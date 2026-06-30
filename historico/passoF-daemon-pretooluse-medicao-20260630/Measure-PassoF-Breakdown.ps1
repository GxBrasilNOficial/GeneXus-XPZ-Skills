#requires -Version 7.4
<#
.SYNOPSIS
PASSO F - breakdown do overhead (localiza a CAUSA). PROTOTIPO DESCARTAVEL. Intercala, na MESMA
rodada, TRES spawns do MESMO cliente NativeAOT real:
  - floor          : spawn AOT puro (ptu-client-floor.exe, return 0;);
  - identity       : ptu-client.exe --emit-identity <deploy> -> spawn + ClientIdentity.Compute
                     (canon de roots/repo + marcador + hashing + derivacao de nomes), SEM stdin/pipe;
  - e2e-allow      : hot-path completo (stdin + identidade + connect + frame + resposta do daemon).

Isola: (identity - floor) = custo da IDENTIDADE por invocacao (lado CLIENTE);
       (e2e - identity)    = custo marginal do round-trip pipe+decisao (lado DAEMON).
Daemon REAL quente. NAO altera producao, NAO liga enforce/fio.
#>
[CmdletBinding()]
param([int] $Iterations = 500, [int] $Warmup = 30)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here    = $PSScriptRoot
$repo    = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills'
$scripts = Join-Path $repo 'scripts'
$exeSrc  = Join-Path $repo 'ptu-native\client\bin\x64\Release\net8.0\win-x64\publish\ptu-client.exe'
$dllSrc  = Join-Path $repo 'ptu-native\lib\bin\Release\net8.0\PtuCanon.dll'
$floorExe = Join-Path $here 'aot-floor\bin\x64\Release\net8.0\win-x64\publish\ptu-client-floor.exe'
$idScript = Join-Path $scripts 'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1'
$pwshExe  = (Get-Command pwsh).Source
foreach ($f in @($exeSrc, $dllSrc, $floorExe, $idScript)) { if (-not (Test-Path -LiteralPath $f)) { throw "ausente: $f" } }

$deployScripts = @(
    'ClaudeCodePreToolUseSafeAllowDaemon.ps1','ClaudeCodePreToolUseSafeAllowSupport.ps1',
    'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1','Get-ClaudeCodeBashSafeSegments.py',
    'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
)
function New-PtuDeploy {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-passoFbd-" + [System.Guid]::NewGuid().ToString('N'))
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
function Invoke-Proc {
    param([string] $File, [string] $Stdin, [string[]] $ExeArgs, [hashtable] $EnvOverride)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $File
    if ($ExeArgs) { foreach ($a in $ExeArgs) { [void]$psi.ArgumentList.Add($a) } }
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
    $out = $p.StandardOutput.ReadToEnd(); [void]$p.StandardError.ReadToEnd(); $p.WaitForExit(); $sw.Stop()
    return [pscustomobject]@{ Ms = [double]$sw.Elapsed.TotalMilliseconds; Out = $out }
}
function Get-Pct { param([double[]] $S, [double] $P)
    $i = [int][math]::Ceiling(($P/100.0)*$S.Count)-1; if ($i -lt 0) {$i=0}; if ($i -ge $S.Count){$i=$S.Count-1}; return $S[$i]
}
function Get-Stats { param([string] $Name, [System.Collections.Generic.List[double]] $L)
    $s=[double[]]@($L|Sort-Object)
    [pscustomobject][ordered]@{ scenario=$Name; n=$s.Count; p50=[math]::Round((Get-Pct $s 50),1); p75=[math]::Round((Get-Pct $s 75),1)
        p90=[math]::Round((Get-Pct $s 90),1); p95=[math]::Round((Get-Pct $s 95),1); mean=[math]::Round(($L|Measure-Object -Average).Average,1) }
}

. $idScript
$deploy = New-PtuDeploy
$env:PTU_SAFE_ALLOW_ROOTS = $deploy
$identity = Get-PtuIdentity -StartDirectory $deploy -DllPath (Join-Path $deploy 'PtuCanon.dll') -Roots @($deploy)
if ($null -eq $identity) { throw "identidade nula" }
$pipeName = $identity.Names.PipeName
$exeF = Join-Path $deploy 'ptu-client.exe'
$deployDaemon = Join-Path $deploy 'ClaudeCodePreToolUseSafeAllowDaemon.ps1'
$envRoots = @{ PTU_SAFE_ALLOW_ROOTS = $deploy }
$jsonAllow = '{"tool_name":"Bash","cwd":"' + ($deploy -replace '\\','\\') + '","tool_input":{"command":"git status"}}'

$daemonProc = $null
try {
    $daemonProc = Start-Process -FilePath $pwshExe -ArgumentList @('-NoProfile','-NoLogo','-NonInteractive','-File',$deployDaemon) -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $deploy 'd.out') -RedirectStandardError (Join-Path $deploy 'd.err')
    try { $daemonProc.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::High } catch {}
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt 30000 -and -not (Test-PipeReady -PipeName $pipeName)) { Start-Sleep -Milliseconds 10 }
    if (-not (Test-PipeReady -PipeName $pipeName)) { throw "daemon nao subiu" }
    # warmup ate allow
    for ($k=0; $k -lt 20; $k++) { $r=Invoke-Proc -File $exeF -Stdin $jsonAllow -EnvOverride $envRoots; if ((($r.Out|ConvertFrom-Json).hookSpecificOutput.permissionDecision) -ceq 'allow') { break }; Start-Sleep -Milliseconds 50 }
    for ($i=0; $i -lt $Warmup; $i++) {
        [void](Invoke-Proc -File $floorExe -Stdin $null -ExeArgs $null -EnvOverride $null)
        [void](Invoke-Proc -File $exeF -Stdin $null -ExeArgs @('--emit-identity',$deploy) -EnvOverride $envRoots)
        [void](Invoke-Proc -File $exeF -Stdin $jsonAllow -ExeArgs $null -EnvOverride $envRoots)
    }

    $floor=[System.Collections.Generic.List[double]]::new()
    $ident=[System.Collections.Generic.List[double]]::new()
    $e2e=[System.Collections.Generic.List[double]]::new()
    for ($i=0; $i -lt $Iterations; $i++) {
        $floor.Add((Invoke-Proc -File $floorExe -Stdin $null -ExeArgs $null -EnvOverride $null).Ms)
        $ident.Add((Invoke-Proc -File $exeF -Stdin $null -ExeArgs @('--emit-identity',$deploy) -EnvOverride $envRoots).Ms)
        $e2e.Add((Invoke-Proc -File $exeF -Stdin $jsonAllow -ExeArgs $null -EnvOverride $envRoots).Ms)
        if ((($i+1)%100) -eq 0) { Write-Host ("  ...{0}/{1}" -f ($i+1),$Iterations) -ForegroundColor DarkGray }
    }

    Write-Host ""
    Write-Host "BREAKDOWN (intercalado floor/identity/e2e-allow, n=$Iterations), ms:" -ForegroundColor Green
    @((Get-Stats 'floor (spawn)' $floor),(Get-Stats 'identity (spawn+id)' $ident),(Get-Stats 'e2e-allow (full)' $e2e)) | Format-Table -AutoSize | Out-String | Write-Host

    $fS=[double[]]@($floor|Sort-Object); $iS=[double[]]@($ident|Sort-Object); $eS=[double[]]@($e2e|Sort-Object)
    Write-Host "DECOMPOSICAO perc-a-perc (ms):" -ForegroundColor Green
    foreach ($p in @(50,75,90,95)) {
        $fp=Get-Pct $fS $p; $ip=Get-Pct $iS $p; $ep=Get-Pct $eS $p
        Write-Host ("  p{0}: identidade(id-floor)={1:N1}  daemon(e2e-id)={2:N1}  total(e2e-floor)={3:N1}" -f $p, ($ip-$fp), ($ep-$ip), ($ep-$fp)) -ForegroundColor Yellow
    }
}
finally {
    if ($null -ne $daemonProc -and -not $daemonProc.HasExited) { try { $daemonProc.Kill() } catch {} }
    if ($env:PTU_SAFE_ALLOW_ROOTS) { Remove-Item Env:PTU_SAFE_ALLOW_ROOTS -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $deploy -Recurse -Force -ErrorAction SilentlyContinue
    if ($identity) { Remove-Item -LiteralPath $identity.Names.ClientLogPath -Force -ErrorAction SilentlyContinue }
}
