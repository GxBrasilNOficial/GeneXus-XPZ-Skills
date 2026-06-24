#requires -Version 7.4
<#
.SYNOPSIS
    Forma intra-registro de gx-legacy-export-element-registry.json: schemaVersion,
    class equivalent|orphan, campos exatos por classe, typeToken e coerencia
    successorRelation x modernSuccessor.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$registryPath = Join-Path $scriptDir 'gx-legacy-export-element-registry.json'
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    throw "Registro nao encontrado: $registryPath"
}

$registry = (Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json)

if ($null -eq $registry.PSObject.Properties['schemaVersion'] -or [int]$registry.schemaVersion -ne 1) {
    throw "schemaVersion esperado 1."
}
if ($null -eq $registry.PSObject.Properties['elements'] -or $null -eq $registry.elements) {
    throw "Registro sem propriedade 'elements'."
}

$typeTokenRegex = [regex]::new('^gxlegacy/[A-Za-z][A-Za-z0-9]*$')
$equivalentFields = @('class', 'catalogType')
$orphanFields = @('class', 'materializedFolderName', 'typeToken', 'modernSuccessor', 'successorRelation')
$knownRelations = @('absorbed', 'none')
$elementCount = 0

foreach ($property in $registry.elements.PSObject.Properties) {
    $name = $property.Name
    $value = $property.Value
    $elementCount++

    if ($null -eq $value.PSObject.Properties['class']) {
        throw "Elemento '$name' sem 'class'."
    }
    $class = [string]$value.class
    $actualFields = @($value.PSObject.Properties.Name | Sort-Object)

    if ($class -eq 'equivalent') {
        $expected = @($equivalentFields | Sort-Object)
        if (($actualFields -join ',') -ne ($expected -join ',')) {
            throw "Elemento equivalent '$name' tem campos [$($actualFields -join ', ')]; esperado [$($expected -join ', ')]."
        }
        if ([string]::IsNullOrWhiteSpace([string]$value.catalogType)) {
            throw "Elemento equivalent '$name' com catalogType vazio."
        }
    }
    elseif ($class -eq 'orphan') {
        $expected = @($orphanFields | Sort-Object)
        if (($actualFields -join ',') -ne ($expected -join ',')) {
            throw "Elemento orphan '$name' tem campos [$($actualFields -join ', ')]; esperado [$($expected -join ', ')]."
        }
        if ([string]::IsNullOrWhiteSpace([string]$value.materializedFolderName)) {
            throw "Elemento orphan '$name' com materializedFolderName vazio."
        }
        $typeToken = [string]$value.typeToken
        if (-not $typeTokenRegex.IsMatch($typeToken)) {
            throw "Elemento orphan '$name' com typeToken '$typeToken' fora do formato ^gxlegacy/[A-Za-z][A-Za-z0-9]*$."
        }
        $relation = [string]$value.successorRelation
        if ($knownRelations -notcontains $relation) {
            throw "Elemento orphan '$name' com successorRelation '$relation' fora do corpus conhecido [$($knownRelations -join ', ')]."
        }
        $successorVal = $value.modernSuccessor
        $isNullSuccessor = ($null -eq $successorVal) -or [string]::IsNullOrWhiteSpace([string]$successorVal)
        if ($relation -eq 'none' -and -not $isNullSuccessor) {
            throw "Elemento orphan '$name' com successorRelation 'none' deve ter modernSuccessor null."
        }
        if ($relation -eq 'absorbed' -and $isNullSuccessor) {
            throw "Elemento orphan '$name' com successorRelation 'absorbed' deve ter modernSuccessor nao nulo."
        }
    }
    else {
        throw "Elemento '$name' com class '$class' fora de {equivalent, orphan}."
    }
}

if ($elementCount -lt 1) {
    throw "Registro sem elementos."
}

Write-Output 'GENEXUS_LEGACY_REGISTRY_SCHEMA_SELFTEST_OK'
