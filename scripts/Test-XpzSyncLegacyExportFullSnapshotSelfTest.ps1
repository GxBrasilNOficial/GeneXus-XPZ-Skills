#requires -Version 7.4
<#
.SYNOPSIS
    Self-test ponta-a-ponta do ramo legado de Sync-GeneXusXpzToXml.ps1 (export GeneXus 9).

.DESCRIPTION
    Exercita a INTEGRACAO real (processo filho pwsh -File) do Sync sobre a fixture iso-8859-1
    gerada on-the-fly, cobrindo (spec congelada Fase 2 v2.8.5, secoes 4.1/6.3/6.4c):
    - -FullSnapshot legado NAO crasha sob StrictMode (o PR original quebrava com
      "property 'Guid' cannot be found"); LegacyFormatDetected=true, RenamedByGuid=0,
      MaterializationInterpretation='legacy-export-adapted';
    - releitura do disco: equivalent -> <Object type="<GUID real>">, orphan Report ->
      type="gxlegacy/Report" em pasta Report, guid="" e GxLegacyPayload presentes;
    - sentinela x data real -> skipped-older-lastUpdate (conservador);
    - pacote MISTO -> throw e kb-source-metadata.md NAO criado;
    - tag legada fora do registro + KbMetadataPath -> throw e kb-source-metadata.md
      NAO criado nem alterado (fail-closed antes da gravacao de metadata).
    Token de sucesso no stdout + exit 0.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptsRoot 'GeneXusLegacyExportFileFixtureSupport.ps1')

$syncScript = Join-Path $scriptsRoot 'Sync-GeneXusXpzToXml.ps1'

function New-WorkRoot {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('legacy-sync-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
    [void](New-Item -ItemType Directory -Path $root)
    return $root
}

function Write-Iso88591File {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::GetEncoding('iso-8859-1'))
}

function Invoke-SyncJson {
    <# Roda o Sync e devolve o objeto JSON do stdout (ultima linha nao-vazia). Lanca se exit != 0. #>
    param([string[]]$SyncArgs)
    $stdout = & pwsh -NoProfile -File $syncScript @SyncArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Sync retornou exit $LASTEXITCODE (esperado 0). Args: $($SyncArgs -join ' ')"
    }
    $line = @($stdout | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })[-1]
    return ($line | ConvertFrom-Json)
}

function Invoke-SyncExpectFailure {
    <# Roda o Sync e exige exit != 0 (fail-closed). #>
    param([string[]]$SyncArgs)
    & pwsh -NoProfile -File $syncScript @SyncArgs 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw "Sync deveria ter falhado (exit != 0), mas retornou 0. Args: $($SyncArgs -join ' ')"
    }
}

# =====================================================================================
# Caso 1 — -FullSnapshot legado nao crasha; releitura do disco (equivalent + orphan)
# =====================================================================================
$work1 = New-WorkRoot
try {
    $fixture = New-GeneXusLegacyExportFixtureFile -Path (Join-Path $work1 'legacy.xml')
    $dest = Join-Path $work1 'acervo'
    [void](New-Item -ItemType Directory -Path $dest)
    $meta = Join-Path $work1 'kb-source-metadata.md'

    $summary = Invoke-SyncJson -SyncArgs @('-InputPath', $fixture, '-DestinationRoot', $dest, '-FullSnapshot', '-KbMetadataPath', $meta)

    if (-not $summary.LegacyFormatDetected) { throw 'Caso1: LegacyFormatDetected deveria ser true.' }
    if ($summary.MaterializationInterpretation -ne 'legacy-export-adapted') { throw "Caso1: MaterializationInterpretation='$($summary.MaterializationInterpretation)' (esperado legacy-export-adapted)." }
    if ($summary.RenamedByGuid -ne 0) { throw "Caso1: RenamedByGuid=$($summary.RenamedByGuid) (esperado 0; guid='' nao participa de rename)." }
    if ($summary.Created -ne 7) { throw "Caso1: Created=$($summary.Created) (esperado 7)." }
    if ($summary.MissingAfterVerification -ne 0 -or $summary.MismatchesAfterVerification -ne 0) { throw 'Caso1: verificacao pos-materializacao falhou.' }
    if ($summary.FullSnapshotMissing -ne 0 -or $summary.FullSnapshotExtra -ne 0) { throw 'Caso1: full snapshot reportou missing/extra.' }

    # Releitura do disco: orphan Report -> pasta Report, type gxlegacy/Report
    $reportFile = Join-Path (Join-Path $dest 'Report') 'RelMov.xml'
    if (-not (Test-Path -LiteralPath $reportFile)) { throw "Caso1: orphan Report nao materializado em $reportFile." }
    [xml]$reportXml = Get-Content -LiteralPath $reportFile -Raw
    if ($reportXml.DocumentElement.LocalName -ne 'Object') { throw 'Caso1: raiz do orphan deveria ser <Object>.' }
    if ($reportXml.DocumentElement.GetAttribute('type') -ne 'gxlegacy/Report') { throw "Caso1: type do orphan='$($reportXml.DocumentElement.GetAttribute('type'))' (esperado gxlegacy/Report)." }
    if ($reportXml.DocumentElement.GetAttribute('guid') -ne '') { throw 'Caso1: guid do orphan deveria ser vazio.' }
    if ($null -eq $reportXml.DocumentElement.SelectSingleNode('./GxLegacyPayload')) { throw 'Caso1: GxLegacyPayload ausente no orphan.' }

    # Releitura do disco: equivalent Transaction -> GUID real (nao gxlegacy/*)
    $txFile = Join-Path (Join-Path $dest 'Transaction') 'Cliente.xml'
    if (-not (Test-Path -LiteralPath $txFile)) { throw "Caso1: equivalent Transaction nao materializado em $txFile." }
    [xml]$txXml = Get-Content -LiteralPath $txFile -Raw
    $txType = $txXml.DocumentElement.GetAttribute('type')
    if ([string]::IsNullOrWhiteSpace($txType) -or $txType -like 'gxlegacy/*') { throw "Caso1: type do equivalent='$txType' (esperado GUID real do catalogo)." }

    # Metadata gravado com Build vindo de MaxGxBuildSaved (2601) e sem bloco <Source> real
    if (-not (Test-Path -LiteralPath $meta)) { throw 'Caso1: kb-source-metadata.md deveria ter sido criado.' }
    $metaText = Get-Content -LiteralPath $meta -Raw
    if ($metaText -notmatch '(?m)^\|\s*Build\s*\|\s*2601\s*\|') { throw 'Caso1: Build=2601 (MaxGxBuildSaved) nao gravado no metadata.' }
} finally {
    if (Test-Path -LiteralPath $work1) { Remove-Item -LiteralPath $work1 -Recurse -Force }
}

# =====================================================================================
# Caso 2 — sentinela x data real -> skipped-older-lastUpdate
# =====================================================================================
$work2 = New-WorkRoot
try {
    $fixture = New-GeneXusLegacyExportFixtureFile -Path (Join-Path $work2 'legacy.xml')
    $dest = Join-Path $work2 'acervo'
    $procFolder = Join-Path $dest 'Procedure'
    [void](New-Item -ItemType Directory -Path $procFolder)

    # Pre-semeia Procedure/RelConfig.xml com lastUpdate REAL (a fixture traz RelConfig SEM
    # LastUpdate -> sentinela 0001-01-01, que e mais antiga -> deve ser skipped).
    $seed = @'
<?xml version="1.0" encoding="utf-8"?>
<Object type="gxlegacy/seed-irrelevante" name="RelConfig" guid="" lastUpdate="2020-06-01T00:00:00.0000000Z" dataSource="gx-legacy-export">
  <GxLegacyPayload>
    <Procedure><Info><Name>RelConfig</Name></Info></Procedure>
  </GxLegacyPayload>
</Object>
'@
    [System.IO.File]::WriteAllText((Join-Path $procFolder 'RelConfig.xml'), $seed, (New-Object System.Text.UTF8Encoding($false)))

    $summary = Invoke-SyncJson -SyncArgs @('-InputPath', $fixture, '-DestinationRoot', $dest)
    if ($summary.SkippedOlderLastUpdate -lt 1) { throw "Caso2: SkippedOlderLastUpdate=$($summary.SkippedOlderLastUpdate) (esperado >=1; sentinela < data real)." }
    if (@($summary.SkippedOlderLastUpdateNames) -notcontains 'Procedure:RelConfig') { throw "Caso2: Procedure:RelConfig deveria estar entre os skipped; obtido: $($summary.SkippedOlderLastUpdateNames -join ', ')." }
} finally {
    if (Test-Path -LiteralPath $work2) { Remove-Item -LiteralPath $work2 -Recurse -Force }
}

# =====================================================================================
# Caso 3 — pacote MISTO -> throw e kb-source-metadata.md NAO criado
# =====================================================================================
$work3 = New-WorkRoot
try {
    $mixed = Join-Path $work3 'misto.xml'
    Write-Iso88591File -Path $mixed -Content @'
<?xml version='1.0' encoding='iso-8859-1'?>
<ExportFile>
  <GXObject><Transaction><Info><Name>Cliente</Name></Info></Transaction></GXObject>
  <Objects><Object type="00000000-0000-0000-0000-000000000001" name="Moderno"/></Objects>
</ExportFile>
'@
    $dest = Join-Path $work3 'acervo'
    [void](New-Item -ItemType Directory -Path $dest)
    $meta = Join-Path $work3 'kb-source-metadata.md'

    Invoke-SyncExpectFailure -SyncArgs @('-InputPath', $mixed, '-DestinationRoot', $dest, '-KbMetadataPath', $meta)
    if (Test-Path -LiteralPath $meta) { throw 'Caso3: pacote misto NAO deveria criar kb-source-metadata.md.' }
} finally {
    if (Test-Path -LiteralPath $work3) { Remove-Item -LiteralPath $work3 -Recurse -Force }
}

# =====================================================================================
# Caso 4 — tag legada fora do registro + KbMetadataPath -> throw e metadata NAO alterado
# =====================================================================================
$work4 = New-WorkRoot
try {
    $unknown = Join-Path $work4 'unknown.xml'
    Write-Iso88591File -Path $unknown -Content @'
<?xml version='1.0' encoding='iso-8859-1'?>
<ExportFile>
  <KMW><MaxGxBuildSaved>2601</MaxGxBuildSaved></KMW>
  <GXObject><TagInexistente><Info><Name>NaoRegistrado</Name></Info></TagInexistente></GXObject>
</ExportFile>
'@
    $dest = Join-Path $work4 'acervo'
    [void](New-Item -ItemType Directory -Path $dest)

    # 4a — metadata ausente: nao deve ser criado
    $metaAbsent = Join-Path $work4 'kb-source-metadata.md'
    Invoke-SyncExpectFailure -SyncArgs @('-InputPath', $unknown, '-DestinationRoot', $dest, '-KbMetadataPath', $metaAbsent)
    if (Test-Path -LiteralPath $metaAbsent) { throw 'Caso4a: tag desconhecida NAO deveria criar kb-source-metadata.md.' }

    # 4b — metadata pre-existente: conteudo nao deve ser alterado (fail-closed antes da metadata)
    $metaPre = Join-Path $work4 'kb-source-metadata-pre.md'
    $sentinelContent = "SENTINELA-INTACTA-{0}" -f ([guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllText($metaPre, $sentinelContent, (New-Object System.Text.UTF8Encoding($false)))
    Invoke-SyncExpectFailure -SyncArgs @('-InputPath', $unknown, '-DestinationRoot', $dest, '-KbMetadataPath', $metaPre)
    if ((Get-Content -LiteralPath $metaPre -Raw) -ne $sentinelContent) { throw 'Caso4b: kb-source-metadata.md pre-existente foi alterado apesar do fail-closed.' }
} finally {
    if (Test-Path -LiteralPath $work4) { Remove-Item -LiteralPath $work4 -Recurse -Force }
}

Write-Output 'XPZ_SYNC_LEGACY_EXPORT_FULLSNAPSHOT_SELFTEST_OK'
exit 0
