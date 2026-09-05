#requires -Version 7.4
<#
.SYNOPSIS
    Grava a lista CURADA de revisores preferidos (schema 3), por escopo machine ou orchestrator.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.
    Preferencia != autorizacao. Schema 3: delegation-cli (6 backends CLI) e
    orchestrator-native-subagent (backend orchestrator-native). Cascata de path via
    -PreferredRoot/-Orchestrator/-Scope, ou desvio -OutputPath (mutuamente exclusivo).
    -Orchestrator/-Scope/-ReviewersJson obrigatorios no corpo. stdout=JSON; stderr=diagnostico.
.PARAMETER ReviewersJson
    Array de titulares OU { reviewers, schemaVersion?, fallbackPolicy? }.
.PARAMETER Orchestrator
    cursor|claude-code|codex|opencode.
.PARAMETER Scope
    machine|orchestrator.
.PARAMETER PreferredRoot
    Default %LOCALAPPDATA%\xpz-llm-delegate (cascata).
.PARAMETER OutputPath
    Desvio explicito sem default.
.PARAMETER Preview
    Valida e emite sem gravar.
.PARAMETER Overwrite
    Grava sobre destino schema 3 valido.
#>
[CmdletBinding()]
param(
    [string] $ReviewersJson,
    [string] $Orchestrator,
    [string] $Scope,
    [string] $PreferredRoot,
    [string] $OutputPath,
    [switch] $Preview,
    [switch] $Overwrite
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

function Emit-SetResult {
    param([hashtable]$Fields, [int]$ExitCode = 0)
    ([pscustomobject]$Fields) | ConvertTo-Json -Depth 12 -Compress
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
        written                = 0
        discardedVeto          = @()
        reason                 = $Reason
        effectivePreferredPath = $null
        outputPath             = $null
        preview                = [bool]$Preview
        document               = $null
    }
    foreach ($k in $Extra.Keys) { $fields[$k] = $Extra[$k] }
    Emit-SetResult -Fields $fields -ExitCode $ExitCode
}

$hardVetoPatterns = @('mistral-large-3', 'nemotron-3-ultra')
$allowedDispatchBackends = @('opencode', 'codex', 'claude-code', 'copilot', 'gemini', 'antigravity')
$allowedNativeBackends = @('orchestrator-native')
$allowedOrchestrators = @('cursor', 'claude-code', 'codex', 'opencode')
$allowedScopes = @('machine', 'orchestrator')
$allowedInvokeArgs = @('backend', 'model', 'profile', 'localProvider', 'oss', 'timeoutSec')
$allowedReasoningEffort = @('unset', 'low', 'medium', 'high', 'xhigh')
$allowedTitularProps = @('type', 'backend', 'targetModelKey', 'harnessModelId', 'reasoningEffort', 'rank', 'invokeArgs', 'fallbackChain', 'model')
$allowedFallbackProps = @('backend', 'targetModelKey', 'invokeArgs', 'reason')
$allowedWrapperProps = @('reviewers', 'schemaVersion', 'fallbackPolicy')
$supportedFallbackActivateOn = @('quota', 'timeout', 'error', 'unavailable')
$legacyFallbackActivateOn = @('quota', 'timeout', 'error', 'unavailable', 'noResponse')

function Test-HardVetoTarget {
    param([string]$TargetModelKey)
    if ([string]::IsNullOrWhiteSpace($TargetModelKey)) { return $false }
    $modelPart = @($TargetModelKey -split '/')[-1]
    foreach ($v in $hardVetoPatterns) {
        if ($modelPart.ToLowerInvariant().Contains($v)) { return $true }
    }
    return $false
}

# Chave de harness Cursor nas duas grafias: 'cursor/<modelo>' (com barra) e 'cursor-<modelo>'
# (slug sem barra, ex. cursor-grok-*, cursor-composer-*). Esses modelos so existem dentro do
# Cursor: nenhum backend CLI da lista despacha para eles.
function Test-CursorHarnessKey {
    param([string]$TargetModelKey)
    if ([string]::IsNullOrWhiteSpace($TargetModelKey)) { return $false }
    $t = $TargetModelKey.Trim()
    if ($t -notmatch '/') { return $t.StartsWith('cursor-', [System.StringComparison]::OrdinalIgnoreCase) }
    $first = @($t -split '/')[0]
    return $first.Equals('cursor', [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-KnownProperties {
    param($Obj, [string[]]$Allowed, [string]$Context)
    if ($null -eq $Obj) { return }
    foreach ($p in @($Obj.PSObject.Properties)) {
        if ($Allowed -notcontains $p.Name) {
            Stop-WithReason -Reason 'unknown-property' -ExitCode 3 -Detail "$Context propriedade extra: $($p.Name)"
        }
    }
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
    if ($null -eq $Policy) {
        return [pscustomobject]@{
            mode              = 'ordered-chain'
            defaultActivateOn = @($supportedFallbackActivateOn)
            gateAskBehavior   = 'ask-human'
            gateDenyBehavior  = 'stop-or-suggest-manual-alternative'
        }
    }
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
        Stop-WithReason -Reason 'fallback-policy-invalid' -ExitCode 3 -Detail 'fallbackPolicy.defaultActivateOn fora do contrato'
    }
    if (-not $legacyNoResponsePolicy) {
        for ($i = 0; $i -lt $supportedFallbackActivateOn.Count; $i++) {
            if ($activateOn[$i] -ne $supportedFallbackActivateOn[$i]) {
                Stop-WithReason -Reason 'fallback-policy-invalid' -ExitCode 3 -Detail 'fallbackPolicy.defaultActivateOn ordem invalida'
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

function Copy-SanitizedInvokeArgs {
    param($InvokeArgs, [string]$Backend, [string]$TargetModelKey)
    $invClean = [ordered]@{}
    $invBackend = [string](Get-Prop $InvokeArgs 'backend')
    if (-not [string]::IsNullOrWhiteSpace($invBackend) -and $invBackend -ne $Backend) {
        Stop-WithReason -Reason 'invoke-args-backend-divergent' -ExitCode 3 -Detail "invokeArgs.backend='$invBackend' vs backend='$Backend'"
    }
    $invClean['backend'] = $Backend
    foreach ($f in $allowedInvokeArgs) {
        if ($f -eq 'backend') { continue }
        $val = Get-Prop $InvokeArgs $f
        if ($null -eq $val) { continue }
        if ($f -eq 'oss') {
            if ($val -is [bool] -and $val) { $invClean[$f] = $true }
            continue
        }
        if ($f -eq 'timeoutSec') {
            $invClean[$f] = [int]$val
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$val)) { $invClean[$f] = [string]$val }
    }
    if (-not $invClean.Contains('model')) {
        $modelPart = @($TargetModelKey -split '/')[-1]
        $invClean['model'] = if ($Backend -eq 'opencode') { $TargetModelKey } else { $modelPart }
    }
    return [pscustomobject]$invClean
}

function Resolve-TitularType {
    param([string]$Backend, $TypeRaw)
    $isNative = $allowedNativeBackends -contains $Backend
    $isCli = $allowedDispatchBackends -contains $Backend
    if (-not $isNative -and -not $isCli) {
        Stop-WithReason -Reason 'backend-not-allowed' -ExitCode 3 -Detail "backend='$Backend'"
    }
    $inferred = if ($isNative) { 'orchestrator-native-subagent' } else { 'delegation-cli' }
    if ($null -eq $TypeRaw -or [string]::IsNullOrWhiteSpace([string]$TypeRaw)) {
        return $inferred
    }
    $t = [string]$TypeRaw
    if ($t -ne 'delegation-cli' -and $t -ne 'orchestrator-native-subagent') {
        Stop-WithReason -Reason 'unknown-property' -ExitCode 3 -Detail "type='$t'"
    }
    if (($t -eq 'delegation-cli' -and -not $isCli) -or ($t -eq 'orchestrator-native-subagent' -and -not $isNative)) {
        Stop-WithReason -Reason 'type-backend-divergent' -ExitCode 3 -Detail "type='$t' backend='$Backend'"
    }
    return $t
}

function ConvertTo-ReviewerV3 {
    param($Item, [int]$DefaultRank)
    Assert-KnownProperties -Obj $Item -Allowed $allowedTitularProps -Context 'titular'

    $backend = [string](Get-Prop $Item 'backend')
    $target = [string](Get-Prop $Item 'targetModelKey')
    $modelAlias = [string](Get-Prop $Item 'model')
    if ([string]::IsNullOrWhiteSpace($target) -and -not [string]::IsNullOrWhiteSpace($modelAlias)) {
        $target = $modelAlias
    }
    elseif (-not [string]::IsNullOrWhiteSpace($target) -and -not [string]::IsNullOrWhiteSpace($modelAlias)) {
        if (-not $target.Equals($modelAlias, [System.StringComparison]::OrdinalIgnoreCase)) {
            Stop-WithReason -Reason 'target-model-key-divergent' -ExitCode 3 -Detail "model='$modelAlias' targetModelKey='$target'"
        }
    }

    $invokeArgs = Get-Prop $Item 'invokeArgs'
    if ([string]::IsNullOrWhiteSpace($backend) -or [string]::IsNullOrWhiteSpace($target) -or $null -eq $invokeArgs) {
        Stop-WithReason -Reason 'reviewer-incomplete' -ExitCode 3 -Detail 'backend/targetModelKey/invokeArgs obrigatorios'
    }

    $type = Resolve-TitularType -Backend $backend -TypeRaw (Get-Prop $Item 'type')
    $isNative = ($type -eq 'orchestrator-native-subagent')

    # Chave de harness Cursor e legitima APENAS como titular nativo e com Criador conhecido
    # (cursor/grok-* e cursor-grok-* -> xai; cursor/composer-* e cursor-composer-* -> anysphere).
    # Como alvo CLI seria titular indespachavel; com Criador desconhecido nao contaria no piso.
    if (Test-CursorHarnessKey -TargetModelKey $target) {
        $cursorFamily = Get-LlmDelegateTargetFamily -TargetModelKey $target
        if (-not $isNative -or -not (Test-LlmDelegateFamilyKnown -Family $cursorFamily)) {
            Stop-WithReason -Reason 'native-cursor-prefix' -ExitCode 3 -Detail "targetModelKey='$target'"
        }
    }
    if (Test-HardVetoTarget -TargetModelKey $target) {
        Stop-WithReason -Reason 'hard-veto' -ExitCode 3 -Detail "veto duro: $target"
    }

    $effortRaw = Get-Prop $Item 'reasoningEffort'
    $effort = if ($null -eq $effortRaw -or [string]::IsNullOrWhiteSpace([string]$effortRaw)) { 'unset' } else { [string]$effortRaw }
    if ($allowedReasoningEffort -notcontains $effort) {
        Stop-WithReason -Reason 'unknown-property' -ExitCode 3 -Detail "reasoningEffort='$effort'"
    }

    $rankValue = Get-Prop $Item 'rank'
    $rank = if ($null -ne $rankValue) { [int]$rankValue } else { $DefaultRank }
    $harnessRaw = Get-Prop $Item 'harnessModelId'
    $chainOut = [System.Collections.Generic.List[object]]::new()

    if ($isNative) {
        if ($null -eq $harnessRaw -or [string]::IsNullOrWhiteSpace([string]$harnessRaw)) {
            Stop-WithReason -Reason 'native-harness-model-id-missing' -ExitCode 3 -Detail 'harnessModelId obrigatorio no nativo'
        }
        $harnessId = ([string]$harnessRaw).Trim()
        foreach ($p in @($invokeArgs.PSObject.Properties)) {
            Stop-WithReason -Reason 'unknown-property' -ExitCode 3 -Detail "nativo nao aceita invokeArgs.$($p.Name)"
        }
        $invClean = [pscustomobject]@{}
        $fallbackItems = Get-Prop $Item 'fallbackChain'
        if ($null -ne $fallbackItems -and @($fallbackItems).Count -gt 0) {
            Stop-WithReason -Reason 'native-fallback-chain-forbidden' -ExitCode 3 -Detail 'nativo nao pode ter fallbackChain'
        }
        return [pscustomobject]@{
            type            = $type
            backend         = $backend
            targetModelKey  = $target
            harnessModelId  = $harnessId
            reasoningEffort = $effort
            rank            = $rank
            invokeArgs      = $invClean
        }
    }

    if ($null -ne $harnessRaw) {
        Stop-WithReason -Reason 'unknown-property' -ExitCode 3 -Detail 'harnessModelId proibido em CLI'
    }
    $invClean = Copy-SanitizedInvokeArgs -InvokeArgs $invokeArgs -Backend $backend -TargetModelKey $target
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    [void]$seen.Add("$backend|$target")
    $fallbackItems = Get-Prop $Item 'fallbackChain'
    if ($null -eq $fallbackItems) { $fallbackItems = @() }
    foreach ($fb in @($fallbackItems)) {
        Assert-KnownProperties -Obj $fb -Allowed $allowedFallbackProps -Context 'fallbackChain'
        $fbBackend = [string](Get-Prop $fb 'backend')
        $fbTarget = [string](Get-Prop $fb 'targetModelKey')
        $fbInv = Get-Prop $fb 'invokeArgs'
        if ([string]::IsNullOrWhiteSpace($fbBackend) -or [string]::IsNullOrWhiteSpace($fbTarget) -or $null -eq $fbInv) {
            Stop-WithReason -Reason 'reviewer-incomplete' -ExitCode 3 -Detail 'fallbackChain item incompleto'
        }
        if ($allowedNativeBackends -contains $fbBackend) {
            Stop-WithReason -Reason 'native-fallback-chain-forbidden' -ExitCode 3 -Detail "nativo como elo: $fbTarget"
        }
        if ($allowedDispatchBackends -notcontains $fbBackend) {
            Stop-WithReason -Reason 'backend-not-allowed' -ExitCode 3 -Detail "fallback backend='$fbBackend'"
        }
        # Elo de cadeia e sempre CLI: nenhuma grafia de harness Cursor e despachavel aqui.
        if (Test-CursorHarnessKey -TargetModelKey $fbTarget) {
            Stop-WithReason -Reason 'native-cursor-prefix' -ExitCode 3 -Detail "fallback targetModelKey='$fbTarget'"
        }
        if (Test-HardVetoTarget -TargetModelKey $fbTarget) {
            Stop-WithReason -Reason 'hard-veto' -ExitCode 3 -Detail "fallback veto: $fbTarget"
        }
        $key = "$fbBackend|$fbTarget"
        if (-not $seen.Add($key)) {
            Stop-WithReason -Reason 'fallback-cycle' -ExitCode 3 -Detail "ciclo envolvendo $fbTarget"
        }
        $fbInvClean = Copy-SanitizedInvokeArgs -InvokeArgs $fbInv -Backend $fbBackend -TargetModelKey $fbTarget
        $chainOut.Add([pscustomobject]@{
                backend        = $fbBackend
                targetModelKey = $fbTarget
                invokeArgs     = $fbInvClean
                reason         = [string](Get-Prop $fb 'reason')
            })
    }

    return [pscustomobject]@{
        type            = $type
        backend         = $backend
        targetModelKey  = $target
        reasoningEffort = $effort
        rank            = $rank
        invokeArgs      = $invClean
        fallbackChain   = @($chainOut)
    }
}

function Test-PersistedSchema3Valid {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        $doc = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json
        $sv = Get-Prop $doc 'schemaVersion'
        return ($null -ne $sv -and [int]$sv -eq 3)
    } catch {
        return $false
    }
}

function Get-DefaultPreferredRoot {
    return (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate')
}

# --- params (exit 1) ---
$orchTrim = if ($null -eq $Orchestrator) { '' } else { $Orchestrator.Trim() }
if ([string]::IsNullOrWhiteSpace($orchTrim)) {
    Stop-WithReason -Reason 'orchestrator-required' -ExitCode 1
}
if ($allowedOrchestrators -notcontains $orchTrim) {
    Stop-WithReason -Reason 'orchestrator-invalid' -ExitCode 1 -Detail "orchestrator='$orchTrim'"
}

$scopeTrim = if ($null -eq $Scope) { '' } else { $Scope.Trim() }
if ([string]::IsNullOrWhiteSpace($scopeTrim)) {
    Stop-WithReason -Reason 'scope-required' -ExitCode 1
}
if ($allowedScopes -notcontains $scopeTrim) {
    Stop-WithReason -Reason 'scope-invalid' -ExitCode 1 -Detail "scope='$scopeTrim'"
}

if ([string]::IsNullOrWhiteSpace($ReviewersJson)) {
    Stop-WithReason -Reason 'reviewers-json-required' -ExitCode 1
}

$hasOutputPath = $PSBoundParameters.ContainsKey('OutputPath') -and -not [string]::IsNullOrWhiteSpace($OutputPath)
$hasPreferredRoot = $PSBoundParameters.ContainsKey('PreferredRoot')
if ($hasOutputPath -and $hasPreferredRoot) {
    Stop-WithReason -Reason 'preferred-path-mode-conflict' -ExitCode 1
}

$root = if ($hasPreferredRoot -and -not [string]::IsNullOrWhiteSpace($PreferredRoot)) {
    [System.IO.Path]::GetFullPath($PreferredRoot)
} else {
    Get-DefaultPreferredRoot
}

if ($hasOutputPath) {
    $effectivePath = [System.IO.Path]::GetFullPath($OutputPath)
} else {
    $fileName = if ($scopeTrim -eq 'orchestrator') {
        "preferred-reviewers.$orchTrim.json"
    } else {
        'preferred-reviewers.json'
    }
    $effectivePath = [System.IO.Path]::GetFullPath((Join-Path $root $fileName))
}

if (-not $Preview -and -not $Overwrite -and (Test-PersistedSchema3Valid -Path $effectivePath)) {
    Stop-WithReason -Reason 'overwrite-required' -ExitCode 1 -Detail "destino schema 3: $effectivePath" -Extra @{
        effectivePreferredPath = $effectivePath
        schemaVersion          = 3
        outputPath             = $effectivePath
    }
}

$parsed = $null
try { $parsed = $ReviewersJson | ConvertFrom-Json } catch {
    Write-ErrDiag $_.Exception.Message
    Stop-WithReason -Reason 'reviewers-json-required' -ExitCode 1 -Extra @{ outputPath = $effectivePath }
}

$items = @()
$inputSchema = $null
$fallbackPolicyIn = $null

if ($parsed -is [System.Array]) {
    $items = @($parsed)
} else {
    Assert-KnownProperties -Obj $parsed -Allowed $allowedWrapperProps -Context 'wrapper'
    $itemsNode = Get-Prop $parsed 'reviewers'
    if ($null -eq $itemsNode) {
        Stop-WithReason -Reason 'reviewer-incomplete' -ExitCode 3 -Detail 'wrapper sem reviewers'
    }
    $items = @($itemsNode)
    $inputSchema = Get-Prop $parsed 'schemaVersion'
    $fallbackPolicyIn = Get-Prop $parsed 'fallbackPolicy'
}

$kept = [System.Collections.Generic.List[object]]::new()
$explicitRanks = [System.Collections.Generic.HashSet[int]]::new()
$implicitRanks = [System.Collections.Generic.HashSet[int]]::new()
$nextImplicitRank = 1

foreach ($it in $items) {
    $backendForRank = [string](Get-Prop $it 'backend')
    $targetForRank = [string](Get-Prop $it 'targetModelKey')
    if ([string]::IsNullOrWhiteSpace($targetForRank)) {
        $targetForRank = [string](Get-Prop $it 'model')
    }
    $rankValueForReservation = Get-Prop $it 'rank'
    $backendOk = ($allowedDispatchBackends -contains $backendForRank) -or ($allowedNativeBackends -contains $backendForRank)
    if ($null -ne $rankValueForReservation -and
        -not [string]::IsNullOrWhiteSpace($backendForRank) -and
        -not [string]::IsNullOrWhiteSpace($targetForRank) -and
        $backendOk -and
        -not (Test-HardVetoTarget -TargetModelKey $targetForRank)) {
        [void]$explicitRanks.Add([int]$rankValueForReservation)
    }
}
foreach ($explicitRank in $explicitRanks) {
    if ($explicitRank -ge $nextImplicitRank) { $nextImplicitRank = $explicitRank + 1 }
}

foreach ($it in $items) {
    $defaultRank = 0
    if ($null -eq (Get-Prop $it 'rank')) {
        while ($explicitRanks.Contains($nextImplicitRank) -or $implicitRanks.Contains($nextImplicitRank)) {
            $nextImplicitRank++
        }
        $defaultRank = $nextImplicitRank
        [void]$implicitRanks.Add($defaultRank)
        $nextImplicitRank++
    }
    $converted = ConvertTo-ReviewerV3 -Item $it -DefaultRank $defaultRank
    $kept.Add($converted)
}

$keptSorted = @($kept | Sort-Object -Property @{ Expression = { [int](Get-Prop $_ 'rank') } }, @{ Expression = { [string](Get-Prop $_ 'targetModelKey') } })
Assert-ValidRankSet -Reviewers $keptSorted
$fallbackPolicy = ConvertTo-SupportedFallbackPolicy -Policy $fallbackPolicyIn

$migratedFrom = $null
if ($null -ne $inputSchema) {
    $svIn = [int]$inputSchema
    if ($svIn -in @(1, 2)) { $migratedFrom = $svIn }
} else {
    # array nu (sem schemaVersion no wrapper) -> migratedFrom 1 (compat entrada legado)
    $migratedFrom = 1
}

$docOrdered = [ordered]@{
    schemaVersion = 3
    updatedAt     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
if ($null -ne $migratedFrom) { $docOrdered['migratedFrom'] = $migratedFrom }
if ($scopeTrim -eq 'orchestrator') {
    $docOrdered['orchestrator'] = $orchTrim
} else {
    $docOrdered['calibratedBy'] = $orchTrim
}
$docOrdered['fallbackPolicy'] = $fallbackPolicy
$docOrdered['reviewers'] = @($keptSorted)
$doc = [pscustomobject]$docOrdered
$docJson = $doc | ConvertTo-Json -Depth 12

if (-not $Preview) {
    $outDir = Split-Path -Parent $effectivePath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $effectivePath -PathType Leaf) {
        $backupPath = "$effectivePath.bak-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))"
        Copy-Item -LiteralPath $effectivePath -Destination $backupPath -Force
    }
    $tmpPath = "$effectivePath.tmp-$([guid]::NewGuid().ToString('N'))"
    try {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tmpPath, $docJson, $utf8NoBom)
        Move-Item -LiteralPath $tmpPath -Destination $effectivePath -Force
    } catch {
        if (Test-Path -LiteralPath $tmpPath -PathType Leaf) {
            Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

Emit-SetResult -ExitCode 0 -Fields @{
    written                = $kept.Count
    discardedVeto          = @()
    reason                 = $null
    effectivePreferredPath = $effectivePath
    schemaVersion          = 3
    outputPath             = $effectivePath
    preview                = [bool]$Preview
    document               = if ($Preview) { $doc } else { $null }
}
