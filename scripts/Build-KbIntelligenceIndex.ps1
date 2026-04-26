#requires -version 5.1
<#
.SYNOPSIS
    Builds the KB Intelligence SQLite index.

.DESCRIPTION
    Wrapper for Build-KbIntelligenceIndex.py. Keeps paths explicit and avoids
    hardcoded KB-specific locations.

.PARAMETER SourceRoot
    Root folder of the materialized XML catalog, usually ObjetosDaKbEmXml.

.PARAMETER OutputPath
    Destination SQLite database path.

.PARAMETER ValidationReportPath
    Optional JSON validation report path.

.PARAMETER ValidationCasesPath
    Optional JSON file with validation cases for the current KB.

.PARAMETER FailOnValidationFailure
    Return a non-zero exit code when any validation case fails.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$ValidationReportPath,

    [string]$ValidationCasesPath,

    [switch]$FailOnValidationFailure
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$enginePath = Join-Path $scriptDir "Build-KbIntelligenceIndex.py"

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
if ($ValidationCasesPath) {
    $arguments += @("--validation-cases-path", $ValidationCasesPath)
}
if ($FailOnValidationFailure) {
    $arguments += "--fail-on-validation-failure"
}

& $python.Source @arguments
exit $LASTEXITCODE
