#requires -Version 7.4

<#
.SYNOPSIS
Wrapper local sanitizado para abrir frente XPZ na pasta paralela da KB.

.DESCRIPTION
Delega ao motor compartilhado `New-GeneXusXpzFront.ps1`, criando ou reutilizando
uma subpasta em `ObjetosGeradosParaImportacaoNaKbNoGenexus` no formato
`NomeCurto_GUID_YYYYMMDD`. Use este wrapper quando o agente precisar abrir uma
frente com comando curto e atômico, sem montar PowerShell composto no chamador.

.PARAMETER NomeCurto
Identificador curto da frente. Deve casar com [A-Za-z][A-Za-z0-9]{2,40}.

.PARAMETER ExtraGuidCount
Quantidade de GUIDs adicionais a devolver para objetos novos do lote.

.PARAMETER ReuseIfExists
Reutiliza uma frente existente com o mesmo NomeCurto quando houver exatamente
uma correspondencia.

.PARAMETER AsJson
Retorna saida JSON estruturada.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$NomeCurto,

    [ValidateRange(0, 1000)]
    [int]$ExtraGuidCount = 0,

    [switch]$ReuseIfExists,

    [switch]$AsJson,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $SharedSkillsRoot "scripts\New-GeneXusXpzFront.ps1"

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared front script not found: $enginePath"
}

$argsForEngine = @{
    RepoRoot        = $repoRoot
    NomeCurto       = $NomeCurto
    ExtraGuidCount  = $ExtraGuidCount
}

if ($ReuseIfExists) {
    $argsForEngine.ReuseIfExists = $true
}

if ($AsJson) {
    $argsForEngine.AsJson = $true
}

& $enginePath @argsForEngine
