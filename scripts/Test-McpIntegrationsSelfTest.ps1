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

    # 4a. repair preserva baseUrl/model do config.json quando omitidos.
    $customBase = 'https://custom.example/provider/v1'
    $customModel = 'custom/jev-model'
    $null = Set-McpConfig -BaseUrl $customBase -Model $customModel -EndpointConfirmed $true
    $repairPreserveOutput = @(& (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action repair -Client all 2>&1)
    $repairPreserveExit = $LASTEXITCODE
    $configAfterPreserve = Get-McpConfig
    Assert-True ($repairPreserveExit -eq 0) "(repair-preserve) exit 0; obtido $repairPreserveExit"
    Assert-True ($null -ne $configAfterPreserve.Value -and [string]$configAfterPreserve.Value.baseUrl -eq $customBase) '(repair-preserve) baseUrl preservada'
    Assert-True ($null -ne $configAfterPreserve.Value -and [string]$configAfterPreserve.Value.model -eq $customModel) '(repair-preserve) model preservado'
    # Restaura preset para o restante do self-test.
    $null = Set-McpConfig -BaseUrl 'https://api.commandcode.ai/provider/v1/systemone' -Model 'typesafe/jev' -EndpointConfirmed $true
    $null = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action repair -Client all 2>&1

    # 4b. Uninstall -WhatIf: planned conta como tratado (INTEGRATIONS_OK / exit 0).
    $whatIfRemoveOutput = @(& (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client all -WhatIf 2>&1)
    $whatIfRemoveExit = $LASTEXITCODE
    $whatIfRemoveText = (($whatIfRemoveOutput | ForEach-Object { [string]$_ }) -join "`n")
    $whatIfRemove = $null
    try { $whatIfRemove = $whatIfRemoveText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($whatIfRemoveExit -eq 0) "(uninstall-whatif) exit 0; obtido $whatIfRemoveExit"
    Assert-True ($null -ne $whatIfRemove -and [string]$whatIfRemove.overall -eq 'INTEGRATIONS_OK') "(uninstall-whatif) overall OK; obtido $($whatIfRemove.overall)"
    Assert-True ($null -ne $whatIfRemove -and [bool]$whatIfRemove.planned -eq $true) '(uninstall-whatif) planned=true'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $oc 'opencode.jsonc')) -match '"jev"') '(uninstall-whatif) opencode intacto'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $cx 'config.toml')) -match '\[mcp_servers\.jev\]') '(uninstall-whatif) codex intacto'

    # 4c. Uninstall OpenCode com chave duplicada: finding entrada_quebrada (exit 66).
    $ocPath = Join-Path $oc 'opencode.jsonc'
    $ocBeforeDup = [System.IO.File]::ReadAllText($ocPath)
    $dupFixture = Join-Path (Get-McpRepoRoot) 'xpz-mcp-integrations-setup\fixtures\opencode\duplicated-key.jsonc'
    [System.IO.File]::Copy($dupFixture, $ocPath, $true)
    $dupUninstallOutput = @(& (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client opencode 2>&1)
    $dupUninstallExit = $LASTEXITCODE
    $dupUninstallText = (($dupUninstallOutput | ForEach-Object { [string]$_ }) -join "`n")
    $dupUninstall = $null
    try { $dupUninstall = $dupUninstallText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($dupUninstallExit -eq 66) "(dup-uninstall) exit 66; obtido $dupUninstallExit"
    Assert-True ($null -ne $dupUninstall -and @($dupUninstall.findings | Where-Object { $_.code -eq 'entrada_quebrada' -and $_.client -eq 'opencode' }).Count -eq 1) '(dup-uninstall) achado entrada_quebrada com client'
    [System.IO.File]::WriteAllText($ocPath, $ocBeforeDup, [System.Text.UTF8Encoding]::new($false))

    # 4d. Manifesto perdido: reinstall reancora hashes de entradas unchanged.
    $manifestPathForAnchor = Get-McpManifestPath
    Remove-Item -LiteralPath $manifestPathForAnchor -Force
    Assert-True (-not (Test-Path -LiteralPath $manifestPathForAnchor)) '(reanchor) manifesto ausente'
    $reanchorOutput = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action install -Client all 2>&1
    $reanchorExit = $LASTEXITCODE
    Assert-True ($reanchorExit -eq 0) "(reanchor) exit 0; obtido $reanchorExit"
    $reanchorManifest = Get-McpManifest
    Assert-True ($reanchorManifest.Exists -and -not $reanchorManifest.Corrupt) '(reanchor) manifesto recriado'
    $reanchorOc = Get-McpManifestClient -Manifest $reanchorManifest.Value -Client 'opencode'
    $reanchorCx = Get-McpManifestClient -Manifest $reanchorManifest.Value -Client 'codex'
    Assert-True ($null -ne $reanchorOc -and @($reanchorOc.hashes).Count -ge 1) '(reanchor) hash opencode'
    Assert-True ($null -ne $reanchorCx -and @($reanchorCx.hashes).Count -ge 1) '(reanchor) hash codex'

    # 4e. -RemoveSkillData recusa apagar shared se outro cliente ainda tem jev live.
    $manifestAfterAnchor = Get-McpManifest
    $manifestAfterAnchor.Value = Remove-McpManifestClient -Manifest $manifestAfterAnchor.Value -Client 'codex'
    $null = Set-McpManifest -Value $manifestAfterAnchor.Value
    $sharedHoldOutput = @(& (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client opencode -RemoveSkillData 2>&1)
    $sharedHoldExit = $LASTEXITCODE
    $sharedHoldText = (($sharedHoldOutput | ForEach-Object { [string]$_ }) -join "`n")
    $sharedHold = $null
    try { $sharedHold = $sharedHoldText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($sharedHoldExit -ne 0) "(shared-hold) exit != 0; obtido $sharedHoldExit"
    Assert-True ($null -ne $sharedHold -and @($sharedHold.findings | Where-Object { $_.code -eq 'dados_compartilhados_em_uso' }).Count -eq 1) '(shared-hold) achado dados_compartilhados_em_uso'
    Assert-True (Test-Path -LiteralPath $launcherPath) '(shared-hold) launcher preservado'
    Assert-True (Test-Path -LiteralPath $vendorDir) '(shared-hold) vendor preservado'
    Assert-True (Test-Path -LiteralPath $configPath) '(shared-hold) config preservado'
    # 4f. Conflito opencode.json+jsonc: -RemoveSkillData fail-closed (nao prova ausencia).
    $null = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action install -Client all 2>&1
    [System.IO.File]::WriteAllText((Join-Path $oc 'opencode.json'), "{`n  `"mcp`": {}`n}`n", [System.Text.UTF8Encoding]::new($false))
    $manifestConflict = Get-McpManifest
    $manifestConflict.Value = Remove-McpManifestClient -Manifest $manifestConflict.Value -Client 'opencode'
    $manifestConflict.Value = Remove-McpManifestClient -Manifest $manifestConflict.Value -Client 'codex'
    $null = Set-McpManifest -Value $manifestConflict.Value
    $conflictHoldOutput = @(& (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client codex -RemoveSkillData 2>&1)
    $conflictHoldExit = $LASTEXITCODE
    $conflictHoldText = (($conflictHoldOutput | ForEach-Object { [string]$_ }) -join "`n")
    $conflictHold = $null
    try { $conflictHold = $conflictHoldText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($conflictHoldExit -ne 0) "(conflict-hold) exit != 0; obtido $conflictHoldExit"
    Assert-True ($null -ne $conflictHold -and @($conflictHold.findings | Where-Object { $_.code -eq 'dados_compartilhados_em_uso' }).Count -eq 1) '(conflict-hold) dados_compartilhados_em_uso'
    Assert-True (Test-Path -LiteralPath $launcherPath) '(conflict-hold) launcher preservado'
    Remove-Item -LiteralPath (Join-Path $oc 'opencode.json') -Force
    # Reancora para o restante do fluxo (remove all / remove-data).
    $null = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action install -Client all 2>&1

    # 4g. Vendor bloqueado por prereq: shape completo e exit 63 (nao 69).
    . (Join-Path $scriptDir 'McpVendorSupport.ps1')
    $savedPathForVendor = $env:PATH
    try {
        $env:PATH = ''
        $blockedVendor = Invoke-McpVendorInstall -WhatIf
        Assert-True ([string]$blockedVendor.status -eq 'blocked') "(vendor-blocked) status blocked; obtido $($blockedVendor.status)"
        Assert-True ($blockedVendor.PSObject.Properties['vendorDir'] -and $null -ne $blockedVendor.vendorDir) '(vendor-blocked) vendorDir presente'
        Assert-True ($blockedVendor.PSObject.Properties['entryPath'] -and $null -ne $blockedVendor.entryPath) '(vendor-blocked) entryPath presente'
        Assert-True ([int]$blockedVendor.exitCode -eq 63) "(vendor-blocked) exit 63; obtido $($blockedVendor.exitCode)"
        $vendorScriptOut = @(& (Join-Path $scriptDir 'Invoke-McpVendor.ps1') -WhatIf 2>&1)
        $vendorScriptExit = $LASTEXITCODE
        $vendorScriptText = (($vendorScriptOut | ForEach-Object { [string]$_ }) -join "`n")
        $vendorScriptJson = $null
        try { $vendorScriptJson = $vendorScriptText | ConvertFrom-Json -AsHashtable } catch { }
        Assert-True ($vendorScriptExit -eq 63) "(vendor-script) exit 63; obtido $vendorScriptExit"
        Assert-True ($null -ne $vendorScriptJson -and [int]$vendorScriptJson.exitCode -eq 63) '(vendor-script) JSON exitCode 63'
        Assert-True ($null -ne $vendorScriptJson -and [string]$vendorScriptJson.status -eq 'blocked') '(vendor-script) status blocked'
    } finally {
        $env:PATH = $savedPathForVendor
    }

    # 4h. -Client all -RemoveSkillData -WhatIf: plano completo sem apagar shared/entradas.
    $whatIfDataOutput = @(& (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client all -RemoveSkillData -WhatIf 2>&1)
    $whatIfDataExit = $LASTEXITCODE
    $whatIfDataText = (($whatIfDataOutput | ForEach-Object { [string]$_ }) -join "`n")
    $whatIfData = $null
    try { $whatIfData = $whatIfDataText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($whatIfDataExit -eq 0) "(uninstall-whatif-data) exit 0; obtido $whatIfDataExit"
    Assert-True ($null -ne $whatIfData -and [string]$whatIfData.overall -eq 'INTEGRATIONS_OK') "(uninstall-whatif-data) overall OK; obtido $($whatIfData.overall)"
    Assert-True ($null -ne $whatIfData -and [bool]$whatIfData.planned -eq $true) '(uninstall-whatif-data) planned=true'
    Assert-True ($null -ne $whatIfData -and @($whatIfData.findings | Where-Object { $_.code -eq 'dados_compartilhados_em_uso' }).Count -eq 0) '(uninstall-whatif-data) sem dados_compartilhados_em_uso'
    Assert-True ($null -ne $whatIfData -and [bool]$whatIfData.launcherRemoved -eq $true) '(uninstall-whatif-data) launcherRemoved planejado'
    Assert-True ($null -ne $whatIfData -and [bool]$whatIfData.vendorRemoved -eq $true) '(uninstall-whatif-data) vendorRemoved planejado'
    Assert-True ($null -ne $whatIfData -and [bool]$whatIfData.dataRemoved -eq $true) '(uninstall-whatif-data) dataRemoved planejado'
    Assert-True (Test-Path -LiteralPath $launcherPath) '(uninstall-whatif-data) launcher intacto'
    Assert-True (Test-Path -LiteralPath $vendorDir) '(uninstall-whatif-data) vendor intacto'
    Assert-True (Test-Path -LiteralPath $configPath) '(uninstall-whatif-data) config intacto'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $oc 'opencode.jsonc')) -match '"jev"') '(uninstall-whatif-data) opencode intacto'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $cx 'config.toml')) -match '\[mcp_servers\.jev\]') '(uninstall-whatif-data) codex intacto'

    # 4i. Uninstall reconhece emissao atual via config.json customizado (sem hashes no manifesto).
    $customRemoveBase = 'https://custom-remove.example/provider/v1'
    $customRemoveModel = 'custom/remove-model'
    $null = Set-McpConfig -BaseUrl $customRemoveBase -Model $customRemoveModel -EndpointConfirmed $true
    $null = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action repair -Client all 2>&1
    $manifestNoHashes = Get-McpManifest
    foreach ($clientName in @('opencode', 'codex')) {
        $rec = Get-McpManifestClient -Manifest $manifestNoHashes.Value -Client $clientName
        Assert-True ($null -ne $rec) "(custom-remove) cliente $clientName no manifesto"
        if ($null -ne $rec) {
            $manifestNoHashes.Value.clients[$clientName] = [ordered]@{
                path               = [string]$rec.path
                hashes             = @()
                lastWriteUtcTicks  = $rec.lastWriteUtcTicks
            }
        }
    }
    $null = Set-McpManifest -Value $manifestNoHashes.Value
    $customRemoveOutput = @(& (Join-Path $scriptDir 'Uninstall-McpIntegration.ps1') -Client all 2>&1)
    $customRemoveExit = $LASTEXITCODE
    Assert-True ($customRemoveExit -eq 0) "(custom-remove) exit 0; obtido $customRemoveExit"
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $oc 'opencode.jsonc')) -notmatch '"jev"') '(custom-remove) entrada opencode removida'
    Assert-True ([System.IO.File]::ReadAllText((Join-Path $cx 'config.toml')) -notmatch '\[mcp_servers\.jev\]') '(custom-remove) entrada codex removida'
    # Restaura preset e reancora para o passo 5 (remove real).
    $null = Set-McpConfig -BaseUrl 'https://api.commandcode.ai/provider/v1/systemone' -Model 'typesafe/jev' -EndpointConfirmed $true
    $null = & (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action install -Client all 2>&1

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

    # 7b. Install OpenCode com chave duplicada: finding entrada_quebrada (exit 66).
    $dupFixture = Join-Path (Get-McpRepoRoot) 'xpz-mcp-integrations-setup\fixtures\opencode\duplicated-key.jsonc'
    [System.IO.File]::Copy($dupFixture, (Join-Path $oc 'opencode.jsonc'), $true)
    $dupInstallOutput = @(& (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action install -Client opencode 2>&1)
    $dupInstallExit = $LASTEXITCODE
    $dupInstallText = (($dupInstallOutput | ForEach-Object { [string]$_ }) -join "`n")
    $dupInstall = $null
    try { $dupInstall = $dupInstallText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($dupInstallExit -eq 66) "(dup-install) exit 66; obtido $dupInstallExit"
    Assert-True ($null -ne $dupInstall -and @($dupInstall.findings | Where-Object { $_.code -eq 'entrada_quebrada' -and $_.client -eq 'opencode' }).Count -eq 1) '(dup-install) achado entrada_quebrada com client'
    [System.IO.File]::WriteAllText((Join-Path $oc 'opencode.jsonc'), "{`n  `"mcp`": { `"servers`": {} }`n}`n", [System.Text.UTF8Encoding]::new($false))

    # 7c. Install Codex com entrada manual migravel: edicao_manual_necessaria (exit 67).
    $manualCodex = @"
model = `"gpt-5`"

[mcp_servers.jev]
command = `"node`"
args = [`"legacy.js`"]
"@
    [System.IO.File]::WriteAllText((Join-Path $cx 'config.toml'), $manualCodex, [System.Text.UTF8Encoding]::new($false))
    $manualInstallOutput = @(& (Join-Path $scriptDir 'Install-McpIntegration.ps1') -Action install -Client codex 2>&1)
    $manualInstallExit = $LASTEXITCODE
    $manualInstallText = (($manualInstallOutput | ForEach-Object { [string]$_ }) -join "`n")
    $manualInstall = $null
    try { $manualInstall = $manualInstallText | ConvertFrom-Json -AsHashtable } catch { }
    Assert-True ($manualInstallExit -eq 67) "(manual-codex-install) exit 67; obtido $manualInstallExit"
    Assert-True ($null -ne $manualInstall -and @($manualInstall.findings | Where-Object { $_.code -eq 'edicao_manual_necessaria' -and $_.client -eq 'codex' }).Count -eq 1) '(manual-codex-install) achado edicao_manual_necessaria'
    Assert-True ($null -ne $manualInstall -and (@($manualInstall.nextActions) -join "`n") -match 'MigrateLegacy') '(manual-codex-install) nextAction MigrateLegacy'

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

    # 9. Guarda do gate do dist: leaf errado; leaf certo com manifesto.
    $badLeafRoot = Join-Path $tempRoot 'dist-guard'
    [System.IO.Directory]::CreateDirectory($badLeafRoot) | Out-Null
    $badLeafOutput = @(& (Get-Command pwsh).Source -NoProfile -File (Join-Path $scriptDir 'Test-McpDistEvidenceSelfTest.ps1') -ManagedRoot $badLeafRoot 2>&1)
    $badLeafExit = $LASTEXITCODE
    Assert-True ($badLeafExit -ne 0) "(dist leaf) leaf errado recusado; obtido exit $badLeafExit"
    Assert-True (($badLeafOutput -join "`n").Contains('MANAGED_ROOT_LEAF')) '(dist leaf) motivo LEAF explicito'

    $guardParent = Join-Path $tempRoot 'dist-guard-parent'
    $guardRoot = Join-Path $guardParent 'xpz-mcp-integrations'
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
