#requires -Version 7.4
<#
.SYNOPSIS
    Avalia, de forma CONSULTIVA, se um conjunto de candidatos a revisor (com seus vereditos
    de gate) atinge o PISO DE DIVERSIDADE de uma revisao por pares (>=2 familias distintas).
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.

    Familia no piso = Criador do Modelo via Get-LlmDelegateTargetFamily(targetModelKey).
    family explicita no item e eco (nao governa allow/potential/dropped).
    So criadores em Test-LlmDelegateFamilyKnown contam; unknown vao a droppedUnknownFamilies.

    hasFallbackEvidence exige (attemptRole=fallback OU fallbackOf nao vazio) E
    (dispatchAttempted=true OU attempts>=1).

    Estados: panelReady | needsBatchAuthorization | insufficientDiversityAfterFallback |
    insufficientDiversity.

    Saida: objeto JSON de maquina no stdout (acrescenta droppedUnknownFamilies,
    unknownFamiliesPresent).
.PARAMETER CandidatesJson
    JSON (array) dos candidatos.
.PARAMETER Floor
    Piso de familias distintas. Default 2.
.PARAMETER AuthorFamily
    Criador do Modelo do autor do manuscrito (nao o nome da ferramenta).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $CandidatesJson,
    [int] $Floor = 2,
    [string] $AuthorFamily
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

function Get-Family {
    param([string]$TargetModelKey)
    return Get-LlmDelegateTargetFamily -TargetModelKey $TargetModelKey
}

$parsed = $null
try { $parsed = $CandidatesJson | ConvertFrom-Json } catch {
    throw "BLOCK: -CandidatesJson nao e JSON valido: $($_.Exception.Message)"
}
$items = @($parsed)

$allowFamilies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$askByNewFamily = [System.Collections.Generic.List[object]]::new()
$potentialFamilies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$dispatchable = [System.Collections.Generic.List[object]]::new()
$droppedUnknown = [System.Collections.Generic.List[object]]::new()
$droppedKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# Passagem 0: todos os itens (inclusive countsForDiversity=false) — unknown families
foreach ($it in $items) {
    $target = [string](Get-Prop $it 'targetModelKey')
    $fam = Get-Family $target
    $known = (Test-LlmDelegateFamilyKnown -Family $fam)
    if (-not $known -or [string]::IsNullOrWhiteSpace($fam)) {
        if (-not [string]::IsNullOrWhiteSpace($target) -and $droppedKeys.Add($target)) {
            $droppedUnknown.Add([pscustomobject]@{
                    targetModelKey = $target
                    resolvedFamily = $fam
                    backend        = [string](Get-Prop $it 'backend')
                })
        }
    }
}

# 1) Familias ja despachaveis (allow) — so known
foreach ($it in $items) {
    $countsRaw = Get-Prop $it 'countsForDiversity'
    if ($countsRaw -eq $false) { continue }
    $verdict = [string](Get-Prop $it 'verdict')
    $stateValue = [string](Get-Prop $it 'state')
    if ([string]::IsNullOrWhiteSpace($verdict) -and $stateValue -eq 'responded') { $verdict = 'allow' }
    $target = [string](Get-Prop $it 'targetModelKey')
    $fam = Get-Family $target
    if ([string]::IsNullOrWhiteSpace($fam)) { continue }
    if (-not (Test-LlmDelegateFamilyKnown -Family $fam)) { continue }
    if ($verdict -eq 'allow') {
        [void]$allowFamilies.Add($fam)
        [void]$potentialFamilies.Add($fam)
        $dispatchable.Add([pscustomobject]@{ targetModelKey = $target; family = $fam; backend = [string](Get-Prop $it 'backend') })
    }
}

# 2) `ask` que adicionam familia ainda nao coberta por `allow`
foreach ($it in $items) {
    $countsRaw = Get-Prop $it 'countsForDiversity'
    if ($countsRaw -eq $false) { continue }
    $verdict = [string](Get-Prop $it 'verdict')
    $stateValue = [string](Get-Prop $it 'state')
    if ([string]::IsNullOrWhiteSpace($verdict) -and $stateValue -eq 'responded') { $verdict = 'allow' }
    if ($verdict -ne 'ask') { continue }
    $target = [string](Get-Prop $it 'targetModelKey')
    $fam = Get-Family $target
    if ([string]::IsNullOrWhiteSpace($fam)) { continue }
    if (-not (Test-LlmDelegateFamilyKnown -Family $fam)) { continue }
    [void]$potentialFamilies.Add($fam)
    if (-not $allowFamilies.Contains($fam)) {
        $askByNewFamily.Add([pscustomobject]@{ targetModelKey = $target; family = $fam; backend = [string](Get-Prop $it 'backend') })
    }
}

$allowCount = $allowFamilies.Count
$potentialCount = $potentialFamilies.Count

$hasFallbackEvidence = @($items | Where-Object {
        $isFb = (-not [string]::IsNullOrWhiteSpace([string](Get-Prop $_ 'fallbackOf'))) -or ([string](Get-Prop $_ 'attemptRole') -eq 'fallback')
        if (-not $isFb) { return $false }
        $dispatched = ([bool](Get-Prop $_ 'dispatchAttempted') -eq $true)
        $attempts = 0
        try { $attempts = [int](Get-Prop $_ 'attempts') } catch { $attempts = 0 }
        return ($dispatched -or $attempts -ge 1)
    }).Count -gt 0

$state = if ($allowCount -ge $Floor) { 'panelReady' }
elseif ($potentialCount -ge $Floor) { 'needsBatchAuthorization' }
elseif ($hasFallbackEvidence) { 'insufficientDiversityAfterFallback' }
else { 'insufficientDiversity' }

$authorInPanel = $false
if (-not [string]::IsNullOrWhiteSpace($AuthorFamily)) {
    $authorInPanel = $allowFamilies.Contains($AuthorFamily.Trim())
}

$fallbackLabel = if ($state -ne 'panelReady') { "segunda opiniao ($($dispatchable.Count))" } else { $null }
$unknownPresent = $droppedUnknown.Count -gt 0

[pscustomobject]@{
    floor                     = $Floor
    panelReady                = ($state -eq 'panelReady')
    state                     = $state
    distinctFamiliesAllow     = @($allowFamilies)
    distinctFamiliesPotential = @($potentialFamilies)
    dispatchable              = @($dispatchable)
    askToAuthorize            = @($askByNewFamily)
    authorFamily              = $AuthorFamily
    authorFamilyInPanel       = $authorInPanel
    fallbackLabel             = $fallbackLabel
    droppedUnknownFamilies    = @($droppedUnknown)
    unknownFamiliesPresent    = $unknownPresent
    note                      = 'Consultivo; NAO e autorizacao. Familia = Criador do Modelo via Get-LlmDelegateTargetFamily(targetModelKey); so criadores em Test-LlmDelegateFamilyKnown contam no piso. family de entrada e eco. hasFallbackEvidence exige despacho efetivo no elo de cadeia.'
} | ConvertTo-Json -Depth 8
