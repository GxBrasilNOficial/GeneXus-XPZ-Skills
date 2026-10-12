#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$readerPath = Join-Path $PSScriptRoot 'Read-MsBuildImportSignals.ps1'
if (-not (Test-Path -LiteralPath $readerPath -PathType Leaf)) {
    throw "Read-MsBuildImportSignals.ps1 nao encontrado: $readerPath"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-msbuild-signals-classifier-" + [guid]::NewGuid().ToString('N'))
try {
    [void](New-Item -ItemType Directory -Path $tempRoot -Force)

    $stdoutPath = Join-Path $tempRoot 'msbuild.stdout.log'
    $stderrPath = Join-Path $tempRoot 'msbuild.stderr.log'

    $stdoutText = @(
        "O acesso ao caminho 'C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json' foi negado."
        'Import Task Success'
    ) -join [Environment]::NewLine

    [System.IO.File]::WriteAllText($stdoutPath, $stdoutText, (Get-Utf8NoBomEncoding))
    [System.IO.File]::WriteAllText($stderrPath, '', (Get-Utf8NoBomEncoding))

    $jsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -Stage 'classifier-self-test' -AsJson) -join [Environment]::NewLine
    $signals = $jsonText | ConvertFrom-Json
    $knownNoise = @($signals.knownStdOutNoise)

    if ($knownNoise.Count -ne 1) {
        throw "Esperava 1 knownStdOutNoise; obtido: $($knownNoise.Count)"
    }

    if ($knownNoise[0].code -ne 'cssproperties-access-denied') {
        throw "Codigo inesperado para knownStdOutNoise: $($knownNoise[0].code)"
    }

    if ($knownNoise[0].classification -ne 'known-environment-noise') {
        throw "Classificacao inesperada para knownStdOutNoise: $($knownNoise[0].classification)"
    }

    if ($signals.counts.knownStdOutNoise -ne 1) {
        throw "Contador knownStdOutNoise inesperado: $($signals.counts.knownStdOutNoise)"
    }

    $lockedStdoutText = @(
        "The process cannot access the file 'C:\Models\GX\GxImport.log' because it is being used by another process."
        'Import Task Success'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $lockedStdoutText, (Get-Utf8NoBomEncoding))

    $lockedJsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -Stage 'classifier-self-test' -AsJson) -join [Environment]::NewLine
    $lockedSignals = $lockedJsonText | ConvertFrom-Json

    if ($lockedSignals.gxImportLogReadStatus -ne 'locked') {
        throw "Status gxImportLogReadStatus inesperado: $($lockedSignals.gxImportLogReadStatus)"
    }

    if (-not $lockedSignals.diagnosticDegraded) {
        throw 'Esperava diagnosticDegraded=true para lock de GxImport.log.'
    }

    if ([string]::IsNullOrWhiteSpace($lockedSignals.gxImportLogReadError)) {
        throw 'Esperava gxImportLogReadError preenchido para lock de GxImport.log.'
    }

    $aliasStdoutText = @(
        '__IMPORTED_ITEM__=SDPanel:SDVendaIncluir'
        'Import Task Success'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $aliasStdoutText, (Get-Utf8NoBomEncoding))

    $aliasJsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -ExpectedItems 'Panel:SDVendaIncluir' -Stage 'classifier-self-test' -AsJson) -join [Environment]::NewLine
    $aliasSignals = $aliasJsonText | ConvertFrom-Json
    $aliasMatches = @($aliasSignals.itemAliasMatches)

    if ($aliasMatches.Count -ne 1) {
        throw "Esperava 1 itemAliasMatches; obtido: $($aliasMatches.Count)"
    }

    if ($aliasMatches[0].canonical -ne 'Panel:SDVendaIncluir') {
        throw "Canonical inesperado para alias Panel/SDPanel: $($aliasMatches[0].canonical)"
    }

    if (@($aliasSignals.expectedItemsCanonical)[0] -ne @($aliasSignals.importedItemsCanonical)[0]) {
        throw 'Esperava expectedItemsCanonical e importedItemsCanonical equivalentes para Panel/SDPanel.'
    }

    $exportStdoutText = @(
        'error : WorkWithForWeb is not a valid type.'
        'error : WorkWithForWeb is not a valid type.'
        'Exportando Work With for Web instância WWPDemo'
        'Export Sucesso'
        '__EXPORTED_FILE__=C:\Temp\demo.xpz'
        "O acesso ao caminho 'C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json' foi negado."
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $exportStdoutText, (Get-Utf8NoBomEncoding))

    $exportJsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -Stage 'export' -AsJson) -join [Environment]::NewLine
    $exportSignals = $exportJsonText | ConvertFrom-Json
    $exportErrors = @($exportSignals.exportErrors)

    if ($exportErrors.Count -ne 2) {
        throw "Esperava 2 exportErrors; obtido: $($exportErrors.Count)"
    }

    if (@($exportSignals.invalidTypesRejected)[0] -ne 'WorkWithForWeb') {
        throw "invalidTypesRejected inesperado: $(@($exportSignals.invalidTypesRejected) -join ', ')"
    }

    if (-not $exportSignals.exportTaskSuccess) {
        throw 'Esperava exportTaskSuccess=true para Export Sucesso.'
    }

    if (-not $exportSignals.exportMarkerFound) {
        throw 'Esperava exportMarkerFound=true para __EXPORTED_FILE__.'
    }

    if ($exportSignals.counts.knownStdOutNoise -ne 1) {
        throw "Contador knownStdOutNoise inesperado no export: $($exportSignals.counts.knownStdOutNoise)"
    }

    # Contexto informado: separa efetivo (pos-Set) de abertura e ecoa contextQuality.
    $contextStdoutText = @(
        "The active environment is '.Net Environment'"
        '> Set Active Environment Sucesso'
        "The active environment is 'TestEnvironment'"
        'Import Task Success'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $contextStdoutText, (Get-Utf8NoBomEncoding))

    $contextJsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -RequestedEnvironmentName 'TestEnvironment' -SetEnvironmentFailed:$false -Stage 'classifier-self-test' -AsJson) -join [Environment]::NewLine
    $contextSignals = $contextJsonText | ConvertFrom-Json
    if ($contextSignals.activeEnvironment -ne 'TestEnvironment') {
        throw "activeEnvironment (efetivo) inesperado: $($contextSignals.activeEnvironment)"
    }
    if ($contextSignals.activeEnvironmentAtOpen -ne '.Net Environment') {
        throw "activeEnvironmentAtOpen inesperado: $($contextSignals.activeEnvironmentAtOpen)"
    }
    if ($contextSignals.contextQuality -ne 'complete') {
        throw "contextQuality inesperado: $($contextSignals.contextQuality)"
    }

    # Troca pedida sem leitura posterior => efetivo nulo (contexto parcial: so o nome).
    $singleReadText = @(
        "The active environment is '.Net Environment'"
        'Import Task Success'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($stdoutPath, $singleReadText, (Get-Utf8NoBomEncoding))
    $singleJsonText = (& $readerPath -StdOutPath $stdoutPath -StdErrPath $stderrPath -RequestedEnvironmentName 'TestEnvironment' -Stage 'classifier-self-test' -AsJson) -join [Environment]::NewLine
    $singleSignals = $singleJsonText | ConvertFrom-Json
    if ($null -ne $singleSignals.activeEnvironment) {
        throw "Efetivo deveria ser nulo sem leitura posterior; recebeu '$($singleSignals.activeEnvironment)'."
    }
    if ($singleSignals.activeEnvironmentAtOpen -ne '.Net Environment') {
        throw "activeEnvironmentAtOpen inesperado: $($singleSignals.activeEnvironmentAtOpen)"
    }
    if ($singleSignals.contextQuality -ne 'partial') {
        throw "contextQuality (so o nome) deveria ser partial: $($singleSignals.contextQuality)"
    }

    # Modo legado (sem contexto): AtOpen nulo e contextQuality=legacy.
    if ($null -ne $aliasSignals.activeEnvironmentAtOpen) {
        throw 'Legado deveria ter activeEnvironmentAtOpen nulo.'
    }
    if ($aliasSignals.contextQuality -ne 'legacy') {
        throw "Legado deveria ter contextQuality=legacy: $($aliasSignals.contextQuality)"
    }

    'TEST_MsBuildImportSignalsClassifier=PASS'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
