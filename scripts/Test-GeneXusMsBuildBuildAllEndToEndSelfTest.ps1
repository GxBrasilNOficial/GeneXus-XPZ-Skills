#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)

    if (-not $Condition) {
        throw $Message
    }
}

function Get-ArrayCount {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return 0
    }

    return @($Value).Count
}

function Remove-WrapperArtifactDirectory {
    param(
        [AllowNull()][string]$MsBuildFilePath,
        [string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($MsBuildFilePath)) {
        return
    }

    $artifactDirectory = Split-Path -Parent $MsBuildFilePath
    $allowedRoot = Join-Path $RepositoryRoot 'Temp\xpz-msbuild-build'
    $resolvedArtifactDirectory = [System.IO.Path]::GetFullPath($artifactDirectory)
    $resolvedAllowedRoot = [System.IO.Path]::GetFullPath($allowedRoot).TrimEnd('\\')
    $relative = [System.IO.Path]::GetRelativePath($resolvedAllowedRoot, $resolvedArtifactDirectory)

    if ($relative -match '^(\.\.|$)' -or (Split-Path -Leaf $resolvedArtifactDirectory) -notmatch '^gx-buildall-[0-9a-f]{32}$') {
        throw "Recusa de limpeza fora do artefato BuildAll do self-test: $resolvedArtifactDirectory"
    }

    if (Test-Path -LiteralPath $resolvedArtifactDirectory -PathType Container) {
        Remove-Item -LiteralPath $resolvedArtifactDirectory -Recurse -Force
    }
}

function Invoke-BuildAllScenario {
    param(
        [string]$ScenarioRoot,
        [string[]]$StdErrLines,
        # Leituras de GetActiveEnvironment na ordem do .msbuild: abertura (antes dos Set) e efetiva (depois).
        [string[]]$ContextLines = @(
            "echo The active environment is 'TestEnvironment'",
            "echo The active environment is 'TestEnvironment'"
        ),
        [int]$FakeExitCode = 0
    )

    $fakeGeneXusDirectory = Join-Path $ScenarioRoot 'GeneXus'
    $fakeKbDirectory = Join-Path $ScenarioRoot 'Kb'
    $workingDirectory = Join-Path $ScenarioRoot 'work'
    $logPath = Join-Path $ScenarioRoot 'result.json'
    $fakeMsBuildPath = Join-Path $ScenarioRoot 'fake-msbuild.cmd'

    foreach ($directory in @($fakeGeneXusDirectory, $fakeKbDirectory, $workingDirectory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    [System.IO.File]::WriteAllText(
        (Join-Path $fakeGeneXusDirectory 'Genexus.Tasks.targets'),
        '<Project />',
        [System.Text.UTF8Encoding]::new($false))

    $cmdLines = @(
        '@echo off',
        'echo __KB_OPEN__=true'
    )
    $cmdLines += $ContextLines
    if ($FakeExitCode -eq 0) {
        $cmdLines += @(
            'echo ^> Build All Task Sucesso',
            'echo ========== Build All Task terminado ==========',
            'echo __BUILDALL_DONE__=true'
        )
    }
    foreach ($line in $StdErrLines) {
        $cmdLines += ('1>&2 echo ' + $line)
    }
    $cmdLines += ('exit /b {0}' -f $FakeExitCode)
    [System.IO.File]::WriteAllText(
        $fakeMsBuildPath,
        ($cmdLines -join "`r`n") + "`r`n",
        [System.Text.Encoding]::ASCII)

    $wrapperPath = Join-Path $PSScriptRoot 'Invoke-GeneXusKbBuildAll.ps1'
    $wrapperOutput = & $wrapperPath `
        -KbPath $fakeKbDirectory `
        -WorkingDirectory $workingDirectory `
        -LogPath $logPath `
        -GeneXusDir $fakeGeneXusDirectory `
        -MsBuildPath $fakeMsBuildPath `
        -EnvironmentName 'TestEnvironment'
    $wrapperExitCode = $LASTEXITCODE
    $jsonText = @($wrapperOutput) -join [Environment]::NewLine

    return [ordered]@{
        ExitCode = $wrapperExitCode
        Diagnostic = ($jsonText | ConvertFrom-Json -Depth 16)
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-buildall-e2e-selftest-' + [System.Guid]::NewGuid().ToString('N'))
$noise = "context [anonymous] 1:12 attribute component isn't defined"
$artifactDirectories = New-Object System.Collections.Generic.List[string]

try {
    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

    $noiseOnly = Invoke-BuildAllScenario -ScenarioRoot (Join-Path $testRoot 'noise-only') -StdErrLines @($noise, $noise, $noise)
    $noiseOnlyArtifact = [string]$noiseOnly.Diagnostic.artifacts.MsBuildFilePath
    $artifactDirectories.Add($noiseOnlyArtifact)

    Assert-True -Condition ($noiseOnly.ExitCode -eq 0) -Message ("BuildAll com ruido conhecido deveria encerrar com exit 0; recebeu exit {0}, status '{1}', resumo '{2}'." -f $noiseOnly.ExitCode, $noiseOnly.Diagnostic.status, $noiseOnly.Diagnostic.summary)
    Assert-True -Condition ($noiseOnly.Diagnostic.executionEvidence.msBuildExitCode -eq 0) -Message 'executionEvidence.msBuildExitCode deveria ser 0.'
    Assert-True -Condition ($noiseOnly.Diagnostic.observedContext.KbOpen -eq $true) -Message 'KbOpen deveria ser true.'
    Assert-True -Condition ($noiseOnly.Diagnostic.observedContext.BuildAllDone -eq $true) -Message 'BuildAllDone deveria ser true.'
    Assert-True -Condition ($noiseOnly.Diagnostic.postProcessingFailed -eq $false) -Message ("postProcessingFailed deveria ser false; erro: {0}" -f $noiseOnly.Diagnostic.postProcessingError)
    Assert-True -Condition ((Get-ArrayCount -Value $noiseOnly.Diagnostic.stderrFilteredNoise) -eq 3) -Message 'As tres linhas de ruido conhecido deveriam permanecer em stderrFilteredNoise.'
    Assert-True -Condition ((Get-ArrayCount -Value $noiseOnly.Diagnostic.stderrContent) -eq 0) -Message 'stderrContent deveria ficar vazio quando stderr contem somente ruido conhecido.'
    Assert-True -Condition ($noiseOnly.Diagnostic.status -eq 'compilou limpo') -Message 'Ruido conhecido isolado nao pode degradar a classificacao operacional.'
    Assert-True -Condition ($noiseOnly.Diagnostic.exitCode -eq 0 -and -not $noiseOnly.Diagnostic.msBuildCategoryBBlocked) -Message 'Cenario de ruido conhecido deveria permanecer como sucesso operacional.'

    $mixed = Invoke-BuildAllScenario -ScenarioRoot (Join-Path $testRoot 'mixed') -StdErrLines @($noise, $noise, $noise, 'ERRO REAL: detalhe preservado')
    $mixedArtifact = [string]$mixed.Diagnostic.artifacts.MsBuildFilePath
    $artifactDirectories.Add($mixedArtifact)

    Assert-True -Condition ($mixed.ExitCode -eq 0) -Message 'Stderr misto nao deve alterar o exitCode bruto do wrapper neste cenario.'
    Assert-True -Condition ($mixed.Diagnostic.executionEvidence.msBuildExitCode -eq 0) -Message 'Stderr misto deveria preservar msBuildExitCode 0.'
    Assert-True -Condition ($mixed.Diagnostic.observedContext.KbOpen -eq $true -and $mixed.Diagnostic.observedContext.BuildAllDone -eq $true) -Message 'Stderr misto deveria preservar os sinais de conclusao operacional.'
    Assert-True -Condition ((Get-ArrayCount -Value $mixed.Diagnostic.stderrFilteredNoise) -eq 3) -Message 'Stderr misto deveria manter as tres linhas conhecidas em stderrFilteredNoise.'
    Assert-True -Condition ((Get-ArrayCount -Value $mixed.Diagnostic.stderrContent) -eq 1) -Message 'Stderr misto deveria preservar uma linha real em stderrContent.'
    Assert-True -Condition ([string]$mixed.Diagnostic.stderrContent[0] -eq 'ERRO REAL: detalhe preservado') -Message 'A linha real do stderr misto foi perdida ou alterada.'
    Assert-True -Condition ($mixed.Diagnostic.postProcessingFailed -eq $false) -Message 'Stderr misto nao deveria causar falha de pos-processamento.'
    Assert-True -Condition ($mixed.Diagnostic.status -eq 'operacao concluida, pendente de confirmacao funcional') -Message 'Stderr misto deveria rebaixar a classificacao conforme o contrato do wrapper.'
    Assert-True -Condition ($mixed.Diagnostic.exitCode -eq 0 -and -not $mixed.Diagnostic.msBuildCategoryBBlocked) -Message 'Stderr misto deveria manter exit 0 sem declarar sucesso limpo.'

    # Troca de environment bem-sucedida: o efetivo e a leitura posterior ao SetActiveEnvironment,
    # nao a de abertura (caso real: build em NETPostgreSQL relatado como '.Net Environment').
    $switched = Invoke-BuildAllScenario -ScenarioRoot (Join-Path $testRoot 'environment-switch') -StdErrLines @() -ContextLines @(
        "echo The active environment is '.Net Environment'",
        'echo ^> Set Active Environment Sucesso',
        "echo The active environment is 'TestEnvironment'"
    )
    $artifactDirectories.Add([string]$switched.Diagnostic.artifacts.MsBuildFilePath)

    Assert-True -Condition ($switched.ExitCode -eq 0) -Message ("Troca de environment deveria encerrar com exit 0; recebeu exit {0}, status '{1}'." -f $switched.ExitCode, $switched.Diagnostic.status)
    Assert-True -Condition ([string]$switched.Diagnostic.observedContext.ActiveEnvironment -eq 'TestEnvironment') -Message ("ActiveEnvironment deveria ser o environment efetivo apos SetActiveEnvironment; recebeu '{0}'." -f $switched.Diagnostic.observedContext.ActiveEnvironment)
    Assert-True -Condition ([string]$switched.Diagnostic.observedContext.ActiveEnvironmentAtOpen -eq '.Net Environment') -Message ("ActiveEnvironmentAtOpen deveria preservar o environment de abertura; recebeu '{0}'." -f $switched.Diagnostic.observedContext.ActiveEnvironmentAtOpen)
    Assert-True -Condition (@($switched.Diagnostic.warnings | Where-Object { [string]$_ -match 'GetActiveEnvironment' }).Count -eq 0) -Message 'Troca bem-sucedida com leitura posterior nao deveria gerar aviso de leitura ausente.'
    Assert-True -Condition ($switched.Diagnostic.status -eq 'compilou limpo') -Message ("Troca de environment bem-sucedida nao deveria rebaixar o status; recebeu '{0}'." -f $switched.Diagnostic.status)

    # O .msbuild gerado precisa ler o environment antes e depois do SetActiveEnvironment, e so entao compilar.
    $msBuildText = [System.IO.File]::ReadAllText([string]$switched.Diagnostic.artifacts.MsBuildFilePath)
    $firstGetEnvironment = $msBuildText.IndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    $setEnvironment = $msBuildText.IndexOf('<SetActiveEnvironment', [System.StringComparison]::Ordinal)
    $lastGetEnvironment = $msBuildText.LastIndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    $buildAll = $msBuildText.IndexOf('<BuildAll', [System.StringComparison]::Ordinal)
    Assert-True -Condition ($firstGetEnvironment -ge 0 -and $firstGetEnvironment -lt $setEnvironment -and $setEnvironment -lt $lastGetEnvironment -and $lastGetEnvironment -lt $buildAll) -Message 'O .msbuild deveria ter GetActiveEnvironment antes e depois de SetActiveEnvironment, ambos antes de BuildAll.'

    # Troca pedida sem leitura posterior: nao reportar o environment de abertura como efetivo.
    $unconfirmed = Invoke-BuildAllScenario -ScenarioRoot (Join-Path $testRoot 'environment-unconfirmed') -StdErrLines @() -ContextLines @(
        "echo The active environment is '.Net Environment'"
    )
    $artifactDirectories.Add([string]$unconfirmed.Diagnostic.artifacts.MsBuildFilePath)

    Assert-True -Condition ($null -eq $unconfirmed.Diagnostic.observedContext.ActiveEnvironment) -Message ("Sem leitura posterior ao Set, ActiveEnvironment deveria ficar nulo; recebeu '{0}'." -f $unconfirmed.Diagnostic.observedContext.ActiveEnvironment)
    Assert-True -Condition ([string]$unconfirmed.Diagnostic.observedContext.ActiveEnvironmentAtOpen -eq '.Net Environment') -Message 'ActiveEnvironmentAtOpen deveria registrar a leitura de abertura.'
    Assert-True -Condition (@($unconfirmed.Diagnostic.warnings | Where-Object { [string]$_ -match 'posterior a SetActiveEnvironment' }).Count -eq 1) -Message 'Sem leitura posterior ao Set, o wrapper deveria avisar que o environment efetivo nao foi observado.'

    # SetActiveEnvironment falhou: o bloqueio cita o environment de abertura, que segue ativo.
    $setFailed = Invoke-BuildAllScenario -ScenarioRoot (Join-Path $testRoot 'environment-set-failed') -StdErrLines @() -FakeExitCode 1 -ContextLines @(
        "echo The active environment is '.Net Environment'",
        "echo Ambiente 'TestEnvironment' nao existe",
        'echo Set Active Environment falhou'
    )
    $artifactDirectories.Add([string]$setFailed.Diagnostic.artifacts.MsBuildFilePath)

    $setFailedReason = @($setFailed.Diagnostic.blockingReasons | Where-Object { [string]$_ -match '^SetActiveEnvironment falhou' })
    Assert-True -Condition ($setFailedReason.Count -eq 1) -Message 'Falha de SetActiveEnvironment deveria gerar um blockingReason especifico.'
    Assert-True -Condition ([string]$setFailedReason[0] -match "momento da abertura era '\.Net Environment'") -Message ("O blockingReason deveria citar o environment de abertura; recebeu '{0}'." -f $setFailedReason[0])
    Assert-True -Condition ([string]$setFailed.Diagnostic.observedContext.ActiveEnvironment -eq '.Net Environment') -Message 'Com SetActiveEnvironment falho, o environment efetivo continua sendo o de abertura.'
}
finally {
    foreach ($msBuildFilePath in $artifactDirectories) {
        try {
            Remove-WrapperArtifactDirectory -MsBuildFilePath $msBuildFilePath -RepositoryRoot $repositoryRoot
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }

    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Output 'GENEXUS_MSBUILD_BUILDALL_E2E_SELFTEST_OK'
