#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do motor de export legado GeneXus 9 (GeneXusLegacyExportFileSupport.ps1), isolado.

.DESCRIPTION
    Exercita o parser/conversor sobre a fixture iso-8859-1 (gerada on-the-fly em Temp por
    GeneXusLegacyExportFileFixtureSupport.ps1; nao versionada — Opcao B) e casos
    inline: deteccao de perfil; leitura encoding-aware via .xml e .xpz (acento Latin-1
    preservado, nao transliterado); equivalent->GUID real / orphan->gxlegacy/<Tag>; sentinela;
    guid=''/dataSource/GxLegacyPayload; atributos; XPath-nao-vaza (nos aninhados em payload nao
    contaminam deteccao nem materializacao); fail-closed misto / tag desconhecida / >1 filho /
    colisao; contrato de inventario known-legacy; delta declarado orphan registry-aware.
    Token de sucesso no stdout + exit 0.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptsRoot 'GeneXusObjectTypeCatalogSupport.ps1')
. (Join-Path $scriptsRoot 'GeneXusLegacyExportFileSupport.ps1')
. (Join-Path $scriptsRoot 'GeneXusLegacyExportFileFixtureSupport.ps1')

# A fixture iso-8859-1 e gerada em Temp on-the-fly (nao versionada; evita transcodificacao por editor/git).
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('legacy-fixture-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $fixtureRoot)
$fixturePath = New-GeneXusLegacyExportFixtureFile -Path (Join-Path $fixtureRoot 'legacy-exportfile-minimal.xml')

function Get-EncodingAwareXmlFromFile {
    param([string]$Path)
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($Path)   # respeita o prologo iso-8859-1
    return $doc
}

function Get-EncodingAwareXmlFromXpz {
    param([string]$XpzPath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($XpzPath)
    try {
        $entry = @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' })[0]
        $doc = New-Object System.Xml.XmlDocument
        $doc.PreserveWhitespace = $true
        $stream = $entry.Open()
        try { $doc.Load($stream) } finally { $stream.Dispose() }   # Load($entry.Open()) respeita o prologo
        return $doc
    } finally {
        $zip.Dispose()
    }
}

$resolution = Resolve-GeneXusObjectTypeCatalogPaths -BaseCatalogPath (Join-Path $scriptsRoot 'gx-object-type-catalog.json')
$merged = $resolution.MergedCatalog
$registry = Get-GeneXusLegacyExportElementRegistry

# --- Leitura encoding-aware via .xml: acento Latin-1 preservado ---
[xml]$fixtureXml = Get-EncodingAwareXmlFromFile -Path $fixturePath
$wpDesc = $fixtureXml.SelectSingleNode('/ExportFile/GXObject/WorkPanel/Info/Description').InnerText
if ($wpDesc -ne 'Cadastro de Parâmetros') { throw "Acento (.xml) nao preservado; obtido '$wpDesc'." }

# --- Leitura encoding-aware via .xpz: mesmo acento preservado ---
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('legacy-support-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot)
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $xpzPath = Join-Path $tempRoot 'fixture.xpz'
    $zipW = [System.IO.Compression.ZipFile]::Open($xpzPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try { [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipW, $fixturePath, 'FinSample_1.xml') } finally { $zipW.Dispose() }
    [xml]$fromXpz = Get-EncodingAwareXmlFromXpz -XpzPath $xpzPath
    $wpDescXpz = $fromXpz.SelectSingleNode('/ExportFile/GXObject/WorkPanel/Info/Description').InnerText
    if ($wpDescXpz -ne 'Cadastro de Parâmetros') { throw "Acento (.xpz) nao preservado; obtido '$wpDescXpz'." }
} finally {
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

# --- Deteccao de perfil: legado-puro apesar de <Objects>/<Attribute> aninhados em payload ---
if (-not (Test-GeneXusLegacyExportFilePackage -XmlDocument $fixtureXml)) { throw 'Fixture deveria ser legado-puro (XPath-nao-vaza).' }
if (Test-GeneXusMixedExportFilePackage -XmlDocument $fixtureXml) { throw 'Fixture nao deveria ser misto (nos aninhados vazaram).' }

# --- Conversao ---
$items = (Get-GeneXusLegacyExportFileSyncItems -XmlDocument $fixtureXml -MergedCatalog $merged -Registry $registry).Items
if (@($items).Count -ne 7) { throw "Esperado 7 itens (5 objetos + 2 atributos), obtido $(@($items).Count)." }

# XPath-nao-vaza: nenhum item materializado do <Object name='NaoDeveVazar'> aninhado
if (@($items | Where-Object { $_.LogicalName -eq 'NaoDeveVazar' }).Count -ne 0) { throw 'Objeto aninhado em payload vazou para os itens.' }

$byElem = @{}
foreach ($it in $items) {
    if ($it.Guid -ne '') { throw "guid deveria ser vazio em '$($it.LogicalName)'." }
    if ($it.Node.GetAttribute('dataSource') -ne 'gx-legacy-export') { throw "dataSource ausente em '$($it.LogicalName)'." }
    if ($null -eq $it.Node.SelectSingleNode('./GxLegacyPayload')) { throw "GxLegacyPayload ausente em '$($it.LogicalName)'." }
    if (-not $byElem.ContainsKey($it.LegacyElement)) { $byElem[$it.LegacyElement] = New-Object System.Collections.Generic.List[object] }
    $byElem[$it.LegacyElement].Add($it)
}

# equivalent -> GUID real do catalogo (WorkPanel) e folder correto
$wp = $byElem['WorkPanel'][0]
if ($wp.FolderType -ne 'WorkPanel') { throw "WorkPanel folder errado: $($wp.FolderType)." }
if ($wp.TypeGuid -notmatch '^[0-9a-fA-F-]{36}$') { throw "WorkPanel deveria ter GUID real; obtido '$($wp.TypeGuid)'." }
$tx = $byElem['Transaction'][0]
if ($tx.FolderType -ne 'Transaction' -or $tx.TypeGuid -notmatch '^[0-9a-fA-F-]{36}$') { throw 'Transaction equivalent falhou.' }

# objeto sem LastUpdate (Procedure RelConfig) -> sentinela
$proc = $byElem['Procedure'][0]
if ($proc.Node.GetAttribute('lastUpdate') -ne '0001-01-01T00:00:00.0000000Z') { throw "Sentinela esperada no Procedure sem LastUpdate; obtido '$($proc.Node.GetAttribute('lastUpdate'))'." }

# orphan -> gxlegacy/<Tag> em pasta propria
$rep = $byElem['Report'][0]
if ($rep.TypeGuid -ne 'gxlegacy/Report' -or $rep.FolderType -ne 'Report') { throw "Report orphan falhou (type=$($rep.TypeGuid), folder=$($rep.FolderType))." }
$menu = $byElem['Menubar'][0]
if ($menu.TypeGuid -ne 'gxlegacy/Menubar' -or $menu.FolderType -ne 'Menubar') { throw "Menubar orphan falhou (type=$($menu.TypeGuid), folder=$($menu.FolderType))." }

# acento Latin-1 preservado (nao transliterado) no payload materializado
if ($tx.Node.OuterXml -notmatch 'Configuração de clientes') { throw 'Acento nao preservado no payload da Transaction.' }

# atributos: 2 GXAtt, com acento no Title preservado
$atts = @($items | Where-Object { $_.RootTag -eq 'Attribute' })
if ($atts.Count -ne 2) { throw "Esperado 2 atributos GXAtt, obtido $($atts.Count)." }
$end = @($atts | Where-Object { $_.LogicalName -eq 'Endereco' })[0]
if ($end.Node.OuterXml -notmatch 'Endereço de cobrança') { throw 'Acento nao preservado no Title do atributo.' }

# --- Inventario: contrato known-legacy ---
$inv = Get-GeneXusLegacyExportFileInventoryItems -XmlDocument $fixtureXml -MergedCatalog $merged -Registry $registry
if ($inv.TotalCount -ne 7) { throw "Inventario esperado 7, obtido $($inv.TotalCount)." }
foreach ($iv in $inv.Items) {
    if ($iv.typeStatus -ne 'known-legacy') { throw 'typeStatus deveria ser known-legacy.' }
    if ([string]::IsNullOrWhiteSpace($iv.typeName)) { throw 'typeName nao-nulo exigido.' }
    if ($iv.rootKind -ne 'Object' -and $iv.rootKind -ne 'Attribute') { throw "rootKind sintetico invalido: $($iv.rootKind)." }
    if ($iv.sourceBlock -ne 'Objects' -and $iv.sourceBlock -ne 'Attributes') { throw "sourceBlock invalido: $($iv.sourceBlock)." }
}
$invRep = @($inv.Items | Where-Object { $_.legacyElement -eq 'Report' })[0]
if ($invRep.typeName -ne 'gxlegacy/Report' -or $invRep.rootKind -ne 'Object') { throw 'Inventario Report orphan falhou.' }

# --- Delta declarado orphan registry-aware (todo orphan) ---
if ((Convert-LegacyDeclaredDeltaKeyToCanonical -DeclaredKey 'Report:RelMov' -Registry $registry) -ne 'gxlegacy/Report:RelMov') { throw 'Delta orphan Report falhou.' }
if ((Convert-LegacyDeclaredDeltaKeyToCanonical -DeclaredKey 'gxlegacy/Report:RelMov' -Registry $registry) -ne 'gxlegacy/Report:RelMov') { throw 'Delta orphan Report (forma canonica) falhou.' }
if ((Convert-LegacyDeclaredDeltaKeyToCanonical -DeclaredKey 'Menubar:MenuPrincipal' -Registry $registry) -ne 'gxlegacy/Menubar:MenuPrincipal') { throw 'Delta orphan Menubar falhou.' }
if ((Convert-LegacyDeclaredDeltaKeyToCanonical -DeclaredKey 'Transaction:Cliente' -Registry $registry) -ne 'Transaction:Cliente') { throw 'Delta equivalent nao deveria ser normalizado.' }

# --- Fail-closed: misto ---
$mixed = [xml]'<ExportFile><GXObject><Transaction><Info><Name>X</Name></Info></Transaction></GXObject><Objects><Object type="x" name="Y"/></Objects></ExportFile>'
if (-not (Test-GeneXusMixedExportFilePackage -XmlDocument $mixed)) { throw 'Misto (Objects/Object) deveria ser detectado.' }
$mixedAtt = [xml]'<ExportFile><GXObject><Transaction><Info><Name>X</Name></Info></Transaction></GXObject><Attributes><Attribute name="Z"/></Attributes></ExportFile>'
if (-not (Test-GeneXusMixedExportFilePackage -XmlDocument $mixedAtt)) { throw 'Misto (Attributes/Attribute moderno) deveria ser detectado.' }
if (Test-GeneXusLegacyExportFilePackage -XmlDocument $mixedAtt) { throw 'Misto nao deveria classificar como legado-puro.' }

# --- Fail-closed: tag desconhecida ---
$unknown = [xml]'<ExportFile><GXObject><FooBar><Info><Name>Z</Name></Info></FooBar></GXObject></ExportFile>'
$threw = $false
try { [void](Get-GeneXusLegacyExportFileSyncItems -XmlDocument $unknown -MergedCatalog $merged -Registry $registry) } catch { $threw = $true }
if (-not $threw) { throw 'Tag desconhecida deveria dar fail-closed.' }

# --- Fail-closed: >1 elemento-filho por GXObject ---
$twoChild = [xml]'<ExportFile><GXObject><Transaction><Info><Name>A</Name></Info></Transaction><Report><Info><Name>B</Name></Info></Report></GXObject></ExportFile>'
$threw = $false
try { [void](Get-GeneXusLegacyExportFileSyncItems -XmlDocument $twoChild -MergedCatalog $merged -Registry $registry) } catch { $threw = $true }
if (-not $threw) { throw '>1 elemento-filho por GXObject deveria dar fail-closed.' }

# --- Fail-closed: colisao de nome (mesmo FolderType|NormalizedName, nomes logicos distintos) ---
# 'A:b' (':' invalido -> '_') e 'A_b' normalizam ambos para 'A_b' (nomes logicos distintos) => colisao.
$collision = [xml]'<ExportFile><GXObject><Transaction><Info><Name>A:b</Name></Info></Transaction></GXObject><GXObject><Transaction><Info><Name>A_b</Name></Info></Transaction></GXObject></ExportFile>'
$threw = $false
try { [void](Get-GeneXusLegacyExportFileSyncItems -XmlDocument $collision -MergedCatalog $merged -Registry $registry) } catch { $threw = $true }
if (-not $threw) { throw 'Colisao de nome normalizado deveria dar fail-closed.' }

if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }

Write-Output 'GENEXUS_LEGACY_EXPORT_FILE_SUPPORT_SELFTEST_OK'
exit 0
