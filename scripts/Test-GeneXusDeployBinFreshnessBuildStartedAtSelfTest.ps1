#requires -Version 7.4

<#
.SYNOPSIS
    Regressao da resolucao de -BuildStartedAt no script avulso Test-GeneXusDeployBinFreshness.ps1.

.DESCRIPTION
    Cobre a Frente 3: a linha de corte pode vir de timing.msbuildStart do JSON do build
    (-BuildResultJsonPath), eliminando a extracao manual; -BuildStartedAt explicito prevalece;
    sem nenhum dos dois, erro claro.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$freshnessScript = Join-Path $scriptDir 'Test-GeneXusDeployBinFreshness.ps1'

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-deploy-bin-bsa-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $kbNativePath = Join-Path $tempRoot 'KbNative'
    $parallelRoot = Join-Path $tempRoot 'parallel'
    $webDir = Join-Path (Join-Path $kbNativePath 'NETFrameworkPostgreSQL') 'web'
    $binDir = Join-Path $webDir 'bin'
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    New-Item -ItemType Directory -Path $parallelRoot -Force | Out-Null

    $metadataPath = Join-Path $parallelRoot 'kb-source-metadata.md'
    $metadata = @(
        '---'
        'deployment_environment_name: .Net Environment'
        'deployment_hosting_kind: dotnet-framework-iis'
        'kb_environment_count: 1'
        'kb_environment_names: .Net Environment'
        'kb_environment_output_dirs: .Net Environment=NETFrameworkPostgreSQL'
        ('kb_environment_web_dirs: .Net Environment={0}' -f $webDir)
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText($metadataPath, $metadata + "`n", (Get-Utf8NoBomEncoding))

    $cutoffIso = '2026-06-08T19:00:00.0000000+00:00'
    $buildJsonPath = Join-Path $tempRoot 'build.json'
    $buildObj = [ordered]@{
        status = 'compilou limpo'
        timing = [ordered]@{ msbuildStart = $cutoffIso }
    }
    [System.IO.File]::WriteAllText($buildJsonPath, ($buildObj | ConvertTo-Json -Depth 8), (Get-Utf8NoBomEncoding))

    # Caso A: linha de corte vem do JSON do build.
    $outA = & $freshnessScript -KbPath $kbNativePath -KbMetadataPath $metadataPath -BuildResultJsonPath $buildJsonPath -AsJson | Out-String
    $resA = $outA | ConvertFrom-Json
    if ($resA.buildStartedAtSource -ne 'build-json') {
        throw "ASSERT_FAILED: caso A deveria ter source=build-json, atual=$($resA.buildStartedAtSource)"
    }
    if ((([DateTimeOffset]$resA.buildStartedAt).UtcTicks) -ne (([DateTimeOffset]::Parse($cutoffIso)).UtcTicks)) {
        throw "ASSERT_FAILED: caso A buildStartedAt divergente do timing.msbuildStart, atual=$($resA.buildStartedAt)"
    }

    # Caso B: -BuildStartedAt explicito prevalece mesmo com JSON presente.
    $explicitIso = '2020-01-01T00:00:00.0000000+00:00'
    $outB = & $freshnessScript -KbPath $kbNativePath -KbMetadataPath $metadataPath -BuildStartedAt $explicitIso -BuildResultJsonPath $buildJsonPath -AsJson | Out-String
    $resB = $outB | ConvertFrom-Json
    if ($resB.buildStartedAtSource -ne 'parameter') {
        throw "ASSERT_FAILED: caso B deveria ter source=parameter, atual=$($resB.buildStartedAtSource)"
    }
    if ((([DateTimeOffset]$resB.buildStartedAt).UtcTicks) -ne (([DateTimeOffset]::Parse($explicitIso)).UtcTicks)) {
        throw "ASSERT_FAILED: caso B deveria usar o timestamp explicito, atual=$($resB.buildStartedAt)"
    }

    # Caso C: sem -BuildStartedAt nem -BuildResultJsonPath -> erro claro.
    $threw = $false
    try {
        & $freshnessScript -KbPath $kbNativePath -KbMetadataPath $metadataPath -AsJson | Out-Null
    }
    catch {
        $threw = $true
        if ($_.Exception.Message -notmatch 'BuildStartedAt' -or $_.Exception.Message -notmatch 'BuildResultJsonPath') {
            throw "ASSERT_FAILED: caso C deveria citar ambos os parametros na mensagem, atual=$($_.Exception.Message)"
        }
    }
    if (-not $threw) {
        throw 'ASSERT_FAILED: caso C deveria lancar erro quando nenhuma fonte de timestamp e informada'
    }

    # Caso D: JSON sem timing.msbuildStart -> erro claro.
    $badJsonPath = Join-Path $tempRoot 'build-sem-timing.json'
    [System.IO.File]::WriteAllText($badJsonPath, ('{ "status": "compilou limpo" }'), (Get-Utf8NoBomEncoding))
    $threwD = $false
    try {
        & $freshnessScript -KbPath $kbNativePath -KbMetadataPath $metadataPath -BuildResultJsonPath $badJsonPath -AsJson | Out-Null
    }
    catch {
        $threwD = $true
        if ($_.Exception.Message -notmatch 'msbuildStart') {
            throw "ASSERT_FAILED: caso D deveria citar msbuildStart ausente, atual=$($_.Exception.Message)"
        }
    }
    if (-not $threwD) {
        throw 'ASSERT_FAILED: caso D deveria lancar erro quando timing.msbuildStart esta ausente no JSON'
    }

    'GENEXUS_DEPLOY_BIN_FRESHNESS_BUILDSTARTEDAT_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
