#requires -Version 7.4
<#
.SYNOPSIS
GATE de seguranca canonico (§8) do daemon+cliente PreToolUse (auto-allow) do Claude Code. PASSO E
(claude-code-pretooluse-implementacao-v1-plan.md, linhas 190-227). Sentinela: "OK:" na ultima linha.

.DESCRIPTION
Este e' o GATE adversarial completo do conjunto daemon (Passo C) + cliente NativeAOT (Passo D). NAO
substitui os self-tests precursores Test-...DaemonStepCSelfTest.ps1 e Test-...ClientStepDSelfTest.ps1
(que ficam como precursores das suas fatias); este gate e' ADITIVO e cobre a bateria inteira do §8.

Sobe o DAEMON REAL e roda o CLIENTE AOT REAL a partir de DEPLOYS temporarios (copia plana exe +
PtuCanon.dll + scripts do daemon + marcador .ptu-safe-allow-root), igual ao layout de producao do
Passo G, para que as edicoes de staleness sejam em COPIAS — nunca nos arquivos reais do repo. Exige o
EXE publicado (NativeAOT) e a DLL buildada. Tudo em temp, limpo no fim; nao toca arquivos versionados.

Construido em sub-passos commitaveis (E-a..E-f); cada um mantem o arquivo VERDE com a sentinela no fim:
  E-a  infra + paridade nuclear (daemon<->in-process; cliente<->daemon §3.1; invariante do cliente);
  E-b  resposta/protocolo adversarial (daemon falso hostil; framing; handshake; downgrade de pin);
  E-c  segments + unicode;
  E-d  ACL (DACL efetiva) + identidade (2 compilacoes; ascensao; roots);
  E-e  escopo (junction; cwd indisponivel; fora de escopo; roots vazio);
  E-f  concorrencia + staleness bloqueante + resto (defer-only; roots ao vivo; privacidade; log de subida).

REUSO: os helpers (deploy temporario, servidor de pipe falso, Invoke-PtuClientExe, comparador §3.1,
frames) sao as MESMAS implementacoes provadas nos precursores StepC/StepD — copiadas aqui para manter
o gate auto-contido (padrao do repo), sem tocar nos precursores.
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
$pin = [Ptu.BuildPin]::Value
$ver = '1.0.0'

$failures = [System.Collections.Generic.List[string]]::new()
function Assert-True { param([bool] $Cond, [string] $Msg) if (-not $Cond) { $script:failures.Add($Msg) } }
function Bytes { param([string] $S) return ,([System.Text.Encoding]::UTF8.GetBytes($S)) }

# Log do cliente de caminho FIXO (identity-invalid); limpo no inicio/fim de quem o exercita.
$identityInvalidLog = Join-Path $env:LOCALAPPDATA 'ClaudeCodePreToolUseSafeAllow\ptu-client-identity-invalid.log'

# ==================================================================================================
# Infra de deploy (copia plana: exe + DLL + scripts do daemon + marcador) = layout do Passo G.
# ==================================================================================================
$deployScripts = @(
    'ClaudeCodePreToolUseSafeAllowDaemon.ps1',
    'ClaudeCodePreToolUseSafeAllowSupport.ps1',
    'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1',
    'Get-ClaudeCodeBashSafeSegments.py',
    'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
)
function New-PtuDeploy {
    # Deploy completo (exe+DLL+scripts+marcador). -NoDaemon: so exe+DLL (cliente isolado / servidor falso).
    # -NoMarker: sem .ptu-safe-allow-root (identidade INVALIDA -> defer/log).
    param([switch] $NoDaemon, [switch] $NoMarker)
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-eselftest-" + [System.Guid]::NewGuid().ToString('N'))
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
    param([string] $DeployDir, [string[]] $Roots)
    if ($null -eq $Roots) { $Roots = @($DeployDir) }
    $id = Get-PtuIdentity -StartDirectory $DeployDir -DllPath (Join-Path $DeployDir 'PtuCanon.dll') -Roots $Roots
    if ($null -eq $id) { throw "identidade nula p/ deploy $DeployDir" }
    return $id
}
function Get-PtuExePath { param([string] $DeployDir) return (Join-Path $DeployDir 'ptu-client.exe') }

function Invoke-PtuClientExe {
    # Roda o EXE alimentando stdin e capturando stdout CRU (preserva o '\n' final do cliente).
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
function Invoke-PtuDecisorProc {
    # Roda o decisor in-process COMO PROCESSO (pwsh -File), capturando stdout CRU do MESMO jeito que o
    # EXE -> a unica diferenca de whitespace final entre os dois lados some na normalizacao §3.1.
    param([string] $Json, [string] $Roots)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = 'pwsh'
    foreach ($a in @('-NoProfile', '-File', $decisor)) { [void]$psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.Environment.Remove('PTU_SAFE_ALLOW_ROOTS') | Out-Null
    if ($Roots) { $psi.Environment['PTU_SAFE_ALLOW_ROOTS'] = $Roots }
    $p = [System.Diagnostics.Process]::Start($psi)
    if ($null -ne $Json) { $p.StandardInput.Write($Json) }
    $p.StandardInput.Close()
    $out = $p.StandardOutput.ReadToEnd()
    [void]$p.WaitForExit(15000)
    return $out
}
function Get-PtuDecisionField {
    param([string] $Json)
    try { $o = $Json | ConvertFrom-Json; return [string]$o.hookSpecificOutput.permissionDecision } catch { return '<unparseable>' }
}
function ConvertTo-Ptu31Normalized {
    # Comparador §3.1 BYTE-A-BYTE: normaliza SO (a) o whitespace final e (b) o valor de
    # permissionDecisionReason -> placeholder. Tudo o mais (ordem dos 3 campos, casing das chaves,
    # ausencia de espacos, estrutura) e' comparado literalmente. Divergencia em qualquer um => FALHA.
    param([string] $Raw)
    if ($null -eq $Raw) { return '<null>' }
    $s = $Raw.TrimEnd("`r", "`n")
    return [regex]::Replace($s, '("permissionDecisionReason":")(.*?)(")', '${1}NORM${3}')
}
function Wait-PtuPipeExists {
    # Enumera por STRINGS ([IO.Directory]::GetFiles devolve "\\.\pipe\<nome>") em vez de
    # (Get-ChildItem).Name: a member-enumeration de .Name sobre os objetos de pipe do sistema LANCA sob
    # StrictMode quando um pipe transiente aparece sem a propriedade Name (flaky, depende do instante).
    param([string] $PipeName, [int] $TimeoutMs)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        try {
            foreach ($e in [System.IO.Directory]::GetFiles('\\.\pipe\')) {
                if ($e.Substring($e.LastIndexOf('\') + 1) -ceq $PipeName) { return $true }
            }
        } catch {}
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
    # Sobe o servidor falso com a resposta dada, roda o EXE e confere a decisao final (esperado defer/allow).
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

# Helpers de pipe p/ falar com o DAEMON REAL.
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
    # Envia um frame ARBITRARIO (header + payload) e le a resposta. Retorna a string ou sentinela.
    param([string] $PipeName, [byte] $Magic, [int] $ProtoVer, [int] $DeclaredLen, [byte[]] $Payload,
          [int] $RespTimeoutMs = 4000)
    $c = Connect-PtuPipe -PipeName $PipeName -TimeoutMs 4000
    if ($null -eq $c) { return '<no-pipe>' }
    try {
        $hdr = [byte[]]::new(7)
        $hdr[0] = $Magic
        $hdr[1] = [byte](($ProtoVer -shr 8) -band 0xFF); $hdr[2] = [byte]($ProtoVer -band 0xFF)
        $hdr[3] = [byte](($DeclaredLen -shr 24) -band 0xFF); $hdr[4] = [byte](($DeclaredLen -shr 16) -band 0xFF)
        $hdr[5] = [byte](($DeclaredLen -shr 8) -band 0xFF); $hdr[6] = [byte]($DeclaredLen -band 0xFF)
        # WriteAsync (nao Write sincrono): o pipe do daemon tem INBUFFER 0, entao enviar mais bytes do que
        # o daemon consome (frame adversarial com bytes orfaos) BLOQUEARIA um Write sincrono. Numa Task
        # nativa o write orfao fica pendente sem travar o teste (abandonado no Dispose); o que importa e' a
        # RESPOSTA do daemon (nunca 'allow' p/ lixo). Frame unico (header+payload concatenado).
        $wire = if ($null -ne $Payload -and $Payload.Length -gt 0) { [byte[]]($hdr + $Payload) } else { $hdr }
        $wt = $c.WriteAsync($wire, 0, $wire.Length)
        if ($Magic -eq 2) { try { [void]$wt.Wait(2000) } catch {}; return '<shutdown>' }
        $r = Read-PtuResp -Stream $c -TimeoutMs $RespTimeoutMs
        try { [void]$wt.Wait(500) } catch {}
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
function Send-PtuShutdown {
    param([string] $PipeName)
    $c = Connect-PtuPipe -PipeName $PipeName -TimeoutMs 4000
    if ($null -eq $c) { return }
    try {
        $hdr = [byte[]]::new(7); $hdr[0] = 2; $hdr[2] = 1; $hdr[6] = 1
        $c.Write($hdr, 0, 7); $c.Write([byte[]]@(0x78), 0, 1); $c.Flush()
    } catch {} finally { $c.Dispose() }
}
function Start-PtuTestDaemon {
    param([string] $DeployDir, [string[]] $Roots, [int] $RequestTimeoutMs = 600)
    if ($null -eq $Roots) { $Roots = @($DeployDir) }
    $daemon = Join-Path $DeployDir 'ClaudeCodePreToolUseSafeAllowDaemon.ps1'
    $argList = @('-NoProfile', '-File', $daemon, '-Roots') + $Roots + @('-RequestTimeoutMs', "$RequestTimeoutMs")
    return Start-Process -FilePath 'pwsh' -PassThru -WindowStyle Hidden -ArgumentList $argList
}
function Stop-PtuTestDaemon {
    param($Proc, [string] $PipeName)
    try { Send-PtuShutdown -PipeName $PipeName } catch {}
    if ($null -ne $Proc) {
        if (-not $Proc.WaitForExit(6000)) { try { $Proc.Kill() } catch {} }
    }
}

function New-PtuFrameBytes {
    # Monta os bytes de UM frame do wire (header 7B + payload). DeclaredLen<0 => usa Payload.Length.
    param([byte] $Magic, [int] $ProtoVer, [byte[]] $Payload, [int] $DeclaredLen = -1)
    $len = if ($DeclaredLen -ge 0) { $DeclaredLen } else { $Payload.Length }
    $hdr = [byte[]]::new(7)
    $hdr[0] = $Magic
    $hdr[1] = [byte](($ProtoVer -shr 8) -band 0xFF); $hdr[2] = [byte]($ProtoVer -band 0xFF)
    $hdr[3] = [byte](($len -shr 24) -band 0xFF); $hdr[4] = [byte](($len -shr 16) -band 0xFF)
    $hdr[5] = [byte](($len -shr 8) -band 0xFF); $hdr[6] = [byte]($len -band 0xFF)
    return ,([byte[]]($hdr + $Payload))
}
function Send-PtuTwoFramesReadOne {
    # Escreve DOIS frames numa MESMA conexao e tenta ler DUAS respostas: o daemon (single-threaded, 1
    # frame por conexao) deve responder so ao 1o (First) e nao emitir 2a resposta (Second = $null).
    param([string] $PipeName, [byte[]] $Frame1, [byte[]] $Frame2)
    $c = Connect-PtuPipe -PipeName $PipeName -TimeoutMs 4000
    if ($null -eq $c) { return [pscustomobject]@{ First = '<no-pipe>'; Second = $null } }
    try {
        # f1+f2 num unico WriteAsync (inbuffer-0: f2 fica orfao quando o daemon le so f1 e fecha; numa
        # Task nativa nao trava o teste). O daemon le 1 frame por conexao -> responde f1 e dispoe; f2 e'
        # descartado (sem 2a resposta).
        $wire = [byte[]]($Frame1 + $Frame2)
        $wt = $c.WriteAsync($wire, 0, $wire.Length)
        $r1 = Read-PtuResp -Stream $c -TimeoutMs 4000
        $r2 = Read-PtuResp -Stream $c -TimeoutMs 800
        try { [void]$wt.Wait(300) } catch {}
        return [pscustomobject]@{ First = $r1; Second = $r2 }
    } finally { $c.Dispose() }
}

# SIDs "estrangeiros" que JAMAIS podem aparecer na DACL dos artefatos de coordenacao (so-usuario):
# Everyone, Authenticated Users, NetworkService.
$script:PtuForeignSids = @('S-1-1-0', 'S-1-5-11', 'S-1-5-20')
function Test-PtuDaclUserOnly {
    # Assercao: a DACL (a) nao contem nenhum SID estrangeiro e (b) so tem regras p/ o SID corrente.
    param($Acl, [string] $Label)
    if ($null -eq $Acl) { Assert-True $false "$Label : DACL nula (nao inspecionada)"; return }
    $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $rules = $Acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier])
    $foreign = [System.Collections.Generic.List[string]]::new()
    $ownerOnly = $true
    foreach ($r in $rules) {
        $sid = $r.IdentityReference.Value
        if ($script:PtuForeignSids -contains $sid) { [void]$foreign.Add($sid) }
        if ($sid -cne $me) { $ownerOnly = $false }
    }
    Assert-True ($foreign.Count -eq 0) "$Label : DACL tem SID estrangeiro ($($foreign -join ','))"
    Assert-True $ownerOnly "$Label : DACL nao e' so-usuario (regra de outro principal)"
}
function Get-PtuPipeDacl {
    # DACL EFETIVA do pipe do daemon, lida via CLIENTE conectado (PipesAclExtensions.GetAccessControl).
    param([string] $PipeName)
    $c = Connect-PtuPipe -PipeName $PipeName -TimeoutMs 4000
    if ($null -eq $c) { return $null }
    try { return [System.IO.Pipes.PipesAclExtensions]::GetAccessControl($c) } catch { return $null } finally { $c.Dispose() }
}
function Get-PtuMutexDacl {
    # DACL EFETIVA de um named mutex vivo (MutexAcl.OpenExisting com ReadPermissions). $null se ausente.
    param([string] $MutexName)
    try {
        $m = [System.Threading.MutexAcl]::OpenExisting($MutexName, [System.Security.AccessControl.MutexRights]::ReadPermissions)
        try { return [System.Threading.ThreadingAclExtensions]::GetAccessControl($m) } finally { $m.Dispose() }
    } catch { return $null }
}

$deploys           = [System.Collections.Generic.List[string]]::new()
$clientLogsToClean = [System.Collections.Generic.List[string]]::new()
$daemons           = [System.Collections.Generic.List[object]]::new()
function Register-PtuDaemon { param($Proc, [string] $Pipe) $script:daemons.Add([pscustomobject]@{ Proc = $Proc; Pipe = $Pipe }) }

try {
    # ==============================================================================================
    # SECAO A (E-a) — Paridade nuclear: daemon<->in-process; cliente<->daemon §3.1; invariante cliente
    # ==============================================================================================
    $depA  = New-PtuDeploy; $deploys.Add($depA)
    $exeA  = Get-PtuExePath -DeployDir $depA
    $idA   = Get-PtuDeployIdentity -DeployDir $depA
    $pipeA = $idA.Names.PipeName
    $clientLogsToClean.Add($idA.Names.ClientLogPath)

    $procA = Start-PtuTestDaemon -DeployDir $depA
    Register-PtuDaemon -Proc $procA -Pipe $pipeA
    $readyA = Connect-PtuPipe -PipeName $pipeA -TimeoutMs 25000
    Assert-True ($null -ne $readyA) "A: daemon real nao subiu (pipe nao ficou conectavel)"
    if ($null -ne $readyA) { $readyA.Dispose() }

    # Diretorio FORA de escopo (defer por escopo, paridade tambem).
    $outA = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-eself-outA-" + [System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $outA -Force | Out-Null

    # A1) Paridade daemon<->in-process num corpus (mesma decisao final allow/defer).
    $corpus = @(
        @{ Cmd = 'git status';            InScope = $true },
        @{ Cmd = 'git log | head';        InScope = $true },
        @{ Cmd = 'cat foo.txt';           InScope = $true },
        @{ Cmd = 'ls -la';                InScope = $true },
        @{ Cmd = 'wc -l foo';             InScope = $true },
        @{ Cmd = 'git branch -a';         InScope = $true },
        @{ Cmd = 'rg pattern';            InScope = $true },
        @{ Cmd = 'git push origin';       InScope = $true },   # defer: subcomando nao allow
        @{ Cmd = 'rm -rf /';              InScope = $true },   # defer: verbo nao allow
        @{ Cmd = 'git -c core.x=y status';InScope = $true },   # defer: flag perigosa
        @{ Cmd = 'git branch novo';       InScope = $true },   # defer: posicional cria branch
        @{ Cmd = 'echo $FOO';             InScope = $true },   # defer: danger char / verbo nao allow
        @{ Cmd = 'date 010100002020';     InScope = $true },   # defer: set de relogio
        @{ Cmd = 'cat foo; rm bar';       InScope = $true },   # defer: 2o segmento nao allow
        @{ Cmd = 'git status';            InScope = $false },  # defer: fora de escopo
        @{ Cmd = 'cat foo.txt';           InScope = $false }   # defer: fora de escopo
    )
    $ix = 0
    # Aquece o daemon antes do corpus: o round-trip ao python persistente tem custo de cold-start e um
    # timeout interno; sem warmup uma tokenizacao inicial pode estourar esse timeout e deferir por
    # PERFORMANCE (nao por logica), quebrando a paridade de forma flaky.
    for ($w = 0; $w -lt 5; $w++) { [void](Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId "warm-$w") }
    foreach ($case in $corpus) {
        $ix++
        $cwd = if ($case.InScope) { $depA } else { $outA }
        $json = @{ tool_name = 'Bash'; tool_input = @{ command = $case.Cmd }; cwd = $cwd } | ConvertTo-Json -Compress
        $inProcOut = Invoke-PtuDecisorProc -Json $json -Roots $depA
        $inProcDec = Get-PtuDecisionField -Json $inProcOut
        $daemonDec = Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd $case.Cmd -Cwd $cwd -ReqId "a-$ix"
        # Paridade de LOGICA: o in-process (python one-shot, sem o timeout do round-trip) e' a referencia.
        # Se o in-process diz allow mas o daemon deu defer, esse defer e' flaky de PERFORMANCE -> re-tenta
        # o daemon ate concordar; defer esperado (in-process=defer) NAO re-tenta (e' o veredito correto).
        if ($inProcDec -ceq 'allow' -and $daemonDec -cne 'allow') {
            for ($r = 0; $r -lt 6 -and $daemonDec -cne 'allow'; $r++) { Start-Sleep -Milliseconds 120; $daemonDec = Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd $case.Cmd -Cwd $cwd -ReqId "a-$ix-r$r" }
        }
        Assert-True (($daemonDec -ceq 'allow') -or ($daemonDec -ceq 'defer')) "A1[$ix]: daemon devolveu valor inesperado '$daemonDec' p/ '$($case.Cmd)'"
        Assert-True ($daemonDec -ceq $inProcDec) "A1[$ix]: paridade daemon('$daemonDec') != in-process('$inProcDec') p/ '$($case.Cmd)' inScope=$($case.InScope)"
    }

    # A2) Paridade cliente<->daemon do JSON §3.1 (byte-a-byte, normalizando so reason + whitespace final).
    # defer (out-of-scope) — deterministico (nao depende de warmup).
    $jsonDefer = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $outA } | ConvertTo-Json -Compress
    $cliDeferOut = Invoke-PtuClientExe -ExePath $exeA -Stdin $jsonDefer -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depA }
    $decDeferOut = Invoke-PtuDecisorProc -Json $jsonDefer -Roots $depA
    Assert-True ((Get-PtuDecisionField $cliDeferOut) -ceq 'defer') "A2: cliente nao deu defer out-of-scope (out=$cliDeferOut)"
    Assert-True ((Get-PtuDecisionField $decDeferOut) -ceq 'defer') "A2: in-process nao deu defer out-of-scope (out=$decDeferOut)"
    Assert-True ((ConvertTo-Ptu31Normalized $cliDeferOut) -ceq (ConvertTo-Ptu31Normalized $decDeferOut)) "A2: §3.1 normalizado defer cliente != in-process (cli=$cliDeferOut dec=$decDeferOut)"

    # allow (in-scope) — tolera o WARMUP do daemon recem-subido (allow EVENTUAL; design §9-0e).
    $jsonAllow = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depA } | ConvertTo-Json -Compress
    $cliAllowOut = $null
    for ($k = 0; $k -lt 12; $k++) {
        $o = Invoke-PtuClientExe -ExePath $exeA -Stdin $jsonAllow -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depA }
        if ((Get-PtuDecisionField $o) -ceq 'allow') { $cliAllowOut = $o; break }
        Start-Sleep -Milliseconds 150
    }
    $decAllowOut = Invoke-PtuDecisorProc -Json $jsonAllow -Roots $depA
    Assert-True ($null -ne $cliAllowOut) "A2: cliente nunca deu allow in-scope (warmup nao convergiu em 12 tentativas)"
    Assert-True ((Get-PtuDecisionField $decAllowOut) -ceq 'allow') "A2: in-process nao deu allow in-scope (out=$decAllowOut)"
    if ($null -ne $cliAllowOut) {
        $prefix = '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"'
        Assert-True ($cliAllowOut.StartsWith($prefix, [System.StringComparison]::Ordinal)) "A2: prefixo §3.1 do cliente (allow) divergente (out=$cliAllowOut)"
        Assert-True ((ConvertTo-Ptu31Normalized $cliAllowOut) -ceq (ConvertTo-Ptu31Normalized $decAllowOut)) "A2: §3.1 normalizado allow cliente != in-process (cli=$cliAllowOut dec=$decAllowOut)"
    }

    # A3) Invariante: o cliente ISOLADO (deploy SEM daemon) NUNCA emite allow, nem in-scope.
    $depA3 = New-PtuDeploy -NoDaemon; $deploys.Add($depA3)
    $exeA3 = Get-PtuExePath -DeployDir $depA3
    $idA3  = Get-PtuDeployIdentity -DeployDir $depA3
    $clientLogsToClean.Add($idA3.Names.ClientLogPath)
    $jsonA3 = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depA3 } | ConvertTo-Json -Compress
    for ($i = 0; $i -lt 3; $i++) {
        $o = Invoke-PtuClientExe -ExePath $exeA3 -Stdin $jsonA3 -EnvOverride @{ PTU_SAFE_ALLOW_ROOTS = $depA3 }
        Assert-True ((Get-PtuDecisionField $o) -ceq 'defer') "A3: cliente isolado emitiu nao-defer (iter $i, out=$o)"
    }

    Remove-Item -LiteralPath $outA -Recurse -Force -ErrorAction SilentlyContinue

    # ==============================================================================================
    # SECAO B (E-b) — Resposta/protocolo adversarial (daemon falso hostil; framing; handshake; pin)
    # ==============================================================================================

    # B1) DAEMON FALSO HOSTIL: o cliente conecta num servidor de pipe PS falso (deploy SEM daemon) que
    # devolve respostas malformadas; o cliente (parsing ESTRITO) tem de tratar TODAS como defer.
    $depB  = New-PtuDeploy -NoDaemon; $deploys.Add($depB)
    $exeB  = Get-PtuExePath -DeployDir $depB
    $idB   = Get-PtuDeployIdentity -DeployDir $depB
    $pipeB = $idB.Names.PipeName
    $clientLogsToClean.Add($idB.Names.ClientLogPath)
    $jsonB = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depB } | ConvertTo-Json -Compress

    Test-PtuStrictResponse -Name 'B1-nul'        -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 6  -Payload ([byte[]]@(97,108,108,111,119,0)) -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-crlf'       -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 7  -Payload (Bytes "allow`r`n") -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-trailspace' -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 6  -Payload (Bytes 'allow ') -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-leadspace'  -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 6  -Payload (Bytes ' allow') -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-upper'      -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 5  -Payload (Bytes 'ALLOW') -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-json'       -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 20 -Payload (Bytes '{"decision":"allow"}') -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-allowdefer' -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 10 -Payload (Bytes 'allowdefer') -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-truncated'  -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 50 -Payload (Bytes 'al') -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-magicbad'   -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 9 -Proto 1 -DeclaredLen 5  -Payload (Bytes 'allow') -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-protobad'   -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 2 -DeclaredLen 5  -Payload (Bytes 'allow') -Expected 'defer'
    Test-PtuStrictResponse -Name 'B1-lenoverflow'-PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 1 -Proto 1 -DeclaredLen 70000 -Payload (Bytes 'allow') -Expected 'defer'
    # B3) 0x02 (shutdown) em RESPOSTA a 0x01 (dados): resposta nao e' frame de dados valido -> defer.
    Test-PtuStrictResponse -Name 'B3-magic2resp' -PipeName $pipeB -ExePath $exeB -Deploy $depB -Stdin $jsonB -Magic 2 -Proto 1 -DeclaredLen 5  -Payload (Bytes 'allow') -Expected 'defer'

    # B2) ENTRADA/PROTOCOLO ADVERSARIAL contra o DAEMON REAL (depA, ainda vivo): todo lixo -> defer,
    # SEM excecao, e o daemon SEGUE servindo depois da saraivada.
    $okBytes = [System.Text.Encoding]::UTF8.GetBytes((@{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depA; ptuSafeAllowVersion = $ver; buildContractPin = $pin; requestId = 'b2' } | ConvertTo-Json -Compress))
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen 70000 -Payload ([byte[]]@())) -ceq 'defer') "B2: payload>64KB != defer"
    # payloadLen>real (declara 50, envia 1): o daemon consome o 1 byte, espera o resto e estoura o timeout de leitura -> defer.
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen 50 -Payload ([byte[]]@(0x7B))) -ceq 'defer') "B2: payloadLen>real (read-timeout) != defer"
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen 0 -Payload ([byte[]]@())) -ceq 'defer') "B2: payloadLen=0 != defer"
    # boundaries de len: 0x7FFFFFFF (int.MaxValue) e 0xFFFFFFFF (4B 0xFF; o daemon usa [long] -> 4294967295,
    # NAO vira signed -1). Ambos > MAX_FRAME -> o daemon rejeita ANTES de ler payload, por isso so o header
    # e' enviado (payload vazio): testa a barreira de len sem deixar bytes orfaos.
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen 2147483647 -Payload ([byte[]]@())) -ceq 'defer') "B2: payloadLen=0x7FFFFFFF != defer"
    $rawFFFF = Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen ([int]::Parse('-1')) -Payload ([byte[]]@())
    Assert-True ($rawFFFF -ceq 'defer') "B2: payloadLen=0xFFFFFFFF (signed -1) != defer (veio '$rawFFFF')"
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 9 -ProtoVer 1 -DeclaredLen $okBytes.Length -Payload $okBytes) -ceq 'defer') "B2: magic fora de {1,2} != defer"
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 2 -DeclaredLen $okBytes.Length -Payload $okBytes) -ceq 'defer') "B2: protocolVersion errado != defer"
    $emptyJson = [System.Text.Encoding]::UTF8.GetBytes('{}')
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen $emptyJson.Length -Payload $emptyJson) -ceq 'defer') "B2: JSON {} != defer"
    # tool_name AUSENTE (ver/pin corretos, in-scope) -> switch default -> defer.
    $noTool = [System.Text.Encoding]::UTF8.GetBytes((@{ tool_input = @{ command = 'git status' }; cwd = $depA; ptuSafeAllowVersion = $ver; buildContractPin = $pin; requestId = 'b2nt' } | ConvertTo-Json -Compress))
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen $noTool.Length -Payload $noTool) -ceq 'defer') "B2: tool_name ausente != defer"
    # tool_name TIPO ERRADO (numero) -> '123' nao casa Bash/PowerShell -> default -> defer.
    $badTool = [System.Text.Encoding]::UTF8.GetBytes((@{ tool_name = 123; tool_input = @{ command = 'git status' }; cwd = $depA; ptuSafeAllowVersion = $ver; buildContractPin = $pin; requestId = 'b2bt' } | ConvertTo-Json -Compress))
    Assert-True ((Send-PtuRaw -PipeName $pipeA -Magic 1 -ProtoVer 1 -DeclaredLen $badTool.Length -Payload $badTool) -ceq 'defer') "B2: tool_name tipo errado != defer"
    # multiplos frames numa conexao: le SO o 1o; sem 2a resposta.
    $f1 = New-PtuFrameBytes -Magic 1 -ProtoVer 1 -Payload ([System.Text.Encoding]::UTF8.GetBytes((@{ tool_name = 'Bash'; tool_input = @{ command = 'rm -rf /' }; cwd = $depA; ptuSafeAllowVersion = $ver; buildContractPin = $pin; requestId = 'b2m1' } | ConvertTo-Json -Compress)))
    $f2 = New-PtuFrameBytes -Magic 1 -ProtoVer 1 -Payload ([System.Text.Encoding]::UTF8.GetBytes((@{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depA; ptuSafeAllowVersion = $ver; buildContractPin = $pin; requestId = 'b2m2' } | ConvertTo-Json -Compress)))
    $multi = Send-PtuTwoFramesReadOne -PipeName $pipeA -Frame1 $f1 -Frame2 $f2
    Assert-True ($multi.First -ceq 'defer') "B2: multi-frame: 1a resposta != defer (rm -rf) (veio '$($multi.First)')"
    Assert-True ($null -eq $multi.Second) "B2: multi-frame: daemon emitiu 2a resposta na mesma conexao (devia ler 1)"

    # B4) HANDSHAKE divergente -> defer. version errada; pin divergente (DOIS valores: a comparacao
    # reqPin -cne dllPin e' simetrica, entao 'EXE novo+DLL velha' e 'velha+nova' reduzem ao MESMO
    # caminho; a assimetria fisica EXE/DLL nao e' reproduzivel sem rebuild — mesma barreira de pin).
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId 'b4v' -Ver '9.9.9') -ceq 'defer') "B4: version divergente != defer"
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId 'b4p1' -Pin ('0' * 64)) -ceq 'defer') "B4: pin divergente (zeros) != defer"
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId 'b4p2' -Pin ('f' * 64)) -ceq 'defer') "B4: pin divergente (efes) != defer"
    Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId 'b4p3' -Pin 'PIN-ERRADO') -ceq 'defer') "B4: pin malformado != defer"
    # daemon SEGUE servindo apos toda a saraivada adversarial (warmup ja passou na Secao A).
    $served = 'defer'
    for ($k = 0; $k -lt 8 -and $served -cne 'allow'; $k++) { $served = Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId "b4ok-$k"; if ($served -cne 'allow') { Start-Sleep -Milliseconds 120 } }
    Assert-True ($served -ceq 'allow') "B2/B4: daemon nao volta a servir (allow) apos a saraivada adversarial"

    # B5) StrictMode da FONTE UNICA (Get-PtuSegmentsVerdict / Get-PtuBashDecision): tokenizador que
    # devolve {status:defer}, {} (sem status) ou $null -> defer, sem excecao (contrato §4.1/StrictMode).
    Assert-True ((Get-PtuSegmentsVerdict $null) -ceq 'defer') "B5: SegmentsVerdict(null) != defer"
    Assert-True ((Get-PtuSegmentsVerdict ([pscustomobject]@{ status = 'defer'; reason = 'loop-error' })) -ceq 'defer') "B5: SegmentsVerdict(status=defer) != defer"
    Assert-True ((Get-PtuSegmentsVerdict ('{}' | ConvertFrom-Json)) -ceq 'defer') "B5: SegmentsVerdict({}) != defer"
    $tokDefer = { param([string] $c) [pscustomobject]@{ status = 'defer'; reason = 'loop-error' } }
    $tokEmpty = { param([string] $c) ('{}' | ConvertFrom-Json) }
    $tokNull  = { param([string] $c) $null }
    Assert-True ((Get-PtuBashDecision -Command 'git status' -Tokenizer $tokDefer) -ceq 'defer') "B5: BashDecision(tok=defer) != defer"
    Assert-True ((Get-PtuBashDecision -Command 'git status' -Tokenizer $tokEmpty) -ceq 'defer') "B5: BashDecision(tok={}) != defer"
    Assert-True ((Get-PtuBashDecision -Command 'git status' -Tokenizer $tokNull) -ceq 'defer') "B5: BashDecision(tok=null) != defer"

    # ==============================================================================================
    # SECAO C (E-c) — Segments (contrato de formato) + Unicode (Cc/Cf; NFC vs NFD)
    # ==============================================================================================
    # C1) Get-PtuSegmentsVerdict: contrato ESTRITO de formato de segments, construido por ConvertFrom-Json
    # (exatamente como o daemon recebe do python). Array-NAO-vazio de arrays-NAO-vazios de strings; resto
    # -> defer (fail-closed).
    Assert-True ((Get-PtuSegmentsVerdict ('{"status":"ok","segments":[]}' | ConvertFrom-Json)) -ceq 'defer') "C1: segments [] != defer"
    Assert-True ((Get-PtuSegmentsVerdict ('{"status":"ok","segments":[[]]}' | ConvertFrom-Json)) -ceq 'defer') "C1: segments [[]] (segmento vazio) != defer"
    Assert-True ((Get-PtuSegmentsVerdict ('{"status":"ok","segments":["git"]}' | ConvertFrom-Json)) -ceq 'defer') "C1: segmento string escalar (['git']) != defer"
    Assert-True ((Get-PtuSegmentsVerdict ('{"status":"ok","segments":[["git","log"],["head"]]}' | ConvertFrom-Json)) -ceq 'allow') "C1: [[git,log],[head]] != allow"
    Assert-True ((Get-PtuSegmentsVerdict ('{"status":"ok","segments":[["git",null]]}' | ConvertFrom-Json)) -ceq 'defer') "C1: token null != defer"
    Assert-True ((Get-PtuSegmentsVerdict ('{"status":"ok","segments":[["git",{}]]}' | ConvertFrom-Json)) -ceq 'defer') "C1: token objeto != defer"
    Assert-True ((Get-PtuSegmentsVerdict ('{"status":"ok","segments":[[""]]}' | ConvertFrom-Json)) -ceq 'defer') "C1: token string vazia != defer"

    # C2) Unicode de CONTROLE/FORMATO (Cc/Cf) em QUALQUER token -> defer, via DAEMON REAL (depA, quente):
    # no verbo cai no fast-path; na flag/arg cai na rejeicao da classify (unicodedata Cc/Cf). U+200B
    # (zero-width space), U+FEFF (BOM/zwnbsp), U+202E (RLO bidi).
    $uniChars = @(
        @{ N = 'U+200B'; C = ([string][char]0x200B) },
        @{ N = 'U+FEFF'; C = ([string][char]0xFEFF) },
        @{ N = 'U+202E'; C = ([string][char]0x202E) }
    )
    foreach ($u in $uniChars) {
        $ch = $u.C
        Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd ("git{0} status" -f $ch) -Cwd $depA -ReqId "c2v") -ceq 'defer') "C2: unicode $($u.N) no VERBO != defer"
        Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd ("git log --onel{0}ine" -f $ch) -Cwd $depA -ReqId "c2f") -ceq 'defer') "C2: unicode $($u.N) na FLAG != defer"
        Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd ("git log {0}arg" -f $ch) -Cwd $depA -ReqId "c2a") -ceq 'defer') "C2: unicode $($u.N) no ARG != defer"
    }

    # C3) NFC vs NFD: a mesma string acentuada nas duas formas deve dar o MESMO veredito. 'cat' e' allow
    # incondicional e o combining U+0301 (NFD) e' categoria Mn (NAO Cc/Cf) -> nao rejeitado -> allow nas
    # duas formas. Tolera warmup (allow eventual).
    $cmdNfc = "cat caf$([char]0x00E9) arquivo"          # café (NFC, U+00E9)
    $cmdNfd = "cat cafe$([char]0x0301) arquivo"         # café (NFD, e + combining acute)
    $rNfc = 'defer'; for ($k = 0; $k -lt 10 -and $rNfc -cne 'allow'; $k++) { $rNfc = Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd $cmdNfc -Cwd $depA -ReqId "c3nfc-$k"; if ($rNfc -cne 'allow') { Start-Sleep -Milliseconds 120 } }
    $rNfd = 'defer'; for ($k = 0; $k -lt 10 -and $rNfd -cne 'allow'; $k++) { $rNfd = Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd $cmdNfd -Cwd $depA -ReqId "c3nfd-$k"; if ($rNfd -cne 'allow') { Start-Sleep -Milliseconds 120 } }
    Assert-True ($rNfc -ceq $rNfd) "C3: NFC ('$rNfc') e NFD ('$rNfd') deram veredito DIFERENTE"
    Assert-True ($rNfc -ceq 'allow') "C3: 'cat cafe arquivo' (NFC) nao deu allow (veio '$rNfc')"

    # ==============================================================================================
    # SECAO D (E-d) — ACL (DACL efetiva so-usuario) + Identidade (paridade EXE<->PS; fail-closed)
    # ==============================================================================================

    # D-ACL-1) DACL efetiva so-usuario dos artefatos VIVOS do daemon depA: pipe + singleton mutex + log.
    Test-PtuDaclUserOnly -Acl (Get-PtuPipeDacl -PipeName $pipeA) -Label 'D-ACL pipe'
    Test-PtuDaclUserOnly -Acl (Get-PtuMutexDacl -MutexName $idA.Names.SingletonMutexName) -Label 'D-ACL singleton-mutex'
    Assert-True (Test-Path -LiteralPath $idA.Names.DaemonLogPath) "D-ACL: daemon log ausente"
    if (Test-Path -LiteralPath $idA.Names.DaemonLogPath) {
        $dlAcl = Get-Acl -LiteralPath $idA.Names.DaemonLogPath
        Assert-True ($dlAcl.AreAccessRulesProtected) "D-ACL daemon-log: heranca nao removida"
        Test-PtuDaclUserOnly -Acl $dlAcl -Label 'D-ACL daemon-log'
    }
    # cliente log: gerado no A3 (cold-path -> daemonScript ausente -> ClientLog 'spawn-failed').
    Assert-True (Test-Path -LiteralPath $idA3.Names.ClientLogPath) "D-ACL: cliente log ausente (deveria vir do A3)"
    if (Test-Path -LiteralPath $idA3.Names.ClientLogPath) {
        $clAcl = Get-Acl -LiteralPath $idA3.Names.ClientLogPath
        Assert-True ($clAcl.AreAccessRulesProtected) "D-ACL client-log: heranca nao removida"
        Test-PtuDaclUserOnly -Acl $clAcl -Label 'D-ACL client-log'
        Assert-True (-not ((Get-Content -Raw -LiteralPath $idA3.Names.ClientLogPath) -match 'git status')) "D-ACL client-log: VAZOU o command"
    }

    # D-ACL-2) guard mutex (cliente, TRANSITORIO): capturado best-effort durante um cold-path real. Se nao
    # entrar na janela, AVISA (a postura so-usuario do mutex ja vem do singleton; a do cliente, do client-log).
    $depG = New-PtuDeploy; $deploys.Add($depG)
    $idG  = Get-PtuDeployIdentity -DeployDir $depG
    $exeG = Get-PtuExePath -DeployDir $depG
    $clientLogsToClean.Add($idG.Names.ClientLogPath)
    Register-PtuDaemon -Proc $null -Pipe $idG.Names.PipeName   # o cold-path sobe um daemon -> shutdown no finally
    $jsonG = @{ tool_name = 'Bash'; tool_input = @{ command = 'git status' }; cwd = $depG } | ConvertTo-Json -Compress
    $cliSb = {
        param($ExePath, $Stdin, $Roots)
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $ExePath; $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true
        $psi.Environment['PTU_SAFE_ALLOW_ROOTS'] = $Roots
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.StandardInput.Write($Stdin); $p.StandardInput.Close()
        [void]$p.StandardOutput.ReadToEnd(); [void]$p.WaitForExit(15000)
    }
    $cliJob = Start-ThreadJob -ScriptBlock $cliSb -ArgumentList $exeG, $jsonG, $depG
    $guardCaptured = $false
    $swG = [System.Diagnostics.Stopwatch]::StartNew()
    while ($swG.ElapsedMilliseconds -lt 4000 -and -not $guardCaptured) {
        $gd = Get-PtuMutexDacl -MutexName $idG.Names.GuardMutexName
        if ($null -ne $gd) { Test-PtuDaclUserOnly -Acl $gd -Label 'D-ACL guard-mutex'; $guardCaptured = $true }
        else { Start-Sleep -Milliseconds 4 }
    }
    [void](Wait-Job -Job $cliJob -Timeout 20000); Remove-Job -Job $cliJob -Force -ErrorAction SilentlyContinue
    if (-not $guardCaptured) { Write-Warning 'E-d: guard mutex (cliente) nao capturado na janela transitoria; postura so-usuario coberta por singleton-mutex + client-log (CreateUserOnly)' }

    # D-ACL-3) shutdown 0x02 ENCERRA o daemon (plano de controle autorizado pela ACL do pipe). Deploy
    # proprio p/ nao derrubar depA (ainda usado abaixo nao — mas mantem isolado).
    $depS = New-PtuDeploy; $deploys.Add($depS)
    $idS  = Get-PtuDeployIdentity -DeployDir $depS
    $clientLogsToClean.Add($idS.Names.ClientLogPath)
    $procS = Start-PtuTestDaemon -DeployDir $depS
    $rdS = Connect-PtuPipe -PipeName $idS.Names.PipeName -TimeoutMs 20000; if ($rdS) { $rdS.Dispose() }
    Send-PtuShutdown -PipeName $idS.Names.PipeName
    Assert-True ($procS.WaitForExit(8000)) "D-ACL: shutdown 0x02 nao encerrou o daemon"

    # D-ID) Identidade: paridade hash cliente[EXE/AOT] <-> daemon[PS/DLL] (mesmo canonicalizePath) + marcador
    # fail-closed. --emit-identity (EXE) vs Get-PtuIdentity (DLL via Add-Type).
    function Get-PtuExeIdentityHash {
        param([string] $ExePath, [string] $StartDir, [string] $Roots)
        $envOverride = if ($Roots) { @{ PTU_SAFE_ALLOW_ROOTS = $Roots } } else { $null }
        return (Invoke-PtuClientExe -ExePath $ExePath -Stdin $null -EnvOverride $envOverride -ExeArgs @('--emit-identity', $StartDir)).Trim()
    }
    # D-ID-1) paridade em path ASCII e NAO-ASCII (İ turco U+0130 + ß U+00DF no caminho) -> canonicalizePath
    # byte-identico EXE<->DLL (se divergisse, o hash divergiria).
    foreach ($variant in @('ascii', 'nonascii')) {
        $sub = if ($variant -eq 'ascii') { 'ptu-id-ascii' } else { "ptu-id-$([char]0x0130)$([char]0x00DF)" }
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ("$sub-" + [System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Copy-Item -LiteralPath $exeSrc -Destination (Join-Path $root 'ptu-client.exe') -Force
        Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $root 'PtuCanon.dll') -Force
        [System.IO.File]::WriteAllText((Join-Path $root '.ptu-safe-allow-root'), '')
        $deploys.Add($root)
        $psId = Get-PtuIdentity -StartDirectory $root -DllPath (Join-Path $root 'PtuCanon.dll') -Roots @($root)
        Assert-True ($null -ne $psId) "D-ID[$variant]: identidade PS nula"
        if ($null -ne $psId) {
            $exeHash = Get-PtuExeIdentityHash -ExePath (Join-Path $root 'ptu-client.exe') -StartDir $root -Roots $root
            Assert-True ($exeHash -ceq $psId.IdentityHash) "D-ID[$variant]: hash EXE($exeHash) != PS($($psId.IdentityHash)) (canonicalizePath divergente)"
        }
    }
    # D-ID-2) fail-closed: ZERO marcador -> invalido nos dois lados.
    $depZero = New-PtuDeploy -NoMarker; $deploys.Add($depZero)
    $exeZeroHash = Get-PtuExeIdentityHash -ExePath (Get-PtuExePath -DeployDir $depZero) -StartDir $depZero -Roots $depZero
    Assert-True ($exeZeroHash -ceq 'IDENTITY-INVALID') "D-ID zero: EXE nao deu IDENTITY-INVALID (veio $exeZeroHash)"
    Assert-True ($null -eq (Get-PtuIdentity -StartDirectory $depZero -DllPath (Join-Path $depZero 'PtuCanon.dll') -Roots @($depZero))) "D-ID zero: PS nao deu identidade nula"
    # D-ID-3) fail-closed: MULTIPLOS marcadores (orfao em ancestral) -> invalido. Fixture outer/marcador +
    # outer/inner/marcador + EXE em outer/inner/deep -> a ascensao acha 2 -> invalido (regra: exatamente 1).
    $outer = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-id-multi-" + [System.Guid]::NewGuid().ToString('N'))
    $inner = Join-Path $outer 'inner'
    $deep  = Join-Path $inner 'deep'
    New-Item -ItemType Directory -Path $deep -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $outer '.ptu-safe-allow-root'), '')
    [System.IO.File]::WriteAllText((Join-Path $inner '.ptu-safe-allow-root'), '')
    Copy-Item -LiteralPath $exeSrc -Destination (Join-Path $deep 'ptu-client.exe') -Force
    Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $deep 'PtuCanon.dll') -Force
    $deploys.Add($outer)
    $exeMultiHash = Get-PtuExeIdentityHash -ExePath (Join-Path $deep 'ptu-client.exe') -StartDir $deep -Roots $deep
    Assert-True ($exeMultiHash -ceq 'IDENTITY-INVALID') "D-ID multi: EXE nao deu IDENTITY-INVALID (orfao em ancestral) (veio $exeMultiHash)"
    Assert-True ($null -eq (Get-PtuIdentity -StartDirectory $deep -DllPath (Join-Path $deep 'PtuCanon.dll') -Roots @($deep))) "D-ID multi: PS nao deu identidade nula (orfao em ancestral)"
    # D-ID-4) checkouts distintos sob o MESMO root largo -> repoCanonical distinto -> pipes distintos.
    $wide = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-id-wide-" + [System.Guid]::NewGuid().ToString('N'))
    $coA = Join-Path $wide 'checkoutA'; $coB = Join-Path $wide 'checkoutB'
    foreach ($co in @($coA, $coB)) {
        New-Item -ItemType Directory -Path $co -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $co '.ptu-safe-allow-root'), '')
        Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $co 'PtuCanon.dll') -Force
    }
    $deploys.Add($wide)
    $idCoA = Get-PtuIdentity -StartDirectory $coA -DllPath (Join-Path $coA 'PtuCanon.dll') -Roots @($wide)
    $idCoB = Get-PtuIdentity -StartDirectory $coB -DllPath (Join-Path $coB 'PtuCanon.dll') -Roots @($wide)
    Assert-True (($null -ne $idCoA) -and ($null -ne $idCoB)) "D-ID wide: identidade nula em checkout sob root largo"
    if (($null -ne $idCoA) -and ($null -ne $idCoB)) {
        Assert-True ($idCoA.Names.PipeName -cne $idCoB.Names.PipeName) "D-ID wide: checkouts distintos sob root largo deram o MESMO pipe"
    }

    # ==============================================================================================
    # SECAO E (E-e) — Escopo (junction dentro/escapa; cwd indisponivel; fora; roots vazio; canon por-req)
    # ==============================================================================================
    # depA tem roots = @($depA). A canonicalizacao do cwd e' POR-REQUISICAO (G2(a)): junction DENTRO de
    # depA apontando p/ dentro -> in-scope; junction que ESCAPA -> defer (sem canon, o StartsWith do path
    # CRU daria falso-allow). Limpeza das junctions com Directory.Delete (remove o link, NAO o target).
    $realSub = Join-Path $depA 'realsub'; New-Item -ItemType Directory -Path $realSub -Force | Out-Null
    $outE = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-eself-outE-" + [System.Guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $outE -Force | Out-Null
    $jin = Join-Path $depA 'jin'; $jout = Join-Path $depA 'jout'
    $junctions = [System.Collections.Generic.List[string]]::new()
    try {
        New-Item -ItemType Junction -Path $jin -Target $realSub | Out-Null; $junctions.Add($jin)
        New-Item -ItemType Junction -Path $jout -Target $outE | Out-Null; $junctions.Add($jout)
        # E1) junction DENTRO -> allow (tolera warmup); junction que ESCAPA -> defer.
        $rIn = 'defer'; for ($k = 0; $k -lt 10 -and $rIn -cne 'allow'; $k++) { $rIn = Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $jin -ReqId "e1in-$k"; if ($rIn -cne 'allow') { Start-Sleep -Milliseconds 120 } }
        Assert-True ($rIn -ceq 'allow') "E1: junction DENTRO do escopo nao deu allow (veio '$rIn')"
        Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $jout -ReqId 'e1out') -ceq 'defer') "E1: junction que ESCAPA do escopo nao deu defer"
        # E2) cwd INDISPONIVEL (path inexistente DENTRO de depA) -> Failed na canon -> defer, SEM travar o loop.
        $missing = Join-Path $depA ('naoexiste-' + [System.Guid]::NewGuid().ToString('N') + '\sub')
        Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $missing -ReqId 'e2') -ceq 'defer') "E2: cwd inexistente nao deu defer"
        $rAfter = 'defer'; for ($k = 0; $k -lt 8 -and $rAfter -cne 'allow'; $k++) { $rAfter = Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $depA -ReqId "e2after-$k"; if ($rAfter -cne 'allow') { Start-Sleep -Milliseconds 120 } }
        Assert-True ($rAfter -ceq 'allow') "E2: daemon nao voltou a servir apos cwd indisponivel (loop travou?)"
        # E3) cwd FORA do escopo + comando allow-candidato -> defer (a 1a barreira de escopo nao afrouxa).
        Assert-True ((Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd 'git status' -Cwd $outE -ReqId 'e3') -ceq 'defer') "E3: cwd fora do escopo + allow-candidato nao deu defer"
    }
    finally {
        foreach ($j in $junctions) { try { [System.IO.Directory]::Delete($j, $false) } catch {} }
        Remove-Item -LiteralPath $outE -Recurse -Force -ErrorAction SilentlyContinue
    }
    # E4) ROOTS vazio / so-whitespace -> defer (fonte unica, in-process). No daemon, roots invalidos ->
    # identidade nula -> o daemon nem sobe (fail-closed na subida); aqui prova-se a 1a barreira de escopo.
    Assert-True (-not (Test-PtuCwdInScope -Cwd $depA -Roots @())) "E4: roots vazio -> CwdInScope deveria ser false"
    Assert-True (-not (Test-PtuCwdInScope -Cwd $depA -Roots @('', '   '))) "E4: roots so-whitespace -> CwdInScope deveria ser false"
    Assert-True ((Get-PtuDecision -ToolName 'Bash' -Command 'git status' -Cwd $depA -Roots @()) -ceq 'defer') "E4: Get-PtuDecision com roots vazio nao deu defer"
}
finally {
    foreach ($d in $daemons) { Stop-PtuTestDaemon -Proc $d.Proc -PipeName $d.Pipe }
    Start-Sleep -Milliseconds 300
    foreach ($dir in $deploys) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    foreach ($lg in $clientLogsToClean) { if ($lg) { Remove-Item -LiteralPath $lg -Force -ErrorAction SilentlyContinue } }
    Remove-Item -LiteralPath $identityInvalidLog -Force -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Error $f -ErrorAction Continue }
    throw "FALHA: Test-ClaudeCodePreToolUseSafeAllowDaemonSelfTest ($($failures.Count) assercao(es))"
}
Write-Output "OK: Test-ClaudeCodePreToolUseSafeAllowDaemonSelfTest.ps1"
