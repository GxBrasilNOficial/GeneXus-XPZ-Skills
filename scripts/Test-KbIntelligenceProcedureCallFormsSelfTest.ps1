#requires -Version 7.4
<#
.SYNOPSIS
    Self-test minimo para extracao de formas de chamada de Procedure no KbIntelligence.
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
$workWithForWebGuid = '78cecefe-be7d-4980-86ce-8d6e91fba04b'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-procedure-call-forms-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$procedureDir = Join-Path $objetosPath 'Procedure'
$transactionDir = Join-Path $objetosPath 'Transaction'
$attributeDir = Join-Path $objetosPath 'Attribute'
$workWithForWebDir = Join-Path $objetosPath 'WorkWithForWeb'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $procedureDir, $transactionDir, $attributeDir, $workWithForWebDir, $kbIntelDir -Force)

$procedureTargets = @(
    @{ Name = 'PStaticNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222201' },
    @{ Name = 'PCommandNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222202' },
    @{ Name = 'PValueNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222203' },
    @{ Name = 'PMethodNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222204' },
    @{ Name = 'PUnusedNoPrefixFake'; Guid = '22222222-2222-2222-2222-222222222205' }
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
Call(PCommandNoPrefixFake, &sdtLog)
&val = udp(PValueNoPrefixFake, 0)
&other = PMethodNoPrefixFake.Udp("C")
//PUnusedNoPrefixFake()
Call(&DynamicProcedureName, &x)
Call(ATT:DynamicProcedureAttribute, &x)
]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'PUsesCallFormsFake.xml'), $callerXml, (Get-Utf8NoBomEncoding))

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
    <Property><Name>Formula</Name><Value>PStaticNoPrefixFake(0) + udp(PValueNoPrefixFake, 0) + PMethodNoPrefixFake.Udp("C")</Value></Property>
  </Properties>
</Attribute>
"@
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrComputedCallFormsFake.xml'), $attrFormulaXml, (Get-Utf8NoBomEncoding))

$workWithXml = @"
<Object type="$workWithForWebGuid" name="WWCallFormsFake" guid="55555555-5555-5555-5555-555555555501">
  <Condition value="PStaticNoPrefixFake()"/>
  <Condition value="PCommandNoPrefixFake.Call()"/>
  <Condition value="udp(PValueNoPrefixFake, OrderId)"/>
  <Condition value="PMethodNoPrefixFake.Udp(&amp;Mode)"/>
  <Grid FilterCondition="PStaticNoPrefixFake()" RowCondition="PCommandNoPrefixFake.Call()" ColCondition="PMethodNoPrefixFake.Udp(&amp;Mode)"/>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $workWithForWebDir 'WWCallFormsFake.xml'), $workWithXml, (Get-Utf8NoBomEncoding))

$cases = @(
    @{ id = 'source-static-no-prefix'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
    @{ id = 'source-call-command'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PCommandNoPrefixFake'; expected_rule = 'procedure_call_command'; should_exist = $true },
    @{ id = 'source-udp-function'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PValueNoPrefixFake'; expected_rule = 'procedure_udp_func'; should_exist = $true },
    @{ id = 'source-dot-udp'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PMethodNoPrefixFake'; expected_rule = 'procedure_dot_udp'; should_exist = $true },
    @{ id = 'commented-static-call'; source = 'Procedure:PUsesCallFormsFake'; target = 'Procedure:PUnusedNoPrefixFake'; expected_rule = 'procedure_direct_call'; should_exist = $false },
    @{ id = 'transaction-rule-static-no-prefix'; source = 'Transaction:TOrderCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
    @{ id = 'attribute-formula-static-no-prefix'; source = 'Attribute:AttrComputedCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'attribute_formula_procedure_direct_call'; should_exist = $true },
    @{ id = 'attribute-formula-udp-function'; source = 'Attribute:AttrComputedCallFormsFake'; target = 'Procedure:PValueNoPrefixFake'; expected_rule = 'attribute_formula_procedure_udp_func'; should_exist = $true },
    @{ id = 'attribute-formula-dot-udp'; source = 'Attribute:AttrComputedCallFormsFake'; target = 'Procedure:PMethodNoPrefixFake'; expected_rule = 'attribute_formula_procedure_dot_udp'; should_exist = $true },
    @{ id = 'workwith-condition-static-no-prefix'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PStaticNoPrefixFake'; expected_rule = 'workwith_condition_procedure'; should_exist = $true },
    @{ id = 'workwith-condition-dot-call'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PCommandNoPrefixFake'; expected_rule = 'workwith_condition_procedure_dot_call'; should_exist = $true },
    @{ id = 'workwith-condition-attribute-dot-udp'; source = 'WorkWithForWeb:WWCallFormsFake'; target = 'Procedure:PMethodNoPrefixFake'; expected_rule = 'workwith_condition_attribute_procedure_dot_udp'; should_exist = $true }
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

Write-Output 'OK: Test-KbIntelligenceProcedureCallFormsSelfTest.ps1'
exit 0
