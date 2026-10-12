#requires -Version 7.4

<#
.SYNOPSIS
    Regressao mínima do ramo WebPanel de Get-GeneXusObjectSummary.ps1.

.DESCRIPTION
    Monta uma fixture sanitizada de WebPanel classico (type c9584656...) com:
    - MainTable Responsive (depth 0) contendo TableInner Flex (depth 1, responsiveSizes não vazio);
    - botao na forma <action> (BtnSave) e na forma <ucw gxControlType="-2133704903"> (BtnMenu);
    - um ucw com gxControlType desconhecido (deve cair em unknownUcwControlTypes);
    - um botao-ucw cujo Event ('Ghost') não tem handler no Source de eventos;
    - caption acentuado (Opção) para validar round-trip de encoding.
    Roda o motor e valida o shape e a honestidade de cobertura.
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
$scriptPath = Join-Path $scriptDir 'Get-GeneXusObjectSummary.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Get-GeneXusObjectSummary.ps1 nao encontrado: $scriptPath"
}
$catalogPath = Join-Path $scriptDir 'gx-ucw-gxcontroltype-catalog.json'
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "gx-ucw-gxcontroltype-catalog.json nao encontrado: $catalogPath"
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
<Object name="WPFixtureMenu" type="c9584656-94b6-4ccd-890f-332d11fc2c25" guid="11111111-1111-1111-1111-111111111111">
  <Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778"><Source><![CDATA[<GxMultiForm rootId="1" version="html:15.0.0;layout:17.11.0"><Form id="1" type="layout"><detail><layout><table controlName="MainTable" tableType="Responsive" responsiveSizes="[]"><row><cell><table controlName="TableInner" tableType="Flex" responsiveSizes="[{&quot;scale&quot;:&quot;sm&quot;}]" flexWrap="Wrap"><row><cell><action controlName="BtnConfirm" onClickEvent="Enter" caption="Confirmar" /></cell><cell><action controlName="BtnSave" onClickEvent="'Save'" caption="Salvar" /></cell><cell><ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;BtnMenu&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'OpenMenu'&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;CaptionExpression&lt;/Name&gt;&lt;Value&gt;Opção&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell><ucw gxControlType="-2133704903" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;BtnOrphan&lt;/Value&gt;&lt;/Property&gt;&lt;Property&gt;&lt;Name&gt;Event&lt;/Name&gt;&lt;Value&gt;'Ghost'&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell><ucw gxControlType="-999999999" PATTERN_ELEMENT_CUSTOM_PROPERTIES="&lt;Properties&gt;&lt;Property&gt;&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;UnknownCtl&lt;/Value&gt;&lt;/Property&gt;&lt;/Properties&gt;" /></cell><cell><data attribute="&amp;ClienteNome" labelCaption="Nome:" /></cell></row></table></cell></row></table></layout></detail></Form></GxMultiForm>]]></Source></Part>
  <Part type="c44bd5ff-f918-415b-98e6-aca44fed84fa"><Source><![CDATA[Event Start
EndEvent

Event Enter
EndEvent

Event 'Save'
EndEvent

Event 'OpenMenu'
EndEvent
]]></Source></Part>
</Object>
'@

$tmpFile = Join-Path ([System.IO.Path]::GetTempPath()) ("wp-shape-fixture-{0}.xml" -f ([guid]::NewGuid().ToString('N')))
[System.IO.File]::WriteAllText($tmpFile, $fixtureXml, (Get-Utf8NoBomEncoding))

try {
    $result = & $scriptPath -InputPath $tmpFile -AsJson | ConvertFrom-Json
    $w = $result.webpanel

    Assert-That ($result.typeGuid -eq 'c9584656-94b6-4ccd-890f-332d11fc2c25') 'typeGuid de WebPanel reconhecido'
    Assert-That ($null -eq $result.panel) 'panel permanece null para WebPanel'
    Assert-That ($null -ne $w) 'webpanel preenchido'

    Assert-That ($w.tableCount -eq 2) "tableCount=2 (obtido: $($w.tableCount))"
    $main = $w.tables | Where-Object { $_.controlName -eq 'MainTable' } | Select-Object -First 1
    Assert-That (($null -ne $main) -and ($main.tableType -eq 'Responsive') -and ($main.depth -eq 0)) 'MainTable: Responsive, depth 0'
    $inner = $w.tables | Where-Object { $_.controlName -eq 'TableInner' } | Select-Object -First 1
    Assert-That (($null -ne $inner) -and ($inner.tableType -eq 'Flex') -and ($inner.depth -eq 1) -and ($inner.responsiveSizesNonEmpty)) 'TableInner: Flex, depth 1, responsiveSizes nao vazio'

    Assert-That ($w.buttonCount -eq 4) "buttonCount=4 (obtido: $($w.buttonCount))"
    $menu = $w.buttons | Where-Object { $_.controlName -eq 'BtnMenu' } | Select-Object -First 1
    Assert-That (($null -ne $menu) -and ($menu.form -eq 'ucw-button') -and ($menu.event -eq 'OpenMenu') -and ($menu.caption -eq 'Opção')) 'BtnMenu: ucw-button, evento OpenMenu, caption acentuado preservado'
    $save = $w.buttons | Where-Object { $_.controlName -eq 'BtnSave' } | Select-Object -First 1
    Assert-That (($null -ne $save) -and ($save.form -eq 'action') -and ($save.event -eq 'Save')) 'BtnSave: action, evento Save (aspas removidas)'

    $menuCtl = $w.controls | Where-Object { ($_.tag -eq 'ucw') -and ($_.name -eq 'BtnMenu') } | Select-Object -First 1
    Assert-That (($null -ne $menuCtl) -and ($menuCtl.resolvedType -eq 'Button')) 'controle BtnMenu resolvido como Button via catalogo'
    $unk = $w.controls | Where-Object { $_.gxControlType -eq '-999999999' } | Select-Object -First 1
    Assert-That (($null -ne $unk) -and ($null -eq $unk.resolvedType) -and ($unk.name -eq 'UnknownCtl')) 'ucw desconhecido: resolvedType null, name preservado'
    Assert-That ($w.coverage.unknownUcwControlTypes -contains '-999999999') 'coverage lista gxControlType desconhecido'

    foreach ($ev in @('Start', 'Enter', 'Save', 'OpenMenu')) {
        Assert-That ($w.eventNames -contains $ev) "evento '$ev' detectado no Source"
    }

    $without = @($w.buttonEventCoverage.buttonEventsWithoutHandler)
    Assert-That (($without.Count -eq 1) -and ($without[0] -eq 'Ghost')) "buttonEventsWithoutHandler = [Ghost], sem falso positivo de evento standard (obtido: $($without -join ','))"

    Assert-That (($w.coverage.patternParseErrors -eq 0) -and ($w.coverage.layoutParseErrors -eq 0)) 'sem erros de parse de layout/pattern'
} finally {
    if (Test-Path -LiteralPath $tmpFile -PathType Leaf) {
        Remove-Item -LiteralPath $tmpFile -Force
    }
}

if ($script:failures -gt 0) {
    throw "Contrato WebPanel shape: $($script:failures) assercao(oes) falharam."
}
Write-Host "Contrato WebPanel shape: OK" -ForegroundColor Green
