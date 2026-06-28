# Measure-Robust1k.ps1 - PROTOTIPO DESCARTAVEL (passo 0b #4: re-medicao robusta caprichada).
# 1000 iter + 50 warmup. Por iteracao mede, INTERCALADO (mesmas condicoes instantaneas do host):
#   floor (aot-floor, return 0; sem stdin) -> e2e-defer (pipe) -> e2e-allow (pipe).
# Permite SUBTRACAO PAREADA (overhead = e2e - floor na MESMA iteracao) p/ cravar o "~2 ms".
# Captura a SERIE TEMPORAL completa em CSV (iter,scenario,ms) p/ histograma + analise de rajada.
# Daemon = pipe + python persistente. High prio no harness/daemon/cliente. NAO e codigo final.
[CmdletBinding()]
param([int] $Iterations = 1000, [int] $Warmup = 50)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scratch = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad'
$repo = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills'
$aotFloor = Join-Path $scratch 'aot-floor\bin\x64\Release\net8.0\win-x64\publish\ptu-client-floor.exe'
$pipeClient = Join-Path $scratch 'aot\bin\x64\Release\net8.0\win-x64\publish\ptu-client-pipe.exe'
$daemon = Join-Path $scratch 'daemon-pipe-persistpy.ps1'
$persistPy = Join-Path $scratch 'shlex-persistent.py'
$pwshExe = (Get-Command pwsh).Source
$csvPath = Join-Path $scratch 'robust1k-series.csv'
foreach ($f in @($aotFloor, $pipeClient, $daemon, $persistPy)) { if (-not (Test-Path -LiteralPath $f)) { throw "ausente: $f" } }

$pipeName = 'ptu-daemon-proto'
$readyFile = Join-Path $scratch 'daemon-ready-r1k.txt'
$dOut = Join-Path $scratch 'daemon-out-r1k.txt'
$dErr = Join-Path $scratch 'daemon-err-r1k.txt'
if (Test-Path $readyFile) { Remove-Item $readyFile -Force }

$jsonDefer = '{"tool_name":"Bash","cwd":"C:\\Dev\\Knowledge\\GeneXus-XPZ-Skills","tool_input":{"command":"npm run build"}}'
$jsonAllow = '{"tool_name":"Bash","cwd":"C:\\Dev\\Knowledge\\GeneXus-XPZ-Skills","tool_input":{"command":"git status"}}'

try { [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch { }

Write-Host "Subindo daemon (pipe + python persistente, High)..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $pwshExe `
    -ArgumentList @('-NoProfile', '-NoLogo', '-NonInteractive', '-File', $daemon, '-PipeName', $pipeName, '-ReadyFile', $readyFile, '-RepoRoot', $repo, '-PersistPy', $persistPy) `
    -PassThru -WindowStyle Hidden -RedirectStandardOutput $dOut -RedirectStandardError $dErr
try { $proc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch { }

try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path $readyFile) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if (-not (Test-Path $readyFile)) {
        $errTxt = if (Test-Path $dErr) { Get-Content -Raw $dErr } else { '(sem stderr)' }
        throw "daemon nao ficou ready em 15s. stderr:`n$errTxt"
    }
    Write-Host "Daemon ready (PID $($proc.Id))." -ForegroundColor Green

    function Invoke-Proc {
        param([string] $File, [string] $Stdin)  # $Stdin = $null para o floor
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $File
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.RedirectStandardInput = ($null -ne $Stdin)
        $psi.CreateNoWindow = $true
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $p = [System.Diagnostics.Process]::Start($psi)
        try { $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch { }
        if ($null -ne $Stdin) { $p.StandardInput.Write($Stdin); $p.StandardInput.Close() }
        [void]$p.StandardOutput.ReadToEnd()
        [void]$p.StandardError.ReadToEnd()
        $p.WaitForExit()
        $sw.Stop()
        return $sw.Elapsed.TotalMilliseconds
    }

    # Warmup intercalado
    for ($i = 0; $i -lt $Warmup; $i++) {
        [void](Invoke-Proc -File $aotFloor -Stdin $null)
        [void](Invoke-Proc -File $pipeClient -Stdin $jsonDefer)
        [void](Invoke-Proc -File $pipeClient -Stdin $jsonAllow)
    }

    $floor = [System.Collections.Generic.List[double]]::new()
    $defer = [System.Collections.Generic.List[double]]::new()
    $allow = [System.Collections.Generic.List[double]]::new()
    $rows = [System.Collections.Generic.List[string]]::new()
    $rows.Add('iter,scenario,ms')

    $tStart = [DateTime]::UtcNow
    for ($i = 0; $i -lt $Iterations; $i++) {
        $mF = Invoke-Proc -File $aotFloor -Stdin $null
        $mD = Invoke-Proc -File $pipeClient -Stdin $jsonDefer
        $mA = Invoke-Proc -File $pipeClient -Stdin $jsonAllow
        $floor.Add($mF); $defer.Add($mD); $allow.Add($mA)
        $rows.Add(('{0},floor,{1}' -f $i, [math]::Round($mF, 3)))
        $rows.Add(('{0},defer,{1}' -f $i, [math]::Round($mD, 3)))
        $rows.Add(('{0},allow,{1}' -f $i, [math]::Round($mA, 3)))
        if ((($i + 1) % 200) -eq 0) { Write-Host ("  ...{0}/{1}" -f ($i + 1), $Iterations) -ForegroundColor DarkGray }
    }
    $elapsed = ([DateTime]::UtcNow - $tStart).TotalSeconds

    [System.IO.File]::WriteAllLines($csvPath, $rows)

    function Pct { param([double[]] $S, [double] $P)
        $idx = [int][math]::Ceiling(($P / 100.0) * $S.Count) - 1
        if ($idx -lt 0) { $idx = 0 }; if ($idx -ge $S.Count) { $idx = $S.Count - 1 }
        return $S[$idx]
    }
    function Stats { param([string] $Name, [System.Collections.Generic.List[double]] $L)
        $s = @($L | Sort-Object)
        $over80 = @($L | Where-Object { $_ -gt 80 }).Count
        $over150 = @($L | Where-Object { $_ -gt 150 }).Count
        return [pscustomobject][ordered]@{
            scenario = $Name; n = $s.Count
            min = [math]::Round($s[0], 1); p50 = [math]::Round((Pct $s 50), 1); p75 = [math]::Round((Pct $s 75), 1)
            p90 = [math]::Round((Pct $s 90), 1); p95 = [math]::Round((Pct $s 95), 1); p99 = [math]::Round((Pct $s 99), 1)
            p999 = [math]::Round((Pct $s 99.9), 1); max = [math]::Round($s[$s.Count - 1], 1); mean = [math]::Round(($L | Measure-Object -Average).Average, 1)
            'gt80%' = [math]::Round(100.0 * $over80 / $s.Count, 1); 'gt150' = $over150
        }
    }

    # Subtracao pareada (overhead = e2e - floor na MESMA iteracao)
    $ovD = [System.Collections.Generic.List[double]]::new()
    $ovA = [System.Collections.Generic.List[double]]::new()
    for ($i = 0; $i -lt $Iterations; $i++) { $ovD.Add($defer[$i] - $floor[$i]); $ovA.Add($allow[$i] - $floor[$i]) }
    function PairStat { param([string] $Name, [System.Collections.Generic.List[double]] $L)
        $s = @($L | Sort-Object)
        return [pscustomobject][ordered]@{
            par = $Name; mediana = [math]::Round((Pct $s 50), 2); p95 = [math]::Round((Pct $s 95), 2)
            media = [math]::Round(($L | Measure-Object -Average).Average, 2); min = [math]::Round($s[0], 2); max = [math]::Round($s[$s.Count - 1], 2)
        }
    }

    Write-Host ""
    Write-Host ("ROBUSTO 1k (intercalado, High prio) - {0:N0}s total:" -f $elapsed) -ForegroundColor Green
    @((Stats 'floor (aot, no-op)' $floor), (Stats 'e2e-defer (pipe)' $defer), (Stats 'e2e-allow (pipe)' $allow)) |
        Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "SUBTRACAO PAREADA - overhead do daemon sobre o floor, MESMA iteracao (ms):" -ForegroundColor Green
    @((PairStat 'defer - floor' $ovD), (PairStat 'allow - floor' $ovA)) | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host ("Serie temporal completa: {0}" -f $csvPath) -ForegroundColor DarkGray
}
finally {
    if ($proc -and -not $proc.HasExited) { $proc.Kill() }
}
