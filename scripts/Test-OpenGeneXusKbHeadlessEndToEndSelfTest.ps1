#requires -Version 7.4

<#
.SYNOPSIS
    E2E in-repo do Open-GeneXusKbHeadless.ps1 com MSBuild falso e GeneXusDir falso.

.DESCRIPTION
    Passa pelo probe real (Test-GeneXusMsBuildSetup.ps1) e pelo gerador de .msbuild do wrapper.
    Cobre a matriz do classificador de exit por cadeia (20/21/22/25 e desconhecido), a leitura
    de abertura vs efetiva (Get -> Set -> Get), o bloqueio de Set falho citando a abertura, o
    fallback de stderr e a asserção estrutural por indices/Condition no .msbuild gerado.
#>

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

function Invoke-OpenScenario {
    param(
        [string]$ScenarioRoot,
        [string[]]$StdOutCmdLines = @(),
        [string[]]$StdErrCmdLines = @(),
        [int]$FakeExitCode = 0,
        [string]$EnvironmentName,
        [string]$VersionName
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

    $cmdLines = @('@echo off') + $StdOutCmdLines + $StdErrCmdLines + @('exit /b {0}' -f $FakeExitCode)
    [System.IO.File]::WriteAllText(
        $fakeMsBuildPath,
        ($cmdLines -join "`r`n") + "`r`n",
        [System.Text.Encoding]::ASCII)

    $wrapperPath = Join-Path $PSScriptRoot 'Open-GeneXusKbHeadless.ps1'
    $wrapperArgs = @{
        KbPath = $fakeKbDirectory
        WorkingDirectory = $workingDirectory
        LogPath = $logPath
        GeneXusDir = $fakeGeneXusDirectory
        MsBuildPath = $fakeMsBuildPath
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) { $wrapperArgs.EnvironmentName = $EnvironmentName }
    if (-not [string]::IsNullOrWhiteSpace($VersionName)) { $wrapperArgs.VersionName = $VersionName }

    $wrapperOutput = & $wrapperPath @wrapperArgs
    $wrapperExitCode = $LASTEXITCODE
    $jsonText = @($wrapperOutput) -join [Environment]::NewLine

    return [ordered]@{
        ExitCode = $wrapperExitCode
        Diagnostic = ($jsonText | ConvertFrom-Json -Depth 16)
    }
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-open-e2e-selftest-' + [System.Guid]::NewGuid().ToString('N'))
try {
    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

    # Troca bem-sucedida: efetivo = leitura posterior ao Set; AtOpen = leitura de abertura.
    $switched = Invoke-OpenScenario -ScenarioRoot (Join-Path $testRoot 'switch') -EnvironmentName 'EnvB' -StdOutCmdLines @(
        "echo The active environment is 'EnvA'",
        'echo ^> Set Active Environment Sucesso',
        "echo The active environment is 'EnvB'"
    )
    Assert-True -Condition ($switched.ExitCode -eq 0) -Message ("Troca OK deveria dar exit 0; recebeu {0} ({1})." -f $switched.ExitCode, $switched.Diagnostic.summary)
    Assert-True -Condition ([string]$switched.Diagnostic.observedContext.ActiveEnvironment -eq 'EnvB') -Message ("ActiveEnvironment deveria ser o efetivo 'EnvB'; recebeu '{0}'." -f $switched.Diagnostic.observedContext.ActiveEnvironment)
    Assert-True -Condition ([string]$switched.Diagnostic.observedContext.ActiveEnvironmentAtOpen -eq 'EnvA') -Message ("ActiveEnvironmentAtOpen deveria ser 'EnvA'; recebeu '{0}'." -f $switched.Diagnostic.observedContext.ActiveEnvironmentAtOpen)

    # Estrutural: Get (AtOpen) antes do Set, Set antes do Get efetivo, Condition preservada.
    $msBuildText = [System.IO.File]::ReadAllText([string]$switched.Diagnostic.artifacts.MsBuildFilePath)
    $firstGetEnvironment = $msBuildText.IndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    $setVersion = $msBuildText.IndexOf('<SetActiveVersion', [System.StringComparison]::Ordinal)
    $lastGetEnvironment = $msBuildText.LastIndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    Assert-True -Condition ($firstGetEnvironment -ge 0 -and $firstGetEnvironment -lt $setVersion -and $setVersion -lt $lastGetEnvironment) -Message 'O .msbuild deveria ter GetActiveEnvironment antes e depois de SetActiveVersion.'
    Assert-True -Condition ($msBuildText -match "<SetActiveVersion Condition=`"'`\$\(KBVersion\)' != ''`"") -Message 'SetActiveVersion deve preservar o Condition.'

    # Set Active Version falho -> 21; bloqueio cita a abertura.
    $setVersionFailed = Invoke-OpenScenario -ScenarioRoot (Join-Path $testRoot 'set-version-failed') -VersionName 'NoSuch' -FakeExitCode 1 -StdOutCmdLines @(
        "echo The active version is 'v1'",
        'echo error : ^> Set Active Version falhou'
    )
    Assert-True -Condition ($setVersionFailed.ExitCode -eq 21) -Message ("Set Active Version falho deveria dar exit 21; recebeu {0}." -f $setVersionFailed.ExitCode)
    $reason = @($setVersionFailed.Diagnostic.blockingReasons | Where-Object { [string]$_ -match '^SetActiveVersion falhou' })
    Assert-True -Condition ($reason.Count -eq 1 -and $reason[0] -match "abertura era 'v1'") -Message ("Bloqueio deveria citar a versao de abertura 'v1'; recebeu '{0}'." -f ($reason -join ' / '))

    # Set Active Environment falho -> 22 (marcador so em stdout).
    $setEnvFailed = Invoke-OpenScenario -ScenarioRoot (Join-Path $testRoot 'set-env-failed') -EnvironmentName 'NoSuch' -FakeExitCode 1 -StdOutCmdLines @(
        "echo The active environment is 'EnvA'",
        "echo Ambiente 'NoSuch' nao existe",
        'echo error : ^> Set Active Environment falhou'
    )
    Assert-True -Condition ($setEnvFailed.ExitCode -eq 22) -Message ("Set Active Environment falho deveria dar exit 22; recebeu {0}." -f $setEnvFailed.ExitCode)

    # Open falhou (com Close warning) -> 20; warning de Close nao dispara 25.
    $openFailed = Invoke-OpenScenario -ScenarioRoot (Join-Path $testRoot 'open-failed') -FakeExitCode 1 -StdOutCmdLines @(
        'echo error : ^> Open Knowledge Base Task falhou',
        'echo warning : ^> Close Knowledge Base Task falhou'
    )
    Assert-True -Condition ($openFailed.ExitCode -eq 20) -Message ("Open falho deveria dar exit 20; recebeu {0}." -f $openFailed.ExitCode)

    # Close error primario (sem error anterior) -> 25.
    $closeFailed = Invoke-OpenScenario -ScenarioRoot (Join-Path $testRoot 'close-failed') -FakeExitCode 1 -StdOutCmdLines @(
        'echo error : ^> Close Knowledge Base falhou'
    )
    Assert-True -Condition ($closeFailed.ExitCode -eq 25) -Message ("Close falho primario deveria dar exit 25; recebeu {0}." -f $closeFailed.ExitCode)

    # Formato desconhecido -> 20.
    $unknown = Invoke-OpenScenario -ScenarioRoot (Join-Path $testRoot 'unknown') -FakeExitCode 1 -StdOutCmdLines @(
        'echo falha nao mapeada sem marcador'
    )
    Assert-True -Condition ($unknown.ExitCode -eq 20) -Message ("Falha desconhecida deveria dar exit 20; recebeu {0}." -f $unknown.ExitCode)

    # Marcador so em stderr -> classificado pelo stderr filtrado (22).
    $stderrOnly = Invoke-OpenScenario -ScenarioRoot (Join-Path $testRoot 'stderr-only') -FakeExitCode 1 -StdErrCmdLines @(
        '1>&2 echo error : ^> Set Active Environment falhou'
    )
    Assert-True -Condition ($stderrOnly.ExitCode -eq 22) -Message ("Marcador so em stderr deveria dar exit 22; recebeu {0}." -f $stderrOnly.ExitCode)

    # Conflito stdout vs stderr: stdout (SetVersion=21) vence.
    $conflict = Invoke-OpenScenario -ScenarioRoot (Join-Path $testRoot 'conflict') -FakeExitCode 1 -StdOutCmdLines @(
        'echo error : ^> Set Active Version falhou'
    ) -StdErrCmdLines @(
        '1>&2 echo error : ^> Set Active Environment falhou'
    )
    Assert-True -Condition ($conflict.ExitCode -eq 21) -Message ("Conflito deveria resolver por stdout (21); recebeu {0}." -f $conflict.ExitCode)
}
finally {
    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'OPEN_GENEXUS_KB_HEADLESS_E2E_SELFTEST_OK'
