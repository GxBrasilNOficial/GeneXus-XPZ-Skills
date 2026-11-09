#requires -Version 7.4

<#
.SYNOPSIS
    Self-test da selecao de credencial importada (auth export/auth.json).
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')
. (Join-Path $scriptDir 'McpVaultSupport.ps1')

$fixtureDir = Join-Path (Split-Path -Parent $scriptDir) 'xpz-mcp-integrations-setup/fixtures/auth-export'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-mcp-cred-selftest-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
$originalProfile = $env:USERPROFILE
$originalLocalAppData = $env:LOCALAPPDATA
$env:USERPROFILE = $tempRoot
$env:LOCALAPPDATA = $tempRoot
$opencodeDir = Join-Path $tempRoot '.config\opencode'
[System.IO.Directory]::CreateDirectory($opencodeDir) | Out-Null
$failures = [System.Collections.Generic.List[string]]::new()
$assertCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:assertCount++
    if (-not $Condition) {
        $script:failures.Add($Message) | Out-Null
    }
}

function Get-Entries {
    param([string]$Name)
    $root = Get-McpJsonFile -Path (Join-Path $fixtureDir $Name)
    return @(ConvertTo-McpCredentialEntries -Root $root)
}

try {
    $one = Get-McpCredentialFromEntries -Entries (Get-Entries -Name 'one-credential.json') -Source 'fixture-one'
    Assert-True ($one.Status -eq 'ok' -and $one.Secret -eq 'test-key-one') '(one) credencial unica'

    $many = Get-McpCredentialFromEntries -Entries (Get-Entries -Name 'many-credentials.json') -Source 'fixture-many'
    Assert-True ($many.Status -eq 'ok' -and $many.Secret -eq 'test-key-commandcode') '(many) seleciona commandcode'

    $duplicate = Get-McpCredentialFromEntries -Entries (Get-Entries -Name 'duplicate-commandcode.json') -Source 'fixture-duplicate'
    Assert-True ($duplicate.Status -eq 'ambiguous') '(duplicate) credencial_ambigua'

    $empty = Get-McpCredentialFromEntries -Entries (Get-Entries -Name 'empty.json') -Source 'fixture-empty'
    Assert-True ($empty.Status -eq 'absent') '(empty) ausente'

    Copy-Item -LiteralPath (Join-Path $fixtureDir 'auth-json-one.json') -Destination (Join-Path $opencodeDir 'auth.json') -Force
    $authJson = Get-McpAuthJsonCredential
    Assert-True ($authJson.Status -eq 'ok' -and $authJson.Secret -eq 'test-key-auth-json') '(auth-json) credencial ativa'

    Copy-Item -LiteralPath (Join-Path $fixtureDir 'auth-json-inactive.json') -Destination (Join-Path $opencodeDir 'auth.json') -Force
    $inactive = Get-McpAuthJsonCredential
    Assert-True ($inactive.Status -eq 'absent') '(auth-json) inativa e ausente'

    $null = Write-McpVault -SecureSecret (ConvertTo-SecureString $one.Secret -AsPlainText -Force)
    Assert-True ((Read-McpVault) -ceq 'test-key-one') '(vault) import simulado grava e le'
} finally {
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output "FAIL: $failure"
    }
    Write-Output "XPZ_MCP_CREDENTIAL_SELFTEST_FAILED: $($failures.Count)/$assertCount"
    exit 1
}
Write-Output "XPZ_MCP_CREDENTIAL_SELFTEST_OK: $assertCount asserts"
exit 0
