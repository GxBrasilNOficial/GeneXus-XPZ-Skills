#requires -Version 7.4

<#
.SYNOPSIS
    Consolida resultados da campanha exportTaskLabel no catálogo e gera relatório para 10a.
#>

param(
    [string]$MatrixRoot = (Join-Path $PSScriptRoot '..\historico\export-task-label-matrix-20260530\matrix'),

    [string]$CoverageMapPath = (Join-Path $PSScriptRoot '..\historico\export-task-label-matrix-20260530\coverage-map.json'),

    [string]$CatalogPath = (Join-Path (Join-Path (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path 'scripts') 'gx-object-type-catalog.json'),

    [string]$ReportPath = (Join-Path $PSScriptRoot '..\historico\export-task-label-matrix-20260530\consolidation-report.json'),

    [switch]$ApplyCatalog,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusExportTaskLabelSupport.ps1'
. $supportPath

function Get-MatrixWinnerForType {
    param($Summary)

    $cleanRuns = @($Summary.runs | Where-Object { $_.cleanSuccess })
    if ($cleanRuns.Count -eq 0) {
        return [pscustomobject]@{
            verdict            = 'inconclusive'
            exportTaskLabel    = $null
            catalogMatchesTask = $false
            cleanRun           = $null
            note               = 'Nenhum candidato com export limpo (exit 0, sem Categoria B, objeto no XPZ).'
        }
    }

    $catalogName = [string]$Summary.catalogTypeName
    $catalogClean = @($cleanRuns | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.candidateTypeLabel) -and
            $_.candidateTypeLabel.Equals($catalogName, [System.StringComparison]::OrdinalIgnoreCase)
        })

    if ($catalogClean.Count -gt 0) {
        return [pscustomobject]@{
            verdict            = 'catalogMatchesTask'
            exportTaskLabel    = $null
            catalogMatchesTask = $true
            cleanRun           = $catalogClean[0]
            note               = 'Rótulo da task Export coincide com o nome do catálogo.'
        }
    }

    $alternate = @($cleanRuns | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.candidateTypeLabel) -and
            -not $_.candidateTypeLabel.Equals($catalogName, [System.StringComparison]::OrdinalIgnoreCase)
        })

    if ($alternate.Count -eq 1) {
        return [pscustomobject]@{
            verdict            = 'divergence'
            exportTaskLabel    = [string]$alternate[0].candidateTypeLabel
            catalogMatchesTask = $false
            cleanRun           = $alternate[0]
            note               = 'Task Export aceita rótulo diferente do catálogo.'
        }
    }

    if ($alternate.Count -gt 1) {
        $labels = @($alternate | ForEach-Object { $_.candidateTypeLabel } | Select-Object -Unique)
        return [pscustomobject]@{
            verdict            = 'ambiguous'
            exportTaskLabel    = $null
            catalogMatchesTask = $false
            cleanRun           = $alternate[0]
            note               = ('Múltiplos rótulos limpos: {0}' -f ($labels -join ', '))
        }
    }

    $nameOnly = @($cleanRuns | Where-Object { [string]::IsNullOrWhiteSpace($_.candidateTypeLabel) })
    if ($nameOnly.Count -gt 0) {
        return [pscustomobject]@{
            verdict            = 'nameOnlyWorks'
            exportTaskLabel    = $null
            catalogMatchesTask = $false
            cleanRun           = $nameOnly[0]
            note               = 'Export limpo apenas com nome sem prefixo Tipo: (formato degradado).'
        }
    }

    return [pscustomobject]@{
        verdict            = 'inconclusive'
        exportTaskLabel    = $null
        catalogMatchesTask = $false
        cleanRun           = $cleanRuns[0]
        note               = 'Candidatos limpos sem rótulo de tipo identificável.'
    }
}

$catalogTypes = @(Get-ExportTaskLabelCatalogTypes -CatalogPath $CatalogPath)
$notTestable = @()
if (Test-Path -LiteralPath $CoverageMapPath -PathType Leaf) {
    $coverage = Get-Content -LiteralPath $CoverageMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $notTestable = @($coverage.types | Where-Object { -not $_.testable })
}

$perType = [System.Collections.Generic.List[object]]::new()
$summaryFiles = @(Get-ChildItem -LiteralPath $MatrixRoot -Recurse -Filter 'matrix-summary.json' -File -ErrorAction SilentlyContinue)

foreach ($file in $summaryFiles) {
    $summary = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $winner = Get-MatrixWinnerForType -Summary $summary
    $inventoryTypes = @()
    $winningObjectList = $null
    if ($null -ne $winner.cleanRun) {
        if ($null -ne $winner.cleanRun.PSObject.Properties['inventoryTypes']) {
            $inventoryTypes = @($winner.cleanRun.inventoryTypes)
        }
        if ($null -ne $winner.cleanRun.PSObject.Properties['objectList']) {
            $winningObjectList = $winner.cleanRun.objectList
        }
    }
    [void]$perType.Add([ordered]@{
        catalogTypeName    = $summary.catalogTypeName
        kbId               = $summary.kbId
        specimenObjectName = $summary.specimenObjectName
        matrixSummaryPath  = $file.FullName
        verdict            = $winner.verdict
        exportTaskLabel    = $winner.exportTaskLabel
        catalogMatchesTask = $winner.catalogMatchesTask
        note               = $winner.note
        inventoryTypes     = @($inventoryTypes)
        winningObjectList  = $winningObjectList
    })
}

$divergences = @($perType | Where-Object { $_.verdict -eq 'divergence' })
$matchesCatalog = @($perType | Where-Object { $_.verdict -eq 'catalogMatchesTask' })
$ambiguous = @($perType | Where-Object { $_.verdict -eq 'ambiguous' })
$inconclusive = @($perType | Where-Object { $_.verdict -in @('inconclusive', 'nameOnlyWorks') })

$catalogUpdates = @()
if ($ApplyCatalog) {
    $catalogObj = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($row in $divergences) {
        $typeName = [string]$row.catalogTypeName
        $label = [string]$row.exportTaskLabel
        if ([string]::IsNullOrWhiteSpace($label)) { continue }

        $entry = $catalogObj.types.$typeName
        if ($null -eq $entry) { continue }

        $previous = $null
        if ($null -ne $entry.PSObject.Properties['exportTaskLabel']) {
            $previous = [string]$entry.exportTaskLabel
        }

        if ($null -eq $previous -or $previous -ne $label) {
            $entry | Add-Member -NotePropertyName exportTaskLabel -NotePropertyValue $label -Force
            [void]$catalogUpdates.Add([ordered]@{
                catalogTypeName = $typeName
                exportTaskLabel = $label
                previous        = $previous
            })
        }
    }

    if ($catalogUpdates.Count -gt 0) {
        $catalogObj | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $CatalogPath -Encoding utf8NoBOM
    }
}

$report = [ordered]@{
    generatedAt          = (Get-Date).ToString('o')
    matrixRoot           = $MatrixRoot
    testedTypeCount      = $perType.Count
    divergenceCount      = $divergences.Count
    catalogMatchCount    = $matchesCatalog.Count
    ambiguousCount       = $ambiguous.Count
    inconclusiveCount    = $inconclusive.Count
    notTestableNoInstance = @($notTestable | ForEach-Object {
        [ordered]@{
            catalogTypeName = $_.catalogTypeName
            perKb           = $_.perKb
        }
    })
    divergences          = @($divergences)
    catalogMatchesTask   = @($matchesCatalog | ForEach-Object {
        [ordered]@{
            catalogTypeName    = $_.catalogTypeName
            kbId               = $_.kbId
            specimenObjectName = $_.specimenObjectName
            note               = $_.note
        }
    })
    ambiguous            = @($ambiguous)
    inconclusive         = @($inconclusive)
    catalogUpdatesApplied = @($catalogUpdates)
}

$reportDir = Split-Path -Parent $ReportPath
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
[System.IO.File]::WriteAllText($ReportPath, ($report | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))

if ($AsJson) {
    $report | ConvertTo-Json -Depth 12
} else {
    Write-Output "EXPORT_TASK_LABEL_MERGE_OK: divergences=$($divergences.Count) catalogMatch=$($matchesCatalog.Count) updates=$($catalogUpdates.Count) report=$ReportPath"
}

exit 0
