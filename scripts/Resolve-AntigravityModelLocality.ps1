#requires -Version 7.4
<#
.SYNOPSIS
    Classifica o destino de uma chamada ao Antigravity CLI (agy).
.DESCRIPTION
    Backend antigravity da skill xpz-llm-delegate. O Antigravity CLI usa servico externo Antigravity;
    portanto, a localidade e sempre external. A chave canonica usada pelo gate e
    antigravity/<modelo>, pois o destino operacional e o provider Antigravity.

    Saida: objeto JSON de maquina no stdout.
.PARAMETER Model
    Modelo solicitado ao Antigravity CLI. Default: gemini-3.6-flash.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Model = 'gemini-3.6-flash'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'LlmDelegateTargetFamilySupport.ps1')

$raw = $Model.Trim()
$modelId = $raw
if ($raw -like 'antigravity/*') {
    $modelId = ($raw -split '/', 2)[1].Trim()
}
if ([string]::IsNullOrWhiteSpace($modelId)) { $modelId = 'gemini-3.6-flash' }

$canonicalModel = "antigravity/$modelId"
$family = Get-LlmDelegateTargetFamily -TargetModelKey $canonicalModel

[pscustomobject]@{
    model          = $Model
    modelId        = $modelId
    provider       = 'antigravity'
    family         = $family
    baseUrl        = $null
    locality       = 'external'
    canonicalModel = $canonicalModel
    reason         = 'Antigravity CLI usa servico externo Antigravity; chave por destino antigravity/<modelo>'
} | ConvertTo-Json -Compress
