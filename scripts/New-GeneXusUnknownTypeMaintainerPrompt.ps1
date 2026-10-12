#requires -Version 7.4

<#
.SYNOPSIS
    Gera prompt copiavel para o mantenedor da base GeneXus-XPZ-Skills.

.PARAMETER DiscoveryReportPath
    JSON gerado por Sync (-DiscoveryReportPath) ou inventario (unknownTypesDiscovery).

.PARAMETER InputPath
    Caminho do XPZ/XML quando DiscoveryReportPath omitido e UnknownTypeGuid informado.

.PARAMETER UnknownTypeGuid
    GUID isolado para prompt mínimo quando não houver relatório.

.PARAMETER KbName
    Nome da KB (opcional).

.PARAMETER GeneXusVersion
    Versão GeneXus (opcional).

.PARAMETER WikiLinks
    Links oficiais consultados com consentimento do usuário.

.PARAMETER NexaFindings
    Texto livre com achados nexa.

.PARAMETER OutFile
    Grava o prompt em arquivo UTF-8.

.PARAMETER AsJson
    Retorna JSON com campo promptText.
#>

[CmdletBinding()]
param(
    [string]$DiscoveryReportPath,

    [Alias('Path')]
    [string]$InputPath,

    [string]$UnknownTypeGuid,

    [string]$KbName,

    [string]$GeneXusVersion,

    [string[]]$WikiLinks = @(),

    [string]$NexaFindings,

    [string]$OutFile,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

. (Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1')

$unknownTypes = @()

if (-not [string]::IsNullOrWhiteSpace($DiscoveryReportPath)) {
    if (-not (Test-Path -LiteralPath $DiscoveryReportPath -PathType Leaf)) {
        throw "BLOCK: DiscoveryReportPath nao encontrado: $DiscoveryReportPath"
    }
    $report = Get-Content -LiteralPath $DiscoveryReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $report.unknownTypes) {
        $unknownTypes = @($report.unknownTypes)
    }
} elseif (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    $inventoryScript = Join-Path $PSScriptRoot 'Get-GeneXusImportPackageObjectInventory.ps1'
    $inv = & $inventoryScript -InputPath $InputPath -FailOnUnknownTypes | ConvertFrom-Json
    if ($null -ne $inv.unknownTypesDiscovery) {
        $unknownTypes = @($inv.unknownTypesDiscovery)
    }
} elseif (-not [string]::IsNullOrWhiteSpace($UnknownTypeGuid)) {
    $unknownTypes = @([pscustomobject]@{
            unknownObjectTypeGuid = $UnknownTypeGuid.Trim()
            count                   = 1
            sampleNames             = @()
            sampleParents           = @()
            sampleParentTypes       = @()
            sampleXmlSnippets       = @()
            suggestedFolderName     = ('Unknown_{0}' -f $UnknownTypeGuid.Split('-')[0])
        })
} else {
    throw 'BLOCK: informe DiscoveryReportPath, InputPath ou UnknownTypeGuid.'
}

if ($unknownTypes.Count -eq 0) {
    throw 'BLOCK: nenhum tipo desconhecido no insumo informado.'
}

$promptText = New-GeneXusUnknownTypeMaintainerPromptText -UnknownTypes $unknownTypes -KbName $KbName -GeneXusVersion $GeneXusVersion -WikiLinks $WikiLinks -NexaFindings $NexaFindings

if ($OutFile) {
    [System.IO.File]::WriteAllText($OutFile, $promptText, (Get-Utf8NoBomEncoding))
}

if ($AsJson) {
    [pscustomobject]@{
        status      = 'PROMPT_READY'
        typeCount   = $unknownTypes.Count
        promptText  = $promptText
        outFile     = $OutFile
    } | ConvertTo-Json -Depth 6
} else {
    Write-Output $promptText
}

exit 0
