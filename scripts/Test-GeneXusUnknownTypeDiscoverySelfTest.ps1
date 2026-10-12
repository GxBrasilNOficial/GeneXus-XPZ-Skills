#requires -Version 7.4

<#
.SYNOPSIS
    Bateria mínima para descoberta de tipos desconhecidos e override de catalogo.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'GeneXusObjectTypeCatalogSupport.ps1')

$unknownGuid = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
$knownProcedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'

$exportXml = @"
<ExportFile>
  <Objects>
    <Object type="$unknownGuid" name="ObjNovo" parent="FolderX" parentType="00000000-0000-0000-0000-000000000004" guid="11111111-1111-1111-1111-111111111101">
      <Source />
    </Object>
    <Object type="$knownProcedureGuid" name="ProcOk" guid="11111111-1111-1111-1111-111111111102">
      <Source />
    </Object>
  </Objects>
</ExportFile>
"@

$doc = New-Object System.Xml.XmlDocument
$doc.PreserveWhitespace = $true
$doc.LoadXml($exportXml)

$resolution = Resolve-GeneXusObjectTypeCatalogPaths -BaseCatalogPath (Join-Path $scriptDir 'gx-object-type-catalog.json')
$folderMap = Get-GeneXusCatalogGuidToFolderMap -MergedCatalog $resolution.MergedCatalog
$unknown = @(Get-GeneXusUnknownObjectTypesFromExportFile -XmlDocument $doc -GuidToFolderMap $folderMap)

if ($unknown.Count -ne 1) {
    throw "esperado 1 tipo desconhecido; obtido $($unknown.Count)"
}
if ($unknown[0].unknownObjectTypeGuid -ne $unknownGuid) {
    throw 'GUID desconhecido divergente'
}
if ($unknown[0].count -ne 1) {
    throw 'count esperado 1'
}
if ($unknown[0].sampleNames[0] -ne 'ObjNovo') {
    throw 'sampleNames esperado ObjNovo'
}
if ($unknown[0].sampleParents[0] -ne 'FolderX') {
    throw 'sampleParents esperado FolderX'
}
if ($unknown[0].sampleXmlSnippets.Count -lt 1) {
    throw 'sampleXmlSnippets esperado'
}

$message = Format-GeneXusUnknownObjectTypesErrorMessage -UnknownTypes $unknown -OverrideActive $false
if ($message -notmatch 'ObjNovo') {
    throw 'mensagem de erro deve incluir nome de amostra'
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-unknown-discovery-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$scriptsDir = Join-Path $parallelRoot 'scripts'
[void](New-Item -ItemType Directory -Path $scriptsDir -Force)

& (Join-Path $scriptDir 'Register-GeneXusObjectTypeCatalogOverride.ps1') `
    -ParallelKbRoot $parallelRoot `
    -TypeName 'TipoTeste' `
    -ObjectTypeGuid $unknownGuid `
    -FolderName 'TipoTeste' `
    -UserApproved `
    -EvidenceSummary 'self-test' | Out-Null

$reminderScript = Join-Path $scriptDir 'Test-XpzCatalogOverrideSessionReminder.ps1'
$reminderJson = & $reminderScript -ParallelKbRoot $parallelRoot -AsJson | ConvertFrom-Json
if (-not $reminderJson.reminderRequired) {
    throw 'reminderRequired esperado true apos override'
}
if ($reminderJson.status -ne 'REMINDER_REQUIRED') {
    throw "status esperado REMINDER_REQUIRED; obtido $($reminderJson.status)"
}

$mergedResolution = Resolve-GeneXusObjectTypeCatalogPaths -ParallelKbRoot $parallelRoot
$mergedMap = Get-GeneXusCatalogGuidToFolderMap -MergedCatalog $mergedResolution.MergedCatalog
if (-not $mergedMap.ContainsKey($unknownGuid)) {
    throw 'override deveria mapear GUID desconhecido'
}

$xmlPath = Join-Path $tempRoot 'package.xml'
[System.IO.File]::WriteAllText($xmlPath, $exportXml, (Get-Utf8NoBomEncoding))
$inventoryScript = Join-Path $scriptDir 'Get-GeneXusImportPackageObjectInventory.ps1'
$invBlocked = & $inventoryScript -InputPath $xmlPath -ParallelKbRoot $parallelRoot | ConvertFrom-Json
if ($invBlocked.unknownTypeCount -ne 0) {
    throw 'com override, unknownTypeCount deveria ser 0'
}

$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$tipoDir = Join-Path $objetosPath 'TipoTeste'
[void](New-Item -ItemType Directory -Path $tipoDir -Force)
$sampleObjectXml = @"
<Object type="$unknownGuid" name="ObjNovo" guid="11111111-1111-1111-1111-111111111199">
  <Source />
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $tipoDir 'ObjNovo.xml'), $sampleObjectXml, (Get-Utf8NoBomEncoding))

$namingScript = Join-Path $scriptDir 'Test-XpzObjetosDaKbNaming.ps1'
$namingJson = & $namingScript -ParallelKbRoot $parallelRoot -AsJson | ConvertFrom-Json
if ($namingJson.status -ne 'NAMING_OK') {
    throw "naming esperado NAMING_OK com override; obtido $($namingJson.status)"
}

$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $kbIntelDir -Force)
$sqlitePath = Join-Path $kbIntelDir 'kb-intelligence.sqlite'
$validationPath = Join-Path $kbIntelDir 'kb-intelligence-validation.json'
$indexScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'
& $indexScript `
    -SourceRoot $objetosPath `
    -OutputPath $sqlitePath `
    -ValidationReportPath $validationPath `
    -ParallelKbRoot $parallelRoot
if ($LASTEXITCODE -ne 0) {
    throw "Build-KbIntelligenceIndex com override deveria passar; exit $LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $sqlitePath -PathType Leaf)) {
    throw 'SQLite do indice nao foi gerado com override'
}

Write-Output 'OK: Test-GeneXusUnknownTypeDiscoverySelfTest.ps1'
exit 0
