#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico do resolvedor Gemini da xpz-llm-delegate.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'Resolve-GeminiModelLocality.ps1'
$out = & $target -Model 'gemini-3-flash-preview' | ConvertFrom-Json
if ([string]$out.locality -ne 'external') { throw "BLOCK: locality esperado external; obtido $($out.locality)" }
if ([string]$out.canonicalModel -ne 'google/gemini-3-flash-preview') { throw "BLOCK: canonicalModel inesperado: $($out.canonicalModel)" }

Write-Host 'OK: Test-GeminiModelLocalitySelfTest.ps1' -ForegroundColor Cyan
