#requires -Version 7.4

<#
.SYNOPSIS
    Remove a entrada jev dos clientes gerenciados pela skill xpz-mcp-integrations-setup.

.DESCRIPTION
    Remove somente entrada reconhecida pelo install-manifest.json (hash
    byte-identico ao bloco emitido). Preserva cofre DPAPI, auth.json, demais
    MCPs e o restante de cada config de cliente. Launcher, vendor, config.json
    e manifesto so saem com -RemoveSkillData; o cofre so com -RemoveVault.
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

$descriptor = Get-McpDescriptor
$pin = Get-McpVendorPin
$launcherPath = Get-McpLauncherPath -Version $pin.Version
$manifest = Get-McpManifest
if ($manifest.Corrupt) {
    $findings.Add((New-McpFinding -Code 'manifesto_corrompido' -Class 'blocking' -Message $manifest.Error)) | Out-Null
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
            continue
        }
        if ($target.status -eq 'conflict') {
            $findings.Add((New-McpFinding -Code 'entrada_em_conflito' -Class 'blocking' -Message $target.reason -Client 'opencode')) | Out-Null
            $clientsResult['opencode'] = [ordered]@{ status = 'conflict'; state = 'nao_configurado'; reason = $target.reason }
            continue
        }
        $result = Update-McpOpenCodeConfig -Path $target.path -LauncherPath $launcherPath -BaseUrl 'https://api.commandcode.ai/provider/v1/systemone' -Model 'typesafe/jev' -ManifestHashes $hashes -Action remove -WhatIf:$WhatIfPreference
        $clientsResult['opencode'] = [ordered]@{
            status = $result.status
            state  = $(if ($result.status -in @('written', 'unchanged')) { 'nao_configurado' } else { 'nao_configurado' })
            path   = $target.path
            reason = if ($result.PSObject.Properties['reason']) { $result.reason } else { $null }
            diff   = if ($result.PSObject.Properties['diff']) { $result.diff } else { $null }
        }
        if ($result.status -in @('written', 'unchanged')) {
            if (-not $WhatIfPreference) {
                $manifest.Value = Remove-McpManifestClient -Manifest $manifest.Value -Client 'opencode'
                $changed = $true
            }
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
            continue
        }
        $result = Update-McpCodexConfig -Path $codexPath -LauncherPath $launcherPath -BaseUrl 'https://api.commandcode.ai/provider/v1/systemone' -Model 'typesafe/jev' -ManifestHashes $hashes -Action remove -WhatIf:$WhatIfPreference
        $clientsResult['codex'] = [ordered]@{
            status = $result.status
            state  = 'nao_configurado'
            path   = $codexPath
            reason = if ($result.PSObject.Properties['reason']) { $result.reason } else { $null }
            diff   = if ($result.PSObject.Properties['diff']) { $result.diff } else { $null }
        }
        if ($result.status -in @('written', 'unchanged')) {
            if (-not $WhatIfPreference) {
                $manifest.Value = Remove-McpManifestClient -Manifest $manifest.Value -Client 'codex'
                $changed = $true
            }
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

$blocking = @($findings | Where-Object { $_.class -eq 'blocking' })
$manifestRefsRemaining = @($manifest.Value.clients.Keys)
$launcherRemoved = $false
$vendorRemoved = $false
$dataRemoved = $false
# Guarda live: manifesto vazio nao basta — outro cliente pode ainda ter jev
# (ex.: manifesto perdido e so um cliente reancorado).
$liveJevHolders = [System.Collections.Generic.List[string]]::new()
$probeBaseUrl = 'https://api.commandcode.ai/provider/v1/systemone'
$probeModel = 'typesafe/jev'
$ocLiveTarget = Get-McpOpenCodeConfigTarget
if ($ocLiveTarget.status -eq 'conflict') {
    # Sem precedencia json/jsonc: nao da para provar ausencia de jev.
    $liveJevHolders.Add('opencode') | Out-Null
} elseif ($ocLiveTarget.status -eq 'ok') {
    $ocLiveInfo = Get-McpOpenCodeEntryInfo -Path $ocLiveTarget.path -LauncherPath $launcherPath -BaseUrl $probeBaseUrl -Model $probeModel
    if ($ocLiveInfo.status -eq 'ok') {
        if ([string]$ocLiveInfo.form -ne 'absent') {
            $liveJevHolders.Add('opencode') | Out-Null
        }
    } elseif ($ocLiveInfo.status -in @('entrada_em_conflito', 'entrada_quebrada')) {
        # Fail-closed: config ambigua/ilegivel nao autoriza apagar shared.
        $liveJevHolders.Add('opencode') | Out-Null
    }
}
$codexLivePath = Get-McpCodexConfigPath
if (Test-McpRegularFile -Path $codexLivePath) {
    $codexLiveDoc = Read-McpTextDocument -Path $codexLivePath
    $codexLiveBlock = Get-McpCodexBlockInfo -Text $codexLiveDoc.Text
    $codexLiveProbe = Invoke-McpTomlProbe -Text $codexLiveDoc.Text
    # Inclui python_indisponivel: sem tomllib, heuristica textual cobre entrada manual.
    $codexTextLooksLikeJev = [bool]($codexLiveDoc.Text -match 'mcp_servers\.jev|mcp_servers\s*\.\s*jev')
    $codexHolds = ($codexLiveBlock.state -eq 'present') -or
        ($codexLiveProbe.Ok -and [bool]$codexLiveProbe.HasJev) -or
        (-not $codexLiveProbe.Ok -and $codexTextLooksLikeJev)
    if ($codexHolds) {
        $liveJevHolders.Add('codex') | Out-Null
    }
}
if ($RemoveSkillData -and $blocking.Count -eq 0 -and $manifestRefsRemaining.Count -eq 0) {
    if ($liveJevHolders.Count -gt 0) {
        $holdersLabel = ($liveJevHolders -join ', ')
        $findings.Add((New-McpFinding -Code 'dados_compartilhados_em_uso' -Class 'blocking' -Message ("launcher/vendor ainda referenciados por entrada jev live ($holdersLabel); remova esses clientes antes de -RemoveSkillData"))) | Out-Null
        $blocking = @($findings | Where-Object { $_.class -eq 'blocking' })
    } elseif (-not $WhatIfPreference) {
        $managedRoot = Get-McpManagedRoot
        $launcherRecords = @($manifest.Value.launchers)
        if ($launcherRecords.Count -eq 0) {
            $launcherRecords = @([pscustomobject]@{ version = $pin.Version })
        }
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
        $changed = $true
    } else {
        $changed = $true
    }
}

if ($RemoveVault) {
    if (-not $WhatIfPreference) {
        $vaultResult = Remove-McpVault
        if ($vaultResult.Status -eq 'removed') { $changed = $true }
    }
    $changed = $true
}

# Persistir manifesto mesmo com clients vazio (uninstall -Client all sem -RemoveSkillData).
# Se -RemoveSkillData ja apagou o arquivo, nao regrava.
if (-not $WhatIfPreference -and -not $manifest.Corrupt -and $blocking.Count -eq 0 -and $changed) {
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
    vaultRemoved    = [bool]$RemoveVault
    findings       = @($findings)
    nextActions    = @($nextActions | Select-Object -Unique)
}
[pscustomobject]$result | ConvertTo-Json -Depth 30
exit $exitCode
