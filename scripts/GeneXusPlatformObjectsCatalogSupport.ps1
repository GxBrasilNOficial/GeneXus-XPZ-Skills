#requires -Version 7.4

<#
.SYNOPSIS
    Carrega gx-platform-objects.json e detecta objetos de plataforma/SDK no inventario de pacote.
#>

Set-StrictMode -Version Latest

function Import-GeneXusPlatformObjectsCatalog {
    param([string]$CatalogPath)

    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
        throw "BLOCK: PlatformObjectsCatalogPath nao encontrado: $CatalogPath"
    }

    $raw = Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8
    $doc = $raw | ConvertFrom-Json
    if ($null -eq $doc.objects) {
        throw "BLOCK: gx-platform-objects.json sem array 'objects'"
    }

    return $doc
}

function Get-PlatformObjectKindSets {
    param($Catalog)

    $moduleNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $externalNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($entry in @($Catalog.objects)) {
        $name = [string]$entry.name
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        switch ([string]$entry.kind) {
            'packagedModule' { [void]$moduleNames.Add($name.Trim()) }
            'externalObject' { [void]$externalNames.Add($name.Trim()) }
            default {
                throw ("BLOCK: kind invalido '{0}' para entrada '{1}' no catalogo de plataforma" -f $entry.kind, $name)
            }
        }
    }

    return [pscustomobject]@{
        ModuleNames           = $moduleNames
        ExternalObjectNames   = $externalNames
    }
}

function Test-IsPlatformModuleInventoryItem {
    param($Item)

    if ($Item.sourceBlock -ne 'Objects' -or [string]::IsNullOrWhiteSpace($Item.name)) {
        return $false
    }

    # Export real GeneXus 18 traz SDK/plataforma como PackagedModule (GUID c88fffcd-...).
    # Module (GUID 00000000-...-000006) e container de KB do usuário.
    return $Item.typeName -eq 'Module' -or $Item.typeName -eq 'PackagedModule'
}

function Get-SystemObjectsPresent {
    param(
        $InventoryItems,
        $PlatformKindSets
    )

    $found = [System.Collections.Generic.List[pscustomobject]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($item in @($InventoryItems | Where-Object { Test-IsPlatformModuleInventoryItem -Item $_ })) {
        if ($PlatformKindSets.ModuleNames.Contains($item.name)) {
            $dedupeKey = ('packagedModule|{0}' -f $item.name)
            if (-not $seen.Contains($dedupeKey)) {
                $found.Add([pscustomobject]@{
                        name     = $item.name
                        kind     = 'packagedModule'
                        typeName = $item.typeName
                    }) | Out-Null
                [void]$seen.Add($dedupeKey)
            }
        }
    }

    foreach ($item in @($InventoryItems | Where-Object {
            $_.sourceBlock -eq 'Objects' -and
            $_.typeName -eq 'ExternalObject' -and
            -not [string]::IsNullOrWhiteSpace($_.name)
        })) {
        if ($PlatformKindSets.ExternalObjectNames.Contains($item.name)) {
            $dedupeKey = ('externalObject|{0}' -f $item.name)
            if (-not $seen.Contains($dedupeKey)) {
                $found.Add([pscustomobject]@{
                        name     = $item.name
                        kind     = 'externalObject'
                        typeName = $item.typeName
                    }) | Out-Null
                [void]$seen.Add($dedupeKey)
            }
        }
    }

    return @($found | Sort-Object { $_.kind }, { $_.name })
}
