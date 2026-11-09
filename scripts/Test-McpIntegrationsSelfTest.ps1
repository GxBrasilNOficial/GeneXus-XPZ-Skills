#requires -Version 7.4

<#
.SYNOPSIS
    Bateria offline da skill xpz-mcp-integrations-setup.

.DESCRIPTION
    Executa os self-tests dos adaptadores e do launcher e um ponta-a-ponta
    instalar/auditar/remover com vendor falso (sem npm ci). O gate do dist real
    fica em Test-McpDistEvidenceSelfTest.ps1 e exige -DistManagedRoot.
#>

[CmdletBinding()]
param(
    [string]$DistManagedRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')
. (Join-Path $scriptDir 'McpVaultSupport.ps1')
. (Join-Path $scriptDir 'McpLauncherSupport.ps1')

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-mcp-int-selftest-' + [Guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
$originalProfile = $env:USERPROFILE
$originalLocalAppData = $env:LOCALAPPDATA
$env:USERPROFILE = $tempRoot
$env:LOCALAPPDATA = $tempRoot
$failures = [System.Collections.Generic.List[string]]::new()
$assertCount = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    $script:assertCount++
    if (-not $Condition) {
        $script:failures.Add($Message) | Out-Null
    }
}

function Invoke-SelfTest {
    param([string]$Name, [string]$ExpectedToken)
    $path = Join-Path $scriptDir $Name
    $output = & (Get-Command pwsh).Source -NoProfile -File $path 2>&1
    $exitCode = $LASTEXITCODE
    Assert-True ($exitCode -eq 0) "($Name) exit 0; obtido $exitCode :: $(($output | Select-Object -Last 3) -join ' | ')"
    Assert-True (($output -join "`n").Contains($ExpectedToken)) "($Name) token $ExpectedToken"
    return $output
}

try {
    $oc = Join-Path $tempRoot '.config\opencode'
    [System.IO.Directory]::CreateDirectory($oc) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $oc 'opencode.jsonc'), "{`n  `"mcp`": {}`n}`n", [System.Text.UTF8Encoding]::new($false))
    $cx = Join-Path $tempRoot '.codex'
    [System.IO.Directory]::CreateDirectory($cx) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $cx 'config.toml'), "model = `"gpt-5`"`n", [System.Text.UTF8Encoding]::new($false))

    $managedRoot = Ensure-McpManagedRoot
    $null = Set-McpAcl -Path $managedRoot -Directory
    $null = Write-McpVault -SecureSecret (ConvertTo-SecureString 'test-secret-selftest' -AsPlainText -Force)

    # Vendor falso: satisfaz o contrato de Test-McpVendor sem npm ci.
    $vendorDir = Get-McpVendorDir -Version '0.13.0'
    $packageDir = Join-Path $vendorDir 'node_modules\@jkudish\jev-mcp'
    [System.IO.Directory]::CreateDirectory((Join-Path $packageDir 'dist')) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $packageDir 'package.json'),
        '{ "name": "@jkudish/jev-mcp", "version": "0.13.0", "license": "MIT" }',
        [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $packageDir 'dist\index.js'),
        'process.stderr.write("[jev-mcp] fake\n"); process.exit(0);',
        [System.Text.UTF8Encoding]::new($false))

    # 1. Self-tests de componente.
    $null = Invoke-SelfTest -Name 'Test-McpOpenCodeAdapterSelfTest.ps1' -ExpectedToken 'XPZ_MCP_OPENCODE_ADAPTER_SELFTEST_OK'
    $null = Invoke-SelfTest -Name 'Test-McpCodexAdapterSelfTest.ps1' -ExpectedToken 'XPZ_MCP_CODEX_ADAPTER_SELFTEST_OK'
    $null = Invoke-SelfTest -Name 'Test-McpLauncherSelfTest.ps1' -ExpectedToken 'XPZ_MCP_LAUNCHER_SELFTEST_OK'
    $null = Invoke-SelfTest -Name 'Test-McpCredentialSelfTest.ps1' -ExpectedToken 'XPZ_MCP_CREDENTIAL_SELFTEST_OK'
    $null = Invoke-SelfTest -Name 'Test-McpExitCodesSelfTest.ps1' -ExpectedToken 'XPZ_MCP_EXIT_CODES_SELFTEST_OK'

    # 2. Instalar nos dois clientes.
    $installOutput = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action install -Client all 2>&1
    $installExit = $LASTEXITCODE
    Assert-True ($installExit -eq 0) "(install) exit 0; obtido $installExit :: $(($installOutput | Select-Object -Last 3) -join ' | ')"
    $install = ($installOutput | ConvertFrom-Json -AsHashtable)
    Assert-True ([string]$install.overall -eq 'INTEGRATIONS_OK') "(install) overall OK; obtido $($install.overall)"
    Assert-True ([string]$install.clients.opencode.state -eq 'escrito') '(install) opencode escrito'
    Assert-True ([string]$install.clients.codex.state -eq 'escrito') '(install) codex escrito'
    $configPath = Get-McpConfigPath
    Assert-True (Test-Path -LiteralPath $configPath) '(install) config.json'
    $configText = [System.IO.File]::ReadAllText($configPath)
    Assert-True ($configText -notmatch 'JEV_API_KEY|test-secret-selftest') '(install) config sem chave'
    $launcherPath = Get-McpLauncherPath -Version '0.13.0'
    Assert-True (Test-Path -LiteralPath $launcherPath) '(install) launcher'
    $launcherText = [System.IO.File]::ReadAllText($launcherPath)
    Assert-True ($launcherText.Contains('# xpz-mcp-integrations-setup:launcher v1')) '(install) sentinela do launcher'
    $manifest = Get-McpManifest
    Assert-True ($manifest.Exists -and -not $manifest.Corrupt) '(install) manifesto'
    Assert-True ([string]$manifest.Value.packageVersion -eq '0.13.0') '(install) versao no manifesto'
    $opencodeRecord = Get-McpManifestClient -Manifest $manifest.Value -Client 'opencode'
    $codexRecord = Get-McpManifestClient -Manifest $manifest.Value -Client 'codex'
    Assert-True (@($opencodeRecord.hashes).Count -ge 1) '(install) hash opencode no manifesto'
    Assert-True (@($codexRecord.hashes).Count -ge 1) '(install) hash codex no manifesto'
    $opencodeText = [System.IO.File]::ReadAllText((Join-Path $oc 'opencode.jsonc'))
    Assert-True ($opencodeText -match 'mcp\.servers|"servers"') '(install) entrada opencode'
    $codexText = [System.IO.File]::ReadAllText((Join-Path $cx 'config.toml'))
    Assert-True ($codexText -match '\[mcp_servers\.jev\]') '(install) entrada codex'

    # 3. Auditoria.
    $auditOutput = & (Join-Path $scriptDir 'Test-McpIntegrations.ps1') 2>&1
    $auditExit = $LASTEXITCODE
    Assert-True ($auditExit -eq 0) "(audit) exit 0; obtido $auditExit"
    $audit = ($auditOutput | ConvertFrom-Json -AsHashtable)
    Assert-True ([string]$audit.overall -eq 'INTEGRATIONS_OK') "(audit) overall OK; obtido $($audit.overall)"
    Assert-True ([string]$audit.clients.opencode.state -in @('escrito', 'recarga_pendente')) '(audit) opencode escrito'
    Assert-True ([string]$audit.clients.codex.state -in @('escrito', 'recarga_pendente')) '(audit) codex escrito'
    Assert-True ([string]$audit.vendor.state -eq 'ok') '(audit) vendor ok'
    Assert-True ([string]$audit.launcher.state -eq 'ok') '(audit) launcher ok'
    Assert-True ($audit.credential.exists -eq $true) '(audit) credencial presente'

    # 4. Reinstalar: idempotente.
    $manifestBeforeRepair = [System.IO.File]::ReadAllText((Get-McpManifestPath))
    $againOutput = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action repair -Client all 2>&1
    $againExit = $LASTEXITCODE
    $manifestAfterRepair = [System.IO.File]::ReadAllText((Get-McpManifestPath))
    Assert-True ($againExit -eq 0) "(repair) exit 0; obtido $againExit"
    $again = ($againOutput | ConvertFrom-Json -AsHashtable)
    $manifestDiff = @(Compare-Object -ReferenceObject @($manifestBeforeRepair -split "`n") -DifferenceObject @($manifestAfterRepair -split "`n") |
        Select-Object -First 8 | ForEach-Object { "$($_.SideIndicator)$($_.InputObject)" }) -join ' | '
    Assert-True ($again.changed -eq $false) "(repair) sem mudanca; obtido changed=$($again.changed); manifestSame=$($manifestBeforeRepair -ceq $manifestAfterRepair); diff=$manifestDiff"
    Assert-True ($manifestBeforeRepair -ceq $manifestAfterRepair) "(repair) manifesto intacto; diff=$manifestDiff"

    # 5. Remover entradas: preserva cofre/config.
    $removeOutput = & (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client all 2>&1
    $removeExit = $LASTEXITCODE
    Assert-True ($removeExit -eq 0) "(remove) exit 0; obtido $removeExit"
    $opencodeText = [System.IO.File]::ReadAllText((Join-Path $oc 'opencode.jsonc'))
    $codexText = [System.IO.File]::ReadAllText((Join-Path $cx 'config.toml'))
    Assert-True ($opencodeText -notmatch '"jev"') '(remove) entrada opencode removida'
    Assert-True ($codexText -notmatch '\[mcp_servers\.jev\]') '(remove) entrada codex removida'
    Assert-True (Test-Path -LiteralPath $configPath) '(remove) config preservado'
    Assert-True (Test-McpVaultExists) '(remove) cofre preservado'

    # 6. Remover dados da skill: cofre preservado.
    $removeDataOutput = & (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client all -RemoveSkillData 2>&1
    $removeDataExit = $LASTEXITCODE
    Assert-True ($removeDataExit -eq 0) "(remove-data) exit 0; obtido $removeDataExit"
    Assert-True (-not (Test-Path -LiteralPath $configPath)) '(remove-data) config removido'
    Assert-True (-not (Test-Path -LiteralPath (Get-McpManifestPath))) '(remove-data) manifesto removido'
    Assert-True (-not (Test-Path -LiteralPath $launcherPath)) '(remove-data) launcher removido'
    Assert-True (-not (Test-Path -LiteralPath $vendorDir)) '(remove-data) vendor removido'
    Assert-True (Test-McpVaultExists) '(remove-data) cofre preservado'

    # 7. Gate do dist real, quando informado.
    if (-not [string]::IsNullOrWhiteSpace($DistManagedRoot)) {
        $distOutput = & (Get-Command pwsh).Source -NoProfile -File (Join-Path $scriptDir 'Test-McpDistEvidenceSelfTest.ps1') -ManagedRoot $DistManagedRoot 2>&1
        $distExit = $LASTEXITCODE
        Assert-True ($distExit -eq 0) "(dist) exit 0; obtido $distExit :: $(($distOutput | Select-Object -Last 3) -join ' | ')"
    }
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
    Write-Output "XPZ_MCP_INTEGRATIONS_SELFTEST_FAILED: $($failures.Count)/$assertCount"
    exit 1
}
Write-Output "XPZ_MCP_INTEGRATIONS_SELFTEST_OK: $assertCount asserts"
exit 0
