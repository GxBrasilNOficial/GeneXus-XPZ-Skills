#requires -Version 7.4

<#
.SYNOPSIS
Verifica a consistência interna de uma KB GeneXus via task CheckKnowledgeBase do MSBuild.

.DESCRIPTION
Executa a task CheckKnowledgeBase com Fix="false" (padrão) ou Fix="true" (com
confirmação interativa obrigatória). O script reaproveita o probe
Test-GeneXusMsBuildSetup.ps1, abre a KB em modo headless controlado, executa
o check e interpreta o stdout para classificar o resultado em categorias distintas:
KB consistente, inconsistências detectadas, check parcial por timeout da Etapa 3 ou
KB inacessível. Emite diagnóstico estruturado em JSON.

Fix="true" modifica a KB fisicamente (reconstrução de índices SQL na Etapa 1 e
correção de inconsistências lógicas na Etapa 4). Este modo exige confirmação
interativa explícita antes de prosseguir.

.PARAMETER KbPath
Caminho da KB a verificar.

.PARAMETER WorkingDirectory
Diretório de trabalho para artefatos temporários desta execução.

.PARAMETER LogPath
Caminho completo do log JSON desta execução.

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, usa fallback do probe.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, usa fallback do probe.

.PARAMETER VersionName
Nome opcional da versão a posicionar antes do check.

.PARAMETER EnvironmentName
Nome opcional do Environment a posicionar antes do check.

.PARAMETER Fix
Ativa Fix="true" na task CheckKnowledgeBase. Modifica a KB fisicamente.
Exige confirmação interativa antes de prosseguir.

.PARAMETER VerboseLog
Amplia o detalhamento gravado no log sem alterar o resultado lógico.
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

    [switch]$Fix,

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
$sharedPathContractScript = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildPathContract.ps1'
. $sharedPathContractScript


function ConvertTo-JsonText {
    param([object]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 8)
}

function Write-JsonLog {
    param([string]$TargetLogPath, [string]$JsonPayload)
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
    $probeDiagnostic = $probeJson | ConvertFrom-Json

    return [ordered]@{
        ExitCode   = $probeExitCode
        Json       = $probeJson
        Diagnostic = $probeDiagnostic
    }
}

function New-ArtifactDirectory {
    $scriptDirectory = Split-Path -Parent $PSCommandPath
    $repositoryRoot = Split-Path -Parent $scriptDirectory
    $tempRoot = Join-Path $repositoryRoot 'Temp'
    $baseDirectory = Join-Path $tempRoot 'xpz-msbuild-import-export'
    [System.IO.Directory]::CreateDirectory($baseDirectory) | Out-Null
    $artifactDirectory = Join-Path $baseDirectory ('gx-kb-consistency-' + [System.Guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($artifactDirectory) | Out-Null
    return $artifactDirectory
}

function Escape-Xml {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Security.SecurityElement]::Escape($Value)
}

function New-MsBuildProjectContent {
    param(
        [string]$ResolvedGeneXusDir,
        [string]$ResolvedKbPath,
        [string]$FixValue
    )

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    $targetsEscaped    = Escape-Xml -Value $targetsPath
    $kbPathEscaped     = Escape-Xml -Value $ResolvedKbPath
    $versionEscaped    = Escape-Xml -Value $VersionName
    $environmentEscaped = Escape-Xml -Value $EnvironmentName
    $fixEscaped        = Escape-Xml -Value $FixValue

    return @"
<Project ToolsVersion="Current" DefaultTargets="Run" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <Import Project="$targetsEscaped" />

  <PropertyGroup>
    <KBPath>$kbPathEscaped</KBPath>
    <KBVersion>$versionEscaped</KBVersion>
    <KBEnvironment>$environmentEscaped</KBEnvironment>
    <CheckFix>$fixEscaped</CheckFix>
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
    <CheckKnowledgeBase Fix="`$(CheckFix)" />
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
    $process = Start-Process -FilePath $ResolvedMsBuildPath -ArgumentList $arguments `
        -WorkingDirectory (Split-Path -Parent $MsBuildFilePath) `
        -RedirectStandardOutput $StdOutPath -RedirectStandardError $StdErrPath `
        -NoNewWindow -PassThru -Wait
    return $process.ExitCode
}

function Read-TextFileSafe {
    param([string]$PathValue)
    if (-not (Test-Path -LiteralPath $PathValue -PathType Leaf)) { return '' }
    return [System.IO.File]::ReadAllText($PathValue)
}

function Get-MarkerValue {
    param([string]$Text, [string]$Marker)
    $match = [regex]::Match($Text, [regex]::Escape($Marker) + '(.*)')
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim()
}

function Get-RegexValue {
    param([string]$Text, [string]$Pattern)
    $match = [regex]::Match($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) { return $null }
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

function New-ExecutionEvidence {
    param(
        [object]$MsBuildExitCode,
        [int]$WrapperExitCode,
        [string]$StdOutPath,
        [string]$StdErrPath
    )

    $msBuildFailed = $null
    if ($null -ne $MsBuildExitCode) {
        $msBuildFailed = ([int]$MsBuildExitCode -ne 0)
    }

    return [ordered]@{
        msBuildExitCode = $MsBuildExitCode
        msBuildFailed   = $msBuildFailed
        wrapperExitCode = $WrapperExitCode
        StdOutPath      = $StdOutPath
        StdErrPath      = $StdErrPath
    }
}

function Get-StepSummaries {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    $summaries = New-Object System.Collections.Generic.List[string]
    foreach ($line in ($Text -split "(`r`n|`n|`r)")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '\d+\s+problema\(s\)\s+encontrado\(s\)') {
            $summaries.Add($trimmed)
        }
    }
    return @($summaries)
}

function Get-SumFromSummaries {
    param([string[]]$Summaries, [string]$Pattern)
    $total = 0
    foreach ($s in $Summaries) {
        $m = [regex]::Match($s, $Pattern)
        if ($m.Success) { $total += [int]$m.Groups[1].Value }
    }
    return $total
}

function Build-ConsistencyResult {
    param([string]$StdOutText, [int]$MsBuildExitCode)

    $timeoutOnStep3 = $StdOutText -match [regex]::Escape('Tempo Limite de Execução Expirado')
    $kbOpenFailed   = ($MsBuildExitCode -ne 0) -and (-not $timeoutOnStep3)
    $fixModeActive  = $StdOutText -match [regex]::Escape('Parâmetro "Fix" especificado')

    $stepSummaries = Get-StepSummaries -Text $StdOutText
    $totalFound    = Get-SumFromSummaries -Summaries $stepSummaries -Pattern '(\d+)\s+problema\(s\)\s+encontrado\(s\)'
    $totalFixed    = Get-SumFromSummaries -Summaries $stepSummaries -Pattern '(\d+)\s+corrigido'

    return [ordered]@{
        hasInconsistencies = ($totalFound -gt 0)
        timeoutOnStep3     = [bool]$timeoutOnStep3
        kbOpenFailed       = [bool]$kbOpenFailed
        fixModeActive      = [bool]$fixModeActive
        totalFound         = $totalFound
        totalFixed         = $totalFixed
        stepSummaries      = $stepSummaries
    }
}

function Resolve-ScriptExitCode {
    param([int]$MsBuildExitCode, [System.Collections.Specialized.OrderedDictionary]$ConsistencyResult)

    if ($MsBuildExitCode -ne 0) {
        if ($ConsistencyResult.kbOpenFailed) { return 21 }
        return 20
    }
    if ($ConsistencyResult.hasInconsistencies) { return 1 }
    return 0
}

function Resolve-StatusLabel {
    param([int]$ScriptExitCode, [System.Collections.Specialized.OrderedDictionary]$ConsistencyResult)

    switch ($ScriptExitCode) {
        0  { return 'sucesso operacional' }
        1  { return 'sucesso operacional' }
        20 { return 'check parcial' }
        21 { return 'kb inacessível' }
        default { return 'falha operacional' }
    }
}

function Resolve-SummaryText {
    param([int]$ScriptExitCode, [System.Collections.Specialized.OrderedDictionary]$ConsistencyResult, [bool]$FixMode)

    $fixSuffix = if ($FixMode) { ' (Fix=true)' } else { '' }
    switch ($ScriptExitCode) {
        0  { return ('Check concluído sem inconsistências detectadas{0}.' -f $fixSuffix) }
        1  { return ('Check concluído{0}; {1} inconsistência(s) detectada(s).' -f $fixSuffix, $ConsistencyResult.totalFound) }
        20 { return ('Check parcial{0}: timeout na Etapa 3 detectado; achados das demais etapas podem ser válidos.' -f $fixSuffix) }
        21 { return ('KB inacessível: OpenKnowledgeBase falhou antes do check começar{0}.' -f $fixSuffix) }
        default { return ('Falha durante execução do check{0}.' -f $fixSuffix) }
    }
}

# ── estado global ────────────────────────────────────────────────────────────

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings        = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace   = New-Object System.Collections.Generic.List[string]

$resolvedLogPath = Get-FullPathSafe -PathValue $LogPath

$logPathRejection = Get-GeneXusMsBuildLogPathRejection -ResolvedLogPath $resolvedLogPath
if ($logPathRejection.rejected) {
    Write-Output (New-GeneXusMsBuildLogPathBlockJson -WrapperName 'Test-GeneXusKbConsistency.ps1' -ResolvedLogPath $resolvedLogPath -Reason $logPathRejection.reason)
    exit 50
}
$fixMode         = $Fix.IsPresent
$fixValue        = if ($fixMode) { 'true' } else { 'false' }

# ── confirmação explícita de Fix="true" ──────────────────────────────────────

if ($fixMode) {
    $displayKbPath = Get-FullPathSafe -PathValue $KbPath
    Write-Host ''
    Write-Host 'ATENCAO: -Fix ativado.'
    Write-Host ''
    Write-Host ('  KB alvo: {0}' -f $displayKbPath)
    Write-Host ''
    Write-Host '  Fix="true" realizara as seguintes operacoes na KB:'
    Write-Host '    Etapa 1 - reconstrucao (REBUILD) ou reorganizacao (REORGANIZE) de indices SQL'
    Write-Host '              altamente fragmentados; emite "Versao de composicao corrigida." quando aplicavel'
    Write-Host '    Etapa 4 - correcao de inconsistencias logicas entre EntityVersionComposition'
    Write-Host '              e ModelEntityVersion (cada item gera par: deteccao + confirmacao de correcao)'
    Write-Host '    Demais etapas - correcao de eventuais problemas encontrados em cada verificacao'
    Write-Host ''
    Write-Host '  Observacao: a Etapa 6 emite "Corrigindo redundancias..." para todas as versoes'
    Write-Host '  mesmo sem problemas reais; o resumo "0 corrigido" e o dado definitivo.'
    Write-Host ''
    $confirmation = Read-Host 'Digite SIM para confirmar e prosseguir com Fix=true'

    if ($confirmation -ne 'SIM') {
        $cancelled = [ordered]@{
            status    = 'não apto para prosseguir'
            summary   = 'Operação cancelada: usuário negou confirmação de Fix="true".'
            exitCode  = 30
            stage     = 'fix-confirmation'
            fixMode   = $true
            consistencyResult = [ordered]@{
                hasInconsistencies = $false
                timeoutOnStep3     = $false
                kbOpenFailed       = $false
                fixModeActive      = $false
                totalFound         = 0
                totalFixed         = 0
                stepSummaries      = @()
            }
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
            executionEvidence = New-ExecutionEvidence `
                -MsBuildExitCode $null `
                -WrapperExitCode 30 `
                -StdOutPath $null `
                -StdErrPath $null
            msBuildExitCode = $null
            stderrContent        = @()
            stderrFilteredNoise  = @()
            blockingReasons = @('Confirmação de Fix="true" negada pelo usuário.')
            warnings        = @()
            strategyTrace   = @()
        }

        $cancelledJson = ConvertTo-JsonText -InputObject $cancelled
        try {
            $logParent = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
            if (-not [string]::IsNullOrWhiteSpace($logParent) -and
                (Test-Path -LiteralPath $logParent -PathType Container) -and
                -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
                Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $cancelledJson
            }
        } catch { }

        Write-Output $cancelledJson
        exit 30
    }

    Add-StrategyTrace -Message 'Confirmação interativa de Fix="true" aceita pelo usuário.'
}

# ── execução principal ───────────────────────────────────────────────────────

try {
    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional do check.'
    }
    if ($fixMode) {
        Add-StrategyTrace -Message 'Fix="true" ativado; task CheckKnowledgeBase modificará a KB.'
    } else {
        Add-StrategyTrace -Message 'Fix="false" (padrão); task CheckKnowledgeBase executará apenas leitura.'
    }

    $artifactDirectory = New-ArtifactDirectory
    $probeLogPath = Join-Path $artifactDirectory 'probe-stage.json'
    $probeStage = Invoke-ProbeStage -ProbeLogPath $probeLogPath
    Add-StrategyTrace -Message ('Probe executado antes do check com exitCode {0}.' -f $probeStage.ExitCode)

    if ($probeStage.ExitCode -ne 0) {
        Add-BlockingReason -Reason 'Probe não apto para prosseguir bloqueou o check de consistência.'
        $probeDiag = $probeStage.Diagnostic
        $blocked = [ordered]@{
            status    = 'não apto para prosseguir'
            summary   = 'Probe bloqueou o check de consistência.'
            exitCode  = $probeStage.ExitCode
            stage     = 'probe'
            fixMode   = $fixMode
            consistencyResult = [ordered]@{
                hasInconsistencies = $false
                timeoutOnStep3     = $false
                kbOpenFailed       = $false
                fixModeActive      = $false
                totalFound         = 0
                totalFixed         = 0
                stepSummaries      = @()
            }
            resolvedPaths = [ordered]@{
                GeneXusDir       = $probeDiag.resolvedPaths.GeneXusDir
                MsBuildPath      = $probeDiag.resolvedPaths.MsBuildPath
                KbPath           = $probeDiag.resolvedPaths.KbPath
                WorkingDirectory = $probeDiag.resolvedPaths.WorkingDirectory
                LogPath          = $resolvedLogPath
            }
            artifacts = [ordered]@{
                ProbeLogPath     = $probeLogPath
                MsBuildFilePath  = $null
                StdOutPath       = $null
                StdErrPath       = $null
                ExecutionLogPath = $resolvedLogPath
            }
            executionEvidence = New-ExecutionEvidence `
                -MsBuildExitCode $null `
                -WrapperExitCode $probeStage.ExitCode `
                -StdOutPath $null `
                -StdErrPath $null
            msBuildExitCode = $null
            stderrContent        = @()
            stderrFilteredNoise  = @()
            blockingReasons = @($probeDiag.blockingReasons + $script:BlockingReasons)
            warnings        = @($probeDiag.warnings)
            strategyTrace   = @($probeDiag.strategyTrace + $script:StrategyTrace)
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

    $msBuildFilePath = Join-Path $artifactDirectory 'kb-consistency.msbuild'
    $stdOutPath      = Join-Path $artifactDirectory 'msbuild.stdout.log'
    $stdErrPath      = Join-Path $artifactDirectory 'msbuild.stderr.log'

    $projectContent = New-MsBuildProjectContent `
        -ResolvedGeneXusDir $resolvedGeneXusDir `
        -ResolvedKbPath $resolvedKbPath `
        -FixValue $fixValue

    [System.IO.File]::WriteAllText($msBuildFilePath, $projectContent, (Get-Utf8NoBomEncoding))
    Add-StrategyTrace -Message ('Arquivo .msbuild temporário gerado em: {0}' -f $msBuildFilePath)

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

    $consistencyResult = Build-ConsistencyResult -StdOutText $stdOutText -MsBuildExitCode $msBuildExitCode
    $scriptExitCode    = Resolve-ScriptExitCode -MsBuildExitCode $msBuildExitCode -ConsistencyResult $consistencyResult
    $statusLabel       = Resolve-StatusLabel -ScriptExitCode $scriptExitCode -ConsistencyResult $consistencyResult
    $summaryText       = Resolve-SummaryText -ScriptExitCode $scriptExitCode -ConsistencyResult $consistencyResult -FixMode $fixMode

    if ($consistencyResult.kbOpenFailed) {
        Add-BlockingReason -Reason 'OpenKnowledgeBase falhou antes do check começar.'
    }
    if ($consistencyResult.timeoutOnStep3) {
        Add-WarningMessage -Message 'Timeout detectado na Etapa 3; check parcial executado. Etapas seguintes podem ter resultados válidos.'
    }
    if ($fixMode -and -not $consistencyResult.fixModeActive) {
        Add-WarningMessage -Message 'Fix=true foi passado mas o marcador de confirmação não foi detectado no stdout. Verifique o log completo.'
    }

    $diagnostic = [ordered]@{
        status    = $statusLabel
        summary   = $summaryText
        exitCode  = $scriptExitCode
        stage     = 'check'
        fixMode   = $fixMode
        consistencyResult = $consistencyResult
        requestedContext = [ordered]@{
            VersionName     = $VersionName
            EnvironmentName = $EnvironmentName
        }
        observedContext = [ordered]@{
            ActiveVersion   = (Get-RegexValue -Text $stdOutText -Pattern "The active version is '([^']+)'")
            ActiveEnvironment = (Get-RegexValue -Text $stdOutText -Pattern "The active environment is '([^']+)'")
            OpenOutput      = (Get-MarkerValue -Text $stdOutText -Marker '__OPEN_OUTPUT__=')
        }
        resolvedPaths = [ordered]@{
            GeneXusDir       = $resolvedGeneXusDir
            MsBuildPath      = $resolvedMsBuildPath
            KbPath           = $resolvedKbPath
            WorkingDirectory = [string]$probeStage.Diagnostic.resolvedPaths.WorkingDirectory
            LogPath          = $resolvedLogPath
        }
        pathActions = $probeStage.Diagnostic.pathActions
        artifacts = [ordered]@{
            ProbeLogPath     = $probeLogPath
            MsBuildFilePath  = $msBuildFilePath
            StdOutPath       = $stdOutPath
            StdErrPath       = $stdErrPath
            ExecutionLogPath = $resolvedLogPath
        }
        executionEvidence = New-ExecutionEvidence `
            -MsBuildExitCode $msBuildExitCode `
            -WrapperExitCode $scriptExitCode `
            -StdOutPath $stdOutPath `
            -StdErrPath $stdErrPath
        msBuildExitCode = $msBuildExitCode
        stderrContent        = Split-NonEmptyLines -Text $stdErrFiltered
        stderrFilteredNoise  = Split-NonEmptyLines -Text $stdErrNoise
        blockingReasons = @($probeStage.Diagnostic.blockingReasons + $script:BlockingReasons)
        warnings        = @($probeStage.Diagnostic.warnings + $script:Warnings)
        strategyTrace   = @($probeStage.Diagnostic.strategyTrace + $script:StrategyTrace)
    }

    $json = ConvertTo-JsonText -InputObject $diagnostic
    Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $json
    Write-Output $json
    exit $scriptExitCode
}
catch {
    $failure = [ordered]@{
        status    = 'falha operacional'
        summary   = 'Falha interna do script antes de concluir o check de consistência.'
        exitCode  = 90
        stage     = 'check'
        fixMode   = $fixMode
        consistencyResult = [ordered]@{
            hasInconsistencies = $false
            timeoutOnStep3     = $false
            kbOpenFailed       = $false
            fixModeActive      = $false
            totalFound         = 0
            totalFixed         = 0
            stepSummaries      = @()
        }
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
            ProbeLogPath     = $null
            MsBuildFilePath  = $null
            StdOutPath       = $null
            StdErrPath       = $null
            ExecutionLogPath = $resolvedLogPath
        }
        executionEvidence = New-ExecutionEvidence `
            -MsBuildExitCode $null `
            -WrapperExitCode 90 `
            -StdOutPath $null `
            -StdErrPath $null
        msBuildExitCode = $null
        stderrContent        = @()
        stderrFilteredNoise  = @()
        blockingReasons = @($_.Exception.Message)
        warnings        = @()
        strategyTrace   = @($script:StrategyTrace)
    }

    $failureJson = ConvertTo-JsonText -InputObject $failure
    try {
        if (-not [string]::IsNullOrWhiteSpace($resolvedLogPath) -and
            -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPath)) {
            $parent = [System.IO.Path]::GetDirectoryName($resolvedLogPath)
            if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container)) {
                Write-JsonLog -TargetLogPath $resolvedLogPath -JsonPayload $failureJson
            }
        }
    } catch { }

    Write-Output $failureJson
    exit 90
}
