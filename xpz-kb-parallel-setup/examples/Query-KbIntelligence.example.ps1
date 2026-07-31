#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para consultar o índice derivado da KB.

.DESCRIPTION
Usa o índice local padrão da pasta paralela da KB e delega a consulta ao motor
compartilhado desta base metodologica.

.PARAMETER Query
Consulta a executar no índice.

.PARAMETER IndexPath
Caminho opcional para um SQLite alternativo. O padrão local aponta para
`KbIntelligence\kb-intelligence.sqlite`.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`. Use este parâmetro quando
o wrapper sanitizado for adaptado para um ambiente com outro caminho local.

.PARAMETER ParallelKbRoot
Raiz da pasta paralela da KB. Por padrão, a pasta pai de `scripts/` deste wrapper.
Usada para resolver `scripts/gx-object-type-catalog.override.json` no gate
`queryableByKbIntelligence` das consultas semanticas.

.PARAMETER CatalogOverridePath
Caminho opcional do override de catalogo (prevalece sobre a deteccao por ParallelKbRoot).

.EXAMPLE
.\Query-KbIntelligence.ps1 -Query impact-basic -ObjectType Procedure -ObjectName procExemplo -Limit 10 -Format text

.EXAMPLE
.\Query-KbIntelligence.ps1 -Query functional-trace-basic -ObjectType Procedure -ObjectName procExemplo -Limit 20 -Format text

.EXAMPLE
.\Query-KbIntelligence.ps1 -Query list-by-type -ObjectType Procedure -Format text

.EXAMPLE
.\Query-KbIntelligence.ps1 -Query index-metadata -Format text
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("object-info", "attribute-info", "search-objects", "list-by-type", "transaction-attributes", "transaction-writable-attributes", "who-uses", "what-uses", "show-evidence", "impact-basic", "functional-trace-basic", "index-metadata", "css-classes", "css-class-usage")]
    [string]$Query,

    [string]$IndexPath,

    [string]$ObjectType,
    [string]$ObjectName,
    [string]$InstanceKey,
    [int]$RelationId,
    [string]$SourceType,
    [string]$SourceName,
    [string]$TargetType,
    [string]$TargetName,
    [string]$Model,
    [string]$Origin,
    [switch]$IncludeImported,
    [switch]$Generated,
    [switch]$Authored,
    [int]$Limit,

    [ValidateSet("json", "text")]
    [string]$Format = "json",

    [string]$ParallelKbRoot,

    [string]$CatalogOverridePath,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\Query-KbIntelligenceIndex.ps1"

if (-not $IndexPath) {
    $IndexPath = Join-Path $repoRoot "KbIntelligence\kb-intelligence.sqlite"
}

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
}

if (-not (Test-Path -LiteralPath $IndexPath)) {
    throw "KB Intelligence index not found: $IndexPath"
}

if (-not $ParallelKbRoot) {
    $ParallelKbRoot = $repoRoot
}

$params = @{
    IndexPath      = $IndexPath
    Query          = $Query
    Format         = $Format
    ParallelKbRoot = $ParallelKbRoot
}

if ($CatalogOverridePath) {
    $params.CatalogOverridePath = $CatalogOverridePath
}

if ($ObjectType) { $params.ObjectType = $ObjectType }
if ($ObjectName) { $params.ObjectName = $ObjectName }
if ($InstanceKey) { $params.InstanceKey = $InstanceKey }
if ($RelationId) { $params.RelationId = $RelationId }
if ($SourceType) { $params.SourceType = $SourceType }
if ($SourceName) { $params.SourceName = $SourceName }
if ($TargetType) { $params.TargetType = $TargetType }
if ($TargetName) { $params.TargetName = $TargetName }
if ($Model) { $params.Model = $Model }
if ($Origin) { $params.Origin = $Origin }
if ($IncludeImported) { $params.IncludeImported = $true }
if ($Generated) { $params.Generated = $true }
if ($Authored) { $params.Authored = $true }
if ($Limit) { $params.Limit = $Limit }

$global:LASTEXITCODE = $null
& $enginePath @params
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
