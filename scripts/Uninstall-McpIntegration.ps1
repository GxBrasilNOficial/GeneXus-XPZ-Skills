#requires -Version 7.4

<#
.SYNOPSIS
    Remove a entrada jev dos clientes gerenciados pela skill xpz-mcp-integrations-setup.

.DESCRIPTION
    Remove somente entrada reconhecida: byte-identica a emissao atual
    (baseUrl/model do config.json efetivo; sem config, o preset) ou hash no
    install-manifest.json. Preserva cofre DPAPI, auth.json, demais MCPs e o
    restante de cada config de cliente. Launcher, vendor, config.json e
    manifesto so saem com -RemoveSkillData; o cofre so com -RemoveVault.
    Em -WhatIf, projeta remocao de clientes no manifesto em memoria, ignora
    holders ja planejados na guarda live e reporta shared sem apagar.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('all', 'opencode', 'codex')]
    [string]$Client = 'all',

    [switch]$RemoveSkillData,

    [switch]$RemoveVault
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    $mcpInternalMessage = [string]$_.Exception.Message
    if (Get-Command Write-McpInternalFailure -ErrorAction SilentlyContinue) {
        Write-McpInternalFailure -Message $mcpInternalMessage -Kind 'mutation' -ActionName 'uninstall'
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

$findings = [System.Collections.Generic.List[object]]::new()
$nextActions = [System.Collections.Generic.List[string]]::new()
$clientsResult = [ordered]@{}
$changed = $false
$planned = [bool]$WhatIfPreference
$vaultRemoved = $false

$descriptor = Get-McpDescriptor
$pin = Get-McpVendorPin
$launcherPath = Get-McpLauncherPath -Version $pin.Version
$manifest = Get-McpManifest
if ($manifest.Corrupt) {
    $findings.Add((New-McpFinding -Code 'manifesto_corrompido' -Class 'blocking' -Message $manifest.Error)) | Out-Null
}

# Emissao atual: config.json efetivo (paridade com install); fallback = preset.
$effectiveBaseUrl = 'https://api.commandcode.ai/provider/v1/systemone'
$effectiveModel = 'typesafe/jev'
try {
    $compatible = $descriptor.Descriptor.modes.compatible
    if ($null -ne $compatible -and -not [string]::IsNullOrWhiteSpace([string]$compatible.preset)) {
        $preset = $descriptor.Descriptor.presets[[string]$compatible.preset]
        if ($null -ne $preset) {
            if (-not [string]::IsNullOrWhiteSpace([string]$preset.baseUrl)) { $effectiveBaseUrl = [string]$preset.baseUrl }
            if (-not [string]::IsNullOrWhiteSpace([string]$preset.model)) { $effectiveModel = [string]$preset.model }
        }
    }
} catch {
    # Mantem fallback literal acima.
}
$configForUninstall = Get-McpConfig
if ($configForUninstall.Exists -and $null -ne $configForUninstall.Value) {
    if (-not [string]::IsNullOrWhiteSpace([string]$configForUninstall.Value.baseUrl)) {
        $effectiveBaseUrl = [string]$configForUninstall.Value.baseUrl
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$configForUninstall.Value.model)) {
        $effectiveModel = [string]$configForUninstall.Value.model
    }
}

$selectedClients = if ($Client -eq 'all') { @('opencode', 'codex') } else { @($Client) }
foreach ($clientName in $selectedClients) {
    $clientRecord = Get-McpManifestClient -Manifest $manifest.Value -Client $clientName
    $hashes = @()
    if ($null -ne $clientRecord -and $null -ne $clientRecord.hashes) { $hashes = @($clientRecord.hashes) }

    if ($clientName -eq 'opencode') {
        $target = Get-McpOpenCodeConfigTarget
        if ($target.status -eq 'absent') {
            $clientsResult['opencode'] = [ordered]@{ status = 'unchanged'; state = 'nao_configurado'; reason = 'config ausente' }
            # Sem configuracao, o Jev nao esta la: o registro do manifesto e orfao e precisa sair,
            # senao bloqueia -RemoveSkillData para sempre (e o plano de -WhatIf nao o mostra).
            if ($null -ne (Get-McpManifestClient -Manifest $manifest.Value -Client 'opencode')) {
                $manifest.Value = Remove-McpManifestClient -Manifest $manifest.Value -Client 'opencode'
                $verbOrphan = if ($WhatIfPreference) { 'seria removido' } else { 'removido' }
                $findings.Add((New-McpFinding -Code 'registro_orfao_removido' -Class 'warn' -Message "registro do opencode no manifesto sem configuracao; $verbOrphan" -Client 'opencode')) | Out-Null
            }
            continue
        }
        if ($target.status -eq 'conflict') {
            $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message $target.reason -Client 'opencode')) | Out-Null
            $clientsResult['opencode'] = [ordered]@{ status = 'conflict'; state = 'nao_configurado'; reason = $target.reason }
            continue
        }
        $result = Update-McpOpenCodeConfig -Path $target.path -LauncherPath $launcherPath -BaseUrl $effectiveBaseUrl -Model $effectiveModel -ManifestHashes $hashes -Action remove -WhatIf:$WhatIfPreference
        $clientsResult['opencode'] = [ordered]@{
            status = $result.status
            state  = $(if ($result.status -in @('written', 'unchanged', 'planned')) { 'nao_configurado' } else { 'nao_configurado' })
            path   = $target.path
            reason = if ($result.PSObject.Properties['reason']) { $result.reason } else { $null }
            diff   = if ($result.PSObject.Properties['diff']) { $result.diff } else { $null }
        }
        if ($result.status -in @('written', 'unchanged', 'planned')) {
            # Projeta manifesto em memoria tambem no -WhatIf (paridade do plano).
            $manifest.Value = Remove-McpManifestClient -Manifest $manifest.Value -Client 'opencode'
            # changed so vale para escrita real do cliente (regra B: 'unchanged' e 'planned' nao marcam).
            if ($result.status -eq 'written') { $changed = $true }
        } elseif ($result.status -in @('manual', 'entrada_em_conflito', 'conflict', 'entrada_quebrada', 'edicao_manual_necessaria')) {
            $code = if ($result.status -eq 'manual') {
                'edicao_manual_necessaria'
            } elseif ($result.status -eq 'entrada_quebrada') {
                'entrada_quebrada'
            } else {
                'entrada_em_conflito'
            }
            $findings.Add((New-McpFinding -Code $code -Class 'blocking' -Message ([string]$result.reason) -Client 'opencode')) | Out-Null
        }
        continue
    }

    if ($clientName -eq 'codex') {
        $codexPath = Get-McpCodexConfigPath
        if (-not (Test-McpRegularFile -Path $codexPath)) {
            $clientsResult['codex'] = [ordered]@{ status = 'unchanged'; state = 'nao_configurado'; reason = 'config ausente' }
            # Mesmo tratamento do opencode: registro sem configuracao e orfao.
            if ($null -ne (Get-McpManifestClient -Manifest $manifest.Value -Client 'codex')) {
                $manifest.Value = Remove-McpManifestClient -Manifest $manifest.Value -Client 'codex'
                $verbOrphan = if ($WhatIfPreference) { 'seria removido' } else { 'removido' }
                $findings.Add((New-McpFinding -Code 'registro_orfao_removido' -Class 'warn' -Message "registro do codex no manifesto sem configuracao; $verbOrphan" -Client 'codex')) | Out-Null
            }
            continue
        }
        $result = Update-McpCodexConfig -Path $codexPath -LauncherPath $launcherPath -BaseUrl $effectiveBaseUrl -Model $effectiveModel -ManifestHashes $hashes -Action remove -WhatIf:$WhatIfPreference
        $clientsResult['codex'] = [ordered]@{
            status = $result.status
            state  = 'nao_configurado'
            path   = $codexPath
            reason = if ($result.PSObject.Properties['reason']) { $result.reason } else { $null }
            diff   = if ($result.PSObject.Properties['diff']) { $result.diff } else { $null }
        }
        if ($result.status -in @('written', 'unchanged', 'planned')) {
            $manifest.Value = Remove-McpManifestClient -Manifest $manifest.Value -Client 'codex'
            # changed so vale para escrita real do cliente (regra B: 'unchanged' e 'planned' nao marcam).
            if ($result.status -eq 'written') { $changed = $true }
        } elseif ($result.status -in @('manual', 'entrada_em_conflito', 'conflict', 'entrada_quebrada', 'edicao_manual_necessaria', 'python_indisponivel')) {
            $code = if ($result.status -eq 'python_indisponivel') {
                'python_indisponivel'
            } elseif ($result.status -in @('edicao_manual_necessaria', 'manual')) {
                'edicao_manual_necessaria'
            } elseif ($result.status -eq 'entrada_quebrada') {
                'entrada_quebrada'
            } else {
                'entrada_em_conflito'
            }
            $class = if ($result.status -eq 'python_indisponivel') { 'warn' } else { 'blocking' }
            $findings.Add((New-McpFinding -Code $code -Class $class -Message ([string]$result.reason) -Client 'codex')) | Out-Null
        }
    }
}

function Test-McpUninstallClientProjectedCleared {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not $clientsResult.Contains($Name)) { return $false }
    $status = [string]$clientsResult[$Name].status
    return ($status -in @('written', 'unchanged', 'planned'))
}

$blocking = @($findings | Where-Object { $_.class -eq 'blocking' })
$manifestRefsRemaining = @($manifest.Value.clients.Keys)
$launcherRemoved = $false
$vendorRemoved = $false
$dataRemoved = $false
# Guarda live: manifesto vazio nao basta — outro cliente pode ainda ter jev.
# Em -WhatIf, ignora clientes que este run ja projetou remover (disco intacto).
$liveJevHolders = [System.Collections.Generic.List[string]]::new()
$ocLiveTarget = Get-McpOpenCodeConfigTarget
if (-not (Test-McpUninstallClientProjectedCleared -Name 'opencode')) {
    if ($ocLiveTarget.status -eq 'conflict') {
        $liveJevHolders.Add('opencode') | Out-Null
    } elseif ($ocLiveTarget.status -eq 'ok') {
        $ocLiveInfo = Get-McpOpenCodeEntryInfo -Path $ocLiveTarget.path -LauncherPath $launcherPath -BaseUrl $effectiveBaseUrl -Model $effectiveModel
        if ($ocLiveInfo.status -eq 'ok') {
            if ([string]$ocLiveInfo.form -ne 'absent') {
                $liveJevHolders.Add('opencode') | Out-Null
            }
        } elseif ($ocLiveInfo.status -in @('entrada_em_conflito', 'entrada_quebrada')) {
            $liveJevHolders.Add('opencode') | Out-Null
        }
    }
}
$codexLivePath = Get-McpCodexConfigPath
if (-not (Test-McpUninstallClientProjectedCleared -Name 'codex') -and (Test-McpRegularFile -Path $codexLivePath)) {
    $codexLiveDoc = Read-McpTextDocument -Path $codexLivePath
    $codexLiveBlock = Get-McpCodexBlockInfo -Text $codexLiveDoc.Text
    $codexLiveProbe = Invoke-McpTomlProbe -Text $codexLiveDoc.Text
    if (Test-McpCodexConfigHoldsJev -Text $codexLiveDoc.Text -Probe $codexLiveProbe -BlockState ([string]$codexLiveBlock.state)) {
        $liveJevHolders.Add('codex') | Out-Null
    }
}
if ($RemoveSkillData -and $blocking.Count -eq 0 -and $manifestRefsRemaining.Count -eq 0) {
    if ($liveJevHolders.Count -gt 0) {
        $holdersLabel = ($liveJevHolders -join ', ')
        $findings.Add((New-McpFinding -Code 'dados_compartilhados_em_uso' -Class 'blocking' -Message ("launcher/vendor ainda referenciados por entrada jev live ($holdersLabel); remova esses clientes antes de -RemoveSkillData"))) | Out-Null
        $blocking = @($findings | Where-Object { $_.class -eq 'blocking' })
    } else {
        $managedRoot = Get-McpManagedRoot
        $launcherRecords = @($manifest.Value.launchers)
        if ($launcherRecords.Count -eq 0) {
            $launcherRecords = @([pscustomobject]@{ version = $pin.Version })
        }
        if ($WhatIfPreference) {
            # Plano: reporta o que seria removido, sem apagar.
            foreach ($record in $launcherRecords) {
                $recordVersion = [string]$record.version
                if ([string]::IsNullOrWhiteSpace($recordVersion)) { continue }
                $candidateLauncher = Get-McpLauncherPath -Version $recordVersion
                if (Test-Path -LiteralPath $candidateLauncher) {
                    $launcherInfo = Test-McpLauncher -Version $recordVersion -Manifest $manifest.Value
                    if ($launcherInfo.state -eq 'ok') { $launcherRemoved = $true }
                }
                $vendorDir = Get-McpVendorDir -Version $recordVersion
                if ((Test-Path -LiteralPath $vendorDir -PathType Container) -and (Test-McpPathUnder -Path $vendorDir -Parent $managedRoot)) {
                    $vendorRemoved = $true
                }
            }
            if (Test-Path -LiteralPath (Get-McpConfigPath)) { $dataRemoved = $true }
            if (Test-Path -LiteralPath (Get-McpManifestPath)) { $dataRemoved = $true }
        } else {
            foreach ($record in $launcherRecords) {
                $recordVersion = [string]$record.version
                if ([string]::IsNullOrWhiteSpace($recordVersion)) { continue }
                $candidateLauncher = Get-McpLauncherPath -Version $recordVersion
                if (-not (Test-Path -LiteralPath $candidateLauncher)) { continue }
                $launcherInfo = Test-McpLauncher -Version $recordVersion -Manifest $manifest.Value
                if ($launcherInfo.state -eq 'ok') {
                    Remove-Item -LiteralPath $candidateLauncher -Force
                    $launcherRemoved = $true
                }
            }
            $remainingLaunchers = @(Get-ChildItem -LiteralPath $managedRoot -File -Filter 'launcher-*.ps1' -ErrorAction SilentlyContinue)
            if ($remainingLaunchers.Count -gt 0) {
                $findings.Add((New-McpFinding -Code 'launcher_orfao' -Class 'warn' -Message 'launcher nao reconhecido permaneceu; confira antes de remover a mao')) | Out-Null
            } else {
                foreach ($record in $launcherRecords) {
                    $recordVersion = [string]$record.version
                    if ([string]::IsNullOrWhiteSpace($recordVersion)) { continue }
                    $vendorDir = Get-McpVendorDir -Version $recordVersion
                    if ((Test-Path -LiteralPath $vendorDir -PathType Container) -and (Test-McpPathUnder -Path $vendorDir -Parent $managedRoot)) {
                        Remove-Item -LiteralPath $vendorDir -Recurse -Force
                        $vendorRemoved = $true
                    }
                }
            }
            $configPath = Get-McpConfigPath
            if (Test-Path -LiteralPath $configPath) {
                Remove-Item -LiteralPath $configPath -Force
                $dataRemoved = $true
            }
            $manifestPath = Get-McpManifestPath
            if (Test-Path -LiteralPath $manifestPath) {
                Remove-Item -LiteralPath $manifestPath -Force
                $dataRemoved = $true
            }
            # changed so vale se algum dado foi de fato removido (regra B).
            if ($launcherRemoved -or $vendorRemoved -or $dataRemoved) { $changed = $true }
        }
    }
}

if ($RemoveVault) {
    # Status real do cofre: 'removed' (apagado), 'planned' (-WhatIf com cofre presente)
    # ou 'absent' (nada a fazer, sem mudanca nem remocao).
    $vaultResult = Remove-McpVault -WhatIf:$WhatIfPreference
    if ($vaultResult.Status -in @('removed', 'planned')) {
        $vaultRemoved = $true
    }
    # changed so vale para remocao real (regra B): -WhatIf ('planned') nao marca.
    if ($vaultResult.Status -eq 'removed') { $changed = $true }
}

# Persistir manifesto mesmo com clients vazio (uninstall -Client all sem -RemoveSkillData).
# Se -RemoveSkillData ja apagou o arquivo, nao regrava.
if (-not $WhatIfPreference -and -not $manifest.Corrupt -and $blocking.Count -eq 0) {
    if (Test-McpRegularFile -Path (Get-McpManifestPath)) {
        $manifestWrite = Set-McpManifest -Value $manifest.Value
        if ($manifestWrite.Status -eq 'written') { $changed = $true }
    }
}

$allRequestedHandled = $true
foreach ($requested in $selectedClients) {
    $clientState = $clientsResult[$requested]
    if ($null -eq $clientState) {
        $allRequestedHandled = $false
        break
    }
    # -WhatIf: planned conta como tratado (paridade com Install-McpIntegration).
    $status = [string]$clientState.status
    $handled = ($status -in @('written', 'unchanged')) -or
        ($WhatIfPreference -and $status -eq 'planned')
    if (-not $handled) {
        $allRequestedHandled = $false
        break
    }
}
$overall = if ($blocking.Count -eq 0 -and $allRequestedHandled) { 'INTEGRATIONS_OK' } else { 'INTEGRATIONS_GAPS' }
$exitCode = Resolve-McpGapsExitCode -Overall $overall -Findings @($findings)
if ($overall -eq 'INTEGRATIONS_OK') {
    $nextActions.Add('Recarregar/reiniciar o cliente para a remocao valer') | Out-Null
}
$result = [ordered]@{
    schemaVersion  = 1
    kind           = 'xpz-mcp-integrations-setup-mutation'
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    action         = 'remove'
    overall        = $overall
    exitCode       = $exitCode
    changed        = $changed
    planned        = $planned
    clients        = $clientsResult
    launcherRemoved = $launcherRemoved
    vendorRemoved   = $vendorRemoved
    dataRemoved     = $dataRemoved
    vaultRemoved    = [bool]$vaultRemoved
    findings       = @($findings)
    nextActions    = @($nextActions | Select-Object -Unique)
}
[pscustomobject]$result | ConvertTo-Json -Depth 30
exit $exitCode
