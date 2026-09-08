#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de Invoke-GeneXusForAgentsSetupSafe.ps1 em modo -RepairOnly (sem setup real).

.DESCRIPTION
    Cobre replace de copia opaca, retarget de junction, matriz compacta
    (.claude/.agents/.config/.gemini/.cursor + .codex so para nexa), expansiva
    (.codex tambem para gam) e BLOCK quando o payload esta ausente.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptUnderTest = Join-Path $PSScriptRoot 'Invoke-GeneXusForAgentsSetupSafe.ps1'
if (-not (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf)) {
    throw "BLOCK: script alvo nao encontrado: $scriptUnderTest"
}

$failures = 0
$cases = 0

function New-TempDir {
    $path = Join-Path $env:TEMP ('xpz-gx4a-safe-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Remove-TempDir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { try { $_.Attributes = 'Normal' } catch { } }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
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

function Assert-True {
    param([string]$CaseName, [bool]$Actual)
    $script:cases++
    if ($Actual) {
        Write-Output ("PASS: {0}" -f $CaseName)
    }
    else {
        $script:failures++
        Write-Output ("FAIL: {0}" -f $CaseName)
    }
}

$fakeProfile = New-TempDir
$fakeLocal = New-TempDir
$originalProfile = $env:USERPROFILE
$originalLocal = $env:LOCALAPPDATA
$originalPath = $env:PATH

try {
    $env:USERPROFILE = $fakeProfile
    $env:LOCALAPPDATA = $fakeLocal
    # Sem CLIs de agente no PATH
    $env:PATH = ($env:SystemRoot + '\System32')

    $payloadNexa = Join-Path $fakeLocal 'Programs\GeneXus\GeneXus4Agents\payload\skills\nexa'
    $payloadGam = Join-Path $fakeLocal 'Programs\GeneXus\GeneXus4Agents\payload\skills\gam'
    New-Item -ItemType Directory -Path $payloadNexa, $payloadGam -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $payloadNexa 'SKILL.md') -Value @"
---
name: nexa
metadata:
  version: "1.0.3"
---
"@ -Encoding utf8
    Set-Content -LiteralPath (Join-Path $payloadGam 'SKILL.md') -Value @"
---
name: gam
metadata:
  version: "1.0.4"
---
"@ -Encoding utf8

    # Copias opacas + junction desatualizado (Codex nexa)
    $opaqueClaudeNexa = Join-Path $fakeProfile '.claude\skills\nexa'
    New-Item -ItemType Directory -Path $opaqueClaudeNexa -Force | Out-Null
    Copy-Item (Join-Path $payloadNexa 'SKILL.md') (Join-Path $opaqueClaudeNexa 'SKILL.md')
    Set-Content -LiteralPath (Join-Path $fakeProfile '.claude\settings.json') -Value '{}' -Encoding utf8

    $opaqueClaudeGam = Join-Path $fakeProfile '.claude\skills\gam'
    New-Item -ItemType Directory -Path $opaqueClaudeGam -Force | Out-Null
    Copy-Item (Join-Path $payloadGam 'SKILL.md') (Join-Path $opaqueClaudeGam 'SKILL.md')

    $wrongTarget = Join-Path $fakeProfile '_old-from-zip\nexa'
    New-Item -ItemType Directory -Path $wrongTarget -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $wrongTarget 'SKILL.md') -Value '# old' -Encoding utf8
    $codexSkills = Join-Path $fakeProfile '.codex\skills'
    New-Item -ItemType Directory -Path $codexSkills -Force | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $codexSkills 'nexa') -Target $wrongTarget | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $fakeProfile '.codex') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fakeProfile '.codex\config.toml') -Value '' -Encoding utf8

    $json = & $scriptUnderTest -RepairOnly -SkipAudit -AsJson -Confirm:$false | Out-String
    $report = $json | ConvertFrom-Json

    Assert-Equal 'label OK' 'GX4A_SETUP_SAFE_OK' ([string]$report.label)
    Assert-Equal 'repairOnly true' 'True' ([string]$report.repairOnly)

    $claudeNexa = Get-Item -LiteralPath (Join-Path $fakeProfile '.claude\skills\nexa') -Force
    Assert-True 'claude nexa e link' (-not [string]::IsNullOrWhiteSpace([string]$claudeNexa.LinkType))
    Assert-True 'claude nexa -> payload' (
        [string]::Equals([string]@($claudeNexa.Target)[0], (Get-Item $payloadNexa).FullName, [StringComparison]::OrdinalIgnoreCase)
    )

    $claudeGam = Get-Item -LiteralPath (Join-Path $fakeProfile '.claude\skills\gam') -Force
    Assert-True 'claude gam e link' (-not [string]::IsNullOrWhiteSpace([string]$claudeGam.LinkType))
    Assert-True 'claude gam -> payload' (
        [string]::Equals([string]@($claudeGam.Target)[0], (Get-Item $payloadGam).FullName, [StringComparison]::OrdinalIgnoreCase)
    )

    $codexNexa = Get-Item -LiteralPath (Join-Path $fakeProfile '.codex\skills\nexa') -Force
    Assert-True 'codex nexa retarget payload' (
        [string]::Equals([string]@($codexNexa.Target)[0], (Get-Item $payloadNexa).FullName, [StringComparison]::OrdinalIgnoreCase)
    )

    # Alvo errado antigo permanece (so o link foi trocado)
    Assert-True 'from-zip falso intacto' (Test-Path -LiteralPath (Join-Path $wrongTarget 'SKILL.md'))

    $actions = @($report.links | ForEach-Object { [string]$_.action })
    Assert-True 'houve replace-copy' ($actions -contains 'replace-copy')
    Assert-True 'houve retarget' ($actions -contains 'retarget')

    function Assert-LinkToPayload {
        param([string]$CaseName, [string]$LinkPath, [string]$PayloadPath)
        $item = Get-Item -LiteralPath $LinkPath -Force
        Assert-True ("$CaseName e link") (-not [string]::IsNullOrWhiteSpace([string]$item.LinkType))
        Assert-True ("$CaseName -> payload") (
            [string]::Equals([string]@($item.Target)[0], (Get-Item $PayloadPath).FullName, [StringComparison]::OrdinalIgnoreCase)
        )
    }

    # Matriz compacta: todos os destinos de Get-SkillLinkDestinationRels
    foreach ($skill in @('nexa', 'gam')) {
        $payload = if ($skill -eq 'nexa') { $payloadNexa } else { $payloadGam }
        foreach ($rel in @(
                '.claude\skills',
                '.agents\skills',
                '.config\opencode\skills',
                '.gemini\config\skills',
                '.cursor\skills'
            )) {
            Assert-LinkToPayload -CaseName ("compacta $rel/$skill") -LinkPath (Join-Path $fakeProfile (Join-Path $rel $skill)) -PayloadPath $payload
        }
    }
    Assert-LinkToPayload -CaseName 'compacta .codex/nexa' -LinkPath (Join-Path $fakeProfile '.codex\skills\nexa') -PayloadPath $payloadNexa
    Assert-True 'compacta sem .codex/gam' (-not (Test-Path -LiteralPath (Join-Path $fakeProfile '.codex\skills\gam')))
}
finally {
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocal
    $env:PATH = $originalPath
    foreach ($p in @($fakeProfile, $fakeLocal)) { Remove-TempDir -Path $p }
}

# Caso: payload ausente → BLOCK
$fakeProfile2 = New-TempDir
$fakeLocal2 = New-TempDir
try {
    $env:USERPROFILE = $fakeProfile2
    $env:LOCALAPPDATA = $fakeLocal2
    $env:PATH = ($env:SystemRoot + '\System32')
    $failed = $false
    try {
        & $scriptUnderTest -RepairOnly -SkipAudit -AsJson -Confirm:$false | Out-Null
    }
    catch {
        $failed = $true
        Assert-True 'payload ausente lanca BLOCK' ([string]$_.Exception.Message -match 'BLOCK:')
    }
    if (-not $failed) {
        $script:cases++
        $script:failures++
        Write-Output 'FAIL: payload ausente deveria falhar'
    }
}
finally {
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocal
    $env:PATH = $originalPath
    foreach ($p in @($fakeProfile2, $fakeLocal2)) { Remove-TempDir -Path $p }
}

# Caso: -Strategy expansiva cria .codex/skills/gam
$fakeProfile3 = New-TempDir
$fakeLocal3 = New-TempDir
try {
    $env:USERPROFILE = $fakeProfile3
    $env:LOCALAPPDATA = $fakeLocal3
    $env:PATH = ($env:SystemRoot + '\System32')

    $payloadNexa3 = Join-Path $fakeLocal3 'Programs\GeneXus\GeneXus4Agents\payload\skills\nexa'
    $payloadGam3 = Join-Path $fakeLocal3 'Programs\GeneXus\GeneXus4Agents\payload\skills\gam'
    New-Item -ItemType Directory -Path $payloadNexa3, $payloadGam3 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $payloadNexa3 'SKILL.md') -Value "# nexa`n" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $payloadGam3 'SKILL.md') -Value "# gam`n" -Encoding utf8

    $json3 = & $scriptUnderTest -RepairOnly -SkipAudit -Strategy expansiva -AsJson -Confirm:$false | Out-String
    $report3 = $json3 | ConvertFrom-Json
    Assert-Equal 'expansiva label OK' 'GX4A_SETUP_SAFE_OK' ([string]$report3.label)
    Assert-Equal 'expansiva strategy' 'expansiva' ([string]$report3.strategy)

    $codexGam = Get-Item -LiteralPath (Join-Path $fakeProfile3 '.codex\skills\gam') -Force
    Assert-True 'expansiva .codex/gam e link' (-not [string]::IsNullOrWhiteSpace([string]$codexGam.LinkType))
    Assert-True 'expansiva .codex/gam -> payload' (
        [string]::Equals([string]@($codexGam.Target)[0], (Get-Item $payloadGam3).FullName, [StringComparison]::OrdinalIgnoreCase)
    )
    $cursorGam = Get-Item -LiteralPath (Join-Path $fakeProfile3 '.cursor\skills\gam') -Force
    Assert-True 'expansiva .cursor/gam e link' (-not [string]::IsNullOrWhiteSpace([string]$cursorGam.LinkType))
}
finally {
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocal
    $env:PATH = $originalPath
    foreach ($p in @($fakeProfile3, $fakeLocal3)) { Remove-TempDir -Path $p }
}

Write-Output '---'
if ($failures -eq 0) {
    Write-Output ("SELFTEST_OK: {0}/{0} casos passaram" -f $cases)
    Write-Output 'GX4A_SETUP_SAFE_SELFTEST_OK'
    exit 0
}
else {
    Write-Output ("SELFTEST_FAIL: {0} de {1} casos falharam" -f $failures, $cases)
    exit 1
}
