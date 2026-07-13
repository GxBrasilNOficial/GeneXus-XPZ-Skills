#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de OpenCodeStreamSupport.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Exercita as funções de parsing do stream do opencode com fixtures JSONL sinteticas
    (sem opencode nem rede). Cobre: mensagem única, multi-mensagem (preambulos + final),
    mensagem final fragmentada em varias partes, evento de erro, ausencia de texto e
    linhas invalidas. Determinístico.
    Sentinela de sucesso: OK: Test-OpenCodeStreamSupportSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'OpenCodeStreamSupport.ps1')

$fail = 0
function Assert-Eq {
    param([string]$Name, $Got, $Expected)
    if ([string]$Got -eq [string]$Expected) {
        Write-Host ("PASS  {0}" -f $Name) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("FAIL  {0}: got=[{1}] esperado=[{2}]" -f $Name, $Got, $Expected) -ForegroundColor Red
    }
}

function New-WatchResultFromLines {
    param(
        [string[]]$Lines,
        [bool]$FallbackToBuild = $false,
        [AllowNull()] [Nullable[int]]$OpencodeExitCode = 0,
        [bool]$OpencodeExitObserved = $true,
        [string]$RequestedAgent = 'reviewer-ro'
    )
    $events = ConvertFrom-OpenCodeStreamLines -Lines $Lines
    $signal = Get-OpenCodeCompletionSignal -Events $events
    return Get-OpenCodeWatchResult -JobId 'job-test' -CompletionSignal $signal -StderrText '' `
        -FallbackToBuild:$FallbackToBuild -FallbackStderrPattern 'pattern-from-guard' `
        -RequestedAgent $RequestedAgent -OpencodeExitCode $OpencodeExitCode `
        -OpencodeExitObserved:$OpencodeExitObserved -FinishedAt ([datetime]'2026-01-01T00:00:00Z')
}

# 1) Mensagem única
$linesSingle = @(
    '{"type":"step_start","part":{}}',
    '{"type":"text","part":{"messageID":"m1","text":"Resposta unica."}}',
    '{"type":"step_finish","part":{}}'
)
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesSingle
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'single: count partes'  (@($parts).Count) 1
Assert-Eq 'single: finalText'     (Get-OpenCodeFinalText -TextParts $parts) 'Resposta unica.'
Assert-Eq 'single: erro nulo'     ($null -eq (Get-OpenCodeStreamErrorMessage -Events $ev)) $true

# 2) Multi-mensagem: preambulos + resposta final na última mensagem
$linesMulti = @(
    '{"type":"text","part":{"messageID":"m1","text":"preambulo 1"}}',
    '{"type":"tool_use","part":{"tool":"bash"}}',
    '{"type":"text","part":{"messageID":"m2","text":"preambulo 2"}}',
    '{"type":"text","part":{"messageID":"m3","text":"RESPOSTA FINAL"}}'
)
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesMulti
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'multi: count partes'   (@($parts).Count) 3
Assert-Eq 'multi: finalText (so ultima msg)' (Get-OpenCodeFinalText -TextParts $parts) 'RESPOSTA FINAL'
Assert-Eq 'multi: allText junta tudo' (Get-OpenCodeAllText -TextParts $parts) "preambulo 1`n`npreambulo 2`n`nRESPOSTA FINAL"

# 3) Mensagem final fragmentada em duas partes (mesmo messageID)
$linesFrag = @(
    '{"type":"text","part":{"messageID":"m1","text":"pre"}}',
    '{"type":"text","part":{"messageID":"m2","text":"parte A "}}',
    '{"type":"text","part":{"messageID":"m2","text":"parte B"}}'
)
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesFrag
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'frag: finalText concatena ultima msg' (Get-OpenCodeFinalText -TextParts $parts) 'parte A parte B'

# 4) Evento de erro
$linesErr = @(
    '{"type":"text","part":{"messageID":"m1","text":"oi"}}',
    '{"type":"error","error":{"data":{"message":"model does not support tools"}}}'
)
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesErr
Assert-Eq 'erro: mensagem extraida' (Get-OpenCodeStreamErrorMessage -Events $ev) 'model does not support tools'

# 5) Sem evento de texto
$linesNoText = @('{"type":"step_start","part":{}}', '{"type":"step_finish","part":{}}')
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesNoText
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'sem-texto: count 0'    (@($parts).Count) 0
Assert-Eq 'sem-texto: finalText vazio' (Get-OpenCodeFinalText -TextParts $parts) ''

# 6) Linhas vazias/invalidas são ignoradas
$linesJunk = @('', '   ', 'isto nao e json', '{"type":"text","part":{"messageID":"m1","text":"ok"}}')
$ev = ConvertFrom-OpenCodeStreamLines -Lines $linesJunk
$parts = @(Get-OpenCodeTextParts -Events $ev)
Assert-Eq 'junk: ignora invalidas, 1 parte' (@($parts).Count) 1
Assert-Eq 'junk: finalText'       (Get-OpenCodeFinalText -TextParts $parts) 'ok'

# ── Achado D: sinal de conclusao (step_finish/reason) + veredito de precedencia ────────────

function Get-Verdict {
    # Helper: deriva signal das fixtures e aplica o veredito sobre o finalText real.
    param([string[]]$Lines)
    $ev = ConvertFrom-OpenCodeStreamLines -Lines $Lines
    $sig = Get-OpenCodeCompletionSignal -Events $ev
    $final = Get-OpenCodeFinalText -TextParts (Get-OpenCodeTextParts -Events $ev)
    return (Get-OpenCodeCompletionVerdict -HasStepFinish $sig.hasStepFinish -Reason $sig.reason -FinalText $final)
}

# 7) reason=stop + texto -> ok
$linesStop = @(
    '{"type":"text","part":{"messageID":"m1","text":"resposta final"}}',
    '{"type":"step_finish","part":{"reason":"stop"}}'
)
$sig = Get-OpenCodeCompletionSignal -Events (ConvertFrom-OpenCodeStreamLines -Lines $linesStop)
Assert-Eq 'stop: hasStepFinish' $sig.hasStepFinish $true
Assert-Eq 'stop: reason'        $sig.reason 'stop'
Assert-Eq 'stop: verdict ok'    (Get-Verdict $linesStop).status 'ok'

# 8) reason=length -> truncated (caso classico de truncamento)
$linesLen = @(
    '{"type":"text","part":{"messageID":"m1","text":"preambulo truncado"}}',
    '{"type":"step_finish","part":{"reason":"length"}}'
)
$vLen = Get-Verdict $linesLen
Assert-Eq 'length: verdict truncated' $vLen.status 'truncated'
Assert-Eq 'length: mensagem cita reason' ($vLen.message -match 'reason=length') $true

# 9) sem step_finish algum -> no-completion (sinal ausente)
$linesNoFin = @('{"type":"text","part":{"messageID":"m1","text":"so preambulo, stream cortou"}}')
$sig = Get-OpenCodeCompletionSignal -Events (ConvertFrom-OpenCodeStreamLines -Lines $linesNoFin)
Assert-Eq 'noFin: hasStepFinish'  $sig.hasStepFinish $false
Assert-Eq 'noFin: verdict no-completion' (Get-Verdict $linesNoFin).status 'no-completion'

# 10) step_finish presente mas SEM campo reason -> no-completion (reason nulo = ausente, sem excecao)
$linesNoReason = @(
    '{"type":"text","part":{"messageID":"m1","text":"texto"}}',
    '{"type":"step_finish","part":{}}'
)
$sig = Get-OpenCodeCompletionSignal -Events (ConvertFrom-OpenCodeStreamLines -Lines $linesNoReason)
Assert-Eq 'noReason: hasStepFinish' $sig.hasStepFinish $true
Assert-Eq 'noReason: reason vazio'  $sig.reason ''
Assert-Eq 'noReason: verdict no-completion' (Get-Verdict $linesNoReason).status 'no-completion'

# 11) reason=stop mas texto final vazio -> empty
$linesEmpty = @('{"type":"step_finish","part":{"reason":"stop"}}')
Assert-Eq 'empty: verdict empty' (Get-Verdict $linesEmpty).status 'empty'

# 12) Regressao do Achado D: preambulo presente (finalText NAO vazio) + reason=tool-calls
#     -> truncated; o adapter NAO deve devolver o preambulo como resposta.
$linesPreamble = @(
    '{"type":"text","part":{"messageID":"m1","text":"deixa eu ler os arquivos primeiro..."}}',
    '{"type":"step_finish","part":{"reason":"tool-calls"}}'
)
$evPre = ConvertFrom-OpenCodeStreamLines -Lines $linesPreamble
$finalPre = Get-OpenCodeFinalText -TextParts (Get-OpenCodeTextParts -Events $evPre)
Assert-Eq 'preamble: finalText nao-vazio' ([string]::IsNullOrWhiteSpace($finalPre)) $false
Assert-Eq 'preamble: verdict truncated (nao devolve preambulo)' (Get-Verdict $linesPreamble).status 'truncated'

# 13) "Ultimo step_finish governa": multiplos step_finish, o ULTIMO sem reason -> no-completion.
#     Contrato que o Watch-OpenCodeJob deve espelhar (sempre sobrescrever lastFinishReason,
#     nunca herdar o reason de um step_finish anterior). Achado da revisao do diff (Codex).
$linesMultiFin = @(
    '{"type":"text","part":{"messageID":"m1","text":"parcial"}}',
    '{"type":"step_finish","part":{"reason":"stop"}}',
    '{"type":"text","part":{"messageID":"m2","text":"mais texto"}}',
    '{"type":"step_finish","part":{}}'
)
$sig = Get-OpenCodeCompletionSignal -Events (ConvertFrom-OpenCodeStreamLines -Lines $linesMultiFin)
Assert-Eq 'multiFin: ultimo step_finish governa (reason vazio)' $sig.reason ''
Assert-Eq 'multiFin: verdict no-completion (nao herda stop anterior)' (Get-Verdict $linesMultiFin).status 'no-completion'

# 14) Parametrico: qualquer reason != stop -> truncated (vocabulario aberto do opencode).
foreach ($r in @('length', 'tool-calls', 'content_filter', 'unknown', 'max_tokens')) {
    $linesR = @(
        '{"type":"text","part":{"messageID":"m1","text":"preambulo"}}',
        ('{"type":"step_finish","part":{"reason":"' + $r + '"}}')
    )
    Assert-Eq ("param: reason=$r -> truncated") (Get-Verdict $linesR).status 'truncated'
}

# 15) Prioridade do erro explicito (G1, claude-opus): mesmo com reason=stop + texto (verdict ok),
#     Get-OpenCodeStreamErrorMessage detecta o erro -> os chamadores (Invoke-OpenCode/Watch) o
#     lancam ANTES de consultar o veredito. O teste fixa a deteccao e a nao-interferencia.
$linesErrFirst = @(
    '{"type":"text","part":{"messageID":"m1","text":"ok"}}',
    '{"type":"step_finish","part":{"reason":"stop"}}',
    '{"type":"error","error":{"data":{"message":"boom no agente"}}}'
)
$evErrFirst = ConvertFrom-OpenCodeStreamLines -Lines $linesErrFirst
Assert-Eq 'errFirst: erro detectado' (Get-OpenCodeStreamErrorMessage -Events $evErrFirst) 'boom no agente'
Assert-Eq 'errFirst: verdict isolado seria ok (erro tratado a parte no chamador)' (Get-Verdict $linesErrFirst).status 'ok'

# 16) Contrato v2 aceito: shape completo, step_finish real e exits zero.
$wrOk = New-WatchResultFromLines -Lines $linesStop
$acceptedOk = Get-OpenCodeAcceptedResult -Result $wrOk
Assert-Eq 'watch-v2 ok: schemaVersion' $wrOk.schemaVersion 2
Assert-Eq 'watch-v2 ok: accepted' $acceptedOk.accepted $true
Assert-Eq 'watch-v2 ok: acceptedFinalText' $acceptedOk.acceptedFinalText 'resposta final'
Assert-Eq 'watch-v2 ok: watcherExitCode' $wrOk.watcherExitCode 0
Assert-Eq 'watch-v2 ok: opencodeExitCode' $wrOk.opencodeExitCode 0

# 17) Fallback sempre rejeita e domina a disposicao/reason, preservando texto bruto em finalText.
$wrFallback = New-WatchResultFromLines -Lines $linesStop -FallbackToBuild $true -RequestedAgent 'reviewer-fake'
$acceptedFallback = Get-OpenCodeAcceptedResult -Result $wrFallback
Assert-Eq 'fallback: accepted false' $acceptedFallback.accepted $false
Assert-Eq 'fallback: helper reason preservado' $acceptedFallback.reason 'opencode-agent-fallback-to-build'
Assert-Eq 'fallback: watcherExitCode 20' $wrFallback.watcherExitCode 20
Assert-Eq 'fallback: disposition' $wrFallback.finalTextDisposition 'rejected-fallback'
Assert-Eq 'fallback: reason' $wrFallback.rejectionReason 'opencode-agent-fallback-to-build'
Assert-Eq 'fallback: acceptedFinalText vazio' $wrFallback.acceptedFinalText ''
Assert-Eq 'fallback: detail reason' $wrFallback.fallbackDetail.reason 'opencode-agent-fallback-to-build'
Assert-Eq 'fallback: requestedAgent preservado' $wrFallback.fallbackDetail.requestedAgent 'reviewer-fake'
Assert-Eq 'fallback: stderrPattern vem de input' $wrFallback.fallbackDetail.stderrPattern 'pattern-from-guard'

# 18) Exit opencode nao zero rejeita sem colapsar o status diagnostico completed.
$wrExit = New-WatchResultFromLines -Lines $linesStop -OpencodeExitCode 7
Assert-Eq 'exit-nonzero: status completed' $wrExit.status 'completed'
Assert-Eq 'exit-nonzero: disposition' $wrExit.finalTextDisposition 'rejected-error'
Assert-Eq 'exit-nonzero: reason' $wrExit.rejectionReason 'opencode-exit-nonzero'
Assert-Eq 'exit-nonzero: acceptedFinalText vazio' $wrExit.acceptedFinalText ''
Assert-Eq 'exit-nonzero: helper rejected' (Get-OpenCodeAcceptedResult -Result $wrExit).accepted $false

# 19) Exit desconhecido rejeita conservadoramente.
$wrUnknownExit = New-WatchResultFromLines -Lines $linesStop -OpencodeExitCode $null -OpencodeExitObserved $false
Assert-Eq 'exit-unknown: status completed' $wrUnknownExit.status 'completed'
Assert-Eq 'exit-unknown: reason' $wrUnknownExit.rejectionReason 'opencode-exit-unknown'
Assert-Eq 'exit-unknown: helper rejected' (Get-OpenCodeAcceptedResult -Result $wrUnknownExit).accepted $false

# 20) Rejeicoes de conclusao usam status publico PT-BR e helper nao aceita texto bruto.
$wrTrunc = New-WatchResultFromLines -Lines $linesLen
Assert-Eq 'truncated: status publico' $wrTrunc.status 'truncado'
Assert-Eq 'truncated: disposition' $wrTrunc.finalTextDisposition 'rejected-truncated'
Assert-Eq 'truncated: acceptedFinalText vazio' $wrTrunc.acceptedFinalText ''
Assert-Eq 'truncated: helper rejected' (Get-OpenCodeAcceptedResult -Result $wrTrunc).accepted $false
$wrNoFin = New-WatchResultFromLines -Lines $linesNoFin
Assert-Eq 'no-completion: status publico' $wrNoFin.status 'sem-conclusao'
Assert-Eq 'no-completion: reason' $wrNoFin.rejectionReason 'no-completion'
$wrEmpty = New-WatchResultFromLines -Lines $linesEmpty
Assert-Eq 'empty: status publico' $wrEmpty.status 'sem-texto'
Assert-Eq 'empty: reason' $wrEmpty.rejectionReason 'empty'

# 21) Helper rejeita contratos fabricados/corrompidos.
$fabricated = [pscustomobject]@{
    schemaVersion = 2; resultAccepted = $true; status = 'completed'; hasStepFinish = $false
    completionVerdict = 'ok'; finishReason = 'stop'; acceptedFinalText = 'texto'; finalText = 'texto'
    watcherExitCode = 0; opencodeExitCode = 0; fallbackToBuild = $false; fallbackDetail = $null
    finalTextDisposition = 'accepted'; rejectionReason = ''; error = $null
}
Assert-Eq 'fabricado: ok sem step_finish rejeitado' (Get-OpenCodeAcceptedResult -Result $fabricated).accepted $false
$fabricatedTextMismatch = $wrOk.PSObject.Copy()
$fabricatedTextMismatch.acceptedFinalText = 'texto divergente'
Assert-Eq 'fabricado: acceptedFinalText diverge de finalText rejeitado' (Get-OpenCodeAcceptedResult -Result $fabricatedTextMismatch).accepted $false
$corruptNumeric = $wrOk.PSObject.Copy()
$corruptNumeric.watcherExitCode = 'zero'
$corruptResult = Get-OpenCodeAcceptedResult -Result $corruptNumeric
Assert-Eq 'corrompido: watcherExitCode nao numerico rejeitado sem excecao' $corruptResult.accepted $false
Assert-Eq 'corrompido: reason numerico' $corruptResult.reason 'invalid-watcherExitCode'
$v1 = [pscustomobject]@{ status = 'completed'; finalText = 'texto' }
Assert-Eq 'v1 implicito: rejeitado' (Get-OpenCodeAcceptedResult -Result $v1).accepted $false
$v3 = $wrOk.PSObject.Copy()
$v3.schemaVersion = 3
Assert-Eq 'schemaVersion >2: rejeitado' (Get-OpenCodeAcceptedResult -Result $v3).accepted $false

$badExitNonzero = $wrExit.PSObject.Copy()
$badExitNonzero.opencodeExitCode = 0
$badExitNonzeroResult = Get-OpenCodeAcceptedResult -Result $badExitNonzero
Assert-Eq 'corrompido: exit-nonzero com opencodeExitCode zero rejeitado' $badExitNonzeroResult.accepted $false
Assert-Eq 'corrompido: exit-nonzero reason incoerente' $badExitNonzeroResult.reason 'rejected-exit-code-incoherent'
$badExitUnknown = $wrUnknownExit.PSObject.Copy()
$badExitUnknown.opencodeExitCode = 1
$badExitUnknownResult = Get-OpenCodeAcceptedResult -Result $badExitUnknown
Assert-Eq 'corrompido: exit-unknown com opencodeExitCode presente rejeitado' $badExitUnknownResult.accepted $false
Assert-Eq 'corrompido: exit-unknown reason incoerente' $badExitUnknownResult.reason 'rejected-exit-code-incoherent'
$badTruncatedVerdict = $wrTrunc.PSObject.Copy()
$badTruncatedVerdict.completionVerdict = 'ok'
$badTruncatedVerdictResult = Get-OpenCodeAcceptedResult -Result $badTruncatedVerdict
Assert-Eq 'corrompido: truncated com verdict ok rejeitado' $badTruncatedVerdictResult.accepted $false
Assert-Eq 'corrompido: truncated verdict reason incoerente' $badTruncatedVerdictResult.reason 'contradictory-completionVerdict'
$badTruncatedDisposition = $wrTrunc.PSObject.Copy()
$badTruncatedDisposition.finalTextDisposition = 'rejected-error'
$badTruncatedDispositionResult = Get-OpenCodeAcceptedResult -Result $badTruncatedDisposition
Assert-Eq 'corrompido: truncated com disposition errada rejeitado' $badTruncatedDispositionResult.accepted $false
Assert-Eq 'corrompido: truncated disposition reason incoerente' $badTruncatedDispositionResult.reason 'rejected-disposition-incoherent'
$badNoCompletionDisposition = $wrNoFin.PSObject.Copy()
$badNoCompletionDisposition.finalTextDisposition = 'rejected-error'
$badNoCompletionDispositionResult = Get-OpenCodeAcceptedResult -Result $badNoCompletionDisposition
Assert-Eq 'corrompido: no-completion com disposition errada rejeitado' $badNoCompletionDispositionResult.accepted $false
Assert-Eq 'corrompido: no-completion disposition reason incoerente' $badNoCompletionDispositionResult.reason 'rejected-disposition-incoherent'
$badEmptyDisposition = $wrEmpty.PSObject.Copy()
$badEmptyDisposition.finalTextDisposition = 'rejected-error'
$badEmptyDispositionResult = Get-OpenCodeAcceptedResult -Result $badEmptyDisposition
Assert-Eq 'corrompido: empty com disposition errada rejeitado' $badEmptyDispositionResult.accepted $false
Assert-Eq 'corrompido: empty disposition reason incoerente' $badEmptyDispositionResult.reason 'rejected-disposition-incoherent'
$badFallbackDisposition = $wrFallback.PSObject.Copy()
$badFallbackDisposition.finalTextDisposition = 'rejected-error'
$badFallbackDispositionResult = Get-OpenCodeAcceptedResult -Result $badFallbackDisposition
Assert-Eq 'corrompido: fallback com disposition errada rejeitado' $badFallbackDispositionResult.accepted $false
Assert-Eq 'corrompido: fallback shape invalido' $badFallbackDispositionResult.reason 'fallback-shape-invalid'
$badFallbackFlag = $wrFallback.PSObject.Copy()
$badFallbackFlag.fallbackToBuild = $false
$badFallbackFlagResult = Get-OpenCodeAcceptedResult -Result $badFallbackFlag
Assert-Eq 'corrompido: fallbackDetail sem fallbackToBuild rejeitado' $badFallbackFlagResult.accepted $false
Assert-Eq 'corrompido: fallback flag reason incoerente' $badFallbackFlagResult.reason 'rejected-shape-incoherent'

# 22) Leitura por caminho aceita apenas <GUID>.result.json final, nunca .tmp.
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-oc-watch-v2-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
try {
    $resultFile = Join-Path $tmpDir 'abc.result.json'
    $tmpFile = "$resultFile.tmp"
    $wrOk | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultFile -Encoding utf8
    $wrOk | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tmpFile -Encoding utf8
    Assert-Eq 'path: final result aceito' (Get-OpenCodeAcceptedResult -Path $resultFile).accepted $true
    Assert-Eq 'path: tmp ignorado/rejeitado' (Get-OpenCodeAcceptedResult -Path $tmpFile).accepted $false
} finally {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

# 23) E2E do Watch-OpenCodeJob.ps1: processo real, JSONL representativo e exit code real do watcher.
function Invoke-WatcherE2E {
    param(
        [string]$Name,
        [string[]]$StreamLines,
        [string]$StderrText = '',
        [int]$OpencodeProcessExitCode = 0,
        [bool]$ExpectAccepted,
        [int]$ExpectedWatcherExitCode,
        [string]$ExpectedDisposition,
        [string]$ExpectedReason,
        [bool]$ExpectFinalLabel,
        [bool]$WriteExitCodeFile = $true,
        [bool]$ExpectOpencodeExitCodeNull = $false
    )
    $jobDir = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-oc-watch-e2e-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $jobDir -Force | Out-Null
    try {
        $jobId = [guid]::NewGuid().ToString('N')
        $base = Join-Path $jobDir $jobId
        $streamPath = "$base.stream.jsonl"
        $stderrPath = "$base.stderr.txt"
        $requestPath = "$base.request.json"
        $resultPath = "$base.result.json"
        $exitCodePath = "$base.exitcode.txt"
        $stdoutPath = Join-Path $jobDir "$Name.stdout.txt"
        $watchErrPath = Join-Path $jobDir "$Name.watch-stderr.txt"

        $StreamLines | Set-Content -LiteralPath $streamPath -Encoding utf8
        Set-Content -LiteralPath $stderrPath -Value $StderrText -Encoding utf8
        [pscustomobject]@{
            jobId = $jobId; model = 'fake/model'; agent = 'reviewer-ro'
            prompt = 'SEGREDO_PROMPT_NAO_DEVE_APARECER'; resultPath = $resultPath
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $requestPath -Encoding utf8

        $sleeperScript = Join-Path $jobDir "$Name-sleeper.ps1"
        $sleeperLines = [System.Collections.Generic.List[string]]::new()
        $sleeperLines.Add('Start-Sleep -Milliseconds 3000')
        if ($WriteExitCodeFile) {
            $sleeperLines.Add("Set-Content -LiteralPath '$($exitCodePath.Replace("'", "''"))' -Value '$OpencodeProcessExitCode' -Encoding ascii -NoNewline")
        }
        $sleeperLines.Add("exit $OpencodeProcessExitCode")
        $sleeperLines | Set-Content -LiteralPath $sleeperScript -Encoding utf8
        $sleeper = Start-Process pwsh -ArgumentList @('-NoProfile','-File',$sleeperScript) -WindowStyle Hidden -PassThru
        $watcher = Join-Path $PSScriptRoot 'Watch-OpenCodeJob.ps1'
        $watch = Start-Process pwsh -ArgumentList @(
            '-NoProfile','-File',$watcher,
            '-JobId',$jobId,'-ProcessId',"$($sleeper.Id)",'-TempDir',$jobDir,'-IntervalSeconds','1','-SilenceThresholdSeconds','30'
        ) -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $watchErrPath
        $watch.WaitForExit(30000) | Out-Null
        if (-not $watch.HasExited) {
            try { $watch.Kill($true) } catch { }
            throw "watcher e2e '$Name' excedeu timeout"
        }
        $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw -Encoding utf8 } else { '' }
        $json = Get-Content -LiteralPath $resultPath -Raw -Encoding utf8 | ConvertFrom-Json
        Assert-Eq "$Name e2e: process exit" $watch.ExitCode $ExpectedWatcherExitCode
        Assert-Eq "$Name e2e: json watcherExitCode" $json.watcherExitCode $ExpectedWatcherExitCode
        if ($ExpectOpencodeExitCodeNull) {
            Assert-Eq "$Name e2e: opencodeExitCode null" ($null -eq $json.opencodeExitCode) $true
        } else {
            Assert-Eq "$Name e2e: opencodeExitCode" $json.opencodeExitCode $OpencodeProcessExitCode
        }
        Assert-Eq "$Name e2e: accepted" $json.resultAccepted $ExpectAccepted
        Assert-Eq "$Name e2e: disposition" $json.finalTextDisposition $ExpectedDisposition
        Assert-Eq "$Name e2e: reason" $json.rejectionReason $ExpectedReason
        Assert-Eq "$Name e2e: helper" (Get-OpenCodeAcceptedResult -Path $resultPath).accepted $ExpectAccepted
        Assert-Eq "$Name e2e: RESPOSTA FINAL policy" ([bool]($stdout -match 'RESPOSTA FINAL')) $ExpectFinalLabel
        if (-not $ExpectAccepted) {
            Assert-Eq "$Name e2e: sem TEXTO preview" ([bool]($stdout -match 'TEXTO:')) $false
            Assert-Eq "$Name e2e: sem prompt bruto" ([bool]($stdout -match 'SEGREDO_PROMPT_NAO_DEVE_APARECER')) $false
        }
    } finally {
        Remove-Item -LiteralPath $jobDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$watchLinesOk = @(
    '{"type":"text","part":{"messageID":"m1","text":"pre"}}',
    '{"type":"tool_use","part":{"tool":"read","state":{"input":{"description":"fixture"}}}}',
    'linha invalida ignoravel',
    '{"type":"text","part":{"messageID":"m2","text":"resposta "}}',
    '{"type":"text","part":{"messageID":"m2","text":"aceita"}}',
    '{"type":"step_finish","part":{"reason":"stop","cost":0.01,"tokens":{"total":12}}}'
)
$fallbackFixturePath = Join-Path (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path 'xpz-llm-delegate\fixtures\opencode-reviewer-ro\fallback-warning.txt'
$fallbackText = Get-Content -LiteralPath $fallbackFixturePath -Raw -Encoding utf8
Invoke-WatcherE2E -Name 'watch-accepted' -StreamLines $watchLinesOk -OpencodeProcessExitCode 0 `
    -ExpectAccepted $true -ExpectedWatcherExitCode 0 -ExpectedDisposition 'accepted' -ExpectedReason '' -ExpectFinalLabel $true
Invoke-WatcherE2E -Name 'watch-fallback' -StreamLines $watchLinesOk -StderrText $fallbackText -OpencodeProcessExitCode 0 `
    -ExpectAccepted $false -ExpectedWatcherExitCode 20 -ExpectedDisposition 'rejected-fallback' -ExpectedReason 'opencode-agent-fallback-to-build' -ExpectFinalLabel $false
Invoke-WatcherE2E -Name 'watch-exit-nonzero' -StreamLines $watchLinesOk -OpencodeProcessExitCode 7 `
    -ExpectAccepted $false -ExpectedWatcherExitCode 20 -ExpectedDisposition 'rejected-error' -ExpectedReason 'opencode-exit-nonzero' -ExpectFinalLabel $false
Invoke-WatcherE2E -Name 'watch-exit-unknown' -StreamLines $watchLinesOk -OpencodeProcessExitCode 0 -WriteExitCodeFile $false `
    -ExpectAccepted $false -ExpectedWatcherExitCode 20 -ExpectedDisposition 'rejected-error' -ExpectedReason 'opencode-exit-unknown' -ExpectFinalLabel $false -ExpectOpencodeExitCodeNull $true

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-OpenCodeStreamSupportSelfTest.ps1" }
Write-Host 'OK: Test-OpenCodeStreamSupportSelfTest.ps1' -ForegroundColor Cyan
