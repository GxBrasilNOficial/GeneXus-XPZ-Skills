#requires -Version 7.4
<#
.SYNOPSIS
    Le a lista curada de revisores preferidos e a cruza com o manifesto de capacidade,
    devolvendo a composicao SUGERIDA do painel de revisao por pares.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.

    INVARIANTE (preferencia != autorizacao): este resolvedor NAO emite veredito de
    autorizacao e NAO consome capabilities.json como verdade do gate. A autorizacao
    continua sendo do Resolve-LlmDelegateAuthorization.ps1, chamado POR REVISOR no momento
    do envio (reavalia destino+sensibilidade). Aqui so se sugere "o que voce prefere que
    esta disponivel".

    Cruza:
      - preferencia (preferred-reviewers.json) — o que o usuario curou
      - disponivel (capabilities.json) — best-effort: o manifesto pode NAO enumerar opencode
        (config minima), entao availableInManifest=false ali nao prova indisponibilidade.

    Compatibilidade:
      - ausencia de schemaVersion = v1;
      - schema v1 plano continua aceito;
      - schema v2 aceita rank e fallbackChain[];
      - invokeArgs.backend, quando presente, deve coincidir com backend no primario e em
        cada fallback; divergencia bloqueia antes do dispatcher.

    A regra de PAPEL do README (forte vs voz adicional; veto duro) e aplicada pelo agente
    /pela metodologia do 15 ao montar o painel — nao por este script (papel "forte/fraco"
    nao e dado de maquina). O veto duro ja foi descartado na gravacao (Set-...).

    Sem o arquivo de preferencia -> hasPreferences=false (a oferta cai no comportamento
    atual: catalogo + politica do README).

    Saida: objeto JSON de maquina no stdout.
.PARAMETER PreferredPath
    Caminho do preferred-reviewers.json. Default: %LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json.
.PARAMETER CapabilitiesPath
    Caminho do capabilities.json. Default: %LOCALAPPDATA%\xpz-llm-delegate\capabilities.json.
.EXAMPLE
    .\Resolve-LlmDelegatePreferredReviewers.ps1
#>
[CmdletBinding()]
param(
    [string] $PreferredPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'preferred-reviewers.json'),
    [string] $CapabilitiesPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'capabilities.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) { return $Obj.PSObject.Properties[$Name].Value }
    return $null
}

function Get-Family {
    param([string]$TargetModelKey)
    if ([string]::IsNullOrWhiteSpace($TargetModelKey) -or $TargetModelKey -notmatch '/') { return $null }
    return @($TargetModelKey -split '/', 2)[0]
}

function Get-ManifestModelMap {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $map }
    try {
        $cap = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        foreach ($b in @(Get-Prop $cap 'backends')) {
            foreach ($m in @(Get-Prop $b 'models')) {
                $cm = [string](Get-Prop $m 'canonicalModel')
                if (-not [string]::IsNullOrWhiteSpace($cm)) { $map[$cm] = $m }
            }
        }
    } catch { }
    return $map
}

function Test-HardVetoTarget {
    param([string]$TargetModelKey)
    if ([string]::IsNullOrWhiteSpace($TargetModelKey)) { return $false }
    $modelPart = @($TargetModelKey -split '/')[-1].ToLowerInvariant()
    foreach ($v in @('mistral-large-3', 'nemotron-3-ultra')) {
        if ($modelPart.Contains($v)) { return $true }
    }
    return $false
}

$supportedFallbackActivateOn = @('quota', 'timeout', 'error', 'unavailable', 'noResponse')

function Assert-ValidRankSet {
    param([object[]]$Reviewers)
    $seenRanks = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($reviewer in @($Reviewers)) {
        $rank = [int](Get-Prop $reviewer 'rank')
        if ($rank -lt 1) { throw "BLOCK: rank invalido ($rank); use inteiros positivos a partir de 1" }
        if (-not $seenRanks.Add($rank)) { throw "BLOCK: rank duplicado ($rank) em preferred-reviewers.json" }
    }
}

function Assert-SupportedFallbackPolicy {
    param($Policy)
    if ($null -eq $Policy) { return }
    $mode = [string](Get-Prop $Policy 'mode')
    if ($mode -ne 'ordered-chain') { throw "BLOCK: fallbackPolicy.mode suportado e somente 'ordered-chain'; veio '$mode'" }
    $activateOn = @(Get-Prop $Policy 'defaultActivateOn' | ForEach-Object { [string]$_ })
    if ($activateOn.Count -ne $supportedFallbackActivateOn.Count) {
        throw "BLOCK: fallbackPolicy.defaultActivateOn deve casar o contrato suportado: $($supportedFallbackActivateOn -join ', ')"
    }
    for ($i = 0; $i -lt $supportedFallbackActivateOn.Count; $i++) {
        if ($activateOn[$i] -ne $supportedFallbackActivateOn[$i]) {
            throw "BLOCK: fallbackPolicy.defaultActivateOn deve preservar a ordem suportada: $($supportedFallbackActivateOn -join ', ')"
        }
    }
    $gateAsk = [string](Get-Prop $Policy 'gateAskBehavior')
    if ($gateAsk -ne 'ask-human') { throw "BLOCK: fallbackPolicy.gateAskBehavior suportado e somente 'ask-human'; veio '$gateAsk'" }
    $gateDeny = [string](Get-Prop $Policy 'gateDenyBehavior')
    if ($gateDeny -ne 'stop-or-suggest-manual-alternative') {
        throw "BLOCK: fallbackPolicy.gateDenyBehavior suportado e somente 'stop-or-suggest-manual-alternative'; veio '$gateDeny'"
    }
}

function Assert-ReviewerValid {
    param($Reviewer, [string]$OwnerLabel)
    $backend = [string](Get-Prop $Reviewer 'backend')
    $target = [string](Get-Prop $Reviewer 'targetModelKey')
    $invokeArgs = Get-Prop $Reviewer 'invokeArgs'
    if ([string]::IsNullOrWhiteSpace($backend) -or [string]::IsNullOrWhiteSpace($target) -or $null -eq $invokeArgs) {
        throw "BLOCK: $OwnerLabel sem backend, targetModelKey ou invokeArgs completo"
    }
    $invBackend = [string](Get-Prop $invokeArgs 'backend')
    if (-not [string]::IsNullOrWhiteSpace($invBackend) -and $invBackend -ne $backend) {
        throw "BLOCK: $OwnerLabel tem invokeArgs.backend ('$invBackend') divergente de backend ('$backend')"
    }
    if (Test-HardVetoTarget -TargetModelKey $target) {
        throw "BLOCK: $OwnerLabel usa modelo sob veto duro: $target"
    }
}

function ConvertTo-ResolvedReviewer {
    param($Reviewer, $ManifestMap, [int]$DefaultRank)
    Assert-ReviewerValid -Reviewer $Reviewer -OwnerLabel 'revisor preferido'
    $backend = [string](Get-Prop $Reviewer 'backend')
    $target = [string](Get-Prop $Reviewer 'targetModelKey')
    $rankValue = Get-Prop $Reviewer 'rank'
    $rank = if ($null -ne $rankValue) { [int]$rankValue } else { $DefaultRank }
    $manifestEntry = $ManifestMap[$target]
    $available = ($null -ne $manifestEntry)
    $diagnostics = [System.Collections.Generic.List[string]]::new()
    if (-not $available) { $diagnostics.Add('availableInManifest=false; diagnostico, nao bloqueio do gate') }
    elseif ((Get-Prop $manifestEntry 'sourceConfidence') -eq 'weak') { $diagnostics.Add('capability sourceConfidence=weak') }

    $chainOut = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    [void]$seen.Add("$backend|$target")
    $fallbackIndex = 0
    $fallbackItems = Get-Prop $Reviewer 'fallbackChain'
    if ($null -eq $fallbackItems) { $fallbackItems = @() }
    foreach ($fb in @($fallbackItems)) {
        Assert-ReviewerValid -Reviewer $fb -OwnerLabel "fallbackChain[$fallbackIndex] de $target"
        $fbBackend = [string](Get-Prop $fb 'backend')
        $fbTarget = [string](Get-Prop $fb 'targetModelKey')
        $key = "$fbBackend|$fbTarget"
        if (-not $seen.Add($key)) {
            throw "BLOCK: ciclo/duplicidade em fallbackChain de $target envolvendo $fbTarget"
        }
        $fbManifest = $ManifestMap[$fbTarget]
        $fbAvailable = ($null -ne $fbManifest)
        $fbDiagnostics = [System.Collections.Generic.List[string]]::new()
        if (-not $fbAvailable) { $fbDiagnostics.Add('availableInManifest=false; diagnostico, nao bloqueio do gate') }
        elseif ((Get-Prop $fbManifest 'sourceConfidence') -eq 'weak') { $fbDiagnostics.Add('capability sourceConfidence=weak') }
        $chainOut.Add([pscustomobject]@{
                backend             = $fbBackend
                targetModelKey      = $fbTarget
                invokeArgs          = (Get-Prop $fb 'invokeArgs')
                family              = Get-Family $fbTarget
                rank                = $rank
                fallbackIndex       = $fallbackIndex
                fallbackOf          = $target
                reason              = [string](Get-Prop $fb 'reason')
                availableInManifest = $fbAvailable
                capability          = $fbManifest
                diagnostics         = @($fbDiagnostics)
            })
        $fallbackIndex++
    }

    [pscustomobject]@{
        backend             = $backend
        targetModelKey      = $target
        invokeArgs          = (Get-Prop $Reviewer 'invokeArgs')
        family              = Get-Family $target
        rank                = $rank
        fallbackChain       = @($chainOut)
        availableInManifest = $available
        capability          = $manifestEntry
        diagnostics         = @($diagnostics)
    }
}

$note = 'Sugestao de composicao; NAO e autorizacao. O gate Resolve-LlmDelegateAuthorization.ps1 reavalia destino+sensibilidade POR REVISOR no envio. availableInManifest e best-effort: o manifesto pode nao enumerar opencode (config minima).'

if (-not (Test-Path -LiteralPath $PreferredPath -PathType Leaf)) {
    [pscustomobject]@{
        hasPreferences = $false
        reason         = 'no-preferred-file'
        reviewers      = @()
        note           = $note
    } | ConvertTo-Json -Depth 8
    return
}

$pref = $null
try { $pref = Get-Content -LiteralPath $PreferredPath -Raw | ConvertFrom-Json } catch {
    [pscustomobject]@{
        hasPreferences = $false
        reason         = "preferred-file-unreadable: $($_.Exception.Message)"
        reviewers      = @()
        note           = $note
    } | ConvertTo-Json -Depth 8
    return
}

$schemaVersion = Get-Prop $pref 'schemaVersion'
if ($null -eq $schemaVersion) { $schemaVersion = 1 }
$reviewers = @(Get-Prop $pref 'reviewers')
$fallbackPolicy = Get-Prop $pref 'fallbackPolicy'
Assert-SupportedFallbackPolicy -Policy $fallbackPolicy
$manifestMap = Get-ManifestModelMap -Path $CapabilitiesPath

$out = [System.Collections.Generic.List[object]]::new()
$rankCounter = 0
foreach ($r in $reviewers) {
    $rankCounter++
    $out.Add((ConvertTo-ResolvedReviewer -Reviewer $r -ManifestMap $manifestMap -DefaultRank $rankCounter))
}
$outSorted = @($out | Sort-Object -Property @{ Expression = { [int](Get-Prop $_ 'rank') } }, @{ Expression = { [string](Get-Prop $_ 'targetModelKey') } })
Assert-ValidRankSet -Reviewers $outSorted

[pscustomobject]@{
    hasPreferences = $true
    schemaVersion  = [int]$schemaVersion
    updatedAt      = [string](Get-Prop $pref 'updatedAt')
    fallbackPolicy = $fallbackPolicy
    reviewers      = @($outSorted)
    note           = $note
} | ConvertTo-Json -Depth 12
