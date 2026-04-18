<#
.SYNOPSIS
Valida o ambiente mínimo para operações headless de GeneXus via MSBuild.

.DESCRIPTION
Executa um probe (sondagem técnica inicial) não invasivo para localizar
GeneXusDir e MsBuildPath, validar Genexus.Tasks.targets, conferir caminhos
seguros para WorkingDirectory e LogPath, e emitir um diagnóstico estruturado
em JSON. Este script não abre a KB, não gera .msbuild operacional e não
executa importação ou exportação.

.PARAMETER WorkingDirectory
 Diretório de trabalho explícito para etapas futuras. Deve ficar fora de
 C:\Program Files (x86). Se o caminho informado for seguro e ainda não existir,
 o probe pode criar automaticamente exatamente essa pasta.

.PARAMETER LogPath
Caminho completo do arquivo de log deste probe. O diretório pai deve existir e
ficar fora de C:\Program Files (x86).

.PARAMETER GeneXusDir
Caminho explícito da instalação do GeneXus. Quando omitido, o script tenta
fallback em caminhos conhecidos.

.PARAMETER MsBuildPath
Caminho explícito do MSBuild.exe. Quando omitido, o script tenta fallback em
caminhos conhecidos do Visual Studio ou Build Tools.

.PARAMETER KbPath
Caminho opcional de KB para validação de existência. Quando omitido, o probe
continua focado em host e instalação.

.PARAMETER VerboseLog
Amplia o detalhamento gravado no log sem alterar o resultado lógico.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $true)]
    [string]$LogPath,

    [string]$GeneXusDir,

    [string]$MsBuildPath,

    [string]$KbPath,

    [switch]$VerboseLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProgramFilesX86 = [System.IO.Path]::GetFullPath('C:\Program Files (x86)')
$sharedPathContractScript = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildPathContract.ps1'
. $sharedPathContractScript

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function New-Check {
    param(
        [string]$Name,
        [string]$Result,
        [string]$Detail
    )

    return [ordered]@{
        name = $Name
        result = $Result
        detail = $Detail
    }
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

function Get-KnownGeneXusCandidates {
    return @(
        'C:\Program Files (x86)\GeneXus\GeneXus18',
        'C:\GeneXus\GeneXus18'
    )
}

function Get-KnownMsBuildCandidates {
    return @(
        'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe'
    )
}

function Resolve-GeneXusDirectory {
    if (-not [string]::IsNullOrWhiteSpace($GeneXusDir)) {
        $resolved = Get-FullPathSafe -PathValue $GeneXusDir
        Add-StrategyTrace -Message 'GeneXusDir usado conforme parâmetro explícito.'
        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
            Add-BlockingReason -Reason ("GeneXusDir inválido: '{0}'." -f $resolved)
            return [ordered]@{
                path = $resolved
                result = 'fail'
                detail = 'Diretório informado não foi encontrado.'
                code = 10
            }
        }

        return [ordered]@{
            path = $resolved
            result = 'ok'
            detail = 'Diretório informado encontrado.'
            code = 0
        }
    }

    $matches = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in Get-KnownGeneXusCandidates) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $matches.Add((Get-FullPathSafe -PathValue $candidate))
        }
    }

    if ($matches.Count -gt 1) {
        Add-StrategyTrace -Message ('Fallback de GeneXusDir encontrou múltiplos candidatos: {0}' -f ($matches -join '; '))
        Add-BlockingReason -Reason 'Mais de uma instalação plausível de GeneXus foi encontrada sem regra de desempate.'
        return [ordered]@{
            path = $null
            result = 'fail'
            detail = 'Múltiplas instalações plausíveis encontradas.'
            code = 16
        }
    }

    if ($matches.Count -eq 1) {
        Add-StrategyTrace -Message ('GeneXusDir resolvido por fallback em caminho conhecido: {0}' -f $matches[0])
        return [ordered]@{
            path = $matches[0]
            result = 'ok'
            detail = 'Diretório localizado por fallback.'
            code = 0
        }
    }

    Add-StrategyTrace -Message 'Fallback de GeneXusDir esgotado sem sucesso.'
    Add-BlockingReason -Reason 'GeneXusDir não localizado.'
    return [ordered]@{
        path = $null
        result = 'fail'
        detail = 'Nenhum caminho conhecido do GeneXus foi encontrado.'
        code = 10
    }
}

function Resolve-MsBuildExecutable {
    if (-not [string]::IsNullOrWhiteSpace($MsBuildPath)) {
        $resolved = Get-FullPathSafe -PathValue $MsBuildPath
        Add-StrategyTrace -Message 'MsBuildPath usado conforme parâmetro explícito.'
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            Add-BlockingReason -Reason ("MsBuildPath inválido: '{0}'." -f $resolved)
            return [ordered]@{
                path = $resolved
                result = 'fail'
                detail = 'Executável informado não foi encontrado.'
                code = 11
            }
        }

        return [ordered]@{
            path = $resolved
            result = 'ok'
            detail = 'Executável informado encontrado.'
            code = 0
        }
    }

    $matches = New-Object System.Collections.Generic.List[string]
    foreach ($candidate in Get-KnownMsBuildCandidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $matches.Add((Get-FullPathSafe -PathValue $candidate))
        }
    }

    if ($matches.Count -gt 0) {
        $selected = $matches[0]
        $discarded = @($matches | Select-Object -Skip 1)
        Add-StrategyTrace -Message ('MsBuildPath não informado; fallback aplicado em caminhos conhecidos do Visual Studio. Selecionado: {0}' -f $selected)
        if ($discarded.Count -gt 0) {
            Add-StrategyTrace -Message ('Candidatos de MSBuild descartados: {0}' -f ($discarded -join '; '))
        }

        return [ordered]@{
            path = $selected
            result = 'ok'
            detail = 'MSBuild localizado por fallback em caminho conhecido.'
            code = 0
        }
    }

    Add-StrategyTrace -Message 'MsBuildPath não informado; fallback aplicado em caminhos conhecidos do Visual Studio sem sucesso.'
    Add-BlockingReason -Reason 'MSBuild.exe não localizado.'
    return [ordered]@{
        path = $null
        result = 'fail'
        detail = 'Nenhum caminho conhecido de MSBuild foi encontrado.'
        code = 11
    }
}

function Validate-TargetsFile {
    param([string]$ResolvedGeneXusDir)

    if ([string]::IsNullOrWhiteSpace($ResolvedGeneXusDir)) {
        return [ordered]@{
            path = $null
            result = 'skip'
            detail = 'Validação dependente de GeneXusDir resolvido.'
            code = 0
        }
    }

    $targetsPath = Join-Path $ResolvedGeneXusDir 'Genexus.Tasks.targets'
    if (Test-Path -LiteralPath $targetsPath -PathType Leaf) {
        return [ordered]@{
            path = (Get-FullPathSafe -PathValue $targetsPath)
            result = 'ok'
            detail = 'Arquivo localizado dentro da instalação do GeneXus.'
            code = 0
        }
    }

    Add-BlockingReason -Reason 'Genexus.Tasks.targets não localizado.'
    return [ordered]@{
        path = (Get-FullPathSafe -PathValue $targetsPath)
        result = 'fail'
        detail = 'Arquivo esperado não foi encontrado.'
        code = 12
    }
}

function Validate-LogPath {
    $resolved = Get-FullPathSafe -PathValue $LogPath
    $parent = [System.IO.Path]::GetDirectoryName($resolved)

    if ([string]::IsNullOrWhiteSpace($parent)) {
        Add-BlockingReason -Reason ("LogPath inválido: '{0}'." -f $resolved)
        return [ordered]@{
            path = $resolved
            result = 'fail'
            detail = 'LogPath não possui diretório pai válido.'
            code = 14
            check = New-Check -Name 'LogPath outside Program Files x86' -Result 'fail' -Detail 'LogPath não possui diretório pai válido.'
        }
    }

    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        Add-BlockingReason -Reason ("LogPath inválido: '{0}'." -f $resolved)
        return [ordered]@{
            path = $resolved
            result = 'fail'
            detail = 'Diretório pai do log não foi encontrado.'
            code = 14
            check = New-Check -Name 'LogPath outside Program Files x86' -Result 'fail' -Detail 'Diretório pai do log não foi encontrado.'
        }
    }

    if (Test-IsUnderProgramFilesX86 -PathValue $resolved) {
        Add-BlockingReason -Reason ('LogPath dentro de {0}.' -f $ProgramFilesX86)
        return [ordered]@{
            path = $resolved
            result = 'fail'
            detail = 'LogPath aponta para árvore estritamente somente leitura.'
            code = 14
            check = New-Check -Name 'LogPath outside Program Files x86' -Result 'fail' -Detail 'LogPath aponta para árvore estritamente somente leitura.'
        }
    }

    return [ordered]@{
        path = $resolved
        result = 'ok'
        detail = 'Destino de log fora da árvore somente leitura.'
        code = 0
        check = New-Check -Name 'LogPath outside Program Files x86' -Result 'ok' -Detail 'Destino de log fora da árvore somente leitura.'
    }
}

function Validate-KbPath {
    if ([string]::IsNullOrWhiteSpace($KbPath)) {
        Add-StrategyTrace -Message 'KbPath omitido nesta fase; validação de KB específica não executada.'
        return [ordered]@{
            path = $null
            result = 'skip'
            detail = 'KbPath não informado nesta fase.'
            code = 0
        }
    }

    $resolved = Get-FullPathSafe -PathValue $KbPath
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        Add-BlockingReason -Reason ("KbPath inválido: '{0}'." -f $resolved)
        return [ordered]@{
            path = $resolved
            result = 'fail'
            detail = 'KB não encontrada no caminho informado.'
            code = 15
        }
    }

    return [ordered]@{
        path = $resolved
        result = 'ok'
        detail = 'KB encontrada no caminho informado.'
        code = 0
    }
}

function Get-PrimaryExitCode {
    param([int[]]$Codes)

    if ($Codes -contains 16) { return 16 }
    if ($Codes -contains 10) { return 10 }
    if ($Codes -contains 11) { return 11 }
    if ($Codes -contains 12) { return 12 }
    if ($Codes -contains 13) { return 13 }
    if ($Codes -contains 14) { return 14 }
    if ($Codes -contains 15) { return 15 }
    return 0
}

function Write-LogFile {
    param(
        [string]$TargetLogPath,
        [string]$JsonPayload
    )

    [System.IO.File]::WriteAllText($TargetLogPath, $JsonPayload + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
}

$script:BlockingReasons = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]
$script:StrategyTrace = New-Object System.Collections.Generic.List[string]

$resolvedLogPathForFallback = Get-FullPathSafe -PathValue $LogPath

try {
    if ($VerboseLog.IsPresent) {
        Add-StrategyTrace -Message 'VerboseLog habilitado para detalhamento adicional do probe.'
    }

    $geneXusResolution = Resolve-GeneXusDirectory
    $msBuildResolution = Resolve-MsBuildExecutable
    $targetsResolution = Validate-TargetsFile -ResolvedGeneXusDir $geneXusResolution.path
    $workingValidation = Resolve-ExplicitWorkingDirectory -PathValue $WorkingDirectory -ProgramFilesX86 $ProgramFilesX86 -FailureCode 13
    $logValidation = Validate-LogPath
    $kbValidation = Validate-KbPath

    if (-not [string]::IsNullOrWhiteSpace($workingValidation.blockingReason)) {
        Add-BlockingReason -Reason $workingValidation.blockingReason
    }
    if (-not [string]::IsNullOrWhiteSpace($workingValidation.warning)) {
        Add-WarningMessage -Message $workingValidation.warning
    }
    if (-not [string]::IsNullOrWhiteSpace($workingValidation.strategyTrace)) {
        Add-StrategyTrace -Message $workingValidation.strategyTrace
    }

    $checks = @(
        (New-Check -Name 'GeneXus installation' -Result $geneXusResolution.result -Detail $geneXusResolution.detail),
        (New-Check -Name 'MSBuild host' -Result $msBuildResolution.result -Detail $msBuildResolution.detail),
        (New-Check -Name 'Genexus.Tasks.targets' -Result $targetsResolution.result -Detail $targetsResolution.detail),
        (New-Check -Name 'KbPath' -Result $kbValidation.result -Detail $kbValidation.detail),
        $workingValidation.check,
        $logValidation.check
    )

    $failureCodes = @(
        $geneXusResolution.code,
        $msBuildResolution.code,
        $targetsResolution.code,
        $workingValidation.code,
        $logValidation.code,
        $kbValidation.code
    ) | Where-Object { $_ -ne 0 }

    $exitCode = Get-PrimaryExitCode -Codes $failureCodes
    $status = if ($exitCode -eq 0) { 'apto para prosseguir' } else { 'não apto para prosseguir' }

    if ($exitCode -eq 0) {
        if ($workingValidation.autoCreated) {
            $summary = 'GeneXus, MSBuild e diretórios seguros validados; WorkingDirectory explícito ausente foi auto-criado com segurança.'
        } else {
            $summary = 'GeneXus, MSBuild e diretórios seguros validados.'
        }
    } else {
        $summary = 'Probe bloqueado por uma ou mais validações de ambiente.'
    }

    $diagnostic = [ordered]@{
        status = $status
        summary = $summary
        resolvedPaths = [ordered]@{
            GeneXusDir = $geneXusResolution.path
            MsBuildPath = $msBuildResolution.path
            KbPath = $kbValidation.path
            WorkingDirectory = $workingValidation.path
            LogPath = $logValidation.path
        }
        pathActions = [ordered]@{
            WorkingDirectory = $workingValidation.pathAction
        }
        checks = $checks
        blockingReasons = @($script:BlockingReasons)
        warnings = @($script:Warnings)
        strategyTrace = @($script:StrategyTrace)
    }

    $json = $diagnostic | ConvertTo-Json -Depth 6

    if ($logValidation.result -eq 'ok') {
        Write-LogFile -TargetLogPath $logValidation.path -JsonPayload $json
    }

    Write-Output $json
    exit $exitCode
}
catch {
    $failure = [ordered]@{
        status = 'não apto para prosseguir'
        summary = 'Falha interna do script antes de diagnóstico completo.'
        resolvedPaths = [ordered]@{
            GeneXusDir = $null
            MsBuildPath = $null
            KbPath = (Get-FullPathSafe -PathValue $KbPath)
            WorkingDirectory = (Get-FullPathSafe -PathValue $WorkingDirectory)
            LogPath = $resolvedLogPathForFallback
        }
        pathActions = [ordered]@{
            WorkingDirectory = 'blocked-internal-error'
        }
        checks = @()
        blockingReasons = @($_.Exception.Message)
        warnings = @()
        strategyTrace = @($script:StrategyTrace)
    }

    $failureJson = $failure | ConvertTo-Json -Depth 6

    try {
        if (-not [string]::IsNullOrWhiteSpace($resolvedLogPathForFallback)) {
            $parent = [System.IO.Path]::GetDirectoryName($resolvedLogPathForFallback)
            if (-not [string]::IsNullOrWhiteSpace($parent) -and (Test-Path -LiteralPath $parent -PathType Container) -and -not (Test-IsUnderProgramFilesX86 -PathValue $resolvedLogPathForFallback)) {
                Write-LogFile -TargetLogPath $resolvedLogPathForFallback -JsonPayload $failureJson
            }
        }
    }
    catch {
    }

    Write-Output $failureJson
    exit 90
}
