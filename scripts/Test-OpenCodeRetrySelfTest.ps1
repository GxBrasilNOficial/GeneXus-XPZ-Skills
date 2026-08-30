#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test do retry-once de Invoke-OpenCode.ps1 (-MaxAttempts).
#
# Mecanismo: um fake-exe REAL (.cmd -> leitor pwsh) injetado via -OpenCodeExe. Como cada tentativa
# do laco e um PROCESSO NOVO, o numero da tentativa vem de um CONTADOR EM ARQUIVO ($env:FAKE_COUNTER);
# o stream que cada tentativa emite e decidido por $env:FAKE_PLAN (lista de status por virgula).
#
# Casos cobertos:
#  (i)   'truncated,ok' com -MaxAttempts 2 -> converte truncado para texto final (contador == 2)
#  (ii)  'truncated' com -MaxAttempts 1 -> mantem o throw, SEM anotacao "(apos N tentativas)" (contador == 1)
#  (iii) exit!=0 e erro-explicito-de-stream sao TERMINAIS (nao re-tentam; contador == 1)
#  (iv)  'truncated,truncated' -MaxAttempts 2 -> throw com "(apos 2 tentativas; ultimo status=truncated...)"
#  (v)   guarda anti-429 POR TENTATIVA: com um 429 na janela (seam XDG_DATA_HOME), o retry e bloqueado
#        (terminal) e NAO ha 2a tentativa (contador == 1).
#
# A deteccao de 429 (Get-OpenCodeUsageLimitError) le o log do opencode sob XDG_DATA_HOME; o teste
# usa um XDG_DATA_HOME temporario LIMPO em todos os casos (isolando do log real da maquina) e, no
# caso (v), aponta para um dir com um log 429 fabricado dentro da janela.

$scriptsDir = $PSScriptRoot
$invoke = Join-Path $scriptsDir 'Invoke-OpenCode.ps1'
. (Join-Path $scriptsDir 'OpenCodeStreamSupport.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Reset-Counter { param([string]$Path) Set-Content -LiteralPath $Path -Value '0' -Encoding ascii -NoNewline }
function Get-Counter  { param([string]$Path) [int](Get-Content -LiteralPath $Path -Raw) }

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-oc-retry-selftest-' + [System.Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

$origXdg = $env:XDG_DATA_HOME

try {
    # leitor: incrementa o contador, consome o stdin (EOF), emite o stream do status da tentativa.
    $fakeReader = Join-Path $tempRoot 'fake-reader.ps1'
    @'
$a = @($args)
# Guard D1/D2: o adapter chama `agent list` (opt-out -Agent reviewer-fake -> so confirma que
# resolve). Responder ANTES da logica de contador (nao consome tentativa) e sem ler stdin.
if ($a.Count -ge 1 -and $a[0] -eq '--version') {
    '1.0.0-fake'
    exit 0
}
if ($a.Count -ge 2 -and $a[0] -eq 'agent' -and $a[1] -eq 'list') {
    'reviewer-fake (all)'
    '['
    '{"permission":"*","action":"deny","pattern":"*"},'
    '{"permission":"read","action":"allow","pattern":"*"},'
    '{"permission":"grep","action":"allow","pattern":"*"},'
    '{"permission":"glob","action":"allow","pattern":"*"},'
    '{"permission":"list","action":"allow","pattern":"*"},'
    '{"permission":"external_directory","action":"deny","pattern":"*"}'
    ']'
    exit 0
}
$counterFile = $env:FAKE_COUNTER
$n = 0
if ($counterFile -and (Test-Path -LiteralPath $counterFile)) { $n = [int](Get-Content -LiteralPath $counterFile -Raw) }
$n++
Set-Content -LiteralPath $counterFile -Value $n -Encoding ascii -NoNewline
[void][Console]::In.ReadToEnd()
$plan = @(($env:FAKE_PLAN -split ','))
$idx = [Math]::Min($n - 1, $plan.Count - 1)
$status = $plan[$idx]
switch ($status) {
    'ok'          { '{"type":"text","part":{"messageID":"m1","text":"OK-RETRY"}}'; '{"type":"step_finish","part":{"reason":"stop"}}'; exit 0 }
    'truncated'   { '{"type":"text","part":{"messageID":"m1","text":"preambulo"}}'; '{"type":"step_finish","part":{"reason":"tool-calls"}}'; exit 0 }
    'streamerror' { '{"type":"error","error":{"data":{"message":"fake stream error"}}}'; exit 0 }
    'exit'        { exit 3 }
    default       { throw "FAKE_PLAN status desconhecido: $status" }
}
'@ | Set-Content -LiteralPath $fakeReader -Encoding utf8

    $fakeCmd = Join-Path $tempRoot 'fake-opencode.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-reader.ps1" %*
exit /b %errorlevel%
'@ | Set-Content -LiteralPath $fakeCmd -Encoding ascii

    $promptFile = Join-Path $tempRoot 'prompt.txt'
    Set-Content -LiteralPath $promptFile -Value 'oi' -Encoding utf8 -NoNewline

    # XDG_DATA_HOME limpo (sem opencode/log) -> Get-OpenCodeUsageLimitError devolve $null por padrao.
    $cleanXdg = Join-Path $tempRoot 'xdg-clean'
    [System.IO.Directory]::CreateDirectory($cleanXdg) | Out-Null
    $env:XDG_DATA_HOME = $cleanXdg

    # ---- (i) 'truncated,ok' com -MaxAttempts 2 ----
    $c = Join-Path $tempRoot 'c1.txt'; Reset-Counter $c
    $env:FAKE_COUNTER = $c; $env:FAKE_PLAN = 'truncated,ok'
    $ans = & $invoke -OpenCodeExe $fakeCmd -Agent 'reviewer-fake' -MessagePath $promptFile -Model 'fake/model' -TimeoutSec 60 -MaxAttempts 2
    Assert-True (([string]$ans) -match 'OK-RETRY') "(i) -MaxAttempts 2 deveria converter truncado->ok; veio: '$ans'."
    Assert-True ((Get-Counter $c) -eq 2) "(i) deveria ter 2 tentativas; contador=$(Get-Counter $c)."

    # ---- (ii) 'truncated' com -MaxAttempts 1 ----
    $c = Join-Path $tempRoot 'c2.txt'; Reset-Counter $c
    $env:FAKE_COUNTER = $c; $env:FAKE_PLAN = 'truncated'
    $threw = $false; $msg = ''
    try { & $invoke -OpenCodeExe $fakeCmd -Agent 'reviewer-fake' -MessagePath $promptFile -Model 'fake/model' -TimeoutSec 60 -MaxAttempts 1 } catch { $threw = $true; $msg = $_.Exception.Message }
    Assert-True $threw "(ii) -MaxAttempts 1 com truncado deveria lancar."
    Assert-True ($msg -match 'truncad') "(ii) a mensagem deveria indicar truncado; veio: '$msg'."
    Assert-True (-not ($msg -match 'apos .* tentativas')) "(ii) -MaxAttempts 1 nao deve anotar '(apos N tentativas)'; veio: '$msg'."
    Assert-True ((Get-Counter $c) -eq 1) "(ii) deveria ter 1 tentativa; contador=$(Get-Counter $c)."

    # ---- (iii-a) exit!=0 NAO re-tenta ----
    $c = Join-Path $tempRoot 'c3a.txt'; Reset-Counter $c
    $env:FAKE_COUNTER = $c; $env:FAKE_PLAN = 'exit,ok'
    $threw = $false; $msg = ''
    try { & $invoke -OpenCodeExe $fakeCmd -Agent 'reviewer-fake' -MessagePath $promptFile -Model 'fake/model' -TimeoutSec 60 -MaxAttempts 2 } catch { $threw = $true; $msg = $_.Exception.Message }
    Assert-True $threw "(iii-a) exit!=0 deveria lancar."
    Assert-True ($msg -match 'codigo 3') "(iii-a) mensagem deveria citar o exit code; veio: '$msg'."
    Assert-True ((Get-Counter $c) -eq 1) "(iii-a) exit!=0 NAO deve re-tentar; contador=$(Get-Counter $c)."

    # ---- (iii-b) erro de stream NAO re-tenta ----
    $c = Join-Path $tempRoot 'c3b.txt'; Reset-Counter $c
    $env:FAKE_COUNTER = $c; $env:FAKE_PLAN = 'streamerror,ok'
    $threw = $false; $msg = ''
    try { & $invoke -OpenCodeExe $fakeCmd -Agent 'reviewer-fake' -MessagePath $promptFile -Model 'fake/model' -TimeoutSec 60 -MaxAttempts 2 } catch { $threw = $true; $msg = $_.Exception.Message }
    Assert-True $threw "(iii-b) erro de stream deveria lancar."
    Assert-True ($msg -match 'erro no stream') "(iii-b) mensagem deveria citar erro no stream; veio: '$msg'."
    Assert-True ((Get-Counter $c) -eq 1) "(iii-b) erro de stream NAO deve re-tentar; contador=$(Get-Counter $c)."

    # ---- (iv) todas truncam -> throw com status final ----
    $c = Join-Path $tempRoot 'c4.txt'; Reset-Counter $c
    $env:FAKE_COUNTER = $c; $env:FAKE_PLAN = 'truncated,truncated'
    $threw = $false; $msg = ''
    try { & $invoke -OpenCodeExe $fakeCmd -Agent 'reviewer-fake' -MessagePath $promptFile -Model 'fake/model' -TimeoutSec 60 -MaxAttempts 2 } catch { $threw = $true; $msg = $_.Exception.Message }
    Assert-True $threw "(iv) todas truncam deveria lancar."
    Assert-True ($msg -match 'apos 2 tentativas') "(iv) deveria anotar '(apos 2 tentativas...)'; veio: '$msg'."
    Assert-True ($msg -match 'ultimo status=truncated') "(iv) deveria citar 'ultimo status=truncated'; veio: '$msg'."
    Assert-True ((Get-Counter $c) -eq 2) "(iv) deveria ter 2 tentativas; contador=$(Get-Counter $c)."

    # ---- (v) guarda anti-429 por-tentativa (seam XDG_DATA_HOME) ----
    $c = Join-Path $tempRoot 'c5.txt'; Reset-Counter $c
    $xdg429 = Join-Path $tempRoot 'xdg-429'
    $logDir = Join-Path $xdg429 'opencode/log'
    [System.IO.Directory]::CreateDirectory($logDir) | Out-Null
    Set-Content -LiteralPath (Join-Path $logDir 'fake.log') -Value '{"statusCode": 429, "msg": "You have reached your weekly usage limit"}' -Encoding utf8
    $env:FAKE_COUNTER = $c; $env:FAKE_PLAN = 'truncated,ok'
    $env:XDG_DATA_HOME = $xdg429
    $threw = $false; $msg = ''
    try { & $invoke -OpenCodeExe $fakeCmd -Agent 'reviewer-fake' -MessagePath $promptFile -Model 'fake/model' -TimeoutSec 60 -MaxAttempts 2 } catch { $threw = $true; $msg = $_.Exception.Message }
    $env:XDG_DATA_HOME = $cleanXdg
    Assert-True $threw "(v) 429 na janela deveria bloquear o retry (lancar)."
    Assert-True ($msg -match 'limite de uso') "(v) mensagem deveria ser Format usage; veio: '$msg'."
    Assert-True ($msg -notmatch 'System\.Collections|@{kind') "(v) throw nao deve interpolar hashtable; veio: '$msg'."
    $fixedRate = Format-OpenCodeLimitBlock -Kind 'rate-limit' -Message ''
    Assert-True ($fixedRate -notmatch '429') "(v) parte fixa de rate nao deve conter 429: $fixedRate"
    Assert-True ((Get-Counter $c) -eq 1) "(v) 429 NAO deve re-tentar; contador=$(Get-Counter $c)."

    Write-Output 'OK: Test-OpenCodeRetrySelfTest.ps1'
}
finally {
    Remove-Item Env:FAKE_COUNTER -ErrorAction SilentlyContinue
    Remove-Item Env:FAKE_PLAN -ErrorAction SilentlyContinue
    if ($null -eq $origXdg) { Remove-Item Env:XDG_DATA_HOME -ErrorAction SilentlyContinue }
    else { $env:XDG_DATA_HOME = $origXdg }
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
