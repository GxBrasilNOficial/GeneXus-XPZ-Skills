#requires -Version 7.4

<#
.SYNOPSIS
    E2E in-repo dos wrappers Export/Import/Preview com MSBuild falso, GeneXusDir falso e
    assembly sintetica minima (fixtures/msbuild-e2e/SyntheticGeneXusMsBuildTasks.cs).

.DESCRIPTION
    Passa pelo probe real e pela reflexao de Genexus.MsBuild.Tasks.dll (dai a assembly sintetica).
    Cobre: teste decisivo dos sinais (observedContext = compactSignals = arquivo de sinais; uma
    leitura + troca pedida + sem falha de Set => efetivo nulo), troca bem-sucedida, Set falho com
    bloqueio citando a abertura, exits preservados (41/31) e assercao estrutural no .msbuild.
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

$fixtureSourcePath = Join-Path $PSScriptRoot 'fixtures\msbuild-e2e\SyntheticGeneXusMsBuildTasks.cs'
if (-not (Test-Path -LiteralPath $fixtureSourcePath -PathType Leaf)) {
    throw "Fixture C# nao encontrada: $fixtureSourcePath"
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-wrappers-e2e-selftest-' + [System.Guid]::NewGuid().ToString('N'))
$syntheticDllPath = Join-Path $testRoot 'Genexus.MsBuild.Tasks.dll'

function Invoke-WrapperScenario {
    param(
        [ValidateSet('Export', 'Import', 'Preview')][string]$Wrapper,
        [string]$ScenarioRoot,
        [string[]]$StdOutCmdLines = @(),
        [string[]]$StdErrCmdLines = @(),
        [int]$FakeExitCode = 0,
        [string]$EnvironmentName
    )

    $fakeGeneXusDirectory = Join-Path $ScenarioRoot 'GeneXus'
    $fakeKbDirectory = Join-Path $ScenarioRoot 'Kb'
    $workingDirectory = Join-Path $ScenarioRoot 'work'
    $logPath = Join-Path $ScenarioRoot 'result.json'
    $fakeMsBuildPath = Join-Path $ScenarioRoot 'fake-msbuild.cmd'

    foreach ($directory in @($fakeGeneXusDirectory, $fakeKbDirectory, $workingDirectory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }

    [System.IO.File]::WriteAllText((Join-Path $fakeGeneXusDirectory 'Genexus.Tasks.targets'), '<Project />', [System.Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath $syntheticDllPath -Destination (Join-Path $fakeGeneXusDirectory 'Genexus.MsBuild.Tasks.dll') -Force

    $cmdLines = @('@echo off') + $StdOutCmdLines + $StdErrCmdLines + @('exit /b {0}' -f $FakeExitCode)
    [System.IO.File]::WriteAllText($fakeMsBuildPath, ($cmdLines -join "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)

    # Pacote de entrada (Import/Preview) e/ou saida previa (Export) existente.
    $xpzPath = Join-Path $workingDirectory 'pkg.xpz'
    [System.IO.File]::WriteAllText($xpzPath, 'dummy', [System.Text.UTF8Encoding]::new($false))

    $wrapperArgs = @{
        KbPath           = $fakeKbDirectory
        WorkingDirectory = $workingDirectory
        LogPath          = $logPath
        GeneXusDir       = $fakeGeneXusDirectory
        MsBuildPath      = $fakeMsBuildPath
    }
    switch ($Wrapper) {
        'Export' {
            $wrapperPath = Join-Path $PSScriptRoot 'Invoke-GeneXusXpzExport.ps1'
            $wrapperArgs.XpzPath = $xpzPath
            $wrapperArgs.ExportAll = 'true'
        }
        'Import' {
            $wrapperPath = Join-Path $PSScriptRoot 'Invoke-GeneXusXpzImport.ps1'
            $wrapperArgs.InputPath = $xpzPath
        }
        'Preview' {
            $wrapperPath = Join-Path $PSScriptRoot 'Test-GeneXusXpzImportPreview.ps1'
            $wrapperArgs.InputPath = $xpzPath
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName)) { $wrapperArgs.EnvironmentName = $EnvironmentName }

    $wrapperOutput = & $wrapperPath @wrapperArgs
    $wrapperExitCode = $LASTEXITCODE
    $jsonText = @($wrapperOutput) -join [Environment]::NewLine

    return [ordered]@{
        ExitCode   = $wrapperExitCode
        Diagnostic = ($jsonText | ConvertFrom-Json -Depth 20)
    }
}

function Get-SignalsFilePath {
    param($Diagnostic, [string]$Wrapper)
    if ($Wrapper -eq 'Export') { return [string]$Diagnostic.artifacts.ExportSignalsPath }
    return [string]$Diagnostic.artifacts.SignalsPath
}

function Get-CompactSignals {
    # Export expoe compactSignals no topo; Import/Preview o aninham em stdoutSignals.compactSignals.
    param($Diagnostic, [string]$Wrapper)
    if ($Diagnostic.PSObject.Properties['compactSignals'] -and $null -ne $Diagnostic.compactSignals) { return $Diagnostic.compactSignals }
    if ($Diagnostic.PSObject.Properties['stdoutSignals'] -and $Diagnostic.stdoutSignals.PSObject.Properties['compactSignals'] -and $null -ne $Diagnostic.stdoutSignals.compactSignals) { return $Diagnostic.stdoutSignals.compactSignals }
    throw "[$Wrapper] compactSignals nao encontrado no diagnostico."
}

function Assert-DecisiveSignals {
    param($Diagnostic, [string]$Wrapper, [string]$ExpectedAtOpen)

    Assert-True -Condition ($null -eq $Diagnostic.observedContext.ActiveEnvironment) -Message ("[$Wrapper] observedContext.ActiveEnvironment deveria ser nulo (troca sem leitura posterior); recebeu '{0}'." -f $Diagnostic.observedContext.ActiveEnvironment)
    Assert-True -Condition ([string]$Diagnostic.observedContext.ActiveEnvironmentAtOpen -eq $ExpectedAtOpen) -Message ("[$Wrapper] observedContext.ActiveEnvironmentAtOpen deveria ser '{0}'." -f $ExpectedAtOpen)

    $compactSignals = Get-CompactSignals -Diagnostic $Diagnostic -Wrapper $Wrapper
    Assert-True -Condition ($null -eq $compactSignals.activeEnvironment) -Message ("[$Wrapper] compactSignals.activeEnvironment deveria ser nulo." -f $compactSignals.activeEnvironment)
    Assert-True -Condition ([string]$compactSignals.activeEnvironmentAtOpen -eq $ExpectedAtOpen) -Message ("[$Wrapper] compactSignals.activeEnvironmentAtOpen deveria ser '{0}'." -f $ExpectedAtOpen)

    $signalsFilePath = Get-SignalsFilePath -Diagnostic $Diagnostic -Wrapper $Wrapper
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($signalsFilePath) -and (Test-Path -LiteralPath $signalsFilePath -PathType Leaf)) -Message ("[$Wrapper] arquivo de sinais ausente: {0}" -f $signalsFilePath)
    $fileSignals = [System.IO.File]::ReadAllText($signalsFilePath) | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($null -eq $fileSignals.activeEnvironment) -Message "[$Wrapper] arquivo de sinais: activeEnvironment deveria ser nulo."
    Assert-True -Condition ([string]$fileSignals.activeEnvironmentAtOpen -eq $ExpectedAtOpen) -Message ("[$Wrapper] arquivo de sinais: activeEnvironmentAtOpen deveria ser '{0}'." -f $ExpectedAtOpen)
}

try {
    [System.IO.Directory]::CreateDirectory($testRoot) | Out-Null
    Add-Type -TypeDefinition ([System.IO.File]::ReadAllText($fixtureSourcePath)) -OutputAssembly $syntheticDllPath

    $decisiveLines = @("echo The active environment is 'EnvOpen'")

    # Teste decisivo dos sinais nos tres wrappers.
    foreach ($wrapper in @('Export', 'Import', 'Preview')) {
        $result = Invoke-WrapperScenario -Wrapper $wrapper -ScenarioRoot (Join-Path $testRoot ("decisive-" + $wrapper.ToLower())) -EnvironmentName 'EnvRequested' -StdOutCmdLines $decisiveLines
        Assert-True -Condition ($result.ExitCode -eq 0) -Message ("[$wrapper] decisivo deveria dar exit 0; recebeu {0} ({1})." -f $result.ExitCode, $result.Diagnostic.summary)
        Assert-DecisiveSignals -Diagnostic $result.Diagnostic -Wrapper $wrapper -ExpectedAtOpen 'EnvOpen'
    }

    # Troca bem-sucedida (Export): efetivo = leitura posterior; AtOpen = abertura.
    $exportSwap = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'swap-export') -EnvironmentName 'EnvB' -StdOutCmdLines @(
        "echo The active environment is 'EnvA'",
        'echo ^> Set Active Environment Sucesso',
        "echo The active environment is 'EnvB'"
    )
    Assert-True -Condition ($exportSwap.ExitCode -eq 0) -Message ("[Export] troca OK deveria dar exit 0; recebeu {0}." -f $exportSwap.ExitCode)
    Assert-True -Condition ([string]$exportSwap.Diagnostic.observedContext.ActiveEnvironment -eq 'EnvB') -Message ("[Export] ActiveEnvironment deveria ser 'EnvB'.")
    Assert-True -Condition ([string]$exportSwap.Diagnostic.observedContext.ActiveEnvironmentAtOpen -eq 'EnvA') -Message "[Export] ActiveEnvironmentAtOpen deveria ser 'EnvA'."

    # Estrutural no .msbuild do Export: Get(AtOpen) antes do Set; Set antes do Get efetivo.
    $exportMsBuild = [System.IO.File]::ReadAllText([string]$exportSwap.Diagnostic.artifacts.MsBuildFilePath)
    $firstGet = $exportMsBuild.IndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    $set = $exportMsBuild.IndexOf('<SetActiveEnvironment', [System.StringComparison]::Ordinal)
    $lastGet = $exportMsBuild.LastIndexOf('<GetActiveEnvironment', [System.StringComparison]::Ordinal)
    Assert-True -Condition ($firstGet -ge 0 -and $firstGet -lt $set -and $set -lt $lastGet) -Message '[Export] ordem Get -> Set -> Get esperada no .msbuild.'

    # Set falho: bloqueio cita a abertura; exits preservados (41 Export / 31 Import-Preview).
    $exportSetFailed = Invoke-WrapperScenario -Wrapper 'Export' -ScenarioRoot (Join-Path $testRoot 'set-failed-export') -EnvironmentName 'EnvRequested' -FakeExitCode 1 -StdOutCmdLines @(
        "echo The active environment is 'EnvOpen'",
        "echo Ambiente 'EnvRequested' nao existe",
        'echo error : ^> Set Active Environment falhou'
    )
    Assert-True -Condition ($exportSetFailed.ExitCode -eq 41) -Message ("[Export] Set falho + MSBuild != 0 deveria preservar exit 41; recebeu {0}." -f $exportSetFailed.ExitCode)
    $exportReason = @($exportSetFailed.Diagnostic.blockingReasons | Where-Object { [string]$_ -match '^SetActiveEnvironment falhou' })
    Assert-True -Condition ($exportReason.Count -eq 1 -and $exportReason[0] -match "abertura era 'EnvOpen'") -Message ("[Export] bloqueio deveria citar a abertura 'EnvOpen'; recebeu '{0}'." -f ($exportReason -join ' / '))

    foreach ($wrapper in @('Import', 'Preview')) {
        $setFailed = Invoke-WrapperScenario -Wrapper $wrapper -ScenarioRoot (Join-Path $testRoot ("set-failed-" + $wrapper.ToLower())) -EnvironmentName 'EnvRequested' -FakeExitCode 1 -StdOutCmdLines @(
            "echo The active environment is 'EnvOpen'",
            "echo Ambiente 'EnvRequested' nao existe",
            'echo error : ^> Set Active Environment falhou'
        )
        Assert-True -Condition ($setFailed.ExitCode -eq 31) -Message ("[$wrapper] Set falho + MSBuild != 0 deveria preservar exit 31; recebeu {0}." -f $setFailed.ExitCode)
        $reason = @($setFailed.Diagnostic.blockingReasons | Where-Object { [string]$_ -match '^SetActiveEnvironment falhou' })
        Assert-True -Condition ($reason.Count -eq 1 -and $reason[0] -match "abertura era 'EnvOpen'") -Message ("[$wrapper] bloqueio deveria citar a abertura 'EnvOpen'; recebeu '{0}'." -f ($reason -join ' / '))
    }

    # Preview: Open SEM CaptureOutput (preservado).
    $previewOpen = [System.IO.File]::ReadAllText([string](Invoke-WrapperScenario -Wrapper 'Preview' -ScenarioRoot (Join-Path $testRoot 'preview-open') -StdOutCmdLines $decisiveLines).Diagnostic.artifacts.MsBuildFilePath)
    Assert-True -Condition ($previewOpen -match [regex]::Escape('<OpenKnowledgeBase Directory="$(KBPath)" />')) -Message '[Preview] OpenKnowledgeBase deve permanecer sem CaptureOutput.'
}
finally {
    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output 'GENEXUS_MSBUILD_ACTIVE_CONTEXT_WRAPPERS_E2E_SELFTEST_OK'
