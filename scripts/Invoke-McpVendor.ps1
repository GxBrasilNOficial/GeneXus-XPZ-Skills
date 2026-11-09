#requires -Version 7.4

<#
.SYNOPSIS
    Vendoriza o componente Jev/System One pinado no lockfile.

.DESCRIPTION
    Copia package.json/package-lock.json do repositorio para
    %LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\ e roda
    `npm ci --ignore-scripts --no-audit --no-fund`. O integrity sha512 do
    tarball e conferido contra o descritor. Sem npx em runtime.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')
. (Join-Path $scriptDir 'McpVendorSupport.ps1')

$result = Invoke-McpVendorInstall -Force:$Force -WhatIf:$WhatIfPreference
$findingsOut = @()
$blockingOut = @()
if ($result.PSObject.Properties['findings']) { $findingsOut = @($result.findings) }
if ($result.PSObject.Properties['blockingReasons']) { $blockingOut = @($result.blockingReasons) }
[pscustomobject]@{
    schemaVersion  = 1
    kind           = 'xpz-mcp-integrations-setup-vendor'
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    status         = $result.status
    exitCode       = $result.exitCode
    version        = $result.version
    vendorDir      = $result.vendorDir
    entryPath      = $result.entryPath
    integrity      = $(if ($result.PSObject.Properties['integrity']) { $result.integrity } else { $null })
    logPath        = $(if ($result.PSObject.Properties['logPath']) { $result.logPath } else { $null })
    npmExitCode    = $(if ($result.PSObject.Properties['npmExitCode']) { $result.npmExitCode } else { $null })
    findings       = @($findingsOut)
    blockingReasons = @($blockingOut)
} | ConvertTo-Json -Depth 20
exit ([int]$result.exitCode)
