#requires -Version 7.4

<#
.SYNOPSIS
Executa importação real de XPZ e, somente se apta, BuildAll pos-import.

.DESCRIPTION
Wrapper integrador simples para reduzir a rodada operacional import -> build.
O script chama Invoke-GeneXusXpzImport.ps1 em processo PowerShell separado,
le o JSON de importação e só chama Invoke-GeneXusKbBuildAll.ps1 quando o
import está apto para build.

Se a importação falhar, bloquear, produzir Categoria B ou não gerar JSON
interpretavel, o build não e executado. A saida final e um JSON único com
importJson, buildJson, roundtripStatus e buildSkippedReason.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [Alias('XpzPath', 'Path')]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$VersionName,

    [string]$EnvironmentName,

    [string]$UpdateFilePath,

    [string]$IncludeItems,

    [string]$ExcludeItems,

    [ValidateSet('true', 'false')]
    [string]$AutomaticBackup = 'false',

    [ValidateSet('AllObjects', 'DifferentObject', 'NewerObjects')]
    [string]$ImportType = 'AllObjects',

    [ValidateSet('Update', 'Keep', 'ReplaceAll')]
    [string]$LanguageTranslations = 'Keep',

    [ValidateSet('true', 'false')]
    [string]$RedefineExternalPrograms = 'false',

    [ValidateSet('true', 'false')]
    [string]$ImportKbInformation = 'false',

    [ValidateSet('true', 'false')]
    [string]$ForceRebuild = 'false',

    [ValidateSet('true', 'false')]
    [string]$CompileMains = 'false',

    [ValidateSet('true', 'false')]
    [string]$DetailedNavigation = 'false',

    [ValidateSet('Release', 'Debug', 'Performance Test')]
    [string]$Configuration,

    [ValidateSet('true', 'false')]
    [string]$FailIfReorg = 'true',

    [ValidateSet('true', 'false')]
    [string]$DoNotExecuteReorg = 'false',

    [switch]$AllowReorg,

    [switch]$ConfirmReorg,

    [switch]$AllowWideRebuild,

    [switch]$ConfirmWideRebuild,

    [switch]$AllowCostlyBuildOptions,

    [switch]$ConfirmCostlyBuildOptions,

    [int]$TimeoutSeconds = 0,

    [switch]$PostImportDeployValidation,

    [switch]$SkipDeployBinCheck,

    [switch]$StrictDeployBinCheck,

    [string]$ParallelKbRoot,

    [string]$IndexPath,

    [string]$CatalogOverridePath,

    [string]$KbMetadataPath,

    [switch]$VerboseLog,

    [switch]$StartWatcher,

    [string]$ImportMonitorLogPath,

    [string]$BuildMonitorLogPath,

    [ValidateRange(1, 60)]
    [int]$WatcherIntervalSeconds = 5,

    [ValidateRange(30, 3600)]
    [int]$WatcherSilenceThresholdSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$logPathGateSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildLogPathSupport.ps1'
if (-not (Test-Path -LiteralPath $logPathGateSupportPath -PathType Leaf)) {
    throw "LogPath gate support script not found: $logPathGateSupportPath"
}
. $logPathGateSupportPath

$categoryBSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildCategoryBSupport.ps1'
if (-not (Test-Path -LiteralPath $categoryBSupportPath -PathType Leaf)) {
    throw "Category B support script not found: $categoryBSupportPath"
}
. $categoryBSupportPath

$script:StrategyTrace = @()
$script:Warnings = @()
$script:BlockingReasons = @()


function ConvertTo-JsonText {
    param([object]$InputObject)

    return ($InputObject | ConvertTo-Json -Depth 12)
}

function Write-JsonLog {
    param(
        [string]$TargetLogPath,
        [string]$JsonPayload
    )

    $parent = Split-Path -Parent $TargetLogPath
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }

    [System.IO.File]::WriteAllText($TargetLogPath, $JsonPayload + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
}

function Add-StrategyTrace {
    param([string]$Message)

    $script:StrategyTrace += $Message
}

function Add-WarningMessage {
    param([string]$Message)

    $script:Warnings += $Message
}

function Add-BlockingReason {
    param([string]$Reason)

    $script:BlockingReasons += $Reason
}

function Get-FullPathSafe {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    return [System.IO.Path]::GetFullPath($PathValue)
}

function Test-IsUnderProgramFilesX86 {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $false
    }

    $programFilesX86 = [System.IO.Path]::GetFullPath('C:\Program Files (x86)').TrimEnd([char[]]@('\', '/'))
    $fullPath = [System.IO.Path]::GetFullPath($PathValue).TrimEnd([char[]]@('\', '/'))
    return $fullPath.StartsWith($programFilesX86, [System.StringComparison]::OrdinalIgnoreCase)
}

function Write-JsonLogIfSafe {
    param(
        [string]$TargetLogPath,
        [string]$JsonPayload
    )

    if ([string]::IsNullOrWhiteSpace($TargetLogPath) -or (Test-IsUnderProgramFilesX86 -PathValue $TargetLogPath)) {
        return
    }

    Write-JsonLog -TargetLogPath $TargetLogPath -JsonPayload $JsonPayload
}

function New-RoundtripArtifactDirectory {
    param([string]$BaseDirectory)

    $resolvedBaseDirectory = Get-FullPathSafe -PathValue $BaseDirectory
    [System.IO.Directory]::CreateDirectory($resolvedBaseDirectory) | Out-Null
    $artifactDirectory = Join-Path $resolvedBaseDirectory ('gx-import-then-build-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function Add-ArgumentPair {
    param(
        [System.Collections.Generic.List[string]]$Arguments,
        [string]$Name,
        [object]$Value
    )

    $Arguments.Add($Name)
    $Arguments.Add([string]$Value)
}

function Add-OptionalArgumentPair {
    param(
        [System.Collections.Generic.List[string]]$Arguments,
        [string]$Name,
        [object]$Value
    )

    if ($null -eq $Value) {
        return
    }

    $stringValue = [string]$Value
    if ([string]::IsNullOrWhiteSpace($stringValue)) {
        return
    }

    Add-ArgumentPair -Arguments $Arguments -Name $Name -Value $stringValue
}

function Add-SwitchArgument {
    param(
        [System.Collections.Generic.List[string]]$Arguments,
        [string]$Name,
        [bool]$Enabled
    )

    if ($Enabled) {
        $Arguments.Add($Name)
    }
}

function Read-TextFileSafe {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue) -or -not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
        return ''
    }

    return [System.IO.File]::ReadAllText($PathValue)
}

function Read-JsonFileSafe {
    param([string]$PathValue)

    $result = [ordered]@{
        ok = $false
        value = $null
        error = $null
    }

    if ([string]::IsNullOrWhiteSpace($PathValue) -or -not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
        $result.error = 'json-log-not-found'
        return $result
    }

    try {
        $text = [System.IO.File]::ReadAllText($PathValue)
        $result.value = ($text | ConvertFrom-Json)
        $result.ok = $true
    } catch {
        $result.error = $_.Exception.Message
    }

    return $result
}

function Invoke-RoundtripChildScript {
    param(
        [string]$ScriptPath,
        [System.Collections.Generic.List[string]]$ScriptArguments,
        [string]$StdOutPath,
        [string]$StdErrPath
    )

    $pwshArguments = [System.Collections.Generic.List[string]]::new()
    $pwshArguments.Add('-NoProfile')
    $pwshArguments.Add('-File')
    $pwshArguments.Add($ScriptPath)
    foreach ($argument in $ScriptArguments) {
        $pwshArguments.Add($argument)
    }

    $process = Start-Process `
        -FilePath 'pwsh' `
        -ArgumentList $pwshArguments `
        -WorkingDirectory (Split-Path -Parent $ScriptPath) `
        -RedirectStandardOutput $StdOutPath `
        -RedirectStandardError $StdErrPath `
        -NoNewWindow `
        -PassThru `
        -Wait

    return [ordered]@{
        exitCode = [int]$process.ExitCode
        stdoutPath = $StdOutPath
        stderrPath = $StdErrPath
        stdoutText = (Read-TextFileSafe -PathValue $StdOutPath)
        stderrText = (Read-TextFileSafe -PathValue $StdErrPath)
    }
}

function Get-JsonPropertyValue {
    param(
        [object]$JsonObject,
        [string]$Name
    )

    if ($null -eq $JsonObject -or $null -eq $JsonObject.PSObject.Properties[$Name]) {
        return $null
    }

    return $JsonObject.PSObject.Properties[$Name].Value
}

function Get-JsonArrayCount {
    param(
        [object]$JsonObject,
        [string]$Name
    )

    $value = Get-JsonPropertyValue -JsonObject $JsonObject -Name $Name
    if ($null -eq $value) {
        return 0
    }

    return @($value).Count
}

function Test-ImportReadyForBuild {
    param(
        [object]$ImportJson,
        [bool]$ImportJsonParsed,
        [int]$ImportProcessExitCode
    )

    $reasons = @()

    if (-not $ImportJsonParsed -or $null -eq $ImportJson) {
        $reasons += 'import-json-indisponivel-ou-invalido'
    } else {
        $exitCodeValue = Get-JsonPropertyValue -JsonObject $ImportJson -Name 'exitCode'
        $exitCode = if ($null -ne $exitCodeValue) { [int]$exitCodeValue } else { $ImportProcessExitCode }
        if ($exitCode -ne 0) {
            $reasons += ('import-exit-code-{0}' -f $exitCode)
        }

        if ((Get-JsonArrayCount -JsonObject $ImportJson -Name 'blockingReasons') -gt 0) {
            $reasons += 'import-blocking-reasons-presentes'
        }

        $categoryBValue = Get-JsonPropertyValue -JsonObject $ImportJson -Name 'msBuildCategoryBBlocked'
        if ($null -ne $categoryBValue -and [bool]$categoryBValue) {
            $reasons += 'import-msbuild-categoria-b'
        }

        $statusValue = [string](Get-JsonPropertyValue -JsonObject $ImportJson -Name 'status')
        if ($statusValue -match '^(falha|não apto|bloqueado)') {
            $reasons += ('import-status-{0}' -f $statusValue)
        }
    }

    if ($ImportProcessExitCode -ne 0 -and $reasons.Count -eq 0) {
        $reasons += ('import-process-exit-code-{0}' -f $ImportProcessExitCode)
    }

    return [ordered]@{
        ready = ($reasons.Count -eq 0)
        reasons = @($reasons)
    }
}

function New-ImportArguments {
    param(
        [string]$ImportWorkingDirectory,
        [string]$ImportLogPath,
        [string]$EffectiveImportMonitorLogPath
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    Add-ArgumentPair -Arguments $arguments -Name '-KbPath' -Value $KbPath
    Add-ArgumentPair -Arguments $arguments -Name '-InputPath' -Value $InputPath
    Add-ArgumentPair -Arguments $arguments -Name '-WorkingDirectory' -Value $ImportWorkingDirectory
    Add-ArgumentPair -Arguments $arguments -Name '-LogPath' -Value $ImportLogPath
    Add-OptionalArgumentPair -Arguments $arguments -Name '-GeneXusDir' -Value $GeneXusDir
    Add-OptionalArgumentPair -Arguments $arguments -Name '-MsBuildPath' -Value $MsBuildPath
    Add-OptionalArgumentPair -Arguments $arguments -Name '-VersionName' -Value $VersionName
    Add-OptionalArgumentPair -Arguments $arguments -Name '-EnvironmentName' -Value $EnvironmentName
    Add-OptionalArgumentPair -Arguments $arguments -Name '-UpdateFilePath' -Value $UpdateFilePath
    Add-OptionalArgumentPair -Arguments $arguments -Name '-IncludeItems' -Value $IncludeItems
    Add-OptionalArgumentPair -Arguments $arguments -Name '-ExcludeItems' -Value $ExcludeItems
    Add-ArgumentPair -Arguments $arguments -Name '-AutomaticBackup' -Value $AutomaticBackup
    Add-ArgumentPair -Arguments $arguments -Name '-ImportType' -Value $ImportType
    Add-ArgumentPair -Arguments $arguments -Name '-LanguageTranslations' -Value $LanguageTranslations
    Add-ArgumentPair -Arguments $arguments -Name '-RedefineExternalPrograms' -Value $RedefineExternalPrograms
    Add-ArgumentPair -Arguments $arguments -Name '-ImportKbInformation' -Value $ImportKbInformation
    Add-SwitchArgument -Arguments $arguments -Name '-VerboseLog' -Enabled $VerboseLog.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-StartWatcher' -Enabled $StartWatcher.IsPresent
    Add-OptionalArgumentPair -Arguments $arguments -Name '-MonitorLogPath' -Value $EffectiveImportMonitorLogPath
    Add-ArgumentPair -Arguments $arguments -Name '-WatcherIntervalSeconds' -Value $WatcherIntervalSeconds
    Add-ArgumentPair -Arguments $arguments -Name '-WatcherSilenceThresholdSeconds' -Value $WatcherSilenceThresholdSeconds
    Add-OptionalArgumentPair -Arguments $arguments -Name '-ParallelKbRoot' -Value $ParallelKbRoot
    Add-OptionalArgumentPair -Arguments $arguments -Name '-IndexPath' -Value $IndexPath
    Add-OptionalArgumentPair -Arguments $arguments -Name '-CatalogOverridePath' -Value $CatalogOverridePath
    return $arguments
}

function New-BuildArguments {
    param(
        [string]$BuildWorkingDirectory,
        [string]$BuildLogPath,
        [string]$EffectiveBuildMonitorLogPath
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    Add-ArgumentPair -Arguments $arguments -Name '-KbPath' -Value $KbPath
    Add-ArgumentPair -Arguments $arguments -Name '-WorkingDirectory' -Value $BuildWorkingDirectory
    Add-ArgumentPair -Arguments $arguments -Name '-LogPath' -Value $BuildLogPath
    Add-OptionalArgumentPair -Arguments $arguments -Name '-GeneXusDir' -Value $GeneXusDir
    Add-OptionalArgumentPair -Arguments $arguments -Name '-MsBuildPath' -Value $MsBuildPath
    Add-OptionalArgumentPair -Arguments $arguments -Name '-VersionName' -Value $VersionName
    Add-OptionalArgumentPair -Arguments $arguments -Name '-EnvironmentName' -Value $EnvironmentName
    Add-ArgumentPair -Arguments $arguments -Name '-ForceRebuild' -Value $ForceRebuild
    Add-ArgumentPair -Arguments $arguments -Name '-CompileMains' -Value $CompileMains
    Add-ArgumentPair -Arguments $arguments -Name '-DetailedNavigation' -Value $DetailedNavigation
    Add-OptionalArgumentPair -Arguments $arguments -Name '-Configuration' -Value $Configuration
    Add-ArgumentPair -Arguments $arguments -Name '-FailIfReorg' -Value $FailIfReorg
    Add-ArgumentPair -Arguments $arguments -Name '-DoNotExecuteReorg' -Value $DoNotExecuteReorg
    Add-SwitchArgument -Arguments $arguments -Name '-AllowReorg' -Enabled $AllowReorg.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-ConfirmReorg' -Enabled $ConfirmReorg.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-AllowWideRebuild' -Enabled $AllowWideRebuild.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-ConfirmWideRebuild' -Enabled $ConfirmWideRebuild.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-AllowCostlyBuildOptions' -Enabled $AllowCostlyBuildOptions.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-ConfirmCostlyBuildOptions' -Enabled $ConfirmCostlyBuildOptions.IsPresent
    Add-ArgumentPair -Arguments $arguments -Name '-TimeoutSeconds' -Value $TimeoutSeconds
    Add-OptionalArgumentPair -Arguments $arguments -Name '-MonitorLogPath' -Value $EffectiveBuildMonitorLogPath
    Add-SwitchArgument -Arguments $arguments -Name '-StartWatcher' -Enabled $StartWatcher.IsPresent
    Add-ArgumentPair -Arguments $arguments -Name '-WatcherIntervalSeconds' -Value $WatcherIntervalSeconds
    Add-ArgumentPair -Arguments $arguments -Name '-WatcherSilenceThresholdSeconds' -Value $WatcherSilenceThresholdSeconds
    Add-SwitchArgument -Arguments $arguments -Name '-VerboseLog' -Enabled $VerboseLog.IsPresent
    Add-OptionalArgumentPair -Arguments $arguments -Name '-ParallelKbRoot' -Value $ParallelKbRoot
    Add-OptionalArgumentPair -Arguments $arguments -Name '-KbMetadataPath' -Value $KbMetadataPath
    Add-SwitchArgument -Arguments $arguments -Name '-PostImportDeployValidation' -Enabled $PostImportDeployValidation.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-SkipDeployBinCheck' -Enabled $SkipDeployBinCheck.IsPresent
    Add-SwitchArgument -Arguments $arguments -Name '-StrictDeployBinCheck' -Enabled $StrictDeployBinCheck.IsPresent
    return $arguments
}

$resolvedWorkingDirectory = Get-FullPathSafe -PathValue $WorkingDirectory
$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

$logPathRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $resolvedLogPath
if ($logPathRejection.rejected) {
    Write-Output (New-GeneXusMsBuildLogPathBlockJson -WrapperName 'Invoke-GeneXusXpzImportThenBuild.ps1' -ResolvedLogPath $resolvedLogPath -Reason $logPathRejection.reason)
    exit 50
}

try {
    if (Test-IsUnderProgramFilesX86 -PathValue $resolvedWorkingDirectory) {
        Add-BlockingReason -Reason 'WorkingDirectory sob Program Files (x86) nao e permitido.'
        $blocked = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'WorkingDirectory inseguro para roundtrip import-build.'
            exitCode = 46
            stage = 'pre-roundtrip'
            blockingReasons = @($script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($script:StrategyTrace)
        }
        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        Write-JsonLogIfSafe -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        Write-Output $blockedJson
        exit 46
    }

    if (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath) {
        Add-BlockingReason -Reason 'LogPath sob Program Files (x86) nao e permitido.'
        $blocked = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'LogPath inseguro para roundtrip import-build.'
            exitCode = 46
            stage = 'pre-roundtrip'
            blockingReasons = @($script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($script:StrategyTrace)
        }
        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        Write-Output $blockedJson
        exit 46
    }

    $scriptsDirectory = Split-Path -Parent $PSCommandPath
    $importScriptPath = Join-Path $scriptsDirectory 'Invoke-GeneXusXpzImport.ps1'
    $buildScriptPath = Join-Path $scriptsDirectory 'Invoke-GeneXusKbBuildAll.ps1'
    if (-not (Test-Path -LiteralPath $importScriptPath -PathType Leaf)) {
        throw "Import wrapper not found: $importScriptPath"
    }
    if (-not (Test-Path -LiteralPath $buildScriptPath -PathType Leaf)) {
        throw "Build wrapper not found: $buildScriptPath"
    }

    $artifactDirectory = New-RoundtripArtifactDirectory -BaseDirectory $resolvedWorkingDirectory
    $importWorkingDirectory = Join-Path $artifactDirectory 'import'
    $buildWorkingDirectory = Join-Path $artifactDirectory 'build'
    [System.IO.Directory]::CreateDirectory($importWorkingDirectory) | Out-Null
    [System.IO.Directory]::CreateDirectory($buildWorkingDirectory) | Out-Null

    $importLogPath = Join-Path $artifactDirectory 'import.json'
    $buildLogPath = Join-Path $artifactDirectory 'build.json'
    $importStdOutPath = Join-Path $artifactDirectory 'import.wrapper.stdout.log'
    $importStdErrPath = Join-Path $artifactDirectory 'import.wrapper.stderr.log'
    $buildStdOutPath = Join-Path $artifactDirectory 'build.wrapper.stdout.log'
    $buildStdErrPath = Join-Path $artifactDirectory 'build.wrapper.stderr.log'
    $effectiveImportMonitorLogPath = if ([string]::IsNullOrWhiteSpace($ImportMonitorLogPath)) { Join-Path $artifactDirectory 'import.monitor.log' } else { Get-FullPathSafe -PathValue $ImportMonitorLogPath }
    $effectiveBuildMonitorLogPath = if ([string]::IsNullOrWhiteSpace($BuildMonitorLogPath)) { Join-Path $artifactDirectory 'build.monitor.log' } else { Get-FullPathSafe -PathValue $BuildMonitorLogPath }

    Add-StrategyTrace -Message ('Roundtrip import-build iniciado. Artefatos em: {0}' -f $artifactDirectory)
    Add-StrategyTrace -Message 'Executando etapa de importação real.'

    $importArguments = New-ImportArguments -ImportWorkingDirectory $importWorkingDirectory -ImportLogPath $importLogPath -EffectiveImportMonitorLogPath $effectiveImportMonitorLogPath
    $importProcess = Invoke-RoundtripChildScript -ScriptPath $importScriptPath -ScriptArguments $importArguments -StdOutPath $importStdOutPath -StdErrPath $importStdErrPath
    $importJsonRead = Read-JsonFileSafe -PathValue $importLogPath
    $importReadiness = Test-ImportReadyForBuild -ImportJson $importJsonRead.value -ImportJsonParsed $importJsonRead.ok -ImportProcessExitCode ([int]$importProcess.exitCode)

    $buildProcess = $null
    $buildJsonRead = [ordered]@{ ok = $false; value = $null; error = 'build-not-run' }
    $roundtripStatus = 'import-blocked-or-failed'
    $buildSkippedReason = $null
    $exitCode = [int]$importProcess.exitCode

    if (-not $importReadiness.ready) {
        $buildSkippedReason = [ordered]@{
            code = 'import-not-ready-for-build'
            reasons = @($importReadiness.reasons)
        }
        Add-StrategyTrace -Message ('Build não executado: {0}' -f (($importReadiness.reasons) -join '; '))
        if ($exitCode -eq 0) {
            $exitCode = 46
        }
    } else {
        Add-StrategyTrace -Message 'Importação apta para build. Executando BuildAll.'
        $buildArguments = New-BuildArguments -BuildWorkingDirectory $buildWorkingDirectory -BuildLogPath $buildLogPath -EffectiveBuildMonitorLogPath $effectiveBuildMonitorLogPath
        $buildProcess = Invoke-RoundtripChildScript -ScriptPath $buildScriptPath -ScriptArguments $buildArguments -StdOutPath $buildStdOutPath -StdErrPath $buildStdErrPath
        $buildJsonRead = Read-JsonFileSafe -PathValue $buildLogPath
        $exitCode = [int]$buildProcess.exitCode
        $roundtripStatus = Get-GeneXusRoundtripStatus -ExitCode $exitCode -BuildJsonOk $buildJsonRead.ok -BuildJson $buildJsonRead.value
    }

    $summary = switch ($roundtripStatus) {
        'roundtrip-ok' { 'Importação real concluída e BuildAll pós-import concluído com build limpo.' }
        'roundtrip-pendente-confirmacao' { 'Importação real concluída com exit 0, mas sem confirmação de build limpo (status do BuildAll diferente de compilou limpo, ou diagnóstico ilegível). Não tratar como validado; conferir o diagnóstico do BuildAll.' }
        'build-failed-or-blocked' { 'Importação real apta, mas BuildAll pós-import falhou ou bloqueou.' }
        default { 'BuildAll pós-import não foi executado porque a importação não ficou apta para build.' }
    }

    $diagnostic = [ordered]@{
        status = $roundtripStatus
        roundtripStatus = $roundtripStatus
        summary = $summary
        exitCode = $exitCode
        stage = 'import-then-build'
        requestedContext = [ordered]@{
            KbPath = $KbPath
            XpzPath = $InputPath
            VersionName = $VersionName
            EnvironmentName = $EnvironmentName
            StartWatcher = $StartWatcher.IsPresent
            PostImportDeployValidation = $PostImportDeployValidation.IsPresent
        }
        resolvedPaths = [ordered]@{
            WorkingDirectory = $resolvedWorkingDirectory
            LogPath = $resolvedLogPath
            ArtifactDirectory = $artifactDirectory
            ImportLogPath = $importLogPath
            BuildLogPath = $buildLogPath
            ImportMonitorLogPath = $effectiveImportMonitorLogPath
            BuildMonitorLogPath = $effectiveBuildMonitorLogPath
        }
        artifacts = [ordered]@{
            importWrapperStdOutPath = $importStdOutPath
            importWrapperStdErrPath = $importStdErrPath
            buildWrapperStdOutPath = $buildStdOutPath
            buildWrapperStdErrPath = $buildStdErrPath
        }
        importProcess = [ordered]@{
            exitCode = [int]$importProcess.exitCode
            stdoutPath = $importProcess.stdoutPath
            stderrPath = $importProcess.stderrPath
            jsonParsed = $importJsonRead.ok
            jsonReadError = $importJsonRead.error
        }
        buildProcess = if ($null -eq $buildProcess) {
            $null
        } else {
            [ordered]@{
                exitCode = [int]$buildProcess.exitCode
                stdoutPath = $buildProcess.stdoutPath
                stderrPath = $buildProcess.stderrPath
                jsonParsed = $buildJsonRead.ok
                jsonReadError = $buildJsonRead.error
            }
        }
        importReadyForBuild = $importReadiness
        buildSkippedReason = $buildSkippedReason
        importJson = $importJsonRead.value
        buildJson = $buildJsonRead.value
        blockingReasons = @($script:BlockingReasons)
        warnings = @($script:Warnings)
        strategyTrace = @($script:StrategyTrace)
    }

    $json = ConvertTo-JsonText -InputObject $diagnostic
    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $exitCode
} catch {
    $failure = [ordered]@{
        status = 'falha operacional'
        summary = 'Falha interna do wrapper import-build antes de concluir a rodada.'
        exitCode = 90
        stage = 'import-then-build'
        error = $_.Exception.Message
        blockingReasons = @($script:BlockingReasons)
        warnings = @($script:Warnings)
        strategyTrace = @($script:StrategyTrace)
    }

    $failureJson = ConvertTo-JsonText -InputObject $failure
    if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath)) {
        Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $failureJson
    }
    Write-Output $failureJson
    exit 90
}
