#requires -Version 7.4
<#
.SYNOPSIS
    Monitor incremental de um job assincrono do opencode (disparado por Start-OpenCodeJob.ps1).
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Segue o processo informado (-ProcessId) e le
    o <GUID>.stream.jsonl incrementalmente, traduzindo os eventos JSON do opencode em linhas
    legiveis: chamadas de ferramenta, custo/tokens parciais e texto recebido. Detecta silencio
    prolongado e encerra quando o processo termina, gravando <GUID>.result.json com a resposta
    final e o custo total.

    Espelha o padrão de Watch-GeneXusMsBuildLog.ps1 do repo GeneXus-XPZ-Skills.
.PARAMETER JobId
    GUID do job (nome-base dos arquivos em -TempDir).
.PARAMETER ProcessId
    PID do processo opencode cuja vida delimita o monitoramento.
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

# Funções compartilhadas de parsing do stream do opencode (dot-source)
. (Join-Path $PSScriptRoot 'OpenCodeStreamSupport.ps1')
# Guard do reviewer-ro (pos-check assincrono = DIAGNOSTICO, nao bloqueia — a barreira e o
# pre-check no spawn de Start-OpenCodeJob.ps1)
. (Join-Path $PSScriptRoot 'OpenCodeReviewerRoGuard.ps1')

$base       = Join-Path $TempDir $JobId
$streamPath = "$base.stream.jsonl"
$reqPath    = "$base.request.json"
$errPath    = "$base.stderr.txt"
$resultPath = "$base.result.json"

# Acumuladores de resultado
$script:textParts        = [System.Collections.Generic.List[object]]::new()
$script:lastError        = $null
$script:totalCost        = [double]0
$script:lastTokens       = 0
$script:sawStepFinish    = $false
$script:lastFinishReason = ''

# ── Helpers ───────────────────────────────────────────────────────────────────

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
                $mid = [string](Get-Prop $part 'messageID')
                $script:textParts.Add([pscustomobject]@{ mid = $mid; text = [string]$t })
                $preview = [string]$t
                if ($preview.Length -gt 100) { $preview = $preview.Substring(0, 100) + '...' }
                Write-Line ("TEXTO: {0}" -f $preview) 'Green'
            }
        }
        'step_finish' {
            $cost = Get-Prop $part 'cost'
            if ($null -ne $cost) { $script:totalCost += [double]$cost }
            $tok = Get-Prop $part 'tokens'
            $tot = Get-Prop $tok 'total'
            if ($null -ne $tot) { $script:lastTokens = [int]$tot }
            # Achado D: capturar o sinal de conclusao do ULTIMO step_finish. Sempre sobrescrever
            # (inclusive com vazio): se o ultimo step_finish vier SEM reason, o estado correto e ''
            # (no-completion), nunca herdar o reason de um step_finish anterior. [string]$null = ''
            # (sem excecao sob StrictMode). Espelha "ultimo step_finish governa" de Get-OpenCodeCompletionSignal.
            $script:sawStepFinish = $true
            $script:lastFinishReason = [string](Get-Prop $part 'reason')
            Write-Line ("passo concluido | custo parcial USD {0:N5} | tokens {1} | reason {2}" -f $script:totalCost, $script:lastTokens, $script:lastFinishReason) 'DarkCyan'
        }
        'error' {
            $emsg = Get-Prop (Get-Prop (Get-Prop $Json 'error') 'data') 'message'
            if ([string]::IsNullOrWhiteSpace($emsg)) { $emsg = ($Json | ConvertTo-Json -Compress) }
            $script:lastError = [string]$emsg
            Write-Line ("ERRO no agente: {0}" -f $emsg) 'Red'
        }
        default { }
    }
}

# ── Header ────────────────────────────────────────────────────────────────────

Write-Host "=== Watch-OpenCodeJob =======================================" -ForegroundColor White
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

# ── Aguardar stream aparecer (ate 30s) ────────────────────────────────────────

$waited = 0
while (-not (Test-Path -LiteralPath $streamPath -PathType Leaf) -and $waited -lt 30) {
    Write-Line "Aguardando stream do opencode..." 'DarkGray'
    Start-Sleep -Seconds 2; $waited += 2
}

# ── Loop principal ────────────────────────────────────────────────────────────

$offset         = [long]0
$lastActivity   = [DateTime]::Now
$silenceAlerted = $false

try {
    :loop while ($true) {
        $alive = $null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)
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
                $procLabel = if ($alive) { "PID $ProcessId ativo" } else { "PID $ProcessId encerrado" }
                Write-Line ("SILENCIO ha ${SilenceThresholdSeconds}s - $procLabel") 'DarkYellow'
            }
        }

        if (-not $alive) {
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
} finally {
    # Resposta final = concatenacao das partes da última mensagem (via OpenCodeStreamSupport)
    $final = Get-OpenCodeFinalText -TextParts $script:textParts

    $errText = ''
    if (Test-Path -LiteralPath $errPath -PathType Leaf) {
        $errText = (Get-Content -LiteralPath $errPath -Raw -ErrorAction SilentlyContinue)
    }
    # Pos-check DIAGNOSTICO (nao bloqueia): warning de fallback silencioso ao 'build' no stderr
    # persistido. A barreira e o pre-check no spawn (Start-OpenCodeJob.ps1); aqui so sinaliza para
    # o operador que o --agent nao resolveu no runtime (a saida pode ter sido gerada pelo 'build').
    $fallbackToBuild = Test-OpenCodeReviewerRoFallbackWarning -Text $errText
    $fallbackDetail = if ($fallbackToBuild) { "warning de fallback ao 'build' no stderr — o --agent nao resolveu no runtime; a resposta pode ter sido gerada pelo agente 'build' full-access. Verifique o provisionamento do reviewer-ro (diagnostico; nao bloqueia)." } else { $null }
    # Achado D: classificar a conclusao por reason (precedencia compartilhada com o sincrono via
    # OpenCodeStreamSupport). lastError tem prioridade; depois truncado/sem-conclusao/sem-texto.
    $verdict = Get-OpenCodeCompletionVerdict -HasStepFinish $script:sawStepFinish -Reason $script:lastFinishReason -FinalText $final
    $status = if ($script:lastError) { 'error' }
    elseif ($verdict.status -eq 'truncated') { 'truncado' }
    elseif ($verdict.status -eq 'no-completion') { 'sem-conclusao' }
    elseif ($verdict.status -eq 'empty') { 'sem-texto' }
    else { 'completed' }

    $result = [ordered]@{
        jobId        = $JobId
        status       = $status
        finalText    = $final
        error        = $script:lastError
        totalCost    = $script:totalCost
        tokens       = $script:lastTokens
        finishReason = $script:lastFinishReason
        stderr       = $errText
        fallbackToBuild = $fallbackToBuild
        fallbackDetail = $fallbackDetail
        finishedAt   = (Get-Date).ToString('o')
    }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding utf8

    if ($fallbackToBuild) {
        Write-Host "DIAGNOSTICO: warning de fallback ao 'build' no stderr — o --agent pode NAO ter resolvido no runtime (saida possivelmente do 'build' full-access). Verifique o provisionamento do reviewer-ro." -ForegroundColor Red
    }

    Write-Host "-------------------------------------------------------------" -ForegroundColor White
    Write-Host "RESPOSTA FINAL:" -ForegroundColor Green
    Write-Host $final
    Write-Host ("Custo total USD {0:N5} | tokens {1}" -f $script:totalCost, $script:lastTokens) -ForegroundColor DarkCyan
    Write-Host ("result.json: {0}" -f $resultPath) -ForegroundColor DarkGray
}
