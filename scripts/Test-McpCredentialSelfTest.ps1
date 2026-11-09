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
$originalPath = $env:PATH
$env:USERPROFILE = $tempRoot
$env:LOCALAPPDATA = $tempRoot
$opencodeConfigDir = Join-Path $tempRoot '.config\opencode'
$opencodeShareDir = Join-Path $tempRoot '.local\share\opencode'
[System.IO.Directory]::CreateDirectory($opencodeConfigDir) | Out-Null
[System.IO.Directory]::CreateDirectory($opencodeShareDir) | Out-Null
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

    $shareAuth = Join-Path $opencodeShareDir 'auth.json'
    $configAuth = Join-Path $opencodeConfigDir 'auth.json'
    Copy-Item -LiteralPath (Join-Path $fixtureDir 'auth-json-one.json') -Destination $shareAuth -Force
    $authJson = Get-McpAuthJsonCredential
    Assert-True ($authJson.Status -eq 'ok' -and $authJson.Secret -eq 'test-key-auth-json') '(auth-json) credencial ativa type=api'
    Assert-True ($authJson.Path -like '*\.local\share\opencode\auth.json') '(auth-json) caminho V2 .local\share'
    Assert-True (@($authJson.Providers) -contains 'commandcode') '(auth-json) provedor commandcode'

    Remove-Item -LiteralPath $shareAuth -Force
    Copy-Item -LiteralPath (Join-Path $fixtureDir 'auth-json-key.json') -Destination $configAuth -Force
    $legacy = Get-McpAuthJsonCredential
    Assert-True ($legacy.Status -eq 'ok' -and $legacy.Secret -eq 'test-key-auth-json-legacy') '(auth-json) type=key legado'
    Assert-True ($legacy.Path -like '*\.config\opencode\auth.json') '(auth-json) caminho legado .config'

    Remove-Item -LiteralPath $configAuth -Force
    Copy-Item -LiteralPath (Join-Path $fixtureDir 'auth-json-inactive.json') -Destination $shareAuth -Force
    $inactive = Get-McpAuthJsonCredential
    Assert-True ($inactive.Status -eq 'absent') '(auth-json) type=api inativa e ausente'

    Remove-Item -LiteralPath $shareAuth -Force
    Copy-Item -LiteralPath (Join-Path $fixtureDir 'auth-json-other-providers.json') -Destination $shareAuth -Force
    $other = Get-McpAuthJsonCredential
    Assert-True ($other.Status -eq 'absent') '(auth-json) sem commandcode e ausente'
    Assert-True (@($other.Providers) -contains 'nvidia2' -and @($other.Providers) -contains 'opencode-go') '(auth-json) provedores diagnosticados'
    Assert-True (@($other.AttemptedPaths).Count -eq 2) '(auth-json) dois caminhos tentados'

    Remove-Item -LiteralPath $shareAuth -Force
    $missing = Get-McpAuthJsonCredential
    Assert-True ($missing.Status -eq 'absent' -and @($missing.ExistingPaths).Count -eq 0) '(auth-json) nenhum arquivo existente'

    $null = Write-McpVault -SecureSecret (ConvertTo-SecureString $one.Secret -AsPlainText -Force)
    Assert-True ((Read-McpVault) -ceq 'test-key-one') '(vault) import simulado grava e le'

    Copy-Item -LiteralPath (Join-Path $fixtureDir 'auth-json-key.json') -Destination $configAuth -Force
    $pwshPath = (Get-Command pwsh).Source
    $emptyPath = Join-Path $tempRoot 'empty-path'
    [System.IO.Directory]::CreateDirectory($emptyPath) | Out-Null
    $env:PATH = $emptyPath
    try {
        $plannedOutput = @(& $pwshPath -NoProfile -File (Join-Path $scriptDir 'Set-McpCredential.ps1') -Action import -ImportFromOpenCode -WhatIf 2>&1)
        $plannedExit = $LASTEXITCODE
        $plannedText = (($plannedOutput | ForEach-Object { [string]$_ }) -join "`n")
        $planned = $null
        try { $planned = $plannedText | ConvertFrom-Json -AsHashtable } catch { }
        Assert-True ($plannedExit -eq 0) "(import -WhatIf) exit 0; obtido $plannedExit"
        Assert-True ($null -ne $planned -and [string]$planned.status -eq 'planned') '(import -WhatIf) status planned'
        Assert-True ($null -ne $planned -and [string]$planned.credentialSource -eq 'auth.json') '(import -WhatIf) credentialSource auth.json'
        Assert-True ($null -ne $planned -and [string]$planned.import.path -like '*\.config\opencode\auth.json') '(import -WhatIf) caminho da reserva'
    } finally {
        $env:PATH = $originalPath
    }
} finally {
    $env:USERPROFILE = $originalProfile
    $env:LOCALAPPDATA = $originalLocalAppData
    $env:PATH = $originalPath
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
