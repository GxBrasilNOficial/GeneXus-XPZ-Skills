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
    Casos isolados adicionais: compat do Cursor sozinho marca REGISTRATION_GAPS;
    vinculo nativo em ~/.cursor/skills produz Cursor OK e REGISTRATION_OK.
    reviewer-ro global do OpenCode, com opencode.jsonc SINTETICO no perfil falso: nao aplicavel,
    ausente (sem gap), defasado, forma interina tools:, canonico, comentario com chaves (defasado e
    canonico), homonimo e JSONC invalido; e a prova de que o conteudo do arquivo nao e impresso.
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

# Caso isolado: so Cursor + skill so em .claude → compat marca REGISTRATION_GAPS
$compatRepo = New-TempDir
$compatProfile = New-TempDir
$compatLocal = New-TempDir
$originalLocalAppData = $env:LOCALAPPDATA
try {
    $env:PATH = ''
    $env:LOCALAPPDATA = $compatLocal
    New-FakeSkill -SkillRepoRoot $compatRepo -Name 'skill-only' | Out-Null
    New-Junction -LinkDir (Join-Path $compatProfile '.claude\skills') -Name 'skill-only' -Target (Join-Path $compatRepo 'skill-only')
    New-Item -ItemType Directory -Path (Join-Path $compatProfile '.cursor') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $compatProfile '.cursor\mcp.json') -Value '{}' -Encoding utf8

    $env:USERPROFILE = $compatProfile
    $compatJson = & $scriptUnderTest -RepoRoot $compatRepo -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $compatReport = $compatJson | ConvertFrom-Json

    Assert-Equal 'isolado: Cursor compat' 'coberta_por_compatibilidade' (Get-SkillStatus -Report $compatReport -Tool 'Cursor' -Skill 'skill-only')
    Assert-Equal 'isolado: overall GAPS por compat' 'REGISTRATION_GAPS' ([string]$compatReport.overall)
    Assert-Equal 'isolado: missing 0' '0' ([string]$compatReport.summary.missing)
    Assert-Equal 'isolado: broken 0' '0' ([string]$compatReport.summary.broken)
    Assert-Equal 'isolado: orphans 0' '0' ([string]$compatReport.summary.orphans)
    $script:cases++
    if ([int]$compatReport.summary.coveredByCompat -ge 1) {
        Write-Output 'PASS: isolado: coveredByCompat >= 1'
    }
    else {
        $script:failures++
        Write-Output ("FAIL: isolado: coveredByCompat esperado >= 1, obtido {0}" -f $compatReport.summary.coveredByCompat)
    }
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @($compatProfile, $compatRepo, $compatLocal)) {
        if (Test-Path -LiteralPath $p) {
            Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue |
                ForEach-Object { try { $_.Attributes = 'Normal' } catch { } }
            Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Caso isolado: vinculo nativo em .cursor/skills → Cursor OK e REGISTRATION_OK
$nativeRepo = New-TempDir
$nativeProfile = New-TempDir
$nativeLocal = New-TempDir
try {
    $env:PATH = ''
    $env:LOCALAPPDATA = $nativeLocal
    New-FakeSkill -SkillRepoRoot $nativeRepo -Name 'skill-only' | Out-Null
    New-Junction -LinkDir (Join-Path $nativeProfile '.cursor\skills') -Name 'skill-only' -Target (Join-Path $nativeRepo 'skill-only')
    New-Item -ItemType Directory -Path (Join-Path $nativeProfile '.cursor') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $nativeProfile '.cursor\mcp.json') -Value '{}' -Encoding utf8

    $env:USERPROFILE = $nativeProfile
    $nativeJson = & $scriptUnderTest -RepoRoot $nativeRepo -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $nativeReport = $nativeJson | ConvertFrom-Json

    Assert-Equal 'nativo: Cursor OK' 'OK' (Get-SkillStatus -Report $nativeReport -Tool 'Cursor' -Skill 'skill-only')
    Assert-Equal 'nativo: overall OK' 'REGISTRATION_OK' ([string]$nativeReport.overall)
    Assert-Equal 'nativo: coveredByCompat 0' '0' ([string]$nativeReport.summary.coveredByCompat)
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @($nativeProfile, $nativeRepo, $nativeLocal)) {
        if (Test-Path -LiteralPath $p) {
            Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue |
                ForEach-Object { try { $_.Attributes = 'Normal' } catch { } }
            Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Casos isolados: reviewer-ro GLOBAL do OpenCode (opencodeReviewerRo), com opencode.jsonc SINTETICO
# num perfil falso. Uma skill com vinculo nativo do OpenCode deixa o overall dependente so do reviewer-ro.
$rroRepo = New-TempDir
$rroLocal = New-TempDir
$rroWork = New-TempDir
$rroProfiles = [System.Collections.Generic.List[string]]::new()
$installerRro = Join-Path $PSScriptRoot 'Install-OpenCodeReviewerRoAgent.ps1'
$sentinel = 'sk-SENTINELA-NAO-IMPRIMIR-7781'
try {
    $env:LOCALAPPDATA = $rroLocal
    New-FakeSkill -SkillRepoRoot $rroRepo -Name 'skill-only' | Out-Null

    # Canonico gerado pelo proprio instalador num caminho temporario (nunca a configuracao real).
    $canonPath = Join-Path $rroWork 'canonico.jsonc'
    & $installerRro -JsoncPath $canonPath | Out-Null
    $canonRaw = Get-Content -LiteralPath $canonPath -Raw -Encoding utf8
    $oldForm = '{ "provider": { "x": { "options": { "apiKey": "' + $sentinel + '" } } }, "agent": { "reviewer-ro": { "description": "x", "mode": "all", "permission": { "*": "deny", "read": "allow", "grep": "allow", "glob": "allow", "list": "allow", "edit": "deny", "bash": "deny", "webfetch": "deny", "websearch": "deny", "task": "deny", "external_directory": "deny" } } } }'

    function Invoke-RroCase {
        param([string]$Name, [AllowNull()][string]$Jsonc, [switch]$NoOpenCode, [switch]$JsonOnly)
        $prof = New-TempDir
        $script:rroProfiles.Add($prof)
        if (-not $NoOpenCode) {
            New-Junction -LinkDir (Join-Path $prof '.config\opencode\skills') -Name 'skill-only' -Target (Join-Path $rroRepo 'skill-only')
            if ($JsonOnly) { Set-Content -LiteralPath (Join-Path $prof '.config\opencode\opencode.json') -Value '{}' -Encoding utf8 }
            if ($null -ne $Jsonc) { [System.IO.File]::WriteAllText((Join-Path $prof '.config\opencode\opencode.jsonc'), $Jsonc, (New-Object System.Text.UTF8Encoding($false))) }
        }
        $env:PATH = ''
        $env:USERPROFILE = $prof
        try {
            $jsonOut = & $scriptUnderTest -RepoRoot $rroRepo -AsJson | Out-String
            $textOut = & $scriptUnderTest -RepoRoot $rroRepo | Out-String
        }
        finally {
            $env:PATH = $originalPath
            $env:USERPROFILE = $originalProfile
        }
        return [pscustomobject]@{ report = ($jsonOut | ConvertFrom-Json); json = $jsonOut; text = $textOut }
    }

    $c = Invoke-RroCase -Name 'na' -Jsonc $null -NoOpenCode
    Assert-Equal 'reviewer-ro: OpenCode nao instalado => NOT_APPLICABLE' 'REVIEWER_RO_NOT_APPLICABLE' ([string]$c.report.opencodeReviewerRo.label)

    $c = Invoke-RroCase -Name 'missing' -Jsonc $null -JsonOnly
    Assert-Equal 'reviewer-ro: jsonc ausente => MISSING' 'REVIEWER_RO_MISSING' ([string]$c.report.opencodeReviewerRo.label)
    Assert-Equal 'reviewer-ro: MISSING nao marca gap' 'REGISTRATION_OK' ([string]$c.report.overall)
    Assert-Equal 'reviewer-ro: opencode.json presente reportado' 'True' ([string]$c.report.opencodeReviewerRo.opencodeJsonPresent)

    $c = Invoke-RroCase -Name 'missing-agent' -Jsonc '{ "agent": { "helper": { "mode": "all" } } }'
    Assert-Equal 'reviewer-ro: agent sem reviewer-ro => MISSING' 'REVIEWER_RO_MISSING' ([string]$c.report.opencodeReviewerRo.label)

    $c = Invoke-RroCase -Name 'stale' -Jsonc $oldForm
    Assert-Equal 'reviewer-ro: forma anterior (read escalar + grep allow) => STALE' 'REVIEWER_RO_STALE' ([string]$c.report.opencodeReviewerRo.label)
    Assert-Equal 'reviewer-ro: STALE marca gap' 'REGISTRATION_GAPS' ([string]$c.report.overall)
    Assert-Equal 'reviewer-ro: STALE lista 2 divergencias' '2' ([string]@($c.report.opencodeReviewerRo.divergences).Count)
    Assert-Equal 'reviewer-ro: STALE corrigivel pelo instalador' 'True' ([string]$c.report.opencodeReviewerRo.autoFixable)
    Assert-Equal 'reviewer-ro: fonte global' 'True' ([string]([string]$c.report.opencodeReviewerRo.source).StartsWith('global:'))
    Assert-Equal 'reviewer-ro: conteudo do jsonc nao aparece no JSON nem no texto' 'False' ([string]($c.json.Contains($sentinel) -or $c.text.Contains($sentinel)))
    Assert-Equal 'reviewer-ro: summary espelha o label' 'REVIEWER_RO_STALE' ([string]$c.report.summary.opencodeReviewerRo)

    $c = Invoke-RroCase -Name 'tools' -Jsonc '{ "agent": { "reviewer-ro": { "mode": "primary", "tools": { "edit": false, "bash": false } } } }'
    Assert-Equal 'reviewer-ro: forma interina tools: => STALE' 'REVIEWER_RO_STALE' ([string]$c.report.opencodeReviewerRo.label)

    $c = Invoke-RroCase -Name 'ok' -Jsonc $canonRaw
    Assert-Equal 'reviewer-ro: canonico => OK' 'REVIEWER_RO_OK' ([string]$c.report.opencodeReviewerRo.label)
    Assert-Equal 'reviewer-ro: canonico nao marca gap' 'REGISTRATION_OK' ([string]$c.report.overall)

    $braceStale = $oldForm.Replace('{ "provider"', "{`n  // nota {nao mexer}`n  `"provider`"")
    $c = Invoke-RroCase -Name 'brace-stale' -Jsonc $braceStale
    Assert-Equal 'reviewer-ro: comentario com chaves + defasado => NOT_AUTOFIXABLE' 'REVIEWER_RO_NOT_AUTOFIXABLE' ([string]$c.report.opencodeReviewerRo.label)
    Assert-Equal 'reviewer-ro: NOT_AUTOFIXABLE marca gap' 'REGISTRATION_GAPS' ([string]$c.report.overall)
    Assert-Equal 'reviewer-ro: NOT_AUTOFIXABLE ainda lista as divergencias' '2' ([string]@($c.report.opencodeReviewerRo.divergences).Count)

    $braceOk = $canonRaw.Replace('"$schema"', "// nota {nao mexer}`n  `"`$schema`"")
    $c = Invoke-RroCase -Name 'brace-ok' -Jsonc $braceOk
    Assert-Equal 'reviewer-ro: comentario com chaves + canonico => OK' 'REVIEWER_RO_OK' ([string]$c.report.opencodeReviewerRo.label)

    $c = Invoke-RroCase -Name 'homonimo' -Jsonc '{ "metadata": { "reviewer-ro": { "note": "x" } }, "agent": { "helper": { "mode": "all" } } }'
    Assert-Equal 'reviewer-ro: homonimo fora de agent => NOT_AUTOFIXABLE' 'REVIEWER_RO_NOT_AUTOFIXABLE' ([string]$c.report.opencodeReviewerRo.label)

    $c = Invoke-RroCase -Name 'invalido' -Jsonc '{ "agent": '
    Assert-Equal 'reviewer-ro: JSONC invalido => NOT_AUTOFIXABLE' 'REVIEWER_RO_NOT_AUTOFIXABLE' ([string]$c.report.opencodeReviewerRo.label)
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @(@($rroProfiles) + @($rroRepo, $rroLocal, $rroWork))) {
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
