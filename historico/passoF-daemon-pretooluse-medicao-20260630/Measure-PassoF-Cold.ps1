#requires -Version 7.4
<#
.SYNOPSIS
PASSO F - frio sob contencao (F3). PROTOTIPO DESCARTAVEL. Usa o CLIENTE e a coordenacao REAIS
(o cold-path do ptu-client.exe disputa o guard mutex e sobe o daemon DETACHED). NAO altera codigo
de producao, NAO liga enforce nem o fio.

Mede, com o daemon PARADO no arranque:
  - coldReadyMs (spawn -> pipe conectavel), 3 amostras;
  - loserSpawns SIMULTANEO (burst K disparado junto -> esperado ~0): so o vencedor do guard sobe daemon;
  - loserSpawns ESCALONADO (K espacados por ~guardWindow -> teto ceil(coldReadyMs/guardWindow)+margem):
    o guard libera antes do pipe ficar pronto, entao clientes tardios re-sobem daemons que PERDEM o
    singleton e saem cedo (loser daemons);
  - pico de RSS (WorkingSet) e vida agregada dos daemons sob burst K.

loserSpawns = (daemons distintos observados) - 1. Conta processos pwsh cuja CommandLine referencia o
Daemon.ps1 do DEPLOY (exclui '-Command' e o proprio processo de inspecao -- quirk do host).
#>
[CmdletBinding()]
param(
    [int] $K = 20,
    [int] $StaggerMs = 50
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo    = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills'
$scripts = Join-Path $repo 'scripts'
$exeSrc  = Join-Path $repo 'ptu-native\client\bin\x64\Release\net8.0\win-x64\publish\ptu-client.exe'
$dllSrc  = Join-Path $repo 'ptu-native\lib\bin\Release\net8.0\PtuCanon.dll'
$idScript = Join-Path $scripts 'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1'
$pwshExe  = (Get-Command pwsh).Source

foreach ($f in @($exeSrc, $dllSrc, $idScript)) { if (-not (Test-Path -LiteralPath $f)) { throw "ausente: $f" } }

$deployScripts = @(
    'ClaudeCodePreToolUseSafeAllowDaemon.ps1',
    'ClaudeCodePreToolUseSafeAllowSupport.ps1',
    'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1',
    'Get-ClaudeCodeBashSafeSegments.py',
    'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
)
function New-PtuDeploy {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-passoFcold-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Copy-Item -LiteralPath $exeSrc -Destination (Join-Path $dir 'ptu-client.exe') -Force
    Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $dir 'PtuCanon.dll') -Force
    foreach ($f in $deployScripts) { Copy-Item -LiteralPath (Join-Path $scripts $f) -Destination (Join-Path $dir $f) -Force }
    [System.IO.File]::WriteAllText((Join-Path $dir '.ptu-safe-allow-root'), '')
    return $dir
}
function Test-PipeReady {
    param([string] $PipeName)
    foreach ($f in [System.IO.Directory]::GetFiles('\\.\pipe\')) {
        if ([System.IO.Path]::GetFileName($f) -ceq $PipeName) { return $true }
    }
    return $false
}
function Get-DaemonProcs {
    # processos pwsh do daemon DESTE deploy. Exclui '-Command' (inspecao) e o proprio PID.
    param([string] $DaemonPath)
    $self = $PID
    $procs = Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" -ErrorAction SilentlyContinue
    $out = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $procs) {
        if ($p.ProcessId -eq $self) { continue }
        $cl = [string]$p.CommandLine
        if ([string]::IsNullOrEmpty($cl)) { continue }
        if ($cl -like '*-Command*') { continue }
        if ($cl -like ('*' + $DaemonPath + '*')) { $out.Add($p) }
    }
    return $out
}
function Stop-DaemonProcs {
    param([string] $DaemonPath)
    foreach ($p in (Get-DaemonProcs -DaemonPath $DaemonPath)) {
        try { $pp = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue; if ($pp) { $pp.Kill() } } catch {}
    }
}

# NB: NAO passar scriptblock entre runspaces (& $using:fb em -Parallel lanca "cannot be invoked in a
# different runspace"). A logica de disparo do cliente real e' INLINADA em cada modo.

. $idScript
$deploy = New-PtuDeploy
$identity = Get-PtuIdentity -StartDirectory $deploy -DllPath (Join-Path $deploy 'PtuCanon.dll') -Roots @($deploy)
if ($null -eq $identity) { throw "identidade nula" }
$pipeName = $identity.Names.PipeName
$exeF = Join-Path $deploy 'ptu-client.exe'
$deployDaemon = Join-Path $deploy 'ClaudeCodePreToolUseSafeAllowDaemon.ps1'
$json = '{"tool_name":"Bash","cwd":"' + ($deploy -replace '\\', '\\') + '","tool_input":{"command":"git status"}}'

function Measure-Burst {
    # Dispara K clientes (simultaneo ou escalonado), poll-amostra os daemons, retorna metricas.
    param([string] $Mode, [int] $StaggerMs)
    Stop-DaemonProcs -DaemonPath $deployDaemon
    Start-Sleep -Milliseconds 400

    $seen = @{}    # pid -> @{ First; Last; PeakRss }
    $swPoll = [System.Diagnostics.Stopwatch]::StartNew()

    if ($Mode -eq 'simultaneo') {
        $job = 1..$K | ForEach-Object -ThrottleLimit $K -Parallel {
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = $using:exeF
            $psi.UseShellExecute = $false
            $psi.RedirectStandardInput = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            $psi.Environment['PTU_SAFE_ALLOW_ROOTS'] = $using:deploy
            $p = [System.Diagnostics.Process]::Start($psi)
            $p.StandardInput.Write($using:json); $p.StandardInput.Close()
            $out = $p.StandardOutput.ReadToEnd()
            [void]$p.StandardError.ReadToEnd()
            $p.WaitForExit(15000) | Out-Null
            try { ($out | ConvertFrom-Json).hookSpecificOutput.permissionDecision } catch { '<err>' }
        } -AsJob
    } else {
        # Escalonado: inicia K clientes espacados por StaggerMs SEM esperar (cada cliente roda detached
        # e faz seu cold-path). Inlinado num ThreadJob; sem passar scriptblock entre runspaces.
        $job = Start-ThreadJob -ScriptBlock {
            param($K, $StaggerMs, $exe, $json, $dep)
            for ($i = 0; $i -lt $K; $i++) {
                $psi = [System.Diagnostics.ProcessStartInfo]::new()
                $psi.FileName = $exe
                $psi.UseShellExecute = $false
                $psi.RedirectStandardInput = $true
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true
                $psi.Environment['PTU_SAFE_ALLOW_ROOTS'] = $dep
                $p = [System.Diagnostics.Process]::Start($psi)
                $p.StandardInput.Write($json); $p.StandardInput.Close()
                Start-Sleep -Milliseconds $StaggerMs
            }
            Start-Sleep -Seconds 3
        } -ArgumentList $K, $StaggerMs, $exeF, $json, $deploy
    }

    # Poll ~4s amostrando daemons
    while ($swPoll.ElapsedMilliseconds -lt 4500) {
        foreach ($p in (Get-DaemonProcs -DaemonPath $deployDaemon)) {
            $id = [int]$p.ProcessId
            $rss = [long]$p.WorkingSetSize
            $now = [double]$swPoll.Elapsed.TotalMilliseconds
            if (-not $seen.ContainsKey($id)) { $seen[$id] = @{ First = $now; Last = $now; PeakRss = $rss } }
            else { $seen[$id].Last = $now; if ($rss -gt $seen[$id].PeakRss) { $seen[$id].PeakRss = $rss } }
        }
        Start-Sleep -Milliseconds 25
    }
    [void](Wait-Job -Job $job -Timeout 20000)
    $decisions = @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
    Remove-Job -Job $job -Force -ErrorAction SilentlyContinue

    $pipeUp = Test-PipeReady -PipeName $pipeName
    $daemons = $seen.Count
    $peakRss = if ($daemons -gt 0) { ($seen.Values | ForEach-Object { $_.PeakRss } | Measure-Object -Maximum).Maximum } else { 0 }
    $aggLife = 0.0
    foreach ($v in $seen.Values) { $aggLife += ($v.Last - $v.First) }

    Stop-DaemonProcs -DaemonPath $deployDaemon
    Start-Sleep -Milliseconds 300

    return [pscustomobject][ordered]@{
        mode        = $Mode
        K           = $K
        daemonsObs  = $daemons
        loserSpawns = [math]::Max(0, $daemons - 1)
        peakRssMB   = [math]::Round($peakRss / 1MB, 1)
        aggLifeMs   = [math]::Round($aggLife, 0)
        pipeUp      = $pipeUp
        decisions   = ($decisions -join ',')
    }
}

try {
    # coldReadyMs (3 amostras): spawn daemon direto, mede ate pipe; mata.
    $env:PTU_SAFE_ALLOW_ROOTS = $deploy
    $colds = [System.Collections.Generic.List[double]]::new()
    for ($s = 0; $s -lt 3; $s++) {
        Stop-DaemonProcs -DaemonPath $deployDaemon
        Start-Sleep -Milliseconds 300
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $dp = Start-Process -FilePath $pwshExe -ArgumentList @('-NoProfile','-NoLogo','-NonInteractive','-File',$deployDaemon) -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $deploy "d$s.out") -RedirectStandardError (Join-Path $deploy "d$s.err")
        while ($sw.ElapsedMilliseconds -lt 30000 -and -not (Test-PipeReady -PipeName $pipeName)) { Start-Sleep -Milliseconds 10 }
        $colds.Add([double]$sw.Elapsed.TotalMilliseconds)
        try { if (-not $dp.HasExited) { $dp.Kill() } } catch {}
        Stop-DaemonProcs -DaemonPath $deployDaemon
        Start-Sleep -Milliseconds 300
    }
    $coldMean = [math]::Round((($colds | Measure-Object -Average).Average), 0)
    $coldMax  = [math]::Round((($colds | Measure-Object -Maximum).Maximum), 0)
    Write-Host ("coldReadyMs (3 amostras): {0} | media {1} max {2}" -f (($colds | ForEach-Object { [math]::Round($_,0) }) -join ', '), $coldMean, $coldMax) -ForegroundColor Green

    $teto = [math]::Ceiling($coldMax / $StaggerMs) + 2
    Write-Host ("teto loserSpawns escalonado = ceil(coldMax/{0})+2 = {1}" -f $StaggerMs, $teto) -ForegroundColor DarkGray

    $rSim = Measure-Burst -Mode 'simultaneo' -StaggerMs 0
    $rStg = Measure-Burst -Mode 'escalonado' -StaggerMs $StaggerMs

    Write-Host ""
    Write-Host ("BURST K={0}:" -f $K) -ForegroundColor Green
    @($rSim, $rStg) | Format-Table mode, K, daemonsObs, loserSpawns, peakRssMB, aggLifeMs, pipeUp -AutoSize | Out-String | Write-Host
    Write-Host ("simultaneo loserSpawns (esperado ~0): {0}" -f $rSim.loserSpawns) -ForegroundColor Yellow
    Write-Host ("escalonado loserSpawns: {0}  (teto {1})  -> {2}" -f $rStg.loserSpawns, $teto, $(if ($rStg.loserSpawns -le $teto) { 'DENTRO' } else { 'ACIMA' })) -ForegroundColor Yellow
}
finally {
    Stop-DaemonProcs -DaemonPath $deployDaemon
    if ($env:PTU_SAFE_ALLOW_ROOTS) { Remove-Item Env:PTU_SAFE_ALLOW_ROOTS -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $deploy -Recurse -Force -ErrorAction SilentlyContinue
    if ($identity) { Remove-Item -LiteralPath $identity.Names.ClientLogPath -Force -ErrorAction SilentlyContinue }
}
