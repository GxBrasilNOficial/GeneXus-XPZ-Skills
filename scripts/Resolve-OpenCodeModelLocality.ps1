#requires -Version 7.4

<#
.SYNOPSIS
    Classifica, de forma deterministica, se um modelo do opencode roda LOCAL (na maquina)
    ou EXTERNO (sai da maquina), lendo a config do opencode.
.DESCRIPTION
    Backend opencode da skill xpz-llm-delegate. Le ~/.config/opencode/opencode.json (ou
    -ConfigPath), resolve o provider do modelo informado e classifica pela baseURL:

        - loopback (127.x / localhost / ::1)  -> local
        - baseURL externa explicita           -> external
        - provider sem baseURL na config       -> external (custom sem endpoint local)
        - provider ausente da config           -> external (gateway embutido/remoto por definicao)
        - provider cloud conhecido              -> external (mesmo sem config legivel)
        - modelo não parseavel ou config ausente -> unknown

    A única forma de um modelo ser LOCAL e seu provider apontar para uma baseURL loopback.
    Na ausencia disso o trafego sai da maquina. O gate de confidencialidade
    (Resolve-LlmDelegateAuthorization.ps1) trata 'external' e 'unknown' como exigindo
    autorizacao para payload sensivel.

    Saida: objeto JSON de maquina no stdout.
.PARAMETER Model
    Modelo no formato provider/modelo (ex: ollama/qwen2.5-coder).
.PARAMETER ConfigPath
    Caminho do opencode.json. Default: ~/.config/opencode/opencode.json.
.EXAMPLE
    .\Resolve-OpenCodeModelLocality.ps1 -Model ollama/qwen2.5-coder:7b_8192ctx
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $Model,
    [string] $ConfigPath = (Join-Path $HOME '.config' | Join-Path -ChildPath 'opencode' | Join-Path -ChildPath 'opencode.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Test-LoopbackHost {
    param([string]$HostName)
    if ([string]::IsNullOrWhiteSpace($HostName)) { return $false }
    $h = $HostName.Trim().Trim('[', ']')
    return ($h -ieq 'localhost' -or $h -eq '::1' -or $h -match '^127\.')
}

function Test-KnownExternalProvider {
    param([string]$Provider)
    return @('ollama-cloud', 'opencode-go') -contains $Provider
}

function New-LocalityResult {
    param([string]$Provider, [string]$BaseUrl, [string]$Locality, [string]$Reason)
    [pscustomobject]@{
        model    = $Model
        provider = $Provider
        baseUrl  = $BaseUrl
        locality = $Locality
        reason   = $Reason
    } | ConvertTo-Json -Compress
}

# 1) Parse provider/modelo
$parts = @($Model -split '/', 2)
if ($parts.Count -lt 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
    New-LocalityResult -Provider $null -BaseUrl $null -Locality 'unknown' `
        -Reason "modelo nao esta no formato provider/modelo: '$Model'"
    return
}
$provider = $parts[0].Trim()

# 2) Config legivel?
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    if (Test-KnownExternalProvider $provider) {
        New-LocalityResult -Provider $provider -BaseUrl $null -Locality 'external' `
            -Reason "provider cloud conhecido ('$provider'); tratado como externo mesmo sem config legivel"
        return
    }
    New-LocalityResult -Provider $provider -BaseUrl $null -Locality 'unknown' `
        -Reason "config do opencode nao encontrada: $ConfigPath"
    return
}

try {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
} catch {
    if (Test-KnownExternalProvider $provider) {
        New-LocalityResult -Provider $provider -BaseUrl $null -Locality 'external' `
            -Reason "provider cloud conhecido ('$provider'); tratado como externo apesar de falha ao ler/parsear a config: $($_.Exception.Message)"
        return
    }
    New-LocalityResult -Provider $provider -BaseUrl $null -Locality 'unknown' `
        -Reason "falha ao ler/parsear a config do opencode: $($_.Exception.Message)"
    return
}

# 3) Provider declarado na config?
$providers = Get-Prop $config 'provider'
$providerNode = Get-Prop $providers $provider
if ($null -eq $providerNode) {
    New-LocalityResult -Provider $provider -BaseUrl $null -Locality 'external' `
        -Reason 'provider ausente da config (gateway embutido/remoto por definicao ou nome invalido); tratado como externo'
    return
}

# 4) baseURL do provider
$options = Get-Prop $providerNode 'options'
$baseUrl = Get-Prop $options 'baseURL'
if ([string]::IsNullOrWhiteSpace($baseUrl)) {
    New-LocalityResult -Provider $provider -BaseUrl $null -Locality 'external' `
        -Reason 'provider declarado sem baseURL local; tratado como externo'
    return
}

# 5) Classifica pela baseURL
$uriHost = $null
try { $uriHost = ([System.Uri]$baseUrl).Host } catch { $uriHost = $null }

if (Test-LoopbackHost $uriHost) {
    New-LocalityResult -Provider $provider -BaseUrl $baseUrl -Locality 'local' `
        -Reason "baseURL loopback ($uriHost); o dado nao sai da maquina"
} else {
    New-LocalityResult -Provider $provider -BaseUrl $baseUrl -Locality 'external' `
        -Reason "baseURL externa (host '$uriHost'); o dado sai da maquina"
}
