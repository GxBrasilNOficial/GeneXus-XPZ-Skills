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
        [AllowNull()][string]$StdOutPath,
        [string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($StdOutPath)) {
        return
    }

    $artifactDirectory = Split-Path -Parent $StdOutPath
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

function Invoke-RecoveryScenario {
    param(
        [string]$ScenarioRoot,
        [bool]$EmitBuildAllDone
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

    $noise = "context [anonymous] 1:12 attribute component isn't defined"
    $cmdLines = @(
        '@echo off',
        'echo __KB_OPEN__=true',
        "echo The active environment is 'TestEnvironment'",
        'echo ^> Build All Task Sucesso',
        'echo ========== Build All Task terminado =========='
    )
    if ($EmitBuildAllDone) {
        $cmdLines += 'echo __BUILDALL_DONE__=true'
    }
    foreach ($line in @($noise, $noise, $noise)) {
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
        -EnvironmentName 'TestEnvironment' `
        -SelfTestForceOuterRecovery
    $wrapperExitCode = $LASTEXITCODE
    $jsonText = @($wrapperOutput) -join [Environment]::NewLine

    return [ordered]@{
        ExitCode   = $wrapperExitCode
        JsonText   = $jsonText
        Diagnostic = ($jsonText | ConvertFrom-Json -Depth 16)
    }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-buildall-recovery-selftest-' + [System.Guid]::NewGuid().ToString('N'))
$artifactDirectories = New-Object System.Collections.Generic.List[string]

try {
    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

    $complete = Invoke-RecoveryScenario -ScenarioRoot (Join-Path $testRoot 'complete') -EmitBuildAllDone $true
    $artifactDirectories.Add([string]$complete.Diagnostic.executionEvidence.StdOutPath)

    Assert-True -Condition ($complete.Diagnostic -isnot [string]) -Message 'Recovery deve devolver JSON parseável.'
    Assert-True -Condition ($complete.ExitCode -eq 0) -Message "Recovery com evidência completa deveria encerrar com exit 0; recebeu $($complete.ExitCode)."
    Assert-True -Condition ($complete.Diagnostic.executionEvidence.msBuildExitCode -eq 0) -Message 'Recovery deve preservar executionEvidence.msBuildExitCode=0.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$complete.Diagnostic.executionEvidence.StdOutPath)) -Message 'Recovery deve preservar executionEvidence.StdOutPath.'
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$complete.Diagnostic.executionEvidence.StdErrPath)) -Message 'Recovery deve preservar executionEvidence.StdErrPath.'
    Assert-True -Condition ($complete.Diagnostic.observedContext.KbOpen -eq $true) -Message 'Recovery deve recuperar KbOpen=true do stdout bruto.'
    Assert-True -Condition ($complete.Diagnostic.observedContext.BuildAllDone -eq $true) -Message 'Recovery deve recuperar BuildAllDone=true do stdout bruto.'
    Assert-True -Condition ((Get-ArrayCount -Value $complete.Diagnostic.stderrFilteredNoise) -eq 3) -Message 'Recovery deve preservar as três linhas conhecidas em stderrFilteredNoise.'
    Assert-True -Condition ((Get-ArrayCount -Value $complete.Diagnostic.stderrContent) -eq 0) -Message 'Recovery deve deixar stderrContent vazio quando só houver ruído conhecido.'
    Assert-True -Condition ($complete.Diagnostic.postProcessingFailed -eq $true) -Message 'Recovery deve marcar postProcessingFailed=true.'
    Assert-True -Condition ([string]$complete.Diagnostic.postProcessingError -match 'SELFTEST: falha artificial') -Message 'Recovery deve preservar a causa artificial controlada.'
    Assert-True -Condition ($complete.Diagnostic.status -eq 'compilou limpo com falha no pos-processamento') -Message 'Recovery com evidência completa deve declarar sucesso operacional com falha de pós-processamento.'
    Assert-True -Condition ($complete.Diagnostic.exitCode -eq 0 -and $complete.Diagnostic.executionEvidence.wrapperExitCode -eq 0) -Message 'Recovery não pode trocar sucesso operacional completo por exitCode=90.'

    $incomplete = Invoke-RecoveryScenario -ScenarioRoot (Join-Path $testRoot 'missing-marker') -EmitBuildAllDone $false
    $artifactDirectories.Add([string]$incomplete.Diagnostic.executionEvidence.StdOutPath)

    Assert-True -Condition ($incomplete.Diagnostic.executionEvidence.msBuildExitCode -eq 0) -Message 'Cenário negativo ainda deve preservar o MSBuild limpo.'
    Assert-True -Condition ($incomplete.Diagnostic.observedContext.BuildAllDone -eq $false) -Message 'Cenário negativo deve manter BuildAllDone=false.'
    Assert-True -Condition ($incomplete.Diagnostic.status -ne 'compilou limpo com falha no pos-processamento') -Message 'Recovery não pode promover evidência sem BuildAllDone a sucesso limpo degradado.'
    Assert-True -Condition ($incomplete.Diagnostic.postProcessingFailed -eq $true) -Message 'Cenário negativo deve continuar identificado como falha de pós-processamento.'
}
finally {
    foreach ($stdOutPath in $artifactDirectories) {
        try {
            Remove-WrapperArtifactDirectory -StdOutPath $stdOutPath -RepositoryRoot $repositoryRoot
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }

    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Output 'GENEXUS_MSBUILD_BUILDALL_RECOVERY_SELFTEST_OK'
