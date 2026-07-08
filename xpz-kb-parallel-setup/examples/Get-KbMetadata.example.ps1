#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local sanitizado para ler campos chave de kb-source-metadata.md.

.DESCRIPTION
Le kb-source-metadata.md na raiz da pasta paralela da KB e retorna campos chave
como texto estruturado. Elimina o padrão recorrente de Select-String + regex
inline nos chamadores.

O parse de tabelas Markdown usa ReadAllLines + split por pipe + Trim, tolerando
CRLF residual; evite regex multiline terminada em \|$, fragil quando o arquivo
tiver terminadores CR antes do LF.

Campos retornados e sua origem em kb-source-metadata.md:
  last_xpz_materialization_run_at : campo de topo ou frontmatter do arquivo
  kb_name                         : campo "name" na tabela da seção ## Source/Version
  source_guid                     : campo "kb (GUID)" na tabela da seção ## Source
                                    (GUID da KB -- não o GUID da versão em ## Source/Version;
                                    implementacoes que lerem source_guid de ## Source/Version
                                    serao semanticamente incorretas mesmo com parse valido)
  deployment_environment_name     : frontmatter — identificador MSBuild do environment de
                                    validacao/deploy (ex.: NETPostgreSQL); gravado por setup
  deployment_hosting_kind         : frontmatter — valor do registro GeneXusKbHostingKindSupport.ps1
                                    (dotnet-core-self-host, dotnet-framework-iis ou java-tomcat)
  kb_environment_count            : frontmatter — contagem de environments (inventario no setup)
  kb_environment_names            : frontmatter — lista separada por virgula (inventario no setup)
  kb_environment_output_dirs      : frontmatter — pares Environment=DiretorioOutput separados por ;
  kb_environment_web_dirs         : frontmatter — pares Environment=CaminhoWeb separados por ;
  kb_environment_servlet_dirs     : frontmatter — pares Environment=SERVLET_DIR separados por ;
                                    usado em Java/Tomcat e preenchido somente apos confirmacao
  kb_environment_app_package      : frontmatter — pares Environment=PacoteApp separados por ;
  kb_environment_servlet_flavor   : frontmatter — pares Environment=jakarta|javax separados por ;

Campos ausentes são indicados com "(ausente)" em vez de falha silenciosa.

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

$deploymentEnvironment = Get-DirectFieldValue -Lines $lines -FieldName 'deployment_environment_name'
$deploymentHostingKind = Get-DirectFieldValue -Lines $lines -FieldName 'deployment_hosting_kind'
$kbEnvironmentCount = Get-DirectFieldValue -Lines $lines -FieldName 'kb_environment_count'
$kbEnvironmentNames = Get-DirectFieldValue -Lines $lines -FieldName 'kb_environment_names'
$kbEnvironmentOutputDirs = Get-DirectFieldValue -Lines $lines -FieldName 'kb_environment_output_dirs'
$kbEnvironmentWebDirs = Get-DirectFieldValue -Lines $lines -FieldName 'kb_environment_web_dirs'
$kbEnvironmentServletDirs = Get-DirectFieldValue -Lines $lines -FieldName 'kb_environment_servlet_dirs'
$kbEnvironmentAppPackage = Get-DirectFieldValue -Lines $lines -FieldName 'kb_environment_app_package'
$kbEnvironmentServletFlavor = Get-DirectFieldValue -Lines $lines -FieldName 'kb_environment_servlet_flavor'

$values = [ordered]@{
    last_xpz_materialization_run_at = $lastMaterialization
    kb_name = $kbName
    source_guid = $sourceGuid
    deployment_environment_name = $deploymentEnvironment
    deployment_hosting_kind = $deploymentHostingKind
    kb_environment_count = $kbEnvironmentCount
    kb_environment_names = $kbEnvironmentNames
    kb_environment_output_dirs = $kbEnvironmentOutputDirs
    kb_environment_web_dirs = $kbEnvironmentWebDirs
    kb_environment_servlet_dirs = $kbEnvironmentServletDirs
    kb_environment_app_package = $kbEnvironmentAppPackage
    kb_environment_servlet_flavor = $kbEnvironmentServletFlavor
}

foreach ($field in $values.Keys) {
    $value = $values[$field]
    if ($value) {
        "${field}: $value"
    } else {
        "${field}: (ausente)"
    }
}
