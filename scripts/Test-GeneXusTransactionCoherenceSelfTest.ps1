#requires -Version 7.4

<#
.SYNOPSIS
    Self-test do gate Test-GeneXusTransactionCoherence.ps1: regra WWP,
    nomes XML, integridade local de Level e classificacoes existentes.

.DESCRIPTION
    Cobre:
    (1) positivo  — Transaction GenerateObject=False com código de tela WorkWithPlus
        DVelop orfao em Events (Call("LoadWWPContext") / Call("<Trn>WW")) dispara fail;
    (2) negativo  — mesma Transaction com Events limpos NÃO dispara;
    (3) negativo  — GenerateObject default (propriedade ausente) com chamada *WW em
        Events NÃO dispara (early-return: tela e gerada, o código não e orfao).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8SupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8SupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8SupportPath"
}
. $utf8SupportPath

$scriptPath = Join-Path $PSScriptRoot 'Test-GeneXusTransactionCoherence.ps1'
$utf8       = Get-Utf8NoBomEncoding
$tempRoot   = Join-Path ([System.IO.Path]::GetTempPath()) ('trncoherence-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$wwpCode        = '07135890-56fc-489b-b408-063722fa9f7d'
$wwpFindingCode = 'wwp-screen-code-on-non-generated-transaction'

function New-TrnXml {
    param(
        [Parameter(Mandatory = $true)][string]$EventsSource,
        [bool]$GenerateObjectFalse,
        [bool]$ApplyWwp
    )
    $props = ''
    if ($GenerateObjectFalse) {
        $props += "    <Property><Name>GenerateObject</Name><Value>False</Value></Property>`n"
    }
    if ($ApplyWwp) {
        $props += "    <Property><Name>Apply:$wwpCode</Name><Value>True</Value></Property>`n"
    }
    return @"
<Object type="1db606f2-af09-4cf9-a3b5-b481519d28f6" name="Trn1" guid="62f63801-fdf0-47a2-a52f-da4f1b035cb8">
  <Part type="264be5fb-1b28-4b25-a598-6ca900dd059f">
    <Level Name="Trn1">
      <Attribute key="True" guid="cad4e441-3180-4271-bb24-059d6090df30">AttrA</Attribute>
    </Level>
  </Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa">
    <Source><![CDATA[$EventsSource]]></Source>
  </Part>
  <Properties>
$props  </Properties>
</Object>
"@
}

function Invoke-Gate {
    param([string]$Xml)
    $f = Join-Path $tempRoot ('trn-{0}.xml' -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($f, $Xml, $utf8)
    return (& $scriptPath -InputPath $f -AsJson | ConvertFrom-Json)
}

function Test-HasWwpFinding {
    param($Result)
    return @($Result.findings | Where-Object { $_.code -eq $wwpFindingCode }).Count -gt 0
}

$eventsDirty = @'

Event Start
  Call("LoadWWPContext", &WWPContext)
EndEvent
Event After Trn
  Call("Trn1WW")
EndEvent
'@

$eventsClean = @'

Event Start
EndEvent
'@

# Caso 1: positivo — GenerateObject=False + código WWP orfao em Events
$r1 = Invoke-Gate (New-TrnXml -EventsSource $eventsDirty -GenerateObjectFalse $true -ApplyWwp $true)
if (-not (Test-HasWwpFinding $r1)) { throw "Caso 1: deveria disparar '$wwpFindingCode'." }
if ($r1.sourceSanityStatus -ne 'fail') { throw "Caso 1: sourceSanityStatus deveria ser 'fail'; obtido '$($r1.sourceSanityStatus)'." }
if ($r1.probablyImportable) { throw 'Caso 1: probablyImportable deveria ser false.' }

# Caso 2: negativo — GenerateObject=False + Events limpos
$r2 = Invoke-Gate (New-TrnXml -EventsSource $eventsClean -GenerateObjectFalse $true -ApplyWwp $true)
if (Test-HasWwpFinding $r2) { throw 'Caso 2: Events limpos nao deveriam disparar a regra WWP.' }

# Caso 3: negativo — GenerateObject default (ausente) + chamada *WW em Events
$r3 = Invoke-Gate (New-TrnXml -EventsSource $eventsDirty -GenerateObjectFalse $false -ApplyWwp $false)
if (Test-HasWwpFinding $r3) { throw 'Caso 3: GenerateObject default (True) nao deveria disparar a regra WWP.' }

# Nomes textuais prevalecem; fallback @name e comparacao sem caixa/espacos.
function New-IntegrityXml {
    param([string]$Levels, [string]$Events = '', [string]$Rules = '')
    return @"
<Object type="1db606f2-af09-4cf9-a3b5-b481519d28f6" name="Integrity">
<Part><Level>$Levels</Level></Part>
<Part><Source><![CDATA[$Events]]></Source></Part>
<Part><Source><![CDATA[$Rules]]></Source></Part>
</Object>
"@
}

function Assert-FindingCount {
    param($Result, [string]$Code, [int]$Count)
    $actual = @($Result.findings | Where-Object code -eq $Code).Count
    if ($actual -ne $Count) { throw "Coherence $Code : esperado $Count, obtido $actual." }
}

$attributes = '<Attribute key="True" name="Ignored"> AttrA </Attribute><Attribute name=" AttrB "> </Attribute>'
$known = Invoke-Gate (New-IntegrityXml $attributes "Event Start`nATTRA.Visible = True`nAttrB = 1`nIgnored.Visible = True`nMissing = 1`nEndEvent" "AttrB.Visible = True;`nMissing.Visible = True;")
Assert-FindingCount $known 'property-on-unknown-attribute' 2
Assert-FindingCount $known 'assignment-to-unknown-name' 1
if (@($known.findings | Where-Object { $_.message -match "'ATTRA\.|'AttrB" }).Count -ne 0) { throw 'Atributos conhecidos receberam aviso.' }

foreach ($descriptor in @('', '<DescriptionAttribute/>', '<DescriptionAttribute> </DescriptionAttribute>', '<DescriptionAttribute> (nOnE) </DescriptionAttribute>', '<DescriptionAttribute> attra </DescriptionAttribute>')) {
    $r = Invoke-Gate (New-IntegrityXml ($attributes + $descriptor))
    Assert-FindingCount $r 'description-attribute-not-in-level' 0
    if ($r.sourceSanityStatus -ne 'pass') { throw 'Descritor valido deveria passar.' }
}
foreach ($level in @(
    ('<Level DescriptionAttribute=" AttrB ">' + $attributes + '</Level>'),
    ('<Level DescriptionAttribute="Missing">' + $attributes + '<DescriptionAttribute>AttrA</DescriptionAttribute></Level>'),
    ('<Level DescriptionAttribute="Missing">' + $attributes + '<DescriptionAttribute>(None)</DescriptionAttribute></Level>'),
    ('<Level DescriptionAttribute="AttrB">' + $attributes + '<DescriptionAttribute> </DescriptionAttribute></Level>')
)) {
    # Parenteses evitam precedencia de virgula/concatenacao no PowerShell.
    $r = Invoke-Gate (New-IntegrityXml ('<Attribute key="True">Root</Attribute>' + $level))
    Assert-FindingCount $r 'description-attribute-not-in-level' 0
}
foreach ($descriptor in @('<DescriptionAttribute>Missing</DescriptionAttribute>', '<DescriptionAttribute>A&apos;B</DescriptionAttribute>')) {
    $r = Invoke-Gate (New-IntegrityXml ($attributes + $descriptor))
    Assert-FindingCount $r 'description-attribute-not-in-level' 1
    if ($r.probablyImportable) { throw 'Descritor invalido deve continuar fail.' }
}
$child = '<Level><Attribute key="True">Child</Attribute><DescriptionAttribute>Child</DescriptionAttribute></Level>'
$r = Invoke-Gate (New-IntegrityXml ($attributes + $child))
Assert-FindingCount $r 'description-attribute-not-in-level' 0
$r = Invoke-Gate (New-IntegrityXml ($attributes + '<DescriptionAttribute>Child</DescriptionAttribute>' + $child))
Assert-FindingCount $r 'description-attribute-not-in-level' 1
$r = Invoke-Gate (New-IntegrityXml ($attributes + '<Level><Attribute key="True">Child</Attribute><DescriptionAttribute>AttrA</DescriptionAttribute></Level>'))
Assert-FindingCount $r 'description-attribute-not-in-level' 1
$r = Invoke-Gate (New-IntegrityXml ('<Attribute>Root</Attribute>' + $child))
Assert-FindingCount $r 'level-no-key' 1

$classified = New-IntegrityXml ($attributes + '<Attribute isRedundant="True"> Redundant </Attribute><Attribute>FormulaAtt</Attribute>') "Event Start`nRedundant = 1`nFormulaAtt = 2`nRedundant.Visible = True`nFormulaAtt.Visible = True`nEndEvent" "Redundant.Visible = True;`nFormulaAtt.Visible = True;"
$r = Invoke-Gate ('<ExportFile><Objects>' + $classified + '</Objects><Attributes><Attribute name="FormulaAtt"><Properties><Property><Name>Formula</Name><Value>1</Value></Property></Properties></Attribute></Attributes></ExportFile>')
Assert-FindingCount $r 'assignment-to-non-writable-attribute' 2
Assert-FindingCount $r 'property-on-non-writable-attribute' 4
Assert-FindingCount $r 'assignment-to-unknown-name' 0
Assert-FindingCount $r 'property-on-unknown-attribute' 0
if (@($r.findings | Where-Object { $_.message -match "classificado como 'formula'" }).Count -ne 3) { throw 'Formula deve manter sua classificacao.' }

$resolvedTempRoot = [System.IO.Path]::GetFullPath($tempRoot)
if (-not $resolvedTempRoot.StartsWith([System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()), [System.StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path $resolvedTempRoot -Leaf) -notlike 'trncoherence-selftest-*') { throw 'Pasta temporaria fora do recorte.' }
Remove-Item -LiteralPath $resolvedTempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OK: Test-GeneXusTransactionCoherenceSelfTest.ps1'
exit 0
