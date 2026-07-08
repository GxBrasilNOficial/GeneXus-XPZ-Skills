#requires -Version 7.4
<#
.SYNOPSIS
    Self-test mínimo para Copy-GeneXusAcervoToFront.ps1.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function New-FixtureObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$LastUpdate,
        [string]$TypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
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

$scriptPath = Join-Path $PSScriptRoot 'Copy-GeneXusAcervoToFront.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('copy-acervo-front-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$acervo = Join-Path $tempRoot 'ObjetosDaKbEmXml'
$procedureDir = Join-Path $acervo 'Procedure'
$frontEmpty = Join-Path $tempRoot 'FrontEmpty'
$frontSeed = Join-Path $tempRoot 'FrontSeed'
$frontSeedObjectList = Join-Path $tempRoot 'FrontSeedObjectList'
$frontSeedGuid = Join-Path $tempRoot 'FrontSeedGuid'
$frontMissing = Join-Path $tempRoot 'FrontMissing'
$frontTypeDrift = Join-Path $tempRoot 'FrontTypeDrift'
[void](New-Item -ItemType Directory -Path $procedureDir, $frontEmpty, $frontSeed, $frontSeedObjectList, $frontSeedGuid, $frontMissing, $frontTypeDrift -Force)

$objName = 'procSeedTeste'
$objGuid = '11111111-1111-1111-1111-111111111111'
$procedureTypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$webPanelTypeGuid = '7a7686a8-90de-4598-9406-014bcbcf3d82'
$objXml = New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate '2026-01-01T00:00:00.0000000Z'
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$objName.xml"), $objXml, (Get-Utf8NoBomEncoding))

$objGuidName = 'procSeedPorGuid'
$objGuidOnly = '22222222-2222-2222-2222-222222222222'
$objGuidXml = New-FixtureObjectXml -Name $objGuidName -Guid $objGuidOnly -LastUpdate '2026-01-02T00:00:00.0000000Z'
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$objGuidName.xml"), $objGuidXml, (Get-Utf8NoBomEncoding))

$emptyResult = & $scriptPath -FrontFolder $frontEmpty -AcervoFolder $acervo | ConvertFrom-Json
if ($emptyResult.status -ne 'not-applicable') {
    throw "Frente vazia sem alvo explicito deveria retornar not-applicable; obtido $($emptyResult.status)"
}
if ((Test-Path -LiteralPath (Join-Path $frontEmpty "$objName.xml") -PathType Leaf)) {
    throw 'Frente vazia sem alvo explicito nao deveria receber seed.'
}

$seedResult = & $scriptPath -FrontFolder $frontSeed -AcervoFolder $acervo -ObjectNames $objName | ConvertFrom-Json
if ($seedResult.status -ne 'pass') {
    throw "Seed explicito deveria retornar pass; obtido $($seedResult.status)"
}
$seedFinding = @($seedResult.findings | Where-Object { $_.code -eq 'seeded-and-bumped' })
if ($seedFinding.Count -ne 1) {
    throw "Seed explicito deveria gerar uma finding seeded-and-bumped; obtido $($seedFinding.Count)"
}
$seededPath = Join-Path $frontSeed "$objName.xml"
if (-not (Test-Path -LiteralPath $seededPath -PathType Leaf)) {
    throw 'Seed explicito nao criou XML na frente.'
}
$seededText = Get-Content -LiteralPath $seededPath -Raw -Encoding UTF8
if ($seededText -notmatch 'lastUpdate="([^"]+)"') {
    throw 'XML semeado nao contem lastUpdate.'
}
if ($Matches[1] -eq '2026-01-01T00:00:00.0000000Z') {
    throw 'Seed explicito deveria bumpar lastUpdate acima do acervo.'
}

$seedObjectListResult = & $scriptPath -FrontFolder $frontSeedObjectList -AcervoFolder $acervo -ObjectList "Procedure:$objName" | ConvertFrom-Json
if ($seedObjectListResult.status -ne 'pass') {
    throw "Seed explicito via ObjectList deveria retornar pass; obtido $($seedObjectListResult.status)"
}
$seedObjectListFinding = @($seedObjectListResult.findings | Where-Object { $_.code -eq 'seeded-and-bumped' -and $_.objectName -eq $objName })
if ($seedObjectListFinding.Count -ne 1) {
    throw "Seed via ObjectList deveria gerar uma finding seeded-and-bumped; obtido $($seedObjectListFinding.Count)"
}
if (-not (Test-Path -LiteralPath (Join-Path $frontSeedObjectList "$objName.xml") -PathType Leaf)) {
    throw 'Seed via ObjectList nao criou XML na frente.'
}

$seedGuidResult = & $scriptPath -FrontFolder $frontSeedGuid -AcervoFolder $acervo -ObjectGuids $objGuidOnly | ConvertFrom-Json
if ($seedGuidResult.status -ne 'pass') {
    throw "Seed explicito por GUID deveria retornar pass; obtido $($seedGuidResult.status)"
}
$seedGuidFinding = @($seedGuidResult.findings | Where-Object { $_.code -eq 'seeded-and-bumped' -and $_.objectGuid -eq $objGuidOnly })
if ($seedGuidFinding.Count -ne 1) {
    throw "Seed explicito por GUID deveria gerar uma finding seeded-and-bumped; obtido $($seedGuidFinding.Count)"
}
if (-not (Test-Path -LiteralPath (Join-Path $frontSeedGuid "$objGuidName.xml") -PathType Leaf)) {
    throw 'Seed explicito por GUID nao criou XML na frente.'
}

$missingResult = & $scriptPath -FrontFolder $frontMissing -AcervoFolder $acervo -ObjectNames 'procInexistente' | ConvertFrom-Json
if ($missingResult.status -ne 'fail') {
    throw "Seed de alvo inexistente deveria retornar fail; obtido $($missingResult.status)"
}
$missingFinding = @($missingResult.findings | Where-Object { $_.code -eq 'seed-target-not-found' })
if ($missingFinding.Count -ne 1) {
    throw "Seed de alvo inexistente deveria gerar seed-target-not-found; obtido $($missingFinding.Count)"
}

$typeDriftName = 'procTypeDrift'
$typeDriftGuid = '33333333-3333-3333-3333-333333333333'
$typeDriftAcervoXml = New-FixtureObjectXml -Name $typeDriftName -Guid $typeDriftGuid -LastUpdate '2026-02-01T00:00:00.0000000Z' -TypeGuid $procedureTypeGuid
$typeDriftFrontXml = New-FixtureObjectXml -Name $typeDriftName -Guid $typeDriftGuid -LastUpdate '2026-01-01T00:00:00.0000000Z' -TypeGuid $webPanelTypeGuid
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$typeDriftName.xml"), $typeDriftAcervoXml, (Get-Utf8NoBomEncoding))
$typeDriftFrontPath = Join-Path $frontTypeDrift "$typeDriftName.xml"
[System.IO.File]::WriteAllText($typeDriftFrontPath, $typeDriftFrontXml, (Get-Utf8NoBomEncoding))
$typeDriftResult = & $scriptPath -FrontFolder $frontTypeDrift -AcervoFolder $acervo | ConvertFrom-Json
if ($typeDriftResult.status -ne 'fail') {
    throw "Drift de Object/@type deveria bloquear autocopia com status fail; obtido $($typeDriftResult.status)"
}
$typeDriftFinding = @($typeDriftResult.findings | Where-Object { $_.code -eq 'front-object-type-drift-skip' })
if ($typeDriftFinding.Count -ne 1) {
    throw "Drift de Object/@type deveria gerar front-object-type-drift-skip; obtido $($typeDriftFinding.Count)"
}
$typeDriftFrontText = Get-Content -LiteralPath $typeDriftFrontPath -Raw -Encoding UTF8
if ($typeDriftFrontText -notmatch [regex]::Escape("type=`"$webPanelTypeGuid`"")) {
    throw 'Drift de Object/@type nao deveria copiar o XML do acervo sobre a frente.'
}

Write-Output 'OK: Test-CopyGeneXusAcervoToFrontSelfTest.ps1'
exit 0
