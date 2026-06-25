#requires -Version 7.4
<#
.SYNOPSIS
    Self-test da deteccao de DIVERGENCIA DE ORIGEM (dataSource) cross-fluxo moderno<->legado
    em Sync-GeneXusXpzToXml.ps1 (entrada 999 «Colisao cross-fluxo…», doc-dono 01k).

.DESCRIPTION
    Exercita o motor por PROCESSO FILHO (pwsh -File), capturando stdout/stderr/exit separados.
    A fixture LEGADA (GeneXusLegacyExportFileSupport) e o incoming; o «outro fluxo» e simulado
    pre-plantando, no acervo ja materializado, um arquivo de envelope MODERNO (sem dataSource),
    LEGADO (com dataSource), com <GxLegacyPayload> (Decisao E.2) ou nao-parseavel. O caminho de
    deteccao e simetrico, entao a direcao legado-incoming exercita o mesmo codigo da moderno-incoming.

    Casos cobertos (numeracao do manuscrito congelado v16):
      1/2 deteccao por divergencia (existente moderno «» vs incoming legado «gx-legacy-export»);
      3   mesmo fluxo (existente legado) -> SEM colisao;
      6   -Block + -KbMetadataPath -> throw, metadata NAO criada, STDOUT sem Summary, STDERR com
          CROSSFLOW_COLLISION: e CROSSFLOW_BLOCKED_ERRORID:;
      7   -VerifyOnly sem -Block + colisao -> Summary.CrossFlowCollisions presente, nada gravado;
      9   existente NAO-PARSEAVEL (fail-soft) -> warning, sem crash, sem colisao;
      13  -Block + nao-parseavel -> NAO bloqueia (falha seguro);
      15  -VerifyOnly + -Block + colisao -> throw, nada gravado;
      17  Decisao E.2: existente sem dataSource mas com <GxLegacyPayload> + incoming legado ->
          classificado como legado -> SEM colisao (mesmo fluxo);
      Writes[].CrossFlowCollision por item; mitigacao stderr JSONL.

    Token de sucesso no stdout + exit 0: GENEXUS_XPZ_SYNC_CROSSFLOW_SELFTEST_OK
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsRoot = Split-Path -Parent $PSCommandPath
. (Join-Path $scriptsRoot 'GeneXusLegacyExportFileFixtureSupport.ps1')
$syncScript = Join-Path $scriptsRoot 'Sync-GeneXusXpzToXml.ps1'

function New-WorkRoot {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ('crossflow-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
    [void](New-Item -ItemType Directory -Path $root)
    return $root
}

function Invoke-Sync {
    <# Roda o Sync por processo filho; devolve { Stdout, Stderr, ExitCode, Summary }. Nunca lanca. #>
    param([string[]]$SyncArgs)
    $outFile = [System.IO.Path]::GetTempFileName()
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath 'pwsh' -ArgumentList (@('-NoProfile', '-File', $syncScript) + $SyncArgs) `
            -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $stdout = Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue
        $summary = $null
        if (-not [string]::IsNullOrWhiteSpace($stdout)) {
            $line = @($stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })[-1]
            if ($line) { try { $summary = $line | ConvertFrom-Json } catch { $summary = $null } }
        }
        return [pscustomobject]@{ Stdout = [string]$stdout; Stderr = [string]$stderr; ExitCode = $p.ExitCode; Summary = $summary }
    } finally {
        Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

function New-LegacyAcervo {
    <# Materializa a fixture legada num acervo fresco e devolve { Dest, ProcFile } (caminho do
       Procedure RelConfig materializado, usado para plantar o «outro fluxo»). #>
    param([string]$Work)
    $fixture = New-GeneXusLegacyExportFixtureFile -Path (Join-Path $Work 'legacy.xml')
    $dest = Join-Path $Work 'acervo'
    [void](New-Item -ItemType Directory -Path $dest)
    $report = Join-Path $Work 'report.json'
    $r = Invoke-Sync -SyncArgs @('-InputPath', $fixture, '-DestinationRoot', $dest, '-ReportPath', $report, '-KeepReport')
    if ($r.ExitCode -ne 0) { throw "Setup: sync legado inicial falhou (exit $($r.ExitCode)). Stderr: $($r.Stderr)" }
    $rep = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
    $proc = @($rep.Writes | Where-Object { $_.LogicalName -eq 'RelConfig' })[0]
    if (-not $proc) { throw 'Setup: nao achei o item RelConfig no acervo materializado.' }
    return [pscustomobject]@{ Fixture = $fixture; Dest = $dest; ProcFile = $proc.FilePath }
}

$failures = New-Object System.Collections.Generic.List[string]
function Assert($cond, $msg) { if (-not $cond) { $script:failures.Add($msg) | Out-Null } }

$modernEnvelope = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<Object type=`"x`" name=`"RelConfig`" guid=`"abc`" lastUpdate=`"2000-01-01T00:00:00.0000000Z`"><Body/></Object>"
$legacyEnvelope = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<Object type=`"x`" name=`"RelConfig`" guid=`"`" lastUpdate=`"2000-01-01T00:00:00.0000000Z`" dataSource=`"gx-legacy-export`"><GxLegacyPayload><Procedure/></GxLegacyPayload></Object>"
$payloadOnlyEnvelope = "<?xml version=`"1.0`" encoding=`"utf-8`"?>`n<Object name=`"RelConfig`" guid=`"`" lastUpdate=`"2000-01-01T00:00:00.0000000Z`"><GxLegacyPayload><Procedure/></GxLegacyPayload></Object>"

# =====================================================================================
# Caso 1/2 — existente MODERNO (sem dataSource) + incoming legado -> COLISAO (fail-soft)
# =====================================================================================
$w = New-WorkRoot
try {
    $a = New-LegacyAcervo -Work $w
    [System.IO.File]::WriteAllText($a.ProcFile, $modernEnvelope)
    $meta = Join-Path $w 'kb-source-metadata.md'
    $r = Invoke-Sync -SyncArgs @('-InputPath', $a.Fixture, '-DestinationRoot', $a.Dest, '-KbMetadataPath', $meta)
    Assert ($r.ExitCode -eq 0) "Caso1: exit=$($r.ExitCode) (esperado 0 fail-soft). Stderr: $($r.Stderr)"
    Assert ($null -ne $r.Summary) 'Caso1: Summary ausente no stdout.'
    $cf = @($r.Summary.CrossFlowCollisions)
    Assert ($cf.Count -eq 1) "Caso1: CrossFlowCollisions=$($cf.Count) (esperado 1)."
    Assert ($cf.Count -eq 1 -and $cf[0].NormalizedName -eq 'RelConfig') 'Caso1: colisao nao e RelConfig.'
    Assert ($cf.Count -eq 1 -and $cf[0].IncomingDataSource -eq 'gx-legacy-export' -and $cf[0].ExistingDataSource -eq '') 'Caso1: dataSource do par incorreto.'
    Assert ($r.Stderr -match 'CROSSFLOW_COLLISION:') 'Caso1: stderr sem CROSSFLOW_COLLISION:.'
    Assert (Test-Path -LiteralPath $meta) 'Caso1: metadata deveria ter sido gravada (fail-soft).'
} finally { Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue }

# =====================================================================================
# Caso 3 — existente LEGADO + incoming legado -> MESMO FLUXO, SEM colisao
# =====================================================================================
$w = New-WorkRoot
try {
    $a = New-LegacyAcervo -Work $w
    [System.IO.File]::WriteAllText($a.ProcFile, $legacyEnvelope)
    $r = Invoke-Sync -SyncArgs @('-InputPath', $a.Fixture, '-DestinationRoot', $a.Dest)
    Assert ($r.ExitCode -eq 0) "Caso3: exit=$($r.ExitCode)."
    Assert ($null -ne $r.Summary -and @($r.Summary.CrossFlowCollisions).Count -eq 0) 'Caso3: deveria ser SEM colisao (mesmo fluxo).'
} finally { Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue }

# =====================================================================================
# Caso 17 — Decisao E.2: existente sem dataSource mas com <GxLegacyPayload> -> legado -> SEM colisao
# =====================================================================================
$w = New-WorkRoot
try {
    $a = New-LegacyAcervo -Work $w
    [System.IO.File]::WriteAllText($a.ProcFile, $payloadOnlyEnvelope)
    $r = Invoke-Sync -SyncArgs @('-InputPath', $a.Fixture, '-DestinationRoot', $a.Dest)
    Assert ($r.ExitCode -eq 0) "Caso17: exit=$($r.ExitCode)."
    Assert ($null -ne $r.Summary -and @($r.Summary.CrossFlowCollisions).Count -eq 0) 'Caso17: E.2 deveria classificar existente como legado (SEM colisao).'
} finally { Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue }

# =====================================================================================
# Caso 6 — -Block + -KbMetadataPath + colisao -> throw, metadata NAO criada, stderr com ErrorId
# =====================================================================================
$w = New-WorkRoot
try {
    $a = New-LegacyAcervo -Work $w
    [System.IO.File]::WriteAllText($a.ProcFile, $modernEnvelope)
    $metaB = Join-Path $w 'kb-block.md'   # nao existe ainda
    $r = Invoke-Sync -SyncArgs @('-InputPath', $a.Fixture, '-DestinationRoot', $a.Dest, '-KbMetadataPath', $metaB, '-BlockCrossFlowDataSource')
    Assert ($r.ExitCode -ne 0) "Caso6: exit=$($r.ExitCode) (esperado !=0 sob -Block)."
    Assert (-not (Test-Path -LiteralPath $metaB)) 'Caso6: metadata NAO deveria ter sido criada (atomicidade pre-metadata).'
    Assert ($r.Stderr -match 'CROSSFLOW_BLOCKED_ERRORID: CrossFlowDataSourceCollisionBlocked') 'Caso6: stderr sem CROSSFLOW_BLOCKED_ERRORID.'
    Assert ($r.Stderr -match 'CROSSFLOW_COLLISION:') 'Caso6: stderr sem CROSSFLOW_COLLISION:.'
    Assert ($null -eq $r.Summary) 'Caso6: STDOUT nao deveria conter Summary (throw antes da emissao).'
} finally { Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue }

# =====================================================================================
# Caso 7 — -VerifyOnly sem -Block + colisao -> Summary.CrossFlowCollisions presente, nada gravado
# =====================================================================================
$w = New-WorkRoot
try {
    $a = New-LegacyAcervo -Work $w
    [System.IO.File]::WriteAllText($a.ProcFile, $modernEnvelope)
    $before = (Get-Content -LiteralPath $a.ProcFile -Raw)
    $r = Invoke-Sync -SyncArgs @('-InputPath', $a.Fixture, '-DestinationRoot', $a.Dest, '-VerifyOnly')
    Assert ($r.ExitCode -eq 0) "Caso7: exit=$($r.ExitCode)."
    Assert ($null -ne $r.Summary -and @($r.Summary.CrossFlowCollisions).Count -eq 1) 'Caso7: CrossFlowCollisions deveria estar presente em -VerifyOnly.'
    Assert ((Get-Content -LiteralPath $a.ProcFile -Raw) -eq $before) 'Caso7: -VerifyOnly nao deveria ter sobrescrito o arquivo.'
} finally { Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue }

# =====================================================================================
# Caso 15 — -VerifyOnly + -Block + colisao -> throw, nada gravado
# =====================================================================================
$w = New-WorkRoot
try {
    $a = New-LegacyAcervo -Work $w
    [System.IO.File]::WriteAllText($a.ProcFile, $modernEnvelope)
    $before = (Get-Content -LiteralPath $a.ProcFile -Raw)
    $r = Invoke-Sync -SyncArgs @('-InputPath', $a.Fixture, '-DestinationRoot', $a.Dest, '-VerifyOnly', '-BlockCrossFlowDataSource')
    Assert ($r.ExitCode -ne 0) "Caso15: exit=$($r.ExitCode) (esperado !=0)."
    Assert ($r.Stderr -match 'CROSSFLOW_BLOCKED_ERRORID') 'Caso15: stderr sem ErrorId.'
    Assert ((Get-Content -LiteralPath $a.ProcFile -Raw) -eq $before) 'Caso15: nada deveria ter sido gravado.'
} finally { Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue }

# =====================================================================================
# Caso 9/13 — existente NAO-PARSEAVEL: contrato da DETECCAO (Decisao G), o que esta frente possui.
# Asserido pelos MARCADORES de stderr da deteccao (warning emitido, sem colisao, sem bloqueio),
# NAO pelo exit code: um arquivo-lixo no acervo crasha estagios DOWNSTREAM pre-existentes
# (Get-LastUpdateInfoFromFile / Test-PackageMaterialization), independentemente desta frente.
# A deteccao roda e emite seus marcadores ANTES desse crash downstream.
# =====================================================================================
$w = New-WorkRoot
try {
    $a = New-LegacyAcervo -Work $w
    [System.IO.File]::WriteAllText($a.ProcFile, "isto nao e XML <<< {{{ ")
    # fail-soft: a deteccao trata o nao-parseavel como warning, sem colisao
    $r = Invoke-Sync -SyncArgs @('-InputPath', $a.Fixture, '-DestinationRoot', $a.Dest)
    Assert ($r.Stderr -match 'CROSSFLOW_WARNING:') 'Caso9: deteccao deveria emitir CROSSFLOW_WARNING para nao-parseavel.'
    Assert (-not ($r.Stderr -match 'CROSSFLOW_COLLISION:')) 'Caso9: nao-parseavel NAO deve gerar colisao.'
    # -Block: a deteccao NAO bloqueia em nao-parseavel (falha seguro): sem ErrorId de bloqueio
    $a2obj = New-LegacyAcervo -Work (New-WorkRoot)
    [System.IO.File]::WriteAllText($a2obj.ProcFile, "tambem nao e XML }}}")
    $r2 = Invoke-Sync -SyncArgs @('-InputPath', $a2obj.Fixture, '-DestinationRoot', $a2obj.Dest, '-BlockCrossFlowDataSource')
    Assert (-not ($r2.Stderr -match 'CROSSFLOW_BLOCKED_ERRORID')) 'Caso13: -Block NAO deveria disparar bloqueio em nao-parseavel (falha seguro).'
} finally { Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue }

# =====================================================================================
# Writes[].CrossFlowCollision por item (via -ReportPath) — exatamente o item colidente marcado
# =====================================================================================
$w = New-WorkRoot
try {
    $a = New-LegacyAcervo -Work $w
    [System.IO.File]::WriteAllText($a.ProcFile, $modernEnvelope)
    $rep2 = Join-Path $w 'rep2.json'
    $r = Invoke-Sync -SyncArgs @('-InputPath', $a.Fixture, '-DestinationRoot', $a.Dest, '-ReportPath', $rep2, '-KeepReport')
    Assert ($r.ExitCode -eq 0) "WritesFlag: exit=$($r.ExitCode)."
    $rep = Get-Content -LiteralPath $rep2 -Raw | ConvertFrom-Json
    $flagged = @($rep.Writes | Where-Object { $_.CrossFlowCollision })
    Assert ($flagged.Count -eq 1 -and $flagged[0].LogicalName -eq 'RelConfig') "WritesFlag: esperado 1 item marcado (RelConfig), veio $($flagged.Count)."
} finally { Remove-Item -LiteralPath $w -Recurse -Force -ErrorAction SilentlyContinue }

if ($failures.Count -gt 0) {
    Write-Host "FALHAS ($($failures.Count)):"
    $failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}
Write-Output 'GENEXUS_XPZ_SYNC_CROSSFLOW_SELFTEST_OK'
exit 0
