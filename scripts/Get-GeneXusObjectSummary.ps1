#requires -Version 7.4

<#
.SYNOPSIS
Resume um objeto GeneXus XML/XPZ sem despejar CDATA extenso.

.DESCRIPTION
Aceita caminho para Object XML, ExportFile XML ou XPZ. Quando o insumo contem
mais de um objeto, use -ObjectName e opcionalmente -ObjectType. Para Panel, o
resumo inclui sinais compactos de level/layout, controles, gridData, actions e
eventos serializados em detail/@events, classificados em namedEventNames,
standardEventNames, variableEventNames e tapEventNames, com actionEventCoverage.
Para WebPanel classico, o resumo (bloco webpanel) inclui tables (tableType
Flex/Responsive e depth por tabela), controls com gxControlType resolvido pelo
catalogo gx-ucw-gxcontroltype-catalog.json, buttons nas duas formas (<action> e
<ucw> Button desserializado de PATTERN_ELEMENT_CUSTOM_PROPERTIES), eventNames e
um bloco coverage que declara o que foi lido e os limites conhecidos (controles
fora do GxMultiForm não são cobertos; gxControlType ausente do catalogo e
reportado em unknownUcwControlTypes, nunca omitido).

.PARAMETER InputPath
Caminho do XML ou XPZ.

.PARAMETER ObjectName
Nome do objeto quando InputPath contem pacote com múltiplos objetos.

.PARAMETER ObjectType
Tipo canonico ou GUID de Object/@type.

.PARAMETER AsJson
Retorna JSON estruturado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$ObjectName,

    [string]$ObjectType,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PanelObjectTypeGuid = 'd82625fd-5892-40b0-99c9-5c8559c197fc'
$WebPanelObjectTypeGuid = 'c9584656-94b6-4ccd-890f-332d11fc2c25'

function Read-TextFileFlexible {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    foreach ($encoding in @([System.Text.UTF8Encoding]::new($true), [System.Text.UnicodeEncoding]::new($false, $true))) {
        try { return $encoding.GetString($bytes) } catch { continue }
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-TypeGuidMap {
    $catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
    $map = @{}
    if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $catalog.types.PSObject.Properties) {
            $guid = $prop.Value.objectTypeGuid
            if (-not [string]::IsNullOrWhiteSpace($guid)) {
                $map[$prop.Name.ToLowerInvariant()] = $guid.ToLowerInvariant()
            }
        }
    }
    return $map
}

function Resolve-ObjectTypeGuid {
    param([string]$TypeValue)

    if ([string]::IsNullOrWhiteSpace($TypeValue)) { return $null }
    if ($TypeValue -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        return $TypeValue.ToLowerInvariant()
    }
    $map = Get-TypeGuidMap
    $key = $TypeValue.ToLowerInvariant()
    if ($map.ContainsKey($key)) { return $map[$key] }
    throw "ObjectType desconhecido no catalogo local: $TypeValue"
}

function ConvertTo-XmlDocument {
    param(
        [string]$XmlText,
        [string]$SourceLabel
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    try {
        $doc.LoadXml($XmlText)
        return $doc
    } catch {
        throw "XML malformado em ${SourceLabel}: $($_.Exception.Message)"
    }
}

function Find-ObjectInXml {
    param(
        [string]$XmlText,
        [string]$SourceLabel,
        [string]$Name,
        [string]$TypeGuid
    )

    $doc = ConvertTo-XmlDocument -XmlText $XmlText -SourceLabel $SourceLabel
    $root = $doc.DocumentElement
    $candidates = @()
    if ($root.LocalName -eq 'Object') {
        $candidates = @($root)
    } elseif ($root.LocalName -eq 'ExportFile') {
        $objectsNode = $root.SelectSingleNode('./Objects')
        if ($null -ne $objectsNode) {
            $candidates = @($objectsNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] -and $_.LocalName -eq 'Object' })
        }
    }

    if ([string]::IsNullOrWhiteSpace($Name) -and $candidates.Count -eq 1) {
        return [pscustomobject]@{ source = $SourceLabel; node = $candidates[0] }
    }

    foreach ($candidate in $candidates) {
        $candidateName = $candidate.GetAttribute('name')
        $candidateType = $candidate.GetAttribute('type').ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($Name) -and -not $candidateName.Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($TypeGuid) -and $candidateType -ne $TypeGuid) {
            continue
        }
        return [pscustomobject]@{ source = $SourceLabel; node = $candidate }
    }
    return $null
}

function Find-Object {
    param(
        [string]$Path,
        [string]$Name,
        [string]$TypeGuid
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()
    if ($extension -ne '.xpz' -and $extension -ne '.zip') {
        return Find-ObjectInXml -XmlText (Read-TextFileFlexible -Path $resolvedPath) -SourceLabel $resolvedPath -Name $Name -TypeGuid $TypeGuid
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedPath)
    try {
        foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' })) {
            $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
            try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
            try {
                $found = Find-ObjectInXml -XmlText $text -SourceLabel ($resolvedPath + '!' + $entry.FullName) -Name $Name -TypeGuid $TypeGuid
                if ($null -ne $found) { return $found }
            } catch {
                continue
            }
        }
    } finally {
        $zip.Dispose()
    }
    return $null
}

function Get-CDataTexts {
    param([System.Xml.XmlElement]$ObjectNode)

    $texts = [System.Collections.Generic.List[string]]::new()
    foreach ($node in @($ObjectNode.SelectNodes('.//Source|.//Data'))) {
        if (-not [string]::IsNullOrWhiteSpace($node.InnerText)) {
            [void]$texts.Add($node.InnerText)
        }
    }
    return @($texts)
}

function Get-UniqueRegexMatches {
    param(
        [string[]]$Texts,
        [string]$Pattern,
        [string]$GroupName
    )

    $set = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($text in $Texts) {
        foreach ($match in [regex]::Matches($text, $Pattern)) {
            $value = $match.Groups[$GroupName].Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                [void]$set.Add($value)
            }
        }
    }
    return @($set)
}

function Get-PanelDetailEventTexts {
    param([string[]]$Texts)

    $eventTexts = [System.Collections.Generic.List[string]]::new()
    foreach ($text in $Texts) {
        if ($text -notmatch '<(?:instance|Root|GxMultiForm)\b') {
            continue
        }
        $innerDoc = New-Object System.Xml.XmlDocument
        try {
            $innerDoc.LoadXml($text)
        } catch {
            continue
        }
        foreach ($detailNode in @($innerDoc.SelectNodes('//detail[@events]'))) {
            $eventsText = $detailNode.GetAttribute('events')
            if (-not [string]::IsNullOrWhiteSpace($eventsText)) {
                [void]$eventTexts.Add($eventsText)
            }
        }
    }
    return @($eventTexts)
}

function Get-ListDifference {
    param(
        [string[]]$Left,
        [string[]]$Right
    )

    $rightSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($value in @($Right)) {
        [void]$rightSet.Add($value)
    }
    return @($Left | Where-Object { -not $rightSet.Contains($_) } | Sort-Object -Unique)
}

function Convert-AttributeTextToMap {
    param([string]$AttributeText)

    $map = [ordered]@{}
    if ([string]::IsNullOrWhiteSpace($AttributeText)) {
        return $map
    }
    foreach ($match in [regex]::Matches($AttributeText, '(?<name>[A-Za-z_][A-Za-z0-9_.:-]*)="(?<value>[^"]*)"')) {
        $map[$match.Groups['name'].Value] = $match.Groups['value'].Value
    }
    return $map
}

function Get-FirstTagAttributes {
    param(
        [string[]]$Texts,
        [string]$TagName
    )

    $pattern = '<' + [regex]::Escape($TagName) + '\b(?<attrs>[^>]*)>'
    foreach ($text in $Texts) {
        $match = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            return (Convert-AttributeTextToMap -AttributeText $match.Groups['attrs'].Value)
        }
    }
    return [ordered]@{}
}

function Get-PanelSummary {
    param([System.Xml.XmlElement]$ObjectNode)

    $texts = @(Get-CDataTexts -ObjectNode $ObjectNode)
    $detailEventTexts = @(Get-PanelDetailEventTexts -Texts $texts)
    $behaviorTexts = @($texts + $detailEventTexts)
    $combined = $texts -join "`n"
    $levelIds = @(Get-UniqueRegexMatches -Texts $texts -Pattern '<(?:level|Level)\b[^>]*(?:id|guid)="(?<id>[^"]+)"' -GroupName 'id')
    $layoutIds = @(Get-UniqueRegexMatches -Texts $texts -Pattern '<(?:layout|Layout)\b[^>]*(?:id|guid)="(?<id>[^"]+)"' -GroupName 'id')
    $controlNames = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bcontrolName="(?<name>[^"]+)"' -GroupName 'name')
    $controlTypes = @(Get-UniqueRegexMatches -Texts $texts -Pattern '<(?<type>grid|Grid|action|Action|table|Table|ucw|attribute|Attribute|textblock|TextBlock)\b' -GroupName 'type')
    $gridDataNames = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bgridData(?:Name)?="(?<name>[^"]+)"' -GroupName 'name')
    $actionControls = @(Get-UniqueRegexMatches -Texts $texts -Pattern '<(?:action|Action)\b[^>]*(?:controlName|name)="(?<name>[^"]+)"' -GroupName 'name')
    $onClickEvents = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bonClickEvent="(?<name>[^"]+)"' -GroupName 'name')
    $normalizedOnClickEvents = @($onClickEvents | ForEach-Object { $_.Trim("'") } | Sort-Object -Unique)
    $namedEvents = @(Get-UniqueRegexMatches -Texts $behaviorTexts -Pattern "(?im)^\s*Event\s+'(?<name>[^']+)'" -GroupName 'name')
    $standardEvents = @(Get-UniqueRegexMatches -Texts $behaviorTexts -Pattern '(?im)^\s*Event\s+(?<name>Start|Refresh|Load|Enter|Back)\s*$' -GroupName 'name')
    $variableEvents = @(Get-UniqueRegexMatches -Texts $behaviorTexts -Pattern '(?im)^\s*Event\s+(?<name>&[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*(?:\(\))?)\s*$' -GroupName 'name')
    $tapEvents = @(Get-UniqueRegexMatches -Texts $behaviorTexts -Pattern '(?im)^\s*Event\s+(?<name>[A-Za-z_][A-Za-z0-9_]*\.Tap)\s*$' -GroupName 'name')
    $events = @($namedEvents + $standardEvents + $variableEvents | Sort-Object -Unique)
    $patternGuids = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bPattern="(?<guid>[0-9a-fA-F-]{36})"' -GroupName 'guid')
    $dataVersions = @(Get-UniqueRegexMatches -Texts $texts -Pattern '\bversion="(?<version>[^"]+)"' -GroupName 'version')
    $layoutAttrs = Get-FirstTagAttributes -Texts $texts -TagName 'layout'
    $firstTableAttrs = Get-FirstTagAttributes -Texts $texts -TagName 'table'

    return [ordered]@{
        levelIds = $levelIds
        layoutIds = $layoutIds
        layoutAttrs = $layoutAttrs
        firstTableAttrs = $firstTableAttrs
        levelLayoutPairCount = [Math]::Max($levelIds.Count, $layoutIds.Count)
        patternGuids = $patternGuids
        dataVersions = $dataVersions
        hasResponsiveSizes = ($combined -match '\bresponsiveSizes=')
        hasGridData = ($combined -match '\bgridData')
        hasActions = (($combined -match '<(?:action|Action)\b') -or ($actionControls.Count -gt 0))
        hasOnClickEvent = ($onClickEvents.Count -gt 0)
        controls = [ordered]@{
            names = $controlNames
            types = $controlTypes
            count = $controlNames.Count
        }
        gridDataNames = $gridDataNames
        actionControls = $actionControls
        onClickEvents = $onClickEvents
        eventNames = $events
        namedEventNames = $namedEvents
        standardEventNames = $standardEvents
        variableEventNames = $variableEvents
        tapEventNames = $tapEvents
        actionEventCoverage = [ordered]@{
            onClickEventsWithoutNamedEvent = @(Get-ListDifference -Left $normalizedOnClickEvents -Right $namedEvents)
            namedEventsWithoutAction = @(Get-ListDifference -Left $namedEvents -Right $normalizedOnClickEvents)
            variableEvents = $variableEvents
            hasUnprovenTapEventSyntax = ($tapEvents.Count -gt 0 -and $onClickEvents.Count -gt 0)
        }
        detailEventTextCount = $detailEventTexts.Count
        cdataTextCount = $texts.Count
    }
}

function Get-UcwControlTypeCatalog {
    $catalogPath = Join-Path $PSScriptRoot 'gx-ucw-gxcontroltype-catalog.json'
    $map = @{}
    if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $catalog.controls.PSObject.Properties) {
            $map[$prop.Name] = $prop.Value
        }
    }
    return $map
}

function ConvertFrom-PatternElementProperties {
    param([string]$PatternValue)

    # PatternValue chega já decodificado pelo parser XML do GxMultiForm (entidades resolvidas).
    $props = [ordered]@{}
    $failed = $false
    if ((-not [string]::IsNullOrWhiteSpace($PatternValue)) -and ($PatternValue -match '<Properties\b')) {
        $pdoc = New-Object System.Xml.XmlDocument
        try {
            $pdoc.LoadXml($PatternValue)
            foreach ($propertyNode in @($pdoc.SelectNodes('//Property'))) {
                $nameNode = $propertyNode.SelectSingleNode('Name')
                if (($null -eq $nameNode) -or [string]::IsNullOrWhiteSpace($nameNode.InnerText)) { continue }
                $valueNode = $propertyNode.SelectSingleNode('Value')
                $value = ''
                if ($null -ne $valueNode) { $value = $valueNode.InnerText }
                $props[$nameNode.InnerText] = $value
            }
        } catch {
            $failed = $true
        }
    }
    return [pscustomobject]@{ Props = $props; Failed = $failed }
}

function Get-WebPanelLayoutDocs {
    param([string[]]$Texts)

    $docs = [System.Collections.Generic.List[System.Xml.XmlDocument]]::new()
    $parseErrors = 0
    foreach ($text in $Texts) {
        if ($text -notmatch '<GxMultiForm\b') { continue }
        $doc = New-Object System.Xml.XmlDocument
        try {
            $doc.LoadXml($text)
            [void]$docs.Add($doc)
        } catch {
            $parseErrors++
        }
    }
    return [pscustomobject]@{ Docs = @($docs); ParseErrors = $parseErrors }
}

function Get-WebPanelSummary {
    param([System.Xml.XmlElement]$ObjectNode)

    $texts = @(Get-CDataTexts -ObjectNode $ObjectNode)
    $catalog = Get-UcwControlTypeCatalog
    $layout = Get-WebPanelLayoutDocs -Texts $texts
    $layoutDocs = @($layout.Docs)

    $structuralSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($t in @('GxMultiForm', 'Form', 'detail', 'layout', 'table', 'row', 'cell')) { [void]$structuralSet.Add($t) }

    $tables = [System.Collections.Generic.List[object]]::new()
    $controls = [System.Collections.Generic.List[object]]::new()
    $buttons = [System.Collections.Generic.List[object]]::new()
    $unknownSet = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $patternParseErrors = 0
    $formCount = 0

    foreach ($doc in $layoutDocs) {
        $formCount += @($doc.SelectNodes('//Form')).Count

        foreach ($tableNode in @($doc.SelectNodes('//table'))) {
            $responsiveSizes = $tableNode.GetAttribute('responsiveSizes')
            $responsiveNonEmpty = (-not [string]::IsNullOrWhiteSpace($responsiveSizes)) -and ($responsiveSizes -ne '[]')
            [void]$tables.Add([ordered]@{
                controlName = $tableNode.GetAttribute('controlName')
                tableType = $tableNode.GetAttribute('tableType')
                responsiveSizesNonEmpty = $responsiveNonEmpty
                depth = @($tableNode.SelectNodes('ancestor::table')).Count
            })
        }

        foreach ($node in @($doc.SelectNodes('//*'))) {
            $tag = $node.LocalName
            if ($structuralSet.Contains($tag)) { continue }

            if ($tag -ieq 'ucw') {
                $gxType = $node.GetAttribute('gxControlType')
                $resolvedName = $null
                $isButton = $false
                if ((-not [string]::IsNullOrWhiteSpace($gxType)) -and $catalog.ContainsKey($gxType)) {
                    $entry = $catalog[$gxType]
                    $resolvedName = $entry.name
                    $isButton = [bool]$entry.isButton
                } elseif (-not [string]::IsNullOrWhiteSpace($gxType)) {
                    [void]$unknownSet.Add($gxType)
                }

                $parsed = ConvertFrom-PatternElementProperties -PatternValue $node.GetAttribute('PATTERN_ELEMENT_CUSTOM_PROPERTIES')
                if ($parsed.Failed) { $patternParseErrors++ }
                $props = $parsed.Props
                $ucwControlName = ''
                if ($props.Contains('ControlName')) { $ucwControlName = $props['ControlName'] }

                [void]$controls.Add([ordered]@{
                    tag = $tag
                    name = $ucwControlName
                    gxControlType = $gxType
                    resolvedType = $resolvedName
                })

                if ($isButton) {
                    $event = ''
                    if ($props.Contains('Event')) { $event = ([string]$props['Event']).Trim("'") }
                    $caption = ''
                    if ($props.Contains('CaptionExpression')) { $caption = $props['CaptionExpression'] }
                    [void]$buttons.Add([ordered]@{
                        form = 'ucw-button'
                        controlName = $ucwControlName
                        event = $event
                        caption = $caption
                    })
                }
                continue
            }

            $controlName = $node.GetAttribute('controlName')
            $name = $controlName
            if ([string]::IsNullOrWhiteSpace($name) -and ($tag -ieq 'data')) {
                $name = $node.GetAttribute('attribute')
            }
            if ((-not [string]::IsNullOrWhiteSpace($name)) -or ($tag -ieq 'action')) {
                [void]$controls.Add([ordered]@{
                    tag = $tag
                    name = $name
                    gxControlType = $null
                    resolvedType = $null
                })
            }

            if ($tag -ieq 'action') {
                [void]$buttons.Add([ordered]@{
                    form = 'action'
                    controlName = $controlName
                    event = ([string]$node.GetAttribute('onClickEvent')).Trim("'")
                    caption = $node.GetAttribute('caption')
                })
            }
        }
    }

    $namedEvents = @(Get-UniqueRegexMatches -Texts $texts -Pattern "(?im)^\s*Event\s+'(?<name>[^']+)'" -GroupName 'name')
    $standardEvents = @(Get-UniqueRegexMatches -Texts $texts -Pattern '(?im)^\s*Event\s+(?<name>Start|Refresh|Load|Enter|Back)\s*$' -GroupName 'name')
    $variableEvents = @(Get-UniqueRegexMatches -Texts $texts -Pattern '(?im)^\s*Event\s+(?<name>&[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*(?:\(\))?)\s*$' -GroupName 'name')
    $events = @($namedEvents + $standardEvents + $variableEvents | Sort-Object -Unique)
    $buttonEvents = @(@($buttons) | ForEach-Object { $_['event'] } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)

    return [ordered]@{
        tableCount = $tables.Count
        tables = @($tables)
        controlCount = $controls.Count
        controls = @($controls)
        buttonCount = $buttons.Count
        buttons = @($buttons)
        eventNames = $events
        namedEventNames = $namedEvents
        standardEventNames = $standardEvents
        variableEventNames = $variableEvents
        buttonEventCoverage = [ordered]@{
            buttonEventsWithoutHandler = @(Get-ListDifference -Left $buttonEvents -Right $events)
        }
        coverage = [ordered]@{
            layoutDocsParsed = $layoutDocs.Count
            layoutFormsParsed = $formCount
            layoutParseErrors = $layout.ParseErrors
            patternParseErrors = $patternParseErrors
            unknownUcwControlTypes = @($unknownSet)
            cdataTextCount = $texts.Count
            notes = 'Enumeracao via parse estrutural do(s) GxMultiForm no Part de layout. Nao cobre controles fora do GxMultiForm (ex.: WebForm/HTML, Conditions em Part propria). Eventos derivados por regex sobre Source/Data; categorias seguem o resumo de Panel e podem nao cobrir todas as formas (ex.: eventos de grid NomeGrid.Load).'
        }
    }
}

function New-Summary {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$Source
    )

    $parts = @($ObjectNode.SelectNodes('./Part') | ForEach-Object {
        [ordered]@{
            type = $_.GetAttribute('type')
            hasSource = ($null -ne $_.SelectSingleNode('./Source'))
            hasData = ($null -ne $_.SelectSingleNode('./Data'))
        }
    })
    $typeGuid = $ObjectNode.GetAttribute('type')
    $summary = [ordered]@{
        source = $Source
        name = $ObjectNode.GetAttribute('name')
        typeGuid = $typeGuid
        guid = $ObjectNode.GetAttribute('guid')
        parent = $ObjectNode.GetAttribute('parent')
        parentGuid = $ObjectNode.GetAttribute('parentGuid')
        parentType = $ObjectNode.GetAttribute('parentType')
        moduleGuid = $ObjectNode.GetAttribute('moduleGuid')
        partCount = $parts.Count
        partTypes = @($parts)
        panel = $null
        webpanel = $null
    }
    if ($typeGuid.ToLowerInvariant() -eq $PanelObjectTypeGuid) {
        $summary.panel = Get-PanelSummary -ObjectNode $ObjectNode
    } elseif ($typeGuid.ToLowerInvariant() -eq $WebPanelObjectTypeGuid) {
        $summary.webpanel = Get-WebPanelSummary -ObjectNode $ObjectNode
    }
    return $summary
}

$resolvedTypeGuid = Resolve-ObjectTypeGuid -TypeValue $ObjectType
$found = Find-Object -Path $InputPath -Name $ObjectName -TypeGuid $resolvedTypeGuid
if ($null -eq $found) {
    throw "Objeto nao encontrado no insumo informado."
}

$summary = New-Summary -ObjectNode $found.node -Source $found.source
if ($AsJson) {
    $summary | ConvertTo-Json -Depth 10
} else {
    [pscustomobject]$summary
}
