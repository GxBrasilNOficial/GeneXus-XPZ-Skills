#requires -Version 7.4

<#
.SYNOPSIS
    Gate consultivo: script compartilhado alterado no diff cujo contrato e
    documentado em SKILL.md / quality-checklist.md que NÃO foi tocado.

.DESCRIPTION
    Apoio mecanico a "Comparacao documental" do 13-revisao-pre-push.md para o
    caso de skill transversal: um wrapper/motor/helper compartilhado costuma ser
    documentado em mais de uma skill (a dona e skills que o consomem). Quando a
    frente altera o script mas mexe só na skill dona (ou em nenhuma), as outras
    skills que descrevem o contrato/parametros/checklist do mesmo script podem
    ficar defasadas sem aparecer no diff.

    Para cada script compartilhado (scripts/*.ps1 ou *.py) no intervalo
    BaseRef..HEAD, procura o nome base do script (como palavra) em todos os
    SKILL.md e quality-checklist.md do repositório (fora de historico/). Cada
    documento que cita o script e NÃO está no diff vira CANDIDATA a comparacao
    documental.

    Consultivo: severity 'warn'; findings entram em agentWarnings e a fase
    semantica confronta cada candidata (atualizar contrato/checklist ou
    justificar que a mudanca não afeta aquela skill). Não prova alinhamento nem
    reprova sozinho.

.PARAMETER RootPath
    Raiz do repositório. Default: pai de scripts/.

.PARAMETER BaseRef
    Referencia base do intervalo BaseRef..HEAD. Default: origin/main.

.PARAMETER ChangedFiles
    Arquivos alterados no intervalo. Quando vazio, o gate calcula via git diff
    BaseRef..HEAD.

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

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path

# Confirma que a ref base existe (sem fallback automático).
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

$changedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($cf in $normalizedChangedFiles) { [void]$changedSet.Add($cf) }

# Scripts compartilhados alterados no intervalo.
$changedScripts = @($normalizedChangedFiles | Where-Object { $_ -match '^scripts/[^/]+\.(ps1|py)$' })

$findings = [System.Collections.Generic.List[object]]::new()
$truncated = $false

if ($changedScripts.Count -gt 0) {
    # Documentos-alvo: SKILL.md e quality-checklist.md, fora de historico/ e .git/.
    $docFiles = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.Name -eq 'SKILL.md' -or $_.Name -eq 'quality-checklist.md') -and
            $_.FullName -notmatch '[\\/](\.git|historico)[\\/]'
        })

    # Pre-le cada doc uma vez (texto completo + linhas).
    $docCache = [System.Collections.Generic.List[object]]::new()
    foreach ($docFile in $docFiles) {
        $relDoc = Normalize-RepoPath -Path ([System.IO.Path]::GetRelativePath($resolvedRoot, $docFile.FullName))
        $lines = @()
        try {
            $lines = @([System.IO.File]::ReadAllLines($docFile.FullName))
        } catch {
            continue
        }
        $docCache.Add([pscustomobject]@{
            RelPath = $relDoc
            Lines   = $lines
            InDiff  = $changedSet.Contains($relDoc)
        })
    }

    foreach ($scriptPath in $changedScripts) {
        if ($truncated) { break }

        $baseName = Split-Path -Leaf $scriptPath
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
        # Nome do script como palavra: '-' não e caractere de palavra, entao o
        # sufixo de extensao (.ps1/.py) ou borda de texto delimitam corretamente.
        $stemRegex = [regex]::new('(?<![A-Za-z0-9_])' + [regex]::Escape($stem) + '(?![A-Za-z0-9_])')

        foreach ($doc in $docCache) {
            if ($truncated) { break }
            if ($doc.InDiff) { continue }

            $firstLine = 0
            for ($i = 0; $i -lt $doc.Lines.Count; $i++) {
                if ($stemRegex.IsMatch($doc.Lines[$i])) {
                    $firstLine = $i + 1
                    break
                }
            }
            if ($firstLine -eq 0) { continue }

            if ($findings.Count -ge $MaxFindings) {
                $truncated = $true
                break
            }

            $findings.Add([pscustomobject][ordered]@{
                code     = 'SHARED_SCRIPT_SKILL_DOC_NOT_IN_DIFF'
                severity = 'warn'
                path     = ('{0}:{1}' -f $doc.RelPath, $firstLine)
                message  = ("script compartilhado '{0}' mudou no intervalo, mas '{1}' (que o documenta) nao esta no diff — comparar contrato/checklist ou justificar que a mudanca nao afeta esta skill" -f $scriptPath, $doc.RelPath)
            })
        }
    }
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }

$result = [ordered]@{
    status         = $status
    baseRef        = $BaseRef
    changedScripts = @($changedScripts)
    candidateCount = $findings.Count
    truncated      = $truncated
    findings       = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("CHANGED_SCRIPTS={0}" -f ($changedScripts -join ', '))
    Write-Output ("CANDIDATE_COUNT={0}" -f $findings.Count)
    foreach ($finding in @($findings)) {
        Write-Output ("SHARED_SCRIPT_SKILL_DOC_NOT_IN_DIFF: {0}: {1}" -f $finding.path, $finding.message)
    }
    if ($truncated) {
        Write-Output 'CANDIDATES_TRUNCATED=true'
    }
}

exit 0
