#requires -Version 7.4
<#
.SYNOPSIS
    Suporte a pacotes ExportFile legados (GXObject / GXAtt) para materializacao e inventario.

.DESCRIPTION
    Adapta exports pre-modernos (ex.: GeneXus 9) para envelopes Object/Attribute reconheciveis
    pelo acervo ObjetosDaKbEmXml e pelo indice KbIntelligence, preservando o XML legado em
    GxLegacyPayload. Nao converte o pacote para formato moderno importavel pela IDE.
#>

Set-StrictMode -Version Latest

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$script:LegacyExportDataSourceAttribute = 'gx-legacy-export'
$script:LegacyExportPayloadElementName = 'GxLegacyPayload'
$script:LegacyExportElementMap = $null

function Get-GeneXusLegacyExportElementMapPath {
    return (Join-Path $PSScriptRoot 'gx-legacy-export-element-map.json')
}

function Get-GeneXusLegacyExportElementMap {
    if ($null -ne $script:LegacyExportElementMap) {
        return $script:LegacyExportElementMap
    }

    $mapPath = Get-GeneXusLegacyExportElementMapPath
    if (-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) {
        throw "Legacy export element map not found: $mapPath"
    }

    $raw = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8
    $script:LegacyExportElementMap = ($raw | ConvertFrom-Json)
    return $script:LegacyExportElementMap
}

function Get-GeneXusLegacyElementToCanonicalTypeMap {
    $map = Get-GeneXusLegacyExportElementMap
    $result = [ordered]@{}
    foreach ($property in $map.elementToCanonicalType.PSObject.Properties) {
        $result[$property.Name] = [string]$property.Value
    }
    return $result
}

function Test-GeneXusLegacyExportFilePackage {
    param([xml]$XmlDocument)

    if ($null -eq $XmlDocument -or $XmlDocument.DocumentElement.LocalName -ne 'ExportFile') {
        return $false
    }

    $hasGxObject = $null -ne $XmlDocument.SelectSingleNode('/ExportFile/GXObject')
    $modernObjectCount = @($XmlDocument.SelectNodes('/ExportFile/Objects/Object')).Count
    return $hasGxObject -and ($modernObjectCount -eq 0)
}

function Convert-GeneXusLegacyLastUpdateToIso8601 {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) {
        return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
    }

    $match = [regex]::Match($Raw, '(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})')
    if ($match.Success) {
        return '{0}T{1}.0000000Z' -f $match.Groups[1].Value, $match.Groups[2].Value
    }

    $parsed = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse($Raw, [ref]$parsed)) {
        return $parsed.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
    }

    return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
}

function Get-GeneXusLegacyExportCatalogMaps {
    param([object]$MergedCatalog)

    $canonicalToFolder = @{}
    $canonicalToGuid = @{}
    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $entry = $property.Value
        $canonicalName = [string]$property.Name
        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            $canonicalName
        }
        $canonicalToFolder[$canonicalName] = $folderName
        if ($null -ne $entry.objectTypeGuid -and -not [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
            $canonicalToGuid[$canonicalName] = [string]$entry.objectTypeGuid
        }
    }

    return @{
        CanonicalToFolder = $canonicalToFolder
        CanonicalToGuid   = $canonicalToGuid
    }
}

function Get-GeneXusLegacyExportObjectName {
    param([System.Xml.XmlElement]$TypeElement)

    $infoName = $TypeElement.SelectSingleNode('./Info/Name')
    if ($null -ne $infoName -and -not [string]::IsNullOrWhiteSpace($infoName.InnerText)) {
        return $infoName.InnerText.Trim()
    }

    throw "Legacy export object name not found under Info/Name for element '$($TypeElement.LocalName)'."
}

function Get-GeneXusLegacyExportObjectLastUpdate {
    param(
        [System.Xml.XmlElement]$TypeElement,
        [string]$FallbackIso8601
    )

    $lastUpdateNode = $TypeElement.SelectSingleNode('./LastUpdate')
    if ($null -ne $lastUpdateNode -and -not [string]::IsNullOrWhiteSpace($lastUpdateNode.InnerText)) {
        return (Convert-GeneXusLegacyLastUpdateToIso8601 -Raw $lastUpdateNode.InnerText.Trim())
    }

    return $FallbackIso8601
}

function New-GeneXusLegacyWrappedObjectXml {
    param(
        [string]$TypeGuid,
        [string]$Name,
        [string]$LastUpdate,
        [System.Xml.XmlElement]$LegacyInnerElement
    )

    $escapedName = [System.Security.SecurityElement]::Escape($Name)
    $legacyXml = $LegacyInnerElement.OuterXml
    $payloadTag = $script:LegacyExportPayloadElementName
    $dataSource = $script:LegacyExportDataSourceAttribute
    return @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$TypeGuid" name="$escapedName" lastUpdate="$LastUpdate" dataSource="$dataSource">
  <$payloadTag>
$legacyXml
  </$payloadTag>
</Object>
"@
}

function New-GeneXusLegacyWrappedAttributeXml {
    param(
        [string]$Name,
        [string]$LastUpdate,
        [System.Xml.XmlElement]$GxAttElement
    )

    $escapedName = [System.Security.SecurityElement]::Escape($Name)
    $legacyXml = $GxAttElement.OuterXml
    $payloadTag = $script:LegacyExportPayloadElementName
    $dataSource = $script:LegacyExportDataSourceAttribute
    return @"
<?xml version="1.0" encoding="utf-8"?>
<Attribute name="$escapedName" lastUpdate="$LastUpdate" dataSource="$dataSource">
  <$payloadTag>
$legacyXml
  </$payloadTag>
</Attribute>
"@
}

function Import-GeneXusLegacyWrappedXmlNode {
    param([string]$XmlText)

    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.LoadXml($XmlText)
    return $document.DocumentElement
}

function Get-GeneXusLegacyExportFileSyncItems {
    param(
        [xml]$XmlDocument,
        [object]$MergedCatalog,
        [scriptblock]$NormalizeFileBaseName
    )

    if ($null -eq $NormalizeFileBaseName) {
        throw 'NormalizeFileBaseName scriptblock is required.'
    }

    $elementMap = Get-GeneXusLegacyElementToCanonicalTypeMap
    $catalogMaps = Get-GeneXusLegacyExportCatalogMaps -MergedCatalog $MergedCatalog
    $items = New-Object System.Collections.Generic.List[object]
    $fallbackLastUpdate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
    $unmappedElements = New-Object System.Collections.Generic.List[string]

    foreach ($gxObject in $XmlDocument.SelectNodes('/ExportFile/GXObject')) {
        $typeElement = $null
        foreach ($child in $gxObject.ChildNodes) {
            if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                $typeElement = [System.Xml.XmlElement]$child
                break
            }
        }

        if ($null -eq $typeElement) {
            continue
        }

        $legacyTag = $typeElement.LocalName
        if (-not $elementMap.Contains($legacyTag)) {
            if ($unmappedElements -notcontains $legacyTag) {
                $unmappedElements.Add($legacyTag) | Out-Null
            }
            continue
        }

        $canonicalType = $elementMap[$legacyTag]
        if (-not $catalogMaps.CanonicalToFolder.ContainsKey($canonicalType) -or -not $catalogMaps.CanonicalToGuid.ContainsKey($canonicalType)) {
            throw "Legacy element '$legacyTag' maps to '$canonicalType' but the effective catalog has no folder/GUID entry."
        }

        $logicalName = Get-GeneXusLegacyExportObjectName -TypeElement $typeElement
        $lastUpdate = Get-GeneXusLegacyExportObjectLastUpdate -TypeElement $typeElement -FallbackIso8601 $fallbackLastUpdate
        $xmlText = New-GeneXusLegacyWrappedObjectXml `
            -TypeGuid $catalogMaps.CanonicalToGuid[$canonicalType] `
            -Name $logicalName `
            -LastUpdate $lastUpdate `
            -LegacyInnerElement $typeElement
        $node = Import-GeneXusLegacyWrappedXmlNode -XmlText $xmlText

        $items.Add([pscustomobject]@{
            PackageSection = 'GXObject'
            RootTag        = 'Object'
            FolderType     = $catalogMaps.CanonicalToFolder[$canonicalType]
            LogicalName    = $logicalName
            NormalizedName = & $NormalizeFileBaseName $logicalName
            TypeGuid       = $catalogMaps.CanonicalToGuid[$canonicalType].ToLowerInvariant()
            Guid           = ''
            LegacyElement  = $legacyTag
            CanonicalType  = $canonicalType
            Node           = $node
        }) | Out-Null
    }

    foreach ($gxAtt in $XmlDocument.SelectNodes('/ExportFile/Attributes/GXAtt')) {
        $attributeNode = $gxAtt.SelectSingleNode('./Attribute')
        if ($null -eq $attributeNode) {
            continue
        }

        $nameNode = $attributeNode.SelectSingleNode('./Name')
        if ($null -eq $nameNode -or [string]::IsNullOrWhiteSpace($nameNode.InnerText)) {
            continue
        }

        $logicalName = $nameNode.InnerText.Trim()
        $lastUpdateNode = $attributeNode.SelectSingleNode('./LastUpdate')
        $lastUpdate = if ($null -ne $lastUpdateNode) {
            Convert-GeneXusLegacyLastUpdateToIso8601 -Raw $lastUpdateNode.InnerText.Trim()
        } else {
            $fallbackLastUpdate
        }

        $xmlText = New-GeneXusLegacyWrappedAttributeXml `
            -Name $logicalName `
            -LastUpdate $lastUpdate `
            -GxAttElement ([System.Xml.XmlElement]$gxAtt)
        $node = Import-GeneXusLegacyWrappedXmlNode -XmlText $xmlText

        $items.Add([pscustomobject]@{
            PackageSection = 'Attributes'
            RootTag        = 'Attribute'
            FolderType     = 'Attribute'
            LogicalName    = $logicalName
            NormalizedName = & $NormalizeFileBaseName $logicalName
            TypeGuid       = 'attribute-top-level'
            Guid           = ''
            LegacyElement  = 'GXAtt'
            CanonicalType  = 'Attribute'
            Node           = $node
        }) | Out-Null
    }

    $collisions = @(
        $items |
        Group-Object { "$($_.FolderType)|$($_.NormalizedName)" } |
        Where-Object {
            $_.Count -gt 1 -and
            @($_.Group | Select-Object -ExpandProperty LogicalName | Sort-Object -Unique).Count -gt 1
        }
    )

    if ($collisions.Count -gt 0) {
        $details = foreach ($collision in $collisions) {
            $names = $collision.Group | Select-Object -ExpandProperty LogicalName | Sort-Object -Unique
            "$($collision.Name) <= $($names -join ', ')"
        }
        throw "Filename normalization collision detected in legacy export: $($details -join '; ')"
    }

    return [pscustomobject]@{
        Items            = @($items.ToArray())
        UnmappedElements = @($unmappedElements)
    }
}

function Get-GeneXusLegacyExportFileInventoryItems {
    param(
        [xml]$XmlDocument,
        [object]$MergedCatalog
    )

    $sync = Get-GeneXusLegacyExportFileSyncItems `
        -XmlDocument $XmlDocument `
        -MergedCatalog $MergedCatalog `
        -NormalizeFileBaseName { param($name)
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            $builder = New-Object System.Text.StringBuilder
            foreach ($char in $name.ToCharArray()) {
                if ($invalidChars -contains $char) { [void]$builder.Append('_') } else { [void]$builder.Append($char) }
            }
            $builder.ToString().TrimEnd('.')
        }

    $inventory = New-Object System.Collections.Generic.List[object]
    $index = 0
    foreach ($item in $sync.Items) {
        $index += 1
        $inventory.Add([pscustomobject]@{
            sourceBlock   = if ($item.PackageSection -eq 'GXObject') { 'GXObject' } else { 'Attributes' }
            index         = $index
            name          = $item.LogicalName
            identityKey   = if ($item.RootTag -eq 'Attribute') { "Attribute:$($item.LogicalName)" } else { "$($item.CanonicalType):$($item.LogicalName)" }
            typeGuid      = if ($item.RootTag -eq 'Attribute') { $null } else { $item.TypeGuid }
            typeName      = $item.CanonicalType
            typeStatus    = 'known'
            legacyElement = $item.LegacyElement
            parent        = $null
            parentType    = $null
        }) | Out-Null
    }

    return [pscustomobject]@{
        Items            = @($inventory.ToArray())
        UnmappedElements = @($sync.UnmappedElements)
        TotalCount       = $inventory.Count
    }
}

function Get-GeneXusLegacyKmwBuildFromPackage {
    param([xml]$XmlDocument)

    $kmwNode = $XmlDocument.SelectSingleNode('/ExportFile/KMW')
    if ($null -eq $kmwNode) {
        return ''
    }

    $buildNode = $kmwNode.SelectSingleNode('Build')
    if ($null -ne $buildNode -and -not [string]::IsNullOrWhiteSpace($buildNode.InnerText)) {
        return $buildNode.InnerText.Trim()
    }

    $legacyBuildNode = $kmwNode.SelectSingleNode('MaxGxBuildSaved')
    if ($null -ne $legacyBuildNode -and -not [string]::IsNullOrWhiteSpace($legacyBuildNode.InnerText)) {
        return $legacyBuildNode.InnerText.Trim()
    }

    return ''
}

function Get-GeneXusLegacyModelNameFromPackage {
    param([xml]$XmlDocument)

    $modelNameNode = $XmlDocument.SelectSingleNode('/ExportFile/Model/Name')
    if ($null -ne $modelNameNode -and -not [string]::IsNullOrWhiteSpace($modelNameNode.InnerText)) {
        return $modelNameNode.InnerText.Trim()
    }

    return ''
}

function Get-GeneXusLegacyKmwPathFromPackage {
    param([xml]$XmlDocument)

    $pathNode = $XmlDocument.SelectSingleNode('/ExportFile/KMW/Path')
    if ($null -ne $pathNode -and -not [string]::IsNullOrWhiteSpace($pathNode.InnerText)) {
        return $pathNode.InnerText.Trim()
    }

    return ''
}
