#requires -Version 7.4
<#
.SYNOPSIS
    Pré-validação de identidade Tipo:Nome contra índice KbIntelligence antes de export/import seletivo MSBuild.
#>

Set-StrictMode -Version Latest

$catalogSupportPath = Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1'
if (-not (Test-Path -LiteralPath $catalogSupportPath -PathType Leaf)) {
    throw "Catalog support not found: $catalogSupportPath"
}
. $catalogSupportPath

function Split-GeneXusMsBuildItemFilter {
    param([string]$FilterText)

    if ([string]::IsNullOrWhiteSpace($FilterText)) {
        return @()
    }

    return @(
        $FilterText -split ',|;|\r\n|\n' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() }
    )
}

function Test-IsSelectiveGeneXusXpzExport {
    param(
        [string]$ObjectList,
        [string]$ExportAll,
        [bool]$FullExportRequested
    )

    if ($FullExportRequested) { return $false }
    if ($ExportAll -eq 'true') { return $false }
    return -not [string]::IsNullOrWhiteSpace($ObjectList)
}

function Test-IsSelectiveGeneXusXpzImport {
    param([string]$IncludeItems)

    return (@(Split-GeneXusMsBuildItemFilter -FilterText $IncludeItems)).Count -gt 0
}

function Convert-GeneXusMsBuildItemFilterToObjectListText {
    param([string]$FilterText)

    $parts = @(Split-GeneXusMsBuildItemFilter -FilterText $FilterText)
    if ($parts.Count -eq 0) {
        return ''
    }

    return ($parts -join ';')
}

function Resolve-GeneXusKbIntelligenceIndexPath {
    param(
        [string]$IndexPath,
        [string]$ParallelKbRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($IndexPath)) {
        return [System.IO.Path]::GetFullPath($IndexPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) {
        return [System.IO.Path]::GetFullPath((Join-Path $ParallelKbRoot 'KbIntelligence\kb-intelligence.sqlite'))
    }

    return $null
}

function Read-GeneXusObjectListItemsFromText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $normalized = $Text -replace ';', "`n"
    $lines = @($normalized -split "`r?`n")
    $items = [System.Collections.Generic.List[object]]::new()
    $lineNumber = 0

    foreach ($line in $lines) {
        $lineNumber += 1
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $parts = @($trimmed -split '[:|	]', 2)
        if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
            throw ("BLOCK: entrada fora do formato Tipo:Nome (linha {0}): {1}" -f $lineNumber, $trimmed)
        }

        $typeLabel = $parts[0].Trim()
        $name = $parts[1].Trim()
        [void]$items.Add([ordered]@{
            declaredTypeLabel = $typeLabel
            name              = $name
            declaredKey       = ('{0}:{1}' -f $typeLabel, $name)
            sourceLine        = $lineNumber
        })
    }

    return @($items)
}

function Resolve-GeneXusCatalogTypeForExportLabel {
    param(
        [object]$MergedCatalog,
        [string]$ExportLabel,
        [bool]$PreferExportTaskLabel = $true
    )

    if ($null -eq $MergedCatalog -or $null -eq $MergedCatalog.types) {
        return $null
    }

    if ($PreferExportTaskLabel) {
        foreach ($property in $MergedCatalog.types.PSObject.Properties) {
            $entry = $property.Value
            if ($null -eq $entry.PSObject.Properties['exportTaskLabel']) {
                continue
            }
            $exportTaskLabel = [string]$entry.exportTaskLabel
            if (-not [string]::IsNullOrWhiteSpace($exportTaskLabel) -and
                $exportTaskLabel.Equals($ExportLabel, [System.StringComparison]::OrdinalIgnoreCase)) {
                return [string]$property.Name
            }
        }
    }

    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $catalogTypeName = [string]$property.Name
        if ($catalogTypeName.Equals($ExportLabel, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $catalogTypeName
        }

        $entry = $property.Value
        if ($null -ne $entry.PSObject.Properties['folderName']) {
            $folderName = [string]$entry.folderName
            if (-not [string]::IsNullOrWhiteSpace($folderName) -and
                $folderName.Equals($ExportLabel, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $catalogTypeName
            }
        }

        if ($null -ne $entry.PSObject.Properties['exportTaskLabel']) {
            $exportTaskLabel = [string]$entry.exportTaskLabel
            if (-not [string]::IsNullOrWhiteSpace($exportTaskLabel) -and
                $exportTaskLabel.Equals($ExportLabel, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $catalogTypeName
            }
        }
    }

    return $ExportLabel
}

function Invoke-GeneXusKbIntelligenceQueryJson {
    param(
        [string]$IndexPath,
        [string]$Query,
        [string]$ObjectType,
        [string]$ObjectName,
        [int]$Limit = 0,
        [string]$ParallelKbRoot,
        [string]$CatalogOverridePath
    )

    $queryScript = Join-Path $PSScriptRoot 'Query-KbIntelligenceIndex.ps1'
    if (-not (Test-Path -LiteralPath $queryScript -PathType Leaf)) {
        throw "Query script not found: $queryScript"
    }

    $args = @{
        IndexPath = $IndexPath
        Query     = $Query
        Format    = 'json'
    }
    if (-not [string]::IsNullOrWhiteSpace($ObjectType)) { $args.ObjectType = $ObjectType }
    if (-not [string]::IsNullOrWhiteSpace($ObjectName)) { $args.ObjectName = $ObjectName }
    if ($Limit -gt 0) { $args.Limit = $Limit }
    if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) { $args.ParallelKbRoot = $ParallelKbRoot }
    if (-not [string]::IsNullOrWhiteSpace($CatalogOverridePath)) { $args.CatalogOverridePath = $CatalogOverridePath }

    $raw = & pwsh -NoProfile -File $queryScript @args 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "KbIntelligence query '$Query' failed (exit $LASTEXITCODE): $raw"
    }

    return ($raw | ConvertFrom-Json)
}

function Test-GeneXusKbIntelligenceIndexReady {
    param(
        [string]$IndexPath,
        [string]$ParallelKbRoot,
        [string]$CatalogOverridePath
    )

    if (-not (Test-Path -LiteralPath $IndexPath -PathType Leaf)) {
        return [pscustomobject]@{
            ok     = $false
            reason = "Índice KbIntelligence não encontrado: $IndexPath"
        }
    }

    try {
        $meta = Invoke-GeneXusKbIntelligenceQueryJson `
            -IndexPath $IndexPath `
            -Query 'index-metadata' `
            -ParallelKbRoot $ParallelKbRoot `
            -CatalogOverridePath $CatalogOverridePath
    } catch {
        return [pscustomobject]@{
            ok     = $false
            reason = $_.Exception.Message
        }
    }

    $lastBuild = $null
    if ($null -ne $meta.PSObject.Properties['last_index_build_run_at']) {
        $lastBuild = [string]$meta.last_index_build_run_at
    } elseif ($null -ne $meta.metadata -and $null -ne $meta.metadata.PSObject.Properties['last_index_build_run_at']) {
        $lastBuild = [string]$meta.metadata.last_index_build_run_at
    }

    if ([string]::IsNullOrWhiteSpace($lastBuild)) {
        return [pscustomobject]@{
            ok     = $false
            reason = 'Índice incompatível ou legado: metadata.last_index_build_run_at ausente — regenere o índice.'
        }
    }

    return [pscustomobject]@{
        ok               = $true
        reason           = $null
        lastIndexBuildAt = $lastBuild
    }
}

function Get-GeneXusObjectListIdentityPreflightItem {
    param(
        [object]$Item,
        [string]$CatalogTypeName,
        [string]$IndexPath,
        [string]$ParallelKbRoot,
        [string]$CatalogOverridePath
    )

    $name = [string]$Item.name
    $declaredLabel = [string]$Item.declaredTypeLabel
    $declaredKey = [string]$Item.declaredKey

    $info = Invoke-GeneXusKbIntelligenceQueryJson `
        -IndexPath $IndexPath `
        -Query 'object-info' `
        -ObjectType $CatalogTypeName `
        -ObjectName $name `
        -ParallelKbRoot $ParallelKbRoot `
        -CatalogOverridePath $CatalogOverridePath

    if ($info.found -eq $true) {
        return [pscustomobject]@{
            declaredKey         = $declaredKey
            declaredTypeLabel   = $declaredLabel
            catalogTypeName     = $CatalogTypeName
            name                = $name
            status              = 'ok'
            note                = 'Par Tipo:Nome confirmado no índice.'
            indexTypesForName   = @($CatalogTypeName)
            searchTotal         = 1
        }
    }

    $search = Invoke-GeneXusKbIntelligenceQueryJson `
        -IndexPath $IndexPath `
        -Query 'search-objects' `
        -ObjectName $name `
        -Limit 50 `
        -ParallelKbRoot $ParallelKbRoot `
        -CatalogOverridePath $CatalogOverridePath

    $searchTotal = 0
    if ($null -ne $search.PSObject.Properties['total']) {
        $searchTotal = [int]$search.total
    }

    $typesForName = @(
        @($search.results) |
            ForEach-Object { [string]$_.type } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    if ($typesForName.Count -gt 1) {
        return [pscustomobject]@{
            declaredKey       = $declaredKey
            declaredTypeLabel = $declaredLabel
            catalogTypeName   = $CatalogTypeName
            name              = $name
            status            = 'ambiguous'
            note              = ('Homônimo no índice: nome "{0}" em {1} tipo(s): {2}' -f $name, $typesForName.Count, ($typesForName -join ', '))
            indexTypesForName = @($typesForName)
            searchTotal       = $searchTotal
        }
    }

    if ($typesForName.Count -eq 1 -and -not $typesForName[0].Equals($CatalogTypeName, [System.StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{
            declaredKey       = $declaredKey
            declaredTypeLabel = $declaredLabel
            catalogTypeName   = $CatalogTypeName
            name              = $name
            status            = 'ambiguous'
            note              = ('Nome "{0}" existe no índice como tipo "{1}", não como "{2}".' -f $name, $typesForName[0], $CatalogTypeName)
            indexTypesForName = @($typesForName)
            searchTotal       = $searchTotal
        }
    }

    return [pscustomobject]@{
        declaredKey       = $declaredKey
        declaredTypeLabel = $declaredLabel
        catalogTypeName   = $CatalogTypeName
        name              = $name
        status            = 'not_in_index'
        note              = ('Objeto não encontrado no índice como {0}:{1}; pode existir só na KB nativa ou acervo ainda não sincronizado.' -f $CatalogTypeName, $name)
        indexTypesForName = @($typesForName)
        searchTotal       = $searchTotal
    }
}

function ConvertTo-GeneXusObjectListPreflightLogSection {
    param($PreflightResult)

    if ($null -eq $PreflightResult -or -not $PreflightResult.preflightEnabled) {
        return $null
    }

    return [ordered]@{
        gateContext         = $PreflightResult.gateContext
        preflightEnabled    = $PreflightResult.preflightEnabled
        preflightSkipped    = $PreflightResult.preflightSkipped
        preflightSkipReason = $PreflightResult.preflightSkipReason
        parallelKbRoot      = $PreflightResult.parallelKbRoot
        lastIndexBuildAt    = $PreflightResult.lastIndexBuildAt
        items               = @($PreflightResult.preflightItems)
    }
}

function New-GeneXusObjectListPreflightSkippedResult {
    param(
        [string]$GateContext,
        [string]$PreflightSkipReason,
        [string]$ParallelKbRoot
    )

    return [pscustomobject]@{
        gateContext         = $GateContext
        preflightEnabled    = $false
        preflightSkipped    = $true
        preflightSkipReason = $PreflightSkipReason
        block               = $false
        exitCode            = 0
        indexPath           = $null
        parallelKbRoot      = $ParallelKbRoot
        preflightItems      = @()
        blockingReasons     = @()
        warnings            = @()
    }
}

function Invoke-GeneXusObjectListIdentityPreflight {
    param(
        [ValidateSet('export', 'import')]
        [string]$GateContext = 'export',
        [string]$ObjectList,
        [string]$ExportAll,
        [bool]$FullExportRequested,
        [string]$IncludeItems,
        [string]$ParallelKbRoot,
        [string]$IndexPath,
        [string]$CatalogOverridePath,
        [string]$BaseCatalogPath
    )

    $itemListText = $null
    $selective = $false
    $skipReason = $null

    if ($GateContext -eq 'import') {
        $selective = Test-IsSelectiveGeneXusXpzImport -IncludeItems $IncludeItems
        if ($selective) {
            $itemListText = Convert-GeneXusMsBuildItemFilterToObjectListText -FilterText $IncludeItems
        } else {
            $skipReason = 'import_not_selective'
        }
    } else {
        $selective = Test-IsSelectiveGeneXusXpzExport `
            -ObjectList $ObjectList `
            -ExportAll $ExportAll `
            -FullExportRequested $FullExportRequested
        if ($selective) {
            $itemListText = $ObjectList
        } else {
            $skipReason = 'export_not_selective'
        }
    }

    if (-not $selective) {
        return (New-GeneXusObjectListPreflightSkippedResult `
            -GateContext $GateContext `
            -PreflightSkipReason $skipReason `
            -ParallelKbRoot $ParallelKbRoot)
    }

    $resolvedParallel = if ([string]::IsNullOrWhiteSpace($ParallelKbRoot)) { $null } else { [System.IO.Path]::GetFullPath($ParallelKbRoot) }
    $resolvedIndex = Resolve-GeneXusKbIntelligenceIndexPath -IndexPath $IndexPath -ParallelKbRoot $resolvedParallel

    if ([string]::IsNullOrWhiteSpace($resolvedIndex)) {
        return [pscustomobject]@{
            gateContext         = $GateContext
            preflightEnabled    = $true
            preflightSkipped    = $false
            preflightSkipReason = $null
            block               = $true
            exitCode            = 35
            indexPath           = $null
            parallelKbRoot      = $resolvedParallel
            preflightItems      = @()
            blockingReasons     = @('Operação seletiva MSBuild com lista Tipo:Nome exige -ParallelKbRoot ou -IndexPath do índice KbIntelligence.')
            warnings            = @()
        }
    }

    $indexReady = Test-GeneXusKbIntelligenceIndexReady `
        -IndexPath $resolvedIndex `
        -ParallelKbRoot $resolvedParallel `
        -CatalogOverridePath $CatalogOverridePath

    if (-not $indexReady.ok) {
        return [pscustomobject]@{
            gateContext         = $GateContext
            preflightEnabled    = $true
            preflightSkipped    = $false
            preflightSkipReason = $null
            block               = $true
            exitCode            = 35
            indexPath           = $resolvedIndex
            parallelKbRoot      = $resolvedParallel
            lastIndexBuildAt    = $null
            preflightItems      = @()
            blockingReasons     = @([string]$indexReady.reason)
            warnings            = @()
        }
    }

    $catalogResolved = Resolve-GeneXusObjectTypeCatalogPaths `
        -BaseCatalogPath $BaseCatalogPath `
        -CatalogOverridePath $CatalogOverridePath `
        -ParallelKbRoot $resolvedParallel

    $items = @(Read-GeneXusObjectListItemsFromText -Text $itemListText)
    $preflightItems = [System.Collections.Generic.List[object]]::new()
    $blockingReasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($item in $items) {
        $catalogTypeName = Resolve-GeneXusCatalogTypeForExportLabel `
            -MergedCatalog $catalogResolved.MergedCatalog `
            -ExportLabel ([string]$item.declaredTypeLabel) -PreferExportTaskLabel ($GateContext -eq 'export')

        $row = Get-GeneXusObjectListIdentityPreflightItem `
            -Item $item `
            -CatalogTypeName $catalogTypeName `
            -IndexPath $resolvedIndex `
            -ParallelKbRoot $resolvedParallel `
            -CatalogOverridePath $catalogResolved.OverridePath

        [void]$preflightItems.Add([ordered]@{
            declaredKey       = $row.declaredKey
            declaredTypeLabel = $row.declaredTypeLabel
            catalogTypeName   = $row.catalogTypeName
            name              = $row.name
            status            = $row.status
            note              = $row.note
            indexTypesForName = @($row.indexTypesForName)
            searchTotal       = $row.searchTotal
        })

        switch ($row.status) {
            'ambiguous' {
                [void]$blockingReasons.Add([string]$row.note)
            }
            'not_in_index' {
                [void]$warnings.Add([string]$row.note)
            }
        }
    }

    $block = $blockingReasons.Count -gt 0

    return [pscustomobject]@{
        gateContext         = $GateContext
        preflightEnabled    = $true
        preflightSkipped    = $false
        preflightSkipReason = $null
        block               = $block
        exitCode            = if ($block) { 35 } else { 0 }
        indexPath           = $resolvedIndex
        parallelKbRoot      = $resolvedParallel
        lastIndexBuildAt    = $indexReady.lastIndexBuildAt
        catalogOverridePath = $catalogResolved.OverridePath
        preflightItems      = @($preflightItems)
        blockingReasons     = @($blockingReasons)
        warnings            = @($warnings)
    }
}
