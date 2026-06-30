#requires -Version 7.4
<#
.SYNOPSIS
PASSO F - ADENDO P0 (concorrência), pedido pelo painel de revisão por pares (2026-06-30). PROTOTIPO
DESCARTAVEL. O daemon e' SINGLE-THREADED (uma conexao por vez) e a medicao base do Passo F foi
SEQUENCIAL. Aqui mede-se o FIO REAL sob RAJADA: N clientes quase-simultaneos contra o daemon QUENTE,
cada cliente medindo o proprio e2e (INCLUINDO espera em fila) ate WaitForExit. NAO altera producao,
NAO liga enforce nem o fio.

Responde as perguntas do painel:
  - latencia percebida p50/p90/p95/p99 por nivel de concorrencia (com fila);
  - fracao allow vs defer sob carga (o daemon degrada para defer fail-closed, ou erra?);
  - PROVA fail-closed: nenhum cliente sob rajada emite saida != allow/defer (e nunca allow indevido —
    todos os inputs sao in-scope, entao allow=correto e defer=degradacao benigna; QUALQUER outra saida
    = bug).
#>
[CmdletBinding()]
param(
    [int[]] $Levels = @(1, 5, 10, 20),
    [int]   $Rounds = 20
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
    'ClaudeCodePreToolUseSafeAllowDaemon.ps1','ClaudeCodePreToolUseSafeAllowSupport.ps1',
    'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1','Get-ClaudeCodeBashSafeSegments.py',
    'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
)
function New-PtuDeploy {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-passoFconc-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Copy-Item -LiteralPath $exeSrc -Destination (Join-Path $dir 'ptu-client.exe') -Force
    Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $dir 'PtuCanon.dll') -Force
    foreach ($f in $deployScripts) { Copy-Item -LiteralPath (Join-Path $scripts $f) -Destination (Join-Path $dir $f) -Force }
    [System.IO.File]::WriteAllText((Join-Path $dir '.ptu-safe-allow-root'), '')
    return $dir
}
function Test-PipeReady { param([string] $PipeName)
    foreach ($f in [System.IO.Directory]::GetFiles('\\.\pipe\')) { if ([System.IO.Path]::GetFileName($f) -ceq $PipeName) { return $true } }
    return $false
}
function Invoke-ClientOnce {
    param([string] $Exe, [string] $Json, [string] $Deploy)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Exe
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.Environment['PTU_SAFE_ALLOW_ROOTS'] = $Deploy
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = [System.Diagnostics.Process]::Start($psi)
    try { $p.StandardInput.Write($Json); $p.StandardInput.Close() } catch { }   # cliente pode ter saido cedo (sem stdin -> defere); seguir e ler o stdout
    $out = $p.StandardOutput.ReadToEnd(); [void]$p.StandardError.ReadToEnd(); $p.WaitForExit(); $sw.Stop()
    $dec = '<none>'
    try { $o = $out | ConvertFrom-Json; $dec = [string]$o.hookSpecificOutput.permissionDecision } catch { $dec = '<unparseable>' }
    return [pscustomobject]@{ Ms = [double]$sw.Elapsed.TotalMilliseconds; Decision = $dec }
}
function Get-Pct { param([double[]] $S, [double] $P)
    if ($S.Count -eq 0) { return 0 }
    $i = [int][math]::Ceiling(($P/100.0)*$S.Count)-1; if ($i -lt 0) {$i=0}; if ($i -ge $S.Count){$i=$S.Count-1}; return $S[$i]
}

. $idScript
$deploy = New-PtuDeploy
$env:PTU_SAFE_ALLOW_ROOTS = $deploy
$identity = Get-PtuIdentity -StartDirectory $deploy -DllPath (Join-Path $deploy 'PtuCanon.dll') -Roots @($deploy)
if ($null -eq $identity) { throw "identidade nula" }
$pipeName = $identity.Names.PipeName
$exeF = Join-Path $deploy 'ptu-client.exe'
$deployDaemon = Join-Path $deploy 'ClaudeCodePreToolUseSafeAllowDaemon.ps1'
$jsonAllow = '{"tool_name":"Bash","cwd":"' + ($deploy -replace '\\','\\') + '","tool_input":{"command":"git status"}}'

$daemonProc = $null
try {
    # Prioridade NORMAL (NAO High): a maquina e' estacao de trabalho ativa; medicao qualitativa (a
    # distribuicao de decisao allow/defer/other e' robusta a carga; latencia e' so indicativa).
    $daemonProc = Start-Process -FilePath $pwshExe -ArgumentList @('-NoProfile','-NoLogo','-NonInteractive','-File',$deployDaemon) -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $deploy 'd.out') -RedirectStandardError (Join-Path $deploy 'd.err')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 30000 -and -not (Test-PipeReady -PipeName $pipeName)) { Start-Sleep -Milliseconds 10 }
    if (-not (Test-PipeReady -PipeName $pipeName)) { throw "daemon nao subiu" }
    # warmup ate allow (estacionario)
    for ($k=0; $k -lt 20; $k++) { $r = Invoke-ClientOnce -Exe $exeF -Json $jsonAllow -Deploy $deploy; if ($r.Decision -ceq 'allow') { break }; Start-Sleep -Milliseconds 50 }

    $summary = [System.Collections.Generic.List[object]]::new()
    foreach ($N in $Levels) {
        $lat = [System.Collections.Generic.List[double]]::new()
        $nAllow = 0; $nDefer = 0; $nOther = 0
        for ($round = 0; $round -lt $Rounds; $round++) {
            # Dispara os N clientes num LOOP APERTADO (sem runspace -> sem o overhead de ~500ms do
            # ForEach-Parallel que mascarava a latencia). Cada cliente com seu proprio cronometro;
            # iniciados em ~ms uns dos outros = rajada quase-simultanea. e2e por cliente INCLUI a fila
            # (daemon single-threaded serve um por vez; os tardios esperam).
            $batch = [System.Collections.Generic.List[object]]::new()
            for ($i = 0; $i -lt $N; $i++) {
                $psi = [System.Diagnostics.ProcessStartInfo]::new()
                $psi.FileName = $exeF
                $psi.UseShellExecute = $false
                $psi.RedirectStandardInput = $true
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.CreateNoWindow = $true
                $psi.Environment['PTU_SAFE_ALLOW_ROOTS'] = $deploy
                $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
                $p = [System.Diagnostics.Process]::Start($psi)
                try { $p.StandardInput.Write($jsonAllow); $p.StandardInput.Close() } catch { }   # cliente pode ter saido cedo -> defere; seguir e ler o stdout
                $batch.Add([pscustomobject]@{ P = $p; Sw = $sw2 })
            }
            foreach ($entry in $batch) {
                $out = $entry.P.StandardOutput.ReadToEnd()
                [void]$entry.P.StandardError.ReadToEnd()
                $entry.P.WaitForExit()
                $entry.Sw.Stop()
                $lat.Add([double]$entry.Sw.Elapsed.TotalMilliseconds)
                $dec = '<none>'
                try { $dec = [string](($out | ConvertFrom-Json).hookSpecificOutput.permissionDecision) } catch { $dec = '<unparseable>' }
                switch ($dec) { 'allow' { $nAllow++ } 'defer' { $nDefer++ } default { $nOther++ } }
                try { $entry.P.Dispose() } catch { }
            }
            Start-Sleep -Milliseconds 150   # cooldown entre rajadas
        }
        $s = [double[]]@($lat | Sort-Object)
        $total = $lat.Count
        $summary.Add([pscustomobject][ordered]@{
            N = $N; total = $total
            'allow%' = [math]::Round(100.0*$nAllow/$total,1)
            'defer%' = [math]::Round(100.0*$nDefer/$total,1)
            other    = $nOther
            p50 = [math]::Round((Get-Pct $s 50),1); p90 = [math]::Round((Get-Pct $s 90),1)
            p95 = [math]::Round((Get-Pct $s 95),1); p99 = [math]::Round((Get-Pct $s 99),1)
            max = [math]::Round($s[$s.Count-1],1)
        })
        Write-Host ("N={0}: total={1} allow%={2} defer%={3} other={4} p50={5} p95={6} max={7}" -f $N, $total, $summary[-1].'allow%', $summary[-1].'defer%', $nOther, $summary[-1].p50, $summary[-1].p95, $summary[-1].max) -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "CONCORRENCIA (rajada de N clientes simultaneos, daemon QUENTE single-threaded), e2e ms COM fila:" -ForegroundColor Green
    $summary | Format-Table -AutoSize | Out-String | Write-Host
    $sumOther = ([int](($summary | Measure-Object -Property other -Sum).Sum))
    Write-Host ("FAIL-CLOSED: saidas != allow/defer no total = {0} (DEVE ser 0)" -f $sumOther) -ForegroundColor $(if ($sumOther -eq 0) { 'Green' } else { 'Red' })
}
finally {
    if ($null -ne $daemonProc -and -not $daemonProc.HasExited) { try { $daemonProc.Kill() } catch {} }
    # varre e mata daemons-perdedores (cold-path) deste deploy, se sobraram
    try {
        $strays = Get-CimInstance Win32_Process -Filter "Name='pwsh.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like ('*' + $deployDaemon + '*') -and $_.CommandLine -notlike '*-Command*' }
        foreach ($s in $strays) { try { Stop-Process -Id $s.ProcessId -Force -ErrorAction Stop } catch {} }
    } catch {}
    if ($env:PTU_SAFE_ALLOW_ROOTS) { Remove-Item Env:PTU_SAFE_ALLOW_ROOTS -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $deploy -Recurse -Force -ErrorAction SilentlyContinue
    if ($identity) { Remove-Item -LiteralPath $identity.Names.ClientLogPath -Force -ErrorAction SilentlyContinue }
}
