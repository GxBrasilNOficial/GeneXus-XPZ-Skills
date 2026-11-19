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

# Caso 6: NewObjectNotImported reduz carimbo futuro + rastro
$f6 = Join-Path $tempRoot 'obj6.xml'
$highStamp = '2099-06-01T00:00:00.0000000Z'
[System.IO.File]::WriteAllText($f6, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $highStamp), $utf8)
$raw6 = & $scriptPath -InputPath $f6 -NewObjectNotImported -AsJson 2>$null
$code6 = $LASTEXITCODE
$r6 = $raw6 | ConvertFrom-Json
if ($code6 -ne 0) { throw "Caso 6: exit deveria ser 0; obtido '$code6'." }
if ($r6.status -ne 'OK') { throw "Caso 6: status OK esperado." }
if (-not $r6.lastUpdateRegressed) { throw 'Caso 6: lastUpdateRegressed deveria ser true.' }
if ($r6.lastUpdateRegressReason -ne 'newObjectNotImported') { throw "Caso 6: reason inesperada '$($r6.lastUpdateRegressReason)'." }
$after6 = Get-LastUpdateFromText (Get-Content -LiteralPath $f6 -Raw -Encoding UTF8)
if ((Get-StampUtc $after6) -ge (Get-StampUtc $highStamp)) { throw 'Caso 6: deveria ter reduzido o carimbo futuro.' }
# stdout AsJson deve permanecer JSON valido (uma linha)
$null = [System.Text.Json.JsonDocument]::Parse([string]$raw6)

# Caso 7: baseline explicito antigo + frente futura -> grava com rastro
$f7 = Join-Path $tempRoot 'obj7.xml'
$base7 = Join-Path $tempRoot 'base7.xml'
[System.IO.File]::WriteAllText($f7, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $highStamp), $utf8)
[System.IO.File]::WriteAllText($base7, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate '2020-01-01T00:00:00.0000000Z'), $utf8)
$r7 = & $scriptPath -InputPath $f7 -BaselineXmlPath $base7 -AsJson 2>$null | ConvertFrom-Json
if ($r7.status -ne 'OK') { throw 'Caso 7: status OK esperado.' }
if (-not $r7.lastUpdateRegressed) { throw 'Caso 7: lastUpdateRegressed deveria ser true.' }
if ($r7.lastUpdateRegressReason -ne 'explicitBaselineBelowCurrent') { throw "Caso 7: reason inesperada." }
$after7 = Get-LastUpdateFromText (Get-Content -LiteralPath $f7 -Raw -Encoding UTF8)
if ((Get-StampUtc $after7) -ge (Get-StampUtc $highStamp)) { throw 'Caso 7: deveria ter baixado o carimbo acumulado.' }

# Caso 8: self in-place nao regride
$f8 = Join-Path $tempRoot 'obj8.xml'
[System.IO.File]::WriteAllText($f8, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $oldStamp), $utf8)
$r8 = & $scriptPath -InputPath $f8 -AsJson | ConvertFrom-Json
if ($r8.status -ne 'OK') { throw 'Caso 8: status OK esperado.' }
if ($r8.lastUpdateRegressed) { throw 'Caso 8: self in-place nao deveria marcar regressed.' }

# Caso 9: OutputPath com carimbo maior + self -> LASTUPDATE_REGRESSED
$f9in = Join-Path $tempRoot 'obj9-in.xml'
$f9out = Join-Path $tempRoot 'obj9-out.xml'
[System.IO.File]::WriteAllText($f9in, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $oldStamp), $utf8)
[System.IO.File]::WriteAllText($f9out, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $highStamp), $utf8)
$before9 = Get-Content -LiteralPath $f9out -Raw -Encoding UTF8
$r9 = & $scriptPath -InputPath $f9in -OutputPath $f9out -AsJson | ConvertFrom-Json
$code9 = $LASTEXITCODE
if ($r9.status -ne 'ERROR') { throw 'Caso 9: status ERROR esperado.' }
if ($r9.code -ne 'LASTUPDATE_REGRESSED') { throw "Caso 9: code LASTUPDATE_REGRESSED esperado; obtido '$($r9.code)'." }
if ($code9 -ne 37) { throw "Caso 9: exit 37 esperado; obtido '$code9'." }
$after9disk = Get-Content -LiteralPath $f9out -Raw -Encoding UTF8
if ($after9disk -cne $before9) { throw 'Caso 9: destino nao deveria ter sido alterado.' }

# Caso 10: atual ilegivel no destino -> LASTUPDATE_UNREADABLE
$f10in = Join-Path $tempRoot 'obj10-in.xml'
$f10out = Join-Path $tempRoot 'obj10-out.xml'
$badStamp = '2026-13-40T99:99:99.0000000Z'
[System.IO.File]::WriteAllText($f10in, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $oldStamp), $utf8)
[System.IO.File]::WriteAllText($f10out, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $badStamp), $utf8)
$r10 = & $scriptPath -InputPath $f10in -OutputPath $f10out -AsJson | ConvertFrom-Json
$code10 = $LASTEXITCODE
if ($r10.code -ne 'LASTUPDATE_UNREADABLE') { throw "Caso 10: LASTUPDATE_UNREADABLE esperado; obtido '$($r10.code)'." }
if ($code10 -ne 38) { throw "Caso 10: exit 38 esperado; obtido '$code10'." }

# Caso 11: DryRun com NewObjectNotImported reporta regressao e nao grava
$f11 = Join-Path $tempRoot 'obj11.xml'
[System.IO.File]::WriteAllText($f11, (New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $highStamp), $utf8)
$r11 = & $scriptPath -InputPath $f11 -NewObjectNotImported -DryRun -AsJson 2>$null | ConvertFrom-Json
if ($r11.status -ne 'OK' -or -not $r11.dryRun) { throw 'Caso 11: DryRun OK esperado.' }
if (-not $r11.lastUpdateRegressed) { throw 'Caso 11: deveria reportar regressed.' }
$disk11 = Get-Content -LiteralPath $f11 -Raw -Encoding UTF8
if ($disk11 -notmatch [regex]::Escape('lastUpdate="' + $highStamp + '"')) { throw 'Caso 11: DryRun nao deveria gravar.' }

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OK: Test-SetGeneXusXmlLastUpdateSelfTest.ps1'
exit 0
