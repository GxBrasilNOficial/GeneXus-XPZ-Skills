#requires -Version 7.4
<#
.SYNOPSIS
    Stages and applies an approved textual Git patch without Codex apply_patch.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string]$RepositoryRoot,
    [Parameter(Mandatory = $true)] [string[]]$AllowedPath,
    [switch]$DryRun,
    [string]$StagedPatchId,
    [string]$ExpectedPatchSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ExitCodes = @{ INTERNAL_ERROR = 1; INVALID_INPUT = 2; MALFORMED_PATCH = 3; PATH_NOT_ALLOWED = 4; GIT_PREFLIGHT_FAILED = 5; GIT_APPLY_FAILED = 6; BINARY_PATCH_REJECTED = 7; RENAME_OR_COPY_REJECTED = 8; NON_TEXTUAL_MODE_REJECTED = 9; PATCH_HASH_MISMATCH = 10; STAGED_PATCH_NOT_FOUND_OR_EXPIRED = 11; STAGED_PATCH_CONSUMING = 12; REPOSITORY_CONTEXT_CHANGED = 13; STAGED_PATCH_ALREADY_APPLIED = 14; GIT_INDEX_HAS_STAGED_CHANGES = 15 }

function Write-Result {
    param([string]$Status, [string]$Code, [string]$Message, [hashtable]$Data = @{})
    $payload = [ordered]@{ kind = 'apply-approved-patch-result'; schemaVersion = 2; status = $Status; code = $Code; message = $Message }
    foreach ($entry in $Data.GetEnumerator()) { $payload[$entry.Key] = $entry.Value }
    [Console]::Out.WriteLine(([pscustomobject]$payload | ConvertTo-Json -Compress -Depth 12))
}

function Stop-Result {
    param([string]$Code, [string]$Message, [hashtable]$Data = @{})
    Write-Result -Status 'error' -Code $Code -Message $Message -Data $Data
    exit $script:ExitCodes[$Code]
}

function Invoke-Git {
    param([string]$Root, [string[]]$Arguments)
    $output = @(& git -C $Root @Arguments 2>&1)
    [pscustomobject]@{ exitCode = $LASTEXITCODE; output = @($output | ForEach-Object { $_.ToString() }) }
}

function Get-Sha256 {
    param([byte[]]$Bytes)
    ([System.Security.Cryptography.SHA256]::HashData($Bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Normalize-Path {
    param([string]$Value, [string]$Code = 'INVALID_INPUT')
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -match '[\s\t]' -or $Value.Contains([char]0)) { Stop-Result $Code "Invalid path: $Value" }
    $path = $Value.Replace('\', '/')
    if ($path.StartsWith('/') -or [IO.Path]::IsPathRooted($path) -or $path -match '^[A-Za-z]:' -or $path -eq '.' -or $path -eq '..') { Stop-Result $Code "Path must be a relative Git path: $Value" }
    $parts = @($path -split '/')
    if ($parts.Count -eq 0 -or @($parts | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) { Stop-Result $Code "Invalid path segments: $Value" }
    return $parts -join '/'
}

function Get-RepositoryContext {
    param([string]$Root)
    try { $candidate = (Resolve-Path -LiteralPath $Root).Path } catch { Stop-Result 'INVALID_INPUT' $_.Exception.Message }
    $top = Invoke-Git $candidate @('rev-parse', '--show-toplevel')
    $bare = Invoke-Git $candidate @('rev-parse', '--is-bare-repository')
    $head = Invoke-Git $candidate @('rev-parse', '--verify', 'HEAD')
    $branch = Invoke-Git $candidate @('symbolic-ref', '--quiet', '--short', 'HEAD')
    $gitDir = Invoke-Git $candidate @('rev-parse', '--absolute-git-dir')
    if ($top.exitCode -ne 0 -or $bare.exitCode -ne 0 -or $head.exitCode -ne 0 -or $branch.exitCode -ne 0 -or $gitDir.exitCode -ne 0) { Stop-Result 'GIT_PREFLIGHT_FAILED' 'Repository must be a non-detached Git work tree.' }
    $rootFull = [IO.Path]::GetFullPath($candidate).TrimEnd('\','/')
    $topFull = [IO.Path]::GetFullPath($top.output[0]).TrimEnd('\','/')
    if (-not $rootFull.Equals($topFull, [StringComparison]::OrdinalIgnoreCase) -or $bare.output[0] -ne 'false' -or $branch.output[0] -ne 'main') { Stop-Result 'GIT_PREFLIGHT_FAILED' 'RepositoryRoot must be a non-bare main work tree root.' }
    [pscustomobject]@{ root = $rootFull; head = $head.output[0]; gitDir = $gitDir.output[0]; branch = $branch.output[0] }
}

function Test-TextBytes {
    param([byte[]]$Bytes, [string]$Path)
    if ($Bytes -contains 0) { Stop-Result 'MALFORMED_PATCH' "NUL byte is not allowed in $Path." }
    try { [void]([Text.UTF8Encoding]::new($false, $true).GetString($Bytes)) } catch { Stop-Result 'MALFORMED_PATCH' "Only valid UTF-8 text is allowed: $Path." }
}

function Get-PatchPaths {
    param([byte[]]$PatchBytes)
    if ($PatchBytes.Length -gt 16MB) { Stop-Result 'INVALID_INPUT' 'Decoded patch exceeds 16 MiB.' }
    try { $text = [Text.UTF8Encoding]::new($false, $true).GetString($PatchBytes) } catch { Stop-Result 'MALFORMED_PATCH' 'Patch must decode as valid UTF-8 unified diff text.' }
    if ($text -match '(?m)^(GIT binary patch|Binary files .+ differ|literal \d+)\s*$') { Stop-Result 'BINARY_PATCH_REJECTED' 'Binary patch is not supported.' }
    if ($text -match '(?m)^(similarity index|rename from|rename to|copy from|copy to) ') { Stop-Result 'RENAME_OR_COPY_REJECTED' 'Rename and copy patches are not supported.' }
    if ($text -match '(?m)^(old mode|new mode) ' -or $text -match '(?m)^(new file mode|deleted file mode) (?!100644$)') { Stop-Result 'NON_TEXTUAL_MODE_REJECTED' 'Only regular 100644 textual files are supported.' }
    $set = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $headers = [regex]::Matches($text, '(?m)^diff --git a/([^\s\t]+) b/([^\s\t]+)$')
    if ($headers.Count -eq 0) { Stop-Result 'MALFORMED_PATCH' 'Patch has no standard diff header.' }
    foreach ($header in $headers) { [void]$set.Add((Normalize-Path $header.Groups[1].Value 'MALFORMED_PATCH')); [void]$set.Add((Normalize-Path $header.Groups[2].Value 'MALFORMED_PATCH')) }
    foreach ($line in @($text -split "`n")) {
        if ($line -match '^(---|\+\+\+) (.+)$') {
            $raw = $Matches[2].TrimEnd("`r")
            if ($raw -eq '/dev/null') { continue }
            if ($raw -notmatch '^[ab]/[^\s\t]+$') { Stop-Result 'MALFORMED_PATCH' "Invalid file header: $line" }
            [void]$set.Add((Normalize-Path $raw.Substring(2) 'MALFORMED_PATCH'))
        }
    }
    if ($set.Contains('.gitattributes')) { Stop-Result 'PATH_NOT_ALLOWED' 'Patches touching .gitattributes are not supported.' }
    return @($set | Sort-Object)
}

function Test-EffectiveAttributes {
    param([string]$Root, [string[]]$Paths)
    foreach ($path in $Paths) {
        $result = Invoke-Git $Root @('check-attr', '-a', '--', $path)
        if ($result.exitCode -ne 0) { Stop-Result 'GIT_PREFLIGHT_FAILED' "git check-attr failed for $path." }
        foreach ($line in $result.output) {
            if ($line -match ': (filter|ident|working-tree-encoding): (?!unspecified$)') { Stop-Result 'MALFORMED_PATCH' "Transforming Git attribute is not allowed for $path." }
        }
    }
}

function Get-PreImages {
    param([string]$Root, [string[]]$Paths)
    $items = @()
    foreach ($path in $Paths) {
        $index = Invoke-Git $Root @('diff', '--cached', '--quiet', '--', $path)
        if ($index.exitCode -eq 1) { Stop-Result 'GIT_INDEX_HAS_STAGED_CHANGES' "Index has staged changes in $path." }
        $unmerged = Invoke-Git $Root @('ls-files', '-u', '--', $path)
        if ($unmerged.exitCode -ne 0 -or $unmerged.output.Count -gt 0) { Stop-Result 'GIT_INDEX_HAS_STAGED_CHANGES' "Index has unmerged entries in $path." }
        $absolute = Join-Path $Root $path.Replace('/', '\')
        if (Test-Path -LiteralPath $absolute -PathType Leaf) {
            $bytes = [IO.File]::ReadAllBytes($absolute); Test-TextBytes $bytes $path
            $items += [pscustomobject]@{ path = $path; exists = $true; sha256 = Get-Sha256 $bytes }
        } elseif (Test-Path -LiteralPath $absolute) { Stop-Result 'MALFORMED_PATCH' "Path is not a regular file: $path" }
        else { $items += [pscustomobject]@{ path = $path; exists = $false; sha256 = $null } }
    }
    return @($items)
}

function Get-StageRoot {
    $temp = [IO.Path]::GetTempPath()
    if ($temp.StartsWith('\\')) { Stop-Result 'INTERNAL_ERROR' 'UNC temp paths are not supported.' }
    $root = Join-Path $temp 'GeneXus-XPZ-ApprovedPatch'
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    return $root
}

function Test-ManifestContext {
    param($Manifest, $Context, [string[]]$Allowed)
    if ($Manifest.repositoryRoot -ne $Context.root -or $Manifest.head -ne $Context.head -or $Manifest.gitDir -ne $Context.gitDir) { Stop-Result 'REPOSITORY_CONTEXT_CHANGED' 'Repository identity or HEAD changed after dry-run.' }
    $expected = @($Manifest.paths | Sort-Object); $actual = @($Allowed | Sort-Object)
    if (($expected -join "`0") -ne ($actual -join "`0")) { Stop-Result 'PATH_NOT_ALLOWED' 'AllowedPath must exactly match the staged patch path set.' }
    Test-EffectiveAttributes $Context.root $expected
    foreach ($entry in $Manifest.preImages) {
        $absolute = Join-Path $Context.root $entry.path.Replace('/', '\')
        $exists = Test-Path -LiteralPath $absolute -PathType Leaf
        if ([bool]$entry.exists -ne [bool]$exists) { Stop-Result 'REPOSITORY_CONTEXT_CHANGED' "Pre-image existence changed: $($entry.path)" }
        if ($exists -and (Get-Sha256 ([IO.File]::ReadAllBytes($absolute))) -ne $entry.sha256) { Stop-Result 'REPOSITORY_CONTEXT_CHANGED' "Pre-image bytes changed: $($entry.path)" }
    }
}

try {
    if ($DryRun -and -not [string]::IsNullOrEmpty($StagedPatchId)) { Stop-Result 'INVALID_INPUT' 'DryRun cannot receive StagedPatchId.' }
    if (-not $DryRun -and ([string]::IsNullOrWhiteSpace($StagedPatchId) -or [string]::IsNullOrWhiteSpace($ExpectedPatchSha256))) { Stop-Result 'INVALID_INPUT' 'Apply requires StagedPatchId and ExpectedPatchSha256.' }
    $context = Get-RepositoryContext $RepositoryRoot
    $allowedSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in $AllowedPath) { [void]$allowedSet.Add((Normalize-Path $item)) }
    if ($allowedSet.Count -eq 0) { Stop-Result 'INVALID_INPUT' 'At least one AllowedPath is required.' }
    $allowed = @($allowedSet | Sort-Object)
    if ($DryRun) {
        $base64 = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($base64) -or $base64 -match '\s' -or $base64 -notmatch '^[A-Za-z0-9+/]*={0,2}$' -or ($base64.Length % 4) -ne 0) { Stop-Result 'INVALID_INPUT' 'stdin must be contiguous padded Base64 ASCII; use StandardInput.Write(...) then StandardInput.Close(), without newline or other whitespace.' }
        try { $patchBytes = [Convert]::FromBase64String($base64) } catch { Stop-Result 'INVALID_INPUT' 'stdin is not valid Base64.' }
        $paths = Get-PatchPaths $patchBytes
        if (($paths -join "`0") -ne ($allowed -join "`0")) { Stop-Result 'PATH_NOT_ALLOWED' 'AllowedPath must exactly match all patch paths.' }
        Test-EffectiveAttributes $context.root $paths
        $preImages = Get-PreImages $context.root $paths
        $stageId = [Guid]::NewGuid().ToString('N'); $stage = Join-Path (Get-StageRoot) $stageId; New-Item -ItemType Directory -Path $stage | Out-Null
        $patchPath = Join-Path $stage 'patch.diff'; [IO.File]::WriteAllBytes($patchPath, $patchBytes)
        $check = Invoke-Git $context.root @('apply', '--check', '--whitespace=error', $patchPath)
        if ($check.exitCode -ne 0) { Stop-Result 'GIT_APPLY_FAILED' 'git apply --check failed.' @{ diagnostic = $check.output } }
        $hash = Get-Sha256 $patchBytes; $manifest = [ordered]@{ schemaVersion = 2; stagedPatchId = $stageId; repositoryRoot = $context.root; gitDir = $context.gitDir; head = $context.head; paths = $paths; patchSha256 = $hash; expiresUtc = [DateTime]::UtcNow.AddMinutes(15).ToString('O'); preImages = $preImages; state = 'ready' }
        [IO.File]::WriteAllText((Join-Path $stage 'manifest.json'), (($manifest | ConvertTo-Json -Compress -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
        Write-Result 'ok' 'DRY_RUN_OK' 'Patch staged without writing.' @{ stagedPatchId = $stageId; patchSha256 = $hash; expiresUtc = $manifest.expiresUtc; state = 'ready'; paths = $paths; head = $context.head }; exit 0
    }
    if ($StagedPatchId -notmatch '^[0-9a-f]{32}$') { Stop-Result 'INVALID_INPUT' 'StagedPatchId must be a lowercase GUID without separators.' }
    $stage = Join-Path (Get-StageRoot) $StagedPatchId; $manifestPath = Join-Path $stage 'manifest.json'; $patchPath = Join-Path $stage 'patch.diff'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or -not (Test-Path -LiteralPath $patchPath -PathType Leaf)) { Stop-Result 'STAGED_PATCH_NOT_FOUND_OR_EXPIRED' 'Staged patch is not available.' }
    $lockPath = Join-Path $stage 'consuming.lock'; try { $lock = [IO.File]::Open($lockPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) } catch { Stop-Result 'STAGED_PATCH_CONSUMING' 'Staged patch is already being consumed.' }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if (([DateTime]$manifest.expiresUtc).ToUniversalTime() -lt [DateTime]::UtcNow) { Stop-Result 'STAGED_PATCH_NOT_FOUND_OR_EXPIRED' 'Staged patch expired.' }
        $bytes = [IO.File]::ReadAllBytes($patchPath); $hash = Get-Sha256 $bytes
        if ($hash -ne $manifest.patchSha256 -or $hash -ne $ExpectedPatchSha256.ToLowerInvariant()) { Stop-Result 'PATCH_HASH_MISMATCH' 'Patch hash does not match manifest and expected value.' }
        Test-ManifestContext $manifest $context $allowed
        $apply = Invoke-Git $context.root @('apply', '--whitespace=error', $patchPath)
        if ($apply.exitCode -ne 0) { Stop-Result 'GIT_APPLY_FAILED' 'git apply failed; staged evidence was retained.' @{ diagnostic = $apply.output } }
        $receipt = [ordered]@{ schemaVersion = 2; stagedPatchId = $StagedPatchId; patchSha256 = $hash; appliedUtc = [DateTime]::UtcNow.ToString('O'); head = $context.head; postImages = Get-PreImages $context.root @($manifest.paths) }
        [IO.File]::WriteAllText((Join-Path $stage 'receipt.json'), (($receipt | ConvertTo-Json -Compress -Depth 12) + "`n"), [Text.UTF8Encoding]::new($false))
        Write-Result 'ok' 'APPLIED' 'Patch applied.' @{ stagedPatchId = $StagedPatchId; patchSha256 = $hash; head = $context.head; receiptRetained = $true; paths = @($manifest.paths) }; exit 0
    } finally { if ($null -ne $lock) { $lock.Dispose() }; Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    Write-Result 'error' 'INTERNAL_ERROR' 'Unexpected internal error.'
    exit $script:ExitCodes.INTERNAL_ERROR
}
