#requires -Version 7.4
<#
.SYNOPSIS
    Self-test ponta-a-ponta do ramo legado de Get-GeneXusImportPackageObjectInventory.ps1.

.DESCRIPTION
    Exercita a INTEGRACAO real (processo filho pwsh -File) do Inventory sobre a fixture
    iso-8859-1 gerada on-the-fly, travando o contrato do perfil legado (spec congelada
    Fase 2 v2.8.5, secao 4.2) que ate aqui so era coberto pelo support isolado:
    - perfil legado-puro detectado: legacyFormatDetected=true; itens known-legacy com
      rootKind sintetico Object/Attribute; equivalent -> typeName real (Transaction),
      orphan -> typeName gxlegacy/Report e gxlegacy/Menubar; guid=null;
    - unknownTypeCount=0 e unknownTypesDiscovery=[] (forma statement: o fail-closed de tag
      vive no parser, nao no discovery moderno por GUID; guarda contra regressao do gotcha
      StrictMode if-expressao @()->null);
    - delta declarado orfao registry-aware: 'Report:RelMov'/'Menubar:MenuPrincipal' (sem
      prefixo) casam gxlegacy/Report:RelMov / gxlegacy/Menubar:MenuPrincipal (matchedCount);
    - pacote MISTO -> BLOCK (exit != 0), nao materializa nem inventaria.
    Token de sucesso no stdout + exit 0.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptsRoot 'GeneXusLegacyExportFileFixtureSupport.ps1')

$inventoryScript = Join-Path $scriptsRoot 'Get-GeneXusImportPackageObjectInventory.ps1'

function New-WorkRoot {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('legacy-inv-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
    [void](New-Item -ItemType Directory -Path $root)
    return $root
}

function Write-Iso88591File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::GetEncoding('iso-8859-1'))
}

function Invoke-InventoryJson {
    <# Roda o Inventory e devolve o objeto JSON do stdout. Lanca se exit != 0. #>
    param([string[]]$InvArgs)
    $stdout = & pwsh -NoProfile -File $inventoryScript @InvArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Inventory retornou exit $LASTEXITCODE (esperado 0). Args: $($InvArgs -join ' ')"
    }
    return (($stdout -join "`n") | ConvertFrom-Json)
}

function Invoke-InventoryExpectBlock {
    <# Roda o Inventory e exige exit != 0 (fail-closed). #>
    param([string[]]$InvArgs)
    & pwsh -NoProfile -File $inventoryScript @InvArgs 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw "Inventory deveria ter falhado (exit != 0), mas retornou 0. Args: $($InvArgs -join ' ')"
    }
}

# =====================================================================================
# Caso 1 — perfil legado-puro: known-legacy, unknownTypeCount=0, discovery vazio
# =====================================================================================
$work1 = New-WorkRoot
try {
    $fixture = New-GeneXusLegacyExportFixtureFile -Path (Join-Path $work1 'legacy.xml')
    $inv = Invoke-InventoryJson -InvArgs @('-InputPath', $fixture)

    if (-not $inv.legacyFormatDetected) { throw 'Caso1: legacyFormatDetected deveria ser true.' }
    if ($inv.objectCount -ne 5) { throw "Caso1: objectCount=$($inv.objectCount) (esperado 5)." }
    if ($inv.attributeCount -ne 2) { throw "Caso1: attributeCount=$($inv.attributeCount) (esperado 2)." }
    if ($inv.unknownTypeCount -ne 0) { throw "Caso1: unknownTypeCount=$($inv.unknownTypeCount) (esperado 0)." }
    if (@($inv.unknownTypesDiscovery).Count -ne 0) { throw "Caso1: unknownTypesDiscovery deveria ser vazio (obtido $(@($inv.unknownTypesDiscovery).Count))." }

    foreach ($item in $inv.inventory) {
        if ($item.typeStatus -ne 'known-legacy') { throw "Caso1: item '$($item.name)' typeStatus='$($item.typeStatus)' (esperado known-legacy)." }
        if ($null -ne $item.guid) { throw "Caso1: item '$($item.name)' guid deveria ser null." }
        if ([string]::IsNullOrWhiteSpace([string]$item.legacyElement)) { throw "Caso1: item '$($item.name)' sem legacyElement." }
    }

    $cliente = @($inv.inventory | Where-Object { $_.name -eq 'Cliente' })
    if ($cliente.Count -ne 1 -or $cliente[0].type -ne 'Transaction' -or $cliente[0].rootKind -ne 'Object') { throw 'Caso1: equivalent Transaction Cliente mal classificado.' }
    $relmov = @($inv.inventory | Where-Object { $_.name -eq 'RelMov' })
    if ($relmov.Count -ne 1 -or $relmov[0].type -ne 'gxlegacy/Report') { throw "Caso1: orphan Report RelMov type='$($relmov[0].type)' (esperado gxlegacy/Report)." }
    $menu = @($inv.inventory | Where-Object { $_.name -eq 'MenuPrincipal' })
    if ($menu.Count -ne 1 -or $menu[0].type -ne 'gxlegacy/Menubar') { throw "Caso1: orphan Menubar type='$($menu[0].type)' (esperado gxlegacy/Menubar)." }
    $attr = @($inv.inventory | Where-Object { $_.rootKind -eq 'Attribute' })
    if ($attr.Count -ne 2) { throw "Caso1: esperado 2 atributos known-legacy, obtido $($attr.Count)." }
} finally {
    if (Test-Path -LiteralPath $work1) { Remove-Item -LiteralPath $work1 -Recurse -Force }
}

# =====================================================================================
# Caso 2 — delta declarado orfao registry-aware (sem prefixo casa gxlegacy/<Tag>:Nome)
# =====================================================================================
$work2 = New-WorkRoot
try {
    $fixture = New-GeneXusLegacyExportFixtureFile -Path (Join-Path $work2 'legacy.xml')
    $inv = Invoke-InventoryJson -InvArgs @('-InputPath', $fixture, '-DeclaredDeltaItems', 'Report:RelMov;Menubar:MenuPrincipal;Transaction:Cliente')

    if ($null -eq $inv.deltaComparison) { throw 'Caso2: deltaComparison ausente.' }
    if ($inv.deltaComparison.matchedCount -ne 3) { throw "Caso2: matchedCount=$($inv.deltaComparison.matchedCount) (esperado 3; orphan declarado sem prefixo deve casar gxlegacy/<Tag>:Nome)." }
    if ($inv.deltaComparison.missingCount -ne 0) { throw "Caso2: missingCount=$($inv.deltaComparison.missingCount) (esperado 0)." }
} finally {
    if (Test-Path -LiteralPath $work2) { Remove-Item -LiteralPath $work2 -Recurse -Force }
}

# =====================================================================================
# Caso 3 — pacote MISTO -> BLOCK (exit != 0)
# =====================================================================================
$work3 = New-WorkRoot
try {
    $mixed = Join-Path $work3 'misto.xml'
    Write-Iso88591File -Path $mixed -Content @'
<?xml version='1.0' encoding='iso-8859-1'?>
<ExportFile>
  <GXObject><Transaction><Info><Name>Cliente</Name></Info></Transaction></GXObject>
  <Objects><Object type="00000000-0000-0000-0000-000000000001" name="Moderno"/></Objects>
</ExportFile>
'@
    Invoke-InventoryExpectBlock -InvArgs @('-InputPath', $mixed)
} finally {
    if (Test-Path -LiteralPath $work3) { Remove-Item -LiteralPath $work3 -Recurse -Force }
}

Write-Output 'XPZ_INVENTORY_LEGACY_EXPORT_SELFTEST_OK'
exit 0
