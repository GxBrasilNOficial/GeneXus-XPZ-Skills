<#
.SYNOPSIS
Wrapper local sanitizado para conferência completa de um export full da KB.

.DESCRIPTION
Reaproveita o wrapper diário em modo somente verificação, com comparação do
snapshot completo mantido em `ObjetosDaKbEmXml`.

.PARAMETER ExpectedItems
Lista opcional de itens esperados no formato `Tipo:Nome`, repassada ao wrapper
diário para comparar foco esperado versus retorno oficial da KB.

.EXAMPLE
.\Test-KbFullSnapshot.ps1 -InputPath C:\Exports\FullKb.xpz -ExpectedItems 'Transaction:Cliente'

.EXAMPLE
.\Test-KbFullSnapshot.ps1 -InputPath C:\Exports\FullKb.xpz -ExpectedItems 'Transaction:Cliente', 'Procedure:GeraBoleto'
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$ReportPath,

    [string[]]$ExpectedItems = @(),

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

if ($ExpectedItems.Count -gt 0) {
    $params.ExpectedItems = @($ExpectedItems)
}

& $wrapperPath @params
