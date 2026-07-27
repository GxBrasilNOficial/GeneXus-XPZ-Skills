#requires -Version 7.4
<#
.SYNOPSIS
    Bateria mínima para Get-GeneXusImportPackageObjectInventory.ps1 (XML e .xpz sintetico).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = $PSScriptRoot
$inventoryScript = Join-Path $scriptDir 'Get-GeneXusImportPackageObjectInventory.ps1'
# Export real GeneXus 18: módulos SDK/plataforma entram como PackagedModule, não Module.
$packagedModuleGuid = 'c88fffcd-b6f8-0000-8fec-00b5497e2117'
$procedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$externalObjectGuid = 'c163e562-42c6-4158-ad83-5b21a14cf30e'
$transactionGuid = '1db606f2-af09-4cf9-a3b5-b481519d28f6'
$workWithGuid = '15cf49b5-fc38-4899-91b5-395d02d79889'
$workWithForWebGuid = '78cecefe-be7d-4980-86ce-8d6e91fba04b'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-import-inventory-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$exportXml = @"
<ExportFile>
  <Objects>
    <Object type="$packagedModuleGuid" name="GeneXus" guid="11111111-1111-1111-1111-111111111101" />
    <Object type="$procedureGuid" name="ProcPedida" guid="11111111-1111-1111-1111-111111111102" />
    <Object type="$procedureGuid" name="ProcExtra" guid="11111111-1111-1111-1111-111111111103" />
    <Object type="$externalObjectGuid" name="Camera" guid="11111111-1111-1111-1111-111111111104" />
  </Objects>
  <Attributes>
    <Attribute name="AttrA" guid="22222222-2222-2222-2222-222222222201" />
    <Attribute name="AttrB" guid="22222222-2222-2222-2222-222222222202" />
  </Attributes>
</ExportFile>
"@

$xmlPath = Join-Path $tempRoot 'package.import_file.xml'
[System.IO.File]::WriteAllText($xmlPath, $exportXml, (Get-Utf8NoBomEncoding))

$result = (& $inventoryScript -InputPath $xmlPath -DeclaredDeltaItems 'Procedure:ProcPedida' | ConvertFrom-Json)
if ($result.objectCount -ne 4) { throw "objectCount esperado 4; obtido $($result.objectCount)" }
if ($result.attributeCount -ne 2) { throw 'attributeCount esperado 2' }
if (-not $result.selectiveExport) { throw 'selectiveExport esperado true' }
if ($result.status -ne 'DELTA_MISMATCH') { throw "status esperado DELTA_MISMATCH; obtido $($result.status)" }
if ($result.deltaComparison.extraCount -ne 3) {
    throw "extraCount esperado 3 (PackagedModule:GeneXus + ProcExtra + Camera); obtido $($result.deltaComparison.extraCount)"
}
if (@($result.systemObjectsPresent).Count -ne 2) {
    throw "systemObjectsPresent esperado 2 (GeneXus + Camera); obtido $(@($result.systemObjectsPresent).Count)"
}
$gxPresent = @($result.systemObjectsPresent | Where-Object { $_.name -eq 'GeneXus' -and $_.kind -eq 'packagedModule' })
if ($gxPresent.Count -ne 1) { throw 'packagedModule GeneXus esperado em systemObjectsPresent' }
$camPresent = @($result.systemObjectsPresent | Where-Object { $_.name -eq 'Camera' -and $_.kind -eq 'externalObject' })
if ($camPresent.Count -ne 1) { throw 'externalObject Camera esperado em systemObjectsPresent' }
$genexusItem = @($result.inventory | Where-Object { $_.name -eq 'GeneXus' } | Select-Object -First 1)
if ($genexusItem.typeName -ne 'PackagedModule') {
    throw "tipo esperado PackagedModule para GeneXus; obtido $($genexusItem.typeName)"
}
if (-not $result.attributesTopLevelUnreconciled) {
    throw 'attributesTopLevelUnreconciled esperado true sem Transaction na lista'
}
if ($result.declaredIncludesTransaction) {
    throw 'declaredIncludesTransaction esperado false'
}
$attrWarning = @($result.warnings | Where-Object { $_ -match 'attributes-top-level-em-export-cirurgico' })
if ($attrWarning.Count -ne 1) {
    throw 'warning attributes-top-level-em-export-cirurgico esperado 1'
}
if ($result.inputKind -ne 'xml') { throw 'inputKind xml esperado' }

$selectiveWithTransactionXml = @"
<ExportFile>
  <Objects>
    <Object type="$transactionGuid" name="TrPedida" guid="33333333-3333-3333-3333-333333333301" />
  </Objects>
  <Attributes>
    <Attribute name="AttrC" guid="44444444-4444-4444-4444-444444444401" />
  </Attributes>
</ExportFile>
"@
$trnXmlPath = Join-Path $tempRoot 'package-trn.import_file.xml'
[System.IO.File]::WriteAllText($trnXmlPath, $selectiveWithTransactionXml, (Get-Utf8NoBomEncoding))
$resultTrn = (& $inventoryScript -InputPath $trnXmlPath -DeclaredDeltaItems 'Transaction:TrPedida' | ConvertFrom-Json)
if (-not $resultTrn.declaredIncludesTransaction) { throw 'declaredIncludesTransaction esperado true com Transaction na lista' }
if ($resultTrn.attributesTopLevelUnreconciled) {
    throw 'attributesTopLevelUnreconciled deve ser false quando Transaction esta na lista (controle negativo)'
}
$trnAttrWarning = @($resultTrn.warnings | Where-Object { $_ -match 'attributes-top-level-em-export-cirurgico' })
if ($trnAttrWarning.Count -gt 0) {
    throw 'nao deve haver warning de atributos top-level com Transaction na lista declarada'
}

$xpzPath = Join-Path $tempRoot 'package.xpz'
Compress-Archive -LiteralPath $xmlPath -DestinationPath $xpzPath -Force
$resultXpz = (& $inventoryScript -InputPath $xpzPath -DeclaredDeltaItems 'Procedure:ProcPedida' | ConvertFrom-Json)
if ($resultXpz.inputKind -ne 'xpz') { throw 'inputKind xpz esperado' }
if ($resultXpz.objectCount -ne 4) { throw 'objectCount xpz esperado 4' }
if (@($resultXpz.systemObjectsPresent).Count -ne 2) { throw 'systemObjectsPresent xpz esperado 2' }

$full = (& $inventoryScript -InputPath $xmlPath | ConvertFrom-Json)
if ($full.selectiveExport) { throw 'selectiveExport deve ser false sem delta' }
if ($null -ne $full.deltaComparison) { throw 'deltaComparison deve ser nulo sem delta' }

$exportLabelXml = @"
<ExportFile>
  <Objects>
    <Object type="$workWithForWebGuid" name="MainWW" guid="55555555-5555-5555-5555-555555555501" />
    <Object type="$procedureGuid" name="ProcExtra" guid="55555555-5555-5555-5555-555555555502" />
  </Objects>
</ExportFile>
"@
$exportLabelPath = Join-Path $tempRoot 'package-export-label.import_file.xml'
[System.IO.File]::WriteAllText($exportLabelPath, $exportLabelXml, (Get-Utf8NoBomEncoding))
$resultAlias = (& $inventoryScript -InputPath $exportLabelPath -DeclaredDeltaItems 'WorkWith:MainWW' | ConvertFrom-Json)
if ($resultAlias.status -ne 'DELTA_MISMATCH') {
    throw "status esperado DELTA_MISMATCH (ProcExtra extra); obtido $($resultAlias.status)"
}
if ($resultAlias.deltaComparison.missingCount -ne 0) {
    throw "missingCount esperado 0 com alias exportTaskLabel; obtido $($resultAlias.deltaComparison.missingCount)"
}
if ($resultAlias.deltaComparison.aliasResolutionCount -ne 1) {
    throw "aliasResolutionCount esperado 1; obtido $($resultAlias.deltaComparison.aliasResolutionCount)"
}
$alias = @($resultAlias.deltaComparison.aliasResolutions)[0]
if ($alias.rule -ne 'exportTaskLabel') { throw "alias rule esperado exportTaskLabel; obtido $($alias.rule)" }
if ($alias.declaredTypeName -ne 'WorkWith' -or $alias.inventoryTypeName -ne 'WorkWithForWeb') {
    throw 'alias deve ligar WorkWith declarado a WorkWithForWeb no inventario'
}
if ($alias.declaredName -ne 'MainWW' -or $alias.exportTaskLabel -ne 'WorkWith') {
    throw 'alias deve preservar nome e exportTaskLabel'
}
if (@($resultAlias.deltaComparison.requestedItemsFound).Count -ne 1) {
    throw 'requestedItemsFound esperado 1 via alias'
}
if (@($resultAlias.deltaComparison.requestedItemsMissing).Count -gt 0) {
    throw 'requestedItemsMissing deve estar vazio quando alias resolve o pedido'
}

$resultAliasMatch = (& $inventoryScript -InputPath $exportLabelPath -DeclaredDeltaItems 'WorkWith:MainWW;Procedure:ProcExtra' | ConvertFrom-Json)
if ($resultAliasMatch.deltaComparison.status -ne 'MATCH') {
    throw "delta status MATCH esperado com lista completa; obtido $($resultAliasMatch.deltaComparison.status)"
}
if ($resultAliasMatch.deltaComparison.aliasResolutionCount -ne 1) {
    throw 'aliasResolutionCount esperado 1 na lista completa'
}

$mobileExportLabelXml = @"
<ExportFile>
  <Objects>
    <Object type="$workWithGuid" name="MobileWW" guid="55555555-5555-5555-5555-555555555503" />
  </Objects>
</ExportFile>
"@
$mobileExportLabelPath = Join-Path $tempRoot 'package-mobile-export-label.import_file.xml'
[System.IO.File]::WriteAllText($mobileExportLabelPath, $mobileExportLabelXml, (Get-Utf8NoBomEncoding))
$resultMobileAlias = (& $inventoryScript -InputPath $mobileExportLabelPath -DeclaredDeltaItems 'WorkWithDevices:MobileWW' | ConvertFrom-Json)
if ($resultMobileAlias.deltaComparison.status -ne 'MATCH') {
    throw "delta status MATCH esperado para WorkWithDevices; obtido $($resultMobileAlias.deltaComparison.status)"
}
if ($resultMobileAlias.deltaComparison.aliasResolutionCount -ne 1) {
    throw 'aliasResolutionCount esperado 1 para WorkWithDevices'
}
$mobileAlias = @($resultMobileAlias.deltaComparison.aliasResolutions)[0]
if ($mobileAlias.rule -ne 'exportTaskLabel' -or $mobileAlias.declaredTypeName -ne 'WorkWithDevices' -or $mobileAlias.inventoryTypeName -ne 'WorkWith') {
    throw 'alias deve ligar WorkWithDevices declarado a WorkWith mobile no inventario'
}

Remove-Item -LiteralPath $tempRoot -Recurse -Force
Write-Output 'GENEXUS_PKG_INVENTORY_SELFTEST_OK'
