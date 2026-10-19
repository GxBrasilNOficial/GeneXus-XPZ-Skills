#requires -Version 7.4

<#
.SYNOPSIS
    Executa checagens mecanicas iniciais da rotina pre-push.

.DESCRIPTION
    Coordena contexto git (commits pendentes, diff --check, arquivos alterados),
    delega parse PowerShell a scripts/Test-PsScriptsParse.ps1 (inclui scripts/
    e scripts-maintenance/), parse Python sem bytecode a scripts/Test-PyScriptsParse.ps1
    e classifica arquivos do diff para insumo da fase semantica do agente.

    Não substitui busca de coerência cruzada, regra em camadas de skills longas
    nem relatório final ao usuário — ver 13-revisao-pre-push.md (AGENTS.md aponta para esse arquivo).
    Emite avisos informativos se a branch não for main ou se a working tree
    tiver alteracoes não commitadas fora do intervalo BaseRef..HEAD. Com
    commitsBehind > 0, define pushReadiness=blocked e marca o diff do intervalo
    como apenas diagnostico (sem falhar parse/whitespace).

.PARAMETER RootPath
    Raiz do repositório. Default: pai de scripts/.

.PARAMETER BaseRef
    Referencia única do intervalo analisado: commits pendentes, contagem,
    arquivos alterados e diff --check usam sempre BaseRef..HEAD. Default:
    origin/main (copia local do último fetch; desde o último push usual em main).
    Se a ref não existir, o script falha com mensagem clara (sem fallback
    automático para main). Com a ref existente mas desatualizada em relacao ao
    remoto, o intervalo pode superestimar commits pendentes; o agente deve
    executar git fetch origin antes da rotina quando precisar comparar contra
    o remoto atual (ver AGENTS.md). O upstream da branch só aparece no JSON
    como contexto informativo.

.PARAMETER AsJson
    Emite diagnostico estruturado em JSON.

.PARAMETER SkipParse
    Pula a invocacao de Test-PsScriptsParse.ps1 (uso excepcional).
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [switch]$AsJson,

    [switch]$SkipParse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RelativeDisplayPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    return [System.IO.Path]::GetRelativePath(
        [System.IO.Path]::GetFullPath($BasePath),
        [System.IO.Path]::GetFullPath($TargetPath)
    )
}

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

function Test-GitRefExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$Ref
    )

    $result = Invoke-RepoGit -RepositoryRoot $RepositoryRoot -Arguments @('rev-parse', '--verify', $Ref)
    return ($result.ExitCode -eq 0)
}

function Resolve-GitRepositoryContext {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartPath
    )

    $topLevelResult = Invoke-RepoGit -RepositoryRoot $StartPath -Arguments @('rev-parse', '--show-toplevel')
    if ($topLevelResult.ExitCode -ne 0) {
        throw ("Nao foi possivel resolver repositorio git a partir de '{0}'. Verifique o caminho ou use git rev-parse --show-toplevel manualmente. Detalhe: {1}" -f $StartPath, $topLevelResult.Text)
    }

    $repositoryRoot = $topLevelResult.Lines[0].Trim()
    $gitDirResult = Invoke-RepoGit -RepositoryRoot $repositoryRoot -Arguments @('rev-parse', '--git-dir')
    $gitDir = $null
    if ($gitDirResult.ExitCode -eq 0 -and $gitDirResult.Lines.Count -gt 0) {
        $gitDir = $gitDirResult.Lines[0].Trim()
    }

    return [pscustomobject]@{
        RepositoryRoot = $repositoryRoot
        GitDir         = $gitDir
    }
}

function Get-PropOrDefault {
    # Acesso seguro a propriedade de objeto vindo de ConvertFrom-Json: sob
    # Set-StrictMode -Version Latest, ler propriedade inexistente lanca. Usado para
    # projetar campos opcionais de gate sem acoplar o orquestrador a uma versao
    # especifica do JSON do gate.
    param(
        $Object,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        $Default = $null
    )

    if ($null -eq $Object) { return $Default }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop -or $null -eq $prop.Value) { return $Default }
    return $prop.Value
}

function Get-ChangedFileKind {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $normalized = ($RelativePath -replace '\\', '/').Trim()

    if ($normalized -match '^scripts/.+\.ps1$') {
        return 'scripts'
    }
    if ($normalized -match '^scripts-maintenance/.+\.ps1$') {
        return 'maintenanceScripts'
    }
    if ($normalized -match '\.example\.ps1$') {
        return 'examples'
    }
    if ($normalized -match '^historico/') {
        return 'historico'
    }
    if ($normalized -match '/SKILL\.md$') {
        return 'skills'
    }
    if ($normalized -match '^\.github/') {
        return 'workflows'
    }
    if ($normalized -match '^[^/]+\.md$') {
        return 'baseDocs'
    }

    return 'other'
}

function Add-ChangedFilesByKind {
    param(
        [AllowEmptyCollection()]
        [string[]]$RelativePaths = @()
    )

    $byKind = [ordered]@{
        scripts   = @()
        maintenanceScripts = @()
        skills    = @()
        baseDocs  = @()
        examples  = @()
        workflows = @()
        historico = @()
        other     = @()
    }

    foreach ($relativePath in @($RelativePaths | Sort-Object)) {
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }

        $kind = Get-ChangedFileKind -RelativePath $relativePath
        $byKind[$kind] = @($byKind[$kind] + $relativePath)
    }

    return $byKind
}

function Get-WorkingTreeDiagnostics {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [int]$MaxSamplePaths = 15
    )

    $statusResult = Invoke-RepoGit -RepositoryRoot $RepositoryRoot -Arguments @('status', '--porcelain')
    if ($statusResult.ExitCode -ne 0) {
        throw ("Falha ao ler working tree (git status --porcelain). Detalhe: {0}" -f $statusResult.Text)
    }

    $untrackedFiles = [System.Collections.Generic.List[string]]::new()
    $dirtyTrackedFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($line in @($statusResult.Lines)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }

        $status = $line.Substring(0, 2)
        $path = $line.Substring(3).Trim()
        if ($path -match ' -> ') {
            $path = ($path -split ' -> ', 2)[1].Trim()
        }

        if ($status -eq '??') {
            [void]$untrackedFiles.Add($path)
        } else {
            [void]$dirtyTrackedFiles.Add($path)
        }
    }

    $untrackedAll = @($untrackedFiles)
    $dirtyTrackedAll = @($dirtyTrackedFiles)
    $isClean = ($untrackedAll.Count -eq 0 -and $dirtyTrackedAll.Count -eq 0)

    return [pscustomobject]@{
        Status              = $(if ($isClean) { 'clean' } else { 'dirty' })
        UntrackedCount      = $untrackedAll.Count
        DirtyTrackedCount   = $dirtyTrackedAll.Count
        UntrackedFiles      = @($untrackedAll | Select-Object -First $MaxSamplePaths)
        DirtyTrackedFiles   = @($dirtyTrackedAll | Select-Object -First $MaxSamplePaths)
        UntrackedTruncated  = ($untrackedAll.Count -gt $MaxSamplePaths)
        DirtyTrackedTruncated = ($dirtyTrackedAll.Count -gt $MaxSamplePaths)
    }
}

$startPath = (Resolve-Path -LiteralPath $RootPath).Path
$gitContext = Resolve-GitRepositoryContext -StartPath $startPath
$resolvedRoot = $gitContext.RepositoryRoot
$resolvedGitDir = $gitContext.GitDir

$branchResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
if ($branchResult.ExitCode -ne 0) {
    throw 'Nao foi possivel resolver a branch atual.'
}
$currentBranch = $branchResult.Lines[0].Trim()

$expectedBranch = 'main'
$onExpectedBranch = ($currentBranch -ceq $expectedBranch)
$workingTree = Get-WorkingTreeDiagnostics -RepositoryRoot $resolvedRoot

$upstreamResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', '--abbrev-ref', '@{upstream}')
$upstreamRef = $null
$upstreamConfigured = ($upstreamResult.ExitCode -eq 0)
if ($upstreamConfigured) {
    $upstreamRef = $upstreamResult.Lines[0].Trim()
}

$effectiveBaseRef = $BaseRef
if (-not (Test-GitRefExists -RepositoryRoot $resolvedRoot -Ref $effectiveBaseRef)) {
    throw ("Ref base '{0}' nao encontrada. Para medir commits locais ainda nao enviados ao remoto, confirme que origin/main existe (ex.: git fetch origin) ou passe -BaseRef com uma ref valida. Nao ha fallback automatico para main." -f $BaseRef)
}

$range = "$effectiveBaseRef..HEAD"
$commitLogResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('log', $range, '--oneline')
if ($commitLogResult.ExitCode -ne 0) {
    throw "Falha ao listar commits pendentes para o intervalo $range."
}

$pendingCommits = @($commitLogResult.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

$aheadRange = "${effectiveBaseRef}..HEAD"
$behindRange = "HEAD..${effectiveBaseRef}"
$aheadResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-list', '--count', $aheadRange)
$behindResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-list', '--count', $behindRange)

$commitsAhead = 0
$commitsBehind = 0
if ($aheadResult.ExitCode -eq 0 -and $aheadResult.Lines.Count -gt 0) {
    $commitsAhead = [int]$aheadResult.Lines[0]
}
if ($behindResult.ExitCode -eq 0 -and $behindResult.Lines.Count -gt 0) {
    $commitsBehind = [int]$behindResult.Lines[0]
}

$changedFiles = @()
$whitespaceStatus = 'clean'
$whitespaceIssues = @()

if ($commitsAhead -gt 0) {
    $nameOnlyResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--name-only', $range)
    if ($nameOnlyResult.ExitCode -ne 0) {
        throw "Falha ao listar arquivos alterados para o intervalo $range."
    }
    $changedFiles = @($nameOnlyResult.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $whitespaceResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--check', $range)
    if ($whitespaceResult.ExitCode -ne 0) {
        $whitespaceStatus = 'issues-found'
        $whitespaceIssues = @($whitespaceResult.Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
}

$changedFilesByKind = Add-ChangedFilesByKind -RelativePaths $changedFiles

$parseGate = [ordered]@{
    script     = 'scripts/Test-PsScriptsParse.ps1'
    status     = 'skipped'
    exitCode   = $null
    fileCount  = $null
    errorCount = $null
    findings   = @()
}

$pythonParseGate = [ordered]@{
    script     = 'scripts/Test-PyScriptsParse.ps1'
    status     = 'skipped'
    exitCode   = $null
    fileCount  = $null
    errorCount = $null
    findings   = @()
}

$traceabilityCoverageGate = [ordered]@{
    script   = 'scripts/Test-PrePushTraceabilityCoverage.ps1'
    status   = 'skipped'
    findings = @()
}

$msBuildProbeDocParityGate = [ordered]@{
    script   = 'scripts/Test-PrePushMsBuildProbeDocParity.ps1'
    status   = 'skipped'
    findings = @()
}

$unexpectedCharGate = [ordered]@{
    script   = 'scripts/Test-GeneXusUnexpectedCharacter.ps1'
    status   = 'skipped'
    findings = @()
}

$newTokenPropagationGate = [ordered]@{
    script              = 'scripts/Test-PrePushNewTokenPropagation.ps1'
    status              = 'skipped'
    candidateCount      = 0
    classCounts         = $null
    truncated           = $false
    truncatedProseCount = 0
    findings            = @()
}

$sharedScriptSkillGate = [ordered]@{
    script   = 'scripts/Test-PrePushSharedScriptSkillCoverage.ps1'
    status   = 'skipped'
    findings = @()
}

$historyCommitGate = [ordered]@{
    script   = 'scripts/Test-PrePushHistoryCommitPlaceholder.ps1'
    status   = 'skipped'
    findings = @()
}

$reviewerRoDriftGate = [ordered]@{
    script   = 'scripts/Test-PrePushOpenCodeReviewerRoDrift.ps1'
    status   = 'skipped'
    findings = @()
}

$gateEnumParityGate = [ordered]@{
    script   = 'scripts/Test-PrePushGateEnumerationParity.ps1'
    status   = 'skipped'
    findings = @()
}

$backendEnumParityGate = [ordered]@{
    script   = 'scripts/Test-PrePushBackendEnumerationParity.ps1'
    status   = 'skipped'
    findings = @()
}

$mechanicalFailures = [System.Collections.Generic.List[string]]::new()

if (-not $SkipParse) {
    $parseScript = Join-Path $PSScriptRoot 'Test-PsScriptsParse.ps1'
    if (-not (Test-Path -LiteralPath $parseScript -PathType Leaf)) {
        throw "Script de parse nao encontrado: $parseScript"
    }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $parseOutput = & $parseScript -RootPath $resolvedRoot -AsJson 2>&1
    $parseExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction

    $parseJsonText = ($parseOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $parseObject = $null
    if (-not [string]::IsNullOrWhiteSpace($parseJsonText)) {
        $parseObject = $parseJsonText | ConvertFrom-Json
    }

    $parseGate.status = if ($parseExitCode -eq 0) { 'pass' } else { 'fail' }
    $parseGate.exitCode = $parseExitCode
    if ($null -ne $parseObject) {
        $parseGate.fileCount = $parseObject.fileCount
        $parseGate.errorCount = $parseObject.errorCount
        $parseGate.findings = @($parseObject.findings)
    }

    if ($parseExitCode -ne 0) {
        [void]$mechanicalFailures.Add('parse')
    }

    $pythonParseScript = Join-Path $PSScriptRoot 'Test-PyScriptsParse.ps1'
    if (Test-Path -LiteralPath $pythonParseScript -PathType Leaf) {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $pythonParseOutput = & $pythonParseScript -RootPath $resolvedRoot -AsJson 2>&1
        $pythonParseExitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorAction

        $pythonParseJsonText = ($pythonParseOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        $pythonParseObject = $null
        if (-not [string]::IsNullOrWhiteSpace($pythonParseJsonText)) {
            $pythonParseObject = $pythonParseJsonText | ConvertFrom-Json
        }

        $pythonParseGate.status = if ($pythonParseExitCode -eq 0) { 'pass' } else { 'fail' }
        $pythonParseGate.exitCode = $pythonParseExitCode
        if ($null -ne $pythonParseObject) {
            $pythonParseGate.fileCount = $pythonParseObject.fileCount
            $pythonParseGate.errorCount = $pythonParseObject.errorCount
            $pythonParseGate.findings = @($pythonParseObject.findings)
        }

        if ($pythonParseExitCode -ne 0) {
            [void]$mechanicalFailures.Add('pythonParse')
        }
    }
}

if ($whitespaceStatus -ne 'clean') {
    [void]$mechanicalFailures.Add('whitespace')
}

$traceabilityCoverageScript = Join-Path $PSScriptRoot 'Test-PrePushTraceabilityCoverage.ps1'
if (Test-Path -LiteralPath $traceabilityCoverageScript -PathType Leaf) {
    $traceabilityOutput = & $traceabilityCoverageScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $traceabilityExitCode = $LASTEXITCODE
    $traceabilityJsonText = ($traceabilityOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $traceabilityObject = $null
    if (-not [string]::IsNullOrWhiteSpace($traceabilityJsonText)) {
        $traceabilityObject = $traceabilityJsonText | ConvertFrom-Json
    }

    if ($traceabilityExitCode -eq 0 -and $null -ne $traceabilityObject) {
        $traceabilityCoverageGate.status = $traceabilityObject.status
        $traceabilityCoverageGate.findings = @($traceabilityObject.findings)
    } else {
        $traceabilityCoverageGate.status = 'warn'
        $traceabilityCoverageGate.findings = @([pscustomobject][ordered]@{
            code     = 'TRACEABILITY_COVERAGE_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-PrePushTraceabilityCoverage.ps1'
            message  = "Falha consultiva ao executar Test-PrePushTraceabilityCoverage.ps1: $traceabilityJsonText"
        })
    }
}

$msBuildProbeDocParityScript = Join-Path $PSScriptRoot 'Test-PrePushMsBuildProbeDocParity.ps1'
if (Test-Path -LiteralPath $msBuildProbeDocParityScript -PathType Leaf) {
    $msBuildParityOutput = & $msBuildProbeDocParityScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $msBuildParityExitCode = $LASTEXITCODE
    $msBuildParityJsonText = ($msBuildParityOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $msBuildParityObject = $null
    if (-not [string]::IsNullOrWhiteSpace($msBuildParityJsonText)) {
        $msBuildParityObject = $msBuildParityJsonText | ConvertFrom-Json
    }

    if ($msBuildParityExitCode -eq 0 -and $null -ne $msBuildParityObject) {
        $msBuildProbeDocParityGate.status = $msBuildParityObject.status
        $msBuildProbeDocParityGate.findings = @($msBuildParityObject.findings)
        if ($msBuildParityObject.status -eq 'fail') {
            [void]$mechanicalFailures.Add('msBuildProbeDocParity')
        }
    } else {
        $msBuildProbeDocParityGate.status = 'warn'
        $msBuildProbeDocParityGate.findings = @([pscustomobject][ordered]@{
            code     = 'MSBUILD_PROBE_DOC_PARITY_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-PrePushMsBuildProbeDocParity.ps1'
            message  = "Falha ao executar Test-PrePushMsBuildProbeDocParity.ps1: $msBuildParityJsonText"
        })
    }
}

$unexpectedCharScript = Join-Path $PSScriptRoot 'Test-GeneXusUnexpectedCharacter.ps1'
if (Test-Path -LiteralPath $unexpectedCharScript -PathType Leaf) {
    $unexpectedCharOutput = & $unexpectedCharScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $unexpectedCharExitCode = $LASTEXITCODE
    $unexpectedCharJsonText = ($unexpectedCharOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $unexpectedCharObject = $null
    if (-not [string]::IsNullOrWhiteSpace($unexpectedCharJsonText)) {
        $unexpectedCharObject = $unexpectedCharJsonText | ConvertFrom-Json
    }

    if ($unexpectedCharExitCode -eq 0 -and $null -ne $unexpectedCharObject) {
        $unexpectedCharGate.status = $unexpectedCharObject.status
        $unexpectedCharGate.findings = @($unexpectedCharObject.findings)
    } else {
        $unexpectedCharGate.status = 'warn'
        $unexpectedCharGate.findings = @([pscustomobject][ordered]@{
            code     = 'UNEXPECTED_CHARACTER_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-GeneXusUnexpectedCharacter.ps1'
            message  = "Falha consultiva ao executar Test-GeneXusUnexpectedCharacter.ps1: $unexpectedCharJsonText"
        })
    }
}

$newTokenPropagationScript = Join-Path $PSScriptRoot 'Test-PrePushNewTokenPropagation.ps1'
if (Test-Path -LiteralPath $newTokenPropagationScript -PathType Leaf) {
    $newTokenOutput = & $newTokenPropagationScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $newTokenExitCode = $LASTEXITCODE
    $newTokenJsonText = ($newTokenOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $newTokenObject = $null
    if (-not [string]::IsNullOrWhiteSpace($newTokenJsonText)) {
        $newTokenObject = $newTokenJsonText | ConvertFrom-Json
    }

    if ($newTokenExitCode -eq 0 -and $null -ne $newTokenObject) {
        $newTokenPropagationGate.status = $newTokenObject.status
        $newTokenPropagationGate.findings = @($newTokenObject.findings)
        # O teto -MaxFindings trunca so a classe 'prose'. Sem projetar estes campos,
        # o revisor (em especial o semantic-only, que so tem o dossie) ve as candidatas
        # listadas e nao sabe quantas foram descartadas — e o 13 (passo 2) promete que
        # truncatedProseCount informa exatamente isso.
        $newTokenPropagationGate.candidateCount = [int](Get-PropOrDefault $newTokenObject 'candidateCount' 0)
        $newTokenPropagationGate.classCounts = (Get-PropOrDefault $newTokenObject 'classCounts' $null)
        $newTokenPropagationGate.truncated = [bool](Get-PropOrDefault $newTokenObject 'truncated' $false)
        $newTokenPropagationGate.truncatedProseCount = [int](Get-PropOrDefault $newTokenObject 'truncatedProseCount' 0)
    } else {
        $newTokenPropagationGate.status = 'warn'
        $newTokenPropagationGate.findings = @([pscustomobject][ordered]@{
            code     = 'NEW_TOKEN_PROPAGATION_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-PrePushNewTokenPropagation.ps1'
            message  = "Falha consultiva ao executar Test-PrePushNewTokenPropagation.ps1: $newTokenJsonText"
        })
    }
}

$sharedScriptSkillScript = Join-Path $PSScriptRoot 'Test-PrePushSharedScriptSkillCoverage.ps1'
if (Test-Path -LiteralPath $sharedScriptSkillScript -PathType Leaf) {
    $sharedScriptOutput = & $sharedScriptSkillScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $sharedScriptExitCode = $LASTEXITCODE
    $sharedScriptJsonText = ($sharedScriptOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $sharedScriptObject = $null
    if (-not [string]::IsNullOrWhiteSpace($sharedScriptJsonText)) {
        $sharedScriptObject = $sharedScriptJsonText | ConvertFrom-Json
    }

    if ($sharedScriptExitCode -eq 0 -and $null -ne $sharedScriptObject) {
        $sharedScriptSkillGate.status = $sharedScriptObject.status
        $sharedScriptSkillGate.findings = @($sharedScriptObject.findings)
    } else {
        $sharedScriptSkillGate.status = 'warn'
        $sharedScriptSkillGate.findings = @([pscustomobject][ordered]@{
            code     = 'SHARED_SCRIPT_SKILL_COVERAGE_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-PrePushSharedScriptSkillCoverage.ps1'
            message  = "Falha consultiva ao executar Test-PrePushSharedScriptSkillCoverage.ps1: $sharedScriptJsonText"
        })
    }
}

$historyCommitScript = Join-Path $PSScriptRoot 'Test-PrePushHistoryCommitPlaceholder.ps1'
if (Test-Path -LiteralPath $historyCommitScript -PathType Leaf) {
    $historyCommitOutput = & $historyCommitScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $historyCommitExitCode = $LASTEXITCODE
    $historyCommitJsonText = ($historyCommitOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $historyCommitObject = $null
    if (-not [string]::IsNullOrWhiteSpace($historyCommitJsonText)) {
        $historyCommitObject = $historyCommitJsonText | ConvertFrom-Json
    }

    if ($historyCommitExitCode -eq 0 -and $null -ne $historyCommitObject) {
        $historyCommitGate.status = $historyCommitObject.status
        $historyCommitGate.findings = @($historyCommitObject.findings)
    } else {
        $historyCommitGate.status = 'warn'
        $historyCommitGate.findings = @([pscustomobject][ordered]@{
            code     = 'HISTORY_COMMIT_PLACEHOLDER_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-PrePushHistoryCommitPlaceholder.ps1'
            message  = "Falha consultiva ao executar Test-PrePushHistoryCommitPlaceholder.ps1: $historyCommitJsonText"
        })
    }
}

$reviewerRoDriftScript = Join-Path $PSScriptRoot 'Test-PrePushOpenCodeReviewerRoDrift.ps1'
if (Test-Path -LiteralPath $reviewerRoDriftScript -PathType Leaf) {
    $reviewerRoDriftOutput = & $reviewerRoDriftScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $reviewerRoDriftExitCode = $LASTEXITCODE
    $reviewerRoDriftJsonText = ($reviewerRoDriftOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $reviewerRoDriftObject = $null
    if (-not [string]::IsNullOrWhiteSpace($reviewerRoDriftJsonText)) {
        $reviewerRoDriftObject = $reviewerRoDriftJsonText | ConvertFrom-Json
    }

    if ($reviewerRoDriftExitCode -eq 0 -and $null -ne $reviewerRoDriftObject) {
        $reviewerRoDriftGate.status = $reviewerRoDriftObject.status
        $reviewerRoDriftGate.findings = @($reviewerRoDriftObject.findings)
    } else {
        $reviewerRoDriftGate.status = 'warn'
        $reviewerRoDriftGate.findings = @([pscustomobject][ordered]@{
            code     = 'OPENCODE_REVIEWER_RO_DRIFT_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-PrePushOpenCodeReviewerRoDrift.ps1'
            message  = "Falha consultiva ao executar Test-PrePushOpenCodeReviewerRoDrift.ps1: $reviewerRoDriftJsonText"
        })
    }
}

function New-EnumerationGateFailure {
    param([string]$ScriptRel, [string]$Code, [string]$Message, [int]$ExitCode = -1)
    return [pscustomobject][ordered]@{
        script = $ScriptRel
        status = 'warn'
        scanComplete = $false
        scanIssues = @([pscustomobject][ordered]@{ code = $Code; path = $ScriptRel; message = $Message })
        canonicalMembers = @()
        files = @()
        candidateCount = 0
        displayTruncated = $false
        findings = @()
        displayFindings = @()
        invocationExitCode = $ExitCode
    }
}

function Invoke-EnumerationGate {
    param([string]$ScriptRel)

    $scriptPath = Join-Path $PSScriptRoot (Split-Path -Leaf $ScriptRel)
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_SCRIPT_MISSING' -Message 'Script do gate ausente ao lado do orquestrador.')
    }

    $process = $null
    try {
        $pwshPath = (Get-Process -Id $PID).Path
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new($pwshPath)
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
        foreach ($argument in @('-NoProfile', '-File', $scriptPath, '-RootPath', $resolvedRoot, '-BaseRef', $effectiveBaseRef, '-MaxFindings', '500', '-AsJson')) {
            [void]$startInfo.ArgumentList.Add($argument)
        }
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) { throw 'Não foi possível iniciar pwsh para o gate consultivo.' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
    } catch {
        if ($null -ne $process) { $process.Dispose() }
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_INVOCATION_EXCEPTION' -Message $_.Exception.Message)
    } finally {
        if ($null -ne $process) { $process.Dispose() }
    }

    if ($exitCode -ne 0) {
        $detail = @("exit=$exitCode", $stderr.Trim(), $stdout.Trim() | Select-Object -First 1) -join ' | '
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_NONZERO_EXIT' -Message $detail -ExitCode $exitCode)
    }
    if ([string]::IsNullOrWhiteSpace($stdout)) {
        $emptyOutputMessage = 'O gate não emitiu JSON em stdout.'
        if (-not [string]::IsNullOrWhiteSpace($stderr)) { $emptyOutputMessage = $stderr.Trim() }
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_EMPTY_OUTPUT' -Message $emptyOutputMessage -ExitCode $exitCode)
    }

    try {
        $gateObject = $stdout | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $detail = "JSON inválido em stdout: $($_.Exception.Message)"
        if (-not [string]::IsNullOrWhiteSpace($stderr)) { $detail += "; stderr: $($stderr.Trim())" }
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_INVALID_JSON' -Message $detail -ExitCode $exitCode)
    }

    $requiredProperties = @('status', 'scanComplete', 'scanIssues', 'canonicalMembers', 'files', 'candidateCount', 'displayTruncated', 'findings')
    foreach ($propertyName in $requiredProperties) {
        if ($null -eq $gateObject.PSObject.Properties[$propertyName]) {
            return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_CONTRACT_INVALID' -Message ("Campo obrigatório ausente no JSON do gate: {0}." -f $propertyName) -ExitCode $exitCode)
        }
    }
    if ($gateObject.scanComplete -isnot [bool] -or $gateObject.canonicalMembers -isnot [array] -or $gateObject.files -isnot [array] -or $gateObject.findings -isnot [array] -or $gateObject.scanIssues -isnot [array]) {
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_CONTRACT_INVALID' -Message 'Tipos inválidos nos campos scanComplete, canonicalMembers, files, findings ou scanIssues.' -ExitCode $exitCode)
    }

    foreach ($fileState in $gateObject.files) {
        if ($null -eq $fileState.PSObject.Properties['file'] -or $fileState.file -isnot [string] -or
            $null -eq $fileState.PSObject.Properties['complete'] -or $fileState.complete -isnot [bool]) {
            return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_CONTRACT_INVALID' -Message 'Estado por arquivo sem file/completion booleano válido.' -ExitCode $exitCode)
        }
    }
    foreach ($finding in $gateObject.findings) {
        if ($null -eq $finding.PSObject.Properties['file'] -or $finding.file -isnot [string] -or
            $null -eq $finding.PSObject.Properties['code'] -or $finding.code -isnot [string] -or
            $null -eq $finding.PSObject.Properties['unitHash'] -or [string]$finding.unitHash -notmatch '^[0-9a-f]{64}$' -or
            $null -eq $finding.PSObject.Properties['listedMembers'] -or $finding.listedMembers -isnot [array]) {
            return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_CONTRACT_INVALID' -Message 'Achado sem file/code/unitHash/listedMembers válidos.' -ExitCode $exitCode)
        }
    }
    if ($gateObject.candidateCount -isnot [int] -and $gateObject.candidateCount -isnot [long]) {
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_CONTRACT_INVALID' -Message 'candidateCount deve ser um inteiro JSON não negativo.' -ExitCode $exitCode)
    }
    if ($gateObject.candidateCount -lt 0) {
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_CONTRACT_INVALID' -Message 'candidateCount deve ser um inteiro JSON não negativo.' -ExitCode $exitCode)
    }
    if ($gateObject.candidateCount -ne @($gateObject.findings).Count) {
        return (New-EnumerationGateFailure -ScriptRel $ScriptRel -Code 'GATE_CONTRACT_INVALID' -Message 'candidateCount não corresponde à coleta integral em findings.' -ExitCode $exitCode)
    }

    $gateObject | Add-Member -NotePropertyName 'invocationExitCode' -NotePropertyValue $exitCode -Force
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        $gateObject.scanIssues = @($gateObject.scanIssues) + [pscustomobject][ordered]@{
            code = 'GATE_STDERR_NONEMPTY'
            path = $ScriptRel
            message = $stderr.Trim()
        }
        $gateObject.scanComplete = $false
        $gateObject.status = 'warn'
    }
    return $gateObject
}

function Test-StringArray {
    param($Value)
    if ($Value -isnot [array]) { return $false }
    foreach ($item in $Value) { if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) { return $false } }
    return $true
}

function Test-OrdinalMemberSetEqual {
    param([string[]]$Left, [string[]]$Right)
    if ($Left.Count -ne $Right.Count) { return $false }
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($item in $Left) { [void]$set.Add($item) }
    foreach ($item in $Right) { if (-not $set.Remove($item)) { return $false } }
    return ($set.Count -eq 0)
}

function Get-EnumerationAnchorKey {
    param([string]$Code, [string]$File, [string]$UnitHash)
    return ("{0}`0{1}`0{2}" -f $Code, $File, $UnitHash)
}

function Read-EnumerationTriageCatalog {
    $catalogPath = Join-Path $resolvedRoot 'scripts/PrePushEnumerationTriage.json'
    $problems = [System.Collections.Generic.List[object]]::new()
    $entries = [System.Collections.Generic.List[object]]::new()
    $valid = $true
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        $valid = $false
        $problems.Add([pscustomobject][ordered]@{ code = 'TRIAGE_CATALOG_MISSING'; path = 'scripts/PrePushEnumerationTriage.json'; message = 'Cadastro ausente; nenhuma triagem pode ser aplicada.' })
        return [pscustomobject]@{ path = 'scripts/PrePushEnumerationTriage.json'; valid = $false; entries = @(); problems = @($problems); duplicateKeys = @() }
    }
    try {
        $catalog = [System.IO.File]::ReadAllText($catalogPath, [System.Text.UTF8Encoding]::new($false, $true)) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        $valid = $false
        $problems.Add([pscustomobject][ordered]@{ code = 'TRIAGE_CATALOG_INVALID_JSON'; path = 'scripts/PrePushEnumerationTriage.json'; message = $_.Exception.Message })
        return [pscustomobject]@{ path = 'scripts/PrePushEnumerationTriage.json'; valid = $false; entries = @(); problems = @($problems); duplicateKeys = @() }
    }
    if ($null -eq $catalog.PSObject.Properties['schemaVersion'] -or [int]$catalog.schemaVersion -ne 1 -or
        $null -eq $catalog.PSObject.Properties['entries'] -or $catalog.entries -isnot [array]) {
        $valid = $false
        $problems.Add([pscustomobject][ordered]@{ code = 'TRIAGE_CATALOG_SCHEMA_INVALID'; path = 'scripts/PrePushEnumerationTriage.json'; message = 'Esperados schemaVersion=1 e entries como array.' })
        return [pscustomobject]@{ path = 'scripts/PrePushEnumerationTriage.json'; valid = $false; entries = @(); problems = @($problems); duplicateKeys = @() }
    }

    $seen = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::Ordinal)
    $duplicateKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $catalog.entries) {
        $code = [string](Get-PropOrDefault $entry 'code' '')
        $file = [string](Get-PropOrDefault $entry 'file' '')
        $unitHash = [string](Get-PropOrDefault $entry 'unitHash' '')
        $listedMembers = Get-PropOrDefault $entry 'listedMembers' $null
        $kind = [string](Get-PropOrDefault $entry 'kind' '')
        $canonicalMembers = Get-PropOrDefault $entry 'canonicalMembers' $null
        $entryValid = ($code -in @('BACKEND_ENUMERATION_SUBSET', 'GATE_ENUMERATION_SUBSET')) -and
            ($file -match '^(?!/)(?!.*(?:^|/)\.\.(?:/|$))[^\\]+(?:/[^\\]+)*$') -and
            ($unitHash -match '^[0-9a-f]{64}$') -and
            (Test-StringArray $listedMembers) -and
            ([string](Get-PropOrDefault $entry 'verdict' '') -eq 'non-gap') -and
            (-not [string]::IsNullOrWhiteSpace([string](Get-PropOrDefault $entry 'reason' ''))) -and
            (-not [string]::IsNullOrWhiteSpace([string](Get-PropOrDefault $entry 'triagedAt' ''))) -and
            (-not [string]::IsNullOrWhiteSpace([string](Get-PropOrDefault $entry 'triagedBy' ''))) -and
            ($kind -in @('closed', 'live-contract')) -and
            ($null -ne $entry.PSObject.Properties['excerpt'] -and $entry.excerpt -is [string])
        if ($kind -eq 'live-contract' -and -not (Test-StringArray $canonicalMembers)) { $entryValid = $false }
        if (-not $entryValid) {
            $valid = $false
            $problems.Add([pscustomobject][ordered]@{ code = 'TRIAGE_ENTRY_INVALID'; path = 'scripts/PrePushEnumerationTriage.json'; message = 'Uma entrada não cumpre o contrato de âncora, campos ou listas.' })
            continue
        }
        $entries.Add($entry)
        $key = Get-EnumerationAnchorKey -Code $code -File $file -UnitHash $unitHash
        if ($seen.ContainsKey($key)) {
            [void]$duplicateKeys.Add($key)
            $problems.Add([pscustomobject][ordered]@{ code = 'TRIAGE_ENTRY_DUPLICATE'; path = $file; message = ("Âncora duplicada no cadastro: {0}." -f $code) })
        } else { $seen[$key] = 1 }
    }
    return [pscustomobject]@{ path = 'scripts/PrePushEnumerationTriage.json'; valid = $valid; entries = @($entries); problems = @($problems); duplicateKeys = @($duplicateKeys) }
}

function Invoke-EnumerationTriage {
    param($GateEnum, $BackendEnum)
    $catalog = Read-EnumerationTriageCatalog
    $catalogProblems = [System.Collections.Generic.List[object]]::new()
    foreach ($problem in $catalog.problems) { $catalogProblems.Add($problem) }
    $scanIssues = [System.Collections.Generic.List[object]]::new()
    foreach ($gate in @($GateEnum, $BackendEnum)) { foreach ($issue in @($gate.scanIssues)) { $scanIssues.Add($issue) } }
    $new = [System.Collections.Generic.List[object]]::new()
    $triaged = [System.Collections.Generic.List[object]]::new()
    $expired = [System.Collections.Generic.List[object]]::new()
    $ambiguous = [System.Collections.Generic.List[object]]::new()
    $orphaned = [System.Collections.Generic.List[object]]::new()
    $usedEntryKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $presentAnchorKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $entriesByKey = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in $catalog.entries) {
        $key = Get-EnumerationAnchorKey -Code $entry.code -File $entry.file -UnitHash $entry.unitHash
        if (-not $entriesByKey.ContainsKey($key)) { $entriesByKey[$key] = $entry }
    }
    $duplicateSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($key in $catalog.duplicateKeys) { [void]$duplicateSet.Add([string]$key) }

    foreach ($gate in @($GateEnum, $BackendEnum)) {
        $members = @($gate.canonicalMembers | ForEach-Object { [string]$_ })
        $fileStates = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        foreach ($state in @($gate.files)) { $fileStates[[string]$state.file] = $state }
        $candidateGroups = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::Ordinal)
        foreach ($finding in @($gate.findings)) {
            $key = Get-EnumerationAnchorKey -Code ([string]$finding.code) -File ([string]$finding.file) -UnitHash ([string]$finding.unitHash)
            [void]$presentAnchorKeys.Add($key)
            if (-not $candidateGroups.ContainsKey($key)) { $candidateGroups[$key] = [System.Collections.Generic.List[object]]::new() }
            $candidateGroups[$key].Add($finding)
        }
        foreach ($key in $candidateGroups.Keys) {
            $candidateList = $candidateGroups[$key]
            foreach ($candidate in $candidateList) {
                $fileComplete = $false
                if ($fileStates.ContainsKey([string]$candidate.file)) { $fileComplete = [bool]$fileStates[[string]$candidate.file].complete }
                $view = [ordered]@{
                    code = [string]$candidate.code
                    file = [string]$candidate.file
                    line = [int](Get-PropOrDefault $candidate 'line' 0)
                    path = [string](Get-PropOrDefault $candidate 'path' $candidate.file)
                    unitHash = [string]$candidate.unitHash
                    listedMembers = @($candidate.listedMembers)
                    message = [string](Get-PropOrDefault $candidate 'message' '')
                    classification = 'new'
                    reason = ''
                    kind = $null
                }
                if ($candidateList.Count -gt 1) {
                    $view.classification = 'ambiguous'
                    $view.reason = 'A mesma âncora ocorre mais de uma vez no arquivo; a triagem não foi reutilizada.'
                    $ambiguous.Add([pscustomobject]$view)
                    [void]$usedEntryKeys.Add($key)
                    continue
                }
                if (-not $fileComplete) {
                    $view.reason = 'O arquivo não foi processado integralmente; confirmar a ocorrência manualmente.'
                    $new.Add([pscustomobject]$view)
                    continue
                }
                if (-not $catalog.valid) {
                    $view.reason = 'Cadastro ausente ou inválido; candidatos permanecem novos.'
                    $new.Add([pscustomobject]$view)
                    continue
                }
                if ($duplicateSet.Contains($key)) {
                    $view.reason = 'Âncora duplicada no cadastro; triagem afetada não foi reutilizada.'
                    $new.Add([pscustomobject]$view)
                    continue
                }
                if (-not $entriesByKey.ContainsKey($key)) {
                    $view.reason = 'Sem triagem vigente para esta âncora.'
                    $new.Add([pscustomobject]$view)
                    continue
                }
                $entry = $entriesByKey[$key]
                if ($entry.kind -eq 'live-contract' -and -not (Test-OrdinalMemberSetEqual -Left @($entry.canonicalMembers) -Right $members)) {
                    $view.reason = 'Contrato vivo expirou porque o conjunto canônico mudou.'
                    $view.classification = 'expired'
                    $expired.Add([pscustomobject]@{ entry = $entry; reason = $view.reason })
                    $newView = [ordered]@{}
                    foreach ($viewKey in $view.Keys) { $newView[$viewKey] = $view[$viewKey] }
                    $newView.classification = 'new'
                    $newView.reason = 'Triagem de contrato vivo expirada; confirmar novamente.'
                    $new.Add([pscustomobject]$newView)
                    [void]$usedEntryKeys.Add($key)
                    continue
                }
                if (-not (Test-OrdinalMemberSetEqual -Left @($entry.listedMembers) -Right @($candidate.listedMembers))) {
                    $view.reason = 'Os membros reconhecidos diferem do cadastro; confirmar como ocorrência nova.'
                    $new.Add([pscustomobject]$view)
                    continue
                }
                $view.classification = 'triaged'
                $view.reason = [string]$entry.reason
                $view.kind = [string]$entry.kind
                $triaged.Add([pscustomobject]$view)
                [void]$usedEntryKeys.Add($key)
            }
        }
    }

    $bothScansComplete = ([bool]$GateEnum.scanComplete -and [bool]$BackendEnum.scanComplete)
    $catalogNoDuplicates = ($catalog.duplicateKeys.Count -eq 0)
    if ($catalog.valid -and $catalogNoDuplicates -and $bothScansComplete) {
        foreach ($entry in $catalog.entries) {
            $key = Get-EnumerationAnchorKey -Code $entry.code -File $entry.file -UnitHash $entry.unitHash
            if ($usedEntryKeys.Contains($key) -or $presentAnchorKeys.Contains($key)) { continue }
            if ($entry.kind -eq 'live-contract') {
                $currentMembers = @()
                if ($entry.code -eq 'BACKEND_ENUMERATION_SUBSET') { $currentMembers = @($BackendEnum.canonicalMembers) }
                if ($entry.code -eq 'GATE_ENUMERATION_SUBSET') { $currentMembers = @($GateEnum.canonicalMembers) }
                if (-not (Test-OrdinalMemberSetEqual -Left @($entry.canonicalMembers) -Right $currentMembers)) {
                    $expired.Add([pscustomobject]@{ entry = $entry; reason = 'Contrato vivo expirou porque o conjunto canônico mudou.' })
                    continue
                }
            }
            $orphaned.Add([pscustomobject]@{ entry = $entry; reason = 'Nenhuma ocorrência com esta âncora foi encontrada em varredura completa.' })
        }
    }

    $limit = 50
    $projection = [ordered]@{
        status = if ($bothScansComplete) { 'complete' } else { 'incomplete' }
        scanComplete = $bothScansComplete
        scanIssues = @($scanIssues)
        catalog = [ordered]@{ path = $catalog.path; valid = $catalog.valid; problems = @($catalogProblems) }
        counts = [ordered]@{ new = $new.Count; triaged = $triaged.Count; expired = $expired.Count; orphaned = $orphaned.Count; ambiguous = $ambiguous.Count }
        displayLimitPerGroup = $limit
        newFindings = @($new | Select-Object -First $limit)
        triagedFindings = @($triaged | Select-Object -First $limit)
        expiredEntries = @($expired | Select-Object -First $limit)
        orphanedEntries = @($orphaned | Select-Object -First $limit)
        ambiguousFindings = @($ambiguous | Select-Object -First $limit)
        displayTruncated = (($new.Count -gt $limit) -or ($triaged.Count -gt $limit) -or ($expired.Count -gt $limit) -or ($orphaned.Count -gt $limit) -or ($ambiguous.Count -gt $limit) -or ($catalogProblems.Count -gt $limit))
        displayTruncatedCount = [Math]::Max(0, $new.Count - $limit) + [Math]::Max(0, $triaged.Count - $limit) + [Math]::Max(0, $expired.Count - $limit) + [Math]::Max(0, $orphaned.Count - $limit) + [Math]::Max(0, $ambiguous.Count - $limit) + [Math]::Max(0, $catalogProblems.Count - $limit)
    }
    return [pscustomobject]$projection
}

$gateEnumParityScript = Join-Path $PSScriptRoot 'Test-PrePushGateEnumerationParity.ps1'
$gateEnumParityGate = Invoke-EnumerationGate -ScriptRel 'scripts/Test-PrePushGateEnumerationParity.ps1'
$gateEnumParityGate | Add-Member -NotePropertyName 'script' -NotePropertyValue 'scripts/Test-PrePushGateEnumerationParity.ps1' -Force

$backendEnumParityScript = Join-Path $PSScriptRoot 'Test-PrePushBackendEnumerationParity.ps1'
$backendEnumParityGate = Invoke-EnumerationGate -ScriptRel 'scripts/Test-PrePushBackendEnumerationParity.ps1'
$backendEnumParityGate | Add-Member -NotePropertyName 'script' -NotePropertyValue 'scripts/Test-PrePushBackendEnumerationParity.ps1' -Force

$enumerationTriage = Invoke-EnumerationTriage -GateEnum $gateEnumParityGate -BackendEnum $backendEnumParityGate

$overallStatus = if ($mechanicalFailures.Count -eq 0) { 'pass' } else { 'fail' }

$pushReadiness = if ($commitsBehind -gt 0) { 'blocked' } else { 'ok' }
$intervalDiffDiagnosticOnly = ($commitsBehind -gt 0)

$agentOperationalReminders = @(
    'Antes da rotina, git fetch origin quando origin/main deve refletir o remoto atual; ref inexistente e ref desatualizada sao casos distintos; sem fetch, commitsBehind pode ficar 0 com remoto real ja adiantado.',
    'Parse (Test-PsScriptsParse.ps1) varre todo scripts/, scripts-maintenance/ e *.example.ps1 fora de historico/, nao apenas o diff do intervalo.',
    'Parse Python (Test-PyScriptsParse.ps1) usa AST e nao gera __pycache__/*.pyc.',
    'Com commitsAhead=0 nao ha diff no intervalo; pre-push nao substitui revisao de alteracoes so na working tree (ver avisos de worktree).',
    'exit 0 mecanico nao autoriza push: ler PUSH_READINESS; com blocked, integrar remoto antes do push.',
    'Com PUSH_READINESS=blocked, diff/arquivos do intervalo sao diagnosticos; fase semantica sobre commits locais continua obrigatoria.',
    'Com SKILL.md no diff, abrir satelites referenciados no proprio SKILL (quality-checklist, wwp-packaging, responsibilities-by-type) para regra em camadas.'
)

$agentWarnings = [System.Collections.Generic.List[string]]::new()
$skillMdInDiff = @($changedFiles | Where-Object { $_ -match '/SKILL\.md$' })
if ($skillMdInDiff.Count -gt 0) {
    $skillSummary = if ($skillMdInDiff.Count -le 3) {
        ($skillMdInDiff -join ', ')
    } else {
        ('{0} (+{1} mais)' -f $skillMdInDiff[0], ($skillMdInDiff.Count - 1))
    }
    [void]$agentWarnings.Add(
        ("SKILL.md alterado no intervalo ({0}): verificar satelites referenciados no proprio arquivo (ex. quality-checklist.md, wwp-packaging.md, responsibilities-by-type/) para regra em camadas." -f $skillSummary)
    )
}
$publicTraceabilityTriggers = [System.Collections.Generic.List[string]]::new()
foreach ($changedPath in @($changedFiles)) {
    $normalizedChangedPath = ($changedPath -replace '\\', '/').Trim()
    if ($normalizedChangedPath -match '^scripts/.+\.(ps1|py|json)$' -or
        $normalizedChangedPath -match '^scripts-maintenance/.+\.ps1$' -or
        $normalizedChangedPath -match '^xpz-[^/]+/SKILL\.md$' -or
        $normalizedChangedPath -match '^xpz-[^/]+/(quality-checklist|wwp-packaging)\.md$' -or
        $normalizedChangedPath -match '^xpz-[^/]+/responsibilities-by-type/.+\.md$' -or
        $normalizedChangedPath -in @('README.md', '02-regras-operacionais-e-runtime.md', '08-guia-para-agente-gpt.md', '10-base-operacional-msbuild-headless.md')) {
        $publicTraceabilityTriggers.Add($normalizedChangedPath)
    }
}
if ($publicTraceabilityTriggers.Count -gt 0) {
    $traceabilitySummary = if ($publicTraceabilityTriggers.Count -le 4) {
        ($publicTraceabilityTriggers -join ', ')
    } else {
        ('{0}, {1}, {2}, {3} (+{4} mais)' -f $publicTraceabilityTriggers[0], $publicTraceabilityTriggers[1], $publicTraceabilityTriggers[2], $publicTraceabilityTriggers[3], ($publicTraceabilityTriggers.Count - 4))
    }
    [void]$agentWarnings.Add(
        ("Mudanca metodologica ou de motor compartilhado detectada ({0}): avaliar explicitamente se 09-inventario-e-rastreabilidade-publica.md precisa registrar a evolucao; presenca de termo no 09 nao basta, comparar se a descricao reflete a abrangencia atual." -f $traceabilitySummary)
    )
}
if (-not $onExpectedBranch) {
    [void]$agentWarnings.Add(
        ("Branch atual e '{0}'; este repositorio espera trabalho direto em {1}." -f $currentBranch, $expectedBranch)
    )
}
if ($workingTree.Status -ne 'clean') {
    [void]$agentWarnings.Add(
        ("Working tree fora do intervalo de commits: {0} arquivo(s) rastreado(s) modificado(s) sem commit e {1} nao rastreado(s); a pre-push nao analisa essas alteracoes em BaseRef..HEAD." -f $workingTree.DirtyTrackedCount, $workingTree.UntrackedCount)
    )
}
if ($commitsBehind -gt 0) {
    [void]$agentWarnings.Add(
        ("Remoto ({0}) esta {1} commit(s) a frente de HEAD: intervalo {2} e arquivos listados sao apenas diagnosticos; push bloqueado ate integrar. Se ainda nao houve fetch, git fetch origin; se commitsBehind persistir, integrar (ex.: git pull --rebase origin main) antes do push." -f $effectiveBaseRef, $commitsBehind, $range)
    )
}
foreach ($traceabilityFinding in @($traceabilityCoverageGate.findings)) {
    [void]$agentWarnings.Add(
        ("Cobertura de rastreabilidade consultiva ({0}): {1}" -f $traceabilityFinding.code, $traceabilityFinding.message)
    )
}
foreach ($msBuildParityFinding in @($msBuildProbeDocParityGate.findings)) {
    $prefix = if ($msBuildParityFinding.severity -eq 'fail') { 'Paridade MSBuild probe (bloqueio mecanico)' } else { 'Paridade MSBuild probe (aviso)' }
    [void]$agentWarnings.Add(
        ("{0} ({1}): {2}" -f $prefix, $msBuildParityFinding.code, $msBuildParityFinding.message)
    )
}
foreach ($unexpectedCharFinding in @($unexpectedCharGate.findings)) {
    [void]$agentWarnings.Add(
        ("Caractere inesperado ({0}): {1}" -f $unexpectedCharFinding.code, $unexpectedCharFinding.message)
    )
}
if ($newTokenPropagationGate.truncated) {
    [void]$agentWarnings.Add(
        ("Propagacao de termo novo: {0} candidata(s) de classe 'prose' foram DESCARTADAS pelo teto -MaxFindings e nao aparecem nas candidatas listadas; as nao-prosa nunca truncam. Ruido alto de prosa pode diluir uma candidata legitima — conferir os pares em pairsConsidered antes de tratar a lista como exaustiva." -f $newTokenPropagationGate.truncatedProseCount)
    )
}
foreach ($newTokenFinding in @($newTokenPropagationGate.findings)) {
    [void]$agentWarnings.Add(
        ("Propagacao de termo novo (candidata consultiva) ({0}): {1} [{2}]" -f $newTokenFinding.code, $newTokenFinding.message, $newTokenFinding.path)
    )
}
foreach ($sharedScriptFinding in @($sharedScriptSkillGate.findings)) {
    [void]$agentWarnings.Add(
        ("Script compartilhado em skill transversal (candidata consultiva) ({0}): {1} [{2}]" -f $sharedScriptFinding.code, $sharedScriptFinding.message, $sharedScriptFinding.path)
    )
}
foreach ($historyCommitFinding in @($historyCommitGate.findings)) {
    [void]$agentWarnings.Add(
        ("Placeholder de rastreabilidade em historico (candidata consultiva) ({0}): {1} [{2}]" -f $historyCommitFinding.code, $historyCommitFinding.message, $historyCommitFinding.path)
    )
}
foreach ($reviewerRoDriftFinding in @($reviewerRoDriftGate.findings)) {
    [void]$agentWarnings.Add(
        ("Deriva do reviewer-ro global (aviso consultivo) ({0}): {1} [{2}]" -f $reviewerRoDriftFinding.code, $reviewerRoDriftFinding.message, $reviewerRoDriftFinding.path)
    )
}
if (-not $enumerationTriage.scanComplete) {
    [void]$agentWarnings.Add(
        ("Triagem de enumerações incompleta: {0} questão(ões) de varredura; não considerar ausências de órfãos como resultado. Ver enumerationTriage.scanIssues." -f @($enumerationTriage.scanIssues).Count)
    )
}
foreach ($problem in @($enumerationTriage.catalog.problems)) {
    [void]$agentWarnings.Add(
        ("Cadastro de triagem ({0}): {1} [{2}]" -f $problem.code, $problem.message, $problem.path)
    )
}
foreach ($finding in @($enumerationTriage.newFindings)) {
    [void]$agentWarnings.Add(
        ("NOVA enumeração para veredito semântico ({0}): {1} — {2}; âncora={3}|{4}|{5}" -f $finding.code, $finding.message, $finding.reason, $finding.file, $finding.code, $finding.unitHash)
    )
}
foreach ($finding in @($enumerationTriage.triagedFindings)) {
    [void]$agentWarnings.Add(
        ("Enumeração triada ({0}): {1}; motivo: {2}; âncora={3}|{4}|{5}" -f $finding.code, $finding.path, $finding.reason, $finding.file, $finding.code, $finding.unitHash)
    )
}
foreach ($entry in @($enumerationTriage.expiredEntries)) {
    [void]$agentWarnings.Add(
        ("Triagem expirada ({0}): {1}; motivo: {2}" -f $entry.entry.code, $entry.entry.file, $entry.reason)
    )
}
foreach ($entry in @($enumerationTriage.orphanedEntries)) {
    [void]$agentWarnings.Add(
        ("Triagem órfã ({0}): {1}; motivo: {2}" -f $entry.entry.code, $entry.entry.file, $entry.reason)
    )
}
foreach ($finding in @($enumerationTriage.ambiguousFindings)) {
    [void]$agentWarnings.Add(
        ("Enumeração ambígua ({0}): {1}; motivo: {2}" -f $finding.code, $finding.path, $finding.reason)
    )
}
if ($enumerationTriage.displayTruncated) {
    [void]$agentWarnings.Add(
        ("Triagem de enumerações: {0} item(ns) ficaram fora dos limites de apresentação por grupo; as contagens totais estão em enumerationTriage.counts." -f $enumerationTriage.displayTruncatedCount)
    )
}

# Segregacao das candidatas NAO-PROSA do gate de propagacao: são as que não
# admitem justificativa coletiva (13: disciplina de confronto por classe) e
# exigem veredito item a item. Bloco proeminente para o revisor não as diluir
# entre os demais avisos.
$nonProseVerdictRequired = [System.Collections.Generic.List[object]]::new()
foreach ($ntFinding in @($newTokenPropagationGate.findings)) {
    $ntClass = if ($ntFinding.PSObject.Properties.Name -contains 'mentionClass') { [string]$ntFinding.mentionClass } else { '' }
    if ($ntClass -ne '' -and $ntClass -ne 'prose') {
        [void]$nonProseVerdictRequired.Add([pscustomobject][ordered]@{
            path         = $ntFinding.path
            mentionClass = $ntClass
            message      = $ntFinding.message
        })
    }
}
$nonProseModelDiversityThreshold = 5

$agentSemanticChecklist = [System.Collections.Generic.List[string]]::new()
[void]$agentSemanticChecklist.Add('Fase semantica: seguir integralmente 13-revisao-pre-push.md na raiz (fonte autoritativa; AGENTS.md resume).')
[void]$agentSemanticChecklist.Add('Nao tratar exit 0 deste passo mecanico como pre-push concluida.')
[void]$agentSemanticChecklist.Add('Eixos vizinhos: aplicar a regra do 13 §5 e registrar no relatório os caminhos examinados, as evidências e o resultado por eixo; quando não se aplicar, indicar isso sucintamente.')
[void]$agentSemanticChecklist.Add('Enumerações consultivas: examinar primeiro enumerationTriage.newFindings; conferir triadas e seus motivos em triagedFindings. Marcador permanente e triagem versionada são mecanismos distintos.')
if (-not $enumerationTriage.scanComplete) {
    [void]$agentSemanticChecklist.Add('Enumerações: varredura incompleta; não declarar triagens órfãs. Conferir enumerationTriage.scanIssues e tratar ausências como não demonstradas.')
}
if ($nonProseVerdictRequired.Count -gt 0) {
    [void]$agentSemanticChecklist.Add(
        ("{0} candidata(s) NAO-PROSA do gate de propagacao exigem VEREDITO INDIVIDUAL (livro-razao item a item: cada uma com arquivo:linha, a lista/tabela/exemplo gemeo no outro documento e veredito gap|justificado). Proibida justificativa coletiva. Lista completa em nonProseVerdictRequired." -f $nonProseVerdictRequired.Count)
    )
    if ($nonProseVerdictRequired.Count -gt $nonProseModelDiversityThreshold) {
        [void]$agentSemanticChecklist.Add(
            ("Mais de {0} candidatas nao-prosa: recomenda-se uma segunda passada da fase semantica por MODELO DISTINTO antes de fechar o veredito (13: salvaguarda de diversidade de modelo) — um unico modelo tende a satisficar e confrontar so as candidatas salientes." -f $nonProseModelDiversityThreshold)
        )
    }
}

$result = [ordered]@{
    status                      = $overallStatus
    pushReadiness               = $pushReadiness
    intervalDiffDiagnosticOnly  = $intervalDiffDiagnosticOnly
    rootPath                    = $resolvedRoot
    git                    = [ordered]@{
        repositoryRoot      = $resolvedRoot
        gitDir              = $resolvedGitDir
        branch              = $currentBranch
        expectedBranch      = $expectedBranch
        onExpectedBranch    = $onExpectedBranch
        workingTree         = [ordered]@{
            status                = $workingTree.Status
            untrackedCount        = $workingTree.UntrackedCount
            dirtyTrackedCount     = $workingTree.DirtyTrackedCount
            untrackedFiles        = @($workingTree.UntrackedFiles)
            dirtyTrackedFiles     = @($workingTree.DirtyTrackedFiles)
            untrackedTruncated    = $workingTree.UntrackedTruncated
            dirtyTrackedTruncated = $workingTree.DirtyTrackedTruncated
        }
        upstream            = $upstreamRef
        baseRef             = $effectiveBaseRef
        range               = $range
        commitsAhead        = $commitsAhead
        commitsBehind       = $commitsBehind
        pendingCommits      = @($pendingCommits)
        changedFiles        = @($changedFiles)
        changedFilesByKind  = $changedFilesByKind
        whitespaceCheck     = $whitespaceStatus
        whitespaceIssues    = @($whitespaceIssues)
    }
    gates                  = [ordered]@{
        parse                = $parseGate
        pythonParse          = $pythonParseGate
        traceabilityCoverage = $traceabilityCoverageGate
        msBuildProbeDocParity = $msBuildProbeDocParityGate
        unexpectedChar       = $unexpectedCharGate
        newTokenPropagation  = $newTokenPropagationGate
        sharedScriptSkillCoverage = $sharedScriptSkillGate
        historyCommitPlaceholder = $historyCommitGate
        openCodeReviewerRoDrift = $reviewerRoDriftGate
        gateEnumerationParity = $gateEnumParityGate
        backendEnumerationParity = $backendEnumParityGate
    }
    mechanicalFailures       = @($mechanicalFailures)
    enumerationTriage        = $enumerationTriage
    agentOperationalReminders = @($agentOperationalReminders)
    agentWarnings             = @($agentWarnings)
    agentSemanticChecklist   = @($agentSemanticChecklist)
    nonProseVerdictRequired  = @($nonProseVerdictRequired)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("STATUS={0}" -f $overallStatus)
    Write-Output ("BRANCH={0} INTERVALO_BASE={1} UPSTREAM_INFORMATIVO={2}" -f $currentBranch, $effectiveBaseRef, $(if ($upstreamRef) { $upstreamRef } else { '(nao configurado)' }))
    Write-Output ("ON_EXPECTED_BRANCH={0} EXPECTED_BRANCH={1}" -f $(if ($onExpectedBranch) { 'true' } else { 'false' }), $expectedBranch)
    Write-Output ("WORKING_TREE={0} UNTRACKED={1} DIRTY_TRACKED={2}" -f $workingTree.Status, $workingTree.UntrackedCount, $workingTree.DirtyTrackedCount)
    foreach ($warning in @($agentWarnings)) {
        Write-Output ("AVISO: {0}" -f $warning)
    }
    if ($nonProseVerdictRequired.Count -gt 0) {
        Write-Output ("NAO_PROSA_VEREDITO_INDIVIDUAL ({0}):" -f $nonProseVerdictRequired.Count)
        foreach ($np in @($nonProseVerdictRequired)) {
            Write-Output ("  - [{0}] {1} [{2}]" -f $np.mentionClass, $np.message, $np.path)
        }
    }
    foreach ($path in @($workingTree.UntrackedFiles)) {
        Write-Output ("WORKING_TREE_UNTRACKED: {0}" -f $path)
    }
    foreach ($path in @($workingTree.DirtyTrackedFiles)) {
        Write-Output ("WORKING_TREE_DIRTY: {0}" -f $path)
    }
    if ($workingTree.UntrackedTruncated -or $workingTree.DirtyTrackedTruncated) {
        Write-Output 'WORKING_TREE_PATHS_TRUNCATED=true'
    }
    Write-Output ("COMMITS_AHEAD={0} COMMITS_BEHIND={1}" -f $commitsAhead, $commitsBehind)
    Write-Output ("PUSH_READINESS={0}" -f $pushReadiness)
    if ($intervalDiffDiagnosticOnly) {
        Write-Output 'INTERVAL_DIFF_DIAGNOSTIC_ONLY=true'
    }
    Write-Output 'NOTA=Com origin/main existente mas desatualizada, a contagem pode nao refletir o remoto atual; git fetch origin antes da rotina quando necessario (ver AGENTS.md).'

    if ($commitsAhead -eq 0) {
        Write-Output 'PENDING_COMMITS=none'
    } else {
        foreach ($commitLine in $pendingCommits) {
            Write-Output ("PENDING_COMMIT: {0}" -f $commitLine)
        }
    }

    Write-Output ("WHITESPACE_CHECK={0}" -f $whitespaceStatus)
    foreach ($issue in $whitespaceIssues) {
        Write-Output ("WHITESPACE_ISSUE: {0}" -f $issue)
    }

    Write-Output ("PARSE_GATE={0}" -f $parseGate.status)
    if ($parseGate.status -ne 'skipped') {
        Write-Output ("PARSE_FILES={0} PARSE_ERRORS={1}" -f $parseGate.fileCount, $parseGate.errorCount)
        foreach ($finding in @($parseGate.findings)) {
            Write-Output ("PARSE_ERROR: {0}:{1}:{2}: {3}" -f $finding.file, $finding.line, $finding.column, $finding.message)
        }
    }

    Write-Output ("PYTHON_PARSE_GATE={0}" -f $pythonParseGate.status)
    if ($pythonParseGate.status -ne 'skipped') {
        Write-Output ("PYTHON_PARSE_FILES={0} PYTHON_PARSE_ERRORS={1}" -f $pythonParseGate.fileCount, $pythonParseGate.errorCount)
        foreach ($finding in @($pythonParseGate.findings)) {
            Write-Output ("PY_PARSE_ERROR: {0}:{1}:{2}: {3}" -f $finding.file, $finding.line, $finding.column, $finding.message)
        }
    }

    Write-Output ("TRACEABILITY_COVERAGE={0}" -f $traceabilityCoverageGate.status)
    foreach ($finding in @($traceabilityCoverageGate.findings)) {
        Write-Output ("TRACEABILITY_FINDING: {0}: {1}" -f $finding.code, $finding.message)
    }

    Write-Output ("MSBUILD_PROBE_DOC_PARITY_GATE={0}" -f $msBuildProbeDocParityGate.status)
    foreach ($finding in @($msBuildProbeDocParityGate.findings)) {
        Write-Output ("MSBUILD_PROBE_DOC_PARITY_FINDING: {0} [{1}]: {2}" -f $finding.code, $finding.severity, $finding.message)
    }

    Write-Output ("UNEXPECTED_CHAR_GATE={0}" -f $unexpectedCharGate.status)
    foreach ($finding in @($unexpectedCharGate.findings)) {
        Write-Output ("UNEXPECTED_CHAR_FINDING: {0}: {1}" -f $finding.code, $finding.message)
    }

    Write-Output ("NEW_TOKEN_PROPAGATION_GATE={0}" -f $newTokenPropagationGate.status)
    if ($newTokenPropagationGate.truncated) {
        Write-Output ("NEW_TOKEN_PROPAGATION_PROSE_TRUNCATED={0}" -f $newTokenPropagationGate.truncatedProseCount)
    }
    foreach ($finding in @($newTokenPropagationGate.findings)) {
        Write-Output ("NEW_TOKEN_PROPAGATION_CANDIDATE: {0}: {1}" -f $finding.path, $finding.message)
    }

    Write-Output ("SHARED_SCRIPT_SKILL_COVERAGE_GATE={0}" -f $sharedScriptSkillGate.status)
    foreach ($finding in @($sharedScriptSkillGate.findings)) {
        Write-Output ("SHARED_SCRIPT_SKILL_DOC_NOT_IN_DIFF: {0}: {1}" -f $finding.path, $finding.message)
    }

    Write-Output ("HISTORY_COMMIT_PLACEHOLDER_GATE={0}" -f $historyCommitGate.status)
    foreach ($finding in @($historyCommitGate.findings)) {
        Write-Output ("HISTORY_COMMIT_FIELD_PLACEHOLDER: {0}: {1}" -f $finding.path, $finding.message)
    }

    Write-Output ("OPENCODE_REVIEWER_RO_DRIFT_GATE={0}" -f $reviewerRoDriftGate.status)
    foreach ($finding in @($reviewerRoDriftGate.findings)) {
        Write-Output ("OPENCODE_REVIEWER_RO_CONTRACT_CHANGED: {0}: {1}" -f $finding.path, $finding.message)
    }

    Write-Output 'ENUMERATION_TRIAGE:'
    Write-Output ("  SCAN_COMPLETE={0}; CATALOG_VALID={1}" -f $enumerationTriage.scanComplete, $enumerationTriage.catalog.valid)
    Write-Output ("  COUNTS new={0} triaged={1} expired={2} orphaned={3} ambiguous={4}" -f $enumerationTriage.counts.new, $enumerationTriage.counts.triaged, $enumerationTriage.counts.expired, $enumerationTriage.counts.orphaned, $enumerationTriage.counts.ambiguous)
    Write-Output '  NEW (veredito semântico):'
    foreach ($finding in @($enumerationTriage.newFindings)) {
        Write-Output ("    - {0} [{1}] {2}; motivo: {3}" -f $finding.path, $finding.code, $finding.message, $finding.reason)
    }
    Write-Output '  TRIAGED (motivo visível):'
    foreach ($finding in @($enumerationTriage.triagedFindings)) {
        Write-Output ("    - {0} [{1}] motivo: {2}" -f $finding.path, $finding.code, $finding.reason)
    }
    Write-Output '  EXPIRED:'
    foreach ($entry in @($enumerationTriage.expiredEntries)) {
        Write-Output ("    - {0} [{1}] motivo: {2}" -f $entry.entry.file, $entry.entry.code, $entry.reason)
    }
    Write-Output '  ORPHANED:'
    foreach ($entry in @($enumerationTriage.orphanedEntries)) {
        Write-Output ("    - {0} [{1}] motivo: {2}" -f $entry.entry.file, $entry.entry.code, $entry.reason)
    }
    Write-Output '  AMBIGUOUS:'
    foreach ($finding in @($enumerationTriage.ambiguousFindings)) {
        Write-Output ("    - {0} [{1}] motivo: {2}" -f $finding.path, $finding.code, $finding.reason)
    }
    foreach ($problem in @($enumerationTriage.catalog.problems)) {
        Write-Output ("  CATALOG_PROBLEM: {0} [{1}] {2}" -f $problem.code, $problem.path, $problem.message)
    }
    foreach ($issue in @($enumerationTriage.scanIssues)) {
        Write-Output ("  SCAN_ISSUE: {0} [{1}] {2}" -f $issue.code, $issue.path, $issue.message)
    }
    if ($enumerationTriage.displayTruncated) {
        Write-Output ("  DISPLAY_TRUNCATED={0}" -f $enumerationTriage.displayTruncatedCount)
    }
    Write-Output ("GATE_ENUMERATION_PARITY_GATE={0}; SCAN_COMPLETE={1}; CANDIDATES={2}" -f $gateEnumParityGate.status, $gateEnumParityGate.scanComplete, $gateEnumParityGate.candidateCount)
    Write-Output ("BACKEND_ENUMERATION_PARITY_GATE={0}; SCAN_COMPLETE={1}; CANDIDATES={2}" -f $backendEnumParityGate.status, $backendEnumParityGate.scanComplete, $backendEnumParityGate.candidateCount)

    if ($changedFiles.Count -gt 0) {
        Write-Output 'CHANGED_FILES_BY_KIND:'
        foreach ($kind in @($changedFilesByKind.Keys)) {
            $paths = @($changedFilesByKind[$kind])
            if ($paths.Count -eq 0) {
                continue
            }
            Write-Output ("  {0}:" -f $kind)
            foreach ($path in $paths) {
                Write-Output ("    - {0}" -f $path)
            }
        }
    }

    Write-Output 'AGENT_SEMANTIC_CHECKLIST:'
    foreach ($item in $agentSemanticChecklist) {
        Write-Output ("  - {0}" -f $item)
    }
}

if ($mechanicalFailures.Count -gt 0) {
    exit 1
}

exit 0
