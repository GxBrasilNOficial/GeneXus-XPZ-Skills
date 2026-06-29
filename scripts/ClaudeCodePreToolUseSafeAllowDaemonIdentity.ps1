#requires -Version 7.4
# ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1 - identidade do daemon PreToolUse (auto-allow) do
# Claude Code. PASSO B3 (claude-code-pretooluse-implementacao-v1-plan.md, linhas 85-101). Solucao
# especifica do Claude Code; nao se aplica a Codex/Cursor/OpenCode. Dot-source para reusar as funcoes.
#
# IdentityHash = SHA256( sid + "\0" + repoCanonical + "\0" + rootsCanonical ). Todos os artefatos de
# coordenacao (pipe, mutex singleton do daemon, mutex de guarda do cliente, logs) derivam do MESMO
# hash, para que cliente e daemon do MESMO checkout/branch/roots se encontrem e os de identidade
# divergente NUNCA respondam um pelo outro (1a barreira de Get-PtuDecision e' Test-PtuCwdInScope).
#
# canonicalizePath vem da DLL UNICA PtuCanon (Add-Type -Path; mesmo .cs do cliente NativeAOT, Passo B1).
# Tudo e' FAIL-CLOSED: qualquer componente invalido -> identidade $null -> o chamador trata como 'defer'.

Set-StrictMode -Version Latest

# Nome do marcador dedicado da raiz do repo (criado pelo install, Passo G). Estavel; nao e' o .md
# (que move/renomeia) nem .git (que aninha).
$script:PtuMarkerName = '.ptu-safe-allow-root'

# Get-PtuRoots vive no Support.ps1 co-localizado; dot-source best-effort (idempotente). O daemon ja
# carrega o Support; aqui garante a funcao quando este script e' usado/testado isolado.
$script:PtuIdentitySupportPath = Join-Path $PSScriptRoot 'ClaudeCodePreToolUseSafeAllowSupport.ps1'
if (Test-Path -LiteralPath $script:PtuIdentitySupportPath) { . $script:PtuIdentitySupportPath }

function Import-PtuCanon {
    # Carrega a DLL PtuCanon (tipo [Ptu.Canon]) via Add-Type -Path, SO se ainda nao estiver carregada.
    # $true se [Ptu.Canon] esta disponivel ao fim; $false em qualquer falha (DLL ausente/invalida).
    param([Parameter(Mandatory)][string] $DllPath)
    if ('Ptu.Canon' -as [type]) { return $true }
    if ([string]::IsNullOrWhiteSpace($DllPath) -or -not (Test-Path -LiteralPath $DllPath -PathType Leaf)) { return $false }
    try { Add-Type -Path $DllPath -ErrorAction Stop } catch { return $false }
    return [bool]('Ptu.Canon' -as [type])
}

function Invoke-PtuCanonicalize {
    # Wrapper de [Ptu.Canon]::CanonicalizePath: $null se o tipo nao esta carregado ou em qualquer falha.
    param([string] $Path)
    if ([string]::IsNullOrEmpty($Path)) { return $null }
    if (-not ('Ptu.Canon' -as [type])) { return $null }
    try { return [Ptu.Canon]::CanonicalizePath($Path) } catch { return $null }
}

function Resolve-PtuRepoMarkerDir {
    # Ascensao determinista de StartDirectory ate a raiz do drive, COLETANDO todo ancestral (inclusive
    # o proprio start) que contenha um FILE de nome EXATO $PtuMarkerName. Reconciliacao da SPEC §B
    # ("parar no 1o match ao subir" + "ZERO/MULTIPLOS/AUSENTE -> INVALIDA") com a detecao de marcador
    # orfao pedida na §4: varre a cadeia INTEIRA; valido SO com EXATAMENTE 1 marcador (entao o 1o == o
    # unico). 0 (ausente) ou >=2 (orfao em ancestral) -> $null (fail-closed). File.Exists ignora
    # diretorio homonimo (marcador tem de ser arquivo) e casa o nome de forma case-insensitive (norma
    # do filesystem Windows). Conjunto + regra IDENTICOS no cliente (EXE) e no daemon (scripts\).
    param([Parameter(Mandatory)][string] $StartDirectory)
    if ([string]::IsNullOrWhiteSpace($StartDirectory)) { return $null }
    $markerDirs = [System.Collections.Generic.List[string]]::new()
    try { $dir = [System.IO.DirectoryInfo]::new($StartDirectory) } catch { return $null }
    while ($null -ne $dir) {
        $candidate = [System.IO.Path]::Combine($dir.FullName, $script:PtuMarkerName)
        if ([System.IO.File]::Exists($candidate)) { $markerDirs.Add($dir.FullName) }
        $dir = $dir.Parent
    }
    if ($markerDirs.Count -eq 1) { return $markerDirs[0] }
    return $null
}

function Get-PtuCanonicalRepoRoot {
    # Marcador da raiz -> canonicalizePath. $null propaga (marcador invalido OU canonicalizacao falha).
    param([Parameter(Mandatory)][string] $StartDirectory)
    $markerDir = Resolve-PtuRepoMarkerDir -StartDirectory $StartDirectory
    if ($null -eq $markerDir) { return $null }
    return (Invoke-PtuCanonicalize -Path $markerDir)
}

function ConvertTo-PtuRootsCanonical {
    # Cada root por canonicalizePath; dedup ordinal-IgnoreCase preservando 1a ocorrencia; ordena
    # ordinal; join ';'. QUALQUER root vazio ou que nao canonicalize -> $null (fail-closed: identidade
    # invalida). As saidas ja vem minusculas (canonicalizePath aplica ToLowerInvariant).
    param([string[]] $Roots)
    $list = @($Roots)
    if ($list.Count -lt 1) { return $null }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $canon = [System.Collections.Generic.List[string]]::new()
    foreach ($r in $list) {
        if ([string]::IsNullOrWhiteSpace($r)) { return $null }
        $c = Invoke-PtuCanonicalize -Path $r
        if ($null -eq $c) { return $null }
        if ($seen.Add($c)) { $canon.Add($c) }
    }
    if ($canon.Count -lt 1) { return $null }
    $canon.Sort([System.StringComparer]::Ordinal)
    return [string]::Join(';', $canon)
}

function Get-PtuIdentityHashFromParts {
    # PURA: SHA256( sid + "\0" + repoCanonical + "\0" + rootsCanonical ) em UTF-8 -> hex minusculo.
    # O separador NUL ("`0") evita colisao por concatenacao ambigua entre os 3 componentes.
    param(
        [Parameter(Mandatory)][string] $Sid,
        [Parameter(Mandatory)][string] $RepoCanonical,
        [Parameter(Mandatory)][string] $RootsCanonical
    )
    $material = $Sid + "`0" + $RepoCanonical + "`0" + $RootsCanonical
    $bytes = ([System.Text.UTF8Encoding]::new($false)).GetBytes($material)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [System.Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-PtuIdentityNames {
    # PURA: deriva os nomes de coordenacao do MESMO IdentityHash (interface consumida pelos Passos C/D).
    # IdentityHash invalido (nao 64 hex minusculos) -> $null.
    param([Parameter(Mandatory)][string] $IdentityHash)
    if ($IdentityHash -cnotmatch '^[0-9a-f]{64}$') { return $null }
    $h = $IdentityHash
    $logDir = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ClaudeCodePreToolUseSafeAllow'
    return [pscustomobject]@{
        IdentityHash       = $h
        PipeName           = "ptu-safe-allow-$h"
        PipePath           = "\\.\pipe\ptu-safe-allow-$h"
        SingletonMutexName = "Local\ptu-safe-allow-singleton-$h"
        GuardMutexName     = "Local\ptu-safe-allow-guard-$h"
        LogDirectory       = $logDir
        DaemonLogPath      = (Join-Path $logDir "ptu-daemon-$h.log")
        ClientLogPath      = (Join-Path $logDir "ptu-client-$h.log")
    }
}

function Get-PtuCurrentUserSid {
    # SID do usuario corrente (estavel; nao muda em renomeacao de conta, ao contrario de USERNAME).
    try { return [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value } catch { return $null }
}

function Get-PtuIdentity {
    # Orquestra a identidade completa. Algum componente invalido -> $null (fail-closed -> 'defer').
    # StartDirectory: localizacao do binario/script (daemon: $PSScriptRoot; cliente: dir do EXE).
    # DllPath: PtuCanon.dll co-localizada (Passo G). Roots: opcional; default = Get-PtuRoots (Support).
    param(
        [Parameter(Mandatory)][string] $StartDirectory,
        [Parameter(Mandatory)][string] $DllPath,
        [string[]] $Roots
    )
    if (-not (Import-PtuCanon -DllPath $DllPath)) { return $null }
    $sid = Get-PtuCurrentUserSid
    if ([string]::IsNullOrWhiteSpace($sid)) { return $null }
    $repo = Get-PtuCanonicalRepoRoot -StartDirectory $StartDirectory
    if ($null -eq $repo) { return $null }
    if ($null -eq $Roots) {
        if (Get-Command -Name Get-PtuRoots -ErrorAction SilentlyContinue) { $Roots = @(Get-PtuRoots) }
        else { return $null }
    }
    $rootsCanon = ConvertTo-PtuRootsCanonical -Roots $Roots
    if ($null -eq $rootsCanon) { return $null }
    $hash = Get-PtuIdentityHashFromParts -Sid $sid -RepoCanonical $repo -RootsCanonical $rootsCanon
    $names = Get-PtuIdentityNames -IdentityHash $hash
    if ($null -eq $names) { return $null }
    return [pscustomobject]@{
        Sid            = $sid
        RepoCanonical  = $repo
        RootsCanonical = $rootsCanon
        IdentityHash   = $hash
        Names          = $names
    }
}
