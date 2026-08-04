#requires -Version 7.4
<#
.SYNOPSIS
    Autoteste do modulo AntigravityCliSupport.ps1 e prova comportamental de Invoke-Antigravity.ps1.
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
$helpValid = "Usage of agy: -p Run a prompt --mode Set agent mode"
Assert-True (Test-AntigravityHelpSupportsContract -HelpText $helpValid) "Reconhece help com -p e --mode"

$helpSubstringOnly = "Usage of agy: --project Add project --prompt-interactive Run prompt"
Assert-True (-not (Test-AntigravityHelpSupportsContract -HelpText $helpSubstringOnly)) "Rejeita help com -p apenas como substring em --project"

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

# 5. Prova Comportamental: Injeção de fake-exe via -AntigravityExe para Invoke-Antigravity.ps1
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ('agy-fake-test-' + [System.Guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($tempDir)

try {
    $fakePs1 = Join-Path $tempDir 'fake-agy-reader.ps1'
    @'
param()
if ($args -contains '--help') {
    "Usage of agy: -p Run a prompt --mode Set agent mode --output-format json"
    exit 0
}
$promptIdx = [array]::IndexOf($args, '-p')
$promptVal = if ($promptIdx -ge 0 -and $promptIdx + 1 -lt $args.Count) { $args[$promptIdx + 1] } else { '' }
$resp = @{
    status = "SUCCESS"
    response = "FAKE_AGY_RESPONSE: $promptVal"
} | ConvertTo-Json -Compress
Write-Output $resp
exit 0
'@ | Set-Content -LiteralPath $fakePs1 -Encoding utf8

    $fakeCmd = Join-Path $tempDir 'fake-agy.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-agy-reader.ps1" %*
'@ | Set-Content -LiteralPath $fakeCmd -Encoding ascii

    $invokeScript = Join-Path $PSScriptRoot 'Invoke-Antigravity.ps1'
    $promptFile = Join-Path $tempDir 'prompt.txt'
    Set-Content -LiteralPath $promptFile -Value 'Teste de prompt via MessagePath' -Encoding utf8

    $output = & $invokeScript -AntigravityExe $fakeCmd -MessagePath $promptFile -Model 'gemini-3.6-flash-high' -Mode plan
    Assert-True ($output -eq 'FAKE_AGY_RESPONSE: Teste de prompt via MessagePath') "Invoke-Antigravity.ps1 via fake-exe parseou JSON e retornou resposta (.response)"
} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Resultado do autoteste: $passed passou, $failed falhou."
if ($failed -gt 0) { exit 1 }
