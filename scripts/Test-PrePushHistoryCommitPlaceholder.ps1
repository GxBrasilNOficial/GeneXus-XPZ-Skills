#requires -Version 7.4

<#
.SYNOPSIS
    Gate consultivo: campo de rastreabilidade (Commit:/PR:) com placeholder
    genérico em arquivo de historico/ tocado pela frente.

.DESCRIPTION
    Apoio mecanico ao checklist de gaps do 13-revisao-pre-push.md. A convencao
    do repositório em `historico/IdeiasImplementadas_*.md` e registrar o campo
    `Commit:` com o hash real (ex.: `- Commit: ``9acc032`` (``mensagem``)`).
    Um placeholder genérico (`este commit`, `este PR`, `TODO`, `TBD`, vazio ou
    `<...>`) indica rastreabilidade não preenchida — gap que a busca semantica
    pode não flagar espontaneamente.

    Escopo diff: avalia apenas arquivos `historico/**.md` presentes no intervalo
    BaseRef..HEAD (o modo de falha e a frente adicionar a entrada com
    placeholder). Para cada um, le o estado atual e procura linhas de campo
    `Commit:`/`PR:` cujo valor seja placeholder.

    Consultivo: severity 'warn'; findings entram em agentWarnings. A exceção
    legitima — o commit ainda não existe e o hash sera preenchido num commit
    seguinte — e tratada pela própria natureza consultiva: o agente confronta a
    candidata e confirma "a preencher" ou corrige; o gate não reprova sozinho.

.PARAMETER RootPath
    Raiz do repositório. Default: pai de scripts/.

.PARAMETER BaseRef
    Referencia base do intervalo BaseRef..HEAD. Default: origin/main.

.PARAMETER ChangedFiles
    Arquivos alterados no intervalo. Quando vazio, calcula via git diff.

.PARAMETER MaxFindings
    Teto de candidatas reportadas. Default: 30.

.PARAMETER AsJson
    Emite diagnostico estruturado em JSON.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,

    [string]$BaseRef = 'origin/main',

    [AllowEmptyCollection()]
    [string[]]$ChangedFiles = @(),

    [ValidateRange(1, 500)]
    [int]$MaxFindings = 30,

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
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path)
    return (($Path -replace '\\', '/').Trim())
}

# Linha de campo de rastreabilidade: '- Commit: <valor>' ou 'PR: <valor>'.
$fieldRegex = [regex]::new('(?i)^\s*-?\s*(?<field>Commit|PR)\s*:\s*(?<value>.*)$')
# Valor placeholder: vazio, palavra genérica, ou marcador entre angulos.
$placeholderWordRegex = [regex]::new('(?i)\b(este\s+commit|este\s+pr|este\s+pull\s+request|todo|tbd|tba|a\s+preencher|preencher\s+depois)\b')

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path

$refCheck = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('rev-parse', '--verify', $BaseRef)
if ($refCheck.ExitCode -ne 0) {
    throw ("Ref base '{0}' nao encontrada; rode git fetch origin ou passe -BaseRef valido." -f $BaseRef)
}

$normalizedChangedFiles = @($ChangedFiles |
    ForEach-Object { Normalize-RepoPath -Path $_ } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique)
if ($normalizedChangedFiles.Count -eq 0) {
    $changedResult = Invoke-RepoGit -RepositoryRoot $resolvedRoot -Arguments @('diff', '--name-only', "$BaseRef..HEAD")
    if ($changedResult.ExitCode -ne 0) {
        throw ("Falha ao listar arquivos alterados em {0}..HEAD: {1}" -f $BaseRef, $changedResult.Text)
    }
    $normalizedChangedFiles = @($changedResult.Lines |
        ForEach-Object { Normalize-RepoPath -Path $_ } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique)
}

$historyFiles = @($normalizedChangedFiles | Where-Object { $_ -match '^historico/.+\.md$' })

$findings = [System.Collections.Generic.List[object]]::new()
$truncated = $false

function Test-IsPlaceholderValue {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)

    $trimmed = $Value.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $true }
    if ($trimmed -match '^<[^>]*>$') { return $true }
    if ($placeholderWordRegex.IsMatch($trimmed)) { return $true }
    return $false
}

foreach ($historyFile in $historyFiles) {
    if ($truncated) { break }

    $fullPath = Join-Path $resolvedRoot $historyFile
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }

    $lines = @()
    try {
        $lines = @([System.IO.File]::ReadAllLines($fullPath))
    } catch {
        continue
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($truncated) { break }
        $m = $fieldRegex.Match($lines[$i])
        if (-not $m.Success) { continue }
        if (-not (Test-IsPlaceholderValue -Value $m.Groups['value'].Value)) { continue }

        if ($findings.Count -ge $MaxFindings) {
            $truncated = $true
            break
        }

        $shown = $m.Groups['value'].Value.Trim()
        if ([string]::IsNullOrEmpty($shown)) { $shown = '(vazio)' }

        $findings.Add([pscustomobject][ordered]@{
            code     = 'HISTORY_COMMIT_FIELD_PLACEHOLDER'
            severity = 'warn'
            path     = ('{0}:{1}' -f $historyFile, ($i + 1))
            message  = ("campo '{0}:' com placeholder '{1}' — preencher com o hash real do commit, ou confirmar que sera preenchido no commit seguinte" -f $m.Groups['field'].Value, $shown)
        })
    }
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }

$result = [ordered]@{
    status            = $status
    baseRef           = $BaseRef
    historyFilesInDiff = @($historyFiles)
    candidateCount    = $findings.Count
    truncated         = $truncated
    findings          = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("HISTORY_FILES_IN_DIFF={0}" -f ($historyFiles -join ', '))
    Write-Output ("CANDIDATE_COUNT={0}" -f $findings.Count)
    foreach ($finding in @($findings)) {
        Write-Output ("HISTORY_COMMIT_FIELD_PLACEHOLDER: {0}: {1}" -f $finding.path, $finding.message)
    }
    if ($truncated) {
        Write-Output 'CANDIDATES_TRUNCATED=true'
    }
}

exit 0
