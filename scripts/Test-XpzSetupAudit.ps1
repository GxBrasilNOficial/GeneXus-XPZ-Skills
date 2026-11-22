#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbRoot,

    [Parameter(Mandatory = $true)]
    [string]$GateWrapperPath,

    [Parameter(Mandatory = $true)]
    [string]$MetadataWrapperTestPath,

    [string]$PowerShellRuntimeTestPath,

    [string]$NamingWrapperPath,

    [string]$SourceSanityWrapperPath,

    [string]$PackageCollisionWrapperPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Acumulador para o contrato estruturado opcional (-AsJson). O default textual
# (Emit-Line) permanece byte-identico; -AsJson emite os MESMOS pares como JSON,
# consumido pelo orquestrador da skill xpz-kb-parallel-pre-push (gates K8/K9).
$script:emitted = [ordered]@{}

function Invoke-WrapperText {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "BLOCK: wrapper ausente: $Path"
    }

    $output = & $Path 2>&1
    if (-not $?) {
        $text = (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw "BLOCK: wrapper falhou sem saida: $Path"
        }

        throw $text
    }

    return (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
}

function Get-MetadataField {
    param(
        [string[]]$Lines,
        [string]$FieldName
    )

    $pattern = '^\s*{0}\s*[:=]\s*(?<value>.+?)\s*$' -f [regex]::Escape($FieldName)
    foreach ($line in $Lines) {
        $match = [regex]::Match($line, $pattern)
        if ($match.Success) {
            return $match.Groups['value'].Value.Trim()
        }
    }

    return $null
}

function Normalize-Value {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $trimmed = $Value.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed -eq '(ausente)') {
        return $null
    }

    return $trimmed
}

function Emit-Line {
    param(
        [string]$Key,
        [string]$Value
    )

    # Chave repetida (ex.: 'wrappers/inventario' multi-parte) acumula como lista,
    # preservando todas as partes no JSON do contrato estruturado (-AsJson). Chave
    # unica permanece string.
    if ($script:emitted.Contains($Key)) {
        $existing = $script:emitted[$Key]
        if ($existing -is [System.Collections.Generic.List[string]]) {
            [void]$existing.Add([string]$Value)
        } else {
            $list = [System.Collections.Generic.List[string]]::new()
            [void]$list.Add([string]$existing)
            [void]$list.Add([string]$Value)
            $script:emitted[$Key] = $list
        }
    } else {
        $script:emitted[$Key] = $Value
    }
    if (-not $AsJson) {
        '{0}: {1}' -f $Key, $Value
    }
}

function Get-SuggestedPowerShellRuntimeWrapperPath {
    param([string]$RootPath)

    $fullRootPath = [System.IO.Path]::GetFullPath($RootPath)
    $kbName = Split-Path -Leaf $fullRootPath
    $safeName = $kbName -replace '[^A-Za-z0-9]', ''
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = 'Kb'
    }

    return (Join-Path (Join-Path $fullRootPath 'scripts') ('Test-{0}KbPowerShellRuntime.ps1' -f $safeName))
}

function Resolve-PowerShellRuntimeTestPath {
    param(
        [string]$RootPath,
        [string]$ExplicitPath
    )

    $suggestedPath = Get-SuggestedPowerShellRuntimeWrapperPath -RootPath $RootPath
    $examplePath = Join-Path (Split-Path -Parent $scriptDir) 'xpz-kb-parallel-setup\examples\Test-KbPowerShellRuntime.example.ps1'

    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return [ordered]@{
            path = $ExplicitPath
            source = 'explicit'
            suggestedPath = $suggestedPath
            examplePath = $examplePath
        }
    }

    $scriptsPath = Join-Path $RootPath 'scripts'
    $detected = @()
    if (Test-Path -LiteralPath $scriptsPath -PathType Container) {
        $detected = @(Get-ChildItem -LiteralPath $scriptsPath -File -Filter 'Test-*KbPowerShellRuntime.ps1' | Sort-Object Name)
    }

    if ($detected.Count -gt 0) {
        return [ordered]@{
            path = $detected[0].FullName
            source = if ($detected.Count -eq 1) { 'autodetected' } else { 'autodetected-first-of-many' }
            candidates = @($detected | ForEach-Object { $_.FullName })
            suggestedPath = $suggestedPath
            examplePath = $examplePath
        }
    }

    return [ordered]@{
        path = $null
        source = 'missing'
        candidates = @()
        suggestedPath = $suggestedPath
        examplePath = $examplePath
    }
}

$scriptDir = Split-Path -Parent $PSCommandPath

$powerShellRuntimeRaw = $null
$powerShellRuntimeStatus = $null
$powerShellRuntimeDetection = Resolve-PowerShellRuntimeTestPath -RootPath $KbRoot -ExplicitPath $PowerShellRuntimeTestPath
try {
    if (-not $powerShellRuntimeDetection['path']) {
        throw ("BLOCK: wrapper de runtime PowerShell nao informado nem detectado em scripts/Test-*KbPowerShellRuntime.ps1; criar wrapper local sugerido em {0} a partir de {1}" -f $powerShellRuntimeDetection['suggestedPath'], $powerShellRuntimeDetection['examplePath'])
    }
    $powerShellRuntimeRaw = Invoke-WrapperText -Path $powerShellRuntimeDetection['path']
    if ($powerShellRuntimeRaw -match '\bPOWERSHELL_RUNTIME_OK\b') {
        $powerShellRuntimeStatus = 'OK'
    } else {
        $powerShellRuntimeStatus = 'BLOCK'
    }
} catch {
    $powerShellRuntimeRaw = $_.Exception.Message.Trim()
    $powerShellRuntimeStatus = 'BLOCK'
}

if ($powerShellRuntimeStatus -ne 'OK') {
    Emit-Line -Key 'powershell/runtime' -Value $powerShellRuntimeStatus
    Emit-Line -Key 'powershell/runtime.evidencia' -Value $(if ($powerShellRuntimeRaw) { $powerShellRuntimeRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
    Emit-Line -Key 'powershell/runtime.detecao' -Value $powerShellRuntimeDetection['source']
    Emit-Line -Key 'powershell/runtime.wrapper_sugerido' -Value $powerShellRuntimeDetection['suggestedPath']
    Emit-Line -Key 'powershell/runtime.molde' -Value $powerShellRuntimeDetection['examplePath']
    Emit-Line -Key 'estado_operacional_sugerido' -Value 'runtime_powershell_bloqueado'
    if ($AsJson) { $script:emitted | ConvertTo-Json -Depth 5 }
    exit 1
}

# Safety-net do contrato "-AsJson nunca lanca" (simetrico ao Test-XpzKbIndexGate):
# qualquer throw daqui pra frente (metadata ausente, leitura, etc.) vira, sob
# -AsJson, JSON com estado bloqueante + error -- nunca um throw que o orquestrador
# interpretaria erradamente como "wrapper desatualizado".
try {

$metadataPath = Join-Path $KbRoot 'kb-source-metadata.md'
if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    throw "BLOCK: kb-source-metadata.md nao encontrado: $metadataPath"
}

$metadataLines = [System.IO.File]::ReadAllLines($metadataPath)
$lastMaterialization = Normalize-Value (Get-MetadataField -Lines $metadataLines -FieldName 'last_xpz_materialization_run_at')

$gateRaw = $null
$gateStatus = $null
$inventorySemanticStatus = $null
# WRITABILITY_COVERAGE_CONTRACT_V1: GATE_OK só é aceito junto com writability_coverage.
$writabilityCoverage = 'unknown'
$writabilityCoverageWarning = 'Gate de indice sem campo writability_coverage; nao afirmar cobertura de gravabilidade.'
$sourceMaskDegraded = 'unknown'
$sourceMaskDegradedWarning = 'Gate de indice sem source_mask_degraded valido (true|false); nao afirmar cobertura completa da mascara.'
try {
    $gateRaw = Invoke-WrapperText -Path $GateWrapperPath
    $coverageMatch = [regex]::Match($gateRaw, 'writability_coverage\s*[:=]\s*(?<value>\S+)')
    if ($coverageMatch.Success -and $coverageMatch.Groups['value'].Value -in @('complete-in-model', 'partial', 'invalid')) {
        $writabilityCoverage = $coverageMatch.Groups['value'].Value
        $warningMatch = [regex]::Match($gateRaw, 'writability_coverage_warning\s*[:=]\s*(?<value>.+)')
        if ($warningMatch.Success) { $writabilityCoverageWarning = $warningMatch.Groups['value'].Value.Trim() }
        else { $writabilityCoverageWarning = $null }
        $gateStatus = if ($gateRaw -match '\bGATE_OK\b') { 'OK' } else { 'PENDENTE' }
    } else {
        $gateStatus = 'PENDENTE'
    }
} catch {
    $gateRaw = $_.Exception.Message.Trim()
    $gateStatus = 'BLOCK'
}

$sourceMaskContractValid = $false
$maskDegradedMatch = if ($gateRaw) {
    [regex]::Match($gateRaw, '(?m)^[ \t]*source_mask_degraded[ \t]*[:=][ \t]*(?<value>true|false)[ \t]*\r?$')
} else {
    [regex]::Match('', 'a^')
}
if ($maskDegradedMatch.Success) {
    $sourceMaskDegraded = $maskDegradedMatch.Groups['value'].Value
    $maskWarningMatch = [regex]::Match($gateRaw, '(?m)^[ \t]*source_mask_degraded_warning[ \t]*[:=][ \t]*(?<value>.+?)[ \t]*\r?$')
    $maskWarning = if ($maskWarningMatch.Success) { $maskWarningMatch.Groups['value'].Value.Trim() } else { '' }
    if ($sourceMaskDegraded -eq 'true') {
        if (-not [string]::IsNullOrWhiteSpace($maskWarning)) {
            $sourceMaskDegradedWarning = $maskWarning
            $sourceMaskContractValid = $true
        } else {
            $sourceMaskDegraded = 'unknown'
            $sourceMaskDegradedWarning = 'Gate de indice com source_mask_degraded=true sem source_mask_degraded_warning; contrato incompleto.'
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($maskWarning)) {
        $sourceMaskDegraded = 'unknown'
        $sourceMaskDegradedWarning = 'Gate de indice com source_mask_degraded=false e aviso de mascara; estado inconsistente.'
    } else {
        $sourceMaskDegradedWarning = $null
        $sourceMaskContractValid = $true
    }
}
if ($gateStatus -eq 'OK' -and -not $sourceMaskContractValid) {
    $gateStatus = 'PENDENTE'
}

$inventorySemanticMatch = if ($gateRaw) {
    [regex]::Match($gateRaw, 'inventory_validation_status\s*[:=]\s*(?<value>\S+)')
} else {
    [regex]::Match('', 'a^')
}
if ($inventorySemanticMatch.Success) {
    $inventorySemanticStatus = $inventorySemanticMatch.Groups['value'].Value.Trim()
} elseif ($gateStatus -eq 'BLOCK' -and $gateRaw -match 'inventario semantico|inventory_validation_status') {
    $inventorySemanticStatus = 'BLOCK'
} else {
    $inventorySemanticStatus = 'PENDENTE'
}

$metadataWrapperRaw = $null
$metadataWrapperStatus = $null
try {
    $metadataWrapperRaw = Invoke-WrapperText -Path $MetadataWrapperTestPath
    if ($metadataWrapperRaw -match '\bMETADATA_WRAPPER_OK\b') {
        $metadataWrapperStatus = 'OK'
    } elseif ($metadataWrapperRaw -match '\bPENDENTE_DE_DADOS\b') {
        $metadataWrapperStatus = 'PENDENTE_DE_DADOS'
    } else {
        $metadataWrapperStatus = 'PENDENTE'
    }
} catch {
    $metadataWrapperRaw = $_.Exception.Message.Trim()
    if ($metadataWrapperRaw -match '\bPENDENTE_DE_DADOS\b') {
        $metadataWrapperStatus = 'PENDENTE_DE_DADOS'
    } else {
        $metadataWrapperStatus = 'BLOCK'
    }
}

$deploymentMetadataRaw = $null
$deploymentMetadataStatus = $null
$deploymentMetadataScriptPath = Join-Path $scriptDir 'Test-XpzKbDeploymentMetadata.ps1'
if (Test-Path -LiteralPath $deploymentMetadataScriptPath -PathType Leaf) {
    try {
        $deploymentMetadataRaw = (& $deploymentMetadataScriptPath -MetadataPath $metadataPath 2>&1 |
            ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        if ($deploymentMetadataRaw -match '\bDEPLOYMENT_METADATA_PLAUSIBILITY_OK\b') {
            $deploymentMetadataStatus = 'OK'
        } elseif ($deploymentMetadataRaw -match '\bDEPLOYMENT_METADATA_PENDENTE\b') {
            $deploymentMetadataStatus = 'PENDENTE'
        } else {
            $deploymentMetadataStatus = 'BLOCK'
        }
    } catch {
        $deploymentMetadataRaw = $_.Exception.Message.Trim()
        if ($deploymentMetadataRaw -match '\bPENDENTE:') {
            $deploymentMetadataStatus = 'PENDENTE'
        } else {
            $deploymentMetadataStatus = 'BLOCK'
        }
    }
} else {
    $deploymentMetadataRaw = 'Test-XpzKbDeploymentMetadata.ps1 ausente no motor compartilhado'
    $deploymentMetadataStatus = 'PENDENTE'
}

$syncStatus = if ($lastMaterialization) { 'OK' } else { 'PENDENTE' }
$syncEvidence = if ($lastMaterialization) {
    "last_xpz_materialization_run_at=$lastMaterialization"
} else {
    'last_xpz_materialization_run_at ausente'
}

$namingRaw = $null
$namingStatus = 'INDETERMINADO'
if ($lastMaterialization) {
    try {
        if (-not $NamingWrapperPath) {
            $defaultNamingScriptPath = Join-Path $scriptDir 'Test-XpzObjetosDaKbNaming.ps1'
            if (Test-Path -LiteralPath $defaultNamingScriptPath -PathType Leaf) {
                $namingOutput = & $defaultNamingScriptPath -ParallelKbRoot $KbRoot -AsJson 2>&1
            } else {
                throw "BLOCK: wrapper de naming nao informado"
            }
        } else {
            $namingOutput = & $NamingWrapperPath -AsJson 2>&1
        }

        $namingExitCode = $LASTEXITCODE
        $namingRaw = (($namingOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine).Trim()
        $namingData = $namingRaw | ConvertFrom-Json
        $indetermined = @($namingData.all | Where-Object { $_.StatusNaming -in @('INDETERMINADO', 'TIPO_DESCONHECIDO') })
        if ($namingData.status -eq 'NAMING_DIVERGENT' -or $namingExitCode -eq 1) {
            $namingStatus = 'DIVERGENT'
        } elseif ($namingData.status -eq 'NAMING_INDETERMINADO' -or $indetermined.Count -gt 0) {
            $namingStatus = 'INDETERMINADO'
        } elseif ($namingData.status -eq 'NAMING_OK' -and $namingExitCode -eq 0) {
            $namingStatus = 'OK'
        } else {
            $namingStatus = 'INDETERMINADO'
        }
        $divergentList = @($namingData.divergent) -join ','
        $namingRaw = "status=$($namingData.status); divergent=$divergentList; total=$(@($namingData.all).Count)"
    } catch {
        $namingRaw = $_.Exception.Message.Trim()
        $namingStatus = 'INDETERMINADO'
    }
} else {
    $namingRaw = 'last_xpz_materialization_run_at ausente; naming nao auditado'
}

$packagesDir = Join-Path $KbRoot 'PacotesGeradosParaImportacaoNaKbNoGenexus'
$packageDirExists = Test-Path -LiteralPath $packagesDir -PathType Container
$hasSourceSanityWrapper = $SourceSanityWrapperPath -and (Test-Path -LiteralPath $SourceSanityWrapperPath -PathType Leaf)
$hasPackageCollisionWrapper = $PackageCollisionWrapperPath -and (Test-Path -LiteralPath $PackageCollisionWrapperPath -PathType Leaf)

if ($packageDirExists -or $hasSourceSanityWrapper -or $hasPackageCollisionWrapper) {
    if ($hasSourceSanityWrapper -and $hasPackageCollisionWrapper) {
        $packageAuditStatus = 'OK'
    } else {
        $packageAuditStatus = 'PENDENTE'
    }
} else {
    $packageAuditStatus = 'NAO_ADOTADO'
}

$packageEvidenceParts = @()
$packageEvidenceParts += ('packages_dir={0}' -f $(if ($packageDirExists) { 'presente' } else { 'ausente' }))
$packageEvidenceParts += ('source_sanity_wrapper={0}' -f $(if ($hasSourceSanityWrapper) { 'presente' } else { 'ausente' }))
$packageEvidenceParts += ('package_collision_wrapper={0}' -f $(if ($hasPackageCollisionWrapper) { 'presente' } else { 'ausente' }))
$packageEvidence = $packageEvidenceParts -join '; '

$declarativeFiles = @('AGENTS.md', 'README.md') | ForEach-Object { Join-Path $KbRoot $_ }
$declarativeDriftEntries = @()
$declarativeIgnoreCase = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
$declarativeDriftPattern = [regex]::new('\blast_(xpz_materialization|index_build)_run_at\b[^\r\n]*?[:=][^\r\n]*?\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}', $declarativeIgnoreCase)
foreach ($declarativePath in $declarativeFiles) {
    if (-not (Test-Path -LiteralPath $declarativePath -PathType Leaf)) { continue }
    $declarativeText = [System.IO.File]::ReadAllText($declarativePath)
    $driftMatches = $declarativeDriftPattern.Matches($declarativeText)
    if ($driftMatches.Count -gt 0) {
        $driftFields = @($driftMatches | ForEach-Object { (@($_.Value -split '[:=]', 2))[0].Trim().Trim('`').Trim() } | Sort-Object -Unique)
        $declarativeDriftEntries += ('{0}:{1}' -f (Split-Path -Leaf $declarativePath), ($driftFields -join ','))
    }
}
if ($declarativeDriftEntries.Count -gt 0) {
    $declarativeStatus = 'DRIFT_TIMESTAMPS_LITERAIS'
    $declarativeEvidence = $declarativeDriftEntries -join '; '
    $declarativeRecommendedAction = 'remover timestamps literais de AGENTS.md/README.md e substituir por ponteiros as fontes autoritativas; nao atualizar os valores literais'
} else {
    $declarativeStatus = 'OK'
    $declarativeEvidence = 'sem timestamps literais de last_xpz_materialization_run_at ou last_index_build_run_at em AGENTS.md/README.md locais'
    $declarativeRecommendedAction = $null
}
$hasDeclarativeDrift = $declarativeStatus -ne 'OK'

# Registro de eventos pos-build (dimensao pos-build/registro). Evidencia: para cada environment, o JSON
# de build mais recente em Temp\ cujo stdoutSignals.postBuildEvents tenha eventos nao inertes. Sem
# registro (noEntryForEnvironment) o environment fica PENDENTE; sem nenhum JSON de build com eventos o
# resultado e SEM_EVIDENCIA (informativo, nao pendencia nem limpo). Reusa os motores de classificacao
# e de estado de registro (mesmos de Register-GeneXusKbPostBuildEvents.ps1 e dos wrappers de build).
. (Join-Path $scriptDir 'GeneXusMsBuildPostBuildEventsSupport.ps1')
. (Join-Path $scriptDir 'GeneXusKbDeploymentEnvironmentSupport.ps1')
$postBuildRegistryStatus = 'SEM_EVIDENCIA'
$postBuildRegistryEvidence = 'sem registro, espelho ou JSON de build com eventos pos-build em Temp\ (rodar um build para evidenciar)'
$postBuildMetadataPath = Join-Path $KbRoot 'kb-source-metadata.md'
$postBuildTempRoot = Join-Path $KbRoot 'Temp'
$postBuildLatestByEnv = @{}
if (Test-Path -LiteralPath $postBuildTempRoot -PathType Container) {
    $postBuildJsonFiles = @(Get-ChildItem -LiteralPath $postBuildTempRoot -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending)
    foreach ($postBuildJsonFile in $postBuildJsonFiles) {
        try {
            $postBuildDoc = (Get-Content -LiteralPath $postBuildJsonFile.FullName -Raw) | ConvertFrom-Json -ErrorAction Stop
        } catch {
            continue
        }
        if ($null -eq $postBuildDoc.PSObject.Properties['stdoutSignals'] -or $null -eq $postBuildDoc.stdoutSignals) { continue }
        if ($null -eq $postBuildDoc.stdoutSignals.PSObject.Properties['postBuildEvents']) { continue }
        if ($null -eq $postBuildDoc.PSObject.Properties['observedContext'] -or $null -eq $postBuildDoc.observedContext) { continue }
        if ($null -eq $postBuildDoc.observedContext.PSObject.Properties['ActiveEnvironment']) { continue }
        $postBuildEnvName = [string]$postBuildDoc.observedContext.ActiveEnvironment
        if ([string]::IsNullOrWhiteSpace($postBuildEnvName)) { continue }
        $postBuildEnvName = $postBuildEnvName.Trim()
        if ($postBuildLatestByEnv.ContainsKey($postBuildEnvName)) { continue }
        $postBuildExecutable = @(@($postBuildDoc.stdoutSignals.postBuildEvents) | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_) -and -not (Test-GeneXusPostBuildEventInert -Line $_)
        })
        if ($postBuildExecutable.Count -eq 0) { continue }
        # Dados do build que decidem se ele serve de base do registro (dimensao pos-build/base).
        $postBuildExitCode = $null
        if ($null -ne $postBuildDoc.PSObject.Properties['exitCode']) { $postBuildExitCode = $postBuildDoc.exitCode }
        $postBuildMsBuildExit = $null
        $postBuildMsBuildFailed = $null
        if ($null -ne $postBuildDoc.PSObject.Properties['executionEvidence'] -and $null -ne $postBuildDoc.executionEvidence) {
            if ($null -ne $postBuildDoc.executionEvidence.PSObject.Properties['msBuildExitCode']) { $postBuildMsBuildExit = $postBuildDoc.executionEvidence.msBuildExitCode }
            if ($null -ne $postBuildDoc.executionEvidence.PSObject.Properties['msBuildFailed']) { $postBuildMsBuildFailed = $postBuildDoc.executionEvidence.msBuildFailed }
        }
        $postBuildStatusText = ''
        if ($null -ne $postBuildDoc.PSObject.Properties['status'] -and $null -ne $postBuildDoc.status) { $postBuildStatusText = [string]$postBuildDoc.status }
        $postBuildRegistryState = $null
        $postBuildUnexpectedCount = 0
        if ($null -ne $postBuildDoc.stdoutSignals.PSObject.Properties['postBuildEventClassification'] -and $null -ne $postBuildDoc.stdoutSignals.postBuildEventClassification) {
            $postBuildClassification = $postBuildDoc.stdoutSignals.postBuildEventClassification
            if ($null -ne $postBuildClassification.PSObject.Properties['registryStatus'] -and $null -ne $postBuildClassification.registryStatus -and
                $null -ne $postBuildClassification.registryStatus.PSObject.Properties['state']) {
                $postBuildRegistryState = [string]$postBuildClassification.registryStatus.state
            }
            if ($null -ne $postBuildClassification.PSObject.Properties['unexpected'] -and $null -ne $postBuildClassification.unexpected) {
                $postBuildUnexpectedCount = @($postBuildClassification.unexpected).Count
            }
        }
        $postBuildLatestByEnv[$postBuildEnvName] = [pscustomobject]@{
            file            = $postBuildJsonFile.FullName
            count           = $postBuildExecutable.Count
            lines           = @($postBuildExecutable | ForEach-Object { $_.Trim() })
            exitCode        = $postBuildExitCode
            msBuildExitCode = $postBuildMsBuildExit
            msBuildFailed   = $postBuildMsBuildFailed
            statusText      = $postBuildStatusText
            registryState   = $postBuildRegistryState
            unexpectedCount = $postBuildUnexpectedCount
        }
    }
}
# Espelho legivel "## Eventos pos-build registrados" (subsecao "### env: X", linhas "- `evento`").
# Auditoria humana, mas a auditoria usa para checar forma (familia x legada) e divergencia com o campo,
# inclusive sem build. Ausencia da secao = sem espelho (nao e divergencia).
$postBuildMirror = @{}
$postBuildMirrorPresent = $false
if (Test-Path -LiteralPath $postBuildMetadataPath -PathType Leaf) {
    $postBuildMirrorEnv = $null
    $postBuildInMirror = $false
    foreach ($postBuildMetaLine in @(Get-Content -LiteralPath $postBuildMetadataPath)) {
        $postBuildTrim = $postBuildMetaLine.Trim()
        if ($postBuildTrim -eq '## Eventos pos-build registrados') {
            $postBuildInMirror = $true
            $postBuildMirrorPresent = $true
            $postBuildMirrorEnv = $null
            continue
        }
        if ($postBuildInMirror -and $postBuildTrim -match '^##\s') { $postBuildInMirror = $false; $postBuildMirrorEnv = $null; continue }
        if (-not $postBuildInMirror) { continue }
        if ($postBuildTrim -match '^###\s+env:\s*(.+)$') {
            $postBuildMirrorEnv = $Matches[1].Trim()
            if (-not $postBuildMirror.ContainsKey($postBuildMirrorEnv)) { $postBuildMirror[$postBuildMirrorEnv] = @() }
            continue
        }
        if ($null -ne $postBuildMirrorEnv -and $postBuildTrim -match '^-\s+`(.+)`$') {
            $postBuildMirror[$postBuildMirrorEnv] += $Matches[1]
        }
    }
}

# Campo kb_environment_post_build_event_hashes (autoridade para o build) e uniao de environments.
$postBuildFieldMap = $null
if (Test-Path -LiteralPath $postBuildMetadataPath -PathType Leaf) {
    $postBuildFieldMap = (Read-GeneXusKbDeploymentMetadataFields -MetadataPath $postBuildMetadataPath).kb_environment_post_build_event_hashes
}
$postBuildEnvs = @{}
foreach ($postBuildKey in $postBuildLatestByEnv.Keys) { $postBuildEnvs[$postBuildKey] = $true }
foreach ($postBuildKey in $postBuildMirror.Keys) { $postBuildEnvs[$postBuildKey] = $true }
if ($null -ne $postBuildFieldMap) {
    foreach ($postBuildKey in $postBuildFieldMap.Keys) { $postBuildEnvs[$postBuildKey] = $true }
}

if ($postBuildEnvs.Count -gt 0) {
    $postBuildParts = @()
    $postBuildPendingEnvs = @()
    $postBuildUnknownEnvs = @()
    foreach ($postBuildEnvKey in @($postBuildEnvs.Keys | Sort-Object)) {
        $postBuildRegistry = Get-GeneXusPostBuildEventRegistryState -MetadataPath $postBuildMetadataPath -EnvironmentName $postBuildEnvKey
        # Hashes registrados no campo (forma de familia ou legada), comparados sem diferenciar caixa.
        $postBuildRegisteredSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($postBuildRegisteredHash in @($postBuildRegistry.hashes)) {
            if (-not [string]::IsNullOrWhiteSpace($postBuildRegisteredHash)) { [void]$postBuildRegisteredSet.Add($postBuildRegisteredHash.Trim()) }
        }
        $postBuildReasons = @()
        $postBuildPending = $false
        $postBuildHasBuild = $postBuildLatestByEnv.ContainsKey($postBuildEnvKey)
        $postBuildAction = 'regravar com Register-*KbPostBuildEvents.ps1'

        # 1) Pareamento espelho x campo, sem build. Cada linha do espelho casa com um hash do campo na forma
        #    de familia ou na legada. Linha sem par ou hash do campo sem linha = divergencia (sempre PENDENTE,
        #    regravar). Par obtido so pela forma legada = forma legada (PENDENTE, regravar).
        $postBuildMirrorLines = @()
        if ($postBuildMirror.ContainsKey($postBuildEnvKey)) { $postBuildMirrorLines = @($postBuildMirror[$postBuildEnvKey]) }
        $postBuildLegacyForm = 0
        if ($postBuildMirrorPresent) {
            $postBuildMatched = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $postBuildUnpaired = 0
            foreach ($postBuildMirrorLine in $postBuildMirrorLines) {
                $postBuildFamilyHash = Get-GeneXusPostBuildEventFamilyHash -Line $postBuildMirrorLine
                if ($postBuildRegisteredSet.Contains($postBuildFamilyHash)) {
                    [void]$postBuildMatched.Add($postBuildFamilyHash)
                    continue
                }
                $postBuildLegacyHash = Get-GeneXusPostBuildEventNormalizedHash -Line $postBuildMirrorLine
                if ($postBuildRegisteredSet.Contains($postBuildLegacyHash)) {
                    [void]$postBuildMatched.Add($postBuildLegacyHash)
                    $postBuildLegacyForm++
                    continue
                }
                $postBuildUnpaired++
            }
            if ($postBuildUnpaired -gt 0 -or $postBuildMatched.Count -ne $postBuildRegisteredSet.Count) {
                $postBuildReasons += "espelho divergente do campo ($postBuildAction)"
                $postBuildPending = $true
            } elseif ($postBuildLegacyForm -gt 0) {
                $postBuildReasons += "forma legada=$postBuildLegacyForm ($postBuildAction)"
                $postBuildPending = $true
            }
        }

        # 3) Cobertura pelo build mais recente com eventos (quando existir).
        if ($postBuildHasBuild) {
            $postBuildEntry = $postBuildLatestByEnv[$postBuildEnvKey]
            if ($postBuildRegistry.state -ne 'available') {
                $postBuildReasons += "sem registro (build $(Split-Path -Leaf (Split-Path -Parent $postBuildEntry.file)); $postBuildAction)"
                $postBuildPending = $true
            } else {
                $postBuildUnregistered = 0
                $postBuildLegacyOnly = 0
                foreach ($postBuildLine in @($postBuildEntry.lines)) {
                    if ($postBuildRegisteredSet.Contains((Get-GeneXusPostBuildEventFamilyHash -Line $postBuildLine))) { continue }
                    if ($postBuildRegisteredSet.Contains((Get-GeneXusPostBuildEventNormalizedHash -Line $postBuildLine))) {
                        $postBuildLegacyOnly++
                    } else {
                        $postBuildUnregistered++
                    }
                }
                if ($postBuildUnregistered -gt 0) {
                    $postBuildReasons += "sem registro=$postBuildUnregistered (build $(Split-Path -Leaf (Split-Path -Parent $postBuildEntry.file)); $postBuildAction)"
                    $postBuildPending = $true
                }
                if ($postBuildLegacyOnly -gt 0) {
                    $postBuildReasons += "so na forma legada=$postBuildLegacyOnly (build $(Split-Path -Leaf (Split-Path -Parent $postBuildEntry.file)); $postBuildAction)"
                    $postBuildPending = $true
                }
            }
        }

        if ($postBuildPending) {
            $postBuildPendingEnvs += $postBuildEnvKey
        } elseif ($postBuildHasBuild) {
            $postBuildReasons += 'registro coerente com o build'
        } elseif ($postBuildMirrorLines.Count -gt 0) {
            $postBuildReasons += 'registro de familia coerente com o espelho; sem build para conferir cobertura'
            $postBuildUnknownEnvs += $postBuildEnvKey
        } else {
            $postBuildReasons += 'sem espelho e sem build: forma do registro nao confirmada'
            $postBuildUnknownEnvs += $postBuildEnvKey
        }
        $postBuildParts += ('{0}: {1}' -f $postBuildEnvKey, ($postBuildReasons -join '; '))
    }
    $postBuildRegistryEvidence = $postBuildParts -join ' | '
    $postBuildRegistryStatus = if ($postBuildPendingEnvs.Count -gt 0) {
        'PENDENTE'
    } elseif ($postBuildUnknownEnvs.Count -gt 0) {
        'SEM_EVIDENCIA'
    } else {
        'OK'
    }
}
$hasPostBuildRegistryPendencies = $postBuildRegistryStatus -eq 'PENDENTE'

# Base do registro (dimensao pos-build/base): informa, por environment, se o build mais recente com eventos
# serve de base para registrar. Informativa: nao altera o estado sugerido. Evita que o agente tenha de
# interpretar o JSON de build: um build nao apto exige build novo antes de qualquer registro.
function Get-PostBuildBaseVerdict {
    param([Parameter(Mandatory = $true)]$Entry)

    if ($null -eq $Entry.exitCode -or "$($Entry.exitCode)" -ne '0') {
        return [pscustomobject]@{ ok = $false; reason = 'exitCode ausente ou diferente de 0' }
    }
    if ($null -eq $Entry.msBuildExitCode -or "$($Entry.msBuildExitCode)" -ne '0') {
        return [pscustomobject]@{ ok = $false; reason = 'executionEvidence.msBuildExitCode ausente ou diferente de 0' }
    }
    if ($null -ne $Entry.msBuildFailed -and [bool]$Entry.msBuildFailed) {
        return [pscustomobject]@{ ok = $false; reason = 'executionEvidence.msBuildFailed verdadeiro' }
    }
    if ($Entry.statusText -match 'compilou limpo') {
        return [pscustomobject]@{ ok = $true; reason = 'status compilou limpo' }
    }
    if ($Entry.statusText -match 'pendente de confirma') {
        if ($null -eq $Entry.registryState) {
            return [pscustomobject]@{ ok = $false; reason = 'sem registryStatus no diagnostico (build anterior ao diagnostico de registro)' }
        }
        if ($Entry.registryState -ne 'noEntryForEnvironment') {
            return [pscustomobject]@{ ok = $false; reason = "registryStatus=$($Entry.registryState), a pendencia nao e so registro ausente" }
        }
        if ([int]$Entry.unexpectedCount -gt 0) {
            return [pscustomobject]@{ ok = $false; reason = "ha $($Entry.unexpectedCount) evento(s) inesperado(s), a pendencia nao e so registro ausente" }
        }
        return [pscustomobject]@{ ok = $true; reason = 'pendente apenas por registro ausente' }
    }
    return [pscustomobject]@{ ok = $false; reason = "status nao previsto: $($Entry.statusText)" }
}

$postBuildBaseStatus = 'SEM_EVIDENCIA'
$postBuildBaseEvidence = 'sem JSON de build com eventos pos-build em Temp\ (rodar um build para evidenciar)'
if ($postBuildLatestByEnv.Count -gt 0) {
    $postBuildBaseParts = @()
    $postBuildBaseRejected = 0
    foreach ($postBuildBaseEnv in @($postBuildLatestByEnv.Keys | Sort-Object)) {
        $postBuildBaseEntry = $postBuildLatestByEnv[$postBuildBaseEnv]
        $postBuildBaseVerdict = Get-PostBuildBaseVerdict -Entry $postBuildBaseEntry
        $postBuildBaseFile = Split-Path -Leaf (Split-Path -Parent $postBuildBaseEntry.file)
        if ($postBuildBaseVerdict.ok) {
            $postBuildBaseParts += ('{0}: apto ({1}; build {2})' -f $postBuildBaseEnv, $postBuildBaseVerdict.reason, $postBuildBaseFile)
        } else {
            $postBuildBaseRejected++
            $postBuildBaseParts += ('{0}: nao apto ({1}; build {2}); gerar build novo antes de registrar' -f $postBuildBaseEnv, $postBuildBaseVerdict.reason, $postBuildBaseFile)
        }
    }
    $postBuildBaseEvidence = $postBuildBaseParts -join ' | '
    $postBuildBaseStatus = if ($postBuildBaseRejected -gt 0) { 'NAO_APTO' } else { 'APTO' }
}

$inventoryScriptPath = Join-Path $scriptDir 'Test-XpzWrapperInventory.ps1'
$examplesPath = Join-Path (Split-Path -Parent $scriptDir) 'xpz-kb-parallel-setup\examples'
$inventoryStatus = 'INVENTORY_UNKNOWN'
if (Test-Path -LiteralPath $inventoryScriptPath -PathType Leaf) {
    try {
        $inventoryOutput = (& $inventoryScriptPath -KbParallelRoot $KbRoot -SkillsExamplesPath $examplesPath 2>&1 |
            ForEach-Object { $_.ToString() }) -join ' '
        $inventoryStatus = $inventoryOutput.Trim()
    } catch {
        $inventoryStatus = "INVENTORY_UNKNOWN: $($_.Exception.Message.Trim())"
    }
} else {
    $inventoryStatus = 'INVENTORY_UNKNOWN: motor Test-XpzWrapperInventory.ps1 ausente'
}

# Regex de pendencia metodologica do inventario: SO estes 4 tokens bloqueiam o estado de setup.
# Deliberadamente FORA daqui (por construcao, nao por acaso): INVENTORY_ENGINE_DIAGNOSTIC (infra do
# repo de skills), INVENTORY_SURFACE_ADVISORY (reducao opcional/ValidateSet do diff de superficie) e
# INVENTORY_HELP_ADVISORY (comment-based help: ajuda invisivel, .PARAMETER orfao, flag desconhecida
# em script simple) — todos sao avisos consultivos que NAO bloqueiam. A perda de contrato obrigatorio
# do diff de superficie e a flag orfa no .EXAMPLE de script advanced ja chegam aqui via
# INVENTORY_CUSTOMIZED (reasons surface_mismatch / help_example_undeclared_param). NAO adicionar os
# rotulos de aviso a este regex (guarda-regressao: Test-XpzWrapperInventorySelfTest.ps1).
$hasInventoryMethodologyPendencies = $inventoryStatus -match '\b(INVENTORY_GAPS|INVENTORY_SHORT_NAMING|INVENTORY_CUSTOMIZED|INVENTORY_LEGACY_ORPHANS)\b'
$hasMetadataWrapperPendencies = $metadataWrapperStatus -ne 'OK'
$hasDeploymentMetadataPendencies = $deploymentMetadataStatus -in @('BLOCK', 'PENDENTE')

$suggestedState = switch ($true) {
    ($powerShellRuntimeStatus -ne 'OK') { 'runtime_powershell_bloqueado'; break }
    ($syncStatus -eq 'PENDENTE') { 'pronto_para_primeira_materializacao'; break }
    ($namingStatus -eq 'DIVERGENT') { 'naming_objetos_da_kb_pendente'; break }
    ($hasMetadataWrapperPendencies) { 'atualizacao_metodologica_pendente'; break }
    ($hasDeploymentMetadataPendencies) { 'atualizacao_metodologica_pendente'; break }
    ($hasPostBuildRegistryPendencies) { 'atualizacao_metodologica_pendente'; break }
    ($hasInventoryMethodologyPendencies) { 'atualizacao_metodologica_pendente'; break }
    ($hasDeclarativeDrift) { 'atualizacao_metodologica_pendente'; break }
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $inventorySemanticStatus -eq 'OK' -and $packageAuditStatus -eq 'OK') { 'materializado_e_indice_validado'; break }
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $inventorySemanticStatus -eq 'OK' -and $packageAuditStatus -eq 'NAO_ADOTADO') { 'materializado_e_indice_validado'; break }
    ($syncStatus -eq 'OK' -and $gateStatus -eq 'OK' -and $inventorySemanticStatus -eq 'OK' -and $packageAuditStatus -eq 'PENDENTE') { 'auditoria_de_empacotamento_pendente'; break }
    default { 'wrappers_atualizados' }
}

Emit-Line -Key 'powershell/runtime' -Value $powerShellRuntimeStatus
Emit-Line -Key 'powershell/runtime.evidencia' -Value $(if ($powerShellRuntimeRaw) { $powerShellRuntimeRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'powershell/runtime.detecao' -Value $powerShellRuntimeDetection['source']
Emit-Line -Key 'sync/materializacao' -Value $syncStatus
Emit-Line -Key 'sync/materializacao.evidencia' -Value $syncEvidence
Emit-Line -Key 'naming/objetos-da-kb' -Value $namingStatus
Emit-Line -Key 'naming/objetos-da-kb.evidencia' -Value $(if ($namingRaw) { $namingRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'indice/gate' -Value $gateStatus
Emit-Line -Key 'indice/gate.evidencia' -Value $(if ($gateRaw) { $gateRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'indice/gravabilidade.cobertura' -Value $writabilityCoverage
if (-not [string]::IsNullOrWhiteSpace($writabilityCoverageWarning)) {
    Emit-Line -Key 'indice/gravabilidade.aviso' -Value $writabilityCoverageWarning
}
Emit-Line -Key 'indice/mascara' -Value $sourceMaskDegraded
if (-not [string]::IsNullOrWhiteSpace($sourceMaskDegradedWarning)) {
    Emit-Line -Key 'indice/mascara.aviso' -Value $sourceMaskDegradedWarning
}
Emit-Line -Key 'indice/semantica' -Value $inventorySemanticStatus
Emit-Line -Key 'indice/semantica.evidencia' -Value $(if ($gateRaw) { $gateRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'metadata wrapper' -Value $metadataWrapperStatus
Emit-Line -Key 'metadata wrapper.evidencia' -Value $(if ($metadataWrapperRaw) { $metadataWrapperRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'metadata/deploy' -Value $deploymentMetadataStatus
Emit-Line -Key 'metadata/deploy.evidencia' -Value $(if ($deploymentMetadataRaw) { $deploymentMetadataRaw.Replace([Environment]::NewLine, ' | ') } else { '(sem saida)' })
Emit-Line -Key 'pos-build/registro' -Value $postBuildRegistryStatus
Emit-Line -Key 'pos-build/registro.evidencia' -Value $postBuildRegistryEvidence
Emit-Line -Key 'pos-build/base' -Value $postBuildBaseStatus
Emit-Line -Key 'pos-build/base.evidencia' -Value $postBuildBaseEvidence
Emit-Line -Key 'empacotamento local' -Value $packageAuditStatus
Emit-Line -Key 'empacotamento local.evidencia' -Value $packageEvidence
Emit-Line -Key 'declarativo/timestamps' -Value $declarativeStatus
Emit-Line -Key 'declarativo/timestamps.evidencia' -Value $declarativeEvidence
if (-not [string]::IsNullOrWhiteSpace($declarativeRecommendedAction)) {
    Emit-Line -Key 'declarativo/timestamps.acao_recomendada' -Value $declarativeRecommendedAction
}
if ($inventoryStatus -match '\|') {
    foreach ($inventoryPart in @($inventoryStatus -split '\|')) {
        $trimmedInventoryPart = $inventoryPart.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmedInventoryPart)) {
            Emit-Line -Key 'wrappers/inventario' -Value $trimmedInventoryPart
        }
    }
} else {
    Emit-Line -Key 'wrappers/inventario' -Value $inventoryStatus
}
Emit-Line -Key 'estado_operacional_sugerido' -Value $suggestedState

if ($AsJson) { $script:emitted | ConvertTo-Json -Depth 5 }

} catch {
    # Excecao fora dos try/catch internos (ex.: kb-source-metadata.md ausente).
    # Sob -AsJson honra o contrato: estado bloqueante (auditoria_incompleta) +
    # error, nunca throw. Em texto re-lanca (default retrocompativel).
    if ($AsJson) {
        if (-not $script:emitted.Contains('estado_operacional_sugerido')) {
            $script:emitted['estado_operacional_sugerido'] = 'auditoria_incompleta'
        }
        $script:emitted['error'] = ($_.Exception.Message -replace '^BLOCK:\s*', '')
        $script:emitted | ConvertTo-Json -Depth 5
        exit 1
    }
    throw
}
