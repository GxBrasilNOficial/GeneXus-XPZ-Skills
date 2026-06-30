#requires -Version 7.4
<#
.SYNOPSIS
Daemon persistente do hook PreToolUse (auto-allow) do Claude Code. PASSO C
(claude-code-pretooluse-implementacao-v1-plan.md, linhas 125-157 + Passo A-escopo 103-123).
Solucao especifica do Claude Code; nao se aplica a Codex/Cursor/OpenCode.

Singleton GARANTIDO PELO DAEMON (refinacao §5(b)): named mutex de vida propria, ACL so-usuario;
quem nao adquire sai cedo. Vencedor: dot-source Support 1x; sobe o python persistente (ShlexLoop) 1x
e valida o handshake; carrega a DLL 1x (Add-Type -Path, co-localizada); self-check; SO ENTAO cria o
named pipe (ready = pipe conectavel; SEM ready file). Loop SINGLE-THREADED: uma conexao por vez.
Decisao por requisicao via a fonte unica (Get-PtuDecision -Tokenizer = round-trip ao python). NUNCA
emite 'deny': so 'allow'/'defer'; qualquer erro/timeout/staleness/versao/pin divergente -> 'defer'.

O cliente NativeAOT real e' o Passo D; aqui um cliente de smoke/self-test (named pipe PS) basta.
NAO liga enforce nem o fio (settings.json). O GATE adversarial completo (§8) e' o Passo E.
#>
[CmdletBinding()]
param(
    [string]   $StartDirectory,                 # default $PSScriptRoot (override de teste)
    [string]   $DllPath,                         # default PtuCanon.dll co-localizada (override de teste/dev)
    [string[]] $Roots,                           # default $null -> Get-PtuRoots (env PTU_SAFE_ALLOW_ROOTS)
    [string]   $PythonExe,                       # default = python do PATH
    [int]      $CwdCanonTimeoutMs = 200,         # timeout duro da canonicalizacao do cwd (G2(a))
    [int]      $CwdCanonCap       = 8,           # cap de threads de canonicalizacao em voo (G2(a))
    [int]      $RequestTimeoutMs  = 1000         # timeout do servidor por leitura de frame
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Protocolo do wire (§7): [magic 1B][protocolVersion 2B BE][payloadLen 4B BE][payload UTF-8].
$script:PtuProtocolVersion = 1
$script:MAGIC_DATA     = [byte]0x01
$script:MAGIC_SHUTDOWN = [byte]0x02
$script:MAX_FRAME      = 65536

# Estado de execucao.
$script:Shutdown            = $false
$script:State               = 'ready'   # 'ready' | 'defer-only'
$script:DeferReason         = ''
$script:DeferOnlyPermanent  = $false
$script:ReloadFailCount     = 0
$script:PendingSupportReload = $false   # sinalizado pela staleness; re-dot-source roda no ESCOPO DE SCRIPT (loop)
$script:PyProc              = $null
$script:PyTokenizer         = $null
$script:CanonRoots          = @()
$script:Artifacts           = $null

# ---------------------------------------------------------------------------------------------------
# Helpers puros / IO
# ---------------------------------------------------------------------------------------------------
function Get-PtuProp {
    param($Obj, [string] $Name)
    if ($null -ne $Obj -and ($null -ne $Obj.PSObject.Properties[$Name])) { return $Obj.$Name }  # indexer: StrictMode-safe p/ objeto vazio (vs .Properties.Name -contains, que lanca)
    return $null
}

function Get-PtuFileSha256 {
    # try/catch: arquivo travado (sharing violation) lanca -> $null (chamador trata stale-uncertain -> defer).
    # (Timeout DURO de hash p/ arquivo que PENDURA, nao so lanca, e' refino do Passo E; aqui best-effort.)
    param([string] $Path)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        return [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    } catch { return $null }
}

function Read-PtuStreamExact {
    # Le EXATAMENTE $Count bytes com timeout (ReadAsync + Wait). $null em timeout/EOF.
    param($Stream, [int] $Count, [int] $TimeoutMs)
    if ($Count -eq 0) { return [byte[]]::new(0) }
    $buf = [byte[]]::new($Count)
    $off = 0
    while ($off -lt $Count) {
        $t = $Stream.ReadAsync($buf, $off, $Count - $off)
        if (-not $t.Wait($TimeoutMs)) { return $null }
        $k = $t.Result
        if ($k -le 0) { return $null }
        $off += $k
    }
    return $buf
}

function Read-PtuFrame {
    # Le um frame do wire. Retorna { Magic; ProtoVer; Payload(byte[]) } ou $null (timeout/EOF/len invalido).
    param($Stream, [int] $TimeoutMs)
    $m = Read-PtuStreamExact $Stream 1 $TimeoutMs
    if ($null -eq $m) { return $null }
    $pv = Read-PtuStreamExact $Stream 2 $TimeoutMs
    if ($null -eq $pv) { return $null }
    $ln = Read-PtuStreamExact $Stream 4 $TimeoutMs
    if ($null -eq $ln) { return $null }
    $proto = ([int]$pv[0] -shl 8) -bor [int]$pv[1]
    $len = ([long]$ln[0] -shl 24) -bor ([long]$ln[1] -shl 16) -bor ([long]$ln[2] -shl 8) -bor [long]$ln[3]
    if ($len -lt 0 -or $len -gt $script:MAX_FRAME) { return $null }
    $payload = Read-PtuStreamExact $Stream ([int]$len) $TimeoutMs
    if ($null -eq $payload) { return $null }
    return [pscustomobject]@{ Magic = $m[0]; ProtoVer = $proto; Payload = $payload }
}

function Write-PtuFrame {
    # A (§7 "timeout no servidor -> fecha+defer"): escrita da resposta com DEADLINE, nao Write sincrono
    # sem timeout. Motivacao (provada empiricamente + revisao por pares 5 familias): com buffer de saida
    # ZERO, o Write sincrono BLOQUEIA ate o cliente DRENAR; um cliente que conecta, manda um frame e nao
    # le a resposta (ex.: payloadLen<real e segura a conexao) PENDURAVA o daemon para sempre (singleton
    # preso, demais conexoes recusadas) -- fail-closed, mas DoS de disponibilidade trivial. Combinada com
    # outBuffer>0 (C, em New-PtuPipeServer): a resposta pequena vai pro buffer do SO e o WriteAsync
    # completa na hora (deadline nunca dispara no caminho real); se a resposta exceder o buffer E o
    # cliente nao drenar, o deadline impede o hang -> 'throw', o loop captura e o finally descarta a
    # conexao, e o daemon SEGUE servindo. Frame unico (header+payload) num WriteAsync so.
    param($Stream, [byte] $Magic, [byte[]] $Bytes, [int] $TimeoutMs = 1000)
    $len = $Bytes.Length
    $hdr = [byte[]]::new(7)
    $hdr[0] = $Magic
    $hdr[1] = [byte](($script:PtuProtocolVersion -shr 8) -band 0xFF)
    $hdr[2] = [byte]($script:PtuProtocolVersion -band 0xFF)
    $hdr[3] = [byte](($len -shr 24) -band 0xFF)
    $hdr[4] = [byte](($len -shr 16) -band 0xFF)
    $hdr[5] = [byte](($len -shr 8)  -band 0xFF)
    $hdr[6] = [byte]($len -band 0xFF)
    $frame = [byte[]]::new(7 + $len)
    [System.Array]::Copy($hdr, 0, $frame, 0, 7)
    if ($len -gt 0) { [System.Array]::Copy($Bytes, 0, $frame, 7, $len) }
    $wt = $Stream.WriteAsync($frame, 0, $frame.Length)
    if (-not $wt.Wait($TimeoutMs)) { throw 'write-timeout' }   # cliente nao drenou + buffer cheio -> nao pendura
    $Stream.Flush()
}

# ---------------------------------------------------------------------------------------------------
# Python persistente (round-trip; framing length-prefixed 4B BE, SEM magic -- contrato do ShlexLoop.py)
# ---------------------------------------------------------------------------------------------------
function Invoke-PtuPythonTokenize {
    param($Proc, [string] $Command)
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Command)
        if ($bytes.Length -gt $script:MAX_FRAME) { return $null }
        $stdin = $Proc.StandardInput.BaseStream
        $hdr = [byte[]]::new(4)
        $hdr[0] = [byte](($bytes.Length -shr 24) -band 0xFF)
        $hdr[1] = [byte](($bytes.Length -shr 16) -band 0xFF)
        $hdr[2] = [byte](($bytes.Length -shr 8)  -band 0xFF)
        $hdr[3] = [byte]($bytes.Length -band 0xFF)
        $stdin.Write($hdr, 0, 4); $stdin.Write($bytes, 0, $bytes.Length); $stdin.Flush()
        $stdout = $Proc.StandardOutput.BaseStream
        $lenBuf = Read-PtuStreamExact $stdout 4 2000
        if ($null -eq $lenBuf) { return $null }
        $n = ([long]$lenBuf[0] -shl 24) -bor ([long]$lenBuf[1] -shl 16) -bor ([long]$lenBuf[2] -shl 8) -bor [long]$lenBuf[3]
        if ($n -lt 0 -or $n -gt $script:MAX_FRAME) { return $null }
        $payload = Read-PtuStreamExact $stdout ([int]$n) 2000
        if ($null -eq $payload) { return $null }
        return ([System.Text.Encoding]::UTF8.GetString($payload) | ConvertFrom-Json)
    } catch { return $null }
}

function Clear-PtuPycache {
    $pc = Join-Path $PSScriptRoot '__pycache__'
    if (Test-Path -LiteralPath $pc) { try { Remove-Item -LiteralPath $pc -Recurse -Force -ErrorAction Stop } catch {} }
}

function Start-PtuPythonProcess {
    # Sobe NOVO python; valida handshake {status:ready, sourceSha256 == hash on-disk do classify}.
    # Anti-.pyc: limpa __pycache__ + PYTHONDONTWRITEBYTECODE=1. Retorna o Process ou $null.
    Clear-PtuPycache
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $script:PythonExe
    [void]$psi.ArgumentList.Add('-u')
    [void]$psi.ArgumentList.Add($script:LoopPath)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $proc = [System.Diagnostics.Process]::Start($psi)
    try {
        $out = $proc.StandardOutput.BaseStream
        $lenBuf = Read-PtuStreamExact $out 4 3000
        if ($null -eq $lenBuf) { throw 'handshake len' }
        $n = ([long]$lenBuf[0] -shl 24) -bor ([long]$lenBuf[1] -shl 16) -bor ([long]$lenBuf[2] -shl 8) -bor [long]$lenBuf[3]
        if ($n -lt 0 -or $n -gt $script:MAX_FRAME) { throw 'handshake size' }
        $payload = Read-PtuStreamExact $out ([int]$n) 3000
        if ($null -eq $payload) { throw 'handshake payload' }
        $ready = [System.Text.Encoding]::UTF8.GetString($payload) | ConvertFrom-Json
        $onDisk = Get-PtuFileSha256 -Path $script:ClassifyPath
        if ((Get-PtuProp $ready 'status') -cne 'ready') { throw 'not ready' }
        if ([string]::IsNullOrEmpty($onDisk) -or ((Get-PtuProp $ready 'sourceSha256') -cne $onDisk)) { throw 'hash mismatch' }
        return $proc
    } catch {
        try { $proc.Kill() } catch {}
        try { $proc.Dispose() } catch {}
        return $null
    }
}

function Invoke-PtuRespawnPython {
    # Transicao SEGURA: sobe e valida o NOVO antes de matar o velho; durante -> chamador deferira.
    $new = Start-PtuPythonProcess
    if ($null -eq $new) { return $false }
    $old = $script:PyProc
    $script:PyProc = $new
    if ($null -ne $old) { try { $old.Kill() } catch {}; try { $old.Dispose() } catch {} }
    Update-PtuArtifactBaseline 'classify'
    Update-PtuArtifactBaseline 'shlexloop'
    return $true
}

# ---------------------------------------------------------------------------------------------------
# Staleness (§6, matriz): support=re-dot-source; classify/shlexloop=respawn; daemon/dll=defer-only.
# ---------------------------------------------------------------------------------------------------
function Update-PtuArtifactBaseline {
    param([string] $Key)
    $a = $script:Artifacts[$Key]
    $fi = [System.IO.FileInfo]::new($a.Path); $fi.Refresh()
    if (-not $fi.Exists) { throw "artefato ausente no baseline: $($a.Path)" }
    $h = Get-PtuFileSha256 -Path $a.Path
    if ([string]::IsNullOrEmpty($h)) { throw "hash nulo no baseline: $($a.Path)" }
    $a.Hash = $h; $a.Size = $fi.Length; $a.Mtime = $fi.LastWriteTimeUtc.Ticks
}

function Set-PtuDeferOnly {
    param([string] $Reason, [bool] $Permanent = $false)
    $script:State = 'defer-only'; $script:DeferReason = $Reason
    if ($Permanent) { $script:DeferOnlyPermanent = $true }
    Write-PtuDaemonLog -RequestId '-' -Decision 'defer-only' -Extra $Reason
}

function Invoke-PtuStalenessCheck {
    # $true = ok-para-servir; $false = deferir ESTA requisicao. Cache (size,mtime) evita re-hash.
    if ($script:State -eq 'defer-only') { return $false }
    foreach ($key in @($script:Artifacts.Keys)) {
        $a = $script:Artifacts[$key]
        try { $fi = [System.IO.FileInfo]::new($a.Path); $fi.Refresh() } catch { Set-PtuDeferOnly -Reason "stat-failed:$key" -Permanent $false; return $false }
        if (-not $fi.Exists) { Set-PtuDeferOnly -Reason "missing:$key" -Permanent ($a.Policy -eq 'deferonly'); return $false }
        if ($fi.Length -eq $a.Size -and $fi.LastWriteTimeUtc.Ticks -eq $a.Mtime) { continue }   # cache hit
        $h = Get-PtuFileSha256 -Path $a.Path
        if ([string]::IsNullOrEmpty($h)) { return $false }                                      # stale-uncertain -> defer
        if ($h -ceq $a.Hash) { $a.Size = $fi.Length; $a.Mtime = $fi.LastWriteTimeUtc.Ticks; continue }  # so mtime mudou
        switch ($a.Policy) {
            'deferonly'   { Set-PtuDeferOnly -Reason "changed:$key" -Permanent $true; return $false }
            'redotsource' { $script:PendingSupportReload = $true; return $false }   # reload no escopo de script (loop)
            'respawn'     { if (Invoke-PtuRespawnPython) { continue } else { return $false } }
            default       { Set-PtuDeferOnly -Reason "unknown-policy:$key" -Permanent $true; return $false }
        }
    }
    return $true
}

function Invoke-PtuWatchdog {
    # Re-tenta sair de defer-only RECUPERAVEL (~30s, fora do caminho quente). So SINALIZA o reload de
    # Support; o re-dot-source efetivo (e a saida de defer-only) rodam no ESCOPO DE SCRIPT (topo do
    # loop), pois dot-source dentro de funcao cairia em escopo filho. Permanente (daemon/dll) nao recupera.
    if ($script:State -ne 'defer-only' -or $script:DeferOnlyPermanent) { return }
    $script:PendingSupportReload = $true
}

# ---------------------------------------------------------------------------------------------------
# Log minimo (§7): SEM command E SEM commandHash. requestId + decisao + estado + timestamp + extra.
# ---------------------------------------------------------------------------------------------------
function Initialize-PtuLog {
    param([string] $Path)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $Path)) {
        $fs = [System.IO.File]::Create($Path); $fs.Dispose()
        $acl = [System.Security.AccessControl.FileSecurity]::new()
        $acl.SetAccessRuleProtection($true, $false)   # remove heranca
        $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $acl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($me, [System.Security.AccessControl.FileSystemRights]::FullControl, [System.Security.AccessControl.AccessControlType]::Allow))
        # .NET Core/PS7: [System.IO.File]::SetAccessControl foi removido; a extensao migrou para FileSystemAclExtensions.
        [System.IO.FileSystemAclExtensions]::SetAccessControl([System.IO.FileInfo]::new($Path), $acl)
    }
}

function Write-PtuDaemonLog {
    param([string] $RequestId, [string] $Decision, [string] $State = $script:State, [string] $Extra = '')
    try {
        $ts = [System.DateTime]::UtcNow.ToString('o')
        $line = ("{0}`t{1}`t{2}`t{3}`t{4}" -f $ts, $RequestId, $Decision, $State, $Extra)   # aspas DUPLAS: `t = TAB real (em aspas simples sairia literal)
        [System.IO.File]::AppendAllText($script:DaemonLogPath, $line + "`n", ([System.Text.UTF8Encoding]::new($false)))
    } catch {}
}

# ---------------------------------------------------------------------------------------------------
# Coordenacao: mutex e pipe com ACL so-usuario
# ---------------------------------------------------------------------------------------------------
function New-PtuUserOnlyMutex {
    param([string] $Name, [ref] $CreatedNew)
    $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $sec = [System.Security.AccessControl.MutexSecurity]::new()
    $sec.AddAccessRule([System.Security.AccessControl.MutexAccessRule]::new($me, [System.Security.AccessControl.MutexRights]::FullControl, [System.Security.AccessControl.AccessControlType]::Allow))
    return [System.Threading.MutexAcl]::Create($false, $Name, $CreatedNew, $sec)
}

function New-PtuPipeServer {
    # Cria o pipe com ACL so-usuario; retry+backoff curto cobre a corrida de cleanup do velho. $null = persistiu.
    param([string] $PipeName)
    $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $sec = [System.IO.Pipes.PipeSecurity]::new()
    $sec.AddAccessRule([System.IO.Pipes.PipeAccessRule]::new($me, [System.IO.Pipes.PipeAccessRights]::FullControl, [System.Security.AccessControl.AccessControlType]::Allow))
    for ($attempt = 0; $attempt -lt 5; $attempt++) {
        try {
            return [System.IO.Pipes.NamedPipeServerStreamAcl]::Create(
                $PipeName, [System.IO.Pipes.PipeDirection]::InOut, 1,
                [System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous,
                0, 4096, $sec)   # C: outBuffer=4096 (>= frame de resposta ~12B): o Write da resposta vai pro buffer do SO e NAO bloqueia mesmo se o cliente nao drenar
        } catch { Start-Sleep -Milliseconds (10 * ($attempt + 1)) }
    }
    return $null
}

# ---------------------------------------------------------------------------------------------------
# Decisao por requisicao
# ---------------------------------------------------------------------------------------------------
function Get-PtuDaemonDecision {
    # Recebe o payload do hook; aplica barreiras (versao §6 + pin), staleness, G2(a) (canon do cwd) e a
    # fonte unica (Get-PtuDecision -Tokenizer). Retorna 'allow'/'defer'. Qualquer falha -> 'defer'.
    param([byte[]] $PayloadBytes)
    try {
        if ($null -eq $PayloadBytes -or $PayloadBytes.Length -eq 0) { return 'defer' }
        $hook = [System.Text.Encoding]::UTF8.GetString($PayloadBytes) | ConvertFrom-Json
        $toolName  = [string](Get-PtuProp $hook 'tool_name')
        $toolInput = Get-PtuProp $hook 'tool_input'
        $command   = [string](Get-PtuProp $toolInput 'command')
        $cwd       = [string](Get-PtuProp $hook 'cwd')
        $reqVer    = [string](Get-PtuProp $hook 'ptuSafeAllowVersion')
        $reqPin    = [string](Get-PtuProp $hook 'buildContractPin')
        # staleness PRIMEIRO (frescor antes de qualquer decisao; garante que o reload de Support seja
        # sinalizado mesmo quando a versao/pin divergem) -> depois 2a barreira (§6, por-requisicao,
        # versao) + pin (3a barreira de handshake).
        if (-not (Invoke-PtuStalenessCheck)) { return 'defer' }
        if ($reqVer -cne $script:PtuSafeAllowVersion) { return 'defer' }
        if ($reqPin -cne [Ptu.BuildPin]::Value) { return 'defer' }
        # G2(a): canonicaliza o cwd POR-REQUISICAO (worker com cap/timeout) antes do escopo
        if ([string]::IsNullOrWhiteSpace($cwd)) { return 'defer' }
        $canonCwd = [Ptu.CwdWorker]::Canonicalize($cwd, $script:CwdCanonTimeoutMs, $script:CwdCanonCap)
        if ([string]::IsNullOrEmpty($canonCwd) -or
            $canonCwd -ceq [Ptu.CwdWorker]::Failed -or
            $canonCwd -ceq [Ptu.CwdWorker]::TimedOut -or
            $canonCwd -ceq [Ptu.CwdWorker]::CapExceeded) { return 'defer' }
        return (Get-PtuDecision -ToolName $toolName -Command $command -Cwd $canonCwd -Roots $script:CanonRoots -Tokenizer $script:PyTokenizer)
    } catch { return 'defer' }
}

# ===================================================================================================
# Subida
# ===================================================================================================
if ([string]::IsNullOrWhiteSpace($StartDirectory)) { $StartDirectory = $PSScriptRoot }
if ([string]::IsNullOrWhiteSpace($DllPath))        { $DllPath = Join-Path $PSScriptRoot 'PtuCanon.dll' }
if ([string]::IsNullOrWhiteSpace($PythonExe)) {
    $pc = Get-Command python -ErrorAction SilentlyContinue
    $PythonExe = if ($pc) { $pc.Source } else { $null }
}
$script:PythonExe = $PythonExe
$script:CwdCanonTimeoutMs = $CwdCanonTimeoutMs
$script:CwdCanonCap = $CwdCanonCap
$script:SupportPath  = Join-Path $PSScriptRoot 'ClaudeCodePreToolUseSafeAllowSupport.ps1'
$script:ClassifyPath = Join-Path $PSScriptRoot 'Get-ClaudeCodeBashSafeSegments.py'
$script:LoopPath     = Join-Path $PSScriptRoot 'ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py'
$script:DaemonPath   = if ($PSCommandPath) { $PSCommandPath } else { Join-Path $PSScriptRoot 'ClaudeCodePreToolUseSafeAllowDaemon.ps1' }

# Identidade (B3): dot-sourcea Support + Identity, carrega a DLL, canonicaliza repo/roots. $null -> fail-closed.
$idScript = Join-Path $PSScriptRoot 'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1'
if (-not (Test-Path -LiteralPath $idScript)) { exit 3 }
. $idScript
. $script:SupportPath
$identity = Get-PtuIdentity -StartDirectory $StartDirectory -DllPath $DllPath -Roots $Roots
if ($null -eq $identity) { exit 3 }
$names = $identity.Names
$script:DaemonLogPath = $names.DaemonLogPath
$script:CanonRoots = @($identity.RootsCanonical -split ';')

# DLL resolvida (a que Add-Type carregou) para o hash de staleness on-disk.
$script:DllResolved = $DllPath
if (-not (Test-Path -LiteralPath $script:DllResolved)) { exit 3 }

# Singleton PELO DAEMON (§5(b)): mutex de vida propria, ACL so-usuario. Abandonado = ADQUIRIDO.
$createdNew = $false
$singleton = New-PtuUserOnlyMutex -Name $names.SingletonMutexName -CreatedNew ([ref]$createdNew)
$acquired = $false
try { $acquired = $singleton.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
if (-not $acquired) { exit 0 }   # outro daemon e' o singleton -> sai cedo

try {
    Initialize-PtuLog -Path $script:DaemonLogPath

    # Self-check: tipos carregados + canonicalizacao funcional.
    if (-not ('Ptu.Canon' -as [type]) -or -not ('Ptu.BuildPin' -as [type]) -or -not ('Ptu.CwdWorker' -as [type])) { exit 4 }
    if ([string]::IsNullOrEmpty([Ptu.Canon]::CanonicalizePath($identity.RepoCanonical))) { exit 4 }

    # Python persistente 1x + handshake validado.
    if ([string]::IsNullOrWhiteSpace($script:PythonExe)) { exit 4 }
    $script:PyProc = Start-PtuPythonProcess
    if ($null -eq $script:PyProc) { exit 4 }
    $script:PyTokenizer = { param([string] $Command) Invoke-PtuPythonTokenize -Proc $script:PyProc -Command $Command }

    # Baseline de staleness (apos a DLL/python no ar).
    $script:Artifacts = [ordered]@{
        support   = @{ Path = $script:SupportPath;  Policy = 'redotsource'; Hash = ''; Size = 0; Mtime = 0 }
        classify  = @{ Path = $script:ClassifyPath; Policy = 'respawn';     Hash = ''; Size = 0; Mtime = 0 }
        shlexloop = @{ Path = $script:LoopPath;     Policy = 'respawn';     Hash = ''; Size = 0; Mtime = 0 }
        daemon    = @{ Path = $script:DaemonPath;   Policy = 'deferonly';   Hash = ''; Size = 0; Mtime = 0 }
        dll       = @{ Path = $script:DllResolved;  Policy = 'deferonly';   Hash = ''; Size = 0; Mtime = 0 }
    }
    foreach ($k in @($script:Artifacts.Keys)) { Update-PtuArtifactBaseline $k }

    Write-PtuDaemonLog -RequestId '-' -Decision 'ready' -Extra 'startup'

    # Loop SINGLE-THREADED: SO AGORA o pipe existe (ready = pipe conectavel; sem ready file).
    while (-not $script:Shutdown) {
        # Re-dot-source de Support PENDENTE roda AQUI (escopo de script) para realmente substituir as
        # funcoes e $script:PtuSafeAllowVersion (dot-source dentro de funcao cairia em escopo filho e nao
        # atualizaria as funcoes). Single-threaded garante que isto aplica antes do proximo request.
        if ($script:PendingSupportReload) {
            $script:PendingSupportReload = $false
            try {
                . $script:SupportPath
                $script:ReloadFailCount = 0
                Update-PtuArtifactBaseline 'support'
                if ($script:State -eq 'defer-only' -and -not $script:DeferOnlyPermanent) { $script:State = 'ready'; $script:DeferReason = '' }
                Write-PtuDaemonLog -RequestId '-' -Decision $script:State -Extra 'support-reloaded'
            } catch {
                $script:ReloadFailCount++
                if ($script:ReloadFailCount -ge 3) { Set-PtuDeferOnly -Reason 'support-reload-failed-x3' -Permanent $false }
            }
        }
        $server = New-PtuPipeServer -PipeName $names.PipeName
        if ($null -eq $server) { Set-PtuDeferOnly -Reason 'pipe-create-failed' -Permanent $false; Start-Sleep -Milliseconds 50; continue }
        try {
            $connTask = $server.WaitForConnectionAsync()
            while (-not $connTask.Wait(30000)) { Invoke-PtuWatchdog }   # watchdog ~30s na ociosidade

            if ($script:PyProc.HasExited) { [void](Invoke-PtuRespawnPython) }

            $decision = 'defer'
            $requestId = '-'
            try {
                $frame = Read-PtuFrame -Stream $server -TimeoutMs $RequestTimeoutMs
                if ($null -ne $frame) {
                    if ($frame.Magic -eq $script:MAGIC_SHUTDOWN) {
                        $script:Shutdown = $true   # ACL do pipe ja restringe ao usuario (§7)
                    }
                    elseif ($frame.Magic -eq $script:MAGIC_DATA -and $frame.ProtoVer -eq $script:PtuProtocolVersion) {
                        try {
                            $peek = [System.Text.Encoding]::UTF8.GetString($frame.Payload) | ConvertFrom-Json
                            $requestId = [string](Get-PtuProp $peek 'requestId')
                            if ([string]::IsNullOrEmpty($requestId)) { $requestId = '-' }
                        } catch { $requestId = '-' }
                        $decision = Get-PtuDaemonDecision -PayloadBytes $frame.Payload
                    }
                }
            } catch { $decision = 'defer' }

            if (-not $script:Shutdown) {
                try { Write-PtuFrame -Stream $server -Magic $script:MAGIC_DATA -Bytes ([System.Text.Encoding]::UTF8.GetBytes($decision)) -TimeoutMs $RequestTimeoutMs } catch {}
                Write-PtuDaemonLog -RequestId $requestId -Decision $decision
            } else {
                Write-PtuDaemonLog -RequestId '-' -Decision 'shutdown'
            }
        } finally { $server.Dispose() }
    }
}
finally {
    if ($null -ne $script:PyProc) { try { $script:PyProc.Kill() } catch {}; try { $script:PyProc.Dispose() } catch {} }
    try { $singleton.ReleaseMutex() } catch {}
    try { $singleton.Dispose() } catch {}
}
exit 0
