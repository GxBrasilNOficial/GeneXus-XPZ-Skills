#requires -Version 7.4
<#
.SYNOPSIS
    Monitor incremental de um job assincrono do Codex (disparado por Start-CodexJob.ps1).
.DESCRIPTION
    Backend codex da skill xpz-llm-delegate. Segue o processo informado (-ProcessId) e le o
    <GUID>.stream.jsonl incrementalmente, traduzindo os eventos do `codex exec --json` em
    linhas legiveis. Encerra quando o processo termina, gravando <GUID>.result.json com a
    resposta final (lida do output-last-message <GUID>.lastmsg.txt) e o uso de tokens —
    somente no caminho de observacao concluida com grupo presente.

    Codigos de saida da observacao: 0 (promoveu, sem-texto, ou pasta sem grupo com alvo morto),
    21 (clobber de result.json), 22 (identidade recusada), 99 (erro interno). 22 e 99 NAO
    gravam result.json. JobId invalido e validacao de parametro ANTES de TempDir (exit 1
    tipico do pwsh; fora de {0,21,22,99}).

    Sem finally que grave result.json (molde OpenCode). Exit 22 e simetrico ao 21
    ($exitCode=22; exit 22 antes da promocao).

    Espelha o padrao de Watch-OpenCodeJob.ps1, alargado ao codigo 22.
.PARAMETER JobId
    GUID N do job (32 hex). Validado antes de resolver/criar TempDir.
.PARAMETER ProcessId
    PID do processo codex cuja vida delimita o monitoramento. Mandatory.
.PARAMETER TempDir
    Pasta dos arquivos de job. Sem default no param(); cascata via Resolve-CodexJobTempDir
    (Bound nao-branco -> env XPZ_CODEX_JOBS_DIR -> %TEMP%\codex-jobs), sempre absoluto.
.PARAMETER ExpectedStartTimeUtc
    Hora de StartTime do processo (UTC yyyy-MM-ddTHH:mm:ss.fffZ). Obrigatoria se o alvo
    esta vivo. Opcional no dummy (pid argv morto). Nunca usar startedAt T0.
.PARAMETER IntervalSeconds
    Intervalo de polling. Default 2. Faixa 1-30.
.PARAMETER SilenceThresholdSeconds
    Segundos sem nova linha antes de alertar. Default 120. Faixa 30-3600.
.EXAMPLE
    .\Watch-CodexJob.ps1 -JobId a1b2c3d4e5f6478890abcdef12345678 -ProcessId 12345 -ExpectedStartTimeUtc 2026-08-30T12:00:00.000Z
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $JobId,
    [Parameter(Mandatory = $true)] [int]    $ProcessId,
    [string] $TempDir,
    [string] $ExpectedStartTimeUtc,
    [ValidateRange(1, 30)]   [int] $IntervalSeconds = 2,
    [ValidateRange(30, 3600)][int] $SilenceThresholdSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# JobId ANTES de resolver/criar TempDir
if ($JobId -notmatch '^[0-9a-fA-F]{32}$') {
    throw 'BLOCK: JobId nao e GUID N.'
}

. (Join-Path $PSScriptRoot 'CodexCliSupport.ps1')

$tempOverride = $null
if ($PSBoundParameters.ContainsKey('TempDir') -and -not [string]::IsNullOrWhiteSpace($TempDir)) {
    $tempOverride = $TempDir.Trim()
}
$TempDir = Resolve-CodexJobTempDir -Override $tempOverride

$base        = Join-Path $TempDir $JobId
$streamPath  = "$base.stream.jsonl"
$reqPath     = "$base.request.json"
$errPath     = "$base.stderr.txt"
$lastMsgPath = "$base.lastmsg.txt"
$resultPath  = "$base.result.json"

$script:lastError    = $null
$script:inputTokens  = 0
$script:outputTokens = 0

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
        $reader.Dispose(); $fs.Dispose()
    } catch {
        Write-Line "AVISO: falha ao ler stream: $($_.Exception.Message)" 'DarkYellow'
    }
    return $lines
}

function Show-Event {
    param($Json)
    $type = [string](Get-Prop $Json 'type')
    switch ($type) {
        'item.started' {
            $item = Get-Prop $Json 'item'
            if ([string](Get-Prop $item 'type') -eq 'command_execution') {
                $c = [string](Get-Prop $item 'command')
                if ($c.Length -gt 70) { $c = $c.Substring(0, 70) + '...' }
                Write-Line ("CMD   inicia: {0}" -f $c) 'Yellow'
            }
        }
        'item.completed' {
            $item = Get-Prop $Json 'item'
            $itype = [string](Get-Prop $item 'type')
            if ($itype -eq 'command_execution') {
                $code = Get-Prop $item 'exit_code'
                Write-Line ("CMD   fim (exit {0})" -f $code) 'DarkYellow'
            } elseif ($itype -eq 'agent_message') {
                $t = [string](Get-Prop $item 'text')
                $preview = $t
                if ($preview.Length -gt 100) { $preview = $preview.Substring(0, 100) + '...' }
                Write-Line ("TEXTO: {0}" -f $preview) 'Green'
            }
        }
        'turn.completed' {
            $usage = Get-Prop $Json 'usage'
            $inp = Get-Prop $usage 'input_tokens'
            $outp = Get-Prop $usage 'output_tokens'
            if ($null -ne $inp)  { $script:inputTokens  = [int]$inp }
            if ($null -ne $outp) { $script:outputTokens = [int]$outp }
            Write-Line ("turno concluido | tokens in {0} / out {1}" -f $script:inputTokens, $script:outputTokens) 'DarkCyan'
        }
        'error' {
            $emsg = Get-Prop $Json 'message'
            if ([string]::IsNullOrWhiteSpace($emsg)) { $emsg = ($Json | ConvertTo-Json -Compress) }
            $script:lastError = [string]$emsg
            Write-Line ("ERRO no agente: {0}" -f $emsg) 'Red'
        }
        default { }
    }
}

function Test-CodexWatchAlive {
    $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $p) { return $false }
    return (-not $p.HasExited)
}

function Test-CodexJobGroupPresent {
    $suffixes = @(
        'request.json', 'lastmsg.txt', 'stream.jsonl', 'stderr.txt',
        'identity.json', 'stdin.txt', 'result.json',
        'invoke-in.txt', 'invoke-out.txt', 'invoke-err.txt'
    )
    foreach ($s in $suffixes) {
        if (Test-Path -LiteralPath "$base.$s" -PathType Leaf) { return $true }
    }
    return $false
}

function Promote-CodexWatchResult {
    $final = ''
    if (Test-Path -LiteralPath $lastMsgPath -PathType Leaf) {
        $final = (Get-Content -LiteralPath $lastMsgPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue)
    }
    if ($null -ne $final) { $final = $final.TrimEnd("`r", "`n") }

    $errText = ''
    if (Test-Path -LiteralPath $errPath -PathType Leaf) {
        $errText = (Get-Content -LiteralPath $errPath -Raw -ErrorAction SilentlyContinue)
    }

    $statusInfo = Resolve-CodexJobStatus -FinalText $final -StreamError $script:lastError -Stderr $errText
    $status = $statusInfo.status
    $script:lastError = $statusInfo.error

    $finishedAt = Format-CodexUtcTimestamp -Value (Get-Date).ToUniversalTime()
    $result = [ordered]@{
        jobId        = $JobId
        status       = $status
        finalText    = $final
        error        = $script:lastError
        inputTokens  = $script:inputTokens
        outputTokens = $script:outputTokens
        stderr       = $errText
        finishedAt   = $finishedAt
    }
    Write-CodexJsonAtomic -Object $result -Path $resultPath

    Write-Host "-------------------------------------------------------------" -ForegroundColor White
    Write-Host "RESPOSTA FINAL:" -ForegroundColor Green
    Write-Host $final
    Write-Host ("tokens in {0} / out {1}" -f $script:inputTokens, $script:outputTokens) -ForegroundColor DarkCyan
    Write-Host ("result.json: {0}" -f $resultPath) -ForegroundColor DarkGray
}

$exitCode = 99
try {
    Write-Host "=== Watch-CodexJob ==========================================" -ForegroundColor White
    if (Test-Path -LiteralPath $reqPath -PathType Leaf) {
        try {
            $req = Get-Content -LiteralPath $reqPath -Raw | ConvertFrom-Json
            Write-Line ("Job   : {0}" -f (Get-Prop $req 'jobId'))  'White'
            Write-Line ("Modelo: {0}" -f (Get-Prop $req 'model'))  'White'
            $pr = [string](Get-Prop $req 'prompt')
            if ($pr.Length -gt 80) { $pr = $pr.Substring(0, 80) + '...' }
            Write-Line ("Prompt: {0}" -f $pr) 'White'
        } catch { }
    }
    Write-Line ("PID   : {0}" -f $ProcessId) 'White'
    Write-Host "-------------------------------------------------------------" -ForegroundColor White

    if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        [Console]::Error.WriteLine('BLOCK: result.json ja existe; recusa clobber.')
        $exitCode = 21
        exit $exitCode
    }

    $argvExpectedUtc = $null
    $argvHourUsable = $false
    if (-not [string]::IsNullOrWhiteSpace($ExpectedStartTimeUtc)) {
        $argvExpectedUtc = ConvertTo-CodexUtcDateTime -Raw $ExpectedStartTimeUtc
        if ($null -ne $argvExpectedUtc) { $argvHourUsable = $true }
    }

    $alive = Test-CodexWatchAlive
    $identityMatched = $false

    if ($alive) {
        if (-not $argvHourUsable) {
            [Console]::Error.WriteLine('BLOCK: identidade do processo recusada.')
            $exitCode = 22
            exit $exitCode
        }

        $proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        if ($null -eq $proc -or $proc.HasExited) {
            $alive = $false
        } else {
            if (-not (Test-CodexProcessStartTimeMatch -Process $proc -ExpectedStartTimeUtc $argvExpectedUtc)) {
                [Console]::Error.WriteLine('BLOCK: identidade do processo recusada.')
                $exitCode = 22
                exit $exitCode
            }
            $resolved = Resolve-CodexPidAndStartTime -TempDir $TempDir -JobId $JobId
            if ($resolved.divergence) {
                [Console]::Error.WriteLine('BLOCK: identidade do processo recusada.')
                $exitCode = 22
                exit $exitCode
            }
            if ($null -ne $resolved.pid -and [int]$resolved.pid -ne $ProcessId) {
                [Console]::Error.WriteLine('BLOCK: identidade do processo recusada.')
                $exitCode = 22
                exit $exitCode
            }
            $identityMatched = $true

            $waited = 0
            while (-not (Test-Path -LiteralPath $streamPath -PathType Leaf) -and $waited -lt 30) {
                if (-not (Test-CodexWatchAlive)) { break }
                Write-Line "Aguardando stream do codex..." 'DarkGray'
                Start-Sleep -Seconds 2; $waited += 2
            }

            $offset         = [long]0
            $lastActivity   = [DateTime]::Now
            $silenceAlerted = $false

            :loop while ($true) {
                $stillAlive = Test-CodexWatchAlive
                $new   = @(Read-NewLines ([ref]$offset))

                if ($new.Count -gt 0) {
                    $lastActivity   = [DateTime]::Now
                    $silenceAlerted = $false
                    foreach ($line in $new) {
                        if ([string]::IsNullOrWhiteSpace($line)) { continue }
                        try { $j = $line | ConvertFrom-Json } catch { continue }
                        Show-Event $j
                    }
                } else {
                    $silenceSec = [int]([DateTime]::Now - $lastActivity).TotalSeconds
                    if ($silenceSec -ge $SilenceThresholdSeconds -and -not $silenceAlerted) {
                        $silenceAlerted = $true
                        $procLabel = if ($stillAlive) { "PID $ProcessId ativo" } else { "PID $ProcessId encerrado" }
                        Write-Line ("SILENCIO ha ${SilenceThresholdSeconds}s - $procLabel") 'DarkYellow'
                    }
                }

                if (-not $stillAlive) {
                    Start-Sleep -Seconds 2
                    $tail = @(Read-NewLines ([ref]$offset))
                    foreach ($line in $tail) {
                        if ([string]::IsNullOrWhiteSpace($line)) { continue }
                        try { $j = $line | ConvertFrom-Json } catch { continue }
                        Show-Event $j
                    }
                    break loop
                }

                Start-Sleep -Seconds $IntervalSeconds
            }
            $alive = $false
        }
    }

    if (-not (Test-CodexWatchAlive)) {
        if (-not (Test-CodexJobGroupPresent)) {
            [Console]::Error.WriteLine('AVISO: grupo Codex ausente no TempDir resolvido.')
            $exitCode = 0
            exit $exitCode
        }

        $hasArgvHour = $argvHourUsable -or $identityMatched
        if (-not $hasArgvHour) {
            $resolved = Resolve-CodexPidAndStartTime -TempDir $TempDir -JobId $JobId
            if ($null -eq $resolved.pid) {
                $exitCode = 0
                exit $exitCode
            }
            if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
                [Console]::Error.WriteLine('BLOCK: result.json ja existe; recusa clobber.')
                $exitCode = 21
                exit $exitCode
            }
            Promote-CodexWatchResult
            $exitCode = 0
            exit $exitCode
        }

        if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
            [Console]::Error.WriteLine('BLOCK: result.json ja existe; recusa clobber.')
            $exitCode = 21
            exit $exitCode
        }
        Promote-CodexWatchResult
        $exitCode = 0
        exit $exitCode
    }

    [Console]::Error.WriteLine('BLOCK: identidade do processo recusada.')
    $exitCode = 22
    exit $exitCode
} catch {
    $msg = [string]$_.Exception.Message
    if ($msg -eq 'CODEX_RESULT_CLOBBER') {
        [Console]::Error.WriteLine('BLOCK: result.json ja existe; recusa clobber.')
        if (Test-Path -LiteralPath "$resultPath.tmp" -PathType Leaf) {
            Remove-Item -LiteralPath "$resultPath.tmp" -Force -ErrorAction SilentlyContinue
        }
        $exitCode = 21
    } elseif ($msg -match 'identidade do processo recusada') {
        [Console]::Error.WriteLine('BLOCK: identidade do processo recusada.')
        $exitCode = 22
    } else {
        try { [Console]::Error.WriteLine("WATCHER_INTERNAL_ERROR: $msg") } catch { }
        $exitCode = 99
    }
}

exit $exitCode
