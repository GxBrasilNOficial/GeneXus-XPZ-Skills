#requires -Version 7.4
<#
.SYNOPSIS
    Self-test das funcoes puras de GeminiCliSupport.ps1.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeminiCliSupport.ps1')

$fail = 0
function Assert-Equal {
    param([string]$Label, $Got, $Expected)
    if ([string]$Got -eq [string]$Expected) {
        Write-Host ("PASS  {0}" -f $Label) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0} -> '{1}' (esperado '{2}')" -f $Label, $Got, $Expected) -ForegroundColor Red
    }
}

Assert-Equal 'parse versao' (ConvertFrom-GeminiVersionText 'gemini 0.35.3') ([version]'0.35.3')
Assert-Equal 'parse invalido -> null' (ConvertFrom-GeminiVersionText 'sem versao') $null

$helpOk = @'
--prompt
--approval-mode
--output-format
--model
'@
Assert-Equal 'help com flags exigidas' (Test-GeminiHelpSupportsContract $helpOk) $true
Assert-Equal 'help incompleto' (Test-GeminiHelpSupportsContract '--prompt --model') $false

$err = Get-GeminiErrorMessage -StdoutText '' -StderrText 'Error: invalid model'
Assert-Equal 'extrai erro simples' $err 'Error: invalid model'
$semErr = Get-GeminiErrorMessage -StdoutText 'tudo certo' -StderrText ''
Assert-Equal 'sem erro -> null' $semErr $null

# Prova de que o extrator reconhece o prompt interativo de login. Medido em 2026-08-06: sem
# credencial em cache, o gemini escreve isto no STDOUT e sai 0.
$authTxt = Get-GeminiErrorMessage -StdoutText 'Opening authentication page in your browser. Do you want to continue? [Y/n]:' -StderrText ''
Assert-Equal 'reconhece prompt interativo de auth no stdout' ($null -ne $authTxt) $true

# ---------------------------------------------------------------------------------------------
# Provas COMPORTAMENTAIS do adapter via fake-exe: stdout nao-JSON com exit 0.
# Regressao travada: o adapter costumava estourar no ConvertFrom-Json e morrer com
# "JSON invalido: Unexpected character... O" sem nunca consultar Get-GeminiErrorMessage.
# ---------------------------------------------------------------------------------------------
$invokeScript = Join-Path $PSScriptRoot 'Invoke-Gemini.ps1'
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("gx-gemini-selftest-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
try {
    $helpBody = 'Usage: gemini --prompt --approval-mode --output-format --model'

    function New-FakeGemini {
        param([string]$Nome, [string]$CorpoStdout)
        $ps1 = Join-Path $tempDir "$Nome.ps1"
        @"
param()
if (`$args -contains '--version') { '0.54.0'; exit 0 }
if (`$args -contains '--help') { '$helpBody'; exit 0 }
Write-Output @'
$CorpoStdout
'@
exit 0
"@ | Set-Content -LiteralPath $ps1 -Encoding utf8
        $cmd = Join-Path $tempDir "$Nome.cmd"
        @"
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0$Nome.ps1" %*
"@ | Set-Content -LiteralPath $cmd -Encoding ascii
        return $cmd
    }

    # (a) stdout com o prompt de login -> mensagem acionavel, NAO "JSON invalido"
    $fakeAuth = New-FakeGemini -Nome 'fake-gemini-auth' -CorpoStdout 'Opening authentication page in your browser. Do you want to continue? [Y/n]:'
    $msgAuth = ''
    try { $null = & $invokeScript -GeminiExe $fakeAuth -Message 'ping' -Model 'gemini-3-flash-preview' }
    catch { $msgAuth = [string]$_.Exception.Message }
    Assert-Equal 'stdout de auth: reporta o motivo real' ($msgAuth -match 'authentication') $true
    Assert-Equal 'stdout de auth: NAO reporta JSON invalido' ($msgAuth -notmatch 'JSON invalido') $true

    # (b) stdout ilegivel que o extrator NAO reconhece -> segue "JSON invalido", agora com amostra
    $fakeJunk = New-FakeGemini -Nome 'fake-gemini-junk' -CorpoStdout 'zzz nao json nem erro conhecido zzz'
    $msgJunk = ''
    try { $null = & $invokeScript -GeminiExe $fakeJunk -Message 'ping' -Model 'gemini-3-flash-preview' }
    catch { $msgJunk = [string]$_.Exception.Message }
    Assert-Equal 'stdout ilegivel: mantem diagnostico de contrato JSON' ($msgJunk -match 'JSON invalido') $true
    Assert-Equal 'stdout ilegivel: inclui amostra do stdout' ($msgJunk -match 'zzz nao json') $true
}
finally {
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-GeminiCliSupportSelfTest.ps1" }
Write-Host 'OK: Test-GeminiCliSupportSelfTest.ps1' -ForegroundColor Cyan
