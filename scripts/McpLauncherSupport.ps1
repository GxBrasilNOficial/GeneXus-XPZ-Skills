#requires -Version 7.4

<#
.SYNOPSIS
    Emissao, verificacao e comando do launcher da skill xpz-mcp-integrations-setup.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:McpLauncherSupportDir = Split-Path -Parent $PSCommandPath
. (Join-Path $script:McpLauncherSupportDir 'McpIntegrationSupport.ps1')

function Get-McpLauncherSentinel {
    return '# xpz-mcp-integrations-setup:launcher v1'
}

function Get-McpLauncherTemplatePath {
    param([string]$RepoRoot = (Get-McpRepoRoot))
    return (Join-Path (Resolve-McpFullPath -Path $RepoRoot) 'xpz-mcp-integrations-setup/templates/launcher.ps1')
}

function Get-McpVendorDir {
    param([Parameter(Mandatory = $true)][string]$Version)
    return (Join-Path (Get-McpManagedRoot) ('vendor-' + $Version))
}

function Get-McpVendorEntryPath {
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Package = '@jkudish/jev-mcp',
        [Parameter(Mandatory = $true)][string]$DistEntry = 'dist/index.js'
    )
    $vendorDir = Get-McpVendorDir -Version $Version
    return (Join-Path $vendorDir ('node_modules/' + $Package + '/' + $DistEntry))
}

function Get-McpVendorPackageJsonPath {
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$Package = '@jkudish/jev-mcp'
    )
    $vendorDir = Get-McpVendorDir -Version $Version
    return (Join-Path $vendorDir ('node_modules/' + $Package + '/package.json'))
}

function Get-McpLauncherPath {
    param([Parameter(Mandatory = $true)][string]$Version)
    return (Join-Path (Get-McpManagedRoot) ('launcher-' + $Version + '.ps1'))
}

function Get-McpLauncherCommand {
    param([Parameter(Mandatory = $true)][string]$LauncherPath)
    return @('pwsh', '-NoProfile', '-File', $LauncherPath)
}

function Test-McpLauncherText {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $sentinel = Get-McpLauncherSentinel
    $lines = @($Text -split "`n")
    $head = @($lines | Select-Object -First 6)
    return (($head -join "`n").Contains($sentinel))
}

function New-McpLauncherText {
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$EntryPath,
        [Parameter(Mandatory = $true)][string]$VendorDir,
        [Parameter(Mandatory = $true)][string]$ManagedRoot,
        [string]$RepoRoot = (Get-McpRepoRoot)
    )
    $templatePath = Get-McpLauncherTemplatePath -RepoRoot $RepoRoot
    if (-not (Test-McpRegularFile -Path $templatePath)) {
        throw "XPZ_MCP_LAUNCHER_TEMPLATE_MISSING: $templatePath"
    }
    $template = Read-McpTextDocument -Path $templatePath
    $values = @{
        '__XPZ_MCP_PACKAGE_VERSION__' = $Version
        '__XPZ_MCP_NODE_PATH__'       = $NodePath
        '__XPZ_MCP_ENTRY_PATH__'      = $EntryPath
        '__XPZ_MCP_VENDOR_DIR__'      = $VendorDir
        '__XPZ_MCP_MANAGED_ROOT__'    = $ManagedRoot
    }
    $text = $template.Text
    foreach ($token in $values.Keys) {
        $escaped = ([string]$values[$token]).Replace("'", "''")
        $text = $text.Replace($token, $escaped)
    }
    if ($text.Contains('__XPZ_MCP_')) {
        throw 'XPZ_MCP_LAUNCHER_TEMPLATE_TOKEN_LEFT: token nao substituido no molde do launcher'
    }
    if (-not (Test-McpLauncherText -Text $text)) {
        throw 'XPZ_MCP_LAUNCHER_SENTINEL_MISSING: molde sem sentinela'
    }
    return $text
}

function Install-McpLauncher {
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$EntryPath,
        [Parameter(Mandatory = $true)][string]$VendorDir,
        [string]$RepoRoot = (Get-McpRepoRoot),
        [switch]$WhatIf
    )
    $managedRoot = Get-McpManagedRoot
    if (-not (Test-Path -LiteralPath $managedRoot -PathType Container)) {
        if ($WhatIf) {
            return [pscustomobject]@{
                Status   = 'planned'
                Path     = (Get-McpLauncherPath -Version $Version)
                Hash     = $null
                Sentinel = (Get-McpLauncherSentinel)
            }
        }
        New-Item -ItemType Directory -Path $managedRoot -Force | Out-Null
    }
    $text = New-McpLauncherText `
        -Version $Version `
        -NodePath $NodePath `
        -EntryPath $EntryPath `
        -VendorDir $VendorDir `
        -ManagedRoot $managedRoot `
        -RepoRoot $RepoRoot
    $path = Get-McpLauncherPath -Version $Version
    $existing = $null
    if (Test-McpRegularFile -Path $path) {
        $document = Read-McpTextDocument -Path $path
        if ($document.Text -ceq $text) {
            return [pscustomobject]@{
                Status   = 'unchanged'
                Path     = $path
                Hash     = $document.Hash
                Sentinel = (Get-McpLauncherSentinel)
            }
        }
        $existing = $document
    }
    $expectedHash = $null
    $expectedLength = $null
    $expectedMtime = $null
    if ($null -ne $existing) {
        $expectedHash = $existing.Hash
        $expectedLength = [long]$existing.Length
        $expectedMtime = $existing.LastWriteTimeUtc
    }
    $writeResult = Write-McpTextTransactional `
        -Path $path `
        -Text $text `
        -EncodingKind 'utf8-nobom' `
        -ExpectedHash $expectedHash `
        -ExpectedLength $expectedLength `
        -ExpectedLastWriteTimeUtc $expectedMtime `
        -WhatIf:$WhatIf
    return [pscustomobject]@{
        Status      = $writeResult.Status
        Path        = $path
        Hash        = $writeResult.Hash
        BackupPath  = $writeResult.BackupPath
        Sentinel    = (Get-McpLauncherSentinel)
    }
}

function Get-McpNodePath {
    $prerequisites = Get-McpPrerequisites
    if (-not $prerequisites.Node.Present -or -not $prerequisites.NodeCompatible) {
        return $null
    }
    return $prerequisites.Node.Path
}

function Test-McpLauncher {
    param(
        [Parameter(Mandatory = $true)][string]$Version,
        [Parameter(Mandatory = $true)]$Manifest
    )
    $path = Get-McpLauncherPath -Version $Version
    $record = Get-McpManifestLauncher -Manifest $Manifest -Version $Version
    if (-not (Test-McpRegularFile -Path $path)) {
        return [pscustomobject]@{
            state        = 'launcher_ausente'
            path         = $path
            expectedHash = $(if ($null -ne $record) { [string]$record.sha256 } else { $null })
            actualHash   = $null
        }
    }
    $document = Read-McpTextDocument -Path $path
    if (-not (Test-McpLauncherText -Text $document.Text)) {
        return [pscustomobject]@{
            state        = 'launcher_divergente'
            path         = $path
            expectedHash = $(if ($null -ne $record) { [string]$record.sha256 } else { $null })
            actualHash   = $document.Hash
            reason       = 'sentinel'
        }
    }
    if ($null -eq $record) {
        return [pscustomobject]@{
            state        = 'launcher_divergente'
            path         = $path
            expectedHash = $null
            actualHash   = $document.Hash
            reason       = 'manifest'
        }
    }
    if ([string]$record.path -ne $path -or [string]$record.sha256 -ne $document.Hash) {
        return [pscustomobject]@{
            state        = 'launcher_divergente'
            path         = $path
            expectedHash = [string]$record.sha256
            actualHash   = $document.Hash
            reason       = 'hash'
        }
    }
    return [pscustomobject]@{
        state        = 'ok'
        path         = $path
        expectedHash = [string]$record.sha256
        actualHash   = $document.Hash
    }
}
