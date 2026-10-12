#requires -Version 7.4

<#
.SYNOPSIS
    Self-test mínimo para extracao de chamadas de método em ExternalObject no KbIntelligence.
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
$externalObjectGuid = 'c163e562-42c6-4158-ad83-5b21a14cf30e'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-external-object-method-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$procedureDir = Join-Path $objetosPath 'Procedure'
$externalObjectDir = Join-Path $objetosPath 'ExternalObject'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $procedureDir, $externalObjectDir, $kbIntelDir -Force)

$externalObjectXml = @"
<Object type="$externalObjectGuid" name="ProgressIndicator" guid="11111111-1111-1111-1111-111111111101">
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $externalObjectDir 'ProgressIndicator.xml'), $externalObjectXml, (Get-Utf8NoBomEncoding))

$shortProcXml = @"
<Object type="$procedureGuid" name="procAtualizaSaldosDasContas" guid="22222222-2222-2222-2222-222222222201">
  <Source><![CDATA[]]></Source>
</Object>
"@
$longProcXml = @"
<Object type="$procedureGuid" name="procAtualizaSaldosDasContasDaLista" guid="22222222-2222-2222-2222-222222222202">
  <Source><![CDATA[]]></Source>
</Object>
"@
$callerXml = @"
<Object type="$procedureGuid" name="procUsaProgressIndicator" guid="22222222-2222-2222-2222-222222222203">
  <Variables>
    <Variable Name="Progress">
      <Properties>
        <Property><Name>ATTCUSTOMTYPE</Name><Value>exo:ProgressIndicator</Value></Property>
      </Properties>
    </Variable>
  </Variables>
  <Source><![CDATA[
&Progress.Show()
procAtualizaSaldosDasContasDaLista()
  ]]></Source>
</Object>
"@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'procAtualizaSaldosDasContas.xml'), $shortProcXml, (Get-Utf8NoBomEncoding))
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'procAtualizaSaldosDasContasDaLista.xml'), $longProcXml, (Get-Utf8NoBomEncoding))
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'procUsaProgressIndicator.xml'), $callerXml, (Get-Utf8NoBomEncoding))

$validationCasesPath = Join-Path $kbIntelDir 'external-object-method-validation.json'
$validationCasesJson = @'
{
  "cases": [
    {
      "id": "external-object-method-call-resolves-variable-custom-type",
      "source": "Procedure:procUsaProgressIndicator",
      "target": "ExternalObject:ProgressIndicator",
      "expected_rule": "source_external_object_method",
      "should_exist": true
    },
    {
      "id": "procedure-direct-call-keeps-exact-callee",
      "source": "Procedure:procUsaProgressIndicator",
      "target": "Procedure:procAtualizaSaldosDasContasDaLista",
      "expected_rule": "procedure_direct_call",
      "should_exist": true
    },
    {
      "id": "procedure-direct-call-does-not-match-substring-callee",
      "source": "Procedure:procUsaProgressIndicator",
      "target": "Procedure:procAtualizaSaldosDasContas",
      "expected_rule": "procedure_direct_call",
      "should_exist": false
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
    throw "Build-KbIntelligenceIndex falhou no self-test de ExternalObject method; exit $LASTEXITCODE"
}

$report = Get-Content -LiteralPath $validationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$failed = @($report.cases | Where-Object { $_.status -ne 'passed' })
if ($failed.Count -gt 0) {
    throw "Casos de validacao falharam: $($failed.id -join ', ')"
}

$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'
$whoUsesJson = & python $queryScript --index-path $sqlitePath --query who-uses --object-type ExternalObject --object-name ProgressIndicator --format json
if ($LASTEXITCODE -ne 0) {
    throw "who-uses falhou; exit $LASTEXITCODE"
}
$whoUses = $whoUsesJson | ConvertFrom-Json
$methodCallSources = @(
    $whoUses.results |
        Where-Object { $_.source_type -eq 'Procedure' -and $_.source_name -eq 'procUsaProgressIndicator' -and $_.extractor_rule -eq 'source_external_object_method' }
)
if ($methodCallSources.Count -lt 1) {
    throw 'who-uses de ExternalObject:ProgressIndicator deveria listar chamada source_external_object_method de Procedure:procUsaProgressIndicator'
}

Write-Output 'OK: Test-KbIntelligenceExternalObjectMethodExtractionSelfTest.ps1'
exit 0
