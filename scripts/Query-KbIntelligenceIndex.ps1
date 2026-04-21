#requires -version 5.1
<#
.SYNOPSIS
    Queries a Phase 1 KB Intelligence SQLite index.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$IndexPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("object-info", "search-objects", "who-uses", "what-uses", "show-evidence")]
    [string]$Query,

    [string]$ObjectType,
    [string]$ObjectName,
    [int]$RelationId,
    [string]$SourceType,
    [string]$SourceName,
    [string]$TargetType,
    [string]$TargetName,
    [int]$Limit,
    [ValidateSet("json", "text")]
    [string]$Format = "json"
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
if ($RelationId) { $arguments += @("--relation-id", $RelationId) }
if ($SourceType) { $arguments += @("--source-type", $SourceType) }
if ($SourceName) { $arguments += @("--source-name", $SourceName) }
if ($TargetType) { $arguments += @("--target-type", $TargetType) }
if ($TargetName) { $arguments += @("--target-name", $TargetName) }
if ($Limit) { $arguments += @("--limit", $Limit) }
if ($Format) { $arguments += @("--format", $Format) }

& $python.Source @arguments
exit $LASTEXITCODE
