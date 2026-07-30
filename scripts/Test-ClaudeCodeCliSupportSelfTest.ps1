#requires -Version 7.4
<#
.SYNOPSIS
    Self-test das funcoes de ClaudeCodeCliSupport.ps1 e da montagem de argumentos dos adapters.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ClaudeCodeCliSupport.ps1')

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

Assert-Equal 'parse versao' (ConvertFrom-ClaudeCodeVersionText '2.1.118 (Claude Code)') ([version]'2.1.118')
Assert-Equal 'parse invalido -> null' (ConvertFrom-ClaudeCodeVersionText 'sem versao') $null

$helpOk = @'
--model
--print
--output-format
--no-session-persistence
--permission-mode
--tools
'@
Assert-Equal 'help com flags exigidas' (Test-ClaudeCodeHelpSupportsContract $helpOk) $true
Assert-Equal 'help incompleto' (Test-ClaudeCodeHelpSupportsContract '--model') $false

$err = Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText 'Error: model not available'
Assert-Equal 'extrai erro simples' $err 'Error: model not available'
$trustErr = 'Claude Code refused to run because this workspace is not trusted. Mark this workspace as trusted to continue.'
Assert-Equal 'detecta workspace nao confiavel' (Test-ClaudeCodeWorkspaceNotTrusted -Text $trustErr) $true
Assert-Equal 'erro workspace not trusted vira mensagem canonica' ((Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText $trustErr) -match 'workspace-not-trusted') $true
Assert-Equal 'erro workspace preserva stderr bruto' ((Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText $trustErr) -match [regex]::Escape($trustErr)) $true
Assert-Equal 'erro workspace pede pacote de evidencia' ((Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText $trustErr) -match 'claude --version') $true
Assert-Equal 'workspace informativo nao vira erro generico' (Get-ClaudeCodeErrorMessage -StdoutText '' -StderrText 'Workspace cache atualizado.') $null
Assert-Equal 'cannot nao casa como not' (Test-ClaudeCodeWorkspaceNotTrusted -Text 'Workspace initialization cannot continue: trusted certificate missing.') $false
Assert-Equal 'texto de stdout nao classifica workspace not trusted' (Get-ClaudeCodeErrorMessage -StdoutText $trustErr -StderrText '') $null

# --- Regressao ancorada em evidencia empirica (2026-07-25, claude 2.1.215) ---------------------
# stderr REAL de execucao em workspace nao confiavel. Medido em quatro ensaios: aparece identico
# (mesmo tamanho, mesmo texto) tanto em exit 1 quanto em exit 0 com resposta valida. Portanto nao
# e evidencia de falha e nao pode disparar o detector de workspace nao confiavel.
$noiseStderr = @'
Ignoring 3 permissions.allow entries from .claude/settings.json: this workspace has not been trusted. Run Claude Code interactively here once and accept the trust dialog, or set projects["C:/tmp/probe"].hasTrustDialogAccepted: true in C:\Users\Fulano\.claude.json.
Permission allow rule (C:\Users\Fulano\.claude\settings.json): Glob(C:/Dev/**) is not matched by file permission checks - only Read(path) rules are. Use Read(C:/Dev/**) instead (Read rules cover all file-reading tools).
Permission allow rule (C:\Users\Fulano\.claude\settings.json): Write(C:/Dev/**) is not matched by file permission checks - only Edit(path) rules are. Use Edit(C:/Dev/**) instead (Edit rules cover all file-editing tools).
'@

Assert-Equal 'aviso de ambiente nao e recusa de workspace' (Test-ClaudeCodeWorkspaceNotTrusted -Text $noiseStderr) $false
Assert-Equal 'ruido de ambiente e removido por inteiro' (Remove-ClaudeCodeEnvironmentNoise -Text $noiseStderr) ''
# Ensaio R4: exit 0, resposta valida, aviso presente -> nenhum erro deve ser reportado.
Assert-Equal 'execucao bem-sucedida com aviso nao vira erro' (Get-ClaudeCodeErrorMessage -StdoutText 'OK' -StderrText $noiseStderr) $null
# Ensaio R1: exit 1 por esgotamento de turno, com o mesmo aviso em stderr.
$maxTurnsMsg = Get-ClaudeCodeErrorMessage -StdoutText 'Error: Reached max turns (1)' -StderrText $noiseStderr
Assert-Equal 'falha real vira codigo canonico max-turns-exhausted' ($maxTurnsMsg -match 'max-turns-exhausted') $true
Assert-Equal 'falha real NAO e rotulada como workspace-not-trusted' ($maxTurnsMsg -match 'workspace-not-trusted') $false
Assert-Equal 'mensagem de max turns preserva a evidencia' ($maxTurnsMsg -match [regex]::Escape('Error: Reached max turns (1)')) $true
Assert-Equal 'mensagem de max turns nao repete ruido de ambiente' ($maxTurnsMsg -match 'permissions\.allow entries') $false
Assert-Equal 'detector de max turns isolado' (Test-ClaudeCodeMaxTurnsExhausted -Text 'Error: Reached max turns (1)') $true
Assert-Equal 'detector de max turns nao casa texto qualquer' (Test-ClaudeCodeMaxTurnsExhausted -Text 'Error: model not available') $false
# A protecao contra recusa genuina continua ativa, inclusive convivendo com o ruido.
$trustPlusNoise = $noiseStderr + "`n" + $trustErr
Assert-Equal 'recusa genuina ainda detectada sob ruido' (Test-ClaudeCodeWorkspaceNotTrusted -Text $trustPlusNoise) $true
Assert-Equal 'status recusa genuina sob ruido continua unavailable' (Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr $trustPlusNoise).status 'unavailable'
Assert-Equal 'status aviso de ambiente puro nao vira unavailable' (Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr $noiseStderr).status 'sem-texto'

$s1 = Resolve-ClaudeCodeJobStatus -FinalText 'ok' -StreamError '' -Stderr 'Error: ruidoso'
Assert-Equal 'status resposta final manda' $s1.status 'completed'
$s2 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError 'stream boom' -Stderr ''
Assert-Equal 'status erro stream' $s2.status 'error'
$s3 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr 'Error: auth required'
Assert-Equal 'status erro stderr' $s3.status 'error'
$s4 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr ''
Assert-Equal 'status sem texto' $s4.status 'sem-texto'
$s5 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError '' -Stderr $trustErr
Assert-Equal 'status workspace not trusted' $s5.status 'unavailable'
Assert-Equal 'stream boom preserva o texto cru' $s2.error 'stream boom'

# --- Caminho ASSINCRONO: o erro do stream passa pelos mesmos detectores do sincrono -------------
# Medido em 2026-07-25 (claude 2.1.220): o desfecho do `--output-format stream-json` NAO vem em um
# evento `type=error`; a ultima linha e `type=result` com `subtype` e `is_error`.
$streamMaxTurns = 'subtype=error_max_turns: Error: Reached max turns (1)'
$s6 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError $streamMaxTurns -Stderr ''
Assert-Equal 'status max turns por stream continua error' $s6.status 'error'
Assert-Equal 'erro de stream de max turns vira codigo canonico' ($s6.error -match 'max-turns-exhausted') $true
$s7 = Resolve-ClaudeCodeJobStatus -FinalText '' -StreamError $trustErr -Stderr ''
Assert-Equal 'recusa de workspace por stream vira unavailable' $s7.status 'unavailable'
Assert-Equal 'recusa de workspace por stream vira codigo canonico' ($s7.error -match 'workspace-not-trusted') $true
Assert-Equal 'subtype error_max_turns isolado casa o detector' (Test-ClaudeCodeMaxTurnsExhausted -Text 'subtype=error_max_turns') $true

$evSuccess = '{"type":"result","subtype":"success","is_error":false,"result":"OK"}' | ConvertFrom-Json
Assert-Equal 'evento result de sucesso nao vira erro' (Get-ClaudeCodeStreamEventErrorText -StreamEvent $evSuccess) ''
$evAssistant = '{"type":"assistant","message":{"content":[{"text":"parcial"}]}}' | ConvertFrom-Json
Assert-Equal 'evento assistant nao vira erro' (Get-ClaudeCodeStreamEventErrorText -StreamEvent $evAssistant) ''
$evMaxTurns = '{"type":"result","subtype":"error_max_turns","is_error":true,"result":"Error: Reached max turns (1)"}' | ConvertFrom-Json
Assert-Equal 'evento result com is_error traz subtype e texto' (Get-ClaudeCodeStreamEventErrorText -StreamEvent $evMaxTurns) 'subtype=error_max_turns: Error: Reached max turns (1)'
# Evento REAL de esgotamento de turno, medido em 2026-07-25 (claude 2.1.220, `--max-turns 1`):
# nao existe campo `result` — a mensagem legivel vive em `errors[]`, com `terminal_reason` ao lado.
# Sem ler esses campos, a evidencia preservada seria apenas `subtype=error_max_turns`.
$evMaxTurnsReal = '{"is_error":true,"terminal_reason":"max_turns","subtype":"error_max_turns","errors":["Reached maximum number of turns (1)"],"type":"result"}' | ConvertFrom-Json
$realText = Get-ClaudeCodeStreamEventErrorText -StreamEvent $evMaxTurnsReal
Assert-Equal 'evento real de max turns preserva a mensagem de errors[]' ($realText -match 'Reached maximum number of turns \(1\)') $true
Assert-Equal 'evento real de max turns preserva terminal_reason' ($realText -match 'terminal_reason=max_turns') $true
Assert-Equal 'evento real de max turns ainda casa o detector' (Test-ClaudeCodeMaxTurnsExhausted -Text $realText) $true
# O texto real de errors[] NAO casa `reached max turns`; sem a alternancia, a deteccao dependeria
# so do subtype vir prefixado na evidencia montada.
Assert-Equal 'texto real de errors[] casa o detector sozinho' (Test-ClaudeCodeMaxTurnsExhausted -Text 'Reached maximum number of turns (1)') $true
# A mensagem canonica e reusada no caminho failureAfterText, onde HOUVE texto antes do corte:
# nao pode afirmar que a chamada terminou sem produzir resposta.
$maxTurnsCanonical = New-ClaudeCodeMaxTurnsExhaustedEvidenceMessage -EvidenceText 'subtype=error_max_turns'
Assert-Equal 'mensagem canonica nao afirma ausencia de resposta' ($maxTurnsCanonical -match 'antes de produzir resposta') $false
Assert-Equal 'mensagem canonica admite texto parcial' ($maxTurnsCanonical -match 'texto parcial') $true
$evTypeError = '{"type":"error","message":"boom"}' | ConvertFrom-Json
Assert-Equal 'evento type=error continua capturado' ((Get-ClaudeCodeStreamEventErrorText -StreamEvent $evTypeError) -match 'boom') $true
Assert-Equal 'evento nulo nao vira erro' (Get-ClaudeCodeStreamEventErrorText -StreamEvent $null) ''

$evDeltaA = '{"type":"content_block_delta","delta":{"type":"text_delta","text":"A"}}' | ConvertFrom-Json
$evDeltaB = '{"type":"content_block_delta","delta":{"type":"text_delta","text":"B"}}' | ConvertFrom-Json
$evResultWithText = '{"type":"result","subtype":"success","is_error":false,"result":"NAO_E_VEREDITO"}' | ConvertFrom-Json
Assert-Equal 'content_block_delta extrai texto incremental' (Get-ClaudeCodeStreamEventText -StreamEvent $evDeltaA) 'A'
Assert-Equal 'assistant content e fallback textual' (Get-ClaudeCodeStreamAcceptedTextFromEvents -StreamEvents @($evAssistant)) 'parcial'
Assert-Equal 'deltas prevalecem sobre assistant para evitar duplicacao' (Get-ClaudeCodeStreamAcceptedTextFromEvents -StreamEvents @($evAssistant, $evDeltaA, $evDeltaB)) 'AB'
Assert-Equal 'result.result nao vira texto aceito' (Get-ClaudeCodeStreamAcceptedTextFromEvents -StreamEvents @($evResultWithText)) ''

$rateLimitRejected = '{"type":"rate_limit_event","status":"rejected","rateLimitType":"weekly","reportedLimitScope":"subscription","resetsAt":1893456000}' | ConvertFrom-Json
$quotaEvidence = Get-ClaudeCodeStreamQuotaEvidence -StreamEvents @($rateLimitRejected)
Assert-Equal 'quota: rate_limit_event rejected detectado' $quotaEvidence.isQuota $true
Assert-Equal 'quota: rateLimitType preservado' $quotaEvidence.rateLimitType 'weekly'
Assert-Equal 'quota: resetsAt unix convertido para UTC' $quotaEvidence.resetsAtUtc '2030-01-01T00:00:00Z'
$result429 = '{"type":"result","is_error":true,"terminal_reason":"api_error","api_error_status":429,"result":"rate limit"}' | ConvertFrom-Json
$quota429 = Get-ClaudeCodeStreamQuotaEvidence -StreamEvents @($result429)
Assert-Equal 'quota: result api_error_status 429 detectado' $quota429.isQuota $true
Assert-Equal 'quota: api_error_status preservado' $quota429.apiErrorStatus '429'

# Falha DEPOIS de texto: `error_max_turns` PODE chegar apos alguma saida, entao descartar o erro
# mascararia resposta truncada como resposta boa. O status nao muda; a evidencia e preservada.
$s8 = Resolve-ClaudeCodeJobStatus -FinalText 'parecer truncado' -StreamError $streamMaxTurns -Stderr ''
Assert-Equal 'texto parcial com falha continua completed' $s8.status 'completed'
Assert-Equal 'texto parcial com falha nao inventa error' $s8.error $null
Assert-Equal 'falha apos texto preserva evidencia' ($s8.failureAfterText -match 'max-turns-exhausted') $true
Assert-Equal 'resposta limpa nao tem falha residual' $s1.failureAfterText $null
Assert-Equal 'falha sem texto nao vira falha apos texto' $s6.failureAfterText $null
Assert-Equal 'sem-texto tambem expoe o campo' $s4.failureAfterText $null

function New-FakeClaudeCodeExe {
    param([string]$TempRoot)

    $fakeExe = Join-Path $TempRoot 'claude.cmd'
    $argsFile = Join-Path $TempRoot 'args.txt'
    $script = @"
@echo off
if "%1"=="--version" (
  echo 2.1.118
  exit /b 0
)
if "%1"=="--help" (
  echo --model --print --output-format --no-session-persistence --permission-mode --tools
  exit /b 0
)
if "%FAKE_CLAUDE_UNTRUSTED%"=="1" (
  echo Claude Code refused to run because this workspace is not trusted. Mark this workspace as trusted to continue. 1>&2
  exit /b 1
)
echo %*>>"$argsFile"
echo OK fake claude
exit /b 0
"@
    Set-Content -LiteralPath $fakeExe -Value $script -Encoding ascii
    return [pscustomobject]@{ Exe = $fakeExe; ArgsFile = $argsFile }
}

function Read-LastFakeClaudeArgs {
    param([string]$Path)
    $lines = @(Get-Content -LiteralPath $Path -ErrorAction Stop)
    if ($lines.Count -eq 0) { return '' }
    return [string]$lines[-1]
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("claude-code-cli-support-selftest-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $fake = New-FakeClaudeCodeExe -TempRoot $tmp

    & (Join-Path $PSScriptRoot 'Invoke-ClaudeCode.ps1') 'adapter default tools' -ClaudeExe $fake.Exe -TimeoutSec 30 | Out-Null
    $invokeDefaultArgs = Read-LastFakeClaudeArgs -Path $fake.ArgsFile
    Assert-Equal 'invoke default passa --tools' ($invokeDefaultArgs -match '--tools Read,Glob,Grep') $true
    # A CLI 2.1.215 nao anuncia mais --max-turns e os adapters deixaram de tentar negocia-lo.
    Assert-Equal 'invoke nao passa --max-turns' ($invokeDefaultArgs -notmatch '--max-turns') $true

    & (Join-Path $PSScriptRoot 'Invoke-ClaudeCode.ps1') 'adapter tools vazio' -ClaudeExe $fake.Exe -Tools '' -TimeoutSec 30 | Out-Null
    $invokeEmptyArgs = Read-LastFakeClaudeArgs -Path $fake.ArgsFile
    # A CLI desabilita todas as ferramentas com --tools "". Omitir a flag faz o oposto: libera o
    # conjunto padrao completo. O valor vazio tem de chegar aspado, porque Start-Process descarta
    # string vazia do ArgumentList e --tools e variadica.
    Assert-Equal 'invoke tools vazio passa --tools ""' ($invokeEmptyArgs -match '--tools ""') $true

    # `--tools default` e o valor que a CLI documenta para liberar o conjunto padrao completo
    # (`claude --help`, 2.1.215). O adapter repassa o literal, sem tratamento especial.
    & (Join-Path $PSScriptRoot 'Invoke-ClaudeCode.ps1') 'adapter tools default' -ClaudeExe $fake.Exe -Tools 'default' -TimeoutSec 30 | Out-Null
    $invokeAllToolsArgs = Read-LastFakeClaudeArgs -Path $fake.ArgsFile
    Assert-Equal 'invoke tools default passa --tools default' ($invokeAllToolsArgs -match '--tools default') $true

    $env:FAKE_CLAUDE_UNTRUSTED = '1'
    $threwTrust = $false
    $trustMsg = ''
    try { & (Join-Path $PSScriptRoot 'Invoke-ClaudeCode.ps1') 'workspace nao confiavel' -ClaudeExe $fake.Exe -TimeoutSec 30 | Out-Null } catch { $threwTrust = $true; $trustMsg = [string]$_.Exception.Message }
    $env:FAKE_CLAUDE_UNTRUSTED = $null
    Assert-Equal 'invoke workspace not trusted bloqueia com codigo canonico' ($threwTrust -and $trustMsg -match 'workspace-not-trusted') $true

    $jobDir = Join-Path $tmp 'jobs'
    $jobJson = & (Join-Path $PSScriptRoot 'Start-ClaudeCodeJob.ps1') 'job default tools' -ClaudeExe $fake.Exe -NoWatcher -TempDir $jobDir
    $job = $jobJson | ConvertFrom-Json
    $deadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $jobDefaultArgs = Read-LastFakeClaudeArgs -Path $fake.ArgsFile
    } while ($jobDefaultArgs -notmatch 'stream-json' -and (Get-Date) -lt $deadline)
    Assert-Equal 'job default passa --tools' ($jobDefaultArgs -match '--tools Read,Glob,Grep') $true
    Assert-Equal 'job nao passa --max-turns' ($jobDefaultArgs -notmatch '--max-turns') $true
    if ($job.pid) {
        Wait-Process -Id ([int]$job.pid) -Timeout 5 -ErrorAction SilentlyContinue
    }

    # Mesmo contrato de -Tools vazio no adapter assincrono.
    $jobEmptyJson = & (Join-Path $PSScriptRoot 'Start-ClaudeCodeJob.ps1') 'job tools vazio' -ClaudeExe $fake.Exe -Tools '' -NoWatcher -TempDir $jobDir
    $jobEmpty = $jobEmptyJson | ConvertFrom-Json
    $deadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $jobEmptyArgs = Read-LastFakeClaudeArgs -Path $fake.ArgsFile
        # Esperar por `--tools` seria satisfeito de imediato pela linha do job ANTERIOR (que traz
        # `--tools Read,Glob,Grep`); a sentinela discriminante aqui e o valor vazio aspado.
    } while ($jobEmptyArgs -notmatch '--tools ""' -and (Get-Date) -lt $deadline)
    Assert-Equal 'job tools vazio passa --tools ""' ($jobEmptyArgs -match '--tools ""') $true
    if ($jobEmpty.pid) {
        Wait-Process -Id ([int]$jobEmpty.pid) -Timeout 5 -ErrorAction SilentlyContinue
    }

    # --- Watch-ClaudeCodeJob.ps1 de ponta a ponta ---------------------------------------------
    # Ate 2026-07-26 nenhum self-test executava o watcher: as funcoes da biblioteca eram cobertas
    # isoladamente, mas a LIGACAO entre elas e o <GUID>.result.json (leitura do stream, extracao
    # do evento final, gravacao de failureAfterText) nao tinha rede. Aqui o stream e sintetico e
    # o processo "dono" ja nao existe, entao o laco encerra na primeira passada.
    $watchDir = Join-Path $tmp 'watch'
    New-Item -ItemType Directory -Path $watchDir -Force | Out-Null
    $watchJobId = [guid]::NewGuid().ToString()
    $watchStream = Join-Path $watchDir "$watchJobId.stream.jsonl"
    # Evento final REAL do esgotamento de turno (claude 2.1.220): sem campo `result`, mensagem em
    # `errors[]`. Precedido de texto, que e o caso em que `failureAfterText` importa.
    $watchLines = @(
        '{"type":"assistant","message":{"content":[{"text":"parecer parcial antes do corte"}]}}'
        '{"is_error":true,"terminal_reason":"max_turns","subtype":"error_max_turns","errors":["Reached maximum number of turns (1)"],"type":"result"}'
    )
    Set-Content -LiteralPath $watchStream -Value $watchLines -Encoding utf8

    # PID garantidamente morto: sondar ate achar um identificador sem processo vivo.
    $deadPid = 999999
    while ($null -ne (Get-Process -Id $deadPid -ErrorAction SilentlyContinue)) { $deadPid-- }

    & (Join-Path $PSScriptRoot 'Watch-ClaudeCodeJob.ps1') -JobId $watchJobId -ProcessId $deadPid `
        -TempDir $watchDir -IntervalSeconds 1 6>$null | Out-Null

    $watchResultPath = Join-Path $watchDir "$watchJobId.result.json"
    Assert-Equal 'watcher grava result.json' (Test-Path -LiteralPath $watchResultPath -PathType Leaf) $true
    $watchResult = Get-Content -LiteralPath $watchResultPath -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-Equal 'watcher mantem completed com texto parcial' $watchResult.status 'completed'
    Assert-Equal 'watcher acumula o texto do stream' $watchResult.finalText 'parecer parcial antes do corte'
    Assert-Equal 'watcher nao inventa error com texto presente' $watchResult.error $null
    Assert-Equal 'watcher grava failureAfterText canonico' ($watchResult.failureAfterText -match 'max-turns-exhausted') $true
    Assert-Equal 'watcher preserva a mensagem de errors[] no result.json' ($watchResult.failureAfterText -match 'Reached maximum number of turns \(1\)') $true
} finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-ClaudeCodeCliSupportSelfTest.ps1" }
Write-Host 'OK: Test-ClaudeCodeCliSupportSelfTest.ps1' -ForegroundColor Cyan
