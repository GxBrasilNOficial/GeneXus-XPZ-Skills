#requires -Version 7.4
<#
.SYNOPSIS
    Suporte ao parsing e materializacao de pacotes ExportFile legados GeneXus 9
    (/ExportFile/GXObject/<Elemento>, identificados por NOME, sem GUID de tipo).

.DESCRIPTION
    Conversor PROPRIO (nao reusa Convert-PackageToItems) que adapta exports pre-modernos
    (GeneXus 9) para envelopes Object/Attribute reconheciveis pelo acervo ObjetosDaKbEmXml,
    CONSUMINDO o registro scripts/gx-legacy-export-element-registry.json (classes
    'equivalent'/'orphan') SEM poluir o catalogo moderno gx-object-type-catalog.json.

    Doc-dono da representacao: 01k-registro-elementos-legados.md. Spec do motor:
    revisao por pares Fase 2 (manuscrito congelado v2.8.5).

    Recebe o [xml] JA carregado encoding-aware (a correcao de leitura iso-8859-1 e local
    em Sync/Inventory) e o MergedCatalog JA resolvido; nao abre, rele nem descompacta arquivo.

    Regras-chave:
    - Deteccao de perfil compartilhada (Test-GeneXusLegacyExportFilePackage / ...Mixed...).
    - Pacote MISTO (GXObject + Objects/Object|Attributes/Attribute moderno) = fail-closed.
    - Tag fora do registro / >1 elemento-filho por GXObject / colisao de nome = fail-closed.
    - lastUpdate ausente/invalido => sentinela deterministica 0001-01-01 (NUNCA Get-Date).
    - Itens legados expoem Guid='' (nao participam de rename por GUID).
#>

Set-StrictMode -Version Latest

$script:LegacyExportSupportRoot = Split-Path -Parent $PSCommandPath

$utf8NoBomEncodingSupportPath = Join-Path $script:LegacyExportSupportRoot 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "Required support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$fileBaseNameNormalizationSupportPath = Join-Path $script:LegacyExportSupportRoot 'GeneXusFileBaseNameNormalizationSupport.ps1'
if (-not (Test-Path -LiteralPath $fileBaseNameNormalizationSupportPath -PathType Leaf)) {
    throw "Required support script not found: $fileBaseNameNormalizationSupportPath"
}
. $fileBaseNameNormalizationSupportPath

# Sentinela deterministica para lastUpdate ausente/invalido (NUNCA Get-Date).
$script:LegacyExportSentinelLastUpdate = '0001-01-01T00:00:00.0000000Z'
$script:LegacyExportDataSourceAttribute = 'gx-legacy-export'
$script:LegacyExportPayloadElementName = 'GxLegacyPayload'
$script:LegacyExportRegistryCache = $null

function Get-GeneXusLegacyExportElementRegistryPath {
    return (Join-Path $script:LegacyExportSupportRoot 'gx-legacy-export-element-registry.json')
}

function Get-GeneXusLegacyExportElementRegistry {
    <# Carrega (com cache) o registro de elementos legados. #>
    if ($null -ne $script:LegacyExportRegistryCache) {
        return $script:LegacyExportRegistryCache
    }
    $registryPath = Get-GeneXusLegacyExportElementRegistryPath
    if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
        throw "Legacy export element registry not found: $registryPath"
    }
    $raw = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8
    $script:LegacyExportRegistryCache = ($raw | ConvertFrom-Json)
    return $script:LegacyExportRegistryCache
}

function Get-GeneXusLegacyRegistryElementMap {
    <# Devolve hashtable: tag legada (case-sensitive) -> objeto do elemento do registro. #>
    param([object]$Registry)

    if ($null -eq $Registry) {
        $Registry = Get-GeneXusLegacyExportElementRegistry
    }
    if ($null -eq $Registry.PSObject.Properties['elements'] -or $null -eq $Registry.elements) {
        throw "Legacy export registry sem propriedade 'elements'."
    }
    $map = @{}
    foreach ($property in $Registry.elements.PSObject.Properties) {
        $map[$property.Name] = $property.Value
    }
    return $map
}

function Get-LegacyElementPropertyValue {
    <# Leitura StrictMode-safe de propriedade opcional de um elemento do registro. #>
    param(
        [object]$Element,
        [string]$Name
    )
    $prop = $Element.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Test-GeneXusLegacyExportFilePackage {
    <# Legado-puro: existe /ExportFile/GXObject e nenhum no moderno (Objects/Object, Attributes/Attribute). #>
    param([xml]$XmlDocument)

    if ($null -eq $XmlDocument -or $null -eq $XmlDocument.DocumentElement -or $XmlDocument.DocumentElement.LocalName -ne 'ExportFile') {
        return $false
    }
    $hasGxObject = $null -ne $XmlDocument.SelectSingleNode('/ExportFile/GXObject')
    if (-not $hasGxObject) { return $false }
    $modernObjectCount = @($XmlDocument.SelectNodes('/ExportFile/Objects/Object')).Count
    $modernAttributeCount = @($XmlDocument.SelectNodes('/ExportFile/Attributes/Attribute')).Count
    return ($modernObjectCount -eq 0) -and ($modernAttributeCount -eq 0)
}

function Test-GeneXusMixedExportFilePackage {
    <# Misto: GXObject presente E algum no moderno (Objects/Object ou Attributes/Attribute). Fora de escopo => fail-closed no caller. #>
    param([xml]$XmlDocument)

    if ($null -eq $XmlDocument -or $null -eq $XmlDocument.DocumentElement -or $XmlDocument.DocumentElement.LocalName -ne 'ExportFile') {
        return $false
    }
    $hasGxObject = $null -ne $XmlDocument.SelectSingleNode('/ExportFile/GXObject')
    if (-not $hasGxObject) { return $false }
    $modernObjectCount = @($XmlDocument.SelectNodes('/ExportFile/Objects/Object')).Count
    $modernAttributeCount = @($XmlDocument.SelectNodes('/ExportFile/Attributes/Attribute')).Count
    return ($modernObjectCount -gt 0) -or ($modernAttributeCount -gt 0)
}

function Convert-GeneXusLegacyLastUpdateToIso8601 {
    <# "YYYY-MM-DD HH:MM:SSGMT" -> "YYYY-MM-DDTHH:MM:SS.0000000Z". Ausente/invalido -> sentinela. #>
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) {
        return $script:LegacyExportSentinelLastUpdate
    }
    $match = [regex]::Match($Raw, '(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})')
    if ($match.Success) {
        return '{0}T{1}.0000000Z' -f $match.Groups[1].Value, $match.Groups[2].Value
    }
    return $script:LegacyExportSentinelLastUpdate
}

function Get-GeneXusLegacyCatalogMaps {
    <# Do MergedCatalog moderno: catalogType -> folderName e catalogType -> objectTypeGuid. #>
    param([object]$MergedCatalog)

    if ($null -eq $MergedCatalog -or $null -eq $MergedCatalog.PSObject.Properties['types'] -or $null -eq $MergedCatalog.types) {
        throw "MergedCatalog invalido (sem 'types')."
    }
    $canonicalToFolder = @{}
    $canonicalToGuid = @{}
    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $entry = $property.Value
        $canonicalName = [string]$property.Name
        $folderProp = $entry.PSObject.Properties['folderName']
        $folderName = if ($null -ne $folderProp -and -not [string]::IsNullOrWhiteSpace([string]$folderProp.Value)) { [string]$folderProp.Value } else { $canonicalName }
        $canonicalToFolder[$canonicalName] = $folderName
        $guidProp = $entry.PSObject.Properties['objectTypeGuid']
        if ($null -ne $guidProp -and -not [string]::IsNullOrWhiteSpace([string]$guidProp.Value)) {
            $canonicalToGuid[$canonicalName] = [string]$guidProp.Value
        }
    }
    return @{ CanonicalToFolder = $canonicalToFolder; CanonicalToGuid = $canonicalToGuid }
}

function Get-GeneXusLegacyExportObjectName {
    param([System.Xml.XmlElement]$TypeElement)

    $infoName = $TypeElement.SelectSingleNode('./Info/Name')
    if ($null -ne $infoName -and -not [string]::IsNullOrWhiteSpace($infoName.InnerText)) {
        return $infoName.InnerText.Trim()
    }
    throw "Export legado: nome nao encontrado em Info/Name para o elemento '$($TypeElement.LocalName)'."
}

function Get-GeneXusLegacyObjectTypeElement {
    <# Primeiro (e unico) elemento-filho do <GXObject>. >1 elemento-filho => fail-closed defensivo. #>
    param([System.Xml.XmlElement]$GxObject)

    $elementChildren = @($GxObject.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
    if ($elementChildren.Count -eq 0) {
        return $null
    }
    if ($elementChildren.Count -gt 1) {
        $tags = ($elementChildren | ForEach-Object { $_.LocalName }) -join ', '
        throw "Export legado: <GXObject> com mais de um elemento-filho ($tags); estrutura nao prevista (premissa: 1 elemento-tipo por GXObject). Fail-closed defensivo."
    }
    return [System.Xml.XmlElement]$elementChildren[0]
}

function New-GeneXusLegacyWrappedXml {
    <# Envelope moderno: lastUpdate injetado como ATRIBUTO da raiz (garante Get-LastUpdateInfoFromNode). #>
    param(
        [ValidateSet('Object', 'Attribute')][string]$RootTag,
        [string]$TypeAttribute,
        [string]$Name,
        [string]$LastUpdate,
        [System.Xml.XmlElement]$LegacyInnerElement
    )

    $escapedName = [System.Security.SecurityElement]::Escape($Name)
    $legacyXml = $LegacyInnerElement.OuterXml
    $payloadTag = $script:LegacyExportPayloadElementName
    $dataSource = $script:LegacyExportDataSourceAttribute
    $typeAttr = if ($RootTag -eq 'Object') { ' type="' + [System.Security.SecurityElement]::Escape($TypeAttribute) + '"' } else { '' }
    return @"
<?xml version="1.0" encoding="utf-8"?>
<$RootTag$typeAttr name="$escapedName" guid="" lastUpdate="$LastUpdate" dataSource="$dataSource">
  <$payloadTag>
$legacyXml
  </$payloadTag>
</$RootTag>
"@
}

function Import-GeneXusLegacyWrappedXmlNode {
    param([string]$XmlText)

    $document = New-Object System.Xml.XmlDocument
    $document.PreserveWhitespace = $true
    $document.LoadXml($XmlText)
    return $document.DocumentElement
}

function Test-GeneXusLegacyItemNameCollision {
    <# Mesma deteccao do moderno (Convert-PackageToItems): FolderType|NormalizedName com nomes logicos distintos => throw. #>
    param([object[]]$Items)

    $collisions = @(
        $Items |
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
        throw "Export legado: colisao de nome normalizado detectada: $($details -join '; ')"
    }
}

function Get-GeneXusLegacyExportFileSyncItems {
    <#
        Conversor proprio. Retorna { Items[] } na MESMA forma dos itens modernos
        (PackageSection/RootTag/FolderType/LogicalName/NormalizedName/TypeGuid/Guid/Node),
        para reuso transparente de Write-ItemToDestination / Resolve-GuidAwareRenames /
        Test-PackageMaterialization. Tag fora do registro => fail-closed (excecao com tag,
        contagem e caminho de extensao do registro).
    #>
    param(
        [xml]$XmlDocument,
        [object]$MergedCatalog,
        [object]$Registry,
        [scriptblock]$NormalizeFileBaseName
    )

    if ($null -eq $NormalizeFileBaseName) {
        $NormalizeFileBaseName = { param($LogicalName) Normalize-FileBaseName -LogicalName $LogicalName }
    }
    $registryMap = Get-GeneXusLegacyRegistryElementMap -Registry $Registry
    $catalogMaps = Get-GeneXusLegacyCatalogMaps -MergedCatalog $MergedCatalog
    $items = New-Object System.Collections.Generic.List[object]
    $unmappedCounts = @{}

    foreach ($gxObject in $XmlDocument.SelectNodes('/ExportFile/GXObject')) {
        $typeElement = Get-GeneXusLegacyObjectTypeElement -GxObject ([System.Xml.XmlElement]$gxObject)
        if ($null -eq $typeElement) { continue }

        $legacyTag = $typeElement.LocalName
        if (-not $registryMap.ContainsKey($legacyTag)) {
            if ($unmappedCounts.ContainsKey($legacyTag)) { $unmappedCounts[$legacyTag] = [int]$unmappedCounts[$legacyTag] + 1 } else { $unmappedCounts[$legacyTag] = 1 }
            continue
        }

        $element = $registryMap[$legacyTag]
        $class = [string](Get-LegacyElementPropertyValue -Element $element -Name 'class')
        $logicalName = Get-GeneXusLegacyExportObjectName -TypeElement $typeElement
        $lastUpdateNode = $typeElement.SelectSingleNode('./LastUpdate')
        $rawLastUpdate = if ($null -ne $lastUpdateNode) { $lastUpdateNode.InnerText } else { '' }
        $lastUpdate = Convert-GeneXusLegacyLastUpdateToIso8601 -Raw $rawLastUpdate

        if ($class -eq 'equivalent') {
            $catalogType = [string](Get-LegacyElementPropertyValue -Element $element -Name 'catalogType')
            if (-not $catalogMaps.CanonicalToFolder.ContainsKey($catalogType) -or -not $catalogMaps.CanonicalToGuid.ContainsKey($catalogType)) {
                throw "Export legado: elemento '$legacyTag' mapeia para '$catalogType' (equivalent), mas o catalogo efetivo nao tem folder/GUID para esse tipo."
            }
            $typeAttribute = $catalogMaps.CanonicalToGuid[$catalogType]
            $folderType = $catalogMaps.CanonicalToFolder[$catalogType]
            $canonicalType = $catalogType
        }
        elseif ($class -eq 'orphan') {
            $typeAttribute = [string](Get-LegacyElementPropertyValue -Element $element -Name 'typeToken')
            $folderType = [string](Get-LegacyElementPropertyValue -Element $element -Name 'materializedFolderName')
            $canonicalType = $typeAttribute
        }
        else {
            throw "Export legado: classe desconhecida '$class' para o elemento '$legacyTag' no registro."
        }

        $xmlText = New-GeneXusLegacyWrappedXml -RootTag 'Object' -TypeAttribute $typeAttribute -Name $logicalName -LastUpdate $lastUpdate -LegacyInnerElement $typeElement
        $node = Import-GeneXusLegacyWrappedXmlNode -XmlText $xmlText

        $items.Add([pscustomobject]@{
            PackageSection = 'Objects'
            RootTag        = 'Object'
            FolderType     = $folderType
            LogicalName    = $logicalName
            NormalizedName = (& $NormalizeFileBaseName $logicalName)
            TypeGuid       = $typeAttribute
            Guid           = ''
            LegacyElement  = $legacyTag
            CanonicalType  = $canonicalType
            Node           = $node
        }) | Out-Null
    }

    if ($unmappedCounts.Count -gt 0) {
        $details = ($unmappedCounts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name) (x$($_.Value))" }) -join ', '
        throw ("Export legado: elemento(s) GXObject fora do registro: {0}. Estenda 'scripts/gx-legacy-export-element-registry.json' (doc-dono 01k-registro-elementos-legados.md) antes de materializar." -f $details)
    }

    foreach ($gxAtt in $XmlDocument.SelectNodes('/ExportFile/Attributes/GXAtt')) {
        $attributeNode = $gxAtt.SelectSingleNode('./Attribute')
        if ($null -eq $attributeNode) { continue }
        $nameNode = $attributeNode.SelectSingleNode('./Name')
        if ($null -eq $nameNode -or [string]::IsNullOrWhiteSpace($nameNode.InnerText)) { continue }

        $logicalName = $nameNode.InnerText.Trim()
        $lastUpdateNode = $attributeNode.SelectSingleNode('./LastUpdate')
        $rawLastUpdate = if ($null -ne $lastUpdateNode) { $lastUpdateNode.InnerText } else { '' }
        $lastUpdate = Convert-GeneXusLegacyLastUpdateToIso8601 -Raw $rawLastUpdate

        $xmlText = New-GeneXusLegacyWrappedXml -RootTag 'Attribute' -TypeAttribute '' -Name $logicalName -LastUpdate $lastUpdate -LegacyInnerElement ([System.Xml.XmlElement]$gxAtt)
        $node = Import-GeneXusLegacyWrappedXmlNode -XmlText $xmlText

        $items.Add([pscustomobject]@{
            PackageSection = 'Attributes'
            RootTag        = 'Attribute'
            FolderType     = 'Attribute'
            LogicalName    = $logicalName
            NormalizedName = (& $NormalizeFileBaseName $logicalName)
            TypeGuid       = 'attribute-top-level'
            Guid           = ''
            LegacyElement  = 'GXAtt'
            CanonicalType  = 'Attribute'
            Node           = $node
        }) | Out-Null
    }

    $itemArray = @($items.ToArray())
    Test-GeneXusLegacyItemNameCollision -Items $itemArray
    return [pscustomobject]@{ Items = $itemArray }
}

function Get-GeneXusLegacyExportFileInventoryItems {
    <# Itens de inventario legado (typeStatus='known-legacy', rootKind sintetico, typeName nao-nulo). #>
    param(
        [xml]$XmlDocument,
        [object]$MergedCatalog,
        [object]$Registry
    )

    $sync = Get-GeneXusLegacyExportFileSyncItems -XmlDocument $XmlDocument -MergedCatalog $MergedCatalog -Registry $Registry
    $inventory = New-Object System.Collections.Generic.List[object]
    $index = 0
    foreach ($item in $sync.Items) {
        $index += 1
        $isAttribute = ($item.RootTag -eq 'Attribute')
        $inventory.Add([pscustomobject]@{
            index         = $index
            sourceBlock   = if ($isAttribute) { 'Attributes' } else { 'Objects' }
            rootKind      = if ($isAttribute) { 'Attribute' } else { 'Object' }
            type          = $item.CanonicalType
            typeName      = $item.CanonicalType
            typeGuid      = if ($isAttribute) { $null } else { $item.TypeGuid }
            typeStatus    = 'known-legacy'
            name          = $item.LogicalName
            guid          = $null
            legacyElement = $item.LegacyElement
            parent        = $null
            parentType    = $null
            identityKey   = "$($item.CanonicalType):$($item.LogicalName)"
        }) | Out-Null
    }
    return [pscustomobject]@{ Items = @($inventory.ToArray()); TotalCount = $inventory.Count }
}

function Convert-LegacyDeclaredDeltaKeyToCanonical {
    <#
        Normaliza a chave de delta declarado de um orphan para o token canonico, antes do set-match.
        Aceita '<Tag>:Nome' e 'gxlegacy/<Tag>:Nome' -> 'gxlegacy/<Tag>:Nome'. Equivalentes e
        chaves nao-orphan passam inalteradas.
    #>
    param(
        [string]$DeclaredKey,
        [object]$Registry
    )

    if ([string]::IsNullOrWhiteSpace($DeclaredKey)) { return $DeclaredKey }
    $sepIndex = $DeclaredKey.IndexOf(':')
    if ($sepIndex -lt 1) { return $DeclaredKey }
    $typePart = $DeclaredKey.Substring(0, $sepIndex)
    $namePart = $DeclaredKey.Substring($sepIndex + 1)

    $registryMap = Get-GeneXusLegacyRegistryElementMap -Registry $Registry
    foreach ($entry in $registryMap.GetEnumerator()) {
        $element = $entry.Value
        if ([string](Get-LegacyElementPropertyValue -Element $element -Name 'class') -ne 'orphan') { continue }
        $token = [string](Get-LegacyElementPropertyValue -Element $element -Name 'typeToken')
        if ($typePart -ieq $entry.Name -or $typePart -ieq $token) {
            return "${token}:${namePart}"
        }
    }
    return $DeclaredKey
}

function Get-GeneXusLegacyKmwBuildFromPackage {
    param([xml]$XmlDocument)
    $kmwNode = $XmlDocument.SelectSingleNode('/ExportFile/KMW')
    if ($null -eq $kmwNode) { return '' }
    $buildNode = $kmwNode.SelectSingleNode('Build')
    if ($null -ne $buildNode -and -not [string]::IsNullOrWhiteSpace($buildNode.InnerText)) { return $buildNode.InnerText.Trim() }
    $legacyBuildNode = $kmwNode.SelectSingleNode('MaxGxBuildSaved')
    if ($null -ne $legacyBuildNode -and -not [string]::IsNullOrWhiteSpace($legacyBuildNode.InnerText)) { return $legacyBuildNode.InnerText.Trim() }
    return ''
}

function Get-GeneXusLegacyModelNameFromPackage {
    param([xml]$XmlDocument)
    $node = $XmlDocument.SelectSingleNode('/ExportFile/Model/Name')
    if ($null -ne $node -and -not [string]::IsNullOrWhiteSpace($node.InnerText)) { return $node.InnerText.Trim() }
    return ''
}

function Get-GeneXusLegacyKmwPathFromPackage {
    param([xml]$XmlDocument)
    $node = $XmlDocument.SelectSingleNode('/ExportFile/KMW/Path')
    if ($null -ne $node -and -not [string]::IsNullOrWhiteSpace($node.InnerText)) { return $node.InnerText.Trim() }
    return ''
}
