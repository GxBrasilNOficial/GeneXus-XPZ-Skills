#requires -Version 7.4

<#
.SYNOPSIS
Wrapper local sanitizado para obter timestamp GeneXus lastUpdate.

.DESCRIPTION
Delega ao motor compartilhado `Get-GeneXusXpzLastUpdate.ps1`, retornando o
timestamp UTC canonico no formato usado por `Object/@lastUpdate`.

.PARAMETER Count
Quantidade de timestamps a devolver. Default: 1.

.PARAMETER BaselineXmlPath
Caminho opcional para XML oficial do acervo. Quando informado, o motor retorna
max(UtcNow + margem, baseline lastUpdate + margem).

.PARAMETER FreshnessMarginSeconds
Margem aplicada sobre UtcNow e sobre o baseline. Default: 60.

.PARAMETER AsJson
Retorna saida JSON estruturada.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.
#>

param(
    [ValidateRange(1, 1000)]
    [int]$Count = 1,

    [string]$BaselineXmlPath,

    [ValidateRange(1, 3600)]
    [int]$FreshnessMarginSeconds = 60,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$enginePath = Join-Path $SharedSkillsRoot "scripts\Get-GeneXusXpzLastUpdate.ps1"

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared lastUpdate script not found: $enginePath"
}

$argsForEngine = @{
    Count                  = $Count
    FreshnessMarginSeconds = $FreshnessMarginSeconds
}

if (-not [string]::IsNullOrWhiteSpace($BaselineXmlPath)) {
    $argsForEngine.BaselineXmlPath = $BaselineXmlPath
}

if ($AsJson) {
    $argsForEngine.AsJson = $true
}

& $enginePath @argsForEngine
