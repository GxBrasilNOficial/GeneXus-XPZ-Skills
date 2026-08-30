#requires -Version 7.4
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
. (Join-Path $scriptsDir 'OpenCodeStreamSupport.ps1')
$watcher = Join-Path $scriptsDir 'Watch-OpenCodeJob.ps1'
$starter = Join-Path $scriptsDir 'Start-OpenCodeJob.ps1'

function Assert-True { param([bool]$c, [string]$m) if (-not $c) { throw $m } }

$threw = $false
try { & $starter -Message 'x' -NoWatcher -WatchTimeoutSec 5 } catch { $threw = $true; $msg = $_.Exception.Message }
Assert-True $threw 'WatchTimeoutSec+NoWatcher deveria lancar antes do spawn'
Assert-True ($msg -match 'WatchTimeoutSec exige watcher') "mensagem de conflito; veio: $msg"

$jobDir = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-oc-watch-limit-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $jobDir -Force | Out-Null
$killLog = Join-Path $jobDir 'kill.log'
try {
    $jobId = [guid]::NewGuid().ToString('N')
    $base = Join-Path $jobDir $jobId
    $streamPath = "$base.stream.jsonl"
    $stderrPath = "$base.stderr.txt"
    $requestPath = "$base.request.json"
    $resultPath = "$base.result.json"
    '{"type":"text","part":{"messageID":"m1","text":"x"}}' | Set-Content -LiteralPath $streamPath -Encoding utf8
    Set-Content -LiteralPath $stderrPath -Value '' -Encoding utf8
    [pscustomobject]@{ jobId = $jobId; model = 'fake/model'; agent = 'reviewer-ro'; prompt = 'p'; startedAt = ([datetime]::UtcNow).ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath $requestPath -Encoding utf8
    '{"schemaVersion":2}' | Set-Content -LiteralPath $resultPath -Encoding utf8

    $sleeper = Start-Process pwsh -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 20') -WindowStyle Hidden -PassThru
    $env:XPZ_TEST_OPENCODE_WATCH_KILL_LOG = $killLog
    $watchErr = Join-Path $jobDir 'werr.txt'
    $watchOut = Join-Path $jobDir 'wout.txt'
    $watch = Start-Process pwsh -ArgumentList @('-NoProfile','-File',$watcher,'-JobId',$jobId,'-ProcessId',"$($sleeper.Id)",'-TempDir',$jobDir,'-IntervalSeconds','1','-SilenceThresholdSeconds','30') `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $watchOut -RedirectStandardError $watchErr
    $watch.WaitForExit(15000) | Out-Null
    Assert-True ($watch.ExitCode -eq 21) "result preexistente deve sair 21; veio $($watch.ExitCode)"
    Assert-True ($sleeper.HasExited -eq $false) 'sleeper nao deveria ser morto (zero Kill efetivo)'
    Assert-True (-not (Test-Path -LiteralPath $killLog)) 'Kill nao deveria ter sido chamado'
    try { $sleeper.Kill($true) } catch { }

    $jobId2 = [guid]::NewGuid().ToString('N')
    $base2 = Join-Path $jobDir $jobId2
    '{"type":"text","part":{"messageID":"m1","text":"x"}}' | Set-Content -LiteralPath "$base2.stream.jsonl" -Encoding utf8
    Set-Content -LiteralPath "$base2.stderr.txt" -Value '' -Encoding utf8
    [pscustomobject]@{ jobId = $jobId2; model = 'fake/model'; agent = 'reviewer-ro'; prompt = 'p'; startedAt = ([datetime]::UtcNow).ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath "$base2.request.json" -Encoding utf8
    $env:XPZ_TEST_OPENCODE_WATCH_FORCE_IDENTITY_UNVERIFIABLE = '1'
    $sleeper2 = Start-Process pwsh -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 25') -WindowStyle Hidden -PassThru
    $werr2 = Join-Path $jobDir 'werr2.txt'
    $wout2 = Join-Path $jobDir 'wout2.txt'
    $watch2 = Start-Process pwsh -ArgumentList @(
        '-NoProfile','-File',$watcher,'-JobId',$jobId2,'-ProcessId',"$($sleeper2.Id)",'-TempDir',$jobDir,
        '-IntervalSeconds','1','-SilenceThresholdSeconds','30','-WatchTimeoutSec','2'
    ) -WindowStyle Hidden -PassThru -RedirectStandardOutput $wout2 -RedirectStandardError $werr2
    $watch2.WaitForExit(20000) | Out-Null
    Assert-True ($watch2.ExitCode -eq 20) "timeout unverifiable deve promover 20; veio $($watch2.ExitCode)"
    $json2 = Get-Content -LiteralPath "$base2.result.json" -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($json2.rejectionReason -eq 'opencode-watch-timeout') "reason timeout; veio $($json2.rejectionReason)"
    Assert-True ($json2.cancelIdentityUnverifiable -eq $true) 'cancelIdentityUnverifiable'
    $err2 = Get-Content -LiteralPath $werr2 -Raw -Encoding utf8
    Assert-True ($err2 -match 'identidade ficara nao verificavel') 'stderr deve avisar unverifiable'
    try { $sleeper2.Kill($true) } catch { }

    $jobId3 = [guid]::NewGuid().ToString('N')
    $base3 = Join-Path $jobDir $jobId3
    $stream3 = "$base3.stream.jsonl"
    Start-Sleep -Milliseconds 50
    $sleeper3 = Start-Process pwsh -ArgumentList @('-NoProfile','-Command','Start-Sleep -Milliseconds 400; exit 0') -WindowStyle Hidden -PassThru
    [pscustomobject]@{ jobId = $jobId3; model = 'fake/model'; agent = 'reviewer-ro'; prompt = 'p' } |
        ConvertTo-Json | Set-Content -LiteralPath "$base3.request.json" -Encoding utf8
    Set-Content -LiteralPath "$base3.stderr.txt" -Value '' -Encoding utf8
    $werr3 = Join-Path $jobDir 'werr3.txt'
    $wout3 = Join-Path $jobDir 'wout3.txt'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $watch3 = Start-Process pwsh -ArgumentList @('-NoProfile','-File',$watcher,'-JobId',$jobId3,'-ProcessId',"$($sleeper3.Id)",'-TempDir',$jobDir,'-IntervalSeconds','1','-SilenceThresholdSeconds','30') `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $wout3 -RedirectStandardError $werr3
    $watch3.WaitForExit(20000) | Out-Null
    $sw.Stop()
    Assert-True ($sw.Elapsed.TotalSeconds -lt 25) "morte na espera de stream nao deve esperar 30s; levou $($sw.Elapsed.TotalSeconds)"
    Assert-True (Test-Path -LiteralPath "$base3.result.json") 'deve promover result apos morte sem stream'

    Remove-Item Env:XPZ_TEST_OPENCODE_WATCH_FORCE_IDENTITY_UNVERIFIABLE -ErrorAction SilentlyContinue

    $fixedUsage = Format-OpenCodeLimitBlock -Kind 'usage-limit' -Message ''
    $jobId4 = [guid]::NewGuid().ToString('N')
    $base4 = Join-Path $jobDir $jobId4
    '{"type":"text","part":{"messageID":"m1","text":"x"}}' | Set-Content -LiteralPath "$base4.stream.jsonl" -Encoding utf8
    Set-Content -LiteralPath "$base4.stderr.txt" -Value 'weekly usage limit' -Encoding utf8
    [pscustomobject]@{ jobId = $jobId4; model = 'fake/model'; agent = 'reviewer-ro'; prompt = 'p'; startedAt = ([datetime]::UtcNow).ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath "$base4.request.json" -Encoding utf8
    $sleeper4 = Start-Process pwsh -ArgumentList @('-NoProfile','-Command','Start-Sleep -Milliseconds 400; exit 0') -WindowStyle Hidden -PassThru
    $werr4 = Join-Path $jobDir 'werr4.txt'
    $wout4 = Join-Path $jobDir 'wout4.txt'
    $watch4 = Start-Process pwsh -ArgumentList @('-NoProfile','-File',$watcher,'-JobId',$jobId4,'-ProcessId',"$($sleeper4.Id)",'-TempDir',$jobDir,'-IntervalSeconds','1','-SilenceThresholdSeconds','30') `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $wout4 -RedirectStandardError $werr4
    $watch4.WaitForExit(20000) | Out-Null
    Assert-True ($watch4.ExitCode -eq 20) "limite via stderr do job deve sair 20; veio $($watch4.ExitCode)"
    $json4 = Get-Content -LiteralPath "$base4.result.json" -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($json4.status -eq 'limite-uso') "status limite-uso; veio $($json4.status)"
    Assert-True ($json4.rejectionReason -eq 'provider-usage-limit') "reason usage; veio $($json4.rejectionReason)"
    Assert-True ($json4.resultAccepted -eq $false) 'resultAccepted false no limite'
    Assert-True ([string]$json4.error -like "$fixedUsage*") "error Format usage; veio: $($json4.error)"
    try { if (-not $sleeper4.HasExited) { $sleeper4.Kill($true) } } catch { }

    $killLog5 = Join-Path $jobDir 'kill5.log'
    $env:XPZ_TEST_OPENCODE_WATCH_KILL_LOG = $killLog5
    $jobId5 = [guid]::NewGuid().ToString('N')
    $base5 = Join-Path $jobDir $jobId5
    '{"type":"text","part":{"messageID":"m1","text":"x"}}' | Set-Content -LiteralPath "$base5.stream.jsonl" -Encoding utf8
    Set-Content -LiteralPath "$base5.stderr.txt" -Value '' -Encoding utf8
    [pscustomobject]@{ jobId = $jobId5; model = 'fake/model'; agent = 'reviewer-ro'; prompt = 'p'; startedAt = ([datetime]::UtcNow).ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath "$base5.request.json" -Encoding utf8
    $sleeper5 = Start-Process pwsh -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 25') -WindowStyle Hidden -PassThru
    $expIso = ([datetime]$sleeper5.StartTime).ToUniversalTime().ToString('o')
    $werr5 = Join-Path $jobDir 'werr5.txt'
    $wout5 = Join-Path $jobDir 'wout5.txt'
    $watch5 = Start-Process pwsh -ArgumentList @(
        '-NoProfile','-File',$watcher,'-JobId',$jobId5,'-ProcessId',"$($sleeper5.Id)",'-TempDir',$jobDir,
        '-IntervalSeconds','1','-SilenceThresholdSeconds','30','-WatchTimeoutSec','2',
        '-ExpectedStartTimeUtc', $expIso
    ) -WindowStyle Hidden -PassThru -RedirectStandardOutput $wout5 -RedirectStandardError $werr5
    $watch5.WaitForExit(20000) | Out-Null
    Assert-True ($watch5.ExitCode -eq 20) "timeout identidade verificada deve sair 20; veio $($watch5.ExitCode)"
    $json5 = Get-Content -LiteralPath "$base5.result.json" -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($json5.rejectionReason -eq 'opencode-watch-timeout') "reason timeout verificado; veio $($json5.rejectionReason)"
    Assert-True ($json5.processIdentityVerified -eq $true) 'processIdentityVerified'
    Assert-True ($json5.cancelIdentityUnverifiable -eq $false) 'cancelIdentityUnverifiable false'
    Assert-True ($json5.cancelAttempted -eq $true) 'cancelAttempted'
    Assert-True (Test-Path -LiteralPath $killLog5) 'Kill deveria ter sido chamado'
    Assert-True ((Get-Content -LiteralPath $killLog5 -Raw -Encoding utf8) -match 'Kill\(true\)') 'kill.log Kill(true)'
    try { if (-not $sleeper5.HasExited) { $sleeper5.Kill($true) } } catch { }

    Write-Output 'OK: Test-OpenCodeWatchJobLimitSelfTest.ps1'
} finally {
    Remove-Item Env:XPZ_TEST_OPENCODE_WATCH_KILL_LOG -ErrorAction SilentlyContinue
    Remove-Item Env:XPZ_TEST_OPENCODE_WATCH_FORCE_IDENTITY_UNVERIFIABLE -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $jobDir) { Remove-Item -LiteralPath $jobDir -Recurse -Force -ErrorAction SilentlyContinue }
}
