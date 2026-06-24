#requires -Version 7.4
<#
.SYNOPSIS
    Self-test: o indexador KbIntelligence e registry-aware para elementos legados orfaos.

.DESCRIPTION
    Monta uma KB sintetica com (a) uma pasta de tipo moderno do catalogo (WebPanel, 1 XML) e
    (b) uma pasta de elemento legado orfao do registro (Report, 1 XML com
    <Object type="gxlegacy/Report">). Builda o indice com -FailOnValidationFailure e prova que:
      - o build COMPLETA (exit 0); antes do fix, o type "gxlegacy/Report" caía em unknown_guids e
        disparava raise SystemExit em collect_all_objects, e a pasta "Report" (fora de
        GX_TYPE_CATALOG_BY_NAME) viraria unknown_type_folder -> status BLOCK;
      - inventory_semantics.status == OK e mismatch_count == 0;
      - a pasta orfa NAO entra em snapshot_objects_by_directory (evita directory_inventory_mismatch);
      - o skip fica AUDITAVEL em legacy_orphan_directories_skipped (nome + contagem), para que OK nao
        esconda XMLs orfaos fisicamente presentes;
      - a pasta de tipo moderno continua indexada normalmente.
    A lista de pastas orfas vem do registro gx-legacy-export-element-registry.json (dinamico), nao inline.
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

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FALHOU: $Message" }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-legacy-orphan-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRoot = Join-Path $tempRoot 'KbParalela'
$objetosPath = Join-Path $parallelRoot 'ObjetosDaKbEmXml'
$webPanelDir = Join-Path $objetosPath 'WebPanel'
$reportDir = Join-Path $objetosPath 'Report'
$kbIntelDir = Join-Path $parallelRoot 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $webPanelDir, $reportDir, $kbIntelDir -Force)

# --- Tipo moderno do catalogo: WebPanel (GUID real), deve ser indexado normalmente. ---
$webPanelXml = @'
<Object type="c9584656-94b6-4ccd-890f-332d11fc2c25" name="wpProof" guid="44444444-0000-0000-0000-000000000001">
  <Properties>
    <Property><Name>Name</Name><Value>wpProof</Value></Property>
  </Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $webPanelDir 'wpProof.xml'), $webPanelXml, $enc)

# --- Elemento legado orfao: Report, materializado com @type = typeToken gxlegacy/Report. ---
# Antes do fix isto quebrava o build (unknown_guids -> SystemExit; pasta Report -> unknown_type_folder -> BLOCK).
$reportOrphanXml = @'
<Object type="gxlegacy/Report" name="rptProof" lastUpdate="0001-01-01T00:00:00.0000000Z" dataSource="gx-legacy-export">
  <GxLegacyPayload>
    <Report><Info><Name>rptProof</Name></Info></Report>
  </GxLegacyPayload>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $reportDir 'rptProof.xml'), $reportOrphanXml, $enc)

$sqlitePath = Join-Path $kbIntelDir 'kb-intelligence.sqlite'
$validationPath = Join-Path $kbIntelDir 'kb-intelligence-validation.json'
$indexScript = Join-Path $scriptDir 'Build-KbIntelligenceIndex.ps1'

& $indexScript `
    -SourceRoot $objetosPath `
    -OutputPath $sqlitePath `
    -ValidationReportPath $validationPath `
    -FailOnValidationFailure `
    -ParallelKbRoot $parallelRoot
Assert-True ($LASTEXITCODE -eq 0) "Build-KbIntelligenceIndex deveria completar (exit 0) com pasta orfa legada presente; exit $LASTEXITCODE"

$report = Get-Content -LiteralPath $validationPath -Raw -Encoding UTF8 | ConvertFrom-Json
$inv = $report.inventory_semantics

Assert-True ($inv.status -eq 'OK') "inventory_semantics.status deveria ser OK, foi $($inv.status)"
Assert-True ($inv.mismatch_count -eq 0) "mismatch_count deveria ser 0, foi $($inv.mismatch_count)"

# Pasta orfa auditada no diagnostico (nome + contagem).
$skipped = @($inv.legacy_orphan_directories_skipped)
$reportSkip = @($skipped | Where-Object { $_.directory -eq 'Report' })
Assert-True ($reportSkip.Count -eq 1) "Report deveria aparecer 1x em legacy_orphan_directories_skipped, apareceu $($reportSkip.Count)"
Assert-True ($reportSkip[0].xml_count -eq 1) "Report deveria registrar xml_count=1 no skip, registrou $($reportSkip[0].xml_count)"

# Pasta orfa NAO entra no snapshot (evita directory_inventory_mismatch); tipo moderno continua no snapshot.
$snapNames = @($inv.snapshot_objects_by_directory.PSObject.Properties.Name)
Assert-True (-not ($snapNames -contains 'Report')) 'A pasta orfa Report NAO deveria entrar em snapshot_objects_by_directory'
Assert-True ($snapNames -contains 'WebPanel') 'A pasta de tipo moderno WebPanel deveria estar em snapshot_objects_by_directory'

# Tipo moderno indexado normalmente.
$indexedNames = @($inv.indexed_objects_by_type.PSObject.Properties.Name)
Assert-True ($indexedNames -contains 'WebPanel') 'WebPanel deveria estar indexado em indexed_objects_by_type'

# --- Cenario B: skip content-aware (pasta mal-nomeada NAO mascarada) ---
# Uma pasta chamada 'Report' (nome de orfao do registro) MAS com conteudo MODERNO (WebPanel, GUID real)
# NAO deve ser pulada em silencio: o skip e content-aware (folder_is_all_legacy_orphan), entao ela segue
# ao caminho normal e e flagrada (status BLOCK), em vez de virar legacy_orphan_directories_skipped.
$tempRootB = Join-Path ([System.IO.Path]::GetTempPath()) ('kb-intel-legacy-orphan-misnamed-{0}' -f ([guid]::NewGuid().ToString('N')))
$parallelRootB = Join-Path $tempRootB 'KbParalela'
$objetosPathB = Join-Path $parallelRootB 'ObjetosDaKbEmXml'
$misnamedReportDir = Join-Path $objetosPathB 'Report'
$kbIntelDirB = Join-Path $parallelRootB 'KbIntelligence'
[void](New-Item -ItemType Directory -Path $misnamedReportDir, $kbIntelDirB -Force)

$misnamedXml = @'
<Object type="c9584656-94b6-4ccd-890f-332d11fc2c25" name="wpMisnamed" guid="55555555-0000-0000-0000-000000000001">
  <Properties>
    <Property><Name>Name</Name><Value>wpMisnamed</Value></Property>
  </Properties>
</Object>
'@
[System.IO.File]::WriteAllText((Join-Path $misnamedReportDir 'wpMisnamed.xml'), $misnamedXml, $enc)

$sqlitePathB = Join-Path $kbIntelDirB 'kb-intelligence.sqlite'
$validationPathB = Join-Path $kbIntelDirB 'kb-intelligence-validation.json'

# Sem -FailOnValidationFailure: queremos ler o report mesmo com BLOCK.
& $indexScript `
    -SourceRoot $objetosPathB `
    -OutputPath $sqlitePathB `
    -ValidationReportPath $validationPathB `
    -ParallelKbRoot $parallelRootB | Out-Null

$reportB = Get-Content -LiteralPath $validationPathB -Raw -Encoding UTF8 | ConvertFrom-Json
$invB = $reportB.inventory_semantics

$skippedB = @($invB.legacy_orphan_directories_skipped)
$reportSkipB = @($skippedB | Where-Object { $_.directory -eq 'Report' })
Assert-True ($reportSkipB.Count -eq 0) "Pasta 'Report' com conteudo MODERNO NAO deveria ser pulada como orfao (skip mascararia diretorio mal-nomeado)"
Assert-True ($invB.status -eq 'BLOCK') "Pasta 'Report' mal-nomeada (conteudo moderno) deveria gerar status BLOCK, foi $($invB.status)"

Write-Output 'OK: Test-KbIntelligenceLegacyOrphanSkipSelfTest.ps1'
exit 0
