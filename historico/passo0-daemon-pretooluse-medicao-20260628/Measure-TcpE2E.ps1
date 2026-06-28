# Measure-TcpE2E.ps1 - PROTOTIPO DESCARTAVEL (passo 0b: fallback TCP+Python).
# Mede o e2e do fallback (cliente Python + TCP loopback + token), com daemon de python
# persistente (mesma decisao do primario). Cliente cold a cada invocacao. Sem exclusao Defender.
[CmdletBinding()]
param([int] $Iterations = 120, [int] $Warmup = 10)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scratch = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad'
$repo = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills'
$tcpClient = Join-Path $scratch 'tcp-client.py'
$daemon = Join-Path $scratch 'daemon-tcp-persistpy.ps1'
$persistPy = Join-Path $scratch 'shlex-persistent.py'
$pythonExe = (Get-Command python).Source
$pwshExe = (Get-Command pwsh).Source

$readyFile = Join-Path $scratch 'daemon-ready-tcp.txt'
$discFile = Join-Path $scratch 'tcp-discovery.json'
$dOut = Join-Path $scratch 'daemon-out-tcp.txt'
$dErr = Join-Path $scratch 'daemon-err-tcp.txt'
foreach ($f in @($readyFile, $discFile)) { if (Test-Path $f) { Remove-Item $f -Force } }

$jsonDefer = '{"tool_name":"Bash","cwd":"C:\\Dev\\Knowledge\\GeneXus-XPZ-Skills","tool_input":{"command":"npm run build"}}'
$jsonAllow = '{"tool_name":"Bash","cwd":"C:\\Dev\\Knowledge\\GeneXus-XPZ-Skills","tool_input":{"command":"git status"}}'

Write-Host "Subindo daemon TCP..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $pwshExe `
    -ArgumentList @('-NoProfile', '-NoLogo', '-NonInteractive', '-File', $daemon, '-DiscoveryFile', $discFile, '-ReadyFile', $readyFile, '-RepoRoot', $repo, '-PersistPy', $persistPy) `
    -PassThru -WindowStyle Hidden -RedirectStandardOutput $dOut -RedirectStandardError $dErr

try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path $readyFile) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if (-not (Test-Path $readyFile)) {
        $errTxt = if (Test-Path $dErr) { Get-Content -Raw $dErr } else { '(sem stderr)' }
        throw "daemon TCP nao ficou ready em 15s. stderr:`n$errTxt"
    }
    $disc = Get-Content -Raw $discFile
    Write-Host "Daemon TCP ready (PID $($proc.Id)); discovery=$disc" -ForegroundColor Green

    function Invoke-Client {
        param([string] $Stdin)
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $pythonExe
        [void]$psi.ArgumentList.Add('-I'); [void]$psi.ArgumentList.Add($tcpClient)
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.StandardInput.Write($Stdin); $p.StandardInput.Close()
        $out = $p.StandardOutput.ReadToEnd()
        [void]$p.StandardError.ReadToEnd()
        $p.WaitForExit()
        $sw.Stop()
        return [pscustomobject]@{ Ms = $sw.Elapsed.TotalMilliseconds; Out = $out }
    }

    function Measure-Scenario {
        param([string] $Name, [string] $Stdin, [int] $Iter, [int] $Warm)
        $lastOut = $null
        for ($i = 0; $i -lt $Warm; $i++) { $lastOut = (Invoke-Client -Stdin $Stdin).Out }
        $samples = [System.Collections.Generic.List[double]]::new()
        for ($i = 0; $i -lt $Iter; $i++) { $r = Invoke-Client -Stdin $Stdin; $samples.Add($r.Ms); $lastOut = $r.Out }
        $sorted = @($samples | Sort-Object)
        function Pct { param([double[]] $S, [double] $P)
            $idx = [int][math]::Ceiling(($P / 100.0) * $S.Count) - 1
            if ($idx -lt 0) { $idx = 0 }; if ($idx -ge $S.Count) { $idx = $S.Count - 1 }
            return $S[$idx]
        }
        return [pscustomobject][ordered]@{
            scenario = $Name; n = $sorted.Count
            min = [math]::Round($sorted[0], 1); p50 = [math]::Round((Pct $sorted 50), 1)
            p90 = [math]::Round((Pct $sorted 90), 1); p95 = [math]::Round((Pct $sorted 95), 1)
            p99 = [math]::Round((Pct $sorted 99), 1); max = [math]::Round($sorted[$sorted.Count - 1], 1)
            mean = [math]::Round(($sorted | Measure-Object -Average).Average, 1); sampleOut = $lastOut.Trim()
        }
    }

    $results = @()
    $results += Measure-Scenario -Name 'tcp-defer-comum'    -Stdin $jsonDefer -Iter $Iterations -Warm $Warmup
    $results += Measure-Scenario -Name 'tcp-allow-candidate' -Stdin $jsonAllow -Iter $Iterations -Warm $Warmup

    Write-Host ""
    Write-Host "E2E FALLBACK TCP+Python (ms, cliente cold, sem exclusao):" -ForegroundColor Green
    $results | Select-Object scenario, n, min, p50, p90, p95, p99, max, mean | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "Sanity:" -ForegroundColor DarkGray
    foreach ($r in $results) { Write-Host ("  [{0}] {1}" -f $r.scenario, $r.sampleOut) }
}
finally {
    if ($proc -and -not $proc.HasExited) { $proc.Kill() }
}
