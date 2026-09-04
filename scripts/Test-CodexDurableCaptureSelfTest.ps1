#requires -Version 7.4
<#
.SYNOPSIS
    Self-test da captura duravel Codex (TempDir, KeepDays, sentinelas, Watch, kb-sensitive).
.DESCRIPTION
    Deterministico com fake-exe. Nunca toca %TEMP%\codex-jobs real do utilizador.
    Sentinela: OK: Test-CodexDurableCaptureSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
$invoke = Join-Path $scriptsDir 'Invoke-Codex.ps1'
$start  = Join-Path $scriptsDir 'Start-CodexJob.ps1'
$watch  = Join-Path $scriptsDir 'Watch-CodexJob.ps1'
. (Join-Path $scriptsDir 'CodexCliSupport.ps1')

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FALHOU: $Message" }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('codex-durable-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tmp) | Out-Null
$jobs = Join-Path $tmp 'jobs'
[IO.Directory]::CreateDirectory($jobs) | Out-Null

$prevDisable = $env:XPZ_CODEX_DISABLE_KEEPDAYS
$env:XPZ_CODEX_DISABLE_KEEPDAYS = '1'
$prevJobsDir = $env:XPZ_CODEX_JOBS_DIR

try {
    # --- fake readers ---
    $okReader = Join-Path $tmp 'fake-ok.ps1'
    @'
$o = $null
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '-o') { $o = $args[$i + 1]; break } }
$s = [Console]::In.ReadToEnd()
if ($o) { Set-Content -LiteralPath $o -Value ('OPINION=' + $s.Length) -Encoding utf8 -NoNewline }
exit 0
'@ | Set-Content -LiteralPath $okReader -Encoding utf8
    $okCmd = Join-Path $tmp 'fake-ok.cmd'
    "@echo off`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"$okReader`" %*`r`n" | Set-Content -LiteralPath $okCmd -Encoding ascii

    $emptyReader = Join-Path $tmp 'fake-empty.ps1'
    @'
$o = $null
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '-o') { $o = $args[$i + 1]; break } }
[void][Console]::In.ReadToEnd()
if ($o) { Set-Content -LiteralPath $o -Value '' -Encoding utf8 -NoNewline }
exit 0
'@ | Set-Content -LiteralPath $emptyReader -Encoding utf8
    $emptyCmd = Join-Path $tmp 'fake-empty.cmd'
    "@echo off`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"$emptyReader`" %*`r`n" | Set-Content -LiteralPath $emptyCmd -Encoding ascii

    $timeoutReader = Join-Path $tmp 'fake-timeout.ps1'
    @'
$o = $null
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '-o') { $o = $args[$i + 1]; break } }
[void][Console]::In.ReadToEnd()
if ($o) { Set-Content -LiteralPath $o -Value 'PARTIAL-BYTES' -Encoding utf8 -NoNewline }
exit 0
'@ | Set-Content -LiteralPath $timeoutReader -Encoding utf8
    $timeoutCmd = Join-Path $tmp 'fake-timeout.cmd'
    "@echo off`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"$timeoutReader`" %*`r`n" | Set-Content -LiteralPath $timeoutCmd -Encoding ascii

    $timeoutEmptyReader = Join-Path $tmp 'fake-timeout-empty.ps1'
    @'
[void][Console]::In.ReadToEnd()
exit 0
'@ | Set-Content -LiteralPath $timeoutEmptyReader -Encoding utf8
    $timeoutEmptyCmd = Join-Path $tmp 'fake-timeout-empty.cmd'
    "@echo off`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"$timeoutEmptyReader`" %*`r`n" | Set-Content -LiteralPath $timeoutEmptyCmd -Encoding ascii

    $prompt = Join-Path $tmp 'prompt.txt'
    Set-Content -LiteralPath $prompt -Value 'hello-durable' -Encoding utf8 -NoNewline

    # ===== Resolve-CodexJobTempDir unit =====
    $resolvedTd = Resolve-CodexJobTempDir -Override $jobs
    Assert-True ([IO.Path]::IsPathRooted($resolvedTd)) 'TempDir: absoluto'
    Assert-True ($resolvedTd -eq [IO.Path]::GetFullPath($jobs)) 'TempDir: Bound'
    Write-Host 'PASS Resolve-CodexJobTempDir' -ForegroundColor Green

    # ===== 1 sucesso in-process public =====
    $j1 = Join-Path $jobs 't1'
    $ans = [string](& $invoke -CodexExe $okCmd -MessagePath $prompt -TempDir $j1 -TimeoutSec 60 -RetentionMode public)
    Assert-True ($ans -eq 'OPINION=13') "1: stdout so parecer; got '$ans'"
    $files1 = @(Get-ChildItem -LiteralPath $j1 -File)
    Assert-True ($null -eq (@($files1 | Where-Object { $_.Name -like '*.invoke-*' }) | Select-Object -First 1)) '1: invoke-* apagados'
    Assert-True (@($files1 | Where-Object { $_.Name -like '*.lastmsg.txt' }).Count -eq 1) '1: lastmsg permanece'
    $req1File = @($files1 | Where-Object { $_.Name -like '*.request.json' })[0]
    $req1 = Get-Content -LiteralPath $req1File.FullName -Raw | ConvertFrom-Json
    Assert-True ($req1.captureOutcome -eq 'success') '1: captureOutcome=success'
    Write-Host 'PASS 1 sucesso public' -ForegroundColor Green
    # 12k: mesmo caminho de sucesso — finally nao lanca; parecer via successText
    Assert-True ($ans.Length -gt 0) '12k: texto devolvido sem throw'
    Write-Host 'PASS 12k success sem throw' -ForegroundColor Green

    # ===== 1b out-of-process stderr =====
    $j1b = Join-Path $jobs 't1b'
    [IO.Directory]::CreateDirectory($j1b) | Out-Null
    $stdout1b = Join-Path $tmp '1b-out.txt'
    $stderr1b = Join-Path $tmp '1b-err.txt'
    $p1b = Start-Process -FilePath pwsh -ArgumentList @(
        '-NoProfile', '-File', $invoke,
        '-CodexExe', $okCmd, '-MessagePath', $prompt, '-TempDir', $j1b,
        '-TimeoutSec', '60', '-RetentionMode', 'public'
    ) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout1b -RedirectStandardError $stderr1b
    Assert-True ($p1b.ExitCode -eq 0) "1b: exit 0 got $($p1b.ExitCode)"
    $out1b = (Get-Content -LiteralPath $stdout1b -Raw).Trim()
    $err1b = Get-Content -LiteralPath $stderr1b -Raw -ErrorAction SilentlyContinue
    Assert-True ($out1b -eq 'OPINION=13') "1b: stdout so parecer; got '$out1b'"
    Assert-True ($err1b -match 'XPZ_CODEX_LASTMSG=') '1b: sentinela LASTMSG em stderr'
    Assert-True ($err1b -match 'XPZ_CODEX_REQUEST=') '1b: sentinela REQUEST em stderr'
    Assert-True ($out1b -notmatch 'XPZ_CODEX_') '1b: stdout sem sentinela'
    Write-Host 'PASS 1b out-of-process' -ForegroundColor Green

    # ===== 2a timeout com bytes, RetentionMode=public =====
    $j2a = Join-Path $jobs 't2a'
    $threw2a = $false; $msg2a = $null
    $env:XPZ_TEST_CODEX_FORCE_TIMEOUT = '1'
    try {
        & $invoke -CodexExe $timeoutCmd -MessagePath $prompt -TempDir $j2a -TimeoutSec 2 -RetentionMode public | Out-Null
    } catch {
        $threw2a = $true
        $msg2a = [string]$_.Exception.Message
    }
    Remove-Item Env:\XPZ_TEST_CODEX_FORCE_TIMEOUT -ErrorAction SilentlyContinue
    Assert-True $threw2a '2a: deveria lancar'
    Assert-True ($msg2a -match 'excedeu' -and $msg2a -match 'foi encerrado') '2a: excedeu+foi encerrado'
    Assert-True ($msg2a -match 'XPZ_CODEX_LASTMSG=') '2a: sentinela'
    $req2aPath = @(Get-ChildItem -LiteralPath $j2a -Filter '*.request.json')[0].FullName
    $req2a = Get-Content -LiteralPath $req2aPath -Raw | ConvertFrom-Json
    Assert-True ($req2a.captureOutcome -eq 'timeout') '2a: captureOutcome=timeout no disco'
    Write-Host 'PASS 2a timeout com bytes' -ForegroundColor Green

    # ===== 2b timeout sem bytes =====
    $j2b = Join-Path $jobs 't2b'
    $threw2b = $false; $msg2b = $null
    $env:XPZ_TEST_CODEX_FORCE_TIMEOUT = '1'
    try {
        & $invoke -CodexExe $timeoutEmptyCmd -MessagePath $prompt -TempDir $j2b -TimeoutSec 2 -RetentionMode public | Out-Null
    } catch {
        $threw2b = $true
        $msg2b = [string]$_.Exception.Message
    }
    Remove-Item Env:\XPZ_TEST_CODEX_FORCE_TIMEOUT -ErrorAction SilentlyContinue
    Assert-True $threw2b '2b: deveria lancar'
    Assert-True ($msg2b -match 'excedeu' -and $msg2b -match 'foi encerrado') '2b: markers'
    $req2b = Get-Content -LiteralPath (@(Get-ChildItem -LiteralPath $j2b -Filter '*.request.json')[0].FullName) -Raw | ConvertFrom-Json
    Assert-True ($req2b.captureOutcome -eq 'timeout') '2b: captureOutcome=timeout'
    Write-Host 'PASS 2b timeout sem bytes' -ForegroundColor Green

    # ===== 2d: timeout REAL (sem FORCE_TIMEOUT) com lastmsg -> recupera parecer =====
    $hangReader = Join-Path $tmp 'fake-hang-after-lastmsg.ps1'
    @'
$o = $null
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '-o') { $o = $args[$i + 1]; break } }
[void][Console]::In.ReadToEnd()
if ($o) { Set-Content -LiteralPath $o -Value 'RECOVERED-AFTER-KILL' -Encoding utf8 -NoNewline }
Start-Sleep -Seconds 30
exit 0
'@ | Set-Content -LiteralPath $hangReader -Encoding utf8
    $hangCmd = Join-Path $tmp 'fake-hang-after-lastmsg.cmd'
    "@echo off`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"$hangReader`" %*`r`n" | Set-Content -LiteralPath $hangCmd -Encoding ascii
    $j2d = Join-Path $jobs 'j2d-recover'
    [IO.Directory]::CreateDirectory($j2d) | Out-Null
    $ans2d = [string](& $invoke -CodexExe $hangCmd -MessagePath $prompt -TempDir $j2d -TimeoutSec 2 -RetentionMode public)
    Assert-True ($ans2d -eq 'RECOVERED-AFTER-KILL') "2d: deveria recuperar lastmsg apos Kill; got '$ans2d'"
    $req2d = Get-Content -LiteralPath (@(Get-ChildItem -LiteralPath $j2d -Filter '*.request.json')[0].FullName) -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($req2d.captureOutcome -eq 'success') '2d: captureOutcome=success apos recuperacao'
    Assert-True ([bool]$req2d.recoveredAfterTimeout) '2d: recoveredAfterTimeout=true no request.json'
    Write-Host 'PASS 2d recover after timeout' -ForegroundColor Green

    # ===== 3 MessagePath invalido =====
    $j3 = Join-Path $jobs 't3'
    [IO.Directory]::CreateDirectory($j3) | Out-Null
    $before3 = @(Get-ChildItem -LiteralPath $j3 -File -ErrorAction SilentlyContinue).Count
    $threw3 = $false
    try { & $invoke -CodexExe $okCmd -MessagePath (Join-Path $tmp 'nope.txt') -TempDir $j3 -TimeoutSec 10 | Out-Null } catch { $threw3 = $true }
    Assert-True $threw3 '3: throw'
    Assert-True (@(Get-ChildItem -LiteralPath $j3 -File -ErrorAction SilentlyContinue).Count -eq $before3) '3: zero ficheiros novos'
    Write-Host 'PASS 3 MessagePath invalido' -ForegroundColor Green

    # ===== 3b exe podre =====
    $j3b = Join-Path $jobs 't3b'
    [IO.Directory]::CreateDirectory($j3b) | Out-Null
    $before3b = @(Get-ChildItem -LiteralPath $j3b -File -ErrorAction SilentlyContinue).Count
    $threw3b = $false
    try { & $invoke -CodexExe (Join-Path $tmp 'nao-existe-codex.exe') -MessagePath $prompt -TempDir $j3b -TimeoutSec 10 | Out-Null } catch { $threw3b = $true }
    Assert-True $threw3b '3b: throw'
    Assert-True (@(Get-ChildItem -LiteralPath $j3b -File -ErrorAction SilentlyContinue).Count -eq $before3b) '3b: zero ficheiros'
    Write-Host 'PASS 3b exe podre' -ForegroundColor Green

    # ===== 4 Start -NoWatcher =====
    $j4 = Join-Path $jobs 't4'
    $json4 = & $start -CodexExe $okCmd -MessagePath $prompt -TempDir $j4 -NoWatcher | ConvertFrom-Json
    Assert-True ($json4.watcher -eq $false) '4: watcher=false'
    # mata o processo fake se ainda vivo
    try { Stop-Process -Id ([int]$json4.pid) -Force -ErrorAction SilentlyContinue } catch { }
    Write-Host 'PASS 4 Start NoWatcher' -ForegroundColor Green

    # ===== 4b spawn fail =====
    $j4b = Join-Path $jobs 't4b'
    $env:XPZ_TEST_CODEX_START_FAIL_SPAWN = '1'
    $threw4b = $false
    $out4b = $null
    try { $out4b = & $start -CodexExe $okCmd -MessagePath $prompt -TempDir $j4b -NoWatcher } catch { $threw4b = $true }
    Remove-Item Env:\XPZ_TEST_CODEX_START_FAIL_SPAWN -ErrorAction SilentlyContinue
    Assert-True $threw4b '4b: spawn fail throw'
    Assert-True ($null -eq $out4b -or [string]$out4b -notmatch '\{') '4b: sem JSON stdout'
    Write-Host 'PASS 4b spawn fail' -ForegroundColor Green

    # ===== 4c rewrite fail apos spawn =====
    $j4c = Join-Path $jobs 't4c'
    $env:XPZ_TEST_CODEX_START_FAIL_REQUEST_REWRITE = '1'
    $json4c = & $start -CodexExe $okCmd -MessagePath $prompt -TempDir $j4c -NoWatcher | ConvertFrom-Json
    Remove-Item Env:\XPZ_TEST_CODEX_START_FAIL_REQUEST_REWRITE -ErrorAction SilentlyContinue
    $ident4c = @(Get-ChildItem -LiteralPath $j4c -Filter '*.identity.json')
    Assert-True ($ident4c.Count -eq 1) '4c: identity.json existe'
    $idObj = Get-Content -LiteralPath $ident4c[0].FullName -Raw | ConvertFrom-Json
    Assert-True ($null -ne $idObj.pid) '4c: identity tem pid'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$idObj.processStartTimeUtc)) '4c: identity tem processStartTimeUtc'
    $guid4c = [IO.Path]::GetFileNameWithoutExtension([IO.Path]::GetFileNameWithoutExtension($ident4c[0].Name))
    # filename is {guid}.identity.json -> GetFileNameWithoutExtension twice
    $guid4c = $ident4c[0].Name -replace '\.identity\.json$', ''
    $resolved4c = Resolve-CodexPidAndStartTime -TempDir $j4c -JobId $guid4c
    Assert-True ($resolved4c.divergence -eq $false) '4c: divergence=false'
    try { Stop-Process -Id ([int]$json4c.pid) -Force -ErrorAction SilentlyContinue } catch { }
    Write-Host 'PASS 4c rewrite fail identity' -ForegroundColor Green

    # ===== 5g pasta vazia + pid morto =====
    $j5g = Join-Path $jobs 't5g'
    [IO.Directory]::CreateDirectory($j5g) | Out-Null
    $deadPid = 999999
    $err5g = Join-Path $tmp '5g-err.txt'
    $p5g = Start-Process -FilePath pwsh -ArgumentList @(
        '-NoProfile', '-File', $watch,
        '-JobId', ('a' * 32), '-ProcessId', "$deadPid", '-TempDir', $j5g
    ) -Wait -PassThru -NoNewWindow -RedirectStandardError $err5g -RedirectStandardOutput (Join-Path $tmp '5g-out.txt')
    Assert-True ($p5g.ExitCode -eq 0) "5g: exit 0 got $($p5g.ExitCode)"
    $e5g = Get-Content -LiteralPath $err5g -Raw -ErrorAction SilentlyContinue
    Assert-True ($e5g -match 'AVISO: grupo Codex ausente') '5g: AVISO'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $j5g (('a' * 32) + '.result.json')))) '5g: sem result.json'
    Write-Host 'PASS 5g pasta vazia morto' -ForegroundColor Green

    # ===== 5f JobId invalido =====
    $j5f = Join-Path $jobs 't5f-should-not-create'
    $env:XPZ_CODEX_JOBS_DIR = $j5f
    $threw5f = $false; $msg5f = $null
    try {
        & $watch -JobId 'not-a-guid' -ProcessId $deadPid 2>$null | Out-Null
    } catch {
        $threw5f = $true
        $msg5f = [string]$_.Exception.Message
    }
    Remove-Item Env:\XPZ_CODEX_JOBS_DIR -ErrorAction SilentlyContinue
    Assert-True $threw5f '5f: throw'
    Assert-True ($msg5f -match 'JobId nao e GUID N') '5f: mensagem'
    Assert-True (-not (Test-Path -LiteralPath $j5f)) '5f: TempDir nao criado'
    Write-Host 'PASS 5f JobId invalido' -ForegroundColor Green

    # ===== 5k vivo sem hora =====
    $j5k = Join-Path $jobs 't5k'
    [IO.Directory]::CreateDirectory($j5k) | Out-Null
    $guid5k = [guid]::NewGuid().ToString('N')
    $err5k = Join-Path $tmp '5k-err.txt'
    $p5k = Start-Process -FilePath pwsh -ArgumentList @(
        '-NoProfile', '-File', $watch,
        '-JobId', $guid5k, '-ProcessId', "$PID", '-TempDir', $j5k
    ) -Wait -PassThru -NoNewWindow -RedirectStandardError $err5k -RedirectStandardOutput (Join-Path $tmp '5k-out.txt')
    Assert-True ($p5k.ExitCode -eq 22) "5k: exit 22 got $($p5k.ExitCode)"
    $e5k = Get-Content -LiteralPath $err5k -Raw -ErrorAction SilentlyContinue
    Assert-True ($e5k -match 'BLOCK: identidade do processo recusada') '5k: BLOCK identidade'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $j5k "$guid5k.result.json"))) '5k: sem result.json'
    Write-Host 'PASS 5k vivo sem hora' -ForegroundColor Green

    # ===== 6 clobber 21 =====
    $j6 = Join-Path $jobs 't6'
    [IO.Directory]::CreateDirectory($j6) | Out-Null
    $guid6 = [guid]::NewGuid().ToString('N')
    Set-Content -LiteralPath (Join-Path $j6 "$guid6.lastmsg.txt") -Value 'x' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $j6 "$guid6.result.json") -Value '{"pre":true}' -Encoding utf8
    $err6 = Join-Path $tmp '6-err.txt'
    $p6 = Start-Process -FilePath pwsh -ArgumentList @(
        '-NoProfile', '-File', $watch,
        '-JobId', $guid6, '-ProcessId', "$deadPid", '-TempDir', $j6,
        '-ExpectedStartTimeUtc', '2020-01-01T00:00:00.000Z'
    ) -Wait -PassThru -NoNewWindow -RedirectStandardError $err6 -RedirectStandardOutput (Join-Path $tmp '6-out.txt')
    Assert-True ($p6.ExitCode -eq 21) "6: exit 21 got $($p6.ExitCode)"
    Write-Host 'PASS 6 clobber 21' -ForegroundColor Green

    # ===== 12i empty =====
    $j12i = Join-Path $jobs 't12i'
    $threw12i = $false; $msg12i = $null
    try { & $invoke -CodexExe $emptyCmd -MessagePath $prompt -TempDir $j12i -TimeoutSec 60 -RetentionMode public | Out-Null } catch {
        $threw12i = $true
        $msg12i = [string]$_.Exception.Message
    }
    Assert-True $threw12i '12i: throw'
    $firstLine = ($msg12i -replace "`r`n", "`n" -split "`n")[0]
    Assert-True ($firstLine -eq 'BLOCK: codex nao produziu resposta (output-last-message vazio).') "12i: primeira linha exacta; got '$firstLine'"
    Assert-True ($msg12i -match 'XPZ_CODEX_') '12i: sentinelas'
    $req12i = Get-Content -LiteralPath (@(Get-ChildItem -LiteralPath $j12i -Filter '*.request.json')[0].FullName) -Raw | ConvertFrom-Json
    Assert-True ($req12i.captureOutcome -eq 'empty') '12i: captureOutcome=empty'
    Write-Host 'PASS 12i empty' -ForegroundColor Green

    # ===== 12m kb-sensitive timeout =====
    $j12m = Join-Path $jobs 't12m'
    $threw12m = $false; $msg12m = $null
    $env:XPZ_TEST_CODEX_FORCE_TIMEOUT = '1'
    try {
        & $invoke -CodexExe $timeoutCmd -MessagePath $prompt -TempDir $j12m -TimeoutSec 2 -RetentionMode 'kb-sensitive' | Out-Null
    } catch {
        $threw12m = $true
        $msg12m = [string]$_.Exception.Message
    }
    Remove-Item Env:\XPZ_TEST_CODEX_FORCE_TIMEOUT -ErrorAction SilentlyContinue
    Assert-True $threw12m '12m: throw'
    Assert-True ($msg12m -match 'XPZ_CODEX_CAPTURED_TEXT_BEGIN') '12m: CAPTURED_TEXT_BEGIN'
    Assert-True ($msg12m -match 'PARTIAL-BYTES') '12m: texto capturado'
    Assert-True (@(Get-ChildItem -LiteralPath $j12m -Filter '*.lastmsg.txt' -ErrorAction SilentlyContinue).Count -eq 0) '12m: lastmsg ausente'
    Assert-True (@(Get-ChildItem -LiteralPath $j12m -Filter '*.invoke-in.txt' -ErrorAction SilentlyContinue).Count -eq 0) '12m: invoke-in ausente'
    Write-Host 'PASS 12m kb-sensitive timeout' -ForegroundColor Green

    # ===== 12n kb-sensitive sucesso =====
    $j12n = Join-Path $jobs 't12n'
    $ans12n = [string](& $invoke -CodexExe $okCmd -MessagePath $prompt -TempDir $j12n -TimeoutSec 60 -RetentionMode 'kb-sensitive')
    Assert-True ($ans12n -eq 'OPINION=13') '12n: stdout parecer'
    Assert-True (@(Get-ChildItem -LiteralPath $j12n -Filter '*.lastmsg.txt' -ErrorAction SilentlyContinue).Count -eq 0) '12n: lastmsg ausente'
    Assert-True (@(Get-ChildItem -LiteralPath $j12n -Filter '*.invoke-*' -ErrorAction SilentlyContinue).Count -eq 0) '12n: invoke-* ausentes'
    Write-Host 'PASS 12n kb-sensitive sucesso' -ForegroundColor Green

    # ===== 12p kb-sensitive sucesso + rewrite fail =====
    $j12p = Join-Path $jobs 't12p'
    $env:XPZ_TEST_CODEX_INVOKE_FAIL_REWRITE = '1'
    $threw12p = $false; $msg12p = $null
    try {
        & $invoke -CodexExe $okCmd -MessagePath $prompt -TempDir $j12p -TimeoutSec 60 -RetentionMode 'kb-sensitive' | Out-Null
    } catch {
        $threw12p = $true
        $msg12p = [string]$_.Exception.Message
    }
    Remove-Item Env:\XPZ_TEST_CODEX_INVOKE_FAIL_REWRITE -ErrorAction SilentlyContinue
    Assert-True $threw12p '12p: throw'
    Assert-True ($msg12p -match 'falha ao gravar request.json') '12p: BLOCK rewrite'
    Assert-True ($msg12p -notmatch 'XPZ_CODEX_CAPTURED_TEXT_BEGIN') '12p: sem captura lastmsg'
    Assert-True (@(Get-ChildItem -LiteralPath $j12p -Filter '*.lastmsg.txt').Count -eq 1) '12p: lastmsg intacto'
    Write-Host 'PASS 12p rewrite fail sucesso' -ForegroundColor Green

    # ===== 12o unexpected =====
    $j12o = Join-Path $jobs 't12o'
    $env:XPZ_TEST_CODEX_INVOKE_UNEXPECTED = '1'
    $threw12o = $false; $msg12o = $null
    try {
        & $invoke -CodexExe $okCmd -MessagePath $prompt -TempDir $j12o -TimeoutSec 60 -RetentionMode public | Out-Null
    } catch {
        $threw12o = $true
        $msg12o = [string]$_.Exception.Message
    }
    Remove-Item Env:\XPZ_TEST_CODEX_INVOKE_UNEXPECTED -ErrorAction SilentlyContinue
    Assert-True $threw12o '12o: throw'
    Assert-True ($msg12o -match 'BLOCK:') '12o: BLOCK'
    $req12oFiles = @(Get-ChildItem -LiteralPath $j12o -Filter '*.request.json' -ErrorAction SilentlyContinue)
    if ($req12oFiles.Count -gt 0) {
        $req12o = Get-Content -LiteralPath $req12oFiles[0].FullName -Raw | ConvertFrom-Json
        Assert-True ($req12o.captureOutcome -eq 'error') '12o: captureOutcome=error'
    }
    Write-Host 'PASS 12o unexpected' -ForegroundColor Green

    # ===== 12q exit != 0 com stdout e stderr nao-classificados =====
    $j12q = Join-Path $jobs 't12q'
    $errReader = Join-Path $tmp 'fake-exit1.ps1'
    @'
[Console]::Out.WriteLine('linha de stdout 1')
[Console]::Error.WriteLine('linha de stderr 1')
exit 1
'@ | Set-Content -LiteralPath $errReader -Encoding utf8
    $errCmd = Join-Path $tmp 'fake-exit1.cmd'
    "@echo off`r`npwsh -NoProfile -ExecutionPolicy Bypass -File `"$errReader`" %*`r`n" | Set-Content -LiteralPath $errCmd -Encoding ascii
    $threw12q = $false; $msg12q = $null
    try {
        & $invoke -CodexExe $errCmd -MessagePath $prompt -TempDir $j12q -TimeoutSec 60 -RetentionMode public | Out-Null
    } catch {
        $threw12q = $true
        $msg12q = [string]$_.Exception.Message
    }
    Assert-True $threw12q '12q: throw'
    Assert-True ($msg12q -match 'BLOCK: codex saiu com codigo 1\.') '12q: BLOCK com codigo 1.'
    Assert-True ($msg12q -match 'stdout:\r?\nlinha de stdout 1') '12q: preserva stdout'
    Assert-True ($msg12q -match 'stderr:\r?\nlinha de stderr 1') '12q: preserva stderr'
    Assert-True ($msg12q -notmatch 'sem resposta') '12q: nao afirma sem resposta'
    Write-Host 'PASS 12q exit 1 com stdout/stderr preservados' -ForegroundColor Green

    # ===== 12h Bound TempDir vazio =====
    $j12h = Join-Path $jobs 't12h-env'
    $env:XPZ_CODEX_JOBS_DIR = $j12h
    $ans12h = [string](& $invoke -CodexExe $okCmd -MessagePath $prompt -TempDir '' -TimeoutSec 60 -RetentionMode public)
    Remove-Item Env:\XPZ_CODEX_JOBS_DIR -ErrorAction SilentlyContinue
    Assert-True ($ans12h -eq 'OPINION=13') '12h: sucesso via env'
    Assert-True (Test-Path -LiteralPath $j12h) '12h: usou env'
    $req12h = @(Get-ChildItem -LiteralPath $j12h -Filter '*.request.json')[0]
    Assert-True ([IO.Path]::IsPathRooted($req12h.DirectoryName)) '12h: path absoluto'
    Write-Host 'PASS 12h TempDir vazio -> env' -ForegroundColor Green

    # ===== 12j Watch 22 vs 99 =====
    Assert-True ($p5k.ExitCode -eq 22) '12j: identidade = 22'
    Assert-True ((Get-Content -LiteralPath $err5k -Raw) -match 'BLOCK: identidade') '12j: stderr BLOCK identidade'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $j5k "$guid5k.result.json"))) '12j: 22 sem result.json'
    $j99 = Join-Path $jobs 't99'
    [IO.Directory]::CreateDirectory($j99) | Out-Null
    $g99 = [guid]::NewGuid().ToString('N')
    Set-Content -LiteralPath (Join-Path $j99 "$g99.lastmsg.txt") -Value 'x' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $j99 "$g99.stderr.txt") -Value '' -Encoding utf8
    # .result.json.tmp como pasta → Set-Content no Write atomico falha → exit 99; sem result.json ficheiro
    [IO.Directory]::CreateDirectory((Join-Path $j99 "$g99.result.json.tmp")) | Out-Null
    $err99 = Join-Path $tmp '99-err.txt'
    $p99 = Start-Process -FilePath pwsh -ArgumentList @(
        '-NoProfile', '-File', $watch,
        '-JobId', $g99, '-ProcessId', "$deadPid", '-TempDir', $j99,
        '-ExpectedStartTimeUtc', '2020-01-01T00:00:00.000Z'
    ) -Wait -PassThru -NoNewWindow -RedirectStandardError $err99 -RedirectStandardOutput (Join-Path $tmp '99-out.txt')
    Assert-True ($p99.ExitCode -eq 99) "12j: exit 99 got $($p99.ExitCode)"
    Assert-True ($p5k.ExitCode -ne $p99.ExitCode) '12j: 22 distinto de 99'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $j99 "$g99.result.json") -PathType Leaf)) '12j: 99 sem result.json'
    Write-Host 'PASS 12j Watch 22 vs 99' -ForegroundColor Green

    # ===== KeepDays C-codex / C-shared =====
    Remove-Item Env:\XPZ_CODEX_DISABLE_KEEPDAYS -ErrorAction SilentlyContinue
    $jk = Join-Path $jobs 'keep'
    [IO.Directory]::CreateDirectory($jk) | Out-Null
    $gOld = [guid]::NewGuid().ToString('N')
    $oldLast = Join-Path $jk "$gOld.lastmsg.txt"
    $oldStream = Join-Path $jk "$gOld.stream.jsonl"
    Set-Content -LiteralPath $oldLast -Value 'old' -Encoding utf8
    Set-Content -LiteralPath $oldStream -Value '{}' -Encoding utf8
    $oldTime = (Get-Date).AddDays(-20)
    [IO.File]::SetLastWriteTime($oldLast, $oldTime)
    [IO.File]::SetLastWriteTime($oldStream, $oldTime)

    $gShared = [guid]::NewGuid().ToString('N')
    $sharedStream = Join-Path $jk "$gShared.stream.jsonl"
    Set-Content -LiteralPath $sharedStream -Value '{}' -Encoding utf8
    [IO.File]::SetLastWriteTime($sharedStream, $oldTime)

    Invoke-CodexJobsKeepDaysCleanup -TempDir $jk -KeepDays 3
    Assert-True (-not (Test-Path -LiteralPath $oldLast)) 'KeepDays: lastmsg orfao removido'
    Assert-True (-not (Test-Path -LiteralPath $oldStream)) 'KeepDays: stream do mesmo GUID removido'
    Assert-True (Test-Path -LiteralPath $sharedStream) 'KeepDays: C-shared sobrevive'
    $env:XPZ_CODEX_DISABLE_KEEPDAYS = '1'
    Write-Host 'PASS KeepDays C-codex/C-shared' -ForegroundColor Green

    # ===== Resolve helpers 4g misto =====
    $jm = Join-Path $jobs 'mixed'
    [IO.Directory]::CreateDirectory($jm) | Out-Null
    $gm = [guid]::NewGuid().ToString('N')
    @{ schemaVersion = 1; source = 'start-job'; pid = 12345 } | ConvertTo-Json | Set-Content (Join-Path $jm "$gm.request.json") -Encoding utf8
    @{ processStartTimeUtc = '2026-08-30T12:00:00.000Z' } | ConvertTo-Json | Set-Content (Join-Path $jm "$gm.identity.json") -Encoding utf8
    $rm = Resolve-CodexPidAndStartTime -TempDir $jm -JobId $gm
    Assert-True ($rm.divergence -eq $false) '4g: misto sem divergencia'
    Assert-True ([int]$rm.pid -eq 12345) '4g: pid do request'
    Assert-True ($rm.processStartTimeUtc -eq '2026-08-30T12:00:00.000Z') '4g: hora da identity'
    Write-Host 'PASS 4g misto' -ForegroundColor Green

    # ===== 5e morto com grupo sem lastmsg -> sem-texto =====
    $j5e = Join-Path $jobs 't5e'
    [IO.Directory]::CreateDirectory($j5e) | Out-Null
    $g5e = [guid]::NewGuid().ToString('N')
    Set-Content -LiteralPath (Join-Path $j5e "$g5e.stderr.txt") -Value '' -Encoding utf8
    $err5e = Join-Path $tmp '5e-err.txt'
    $out5e = Join-Path $tmp '5e-out.txt'
    $p5e = Start-Process -FilePath pwsh -ArgumentList @(
        '-NoProfile', '-File', $watch,
        '-JobId', $g5e, '-ProcessId', "$deadPid", '-TempDir', $j5e,
        '-ExpectedStartTimeUtc', '2020-01-01T00:00:00.000Z'
    ) -Wait -PassThru -NoNewWindow -RedirectStandardError $err5e -RedirectStandardOutput $out5e
    Assert-True ($p5e.ExitCode -eq 0) "5e: exit 0 got $($p5e.ExitCode)"
    $res5eRaw = Get-Content -LiteralPath (Join-Path $j5e "$g5e.result.json") -Raw -Encoding utf8
    $res5e = $res5eRaw | ConvertFrom-Json
    Assert-True ($res5e.status -eq 'sem-texto') '5e: status sem-texto'
    Assert-True ($res5eRaw -match '"finishedAt"\s*:\s*"[^"]+Z"') '5e: finishedAt UTC Z no JSON'
    Assert-True ($res5eRaw -match '"finishedAt"\s*:\s*"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z"') '5e: finishedAt fffZ'
    Write-Host 'PASS 5e sem-texto shape' -ForegroundColor Green

    # ===== 2c: path com 429 nas sentinelas; classificador usa prefixo (timeout, nao quota) =====
    # Lock do ALGORITMO de corte (prefixo antes de XPZ_CODEX_). A integracao no Parallel do
    # dispatcher e o caso 5b de Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1.
    $j2c = Join-Path $jobs 'ledger-with-429-in-name'
    [IO.Directory]::CreateDirectory($j2c) | Out-Null
    $env:XPZ_TEST_CODEX_FORCE_TIMEOUT = '1'
    $threw2c = $false; $msg2c = $null
    try {
        & $invoke -CodexExe $timeoutCmd -MessagePath $prompt -TempDir $j2c -TimeoutSec 2 -RetentionMode public | Out-Null
    } catch {
        $threw2c = $true
        $msg2c = [string]$_.Exception.Message
    }
    Remove-Item Env:\XPZ_TEST_CODEX_FORCE_TIMEOUT -ErrorAction SilentlyContinue
    Assert-True $threw2c '2c: throw'
    Assert-True ($msg2c -match '429') '2c: errorPath/mensagem contem 429 do path'
    $errNorm2c = $msg2c -replace "`r`n", "`n"
    $cut2c = -1
    if ($errNorm2c.StartsWith('XPZ_CODEX_')) { $cut2c = 0 }
    else {
        $idx2c = $errNorm2c.IndexOf("`nXPZ_CODEX_")
        if ($idx2c -ge 0) { $cut2c = $idx2c }
    }
    $msgClassificado2c = if ($cut2c -eq 0) { '' } elseif ($cut2c -gt 0) { $errNorm2c.Substring(0, $cut2c) } else { $errNorm2c }
    Assert-True ($msgClassificado2c -match 'excedeu' -and $msgClassificado2c -match 'foi encerrado') '2c: prefixo ainda e timeout'
    Assert-True ($msgClassificado2c -notmatch '429') '2c: msgClassificado sem path/429'
    $quotaPat = '(?i)(^|[^0-9])(402|429)([^0-9]|$)|quota|rate limit'
    Assert-True (-not ($msgClassificado2c -match 'BLOCK:' -and $msgClassificado2c -match $quotaPat)) '2c: nao classifica quota'
    Write-Host 'PASS 2c strip 429 no path -> timeout' -ForegroundColor Green

    # ===== 12g: timeout + rewrite falhou; excedeu/foi encerrado sobrevivem =====
    $j12g = Join-Path $jobs 't12g'
    $env:XPZ_TEST_CODEX_FORCE_TIMEOUT = '1'
    $env:XPZ_TEST_CODEX_INVOKE_FAIL_REWRITE = '1'
    $threw12g = $false; $msg12g = $null
    try {
        & $invoke -CodexExe $timeoutCmd -MessagePath $prompt -TempDir $j12g -TimeoutSec 2 -RetentionMode public | Out-Null
    } catch {
        $threw12g = $true
        $msg12g = [string]$_.Exception.Message
    }
    Remove-Item Env:\XPZ_TEST_CODEX_FORCE_TIMEOUT -ErrorAction SilentlyContinue
    Remove-Item Env:\XPZ_TEST_CODEX_INVOKE_FAIL_REWRITE -ErrorAction SilentlyContinue
    Assert-True $threw12g '12g: throw'
    Assert-True ($msg12g -match 'excedeu' -and $msg12g -match 'foi encerrado') '12g: timeout preservado apos rewrite fail'
    Assert-True ($msg12g -match 'falha ao gravar request.json') '12g: BLOCK rewrite anexado'
    Write-Host 'PASS 12g timeout+rewrite fail' -ForegroundColor Green

    # ===== 5l: vivo + hora valida + pasta vazia -> apos morte, AVISO exit 0 sem result =====
    $j5l = Join-Path $jobs 't5l-empty'
    [IO.Directory]::CreateDirectory($j5l) | Out-Null
    $g5l = [guid]::NewGuid().ToString('N')
    $sleeper = Start-Process -FilePath pwsh -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 3') -PassThru -WindowStyle Hidden
    $st5l = $sleeper.StartTime
    if ($st5l.Kind -ne [DateTimeKind]::Utc) { $st5l = $st5l.ToUniversalTime() }
    $hora5l = Format-CodexUtcTimestamp -Value $st5l
    $err5l = Join-Path $tmp '5l-err.txt'
    $out5l = Join-Path $tmp '5l-out.txt'
    $p5l = Start-Process -FilePath pwsh -ArgumentList @(
        '-NoProfile', '-File', $watch,
        '-JobId', $g5l, '-ProcessId', "$($sleeper.Id)", '-TempDir', $j5l,
        '-ExpectedStartTimeUtc', $hora5l
    ) -Wait -PassThru -NoNewWindow -RedirectStandardError $err5l -RedirectStandardOutput $out5l
    Assert-True ($p5l.ExitCode -eq 0) "5l: exit 0 got $($p5l.ExitCode)"
    $e5l = Get-Content -LiteralPath $err5l -Raw -ErrorAction SilentlyContinue
    Assert-True ($e5l -match 'AVISO: grupo Codex ausente') '5l: AVISO grupo ausente'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $j5l "$g5l.result.json"))) '5l: sem result.json'
    Write-Host 'PASS 5l vivo+hora+pasta vazia' -ForegroundColor Green

    # ===== 12e: RoundId de fallback usa sufixo -fb-* (recuperacao por glob) =====
    $dispSrc = Get-Content -LiteralPath (Join-Path $scriptsDir 'Invoke-LlmDelegatePanelDispatch.ps1') -Raw -Encoding utf8
    Assert-True ($dispSrc -match 'RoundId\s*=\s*"\$RoundId-fb-\$\(\$rec\.index\)-\$fbIdx"') '12e: RoundId-fb-i-j no dispatcher'
    Write-Host 'PASS 12e fallback path -fb-*' -ForegroundColor Green

    # ===== 12f: marcador backend-parity isola unidade; bullet seguinte e outra =====
    $probeMd = Join-Path $tmp 'parity-probe.md'
    @(
        '<!-- backend-parity: ignore -->',
        'Paragrafo novo cita Codex e Claude Code nesta unidade isolada.',
        '',
        '- Bullet seguinte cita Codex e Gemini e e outra unidade.'
    ) -join "`n" | Set-Content -LiteralPath $probeMd -Encoding utf8 -NoNewline
    # Parser minimo alinhado ao gate: linha em branco fecha unidade; bullet inicia unidade nova.
    $probeLines = [System.IO.File]::ReadAllLines($probeMd)
    $units = [System.Collections.Generic.List[object]]::new()
    $buf = [System.Collections.Generic.List[string]]::new()
    $startU = 1
    for ($pi = 0; $pi -lt $probeLines.Count; $pi++) {
        $pl = $probeLines[$pi]
        if ([string]::IsNullOrWhiteSpace($pl)) {
            if ($buf.Count -gt 0) {
                $units.Add([pscustomobject]@{ RawLines = @($buf) })
                $buf.Clear()
            }
            continue
        }
        if ($pl -match '^\s*[-*+]\s+') {
            if ($buf.Count -gt 0) {
                $units.Add([pscustomobject]@{ RawLines = @($buf) })
                $buf.Clear()
            }
        }
        if ($buf.Count -eq 0) { $startU = $pi + 1 }
        $buf.Add($pl)
    }
    if ($buf.Count -gt 0) { $units.Add([pscustomobject]@{ RawLines = @($buf) }) }
    Assert-True ($units.Count -ge 2) "12f: esperava >=2 unidades, got $($units.Count)"
    $u0 = ($units[0].RawLines -join "`n")
    $u1 = ($units[1].RawLines -join "`n")
    Assert-True ($u0 -match 'backend-parity:\s*ignore') '12f: marcador na 1a unidade'
    Assert-True ($u1 -notmatch 'backend-parity:\s*ignore') '12f: bullet seguinte sem marcador'
    $res999 = Select-String -Path (Join-Path (Split-Path $scriptsDir -Parent) '999-ideias-pendentes.md') `
        -Pattern 'Residuais da captura duravel Codex|Residuais da captura durável Codex' |
        Select-Object -First 1
    Assert-True ($null -ne $res999) '12f: entrada residual no 999'
    $lineBefore = (Get-Content -LiteralPath $res999.Path -Encoding utf8)[$res999.LineNumber - 2]
    Assert-True ($lineBefore -match 'backend-parity:\s*ignore') '12f: marcador imediatamente antes do titulo residual 999'
    $tr14 = Select-String -Path (Join-Path (Split-Path $scriptsDir -Parent) '14-revisao-pre-push-reforcada.md') `
        -Pattern 'Transporte Codex vs ancora nativa|Transporte Codex vs âncora nativa' |
        Select-Object -First 1
    Assert-True ($null -ne $tr14) '12f: paragrafo transporte no 14'
    $lineBefore14 = (Get-Content -LiteralPath $tr14.Path -Encoding utf8)[$tr14.LineNumber - 2]
    Assert-True ($lineBefore14 -match 'backend-parity:\s*ignore') '12f: marcador na unidade do paragrafo 14'
    Write-Host 'PASS 12f marcador de paridade' -ForegroundColor Green

    Write-Output 'OK: Test-CodexDurableCaptureSelfTest.ps1'
}
finally {
    if ($null -eq $prevDisable) {
        Remove-Item Env:\XPZ_CODEX_DISABLE_KEEPDAYS -ErrorAction SilentlyContinue
    } else {
        $env:XPZ_CODEX_DISABLE_KEEPDAYS = $prevDisable
    }
    if ($null -eq $prevJobsDir) {
        Remove-Item Env:\XPZ_CODEX_JOBS_DIR -ErrorAction SilentlyContinue
    } else {
        $env:XPZ_CODEX_JOBS_DIR = $prevJobsDir
    }
    Remove-Item Env:\XPZ_TEST_CODEX_START_FAIL_SPAWN -ErrorAction SilentlyContinue
    Remove-Item Env:\XPZ_TEST_CODEX_START_FAIL_REQUEST_REWRITE -ErrorAction SilentlyContinue
    Remove-Item Env:\XPZ_TEST_CODEX_INVOKE_FAIL_REWRITE -ErrorAction SilentlyContinue
    Remove-Item Env:\XPZ_TEST_CODEX_INVOKE_UNEXPECTED -ErrorAction SilentlyContinue
    Remove-Item Env:\XPZ_TEST_CODEX_FORCE_TIMEOUT -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
