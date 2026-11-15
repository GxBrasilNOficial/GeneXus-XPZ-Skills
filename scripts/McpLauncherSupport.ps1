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

function Get-McpLauncherTemplateRevision {
    # Revisao atual do molde. Sobe quando o comportamento do launcher muda (rev 2: regra de
    # endpoint antes do cofre). Copia emitida com revisao menor ou sem a linha e desatualizada.
    return 2
}

function Get-McpLauncherTextRevision {
    # Revisao declarada no cabecalho da copia; sem a linha (molde anterior a rev 2) vale 1.
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)
    $head = (@($Text -split "`n") | Select-Object -First 10) -join "`n"
    $match = [regex]::Match($head, '(?m)^# template-revision: (\d+)\r?$')
    if (-not $match.Success) { return 1 }
    return [int]$match.Groups[1].Value
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

function Get-McpLauncherPresetHost {
    # Host do preset do modo compatible: o launcher aplica a mesma regra de endpoint
    # do install e da auditoria (host fora do preset exige endpointConfirmed).
    param([string]$RepoRoot = (Get-McpRepoRoot))
    $descriptor = Get-McpDescriptor -RepoRoot $RepoRoot
    $presetName = [string]$descriptor.Descriptor.modes.compatible.preset
    $preset = $descriptor.Descriptor.presets[$presetName]
    if ($null -eq $preset) {
        throw "XPZ_MCP_LAUNCHER_PRESET_MISSING: preset '$presetName' do modo compatible ausente no descritor"
    }
    $presetUri = $null
    if (-not [Uri]::TryCreate([string]$preset.baseUrl, [UriKind]::Absolute, [ref]$presetUri) -or [string]::IsNullOrWhiteSpace($presetUri.Host)) {
        throw "XPZ_MCP_LAUNCHER_PRESET_INVALID: baseUrl do preset '$presetName' invalida"
    }
    return $presetUri.Host
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
    $presetHost = Get-McpLauncherPresetHost -RepoRoot $RepoRoot
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
        '__XPZ_MCP_PRESET_HOST__'     = $presetHost
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
    if ((Get-McpLauncherTextRevision -Text $text) -ne (Get-McpLauncherTemplateRevision)) {
        throw 'XPZ_MCP_LAUNCHER_REVISION_MISMATCH: revisao do molde difere de Get-McpLauncherTemplateRevision'
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
        -CreateExclusive:($null -eq $existing) `
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
    # Copia reconhecida (sentinela + hash do manifesto), mas de molde anterior: falta o
    # comportamento atual (ex.: regra de endpoint da rev 2). Pede reparo; nao e copia alheia.
    $revision = Get-McpLauncherTextRevision -Text $document.Text
    if ($revision -lt (Get-McpLauncherTemplateRevision)) {
        return [pscustomobject]@{
            state        = 'launcher_desatualizado'
            path         = $path
            expectedHash = [string]$record.sha256
            actualHash   = $document.Hash
            reason       = "revisao $revision < $(Get-McpLauncherTemplateRevision)"
        }
    }
    return [pscustomobject]@{
        state        = 'ok'
        path         = $path
        expectedHash = [string]$record.sha256
        actualHash   = $document.Hash
    }
}
