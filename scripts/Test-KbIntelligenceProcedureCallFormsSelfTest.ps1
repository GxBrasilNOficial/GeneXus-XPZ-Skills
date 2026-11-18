#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de formas de chamada de Procedure, WebPanel.Popup e actions de aba gerada no KbIntelligence.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$scriptDir = $PSScriptRoot
$procedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$transactionGuid = '1db606f2-af09-4cf9-a3b5-b481519d28f6'
$workWithGuid = '15cf49b5-fc38-4899-91b5-395d02d79889'
$workWithForWebGuid = '78cecefe-be7d-4980-86ce-8d6e91fba04b'
$webPanelGuid = 'c9584656-94b6-4ccd-890f-332d11fc2c25'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-procedure-call-forms-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$procedureDir = Join-Path $objetosPath 'Procedure'
$transactionDir = Join-Path $objetosPath 'Transaction'
$attributeDir = Join-Path $objetosPath 'Attribute'
$workWithDir = Join-Path $objetosPath 'WorkWith'
$workWithForWebDir = Join-Path $objetosPath 'WorkWithForWeb'
$webPanelDir = Join-Path $objetosPath 'WebPanel'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $procedureDir, $transactionDir, $attributeDir, $workWithDir, $workWithForWebDir, $webPanelDir, $kbIntelDir -Force)

$procedureTargets = @(
    @{ Name = 'PStaticNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222201' },
    @{ Name = 'PCommandNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222202' },
    @{ Name = 'PValueNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222203' },
    @{ Name = 'PMethodNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222204' },
    @{ Name = 'PUnusedNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222205' },
    @{ Name = 'PLinkTargetFake'; Guid = '22222222-2222-2222-2222-222222222207' },
    @{ Name = 'PActionLinkTargetAFake'; Guid = '22222222-2222-2222-2222-222222222208' },
    @{ Name = 'PActionLinkTargetBFake'; Guid = '22222222-2222-2222-2222-222222222209' },
    @{ Name = 'PWrapperFake'; Guid = '22222222-2222-2222-2222-222222222210' },
    @{ Name = 'PPrefixFake'; Guid = '22222222-2222-2222-2222-222222222211' },
    @{ Name = 'PPrefixFakeExtra'; Guid = '22222222-2222-2222-2222-222222222212' },
    @{ Name = 'KProcFake'; Guid = '22222222-2222-2222-2222-222222222213' },
    @{ Name = 'SProcFake'; Guid = '22222222-2222-2222-2222-222222222214' }
)
foreach ($target in $procedureTargets) {
    $xml = @"
<Object type="$procedureGuid" name="$($target.Name)" guid="$($target.Guid)">
  <Source><![CDATA[]]></Source>
</Object>
"@
    [System.IO.File]::WriteAllText((Join-Path $procedureDir ("{0}.xml" -f $target.Name)), $xml, (Get-Utf8NoBomEncoding))
}

$callerXml = @"
<Object type="$procedureGuid" name="PUsesCallFormsFake" guid="22222222-2222-2222-2222-222222222206">
  <Source><![CDATA[
PStaticNoPrefixFake()
PPrefixFakeExtra()
$([char]0x212A)ProcFake()
$([char]0x017F)ProcFake()
Call(PCommandNoPrefixFake, &sdtLog)
&val = udp(PValueNoPrefixFake, 0)
&other = PMethodNoPrefixFake.Udp("C")
&url = PLinkTargetFake.Link(&OrderId)
wpPopupTargetFake.Popup(&OrderId)
//PUnusedNoPrefixFake()
Call(&DynamicProcedureName, &x)
Call(ATT:DynamicProcedureAttribute, &x)
]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'PUsesCallFormsFake.xml'), $callerXml, (Get-Utf8NoBomEncoding))

$popupNegativesXml = @"
<Object type="$procedureGuid" name="PPopupNegativesFake" guid="22222222-2222-2222-2222-222222222215">
  <Source><![CDATA[
//wpPopupTargetFake.Popup(&OrderId)
&wpPopupTargetFake.Popup(&OrderId)
Carga.Popup(TrnMode.Update, &OrderId)
]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'PPopupNegativesFake.xml'), $popupNegativesXml, (Get-Utf8NoBomEncoding))

$webPanelXml = @"
<Object type="$webPanelGuid" name="WPUsesProcedureLinkFake" guid="66666666-6666-6666-6666-666666666601">
  <Source><![CDATA[
Event 'Open'
  Extensions.Web.Window.OpenNewWindow(PActionLinkTargetAFake.Link(&OrderId))
EndEvent
]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'WPUsesProcedureLinkFake.xml'), $webPanelXml, (Get-Utf8NoBomEncoding))

$webPanelTargets = @(
    @{ Name = 'WPPopupTargetFake'; Guid = '66666666-6666-6666-6666-666666666602' },
    @{ Name = 'WPOnlyOtherFake'; Guid = '66666666-6666-6666-6666-666666666603' },
    @{ Name = 'WPGeneralTabFake'; Guid = '66666666-6666-6666-6666-666666666604' },
    @{ Name = 'WPOtherTabFake'; Guid = '66666666-6666-6666-6666-666666666605' }
)
foreach ($target in $webPanelTargets) {
    $targetXml = @"
<Object type="$webPanelGuid" name="$($target.Name)" guid="$($target.Guid)">
  <Source><![CDATA[]]></Source>
</Object>
"@
    [System.IO.File]::WriteAllText((Join-Path $webPanelDir ("{0}.xml" -f $target.Name)), $targetXml, (Get-Utf8NoBomEncoding))
}

$popupCallerXml = @"
<Object type="$webPanelGuid" name="WPUsesPopupFake" guid="66666666-6666-6666-6666-666666666606">
  <Source><![CDATA[
Event 'Open'
  wpPopupTargetFake.Popup()
EndEvent
]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'WPUsesPopupFake.xml'), $popupCallerXml, (Get-Utf8NoBomEncoding))

$transactionXml = @"
<Object type="$transactionGuid" name="TOrderCallFormsFake" guid="33333333-3333-3333-3333-333333333301">
  <Source><![CDATA[
OrderValue = PStaticNoPrefixFake() if OrderValue.IsEmpty() on aftervalidate;
OrderNote = udp(PValueNoPrefixFake, OrderId) if OrderNote.IsEmpty() on aftervalidate;
]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $transactionDir 'TOrderCallFormsFake.xml'), $transactionXml, (Get-Utf8NoBomEncoding))

$attrFormulaXml = @"
<Attribute name="AttrComputedCallFormsFake" guid="44444444-4444-4444-4444-444444444401">
  <Properties>
    <Property><Name>Formula</Name><Value>PStaticNoPrefixFake(0) + Call(PCommandNoPrefixFake, 0) + udp(PValueNoPrefixFake, 0) + PMethodNoPrefixFake.Udp("C") + PLinkTargetFake.Link(0)</Value></Property>
  </Properties>
</Attribute>
"@
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrComputedCallFormsFake.xml'), $attrFormulaXml, (Get-Utf8NoBomEncoding))

$workWithXml = @"
<Object type="$workWithForWebGuid" name="WWCallFormsFake" guid="55555555-5555-5555-5555-555555555501">
  <Condition value="PStaticNoPrefixFake()"/>
  <Condition value="Call(PCommandNoPrefixFake, &amp;Mode)"/>
  <Condition value="PCommandNoPrefixFake.Call()"/>
  <Condition value="udp(PValueNoPrefixFake, OrderId)"/>
  <Condition value="PMethodNoPrefixFake.Udp(&amp;Mode)"/>
  <Grid CommandCondition="Call(PCommandNoPrefixFake, &amp;Mode)"/>
  <Grid FilterCondition="PStaticNoPrefixFake()" RowCondition="PCommandNoPrefixFake.Call()" ColCondition="PMethodNoPrefixFake.Udp(&amp;Mode)"/>
  <action name="OpenIndirectA" gxobject="$procedureGuid-PWrapperFake">
    <parameters>
      <parameter name="PActionLinkTargetAFake.Link(&amp;OrderId)" />
      <parameter name="0" />
    </parameters>
  </action>
  <action name="OpenIndirectB" gxobject="$procedureGuid-PWrapperFake">
    <parameters>
      <parameter name="PActionLinkTargetBFake.Link(procLeEmpresaSessao(), &amp;OrderId)" />
    </parameters>
  </action>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $workWithForWebDir 'WWCallFormsFake.xml'), $workWithXml, (Get-Utf8NoBomEncoding))
$workWithMobileXml = $workWithXml.Replace($workWithForWebGuid, $workWithGuid).Replace('55555555-5555-5555-5555-555555555501', '55555555-5555-5555-5555-555555555502')
[System.IO.File]::WriteAllText((Join-Path $workWithDir 'WWCallFormsFake.xml'), $workWithMobileXml, (Get-Utf8NoBomEncoding))

$workWithTabXml = @"
<Object type="$workWithForWebGuid" name="WWPopupTabFake" guid="55555555-5555-5555-5555-555555555503">
  <Data Pattern="$workWithForWebGuid" Version="1.0"><![CDATA[<?xml version="1.0" encoding="utf-16"?>
<WorkWith>
  <tabs>
    <tab name="General" code="General" type="Tabular" wcname="WPGeneralTabFake">
      <actions>
        <action name="AbreGeneral" gxobject="$webPanelGuid-WPPopupTargetFake" />
      </actions>
    </tab>
    <tab name="Other" code="Other" type="Tabular" wcname="WPOtherTabFake">
      <actions>
        <action name="AbreOther" gxobject="$webPanelGuid-WPOnlyOtherFake" />
      </actions>
    </tab>
  </tabs>
</WorkWith>]]></Data>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $workWithForWebDir 'WWPopupTabFake.xml'), $workWithTabXml, (Get-Utf8NoBomEncoding))

$cases = @(
    @{ id = 'source-static-no-prefix'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
    @{ id = 'source-prefix-keeps-longer-name'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PPrefixFakeExtra'; expected_rule = 'procedure_direct_call'; should_exist = $true },
    @{ id = 'source-prefix-does-not-match-shorter-name'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PPrefixFake'; expected_rule = 'procedure_direct_call'; should_exist = $false },
    @{ id = 'source-kelvin-sign-matches-ascii-name'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:KProcFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
    @{ id = 'source-long-s-does-not-emit-evidence'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:SProcFake'; expected_rule = 'procedure_direct_call'; should_exist = $false },
    @{ id = 'source-call-command'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PCommandNoPrefixFake'; expected_rule = 'procedure_call_command'; should_exist = $true },
    @{ id = 'source-udp-function'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PValueNoPrefixFake'; expected_rule = 'procedure_udp_func'; should_exist = $true },
    @{ id = 'source-dot-udp'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PMethodNoPrefixFake'; expected_rule = 'procedure_dot_udp'; should_exist = $true },
    @{ id = 'source-dot-link'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PLinkTargetFake'; expected_rule = 'procedure_dot_link'; should_exist = $true },
    @{ id = 'webpanel-source-dot-link-open-new-window'; source = 'WebPanel:WPUsesProcedureLinkFake'; target = 'Procedure:PActionLinkTargetAFake'; expected_rule = 'procedure_dot_link'; should_exist = $true },
    @{ id = 'commented-static-call'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PUnusedNoPrefixFake'; expected_rule = 'procedure_direct_call'; should_exist = $false },
    @{ id = 'transaction-rule-static-no-prefix'; source = 'Transaction:TOrderCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
    @{ id = 'attribute-formula-static-no-prefix'; source = 'Attribute:AttrComputedCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'attribute_formula_procedure_direct_call'; should_exist = $true },
    @{ id = 'attribute-formula-call-command'; source = 'Attribute:AttrComputedCallFormsFake'; target = 'Procedure:PCommandNoPrefixFake'; expected_rule = 'attribute_formula_procedure_call_command'; should_exist = $true },
    @{ id = 'attribute-formula-udp-function'; source = 'Attribute:AttrComputedCallFormsFake'; target = 'Procedure:PValueNoPrefixFake'; expected_rule = 'attribute_formula_procedure_udp_func'; should_exist = $true },
    @{ id = 'attribute-formula-dot-udp'; source = 'Attribute:AttrComputedCallFormsFake'; target = 'Procedure:PMethodNoPrefixFake'; expected_rule = 'attribute_formula_procedure_dot_udp'; should_exist = $true },
    @{ id = 'attribute-formula-dot-link'; source = 'Attribute:AttrComputedCallFormsFake'; target = 'Procedure:PLinkTargetFake'; expected_rule = 'attribute_formula_procedure_dot_link'; should_exist = $true },
    @{ id = 'workwith-condition-static-no-prefix'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'workwith_condition_procedure'; should_exist = $true },
    @{ id = 'workwith-mobile-same-name-condition'; source = 'WorkWith:WWCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'workwith_condition_procedure'; should_exist = $true },
    @{ id = 'workwith-condition-call-command'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PCommandNoPrefixFake'; expected_rule = 'workwith_condition_procedure_call_command'; should_exist = $true },
    @{ id = 'workwith-condition-dot-call'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PCommandNoPrefixFake'; expected_rule = 'workwith_condition_procedure_dot_call'; should_exist = $true },
    @{ id = 'workwith-condition-attribute-call-command'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PCommandNoPrefixFake'; expected_rule = 'workwith_condition_attribute_procedure_call_command'; should_exist = $true },
    @{ id = 'workwith-condition-attribute-dot-udp'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PMethodNoPrefixFake'; expected_rule = 'workwith_condition_attribute_procedure_dot_udp'; should_exist = $true },
    @{ id = 'workwith-action-wrapper-gxobject-preserved'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PWrapperFake'; expected_rule = 'workwith_action_gxobject'; should_exist = $true },
    @{ id = 'workwith-action-parameter-procedure-dot-link-a'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PActionLinkTargetAFake'; expected_rule = 'workwith_action_parameter_procedure_dot_link'; should_exist = $true },
    @{ id = 'workwith-action-parameter-procedure-dot-link-b'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PActionLinkTargetBFake'; expected_rule = 'workwith_action_parameter_procedure_dot_link'; should_exist = $true },
    @{ id = 'popup-procedure-source'; source = 'Procedure:PUsesCallFormsFake'; target = 'WebPanel:WPPopupTargetFake'; expected_rule = 'webpanel_dot_popup'; should_exist = $true },
    @{ id = 'popup-webpanel-source'; source = 'WebPanel:WPUsesPopupFake'; target = 'WebPanel:WPPopupTargetFake'; expected_rule = 'webpanel_dot_popup'; should_exist = $true },
    @{ id = 'popup-commented-line-ignored'; source = 'Procedure:PPopupNegativesFake'; target = 'WebPanel:WPPopupTargetFake'; expected_rule = 'webpanel_dot_popup'; should_exist = $false },
    @{ id = 'popup-variable-receiver-ignored'; source = 'Procedure:PPopupNegativesFake'; target = 'WebPanel:WPPopupTargetFake'; expected_rule = 'webpanel_dot_popup'; should_exist = $false },
    @{ id = 'workwith-tab-action-general'; source = 'WebPanel:WPGeneralTabFake'; target = 'WebPanel:WPPopupTargetFake'; expected_rule = 'workwith_tab_action_gxobject'; should_exist = $true },
    @{ id = 'workwith-tab-action-other-does-not-leak'; source = 'WebPanel:WPOtherTabFake'; target = 'WebPanel:WPPopupTargetFake'; expected_rule = 'workwith_tab_action_gxobject'; should_exist = $false },
    @{ id = 'workwith-tab-action-other-own'; source = 'WebPanel:WPOtherTabFake'; target = 'WebPanel:WPOnlyOtherFake'; expected_rule = 'workwith_tab_action_gxobject'; should_exist = $true },
    @{ id = 'workwith-tab-action-general-does-not-leak'; source = 'WebPanel:WPGeneralTabFake'; target = 'WebPanel:WPOnlyOtherFake'; expected_rule = 'workwith_tab_action_gxobject'; should_exist = $false },
    @{ id = 'workwith-tab-level-action-preserved'; source = 'WorkWithForWeb:WWPopupTabFake'; target = 'WebPanel:WPPopupTargetFake'; expected_rule = 'workwith_action_gxobject'; should_exist = $true }
)
$validationCasesPath = Join-Path $kbIntelDir 'procedure-call-forms-validation.json'
[pscustomobject]@{ cases = $cases } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $validationCasesPath -Encoding utf8NoBOM

$sqlitePath = Join-Path $kbIntelDir 'kb-intelligence.sqlite'
$validationPath = Join-Path $kbIntelDir 'kb-intelligence-validation.json'
$indexScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'

& $indexScript `
    -SourceRoot $objetosPath `
    -OutputPath $sqlitePath `
    -ValidationReportPath $validationPath `
    -ValidationCasesPath $validationCasesPath `
    -FailOnValidationFailure `
    -ParallelKbRoot $parallelRoot
if ($LASTEXITCODE -ne 0) {
    throw "Build-KbIntelligenceIndex falhou no self-test de formas de chamada; exit $LASTEXITCODE"
}

$report = Get-Content -LiteralPath $validationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$failed = @($report.cases | Where-Object { $_.status -ne 'passed' })
if ($failed.Count -gt 0) {
    throw "Casos de validacao falharam: $($failed.id -join ', ')"
}

$queryPython = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'
$popupUsesJson = & python $queryPython --index-path $sqlitePath --query who-uses `
    --object-type WebPanel --object-name WPPopupTargetFake --format json
if ($LASTEXITCODE -ne 0) {
    throw "who-uses de WPPopupTargetFake falhou; exit $LASTEXITCODE"
}
$popupUses = $popupUsesJson | ConvertFrom-Json
$popupSources = @($popupUses.results | ForEach-Object { "$($_.source_type):$($_.source_name)" })
foreach ($expectedSource in @(
    'Procedure:PUsesCallFormsFake',
    'WebPanel:WPUsesPopupFake',
    'WebPanel:WPGeneralTabFake',
    'WorkWithForWeb:WWPopupTabFake'
)) {
    if ($popupSources -notcontains $expectedSource) {
        throw "who-uses de WPPopupTargetFake deveria conter $expectedSource; obtido: $($popupSources -join ', ')"
    }
}
if ($popupSources -contains 'WebPanel:WPOtherTabFake') {
    throw "who-uses de WPPopupTargetFake nao deveria atribuir a action a WPOtherTabFake"
}

$tabEvidence = @($popupUses.results | Where-Object {
    $_.source_type -eq 'WebPanel' -and $_.source_name -eq 'WPGeneralTabFake'
})
if ($tabEvidence.Count -ne 1) {
    throw "who-uses de WPPopupTargetFake deveria ter 1 evidencia de WPGeneralTabFake; obtido $($tabEvidence.Count)"
}
if ([string]$tabEvidence[0].source_file -ne 'WorkWithForWeb/WWPopupTabFake.xml') {
    throw "source_file da aba deveria apontar para o XML da WorkWith; obtido '$($tabEvidence[0].source_file)'"
}
if ([int]$tabEvidence[0].line -le 0) {
    throw "line da evidencia da aba deveria ser positiva; obtido $($tabEvidence[0].line)"
}
if ([string]$tabEvidence[0].extractor_rule -ne 'workwith_tab_action_gxobject') {
    throw "regra da evidencia da aba inesperada: $($tabEvidence[0].extractor_rule)"
}

$otherUsesJson = & python $queryPython --index-path $sqlitePath --query who-uses `
    --object-type WebPanel --object-name WPOnlyOtherFake --format json
if ($LASTEXITCODE -ne 0) {
    throw "who-uses de WPOnlyOtherFake falhou; exit $LASTEXITCODE"
}
$otherUses = $otherUsesJson | ConvertFrom-Json
$otherSources = @($otherUses.results | ForEach-Object { "$($_.source_type):$($_.source_name)" })
if ($otherSources -notcontains 'WebPanel:WPOtherTabFake') {
    throw "who-uses de WPOnlyOtherFake deveria conter WebPanel:WPOtherTabFake; obtido: $($otherSources -join ', ')"
}
if ($otherSources -contains 'WebPanel:WPGeneralTabFake') {
    throw "who-uses de WPOnlyOtherFake nao deveria atribuir a action a WPGeneralTabFake"
}

Write-Output 'OK: Test-KbIntelligenceProcedureCallFormsSelfTest.ps1'
exit 0
