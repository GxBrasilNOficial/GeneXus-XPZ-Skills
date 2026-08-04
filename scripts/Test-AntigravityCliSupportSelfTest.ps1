#requires -Version 7.4
<#
.SYNOPSIS
    Autoteste do modulo AntigravityCliSupport.ps1.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'AntigravityCliSupport.ps1')

$passed = 0
$failed = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if ($Condition) {
        $script:passed++
        Write-Host "[PASS] $Message" -ForegroundColor Green
    } else {
        $script:failed++
        Write-Host "[FAIL] $Message" -ForegroundColor Red
    }
}

# 1. Test-AntigravityHelpSupportsContract
$helpValid = "Usage of agy: --print Run a prompt --mode Set agent mode"
Assert-True (Test-AntigravityHelpSupportsContract -HelpText $helpValid) "Reconhece help com --print e --mode"

$helpInvalid = "Usage of agy: --something else"
Assert-True (-not (Test-AntigravityHelpSupportsContract -HelpText $helpInvalid)) "Rejeita help sem flags requeridas"

# 2. Get-AntigravityErrorMessage
$errText = Get-AntigravityErrorMessage -StdoutText "" -StderrText "Error 429: rate limit exceeded for resource"
Assert-True ($errText -like "*429*") "Extrai mensagem de erro de cota/rate limit"

# 3. Quota failure pattern
Assert-True ("quota exceeded" -match $quotaFailurePattern) "Regex de cota reconhece 'quota exceeded'"
Assert-True ("429 Too Many Requests" -match $quotaFailurePattern) "Regex de cota reconhece 429 / Too Many Requests"

# 4. Resolve-AntigravityExe
try {
    $exe = Resolve-AntigravityExe
    Assert-True (Test-Path -LiteralPath $exe -PathType Leaf) "Resolve executavel agy.exe no sistema ($exe)"
} catch {
    Assert-True $false "Falha ao resolver agy.exe: $($_.Exception.Message)"
}

Write-Host "Resultado do autoteste: $passed passou, $failed falhou."
if ($failed -gt 0) { exit 1 }
