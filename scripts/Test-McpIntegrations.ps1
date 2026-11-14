#requires -Version 7.4

<#
.SYNOPSIS
    Auditoria da skill xpz-mcp-integrations-setup, sem escrita na configuracao dos clientes.

.DESCRIPTION
    Emite JSON de maquina no stdout. Nao grava, nao remove e nao altera config
    de cliente (ressalva: a sonda TOML do Codex grava copia temporaria do config.toml em %TEMP%, removida no finally). overall=INTEGRATIONS_OK e estrutural: entrada reconhecida em
    cada cliente gerenciado e nenhum achado blocking (warns como
    acl_nao_aplicavel nao derrubam sozinhos). Credencial verificada e um eixo
    separado, promovido apenas por -CheckCredential (online opt-in).

    -CheckBoot e -CheckCredential sao opt-in. -CheckCredential exige
    autorizacao explicita por execucao.
#>

[CmdletBinding()]
param(
    [Alias('Path')]
    [string]$InputPath,

    [switch]$CheckBoot,

    [switch]$CheckCredential
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    $mcpInternalMessage = [string]$_.Exception.Message
    if (Get-Command Write-McpInternalFailure -ErrorAction SilentlyContinue) {
        Write-McpInternalFailure -Message $mcpInternalMessage -Kind 'audit'
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

$originalProfile = $env:USERPROFILE
$originalLocalAppData = $env:LOCALAPPDATA
$auditInput = $null
if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
    $auditInput = Get-McpJsonFile -Path ([System.IO.Path]::GetFullPath($InputPath))
    if ($null -eq $auditInput) {
        throw "XPZ_MCP_AUDIT_INPUT_MISSING: $InputPath"
    }
    if ($auditInput.Contains('userProfile') -and -not [string]::IsNullOrWhiteSpace([string]$auditInput['userProfile'])) {
        $env:USERPROFILE = [string]$auditInput['userProfile']
    }
    if ($auditInput.Contains('localAppData') -and -not [string]::IsNullOrWhiteSpace([string]$auditInput['localAppData'])) {
        $env:LOCALAPPDATA = [string]$auditInput['localAppData']
    }
}

function New-McpBootResult {
    param([Parameter(Mandatory = $true)][string]$LauncherPath)
    $pwsh = Get-McpCommandInfo -Name 'pwsh' -VersionArguments @('-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()')
    if (-not $pwsh.Present) {
        return [pscustomobject]@{ state = 'boot_falhou'; exitCode = $null; responseFound = $false; stderr = 'pwsh ausente' }
    }
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $pwsh.Path
    $psi.Arguments = '-NoProfile -File "' + $LauncherPath + '"'
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $process = $null
    try {
        $process = [System.Diagnostics.Process]::Start($psi)
        $outTask = $process.StandardOutput.ReadToEndAsync()
        $errTask = $process.StandardError.ReadToEndAsync()
        $init = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"xpz-mcp-integrations-setup","version":"1.0"}}}'
        $initialized = '{"jsonrpc":"2.0","method":"notifications/initialized"}'
        $process.StandardInput.WriteLine($init)
        $process.StandardInput.WriteLine($initialized)
        $process.StandardInput.Close()
        $exited = $process.WaitForExit(20000)
        if (-not $exited) {
            try { $process.Kill($true) } catch { }
            return [pscustomobject]@{ state = 'boot_timeout'; exitCode = $null; responseFound = $false; stderr = '' }
        }
        $process.WaitForExit()
        $stdout = $outTask.GetAwaiter().GetResult()
        $stderr = $errTask.GetAwaiter().GetResult()
        $responseFound = $false
        foreach ($line in @($stdout -split "`n")) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            try {
                $message = $trimmed | ConvertFrom-Json -AsHashtable
            } catch {
                continue
            }
            if ($message.Contains('id') -and [string]$message['id'] -eq '1' -and $message.Contains('result')) {
                $responseFound = $true
                break
            }
        }
        return [pscustomobject]@{
            state         = $(if ($process.ExitCode -eq 0 -and $responseFound) { 'boot_ok' } else { 'boot_falhou' })
            exitCode      = $process.ExitCode
            responseFound = $responseFound
            stderr        = (($stderr -split "`n") | Select-Object -First 5) -join "`n"
        }
    } catch {
        return [pscustomobject]@{ state = 'boot_falhou'; exitCode = $null; responseFound = $false; stderr = $_.Exception.Message }
    } finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function New-McpCredentialProbe {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][string]$Secret
    )
    $question = [ordered]@{
        type         = 'noul'
        instructions = 'This is a health probe; the statement is true.'
    }
    $body = [ordered]@{
        model     = $Model
        state     = 'xpz-mcp-integrations-setup credential probe'
        questions = [ordered]@{
            xpz_mcp_probe = $question
        }
    } | ConvertTo-Json -Depth 10 -Compress
    try {
        $response = Invoke-WebRequest -Uri $BaseUrl -Method Post -Headers @{ Authorization = "Bearer $Secret" } `
            -ContentType 'application/json' -Body $body -SkipHttpErrorCheck -TimeoutSec 20
    } catch {
        return [pscustomobject]@{ endpointReachable = $false; credentialVerified = $false; status = $null; reason = 'request_failed' }
    }
    $endpointReachable = $true
    $credentialVerified = $false
    if ([int]$response.StatusCode -eq 200) {
        try {
            $parsed = $response.Content | ConvertFrom-Json -AsHashtable
            $answers = $parsed['answers']
            if ($answers -is [System.Collections.IDictionary] -and $answers.Contains('xpz_mcp_probe')) {
                $answer = $answers['xpz_mcp_probe']
                if ($answer -is [System.Collections.IDictionary] -and $answer.Contains('noul')) {
                    $noul = $answer['noul']
                    if ($noul -is [int] -or $noul -is [long] -or $noul -is [double] -or $noul -is [decimal]) {
                        $value = [double]$noul
                        if ($value -ge 0 -and $value -le 1) {
                            $credentialVerified = $true
                        }
                    }
                }
            }
        } catch {
            $credentialVerified = $false
        }
    }
    return [pscustomobject]@{
        endpointReachable    = $endpointReachable
        credentialVerified   = $credentialVerified
        status               = [int]$response.StatusCode
        reason               = $(if ($credentialVerified) { 'answers_ok' } elseif ($endpointReachable) { 'endpoint_only' } else { 'request_failed' })
    }
}


$findings = [System.Collections.Generic.List[object]]::new()
$nextActions = [System.Collections.Generic.List[object]]::new()
function Add-McpNextAction {
    param([int]$Code, [string]$Text)
    $nextActions.Add([pscustomobject]@{ Code = $Code; Text = $Text }) | Out-Null
}
$descriptor = $null
$component = $null
$compatible = $null
$preset = [pscustomobject]@{ baseUrl = 'https://invalid.local/'; model = 'unknown' }
try {
    $descriptor = Get-McpDescriptor
    $component = $descriptor.Descriptor.component
    $compatible = $descriptor.Descriptor.modes.compatible
    $preset = $descriptor.Descriptor.presets[$compatible.preset]
} catch {
    $findings.Add((New-McpFinding -Code 'descriptor_invalido' -Class 'blocking' -Message $_.Exception.Message)) | Out-Null
}

$prerequisites = Get-McpPrerequisites
foreach ($finding in @(Get-McpPrerequisiteFindings -Prerequisites $prerequisites)) {
    $findings.Add($finding) | Out-Null
}
if (-not $prerequisites.NodeCompatible -and $prerequisites.Winget.Present) {
    Add-McpNextAction -Code 63 -Text 'winget install --id OpenJS.NodeJS.LTS -e (instalar Node >= 22 com aprovacao)'
}
if ($prerequisites.VersionManagers.Count -gt 0) {
    $findings.Add((New-McpFinding -Code 'version_manager_presente' -Class 'warn' -Message ('gerenciador de versao detectado: ' + ($prerequisites.VersionManagers -join ', ')))) | Out-Null
}

$managedRoot = Get-McpManagedRoot
$manifest = Get-McpManifest
if ($manifest.Corrupt) {
    $findings.Add((New-McpFinding -Code 'manifesto_corrompido' -Class 'warn' -Message $manifest.Error)) | Out-Null
}
$config = Get-McpConfig
$endpointMatchesPreset = $false
$baseUrlHost = $null
$baseUrlRedacted = $null
if ($null -ne $config.Value) {
    $baseUrlHost = ([Uri]::new([string]$config.Value.baseUrl)).Host
    $baseUrlRedacted = Format-McpRedactedUrl -Url ([string]$config.Value.baseUrl)
    $endpointMatchesPreset = ($baseUrlHost -eq ([Uri]::new([string]$preset.baseUrl)).Host)
}
if (-not $config.Exists) {
    $findings.Add((New-McpFinding -Code 'config_ausente' -Class 'blocking' -Message 'config.json nao existe; execute a instalacao')) | Out-Null
    Add-McpNextAction -Code 62 -Text 'Install-McpIntegration.ps1 -Action install'
} elseif ($null -eq $config.Value) {
    $findings.Add((New-McpFinding -Code 'config_invalido' -Class 'blocking' -Message $config.Error)) | Out-Null
    Add-McpNextAction -Code 62 -Text 'Install-McpIntegration.ps1 -Action repair'
} elseif (-not $endpointMatchesPreset -and $config.Value.endpointConfirmed -ne $true) {
    $findings.Add((New-McpFinding -Code 'endpoint_nao_confirmado' -Class 'blocking' -Message "host $baseUrlHost difere do preset Command Code; confirme o endpoint")) | Out-Null
    Add-McpNextAction -Code 62 -Text 'Install-McpIntegration.ps1 -Action repair -ConfirmEndpoint'
}

$vendor = $null
$launcher = $null
if ($null -ne $descriptor) {
    $pin = Get-McpVendorPin
    $vendor = Test-McpVendor -Pin $pin
    if ($vendor.state -ne 'ok') {
        $class = 'blocking'
        $findings.Add((New-McpFinding -Code $vendor.state -Class $class -Message "vendor: $($vendor.state)")) | Out-Null
        Add-McpNextAction -Code 64 -Text 'Invoke-McpVendor.ps1'
    }
    $launcherResult = Test-McpLauncher -Version $pin.Version -Manifest $manifest.Value
    $launcher = $launcherResult
    if ($launcherResult.state -ne 'ok') {
        $findings.Add((New-McpFinding -Code $launcherResult.state -Class 'blocking' -Message "launcher: $($launcherResult.state)")) | Out-Null
        Add-McpNextAction -Code 65 -Text 'Install-McpIntegration.ps1 -Action repair'
    }
}

$credentialExists = Test-McpVaultExists
if (-not $credentialExists) {
    $findings.Add((New-McpFinding -Code 'credencial_ausente' -Class 'blocking' -Message 'cofre DPAPI ausente')) | Out-Null
    Add-McpNextAction -Code 61 -Text 'Set-McpCredential.ps1 -Action set'
}

# ACL so-dono: warn na auditoria (A.9); blocking permanece nos mutadores de blob.
foreach ($aclFinding in @(Get-McpAclAuditFindings)) {
    $findings.Add($aclFinding) | Out-Null
}
if (@($findings | Where-Object { $_.code -eq 'acl_nao_aplicavel' -and $_.class -eq 'warn' }).Count -gt 0) {
    Add-McpNextAction -Code 67 -Text 'Install-McpIntegration.ps1 -Action repair (reaplica ACL na raiz/manifesto/config)'
    Add-McpNextAction -Code 67 -Text 'Set-McpCredential.ps1 -Action set (reaplica ACL do cofre ao regravar)'
}

$clients = [ordered]@{}
$clientOrder = @('opencode', 'codex')
foreach ($client in $clientOrder) {
    $installed = Test-McpClientInstalled -Client $client
    if (-not $installed) {
        $clients[$client] = [ordered]@{
            installed = $false
            state     = 'nao_configurado'
            findings  = @()
        }
        continue
    }
    $clientFindings = @()
    $state = 'nao_configurado'
    $clientPath = $null
    $clientForm = $null
    $clientMigration = $null
    if ($null -ne $descriptor -and $null -ne $manifest) {
        $pin = Get-McpVendorPin
        $launcherPath = Get-McpLauncherPath -Version $pin.Version
        $baseUrl = if ($null -ne $config.Value) { [string]$config.Value.baseUrl } else { [string]$preset.baseUrl }
        $model = if ($null -ne $config.Value) { [string]$config.Value.model } else { [string]$preset.model }
        $clientHashes = @()
        $clientRecord = Get-McpManifestClient -Manifest $manifest.Value -Client $client
        if ($null -ne $clientRecord -and $null -ne $clientRecord.hashes) {
            $clientHashes = @($clientRecord.hashes)
        }
        if ($client -eq 'opencode') {
            $result = Get-McpOpenCodeState -LauncherPath $launcherPath -BaseUrl $baseUrl -Model $model -ManifestHashes $clientHashes
        } else {
            $result = Get-McpCodexState -LauncherPath $launcherPath -BaseUrl $baseUrl -Model $model -ManifestHashes $clientHashes
        }
        $state = $result.state
        $clientPath = $result.path
        $clientFindings = @($result.findings)
        if ($result.PSObject.Properties['form']) { $clientForm = [string]$result.form }
        if ($result.PSObject.Properties['migration']) { $clientMigration = [string]$result.migration }
        foreach ($finding in $clientFindings) {
            $findings.Add($finding) | Out-Null
        }
    }
    $clients[$client] = [ordered]@{
        installed = $true
        state     = $state
        path      = $clientPath
        form      = $clientForm
        migration = $clientMigration
        findings  = $clientFindings
    }
}
foreach ($clientName in $clientOrder) {
    if (@($clients[$clientName].findings | Where-Object { $_.code -eq 'edicao_manual_necessaria' }).Count -gt 0) {
        Add-McpNextAction -Code 67 -Text ("Install-McpIntegration.ps1 -Client $clientName -MigrateLegacy")
    }
}
if ($clients['opencode'].installed -and $clients['opencode'].state -eq 'nao_configurado') {
    Add-McpNextAction -Code 60 -Text 'Install-McpIntegration.ps1 -Client opencode'
}
if ($clients['codex'].installed -and $clients['codex'].state -eq 'nao_configurado') {
    Add-McpNextAction -Code 60 -Text 'Install-McpIntegration.ps1 -Client codex'
}

$boot = $null
if ($CheckBoot -and $null -ne $launcher -and $launcher.state -eq 'ok' -and $vendor -and $vendor.state -eq 'ok' -and $credentialExists -and $null -ne $config.Value) {
    $boot = New-McpBootResult -LauncherPath $launcher.path
    foreach ($client in $clientOrder) {
        if (-not $clients[$client].installed -or $boot.state -ne 'boot_ok') { continue }
        # So promove quem ja tem entrada reconhecida (>= escrito); nao_configurado nao vira boot_ok.
        if (-not (Test-McpStateAtLeast -State $clients[$client].state -Minimum 'escrito')) { continue }
        if ((Get-McpStateRank -State $clients[$client].state) -lt (Get-McpStateRank -State 'boot_ok')) {
            $clients[$client].state = 'boot_ok'
        }
    }
    if ($boot.state -ne 'boot_ok') {
        $findings.Add((New-McpFinding -Code 'boot_falhou' -Class 'warn' -Message "boot: $($boot.state)")) | Out-Null
    }
}

$credentialProbe = $null
$endpointAuthorized = ($null -ne $config.Value -and ($config.Value.endpointConfirmed -eq $true -or $endpointMatchesPreset))
if ($CheckCredential -and -not $endpointAuthorized) {
    $findings.Add((New-McpFinding -Code 'endpoint_nao_confirmado' -Class 'blocking' -Message 'probe de credencial recusado: endpoint nao confirmado')) | Out-Null
}
if ($CheckCredential -and $credentialExists -and $endpointAuthorized) {
    try {
        $secret = Read-McpVault
        $credentialProbe = New-McpCredentialProbe -BaseUrl ([string]$config.Value.baseUrl) -Model ([string]$config.Value.model) -Secret $secret
    } catch {
        $credentialProbe = [pscustomobject]@{ endpointReachable = $false; credentialVerified = $false; status = $null; reason = 'vault_read_failed' }
    } finally {
        $secret = $null
    }
    if ($credentialProbe.endpointReachable) {
        foreach ($client in $clientOrder) {
            if ($clients[$client].installed -and (Test-McpStateAtLeast -State $clients[$client].state -Minimum 'escrito')) {
                $clients[$client].state = 'endpoint_alcancavel'
            }
        }
    }
    if ($credentialProbe.credentialVerified) {
        foreach ($client in $clientOrder) {
            if ($clients[$client].installed -and (Test-McpStateAtLeast -State $clients[$client].state -Minimum 'escrito')) {
                $clients[$client].state = 'credencial_verificada'
            }
        }
    } elseif ($credentialProbe.endpointReachable) {
        $findings.Add((New-McpFinding -Code 'credencial_nao_verificada' -Class 'warn' -Message 'endpoint respondeu, mas a credencial nao foi promovida')) | Out-Null
    }
}

# E2E confirmado manualmente e registrado no manifesto.
foreach ($client in $clientOrder) {
    if (-not $clients[$client].installed) { continue }
    $e2eTable = $manifest.Value.e2e
    if ($null -eq $e2eTable) { continue }
    $hasE2e = if ($e2eTable -is [System.Collections.IDictionary]) { $e2eTable.Contains($client) } else { $null -ne $e2eTable.PSObject.Properties[$client] }
    if (-not $hasE2e) { continue }
    $stamp = if ($e2eTable -is [System.Collections.IDictionary]) { [string]$e2eTable[$client] } else { [string]$e2eTable.PSObject.Properties[$client].Value }
    if (-not [string]::IsNullOrWhiteSpace($stamp) -and (Test-McpStateAtLeast -State $clients[$client].state -Minimum 'credencial_verificada')) {
        $clients[$client].state = 'e2e_opt_in_confirmado'
    }
}

$blocking = @($findings | Where-Object { $_.class -eq 'blocking' })
$managedClientStates = @()
foreach ($client in $clientOrder) {
    if ($clients[$client].installed) {
        $managedClientStates += [string]$clients[$client].state
    }
}
$allClientsWritten = $true
foreach ($state in $managedClientStates) {
    if (-not (Test-McpStateAtLeast -State $state -Minimum 'escrito')) {
        $allClientsWritten = $false
    }
}
$overall = 'INTEGRATIONS_GAPS'
if ($blocking.Count -eq 0 -and $allClientsWritten) {
    $overall = 'INTEGRATIONS_OK'
}
$exitCode = Resolve-McpGapsExitCode -Overall $overall -Findings @($findings)
$orderedNextActions = @($nextActions |
    Sort-Object -Property @{ Expression = { Get-McpExitCodeRank -Code $_.Code } }, @{ Expression = { $_.Text } } |
    Select-Object -ExpandProperty Text -Unique)

$result = [ordered]@{
    schemaVersion  = 1
    kind           = 'xpz-mcp-integrations-setup-audit'
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
    overall        = $overall
    exitCode       = $exitCode
    descriptor     = if ($null -ne $descriptor) {
        [ordered]@{ path = $descriptor.Path; hash = $descriptor.Hash; version = [string]$component.version }
    } else { $null }
    managedRoot    = $managedRoot
    prerequisites  = [ordered]@{
        pwsh             = $prerequisites.Pwsh.Present
        node             = $prerequisites.Node.Present
        nodeVersion      = $(if ($null -ne $prerequisites.NodeVersion) { $prerequisites.NodeVersion.ToString() } else { $null })
        nodeCompatible   = $prerequisites.NodeCompatible
        npm              = $prerequisites.Npm.Present
        python           = $prerequisites.Python.Present
        pythonVersion    = $(if ($null -ne $prerequisites.PythonVersion) { $prerequisites.PythonVersion.ToString() } else { $null })
        pythonCompatible = $prerequisites.PythonCompatible
        versionManagers  = @($prerequisites.VersionManagers)
    }
    config         = [ordered]@{
        exists            = $config.Exists
        valid             = ($null -ne $config.Value)
        provider          = $(if ($null -ne $config.Value) { [string]$config.Value.provider } else { $null })
        baseUrlHost       = $baseUrlHost
        baseUrlRedacted   = $baseUrlRedacted
        endpointConfirmed = $(if ($null -ne $config.Value) { [bool]$config.Value.endpointConfirmed } else { $null })
        endpointMatchesPreset = $endpointMatchesPreset
    }
    vendor         = if ($null -ne $vendor) { [ordered]@{ state = $vendor.state; version = $vendor.version; path = $vendor.vendorDir } } else { $null }
    launcher       = if ($null -ne $launcher) { [ordered]@{ state = $launcher.state; path = $launcher.path } } else { $null }
    manifest       = [ordered]@{ exists = $manifest.Exists; corrupt = $manifest.Corrupt; path = $manifest.Path }
    credential     = [ordered]@{ exists = $credentialExists; source = 'vault-dpapi' }
    boot           = if ($null -ne $boot) { [ordered]@{ state = $boot.state; exitCode = $boot.exitCode; responseFound = $boot.responseFound } } else { $null }
    credentialProbe = if ($null -ne $credentialProbe) {
        [ordered]@{ endpointReachable = $credentialProbe.endpointReachable; credentialVerified = $credentialProbe.credentialVerified; status = $credentialProbe.status; reason = $credentialProbe.reason }
    } else { $null }
    clients         = $clients
    findings        = @($findings)
    nextActions     = @($orderedNextActions)
    nextActionsMode = 'possible-actions'
    nextActionsNote = 'Lista de acoes possiveis ordenada pela precedencia do exit code; nao e uma sequencia de execucao. A migracao manual exige cofre (Set-McpCredential) antes do install.'
}

$env:USERPROFILE = $originalProfile
$env:LOCALAPPDATA = $originalLocalAppData

[pscustomobject]$result | ConvertTo-Json -Depth 30
exit $exitCode
