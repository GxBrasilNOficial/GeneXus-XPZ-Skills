#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do ramo sem baseline de Get-NewGeneXusLastUpdateValueFromEngine.

.DESCRIPTION
    Entregavel da secao 13.1 do desenho de Edit-GeneXusXmlBatchMetadata.ps1:
    -BaselineXmlPath passou a ser OPCIONAL. Antes era Mandatory = $true, o que
    tornava o ramo "nem o alvo nem o acervo tem lastUpdate legivel" (secao
    2.1-bis) inexecutavel pela propria funcao que a tabela de reuso nomeia.

    Cobre: parametro nao obrigatorio no contrato; chamada sem baseline devolve
    UtcNow + margem; chamada com baseline futuro continua respeitando a regra
    max (nao-regressao do comportamento herdado).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')
. (Join-Path $PSScriptRoot 'GeneXusXmlSurgicalEditSupport.ps1')

function Get-StampUtc {
    param([Parameter(Mandatory = $true)][string]$Value)

    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed)
    if (-not $ok) { throw "Timestamp invalido no teste: '$Value'." }
    return $parsed
}

# 1. Contrato: o parametro NAO pode ser obrigatorio.
$command = Get-Command -Name Get-NewGeneXusLastUpdateValueFromEngine
$parameter = $command.Parameters['BaselineXmlPath']
if ($null -eq $parameter) {
    throw 'Get-NewGeneXusLastUpdateValueFromEngine nao expoe -BaselineXmlPath.'
}
foreach ($attribute in $parameter.Attributes) {
    if ($attribute -is [System.Management.Automation.ParameterAttribute] -and $attribute.Mandatory) {
        throw '-BaselineXmlPath voltou a ser obrigatorio; o ramo sem baseline (secao 2.1-bis) fica inexecutavel.'
    }
}

# 2. Sem baseline: UtcNow + margem.
$margin = 60
$antes = [DateTimeOffset]::UtcNow
$semBaseline = Get-NewGeneXusLastUpdateValueFromEngine -FreshnessMarginSeconds $margin
$depois = [DateTimeOffset]::UtcNow
if ([string]::IsNullOrWhiteSpace($semBaseline)) {
    throw 'Chamada sem baseline nao devolveu timestamp.'
}
$valor = Get-StampUtc -Value $semBaseline
if ($valor -lt $antes.AddSeconds($margin - 2) -or $valor -gt $depois.AddSeconds($margin + 2)) {
    throw "Chamada sem baseline devolveu '$semBaseline', fora da janela UtcNow + $margin s."
}

# 3. Com baseline futuro: regra max preservada (nao-regressao).
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('lastupdate-optional-baseline-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)
try {
    $baselinePath = Join-Path $tempRoot 'baseline.xml'
    $baselineStamp = '2099-01-01T00:00:00.0000000Z'
    [System.IO.File]::WriteAllText(
        $baselinePath,
        '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" + '<Object lastUpdate="' + $baselineStamp + '" />' + "`r`n",
        (Get-Utf8NoBomEncoding))

    $comBaseline = Get-NewGeneXusLastUpdateValueFromEngine -BaselineXmlPath $baselinePath -FreshnessMarginSeconds $margin
    $valorFuturo = Get-StampUtc -Value $comBaseline
    if ($valorFuturo -le (Get-StampUtc -Value $baselineStamp)) {
        throw "Com baseline futuro, o motor deveria devolver baseline + margem; obtido '$comBaseline'."
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output 'OK: Test-GeneXusLastUpdateEngineOptionalBaselineSelfTest.ps1'
exit 0
