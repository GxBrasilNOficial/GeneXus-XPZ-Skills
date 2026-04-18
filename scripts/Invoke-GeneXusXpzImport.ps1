<#
.SYNOPSIS
Executa importação real de XPZ via MSBuild com parâmetros explícitos.

.DESCRIPTION
Implementa a etapa de importação real da frente experimental: reaproveita
o probe Test-GeneXusMsBuildSetup.ps1, abre a KB em modo headless controlado,
posiciona versão e Environment quando informados, executa a task Import sem
PreviewMode e fecha a KB. O script não executa exportação.

.PARAMETER KbPath
Caminho da KB a ser usada na importação.

.PARAMETER XpzPath
Caminho do arquivo XPZ de entrada.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, usa fallback do probe.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, usa fallback do probe.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes da importação.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes da importação.

.PARAMETER UpdateFilePath
Caminho opcional para o UpdateFile gerado pela importação, quando suportado.

.PARAMETER IncludeItems
Lista opcional de objetos a incluir.

.PARAMETER ExcludeItems
Lista opcional de objetos a excluir.

.PARAMETER AutomaticBackup
Valor explícito para AutomaticBackup. Default: false.

.PARAMETER ImportType
Valor explícito para ImportType. Default: AllObjects.

.PARAMETER LanguageTranslations
Valor explícito para LanguageTranslations. Default: Keep.

.PARAMETER RedefineExternalPrograms
Valor explícito para RedefineExternalPrograms. Default: false.

.PARAMETER ImportKbInformation
Valor explícito para ImportKBInformation. Default: false.

.PARAMETER VerboseLog
Amplia o detalhamento gravado no log sem alterar o resultado lógico.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [string]$XpzPath,

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

    [switch]$VerboseLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProgramFilesX86 = [System.IO.Path]::GetFullPath('C:\Program Files (x86)')

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
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

    $fullPath = Get-FullPathSafe -PathValue $PathValue
    $candidate = $fullPath.TrimEnd('\')
    $root = $ProgramFilesX86.TrimEnd('\')
    return $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-JsonText {
    param([object]$InputObject)

    return ($InputObject | ConvertTo-Json -Depth 8)
}

function Write-JsonLog {
    param(
        [string]$TargetLogPath,
        [string]$JsonPayload
    )

    [System.IO.File]::WriteAllText($TargetLogPath, $JsonPayload + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
}

function Add-StrategyTrace {
    param([string]$Message)

    $script:StrategyTrace.Add($Message)
}

function Add-BlockingReason {
    param([string]$Reason)

    if (-not $script:BlockingReasons.Contains($Reason)) {
        $script:BlockingReasons.Add($Reason)
    }
}

function Add-WarningMessage {
    param([string]$Message)

    if (-not $script:Warnings.Contains($Message)) {
        $script:Warnings.Add($Message)
    }
}

function Resolve-ProbeScriptPath {
    $scriptDirectory = Split-Path -Parent $PSCommandPath
    $probePath = Join-Path $scriptDirectory 'Test-GeneXusMsBuildSetup.ps1'
    if (-not (Test-Path -LiteralPath $probePath -PathType Leaf)) {
        throw "Probe script not found: $probePath"
    }
    return $probePath
}

function Invoke-ProbeStage {
    param([string]$ProbeLogPath)

    $probeScriptPath = Resolve-ProbeScriptPath
    $probeArgs = @{
        WorkingDirectory = $WorkingDirectory
        LogPath = $ProbeLogPath
        KbPath = $KbPath
    }

    if (-not [string]::IsNullOrWhiteSpace($GeneXusDir)) {
        $probeArgs.GeneXusDir = $GeneXusDir
    }
    if (-not [string]::IsNullOrWhiteSpace($MsBuildPath)) {
        $probeArgs.MsBuildPath = $MsBuildPath
    }
    if ($VerboseLog.IsPresent) {
        $probeArgs.VerboseLog = $true
    }

    $probeOutput = & $probeScriptPath @probeArgs
    $probeExitCode = $LASTEXITCODE
    $probeJson = ($probeOutput -join [Environment]::NewLine)
    $probeDiagnostic = $probeJson | ConvertFrom-Json -Depth 8

    return [ordered]@{
        ExitCode = $probeExitCode
        Json = $probeJson
        Diagnostic = $probeDiagnostic
    }
}

function Escape-Xml {
    param([string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return [System.Security.SecurityElement]::Escape($Value)
}

function New-ArtifactDirectory {
    $scriptDirectory = Split-Path -Parent $PSCommandPath
    $repositoryRoot = Split-Path -Parent $scriptDirectory
    $tempRoot = Join-Path $repositoryRoot 'Temp'
    $baseDirectory = Join-Path $tempRoot 'xpz-msbuild-import-export'
    [System.IO.Directory]::CreateDirectory($baseDirectory) | Out-Null
    $artifactDirectory = Join-Path $baseDirectory ('gx-import-real-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function Validate-XpzPath {
    $resolved = Get-FullPathSafe -PathValue $XpzPath
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        Add-BlockingReason -Reason ("XpzPath inválido: '{0}'." -f $resolved)
        return [ordered]@{
            Path = $resolved
            Result = 'fail'
            Detail = 'Arquivo XPZ não foi encontrado.'
            ExitCode = 30
        }
    }

    if (-not $resolved.ToLowerInvariant().EndsWith('.xpz')) {
        Add-WarningMessage -Message 'XpzPath informado não termina com extensão .xpz.'
    }

    return [ordered]@{
        Path = $resolved
        Result = 'ok'
        Detail = 'Arquivo XPZ encontrado.'
        ExitCode = 0
    }
}

function Validate-OptionalOutputPath {
    param(
        [string]$PathValue,
        [string]$ReasonPrefix
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return [ordered]@{
            Path = $null
            Result = 'skip'
            Detail = 'Caminho opcional não informado.'
            ExitCode = 0
        }
    }

    $resolved = Get-FullPathSafe -PathValue $PathValue
    $parent = [System.IO.Path]::GetDirectoryName($resolved)

    if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent -PathType Container)) {
        Add-BlockingReason -Reason ($ReasonPrefix -f $resolved)
        return [ordered]@{
            Path = $resolved
            Result = 'fail'
            Detail = 'Diretório pai do caminho opcional não foi encontrado.'
            ExitCode = 32
        }
    }

    if (Test-IsUnderProgramFilesX86 -PathValue $resolved) {
        Add-BlockingReason -Reason ($ReasonPrefix -f $resolved)
        return [ordered]@{
            Path = $resolved
            Result = 'fail'
            Detail = 'Caminho opcional aponta para árvore estritamente somente leitura.'
            ExitCode = 32
        }
    }

    return [ordered]@{
        Path = $resolved
        Result = 'ok'
        Detail = 'Caminho opcional validado.'
        ExitCode = 0
    }
}

function Get-ImportTaskPropertyNames {
    param([string]$ResolvedGeneXusDir)

    $assemblyPath = Join-Path $ResolvedGeneXusDir 'Genexus.MsBuild.Tasks.dll'
    $assembly = [System.Reflection.Assembly]::LoadFrom($assemblyPath)
    $taskType = $assembly.GetType('Genexus.MsBuild.Tasks.Import')
    if ($null -eq $taskType) {
        throw "Import task type not found in assembly: $assemblyPath"
    }

    return @(
        $taskType.GetProperties([System.Reflection.BindingFlags] 'Instance,Public') |
            Select-Object -ExpandProperty Name
    )
}

function Test-ImportTaskSupportsProperty {
    param(
        [string[]]$PropertyNames,
        [string]$PropertyName
    )

    return $PropertyNames -contains $PropertyName
}

function New-MsBuildProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath,
        [string]$ResolvedXpzPath,
        [string]$ResolvedUpdateFilePath,
        [string[]]$ResolvedIncludeItems,
        [string[]]$ResolvedExcludeItems
    )

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEscaped = Escape-Xml -Value $targetsPath
    $kbPathEscaped = Escape-Xml -Value $ResolvedKbPath
    $xpzEscaped = Escape-Xml -Value $ResolvedXpzPath
    $versionEscaped = Escape-Xml -Value $VersionName
    $environmentEscaped = Escape-Xml -Value $EnvironmentName
    $updateEscaped = Escape-Xml -Value $ResolvedUpdateFilePath
    $automaticBackupEscaped = Escape-Xml -Value $AutomaticBackup
    $importTypeEscaped = Escape-Xml -Value $ImportType
    $translationsEscaped = Escape-Xml -Value $LanguageTranslations
    $redefineEscaped = Escape-Xml -Value $RedefineExternalPrograms
    $importKbInfoEscaped = Escape-Xml -Value $ImportKbInformation
    $includeEscaped = Escape-Xml -Value (($ResolvedIncludeItems -join ';'))
    $excludeEscaped = Escape-Xml -Value (($ResolvedExcludeItems -join ';'))

    $optionalAttributes = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($includeEscaped)) {
        $optionalAttributes.Add("      IncludeItems=""`$(IncludeItems)""")
    }
    if (-not [string]::IsNullOrWhiteSpace($excludeEscaped)) {
        $optionalAttributes.Add("      ExcludeItems=""`$(ExcludeItems)""")
    }
    if (-not [string]::IsNullOrWhiteSpace($updateEscaped)) {
        $optionalAttributes.Add("      UpdateFile=""`$(UpdateFilePath)""")
    }
    if ($ImportKbInformation -eq 'true') {
        $optionalAttributes.Add("      ImportKBInformation=""`$(ImportKBInformation)""")
    }

    $optionalAttributesText = ''
    if ($optionalAttributes.Count -gt 0) {
        $optionalAttributesText = [Environment]::NewLine + ($optionalAttributes -join [Environment]::NewLine)
    }

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEscaped" />

  <PropertyGroup>
    <KBPath>$kbPathEscaped</KBPath>
    <XPZPath>$xpzEscaped</XPZPath>
    <KBVersion>$versionEscaped</KBVersion>
    <KBEnvironment>$environmentEscaped</KBEnvironment>
    <UpdateFilePath>$updateEscaped</UpdateFilePath>
    <AutomaticBackup>$automaticBackupEscaped</AutomaticBackup>
    <ImportType>$importTypeEscaped</ImportType>
    <LanguageTranslations>$translationsEscaped</LanguageTranslations>
    <RedefineExternalPrograms>$redefineEscaped</RedefineExternalPrograms>
    <ImportKBInformation>$importKbInfoEscaped</ImportKBInformation>
    <IncludeItems>$includeEscaped</IncludeItems>
    <ExcludeItems>$excludeEscaped</ExcludeItems>
  </PropertyGroup>

  <Target Name="CloseOnError">
    <CloseKnowledgeBase ContinueOnError="WarnAndContinue" />
  </Target>

  <Target Name="Run">
    <OpenKnowledgeBase Directory="`$(KBPath)" CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="OpenOutput" />
    </OpenKnowledgeBase>
    <SetActiveVersion Condition="'`$(KBVersion)' != ''" VersionName="`$(KBVersion)" />
    <SetActiveEnvironment Condition="'`$(KBEnvironment)' != ''" EnvironmentName="`$(KBEnvironment)" />
    <GetActiveVersion CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveVersionOutput" />
    </GetActiveVersion>
    <GetActiveEnvironment CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveEnvironmentOutput" />
    </GetActiveEnvironment>
    <Import
      File="`$(XPZPath)"
      AutomaticBackup="`$(AutomaticBackup)"
      ImportType="`$(ImportType)"
      LanguageTranslations="`$(LanguageTranslations)"
      RedefineExternalPrograms="`$(RedefineExternalPrograms)"
      PreviewMode="false"$optionalAttributesText>
      <Output TaskParameter="ImportedItems" ItemName="ImportedItem" />
    </Import>
    <Message Text="__IMPORTED_ITEM__=%(ImportedItem.Identity)" Importance="High" Condition="'@(ImportedItem)' != ''" />
    <Message Text="__OPEN_OUTPUT__=`$(OpenOutput)" Importance="High" />
    <Message Text="__ACTIVE_VERSION__=`$(ActiveVersionOutput)" Importance="High" />
    <Message Text="__ACTIVE_ENVIRONMENT__=`$(ActiveEnvironmentOutput)" Importance="High" />
    <CloseKnowledgeBase />
    <OnError ExecuteTargets="CloseOnError" />
  </Target>
</Project>
"@
}

function Invoke-MsBuildFile {
    param(
        [string]$ResolvedMsBuildPath,
        [string]$MsBuildFilePath,
        [string]$StdOutPath,
        [string]$StdErrPath
    )

    $arguments = @(
        $MsBuildFilePath,
        '/nologo',
        '/verbosity:minimal',
        '/target:Run'
    )

    Add-StrategyTrace -Message ('MSBuild acionado com alvo Run em: {0}' -f $MsBuildFilePath)
    $process = Start-Process -FilePath $ResolvedMsBuildPath -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $MsBuildFilePath) -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -NoNewWindow -PassThru -Wait
    return $process.ExitCode
}

function Read-TextFileSafe {
    param([string]$PathValue)

    if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) {
        return ''
    }

    return [System.IO.File]::ReadAllText($PathValue)
}

function Get-MarkerValue {
    param(
        [string]$Text,
        [string]$Marker
    )

    $match = [regex]::Match($Text, [regex]::Escape($Marker) + '(.*)')
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim()
}

function Get-RegexValue {
    param(
        [string]$Text,
        [string]$Pattern
    )

    $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups[1].Value.Trim()
}

function Get-TextSummary {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    return @($Text -split "(`r`n|`n|`r)" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 20)
}

function Get-MatchingLines {
    param(
        [string]$Text,
        [string]$Prefix
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    return @(
        $Text -split "(`r`n|`n|`r)" |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_.Trim().StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase) } |
            ForEach-Object { $_.Trim().Substring($Prefix.Length) }
    )
}

function Get-ImportExitCode {
    param(
        [int]$MsBuildExitCode,
        [string]$ResolvedUpdateFilePath
    )

    if ($MsBuildExitCode -eq 0) {
        if (-not [string]::IsNullOrWhiteSpace($ResolvedUpdateFilePath) -and -not (Test-Path -LiteralPath $ResolvedUpdateFilePath -PathType Leaf)) {
            return 32
        }
        return 0
    }

    return 31
}

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace = New-Object System.Collections.Generic.List[string]

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

try {
    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional da importação real.'
    }

    $artifactDirectory = New-ArtifactDirectory
    $probeLogPath = Join-Path $artifactDirectory 'probe-stage.json'
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath
    Add-StrategyTrace -Message ('Probe executado antes da importação real com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe não apto para prosseguir bloqueou a importação real.'
        $probeDiagnostic = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'Probe bloqueou a importação real.'
            exitCode = $probeStage.ExitCode
            stage = 'probe'
            resolvedPaths = [ordered]@{
                GeneXusDir = $probeDiagnostic.resolvedPaths.GeneXusDir
                MsBuildPath = $probeDiagnostic.resolvedPaths.MsBuildPath
                KbPath = $probeDiagnostic.resolvedPaths.KbPath
                XpzPath = (Get-FullPathSafe -PathValue $XpzPath)
                WorkingDirectory = $probeDiagnostic.resolvedPaths.WorkingDirectory
                LogPath = $resolvedLogPath
                UpdateFilePath = (Get-FullPathSafe -PathValue $UpdateFilePath)
            }
            pathActions = $probeDiagnostic.pathActions
            artifacts = [ordered]@{
                ProbeLogPath = $probeLogPath
                MsBuildFilePath = $null
                StdOutPath = $null
                StdErrPath = $null
                ExecutionLogPath = $resolvedLogPath
            }
            importedItems = @()
            blockingReasons = @($probeDiagnostic.blockingReasons + $script:BlockingReasons)
            warnings = @($probeDiagnostic.warnings)
            strategyTrace = @($probeDiagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        }
        Write-Output $blockedJson
        exit $probeStage.ExitCode
    }

    $xpzValidation = Validate-XpzPath
    $updateFileValidation = Validate-OptionalOutputPath -PathValue $UpdateFilePath -ReasonPrefix "UpdateFilePath inválido ou inseguro: '{0}'."
    if ($xpzValidation.ExitCode -ne 0 -or $updateFileValidation.ExitCode -ne 0) {
        $exitCode = if ($xpzValidation.ExitCode -ne 0) { $xpzValidation.ExitCode } else { $updateFileValidation.ExitCode }
        $blockedJsonObject = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'Validação prévia bloqueou a importação real.'
            exitCode = $exitCode
            stage = 'pre-validate'
            resolvedPaths = [ordered]@{
                GeneXusDir = $probeStage.Diagnostic.resolvedPaths.GeneXusDir
                MsBuildPath = $probeStage.Diagnostic.resolvedPaths.MsBuildPath
                KbPath = $probeStage.Diagnostic.resolvedPaths.KbPath
                XpzPath = $xpzValidation.Path
                WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
                LogPath = $resolvedLogPath
                UpdateFilePath = $updateFileValidation.Path
            }
            pathActions = $probeStage.Diagnostic.pathActions
            artifacts = [ordered]@{
                ProbeLogPath = $probeLogPath
                MsBuildFilePath = $null
                StdOutPath = $null
                StdErrPath = $null
                ExecutionLogPath = $resolvedLogPath
            }
            importedItems = @()
            blockingReasons = @($script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blockedJson = ConvertTo-JsonText -InputObject $blockedJsonObject
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        }
        Write-Output $blockedJson
        exit $exitCode
    }

    $resolvedGeneXusDir = [string]$probeStage.Diagnostic.resolvedPaths.GeneXusDir
    $resolvedMsBuildPath = [string]$probeStage.Diagnostic.resolvedPaths.MsBuildPath
    $resolvedKbPath = [string]$probeStage.Diagnostic.resolvedPaths.KbPath
    $resolvedXpzPath = $xpzValidation.Path
    $resolvedUpdateFilePath = $updateFileValidation.Path

    $importTaskPropertyNames = Get-ImportTaskPropertyNames -ResolvedGeneXusDir $resolvedGeneXusDir
    Add-StrategyTrace -Message ('Import task properties carregadas da instalação atual: {0}' -f ($importTaskPropertyNames -join ', '))

    foreach ($candidateProperty in @('File', 'AutomaticBackup', 'ImportType', 'LanguageTranslations', 'RedefineExternalPrograms', 'IncludeItems', 'ExcludeItems', 'PreviewMode')) {
        if (-not (Test-ImportTaskSupportsProperty -PropertyNames $importTaskPropertyNames -PropertyName $candidateProperty)) {
            Add-BlockingReason -Reason ("A instalação atual não expõe a propriedade pública {0} na task Import." -f $candidateProperty)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($UpdateFilePath) -and -not (Test-ImportTaskSupportsProperty -PropertyNames $importTaskPropertyNames -PropertyName 'UpdateFile')) {
        Add-BlockingReason -Reason 'A instalação atual não expõe a propriedade pública UpdateFile na task Import.'
    }

    if ($ImportKbInformation -eq 'true' -and -not (Test-ImportTaskSupportsProperty -PropertyNames $importTaskPropertyNames -PropertyName 'ImportKBInformation')) {
        Add-BlockingReason -Reason 'A instalação atual não expõe a propriedade pública ImportKBInformation na task Import.'
    }

    if ($script:BlockingReasons.Count -gt 0) {
        $unsupported = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'Importação bloqueada porque a task Import não expõe um ou mais parâmetros solicitados.'
            exitCode = 32
            stage = 'task-support'
            requestedContext = [ordered]@{
                VersionName = $VersionName
                EnvironmentName = $EnvironmentName
                ImportType = $ImportType
                LanguageTranslations = $LanguageTranslations
                AutomaticBackup = $AutomaticBackup
                RedefineExternalPrograms = $RedefineExternalPrograms
                ImportKbInformation = $ImportKbInformation
                IncludeItems = $IncludeItems
                ExcludeItems = $ExcludeItems
            }
            resolvedPaths = [ordered]@{
                GeneXusDir = $resolvedGeneXusDir
                MsBuildPath = $resolvedMsBuildPath
                KbPath = $resolvedKbPath
                XpzPath = $resolvedXpzPath
                WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
                LogPath = $resolvedLogPath
                UpdateFilePath = $resolvedUpdateFilePath
            }
            pathActions = $probeStage.Diagnostic.pathActions
            artifacts = [ordered]@{
                ProbeLogPath = $probeLogPath
                MsBuildFilePath = $null
                StdOutPath = $null
                StdErrPath = $null
                ExecutionLogPath = $resolvedLogPath
            }
            importedItems = @()
            blockingReasons = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $unsupportedJson = ConvertTo-JsonText -InputObject $unsupported
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $unsupportedJson
        }
        Write-Output $unsupportedJson
        exit 32
    }

    $includeItemsArray = @()
    if (-not [string]::IsNullOrWhiteSpace($IncludeItems)) {
        $includeItemsArray = @($IncludeItems -split ',|;|\r\n|\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
    }

    $excludeItemsArray = @()
    if (-not [string]::IsNullOrWhiteSpace($ExcludeItems)) {
        $excludeItemsArray = @($ExcludeItems -split ',|;|\r\n|\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
    }

    $msBuildFilePath = Join-Path $artifactDirectory 'import-real.msbuild'
    $stdOutPath = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath = Join-Path $artifactDirectory 'msbuild.stderr.log'
    $projectContent = New-MsBuildProjectContent -ResolvedGeneXusDir $resolvedGeneXusDir -ResolvedKbPath $resolvedKbPath -ResolvedXpzPath $resolvedXpzPath -ResolvedUpdateFilePath $resolvedUpdateFilePath -ResolvedIncludeItems $includeItemsArray -ResolvedExcludeItems $excludeItemsArray
    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild temporário gerado em: {0}' -f $msBuildFilePath)

    $msBuildExitCode = Invoke-MsBuildFile -ResolvedMsBuildPath $resolvedMsBuildPath -MsBuildFilePath $msBuildFilePath -StdOutPath $stdOutPath -StdErrPath $stdErrPath
    $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
    $stdErrText = Read-TextFileSafe -PathValue $stdErrPath
    $importedItems = @(Get-MatchingLines -Text $stdOutText -Prefix '__IMPORTED_ITEM__=')

    $importExitCode = Get-ImportExitCode -MsBuildExitCode $msBuildExitCode -ResolvedUpdateFilePath $resolvedUpdateFilePath
    if ($importExitCode -eq 0) {
        $status = 'sucesso operacional'
        $summary = 'Importação real executada sem erro operacional.'
    } else {
        $status = 'falha operacional'
        $summary = 'Importação real falhou durante a execução.'
        Add-BlockingReason -Reason ('Execução MSBuild terminou com exitCode {0}.' -f $msBuildExitCode)
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedUpdateFilePath) -and (Test-Path -LiteralPath $resolvedUpdateFilePath -PathType Leaf)) {
        Add-StrategyTrace -Message ('UpdateFile gerado em: {0}' -f $resolvedUpdateFilePath)
    }

    $diagnostic = [ordered]@{
        status = $status
        summary = $summary
        exitCode = $importExitCode
        stage = 'import-real'
        requestedContext = [ordered]@{
            VersionName = $VersionName
            EnvironmentName = $EnvironmentName
            ImportType = $ImportType
            LanguageTranslations = $LanguageTranslations
            AutomaticBackup = $AutomaticBackup
            RedefineExternalPrograms = $RedefineExternalPrograms
            ImportKbInformation = $ImportKbInformation
            IncludeItems = $IncludeItems
            ExcludeItems = $ExcludeItems
        }
        observedContext = [ordered]@{
            ActiveVersion = (Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'")
            ActiveEnvironment = (Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'")
            OpenOutput = (Get-MarkerValue -Text $stdOutText -Marker '__OPEN_OUTPUT__=')
        }
        resolvedPaths = [ordered]@{
            GeneXusDir = $resolvedGeneXusDir
            MsBuildPath = $resolvedMsBuildPath
            KbPath = $resolvedKbPath
            XpzPath = $resolvedXpzPath
            WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
            LogPath = $resolvedLogPath
            UpdateFilePath = $resolvedUpdateFilePath
        }
        pathActions = $probeStage.Diagnostic.pathActions
        artifacts = [ordered]@{
            ProbeLogPath = $probeLogPath
            MsBuildFilePath = $msBuildFilePath
            StdOutPath = $stdOutPath
            StdErrPath = $stdErrPath
            ExecutionLogPath = $resolvedLogPath
        }
        importedItems = $importedItems
        stdoutSummary = Get-TextSummary -Text $stdOutText
        stderrSummary = Get-TextSummary -Text $stdErrText
        blockingReasons = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
        warnings = @($probeStage.Diagnostic.warnings + $script:Warnings)
        strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
    }

    $json = ConvertTo-JsonText -InputObject $diagnostic
    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $importExitCode
}
catch {
    $failure = [ordered]@{
        status = 'falha operacional'
        summary = 'Falha interna do script antes de concluir a importação real.'
        exitCode = 90
        stage = 'import-real'
        requestedContext = [ordered]@{
            VersionName = $VersionName
            EnvironmentName = $EnvironmentName
            ImportType = $ImportType
            LanguageTranslations = $LanguageTranslations
            AutomaticBackup = $AutomaticBackup
            RedefineExternalPrograms = $RedefineExternalPrograms
            ImportKbInformation = $ImportKbInformation
            IncludeItems = $IncludeItems
            ExcludeItems = $ExcludeItems
        }
        resolvedPaths = [ordered]@{
            GeneXusDir = (Get-FullPathSafe -PathValue $GeneXusDir)
            MsBuildPath = (Get-FullPathSafe -PathValue $MsBuildPath)
            KbPath = (Get-FullPathSafe -PathValue $KbPath)
            XpzPath = (Get-FullPathSafe -PathValue $XpzPath)
            WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
            LogPath = $resolvedLogPath
            UpdateFilePath = (Get-FullPathSafe -PathValue $UpdateFilePath)
        }
        pathActions = [ordered]@{
            WorkingDirectory = 'blocked-internal-error'
        }
        artifacts = [ordered]@{
            ProbeLogPath = $null
            MsBuildFilePath = $null
            StdOutPath = $null
            StdErrPath = $null
            ExecutionLogPath = $resolvedLogPath
        }
        importedItems = @()
        stdoutSummary = @()
        stderrSummary = @()
        blockingReasons = @($_.Exception.Message)
        warnings = @()
        strategyTrace = @($script:StrategyTrace)
    }

    $failureJson = ConvertTo-JsonText -InputObject $failure
    try {
        if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath) -and -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            $parent = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
            if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
                Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $failureJson
            }
        }
    } catch {
        # best effort apenas
    }

    Write-Output $failureJson
    exit 90
}
