#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$preflightPath = Join-Path $PSScriptRoot 'GeneXusObjectListIdentityPreflight.ps1'
. $preflightPath

if (-not (Test-IsSelectiveGeneXusXpzExport -ObjectList 'Procedure:A' -ExportAll 'false' -FullExportRequested $false)) {
    throw 'Esperava export seletivo com ObjectList'
}

if (Test-IsSelectiveGeneXusXpzExport -ObjectList '' -ExportAll 'true' -FullExportRequested:$false) {
    throw 'ExportAll nao deveria ser seletivo'
}

$catalogResolved = Resolve-GeneXusObjectTypeCatalogPaths -ParallelKbRoot $null
$wwType = Resolve-GeneXusCatalogTypeForExportLabel -MergedCatalog $catalogResolved.MergedCatalog -ExportLabel 'WorkWith'
if ($wwType -ne 'WorkWithForWeb') {
    throw "Esperava WorkWith -> WorkWithForWeb no catalogo; obtido: $wwType"
}

$wwCanonicalType = Resolve-GeneXusCatalogTypeForExportLabel -MergedCatalog $catalogResolved.MergedCatalog -ExportLabel 'WorkWith' -PreferExportTaskLabel $false
if ($wwCanonicalType -ne 'WorkWith') {
    throw "Esperava WorkWith canonico -> WorkWith fora do contexto Export; obtido: $wwCanonicalType"
}

$wwMobileType = Resolve-GeneXusCatalogTypeForExportLabel -MergedCatalog $catalogResolved.MergedCatalog -ExportLabel 'WorkWithDevices'
if ($wwMobileType -ne 'WorkWith') {
    throw "Esperava WorkWithDevices -> WorkWith no catalogo; obtido: $wwMobileType"
}

$mobileEntry = $catalogResolved.MergedCatalog.types.WorkWith
$webEntry = $catalogResolved.MergedCatalog.types.WorkWithForWeb
if ($mobileEntry.objectTypeGuid -ne '15cf49b5-fc38-4899-91b5-395d02d79889') {
    throw 'GUID mobile WorkWith inesperado no catalogo'
}
if ($webEntry.objectTypeGuid -ne '78cecefe-be7d-4980-86ce-8d6e91fba04b') {
    throw 'GUID web WorkWithForWeb inesperado no catalogo'
}
if ($mobileEntry.objectTypeGuid -eq $webEntry.objectTypeGuid) {
    throw 'WorkWith e WorkWithForWeb devem coexistir com GUIDs distintos'
}
if ($mobileEntry.folderName -ne 'WorkWith' -or $webEntry.folderName -ne 'WorkWithForWeb') {
    throw 'WorkWith e WorkWithForWeb devem materializar em pastas distintas'
}

$blocked = Invoke-GeneXusObjectListIdentityPreflight `
    -ObjectList 'Procedure:Demo' `
    -ExportAll 'false' `
    -FullExportRequested $false

if (-not $blocked.block -or $blocked.exitCode -ne 35) {
    throw 'Export seletivo sem ParallelKbRoot/IndexPath deveria bloquear com exit 35'
}

if (-not (Test-IsSelectiveGeneXusXpzImport -IncludeItems 'Procedure:A')) {
    throw 'Esperava import seletivo com IncludeItems'
}

if (Test-IsSelectiveGeneXusXpzImport -IncludeItems '') {
    throw 'IncludeItems vazio nao deveria ser seletivo'
}

$importBlocked = Invoke-GeneXusObjectListIdentityPreflight `
    -GateContext 'import' `
    -IncludeItems 'Procedure:Demo'

if (-not $importBlocked.block -or $importBlocked.exitCode -ne 35 -or $importBlocked.gateContext -ne 'import') {
    throw 'Import seletivo sem indice deveria bloquear com exit 35 e gateContext import'
}

$importSkipped = Invoke-GeneXusObjectListIdentityPreflight -GateContext 'import' -IncludeItems ''
if (-not $importSkipped.preflightSkipped -or $importSkipped.preflightSkipReason -ne 'import_not_selective') {
    throw 'Import sem IncludeItems deveria pular preflight'
}

$filterParts = @(Split-GeneXusMsBuildItemFilter -FilterText 'Procedure:A, WebPanel:B;Transaction:C')
if ($filterParts.Count -ne 3) {
    throw "Esperava 3 itens no split de filtro MSBuild; obtido: $($filterParts.Count)"
}

$items = @(Read-GeneXusObjectListItemsFromText -Text 'Procedure:A;WebPanel:B')
if ($items.Count -ne 2) {
    throw "Esperava 2 itens parseados; obtido: $($items.Count)"
}

Write-Output 'OBJECT_LIST_IDENTITY_PREFLIGHT_SELFTEST_OK'
