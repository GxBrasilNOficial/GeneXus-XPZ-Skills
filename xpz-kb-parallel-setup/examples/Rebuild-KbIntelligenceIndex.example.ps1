#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para rebuild completo do índice derivado da KB.

.DESCRIPTION
Destroi e recria o SQLite do zero a partir de ObjetosDaKbEmXml, delegando a
construcao e validação ao motor compartilhado desta base metodologica.
Não existe modo incremental — a cada execução e um rebuild completo.

.PARAMETER SourceRoot
Raiz opcional do snapshot XML oficial da KB.

.PARAMETER OutputPath
Caminho opcional do SQLite derivado.

.PARAMETER ValidationReportPath
Caminho opcional para salvar o relatório JSON de validação.

.PARAMETER ValidationCasesPath
Caminho opcional para os casos de validação.

.PARAMETER FailOnValidationFailure
Retorna erro quando qualquer caso de validação falhar.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`. Use este parâmetro quando
o wrapper sanitizado for adaptado para um ambiente com outro caminho local.

.EXAMPLE
.\Rebuild-KbIntelligenceIndex.ps1 -FailOnValidationFailure

.EXAMPLE
.\Rebuild-KbIntelligenceIndex.ps1 -ValidationCasesPath "C:\CAMINHO\PARA\casos-validacao.json" -FailOnValidationFailure
#>

param(
    [string]$SourceRoot,

    [string]$OutputPath,

    [string]$ValidationReportPath,

    [string]$ValidationCasesPath,

    [switch]$FailOnValidationFailure,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\Build-KbIntelligenceIndex.ps1"

if (-not $SourceRoot) {
    $SourceRoot = Join-Path $repoRoot "ObjetosDaKbEmXml"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot "KbIntelligence\kb-intelligence.sqlite"
}

if (-not $ValidationReportPath) {
    $ValidationReportPath = Join-Path $repoRoot "KbIntelligence\kb-intelligence-validation.json"
}

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
}

if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "Source root not found: $SourceRoot"
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    throw "Output directory not found: $outputDirectory"
}

$validationDirectory = Split-Path -Parent $ValidationReportPath
if (-not (Test-Path -LiteralPath $validationDirectory)) {
    throw "Validation report directory not found: $validationDirectory"
}

if ($ValidationCasesPath -and -not (Test-Path -LiteralPath $ValidationCasesPath)) {
    throw "Validation cases file not found: $ValidationCasesPath"
}

$params = @{
    SourceRoot           = $SourceRoot
    OutputPath           = $OutputPath
    ValidationReportPath = $ValidationReportPath
    ParallelKbRoot       = $repoRoot
}

if ($ValidationCasesPath) {
    $params.ValidationCasesPath = $ValidationCasesPath
}

if ($FailOnValidationFailure) {
    $params.FailOnValidationFailure = $true
}

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
