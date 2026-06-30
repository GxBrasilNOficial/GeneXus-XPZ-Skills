#requires -Version 7.4
<#
.SYNOPSIS
Self-test do MODO MEDICAO (--observe / Fase 3) do cliente NativeAOT do hook PreToolUse (auto-allow) do
Claude Code. PASSO G. Sentinela de sucesso: "OK:" na ultima linha.

.DESCRIPTION
Prova que o modo observe (ptu-client.exe --observe) e' PASSIVO: exercita o fio real (hot/cold) e GRAVA
a telemetria, mas SEMPRE devolve defer ao Claude Code -- nunca allow, mesmo quando o outro lado responde
allow. Casos:
  1) passividade: servidor responde allow -> saida defer + reason observe;
  2) fidelidade do log: wouldDecision/outcome/path/latencyMs/requestId;
  3) privacidade (§7): o command NAO aparece no log de medicao;
  4) caminho defer: servidor responde defer -> saida defer, log wouldDecision=defer;
  5) caminho frio: canal ausente, sem script de daemon -> saida defer, log outcome=cold/path=cold (sem subir daemon).
Reusa o padrao do StepD (deploy temporario plano + servidor de pipe FALSO + Invoke-PtuClientExe). Exige o
EXE publicado (NativeAOT) e a DLL buildada. Tudo em temp/LOCALAPPDATA, limpo no fim; nao toca versionados.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scripts  = $PSScriptRoot
$repo     = Split-Path -Parent $scripts
$exeSrc   = Join-Path $repo 'ptu-native\client\bin\x64\Release\net8.0\win-x64\publish\ptu-client.exe'
$dllSrc   = Join-Path $repo 'ptu-native\lib\bin\Release\net8.0\PtuCanon.dll'
$idScript = Join-Path $scripts 'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1'

if (-not (Test-Path -LiteralPath $exeSrc)) {
    throw "EXE NativeAOT nao publicado: $exeSrc -- rode: ptu-native/client/publish.bat"
}
if (-not (Test-Path -LiteralPath $dllSrc)) {
    throw "DLL nao buildada: $dllSrc -- rode: dotnet build ptu-native/lib/ptu-lib.csproj -c Release -nodeReuse:false -p:UseSharedCompilation=false --no-incremental"
}

Import-Module ThreadJob -ErrorAction SilentlyContinue
. $idScript
if (-not ('Ptu.Canon' -as [type])) { Add-Type -Path $dllSrc }

$failures = [System.Collections.Generic.List[string]]::new()
function Assert-True { param([bool] $Cond, [string] $Msg) if (-not $Cond) { $script:failures.Add($Msg) } }

# --------------------------------------------------------------------------------------------------
# Infra (espelha o StepD: deploy plano exe+DLL+scripts+marcador = layout do Passo G).
# --------------------------------------------------------------------------------------------------
$deployScripts = @(
    'ClaudeCodePreToolUseSafeAllowDaemon.ps1',
    'ClaudeCodePreToolUseSafeAllowSupport.ps1',
    'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1',
    'Get-ClaudeCodeBashSafeSegments.py',
    'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
)
function New-PtuClientDeploy {
    param([switch] $NoDaemon, [switch] $NoMarker)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-obsselftest-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Copy-Item -LiteralPath $exeSrc -Destination (Join-Path $dir 'ptu-client.exe') -Force
    Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $dir 'PtuCanon.dll') -Force
    if (-not $NoDaemon) {
        foreach ($f in $deployScripts) { Copy-Item -LiteralPath (Join-Path $scripts $f) -Destination (Join-Path $dir $f) -Force }
    }
    if (-not $NoMarker) { [System.IO.File]::WriteAllText((Join-Path $dir '.ptu-safe-allow-root'), '') }
    return $dir
}
function Get-PtuDeployIdentity {
    param([string] $DeployDir)
    $id = Get-PtuIdentity -StartDirectory $DeployDir -DllPath (Join-Path $DeployDir 'PtuCanon.dll') -Roots @($DeployDir)
    if ($null -eq $id) { throw "identidade nula p/ deploy $DeployDir" }
    return $id
}
function Get-PtuExePath { param([string] $DeployDir) return (Join-Path $DeployDir 'ptu-client.exe') }

function Invoke-PtuClientExe {
    # Roda o EXE alimentando stdin e capturando stdout; env-base + PTU_SAFE_ALLOW_ROOTS controlado.
    param([string] $ExePath, [string] $Stdin, [hashtable] $EnvOverride, [string[]] $ExeArgs = @())
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $ExePath
    foreach ($a in $ExeArgs) { [void]$psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.Environment.Remove('PTU_SAFE_ALLOW_ROOTS') | Out-Null
    if ($EnvOverride) { foreach ($k in $EnvOverride.Keys) { $psi.Environment[$k] = $EnvOverride[$k] } }
    $p = [System.Diagnostics.Process]::Start($psi)
    if ($null -ne $Stdin) { $p.StandardInput.Write($Stdin) }
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd()
    [void]$p.WaitForExit(15000)
    return $out
}
function Get-PtuDecisionField {
    param([string] $Json)
    try { $o = $Json | ConvertFrom-Json; return [string]$o.hookSpecificOutput.permissionDecision } catch { return '<unparseable>' }
}
function Get-PtuReasonField {
    param([string] $Json)
    try { $o = $Json | ConvertFrom-Json; return [string]$o.hookSpecificOutput.permissionDecisionReason } catch { return '' }
}
function Wait-PtuPipeExists {
    param([string] $PipeName, [int] $TimeoutMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        $names = @((Get-ChildItem -Path '\\.\pipe\' -ErrorAction SilentlyContinue).Name)
        if ($names -ccontains $PipeName) { return $true }
        Start-Sleep -Milliseconds 25
    }
    return $false
}

# Servidor de pipe FALSO: aceita 1 conexao, drena o request, devolve UM frame valido (Magic=1, Proto=1).
$fakeServer = {
    param($PipeName, $Payload)
    $server = [System.IO.Pipes.NamedPipeServerStream]::new(
        $PipeName, [System.IO.Pipes.PipeDirection]::InOut, 1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous)
    try {
        $ct = $server.WaitForConnectionAsync()
        if (-not $ct.Wait(8000)) { return }
        $hdr = [byte[]]::new(7); $off = 0
        while ($off -lt 7) { $t = $server.ReadAsync($hdr, $off, 7 - $off); if (-not $t.Wait(2000)) { break }; $k = $t.Result; if ($k -le 0) { break }; $off += $k }
        if ($off -eq 7) {
            $rlen = ([int]$hdr[3] -shl 24) -bor ([int]$hdr[4] -shl 16) -bor ([int]$hdr[5] -shl 8) -bor [int]$hdr[6]
            if ($rlen -gt 0 -and $rlen -le 65536) {
                $rb = [byte[]]::new($rlen); $o2 = 0
                while ($o2 -lt $rlen) { $t = $server.ReadAsync($rb, $o2, $rlen - $o2); if (-not $t.Wait(2000)) { break }; $k = $t.Result; if ($k -le 0) { break }; $o2 += $k }
            }
        }
        $rh = [byte[]]::new(7)
        $rh[0] = 1; $rh[2] = 1
        $len = $Payload.Length
        $rh[3] = [byte](($len -shr 24) -band 0xFF); $rh[4] = [byte](($len -shr 16) -band 0xFF)
        $rh[5] = [byte](($len -shr 8) -band 0xFF); $rh[6] = [byte]($len -band 0xFF)
        $server.Write($rh, 0, 7)
        if ($len -gt 0) { $server.Write($Payload, 0, $len) }
        $server.Flush()
        Start-Sleep -Milliseconds 300
    } finally { $server.Dispose() }
}

function Get-PtuObserveLogPath { param([string] $Hash) return (Join-Path $env:LOCALAPPDATA "ClaudeCodePreToolUseSafeAllow\ptu-observe-$Hash.log") }
function Clear-PtuFile { param([string] $Path) if ($Path -and (Test-Path -LiteralPath $Path)) { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue } }
function Read-PtuObserveLines { param([string] $Path) if (-not (Test-Path -LiteralPath $Path)) { return @() } return @(Get-Content -LiteralPath $Path) }

function Invoke-PtuObserveAgainstFake {
    # Sobe o servidor falso com a resposta dada, roda o EXE em --observe e devolve a saida §3.1.
    param([string] $Payload, [string] $Command, [string] $DeployDir, [string] $ExePath, [string] $PipeName)
    $job = Start-ThreadJob -ScriptBlock $fakeServer -ArgumentList $PipeName, ([System.Text.Encoding]::UTF8.GetBytes($Payload))
    try {
        if (-not (Wait-PtuPipeExists -PipeName $PipeName -TimeoutMs 6000)) { return '<no-pipe>' }
        $json = @{ tool_name = 'Bash'; tool_input = @{ command = $Command }; cwd = $DeployDir } | ConvertTo-Json -Compress
        return (Invoke-PtuClientExe -ExePath $ExePath -Stdin $json -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $DeployDir } -ExeArgs @('--observe'))
    } finally {
        [void](Wait-Job -Job $job -Timeout 12000)
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

$deploys = [System.Collections.Generic.List[string]]::new()
$obsLogs = [System.Collections.Generic.List[string]]::new()
try {
    # =============================================================================================
    # Casos 1+2+3: servidor FALSO responde "allow" (deploy -NoDaemon: so o servidor falso responde).
    # =============================================================================================
    $dep1 = New-PtuClientDeploy -NoDaemon; $deploys.Add($dep1)
    $exe1 = Get-PtuExePath -DeployDir $dep1
    $id1  = Get-PtuDeployIdentity -DeployDir $dep1
    $log1 = Get-PtuObserveLogPath -Hash $id1.IdentityHash; $obsLogs.Add($log1)
    Clear-PtuFile -Path $log1
    $sentinela = 'SENTINELA_OBS_' + [System.Guid]::NewGuid().ToString('N')
    $cmd1 = 'git status # ' + $sentinela
    $out1 = Invoke-PtuObserveAgainstFake -Payload 'allow' -Command $cmd1 -DeployDir $dep1 -ExePath $exe1 -PipeName $id1.Names.PipeName

    # Caso 1: passividade -> defer + reason observe (mesmo o fake dizendo allow)
    Assert-True ((Get-PtuDecisionField -Json $out1) -ceq 'defer') "1: observe deveria devolver defer (out=$out1)"
    Assert-True ((Get-PtuReasonField -Json $out1) -match 'observe') "1: reason deveria conter 'observe' (out=$out1)"

    # Caso 2: log fiel (6 colunas TSV; wouldDecision/outcome/path/latencyMs/requestId)
    $lines1 = @(Read-PtuObserveLines -Path $log1)
    Assert-True ($lines1.Count -ge 1) "2: log de medicao vazio/ausente ($log1)"
    if ($lines1.Count -ge 1) {
        $cols = @($lines1[-1] -split "`t")
        Assert-True ($cols.Count -eq 6) "2: linha deveria ter 6 colunas TSV, veio $($cols.Count) ($($lines1[-1]))"
        if ($cols.Count -eq 6) {
            Assert-True ($cols[2] -ceq 'allow')   "2: wouldDecision deveria ser allow, veio '$($cols[2])'"
            Assert-True ($cols[3] -ceq 'decided') "2: outcome deveria ser decided, veio '$($cols[3])'"
            Assert-True ($cols[5] -ceq 'hot')     "2: path deveria ser hot, veio '$($cols[5])'"
            $lat = 0.0
            $okLat = [double]::TryParse($cols[4], [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$lat)
            Assert-True $okLat "2: latencyMs nao parseavel como double invariante ('$($cols[4])')"
            Assert-True (-not [string]::IsNullOrWhiteSpace($cols[1])) "2: requestId vazio"
        }
    }

    # Caso 3: privacidade -- a sentinela do command NAO aparece em nenhuma linha do log
    $vazou = $false
    foreach ($ln in $lines1) { if ($ln -like ('*' + $sentinela + '*')) { $vazou = $true; break } }
    Assert-True (-not $vazou) "3: a sentinela do comando vazou no log de medicao (privacidade §7)"

    # =============================================================================================
    # Caso 4: servidor FALSO responde "defer".
    # =============================================================================================
    $dep4 = New-PtuClientDeploy -NoDaemon; $deploys.Add($dep4)
    $exe4 = Get-PtuExePath -DeployDir $dep4
    $id4  = Get-PtuDeployIdentity -DeployDir $dep4
    $log4 = Get-PtuObserveLogPath -Hash $id4.IdentityHash; $obsLogs.Add($log4)
    Clear-PtuFile -Path $log4
    $out4 = Invoke-PtuObserveAgainstFake -Payload 'defer' -Command 'git status' -DeployDir $dep4 -ExePath $exe4 -PipeName $id4.Names.PipeName
    Assert-True ((Get-PtuDecisionField -Json $out4) -ceq 'defer') "4: observe deveria devolver defer (out=$out4)"
    $lines4 = @(Read-PtuObserveLines -Path $log4)
    Assert-True ($lines4.Count -ge 1) "4: log de medicao vazio/ausente ($log4)"
    if ($lines4.Count -ge 1) {
        $cols4 = @($lines4[-1] -split "`t")
        if ($cols4.Count -eq 6) { Assert-True ($cols4[2] -ceq 'defer') "4: wouldDecision deveria ser defer, veio '$($cols4[2])'" }
    }

    # =============================================================================================
    # Caso 5: caminho FRIO -- canal ausente e SEM script de daemon (ColdPath nao spawna daemon real).
    # =============================================================================================
    $dep5 = New-PtuClientDeploy -NoDaemon; $deploys.Add($dep5)
    $exe5 = Get-PtuExePath -DeployDir $dep5
    $id5  = Get-PtuDeployIdentity -DeployDir $dep5
    $log5 = Get-PtuObserveLogPath -Hash $id5.IdentityHash; $obsLogs.Add($log5)
    Clear-PtuFile -Path $log5
    $json5 = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $dep5 } | ConvertTo-Json -Compress
    $out5 = Invoke-PtuClientExe -ExePath $exe5 -Stdin $json5 -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $dep5 } -ExeArgs @('--observe')
    Assert-True ((Get-PtuDecisionField -Json $out5) -ceq 'defer') "5: observe frio deveria devolver defer (out=$out5)"
    $lines5 = @(Read-PtuObserveLines -Path $log5)
    Assert-True ($lines5.Count -ge 1) "5: log de medicao vazio/ausente ($log5)"
    if ($lines5.Count -ge 1) {
        $cols5 = @($lines5[-1] -split "`t")
        if ($cols5.Count -eq 6) {
            Assert-True ($cols5[3] -ceq 'cold') "5: outcome deveria ser cold, veio '$($cols5[3])'"
            Assert-True ($cols5[5] -ceq 'cold') "5: path deveria ser cold, veio '$($cols5[5])'"
        }
    }
}
finally {
    foreach ($d in $deploys) { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue } }
    foreach ($l in $obsLogs) { Clear-PtuFile -Path $l }
}

if ($failures.Count -gt 0) {
    Write-Host ("FALHAS ({0}):" -f $failures.Count)
    foreach ($f in $failures) { Write-Host "  - $f" }
    Write-Host "FAIL: Test-ClaudeCodePreToolUseSafeAllowObserveSelfTest.ps1"
    exit 1
}
Write-Host "OK: Test-ClaudeCodePreToolUseSafeAllowObserveSelfTest.ps1"
exit 0
