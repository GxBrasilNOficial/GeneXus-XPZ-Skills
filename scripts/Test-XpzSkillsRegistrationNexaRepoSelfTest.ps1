#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico da deteccao de repo legado da nexa em Test-XpzSkillsRegistration.ps1.

.DESCRIPTION
    Monta perfil falso com vinculos validos da nexa apontando para um clone Git com
    origin divergente do oficial. Confere que externalOverall = EXTERNAL_SKILLS_GAPS
    e repoBootstrapDetected.label = NEXA_REMOTE_MISMATCH, sem rede.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptUnderTest = Join-Path $PSScriptRoot 'Test-XpzSkillsRegistration.ps1'
if (-not (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf)) {
    throw "BLOCK: script alvo nao encontrado: $scriptUnderTest"
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    throw 'BLOCK: git ausente; este self-test requer o executavel git.'
}

$official = 'https://github.com/GxBrasilNOficial/genexus-skills-from-zip.git'
$legacyOrigin = 'https://github.com/genexuslabs/genexus-skills.git'

$failures = 0
$cases = 0

function New-TempDir {
    $path = Join-Path $env:TEMP ('xpz-nexarepo-selftest-' + [Guid]::NewGuid().ToString('N'))
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

function New-Junction {
    param([string]$LinkDir, [string]$Name, [string]$Target)
    if (-not (Test-Path -LiteralPath $LinkDir -PathType Container)) {
        New-Item -ItemType Directory -Path $LinkDir -Force | Out-Null
    }
    New-Item -ItemType Junction -Path (Join-Path $LinkDir $Name) -Target $Target | Out-Null
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
$legacyRepo = New-TempDir
$originalProfile = $env:USERPROFILE
$originalPath = $env:PATH

try {
    $env:PATH = ''

    # Inventario minimo na raiz XPZ falsa
    $skillDir = Join-Path $fakeRepo 'xpz-skills-setup'
    New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value '# setup' -Encoding utf8

    # Clone legado simulado com subpasta nexa
    & $git.Source -C $legacyRepo init -b main *> $null
    & $git.Source -C $legacyRepo remote add origin $legacyOrigin *> $null
    $nexaDir = Join-Path $legacyRepo 'nexa'
    New-Item -ItemType Directory -Path $nexaDir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $nexaDir 'SKILL.md') -Value '# nexa' -Encoding utf8

    $claudeSkills = Join-Path $fakeProfile '.claude\skills'
    $codexSkills = Join-Path $fakeProfile '.codex\skills'
    New-Junction -LinkDir $claudeSkills -Name 'nexa' -Target $nexaDir
    New-Junction -LinkDir $codexSkills -Name 'nexa' -Target $nexaDir

    Set-Content -LiteralPath (Join-Path $fakeProfile '.claude\settings.json') -Value '{}' -Encoding utf8
    New-Item -ItemType Directory -Path (Join-Path $fakeProfile '.codex') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fakeProfile '.codex\config.toml') -Value '' -Encoding utf8

    $env:USERPROFILE = $fakeProfile
    $json = & $scriptUnderTest -RepoRoot $fakeRepo -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $report = $json | ConvertFrom-Json

    Assert-Equal 'externalOverall GAPS por repo legado' 'EXTERNAL_SKILLS_GAPS' ([string]$report.externalOverall)

    $nexaEntry = @($report.externalSkills | Where-Object { $_.name -eq 'nexa' })
    $script:cases++
    if ($nexaEntry.Count -eq 1) {
        Write-Output 'PASS: externalSkills contem nexa'
    }
    else {
        $script:failures++
        Write-Output ("FAIL: externalSkills deveria conter exatamente um nexa (obtido {0})" -f $nexaEntry.Count)
    }

    if ($nexaEntry.Count -eq 1) {
        Assert-Equal 'repoBootstrapDetected NEXA_REMOTE_MISMATCH' 'NEXA_REMOTE_MISMATCH' ([string]$nexaEntry[0].repoBootstrapDetected.label)
        Assert-Equal 'repoOriginOk false' 'False' ([string]$nexaEntry[0].repoOriginOk)
        Assert-Equal 'Claude nexa OK (vinculo valido)' 'OK' ([string](@($nexaEntry[0].tools | Where-Object { $_.name -eq 'ClaudeCode' }).status))
    }
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    foreach ($p in @($fakeProfile, $fakeRepo, $legacyRepo)) {
        Remove-TempDir -Path $p
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
