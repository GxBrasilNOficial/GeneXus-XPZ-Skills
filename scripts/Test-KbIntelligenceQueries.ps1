#requires -Version 7.4

<#
.SYNOPSIS
    Validates KB Intelligence query behavior against small JSON case files.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$IndexPath,

    [Parameter(Mandatory = $true)]
    [string]$ValidationCasesPath,

    [string]$ValidationReportPath,

    [switch]$FailOnValidationFailure
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$enginePath = Join-Path $scriptDir "Test-KbIntelligenceQueries.py"

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
    "--validation-cases-path", $ValidationCasesPath
)

if ($ValidationReportPath) { $arguments += @("--validation-report-path", $ValidationReportPath) }
if ($FailOnValidationFailure) { $arguments += @("--fail-on-validation-failure") }

& $python.Source @arguments
exit $LASTEXITCODE
