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

# 2b. Formas flexionadas de auth. `\bauth\b` isolado NAO casa "authentication"/"authenticating" —
# as palavras exatas das duas falhas reais medidas em 2026-08-06 no CLI irmao (Gemini). Aqui o
# custo do falso negativo e maior que no Gemini: o adapter tem fallback de texto bruto (caso 8).
$authPrompt = Get-AntigravityErrorMessage -StdoutText "Opening authentication page in your browser. Do you want to continue? [Y/n]:" -StderrText ""
Assert-True ($null -ne $authPrompt) "Reconhece prompt interativo de autenticacao no stdout"
$authErr = Get-AntigravityErrorMessage -StdoutText "" -StderrText "Error authenticating: IneligibleTierError: client no longer supported"
Assert-True ($null -ne $authErr) "Reconhece erro de autenticacao no stderr"
$semRuido = Get-AntigravityErrorMessage -StdoutText "Loaded cached credentials" -StderrText ""
Assert-True ($null -eq $semRuido) "NAO trata 'Loaded cached credentials' (linha informativa de execucao normal) como erro"

# 3. Quota failure pattern
Assert-True ("quota exceeded" -match $quotaFailurePattern) "Regex de cota reconhece 'quota exceeded'"
Assert-True ("429 Too Many Requests" -match $quotaFailurePattern) "Regex de cota reconhece 429 / Too Many Requests"
Assert-True ("resource_exhausted" -match $quotaFailurePattern) "Regex de cota reconhece resource_exhausted"
Assert-True ("credits exhausted for this billing cycle" -match $quotaFailurePattern) "Regex de cota reconhece 'credits exhausted'"

# Casos NEGATIVOS: `exhausted` solto classificava erro generico de rede/contexto como cota. Paridade
# com o mesmo defeito ja corrigido no $quotaFailurePattern do dispatcher (2026-08-06). Reportar cota
# onde nao ha manda o operador esperar reset de ciclo por falha que nao e de cota.
Assert-True (-not ("retries exhausted after 3 attempts" -match $quotaFailurePattern)) "NAO trata 'retries exhausted' (rede) como cota"
Assert-True (-not ("connection pool exhausted" -match $quotaFailurePattern)) "NAO trata 'connection pool exhausted' como cota"
Assert-True (-not ("context window exhausted" -match $quotaFailurePattern)) "NAO trata 'context window exhausted' como cota"

# 4. Resolve-AntigravityExe — sonda opcional do binario real (maquina sem agy NAO falha a suite;
#    a prova fail-closed do contrato e dos adapters esta nos casos 5-7 com fake-exe).
try {
    $exe = Resolve-AntigravityExe
    Assert-True (Test-Path -LiteralPath $exe -PathType Leaf) "Resolve executavel agy.exe no sistema ($exe)"
} catch {
    Write-Host "[SKIP] Resolve-AntigravityExe (agy nao instalado nesta maquina): $($_.Exception.Message)" -ForegroundColor Yellow
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

    # 8. Prova Comportamental: FALLBACK DE TEXTO BRUTO E FAIL-CLOSED CONTRA ERRO CONHECIDO.
    # Reproduz o estado medido em 2026-08-06 no Gemini CLI (mesma familia, sem credencial em cache):
    # prompt interativo de login no STDOUT e exit 0. Sem o guard, esse texto era devolvido como
    # PARECER do modelo e, como `responded` no dispatcher e mecanico (texto nao-vazio basta), a
    # falha de auth entrava no recibo do painel como revisor que RESPONDEU. O caso 6 acima prova
    # que o fallback legitimo (texto que nao casa erro conhecido) segue funcionando.
    $fakeAuthPs1 = Join-Path $tempDir 'fake-agy-auth.ps1'
    @'
param()
if ($args -contains '--help') {
    "Usage of agy: -p Run a prompt --mode Set agent mode"
    exit 0
}
Write-Output "Opening authentication page in your browser. Do you want to continue? [Y/n]:"
exit 0
'@ | Set-Content -LiteralPath $fakeAuthPs1 -Encoding utf8

    $fakeAuthCmd = Join-Path $tempDir 'fake-agy-auth.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-agy-auth.ps1" %*
'@ | Set-Content -LiteralPath $fakeAuthCmd -Encoding ascii

    $authBlockCaught = $false
    $authReturned = $null
    try {
        $authReturned = & $invokeScript -AntigravityExe $fakeAuthCmd -Message 'ping' -Model 'gemini-3.6-flash-high' -Mode plan
    } catch {
        if ($_.Exception.Message -like '*erro conhecido*') { $authBlockCaught = $true }
    }
    Assert-True $authBlockCaught "Stdout de auth com exit 0 deve virar BLOCK, nao parecer (fallback fail-closed)"
    Assert-True ([string]::IsNullOrEmpty([string]$authReturned)) "Stdout de auth nao pode ser devolvido como resposta do modelo"

} finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Resultado do autoteste: $passed passou, $failed falhou."
if ($failed -gt 0) { exit 1 }
Write-Host "OK: Test-AntigravityCliSupportSelfTest.ps1"
