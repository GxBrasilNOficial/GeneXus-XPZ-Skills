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

    SANITIZACAO POR DESENHO: o manifesto grava SOMENTE metadados nao sensiveis -
    canonicalModel, backend, locality, reasonCode (codigo curto, sem host/baseURL) e
    sourceKind. NUNCA grava token, chave de API, baseURL/host, header, caminho de config,
    prompt nem politica por-KB. O self-test prova essa ausencia.

    ENUMERACAO: so opencode (provider/modelo em opencode.json) e Codex (config.toml) tem
    fonte de enumeracao de modelos. Claude Code, Copilot e Gemini nao tem enumeracao
    nativa - registrados como instalados com models=[] e enumeration=none-native; o modelo
    default deles vive na doc da skill/no 14, nao aqui.

    ESTAVEL vs VOLATIL: o que o manifesto grava (instalado? local/externo?) e estavel e
    cacheavel. A SAUDE do backend ("responde agora?") e volatil e fica em lastHealthCheck
    (null por padrao) - reverificada de leve no momento da revisao, nao nesta sondagem.

    Reuso: chama Resolve-OpenCodeModelLocality.ps1 / Resolve-CodexModelLocality.ps1 em
    processo para a localidade de cada modelo (a chave de destino canonica). A enumeracao
    em si (listar os modelos) e logica nova, pois os resolvers classificam UM modelo dado.
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
    [string] $ClaudeStatsCachePath = (Join-Path $HOME '.claude' | Join-Path -ChildPath 'stats-cache.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
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
        [string]$Locality = 'unknown',
        [ValidateSet('configured', 'catalog', 'cache', 'historical', 'probe')] [string]$SourceKind = 'configured',
        [ValidateSet('strong', 'medium', 'weak')] [string]$SourceConfidence = 'strong',
        [bool]$AvailableInManifest = $true,
        [string[]]$Diagnostics = @()
    )
    if ([string]::IsNullOrWhiteSpace($CanonicalModel)) { $CanonicalModel = $TargetModelKey }
    if ([string]::IsNullOrWhiteSpace($Provider)) { $Provider = Get-ProviderFromModelKey $CanonicalModel }
    [pscustomobject]@{
        backend             = $Backend
        targetModelKey      = $TargetModelKey
        canonicalModel      = $CanonicalModel
        provider            = $Provider
        family              = $Provider
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
