#requires -version 5.1
<#
.SYNOPSIS
    Builds the Phase 1 KB Intelligence SQLite index.

.DESCRIPTION
    Wrapper for New-KbIntelligenceIndex.py. Keeps paths explicit and avoids
    hardcoded KB-specific locations.

.PARAMETER SourceRoot
    Root folder of the materialized XML catalog, usually ObjetosDaKbEmXml.

.PARAMETER OutputPath
    Destination SQLite database path.

.PARAMETER ValidationReportPath
    Optional JSON validation report path.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$ValidationReportPath
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$enginePath = Join-Path $scriptDir "New-KbIntelligenceIndex.py"

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
    "--source-root", $SourceRoot,
    "--output-path", $OutputPath
)

if ($ValidationReportPath) {
    $arguments += @("--validation-report-path", $ValidationReportPath)
}

& $python.Source @arguments
exit $LASTEXITCODE
