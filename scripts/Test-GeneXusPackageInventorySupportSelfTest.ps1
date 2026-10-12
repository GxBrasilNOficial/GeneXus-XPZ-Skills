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
    $attrItems = @($sidecar.items | Where-Object { $_.sourceBlock -eq 'Attributes' })
    Assert-True ($attrItems.Count -eq 1) 'sidecar deve conter um atributo top-level nominal'
    Assert-Equal 'AttrOne' $attrItems[0].name 'nome do atributo no sidecar'

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
