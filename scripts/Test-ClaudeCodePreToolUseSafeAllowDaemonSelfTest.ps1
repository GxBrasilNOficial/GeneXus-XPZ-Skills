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
        $c.Write($hdr, 0, 7)
        if ($null -ne $Payload -and $Payload.Length -gt 0) { $c.Write($Payload, 0, $Payload.Length) }
        $c.Flush()
        if ($Magic -eq 2) { return '<shutdown>' }
        $r = Read-PtuResp -Stream $c -TimeoutMs $RespTimeoutMs
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
    foreach ($case in $corpus) {
        $ix++
        $cwd = if ($case.InScope) { $depA } else { $outA }
        $json = @{ tool_name = 'Bash'; tool_input = @{ command = $case.Cmd }; cwd = $cwd } | ConvertTo-Json -Compress
        $daemonDec = Send-PtuReq -PipeName $pipeA -Tool 'Bash' -Cmd $case.Cmd -Cwd $cwd -ReqId "a-$ix"
        $inProcOut = Invoke-PtuDecisorProc -Json $json -Roots $depA
        $inProcDec = Get-PtuDecisionField -Json $inProcOut
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
