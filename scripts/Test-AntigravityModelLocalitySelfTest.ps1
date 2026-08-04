#requires -Version 7.4
<#
.SYNOPSIS
    Autoteste do resolvedor Resolve-AntigravityModelLocality.ps1.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script = Join-Path $PSScriptRoot 'Resolve-AntigravityModelLocality.ps1'

$passed = 0
$failed = 0

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -eq $Expected) {
        $script:passed++
        Write-Host "[PASS] $Message" -ForegroundColor Green
    } else {
        $script:failed++
        Write-Host "[FAIL] $Message (esperado '$Expected', obtido '$Actual')" -ForegroundColor Red
    }
}

# 1. Default (gemini-3.6-flash-high)
$res1 = & $script | ConvertFrom-Json
Assert-Equal $res1.provider 'antigravity' "Provider e antigravity"
Assert-Equal $res1.canonicalModel 'antigravity/gemini-3.6-flash-high' "CanonicalModel e antigravity/gemini-3.6-flash-high"
Assert-Equal $res1.family 'google' "Familia e google"
Assert-Equal $res1.locality 'external' "Localidade e external"

# 2. Claude
$res2 = & $script -Model 'antigravity/claude-sonnet-4-6' | ConvertFrom-Json
Assert-Equal $res2.canonicalModel 'antigravity/claude-sonnet-4-6' "CanonicalModel e antigravity/claude-sonnet-4-6"
Assert-Equal $res2.family 'anthropic' "Familia e anthropic"

# 3. GPT
$res3 = & $script -Model 'gpt-oss-120b-medium' | ConvertFrom-Json
Assert-Equal $res3.canonicalModel 'antigravity/gpt-oss-120b-medium' "CanonicalModel e antigravity/gpt-oss-120b-medium"
Assert-Equal $res3.family 'openai' "Familia e openai"

Write-Host "Resultado do autoteste: $passed passou, $failed falhou."
if ($failed -gt 0) { exit 1 }
Write-Host "OK: Test-AntigravityModelLocalitySelfTest.ps1"

