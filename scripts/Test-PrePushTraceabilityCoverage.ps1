#requires -Version 7.4
<#
.SYNOPSIS
    Detecta riscos objetivos de rastreabilidade editorial na rotina pre-push.

.DESCRIPTION
    Checagem consultiva para apontar zonas de risco que a fase semantica deve
    justificar. Não tenta provar cobertura documental completa.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [AllowEmptyCollection()]
    [string[]]$ChangedFiles = @(),

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-RepoGit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & git -C $RepositoryRoot @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @()
    if ($null -ne $output) {
        $lines = @($output | ForEach-Object { $_.ToString() })
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Lines    = $lines
        Text     = ($lines -join [Environment]::NewLine)
    }
}

function Normalize-RepoPath {
    param([string]$Path)

    return (($Path -replace '\\', '/').Trim())
}

function Add-Finding {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Target,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Path = $null
    )

    $Target.Add([pscustomobject][ordered]@{
        code     = $Code
        severity = 'warn'
        path     = $Path
        message  = $Message
    })
}

function Get-GitFileTextAtRef {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$Ref,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $result = Invoke-RepoGit -RepositoryRoot $RepositoryRoot -Arguments @('show', ('{0}:{1}' -f $Ref, $Path))
    if ($result.ExitCode -ne 0) {
        return $null
    }
    return $result.Text
}

function Get-ExtractorSignatureVersionFromSources {
    param(
        [AllowNull()]
        [string]$PrimarySource,

        [AllowNull()]
        [string]$FallbackSource
    )

    foreach ($source in @($PrimarySource, $FallbackSource)) {
        if ([string]::IsNullOrWhiteSpace($source)) { continue }
        $versionMatch = [regex]::Match($source, 'EXTRACTOR_SIGNATURE_VERSION\s*=\s*"(?<version>[^"]+)"')
        if ($versionMatch.Success) {
            return $versionMatch.Groups['version'].Value
        }
    }

    return $null
}

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
$normalizedChangedFiles = @($ChangedFiles | ForEach-Object { Normalize-RepoPath -Path $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
if ($normalizedChangedFiles.Count -eq 0) {
    $changedResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--name-only', "$BaseRef..HEAD")
    if ($changedResult.ExitCode -ne 0) {
        throw ("Falha ao listar arquivos alterados em {0}..HEAD: {1}" -f $BaseRef, $changedResult.Text)
    }
    $normalizedChangedFiles = @($changedResult.Lines | ForEach-Object { Normalize-RepoPath -Path $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

$publicTraceabilityPath = Join-Path $resolvedRoot '09-inventario-e-rastreabilidade-publica.md'
$agentGuidePath = Join-Path $resolvedRoot '08-guia-para-agente-gpt.md'
$publicTraceabilityText = if (Test-Path -LiteralPath $publicTraceabilityPath -PathType Leaf) {
    [System.IO.File]::ReadAllText($publicTraceabilityPath)
} else {
    ''
}
$agentGuideText = if (Test-Path -LiteralPath $agentGuidePath -PathType Leaf) {
    [System.IO.File]::ReadAllText($agentGuidePath)
} else {
    ''
}

$findings = [System.Collections.Generic.List[object]]::new()

$agentsChanged = $normalizedChangedFiles -contains 'AGENTS.md'
$prePushDocChanged = $normalizedChangedFiles -contains '13-revisao-pre-push.md'
if ($agentsChanged) {
    $agentsDiff = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--unified=0', "$BaseRef..HEAD", '--', 'AGENTS.md')
    if ($agentsDiff.ExitCode -eq 0 -and
        $agentsDiff.Text -match '(?i)(pre-push|pré-push|09-inventario|rastreabilidade|13-revisao)' -and
        -not ($normalizedChangedFiles -contains '08-guia-para-agente-gpt.md')) {
        Add-Finding -Target $findings -Code 'AGENTS_PREPUSH_NOT_MIRRORED_IN_08' -Path '08-guia-para-agente-gpt.md' -Message 'AGENTS.md alterou regra pre-push/rastreabilidade, mas 08-guia-para-agente-gpt.md nao aparece no intervalo; avaliar se o guia do agente ficou defasado.'
    }
}
if ($prePushDocChanged -and -not ($normalizedChangedFiles -contains '08-guia-para-agente-gpt.md')) {
    Add-Finding -Target $findings -Code 'PREPUSH_DOC_NOT_MIRRORED_IN_08' -Path '08-guia-para-agente-gpt.md' -Message '13-revisao-pre-push.md alterado no intervalo, mas 08-guia-para-agente-gpt.md nao; avaliar se o resumo para agentes GPT ficou defasado.'
}

# Trava anti-regressao do 09 enxuto (indice de ponteiros): entrada de script que voltou ao
# formato verboso antigo (rotulo "Evidencia direta" colado num caminho scripts/...). Pos-
# enxugamento o ponteiro de script nao leva rotulo (- `scripts/X` (categoria) -- ...); o
# reaparecimento desse formato sinaliza prosa de contrato voltando a duplicar o dono logico.
# Invariante (nao diff-scoped), warn, com teto. Bullets de governanca que citam um script tem
# texto entre o rotulo e o caminho (": o script `scripts/...`"), entao nao casam o padrao.
$verboseEntryRegex = [regex]'(?m)^- `Evid[eê]ncia direta`:[ \t]*`scripts(-maintenance)?/'
$verboseLineCap = 25
$verboseReported = 0
foreach ($verboseMatch in $verboseEntryRegex.Matches($publicTraceabilityText)) {
    if ($verboseReported -ge $verboseLineCap) { break }
    $verboseLineNumber = (($publicTraceabilityText.Substring(0, $verboseMatch.Index)) -split "`n").Count
    Add-Finding -Target $findings -Code 'PUBLIC_TRACEABILITY_VERBOSE_LINE' -Path '09-inventario-e-rastreabilidade-publica.md' -Message ("Linha ~{0} do 09 esta no formato verboso de entrada de script (rotulo 'Evidencia direta' colado num caminho scripts/); o 09 e indice de ponteiros - reduzir a 1 linha (papel + dono + validacao), o detalhe de contrato vive no dono." -f $verboseLineNumber)
    $verboseReported++
}

$scriptRiskPattern = '(INVENTORY_[A-Z_]+|DRIFT_[A-Z_]+|executionEvidence|watcherContext|pathEnrichment|diagnosticDegraded|compactSignals|PUSH_READINESS|pushReadiness|estado_operacional_sugerido|atualizacao_metodologica_pendente)'
$changedScriptPaths = @($normalizedChangedFiles | Where-Object { $_ -match '^scripts/.+\.(ps1|py|json)$' })
foreach ($scriptPath in $changedScriptPaths) {
    $scriptDiff = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--unified=0', "$BaseRef..HEAD", '--', $scriptPath)
    if ($scriptDiff.ExitCode -ne 0) {
        continue
    }

    $scriptBaseName = Split-Path -Leaf $scriptPath
    $isTraceabilityDetector = $scriptBaseName -eq 'Test-PrePushTraceabilityCoverage.ps1'
    $addedDiffText = (@($scriptDiff.Lines | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' }) -join [Environment]::NewLine)
    $removedDiffText = (@($scriptDiff.Lines | Where-Object { $_ -match '^-' -and $_ -notmatch '^---' }) -join [Environment]::NewLine)
    $scriptHasTraceabilityRisk = $addedDiffText -match $scriptRiskPattern
    if ($scriptHasTraceabilityRisk -and $publicTraceabilityText -notmatch [regex]::Escape($scriptBaseName)) {
        Add-Finding -Target $findings -Code 'PUBLIC_TRACEABILITY_MISSING_SCRIPT' -Path $scriptPath -Message ("{0} mudou contrato/sinal rastreavel, mas 09-inventario-e-rastreabilidade-publica.md nao menciona o script nominalmente." -f $scriptPath)
    }

    $tokens = if ($isTraceabilityDetector) {
        @()
    } else {
        $addedTokens = @([regex]::Matches($addedDiffText, $scriptRiskPattern) | ForEach-Object { $_.Value } | Sort-Object -Unique)
        $removedTokens = @([regex]::Matches($removedDiffText, $scriptRiskPattern) | ForEach-Object { $_.Value } | Sort-Object -Unique)
        @($addedTokens | Where-Object { $removedTokens -notcontains $_ })
    }
    foreach ($token in $tokens) {
        if ($publicTraceabilityText -notmatch [regex]::Escape($token)) {
            Add-Finding -Target $findings -Code 'PUBLIC_TRACEABILITY_MISSING_TOKEN' -Path $scriptPath -Message ("Token rastreavel '{0}' aparece no diff de {1}, mas nao aparece no 09." -f $token, $scriptPath)
        }
    }
}

$selfTestChangedPaths = @($changedScriptPaths | Where-Object { $_ -match 'SelfTest\.ps1$' })
foreach ($selfTestPath in $selfTestChangedPaths) {
    $selfTestBaseName = Split-Path -Leaf $selfTestPath
    $motorCandidates = [System.Collections.Generic.List[string]]::new()
    $suffixMotor = $selfTestBaseName -replace 'SelfTest\.ps1$', '.ps1'
    if ($suffixMotor -ne $selfTestBaseName) {
        $motorCandidates.Add($suffixMotor) | Out-Null
    }
    if ($selfTestBaseName -match '^Test-(.+)SelfTest\.ps1$') {
        $getMotor = ('Get-{0}.ps1' -f $Matches[1])
        if (-not $motorCandidates.Contains($getMotor)) {
            $motorCandidates.Add($getMotor) | Out-Null
        }
    }

    $existingMotorCandidates = [System.Collections.Generic.List[string]]::new()
    foreach ($motorCandidate in $motorCandidates) {
        $candidatePath = Join-Path (Join-Path $resolvedRoot 'scripts') $motorCandidate
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            $existingMotorCandidates.Add($motorCandidate) | Out-Null
        }
    }

    $motorMentioned = $false
    foreach ($motorCandidate in $existingMotorCandidates) {
        if ($publicTraceabilityText -match [regex]::Escape($motorCandidate)) {
            $motorMentioned = $true
            break
        }
    }

    if ($existingMotorCandidates.Count -gt 0 -and
        $publicTraceabilityText -match [regex]::Escape($selfTestBaseName) -and
        -not $motorMentioned) {
        $motorList = ($existingMotorCandidates -join ', ')
        Add-Finding -Target $findings -Code 'PUBLIC_TRACEABILITY_AGGREGATED_ROLE_RISK' -Path $selfTestPath -Message ("09 menciona a bateria {0}, mas nao menciona o motor correspondente ({1}); avaliar rastreabilidade agregada demais." -f $selfTestBaseName, $motorList)
    }
}

if ((($agentsChanged -or $prePushDocChanged) -and ($normalizedChangedFiles -contains '08-guia-para-agente-gpt.md'))) {
    foreach ($requiredPhrase in @('13-revisao-pre-push.md', '09-inventario-e-rastreabilidade-publica.md', 'paridade motor', 'rastreabilidade agregada')) {
        if ($agentGuideText -notmatch [regex]::Escape($requiredPhrase)) {
            Add-Finding -Target $findings -Code 'AGENT_GUIDE_PREPUSH_RULE_INCOMPLETE' -Path '08-guia-para-agente-gpt.md' -Message ("08-guia-para-agente-gpt.md foi alterado junto com doc pre-push, mas nao contem marcador esperado: {0}" -f $requiredPhrase)
        }
    }
}

$queryPyPath = Join-Path $resolvedRoot 'scripts/Query-KbIntelligenceIndex.py'
$buildPs1Path = Join-Path $resolvedRoot 'scripts/Build-KbIntelligenceIndex.ps1'
$queryPs1Path = Join-Path $resolvedRoot 'scripts/Query-KbIntelligenceIndex.ps1'
$buildPyRelativePath = 'scripts/Build-KbIntelligenceIndex.py'
$signaturePyRelativePath = 'scripts/GeneXusKbIntelligenceExtractorSignature.py'
if ($normalizedChangedFiles -contains $buildPyRelativePath -or $normalizedChangedFiles -contains $signaturePyRelativePath) {
    $buildPyPath = Join-Path $resolvedRoot $buildPyRelativePath
    if (Test-Path -LiteralPath $buildPyPath -PathType Leaf) {
        $buildPyCurrentText = [System.IO.File]::ReadAllText($buildPyPath)
        $signaturePyPath = Join-Path $resolvedRoot $signaturePyRelativePath
        $signaturePyCurrentText = if (Test-Path -LiteralPath $signaturePyPath -PathType Leaf) {
            [System.IO.File]::ReadAllText($signaturePyPath)
        } else {
            $null
        }
        $buildPyBaseText = Get-GitFileTextAtRef -RepositoryRoot $resolvedRoot -Ref $BaseRef -Path $buildPyRelativePath
        $signaturePyBaseText = Get-GitFileTextAtRef -RepositoryRoot $resolvedRoot -Ref $BaseRef -Path $signaturePyRelativePath
        $currentExtractorVersion = Get-ExtractorSignatureVersionFromSources -PrimarySource $signaturePyCurrentText -FallbackSource $buildPyCurrentText
        $baseExtractorVersion = Get-ExtractorSignatureVersionFromSources -PrimarySource $signaturePyBaseText -FallbackSource $buildPyBaseText

        if ([string]::IsNullOrWhiteSpace($currentExtractorVersion) -or
            [string]::IsNullOrWhiteSpace($baseExtractorVersion)) {
            Add-Finding -Target $findings -Code 'EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED' -Path $buildPyRelativePath -Message ("Nao foi possivel resolver a assinatura do extrator no estado atual ou em {0}; revisar as fontes da versao antes de considerar a cobertura documental valida." -f $BaseRef)
        } elseif ($currentExtractorVersion -ne $baseExtractorVersion) {
            $staleExtractorPattern = [regex]::new(
                ('(?i)\b(?:extrator|extractor)(?:\s+\w+){{0,4}}\s+`?{0}`?\b' -f [regex]::Escape($baseExtractorVersion))
            )
            $docFiles = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
                Where-Object {
                    (Normalize-RepoPath -Path ([System.IO.Path]::GetRelativePath($resolvedRoot, $_.FullName))) -notmatch '^(historico|\.git)/'
                })
            foreach ($docFile in $docFiles) {
                $relativeDocPath = Normalize-RepoPath -Path ([System.IO.Path]::GetRelativePath($resolvedRoot, $docFile.FullName))
                $docText = [System.IO.File]::ReadAllText($docFile.FullName)
                $staleMatches = @($staleExtractorPattern.Matches($docText))
                if ($staleMatches.Count -gt 0) {
                    Add-Finding -Target $findings -Code 'EXTRACTOR_SIGNATURE_STALE_DOC_REF' -Path $relativeDocPath -Message ("A assinatura do extrator mudou de {0} para {1}, mas {2} ainda contem referencia textual a extrator/extractor {0}; revisar se e historico justificado ou gap documental." -f $baseExtractorVersion, $currentExtractorVersion, $relativeDocPath)
                }
            }
        }
    }
}
if ((Test-Path -LiteralPath $queryPyPath -PathType Leaf) -and (Test-Path -LiteralPath $buildPs1Path -PathType Leaf)) {
    $queryPyText = [System.IO.File]::ReadAllText($queryPyPath)
    $buildPs1Text = [System.IO.File]::ReadAllText($buildPs1Path)
    $queryPs1Text = if (Test-Path -LiteralPath $queryPs1Path -PathType Leaf) {
        [System.IO.File]::ReadAllText($queryPs1Path)
    } else {
        ''
    }

    $docPaths = @(
        '02-regras-operacionais-e-runtime.md',
        '08-guia-para-agente-gpt.md',
        'README.md',
        'AGENTS.md',
        '13-revisao-pre-push.md',
        'scripts/README-kb-intelligence.md'
    )
    $docCombined = ($docPaths | ForEach-Object {
        $docPath = Join-Path $resolvedRoot $_
        if (Test-Path -LiteralPath $docPath -PathType Leaf) {
            [System.IO.File]::ReadAllText($docPath)
        } else {
            ''
        }
    }) -join [Environment]::NewLine

    $docsPromiseEffectiveCatalog = ($docCombined -match '(?i)catalogo efetivo|effective catalog') -and
        ($docCombined -match 'Query-KbIntelligenceIndex')

    if ($docsPromiseEffectiveCatalog) {
        $queryHasEffectiveCatalog = $queryPyText -match '(?i)catalog-override-path|parallel-kb-root|resolve_effective|GeneXusObjectTypeCatalogCore'
        if (-not $queryHasEffectiveCatalog) {
            Add-Finding -Target $findings -Code 'MOTOR_DOC_CATALOG_EFFECTIVE_MISMATCH' -Path $queryPyPath -Message 'Documentacao promete catalogo efetivo no Query-KbIntelligenceIndex, mas o motor Python nao referencia merge/override/parallel-kb-root.'
        }
    }

    if ($buildPs1Text -match '\$ParallelKbRoot' -and $queryPs1Text -and $queryPs1Text -notmatch '\$ParallelKbRoot') {
        Add-Finding -Target $findings -Code 'MOTOR_PAIR_PARAM_ASYMMETRY' -Path $queryPs1Path -Message 'Build-KbIntelligenceIndex.ps1 expoe -ParallelKbRoot, mas Query-KbIntelligenceIndex.ps1 nao.'
    }
}

$orchestratorPath = 'scripts/Invoke-PrePushMechanicalChecks.ps1'
if ($normalizedChangedFiles -contains $orchestratorPath) {
    $orchestratorDiff = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--unified=0', "$BaseRef..HEAD", '--', $orchestratorPath)
    if ($orchestratorDiff.ExitCode -eq 0) {
        $addedOrchestratorText = (@($orchestratorDiff.Lines | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' }) -join [Environment]::NewLine)
        $referencedGateScripts = @([regex]::Matches($addedOrchestratorText, 'Test-[A-Za-z0-9-]+\.ps1') |
            ForEach-Object { $_.Value } |
            Where-Object { $_ -ne 'Test-PsScriptsParse.ps1' } |
            Sort-Object -Unique)
        foreach ($gateScript in $referencedGateScripts) {
            if ($agentGuideText -notmatch [regex]::Escape($gateScript)) {
                Add-Finding -Target $findings -Code 'AGENT_GUIDE_MISSING_ORCHESTRATOR_GATE' -Path '08-guia-para-agente-gpt.md' -Message ("Invoke-PrePushMechanicalChecks.ps1 passou a referenciar {0}, mas 08-guia-para-agente-gpt.md nao cita esse gate nominalmente." -f $gateScript)
            }
        }
    }
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }
$result = [ordered]@{
    status       = $status
    baseRef      = $BaseRef
    changedFiles = @($normalizedChangedFiles)
    findings     = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("TRACEABILITY_COVERAGE={0}" -f $status)
    foreach ($finding in $findings) {
        Write-Output ("TRACEABILITY_FINDING: {0}: {1}" -f $finding.code, $finding.message)
    }
}

exit 0
