#requires -Version 7.4

<#
.SYNOPSIS
    Valida packageInventory embutido no fluxo xpz-builder (suporte compartilhado).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'GeneXusPackageInventorySupport.ps1')

$procedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-builder-inventory-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$exportXml = @"
<ExportFile>
  <Objects>
    <Object type="$procedureGuid" name="ProcPedida" guid="11111111-1111-1111-1111-111111111102" />
    <Object type="$procedureGuid" name="ProcExtra" guid="11111111-1111-1111-1111-111111111103" />
  </Objects>
</ExportFile>
"@
$packagePath = Join-Path $tempRoot 'pkg.import_file.xml'
[System.IO.File]::WriteAllText($packagePath, $exportXml, (Get-Utf8NoBomEncoding))

$block = New-PackageInventoryResult -InputPath $packagePath -DeclaredDeltaItems 'Procedure:ProcPedida'
if ($block.inventoryDegraded) {
    throw "inventoryDegraded inesperado: $($block.inventoryError)"
}
if ($null -eq $block.packageInventory) {
    throw 'packageInventory esperado no bloco de inventario'
}
if ([int]$block.packageInventory.totalObjects -ne 2) {
    throw "totalObjects esperado 2; obtido $($block.packageInventory.totalObjects)"
}
if ([int]$block.packageInventory.extrasCount -ne 1) {
    throw "extrasCount esperado 1 (ProcExtra); obtido $($block.packageInventory.extrasCount)"
}

$objectXmlPath = Join-Path $tempRoot 'ProcPedida.xml'
@"
<Object type="$procedureGuid" name="ProcPedida" guid="11111111-1111-1111-1111-111111111102" lastUpdate="2026-05-25T12:00:00.0000000Z" />
"@ | Set-Content -LiteralPath $objectXmlPath -Encoding utf8NoBOM

$objectDoc = New-Object System.Xml.XmlDocument
$objectDoc.PreserveWhitespace = $true
$objectDoc.Load($objectXmlPath)
$delta = ConvertTo-DeclaredDeltaItemsFromObjectDocuments -ObjectDocuments @($objectDoc) -ModifiedObjectNames @('ProcPedida')
if ($delta -ne 'Procedure:ProcPedida') {
    throw "delta declarado esperado Procedure:ProcPedida; obtido $delta"
}

Remove-Item -LiteralPath $tempRoot -Recurse -Force
Write-Output 'XPZ_BUILDER_PACKAGE_INVENTORY_SELFTEST_OK'
