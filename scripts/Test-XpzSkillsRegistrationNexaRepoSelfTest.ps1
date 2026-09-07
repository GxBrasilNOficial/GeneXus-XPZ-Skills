#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico da deteccao de repo legado da nexa em Test-XpzSkillsRegistration.ps1.

.DESCRIPTION
    Monta perfil falso com vinculos validos da nexa apontando para um clone Git com
    origin divergente do oficial. Confere que externalOverall = EXTERNAL_SKILLS_GAPS
    e repoBootstrapDetected.label = NEXA_REMOTE_MISMATCH, sem rede. Inclui caso misto
    (Claude no canonico + Antigravity no legado) para impedir falso EXTERNAL_SKILLS_OK.
    Inclui caso positivo: perfil sem ferramentas/vinculos e pasta-irma canônica
    ausente — repoBootstrapCanonical = NEXA_REPO_MISSING e EXTERNAL_SKILLS_OK
    (canônico ausente e informativo; nao abre gap sozinho).
    Isola LOCALAPPDATA para nao herdar GeneXus4Agents real da maquina.
    Casos adicionais: copia_opaca nexa/gam (payload Gx4A preferido) e
    fonte_desatualizada (junction From-Zip com payload mais novo).
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
$fakeLocalAppData = New-TempDir
$originalProfile = $env:USERPROFILE
$originalPath = $env:PATH
$originalLocalAppData = $env:LOCALAPPDATA
# PATH minimo: so o diretorio do git ja resolvido. Evita CLIs de agente no PATH
# (determinismo de Test-ToolInstalled) sem depender dos 3 fallbacks hard-coded
# de Find-GitExecutable (Program Files / LOCALAPPDATA) — scoop/choco/portatil.
$gitBinDir = Split-Path -Parent $git.Source

try {
    $env:PATH = $gitBinDir
    $env:LOCALAPPDATA = $fakeLocalAppData

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
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @($fakeProfile, $fakeRepo, $legacyRepo, $fakeLocalAppData)) {
        Remove-TempDir -Path $p
    }
}

# Caso 2: instalacao mista — primeiro vinculo canônico, Antigravity ainda no legado
$fakeRepo2 = New-TempDir
$fakeProfile2 = New-TempDir
$legacyRepo2 = New-TempDir
$canonicalRepo2 = New-TempDir
$fakeLocalAppData2 = New-TempDir
try {
    $env:PATH = $gitBinDir
    $env:LOCALAPPDATA = $fakeLocalAppData2

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
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @($fakeProfile2, $fakeRepo2, $legacyRepo2, $canonicalRepo2, $fakeLocalAppData2)) {
        Remove-TempDir -Path $p
    }
}

# Caso 3: canônico ausente sem registro — NEXA_REPO_MISSING informativo, EXTERNAL_SKILLS_OK
$fakeRepo3 = New-TempDir
$fakeProfile3 = New-TempDir
$fakeLocalAppData3 = New-TempDir
try {
    $env:PATH = $gitBinDir
    $env:LOCALAPPDATA = $fakeLocalAppData3

    $skillDir3 = Join-Path $fakeRepo3 'xpz-skills-setup'
    New-Item -ItemType Directory -Path $skillDir3 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skillDir3 'SKILL.md') -Value '# setup' -Encoding utf8
    # Sem markers de ferramenta em $fakeProfile3 e sem CLIs no PATH => nenhuma
    # ferramenta "instalada"; canônico irmão GeneXus-Skills-From-Zip nao existe.

    $env:USERPROFILE = $fakeProfile3
    $json3 = & $scriptUnderTest -RepoRoot $fakeRepo3 -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $report3 = $json3 | ConvertFrom-Json

    Assert-Equal 'canonico ausente: externalOverall OK' 'EXTERNAL_SKILLS_OK' ([string]$report3.externalOverall)
    $nexa3 = @($report3.externalSkills | Where-Object { $_.name -eq 'nexa' })
    if ($nexa3.Count -eq 1) {
        Assert-equal 'canonico ausente: repoBootstrapCanonical NEXA_REPO_MISSING' 'NEXA_REPO_MISSING' ([string]$nexa3[0].repoBootstrapCanonical.label)
        Assert-Equal 'canonico ausente: repoOriginOk false' 'False' ([string]$nexa3[0].repoOriginOk)
    }
    else {
        $script:cases++
        $script:failures++
        Write-Output 'FAIL: canonico ausente: externalSkills deveria conter nexa'
    }
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @($fakeProfile3, $fakeRepo3, $fakeLocalAppData3)) {
        Remove-TempDir -Path $p
    }
}

# Caso 4: copia_opaca nexa — payload Gx4A mais novo que From-Zip; Claude tem pasta real
$fakeRepo4 = New-TempDir
$fakeProfile4 = New-TempDir
$fakeLocalAppData4 = New-TempDir
$fromZip4 = Join-Path ([System.IO.Path]::GetDirectoryName($fakeRepo4)) 'GeneXus-Skills-From-Zip'
try {
    $env:PATH = $gitBinDir
    $env:LOCALAPPDATA = $fakeLocalAppData4

    $skillDir4 = Join-Path $fakeRepo4 'xpz-skills-setup'
    New-Item -ItemType Directory -Path $skillDir4 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skillDir4 'SKILL.md') -Value '# setup' -Encoding utf8

    # From-Zip irmao (mais velho, sem version)
    $fromZipNexa = Join-Path $fromZip4 'nexa'
    New-Item -ItemType Directory -Path $fromZipNexa -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fromZipNexa 'SKILL.md') -Value @"
---
name: nexa
description: old
---
"@ -Encoding utf8
    (Get-Item (Join-Path $fromZipNexa 'SKILL.md')).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-30)

    # Payload Gx4A mais novo (1.0.3)
    $payloadNexa = Join-Path $fakeLocalAppData4 'Programs\GeneXus\GeneXus4Agents\payload\skills\nexa'
    New-Item -ItemType Directory -Path $payloadNexa -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $payloadNexa 'SKILL.md') -Value @"
---
name: nexa
description: new
metadata:
  version: "1.0.3"
  author: "GeneXus"
---
"@ -Encoding utf8
    $managed = Join-Path $fakeLocalAppData4 'Programs\GeneXus\GeneXus4Agents\.skill-managed-nexa'
    Set-Content -LiteralPath $managed -Value @"
2026-09-07T11:10:08
checksum=ABC
$($fakeProfile4)\.claude\skills\nexa
"@ -Encoding utf8

    # Copia opaca em Claude
    $opaque = Join-Path $fakeProfile4 '.claude\skills\nexa'
    New-Item -ItemType Directory -Path $opaque -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $payloadNexa 'SKILL.md') -Destination (Join-Path $opaque 'SKILL.md')
    Set-Content -LiteralPath (Join-Path $fakeProfile4 '.claude\settings.json') -Value '{}' -Encoding utf8

    $env:USERPROFILE = $fakeProfile4
    $json4 = & $scriptUnderTest -RepoRoot $fakeRepo4 -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $report4 = $json4 | ConvertFrom-Json

    Assert-Equal 'copia_opaca: externalOverall GAPS' 'EXTERNAL_SKILLS_GAPS' ([string]$report4.externalOverall)
    $nexa4 = @($report4.externalSkills | Where-Object { $_.name -eq 'nexa' })
    if ($nexa4.Count -eq 1) {
        Assert-equal 'copia_opaca: preferredKind gx4a-payload' 'gx4a-payload' ([string]$nexa4[0].preferredKind)
        Assert-equal 'copia_opaca: Claude status' 'copia_opaca' ([string](@($nexa4[0].tools | Where-Object { $_.name -eq 'ClaudeCode' }).status))
        Assert-equal 'copia_opaca: resolveAction' 'replace-with-junction-to-preferred' ([string]$nexa4[0].resolveAction)
        Assert-Equal 'copia_opaca: fromZipBehind true' 'True' ([string]$nexa4[0].fromZipBehindPreferred)
    }
    else {
        $script:cases++
        $script:failures++
        Write-Output 'FAIL: copia_opaca: externalSkills deveria conter nexa'
    }
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @($fakeProfile4, $fakeRepo4, $fakeLocalAppData4, $fromZip4)) {
        Remove-TempDir -Path $p
    }
}

# Caso 5: gam copia_opaca → preferred payload
$fakeRepo5 = New-TempDir
$fakeProfile5 = New-TempDir
$fakeLocalAppData5 = New-TempDir
try {
    $env:PATH = $gitBinDir
    $env:LOCALAPPDATA = $fakeLocalAppData5

    $skillDir5 = Join-Path $fakeRepo5 'xpz-skills-setup'
    New-Item -ItemType Directory -Path $skillDir5 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skillDir5 'SKILL.md') -Value '# setup' -Encoding utf8

    $payloadGam = Join-Path $fakeLocalAppData5 'Programs\GeneXus\GeneXus4Agents\payload\skills\gam'
    New-Item -ItemType Directory -Path $payloadGam -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $payloadGam 'SKILL.md') -Value @"
---
name: gam
metadata:
  version: "1.0.4"
---
"@ -Encoding utf8
    Set-Content -LiteralPath (Join-Path $fakeLocalAppData5 'Programs\GeneXus\GeneXus4Agents\.skill-managed-gam') -Value @"
checksum=DEF
$($fakeProfile5)\.claude\skills\gam
"@ -Encoding utf8

    $opaqueGam = Join-Path $fakeProfile5 '.claude\skills\gam'
    New-Item -ItemType Directory -Path $opaqueGam -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $payloadGam 'SKILL.md') -Destination (Join-Path $opaqueGam 'SKILL.md')
    Set-Content -LiteralPath (Join-Path $fakeProfile5 '.claude\settings.json') -Value '{}' -Encoding utf8

    $env:USERPROFILE = $fakeProfile5
    $json5 = & $scriptUnderTest -RepoRoot $fakeRepo5 -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $report5 = $json5 | ConvertFrom-Json

    Assert-Equal 'gam opaca: externalOverall GAPS' 'EXTERNAL_SKILLS_GAPS' ([string]$report5.externalOverall)
    $gam5 = @($report5.externalSkills | Where-Object { $_.name -eq 'gam' })
    if ($gam5.Count -eq 1) {
        Assert-Equal 'gam opaca: preferredKind' 'gx4a-payload' ([string]$gam5[0].preferredKind)
        Assert-Equal 'gam opaca: Claude status' 'copia_opaca' ([string](@($gam5[0].tools | Where-Object { $_.name -eq 'ClaudeCode' }).status))
        Assert-Equal 'gam opaca: resolveAction' 'replace-with-junction-to-preferred' ([string]$gam5[0].resolveAction)
    }
    else {
        $script:cases++
        $script:failures++
        Write-Output 'FAIL: gam opaca: externalSkills deveria conter gam'
    }
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @($fakeProfile5, $fakeRepo5, $fakeLocalAppData5)) {
        Remove-TempDir -Path $p
    }
}

# Caso 6: junction From-Zip com payload mais novo → fonte_desatualizada
$fakeRepo6 = New-TempDir
$fakeProfile6 = New-TempDir
$fakeLocalAppData6 = New-TempDir
$fromZip6 = Join-Path ([System.IO.Path]::GetDirectoryName($fakeRepo6)) 'GeneXus-Skills-From-Zip'
try {
    $env:PATH = $gitBinDir
    $env:LOCALAPPDATA = $fakeLocalAppData6

    $skillDir6 = Join-Path $fakeRepo6 'xpz-skills-setup'
    New-Item -ItemType Directory -Path $skillDir6 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $skillDir6 'SKILL.md') -Value '# setup' -Encoding utf8

    & $git.Source -C $fromZip6 init -b main *> $null
    & $git.Source -C $fromZip6 remote add origin $official *> $null
    $fromZipNexa6 = Join-Path $fromZip6 'nexa'
    New-Item -ItemType Directory -Path $fromZipNexa6 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $fromZipNexa6 'SKILL.md') -Value @"
---
name: nexa
---
"@ -Encoding utf8
    (Get-Item (Join-Path $fromZipNexa6 'SKILL.md')).LastWriteTimeUtc = [datetime]::UtcNow.AddDays(-20)

    $payloadNexa6 = Join-Path $fakeLocalAppData6 'Programs\GeneXus\GeneXus4Agents\payload\skills\nexa'
    New-Item -ItemType Directory -Path $payloadNexa6 -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $payloadNexa6 'SKILL.md') -Value @"
---
name: nexa
metadata:
  version: "1.0.3"
---
"@ -Encoding utf8

    New-Junction -LinkDir (Join-Path $fakeProfile6 '.claude\skills') -Name 'nexa' -Target $fromZipNexa6
    Set-Content -LiteralPath (Join-Path $fakeProfile6 '.claude\settings.json') -Value '{}' -Encoding utf8

    $env:USERPROFILE = $fakeProfile6
    $json6 = & $scriptUnderTest -RepoRoot $fakeRepo6 -AsJson | Out-String
    $env:USERPROFILE = $originalProfile
    $report6 = $json6 | ConvertFrom-Json

    Assert-Equal 'stale: externalOverall GAPS' 'EXTERNAL_SKILLS_GAPS' ([string]$report6.externalOverall)
    $nexa6 = @($report6.externalSkills | Where-Object { $_.name -eq 'nexa' })
    if ($nexa6.Count -eq 1) {
        Assert-Equal 'stale: preferredKind gx4a-payload' 'gx4a-payload' ([string]$nexa6[0].preferredKind)
        Assert-Equal 'stale: Claude fonte_desatualizada' 'fonte_desatualizada' ([string](@($nexa6[0].tools | Where-Object { $_.name -eq 'ClaudeCode' }).status))
    }
    else {
        $script:cases++
        $script:failures++
        Write-Output 'FAIL: stale: externalSkills deveria conter nexa'
    }
}
finally {
    $env:PATH = $originalPath
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    foreach ($p in @($fakeProfile6, $fakeRepo6, $fakeLocalAppData6, $fromZip6)) {
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
