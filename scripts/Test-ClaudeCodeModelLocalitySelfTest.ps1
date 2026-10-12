#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de Resolve-ClaudeCodeModelLocality.ps1.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = Join-Path $PSScriptRoot 'Resolve-ClaudeCodeModelLocality.ps1'
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "BLOCK: alvo nao encontrado: $target" }

$fail = 0
function Assert-Claude {
    param([string]$Model, [string]$ExpectedLocality, [string]$ExpectedKey)
    $out = & $target -Model $Model | ConvertFrom-Json
    $loc = [string]$out.locality
    $key = [string]$out.canonicalModel
    if ($loc -eq $ExpectedLocality -and $key -eq $ExpectedKey) {
        Write-Host ("PASS  {0,-28} -> {1,-8} key={2}" -f $Model, $loc, $key) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0,-28} -> {1} key={2} (esperado {3} / {4})" -f $Model, $loc, $key, $ExpectedLocality, $ExpectedKey) -ForegroundColor Red
    }
}

Assert-Claude -Model 'opus' -ExpectedLocality 'external' -ExpectedKey 'anthropic/claude-opus-4-8'
Assert-Claude -Model 'claude-opus-4-8' -ExpectedLocality 'external' -ExpectedKey 'anthropic/claude-opus-4-8'
Assert-Claude -Model 'anthropic/claude-opus-4-8' -ExpectedLocality 'external' -ExpectedKey 'anthropic/claude-opus-4-8'
Assert-Claude -Model 'sonnet' -ExpectedLocality 'unknown' -ExpectedKey ''
Assert-Claude -Model 'gpt-5.5' -ExpectedLocality 'unknown' -ExpectedKey ''
Assert-Claude -Model '' -ExpectedLocality 'unknown' -ExpectedKey ''

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-ClaudeCodeModelLocalitySelfTest.ps1" }
Write-Host 'OK: Test-ClaudeCodeModelLocalitySelfTest.ps1' -ForegroundColor Cyan
