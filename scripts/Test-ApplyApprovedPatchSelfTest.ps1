#requires -Version 7.4
<#
.SYNOPSIS
    Self-test for Apply-ApprovedPatch.ps1.
#>

[CmdletBinding()]
param(
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = @(& $FilePath @Arguments 2>&1)
    return [pscustomobject]@{
        exitCode = $LASTEXITCODE
        output   = @($output | ForEach-Object { $_.ToString() })
    }
}

function Invoke-ApplyApprovedPatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$PatchPath,

        [Parameter(Mandatory = $true)]
        [string[]]$AllowedPath,

        [switch]$DryRun
    )

    $arguments = @(
        '-NoProfile',
        '-File',
        $script:ApplyScriptPath,
        '-RepositoryRoot',
        $RepositoryRoot,
        '-PatchPath',
        $PatchPath
    )

    foreach ($pathItem in $AllowedPath) {
        $arguments += @('-AllowedPath', $pathItem)
    }

    if ($DryRun) {
        $arguments += '-DryRun'
    }

    $arguments += '-AsJson'
    $result = Invoke-Native -FilePath 'pwsh' -Arguments $arguments
    $json = $null
    try {
        $json = ($result.output -join "`n") | ConvertFrom-Json
    } catch {
        $json = [pscustomobject]@{
            status = 'invalid-json'
            code   = 'INVALID_JSON'
            raw    = $result.output
        }
    }

    return [pscustomobject]@{
        exitCode = $result.exitCode
        json     = $json
        output   = $result.output
    }
}

function Assert-Condition {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function New-TestRepo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root
    )

    New-Item -ItemType Directory -Path $Root | Out-Null
    $init = Invoke-Native -FilePath 'git' -Arguments @('-C', $Root, 'init')
    Assert-Condition -Condition ($init.exitCode -eq 0) -Message "git init failed: $($init.output -join '; ')"
    $configAutocrlf = Invoke-Native -FilePath 'git' -Arguments @('-C', $Root, 'config', 'core.autocrlf', 'false')
    Assert-Condition -Condition ($configAutocrlf.exitCode -eq 0) -Message "git config core.autocrlf failed: $($configAutocrlf.output -join '; ')"

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Join-Path $Root 'allowed.txt'), "one`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $Root 'other.txt'), "base`n", $utf8NoBom)

    $add = Invoke-Native -FilePath 'git' -Arguments @('-C', $Root, 'add', 'allowed.txt', 'other.txt')
    Assert-Condition -Condition ($add.exitCode -eq 0) -Message "git add failed: $($add.output -join '; ')"
}

function New-PatchFromWorktreeChange {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryRoot,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$NewContent,

        [Parameter(Mandatory = $true)]
        [string]$PatchPath,

        [Parameter(Mandatory = $true)]
        [string]$OriginalContent
    )

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Join-Path $RepositoryRoot $RelativePath), $NewContent, $utf8NoBom)
    $diff = Invoke-Native -FilePath 'git' -Arguments @('-C', $RepositoryRoot, 'diff', '--', $RelativePath)
    Assert-Condition -Condition ($diff.exitCode -eq 0) -Message "git diff failed: $($diff.output -join '; ')"
    [System.IO.File]::WriteAllText($PatchPath, (($diff.output -join "`n") + "`n"), $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $RepositoryRoot $RelativePath), $OriginalContent, $utf8NoBom)
}

$script:ApplyScriptPath = Join-Path $PSScriptRoot 'Apply-ApprovedPatch.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ApplyApprovedPatchSelfTest_' + [System.Guid]::NewGuid().ToString('N'))
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$results = [System.Collections.Generic.List[object]]::new()

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null

    $dryRunRepo = Join-Path $tempRoot 'dry-run'
    New-TestRepo -Root $dryRunRepo
    $dryRunPatch = Join-Path $tempRoot 'dry-run.patch'
    New-PatchFromWorktreeChange -RepositoryRoot $dryRunRepo -RelativePath 'allowed.txt' -NewContent "two`n" -PatchPath $dryRunPatch -OriginalContent "one`n"
    $dryRunResult = Invoke-ApplyApprovedPatch -RepositoryRoot $dryRunRepo -PatchPath $dryRunPatch -AllowedPath @('allowed.txt') -DryRun
    $dryRunContent = [System.IO.File]::ReadAllText((Join-Path $dryRunRepo 'allowed.txt'), [System.Text.UTF8Encoding]::new($false, $true))
    Assert-Condition -Condition ($dryRunResult.exitCode -eq 0 -and $dryRunResult.json.code -eq 'DRY_RUN_OK') -Message 'DryRun did not return DRY_RUN_OK.'
    Assert-Condition -Condition ($dryRunContent -eq "one`n") -Message 'DryRun wrote to the repository.'
    $results.Add([pscustomobject]@{ name = 'DryRun does not write'; status = 'pass' }) | Out-Null

    $applyRepo = Join-Path $tempRoot 'apply'
    New-TestRepo -Root $applyRepo
    $applyPatch = Join-Path $tempRoot 'apply.patch'
    New-PatchFromWorktreeChange -RepositoryRoot $applyRepo -RelativePath 'allowed.txt' -NewContent "two`n" -PatchPath $applyPatch -OriginalContent "one`n"
    $applyResult = Invoke-ApplyApprovedPatch -RepositoryRoot $applyRepo -PatchPath $applyPatch -AllowedPath @('allowed.txt')
    $applyContent = [System.IO.File]::ReadAllText((Join-Path $applyRepo 'allowed.txt'), [System.Text.UTF8Encoding]::new($false, $true))
    Assert-Condition -Condition ($applyResult.exitCode -eq 0 -and $applyResult.json.code -eq 'APPLIED') -Message 'Allowed patch did not return APPLIED.'
    Assert-Condition -Condition ($applyContent -eq "two`n") -Message 'Allowed patch did not modify the file.'
    $results.Add([pscustomobject]@{ name = 'Allowed patch writes'; status = 'pass' }) | Out-Null

    $blockedRepo = Join-Path $tempRoot 'blocked'
    New-TestRepo -Root $blockedRepo
    $blockedPatch = Join-Path $tempRoot 'blocked.patch'
    New-PatchFromWorktreeChange -RepositoryRoot $blockedRepo -RelativePath 'other.txt' -NewContent "changed`n" -PatchPath $blockedPatch -OriginalContent "base`n"
    $blockedResult = Invoke-ApplyApprovedPatch -RepositoryRoot $blockedRepo -PatchPath $blockedPatch -AllowedPath @('allowed.txt')
    $blockedContent = [System.IO.File]::ReadAllText((Join-Path $blockedRepo 'other.txt'), [System.Text.UTF8Encoding]::new($false, $true))
    Assert-Condition -Condition ($blockedResult.exitCode -ne 0 -and $blockedResult.json.code -eq 'PATH_NOT_ALLOWED') -Message 'Out-of-scope patch did not return PATH_NOT_ALLOWED.'
    Assert-Condition -Condition ($blockedContent -eq "base`n") -Message 'Out-of-scope patch wrote to the repository.'
    $results.Add([pscustomobject]@{ name = 'Out-of-scope path is blocked'; status = 'pass' }) | Out-Null

    $headerMismatchRepo = Join-Path $tempRoot 'header-mismatch'
    New-TestRepo -Root $headerMismatchRepo
    $headerMismatchPatch = Join-Path $tempRoot 'header-mismatch.patch'
    New-PatchFromWorktreeChange -RepositoryRoot $headerMismatchRepo -RelativePath 'other.txt' -NewContent "changed`n" -PatchPath $headerMismatchPatch -OriginalContent "base`n"
    $headerMismatchText = [System.IO.File]::ReadAllText($headerMismatchPatch, [System.Text.UTF8Encoding]::new($false, $true))
    $headerMismatchText = $headerMismatchText.Replace('diff --git a/other.txt b/other.txt', 'diff --git a/allowed.txt b/allowed.txt')
    [System.IO.File]::WriteAllText($headerMismatchPatch, $headerMismatchText, $utf8NoBom)
    $headerMismatchResult = Invoke-ApplyApprovedPatch -RepositoryRoot $headerMismatchRepo -PatchPath $headerMismatchPatch -AllowedPath @('allowed.txt')
    $headerMismatchContent = [System.IO.File]::ReadAllText((Join-Path $headerMismatchRepo 'other.txt'), [System.Text.UTF8Encoding]::new($false, $true))
    Assert-Condition -Condition ($headerMismatchResult.exitCode -ne 0 -and $headerMismatchResult.json.code -eq 'PATH_NOT_ALLOWED') -Message 'Mismatched ---/+++ headers did not return PATH_NOT_ALLOWED.'
    Assert-Condition -Condition ($headerMismatchContent -eq "base`n") -Message 'Mismatched ---/+++ headers wrote to the repository.'
    $results.Add([pscustomobject]@{ name = 'Mismatched file headers are blocked'; status = 'pass' }) | Out-Null
    $headerRepo = Join-Path $tempRoot 'missing-header'
    New-TestRepo -Root $headerRepo
    $missingHeaderPatch = Join-Path $tempRoot 'missing-header.patch'
    [System.IO.File]::WriteAllText($missingHeaderPatch, "@@ -1 +1 @@`n-one`n+two`n", $utf8NoBom)
    $missingHeaderResult = Invoke-ApplyApprovedPatch -RepositoryRoot $headerRepo -PatchPath $missingHeaderPatch -AllowedPath @('allowed.txt')
    Assert-Condition -Condition ($missingHeaderResult.exitCode -ne 0 -and $missingHeaderResult.json.code -eq 'PATCH_WITHOUT_STANDARD_HEADER') -Message 'Patch without header did not return PATCH_WITHOUT_STANDARD_HEADER.'
    $results.Add([pscustomobject]@{ name = 'Patch without header is blocked'; status = 'pass' }) | Out-Null

    $payload = [ordered]@{
        status = 'pass'
        code   = 'SELFTEST_OK'
        tests  = @($results)
    }

    if ($AsJson) {
        [pscustomobject]$payload | ConvertTo-Json -Depth 6
    } else {
        'SELFTEST_OK'
        foreach ($result in $results) {
            'PASS: {0}' -f $result.name
        }
    }

    exit 0
} catch {
    $payload = [ordered]@{
        status  = 'fail'
        code    = 'SELFTEST_FAILED'
        message = $_.Exception.Message
        tests   = @($results)
    }

    if ($AsJson) {
        [pscustomobject]$payload | ConvertTo-Json -Depth 6
    } else {
        'SELFTEST_FAILED: {0}' -f $_.Exception.Message
    }

    exit 1
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
