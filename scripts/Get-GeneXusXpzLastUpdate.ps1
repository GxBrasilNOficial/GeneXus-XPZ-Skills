#requires -Version 7.4

<#
.SYNOPSIS
    Gera timestamps UTC no formato GeneXus lastUpdate.

.DESCRIPTION
    Retorna o timestamp UTC canonico formatado como
    yyyy-MM-ddTHH:mm:ss.0000000Z, evitando que agentes precisem compor
    comandos PowerShell inline para preencher lastUpdate em XMLs gerados.

    Quando BaselineXmlPath e informado, calcula o timestamp como:
    max(UtcNow + FreshnessMarginSeconds, baseline lastUpdate + FreshnessMarginSeconds).

.PARAMETER Count
    Quantidade de timestamps a devolver. Default: 1.

.PARAMETER BaselineXmlPath
    Caminho opcional de XML oficial usado como baseline para garantir que
    o novo lastUpdate fique estritamente mais novo que o acervo.

.PARAMETER FreshnessMarginSeconds
    Margem aplicada sobre UtcNow e sobre o baseline. Default: 60.

.PARAMETER AsJson
    Retorna saida JSON estruturada.
#>

[CmdletBinding()]
param(
    [ValidateRange(1, 1000)]
    [int]$Count = 1,

    [string]$BaselineXmlPath,

    [ValidateRange(1, 3600)]
    [int]$FreshnessMarginSeconds = 60,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-GeneXusLastUpdate {
    param([Parameter(Mandatory = $true)][DateTime]$Value)

    $utcValue = $Value.ToUniversalTime()
    return $utcValue.ToString(
        "yyyy-MM-dd'T'HH:mm:ss'.0000000Z'",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Read-GeneXusLastUpdate {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "BaselineXmlPath nao encontrado: $Path"
    }

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $doc.LoadXml($raw)
    $root = $doc.DocumentElement
    if ($null -eq $root) {
        throw "BaselineXmlPath sem elemento raiz: $Path"
    }

    $rawLastUpdate = $root.GetAttribute("lastUpdate")
    if ([string]::IsNullOrWhiteSpace($rawLastUpdate)) {
        throw "BaselineXmlPath sem atributo lastUpdate na raiz '$($root.LocalName)': $Path"
    }

    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $rawLastUpdate,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed
    )
    if (-not $ok) {
        throw "BaselineXmlPath com lastUpdate invalido '$rawLastUpdate': $Path"
    }

    return $parsed.UtcDateTime
}

$baselineLastUpdate = $null
if (-not [string]::IsNullOrWhiteSpace($BaselineXmlPath)) {
    $baselineLastUpdate = Read-GeneXusLastUpdate -Path $BaselineXmlPath
}

$values = [System.Collections.Generic.List[string]]::new()
$baseCandidate = [DateTime]::UtcNow.AddSeconds($FreshnessMarginSeconds)
if ($null -ne $baselineLastUpdate) {
    $baselineCandidate = $baselineLastUpdate.AddSeconds($FreshnessMarginSeconds)
    if ($baselineCandidate -gt $baseCandidate) {
        $baseCandidate = $baselineCandidate
    }
}

for ($i = 0; $i -lt $Count; $i++) {
    $timestamp = Format-GeneXusLastUpdate -Value $baseCandidate.AddSeconds($i)
    $values.Add($timestamp) | Out-Null
}

if ($AsJson) {
    [pscustomobject]@{
        status                 = 'OK'
        count                  = $Count
        freshnessMarginSeconds = $FreshnessMarginSeconds
        baselineXmlPath        = $BaselineXmlPath
        baselineLastUpdate     = if ($null -ne $baselineLastUpdate) { Format-GeneXusLastUpdate -Value $baselineLastUpdate } else { $null }
        lastUpdates            = $values.ToArray()
    } | ConvertTo-Json -Depth 4
    exit 0
}

if ($Count -eq 1) {
    $values[0]
} else {
    $values.ToArray()
}
