#requires -Version 7.4

<#
.SYNOPSIS
Executa build completo pós-import via MSBuild: BuildAll (specify + generate + compile).

.DESCRIPTION
Implementa a etapa de validação completa da skill xpz-msbuild-build: reaproveita o probe
Test-GeneXusMsBuildSetup.ps1, abre a KB em modo headless controlado, posiciona versão e
Environment quando informados, executa BuildAll com parâmetros explícitos e fecha a KB.

Classifica o resultado em seis categorias operacionais:
  - compilou limpo
  - compilou com erros
  - reorg necessária detectada
  - timeout em KB grande
  - KB inacessível
  - operação concluída, pendente de confirmação funcional

Por padrão, FailIfReorg=true bloqueia o build se reorganização for necessária, sem executá-la.
Reorg só ocorre quando -AllowReorg é passado e o usuário confirma interativamente.

Quando -MonitorLogPath é fornecido, o script aguarda 6 segundos após o MSBuild terminar
antes de ler o arquivo — tempo necessário para Watch-GeneXusMsBuildLog.ps1 drenar as
linhas finais do log (Watch dorme 2s após detectar que o processo morreu; com intervalo
de polling de 3-5s, o pior caso é ~5s). Esse delay não é contabilizado em totalDurationSeconds.

.PARAMETER KbPath
Caminho da KB a ser usada no build.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, usa fallback do probe.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, usa fallback do probe.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes do build.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes do build. Em KB com kb_environment_count maior que 1
em kb-source-metadata.md, e obrigatório (direto ou via deployment_environment_name gravado pelo
xpz-kb-parallel-setup). Omitir só e valido quando kb_environment_count for 1 no metadata.

.PARAMETER ParallelKbRoot
Raiz da pasta paralela da KB para resolver kb-source-metadata.md (campos deployment_environment_name,
kb_environment_count, kb_environment_names e, quando o gate de deploy bin estiver ativo,
kb_environment_web_dirs). Não dispara inventario de environments na KB nativa.

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
Equivale a "Rebuild All" da IDE (não a "Build All"): muda a semântica de BuildAll incremental
para regeneração total. Em KB grande pode durar horas e regenerar centenas/milhares de
objetos, incluindo subtype groups. Default: false.

Operação ampla bloqueada por política: ForceRebuild=true só pode ser usado em conjunto com
-AllowWideRebuild e confirmação explícita por frase exata do usuário (modo interativo) ou
-AllowWideRebuild -ConfirmWideRebuild (modo não-interativo). Tentativa sem -AllowWideRebuild
é bloqueada com exit 46.

.PARAMETER CompileMains
Quando true, compila também os objetos Main além do Developer Menu. Default: false.
Opção cara bloqueada por política: só pode ser usada em conjunto com
-AllowCostlyBuildOptions e confirmação explícita do usuário.

.PARAMETER DetailedNavigation
Quando true, executa navegação detalhada. Default: false. Opção cara bloqueada por
política: só pode ser usada em conjunto com -AllowCostlyBuildOptions e confirmação
explícita do usuário.

.PARAMETER FailIfReorg
Quando true, bloqueia o build se reorganização for necessária sem executá-la. Default: true.
Não pode ser definido como false sem usar -AllowReorg — a tentativa é bloqueada por política.

.PARAMETER DoNotExecuteReorg
Quando true, gera o script de reorg sem executá-lo. Default: false.
Ignorado quando FailIfReorg=true porque o build falha antes de chegar à reorg.

.PARAMETER AllowReorg
Switch. Quando presente, sobrescreve FailIfReorg para false e DoNotExecuteReorg para false.
Em modo interativo (sem -ConfirmReorg), exige que o usuário digite 'sim' no terminal antes
de prosseguir. Em modo não-interativo (com -ConfirmReorg), a confirmação é feita pelo
chamador via parâmetro. É a única forma autorizada de habilitar a reorganização do banco.

.PARAMETER ConfirmReorg
Switch. Usado em conjunto com -AllowReorg para dispensar o Read-Host interativo.
Destina-se exclusivamente a processos desanexados (Start-Process) onde não há terminal
disponível — por exemplo, quando Watch-GeneXusMsBuildLog.ps1 é executado em paralelo.
Usar -ConfirmReorg sem -AllowReorg é bloqueado por política (exit 46).
O chamador é responsável por obter confirmação explícita do usuário humano antes de
passar -ConfirmReorg — este parâmetro não dispensa a confirmação, apenas muda o canal.

.PARAMETER AllowWideRebuild
Switch. Único caminho autorizado para habilitar -ForceRebuild true. Em modo interativo
(sem -ConfirmWideRebuild), exige que o usuário digite no terminal a frase exata:
    entendo que isto pode regerar a KB inteira e aceito o custo
Em modo não-interativo (com -ConfirmWideRebuild), a confirmação é feita pelo chamador
via parâmetro. Sem este switch, -ForceRebuild true é bloqueado por política (exit 46),
independentemente de qualquer outra autorização (inclusive -AllowReorg).

.PARAMETER ConfirmWideRebuild
Switch. Usado em conjunto com -AllowWideRebuild para dispensar o Read-Host interativo
da frase de confirmação. Destina-se exclusivamente a processos desanexados onde não
há terminal disponível. Usar -ConfirmWideRebuild sem -AllowWideRebuild é bloqueado
por política (exit 46). O chamador é responsável por obter confirmação explícita do
usuário humano com a frase exata antes de passar -ConfirmWideRebuild — este parâmetro
não dispensa a confirmação, apenas muda o canal.

.PARAMETER AllowCostlyBuildOptions
Switch. Único caminho autorizado para habilitar -CompileMains true ou
-DetailedNavigation true sem execução acidental. Em modo interativo exige frase exata:
    entendo que estas opções podem ampliar muito o custo do build e aceito executar
Em modo não-interativo requer -ConfirmCostlyBuildOptions.

.PARAMETER ConfirmCostlyBuildOptions
Switch. Usado em conjunto com -AllowCostlyBuildOptions para dispensar o Read-Host
interativo da frase de confirmação. Proibido sem -AllowCostlyBuildOptions. O chamador
é responsável por obter confirmação explícita do usuário humano com a frase exata.

.PARAMETER TimeoutSeconds
Segundos máximos de espera pelo MSBuild. Default 0 = sem timeout.
Quando excedido, o processo MSBuild é encerrado e o resultado é classificado como
'timeout em KB grande'. MSBuild pode ainda estar em execução após o encerramento.

.PARAMETER Configuration
Configuração de build a aplicar antes do BuildAll. Valores válidos: Release, Debug,
Performance Test. Quando omitido, a configuração ativa da KB é mantida sem alteração.
Emite SetConfiguration imediatamente antes do BuildAll.

.PARAMETER MonitorLogPath
Caminho opcional do log gravado por Watch-GeneXusMsBuildLog.ps1.
Quando fornecido e o arquivo existir após o build, o script parseia os marcadores
'iniciado'/'terminado' do log do monitor para extrair os timestamps de cada fase
interna do build e popular 'timing.phases' no JSON de resultado.
Sem este parâmetro, 'timing.phases' fica vazio mas probe/msbuild/total são registrados.

.PARAMETER StartWatcher
Switch. Quando presente, o próprio wrapper dispara Watch-GeneXusMsBuildLog.ps1 em janela
visível separada antes de iniciar o MSBuild. Requer -MonitorLogPath. O watcher recebe o
PID do processo wrapper como alvo de monitoramento e o mesmo caminho de -MonitorLogPath
para gravar o log de fases. O JSON de resultado registra watcherContext.watcherLaunched
e watcherContext.watcherPid para evidência auditável. Se o watcher falhar ao iniciar,
o build prossegue com um warning — não bloqueia a execução.

.PARAMETER WatcherIntervalSeconds
Intervalo de polling em segundos do watcher. Repassado a Watch-GeneXusMsBuildLog.ps1.
Padrão: 5. Intervalo válido: 1-60.

.PARAMETER WatcherSilenceThresholdSeconds
Segundos sem nova linha no log antes de o watcher emitir alerta de silêncio.
Repassado a Watch-GeneXusMsBuildLog.ps1. Padrão: 120. Intervalo válido: 30-3600.

.PARAMETER VerboseLog
Amplia o detalhamento gravado no log sem alterar o resultado lógico.

.PARAMETER SelfTestForceOuterRecovery
Uso exclusivo do self-test controlado. Depois de o MSBuild terminar e os seus logs
brutos estarem disponíveis, força uma exceção local imediatamente antes da escrita
do diagnóstico normal para exercitar o recovery externo. Não usar operacionalmente.
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

    [string]$MonitorLogPath,

    [switch]$StartWatcher,

    [ValidateRange(1, 60)]
    [int]$WatcherIntervalSeconds = 5,

    [ValidateRange(30, 3600)]
    [int]$WatcherSilenceThresholdSeconds = 120,

    [switch]$VerboseLog,

    [string]$ParallelKbRoot,

    [string]$KbMetadataPath,

    [switch]$PostImportDeployValidation,

    [switch]$SkipDeployBinCheck,

    [switch]$StrictDeployBinCheck,

    [Parameter(DontShow = $true)]
    [switch]$SelfTestForceOuterRecovery
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
    $artifactDirectory = Join-Path $baseDirectory ('gx-buildall-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function New-MsBuildProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath,
        [string]$EffectiveFailIfReorg,
        [string]$EffectiveDoNotExecuteReorg
    )

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEscaped            = Escape-Xml -Value $targetsPath
    $kbPathEscaped             = Escape-Xml -Value $ResolvedKbPath
    $versionEscaped            = Escape-Xml -Value $VersionName
    $environmentEscaped        = Escape-Xml -Value $EnvironmentName
    $forceRebuildEscaped       = Escape-Xml -Value $ForceRebuild
    $compileMainsEscaped       = Escape-Xml -Value $CompileMains
    $detailedNavigationEscaped = Escape-Xml -Value $DetailedNavigation
    $configurationEscaped      = Escape-Xml -Value $Configuration
    $failIfReorgEscaped        = Escape-Xml -Value $EffectiveFailIfReorg
    $doNotExecuteReorgEscaped  = Escape-Xml -Value $EffectiveDoNotExecuteReorg

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEscaped" />

  <PropertyGroup>
    <KBPath>$kbPathEscaped</KBPath>
    <KBVersion>$versionEscaped</KBVersion>
    <KBEnvironment>$environmentEscaped</KBEnvironment>
    <ForceRebuild>$forceRebuildEscaped</ForceRebuild>
    <CompileMains>$compileMainsEscaped</CompileMains>
    <DetailedNavigation>$detailedNavigationEscaped</DetailedNavigation>
    <FailIfReorg>$failIfReorgEscaped</FailIfReorg>
    <DoNotExecuteReorg>$doNotExecuteReorgEscaped</DoNotExecuteReorg>
    <KBConfiguration>$configurationEscaped</KBConfiguration>
  </PropertyGroup>

  <Target Name="CloseOnError">
    <CloseKnowledgeBase ContinueOnError="WarnAndContinue" />
  </Target>

  <Target Name="Run">
    <OpenKnowledgeBase Directory="`$(KBPath)" CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="OpenOutput" />
    </OpenKnowledgeBase>
    <Message Text="__KB_OPEN__=true" Importance="High" />
    <GetActiveVersion CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveVersionOutput" />
    </GetActiveVersion>
    <GetActiveEnvironment CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="ActiveEnvironmentOutput" />
    </GetActiveEnvironment>
    <SetActiveVersion Condition="'`$(KBVersion)' != ''" VersionName="`$(KBVersion)" />
    <SetActiveEnvironment Condition="'`$(KBEnvironment)' != ''" EnvironmentName="`$(KBEnvironment)" />
    <SetConfiguration Condition="'`$(KBConfiguration)' != ''" Configuration="`$(KBConfiguration)" />
    <BuildAll
        ForceRebuild="`$(ForceRebuild)"
        CompileMains="`$(CompileMains)"
        DetailedNavigation="`$(DetailedNavigation)"
        FailIfReorg="`$(FailIfReorg)"
        DoNotExecuteReorg="`$(DoNotExecuteReorg)"
        CaptureOutput="true">
      <Output TaskParameter="TaskOutput" PropertyName="BuildOutput" />
    </BuildAll>
    <Message Text="__BUILDALL_DONE__=true" Importance="High" />
    <Message Text="__OPEN_OUTPUT__=`$(OpenOutput)" Importance="High" />
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
    $process = Start-Process -FilePath $ResolvedMsBuildPath -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $MsBuildFilePath) -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath -NoNewWindow -PassThru

    if ($TimeoutSeconds -gt 0) {
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            try { $process.Kill() } catch { }
            Add-StrategyTrace -Message ('MSBuild encerrado por timeout após {0} segundos.' -f $TimeoutSeconds)
            return [ordered]@{ ExitCode = -1; TimedOut = $true }
        }
    } else {
        $process.WaitForExit()
    }

    return [ordered]@{ ExitCode = $process.ExitCode; TimedOut = $false }
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
        [bool]$KbOpen,
        [bool]$BuildAllDone,
        [bool]$ReorgDetected,
        [bool]$TimedOut,
        [bool]$AllowReorgConfirmed
    )

    if ($TimedOut) {
        return [ordered]@{
            Status   = 'timeout em KB grande'
            Summary  = 'O wrapper encerrou por timeout. MSBuild pode ainda estar em execucao. Distinguir timeout do invocador de falha real do MSBuild antes de concluir sobre o resultado.'
            ExitCode = 43
        }
    }

    if (-not $KbOpen) {
        return [ordered]@{
            Status   = 'KB inacessivel'
            Summary  = 'OpenKnowledgeBase falhou antes do build. Verifique KbPath, permissoes e integridade da KB.'
            ExitCode = 40
        }
    }

    if ($KbOpen -and -not $BuildAllDone -and $ReorgDetected -and -not $AllowReorgConfirmed) {
        return [ordered]@{
            Status   = 'reorg necessaria detectada'
            Summary  = 'FailIfReorg bloqueou o build. Reorganizacao do banco detectada mas nao executada. Decida o proximo passo: executar reorg com -AllowReorg ou abrir a KB na IDE.'
            ExitCode = 44
        }
    }

    if ($MsBuildExitCode -eq 0 -and $BuildAllDone) {
        $cleanSummary = if ($ReorgDetected -and $AllowReorgConfirmed) {
            'BuildAll concluiu sem erro. Reorganizacao do banco executada com sucesso.'
        } else {
            'BuildAll concluiu sem erro e sem reorg detectada.'
        }
        return [ordered]@{
            Status   = 'compilou limpo'
            Summary  = $cleanSummary
            ExitCode = 0
        }
    }

    if ($MsBuildExitCode -eq 0 -and -not $BuildAllDone) {
        return [ordered]@{
            Status   = 'operacao concluida, pendente de confirmacao funcional'
            Summary  = 'MSBuild retornou exitCode 0 mas o marcador de conclusao do BuildAll nao foi detectado. Validacao funcional depende de inspecao na IDE.'
            ExitCode = 0
        }
    }

    return [ordered]@{
        Status   = 'compilou com erros'
        Summary  = 'BuildAll falhou. Verifique stdout e stderr para detalhes dos erros de compilacao ou specify.'
        ExitCode = 45
    }
}

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings        = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace   = New-Object System.Collections.Generic.List[string]
$script:TimingLog       = [ordered]@{}
$script:PathEnrichment  = [ordered]@{
    applied        = $false
    subdirsAdded   = @()
    subdirsSkipped = @()
}
$script:WatcherContext  = New-GeneXusMsBuildWatcherContext -StartWatcherRequested $StartWatcher.IsPresent
$script:DeploymentEnvironmentContext = $null
# Bucket de sinais carregados adiante para os caminhos de excecao (fallback de
# serializacao e recovery externo). Preenchido durante o caminho normal conforme
# cada sinal e calculado. Default null (nao "0"/"false") para nao fingir
# "zero erros" / "sem reorg" quando a falha estourou antes do calculo: null =
# "nao chegou a ser computado". Lido pelos objetos enxutos sem recomputar.
# Complete e marcado true so depois do ultimo sinal ser calculado: true = bucket
# integral, o consumidor pode confiar sem reabrir o log; false = parcial, reabrir
# o log para qualquer campo null. Decide a confianca sem o agente ter de inferir
# o significado do null campo a campo.
$script:BuildSignals = [ordered]@{
    Complete        = $false
    ReorgDetected   = $null
    ErrorCount      = $null
    PostBuildEvents = $null
}
$confirmReorgMode       = $null
$confirmWideRebuildMode = $null
$confirmCostlyBuildOptionsMode = $null
$allowCostlyBuildOptionsConfirmed = $false
$msBuildExitCode = $null
$timedOut = $false
$stdOutText = ''
$stdErrText = ''
$postProcessingFailed = $false
$postProcessingError = $null
$buildStatus = $null
$msBuildCategoryBBlocked = $false
$operationalSubStateBuild = $null

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

$logPathRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $resolvedLogPath
if ($logPathRejection.rejected) {
    Write-Output (New-GeneXusMsBuildLogPathBlockJson -WrapperName 'Invoke-GeneXusKbBuildAll.ps1' -ResolvedLogPath $resolvedLogPath -Reason $logPathRejection.reason)
    exit 50
}

$script:TimingLog['scriptStart'] = Get-GeneXusMsBuildNowIso

try {
    # Gate de segurança: -ConfirmWideRebuild sem -AllowWideRebuild não tem sentido e é bloqueado por política
    if ($ConfirmWideRebuild.IsPresent -and -not $AllowWideRebuild.IsPresent) {
        Add-BlockingReason -Reason '-ConfirmWideRebuild so pode ser usado em conjunto com -AllowWideRebuild. Para confirmar regeneracao ampla interativamente, use apenas -AllowWideRebuild. Para modo nao-interativo, use -AllowWideRebuild -ConfirmWideRebuild apos confirmar a operacao com o usuario humano.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = '-ConfirmWideRebuild requer -AllowWideRebuild. Execute novamente com -AllowWideRebuild -ConfirmWideRebuild apos confirmar a operacao com o usuario humano.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration              = $Configuration
                ForceRebuild               = $ForceRebuild
                FailIfReorg                = $FailIfReorg
                DoNotExecuteReorg          = $DoNotExecuteReorg
                AllowReorgRequested        = $AllowReorg.IsPresent
                AllowReorgConfirmed        = $false
                ConfirmReorgMode           = $confirmReorgMode
                AllowWideRebuildRequested  = $false
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
                StartWatcherRequested      = $StartWatcher.IsPresent
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration                  = $Configuration
                ForceRebuild                   = $ForceRebuild
                CompileMains                   = $CompileMains
                DetailedNavigation             = $DetailedNavigation
                FailIfReorg                    = $FailIfReorg
                DoNotExecuteReorg              = $DoNotExecuteReorg
                AllowReorgRequested            = $AllowReorg.IsPresent
                AllowReorgConfirmed            = $false
                ConfirmReorgMode               = $confirmReorgMode
                AllowWideRebuildRequested      = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed      = $false
                ConfirmWideRebuildMode         = $confirmWideRebuildMode
                AllowCostlyBuildOptionsRequested = $false
                AllowCostlyBuildOptionsConfirmed = $false
                ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
                StartWatcherRequested          = $StartWatcher.IsPresent
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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
    # ForceRebuild=true equivale a "Rebuild All" da IDE: muda BuildAll incremental para regeneracao TOTAL,
    # podendo levar horas e regenerar centenas/milhares de objetos em KB grande.
    if ($ForceRebuild -eq 'true' -and -not $AllowWideRebuild.IsPresent) {
        Add-BlockingReason -Reason 'ForceRebuild=true equivale a "Rebuild All" da IDE (regenera TODOS os objetos da KB, nao apenas os alterados). Em KB grande pode levar horas e regenerar centenas/milhares de objetos. So pode ser habilitado via -AllowWideRebuild com confirmacao explicita do usuario. Para BuildAll incremental costumeiro, omita ForceRebuild ou use ForceRebuild=false.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = 'ForceRebuild=true requer -AllowWideRebuild e confirmacao explicita do usuario por frase exata. Para BuildAll incremental, omita ForceRebuild.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration              = $Configuration
                ForceRebuild               = $ForceRebuild
                FailIfReorg                = $FailIfReorg
                DoNotExecuteReorg          = $DoNotExecuteReorg
                AllowReorgRequested        = $AllowReorg.IsPresent
                AllowReorgConfirmed        = $false
                ConfirmReorgMode           = $confirmReorgMode
                AllowWideRebuildRequested  = $false
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
                StartWatcherRequested      = $StartWatcher.IsPresent
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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

    $costlyBuildOptionsRequested = ($CompileMains -eq 'true' -or $DetailedNavigation -eq 'true')

    # Gate de segurança: opções que ampliam custo do build não passam silenciosamente.
    if ($costlyBuildOptionsRequested -and -not $AllowCostlyBuildOptions.IsPresent) {
        $costlyOptions = @()
        if ($CompileMains -eq 'true') { $costlyOptions += 'CompileMains=true' }
        if ($DetailedNavigation -eq 'true') { $costlyOptions += 'DetailedNavigation=true' }
        Add-BlockingReason -Reason ('Opcoes caras de build solicitadas sem -AllowCostlyBuildOptions: {0}. CompileMains=true compila tambem objetos Main; DetailedNavigation=true executa navegacao detalhada. Em KB grande estas opcoes podem transformar validacao cotidiana em execucao de alto custo. Confirme explicitamente antes de prosseguir.' -f ($costlyOptions -join ', '))
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = 'Opcoes caras de build requerem -AllowCostlyBuildOptions e confirmacao explicita do usuario.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration                  = $Configuration
                ForceRebuild                   = $ForceRebuild
                CompileMains                   = $CompileMains
                DetailedNavigation             = $DetailedNavigation
                FailIfReorg                    = $FailIfReorg
                DoNotExecuteReorg              = $DoNotExecuteReorg
                CostlyBuildOptions             = @($costlyOptions)
                AllowReorgRequested            = $AllowReorg.IsPresent
                AllowReorgConfirmed            = $false
                ConfirmReorgMode               = $confirmReorgMode
                AllowWideRebuildRequested      = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed      = $false
                ConfirmWideRebuildMode         = $confirmWideRebuildMode
                AllowCostlyBuildOptionsRequested = $false
                AllowCostlyBuildOptionsConfirmed = $false
                ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
                StartWatcherRequested          = $StartWatcher.IsPresent
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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

    # Gate de segurança: -ConfirmReorg sem -AllowReorg não tem sentido e é bloqueado por política
    if ($ConfirmReorg.IsPresent -and -not $AllowReorg.IsPresent) {
        Add-BlockingReason -Reason '-ConfirmReorg so pode ser usado em conjunto com -AllowReorg. Para confirmar reorg interativamente, use apenas -AllowReorg. Para modo nao-interativo, use -AllowReorg -ConfirmReorg.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = '-ConfirmReorg requer -AllowReorg. Execute novamente com -AllowReorg -ConfirmReorg.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration              = $Configuration
                ForceRebuild               = $ForceRebuild
                FailIfReorg                = $FailIfReorg
                DoNotExecuteReorg          = $DoNotExecuteReorg
                AllowReorgRequested        = $false
                AllowReorgConfirmed        = $false
                ConfirmReorgMode           = $confirmReorgMode
                AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
                StartWatcherRequested      = $StartWatcher.IsPresent
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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

    # Gate de segurança: FailIfReorg=false sem -AllowReorg é bloqueado por política
    if ($FailIfReorg -eq 'false' -and -not $AllowReorg.IsPresent) {
        Add-BlockingReason -Reason 'FailIfReorg=false so pode ser habilitado via -AllowReorg com confirmacao interativa explicita. Execute novamente passando -AllowReorg.'
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            summary          = 'FailIfReorg=false requer -AllowReorg e confirmacao interativa. Execute novamente com -AllowReorg.'
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration              = $Configuration
                ForceRebuild               = $ForceRebuild
                FailIfReorg                = $FailIfReorg
                DoNotExecuteReorg          = $DoNotExecuteReorg
                AllowReorgRequested        = $false
                AllowReorgConfirmed        = $false
                ConfirmReorgMode           = $confirmReorgMode
                AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
                StartWatcherRequested      = $StartWatcher.IsPresent
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration                 = $Configuration
                ForceRebuild                  = $ForceRebuild
                FailIfReorg                   = $FailIfReorg
                DoNotExecuteReorg             = $DoNotExecuteReorg
                EnvironmentName               = $EnvironmentName
                ParallelKbRoot                = $ParallelKbRoot
                KbMetadataPath                = $KbMetadataPath
                AllowReorgRequested           = $AllowReorg.IsPresent
                AllowReorgConfirmed           = $false
                ConfirmReorgMode              = $confirmReorgMode
                AllowWideRebuildRequested     = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed     = $false
                ConfirmWideRebuildMode        = $confirmWideRebuildMode
                AllowCostlyBuildOptionsRequested = $AllowCostlyBuildOptions.IsPresent
                AllowCostlyBuildOptionsConfirmed = $allowCostlyBuildOptionsConfirmed
                ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
                StartWatcherRequested         = $StartWatcher.IsPresent
                deploymentEnvironmentContext  = $envResolution.Context
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
            artifacts        = [ordered]@{
                ProbeLogPath     = $null
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
            }
            watcherContext   = $script:WatcherContext
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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

    # Gate de segurança: -StartWatcher requer -MonitorLogPath
    $watcherParameterValidation = Test-GeneXusMsBuildWatcherParameters -StartWatcherRequested $StartWatcher.IsPresent -MonitorLogPath $MonitorLogPath
    if (-not $watcherParameterValidation.ok) {
        Add-BlockingReason -Reason $watcherParameterValidation.reason
        $blocked = [ordered]@{
            status           = 'bloqueado por politica de seguranca'
            causeId          = $watcherParameterValidation.causeId
            summary          = $watcherParameterValidation.summary
            exitCode         = 46
            stage            = 'pre-build'
            requestedContext = [ordered]@{
                Configuration              = $Configuration
                ForceRebuild               = $ForceRebuild
                FailIfReorg                = $FailIfReorg
                DoNotExecuteReorg          = $DoNotExecuteReorg
                AllowReorgRequested        = $AllowReorg.IsPresent
                AllowReorgConfirmed        = $false
                ConfirmReorgMode           = $confirmReorgMode
                AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
                StartWatcherRequested      = $StartWatcher.IsPresent
            }
            observedContext  = [ordered]@{
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
            blockingReasons  = @($script:BlockingReasons)
            warnings         = @($script:Warnings)
            strategyTrace    = @($script:StrategyTrace)
        }
        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional.'
    }

    $artifactDirectory = New-ArtifactDirectory
    $probeLogPath = Join-Path $artifactDirectory 'probe-stage.json'
    $script:TimingLog['probeStart'] = Get-GeneXusMsBuildNowIso
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath
    $script:TimingLog['probeEnd'] = Get-GeneXusMsBuildNowIso

    Add-StrategyTrace -Message ('Probe executado antes do build com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe não apto para prosseguir bloqueou o build.'
        $probeDiagnostic = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status           = 'não apto para prosseguir'
            summary          = 'Probe bloqueou o build.'
            exitCode         = $probeStage.ExitCode
            stage            = 'probe'
            requestedContext = [ordered]@{
                VersionName                = $VersionName
                EnvironmentName            = $EnvironmentName
                ForceRebuild               = $ForceRebuild
                CompileMains               = $CompileMains
                DetailedNavigation         = $DetailedNavigation
                Configuration              = $Configuration
                EffectiveFailIfReorg       = $FailIfReorg
                EffectiveDoNotExecuteReorg = $DoNotExecuteReorg
                AllowReorgRequested        = $AllowReorg.IsPresent
                AllowReorgConfirmed        = $false
                ConfirmReorgMode           = $confirmReorgMode
                AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
                AllowWideRebuildConfirmed  = $false
                ConfirmWideRebuildMode     = $confirmWideRebuildMode
                StartWatcherRequested      = $StartWatcher.IsPresent
                TimeoutSeconds             = $TimeoutSeconds
            }
            observedContext  = [ordered]@{
                ActiveVersion     = $null
                ActiveEnvironment = $null
                KbOpen            = $false
                BuildAllDone      = $false
                ReorgDetected     = $false
                TimedOut          = $false
                MsBuildExitCode   = $null
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
                ProbeLogPath     = $probeLogPath
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
            }
            watcherContext   = $script:WatcherContext
            blockingReasons  = @($probeDiagnostic.blockingReasons + $script:BlockingReasons)
            warnings         = @($probeDiagnostic.warnings)
            strategyTrace    = @($probeDiagnostic.strategyTrace + $script:StrategyTrace)
        }

        $blocked['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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
    # Sem isso, builds headless cuja KB atinja as fases "DeveloperMenu Compilacao" ou
    # "Atualizacao de configuração da web" falham com "Não foi possível encontrar uma parte
    # do caminho". A IDE GeneXus já faz esse enriquecimento implicito; MSBuild via wrapper
    # externo herda apenas o PATH do shell do agente. Evidencia empirica:
    # Temp\xpz-build-verify-path-20260520-r1d (sem enriquecimento, falha) vs
    # Temp\xpz-build-verify-path-20260520-r2 (com enriquecimento, compilou limpo).
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

    $effectiveFailIfReorg       = $FailIfReorg
    $effectiveDoNotExecuteReorg = $DoNotExecuteReorg
    $allowReorgConfirmed        = $false
    $allowWideRebuildConfirmed  = $false

    # Confirmação explícita de regeneração ampla (ForceRebuild=true + -AllowWideRebuild)
    # Esta confirmação é independente da reorg: a regeneração ampla pode ocorrer sem reorg.
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
            Write-Host 'ForceRebuild=true equivale a "Rebuild All" da IDE: regenera TODOS os objetos'
            Write-Host 'da KB, nao apenas os alterados desde o ultimo build. Em KB grande pode levar'
            Write-Host 'horas e regenerar centenas/milhares de objetos, incluindo subtype groups.'
            Write-Host ''
            Write-Host 'Para confirmar, digite EXATAMENTE a frase abaixo (sem aspas):'
            Write-Host '    entendo que isto pode regerar a KB inteira e aceito o custo'
            Write-Host ''
            $wideRebuildConfirmation = Read-Host 'Confirmacao'

            if ($wideRebuildConfirmation -ne 'entendo que isto pode regerar a KB inteira e aceito o custo') {
                Add-BlockingReason -Reason 'Regeneracao ampla (ForceRebuild=true) nao confirmada pelo usuario com a frase exata. Execucao cancelada por seguranca.'
                $aborted = [ordered]@{
                    status           = 'cancelado pelo usuario'
                    summary          = 'Regeneracao ampla nao confirmada pelo usuario. Build cancelado por seguranca.'
                    exitCode         = 47
                    stage            = 'pre-build'
                    requestedContext = [ordered]@{
                        VersionName                = $VersionName
                        EnvironmentName            = $EnvironmentName
                        ForceRebuild               = $ForceRebuild
                        CompileMains               = $CompileMains
                        DetailedNavigation         = $DetailedNavigation
                        Configuration              = $Configuration
                        EffectiveFailIfReorg       = $effectiveFailIfReorg
                        EffectiveDoNotExecuteReorg = $effectiveDoNotExecuteReorg
                        AllowReorgRequested        = $AllowReorg.IsPresent
                        AllowReorgConfirmed        = $false
                        ConfirmReorgMode           = $confirmReorgMode
                        AllowWideRebuildRequested  = $true
                        AllowWideRebuildConfirmed  = $false
                        ConfirmWideRebuildMode     = $confirmWideRebuildMode
                        StartWatcherRequested      = $StartWatcher.IsPresent
                        TimeoutSeconds             = $TimeoutSeconds
                    }
                    observedContext  = [ordered]@{
                        ActiveVersion     = $null
                        ActiveEnvironment = $null
                        KbOpen            = $false
                        BuildAllDone      = $false
                        ReorgDetected     = $false
                        TimedOut          = $false
                        MsBuildExitCode   = $null
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
                    blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
                    warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
                    strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
                }
                $aborted['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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
        $costlyOptions = @()
        if ($CompileMains -eq 'true') { $costlyOptions += 'CompileMains=true' }
        if ($DetailedNavigation -eq 'true') { $costlyOptions += 'DetailedNavigation=true' }

        if ($ConfirmCostlyBuildOptions.IsPresent) {
            $allowCostlyBuildOptionsConfirmed = $true
            $confirmCostlyBuildOptionsMode    = 'parameter'
            Add-StrategyTrace -Message ('AllowCostlyBuildOptions confirmado via -ConfirmCostlyBuildOptions (modo nao-interativo). Opcoes autorizadas: {0}.' -f ($costlyOptions -join ', '))
        } else {
            $confirmCostlyBuildOptionsMode = 'interactive'
            Write-Host ''
            Write-Host 'AVISO: opcoes caras de build foram solicitadas.'
            Write-Host ''
            Write-Host ('KB alvo:      {0}' -f $resolvedKbPath)
            Write-Host ('GeneXusDir:   {0}' -f $resolvedGeneXusDir)
            Write-Host ('Opcoes:       {0}' -f ($costlyOptions -join ', '))
            Write-Host ''
            Write-Host 'CompileMains=true compila tambem os objetos Main, alem do Developer Menu.'
            Write-Host 'DetailedNavigation=true executa navegacao detalhada durante a especificacao.'
            Write-Host 'Em KB grande, essas opcoes podem ampliar muito o tempo do build e gerar custo'
            Write-Host 'operacional semelhante a execucoes que o usuario pretendia evitar.'
            Write-Host ''
            Write-Host 'Para confirmar, digite EXATAMENTE a frase abaixo (sem aspas):'
            Write-Host '    entendo que estas opcoes podem ampliar muito o custo do build e aceito executar'
            Write-Host ''
            $costlyConfirmation = Read-Host 'Confirmacao'

            if ($costlyConfirmation -ne 'entendo que estas opcoes podem ampliar muito o custo do build e aceito executar') {
                Add-BlockingReason -Reason 'Opcoes caras de build nao confirmadas pelo usuario com a frase exata. Execucao cancelada por seguranca.'
                $aborted = [ordered]@{
                    status           = 'cancelado pelo usuario'
                    summary          = 'Opcoes caras de build nao confirmadas pelo usuario. Build cancelado por seguranca.'
                    exitCode         = 47
                    stage            = 'pre-build'
                    requestedContext = [ordered]@{
                        VersionName                     = $VersionName
                        EnvironmentName                 = $EnvironmentName
                        ForceRebuild                    = $ForceRebuild
                        CompileMains                    = $CompileMains
                        DetailedNavigation              = $DetailedNavigation
                        CostlyBuildOptions              = @($costlyOptions)
                        Configuration                   = $Configuration
                        EffectiveFailIfReorg            = $effectiveFailIfReorg
                        EffectiveDoNotExecuteReorg      = $effectiveDoNotExecuteReorg
                        AllowReorgRequested             = $AllowReorg.IsPresent
                        AllowReorgConfirmed             = $false
                        ConfirmReorgMode                = $confirmReorgMode
                        AllowWideRebuildRequested       = $AllowWideRebuild.IsPresent
                        AllowWideRebuildConfirmed       = $allowWideRebuildConfirmed
                        ConfirmWideRebuildMode          = $confirmWideRebuildMode
                        AllowCostlyBuildOptionsRequested = $true
                        AllowCostlyBuildOptionsConfirmed = $false
                        ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
                        StartWatcherRequested           = $StartWatcher.IsPresent
                        TimeoutSeconds                  = $TimeoutSeconds
                    }
                    observedContext  = [ordered]@{
                        ActiveVersion     = $null
                        ActiveEnvironment = $null
                        KbOpen            = $false
                        BuildAllDone      = $false
                        ReorgDetected     = $false
                        TimedOut          = $false
                        MsBuildExitCode   = $null
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
                    blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
                    warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
                    strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
                }
                $aborted['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
                $abortedJson = ConvertTo-JsonText -InputObject $aborted
                if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
                    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $abortedJson
                }
                Write-Output $abortedJson
                exit 47
            }

            $allowCostlyBuildOptionsConfirmed = $true
            Add-StrategyTrace -Message ('AllowCostlyBuildOptions confirmado pelo usuario interativamente via frase exata. Opcoes autorizadas: {0}.' -f ($costlyOptions -join ', '))
        }
    } elseif ($AllowCostlyBuildOptions.IsPresent) {
        Add-WarningMessage -Message '-AllowCostlyBuildOptions foi informado, mas CompileMains=false e DetailedNavigation=false; o autorizador e redundante neste cenario.'
        Add-StrategyTrace -Message '-AllowCostlyBuildOptions redundante: nenhuma opcao cara de build foi solicitada.'
    }

    if ($AllowReorg.IsPresent) {
        if ($ConfirmReorg.IsPresent) {
            $effectiveFailIfReorg       = 'false'
            $effectiveDoNotExecuteReorg = 'false'
            $allowReorgConfirmed        = $true
            $confirmReorgMode           = 'parameter'
            Add-StrategyTrace -Message 'AllowReorg confirmado via -ConfirmReorg (modo nao-interativo). FailIfReorg=false, DoNotExecuteReorg=false habilitados.'
        } else {
            $confirmReorgMode = 'interactive'
            Write-Host ''
            Write-Host 'AVISO: O parametro -AllowReorg foi especificado.'
            Write-Host ''
            Write-Host ('KB alvo:      {0}' -f $resolvedKbPath)
            Write-Host ('GeneXusDir:   {0}' -f $resolvedGeneXusDir)
            Write-Host ''
            Write-Host 'A reorganizacao do banco de dados sera executada se o GeneXus detectar'
            Write-Host 'alteracoes estruturais pendentes. Esta operacao altera permanentemente'
            Write-Host 'o esquema do banco de dados e nao pode ser desfeita automaticamente.'
            Write-Host ''
            $confirmation = Read-Host 'Confirma a execucao com reorg habilitada? (sim para confirmar, qualquer outra entrada cancela)'

            if ($confirmation -notin @('sim', 'SIM', 'Sim', 's', 'S')) {
                Add-BlockingReason -Reason 'Reorg nao confirmada pelo usuario. Execucao cancelada por seguranca.'
                $aborted = [ordered]@{
                    status           = 'cancelado pelo usuario'
                    summary          = 'Execucao com reorg nao confirmada pelo usuario. Build cancelado por seguranca.'
                    exitCode         = 47
                    stage            = 'pre-build'
                    requestedContext = [ordered]@{
                        VersionName                = $VersionName
                        EnvironmentName            = $EnvironmentName
                        ForceRebuild               = $ForceRebuild
                        CompileMains               = $CompileMains
                        DetailedNavigation         = $DetailedNavigation
                        Configuration              = $Configuration
                        EffectiveFailIfReorg       = $effectiveFailIfReorg
                        EffectiveDoNotExecuteReorg = $effectiveDoNotExecuteReorg
                        AllowReorgRequested        = $true
                        AllowReorgConfirmed        = $false
                        ConfirmReorgMode           = $confirmReorgMode
                        AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
                        AllowWideRebuildConfirmed  = $allowWideRebuildConfirmed
                        ConfirmWideRebuildMode     = $confirmWideRebuildMode
                        StartWatcherRequested      = $StartWatcher.IsPresent
                        TimeoutSeconds             = $TimeoutSeconds
                    }
                    observedContext  = [ordered]@{
                        ActiveVersion     = $null
                        ActiveEnvironment = $null
                        KbOpen            = $false
                        BuildAllDone      = $false
                        ReorgDetected     = $false
                        TimedOut          = $false
                        MsBuildExitCode   = $null
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
                    blockingReasons  = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
                    warnings         = @($probeStage.Diagnostic.warnings + $script:Warnings)
                    strategyTrace    = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
                }
                $aborted['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
            $abortedJson = ConvertTo-JsonText -InputObject $aborted
                if (-not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
                    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $abortedJson
                }
                Write-Output $abortedJson
                exit 47
            }

            $effectiveFailIfReorg       = 'false'
            $effectiveDoNotExecuteReorg = 'false'
            $allowReorgConfirmed        = $true
            Add-StrategyTrace -Message 'AllowReorg confirmado pelo usuario interativamente. FailIfReorg=false, DoNotExecuteReorg=false habilitados.'
        }
    }

    if ($TimeoutSeconds -gt 0) {
        Add-StrategyTrace -Message ('Timeout configurado: {0} segundos.' -f $TimeoutSeconds)
    } else {
        Add-StrategyTrace -Message 'Sem timeout configurado. MSBuild aguardado por tempo indeterminado.'
    }

    if ([string]::IsNullOrEmpty($Configuration)) {
        Add-StrategyTrace -Message 'Configuration nao especificada. Configuracao ativa da KB sera mantida sem alteracao.'
    } else {
        Add-StrategyTrace -Message ('Configuration especificada: {0}. SetConfiguration sera emitido imediatamente antes do BuildAll.' -f $Configuration)
    }

    $msBuildFilePath = Join-Path $artifactDirectory 'buildall.msbuild'
    $stdOutPath      = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath      = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-MsBuildProjectContent `
        -ResolvedGeneXusDir $resolvedGeneXusDir `
        -ResolvedKbPath $resolvedKbPath `
        -EffectiveFailIfReorg $effectiveFailIfReorg `
        -EffectiveDoNotExecuteReorg $effectiveDoNotExecuteReorg

    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild temporario gerado em: {0}' -f $msBuildFilePath)

    $script:TimingLog['msbuildConcurrencyCheckStart'] = Get-GeneXusMsBuildNowIso
    $msBuildConcurrency = Invoke-GeneXusMsBuildKbConcurrencyCheck -KbPath $resolvedKbPath -ExcludeProcessId $PID
    $script:TimingLog['msbuildConcurrencyCheckEnd'] = Get-GeneXusMsBuildNowIso
    Add-StrategyTrace -Message ('Preflight de concorrencia MSBuild concluido com status {0}.' -f $msBuildConcurrency.status)
    if ([int]$msBuildConcurrency.exitCode -ne 0) {
        Add-BlockingReason -Reason $msBuildConcurrency.summary
        $blocked = [ordered]@{
            status = 'bloqueado por MSBuild concorrente'
            summary = $msBuildConcurrency.summary
            exitCode = 46
            stage = 'pre-buildall'
            requestedContext = [ordered]@{
                VersionName = $VersionName
                EnvironmentName = $EnvironmentName
                Configuration = $Configuration
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
            -WatcherContext         $script:WatcherContext `
            -ScriptsDirectory       (Split-Path -Parent $PSCommandPath) `
            -LogFilePath            $stdOutPath `
            -MonitorLogFilePath     $MonitorLogPath `
            -IntervalSeconds        $WatcherIntervalSeconds `
            -SilenceThresholdSeconds $WatcherSilenceThresholdSeconds
    }

    $script:TimingLog['msbuildStart'] = Get-GeneXusMsBuildNowIso
    $msBuildResult   = Invoke-MsBuildFile -ResolvedMsBuildPath $resolvedMsBuildPath -MsBuildFilePath $msBuildFilePath -StdOutPath $stdOutPath -StdErrPath $stdErrPath
    $script:TimingLog['msbuildEnd'] = Get-GeneXusMsBuildNowIso
    $msBuildExitCode = $msBuildResult.ExitCode
    $timedOut        = $msBuildResult.TimedOut

    $stdOutText = Read-TextFileSafe -PathValue $stdOutPath
    $stdErrText = Read-TextFileSafe -PathValue $stdErrPath

    $kbOpenMarker     = Get-MarkerValue -Text $stdOutText -Marker '__KB_OPEN__='
    $buildAllDoneMarker = Get-MarkerValue -Text $stdOutText -Marker '__BUILDALL_DONE__='
    $kbOpen       = ($kbOpenMarker -eq 'true')
    $buildAllDone = ($buildAllDoneMarker -eq 'true')

    # Detecta reorg pelo conteúdo do stdout/stderr (padrão GeneXus: "reorganization", "reorganizacao")
    $combinedOutput = $stdOutText + $stdErrText
    $reorgDetected  = [bool]($combinedOutput -match '(?i)reorgan')
    $script:BuildSignals['ReorgDetected'] = $reorgDetected

    # Detecta falha de SetActiveVersion (versão informada não existe na KB)
    $setVersionFailed = [bool]($stdOutText -match 'Set Active Version falhou')
    $setEnvironmentFailed = [bool]($stdOutText -match 'Set Active Environment falhou')

    $activeVersionOutput     = Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'"
    $activeEnvironmentOutput = Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'"
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
        Add-WarningMessage -Message 'Versao solicitada, mas o retorno de GetActiveVersion veio vazio.'
    }
    if (-not [string]::IsNullOrWhiteSpace($EnvironmentName) -and [string]::IsNullOrWhiteSpace($activeEnvironmentOutput) -and -not $setEnvironmentFailed) {
        Add-WarningMessage -Message 'Environment solicitado, mas o retorno de GetActiveEnvironment veio vazio.'
    }

    $buildStatus = Resolve-BuildStatus `
        -MsBuildExitCode    $msBuildExitCode `
        -KbOpen             $kbOpen `
        -BuildAllDone       $buildAllDone `
        -ReorgDetected      $reorgDetected `
        -TimedOut           $timedOut `
        -AllowReorgConfirmed $allowReorgConfirmed

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
    $buildWarningLines = @()
    $buildErrors = @()
    $knownStdOutNoiseBuild = @()

    try {
    # GeneXus 18 grava ruídos conhecidos no stderr durante BuildAll/SpecifyAll.
    # O par [anonymous]+component tem evidencia datada em FabricaBrasil18/wsEducacaoSpTeste
    # (2026-05-10, 3x); o par [/g_service_worker]+obj foi observado em KBs Java/Tomcat.
    # Pares cruzados permanecem stderr real. Filtrar antes de classificar.
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

    $stdOutBlockingPatternRegex = 'Access denied|error MSB|: error |FAILED|at System\.|at Microsoft\.'
    $blockingPatternMatch       = [regex]::Match($stdOutFiltered, $stdOutBlockingPatternRegex)
    $detectedBlockingPattern    = if ($blockingPatternMatch.Success) { $blockingPatternMatch.Value } else { $null }

    $postBuildEventLines = @(Get-GeneXusMsBuildPostBuildEventLines -StdOutLines $stdOutNonNoiseLines)
    # Carrega adiante as linhas pos-build (deploy, sino etc.) para os caminhos de
    # excecao. Generico e KB-agnostico: a linha bruta (ex.: o .bat de deploy) chega
    # ao bucket sem detector dedicado. @() = computou sem eventos; null (default) =
    # a falha estourou antes daqui.
    $script:BuildSignals['PostBuildEvents'] = @($postBuildEventLines)

    $buildWarningLines   = @([regex]::Matches($stdOutFiltered, '(?m)[^\r\n]*\(\d+,\d+\)\s*:\s*warning\s*:[^\r\n]*') |
                             ForEach-Object { $_.Value.Trim() })

    if ($buildStatus.Status -eq 'compilou limpo' -and -not [string]::IsNullOrWhiteSpace($stdErrFiltered)) {
        $buildStatus = [ordered]@{
            Status   = 'operacao concluida, pendente de confirmacao funcional'
            Summary  = 'BuildAll concluiu sem erro de MSBuild, mas stderr nao esta vazio. Verifique stderrContent no diagnostico.'
            ExitCode = 0
        }
    }

    if ($buildStatus.Status -eq 'compilou limpo' -and $detectedBlockingPattern) {
        $buildStatus = [ordered]@{
            Status   = 'operacao concluida, pendente de confirmacao funcional'
            Summary  = "BuildAll concluiu sem erro de MSBuild, mas stdout contem padrao de alerta: '$detectedBlockingPattern'. Verifique stdoutSignals no diagnostico."
            ExitCode = 0
        }
    }

    if ($postBuildEventLines.Count -gt 0) {
        # Classifica os eventos contra o conjunto registrado do environment ativo em
        # kb-source-metadata.md (kb_environment_post_build_event_hashes). Saidas inertes ja
        # foram separadas pelo suporte compartilhado; cada evento restante registrado e esperado
        # (informativo), e cada evento restante sem registro rebaixa. Sem registro para o
        # environment, so o fallback estrito de som e benigno.
        $metadataPathForPostBuild = $null
        if ($null -ne $script:DeploymentEnvironmentContext) {
            $metadataPathForPostBuild = Get-GeneXusKbDeploymentContextValue -DeploymentEnvironmentContext $script:DeploymentEnvironmentContext -Name 'kbSourceMetadataPath'
        }
        $registeredPostBuildHashes = Get-GeneXusRegisteredPostBuildEventHashesForEnvironment `
            -MetadataPath $metadataPathForPostBuild -EnvironmentName $activeEnvironmentOutput
        $pbClassification = Get-GeneXusPostBuildEventClassification `
            -PostBuildEventLines $postBuildEventLines -RegisteredHashes $registeredPostBuildHashes

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

        if ($pbClassification.shouldDowngrade -and $buildStatus.Status -eq 'compilou limpo') {
            $buildStatus = [ordered]@{
                Status   = 'operacao concluida, pendente de confirmacao funcional'
                Summary  = 'BuildAll concluiu sem erro de MSBuild, mas stdout indica evento pos-build nao registrado/nao reconhecido. Verifique stdoutSignals.postBuildEvents no diagnostico.'
                ExitCode = 0
            }
        }
    }

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
            $buildSignalsJson = (& $signalsScript -StdOutPath $stdOutPath -StdErrPath $stdErrPath -Stage 'build-all' -AsJson) | Out-String
            if (-not [string]::IsNullOrWhiteSpace($buildSignalsJson)) {
                $parsedBuildSignals = $buildSignalsJson | ConvertFrom-Json
                if ($null -ne $parsedBuildSignals.PSObject.Properties['errors']) {
                    $buildErrors = @($parsedBuildSignals.errors)
                }
                if ($null -ne $parsedBuildSignals.PSObject.Properties['knownStdOutNoise']) {
                    $knownStdOutNoiseBuild = @($parsedBuildSignals.knownStdOutNoise)
                }
            }
        }
        catch {
            Add-WarningMessage -Message ('Falha ao classificar sinais build-all para Categoria B: {0}' -f $_.Exception.Message)
        }
    }

    # Carrega a contagem canonica de erros adiante para os caminhos de excecao. Se a
    # analise abortou antes daqui, ErrorCount permanece null (parcial honesto). Se
    # chegou aqui, este 0/N e o mesmo valor que o caminho feliz reportaria.
    $script:BuildSignals['ErrorCount'] = @($buildErrors).Count
    # ErrorCount e o ultimo sinal da sequencia (reorg, eventos pos-build e erros ja
    # foram calculados antes daqui); alcancar esta linha marca o bucket como integral.
    # Ao adicionar um sinal calculado DEPOIS deste ponto, mover esta marcacao para
    # depois dele.
    $script:BuildSignals['Complete'] = $true

    if ($msBuildExitCode -eq 0 -and $buildStatus.ExitCode -eq 0) {
        $categoryBExit = Resolve-GeneXusMsBuildCategoryBExitCode `
            -BaseExitCode $buildStatus.ExitCode `
            -MsBuildExitCode $msBuildExitCode `
            -MsBuildErrors $buildErrors `
            -InvalidTypesRejected @()
        if ($categoryBExit -eq $script:GeneXusMsBuildCategoryBExitCode) {
            $msBuildCategoryBBlocked = $true
            $operationalSubStateBuild = $script:BuildOperationalSubStateCategoryB
            $categoryBSummary = Get-GeneXusMsBuildCategoryBStatusSummary `
                -OperationLabel 'BuildAll' `
                -ArtifactOnDisk $false `
                -ArtifactKind $null
            $buildStatus = [ordered]@{
                Status   = $categoryBSummary.Status
                Summary  = $categoryBSummary.Summary
                ExitCode = $categoryBExit
            }
            foreach ($reason in (Get-GeneXusMsBuildCategoryBBlockingReasons -MsBuildErrors $buildErrors -InvalidTypesRejected @() -StageLabel 'BuildAll')) {
                Add-BlockingReason -Reason $reason
            }
        }
    }

    if ($buildStatus.ExitCode -ne 0 -and -not $msBuildCategoryBBlocked -and $script:BlockingReasons.Count -eq 0) {
        Add-BlockingReason -Reason 'MSBuild falhou sem causa acionável classificada; consulte executionEvidence e logs brutos nos artefatos.'
    }

    if ($buildStatus.Status -eq 'reorg necessaria detectada') {
        Add-WarningMessage -Message 'Recomenda-se abrir a KB na IDE para inspecionar a reorganizacao gerada antes de decidir executa-la.'
    }

    if ($buildStatus.Status -eq 'operacao concluida, pendente de confirmacao funcional' -and -not [string]::IsNullOrWhiteSpace($stdErrFiltered)) {
        $stderrPreview = ((Split-NonEmptyLines -Text $stdErrFiltered) | Select-Object -First 5 | ForEach-Object { $_.TrimEnd() }) -join ' | '
        Add-WarningMessage -Message "Stderr nao vazio detectado apos build: $stderrPreview"
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
    }

    if ($postProcessingFailed -and ($msBuildExitCode -eq 0) -and ($null -ne $buildStatus) -and ($buildStatus.ExitCode -eq 0) -and ($buildStatus.Status -eq 'compilou limpo')) {
        $buildStatus = [ordered]@{
            Status   = 'compilou limpo'
            Summary  = 'BuildAll concluiu sem erro de MSBuild, mas o pos-processamento local falhou. Evidencias do MSBuild preservadas nos artefatos.'
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

        # Decide o gate de deploy bin pelo fato (exit 0 + BuildAll concluido), não pela string
        # de status. Rebaixamentos benignos (sino pos-build, ruido de stderr) mantem ExitCode 0
        # e não devem suprimir a validação pedida; Category B/reorg/timeout já derrubam ExitCode.
        $buildOperationallySucceeded = ($buildStatus.ExitCode -eq 0 -and $buildAllDone)

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
            -OperationLabel 'BuildAll'

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
            Add-WarningMessage -Message ("ActiveEnvironment observado ('{0}') diverge do environment de validacao resolvido ('{1}'). Nao tratar compilou limpo como validacao deploy nesse environment." -f $activeEnvironmentOutput, $expectedEnv)
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
        stage            = 'build-all'
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
            CompileMains               = $CompileMains
            DetailedNavigation         = $DetailedNavigation
            Configuration              = $Configuration
            EffectiveFailIfReorg       = $effectiveFailIfReorg
            EffectiveDoNotExecuteReorg = $effectiveDoNotExecuteReorg
            AllowReorgRequested        = $AllowReorg.IsPresent
            AllowReorgConfirmed        = $allowReorgConfirmed
            ConfirmReorgMode           = $confirmReorgMode
            AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
            AllowWideRebuildConfirmed  = $allowWideRebuildConfirmed
            ConfirmWideRebuildMode     = $confirmWideRebuildMode
            AllowCostlyBuildOptionsRequested = $AllowCostlyBuildOptions.IsPresent
            AllowCostlyBuildOptionsConfirmed = $allowCostlyBuildOptionsConfirmed
            ConfirmCostlyBuildOptionsMode    = $confirmCostlyBuildOptionsMode
            StartWatcherRequested      = $StartWatcher.IsPresent
            TimeoutSeconds             = $TimeoutSeconds
        }
        observedContext  = [ordered]@{
            ActiveVersion     = $activeVersionOutput
            ActiveEnvironment = $activeEnvironmentOutput
            KbOpen            = $kbOpen
            BuildAllDone      = $buildAllDone
            ReorgDetected     = $reorgDetected
            TimedOut          = $timedOut
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
        buildErrors          = @($buildErrors)
        knownStdOutNoise     = @($knownStdOutNoiseBuild)
        operationalSubState  = $operationalSubStateBuild
        msBuildCategoryBBlocked = $msBuildCategoryBBlocked
        stdoutSignals        = [ordered]@{
            blockingPattern = $detectedBlockingPattern
            postBuildEvents = $postBuildEventLines
            postBuildEventClassification = $pbClassification
            buildWarnings   = $buildWarningLines
            buildErrors     = @($buildErrors)
            knownStdOutNoise = @($knownStdOutNoiseBuild)
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

    $diagnostic['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath

    try {
        $json = ConvertTo-JsonText -InputObject $diagnostic
    }
    catch {
        $postProcessingFailed = $true
        $postProcessingError  = ('Falha ao serializar diagnostico apos MSBuild: {0}' -f $_.Exception.Message)
        Add-StrategyTrace -Message $postProcessingError
        if (($buildStatus.ExitCode -eq 0) -and ($msBuildExitCode -eq 0)) {
            $buildStatus = [ordered]@{
                Status   = 'compilou limpo'
                Summary  = 'BuildAll concluiu sem erro de MSBuild, mas a serializacao do diagnostico falhou. Evidencias primarias preservadas no log bruto.'
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
            stage                = 'build-all'
            buildSignals         = $script:BuildSignals
            artifacts            = [ordered]@{
                MsBuildStdoutLogPath = $stdOutPath
                MsBuildStderrLogPath = $stdErrPath
                ExecutionLogPath     = $resolvedLogPath
            }
            watcherContext       = $script:WatcherContext
            timing               = (Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath)
            note                 = 'Diagnostico completo nao pode ser serializado; consultar msbuild.stdout.log para evidencia primaria. buildSignals.Complete=true: reorg/erros/eventos pos-build sao integrais e confiaveis (nao reabrir o log para eles). Complete=false: bucket parcial — campo null nao e zero/vazio, reabrir o log para os campos null.'
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

    if ($SelfTestForceOuterRecovery.IsPresent) {
        throw 'SELFTEST: falha artificial antes da escrita do diagnostico normal.'
    }

    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $buildStatus.ExitCode
}
catch {
    $outerCatchError = $_.Exception.Message
    $postProcessingError = $outerCatchError
    if ($null -ne $msBuildExitCode) {
        $recoveryBuildAllDone = $false
        $recoveryKbOpen = $false
        $recoveryStdOut = ''
        $recoveryStdErr = $stdErrText
        $recoveryStdErrFilteredNoise = @()
        $recoveryStdErrContent = @()
        try {
            if (-not [string]::IsNullOrWhiteSpace($stdOutPath) -and (Test-Path -LiteralPath $stdOutPath -PathType Leaf)) {
                $recoveryStdOut = Read-TextFileSafe -PathValue $stdOutPath
                $recoveryBuildAllDone = ((Get-MarkerValue -Text $recoveryStdOut -Marker '__BUILDALL_DONE__=') -eq 'true')
                $recoveryKbOpen = ((Get-MarkerValue -Text $recoveryStdOut -Marker '__KB_OPEN__=') -eq 'true')
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
            $recoveryReorgDetected = [bool](($recoveryStdOut + $recoveryStdErr) -match '(?i)reorgan')
            $recoveryBuildStatus = Resolve-BuildStatus `
                -MsBuildExitCode $msBuildExitCode `
                -KbOpen $recoveryKbOpen `
                -BuildAllDone $recoveryBuildAllDone `
                -ReorgDetected $recoveryReorgDetected `
                -TimedOut $timedOut `
                -AllowReorgConfirmed $allowReorgConfirmed
        }

        if (($recoveryBuildStatus.Status -eq 'compilou limpo') -and (-not $recoveryKbOpen -or -not $recoveryBuildAllDone)) {
            $recoveryBuildStatus = Resolve-BuildStatus `
                -MsBuildExitCode $msBuildExitCode `
                -KbOpen $recoveryKbOpen `
                -BuildAllDone $recoveryBuildAllDone `
                -ReorgDetected $false `
                -TimedOut $timedOut `
                -AllowReorgConfirmed $allowReorgConfirmed
        }

        $recoveryExitCode = [int]$recoveryBuildStatus.ExitCode
        $recoveryStatus = [string]$recoveryBuildStatus.Status
        $recoverySummary = [string]$recoveryBuildStatus.Summary
        if (($recoveryExitCode -eq 0) -and ($recoveryStatus -eq 'compilou limpo') -and $recoveryKbOpen -and $recoveryBuildAllDone) {
            $recoveryStatus = 'compilou limpo com falha no pos-processamento'
            $recoverySummary = 'BuildAll concluiu sem erro de MSBuild e com marcador de conclusão, mas o wrapper falhou ao montar o diagnóstico. Consulte msbuild.stdout.log nos artefatos.'
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
            stage                = 'build-all'
            observedContext      = [ordered]@{
                KbOpen       = $recoveryKbOpen
                BuildAllDone = $recoveryBuildAllDone
                MsBuildExitCode = $msBuildExitCode
            }
            buildSignals         = $script:BuildSignals
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
            note                 = 'Diagnostico completo indisponivel apos falha interna; consultar msbuild.stdout.log para evidencia primaria. buildSignals.Complete=true: reorg/erros/eventos pos-build sao integrais e confiaveis (nao reabrir o log para eles). Complete=false: bucket parcial — campo null nao e zero/vazio, reabrir o log para os campos null.'
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
        summary          = 'Falha interna do script antes de concluir o build.'
        exitCode         = 90
        stage            = 'build-all'
        requestedContext = [ordered]@{
            VersionName                = $VersionName
            EnvironmentName            = $EnvironmentName
            ForceRebuild               = $ForceRebuild
            CompileMains               = $CompileMains
            DetailedNavigation         = $DetailedNavigation
            Configuration              = $Configuration
            EffectiveFailIfReorg       = $FailIfReorg
            EffectiveDoNotExecuteReorg = $DoNotExecuteReorg
            AllowReorgRequested        = $AllowReorg.IsPresent
            AllowReorgConfirmed        = $false
            ConfirmReorgMode           = $confirmReorgMode
            AllowWideRebuildRequested  = $AllowWideRebuild.IsPresent
            AllowWideRebuildConfirmed  = $false
            ConfirmWideRebuildMode     = $confirmWideRebuildMode
            StartWatcherRequested      = $StartWatcher.IsPresent
            TimeoutSeconds             = $TimeoutSeconds
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

    $failure['timing'] = Get-GeneXusMsBuildTimingSection -TimingLog $script:TimingLog -MonitorLogPath $MonitorLogPath
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
