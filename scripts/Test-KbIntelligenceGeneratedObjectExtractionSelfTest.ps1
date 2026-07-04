#requires -Version 7.4
<#
.SYNOPSIS
    Self-test da extracao de objetos gerados por Pattern (IsGeneratedObject / PatternObjectId /
    InstanceKey) no KbIntelligence e do filtro --generated/--authored.

.DESCRIPTION
    Monta uma KB sintetica cobrindo a matriz do design convergido:
      - WebPanel gerado (flag + companheiras, com Part antes do Properties raiz);
      - WebPanel autoral (sem marcador -> 0);
      - WebPanel MALFORMADO (XML invalido -> caminho de FALLBACK regex; flag + PatternObjectId no bloco raiz);
      - Procedure divergente (flag SEM companheiras, caso ListPrograms);
      - PackagedModule CONTEINER (flag em <Object> ANINHADO sob <Part><ExportFile>; raiz autoral -> 0,
        guarda contra o gap da extracao whole-file).
    Builda o indice e confere object-info (JSON e texto), o filtro --generated/--authored no motor .py
    e no wrapper .ps1 (processo filho), e o contador generated_objects_count / schema_version na metadata.
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

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-genobj-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$webPanelDir = Join-Path $objetosPath 'WebPanel'
$procedureDir = Join-Path $objetosPath 'Procedure'
$packagedModuleDir = Join-Path $objetosPath 'PackagedModule'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $webPanelDir, $procedureDir, $packagedModuleDir, $kbIntelDir -Force)

# --- WebPanel gerado: Part (com Properties proprio) ANTES do Properties de nivel-objeto ---
$wpGeneratedXml = @'
<Object type="c9584656-94b6-4ccd-890f-332d11fc2c25" name="wpGenerated" guid="11110000-0000-0000-0000-000000000001">
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Properties><Property><Name>IsDefault</Name><Value>False</Value></Property></Properties>
  </Part>
  <Properties><Property><Name>Name</Name><Value>wpGenerated</Value></Property><Property><Name>IsGeneratedObject</Name><Value>True</Value></Property><Property><Name>InstanceKey</Name><Value>78cecefe-be7d-4980-86ce-8d6e91fba04b-WorkWithWebFoo</Value></Property><Property><Name>PatternObjectId</Name><Value>TabGrid</Value></Property></Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'wpGenerated.xml'), $wpGeneratedXml, $enc)

# --- WebPanel autoral: Properties raiz sem o marcador ---
$wpAuthoredXml = @'
<Object type="c9584656-94b6-4ccd-890f-332d11fc2c25" name="wpAuthored" guid="11110000-0000-0000-0000-000000000002">
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Properties><Property><Name>IsDefault</Name><Value>False</Value></Property></Properties>
  </Part>
  <Properties><Property><Name>Name</Name><Value>wpAuthored</Value></Property></Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'wpAuthored.xml'), $wpAuthoredXml, $enc)

# --- WebPanel MALFORMADO: <Table> aberto e fechado por </Layout> -> ElementTree.ParseError -> FALLBACK ---
$wpMalformedXml = @'
<Object type="c9584656-94b6-4ccd-890f-332d11fc2c25" name="wpMalformed" guid="11110000-0000-0000-0000-000000000003">
  <Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9">
    <Layout><Table class="X"></Layout>
  </Part>
  <Properties><Property><Name>Name</Name><Value>wpMalformed</Value></Property><Property><Name>IsGeneratedObject</Name><Value>True</Value></Property><Property><Name>PatternObjectId</Name><Value>Selection</Value></Property></Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'wpMalformed.xml'), $wpMalformedXml, $enc)

# --- Procedure divergente: flag SEM companheiras (caso ListPrograms) ---
$procDivergentXml = @'
<Object type="84a12160-f59b-4ad7-a683-ea4481ac23e9" name="procDivergent" guid="11110000-0000-0000-0000-000000000004">
  <Properties><Property><Name>Name</Name><Value>procDivergent</Value></Property><Property><Name>IsGeneratedObject</Name><Value>True</Value></Property></Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $procedureDir 'procDivergent.xml'), $procDivergentXml, $enc)

# --- PackagedModule conteiner: flag em <Object> ANINHADO; raiz autoral -> extracao deve dar 0 ---
$pkgContainerXml = @'
<Object type="c88fffcd-b6f8-0000-8fec-00b5497e2117" name="pkgContainer" guid="11110000-0000-0000-0000-000000000005">
  <Part type="ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc">
    <ExportFile><Objects>
      <Object type="c163e562-42c6-4158-ad83-5b21a14cf30e" name="NestedGen" guid="11110000-0000-0000-0000-000000000006">
        <Properties><Property><Name>Name</Name><Value>NestedGen</Value></Property><Property><Name>IsGeneratedObject</Name><Value>True</Value></Property><Property><Name>PatternObjectId</Name><Value>View</Value></Property><Property><Name>InstanceKey</Name><Value>xxxx-WorkWithWebNested</Value></Property></Properties>
      </Object>
    </Objects></ExportFile>
  </Part>
  <Properties><Property><Name>Name</Name><Value>pkgContainer</Value></Property><Property><Name>ModuleVersion</Name><Value>1.0</Value></Property></Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $packagedModuleDir 'pkgContainer.xml'), $pkgContainerXml, $enc)

# --- WebPanel gerado 2: MESMA instancia canonica de wpGenerated (agrupamento por instancia) ---
$wpGenerated2Xml = @'
<Object type="c9584656-94b6-4ccd-890f-332d11fc2c25" name="wpGenerated2" guid="11110000-0000-0000-0000-000000000007">
  <Properties><Property><Name>Name</Name><Value>wpGenerated2</Value></Property><Property><Name>IsGeneratedObject</Name><Value>True</Value></Property><Property><Name>InstanceKey</Name><Value>78cecefe-be7d-4980-86ce-8d6e91fba04b-WorkWithWebFoo</Value></Property><Property><Name>PatternObjectId</Name><Value>TabTabular</Value></Property></Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'wpGenerated2.xml'), $wpGenerated2Xml, $enc)

# --- WebPanel gerado com InstanceKey NAO-CANONICO (raiz): instance_name deve derivar para nulo ---
$wpOrfaXml = @'
<Object type="c9584656-94b6-4ccd-890f-332d11fc2c25" name="wpOrfa" guid="11110000-0000-0000-0000-000000000008">
  <Properties><Property><Name>Name</Name><Value>wpOrfa</Value></Property><Property><Name>IsGeneratedObject</Name><Value>True</Value></Property><Property><Name>InstanceKey</Name><Value>zzzz-WorkWithWebOrfa</Value></Property><Property><Name>PatternObjectId</Name><Value>Selection</Value></Property></Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'wpOrfa.xml'), $wpOrfaXml, $enc)

$sqlitePath = Join-Path $kbIntelDir 'kb-intelligence.sqlite'
$indexScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'

& $indexScript `
    -SourceRoot $objetosPath `
    -OutputPath $sqlitePath `
    -FailOnValidationFailure `
    -ParallelKbRoot $parallelRoot
if ($LASTEXITCODE -ne 0) {
    throw "Build-KbIntelligenceIndex falhou no self-test de objetos gerados; exit $LASTEXITCODE"
}

$queryScript = Join-Path $scriptDir 'Query-KbIntelligenceIndex.py'
$queryWrapper = Join-Path $scriptDir 'Query-KbIntelligenceIndex.ps1'

function Invoke-Query {
    param([string[]]$QueryArgs)
    $out = & python $queryScript --index-path $sqlitePath @QueryArgs --format json
    if ($LASTEXITCODE -ne 0) {
        throw "Query (.py) falhou (args: $($QueryArgs -join ' ')); exit $LASTEXITCODE"
    }
    return ($out | ConvertFrom-Json)
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FALHOU: $Message" }
}

function Get-ObjectInfo {
    param([string]$Type, [string]$Name)
    return Invoke-Query -QueryArgs @('--query', 'object-info', '--object-type', $Type, '--object-name', $Name)
}

# --- object-info: extracao escopada correta para cada caso ---
$gen = Get-ObjectInfo -Type 'WebPanel' -Name 'wpGenerated'
Assert-True ($gen.object.is_generated_object -eq 1) 'wpGenerated deveria ter is_generated_object=1'
Assert-True ($gen.object.pattern_object_id -eq 'TabGrid') 'wpGenerated deveria ter pattern_object_id=TabGrid'
Assert-True ($gen.object.instance_key -eq '78cecefe-be7d-4980-86ce-8d6e91fba04b-WorkWithWebFoo') 'wpGenerated instance_key incorreto'

$auth = Get-ObjectInfo -Type 'WebPanel' -Name 'wpAuthored'
Assert-True ($auth.object.is_generated_object -eq 0) 'wpAuthored deveria ter is_generated_object=0'
Assert-True ($null -eq $auth.object.pattern_object_id) 'wpAuthored deveria ter pattern_object_id nulo'
Assert-True ($null -eq $auth.object.instance_key) 'wpAuthored deveria ter instance_key nulo'

# FALLBACK: XML malformado -> ElementTree falha -> regex do ultimo <Properties> extrai do raiz
$mal = Get-ObjectInfo -Type 'WebPanel' -Name 'wpMalformed'
Assert-True ($mal.object.is_generated_object -eq 1) 'wpMalformed (fallback) deveria ter is_generated_object=1'
Assert-True ($mal.object.pattern_object_id -eq 'Selection') 'wpMalformed (fallback) deveria ter pattern_object_id=Selection'
Assert-True ($null -eq $mal.object.instance_key) 'wpMalformed deveria ter instance_key nulo'

# DIVERGENTE: flag sem companheiras
$div = Get-ObjectInfo -Type 'Procedure' -Name 'procDivergent'
Assert-True ($div.object.is_generated_object -eq 1) 'procDivergent deveria ter is_generated_object=1'
Assert-True ($null -eq $div.object.pattern_object_id) 'procDivergent deveria ter pattern_object_id nulo'
Assert-True ($null -eq $div.object.instance_key) 'procDivergent deveria ter instance_key nulo'

# CONTEINER (gap-guard): marcador aninhado NAO pode contaminar o raiz
$pkg = Get-ObjectInfo -Type 'PackagedModule' -Name 'pkgContainer'
Assert-True ($pkg.object.is_generated_object -eq 0) 'pkgContainer (raiz) deveria ter is_generated_object=0, nunca herdar do aninhado'
Assert-True ($null -eq $pkg.object.pattern_object_id) 'pkgContainer deveria ter pattern_object_id nulo'

# --- filtro --generated / --authored no motor .py (list-by-type WebPanel) ---
$genList = Invoke-Query -QueryArgs @('--query', 'list-by-type', '--object-type', 'WebPanel', '--generated')
$genNames = @($genList.results | ForEach-Object { $_.name })
Assert-True ($genNames -contains 'wpGenerated') 'filtro --generated deveria incluir wpGenerated'
Assert-True ($genNames -contains 'wpMalformed') 'filtro --generated deveria incluir wpMalformed'
Assert-True (-not ($genNames -contains 'wpAuthored')) 'filtro --generated NAO deveria incluir wpAuthored'

$authList = Invoke-Query -QueryArgs @('--query', 'list-by-type', '--object-type', 'WebPanel', '--authored')
$authNames = @($authList.results | ForEach-Object { $_.name })
Assert-True ($authNames -contains 'wpAuthored') 'filtro --authored deveria incluir wpAuthored'
Assert-True (-not ($authNames -contains 'wpGenerated')) 'filtro --authored NAO deveria incluir wpGenerated'

# --- filtro via WRAPPER .ps1 (processo filho) ---
$wrapperOut = & $queryWrapper -IndexPath $sqlitePath -Query 'list-by-type' -ObjectType 'WebPanel' -Generated -Format json
if ($LASTEXITCODE -ne 0) { throw "Wrapper .ps1 -Generated falhou; exit $LASTEXITCODE" }
$wrapperGen = ($wrapperOut | ConvertFrom-Json)
$wrapperNames = @($wrapperGen.results | ForEach-Object { $_.name })
Assert-True ($wrapperNames -contains 'wpGenerated') 'wrapper -Generated deveria incluir wpGenerated'
Assert-True (-not ($wrapperNames -contains 'wpAuthored')) 'wrapper -Generated NAO deveria incluir wpAuthored'

# --- modo texto: object-info mostra os 3 campos ---
$textOut = & python $queryScript --index-path $sqlitePath --query object-info --object-type WebPanel --object-name wpGenerated --format text
if ($LASTEXITCODE -ne 0) { throw "object-info --format text falhou; exit $LASTEXITCODE" }
$textJoined = ($textOut -join "`n")
Assert-True ($textJoined -match 'generated: 1') 'texto object-info deveria mostrar "generated: 1"'
Assert-True ($textJoined -match 'pattern_object_id: TabGrid') 'texto object-info deveria mostrar pattern_object_id: TabGrid'
Assert-True ($textJoined -match 'instance_key: 78cecefe') 'texto object-info deveria mostrar instance_key'

# --- metadata: contador e schema_version ---
$meta = Invoke-Query -QueryArgs @('--query', 'index-metadata')
Assert-True ($meta.metadata.schema_version -eq '4') "schema_version deveria ser 4, foi $($meta.metadata.schema_version)"
Assert-True ($meta.metadata.generated_objects_count -eq '5') "generated_objects_count deveria ser 5 (wpGenerated, wpMalformed, procDivergent, wpGenerated2, wpOrfa), foi $($meta.metadata.generated_objects_count)"

# ============================================================================
# Reverse lookup por instancia: instance_name derivado + filtro -InstanceKey
# ============================================================================

$fooKey = '78cecefe-be7d-4980-86ce-8d6e91fba04b-WorkWithWebFoo'
$fooKeyUpper = '78CECEFE-BE7D-4980-86CE-8D6E91FBA04B-WorkWithWebFoo'
$fooKeyLower = '78cecefe-be7d-4980-86ce-8d6e91fba04b-workwithwebfoo'

# instance_name derivado no object-info (canonico -> nome; autoral/nao-canonico -> nulo)
$gen1 = Get-ObjectInfo -Type 'WebPanel' -Name 'wpGenerated'
Assert-True ($gen1.object.instance_name -eq 'WorkWithWebFoo') 'wpGenerated deveria ter instance_name=WorkWithWebFoo'
$auth1 = Get-ObjectInfo -Type 'WebPanel' -Name 'wpAuthored'
Assert-True ($null -eq $auth1.object.instance_name) 'wpAuthored deveria ter instance_name nulo'
$orfa1 = Get-ObjectInfo -Type 'WebPanel' -Name 'wpOrfa'
Assert-True ($null -eq $orfa1.object.instance_name) 'wpOrfa (nao-canonico) deveria ter instance_name nulo'

function Get-SearchNames {
    param([string[]]$ExtraArgs)
    $r = Invoke-Query -QueryArgs (@('--query', 'search-objects') + $ExtraArgs)
    # ',@(...)' preserva o array no retorno (evita unwrap p/ $null quando vazio, sob StrictMode).
    return , @($r.results | ForEach-Object { $_.name })
}

# reverse lookup por NOME da instancia -> os 2 objetos da instancia (nao autorais nem outras)
$byName = Get-SearchNames -ExtraArgs @('--instance-key', 'WorkWithWebFoo')
Assert-True ($byName.Count -eq 2) "reverse lookup por nome deveria ter 2 resultados, teve $($byName.Count)"
Assert-True (($byName -contains 'wpGenerated') -and ($byName -contains 'wpGenerated2')) 'reverse lookup por nome deveria conter wpGenerated e wpGenerated2'
Assert-True (-not ($byName -contains 'wpOrfa')) 'reverse lookup por nome NAO deveria conter wpOrfa (instancia diferente)'

# reverse lookup por CHAVE COMPLETA canonica -> mesmos 2
$byKey = Get-SearchNames -ExtraArgs @('--instance-key', $fooKey)
Assert-True ($byKey.Count -eq 2) 'reverse lookup por chave completa deveria ter 2 resultados'

# chave completa com GUID MAIUSCULO -> mesmos 2 (ignora caixa)
$byKeyUpper = Get-SearchNames -ExtraArgs @('--instance-key', $fooKeyUpper)
Assert-True ($byKeyUpper.Count -eq 2) 'chave completa com GUID maiusculo deveria ter 2 resultados (ignora caixa)'

# chave completa MINUSCULA (GUID + nome minusculos) -> mesmos 2 (ignora caixa por chave)
$byKeyLower = Get-SearchNames -ExtraArgs @('--instance-key', $fooKeyLower)
Assert-True ($byKeyLower.Count -eq 2) 'chave completa minuscula deveria ter 2 resultados (ignora caixa por chave)'

# nome MINUSCULO -> mesmos 2 (ignora caixa por nome)
$byNameLower = Get-SearchNames -ExtraArgs @('--instance-key', 'workwithwebfoo')
Assert-True ($byNameLower.Count -eq 2) 'nome minusculo deveria dar os 2 (ignora caixa por nome)'

# prefixo parcial do nome -> zero (correspondencia exata, nunca parcial)
$byPartial = Get-SearchNames -ExtraArgs @('--instance-key', 'WorkWithWebFo')
Assert-True ($byPartial.Count -eq 0) 'prefixo parcial do nome deveria dar zero (exato, nao parcial)'

# composicao com --authored / --generated / --object-type
$byNameAuth = Get-SearchNames -ExtraArgs @('--instance-key', 'WorkWithWebFoo', '--authored')
Assert-True ($byNameAuth.Count -eq 0) 'instancia + --authored deveria dar zero'
$byNameGen = Get-SearchNames -ExtraArgs @('--instance-key', 'WorkWithWebFoo', '--generated')
Assert-True ($byNameGen.Count -eq 2) 'instancia + --generated deveria dar os 2'
$byNameType = Get-SearchNames -ExtraArgs @('--instance-key', 'WorkWithWebFoo', '--object-type', 'WebPanel')
Assert-True ($byNameType.Count -eq 2) 'instancia + --object-type WebPanel deveria dar os 2'

# JSON: instance_filter.mode e instance_name nos resultados
$byNameFull = Invoke-Query -QueryArgs @('--query', 'search-objects', '--instance-key', 'WorkWithWebFoo')
Assert-True ($byNameFull.instance_filter.mode -eq 'instance-name') 'instance_filter.mode deveria ser instance-name'
Assert-True (@($byNameFull.results | Where-Object { $_.instance_name -eq 'WorkWithWebFoo' }).Count -eq 2) 'resultados por nome deveriam trazer instance_name=WorkWithWebFoo'
$byKeyFull = Invoke-Query -QueryArgs @('--query', 'search-objects', '--instance-key', $fooKey)
Assert-True ($byKeyFull.instance_filter.mode -eq 'full-key') 'instance_filter.mode deveria ser full-key'

# nao-regressao: busca por nome de objeto (sem -InstanceKey) traz instance_name (nulo p/ autoral)
$byObjName = Invoke-Query -QueryArgs @('--query', 'search-objects', '--object-name', 'wpAuthored')
$authRow = @($byObjName.results | Where-Object { $_.name -eq 'wpAuthored' })[0]
Assert-True ($authRow.PSObject.Properties.Name -contains 'instance_name') 'resultado autoral deveria ter o campo instance_name'
Assert-True ($null -eq $authRow.instance_name) 'wpAuthored deveria ter instance_name nulo na busca por nome de objeto'

# via WRAPPER .ps1 (processo filho): -InstanceKey repassado
$wrapInst = & $queryWrapper -IndexPath $sqlitePath -Query 'search-objects' -InstanceKey 'WorkWithWebFoo' -Format json
if ($LASTEXITCODE -ne 0) { throw "wrapper .ps1 -InstanceKey falhou; exit $LASTEXITCODE" }
$wrapInstNames = @(($wrapInst | ConvertFrom-Json).results | ForEach-Object { $_.name })
Assert-True ($wrapInstNames.Count -eq 2) 'wrapper -InstanceKey WorkWithWebFoo deveria dar os 2'

# Erros esperados: obrigatoriedade, escopo, chave sem nome
function Assert-QueryFails {
    param([string[]]$QueryArgs, [string]$Message)
    $null = & python $queryScript --index-path $sqlitePath @QueryArgs --format json 2>&1
    if ($LASTEXITCODE -eq 0) { throw "ASSERT FALHOU (deveria falhar): $Message" }
}

Assert-QueryFails -QueryArgs @('--query', 'search-objects') -Message 'search-objects sem object-name e sem instance-key deveria falhar'
Assert-QueryFails -QueryArgs @('--query', 'list-by-type', '--object-type', 'WebPanel', '--instance-key', 'WorkWithWebFoo') -Message 'list-by-type com --instance-key deveria falhar (fora de escopo)'
Assert-QueryFails -QueryArgs @('--query', 'search-objects', '--instance-key', '78cecefe-be7d-4980-86ce-8d6e91fba04b-') -Message 'chave <GUID>- sem nome deveria falhar'
Assert-QueryFails -QueryArgs @('--query', 'who-uses', '--object-type', 'WebPanel', '--object-name', 'wpGenerated', '--instance-key', 'WorkWithWebFoo') -Message 'who-uses (semantica) com --instance-key deveria falhar (fora de escopo)'

Write-Output 'OK: Test-KbIntelligenceGeneratedObjectExtractionSelfTest.ps1'
exit 0
