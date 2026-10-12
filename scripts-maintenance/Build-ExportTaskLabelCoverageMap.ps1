#requires -Version 7.4

<#
.SYNOPSIS
    Mapa de cobertura exportTaskLabel: tipo do catálogo x instância por KB paralela.
#>

param(
    [string]$CatalogPath,

    [string]$OutputPath = (Join-Path $PSScriptRoot '..\historico\export-task-label-matrix-20260530\coverage-map.json'),

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusExportTaskLabelSupport.ps1'
. $supportPath

if (-not [string]::IsNullOrWhiteSpace($CatalogPath)) {
    $catalogTypes = @(Get-ExportTaskLabelCatalogTypes -CatalogPath $CatalogPath)
} else {
    $catalogTypes = @(Get-ExportTaskLabelCatalogTypes)
}

$kbEntries = @(Get-ExportTaskLabelKbRegistry)
$typeResults = [System.Collections.Generic.List[object]]::new()

foreach ($typeEntry in $catalogTypes) {
    $perKb = [System.Collections.Generic.List[object]]::new()
    $chosen = $null

    foreach ($kb in ($kbEntries | Sort-Object priority)) {
        $indexPath = Join-Path $kb.parallelKbRoot 'KbIntelligence\kb-intelligence.sqlite'
        if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
            continue
        }

        $listResult = $null
        $specimenName = $null
        $total = 0
        try {
            $listResult = Invoke-KbIntelligenceListByTypeFirst -IndexPath $indexPath -ObjectType $typeEntry.catalogTypeName -Limit 1
            $total = if ($null -ne $listResult.total) { [int]$listResult.total } else { 0 }
            if ($null -ne $listResult.results -and @($listResult.results).Count -gt 0) {
                $specimenName = [string]$listResult.results[0].name
            }
        } catch {
            $perKb.Add([ordered]@{
                kbId        = $kb.id
                parallelKbRoot = $kb.parallelKbRoot
                kbPath      = $kb.kbPath
                total       = 0
                specimenName = $null
                queryError  = $_.Exception.Message
            }) | Out-Null
            continue
        }

        $perKb.Add([ordered]@{
            kbId           = $kb.id
            parallelKbRoot = $kb.parallelKbRoot
            kbPath         = $kb.kbPath
            total          = $total
            specimenName   = $specimenName
            queryError     = $null
        }) | Out-Null

        if ($null -eq $chosen -and $total -gt 0 -and -not [string]::IsNullOrWhiteSpace($specimenName)) {
            $chosen = [ordered]@{
                kbId           = $kb.id
                parallelKbRoot = $kb.parallelKbRoot
                kbPath         = $kb.kbPath
                specimenName   = $specimenName
                priority       = $kb.priority
                referenceKb    = [bool]$kb.referenceKb
            }
        }
    }

    $typeResults.Add([ordered]@{
        catalogTypeName = $typeEntry.catalogTypeName
        folderName      = $typeEntry.folderName
        objectTypeGuid  = $typeEntry.objectTypeGuid
        exportTaskLabel = $typeEntry.exportTaskLabel
        chosenSpecimen  = $chosen
        perKb           = @($perKb)
        testable        = ($null -ne $chosen)
    }) | Out-Null
}

$outDir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$result = [ordered]@{
    generatedAt   = (Get-Date).ToString('o')
    catalogTypeCount = $catalogTypes.Count
    testableCount = @($typeResults | Where-Object { $_.testable }).Count
    kbRegistry    = @($kbEntries | ForEach-Object {
        [ordered]@{
            id             = $_.id
            parallelKbRoot = $_.parallelKbRoot
            kbPath         = $_.kbPath
            priority       = $_.priority
            referenceKb    = [bool]$_.referenceKb
        }
    })
    types         = @($typeResults)
}

$json = $result | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))

if ($AsJson) {
    $json
} else {
    Write-Output "EXPORT_TASK_LABEL_COVERAGE_OK: $OutputPath (testable=$($result.testableCount)/$($result.catalogTypeCount))"
}

exit 0
