#requires -Version 7.4
<#
.SYNOPSIS
    Applies a previously approved Git patch after mechanical path checks.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PatchPath,

    [Parameter(Mandatory = $true)]
    [string[]]$AllowedPath,

    [string]$RepositoryRoot = (Get-Location).Path,

    [switch]$DryRun,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-ResultAndExit {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ok', 'error')]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [string]$Message,

        [hashtable]$Data = @{},

        [int]$ExitCode
    )

    $payload = [ordered]@{
        status  = $Status
        code    = $Code
        message = $Message
    }

    foreach ($entry in $Data.GetEnumerator()) {
        $payload[$entry.Key] = $entry.Value
    }

    if ($AsJson) {
        [pscustomobject]$payload | ConvertTo-Json -Depth 8
    } else {
        '{0}: {1}: {2}' -f $Status.ToUpperInvariant(), $Code, $Message
    }

    exit $ExitCode
}

function Normalize-RelativeGitPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [Parameter(Mandatory = $true)]
        [string]$Code
    )

    $value = $PathValue.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-ResultAndExit -Status error -Code $Code -Message 'Path is empty.' -ExitCode 2
    }

    $value = $value -replace '\\', '/'
    if ($value -eq '.' -or $value -eq '..') {
        Write-ResultAndExit -Status error -Code $Code -Message "Path is not allowed: $PathValue" -ExitCode 2
    }

    if ([System.IO.Path]::IsPathFullyQualified($value) -or [System.IO.Path]::IsPathRooted($value) -or $value.StartsWith('/')) {
        Write-ResultAndExit -Status error -Code $Code -Message "Absolute path is not allowed: $PathValue" -ExitCode 2
    }

    $parts = @($value -split '/')
    foreach ($part in $parts) {
        if ([string]::IsNullOrWhiteSpace($part) -or $part -eq '.' -or $part -eq '..') {
            Write-ResultAndExit -Status error -Code $Code -Message "Path segment is not allowed: $PathValue" -ExitCode 2
        }
    }

    return ($parts -join '/')
}

function Invoke-GitChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = @(& git -C $Root @Arguments 2>&1)
    return [pscustomobject]@{
        exitCode = $LASTEXITCODE
        output   = @($output | ForEach-Object { $_.ToString() })
    }
}

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
} catch {
    Write-ResultAndExit -Status error -Code 'REPOSITORY_ROOT_NOT_FOUND' -Message $_.Exception.Message -ExitCode 2
}

$gitRootResult = Invoke-GitChecked -Root $resolvedRoot -Arguments @('rev-parse', '--show-toplevel')
if ($gitRootResult.exitCode -ne 0 -or $gitRootResult.output.Count -eq 0) {
    Write-ResultAndExit -Status error -Code 'REPOSITORY_ROOT_NOT_GIT' -Message 'RepositoryRoot is not inside a Git repository.' -Data @{ gitOutput = $gitRootResult.output } -ExitCode 2
}

$gitRoot = [System.IO.Path]::GetFullPath($gitRootResult.output[0]).TrimEnd('\', '/')
$candidateRoot = [System.IO.Path]::GetFullPath($resolvedRoot).TrimEnd('\', '/')
if (-not $gitRoot.Equals($candidateRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-ResultAndExit -Status error -Code 'REPOSITORY_ROOT_NOT_GIT_ROOT' -Message 'RepositoryRoot must be the Git repository root.' -Data @{ repositoryRoot = $candidateRoot; gitRoot = $gitRoot } -ExitCode 2
}

try {
    $resolvedPatchPath = (Resolve-Path -LiteralPath $PatchPath).Path
} catch {
    Write-ResultAndExit -Status error -Code 'PATCH_NOT_FOUND' -Message $_.Exception.Message -ExitCode 2
}

if (-not (Test-Path -LiteralPath $resolvedPatchPath -PathType Leaf)) {
    Write-ResultAndExit -Status error -Code 'PATCH_NOT_FILE' -Message 'PatchPath must point to a file.' -ExitCode 2
}

$allowedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($pathItem in $AllowedPath) {
    $normalized = Normalize-RelativeGitPath -PathValue $pathItem -Code 'INVALID_ALLOWED_PATH'
    [void]$allowedSet.Add($normalized)
}

if ($allowedSet.Count -eq 0) {
    Write-ResultAndExit -Status error -Code 'NO_ALLOWED_PATHS' -Message 'At least one AllowedPath is required.' -ExitCode 2
}

$patchText = [System.IO.File]::ReadAllText($resolvedPatchPath, [System.Text.UTF8Encoding]::new($false, $true))
$patchLines = @($patchText -split "`r?`n")

if ($patchText -match '(?m)^GIT binary patch\s*$' -or
    $patchText -match '(?m)^Binary files .+ differ\s*$' -or
    $patchText -match '(?m)^literal \d+\s*$') {
    Write-ResultAndExit -Status error -Code 'BINARY_PATCH_NOT_SUPPORTED' -Message 'Binary patches are not supported.' -ExitCode 3
}

if ($patchText -match '(?m)^rename (from|to) ' -or $patchText -match '(?m)^similarity index ') {
    Write-ResultAndExit -Status error -Code 'RENAME_NOT_SUPPORTED' -Message 'Rename patches are not supported.' -ExitCode 3
}

if ($patchText -match '(?m)^copy (from|to) ') {
    Write-ResultAndExit -Status error -Code 'COPY_NOT_SUPPORTED' -Message 'Copy patches are not supported.' -ExitCode 3
}

$touchedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$headerCount = 0
foreach ($line in $patchLines) {
    $match = [regex]::Match($line, '^diff --git a/(.+) b/(.+)$')
    if (-not $match.Success) {
        continue
    }

    $headerCount++
    $leftPath = Normalize-RelativeGitPath -PathValue $match.Groups[1].Value -Code 'INVALID_PATCH_PATH'
    $rightPath = Normalize-RelativeGitPath -PathValue $match.Groups[2].Value -Code 'INVALID_PATCH_PATH'
    [void]$touchedSet.Add($leftPath)
    [void]$touchedSet.Add($rightPath)
}

$fileHeaderCount = 0
foreach ($line in $patchLines) {
    $fileHeaderMatch = [regex]::Match($line, '^(?<marker>---|\+\+\+) (?<path>.+)$')
    if (-not $fileHeaderMatch.Success) {
        continue
    }

    $fileHeaderCount++
    $rawPath = $fileHeaderMatch.Groups['path'].Value.Trim()
    $tabIndex = $rawPath.IndexOf("`t")
    if ($tabIndex -ge 0) {
        $rawPath = $rawPath.Substring(0, $tabIndex)
    }
    if ($rawPath -eq '/dev/null') {
        continue
    }

    $prefix = if ($fileHeaderMatch.Groups['marker'].Value -eq '---') { 'a/' } else { 'b/' }
    if (-not $rawPath.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
        Write-ResultAndExit -Status error -Code 'INVALID_PATCH_FILE_HEADER' -Message "Patch file header must start with $prefix or be /dev/null." -ExitCode 3
    }
    $headerPath = Normalize-RelativeGitPath -PathValue $rawPath.Substring($prefix.Length) -Code 'INVALID_PATCH_PATH'
    [void]$touchedSet.Add($headerPath)
}

if ($headerCount -eq 0) {
    Write-ResultAndExit -Status error -Code 'PATCH_WITHOUT_STANDARD_HEADER' -Message 'Patch has no standard diff --git a/path b/path header.' -ExitCode 3
}

if ($fileHeaderCount -eq 0) {
    Write-ResultAndExit -Status error -Code 'PATCH_WITHOUT_FILE_HEADERS' -Message 'Patch has no ---/+++ file headers.' -ExitCode 3
}

$notAllowed = @($touchedSet | Where-Object { -not $allowedSet.Contains($_) } | Sort-Object)
if ($notAllowed.Count -gt 0) {
    Write-ResultAndExit -Status error -Code 'PATH_NOT_ALLOWED' -Message 'Patch touches paths outside AllowedPath.' -Data @{ paths = $notAllowed } -ExitCode 4
}

$checkResult = Invoke-GitChecked -Root $resolvedRoot -Arguments @('apply', '--check', '--whitespace=error', $resolvedPatchPath)
if ($checkResult.exitCode -ne 0) {
    Write-ResultAndExit -Status error -Code 'GIT_APPLY_CHECK_FAILED' -Message 'git apply --check failed.' -Data @{ gitOutput = $checkResult.output } -ExitCode 5
}

if ($DryRun) {
    Write-ResultAndExit -Status ok -Code 'DRY_RUN_OK' -Message 'Patch validated without writing.' -Data @{ paths = @($touchedSet | Sort-Object) } -ExitCode 0
}

$applyResult = Invoke-GitChecked -Root $resolvedRoot -Arguments @('apply', '--whitespace=error', $resolvedPatchPath)
if ($applyResult.exitCode -ne 0) {
    Write-ResultAndExit -Status error -Code 'GIT_APPLY_FAILED' -Message 'git apply failed.' -Data @{ gitOutput = $applyResult.output } -ExitCode 6
}

Write-ResultAndExit -Status ok -Code 'APPLIED' -Message 'Patch applied.' -Data @{ paths = @($touchedSet | Sort-Object) } -ExitCode 0
