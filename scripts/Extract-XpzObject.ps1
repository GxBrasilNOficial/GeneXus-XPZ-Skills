#requires -Version 7.4

<#
.SYNOPSIS
Extrai um objeto GeneXus de XML/XPZ sem imprimir o pacote inteiro.

.DESCRIPTION
Aceita um XML com raiz Object/ExportFile ou um XPZ compactado. Localiza objeto
por nome e, opcionalmente, por tipo (nome canonico ou GUID) e retorna apenas o
XML do objeto encontrado, ou um resumo JSON compacto com -SummaryJson.

.PARAMETER InputPath
Caminho do XML ou XPZ.

.PARAMETER ObjectName
Nome do objeto GeneXus a localizar.

.PARAMETER ObjectType
Tipo canonico (Panel, WebPanel, Procedure etc.) ou GUID de Object/@type.

.PARAMETER OutputPath
Quando informado, grava o XML do objeto nesse caminho.

.PARAMETER SummaryJson
Retorna apenas resumo JSON compacto.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$ObjectName,

    [string]$ObjectType,

    [string]$OutputPath,

    [switch]$SummaryJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath


function Read-TextFileFlexible {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    foreach ($encoding in @([System.Text.UTF8Encoding]::new($true), [System.Text.UnicodeEncoding]::new($false, $true))) {
        try {
            return $encoding.GetString($bytes)
        } catch {
            continue
        }
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-TypeGuidMap {
    $catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
    $map = @{}
    if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($prop in $catalog.types.PSObject.Properties) {
            $guid = $prop.Value.objectTypeGuid
            if (-not [string]::IsNullOrWhiteSpace($guid)) {
                $map[$prop.Name.ToLowerInvariant()] = $guid.ToLowerInvariant()
            }
        }
    }
    return $map
}

function Resolve-ObjectTypeGuid {
    param([string]$TypeValue)

    if ([string]::IsNullOrWhiteSpace($TypeValue)) {
        return $null
    }
    if ($TypeValue -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
        return $TypeValue.ToLowerInvariant()
    }
    $map = Get-TypeGuidMap
    $key = $TypeValue.ToLowerInvariant()
    if ($map.ContainsKey($key)) {
        return $map[$key]
    }
    throw "ObjectType desconhecido no catalogo local: $TypeValue"
}

function ConvertTo-XmlDocument {
    param(
        [string]$XmlText,
        [string]$SourceLabel
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    try {
        $doc.LoadXml($XmlText)
        return $doc
    } catch {
        throw "XML malformado em ${SourceLabel}: $($_.Exception.Message)"
    }
}

function Export-ObjectNodeText {
    param([System.Xml.XmlElement]$Node)

    return $Node.OuterXml
}

function Find-ObjectInXml {
    param(
        [string]$XmlText,
        [string]$SourceLabel,
        [string]$Name,
        [string]$TypeGuid
    )

    $doc = ConvertTo-XmlDocument -XmlText $XmlText -SourceLabel $SourceLabel
    $root = $doc.DocumentElement
    $candidates = @()
    if ($root.LocalName -eq 'Object') {
        $candidates = @($root)
    } elseif ($root.LocalName -eq 'ExportFile') {
        $objectsNode = $root.SelectSingleNode('./Objects')
        if ($null -ne $objectsNode) {
            $candidates = @($objectsNode.ChildNodes | Where-Object { $_ -is [System.Xml.XmlElement] -and $_.LocalName -eq 'Object' })
        }
    }
    foreach ($candidate in $candidates) {
        $candidateName = $candidate.GetAttribute('name')
        $candidateType = $candidate.GetAttribute('type').ToLowerInvariant()
        if (-not $candidateName.Equals($Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($TypeGuid) -and $candidateType -ne $TypeGuid) {
            continue
        }
        return [pscustomobject]@{
            source = $SourceLabel
            node = $candidate
        }
    }
    return $null
}

function Find-Object {
    param(
        [string]$Path,
        [string]$Name,
        [string]$TypeGuid
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $extension = [System.IO.Path]::GetExtension($resolvedPath).ToLowerInvariant()
    if ($extension -ne '.xpz' -and $extension -ne '.zip') {
        $text = Read-TextFileFlexible -Path $resolvedPath
        return Find-ObjectInXml -XmlText $text -SourceLabel $resolvedPath -Name $Name -TypeGuid $TypeGuid
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($resolvedPath)
    try {
        foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' })) {
            $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
            try {
                $text = $reader.ReadToEnd()
            } finally {
                $reader.Dispose()
            }
            try {
                $found = Find-ObjectInXml -XmlText $text -SourceLabel ($resolvedPath + '!' + $entry.FullName) -Name $Name -TypeGuid $TypeGuid
                if ($null -ne $found) {
                    return $found
                }
            } catch {
                continue
            }
        }
    } finally {
        $zip.Dispose()
    }
    return $null
}

function New-Summary {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$Source
    )

    $parts = @($ObjectNode.SelectNodes('./Part') | ForEach-Object {
        [ordered]@{
            type = $_.GetAttribute('type')
            hasSource = ($null -ne $_.SelectSingleNode('./Source'))
            hasData = ($null -ne $_.SelectSingleNode('./Data'))
        }
    })
    return [ordered]@{
        source = $Source
        name = $ObjectNode.GetAttribute('name')
        typeGuid = $ObjectNode.GetAttribute('type')
        guid = $ObjectNode.GetAttribute('guid')
        parent = $ObjectNode.GetAttribute('parent')
        parentGuid = $ObjectNode.GetAttribute('parentGuid')
        parentType = $ObjectNode.GetAttribute('parentType')
        moduleGuid = $ObjectNode.GetAttribute('moduleGuid')
        partCount = $parts.Count
        partTypes = @($parts)
    }
}

$resolvedTypeGuid = Resolve-ObjectTypeGuid -TypeValue $ObjectType
$result = Find-Object -Path $InputPath -Name $ObjectName -TypeGuid $resolvedTypeGuid
if ($null -eq $result) {
    throw "Objeto nao encontrado: $ObjectName"
}

if ($SummaryJson) {
    New-Summary -ObjectNode $result.node -Source $result.source | ConvertTo-Json -Depth 8
    return
}

$objectXml = Export-ObjectNodeText -Node $result.node
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($resolvedOutput)
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    }
    [System.IO.File]::WriteAllText($resolvedOutput, $objectXml + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
    [ordered]@{
        status = 'object-extracted'
        outputPath = $resolvedOutput
        source = $result.source
        objectName = $ObjectName
    } | ConvertTo-Json -Depth 4
} else {
    $objectXml
}
