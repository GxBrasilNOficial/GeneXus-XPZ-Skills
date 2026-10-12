#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de Set-GeneXusXmlLastUpdate.ps1.

.DESCRIPTION
    Cobre: bump simples in-place, bump com baseline no futuro (regra max), DryRun
    sem gravacao, XML sem lastUpdate (erro), e input inexistente (erro).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function New-FixtureObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$LastUpdate
    )
    return @"
<Object type="84a12160-f59b-4ad7-a683-ea4481ac23e9" name="$Name" guid="$Guid" fullyQualifiedName="$Name" lastUpdate="$LastUpdate">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>$Name</Value>
    </Property>
  </Properties>
  <Source><![CDATA[]]></Source>
</Object>
"@
}

function Get-StampUtc {
    param([Parameter(Mandatory = $true)][string]$Value)
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed
    )
    if (-not $ok) {
        throw "Timestamp invalido no teste: '$Value'."
    }
    return $parsed.UtcDateTime
}

# Le o lastUpdate cru do texto (fonte da verdade), evitando o "smart date" do
# ConvertFrom-Json que transformaria a string ISO em DateTime local.
function Get-LastUpdateFromText {
    param([Parameter(Mandatory = $true)][string]$Text)
    $m = [regex]::Match($Text, 'lastUpdate="([^"]+)"')
    if (-not $m.Success) {
        throw 'lastUpdate nao encontrado no texto.'
    }
    return $m.Groups[1].Value
}

$scriptPath = Join-Path $PSScriptRoot 'Set-GeneXusXmlLastUpdate.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('set-lastupdate-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$objName = 'procBumpTeste'
$objGuid = '11111111-1111-1111-1111-111111111111'
$oldStamp = '2026-01-01T00:00:00.0000000Z'
$utf8 = Get-Utf8NoBomEncoding

# Caso 1: bump simples in-place
$f1 = Join-Path $tempRoot 'obj1.xml'
[System.IO.File]::WriteAllText($f1, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $oldStamp), $utf8)
$r1 = & $scriptPath -InputPath $f1 -AsJson | ConvertFrom-Json
$code1 = $LASTEXITCODE
if ($r1.status -ne 'OK') { throw "Caso 1: status deveria ser OK; obtido '$($r1.status)'." }
if ($code1 -ne 0) { throw "Caso 1: exitCode deveria ser 0; obtido '$code1'." }
$disk1 = Get-Content -LiteralPath $f1 -Raw -Encoding UTF8
$after1 = Get-LastUpdateFromText $disk1
if ($after1 -eq $oldStamp) { throw 'Caso 1: lastUpdate nao foi bumpado no arquivo.' }
if ((Get-StampUtc $after1) -le (Get-StampUtc $oldStamp)) { throw 'Caso 1: novo lastUpdate deveria ser maior que o anterior.' }
if ($disk1 -notmatch '<Value>procBumpTeste</Value>') { throw 'Caso 1: conteudo fora do lastUpdate foi alterado indevidamente.' }
if (Test-Path -LiteralPath "$f1.bak") { throw 'Caso 1: backup .bak nao deveria persistir apos sucesso.' }

# Caso 2: baseline no futuro -> novo lastUpdate respeita o baseline (regra max)
$f2 = Join-Path $tempRoot 'obj2.xml'
$baseline2 = Join-Path $tempRoot 'baseline2.xml'
$futureStamp = '2099-01-01T00:00:00.0000000Z'
[System.IO.File]::WriteAllText($f2, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $oldStamp), $utf8)
[System.IO.File]::WriteAllText($baseline2, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $futureStamp), $utf8)
$r2 = & $scriptPath -InputPath $f2 -BaselineXmlPath $baseline2 -AsJson | ConvertFrom-Json
if ($r2.status -ne 'OK') { throw "Caso 2: status deveria ser OK; obtido '$($r2.status)'." }
$after2 = Get-LastUpdateFromText (Get-Content -LiteralPath $f2 -Raw -Encoding UTF8)
if ((Get-StampUtc $after2) -le (Get-StampUtc $futureStamp)) { throw 'Caso 2: lastUpdate deveria respeitar o baseline futuro (regra max).' }

# Caso 3: DryRun não grava
$f3 = Join-Path $tempRoot 'obj3.xml'
[System.IO.File]::WriteAllText($f3, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $oldStamp), $utf8)
$r3 = & $scriptPath -InputPath $f3 -DryRun -AsJson | ConvertFrom-Json
if ($r3.status -ne 'OK') { throw "Caso 3: status deveria ser OK; obtido '$($r3.status)'." }
if (-not $r3.dryRun) { throw 'Caso 3: dryRun deveria ser true.' }
$disk3 = Get-Content -LiteralPath $f3 -Raw -Encoding UTF8
if ($disk3 -notmatch [regex]::Escape('lastUpdate="' + $oldStamp + '"')) { throw 'Caso 3: DryRun nao deveria ter gravado o arquivo.' }

# Caso 4: XML sem lastUpdate -> NO_LASTUPDATE
$f4 = Join-Path $tempRoot 'obj4.xml'
$noStampXml = "<Object name=""$objName"" guid=""$objGuid"">`n  <Properties>`n    <Property>`n      <Name>Name</Name>`n      <Value>$objName</Value>`n    </Property>`n  </Properties>`n</Object>"
[System.IO.File]::WriteAllText($f4, $noStampXml, $utf8)
$r4 = & $scriptPath -InputPath $f4 -AsJson | ConvertFrom-Json
$code4 = $LASTEXITCODE
if ($r4.status -ne 'ERROR') { throw "Caso 4: status deveria ser ERROR; obtido '$($r4.status)'." }
if ($r4.code -ne 'NO_LASTUPDATE') { throw "Caso 4: code deveria ser NO_LASTUPDATE; obtido '$($r4.code)'." }
if ($code4 -ne 12) { throw "Caso 4: exitCode deveria ser 12; obtido '$code4'." }

# Caso 5: input inexistente -> INPUT_NOT_FOUND
$f5 = Join-Path $tempRoot 'inexistente.xml'
$r5 = & $scriptPath -InputPath $f5 -AsJson | ConvertFrom-Json
$code5 = $LASTEXITCODE
if ($r5.status -ne 'ERROR') { throw "Caso 5: status deveria ser ERROR; obtido '$($r5.status)'." }
if ($r5.code -ne 'INPUT_NOT_FOUND') { throw "Caso 5: code deveria ser INPUT_NOT_FOUND; obtido '$($r5.code)'." }
if ($code5 -ne 14) { throw "Caso 5: exitCode deveria ser 14; obtido '$code5'." }

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OK: Test-SetGeneXusXmlLastUpdateSelfTest.ps1'
exit 0
