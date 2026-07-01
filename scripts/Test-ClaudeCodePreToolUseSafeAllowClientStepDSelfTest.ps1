#requires -Version 7.4
<#
.SYNOPSIS
Self-test do PASSO D (cliente NativeAOT do hook PreToolUse auto-allow do Claude Code):
ptu-native/client (ptu-client.exe). Sentinela de sucesso: "OK:" na ultima linha.

.DESCRIPTION
PRECURSOR, NAO o gate. O GATE de seguranca completo (§8) e' o Passo E, no arquivo canonico
Test-ClaudeCodePreToolUseSafeAllowDaemonSelfTest.ps1 (JA CRIADO; ver esse arquivo). Este arquivo
cobre so a FATIA do Passo D:
  A) paridade de identidade cliente[C#] <-> daemon[PS] (env-presente, env-ausente->default, invalida) + pin;
  B) parsing ESTRITO da resposta (servidor de pipe PS FALSO: caso feliz allow/defer + saraivada hostil);
  C) paridade do JSON §3.1 cliente <-> decisor in-process;
  D) invariante: o cliente ISOLADO (sem daemon) NUNCA emite allow;
  E) identidade invalida -> defer + log identity-invalid (presenca + ACL so-usuario + SEM command);
  F) dispara-e-sai com o DAEMON REAL (frio -> defer + spawn; quente -> allow; out-of-scope -> defer; shutdown).

Roda o EXE AOT a partir de um DEPLOY DIR temporario (copia plana exe + PtuCanon.dll + scripts do
daemon + marcador .ptu-safe-allow-root), igual ao layout de producao do Passo G. Exige o EXE publicado
(NativeAOT) e a DLL buildada. Tudo em temp, limpo no fim; nao toca arquivos versionados.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scripts = $PSScriptRoot
$repo    = Split-Path -Parent $scripts
$exeSrc  = Join-Path $repo 'ptu-native\client\bin\x64\Release\net8.0\win-x64\publish\ptu-client.exe'
$dllSrc  = Join-Path $repo 'ptu-native\lib\bin\Release\net8.0\PtuCanon.dll'
$idScript = Join-Path $scripts 'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1'
$decisor  = Join-Path $scripts 'Invoke-ClaudeCodePreToolUseSafeAllow.ps1'

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
function Bytes { param([string] $S) return ,([System.Text.Encoding]::UTF8.GetBytes($S)) }

$identityInvalidLog = Join-Path $env:LOCALAPPDATA 'ClaudeCodePreToolUseSafeAllow\ptu-client-identity-invalid.log'

# --------------------------------------------------------------------------------------------------
# Infra
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
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-dselftest-" + [System.Guid]::NewGuid().ToString('N'))
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
    # SAIDA §3.1: 'allow' -> 'allow'; ABSTER = saida VAZIA (nenhum permissionDecision) -> sentinela
    # '(abstain)'. Um 'defer'/'ask' LITERAL na boca (regressao) cai no parse e devolve o valor -> pego.
    param([string] $Json)
    if ([string]::IsNullOrWhiteSpace($Json)) { return '(abstain)' }
    try { $o = $Json | ConvertFrom-Json; return [string]$o.hookSpecificOutput.permissionDecision } catch { return '<unparseable>' }
}
function ConvertTo-PtuNormalized {
    # Estrutura §3.1 com o valor de permissionDecisionReason normalizado (comparador de paridade do §8).
    param([string] $Json)
    $o = $Json | ConvertFrom-Json
    $o.hookSpecificOutput.permissionDecisionReason = 'NORM'
    return ($o | ConvertTo-Json -Compress -Depth 6)
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

# Servidor de pipe FALSO (thread job): aceita 1 conexao, dreana o request, devolve UM frame arbitrario.
$fakeServer = {
    param($PipeName, $Magic, $Proto, $DeclaredLen, $Payload)
    $server = [System.IO.Pipes.NamedPipeServerStream]::new(
        $PipeName, [System.IO.Pipes.PipeDirection]::InOut, 1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous)
    try {
        $ct = $server.WaitForConnectionAsync()
        if (-not $ct.Wait(8000)) { return }
        # dreana o request (7 hdr + payload), best-effort
        $hdr = [byte[]]::new(7); $off = 0
        while ($off -lt 7) { $t = $server.ReadAsync($hdr, $off, 7 - $off); if (-not $t.Wait(2000)) { break }; $k = $t.Result; if ($k -le 0) { break }; $off += $k }
        if ($off -eq 7) {
            $rlen = ([int]$hdr[3] -shl 24) -bor ([int]$hdr[4] -shl 16) -bor ([int]$hdr[5] -shl 8) -bor [int]$hdr[6]
            if ($rlen -gt 0 -and $rlen -le 65536) {
                $rb = [byte[]]::new($rlen); $o2 = 0
                while ($o2 -lt $rlen) { $t = $server.ReadAsync($rb, $o2, $rlen - $o2); if (-not $t.Wait(2000)) { break }; $k = $t.Result; if ($k -le 0) { break }; $o2 += $k }
            }
        }
        # devolve o frame arbitrario
        $rh = [byte[]]::new(7)
        $rh[0] = [byte]$Magic
        $rh[1] = [byte](([int]$Proto -shr 8) -band 0xFF); $rh[2] = [byte]([int]$Proto -band 0xFF)
        $rh[3] = [byte](([int]$DeclaredLen -shr 24) -band 0xFF); $rh[4] = [byte](([int]$DeclaredLen -shr 16) -band 0xFF)
        $rh[5] = [byte](([int]$DeclaredLen -shr 8) -band 0xFF); $rh[6] = [byte]([int]$DeclaredLen -band 0xFF)
        $server.Write($rh, 0, 7)
        if ($null -ne $Payload -and $Payload.Length -gt 0) { $server.Write($Payload, 0, $Payload.Length) }
        $server.Flush()
        Start-Sleep -Milliseconds 300
    } finally { $server.Dispose() }
}

function Test-PtuStrictResponse {
    # Sobe o servidor falso com a resposta dada, roda o EXE e confere a decisao final.
    param([string] $Name, [string] $PipeName, [string] $ExePath, [string] $Deploy, [string] $Stdin,
          [int] $Magic, [int] $Proto, [int] $DeclaredLen, [byte[]] $Payload, [string] $Expected)
    $job = Start-ThreadJob -ScriptBlock $fakeServer -ArgumentList $PipeName, $Magic, $Proto, $DeclaredLen, $Payload
    try {
        if (-not (Wait-PtuPipeExists -PipeName $PipeName -TimeoutMs 6000)) { Assert-True $false "${Name}: pipe falso nao apareceu"; return }
        $out = Invoke-PtuClientExe -ExePath $ExePath -Stdin $Stdin -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $Deploy }
        $dec = Get-PtuDecisionField -Json $out
        Assert-True ($dec -ceq $Expected) "${Name}: esperado '$Expected', veio '$dec' (out=$out)"
    } finally {
        [void](Wait-Job -Job $job -Timeout 12000)
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

# Helpers de pipe p/ falar com o DAEMON REAL (secao F).
function Connect-PtuPipe {
    param([string] $PipeName, [int] $TimeoutMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        $c = [System.IO.Pipes.NamedPipeClientStream]::new('.', $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
        try { $c.Connect(200); return $c } catch { $c.Dispose(); Start-Sleep -Milliseconds 80 }
    }
    return $null
}
function Send-PtuShutdown {
    param([string] $PipeName)
    $c = Connect-PtuPipe -PipeName $PipeName -TimeoutMs 4000
    if ($null -eq $c) { return }
    try {
        $hdr = [byte[]]::new(7); $hdr[0] = 2; $hdr[2] = 1; $hdr[6] = 1
        $c.Write($hdr, 0, 7); $c.Write([byte[]]@(0x78), 0, 1); $c.Flush()
    } catch {} finally { $c.Dispose() }
}

$deploys = [System.Collections.Generic.List[string]]::new()
$clientLogsToClean = [System.Collections.Generic.List[string]]::new()
try {
    # ==============================================================================================
    # A) Identidade: paridade cliente<->PS + pin (env-presente, env-ausente->default, invalida)
    # ==============================================================================================
    $depA = New-PtuClientDeploy; $deploys.Add($depA)
    $exeA = Get-PtuExePath -DeployDir $depA
    $idA  = Get-PtuDeployIdentity -DeployDir $depA
    $clientLogsToClean.Add($idA.Names.ClientLogPath)

    $pinExe = Invoke-PtuClientExe -ExePath $exeA -Stdin $null -ExeArgs @('--emit-pin')
    Assert-True ($pinExe -ceq [Ptu.BuildPin]::Value) "A: pin cliente != pin DLL (exe=$pinExe)"

    $hashEnv = (Invoke-PtuClientExe -ExePath $exeA -Stdin $null -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depA } -ExeArgs @('--emit-identity', $depA)).Trim()
    Assert-True ($hashEnv -ceq $idA.IdentityHash) "A: hash cliente != hash PS (env-presente) exe=$hashEnv ps=$($idA.IdentityHash)"

    $idADefault = Get-PtuIdentity -StartDirectory $depA -DllPath (Join-Path $depA 'PtuCanon.dll')   # Roots $null -> default
    $hashDef = (Invoke-PtuClientExe -ExePath $exeA -Stdin $null -EnvOverride $null -ExeArgs @('--emit-identity', $depA)).Trim()
    Assert-True ($null -ne $idADefault) "A: identidade PS nula (env-ausente)"
    if ($null -ne $idADefault) {
        Assert-True ($hashDef -ceq $idADefault.IdentityHash) "A: hash cliente != hash PS (env-ausente->default) exe=$hashDef ps=$($idADefault.IdentityHash)"
        Assert-True ($hashEnv -cne $hashDef) "A: env-presente e env-ausente deram o MESMO hash (roots distintos deveriam divergir)"
    }
    $depNoMark = New-PtuClientDeploy -NoMarker; $deploys.Add($depNoMark)
    $hashInval = (Invoke-PtuClientExe -ExePath (Get-PtuExePath -DeployDir $depNoMark) -Stdin $null -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depNoMark } -ExeArgs @('--emit-identity', $depNoMark)).Trim()
    Assert-True ($hashInval -ceq 'IDENTITY-INVALID') "A: sem marcador deveria dar IDENTITY-INVALID (veio $hashInval)"

    # ==============================================================================================
    # B) Parsing ESTRITO da resposta (servidor falso): caso feliz + saraivada hostil
    # ==============================================================================================
    $depB = New-PtuClientDeploy -NoDaemon; $deploys.Add($depB)   # sem daemon: so o servidor falso responde
    $exeB = Get-PtuExePath -DeployDir $depB
    $idB  = Get-PtuDeployIdentity -DeployDir $depB
    $pipeB = $idB.Names.PipeName
    $clientLogsToClean.Add($idB.Names.ClientLogPath)
    $jsonB = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depB } | ConvertTo-Json -Compress

    # validos
    Test-PtuStrictResponse -Name 'B-allow'  -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 5 -Payload (Bytes 'allow') -Expected 'allow'
    Test-PtuStrictResponse -Name 'B-defer'  -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 5 -Payload (Bytes 'defer') -Expected '(abstain)'
    # hostis -> sempre defer
    Test-PtuStrictResponse -Name 'B-trailspace'  -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 6 -Payload (Bytes 'allow ') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-leadspace'   -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 6 -Payload (Bytes ' allow') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-upper'       -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 5 -Payload (Bytes 'ALLOW') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-nul'         -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 6 -Payload ([byte[]]@(97,108,108,111,119,0)) -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-allowdefer'  -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 10 -Payload (Bytes 'allowdefer') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-json'        -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 20 -Payload (Bytes '{"decision":"allow"}') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-magic2'      -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 2 -Proto 1 -DeclaredLen 5 -Payload (Bytes 'allow') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-magic9'      -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 9 -Proto 1 -DeclaredLen 5 -Payload (Bytes 'allow') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-proto2'      -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 2 -DeclaredLen 5 -Payload (Bytes 'allow') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-lenoverflow' -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 70000 -Payload (Bytes 'allow') -Expected '(abstain)'
    Test-PtuStrictResponse -Name 'B-truncated'   -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 50 -Payload (Bytes 'al') -Expected '(abstain)'

    # ==============================================================================================
    # C) Paridade do JSON §3.1 cliente <-> decisor in-process (allow e defer)
    # ==============================================================================================
    $jsonAllow = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depB } | ConvertTo-Json -Compress
    $outDirC = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-dself-out-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $outDirC -Force | Out-Null
    $jsonDefer = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $outDirC } | ConvertTo-Json -Compress

    # cliente: allow via servidor falso; defer via servidor falso
    $exeAllowOut = $null
    $job = Start-ThreadJob -ScriptBlock $fakeServer -ArgumentList $pipeB, 1, 1, 5, (Bytes 'allow')
    try {
        if (Wait-PtuPipeExists -PipeName $pipeB -TimeoutMs 6000) {
            $exeAllowOut = Invoke-PtuClientExe -ExePath $exeB -Stdin $jsonAllow -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depB }
        }
    } finally { [void](Wait-Job -Job $job -Timeout 12000); Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }

    $exeDeferOut = $null
    $job = Start-ThreadJob -ScriptBlock $fakeServer -ArgumentList $pipeB, 1, 1, 5, (Bytes 'defer')
    try {
        if (Wait-PtuPipeExists -PipeName $pipeB -TimeoutMs 6000) {
            $exeDeferOut = Invoke-PtuClientExe -ExePath $exeB -Stdin $jsonDefer -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depB }
        }
    } finally { [void](Wait-Job -Job $job -Timeout 12000); Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }

    # decisor in-process: allow (in-scope) e defer (out-of-scope)
    $prevRoots = $env:PTU_SAFE_ALLOW_ROOTS
    $env:PTU_SAFE_ALLOW_ROOTS = $depB
    try {
        $decAllowOut = & $decisor -InputJson $jsonAllow
        $decDeferOut = & $decisor -InputJson $jsonDefer
    } finally {
        if ($null -eq $prevRoots) { Remove-Item Env:PTU_SAFE_ALLOW_ROOTS -ErrorAction SilentlyContinue } else { $env:PTU_SAFE_ALLOW_ROOTS = $prevRoots }
    }

    Assert-True ($null -ne $exeAllowOut -and (Get-PtuDecisionField $exeAllowOut) -ceq 'allow') "C: cliente nao deu allow no caso feliz (out=$exeAllowOut)"
    Assert-True ((Get-PtuDecisionField $decAllowOut) -ceq 'allow') "C: decisor in-process nao deu allow (out=$decAllowOut)"
    if ($null -ne $exeAllowOut) {
        $prefix = '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"'
        Assert-True ($exeAllowOut.StartsWith($prefix, [System.StringComparison]::Ordinal)) "C: prefixo §3.1 do cliente (allow) divergente (out=$exeAllowOut)"
        Assert-True ((ConvertTo-PtuNormalized $exeAllowOut) -ceq (ConvertTo-PtuNormalized $decAllowOut)) "C: §3.1 normalizado allow cliente != decisor"
    }
    # abster (defer interno): a boca §3.1 fica VAZIA nos dois lados (nenhum permissionDecision).
    Assert-True ((Get-PtuDecisionField $exeDeferOut) -ceq '(abstain)') "C: cliente nao absteve (out=[$exeDeferOut])"
    Assert-True ((Get-PtuDecisionField $decDeferOut) -ceq '(abstain)') "C: decisor in-process nao absteve (out=[$decDeferOut])"
    # Paridade da abstencao = ambos VAZIOS (byte-a-byte trivial: nada emitido).
    Assert-True ([string]::IsNullOrWhiteSpace($exeDeferOut) -and [string]::IsNullOrWhiteSpace($decDeferOut)) "C: abster deveria dar saida VAZIA nos dois (cli=[$exeDeferOut] dec=[$decDeferOut])"

    # ==============================================================================================
    # D) Invariante: cliente ISOLADO (deploy SEM daemon) NUNCA emite allow, nem in-scope
    # ==============================================================================================
    $depD = New-PtuClientDeploy -NoDaemon; $deploys.Add($depD)
    $exeD = Get-PtuExePath -DeployDir $depD
    $idD  = Get-PtuDeployIdentity -DeployDir $depD
    $clientLogsToClean.Add($idD.Names.ClientLogPath)
    $jsonD = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depD } | ConvertTo-Json -Compress
    for ($i = 0; $i -lt 3; $i++) {
        $o = Invoke-PtuClientExe -ExePath $exeD -Stdin $jsonD -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depD }
        Assert-True ((Get-PtuDecisionField $o) -ceq '(abstain)') "D: cliente isolado nao absteve (emitiu algo) (iter $i, out=[$o])"
    }

    # ==============================================================================================
    # E) Identidade invalida -> defer + log identity-invalid (presenca + ACL so-usuario + SEM command)
    # ==============================================================================================
    Remove-Item -LiteralPath $identityInvalidLog -Force -ErrorAction SilentlyContinue
    $depE = New-PtuClientDeploy -NoMarker; $deploys.Add($depE)
    $exeE = Get-PtuExePath -DeployDir $depE
    $jsonE = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = 'C:/qualquer' } | ConvertTo-Json -Compress
    $oE = Invoke-PtuClientExe -ExePath $exeE -Stdin $jsonE -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depE }
    Assert-True ((Get-PtuDecisionField $oE) -ceq '(abstain)') "E: identidade invalida nao absteve (out=[$oE])"
    Assert-True (Test-Path -LiteralPath $identityInvalidLog) "E: log identity-invalid nao foi gravado"
    if (Test-Path -LiteralPath $identityInvalidLog) {
        $logTxt = (Get-Content -Raw -LiteralPath $identityInvalidLog)
        Assert-True ($logTxt -match 'identity-invalid') "E: log nao contem o codigo identity-invalid"
        Assert-True (-not ($logTxt -match 'git status')) "E: log VAZOU o command (git status presente)"
        $acl = Get-Acl -LiteralPath $identityInvalidLog
        Assert-True ($acl.AreAccessRulesProtected) "E: ACL do log nao esta protegida (heranca ativa)"
        $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $foreign = @($acl.Access | Where-Object { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -cne $me.Value })
        Assert-True ($foreign.Count -eq 0) "E: ACL do log tem regra de outro principal ($($foreign.Count))"
    }
    Remove-Item -LiteralPath $identityInvalidLog -Force -ErrorAction SilentlyContinue

    # ==============================================================================================
    # F) Dispara-e-sai com o DAEMON REAL: frio -> defer + spawn; quente -> allow; out-of-scope -> defer
    # ==============================================================================================
    $depF = New-PtuClientDeploy; $deploys.Add($depF)
    $exeF = Get-PtuExePath -DeployDir $depF
    $idF  = Get-PtuDeployIdentity -DeployDir $depF
    $pipeF = $idF.Names.PipeName
    $clientLogsToClean.Add($idF.Names.ClientLogPath)
    $jsonF = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depF } | ConvertTo-Json -Compress
    $outDirF = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-dself-fout-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $outDirF -Force | Out-Null
    $jsonFout = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $outDirF } | ConvertTo-Json -Compress

    try {
        $oCold = Invoke-PtuClientExe -ExePath $exeF -Stdin $jsonF -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depF }
        Assert-True ((Get-PtuDecisionField $oCold) -ceq '(abstain)') "F: frio (canal ausente) nao absteve (out=[$oCold])"

        $ready = Wait-PtuPipeExists -PipeName $pipeF -TimeoutMs 25000
        Assert-True $ready "F: daemon real nao subiu (pipe nao ficou disponivel)"
        if ($ready) {
            # O daemon recem-subido AQUECE nos primeiros round-trips (python/JIT): as primeiras
            # requisicoes podem estourar o deadline quente de 80 ms e deferir (fail-closed CORRETO, por
            # design §9-0e). Provamos que o hot-path com daemon REAL EVENTUALMENTE da allow (estacionario).
            $allowed = $false
            for ($k = 0; $k -lt 12 -and -not $allowed; $k++) {
                $oHot = Invoke-PtuClientExe -ExePath $exeF -Stdin $jsonF -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depF }
                if ((Get-PtuDecisionField $oHot) -ceq 'allow') { $allowed = $true; break }
                Start-Sleep -Milliseconds 150
            }
            Assert-True $allowed "F: quente in-scope com daemon real nunca deu allow (warmup nao convergiu em 12 tentativas)"

            # Daemon agora QUENTE: out-of-scope deve deferir por ESCOPO (nao por warmup).
            $oHotOut = Invoke-PtuClientExe -ExePath $exeF -Stdin $jsonFout -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depF }
            Assert-True ((Get-PtuDecisionField $oHotOut) -ceq '(abstain)') "F: quente out-of-scope nao absteve (out=[$oHotOut])"
        }
    } finally {
        Send-PtuShutdown -PipeName $pipeF
        Start-Sleep -Milliseconds 500
        Remove-Item -LiteralPath $outDirF -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    foreach ($d in $deploys) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    foreach ($lg in $clientLogsToClean) { if ($lg) { Remove-Item -LiteralPath $lg -Force -ErrorAction SilentlyContinue } }
    Remove-Item -LiteralPath $identityInvalidLog -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Error $f -ErrorAction Continue }
    throw "FALHA: Test-ClaudeCodePreToolUseSafeAllowClientStepDSelfTest ($($failures.Count) assercao(es))"
}
Write-Output "OK: Test-ClaudeCodePreToolUseSafeAllowClientStepDSelfTest.ps1"
