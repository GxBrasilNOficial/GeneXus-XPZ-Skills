#requires -Version 7.4
<#
.SYNOPSIS
    Disjuncao registro x catalogo: nome de orphan, typeToken e materializedFolderName
    nao colidem com tipo/folderName do catalogo moderno; catalogType de cada equivalent
    existe no catalogo; modernSuccessor nao nulo existe no catalogo.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'GeneXusObjectTypeCatalogSupport.ps1')

$catalogPath = Get-GeneXusObjectTypeCatalogDefaultBasePath
$catalog = Read-GeneXusObjectTypeCatalogFile -Path $catalogPath

$registryPath = Join-Path $scriptDir 'gx-legacy-export-element-registry.json'
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    throw "Registro nao encontrado: $registryPath"
}
$registry = (Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json)

$catalogTypeNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$catalogFolderNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($property in $catalog.types.PSObject.Properties) {
    [void]$catalogTypeNames.Add([string]$property.Name)
    $entry = $property.Value
    if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
        [void]$catalogFolderNames.Add([string]$entry.folderName)
    }
}

foreach ($property in $registry.elements.PSObject.Properties) {
    $name = $property.Name
    $value = $property.Value
    $class = [string]$value.class

    if ($class -eq 'equivalent') {
        $catalogType = [string]$value.catalogType
        if (-not $catalogTypeNames.Contains($catalogType)) {
            throw "Elemento equivalent '$name' aponta catalogType '$catalogType' inexistente no catalogo."
        }
    }
    elseif ($class -eq 'orphan') {
        if ($catalogTypeNames.Contains($name)) {
            throw "Elemento orphan '$name' colide com tipo do catalogo moderno (nao deveria ter equivalente)."
        }
        $materialized = [string]$value.materializedFolderName
        if ($catalogFolderNames.Contains($materialized) -or $catalogTypeNames.Contains($materialized)) {
            throw "Elemento orphan '$name' tem materializedFolderName '$materialized' que colide com o catalogo."
        }
        $typeToken = [string]$value.typeToken
        if ($catalogTypeNames.Contains($typeToken) -or $catalogFolderNames.Contains($typeToken)) {
            throw "Elemento orphan '$name' tem typeToken '$typeToken' que colide com o catalogo."
        }
        $successorVal = $value.modernSuccessor
        $isNullSuccessor = ($null -eq $successorVal) -or [string]::IsNullOrWhiteSpace([string]$successorVal)
        if (-not $isNullSuccessor -and -not $catalogTypeNames.Contains([string]$successorVal)) {
            throw "Elemento orphan '$name' aponta modernSuccessor '$successorVal' inexistente no catalogo."
        }
    }
    else {
        throw "Elemento '$name' com class '$class' fora de {equivalent, orphan}."
    }
}

Write-Output 'GENEXUS_LEGACY_REGISTRY_DISJOINT_SELFTEST_OK'
