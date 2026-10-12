#requires -Version 7.4

<#
.SYNOPSIS
    Barragem estrutural (Categoria B) para wrappers MSBuild GeneXus.

.DESCRIPTION
    Categoria A (extras de inventario, módulos de plataforma, etc.) permanece com exitCode=0
    e decisão do agente (Decisão pos-gates). Categoria B (linhas error: no log MSBuild,
    invalidTypesRejected) rebaixa o exitCode classificado pelo wrapper para 48 quando a task
    MSBuild concluiu com sucesso aparente mas o log registra rejeicao objetiva.
#>

Set-StrictMode -Version Latest

# Fonte canonica numerica: scripts/msbuild-exit-codes.catalog.json
$script:GeneXusMsBuildCategoryBExitCode = 48

$script:ExportOperationalSubStateCategoryB = 'exportação parcial com errors do MSBuild — artefato não confiável'
$script:ImportOperationalSubStateCategoryB = 'importação com errors do MSBuild — alteração não confiável'
$script:PreviewOperationalSubStateCategoryB = 'preview com errors do MSBuild — diagnóstico não confiável'
$script:BuildOperationalSubStateCategoryB = 'build com errors do MSBuild — resultado não confiável'

function Test-GeneXusMsBuildCategoryBPresent {
    param(
        [string[]]$MsBuildErrors,
        [string[]]$InvalidTypesRejected
    )

    if (@($MsBuildErrors).Count -gt 0) {
        return $true
    }
    if (@($InvalidTypesRejected).Count -gt 0) {
        return $true
    }
    return $false
}

function Get-GeneXusMsBuildCategoryBBlockingReasons {
    param(
        [string[]]$MsBuildErrors,
        [string[]]$InvalidTypesRejected,
        [string]$StageLabel
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $label = if ([string]::IsNullOrWhiteSpace($StageLabel)) { 'MSBuild' } else { $StageLabel }

    if (@($InvalidTypesRejected).Count -gt 0) {
        [void]$reasons.Add(
            ('{0}: tipo(s) rejeitado(s) na lista ou no log ({1}).' -f $label, ($InvalidTypesRejected -join ', '))
        )
    }

    $errorLines = @($MsBuildErrors)
    $maxLines = 3
    for ($i = 0; $i -lt [Math]::Min($errorLines.Count, $maxLines); $i++) {
        [void]$reasons.Add(('{0}: linha error: no log — {1}' -f $label, $errorLines[$i]))
    }
    if ($errorLines.Count -gt $maxLines) {
        [void]$reasons.Add(
            ('{0}: mais {1} linha(s) com error: em msbuild.stdout.log / msbuild.stderr.log (ver array de errors no diagnostico).' -f $label, ($errorLines.Count - $maxLines))
        )
    }

    if ($reasons.Count -eq 0) {
        [void]$reasons.Add(('{0}: rejeicao Categoria B detectada sem detalhe serializado; consultar logs brutos.' -f $label))
    }

    return @($reasons)
}

function Get-GeneXusMsBuildCategoryBStatusSummary {
    param(
        [string]$OperationLabel,
        [bool]$ArtifactOnDisk,
        [string]$ArtifactKind
    )

    $artifactNote = if ($ArtifactOnDisk) {
        if ([string]::IsNullOrWhiteSpace($ArtifactKind)) {
            ' O artefato pode ter sido gravado no disco apenas para inspecao — nao tratar como entrega operacional limpa.'
        } else {
            " O $ArtifactKind pode ter sido gravado no disco apenas para inspecao — nao tratar como entrega operacional limpa."
        }
    } else {
        ''
    }

    return [ordered]@{
        Status  = 'falha operacional com rejeicao MSBuild no log'
        Summary = ("{0} concluiu com sucesso aparente da task MSBuild, mas o log contem linha(s) error: ou tipo(s) rejeitado(s) (Categoria B).{1}" -f $OperationLabel, $artifactNote)
    }
}

function Read-GeneXusMsBuildStageSignals {
    param(
        [string]$StdOutPath,
        [string]$StdErrPath,
        [string]$Stage,
        [string]$SignalsScriptPath,
        [string]$OutputPath,
        [string]$ExpectedItems
    )

    $empty = [pscustomobject]@{
        exportErrors         = @()
        importErrors         = @()
        buildErrors          = @()
        previewErrors        = @()
        invalidTypesRejected = @()
        knownStdOutNoise      = @()
        rawSignals           = $null
        signalsDegraded      = $false
        signalsDegradedReason = $null
    }

    if (-not (Test-Path -LiteralPath $SignalsScriptPath -PathType Leaf)) {
        $empty.signalsDegraded = $true
        $empty.signalsDegradedReason = "Read-MsBuildImportSignals.ps1 nao encontrado: $SignalsScriptPath"
        return $empty
    }

    try {
        $readerArgs = @{
            StdOutPath = $StdOutPath
            StdErrPath = $StdErrPath
            Stage      = $Stage
            AsJson     = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($ExpectedItems)) {
            $readerArgs['ExpectedItems'] = $ExpectedItems
        }
        if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
            $readerArgs['OutputPath'] = $OutputPath
        }

        $signalsJsonText = (& $SignalsScriptPath @readerArgs) | Out-String
        if ([string]::IsNullOrWhiteSpace($signalsJsonText)) {
            $empty.signalsDegraded = $true
            $empty.signalsDegradedReason = 'Read-MsBuildImportSignals.ps1 retornou JSON vazio.'
            return $empty
        }

        $signals = $signalsJsonText | ConvertFrom-Json
        $exportErrors = @()
        $importErrors = @()
        $invalidTypesRejected = @()
        $knownStdOutNoise = @()

        if ($Stage -eq 'export') {
            if ($null -ne $signals.PSObject.Properties['exportErrors']) {
                $exportErrors = @($signals.exportErrors)
            }
            if ($null -ne $signals.PSObject.Properties['invalidTypesRejected']) {
                $invalidTypesRejected = @($signals.invalidTypesRejected)
            }
        } else {
            if ($null -ne $signals.PSObject.Properties['errors']) {
                $importErrors = @($signals.errors)
            }
        }

        if ($null -ne $signals.PSObject.Properties['knownStdOutNoise']) {
            $knownStdOutNoise = @($signals.knownStdOutNoise)
        }

        $buildErrors = @()
        $previewErrors = @()
        if ($Stage -eq 'build-all') {
            $buildErrors = @($importErrors)
            $importErrors = @()
        } elseif ($Stage -eq 'import-preview') {
            $previewErrors = @($importErrors)
            $importErrors = @()
        }

        return [pscustomobject]@{
            exportErrors          = @($exportErrors)
            importErrors          = @($importErrors)
            buildErrors           = @($buildErrors)
            previewErrors         = @($previewErrors)
            invalidTypesRejected  = @($invalidTypesRejected)
            knownStdOutNoise      = @($knownStdOutNoise)
            rawSignals            = $signals
            signalsDegraded       = $false
            signalsDegradedReason = $null
        }
    }
    catch {
        $empty.signalsDegraded = $true
        $empty.signalsDegradedReason = $_.Exception.Message
        return $empty
    }
}

function Resolve-GeneXusMsBuildCategoryBExitCode {
    param(
        [int]$BaseExitCode,
        [int]$MsBuildExitCode,
        [string[]]$MsBuildErrors,
        [string[]]$InvalidTypesRejected
    )

    if ($BaseExitCode -ne 0) {
        return $BaseExitCode
    }
    if ($MsBuildExitCode -ne 0) {
        return $BaseExitCode
    }
    if (Test-GeneXusMsBuildCategoryBPresent -MsBuildErrors $MsBuildErrors -InvalidTypesRejected $InvalidTypesRejected) {
        return $script:GeneXusMsBuildCategoryBExitCode
    }
    return $BaseExitCode
}
