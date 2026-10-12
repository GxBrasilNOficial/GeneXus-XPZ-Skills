#requires -Version 7.4

<#
.SYNOPSIS
    Regressao do classificador pos-build de deploy bin (Invoke-GeneXusKbDeployBinPostBuildClassification),
    caminho .NET Core fresco.

.DESCRIPTION
    Exercita o ramo `status='fresh'` de um environment `dotnet-core-self-host`:
    DLL de objeto fresca em web\bin (publicacao confirmada) + GxNetCoreStartup.dll velho
    (sentinela nao regravado neste build incremental). Esse ramo percorre a linha que
    consultava `.ContainsKey('sentinelFreshSinceBuild')` sobre o `[ordered]@{}` binCheck
    (erro de runtime sob StrictMode antes do fix; agora `.Contains(...)`), e tambem depende
    de o binCheck reportado conter os campos de publicacao (perdidos antes do fix do
    parametro `[System.Collections.IDictionary]` em Add-...PublicationFieldsToBinCheck).

    Asserçoes:
      (a) a classificacao nao lança excecao;
      (b) `deployBinCheck.binCheck` contem os campos de publicacao (publicationFreshSinceBuild,
          objectDllCount) E os de sentinela (sentinelFound, sentinelFreshSinceBuild);
      (c) `warnings` traz o aviso consultivo do GxNetCoreStartup.dll.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'GeneXusKbDeployBinSupport.ps1')

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-deploy-bin-classification-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    $kbNativePath = Join-Path $tempRoot 'KbNative'
    $parallelRoot = Join-Path $tempRoot 'parallel'
    $webDir = Join-Path (Join-Path $kbNativePath 'NETCorePostgreSQL') 'web'
    $binDir = Join-Path $webDir 'bin'
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    New-Item -ItemType Directory -Path $parallelRoot -Force | Out-Null

    $envName = 'NetCore Environment'
    $metadataPath = Join-Path $parallelRoot 'kb-source-metadata.md'
    $metadata = @(
        '---'
        'deployment_environment_name: NetCore Environment'
        'deployment_hosting_kind: dotnet-core-self-host'
        'kb_environment_count: 1'
        'kb_environment_names: NetCore Environment'
        'kb_environment_output_dirs: NetCore Environment=NETCorePostgreSQL'
        ('kb_environment_web_dirs: NetCore Environment={0}' -f $webDir)
        '---'
        ''
    ) -join "`n"
    [System.IO.File]::WriteAllText($metadataPath, $metadata + "`n", (Get-Utf8NoBomEncoding))

    $buildStartedAt = [DateTimeOffset]::Now.AddMinutes(-2)

    # DLL de objeto: fresca (>= threshold = BuildStartedAt - slack 5s). Timestamp fixado, nao
    # confiado ao relogio de criacao.
    $objectDll = Join-Path $binDir 'minhaapp.dll'
    [System.IO.File]::WriteAllText($objectDll, 'objeto', (Get-Utf8NoBomEncoding))
    (Get-Item -LiteralPath $objectDll).LastWriteTime = $buildStartedAt.AddMinutes(1).LocalDateTime

    # Sentinela Core: velho (< threshold por margem >> 5s) => sentinelFreshSinceBuild=false.
    $sentinel = Join-Path $binDir 'GxNetCoreStartup.dll'
    [System.IO.File]::WriteAllText($sentinel, 'runtime', (Get-Utf8NoBomEncoding))
    (Get-Item -LiteralPath $sentinel).LastWriteTime = $buildStartedAt.AddHours(-1).LocalDateTime

    $classification = Invoke-GeneXusKbDeployBinPostBuildClassification `
        -KbPath $kbNativePath `
        -ValidationEnvironmentName $envName `
        -MetadataPath $metadataPath `
        -DeploymentHostingKind $null `
        -BuildStartedAt $buildStartedAt `
        -BuildOperationallySucceeded $true `
        -PostImportDeployValidation `
        -OperationLabel 'SelfTest'

    # (a) Nao deve lançar — se chegou aqui sem excecao, ok. Sanidade extra do caminho 'fresh'.
    if ($classification.deployBinFreshness -ne 'fresh') {
        throw "ASSERT_FAILED: deployBinFreshness esperado 'fresh', atual=$($classification.deployBinFreshness)"
    }
    if ($classification.statusReclassified) {
        throw "ASSERT_FAILED: caminho fresco nao deve reclassificar status (statusReclassified=$($classification.statusReclassified))"
    }

    $binCheck = $classification.deployBinCheck.binCheck

    # (b) Campos de publicacao presentes no binCheck reportado (trava o fix do parametro IDictionary).
    if (-not $binCheck.Contains('publicationFreshSinceBuild')) {
        throw "ASSERT_FAILED: binCheck reportado nao contem 'publicationFreshSinceBuild' (regressao do fix [System.Collections.IDictionary])"
    }
    if (-not $binCheck.Contains('objectDllCount')) {
        throw "ASSERT_FAILED: binCheck reportado nao contem 'objectDllCount' (regressao do fix [System.Collections.IDictionary])"
    }
    # Os outros dois campos que o catalogo de exit 49 promete (jsonHints): presenca da chave
    # trava a regressao da copia, mesmo com valor $null (sem .config no fixture).
    if (-not $binCheck.Contains('objectDllMaxWriteTime')) {
        throw "ASSERT_FAILED: binCheck reportado nao contem 'objectDllMaxWriteTime' (regressao do fix [System.Collections.IDictionary])"
    }
    if (-not $binCheck.Contains('configMaxWriteTime')) {
        throw "ASSERT_FAILED: binCheck reportado nao contem 'configMaxWriteTime' (regressao do fix [System.Collections.IDictionary])"
    }
    if ($binCheck['publicationFreshSinceBuild'] -ne $true) {
        throw "ASSERT_FAILED: publicationFreshSinceBuild esperado true, atual=$($binCheck['publicationFreshSinceBuild'])"
    }

    # (b) Campos de sentinela presentes (mutados direto; o ramo de warning depende deles).
    if (-not $binCheck.Contains('sentinelFound')) {
        throw "ASSERT_FAILED: binCheck reportado nao contem 'sentinelFound'"
    }
    if (-not $binCheck.Contains('sentinelFreshSinceBuild')) {
        throw "ASSERT_FAILED: binCheck reportado nao contem 'sentinelFreshSinceBuild'"
    }
    if ($binCheck['sentinelFound'] -ne $true) {
        throw "ASSERT_FAILED: sentinelFound esperado true, atual=$($binCheck['sentinelFound'])"
    }
    if ($binCheck['sentinelFreshSinceBuild'] -ne $false) {
        throw "ASSERT_FAILED: sentinelFreshSinceBuild esperado false, atual=$($binCheck['sentinelFreshSinceBuild'])"
    }

    # (c) Warning consultivo do sentinela Core presente.
    $warnings = @($classification.warnings)
    $hasSentinelWarning = @($warnings | Where-Object { $_ -match 'GxNetCoreStartup\.dll' }).Count -gt 0
    if (-not $hasSentinelWarning) {
        throw "ASSERT_FAILED: warning consultivo do GxNetCoreStartup.dll ausente. warnings=$($warnings -join ' | ')"
    }

    'GENEXUS_DEPLOY_BIN_CLASSIFICATION_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
