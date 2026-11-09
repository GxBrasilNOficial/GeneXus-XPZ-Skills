#requires -Version 7.4

<#
.SYNOPSIS
    Instalador/reparador/atualizador da skill xpz-mcp-integrations-setup.

.DESCRIPTION
    Mutador com -WhatIf. Instala o componente Jev/System One vendorizado,
    emite o launcher por versao, grava config.json nao secreto, registra o
    manifesto de instalacao e emite a entrada nos clientes OpenCode e/ou Codex.
    Nada e gravado sem chamada explicita deste motor; a credencial vem do cofre
    DPAPI e nunca do config do cliente.

    Action update exige -AllowUpdate. Nao existe verificação automatica de nova
    versao na v1 (-CheckUpdates fica no F2).
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('install', 'repair', 'update', 'record-e2e')]
    [string]$Action = 'install',

    [ValidateSet('all', 'opencode', 'codex')]
    [string]$Client = 'all',

    [ValidateSet('compatible')]
    [string]$Provider = 'compatible',

    [string]$BaseUrl,

    [string]$Model,

    [switch]$ConfirmEndpoint,

    [switch]$MigrateLegacy,

    [switch]$AllowUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    $mcpInternalMessage = [string]$_.Exception.Message
    if (Get-Command Write-McpInternalFailure -ErrorAction SilentlyContinue) {
        Write-McpInternalFailure -Message $mcpInternalMessage -Kind 'mutation' -ActionName $Action
    }
    [pscustomobject][ordered]@{
        schemaVersion  = 1
        kind           = 'xpz-mcp-integrations-setup-internal-error'
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        overall        = 'INTEGRATIONS_GAPS'
        exitCode       = 69
        findings       = @([ordered]@{ code = 'erro_interno'; class = 'blocking'; message = $mcpInternalMessage })
    } | ConvertTo-Json -Depth 10
    exit 69
}

$scriptDir = $PSScriptRoot
. (Join-Path $scriptDir 'McpIntegrationSupport.ps1')
. (Join-Path $scriptDir 'McpVaultSupport.ps1')
. (Join-Path $scriptDir 'McpLauncherSupport.ps1')
. (Join-Path $scriptDir 'McpVendorSupport.ps1')
. (Join-Path $scriptDir 'McpOpenCodeSupport.ps1')
. (Join-Path $scriptDir 'McpCodexSupport.ps1')

function New-McpMutationResult {
    param(
        [string]$ActionName,
        [string]$Overall,
        [int]$ExitCode,
        [bool]$Changed,
        [bool]$Planned,
        $Findings,
        $Clients,
        $Vendor,
        $Launcher,
        $Config,
        $Credential,
        $NextActions
    )
    return [ordered]@{
        schemaVersion  = 1
        kind           = 'xpz-mcp-integrations-setup-mutation'
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        action         = $ActionName
        overall        = $Overall
        exitCode       = $ExitCode
        changed        = $Changed
        planned        = $Planned
        findings       = @($Findings)
        clients        = $Clients
        vendor         = $Vendor
        launcher       = $Launcher
        config         = $Config
        credential     = $Credential
        nextActions    = @($NextActions)
    }
}

$findings = [System.Collections.Generic.List[object]]::new()
$nextActions = [System.Collections.Generic.List[string]]::new()
$clientsResult = [ordered]@{}
$changed = $false
$planned = [bool]$WhatIfPreference

if ($Action -eq 'record-e2e') {
    if ($Client -eq 'all') {
        $findings.Add((New-McpFinding -Code 'client_obrigatorio' -Class 'blocking' -Message 'record-e2e exige -Client opencode ou codex')) | Out-Null
        $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode 67 -Changed $false -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $null -Launcher $null -Config $null -Credential $null -NextActions $nextActions
        [pscustomobject]$result | ConvertTo-Json -Depth 30
        exit 67
    }
    $manifest = Get-McpManifest
    if ($manifest.Corrupt) {
        $findings.Add((New-McpFinding -Code 'manifesto_corrompido' -Class 'blocking' -Message $manifest.Error)) | Out-Null
        $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode 67 -Changed $false -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $null -Launcher $null -Config $null -Credential $null -NextActions $nextActions
        [pscustomobject]$result | ConvertTo-Json -Depth 30
        exit 67
    }
    if (-not $WhatIfPreference) {
        if ($null -eq $manifest.Value.e2e) {
            $manifest.Value.e2e = [ordered]@{}
        }
        if ($manifest.Value.e2e -isnot [System.Collections.IDictionary]) {
            $manifest.Value.e2e = ConvertTo-McpOrdered -Value $manifest.Value.e2e
        }
        $manifest.Value.e2e[$Client] = [DateTime]::UtcNow.Ticks
        $null = Set-McpManifest -Value $manifest.Value
        $changed = $true
    }
    $clientsResult[$Client] = [ordered]@{ state = 'e2e_opt_in_confirmado'; recorded = -not $planned }
    $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_OK' -ExitCode 0 -Changed $changed -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $null -Launcher $null -Config $null -Credential $null -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 30
    exit 0
}

if ($Action -eq 'update' -and -not $AllowUpdate) {
    $findings.Add((New-McpFinding -Code 'atualizacao_sem_aprovacao' -Class 'blocking' -Message 'Action update exige -AllowUpdate; nao ha atualizacao automatica')) | Out-Null
    $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode 67 -Changed $false -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $null -Launcher $null -Config $null -Credential $null -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 30
    exit 67
}

$descriptor = $null
try {
    $descriptor = Get-McpDescriptor
} catch {
    $findings.Add((New-McpFinding -Code 'descriptor_invalido' -Class 'blocking' -Message $_.Exception.Message)) | Out-Null
}
if ($null -eq $descriptor) {
    $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode 60 -Changed $false -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $null -Launcher $null -Config $null -Credential $null -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 30
    exit 60
}
$component = $descriptor.Descriptor.component
$compatible = $descriptor.Descriptor.modes.compatible
if ($compatible.endpointRule -ne 'explicit-url') {
    $findings.Add((New-McpFinding -Code 'descriptor_invalido' -Class 'blocking' -Message 'modo compatible sem regra explicit-url')) | Out-Null
}
$preset = $descriptor.Descriptor.presets[$compatible.preset]

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    $BaseUrl = [string]$preset.baseUrl
}
if ([string]::IsNullOrWhiteSpace($Model)) {
    $Model = [string]$preset.model
}
if ($BaseUrl -notmatch '^https://[^\s]+$') {
    $findings.Add((New-McpFinding -Code 'endpoint_invalido' -Class 'blocking' -Message 'baseUrl deve ser https')) | Out-Null
}
$baseUri = $null
$presetUri = $null
try { $baseUri = [Uri]::new($BaseUrl) } catch { }
try { $presetUri = [Uri]::new([string]$preset.baseUrl) } catch { }
$hostMatchesPreset = ($null -ne $baseUri -and $null -ne $presetUri -and $baseUri.Host -eq $presetUri.Host)
$endpointConfirmed = $hostMatchesPreset -or [bool]$ConfirmEndpoint
if (-not $hostMatchesPreset -and -not $ConfirmEndpoint) {
    $findings.Add((New-McpFinding -Code 'endpoint_nao_confirmado' -Class 'blocking' -Message ('host ' + $(if ($null -ne $baseUri) { $baseUri.Host } else { '<invalido>' }) + ' difere do preset Command Code; use -ConfirmEndpoint'))) | Out-Null
}

$prerequisites = Get-McpPrerequisites
$prereqFindings = @(Get-McpPrerequisiteFindings -Prerequisites $prerequisites)
foreach ($finding in $prereqFindings) {
    if ($finding.code -ne 'python_indisponivel') {
        $findings.Add($finding) | Out-Null
    } elseif ($Client -in @('all', 'codex')) {
        $findings.Add($finding) | Out-Null
    }
}
if (-not $prerequisites.NodeCompatible -and $prerequisites.Winget.Present) {
    $nextActions.Add('winget install --id OpenJS.NodeJS.LTS -e') | Out-Null
}

$blockingBeforeInstall = @($findings | Where-Object { $_.class -eq 'blocking' })
$vendor = $null
$launcher = $null
$config = $null
$credential = [ordered]@{ exists = (Test-McpVaultExists); source = 'vault-dpapi' }
if ($Action -in @('install', 'update') -and -not $credential.exists) {
    $findings.Add((New-McpFinding -Code 'credencial_ausente' -Class 'blocking' -Message 'cofre DPAPI ausente; importe/defina a chave antes de instalar')) | Out-Null
    $nextActions.Add('Set-McpCredential.ps1 -Action import -ImportFromOpenCode') | Out-Null
    $nextActions.Add('Set-McpCredential.ps1 -Action set') | Out-Null
}

if ($blockingBeforeInstall.Count -gt 0) {
    $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode (Get-McpExitCodeForFindings -Findings @($findings)) -Changed $false -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $null -Launcher $null -Config $null -Credential $credential -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 30
    exit ([int]$result.exitCode)
}

# Caminho gerenciado + ACL so-dono antes de persistir. Em -WhatIf nada e criado.
if ($WhatIfPreference) {
    $managedRoot = Get-McpManagedRoot
} else {
    $managedRoot = Ensure-McpManagedRoot
    try {
        $null = Set-McpAcl -Path $managedRoot -Directory
    } catch {
        $findings.Add((New-McpFinding -Code 'acl_nao_aplicavel' -Class 'blocking' -Message $_.Exception.Message)) | Out-Null
        $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode 67 -Changed $false -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $null -Launcher $null -Config $null -Credential $credential -NextActions $nextActions
        [pscustomobject]$result | ConvertTo-Json -Depth 30
        exit 67
    }
}

$pin = Get-McpVendorPin
$vendor = Test-McpVendor -Pin $pin
if ($vendor.state -ne 'ok') {
    if ($WhatIfPreference) {
        $vendor = [pscustomobject]@{ state = 'planned'; vendorDir = (Get-McpVendorDir -Version $pin.Version); entryPath = (Get-McpVendorEntryPath -Version $pin.Version -Package $pin.Package -DistEntry $pin.DistEntry); version = $pin.Version }
    } else {
        $vendorInstall = Invoke-McpVendorInstall
        if ($vendorInstall.status -notin @('ok', 'unchanged')) {
            $findings.Add((New-McpFinding -Code 'vendor_falhou' -Class 'blocking' -Message ('vendor: ' + [string]$vendorInstall.status))) | Out-Null
            $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode 64 -Changed $false -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $vendorInstall -Launcher $null -Config $null -Credential $credential -NextActions $nextActions
            [pscustomobject]$result | ConvertTo-Json -Depth 30
            exit 64
        }
        $vendor = Test-McpVendor -Pin $pin
        $changed = $true
    }
}
if ($vendor.state -eq 'vendor_divergente') {
    $findings.Add((New-McpFinding -Code 'vendor_divergente' -Class 'blocking' -Message 'versao instalada diverge do pin')) | Out-Null
}

$nodePath = Get-McpNodePath
if ([string]::IsNullOrWhiteSpace($nodePath)) {
    $findings.Add((New-McpFinding -Code 'node_incompativel' -Class 'blocking' -Message 'node >= 22 nao resolvido em caminho absoluto')) | Out-Null
    $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode 63 -Changed $false -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $vendor -Launcher $null -Config $null -Credential $credential -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 30
    exit 63
}

$launcher = Install-McpLauncher `
    -Version $pin.Version `
    -NodePath $nodePath `
    -EntryPath $vendor.entryPath `
    -VendorDir $vendor.vendorDir `
    -WhatIf:$WhatIfPreference
if ($launcher.Status -eq 'written') { $changed = $true }

$config = Set-McpConfig -BaseUrl $BaseUrl -Model $Model -EndpointConfirmed $endpointConfirmed -WhatIf:$WhatIfPreference
if ($config.Status -eq 'written') { $changed = $true }

$manifest = Get-McpManifest
if ($manifest.Corrupt) {
    $findings.Add((New-McpFinding -Code 'manifesto_corrompido' -Class 'blocking' -Message $manifest.Error)) | Out-Null
    $result = New-McpMutationResult -ActionName $Action -Overall 'INTEGRATIONS_GAPS' -ExitCode 67 -Changed $changed -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $vendor -Launcher $launcher -Config $config -Credential $credential -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 30
    exit 67
}
if ($Action -eq 'update' -and $manifest.Exists -and [string]$manifest.Value.packageVersion -eq $pin.Version) {
    $findings.Add((New-McpFinding -Code 'atualizacao_sem_versao_nova' -Class 'warn' -Message 'Action update sem versao nova; tratado como reparo')) | Out-Null
}
$manifest.Value.packageVersion = $pin.Version

$manifestLauncher = Get-McpManifestLauncher -Manifest $manifest.Value -Version $pin.Version
if ($null -eq $manifestLauncher -or [string]$manifestLauncher.sha256 -ne [string]$launcher.Hash) {
    if (-not $WhatIfPreference) {
        $manifest.Value = Set-McpManifestLauncher -Manifest $manifest.Value -Version $pin.Version -Path $launcher.Path -Sentinel (Get-McpLauncherSentinel) -Hash ([string]$launcher.Hash)
        $changed = $true
    }
}

$selectedClients = @()
if ($Client -eq 'all') {
    $selectedClients = @('opencode', 'codex')
} else {
    $selectedClients = @($Client)
}

foreach ($clientName in $selectedClients) {
    $clientFindingStart = $findings.Count
    if ($clientName -eq 'opencode') {
        $target = Get-McpOpenCodeConfigTarget
        if ($target.status -eq 'conflict') {
            $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message $target.reason -Client 'opencode')) | Out-Null
            $clientsResult['opencode'] = [ordered]@{ state = 'nao_configurado'; status = 'conflict'; path = $null; written = $false }
            continue
        }
        if ($target.status -eq 'absent') {
            $installed = Test-McpClientInstalled -Client 'opencode'
            $clientsResult['opencode'] = [ordered]@{ state = 'nao_configurado'; status = $(if ($installed) { 'absent' } else { 'not-installed' }); path = $null; written = $false; reason = 'opencode.json/opencode.jsonc ausente' }
            if ($installed) {
                $findings.Add((New-McpFinding -Code 'config_ausente' -Class 'blocking' -Message 'OpenCode sem opencode.json/jsonc; abra o OpenCode uma vez ou crie a config' -Client 'opencode')) | Out-Null
            } elseif ($Client -eq 'opencode') {
                $findings.Add((New-McpFinding -Code 'client_nao_instalado' -Class 'warn' -Message 'OpenCode nao detectado nesta maquina' -Client 'opencode')) | Out-Null
            }
            continue
        }
        $clientRecord = Get-McpManifestClient -Manifest $manifest.Value -Client 'opencode'
        $hashes = @()
        if ($null -ne $clientRecord -and $null -ne $clientRecord.hashes) { $hashes = @($clientRecord.hashes) }
        $update = Update-McpOpenCodeConfig -Path $target.path -LauncherPath $launcher.Path -BaseUrl $BaseUrl -Model $Model -ManifestHashes $hashes -Action install -MigrateLegacy:$MigrateLegacy -WhatIf:$WhatIfPreference
        $clientsResult['opencode'] = [ordered]@{
            state    = $(if ($update.status -eq 'written') { 'escrito' } elseif ($update.status -eq 'unchanged') { 'escrito' } else { 'nao_configurado' })
            status   = $update.status
            path     = $target.path
            written  = [bool]$update.written
            action   = $update.action
            diff     = if ($update.PSObject.Properties['diff']) { $update.diff } else { $null }
            snippet  = if ($update.PSObject.Properties['snippet']) { $update.snippet } else { $null }
            reason   = if ($update.PSObject.Properties['reason']) { $update.reason } else { $null }
        }
        if ($update.status -in @('manual', 'entrada_em_conflito', 'conflict')) {
            $findings.Add((New-McpFinding -Code $(if ($update.status -eq 'manual') { 'edicao_manual_necessaria' } else { 'entrada_em_conflito' }) -Class 'blocking' -Message ([string]$update.reason) -Client 'opencode')) | Out-Null
        }
        if ($update.status -eq 'written' -and -not [string]::IsNullOrWhiteSpace([string]$update.entryHash) -and -not $WhatIfPreference) {
            $manifest.Value = Add-McpManifestClientHash -Manifest $manifest.Value -Client 'opencode' -Path $target.path -Hash ([string]$update.entryHash)
            $changed = $true
        }
        continue
    }
    if ($clientName -eq 'codex') {
        $codexPath = Get-McpCodexConfigPath
        if (-not (Test-McpRegularFile -Path $codexPath)) {
            $installed = Test-McpClientInstalled -Client 'codex'
            $clientsResult['codex'] = [ordered]@{ state = 'nao_configurado'; status = $(if ($installed) { 'absent' } else { 'not-installed' }); path = $codexPath; written = $false }
            if ($installed) {
                $findings.Add((New-McpFinding -Code 'config_ausente' -Class 'blocking' -Message 'Codex sem config.toml; abra o Codex uma vez ou crie a config' -Client 'codex')) | Out-Null
            } elseif ($Client -eq 'codex') {
                $findings.Add((New-McpFinding -Code 'client_nao_instalado' -Class 'warn' -Message 'Codex nao detectado nesta maquina' -Client 'codex')) | Out-Null
            }
            continue
        }
        $clientRecord = Get-McpManifestClient -Manifest $manifest.Value -Client 'codex'
        $hashes = @()
        if ($null -ne $clientRecord -and $null -ne $clientRecord.hashes) { $hashes = @($clientRecord.hashes) }
        $update = Update-McpCodexConfig -Path $codexPath -LauncherPath $launcher.Path -BaseUrl $BaseUrl -Model $Model -ManifestHashes $hashes -Action install -MigrateLegacy:$MigrateLegacy -WhatIf:$WhatIfPreference
        $clientsResult['codex'] = [ordered]@{
            state    = $(if ($update.status -eq 'written') { 'escrito' } elseif ($update.status -eq 'unchanged') { 'escrito' } else { 'nao_configurado' })
            status   = $update.status
            path     = $codexPath
            written  = [bool]$update.written
            action   = $update.action
            diff     = if ($update.PSObject.Properties['diff']) { $update.diff } else { $null }
            snippet  = if ($update.PSObject.Properties['snippet']) { $update.snippet } else { $null }
            reason   = if ($update.PSObject.Properties['reason']) { $update.reason } else { $null }
        }
        if ($update.status -in @('manual', 'entrada_em_conflito', 'conflict', 'entrada_quebrada', 'edicao_manual_necessaria', 'python_indisponivel')) {
            $code = if ($update.status -eq 'python_indisponivel') { 'python_indisponivel' } elseif ($update.status -eq 'edicao_manual_necessaria') { 'edicao_manual_necessaria' } elseif ($update.status -eq 'entrada_quebrada') { 'entrada_quebrada' } else { 'entrada_em_conflito' }
            $class = if ($update.status -eq 'python_indisponivel') { 'warn' } else { 'blocking' }
            $findings.Add((New-McpFinding -Code $code -Class $class -Message ([string]$update.reason) -Client 'codex')) | Out-Null
        }
        if ($update.status -eq 'written' -and -not [string]::IsNullOrWhiteSpace([string]$update.entryHash) -and -not $WhatIfPreference) {
            $manifest.Value = Add-McpManifestClientHash -Manifest $manifest.Value -Client 'codex' -Path $codexPath -Hash ([string]$update.entryHash)
            $changed = $true
        }
    }
}

if (-not $WhatIfPreference) {
    $manifestWrite = Set-McpManifest -Value $manifest.Value
    if ($manifestWrite.Status -eq 'written') {
        $changed = $true
        $null = Set-McpAcl -Path $manifestWrite.Path
    }
}

$blocking = @($findings | Where-Object { $_.class -eq 'blocking' })
$overall = if ($blocking.Count -eq 0) { 'INTEGRATIONS_OK' } else { 'INTEGRATIONS_GAPS' }
$exitCode = if ($overall -eq 'INTEGRATIONS_OK') { 0 } else { Get-McpExitCodeForFindings -Findings @($findings) }
if ($overall -eq 'INTEGRATIONS_OK') {
    $nextActions.Add('Recarregar/reiniciar o cliente para a entrada jev valer') | Out-Null
}
$launcherResult = if ($null -ne $launcher) {
    [ordered]@{ status = [string]$launcher.Status; path = [string]$launcher.Path; hash = [string]$launcher.Hash }
} else { $null }
$configResult = if ($null -ne $config) {
    [ordered]@{ status = [string]$config.Status; path = [string]$config.Path; hash = [string]$config.Hash; backupPath = [string]$config.BackupPath }
} else { $null }
$result = New-McpMutationResult -ActionName $Action -Overall $overall -ExitCode $exitCode -Changed $changed -Planned $planned -Findings $findings -Clients $clientsResult -Vendor $vendor -Launcher $launcherResult -Config $configResult -Credential $credential -NextActions ($nextActions | Select-Object -Unique)
[pscustomobject]$result | ConvertTo-Json -Depth 30
exit $exitCode
