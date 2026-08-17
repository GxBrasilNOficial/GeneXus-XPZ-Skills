#requires -Version 7.4

<#
.SYNOPSIS
Executa verificação leve pós-import via MSBuild: SpecifyAll seguido de GenerateOnly.

.DESCRIPTION
Implementa a etapa de verificação leve da skill xpz-msbuild-build: reaproveita o probe
Test-GeneXusMsBuildSetup.ps1, abre a KB em modo headless controlado, posiciona versão e
Environment quando informados, executa SpecifyAll seguido de GenerateOnly com parâmetros
explícitos e fecha a KB. Não compila e não executa reorg.

Classifica o resultado em cinco categorias:
  - specify e generate concluídos
  - operação concluída, pendente de confirmação funcional
  - erro de specify
  - erro de generate
  - KB inacessível

.PARAMETER KbPath
Caminho da KB a ser usada na verificação.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, usa fallback do probe.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, usa fallback do probe.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes da verificação.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes da verificação. Em KB com kb_environment_count
maior que 1 em kb-source-metadata.md, e obrigatório (direto ou via deployment_environment_name
gravado pelo xpz-kb-parallel-setup).

.PARAMETER ParallelKbRoot
Raiz da pasta paralela da KB para resolver kb-source-metadata.md sem inventario em runtime
(quando o gate de deploy bin estiver ativo, também le kb_environment_web_dirs).

.PARAMETER KbMetadataPath
Caminho explicito para kb-source-metadata.md; prevalece sobre -ParallelKbRoot.

.PARAMETER PostImportDeployValidation
Quando presente, ativa gate de validação deploy pos-import por familia de deployment_hosting_kind:
.NET checa o web\bin resolvido por kb_environment_web_dirs; java-tomcat roda o co-gate Java no
WEB-INF\classes externo (kb_environment_servlet_dirs/_app_package) — exit 49 se desatualizado.
Metadata sem o mapeamento bloqueia a resolucao (status unknown); reconciliar via xpz-kb-parallel-setup.

.PARAMETER SkipDeployBinCheck
Pula a checagem de publicacao do environment de deploy (.NET: web\bin; java-tomcat: WEB-INF\classes).

.PARAMETER StrictDeployBinCheck
Forca o gate de publicacao (.NET: web\bin; java-tomcat: co-gate WEB-INF\classes) mesmo fora do fluxo pos-import.

.PARAMETER ForceRebuild
Quando true, força a regeneração de TODOS os objetos da KB, independentemente de mudança.
Equivale a "Rebuild All" da IDE (não a "Build All"): muda a semântica de SpecifyAll/GenerateOnly
incremental para regeneração total. Em KB grande pode durar horas e regenerar centenas/milhares
de objetos, incluindo subtype groups. Default: false.

Operação ampla bloqueada por política: ForceRebuild=true só pode ser usado em conjunto com
-AllowWideRebuild e confirmação explícita por frase exata do usuário (modo interativo) ou
-AllowWideRebuild -ConfirmWideRebuild (modo não-interativo). Tentativa sem -AllowWideRebuild
é bloqueada com exit 46.

.PARAMETER DetailedNavigation
Quando true, executa navegação detalhada. Default: false. Opção cara bloqueada por
política: só pode ser usada em conjunto com -AllowCostlyBuildOptions e confirmação
explícita do usuário.

.PARAMETER AllowWideRebuild
Switch. Único caminho autorizado para habilitar -ForceRebuild true. Em modo interativo
(sem -ConfirmWideRebuild), exige que o usuário digite no terminal a frase exata:
    entendo que isto pode regerar a KB inteira e aceito o custo
Em modo não-interativo (com -ConfirmWideRebuild), a confirmação é feita pelo chamador
via parâmetro. Sem este switch, -ForceRebuild true é bloqueado por política (exit 46).

.PARAMETER ConfirmWideRebuild
Switch. Usado em conjunto com -AllowWideRebuild para dispensar o Read-Host interativo
da frase de confirmação. Destina-se exclusivamente a processos desanexados onde não
há terminal disponível. Usar -ConfirmWideRebuild sem -AllowWideRebuild é bloqueado
por política (exit 46). O chamador é responsável por obter confirmação explícita do
usuário humano com a frase exata antes de passar -ConfirmWideRebuild — este parâmetro
não dispensa a confirmação, apenas muda o canal.

.PARAMETER AllowCostlyBuildOptions
Switch. Único caminho autorizado para habilitar -DetailedNavigation true sem execução
acidental. Em modo interativo exige frase exata:
    entendo que estas opções podem ampliar muito o custo do build e aceito executar
Em modo não-interativo requer -ConfirmCostlyBuildOptions.

.PARAMETER ConfirmCostlyBuildOptions
Switch. Usado em conjunto com -AllowCostlyBuildOptions para dispensar o Read-Host
interativo da frase de confirmação. Proibido sem -AllowCostlyBuildOptions. O chamador
é responsável por obter confirmação explícita do usuário humano com a frase exata.

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
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$KbPath,

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$VersionName,

    [string]$EnvironmentName,

    [ValidateSet('true', 'false')]
    [string]$ForceRebuild = 'false',

    [ValidateSet('true', 'false')]
    [string]$DetailedNavigation = 'false',

    [switch]$AllowWideRebuild,

    [switch]$ConfirmWideRebuild,

    [switch]$AllowCostlyBuildOptions,

    [switch]$ConfirmCostlyBuildOptions,

    [switch]$VerboseLog,

    [string]$MonitorLogPath,

    [switch]$StartWatcher,

    [ValidateRange(1, 60)]
    [int]$WatcherIntervalSeconds = 5,

    [ValidateRange(30, 3600)]
    [int]$WatcherSilenceThresholdSeconds = 120,

    [string]$ParallelKbRoot,

    [string]$KbMetadataPath,

    [switch]$PostImportDeployValidation,

    [switch]$SkipDeployBinCheck,

    [switch]$StrictDeployBinCheck
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

$gamPlatformsSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildGamPlatformsSupport.ps1'
if (-not (Test-Path -LiteralPath $gamPlatformsSupportPath -PathType Leaf)) {
    throw "GAM Platforms support script not found: $gamPlatformsSupportPath"
}
. $gamPlatformsSupportPath

$stderrNoiseSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildStderrNoiseSupport.ps1'
if (-not (Test-Path -LiteralPath $stderrNoiseSupportPath -PathType Leaf)) {
    throw "MSBuild stderr noise support script not found: $stderrNoiseSupportPath"
}
. $stderrNoiseSupportPath

$postBuildEventsSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildPostBuildEventsSupport.ps1'
if (-not (Test-Path -LiteralPath $postBuildEventsSupportPath -PathType Leaf)) {
    throw "Post-build events support script not found: $postBuildEventsSupportPath"
}
. $postBuildEventsSupportPath

$deploymentEnvironmentSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusKbDeploymentEnvironmentSupport.ps1'
if (-not (Test-Path -LiteralPath $deploymentEnvironmentSupportPath -PathType Leaf)) {
    throw "Deployment environment support script not found: $deploymentEnvironmentSupportPath"
}
. $deploymentEnvironmentSupportPath

$deployBinSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusKbDeployBinSupport.ps1'
if (-not (Test-Path -LiteralPath $deployBinSupportPath -PathType Leaf)) {
    throw "Deploy bin support script not found: $deployBinSupportPath"
}
. $deployBinSupportPath

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

    $probeOutput = & $probeScriptPath @probeArgs
    $probeExitCode = $LASTEXITCODE
    $probeJson = ($probeOutput -join [Environment]::NewLine)
    $probeDiagnostic = $probeJson | ConvertFrom-Json -Depth 8

    return [ordered]@{
        ExitCode   = $probeExitCode
        Json       = $probeJson
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
    $baseDirectory = Join-Path $tempRoot 'xpz-msbuild-build'
    [System.IO.Directory]::CreateDirectory($baseDirectory) | Out-Null
    $artifactDirectory = Join-Path $baseDirectory ('gx-specifygenerate-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function New-MsBuildProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath
    )

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEscaped     = Escape-Xml -Value $targetsPath
    $kbPathEscaped      = Escape-Xml -Value $ResolvedKbPath
    $versionEscaped     = Escape-Xml -Value $VersionName
    $environmentEscaped = Escape-Xml -Value $EnvironmentName
    $forceRebuildEscaped       = Escape-Xml -Value $ForceRebuild
    $detailedNavigationEscaped = Escape-Xml -Value $DetailedNavigation

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEscaped" />

  <PropertyGroup>
    <KBPath>$kbPathEscaped</KBPath>
    <KBVersion>$versionEscaped</KBVersion>
    <KBEnvironment>$environmentEscaped</KBEnvironment>
    <ForceRebuild>$forceRebuildEscaped</ForceRebuild>
    <DetailedNavigation>$detailedNavigationEscaped</DetailedNavigation>
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
    <SpecifyAll ForceRebuild="`$(ForceRebuild)" DetailedNavigation="`$(DetailedNavigation)" CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="SpecifyOutput" />
    </SpecifyAll>
    <Message Text="__SPECIFY_DONE__=true" Importance="High" />
    <GenerateOnly CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="GenerateOutput" />
    </GenerateOnly>
    <Message Text="__GENERATE_DONE__=true" Importance="High" />
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

function Resolve-BuildStatus {
    param(
        [int]$MsBuildExitCode,
        [bool]$SpecifyDone,
        [bool]$GenerateDone,
        [string]$StdOutText,
        [string]$StdErrText,
        [bool]$PostBuildShouldDowngrade = $false
    )

    # Padrão bloqueante de maior prioridade: reorg real executada dentro do SpecifyAll.
    # SpecifyAll pode executar Database Impact Analysis, gerar bldReorganization.cs e
    # executar a reorg internamente quando há alterações estruturais pendentes no banco.
    # Esse comportamento é intrínseco à task GeneXus e independe de flags do wrapper.
    if ($StdOutText -match 'Reorganiza') {
        Add-WarningMessage -Message 'Padrão "Reorganiza" detectado em stdout: SpecifyAll executou reorganização real de banco de dados. Confirmar com o usuário se a reorg era esperada e autorizada antes de declarar qualquer sucesso.'
        return [ordered]@{
            Status   = 'reorg detectada ou executada'
            Summary  = 'SpecifyAll disparou reorganização real de banco de dados (padrão "Reorganiza" encontrado em stdout). Este comportamento é intrínseco à task GeneXus quando há alterações estruturais pendentes. Não declarar sucesso sem confirmação explícita do usuário.'
            ExitCode = 43
        }
    }

    # Eventos pos-build: a classificação (registrado x inesperado x fallback de som) e o
    # detalhamento por linha ficam no chamador; aqui chega apenas o veredito agregado em
    # $PostBuildShouldDowngrade, que entra como impedimento somente quando ha evento
    # inesperado/nao reconhecido.

    # Stderr não vazio: qualquer conteúdo em stderr é sinal de risco, independente do exitCode.
    $stderrNonEmpty = -not [string]::IsNullOrWhiteSpace($StdErrText)
    if ($stderrNonEmpty) {
        Add-WarningMessage -Message ('stderr não vazio: conteúdo presente impediu classificação limpa. Inspecionar stderr antes de concluir sobre o resultado.')
    }

    $alertPatterns = @('Access denied')
    $foundAlerts = @($alertPatterns | Where-Object {
        ($StdOutText -match [regex]::Escape($_)) -or ($StdErrText -match [regex]::Escape($_))
    })

    $hasImpediment = ($foundAlerts.Count -gt 0) -or $stderrNonEmpty -or $PostBuildShouldDowngrade

    if ($MsBuildExitCode -eq 0 -and $SpecifyDone -and $GenerateDone -and -not $hasImpediment) {
        return [ordered]@{
            Status   = 'specify e generate concluídos'
            Summary  = 'SpecifyAll e GenerateOnly concluídos sem erro operacional.'
            ExitCode = 0
        }
    }

    if ($MsBuildExitCode -eq 0 -and $SpecifyDone -and $GenerateDone) {
        foreach ($alert in $foundAlerts) {
            Add-WarningMessage -Message ('Padrão de alerta em stdout/stderr impede classificação limpa: "{0}".' -f $alert)
        }
        return [ordered]@{
            Status   = 'operação concluída, pendente de confirmação funcional'
            Summary  = 'SpecifyAll e GenerateOnly concluídos com exitCode 0, mas impedimentos detectados em stdout/stderr (stderr não vazio, padrões de alerta ou eventos pós-build). Validação funcional necessária antes de concluir sobre o resultado.'
            ExitCode = 0
        }
    }

    if (-not $SpecifyDone) {
        return [ordered]@{
            Status   = 'KB inacessível'
            Summary  = 'KB não pôde ser aberta ou SpecifyAll falhou antes de iniciar.'
            ExitCode = 40
        }
    }

    if ($SpecifyDone -and -not $GenerateDone) {
        return [ordered]@{
            Status   = 'erro de generate'
            Summary  = 'SpecifyAll concluído mas GenerateOnly falhou.'
            ExitCode = 42
        }
    }

    # SpecifyDone=false coberto acima; chegou aqui apenas se exitCode<>0 com ambos done
    return [ordered]@{
        Status   = 'erro de specify'
        Summary  = 'SpecifyAll falhou durante a execução.'
        ExitCode = 41
    }
}

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings        = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace   = New-Object System.Collections.Generic.List[string]
$script:PathEnrichment  = [ordered]@{
    applied        = $false
    subdirsAdded   = @()
    subdirsSkipped = @()
}
$script:TimingLog       = [ordered]@{}
$script:WatcherContext  = New-GeneXusMsBuildWatcherContext -StartWatcherRequested $StartWatcher.IsPresent
$script:DeploymentEnvironmentContext = $null

$confirmWideRebuildMode    = $null
$allowWideRebuildConfirmed = $false
$confirmCostlyBuildOptionsMode = $null
$allowCostlyBuildOptionsConfirmed = $false
$msBuildExitCode = $null
$stdOutText = ''
$stdErrText = ''
$postProcessingFailed = $false
$postProcessingError = $null
$buildStatus = $null
$msBuildCategoryBBlocked = $false
$operationalSubStateSpecify = $null
$activeVersionOutput = $null
$activeEnvironmentOutput = $null
$specifyDone = $false
$generateDone = $false

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

$logPathRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $resolvedLogPath
if ($logPathRejection.rejected) {
    Write-Output (New-GeneXusMsBuildLogPathBlockJson -WrapperName 'Invoke-GeneXusKbSpecifyGenerate.ps1' -ResolvedLogPath $resolvedLogPath -Reason $logPathRejection.reason)
    exit 50
}
$script:TimingLog['scriptStart'] = Get-GeneXusMsBuildNowIso

try {
    $watcherParameterValidation = Test-GeneXusMsBuildWatcherParameters -StartWatcherRequested $StartWatcher.IsPresent -MonitorLogPath $MonitorLogPath
    if (-not $watcherParameterValidation.ok) {
        Add-BlockingReason -Reason $watcherParameterValidation.reason
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            causeId          = $watcherParameterValidation.causeId
            summary          = $watcherParameterValidation.summary
            exitCode         = 46
            stage            = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName           = $VersionName
                EnvironmentName       = $EnvironmentName
                ForceRebuild          = $ForceRebuild
                DetailedNavigation    = $DetailedNavigation
                StartWatcherRequested = $StartWatcher.IsPresent
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
                MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
                KbPath           = (Get-FullPathSafe -PathValue $KbPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
            }
            artifacts        = [ordered]@{ ExecutionLogPath = $resolvedLogPath }
            watcherContext   = $script:WatcherContext
            timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
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

    # Gate de segurança: -ConfirmWideRebuild sem -AllowWideRebuild não tem sentido e é bloqueado por política
    if ($ConfirmWideRebuild.IsPresent -and -not $AllowWideRebuild.IsPresent) {
        Add-BlockingReason -Reason '-ConfirmWideRebuild so pode ser usado em conjunto com -AllowWideRebuild. Para confirmar regeneracao ampla interativamente, use apenas -AllowWideRebuild. Para modo nao-interativo, use -AllowWideRebuild -ConfirmWideRebuild apos confirmar a operacao com o usuario humano.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = '-ConfirmWideRebuild requer -AllowWideRebuild. Execute novamente com -AllowWideRebuild -ConfirmWideRebuild apos confirmar a operacao com o usuario humano.'
            exitCode         = 46
            stage            = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ForceRebuild               = $ForceRebuild
                DetailedNavigation         = $DetailedNavigation
                AllowWideRebuildRequested  = $false
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
                MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
                KbPath           = (Get-FullPathSafe -PathValue $KbPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
            }
            pathActions      = [ordered]@{ WorkingDirectory = 'blocked-policy' }
            artifacts        = [ordered]@{
                ProbeLogPath     = $null
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
            }
            watcherContext   = $script:WatcherContext
            timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
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

    # Gate de segurança: -ConfirmCostlyBuildOptions sem -AllowCostlyBuildOptions não tem sentido
    if ($ConfirmCostlyBuildOptions.IsPresent -and -not $AllowCostlyBuildOptions.IsPresent) {
        Add-BlockingReason -Reason '-ConfirmCostlyBuildOptions so pode ser usado em conjunto com -AllowCostlyBuildOptions. Para confirmar opcoes caras interativamente, use apenas -AllowCostlyBuildOptions. Para modo nao-interativo, use -AllowCostlyBuildOptions -ConfirmCostlyBuildOptions apos confirmar a operacao com o usuario humano.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = '-ConfirmCostlyBuildOptions requer -AllowCostlyBuildOptions.'
            exitCode         = 46
            stage            = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName                     = $VersionName
                EnvironmentName                 = $EnvironmentName
                ForceRebuild                    = $ForceRebuild
                DetailedNavigation              = $DetailedNavigation
                AllowWideRebuildRequested       = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed       = $false
                ConfirmWideRebuildMode          = $confirmWideRebuildMode
                AllowCostlyBuildOptionsRequested = $false
                AllowCostlyBuildOptionsConfirmed = $false
                ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
                MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
                KbPath           = (Get-FullPathSafe -PathValue $KbPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
            }
            pathActions      = [ordered]@{ WorkingDirectory = 'blocked-policy' }
            artifacts        = [ordered]@{
                ProbeLogPath     = $null
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
            }
            watcherContext   = $script:WatcherContext
            timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
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

    # Gate de segurança: -ForceRebuild=true sem -AllowWideRebuild é bloqueado por política
    # ForceRebuild=true muda SpecifyAll/GenerateOnly de incremental para regeneracao total
    # de TODOS os objetos da KB. Em KB grande pode levar horas e regenerar centenas/milhares.
    if ($ForceRebuild -eq 'true' -and -not $AllowWideRebuild.IsPresent) {
        Add-BlockingReason -Reason 'ForceRebuild=true muda SpecifyAll/GenerateOnly de incremental para regeneracao TOTAL de todos os objetos da KB. Em KB grande pode levar horas e regenerar centenas/milhares de objetos. So pode ser habilitado via -AllowWideRebuild com confirmacao explicita do usuario. Para verificacao incremental, omita ForceRebuild ou use ForceRebuild=false.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = 'ForceRebuild=true requer -AllowWideRebuild e confirmacao explicita do usuario por frase exata. Para verificacao incremental, omita ForceRebuild.'
            exitCode         = 46
            stage            = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ForceRebuild               = $ForceRebuild
                DetailedNavigation         = $DetailedNavigation
                AllowWideRebuildRequested  = $false
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
                MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
                KbPath           = (Get-FullPathSafe -PathValue $KbPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
            }
            pathActions      = [ordered]@{ WorkingDirectory = 'blocked-policy' }
            artifacts        = [ordered]@{
                ProbeLogPath     = $null
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
            }
            watcherContext   = $script:WatcherContext
            timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
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

    $costlyBuildOptionsRequested = ($DetailedNavigation -eq 'true')

    # Gate de segurança: opções que ampliam custo da verificação não passam silenciosamente.
    if ($costlyBuildOptionsRequested -and -not $AllowCostlyBuildOptions.IsPresent) {
        Add-BlockingReason -Reason 'Opcao cara de build solicitada sem -AllowCostlyBuildOptions: DetailedNavigation=true. DetailedNavigation=true executa navegacao detalhada durante a especificacao; em KB grande pode transformar validacao cotidiana em execucao de alto custo. Confirme explicitamente antes de prosseguir.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = 'DetailedNavigation=true requer -AllowCostlyBuildOptions e confirmacao explicita do usuario.'
            exitCode         = 46
            stage            = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName                     = $VersionName
                EnvironmentName                 = $EnvironmentName
                ForceRebuild                    = $ForceRebuild
                DetailedNavigation              = $DetailedNavigation
                CostlyBuildOptions              = @('DetailedNavigation=true')
                AllowWideRebuildRequested       = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed       = $false
                ConfirmWideRebuildMode          = $confirmWideRebuildMode
                AllowCostlyBuildOptionsRequested = $false
                AllowCostlyBuildOptionsConfirmed = $false
                ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
                MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
                KbPath           = (Get-FullPathSafe -PathValue $KbPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
            }
            pathActions      = [ordered]@{ WorkingDirectory = 'blocked-policy' }
            artifacts        = [ordered]@{
                ProbeLogPath     = $null
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
            }
            watcherContext   = $script:WatcherContext
            timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
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

    if ($costlyBuildOptionsRequested -and $AllowCostlyBuildOptions.IsPresent -and $ConfirmCostlyBuildOptions.IsPresent) {
        $allowCostlyBuildOptionsConfirmed = $true
        $confirmCostlyBuildOptionsMode = 'parameter'
    }

    $envResolution = Resolve-GeneXusKbValidationEnvironment -EnvironmentName $EnvironmentName -KbMetadataPath $KbMetadataPath -ParallelKbRoot $ParallelKbRoot
    $script:DeploymentEnvironmentContext = $envResolution.Context

    if (-not $envResolution.Proceed) {
        foreach ($reason in $envResolution.BlockingReasons) {
            Add-BlockingReason -Reason $reason
        }

        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = $envResolution.Summary
            exitCode         = 46
            stage            = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ParallelKbRoot             = $ParallelKbRoot
                KbMetadataPath             = $KbMetadataPath
                ForceRebuild               = $ForceRebuild
                DetailedNavigation         = $DetailedNavigation
                deploymentEnvironmentContext = $envResolution.Context
                AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
                AllowCostlyBuildOptionsRequested = $AllowCostlyBuildOptions.IsPresent
                AllowCostlyBuildOptionsConfirmed = $allowCostlyBuildOptionsConfirmed
                ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
                MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
                KbPath           = (Get-FullPathSafe -PathValue $KbPath)
                WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
                LogPath          = $resolvedLogPath
                KbMetadataPath   = $envResolution.Context.kbSourceMetadataPath
                ParallelKbRoot   = (Get-FullPathSafe -PathValue $ParallelKbRoot)
            }
            pathActions      = [ordered]@{ WorkingDirectory = 'blocked-policy' }
            artifacts        = [ordered]@{ ExecutionLogPath = $resolvedLogPath }
            watcherContext   = $script:WatcherContext
            timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
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

    if (-not [string]::IsNullOrWhiteSpace($envResolution.EnvironmentName)) {
        $EnvironmentName = $envResolution.EnvironmentName
        if ($envResolution.Context.deploymentEnvironmentSource -eq 'kb-source-metadata') {
            Add-StrategyTrace -Message 'EnvironmentName aplicado a partir de deployment_environment_name em kb-source-metadata.md.'
        }
    }

    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional.'
    }

    $artifactDirectory = New-ArtifactDirectory
    $probeLogPath = Join-Path $artifactDirectory 'probe-stage.json'
    $script:TimingLog['probeStart'] = Get-GeneXusMsBuildNowIso
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath
    $script:TimingLog['probeEnd'] = Get-GeneXusMsBuildNowIso

    Add-StrategyTrace -Message ('Probe executado antes da verificação com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe não apto para prosseguir bloqueou a verificação.'
        $probeDiagnostic = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status           = 'não apto para prosseguir'
            summary          = 'Probe bloqueou a verificação de specify e generate.'
            exitCode         = $probeStage.ExitCode
            stage            = 'probe'
            requestedContext = [ordered]@{
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ForceRebuild               = $ForceRebuild
                DetailedNavigation         = $DetailedNavigation
                AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                SpecifyDone       = $false
                GenerateDone      = $false
                pathEnrichment    = $script:PathEnrichment
            }
            resolvedPaths    = [ordered]@{
                GeneXusDir       = $probeDiagnostic.resolvedPaths.GeneXusDir
                MsBuildPath      = $probeDiagnostic.resolvedPaths.MsBuildPath
                KbPath           = $probeDiagnostic.resolvedPaths.KbPath
                WorkingDirectory = $probeDiagnostic.resolvedPaths.WorkingDirectory
                LogPath          = $resolvedLogPath
            }
            pathActions      = $probeDiagnostic.pathActions
            artifacts        = [ordered]@{
                ProbeLogPath      = $probeLogPath
                MsBuildFilePath   = $null
                StdOutPath        = $null
                StdErrPath        = $null
                ExecutionLogPath  = $resolvedLogPath
            }
            watcherContext   = $script:WatcherContext
            timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            blockingReasons  = @($probeDiagnostic.blockingReasons + $script:BlockingReasons)
            warnings         = @($probeDiagnostic.warnings)
            strategyTrace    = @($probeDiagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        }
        Write-Output $blockedJson
        exit $probeStage.ExitCode
    }

    $resolvedGeneXusDir  = [string]$probeStage.Diagnostic.resolvedPaths.GeneXusDir
    $resolvedMsBuildPath = [string]$probeStage.Diagnostic.resolvedPaths.MsBuildPath
    $resolvedKbPath      = [string]$probeStage.Diagnostic.resolvedPaths.KbPath

    # Enriquecer $env:PATH com subdirs do GeneXus que hospedam tools chamadas internamente
    # por Process.Start sem caminho absoluto (gxexec, UpdConfigWeb, BuildService, Reor.exe).
    # Ver nota detalhada no wrapper irmao Invoke-GeneXusKbBuildAll.ps1. Em SpecifyGenerate
    # puro (sem compile) a falha pode aparecer se SpecifyAll disparar reorg internamente.
    $gxSubPathCandidates = @(
        $resolvedGeneXusDir,
        (Join-Path $resolvedGeneXusDir 'gxnet'),
        (Join-Path $resolvedGeneXusDir 'gxnet\bin'),
        (Join-Path $resolvedGeneXusDir 'gxnetcore')
    )
    $gxSubPathsAdded   = @($gxSubPathCandidates | Where-Object { Test-Path -LiteralPath $_ })
    $gxSubPathsSkipped = @($gxSubPathCandidates | Where-Object { -not (Test-Path -LiteralPath $_) })
    if ($gxSubPathsAdded.Count -gt 0) {
        $env:PATH = ($gxSubPathsAdded -join ';') + ';' + $env:PATH
    }
    $script:PathEnrichment = [ordered]@{
        applied        = ($gxSubPathsAdded.Count -gt 0)
        subdirsAdded   = $gxSubPathsAdded
        subdirsSkipped = $gxSubPathsSkipped
    }
    if ($gxSubPathsSkipped.Count -gt 0) {
        Add-WarningMessage -Message ("Subdirs esperados do GeneXus ausentes em '{0}': {1}. Instalacao pode estar nao-padrao; tools internas chamadas por Process.Start sem caminho absoluto (gxexec, UpdConfigWeb) podem falhar." -f $resolvedGeneXusDir, ($gxSubPathsSkipped -join ', '))
    }
    Add-StrategyTrace -Message ("PATH enriquecido com subdirs do GeneXus para tools internas: [{0}]. Subdirs ausentes: [{1}]." -f ($gxSubPathsAdded -join ', '), ($gxSubPathsSkipped -join ', '))

    # Confirmação explícita de regeneração ampla (ForceRebuild=true + -AllowWideRebuild)
    # -AllowWideRebuild só autoriza ForceRebuild=true; sozinho com ForceRebuild=false e redundante.
    if ($ForceRebuild -eq 'true' -and $AllowWideRebuild.IsPresent) {
        if ($ConfirmWideRebuild.IsPresent) {
            $allowWideRebuildConfirmed = $true
            $confirmWideRebuildMode    = 'parameter'
            Add-StrategyTrace -Message 'AllowWideRebuild confirmado via -ConfirmWideRebuild (modo nao-interativo). ForceRebuild=true autorizado.'
        } else {
            $confirmWideRebuildMode = 'interactive'
            Write-Host ''
            Write-Host 'AVISO: O parametro -AllowWideRebuild foi especificado e ForceRebuild=true.'
            Write-Host ''
            Write-Host ('KB alvo:      {0}' -f $resolvedKbPath)
            Write-Host ('GeneXusDir:   {0}' -f $resolvedGeneXusDir)
            Write-Host ''
            Write-Host 'ForceRebuild=true muda SpecifyAll/GenerateOnly de incremental para regeneracao'
            Write-Host 'TOTAL de TODOS os objetos da KB. Em KB grande pode levar horas e regenerar'
            Write-Host 'centenas/milhares de objetos, incluindo subtype groups.'
            Write-Host ''
            Write-Host 'Para confirmar, digite EXATAMENTE a frase abaixo (sem aspas):'
            Write-Host '    entendo que isto pode regerar a KB inteira e aceito o custo'
            Write-Host ''
            $wideRebuildConfirmation = Read-Host 'Confirmacao'

            if ($wideRebuildConfirmation -ne 'entendo que isto pode regerar a KB inteira e aceito o custo') {
                Add-BlockingReason -Reason 'Regeneracao ampla (ForceRebuild=true) nao confirmada pelo usuario com a frase exata. Execucao cancelada por seguranca.'
                $aborted = [ordered]@{
                    status           = 'cancelado pelo usuario'
                    summary          = 'Regeneracao ampla nao confirmada pelo usuario. SpecifyAll/GenerateOnly cancelado por seguranca.'
                    exitCode         = 47
                    stage            = 'pre-specify-generate'
                    requestedContext = [ordered]@{
                        VersionName                = $VersionName
                        EnvironmentName            = $EnvironmentName
                        ForceRebuild               = $ForceRebuild
                        DetailedNavigation         = $DetailedNavigation
                        AllowWideRebuildRequested  = $true
                        AllowWideRebuildConfirmed  = $false
                        ConfirmWideRebuildMode     = $confirmWideRebuildMode
                    }
                    observedContext  = [ordered]@{
                        ActiveVersion     = $null
                        ActiveEnvironment = $null
                        SpecifyDone       = $false
                        GenerateDone      = $false
                        pathEnrichment    = $script:PathEnrichment
                    }
                    resolvedPaths    = [ordered]@{
                        GeneXusDir       = $resolvedGeneXusDir
                        MsBuildPath      = $resolvedMsBuildPath
                        KbPath           = $resolvedKbPath
                        WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
                        LogPath          = $resolvedLogPath
                    }
                    pathActions      = $probeStage.Diagnostic.pathActions
                    artifacts        = [ordered]@{
                        ProbeLogPath     = $probeLogPath
                        MsBuildFilePath  = $null
                        StdOutPath       = $null
                        StdErrPath       = $null
                        ExecutionLogPath = $resolvedLogPath
                    }
                    watcherContext   = $script:WatcherContext
                    timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
                    blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
                    warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
                    strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
                }
                $abortedJson = ConvertTo-JsonText -InputObject $aborted
                if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
                    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $abortedJson
                }
                Write-Output $abortedJson
                exit 47
            }

            $allowWideRebuildConfirmed = $true
            Add-StrategyTrace -Message 'AllowWideRebuild confirmado pelo usuario interativamente via frase exata. ForceRebuild=true autorizado.'
        }
    } elseif ($AllowWideRebuild.IsPresent) {
        Add-WarningMessage -Message '-AllowWideRebuild foi informado, mas ForceRebuild=false; o autorizador e redundante neste cenario (nenhuma regeneracao ampla foi solicitada). Para regenerar a KB inteira, passar tambem -ForceRebuild true.'
        Add-StrategyTrace -Message '-AllowWideRebuild redundante: ForceRebuild=false, nenhuma regeneracao ampla a confirmar.'
    }

    if ($costlyBuildOptionsRequested -and $AllowCostlyBuildOptions.IsPresent) {
        if ($ConfirmCostlyBuildOptions.IsPresent) {
            $allowCostlyBuildOptionsConfirmed = $true
            $confirmCostlyBuildOptionsMode    = 'parameter'
            Add-StrategyTrace -Message 'AllowCostlyBuildOptions confirmado via -ConfirmCostlyBuildOptions (modo nao-interativo). DetailedNavigation=true autorizado.'
        } else {
            $confirmCostlyBuildOptionsMode = 'interactive'
            Write-Host ''
            Write-Host 'AVISO: opcao cara de build foi solicitada.'
            Write-Host ''
            Write-Host ('KB alvo:      {0}' -f $resolvedKbPath)
            Write-Host ('GeneXusDir:   {0}' -f $resolvedGeneXusDir)
            Write-Host 'Opcoes:       DetailedNavigation=true'
            Write-Host ''
            Write-Host 'DetailedNavigation=true executa navegacao detalhada durante a especificacao.'
            Write-Host 'Em KB grande, essa opcao pode ampliar muito o tempo da verificacao e gerar'
            Write-Host 'custo operacional semelhante a execucoes que o usuario pretendia evitar.'
            Write-Host ''
            Write-Host 'Para confirmar, digite EXATAMENTE a frase abaixo (sem aspas):'
            Write-Host '    entendo que estas opcoes podem ampliar muito o custo do build e aceito executar'
            Write-Host ''
            $costlyConfirmation = Read-Host 'Confirmacao'

            if ($costlyConfirmation -ne 'entendo que estas opcoes podem ampliar muito o custo do build e aceito executar') {
                Add-BlockingReason -Reason 'Opcao cara de build nao confirmada pelo usuario com a frase exata. Execucao cancelada por seguranca.'
                $aborted = [ordered]@{
                    status           = 'cancelado pelo usuario'
                    summary          = 'DetailedNavigation=true nao confirmado pelo usuario. SpecifyAll/GenerateOnly cancelado por seguranca.'
                    exitCode         = 47
                    stage            = 'pre-specify-generate'
                    requestedContext = [ordered]@{
                        VersionName                     = $VersionName
                        EnvironmentName                 = $EnvironmentName
                        ForceRebuild                    = $ForceRebuild
                        DetailedNavigation              = $DetailedNavigation
                        CostlyBuildOptions              = @('DetailedNavigation=true')
                        AllowWideRebuildRequested       = $AllowWideRebuild.IsPresent
                        AllowWideRebuildConfirmed       = $allowWideRebuildConfirmed
                        ConfirmWideRebuildMode          = $confirmWideRebuildMode
                        AllowCostlyBuildOptionsRequested = $true
                        AllowCostlyBuildOptionsConfirmed = $false
                        ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
                    }
                    observedContext  = [ordered]@{
                        ActiveVersion     = $null
                        ActiveEnvironment = $null
                        SpecifyDone       = $false
                        GenerateDone      = $false
                        pathEnrichment    = $script:PathEnrichment
                    }
                    resolvedPaths    = [ordered]@{
                        GeneXusDir       = $resolvedGeneXusDir
                        MsBuildPath      = $resolvedMsBuildPath
                        KbPath           = $resolvedKbPath
                        WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
                        LogPath          = $resolvedLogPath
                    }
                    pathActions      = $probeStage.Diagnostic.pathActions
                    artifacts        = [ordered]@{
                        ProbeLogPath     = $probeLogPath
                        MsBuildFilePath  = $null
                        StdOutPath       = $null
                        StdErrPath       = $null
                        ExecutionLogPath = $resolvedLogPath
                    }
                    watcherContext   = $script:WatcherContext
                    timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
                    blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
                    warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
                    strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
                }
                $abortedJson = ConvertTo-JsonText -InputObject $aborted
                if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
                    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $abortedJson
                }
                Write-Output $abortedJson
                exit 47
            }

            $allowCostlyBuildOptionsConfirmed = $true
            Add-StrategyTrace -Message 'AllowCostlyBuildOptions confirmado pelo usuario interativamente via frase exata. DetailedNavigation=true autorizado.'
        }
    } elseif ($AllowCostlyBuildOptions.IsPresent) {
        Add-WarningMessage -Message '-AllowCostlyBuildOptions foi informado, mas DetailedNavigation=false; o autorizador e redundante neste cenario.'
        Add-StrategyTrace -Message '-AllowCostlyBuildOptions redundante: nenhuma opcao cara de build foi solicitada.'
    }

    $msBuildFilePath = Join-Path $artifactDirectory 'specifygenerate.msbuild'
    $stdOutPath      = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath      = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-MsBuildProjectContent -ResolvedGeneXusDir $resolvedGeneXusDir -ResolvedKbPath $resolvedKbPath
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
            stage = 'pre-specify-generate'
            requestedContext = [ordered]@{
                VersionName = $VersionName
                EnvironmentName = $EnvironmentName
                ForceRebuild = $ForceRebuild
            }
            resolvedPaths = [ordered]@{
                GeneXusDir = $resolvedGeneXusDir
                MsBuildPath = $resolvedMsBuildPath
                KbPath = $resolvedKbPath
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
            blockingReasons = @($msBuildConcurrency.blockingReasons + $script:BlockingReasons)
            warnings = @($msBuildConcurrency.warnings + $script:Warnings)
            strategyTrace = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blockedJson = ConvertTo-JsonText -InputObject $blocked
        if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $blockedJson
        }
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
    $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
    $stdErrText = Read-TextFileSafe -PathValue $stdErrPath

    $stdErrFilteredNoise = ''
    $stdErrFiltered      = ''
    $stdOutNoiseLines    = @()
    $stdOutNonNoiseLines = @()
    $stdOutFilteredNoise = ''
    $stdOutFiltered      = ''
    $environmentRemediationHints = $null
    $detectedBlockingPattern = $null
    $postBuildEventLines = @()
    $pbClassification = $null
    $postBuildShouldDowngradeFlag = $false
    $buildWarningLines = @()
    $specifyErrors = @()
    $knownStdOutNoiseSpecify = @()

    try {
    # GeneXus 18 grava ruídos conhecidos no stderr durante SpecifyAll:
    # [anonymous]+component (evidência datada) e [/g_service_worker]+obj (observado
    # em KBs Java/Tomcat). Pares cruzados permanecem stderr real. Filtrar antes.
    $stdErrNoiseClassification = Get-GeneXusMsBuildStderrNoiseClassification -Text $stdErrText
    $stdErrFilteredNoise = $stdErrNoiseClassification.NoiseText
    $stdErrFiltered      = $stdErrNoiseClassification.FilteredText

    # Ruido estrutural GAM/NetCore: GeneXusMsBuildGamPlatformsSupport.ps1 (ver SKILL.md).
    $stdOutLines      = if ([string]::IsNullOrEmpty($stdOutText)) { @() } else { $stdOutText -split "`r?`n" }
    $gamPostFilter    = Get-GamPlatformsStdoutPostFilterResult -StdOutLines $stdOutLines -ResolvedGeneXusDir $resolvedGeneXusDir
    $stdOutNoiseLines = @($gamPostFilter.NoiseLines)
    $stdOutNonNoiseLines = @($gamPostFilter.NonNoiseLines)
    $stdOutFilteredNoise = ($stdOutNoiseLines -join "`n")
    $stdOutFiltered      = ($stdOutNonNoiseLines -join "`n")
    $environmentRemediationHints = $gamPostFilter.EnvironmentRemediationHints
    if (-not [string]::IsNullOrWhiteSpace($gamPostFilter.RemediationHintWarning)) {
        Add-WarningMessage -Message ('Falha ao montar environmentRemediationHints (consultivo): {0}' -f $gamPostFilter.RemediationHintWarning)
    }

    $specifyDoneMarker  = Get-MarkerValue -Text $stdOutText -Marker '__SPECIFY_DONE__='
    $generateDoneMarker = Get-MarkerValue -Text $stdOutText -Marker '__GENERATE_DONE__='
    $specifyDone  = ($specifyDoneMarker -eq 'true')
    $generateDone = ($generateDoneMarker -eq 'true')

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

    if (-not [string]::IsNullOrWhiteSpace($VersionName) -and [string]::IsNullOrWhiteSpace($activeVersionOutput) -and -not $setVersionFailed) {
        Add-WarningMessage -Message 'Versão solicitada, mas o retorno de GetActiveVersion veio vazio.'
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName) -and [string]::IsNullOrWhiteSpace($activeEnvironmentOutput) -and -not $setEnvironmentFailed) {
        Add-WarningMessage -Message 'Environment solicitado, mas o retorno de GetActiveEnvironment veio vazio.'
    }

    $stdOutBlockingPatternRegex = 'Access denied|error MSB|: error |FAILED|at System\.|at Microsoft\.'
    $blockingPatternMatch       = [regex]::Match($stdOutFiltered, $stdOutBlockingPatternRegex)
    $detectedBlockingPattern    = if ($blockingPatternMatch.Success) { $blockingPatternMatch.Value } else { $null }

    $postBuildEventLines = @(Get-GeneXusMsBuildPostBuildEventLines -StdOutLines $stdOutNonNoiseLines)

    # Classifica os eventos contra o conjunto registrado do environment ativo em
    # kb-source-metadata.md. Saidas inertes ja foram separadas pelo suporte compartilhado;
    # cada evento restante registrado e esperado (informativo), e cada evento restante sem
    # registro rebaixa. Sem registro, so o fallback estrito de som e benigno. Apenas o
    # veredito agregado entra como impedimento em Resolve-BuildStatus.
    if ($postBuildEventLines.Count -gt 0) {
        $metadataPathForPostBuild = $null
        if ($null -ne $script:DeploymentEnvironmentContext) {
            $metadataPathForPostBuild = Get-GeneXusKbDeploymentContextValue -DeploymentEnvironmentContext $script:DeploymentEnvironmentContext -Name 'kbSourceMetadataPath'
        }
        $registeredPostBuildHashes = Get-GeneXusRegisteredPostBuildEventHashesForEnvironment `
            -MetadataPath $metadataPathForPostBuild -EnvironmentName $activeEnvironmentOutput
        $pbClassification = Get-GeneXusPostBuildEventClassification `
            -PostBuildEventLines $postBuildEventLines -RegisteredHashes $registeredPostBuildHashes
        $postBuildShouldDowngradeFlag = $pbClassification.shouldDowngrade

        foreach ($evt in $pbClassification.expected) {
            Add-WarningMessage -Message "Evento pos-build registrado reconhecido (nao afeta a classificacao): '$evt'"
        }
        foreach ($evt in $pbClassification.benignFallback) {
            Add-WarningMessage -Message "Evento pos-build benigno reconhecido sem registro: '$evt'. Registre via xpz-kb-parallel-setup (Register-GeneXusKbPostBuildEvents.ps1) para reconhecimento explicito."
        }
        foreach ($evt in $pbClassification.unexpected) {
            Add-WarningMessage -Message "Evento pos-build NAO registrado detectado: '$evt'. Se for legitimo, registre via xpz-kb-parallel-setup (Register-GeneXusKbPostBuildEvents.ps1); status rebaixado por cautela."
        }
        foreach ($evt in $pbClassification.unknownFallback) {
            Add-WarningMessage -Message "Evento pos-build nao reconhecido detectado: '$evt'. Processo externo pode ter sido disparado; status rebaixado por cautela."
        }
    }

    $buildStatus = Resolve-BuildStatus `
        -MsBuildExitCode $msBuildExitCode `
        -SpecifyDone $specifyDone `
        -GenerateDone $generateDone `
        -StdOutText $stdOutFiltered `
        -StdErrText $stdErrFiltered `
        -PostBuildShouldDowngrade $postBuildShouldDowngradeFlag

    $buildWarningLines   = @([regex]::Matches($stdOutFiltered, '(?m)[^\r\n]*\(\d+,\d+\)\s*:\s*warning\s*:[^\r\n]*') |
                             ForEach-Object { $_.Value.Trim() })

    # Promover warnings pmm00xx (versão de módulo GeneXus) a alertas top-level.
    # pmm00xx aparecem em buildWarnings mas o usuário não costuma inspecionar essa
    # lista interna. Surfacing-los em warnings garante visibilidade no resumo do
    # JSON. Resolucao tipica: 'Update Modules' na IDE. pmm0045 (inversao de versão)
    # merece texto mais explicito porque sinaliza estado não trivial (módulo
    # satelite exige versão MAIS NOVA do módulo principal do que a instalada).
    foreach ($wLine in $buildWarningLines) {
        if ($wLine -match 'warning\s*:\s*(pmm\d{4}):\s*([^\r\n]+)') {
            $pmmCode = $matches[1]
            $pmmMsg  = $matches[2].Trim()
            if ($pmmCode -eq 'pmm0045') {
                Add-WarningMessage -Message "Alerta de inversao de versao de modulo ($pmmCode): $pmmMsg Modulo satelite exige versao MAIS NOVA do modulo principal — pode exigir update do GeneXus instalado ou downgrade de modulos da KB. Inspecionar via 'Update Modules' na IDE."
            } else {
                Add-WarningMessage -Message "Alerta de versao de modulo ($pmmCode): $pmmMsg Resolver via 'Update Modules' na IDE."
            }
        }
    }

    $signalsScript = Join-Path $PSScriptRoot 'Read-MsBuildImportSignals.ps1'
    if (Test-Path -LiteralPath $signalsScript -PathType Leaf) {
        try {
            $specifySignalsJson = (& $signalsScript -StdOutPath $stdOutPath -StdErrPath $stdErrPath -Stage 'specify-generate' -AsJson) | Out-String
            if (-not [string]::IsNullOrWhiteSpace($specifySignalsJson)) {
                $specifySignals = $specifySignalsJson | ConvertFrom-Json
                if ($null -ne $specifySignals.PSObject.Properties['errors']) {
                    $specifyErrors = @($specifySignals.errors)
                }
                if ($null -ne $specifySignals.PSObject.Properties['knownStdOutNoise']) {
                    $knownStdOutNoiseSpecify = @($specifySignals.knownStdOutNoise)
                }
            }
        }
        catch {
            Add-WarningMessage -Message ('Falha ao classificar sinais specify-generate para Categoria B: {0}' -f $_.Exception.Message)
        }
    }

    if ($msBuildExitCode -eq 0 -and $buildStatus.ExitCode -eq 0) {
        $categoryBExit = Resolve-GeneXusMsBuildCategoryBExitCode `
            -BaseExitCode $buildStatus.ExitCode `
            -MsBuildExitCode $msBuildExitCode `
            -MsBuildErrors $specifyErrors `
            -InvalidTypesRejected @()
        if ($categoryBExit -eq $script:GeneXusMsBuildCategoryBExitCode) {
            $msBuildCategoryBBlocked = $true
            $operationalSubStateSpecify = $script:BuildOperationalSubStateCategoryB
            $categoryBSummary = Get-GeneXusMsBuildCategoryBStatusSummary `
                -OperationLabel 'SpecifyAll/GenerateOnly' `
                -ArtifactOnDisk $false `
                -ArtifactKind $null
            $buildStatus = [ordered]@{
                Status   = $categoryBSummary.Status
                Summary  = $categoryBSummary.Summary
                ExitCode = $categoryBExit
            }
            foreach ($reason in (Get-GeneXusMsBuildCategoryBBlockingReasons -MsBuildErrors $specifyErrors -InvalidTypesRejected @() -StageLabel 'SpecifyGenerate')) {
                Add-BlockingReason -Reason $reason
            }
        }
    }

    if ($buildStatus.ExitCode -ne 0 -and -not $msBuildCategoryBBlocked -and $script:BlockingReasons.Count -eq 0) {
        Add-BlockingReason -Reason 'MSBuild falhou sem causa acionável classificada; consulte executionEvidence e logs brutos nos artefatos.'
    }

    }
    catch {
        $postProcessingFailed = $true
        $postProcessingError  = $_.Exception.Message
        Add-WarningMessage -Message ('Pos-processamento local falhou apos MSBuild: {0}' -f $postProcessingError)
        Add-StrategyTrace -Message ('Pos-processamento falhou apos MSBuild: {0}' -f $postProcessingError)
        if ([string]::IsNullOrEmpty($stdOutFiltered) -and -not [string]::IsNullOrEmpty($stdOutText)) {
            $stdOutFiltered = $stdOutText
        }
        if ([string]::IsNullOrEmpty($stdErrFiltered) -and -not [string]::IsNullOrEmpty($stdErrText)) {
            $stdErrFiltered = $stdErrText
        }
        if ($null -eq $buildStatus) {
            $buildStatus = Resolve-BuildStatus `
                -MsBuildExitCode $msBuildExitCode `
                -SpecifyDone $false `
                -GenerateDone $false `
                -StdOutText $stdOutFiltered `
                -StdErrText $stdErrFiltered `
                -PostBuildShouldDowngrade $postBuildShouldDowngradeFlag
        }
    }

    if ($postProcessingFailed -and ($msBuildExitCode -eq 0) -and ($null -ne $buildStatus) -and ($buildStatus.ExitCode -eq 0) -and ($buildStatus.Status -eq 'specify e generate concluídos')) {
        $buildStatus = [ordered]@{
            Status   = 'specify e generate concluídos'
            Summary  = 'SpecifyAll/GenerateOnly concluiu sem erro de MSBuild, mas o pos-processamento local falhou. Evidencias do MSBuild preservadas nos artefatos.'
            ExitCode = 0
        }
    }

    $script:DeployBinClassification = $null
    if ($null -ne $buildStatus -and $msBuildExitCode -eq 0) {
        $validationEnvForDeployBin = $EnvironmentName
        if ($null -ne $script:DeploymentEnvironmentContext) {
            $ctxResolvedDeploy = Get-GeneXusKbDeploymentContextValue -DeploymentEnvironmentContext $script:DeploymentEnvironmentContext -Name 'validationEnvironmentResolved'
            if (-not [string]::IsNullOrWhiteSpace($ctxResolvedDeploy)) {
                $validationEnvForDeployBin = $ctxResolvedDeploy
            }
        }
        if ([string]::IsNullOrWhiteSpace($validationEnvForDeployBin)) {
            $validationEnvForDeployBin = $activeEnvironmentOutput
        }

        $buildStartedAtDeploy = [DateTimeOffset]::UtcNow
        if ($script:TimingLog.Contains('msbuildStart') -and -not [string]::IsNullOrWhiteSpace($script:TimingLog['msbuildStart'])) {
            try {
                $buildStartedAtDeploy = [DateTimeOffset]::Parse($script:TimingLog['msbuildStart'])
            }
            catch {
                Add-WarningMessage -Message ('BuildStartedAt para deploy bin nao parseavel: {0}' -f $script:TimingLog['msbuildStart'])
            }
        }

        $metadataPathDeploy = $null
        if ($null -ne $script:DeploymentEnvironmentContext) {
            $metadataPathDeploy = Get-GeneXusKbDeploymentContextValue -DeploymentEnvironmentContext $script:DeploymentEnvironmentContext -Name 'kbSourceMetadataPath'
        }

        # Decide o gate de deploy bin pelo fato (exit 0 + specify e generate concluidos), não pela
        # string de status. Rebaixamentos benignos (sino pos-build, ruido de stderr) mantem
        # ExitCode 0 e não devem suprimir a validação pedida; Category B/reorg/timeout já derrubam ExitCode.
        $buildOperationallySucceeded = ($buildStatus.ExitCode -eq 0 -and $specifyDone -and $generateDone)

        $script:DeployBinClassification = Invoke-GeneXusKbDeployBinPostBuildClassification `
            -KbPath $resolvedKbPath `
            -ValidationEnvironmentName $validationEnvForDeployBin `
            -MetadataPath $metadataPathDeploy `
            -DeploymentHostingKind $null `
            -BuildStartedAt $buildStartedAtDeploy `
            -BuildOperationallySucceeded $buildOperationallySucceeded `
            -PostImportDeployValidation:$PostImportDeployValidation `
            -SkipDeployBinCheck:$SkipDeployBinCheck `
            -StrictDeployBinCheck:$StrictDeployBinCheck `
            -OperationLabel 'SpecifyGenerate'

        foreach ($warn in $script:DeployBinClassification.warnings) {
            Add-WarningMessage -Message $warn
        }
        foreach ($reason in $script:DeployBinClassification.blockingReasons) {
            Add-BlockingReason -Reason $reason
        }

        if ($script:DeployBinClassification.statusReclassified) {
            $reclassifiedExit = if ($null -ne $script:DeployBinClassification.newExitCode) {
                $script:DeployBinClassification.newExitCode
            } else {
                $buildStatus.ExitCode
            }
            $buildStatus = [ordered]@{
                Status   = $script:DeployBinClassification.newStatus
                Summary  = $script:DeployBinClassification.newSummary
                ExitCode = $reclassifiedExit
            }
        }
    }

    if ($null -ne $script:DeploymentEnvironmentContext) {
        if (-not (Test-GeneXusKbActiveEnvironmentMatchesValidation -ActiveEnvironment $activeEnvironmentOutput -DeploymentEnvironmentContext $script:DeploymentEnvironmentContext)) {
            $expectedEnv = Get-GeneXusKbDeploymentContextValue -DeploymentEnvironmentContext $script:DeploymentEnvironmentContext -Name 'validationEnvironmentResolved'
            Add-WarningMessage -Message ("ActiveEnvironment observado ('{0}') diverge do environment de validacao resolvido ('{1}'). Nao tratar specify/generate concluidos como validacao deploy nesse environment." -f $activeEnvironmentOutput, $expectedEnv)
        }
    }

    $diagnostic = [ordered]@{
        status           = $buildStatus.Status
        summary          = $buildStatus.Summary
        exitCode         = $buildStatus.ExitCode
        executionEvidence = [ordered]@{
            msBuildExitCode = $msBuildExitCode
            msBuildFailed = ($msBuildExitCode -ne 0)
            wrapperExitCode = $buildStatus.ExitCode
            StdOutPath = $stdOutPath
            StdErrPath = $stdErrPath
        }
        stage            = 'specify-generate'
        requestedContext = [ordered]@{
            VersionName                = $VersionName
            EnvironmentName            = $EnvironmentName
            ParallelKbRoot             = $ParallelKbRoot
            KbMetadataPath             = $KbMetadataPath
            PostImportDeployValidation = $PostImportDeployValidation.IsPresent
            SkipDeployBinCheck         = $SkipDeployBinCheck.IsPresent
            StrictDeployBinCheck       = $StrictDeployBinCheck.IsPresent
            deploymentEnvironmentContext = $script:DeploymentEnvironmentContext
            ForceRebuild               = $ForceRebuild
            DetailedNavigation         = $DetailedNavigation
            AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
            AllowWideRebuildConfirmed  = $allowWideRebuildConfirmed
            ConfirmWideRebuildMode     = $confirmWideRebuildMode
            AllowCostlyBuildOptionsRequested = $AllowCostlyBuildOptions.IsPresent
            AllowCostlyBuildOptionsConfirmed = $allowCostlyBuildOptionsConfirmed
            ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
            StartWatcherRequested      = $StartWatcher.IsPresent
        }
        observedContext  = [ordered]@{
            ActiveVersion     = $activeVersionOutput
            ActiveEnvironment = $activeEnvironmentOutput
            SpecifyDone       = $specifyDone
            GenerateDone      = $generateDone
            MsBuildExitCode   = $msBuildExitCode
            pathEnrichment    = $script:PathEnrichment
        }
        resolvedPaths    = [ordered]@{
            GeneXusDir       = $resolvedGeneXusDir
            MsBuildPath      = $resolvedMsBuildPath
            KbPath           = $resolvedKbPath
            WorkingDirectory = $probeStage.Diagnostic.resolvedPaths.WorkingDirectory
            LogPath          = $resolvedLogPath
        }
        pathActions      = $probeStage.Diagnostic.pathActions
        artifacts        = [ordered]@{
            ProbeLogPath     = $probeLogPath
            MsBuildFilePath  = $msBuildFilePath
            StdOutPath       = $stdOutPath
            StdErrPath       = $stdErrPath
            ExecutionLogPath = $resolvedLogPath
        }
        watcherContext   = $script:WatcherContext
        timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
        specifyErrors        = @($specifyErrors)
        knownStdOutNoise     = @($knownStdOutNoiseSpecify)
        operationalSubState  = $operationalSubStateSpecify
        msBuildCategoryBBlocked = $msBuildCategoryBBlocked
        stdoutSignals        = [ordered]@{
            blockingPattern = $detectedBlockingPattern
            postBuildEvents = $postBuildEventLines
            postBuildEventClassification = $pbClassification
            buildWarnings   = $buildWarningLines
            specifyErrors   = @($specifyErrors)
            knownStdOutNoise = @($knownStdOutNoiseSpecify)
        }
        stdoutFilteredNoise  = Split-NonEmptyLines -Text $stdOutFilteredNoise
        stderrContent        = Split-NonEmptyLines -Text $stdErrFiltered
        stderrFilteredNoise  = Split-NonEmptyLines -Text $stdErrFilteredNoise
        blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
        warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
        strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
        postProcessingFailed = $postProcessingFailed
        postProcessingError  = $postProcessingError
    }

    if ($null -ne $script:DeployBinClassification) {
        $diagnostic['deployBinFreshness'] = $script:DeployBinClassification.deployBinFreshness
        $diagnostic['deployBinCheck'] = $script:DeployBinClassification.deployBinCheck
    }

    if ($null -ne $environmentRemediationHints) {
        $diagnostic['environmentRemediationHints'] = $environmentRemediationHints
    }

    try {
        $json = ConvertTo-JsonText -InputObject $diagnostic
    }
    catch {
        $postProcessingFailed = $true
        $postProcessingError  = ('Falha ao serializar diagnostico apos MSBuild: {0}' -f $_.Exception.Message)
        Add-StrategyTrace -Message $postProcessingError
        if (($buildStatus.ExitCode -eq 0) -and ($msBuildExitCode -eq 0)) {
            $buildStatus = [ordered]@{
                Status   = 'specify e generate concluídos'
                Summary  = 'SpecifyAll/GenerateOnly concluiu sem erro de MSBuild, mas a serializacao do diagnostico falhou. Evidencias primarias preservadas no log bruto.'
                ExitCode = 0
            }
        }
        $fallback = [ordered]@{
            status               = $buildStatus.Status
            summary              = $buildStatus.Summary
            exitCode             = $buildStatus.ExitCode
            executionEvidence    = [ordered]@{
                msBuildExitCode = $msBuildExitCode
                msBuildFailed   = ($msBuildExitCode -ne 0)
                wrapperExitCode = $buildStatus.ExitCode
                StdOutPath      = $stdOutPath
                StdErrPath      = $stdErrPath
            }
            postProcessingFailed = $true
            postProcessingError  = $postProcessingError
            stage                = 'specify-generate'
            artifacts            = [ordered]@{
                MsBuildStdoutLogPath = $stdOutPath
                MsBuildStderrLogPath = $stdErrPath
                ExecutionLogPath     = $resolvedLogPath
            }
            watcherContext       = $script:WatcherContext
            timing               = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            note                 = 'Diagnostico completo nao pode ser serializado; consultar msbuild.stdout.log para evidencia primaria.'
        }
        try {
            $json = $fallback | ConvertTo-Json -Depth 3
        }
        catch {
            $msBuildExitCodeText = if ($null -eq $msBuildExitCode) { 'null' } else { [string]$msBuildExitCode }
            $msBuildFailedText = if ($null -eq $msBuildExitCode) { 'null' } elseif ($msBuildExitCode -ne 0) { 'true' } else { 'false' }
            $json = '{"status":"' + $buildStatus.Status + '","exitCode":' + $buildStatus.ExitCode + ',"msBuildExitCode":' + $msBuildExitCodeText + ',"executionEvidence":{"msBuildExitCode":' + $msBuildExitCodeText + ',"msBuildFailed":' + $msBuildFailedText + ',"wrapperExitCode":' + $buildStatus.ExitCode + '},"postProcessingFailed":true,"note":"Fallback minimo: serializacao do fallback tambem falhou. Consultar msbuild.stdout.log."}'
        }
    }

    # Fallback: gravar sempre no diretório de artefatos, independente de $resolvedLogPath.
    # Garante rastreabilidade mesmo quando o chamador for interrompido antes de ler o JSON.
    $artifactResultPath = Join-Path $artifactDirectory 'specifygenerate-result.json'
    [System.IO.File]::WriteAllText($artifactResultPath, $json + [Environment]::NewLine, (Get-Utf8NoBomEncoding))

    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $buildStatus.ExitCode
}
catch {
    $outerCatchError = $_.Exception.Message
    $postProcessingError = $outerCatchError
    if ($null -ne $msBuildExitCode) {
        $recoverySpecifyDone = $false
        $recoveryGenerateDone = $false
        $recoveryStdOut = ''
        $recoveryStdErr = $stdErrText
        $recoveryStdErrFilteredNoise = @()
        $recoveryStdErrContent = @()
        try {
            if (-not [string]::IsNullOrWhiteSpace($stdOutPath) -and (Test-Path -LiteralPath $stdOutPath -PathType Leaf)) {
                $recoveryStdOut = Read-TextFileSafe -PathValue $stdOutPath
                $recoverySpecifyDone = ((Get-MarkerValue -Text $recoveryStdOut -Marker '__SPECIFY_DONE__=') -eq 'true')
                $recoveryGenerateDone = ((Get-MarkerValue -Text $recoveryStdOut -Marker '__GENERATE_DONE__=') -eq 'true')
            }
        }
        catch {
            # best effort apenas
        }
        try {
            if ([string]::IsNullOrEmpty($recoveryStdErr) -and -not [string]::IsNullOrWhiteSpace($stdErrPath) -and (Test-Path -LiteralPath $stdErrPath -PathType Leaf)) {
                $recoveryStdErr = Read-TextFileSafe -PathValue $stdErrPath
            }
            $recoveryStdErrClassification = Get-GeneXusMsBuildStderrNoiseClassification -Text $recoveryStdErr
            $recoveryStdErrContent = Split-NonEmptyLines -Text $recoveryStdErrClassification.FilteredText
            $recoveryStdErrFilteredNoise = Split-NonEmptyLines -Text $recoveryStdErrClassification.NoiseText
        }
        catch {
            # best effort apenas
        }

        $recoveryBuildStatus = $buildStatus
        if ($null -eq $recoveryBuildStatus) {
            $recoveryBuildStatus = Resolve-BuildStatus `
                -MsBuildExitCode $msBuildExitCode `
                -SpecifyDone $recoverySpecifyDone `
                -GenerateDone $recoveryGenerateDone `
                -StdOutText $recoveryStdOut `
                -StdErrText ($recoveryStdErrContent -join "`n")
        }

        if (($recoveryBuildStatus.Status -eq 'specify e generate concluídos') -and (-not $recoverySpecifyDone -or -not $recoveryGenerateDone)) {
            $recoveryBuildStatus = Resolve-BuildStatus `
                -MsBuildExitCode $msBuildExitCode `
                -SpecifyDone $recoverySpecifyDone `
                -GenerateDone $recoveryGenerateDone `
                -StdOutText $recoveryStdOut `
                -StdErrText ($recoveryStdErrContent -join "`n")
        }

        $recoveryExitCode = [int]$recoveryBuildStatus.ExitCode
        $recoveryStatus = [string]$recoveryBuildStatus.Status
        $recoverySummary = [string]$recoveryBuildStatus.Summary
        if (($recoveryExitCode -eq 0) -and ($recoveryStatus -eq 'specify e generate concluídos') -and $recoverySpecifyDone -and $recoveryGenerateDone) {
            $recoveryStatus = 'specify e generate concluídos com falha no pos-processamento'
            $recoverySummary = 'SpecifyAll/GenerateOnly concluiu sem erro de MSBuild e com marcadores de conclusão, mas o wrapper falhou ao montar o diagnóstico. Consulte msbuild.stdout.log nos artefatos.'
        } else {
            $recoverySummary = $recoverySummary + ' O diagnóstico completo falhou após o MSBuild; a classificação e a evidência disponível foram preservadas.'
        }

        $recovery = [ordered]@{
            status               = $recoveryStatus
            summary              = $recoverySummary
            exitCode             = $recoveryExitCode
            executionEvidence    = [ordered]@{
                msBuildExitCode = $msBuildExitCode
                msBuildFailed   = ($msBuildExitCode -ne 0)
                wrapperExitCode = $recoveryExitCode
                StdOutPath      = $stdOutPath
                StdErrPath      = $stdErrPath
            }
            postProcessingFailed = $true
            postProcessingError  = $postProcessingError
            stage                = 'specify-generate'
            observedContext      = [ordered]@{
                SpecifyDone       = $recoverySpecifyDone
                GenerateDone      = $recoveryGenerateDone
                MsBuildExitCode   = $msBuildExitCode
            }
            resolvedPaths        = [ordered]@{
                GeneXusDir       = (Get-FullPathSafe -PathValue $resolvedGeneXusDir)
                MsBuildPath      = (Get-FullPathSafe -PathValue $resolvedMsBuildPath)
                KbPath           = (Get-FullPathSafe -PathValue $resolvedKbPath)
                LogPath          = $resolvedLogPath
            }
            artifacts            = [ordered]@{
                MsBuildStdoutLogPath = $stdOutPath
                MsBuildStderrLogPath = $stdErrPath
                ExecutionLogPath     = $resolvedLogPath
            }
            watcherContext       = $script:WatcherContext
            timing               = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            stderrContent        = @($recoveryStdErrContent | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            stderrFilteredNoise  = @($recoveryStdErrFilteredNoise | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            blockingReasons      = @($script:BlockingReasons)
            warnings             = @($script:Warnings)
            strategyTrace        = @($script:StrategyTrace)
            note                 = 'Diagnostico completo indisponivel apos falha interna; consultar msbuild.stdout.log para evidencia primaria.'
        }
        try {
            $recoveryJson = ConvertTo-JsonText -InputObject $recovery
            try {
                if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath) -and -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
                    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $recoveryJson
                }
            }
            catch {
                # best effort apenas
            }
            Write-Output $recoveryJson
            exit $recoveryExitCode
        }
        catch {
            # cair no failure padrão abaixo
        }
    }

    $failure = [ordered]@{
        status           = 'falha operacional'
        summary          = 'Falha interna do script antes de concluir a verificação.'
        exitCode         = 90
        stage            = 'specify-generate'
        requestedContext = [ordered]@{
            VersionName                = $VersionName
            EnvironmentName            = $EnvironmentName
            ForceRebuild               = $ForceRebuild
            DetailedNavigation         = $DetailedNavigation
            AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
            AllowWideRebuildConfirmed  = $allowWideRebuildConfirmed
            ConfirmWideRebuildMode     = $confirmWideRebuildMode
            StartWatcherRequested      = $StartWatcher.IsPresent
        }
        resolvedPaths    = [ordered]@{
            GeneXusDir       = (Get-FullPathSafe -PathValue $GeneXusDir)
            MsBuildPath      = (Get-FullPathSafe -PathValue $MsBuildPath)
            KbPath           = (Get-FullPathSafe -PathValue $KbPath)
            WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
            LogPath          = $resolvedLogPath
        }
        pathActions      = [ordered]@{
            WorkingDirectory = 'blocked-internal-error'
        }
        artifacts        = [ordered]@{
            ProbeLogPath     = $null
            MsBuildFilePath  = $null
            StdOutPath       = $null
            StdErrPath       = $null
            ExecutionLogPath = $resolvedLogPath
        }
        watcherContext   = $script:WatcherContext
        timing           = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
        stdoutSignals        = [ordered]@{
            blockingPattern = $null
            postBuildEvents = @()
            buildWarnings   = @()
        }
        stdoutFilteredNoise  = @()
        stderrContent        = @()
        stderrFilteredNoise  = @()
        blockingReasons  = @($_.Exception.Message)
        warnings         = @()
        strategyTrace    = @($script:StrategyTrace)
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
