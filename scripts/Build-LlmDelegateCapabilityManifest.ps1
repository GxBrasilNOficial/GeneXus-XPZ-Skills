#requires -Version 7.4
<#
.SYNOPSIS
    Sonda os backends de LLM da skill xpz-llm-delegate instalados na maquina e grava um
    manifesto de CAPACIDADE sanitizado (quais backends/modelos estao disponiveis e se
    sao locais ou externos), para alimentar a OFERTA de painel de revisao por pares sem
    re-sondar a cada uso.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia de revisao por pares em
    15-revisao-por-pares.md. O manifesto e fato da MAQUINA (machine-level), gravado fora
    do git (default %LOCALAPPDATA%\xpz-llm-delegate\capabilities.json).

    DICA, NUNCA VERDADE DO GATE: este manifesto serve a oferta/UI. O gate de
    confidencialidade (Resolve-LlmDelegateAuthorization.ps1) NAO consome este arquivo;
    ele reavalia destino e sensibilidade deterministicamente a cada uso. Nao acoplar.

    SANITIZACAO POR DESENHO: o manifesto grava SOMENTE metadados nao sensiveis, como
    backend, targetModelKey, canonicalModel, provider, family, sourceKind, sourceConfidence,
    availableInManifest, locality, reasonCode (codigo curto, sem host/baseURL), hardVeto e
    diagnostics. NUNCA grava token, chave de API, baseURL/host, header, caminho de config,
    prompt nem politica por-KB. O self-test prova essa ausencia.

    ENUMERACAO: opencode le provider/modelo em opencode.json/jsonc; Codex usa config.toml
    e resolvedor; Claude Code combina settings configurado e cache historico/fraco
    (enumeration=settings-or-historical); Antigravity CLI sonda modelos via agy models
    (enumeration=cli). Copilot e Gemini seguem registrados como instalados sem enumeracao nativa
    forte (models=[] e enumeration=none-native); o modelo default deles vive na doc da skill/no 14, nao aqui.

    ESTAVEL vs VOLATIL: o que o manifesto grava (instalado? local/externo?) e estavel e
    cacheavel. A SAUDE do backend ("responde agora?") e volatil e fica em lastHealthCheck
    (null por padrao) - reverificada de leve no momento da revisao, nao nesta sondagem.

    Reuso: chama Resolve-OpenCodeModelLocality.ps1, Resolve-CodexModelLocality.ps1,
    Resolve-ClaudeCodeModelLocality.ps1, Resolve-CopilotModelLocality.ps1, Resolve-GeminiModelLocality.ps1
    e Resolve-AntigravityModelLocality.ps1 em processo para a localidade de cada modelo (a chave
    de destino canonica). A enumeracao em si (listar os modelos) e logica propria deste script,
    pois os resolvers classificam UM modelo dado.
.PARAMETER OutputPath
    Caminho do manifesto machine-level. Default: %LOCALAPPDATA%\xpz-llm-delegate\capabilities.json.
.PARAMETER SnapshotPath
    Quando informado, grava tambem um snapshot por-KB (cache re-derivavel) com snapshotAt e
    sourceGeneratedAt. O setup da pasta paralela usa Temp\llm-delegate-capabilities.snapshot.json.
.PARAMETER OpenCodeConfigPath
    Caminho do opencode.json/jsonc. Default: ~/.config/opencode/opencode.json; se ausente,
    tenta ~/.config/opencode/opencode.jsonc.
.PARAMETER CodexConfigPath
    Caminho do config.toml do Codex. Default: ~/.codex/config.toml.
.PARAMETER ClaudeSettingsPath
    Caminho do settings.json/jsonc do Claude Code. Default: ~/.claude/settings.json.
.PARAMETER ClaudeStatsCachePath
    Caminho opcional do stats-cache.json do Claude Code. Fonte historica/fraca.
.PARAMETER AntigravityExe
    Caminho do executavel do Antigravity CLI (agy.exe). Quando omitido, e resolvido via AntigravityCliSupport.ps1.
.EXAMPLE
    .\Build-LlmDelegateCapabilityManifest.ps1
.EXAMPLE
    .\Build-LlmDelegateCapabilityManifest.ps1 -SnapshotPath 'C:\KB\Parallel\Temp\llm-delegate-capabilities.snapshot.json'
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'capabilities.json'),
    [string] $SnapshotPath,
    [string] $OpenCodeConfigPath = (Join-Path $HOME '.config' | Join-Path -ChildPath 'opencode' | Join-Path -ChildPath 'opencode.json'),
    [string] $CodexConfigPath = (Join-Path $HOME '.codex' | Join-Path -ChildPath 'config.toml'),
    [string] $ClaudeSettingsPath = (Join-Path $HOME '.claude' | Join-Path -ChildPath 'settings.json'),
    [string] $ClaudeStatsCachePath = (Join-Path $HOME '.claude' | Join-Path -ChildPath 'stats-cache.json'),
    [string] $AntigravityExe
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
. (Join-Path $scriptsDir 'LlmDelegateTargetFamilySupport.ps1')
$openResolver = Join-Path $scriptsDir 'Resolve-OpenCodeModelLocality.ps1'
$codexResolver = Join-Path $scriptsDir 'Resolve-CodexModelLocality.ps1'
$claudeResolver = Join-Path $scriptsDir 'Resolve-ClaudeCodeModelLocality.ps1'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Test-CommandPresent {
    param([string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function ConvertFrom-JsoncText {
    param([Parameter(Mandatory)] [string]$Text)
    $withoutBlock = [regex]::Replace($Text, '(?s)/\*.*?\*/', '')
    $withoutLine = [regex]::Replace($withoutBlock, '(?m)^\s*//.*$', '')
    $withoutTrailingCommas = [regex]::Replace($withoutLine, ',(\s*[\}\]])', '$1')
    return $withoutTrailingCommas | ConvertFrom-Json
}

function Read-JsonOrJsoncFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return ConvertFrom-JsoncText -Text (Get-Content -LiteralPath $Path -Raw -Encoding utf8)
}

function Resolve-OpenCodeConfigPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return $Path }
    if ($Path.EndsWith('.json', [System.StringComparison]::OrdinalIgnoreCase)) {
        $jsonc = $Path.Substring(0, $Path.Length - 5) + '.jsonc'
        if (Test-Path -LiteralPath $jsonc -PathType Leaf) { return $jsonc }
    }
    return $Path
}

# Mapeia a saida do resolver para um reasonCode CURTO e sanitizado (sem host/baseURL).
function ConvertTo-ReasonCode {
    param([string]$Locality)
    switch ($Locality) {
        'local' { 'loopback-local' }
        'external' { 'external' }
        default { 'unknown' }
    }
}

function Get-ProviderFromModelKey {
    param([string]$TargetModelKey)
    if ([string]::IsNullOrWhiteSpace($TargetModelKey) -or $TargetModelKey -notmatch '/') { return 'unknown' }
    return @($TargetModelKey -split '/', 2)[0]
}

function Test-HardVetoModel {
    param([string]$TargetModelKey)
    if ([string]::IsNullOrWhiteSpace($TargetModelKey)) { return $false }
    $modelPart = @($TargetModelKey -split '/')[-1].ToLowerInvariant()
    foreach ($v in @('mistral-large-3', 'nemotron-3-ultra')) {
        if ($modelPart.Contains($v)) { return $true }
    }
    return $false
}

function New-CapabilityEntry {
    param(
        [Parameter(Mandatory)] [string]$Backend,
        [Parameter(Mandatory)] [string]$TargetModelKey,
        [string]$CanonicalModel,
        [string]$Provider,
        [string]$Family,
        [string]$Locality = 'unknown',
        [ValidateSet('configured', 'catalog', 'cache', 'historical', 'probe', 'cli')] [string]$SourceKind = 'configured',
        [ValidateSet('strong', 'medium', 'weak')] [string]$SourceConfidence = 'strong',
        [bool]$AvailableInManifest = $true,
        [string[]]$Diagnostics = @()
    )
    if ([string]::IsNullOrWhiteSpace($CanonicalModel)) { $CanonicalModel = $TargetModelKey }
    if ([string]::IsNullOrWhiteSpace($Provider)) { $Provider = Get-ProviderFromModelKey $CanonicalModel }
    if ([string]::IsNullOrWhiteSpace($Family)) { $Family = Get-LlmDelegateTargetFamily -TargetModelKey $CanonicalModel }
    if ([string]::IsNullOrWhiteSpace($Family)) { $Family = $Provider }
    [pscustomobject]@{
        backend             = $Backend
        targetModelKey      = $TargetModelKey
        canonicalModel      = $CanonicalModel
        provider            = $Provider
        family              = $Family
        sourceKind          = $SourceKind
        sourceConfidence    = $SourceConfidence
        availableInManifest = $AvailableInManifest
        locality            = $Locality
        reasonCode          = ConvertTo-ReasonCode $Locality
        hardVeto            = (Test-HardVetoModel $CanonicalModel)
        diagnostics         = @($Diagnostics | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}

function Get-OpenCodeModelEntries {
    param([string]$ConfigPath)
    $entries = @()
    $ConfigPath = Resolve-OpenCodeConfigPath -Path $ConfigPath
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $entries }
    $cfg = $null
    try { $cfg = Read-JsonOrJsoncFile -Path $ConfigPath } catch { return $entries }
    $providers = Get-Prop $cfg 'provider'
    if ($null -eq $providers) { return $entries }
    foreach ($prop in $providers.PSObject.Properties) {
        $provName = $prop.Name
        $modelsNode = Get-Prop $prop.Value 'models'
        if ($null -eq $modelsNode) { continue }
        foreach ($modelProp in $modelsNode.PSObject.Properties) {
            $canonical = "$provName/$($modelProp.Name)"
            $locality = 'unknown'
            try {
                $resJson = & $openResolver -Model $canonical -ConfigPath $ConfigPath
                if ($resJson) {
                    $res = $resJson | ConvertFrom-Json
                    $locality = [string](Get-Prop $res 'locality')
                }
            } catch { $locality = 'unknown' }
            $entries += New-CapabilityEntry -Backend 'opencode' -TargetModelKey $canonical `
                -CanonicalModel $canonical -Provider $provName -Locality $locality `
                -SourceKind 'configured' -SourceConfidence 'strong' -AvailableInManifest $true
        }
    }
    return $entries
}

function Get-CodexProfileIds {
    param([string]$ConfigPath)
    $ids = @()
    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) { return $ids }
    foreach ($rawLine in (Get-Content -LiteralPath $ConfigPath -Encoding utf8)) {
        $m = [regex]::Match($rawLine.Trim(), '^\[profiles\.([^\]]+)\]')
        if ($m.Success) { $ids += $m.Groups[1].Value.Trim() }
    }
    return $ids
}

function Get-CodexModelEntries {
    param([string]$ConfigPath)
    $entries = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Cada invocacao do resolver: $null = default (deriva o model de topo da config);
    # caso contrario, um profile declarado. Chamada DIRETA (sem splat de array, que nao
    # vincula parametro nomeado de forma confiavel) e sem funcao aninhada (que quebraria
    # o `+=` por escopo); a List muta por referencia via .Add().
    $profilesToProbe = @($null) + @(Get-CodexProfileIds -ConfigPath $ConfigPath)

    foreach ($profileId in $profilesToProbe) {
        try {
            if ([string]::IsNullOrWhiteSpace([string]$profileId)) {
                $resJson = & $codexResolver -ConfigPath $ConfigPath
            }
            else {
                $resJson = & $codexResolver -Profile $profileId -ConfigPath $ConfigPath
            }
            if (-not $resJson) { continue }
            $res = $resJson | ConvertFrom-Json
            $canonical = [string](Get-Prop $res 'canonicalModel')
            if ([string]::IsNullOrWhiteSpace($canonical)) { continue }
            $provider = [string](Get-Prop $res 'provider')
            if ([string]::IsNullOrWhiteSpace($provider) -or $canonical -notmatch '/') {
                if (-not $seen.Add("weak:$canonical")) { continue }
                $entries.Add((New-CapabilityEntry -Backend 'codex' -TargetModelKey $canonical `
                            -CanonicalModel $canonical -Provider 'unknown' -Locality 'unknown' `
                            -SourceKind 'configured' -SourceConfidence 'weak' -AvailableInManifest $true `
                            -Diagnostics @('provider de destino nao comprovado pelo resolvedor; nao inventar prefixo openai')))
                continue
            }
            if (-not $seen.Add($canonical)) { continue }
            $locality = [string](Get-Prop $res 'locality')
            $entries.Add((New-CapabilityEntry -Backend 'codex' -TargetModelKey $canonical `
                        -CanonicalModel $canonical -Provider $provider -Locality $locality `
                        -SourceKind 'configured' -SourceConfidence 'strong' -AvailableInManifest $true))
        } catch { }
    }
    return $entries
}

function Get-ClaudeCodeModelEntries {
    param([string]$SettingsPath, [string]$StatsCachePath)
    $entries = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($source in @(
            @{ path = $SettingsPath; kind = 'configured'; confidence = 'strong' }
            @{ path = $StatsCachePath; kind = 'historical'; confidence = 'weak' }
        )) {
        if (-not (Test-Path -LiteralPath $source.path -PathType Leaf)) { continue }
        $raw = Get-Content -LiteralPath $source.path -Raw -Encoding utf8
        $matches = [regex]::Matches($raw, '(?i)\b(claude-[a-z0-9][a-z0-9\-]*|opus)\b')
        foreach ($m in $matches) {
            $model = $m.Groups[1].Value
            try {
                $res = (& $claudeResolver -Model $model) | ConvertFrom-Json
                $canonical = [string](Get-Prop $res 'canonicalModel')
                if ([string]::IsNullOrWhiteSpace($canonical)) { continue }
                $seenKey = "$($source.kind):$canonical"
                if (-not $seen.Add($seenKey)) { continue }
                $diagnostics = @()
                if ($source.kind -eq 'historical') { $diagnostics += 'fonte historica/fraca; nao prova disponibilidade atual' }
                $entries.Add((New-CapabilityEntry -Backend 'claude-code' -TargetModelKey $canonical `
                            -CanonicalModel $canonical -Provider ([string](Get-Prop $res 'provider')) `
                            -Locality ([string](Get-Prop $res 'locality')) -SourceKind $source.kind `
                            -SourceConfidence $source.confidence -AvailableInManifest ($source.kind -ne 'historical') `
                            -Diagnostics $diagnostics))
            } catch { }
        }
    }
    return $entries
}

# --- Monta os backends -----------------------------------------------------

$backends = @()

$backends += [pscustomobject]@{
    backend     = 'opencode'
    installed   = (Test-CommandPresent 'opencode')
    enumeration = 'config'
    models      = @(Get-OpenCodeModelEntries -ConfigPath $OpenCodeConfigPath)
}

$backends += [pscustomobject]@{
    backend     = 'codex'
    installed   = (Test-CommandPresent 'codex')
    enumeration = 'config'
    models      = @(Get-CodexModelEntries -ConfigPath $CodexConfigPath)
}

$backends += [pscustomobject]@{
    backend     = 'claude-code'
    installed   = (Test-CommandPresent 'claude')
    enumeration = 'settings-or-historical'
    models      = @(Get-ClaudeCodeModelEntries -SettingsPath $ClaudeSettingsPath -StatsCachePath $ClaudeStatsCachePath)
}

function Get-AntigravityModelEntries {
    param([string]$AntigravityExe)
    $entries = [System.Collections.Generic.List[object]]::new()
    $antigravityResolver = Join-Path $PSScriptRoot 'Resolve-AntigravityModelLocality.ps1'
    if (-not (Test-Path -LiteralPath $antigravityResolver -PathType Leaf)) { return $entries }

    $exe = $AntigravityExe
    if (-not $exe) {
        $supportScript = Join-Path $PSScriptRoot 'AntigravityCliSupport.ps1'
        if (Test-Path -LiteralPath $supportScript -PathType Leaf) {
            . $supportScript
            try { $exe = Resolve-AntigravityExe -SkipContractCheck } catch { }
        }
    }

    if (-not $exe -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) { return $entries }

    # `agy models` e a UNICA sondagem deste manifesto que EXECUTA um CLI e espera resposta de rede
    # (opencode/codex/claude-code leem arquivo de config; copilot/gemini so checam presenca no PATH).
    # Sem teto de tempo, um CLI que pendure - token expirado que caia em prompt interativo de login,
    # rede lenta, servico fora do ar - penduraria o manifesto INTEIRO, e com ele a oferta de painel e
    # o snapshot do xpz-kb-parallel-setup. Medido em 2026-08-06: 2,2s no caminho feliz (~80% do tempo
    # total do manifesto). Teto de 20s = folga larga sobre isso sem virar trava. Estouro/erro degrada
    # para lista vazia -> enumeration=none-native, o mesmo caminho ja usado quando nao ha modelos.
    $AntigravityProbeTimeoutSec = 20
    $rawModels = @()
    $proc = $null
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = $exe
        $psi.ArgumentList.Add('models')
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true    # fechado logo abaixo: EOF puro, sem pendurar em TTY
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Close()
        # Drenar os DOIS pipes de forma assincrona antes do WaitForExit. O stderr nao e consumido,
        # mas precisa ser lido: pipe cheio bloqueia o processo filho e o timeout viraria a regra em
        # vez da excecao.
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $null = $proc.StandardError.ReadToEndAsync()

        if ($proc.WaitForExit($AntigravityProbeTimeoutSec * 1000)) {
            $rawOutput = $stdoutTask.GetAwaiter().GetResult()
            if ($proc.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($rawOutput)) {
                $rawModels = @($rawOutput -split "`r?`n" | Where-Object { $_ -match '^[a-z0-9][a-z0-9\-\.]+$' })
            }
        }
        else {
            try { $proc.Kill($true) } catch { }
        }
    } catch { }
    finally {
        if ($null -ne $proc) { try { $proc.Dispose() } catch { } }
    }

    if ($rawModels.Count -eq 0) {
        return $entries
    }

    foreach ($m in $rawModels) {
        try {
            $res = (& $antigravityResolver -Model $m) | ConvertFrom-Json
            $canonical = [string](Get-Prop $res 'canonicalModel')
            if ([string]::IsNullOrWhiteSpace($canonical)) { continue }
            $entries.Add((New-CapabilityEntry -Backend 'antigravity' -TargetModelKey $canonical `
                        -CanonicalModel $canonical -Provider ([string](Get-Prop $res 'provider')) `
                        -Family ([string](Get-Prop $res 'family')) `
                        -Locality ([string](Get-Prop $res 'locality')) -SourceKind 'cli' `
                        -SourceConfidence 'strong' -AvailableInManifest $true))
        } catch { }
    }
    return $entries
}

function Test-AntigravityPresent {
    param([string]$AntigravityExe)
    if ($AntigravityExe -and (Test-Path -LiteralPath $AntigravityExe -PathType Leaf)) { return $true }
    $supportScript = Join-Path $PSScriptRoot 'AntigravityCliSupport.ps1'
    if (Test-Path -LiteralPath $supportScript -PathType Leaf) {
        . $supportScript
        try { return [bool](Resolve-AntigravityExe -SkipContractCheck) } catch { return $false }
    }
    return (Test-CommandPresent 'agy')
}

foreach ($b in @(
        @{ name = 'copilot'; cmd = 'copilot' }
        @{ name = 'gemini'; cmd = 'gemini' }
    )) {
    $backends += [pscustomobject]@{
        backend     = $b.name
        installed   = (Test-CommandPresent $b.cmd)
        enumeration = 'none-native'
        models      = @()
    }
}

$isAgyInstalled = Test-AntigravityPresent -AntigravityExe $AntigravityExe
$agyModelEntries = @(Get-AntigravityModelEntries -AntigravityExe $AntigravityExe)
$hasAgyModels = ($agyModelEntries.Count -gt 0)

$backends += [pscustomobject]@{
    backend     = 'antigravity'
    installed   = $isAgyInstalled
    enumeration = if ($hasAgyModels) { 'cli' } else { 'none-native' }
    models      = [object[]]$agyModelEntries
}

$generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$manifest = [pscustomobject]@{
    schemaVersion   = 1
    generatedAt     = $generatedAt
    backends        = $backends
    lastHealthCheck = $null
}

# --- Grava o manifesto machine-level ---------------------------------------

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$manifestJson = $manifest | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $OutputPath -Value $manifestJson -Encoding utf8

# --- Snapshot por-KB opcional (cache re-derivavel) -------------------------

if (-not [string]::IsNullOrWhiteSpace($SnapshotPath)) {
    $snapDir = Split-Path -Parent $SnapshotPath
    if ($snapDir -and -not (Test-Path -LiteralPath $snapDir)) {
        New-Item -ItemType Directory -Path $snapDir -Force | Out-Null
    }
    $snapshot = [pscustomobject]@{
        schemaVersion     = 1
        snapshotAt        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        sourceGeneratedAt = $generatedAt
        backends          = $backends
        lastHealthCheck   = $null
    }
    Set-Content -LiteralPath $SnapshotPath -Value ($snapshot | ConvertTo-Json -Depth 8) -Encoding utf8
}

# Saida de maquina: o manifesto.
$manifestJson
