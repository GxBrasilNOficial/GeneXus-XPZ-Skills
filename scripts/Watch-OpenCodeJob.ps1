#requires -Version 7.4
<#
.SYNOPSIS
    Monitor incremental de um job assincrono do opencode (disparado por Start-OpenCodeJob.ps1).
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Segue o processo informado (-ProcessId), le
    o <GUID>.stream.jsonl incrementalmente, traduz eventos neutros para acompanhamento humano e,
    no fim, grava <GUID>.result.json com contrato local schemaVersion=2.

    O contrato v2 separa resultado aceito de resultado rejeitado. Fallback de agente opencode para
    o agente default, truncamento, ausencia de conclusao, ausencia de texto, erro de stream, exit
    opencode diferente de zero ou exit opencode desconhecido viram rejeicao controlada (exit 20)
    quando o watcher consegue promover o contrato. O exit real do opencode vem de
    <GUID>.exitcode.txt; -ProcessId delimita a vida do processo observado (runner pwsh criado por
    Start-OpenCodeJob.ps1, ou processo equivalente em invocacoes manuais). Falha interna do
    proprio watcher antes da promocao atomica sai com codigo 99, emite WATCHER_INTERNAL_ERROR no
    stderr e nao promove <GUID>.result.json. -WatchTimeoutSec (default 0) e opt-in; se o processo
    observado ainda estiver vivo no prazo, o watcher tenta encerrar a arvore do runner e promove
    rejeicao opencode-watch-timeout (exit 20). Esperas do poll usam o restante em milissegundos e
    nao arredondam para cima alem do prazo. result.json preexistente recusa clobber (exit 21).
    Jobs com watcher classificam limite de uso/taxa do provider via o resolvedor compartilhado.
.PARAMETER JobId
    GUID do job (nome-base dos arquivos em -TempDir).
.PARAMETER ProcessId
    PID do processo observado cuja vida delimita o monitoramento. No fluxo padrao de
    Start-OpenCodeJob.ps1, e o PID do runner pwsh; o exit do opencode deve vir de
    <GUID>.exitcode.txt.
.PARAMETER TempDir
    Pasta dos arquivos de job. Default: <temp do usuário>\opencode-jobs.
.PARAMETER IntervalSeconds
    Intervalo de polling. Default 2. Faixa 1-30.
.PARAMETER SilenceThresholdSeconds
    Segundos sem nova linha antes de alertar. Default 120. Faixa 30-3600.
.PARAMETER WatchTimeoutSec
    Timeout opt-in do observador (0 = desligado, maximo 86400). Independente do alerta de silencio.
.PARAMETER ExpectedStartTimeUtc
    StartTime UTC do runner (ISO-Z), para kill por identidade (PID + StartTime).
.EXAMPLE
    .\Watch-OpenCodeJob.ps1 -JobId a1b2c3 -ProcessId 12345
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $JobId,
    [Parameter(Mandatory = $true)] [int]    $ProcessId,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'opencode-jobs'),
    [ValidateRange(1, 30)]   [int] $IntervalSeconds = 2,
    [ValidateRange(30, 3600)][int] $SilenceThresholdSeconds = 120,
    [ValidateRange(0, 86400)][int] $WatchTimeoutSec = 0,
    [string] $ExpectedStartTimeUtc
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'OpenCodeStreamSupport.ps1')
. (Join-Path $PSScriptRoot 'OpenCodeReviewerRoGuard.ps1')

$base       = Join-Path $TempDir $JobId
$streamPath = "$base.stream.jsonl"
$reqPath    = "$base.request.json"
$errPath    = "$base.stderr.txt"
$resultPath = "$base.result.json"
$exitCodePath = "$base.exitcode.txt"

$script:events = [System.Collections.Generic.List[object]]::new()

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Write-Line {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message) -ForegroundColor $Color
}

function Read-NewLines {
    param([ref]$Offset)
    $lines = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $streamPath -PathType Leaf)) { return $lines }

    $fs = $null
    $reader = $null
    try {
        $fs = [System.IO.FileStream]::new(
            $streamPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        [void]$fs.Seek($Offset.Value, [System.IO.SeekOrigin]::Begin)
        $reader = [System.IO.StreamReader]::new($fs, [System.Text.Encoding]::UTF8)
        $l = $reader.ReadLine()
        while ($null -ne $l) { $lines.Add($l); $l = $reader.ReadLine() }
        $Offset.Value = $fs.Position
    } catch {
        Write-Line "AVISO: falha ao ler stream: $($_.Exception.Message)" 'DarkYellow'
    } finally {
        if ($reader) { $reader.Dispose() }
        elseif ($fs) { $fs.Dispose() }
    }
    return $lines
}

function Show-Event {
    param($Json)
    $type = Get-Prop $Json 'type'
    $part = Get-Prop $Json 'part'
    switch ($type) {
        'tool_use' {
            $tool  = Get-Prop $part 'tool'
            $state = Get-Prop $part 'state'
            $inp   = Get-Prop $state 'input'
            $cmd   = Get-Prop $inp 'command'
            if (-not $cmd) { $cmd = Get-Prop $inp 'description' }
            $c = [string]$cmd
            if ($c.Length -gt 70) { $c = $c.Substring(0, 70) + '...' }
            Write-Line ("TOOL  {0}: {1}" -f $tool, $c) 'Yellow'
        }
        'text' {
            $t = Get-Prop $part 'text'
            if ($t) {
                Write-Line ("TEXTO recebido ({0} chars)" -f ([string]$t).Length) 'Green'
            }
        }
        'step_finish' {
            $cost = Get-Prop $part 'cost'
            $tok = Get-Prop $part 'tokens'
            $tot = Get-Prop $tok 'total'
            $reason = [string](Get-Prop $part 'reason')
            $costText = if ($null -ne $cost) { [double]$cost } else { 0 }
            $tokText = if ($null -ne $tot) { [int]$tot } else { 0 }
            Write-Line ("passo concluido | custo parcial USD {0:N5} | tokens {1} | reason {2}" -f $costText, $tokText, $reason) 'DarkCyan'
        }
        'error' {
            $emsg = Get-Prop (Get-Prop (Get-Prop $Json 'error') 'data') 'message'
            if ([string]::IsNullOrWhiteSpace($emsg)) { $emsg = 'erro no stream opencode' }
            Write-Line ("ERRO no agente: {0}" -f $emsg) 'Red'
        }
        default { }
    }
}

function Write-OpenCodeResultAtomic {
    param(
        [Parameter(Mandatory)] $Result,
        [Parameter(Mandatory)] [string] $Path
    )
    $json = $Result | ConvertTo-Json -Depth 8
    $tmp = "$Path.tmp"
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        if (Test-Path -LiteralPath $tmp -PathType Leaf) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        $ex = [System.InvalidOperationException]::new('OPENCODE_RESULT_CLOBBER')
        throw $ex
    }
    Set-Content -LiteralPath $tmp -Value $json -Encoding utf8
    try {
        Move-Item -LiteralPath $tmp -Destination $Path
    } catch {
        if (Test-Path -LiteralPath $tmp -PathType Leaf) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        $ex = [System.InvalidOperationException]::new('OPENCODE_RESULT_CLOBBER')
        throw $ex
    }
}

function Write-HumanResult {
    param(
        [Parameter(Mandatory)] $Result,
        [Parameter(Mandatory)] [string] $Path
    )
    try {
        Write-Host "-------------------------------------------------------------" -ForegroundColor White
        if ($Result.resultAccepted) {
            Write-Host "RESPOSTA FINAL:" -ForegroundColor Green
            Write-Host $Result.acceptedFinalText
        } elseif ($Result.fallbackToBuild) {
            Write-Host "RESULTADO NAO ACEITO: fallback opencode para agente default/build detectado; resposta invalidada." -ForegroundColor Red
        } else {
            Write-Host ("RESULTADO NAO ACEITO: status={0}; rejectionReason={1}" -f $Result.status, $Result.rejectionReason) -ForegroundColor Red
        }
        Write-Host ("Custo total USD {0:N5} | tokens {1}" -f $Result.totalCost, $Result.tokens) -ForegroundColor DarkCyan
        Write-Host ("result.json: {0}" -f $Path) -ForegroundColor DarkGray
    } catch {
        try { [Console]::Error.WriteLine("AVISO: falha ao apresentar resultado humano: $($_.Exception.Message)") } catch { }
    }
}

$exitCode = 99
try {
    Write-Host "=== Watch-OpenCodeJob =======================================" -ForegroundColor White
    if (Test-Path -LiteralPath $reqPath -PathType Leaf) {
        try {
            $req = Get-Content -LiteralPath $reqPath -Raw -Encoding utf8 | ConvertFrom-Json
            Write-Line ("Job   : {0}" -f (Get-Prop $req 'jobId'))  'White'
            Write-Line ("Modelo: {0}" -f (Get-Prop $req 'model'))  'White'
            $promptLen = ([string](Get-Prop $req 'prompt')).Length
            Write-Line ("Prompt recebido ({0} chars)" -f $promptLen) 'White'
        } catch { }
    }
    Write-Line ("PID   : {0}" -f $ProcessId) 'White'
    Write-Host "-------------------------------------------------------------" -ForegroundColor White

    if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        [Console]::Error.WriteLine('BLOCK: result.json ja existe; recusa clobber.')
        $exitCode = 21
        exit $exitCode
    }

    $sinceTimeSource = 'watcher-attach-fallback'
    $t0 = [datetime]::UtcNow
    if (Test-Path -LiteralPath $reqPath -PathType Leaf) {
        try {
            $reqObj = Get-Content -LiteralPath $reqPath -Raw -Encoding utf8 | ConvertFrom-Json
            $startedRaw = Get-Prop $reqObj 'startedAt'
            $parsedT0 = Convert-OpenCodeLineTimestampUtc $startedRaw
            if ($null -eq $parsedT0 -and $null -ne $startedRaw) {
                $dto = [datetimeoffset]::MinValue
                if ([datetimeoffset]::TryParse([string]$startedRaw, [ref]$dto)) { $parsedT0 = $dto.UtcDateTime }
            }
            if ($null -ne $parsedT0) {
                $t0 = $parsedT0
                $sinceTimeSource = 'request-startedAt'
            }
        } catch { }
    }

    $expectedStart = $null
    if (-not [string]::IsNullOrWhiteSpace($ExpectedStartTimeUtc)) {
        $dtoExp = [datetimeoffset]::MinValue
        if ([datetimeoffset]::TryParse($ExpectedStartTimeUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$dtoExp)) {
            $expectedStart = $dtoExp.UtcDateTime
        }
    }

    $deadlineUtc = $null
    if ($WatchTimeoutSec -gt 0) { $deadlineUtc = [datetime]::UtcNow.AddSeconds($WatchTimeoutSec) }
    $watchTimedOut = $false
    $lastActivity = [datetime]::UtcNow
    $offset = [long]0
    $silenceAlerted = $false

    function Get-WatchSleepMsLocal {
        param([double]$DefaultSec, $Deadline)
        $defaultMs = $DefaultSec * 1000.0
        if ($null -eq $Deadline) { return [Math]::Max(1, [int][Math]::Ceiling($defaultMs)) }
        $remMs = ($Deadline - [datetime]::UtcNow).TotalMilliseconds
        if ($remMs -le 0) { return 0 }
        $m = [Math]::Min($defaultMs, $remMs)
        return [int][Math]::Floor($m)
    }
    function Test-WatchAliveLocal {
        $procNow = Get-OpenCodeWatchedProcess -ProcessId $ProcessId
        if ($null -eq $procNow) { return $false }
        return (-not $procNow.HasExited)
    }
    function Add-WatchStreamLinesLocal {
        param($Lines)
        foreach ($line in @($Lines)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $j = $line | ConvertFrom-Json
                $script:events.Add($j)
                Show-Event $j
            } catch { continue }
        }
    }

    while (-not (Test-Path -LiteralPath $streamPath -PathType Leaf)) {
        if (-not (Test-WatchAliveLocal)) { break }
        if ($null -ne $deadlineUtc -and [datetime]::UtcNow -ge $deadlineUtc) {
            if (Test-WatchAliveLocal) { $watchTimedOut = $true }
            break
        }
        Write-Line "Aguardando stream do opencode..." 'DarkGray'
        $sl = Get-WatchSleepMsLocal -DefaultSec 2 -Deadline $deadlineUtc
        if ($sl -le 0) {
            if (Test-WatchAliveLocal) { $watchTimedOut = $true }
            break
        }
        Start-Sleep -Milliseconds $sl
    }

    :loop while (-not $watchTimedOut) {
        $alive = Test-WatchAliveLocal
        if ($null -ne $deadlineUtc -and [datetime]::UtcNow -ge $deadlineUtc -and $alive) {
            $watchTimedOut = $true
            break loop
        }
        $new = @(Read-NewLines ([ref]$offset))

        if ($new.Count -gt 0) {
            $lastActivity = [datetime]::UtcNow
            $silenceAlerted = $false
            Add-WatchStreamLinesLocal $new
        } else {
            $silenceSec = [int]([datetime]::UtcNow - $lastActivity).TotalSeconds
            if ($silenceSec -ge $SilenceThresholdSeconds -and -not $silenceAlerted) {
                $silenceAlerted = $true
                $procLabel = if ($alive) { "PID $ProcessId ativo" } else { "PID $ProcessId encerrado" }
                Write-Line ("SILENCIO ha ${SilenceThresholdSeconds}s - $procLabel") 'DarkYellow'
            }
        }

        if (-not $alive) {
            $slTail = Get-WatchSleepMsLocal -DefaultSec 2 -Deadline $deadlineUtc
            if ($slTail -gt 0) { Start-Sleep -Milliseconds $slTail }
            Add-WatchStreamLinesLocal (Read-NewLines ([ref]$offset))
            break loop
        }

        $sl = Get-WatchSleepMsLocal -DefaultSec $IntervalSeconds -Deadline $deadlineUtc
        if ($sl -le 0) {
            if (Test-WatchAliveLocal) { $watchTimedOut = $true }
            break loop
        }
        Start-Sleep -Milliseconds $sl
    }

    if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        [Console]::Error.WriteLine('BLOCK: result.json ja existe; recusa clobber.')
        $exitCode = 21
        exit $exitCode
    }

    $processIdentityVerified = $null
    $cancelIdentityUnverifiable = $null
    $cancelAttempted = $null
    $stillAliveAtPromote = $null
    $aliveNow = Test-WatchAliveLocal
    if ($watchTimedOut -and $aliveNow) {
        $forceUnverifiable = ($env:XPZ_TEST_OPENCODE_WATCH_FORCE_IDENTITY_UNVERIFIABLE -eq '1')
        $proc = Get-OpenCodeWatchedProcess -ProcessId $ProcessId
        $identOk = (-not $forceUnverifiable) -and (Test-OpenCodeWatchedProcessIdentity -Process $proc -ExpectedStartTimeUtc $expectedStart)
        if ($forceUnverifiable -or -not $identOk) {
            [Console]::Error.WriteLine('AVISO: StartTime do runner indisponivel; kill por identidade ficara nao verificavel.')
        }
        if ($identOk) {
            $processIdentityVerified = $true
            $cancelIdentityUnverifiable = $false
            $cancelAttempted = $true
            try { Stop-OpenCodeWatchedProcess -Process $proc } catch { }
            $flushUntil = [datetime]::UtcNow.AddSeconds(2)
            while ([datetime]::UtcNow -lt $flushUntil) {
                $proc = Get-OpenCodeWatchedProcess -ProcessId $ProcessId
                if ($null -eq $proc -or $proc.HasExited) { break }
                Start-Sleep -Milliseconds 100
            }
        } else {
            $processIdentityVerified = $false
            $cancelIdentityUnverifiable = $true
            $cancelAttempted = $false
        }
        $aliveNow = Test-WatchAliveLocal
        $stillAliveAtPromote = $aliveNow
        if ($stillAliveAtPromote) {
            [Console]::Error.WriteLine('AVISO: result.json promovido com processo observado ainda vivo; escritas tardias nao reclobberam o result.')
        }
        Add-WatchStreamLinesLocal (Read-NewLines ([ref]$offset))
    } else {
        $watchTimedOut = $false
        Add-WatchStreamLinesLocal (Read-NewLines ([ref]$offset))
    }

    $opencodeExitObserved = $false
    $opencodeExitCode = $null
    if (Test-Path -LiteralPath $exitCodePath -PathType Leaf) {
        $rawExitCode = (Get-Content -LiteralPath $exitCodePath -Raw -Encoding utf8 -ErrorAction SilentlyContinue).Trim()
        $parsedExit = 0
        if ([int]::TryParse($rawExitCode, [ref]$parsedExit)) {
            $opencodeExitCode = $parsedExit
            $opencodeExitObserved = $true
        }
    }
    $errText = ''
    if (Test-Path -LiteralPath $errPath -PathType Leaf) {
        $errText = Get-Content -LiteralPath $errPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    }
    $rawStream = @()
    if (Test-Path -LiteralPath $streamPath -PathType Leaf) {
        $rawStream = @(Get-Content -LiteralPath $streamPath -Encoding utf8 -ErrorAction SilentlyContinue)
    }
    $streamErrors = @(Get-OpenCodeStreamErrorCandidates -Lines $rawStream)
    $limitHit = Resolve-OpenCodeProviderLimitHit -StreamErrors $streamErrors -StderrText $errText -SinceTime $t0
    $requestedAgent = Get-OpenCodeRequestedAgent -RequestPath $reqPath
    $fallbackToBuild = Test-OpenCodeReviewerRoFallbackWarning -Text $errText
    $fallbackPattern = Get-OpenCodeReviewerRoFallbackWarningPattern
    $signal = Get-OpenCodeCompletionSignal -Events @($script:events)
    $wrSplat = @{
        JobId = $JobId
        CompletionSignal = $signal
        StderrText = $errText
        FallbackToBuild = $fallbackToBuild
        FallbackStderrPattern = $fallbackPattern
        RequestedAgent = $requestedAgent
        OpencodeExitCode = $opencodeExitCode
        OpencodeExitObserved = $opencodeExitObserved
        FinishedAt = (Get-Date).ToUniversalTime()
        WatchTimedOut = $watchTimedOut
        LimitHit = $limitHit
        SinceTimeSource = $sinceTimeSource
        WatchTimeoutSec = $WatchTimeoutSec
    }
    if ($null -ne $processIdentityVerified) {
        $wrSplat['ProcessIdentityVerified'] = $processIdentityVerified
        $wrSplat['CancelIdentityUnverifiable'] = $cancelIdentityUnverifiable
        $wrSplat['CancelAttempted'] = $cancelAttempted
    }
    if ($null -ne $stillAliveAtPromote) { $wrSplat['WatchedProcessStillAliveAtPromote'] = $stillAliveAtPromote }
    $result = Get-OpenCodeWatchResult @wrSplat

    Write-OpenCodeResultAtomic -Result $result -Path $resultPath
    $exitCode = [int]$result.watcherExitCode
    Write-HumanResult -Result $result -Path $resultPath
} catch {
    if ($_.Exception.Message -eq 'OPENCODE_RESULT_CLOBBER') {
        [Console]::Error.WriteLine('BLOCK: result.json ja existe; recusa clobber.')
        if (Test-Path -LiteralPath "$resultPath.tmp" -PathType Leaf) {
            Remove-Item -LiteralPath "$resultPath.tmp" -Force -ErrorAction SilentlyContinue
        }
        $exitCode = 21
    } else {
        try { [Console]::Error.WriteLine("WATCHER_INTERNAL_ERROR: $($_.Exception.Message)") } catch { }
        $exitCode = 99
    }
}

exit $exitCode
