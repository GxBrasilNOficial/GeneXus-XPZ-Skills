#requires -Version 7.4
<#
.SYNOPSIS
    Pureza do catalogo moderno gx-object-type-catalog.json: objectTypeGuid null
    so e aceito em rootKind Attribute; todo rootKind diferente exige UUID valido;
    fail-safe para rootKind novo (fora de Object/Virtual/Attribute).
.DESCRIPTION
    Nao usa heuristica "parece sintetico": GUIDs com padrao repetido
    (dcdcdcdc-... DataStore, ecececec-... Generator) sao reais e confirmados em
    export real. O criterio e estrutural (rootKind), nao a forma do GUID.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'GeneXusObjectTypeCatalogSupport.ps1')

$catalogPath = Get-GeneXusObjectTypeCatalogDefaultBasePath
$catalog = Read-GeneXusObjectTypeCatalogFile -Path $catalogPath

if ($null -eq $catalog.PSObject.Properties['types'] -or $null -eq $catalog.types) {
    throw "Catalogo sem propriedade 'types': $catalogPath"
}

$knownRootKinds = @('Object', 'Virtual', 'Attribute')

foreach ($property in $catalog.types.PSObject.Properties) {
    $typeName = $property.Name
    $entry = $property.Value

    if ($null -eq $entry.PSObject.Properties['rootKind']) {
        throw "Tipo '$typeName' sem 'rootKind'."
    }
    $rootKind = [string]$entry.rootKind

    if ($knownRootKinds -notcontains $rootKind) {
        throw "Tipo '$typeName' usa rootKind desconhecido '$rootKind'. Revise a regra de pureza (fail-safe): so Attribute pode ter objectTypeGuid null; rootKind novo precisa de decisao explicita."
    }

    if ($null -eq $entry.PSObject.Properties['objectTypeGuid']) {
        throw "Tipo '$typeName' sem 'objectTypeGuid'."
    }
    $guidVal = $entry.objectTypeGuid
    $isNullGuid = ($null -eq $guidVal) -or [string]::IsNullOrWhiteSpace([string]$guidVal)

    if ($isNullGuid) {
        if ($rootKind -ne 'Attribute') {
            throw "Tipo '$typeName' tem objectTypeGuid null mas rootKind '$rootKind' (null so e permitido em rootKind Attribute)."
        }
        continue
    }

    $parsed = [guid]::Empty
    if (-not [guid]::TryParse([string]$guidVal, [ref]$parsed)) {
        throw "Tipo '$typeName' tem objectTypeGuid '$guidVal' que nao e um UUID valido."
    }
}

Write-Output 'GENEXUS_CATALOG_PURITY_SELFTEST_OK'
