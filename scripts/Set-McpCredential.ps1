#requires -Version 7.4

<#
.SYNOPSIS
    Gerencia a credencial do componente Jev/System One no cofre DPAPI.

.DESCRIPTION
    A v1 usa a chave SO do cofre DPAPI CurrentUser; o launcher nao aceita
    chave por variavel de ambiente. A importacao e bootstrap unico a partir de
    `opencode auth export` (preferido) ou `auth.json` (reserva), nunca fonte em
    runtime; nenhum dos dois e alterado.

    Nunca imprime, loga ou grava a chave em claro.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('set', 'import', 'remove', 'test')]
    [string]$Action = 'set',

    [switch]$ImportFromOpenCode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    $mcpInternalMessage = [string]$_.Exception.Message
    if (Get-Command Write-McpInternalFailure -ErrorAction SilentlyContinue) {
        Write-McpInternalFailure -Message $mcpInternalMessage -Kind 'credential' -ActionName $Action
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

function New-McpCredentialResult {
    param(
        [string]$ActionName,
        [string]$Status,
        [int]$ExitCode,
        [bool]$Written,
        [bool]$Planned,
        $Findings,
        [bool]$Exists,
        [string]$Source,
        $NextActions
    )
    return [ordered]@{
        schemaVersion  = 1
        kind           = 'xpz-mcp-integrations-setup-credential'
        generatedAtUtc = [DateTime]::UtcNow.ToString('o')
        action         = $ActionName
        status         = $Status
        exitCode       = $ExitCode
        written        = $Written
        planned        = $Planned
        credential     = [ordered]@{ exists = $Exists; source = $Source }
        findings       = @($Findings)
        nextActions    = @($NextActions)
    }
}

$findings = [System.Collections.Generic.List[object]]::new()
$nextActions = [System.Collections.Generic.List[string]]::new()
$planned = [bool]$WhatIfPreference

if ($Action -eq 'remove') {
    if ($WhatIfPreference) {
        $result = New-McpCredentialResult -ActionName $Action -Status 'planned' -ExitCode 0 -Written $false -Planned $true -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
        [pscustomobject]$result | ConvertTo-Json -Depth 10
        exit 0
    }
    $remove = Remove-McpVault
    $result = New-McpCredentialResult -ActionName $Action -Status $remove.Status -ExitCode 0 -Written ($remove.Status -eq 'removed') -Planned $false -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 10
    exit 0
}

if ($Action -eq 'test') {
    if (-not (Test-McpVaultExists)) {
        $findings.Add((New-McpFinding -Code 'credencial_ausente' -Class 'blocking' -Message 'cofre DPAPI ausente')) | Out-Null
        $result = New-McpCredentialResult -ActionName $Action -Status 'credencial_ausente' -ExitCode 61 -Written $false -Planned $false -Findings $findings -Exists $false -Source 'vault-dpapi' -NextActions $nextActions
        [pscustomobject]$result | ConvertTo-Json -Depth 10
        exit 61
    }
    try {
        $secret = Read-McpVault
        $ok = -not [string]::IsNullOrWhiteSpace($secret)
        $secret = $null
        if ($ok) {
            $result = New-McpCredentialResult -ActionName $Action -Status 'credencial_ok' -ExitCode 0 -Written $false -Planned $false -Findings $findings -Exists $true -Source 'vault-dpapi' -NextActions $nextActions
            [pscustomobject]$result | ConvertTo-Json -Depth 10
            exit 0
        }
        $findings.Add((New-McpFinding -Code 'credencial_ilegivel' -Class 'blocking' -Message 'cofre descriptografou vazio')) | Out-Null
    } catch {
        $findings.Add((New-McpFinding -Code 'credencial_ilegivel' -Class 'blocking' -Message 'cofre DPAPI ilegivel para este usuario')) | Out-Null
    }
    $result = New-McpCredentialResult -ActionName $Action -Status 'credencial_ilegivel' -ExitCode 61 -Written $false -Planned $false -Findings $findings -Exists $true -Source 'vault-dpapi' -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 10
    exit 61
}

$secureSecret = $null
$source = 'secure-input'
if ($planned -and $Action -eq 'set') {
    $result = New-McpCredentialResult -ActionName $Action -Status 'planned' -ExitCode 0 -Written $false -Planned $true -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 10
    exit 0
}
if ($Action -eq 'import') {
    if (-not $ImportFromOpenCode) {
        $findings.Add((New-McpFinding -Code 'acao_invalida' -Class 'blocking' -Message 'Action import exige -ImportFromOpenCode')) | Out-Null
        $result = New-McpCredentialResult -ActionName $Action -Status 'invalid' -ExitCode 67 -Written $false -Planned $planned -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
        [pscustomobject]$result | ConvertTo-Json -Depth 10
        exit 67
    }
    $import = Get-McpOpenCodeCredential
    if ($import.Status -eq 'ambiguous') {
        $findings.Add((New-McpFinding -Code 'credencial_ambigua' -Class 'blocking' -Message 'mais de uma credencial ativa para commandcode; nada foi gravado')) | Out-Null
        $result = New-McpCredentialResult -ActionName $Action -Status 'credencial_ambigua' -ExitCode 67 -Written $false -Planned $planned -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
        [pscustomobject]$result | ConvertTo-Json -Depth 10
        exit 67
    }
    if ($import.Status -ne 'ok' -or [string]::IsNullOrWhiteSpace([string]$import.Secret)) {
        $code = if ($import.Status -eq 'invalid') { 'credencial_invalida' } else { 'credencial_ausente' }
        $findings.Add((New-McpFinding -Code $code -Class 'blocking' -Message "importacao nao encontrou credencial commandcode utilizavel ($($import.Status))")) | Out-Null
        $nextActions.Add('Set-McpCredential.ps1 -Action set') | Out-Null
        $result = New-McpCredentialResult -ActionName $Action -Status $code -ExitCode 61 -Written $false -Planned $planned -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
        [pscustomobject]$result | ConvertTo-Json -Depth 10
        exit 61
    }
    $source = [string]$import.Source
    $secureSecret = [System.Security.SecureString]::new()
    foreach ($character in ([string]$import.Secret).ToCharArray()) {
        $secureSecret.AppendChar($character)
    }
    $secureSecret.MakeReadOnly()
    $import = $null
} else {
    $secureSecret = Read-Host -AsSecureString 'Informe a chave JEV_API_KEY (nao ecoada)'
}

if ($planned) {
    $result = New-McpCredentialResult -ActionName $Action -Status 'planned' -ExitCode 0 -Written $false -Planned $true -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 10
    exit 0
}

try {
    $write = Write-McpVault -SecureSecret $secureSecret
} catch {
    $aclFailure = $_.Exception.Message -match 'ACL_NAO_APLICAVEL'
    $code = if ($aclFailure) { 'acl_nao_aplicavel' } else { 'credencial_ilegivel' }
    $exit = if ($aclFailure) { 67 } else { 61 }
    $findings.Add((New-McpFinding -Code $code -Class 'blocking' -Message $_.Exception.Message)) | Out-Null
    $result = New-McpCredentialResult -ActionName $Action -Status 'failed' -ExitCode $exit -Written $false -Planned $false -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
    [pscustomobject]$result | ConvertTo-Json -Depth 10
    exit $exit
} finally {
    $secureSecret = $null
}

$result = New-McpCredentialResult -ActionName $Action -Status $write.Status -ExitCode 0 -Written ($write.Status -eq 'written') -Planned $false -Findings $findings -Exists (Test-McpVaultExists) -Source 'vault-dpapi' -NextActions $nextActions
$result['credentialSource'] = $source
[pscustomobject]$result | ConvertTo-Json -Depth 10
exit 0
