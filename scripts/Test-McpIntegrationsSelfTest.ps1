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
    Assert-True (@($audit.findings | Where-Object { $_.code -eq 'acl_nao_aplicavel' }).Count -eq 0) '(audit) sem warn ACL apos install com ACL so-dono'

    # 4. Reinstalar: idempotente; repair reaplica ACL do manifesto em unchanged.
    $manifestPath = Get-McpManifestPath
    Assert-True (Test-McpAcl -Path $manifestPath) '(pre-repair) manifesto com ACL so-dono'
    # Recriar o ficheiro herda ACL do diretorio (sem so-dono protegido); evita Set-Acl/SeSecurityPrivilege.
    $manifestBytes = [System.IO.File]::ReadAllBytes($manifestPath)
    Remove-Item -LiteralPath $manifestPath -Force
    [System.IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
    Assert-True (-not (Test-McpAcl -Path $manifestPath)) '(pre-repair) ACL do manifesto quebrada de proposito'
    $manifestBeforeRepair = [System.IO.File]::ReadAllText($manifestPath)
    $againOutput = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action repair -Client all 2>&1
    $againExit = $LASTEXITCODE
    $manifestAfterRepair = [System.IO.File]::ReadAllText($manifestPath)
    Assert-True ($againExit -eq 0) "(repair) exit 0; obtido $againExit"
    $again = ($againOutput | ConvertFrom-Json -AsHashtable)
    $manifestDiff = @(Compare-Object -ReferenceObject @($manifestBeforeRepair -split "`n") -DifferenceObject @($manifestAfterRepair -split "`n") |
        Select-Object -First 8 | ForEach-Object { "$($_.SideIndicator)$($_.InputObject)" }) -join ' | '
    Assert-True ($again.changed -eq $false) "(repair) sem mudanca; obtido changed=$($again.changed); manifestSame=$($manifestBeforeRepair -ceq $manifestAfterRepair); diff=$manifestDiff"
    Assert-True ($manifestBeforeRepair -ceq $manifestAfterRepair) "(repair) manifesto intacto; diff=$manifestDiff"
    Assert-True (Test-McpAcl -Path $manifestPath) '(repair) ACL do manifesto reaplicada em unchanged'

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
    $manifestAfterRemove = Get-McpManifest
    Assert-True ($manifestAfterRemove.Exists -and -not $manifestAfterRemove.Corrupt) '(remove) manifesto permanece'
    Assert-True (@($manifestAfterRemove.Value.clients.Keys).Count -eq 0) '(remove) manifesto clients vazio persistido'

    # 6. Remover dados da skill: cofre preservado.
    $removeDataOutput = & (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client all -RemoveSkillData 2>&1
    $removeDataExit = $LASTEXITCODE
    Assert-True ($removeDataExit -eq 0) "(remove-data) exit 0; obtido $removeDataExit"
    Assert-True (-not (Test-Path -LiteralPath $configPath)) '(remove-data) config removido'
    Assert-True (-not (Test-Path -LiteralPath (Get-McpManifestPath))) '(remove-data) manifesto removido'
    Assert-True (-not (Test-Path -LiteralPath $launcherPath)) '(remove-data) launcher removido'
    Assert-True (-not (Test-Path -LiteralPath $vendorDir)) '(remove-data) vendor removido'
    Assert-True (Test-McpVaultExists) '(remove-data) cofre preservado'

    # 6b. Install sem cofre: blocking antes de qualquer escrita (G1).
    Remove-Item -LiteralPath (Get-McpVaultBlobPath) -Force
    $noCredOutput = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action install -Client all 2>&1
    $noCredExit = $LASTEXITCODE
    $noCredText = (($noCredOutput | ForEach-Object { [string]$_ }) -join "`n")
    $noCred = $null
    try { $noCred = $noCredText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($noCredExit -eq 61) "(no-cred) exit 61; obtido $noCredExit"
    Assert-True ($null -ne $noCred -and [string]$noCred.overall -eq 'INTEGRATIONS_GAPS') '(no-cred) overall GAPS'
    Assert-True ($null -ne $noCred -and @($noCred.findings | Where-Object { $_.code -eq 'credencial_ausente' }).Count -eq 1) '(no-cred) achado credencial_ausente'
    Assert-True (-not (Test-Path -LiteralPath $launcherPath)) '(no-cred) launcher nao emitido sem cofre'
    Assert-True (-not (Test-Path -LiteralPath $vendorDir)) '(no-cred) vendor nao instalado sem cofre'

    # 6c. Repair sem cofre: mesmo gate blocking antes de escrita.
    $noCredRepairOutput = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action repair -Client all 2>&1
    $noCredRepairExit = $LASTEXITCODE
    $noCredRepairText = (($noCredRepairOutput | ForEach-Object { [string]$_ }) -join "`n")
    $noCredRepair = $null
    try { $noCredRepair = $noCredRepairText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($noCredRepairExit -eq 61) "(no-cred-repair) exit 61; obtido $noCredRepairExit"
    Assert-True ($null -ne $noCredRepair -and [string]$noCredRepair.overall -eq 'INTEGRATIONS_GAPS') '(no-cred-repair) overall GAPS'
    Assert-True ($null -ne $noCredRepair -and @($noCredRepair.findings | Where-Object { $_.code -eq 'credencial_ausente' }).Count -eq 1) '(no-cred-repair) achado credencial_ausente'
    Assert-True (-not (Test-Path -LiteralPath $launcherPath)) '(no-cred-repair) launcher nao emitido sem cofre'
    Assert-True (-not (Test-Path -LiteralPath $vendorDir)) '(no-cred-repair) vendor nao instalado sem cofre'
    $null = Write-McpVault -SecureSecret (ConvertTo-SecureString 'test-secret-selftest' -AsPlainText -Force)

    # 7. Auditoria de entrada manual migravel: edicao_manual_necessaria e
    # nextAction -MigrateLegacy, com exit 67 pela precedencia.
    $legacyRoot = Join-Path $tempRoot 'legacy-profile'
    $legacyOc = Join-Path $legacyRoot '.config\opencode'
    [System.IO.Directory]::CreateDirectory($legacyOc) | Out-Null
    $legacyJsonc = @"
{
  "mcp": {
    "jev": {
      "type": "local",
      "command": ["node", "legacy.js"],
      "enabled": true
    }
  }
}
"@
    [System.IO.File]::WriteAllText((Join-Path $legacyOc 'opencode.jsonc'), $legacyJsonc, [System.Text.UTF8Encoding]::new($false))
    $legacyInput = Join-Path $legacyRoot 'audit-input.json'
    [System.IO.File]::WriteAllText($legacyInput, (@{ userProfile = $legacyRoot; localAppData = $legacyRoot } | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
    $legacyOutput = @(& (Get-Command pwsh).Source -NoProfile -File (Join-Path $scriptDir 'Test-McpIntegrations.ps1') -InputPath $legacyInput 2>&1)
    $legacyExit = $LASTEXITCODE
    $legacyText = (($legacyOutput | ForEach-Object { [string]$_ }) -join "`n")
    $legacyAudit = $null
    try { $legacyAudit = $legacyText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($legacyExit -eq 67) "(legacy) exit 67; obtido $legacyExit"
    Assert-True ($null -ne $legacyAudit -and [string]$legacyAudit.clients.opencode.form -eq 'legacy') '(legacy) form legacy'
    Assert-True ($null -ne $legacyAudit -and @($legacyAudit.findings | Where-Object { $_.code -eq 'edicao_manual_necessaria' }).Count -eq 1) '(legacy) achado edicao_manual_necessaria'
    Assert-True ($null -ne $legacyAudit -and [string](@($legacyAudit.nextActions)[0]) -like '*opencode*MigrateLegacy*') '(legacy) nextAction MigrateLegacy'
    Assert-True ($null -ne $legacyAudit -and [string]$legacyAudit.nextActionsMode -eq 'possible-actions') '(legacy) nextActions como menu'

    # 8. Warn de ACL na auditoria: pasta/blob sem ACL so-dono (heranca default do temp).
    $aclWarnRoot = Join-Path $tempRoot 'acl-warn-profile'
    $aclManaged = Join-Path $aclWarnRoot 'xpz-mcp-integrations'
    $aclVault = Join-Path $aclManaged 'vault'
    [System.IO.Directory]::CreateDirectory($aclVault) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $aclVault 'credential.blob'), "{`"version`":1}`n", [System.Text.UTF8Encoding]::new($false))
    Assert-True (-not (Test-McpAcl -Path $aclManaged)) '(acl-warn) managed-root sem ACL so-dono'
    Assert-True (-not (Test-McpAcl -Path $aclVault)) '(acl-warn) vault-dir sem ACL so-dono'
    $aclWarnInput = Join-Path $aclWarnRoot 'audit-input.json'
    [System.IO.File]::WriteAllText(
        $aclWarnInput,
        (@{ userProfile = $aclWarnRoot; localAppData = $aclWarnRoot } | ConvertTo-Json),
        [System.Text.UTF8Encoding]::new($false)
    )
    $aclWarnOutput = @(& (Get-Command pwsh).Source -NoProfile -File (Join-Path $scriptDir 'Test-McpIntegrations.ps1') -InputPath $aclWarnInput 2>&1)
    $aclWarnText = (($aclWarnOutput | ForEach-Object { [string]$_ }) -join "`n")
    $aclWarnAudit = $null
    try { $aclWarnAudit = $aclWarnText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($null -ne $aclWarnAudit) '(acl-warn) JSON de auditoria parseavel'
    $aclWarnFindings = @($aclWarnAudit.findings | Where-Object { $_.code -eq 'acl_nao_aplicavel' -and $_.class -eq 'warn' })
    Assert-True ($aclWarnFindings.Count -eq 1) "(acl-warn) um achado warn acl_nao_aplicavel; obtido $($aclWarnFindings.Count)"
    Assert-True ([string]$aclWarnFindings[0].message -match 'managed-root|vault') '(acl-warn) mensagem cita path gerenciado'
    Assert-True (@($aclWarnAudit.nextActions | Where-Object { $_ -match 'repair|Set-McpCredential' }).Count -ge 1) '(acl-warn) nextActions de reparo/ACL'

    # 9. Guarda do gate do dist: root com manifesto nao pode ganhar cofre falso.
    $guardRoot = Join-Path $tempRoot 'dist-guard'
    [System.IO.Directory]::CreateDirectory($guardRoot) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $guardRoot 'install-manifest.json'), '{}', [System.Text.UTF8Encoding]::new($false))
    $guardOutput = @(& (Get-Command pwsh).Source -NoProfile -File (Join-Path $scriptDir 'Test-McpDistEvidenceSelfTest.ps1') -ManagedRoot $guardRoot 2>&1)
    $guardExit = $LASTEXITCODE
    Assert-True ($guardExit -ne 0) "(dist guard) root com manifesto recusado; obtido exit $guardExit"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $guardRoot 'vault\credential.blob'))) '(dist guard) nenhum cofre criado'
    Assert-True (($guardOutput -join "`n").Contains('NOT_DISPOSABLE')) '(dist guard) motivo explicito'

    # 10. Gate do dist real, quando informado.
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
