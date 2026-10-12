#requires -Version 7.4

<#
.SYNOPSIS
    Parses repository PowerShell scripts and reports syntax errors.

.DESCRIPTION
    Checks scripts/*.ps1, scripts-maintenance/*.ps1 and every *.example.ps1 outside historico/.
    This is a syntax-only gate for the repository runtime contract: pwsh 7.4+.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-IsUnderPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath,

        [Parameter(Mandatory = $true)]
        [string]$ParentPath
    )

    $candidate = [System.IO.Path]::GetFullPath($CandidatePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $parent = [System.IO.Path]::GetFullPath($ParentPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    return $candidate.Equals($parent, [System.StringComparison]::OrdinalIgnoreCase) -or
        $candidate.StartsWith($parent + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
        $candidate.StartsWith($parent + [System.IO.Path]::AltDirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-RelativeDisplayPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    return [System.IO.Path]::GetRelativePath(
        [System.IO.Path]::GetFullPath($BasePath),
        [System.IO.Path]::GetFullPath($TargetPath)
    )
}

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
$scriptsPath = Join-Path $resolvedRoot "scripts"
$maintenanceScriptsPath = Join-Path $resolvedRoot "scripts-maintenance"
$historicoPath = Join-Path $resolvedRoot "historico"

if (-not (Test-Path -LiteralPath $scriptsPath -PathType Container)) {
    throw "scripts directory not found: $scriptsPath"
}

$scriptFiles = @(Get-ChildItem -LiteralPath $scriptsPath -File -Filter "*.ps1" | Sort-Object FullName)
$maintenanceScriptFiles = @()
if (Test-Path -LiteralPath $maintenanceScriptsPath -PathType Container) {
    $maintenanceScriptFiles = @(Get-ChildItem -LiteralPath $maintenanceScriptsPath -File -Filter "*.ps1" | Sort-Object FullName)
}
$exampleFiles = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter "*.example.ps1" |
    Where-Object { -not (Test-IsUnderPath -CandidatePath $_.FullName -ParentPath $historicoPath) } |
    Sort-Object FullName)
$files = @($scriptFiles + $maintenanceScriptFiles + $exampleFiles)

$findings = [System.Collections.Generic.List[object]]::new()

foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

    foreach ($parseError in @($parseErrors)) {
        $findings.Add([pscustomobject]@{
            file    = Get-RelativeDisplayPath -BasePath $resolvedRoot -TargetPath $file.FullName
            line    = $parseError.Extent.StartLineNumber
            column  = $parseError.Extent.StartColumnNumber
            message = $parseError.Message
        }) | Out-Null
    }
}

$result = [ordered]@{
    rootPath   = $resolvedRoot
    status     = if ($findings.Count -eq 0) { "pass" } else { "fail" }
    fileCount  = $files.Count
    errorCount = $findings.Count
    findings   = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    foreach ($finding in $findings) {
        "PARSE_ERROR: {0}:{1}:{2}: {3}" -f $finding.file, $finding.line, $finding.column, $finding.message
    }
    "FILES={0}; ERRORS={1}" -f $files.Count, $findings.Count
}

if ($findings.Count -gt 0) {
    exit 1
}

exit 0
