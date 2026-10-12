#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de Test-PrePushGateEnumerationParity.ps1.

.DESCRIPTION
    Monta uma raiz temporaria com um orquestrador sintetico que invoca tres
    gates semanticos (Alpha/Beta/Gamma) e dois gates de parse (excluidos por
    padrão), e um .md de raiz com quatro linhas. Confirma:
      - linha que enumera 2 dos 3 gates semanticos -> candidata (subconjunto próprio);
      - linha que co-cita o par de parse -> NÃO vira candidata (par excluido);
      - linha que enumera os 3 gates semanticos -> NÃO vira candidata (conjunto completo);
      - linha com 1 único gate -> NÃO vira candidata.
    Não precisa de git: o gate e invariante (le orquestrador + .md, sem diff).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushGateEnumerationParity.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-gate-enum-parity-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts') -Force)

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

try {
    # Orquestrador sintetico: 3 gates semanticos + 2 de parse (excluidos).
    $orchestrator = @'
$a = Join-Path $PSScriptRoot 'Test-Alpha.ps1'
$b = Join-Path $PSScriptRoot 'Test-Beta.ps1'
$g = Join-Path $PSScriptRoot 'Test-Gamma.ps1'
$p1 = Join-Path $PSScriptRoot 'Test-PsScriptsParse.ps1'
$p2 = Join-Path $PSScriptRoot 'Test-PyScriptsParse.ps1'
'@
    Write-TempFile -RelativePath 'scripts/Invoke-PrePushMechanicalChecks.ps1' -Content $orchestrator

    $doc = @'
# Doc da rotina

- Os gates semanticos sao `Test-Alpha.ps1` e `Test-Beta.ps1`.
- O parse delegado (`Test-PsScriptsParse.ps1` e `Test-PyScriptsParse.ps1`) varre o repo.
- Conjunto completo: `Test-Alpha.ps1`, `Test-Beta.ps1` e `Test-Gamma.ps1`.
- Apenas `Test-Gamma.ps1` cobre o caso isolado.
'@
    Write-TempFile -RelativePath 'doc-rotina.md' -Content $doc

    $output = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -AsJson 2>&1
    $exitCode = $LASTEXITCODE
    $jsonText = ($output | Out-String).Trim()
    $result = $jsonText | ConvertFrom-Json

    if ($exitCode -ne 0) {
        throw "gate deveria sair com exit 0 (consultivo); obtido $exitCode. Saida: $jsonText"
    }
    if ($result.status -ne 'warn') {
        throw "status deveria ser 'warn'; obtido '$($result.status)'. Saida: $jsonText"
    }
    if (@($result.orchestratorGates).Count -ne 3) {
        throw "conjunto derivado deveria ter 3 gates (parse excluido); obtido $(@($result.orchestratorGates) -join ', ')"
    }
    if ($result.candidateCount -ne 1) {
        throw "deveria haver exatamente 1 candidata (linha 2-de-3); obtido $($result.candidateCount). Findings: $(@($result.findings | ForEach-Object { $_.path }) -join ', ')"
    }

    $finding = $result.findings[0]
    if ($finding.message -notmatch 'Test-Alpha\.ps1' -or $finding.message -notmatch 'Test-Beta\.ps1') {
        throw "a candidata deveria enumerar Alpha e Beta; message: $($finding.message)"
    }
    if ($finding.message -notmatch 'Test-Gamma\.ps1') {
        throw "a candidata deveria apontar Gamma como ausente; message: $($finding.message)"
    }

    Write-Output 'OK: Test-PrePushGateEnumerationParitySelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
