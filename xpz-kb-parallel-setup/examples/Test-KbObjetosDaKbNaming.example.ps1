#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para auditar o naming de ObjetosDaKbEmXml.

.DESCRIPTION
Delega ao motor compartilhado `Test-XpzObjetosDaKbNaming.ps1`.
Este wrapper e somente leitura: ele não renomeia diretórios nem altera XMLs.

.PARAMETER KbRoot
Caminho opcional para a raiz da pasta paralela da KB.
Quando omitido, usa a pasta pai de `scripts`.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.PARAMETER AsJson
Emite JSON estruturado.

.EXAMPLE
.\Test-KbObjetosDaKbNaming.ps1
#>

param(
    [string]$KbRoot,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills",

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $KbRoot) {
    $KbRoot = Split-Path -Parent $PSScriptRoot
}

$enginePath = Join-Path $SharedSkillsRoot 'scripts\Test-XpzObjetosDaKbNaming.ps1'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared naming audit script not found: $enginePath"
}

$global:LASTEXITCODE = $null
& $enginePath -ParallelKbRoot $KbRoot -AsJson:$AsJson
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
