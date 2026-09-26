#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do catalogo (camada 1) e do rastreamento de uso (camada 2) de classes CSS no KbIntelligence.

.DESCRIPTION
    Monta uma KB sintetica cobrindo a matriz: ThemeClass legacy (com caso :hover e heranca),
    DesignSystem autoral (com redeclaracao em @media e comentarios /* */ e //), PackagedModule
    (DesignSystem aninhado, classe importada), e um WebPanel exercitando as 7 formas de uso
    (layout estatico, múltiplas classes, literal aspas simples/duplas, prefixos StyleClass:/ThemeClass:,
    variável dinamica, Format() dinamico, linha comentada) mais uma classe usada e não catalogada.
    Builda o índice, valida casos de relacao e confere as consultas css-classes e css-class-usage.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath
$enc = Get-Utf8NoBomEncoding

$scriptDir = $PSScriptRoot

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-css-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$themeClassDir = Join-Path $objetosPath 'ThemeClass'
$designSystemDir = Join-Path $objetosPath 'DesignSystem'
$packagedModuleDir = Join-Path $objetosPath 'PackagedModule'
$webPanelDir = Join-Path $objetosPath 'WebPanel'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $themeClassDir, $designSystemDir, $packagedModuleDir, $webPanelDir, $kbIntelDir -Force)

# --- ThemeClass legacy ---
$legacyButtonXml = @'
<Object type="d4876646-98dd-419b-8c1c-896f83c48368" name="LegacyButton" guid="11111111-0000-0000-0000-000000000001">
  <Properties>
    <Property><Name>Name</Name><Value>LegacyButton</Value></Property>
  </Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $themeClassDir 'LegacyButton.xml'), $legacyButtonXml, $enc)

# Caso :hover — o filesystem corrompe ':' em '_' no nome do arquivo; o Name real tem ':'.
$legacyHoverXml = @'
<Object type="d4876646-98dd-419b-8c1c-896f83c48368" name="LegacyHover:hover" guid="11111111-0000-0000-0000-000000000002">
  <Properties>
    <Property><Name>Name</Name><Value>LegacyHover:hover</Value></Property>
  </Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $themeClassDir 'LegacyHover_hover.xml'), $legacyHoverXml, $enc)

# Heranca — parent aponta para outra ThemeClass.
$legacyChildXml = @'
<Object type="d4876646-98dd-419b-8c1c-896f83c48368" name="LegacyChild" guid="11111111-0000-0000-0000-000000000003" parent="LegacyButton">
  <Properties>
    <Property><Name>Name</Name><Value>LegacyChild</Value></Property>
  </Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $themeClassDir 'LegacyChild.xml'), $legacyChildXml, $enc)

# --- DesignSystem autoral: Styles part (GUID c6b14574); @media redeclara .Responsive; comentarios não contam. ---
$designSystemXml = @'
<Object type="78b3fa0e-174c-4b2b-8716-718167a428b5" name="dsTest" guid="22222222-0000-0000-0000-000000000001">
  <Part type="75e52d99-6edd-4bad-a1d7-dcc9b7f000ef">
    <Source><![CDATA[tokens Name {
  #colors { primary: #000; }
}]]></Source>
  </Part>
  <Part type="c6b14574-4f5f-4e35-aaa7-e322e88a9a10">
    <Source><![CDATA[Styles dsTest
{
  .PanelTitle { color: #000; }
  .card-basico { padding: 4px; }
  .Responsive { width: 100%; }
  @media (max-width: 1199px) {
    .Responsive { width: 50%; }
  }
  /* .CommentedBlock { color: red; } */
  // .CommentedLine { color: blue; }
}]]></Source>
  </Part>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $designSystemDir 'dsTest.xml'), $designSystemXml, $enc)

# --- PackagedModule: DesignSystem aninhado (mesmo Styles part GUID); classe importada. ---
$packagedModuleXml = @'
<Object type="c88fffcd-b6f8-0000-8fec-00b5497e2117" name="PkgMod" guid="33333333-0000-0000-0000-000000000001">
  <Module>
    <Object type="78b3fa0e-174c-4b2b-8716-718167a428b5" name="NestedDS" guid="33333333-0000-0000-0000-000000000002">
      <Part type="c6b14574-4f5f-4e35-aaa7-e322e88a9a10">
        <Source><![CDATA[Styles NestedDS
{
  .ImportedThing { color: green; }
}]]></Source>
      </Part>
    </Object>
  </Module>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $packagedModuleDir 'PkgMod.xml'), $packagedModuleXml, $enc)

# --- WebPanel: 7 formas de uso + classe não catalogada (UncatalProof). ---
$webPanelXml = @'
<Object type="c9584656-94b6-4ccd-890f-332d11fc2c25" name="wpTest" guid="44444444-0000-0000-0000-000000000001">
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Layout><Table class="PanelTitle"><Cell class="card-basico PanelTitle" cellClass="FormCell" /><Cell class="UncatalProof" GxObjClass="13" /></Table></Layout>
  </Part>
  <Part type="9b0a32a3-de6d-4be1-a4dd-1b85d3741534">
    <Source><![CDATA[
&v1.Class = "PanelTitle"
&v2.Class = 'card-basico'
&v3.Class = 'card-basico PanelTitle'
&v4.Class = StyleClass:PanelTitle
&v5.Class = ThemeClass:LegacyButton
&v6.Class = &someVar
&v7.Class = Format("x-%1", &t)
// &v8.Class = "ShouldBeIgnored"
]]></Source>
  </Part>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'wpTest.xml'), $webPanelXml, $enc)

# --- Casos de validação (relacoes) ---
$validationCasesPath = Join-Path $kbIntelDir 'css-validation.json'
$validationCasesJson = @'
{
  "cases": [
    { "id": "layout-static-resolves", "source": "WebPanel:wpTest", "target": "CssClass:PanelTitle", "expected_rule": "css_layout_class_attribute", "should_exist": true },
    { "id": "layout-uncatalogued-still-tracked", "source": "WebPanel:wpTest", "target": "CssClass:UncatalProof", "expected_rule": "css_layout_class_attribute", "should_exist": true },
    { "id": "layout-cellclass-tracked", "source": "WebPanel:wpTest", "target": "CssClass:FormCell", "expected_rule": "css_layout_class_attribute", "should_exist": true },
    { "id": "layout-gxobjclass-numeric-ignored", "source": "WebPanel:wpTest", "target": "CssClass:13", "expected_rule": "css_layout_class_attribute", "should_exist": false },
    { "id": "event-literal-single-quote", "source": "WebPanel:wpTest", "target": "CssClass:card-basico", "expected_rule": "css_event_class_assignment", "should_exist": true },
    { "id": "event-themeclass-prefix", "source": "WebPanel:wpTest", "target": "CssClass:LegacyButton", "expected_rule": "css_event_class_assignment", "should_exist": true },
    { "id": "event-styleclass-prefix", "source": "WebPanel:wpTest", "target": "CssClass:PanelTitle", "expected_rule": "css_event_class_assignment", "should_exist": true },
    { "id": "commented-line-ignored", "source": "WebPanel:wpTest", "target": "CssClass:ShouldBeIgnored", "expected_rule": "css_event_class_assignment", "should_exist": false }
  ]
}
'@
[System.IO.File]::WriteAllText($validationCasesPath, $validationCasesJson, $enc)

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
    throw "Build-KbIntelligenceIndex falhou no self-test de classes CSS; exit $LASTEXITCODE"
}

$report = Get-Content -LiteralPath $validationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$failed = @($report.cases | Where-Object { $_.status -ne 'passed' })
if ($failed.Count -gt 0) {
    throw "Casos de validacao de relacao falharam: $($failed.id -join ', ')"
}

$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'

function Invoke-CssQuery {
    param([string[]]$QueryArgs)
    $out = & python $queryScript --index-path $sqlitePath @QueryArgs --format json
    if ($LASTEXITCODE -ne 0) {
        throw "Query falhou (args: $($QueryArgs -join ' ')); exit $LASTEXITCODE"
    }
    return ($out | ConvertFrom-Json)
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FALHOU: $Message" }
}

# --- css-classes: visao padrão (só kb-authored) ---
$catalog = Invoke-CssQuery -QueryArgs @('--query', 'css-classes')
$byName = @{}
foreach ($row in $catalog.results) { $byName[$row.class_name] = $row }

Assert-True ($byName.ContainsKey('PanelTitle')) 'PanelTitle deveria estar no catalogo (design-system)'
Assert-True ($byName['PanelTitle'].model -eq 'design-system') 'PanelTitle deveria ser model=design-system'
Assert-True ($byName.ContainsKey('card-basico')) 'card-basico (com hifen) deveria estar no catalogo'
Assert-True ($byName.ContainsKey('Responsive')) 'Responsive deveria estar no catalogo'
$respCount = @($catalog.results | Where-Object { $_.class_name -eq 'Responsive' }).Count
Assert-True ($respCount -eq 1) "Responsive deveria aparecer 1x (dedup de @media), apareceu $respCount"
Assert-True (-not $byName.ContainsKey('CommentedBlock')) 'CommentedBlock (/* */) NAO deveria ser catalogada'
Assert-True (-not $byName.ContainsKey('CommentedLine')) 'CommentedLine (//) NAO deveria ser catalogada'

Assert-True ($byName.ContainsKey('LegacyButton')) 'LegacyButton deveria estar no catalogo (legacy-theme)'
Assert-True ($byName['LegacyButton'].model -eq 'legacy-theme') 'LegacyButton deveria ser model=legacy-theme'
Assert-True ([bool]$byName['LegacyButton'].deprecated) 'LegacyButton (legacy) deveria estar deprecated=true'
Assert-True ($byName.ContainsKey('LegacyHover:hover')) 'Classe legacy deveria usar o Name (LegacyHover:hover), nao o stem'
Assert-True (-not $byName.ContainsKey('LegacyHover_hover')) 'O stem corrompido (LegacyHover_hover) NAO deveria virar nome de classe'
Assert-True ($byName.ContainsKey('LegacyChild')) 'LegacyChild deveria estar no catalogo'
Assert-True ($byName['LegacyChild'].parent_class -eq 'LegacyButton') 'LegacyChild deveria registrar parent_class=LegacyButton'

Assert-True (-not $byName.ContainsKey('ImportedThing')) 'ImportedThing (packaged-module) NAO deveria aparecer na visao padrao'

# --- css-classes: incluindo importadas ---
$catalogImported = Invoke-CssQuery -QueryArgs @('--query', 'css-classes', '--include-imported')
$importedRow = @($catalogImported.results | Where-Object { $_.class_name -eq 'ImportedThing' })
Assert-True ($importedRow.Count -eq 1) 'ImportedThing deveria aparecer com --include-imported'
Assert-True ($importedRow[0].origin -eq 'packaged-module') 'ImportedThing deveria ser origin=packaged-module'

# --- css-class-usage: por classe ---
$usage = Invoke-CssQuery -QueryArgs @('--query', 'css-class-usage', '--object-name', 'PanelTitle')
Assert-True ([bool]$usage.found_in_catalog) 'PanelTitle deveria ser found_in_catalog=true'
Assert-True ($usage.resolvable_uses_total -ge 2) "PanelTitle deveria ter >=2 usos resolviveis, teve $($usage.resolvable_uses_total)"
Assert-True ($usage.dynamic_uses_total -ge 2) "Deveria haver >=2 atribuicoes dinamicas (&someVar e Format), teve $($usage.dynamic_uses_total)"

# --- who-uses: alvo CSS com relacoes, mesmo sem linha correspondente em objects ---
$whoUses = Invoke-CssQuery -QueryArgs @('--query', 'who-uses', '--object-type', 'CssClass', '--object-name', 'PanelTitle')
Assert-True ([bool]$whoUses.found) 'PanelTitle deveria ser found=true pelas relacoes de entrada'
Assert-True ($whoUses.total -ge 1) "PanelTitle deveria ter >=1 relacao de entrada, teve $($whoUses.total)"

# --- css-class-usage: overview com classe usada mas não catalogada ---
$overview = Invoke-CssQuery -QueryArgs @('--query', 'css-class-usage')
Assert-True ($overview.used_but_uncatalogued -contains 'UncatalProof') 'UncatalProof deveria aparecer em used_but_uncatalogued'

Write-Output 'OK: Test-KbIntelligenceCssClassExtractionSelfTest.ps1'
exit 0
