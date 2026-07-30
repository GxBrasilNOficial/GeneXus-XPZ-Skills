#requires -Version 7.4

<#
.SYNOPSIS
Lê uma propriedade da Knowledge Base do GeneXus via MSBuild em modo headless.

.DESCRIPTION
Abre a KB, executa a task Get*Property correspondente ao nível informado, captura
o valor retornado e fecha a KB. Operação de leitura segura, sem efeito sobre a KB.

.PARAMETER KbPath
Caminho da KB a ser aberta.

.PARAMETER Level
Nível da propriedade: KB, Version, Environment, Generator, DataStore ou Object.

.PARAMETER Name
Nome da propriedade a ler.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER Target
Nome do generator, datastore ou objeto. Obrigatório quando Level for Generator,
DataStore ou Object. Ignorado para KB, Version e Environment.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, a resolução usa
fallbacks compatíveis com Test-GeneXusMsBuildSetup.ps1.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, a resolução usa fallbacks
compatíveis com Test-GeneXusMsBuildSetup.ps1.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes da leitura.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes da leitura.

.PARAMETER VerboseLog
Amplia o detalhamento gravado no log sem alterar o resultado lógico.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('KB', 'Version', 'Environment', 'Generator', 'DataStore', 'Object')]
    [string]$Level,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [string]$Target,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$VersionName,

    [string]$EnvironmentName,

    [switch]$VerboseLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

$stderrNoiseSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildStderrNoiseSupport.ps1'
if (-not (Test-Path -LiteralPath $stderrNoiseSupportPath -PathType Leaf)) {
    throw "Stderr noise support script not found: $stderrNoiseSupportPath"
}
. $stderrNoiseSupportPath

$ProgramFilesX86 = [System.IO.Path]::GetFullPath('C:\Program Files (x86)')


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
        LogPath          = $ProbeLogPath
        KbPath           = $KbPath
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

    $probeOutput   = & $probeScriptPath @probeArgs
    $probeExitCode = $LASTEXITCODE
    $probeJson     = ($probeOutput -join [Environment]::NewLine)
    $probeDiag     = $probeJson | ConvertFrom-Json -Depth 8

    return [ordered]@{
        ExitCode   = $probeExitCode
        Json       = $probeJson
        Diagnostic = $probeDiag
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
    param([string]$BaseDirectory)

    $dir = Join-Path $BaseDirectory ('gx-get-prop-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($dir) | Out-Null
    return $dir
}

function New-GetPropertyTaskXml {
    param(
        [string]$ResolvedLevel,
        [string]$ResolvedName,
        [string]$ResolvedTarget
    )

    $nameEsc   = Escape-Xml -Value $ResolvedName
    $targetEsc = Escape-Xml -Value $ResolvedTarget
    $outputEl  = '      <Output TaskParameter="PropertyValue" PropertyName="PropValue" />'

    switch ($ResolvedLevel) {
        'KB' {
            return @"
    <GetKnowledgeBaseProperty Name="$nameEsc">
$outputEl
    </GetKnowledgeBaseProperty>
"@
        }
        'Version' {
            return @"
    <GetVersionProperty Name="$nameEsc">
$outputEl
    </GetVersionProperty>
"@
        }
        'Environment' {
            return @"
    <GetEnvironmentProperty Name="$nameEsc">
$outputEl
    </GetEnvironmentProperty>
"@
        }
        'Generator' {
            return @"
    <GetGeneratorProperty Name="$nameEsc" Generator="$targetEsc">
$outputEl
    </GetGeneratorProperty>
"@
        }
        'DataStore' {
            return @"
    <GetDataStoreProperty Name="$nameEsc" DataStore="$targetEsc">
$outputEl
    </GetDataStoreProperty>
"@
        }
        'Object' {
            return @"
    <GetObjectProperty Name="$nameEsc" Object="$targetEsc">
$outputEl
    </GetObjectProperty>
"@
        }
    }
}

function New-MsBuildProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath
    )

    $targetsPath  = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEsc   = Escape-Xml -Value $targetsPath
    $kbPathEsc    = Escape-Xml -Value $ResolvedKbPath
    $versionEsc   = Escape-Xml -Value $VersionName
    $envEsc       = Escape-Xml -Value $EnvironmentName
    $getTaskXml   = New-GetPropertyTaskXml -ResolvedLevel $Level -ResolvedName $Name -ResolvedTarget $Target

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEsc" />

  <PropertyGroup>
    <KBPath>$kbPathEsc</KBPath>
    <KBVersion>$versionEsc</KBVersion>
    <KBEnvironment>$envEsc</KBEnvironment>
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
$getTaskXml
    <Message Text="__PROP_VALUE__=`$(PropValue)" Importance="High" />
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
        '/nodeReuse:false',
        '/target:Run'
    )

    Add-StrategyTrace -Message ('MSBuild acionado com alvo Run em: {0}' -f $MsBuildFilePath)
    $process = Start-Process `
        -FilePath $ResolvedMsBuildPath `
        -ArgumentList $arguments `
        -WorkingDirectory (Split-Path -Parent $MsBuildFilePath) `
        -RedirectStandardOutput $StdOutPath `
        -RedirectStandardError $StdErrPath `
        -NoNewWindow -PassThru -Wait
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

function Split-NonEmptyLines {
    param([string]$Text)
    # Preserva tipagem [string[]] mesmo quando o resultado tem 0 ou 1 elemento.
    # Sem isso, o PowerShell faz unwrapping em propriedade de hashtable:
    #   0 elementos -> $null (JSON: null)
    #   1 elemento  -> string solta (JSON: string em vez de array)
    # Duas quirks distintas a tratar:
    #   - 1+ elementos: `, $result` impede o unwrapping no retorno
    #   - 0 elementos: `[string[]]$x = @()` vira `$null`; usar [string[]]::new(0) explicito
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ,([string[]]::new(0))
    }
    [string[]]$result = @($Text -split "(`r`n|`n|`r)" |
                          Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    return ,$result
}

# ---------------------------------------------------------------------------

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings        = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace   = New-Object System.Collections.Generic.List[string]

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

$logPathRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $resolvedLogPath
if ($logPathRejection.rejected) {
    Write-Output (New-GeneXusMsBuildLogPathBlockJson -WrapperName 'Get-GeneXusKbProperty.ps1' -ResolvedLogPath $resolvedLogPath -Reason $logPathRejection.reason)
    exit 50
}

try {
    $levelRequiresTarget = @('Generator', 'DataStore', 'Object')
    if ($levelRequiresTarget -contains $Level -and [string]::IsNullOrWhiteSpace($Target)) {
        Add-BlockingReason -Reason ("Parâmetro -Target obrigatório quando -Level é '$Level'.")
        $blocked = [ordered]@{
            status        = 'não apto para prosseguir'
            summary       = "-Target é obrigatório para Level '$Level'."
            exitCode      = 31
            level         = $Level
            target        = $null
            propertyName  = $Name
            propertyValue = $null
            resolvedPaths = [ordered]@{
                GeneXusDir       = $null
                MsBuildPath      = $null
                KbPath           = (Get-FullPathSafe -PathValue $KbPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
            }
            artifacts = [ordered]@{
                ProbeLogPath    = $null
                MsBuildFilePath = $null
                StdOutPath      = $null
                StdErrPath      = $null
                ExecutionLogPath = $resolvedLogPath
            }
            blockingReasons = @($script:BlockingReasons)
            warnings        = @($script:Warnings)
            strategyTrace   = @($script:StrategyTrace)
        }
        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        }
        Write-Output $blockedJson
        exit 31
    }

    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado.'
    }

    Add-StrategyTrace -Message ("Leitura solicitada: Level='$Level' Name='$Name' Target='$Target'.")

    $probeLogBaseDir = if ([string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        Split-Path -Parent $PSCommandPath
    } else {
        Get-FullPathSafe -PathValue $WorkingDirectory
    }
    $probeLogPath = Join-Path $probeLogBaseDir ('gx-getprop-probe-' + [System.Guid]::NewGuid().ToString('N') + '.json')
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath

    Add-StrategyTrace -Message ('Probe executado com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe não apto para prosseguir bloqueou a leitura de propriedade.'
        $pd = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status        = 'não apto para prosseguir'
            summary       = 'Probe bloqueou a leitura de propriedade.'
            exitCode      = $probeStage.ExitCode
            level         = $Level
            target        = if ([string]::IsNullOrWhiteSpace($Target)) { $null } else { $Target }
            propertyName  = $Name
            propertyValue = $null
            resolvedPaths = [ordered]@{
                GeneXusDir       = $pd.resolvedPaths.GeneXusDir
                MsBuildPath      = $pd.resolvedPaths.MsBuildPath
                KbPath           = $pd.resolvedPaths.KbPath
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
            }
            pathActions = $pd.pathActions
            artifacts = [ordered]@{
                ProbeLogPath    = $probeLogPath
                MsBuildFilePath = $null
                StdOutPath      = $null
                StdErrPath      = $null
                ExecutionLogPath = $resolvedLogPath
            }
            blockingReasons = @($pd.blockingReasons + $script:BlockingReasons)
            warnings        = @($pd.warnings)
            strategyTrace   = @($pd.strategyTrace + $script:StrategyTrace)
        }
        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        }
        Write-Output $blockedJson
        exit $probeStage.ExitCode
    }

    $resolvedGeneXusDir      = [string]$probeStage.Diagnostic.resolvedPaths.GeneXusDir
    $resolvedMsBuildPath     = [string]$probeStage.Diagnostic.resolvedPaths.MsBuildPath
    $resolvedKbPath          = [string]$probeStage.Diagnostic.resolvedPaths.KbPath
    $resolvedWorkingDirectory = [string]$probeStage.Diagnostic.resolvedPaths.WorkingDirectory
    $artifactDirectory       = New-ArtifactDirectory -BaseDirectory $resolvedWorkingDirectory

    $msBuildFilePath = Join-Path $artifactDirectory 'get-kb-property.msbuild'
    $stdOutPath      = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath      = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-MsBuildProjectContent -ResolvedGeneXusDir $resolvedGeneXusDir -ResolvedKbPath $resolvedKbPath
    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild gerado em: {0}' -f $msBuildFilePath)

    $msBuildExitCode = Invoke-MsBuildFile `
        -ResolvedMsBuildPath $resolvedMsBuildPath `
        -MsBuildFilePath $msBuildFilePath `
        -StdOutPath $stdOutPath `
        -StdErrPath $stdErrPath

    $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
    $stdErrText = Read-TextFileSafe -PathValue $stdErrPath
    $stdErrNoiseClassification = Get-GeneXusMsBuildStderrNoiseClassification -Text $stdErrText
    $stdErrNoise = $stdErrNoiseClassification.NoiseText
    $stdErrFiltered = $stdErrNoiseClassification.FilteredText

    $propertyValue = Get-MarkerValue -Text $stdOutText -Marker '__PROP_VALUE__='

    if ($msBuildExitCode -ne 0 -and $script:BlockingReasons.Count -eq 0) {
        Add-BlockingReason -Reason 'MSBuild falhou sem causa acionável classificada; consulte executionEvidence e logs brutos nos artefatos.'
    }

    if ($msBuildExitCode -eq 0 -and $null -eq $propertyValue) {
        Add-WarningMessage -Message 'MSBuild concluiu com sucesso mas o marcador __PROP_VALUE__ não foi encontrado no stdout.'
    }

    $operationExitCode = if ($msBuildExitCode -eq 0) { 0 } else { 20 }
    $status  = if ($operationExitCode -eq 0) { 'leitura concluída' } else { 'falha de leitura' }
    $summary = if ($operationExitCode -eq 0) {
        ("Propriedade '$Name' lida no nível '$Level'.")
    } else {
        ("Falha ao ler propriedade '$Name' no nível '$Level'.")
    }

    $diagnostic = [ordered]@{
        status        = $status
        summary       = $summary
        exitCode      = $operationExitCode
        executionEvidence = [ordered]@{
            msBuildExitCode = $msBuildExitCode
            msBuildFailed = ($msBuildExitCode -ne 0)
            wrapperExitCode = $operationExitCode
            StdOutPath = $stdOutPath
            StdErrPath = $stdErrPath
        }
        level         = $Level
        target        = if ([string]::IsNullOrWhiteSpace($Target)) { $null } else { $Target }
        propertyName  = $Name
        propertyValue = $propertyValue
        resolvedPaths = [ordered]@{
            GeneXusDir       = $resolvedGeneXusDir
            MsBuildPath      = $resolvedMsBuildPath
            KbPath           = $resolvedKbPath
            WorkingDirectory = $resolvedWorkingDirectory
            LogPath          = $resolvedLogPath
        }
        pathActions = $probeStage.Diagnostic.pathActions
        artifacts = [ordered]@{
            ProbeLogPath    = $probeLogPath
            MsBuildFilePath = $msBuildFilePath
            StdOutPath      = $stdOutPath
            StdErrPath      = $stdErrPath
            ExecutionLogPath = $resolvedLogPath
        }
        stderrContent        = Split-NonEmptyLines -Text $stdErrFiltered
        stderrFilteredNoise  = Split-NonEmptyLines -Text $stdErrNoise
        blockingReasons = @($script:BlockingReasons)
        warnings        = @($script:Warnings)
        strategyTrace   = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
    }

    $json = ConvertTo-JsonText -InputObject $diagnostic
    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $operationExitCode
}
catch {
    $failure = [ordered]@{
        status        = 'falha operacional'
        summary       = 'Falha interna do script antes de concluir a leitura de propriedade.'
        exitCode      = 90
        level         = $Level
        target        = if ([string]::IsNullOrWhiteSpace($Target)) { $null } else { $Target }
        propertyName  = $Name
        propertyValue = $null
        resolvedPaths = [ordered]@{
            GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
            MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
            KbPath           = (Get-FullPathSafe -PathValue $KbPath)
            WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
            LogPath          = $resolvedLogPath
        }
        pathActions = [ordered]@{
            WorkingDirectory = 'blocked-internal-error'
        }
        artifacts = [ordered]@{
            ProbeLogPath    = $null
            MsBuildFilePath = $null
            StdOutPath      = $null
            StdErrPath      = $null
            ExecutionLogPath = $resolvedLogPath
        }
        stderrContent        = @()
        stderrFilteredNoise  = @()
        blockingReasons = @($_.Exception.Message)
        warnings        = @()
        strategyTrace   = @($script:StrategyTrace)
    }

    $failureJson = ConvertTo-JsonText -InputObject $failure
    try {
        if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath) -and -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            $parent = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
            if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
                Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $failureJson
            }
        }
    }
    catch {
    }

    Write-Output $failureJson
    exit 90
}
