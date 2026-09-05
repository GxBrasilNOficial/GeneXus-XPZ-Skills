#requires -Version 7.4
<#
.SYNOPSIS
    Le a lista curada de revisores preferidos (schema 3) em cascata orchestrator->machine
    e a cruza com o manifesto de capacidade.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.
    INVARIANTE: preferencia != autorizacao. O gate Resolve-LlmDelegateAuthorization.ps1
    reavalia por revisor no envio.

    Cascata (sem -PreferredPath): preferred-reviewers.<orch>.json schema 3, senao machine
    preferred-reviewers.json schema 3. Ficheiro efetivo ilegivel/schema!=3 -> exit 2
    (nao cai no nivel seguinte). Desvio -PreferredPath: so esse ficheiro.

    -Orchestrator obrigatorio no corpo (cursor|claude-code|codex|opencode).
    stdout=JSON; stderr=diagnostico.
.PARAMETER Orchestrator
    cursor|claude-code|codex|opencode.
.PARAMETER PreferredRoot
    Default %LOCALAPPDATA%\xpz-llm-delegate (cascata).
.PARAMETER PreferredPath
    Desvio explicito sem default.
.PARAMETER CapabilitiesPath
    Default %LOCALAPPDATA%\xpz-llm-delegate\capabilities.json (nao derivado de PreferredRoot).
#>
[CmdletBinding()]
param(
    [string] $Orchestrator,
    [string] $PreferredRoot,
    [string] $PreferredPath,
    [string] $CapabilitiesPath = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate' | Join-Path -ChildPath 'capabilities.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'LlmDelegateTargetFamilySupport.ps1')

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and -not [string]::IsNullOrEmpty($Name) -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Write-ErrDiag {
    param([string]$Message)
    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        [Console]::Error.WriteLine($Message)
    }
}

function Emit-ResolveResult {
    param([hashtable]$Fields, [int]$ExitCode = 0)
    ([pscustomobject]$Fields) | ConvertTo-Json -Depth 12
    exit $ExitCode
}

function Stop-WithReason {
    param(
        [string]$Reason,
        [int]$ExitCode,
        [string]$Detail = '',
        [hashtable]$Extra = @{}
    )
    Write-ErrDiag $Detail
    $fields = @{
        hasPreferences         = $false
        reason                 = $Reason
        schemaVersion          = $null
        preferenceSource       = $null
        effectivePreferredPath = $null
        orchestrator           = $null
        calibratedBy           = $null
        fallbackPolicy         = $null
        diagnostics            = @()
        reviewers              = @()
        note                   = $script:Note
        updatedAt              = $null
        migratedFrom           = $null
    }
    foreach ($k in $Extra.Keys) { $fields[$k] = $Extra[$k] }
    Emit-ResolveResult -Fields $fields -ExitCode $ExitCode
}

$script:Note = 'Sugestao de composicao; NAO e autorizacao. O gate Resolve-LlmDelegateAuthorization.ps1 reavalia destino+sensibilidade POR REVISOR no envio. availableInManifest e best-effort: o manifesto pode nao enumerar opencode (config minima).'
$allowedOrchestrators = @('cursor', 'claude-code', 'codex', 'opencode')
$allowedDispatchBackends = @('opencode', 'codex', 'claude-code', 'copilot', 'gemini', 'antigravity')
$allowedNativeBackends = @('orchestrator-native')
$supportedFallbackActivateOn = @('quota', 'timeout', 'error', 'unavailable')
$legacyFallbackActivateOn = @('quota', 'timeout', 'error', 'unavailable', 'noResponse')

function Get-Family {
    param([string]$TargetModelKey)
    return Get-LlmDelegateTargetFamily -TargetModelKey $TargetModelKey
}

function Get-ManifestModelMap {
    param([string]$Path)
    $map = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $map }
    try {
        $cap = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
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

function Assert-ValidRankSet {
    param([object[]]$Reviewers)
    $seenRanks = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($reviewer in @($Reviewers)) {
        $rank = [int](Get-Prop $reviewer 'rank')
        if ($rank -lt 1) {
            Stop-WithReason -Reason 'rank-invalid' -ExitCode 3 -Detail "rank invalido ($rank)"
        }
        if (-not $seenRanks.Add($rank)) {
            Stop-WithReason -Reason 'rank-duplicate' -ExitCode 3 -Detail "rank duplicado ($rank)"
        }
    }
}

function ConvertTo-SupportedFallbackPolicy {
    param($Policy)
    if ($null -eq $Policy) { return $null }
    $mode = [string](Get-Prop $Policy 'mode')
    if ($mode -ne 'ordered-chain') {
        Stop-WithReason -Reason 'fallback-policy-invalid' -ExitCode 3 -Detail "fallbackPolicy.mode='$mode'"
    }
    $activateOn = @(Get-Prop $Policy 'defaultActivateOn' | ForEach-Object { [string]$_ })
    $legacyNoResponsePolicy = ($activateOn.Count -eq $legacyFallbackActivateOn.Count)
    if ($legacyNoResponsePolicy) {
        for ($i = 0; $i -lt $legacyFallbackActivateOn.Count; $i++) {
            if ($activateOn[$i] -ne $legacyFallbackActivateOn[$i]) { $legacyNoResponsePolicy = $false; break }
        }
    }
    if (-not $legacyNoResponsePolicy -and $activateOn.Count -ne $supportedFallbackActivateOn.Count) {
        Stop-WithReason -Reason 'fallback-policy-invalid' -ExitCode 3 -Detail 'defaultActivateOn fora do contrato'
    }
    if (-not $legacyNoResponsePolicy) {
        for ($i = 0; $i -lt $supportedFallbackActivateOn.Count; $i++) {
            if ($activateOn[$i] -ne $supportedFallbackActivateOn[$i]) {
                Stop-WithReason -Reason 'fallback-policy-invalid' -ExitCode 3 -Detail 'defaultActivateOn ordem invalida'
            }
        }
    }
    $gateAsk = [string](Get-Prop $Policy 'gateAskBehavior')
    if ($gateAsk -ne 'ask-human') {
        Stop-WithReason -Reason 'fallback-policy-invalid' -ExitCode 3 -Detail "gateAskBehavior='$gateAsk'"
    }
    $gateDeny = [string](Get-Prop $Policy 'gateDenyBehavior')
    if ($gateDeny -ne 'stop-or-suggest-manual-alternative') {
        Stop-WithReason -Reason 'fallback-policy-invalid' -ExitCode 3 -Detail "gateDenyBehavior='$gateDeny'"
    }
    return [pscustomobject]@{
        mode              = 'ordered-chain'
        defaultActivateOn = @($supportedFallbackActivateOn)
        gateAskBehavior   = 'ask-human'
        gateDenyBehavior  = 'stop-or-suggest-manual-alternative'
    }
}

function Assert-ReviewerValid {
    param($Reviewer, [string]$OwnerLabel)
    $backend = [string](Get-Prop $Reviewer 'backend')
    $target = [string](Get-Prop $Reviewer 'targetModelKey')
    $invokeArgs = Get-Prop $Reviewer 'invokeArgs'
    if ([string]::IsNullOrWhiteSpace($backend) -or [string]::IsNullOrWhiteSpace($target) -or $null -eq $invokeArgs) {
        Stop-WithReason -Reason 'reviewer-incomplete' -ExitCode 3 -Detail "$OwnerLabel incompleto"
    }
    $invBackend = [string](Get-Prop $invokeArgs 'backend')
    if (-not [string]::IsNullOrWhiteSpace($invBackend) -and $invBackend -ne $backend) {
        Stop-WithReason -Reason 'invoke-args-backend-divergent' -ExitCode 3 -Detail "$OwnerLabel invokeArgs.backend diverge"
    }
    if (Test-HardVetoTarget -TargetModelKey $target) {
        Stop-WithReason -Reason 'hard-veto' -ExitCode 3 -Detail "$OwnerLabel veto duro: $target"
    }
}

function ConvertTo-ResolvedReviewer {
    param($Reviewer, $ManifestMap, [int]$DefaultRank)
    Assert-ReviewerValid -Reviewer $Reviewer -OwnerLabel 'revisor preferido'
    $backend = [string](Get-Prop $Reviewer 'backend')
    $target = [string](Get-Prop $Reviewer 'targetModelKey')
    $isNative = ($allowedNativeBackends -contains $backend)
    $typeRaw = Get-Prop $Reviewer 'type'
    $type = if ($null -ne $typeRaw -and -not [string]::IsNullOrWhiteSpace([string]$typeRaw)) {
        [string]$typeRaw
    } elseif ($isNative) {
        'orchestrator-native-subagent'
    } else {
        'delegation-cli'
    }
    $rankValue = Get-Prop $Reviewer 'rank'
    $rank = if ($null -ne $rankValue) { [int]$rankValue } else { $DefaultRank }
    $effortRaw = Get-Prop $Reviewer 'reasoningEffort'
    $effort = if ($null -eq $effortRaw -or [string]::IsNullOrWhiteSpace([string]$effortRaw)) { 'unset' } else { [string]$effortRaw }
    $harnessRaw = Get-Prop $Reviewer 'harnessModelId'
    $harnessId = if ($isNative) {
        if ($null -eq $harnessRaw -or [string]::IsNullOrWhiteSpace([string]$harnessRaw)) {
            Stop-WithReason -Reason 'native-harness-model-id-missing' -ExitCode 3 -Detail 'harnessModelId ausente no nativo'
        }
        ([string]$harnessRaw).Trim()
    } else {
        $null
    }

    # Mesmo contrato do escritor (Set-): chave de harness Cursor so vale como titular nativo
    # com Criador conhecido. Arquivo editado a mao com ela sob backend CLI entregaria ao painel
    # um titular indespachavel, entao a leitura tambem recusa fail-closed.
    if (Test-LlmDelegateCursorHarnessKey -TargetModelKey $target) {
        $cursorFamily = Get-Family $target
        if (-not $isNative -or -not (Test-LlmDelegateFamilyKnown -Family $cursorFamily)) {
            Stop-WithReason -Reason 'native-cursor-prefix' -ExitCode 3 -Detail "targetModelKey='$target'"
        }
    }

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
    if ($isNative -and @($fallbackItems).Count -gt 0) {
        Stop-WithReason -Reason 'native-fallback-chain-forbidden' -ExitCode 3 -Detail 'nativo com fallbackChain'
    }
    foreach ($fb in @($fallbackItems)) {
        Assert-ReviewerValid -Reviewer $fb -OwnerLabel "fallbackChain[$fallbackIndex] de $target"
        $fbBackend = [string](Get-Prop $fb 'backend')
        $fbTarget = [string](Get-Prop $fb 'targetModelKey')
        if ($allowedNativeBackends -contains $fbBackend) {
            Stop-WithReason -Reason 'native-fallback-chain-forbidden' -ExitCode 3 -Detail "nativo como elo: $fbTarget"
        }
        # Elo de cadeia e sempre CLI: nenhuma grafia de harness Cursor e despachavel aqui.
        if (Test-LlmDelegateCursorHarnessKey -TargetModelKey $fbTarget) {
            Stop-WithReason -Reason 'native-cursor-prefix' -ExitCode 3 -Detail "fallback targetModelKey='$fbTarget'"
        }
        $key = "$fbBackend|$fbTarget"
        if (-not $seen.Add($key)) {
            Stop-WithReason -Reason 'fallback-cycle' -ExitCode 3 -Detail "ciclo envolvendo $fbTarget"
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
                type                = 'delegation-cli'
                harnessModelId      = $null
                reasoningEffort     = 'unset'
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
        type                = $type
        harnessModelId      = $harnessId
        reasoningEffort     = $effort
    }
}

function Get-DefaultPreferredRoot {
    return (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate')
}

function Read-PreferredDocument {
    param(
        [string]$Path,
        [string]$PreferenceSource,
        [string]$OrchestratorExpected,
        [bool]$RequireOrchestratorMatch,
        [System.Collections.Generic.List[string]]$Diagnostics
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $pref = $null
    try {
        $pref = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
        Stop-WithReason -Reason 'preferred-file-unreadable' -ExitCode 2 -Detail $_.Exception.Message -Extra @{
            preferenceSource       = $PreferenceSource
            effectivePreferredPath = [System.IO.Path]::GetFullPath($Path)
            diagnostics            = @($Diagnostics)
        }
    }
    $sv = Get-Prop $pref 'schemaVersion'
    if ($null -eq $sv -or [int]$sv -ne 3) {
        Stop-WithReason -Reason 'preferred-schema-unsupported' -ExitCode 2 -Detail "schemaVersion='$sv' em $Path; regrave com Set- schema 3" -Extra @{
            preferenceSource       = $PreferenceSource
            effectivePreferredPath = [System.IO.Path]::GetFullPath($Path)
            schemaVersion          = $sv
            diagnostics            = @($Diagnostics)
        }
    }
    $fileOrch = [string](Get-Prop $pref 'orchestrator')
    if ($RequireOrchestratorMatch) {
        if ([string]::IsNullOrWhiteSpace($fileOrch) -or -not $fileOrch.Equals($OrchestratorExpected, [System.StringComparison]::OrdinalIgnoreCase)) {
            Stop-WithReason -Reason 'orchestrator-mismatch' -ExitCode 2 -Detail "ficheiro orchestrator='$fileOrch' vs '$OrchestratorExpected'" -Extra @{
                preferenceSource       = $PreferenceSource
                effectivePreferredPath = [System.IO.Path]::GetFullPath($Path)
                schemaVersion          = 3
                orchestrator           = $fileOrch
                diagnostics            = @($Diagnostics)
            }
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($fileOrch)) {
        if (-not $fileOrch.Equals($OrchestratorExpected, [System.StringComparison]::OrdinalIgnoreCase)) {
            Stop-WithReason -Reason 'orchestrator-mismatch' -ExitCode 2 -Detail "campo orchestrator='$fileOrch' vs '$OrchestratorExpected'" -Extra @{
                preferenceSource       = $PreferenceSource
                effectivePreferredPath = [System.IO.Path]::GetFullPath($Path)
                schemaVersion          = 3
                orchestrator           = $fileOrch
                diagnostics            = @($Diagnostics)
            }
        }
    }
    return $pref
}

function Emit-ResolvedDocument {
    param(
        $Pref,
        [string]$PreferenceSource,
        [string]$EffectivePath,
        [string]$CapabilitiesPath,
        [System.Collections.Generic.List[string]]$Diagnostics
    )
    $fallbackPolicy = ConvertTo-SupportedFallbackPolicy -Policy (Get-Prop $Pref 'fallbackPolicy')
    $manifestMap = Get-ManifestModelMap -Path $CapabilitiesPath
    $reviewers = @(Get-Prop $Pref 'reviewers')
    $out = [System.Collections.Generic.List[object]]::new()
    $rankCounter = 0
    foreach ($r in $reviewers) {
        $rankCounter++
        $out.Add((ConvertTo-ResolvedReviewer -Reviewer $r -ManifestMap $manifestMap -DefaultRank $rankCounter))
    }
    $outSorted = @($out | Sort-Object -Property @{ Expression = { [int](Get-Prop $_ 'rank') } }, @{ Expression = { [string](Get-Prop $_ 'targetModelKey') } })
    Assert-ValidRankSet -Reviewers $outSorted

    $updatedAtRaw = Get-Prop $Pref 'updatedAt'
    $updatedAtOut = if ($updatedAtRaw -is [datetime]) {
        $updatedAtRaw.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    } else {
        [string]$updatedAtRaw
    }

    Emit-ResolveResult -ExitCode 0 -Fields @{
        hasPreferences         = $true
        reason                 = $null
        schemaVersion          = 3
        preferenceSource       = $PreferenceSource
        effectivePreferredPath = [System.IO.Path]::GetFullPath($EffectivePath)
        orchestrator           = Get-Prop $Pref 'orchestrator'
        calibratedBy           = Get-Prop $Pref 'calibratedBy'
        fallbackPolicy         = $fallbackPolicy
        diagnostics            = @($Diagnostics)
        reviewers              = @($outSorted)
        note                   = $script:Note
        updatedAt              = $updatedAtOut
        migratedFrom           = Get-Prop $Pref 'migratedFrom'
    }
}

# --- params ---
$orchTrim = if ($null -eq $Orchestrator) { '' } else { $Orchestrator.Trim() }
if ([string]::IsNullOrWhiteSpace($orchTrim)) {
    Stop-WithReason -Reason 'orchestrator-required' -ExitCode 1
}
if ($allowedOrchestrators -notcontains $orchTrim) {
    Stop-WithReason -Reason 'orchestrator-invalid' -ExitCode 1 -Detail "orchestrator='$orchTrim'"
}

$hasPreferredPath = $PSBoundParameters.ContainsKey('PreferredPath') -and -not [string]::IsNullOrWhiteSpace($PreferredPath)
$hasPreferredRoot = $PSBoundParameters.ContainsKey('PreferredRoot')
if ($hasPreferredPath -and $hasPreferredRoot) {
    Stop-WithReason -Reason 'preferred-path-mode-conflict' -ExitCode 1
}

$diagnostics = [System.Collections.Generic.List[string]]::new()

if ($hasPreferredPath) {
    $fullPath = [System.IO.Path]::GetFullPath($PreferredPath)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        Emit-ResolveResult -ExitCode 0 -Fields @{
            hasPreferences         = $false
            reason                 = 'no-preferred-file'
            schemaVersion          = $null
            preferenceSource       = 'explicit-path'
            effectivePreferredPath = $fullPath
            orchestrator           = $null
            calibratedBy           = $null
            fallbackPolicy         = $null
            diagnostics            = @()
            reviewers              = @()
            note                   = $script:Note
            updatedAt              = $null
            migratedFrom           = $null
        }
    }
    $pref = Read-PreferredDocument -Path $fullPath -PreferenceSource 'explicit-path' `
        -OrchestratorExpected $orchTrim -RequireOrchestratorMatch:$false -Diagnostics $diagnostics
    Emit-ResolvedDocument -Pref $pref -PreferenceSource 'explicit-path' -EffectivePath $fullPath `
        -CapabilitiesPath $CapabilitiesPath -Diagnostics $diagnostics
}

$root = if ($hasPreferredRoot -and -not [string]::IsNullOrWhiteSpace($PreferredRoot)) {
    [System.IO.Path]::GetFullPath($PreferredRoot)
} else {
    Get-DefaultPreferredRoot
}

$orchPath = [System.IO.Path]::GetFullPath((Join-Path $root "preferred-reviewers.$orchTrim.json"))
$machinePath = [System.IO.Path]::GetFullPath((Join-Path $root 'preferred-reviewers.json'))

if (Test-Path -LiteralPath $orchPath -PathType Leaf) {
    $pref = Read-PreferredDocument -Path $orchPath -PreferenceSource 'orchestrator' `
        -OrchestratorExpected $orchTrim -RequireOrchestratorMatch:$true -Diagnostics $diagnostics
    Emit-ResolvedDocument -Pref $pref -PreferenceSource 'orchestrator' -EffectivePath $orchPath `
        -CapabilitiesPath $CapabilitiesPath -Diagnostics $diagnostics
}

$diagnostics.Add('orchestrator-file-absent')

if (Test-Path -LiteralPath $machinePath -PathType Leaf) {
    $pref = Read-PreferredDocument -Path $machinePath -PreferenceSource 'machine' `
        -OrchestratorExpected $orchTrim -RequireOrchestratorMatch:$false -Diagnostics $diagnostics
    Emit-ResolvedDocument -Pref $pref -PreferenceSource 'machine' -EffectivePath $machinePath `
        -CapabilitiesPath $CapabilitiesPath -Diagnostics $diagnostics
}

Emit-ResolveResult -ExitCode 0 -Fields @{
    hasPreferences         = $false
    reason                 = 'no-preferred-file'
    schemaVersion          = $null
    preferenceSource       = 'none'
    effectivePreferredPath = $null
    orchestrator           = $null
    calibratedBy           = $null
    fallbackPolicy         = $null
    diagnostics            = @($diagnostics)
    reviewers              = @()
    note                   = $script:Note
    updatedAt              = $null
    migratedFrom           = $null
}
