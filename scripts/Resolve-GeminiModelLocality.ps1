#requires -Version 7.4

<#
.SYNOPSIS
    Classifica o destino de uma chamada ao Gemini CLI.
.DESCRIPTION
    Backend gemini da skill xpz-llm-delegate. O Gemini CLI usa servico externo do Google;
    portanto, a localidade e sempre external. A chave canonica usada pelo gate e
    google/<modelo>, pois o destino operacional e o provider Google.

    Saida: objeto JSON de maquina no stdout.
.PARAMETER Model
    Modelo solicitado ao Gemini CLI. Default: gemini-3-flash-preview, observado no CLI
    validado nesta maquina quando o usuario nao informou -m/--model.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Model = 'gemini-3-flash-preview'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modelParts = @($Model -split '/')
$modelId = $modelParts[$modelParts.Count - 1].Trim()
if ([string]::IsNullOrWhiteSpace($modelId)) { $modelId = 'gemini-3-flash-preview' }

[pscustomobject]@{
    model          = $Model
    modelId        = $modelId
    provider       = 'google'
    baseUrl        = $null
    locality       = 'external'
    canonicalModel = "google/$modelId"
    reason         = 'Gemini CLI usa servico externo do Google; chave por destino google/<modelo>'
} | ConvertTo-Json -Compress
