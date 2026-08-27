#requires -Version 7.4
<#
.SYNOPSIS
    Classifica a localidade de um destino orchestrator-native (subagente nativo).
.DESCRIPTION
    Backend orchestrator-native da skill xpz-llm-delegate. Shape identico ao
    Resolve-AntigravityModelLocality (inclui baseUrl=$null) para o gate nao ramificar.
    Localidade = destino da chave targetModelKey, nunca "in-process = local".
    Nesta frente nunca devolve locality=local.
.PARAMETER Model
    targetModelKey (criador/modelo).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Model
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'LlmDelegateTargetFamilySupport.ps1')

$raw = if ($null -eq $Model) { '' } else { $Model.Trim() }
$parts = @($raw -split '/')
$modelId = if ($parts.Count -ge 2) { $parts[-1] } else { $raw }
$provider = if ($parts.Count -ge 2) { $parts[0] } else { $raw }
$family = Get-LlmDelegateTargetFamily -TargetModelKey $raw

$locality = 'unknown'
$reason = 'native-unknown-family'

$first = if ($parts.Count -ge 1) { $parts[0] } else { '' }
if ($first.Equals('cursor', [System.StringComparison]::OrdinalIgnoreCase)) {
    $locality = 'unknown'
    $reason = 'native-cursor-prefix'
} elseif ($raw -notmatch '/') {
    $locality = 'unknown'
    $reason = 'native-key-no-slash'
} elseif (-not (Test-LlmDelegateFamilyKnown -Family $family)) {
    $locality = 'unknown'
    $reason = 'native-unknown-family'
} else {
    $locality = 'external'
    $reason = 'native-cloud-creator'
}

[pscustomobject]@{
    model          = $Model
    modelId        = $modelId
    provider       = $provider
    family         = $family
    baseUrl        = $null
    locality       = $locality
    canonicalModel = $raw
    reason         = $reason
} | ConvertTo-Json -Compress
