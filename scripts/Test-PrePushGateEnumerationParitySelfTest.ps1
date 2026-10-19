#requires -Version 7.4

<#
.SYNOPSIS
    Self-test de Test-PrePushGateEnumerationParity.ps1.

.DESCRIPTION
    Monta uma raiz temporaria com um orquestrador sintetico que invoca tres
    gates semanticos (Alpha/Beta/Gamma) e dois gates de parse (excluidos por
    padrão), e Markdown de raiz. Confirma:
      - linha que enumera 2 dos 3 gates semanticos -> candidata (subconjunto próprio);
      - linha que co-cita o par de parse -> NÃO vira candidata (par excluido);
      - linha que enumera os 3 gates semanticos -> NÃO vira candidata (conjunto completo);
      - linha com 1 único gate -> NÃO vira candidata;
      - âncora estável sob deslocamento/EOL, invalidação por edição;
      - extração dinâmica e falha de leitura deixam scanComplete=false;
      - teto limita exibição, não a coleta integral.
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

function Invoke-GateEnumeration {
    param([int]$MaxFindings = 30)
    $output = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -MaxFindings $MaxFindings -AsJson
    $exitCode = $LASTEXITCODE
    $jsonText = ($output | Out-String).Trim()
    if ($exitCode -ne 0) { throw "Gate retornou exit ${exitCode}: $jsonText" }
    return ($jsonText | ConvertFrom-Json -ErrorAction Stop)
}

try {
    # Orquestrador sintetico: 3 gates semanticos + 2 de parse (excluidos).
    $orchestrator = @'
$a = Join-Path $PSScriptRoot 'Test-Alpha.ps1'
$b = Join-Path $PSScriptRoot 'Test-Beta.ps1'
$g = Join-Path $PSScriptRoot 'Test-Gamma.ps1'
$p1 = Join-Path $PSScriptRoot 'Test-PsScriptsParse.ps1'
$p2 = Join-Path $PSScriptRoot 'Test-PyScriptsParse.ps1'
Invoke-EnumerationGate -ScriptRel 'scripts/Test-Alpha.ps1'
Invoke-EnumerationGate -ScriptRel 'scripts/Test-Beta.ps1'
Invoke-EnumerationGate -ScriptRel 'scripts/Test-Gamma.ps1'
Invoke-EnumerationGate -ScriptRel 'scripts/Test-PsScriptsParse.ps1'
Invoke-EnumerationGate -ScriptRel 'scripts/Test-PyScriptsParse.ps1'
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
    if (-not $result.scanComplete) {
        throw "varredura válida deveria ter scanComplete=true. Issues: $(@($result.scanIssues | ForEach-Object { $_.message }) -join ' | ')"
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

    # Âncora por linha, EOL normalizado e invalidado por alteração textual.
    if ($finding.file -ne 'doc-rotina.md' -or $finding.unitHash -notmatch '^[0-9a-f]{64}$' -or @($finding.listedMembers).Count -ne 2) {
        throw 'a candidata deveria expor file, unitHash e listedMembers.'
    }
    $originalDoc = [System.IO.File]::ReadAllText((Join-Path $tempRoot 'doc-rotina.md'))
    $originalHash = [string]$finding.unitHash
    $shiftedDoc = "`r`n`r`n" + ($originalDoc -replace "`r?`n", "`r`n")
    Write-TempFile -RelativePath 'doc-rotina.md' -Content $shiftedDoc
    $shiftedResult = Invoke-GateEnumeration
    $shiftedFinding = @($shiftedResult.findings | Where-Object { $_.unitHash -eq $originalHash })[0]
    if ($null -eq $shiftedFinding -or [int]$shiftedFinding.line -le [int]$finding.line) {
        throw 'deslocamento e LF/CRLF deveriam preservar o hash e alterar a linha de apresentação.'
    }
    Write-TempFile -RelativePath 'doc-rotina.md' -Content $originalDoc.Replace('gates semanticos', 'gates consultivos')
    $editedResult = Invoke-GateEnumeration
    if (@($editedResult.findings | Where-Object { $_.unitHash -eq $originalHash }).Count -ne 0) {
        throw 'editar o texto deveria invalidar a âncora.'
    }

    # Forma dinâmica ou não reconhecida de invocação canônica falha fechada.
    Write-TempFile -RelativePath 'scripts/Invoke-PrePushMechanicalChecks.ps1' -Content @'
$gatePath = $DynamicGatePath
Invoke-EnumerationGate -ScriptRel $gatePath
'@
    $dynamicResult = Invoke-GateEnumeration
    if ($dynamicResult.scanComplete -or @($dynamicResult.scanIssues).Count -eq 0) {
        throw 'invocação dinâmica deveria produzir scanComplete=false com diagnóstico.'
    }

    # Erro ao ler arquivo processado também invalida a varredura.
    Write-TempFile -RelativePath 'scripts/Invoke-PrePushMechanicalChecks.ps1' -Content $orchestrator
    $lockedPath = Join-Path $tempRoot 'doc-rotina.md'
    $lockedFile = [System.IO.File]::Open($lockedPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try { $readErrorResult = Invoke-GateEnumeration } finally { $lockedFile.Dispose() }
    if ($readErrorResult.scanComplete -or @($readErrorResult.files | Where-Object { $_.file -eq 'doc-rotina.md' -and -not $_.complete }).Count -ne 1) {
        throw 'erro de leitura deveria marcar o arquivo e a varredura como incompletos.'
    }

    # Teto aplicado depois da coleta: cinco findings continuam presentes em JSON.
    $manyLines = [System.Collections.Generic.List[string]]::new()
    for ($number = 1; $number -le 5; $number++) { $manyLines.Add("Linha ${number}: Test-Alpha.ps1 e Test-Beta.ps1.") }
    Write-TempFile -RelativePath 'doc-rotina.md' -Content ($manyLines -join "`n")
    $cappedResult = Invoke-GateEnumeration -MaxFindings 1
    if ([int]$cappedResult.candidateCount -ne 5 -or @($cappedResult.findings).Count -ne 5 -or @($cappedResult.displayFindings).Count -ne 1 -or -not $cappedResult.displayTruncated) {
        throw "coleta integral e teto de exibição incorretos (count=$($cappedResult.candidateCount), displayed=$(@($cappedResult.displayFindings).Count))."
    }

    Write-Output 'OK: Test-PrePushGateEnumerationParitySelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
