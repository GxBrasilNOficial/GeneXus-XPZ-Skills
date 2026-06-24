#requires -Version 7.4
<#
.SYNOPSIS
    Self-test: Test-XpzObjetosDaKbNaming classifica elemento legado orfao por typeToken, nao como
    TIPO_DESCONHECIDO.

.DESCRIPTION
    Monta uma pasta paralela sintetica com ObjetosDaKbEmXml/Report contendo um XML materializado
    com <Object type="gxlegacy/Report">. Roda o audit de naming -AsJson e prova que:
      - o diretorio Report classifica como NAMING_OK (TipoReal = gxlegacy/Report,
        NomeCanonicoEsperado = Report do registro), em vez de TIPO_DESCONHECIDO;
      - o status geral e NAMING_OK e o exit e 0.
    A correspondencia typeToken -> materializedFolderName vem do registro
    gx-legacy-export-element-registry.json (dinamico), nao inline.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath
$enc = Get-Utf8NoBomEncoding

$scriptDir = $PSScriptRoot

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FALHOU: $Message" }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-naming-legacy-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$reportDir = Join-Path $objetosPath 'Report'
[void](New-Item -ItemType Directory -Path $reportDir -Force)

$reportOrphanXml = @'
<Object type="gxlegacy/Report" name="rptProof" lastUpdate="0001-01-01T00:00:00.0000000Z" dataSource="gx-legacy-export">
  <GxLegacyPayload>
    <Report><Info><Name>rptProof</Name></Info></Report>
  </GxLegacyPayload>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $reportDir 'rptProof.xml'), $reportOrphanXml, $enc)

$namingScript = Join-Path $scriptDir 'Test-XpzObjetosDaKbNaming.ps1'
$output = & $namingScript -ParallelKbRoot $parallelRoot -AsJson
Assert-True ($LASTEXITCODE -eq 0) "Test-XpzObjetosDaKbNaming deveria sair 0 com orfao legado classificado; exit $LASTEXITCODE"

$result = $output | ConvertFrom-Json
Assert-True ($result.status -eq 'NAMING_OK') "status deveria ser NAMING_OK, foi $($result.status)"

$reportRow = @($result.all | Where-Object { $_.Diretorio -eq 'Report' })
Assert-True ($reportRow.Count -eq 1) "deveria haver 1 linha para o diretorio Report, houve $($reportRow.Count)"
Assert-True ($reportRow[0].TipoReal -eq 'gxlegacy/Report') "TipoReal do Report deveria ser gxlegacy/Report, foi $($reportRow[0].TipoReal)"
Assert-True ($reportRow[0].StatusNaming -eq 'OK') "StatusNaming do Report deveria ser OK, foi $($reportRow[0].StatusNaming)"

Write-Output 'OK: Test-XpzObjetosDaKbNamingLegacySelfTest.ps1'
exit 0
