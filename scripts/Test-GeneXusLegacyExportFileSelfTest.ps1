#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusLegacyExportFileSupport.ps1'
$catalogSupportPath = Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1'
. $supportPath
. $catalogSupportPath

$fixturePath = Join-Path $PSScriptRoot 'test-fixtures\legacy-exportfile-minimal.xml'
if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
    throw "Fixture not found: $fixturePath"
}

[xml]$fixture = Get-Content -LiteralPath $fixturePath -Raw
if (-not (Test-GeneXusLegacyExportFilePackage -XmlDocument $fixture)) {
    throw 'Fixture should be detected as legacy ExportFile.'
}

$build = Get-GeneXusLegacyKmwBuildFromPackage -XmlDocument $fixture
if ($build -ne '2494') {
    throw "Expected MaxGxBuildSaved mapping to build 2494, got '$build'."
}

$catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
$resolution = Resolve-GeneXusObjectTypeCatalogPaths -BaseCatalogPath $catalogPath
$sync = Get-GeneXusLegacyExportFileSyncItems `
    -XmlDocument $fixture `
    -MergedCatalog $resolution.MergedCatalog `
    -NormalizeFileBaseName { param($name) $name }

if (@($sync.Items).Count -ne 2) {
    throw "Expected 2 sync items, got $(@($sync.Items).Count)."
}

foreach ($item in @($sync.Items)) {
    if ($null -eq $item.PSObject.Properties['Guid']) {
        throw "Legacy sync item '$($item.FolderType):$($item.LogicalName)' missing Guid property."
    }
    if ($item.Guid -ne '') {
        throw "Legacy sync item '$($item.FolderType):$($item.LogicalName)' should expose empty Guid, got '$($item.Guid)'."
    }
}

$transaction = @($sync.Items | Where-Object { $_.CanonicalType -eq 'Transaction' })
if ($transaction.Count -ne 1 -or $transaction[0].LogicalName -ne 'Cliente') {
    throw 'Transaction Cliente not materialized as expected.'
}

$attribute = @($sync.Items | Where-Object { $_.CanonicalType -eq 'Attribute' })
if ($attribute.Count -ne 1 -or $attribute[0].LogicalName -ne 'ClienteId') {
    throw 'Attribute ClienteId not materialized as expected.'
}

if ($transaction[0].Node.GetAttribute('dataSource') -ne 'gx-legacy-export') {
    throw 'Wrapped object missing dataSource=gx-legacy-export.'
}

$payload = $transaction[0].Node.SelectSingleNode('./GxLegacyPayload')
if ($null -eq $payload) {
    throw 'Wrapped object missing GxLegacyPayload.'
}

$inventory = Get-GeneXusLegacyExportFileInventoryItems -XmlDocument $fixture -MergedCatalog $resolution.MergedCatalog
if ($inventory.TotalCount -ne 2) {
    throw "Expected inventory count 2, got $($inventory.TotalCount)."
}

Write-Output 'Test-GeneXusLegacyExportFileSelfTest: OK'
