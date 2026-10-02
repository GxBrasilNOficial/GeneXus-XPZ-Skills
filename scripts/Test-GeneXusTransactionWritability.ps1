#requires -Version 7.4
<#
.SYNOPSIS
    Gate de gravabilidade por Transaction (fachada do nucleo canonico Python).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TransactionPath,

    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [string]$DeltaRoot,

    [string]$DecisionPath,

    [string]$RequestPath,

    [string]$FrontId,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'GeneXusTransactionWritabilitySupport.ps1')

if (-not (Test-Path -LiteralPath $TransactionPath -PathType Leaf)) {
    throw "TransactionPath nao encontrado ou nao e arquivo: $TransactionPath"
}
if (-not (Test-Path -LiteralPath $CorpusFolder -PathType Container)) {
    throw "CorpusFolder nao encontrado ou nao e diretorio: $CorpusFolder"
}
if (-not [string]::IsNullOrWhiteSpace($DeltaRoot) -and
    -not (Test-Path -LiteralPath $DeltaRoot -PathType Container)) {
    throw "DeltaRoot nao encontrado ou nao e diretorio: $DeltaRoot"
}

$TransactionPath = (Resolve-Path -LiteralPath $TransactionPath).Path
$CorpusFolder = (Resolve-Path -LiteralPath $CorpusFolder).Path
$catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "Catalogo de tipos nao encontrado: $catalogPath"
}

if (-not [string]::IsNullOrWhiteSpace($DecisionPath) -and
    -not (Test-Path -LiteralPath $DecisionPath -PathType Leaf)) {
    throw "DecisionPath nao encontrado ou nao e arquivo: $DecisionPath"
}
if (-not [string]::IsNullOrWhiteSpace($RequestPath)) {
    $RequestPath = [System.IO.Path]::GetFullPath($RequestPath)
    $requestParent = Split-Path -Parent $RequestPath
    if (-not (Test-Path -LiteralPath $requestParent -PathType Container)) {
        throw "A pasta pai de RequestPath nao existe: $requestParent"
    }
}

$arguments = @(
    '--transaction-path', $TransactionPath,
    '--corpus-root', $CorpusFolder
)
if (-not [string]::IsNullOrWhiteSpace($DeltaRoot)) {
    $arguments += @('--delta-root', (Resolve-Path -LiteralPath $DeltaRoot).Path)
}
if (-not [string]::IsNullOrWhiteSpace($DecisionPath)) {
    $arguments += @('--decision-path', (Resolve-Path -LiteralPath $DecisionPath).Path)
}
if (-not [string]::IsNullOrWhiteSpace($RequestPath)) {
    $arguments += @('--request-path', [System.IO.Path]::GetFullPath($RequestPath))
}
if (-not [string]::IsNullOrWhiteSpace($FrontId)) {
    $arguments += @('--front-id', $FrontId)
}
$result = Invoke-GeneXusWritabilityOperational -Arguments $arguments

if ($AsJson) {
    $result | ConvertTo-Json -Depth 30
} else {
    Write-Output "status: $($result.status)"
    Write-Output "operationalStatus: $($result.operationalStatus)"
    Write-Output "transactionName: $($result.transactionName)"
    Write-Output "coverage: $($result.coverage)"
    $levelAttributes = @($result.levelAttributes)
    Write-Output "levelAttributes: $($levelAttributes.Count)"
    foreach ($a in $levelAttributes) {
        $w = if ($null -eq $a.writable) { 'null' } else { $a.writable }
        $effective = if ($null -eq $a.effectiveWritable) { 'null' } else { $a.effectiveWritable }
        Write-Output "  [$($a.levelName)] $($a.attributeName) key=$($a.key) -> $($a.classification) (automatic=$w effective=$effective decision=$($a.decisionState))"
        foreach ($receipt in @($a.decisionReceipts)) {
            Write-Output "    receipt: decision=$($receipt.decisionId) actor=$($receipt.actor) approvedAt=$($receipt.approvedAt) reference=$($receipt.approvalReceipt.reference)"
        }
    }
}
