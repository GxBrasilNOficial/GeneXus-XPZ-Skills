#requires -Version 7.4

<#
.SYNOPSIS
    Gate do F1: revisao estatica do dist + boot sem chave.

.DESCRIPTION
    Requer uma arvore vendorizada real (npm ci --ignore-scripts) e a evidencia
    sanitizada commitada em xpz-mcp-integrations-setup/fixtures/dist/0.13.0/.
    -ManagedRoot deve apontar para um managed root descartavel
    (...\xpz-mcp-integrations-setup) cujo vendor-0.13.0 ja exista.
#>

[CmdletBinding()]
param(
    [string]$ManagedRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')
. (Join-Path $scriptDir 'McpVaultSupport.ps1')
. (Join-Path $scriptDir 'McpLauncherSupport.ps1')
. (Join-Path $scriptDir 'McpVendorSupport.ps1')

$repoRoot = Get-McpRepoRoot
$fixtureDir = Join-Path $repoRoot 'xpz-mcp-integrations-setup/fixtures/dist/0.13.0'
$originalProfile = $env:USERPROFILE
$originalLocalAppData = $env:LOCALAPPDATA
$resolvedManagedRoot = $null
$launcherPath = $null
$createdConfig = $false
$createdVault = $false
$createdLauncher = $false
$failures = [System.Collections.Generic.List[string]]::new()
$assertCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:assertCount++
    if (-not $Condition) {
        $script:failures.Add($Message) | Out-Null
    }
}

function Start-BootProbe {
    param([string]$LauncherPath, [int]$TimeoutMs = 20000)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command pwsh).Source
    $psi.Arguments = '-NoProfile -File "' + $LauncherPath + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($psi)
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.WriteLine('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"xpz-mcp-integrations-setup","version":"1.0"}}}')
    $process.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
    $process.StandardInput.Close()
    $exited = $process.WaitForExit($TimeoutMs)
    if (-not $exited) {
        try { $process.Kill($true) } catch { }
        return [pscustomobject]@{ ExitCode = $null; Stdout = ''; Stderr = 'timeout'; TimedOut = $true }
    }
    $process.WaitForExit()
    $stdout = $outTask.GetAwaiter().GetResult()
    $stderr = $errTask.GetAwaiter().GetResult()
    $exitCode = $process.ExitCode
    $process.Dispose()
    return [pscustomobject]@{ ExitCode = $exitCode; Stdout = $stdout; Stderr = $stderr; TimedOut = $false }
}

try {
    # 1. Evidencia fixture.
    foreach ($file in @('provider-compatible.excerpt.js', 'package-metadata.excerpt.json', 'boot-initialize.txt', 'eof-exit.txt', 'LICENSE', 'PROVENANCE.json', 'STATIC-REVIEW.md')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $fixtureDir $file) -PathType Leaf) "(fixture) $file presente"
    }
    $provider = [System.IO.File]::ReadAllText((Join-Path $fixtureDir 'provider-compatible.excerpt.js'))
    Assert-True ($provider.Contains('JEV_API_KEY') -and $provider.Contains('JEV_API_BASE_URL')) '(provider) variaveis do modo compatible'
    Assert-True ($provider.Contains('compatible')) '(provider) modo compatible'
    Assert-True ($provider.Contains('answers')) '(provider) contrato answers'
    $metadata = Get-McpJsonFile -Path (Join-Path $fixtureDir 'package-metadata.excerpt.json')
    Assert-True ([string]$metadata.engines.node -eq '>=22') '(metadata) engines.node >=22'
    Assert-True ([string]$metadata.prepare -eq 'npm run build') '(metadata) prepare declarado'
    Assert-True ([string]$metadata.license -eq 'MIT') '(metadata) licenca MIT'
    $license = [System.IO.File]::ReadAllText((Join-Path $fixtureDir 'LICENSE'))
    Assert-True ($license.StartsWith('MIT License')) '(license) MIT integral'
    $provenance = Get-McpJsonFile -Path (Join-Path $fixtureDir 'PROVENANCE.json')
    $descriptor = Get-McpDescriptor
    Assert-True ([string]$provenance.tarballIntegrity -eq [string]$descriptor.Descriptor.component.tarballIntegrity) '(provenance) integrity igual ao descritor'
    $bootFixture = [System.IO.File]::ReadAllText((Join-Path $fixtureDir 'boot-initialize.txt'))
    Assert-True ($bootFixture.Contains('jev-mcp') -and $bootFixture.Contains('EXIT: 0')) '(boot fixture) initialize e exit 0'
    $eofFixture = [System.IO.File]::ReadAllText((Join-Path $fixtureDir 'eof-exit.txt'))
    Assert-True ($eofFixture.Contains('exit 0')) '(eof fixture) exit 0'
    $staticReview = [System.IO.File]::ReadAllText((Join-Path $fixtureDir 'STATIC-REVIEW.md'))
    Assert-True ($staticReview.Contains('boot') -and $staticReview.Contains('network') -or $staticReview.Contains('rede')) '(static review) boot e limite de rede'

    # 2. Arvore vendorizada real.
    if ([string]::IsNullOrWhiteSpace($ManagedRoot)) {
        throw 'XPZ_MCP_DIST_EVIDENCE_MANAGED_ROOT_REQUIRED: informe -ManagedRoot de uma instalacao descartavel com vendor-0.13.0'
    }
    $managedRoot = Resolve-McpFullPath -Path $ManagedRoot
    $resolvedManagedRoot = $managedRoot
    if (-not (Test-Path -LiteralPath $managedRoot -PathType Container)) {
        throw "XPZ_MCP_DIST_EVIDENCE_MANAGED_ROOT_MISSING: $managedRoot"
    }
    $guardPaths = @(
        (Join-Path $managedRoot 'install-manifest.json'),
        (Join-Path $managedRoot 'config.json'),
        (Join-Path $managedRoot 'vault')
    )
    $guardHits = @($guardPaths | Where-Object { Test-Path -LiteralPath $_ })
    $guardLaunchers = @(Get-ChildItem -LiteralPath $managedRoot -Filter 'launcher-*.ps1' -File -ErrorAction SilentlyContinue)
    if ($guardLaunchers.Count -gt 0) {
        $guardHits += @($guardLaunchers.FullName)
    }
    if ($guardHits.Count -gt 0) {
        throw "XPZ_MCP_DIST_EVIDENCE_MANAGED_ROOT_NOT_DISPOSABLE: $managedRoot contem $($guardHits -join ', '); use um root limpo so com vendor-0.13.0"
    }
    $env:LOCALAPPDATA = Split-Path -Parent $managedRoot
    $env:USERPROFILE = Split-Path -Parent $managedRoot
    $pin = Get-McpVendorPin
    $vendor = Test-McpVendor -Pin $pin
    Assert-True ($vendor.state -eq 'ok') "(vendor) estado ok; obtido $($vendor.state)"
    Assert-True (Test-McpRegularFile -Path (Join-Path (Split-Path -Parent $vendor.entryPath) '..\LICENSE')) '(vendor) LICENSE presente'

    # 3. Boot sem chave com o servidor real.
    $launcherPath = Join-Path $managedRoot 'launcher-0.13.0.ps1'
    if (-not (Test-Path -LiteralPath $launcherPath)) {
        $launcher = Install-McpLauncher -Version '0.13.0' -NodePath (Get-Command node).Source -EntryPath $vendor.entryPath -VendorDir $vendor.vendorDir
        $launcherPath = $launcher.Path
        $createdLauncher = $true
    }
    if (-not (Test-Path -LiteralPath (Get-McpConfigPath))) {
        $null = Set-McpConfig -BaseUrl 'https://api.commandcode.ai/provider/v1/systemone' -Model 'typesafe/jev' -EndpointConfirmed $true
        $createdConfig = $true
    }
    if (-not (Test-McpVaultExists)) {
        $null = Write-McpVault -SecureSecret (ConvertTo-SecureString 'boot-without-key' -AsPlainText -Force)
        $createdVault = $true
    }
    $boot = Start-BootProbe -LauncherPath $launcherPath
    Assert-True (-not $boot.TimedOut) '(boot) sem timeout'
    Assert-True ($boot.ExitCode -eq 0) "(boot) exit 0; obtido $($boot.ExitCode)"
    Assert-True ($boot.Stdout -match 'serverInfo' -and $boot.Stdout -match 'jev-mcp') '(boot) resposta initialize com jev-mcp'
    Assert-True ($boot.Stderr -match '\[jev-mcp\] ready') '(boot) stderr ready'
} finally {
    if ($createdLauncher -and -not [string]::IsNullOrWhiteSpace($launcherPath) -and (Test-Path -LiteralPath $launcherPath)) {
        Remove-Item -LiteralPath $launcherPath -Force -ErrorAction SilentlyContinue
    }
    if ($createdConfig -and -not [string]::IsNullOrWhiteSpace($resolvedManagedRoot)) {
        Remove-Item -LiteralPath (Join-Path $resolvedManagedRoot 'config.json') -Force -ErrorAction SilentlyContinue
    }
    if ($createdVault -and -not [string]::IsNullOrWhiteSpace($resolvedManagedRoot)) {
        Remove-Item -LiteralPath (Join-Path $resolvedManagedRoot 'vault') -Recurse -Force -ErrorAction SilentlyContinue
    }
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "FAIL: $failure"
    }
    Write-Output "XPZ_MCP_DIST_EVIDENCE_SELFTEST_FAILED: $($failures.Count)/$assertCount"
    exit 1
}
Write-Output "XPZ_MCP_DIST_EVIDENCE_SELFTEST_OK: $assertCount asserts"
exit 0
