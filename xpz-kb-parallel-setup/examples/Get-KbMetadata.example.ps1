#requires -version 5.1
<#
.SYNOPSIS
Wrapper local sanitizado para ler campos chave de kb-source-metadata.md.

.DESCRIPTION
Le kb-source-metadata.md na raiz da pasta paralela da KB e retorna campos chave
como texto estruturado. Elimina o padrao recorrente de Select-String + regex
inline nos chamadores.

Campos retornados: last_xpz_materialization_run_at, kb_name, source_guid.
Campos ausentes sao indicados com "(ausente)" em vez de falha silenciosa.

.PARAMETER MetadataPath
Caminho opcional para kb-source-metadata.md.
Quando omitido, usa kb-source-metadata.md na raiz da pasta paralela da KB.

.EXAMPLE
.\Get-KbMetadata.ps1

.EXAMPLE
.\Get-KbMetadata.ps1 -MetadataPath "C:\CAMINHO\PARA\kb-source-metadata.md"
#>

param(
    [string]$MetadataPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $MetadataPath) {
    $MetadataPath = Join-Path $repoRoot 'kb-source-metadata.md'
}

if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
    throw "kb-source-metadata.md not found: $MetadataPath"
}

function Get-DirectFieldValue {
    param(
        [string[]]$Lines,
        [string]$FieldName
    )

    $pattern = '^\s*{0}\s*[:=]\s*(?<value>.+?)\s*$' -f [regex]::Escape($FieldName)
    foreach ($line in $Lines) {
        $match = [regex]::Match($line, $pattern)
        if ($match.Success) {
            return $match.Groups['value'].Value.Trim()
        }
    }

    return $null
}

function Get-MarkdownTableValue {
    param(
        [string[]]$Lines,
        [string]$SectionName,
        [string]$FieldName
    )

    $inSection = $false
    $sectionPattern = '^\s*##\s+{0}\s*$' -f [regex]::Escape($SectionName)

    foreach ($line in $Lines) {
        if ([regex]::IsMatch($line, '^\s*##\s+')) {
            $inSection = [regex]::IsMatch($line, $sectionPattern)
            continue
        }

        if (-not $inSection) {
            continue
        }

        $cells = $line -split '\|'
        if ($cells.Count -lt 4) {
            continue
        }

        $name = $cells[1].Trim()
        $value = $cells[2].Trim()
        if ($name -ieq $FieldName -and $name -notmatch '^-+$') {
            return $value
        }
    }

    return $null
}

$lines = [System.IO.File]::ReadAllLines($MetadataPath)

$lastMaterialization = Get-DirectFieldValue -Lines $lines -FieldName 'last_xpz_materialization_run_at'
$kbName = Get-DirectFieldValue -Lines $lines -FieldName 'kb_name'
$sourceGuid = Get-DirectFieldValue -Lines $lines -FieldName 'source_guid'

if (-not $kbName) {
    $kbName = Get-MarkdownTableValue -Lines $lines -SectionName 'Source/Version' -FieldName 'name'
}

if (-not $sourceGuid) {
    $sourceGuid = Get-MarkdownTableValue -Lines $lines -SectionName 'Source' -FieldName 'kb (GUID)'
}

$values = [ordered]@{
    last_xpz_materialization_run_at = $lastMaterialization
    kb_name = $kbName
    source_guid = $sourceGuid
}

foreach ($field in $values.Keys) {
    $value = $values[$field]
    if ($value) {
        "${field}: $value"
    } else {
        "${field}: (ausente)"
    }
}
