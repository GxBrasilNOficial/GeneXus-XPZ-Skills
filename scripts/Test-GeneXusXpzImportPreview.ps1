#requires -Version 7.4

<#
.SYNOPSIS
Executa preview de importação de pacote (.xpz, .xml ou .import_file.xml) via MSBuild sem alterar a KB.

.DESCRIPTION
Implementa a terceira etapa da trilha experimental: reaproveita o probe
Test-GeneXusMsBuildSetup.ps1, abre a KB em modo headless controlado, posiciona
versão e Environment quando informados, executa a task Import com
PreviewMode="true" e fecha a KB. O script não executa importação real.

.PARAMETER KbPath
Caminho da KB a ser usada no preview.

.PARAMETER InputPath
Caminho do pacote de importação a ser inspecionado em preview. Nome canônico do
contrato de entrada primária; aliases aceitos: `-XpzPath` (retrocompatível) e `-Path`. Aceita `.xpz`
(formato compactado padrão GeneXus), `.xml` ou `.import_file.xml` (envelope
GeneXus com raiz `<ExportFile>`) — qualquer um deles é insumo válido quando o
envelope já foi validado externamente por `Test-GeneXusImportFileEnvelope.ps1`.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, usa fallback do probe.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, usa fallback do probe.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes do preview.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes do preview.

.PARAMETER UpdateFilePath
Caminho opcional para o UpdateFile gerado pelo preview.

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

.PARAMETER ImportKbInformation
Valor para ImportKBInformation, tri-state: omitido ou `false` significam não
emitir o atributo na task Import (omissão do atributo faz a task aplicar seu
próprio default, documentado como `true` em
`10-base-operacional-msbuild-headless.md`); apenas `true` emite o atributo e
exige que a task carregada exponha a propriedade. Bloqueio por assinatura da
task só ocorre quando o valor for `true` em instalação sem suporte; `false` é
tratado como omissão.

.PARAMETER VerboseLog
Amplia o detalhamento gravado no log sem alterar o resultado lógico.

.PARAMETER MonitorLogPath
Caminho opcional do log gravado por Watch-GeneXusMsBuildLog.ps1.

.PARAMETER StartWatcher
Switch. Quando presente, o próprio wrapper dispara Watch-GeneXusMsBuildLog.ps1 antes
de iniciar o MSBuild. Requer -MonitorLogPath.

.PARAMETER WatcherIntervalSeconds
Intervalo de polling em segundos do watcher. Padrão: 5. Intervalo válido: 1-60.

.PARAMETER WatcherSilenceThresholdSeconds
Segundos sem nova linha no log antes de o watcher emitir alerta de silêncio. Padrão: 120.
Intervalo válido: 30-3600.

.PARAMETER ParallelKbRoot
Raiz da pasta paralela da KB. Obrigatório em preview/import seletivo com -IncludeItems.

.PARAMETER IndexPath
Caminho explícito do kb-intelligence.sqlite; prevalece sobre -ParallelKbRoot.

.PARAMETER CatalogOverridePath
Override opcional de scripts/gx-object-type-catalog.override.json.
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
    [string]$ImportKbInformation,

    [switch]$VerboseLog,

    [string]$MonitorLogPath,

    [switch]$StartWatcher,

    [ValidateRange(1, 60)]
    [int]$WatcherIntervalSeconds = 5,

    [ValidateRange(30, 3600)]
    [int]$WatcherSilenceThresholdSeconds = 120,

    [string]$ParallelKbRoot,

    [string]$IndexPath,

    [string]$CatalogOverridePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$stderrNoiseSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildStderrNoiseSupport.ps1'
if (-not (Test-Path -LiteralPath $stderrNoiseSupportPath -PathType Leaf)) {
    throw "Stderr noise support script not found: $stderrNoiseSupportPath"
}
. $stderrNoiseSupportPath

$logPathGateSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildLogPathSupport.ps1'
if (-not (Test-Path -LiteralPath $logPathGateSupportPath -PathType Leaf)) {
    throw "LogPath gate support script not found: $logPathGateSupportPath"
}
. $logPathGateSupportPath

$watcherSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildWatcherSupport.ps1'
if (-not (Test-Path -LiteralPath $watcherSupportPath -PathType Leaf)) {
    throw "Watcher support script not found: $watcherSupportPath"
}
. $watcherSupportPath

$concurrencySupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildConcurrencySupport.ps1'
if (-not (Test-Path -LiteralPath $concurrencySupportPath -PathType Leaf)) {
    throw "Concurrency support script not found: $concurrencySupportPath"
}
. $concurrencySupportPath

$categoryBSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildCategoryBSupport.ps1'
if (-not (Test-Path -LiteralPath $categoryBSupportPath -PathType Leaf)) {
    throw "Category B support script not found: $categoryBSupportPath"
}
. $categoryBSupportPath

$preflightSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusObjectListIdentityPreflight.ps1'
if (-not (Test-Path -LiteralPath $preflightSupportPath -PathType Leaf)) {
    throw "Object list identity preflight script not found: $preflightSupportPath"
}
. $preflightSupportPath

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

function Add-GeneXusSubdirsToPath {
    param([string]$ResolvedGeneXusDir)

    $gxSubPathCandidates = @(
        $ResolvedGeneXusDir,
        (Join-Path $ResolvedGeneXusDir 'gxnet'),
        (Join-Path $ResolvedGeneXusDir 'gxnet\bin'),
        (Join-Path $ResolvedGeneXusDir 'gxnetcore')
    )

    $gxSubPathsAdded = @()
    $gxSubPathsSkipped = @()

    foreach ($candidate in $gxSubPathCandidates) {
        if (Test-Path -LiteralPath $candidate) {
            $gxSubPathsAdded += $candidate
        } else {
            $gxSubPathsSkipped += $candidate
        }
    }

    if ($gxSubPathsAdded.Count -gt 0) {
        $env:PATH = ($gxSubPathsAdded -join ';') + ';' + $env:PATH
    }

    $script:PathEnrichment = [ordered]@{
        applied        = ($gxSubPathsAdded.Count -gt 0)
        subdirsAdded   = $gxSubPathsAdded
        subdirsSkipped = $gxSubPathsSkipped
    }

    if ($gxSubPathsSkipped.Count -gt 0) {
        Add-WarningMessage -Message ("Subdirs esperados do GeneXus ausentes em '{0}': {1}. Instalacao pode estar nao-padrao; tools internas chamadas por Process.Start sem caminho absoluto podem falhar." -f $ResolvedGeneXusDir, ($gxSubPathsSkipped -join ', '))
    }

    Add-StrategyTrace -Message ("PATH enriquecido preventivamente com subdirs do GeneXus para preview headless de import: [{0}]. Subdirs ausentes: [{1}]." -f ($gxSubPathsAdded -join ', '), ($gxSubPathsSkipped -join ', '))
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
    $probeDiagnostic = $probeJson | ConvertFrom-Json

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
    $artifactDirectory = Join-Path $baseDirectory ('gx-import-preview-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function Validate-XpzPath {
    $resolved = Get-FullPathSafe -PathValue $InputPath
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        Add-BlockingReason -Reason ("XpzPath inválido: '{0}'." -f $resolved)
        return [ordered]@{
            Path = $resolved
            Result = 'fail'
            Detail = 'Arquivo XPZ não foi encontrado.'
            ExitCode = 30
        }
    }

    $lowerPath = $resolved.ToLowerInvariant()
    $acceptedExtensions = @('.xpz', '.xml', '.import_file.xml')
    $isAccepted = $false
    foreach ($ext in $acceptedExtensions) {
        if ($lowerPath.EndsWith($ext)) {
            $isAccepted = $true
            break
        }
    }
    if (-not $isAccepted) {
        Add-WarningMessage -Message 'XpzPath informado não termina com extensão reconhecida (.xpz, .xml, .import_file.xml).'
    }

    return [ordered]@{
        Path = $resolved
        Result = 'ok'
        Detail = 'Pacote de importação encontrado.'
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

function Split-ItemFilter {
    param([string]$FilterText)

    if ([string]::IsNullOrWhiteSpace($FilterText)) {
        return @()
    }

    return @(
        $FilterText -split ',|;|\r\n|\n' |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() }
    )
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
    $includeEscaped = Escape-Xml -Value (($ResolvedIncludeItems -join ';'))
    $excludeEscaped = Escape-Xml -Value (($ResolvedExcludeItems -join ';'))
    $updateEscaped = Escape-Xml -Value $ResolvedUpdateFilePath
    $automaticBackupEscaped = Escape-Xml -Value $AutomaticBackup
    $importTypeEscaped = Escape-Xml -Value $ImportType
    $translationsEscaped = Escape-Xml -Value $LanguageTranslations
    $importKbInfoEscaped = Escape-Xml -Value $ImportKbInformation

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
    <IncludeItems>$includeEscaped</IncludeItems>
    <ExcludeItems>$excludeEscaped</ExcludeItems>
    <UpdateFilePath>$updateEscaped</UpdateFilePath>
    <AutomaticBackup>$automaticBackupEscaped</AutomaticBackup>
    <ImportType>$importTypeEscaped</ImportType>
    <LanguageTranslations>$translationsEscaped</LanguageTranslations>
    <ImportKBInformation>$importKbInfoEscaped</ImportKBInformation>
  </PropertyGroup>

  <Target Name="CloseOnError">
    <CloseKnowledgeBase ContinueOnError="WarnAndContinue" />
  </Target>

  <Target Name="Run">
    <OpenKnowledgeBase Directory="`$(KBPath)" />
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
      PreviewMode="true"$optionalAttributesText>
      <Output TaskParameter="ImportedItems" ItemName="ImportedItem" />
    </Import>
    <Message Text="__IMPORTED_ITEM__=%(ImportedItem.Identity)" Importance="High" Condition="'@(ImportedItem)' != ''" />
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
        '/nodeReuse:false',
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

function Get-RegexValue {
    param(
        [string]$Text,
        [string]$Pattern
    )

    $match = [regex]::Match($Text, $Pattern)
    if (-not $match.Success -or $match.Groups.Count -lt 2) {
        return $null
    }
    return $match.Groups[1].Value.Trim()
}

function Get-PreviewExitCode {
    param(
        [int]$MsBuildExitCode,
        [string]$ResolvedUpdateFilePath,
        [string[]]$PreviewErrors
    )

    if ($MsBuildExitCode -eq 0) {
        if (-not [string]::IsNullOrWhiteSpace($ResolvedUpdateFilePath) -and -not (Test-Path -LiteralPath $ResolvedUpdateFilePath -PathType Leaf)) {
            return 32
        }
        return (Resolve-GeneXusMsBuildCategoryBExitCode `
            -BaseExitCode 0 `
            -MsBuildExitCode $MsBuildExitCode `
            -MsBuildErrors $PreviewErrors `
            -InvalidTypesRejected @())
    }

    return 31
}

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace = New-Object System.Collections.Generic.List[string]
$script:PathEnrichment = [ordered]@{
    applied        = $false
    subdirsAdded   = @()
    subdirsSkipped = @()
}
$script:TimingLog = [ordered]@{}
$script:WatcherContext = New-GeneXusMsBuildWatcherContext -StartWatcherRequested $StartWatcher.IsPresent

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

$logPathRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $resolvedLogPath
if ($logPathRejection.rejected) {
    Write-Output (New-GeneXusMsBuildLogPathBlockJson -WrapperName 'Test-GeneXusXpzImportPreview.ps1' -ResolvedLogPath $resolvedLogPath -Reason $logPathRejection.reason)
    exit 50
}
$script:TimingLog['scriptStart'] = Get-GeneXusMsBuildNowIso

try {
    $watcherParameterValidation = Test-GeneXusMsBuildWatcherParameters -StartWatcherRequested $StartWatcher.IsPresent -MonitorLogPath $MonitorLogPath
    if (-not $watcherParameterValidation.ok) {
        Add-BlockingReason -Reason $watcherParameterValidation.reason
        $blocked = [ordered]@{
            status = 'bloqueado por politica de seguranca'
            causeId = $watcherParameterValidation.causeId
            summary = $watcherParameterValidation.summary
            exitCode = 46
            stage = 'pre-import-preview'
            requestedContext = [ordered]@{
                VersionName = $VersionName
                EnvironmentName = $EnvironmentName
                ImportType = $ImportType
                ImportKbInformation = $ImportKbInformation
                StartWatcherRequested = $StartWatcher.IsPresent
            }
            resolvedPaths = [ordered]@{
                GeneXusDir = (Get-FullPathSafe -PathValue $GeneXusDir)
                MsBuildPath = (Get-FullPathSafe -PathValue $MsBuildPath)
                KbPath = (Get-FullPathSafe -PathValue $KbPath)
                XpzPath = (Get-FullPathSafe -PathValue $InputPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath = $resolvedLogPath
            }
            artifacts = [ordered]@{ ExecutionLogPath = $resolvedLogPath }
            watcherContext = $script:WatcherContext
            timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            blockingReasons = @($script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($script:StrategyTrace)
        }
        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath) -and -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            $parent = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
            if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
                Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
            }
        }
        Write-Output $blockedJson
        exit 46
    }

    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional do preview de importação.'
    }

    $artifactDirectory = New-ArtifactDirectory
    $probeLogPath = Join-Path $artifactDirectory 'probe-stage.json'
    $script:TimingLog['probeStart'] = Get-GeneXusMsBuildNowIso
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath
    $script:TimingLog['probeEnd'] = Get-GeneXusMsBuildNowIso
    Add-StrategyTrace -Message ('Probe executado antes do preview de importação com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe não apto para prosseguir bloqueou o preview de importação.'
        $probeDiagnostic = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'Probe bloqueou o preview de importação.'
            exitCode = $probeStage.ExitCode
            stage = 'probe'
            resolvedPaths = [ordered]@{
                GeneXusDir = $probeDiagnostic.resolvedPaths.GeneXusDir
                MsBuildPath = $probeDiagnostic.resolvedPaths.MsBuildPath
                KbPath = $probeDiagnostic.resolvedPaths.KbPath
                XpzPath = (Get-FullPathSafe -PathValue $InputPath)
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
            watcherContext = $script:WatcherContext
            timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
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
            summary = 'Validação prévia bloqueou o preview de importação.'
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
            watcherContext = $script:WatcherContext
            timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            importedItems = @()
            blockingReasons = @($script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blockedJson = ConvertTo-JsonText -InputObject $blockedJsonObject
        Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        Write-Output $blockedJson
        exit $exitCode
    }

    $preflightResult = Invoke-GeneXusObjectListIdentityPreflight `
        -GateContext 'import' `
        -IncludeItems $IncludeItems `
        -ParallelKbRoot $ParallelKbRoot `
        -IndexPath $IndexPath `
        -CatalogOverridePath $CatalogOverridePath

    foreach ($warn in @($preflightResult.warnings)) {
        Add-WarningMessage -Message $warn
    }

    if ($preflightResult.block) {
        foreach ($reason in @($preflightResult.blockingReasons)) {
            Add-BlockingReason -Reason $reason
        }

        $preflightBlocked = [ordered]@{
            status = 'não apto para prosseguir'
            summary = 'Pré-validação de identidade no índice KbIntelligence bloqueou o preview de importação seletiva.'
            exitCode = $preflightResult.exitCode
            stage = 'pre-import-identity'
            requestedContext = [ordered]@{
                VersionName = $VersionName
                EnvironmentName = $EnvironmentName
                IncludeItems = $IncludeItems
                ExcludeItems = $ExcludeItems
                ParallelKbRoot = $ParallelKbRoot
                IndexPath = $IndexPath
            }
            resolvedPaths = [ordered]@{
                GeneXusDir = $probeStage.Diagnostic.resolvedPaths.GeneXusDir
                MsBuildPath = $probeStage.Diagnostic.resolvedPaths.MsBuildPath
                KbPath = $probeStage.Diagnostic.resolvedPaths.KbPath
                XpzPath = $xpzValidation.Path
                WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
                LogPath = $resolvedLogPath
                UpdateFilePath = $updateFileValidation.Path
                KbIntelligenceIndexPath = $preflightResult.indexPath
            }
            objectListPreflight = ConvertTo-GeneXusObjectListPreflightLogSection -PreflightResult $preflightResult
            pathActions = $probeStage.Diagnostic.pathActions
            artifacts = [ordered]@{
                ProbeLogPath = $probeLogPath
                ExecutionLogPath = $resolvedLogPath
            }
            watcherContext = $script:WatcherContext
            timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            importedItems = @()
            blockingReasons = @($script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $preflightBlockedJson = ConvertTo-JsonText -InputObject $preflightBlocked
        Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $preflightBlockedJson
        Write-Output $preflightBlockedJson
        exit $preflightResult.exitCode
    }

    if ($preflightResult.preflightEnabled) {
        Add-StrategyTrace -Message ('Pré-validação de identidade no índice (preview): {0} item(ns); avisos={1}.' -f @($preflightResult.preflightItems).Count, @($preflightResult.warnings).Count)
    }

    $resolvedGeneXusDir = [string]$probeStage.Diagnostic.resolvedPaths.GeneXusDir
    $resolvedMsBuildPath = [string]$probeStage.Diagnostic.resolvedPaths.MsBuildPath
    $resolvedKbPath = [string]$probeStage.Diagnostic.resolvedPaths.KbPath
    $resolvedXpzPath = $xpzValidation.Path
    $resolvedUpdateFilePath = $updateFileValidation.Path

    Add-GeneXusSubdirsToPath -ResolvedGeneXusDir $resolvedGeneXusDir

    $importTaskPropertyNames = Get-ImportTaskPropertyNames -ResolvedGeneXusDir $resolvedGeneXusDir
    Add-StrategyTrace -Message ('Import task properties carregadas da instalação atual: {0}' -f ($importTaskPropertyNames -join ', '))

    if (-not [string]::IsNullOrWhiteSpace($resolvedUpdateFilePath) -and -not (Test-ImportTaskSupportsProperty -PropertyNames $importTaskPropertyNames -PropertyName 'UpdateFile')) {
        Add-BlockingReason -Reason 'A instalação atual não expõe a propriedade pública UpdateFile na task Import.'
        $unsupported = [ordered]@{
            status = 'preview bloqueado por assinatura da task'
            summary = 'Preview bloqueado porque a instalação atual não suporta UpdateFile na task Import.'
            exitCode = 32
            stage = 'pre-validate'
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
            watcherContext = $script:WatcherContext
            timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            importedItems = @()
            blockingReasons = @($script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $unsupportedJson = ConvertTo-JsonText -InputObject $unsupported
        Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $unsupportedJson
        Write-Output $unsupportedJson
        exit 32
    }

    if ($ImportKbInformation -eq 'true' -and -not (Test-ImportTaskSupportsProperty -PropertyNames $importTaskPropertyNames -PropertyName 'ImportKBInformation')) {
        Add-BlockingReason -Reason 'A instalação atual não expõe a propriedade pública ImportKBInformation na task Import; valor solicitado foi true e não pode ser omitido sem mudar a intenção.'
        $unsupported = [ordered]@{
            status = 'preview bloqueado por assinatura da task'
            summary = 'Preview bloqueado porque a instalação atual não suporta ImportKBInformation=true na task Import.'
            exitCode = 32
            stage = 'pre-validate'
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
            watcherContext = $script:WatcherContext
            timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            importedItems = @()
            blockingReasons = @($script:BlockingReasons)
            warnings = @($script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $unsupportedJson = ConvertTo-JsonText -InputObject $unsupported
        Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $unsupportedJson
        Write-Output $unsupportedJson
        exit 32
    }

    $includeItemsArray = Split-ItemFilter -FilterText $IncludeItems
    $excludeItemsArray = Split-ItemFilter -FilterText $ExcludeItems

    $msBuildFilePath = Join-Path $artifactDirectory 'import-preview.msbuild'
    $stdOutPath = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath = Join-Path $artifactDirectory 'msbuild.stderr.log'
    $projectContent = New-MsBuildProjectContent -ResolvedGeneXusDir $resolvedGeneXusDir -ResolvedKbPath $resolvedKbPath -ResolvedXpzPath $resolvedXpzPath -ResolvedUpdateFilePath $resolvedUpdateFilePath -ResolvedIncludeItems $includeItemsArray -ResolvedExcludeItems $excludeItemsArray
    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild temporário gerado em: {0}' -f $msBuildFilePath)

    $script:TimingLog['msbuildConcurrencyCheckStart'] = Get-GeneXusMsBuildNowIso
    $msBuildConcurrency = Invoke-GeneXusMsBuildKbConcurrencyCheck -KbPath $resolvedKbPath -ExcludeProcessId $PID
    $script:TimingLog['msbuildConcurrencyCheckEnd'] = Get-GeneXusMsBuildNowIso
    Add-StrategyTrace -Message ('Preflight de concorrência MSBuild concluído com status {0}.' -f $msBuildConcurrency.status)
    if ([int]$msBuildConcurrency.exitCode -ne 0) {
        Add-BlockingReason -Reason $msBuildConcurrency.summary
        $blocked = [ordered]@{
            status = 'bloqueado por MSBuild concorrente'
            summary = $msBuildConcurrency.summary
            exitCode = 46
            stage = 'pre-import-preview'
            requestedContext = [ordered]@{
                VersionName = $VersionName
                EnvironmentName = $EnvironmentName
                XpzPath = $resolvedXpzPath
            }
            resolvedPaths = [ordered]@{
                GeneXusDir = $resolvedGeneXusDir
                MsBuildPath = $resolvedMsBuildPath
                KbPath = $resolvedKbPath
                XpzPath = $resolvedXpzPath
                LogPath = $resolvedLogPath
            }
            artifacts = [ordered]@{
                ProbeLogPath = $probeLogPath
                MsBuildFilePath = $msBuildFilePath
                StdOutPath = $stdOutPath
                StdErrPath = $stdErrPath
            }
            watcherContext = $script:WatcherContext
            timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            msBuildConcurrency = $msBuildConcurrency
            importedItems = @()
            blockingReasons = @($msBuildConcurrency.blockingReasons + $script:BlockingReasons)
            warnings = @($msBuildConcurrency.warnings + $script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        Write-Output $blockedJson
        exit 46
    }

    if ($StartWatcher.IsPresent) {
        Start-GeneXusMsBuildWatcherProcess `
            -WatcherContext $script:WatcherContext `
            -ScriptsDirectory (Split-Path -Parent $PSCommandPath) `
            -LogFilePath $stdOutPath `
            -MonitorLogFilePath $MonitorLogPath `
            -IntervalSeconds $WatcherIntervalSeconds `
            -SilenceThresholdSeconds $WatcherSilenceThresholdSeconds
    }

    $script:TimingLog['msbuildStart'] = Get-GeneXusMsBuildNowIso
    $msBuildExitCode = Invoke-MsBuildFile -ResolvedMsBuildPath $resolvedMsBuildPath -MsBuildFilePath $msBuildFilePath -StdOutPath $stdOutPath -StdErrPath $stdErrPath
    $script:TimingLog['msbuildEnd'] = Get-GeneXusMsBuildNowIso
    # Pos-processamento resiliente: a partir daqui o MSBuild já rodou.
    # Falha local não pode descartar evidencia real do MSBuild.
    $postProcessingFailed = $false
    $postProcessingError  = $null
    $diagnosticDegraded   = $false
    $diagnosticDegradedReason = $null
    $stdOutText         = ''
    $stdErrText         = ''
    $stdErrNoise        = ''
    $stdErrFiltered     = ''
    $importedItems      = @()
    $importWarningLines = @()
    $signalsPath        = Join-Path $artifactDirectory 'msbuild.import.signals.json'
    $importSignals      = $null
    $previewErrors      = @()
    $knownStdOutNoise   = @()
    $gxImportLogReadStatus = 'ok'
    $gxImportLogReadError = $null

    try {
        $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
        $stdErrText = Read-TextFileSafe -PathValue $stdErrPath
        $stdErrNoiseClassification = Get-GeneXusMsBuildStderrNoiseClassification -Text $stdErrText
        $stdErrNoise    = $stdErrNoiseClassification.NoiseText
        $stdErrFiltered = $stdErrNoiseClassification.FilteredText
        $importedItems      = @(Get-MatchingLines -Text $stdOutText -Prefix '__IMPORTED_ITEM__=')
        $importWarningLines = @([regex]::Matches($stdOutText, '(?m)[^\r\n]*\(\d+,\d+\)\s*:\s*warning\s*:[^\r\n]*') | ForEach-Object { $_.Value.Trim() })
    }
    catch {
        $postProcessingFailed = $true
        $diagnosticDegraded = $true
        $postProcessingError  = $_.Exception.Message
        $diagnosticDegradedReason = ('Pos-processamento local falhou apos MSBuild: {0}' -f $postProcessingError)
        Add-StrategyTrace -Message ('Pos-processamento falhou apos MSBuild: {0}' -f $postProcessingError)
        if ($stdOutText) {
            try { $importedItems = @(Get-MatchingLines -Text $stdOutText -Prefix '__IMPORTED_ITEM__=') } catch {}
        }
    }

    $signalsScript = Join-Path $PSScriptRoot 'Read-MsBuildImportSignals.ps1'
    try {
        if (Test-Path -LiteralPath $signalsScript -PathType Leaf) {
            $signalsJson = & $signalsScript -StdOutPath $stdOutPath -StdErrPath $stdErrPath -ExpectedItems ($includeItemsArray -join ';') -Stage 'import-preview' -OutputPath $signalsPath -AsJson
            $signalsJsonText = $signalsJson | Out-String
            if (-not [string]::IsNullOrWhiteSpace($signalsJsonText)) {
                $importSignals = $signalsJsonText | ConvertFrom-Json
                if (($importedItems.Count -eq 0) -and ($null -ne $importSignals.importedItems)) {
                    $importedItems = @($importSignals.importedItems)
                }
                if ($null -ne $importSignals.PSObject.Properties['gxImportLogReadStatus']) {
                    $gxImportLogReadStatus = [string]$importSignals.gxImportLogReadStatus
                }
                if ($null -ne $importSignals.PSObject.Properties['gxImportLogReadError']) {
                    $gxImportLogReadError = $importSignals.gxImportLogReadError
                }
                if ($null -ne $importSignals.PSObject.Properties['errors']) {
                    $previewErrors = @($importSignals.errors)
                }
                if ($null -ne $importSignals.PSObject.Properties['knownStdOutNoise']) {
                    $knownStdOutNoise = @($importSignals.knownStdOutNoise)
                }
                if ($gxImportLogReadStatus -in @('locked', 'error')) {
                    $diagnosticDegraded = $true
                    $diagnosticDegradedReason = ('Leitura de GxImport.log degradada: {0}' -f $gxImportLogReadStatus)
                    Add-StrategyTrace -Message $diagnosticDegradedReason
                }
            }
        } else {
            $diagnosticDegraded = $true
            $diagnosticDegradedReason = 'Read-MsBuildImportSignals.ps1 nao encontrado; sinais compactos nao foram gerados.'
            Add-StrategyTrace -Message $diagnosticDegradedReason
        }
    }
    catch {
        $diagnosticDegraded = $true
        $diagnosticDegradedReason = ('Falha ao gerar signals.json: {0}' -f $_.Exception.Message)
        Add-StrategyTrace -Message $diagnosticDegradedReason
    }

    $setVersionFailed     = [bool]($stdOutText -match 'Set Active Version falhou')
    $setEnvironmentFailed = [bool]($stdOutText -match 'Set Active Environment falhou')

    $activeVersionOutput      = Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'"
    $activeEnvironmentOutput  = Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'"
    $missingEnvironmentOutput = Get-RegexValue -Text $stdOutText -Pattern "Ambiente '([^']+)' n[aã]o existe"

    if ($setVersionFailed) {
        $actualVersion = if (-not [string]::IsNullOrWhiteSpace($activeVersionOutput)) { $activeVersionOutput } else { '(desconhecida)' }
        Add-BlockingReason -Reason ("SetActiveVersion falhou — a versao '{0}' nao existe nesta KB. A versao ativa no momento da abertura era '{1}'. Para usar a versao ativa, omita o parametro -VersionName." -f $VersionName, $actualVersion)
    }

    if ($setEnvironmentFailed) {
        $actualEnvironment = if (-not [string]::IsNullOrWhiteSpace($activeEnvironmentOutput)) { $activeEnvironmentOutput } else { '(desconhecido)' }
        $requestedEnvironment = if (-not [string]::IsNullOrWhiteSpace($missingEnvironmentOutput)) { $missingEnvironmentOutput } else { $EnvironmentName }
        Add-BlockingReason -Reason ("SetActiveEnvironment falhou — o Environment '{0}' nao existe nesta KB. O Environment ativo no momento da abertura era '{1}'. Para usar o Environment ativo, omita o parametro -EnvironmentName." -f $requestedEnvironment, $actualEnvironment)
    }

    if ($previewErrors.Count -gt 0) {
        Add-WarningMessage -Message ('MSBuild emitiu {0} linha(s) com error: no log apesar de sucesso aparente do preview; ver previewErrors no diagnostico.' -f $previewErrors.Count)
    }

    $previewExitCode = Get-PreviewExitCode `
        -MsBuildExitCode $msBuildExitCode `
        -ResolvedUpdateFilePath $resolvedUpdateFilePath `
        -PreviewErrors $previewErrors

    $msBuildCategoryBBlocked = ($previewExitCode -eq $script:GeneXusMsBuildCategoryBExitCode)
    $operationalSubState = $null
    if ($msBuildCategoryBBlocked) {
        $operationalSubState = $script:PreviewOperationalSubStateCategoryB
    }

    if ($previewExitCode -eq 0) {
        if ($postProcessingFailed) {
            $status = 'preview apenas com falha no pos-processamento'
            $summary = 'Preview executado sem alterar a KB, mas o pós-processamento local falhou. Evidências do MSBuild preservadas.'
        } else {
            $status = 'preview apenas'
            $summary = 'Preview de importação executado sem alterar a KB.'
        }
    } elseif ($msBuildCategoryBBlocked) {
        $categoryBSummary = Get-GeneXusMsBuildCategoryBStatusSummary `
            -OperationLabel 'Preview de importação' `
            -ArtifactOnDisk $false `
            -ArtifactKind $null
        $status = $categoryBSummary.Status
        $summary = $categoryBSummary.Summary
        foreach ($reason in (Get-GeneXusMsBuildCategoryBBlockingReasons -MsBuildErrors $previewErrors -InvalidTypesRejected @() -StageLabel 'Preview')) {
            Add-BlockingReason -Reason $reason
        }
    } else {
        $status = 'falha operacional'
        $summary = 'Preview de importação falhou durante a execução.'
        if ($script:BlockingReasons.Count -eq 0) {
            Add-BlockingReason -Reason 'MSBuild falhou sem causa acionável classificada; consulte executionEvidence e logs brutos nos artefatos.'
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($resolvedUpdateFilePath) -and (Test-Path -LiteralPath $resolvedUpdateFilePath -PathType Leaf)) {
        Add-StrategyTrace -Message ('UpdateFile gerado em: {0}' -f $resolvedUpdateFilePath)
    }

    $diagnostic = [ordered]@{
        status = $status
        summary = $summary
        exitCode = $previewExitCode
        msBuildExitCode      = $msBuildExitCode
        executionEvidence = [ordered]@{
            msBuildExitCode = $msBuildExitCode
            msBuildFailed = ($msBuildExitCode -ne 0)
            wrapperExitCode = $previewExitCode
            StdOutPath = $stdOutPath
            StdErrPath = $stdErrPath
        }
        postProcessingFailed = $postProcessingFailed
        postProcessingError  = $postProcessingError
        diagnosticDegraded   = $diagnosticDegraded
        diagnosticDegradedReason = $diagnosticDegradedReason
        gxImportLogReadStatus = $gxImportLogReadStatus
        gxImportLogReadError = $gxImportLogReadError
        stage = 'import-preview'
        resolvedPaths = [ordered]@{
            GeneXusDir = $resolvedGeneXusDir
            MsBuildPath = $resolvedMsBuildPath
            KbPath = $resolvedKbPath
            XpzPath = $resolvedXpzPath
            WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
            LogPath = $resolvedLogPath
            UpdateFilePath = $resolvedUpdateFilePath
            KbIntelligenceIndexPath = if ($preflightResult.preflightEnabled) { $preflightResult.indexPath } else { $null }
        }
        objectListPreflight = ConvertTo-GeneXusObjectListPreflightLogSection -PreflightResult $preflightResult
        pathActions = $probeStage.Diagnostic.pathActions
        requestedContext = [ordered]@{
            VersionName = $VersionName
            EnvironmentName = $EnvironmentName
            ImportType = $ImportType
            LanguageTranslations = $LanguageTranslations
            AutomaticBackup = $AutomaticBackup
            ImportKbInformation = $ImportKbInformation
            IncludeItems = $IncludeItems
            ExcludeItems = $ExcludeItems
            StartWatcherRequested = $StartWatcher.IsPresent
            ParallelKbRoot = $ParallelKbRoot
            IndexPath = $IndexPath
        }
        observedContext = [ordered]@{
            ActiveVersion = $activeVersionOutput
            ActiveEnvironment = $activeEnvironmentOutput
            pathEnrichment = $script:PathEnrichment
        }
        artifacts = [ordered]@{
            ProbeLogPath = $probeLogPath
            MsBuildFilePath = $msBuildFilePath
            StdOutPath = $stdOutPath
            StdErrPath = $stdErrPath
            SignalsPath = $signalsPath
            ExecutionLogPath = $resolvedLogPath
        }
        watcherContext = $script:WatcherContext
        timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
        importedItems = $importedItems
        previewErrors = @($previewErrors)
        knownStdOutNoise = @($knownStdOutNoise)
        operationalSubState = $operationalSubState
        msBuildCategoryBBlocked = $msBuildCategoryBBlocked
        stdoutSignals = [ordered]@{
            importWarnings = $importWarningLines
            previewErrors = @($previewErrors)
            knownStdOutNoise = @($knownStdOutNoise)
            compactSignals = $importSignals
        }
        stderrContent        = Split-NonEmptyLines -Text $stdErrFiltered
        stderrFilteredNoise  = Split-NonEmptyLines -Text $stdErrNoise
        blockingReasons = @($script:BlockingReasons)
        warnings = @($script:Warnings)
        strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
    }

    try {
        $json = ConvertTo-JsonText -InputObject $diagnostic
    }
    catch {
        $postProcessingFailed = $true
        $diagnosticDegraded = $true
        $postProcessingError  = ('Falha ao serializar diagnostico apos MSBuild: {0}' -f $_.Exception.Message)
        $diagnosticDegradedReason = $postProcessingError
        Add-StrategyTrace -Message $postProcessingError
        if ($previewExitCode -eq 0) {
            $status = 'preview apenas com falha no pos-processamento'
            $summary = 'Preview executado sem alterar a KB, mas a serialização do diagnóstico falhou. Evidências primárias preservadas no log bruto.'
        }
        $importedItemsForFallback = @()
        try { $importedItemsForFallback = @($importedItems) } catch {}
        $fallback = [ordered]@{
            status               = $status
            summary              = $summary
            exitCode             = $previewExitCode
            msBuildExitCode      = $msBuildExitCode
            executionEvidence    = [ordered]@{
                msBuildExitCode = $msBuildExitCode
                msBuildFailed   = ($msBuildExitCode -ne 0)
                wrapperExitCode = $previewExitCode
                StdOutPath      = $stdOutPath
                StdErrPath      = $stdErrPath
            }
            postProcessingFailed = $true
            postProcessingError  = $postProcessingError
            diagnosticDegraded   = $true
            diagnosticDegradedReason = $diagnosticDegradedReason
            stage                = 'import-preview'
            artifacts            = [ordered]@{
                MsBuildStdoutLogPath = $stdOutPath
                MsBuildStderrLogPath = $stdErrPath
                SignalsPath          = $signalsPath
                ExecutionLogPath     = $resolvedLogPath
                UpdateFilePath       = $resolvedUpdateFilePath
            }
            watcherContext       = $script:WatcherContext
            timing               = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            importedItems        = $importedItemsForFallback
            note                 = 'Diagnostico completo nao pode ser serializado; consultar msbuild.stdout.log para marcas __IMPORTED_ITEM__ como evidencia primaria.'
        }
        try {
            $json = $fallback | ConvertTo-Json -Depth 3
        }
        catch {
            $msBuildExitCodeText = if ($null -eq $msBuildExitCode) { 'null' } else { [string]$msBuildExitCode }
            $msBuildFailedText = if ($null -eq $msBuildExitCode) { 'null' } elseif ($msBuildExitCode -ne 0) { 'true' } else { 'false' }
            $json = '{"status":"' + $status + '","exitCode":' + $previewExitCode + ',"msBuildExitCode":' + $msBuildExitCodeText + ',"executionEvidence":{"msBuildExitCode":' + $msBuildExitCodeText + ',"msBuildFailed":' + $msBuildFailedText + ',"wrapperExitCode":' + $previewExitCode + '},"postProcessingFailed":true,"note":"Fallback minimo: serializacao do fallback tambem falhou. Consultar msbuild.stdout.log."}'
        }
    }
    try { Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json } catch {}
    Write-Output $json
    exit $previewExitCode
}
catch {
    $failure = [ordered]@{
        status = 'falha operacional'
        summary = 'Falha interna do script antes de concluir o preview de importação.'
        exitCode = 90
        msBuildExitCode      = $null
        postProcessingFailed = $false
        postProcessingError  = $null
        diagnosticDegraded   = $true
        diagnosticDegradedReason = $_.Exception.Message
        stage = 'import-preview'
        resolvedPaths = [ordered]@{
            GeneXusDir = (Get-FullPathSafe -PathValue $GeneXusDir)
            MsBuildPath = (Get-FullPathSafe -PathValue $MsBuildPath)
            KbPath = (Get-FullPathSafe -PathValue $KbPath)
            XpzPath = (Get-FullPathSafe -PathValue $InputPath)
            WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
            LogPath = $resolvedLogPath
            UpdateFilePath = (Get-FullPathSafe -PathValue $UpdateFilePath)
        }
        pathActions = [ordered]@{
            WorkingDirectory = 'blocked-internal-error'
        }
        requestedContext = [ordered]@{
            VersionName = $VersionName
            EnvironmentName = $EnvironmentName
            ImportType = $ImportType
            LanguageTranslations = $LanguageTranslations
            AutomaticBackup = $AutomaticBackup
            ImportKbInformation = $ImportKbInformation
            IncludeItems = $IncludeItems
            ExcludeItems = $ExcludeItems
            StartWatcherRequested = $StartWatcher.IsPresent
        }
        artifacts = [ordered]@{
            ProbeLogPath = $null
            MsBuildFilePath = $null
            StdOutPath = $null
            StdErrPath = $null
            SignalsPath = $null
            ExecutionLogPath = $resolvedLogPath
        }
        watcherContext = $script:WatcherContext
        timing = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
        importedItems = @()
        stdoutSignals = [ordered]@{
            importWarnings = @()
            compactSignals = $null
        }
        stderrContent        = @()
        stderrFilteredNoise  = @()
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
    }
    catch {
    }

    Write-Output $failureJson
    exit 90
}
