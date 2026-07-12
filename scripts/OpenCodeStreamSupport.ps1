#requires -Version 7.4
<#
.SYNOPSIS
    Funções compartilhadas de parsing do stream JSON do opencode (skill xpz-llm-delegate).
.DESCRIPTION
    Módulo dot-source consumido por Invoke-OpenCode.ps1 e Watch-OpenCodeJob.ps1 para evitar
    duplicar a lógica de extracao. Não invoca opencode (o parsing é puro; a única leitura externa
    é Get-OpenCodeUsageLimitError, que apenas LÊ o log do opencode para diagnosticar HTTP 429).

    Eventos do `opencode run --format json`: um objeto JSON por linha, com `type`
    (`step_start`, `text`, `tool_use`, `step_finish`, `error`) e `part`. Cada evento `text`
    pertence a uma mensagem (`part.messageID`); a resposta final e a última mensagem.

    Contrato validado por Test-OpenCodeStreamSupportSelfTest.ps1.
#>

Set-StrictMode -Version Latest

function Get-OcProp {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function ConvertFrom-OpenCodeStreamLines {
    # Converte as linhas JSONL em eventos; ignora linhas vazias/nao-parseaveis.
    param([string[]]$Lines)
    $events = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @($Lines)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try { $events.Add(($line | ConvertFrom-Json)) } catch { }
    }
    return $events
}

function Get-OpenCodeStreamErrorMessage {
    # Mensagem do último evento type=error, ou $null se não houver erro.
    param([object[]]$Events)
    $errs = @(@($Events) | Where-Object { (Get-OcProp $_ 'type') -eq 'error' })
    if ($errs.Count -eq 0) { return $null }
    $last = $errs[$errs.Count - 1]
    $msg = Get-OcProp (Get-OcProp (Get-OcProp $last 'error') 'data') 'message'
    if ([string]::IsNullOrWhiteSpace($msg)) { $msg = ($last | ConvertTo-Json -Compress) }
    return [string]$msg
}

function Get-OpenCodeTextParts {
    # Lista de [pscustomobject]{ mid; text } para eventos text com texto nao-vazio, em ordem.
    param([object[]]$Events)
    $parts = [System.Collections.Generic.List[object]]::new()
    foreach ($e in @($Events)) {
        if ((Get-OcProp $e 'type') -ne 'text') { continue }
        $part = Get-OcProp $e 'part'
        $text = [string](Get-OcProp $part 'text')
        if ([string]::IsNullOrEmpty($text)) { continue }
        $parts.Add([pscustomobject]@{ mid = [string](Get-OcProp $part 'messageID'); text = $text })
    }
    return $parts
}

function Get-OpenCodeFinalText {
    # Resposta final = concatenacao das partes de texto da ÚLTIMA mensagem (messageID).
    # Robusto a mensagem final fragmentada em varias partes; sem messageID, usa a última parte.
    param([object[]]$TextParts)
    $tp = @(@($TextParts) | Where-Object { $null -ne $_ })
    if ($tp.Count -eq 0) { return '' }
    $lastMid = [string]$tp[$tp.Count - 1].mid
    if ([string]::IsNullOrEmpty($lastMid)) { return [string]$tp[$tp.Count - 1].text }
    return (@($tp | Where-Object { [string]$_.mid -eq $lastMid } | ForEach-Object { [string]$_.text }) -join '')
}

function Get-OpenCodeAllText {
    # Toda a narracao (preambulos de passo + resposta final), em ordem.
    param([object[]]$TextParts)
    return (@(@($TextParts) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.text }) -join "`n`n")
}

function Get-OpenCodeCompletionSignal {
    # Sinal de conclusao do stream, a partir do ULTIMO evento step_finish e seu part.reason.
    # Achado D: leitura agentica que estoura passos encerra um step com reason != 'stop' (ou
    # sem step_finish algum), e o adapter devolvia o preambulo como se fosse a resposta final.
    # Retorna [pscustomobject]{ hasStepFinish; reason; completionVerdict; finalText; lastError; totalCost; tokens }:
    #   hasStepFinish=$false           -> nenhum step_finish no stream (conclusao ausente)
    #   hasStepFinish=$true; reason=''  -> step_finish presente mas sem campo reason (tratar como ausente)
    #   hasStepFinish=$true; reason='stop'|'length'|'tool-calls'|... -> reason explicito
    param([object[]]$Events)
    $steps = @(@($Events) | Where-Object { (Get-OcProp $_ 'type') -eq 'step_finish' })
    $parts = @(Get-OpenCodeTextParts -Events $Events)
    $finalText = Get-OpenCodeFinalText -TextParts $parts
    $lastError = Get-OpenCodeStreamErrorMessage -Events $Events
    $totalCost = [double]0
    $lastTokens = 0
    foreach ($step in $steps) {
        $part = Get-OcProp $step 'part'
        $cost = Get-OcProp $part 'cost'
        if ($null -ne $cost) { $totalCost += [double]$cost }
        $tok = Get-OcProp $part 'tokens'
        $tot = Get-OcProp $tok 'total'
        if ($null -ne $tot) { $lastTokens = [int]$tot }
    }
    if ($steps.Count -eq 0) {
        $verdict = Get-OpenCodeCompletionVerdict -HasStepFinish $false -Reason '' -FinalText $finalText
        return [pscustomobject]@{
            hasStepFinish = $false; reason = ''; finishReason = ''
            completionVerdict = [string]$verdict.status; finalText = $finalText; lastError = $lastError
            totalCost = $totalCost; tokens = $lastTokens; verdictMessage = [string]$verdict.message
        }
    }
    $last = $steps[$steps.Count - 1]
    $reason = [string](Get-OcProp (Get-OcProp $last 'part') 'reason')
    $verdict = Get-OpenCodeCompletionVerdict -HasStepFinish $true -Reason $reason -FinalText $finalText
    return [pscustomobject]@{
        hasStepFinish = $true; reason = $reason; finishReason = $reason
        completionVerdict = [string]$verdict.status; finalText = $finalText; lastError = $lastError
        totalCost = $totalCost; tokens = $lastTokens; verdictMessage = [string]$verdict.message
    }
}

function Get-OpenCodeCompletionVerdict {
    # Precedencia FIXADA do Achado D (NAO trata erro explicito de stream; isso e tratado a parte,
    # com prioridade, por Get-OpenCodeStreamErrorMessage no chamador):
    #   (1) step_finish com reason != 'stop' (inclui 'length','tool-calls') -> truncated
    #   (2) sem step_finish OU reason vazio (sinal de conclusao ausente)     -> no-completion
    #   (3) texto final vazio, apos conclusao limpa (reason='stop')          -> empty
    #   senao                                                                -> ok
    # Cada caso e disjunto -> uma mensagem deterministica por cenario (fixtures do self-test).
    # 'reason' nulo/ausente e tratado como cadeia vazia (cai em (2)); NUNCA lanca sob StrictMode.
    #
    # Vocabulario de reason: SO 'stop' e sucesso. QUALQUER outro valor ('length', 'tool-calls',
    # 'content_filter', 'unknown', 'max_tokens', ...) cai em (1) truncated POR DESIGN — inclusive
    # 'tool-calls' com preambulo textual ja presente, que e justamente o vazamento do Achado D
    # (o turno viraria tool call e o preambulo nao e a resposta final). NAO "consertar" essa
    # precedencia. Risco a vigiar: se o opencode renomear 'stop' upstream (ex.: 'done'), toda
    # chamada legitima viraria truncated -> revisar aqui e em xpz-llm-delegate/SKILL.md (LIMITE
    # CONHECIDO opencode), onde fica registrada a versao do opencode contra a qual foi mapeado.
    param([bool]$HasStepFinish, [string]$Reason, [string]$FinalText)
    if ($HasStepFinish -and -not [string]::IsNullOrEmpty($Reason) -and $Reason -ne 'stop') {
        return [pscustomobject]@{ status = 'truncated'; reason = $Reason; message = "BLOCK: resposta truncada (reason=$Reason). Use -Raw para inspecionar." }
    }
    if (-not $HasStepFinish -or [string]::IsNullOrEmpty($Reason)) {
        return [pscustomobject]@{ status = 'no-completion'; reason = ''; message = 'BLOCK: resposta sem sinal de conclusao (step_finish/reason ausente). Use -Raw para inspecionar.' }
    }
    if ([string]::IsNullOrWhiteSpace($FinalText)) {
        return [pscustomobject]@{ status = 'empty'; reason = $Reason; message = 'BLOCK: nenhum evento de texto na resposta. Use -Raw para inspecionar.' }
    }
    return [pscustomobject]@{ status = 'ok'; reason = $Reason; message = '' }
}

function Get-OpenCodeUsageLimitError {
    # O opencode retenta o HTTP 429 (limite de uso do provider) em SILENCIO: stdout/stderr ficam
    # vazios e a chamada so estoura por -TimeoutSec, mascarando a causa como "timeout". O 429 e
    # gravado apenas no log proprio do opencode (~/.local/share/opencode/log/<ts>.log; respeita
    # XDG_DATA_HOME). Varre os logs escritos na janela do processo (mtime >= SinceTime - 5s) e
    # devolve a mensagem do limite, ou $null se nao houver 429 no periodo. SO LEITURA do log;
    # nao invoca opencode. -LogDir (override; default = dir real) habilita o self-test por fixture.
    param(
        [Parameter(Mandatory)][datetime]$SinceTime,
        [string]$LogDir
    )
    if ([string]::IsNullOrWhiteSpace($LogDir)) {
        $base = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path $env:USERPROFILE '.local/share' }
        $LogDir = Join-Path $base 'opencode/log'
    }
    if (-not (Test-Path -LiteralPath $LogDir -PathType Container)) { return $null }
    $cutoff = $SinceTime.AddSeconds(-5)
    $logs = @(Get-ChildItem -LiteralPath $LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $cutoff } | Sort-Object LastWriteTime -Descending)
    foreach ($log in $logs) {
        $text = Get-Content -LiteralPath $log.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrEmpty($text)) { continue }
        if ($text -match '"statusCode":\s*429') {
            $m = [regex]::Match($text, 'reached your[^"\\]*usage limit[^"\\]*')
            if ($m.Success) { return $m.Value.Trim() }
            return 'HTTP 429 - limite de uso do provider'
        }
    }
    return $null
}

function Get-OpenCodeRequestedAgent {
    param([string]$RequestPath)
    if ([string]::IsNullOrWhiteSpace($RequestPath) -or -not (Test-Path -LiteralPath $RequestPath -PathType Leaf)) {
        return '(unknown)'
    }
    try {
        $req = Get-Content -LiteralPath $RequestPath -Raw -Encoding utf8 | ConvertFrom-Json
        $agent = Get-OcProp $req 'agent'
        if ([string]::IsNullOrWhiteSpace([string]$agent)) { return '(unknown)' }
        return [string]$agent
    } catch {
        return '(unknown)'
    }
}

function Join-OpenCodeErrorParts {
    param([string[]]$Parts)
    return (@($Parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ' | ')
}

function Get-OpenCodeWatchResult {
    param(
        [Parameter(Mandatory)] [string] $JobId,
        [Parameter(Mandatory)] $CompletionSignal,
        [string] $StderrText = '',
        [bool] $FallbackToBuild,
        [string] $FallbackStderrPattern = '',
        [string] $RequestedAgent = '(unknown)',
        [AllowNull()] [Nullable[int]] $OpencodeExitCode,
        [bool] $OpencodeExitObserved,
        [datetime] $FinishedAt = (Get-Date)
    )

    $finalText = [string](Get-OcProp $CompletionSignal 'finalText')
    $lastError = [string](Get-OcProp $CompletionSignal 'lastError')
    $hasStepFinish = [bool](Get-OcProp $CompletionSignal 'hasStepFinish')
    $finishReason = [string](Get-OcProp $CompletionSignal 'reason')
    $completionVerdict = [string](Get-OcProp $CompletionSignal 'completionVerdict')
    $verdictMessage = [string](Get-OcProp $CompletionSignal 'verdictMessage')
    $totalCost = Get-OcProp $CompletionSignal 'totalCost'
    $tokens = Get-OcProp $CompletionSignal 'tokens'
    if ([string]::IsNullOrWhiteSpace($completionVerdict)) {
        $fallbackVerdict = Get-OpenCodeCompletionVerdict -HasStepFinish $hasStepFinish -Reason $finishReason -FinalText $finalText
        $completionVerdict = [string]$fallbackVerdict.status
        $verdictMessage = [string]$fallbackVerdict.message
    }

    $status = if (-not [string]::IsNullOrWhiteSpace($lastError)) { 'error' }
    elseif ($completionVerdict -eq 'truncated') { 'truncado' }
    elseif ($completionVerdict -eq 'no-completion') { 'sem-conclusao' }
    elseif ($completionVerdict -eq 'empty') { 'sem-texto' }
    else { 'completed' }

    $exitCause = $null
    if (-not $OpencodeExitObserved -or $null -eq $OpencodeExitCode) {
        $exitCause = [pscustomobject]@{
            reason = 'opencode-exit-unknown'
            message = 'BLOCK: opencode process exit code unavailable; opencodeExitCode=<unknown>'
        }
    } elseif ([int]$OpencodeExitCode -ne 0) {
        $exitCause = [pscustomobject]@{
            reason = 'opencode-exit-nonzero'
            message = "BLOCK: opencode process exited with non-zero code; opencodeExitCode=$([int]$OpencodeExitCode)"
        }
    }

    $disposition = 'accepted'
    $rejectionReason = ''
    $errorParts = [System.Collections.Generic.List[string]]::new()
    if ($FallbackToBuild) {
        $disposition = 'rejected-fallback'
        $rejectionReason = 'opencode-agent-fallback-to-build'
    } elseif ($exitCause) {
        $disposition = 'rejected-error'
        $rejectionReason = [string]$exitCause.reason
    } elseif (-not [string]::IsNullOrWhiteSpace($lastError)) {
        $disposition = 'rejected-error'
        $rejectionReason = 'opencode-error'
    } elseif ($completionVerdict -eq 'truncated') {
        $disposition = 'rejected-truncated'
        $rejectionReason = 'truncated'
    } elseif ($completionVerdict -eq 'no-completion') {
        $disposition = 'rejected-no-completion'
        $rejectionReason = 'no-completion'
    } elseif ($completionVerdict -eq 'empty') {
        $disposition = 'rejected-empty'
        $rejectionReason = 'empty'
    }

    if (-not [string]::IsNullOrWhiteSpace($verdictMessage) -and $completionVerdict -ne 'ok') { $errorParts.Add($verdictMessage) }
    if ($exitCause) { $errorParts.Add([string]$exitCause.message) }
    if (-not [string]::IsNullOrWhiteSpace($lastError)) { $errorParts.Add($lastError) }

    $fallbackDetail = $null
    if ($FallbackToBuild) {
        $renderedFinish = if ([string]::IsNullOrEmpty($finishReason)) { '<empty>' } else { $finishReason }
        $fallbackMsg = "BLOCK: opencode agent fallback to build detected; requestedAgent=$RequestedAgent; originalStatus=$status; originalFinishReason=$renderedFinish"
        $errorParts.Add($fallbackMsg)
        $fallbackDetail = [pscustomobject]@{
            reason = 'opencode-agent-fallback-to-build'
            message = $fallbackMsg
            requestedAgent = $RequestedAgent
            originalStatus = $status
            originalFinishReason = $finishReason
            originalErrorPresent = (-not [string]::IsNullOrWhiteSpace($lastError))
            acceptanceInvalidated = $true
            stderrPattern = $FallbackStderrPattern
        }
    }

    $accepted = (
        $disposition -eq 'accepted' -and
        $status -eq 'completed' -and
        $hasStepFinish -and
        $completionVerdict -eq 'ok' -and
        $finishReason -eq 'stop' -and
        -not [string]::IsNullOrWhiteSpace($finalText) -and
        -not $FallbackToBuild -and
        $null -eq $fallbackDetail -and
        [string]::IsNullOrWhiteSpace($lastError) -and
        $OpencodeExitObserved -and
        $null -ne $OpencodeExitCode -and
        [int]$OpencodeExitCode -eq 0
    )

    if (-not $accepted -and $disposition -eq 'accepted') {
        $disposition = 'rejected-error'
        $rejectionReason = if ($exitCause) { [string]$exitCause.reason } else { 'opencode-error' }
        if ($errorParts.Count -eq 0) { $errorParts.Add('BLOCK: opencode watch result did not satisfy acceptance criteria.') }
    }

    $watcherExitCode = if ($accepted) { 0 } else { 20 }
    $errorText = if ($accepted) { $null } else { Join-OpenCodeErrorParts -Parts @($errorParts) }
    if (-not $accepted -and [string]::IsNullOrWhiteSpace($errorText)) {
        $errorText = 'BLOCK: opencode watch result rejected.'
    }

    return [pscustomobject]([ordered]@{
        schemaVersion = 2
        jobId = $JobId
        status = $status
        resultAccepted = $accepted
        watcherExitCode = $watcherExitCode
        opencodeExitCode = $(if ($null -eq $OpencodeExitCode) { $null } else { [int]$OpencodeExitCode })
        finalText = $finalText
        acceptedFinalText = $(if ($accepted) { $finalText } else { '' })
        finalTextDisposition = $(if ($accepted) { 'accepted' } else { $disposition })
        error = $errorText
        rejectionReason = $(if ($accepted) { '' } else { $rejectionReason })
        totalCost = $totalCost
        tokens = $tokens
        finishReason = $finishReason
        hasStepFinish = $hasStepFinish
        completionVerdict = $completionVerdict
        stderr = [string]$StderrText
        fallbackToBuild = $FallbackToBuild
        fallbackDetail = $fallbackDetail
        requestedAgent = $RequestedAgent
        finishedAt = $FinishedAt.ToString('o')
    })
}

function Get-OpenCodeAcceptedResult {
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Object')] [object] $Result,
        [Parameter(Mandatory, ParameterSetName = 'Path')] [string] $Path
    )

    $reason = ''
    $obj = $Result
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if ($Path -notmatch '\.result\.json$' -or $Path -match '\.tmp$') {
            return [pscustomobject]@{ accepted = $false; reason = 'path-not-final-result'; result = $null; acceptedFinalText = ''; error = 'Path is not a final <GUID>.result.json file.' }
        }
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return [pscustomobject]@{ accepted = $false; reason = 'result-file-missing'; result = $null; acceptedFinalText = ''; error = 'Result file not found.' }
        }
        try { $obj = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json }
        catch { return [pscustomobject]@{ accepted = $false; reason = 'result-json-invalid'; result = $null; acceptedFinalText = ''; error = $_.Exception.Message } }
    }

    function HasProp($o, [string]$n) { return ($null -ne $o -and $null -ne $o.PSObject.Properties[$n]) }
    function Val($o, [string]$n) { if (HasProp $o $n) { return $o.PSObject.Properties[$n].Value }; return $null }
    function Convert-OpenCodeResultInt($o, [string]$n) {
        if (-not (HasProp $o $n)) { return [pscustomobject]@{ ok = $false; value = 0 } }
        $v = Val $o $n
        if ($null -eq $v) { return [pscustomobject]@{ ok = $false; value = 0 } }
        $parsed = 0
        if (-not [int]::TryParse([string]$v, [ref]$parsed)) {
            return [pscustomobject]@{ ok = $false; value = 0 }
        }
        return [pscustomobject]@{ ok = $true; value = $parsed }
    }
    $failResult = {
        param([string]$r, [string]$e)
        return [pscustomobject]@{ accepted = $false; reason = $r; result = $obj; acceptedFinalText = ''; error = $e }
    }

    foreach ($p in @('schemaVersion','resultAccepted','status','hasStepFinish','completionVerdict','finishReason','acceptedFinalText','finalText','watcherExitCode','opencodeExitCode','fallbackToBuild','fallbackDetail','finalTextDisposition','rejectionReason','error')) {
        if (-not (HasProp $obj $p)) { return (& $failResult 'missing-field' "Missing field: $p") }
    }
    $schemaVersionParsed = Convert-OpenCodeResultInt $obj 'schemaVersion'
    if (-not $schemaVersionParsed.ok) { return (& $failResult 'invalid-schemaVersion' 'schemaVersion must be an integer.') }
    $schemaVersion = $schemaVersionParsed.value
    if ($schemaVersion -ne 2) { return (& $failResult 'unsupported-schemaVersion' 'schemaVersion must be exactly 2.') }
    if ((Val $obj 'resultAccepted') -isnot [bool]) { return (& $failResult 'invalid-resultAccepted' 'resultAccepted must be boolean.') }
    if ((Val $obj 'hasStepFinish') -isnot [bool]) { return (& $failResult 'invalid-hasStepFinish' 'hasStepFinish must be boolean.') }
    if ((Val $obj 'fallbackToBuild') -isnot [bool]) { return (& $failResult 'invalid-fallbackToBuild' 'fallbackToBuild must be boolean.') }
    $watcherExitCodeParsed = Convert-OpenCodeResultInt $obj 'watcherExitCode'
    if (-not $watcherExitCodeParsed.ok) { return (& $failResult 'invalid-watcherExitCode' 'watcherExitCode must be an integer.') }
    $watcherExitCode = $watcherExitCodeParsed.value
    $opencodeExitCode = $null
    if ($null -ne (Val $obj 'opencodeExitCode')) {
        $opencodeExitCodeParsed = Convert-OpenCodeResultInt $obj 'opencodeExitCode'
        if (-not $opencodeExitCodeParsed.ok) { return (& $failResult 'invalid-opencodeExitCode' 'opencodeExitCode must be integer or null.') }
        $opencodeExitCode = $opencodeExitCodeParsed.value
    }

    $validStatus = @('completed','truncado','sem-conclusao','sem-texto','error')
    $validVerdict = @('ok','truncated','no-completion','empty','error')
    $validDisposition = @('accepted','rejected-fallback','rejected-error','rejected-truncated','rejected-no-completion','rejected-empty')
    $validReason = @('opencode-agent-fallback-to-build','opencode-exit-nonzero','opencode-exit-unknown','opencode-error','truncated','no-completion','empty')
    if ($validStatus -notcontains [string](Val $obj 'status')) { return (& $failResult 'invalid-status' 'Invalid status.') }
    if ($validVerdict -notcontains [string](Val $obj 'completionVerdict')) { return (& $failResult 'invalid-completionVerdict' 'Invalid completionVerdict.') }
    if ($validDisposition -notcontains [string](Val $obj 'finalTextDisposition')) { return (& $failResult 'invalid-finalTextDisposition' 'Invalid finalTextDisposition.') }
    if ((Val $obj 'finalText') -isnot [string] -or (Val $obj 'acceptedFinalText') -isnot [string] -or (Val $obj 'rejectionReason') -isnot [string]) {
        return (& $failResult 'invalid-string-shape' 'Critical text fields must be strings.')
    }

    if ([bool](Val $obj 'resultAccepted')) {
        $ok = (
            [string](Val $obj 'status') -eq 'completed' -and
            [bool](Val $obj 'hasStepFinish') -and
            [string](Val $obj 'completionVerdict') -eq 'ok' -and
            [string](Val $obj 'finishReason') -eq 'stop' -and
            $watcherExitCode -eq 0 -and
            $null -ne $opencodeExitCode -and $opencodeExitCode -eq 0 -and
            -not [bool](Val $obj 'fallbackToBuild') -and
            $null -eq (Val $obj 'fallbackDetail') -and
            [string](Val $obj 'finalTextDisposition') -eq 'accepted' -and
            [string](Val $obj 'rejectionReason') -eq '' -and
            $null -eq (Val $obj 'error') -and
            [string](Val $obj 'acceptedFinalText') -eq [string](Val $obj 'finalText') -and
            -not [string]::IsNullOrWhiteSpace([string](Val $obj 'acceptedFinalText'))
        )
        if (-not $ok) { return (& $failResult 'accepted-shape-invalid' 'Accepted result does not satisfy v2 acceptance shape.') }
        return [pscustomobject]@{ accepted = $true; reason = ''; result = $obj; acceptedFinalText = [string](Val $obj 'acceptedFinalText'); error = $null }
    }

    if ([string](Val $obj 'acceptedFinalText') -ne '') { return (& $failResult 'rejected-with-accepted-text' 'Rejected result must have empty acceptedFinalText.') }
    if ([string]::IsNullOrWhiteSpace([string](Val $obj 'error'))) { return (& $failResult 'rejected-without-error' 'Rejected result must have non-empty error.') }
    if ([string](Val $obj 'finalTextDisposition') -eq 'accepted') { return (& $failResult 'rejected-disposition-invalid' 'Rejected result must not have accepted disposition.') }
    $rr = [string](Val $obj 'rejectionReason')
    if ($validReason -notcontains $rr) { return (& $failResult 'invalid-rejectionReason' 'Invalid rejectionReason.') }
    if ([string](Val $obj 'completionVerdict') -eq 'ok' -and [string](Val $obj 'finalTextDisposition') -in @('rejected-truncated','rejected-no-completion','rejected-empty')) {
        return (& $failResult 'contradictory-completionVerdict' 'completionVerdict ok contradicts rejection disposition.')
    }
    if ([bool](Val $obj 'fallbackToBuild') -or $null -ne (Val $obj 'fallbackDetail')) {
        if ([string](Val $obj 'finalTextDisposition') -ne 'rejected-fallback' -or $rr -ne 'opencode-agent-fallback-to-build') {
            return (& $failResult 'fallback-shape-invalid' 'Fallback must dominate disposition and rejectionReason.')
        }
        $fd = Val $obj 'fallbackDetail'
        if ($fd -is [string] -or $null -eq $fd) { return (& $failResult 'fallbackDetail-shape-invalid' 'fallbackDetail must be object in v2 fallback rejection.') }
        foreach ($p in @('reason','requestedAgent','stderrPattern','acceptanceInvalidated','originalStatus','originalFinishReason','originalErrorPresent')) {
            if (-not (HasProp $fd $p)) { return (& $failResult 'fallbackDetail-missing-field' "fallbackDetail missing field: $p") }
        }
        if ([string](Val $fd 'reason') -ne 'opencode-agent-fallback-to-build' -or (Val $fd 'acceptanceInvalidated') -ne $true -or (Val $fd 'originalErrorPresent') -isnot [bool] -or [string]::IsNullOrWhiteSpace([string](Val $fd 'stderrPattern'))) {
            return (& $failResult 'fallbackDetail-shape-invalid' 'fallbackDetail has invalid v2 shape.')
        }
    }
    if ($watcherExitCode -ne 20) { return (& $failResult 'rejected-watcherExitCode-invalid' 'Rejected v2 result must have watcherExitCode 20.') }
    return [pscustomobject]@{ accepted = $false; reason = $rr; result = $obj; acceptedFinalText = ''; error = [string](Val $obj 'error') }
}
