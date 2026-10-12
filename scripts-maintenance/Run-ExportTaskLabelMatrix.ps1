#requires -Version 7.4

<#
.SYNOPSIS
    Executa matriz de candidatos exportTaskLabel para um tipo e espécime em uma KB nativa.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$CatalogTypeName,

    [Parameter(Mandatory = $true)]
    [string]$SpecimenObjectName,

    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [string]$KbId = 'unknown',

    [string]$ParallelKbRoot,

    [string]$OutputDirectory,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [switch]$AsJson,

    [switch]$ParseOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusExportTaskLabelSupport.ps1'
. $supportPath

$runtimeScriptsPath = Join-Path (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path 'scripts'
$exportScript = Join-Path $runtimeScriptsPath 'Invoke-GeneXusXpzExport.ps1'
if (-not (Test-Path -LiteralPath $exportScript -PathType Leaf)) {
    throw "Export script not found: $exportScript"
}

$catalogTypes = @(Get-ExportTaskLabelCatalogTypes)
$typeEntry = @($catalogTypes | Where-Object { $_.catalogTypeName -eq $CatalogTypeName } | Select-Object -First 1)
if (@($typeEntry).Count -eq 0) {
    throw "Catalog type not found: $CatalogTypeName"
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $safeType = ($CatalogTypeName -replace '[^\w\-]', '_')
    $OutputDirectory = Join-Path $PSScriptRoot "..\historico\export-task-label-matrix-20260530\matrix\$KbId\$safeType"
}
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$candidates = @(Get-ExportTaskLabelCandidatesForType `
    -CatalogTypeName $typeEntry.catalogTypeName `
    -FolderName $typeEntry.folderName `
    -ObjectName $SpecimenObjectName `
    -ExistingExportTaskLabel $typeEntry.exportTaskLabel)

$runs = [System.Collections.Generic.List[object]]::new()
$runIndex = 0

foreach ($objectList in $candidates) {
    $runIndex += 1
    $safeCandidate = ($objectList -replace '[:\\\/\s]', '_')
    if ($safeCandidate.Length -gt 80) {
        $safeCandidate = $safeCandidate.Substring(0, 80)
    }
    $workDir = Join-Path $OutputDirectory ("run-{0:D2}-{1}" -f $runIndex, $safeCandidate)
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null

    $xpzPath = Join-Path $workDir 'matrix-export.xpz'
    $logPath = Join-Path $workDir 'export.json'

    $exportArgs = @{
        KbPath            = $KbPath
        XpzPath           = $xpzPath
        WorkingDirectory  = $workDir
        LogPath           = $logPath
        ObjectList        = $objectList
        ExportAll         = 'false'
    }
    if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) { $exportArgs.ParallelKbRoot = $ParallelKbRoot }
    if (-not [string]::IsNullOrWhiteSpace($GeneXusDir)) { $exportArgs.GeneXusDir = $GeneXusDir }
    if (-not [string]::IsNullOrWhiteSpace($MsBuildPath)) { $exportArgs.MsBuildPath = $MsBuildPath }

    $procExit = 0
    $procError = $null
    $skipExport = $ParseOnly -and (Test-Path -LiteralPath $logPath -PathType Leaf)
    if ($skipExport) {
        $procExit = 0
    } else {
        try {
            $null = & $exportScript @exportArgs 2>&1
            $procExit = $LASTEXITCODE
        } catch {
            $procError = $_.Exception.Message
            $procExit = 90
        }
    }

    $parsed = Get-ExportTaskLabelMatrixResultFromExportLog `
        -ExportLogPath $logPath `
        -ExpectedObjectName $SpecimenObjectName `
        -CatalogTypeName $typeEntry.catalogTypeName

    $candidateLabel = $null
    if ($objectList -match '^([^:]+):(.+)$') {
        $candidateLabel = $matches[1]
    }

    [void]$runs.Add([ordered]@{
        candidateId          = ('run-{0:D2}' -f $runIndex)
        objectList           = $objectList
        candidateTypeLabel   = $candidateLabel
        processExitCode      = $procExit
        processError         = $procError
        exitCode             = $parsed.exitCode
        invalidTypesRejected = @($parsed.invalidTypesRejected)
        exportErrors         = @($parsed.exportErrors)
        msBuildCategoryBBlocked = $parsed.msBuildCategoryBBlocked
        objectInXpz          = $parsed.objectInXpz
        inventoryTypes       = @($parsed.inventoryTypes)
        exportLogPath        = $logPath
        workingDirectory     = $workDir
        cleanSuccess         = (
            $procExit -eq 0 -and
            $parsed.parseOk -and
            $parsed.invalidTypesRejected.Count -eq 0 -and
            $parsed.exportErrors.Count -eq 0 -and
            $parsed.objectInXpz
        )
    })
}

$summary = [ordered]@{
    generatedAt        = (Get-Date).ToString('o')
    kbId               = $KbId
    kbPath             = $KbPath
    catalogTypeName    = $typeEntry.catalogTypeName
    folderName         = $typeEntry.folderName
    specimenObjectName = $SpecimenObjectName
    existingExportTaskLabel = $typeEntry.exportTaskLabel
    outputDirectory    = (Resolve-Path -LiteralPath $OutputDirectory).Path
    runs               = @($runs)
}

$summaryPath = Join-Path $OutputDirectory 'matrix-summary.json'
[System.IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 12), [System.Text.UTF8Encoding]::new($false))

if ($AsJson) {
    $summary | ConvertTo-Json -Depth 12
} else {
    Write-Output "EXPORT_TASK_LABEL_MATRIX_OK: $summaryPath"
}

exit 0
