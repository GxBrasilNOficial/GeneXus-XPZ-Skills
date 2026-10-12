#requires -Version 7.4

<#
.SYNOPSIS
    Calcula a assinatura deterministica do contrato de setup de pasta paralela da KB.

.DESCRIPTION
    A assinatura cobre apenas a superficie metodologica de xpz-kb-parallel-setup
    declarada em xpz-kb-parallel-setup/setup-contract.manifest.json.
    Conteúdo textual e normalizado para LF antes do hash para evitar diferenca
    artificial entre checkouts Windows e Unix.
#>

[CmdletBinding()]
param(
    [string]$SkillsRoot,

    [string]$ManifestPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DefaultSkillsRoot {
    return (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
}

function ConvertTo-RepoRelativePath {
    param(
        [string]$RootPath,
        [string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    if (-not $pathFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "BLOCK: arquivo fora de SkillsRoot: $pathFull"
    }

    $relative = $pathFull.Substring($rootFull.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return ($relative -replace '\\', '/')
}

function Get-NormalizedTextHash {
    param(
        [string]$Path
    )

    $raw = [System.IO.File]::ReadAllText($Path)
    $normalized = $raw -replace "`r`n", "`n"
    $normalized = $normalized -replace "`r", "`n"
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $bytes = $utf8NoBom.GetBytes($normalized)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
    } finally {
        $sha.Dispose()
    }

    return [pscustomobject]@{
        sha256 = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
        normalizedLength = $bytes.Length
    }
}

function Resolve-ManifestInclude {
    param(
        [string]$RootPath,
        [string]$Include
    )

    if ([string]::IsNullOrWhiteSpace($Include)) {
        throw 'BLOCK: include vazio em setup-contract.manifest.json'
    }

    $normalizedInclude = $Include -replace '/', [System.IO.Path]::DirectorySeparatorChar
    $includePath = Join-Path $RootPath $normalizedInclude
    $hasWildcard = [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Include)

    if ($hasWildcard) {
        $matches = @(Get-ChildItem -Path $includePath -File -ErrorAction SilentlyContinue | Sort-Object FullName)
        if ($matches.Count -eq 0) {
            throw "BLOCK: include sem arquivos no contrato de setup: $Include"
        }

        return @($matches | Select-Object -ExpandProperty FullName)
    }

    if (-not (Test-Path -LiteralPath $includePath -PathType Leaf)) {
        throw "BLOCK: arquivo do contrato de setup ausente: $Include"
    }

    return @([System.IO.Path]::GetFullPath($includePath))
}

if ([string]::IsNullOrWhiteSpace($SkillsRoot)) {
    $SkillsRoot = Get-DefaultSkillsRoot
}

$skillsRootFull = [System.IO.Path]::GetFullPath($SkillsRoot)

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $skillsRootFull 'xpz-kb-parallel-setup\setup-contract.manifest.json'
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "BLOCK: manifesto de contrato de setup ausente: $ManifestPath"
}

$manifestRelativePath = ConvertTo-RepoRelativePath -RootPath $skillsRootFull -Path $ManifestPath
$manifestRaw = [System.IO.File]::ReadAllText($ManifestPath)
$manifest = $manifestRaw | ConvertFrom-Json

if ($null -eq $manifest.signatureVersion -or [string]::IsNullOrWhiteSpace([string]$manifest.signatureVersion)) {
    throw 'BLOCK: setup-contract.manifest.json sem signatureVersion'
}

if ($null -eq $manifest.include) {
    throw 'BLOCK: setup-contract.manifest.json sem include'
}

$fileMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($include in @($manifest.include)) {
    foreach ($path in @(Resolve-ManifestInclude -RootPath $skillsRootFull -Include ([string]$include))) {
        $relative = ConvertTo-RepoRelativePath -RootPath $skillsRootFull -Path $path
        if (-not $fileMap.ContainsKey($relative)) {
            $fileMap.Add($relative, $path)
        }
    }
}

if (-not $fileMap.ContainsKey($manifestRelativePath)) {
    $fileMap.Add($manifestRelativePath, [System.IO.Path]::GetFullPath($ManifestPath))
}

$records = @()
foreach ($relativePath in @($fileMap.Keys | Sort-Object)) {
    $hash = Get-NormalizedTextHash -Path $fileMap[$relativePath]
    $records += [pscustomobject]@{
        relativePath = $relativePath
        sha256 = $hash.sha256
        normalizedLength = $hash.normalizedLength
    }
}

$canonicalLines = [System.Collections.Generic.List[string]]::new()
$canonicalLines.Add([string]$manifest.signatureVersion)
foreach ($record in $records) {
    $canonicalLines.Add(('{0}|{1}|{2}' -f $record.relativePath, $record.normalizedLength, $record.sha256))
}

$canonicalText = ($canonicalLines.ToArray() -join "`n") + "`n"
$utf8NoBomForCanonical = [System.Text.UTF8Encoding]::new($false)
$canonicalBytes = $utf8NoBomForCanonical.GetBytes($canonicalText)
$canonicalSha = [System.Security.Cryptography.SHA256]::Create()
try {
    $signatureBytes = $canonicalSha.ComputeHash($canonicalBytes)
} finally {
    $canonicalSha.Dispose()
}

$result = [pscustomobject]@{
    status = 'SETUP_CONTRACT_SIGNATURE_OK'
    signatureVersion = [string]$manifest.signatureVersion
    signatureHash = ([System.BitConverter]::ToString($signatureBytes) -replace '-', '').ToLowerInvariant()
    manifestPath = [System.IO.Path]::GetFullPath($ManifestPath)
    fileCount = $records.Count
    files = $records
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6 -Compress
    exit 0
}

Write-Output ("SETUP_CONTRACT_SIGNATURE_OK: {0} {1}" -f $result.signatureVersion, $result.signatureHash)
exit 0
