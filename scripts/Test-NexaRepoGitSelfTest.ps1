#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico de Initialize-NexaRepoGit.ps1.

.DESCRIPTION
    Valida a classificação de estado do bootstrap do repositório da skill `nexa`
    SEM acesso a rede e SEM tocar no repositório real. Cada caso monta um cenário
    local e confere o "label" produzido. Os caminhos que exigiriam clone/fetch do
    remoto oficial são exercitados via -WhatIf, que para antes de qualquer operacao
    de rede ou escrita. A raiz e sempre passada por -NexaRepoRoot explicito, de modo
    que a deteccao por vinculo global e os defaults não interferem.

    Requer o executavel Git disponível (o próprio recurso depende dele).
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptUnderTest = Join-Path $PSScriptRoot 'Initialize-NexaRepoGit.ps1'
if (-not (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf)) {
    throw "BLOCK: script alvo nao encontrado: $scriptUnderTest"
}

$official = 'https://github.com/GxBrasilNOficial/genexus-skills-from-zip.git'
$git = (Get-Command git -ErrorAction SilentlyContinue)
if (-not $git) {
    throw 'BLOCK: git ausente; este self-test requer o executavel git.'
}

$failures = 0
$cases = 0

function New-TempDir {
    $path = Join-Path $env:TEMP ('nexa-gitselftest-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Remove-TempDir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Attributes = 'Normal' }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-Label {
    param(
        [string]$CaseName,
        [string]$ExpectedLabel,
        [string]$Output
    )
    $script:cases++
    if ($Output -match ('"label":\s*"' + [regex]::Escape($ExpectedLabel) + '"')) {
        Write-Output ("PASS: {0} -> {1}" -f $CaseName, $ExpectedLabel)
    }
    else {
        $script:failures++
        Write-Output ("FAIL: {0} -> esperado {1}" -f $CaseName, $ExpectedLabel)
        Write-Output ("      saida: {0}" -f ($Output -replace "`r?`n", ' '))
    }
}

# Caso A: repositório já ligado ao oficial -> NEXA_ALREADY_LINKED (sem rede)
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    & git -C $tmp remote add origin $official *> $null
    $out = & $scriptUnderTest -NexaRepoRoot $tmp -AsJson | Out-String
    Assert-Label -CaseName 'already-linked' -ExpectedLabel 'NEXA_ALREADY_LINKED' -Output $out
}
finally { Remove-TempDir -Path $tmp }

# Caso B: origin diverge do oficial -> NEXA_REMOTE_MISMATCH (sem rede)
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    & git -C $tmp remote add origin 'https://example.com/outro/repo.git' *> $null
    $out = & $scriptUnderTest -NexaRepoRoot $tmp -AsJson | Out-String
    Assert-Label -CaseName 'remote-mismatch' -ExpectedLabel 'NEXA_REMOTE_MISMATCH' -Output $out
    if ($out -notmatch '-NexaRepoRoot' -or $out -notmatch 'GeneXus-Skills-From-Zip') {
        throw "Caso remote-mismatch: mensagem deve orientar -NexaRepoRoot / GeneXus-Skills-From-Zip. Saida: $out"
    }
}
finally { Remove-TempDir -Path $tmp }

# Caso B2: origin oficial + remoto extra (fork) -> NEXA_ALREADY_LINKED (tolera fork)
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    & git -C $tmp remote add origin $official *> $null
    & git -C $tmp remote add fork 'https://github.com/alguem/genexus-skills-from-zip.git' *> $null
    $out = & $scriptUnderTest -NexaRepoRoot $tmp -AsJson | Out-String
    Assert-Label -CaseName 'official-with-extra-fork' -ExpectedLabel 'NEXA_ALREADY_LINKED' -Output $out
}
finally { Remove-TempDir -Path $tmp }

# Caso C: repositório sem origin + WhatIf -> NEXA_ORIGIN_ADD_SKIPPED (sem rede/escrita)
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    $out = & $scriptUnderTest -NexaRepoRoot $tmp -AsJson -WhatIf | Out-String
    Assert-Label -CaseName 'origin-missing-whatif' -ExpectedLabel 'NEXA_ORIGIN_ADD_SKIPPED' -Output $out
}
finally { Remove-TempDir -Path $tmp }

# Caso D: pasta com conteúdo, sem .git -> NEXA_DIR_NOT_REPO (bloqueia, sem rede/escrita)
$tmp = New-TempDir
try {
    Set-Content -LiteralPath (Join-Path $tmp 'algum.txt') -Value 'conteudo' -Encoding utf8
    $out = & $scriptUnderTest -NexaRepoRoot $tmp -AsJson | Out-String
    Assert-Label -CaseName 'dir-not-repo' -ExpectedLabel 'NEXA_DIR_NOT_REPO' -Output $out
}
finally { Remove-TempDir -Path $tmp }

# Caso E: pasta inexistente + WhatIf -> NEXA_CLONE_SKIPPED (para antes do clone)
$tmp = New-TempDir
try {
    $target = Join-Path $tmp 'GeneXus-Skills-From-Zip'
    $out = & $scriptUnderTest -NexaRepoRoot $target -AsJson -WhatIf | Out-String
    Assert-Label -CaseName 'clone-skipped-whatif' -ExpectedLabel 'NEXA_CLONE_SKIPPED' -Output $out
}
finally { Remove-TempDir -Path $tmp }

Write-Output ('---')
if ($failures -eq 0) {
    Write-Output ("SELFTEST_OK: {0}/{0} casos passaram" -f $cases)
    exit 0
}
else {
    Write-Output ("SELFTEST_FAIL: {0} de {1} casos falharam" -f $failures, $cases)
    exit 1
}
