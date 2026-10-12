#requires -Version 7.4

<#
.SYNOPSIS
Compara dois Panels GeneXus por shape compacto.

.DESCRIPTION
Usa Get-GeneXusObjectSummary.ps1 para comparar Object attrs, Pattern/Data
version, level/layout, controles, eventos serializados (nomeados, padrão,
de variável e Tap), cobertura action/event e flags estruturais sem imprimir
CDATA.

.PARAMETER LeftPath
XML/XPZ do primeiro Panel.

.PARAMETER RightPath
XML/XPZ do segundo Panel.

.PARAMETER LeftObjectName
Nome do objeto no primeiro insumo, quando necessário.

.PARAMETER RightObjectName
Nome do objeto no segundo insumo, quando necessário.

.PARAMETER AsJson
Retorna JSON estruturado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LeftPath,

    [Parameter(Mandatory = $true)]
    [string]$RightPath,

    [string]$LeftObjectName,

    [string]$RightObjectName,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Summary {
    param(
        [string]$Path,
        [string]$Name
    )

    $scriptPath = Join-Path $PSScriptRoot 'Get-GeneXusObjectSummary.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "Get-GeneXusObjectSummary.ps1 nao encontrado: $scriptPath"
    }
    $scriptParams = @{
        InputPath = $Path
        ObjectType = 'Panel'
        AsJson = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $scriptParams['ObjectName'] = $Name
    }
    $json = & $scriptPath @scriptParams
    return (($json | Out-String) | ConvertFrom-Json)
}

function Normalize-Array {
    param([object]$Value)

    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value) }
    return @($Value)
}

function Compare-Scalar {
    param(
        [string]$Name,
        [object]$Left,
        [object]$Right
    )

    return [ordered]@{
        name = $Name
        left = $Left
        right = $Right
        equal = ([string]$Left -eq [string]$Right)
    }
}

function Compare-List {
    param(
        [string]$Name,
        [object]$Left,
        [object]$Right
    )

    $leftValues = @(Normalize-Array -Value $Left | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $rightValues = @(Normalize-Array -Value $Right | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    $leftSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($value in $leftValues) { [void]$leftSet.Add($value) }
    $rightSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($value in $rightValues) { [void]$rightSet.Add($value) }
    $onlyLeft = @($leftValues | Where-Object { -not $rightSet.Contains($_) })
    $onlyRight = @($rightValues | Where-Object { -not $leftSet.Contains($_) })
    return [ordered]@{
        name = $Name
        equal = ($onlyLeft.Count -eq 0 -and $onlyRight.Count -eq 0)
        leftCount = $leftValues.Count
        rightCount = $rightValues.Count
        onlyLeft = $onlyLeft
        onlyRight = $onlyRight
    }
}

function Convert-MapToPairs {
    param([object]$Map)

    if ($null -eq $Map) { return @() }
    $pairs = [System.Collections.Generic.List[string]]::new()
    foreach ($prop in $Map.PSObject.Properties) {
        [void]$pairs.Add(('{0}={1}' -f $prop.Name, $prop.Value))
    }
    return @($pairs)
}

$left = Read-Summary -Path $LeftPath -Name $LeftObjectName
$right = Read-Summary -Path $RightPath -Name $RightObjectName
if ($null -eq $left.panel -or $null -eq $right.panel) {
    $hint = ''
    if (($null -ne $left.webpanel) -or ($null -ne $right.webpanel)) {
        $hint = ' Para WebPanel classico, use scripts/Get-GeneXusObjectSummary.ps1 (bloco webpanel) para inspecionar o shape; Compare-GeneXusPanelShape cobre apenas Panel.'
    }
    throw ('Ambos os objetos precisam ser Panel.' + $hint)
}

$scalarComparisons = @(
    (Compare-Scalar -Name 'typeGuid' -Left $left.typeGuid -Right $right.typeGuid),
    (Compare-Scalar -Name 'parentGuid' -Left $left.parentGuid -Right $right.parentGuid),
    (Compare-Scalar -Name 'parentType' -Left $left.parentType -Right $right.parentType),
    (Compare-Scalar -Name 'moduleGuid' -Left $left.moduleGuid -Right $right.moduleGuid),
    (Compare-Scalar -Name 'hasResponsiveSizes' -Left $left.panel.hasResponsiveSizes -Right $right.panel.hasResponsiveSizes),
    (Compare-Scalar -Name 'hasGridData' -Left $left.panel.hasGridData -Right $right.panel.hasGridData),
    (Compare-Scalar -Name 'hasActions' -Left $left.panel.hasActions -Right $right.panel.hasActions),
    (Compare-Scalar -Name 'hasOnClickEvent' -Left $left.panel.hasOnClickEvent -Right $right.panel.hasOnClickEvent),
    (Compare-Scalar -Name 'hasUnprovenTapEventSyntax' -Left $left.panel.actionEventCoverage.hasUnprovenTapEventSyntax -Right $right.panel.actionEventCoverage.hasUnprovenTapEventSyntax)
)

$listComparisons = @(
    (Compare-List -Name 'partTypes' -Left @($left.partTypes | ForEach-Object { $_.type }) -Right @($right.partTypes | ForEach-Object { $_.type })),
    (Compare-List -Name 'patternGuids' -Left $left.panel.patternGuids -Right $right.panel.patternGuids),
    (Compare-List -Name 'dataVersions' -Left $left.panel.dataVersions -Right $right.panel.dataVersions),
    (Compare-List -Name 'levelIds' -Left $left.panel.levelIds -Right $right.panel.levelIds),
    (Compare-List -Name 'layoutIds' -Left $left.panel.layoutIds -Right $right.panel.layoutIds),
    (Compare-List -Name 'layoutAttrs' -Left (Convert-MapToPairs -Map $left.panel.layoutAttrs) -Right (Convert-MapToPairs -Map $right.panel.layoutAttrs)),
    (Compare-List -Name 'firstTableAttrs' -Left (Convert-MapToPairs -Map $left.panel.firstTableAttrs) -Right (Convert-MapToPairs -Map $right.panel.firstTableAttrs)),
    (Compare-List -Name 'controlNames' -Left $left.panel.controls.names -Right $right.panel.controls.names),
    (Compare-List -Name 'controlTypes' -Left $left.panel.controls.types -Right $right.panel.controls.types),
    (Compare-List -Name 'gridDataNames' -Left $left.panel.gridDataNames -Right $right.panel.gridDataNames),
    (Compare-List -Name 'actionControls' -Left $left.panel.actionControls -Right $right.panel.actionControls),
    (Compare-List -Name 'onClickEvents' -Left $left.panel.onClickEvents -Right $right.panel.onClickEvents),
    (Compare-List -Name 'eventNames' -Left $left.panel.eventNames -Right $right.panel.eventNames),
    (Compare-List -Name 'namedEventNames' -Left $left.panel.namedEventNames -Right $right.panel.namedEventNames),
    (Compare-List -Name 'standardEventNames' -Left $left.panel.standardEventNames -Right $right.panel.standardEventNames),
    (Compare-List -Name 'variableEventNames' -Left $left.panel.variableEventNames -Right $right.panel.variableEventNames),
    (Compare-List -Name 'tapEventNames' -Left $left.panel.tapEventNames -Right $right.panel.tapEventNames),
    (Compare-List -Name 'onClickEventsWithoutNamedEvent' -Left $left.panel.actionEventCoverage.onClickEventsWithoutNamedEvent -Right $right.panel.actionEventCoverage.onClickEventsWithoutNamedEvent),
    (Compare-List -Name 'namedEventsWithoutAction' -Left $left.panel.actionEventCoverage.namedEventsWithoutAction -Right $right.panel.actionEventCoverage.namedEventsWithoutAction)
)

$all = @($scalarComparisons + $listComparisons)
$differences = @($all | Where-Object { -not $_.equal })
$result = [ordered]@{
    status = if ($differences.Count -eq 0) { 'same-shape' } else { 'different-shape' }
    left = [ordered]@{ path = (Resolve-Path -LiteralPath $LeftPath).Path; objectName = $left.name }
    right = [ordered]@{ path = (Resolve-Path -LiteralPath $RightPath).Path; objectName = $right.name }
    summary = [ordered]@{
        comparisonCount = $all.Count
        differenceCount = $differences.Count
    }
    scalarComparisons = $scalarComparisons
    listComparisons = $listComparisons
    differences = $differences
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 10
} else {
    [pscustomobject]$result
}
