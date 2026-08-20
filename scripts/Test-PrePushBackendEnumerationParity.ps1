#requires -Version 7.4
<#
.SYNOPSIS
    Gate consultivo: enumeracao de backends/adapters de delegacao na documentacao
    que ficou como subconjunto proprio do conjunto canonico do dispatcher.

.DESCRIPTION
    Conserto da causa-raiz de um gap metodologico (Nivel 3): ao adicionar backends
    novos ao dispatcher (scripts/Invoke-LlmDelegatePanelDispatch.ps1), enumeracoes
    fechadas em prosa nos documentos Markdown podem permanecer com o conjunto
    antigo/incompleto sem citar o termo novo.

    Este gate extrai a VERDADE do codigo: deriva o conjunto canonico de backends
    a partir de $AdapterScript no AST do dispatcher real. Depois varre os arquivos
    *.md da raiz + xpz-llm-delegate/**/*.md (excluindo historico/ e arquivos
    congelados) e sinaliza qualquer unidade logica/sentenca que cite >= 2 backends
    formando um subconjunto proprio do conjunto canonico (2 <= n < total).

    Delimitacao de Dominio: sentencas/blocos contendo o token \bCursor\b (case-
    insensitive) sao ignorados por pertencerem ao Dominio B (Ferramentas de Agente
    gerenciadas), nao a backends de delegacao LLM (Dominio A).

    Marcador de Excecao: suporta <!-- backend-parity: ignore --> ou
    # backend-parity: ignore em comentarios para recortes intencionais por eixo.

.PARAMETER RootPath
    Raiz do repositorio. Default: pai de scripts/.

.PARAMETER BaseRef
    Aceito para o contrato comum dos gates; este gate e invariante (nao usa diff).

.PARAMETER ChangedFiles
    Aceito para o contrato comum dos gates; nao usado (verificacao e repo-wide).

.PARAMETER MaxFindings
    Teto de candidatas reportadas. Default: 50.

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
    [int]$MaxFindings = 50,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path

$dispatcherRel = 'scripts/Invoke-LlmDelegatePanelDispatch.ps1'
$dispatcherPath = Join-Path $resolvedRoot $dispatcherRel

$findings = [System.Collections.Generic.List[object]]::new()
$truncated = $false
$canonicalBackends = @()
$ignoredCount = 0

function Get-BackendRegex {
    param([string]$Backend)
    switch ($Backend.ToLowerInvariant()) {
        'opencode'    { return [regex]::new('(?i)\bopencode\b') }
        'codex'       { return [regex]::new('(?i)\bcodex\b') }
        'claude-code' { return [regex]::new('(?i)\b(?:claude-code|claudecode|claude(?:\s+code)?)\b') }
        'copilot'     { return [regex]::new('(?i)\b(?:github\s+)?copilot(?:\s+cli)?\b') }
        'gemini'      { return [regex]::new('(?i)\bgemini(?:\s+cli)?\b') }
        'antigravity' { return [regex]::new('(?i)\b(?:antigravity(?:\s+cli)?|agy)\b') }
        default       { return [regex]::new("(?i)\b$([regex]::Escape($Backend))\b") }
    }
}

function Parse-MarkdownLogicalUnits {
    param([string]$FilePath)

    $lines = @([System.IO.File]::ReadAllLines($FilePath))
    $units = [System.Collections.Generic.List[object]]::new()

    $inCodeBlock = $false
    $currentBlockLines = [System.Collections.Generic.List[string]]::new()
    $startLineNum = 1

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineNum = $i + 1
        $line = $lines[$i]

        if ($line -match '^\s*```') {
            if ($inCodeBlock) {
                $inCodeBlock = $false
                continue
            } else {
                if ($currentBlockLines.Count -gt 0) {
                    $units.Add([pscustomobject]@{
                        StartLine = $startLineNum
                        EndLine   = $lineNum - 1
                        RawLines  = @($currentBlockLines)
                    })
                    $currentBlockLines.Clear()
                }
                $inCodeBlock = $true
                continue
            }
        }

        if ($inCodeBlock) { continue }

        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($currentBlockLines.Count -gt 0) {
                $units.Add([pscustomobject]@{
                    StartLine = $startLineNum
                    EndLine   = $lineNum - 1
                    RawLines  = @($currentBlockLines)
                })
                $currentBlockLines.Clear()
            }
            continue
        }

        if ($line -match '^\s*#{1,6}\s+' -or $line -match '^\s*\|.*\|\s*$') {
            if ($currentBlockLines.Count -gt 0) {
                $units.Add([pscustomobject]@{
                    StartLine = $startLineNum
                    EndLine   = $lineNum - 1
                    RawLines  = @($currentBlockLines)
                })
                $currentBlockLines.Clear()
            }
            $units.Add([pscustomobject]@{
                StartLine = $lineNum
                EndLine   = $lineNum
                RawLines  = @($line)
            })
            continue
        }

        if ($line -match '^\s*[-*+]\s+' -or $line -match '^\s*\d+\.\s+') {
            if ($currentBlockLines.Count -gt 0) {
                $units.Add([pscustomobject]@{
                    StartLine = $startLineNum
                    EndLine   = $lineNum - 1
                    RawLines  = @($currentBlockLines)
                })
                $currentBlockLines.Clear()
            }
            $startLineNum = $lineNum
            $currentBlockLines.Add($line)
            continue
        }

        if ($currentBlockLines.Count -eq 0) {
            $startLineNum = $lineNum
        }
        $currentBlockLines.Add($line)
    }

    if ($currentBlockLines.Count -gt 0) {
        $units.Add([pscustomobject]@{
            StartLine = $startLineNum
            EndLine   = $lines.Count
            RawLines  = @($currentBlockLines)
        })
    }

    return @($units)
}

if (Test-Path -LiteralPath $dispatcherPath -PathType Leaf) {
    $tokens = $null
    $parserErrors = $null
    $dispatcherAst = [System.Management.Automation.Language.Parser]::ParseFile($dispatcherPath, [ref]$tokens, [ref]$parserErrors)

    if (@($parserErrors).Count -eq 0) {
        $assign = @($dispatcherAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text.Trim() -eq '$AdapterScript'
        }, $true))[0]

        if ($null -ne $assign) {
            $ht = if ($assign.Right -is [System.Management.Automation.Language.HashtableAst]) {
                $assign.Right
            } else {
                @($assign.Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $true))[0]
            }

            if ($null -ne $ht) {
                $extracted = [System.Collections.Generic.List[string]]::new()
                foreach ($pair in $ht.KeyValuePairs) {
                    $extracted.Add($pair.Item1.Extent.Text.Trim("'", '"', ' '))
                }
                $canonicalBackends = @($extracted)
            }
        }
    }
}

if ($canonicalBackends.Count -ge 2) {
    $backendPatterns = [ordered]@{}
    foreach ($b in $canonicalBackends) {
        $backendPatterns[$b] = Get-BackendRegex $b
    }

    $excludedFileNames = @('CHANGELOG.md', '998-ideias-descartadas-e-porque.md')

    $docFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($f in @(Get-ChildItem -LiteralPath $resolvedRoot -File -Filter '*.md' -ErrorAction SilentlyContinue)) {
        $docFiles.Add($f)
    }
    $llmDelegateDir = Join-Path $resolvedRoot 'xpz-llm-delegate'
    if (Test-Path -LiteralPath $llmDelegateDir -PathType Container) {
        foreach ($f in @(Get-ChildItem -LiteralPath $llmDelegateDir -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue)) {
            $docFiles.Add($f)
        }
    }

    foreach ($docFile in $docFiles) {
        if ($truncated) { break }

        $relPath = ([System.IO.Path]::GetRelativePath($resolvedRoot, $docFile.FullName) -replace '\\', '/')
        if ($relPath -match '^historico/' -or $relPath -match '^(?:temp|tempo)/' -or $docFile.Name -in $excludedFileNames) {
            continue
        }

        $units = Parse-MarkdownLogicalUnits $docFile.FullName

        foreach ($u in $units) {
            if ($truncated) { break }

            $hasIgnore = $false
            foreach ($l in $u.RawLines) {
                if ($l -match '<!--\s*backend-parity:\s*ignore\s*-->' -or $l -match '#\s*backend-parity:\s*ignore') {
                    $hasIgnore = $true
                    break
                }
            }
            if ($hasIgnore) {
                $ignoredCount++
                continue
            }

            $flatText = ($u.RawLines -join ' ')
            if ($flatText -match '(?i)\bcursor\b') {
                continue
            }

            $sentenceSplits = [regex]::Split($flatText, '(?<=[.!?])\s+(?=[A-Z0-9`"''\(\[])')

            foreach ($sentence in $sentenceSplits) {
                if ($truncated) { break }
                if ([string]::IsNullOrWhiteSpace($sentence)) { continue }
                if ($sentence -match '(?i)\bcursor\b') { continue }

                $onSentence = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($b in $canonicalBackends) {
                    if ($backendPatterns[$b].IsMatch($sentence)) {
                        [void]$onSentence.Add($b)
                    }
                }

                if ($onSentence.Count -lt 2) { continue }
                if ($onSentence.Count -ge $canonicalBackends.Count) { continue }

                if ($findings.Count -ge $MaxFindings) {
                    $truncated = $true
                    break
                }

                $listed = @($onSentence | Sort-Object)
                $missing = @($canonicalBackends | Where-Object { -not $onSentence.Contains($_) })

                $findings.Add([pscustomobject][ordered]@{
                    code     = 'BACKEND_ENUMERATION_SUBSET'
                    severity = 'warn'
                    path     = ('{0}:{1}' -f $relPath, $u.StartLine)
                    message  = ("enumera {0} de {1} backends canonicos ({2}); se a frase descreve o conjunto de backends, confirmar se esta completa — ausente(s): {3}" -f $onSentence.Count, $canonicalBackends.Count, ($listed -join ', '), ($missing -join ', '))
                })
            }
        }
    }
}

$status = if ($findings.Count -gt 0) { 'warn' } else { 'pass' }

$result = [ordered]@{
    status            = $status
    dispatcher        = $dispatcherRel
    canonicalBackends = @($canonicalBackends)
    candidateCount    = $findings.Count
    ignoredCount      = $ignoredCount
    truncated         = $truncated
    findings          = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("CANONICAL_BACKENDS={0}" -f ($canonicalBackends -join ', '))
    Write-Output ("CANDIDATE_COUNT={0}" -f $findings.Count)
    Write-Output ("IGNORED_COUNT={0}" -f $ignoredCount)
    foreach ($finding in @($findings)) {
        Write-Output ("BACKEND_ENUMERATION_SUBSET: {0}: {1}" -f $finding.path, $finding.message)
    }
    if ($truncated) {
        Write-Output 'CANDIDATES_TRUNCATED=true'
    }
}

exit 0
