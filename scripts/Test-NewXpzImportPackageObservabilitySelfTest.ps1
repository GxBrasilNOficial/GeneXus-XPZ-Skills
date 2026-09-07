#requires -Version 7.4
<#
.SYNOPSIS
    Autoteste do relatorio de execucao do empacotamento XPZ.

.DESCRIPTION
    Verifica o bloqueio sem efeito colateral de ReportPath invalido, o caminho
    feliz com inventario confirmado, a recusa de tipo desconhecido pelo inventario
    e a preservacao de estado running quando o wrapper e interrompido durante a
    fase de escrita do pacote.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'New-XpzImportPackage.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('new-xpz-import-observability-{0}' -f [guid]::NewGuid().ToString('N'))
$encoding = [Text.UTF8Encoding]::new($false)
$process = $null

function New-ObservabilityFixture {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$FrontName,
        [string]$ObjectType = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
    )

    $frontDir = Join-Path $Root 'ObjetosGeradosParaImportacaoNaKbNoGenexus' $FrontName
    $acervoDir = Join-Path $Root 'ObjetosDaKbEmXml' 'Procedure'
    [void](New-Item -ItemType Directory -Path $frontDir, $acervoDir, (Join-Path $Root 'reports') -Force)
    $frontXml = '<Object type="84a12160-f59b-4ad7-a683-ea4481ac23e9" name="procObservabilidade" guid="11111111-1111-1111-1111-111111111111" fullyQualifiedName="procObservabilidade" lastUpdate="2026-02-01T00:00:00.0000000Z"><Properties><Property><Name>Name</Name><Value>procObservabilidade</Value></Property></Properties><Source><![CDATA[]]></Source></Object>'
    $frontXml = $frontXml.Replace('84a12160-f59b-4ad7-a683-ea4481ac23e9', $ObjectType)
    $acervoXml = $frontXml.Replace('2026-02-01', '2026-01-01')
    [IO.File]::WriteAllText((Join-Path $frontDir 'procObservabilidade.xml'), $frontXml, $encoding)
    [IO.File]::WriteAllText((Join-Path $acervoDir 'procObservabilidade.xml'), $acervoXml, $encoding)
    $metadata = @(
        '# Metadata', '', '## KMW', '| Campo | Valor |', '|---|---|',
        '| MajorVersion | 18 |', '| MinorVersion | 0 |', '| Build | 170000 |', '',
        '## Source', '| Campo | Valor |', '|---|---|',
        '| kb (GUID) | 22222222-2222-2222-2222-222222222222 |',
        '| username | tester |', '| UNCPath | C:\KB |', '',
        '## Source/Version', '| Campo | Valor |', '|---|---|',
        '| guid | 33333333-3333-3333-3333-333333333333 |', '| name | Main |'
    ) -join "`n"
    [IO.File]::WriteAllText((Join-Path $Root 'kb-source-metadata.md'), $metadata, $encoding)
}

function Invoke-ObservabilityWrapper {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$FrontName,
        [Parameter(Mandatory = $true)][string]$Report
    )

    $errorPath = Join-Path $Root 'wrapper.stderr.txt'
    $stdout = (& $scriptPath -RepoRoot $Root -FrontName $FrontName -ReportPath $Report 2> $errorPath | Out-String)
    $exitCode = $LASTEXITCODE
    return [pscustomobject]@{ exitCode = $exitCode; result = ($stdout | ConvertFrom-Json); stderr = (Get-Content -LiteralPath $errorPath -Raw -ErrorAction SilentlyContinue) }
}

try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)

    $invalidRoot = Join-Path $tempRoot 'invalid'
    New-ObservabilityFixture -Root $invalidRoot -FrontName 'Observabilidade_11111111_20260905'
    $invalidReport = Join-Path $invalidRoot 'reports/invalid.txt'
    $invalidRaw = (& $scriptPath -RepoRoot $invalidRoot -FrontName 'Observabilidade_11111111_20260905' -ReportPath $invalidReport 2>$null | Out-String)
    $invalidCode = $LASTEXITCODE
    $invalidResult = $invalidRaw | ConvertFrom-Json
    if ($invalidCode -ne 20 -or $invalidResult.stage -ne 'validate-report-path') { throw 'ReportPath invalido nao bloqueou no preflight esperado' }
    if (Test-Path -LiteralPath $invalidReport -PathType Leaf) { throw 'ReportPath invalido criou relatorio' }
    if (Test-Path -LiteralPath (Join-Path $invalidRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus')) { throw 'ReportPath invalido criou pasta de pacotes' }

    $historicoRoot = Join-Path $tempRoot 'forbidden-historico'
    New-ObservabilityFixture -Root $historicoRoot -FrontName 'Observabilidade_55555555_20260905'
    [void](New-Item -ItemType Directory -Path (Join-Path $historicoRoot 'historico') -Force)
    $historicoReport = Join-Path $historicoRoot 'historico/report.json'
    $historico = Invoke-ObservabilityWrapper -Root $historicoRoot -FrontName 'Observabilidade_55555555_20260905' -Report $historicoReport
    if ($historico.exitCode -ne 20 -or $historico.result.stage -ne 'validate-report-path') { throw 'ReportPath sob historico nao bloqueou no preflight esperado' }
    if (Test-Path -LiteralPath $historicoReport -PathType Leaf) { throw 'ReportPath sob historico criou relatorio' }
    if (Test-Path -LiteralPath (Join-Path $historicoRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus')) { throw 'ReportPath sob historico criou pasta de pacotes' }

    $packagesRoot = Join-Path $tempRoot 'forbidden-packages'
    New-ObservabilityFixture -Root $packagesRoot -FrontName 'Observabilidade_66666666_20260905'
    $packagesDir = Join-Path $packagesRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus'
    [void](New-Item -ItemType Directory -Path $packagesDir -Force)
    $packagesReport = Join-Path $packagesDir 'side-report.json'
    $packages = Invoke-ObservabilityWrapper -Root $packagesRoot -FrontName 'Observabilidade_66666666_20260905' -Report $packagesReport
    if ($packages.exitCode -ne 20 -or $packages.result.stage -ne 'validate-report-path') { throw 'ReportPath sob PacotesGerados nao bloqueou no preflight esperado' }
    if (Test-Path -LiteralPath $packagesReport -PathType Leaf) { throw 'ReportPath sob PacotesGerados criou relatorio' }

    $successRoot = Join-Path $tempRoot 'success'
    $successFront = 'Observabilidade_22222222_20260905'
    New-ObservabilityFixture -Root $successRoot -FrontName $successFront
    $successReport = Join-Path $successRoot 'reports/success.json'
    $success = Invoke-ObservabilityWrapper -Root $successRoot -FrontName $successFront -Report $successReport
    if ($success.exitCode -ne 0) { throw "caminho feliz retornou exitCode $($success.exitCode)" }
    $successDoc = Get-Content -LiteralPath $successReport -Raw | ConvertFrom-Json
    if ($successDoc.Kind -ne 'xpz-package-execution-report' -or [int]$successDoc.SchemaVersion -ne 1) { throw 'schema do relatorio feliz invalido' }
    if ($successDoc.executionState -ne 'completed' -or $successDoc.packageState -ne 'accepted' -or $successDoc.inventoryDecision -ne 'accepted') { throw 'estado final do relatorio feliz invalido' }
    if ($successDoc.inventoryStatus -ne 'INVENTORY_OK' -or $successDoc.deltaStatus -ne 'MATCH') { throw 'inventario do relatorio feliz nao foi confirmado' }
    $successStages = @($successDoc.stageHistory | ForEach-Object { $_.stage })
    foreach ($requiredStage in @('engine-start', 'classify-front', 'load-template', 'write-package', 'validate-envelope', 'engine-finished', 'post-inventory', 'completed')) {
        if ($successStages -notcontains $requiredStage) { throw "fase $requiredStage do motor Python/pos-inventario nao foi preservada" }
    }
    if (@($successStages | Where-Object { $_ -eq 'completed' }).Count -ne 1) { throw 'relatorio feliz tem conclusao terminal duplicada ou ausente' }
    $successBytes = [IO.File]::ReadAllBytes($successReport)
    if ($successBytes.Length -ge 3 -and $successBytes[0] -eq 0xEF -and $successBytes[1] -eq 0xBB -and $successBytes[2] -eq 0xBF) { throw 'relatorio feliz contem BOM inesperado' }

    $unknownRoot = Join-Path $tempRoot 'unknown-type'
    $unknownFront = 'Observabilidade_44444444_20260905'
    New-ObservabilityFixture -Root $unknownRoot -FrontName $unknownFront -ObjectType 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
    $unknownReport = Join-Path $unknownRoot 'reports/unknown-type.json'
    $unknown = Invoke-ObservabilityWrapper -Root $unknownRoot -FrontName $unknownFront -Report $unknownReport
    if ($unknown.exitCode -eq 0) { throw 'tipo desconhecido nao bloqueou o inventario' }
    $unknownDoc = Get-Content -LiteralPath $unknownReport -Raw | ConvertFrom-Json
    if ($unknownDoc.executionState -ne 'blocked' -or $unknownDoc.packageState -ne 'candidate' -or $unknownDoc.inventoryDecision -ne 'unknown') { throw 'inventario desconhecido promoveu estado incorreto' }
    if ($unknownDoc.inventoryStatus -ne 'UNKNOWN_TYPES_BLOCKED' -or [int]$unknownDoc.resultExitCode -ne 3) { throw 'exitCode do inventario desconhecido nao foi propagado ao relatorio' }
    $unknownStages = @($unknownDoc.stageHistory | ForEach-Object { $_.stage })
    foreach ($requiredStage in @('engine-start', 'classify-front', 'load-template', 'write-package', 'validate-envelope', 'engine-finished', 'post-inventory')) {
        if ($unknownStages -notcontains $requiredStage) { throw "fase $requiredStage nao foi preservada no bloqueio de inventario" }
    }
    if (@($unknownStages | Where-Object { $_ -eq 'completed' }).Count -ne 0) { throw 'bloqueio de inventario registrou conclusao completed indevida' }
    if (@($unknownStages | Where-Object { $_ -eq 'post-inventory' }).Count -ne 1) { throw 'bloqueio de inventario registrou post-inventory duplicado' }

    $holdRoot = Join-Path $tempRoot 'hold'
    $holdFront = 'Observabilidade_33333333_20260905'
    New-ObservabilityFixture -Root $holdRoot -FrontName $holdFront
    $holdReport = Join-Path $holdRoot 'reports/hold.json'
    $holdFile = Join-Path $holdRoot 'hold.signal'
    $readyFile = Join-Path $holdRoot 'ready.signal'
    [IO.File]::WriteAllText($holdFile, 'hold', $encoding)
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    foreach ($arg in @('-NoProfile', '-File', $scriptPath, '-RepoRoot', $holdRoot, '-FrontName', $holdFront, '-ReportPath', $holdReport)) { [void]$psi.ArgumentList.Add($arg) }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['XPZ_NEW_XPZ_TEST_HOLD_STAGE'] = 'write-package'
    $psi.Environment['XPZ_NEW_XPZ_TEST_HOLD_FILE'] = $holdFile
    $psi.Environment['XPZ_NEW_XPZ_TEST_READY_FILE'] = $readyFile
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $readyFile) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path -LiteralPath $readyFile)) { try { $process.Kill($true) } catch { }; throw 'autoteste de interrupcao nao alcançou a fase de escrita' }
    $process.Kill($true)
    [void]$process.WaitForExit(10000)
    [void]$stdoutTask.Wait(10000)
    [void]$stderrTask.Wait(10000)
    $holdDoc = Get-Content -LiteralPath $holdReport -Raw | ConvertFrom-Json
    if ($holdDoc.executionState -ne 'running' -or $holdDoc.packageState -ne 'candidate' -or $null -ne $holdDoc.completedAtUtc) { throw 'interrupcao deixou relatorio em falso estado terminal' }
    if (-not (Test-Path -LiteralPath $holdDoc.packagePath -PathType Leaf)) { throw 'interrupcao nao preservou pacote candidato observavel' }

    'NEW_XPZ_IMPORT_PACKAGE_OBSERVABILITY_SELFTEST_OK'
} finally {
    if ($null -ne $process -and -not $process.HasExited) { try { $process.Kill($true) } catch { } }
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
