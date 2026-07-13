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
        [string[]]$StdErrLines
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
        'echo __KB_OPEN__=true',
        "echo The active environment is 'TestEnvironment'",
        'echo ^> Build All Task Sucesso',
        'echo ========== Build All Task terminado ==========',
        'echo __BUILDALL_DONE__=true'
    )
    foreach ($line in $StdErrLines) {
        $cmdLines += ('1>&2 echo ' + $line)
    }
    $cmdLines += 'exit /b 0'
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
    Assert-True -Condition ((Get-ArrayCount -Value $mixed.Diagnostic.stderrFilteredNoise) -eq 3) -Message 'Stderr misto deveria manter as tres linhas conhecidas em stderrFilteredNoise.'
    Assert-True -Condition ((Get-ArrayCount -Value $mixed.Diagnostic.stderrContent) -eq 1) -Message 'Stderr misto deveria preservar uma linha real em stderrContent.'
    Assert-True -Condition ([string]$mixed.Diagnostic.stderrContent[0] -eq 'ERRO REAL: detalhe preservado') -Message 'A linha real do stderr misto foi perdida ou alterada.'
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
