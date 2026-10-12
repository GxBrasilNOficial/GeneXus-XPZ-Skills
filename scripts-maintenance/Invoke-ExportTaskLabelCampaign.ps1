#requires -Version 7.4

<#
.SYNOPSIS
    Campanha P5: matriz exportTaskLabel para todos os tipos com espécime no mapa de cobertura.
#>

param(
    [string]$CoverageMapPath = (Join-Path $PSScriptRoot '..\historico\export-task-label-matrix-20260530\coverage-map.json'),

    [string]$MatrixRoot = (Join-Path $PSScriptRoot '..\historico\export-task-label-matrix-20260530\matrix'),

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string[]]$SkipCatalogTypes = @(),

    [switch]$Force,

    [switch]$ParseOnly,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusExportTaskLabelSupport.ps1'
. $supportPath

$matrixScript = Join-Path $PSScriptRoot 'Run-ExportTaskLabelMatrix.ps1'
if (-not (Test-Path -LiteralPath $matrixScript -PathType Leaf)) {
    throw "Matrix script not found: $matrixScript"
}

if (-not (Test-Path -LiteralPath $CoverageMapPath -PathType Leaf)) {
    throw "Coverage map not found: $CoverageMapPath. Run Build-ExportTaskLabelCoverageMap.ps1 first."
}

$coverage = Get-Content -LiteralPath $CoverageMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
$skipSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($s in @($SkipCatalogTypes)) {
    if (-not [string]::IsNullOrWhiteSpace($s)) {
        [void]$skipSet.Add($s.Trim())
    }
}

$campaignLog = [System.Collections.Generic.List[object]]::new()
$testable = @($coverage.types | Where-Object { $_.testable })

foreach ($typeRow in $testable) {
    $catalogTypeName = [string]$typeRow.catalogTypeName
    if ($skipSet.Contains($catalogTypeName)) {
        [void]$campaignLog.Add([ordered]@{
            catalogTypeName = $catalogTypeName
            status          = 'skipped'
            reason          = 'SkipCatalogTypes'
        })
        continue
    }

    $chosen = $typeRow.chosenSpecimen
    $kbId = [string]$chosen.kbId
    $kbPath = [string]$chosen.kbPath
    $parallelKbRoot = [string]$chosen.parallelKbRoot
    $specimen = [string]$chosen.specimenName

    $safeType = ($catalogTypeName -replace '[^\w\-]', '_')
    $outDir = Join-Path $MatrixRoot "$kbId\$safeType"
    $summaryPath = Join-Path $outDir 'matrix-summary.json'

    if ((Test-Path -LiteralPath $summaryPath -PathType Leaf) -and -not $Force -and -not $ParseOnly) {
        [void]$campaignLog.Add([ordered]@{
            catalogTypeName = $catalogTypeName
            status          = 'skipped'
            reason          = 'matrix-summary exists'
            summaryPath     = $summaryPath
        })
        continue
    }

    try {
        $matrixParams = @{
            CatalogTypeName    = $catalogTypeName
            SpecimenObjectName = $specimen
            KbPath             = $kbPath
            KbId               = $kbId
            ParallelKbRoot     = $parallelKbRoot
            OutputDirectory    = $outDir
        }
        if (-not [string]::IsNullOrWhiteSpace($GeneXusDir)) { $matrixParams.GeneXusDir = $GeneXusDir }
        if (-not [string]::IsNullOrWhiteSpace($MsBuildPath)) { $matrixParams.MsBuildPath = $MsBuildPath }
        if ($ParseOnly) { $matrixParams.ParseOnly = $true }

        & $matrixScript @matrixParams

        if ($LASTEXITCODE -ne 0) {
            throw "Run-ExportTaskLabelMatrix exit $LASTEXITCODE"
        }

        [void]$campaignLog.Add([ordered]@{
            catalogTypeName = $catalogTypeName
            status          = 'completed'
            kbId            = $kbId
            specimenName    = $specimen
            summaryPath     = $summaryPath
        })
    } catch {
        [void]$campaignLog.Add([ordered]@{
            catalogTypeName = $catalogTypeName
            status          = 'failed'
            kbId            = $kbId
            specimenName    = $specimen
            error           = $_.Exception.Message
        })
    }
}

$campaignSummary = [ordered]@{
    generatedAt    = (Get-Date).ToString('o')
    coverageMapPath = (Resolve-Path -LiteralPath $CoverageMapPath).Path
    matrixRoot     = $MatrixRoot
    processedCount = $campaignLog.Count
    completedCount = @($campaignLog | Where-Object { $_.status -eq 'completed' }).Count
    failedCount    = @($campaignLog | Where-Object { $_.status -eq 'failed' }).Count
    skippedCount   = @($campaignLog | Where-Object { $_.status -eq 'skipped' }).Count
    entries        = @($campaignLog)
}

$campaignPath = Join-Path (Split-Path -Parent $CoverageMapPath) 'campaign-log.json'
[System.IO.File]::WriteAllText($campaignPath, ($campaignSummary | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))

if ($AsJson) {
    $campaignSummary | ConvertTo-Json -Depth 10
} else {
    Write-Output "EXPORT_TASK_LABEL_CAMPAIGN_OK: completed=$($campaignSummary.completedCount) failed=$($campaignSummary.failedCount) skipped=$($campaignSummary.skippedCount)"
}

exit 0
