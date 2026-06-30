#requires -Version 7.4
<#
.SYNOPSIS
PASSO F - medicao do FIO REAL (cliente NativeAOT ptu-client.exe <-> daemon pwsh REAL) vs criterio
§9-0e RE-ENQUADRADO. PROTOTIPO DESCARTAVEL: NAO altera codigo de producao, NAO liga enforce nem o
fio (settings.json intocado). Sobe o daemon e o cliente REAIS ja buildados, a partir de um DEPLOY
temporario (layout de producao do Passo G), e mede com a metodologia do passo 0.

Cobre, numa unica sessao de daemon QUENTE:
  - coldReadyMs (spawn do daemon -> pipe conectavel);
  - WARMUP capturado A PARTE (1 as reqs estouram os 80 ms e deferem; o estacionario da allow);
  - ROBUST1k: >=1000 iteracoes INTERCALADAS floor/defer/allow -> CSV + as DUAS metricas do gate
    (perc-a-perc e2e-floor ate p95; pareado p90) + telemetria (p50/p90/p95/p99, %>80ms);
  - CANON isolado: custo de [Ptu.CwdWorker]::Canonicalize in-process;
  - BASELINE (iii): hook pwsh string-puro ORIGINAL (decisor in-process via pwsh -File por chamada).

A medicao deve rodar SOZINHA (sem outras cargas pesadas concorrentes): os tempos sao sensiveis a
contencao. Defender ATIVO (como no passo 0). High prio no harness/daemon/clientes.

.PARAMETER Iterations  >=1000 (default 1000). .PARAMETER Warmup  iter de aquecimento (default 50).
#>
[CmdletBinding()]
param(
    [int] $Iterations = 1000,
    [int] $Warmup = 50,
    [int] $CanonIter = 1000,
    [int] $BaselineIter = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here    = $PSScriptRoot
$repo    = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills'
$scripts = Join-Path $repo 'scripts'
$exeSrc  = Join-Path $repo 'ptu-native\client\bin\x64\Release\net8.0\win-x64\publish\ptu-client.exe'
$dllSrc  = Join-Path $repo 'ptu-native\lib\bin\Release\net8.0\PtuCanon.dll'
$floorExe = Join-Path $here 'aot-floor\bin\x64\Release\net8.0\win-x64\publish\ptu-client-floor.exe'
$idScript = Join-Path $scripts 'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1'
$decisor  = Join-Path $scripts 'Invoke-ClaudeCodePreToolUseSafeAllow.ps1'
$pwshExe  = (Get-Command pwsh).Source

foreach ($f in @($exeSrc, $dllSrc, $floorExe, $idScript, $decisor)) {
    if (-not (Test-Path -LiteralPath $f)) { throw "ausente: $f" }
}

$csvPath = Join-Path $here 'passoF-series.csv'

$deployScripts = @(
    'ClaudeCodePreToolUseSafeAllowDaemon.ps1',
    'ClaudeCodePreToolUseSafeAllowSupport.ps1',
    'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1',
    'Get-ClaudeCodeBashSafeSegments.py',
    'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
)

# ---------------------------------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------------------------------
function New-PtuDeploy {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-passoF-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Copy-Item -LiteralPath $exeSrc -Destination (Join-Path $dir 'ptu-client.exe') -Force
    Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $dir 'PtuCanon.dll') -Force
    foreach ($f in $deployScripts) { Copy-Item -LiteralPath (Join-Path $scripts $f) -Destination (Join-Path $dir $f) -Force }
    [System.IO.File]::WriteAllText((Join-Path $dir '.ptu-safe-allow-root'), '')
    return $dir
}

function Test-PipeReady {
    param([string] $PipeName)
    $files = [System.IO.Directory]::GetFiles('\\.\pipe\')   # NAO (Get-ChildItem).Name (lanca sob StrictMode)
    foreach ($f in $files) { if ([System.IO.Path]::GetFileName($f) -ceq $PipeName) { return $true } }
    return $false
}

function Wait-PipeReady {
    param([string] $PipeName, [int] $TimeoutMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        if (Test-PipeReady -PipeName $PipeName) { return [double]$sw.Elapsed.TotalMilliseconds }
        Start-Sleep -Milliseconds 10
    }
    return [double](-1)
}

function Invoke-Proc {
    # Stopwatch em volta de Start -> escreve stdin -> ReadToEnd -> WaitForExit (fiel ao §5: o teardown
    # esta no caminho critico). $Stdin = $null para o floor (sem redirecionar stdin). High prio.
    param([string] $File, [string] $Stdin, [hashtable] $EnvOverride)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $File
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = ($null -ne $Stdin)
    $psi.CreateNoWindow = $true
    $psi.Environment.Remove('PTU_SAFE_ALLOW_ROOTS') | Out-Null
    if ($EnvOverride) { foreach ($k in $EnvOverride.Keys) { $psi.Environment[$k] = $EnvOverride[$k] } }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = [System.Diagnostics.Process]::Start($psi)
    try { $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch {}
    if ($null -ne $Stdin) { $p.StandardInput.Write($Stdin); $p.StandardInput.Close() }
    $out = $p.StandardOutput.ReadToEnd()
    [void]$p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $sw.Stop()
    return [pscustomobject]@{ Ms = [double]$sw.Elapsed.TotalMilliseconds; Out = $out }
}

function Get-Decision {
    param([string] $Json)
    try { $o = $Json | ConvertFrom-Json; return [string]$o.hookSpecificOutput.permissionDecision } catch { return '<unparseable>' }
}

function Invoke-PwshHook {
    # Baseline (iii): o hook pwsh string-puro ORIGINAL = `pwsh -NoProfile -File <decisor>` com o JSON do
    # hook no stdin, UM pwsh por chamada (startup do pwsh no caminho critico). Mede ate WaitForExit.
    param([string] $PwshExe, [string] $Decisor, [string] $Stdin, [hashtable] $EnvOverride)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $PwshExe
    foreach ($a in @('-NoProfile', '-NoLogo', '-NonInteractive', '-File', $Decisor)) { [void]$psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.Environment.Remove('PTU_SAFE_ALLOW_ROOTS') | Out-Null
    if ($EnvOverride) { foreach ($k in $EnvOverride.Keys) { $psi.Environment[$k] = $EnvOverride[$k] } }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = [System.Diagnostics.Process]::Start($psi)
    try { $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch {}
    $p.StandardInput.Write($Stdin); $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd()
    [void]$p.StandardError.ReadToEnd()
    $p.WaitForExit()
    $sw.Stop()
    return [pscustomobject]@{ Ms = [double]$sw.Elapsed.TotalMilliseconds; Out = $out }
}

function Get-Pct {
    param([double[]] $Sorted, [double] $P)
    $idx = [int][math]::Ceiling(($P / 100.0) * $Sorted.Count) - 1
    if ($idx -lt 0) { $idx = 0 }
    if ($idx -ge $Sorted.Count) { $idx = $Sorted.Count - 1 }
    return $Sorted[$idx]
}

function Get-Stats {
    param([string] $Name, [System.Collections.Generic.List[double]] $L)
    $s = [double[]]@($L | Sort-Object)
    $over80 = @($L | Where-Object { $_ -gt 80 }).Count
    return [pscustomobject][ordered]@{
        scenario = $Name; n = $s.Count
        min  = [math]::Round($s[0], 1)
        p50  = [math]::Round((Get-Pct $s 50), 1)
        p75  = [math]::Round((Get-Pct $s 75), 1)
        p90  = [math]::Round((Get-Pct $s 90), 1)
        p95  = [math]::Round((Get-Pct $s 95), 1)
        p99  = [math]::Round((Get-Pct $s 99), 1)
        max  = [math]::Round($s[$s.Count - 1], 1)
        mean = [math]::Round(($L | Measure-Object -Average).Average, 1)
        'gt80%' = [math]::Round(100.0 * $over80 / $s.Count, 2)
    }
}

function Get-PairStat {
    param([string] $Name, [System.Collections.Generic.List[double]] $L)
    $s = [double[]]@($L | Sort-Object)
    $neg = @($L | Where-Object { $_ -lt 0 }).Count
    return [pscustomobject][ordered]@{
        par   = $Name
        p50   = [math]::Round((Get-Pct $s 50), 2)
        p75   = [math]::Round((Get-Pct $s 75), 2)
        p90   = [math]::Round((Get-Pct $s 90), 2)
        p95   = [math]::Round((Get-Pct $s 95), 2)
        media = [math]::Round(($L | Measure-Object -Average).Average, 2)
        min   = [math]::Round($s[0], 2)
        max   = [math]::Round($s[$s.Count - 1], 2)
        'neg%' = [math]::Round(100.0 * $neg / $s.Count, 1)
    }
}

# ===================================================================================================
# Subida
# ===================================================================================================
try { [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch {}

. $idScript
if (-not ('Ptu.Canon' -as [type])) { Add-Type -Path $dllSrc }

$deploy = New-PtuDeploy
$env:PTU_SAFE_ALLOW_ROOTS = $deploy
$identity = Get-PtuIdentity -StartDirectory $deploy -DllPath (Join-Path $deploy 'PtuCanon.dll') -Roots @($deploy)
if ($null -eq $identity) { throw "identidade nula p/ deploy $deploy" }
$pipeName = $identity.Names.PipeName
$exeF = Join-Path $deploy 'ptu-client.exe'
$deployDaemon = Join-Path $deploy 'ClaudeCodePreToolUseSafeAllowDaemon.ps1'
$dOut = Join-Path $deploy 'daemon-out.txt'
$dErr = Join-Path $deploy 'daemon-err.txt'

$envRoots = @{ PTU_SAFE_ALLOW_ROOTS = $deploy }
$jsonDefer = '{"tool_name":"Bash","cwd":"' + ($deploy -replace '\\', '\\') + '","tool_input":{"command":"npm run build"}}'
$jsonAllow = '{"tool_name":"Bash","cwd":"' + ($deploy -replace '\\', '\\') + '","tool_input":{"command":"git status"}}'

$daemonProc = $null
try {
    Write-Host "Deploy: $deploy" -ForegroundColor DarkGray
    Write-Host "Pipe:   $pipeName" -ForegroundColor DarkGray

    # --- coldReadyMs: spawn do daemon REAL -> pipe conectavel ---
    $swCold = [System.Diagnostics.Stopwatch]::StartNew()
    $daemonProc = Start-Process -FilePath $pwshExe `
        -ArgumentList @('-NoProfile', '-NoLogo', '-NonInteractive', '-File', $deployDaemon) `
        -PassThru -WindowStyle Hidden -RedirectStandardOutput $dOut -RedirectStandardError $dErr
    try { $daemonProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch {}
    $coldReadyMs = Wait-PipeReady -PipeName $pipeName -TimeoutMs 30000
    $swCold.Stop()
    if ($coldReadyMs -lt 0) {
        $errTxt = if (Test-Path $dErr) { Get-Content -Raw $dErr } else { '(sem stderr)' }
        throw "daemon nao ficou ready em 30s. stderr:`n$errTxt"
    }
    Write-Host ("coldReadyMs (spawn -> pipe conectavel): {0:N0} ms (PID {1})" -f $coldReadyMs, $daemonProc.Id) -ForegroundColor Green

    # --- WARMUP capturado A PARTE: o estacionario so comeca quando allow converge ---
    $warmRows = [System.Collections.Generic.List[string]]::new()
    $warmConverged = $false
    $warmCount = 0
    for ($k = 0; $k -lt 30; $k++) {
        $r = Invoke-Proc -File $exeF -Stdin $jsonAllow -EnvOverride $envRoots
        $dec = Get-Decision $r.Out
        $warmRows.Add(('{0},{1},{2}' -f $k, $dec, [math]::Round($r.Ms, 1)))
        $warmCount++
        if ($dec -ceq 'allow') { $warmConverged = $true; break }
        Start-Sleep -Milliseconds 50
    }
    Write-Host ("WARMUP (ate allow convergir): {0} req" -f $warmCount) -ForegroundColor Yellow
    $warmRows | ForEach-Object { Write-Host ("  warm[{0}]" -f $_) -ForegroundColor DarkGray }
    if (-not $warmConverged) { throw "warmup nao convergiu p/ allow em 30 tentativas" }

    # Warmup adicional intercalado (estabiliza floor/defer/allow juntos antes da medicao)
    for ($i = 0; $i -lt $Warmup; $i++) {
        [void](Invoke-Proc -File $floorExe -Stdin $null -EnvOverride $null)
        [void](Invoke-Proc -File $exeF -Stdin $jsonDefer -EnvOverride $envRoots)
        [void](Invoke-Proc -File $exeF -Stdin $jsonAllow -EnvOverride $envRoots)
    }

    # --- ROBUST1k: floor/defer/allow INTERCALADO ---
    $floor = [System.Collections.Generic.List[double]]::new()
    $defer = [System.Collections.Generic.List[double]]::new()
    $allow = [System.Collections.Generic.List[double]]::new()
    $rows  = [System.Collections.Generic.List[string]]::new()
    $rows.Add('iter,scenario,ms,decision')
    $deferMismatch = 0
    $allowMismatch = 0

    $tStart = [DateTime]::UtcNow
    for ($i = 0; $i -lt $Iterations; $i++) {
        $rF = Invoke-Proc -File $floorExe -Stdin $null -EnvOverride $null
        $rD = Invoke-Proc -File $exeF -Stdin $jsonDefer -EnvOverride $envRoots
        $rA = Invoke-Proc -File $exeF -Stdin $jsonAllow -EnvOverride $envRoots
        $decD = Get-Decision $rD.Out
        $decA = Get-Decision $rA.Out
        if ($decD -cne 'defer') { $deferMismatch++ }
        if ($decA -cne 'allow') { $allowMismatch++ }
        $floor.Add($rF.Ms); $defer.Add($rD.Ms); $allow.Add($rA.Ms)
        $rows.Add(('{0},floor,{1},-'     -f $i, [math]::Round($rF.Ms, 3)))
        $rows.Add(('{0},defer,{1},{2}'   -f $i, [math]::Round($rD.Ms, 3), $decD))
        $rows.Add(('{0},allow,{1},{2}'   -f $i, [math]::Round($rA.Ms, 3), $decA))
        if ((($i + 1) % 200) -eq 0) { Write-Host ("  ...{0}/{1}" -f ($i + 1), $Iterations) -ForegroundColor DarkGray }
    }
    $elapsed = ([DateTime]::UtcNow - $tStart).TotalSeconds
    [System.IO.File]::WriteAllLines($csvPath, $rows)

    # Subtracao pareada (overhead = e2e - floor na MESMA iteracao)
    $ovD = [System.Collections.Generic.List[double]]::new()
    $ovA = [System.Collections.Generic.List[double]]::new()
    for ($i = 0; $i -lt $Iterations; $i++) { $ovD.Add($defer[$i] - $floor[$i]); $ovA.Add($allow[$i] - $floor[$i]) }

    # Cross-check percentil-a-percentil (e2e_pX - floor_pX)
    $fS = [double[]]@($floor | Sort-Object)
    $dS = [double[]]@($defer | Sort-Object)
    $aS = [double[]]@($allow | Sort-Object)
    $ppRows = foreach ($p in @(50, 75, 90, 95, 99)) {
        [pscustomobject][ordered]@{
            percentil = "p$p"
            floor = [math]::Round((Get-Pct $fS $p), 1)
            defer = [math]::Round((Get-Pct $dS $p), 1)
            allow = [math]::Round((Get-Pct $aS $p), 1)
            'defer-floor' = [math]::Round((Get-Pct $dS $p) - (Get-Pct $fS $p), 1)
            'allow-floor' = [math]::Round((Get-Pct $aS $p) - (Get-Pct $fS $p), 1)
        }
    }

    Write-Host ""
    Write-Host ("ROBUST1k (intercalado, High) - {0:N0}s; mismatch defer={1} allow={2}" -f $elapsed, $deferMismatch, $allowMismatch) -ForegroundColor Green
    @((Get-Stats 'floor (AOT no-op)' $floor), (Get-Stats 'e2e-defer' $defer), (Get-Stats 'e2e-allow' $allow)) | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "CROSS-CHECK percentil-a-percentil (e2e_pX - floor_pX), ms:" -ForegroundColor Green
    $ppRows | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "SUBTRACAO PAREADA (overhead = e2e - floor na MESMA iteracao), ms:" -ForegroundColor Green
    @((Get-PairStat 'defer - floor' $ovD), (Get-PairStat 'allow - floor' $ovA)) | Format-Table -AutoSize | Out-String | Write-Host

    # --- CANON isolado: custo de CwdWorker.Canonicalize in-process ---
    $canon = [System.Collections.Generic.List[double]]::new()
    for ($i = 0; $i -lt 30; $i++) { [void][Ptu.CwdWorker]::Canonicalize($deploy, 200, 8) }   # warmup
    for ($i = 0; $i -lt $CanonIter; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        [void][Ptu.CwdWorker]::Canonicalize($deploy, 200, 8)
        $sw.Stop()
        $canon.Add($sw.Elapsed.TotalMilliseconds)
    }
    Write-Host "CANON isolado [Ptu.CwdWorker]::Canonicalize (in-process), ms:" -ForegroundColor Green
    @((Get-Stats 'cwd-canon' $canon)) | Format-Table -AutoSize | Out-String | Write-Host

    # --- BASELINE (iii): hook pwsh string-puro ORIGINAL (decisor via pwsh -File por chamada) ---
    $baseHook = [System.Collections.Generic.List[double]]::new()
    $baseDecMismatch = 0
    for ($i = 0; $i -lt 3; $i++) { [void](Invoke-PwshHook -PwshExe $pwshExe -Decisor $decisor -Stdin $jsonDefer -EnvOverride $envRoots) }   # aquece
    for ($i = 0; $i -lt $BaselineIter; $i++) {
        $r = Invoke-PwshHook -PwshExe $pwshExe -Decisor $decisor -Stdin $jsonDefer -EnvOverride $envRoots
        if ((Get-Decision $r.Out) -cne 'defer') { $baseDecMismatch++ }
        $baseHook.Add($r.Ms)
    }
    Write-Host ("BASELINE (iii) hook pwsh ORIGINAL, defer-comum por chamada (mismatch={0}), ms:" -f $baseDecMismatch) -ForegroundColor Green
    @((Get-Stats 'pwsh-hook-defer' $baseHook)) | Format-Table -AutoSize | Out-String | Write-Host

    Write-Host ("Serie temporal completa: {0}" -f $csvPath) -ForegroundColor DarkGray
    Write-Host ("coldReadyMs={0:N0}; warmupReq={1}" -f $coldReadyMs, $warmCount) -ForegroundColor DarkGray
}
finally {
    if ($null -ne $daemonProc -and -not $daemonProc.HasExited) { try { $daemonProc.Kill() } catch {} }
    if ($env:PTU_SAFE_ALLOW_ROOTS) { Remove-Item Env:PTU_SAFE_ALLOW_ROOTS -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $deploy -Recurse -Force -ErrorAction SilentlyContinue
    if ($identity) { Remove-Item -LiteralPath $identity.Names.ClientLogPath -Force -ErrorAction SilentlyContinue }
}
