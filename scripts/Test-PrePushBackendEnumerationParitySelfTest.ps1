#requires -Version 7.4
<#
.SYNOPSIS
    Self-test de Test-PrePushBackendEnumerationParity.ps1 (Nivel 3).

.DESCRIPTION
    Valida os 9 cenarios metodologicos do gate consultivo de paridade de backends:
      1. Extracao fiel da fonte de verdade do dispatcher ($AdapterScript via AST).
      2. Enumeracao completa em linha unica (pass, sem finding).
      3. Enumeracao completa quebrada em multiplas linhas por wrap de paragrafo (pass).
      4. Subconjunto proprio em linha unica e multi-linha (warn / finding).
      5. Casamento tolerante a formatacao Markdown (negrito, crases, links, pontuacao).
      6. Respeito a fronteira de dominio (sentencas com \bCursor\b ignoradas).
      7. Respeito ao marcador inline (<!-- backend-parity: ignore --> / # backend-parity: ignore).
      8. Saida estruturada em JSON e conformidade com contrato comum de gates.
      9. Simulacao de novo backend adicionado ao dispatcher sem atualizacao na doc (deteccao).

    Sentinela de sucesso: OK: Test-PrePushBackendEnumerationParitySelfTest.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Test-PrePushBackendEnumerationParity.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Script alvo nao encontrado: $scriptPath"
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-backend-parity-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path (Join-Path $tempRoot 'scripts') -Force)
[void](New-Item -ItemType Directory -Path (Join-Path $tempRoot 'xpz-llm-delegate') -Force)

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
    # -----------------------------------------------------------------------------------
    # Fixture: Dispatcher sintetico com 6 backends canonicos
    # -----------------------------------------------------------------------------------
    $dispatcher = @'
$AdapterScript = @{
    'opencode'    = 'Invoke-OpenCode.ps1'
    'codex'       = 'Invoke-Codex.ps1'
    'claude-code' = 'Invoke-ClaudeCodeAsync.ps1'
    'copilot'     = 'Invoke-Copilot.ps1'
    'gemini'      = 'Invoke-Gemini.ps1'
    'antigravity' = 'Invoke-Antigravity.ps1'
}
'@
    Write-TempFile -RelativePath 'scripts/Invoke-LlmDelegatePanelDispatch.ps1' -Content $dispatcher

    # -----------------------------------------------------------------------------------
    # Documentos de teste cobrindo os cenarios 2 a 7
    # -----------------------------------------------------------------------------------
    $doc1 = @'
# Teste de Paridade de Backends

## Cenario 2: Enumeracao completa em linha unica
Suporta opencode, codex, claude-code, copilot, gemini e antigravity.

## Cenario 3: Enumeracao completa quebrada por wrap
Esta metodologia suporta os backends **opencode**, **Codex**, `Claude Code`,
`GitHub Copilot CLI`, `Gemini CLI` e **Antigravity CLI** de forma integrada.

## Cenario 4: Subconjunto proprio (deve gerar warning)
Os backends avaliados inicialmente foram `opencode`, `codex` e `claude-code`.

## Cenario 5: Formatacao complexa em subconjunto proprio
Comparando **[OpenCode](https://example.com)** contra _Copilot_ e `Gemini`.

## Cenario 6: Dominio B (Cursor presente -> deve ser ignorado)
Ferramentas de agente instaladas: Cursor, Claude Code, Codex, Copilot, Gemini e Antigravity.

## Cenario 7: Marcador de excecao inline (deve ser ignorado)
<!-- backend-parity: ignore -->
Recorte por eixo stdin-based: apenas opencode, codex e claude-code.
'@
    Write-TempFile -RelativePath 'doc-test.md' -Content $doc1

    # Executa o gate via pwsh
    $output = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -AsJson 2>&1
    $exitCode = $LASTEXITCODE
    $jsonText = ($output | Out-String).Trim()
    $result = $jsonText | ConvertFrom-Json

    # -----------------------------------------------------------------------------------
    # Assercoes Cenarios 1 a 8
    # -----------------------------------------------------------------------------------
    if ($exitCode -ne 0) {
        throw "Cenario 8: gate deveria sair com exit 0 (consultivo); obtido $exitCode. Saida: $jsonText"
    }
    if ($result.status -ne 'warn') {
        throw "Cenario 8: status deveria ser 'warn'; obtido '$($result.status)'. Saida: $jsonText"
    }

    # Cenario 1: Extracao fiel
    $extractedBackends = @($result.canonicalBackends | Sort-Object)
    $expectedBackends = @('antigravity', 'claude-code', 'codex', 'copilot', 'gemini', 'opencode')
    if (($extractedBackends -join ',') -ne ($expectedBackends -join ',')) {
        throw "Cenario 1: extracao de backends do dispatcher falhou; obtido $(($extractedBackends) -join ',')"
    }

    # Cenario 7: Contagem de ignorados
    if ([int]$result.ignoredCount -ne 1) {
        throw "Cenario 7: ignoredCount deveria ser 1; obtido $($result.ignoredCount)"
    }

    # Cenarios 2, 3, 4, 5, 6: Contagem de findings (apenas Cenarios 4 e 5 devem gerar finding)
    if ([int]$result.candidateCount -ne 2) {
        throw "Cenarios 2-6: esperados exatamente 2 findings (Cenarios 4 e 5); obtido $($result.candidateCount). Findings: $(@($result.findings | ForEach-Object { $_.message }) -join ' | ')"
    }

    # Validacao das mensagens dos findings
    $f1 = $result.findings[0]
    if ($f1.message -notmatch 'opencode' -or $f1.message -notmatch 'codex' -or $f1.message -notmatch 'claude-code') {
        throw "Cenario 4: finding 1 deveria listar opencode, codex e claude-code; got $($f1.message)"
    }
    if ($f1.message -notmatch 'antigravity' -or $f1.message -notmatch 'copilot' -or $f1.message -notmatch 'gemini') {
        throw "Cenario 4: finding 1 deveria apontar antigravity, copilot e gemini como ausentes; got $($f1.message)"
    }

    $f2 = $result.findings[1]
    if ($f2.message -notmatch 'opencode' -or $f2.message -notmatch 'copilot' -or $f2.message -notmatch 'gemini') {
        throw "Cenario 5: finding 2 deveria listar opencode, copilot e gemini; got $($f2.message)"
    }

    # -----------------------------------------------------------------------------------
    # Cenario 9: Simulacao de novo backend no dispatcher sem atualizacao na doc
    # -----------------------------------------------------------------------------------
    $dispatcherWithNew = @'
$AdapterScript = @{
    'opencode'    = 'Invoke-OpenCode.ps1'
    'codex'       = 'Invoke-Codex.ps1'
    'claude-code' = 'Invoke-ClaudeCodeAsync.ps1'
    'copilot'     = 'Invoke-Copilot.ps1'
    'gemini'      = 'Invoke-Gemini.ps1'
    'antigravity' = 'Invoke-Antigravity.ps1'
    'future-llm'  = 'Invoke-FutureLlm.ps1'
}
'@
    Write-TempFile -RelativePath 'scripts/Invoke-LlmDelegatePanelDispatch.ps1' -Content $dispatcherWithNew

    # Doc que anteriormente tinha os 6 (completa) agora tem 6 de 7 -> deve virar finding!
    $docWith6 = @'
# Doc Anteriormente Completa
Os backends suportados sao opencode, codex, claude-code, copilot, gemini e antigravity.
'@
    Write-TempFile -RelativePath 'doc-test.md' -Content $docWith6

    $output9 = & pwsh -NoProfile -File $scriptPath -RootPath $tempRoot -AsJson 2>&1
    $jsonText9 = ($output9 | Out-String).Trim()
    $result9 = $jsonText9 | ConvertFrom-Json

    if (@($result9.canonicalBackends).Count -ne 7) {
        throw "Cenario 9: canonicalBackends deveria conter 7 itens; obtido $(@($result9.canonicalBackends).Count)"
    }
    if ([int]$result9.candidateCount -ne 1) {
        throw "Cenario 9: doc com 6 backends deveria ser detectada como subconjunto proprio apos adicao do 7o backend; candidateCount=$($result9.candidateCount)"
    }
    if ($result9.findings[0].message -notmatch 'future-llm') {
        throw "Cenario 9: finding deveria indicar future-llm como ausente; got $($result9.findings[0].message)"
    }

    Write-Output 'OK: Test-PrePushBackendEnumerationParitySelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
