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
    stderr e nao promove <GUID>.result.json.
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
.EXAMPLE
    .\Watch-OpenCodeJob.ps1 -JobId a1b2c3 -ProcessId 12345
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $JobId,
    [Parameter(Mandatory = $true)] [int]    $ProcessId,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'opencode-jobs'),
    [ValidateRange(1, 30)]   [int] $IntervalSeconds = 2,
    [ValidateRange(30, 3600)][int] $SilenceThresholdSeconds = 120
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
    Set-Content -LiteralPath $tmp -Value $json -Encoding utf8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
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

    $observedProcess = $null
    try { $observedProcess = [System.Diagnostics.Process]::GetProcessById($ProcessId) } catch { $observedProcess = $null }
    $opencodeExitObserved = $false
    $opencodeExitCode = $null

    $waited = 0
    while (-not (Test-Path -LiteralPath $streamPath -PathType Leaf) -and $waited -lt 30) {
        Write-Line "Aguardando stream do opencode..." 'DarkGray'
        Start-Sleep -Seconds 2
        $waited += 2
    }

    $offset = [long]0
    $lastActivity = [DateTime]::Now
    $silenceAlerted = $false

    :loop while ($true) {
        $alive = if ($observedProcess) { -not $observedProcess.HasExited } else { $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) }
        $new = @(Read-NewLines ([ref]$offset))

        if ($new.Count -gt 0) {
            $lastActivity = [DateTime]::Now
            $silenceAlerted = $false
            foreach ($line in $new) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try {
                    $j = $line | ConvertFrom-Json
                    $script:events.Add($j)
                    Show-Event $j
                } catch { continue }
            }
        } else {
            $silenceSec = [int]([DateTime]::Now - $lastActivity).TotalSeconds
            if ($silenceSec -ge $SilenceThresholdSeconds -and -not $silenceAlerted) {
                $silenceAlerted = $true
                $procLabel = if ($alive) { "PID $ProcessId ativo" } else { "PID $ProcessId encerrado" }
                Write-Line ("SILENCIO ha ${SilenceThresholdSeconds}s - $procLabel") 'DarkYellow'
            }
        }

        if (-not $alive) {
            Start-Sleep -Seconds 2
            $tail = @(Read-NewLines ([ref]$offset))
            foreach ($line in $tail) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                try {
                    $j = $line | ConvertFrom-Json
                    $script:events.Add($j)
                    Show-Event $j
                } catch { continue }
            }
            break loop
        }

        Start-Sleep -Seconds $IntervalSeconds
    }

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
    $requestedAgent = Get-OpenCodeRequestedAgent -RequestPath $reqPath
    $fallbackToBuild = Test-OpenCodeReviewerRoFallbackWarning -Text $errText
    $fallbackPattern = Get-OpenCodeReviewerRoFallbackWarningPattern
    $signal = Get-OpenCodeCompletionSignal -Events @($script:events)
    $result = Get-OpenCodeWatchResult -JobId $JobId -CompletionSignal $signal -StderrText $errText `
        -FallbackToBuild:$fallbackToBuild -FallbackStderrPattern $fallbackPattern -RequestedAgent $requestedAgent `
        -OpencodeExitCode $opencodeExitCode -OpencodeExitObserved:$opencodeExitObserved -FinishedAt (Get-Date)

    Write-OpenCodeResultAtomic -Result $result -Path $resultPath
    $exitCode = [int]$result.watcherExitCode
    Write-HumanResult -Result $result -Path $resultPath
} catch {
    try { [Console]::Error.WriteLine("WATCHER_INTERNAL_ERROR: $($_.Exception.Message)") } catch { }
    $exitCode = 99
}

exit $exitCode
