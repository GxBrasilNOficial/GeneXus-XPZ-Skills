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
$frontExplicitNewer = Join-Path $tempRoot 'FrontExplicitNewer'
$frontExplicitNewerDryRun = Join-Path $tempRoot 'FrontExplicitNewerDryRun'
[void](New-Item -ItemType Directory -Path $procedureDir, $frontEmpty, $frontSeed, $frontSeedObjectList, $frontSeedGuid, $frontMissing, $frontTypeDrift, $frontExplicitNewer, $frontExplicitNewerDryRun -Force)

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

$explicitNewerName = 'procExplicitNewer'
$explicitNewerGuid = '44444444-4444-4444-4444-444444444444'
$explicitNewerAcervoXml = New-FixtureObjectXml -Name $explicitNewerName -Guid $explicitNewerGuid -LastUpdate '2026-01-01T00:00:00.0000000Z'
$explicitNewerFrontXml = New-FixtureObjectXml -Name $explicitNewerName -Guid $explicitNewerGuid -LastUpdate '2026-03-01T00:00:00.0000000Z'
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$explicitNewerName.xml"), $explicitNewerAcervoXml, (Get-Utf8NoBomEncoding))
$explicitNewerFrontPath = Join-Path $frontExplicitNewer "$explicitNewerName.xml"
[System.IO.File]::WriteAllText($explicitNewerFrontPath, $explicitNewerFrontXml, (Get-Utf8NoBomEncoding))
$explicitUnlistedName = 'procExplicitUnlisted'
$explicitUnlistedGuid = '55555555-5555-5555-5555-555555555555'
$explicitUnlistedAcervoXml = New-FixtureObjectXml -Name $explicitUnlistedName -Guid $explicitUnlistedGuid -LastUpdate '2026-01-01T00:00:00.0000000Z'
$explicitUnlistedFrontXml = New-FixtureObjectXml -Name $explicitUnlistedName -Guid $explicitUnlistedGuid -LastUpdate '2026-04-01T00:00:00.0000000Z'
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$explicitUnlistedName.xml"), $explicitUnlistedAcervoXml, (Get-Utf8NoBomEncoding))
$explicitUnlistedFrontPath = Join-Path $frontExplicitNewer "$explicitUnlistedName.xml"
[System.IO.File]::WriteAllText($explicitUnlistedFrontPath, $explicitUnlistedFrontXml, (Get-Utf8NoBomEncoding))
$explicitNewerResult = & $scriptPath -FrontFolder $frontExplicitNewer -AcervoFolder $acervo -ObjectList "Procedure:$explicitNewerName" | ConvertFrom-Json
if ($explicitNewerResult.status -ne 'pass') {
    throw "Reconstrucao explicita de frente mais nova deveria retornar pass; obtido $($explicitNewerResult.status)"
}
$explicitNewerFinding = @($explicitNewerResult.findings | Where-Object { $_.code -eq 'copied-and-bumped' -and $_.objectName -eq $explicitNewerName })
if ($explicitNewerFinding.Count -ne 1) {
    throw "Reconstrucao explicita de frente mais nova deveria gerar copied-and-bumped; obtido $($explicitNewerFinding.Count)"
}
$explicitNewerText = Get-Content -LiteralPath $explicitNewerFrontPath -Raw -Encoding UTF8
if ($explicitNewerText -match 'lastUpdate="2026-03-01T00:00:00.0000000Z"') {
    throw 'Reconstrucao explicita nao deveria preservar o lastUpdate antigo da frente mais nova.'
}
$explicitUnlistedText = Get-Content -LiteralPath $explicitUnlistedFrontPath -Raw -Encoding UTF8
if ($explicitUnlistedText -notmatch 'lastUpdate="2026-04-01T00:00:00.0000000Z"') {
    throw 'Reconstrucao explicita nao deveria sobrescrever objeto mais novo fora do alvo listado.'
}
$explicitUnlistedFinding = @($explicitNewerResult.findings | Where-Object { $_.objectName -eq $explicitUnlistedName })
if ($explicitUnlistedFinding.Count -ne 0) {
    throw "Reconstrucao explicita nao deveria gerar finding para objeto fora do alvo listado; obtido $($explicitUnlistedFinding.Count)"
}

$explicitNewerDryRunFrontPath = Join-Path $frontExplicitNewerDryRun "$explicitNewerName.xml"
[System.IO.File]::WriteAllText($explicitNewerDryRunFrontPath, $explicitNewerFrontXml, (Get-Utf8NoBomEncoding))
$explicitNewerDryRunResult = & $scriptPath -FrontFolder $frontExplicitNewerDryRun -AcervoFolder $acervo -ObjectList "Procedure:$explicitNewerName" -DryRun | ConvertFrom-Json
if ($explicitNewerDryRunResult.status -ne 'pass') {
    throw "DryRun de reconstrucao explicita de frente mais nova deveria retornar pass; obtido $($explicitNewerDryRunResult.status)"
}
$explicitNewerDryRunFinding = @($explicitNewerDryRunResult.findings | Where-Object { $_.code -eq 'dry-run-copy' -and $_.objectName -eq $explicitNewerName })
if ($explicitNewerDryRunFinding.Count -ne 1) {
    throw "DryRun de reconstrucao explicita deveria gerar dry-run-copy; obtido $($explicitNewerDryRunFinding.Count)"
}
$explicitNewerDryRunText = Get-Content -LiteralPath $explicitNewerDryRunFrontPath -Raw -Encoding UTF8
if ($explicitNewerDryRunText -notmatch 'lastUpdate="2026-03-01T00:00:00.0000000Z"') {
    throw 'DryRun de reconstrucao explicita nao deveria gravar sobre frente mais nova.'
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

$typeDriftExplicitResult = & $scriptPath -FrontFolder $frontTypeDrift -AcervoFolder $acervo -ObjectList "Procedure:$typeDriftName" | ConvertFrom-Json
if ($typeDriftExplicitResult.status -ne 'fail') {
    throw 'Alvo explicito nao deveria furar bloqueio de Object/@type divergente.'
}
$typeDriftExplicitFinding = @($typeDriftExplicitResult.findings | Where-Object { $_.code -eq 'front-object-type-drift-skip' -and $_.objectName -eq $typeDriftName })
if ($typeDriftExplicitFinding.Count -ne 1) {
    throw 'Alvo explicito deveria manter finding front-object-type-drift-skip.'
}
$typeDriftExplicitFrontText = Get-Content -LiteralPath $typeDriftFrontPath -Raw -Encoding UTF8
if ($typeDriftExplicitFrontText -notmatch [regex]::Escape("type=`"$webPanelTypeGuid`"")) {
    throw 'Alvo explicito com Object/@type divergente nao deveria sobrescrever a frente.'
}

Write-Output 'OK: Test-CopyGeneXusAcervoToFrontSelfTest.ps1'
exit 0
