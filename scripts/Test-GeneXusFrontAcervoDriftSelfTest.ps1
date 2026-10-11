#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do gate 9-FD para drift frente-vs-acervo e fidelidade textual parcial.

.DESCRIPTION
    Cobre lastUpdate, Object/@type, assinatura funcional de tipo de Attribute por
    GUID e a protecao textual parcial contra remocao forte de trailing whitespace
    herdado, incluindo o finding informativo de falha de leitura UTF-8 comparavel.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$gateScript = Join-Path $scriptDir 'Test-GeneXusFrontAcervoDrift.ps1'
$encodingSupportPath = Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1'

if (-not (Test-Path -LiteralPath $gateScript -PathType Leaf)) {
    throw "Gate script not found: $gateScript"
}
if (-not (Test-Path -LiteralPath $encodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $encodingSupportPath"
}
. $encodingSupportPath

function Assert-True {
    param(
        [bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw "ASSERT_FAILED: $Message"
    }
}

function Assert-PropertyAbsent {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Assert-True ($null -eq $Object.PSObject.Properties[$PropertyName]) $Message
}

function Write-Utf8NoBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
}

function Write-Utf8BomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($true))
}

function Write-Utf16LeBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UnicodeEncoding]::new($false, $true))
}

function New-FixtureObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeGuid,
        [Parameter(Mandatory = $true)][string]$LastUpdate
    )

    return @"
<Object type="$TypeGuid" name="$Name" guid="$Guid" fullyQualifiedName="$Name" lastUpdate="$LastUpdate">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>$Name</Value>
    </Property>
  </Properties>
  <Source><![CDATA[]]></Source>
</Object>
"@
}

function New-TextualFidelityFixtureObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeGuid,
        [Parameter(Mandatory = $true)][string]$LastUpdate,
        [int]$TrailingWhitespaceLines = 0,
        [switch]$TrimTrailingWhitespace,
        [int]$FunctionalChanges = 0,
        [int]$StableLines = 0
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $rootLine = "<Object type=""$TypeGuid"" name=""$Name"" guid=""$Guid"" fullyQualifiedName=""$Name"" lastUpdate=""$LastUpdate"">"
    if ($TrailingWhitespaceLines -gt 0 -and -not $TrimTrailingWhitespace) { $rootLine += '  ' }
    $lines.Add($rootLine) | Out-Null
    $lines.Add('  <Properties>') | Out-Null
    $lines.Add('    <Property>') | Out-Null
    $lines.Add('      <Name>Name</Name>') | Out-Null
    $lines.Add("      <Value>$Name</Value>") | Out-Null
    $lines.Add('    </Property>') | Out-Null
    for ($i = 1; $i -le $TrailingWhitespaceLines; $i++) {
        $value = "      <Property><Name>P$i</Name><Value>V$i</Value></Property>"
        if (-not $TrimTrailingWhitespace) { $value += '  ' }
        $lines.Add($value) | Out-Null
    }
    for ($i = 1; $i -le $FunctionalChanges; $i++) {
        $lines.Add("      <Property><Name>Func$i</Name><Value>$Name-$i</Value></Property>") | Out-Null
    }
    for ($i = 1; $i -le $StableLines; $i++) {
        $lines.Add("      <Property><Name>Stable$i</Name><Value>Stable$i</Value></Property>") | Out-Null
    }
    $lines.Add('  </Properties>') | Out-Null
    $lines.Add('  <Source><![CDATA[]]></Source>') | Out-Null
    $lines.Add('</Object>') | Out-Null
    return ($lines -join "`n") + "`n"
}

function New-FixtureAttributeXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeValue,
        [string]$Length = '10',
        [string]$MaxLength = '10'
    )

    return @"
<Attribute name="$Name" fullyQualifiedName="$Name" guid="$Guid">
  <Properties>
    <Property><Name>Name</Name><Value>$Name</Value></Property>
    <Property><Name>ATTCUSTOMTYPE</Name><Value>$TypeValue</Value></Property>
    <Property><Name>Length</Name><Value>$Length</Value></Property>
    <Property><Name>AttMaxLen</Name><Value>$MaxLength</Value></Property>
  </Properties>
</Attribute>
"@
}

function Write-FixtureAttribute {
    param(
        [Parameter(Mandatory = $true)][string]$Folder,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeValue,
        [string]$Length = '10',
        [string]$MaxLength = '10'
    )

    [void](New-Item -ItemType Directory -Path $Folder -Force)
    Write-Utf8NoBomText -Path (Join-Path $Folder "$Name.xml") -Content (New-FixtureAttributeXml -Name $Name -Guid $Guid -TypeValue $TypeValue -Length $Length -MaxLength $MaxLength)
}

function Write-FixtureObjectContent {
    param(
        [Parameter(Mandatory = $true)][string]$Folder,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$Utf8Bom
    )

    [void](New-Item -ItemType Directory -Path $Folder -Force)
    $path = Join-Path $Folder "$Name.xml"
    if ($Utf8Bom) {
        Write-Utf8BomText -Path $path -Content $Content
    } else {
        Write-Utf8NoBomText -Path $path -Content $Content
    }
}

function Write-FixtureObject {
    param(
        [Parameter(Mandatory = $true)][string]$Folder,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeGuid,
        [Parameter(Mandatory = $true)][string]$LastUpdate
    )

    [void](New-Item -ItemType Directory -Path $Folder -Force)
    Write-Utf8NoBomText -Path (Join-Path $Folder "$Name.xml") -Content (New-FixtureObjectXml -Name $Name -Guid $Guid -TypeGuid $TypeGuid -LastUpdate $LastUpdate)
}

function New-FixtureDomainXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$LastUpdate,
        [string]$TypeGuid = '00972a17-9975-449e-aab1-d26165d51393',
        [System.Collections.IDictionary]$RootAttributes = @{},
        [object[]]$Properties = @(),
        [switch]$OmitNameProperty,
        [switch]$OmitRootName
    )

    $document = [System.Xml.XmlDocument]::new()
    $root = $document.CreateElement('Object')
    [void]$document.AppendChild($root)
    $attributes = [ordered]@{
        type = $TypeGuid
        name = $Name
        guid = $Guid
        fullyQualifiedName = $Name
        lastUpdate = $LastUpdate
    }
    foreach ($key in $RootAttributes.Keys) { $attributes[[string]$key] = $RootAttributes[$key] }
    foreach ($key in $attributes.Keys) {
        if ($key -ceq 'name' -and $OmitRootName) { continue }
        if ($null -ne $attributes[$key]) { $root.SetAttribute([string]$key, [string]$attributes[$key]) }
    }

    $rootProperties = $document.CreateElement('Properties')
    [void]$root.AppendChild($rootProperties)
    if (-not $OmitNameProperty) {
        $nameProperty = $document.CreateElement('Property')
        $nameNode = $document.CreateElement('Name')
        $nameNode.InnerText = 'Name'
        $valueNode = $document.CreateElement('Value')
        $valueNode.InnerText = $Name
        [void]$nameProperty.AppendChild($nameNode)
        [void]$nameProperty.AppendChild($valueNode)
        [void]$rootProperties.AppendChild($nameProperty)
    }

    $partContainers = [System.Collections.Generic.Dictionary[string, System.Xml.XmlElement]]::new([System.StringComparer]::Ordinal)
    foreach ($property in $Properties) {
        $container = $rootProperties
        $partType = if ($property.Contains('PartType')) { [string]$property['PartType'] } else { '' }
        $containerKind = if ($property.Contains('Container')) { [string]$property['Container'] } else { 'Object' }
        if ($containerKind -ceq 'Part') {
            if (-not $partContainers.ContainsKey($partType)) {
                $part = $document.CreateElement('Part')
                $part.SetAttribute('type', $partType)
                [void]$root.AppendChild($part)
                $partProperties = $document.CreateElement('Properties')
                [void]$part.AppendChild($partProperties)
                $partContainers.Add($partType, $partProperties)
            }
            $container = $partContainers[$partType]
        }
        $propertyNode = $document.CreateElement('Property')
        $missingName = $property.Contains('MissingName') -and [bool]$property['MissingName']
        $missingValue = $property.Contains('MissingValue') -and [bool]$property['MissingValue']
        if (-not $missingName) {
            $nameNode = $document.CreateElement('Name')
            $nameNode.InnerText = [string]$property.Name
            [void]$propertyNode.AppendChild($nameNode)
        }
        if (-not $missingValue) {
            $valueNode = $document.CreateElement('Value')
            $valueNode.InnerText = [string]$property.Value
            [void]$propertyNode.AppendChild($valueNode)
        }
        [void]$container.AppendChild($propertyNode)
    }
    return $document.OuterXml
}

function New-DomainGateCase {
    param(
        [Parameter(Mandatory = $true)][string]$CaseName,
        [Parameter(Mandatory = $true)][string]$FrontXml,
        [AllowNull()][string]$BaselineXml,
        [string]$FrontFileName = 'DomainFront.xml',
        [string]$BaselineFileName = 'DomainBaseline.xml'
    )

    $caseRoot = Join-Path $tempRoot $CaseName
    $frontFolder = Join-Path $caseRoot 'front'
    $acervoFolder = Join-Path $caseRoot 'acervo'
    [void](New-Item -ItemType Directory -Path $frontFolder -Force)
    [void](New-Item -ItemType Directory -Path (Join-Path $acervoFolder 'Domain') -Force)
    Write-FixtureObjectContent -Folder $frontFolder -Name ([System.IO.Path]::GetFileNameWithoutExtension($FrontFileName)) -Content $FrontXml
    if (-not [string]::IsNullOrEmpty($BaselineXml)) {
        Write-FixtureObjectContent -Folder (Join-Path $acervoFolder 'Domain') -Name ([System.IO.Path]::GetFileNameWithoutExtension($BaselineFileName)) -Content $BaselineXml
    }
    return [pscustomobject]@{ root = $caseRoot; front = $frontFolder; acervo = $acervoFolder; frontFile = (Join-Path $frontFolder $FrontFileName) }
}

function Invoke-DomainGateCase {
    param(
        [Parameter(Mandatory = $true)]$Case,
        [string]$GatePath = $gateScript,
        [AllowNull()][string]$ApprovedPath
    )

    if ($PSBoundParameters.ContainsKey('ApprovedPath')) {
        return (& $GatePath -FrontFolder $Case.front -AcervoFolder $Case.acervo -ApprovedDomainChangesPath $ApprovedPath -AsJson | ConvertFrom-Json)
    }
    return (& $GatePath -FrontFolder $Case.front -AcervoFolder $Case.acervo -AsJson | ConvertFrom-Json)
}

function New-DomainApprovalFromChange {
    param([Parameter(Mandatory = $true)]$Change)
    $approval = [ordered]@{
        objectGuid = [string]$Change.objectGuid
        field = [string]$Change.field
        locationKind = [string]$Change.locationKind
        container = [string]$Change.container
        partType = [string]$Change.partType
        component = [string]$Change.component
        enumStoredValue = [string]$Change.enumStoredValue
        oldState = [string]$Change.oldState
        oldValue = $Change.oldValue
        newState = [string]$Change.newState
        newValue = $Change.newValue
    }
    return $approval
}

function Write-DomainApprovalFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [object[]]$Approvals = @()
    )
    $envelope = [ordered]@{ kind = 'domain-drift-approvals'; schemaVersion = 1; approvals = @($Approvals) }
    Write-Utf8NoBomText -Path $Path -Content (ConvertTo-Json -InputObject $envelope -Depth 12)
}

function New-DomainGateHarness {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][string]$CatalogText,
        [switch]$OmitCatalog
    )

    $sourceScripts = Split-Path -Parent $gateScript
    $targetScripts = Join-Path $tempRoot 'domain-gate-harnesses' $Name 'scripts'
    [void](New-Item -ItemType Directory -Path $targetScripts -Force)
    foreach ($file in @('Test-GeneXusFrontAcervoDrift.ps1', 'GeneXusObjectTypeDriftSupport.ps1', 'GeneXusDomainDriftSupport.ps1')) {
        Copy-Item -LiteralPath (Join-Path $sourceScripts $file) -Destination (Join-Path $targetScripts $file) -Force
    }
    if (-not $OmitCatalog) {
        $catalogSource = Join-Path $sourceScripts 'gx-object-type-catalog.json'
        $content = if ($null -ne $CatalogText) { $CatalogText } else { Get-Content -Raw -LiteralPath $catalogSource }
        Write-Utf8NoBomText -Path (Join-Path $targetScripts 'gx-object-type-catalog.json') -Content $content
    }
    return Join-Path $targetScripts 'Test-GeneXusFrontAcervoDrift.ps1'
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-front-acervo-drift-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))

try {
    $procedureTypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
    $webPanelTypeGuid = '7a7686a8-90de-4598-9406-014bcbcf3d82'
    $guid = '11111111-1111-1111-1111-111111111111'
    $oldStamp = '2026-01-01T00:00:00.0000000Z'
    $newStamp = '2026-01-01T00:02:00.0000000Z'

    $front1 = Join-Path $tempRoot 'case1-front'
    $acervo1 = Join-Path $tempRoot 'case1-acervo'
    Write-FixtureObject -Folder $front1 -Name 'ObjDrift' -Guid $guid -TypeGuid $webPanelTypeGuid -LastUpdate $newStamp
    Write-FixtureObject -Folder (Join-Path $acervo1 'Procedure') -Name 'ObjDrift' -Guid $guid -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp
    $r1 = & $gateScript -FrontFolder $front1 -AcervoFolder $acervo1 -AsJson | ConvertFrom-Json
    Assert-True ($r1.status -eq 'fail') "Caso 1: status esperado fail; obtido $($r1.status)"
    $r1Codes = @($r1.findings | ForEach-Object { $_.code })
    Assert-True ($r1Codes -contains 'front-object-type-drift') 'Caso 1: finding front-object-type-drift ausente.'
    Assert-True ($r1Codes -notcontains 'front-newer-than-acervo') 'Caso 1: front-newer-than-acervo deveria ser suprimido quando ha drift fatal de tipo.'
    $typeFinding = @($r1.findings | Where-Object { $_.code -eq 'front-object-type-drift' } | Select-Object -First 1)[0]
    Assert-True ($typeFinding.matchBasis -eq 'guid') "Caso 1: matchBasis esperado guid; obtido $($typeFinding.matchBasis)"
    Assert-True ($typeFinding.objectGuid -eq $guid) "Caso 1: objectGuid normalizado esperado $guid; obtido $($typeFinding.objectGuid)"
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$typeFinding.message)) 'Caso 1: finding fatal deveria preservar message.'
    Assert-True ($typeFinding.acervoPath -eq 'Procedure/ObjDrift.xml') "Caso 1: acervoPath relativo inesperado: $($typeFinding.acervoPath)"
    Assert-True ($typeFinding.frontObjectTypeNormalized -eq $webPanelTypeGuid) 'Caso 1: tipo normalizado da frente nao preservado.'
    Assert-True ($typeFinding.acervoObjectTypeNormalized -eq $procedureTypeGuid) 'Caso 1: tipo normalizado do acervo nao preservado.'
    Assert-PropertyAbsent -Object $typeFinding -PropertyName 'acervoFile' -Message 'Caso 1: finding novo de type drift nao deve emitir acervoFile.'
    foreach ($legacyName in @('frontGuid', 'baselinePath', 'candidateBaselinePaths', 'baselineObjectType', 'baselineObjectTypeNormalized')) {
        Assert-PropertyAbsent -Object $typeFinding -PropertyName $legacyName -Message "Caso 1: finding novo de type drift nao deve emitir $legacyName."
    }

    $front2 = Join-Path $tempRoot 'case2-front'
    $acervo2 = Join-Path $tempRoot 'case2-acervo'
    Write-FixtureObject -Folder $front2 -Name 'ObjDriftOld' -Guid $guid -TypeGuid $webPanelTypeGuid -LastUpdate $oldStamp
    Write-FixtureObject -Folder (Join-Path $acervo2 'Procedure') -Name 'ObjDriftOld' -Guid $guid -TypeGuid $procedureTypeGuid -LastUpdate $newStamp
    $r2 = & $gateScript -FrontFolder $front2 -AcervoFolder $acervo2 -AsJson | ConvertFrom-Json
    $r2Codes = @($r2.findings | ForEach-Object { $_.code })
    Assert-True ($r2Codes -contains 'front-object-type-drift') 'Caso 2: drift de tipo deveria coexistir com lastUpdate antigo.'
    Assert-True ($r2Codes -contains 'front-older-than-acervo') 'Caso 2: front-older-than-acervo deveria ser preservado.'

    $front3 = Join-Path $tempRoot 'case3-front'
    $acervo3 = Join-Path $tempRoot 'case3-acervo'
    Write-FixtureObject -Folder $front3 -Name 'ObjAmbiguo' -Guid $guid -TypeGuid $webPanelTypeGuid -LastUpdate $newStamp
    Write-FixtureObject -Folder (Join-Path $acervo3 'ProcedureA') -Name 'ObjAmbiguo' -Guid $guid -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp
    Write-FixtureObject -Folder (Join-Path $acervo3 'ProcedureB') -Name 'ObjAmbiguoCopia' -Guid $guid -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp
    $r3 = & $gateScript -FrontFolder $front3 -AcervoFolder $acervo3 -AsJson | ConvertFrom-Json
    $r3Codes = @($r3.findings | ForEach-Object { $_.code })
    Assert-True ($r3Codes -contains 'front-object-type-drift-ambiguous-acervo') 'Caso 3: ambiguidade por GUID deveria gerar diagnostico nao fatal.'
    Assert-True ($r3Codes -notcontains 'front-object-type-drift') 'Caso 3: ambiguidade nao deveria afirmar drift fatal.'
    Assert-True ($r3Codes -notcontains 'front-textual-fidelity-info') 'Caso 3: GUID ambiguo nao deve emitir front-textual-fidelity-info.'
    $ambiguousFinding = @($r3.findings | Where-Object { $_.code -eq 'front-object-type-drift-ambiguous-acervo' } | Select-Object -First 1)[0]
    Assert-True ($ambiguousFinding.severity -eq 'info') "Caso 3: ambiguidade deveria ser info; obtido $($ambiguousFinding.severity)."
    Assert-True ($ambiguousFinding.objectGuid -eq $guid) "Caso 3: objectGuid normalizado esperado $guid; obtido $($ambiguousFinding.objectGuid)"
    Assert-True ($ambiguousFinding.matchBasis -eq 'guid-ambiguous') "Caso 3: matchBasis esperado guid-ambiguous; obtido $($ambiguousFinding.matchBasis)."
    Assert-True ((@($ambiguousFinding.candidateAcervoPaths)).Count -eq 2) 'Caso 3: candidateAcervoPaths deveria ter dois candidatos.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$ambiguousFinding.message)) 'Caso 3: ambiguidade deveria preservar message.'
    Assert-PropertyAbsent -Object $ambiguousFinding -PropertyName 'acervoObjectType' -Message 'Caso 3: ambiguidade nao deve escolher acervoObjectType arbitrario.'
    Assert-PropertyAbsent -Object $ambiguousFinding -PropertyName 'acervoObjectTypeNormalized' -Message 'Caso 3: ambiguidade nao deve escolher acervoObjectTypeNormalized arbitrario.'
    foreach ($legacyName in @('frontGuid', 'baselinePath', 'candidateBaselinePaths', 'baselineObjectType', 'baselineObjectTypeNormalized')) {
        Assert-PropertyAbsent -Object $ambiguousFinding -PropertyName $legacyName -Message "Caso 3: ambiguidade nao deve emitir $legacyName."
    }

    $front4 = Join-Path $tempRoot 'case4-front'
    $acervo4 = Join-Path $tempRoot 'case4-acervo'
    Write-FixtureObject -Folder $front4 -Name 'ObjNominal' -Guid '22222222-2222-2222-2222-222222222222' -TypeGuid $webPanelTypeGuid -LastUpdate $newStamp
    Write-FixtureObject -Folder (Join-Path $acervo4 'Procedure') -Name 'ObjNominal' -Guid '33333333-3333-3333-3333-333333333333' -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp
    $r4 = & $gateScript -FrontFolder $front4 -AcervoFolder $acervo4 -AsJson | ConvertFrom-Json
    $r4Codes = @($r4.findings | ForEach-Object { $_.code })
    Assert-True ($r4Codes -notcontains 'front-object-type-drift') 'Caso 4: match nominal sem GUID igual nao deve gerar drift de tipo.'

    $front5 = Join-Path $tempRoot 'case5-front'
    $acervo5 = Join-Path $tempRoot 'case5-acervo'
    $obj5 = 'ObjTrimGlobal'
    $guid5 = '55555555-5555-5555-5555-555555555555'
    $acervo5Xml = New-TextualFidelityFixtureObjectXml -Name $obj5 -Guid $guid5 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -TrailingWhitespaceLines 40
    $front5Xml = New-TextualFidelityFixtureObjectXml -Name $obj5 -Guid $guid5 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -TrailingWhitespaceLines 40 -TrimTrailingWhitespace -FunctionalChanges 2
    Write-FixtureObjectContent -Folder $front5 -Name $obj5 -Content $front5Xml
    Write-FixtureObjectContent -Folder (Join-Path $acervo5 'Procedure') -Name $obj5 -Content $acervo5Xml
    $r5 = & $gateScript -FrontFolder $front5 -AcervoFolder $acervo5 -AsJson | ConvertFrom-Json
    Assert-True ($r5.objectsScanned -eq 1) "Caso 5: objectsScanned esperado 1; obtido $($r5.objectsScanned)"
    Assert-True ($r5.status -eq 'fail') "Caso 5: status fail esperado; obtido $($r5.status)"
    $textFinding5 = @($r5.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' } | Select-Object -First 1)
    Assert-True ($textFinding5.Count -eq 1) 'Caso 5: finding de trim global forte ausente.'
    Assert-True ($textFinding5[0].classification -eq 'trim-removal-churn') "Caso 5: classification inesperado: $($textFinding5[0].classification)"
    Assert-True ($textFinding5[0].whitespaceTrimPairCount -ge 40) "Caso 5: contagem de trim inesperada: $($textFinding5[0].whitespaceTrimPairCount)"
    Assert-True ($null -ne $textFinding5[0].functionalChangedLineEstimate) 'Caso 5: functionalChangedLineEstimate ausente.'
    Assert-True ($textFinding5[0].acervoLineCount -gt 0) "Caso 5: acervoLineCount inesperado: $($textFinding5[0].acervoLineCount)"
    Assert-True ($null -ne $textFinding5[0].thresholds) 'Caso 5: thresholds ausente.'
    Assert-True ($textFinding5[0].thresholds.MinWhitespaceChurnLines -eq 25) "Caso 5: thresholds.MinWhitespaceChurnLines inesperado: $($textFinding5[0].thresholds.MinWhitespaceChurnLines)"
    Assert-True ($textFinding5[0].thresholds.ChurnDominanceFactor -eq 3) "Caso 5: thresholds.ChurnDominanceFactor inesperado: $($textFinding5[0].thresholds.ChurnDominanceFactor)"
    Assert-True ([double]$textFinding5[0].thresholds.GlobalTrimRatio -eq 0.50) "Caso 5: thresholds.GlobalTrimRatio inesperado: $($textFinding5[0].thresholds.GlobalTrimRatio)"

    $front6 = Join-Path $tempRoot 'case6-front'
    $acervo6 = Join-Path $tempRoot 'case6-acervo'
    $obj6 = 'ObjTrimGlobalRatio'
    $guid6 = '66666666-6666-6666-6666-666666666666'
    $acervo6Xml = New-TextualFidelityFixtureObjectXml -Name $obj6 -Guid $guid6 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -TrailingWhitespaceLines 40
    $front6Xml = New-TextualFidelityFixtureObjectXml -Name $obj6 -Guid $guid6 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -TrailingWhitespaceLines 40 -TrimTrailingWhitespace -FunctionalChanges 20
    Write-FixtureObjectContent -Folder $front6 -Name $obj6 -Content $front6Xml
    Write-FixtureObjectContent -Folder (Join-Path $acervo6 'Procedure') -Name $obj6 -Content $acervo6Xml
    $r6 = & $gateScript -FrontFolder $front6 -AcervoFolder $acervo6 -AsJson | ConvertFrom-Json
    Assert-True ($r6.objectsScanned -eq 1) "Caso 6: objectsScanned esperado 1; obtido $($r6.objectsScanned)"
    Assert-True (@($r6.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' }).Count -eq 1) 'Caso 6: trim forte por proporcao do acervo deveria falhar.'

    $front7 = Join-Path $tempRoot 'case7-front'
    $acervo7 = Join-Path $tempRoot 'case7-acervo'
    $obj7 = 'ObjSemBaseline'
    [void](New-Item -ItemType Directory -Path $acervo7 -Force)
    Write-FixtureObject -Folder $front7 -Name $obj7 -Guid '77777777-7777-7777-7777-777777777777' -TypeGuid $procedureTypeGuid -LastUpdate $newStamp
    $r7 = & $gateScript -FrontFolder $front7 -AcervoFolder $acervo7 -AsJson | ConvertFrom-Json
    $r7Codes = @($r7.findings | ForEach-Object { $_.code })
    Assert-True ($r7.status -ne 'fail') "Caso 7: objeto novo sem baseline nao deveria falhar; obtido $($r7.status)"
    Assert-True ($r7Codes -contains 'front-only-new-object') 'Caso 7: front-only-new-object esperado.'
    Assert-True ($r7Codes -notcontains 'front-textual-fidelity-info') 'Caso 7: objeto novo sem baseline nao deve emitir finding textual extra.'

    $front8 = Join-Path $tempRoot 'case8-front'
    $acervo8 = Join-Path $tempRoot 'case8-acervo'
    $obj8 = 'ObjDeltaDominante'
    $guid8 = '88888888-8888-8888-8888-888888888888'
    $acervo8Xml = New-TextualFidelityFixtureObjectXml -Name $obj8 -Guid $guid8 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -TrailingWhitespaceLines 5 -StableLines 40
    $front8Xml = New-TextualFidelityFixtureObjectXml -Name $obj8 -Guid $guid8 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -TrailingWhitespaceLines 5 -TrimTrailingWhitespace -FunctionalChanges 40 -StableLines 40
    Write-FixtureObjectContent -Folder $front8 -Name $obj8 -Content $front8Xml
    Write-FixtureObjectContent -Folder (Join-Path $acervo8 'Procedure') -Name $obj8 -Content $acervo8Xml
    $r8 = & $gateScript -FrontFolder $front8 -AcervoFolder $acervo8 -AsJson | ConvertFrom-Json
    Assert-True ($r8.objectsScanned -eq 1) "Caso 8: objectsScanned esperado 1; obtido $($r8.objectsScanned)"
    Assert-True (@($r8.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' }).Count -eq 0) 'Caso 8: delta funcional dominante com poucos trims nao deveria bloquear por fidelidade textual.'

    $front9 = Join-Path $tempRoot 'case9-front'
    $acervo9 = Join-Path $tempRoot 'case9-acervo'
    $obj9 = 'ObjBomUtf8'
    $guid9 = '99999999-9999-9999-9999-999999999999'
    $same9Acervo = New-TextualFidelityFixtureObjectXml -Name $obj9 -Guid $guid9 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -StableLines 5
    $same9Front = New-TextualFidelityFixtureObjectXml -Name $obj9 -Guid $guid9 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -StableLines 5
    Write-FixtureObjectContent -Folder $front9 -Name $obj9 -Content $same9Front -Utf8Bom
    Write-FixtureObjectContent -Folder (Join-Path $acervo9 'Procedure') -Name $obj9 -Content $same9Acervo
    $r9 = & $gateScript -FrontFolder $front9 -AcervoFolder $acervo9 -AsJson | ConvertFrom-Json
    Assert-True ($r9.objectsScanned -eq 1) "Caso 9: objectsScanned esperado 1; obtido $($r9.objectsScanned)"
    Assert-True (@($r9.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' }).Count -eq 0) 'Caso 9: BOM UTF-8 unilateral nao deve criar residuo funcional nem trim churn.'

    $front10 = Join-Path $tempRoot 'case10-front'
    $acervo10 = Join-Path $tempRoot 'case10-acervo'
    $obj10 = 'ObjUtf16Info'
    $guid10 = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    $same10Acervo = New-TextualFidelityFixtureObjectXml -Name $obj10 -Guid $guid10 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -StableLines 5
    $same10Front = New-TextualFidelityFixtureObjectXml -Name $obj10 -Guid $guid10 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -StableLines 5
    Write-FixtureObjectContent -Folder $front10 -Name $obj10 -Content $same10Front
    $acervo10ObjectFolder = Join-Path $acervo10 'Procedure'
    [void](New-Item -ItemType Directory -Path $acervo10ObjectFolder -Force)
    Write-Utf16LeBomText -Path (Join-Path $acervo10ObjectFolder "$obj10.xml") -Content $same10Acervo
    $r10 = & $gateScript -FrontFolder $front10 -AcervoFolder $acervo10 -AsJson | ConvertFrom-Json
    Assert-True ($r10.objectsScanned -eq 1) "Caso 10: objectsScanned esperado 1; obtido $($r10.objectsScanned)"
    Assert-True ($r10.status -ne 'fail') "Caso 10: comparacao textual informativa nao deveria falhar; obtido $($r10.status)"
    $infoFinding10 = @($r10.findings | Where-Object { $_.code -eq 'front-textual-fidelity-info' } | Select-Object -First 1)
    Assert-True ($infoFinding10.Count -eq 1) 'Caso 10: front-textual-fidelity-info esperado quando baseline por GUID existe mas leitura UTF-8 comparavel falha.'
    Assert-True ($infoFinding10[0].classification -eq 'not-applicable') "Caso 10: classification inesperado: $($infoFinding10[0].classification)"
    Assert-True ([string]$infoFinding10[0].reason -match 'acervo=utf-16-le-bom') "Caso 10: reason deveria registrar acervo=utf-16-le-bom; obtido $($infoFinding10[0].reason)"
    Assert-True (@($r10.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' }).Count -eq 0) 'Caso 10: info textual nao deve emitir bloqueio de trim churn.'

    $attributeName = 'AttrGuard'
    $attributeGuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
    $front11 = Join-Path $tempRoot 'case11-front'
    $acervo11 = Join-Path $tempRoot 'case11-acervo'
    Write-FixtureAttribute -Folder $front11 -Name $attributeName -Guid $attributeGuid -TypeValue ' bas:numeric '
    Write-FixtureAttribute -Folder (Join-Path $acervo11 'Attribute') -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric'
    $r11 = & $gateScript -FrontFolder $front11 -AcervoFolder $acervo11 -AsJson | ConvertFrom-Json
    Assert-True ($r11.attributesScanned -eq 1) "Caso 11: attributesScanned esperado 1; obtido $($r11.attributesScanned)"
    Assert-True ($r11.status -eq 'pass') "Caso 11: valores normalizados da assinatura deveriam passar; obtido $($r11.status)"
    Assert-True (@($r11.findings | Where-Object { $_.code -eq 'front-attribute-type-signature-drift' }).Count -eq 0) 'Caso 11: tipo igual ignorando caixa e espacos externos nao deveria gerar drift.'

    $front12 = Join-Path $tempRoot 'case12-front'
    $acervo12 = Join-Path $tempRoot 'case12-acervo'
    Write-FixtureAttribute -Folder $front12 -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:VarChar'
    Write-FixtureAttribute -Folder (Join-Path $acervo12 'Attribute') -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric'
    $r12 = & $gateScript -FrontFolder $front12 -AcervoFolder $acervo12 -AsJson | ConvertFrom-Json
    Assert-True ($r12.attributesScanned -eq 1) "Caso 12: attributesScanned esperado 1; obtido $($r12.attributesScanned)"
    Assert-True ($r12.status -eq 'fail') "Caso 12: divergencia Numeric/VarChar deveria falhar; obtido $($r12.status)"
    $attributeFinding12 = @($r12.findings | Where-Object { $_.code -eq 'front-attribute-type-signature-drift' } | Select-Object -First 1)
    Assert-True ($attributeFinding12.Count -eq 1) 'Caso 12: finding front-attribute-type-signature-drift ausente.'
    Assert-True ($attributeFinding12[0].matchBasis -eq 'guid') "Caso 12: matchBasis deveria ser guid; obtido $($attributeFinding12[0].matchBasis)"
    Assert-True ($attributeFinding12[0].objectGuid -eq $attributeGuid) "Caso 12: GUID normalizado inesperado: $($attributeFinding12[0].objectGuid)"
    Assert-True ($attributeFinding12[0].acervoPath -eq 'Attribute/AttrGuard.xml') "Caso 12: acervoPath inesperado: $($attributeFinding12[0].acervoPath)"
    Assert-True (@($attributeFinding12[0].signatureDifferences | Where-Object { $_.fieldName -eq 'ATTCUSTOMTYPE' -and $_.frontValue -eq 'bas:VarChar' -and $_.acervoValue -eq 'bas:Numeric' }).Count -eq 1) 'Caso 12: diferenca de ATTCUSTOMTYPE nao foi preservada no finding.'

    $front13 = Join-Path $tempRoot 'case13-front'
    $acervo13 = Join-Path $tempRoot 'case13-acervo'
    Write-FixtureAttribute -Folder $front13 -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:VarChar'
    $brokenAttributeFolder13 = Join-Path $acervo13 'Attribute'
    [void](New-Item -ItemType Directory -Path $brokenAttributeFolder13 -Force)
    Write-Utf8NoBomText -Path (Join-Path $brokenAttributeFolder13 'Broken.xml') -Content '<Attribute name="Broken"'
    $r13 = & $gateScript -FrontFolder $front13 -AcervoFolder $acervo13 -AsJson | ConvertFrom-Json
    Assert-True ($r13.status -eq 'fail') "Caso 13: acervo Attribute ilegivel deveria falhar; obtido $($r13.status)"
    $unreadableFinding13 = @($r13.findings | Where-Object { $_.code -eq 'front-attribute-acervo-unreadable' })
    Assert-True ($unreadableFinding13.Count -eq 1) 'Caso 13: front-attribute-acervo-unreadable ausente.'
    Assert-True (@($unreadableFinding13[0].untrustedAcervoPaths) -contains 'Attribute/Broken.xml') 'Caso 13: caminho do XML ilegivel nao foi preservado.'
    Assert-True (@($r13.findings | Where-Object { $_.code -eq 'front-only-new-attribute' }).Count -eq 0) 'Caso 13: acervo invalido nao pode fazer Attribute parecer novo.'

    $front14 = Join-Path $tempRoot 'case14-front'
    $acervo14 = Join-Path $tempRoot 'case14-acervo'
    Write-FixtureAttribute -Folder $front14 -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '12' -MaxLength '10'
    Write-FixtureAttribute -Folder (Join-Path $acervo14 'Attribute') -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '10' -MaxLength '10'
    $r14 = & $gateScript -FrontFolder $front14 -AcervoFolder $acervo14 -AsJson | ConvertFrom-Json
    Assert-True ($r14.status -eq 'fail') "Caso 14: aumento sem solicitacao explicita deveria falhar; obtido $($r14.status)"
    $growthFinding14 = @($r14.findings | Where-Object { $_.code -eq 'front-attribute-size-growth-requires-user-request' } | Select-Object -First 1)
    Assert-True ($growthFinding14.Count -eq 1) 'Caso 14: finding de solicitacao explicita ausente.'
    Assert-True ($growthFinding14[0].requiredApproval -eq "$attributeGuid|Length|10|12") "Caso 14: autorizacao exata inesperada: $($growthFinding14[0].requiredApproval)"

    $front15 = Join-Path $tempRoot 'case15-front'
    $acervo15 = Join-Path $tempRoot 'case15-acervo'
    Write-FixtureAttribute -Folder $front15 -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '12' -MaxLength '10'
    Write-FixtureAttribute -Folder (Join-Path $acervo15 'Attribute') -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '10' -MaxLength '10'
    $approval15 = "$attributeGuid|Length|10|12"
    $r15 = & $gateScript -FrontFolder $front15 -AcervoFolder $acervo15 -ApprovedAttributeSizeGrowth $approval15 -AsJson | ConvertFrom-Json
    Assert-True ($r15.status -eq 'pass') "Caso 15: aumento exato explicitamente autorizado deveria passar; obtido $($r15.status)"
    $approvedFinding15 = @($r15.findings | Where-Object { $_.code -eq 'front-attribute-size-growth-authorized' } | Select-Object -First 1)
    Assert-True ($approvedFinding15.Count -eq 1) 'Caso 15: finding informativo de aumento autorizado ausente.'

    $front16 = Join-Path $tempRoot 'case16-front'
    $acervo16 = Join-Path $tempRoot 'case16-acervo'
    Write-FixtureAttribute -Folder $front16 -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '8' -MaxLength '10'
    Write-FixtureAttribute -Folder (Join-Path $acervo16 'Attribute') -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '10' -MaxLength '10'
    $r16 = & $gateScript -FrontFolder $front16 -AcervoFolder $acervo16 -AsJson | ConvertFrom-Json
    Assert-True ($r16.status -eq 'fail') "Caso 16: reducao de tamanho deveria falhar; obtido $($r16.status)"
    Assert-True (@($r16.findings | Where-Object { $_.code -eq 'front-attribute-size-reduction' }).Count -eq 1) 'Caso 16: finding de reducao ausente.'

    $front17 = Join-Path $tempRoot 'case17-front'
    $acervo17 = Join-Path $tempRoot 'case17-acervo'
    Write-FixtureAttribute -Folder $front17 -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:VarChar' -Length '12' -MaxLength '10'
    Write-FixtureAttribute -Folder (Join-Path $acervo17 'Attribute') -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '10' -MaxLength '10'
    $approval17 = "$attributeGuid|Length|10|12"
    $r17 = & $gateScript -FrontFolder $front17 -AcervoFolder $acervo17 -ApprovedAttributeSizeGrowth $approval17 -AsJson | ConvertFrom-Json
    Assert-True ($r17.status -eq 'fail') "Caso 17: autorizacao de aumento nao pode liberar mudanca de tipo; obtido $($r17.status)"
    Assert-True (@($r17.findings | Where-Object { $_.code -eq 'front-attribute-type-signature-drift' }).Count -eq 1) 'Caso 17: bloqueio de mudanca de tipo ausente.'

    $front18 = Join-Path $tempRoot 'case18-front'
    $acervo18 = Join-Path $tempRoot 'case18-acervo'
    Write-FixtureAttribute -Folder $front18 -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '12' -MaxLength '10'
    Write-FixtureAttribute -Folder (Join-Path $acervo18 'Attribute') -Name $attributeName -Guid $attributeGuid -TypeValue 'bas:Numeric' -Length '10' -MaxLength '10'
    $wrongApproval18 = "$attributeGuid|Length|10|13"
    $r18 = & $gateScript -FrontFolder $front18 -AcervoFolder $acervo18 -ApprovedAttributeSizeGrowth $wrongApproval18 -AsJson | ConvertFrom-Json
    Assert-True ($r18.status -eq 'fail') "Caso 18: autorizacao de valores diferentes nao pode liberar aumento; obtido $($r18.status)"
    Assert-True (@($r18.findings | Where-Object { $_.code -eq 'front-attribute-size-approval-unmatched' }).Count -eq 1) 'Caso 18: autorizacao nao correspondente deveria falhar.'
    Assert-True (@($r18.findings | Where-Object { $_.code -eq 'front-attribute-size-growth-requires-user-request' }).Count -eq 1) 'Caso 18: aumento real continuou sem autorizacao exata.'

    $domainTypeGuid = '00972a17-9975-449e-aab1-d26165d51393'
    $domainGuid = 'aaaaaaaa-1111-2222-3333-444444444444'
    $domainOldStamp = '2026-01-01T00:00:00.0000000Z'
    $domainNewStamp = '2026-02-01T00:00:00.0000000Z'

    # A matriz de propriedades é fechada: toda propriedade observada tem uma regra explícita.
    $domainSupportPath = Join-Path $scriptDir 'GeneXusDomainDriftSupport.ps1'
    . $domainSupportPath
    $expectedConditional = @('AUTONUMBER', 'AUTONUMBER_FORREPLICATION', 'AUTONUMBER_START', 'AUTONUMBER_STEP', 'AddEmptyItem', 'ATT_PICTURE', 'AttAvgLen', 'AttCollection', 'ControlType', 'EmptyAsNull', 'idBasedOn', 'idCHARCASE', 'idDATEFORMAT', 'idHOURFORMAT', 'Name', 'Description', 'NotifyContextChange')
    $expectedBlocked = @('ATT_INITIAL_VALUE', 'ATTCUSTOMTYPE', 'Decimals', 'IsDefault', 'Signed')
    $expectedSize = @('Length', 'AttMaxLen')
    $actualClassified = @($script:GeneXusDomainConditionalFields + $script:GeneXusDomainAlwaysBlockedFields + $expectedSize + @('IDEnumDefinedValues'))
    $expectedClassified = @($expectedConditional + $expectedBlocked + $expectedSize + @('IDEnumDefinedValues'))
    $actualSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($field in $actualClassified) { [void]$actualSet.Add([string]$field) }
    $expectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($field in $expectedClassified) { [void]$expectedSet.Add([string]$field) }
    Assert-True ($actualClassified.Count -eq 25 -and $actualSet.SetEquals($expectedSet)) 'Caso 19: a matriz fechada deve classificar exatamente as 25 propriedades Domain observadas.'

    $unchangedDomain = New-FixtureDomainXml -Name 'DomainBase' -Guid $domainGuid -TypeGuid $domainTypeGuid -LastUpdate $domainNewStamp
    $baselineDomain = New-FixtureDomainXml -Name 'DomainBase' -Guid $domainGuid -TypeGuid $domainTypeGuid -LastUpdate $domainOldStamp
    $domainCase20 = New-DomainGateCase -CaseName 'domain-case20-unchanged' -FrontXml $unchangedDomain -BaselineXml $baselineDomain
    $r20 = Invoke-DomainGateCase -Case $domainCase20
    Assert-True ($r20.status -eq 'pass' -and $r20.domainsScanned -eq 1) 'Caso 20: Domain sem drift deveria passar e contar um Domain.'
    Assert-True (@($r20.findings | Where-Object { $_.code -like 'domain-*' }).Count -eq 0) 'Caso 20: Domain sem drift não deveria receber finding Domain.'

    # Description só passa após aprovação exata dos dois locais espelhados.
    $descriptionBase = New-FixtureDomainXml -Name 'DomainDescription' -Guid 'bbbbbbbb-1111-2222-3333-444444444444' -LastUpdate $domainOldStamp -RootAttributes @{ description = 'Descrição antiga' } -Properties @(@{ Name = 'Description'; Value = 'Descrição antiga' })
    $descriptionFront = New-FixtureDomainXml -Name 'DomainDescription' -Guid 'bbbbbbbb-1111-2222-3333-444444444444' -LastUpdate $domainNewStamp -RootAttributes @{ description = 'Descrição nova "Ação"' } -Properties @(@{ Name = 'Description'; Value = 'Descrição nova "Ação"' })
    $domainCase21 = New-DomainGateCase -CaseName 'domain-case21-description' -FrontXml $descriptionFront -BaselineXml $descriptionBase
    $r21 = Invoke-DomainGateCase -Case $domainCase21
    $descriptionRequirements = @($r21.findings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' })
    Assert-True ($r21.status -eq 'fail' -and $descriptionRequirements.Count -eq 2) 'Caso 21: Description alterada na raiz e propriedade deve exigir duas confirmações pontuais.'
    $approval21 = Join-Path $domainCase21.root 'approvals.json'
    $approvals21 = @($descriptionRequirements | ForEach-Object { New-DomainApprovalFromChange -Change $_.domainChange })
    Write-DomainApprovalFile -Path $approval21 -Approvals $approvals21
    $r21Approved = Invoke-DomainGateCase -Case $domainCase21 -ApprovedPath $approval21
    Assert-True ($r21Approved.status -eq 'pass') 'Caso 21: aprovações JSON exatas para os dois locais de Description deveriam passar.'
    Assert-True (@($r21Approved.findings | Where-Object { $_.code -eq 'domain-change-approved' }).Count -eq 2) 'Caso 21: findings informativos deveriam registrar ambas as aprovações.'

    $lengthBase = New-FixtureDomainXml -Name 'DomainLength' -Guid 'cccccccc-1111-2222-3333-444444444444' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'Length'; Value = '10' })
    $lengthDown = New-FixtureDomainXml -Name 'DomainLength' -Guid 'cccccccc-1111-2222-3333-444444444444' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'Length'; Value = '8' })
    $domainCase22 = New-DomainGateCase -CaseName 'domain-case22-length-reduction' -FrontXml $lengthDown -BaselineXml $lengthBase
    $r22 = Invoke-DomainGateCase -Case $domainCase22
    $reduction22 = @($r22.findings | Where-Object { $_.code -eq 'domain-size-reduction' } | Select-Object -First 1)
    Assert-True ($r22.status -eq 'fail' -and $reduction22.Count -eq 1) 'Caso 22: redução de Length deve sempre bloquear.'
    $approval22 = Join-Path $domainCase22.root 'approvals.json'
    Write-DomainApprovalFile -Path $approval22 -Approvals @((New-DomainApprovalFromChange -Change $reduction22[0].domainChange))
    $r22Approved = Invoke-DomainGateCase -Case $domainCase22 -ApprovedPath $approval22
    Assert-True ($r22Approved.status -eq 'fail' -and @($r22Approved.findings | Where-Object { $_.code -eq 'domain-approval-blocked-change' }).Count -eq 1) 'Caso 22: aprovação não pode liberar redução de Length.'

    $lengthUp = New-FixtureDomainXml -Name 'DomainLength' -Guid 'dddddddd-1111-2222-3333-444444444444' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'Length'; Value = '12' })
    $lengthUpBase = New-FixtureDomainXml -Name 'DomainLength' -Guid 'dddddddd-1111-2222-3333-444444444444' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'Length'; Value = '10' })
    $domainCase23 = New-DomainGateCase -CaseName 'domain-case23-length-growth' -FrontXml $lengthUp -BaselineXml $lengthUpBase
    $r23 = Invoke-DomainGateCase -Case $domainCase23
    $growth23 = @($r23.findings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' } | Select-Object -First 1)
    Assert-True ($r23.status -eq 'fail' -and $growth23.Count -eq 1) 'Caso 23: aumento de Length deve exigir aprovação específica.'
    $approval23 = Join-Path $domainCase23.root 'approvals.json'
    Write-DomainApprovalFile -Path $approval23 -Approvals @((New-DomainApprovalFromChange -Change $growth23[0].domainChange))
    $r23Approved = Invoke-DomainGateCase -Case $domainCase23 -ApprovedPath $approval23
    Assert-True ($r23Approved.status -eq 'pass' -and @($r23Approved.findings | Where-Object { $_.code -eq 'domain-change-approved' }).Count -eq 1) 'Caso 23: aumento de Length com aprovação exata deveria passar.'

    $typeBase = New-FixtureDomainXml -Name 'DomainType' -Guid 'eeeeeeee-1111-2222-3333-444444444444' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'ATTCUSTOMTYPE'; Value = 'bas:Numeric' })
    $typeFront = New-FixtureDomainXml -Name 'DomainType' -Guid 'eeeeeeee-1111-2222-3333-444444444444' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'ATTCUSTOMTYPE'; Value = 'bas:VarChar' })
    $domainCase24 = New-DomainGateCase -CaseName 'domain-case24-type-change' -FrontXml $typeFront -BaselineXml $typeBase
    $r24 = Invoke-DomainGateCase -Case $domainCase24
    $blockedType24 = @($r24.findings | Where-Object { $_.code -eq 'domain-change-always-blocked' } | Select-Object -First 1)
    Assert-True ($r24.status -eq 'fail' -and $blockedType24.Count -eq 1) 'Caso 24: mudança destrutiva de tipo deve bloquear.'
    $approval24 = Join-Path $domainCase24.root 'approvals.json'
    Write-DomainApprovalFile -Path $approval24 -Approvals @((New-DomainApprovalFromChange -Change $blockedType24[0].domainChange))
    $r24Approved = Invoke-DomainGateCase -Case $domainCase24 -ApprovedPath $approval24
    Assert-True ($r24Approved.status -eq 'fail') 'Caso 24: aprovação não pode liberar mudança de tipo destrutiva.'

    $enumGuid = 'ffffffff-1111-2222-3333-444444444444'
    $enumBase = '1, Primeiro, Texto\, com vírgula; 2, Segundo, Outra descrição'
    $enumFront = '1, Primeiro, Texto\, com vírgula; 2, Segundo, Descrição nova'
    $enumBaseXml = New-FixtureDomainXml -Name 'DomainEnum' -Guid $enumGuid -LastUpdate $domainOldStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = $enumBase })
    $enumFrontXml = New-FixtureDomainXml -Name 'DomainEnum' -Guid $enumGuid -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = $enumFront })
    $domainCase25 = New-DomainGateCase -CaseName 'domain-case25-enum-description' -FrontXml $enumFrontXml -BaselineXml $enumBaseXml
    $r25 = Invoke-DomainGateCase -Case $domainCase25
    $enumChange25 = @($r25.findings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' } | Select-Object -First 1)
    Assert-True ($r25.status -eq 'fail' -and $enumChange25.Count -eq 1 -and $enumChange25[0].domainChange.component -eq 'description') 'Caso 25: descrição de item enumerado deve ser uma diferença condicional identificada pelo valor armazenado.'
    Assert-True ($enumChange25[0].domainChange.enumStoredValue -eq '2') 'Caso 25: aprovação de descrição enumerada deve identificar o valor armazenado.'
    $approval25 = Join-Path $domainCase25.root 'approvals.json'
    Write-DomainApprovalFile -Path $approval25 -Approvals @((New-DomainApprovalFromChange -Change $enumChange25[0].domainChange))
    $r25Approved = Invoke-DomainGateCase -Case $domainCase25 -ApprovedPath $approval25
    Assert-True ($r25Approved.status -eq 'pass') 'Caso 25: descrição enumerada com separador escapado e aprovação exata deveria passar.'

    $enumRenameBase = New-FixtureDomainXml -Name 'DomainEnumRename' -Guid '11111111-aaaa-bbbb-cccc-222222222222' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = '1, Primeiro, Item; 2, Segundo, Outro' })
    $enumRenameFront = New-FixtureDomainXml -Name 'DomainEnumRename' -Guid '11111111-aaaa-bbbb-cccc-222222222222' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = '1, PrimeiroNovo, Item; 2, Segundo, Outro' })
    $domainCase26 = New-DomainGateCase -CaseName 'domain-case26-enum-rename' -FrontXml $enumRenameFront -BaselineXml $enumRenameBase
    $r26 = Invoke-DomainGateCase -Case $domainCase26
    $enumRename26 = @($r26.findings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' } | Select-Object -First 1)
    Assert-True ($r26.status -eq 'fail' -and $enumRename26.Count -eq 1 -and $enumRename26[0].domainChange.component -eq 'identifier') 'Caso 26: rename de identificador com valor persistido estável deve permitir confirmação pontual.'
    $approval26 = Join-Path $domainCase26.root 'approvals.json'
    Write-DomainApprovalFile -Path $approval26 -Approvals @((New-DomainApprovalFromChange -Change $enumRename26[0].domainChange))
    Assert-True ((Invoke-DomainGateCase -Case $domainCase26 -ApprovedPath $approval26).status -eq 'pass') 'Caso 26: rename válido de identificador com valor estável deveria passar após aprovação.'

    $enumOrderBaseText = '1, Primeiro, Item; 2, Segundo, Outro'
    $enumOrderFrontText = '2, Segundo, Outro; 1, Primeiro, Item'
    $enumOrderBase = New-FixtureDomainXml -Name 'DomainEnumOrder' -Guid '22222222-aaaa-bbbb-cccc-333333333333' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = $enumOrderBaseText })
    $enumOrderFront = New-FixtureDomainXml -Name 'DomainEnumOrder' -Guid '22222222-aaaa-bbbb-cccc-333333333333' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = $enumOrderFrontText })
    $domainCase27 = New-DomainGateCase -CaseName 'domain-case27-enum-order' -FrontXml $enumOrderFront -BaselineXml $enumOrderBase
    $r27 = Invoke-DomainGateCase -Case $domainCase27
    $enumOrder27 = @($r27.findings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' } | Select-Object -First 1)
    Assert-True ($r27.status -eq 'fail' -and $enumOrder27.Count -eq 1 -and $enumOrder27[0].domainChange.component -eq 'order') 'Caso 27: reordenação isolada de enumeração deve pedir confirmação.'
    $approval27 = Join-Path $domainCase27.root 'approvals.json'
    Write-DomainApprovalFile -Path $approval27 -Approvals @((New-DomainApprovalFromChange -Change $enumOrder27[0].domainChange))
    Assert-True ((Invoke-DomainGateCase -Case $domainCase27 -ApprovedPath $approval27).status -eq 'pass') 'Caso 27: reordenação isolada deveria passar após aprovação exata.'

    $enumRemovalFront = New-FixtureDomainXml -Name 'DomainEnumRemoval' -Guid '33333333-aaaa-bbbb-cccc-444444444444' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = '2, Segundo, Outro' })
    $enumRemovalBase = New-FixtureDomainXml -Name 'DomainEnumRemoval' -Guid '33333333-aaaa-bbbb-cccc-444444444444' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = '1, Primeiro, Item; 2, Segundo, Outro' })
    $domainCase28 = New-DomainGateCase -CaseName 'domain-case28-enum-removal' -FrontXml $enumRemovalFront -BaselineXml $enumRemovalBase
    $r28 = Invoke-DomainGateCase -Case $domainCase28
    Assert-True ($r28.status -eq 'fail' -and @($r28.findings | Where-Object { $_.code -eq 'domain-enumeration-value-removal' }).Count -eq 1) 'Caso 28: remoção de valor persistido enumerado deve bloquear.'

    $enumReuseFront = New-FixtureDomainXml -Name 'DomainEnumReuse' -Guid '44444444-aaaa-bbbb-cccc-555555555555' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = '1, Segundo, Item; 2, Novo, Outro' })
    $enumReuseBase = New-FixtureDomainXml -Name 'DomainEnumReuse' -Guid '44444444-aaaa-bbbb-cccc-555555555555' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = '1, Primeiro, Item; 2, Segundo, Outro' })
    $domainCase29 = New-DomainGateCase -CaseName 'domain-case29-enum-reuse' -FrontXml $enumReuseFront -BaselineXml $enumReuseBase
    $r29 = Invoke-DomainGateCase -Case $domainCase29
    Assert-True ($r29.status -eq 'fail' -and @($r29.findings | Where-Object { $_.code -eq 'domain-enumeration-identifier-reuse' }).Count -gt 0) 'Caso 29: reutilização de identificador enumerado deve bloquear.'

    foreach ($invalidEnum in @(
        @{ name = 'duplicate-stored'; value = '1, Um, A; 1, Outro, B' },
        @{ name = 'duplicate-identifier'; value = '1, Um, A; 2, um, B' },
        @{ name = 'empty-item'; value = '1, Um, A;;2, Dois, B' },
        @{ name = 'trailing-item'; value = '1, Um, A;' },
        @{ name = 'wrong-component-count'; value = '1, Um' }
    )) {
        $invalidGuid = [guid]::NewGuid().ToString('D')
        $baseXml = New-FixtureDomainXml -Name "DomainEnum_$($invalidEnum.name)" -Guid $invalidGuid -LastUpdate $domainOldStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = '1, Um, A; 2, Dois, B' })
        $frontXml = New-FixtureDomainXml -Name "DomainEnum_$($invalidEnum.name)" -Guid $invalidGuid -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = [string]$invalidEnum.value })
        $invalidCase = New-DomainGateCase -CaseName "domain-case30-$($invalidEnum.name)" -FrontXml $frontXml -BaselineXml $baseXml
        $invalidResult = Invoke-DomainGateCase -Case $invalidCase
        Assert-True ($invalidResult.status -eq 'fail' -and @($invalidResult.findings | Where-Object { $_.code -eq 'domain-enumeration-invalid' }).Count -eq 1) "Caso 30 ($($invalidEnum.name)): parse ambíguo/duplicado/vazio deveria bloquear."
    }

    $enumCaseBase = New-FixtureDomainXml -Name 'DomainEnumCase' -Guid '55555555-aaaa-bbbb-cccc-666666666666' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = 'Ab, Abc, Item' })
    $enumCaseFront = New-FixtureDomainXml -Name 'DomainEnumCase' -Guid '55555555-aaaa-bbbb-cccc-666666666666' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IDEnumDefinedValues'; Value = 'ab, Abc, Item' })
    $domainCase31 = New-DomainGateCase -CaseName 'domain-case31-enum-value-case' -FrontXml $enumCaseFront -BaselineXml $enumCaseBase
    $r31 = Invoke-DomainGateCase -Case $domainCase31
    Assert-True ($r31.status -eq 'fail' -and @($r31.findings | Where-Object { $_.code -eq 'domain-enumeration-value-removal' }).Count -eq 1) 'Caso 31: diferença de caixa no valor armazenado não pode ser normalizada como igualdade.'

    $partType = 'ad3ca970-19d0-44e1-a7b7-db05556e820c'
    $partBase = New-FixtureDomainXml -Name 'DomainPart' -Guid '66666666-aaaa-bbbb-cccc-777777777777' -LastUpdate $domainOldStamp -Properties @(@{ Container = 'Part'; PartType = $partType; Name = 'ControlType'; Value = 'Old' })
    $partFront = New-FixtureDomainXml -Name 'DomainPart' -Guid '66666666-aaaa-bbbb-cccc-777777777777' -LastUpdate $domainNewStamp -Properties @(@{ Container = 'Part'; PartType = $partType; Name = 'ControlType'; Value = 'New' })
    $domainCase32 = New-DomainGateCase -CaseName 'domain-case32-part-property' -FrontXml $partFront -BaselineXml $partBase
    $r32 = Invoke-DomainGateCase -Case $domainCase32
    $partChange32 = @($r32.findings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' } | Select-Object -First 1)
    Assert-True ($partChange32.Count -eq 1 -and $partChange32[0].domainChange.container -eq 'Object/Part/Properties' -and $partChange32[0].domainChange.partType -eq $partType) 'Caso 32: propriedade Part-only deve ser observada com Part/@type na identidade.'
    $partApproval = Join-Path $domainCase32.root 'approvals.json'
    Write-DomainApprovalFile -Path $partApproval -Approvals @((New-DomainApprovalFromChange -Change $partChange32[0].domainChange))
    Assert-True ((Invoke-DomainGateCase -Case $domainCase32 -ApprovedPath $partApproval).status -eq 'pass') 'Caso 32: propriedade em Part com aprovação exata deveria passar.'

    $partAddedType = New-FixtureDomainXml -Name 'DomainPartNew' -Guid '77777777-aaaa-bbbb-cccc-888888888888' -LastUpdate $domainNewStamp -Properties @(@{ Container = 'Part'; PartType = 'new-part-type'; Name = 'ControlType'; Value = 'New' })
    $partAddedBase = New-FixtureDomainXml -Name 'DomainPartNew' -Guid '77777777-aaaa-bbbb-cccc-888888888888' -LastUpdate $domainOldStamp
    $domainCase33 = New-DomainGateCase -CaseName 'domain-case33-part-added' -FrontXml $partAddedType -BaselineXml $partAddedBase
    $r33 = Invoke-DomainGateCase -Case $domainCase33
    Assert-True ($r33.status -eq 'fail' -and @($r33.findings | Where-Object { $_.code -eq 'domain-property-container-new' }).Count -gt 0) 'Caso 33: container Part novo deve bloquear mesmo com campo condicional.'

    $duplicateProperties = @(@{ Name = 'IsDefault'; Value = 'False' }, @{ Name = 'IsDefault'; Value = 'False' })
    $duplicateFront = New-FixtureDomainXml -Name 'DomainDuplicate' -Guid '88888888-aaaa-bbbb-cccc-999999999999' -LastUpdate $domainNewStamp -Properties $duplicateProperties
    $duplicateBase = New-FixtureDomainXml -Name 'DomainDuplicate' -Guid '88888888-aaaa-bbbb-cccc-999999999999' -LastUpdate $domainOldStamp
    $domainCase34 = New-DomainGateCase -CaseName 'domain-case34-property-duplicate' -FrontXml $duplicateFront -BaselineXml $duplicateBase
    $r34 = Invoke-DomainGateCase -Case $domainCase34
    Assert-True ($r34.status -eq 'fail' -and @($r34.findings | Where-Object { $_.code -eq 'front-domain-structure-invalid' -or $_.code -eq 'domain-property-duplicate' }).Count -gt 0) 'Caso 34: propriedade duplicada deve bloquear, inclusive em Domain novo/pareado.'

    $isDefaultBase = New-FixtureDomainXml -Name 'DomainDefault' -Guid '99999999-aaaa-bbbb-cccc-000000000000' -LastUpdate $domainOldStamp -Properties @(@{ Name = 'IsDefault'; Value = 'False' })
    $isDefaultSame = New-FixtureDomainXml -Name 'DomainDefault' -Guid '99999999-aaaa-bbbb-cccc-000000000000' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IsDefault'; Value = 'False' })
    $domainCase35 = New-DomainGateCase -CaseName 'domain-case35-isdefault-same' -FrontXml $isDefaultSame -BaselineXml $isDefaultBase
    Assert-True ((Invoke-DomainGateCase -Case $domainCase35).status -eq 'pass') 'Caso 35: IsDefault igual à baseline não bloqueia pela presença da propriedade.'
    $isDefaultChanged = New-FixtureDomainXml -Name 'DomainDefault' -Guid '99999999-aaaa-bbbb-cccc-000000000000' -LastUpdate $domainNewStamp -Properties @(@{ Name = 'IsDefault'; Value = 'True' })
    $domainCase36 = New-DomainGateCase -CaseName 'domain-case36-isdefault-change' -FrontXml $isDefaultChanged -BaselineXml $isDefaultBase
    $r36 = Invoke-DomainGateCase -Case $domainCase36
    Assert-True ($r36.status -eq 'fail' -and @($r36.findings | Where-Object { $_.code -eq 'domain-change-always-blocked' }).Count -eq 1) 'Caso 36: alteração de IsDefault permanece bloqueada.'

    $rootMismatch = New-FixtureDomainXml -Name 'DomainNameMismatch' -Guid '12345678-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainNewStamp -RootAttributes @{ name = 'RootName' }
    $domainCase37 = New-DomainGateCase -CaseName 'domain-case37-name-mismatch' -FrontXml $rootMismatch -BaselineXml $null
    $r37 = Invoke-DomainGateCase -Case $domainCase37
    Assert-True ($r37.status -eq 'fail' -and @($r37.findings | Where-Object { $_.code -eq 'domain-root-name-mismatch' }).Count -eq 1) 'Caso 37: Object/@name divergente da propriedade Name deve bloquear.'

    $missingName = New-FixtureDomainXml -Name 'DomainMissingName' -Guid '23456789-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainNewStamp -OmitNameProperty
    $domainCase38 = New-DomainGateCase -CaseName 'domain-case38-name-missing' -FrontXml $missingName -BaselineXml $null
    $r38 = Invoke-DomainGateCase -Case $domainCase38
    Assert-True ($r38.status -eq 'fail' -and @($r38.findings | Where-Object { $_.code -eq 'domain-root-name-incomplete' }).Count -eq 1) 'Caso 38: Domain sem propriedade Name deve continuar reconhecido e bloquear.'

    $invalidIdentity = New-FixtureDomainXml -Name 'DomainInvalidGuid' -Guid 'not-a-guid' -LastUpdate $domainNewStamp
    $domainCase39 = New-DomainGateCase -CaseName 'domain-case39-invalid-guid' -FrontXml $invalidIdentity -BaselineXml $null
    $r39 = Invoke-DomainGateCase -Case $domainCase39
    Assert-True ($r39.status -eq 'fail' -and @($r39.findings | Where-Object { $_.code -eq 'front-domain-identity-invalid' }).Count -eq 1) 'Caso 39: GUID ausente/inválido deve bloquear identidade Domain.'

    $newDomainGuid = '34567890-aaaa-bbbb-cccc-123456789abc'
    $newDomainXml = New-FixtureDomainXml -Name 'DomainNovo' -Guid $newDomainGuid -LastUpdate $domainNewStamp
    $domainCase40 = New-DomainGateCase -CaseName 'domain-case40-new' -FrontXml $newDomainXml -BaselineXml $null
    $r40 = Invoke-DomainGateCase -Case $domainCase40
    Assert-True ($r40.status -ne 'fail' -and @($r40.findings | Where-Object { $_.code -eq 'front-only-new-object' }).Count -eq 1) 'Caso 40: Domain novo só passa após as varreduras completas.'

    $duplicateFrontGuid = '45678901-aaaa-bbbb-cccc-123456789abc'
    $domainCase41 = New-DomainGateCase -CaseName 'domain-case41-front-duplicate' -FrontXml (New-FixtureDomainXml -Name 'DomainDuplicadoA' -Guid $duplicateFrontGuid -LastUpdate $domainNewStamp) -BaselineXml $null
    Write-FixtureObjectContent -Folder $domainCase41.front -Name 'DomainDuplicadoB' -Content (New-FixtureDomainXml -Name 'DomainDuplicadoB' -Guid $duplicateFrontGuid -LastUpdate $domainNewStamp)
    $r41 = Invoke-DomainGateCase -Case $domainCase41
    Assert-True ($r41.status -eq 'fail' -and @($r41.findings | Where-Object { $_.code -eq 'front-domain-guid-duplicate' }).Count -gt 0) 'Caso 41: GUID repetido na frente deve bloquear a identidade.'

    $malformedBaseCase = New-DomainGateCase -CaseName 'domain-case42-baseline-malformed' -FrontXml (New-FixtureDomainXml -Name 'DomainBaseBad' -Guid '56789012-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainNewStamp) -BaselineXml '<Object type="broken"'
    $r42 = Invoke-DomainGateCase -Case $malformedBaseCase
    Assert-True ($r42.status -eq 'fail' -and @($r42.findings | Where-Object { $_.code -eq 'domain-baseline-incomplete' }).Count -eq 1) 'Caso 42: baseline Domain ilegível deve impedir comparação/classificação como novo.'

    $newWithGlobalGap = New-DomainGateCase -CaseName 'domain-case43-global-gap' -FrontXml (New-FixtureDomainXml -Name 'DomainGlobalGap' -Guid '67890123-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainNewStamp) -BaselineXml $null
    Write-FixtureObjectContent -Folder (Join-Path $newWithGlobalGap.acervo 'Procedure') -Name 'ObjectWithoutGuid' -Content '<Object type="84a12160-f59b-4ad7-a683-ea4481ac23e9" name="ObjectWithoutGuid" />'
    $r43 = Invoke-DomainGateCase -Case $newWithGlobalGap
    Assert-True ($r43.status -eq 'fail' -and @($r43.findings | Where-Object { $_.code -eq 'domain-baseline-incomplete' }).Count -eq 1) 'Caso 43: índice global Object incompleto impede a classificação de Domain novo.'

    $embeddedGuid = '78901234-aaaa-bbbb-cccc-123456789abc'
    $embeddedCase = New-DomainGateCase -CaseName 'domain-case44-embedded-guid' -FrontXml (New-FixtureDomainXml -Name 'DomainEmbedded' -Guid $embeddedGuid -LastUpdate $domainNewStamp) -BaselineXml $null
    Write-FixtureObjectContent -Folder (Join-Path $embeddedCase.acervo 'PackagedModule') -Name 'Package' -Content "<PackagedModule><Objects>$(New-FixtureDomainXml -Name 'DomainEmbedded' -Guid $embeddedGuid -LastUpdate $domainOldStamp)</Objects></PackagedModule>"
    $r44 = Invoke-DomainGateCase -Case $embeddedCase
    Assert-True ($r44.status -eq 'fail' -and @($r44.findings | Where-Object { $_.code -eq 'front-domain-packagedmodule-identity-collision' }).Count -eq 1) 'Caso 44: GUID encontrado somente em PackagedModule impede falso Domain novo.'

    $embeddedInvalid = New-DomainGateCase -CaseName 'domain-case45-embedded-invalid' -FrontXml (New-FixtureDomainXml -Name 'DomainEmbeddedInvalid' -Guid '89012345-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainNewStamp) -BaselineXml $null
    $invalidEmbeddedXml = "<PackagedModule><Objects>$(New-FixtureDomainXml -Name 'EmbeddedWithoutGuid' -Guid 'bad-guid' -LastUpdate $domainOldStamp)</Objects></PackagedModule>"
    Write-FixtureObjectContent -Folder (Join-Path $embeddedInvalid.acervo 'PackagedModule') -Name 'Package' -Content $invalidEmbeddedXml
    $r45 = Invoke-DomainGateCase -Case $embeddedInvalid
    Assert-True ($r45.status -eq 'fail' -and @($r45.findings | Where-Object { $_.code -eq 'domain-embedded-scan-incomplete' }).Count -eq 1) 'Caso 45: Domain embutido sem GUID torna incompleta a prova de Domain novo.'

    $collisionName = 'DomainCollision'
    $collisionFront = New-FixtureDomainXml -Name $collisionName -Guid '90123456-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainNewStamp
    $collisionBase = New-FixtureDomainXml -Name $collisionName -Guid 'a0123456-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainOldStamp
    $domainCase46 = New-DomainGateCase -CaseName 'domain-case46-name-collision' -FrontXml $collisionFront -BaselineXml $collisionBase
    $r46 = Invoke-DomainGateCase -Case $domainCase46
    Assert-True ($r46.status -eq 'fail' -and @($r46.findings | Where-Object { $_.code -eq 'front-domain-name-collision' }).Count -eq 1) 'Caso 46: homônimo com GUID diferente não pode ser classificado como novo.'

    $fqnBase = New-FixtureDomainXml -Name 'DomainBaseFqn' -Guid 'b0123456-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainOldStamp -RootAttributes @{ fullyQualifiedName = 'Módulo.DomainFqn' }
    $fqnFront = New-FixtureDomainXml -Name 'DomainFqn' -Guid 'c0123456-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainNewStamp -RootAttributes @{ fullyQualifiedName = 'Módulo.DomainFqn' }
    $domainCase47 = New-DomainGateCase -CaseName 'domain-case47-fqn-collision' -FrontXml $fqnFront -BaselineXml $fqnBase
    $r47 = Invoke-DomainGateCase -Case $domainCase47
    Assert-True ($r47.status -eq 'fail' -and @($r47.findings | Where-Object { $_.code -eq 'front-domain-name-collision' }).Count -eq 1) 'Caso 47: FQN conflitante com GUID diferente deve bloquear.'

    $guidTextBase = New-FixtureDomainXml -Name 'DomainGuidText' -Guid $domainGuid -LastUpdate $domainOldStamp
    $guidTextFront = New-FixtureDomainXml -Name 'DomainGuidText' -Guid ('{' + $domainGuid.ToUpperInvariant() + '}') -TypeGuid ('{' + $domainTypeGuid.ToUpperInvariant() + '}') -LastUpdate $domainNewStamp
    $domainCase48 = New-DomainGateCase -CaseName 'domain-case48-guid-normalization' -FrontXml $guidTextFront -BaselineXml $guidTextBase
    $r48 = Invoke-DomainGateCase -Case $domainCase48
    Assert-True ($r48.status -ne 'fail' -and $r48.domainsScanned -eq 1) 'Caso 48: GUIDs equivalentes em caixa e formato aceito devem parear pelo GUID normalizado.'

    $duplicateApprovalCase = New-DomainGateCase -CaseName 'domain-case49-approval-duplicate' -FrontXml $lengthUp -BaselineXml $lengthUpBase
    $duplicateApprovalPath = Join-Path $duplicateApprovalCase.root 'approvals.json'
    $lengthUpCaseResult = Invoke-DomainGateCase -Case $duplicateApprovalCase
    $lengthUpChange = @($lengthUpCaseResult.findings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' } | Select-Object -First 1)[0].domainChange
    $duplicateApproval = New-DomainApprovalFromChange -Change $lengthUpChange
    Write-DomainApprovalFile -Path $duplicateApprovalPath -Approvals @($duplicateApproval, $duplicateApproval)
    $r49 = Invoke-DomainGateCase -Case $duplicateApprovalCase -ApprovedPath $duplicateApprovalPath
    Assert-True ($r49.status -eq 'fail' -and @($r49.findings | Where-Object { $_.code -eq 'domain-approval-envelope-invalid' }).Count -eq 1) 'Caso 49: aprovação duplicada deve invalidar o envelope de aprovações.'

    $unmatchedApprovalPath = Join-Path $domainCase20.root 'unmatched-approval.json'
    $unmatchedApproval = [ordered]@{ objectGuid = 'aaaaaaaa-1111-2222-3333-444444444444'; field = 'Description'; locationKind = 'property'; container = 'Object/Properties'; partType = ''; component = 'value'; enumStoredValue = ''; oldState = 'value'; oldValue = 'old'; newState = 'value'; newValue = 'new' }
    Write-DomainApprovalFile -Path $unmatchedApprovalPath -Approvals @($unmatchedApproval)
    $r50 = Invoke-DomainGateCase -Case $domainCase20 -ApprovedPath $unmatchedApprovalPath
    Assert-True ($r50.status -eq 'fail' -and @($r50.findings | Where-Object { $_.code -eq 'domain-approval-unmatched' }).Count -eq 1) 'Caso 50: aprovação sem diferença correspondente deve bloquear.'

    $invalidApprovalPath = Join-Path $domainCase20.root 'invalid-approval.json'
    Write-Utf8NoBomText -Path $invalidApprovalPath -Content '{ invalid json'
    $r51 = Invoke-DomainGateCase -Case $domainCase20 -ApprovedPath $invalidApprovalPath
    Assert-True ($r51.status -eq 'fail' -and @($r51.findings | Where-Object { $_.code -eq 'domain-approval-envelope-invalid' }).Count -eq 1) 'Caso 51: JSON de aprovações inválido deve bloquear.'

    $catalogFallbackVariants = @(
        @{ name = 'missing'; omit = $true; text = $null },
        @{ name = 'unreadable'; omit = $false; text = 'not json' },
        @{ name = 'missing-domain'; omit = $false; text = '{"types":{}}' },
        @{ name = 'duplicate-domain'; omit = $false; text = '{"types":{"Domain":{"objectTypeGuid":"00972a17-9975-449e-aab1-d26165d51393"},"Domain":{"objectTypeGuid":"00972a17-9975-449e-aab1-d26165d51393"}}}' },
        @{ name = 'invalid-guid'; omit = $false; text = '{"types":{"Domain":{"objectTypeGuid":"bad-guid"}}}' }
    )
    foreach ($variant in $catalogFallbackVariants) {
        $fallbackHarness = New-DomainGateHarness -Name ([string]$variant.name) -CatalogText $variant.text -OmitCatalog:([bool]$variant.omit)
        $fallbackGuid = [guid]::NewGuid().ToString('D')
        $fallbackBase = New-FixtureDomainXml -Name "DomainFallback_$($variant.name)" -Guid $fallbackGuid -LastUpdate $domainOldStamp
        $fallbackFront = New-FixtureDomainXml -Name "DomainFallback_$($variant.name)" -Guid $fallbackGuid -LastUpdate $domainNewStamp
        $fallbackCase = New-DomainGateCase -CaseName "domain-catalog-fallback-$($variant.name)" -FrontXml $fallbackFront -BaselineXml $fallbackBase
        $fallbackResult = Invoke-DomainGateCase -Case $fallbackCase -GatePath $fallbackHarness
        Assert-True ($fallbackResult.status -ne 'fail' -and $fallbackResult.domainsScanned -eq 1) "Caso 52 ($($variant.name)): catálogo ausente/inválido deve usar o fallback apenas para Domain correspondente."
    }

    $duplicateTypePropertyCatalog = '{"types":{"Domain":{"objectTypeGuid":"00972a17-9975-449e-aab1-d26165d51393","objectTypeGuid":"00972a17-9975-449e-aab1-d26165d51393"}}}'
    $duplicateTypePropertyHarness = New-DomainGateHarness -Name 'duplicate-guid-property' -CatalogText $duplicateTypePropertyCatalog
    $duplicateTypePropertyCase = New-DomainGateCase -CaseName 'domain-catalog-duplicate-guid-property' -FrontXml (New-FixtureDomainXml -Name 'DomainDuplicateTypeGuid' -Guid 'd0123456-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainNewStamp) -BaselineXml (New-FixtureDomainXml -Name 'DomainDuplicateTypeGuid' -Guid 'd0123456-aaaa-bbbb-cccc-123456789abc' -LastUpdate $domainOldStamp)
    $duplicateTypePropertyResult = Invoke-DomainGateCase -Case $duplicateTypePropertyCase -GatePath $duplicateTypePropertyHarness
    Assert-True ($duplicateTypePropertyResult.status -ne 'fail') 'Caso 53: objectTypeGuid duplicado no catálogo deve recorrer ao GUID fallback aprovado.'

    $divergentCatalog = '{"types":{"Domain":{"objectTypeGuid":"e0123456-aaaa-bbbb-cccc-123456789abc"}}}'
    $divergentHarness = New-DomainGateHarness -Name 'divergent-guid' -CatalogText $divergentCatalog
    $divergentType = 'e0123456-aaaa-bbbb-cccc-123456789abc'
    $divergentGuid = 'f0123456-aaaa-bbbb-cccc-123456789abc'
    $divergentBase = New-FixtureDomainXml -Name 'DomainCatalogDivergent' -Guid $divergentGuid -TypeGuid $divergentType -LastUpdate $domainOldStamp
    $divergentFront = New-FixtureDomainXml -Name 'DomainCatalogDivergent' -Guid $divergentGuid -TypeGuid $divergentType -LastUpdate $domainNewStamp
    $divergentCase = New-DomainGateCase -CaseName 'domain-catalog-divergent' -FrontXml $divergentFront -BaselineXml $divergentBase
    $divergentResult = Invoke-DomainGateCase -Case $divergentCase -GatePath $divergentHarness
    Assert-True ($divergentResult.status -eq 'fail' -and @($divergentResult.findings | Where-Object { $_.code -eq 'domain-catalog-inconsistent' }).Count -eq 1 -and @($divergentResult.findings | Where-Object { $_.code -eq 'front-only-new-object' }).Count -eq 0) 'Caso 54: GUID válido divergente no catálogo deve ser reconhecido como Domain e bloquear sem fallback genérico.'

    $nonDomainCase = New-DomainGateCase -CaseName 'domain-case55-nondomain' -FrontXml (New-FixtureObjectXml -Name 'ProcedureOnly' -Guid '01234567-aaaa-bbbb-cccc-123456789abc' -TypeGuid $procedureTypeGuid -LastUpdate $domainNewStamp) -BaselineXml $null
    $r55 = Invoke-DomainGateCase -Case $nonDomainCase
    Assert-True ($r55.status -ne 'fail' -and $r55.domainsScanned -eq 0 -and @($r55.findings | Where-Object { $_.code -like 'domain-*' }).Count -eq 0) 'Caso 55: entrada não-Domain conserva seu tratamento sem findings Domain.'

    Write-Output 'GENEXUS_FRONT_ACERVO_DRIFT_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
