#requires -Version 7.4

<#
.SYNOPSIS
    Classifica uma invocacao do Claude Code como destino externo Anthropic e devolve a
    chave canonica provider/modelo usada pelo gate de confidencialidade.
.DESCRIPTION
    Backend claude-code da skill xpz-llm-delegate. Claude Code, no uso coberto por este
    adapter, envia trafego para Anthropic; portanto modelos Claude conhecidos sao externos.

    A chave de politica e sempre o destino: anthropic/<modelo>. O adapter nunca entra na
    chave. Alias volateis sao tratados de forma conservadora: somente `opus` e normalizado
    aqui para `claude-opus-4-8`, porque este e o objetivo explicito da frente; outros aliases
    nus ficam unknown para evitar politica ambigua.

    Saida: JSON compacto com locality, provider, canonicalModel e reason.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Model = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$raw = $Model.Trim()
$modelId = $raw
if ($raw -like 'anthropic/*') {
    $modelId = ($raw -split '/', 2)[1]
}

$canonicalModel = $null
$locality = 'unknown'
$provider = $null
$reason = ''

if ([string]::IsNullOrWhiteSpace($modelId)) {
    $reason = "modelo nao informado; destino desconhecido (fail-closed no gate: payload kb-sensitive -> ask, public -> allow)"
}
elseif ($modelId -ieq 'opus') {
    $provider = 'anthropic'
    $modelId = 'claude-opus-4-8'
    $canonicalModel = 'anthropic/claude-opus-4-8'
    $locality = 'external'
    $reason = "alias 'opus' normalizado para Claude Opus 4.8; destino Anthropic externo"
}
elseif ($modelId -match '^claude-[a-z0-9][a-z0-9\-]*$') {
    $provider = 'anthropic'
    $canonicalModel = "anthropic/$modelId"
    $locality = 'external'
    $reason = "modelo Claude explicito; destino Anthropic externo"
}
else {
    $reason = "modelo '$Model' nao reconhecido como Claude explicito; localidade desconhecida (fail-closed no gate para payload sensivel)"
}

[pscustomobject]@{
    model          = $Model
    modelId        = $modelId
    provider       = $provider
    baseUrl        = $null
    locality       = $locality
    canonicalModel = $canonicalModel
    reason         = $reason
} | ConvertTo-Json -Compress
