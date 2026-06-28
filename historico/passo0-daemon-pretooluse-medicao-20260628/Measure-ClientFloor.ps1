# Measure-ClientFloor.ps1 - PROTOTIPO DESCARTAVEL (passo 0b: piso de startup do cliente).
# Mede o custo puro de subir cada runtime de cliente candidato, sem I/O nem conexao.
# E o novo gargalo por-invocacao (o daemon resolve o servidor; o cliente nasce a cada tool).
[CmdletBinding()]
param([int] $Iterations = 120, [int] $Warmup = 10)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad'
$aotExe = Join-Path $root 'aot-floor\bin\x64\Release\net8.0\win-x64\publish\ptu-client-floor.exe'
$pyFloor = Join-Path $root 'py-floor.py'
$pyExe = (Get-Command python).Source
if (-not (Test-Path -LiteralPath $aotExe)) { throw "exe AOT nao encontrado: $aotExe" }

function Invoke-Once {
    param([string] $File, [string[]] $ArgList)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $File
    foreach ($a in $ArgList) { [void]$psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = [System.Diagnostics.Process]::Start($psi)
    [void]$p.StandardOutput.ReadToEnd()
    [void]$p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $sw.Stop()
    return $sw.Elapsed.TotalMilliseconds
}

function Measure-Scenario {
    param([string] $Name, [string] $File, [string[]] $ArgList, [int] $Iter, [int] $Warm)
    for ($i = 0; $i -lt $Warm; $i++) { [void](Invoke-Once -File $File -ArgList $ArgList) }
    $samples = [System.Collections.Generic.List[double]]::new()
    for ($i = 0; $i -lt $Iter; $i++) { $samples.Add((Invoke-Once -File $File -ArgList $ArgList)) }
    $sorted = @($samples | Sort-Object)
    function Pct { param([double[]] $S, [double] $P)
        $idx = [int][math]::Ceiling(($P / 100.0) * $S.Count) - 1
        if ($idx -lt 0) { $idx = 0 }; if ($idx -ge $S.Count) { $idx = $S.Count - 1 }
        return $S[$idx]
    }
    return [pscustomobject][ordered]@{
        scenario = $Name
        n    = $sorted.Count
        min  = [math]::Round($sorted[0], 1)
        p50  = [math]::Round((Pct $sorted 50), 1)
        p90  = [math]::Round((Pct $sorted 90), 1)
        p95  = [math]::Round((Pct $sorted 95), 1)
        p99  = [math]::Round((Pct $sorted 99), 1)
        max  = [math]::Round($sorted[$sorted.Count - 1], 1)
        mean = [math]::Round(($sorted | Measure-Object -Average).Average, 1)
    }
}

$results = @()
$results += Measure-Scenario -Name 'aot-client-floor'    -File $aotExe -ArgList @()                -Iter $Iterations -Warm $Warmup
$results += Measure-Scenario -Name 'python-client-floor' -File $pyExe  -ArgList @('-I', $pyFloor)   -Iter $Iterations -Warm $Warmup

Write-Host "PISO DE STARTUP DO CLIENTE (ms wall-clock por invocacao):" -ForegroundColor Green
$results | Format-Table -AutoSize | Out-String | Write-Host
