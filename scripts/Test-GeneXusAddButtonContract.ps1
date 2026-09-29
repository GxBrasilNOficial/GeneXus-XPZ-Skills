#requires -Version 7.4
<#
.SYNOPSIS
    Regressao mínima do contrato Add-GeneXusButton.ps1.

.DESCRIPTION
    Fixture sanitizada de WebPanel com:
    - MainTable Flex contendo a celula folha do controle TBAnchor;
    - RespTable Responsive com responsiveSizes preenchido contendo TBResp;
    - Part de eventos (c44bd5ff) com 'Event Start'.
    Valida: insercao action e ucw em Flex (escrita real, bem-formado, Event stub,
    bump de lastUpdate); insercao -BeforeControlName (nova celula antes da ancora);
    exclusividade mutua das ancoras; gate RESPONSIVE_UNSAFE; ancora inexistente; e
    que -DryRun não altera o arquivo.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = $PSScriptRoot
$scriptPath = Join-Path $scriptDir 'Add-GeneXusButton.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Add-GeneXusButton.ps1 nao encontrado: $scriptPath"
}

$script:failures = 0
function Assert-That {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        $script:failures++
        Write-Host "FAIL: $Message" -ForegroundColor Red
    } else {
        Write-Host "ok  : $Message"
    }
}

$fixtureXml = @'
<?xml version="1.0" encoding="utf-8"?>
<Object name="WPFixtureButtons" type="c9584656-94b6-4ccd-890f-332d11fc2c25" guid="22222222-2222-2222-2222-222222222222" lastUpdate="2020-01-01T00:00:00.0000000Z">
  <Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778"><Source><![CDATA[<GxMultiForm rootId="1" version="html:15.0.0;layout:17.11.0"><Form id="1" type="layout"><detail><layout><table controlName="MainTable" tableType="Flex" responsiveSizes="[]"><row><cell><textblock controlName="TBAnchor" caption="Ancora" /></cell></row><row><cell><table controlName="RespTable" tableType="Responsive" responsiveSizes="[{&quot;scale&quot;:&quot;sm&quot;,&quot;rows&quot;:[[{&quot;width&quot;:50}]]}]"><row><cell><textblock controlName="TBResp" caption="Resp" /></cell></row></table></cell></row></table></layout></detail></Form></GxMultiForm>]]></Source></Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa"><Source><![CDATA[Event Start
EndEvent
]]></Source></Part>
</Object>
'@

function New-FixtureFile {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("add-btn-fixture-{0}.xml" -f ([guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($path, $fixtureXml, (Get-Utf8NoBomEncoding))
    return $path
}

function Invoke-AddButton {
    param([string[]]$ArgList)
    $out = & pwsh -NoProfile -File $scriptPath @ArgList 2>&1
    $code = $LASTEXITCODE
    $text = ($out | Out-String)
    $obj = $null
    try { $obj = $text | ConvertFrom-Json } catch { $obj = $null }
    return [pscustomobject]@{ ExitCode = $code; Json = $obj; Raw = $text }
}

# --- 1) action em Flex (escrita real) -------------------------------------------
$f1 = New-FixtureFile
try {
    $r = Invoke-AddButton -ArgList @('-InputPath', $f1, '-AfterControlName', 'TBAnchor', '-ButtonControlName', 'BtnNew', '-EventName', 'EvNew', '-Caption', 'Novo Botao', '-Class', 'button-primary', '-Form', 'action', '-AsJson')
    Assert-That ($r.ExitCode -eq 0) "action/Flex: exit 0 (obtido: $($r.ExitCode))"
    Assert-That (($null -ne $r.Json) -and ($r.Json.Code -eq 'BUTTON_ADDED') -and ($r.Json.TableType -eq 'Flex') -and ($r.Json.EventStubApplied)) 'action/Flex: BUTTON_ADDED, TableType Flex, Event stub aplicado'
    $written = [System.IO.File]::ReadAllText($f1)
    Assert-That ($written.Contains('<action controlName="BtnNew" onClickEvent="''EvNew''" caption="Novo Botao" class="button-primary" />')) 'action/Flex: snippet <action> presente no arquivo'
    Assert-That ($written.Contains("Event 'EvNew'")) 'action/Flex: Event stub presente no Part de eventos'
    $wf = $false
    try { (New-Object System.Xml.XmlDocument).LoadXml($written); $wf = $true } catch { $wf = $false }
    Assert-That $wf 'action/Flex: XML resultante bem-formado'
    Assert-That (($null -ne $r.Json.LastUpdateAfter) -and ($r.Json.LastUpdateAfter -ne '2020-01-01T00:00:00.0000000Z')) 'action/Flex: lastUpdate bumped'
} finally {
    if (Test-Path -LiteralPath $f1 -PathType Leaf) { Remove-Item -LiteralPath $f1 -Force }
}

# --- 2) ucw em Flex --------------------------------------------------------------
$f2 = New-FixtureFile
try {
    $r = Invoke-AddButton -ArgList @('-InputPath', $f2, '-AfterControlName', 'TBAnchor', '-ButtonControlName', 'BtnUcw', '-EventName', 'EvUcw', '-Caption', 'Menu', '-Form', 'ucw', '-AsJson')
    Assert-That ($r.ExitCode -eq 0) "ucw/Flex: exit 0 (obtido: $($r.ExitCode))"
    $written = [System.IO.File]::ReadAllText($f2)
    Assert-That ($written.Contains('gxControlType="-2133704903"') -and $written.Contains('&lt;Value&gt;BtnUcw&lt;/Value&gt;')) 'ucw/Flex: <ucw> Button com PATTERN escapado presente'
    Assert-That ($written.Contains("&lt;Value&gt;'EvUcw'&lt;/Value&gt;")) 'ucw/Flex: Event do Button serializado com aspas'
} finally {
    if (Test-Path -LiteralPath $f2 -PathType Leaf) { Remove-Item -LiteralPath $f2 -Force }
}

# --- 3) gate Responsive ----------------------------------------------------------
$f3 = New-FixtureFile
try {
    $r = Invoke-AddButton -ArgList @('-InputPath', $f3, '-AfterControlName', 'TBResp', '-ButtonControlName', 'BtnR', '-EventName', 'EvR', '-Caption', 'R', '-AsJson')
    Assert-That ($r.ExitCode -eq 22) "Responsive preenchido: exit 22 (obtido: $($r.ExitCode))"
    Assert-That (($null -ne $r.Json) -and ($r.Json.Code -eq 'RESPONSIVE_UNSAFE')) 'Responsive preenchido: RESPONSIVE_UNSAFE'
    $unchanged = [System.IO.File]::ReadAllText($f3)
    Assert-That ($unchanged -eq $fixtureXml) 'Responsive preenchido: arquivo nao foi alterado'
} finally {
    if (Test-Path -LiteralPath $f3 -PathType Leaf) { Remove-Item -LiteralPath $f3 -Force }
}

# --- 4) ancora inexistente -------------------------------------------------------
$f4 = New-FixtureFile
try {
    $r = Invoke-AddButton -ArgList @('-InputPath', $f4, '-AfterControlName', 'NaoExiste', '-ButtonControlName', 'BtnZ', '-EventName', 'EvZ', '-Caption', 'Z', '-AsJson')
    Assert-That ($r.ExitCode -eq 20) "ancora inexistente: exit 20 (obtido: $($r.ExitCode))"
    Assert-That (($null -ne $r.Json) -and ($r.Json.Code -eq 'ANCHOR_CONTROL_NOT_FOUND')) 'ancora inexistente: ANCHOR_CONTROL_NOT_FOUND'
} finally {
    if (Test-Path -LiteralPath $f4 -PathType Leaf) { Remove-Item -LiteralPath $f4 -Force }
}

# --- 5) DryRun não altera o arquivo ---------------------------------------------
$f5 = New-FixtureFile
try {
    $r = Invoke-AddButton -ArgList @('-InputPath', $f5, '-AfterControlName', 'TBAnchor', '-ButtonControlName', 'BtnD', '-EventName', 'EvD', '-Caption', 'D', '-DryRun', '-AsJson')
    Assert-That ($r.ExitCode -eq 0) "DryRun: exit 0 (obtido: $($r.ExitCode))"
    $afterDry = [System.IO.File]::ReadAllText($f5)
    Assert-That ($afterDry -eq $fixtureXml) 'DryRun: arquivo nao foi alterado'
} finally {
    if (Test-Path -LiteralPath $f5 -PathType Leaf) { Remove-Item -LiteralPath $f5 -Force }
}

# --- 6) BeforeControlName: nova celula inserida ANTES da celula da ancora --------
$f6 = New-FixtureFile
try {
    $r = Invoke-AddButton -ArgList @('-InputPath', $f6, '-BeforeControlName', 'TBAnchor', '-ButtonControlName', 'BtnBefore', '-EventName', 'EvBefore', '-Caption', 'Antes', '-Form', 'action', '-AsJson')
    Assert-That ($r.ExitCode -eq 0) "before/Flex: exit 0 (obtido: $($r.ExitCode))"
    Assert-That (($null -ne $r.Json) -and ($r.Json.Code -eq 'BUTTON_ADDED') -and ($r.Json.Position -eq 'Before') -and ($r.Json.AnchorControlName -eq 'TBAnchor')) 'before/Flex: BUTTON_ADDED, Position Before, AnchorControlName TBAnchor'
    $written = [System.IO.File]::ReadAllText($f6)
    $idxBtn = $written.IndexOf('controlName="BtnBefore"', [System.StringComparison]::Ordinal)
    $idxAnchor = $written.IndexOf('controlName="TBAnchor"', [System.StringComparison]::Ordinal)
    Assert-That (($idxBtn -ge 0) -and ($idxAnchor -ge 0) -and ($idxBtn -lt $idxAnchor)) 'before/Flex: celula do botao precede a celula da ancora no layout'
    $wf = $false
    try { (New-Object System.Xml.XmlDocument).LoadXml($written); $wf = $true } catch { $wf = $false }
    Assert-That $wf 'before/Flex: XML resultante bem-formado'
} finally {
    if (Test-Path -LiteralPath $f6 -PathType Leaf) { Remove-Item -LiteralPath $f6 -Force }
}

# --- 7) ancoras mutuamente exclusivas (parameter sets) ---------------------------
$f7 = New-FixtureFile
try {
    $r = Invoke-AddButton -ArgList @('-InputPath', $f7, '-AfterControlName', 'TBAnchor', '-BeforeControlName', 'TBAnchor', '-ButtonControlName', 'BtnX', '-EventName', 'EvX', '-Caption', 'X', '-AsJson')
    Assert-That ($r.ExitCode -ne 0) "ancoras simultaneas: exit nao-zero (obtido: $($r.ExitCode))"
    $unchanged = [System.IO.File]::ReadAllText($f7)
    Assert-That ($unchanged -eq $fixtureXml) 'ancoras simultaneas: arquivo nao foi alterado'
} finally {
    if (Test-Path -LiteralPath $f7 -PathType Leaf) { Remove-Item -LiteralPath $f7 -Force }
}

# --- 8) unicidade da celula ancora (Get-AnchorOccurrenceCount) -------------------
$dupCell = '<cell><textblock controlName="TBAnchor" caption="Ancora" /></cell>'
$fixtureXmlDup = $fixtureXml.Replace($dupCell, $dupCell + $dupCell)
$f8 = Join-Path ([System.IO.Path]::GetTempPath()) ("add-btn-dup-{0}.xml" -f ([guid]::NewGuid().ToString('N')))
try {
    [System.IO.File]::WriteAllText($f8, $fixtureXmlDup, (Get-Utf8NoBomEncoding))
    $r = Invoke-AddButton -ArgList @('-InputPath', $f8, '-AfterControlName', 'TBAnchor', '-ButtonControlName', 'BtnDup', '-EventName', 'EvDup', '-Caption', 'D', '-AsJson')
    Assert-That ($r.ExitCode -eq 25) "celula ancora duplicada: exit 25 (obtido: $($r.ExitCode))"
    Assert-That (($null -ne $r.Json) -and ($r.Json.Code -eq 'ANCHOR_NOT_UNIQUE')) 'celula ancora duplicada: ANCHOR_NOT_UNIQUE'
    $unchanged = [System.IO.File]::ReadAllText($f8)
    Assert-That ($unchanged -eq $fixtureXmlDup) 'celula ancora duplicada: arquivo nao foi alterado'
} finally {
    if (Test-Path -LiteralPath $f8 -PathType Leaf) { Remove-Item -LiteralPath $f8 -Force }
}

if ($script:failures -gt 0) {
    throw "Contrato Add-GeneXusButton: $($script:failures) assercao(oes) falharam."
}
Write-Host "Contrato Add-GeneXusButton: OK" -ForegroundColor Green
