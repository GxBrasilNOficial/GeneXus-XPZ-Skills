#requires -Version 7.4
<#
.SYNOPSIS
    Queries a KB Intelligence SQLite index.

.PARAMETER Origin
Filtra resultados de css-classes, list-by-type ou search-objects por kb-authored ou packaged-module.

.PARAMETER IncludeImported
Remove o filtro padrão kb-authored em css-classes, list-by-type e search-objects por instance-key. Não altera buscas por nome.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$IndexPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("object-info", "attribute-info", "search-objects", "list-by-type", "transaction-attributes", "transaction-writable-attributes", "who-uses", "what-uses", "show-evidence", "impact-basic", "functional-trace-basic", "index-metadata", "css-classes", "css-class-usage")]
    [string]$Query,

    [string]$ObjectType,
    [string]$ObjectName,
    [string]$InstanceKey,
    [int]$RelationId,
    [string]$SourceType,
    [string]$SourceName,
    [string]$TargetType,
    [string]$TargetName,
    [string]$Model,
    [ValidateSet("kb-authored", "packaged-module")]
    [string]$Origin,
    [switch]$IncludeImported,
    [switch]$Generated,
    [switch]$Authored,
    [int]$Limit,
    [ValidateSet("json", "text")]
    [string]$Format = "json",

    [string]$ParallelKbRoot,

    [string]$CatalogOverridePath
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$enginePath = Join-Path $scriptDir "Query-KbIntelligenceIndex.py"

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw "Python was not found in PATH. Python 3 with sqlite3 is required."
}

$arguments = @(
    $enginePath,
    "--index-path", $IndexPath,
    "--query", $Query
)

if ($ObjectType) { $arguments += @("--object-type", $ObjectType) }
if ($ObjectName) { $arguments += @("--object-name", $ObjectName) }
if ($InstanceKey) { $arguments += @("--instance-key", $InstanceKey) }
if ($RelationId) { $arguments += @("--relation-id", $RelationId) }
if ($SourceType) { $arguments += @("--source-type", $SourceType) }
if ($SourceName) { $arguments += @("--source-name", $SourceName) }
if ($TargetType) { $arguments += @("--target-type", $TargetType) }
if ($TargetName) { $arguments += @("--target-name", $TargetName) }
if ($Model) { $arguments += @("--model", $Model) }
if ($Origin) { $arguments += @("--origin", $Origin) }
if ($IncludeImported) { $arguments += @("--include-imported") }
if ($Generated) { $arguments += @("--generated") }
if ($Authored) { $arguments += @("--authored") }
if ($Limit) { $arguments += @("--limit", $Limit) }
if ($Format) { $arguments += @("--format", $Format) }
if ($ParallelKbRoot) { $arguments += @("--parallel-kb-root", $ParallelKbRoot) }
if ($CatalogOverridePath) { $arguments += @("--catalog-override-path", $CatalogOverridePath) }

$previousPythonIoEncoding = [Environment]::GetEnvironmentVariable("PYTHONIOENCODING", "Process")
$exitCode = 1
try {
    $env:PYTHONIOENCODING = [Console]::OutputEncoding.WebName
    & $python.Source @arguments
    $exitCode = $LASTEXITCODE
}
finally {
    [Environment]::SetEnvironmentVariable("PYTHONIOENCODING", $previousPythonIoEncoding, "Process")
}

exit $exitCode
