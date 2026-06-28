# Measure-PipeE2E.ps1 - PROTOTIPO DESCARTAVEL (passo 0b: e2e do primario pipe+NativeAOT).
# Sobe o daemon persistente, espera ready, e mede o cliente AOT cold (1 por invocacao)
# fazendo round-trip real pelo named pipe. Separa defer-comum (sem python) de allow-candidato.
[CmdletBinding()]
param([int] $Iterations = 120, [int] $Warmup = 10)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scratch = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad'
$repo = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills'
$clientExe = Join-Path $scratch 'aot\bin\x64\Release\net8.0\win-x64\publish\ptu-client-pipe.exe'
$daemon = Join-Path $scratch 'daemon-pipe.ps1'
$pwshExe = (Get-Command pwsh).Source
if (-not (Test-Path -LiteralPath $clientExe)) { throw "cliente AOT nao encontrado: $clientExe" }

$pipeName = 'ptu-daemon-proto'
$readyFile = Join-Path $scratch 'daemon-ready.txt'
$dOut = Join-Path $scratch 'daemon-out.txt'
$dErr = Join-Path $scratch 'daemon-err.txt'
if (Test-Path $readyFile) { Remove-Item $readyFile -Force }

$jsonDefer = '{"tool_name":"Bash","cwd":"C:\\Dev\\Knowledge\\GeneXus-XPZ-Skills","tool_input":{"command":"npm run build"}}'
$jsonAllow = '{"tool_name":"Bash","cwd":"C:\\Dev\\Knowledge\\GeneXus-XPZ-Skills","tool_input":{"command":"git status"}}'

Write-Host "Subindo daemon..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $pwshExe `
    -ArgumentList @('-NoProfile', '-NoLogo', '-NonInteractive', '-File', $daemon, '-PipeName', $pipeName, '-ReadyFile', $readyFile, '-RepoRoot', $repo) `
    -PassThru -WindowStyle Hidden -RedirectStandardOutput $dOut -RedirectStandardError $dErr

try {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while (-not (Test-Path $readyFile) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
    if (-not (Test-Path $readyFile)) {
        $errTxt = if (Test-Path $dErr) { Get-Content -Raw $dErr } else { '(sem stderr)' }
        throw "daemon nao ficou ready em 15s. stderr:`n$errTxt"
    }
    Write-Host "Daemon ready (PID $($proc.Id))." -ForegroundColor Green

    function Invoke-Client {
        param([string] $Stdin)
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $clientExe
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
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
    $results += Measure-Scenario -Name 'e2e-defer-comum'     -Stdin $jsonDefer -Iter $Iterations -Warm $Warmup
    $results += Measure-Scenario -Name 'e2e-allow-candidate'  -Stdin $jsonAllow -Iter $Iterations -Warm $Warmup

    Write-Host ""
    Write-Host "E2E PIPE+NativeAOT (ms wall-clock por invocacao, cliente cold):" -ForegroundColor Green
    $results | Select-Object scenario, n, min, p50, p90, p95, p99, max, mean | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "Sanity (decisao emitida pelo cliente):" -ForegroundColor DarkGray
    foreach ($r in $results) { Write-Host ("  [{0}] {1}" -f $r.scenario, $r.sampleOut) }
}
finally {
    if ($proc -and -not $proc.HasExited) { $proc.Kill() }
}
