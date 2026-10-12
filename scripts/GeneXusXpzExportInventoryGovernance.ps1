#requires -Version 7.4

<#
.SYNOPSIS
    Governanca de inventario e operationalSubState para export MSBuild (Invoke-GeneXusXpzExport.ps1).

.DESCRIPTION
    Não e helper genérico de inventario (ver GeneXusPackageInventorySupport.ps1).
    Carregado exclusivamente pelo wrapper de export para classificar operationalSubState
    e montar o bloco de inventario pos-export.
#>

Set-StrictMode -Version Latest

function Resolve-ExportOperationalSubState {
    param(
        $InventoryBlock,
        [string[]]$ExportErrors
    )

    # Precedência fixa de operationalSubState (do mais forte ao mais fraco):
    #   1. exportErrors[] não vazio ->
    #      "exportação parcial com errors do MSBuild — artefato não confiável"
    #   2. inventoryDegraded=true ->
    #      "exportação concluída sem inventário (degradado)"
    #   3. seletiva (packageInventory.selectiveExport) com sinais de extras
    #      (systemObjectsPresent, attributesTopLevelUnreconciled,
    #       extraCount > 0, requestedItemsMissing não vazio) ->
    #      "exportação concluída, inventário com extras não conciliados"
    #   4. caso base -> "exportação concluída e inventário consolidado"

    if (@($ExportErrors).Count -gt 0) {
        return 'exportação parcial com errors do MSBuild — artefato não confiável'
    }
    if ($null -ne $InventoryBlock) {
        return [string]$InventoryBlock.operationalSubState
    }
    return $null
}

function Resolve-ExportPackageInventoryOperationalSubState {
    param(
        $PackageInventory,
        [bool]$InventoryDegraded
    )

    if ($InventoryDegraded -or $null -eq $PackageInventory) {
        return 'exportação concluída sem inventário (degradado)'
    }

    if (-not [bool]$PackageInventory.selectiveExport) {
        return 'exportação concluída e inventário consolidado'
    }

    $hasSystemObjects = @($PackageInventory.systemObjectsPresent).Count -gt 0
    $hasAttributesUnreconciled = $false
    if (Get-Member -InputObject $PackageInventory -Name 'attributesTopLevelUnreconciled' -MemberType NoteProperty, Property -ErrorAction SilentlyContinue) {
        $hasAttributesUnreconciled = [bool]$PackageInventory.attributesTopLevelUnreconciled
    }
    $hasExtras = $false
    $hasMissing = $false
    if (Get-Member -InputObject $PackageInventory -Name 'extrasCount' -MemberType NoteProperty, Property -ErrorAction SilentlyContinue) {
        $hasExtras = [int]$PackageInventory.extrasCount -gt 0
    }
    if (Get-Member -InputObject $PackageInventory -Name 'requestedItemsMissing' -MemberType NoteProperty, Property -ErrorAction SilentlyContinue) {
        $hasMissing = @($PackageInventory.requestedItemsMissing).Count -gt 0
    }
    if ($hasSystemObjects -or $hasAttributesUnreconciled -or $hasExtras -or $hasMissing) {
        return 'exportação concluída, inventário com extras não conciliados'
    }

    return 'exportação concluída e inventário consolidado'
}

function New-ExportPackageInventoryBlock {
    param(
        [string]$XpzPath,
        [string]$ArtifactDirectory,
        [string]$ObjectList,
        [string]$ExportAll,
        [bool]$FullExportRequested
    )

    $packageInventoryPath = Join-Path $ArtifactDirectory 'package-inventory.json'
    $isSelective = (-not $FullExportRequested) -and ($ExportAll -ne 'true') -and (-not [string]::IsNullOrWhiteSpace($ObjectList))

    $declaredDelta = $null
    if ($isSelective) {
        $declaredDelta = $ObjectList
    }

    $supportPath = Join-Path $PSScriptRoot 'GeneXusPackageInventorySupport.ps1'
    if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
        return [pscustomobject]@{
            inventoryDegraded    = $true
            inventoryError       = "Script de suporte de inventario nao encontrado: $supportPath"
            packageInventory     = $null
            packageInventoryPath = $packageInventoryPath
            operationalSubState  = 'exportação concluída sem inventário (degradado)'
        }
    }

    . $supportPath
    $core = New-PackageInventoryResult `
        -InputPath $XpzPath `
        -DeclaredDeltaItems $declaredDelta `
        -SidecarInventoryPath $packageInventoryPath

    $operationalSubState = Resolve-ExportPackageInventoryOperationalSubState `
        -PackageInventory $core.packageInventory `
        -InventoryDegraded $core.inventoryDegraded

    return [pscustomobject]@{
        inventoryDegraded    = $core.inventoryDegraded
        inventoryError       = $core.inventoryError
        packageInventory     = $core.packageInventory
        packageInventoryPath = $core.packageInventoryPath
        operationalSubState  = $operationalSubState
    }
}
