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

# 5. Prova Comportamental: Injeção de fake-exe (JSON) via -AntigravityExe para Invoke-Antigravity.ps1
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

    # 6. Prova Comportamental: Injeção de fake-exe que retorna TEXTO PURO (não-JSON) para validar fallback sem estourar tipo
    $fakeRawPs1 = Join-Path $tempDir 'fake-agy-raw.ps1'
    @'
param()
if ($args -contains '--help') {
    "Usage of agy: -p Run a prompt --mode Set agent mode"
    exit 0
}
Write-Output "RESPOSTA_EM_TEXTO_BRUTO_SEM_JSON"
exit 0
'@ | Set-Content -LiteralPath $fakeRawPs1 -Encoding utf8

    $fakeRawCmd = Join-Path $tempDir 'fake-agy-raw.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-agy-raw.ps1" %*
'@ | Set-Content -LiteralPath $fakeRawCmd -Encoding ascii

    $rawOutput = & $invokeScript -AntigravityExe $fakeRawCmd -Message 'Teste texto puro' -Model 'gemini-3.6-flash-high' -Mode plan
    Assert-True ($rawOutput -eq 'RESPOSTA_EM_TEXTO_BRUTO_SEM_JSON') "Invoke-Antigravity.ps1 via fake-exe de texto puro ativou fallback sem excecao de tipo"

    # 7. Prova Comportamental: Injeção de fake-exe que retorna JSON com status != SUCCESS (N5 fix validation)
    $fakeErrPs1 = Join-Path $tempDir 'fake-agy-err.ps1'
    @'
param()
if ($args -contains '--help') {
    "Usage of agy: -p Run a prompt --mode Set agent mode"
    exit 0
}
@{
    status = "ERROR"
    response = "nao deveria ser usado"
} | ConvertTo-Json -Compress
exit 0
'@ | Set-Content -LiteralPath $fakeErrPs1 -Encoding utf8

    $fakeErrCmd = Join-Path $tempDir 'fake-agy-err.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-agy-err.ps1" %*
'@ | Set-Content -LiteralPath $fakeErrCmd -Encoding ascii

    $n5ErrorCaught = $false
    try {
        $null = & $invokeScript -AntigravityExe $fakeErrCmd -Message 'Teste status ERROR' -Model 'gemini-3.6-flash-high' -Mode plan
    } catch {
        if ($_.Exception.Message -like "*status 'ERROR'*") {
            $n5ErrorCaught = $true
        }
    }
    Assert-True $n5ErrorCaught "Invoke-Antigravity.ps1 lanca excecao BLOCK com status ERROR sem engolir pelo catch"

} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Resultado do autoteste: $passed passou, $failed falhou."
if ($failed -gt 0) { exit 1 }
