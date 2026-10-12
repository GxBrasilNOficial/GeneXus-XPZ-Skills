#requires -Version 7.4

<#
.SYNOPSIS
    Classifica, de forma deterministica, se uma invocacao do Codex roda LOCAL (na maquina)
    ou EXTERNO (sai da maquina), e devolve o provider/modelo de DESTINO canonico.
.DESCRIPTION
    Backend codex da skill xpz-llm-delegate. Espelha o criterio do resolvedor opencode
    (Resolve-OpenCodeModelLocality.ps1): a localidade vem da baseURL do provider de destino,
    nao do nome do modelo.

    EIXO (ver secao ANATOMIA da skill): este script traduz a invocacao do Codex para a
    chave de DESTINO que o gate e a politica usam. O backend/adapter (Codex vs opencode)
    NAO entra na chave: se o trafego vai para a OpenAI, a chave e openai/<modelo>, igual
    ao opencode. Por isso uma regra de politica 'openai/*' cobre os dois backends.

    O Codex nao usa o formato provider/modelo na linha de comando (quando -Model e informado,
    usa '-m <modelo>' nu; quando omitido, vale o default do proprio Codex/config). Este
    resolvedor determina o provider efetivo:

        -Oss / -LocalProvider <ollama|lmstudio>  -> provider OSS local (loopback) -> local
        -Profile <id>                            -> [profiles.<id>].model_provider ->
                                                    [model_providers.<prov>].base_url -> loopback?
        nem oss nem profile                      -> model_provider de topo da config, ou
                                                    'openai' (built-in, sem base_url) -> external

    Classificacao pela base_url (igual ao opencode):
        - loopback (127.x / localhost / ::1)        -> local
        - base_url externa explicita                -> external
        - provider built-in sem base_url na config  -> external (endpoint remoto por definicao)
        - profile/provider nao resolvivel           -> unknown

    O gate de confidencialidade (Resolve-LlmDelegateAuthorization.ps1) trata 'external' e
    'unknown' como exigindo autorizacao para payload sensivel.

    Saida: objeto JSON de maquina no stdout, com os mesmos campos do resolvedor opencode
    mais 'canonicalModel' (a chave de destino que o gate casa na politica).
.PARAMETER Model
    Nome do modelo como o Codex o aceita (ex: gpt-5.5). Opcional; quando omitido, o
    resolvedor tenta derivar de [profiles.<id>].model ou do model de topo da config.
    Aceita tambem a forma prefixada (openai/gpt-5.5); nesse caso so a parte do modelo e
    usada, e o provider e determinado pela invocacao/config, nao pelo prefixo.
.PARAMETER Oss
    Indica invocacao com provider open-source local (codex exec --oss). Implica local.
.PARAMETER LocalProvider
    Provider OSS local quando -Oss: 'ollama' (default) ou 'lmstudio'.
.PARAMETER Profile
    Nome do profile da config do Codex (codex exec -p <id>). Resolve o model_provider e a
    base_url a partir de [profiles.<id>] / [model_providers.<prov>].
.PARAMETER ConfigPath
    Caminho do config.toml do Codex. Default: ~/.codex/config.toml.
.EXAMPLE
    .\Resolve-CodexModelLocality.ps1 -Model gpt-5.5
.EXAMPLE
    .\Resolve-CodexModelLocality.ps1 -Model qwen2.5-coder:7b -Oss -LocalProvider ollama
.EXAMPLE
    .\Resolve-CodexModelLocality.ps1 -Model qwen2.5-coder:7b -Profile ollama-launch
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)] [string] $Model,
    [switch] $Oss,
    [ValidateSet('ollama', 'lmstudio')] [string] $LocalProvider,
    [string] $Profile,
    [string] $ConfigPath = (Join-Path $HOME '.codex' | Join-Path -ChildPath 'config.toml')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:modelId = $null
if (-not [string]::IsNullOrWhiteSpace($Model)) {
    $initialModelParts = @($Model -split '/')
    $script:modelId = $initialModelParts[$initialModelParts.Count - 1].Trim()
    if ([string]::IsNullOrWhiteSpace($script:modelId)) { $script:modelId = $null }
}

function Test-LoopbackHost {
    param([string]$HostName)
    if ([string]::IsNullOrWhiteSpace($HostName)) { return $false }
    $h = $HostName.Trim().Trim('[', ']')
    return ($h -ieq 'localhost' -or $h -eq '::1' -or $h -match '^127\.')
}

function Get-BaseUrlLocality {
    param([string]$BaseUrl)
    $uriHost = $null
    try { $uriHost = ([System.Uri]$BaseUrl).Host } catch { $uriHost = $null }
    if (Test-LoopbackHost $uriHost) { return 'local' }
    return 'external'
}

function New-LocalityResult {
    param([string]$Provider, [string]$BaseUrl, [string]$Locality, [string]$Reason)
    $canonical = if ($Provider -and $script:modelId) { "$Provider/$script:modelId" } elseif ($script:modelId) { $script:modelId } else { $null }
    [pscustomobject]@{
        model          = $Model
        modelId        = $script:modelId
        provider       = $Provider
        baseUrl        = $BaseUrl
        locality       = $Locality
        canonicalModel = $canonical
        reason         = $Reason
    } | ConvertTo-Json -Compress
}

# Mini-parser TOML focado: coleta apenas o que o resolvedor precisa.
#   - $topLevelModel    : 'model' antes da primeira secao [..]
#   - $topLevelProvider : 'model_provider' antes da primeira secao [..]
#   - $providerBaseUrl  : base_url por [model_providers.<id>]
#   - $profileModel     : model por [profiles.<id>]
#   - $profileProvider  : model_provider por [profiles.<id>]
function Read-CodexConfigSubset {
    param([string]$Path)
    $providerBaseUrl = @{}
    $profileModel = @{}
    $profileProvider = @{}
    $topLevelModel = $null
    $topLevelProvider = $null
    $section = ''   # '' = topo

    foreach ($rawLine in (Get-Content -LiteralPath $Path -Encoding utf8)) {
        $line = $rawLine.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }

        $secMatch = [regex]::Match($line, '^\[([^\]]+)\]')
        if ($secMatch.Success) { $section = $secMatch.Groups[1].Value.Trim(); continue }

        $kvMatch = [regex]::Match($line, '^([A-Za-z0-9_\-\.]+)\s*=\s*"([^"]*)"')
        if (-not $kvMatch.Success) { continue }
        $key = $kvMatch.Groups[1].Value
        $val = $kvMatch.Groups[2].Value

        if ($section -eq '') {
            if ($key -eq 'model') { $topLevelModel = $val }
            if ($key -eq 'model_provider') { $topLevelProvider = $val }
        }
        elseif ($section -like 'model_providers.*') {
            if ($key -eq 'base_url') {
                $id = $section.Substring('model_providers.'.Length)
                $providerBaseUrl[$id] = $val
            }
        }
        elseif ($section -like 'profiles.*') {
            if ($key -eq 'model') {
                $id = $section.Substring('profiles.'.Length)
                $profileModel[$id] = $val
            }
            if ($key -eq 'model_provider') {
                $id = $section.Substring('profiles.'.Length)
                $profileProvider[$id] = $val
            }
        }
    }

    [pscustomobject]@{
        topLevelModel    = $topLevelModel
        topLevelProvider = $topLevelProvider
        providerBaseUrl  = $providerBaseUrl
        profileModel     = $profileModel
        profileProvider  = $profileProvider
    }
}

# 1) Caminho LOCAL explicito por OSS: nao depende da config.
if ($Oss -or $LocalProvider) {
    $prov = if ($LocalProvider) { $LocalProvider } else { 'ollama' }
    $baseUrl = if ($prov -eq 'lmstudio') { 'http://localhost:1234/v1' } else { 'http://localhost:11434/v1' }
    New-LocalityResult -Provider $prov -BaseUrl $baseUrl -Locality 'local' `
        -Reason "invocacao OSS local ($prov, loopback); o dado nao sai da maquina"
    return
}

# 2) Config legivel? (necessaria para profile e provider de topo)
$configFound = Test-Path -LiteralPath $ConfigPath -PathType Leaf
$cfg = $null
if ($configFound) {
    try {
        $cfg = Read-CodexConfigSubset -Path $ConfigPath
    } catch {
        New-LocalityResult -Provider $null -BaseUrl $null -Locality 'unknown' `
            -Reason "falha ao ler/parsear o config.toml do Codex: $($_.Exception.Message)"
        return
    }
}

# Modelo efetivo: se -Model foi omitido, usar profile.model ou model de topo da config.
if ($script:modelId) {
    # -Model explicito vence a config.
}
elseif ($Profile -and $configFound -and $cfg.profileModel.ContainsKey($Profile)) {
    $script:modelId = [string]$cfg.profileModel[$Profile]
}
elseif ($configFound -and $cfg.topLevelModel) {
    $script:modelId = [string]$cfg.topLevelModel
}

if ([string]::IsNullOrWhiteSpace($script:modelId)) {
    $script:modelId = $null
}

# 3) Caminho por PROFILE: resolve provider -> base_url pela config.
if ($Profile) {
    if (-not $configFound) {
        New-LocalityResult -Provider $null -BaseUrl $null -Locality 'unknown' `
            -Reason "profile '$Profile' pedido, mas config.toml nao encontrada: $ConfigPath"
        return
    }
    if (-not $cfg.profileProvider.ContainsKey($Profile)) {
        New-LocalityResult -Provider $null -BaseUrl $null -Locality 'unknown' `
            -Reason "profile '$Profile' sem model_provider na config; nao resolvivel"
        return
    }
    $prov = $cfg.profileProvider[$Profile]
    if (-not $script:modelId) {
        New-LocalityResult -Provider $prov -BaseUrl $null -Locality 'unknown' `
            -Reason "profile '$Profile' sem model na config e -Model omitido; modelo de destino nao resolvivel"
        return
    }
    if (-not $cfg.providerBaseUrl.ContainsKey($prov)) {
        # Provider built-in (ex: openai) sem base_url na config -> externo.
        New-LocalityResult -Provider $prov -BaseUrl $null -Locality 'external' `
            -Reason "profile '$Profile' usa provider '$prov' built-in (sem base_url local); tratado como externo"
        return
    }
    $baseUrl = $cfg.providerBaseUrl[$prov]
    $locality = Get-BaseUrlLocality $baseUrl
    New-LocalityResult -Provider $prov -BaseUrl $baseUrl -Locality $locality `
        -Reason "profile '$Profile' -> provider '$prov' (base_url '$baseUrl')"
    return
}

# 4) Caminho DEFAULT: provider de topo da config, ou openai built-in.
$prov = if ($configFound -and $cfg.topLevelProvider) { $cfg.topLevelProvider } else { 'openai' }

if (-not $script:modelId) {
    New-LocalityResult -Provider $prov -BaseUrl $null -Locality 'unknown' `
        -Reason "modelo omitido e config sem model de topo; destino exato nao resolvivel"
    return
}

if (-not $configFound -or -not $cfg.providerBaseUrl.ContainsKey($prov)) {
    # openai (ou outro built-in) sem base_url local -> externo, por definicao.
    New-LocalityResult -Provider $prov -BaseUrl $null -Locality 'external' `
        -Reason "provider de destino '$prov' built-in/remoto (sem base_url local); o dado sai da maquina"
    return
}

$baseUrl = $cfg.providerBaseUrl[$prov]
$locality = Get-BaseUrlLocality $baseUrl
New-LocalityResult -Provider $prov -BaseUrl $baseUrl -Locality $locality `
    -Reason "provider de destino '$prov' (base_url '$baseUrl')"
