#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de Test-PrePushOpenCodeReviewerRoDrift.ps1.

.DESCRIPTION
    Monta um repositório git temporario e confirma:
      - intervalo que altera .opencode/agent/reviewer-ro.md -> status 'warn',
        um finding OPENCODE_REVIEWER_RO_CONTRACT_CHANGED, exit 0 (consultivo);
      - intervalo sem esse arquivo (inclusive outro .md em .opencode/agent/) -> 'pass';
      - -ChangedFiles explicito com barra invertida -> normaliza e detecta;
      - caixa diferente no caminho -> não detecta (comparação ordinal, como o git).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushOpenCodeReviewerRoDrift.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-reviewer-ro-drift-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')
$utf8NoBom = Get-Utf8NoBomEncoding
function Write-TempFile {
    param([string]$RelativePath, [string]$Content)
    $full = Join-Path $tempRoot $RelativePath
    $dir = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $dir)) {
        [void](New-Item -ItemType Directory -Path $dir -Force)
    }
    [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
}

function Invoke-TempGit {
    param([string[]]$Arguments)
    $output = & git -C $tempRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ("git {0} falhou: {1}" -f ($Arguments -join ' '), (($output | Out-String).Trim()))
    }
    return $output
}

function Invoke-Gate {
    param([string]$BaseRef, [string[]]$ChangedFiles = @())
    $gateArgs = @('-NoProfile', '-File', $scriptPath, '-RootPath', $tempRoot, '-BaseRef', $BaseRef, '-AsJson')
    if ($ChangedFiles.Count -gt 0) { $gateArgs += @('-ChangedFiles', ($ChangedFiles -join ',')) }
    $output = & pwsh @gateArgs 2>&1
    $exitCode = $LASTEXITCODE
    $jsonText = ($output | Out-String).Trim()
    if ($exitCode -ne 0) {
        throw "gate deveria sair com exit 0 (consultivo); obtido $exitCode. Saida: $jsonText"
    }
    return ($jsonText | ConvertFrom-Json)
}

try {
    [void](Invoke-TempGit @('init', '-q'))
    [void](Invoke-TempGit @('config', 'user.email', 'selftest@example.com'))
    [void](Invoke-TempGit @('config', 'user.name', 'Self Test'))
    [void](Invoke-TempGit @('config', 'commit.gpgsign', 'false'))

    Write-TempFile -RelativePath '.opencode/agent/reviewer-ro.md' -Content "---`nmode: all`n---`nv1`n"
    Write-TempFile -RelativePath 'base.md' -Content "base`n"
    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'base'))
    $baseSha = (Invoke-TempGit @('rev-parse', 'HEAD') | Out-String).Trim()

    # Intervalo SEM o contrato (inclui outro agente na mesma pasta) -> pass.
    Write-TempFile -RelativePath '.opencode/agent/outro.md' -Content "outro`n"
    Write-TempFile -RelativePath 'base.md' -Content "base 2`n"
    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'sem contrato'))
    $midSha = (Invoke-TempGit @('rev-parse', 'HEAD') | Out-String).Trim()

    $r = Invoke-Gate -BaseRef $baseSha
    if ($r.status -ne 'pass' -or $r.contractChanged -or @($r.findings).Count -ne 0) {
        throw "intervalo sem o contrato deveria ser 'pass' sem findings; obtido status=$($r.status) findings=$(@($r.findings).Count)"
    }

    # Intervalo COM o contrato -> warn + 1 finding.
    Write-TempFile -RelativePath '.opencode/agent/reviewer-ro.md' -Content "---`nmode: all`n---`nv2`n"
    [void](Invoke-TempGit @('add', '-A'))
    [void](Invoke-TempGit @('commit', '-q', '-m', 'altera contrato'))

    $r = Invoke-Gate -BaseRef $baseSha
    if ($r.status -ne 'warn' -or -not $r.contractChanged) {
        throw "intervalo com o contrato deveria ser 'warn'; obtido status=$($r.status)"
    }
    $codes = @($r.findings | ForEach-Object { $_.code })
    if ($codes.Count -ne 1 -or $codes[0] -ne 'OPENCODE_REVIEWER_RO_CONTRACT_CHANGED') {
        throw "esperado 1 finding OPENCODE_REVIEWER_RO_CONTRACT_CHANGED; obtido: $($codes -join ', ')"
    }
    if ($r.findings[0].message -notmatch 'Install-OpenCodeReviewerRoAgent\.ps1') {
        throw "a mensagem deveria apontar o instalador; obtida: $($r.findings[0].message)"
    }

    # So o ultimo commit no intervalo (mid..HEAD) -> continua detectando.
    $r = Invoke-Gate -BaseRef $midSha
    if ($r.status -ne 'warn') {
        throw "intervalo mid..HEAD (so o commit do contrato) deveria ser 'warn'; obtido $($r.status)"
    }

    # -ChangedFiles explicito com barra invertida -> normaliza e detecta.
    $r = Invoke-Gate -BaseRef $baseSha -ChangedFiles @('.opencode\agent\reviewer-ro.md')
    if ($r.status -ne 'warn') {
        throw "-ChangedFiles com barra invertida deveria detectar; obtido $($r.status)"
    }

    # Caixa diferente -> nao detecta (comparacao ordinal).
    $r = Invoke-Gate -BaseRef $baseSha -ChangedFiles @('.opencode/agent/Reviewer-RO.md')
    if ($r.status -ne 'pass') {
        throw "caminho com caixa diferente NAO deveria detectar; obtido $($r.status)"
    }

    Write-Output 'OK: Test-PrePushOpenCodeReviewerRoDriftSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
