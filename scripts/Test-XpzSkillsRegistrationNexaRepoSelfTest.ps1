#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico da deteccao de repo legado da nexa em Test-XpzSkillsRegistration.ps1.

.DESCRIPTION
    Monta perfil falso com vinculos validos da nexa apontando para um clone Git com
    origin divergente do oficial. Confere que externalOverall = EXTERNAL_SKILLS_GAPS
    e repoBootstrapDetected.label = NEXA_REMOTE_MISMATCH, sem rede. Inclui caso misto
    (Claude no canonico + Antigravity no legado) para impedir falso EXTERNAL_SKILLS_OK.
    Durante a invocacao do motor, PATH fica reduzido ao diretorio do git ja resolvido
    (sem CLIs de agente; nao depende dos fallbacks Program Files do Find-GitExecutable).
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
# PATH minimo: so o diretorio do git ja resolvido. Evita CLIs de agente no PATH
# (determinismo de Test-ToolInstalled) sem depender dos 3 fallbacks hard-coded
# de Find-GitExecutable (Program Files / LOCALAPPDATA) — scoop/choco/portatil.
$gitBinDir = Split-Path -Parent $git.Source

try {
    $env:PATH = $gitBinDir

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
        Assert-equal 'Claude nexa OK (vinculo valido)' 'OK' ([string](@($nexaEntry[0].tools | Where-Object { $_.name -eq 'ClaudeCode' }).status))
    }
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    foreach ($p in @($fakeProfile, $fakeRepo, $legacyRepo)) {
        Remove-TempDir -Path $p
    }
}

# Caso 2: instalacao mista — primeiro vinculo canônico, Antigravity ainda no legado
$fakeRepo2 = New-TempDir
$fakeProfile2 = New-TempDir
$legacyRepo2 = New-TempDir
$canonicalRepo2 = New-TempDir
try {
    $env:PATH = $gitBinDir

    $skillDir2 = Join-Path $fakeRepo2 'xpz-skills-setup'
    New-Item -ItemType Directory -Path $skillDir2 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skillDir2 'SKILL.md') -Value '# setup' -Encoding utf8

    & $git.Source -C $legacyRepo2 init -b main *> $null
    & $git.Source -C $legacyRepo2 remote add origin $legacyOrigin *> $null
    $legacyNexa = Join-Path $legacyRepo2 'nexa'
    New-Item -ItemType Directory -Path $legacyNexa -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $legacyNexa 'SKILL.md') -Value '# nexa' -Encoding utf8

    & $git.Source -C $canonicalRepo2 init -b main *> $null
    & $git.Source -C $canonicalRepo2 remote add origin $official *> $null
    $canonNexa = Join-Path $canonicalRepo2 'nexa'
    New-Item -ItemType Directory -Path $canonNexa -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $canonNexa 'SKILL.md') -Value '# nexa' -Encoding utf8

    # Claude (primeiro na ordem) -> canonico; Antigravity nativo -> legado
    New-Junction -LinkDir (Join-Path $fakeProfile2 '.claude\skills') -Name 'nexa' -Target $canonNexa
    New-Junction -LinkDir (Join-Path $fakeProfile2 '.gemini\config\skills') -Name 'nexa' -Target $legacyNexa

    Set-Content -LiteralPath (Join-Path $fakeProfile2 '.claude\settings.json') -Value '{}' -Encoding utf8
    $geminiConfig = Join-Path $fakeProfile2 '.gemini\config'
    New-Item -ItemType Directory -Path $geminiConfig -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $geminiConfig 'config.json') -Value '{}' -Encoding utf8

    $env:USERPROFILE = $fakeProfile2
    $json2 = & $scriptUnderTest -RepoRoot $fakeRepo2 -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $report2 = $json2 | ConvertFrom-Json

    Assert-Equal 'misto: externalOverall GAPS' 'EXTERNAL_SKILLS_GAPS' ([string]$report2.externalOverall)
    $nexa2 = @($report2.externalSkills | Where-Object { $_.name -eq 'nexa' })
    if ($nexa2.Count -eq 1) {
        Assert-Equal 'misto: bootstrap NEXA_REMOTE_MISMATCH' 'NEXA_REMOTE_MISMATCH' ([string]$nexa2[0].repoBootstrapDetected.label)
        Assert-Equal 'misto: Claude OK' 'OK' ([string](@($nexa2[0].tools | Where-Object { $_.name -eq 'ClaudeCode' }).status))
        Assert-Equal 'misto: Antigravity OK (vinculo legado valido)' 'OK' ([string](@($nexa2[0].tools | Where-Object { $_.name -eq 'Antigravity' }).status))
    }
    else {
        $script:cases++
        $script:failures++
        Write-Output 'FAIL: misto: externalSkills deveria conter nexa'
    }
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    foreach ($p in @($fakeProfile2, $fakeRepo2, $legacyRepo2, $canonicalRepo2)) {
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
