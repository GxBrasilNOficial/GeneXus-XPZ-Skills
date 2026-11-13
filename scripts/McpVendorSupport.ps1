#requires -Version 7.4

<#
.SYNOPSIS
    Vendorizacao pinada do componente Jev/System One.

.DESCRIPTION
    O repositorio guarda `vendor/package.json` + `vendor/package-lock.json`.
    A instalacao roda `npm ci --ignore-scripts --no-audit --no-fund` em
    `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\` e confere a versao
    instalada contra o pin do descritor. Sem npx em runtime.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:McpVendorSupportDir = Split-Path -Parent $PSCommandPath
. (Join-Path $script:McpVendorSupportDir 'McpIntegrationSupport.ps1')
. (Join-Path $script:McpVendorSupportDir 'McpLauncherSupport.ps1')

function Get-McpVendorPin {
    param([string]$RepoRoot = (Get-McpRepoRoot))
    $root = Resolve-McpFullPath -Path $RepoRoot
    $descriptor = Get-McpDescriptor -RepoRoot $root
    $packageJsonPath = Join-Path $root 'xpz-mcp-integrations-setup/vendor/package.json'
    $lockPath = Join-Path $root 'xpz-mcp-integrations-setup/vendor/package-lock.json'
    if (-not (Test-McpRegularFile -Path $packageJsonPath)) {
        throw "XPZ_MCP_VENDOR_PIN_MISSING: $packageJsonPath"
    }
    if (-not (Test-McpRegularFile -Path $lockPath)) {
        throw "XPZ_MCP_VENDOR_PIN_MISSING: $lockPath"
    }
    $package = Get-McpJsonFile -Path $packageJsonPath
    $lock = Get-McpJsonFile -Path $lockPath
    $component = $descriptor.Descriptor.component

    if ($null -eq $package -or $null -eq $package.dependencies) {
        throw 'XPZ_MCP_VENDOR_PIN_INVALID: package.json sem dependencies'
    }
    $declared = Get-McpDictionaryValue -Object $package.dependencies -Key ([string]$component.package)
    if ($null -eq $declared) {
        throw "XPZ_MCP_VENDOR_PIN_INVALID: package.json sem dependencia $($component.package)"
    }
    if ([string]$declared -ne [string]$component.version) {
        throw "XPZ_MCP_VENDOR_PIN_INVALID: package.json declara '$declared' para $($component.package); esperado pin exato $($component.version)"
    }
    if ($lock.lockfileVersion -ne 3) {
        throw "XPZ_MCP_VENDOR_PIN_INVALID: lockfileVersion $($lock.lockfileVersion); esperado 3"
    }
    $rootEntry = Get-McpDictionaryValue -Object $lock.packages -Key ''
    if ($null -eq $rootEntry -or $null -eq $rootEntry.dependencies) {
        throw 'XPZ_MCP_VENDOR_PIN_INVALID: raiz do lock sem dependencies'
    }
    $rootDependency = Get-McpDictionaryValue -Object $rootEntry.dependencies -Key ([string]$component.package)
    if ($null -eq $rootDependency) {
        throw "XPZ_MCP_VENDOR_PIN_INVALID: raiz do lock sem $($component.package)"
    }
    if ([string]$rootDependency -ne [string]$component.version) {
        throw "XPZ_MCP_VENDOR_PIN_INVALID: raiz do lock declara '$rootDependency'; esperado $($component.version)"
    }
    $locked = Get-McpDictionaryValue -Object $lock.packages -Key ('node_modules/' + $component.package)
    if ($null -eq $locked) {
        throw "XPZ_MCP_VENDOR_PIN_INVALID: entrada do pacote ausente no lock: $($component.package)"
    }
    if ([string]$locked.version -ne [string]$component.version) {
        throw "XPZ_MCP_VENDOR_PIN_INVALID: lock resolve versao $($locked.version); esperado $($component.version)"
    }
    if ([string]$locked.integrity -ne [string]$component.tarballIntegrity) {
        throw 'XPZ_MCP_VENDOR_PIN_INVALID: integrity do lock diverge do descritor'
    }
    $packageCount = @(Get-McpKeyNames -Object $lock.packages).Count - 1
    return [pscustomobject]@{
        RepoRoot        = $root
        Descriptor      = $descriptor
        Package         = [string]$component.package
        Version         = [string]$component.version
        TarballIntegrity = [string]$component.tarballIntegrity
        DistEntry       = [string]$component.distEntry
        PackageJsonPath = $packageJsonPath
        LockPath        = $lockPath
        LockedTreeCount = $packageCount
    }
}

function Test-McpVendor {
    param(
        [Parameter(Mandatory = $true)]$Pin
    )
    $vendorDir = Get-McpVendorDir -Version $Pin.Version
    $packageJsonPath = Get-McpVendorPackageJsonPath -Version $Pin.Version -Package $Pin.Package
    $entryPath = Get-McpVendorEntryPath -Version $Pin.Version -Package $Pin.Package -DistEntry $Pin.DistEntry
    if (-not (Test-Path -LiteralPath $vendorDir -PathType Container)) {
        return [pscustomobject]@{
            state     = 'vendor_ausente'
            vendorDir = $vendorDir
            entryPath = $entryPath
            version   = $null
        }
    }
    if (-not (Test-McpRegularFile -Path $packageJsonPath)) {
        return [pscustomobject]@{
            state     = 'vendor_ausente'
            vendorDir = $vendorDir
            entryPath = $entryPath
            version   = $null
        }
    }
    try {
        $installed = Get-McpJsonFile -Path $packageJsonPath
    } catch {
        return [pscustomobject]@{
            state     = 'vendor_divergente'
            vendorDir = $vendorDir
            entryPath = $entryPath
            version   = $null
            reason    = 'package.json invalido'
        }
    }
    if ([string]$installed.version -ne $Pin.Version) {
        return [pscustomobject]@{
            state     = 'vendor_divergente'
            vendorDir = $vendorDir
            entryPath = $entryPath
            version   = [string]$installed.version
            reason    = "versao instalada $($installed.version) diverge do pin $($Pin.Version)"
        }
    }
    if (-not (Test-McpRegularFile -Path $entryPath)) {
        return [pscustomobject]@{
            state     = 'vendor_ausente'
            vendorDir = $vendorDir
            entryPath = $entryPath
            version   = [string]$installed.version
            reason    = 'dist/index.js ausente'
        }
    }
    $licensePath = Join-Path (Split-Path -Parent $entryPath) '..\LICENSE'
    $licensePath = [System.IO.Path]::GetFullPath($licensePath)
    return [pscustomobject]@{
        state      = 'ok'
        vendorDir  = $vendorDir
        entryPath  = $entryPath
        version    = [string]$installed.version
        licensePath = $licensePath
        licensePresent = (Test-McpRegularFile -Path $licensePath)
    }
}

function Invoke-McpVendorInstall {
    param(
        [string]$RepoRoot = (Get-McpRepoRoot),
        [switch]$Force,
        [switch]$WhatIf
    )
    $pin = Get-McpVendorPin -RepoRoot $RepoRoot
    $prerequisites = Get-McpPrerequisites
    $findings = [System.Collections.Generic.List[object]]::new()
    foreach ($finding in @(Get-McpPrerequisiteFindings -Prerequisites $prerequisites)) {
        if ($finding.code -in @('node_ausente', 'node_incompativel', 'node_path_nao_resolve', 'node_npm_ausente', 'pwsh_ausente')) {
            $findings.Add($finding) | Out-Null
        }
    }
    $vendorDir = Get-McpVendorDir -Version $pin.Version
    $entryPath = Get-McpVendorEntryPath -Version $pin.Version -Package $pin.Package -DistEntry $pin.DistEntry
    if ($findings.Count -gt 0) {
        return [pscustomobject]@{
            status          = 'blocked'
            exitCode        = Get-McpExitCodeForFindings -Findings @($findings)
            version         = $pin.Version
            vendorDir       = $vendorDir
            entryPath       = $entryPath
            findings        = @($findings)
            blockingReasons = @($findings | ForEach-Object { $_.message })
        }
    }

    $current = Test-McpVendor -Pin $pin
    if (-not $Force -and $current.state -eq 'ok') {
        return [pscustomobject]@{
            status      = 'unchanged'
            exitCode    = 0
            version     = $pin.Version
            vendorDir   = $vendorDir
            entryPath   = $current.entryPath
            integrity   = $pin.TarballIntegrity
        }
    }

    if ($WhatIf) {
        return [pscustomobject]@{
            status          = 'planned'
            exitCode        = 0
            version         = $pin.Version
            vendorDir       = $vendorDir
            entryPath       = $entryPath
            packageJsonPath = $pin.PackageJsonPath
            lockPath        = $pin.LockPath
            integrity       = $pin.TarballIntegrity
        }
    }

    if (-not (Test-Path -LiteralPath $vendorDir -PathType Container)) {
        New-Item -ItemType Directory -Path $vendorDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $pin.PackageJsonPath -Destination (Join-Path $vendorDir 'package.json') -Force
    Copy-Item -LiteralPath $pin.LockPath -Destination (Join-Path $vendorDir 'package-lock.json') -Force

    $logPath = Join-Path $vendorDir 'npm-ci.log'
    $npmPath = $prerequisites.Npm.Path
    $npmExitCode = 0
    $npmOutput = @()
    Push-Location -LiteralPath $vendorDir
    try {
        $npmOutput = @(& $npmPath 'ci' '--ignore-scripts' '--no-audit' '--no-fund' 2>&1)
        $npmExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    $logText = (($npmOutput | ForEach-Object { $_.ToString() }) -join "`n")
    [System.IO.File]::WriteAllText($logPath, $logText, [System.Text.UTF8Encoding]::new($false))

    if ($npmExitCode -ne 0) {
        return [pscustomobject]@{
            status          = 'failed'
            exitCode        = 64
            version         = $pin.Version
            vendorDir       = $vendorDir
            entryPath       = $entryPath
            logPath         = $logPath
            npmExitCode     = $npmExitCode
            blockingReasons = @("npm ci falhou com exit $npmExitCode; ver $logPath")
        }
    }

    $after = Test-McpVendor -Pin $pin
    $treeBytes = 0
    if (Test-Path -LiteralPath $vendorDir -PathType Container) {
        $treeBytes = (Get-ChildItem -LiteralPath $vendorDir -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
    }
    return [pscustomobject]@{
        status      = $after.state
        exitCode    = $(if ($after.state -eq 'ok') { 0 } else { 64 })
        version     = $pin.Version
        vendorDir   = $vendorDir
        entryPath   = $after.entryPath
        integrity   = $pin.TarballIntegrity
        treeBytes   = [long]($treeBytes ?? 0)
        logPath     = $logPath
        npmExitCode = $npmExitCode
    }
}
