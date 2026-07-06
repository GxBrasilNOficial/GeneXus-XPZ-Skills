#requires -Version 7.4
<#
.SYNOPSIS
    Diagnostico somente leitura de frescor da publicacao do environment de deploy (Eixo A), por familia
    de deployment_hosting_kind (.NET: web\bin; java-tomcat: co-gate Java no WEB-INF\classes externo).

.DESCRIPTION
    Complementa Test-GeneXusRuntimeFreshness.ps1 (CSharpModel compartilhado). Fia o registro de hosting
    kinds e discrimina pelo predicado do Eixo A (runsDeployBinEngine): .NET verifica artefatos no web\bin
    mapeado por kb_environment_web_dirs; java-tomcat (Eixo A supported) roteia ao dispatcher por familia
    (Test-GeneXusKbDeployBinFreshnessCore -> co-gate Java no WEB-INF\classes externo). Valor fora do
    registro -> mensagem canonica.

.PARAMETER KbPath
    Caminho da KB GeneXus nativa.

.PARAMETER EnvironmentName
    Nome do environment de deploy. Se omitido, usa deployment_environment_name do metadata.

.PARAMETER BuildStartedAt
    Timestamp ISO de inicio do build usado como linha de corte. Opcional quando
    -BuildResultJsonPath for informado; se ambos vierem, -BuildStartedAt prevalece.

.PARAMETER BuildResultJsonPath
    Caminho do JSON de um build (Invoke-GeneXusKbBuildAll.ps1 / Invoke-GeneXusKbSpecifyGenerate.ps1).
    Quando informado e -BuildStartedAt for omitido, a linha de corte vem de timing.msbuildStart
    do próprio build — elimina a extracao manual do timestamp.

.PARAMETER ParallelKbRoot
    Raiz da pasta paralela para resolver kb-source-metadata.md.

.PARAMETER KbMetadataPath
    Caminho explicito para kb-source-metadata.md.

.PARAMETER DeploymentHostingKind
    Quando informado, prevalece sobre o valor do metadata.

.PARAMETER AsJson
    Emite JSON estruturado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [string]$EnvironmentName,

    [string]$BuildStartedAt,

    [string]$BuildResultJsonPath,

    [string]$ParallelKbRoot,

    [string]$KbMetadataPath,

    [string]$DeploymentHostingKind,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusKbDeployBinSupport.ps1')
# Fase 2 (paridade Java/Tomcat): registro-fonte-unica dos hosting kinds (dot-source explicito,
# alem do transitivo via GeneXusKbDeployBinSupport.ps1 — idempotente).
. (Join-Path $PSScriptRoot 'GeneXusKbHostingKindSupport.ps1')

$kbPathResolved = [System.IO.Path]::GetFullPath($KbPath)
if (-not (Test-Path -LiteralPath $kbPathResolved -PathType Container)) {
    throw "KbPath invalido: $kbPathResolved"
}

$metadataPathResolved = Resolve-GeneXusKbSourceMetadataPath -KbMetadataPath $KbMetadataPath -ParallelKbRoot $ParallelKbRoot
$fields = $null
if ($metadataPathResolved) {
    $fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $metadataPathResolved
}

$validationEnvironment = $EnvironmentName
if ([string]::IsNullOrWhiteSpace($validationEnvironment) -and $null -ne $fields) {
    $validationEnvironment = $fields.deployment_environment_name
}

$hostingKind = $DeploymentHostingKind
if ([string]::IsNullOrWhiteSpace($hostingKind) -and $null -ne $fields) {
    $hostingKind = $fields.deployment_hosting_kind
}

# Linha de corte: -BuildStartedAt explicito prevalece; senao vem de timing.msbuildStart
# do JSON do build (-BuildResultJsonPath), eliminando a extracao manual do timestamp.
$buildStartedAtRaw = $BuildStartedAt
$buildStartedAtSource = 'parameter'
if ([string]::IsNullOrWhiteSpace($buildStartedAtRaw)) {
    if ([string]::IsNullOrWhiteSpace($BuildResultJsonPath)) {
        throw 'Informe -BuildStartedAt (timestamp ISO) ou -BuildResultJsonPath (JSON de build com timing.msbuildStart).'
    }
    if (-not (Test-Path -LiteralPath $BuildResultJsonPath -PathType Leaf)) {
        throw "BuildResultJsonPath invalido: $BuildResultJsonPath"
    }
    $buildJson = (Get-Content -LiteralPath $BuildResultJsonPath -Raw) | ConvertFrom-Json
    $msbuildStartValue = $null
    if ($null -ne $buildJson.PSObject.Properties['timing'] -and $null -ne $buildJson.timing -and
        $null -ne $buildJson.timing.PSObject.Properties['msbuildStart']) {
        $msbuildStartValue = $buildJson.timing.msbuildStart
    }
    # ConvertFrom-Json auto-converte string ISO para [datetime] local; normalizar para ISO
    # preservando o instante, sem round-trip dependente de cultura.
    if ($msbuildStartValue -is [datetime]) {
        $buildStartedAtRaw = ([DateTimeOffset]$msbuildStartValue).ToString('o')
    }
    elseif ($msbuildStartValue -is [System.DateTimeOffset]) {
        $buildStartedAtRaw = $msbuildStartValue.ToString('o')
    }
    else {
        $buildStartedAtRaw = [string]$msbuildStartValue
    }
    if ([string]::IsNullOrWhiteSpace($buildStartedAtRaw)) {
        throw "timing.msbuildStart ausente ou vazio em: $BuildResultJsonPath"
    }
    $buildStartedAtSource = 'build-json'
}

try {
    $buildStartedAtDt = [DateTimeOffset]::Parse($buildStartedAtRaw)
}
catch {
    throw "BuildStartedAt nao e timestamp valido: '$buildStartedAtRaw'"
}

$result = [ordered]@{
    status                    = 'skipped'
    validationEnvironmentName = $validationEnvironment
    deploymentHostingKind     = $hostingKind
    metadataPath              = $metadataPathResolved
    buildStartedAt            = $buildStartedAtDt.ToString('o')
    buildStartedAtSource      = $buildStartedAtSource
    deployBinCheck            = $null
    summary                   = ''
}

# Fase 2/3: lookup do registro uma vez (guard de vazio T1: so consulta quando presente; vazio cai no
# ramo 'ausente' abaixo). Esta e a fachada do Eixo A (deploy-bin); discrimina pelo campo DO SEU EIXO
# ($rec.runsDeployBinEngine), nao pelo alias legado runsFreshnessEngine.
$rec = $null
if (-not [string]::IsNullOrWhiteSpace($hostingKind)) {
    $rec = Get-GeneXusKbHostingKindSupportRecord -HostingKind $hostingKind
}

if ([string]::IsNullOrWhiteSpace($validationEnvironment)) {
    $result.summary = 'Environment de deploy nao informado e deployment_environment_name ausente no metadata.'
}
elseif ([string]::IsNullOrWhiteSpace($hostingKind)) {
    $result.summary = 'deployment_hosting_kind ausente; gravar via xpz-kb-parallel-setup.'
}
elseif ($null -eq $rec) {
    # presente-e-fora-do-registro: rejeicao com a mensagem canonica (fonte-unica das chaves).
    $result.summary = Get-GeneXusKbHostingKindSupportInvalidValueMessage -HostingKind $hostingKind
}
elseif (-not $rec.runsDeployBinEngine) {
    # recognized-no-engine / blocked-out-of-scope no Eixo A: skip DERIVADO do registro (campos do
    # Eixo A; nunca redigitado).
    $result.status = $rec.deployBinSkipStatus
    $result.summary = $rec.deployBinUnsupportedReason
}
else {
    $freshness = Test-GeneXusKbDeployBinFreshnessCore `
        -KbPath $kbPathResolved `
        -EnvironmentName $validationEnvironment `
        -DeploymentHostingKind $hostingKind `
        -BuildStartedAt $buildStartedAtDt `
        -MetadataPath $metadataPathResolved

    $result.status = $freshness.status
    $result.deployBinCheck = [ordered]@{
        paths           = $freshness.paths
        binCheck        = $freshness.binCheck
        diagnosticLayer = $freshness.diagnosticLayer
        interpretation  = $freshness.interpretation
        thresholdAt     = $freshness.thresholdAt
    }
    $result.summary = $freshness.interpretation
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
}
else {
    Write-Output ("deploy-bin-{0}: env={1} hosting={2} — {3}" -f $result.status, $validationEnvironment, $hostingKind, $result.summary)
}
