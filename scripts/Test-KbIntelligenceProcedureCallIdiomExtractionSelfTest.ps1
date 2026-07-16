#requires -Version 7.4
<#
.SYNOPSIS
    Self-test minimo para extracao dos idiomas de chamada de procedure legado GeneXus no KbIntelligence:
    call(Proc, ...), udp(Proc, ...) e Proc.udp(...). Cobre a chamada via udp() nas Rules de uma
    Transaction, a Formula de Attribute e as condicoes de WorkWithForWeb (rota <Condition> e rota
    atributo *Condition), onde valem .Call(), udp(...) e .udp(...).
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-proc-call-idiom-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$procedureDir = Join-Path $objetosPath 'Procedure'
$transactionDir = Join-Path $objetosPath 'Transaction'
$attributeDir = Join-Path $objetosPath 'Attribute'
$workWithForWebDir = Join-Path $objetosPath 'WorkWithForWeb'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $procedureDir, $transactionDir, $attributeDir, $workWithForWebDir, $kbIntelDir -Force)

# Alvos: nomes que NAO comecam com "proc" (logo, PROCEDURE_DIRECT_RE nao os pegaria).
$getValueXml = @"
<Object type="$procedureGuid" name="PGetValueFake" guid="22222222-2222-2222-2222-222222222201">
  <Source><![CDATA[]]></Source>
</Object>
"@
$writeLogXml = @"
<Object type="$procedureGuid" name="PWriteLogFake" guid="22222222-2222-2222-2222-222222222202">
  <Source><![CDATA[]]></Source>
</Object>
"@
$lookupXml = @"
<Object type="$procedureGuid" name="PLookupFake" guid="22222222-2222-2222-2222-222222222203">
  <Source><![CDATA[]]></Source>
</Object>
"@
$unusedXml = @"
<Object type="$procedureGuid" name="PUnusedFake" guid="22222222-2222-2222-2222-222222222204">
  <Source><![CDATA[]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'PGetValueFake.xml'), $getValueXml, (Get-Utf8NoBomEncoding))
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'PWriteLogFake.xml'), $writeLogXml, (Get-Utf8NoBomEncoding))
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'PLookupFake.xml'), $lookupXml, (Get-Utf8NoBomEncoding))
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'PUnusedFake.xml'), $unusedXml, (Get-Utf8NoBomEncoding))

# Transaction chamando via udp() nas Rules (idioma valor legado, alvo = primeiro argumento).
$transactionXml = @"
<Object type="$transactionGuid" name="TOrderFake" guid="33333333-3333-3333-3333-333333333301">
  <Source><![CDATA[
OrdNote = udp(PGetValueFake, OrdId) if OrdNote.IsEmpty() on aftervalidate;
]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $transactionDir 'TOrderFake.xml'), $transactionXml, (Get-Utf8NoBomEncoding))

# Procedure chamando via call(...) e via .udp(); linha comentada com PUnusedFake NAO deve resolver.
$callerXml = @"
<Object type="$procedureGuid" name="PUsesIdiomsFake" guid="22222222-2222-2222-2222-222222222205">
  <Source><![CDATA[
call(PWriteLogFake, &sdtLog)
&val = PLookupFake.udp()
//call(PUnusedFake, &x)
]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'PUsesIdiomsFake.xml'), $callerXml, (Get-Utf8NoBomEncoding))

# Attribute com Formula usando udp() (idioma valido em expressao).
$attrFormulaXml = @"
<Attribute name="AttrComputedFake" guid="44444444-4444-4444-4444-444444444401">
  <Properties>
    <Property><Name>Formula</Name><Value>udp(PGetValueFake, 0)</Value></Property>
  </Properties>
</Attribute>
"@
[System.IO.File]::WriteAllText((Join-Path $attributeDir 'AttrComputedFake.xml'), $attrFormulaXml, (Get-Utf8NoBomEncoding))

# WorkWithForWeb: idiomas de chamada de procedure nas condicoes.
#   <Condition value="..."/>  -> extract_workwith_condition_evidence
#   atributo *Condition em tag -> extract_workwith_condition_attribute_evidence
# Cobre .Call(), udp(...) e .udp(...) em ambas as rotas (call() comando nao vale em condicao).
$workWithXml = @"
<Object type="$workWithForWebGuid" name="WWOrderFake" guid="55555555-5555-5555-5555-555555555501">
  <Condition value="PWriteLogFake.Call()"/>
  <Condition value="udp(PLookupFake, OrdId)"/>
  <Condition value="PGetValueFake.udp(0)"/>
  <Grid FilterCondition="udp(PLookupFake, OrdId)" RowCondition="PWriteLogFake.Call()" ColCondition="PGetValueFake.udp(0)"/>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $workWithForWebDir 'WWOrderFake.xml'), $workWithXml, (Get-Utf8NoBomEncoding))

$validationCasesPath = Join-Path $kbIntelDir 'procedure-call-idiom-validation.json'
$validationCasesJson = @'
{
  "cases": [
    {
      "id": "udp-func-in-transaction-rule-resolves-callee",
      "source": "Transaction:TOrderFake",
      "target": "Procedure:PGetValueFake",
      "expected_rule": "procedure_udp_func",
      "should_exist": true
    },
    {
      "id": "call-command-resolves-callee",
      "source": "Procedure:PUsesIdiomsFake",
      "target": "Procedure:PWriteLogFake",
      "expected_rule": "procedure_call_command",
      "should_exist": true
    },
    {
      "id": "dot-udp-resolves-callee",
      "source": "Procedure:PUsesIdiomsFake",
      "target": "Procedure:PLookupFake",
      "expected_rule": "procedure_dot_udp",
      "should_exist": true
    },
    {
      "id": "commented-call-does-not-resolve",
      "source": "Procedure:PUsesIdiomsFake",
      "target": "Procedure:PUnusedFake",
      "expected_rule": "procedure_call_command",
      "should_exist": false
    },
    {
      "id": "udp-in-attribute-formula-resolves-callee",
      "source": "Attribute:AttrComputedFake",
      "target": "Procedure:PGetValueFake",
      "expected_rule": "attribute_formula_procedure_udp_func",
      "should_exist": true
    },
    {
      "id": "workwith-condition-dot-call-resolves-callee",
      "source": "WorkWithForWeb:WWOrderFake",
      "target": "Procedure:PWriteLogFake",
      "expected_rule": "workwith_condition_procedure_dot_call",
      "should_exist": true
    },
    {
      "id": "workwith-condition-udp-func-resolves-callee",
      "source": "WorkWithForWeb:WWOrderFake",
      "target": "Procedure:PLookupFake",
      "expected_rule": "workwith_condition_procedure_udp_func",
      "should_exist": true
    },
    {
      "id": "workwith-condition-dot-udp-resolves-callee",
      "source": "WorkWithForWeb:WWOrderFake",
      "target": "Procedure:PGetValueFake",
      "expected_rule": "workwith_condition_procedure_dot_udp",
      "should_exist": true
    },
    {
      "id": "workwith-condition-attribute-udp-func-resolves-callee",
      "source": "WorkWithForWeb:WWOrderFake",
      "target": "Procedure:PLookupFake",
      "expected_rule": "workwith_condition_attribute_procedure_udp_func",
      "should_exist": true
    },
    {
      "id": "workwith-condition-attribute-dot-call-resolves-callee",
      "source": "WorkWithForWeb:WWOrderFake",
      "target": "Procedure:PWriteLogFake",
      "expected_rule": "workwith_condition_attribute_procedure_dot_call",
      "should_exist": true
    },
    {
      "id": "workwith-condition-attribute-dot-udp-resolves-callee",
      "source": "WorkWithForWeb:WWOrderFake",
      "target": "Procedure:PGetValueFake",
      "expected_rule": "workwith_condition_attribute_procedure_dot_udp",
      "should_exist": true
    }
  ]
}
'@
[System.IO.File]::WriteAllText($validationCasesPath, $validationCasesJson, (Get-Utf8NoBomEncoding))

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
    throw "Build-KbIntelligenceIndex falhou no self-test de idiomas de chamada; exit $LASTEXITCODE"
}

$report = Get-Content -LiteralPath $validationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$failed = @($report.cases | Where-Object { $_.status -ne 'passed' })
if ($failed.Count -gt 0) {
    throw "Casos de validacao falharam: $($failed.id -join ', ')"
}

# Regressao explicita: who-uses do alvo chamado via udp() nas Rules deve listar a Transaction.
$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'
$whoUsesJson = & python $queryScript --index-path $sqlitePath --query who-uses --object-type Procedure --object-name PGetValueFake --format json
if ($LASTEXITCODE -ne 0) {
    throw "who-uses falhou; exit $LASTEXITCODE"
}
$whoUses = $whoUsesJson | ConvertFrom-Json
$udpSources = @(
    $whoUses.results |
        Where-Object { $_.source_type -eq 'Transaction' -and $_.source_name -eq 'TOrderFake' -and $_.extractor_rule -eq 'procedure_udp_func' }
)
if ($udpSources.Count -lt 1) {
    throw 'who-uses de Procedure:PGetValueFake deveria listar chamada procedure_udp_func de Transaction:TOrderFake'
}

# Regressao WorkWith: who-uses do alvo chamado via .udp() em condicao deve listar o WorkWithForWeb.
$workWithSources = @(
    $whoUses.results |
        Where-Object { $_.source_type -eq 'WorkWithForWeb' -and $_.source_name -eq 'WWOrderFake' -and $_.extractor_rule -eq 'workwith_condition_procedure_dot_udp' }
)
if ($workWithSources.Count -lt 1) {
    throw 'who-uses de Procedure:PGetValueFake deveria listar chamada workwith_condition_procedure_dot_udp de WorkWithForWeb:WWOrderFake'
}

Write-Output 'OK: Test-KbIntelligenceProcedureCallIdiomExtractionSelfTest.ps1'
exit 0
