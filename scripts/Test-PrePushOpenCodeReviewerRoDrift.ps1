#requires -Version 7.4
<#
.SYNOPSIS
    Gate consultivo: o intervalo da pré-push altera o contrato canônico do
    agente opencode `reviewer-ro` (.opencode/agent/reviewer-ro.md).

.DESCRIPTION
    Apoio mecanico ao 13-revisao-pre-push.md. O `reviewer-ro` tem duas
    instalações: a project-local (o próprio .opencode/agent/reviewer-ro.md, que
    viaja com o repositório) e a global (`agent.reviewer-ro` em
    ~/.config/opencode/opencode.jsonc de cada máquina), derivada desse markdown
    por scripts/Install-OpenCodeReviewerRoAgent.ps1. Mudar o markdown não muda a
    cópia global: de cwd fora do repositório o guard dos adapters passa a
    bloquear com motivo `static` até a reinstalação (caso real 2026-10-09, após
    o commit 8f61c28).

    Escopo diff: só olha se `.opencode/agent/reviewer-ro.md` está entre os
    arquivos do intervalo BaseRef..HEAD. Não lê a configuração global da
    máquina (fora do repositório; pode conter chaves de provedor).

    Consultivo: severity 'warn'; o finding entra em agentWarnings e não falha
    o gate mecânico.

.PARAMETER RootPath
    Raiz do repositório. Default: pai de scripts/.

.PARAMETER BaseRef
    Referencia base do intervalo BaseRef..HEAD. Default: origin/main.

.PARAMETER ChangedFiles
    Arquivos alterados no intervalo. Quando vazio, calcula via git diff.

.PARAMETER AsJson
    Emite diagnostico estruturado em JSON.
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

$contractPath = '.opencode/agent/reviewer-ro.md'

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

# Comparacao ordinal (case-sensitive), como o git registra o caminho.
$contractChanged = @($normalizedChangedFiles | Where-Object { $_ -ceq $contractPath }).Count -gt 0

$findings = [System.Collections.Generic.List[object]]::new()
if ($contractChanged) {
    $findings.Add([pscustomobject][ordered]@{
        code     = 'OPENCODE_REVIEWER_RO_CONTRACT_CHANGED'
        severity = 'warn'
        path     = $contractPath
        message  = 'contrato canonico do reviewer-ro alterado no intervalo: a copia global (agent.reviewer-ro em ~/.config/opencode/opencode.jsonc) de cada maquina fica defasada e o guard bloqueia com motivo static fora do repositorio. Apos o push, reinstalar pelo passo 10 da xpz-skills-setup ou com scripts/Install-OpenCodeReviewerRoAgent.ps1 (-WhatIf antes; faz backup) e conferir com scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -WorkingDirectory <pasta neutra> -ExpectGlobal -AsJson.'
    })
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }

$result = [ordered]@{
    status          = $status
    baseRef         = $BaseRef
    contractPath    = $contractPath
    contractChanged = $contractChanged
    findings        = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("CONTRACT_CHANGED={0}" -f $contractChanged.ToString().ToLowerInvariant())
    foreach ($finding in @($findings)) {
        Write-Output ("{0}: {1}: {2}" -f $finding.code, $finding.path, $finding.message)
    }
}

exit 0
