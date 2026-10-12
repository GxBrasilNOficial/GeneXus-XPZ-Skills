#requires -Version 7.4

<#
.SYNOPSIS
    Abre uma frente de trabalho XPZ em pasta paralela de KB GeneXus.

.DESCRIPTION
    Cria ou reutiliza uma subpasta de frente em
    ObjetosGeradosParaImportacaoNaKbNoGenexus no formato
    NomeCurto_GUID_YYYYMMDD. Também devolve GUIDs adicionais e timestamp UTC
    formatado como GeneXus lastUpdate para evitar comandos PowerShell compostos
    nos chamadores.

.PARAMETER RepoRoot
    Raiz da pasta paralela da KB.

.PARAMETER NomeCurto
    Identificador curto da frente. Deve casar com [A-Za-z][A-Za-z0-9]{2,40}.

.PARAMETER ExtraGuidCount
    Quantidade de GUIDs adicionais a devolver para objetos novos do lote.

.PARAMETER ReuseIfExists
    Se já existir exatamente uma frente com o mesmo NomeCurto, reutiliza a
    pasta existente. Sem este switch, a existência de frente previa bloqueia.

.PARAMETER AsJson
    Retorna saida JSON estruturada.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$NomeCurto,

    [ValidateRange(0, 1000)]
    [int]$ExtraGuidCount = 0,

    [switch]$ReuseIfExists,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-LastUpdateTimestamp {
    return [DateTime]::UtcNow.ToString(
        "yyyy-MM-dd'T'HH:mm:ss'.0000000Z'",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function New-BlockResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Reason,

        $ResolvedFrontDir = $null
    )

    $result = [ordered]@{
        status              = 'BLOCK'
        nomeCurto           = $NomeCurto
        frontGuid           = $null
        yyyymmdd            = $null
        frontDir            = $ResolvedFrontDir
        createdAtUtc        = New-LastUpdateTimestamp
        extraGuids          = @()
        preExistingFrontDir = $ResolvedFrontDir
        blockingReason      = $Reason
    }

    if ($AsJson) {
        [pscustomobject]$result | ConvertTo-Json -Depth 5
        exit 1
    }

    throw "BLOCK: $Reason"
}

if ($NomeCurto -notmatch '^[A-Za-z][A-Za-z0-9]{2,40}$') {
    New-BlockResult -Reason 'NomeCurto invalido; use [A-Za-z][A-Za-z0-9]{2,40}'
}

if (-not (Test-Path -LiteralPath $RepoRoot -PathType Container)) {
    New-BlockResult -Reason "RepoRoot inexistente ou nao e pasta: $RepoRoot"
}

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$workRoot = Join-Path $resolvedRepoRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus'
if (-not (Test-Path -LiteralPath $workRoot -PathType Container)) {
    New-BlockResult -Reason "RepoRoot nao contem ObjetosGeradosParaImportacaoNaKbNoGenexus: $resolvedRepoRoot"
}

$frontPattern = '^{0}_(?<guid>[0-9a-fA-F]{{8}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{12}})_(?<date>\d{{8}})$' -f [regex]::Escape($NomeCurto)
$preExisting = @(Get-ChildItem -LiteralPath $workRoot -Directory |
    Where-Object { $_.Name -match $frontPattern } |
    Sort-Object FullName)

if ($preExisting.Count -gt 1) {
    $paths = ($preExisting | ForEach-Object { $_.FullName }) -join '; '
    New-BlockResult -Reason "mais de uma frente existente para NomeCurto '$NomeCurto': $paths"
}

$extraGuids = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $ExtraGuidCount; $i++) {
    $extraGuids.Add(([guid]::NewGuid().ToString())) | Out-Null
}

if ($preExisting.Count -eq 1) {
    $existing = $preExisting[0]
    $match = [regex]::Match($existing.Name, $frontPattern)
    if (-not $ReuseIfExists) {
        New-BlockResult -Reason "frente existente para NomeCurto '$NomeCurto'; use -ReuseIfExists para retomar" -ResolvedFrontDir $existing.FullName
    }

    $result = [ordered]@{
        status              = 'REUSED'
        nomeCurto           = $NomeCurto
        frontGuid           = $match.Groups['guid'].Value.ToLowerInvariant()
        yyyymmdd            = $match.Groups['date'].Value
        frontDir            = $existing.FullName
        createdAtUtc        = New-LastUpdateTimestamp
        extraGuids          = $extraGuids.ToArray()
        preExistingFrontDir = $existing.FullName
        blockingReason      = $null
    }
} else {
    $frontGuid = [guid]::NewGuid().ToString()
    $yyyymmdd = (Get-Date).ToString('yyyyMMdd', [System.Globalization.CultureInfo]::InvariantCulture)
    $frontName = '{0}_{1}_{2}' -f $NomeCurto, $frontGuid, $yyyymmdd
    $frontDir = Join-Path $workRoot $frontName

    [void](New-Item -ItemType Directory -Path $frontDir -Force:$false)

    $result = [ordered]@{
        status              = 'OK'
        nomeCurto           = $NomeCurto
        frontGuid           = $frontGuid
        yyyymmdd            = $yyyymmdd
        frontDir            = $frontDir
        createdAtUtc        = New-LastUpdateTimestamp
        extraGuids          = $extraGuids.ToArray()
        preExistingFrontDir = $null
        blockingReason      = $null
    }
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 5
} else {
    [pscustomobject]$result
}
