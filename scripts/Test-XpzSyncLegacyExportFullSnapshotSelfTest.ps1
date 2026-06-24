#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de Sync-GeneXusXpzToXml.ps1 com export legado sob -FullSnapshot.

.DESCRIPTION
    Cobre o caminho ponta a ponta do sync para pacotes ExportFile legados
    (GXObject/GXAtt) quando DestinationRoot ja existe e -FullSnapshot aciona
    Resolve-GuidAwareRenames. Exports legados nao tem GUID de identidade estavel,
    portanto nao devem participar de rename por GUID.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Sync-GeneXusXpzToXml.ps1'
$fixturePath = Join-Path $PSScriptRoot 'test-fixtures\legacy-exportfile-minimal.xml'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-sync-legacy-fullsnapshot-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

function New-CaseDir {
    param([string]$Name)

    $acervo = Join-Path (Join-Path $tempRoot $Name) 'ObjetosDaKbEmXml'
    [void](New-Item -ItemType Directory -Path $acervo -Force)
    return [pscustomobject]@{ Root = (Join-Path $tempRoot $Name); Acervo = $acervo }
}

function Invoke-LegacySync {
    param(
        [string]$Acervo,
        [switch]$VerifyOnly,
        [string]$ReportPath
    )

    $psArgs = @(
        '-NoProfile',
        '-File', $scriptPath,
        '-InputPath', $fixturePath,
        '-DestinationRoot', $Acervo,
        '-FullSnapshot'
    )
    if ($VerifyOnly) { $psArgs += '-VerifyOnly' }
    if ($ReportPath) { $psArgs += @('-ReportPath', $ReportPath, '-KeepReport') }

    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $stdout = & pwsh @psArgs 2>$errFile
        $exit = $LASTEXITCODE
        $stderr = Get-Content -LiteralPath $errFile -Raw
    } finally {
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }

    return [pscustomobject]@{
        ExitCode = $exit
        StdOut   = ($stdout | Out-String)
        StdErr   = $stderr
        Output   = (($stdout | Out-String) + [Environment]::NewLine + $stderr)
    }
}

function Assert-StdoutIsPureJson {
    param([string]$Case, [object]$Result)

    $raw = $Result.StdOut.Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "${Case}: stdout deveria conter JSON do resumo." }
    if ($raw -match "`n") { throw "${Case}: stdout deveria ser uma unica linha JSON; contem quebras. StdOut: $raw" }

    try {
        $obj = $raw | ConvertFrom-Json
    } catch {
        throw "${Case}: stdout deveria ser JSON parseavel; falhou: $($_.Exception.Message). StdOut: $raw"
    }

    if ($obj.Kind -ne 'xpz-sync-result') { throw "${Case}: JSON.Kind deveria ser 'xpz-sync-result'; obtido '$($obj.Kind)'" }
    if ($obj.SchemaVersion -ne 1) { throw "${Case}: JSON.SchemaVersion deveria ser 1; obtido '$($obj.SchemaVersion)'" }
    return $obj
}

try {
    if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
        throw "Fixture not found: $fixturePath"
    }

    # A: -VerifyOnly nao materializa, mas tambem nao deve quebrar em StrictMode
    # ao passar pelo reconciliador GUID-aware com itens legados sem GUID estavel.
    $a = New-CaseDir -Name 'verify-only'
    $repA = Join-Path $a.Root 'report.json'
    $rA = Invoke-LegacySync -Acervo $a.Acervo -VerifyOnly -ReportPath $repA
    if ($rA.Output -match "property 'Guid' cannot be found") {
        throw "A: export legado sob -FullSnapshot nao deveria quebrar por propriedade Guid ausente. Saida: $($rA.Output)"
    }
    if (-not (Test-Path -LiteralPath $repA -PathType Leaf)) {
        throw "A: relatorio deveria ter sido gravado antes da falha esperada de verificacao."
    }
    if (Test-Path -LiteralPath (Join-Path $a.Acervo 'Transaction\Cliente.xml')) {
        throw 'A: VerifyOnly nao deveria materializar Transaction/Cliente.xml.'
    }
    if (Test-Path -LiteralPath (Join-Path $a.Acervo 'Attribute\ClienteId.xml')) {
        throw 'A: VerifyOnly nao deveria materializar Attribute/ClienteId.xml.'
    }
    $aObj = Assert-StdoutIsPureJson -Case 'A' -Result $rA
    if (-not $aObj.LegacyFormatDetected) { throw 'A: LegacyFormatDetected deveria ser true.' }
    if ($aObj.RenamedByGuid -ne 0) { throw "A: RenamedByGuid deveria ser 0; obtido $($aObj.RenamedByGuid)." }
    if ($aObj.RenameResidualsDetected -ne 0) { throw "A: RenameResidualsDetected deveria ser 0; obtido $($aObj.RenameResidualsDetected)." }

    # B: materializacao real em DestinationRoot existente deve concluir e manter
    # o caminho legado fora da reconciliacao por GUID.
    $b = New-CaseDir -Name 'apply'
    $repB = Join-Path $b.Root 'report.json'
    $rB = Invoke-LegacySync -Acervo $b.Acervo -ReportPath $repB
    if ($rB.ExitCode -ne 0) { throw "B: materializacao legada deveria sair com exit 0; obtido $($rB.ExitCode). Saida: $($rB.Output)" }

    $transactionPath = Join-Path $b.Acervo 'Transaction\Cliente.xml'
    $attributePath = Join-Path $b.Acervo 'Attribute\ClienteId.xml'
    if (-not (Test-Path -LiteralPath $transactionPath -PathType Leaf)) { throw 'B: Transaction/Cliente.xml deveria existir.' }
    if (-not (Test-Path -LiteralPath $attributePath -PathType Leaf)) { throw 'B: Attribute/ClienteId.xml deveria existir.' }

    [xml]$transactionXml = Get-Content -LiteralPath $transactionPath -Raw
    if ($transactionXml.DocumentElement.GetAttribute('dataSource') -ne 'gx-legacy-export') {
        throw 'B: Transaction materializada deveria ter dataSource=gx-legacy-export.'
    }
    if ($null -eq $transactionXml.DocumentElement.SelectSingleNode('./GxLegacyPayload')) {
        throw 'B: Transaction materializada deveria conter GxLegacyPayload.'
    }
    if (-not [string]::IsNullOrWhiteSpace($transactionXml.DocumentElement.GetAttribute('guid'))) {
        throw 'B: XML legado materializado nao deveria carregar guid de identidade estavel.'
    }

    $bObj = Assert-StdoutIsPureJson -Case 'B' -Result $rB
    if (-not $bObj.LegacyFormatDetected) { throw 'B: LegacyFormatDetected deveria ser true.' }
    if ($bObj.MaterializationInterpretation -ne 'legacy-export-adapted') {
        throw "B: MaterializationInterpretation deveria ser legacy-export-adapted; obtido '$($bObj.MaterializationInterpretation)'."
    }
    if ($bObj.RenamedByGuid -ne 0) { throw "B: RenamedByGuid deveria ser 0; obtido $($bObj.RenamedByGuid)." }
    if ($bObj.RenameResidualsDetected -ne 0) { throw "B: RenameResidualsDetected deveria ser 0; obtido $($bObj.RenameResidualsDetected)." }

    Write-Output 'OK: Test-XpzSyncLegacyExportFullSnapshotSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
