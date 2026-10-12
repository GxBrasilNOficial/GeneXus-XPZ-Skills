#requires -Version 7.4

<#
.SYNOPSIS
    Valida gx-platform-objects.json e Get-SystemObjectsPresent (paridade com listas .txt legadas).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'GeneXusPlatformObjectsCatalogSupport.ps1')

$catalogPath = Join-Path $scriptDir 'gx-platform-objects.json'
$catalog = Import-GeneXusPlatformObjectsCatalog -CatalogPath $catalogPath
if ([int]$catalog.schemaVersion -ne 1) {
    throw "schemaVersion esperado 1; obtido $($catalog.schemaVersion)"
}

$packagedModuleCount = @($catalog.objects | Where-Object { $_.kind -eq 'packagedModule' }).Count
$externalObjectCount = @($catalog.objects | Where-Object { $_.kind -eq 'externalObject' }).Count
if ($packagedModuleCount -ne 16) {
    throw "packagedModule esperado 16 entradas; obtido $packagedModuleCount"
}
if ($externalObjectCount -ne 35) {
    throw "externalObject esperado 35 entradas; obtido $externalObjectCount"
}

$kindSets = Get-PlatformObjectKindSets -Catalog $catalog
$inventory = @(
    [pscustomobject]@{ sourceBlock = 'Objects'; typeName = 'PackagedModule'; name = 'GeneXus' }
    [pscustomobject]@{ sourceBlock = 'Objects'; typeName = 'ExternalObject'; name = 'Camera' }
    [pscustomobject]@{ sourceBlock = 'Objects'; typeName = 'Procedure'; name = 'ProcLocal' }
)
$present = @(Get-SystemObjectsPresent -InventoryItems $inventory -PlatformKindSets $kindSets)
if ($present.Count -ne 2) {
    throw "Get-SystemObjectsPresent esperado 2; obtido $($present.Count)"
}
if ($present[0].kind -ne 'externalObject' -or $present[0].name -ne 'Camera') {
    throw 'ordenacao ou Camera inesperada'
}
if ($present[1].kind -ne 'packagedModule' -or $present[1].name -ne 'GeneXus') {
    throw 'GeneXus packagedModule inesperado'
}

Write-Output 'GENEXUS_PLATFORM_OBJECTS_CATALOG_SELFTEST_OK'
