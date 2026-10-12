#requires -Version 7.4

<#
.SYNOPSIS
    Funções compartilhadas para matriz exportTaskLabel (P5).
#>

Set-StrictMode -Version Latest

$script:ExportTaskLabelRepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$script:ExportTaskLabelRuntimeScriptsPath = Join-Path $script:ExportTaskLabelRepositoryRoot 'scripts'

$script:ExportTaskLabelKbRegistry = @(
    [ordered]@{
        id             = 'FabricaBrasil'
        parallelKbRoot = 'C:\Dev\Prod\Gx_FabricaBrasil'
        kbPath         = 'C:\GxModels\FabricaBrasil18'
        priority       = 1
        referenceKb    = $true
    }
    [ordered]@{
        id             = 'wsEducacao'
        parallelKbRoot = 'C:\Dev\Prod\Gx_wsEducacaoSpTeste'
        kbPath         = 'C:\KBs\wsEducacaoSpTeste'
        priority       = 2
        referenceKb    = $false
    }
    [ordered]@{
        id             = 'OnlineShopSS'
        parallelKbRoot = 'C:\Dev\Test\Gx_OnlineShopSS'
        kbPath         = 'C:\KBs\OnlineShopSS'
        priority       = 3
        referenceKb    = $false
    }
)

$script:ExportTaskLabelExtraCandidatesByType = [ordered]@{
    WorkWithForWeb = @('WorkWith', 'WWP', 'WorkWithDevicesForWeb', 'PatternInstance')
}

function Convert-UncGxPathToLocalPath {
    param([string]$UncPath)

    if ([string]::IsNullOrWhiteSpace($UncPath)) {
        return $null
    }

    $trimmed = $UncPath.Trim()
    if ($trimmed -match '^[A-Za-z]:\\') {
        return $trimmed
    }

    if ($trimmed -match '^\\\\[^\\]+\\[^\\]+\\(.+)$') {
        return (Join-Path 'C:\' ($matches[1] -replace '/', '\'))
    }

    return $trimmed
}

function Get-KbNativePathFromParallelRoot {
    param([string]$ParallelKbRoot)

    $metadataPath = Join-Path $ParallelKbRoot 'kb-source-metadata.md'
    if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
        return $null
    }

    $content = Get-Content -LiteralPath $metadataPath -Raw -Encoding UTF8
    if ($content -match '\|\s*UNCPath\s*\|\s*([^\|\r\n]+)\s*\|') {
        return (Convert-UncGxPathToLocalPath -UncPath $matches[1].Trim())
    }

    return $null
}

function Get-ExportTaskLabelKbRegistry {
  param([switch]$ResolveKbPathFromMetadata)

    $entries = @()
    foreach ($entry in $script:ExportTaskLabelKbRegistry) {
        $clone = [ordered]@{}
        foreach ($key in $entry.Keys) {
            $clone[$key] = $entry[$key]
        }
        if ($ResolveKbPathFromMetadata) {
            $resolved = Get-KbNativePathFromParallelRoot -ParallelKbRoot $clone.parallelKbRoot
            if (-not [string]::IsNullOrWhiteSpace($resolved)) {
                $clone.kbPath = $resolved
            }
        }
        $entries += ,[pscustomobject]$clone
    }
    return @($entries)
}

function Get-ExportTaskLabelCatalogTypes {
    param(
        [string]$CatalogPath = (Join-Path $script:ExportTaskLabelRuntimeScriptsPath 'gx-object-type-catalog.json')
    )

    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
        throw "Catalog not found: $CatalogPath"
    }

    $catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $types = [System.Collections.Generic.List[object]]::new()
    foreach ($property in $catalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.inventoryEligible -or -not [bool]$entry.inventoryEligible) {
            continue
        }
        if ($null -ne $entry.rootKind -and $entry.rootKind -ne 'Object') {
            continue
        }

        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            [string]$property.Name
        }

        $exportTaskLabel = $null
        if ($null -ne $entry.PSObject.Properties['exportTaskLabel'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.exportTaskLabel)) {
            $exportTaskLabel = [string]$entry.exportTaskLabel
        }

        [void]$types.Add([pscustomobject]@{
            catalogTypeName = [string]$property.Name
            folderName      = $folderName
            objectTypeGuid  = if ($null -ne $entry.objectTypeGuid) { [string]$entry.objectTypeGuid } else { $null }
            exportTaskLabel = $exportTaskLabel
        })
    }

    return @($types | Sort-Object catalogTypeName)
}

function Get-ExportTaskLabelCandidatesForType {
    param(
        [string]$CatalogTypeName,
        [string]$FolderName,
        [string]$ObjectName,
        [string]$ExistingExportTaskLabel
    )

    $labels = [System.Collections.Generic.List[string]]::new()
    $addLabel = {
        param([string]$Label)
        if ([string]::IsNullOrWhiteSpace($Label)) { return }
        foreach ($existing in $labels) {
            if ($existing.Equals($Label, [System.StringComparison]::OrdinalIgnoreCase)) {
                return
            }
        }
        [void]$labels.Add($Label)
    }

    & $addLabel $CatalogTypeName
    if (-not [string]::IsNullOrWhiteSpace($FolderName)) {
        & $addLabel $FolderName
    }
    if (-not [string]::IsNullOrWhiteSpace($ExistingExportTaskLabel)) {
        & $addLabel $ExistingExportTaskLabel
    }
    if ($script:ExportTaskLabelExtraCandidatesByType.Contains($CatalogTypeName)) {
        foreach ($extra in @($script:ExportTaskLabelExtraCandidatesByType[$CatalogTypeName])) {
            & $addLabel $extra
        }
    }

    $objectLists = [System.Collections.Generic.List[string]]::new()
    foreach ($label in $labels) {
        [void]$objectLists.Add(('{0}:{1}' -f $label, $ObjectName))
    }
    [void]$objectLists.Add($ObjectName)

    return @($objectLists)
}

function Invoke-KbIntelligenceListByTypeFirst {
    param(
        [string]$IndexPath,
        [string]$ObjectType,
        [int]$Limit = 1
    )

    $queryScript = Join-Path $script:ExportTaskLabelRuntimeScriptsPath 'Query-KbIntelligenceIndex.ps1'
    if (-not (Test-Path -LiteralPath $queryScript -PathType Leaf)) {
        throw "Query script not found: $queryScript"
    }

    $raw = & pwsh -NoProfile -File $queryScript -Query list-by-type -IndexPath $IndexPath -ObjectType $ObjectType -Limit $Limit -Format json
    if ($LASTEXITCODE -ne 0) {
        throw "list-by-type failed for $ObjectType (exit $LASTEXITCODE): $raw"
    }

    return ($raw | ConvertFrom-Json)
}

function Get-ExportTaskLabelMatrixResultFromExportLog {
    param(
        [string]$ExportLogPath,
        [string]$ExpectedObjectName,
        [string]$CatalogTypeName
    )

    if (-not (Test-Path -LiteralPath $ExportLogPath -PathType Leaf)) {
        return [pscustomobject]@{
            parseOk              = $false
            exitCode             = $null
            invalidTypesRejected = @()
            exportErrors         = @()
            objectInXpz          = $false
            inventoryTypes       = @()
            packageInventoryPath = $null
        }
    }

    $log = Get-Content -LiteralPath $ExportLogPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $invalid = @()
    if ($null -ne $log.PSObject.Properties['invalidTypesRejected']) {
        $invalid = @($log.invalidTypesRejected)
    }
    $exportErrors = @()
    if ($null -ne $log.PSObject.Properties['exportErrors']) {
        $exportErrors = @($log.exportErrors)
    }

    $objectInXpz = $false
    $inventoryTypes = [System.Collections.Generic.List[string]]::new()
    $packagePath = $null

    if ($null -ne $log.PSObject.Properties['packageInventory'] -and $null -ne $log.packageInventory) {
        $pi = $log.packageInventory
        if ($null -ne $pi.PSObject.Properties['objectsByType']) {
            foreach ($prop in $pi.objectsByType.PSObject.Properties) {
                [void]$inventoryTypes.Add([string]$prop.Name)
            }
        }
        if ($null -ne $pi.PSObject.Properties['nominalInventoryAt']) {
            $packagePath = [string]$pi.nominalInventoryAt
        }
    }

    if ($null -ne $log.PSObject.Properties['resolvedPaths'] -and $null -ne $log.resolvedPaths.PSObject.Properties['XpzPath']) {
        $xpzPath = [string]$log.resolvedPaths.XpzPath
        if ((Test-Path -LiteralPath $xpzPath -PathType Leaf) -and $inventoryTypes.Count -eq 0) {
            $inventoryScript = Join-Path $script:ExportTaskLabelRuntimeScriptsPath 'Get-GeneXusImportPackageObjectInventory.ps1'
            if (Test-Path -LiteralPath $inventoryScript -PathType Leaf) {
                $inv = & $inventoryScript -InputPath $xpzPath -AsJson | ConvertFrom-Json
                foreach ($item in @($inv.inventory | Where-Object { $_.sourceBlock -eq 'Objects' -and $_.name -eq $ExpectedObjectName })) {
                    if (-not [string]::IsNullOrWhiteSpace($item.typeName)) {
                        [void]$inventoryTypes.Add([string]$item.typeName)
                    }
                }
            }
        }
    }

    $aliasResolutionCount = 0
    if ($null -ne $log.PSObject.Properties['packageInventory'] -and $null -ne $log.packageInventory) {
        $piAlias = $log.packageInventory
        if ($null -ne $piAlias.PSObject.Properties['aliasResolutionCount']) {
            $aliasResolutionCount = [int]$piAlias.aliasResolutionCount
        }
    }

    $objectInXpz = @($inventoryTypes | Where-Object {
            $_ -eq $CatalogTypeName -or $aliasResolutionCount -gt 0
        }).Count -gt 0

    if (-not $objectInXpz) {
        $objectInXpz = @($inventoryTypes).Count -gt 0
        if ($null -ne $packagePath -and (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
            $sidecar = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $hit = @($sidecar.items | Where-Object {
                $_.sourceBlock -eq 'Objects' -and $_.name -eq $ExpectedObjectName
            })
            if ($hit.Count -gt 0) {
                $objectInXpz = $true
                foreach ($h in $hit) {
                    if (-not [string]::IsNullOrWhiteSpace($h.typeName)) {
                        [void]$inventoryTypes.Add([string]$h.typeName)
                    }
                }
            }
        }
    }

    return [pscustomobject]@{
        parseOk              = $true
        exitCode             = if ($null -ne $log.exitCode) { [int]$log.exitCode } else { $null }
        invalidTypesRejected = @($invalid)
        exportErrors         = @($exportErrors)
        objectInXpz          = $objectInXpz
        inventoryTypes       = @($inventoryTypes | Select-Object -Unique)
        packageInventoryPath = $packagePath
        msBuildCategoryBBlocked = if ($null -ne $log.PSObject.Properties['msBuildCategoryBBlocked']) { [bool]$log.msBuildCategoryBBlocked } else { $false }
    }
}
