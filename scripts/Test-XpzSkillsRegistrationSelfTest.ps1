#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico de Test-XpzSkillsRegistration.ps1.

.DESCRIPTION
    Monta uma raiz de skills e um perfil de usuário falsos em pasta temporaria e
    confere a classificação por ferramenta sem rede. Usa junctions (não exigem
    privilegio de administrador) para simular vinculos. O perfil falso e injetado
    via $env:USERPROFILE durante a invocacao e restaurado ao final.

    Cobre: OK, ausente, quebrada, coberta_por_compatibilidade e orfa.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptUnderTest = Join-Path $PSScriptRoot 'Test-XpzSkillsRegistration.ps1'
if (-not (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf)) {
    throw "BLOCK: script alvo nao encontrado: $scriptUnderTest"
}

$failures = 0
$cases = 0

function New-TempDir {
    $path = Join-Path $env:TEMP ('xpz-regselftest-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function New-FakeSkill {
    param([string]$SkillRepoRoot, [string]$Name, [switch]$WithoutSkillMd)
    $dir = Join-Path $SkillRepoRoot $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    if (-not $WithoutSkillMd) {
        Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value "# $Name" -Encoding utf8
    }
    return $dir
}

function New-Junction {
    param([string]$LinkDir, [string]$Name, [string]$Target)
    if (-not (Test-Path -LiteralPath $LinkDir -PathType Container)) {
        New-Item -ItemType Directory -Path $LinkDir -Force | Out-Null
    }
    New-Item -ItemType Junction -Path (Join-Path $LinkDir $Name) -Target $Target | Out-Null
}

function Get-SkillStatus {
    param($Report, [string]$Tool, [string]$Skill)
    $t = $Report.tools | Where-Object { $_.name -eq $Tool }
    if (-not $t) { return '<tool-ausente>' }
    $s = $t.skills | Where-Object { $_.name -eq $Skill }
    if (-not $s) { return '<skill-ausente>' }
    return $s.status
}

function Assert-Equal {
    param([string]$CaseName, [string]$Expected, [string]$Actual)
    $script:cases++
    if ($Actual -eq $Expected) {
        Write-Output ("PASS: {0} -> {1}" -f $CaseName, $Expected)
    }
    else {
        $script:failures++
        Write-Output ("FAIL: {0} -> esperado '{1}', obtido '{2}'" -f $CaseName, $Expected, $Actual)
    }
}

$fakeRepo = New-TempDir
$fakeProfile = New-TempDir
$brokenTarget = Join-Path $fakeProfile 'broken-target'
$originalProfile = $env:USERPROFILE
$originalPath = $env:PATH

try {
    $env:PATH = ''
    # Inventario: skill-a, skill-b, skill-c (com SKILL.md). skill-removida sem SKILL.md.
    New-FakeSkill -SkillRepoRoot $fakeRepo -Name 'skill-a' | Out-Null
    New-FakeSkill -SkillRepoRoot $fakeRepo -Name 'skill-b' | Out-Null
    New-FakeSkill -SkillRepoRoot $fakeRepo -Name 'skill-c' | Out-Null
    New-FakeSkill -SkillRepoRoot $fakeRepo -Name 'skill-removida' -WithoutSkillMd | Out-Null

    New-Item -ItemType Directory -Path $brokenTarget -Force | Out-Null

    $claudeSkills = Join-Path $fakeProfile '.claude\skills'
    $codexSkills = Join-Path $fakeProfile '.codex\skills'
    $geminiSkills = Join-Path $fakeProfile '.gemini\config\skills'

    # OK em Claude
    New-Junction -LinkDir $claudeSkills -Name 'skill-a' -Target (Join-Path $fakeRepo 'skill-a')
    # quebrada em Claude (target removido depois)
    New-Junction -LinkDir $claudeSkills -Name 'skill-c' -Target $brokenTarget
    # orfa em Claude (aponta para o repo, mas não está no inventario)
    New-Junction -LinkDir $claudeSkills -Name 'skill-removida' -Target (Join-Path $fakeRepo 'skill-removida')
    # OK em Codex
    New-Junction -LinkDir $codexSkills -Name 'skill-b' -Target (Join-Path $fakeRepo 'skill-b')
    # OK em Antigravity (.gemini\config\skills)
    New-Junction -LinkDir $geminiSkills -Name 'skill-a' -Target (Join-Path $fakeRepo 'skill-a')

    # Tornar skill-c quebrada: remover o alvo do junction
    Remove-Item -LiteralPath $brokenTarget -Recurse -Force

    # Marca ferramentas como instaladas de forma deterministica (independe do PATH real):
    Set-Content -LiteralPath (Join-Path $fakeProfile '.claude\settings.json') -Value '{}' -Encoding utf8
    New-Item -ItemType Directory -Path (Join-Path $fakeProfile '.codex') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fakeProfile '.codex\config.toml') -Value '' -Encoding utf8
    New-Item -ItemType Directory -Path (Join-Path $fakeProfile '.cursor') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fakeProfile '.cursor\mcp.json') -Value '{}' -Encoding utf8
    New-Item -ItemType Directory -Path (Join-Path $fakeProfile '.config\opencode') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fakeProfile '.config\opencode\opencode.json') -Value '{}' -Encoding utf8
    New-Item -ItemType Directory -Path (Join-Path $fakeProfile '.gemini\config') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fakeProfile '.gemini\config\config.json') -Value '{}' -Encoding utf8

    $env:USERPROFILE = $fakeProfile
    $json = & $scriptUnderTest -RepoRoot $fakeRepo -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $report = $json | ConvertFrom-Json

    Assert-Equal 'Claude/skill-a OK' 'OK' (Get-SkillStatus -Report $report -Tool 'ClaudeCode' -Skill 'skill-a')
    Assert-Equal 'Claude/skill-b ausente' 'ausente' (Get-SkillStatus -Report $report -Tool 'ClaudeCode' -Skill 'skill-b')
    Assert-Equal 'Claude/skill-c quebrada' 'quebrada' (Get-SkillStatus -Report $report -Tool 'ClaudeCode' -Skill 'skill-c')
    Assert-Equal 'Codex/skill-b OK' 'OK' (Get-SkillStatus -Report $report -Tool 'Codex' -Skill 'skill-b')
    Assert-Equal 'Cursor/skill-a compat' 'coberta_por_compatibilidade' (Get-SkillStatus -Report $report -Tool 'Cursor' -Skill 'skill-a')
    Assert-Equal 'Cursor/skill-b compat' 'coberta_por_compatibilidade' (Get-SkillStatus -Report $report -Tool 'Cursor' -Skill 'skill-b')
    Assert-Equal 'OpenCode/skill-a ausente' 'ausente' (Get-SkillStatus -Report $report -Tool 'OpenCode' -Skill 'skill-a')
    Assert-Equal 'Antigravity/skill-a OK' 'OK' (Get-SkillStatus -Report $report -Tool 'Antigravity' -Skill 'skill-a')
    Assert-Equal 'Antigravity/skill-b ausente' 'ausente' (Get-SkillStatus -Report $report -Tool 'Antigravity' -Skill 'skill-b')

    $script:cases++
    $orphanNames = @($report.orphans | ForEach-Object { $_.name })
    if ($orphanNames -contains 'skill-removida') {
        Write-Output 'PASS: orfa skill-removida detectada'
    }
    else {
        $script:failures++
        Write-Output ("FAIL: orfa skill-removida nao detectada (orfas: {0})" -f ($orphanNames -join ','))
    }

    $script:cases++
    if ($report.overall -eq 'REGISTRATION_GAPS') {
        Write-Output 'PASS: overall REGISTRATION_GAPS'
    }
    else {
        $script:failures++
        Write-Output ("FAIL: overall esperado REGISTRATION_GAPS, obtido {0}" -f $report.overall)
    }

    # Skills externas gerenciadas: a nexa deve aparecer na seção separada, e o veredito
    # externo deve ser independente do overall (aqui GAPS, pois a nexa está ausente).
    $script:cases++
    $nexaEntry = @($report.externalSkills | Where-Object { $_.name -eq 'nexa' })
    if ($nexaEntry.Count -eq 1) {
        Write-Output 'PASS: externalSkills contem nexa'
    }
    else {
        $script:failures++
        Write-Output ("FAIL: externalSkills deveria conter exatamente um nexa (obtido {0})" -f $nexaEntry.Count)
    }

    Assert-Equal 'externalOverall GAPS' 'EXTERNAL_SKILLS_GAPS' ([string]$report.externalOverall)
    Assert-Equal 'summary.externalOverall espelha topo' ([string]$report.externalOverall) ([string]$report.summary.externalOverall)
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    foreach ($p in @($fakeProfile, $fakeRepo)) {
        if (Test-Path -LiteralPath $p) {
            Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue |
                ForEach-Object { try { $_.Attributes = 'Normal' } catch { } }
            Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Output '---'
if ($failures -eq 0) {
    Write-Output ("SELFTEST_OK: {0}/{0} casos passaram" -f $cases)
    exit 0
}
else {
    Write-Output ("SELFTEST_FAIL: {0} de {1} casos falharam" -f $failures, $cases)
    exit 1
}
