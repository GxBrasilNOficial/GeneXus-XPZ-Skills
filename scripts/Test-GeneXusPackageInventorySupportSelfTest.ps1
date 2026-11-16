#requires -Version 7.4

<#
.SYNOPSIS
    Valida contrato de packageInventory resumido (nominalInventoryAt, extrasFullListAt).

.DESCRIPTION
    Exercita New-PackageInventoryResult em pacote XML sintetico sem KB/MSBuild.
    Fecha verificacao empirica estrutural de nominalInventoryAt no resumo JSON.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptDir 'GeneXusPackageInventorySupport.ps1')

function Assert-True {
    param(
        [bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw "ASSERT_FAILED: $Message"
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Actual,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if ($Expected -ne $Actual) {
        throw "ASSERT_FAILED: $Message | expected='$Expected' actual='$Actual'"
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('pkg-inv-support-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$xmlPath = Join-Path $tempRoot 'selective-min.import_file.xml'
$sidecarPath = Join-Path $tempRoot 'package-inventory.json'

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)

    @'
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <Objects>
    <Object name="ExtraProc" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" guid="00000000-0000-0000-0000-000000000001" />
    <Object name="MainWW" type="78cecefe-be7d-4980-86ce-8d6e91fba04b" guid="00000000-0000-0000-0000-000000000002" />
  </Objects>
  <Attributes>
    <Attribute name="AttrOne" guid="00000000-0000-0000-0000-000000000003" />
  </Attributes>
</ExportFile>
'@ | Set-Content -LiteralPath $xmlPath -Encoding utf8NoBOM

    $declared = 'WorkWithForWeb:MainWW'
    $core = New-PackageInventoryResult -InputPath $xmlPath -DeclaredDeltaItems $declared -SidecarInventoryPath $sidecarPath

    Assert-True ($false -eq $core.inventoryDegraded) 'inventoryDegraded deve ser false'
    Assert-True ($null -ne $core.packageInventory) 'packageInventory deve existir'

    $summary = $core.packageInventory
    Assert-Equal $sidecarPath $summary.nominalInventoryAt 'nominalInventoryAt deve apontar para o sidecar'
    Assert-True (Test-Path -LiteralPath $summary.nominalInventoryAt -PathType Leaf) 'sidecar nominalInventoryAt deve existir no disco'
    Assert-True ($summary.attributesTopLevelUnreconciled) 'attributesTopLevelUnreconciled deve ser true sem Transaction na lista'
    Assert-True ([int]$summary.extrasCount -gt 0) 'extrasCount deve ser > 0 no cenario sintetico'
    Assert-Equal $sidecarPath $summary.extrasFullListAt 'extrasFullListAt deve apontar para o sidecar quando ha extras'

    $sidecar = Get-Content -LiteralPath $sidecarPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal '2' ([string]$sidecar.schemaVersion) 'schemaVersion do sidecar'
    Assert-True ($null -ne $sidecar.deltaComparison) 'sidecar seletivo deve conter deltaComparison'
    Assert-True (@($sidecar.deltaComparison.extraObjects).Count -eq [int]$summary.extrasCount) 'sidecar deve conter a lista completa de extras'
    Assert-True (@($sidecar.deltaComparison.aliasResolutions).Count -eq 0) 'sidecar deve manter aliasResolutions como lista vazia'
    $attrItems = @($sidecar.items | Where-Object { $_.sourceBlock -eq 'Attributes' })
    Assert-True ($attrItems.Count -eq 1) 'sidecar deve conter um atributo top-level nominal'
    Assert-Equal 'AttrOne' $attrItems[0].name 'nome do atributo no sidecar'

    $aliasSidecarPath = Join-Path $tempRoot 'package-inventory-alias.json'
    $aliasResult = New-PackageInventoryResult -InputPath $xmlPath -DeclaredDeltaItems 'WorkWith:MainWW' -SidecarInventoryPath $aliasSidecarPath
    $aliasSidecar = Get-Content -LiteralPath $aliasSidecarPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal '1' ([string]$aliasResult.packageInventory.aliasResolutionCount) 'resumo deve registrar uma resolução de alias'
    Assert-Equal $aliasSidecarPath $aliasResult.packageInventory.aliasResolutionsFullListAt 'ponteiro de aliases deve apontar ao sidecar publicado'
    Assert-True (@($aliasSidecar.deltaComparison.aliasResolutions).Count -eq 1) 'sidecar deve copiar a resolução completa de alias'
    Assert-Equal 'WorkWithForWeb' ([string]$aliasSidecar.deltaComparison.aliasResolutions[0].inventoryTypeName) 'alias deve preservar o tipo real do inventário'

    $fullExportSidecarPath = Join-Path $tempRoot 'package-inventory-full.json'
    $fullExport = New-PackageInventoryResult -InputPath $xmlPath -SidecarInventoryPath $fullExportSidecarPath
    $fullExportSidecar = Get-Content -LiteralPath $fullExportSidecarPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($null -eq $fullExportSidecar.PSObject.Properties['deltaComparison']) 'export sem delta nao deve inventar deltaComparison'
    Assert-True ($null -eq $fullExport.packageInventory.PSObject.Properties['extrasFullListAt']) 'export sem delta nao deve anunciar extrasFullListAt'
    Assert-True ($true -eq $fullExport.sidecarPublished) 'sidecar de export completo deve ser publicado'

    $manyObjectsPath = Join-Path $tempRoot 'selective-many.import_file.xml'
    $manyXml = [System.Text.StringBuilder]::new()
    [void]$manyXml.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
    [void]$manyXml.AppendLine('<ExportFile><Objects>')
    [void]$manyXml.AppendLine('<Object name="MainWW" type="78cecefe-be7d-4980-86ce-8d6e91fba04b" guid="00000000-0000-0000-0000-000000000002" />')
    for ($index = 1; $index -le 51; $index++) {
        [void]$manyXml.AppendLine(('<Object name="ExtraProc{0:D2}" type="84a12160-f59b-4ad7-a683-ea4481ac23e9" guid="00000000-0000-0000-0000-{1:D12}" />' -f $index, $index))
    }
    [void]$manyXml.AppendLine('</Objects></ExportFile>')
    [System.IO.File]::WriteAllText($manyObjectsPath, $manyXml.ToString(), (Get-Utf8NoBomEncoding))
    $manySidecarPath = Join-Path $tempRoot 'package-inventory-many.json'
    $many = New-PackageInventoryResult -InputPath $manyObjectsPath -DeclaredDeltaItems 'WorkWithForWeb:MainWW' -SidecarInventoryPath $manySidecarPath
    $manySidecar = Get-Content -LiteralPath $manySidecarPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal '51' ([string]$many.packageInventory.extrasCount) 'resumo deve contar 51 extras'
    Assert-True ($many.packageInventory.extrasSampleTruncated) 'resumo deve marcar amostra truncada acima de 50'
    Assert-True (@($manySidecar.deltaComparison.extraObjects).Count -eq 51) 'sidecar deve preservar os 51 extras completos'

    $originalHash = (Get-FileHash -LiteralPath $sidecarPath -Algorithm SHA256).Hash
    $lockedStream = [System.IO.File]::Open($sidecarPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
    try {
        $failedPublish = New-PackageInventoryResult -InputPath $xmlPath -DeclaredDeltaItems $declared -SidecarInventoryPath $sidecarPath
    } finally {
        $lockedStream.Dispose()
    }
    Assert-True ($null -eq $failedPublish.packageInventoryPath) 'falha de publicação não deve anunciar caminho'
    Assert-True ($false -eq $failedPublish.sidecarPublished) 'falha de publicação deve ser explícita'
    Assert-True (-not [string]::IsNullOrWhiteSpace($failedPublish.sidecarError)) 'falha de publicação deve registrar sidecarError'
    Assert-Equal '90' ([string]$failedPublish.inventoryExitCode) 'falha de publicação preserva classificação de erro atual'
    Assert-Equal $originalHash (Get-FileHash -LiteralPath $sidecarPath -Algorithm SHA256).Hash 'falha de publicação deve preservar sidecar anterior'

    $stubRoot = Join-Path $tempRoot 'reduced-engine-stub'
    [void](New-Item -ItemType Directory -Path $stubRoot -Force)
    Copy-Item -LiteralPath (Join-Path $scriptDir 'GeneXusPackageInventorySupport.ps1') -Destination (Join-Path $stubRoot 'GeneXusPackageInventorySupport.ps1')
    Copy-Item -LiteralPath (Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1') -Destination (Join-Path $stubRoot 'Utf8NoBomEncodingSupport.ps1')
    $stubEngine = @'
[CmdletBinding()]
param([string]$InputPath, [string]$DeclaredDeltaItems, [switch]$FailOnDeltaMismatch, [switch]$FailOnUnknownTypes)
$aliases = @(
    for ($index = 1; $index -le 51; $index++) {
        [pscustomobject]@{ declaredKey = "workwith:Name$index"; declaredTypeName = 'WorkWith'; declaredName = "Name$index"; inventoryTypeName = 'WorkWithForWeb'; inventoryName = "Name$index"; inventoryKey = "workwithforweb:name$index"; rule = 'exportTaskLabel' }
    }
)
$delta = [ordered]@{ status = 'MATCH'; selectiveExport = $true; declaredCount = 51; requestedItemsFound = @(); requestedItemsMissing = @(); matchedCount = 0; extraCount = 0; missingCount = 0; uncomparableCount = 0; extraObjects = @(); missingObjects = @(); uncomparableObjects = @(); systemObjectsPresent = @(); aliasResolutions = $aliases; aliasResolutionCount = 51 }
[pscustomobject]@{ status = 'INVENTORY_OK'; exitCode = 0; inputPath = $InputPath; inputKind = 'xml'; innerXmlEntry = $null; objectCount = 0; attributeCount = 0; objectsByType = @{}; systemObjectsPresent = @(); selectiveExport = $true; declaredIncludesTransaction = $false; attributesTopLevelUnreconciled = $false; inventory = @(); deltaComparison = $delta; warnings = @() } | ConvertTo-Json -Depth 10
'@
    [System.IO.File]::WriteAllText((Join-Path $stubRoot 'Get-GeneXusImportPackageObjectInventory.ps1'), $stubEngine, (Get-Utf8NoBomEncoding))
    . (Join-Path $stubRoot 'GeneXusPackageInventorySupport.ps1')
    $aliasManyPath = Join-Path $tempRoot 'package-inventory-many-aliases.json'
    $aliasMany = New-PackageInventoryResult -InputPath $xmlPath -DeclaredDeltaItems 'WorkWith:Name' -SidecarInventoryPath $aliasManyPath
    $aliasManySidecar = Get-Content -LiteralPath $aliasManyPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-Equal '51' ([string]$aliasMany.packageInventory.aliasResolutionCount) 'resumo deve contar 51 aliases'
    Assert-True ($aliasMany.packageInventory.aliasResolutionsTruncated) 'resumo deve marcar aliases truncados acima de 50'
    Assert-True (@($aliasManySidecar.deltaComparison.aliasResolutions).Count -eq 51) 'sidecar deve preservar os 51 aliases completos'
    Assert-Equal 'WorkWithForWeb' ([string]$aliasManySidecar.deltaComparison.aliasResolutions[50].inventoryTypeName) 'alias copiado deve preservar os campos originais'

    $stubEngine = @'
[CmdletBinding()]
param([string]$InputPath, [string]$DeclaredDeltaItems, [switch]$FailOnDeltaMismatch, [switch]$FailOnUnknownTypes)
[pscustomobject]@{ status = 'bloqueado'; exitCode = 20; inputPath = $InputPath; blockingReasons = @('BLOCK: resposta reduzida sintetica'); warnings = @() } | ConvertTo-Json -Depth 6
'@
    [System.IO.File]::WriteAllText((Join-Path $stubRoot 'Get-GeneXusImportPackageObjectInventory.ps1'), $stubEngine, (Get-Utf8NoBomEncoding))
    $reduced = New-PackageInventoryResult -InputPath $xmlPath -DeclaredDeltaItems $declared -SidecarInventoryPath (Join-Path $tempRoot 'must-not-exist.json')
    Assert-Equal '90' ([string]$reduced.inventoryExitCode) 'resposta reduzida mantém a classificação de erro atual do suporte'
    Assert-True ($reduced.inventoryError.Contains('exitCode=20')) 'erro deve preservar exitCode do motor na mensagem'
    Assert-True ($reduced.inventoryError.Contains('resposta reduzida sintetica')) 'erro deve preservar blockingReasons do motor'
    Assert-True ($null -eq $reduced.packageInventoryPath) 'resposta reduzida não deve anunciar sidecar'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'must-not-exist.json'))) 'resposta reduzida não deve publicar sidecar'
    . (Join-Path $scriptDir 'GeneXusPackageInventorySupport.ps1')

    $withTransaction = New-PackageInventoryResult `
        -InputPath $xmlPath `
        -DeclaredDeltaItems 'Transaction:TrnA;WorkWithForWeb:MainWW' `
        -SidecarInventoryPath (Join-Path $tempRoot 'package-inventory-with-trn.json')

    Assert-True (-not $withTransaction.packageInventory.attributesTopLevelUnreconciled) `
        'com Transaction na lista, attributesTopLevelUnreconciled deve ser false'

    Write-Output 'GENEXUS_PACKAGE_INVENTORY_SUPPORT_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
