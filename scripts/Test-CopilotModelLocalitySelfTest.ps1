#requires -Version 7.4
<#
.SYNOPSIS
    Self-test deterministico do resolvedor Copilot da xpz-llm-delegate.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'Resolve-CopilotModelLocality.ps1'
$out = & $target -Model 'gpt-5-mini' | ConvertFrom-Json
if ([string]$out.locality -ne 'external') { throw "BLOCK: locality esperado external; obtido $($out.locality)" }
if ([string]$out.canonicalModel -ne 'github-copilot/gpt-5-mini') { throw "BLOCK: canonicalModel inesperado: $($out.canonicalModel)" }

# Default do resolvedor espelha o default do adapter (auto). O catalogo do Copilot muda entre
# versoes do CLI: em 2026-08-06 o antigo default 'gpt-5-mini' ja era recusado pelo CLI 1.0.78.
# Modelo concreto passado pelo chamador continua valendo (assert acima); o que nao pode voltar
# e um id concreto como DEFAULT.
$def = & $target | ConvertFrom-Json
if ([string]$def.locality -ne 'external') { throw "BLOCK: default: locality esperado external; obtido $($def.locality)" }
if ([string]$def.canonicalModel -ne 'github-copilot/auto') { throw "BLOCK: default deveria ser github-copilot/auto; obtido $($def.canonicalModel)" }

$vazio = & $target -Model '' | ConvertFrom-Json
if ([string]$vazio.canonicalModel -ne 'github-copilot/auto') { throw "BLOCK: modelo vazio deveria cair em github-copilot/auto; obtido $($vazio.canonicalModel)" }

Write-Host 'OK: Test-CopilotModelLocalitySelfTest.ps1' -ForegroundColor Cyan
