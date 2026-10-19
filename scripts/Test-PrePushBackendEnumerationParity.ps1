#requires -Version 7.4

<#
.SYNOPSIS
    Gate consultivo: enumerações documentais de backends fora do conjunto do dispatcher.

.DESCRIPTION
    Deriva o conjunto canônico de $AdapterScript por AST e identifica subconjuntos
    por unidade lógica. A coleta examina arquivos Markdown diretamente na raiz do
    repositório e, recursivamente, em xpz-llm-delegate/; não percorre outras pastas
    da raiz. Exclui CHANGELOG.md e 998-ideias-descartadas-e-porque.md em ambos os
    escopos, além das subárvores historico/, temp/ e tempo/ em xpz-llm-delegate/.
    Qualquer falha de extração, enumeração, leitura ou processamento deixa
    scanComplete=false. O limite controla apenas displayFindings; findings sempre
    contém a coleta integral dentro desse escopo.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
    [string]$BaseRef = 'origin/main',
    [AllowEmptyCollection()][string[]]$ChangedFiles = @(),
    [ValidateRange(1, 500)][int]$MaxFindings = 50,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
$dispatcherRel = 'scripts/Invoke-LlmDelegatePanelDispatch.ps1'
$dispatcherPath = Join-Path $resolvedRoot $dispatcherRel
$findings = [System.Collections.Generic.List[object]]::new()
$scanIssues = [System.Collections.Generic.List[object]]::new()
$fileStates = [System.Collections.Generic.List[object]]::new()
$canonicalBackends = [System.Collections.Generic.List[string]]::new()
$ignoredCount = 0
$sourceComplete = $false
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Add-ScanIssue {
    param([string]$Code, [string]$Path, [string]$Message)
    $scanIssues.Add([pscustomobject][ordered]@{ code = $Code; path = $Path; message = $Message })
}

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $bytes = $sha.ComputeHash($utf8NoBom.GetBytes($Text)) } finally { $sha.Dispose() }
    return (([System.BitConverter]::ToString($bytes)) -replace '-', '').ToLowerInvariant()
}

function Get-OrdinalSortedStrings {
    param([string[]]$Values)
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($value in $Values) { $result.Add($value) }
    $result.Sort([System.StringComparer]::Ordinal)
    return @($result.ToArray())
}

function Get-BackendRegex {
    param([string]$Backend)
    switch ($Backend.ToLowerInvariant()) {
        'opencode'    { return [regex]::new('(?i)\b(?:opencode(?:\/(?:ollama[\s\-_]*cloud|mimo))?)\b') }
        'codex'       { return [regex]::new('(?i)\b(?:codex(?:[\s\-_]*delegate|[\s\-_]*cli)?)\b') }
        'claude-code' { return [regex]::new('(?i)\b(?:claude[\s\-_]*code|claudecode|claude)\b') }
        'copilot'     { return [regex]::new('(?i)\b(?:github[\s\-_]+)?copilot(?:[\s\-_]+cli)?\b') }
        'gemini'      { return [regex]::new('(?i)\bgemini(?:[\s\-_]+cli)?\b') }
        'antigravity' { return [regex]::new('(?i)\b(?:antigravity(?:[\s\-_]+(?:cli|2\.0))?|agy)\b') }
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
            if ($inCodeBlock) { $inCodeBlock = $false; continue }
            if ($currentBlockLines.Count -gt 0) {
                $units.Add([pscustomobject]@{ StartLine = $startLineNum; EndLine = $lineNum - 1; RawLines = @($currentBlockLines) })
                $currentBlockLines.Clear()
            }
            $inCodeBlock = $true
            continue
        }
        if ($inCodeBlock) { continue }
        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($currentBlockLines.Count -gt 0) {
                $units.Add([pscustomobject]@{ StartLine = $startLineNum; EndLine = $lineNum - 1; RawLines = @($currentBlockLines) })
                $currentBlockLines.Clear()
            }
            continue
        }
        if ($line -match '^\s*#{1,6}\s+' -or $line -match '^\s*\|.*\|\s*$') {
            if ($currentBlockLines.Count -gt 0) {
                $units.Add([pscustomobject]@{ StartLine = $startLineNum; EndLine = $lineNum - 1; RawLines = @($currentBlockLines) })
                $currentBlockLines.Clear()
            }
            $units.Add([pscustomobject]@{ StartLine = $lineNum; EndLine = $lineNum; RawLines = @($line) })
            continue
        }
        if ($line -match '^\s*[-*+]\s+' -or $line -match '^\s*\d+\.\s+') {
            if ($currentBlockLines.Count -gt 0) {
                $units.Add([pscustomobject]@{ StartLine = $startLineNum; EndLine = $lineNum - 1; RawLines = @($currentBlockLines) })
                $currentBlockLines.Clear()
            }
            $startLineNum = $lineNum
            $currentBlockLines.Add($line)
            continue
        }
        if ($currentBlockLines.Count -eq 0) { $startLineNum = $lineNum }
        $currentBlockLines.Add($line)
    }
    if ($currentBlockLines.Count -gt 0) {
        $units.Add([pscustomobject]@{ StartLine = $startLineNum; EndLine = $lines.Count; RawLines = @($currentBlockLines) })
    }
    return @($units)
}

# A fonte é válida apenas quando existe uma única atribuição direta e todos os
# membros são chaves literais, distintas e não vazias.
try {
    if (-not (Test-Path -LiteralPath $dispatcherPath -PathType Leaf)) {
        Add-ScanIssue 'CANONICAL_SOURCE_MISSING' $dispatcherRel 'Dispatcher ausente.'
    } else {
        $tokens = $null
        $parserErrors = $null
        $dispatcherAst = [System.Management.Automation.Language.Parser]::ParseFile($dispatcherPath, [ref]$tokens, [ref]$parserErrors)
        if (@($parserErrors).Count -gt 0) {
            Add-ScanIssue 'CANONICAL_SOURCE_PARSE_ERROR' $dispatcherRel ((@($parserErrors | ForEach-Object { $_.Message }) -join '; '))
        } else {
            $assignments = @($dispatcherAst.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $node.Left.VariablePath.UserPath -eq 'AdapterScript'
            }, $true))
            $rightAst = $null
            if ($assignments.Count -eq 1) {
                $rightAst = $assignments[0].Right
                if ($rightAst -is [System.Management.Automation.Language.CommandExpressionAst] -and $rightAst.Redirections.Count -eq 0) {
                    $rightAst = $rightAst.Expression
                } elseif ($rightAst -is [System.Management.Automation.Language.PipelineAst] -and
                    $rightAst.PipelineElements.Count -eq 1 -and
                    $rightAst.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst] -and
                    $rightAst.PipelineElements[0].Redirections.Count -eq 0) {
                    $rightAst = $rightAst.PipelineElements[0].Expression
                }
            }
            if ($assignments.Count -ne 1 -or $rightAst -isnot [System.Management.Automation.Language.HashtableAst]) {
                Add-ScanIssue 'CANONICAL_SOURCE_UNSUPPORTED' $dispatcherRel 'Esperada uma única atribuição direta de $AdapterScript para uma hashtable literal.'
            } else {
                $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                $valid = $true
                foreach ($pair in $rightAst.KeyValuePairs) {
                    if ($pair.Item1 -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) {
                        Add-ScanIssue 'CANONICAL_KEY_NOT_LITERAL' $dispatcherRel 'Chave dinâmica ou expressão não suportada em $AdapterScript.'
                        $valid = $false
                        continue
                    }
                    $key = [string]$pair.Item1.Value
                    if ([string]::IsNullOrWhiteSpace($key) -or -not $seen.Add($key)) {
                        Add-ScanIssue 'CANONICAL_KEY_INVALID' $dispatcherRel 'Chave vazia ou duplicada em $AdapterScript.'
                        $valid = $false
                        continue
                    }
                    $canonicalBackends.Add($key)
                }
                if ($valid -and $canonicalBackends.Count -ge 2) { $sourceComplete = $true }
                elseif ($valid) { Add-ScanIssue 'CANONICAL_SET_TOO_SMALL' $dispatcherRel 'O conjunto canônico precisa conter ao menos dois backends.' }
            }
        }
    }
} catch {
    Add-ScanIssue 'CANONICAL_SOURCE_ERROR' $dispatcherRel $_.Exception.Message
}

$excludedFileNames = @('CHANGELOG.md', '998-ideias-descartadas-e-porque.md')
$docFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
try {
    foreach ($file in @(Get-ChildItem -LiteralPath $resolvedRoot -File -Filter '*.md' -ErrorAction Stop | Sort-Object FullName)) { $docFiles.Add($file) }
} catch { Add-ScanIssue 'ROOT_ENUMERATION_ERROR' '.' $_.Exception.Message }

$llmDelegateDir = Join-Path $resolvedRoot 'xpz-llm-delegate'
if (Test-Path -LiteralPath $llmDelegateDir) {
    if (-not (Test-Path -LiteralPath $llmDelegateDir -PathType Container)) {
        Add-ScanIssue 'SUBTREE_NOT_DIRECTORY' 'xpz-llm-delegate' 'O caminho xpz-llm-delegate existe e não é diretório.'
    } else {
        try {
            foreach ($file in @(Get-ChildItem -LiteralPath $llmDelegateDir -Recurse -File -Filter '*.md' -ErrorAction Stop | Sort-Object FullName)) { $docFiles.Add($file) }
        } catch { Add-ScanIssue 'SUBTREE_ENUMERATION_ERROR' 'xpz-llm-delegate' $_.Exception.Message }
    }
}

$backendPatterns = [ordered]@{}
if ($sourceComplete) {
    foreach ($backend in $canonicalBackends) { $backendPatterns[$backend] = Get-BackendRegex $backend }
}

foreach ($docFile in $docFiles) {
    $relPath = ([System.IO.Path]::GetRelativePath($resolvedRoot, $docFile.FullName) -replace '\\', '/')
    $relativeDirectory = [System.IO.Path]::GetDirectoryName($relPath) -replace '\\', '/'
    if ($relativeDirectory -match '(?:^|/)(?:historico|temp|tempo)(?:/|$)' -or $docFile.Name -in $excludedFileNames) { continue }
    $fileIssues = [System.Collections.Generic.List[string]]::new()
    try {
        $units = @(Parse-MarkdownLogicalUnits $docFile.FullName)
        if ($sourceComplete) {
            foreach ($unit in $units) {
                $hasIgnore = $false
                foreach ($line in $unit.RawLines) {
                    if ($line -match '<!--\s*backend-parity:\s*ignore\s*-->' -or $line -match '#\s*backend-parity:\s*ignore') { $hasIgnore = $true; break }
                }
                if ($hasIgnore) { $ignoredCount++; continue }
                $flatText = ($unit.RawLines -join ' ')
                $onUnit = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                foreach ($backend in $canonicalBackends) { if ($backendPatterns[$backend].IsMatch($flatText)) { [void]$onUnit.Add($backend) } }
                if ($onUnit.Count -lt 2 -or $onUnit.Count -ge $canonicalBackends.Count) { continue }
                $listed = Get-OrdinalSortedStrings @($onUnit)
                $missing = @(Get-OrdinalSortedStrings @($canonicalBackends | Where-Object { -not $onUnit.Contains($_) }))
                $unitText = ($unit.RawLines -join "`n")
                $findings.Add([pscustomobject][ordered]@{
                    code = 'BACKEND_ENUMERATION_SUBSET'
                    severity = 'warn'
                    file = $relPath
                    line = [int]$unit.StartLine
                    path = ('{0}:{1}' -f $relPath, $unit.StartLine)
                    unitHash = (Get-Sha256Hex $unitText)
                    listedMembers = @($listed)
                    message = ("enumera {0} de {1} backends canônicos ({2}); se o bloco descreve o conjunto de backends, confirmar se está completo — ausente(s): {3}" -f $onUnit.Count, $canonicalBackends.Count, ($listed -join ', '), ($missing -join ', '))
                })
            }
        }
        $fileStates.Add([pscustomobject][ordered]@{ file = $relPath; complete = $true; status = 'complete'; issues = @() })
    } catch {
        $message = $_.Exception.Message
        $fileIssues.Add($message)
        Add-ScanIssue 'FILE_PROCESSING_ERROR' $relPath $message
        $fileStates.Add([pscustomobject][ordered]@{ file = $relPath; complete = $false; status = 'error'; issues = @($fileIssues) })
    }
}

$scanComplete = ($sourceComplete -and $scanIssues.Count -eq 0)
$allFindings = @($findings)
$displayFindings = @($allFindings | Select-Object -First $MaxFindings)
$displayTruncated = ($allFindings.Count -gt $MaxFindings)
$status = if ($allFindings.Count -gt 0 -or -not $scanComplete) { 'warn' } else { 'pass' }
$result = [ordered]@{
    status = $status
    dispatcher = $dispatcherRel
    canonicalMembers = @(Get-OrdinalSortedStrings @($canonicalBackends))
    canonicalBackends = @(Get-OrdinalSortedStrings @($canonicalBackends))
    scanComplete = $scanComplete
    scanIssues = @($scanIssues)
    files = @($fileStates)
    candidateCount = $allFindings.Count
    ignoredCount = $ignoredCount
    displayTruncated = $displayTruncated
    findings = $allFindings
    displayFindings = $displayFindings
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("SCAN_COMPLETE={0}" -f $scanComplete.ToString().ToLowerInvariant())
    Write-Output ("CANONICAL_BACKENDS={0}" -f (@($result.canonicalMembers) -join ', '))
    Write-Output ("CANDIDATE_COUNT={0}" -f $allFindings.Count)
    Write-Output ("IGNORED_COUNT={0}" -f $ignoredCount)
    foreach ($issue in $scanIssues) { Write-Output ("SCAN_ISSUE: {0} [{1}] {2}" -f $issue.code, $issue.path, $issue.message) }
    foreach ($finding in $displayFindings) { Write-Output ("BACKEND_ENUMERATION_SUBSET: {0}: {1}" -f $finding.path, $finding.message) }
    if ($displayTruncated) { Write-Output ("DISPLAY_TRUNCATED={0}" -f ($allFindings.Count - $MaxFindings)) }
}

exit 0
