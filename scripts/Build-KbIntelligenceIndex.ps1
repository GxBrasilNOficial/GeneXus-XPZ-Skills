#requires -Version 7.4
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

.PARAMETER ParallelKbRoot
    Raiz da pasta paralela da KB; resolve scripts/gx-object-type-catalog.override.json quando existir.

.PARAMETER CatalogOverridePath
    Caminho explicito do override local; prevalece sobre a deteccao automática pela pasta paralela.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$ValidationReportPath,

    [string]$ValidationCasesPath,

    [switch]$FailOnValidationFailure,

    [string]$ParallelKbRoot,

    [string]$CatalogOverridePath
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'GeneXusPythonPrerequisite.ps1')

$enginePath = Join-Path $scriptDir "Build-KbIntelligenceIndex.py"

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
}

$python = Get-GeneXusPythonExecutable
if ($null -eq $python) {
    Write-Host (Get-GeneXusPythonPrerequisiteErrorMessage) -ForegroundColor Red
    exit 8
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
if ($ParallelKbRoot) {
    $arguments += @("--parallel-kb-root", $ParallelKbRoot)
}
if ($CatalogOverridePath) {
    $arguments += @("--catalog-override-path", $CatalogOverridePath)
}

$output = @(& $python.Source @arguments 2>&1)
$engineExitCode = $LASTEXITCODE

if ($output.Count -gt 0) {
    $output | ForEach-Object { Write-Output $_ }
}

if ($engineExitCode -ne 0) {
    exit $engineExitCode
}

exit 0
