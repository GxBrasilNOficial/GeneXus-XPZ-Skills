#requires -Version 7.4
<#
.SYNOPSIS
    Self-test G.2 da frente idBasedOn -> Domain (extrator 12): fixtures nao-vacuos e evidencia persistida.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function Get-CompactSnippet([string]$Text, [int]$Limit = 220) {
    $snippet = (($Text.Trim() -split '\s+' | Where-Object { $_ -ne '' }) -join ' ')
    if ($snippet.Length -le $Limit) { return $snippet }
    return ($snippet.Substring(0, $Limit - 3).TrimEnd() + '...')
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERT: $Message" }
}

function Get-BasedOnDomainRows([string]$SqlitePath) {
    $outJson = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-idb-rows-{0}.json' -f ([guid]::NewGuid().ToString('N')))
    $pyPath = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-idb-rows-{0}.py' -f ([guid]::NewGuid().ToString('N')))
    $py = @"
import json, sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
rows = conn.execute("""
SELECT o.type, o.name, r.target_type, r.target_name, r.relation_kind, r.confidence,
       e.extractor_rule, e.source_file, e.line, e.column, e.snippet, e.evidence_role
FROM relations r
JOIN objects o ON o.object_id = r.source_object_id
JOIN evidence e ON e.evidence_id = r.evidence_id
WHERE r.relation_kind = 'based_on_domain'
ORDER BY o.type, o.name, e.line, e.extractor_rule
""").fetchall()
payload = [
    {
        "source_type": r[0], "source_name": r[1], "target_type": r[2], "target_name": r[3],
        "relation_kind": r[4], "confidence": r[5], "extractor_rule": r[6], "source_file": r[7],
        "line": r[8], "column": r[9], "snippet": r[10], "evidence_role": r[11],
    }
    for r in rows
]
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    json.dump(payload, fh, ensure_ascii=False)
"@
    $enc = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($pyPath, $py, $enc)
    try {
        & python $pyPath $SqlitePath $outJson
        if ($LASTEXITCODE -ne 0) { throw "Falha ao ler based_on_domain do sqlite; exit $LASTEXITCODE" }
        $parsed = Get-Content -LiteralPath $outJson -Raw -Encoding UTF8 | ConvertFrom-Json
        return @($parsed)
    }
    finally {
        Remove-Item -LiteralPath $pyPath, $outJson -Force -ErrorAction SilentlyContinue
    }
}

function Find-Rows {
    param(
        [Parameter(Mandatory)]
        [object[]]$Rows,
        [Parameter(Mandatory)]
        [string]$SourceType,
        [Parameter(Mandatory)]
        [string]$SourceName,
        [string]$TargetName = '',
        [string]$Rule = ''
    )
    return @(
        $Rows | Where-Object {
            $_.source_type -eq $SourceType -and $_.source_name -eq $SourceName -and
            ([string]::IsNullOrEmpty($TargetName) -or $_.target_name -eq $TargetName) -and
            ([string]::IsNullOrEmpty($Rule) -or $_.extractor_rule -eq $Rule)
        }
    )
}

$scriptDir = $PSScriptRoot
$domainGuid = '00972a17-9975-449e-aab1-d26165d51393'
$procedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$sdtGuid = '447527b5-9210-4523-898b-5dccb17be60a'
$panelGuid = 'd82625fd-5892-40b0-99c9-5c8559c197fc'
$webPanelGuid = 'c9584656-94b6-4ccd-890f-332d11fc2c25'
$transactionGuid = '1db606f2-af09-4cf9-a3b5-b481519d28f6'
$dataProviderGuid = '2a9e9aba-d2de-4801-ae7f-5e3819222daf'
$apiGuid = '36e32e2d-023e-4188-95df-d13573bac2e0'
$dataSelectorGuid = 'ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af'
$workWithGuid = '15cf49b5-fc38-4899-91b5-395d02d79889'
$workWithForWebGuid = '78cecefe-be7d-4980-86ce-8d6e91fba04b'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-idbasedon-domain-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$domainDir = Join-Path $objetosPath 'Domain'
$procedureDir = Join-Path $objetosPath 'Procedure'
$sdtDir = Join-Path $objetosPath 'SDT'
$attributeDir = Join-Path $objetosPath 'Attribute'
$panelDir = Join-Path $objetosPath 'Panel'
$webPanelDir = Join-Path $objetosPath 'WebPanel'
$transactionDir = Join-Path $objetosPath 'Transaction'
$dataProviderDir = Join-Path $objetosPath 'DataProvider'
$apiDir = Join-Path $objetosPath 'API'
$dataSelectorDir = Join-Path $objetosPath 'DataSelector'
$workWithDir = Join-Path $objetosPath 'WorkWith'
$workWithForWebDir = Join-Path $objetosPath 'WorkWithForWeb'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $domainDir, $procedureDir, $sdtDir, $attributeDir, $panelDir, $webPanelDir, $transactionDir, $dataProviderDir, $apiDir, $dataSelectorDir, $workWithDir, $workWithForWebDir, $kbIntelDir -Force)

function Write-DomainXml {
    param([string]$Name, [string]$Fqfn, [string]$GuidSuffix)
    $fqAttr = if ([string]::IsNullOrEmpty($Fqfn)) { '' } else { " fullyQualifiedName=`"$Fqfn`"" }
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$domainGuid" name="$Name" guid="aaaaaaaa-aaaa-aaaa-aaaa-$GuidSuffix"$fqAttr>
  <Properties><Property><Name>Name</Name><Value>$Name</Value></Property></Properties>
</Object>
"@
    [System.IO.File]::WriteAllText((Join-Path $domainDir "$Name.xml"), $xml, (Get-Utf8NoBomEncoding))
}

function Write-TypedObjectWithIdBasedOn {
    param(
        [string]$TypeGuid,
        [string]$FolderPath,
        [string]$Name,
        [string]$GuidSuffix,
        [string]$DomainValue
    )
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$TypeGuid" name="$Name" guid="ffffffff-ffff-ffff-ffff-$GuidSuffix" fullyQualifiedName="$Name">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="V1">
      <Properties><Property><Name>idBasedOn</Name><Value>$DomainValue</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
    [System.IO.File]::WriteAllText((Join-Path $FolderPath "$Name.xml"), $xml, (Get-Utf8NoBomEncoding))
}

try {

# Domains alvo
Write-DomainXml -Name 'DomAlpha' -Fqfn 'DomAlpha' -GuidSuffix '000000000001'
Write-DomainXml -Name 'DomBeta' -Fqfn 'DomBeta' -GuidSuffix '000000000002'
Write-DomainXml -Name 'DomMod' -Fqfn 'Mod.DomMod' -GuidSuffix '000000000003'
Write-DomainXml -Name 'DomPairA' -Fqfn 'DomPairA' -GuidSuffix '000000000004'
Write-DomainXml -Name 'DomPairB' -Fqfn 'DomPairB' -GuidSuffix '000000000005'
Write-DomainXml -Name 'DomDedup' -Fqfn 'Mod.DomDedup' -GuidSuffix '000000000006'
Write-DomainXml -Name 'DomNoFqfn' -Fqfn '' -GuidSuffix '000000000007'
Write-DomainXml -Name 'NestedLeaf' -Fqfn 'A.B.NestedLeaf' -GuidSuffix '000000000008'
Write-DomainXml -Name 'DomCase' -Fqfn 'ModCase.DomCase' -GuidSuffix '000000000009'
Write-DomainXml -Name 'DomSpace' -Fqfn 'Mod.DomSpace' -GuidSuffix '00000000000a'
Write-DomainXml -Name 'DomY' -Fqfn 'DomY' -GuidSuffix '00000000000b'
Write-DomainXml -Name 'DomCdata' -Fqfn 'DomCdata' -GuidSuffix '00000000000c'
Write-DomainXml -Name 'DomComment' -Fqfn 'DomComment' -GuidSuffix '00000000000d'
Write-DomainXml -Name 'DomNewline' -Fqfn 'DomNewline' -GuidSuffix '00000000000e'
Write-DomainXml -Name 'DomDivergent' -Fqfn 'RealMod.DomDivergent' -GuidSuffix '00000000000f'
Write-DomainXml -Name 'DomCombo' -Fqfn 'DomCombo' -GuidSuffix '000000000010'
Write-DomainXml -Name 'DomPatho' -Fqfn 'DomPatho' -GuidSuffix '000000000011'
Write-DomainXml -Name 'DomLeak' -Fqfn 'DomLeak' -GuidSuffix '000000000012'
Write-DomainXml -Name 'DomSym' -Fqfn 'DomSym' -GuidSuffix '000000000013'
Write-DomainXml -Name 'DomReqMask' -Fqfn 'DomReqMask' -GuidSuffix '000000000014'
Write-DomainXml -Name 'DomScope' -Fqfn 'DomScope' -GuidSuffix '000000000015'

# G.2.21 cobertura de tipos no escopo (alem de SDT/Procedure/Attribute ja cobertos)
Write-TypedObjectWithIdBasedOn -TypeGuid $webPanelGuid -FolderPath $webPanelDir -Name 'WpUsesDomScope' -GuidSuffix '000000000001' -DomainValue 'Domain:DomScope'
Write-TypedObjectWithIdBasedOn -TypeGuid $transactionGuid -FolderPath $transactionDir -Name 'TrnUsesDomScope' -GuidSuffix '000000000002' -DomainValue 'Domain:DomScope'
Write-TypedObjectWithIdBasedOn -TypeGuid $dataProviderGuid -FolderPath $dataProviderDir -Name 'DpUsesDomScope' -GuidSuffix '000000000003' -DomainValue 'Domain:DomScope'
Write-TypedObjectWithIdBasedOn -TypeGuid $apiGuid -FolderPath $apiDir -Name 'ApiUsesDomScope' -GuidSuffix '000000000004' -DomainValue 'Domain:DomScope'
Write-TypedObjectWithIdBasedOn -TypeGuid $dataSelectorGuid -FolderPath $dataSelectorDir -Name 'DsUsesDomScope' -GuidSuffix '000000000005' -DomainValue 'Domain:DomScope'
Write-TypedObjectWithIdBasedOn -TypeGuid $workWithGuid -FolderPath $workWithDir -Name 'WwUsesDomScope' -GuidSuffix '000000000006' -DomainValue 'Domain:DomScope'
Write-TypedObjectWithIdBasedOn -TypeGuid $workWithForWebGuid -FolderPath $workWithForWebDir -Name 'WwWebUsesDomScope' -GuidSuffix '000000000007' -DomainValue 'Domain:DomScope'
$domUsesScopeXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$domainGuid" name="DomUsesDomScope" guid="aaaaaaaa-aaaa-aaaa-aaaa-000000000016" fullyQualifiedName="DomUsesDomScope">
  <Properties>
    <Property><Name>Name</Name><Value>DomUsesDomScope</Value></Property>
    <Property><Name>idBasedOn</Name><Value>Domain:DomScope</Value></Property>
  </Properties>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $domainDir 'DomUsesDomScope.xml'), $domUsesScopeXml, (Get-Utf8NoBomEncoding))

# G.2.1 SDT item
$sdtXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$sdtGuid" name="SdtUsesDomAlpha" guid="bbbbbbbb-bbbb-bbbb-bbbb-000000000001" fullyQualifiedName="SdtUsesDomAlpha">
  <Item>
    <Properties>
      <Property><Name>idBasedOn</Name><Value>Domain:DomAlpha</Value></Property>
    </Properties>
  </Item>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $sdtDir 'SdtUsesDomAlpha.xml'), $sdtXml, (Get-Utf8NoBomEncoding))

# G.2.2 / G.2.4 / G.2.5 / G.2.12 Procedure variables
$procXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcUsesDomains" guid="cccccccc-cccc-cccc-cccc-000000000001" fullyQualifiedName="ProcUsesDomains">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VBeta">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomBeta</Value></Property></Properties>
    </Variable>
    <Variable Name="VDedup1">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomPairA</Value></Property></Properties>
    </Variable>
    <Variable Name="VDedup2">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomPairA</Value></Property></Properties>
    </Variable>
    <Variable Name="VPairB">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomPairB</Value></Property></Properties>
    </Variable>
    <Variable Name="VSpaceTight">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomSpace,Mod</Value></Property></Properties>
    </Variable>
    <Variable Name="VSpaceLoose">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomSpace, Mod</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcUsesDomains.xml'), $procXml, (Get-Utf8NoBomEncoding))

# G.2.3 Attribute + Procedure com modulo
$attrModXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Attribute name="AttrUsesDomMod" guid="dddddddd-dddd-dddd-dddd-000000000001">
  <Properties>
    <Property><Name>idBasedOn</Name><Value>Domain:DomMod, Mod</Value></Property>
  </Properties>
</Attribute>
"@
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrUsesDomMod.xml'), $attrModXml, (Get-Utf8NoBomEncoding))

$procModXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcUsesDomMod" guid="cccccccc-cccc-cccc-cccc-000000000002" fullyQualifiedName="ProcUsesDomMod">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VMod">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomMod, Mod</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcUsesDomMod.xml'), $procModXml, (Get-Utf8NoBomEncoding))

# G.2.6 same target short + module (with fqfn)
$procDedupXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcDedupShortAndMod" guid="cccccccc-cccc-cccc-cccc-000000000003" fullyQualifiedName="ProcDedupShortAndMod">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="V1">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomDedup</Value></Property></Properties>
    </Variable>
    <Variable Name="V2">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomDedup, Mod</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcDedupShortAndMod.xml'), $procDedupXml, (Get-Utf8NoBomEncoding))

# G.2.6b without fqfn: only short resolves
$procNoFqfnXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcNoFqfnMod" guid="cccccccc-cccc-cccc-cccc-000000000004" fullyQualifiedName="ProcNoFqfnMod">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VShort">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomNoFqfn</Value></Property></Properties>
    </Variable>
    <Variable Name="VMod">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomNoFqfn, Mod</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcNoFqfnMod.xml'), $procNoFqfnXml, (Get-Utf8NoBomEncoding))

# G.2.7 Attribute: ignored
$attrRefXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Attribute name="AttrBasedOnAttribute" guid="dddddddd-dddd-dddd-dddd-000000000002">
  <Properties>
    <Property><Name>idBasedOn</Name><Value>Attribute:SomeOtherAttr</Value></Property>
  </Properties>
</Attribute>
"@
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrBasedOnAttribute.xml'), $attrRefXml, (Get-Utf8NoBomEncoding))

# G.2.8 divergent module
$attrDivXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Attribute name="AttrDivergentMod" guid="dddddddd-dddd-dddd-dddd-000000000003">
  <Properties>
    <Property><Name>idBasedOn</Name><Value>Domain:DomDivergent, WrongMod</Value></Property>
  </Properties>
</Attribute>
"@
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrDivergentMod.xml'), $attrDivXml, (Get-Utf8NoBomEncoding))

# G.2.9 fqfn ausente ja coberto por ProcNoFqfnMod VMod

# G.2.10 nested
$procNestXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcNestedFqfn" guid="cccccccc-cccc-cccc-cccc-000000000005" fullyQualifiedName="ProcNestedFqfn">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VOk">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:NestedLeaf, A.B</Value></Property></Properties>
    </Variable>
    <Variable Name="VOnlyB">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:NestedLeaf, B</Value></Property></Properties>
    </Variable>
    <Variable Name="VOnlyA">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:NestedLeaf, A</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcNestedFqfn.xml'), $procNestXml, (Get-Utf8NoBomEncoding))

# G.2.11 case
$procCaseXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcCaseFold" guid="cccccccc-cccc-cccc-cccc-000000000006" fullyQualifiedName="ProcCaseFold">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VCase">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:domcase, modcase</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcCaseFold.xml'), $procCaseXml, (Get-Utf8NoBomEncoding))

# G.2.13 borders
$procBorderXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcBorders" guid="cccccccc-cccc-cccc-cccc-000000000007" fullyQualifiedName="ProcBorders">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VEmpty">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:</Value></Property></Properties>
    </Variable>
    <Variable Name="VMulti">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomAlpha, A, B</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcBorders.xml'), $procBorderXml, (Get-Utf8NoBomEncoding))

# G.2.14 CDATA: fake inside CDATA + real after
$procCdataXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcCdataMask" guid="cccccccc-cccc-cccc-cccc-000000000008" fullyQualifiedName="ProcCdataMask">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[
<Property><Name>idBasedOn</Name><Value>Domain:DomCdata</Value></Property>
]]></Source>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VReal">
      <Properties>
        <Property><Name>idBasedOn</Name><Value>Domain:DomCdata</Value></Property>
      </Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcCdataMask.xml'), $procCdataXml, (Get-Utf8NoBomEncoding))

# G.2.15 comment
$procCommentXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcCommentMask" guid="cccccccc-cccc-cccc-cccc-000000000009" fullyQualifiedName="ProcCommentMask">
  <!--
  <Property><Name>idBasedOn</Name><Value>Domain:DomComment</Value></Property>
  -->
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VReal">
      <Properties>
        <Property><Name>idBasedOn</Name><Value>Domain:DomComment</Value></Property>
      </Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcCommentMask.xml'), $procCommentXml, (Get-Utf8NoBomEncoding))

# G.2.14b combinacao bem-formada: <!--...--> completo + Property falso dentro do mesmo CDATA; real fora
$procComboXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcCdataCommentCombo" guid="cccccccc-cccc-cccc-cccc-00000000000b" fullyQualifiedName="ProcCdataCommentCombo">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[
prefix <!-- fake comment --> suffix
<Property><Name>idBasedOn</Name><Value>Domain:DomCombo</Value></Property>
]]></Source>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VReal">
      <Properties>
        <Property><Name>idBasedOn</Name><Value>Domain:DomCombo</Value></Property>
      </Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcCdataCommentCombo.xml'), $procComboXml, (Get-Utf8NoBomEncoding))

# G.2.14c patogenico: <!-- abre no CDATA, --> so depois do ]]>; Property real entre ]]> e -->
$procPathoXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcCdataCommentPatho" guid="cccccccc-cccc-cccc-cccc-00000000000c" fullyQualifiedName="ProcCdataCommentPatho">
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[
before <!-- span across
]]></Source>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VReal">
      <Properties>
        <Property><Name>idBasedOn</Name><Value>Domain:DomPatho</Value></Property>
      </Properties>
    </Variable>
  </Part>
-->
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcCdataCommentPatho.xml'), $procPathoXml, (Get-Utf8NoBomEncoding))

# G.2.14d comentario com literal <![CDATA[: Property falso antes do literal nao vaza; real fora permanece
$procSymXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcCommentCdataLiteral" guid="cccccccc-cccc-cccc-cccc-00000000000d" fullyQualifiedName="ProcCommentCdataLiteral">
  <!--
  <Property><Name>idBasedOn</Name><Value>Domain:DomLeak</Value></Property>
  docs mention <![CDATA[
  -->
  <Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff">
    <Source><![CDATA[real source body]]></Source>
  </Part>
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VReal">
      <Properties>
        <Property><Name>idBasedOn</Name><Value>Domain:DomSym</Value></Property>
      </Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcCommentCdataLiteral.xml'), $procSymXml, (Get-Utf8NoBomEncoding))

# G.2.16 &#xA; — value with entity newline; line must come from raw
$procNlXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcEntityNewline" guid="cccccccc-cccc-cccc-cccc-00000000000a" fullyQualifiedName="ProcEntityNewline">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VNl">
      <Properties>
        <Property><Name>idBasedOn</Name><Value>Domain:DomNewline&#xA;</Value></Property>
      </Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcEntityNewline.xml'), $procNlXml, (Get-Utf8NoBomEncoding))

# G.2.18 Panel (fora do escopo)
$panelXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$panelGuid" name="PanelWithIdBasedOn" guid="eeeeeeee-eeee-eeee-eeee-000000000001" fullyQualifiedName="PanelWithIdBasedOn">
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Variable Name="VPanel">
      <Properties><Property><Name>idBasedOn</Name><Value>Domain:DomAlpha</Value></Property></Properties>
    </Variable>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $panelDir 'PanelWithIdBasedOn.xml'), $panelXml, (Get-Utf8NoBomEncoding))

# G.2.19 Attribute regression Domain:Y
$attrYXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Attribute name="AttrUsesDomY" guid="dddddddd-dddd-dddd-dddd-000000000004">
  <Properties>
    <Property><Name>idBasedOn</Name><Value>Domain:DomY</Value></Property>
  </Properties>
</Attribute>
"@
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrUsesDomY.xml'), $attrYXml, (Get-Utf8NoBomEncoding))

# G.2.20 require_property: Property so em comentario (nao deve satisfazer a precondicao mascarada)
$procReqCommentOnlyXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureGuid" name="ProcReqPropCommentOnly" guid="cccccccc-cccc-cccc-cccc-00000000000e" fullyQualifiedName="ProcReqPropCommentOnly">
  <!-- <Property><Name>idBasedOn</Name><Value>Domain:DomReqMask</Value></Property> -->
  <Part type="e4c4ade7-53f0-4a56-bdfd-843735b66f47">
    <Source><![CDATA[no real idBasedOn]]></Source>
  </Part>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'ProcReqPropCommentOnly.xml'), $procReqCommentOnlyXml, (Get-Utf8NoBomEncoding))

$casesPath = Join-Path $kbIntelDir 'idbasedon-require-property-cases.json'
$casesJson = @"
{
  "cases": [
    {
      "id": "g2-require-property-real",
      "source": "Attribute:AttrUsesDomY",
      "target": "Domain:DomY",
      "expected_rule": "attribute_idbasedon_domain",
      "should_exist": true,
      "require_property_in_source": "Domain:DomY",
      "expectation": "Property real fora de comentario/CDATA satisfaz require_property_in_source"
    },
    {
      "id": "g2-require-property-comment-only",
      "source": "Procedure:ProcReqPropCommentOnly",
      "target": "Domain:DomReqMask",
      "expected_rule": "object_idbasedon_domain",
      "should_exist": false,
      "require_source_exists": true,
      "require_property_in_source": "Domain:DomReqMask",
      "expectation": "Property so em comentario nao satisfaz require_property_in_source (paridade com mascara do extrator)"
    }
  ]
}
"@
[System.IO.File]::WriteAllText($casesPath, $casesJson, (Get-Utf8NoBomEncoding))

$sqlitePath = Join-Path $kbIntelDir 'kb-intelligence.sqlite'
$validationPath = Join-Path $kbIntelDir 'kb-intelligence-validation.json'
$indexScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'

& $indexScript `
    -SourceRoot $objetosPath `
    -OutputPath $sqlitePath `
    -ValidationReportPath $validationPath `
    -ValidationCasesPath $casesPath `
    -ParallelKbRoot $parallelRoot
if ($LASTEXITCODE -ne 0) {
    throw "Build-KbIntelligenceIndex falhou no self-test idBasedOn; exit $LASTEXITCODE"
}

$metaVersion = & python -c "import sqlite3,sys; c=sqlite3.connect(sys.argv[1]); print(c.execute(""SELECT value FROM metadata WHERE key='extractor_signature_version'"").fetchone()[0])" $sqlitePath
Assert-True ($metaVersion -eq '12') "extractor_signature_version esperado 12; obtido $metaVersion"

$rows = Get-BasedOnDomainRows -SqlitePath $sqlitePath

# G.2.1
$r = @(Find-Rows -Rows $rows -SourceType 'SDT' -SourceName 'SdtUsesDomAlpha' -TargetName 'DomAlpha' -Rule 'object_idbasedon_domain')
Assert-True ($r.Count -eq 1) "G.2.1 SDT->DomAlpha esperado 1; obtido $($r.Count)"

# G.2.2
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcUsesDomains' -TargetName 'DomBeta' -Rule 'object_idbasedon_domain')
Assert-True ($r.Count -eq 1) "G.2.2 Procedure->DomBeta esperado 1; obtido $($r.Count)"

# G.2.3 Attribute + Procedure modulo
$r = @(Find-Rows -Rows $rows -SourceType 'Attribute' -SourceName 'AttrUsesDomMod' -TargetName 'DomMod' -Rule 'attribute_idbasedon_domain')
Assert-True ($r.Count -eq 1) "G.2.3 Attribute modulo esperado 1; obtido $($r.Count)"
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcUsesDomMod' -TargetName 'DomMod' -Rule 'object_idbasedon_domain')
Assert-True ($r.Count -eq 1) "G.2.3 Procedure modulo esperado 1; obtido $($r.Count)"

# G.2.4 dedup multi-ocorrencia DomPairA
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcUsesDomains' -TargetName 'DomPairA')
Assert-True ($r.Count -eq 1) "G.2.4 dedup DomPairA esperado 1; obtido $($r.Count)"
Assert-True ($r[0].line -gt 0) "G.2.4 linha da primeira evidencia"

# G.2.5 pares distintos
$rA = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcUsesDomains' -TargetName 'DomPairA')
$rB = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcUsesDomains' -TargetName 'DomPairB')
Assert-True (($rA.Count -eq 1) -and ($rB.Count -eq 1)) "G.2.5 pares distintos DomPairA/B"

# G.2.6 short+mod com fqfn -> 1
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcDedupShortAndMod' -TargetName 'DomDedup')
Assert-True ($r.Count -eq 1) "G.2.6 dedup short+mod esperado 1; obtido $($r.Count)"

# G.2.6b sem fqfn: so short
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcNoFqfnMod' -TargetName 'DomNoFqfn')
Assert-True ($r.Count -eq 1) "G.2.6b sem fqfn esperado 1 (so short); obtido $($r.Count)"

# G.2.7 Attribute: nenhuma based_on_domain
$r = @(Find-Rows -Rows $rows -SourceType 'Attribute' -SourceName 'AttrBasedOnAttribute')
Assert-True ($r.Count -eq 0) "G.2.7 Attribute: nao deve gerar based_on_domain"

# G.2.8 divergente
$r = @(Find-Rows -Rows $rows -SourceType 'Attribute' -SourceName 'AttrDivergentMod')
Assert-True ($r.Count -eq 0) "G.2.8 modulo divergente nao resolve"

# G.2.10 nested
$rOk = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcNestedFqfn' -TargetName 'NestedLeaf')
Assert-True ($rOk.Count -eq 1) "G.2.10 A.B.NestedLeaf resolve; obtido $($rOk.Count)"

# G.2.11 case
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcCaseFold' -TargetName 'DomCase')
Assert-True ($r.Count -eq 1) "G.2.11 lower() case"

# G.2.12 espacamentos -> 1 aresta DomSpace (duas vars, dedup)
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcUsesDomains' -TargetName 'DomSpace')
Assert-True ($r.Count -eq 1) "G.2.12 espacamentos DomSpace esperado 1; obtido $($r.Count)"

# G.2.13 borders
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcBorders')
Assert-True ($r.Count -eq 0) "G.2.13 bordas nao resolvem"

# G.2.14 CDATA: uma aresta; linha apos CDATA (nao a linha do texto dentro do CDATA)
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcCdataMask' -TargetName 'DomCdata')
Assert-True ($r.Count -eq 1) "G.2.14 CDATA esperado 1 aresta real; obtido $($r.Count)"
$cdataText = Get-Content -LiteralPath (Join-Path $procedureDir 'ProcCdataMask.xml') -Raw
$realMatch = [regex]::Match($cdataText, '<Variable Name="VReal">[\s\S]*?<Name>idBasedOn</Name>\s*<Value>Domain:DomCdata</Value>')
Assert-True $realMatch.Success "G.2.14 localizar ocorrencia real"
$expectedLine = ($cdataText.Substring(0, $realMatch.Index + $realMatch.Value.IndexOf('Domain:DomCdata')).Split("`n").Count)
Assert-True ($r[0].line -eq $expectedLine) "G.2.14 linha do cru esperado $expectedLine; obtido $($r[0].line)"

# G.2.15 comment: uma aresta (a real)
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcCommentMask' -TargetName 'DomComment')
Assert-True ($r.Count -eq 1) "G.2.15 comentario esperado 1; obtido $($r.Count)"

# G.2.14b combinacao CDATA+comentario bem-formada: so a aresta real (fora do CDATA)
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcCdataCommentCombo' -TargetName 'DomCombo')
Assert-True ($r.Count -eq 1) "G.2.14b combo esperado 1 aresta real; obtido $($r.Count)"
Assert-True ($r[0].extractor_rule -eq 'object_idbasedon_domain') "G.2.14b regra object_idbasedon_domain"

# G.2.14c patogenico: Property entre ]]> e --> permanece visivel (comentario nao engole apos CDATA)
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcCdataCommentPatho' -TargetName 'DomPatho')
Assert-True ($r.Count -eq 1) "G.2.14c patogenico esperado 1 aresta real; obtido $($r.Count)"

# G.2.14d comentario cita <![CDATA[: DomLeak no comentario nao vaza; DomSym real fora sim
$rLeak = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcCommentCdataLiteral' -TargetName 'DomLeak')
Assert-True ($rLeak.Count -eq 0) "G.2.14d DomLeak no comentario nao deve vazar; obtido $($rLeak.Count)"
$rSym = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcCommentCdataLiteral' -TargetName 'DomSym')
Assert-True ($rSym.Count -eq 1) "G.2.14d DomSym real esperado 1; obtido $($rSym.Count)"

# G.2.16 &#xA;
$r = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcEntityNewline' -TargetName 'DomNewline')
Assert-True ($r.Count -eq 1) "G.2.16 entidade newline resolve; obtido $($r.Count)"
$nlText = Get-Content -LiteralPath (Join-Path $procedureDir 'ProcEntityNewline.xml') -Raw
$nlMatch = [regex]::Match($nlText, '<Name>idBasedOn</Name>\s*<Value>Domain:DomNewline')
$nlLine = ($nlText.Substring(0, $nlMatch.Index).Split("`n").Count)
Assert-True ($r[0].line -eq $nlLine) "G.2.16 linha cravada esperado $nlLine; obtido $($r[0].line)"

# G.2.17 snippet persistido = compact_snippet do cru + G.2.19 regressao Attribute
$rY = @(Find-Rows -Rows $rows -SourceType 'Attribute' -SourceName 'AttrUsesDomY' -TargetName 'DomY' -Rule 'attribute_idbasedon_domain')
Assert-True ($rY.Count -eq 1) "G.2.17/19 AttrUsesDomY"
$yText = Get-Content -LiteralPath (Join-Path $attributeDir 'AttrUsesDomY.xml') -Raw
$yMatch = [regex]::Match($yText, '<Property>\s*<Name>idBasedOn</Name>\s*<Value>Domain:DomY</Value>\s*</Property>', 'IgnoreCase,Singleline')
Assert-True $yMatch.Success "G.2.17 match cru"
$expectedSnippet = Get-CompactSnippet -Text $yMatch.Value
Assert-True ($rY[0].snippet -eq $expectedSnippet) "G.2.17 snippet persistido diverge: got='$($rY[0].snippet)' expected='$expectedSnippet'"
Assert-True ($rY[0].column -eq 1) "G.2.17 column=1"
Assert-True ($rY[0].evidence_role -eq 'Property idBasedOn') "G.2.17 evidence_role"
Assert-True ($rY[0].confidence -eq 'direct') "G.2.17 confidence"
$valueIdx = $yText.IndexOf('Domain:DomY')
$yLineExact = ($yText.Substring(0, $valueIdx).Split("`n").Count)
Assert-True ($rY[0].line -eq $yLineExact) "G.2.19 linha Attribute esperado $yLineExact; obtido $($rY[0].line)"
Assert-True ($rY[0].extractor_rule -eq 'attribute_idbasedon_domain') "G.2.19 regra Attribute"

# G.2.18 Panel
$rPanel = @(Find-Rows -Rows $rows -SourceType 'Panel' -SourceName 'PanelWithIdBasedOn')
Assert-True ($rPanel.Count -eq 0) "G.2.18 Panel fora do escopo"

# G.2.21 tipos restantes do escopo (1 aresta object_idbasedon_domain cada)
$scopeCases = @(
    @{ Type = 'WebPanel'; Name = 'WpUsesDomScope' },
    @{ Type = 'Transaction'; Name = 'TrnUsesDomScope' },
    @{ Type = 'DataProvider'; Name = 'DpUsesDomScope' },
    @{ Type = 'API'; Name = 'ApiUsesDomScope' },
    @{ Type = 'DataSelector'; Name = 'DsUsesDomScope' },
    @{ Type = 'WorkWith'; Name = 'WwUsesDomScope' },
    @{ Type = 'WorkWithForWeb'; Name = 'WwWebUsesDomScope' },
    @{ Type = 'Domain'; Name = 'DomUsesDomScope' }
)
foreach ($sc in $scopeCases) {
    $r = @(Find-Rows -Rows $rows -SourceType $sc.Type -SourceName $sc.Name -TargetName 'DomScope' -Rule 'object_idbasedon_domain')
    Assert-True ($r.Count -eq 1) "G.2.21 $($sc.Type):$($sc.Name)->DomScope esperado 1; obtido $($r.Count)"
}

# G.2.20 require_property_in_source: real passa; so-comentario falha a precondicao (nao passa em vacuo)
$report = Get-Content -LiteralPath $validationPath -Raw | ConvertFrom-Json
$caseReal = @($report.cases | Where-Object { $_.id -eq 'g2-require-property-real' })[0]
$caseComment = @($report.cases | Where-Object { $_.id -eq 'g2-require-property-comment-only' })[0]
Assert-True ($null -ne $caseReal) "G.2.20 caso real ausente no relatório"
Assert-True ($null -ne $caseComment) "G.2.20 caso comment-only ausente no relatório"
Assert-True ($caseReal.status -eq 'passed') "G.2.20 require real esperado passed; obtido $($caseReal.status)"
Assert-True ($caseComment.status -eq 'failed') "G.2.20 require comment-only esperado failed; obtido $($caseComment.status)"
$failText = [string]::Join(' | ', @($caseComment.failures))
Assert-True ($failText -match 'require_property_in_source') "G.2.20 falha esperada require_property_in_source; obtido: $failText"
$rReq = @(Find-Rows -Rows $rows -SourceType 'Procedure' -SourceName 'ProcReqPropCommentOnly' -TargetName 'DomReqMask')
Assert-True ($rReq.Count -eq 0) "G.2.20 extrator nao deve emitir aresta de Property so em comentario"

Write-Output 'OK: Test-KbIntelligenceIdBasedOnDomainSelfTest.ps1'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
