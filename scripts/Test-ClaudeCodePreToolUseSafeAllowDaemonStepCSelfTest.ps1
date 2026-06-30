#requires -Version 7.4
<#
.SYNOPSIS
Self-test do PASSO C (daemon PreToolUse auto-allow do Claude Code):
scripts/ClaudeCodePreToolUseSafeAllowDaemon.ps1. Sentinela de sucesso: "OK:" na ultima linha.

.DESCRIPTION
PRECURSOR, NAO o gate. O GATE de seguranca completo (§8) e' o Passo E, sob o nome canonico
RESERVADO Test-ClaudeCodePreToolUseSafeAllowDaemonSelfTest.ps1 (ainda nao criado). Este arquivo
cobre so a FATIA do Passo C, sem o cliente NativeAOT (Passo D) e sem a bateria adversarial inteira
do §8: subida/singleton/protocolo/staleness/cap, com um cliente de named pipe em PowerShell.

Roda o daemon a partir de um DEPLOY DIR temporario (copia plana dos scripts + PtuCanon.dll +
marcador .ptu-safe-allow-root), igual ao layout de producao do Passo G, para que as edicoes de
staleness sejam em COPIAS — nunca nos arquivos reais do repo. Exige a DLL buildada (ptu-lib).
Tudo em temp, limpo no fim; nao toca arquivos versionados.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scripts   = $PSScriptRoot
$repo      = Split-Path -Parent $scripts
$dllSrc    = Join-Path $repo 'ptu-native\lib\bin\Release\net8.0\PtuCanon.dll'
$idScript  = Join-Path $scripts 'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1'
if (-not (Test-Path -LiteralPath $dllSrc)) {
    throw "DLL nao buildada: $dllSrc -- rode: dotnet build ptu-native/lib/ptu-lib.csproj -c Release -nodeReuse:false -p:UseSharedCompilation=false --no-incremental"
}

$failures = [System.Collections.Generic.List[string]]::new()
function Assert-True { param([bool] $Cond, [string] $Msg) if (-not $Cond) { $script:failures.Add($Msg) } }

# Carrega [Ptu.*] no PROCESSO DO TESTE (cap in-process + identidade p/ nome do pipe).
. $idScript
if (-not ('Ptu.Canon' -as [type])) { Add-Type -Path $dllSrc }
$pin = [Ptu.BuildPin]::Value
$ver = '1.0.0'

# --------------------------------------------------------------------------------------------------
# Infra
# --------------------------------------------------------------------------------------------------
$deployFiles = @(
    'ClaudeCodePreToolUseSafeAllowDaemon.ps1',
    'ClaudeCodePreToolUseSafeAllowSupport.ps1',
    'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1',
    'Get-ClaudeCodeBashSafeSegments.py',
    'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
)
function New-PtuDeploy {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-cselftest-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    foreach ($f in $deployFiles) { Copy-Item -LiteralPath (Join-Path $scripts $f) -Destination (Join-Path $dir $f) -Force }
    Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $dir 'PtuCanon.dll') -Force
    [System.IO.File]::WriteAllText((Join-Path $dir '.ptu-safe-allow-root'), '')
    return $dir
}
function Get-PtuDeployPipe {
    param([string] $DeployDir)
    $id = Get-PtuIdentity -StartDirectory $DeployDir -DllPath (Join-Path $DeployDir 'PtuCanon.dll') -Roots @($DeployDir)
    if ($null -eq $id) { throw "identidade nula p/ deploy $DeployDir" }
    return $id.Names.PipeName
}
function Start-PtuTestDaemon {
    param([string] $DeployDir)
    $daemon = Join-Path $DeployDir 'ClaudeCodePreToolUseSafeAllowDaemon.ps1'
    return Start-Process -FilePath 'pwsh' -PassThru -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-File', $daemon, '-Roots', $DeployDir, '-RequestTimeoutMs', '600')
}
function Connect-PtuPipe {
    param([string] $PipeName, [int] $TimeoutMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        $c = [System.IO.Pipes.NamedPipeClientStream]::new('.', $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
        try { $c.Connect(200); return $c } catch { $c.Dispose(); Start-Sleep -Milliseconds 80 }
    }
    return $null
}
function Read-PtuResp {
    param($Stream, [int] $TimeoutMs)
    $h = [byte[]]::new(7); $off = 0
    while ($off -lt 7) {
        $t = $Stream.ReadAsync($h, $off, 7 - $off)
        if (-not $t.Wait($TimeoutMs)) { return $null }
        $k = $t.Result; if ($k -le 0) { return $null }; $off += $k
    }
    $n = ([int]$h[3] -shl 24) -bor ([int]$h[4] -shl 16) -bor ([int]$h[5] -shl 8) -bor [int]$h[6]
    if ($n -lt 0 -or $n -gt 65536) { return $null }
    $b = [byte[]]::new($n); $off = 0
    while ($off -lt $n) {
        $t = $Stream.ReadAsync($b, $off, $n - $off)
        if (-not $t.Wait($TimeoutMs)) { return $null }
        $k = $t.Result; if ($k -le 0) { return $null }; $off += $k
    }
    return [System.Text.Encoding]::UTF8.GetString($b)
}
function Send-PtuRaw {
    # Envia um frame ARBITRARIO (header + payload) e le a resposta. Retorna a string ou '<none>'.
    param([string] $PipeName, [byte] $Magic, [int] $ProtoVer, [int] $DeclaredLen, [byte[]] $Payload)
    $c = Connect-PtuPipe -PipeName $PipeName -TimeoutMs 4000
    if ($null -eq $c) { return '<no-pipe>' }
    try {
        $hdr = [byte[]]::new(7)
        $hdr[0] = $Magic
        $hdr[1] = [byte](($ProtoVer -shr 8) -band 0xFF); $hdr[2] = [byte]($ProtoVer -band 0xFF)
        $hdr[3] = [byte](($DeclaredLen -shr 24) -band 0xFF); $hdr[4] = [byte](($DeclaredLen -shr 16) -band 0xFF)
        $hdr[5] = [byte](($DeclaredLen -shr 8) -band 0xFF); $hdr[6] = [byte]($DeclaredLen -band 0xFF)
        $c.Write($hdr, 0, 7)
        if ($null -ne $Payload -and $Payload.Length -gt 0) { $c.Write($Payload, 0, $Payload.Length) }
        $c.Flush()
        if ($Magic -eq 2) { return '<shutdown>' }
        $r = Read-PtuResp -Stream $c -TimeoutMs 4000
        if ($null -eq $r) { return '<none>' }
        return $r
    } finally { $c.Dispose() }
}
function Send-PtuReq {
    # Frame de DADOS bem-formado (magic=1, protoVer=1) com payload de hook JSON.
    param([string] $PipeName, [string] $Tool, [string] $Cmd, [string] $Cwd, [string] $ReqId,
          [string] $Pin = $pin, [string] $Ver = $ver)
    $json = @{ tool_name = $Tool; tool_input = @{ command = $Cmd }; cwd = $Cwd
               ptuSafeAllowVersion = $Ver; buildContractPin = $Pin; requestId = $ReqId } | ConvertTo-Json -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Send-PtuRaw -PipeName $PipeName -Magic 1 -ProtoVer 1 -DeclaredLen $bytes.Length -Payload $bytes
}
function Stop-PtuTestDaemon {
    param($Proc, [string] $PipeName)
    try { [void](Send-PtuRaw -PipeName $PipeName -Magic 2 -ProtoVer 1 -DeclaredLen 1 -Payload ([byte[]]@(0x78))) } catch {}
    if (-not $Proc.WaitForExit(6000)) { try { $Proc.Kill() } catch {} }
}

$deploys = [System.Collections.Generic.List[string]]::new()
try {
    # ============================================================================================
    # A) Subida + decisao + barreiras + protocolo adversarial (daemon unico)
    # ============================================================================================
    $depA = New-PtuDeploy; $deploys.Add($depA)
    $pipeA = Get-PtuDeployPipe -DeployDir $depA
    $procA = Start-PtuTestDaemon -DeployDir $depA
    $ready = Connect-PtuPipe -PipeName $pipeA -TimeoutMs 20000
    Assert-True ($null -ne $ready) "A: pipe nao ficou conectavel (daemon nao subiu)"
    if ($null -ne $ready) { $ready.Dispose() }

    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status'  -Cwd $depA -ReqId 'a1') -ceq 'allow') "A1: git status in-scope != allow"
    $outDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-cself-out-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status'  -Cwd $outDir -ReqId 'a2') -ceq 'defer') "A2: out-of-scope != defer"
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'rm -rf /'    -Cwd $depA -ReqId 'a3') -ceq 'defer') "A3: rm -rf != defer"
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git log | head' -Cwd $depA -ReqId 'a4') -ceq 'allow') "A4: git log|head != allow"
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'PowerShell' -Cmd 'x' -Cwd $depA -ReqId 'a5') -ceq 'defer') "A5: tool PowerShell != defer"
    # barreiras de handshake
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId 'a6' -Pin 'PIN-ERRADO') -ceq 'defer') "A6: pin errado != defer"
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId 'a7' -Ver '9.9.9') -ceq 'defer') "A7: versao errada != defer"
    # protocolo adversarial
    $okBytes = [System.Text.Encoding]::UTF8.GetBytes((@{ tool_name='Bash'; tool_input=@{command='git status'}; cwd=$depA; ptuSafeAllowVersion=$ver; buildContractPin=$pin; requestId='adv' } | ConvertTo-Json -Compress))
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 9 -ProtoVer 1 -DeclaredLen $okBytes.Length -Payload $okBytes) -ceq 'defer') "A8: magic desconhecido != defer"
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 2 -DeclaredLen $okBytes.Length -Payload $okBytes) -ceq 'defer') "A9: protocolVersion errado != defer"
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen 70000 -Payload ([byte[]]@())) -ceq 'defer') "A10: len>64KB != defer"
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen 50 -Payload ([byte[]]@(0x7B))) -ceq 'defer') "A11: truncado (declara 50, manda 1) != defer"
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen 0 -Payload ([byte[]]@())) -ceq 'defer') "A12: payload vazio != defer"
    $emptyJson = [System.Text.Encoding]::UTF8.GetBytes('{}')
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen $emptyJson.Length -Payload $emptyJson) -ceq 'defer') "A13: JSON {} != defer"
    # daemon segue servindo apos a saraivada adversarial
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId 'a14') -ceq 'allow') "A14: daemon nao serve apos adversarial"

    # ============================================================================================
    # B) Singleton: 2o daemon sai cedo; 1o segue servindo
    # ============================================================================================
    $procB2 = Start-PtuTestDaemon -DeployDir $depA
    Assert-True ($procB2.WaitForExit(8000)) "B: 2o daemon nao saiu (singleton falhou)"
    if ($procB2.HasExited) { Assert-True ($procB2.ExitCode -eq 0) "B: 2o daemon saiu com codigo != 0" }
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId 'b1') -ceq 'allow') "B: 1o daemon parou de servir apos 2o subir"
    Stop-PtuTestDaemon -Proc $procA -PipeName $pipeA
    Assert-True ($procA.HasExited) "B: shutdown opcode nao encerrou o daemon"

    # ============================================================================================
    # C) Cap da canonicalizacao (C1, in-process): LIMITE POR CAP sob N timeouts
    # ============================================================================================
    $cap = 3
    $res = @()
    for ($i = 0; $i -lt 6; $i++) { $res += [Ptu.CwdWorker]::CanonicalizeSlowForTest(4000, 40, $cap) }
    Assert-True ([Ptu.CwdWorker]::InFlight() -le $cap) "C: InFlight ($([Ptu.CwdWorker]::InFlight())) > cap ($cap)"
    Assert-True (@($res | Where-Object { $_ -ceq [Ptu.CwdWorker]::CapExceeded }).Count -ge ($res.Count - $cap)) "C: excedentes do cap nao retornaram CapExceeded"
    Assert-True (@($res | Where-Object { $_ -ceq [Ptu.CwdWorker]::TimedOut }).Count -le $cap) "C: mais timeouts presos que o cap"

    # ============================================================================================
    # D) Staleness Support (re-dot-source): editar a COPIA muda a decisao
    # ============================================================================================
    $depD = New-PtuDeploy; $deploys.Add($depD)
    $pipeD = Get-PtuDeployPipe -DeployDir $depD
    $procD = Start-PtuTestDaemon -DeployDir $depD
    $rd = Connect-PtuPipe -PipeName $pipeD -TimeoutMs 20000; if ($null -ne $rd) { $rd.Dispose() }
    Assert-True ((Send-PtuReq -PipeName $pipeD -Tool 'Bash' -Cmd 'git status' -Cwd $depD -ReqId 'd1') -ceq 'allow') "D: baseline pre-edicao != allow"
    $supCopy = Join-Path $depD 'ClaudeCodePreToolUseSafeAllowSupport.ps1'
    $supText = [System.IO.File]::ReadAllText($supCopy).Replace("`$script:PtuSafeAllowVersion = '1.0.0'", "`$script:PtuSafeAllowVersion = '1.0.1'")
    [System.IO.File]::WriteAllText($supCopy, $supText, ([System.Text.UTF8Encoding]::new($false)))
    (Get-Item -LiteralPath $supCopy).LastWriteTimeUtc = [System.DateTime]::UtcNow.AddSeconds(2)
    # apos re-dot-source, a versao do daemon vira 1.0.1 -> requisicao com '1.0.0' agora defere
    Assert-True ((Send-PtuReq -PipeName $pipeD -Tool 'Bash' -Cmd 'git status' -Cwd $depD -ReqId 'd2' -Ver '1.0.0') -ceq 'defer') "D: staleness do Support nao re-dot-sourceou (ainda allow com versao velha)"
    Assert-True ((Send-PtuReq -PipeName $pipeD -Tool 'Bash' -Cmd 'git status' -Cwd $depD -ReqId 'd3' -Ver '1.0.1') -ceq 'allow') "D: apos reload, versao nova nao volta a allow"
    Stop-PtuTestDaemon -Proc $procD -PipeName $pipeD

    # ============================================================================================
    # E) Staleness DLL on-disk (defer-only): mexer no arquivo da DLL -> defer permanente
    # ============================================================================================
    $depE = New-PtuDeploy; $deploys.Add($depE)
    $pipeE = Get-PtuDeployPipe -DeployDir $depE
    $procE = Start-PtuTestDaemon -DeployDir $depE
    $re = Connect-PtuPipe -PipeName $pipeE -TimeoutMs 20000; if ($null -ne $re) { $re.Dispose() }
    Assert-True ((Send-PtuReq -PipeName $pipeE -Tool 'Bash' -Cmd 'git status' -Cwd $depE -ReqId 'e1') -ceq 'allow') "E: baseline pre-edicao != allow"
    $dllCopy = Join-Path $depE 'PtuCanon.dll'
    # No Windows a DLL CARREGADA nao pode ser modificada in-place, mas PODE ser renomeada (CoreCLR
    # abre com FILE_SHARE_DELETE). A substituicao REAL e' rename-do-velho + novo arquivo no mesmo path
    # -- e a staleness do daemon hasheia o ARQUIVO on-disk (nao o assembly em memoria) -> defer-only.
    [System.IO.File]::Move($dllCopy, "$dllCopy.old")
    $orig = [System.IO.File]::ReadAllBytes($dllSrc)
    $tampered = [byte[]]::new($orig.Length + 1)
    [System.Array]::Copy($orig, $tampered, $orig.Length); $tampered[$orig.Length] = 0
    [System.IO.File]::WriteAllBytes($dllCopy, $tampered)
    (Get-Item -LiteralPath $dllCopy).LastWriteTimeUtc = [System.DateTime]::UtcNow.AddSeconds(2)
    Assert-True ((Send-PtuReq -PipeName $pipeE -Tool 'Bash' -Cmd 'git status' -Cwd $depE -ReqId 'e2') -ceq 'defer') "E: DLL alterada on-disk nao deu defer"
    Assert-True ((Send-PtuReq -PipeName $pipeE -Tool 'Bash' -Cmd 'git status' -Cwd $depE -ReqId 'e3') -ceq 'defer') "E: defer-only nao e' permanente (voltou a allow)"
    Stop-PtuTestDaemon -Proc $procE -PipeName $pipeE
}
finally {
    foreach ($d in $deploys) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Error $f -ErrorAction Continue }
    throw "FALHA: Test-ClaudeCodePreToolUseSafeAllowDaemonStepCSelfTest ($($failures.Count) assercao(es))"
}
Write-Output "OK: Test-ClaudeCodePreToolUseSafeAllowDaemonStepCSelfTest.ps1"
