#requires -Version 7.4
<#
.SYNOPSIS
    Monitor incremental de um job assincrono do Claude Code.
.DESCRIPTION
    Le o stream JSONL emitido por `claude -p --output-format stream-json`, mostra texto
    parcial quando disponivel e grava <GUID>.result.json ao final.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $JobId,
    [Parameter(Mandatory)] [int] $ProcessId,
    [string] $TempDir = (Join-Path ([System.IO.Path]::GetTempPath()) 'claude-code-jobs'),
    [ValidateRange(1, 30)] [int] $IntervalSeconds = 2,
    [ValidateRange(30, 3600)] [int] $SilenceThresholdSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ClaudeCodeCliSupport.ps1')

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

$base = Join-Path $TempDir $JobId
$streamPath = "$base.stream.jsonl"
$errPath = "$base.stderr.txt"
$resultPath = "$base.result.json"

Write-Host "Monitorando Claude Code job $JobId (PID $ProcessId)" -ForegroundColor Cyan
Write-Host "Stream: $streamPath" -ForegroundColor DarkGray

$seen = 0
$finalText = ''
$streamError = ''
$streamEvents = [System.Collections.Generic.List[object]]::new()
$lastActivity = Get-Date

while ($true) {
    if (Test-Path -LiteralPath $streamPath -PathType Leaf) {
        $lines = @(Get-Content -LiteralPath $streamPath -Encoding utf8 -ErrorAction SilentlyContinue)
        for ($i = $seen; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $ev = $null
            try { $ev = $line | ConvertFrom-Json } catch { continue }
            $streamEvents.Add($ev)
            $txt = Get-ClaudeCodeStreamEventText -StreamEvent $ev
            if (-not [string]::IsNullOrEmpty($txt)) {
                Write-Host $txt -NoNewline
                $finalText += $txt
                $lastActivity = Get-Date
            }
            # Cobre tanto `type=error` quanto o evento final `type=result` com `is_error=true`
            # (subtype `error_max_turns` e afins), que e a forma real do desfecho no stream-json.
            $evError = Get-ClaudeCodeStreamEventErrorText -StreamEvent $ev
            if (-not [string]::IsNullOrWhiteSpace($evError)) {
                $streamError = $evError
                $lastActivity = Get-Date
            }
        }
        $seen = $lines.Count
    }

    $running = $false
    try { $running = $null -ne (Get-Process -Id $ProcessId -ErrorAction Stop) } catch { $running = $false }
    if (-not $running) { break }

    if (((Get-Date) - $lastActivity).TotalSeconds -gt $SilenceThresholdSeconds) {
        Write-Host "`nSem nova saida ha mais de $SilenceThresholdSeconds s; processo ainda ativo." -ForegroundColor Yellow
        $lastActivity = Get-Date
    }
    Start-Sleep -Seconds $IntervalSeconds
}

$stderr = ''
if (Test-Path -LiteralPath $errPath -PathType Leaf) {
    $stderr = Get-Content -LiteralPath $errPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
}
$finalText = Get-ClaudeCodeStreamAcceptedTextFromEvents -StreamEvents @($streamEvents)
$status = Resolve-ClaudeCodeJobStatus -FinalText $finalText -StreamError $streamError -Stderr $stderr

$result = [ordered]@{
    jobId = $JobId
    status = $status.status
    finalText = $finalText
    error = $status.error
    # Falha observada DEPOIS de o job ja ter produzido texto (acontece no esgotamento de turno
    # quando o assistente emitiu algo antes de gastar o ultimo turno numa ferramenta): nao muda o
    # status, mas preserva a evidencia de que a resposta pode estar truncada.
    failureAfterText = $status.failureAfterText
    stderr = $stderr
    finishedAt = (Get-Date).ToString('o')
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultPath -Encoding utf8

Write-Host "`nStatus: $($status.status)" -ForegroundColor Cyan
Write-Host "Result: $resultPath" -ForegroundColor DarkGray
