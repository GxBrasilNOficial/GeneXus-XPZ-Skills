#requires -Version 7.4
<#
.SYNOPSIS
    Funções compartilhadas de parsing do stream JSON do opencode (skill xpz-llm-delegate).
.DESCRIPTION
    Módulo dot-source consumido por Invoke-OpenCode.ps1 e Watch-OpenCodeJob.ps1 para evitar
    duplicar a lógica de extracao. Não invoca opencode (o parsing é puro; a unica leitura externa
    e o resolvedor de limite de provider, que apenas LE o log do opencode).

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

function Get-OpenCodeDefaultProviderLogDir {
    $base = if ($env:XDG_DATA_HOME) { $env:XDG_DATA_HOME } else { Join-Path $env:USERPROFILE '.local/share' }
    return (Join-Path $base 'opencode/log')
}

function Convert-OpenCodeSinceTimeUtc {
    param([datetime]$SinceTime)
    if ($SinceTime.Kind -eq [DateTimeKind]::Utc) { return $SinceTime }
    return $SinceTime.ToUniversalTime()
}

function Convert-OpenCodeLineTimestampUtc {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [datetime]) {
        $dt = [datetime]$Value
        if ($dt.Kind -eq [DateTimeKind]::Utc) { return $dt }
        if ($dt.Kind -eq [DateTimeKind]::Unspecified) {
            return [DateTime]::SpecifyKind($dt, [DateTimeKind]::Utc)
        }
        return $dt.ToUniversalTime()
    }
    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $dto = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse($s, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$dto)) {
        return $dto.UtcDateTime
    }
    return $null
}

function Get-OpenCodeProviderLimitKindFromText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    $usagePhrase = '(?i)usage limit|Monthly usage limit|weekly usage limit|Insufficient balance|limite de uso|insufficient coding plan balance|resource_exhausted|Payment Required'
    $usageRx = @(
        '(?i)insufficient\s+balance',
        '(?i)insufficient\s+coding\s+plan\s+balance',
        '(?i)(?:credits?|balance|saldo)\s+exhausted',
        '(?i)saldo\s+insuficiente',
        '(?i)sem\s+quota'
    )
    $isUsage = ($Text -match $usagePhrase)
    if (-not $isUsage) {
        foreach ($rx in $usageRx) {
            if ($Text -match $rx) { $isUsage = $true; break }
        }
    }
    if (-not $isUsage) {
        if ($Text -match '"statusCode"\s*:\s*402') { $isUsage = $true }
        elseif ($Text -match '(?i)(?:^|\s)statusCode=402(?:\s|$)') { $isUsage = $true }
    }
    if ($isUsage) { return 'usage-limit' }
    if ($Text -match '"statusCode"\s*:\s*429') { return 'rate-limit' }
    if ($Text -match '(?i)(?:^|\s)statusCode=429(?:\s|$)') { return 'rate-limit' }
    if ($Text -match '(?i)Too Many Requests|rate limit|rate_limit') { return 'rate-limit' }
    return $null
}

function Get-OpenCodeProviderLimitLevelRank {
    param([string]$Level)
    if ([string]::IsNullOrWhiteSpace($Level)) { return 1 }
    if ($Level -match '(?i)^(ERROR|WARN|WARNING)$') { return 0 }
    if ($Level -match '(?i)^INFO$') { return 2 }
    return 1
}

function Get-OpenCodeStreamErrorCandidates {
    param([string[]]$Lines)
    $list = [System.Collections.Generic.List[object]]::new()
    $i = -1
    foreach ($line in @($Lines)) {
        $i++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $evt = $null
        try { $evt = $line | ConvertFrom-Json } catch { continue }
        if ((Get-OcProp $evt 'type') -ne 'error') { continue }
        $text = Get-OcProp (Get-OcProp (Get-OcProp $evt 'error') 'data') 'message'
        if ([string]::IsNullOrWhiteSpace($text)) { $text = ($evt | ConvertTo-Json -Compress) }
        $list.Add([pscustomobject]@{ lineIndex = $i; text = [string]$text })
    }
    return @($list)
}

function Get-OpenCodeProviderLimitLogLines {
    param(
        [Parameter(Mandatory)][datetime]$SinceTime,
        [string]$LogDir,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    if ([string]::IsNullOrWhiteSpace($LogDir)) { $LogDir = Get-OpenCodeDefaultProviderLogDir }
    $result = [System.Collections.Generic.List[object]]::new()
    if (-not (Test-Path -LiteralPath $LogDir -PathType Container)) { return @($result) }
    $t0 = Convert-OpenCodeSinceTimeUtc -SinceTime $SinceTime
    if ($NowUtc.Kind -ne [DateTimeKind]::Utc) { $NowUtc = $NowUtc.ToUniversalTime() }
    $fileStart = $t0.AddSeconds(-5)
    $logs = @(Get-ChildItem -LiteralPath $LogDir -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $fileStart -and $_.LastWriteTimeUtc -le $NowUtc })
    foreach ($log in $logs) {
        $rawLines = @(Get-Content -LiteralPath $log.FullName -Encoding utf8 -ErrorAction SilentlyContinue)
        $li = -1
        foreach ($raw in $rawLines) {
            $li++
            $lineTs = $null
            $level = ''
            $obj = $null
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                try { $obj = $raw | ConvertFrom-Json } catch { $obj = $null }
            }
            if ($null -ne $obj) {
                foreach ($name in @('time', 'timestamp', 'ts')) {
                    $lineTs = Convert-OpenCodeLineTimestampUtc (Get-OcProp $obj $name)
                    if ($null -ne $lineTs) { break }
                }
                $level = [string](Get-OcProp $obj 'level')
            } elseif ($raw -match 'timestamp=([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+(?:Z|[+-][0-9]{2}:[0-9]{2}))') {
                $lineTs = Convert-OpenCodeLineTimestampUtc $Matches[1]
                if ($raw -match '(?i)(?:^|\s)level=([A-Za-z]+)') { $level = [string]$Matches[1] }
            }
            if ($null -ne $lineTs) {
                if ($lineTs -lt $t0 -or $lineTs -gt $NowUtc) { continue }
            }
            $result.Add([pscustomobject]@{
                path = [string]$log.FullName
                lineIndex = $li
                raw = [string]$raw
                lineTimestampUtc = $lineTs
                lastWriteTimeUtc = $log.LastWriteTimeUtc
                level = $level
            })
        }
    }
    return @($result)
}

function Select-OpenCodeProviderLimitHit {
    param([object[]]$Candidates)
    $usage = @($Candidates | Where-Object { $_.kind -eq 'usage-limit' })
    $rate = @($Candidates | Where-Object { $_.kind -eq 'rate-limit' })
    $pool = $usage
    if ($pool.Count -eq 0) { $pool = $rate }
    if ($pool.Count -eq 0) { return $null }
    $withTs = @($pool | Where-Object { $null -ne $_.lineTimestampUtc })
    if ($withTs.Count -gt 0) {
        $maxTs = ($withTs | Measure-Object -Property lineTimestampUtc -Maximum).Maximum
        $pool = @($withTs | Where-Object { $_.lineTimestampUtc -eq $maxTs })
    }
    $bestLevel = ($pool | ForEach-Object { [int]$_.levelRank } | Measure-Object -Minimum).Minimum
    $pool = @($pool | Where-Object { [int]$_.levelRank -eq $bestLevel })
    $bestSrc = ($pool | ForEach-Object { [int]$_.sourceRank } | Measure-Object -Minimum).Minimum
    $pool = @($pool | Where-Object { [int]$_.sourceRank -eq $bestSrc })
    $logPool = @($pool | Where-Object { $_.source -eq 'log' })
    if ($logPool.Count -gt 0 -and $pool.Count -eq $logPool.Count) {
        $maxMtime = ($logPool | Measure-Object -Property lastWriteTimeUtc -Maximum).Maximum
        $pool = @($logPool | Where-Object { $_.lastWriteTimeUtc -eq $maxMtime })
    }
    $ord = @($pool | Sort-Object @{ Expression = { [string]$_.sourceFile }; Ascending = $true }, @{ Expression = { [int]$_.lineIndex }; Ascending = $true })
    $win = $ord[0]
    return [pscustomobject]@{
        kind = [string]$win.kind
        message = [string]$win.message
        lineTimestampUtc = $win.lineTimestampUtc
        sourceFile = [string]$win.sourceFile
        lineIndex = [int]$win.lineIndex
        source = [string]$win.source
    }
}

function Resolve-OpenCodeProviderLimitHit {
    param(
        [object[]]$StreamErrors,
        [string]$StderrText = '',
        [object[]]$LogLines,
        [datetime]$SinceTime,
        [string]$LogDir,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    $cands = [System.Collections.Generic.List[object]]::new()
    foreach ($se in @($StreamErrors)) {
        $text = [string](Get-OcProp $se 'text')
        $kind = Get-OpenCodeProviderLimitKindFromText -Text $text
        if ($null -eq $kind) { continue }
        $idx = 0
        $idxVal = Get-OcProp $se 'lineIndex'
        if ($null -ne $idxVal) { $idx = [int]$idxVal }
        $cands.Add([pscustomobject]@{
            kind = $kind; message = $text; lineTimestampUtc = $null
            sourceFile = 'stream'; lineIndex = $idx; source = 'stream'
            sourceRank = 0; levelRank = 1; lastWriteTimeUtc = [datetime]::MinValue
        })
    }
    if (-not [string]::IsNullOrWhiteSpace($StderrText)) {
        $kind = Get-OpenCodeProviderLimitKindFromText -Text $StderrText
        if ($null -ne $kind) {
            $cands.Add([pscustomobject]@{
                kind = $kind; message = [string]$StderrText; lineTimestampUtc = $null
                sourceFile = 'stderr'; lineIndex = 0; source = 'stderr'
                sourceRank = 1; levelRank = 1; lastWriteTimeUtc = [datetime]::MinValue
            })
        }
    }
    if (-not $PSBoundParameters.ContainsKey('LogLines')) {
        if ($PSBoundParameters.ContainsKey('SinceTime')) {
            $LogLines = @(Get-OpenCodeProviderLimitLogLines -SinceTime $SinceTime -LogDir $LogDir -NowUtc $NowUtc)
        } else {
            $LogLines = @()
        }
    }
    foreach ($ll in @($LogLines)) {
        $raw = [string](Get-OcProp $ll 'raw')
        $kind = Get-OpenCodeProviderLimitKindFromText -Text $raw
        if ($null -eq $kind) { continue }
        $cands.Add([pscustomobject]@{
            kind = $kind; message = $raw
            lineTimestampUtc = (Get-OcProp $ll 'lineTimestampUtc')
            sourceFile = [string](Get-OcProp $ll 'path')
            lineIndex = [int](Get-OcProp $ll 'lineIndex')
            source = 'log'; sourceRank = 2
            levelRank = (Get-OpenCodeProviderLimitLevelRank -Level ([string](Get-OcProp $ll 'level')))
            lastWriteTimeUtc = $(if ($null -ne (Get-OcProp $ll 'lastWriteTimeUtc')) { Get-OcProp $ll 'lastWriteTimeUtc' } else { [datetime]::MinValue })
        })
    }
    return (Select-OpenCodeProviderLimitHit -Candidates @($cands))
}

function Format-OpenCodeLimitBlock {
    param(
        [Parameter(Mandatory)][ValidateSet('usage-limit', 'rate-limit')][string]$Kind,
        [string]$Message = ''
    )
    $fixed = if ($Kind -eq 'usage-limit') {
        'BLOCK: opencode atingiu o limite de uso do provider. NAO e timeout tecnico; aguardar o reset do ciclo de uso (limite de uso).'
    } else {
        'BLOCK: opencode atingiu o limite de taxa do provider. Nao re-tentar imediatamente (rate limit / too many requests).'
    }
    if ([string]::IsNullOrWhiteSpace($Message)) { return $fixed }
    return ($fixed + ' ' + $Message)
}

function Format-OpenCodeWatchTimeoutBlock {
    param([Parameter(Mandatory)][int]$WatchTimeoutSec)
    return "BLOCK: Watch-OpenCodeJob atingiu WatchTimeoutSec=$WatchTimeoutSec; processo observado ainda vivo. opencode-watch-timeout"
}

function Get-OpenCodeUsageLimitError {
    # Wrapper do resolvedor (somente fonte log, janela T0). Devolve o objeto tipado ou $null.
    param(
        [Parameter(Mandatory)][datetime]$SinceTime,
        [string]$LogDir,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    return Resolve-OpenCodeProviderLimitHit -StreamErrors @() -StderrText '' -SinceTime $SinceTime -LogDir $LogDir -NowUtc $NowUtc
}

function Get-OpenCodeWatchedProcess {
    param([Parameter(Mandatory)][int]$ProcessId)
    try { return [System.Diagnostics.Process]::GetProcessById($ProcessId) } catch { return $null }
}

function Test-OpenCodeWatchedProcessIdentity {
    param($Process, [AllowNull()][Nullable[datetime]]$ExpectedStartTimeUtc)
    if ($null -eq $Process) { return $false }
    if ($Process.HasExited) { return $false }
    if ($null -eq $ExpectedStartTimeUtc) { return $false }
    try {
        $st = $Process.StartTime
        if ($st.Kind -ne [DateTimeKind]::Utc) { $st = $st.ToUniversalTime() }
        $exp = [datetime]$ExpectedStartTimeUtc
        if ($exp.Kind -ne [DateTimeKind]::Utc) { $exp = $exp.ToUniversalTime() }
        return ([Math]::Abs(($st - $exp).TotalMilliseconds) -lt 1000)
    } catch {
        return $false
    }
}

function Stop-OpenCodeWatchedProcess {
    param($Process)
    if (-not [string]::IsNullOrWhiteSpace($env:XPZ_TEST_OPENCODE_WATCH_KILL_LOG)) {
        Add-Content -LiteralPath $env:XPZ_TEST_OPENCODE_WATCH_KILL_LOG -Value 'Kill(true)' -Encoding utf8
    }
    if ($env:XPZ_TEST_OPENCODE_WATCH_KILL_THROW -eq '1') { throw 'test kill throw' }
    if ($env:XPZ_TEST_OPENCODE_WATCH_KILL_NOOP -eq '1') { return }
    $Process.Kill($true)
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
        [datetime] $FinishedAt = (Get-Date),
        [bool] $WatchTimedOut = $false,
        $LimitHit = $null,
        [string] $SinceTimeSource = '',
        [int] $WatchTimeoutSec = 0,
        [AllowNull()] [Nullable[bool]] $ProcessIdentityVerified = $null,
        [AllowNull()] [Nullable[bool]] $CancelIdentityUnverifiable = $null,
        [AllowNull()] [Nullable[bool]] $CancelAttempted = $null,
        [AllowNull()] [Nullable[bool]] $WatchedProcessStillAliveAtPromote = $null
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

    $limitKind = $null
    $limitMessage = ''
    if ($null -ne $LimitHit) {
        $limitKind = [string](Get-OcProp $LimitHit 'kind')
        $limitMessage = [string](Get-OcProp $LimitHit 'message')
        if ($limitKind -ne 'usage-limit' -and $limitKind -ne 'rate-limit') { $limitKind = $null }
    }
    if (-not $FallbackToBuild -and -not $accepted -and $limitKind) {
        if ($limitKind -eq 'usage-limit') {
            $status = 'limite-uso'
            $disposition = 'rejected-usage-limit'
            $rejectionReason = 'provider-usage-limit'
        } else {
            $status = 'limite-taxa'
            $disposition = 'rejected-rate-limit'
            $rejectionReason = 'provider-rate-limit'
        }
        if ($completionVerdict -eq 'ok') { $completionVerdict = 'error' }
        $errorText = Format-OpenCodeLimitBlock -Kind $limitKind -Message $limitMessage
        $accepted = $false
        $watcherExitCode = 20
    } elseif (-not $FallbackToBuild -and $WatchTimedOut) {
        $status = 'error'
        $disposition = 'rejected-error'
        $rejectionReason = 'opencode-watch-timeout'
        if ($completionVerdict -eq 'ok') { $completionVerdict = 'error' }
        $errorText = Format-OpenCodeWatchTimeoutBlock -WatchTimeoutSec $WatchTimeoutSec
        $accepted = $false
        $watcherExitCode = 20
    }

    $ht = [ordered]@{
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
    }
    if (-not [string]::IsNullOrWhiteSpace($SinceTimeSource)) { $ht['sinceTimeSource'] = $SinceTimeSource }
    if ($null -ne $ProcessIdentityVerified -or $null -ne $CancelIdentityUnverifiable -or $null -ne $CancelAttempted) {
        $ht['processIdentityVerified'] = [bool]$ProcessIdentityVerified
        $ht['cancelIdentityUnverifiable'] = [bool]$CancelIdentityUnverifiable
        $ht['cancelAttempted'] = [bool]$CancelAttempted
    }
    if ($null -ne $WatchedProcessStillAliveAtPromote) {
        $ht['watchedProcessStillAliveAtPromote'] = [bool]$WatchedProcessStillAliveAtPromote
    }
    return [pscustomobject]$ht
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

    $validStatus = @('completed','truncado','sem-conclusao','sem-texto','error','limite-uso','limite-taxa')
    $validVerdict = @('ok','truncated','no-completion','empty','error')
    $validDisposition = @('accepted','rejected-fallback','rejected-error','rejected-truncated','rejected-no-completion','rejected-empty','rejected-usage-limit','rejected-rate-limit')
    $validReason = @('opencode-agent-fallback-to-build','opencode-exit-nonzero','opencode-exit-unknown','opencode-error','truncated','no-completion','empty','provider-usage-limit','provider-rate-limit','opencode-watch-timeout')
    if ($validStatus -notcontains [string](Val $obj 'status')) { return (& $failResult 'invalid-status' 'Invalid status.') }
    if ($validVerdict -notcontains [string](Val $obj 'completionVerdict')) { return (& $failResult 'invalid-completionVerdict' 'Invalid completionVerdict.') }
    if ($validDisposition -notcontains [string](Val $obj 'finalTextDisposition')) { return (& $failResult 'invalid-finalTextDisposition' 'Invalid finalTextDisposition.') }
    if (HasProp $obj 'sinceTimeSource') {
        $sts = [string](Val $obj 'sinceTimeSource')
        if ($sts -ne 'request-startedAt' -and $sts -ne 'watcher-attach-fallback') {
            return (& $failResult 'invalid-sinceTimeSource' 'sinceTimeSource must be request-startedAt or watcher-attach-fallback.')
        }
    }
    $idNames = @('processIdentityVerified','cancelIdentityUnverifiable','cancelAttempted')
    $idPresent = @($idNames | Where-Object { HasProp $obj $_ }).Count
    if ($idPresent -gt 0 -and $idPresent -lt 3) {
        return (& $failResult 'rejected-identity-incoherent' 'Identity fields must appear together.')
    }
    if ($idPresent -eq 3) {
        foreach ($n in $idNames) {
            if ((Val $obj $n) -isnot [bool]) { return (& $failResult 'rejected-identity-incoherent' 'Identity fields must be boolean.') }
        }
        if ([bool](Val $obj 'processIdentityVerified') -and [bool](Val $obj 'cancelIdentityUnverifiable')) {
            return (& $failResult 'rejected-identity-incoherent' 'processIdentityVerified and cancelIdentityUnverifiable cannot both be true.')
        }
    }
    if (HasProp $obj 'watchedProcessStillAliveAtPromote') {
        if ((Val $obj 'watchedProcessStillAliveAtPromote') -isnot [bool]) {
            return (& $failResult 'invalid-watchedProcessStillAliveAtPromote' 'watchedProcessStillAliveAtPromote must be boolean.')
        }
    }
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
    $status = [string](Val $obj 'status')
    $completionVerdict = [string](Val $obj 'completionVerdict')
    $finalTextDisposition = [string](Val $obj 'finalTextDisposition')
    $hasStepFinish = [bool](Val $obj 'hasStepFinish')
    $finishReason = [string](Val $obj 'finishReason')
    switch ($rr) {
        'opencode-agent-fallback-to-build' {
            if (-not [bool](Val $obj 'fallbackToBuild') -or $null -eq (Val $obj 'fallbackDetail')) {
                return (& $failResult 'rejected-shape-incoherent' 'Fallback rejectionReason requires fallbackToBuild/fallbackDetail.')
            }
        }
        'opencode-exit-nonzero' {
            if ($finalTextDisposition -ne 'rejected-error') {
                return (& $failResult 'rejected-disposition-incoherent' 'opencode-exit-nonzero requires rejected-error disposition.')
            }
            if ($null -eq $opencodeExitCode -or $opencodeExitCode -eq 0) {
                return (& $failResult 'rejected-exit-code-incoherent' 'opencode-exit-nonzero requires non-zero opencodeExitCode.')
            }
        }
        'opencode-exit-unknown' {
            if ($finalTextDisposition -ne 'rejected-error') {
                return (& $failResult 'rejected-disposition-incoherent' 'opencode-exit-unknown requires rejected-error disposition.')
            }
            if ($null -ne $opencodeExitCode) {
                return (& $failResult 'rejected-exit-code-incoherent' 'opencode-exit-unknown requires null opencodeExitCode.')
            }
        }
        'opencode-error' {
            if ($finalTextDisposition -ne 'rejected-error') {
                return (& $failResult 'rejected-disposition-incoherent' 'opencode-error requires rejected-error disposition.')
            }
            if ($status -ne 'error') {
                return (& $failResult 'rejected-status-incoherent' 'opencode-error requires error status.')
            }
        }
        'truncated' {
            if ($finalTextDisposition -ne 'rejected-truncated') {
                return (& $failResult 'rejected-disposition-incoherent' 'truncated requires rejected-truncated disposition.')
            }
            if ($completionVerdict -ne 'truncated' -or $status -ne 'truncado' -or -not $hasStepFinish -or [string]::IsNullOrWhiteSpace($finishReason) -or $finishReason -eq 'stop') {
                return (& $failResult 'rejected-verdict-incoherent' 'truncated rejection has incoherent completion signal.')
            }
        }
        'no-completion' {
            if ($finalTextDisposition -ne 'rejected-no-completion') {
                return (& $failResult 'rejected-disposition-incoherent' 'no-completion requires rejected-no-completion disposition.')
            }
            if ($completionVerdict -ne 'no-completion' -or $status -ne 'sem-conclusao' -or -not [string]::IsNullOrEmpty($finishReason)) {
                return (& $failResult 'rejected-verdict-incoherent' 'no-completion rejection has incoherent completion signal.')
            }
        }
        'empty' {
            if ($finalTextDisposition -ne 'rejected-empty') {
                return (& $failResult 'rejected-disposition-incoherent' 'empty requires rejected-empty disposition.')
            }
            if ($completionVerdict -ne 'empty' -or $status -ne 'sem-texto' -or -not $hasStepFinish -or $finishReason -ne 'stop') {
                return (& $failResult 'rejected-verdict-incoherent' 'empty rejection has incoherent completion signal.')
            }
        }
        'provider-usage-limit' {
            if ($finalTextDisposition -ne 'rejected-usage-limit' -or $status -ne 'limite-uso') {
                return (& $failResult 'rejected-status-incoherent' 'provider-usage-limit requires limite-uso / rejected-usage-limit.')
            }
            if ($completionVerdict -eq 'ok') {
                return (& $failResult 'rejected-verdict-incoherent' 'provider-usage-limit cannot have completionVerdict ok.')
            }
            $fixedUsage = Format-OpenCodeLimitBlock -Kind 'usage-limit' -Message ''
            if ([string](Val $obj 'error') -notlike ($fixedUsage + '*')) {
                return (& $failResult 'rejected-shape-incoherent' 'provider-usage-limit error must use Format-OpenCodeLimitBlock usage text.')
            }
        }
        'provider-rate-limit' {
            if ($finalTextDisposition -ne 'rejected-rate-limit' -or $status -ne 'limite-taxa') {
                return (& $failResult 'rejected-status-incoherent' 'provider-rate-limit requires limite-taxa / rejected-rate-limit.')
            }
            if ($completionVerdict -eq 'ok') {
                return (& $failResult 'rejected-verdict-incoherent' 'provider-rate-limit cannot have completionVerdict ok.')
            }
            $fixedRate = Format-OpenCodeLimitBlock -Kind 'rate-limit' -Message ''
            if ([string](Val $obj 'error') -notlike ($fixedRate + '*')) {
                return (& $failResult 'rejected-shape-incoherent' 'provider-rate-limit error must use Format-OpenCodeLimitBlock rate text.')
            }
        }
        'opencode-watch-timeout' {
            if ($finalTextDisposition -ne 'rejected-error' -or $status -ne 'error') {
                return (& $failResult 'rejected-status-incoherent' 'opencode-watch-timeout requires status error.')
            }
            if ($completionVerdict -eq 'ok') {
                return (& $failResult 'rejected-verdict-incoherent' 'opencode-watch-timeout cannot have completionVerdict ok.')
            }
            $err = [string](Val $obj 'error')
            if ($err -notmatch '^BLOCK: Watch-OpenCodeJob atingiu WatchTimeoutSec=\d+; processo observado ainda vivo\. opencode-watch-timeout$') {
                return (& $failResult 'rejected-shape-incoherent' 'opencode-watch-timeout error must be the canonical timeout BLOCK.')
            }
        }
    }
    if ($watcherExitCode -ne 20) { return (& $failResult 'rejected-watcherExitCode-invalid' 'Rejected v2 result must have watcherExitCode 20.') }
    return [pscustomobject]@{ accepted = $false; reason = $rr; result = $obj; acceptedFinalText = ''; error = [string](Val $obj 'error') }
}
