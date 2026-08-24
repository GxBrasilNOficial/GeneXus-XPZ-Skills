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

$gateEnumParityScript = Join-Path $PSScriptRoot 'Test-PrePushGateEnumerationParity.ps1'
if (Test-Path -LiteralPath $gateEnumParityScript -PathType Leaf) {
    $gateEnumOutput = & $gateEnumParityScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $gateEnumExitCode = $LASTEXITCODE
    $gateEnumJsonText = ($gateEnumOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $gateEnumObject = $null
    if (-not [string]::IsNullOrWhiteSpace($gateEnumJsonText)) {
        $gateEnumObject = $gateEnumJsonText | ConvertFrom-Json
    }

    if ($gateEnumExitCode -eq 0 -and $null -ne $gateEnumObject) {
        $gateEnumParityGate.status = $gateEnumObject.status
        $gateEnumParityGate.findings = @($gateEnumObject.findings)
    } else {
        $gateEnumParityGate.status = 'warn'
        $gateEnumParityGate.findings = @([pscustomobject][ordered]@{
            code     = 'GATE_ENUMERATION_PARITY_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-PrePushGateEnumerationParity.ps1'
            message  = "Falha consultiva ao executar Test-PrePushGateEnumerationParity.ps1: $gateEnumJsonText"
        })
    }
}

$backendEnumParityScript = Join-Path $PSScriptRoot 'Test-PrePushBackendEnumerationParity.ps1'
if (Test-Path -LiteralPath $backendEnumParityScript -PathType Leaf) {
    $backendEnumOutput = & $backendEnumParityScript -RootPath $resolvedRoot -BaseRef $effectiveBaseRef -ChangedFiles $changedFiles -AsJson 2>&1
    $backendEnumExitCode = $LASTEXITCODE
    $backendEnumJsonText = ($backendEnumOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    $backendEnumObject = $null
    if (-not [string]::IsNullOrWhiteSpace($backendEnumJsonText)) {
        $backendEnumObject = $backendEnumJsonText | ConvertFrom-Json
    }

    if ($backendEnumExitCode -eq 0 -and $null -ne $backendEnumObject) {
        $backendEnumParityGate.status = $backendEnumObject.status
        $backendEnumParityGate.findings = @($backendEnumObject.findings)
    } else {
        $backendEnumParityGate.status = 'warn'
        $backendEnumParityGate.findings = @([pscustomobject][ordered]@{
            code     = 'BACKEND_ENUMERATION_PARITY_SCRIPT_ERROR'
            severity = 'warn'
            path     = 'scripts/Test-PrePushBackendEnumerationParity.ps1'
            message  = "Falha consultiva ao executar Test-PrePushBackendEnumerationParity.ps1: $backendEnumJsonText"
        })
    }
}

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
foreach ($gateEnumFinding in @($gateEnumParityGate.findings)) {
    [void]$agentWarnings.Add(
        ("Enumeracao de gates defasada na doc (candidata consultiva) ({0}): {1} [{2}]" -f $gateEnumFinding.code, $gateEnumFinding.message, $gateEnumFinding.path)
    )
}
foreach ($backendEnumFinding in @($backendEnumParityGate.findings)) {
    [void]$agentWarnings.Add(
        ("Enumeracao de backends defasada na doc (candidata consultiva) ({0}): {1} [{2}]" -f $backendEnumFinding.code, $backendEnumFinding.message, $backendEnumFinding.path)
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
        gateEnumerationParity = $gateEnumParityGate
        backendEnumerationParity = $backendEnumParityGate
    }
    mechanicalFailures       = @($mechanicalFailures)
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

    Write-Output ("GATE_ENUMERATION_PARITY_GATE={0}" -f $gateEnumParityGate.status)
    foreach ($finding in @($gateEnumParityGate.findings)) {
        Write-Output ("GATE_ENUMERATION_SUBSET: {0}: {1}" -f $finding.path, $finding.message)
    }

    Write-Output ("BACKEND_ENUMERATION_PARITY_GATE={0}" -f $backendEnumParityGate.status)
    foreach ($finding in @($backendEnumParityGate.findings)) {
        Write-Output ("BACKEND_ENUMERATION_SUBSET: {0}: {1}" -f $finding.path, $finding.message)
    }

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
