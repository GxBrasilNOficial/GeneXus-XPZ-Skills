#requires -Version 7.4
<#
.SYNOPSIS
Inventaria objetos efetivamente presentes em import_file.xml ou pacote .xpz GeneXus.

.DESCRIPTION
Le um envelope GeneXus com raiz <ExportFile> (XML direto ou XML interno em .xpz),
lista os objetos sob <Objects> e atributos top-level sob <Attributes>, mapeia GUIDs
de tipo pelo catalogo compartilhado quando possível e, opcionalmente, confronta o
inventario de objetos com um delta declarado em texto Tipo:Nome.

.PARAMETER InputPath
Caminho do import_file.xml, XML equivalente com raiz <ExportFile> ou pacote .xpz.

.PARAMETER DeclaredDeltaPath
Arquivo texto opcional com o delta esperado, uma entrada por linha no formato Tipo:Nome.

.PARAMETER DeclaredDeltaItems
Lista inline opcional no formato Tipo:Nome separada por ponto-e-virgula (;) ou quebra
de linha. Ignorada quando DeclaredDeltaPath estiver informado.

.PARAMETER CatalogPath
Caminho opcional para gx-object-type-catalog.json.

.PARAMETER CatalogOverridePath
Caminho opcional para gx-object-type-catalog.override.json na pasta paralela.

.PARAMETER ParallelKbRoot
Raiz da pasta paralela; resolve override em scripts/ quando CatalogOverridePath omitido.

.PARAMETER FailOnUnknownTypes
Retorna exit code 3 quando houver tipo não mapeado no catalogo efetivo (pre-varredura de sync).

.PARAMETER PlatformObjectsCatalogPath
Caminho opcional para gx-platform-objects.json (catalogo unificado de plataforma/SDK).

.PARAMETER FailOnDeltaMismatch
Quando informado junto com delta declarado, retorna exit code 2 se houver objetos
extras ou ausentes na comparacao seletiva (somente bloco Objects).

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$DeclaredDeltaPath,

    [string]$DeclaredDeltaItems,

    [string]$CatalogPath,

    [string]$CatalogOverridePath,

    [string]$ParallelKbRoot,

    [switch]$FailOnUnknownTypes,

    [string]$PlatformObjectsCatalogPath,

    [switch]$FailOnDeltaMismatch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    $message = $_.Exception.Message
    $exitCode = if ($message.StartsWith('BLOCK:')) { 20 } else { 90 }
    $status = if ($exitCode -eq 20) { 'bloqueado' } else { 'erro' }
    [ordered]@{
        status = $status
        exitCode = $exitCode
        inputPath = $InputPath
        blockingReasons = @($message)
        warnings = @()
    } | ConvertTo-Json -Depth 6
    exit $exitCode
}

$supportScript = Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1'
if (-not (Test-Path -LiteralPath $supportScript -PathType Leaf)) {
    throw "BLOCK: support script not found: $supportScript"
}
. $supportScript

$platformCatalogSupport = Join-Path $PSScriptRoot 'GeneXusPlatformObjectsCatalogSupport.ps1'
if (-not (Test-Path -LiteralPath $platformCatalogSupport -PathType Leaf)) {
    throw "BLOCK: support script not found: $platformCatalogSupport"
}
. $platformCatalogSupport

$legacyExportSupportScript = Join-Path $PSScriptRoot 'GeneXusLegacyExportFileSupport.ps1'
if (-not (Test-Path -LiteralPath $legacyExportSupportScript -PathType Leaf)) {
    throw "BLOCK: support script not found: $legacyExportSupportScript"
}
. $legacyExportSupportScript

function Get-IdentityKey {
    param(
        [string]$TypeName,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($TypeName) -or [string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    return ('{0}:{1}' -f $TypeName.Trim(), $Name.Trim()).ToLowerInvariant()
}

function Read-DeclaredDeltaLines {
    param([string[]]$Lines)

    $items = [System.Collections.Generic.List[pscustomobject]]::new()
    $lineNumber = 0
    foreach ($line in $Lines) {
        $lineNumber += 1
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith('#')) {
            continue
        }

        $parts = @($trimmed -split '[:|	]', 2)
        if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
            throw ("BLOCK: entrada fora do formato Tipo:Nome (linha {0}): {1}" -f $lineNumber, $trimmed)
        }

        $typeName = $parts[0].Trim()
        $name = $parts[1].Trim()
        $items.Add([pscustomobject]@{
            typeName = $typeName
            name     = $name
            key      = Get-IdentityKey -TypeName $typeName -Name $name
            source   = ('line {0}' -f $lineNumber)
        }) | Out-Null
    }

    return @($items)
}

function Read-DeclaredDeltaFromPath {
    param([string]$Path)
    return @(Read-DeclaredDeltaLines -Lines @(Get-Content -LiteralPath $Path -Encoding UTF8))
}

function Read-DeclaredDeltaFromItems {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $normalized = $Text -replace ';', "`n"
    $lines = @($normalized -split "`r?`n")
    return @(Read-DeclaredDeltaLines -Lines $lines)
}

function Get-ExportFileXmlDocument {
    param([string]$Path)

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()

    if ($extension -eq '.xpz' -or $extension -eq '.zip') {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $candidates = [System.Collections.Generic.List[System.Xml.XmlDocument]]::new()
        $candidateNames = [System.Collections.Generic.List[string]]::new()
        $zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedPath)
        try {
            foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' } | Sort-Object FullName)) {
                $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
                try {
                    $entryText = $reader.ReadToEnd()
                } finally {
                    $reader.Dispose()
                }

                $candidateDoc = New-Object System.Xml.XmlDocument
                try {
                    $candidateDoc.PreserveWhitespace = $true
                    $candidateDoc.LoadXml($entryText)
                } catch {
                    continue
                }

                if ($candidateDoc.DocumentElement.LocalName -eq 'ExportFile') {
                    $candidates.Add($candidateDoc) | Out-Null
                    $candidateNames.Add($entry.FullName) | Out-Null
                }
            }
        } finally {
            $zip.Dispose()
        }

        if ($candidates.Count -eq 0) {
            throw "BLOCK: pacote .xpz nao contem XML com raiz ExportFile: $resolvedPath"
        }
        if ($candidates.Count -gt 1) {
            $names = ($candidateNames -join ', ')
            throw ("BLOCK: pacote .xpz contem {0} candidatos ExportFile ambiguos ({1}); informe XML descompactado." -f $candidates.Count, $names)
        }

        return [pscustomobject]@{
            Document     = $candidates[0]
            ResolvedPath = $resolvedPath
            InputKind    = 'xpz'
            InnerXmlName = $candidateNames[0]
        }
    }

    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.Load($resolvedPath)
    return [pscustomobject]@{
        Document     = $document
        ResolvedPath = $resolvedPath
        InputKind    = 'xml'
        InnerXmlName = $null
    }
}

function New-InventoryItem {
    param(
        [System.Xml.XmlElement]$Node,
        [hashtable]$GuidMap,
        [string]$SourceBlock,
        [int]$Index
    )

    $rootKind = $Node.LocalName
    $rawTypeGuid = $Node.GetAttribute('type')
    $name = $Node.GetAttribute('name')
    $guid = $Node.GetAttribute('guid')
    $typeName = $null
    $typeStatus = 'unknown'

    if ($rootKind -eq 'Attribute') {
        $typeName = 'Attribute'
        $typeStatus = 'root-kind'
    } elseif (-not [string]::IsNullOrWhiteSpace($rawTypeGuid)) {
        $typeKey = $rawTypeGuid.ToLowerInvariant()
        if ($GuidMap.ContainsKey($typeKey)) {
            $typeName = $GuidMap[$typeKey].typeName
            $typeStatus = 'mapped'
        }
    }

    $identityKey = Get-IdentityKey -TypeName $typeName -Name $name

    $parent = $null
    $parentType = $null
    if ($rootKind -eq 'Object') {
        $parent = $Node.GetAttribute('parent')
        if ([string]::IsNullOrWhiteSpace($parent)) { $parent = $null }
        $parentType = $Node.GetAttribute('parentType')
        if ([string]::IsNullOrWhiteSpace($parentType)) { $parentType = $null }
    }

    return [pscustomobject]@{
        index       = $Index
        sourceBlock = $SourceBlock
        rootKind    = $rootKind
        type        = $typeName
        typeName    = $typeName
        typeGuid    = if ([string]::IsNullOrWhiteSpace($rawTypeGuid)) { $null } else { $rawTypeGuid }
        typeStatus  = $typeStatus
        name        = if ([string]::IsNullOrWhiteSpace($name)) { $null } else { $name }
        guid        = if ([string]::IsNullOrWhiteSpace($guid)) { $null } else { $guid }
        parent      = $parent
        parentType  = $parentType
        identityKey = $identityKey
    }
}

function Get-ObjectsByTypeMap {
    param($InventoryItems)

    $map = [ordered]@{}
    foreach ($item in @($InventoryItems | Where-Object { $_.sourceBlock -eq 'Objects' -and -not [string]::IsNullOrWhiteSpace($_.typeName) })) {
        $key = [string]$item.typeName
        if ($map.Contains($key)) {
            $map[$key] = [int]$map[$key] + 1
        } else {
            $map[$key] = 1
        }
    }
    return $map
}

function Resolve-GeneXusExportTaskLabelAliasMatches {
    param(
        [object[]]$DeclaredItems,
        [object[]]$ObjectItems,
        [System.Collections.Generic.HashSet[string]]$InventoryKeys,
        [object[]]$AliasRules
    )

    $resolutions = [System.Collections.Generic.List[object]]::new()
    $consumedInventoryKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($declared in @($DeclaredItems)) {
        if ([string]::IsNullOrWhiteSpace($declared.key)) {
            continue
        }
        if ($InventoryKeys.Contains($declared.key)) {
            continue
        }

        foreach ($rule in @($AliasRules)) {
            if (-not $declared.typeName.Equals($rule.exportTaskLabel, [System.StringComparison]::OrdinalIgnoreCase)) {
                continue
            }

            $candidates = @(
                $ObjectItems | Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_.identityKey) -and
                    -not [string]::IsNullOrWhiteSpace($_.name) -and
                    $_.typeName.Equals($rule.catalogTypeName, [System.StringComparison]::OrdinalIgnoreCase) -and
                    $_.name.Equals($declared.name, [System.StringComparison]::OrdinalIgnoreCase)
                }
            )
            if ($candidates.Count -ne 1) {
                continue
            }

            $inventoryItem = $candidates[0]
            if ($consumedInventoryKeys.Contains($inventoryItem.identityKey)) {
                continue
            }

            [void]$consumedInventoryKeys.Add($inventoryItem.identityKey)
            [void]$resolutions.Add([ordered]@{
                declaredTypeName  = $declared.typeName
                declaredName      = $declared.name
                declaredKey       = $declared.key
                inventoryTypeName = $inventoryItem.typeName
                inventoryName     = $inventoryItem.name
                inventoryKey      = $inventoryItem.identityKey
                rule              = 'exportTaskLabel'
                catalogTypeGuid   = $rule.catalogTypeGuid
                catalogTypeName   = $rule.catalogTypeName
                exportTaskLabel   = $rule.exportTaskLabel
            })
            break
        }
    }

    return [pscustomobject]@{
        Resolutions             = @($resolutions)
        ConsumedInventoryKeys   = $consumedInventoryKeys
    }
}

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "BLOCK: InputPath nao encontrado: $InputPath"
}

$catalogResolution = Resolve-GeneXusObjectTypeCatalogPaths -BaseCatalogPath $CatalogPath -CatalogOverridePath $CatalogOverridePath -ParallelKbRoot $ParallelKbRoot
$CatalogPath = $catalogResolution.BaseCatalogPath
$guidMap = Get-GeneXusCatalogGuidToTypeMap -MergedCatalog $catalogResolution.MergedCatalog
$catalogFolderMap = Get-GeneXusCatalogGuidToFolderMap -MergedCatalog $catalogResolution.MergedCatalog
$exportTaskLabelAliasRules = @(Get-GeneXusExportTaskLabelAliasRules -MergedCatalog $catalogResolution.MergedCatalog)

if (-not $PlatformObjectsCatalogPath) {
    $PlatformObjectsCatalogPath = Join-Path $PSScriptRoot 'gx-platform-objects.json'
}
$platformCatalog = Import-GeneXusPlatformObjectsCatalog -CatalogPath $PlatformObjectsCatalogPath
$platformKindSets = Get-PlatformObjectKindSets -Catalog $platformCatalog

$package = Get-ExportFileXmlDocument -Path $InputPath
$root = $package.Document.DocumentElement
if ($null -eq $root -or $root.LocalName -ne 'ExportFile') {
    $found = if ($null -eq $root) { '<null>' } else { $root.LocalName }
    throw ("BLOCK: raiz esperada 'ExportFile'; encontrada '{0}'." -f $found)
}

$inventory = [System.Collections.Generic.List[pscustomObject]]::new()
$legacyFormatDetected = Test-GeneXusLegacyExportFilePackage -XmlDocument $package.Document
$legacyUnmappedElements = @()

if ($legacyFormatDetected) {
    $legacyInventory = Get-GeneXusLegacyExportFileInventoryItems -XmlDocument $package.Document -MergedCatalog $catalogResolution.MergedCatalog
    foreach ($legacyItem in $legacyInventory.Items) {
        $inventory.Add($legacyItem) | Out-Null
    }
    $legacyUnmappedElements = @($legacyInventory.UnmappedElements)
}
else {
    $objectsNode = $root.SelectSingleNode('./Objects')
    if ($null -ne $objectsNode) {
        $index = 0
        foreach ($child in @($objectsNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] })) {
            $index += 1
            $inventory.Add((New-InventoryItem -Node $child -GuidMap $guidMap -SourceBlock 'Objects' -Index $index)) | Out-Null
        }
    }

    $attributesNode = $root.SelectSingleNode('./Attributes')
    if ($null -ne $attributesNode) {
        $index = 0
        foreach ($child in @($attributesNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] })) {
            if ($child.LocalName -eq 'GXAtt') {
                continue
            }
            $index += 1
            $inventory.Add((New-InventoryItem -Node $child -GuidMap $guidMap -SourceBlock 'Attributes' -Index $index)) | Out-Null
        }
    }
}

$inventoryArray = @($inventory)
$objectItems = @($inventoryArray | Where-Object { $_.sourceBlock -eq 'Objects' -or $_.sourceBlock -eq 'GXObject' })
$attributeItems = @($inventoryArray | Where-Object { $_.sourceBlock -eq 'Attributes' })

$warnings = [System.Collections.Generic.List[string]]::new()
if ($legacyFormatDetected) {
    $warnings.Add('export-legado: envelope GXObject/GXAtt detectado; inventario via GeneXusLegacyExportFileSupport.') | Out-Null
    if ($legacyUnmappedElements.Count -gt 0) {
        $warnings.Add(("export-legado: elementos GXObject ignorados por falta de mapeamento: {0}" -f ($legacyUnmappedElements -join ', '))) | Out-Null
    }
}
$unknownTypeItems = @($inventoryArray | Where-Object { $_.typeStatus -eq 'unknown' })
foreach ($item in $unknownTypeItems) {
    $parentHint = if (-not [string]::IsNullOrWhiteSpace($item.parent)) { " parent='$($item.parent)'" } else { '' }
    $parentTypeHint = if (-not [string]::IsNullOrWhiteSpace($item.parentType)) { " parentType='$($item.parentType)'" } else { '' }
    $warnings.Add(("tipo nao mapeado no item {0}[{1}] name='{2}' typeGuid='{3}'{4}{5}" -f $item.sourceBlock, $item.index, $item.name, $item.typeGuid, $parentHint, $parentTypeHint)) | Out-Null
}

$unknownTypesDiscovery = @()
if (-not $legacyFormatDetected) {
    $unknownTypesDiscovery = @(Get-GeneXusUnknownObjectTypesFromExportFile -XmlDocument $package.Document -GuidToFolderMap $catalogFolderMap)
}

$objectsByType = Get-ObjectsByTypeMap -InventoryItems $inventoryArray
$systemObjectsPresent = @(Get-SystemObjectsPresent -InventoryItems $inventoryArray -PlatformKindSets $platformKindSets)

$deltaComparison = $null
$selectiveExport = $false
$status = 'INVENTORY_OK'
$exitCode = 0
$declaredIncludesTransaction = $false
$attributesTopLevelUnreconciled = $false

$declaredItems = @()
if (-not [string]::IsNullOrWhiteSpace($DeclaredDeltaPath)) {
    if (-not (Test-Path -LiteralPath $DeclaredDeltaPath -PathType Leaf)) {
        throw "BLOCK: DeclaredDeltaPath nao encontrado: $DeclaredDeltaPath"
    }
    $declaredItems = @(Read-DeclaredDeltaFromPath -Path $DeclaredDeltaPath)
} elseif (-not [string]::IsNullOrWhiteSpace($DeclaredDeltaItems)) {
    $declaredItems = @(Read-DeclaredDeltaFromItems -Text $DeclaredDeltaItems)
}

if ($declaredItems.Count -gt 0) {
    $selectiveExport = $true
    $declaredKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $declaredItems) {
        if (-not [string]::IsNullOrWhiteSpace($item.key)) {
            [void]$declaredKeys.Add($item.key)
        }
    }

    $inventoryKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $objectItems) {
        if (-not [string]::IsNullOrWhiteSpace($item.identityKey)) {
            [void]$inventoryKeys.Add($item.identityKey)
        }
    }

    $aliasMatchResult = Resolve-GeneXusExportTaskLabelAliasMatches `
        -DeclaredItems $declaredItems `
        -ObjectItems $objectItems `
        -InventoryKeys $inventoryKeys `
        -AliasRules $exportTaskLabelAliasRules
    $aliasResolutions = @($aliasMatchResult.Resolutions)
    $aliasResolvedDeclaredKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($resolution in $aliasResolutions) {
        if (-not [string]::IsNullOrWhiteSpace($resolution.declaredKey)) {
            [void]$aliasResolvedDeclaredKeys.Add($resolution.declaredKey)
        }
    }

    $extraKeys = @(
        $inventoryKeys |
            Where-Object {
                -not $declaredKeys.Contains($_) -and
                -not $aliasMatchResult.ConsumedInventoryKeys.Contains($_)
            } |
            Sort-Object
    )
    $missingKeys = @(
        $declaredKeys |
            Where-Object { -not $inventoryKeys.Contains($_) -and -not $aliasResolvedDeclaredKeys.Contains($_) } |
            Sort-Object
    )
    $extraObjects = @($objectItems | Where-Object { -not [string]::IsNullOrWhiteSpace($_.identityKey) -and $extraKeys -contains $_.identityKey })
    $uncomparableObjects = @($objectItems | Where-Object { [string]::IsNullOrWhiteSpace($_.identityKey) })
    $missingObjects = @($declaredItems | Where-Object { $missingKeys -contains $_.key })
    $requestedItemsFound = @(
        $declaredItems | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.key) -and (
                $inventoryKeys.Contains($_.key) -or $aliasResolvedDeclaredKeys.Contains($_.key)
            )
        }
    )

    $deltaStatus = if ($extraKeys.Count -eq 0 -and $missingKeys.Count -eq 0 -and $uncomparableObjects.Count -eq 0) { 'MATCH' } else { 'MISMATCH' }
    if ($deltaStatus -eq 'MISMATCH') {
        $status = 'DELTA_MISMATCH'
        if ($FailOnDeltaMismatch) {
            $exitCode = 2
        }
    }

    $deltaComparison = [ordered]@{
        status              = $deltaStatus
        selectiveExport     = $true
        declaredCount       = $declaredItems.Count
        requestedItemsFound = @($requestedItemsFound)
        requestedItemsMissing = @($missingObjects)
        matchedCount        = $requestedItemsFound.Count
        extraCount          = $extraKeys.Count
        missingCount        = $missingKeys.Count
        uncomparableCount   = $uncomparableObjects.Count
        extraObjects        = @($extraObjects)
        missingObjects      = @($missingObjects)
        uncomparableObjects = @($uncomparableObjects)
        systemObjectsPresent = @($systemObjectsPresent)
        aliasResolutions    = @($aliasResolutions)
        aliasResolutionCount = $aliasResolutions.Count
    }
}

if ($declaredItems.Count -gt 0) {
    $declaredIncludesTransaction = @($declaredItems | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.typeName) -and
            $_.typeName.Equals('Transaction', [System.StringComparison]::OrdinalIgnoreCase)
        }).Count -gt 0
}

if ($selectiveExport -and $attributeItems.Count -gt 0 -and -not $declaredIncludesTransaction) {
    $warnings.Add(('attributes-top-level-em-export-cirurgico: {0} atributo(s) top-level em export seletiva sem Transaction na lista declarada' -f $attributeItems.Count)) | Out-Null
    $attributesTopLevelUnreconciled = $true
}

if ($unknownTypesDiscovery.Count -gt 0 -and $FailOnUnknownTypes) {
    $status = 'UNKNOWN_TYPES_BLOCKED'
    $exitCode = 3
    $warnings.Add('pre-varredura bloqueada: tipos nao mapeados no catalogo efetivo; resolva antes de Sync-GeneXusXpzToXml.ps1') | Out-Null
}

$overrideReminder = $null
if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) {
    $overrideReminder = Get-GeneXusCatalogOverrideSessionReminder -ParallelKbRoot $ParallelKbRoot -CatalogOverridePath $CatalogOverridePath
    if ($overrideReminder.reminderRequired) {
        $warnings.Add($overrideReminder.message) | Out-Null
    }
}

$result = [ordered]@{
    status               = $status
    exitCode             = $exitCode
    inputPath            = $package.ResolvedPath
    inputKind            = $package.InputKind
    innerXmlEntry        = $package.InnerXmlName
    rootElement          = $root.LocalName
    legacyFormatDetected = [bool]$legacyFormatDetected
    legacyUnmappedElements = $legacyUnmappedElements
    selectiveExport      = $selectiveExport
    totalItemCount       = $inventoryArray.Count
    objectCount          = $objectItems.Count
    attributeCount       = $attributeItems.Count
    objectsByType                 = $objectsByType
    systemObjectsPresent          = @($systemObjectsPresent)
    declaredIncludesTransaction   = $declaredIncludesTransaction
    attributesTopLevelUnreconciled = $attributesTopLevelUnreconciled
    unknownTypeCount              = $unknownTypeItems.Count
    unknownTypesDiscovery         = $unknownTypesDiscovery
    catalogOverrideActive         = $catalogResolution.OverrideActive
    catalogOverridePath           = $catalogResolution.OverridePath
    catalogUpstreamPending        = $catalogResolution.UpstreamPending
    catalogOverrideReminder       = $overrideReminder
    inventory            = $inventoryArray
    deltaComparison      = $deltaComparison
    warnings             = @($warnings)
}

[pscustomobject]$result | ConvertTo-Json -Depth 10

exit $exitCode
