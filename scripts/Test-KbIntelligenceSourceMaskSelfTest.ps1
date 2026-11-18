#requires -Version 7.4

<#
.SYNOPSIS
    Self-test do incremento 17a: mascara de Source, Formula, condicoes, layout
    intocado, mixed-layout skip, native-skip, falha fechada (exit 9), escrita
    atomica, modo degradado e metadata.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$procedureGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$webPanelGuid = 'c9584656-94b6-4ccd-890f-332d11fc2c25'
$workWithForWebGuid = '78cecefe-be7d-4980-86ce-8d6e91fba04b'
$indexScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'
$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.ps1'
$queryPython = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'

function Write-ObjectXml {
    param([string]$Path, [string]$TypeGuid, [string]$Name, [string]$Guid, [string]$Source)
    $xml = @"
<Object type="$TypeGuid" name="$Name" guid="$Guid">
  <Source><![CDATA[$Source]]></Source>
</Object>
"@
    [System.IO.File]::WriteAllText($Path, $xml, (New-Object System.Text.UTF8Encoding($false)))
}

function Write-AttributeXml {
    param([string]$Path, [string]$Name, [string]$Guid, [string]$Formula)
    $xml = @"
<Attribute name="$Name" guid="$Guid">
  <Properties>
    <Property><Name>Formula</Name><Value>$Formula</Value></Property>
  </Properties>
</Attribute>
"@
    [System.IO.File]::WriteAllText($Path, $xml, (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-Build {
    param([string]$SourceRoot, [string]$OutputPath, [string]$ReportPath, [string]$CasesPath, [switch]$AllowMaskDegraded)
    $params = @{
        SourceRoot = $SourceRoot
        OutputPath = $OutputPath
        ValidationReportPath = $ReportPath
    }
    if ($CasesPath) { $params.ValidationCasesPath = $CasesPath; $params.FailOnValidationFailure = $true }
    if ($AllowMaskDegraded) { $params.AllowMaskDegraded = $true }
    & $indexScript @params | Out-Null
    return $LASTEXITCODE
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-source-mask-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
try {
    # ---------------------------------------------------------------- KB 1
    $parallelRoot = Join-Path $tempRoot 'KbParalela'
    $objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
    $procedureDir = Join-Path $objetosPath 'Procedure'
    $webPanelDir = Join-Path $objetosPath 'WebPanel'
    $attributeDir = Join-Path $objetosPath 'Attribute'
    $workWithForWebDir = Join-Path $objetosPath 'WorkWithForWeb'
    $kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
    [void](New-Item -ItemType Directory -Path $procedureDir, $webPanelDir, $attributeDir, $workWithForWebDir, $kbIntelDir -Force)

    Write-ObjectXml (Join-Path $procedureDir 'PRealFake.xml') $procedureGuid 'PRealFake' '22222222-2222-2222-2222-222222222201' ''
    Write-ObjectXml (Join-Path $procedureDir 'PFakeTargetFake.xml') $procedureGuid 'PFakeTargetFake' '22222222-2222-2222-2222-222222222202' ''
    Write-ObjectXml (Join-Path $procedureDir 'PStringFalsePositiveFake.xml') $procedureGuid 'PStringFalsePositiveFake' '22222222-2222-2222-2222-222222222203' @'
&msg = 'Antes de PFakeTargetFake()'
PRealFake()
'@
    Write-ObjectXml (Join-Path $procedureDir 'PNativeFake.xml') $procedureGuid 'PNativeFake' '22222222-2222-2222-2222-222222222204' @'
csharp
&msg = "PFakeTargetFake()"
PRealFake()
'@

    $layoutSource = '<GxMultiForm rootId="1" version="x"><Form id="1" type="layout"><detail><layout><table controlName="MainTable"><row><cell><Property><Name>ControlWhere</Name><Value>PRealFake()</Value></Property></cell></row></table></layout></detail></Form></GxMultiForm>'
    Write-ObjectXml (Join-Path $webPanelDir 'WPLayoutFake.xml') $webPanelGuid 'WPLayoutFake' '33333333-3333-3333-3333-333333333301' $layoutSource

    $mixedLayoutSource = @'
// cabecalho
<GxMultiForm rootId='1'><Form><Value>PFakeTargetFake()</Value></Form></GxMultiForm>
'@
    Write-ObjectXml (Join-Path $webPanelDir 'WPMixedLayoutFake.xml') $webPanelGuid 'WPMixedLayoutFake' '33333333-3333-3333-3333-333333333302' $mixedLayoutSource

    $cssEventSource = @'
Event 'MaskCss'
  &ctrl.Class = 'CardMaskFake'
EndEvent
'@
    Write-ObjectXml (Join-Path $webPanelDir 'WPCssMaskFake.xml') $webPanelGuid 'WPCssMaskFake' '33333333-3333-3333-3333-333333333303' $cssEventSource

    # Bloco serialized que contem <GxMultiForm>: nao e mascarado, conta em
    # mixed_layout_skips e fica fora de source_mask_blocks_scanned.
    $serializedMixedSource = '<SerializedRoot><GxMultiForm rootId="1"><Form><Value>PFakeTargetFake()</Value></Form></GxMultiForm></SerializedRoot>'
    Write-ObjectXml (Join-Path $webPanelDir 'WPSerializedMixedFake.xml') $webPanelGuid 'WPSerializedMixedFake' '33333333-3333-3333-3333-333333333304' $serializedMixedSource

    Write-AttributeXml (Join-Path $attributeDir 'AttrMaskFormulaFake.xml') 'AttrMaskFormulaFake' '44444444-4444-4444-4444-444444444401' "PRealFake(0) + 'PFakeTargetFake()'"

    $workWithConditionXml = @"
<Object type="$workWithForWebGuid" name="WWMaskFake" guid="55555555-5555-5555-5555-555555555501">
  <Condition value="PRealFake() + 'PFakeTargetFake()'"/>
</Object>
"@
    [System.IO.File]::WriteAllText((Join-Path $workWithForWebDir 'WWMaskFake.xml'), $workWithConditionXml, (New-Object System.Text.UTF8Encoding($false)))

    $casesPath = Join-Path $kbIntelDir 'source-mask-validation.json'
    $cases = @(
        @{ id = 'source-string-false-positive'; source = 'Procedure:PStringFalsePositiveFake'; target = 'Procedure:PFakeTargetFake'; expected_rule = 'procedure_direct_call'; should_exist = $false },
        @{ id = 'source-string-real-call'; source = 'Procedure:PStringFalsePositiveFake'; target = 'Procedure:PRealFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
        @{ id = 'layout-raw-scan'; source = 'WebPanel:WPLayoutFake'; target = 'Procedure:PRealFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
        @{ id = 'mixed-layout-keeps-current-scan'; source = 'WebPanel:WPMixedLayoutFake'; target = 'Procedure:PFakeTargetFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
        @{ id = 'native-skip-keeps-current-scan'; source = 'Procedure:PNativeFake'; target = 'Procedure:PFakeTargetFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
        @{ id = 'native-skip-real-call'; source = 'Procedure:PNativeFake'; target = 'Procedure:PRealFake'; expected_rule = 'procedure_direct_call'; should_exist = $true },
        @{ id = 'attribute-formula-string-false-positive'; source = 'Attribute:AttrMaskFormulaFake'; target = 'Procedure:PFakeTargetFake'; expected_rule = 'attribute_formula_procedure_direct_call'; should_exist = $false },
        @{ id = 'attribute-formula-real-call'; source = 'Attribute:AttrMaskFormulaFake'; target = 'Procedure:PRealFake'; expected_rule = 'attribute_formula_procedure_direct_call'; should_exist = $true },
        @{ id = 'workwith-condition-string-false-positive'; source = 'WorkWithForWeb:WWMaskFake'; target = 'Procedure:PFakeTargetFake'; expected_rule = 'workwith_condition_procedure'; should_exist = $false },
        @{ id = 'workwith-condition-real-call'; source = 'WorkWithForWeb:WWMaskFake'; target = 'Procedure:PRealFake'; expected_rule = 'workwith_condition_procedure'; should_exist = $true },
        @{ id = 'css-event-class-intact'; source = 'WebPanel:WPCssMaskFake'; target = 'CssClass:CardMaskFake'; expected_rule = 'css_event_class_assignment'; should_exist = $true }
    )
    [pscustomobject]@{ cases = $cases } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $casesPath -Encoding utf8NoBOM

    $sqlitePath = Join-Path $kbIntelDir 'kb-intelligence.sqlite'
    $reportPath = Join-Path $kbIntelDir 'kb-intelligence-validation.json'
    $exit = Invoke-Build -SourceRoot $objetosPath -OutputPath $sqlitePath -ReportPath $reportPath -CasesPath $casesPath
    if ($exit -ne 0) { throw "build da KB 1 falhou com exit $exit" }
    if (-not (Test-Path -LiteralPath $sqlitePath -PathType Leaf)) { throw 'SQLite da KB 1 nao foi gerado' }

    $metadataJson = & $queryScript -IndexPath $sqlitePath -Query index-metadata -ParallelKbRoot $parallelRoot -Format json
    $metadata = $metadataJson | ConvertFrom-Json
    if ([string]$metadata.metadata.source_mask_degraded -ne 'false') {
        throw "source_mask_degraded deveria ser false; obtido $($metadata.metadata.source_mask_degraded)"
    }
    if ([int]$metadata.metadata.source_mask_native_skips -ne 1) {
        throw "source_mask_native_skips deveria ser 1; obtido $($metadata.metadata.source_mask_native_skips)"
    }
    if ([int]$metadata.metadata.source_mask_mixed_layout_skips -ne 2) {
        throw "source_mask_mixed_layout_skips deveria ser 2; obtido $($metadata.metadata.source_mask_mixed_layout_skips)"
    }
    if ([int]$metadata.metadata.source_mask_blocks_scanned -ne 4) {
        throw "source_mask_blocks_scanned deveria ser 4; obtido $($metadata.metadata.source_mask_blocks_scanned)"
    }
    if ([int]$metadata.metadata.source_mask_blocks_masked -ne 2) {
        throw "source_mask_blocks_masked deveria ser 2; obtido $($metadata.metadata.source_mask_blocks_masked)"
    }
    $codeEventsMixed = [int]$metadata.metadata.source_mask_blocks_scanned `
        - [int]$metadata.metadata.source_mask_blocks_masked `
        - [int]$metadata.metadata.source_mask_native_skips
    if ($codeEventsMixed -ne 1) {
        throw "scanned - masked - native deveria ser 1 (mixed de code/events); obtido $codeEventsMixed"
    }
    $kindCounts = $metadata.metadata.source_block_kind_counts | ConvertFrom-Json
    $kindNames = @($kindCounts.PSObject.Properties.Name)
    foreach ($kind in @('code', 'events', 'layout', 'serialized')) {
        if ($kindNames -notcontains $kind) {
            throw "source_block_kind_counts deveria conter '$kind'; obtido $($kindNames -join ',')"
        }
    }
    if ([int]$kindCounts.layout -lt 1 -or [int]$kindCounts.code -lt 1 -or [int]$kindCounts.events -lt 1 -or [int]$kindCounts.serialized -lt 1) {
        throw "source_block_kind_counts deveria contar layout, code, events e serialized; obtido $($metadata.metadata.source_block_kind_counts)"
    }

    $report = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $failed = @($report.cases | Where-Object { $_.status -ne 'passed' })
    if ($failed.Count -gt 0) { throw "Casos de validacao falharam: $($failed.id -join ', ')" }

    $whoUsesJson = & python $queryPython --index-path $sqlitePath --query who-uses --object-type Procedure --object-name PRealFake --format json
    if ($LASTEXITCODE -ne 0) { throw "who-uses falhou; exit $LASTEXITCODE" }
    $whoUses = $whoUsesJson | ConvertFrom-Json
    $sourceEvidence = @($whoUses.results | Where-Object {
        $_.source_type -eq 'Procedure' -and $_.source_name -eq 'PStringFalsePositiveFake'
    })
    if ($sourceEvidence.Count -ne 1) {
        throw "who-uses deveria ter 1 evidencia de PStringFalsePositiveFake; obtido $($sourceEvidence.Count)"
    }
    $evidence = $sourceEvidence[0]
    if ([int]$evidence.line -le 0 -or [int]$evidence.column -le 0) {
        throw "line/column da evidencia invalidos: $($evidence.line)/$($evidence.column)"
    }
    if ([string]$evidence.snippet -notmatch 'PRealFake') {
        throw "snippet da evidencia deveria citar PRealFake; obtido '$($evidence.snippet)'"
    }

    # ---------------------------------------------------------------- KB 2
    $parallelRoot2 = Join-Path $tempRoot 'KbParalela2'
    $objetosPath2 = Join-Path $parallelRoot2 'ObjetosDaKbEmXml'
    $procedureDir2 = Join-Path $objetosPath2 'Procedure'
    $kbIntelDir2 = Join-Path $parallelRoot2 'KbIntelligence'
    [void](New-Item -ItemType Directory -Path $procedureDir2, $kbIntelDir2 -Force)
    Write-ObjectXml (Join-Path $procedureDir2 'PUnterminatedFake.xml') $procedureGuid 'PUnterminatedFake' '22222222-2222-2222-2222-222222222205' @'
&msg = "unterminated
'@
    $sqlitePath2 = Join-Path $kbIntelDir2 'kb-intelligence.sqlite'
    $reportPath2 = Join-Path $kbIntelDir2 'kb-intelligence-validation.json'

    # Escrita atomica: um arquivo pre-existente nao pode ser tocado na falha fechada.
    [System.IO.File]::WriteAllText($sqlitePath2, 'sentinel', (New-Object System.Text.UTF8Encoding($false)))

    $exit2 = Invoke-Build -SourceRoot $objetosPath2 -OutputPath $sqlitePath2 -ReportPath $reportPath2
    if ($exit2 -ne 9) { throw "build sem -AllowMaskDegraded deveria sair 9; obtido $exit2" }
    $sentinel = [System.IO.File]::ReadAllText($sqlitePath2)
    if ($sentinel -ne 'sentinel') {
        throw 'SQLite pre-existente deveria permanecer intacto apos a falha fechada de mascara'
    }

    $exit3 = Invoke-Build -SourceRoot $objetosPath2 -OutputPath $sqlitePath2 -ReportPath $reportPath2 -AllowMaskDegraded
    if ($exit3 -ne 0) { throw "build com -AllowMaskDegraded deveria sair 0; obtido $exit3" }
    $metadata2 = (& $queryScript -IndexPath $sqlitePath2 -Query index-metadata -ParallelKbRoot $parallelRoot2 -Format json) | ConvertFrom-Json
    if ([string]$metadata2.metadata.source_mask_degraded -ne 'true') {
        throw "source_mask_degraded deveria ser true no modo degradado; obtido $($metadata2.metadata.source_mask_degraded)"
    }
    if ([string]$metadata2.metadata.source_mask_degraded_blocks -notmatch 'Procedure/PUnterminatedFake\.xml') {
        throw "source_mask_degraded_blocks deveria citar Procedure/PUnterminatedFake.xml; obtido $($metadata2.metadata.source_mask_degraded_blocks)"
    }
    if ([string]$metadata2.metadata.source_mask_degraded_blocks -notmatch 'unterminated string') {
        throw "source_mask_degraded_blocks deveria citar o motivo; obtido $($metadata2.metadata.source_mask_degraded_blocks)"
    }

    Write-Output 'OK: Test-KbIntelligenceSourceMaskSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
