<#
.SYNOPSIS
Wrapper local sanitizado para conferência completa de um export full da KB.

.DESCRIPTION
Reaproveita o wrapper diário em modo somente verificação, com comparação do
snapshot completo mantido em `ObjetosDaKbEmXml`.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$ReportPath,

    [switch]$KeepReport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$wrapperPath = Join-Path $scriptRoot "Update-KbFromXpz.ps1"

if (-not (Test-Path -LiteralPath $wrapperPath)) {
    throw "Wrapper script not found: $wrapperPath"
}

$params = @{
    InputPath = $InputPath
    VerifyOnly = $true
    FullSnapshot = $true
}

if ($ReportPath) {
    $params.ReportPath = $ReportPath
}

if ($KeepReport) {
    $params.KeepReport = $true
}

& $wrapperPath @params
