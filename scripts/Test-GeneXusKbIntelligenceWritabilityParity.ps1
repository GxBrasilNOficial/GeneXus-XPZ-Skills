#requires -Version 7.4
<#
.SYNOPSIS
    Exige paridade entre Test-GeneXusTransactionWritability.ps1 e consultas do índice materializado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CorpusFolder,

    [Parameter(Mandatory = $true)]
    [string]$IndexPath,

    [int]$MaxTransactions = 0,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$corpusFolder = (Resolve-Path -LiteralPath $CorpusFolder).Path
$indexPath = (Resolve-Path -LiteralPath $IndexPath).Path

if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw "IndexPath nao encontrado: $indexPath"
}

$writabilityScript = Join-Path $scriptDir 'Test-GeneXusTransactionWritability.ps1'
$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'

$txFolder = Join-Path $corpusFolder 'Transaction'
if (-not (Test-Path -LiteralPath $txFolder -PathType Container)) {
    throw "Pasta Transaction ausente em CorpusFolder: $txFolder"
}

$txFiles = @(Get-ChildItem -LiteralPath $txFolder -Filter '*.xml' -File | Sort-Object Name)
if ($MaxTransactions -gt 0) {
    $txFiles = @($txFiles | Select-Object -First $MaxTransactions)
}

$failures = [System.Collections.Generic.List[string]]::new()
$checked = 0

function Get-OccurrenceKey {
    param([Parameter(Mandatory = $true)]$Row)

    $identity = $Row.identity
    if ($null -eq $identity -or $null -eq $identity.transaction -or
        $null -eq $identity.level -or $null -eq $identity.attribute -or
        $null -eq $identity.level.pathOrdinals) {
        throw 'Ocorrência sem identidade completa no resultado de gravabilidade.'
    }
    $keyObject = [ordered]@{
        transaction = [ordered]@{
            type = [string]$identity.transaction.type
            guid = $identity.transaction.guid
            name = [string]$identity.transaction.name
            path = [string]$identity.transaction.path
            rootKind = $identity.transaction.rootKind
        }
        partType = [string]$identity.partType
        level = [ordered]@{
            guid = $identity.level.guid
            pathOrdinals = @($identity.level.pathOrdinals)
        }
        attribute = [ordered]@{
            type = [string]$identity.attribute.type
            guid = $identity.attribute.guid
            name = [string]$identity.attribute.name
            path = [string]$identity.attribute.path
            rootKind = $identity.attribute.rootKind
        }
    }
    $json = ConvertTo-Json -InputObject $keyObject -Depth 8 -Compress
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json))
}

foreach ($txFile in $txFiles) {
    $gateJson = & $writabilityScript -TransactionPath $txFile.FullName -CorpusFolder $corpusFolder -AsJson | ConvertFrom-Json
    if ($gateJson.status -ne 'pass') {
        $failures.Add("Gate status nao pass para $($txFile.Name): $($gateJson.status)")
        continue
    }
    $txName = [string]$gateJson.transactionName
    if ([string]::IsNullOrWhiteSpace($txName)) {
        $failures.Add("transactionName vazio para $($txFile.Name)")
        continue
    }

    $indexJsonText = & python $queryScript `
        --index-path $indexPath `
        --query transaction-attributes `
        --object-name $txName `
        --format json
    if ($LASTEXITCODE -ne 0) {
        $failures.Add("Query transaction-attributes falhou para $txName (exit $LASTEXITCODE)")
        continue
    }
    $indexJson = $indexJsonText | ConvertFrom-Json
    if (-not $indexJson.found) {
        $failures.Add("Indice nao encontrou Transaction $txName")
        continue
    }

    $indexMap = [System.Collections.Generic.Dictionary[string, object]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($row in @($indexJson.results)) {
        try {
            $key = Get-OccurrenceKey -Row $row
        } catch {
            $failures.Add("Indice sem identidade completa para ${txName}: $($_.Exception.Message)")
            continue
        }
        if ($indexMap.ContainsKey($key)) {
            $failures.Add("Indice duplicou a identidade de ocorrência em $txName")
            continue
        }
        $indexMap.Add($key, $row)
    }

    $gateKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($gateRow in @($gateJson.levelAttributes)) {
        $checked++
        try {
            $key = Get-OccurrenceKey -Row $gateRow
        } catch {
            $failures.Add("Gate sem identidade completa para ${txName}: $($_.Exception.Message)")
            continue
        }
        if (-not $gateKeys.Add($key)) {
            $failures.Add("Gate duplicou a identidade de ocorrência em $txName")
            continue
        }
        if (-not $indexMap.ContainsKey($key)) {
            $failures.Add("Indice sem ocorrência correspondente para $txName :: $($gateRow.attributeName)")
            continue
        }
        $indexRow = $indexMap[$key]
        if ([string]$indexRow.classification -ne [string]$gateRow.classification) {
            $failures.Add(
                "classification divergente em $txName [$($gateRow.attributeName)]: gate=$($gateRow.classification) index=$($indexRow.classification)"
            )
        }
        $gateWritable = $gateRow.writable
        $indexWritable = $indexRow.writable
        $gateIsNull = $null -eq $gateWritable
        $indexIsNull = $null -eq $indexWritable
        if ($gateIsNull -ne $indexIsNull) {
            $failures.Add(
                "writable nullability divergente em $txName [$($gateRow.attributeName)]: gate=$gateWritable index=$indexWritable"
            )
        } elseif (-not $gateIsNull -and [bool]$gateWritable -ne [bool]$indexWritable) {
            $failures.Add(
                "writable divergente em $txName [$($gateRow.attributeName)]: gate=$gateWritable index=$indexWritable"
            )
        }
        $gateCanAssign = $gateRow.canAssignInNew
        $indexCanAssign = $indexRow.canAssignInNew
        if (($null -eq $gateCanAssign) -ne ($null -eq $indexCanAssign) -or
            ($null -ne $gateCanAssign -and [bool]$gateCanAssign -ne [bool]$indexCanAssign)) {
            $failures.Add(
                "canAssignInNew divergente em $txName [$($gateRow.attributeName)]: gate=$gateCanAssign index=$indexCanAssign"
            )
        }
        if ([string]$gateRow.coverage -ne [string]$indexRow.coverage) {
            $failures.Add("coverage divergente em $txName [$($gateRow.attributeName)]")
        }
        if ([string]$gateJson.writabilityRuleVersion -ne [string]$indexRow.writabilityRuleVersion) {
            $failures.Add("writabilityRuleVersion divergente em $txName [$($gateRow.attributeName)]")
        }
        $gateReasons = ConvertTo-Json -InputObject @($gateRow.reasonCodes) -Depth 4 -Compress
        $indexReasons = ConvertTo-Json -InputObject @($indexRow.reasonCodes) -Depth 4 -Compress
        if ($gateReasons -cne $indexReasons) {
            $failures.Add("reasonCodes divergentes em $txName [$($gateRow.attributeName)]")
        }
    }
    if ($gateKeys.Count -ne $indexMap.Count) {
        $failures.Add("Contagem de ocorrências divergente em ${txName}: gate=$($gateKeys.Count) indice=$($indexMap.Count)")
    }
}

$report = [pscustomobject]@{
    status            = if ($failures.Count -eq 0) { 'pass' } else { 'fail' }
    corpusFolder      = $corpusFolder
    indexPath         = $indexPath
    transactions      = $txFiles.Count
    attributePairs    = $checked
    failureCount      = $failures.Count
    failures          = @($failures)
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $($report.status)"
    Write-Output "transactions: $($report.transactions)"
    Write-Output "attributePairs: $($report.attributePairs)"
    Write-Output "failureCount: $($report.failureCount)"
    foreach ($failure in $report.failures) {
        Write-Output "  $failure"
    }
}

if ($report.status -ne 'pass') {
    exit 2
}
exit 0
