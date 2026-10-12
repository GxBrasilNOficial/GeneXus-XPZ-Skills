#requires -Version 7.4

<#
.SYNOPSIS
    Valida Resolve-ExportPackageInventoryOperationalSubState e precedencia em Resolve-ExportOperationalSubState.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'GeneXusXpzExportInventoryGovernance.ps1')

function Assert-SubState {
    param(
        [string]$Label,
        [string]$Expected,
        [string]$Actual
    )

    if ($Actual -ne $Expected) {
        throw "$Label : esperado [$Expected]; obtido [$Actual]"
    }
}

$consolidado = 'exportação concluída e inventário consolidado'
$extras = 'exportação concluída, inventário com extras não conciliados'
$degradado = 'exportação concluída sem inventário (degradado)'
$errosParciais = 'exportação parcial com errors do MSBuild — artefato não confiável'

Assert-SubState -Label 'degradado' -Expected $degradado -Actual (
    Resolve-ExportPackageInventoryOperationalSubState -PackageInventory $null -InventoryDegraded $true
)

$seletivaLimpa = [pscustomobject]@{
    selectiveExport                = $true
    systemObjectsPresent           = @()
    attributesTopLevelUnreconciled = $false
    extrasCount                    = 0
    requestedItemsMissing          = @()
}
Assert-SubState -Label 'seletiva limpa' -Expected $consolidado -Actual (
    Resolve-ExportPackageInventoryOperationalSubState -PackageInventory $seletivaLimpa -InventoryDegraded $false
)

$comModulos = [pscustomobject]@{
    selectiveExport                = $true
    systemObjectsPresent           = @([pscustomobject]@{ name = 'GeneXusCommon'; kind = 'packagedModule' })
    attributesTopLevelUnreconciled = $false
    extrasCount                    = 0
    requestedItemsMissing          = @()
}
Assert-SubState -Label 'systemObjectsPresent packagedModule' -Expected $extras -Actual (
    Resolve-ExportPackageInventoryOperationalSubState -PackageInventory $comModulos -InventoryDegraded $false
)

$comExternal = [pscustomobject]@{
    selectiveExport                = $true
    systemObjectsPresent           = @([pscustomobject]@{ name = 'Camera'; kind = 'externalObject' })
    attributesTopLevelUnreconciled = $false
    extrasCount                    = 0
    requestedItemsMissing          = @()
}
Assert-SubState -Label 'systemObjectsPresent externalObject' -Expected $extras -Actual (
    Resolve-ExportPackageInventoryOperationalSubState -PackageInventory $comExternal -InventoryDegraded $false
)

$comAtributos = [pscustomobject]@{
    selectiveExport                = $true
    systemObjectsPresent           = @()
    attributesTopLevelUnreconciled = $true
    extrasCount                    = 0
    requestedItemsMissing          = @()
}
Assert-SubState -Label 'attributesTopLevelUnreconciled' -Expected $extras -Actual (
    Resolve-ExportPackageInventoryOperationalSubState -PackageInventory $comAtributos -InventoryDegraded $false
)

$comExtras = [pscustomobject]@{
    selectiveExport                = $true
    systemObjectsPresent           = @()
    attributesTopLevelUnreconciled = $false
    extrasCount                    = 2
    requestedItemsMissing          = @()
}
Assert-SubState -Label 'extrasCount' -Expected $extras -Actual (
    Resolve-ExportPackageInventoryOperationalSubState -PackageInventory $comExtras -InventoryDegraded $false
)

$comMissing = [pscustomobject]@{
    selectiveExport                = $true
    systemObjectsPresent           = @()
    attributesTopLevelUnreconciled = $false
    extrasCount                    = 0
    requestedItemsMissing          = @('Procedure:Faltante')
}
Assert-SubState -Label 'requestedItemsMissing' -Expected $extras -Actual (
    Resolve-ExportPackageInventoryOperationalSubState -PackageInventory $comMissing -InventoryDegraded $false
)

$fullComModulos = [pscustomobject]@{
    selectiveExport                = $false
    systemObjectsPresent           = @(
        [pscustomobject]@{ name = 'GeneXusCommon'; kind = 'packagedModule' }
        [pscustomobject]@{ name = 'Camera'; kind = 'externalObject' }
    )
    attributesTopLevelUnreconciled = $true
    extrasCount                    = 5
    requestedItemsMissing          = @('Procedure:Faltante')
}
Assert-SubState -Label 'full export' -Expected $consolidado -Actual (
    Resolve-ExportPackageInventoryOperationalSubState -PackageInventory $fullComModulos -InventoryDegraded $false
)

$inventoryBlockDegradado = [pscustomobject]@{
    inventoryDegraded   = $true
    operationalSubState = $degradado
}
$inventoryBlockOk = [pscustomobject]@{
    inventoryDegraded   = $false
    operationalSubState = $consolidado
}
Assert-SubState -Label 'precedencia exportErrors sobre degradado' -Expected $errosParciais -Actual (
    Resolve-ExportOperationalSubState -InventoryBlock $inventoryBlockDegradado -ExportErrors @('error : algo')
)
Assert-SubState -Label 'precedencia degradado sem exportErrors' -Expected $degradado -Actual (
    Resolve-ExportOperationalSubState -InventoryBlock $inventoryBlockDegradado -ExportErrors @()
)
Assert-SubState -Label 'precedencia inventario ok' -Expected $consolidado -Actual (
    Resolve-ExportOperationalSubState -InventoryBlock $inventoryBlockOk -ExportErrors @()
)

$procedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$integrationRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-export-inventory-dry-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $integrationRoot -Force)
$exportXml = @"
<ExportFile>
  <Objects>
    <Object type="$procedureGuid" name="ProcPedida" guid="11111111-1111-1111-1111-111111111102" />
    <Object type="$procedureGuid" name="ProcExtra" guid="11111111-1111-1111-1111-111111111103" />
  </Objects>
</ExportFile>
"@
$packagePath = Join-Path $integrationRoot 'pkg.import_file.xml'
[System.IO.File]::WriteAllText($packagePath, $exportXml, (Get-Utf8NoBomEncoding))
$dryBlock = New-ExportPackageInventoryBlock `
    -XpzPath $packagePath `
    -ArtifactDirectory $integrationRoot `
    -ObjectList 'Procedure:ProcPedida' `
    -ExportAll 'false' `
    -FullExportRequested $false
if ($dryBlock.inventoryDegraded) {
    throw "DRY export block degradado: $($dryBlock.inventoryError)"
}
Assert-SubState -Label 'DRY New-ExportPackageInventoryBlock' -Expected $extras -Actual $dryBlock.operationalSubState
Remove-Item -LiteralPath $integrationRoot -Recurse -Force

Write-Output 'EXPORT_SUBSTATE_CLASSIFIER_SELFTEST_OK'
