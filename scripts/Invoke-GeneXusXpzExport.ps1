<#
.SYNOPSIS
Executa exportação de XPZ via MSBuild com parâmetros explícitos.

.DESCRIPTION
Implementa a etapa de exportação simples da frente experimental: reaproveita
o probe Test-GeneXusMsBuildSetup.ps1, abre a KB em modo headless controlado,
posiciona versão e Environment quando informados, executa a task Export com
parâmetros explícitos e fecha a KB. O script não executa importação.

.PARAMETER KbPath
Caminho da KB a ser usada na exportação.

.PARAMETER XpzPath
Caminho do arquivo XPZ de saída.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, usa fallback do probe.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, usa fallback do probe.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes da exportação.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes da exportação.

.PARAMETER ObjectList
Lista explícita de objetos a exportar, quando ExportAll não estiver habilitado.

.PARAMETER DependencyType
Valor explícito para DependencyType.

.PARAMETER ReferenceType
Valor explícito para ReferenceType.

.PARAMETER ExportKbInfo
Valor explícito para ExportKBInfo. Default: false.

.PARAMETER ExportAll
Valor explícito para ExportAll. Default: false.

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

    [string]$ObjectList,

    [string]$DependencyType,

    [string]$ReferenceType,

    [ValidateSet('true', 'false')]
    [string]$ExportKbInfo = 'false',

    [ValidateSet('true', 'false')]
    [string]$ExportAll = 'false',

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
    $artifactDirectory = Join-Path $baseDirectory ('gx-export-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function Validate-XpzPath {
    $resolved = Get-FullPathSafe -PathValue $XpzPath
    $parent = [System.IO.Path]::GetDirectoryName($resolved)

    if ([string]::IsNullOrWhiteSpace($parent)) {
        Add-BlockingReason -Reason ("XpzPath inválido: '{0}'." -f $resolved)
        return [ordered]@{
            Path = $resolved
            Result = 'fail'
            Detail = 'XpzPath não possui diretório pai válido.'
            ExitCode = 33
        }
    }

    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        Add-BlockingReason -Reason ("XpzPath inválido: '{0}'." -f $resolved)
        return [ordered]@{
            Path = $resolved
            Result = 'fail'
            Detail = 'Diretório pai do XPZ não foi encontrado.'
            ExitCode = 33
        }
    }

    if (Test-IsUnderProgramFilesX86 -PathValue $resolved) {
        Add-BlockingReason -Reason ("XpzPath dentro da árvore somente leitura: '{0}'." -f $resolved)
        return [ordered]@{
            Path = $resolved
            Result = 'fail'
            Detail = 'XPZ de saída aponta para árvore estritamente somente leitura.'
            ExitCode = 33
        }
    }

    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        Add-WarningMessage -Message ('XpzPath já existe e pode ser sobrescrito pela exportação: {0}' -f $resolved)
    }

    return [ordered]@{
        Path = $resolved
        Result = 'ok'
        Detail = 'Destino de XPZ validado.'
        ExitCode = 0
    }
}

function Validate-RequiredExportShape {
    if ([string]::IsNullOrWhiteSpace($ObjectList) -and $ExportAll -ne 'true') {
        Add-BlockingReason -Reason 'ObjectList não foi informado e ExportAll não está habilitado.'
        return [ordered]@{
            Result = 'fail'
            Detail = 'Exportação simples requer ObjectList ou ExportAll=true.'
            ExitCode = 33
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ObjectList) -and $ExportAll -eq 'true') {
        Add-WarningMessage -Message 'ObjectList foi informado junto com ExportAll=true; o wrapper vai privilegiar ExportAll.'
    }

    return [ordered]@{
        Result = 'ok'
        Detail = 'Formato básico da exportação validado.'
        ExitCode = 0
    }
}

function Get-ExportTaskPropertyNames {
    param([string]$ResolvedGeneXusDir)

    $assemblyPath = Join-Path $ResolvedGeneXusDir 'Genexus.MsBuild.Tasks.dll'
    $assembly = [System.Reflection.Assembly]::LoadFrom($assemblyPath)
    $taskType = $assembly.GetType('Genexus.MsBuild.Tasks.Export')
    if ($null -eq $taskType) {
        throw "Export task type not found in assembly: $assemblyPath"
    }

    return @(
        $taskType.GetProperties([System.Reflection.BindingFlags] 'Instance,Public') |
            Select-Object -ExpandProperty Name
    )
}

function Test-ExportTaskSupportsProperty {
    param(
        [string[]]$PropertyNames,
        [string]$PropertyName
    )

    return $PropertyNames -contains $PropertyName
}

function Resolve-ExportKbInfoPropertyName {
    param([string[]]$PropertyNames)

    if ($PropertyNames -contains 'ExportKBInfo') {
        return 'ExportKBInfo'
    }

    if ($PropertyNames -contains 'ExportKBProperties') {
        return 'ExportKBProperties'
    }

    return $null
}

function New-MsBuildProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath,
        [string]$ResolvedXpzPath,
        [string]$ResolvedObjectList,
        [string]$ResolvedDependencyType,
        [string]$ResolvedReferenceType,
        [string]$ResolvedExportKbInfoPropertyName,
        [bool]$SupportsExportAll
    )

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEscaped = Escape-Xml -Value $targetsPath
    $kbPathEscaped = Escape-Xml -Value $ResolvedKbPath
    $xpzEscaped = Escape-Xml -Value $ResolvedXpzPath
    $versionEscaped = Escape-Xml -Value $VersionName
    $environmentEscaped = Escape-Xml -Value $EnvironmentName
    $objectListEscaped = Escape-Xml -Value $ResolvedObjectList
    $dependencyTypeEscaped = Escape-Xml -Value $ResolvedDependencyType
    $referenceTypeEscaped = Escape-Xml -Value $ResolvedReferenceType
    $exportKbInfoEscaped = Escape-Xml -Value $ExportKbInfo
    $exportAllEscaped = Escape-Xml -Value $ExportAll

    $objectsAttribute = ''
    if (-not [string]::IsNullOrWhiteSpace($objectListEscaped)) {
        $objectsAttribute = "      Objects=""`$(ObjectList)""`r`n"
    }

    $dependencyAttribute = ''
    if (-not [string]::IsNullOrWhiteSpace($dependencyTypeEscaped)) {
        $dependencyAttribute = "      DependencyType=""`$(DependencyType)""`r`n"
    }

    $referenceAttribute = ''
    if (-not [string]::IsNullOrWhiteSpace($referenceTypeEscaped)) {
        $referenceAttribute = "      ReferenceType=""`$(ReferenceType)""`r`n"
    }

    $exportKbInfoAttribute = ''
    if (-not [string]::IsNullOrWhiteSpace($ResolvedExportKbInfoPropertyName)) {
        $exportKbInfoAttribute = "      $ResolvedExportKbInfoPropertyName=""`$(ExportKbInfo)""`r`n"
    }

    $exportAllAttribute = ''
    if ($SupportsExportAll) {
        $exportAllAttribute = "      ExportAll=""`$(ExportAll)""`r`n"
    }

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEscaped" />

  <PropertyGroup>
    <KBPath>$kbPathEscaped</KBPath>
    <XPZPath>$xpzEscaped</XPZPath>
    <KBVersion>$versionEscaped</KBVersion>
    <KBEnvironment>$environmentEscaped</KBEnvironment>
    <ObjectList>$objectListEscaped</ObjectList>
    <DependencyType>$dependencyTypeEscaped</DependencyType>
    <ReferenceType>$referenceTypeEscaped</ReferenceType>
    <ExportKbInfo>$exportKbInfoEscaped</ExportKbInfo>
    <ExportAll>$exportAllEscaped</ExportAll>
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
    <Export
      File="`$(XPZPath)"$objectsAttribute$dependencyAttribute$referenceAttribute$exportKbInfoAttribute$exportAllAttribute />
    <Message Text="__EXPORTED_FILE__=`$(XPZPath)" Importance="High" />
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

function Get-ExportExitCode {
    param(
        [int]$MsBuildExitCode,
        [string]$ResolvedXpzPath
    )

    if ($MsBuildExitCode -ne 0) {
        return 41
    }

    if (-not (Test-Path -LiteralPath $ResolvedXpzPath -PathType Leaf)) {
        return 42
    }

    return 0
}

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace = New-Object System.Collections.Generic.List[string]

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

try {
    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional da exportação headless.'
    }

    $artifactDirectory = New-ArtifactDirectory
    $probeLogPath = Join-Path $artifactDirectory 'probe-stage.json'
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath

    Add-StrategyTrace -Message ('Probe executado antes da exportação com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe não apto para prosseguir bloqueou a exportação.'
        $probeDiagnostic = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'Probe bloqueou a exportação.'
            exitCode = $probeStage.ExitCode
            stage = 'probe'
            requestedContext = [ordered]@{
                VersionName = $VersionName
                EnvironmentName = $EnvironmentName
                ObjectList = $ObjectList
                DependencyType = $DependencyType
                ReferenceType = $ReferenceType
                ExportKbInfo = $ExportKbInfo
                ExportAll = $ExportAll
            }
            observedContext = [ordered]@{
                ActiveVersion = $null
                ActiveEnvironment = $null
            }
            resolvedPaths = [ordered]@{
                GeneXusDir = $probeDiagnostic.resolvedPaths.GeneXusDir
                MsBuildPath = $probeDiagnostic.resolvedPaths.MsBuildPath
                KbPath = $probeDiagnostic.resolvedPaths.KbPath
                XpzPath = (Get-FullPathSafe -PathValue $XpzPath)
                WorkingDirectory = $probeDiagnostic.resolvedPaths.WorkingDirectory
                LogPath = $resolvedLogPath
            }
            pathActions = $probeDiagnostic.pathActions
            artifacts = [ordered]@{
                ProbeLogPath = $probeLogPath
                MsBuildFilePath = $null
                StdOutPath = $null
                StdErrPath = $null
                ExecutionLogPath = $resolvedLogPath
                XpzPath = (Get-FullPathSafe -PathValue $XpzPath)
            }
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
    $exportShapeValidation = Validate-RequiredExportShape
    if ($xpzValidation.ExitCode -ne 0 -or $exportShapeValidation.ExitCode -ne 0) {
        $exitCode = if ($xpzValidation.ExitCode -ne 0) { $xpzValidation.ExitCode } else { $exportShapeValidation.ExitCode }
        $blockedJsonObject = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'Validação prévia bloqueou a exportação.'
            exitCode = $exitCode
            stage = 'pre-validate'
            resolvedPaths = [ordered]@{
                GeneXusDir = $probeStage.Diagnostic.resolvedPaths.GeneXusDir
                MsBuildPath = $probeStage.Diagnostic.resolvedPaths.MsBuildPath
                KbPath = $probeStage.Diagnostic.resolvedPaths.KbPath
                XpzPath = $xpzValidation.Path
                WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
                LogPath = $resolvedLogPath
            }
            pathActions = $probeStage.Diagnostic.pathActions
            artifacts = [ordered]@{
                ProbeLogPath = $probeLogPath
                MsBuildFilePath = $null
                StdOutPath = $null
                StdErrPath = $null
                ExecutionLogPath = $resolvedLogPath
                XpzPath = $xpzValidation.Path
            }
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
    $resolvedObjectList = [string]$ObjectList
    $resolvedDependencyType = [string]$DependencyType
    $resolvedReferenceType = [string]$ReferenceType

    $exportTaskPropertyNames = Get-ExportTaskPropertyNames -ResolvedGeneXusDir $resolvedGeneXusDir
    $exportKbInfoPropertyName = Resolve-ExportKbInfoPropertyName -PropertyNames $exportTaskPropertyNames
    $supportsExportAll = Test-ExportTaskSupportsProperty -PropertyNames $exportTaskPropertyNames -PropertyName 'ExportAll'

    if (-not [string]::IsNullOrWhiteSpace($resolvedObjectList) -and -not (Test-ExportTaskSupportsProperty -PropertyNames $exportTaskPropertyNames -PropertyName 'Objects')) {
        Add-BlockingReason -Reason 'A instalação atual não expõe a propriedade Objects na task Export.'
    }
    if (-not [string]::IsNullOrWhiteSpace($resolvedDependencyType) -and -not (Test-ExportTaskSupportsProperty -PropertyNames $exportTaskPropertyNames -PropertyName 'DependencyType')) {
        Add-BlockingReason -Reason 'A instalação atual não expõe a propriedade DependencyType na task Export.'
    }
    if (-not [string]::IsNullOrWhiteSpace($resolvedReferenceType) -and -not (Test-ExportTaskSupportsProperty -PropertyNames $exportTaskPropertyNames -PropertyName 'ReferenceType')) {
        Add-BlockingReason -Reason 'A instalação atual não expõe a propriedade ReferenceType na task Export.'
    }
    if ($ExportAll -eq 'true' -and -not (Test-ExportTaskSupportsProperty -PropertyNames $exportTaskPropertyNames -PropertyName 'ExportAll')) {
        Add-BlockingReason -Reason 'A instalação atual não expõe a propriedade ExportAll na task Export.'
    }
    if ($ExportKbInfo -eq 'true' -and [string]::IsNullOrWhiteSpace($exportKbInfoPropertyName)) {
        Add-BlockingReason -Reason 'A instalação atual não expõe ExportKBInfo nem ExportKBProperties na task Export.'
    }

    if ($script:BlockingReasons.Count -gt 0) {
        $unsupported = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'Exportação bloqueada porque a task Export não expõe um ou mais parâmetros solicitados.'
            exitCode = 34
            stage = 'task-support'
            requestedContext = [ordered]@{
                VersionName = $VersionName
                EnvironmentName = $EnvironmentName
                ObjectList = $ObjectList
                DependencyType = $DependencyType
                ReferenceType = $ReferenceType
                ExportKbInfo = $ExportKbInfo
                ExportAll = $ExportAll
            }
            observedContext = [ordered]@{
                ActiveVersion = $null
                ActiveEnvironment = $null
            }
            resolvedPaths = [ordered]@{
                GeneXusDir = $resolvedGeneXusDir
                MsBuildPath = $resolvedMsBuildPath
                KbPath = $resolvedKbPath
                XpzPath = $resolvedXpzPath
                WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
                LogPath = $resolvedLogPath
            }
            pathActions = $probeStage.Diagnostic.pathActions
            artifacts = [ordered]@{
                ProbeLogPath = $probeLogPath
                MsBuildFilePath = $null
                StdOutPath = $null
                StdErrPath = $null
                ExecutionLogPath = $resolvedLogPath
                XpzPath = $resolvedXpzPath
            }
            blockingReasons = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $unsupportedJson = ConvertTo-JsonText -InputObject $unsupported
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $unsupportedJson
        }
        Write-Output $unsupportedJson
        exit 34
    }

    $msBuildFilePath = Join-Path $artifactDirectory 'export-xpz.msbuild'
    $stdOutPath = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-MsBuildProjectContent -ResolvedGeneXusDir $resolvedGeneXusDir -ResolvedKbPath $resolvedKbPath -ResolvedXpzPath $resolvedXpzPath -ResolvedObjectList $resolvedObjectList -ResolvedDependencyType $resolvedDependencyType -ResolvedReferenceType $resolvedReferenceType -ResolvedExportKbInfoPropertyName $exportKbInfoPropertyName -SupportsExportAll $supportsExportAll
    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild temporário gerado em: {0}' -f $msBuildFilePath)

    $msBuildExitCode = Invoke-MsBuildFile -ResolvedMsBuildPath $resolvedMsBuildPath -MsBuildFilePath $msBuildFilePath -StdOutPath $stdOutPath -StdErrPath $stdErrPath
    $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
    $stdErrText = Read-TextFileSafe -PathValue $stdErrPath

    $openOutput = Get-MarkerValue -Text $stdOutText -Marker '__OPEN_OUTPUT__='
    $activeVersionOutput = Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'"
    $activeEnvironmentOutput = Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'"
    $exportedFileMarker = Get-MarkerValue -Text $stdOutText -Marker '__EXPORTED_FILE__='

    if (-not [string]::IsNullOrWhiteSpace($VersionName) -and [string]::IsNullOrWhiteSpace($activeVersionOutput)) {
        Add-WarningMessage -Message 'Versão solicitada, mas o retorno de GetActiveVersion veio vazio.'
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName) -and [string]::IsNullOrWhiteSpace($activeEnvironmentOutput)) {
        Add-WarningMessage -Message 'Environment solicitado, mas o retorno de GetActiveEnvironment veio vazio.'
    }

    $fileExists = Test-Path -LiteralPath $resolvedXpzPath -PathType Leaf
    if (-not $fileExists) {
        Add-BlockingReason -Reason ('XPZ de saída não foi encontrado após a exportação: {0}' -f $resolvedXpzPath)
    }

    $exportExitCode = Get-ExportExitCode -MsBuildExitCode $msBuildExitCode -ResolvedXpzPath $resolvedXpzPath
    $status = if ($exportExitCode -eq 0) { 'sucesso operacional' } else { 'falha operacional' }
    $summary = if ($exportExitCode -eq 0) { 'Exportação headless concluída e XPZ gerado.' } else { 'Exportação headless falhou durante a execução do MSBuild.' }

    if ($exportExitCode -ne 0) {
        Add-BlockingReason -Reason ('Execução MSBuild terminou com exitCode {0}.' -f $msBuildExitCode)
    }

    if (-not [string]::IsNullOrWhiteSpace($exportedFileMarker) -and -not $fileExists) {
        Add-WarningMessage -Message 'O marcador de exportação foi emitido, mas o arquivo não foi encontrado no caminho final.'
    }

    $fileSizeBytes = $null
    if ($fileExists) {
        $fileSizeBytes = (Get-Item -LiteralPath $resolvedXpzPath).Length
        Add-StrategyTrace -Message ('XPZ gerado em: {0}' -f $resolvedXpzPath)
    }

    $diagnostic = [ordered]@{
        status = $status
        summary = $summary
        exitCode = $exportExitCode
        stage = 'export'
        requestedContext = [ordered]@{
            VersionName = $VersionName
            EnvironmentName = $EnvironmentName
            ObjectList = $ObjectList
            DependencyType = $DependencyType
            ReferenceType = $ReferenceType
            ExportKbInfo = $ExportKbInfo
            ExportAll = $ExportAll
        }
        observedContext = [ordered]@{
            ActiveVersion = $activeVersionOutput
            ActiveEnvironment = $activeEnvironmentOutput
            OpenOutput = $openOutput
        }
        resolvedPaths = [ordered]@{
            GeneXusDir = $resolvedGeneXusDir
            MsBuildPath = $resolvedMsBuildPath
            KbPath = $resolvedKbPath
            XpzPath = $resolvedXpzPath
            WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
            LogPath = $resolvedLogPath
        }
        pathActions = $probeStage.Diagnostic.pathActions
        artifacts = [ordered]@{
            ProbeLogPath = $probeLogPath
            MsBuildFilePath = $msBuildFilePath
            StdOutPath = $stdOutPath
            StdErrPath = $stdErrPath
            ExecutionLogPath = $resolvedLogPath
            XpzPath = $resolvedXpzPath
            XpzSizeBytes = $fileSizeBytes
        }
        stdoutSummary = Get-TextSummary -Text $stdOutText
        stderrSummary = Get-TextSummary -Text $stdErrText
        blockingReasons = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
        warnings = @($probeStage.Diagnostic.warnings + $script:Warnings)
        strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
    }

    $json = ConvertTo-JsonText -InputObject $diagnostic
    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $exportExitCode
}
catch {
    $failure = [ordered]@{
        status = 'falha operacional'
        summary = 'Falha interna do script antes de concluir a exportação.'
        exitCode = 90
        stage = 'export'
        requestedContext = [ordered]@{
            VersionName = $VersionName
            EnvironmentName = $EnvironmentName
            ObjectList = $ObjectList
            DependencyType = $DependencyType
            ReferenceType = $ReferenceType
            ExportKbInfo = $ExportKbInfo
            ExportAll = $ExportAll
        }
        resolvedPaths = [ordered]@{
            GeneXusDir = (Get-FullPathSafe -PathValue $GeneXusDir)
            MsBuildPath = (Get-FullPathSafe -PathValue $MsBuildPath)
            KbPath = (Get-FullPathSafe -PathValue $KbPath)
            XpzPath = (Get-FullPathSafe -PathValue $XpzPath)
            WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
            LogPath = $resolvedLogPath
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
            XpzPath = (Get-FullPathSafe -PathValue $XpzPath)
        }
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
