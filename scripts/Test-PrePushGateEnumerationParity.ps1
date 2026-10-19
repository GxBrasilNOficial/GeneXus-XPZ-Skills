#requires -Version 7.4

<#
.SYNOPSIS
    Gate consultivo de enumerações documentais dos gates da pré-push.

.DESCRIPTION
    Deriva por AST os gates invocados pelo orquestrador, exceto o par fixo de
    parse, e percorre integralmente os Markdown da raiz. Extração, enumeração,
    leitura ou processamento incompleto deixa scanComplete=false. O limite afeta
    apenas displayFindings; findings contém a coleta integral.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path,
    [string]$BaseRef = 'origin/main',
    [AllowEmptyCollection()][string[]]$ChangedFiles = @(),
    [ValidateRange(1, 500)][int]$MaxFindings = 30,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
$orchestratorRel = 'scripts/Invoke-PrePushMechanicalChecks.ps1'
$orchestratorPath = Join-Path $resolvedRoot $orchestratorRel
$findings = [System.Collections.Generic.List[object]]::new()
$scanIssues = [System.Collections.Generic.List[object]]::new()
$fileStates = [System.Collections.Generic.List[object]]::new()
$orchestratorGates = [System.Collections.Generic.List[string]]::new()
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

$gateNamePattern = [regex]::new('^\s*Join-Path\s+\$PSScriptRoot\s+[''\"](?<name>Test-[A-Za-z0-9.\-]+\.ps1)[''\"]\s*$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
try {
    if (-not (Test-Path -LiteralPath $orchestratorPath -PathType Leaf)) {
        Add-ScanIssue 'CANONICAL_SOURCE_MISSING' $orchestratorRel 'Orquestrador ausente.'
    } else {
        $tokens = $null
        $parserErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($orchestratorPath, [ref]$tokens, [ref]$parserErrors)
        if (@($parserErrors).Count -gt 0) {
            Add-ScanIssue 'CANONICAL_SOURCE_PARSE_ERROR' $orchestratorRel ((@($parserErrors | ForEach-Object { $_.Message }) -join '; '))
        } else {
            $assignmentMap = @{}
            $assignments = @($ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left -is [System.Management.Automation.Language.VariableExpressionAst]
            }, $true))
            foreach ($assignment in $assignments) {
                $varName = $assignment.Left.VariablePath.UserPath
                if (-not $assignmentMap.ContainsKey($varName)) { $assignmentMap[$varName] = [System.Collections.Generic.List[object]]::new() }
                $assignmentMap[$varName].Add($assignment)
            }

            $recognizedInvocations = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            $sourceValid = $true
            $commands = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))
            foreach ($command in $commands) {
                if ($command.GetCommandName() -eq 'Invoke-EnumerationGate') {
                    $elements = @($command.CommandElements)
                    $scriptRelIndex = -1
                    for ($elementIndex = 1; $elementIndex -lt $elements.Count; $elementIndex++) {
                        if ($elements[$elementIndex].Extent.Text -eq '-ScriptRel') { $scriptRelIndex = $elementIndex + 1; break }
                    }
                    if ($scriptRelIndex -lt 0 -or $scriptRelIndex -ge $elements.Count -or
                        $elements[$scriptRelIndex] -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -or
                        $elements[$scriptRelIndex].Value -notmatch '^scripts/(Test-[A-Za-z0-9.\-]+\.ps1)$') {
                        Add-ScanIssue 'UNSUPPORTED_GATE_INVOKER' $orchestratorRel 'Invoke-EnumerationGate precisa receber -ScriptRel com caminho literal scripts/Test-*.ps1.'
                        $sourceValid = $false
                    } else {
                        $invokedGate = $Matches[1]
                        if ($invokedGate -notmatch 'ScriptsParse\.ps1$') { [void]$recognizedInvocations.Add($invokedGate) }
                    }
                    continue
                }
                if ($command.InvocationOperator -ne [System.Management.Automation.Language.TokenKind]::Ampersand) { continue }
                if ($command.CommandElements.Count -eq 0) { continue }
                $target = $command.CommandElements[0]
                if ($target -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    $varName = $target.VariablePath.UserPath
                    if (-not $assignmentMap.ContainsKey($varName) -or $assignmentMap[$varName].Count -ne 1) {
                        Add-ScanIssue 'DYNAMIC_GATE_INVOCATION' $orchestratorRel ("Invocação por variável sem atribuição única reconhecida: & {0}." -f $varName)
                        $sourceValid = $false
                        continue
                    }
                    $rightText = [string]$assignmentMap[$varName][0].Right.Extent.Text
                    $match = $gateNamePattern.Match($rightText)
                    if (-not $match.Success) {
                        Add-ScanIssue 'UNSUPPORTED_GATE_INVOCATION' $orchestratorRel ("Atribuição de {0} não usa o formato literal Join-Path reconhecido." -f $varName)
                        $sourceValid = $false
                        continue
                    }
                    $name = $match.Groups['name'].Value
                    if ($name -match 'ScriptsParse\.ps1$') { continue }
                    [void]$recognizedInvocations.Add($name)
                } elseif ($target.Extent.Text -match 'Test-[A-Za-z0-9.\-]+\.ps1') {
                    Add-ScanIssue 'UNSUPPORTED_LITERAL_GATE_INVOCATION' $orchestratorRel 'Invocação literal direta de gate não suportada; use a atribuição literal Join-Path e variável reconhecida.'
                    $sourceValid = $false
                }
            }

            foreach ($command in $commands) {
                if ($command.GetCommandName() -in @('Invoke-Expression', 'iex')) {
                    Add-ScanIssue 'DYNAMIC_GATE_EXECUTION' $orchestratorRel 'Invoke-Expression/iex impede demonstrar a enumeração completa dos gates.'
                    $sourceValid = $false
                    break
                }
            }
            foreach ($name in $recognizedInvocations) { $orchestratorGates.Add($name) }
            if ($orchestratorGates.Count -lt 2) {
                Add-ScanIssue 'CANONICAL_SET_TOO_SMALL' $orchestratorRel 'Menos de dois gates consultivos reconhecidos no orquestrador.'
                $sourceValid = $false
            }
            if ($sourceValid) { $sourceComplete = $true }
        }
    }
} catch {
    Add-ScanIssue 'CANONICAL_SOURCE_ERROR' $orchestratorRel $_.Exception.Message
}

$docFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
try {
    foreach ($file in @(Get-ChildItem -LiteralPath $resolvedRoot -File -Filter '*.md' -ErrorAction Stop | Sort-Object FullName)) { $docFiles.Add($file) }
} catch { Add-ScanIssue 'ROOT_ENUMERATION_ERROR' '.' $_.Exception.Message }

$gateSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($name in $orchestratorGates) { [void]$gateSet.Add($name) }
$nameTokenRegex = [regex]::new('Test-[A-Za-z0-9.\-]+\.ps1')
foreach ($docFile in $docFiles) {
    $relPath = $docFile.Name
    $fileIssues = [System.Collections.Generic.List[string]]::new()
    try {
        $lines = @([System.IO.File]::ReadAllLines($docFile.FullName))
        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            $text = $lines[$lineIndex]
            $onLine = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            foreach ($match in $nameTokenRegex.Matches($text)) {
                if ($gateSet.Contains($match.Value)) { [void]$onLine.Add($match.Value) }
            }
            if ($onLine.Count -lt 2 -or $onLine.Count -ge $orchestratorGates.Count) { continue }
            $listed = Get-OrdinalSortedStrings @($onLine)
            $missing = @(Get-OrdinalSortedStrings @($orchestratorGates | Where-Object { -not $onLine.Contains($_) }))
            $lineNumber = $lineIndex + 1
            $findings.Add([pscustomobject][ordered]@{
                code = 'GATE_ENUMERATION_SUBSET'
                severity = 'warn'
                file = $relPath
                line = $lineNumber
                path = ('{0}:{1}' -f $relPath, $lineNumber)
                unitHash = (Get-Sha256Hex $text)
                listedMembers = @($listed)
                message = ("enumera {0} de {1} gates do orquestrador ({2}); se a frase descreve o conjunto de gates, confirmar se está completa — ausente(s): {3}" -f $onLine.Count, $orchestratorGates.Count, ($listed -join ', '), ($missing -join ', '))
            })
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
$canonicalSorted = @(Get-OrdinalSortedStrings @($orchestratorGates))
$result = [ordered]@{
    status = $status
    orchestrator = $orchestratorRel
    canonicalMembers = $canonicalSorted
    orchestratorGates = $canonicalSorted
    scanComplete = $scanComplete
    scanIssues = @($scanIssues)
    files = @($fileStates)
    candidateCount = $allFindings.Count
    displayTruncated = $displayTruncated
    findings = $allFindings
    displayFindings = $displayFindings
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("STATUS={0}" -f $status)
    Write-Output ("SCAN_COMPLETE={0}" -f $scanComplete.ToString().ToLowerInvariant())
    Write-Output ("ORCHESTRATOR_GATES={0}" -f ($canonicalSorted -join ', '))
    Write-Output ("CANDIDATE_COUNT={0}" -f $allFindings.Count)
    foreach ($issue in $scanIssues) { Write-Output ("SCAN_ISSUE: {0} [{1}] {2}" -f $issue.code, $issue.path, $issue.message) }
    foreach ($finding in $displayFindings) { Write-Output ("GATE_ENUMERATION_SUBSET: {0}: {1}" -f $finding.path, $finding.message) }
    if ($displayTruncated) { Write-Output ("DISPLAY_TRUNCATED={0}" -f ($allFindings.Count - $MaxFindings)) }
}

exit 0
