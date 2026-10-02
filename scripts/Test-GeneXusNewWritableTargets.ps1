#requires -Version 7.4
[CmdletBinding()]
param(
    [string]$FrontFolder,

    [string]$ProcedurePath,

    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [string]$DecisionPath,

    [string]$RequestPath,

    [string]$FrontId,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($FrontFolder) -and [string]::IsNullOrWhiteSpace($ProcedurePath)) {
    throw 'Informe FrontFolder ou ProcedurePath.'
}
if (-not (Test-Path -LiteralPath $CorpusFolder -PathType Container)) {
    throw "CorpusFolder nao encontrado ou nao e diretorio: $CorpusFolder"
}
$CorpusFolder = (Resolve-Path -LiteralPath $CorpusFolder).Path

$arguments = [System.Collections.Generic.List[string]]::new()
$arguments.Add('--corpus-root')
$arguments.Add($CorpusFolder)
if (-not [string]::IsNullOrWhiteSpace($FrontFolder)) {
    if (-not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
        throw "FrontFolder nao encontrado ou nao e diretorio: $FrontFolder"
    }
    $FrontFolder = (Resolve-Path -LiteralPath $FrontFolder).Path
    $arguments.Add('--front-folder')
    $arguments.Add($FrontFolder)
    $arguments.Add('--delta-root')
    $arguments.Add($FrontFolder)
}
if (-not [string]::IsNullOrWhiteSpace($FrontId)) {
    $arguments.Add('--front-id')
    $arguments.Add($FrontId)
}
if (-not [string]::IsNullOrWhiteSpace($ProcedurePath)) {
    if (-not (Test-Path -LiteralPath $ProcedurePath -PathType Leaf)) {
        throw "ProcedurePath nao encontrado ou nao e arquivo: $ProcedurePath"
    }
    $ProcedurePath = (Resolve-Path -LiteralPath $ProcedurePath).Path
    $arguments.Add('--procedure-path')
    $arguments.Add($ProcedurePath)
}
if (-not [string]::IsNullOrWhiteSpace($DecisionPath)) {
    if (-not (Test-Path -LiteralPath $DecisionPath -PathType Leaf)) {
        throw "DecisionPath nao encontrado ou nao e arquivo: $DecisionPath"
    }
    $arguments.Add('--decision-path')
    $arguments.Add((Resolve-Path -LiteralPath $DecisionPath).Path)
}
if (-not [string]::IsNullOrWhiteSpace($RequestPath)) {
    $arguments.Add('--request-path')
    $arguments.Add([System.IO.Path]::GetFullPath($RequestPath))
}

. (Join-Path $PSScriptRoot 'GeneXusTransactionWritabilitySupport.ps1')
$result = Invoke-GeneXusWritabilityOperational -Arguments $arguments.ToArray()

if ($AsJson) {
    $result | ConvertTo-Json -Depth 100
    return
}

Write-Output "status: $($result.status)"
Write-Output "operationalStatus: $($result.operationalStatus)"
Write-Output "proceduresScanned: $($result.proceduresScanned)"
Write-Output "newBlocksScanned: $($result.newBlocksScanned)"
Write-Output "assignmentsScanned: $($result.assignmentsScanned)"
if (-not [string]::IsNullOrWhiteSpace([string]$result.decisionManifestError)) {
    Write-Output "decisionManifestError: $($result.decisionManifestError)"
}
foreach ($decision in @($result.decisionResults)) {
    $causes = @($decision.reasonCodes) -join ', '
    $decisionLine = "decision $($decision.decisionId): $($decision.status)"
    if ($causes) {
        $decisionLine += " ($causes)"
    }
    Write-Output $decisionLine
    if ($decision.status -eq 'applied') {
        Write-Output "  approvedBy=$($decision.actor); approvedAt=$($decision.approvedAt); receipt=$($decision.approvalReceipt.reference): $($decision.approvalReceipt.text)"
    }
}
foreach ($procedure in @($result.procedures)) {
    Write-Output "procedure: $($procedure.procedure.name) [$($procedure.procedure.guid)]"
    foreach ($block in @($procedure.newBlocks)) {
        $selectedTableGuid = $block.PSObject.Properties['selectedTableGuid']
        $selection = if ($null -ne $selectedTableGuid) { "; selectedTable=$($selectedTableGuid.Value)" } else { '' }
        Write-Output "  New #$($block.block.index): $($block.candidateState); coverage=$($block.coverage); decisionState=$($block.decisionState)$selection"
        foreach ($assignment in @($block.assignments)) {
            $identity = $assignment.assignment.attribute
            $name = if ($null -eq $identity) { $assignment.name } else { $identity.name }
            Write-Output "    assignment $name at [$($assignment.assignment.start),$($assignment.assignment.end)) identity=$($assignment.identityStatus)"
        }
        foreach ($candidate in @($block.candidates)) {
            Write-Output "    candidate Table: $($candidate.table.name) [$($candidate.table.guid)] selectable=$($candidate.selectable)"
            foreach ($target in @($candidate.assignmentTargets)) {
                foreach ($occurrence in @($target.occurrences)) {
                    $attributeName = $occurrence.occurrence.attribute.name
                    Write-Output "      $attributeName automatic=$($occurrence.writable) effective=$($occurrence.effectiveWritable) decisionState=$($occurrence.decisionState)"
                }
            }
        }
        foreach ($reason in @($block.reasonCodes)) {
            Write-Output "    reason: $reason"
        }
    }
}
