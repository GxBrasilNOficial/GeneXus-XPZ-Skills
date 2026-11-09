#requires -Version 7.4

<#
.SYNOPSIS
    Cofre DPAPI da skill xpz-mcp-integrations-setup.

.DESCRIPTION
    Blob DPAPI CurrentUser, sem entropia adicional, com metadado de modo e
    variavel secreta separado do valor cifrado. A chave nunca e impressa,
    logada ou gravada no config do cliente.

    Na v1 a chave vem SO do cofre. Importacao unica de `opencode auth export`
    (preferido) ou `auth.json` (reserva) e bootstrap; nenhum dos dois e lido em
    runtime pelo launcher.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:McpVaultSupportDir = Split-Path -Parent $PSCommandPath
. (Join-Path $script:McpVaultSupportDir 'McpIntegrationSupport.ps1')

function Get-McpVaultDir {
    return (Join-Path (Get-McpManagedRoot) 'vault')
}

function Get-McpVaultBlobPath {
    return (Join-Path (Get-McpVaultDir) 'credential.blob')
}

function Test-McpAcl {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        if (-not $acl.AreAccessRulesProtected) {
            return $false
        }
        $rules = @($acl.Access)
        if ($rules.Count -ne 1) {
            return $false
        }
        return ([string]$rules[0].AccessControlType -eq 'Allow')
    } catch {
        return $false
    }
}

function Set-McpAcl {
    <#
    .SYNOPSIS
        ACL so-dono para diretorio ou arquivo gerenciado.

    .DESCRIPTION
        Remove heranca e deixa uma unica regra Allow FullControl para o SID do
        usuario atual. Nao cria regra Deny para Users/Everyone: sem heranca e
        sem Allow, o acesso fica negado por ausencia de concessao.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$Directory
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "XPZ_MCP_ACL_TARGET_MISSING: $Path"
    }
    if ($WhatIfPreference) {
        return [pscustomobject]@{
            Path      = $Path
            Protected = $false
            RuleCount = 0
            Status    = 'planned'
        }
    }
    if (Test-McpAcl -Path $Path) {
        return [pscustomobject]@{
            Path      = $Path
            Protected = $true
            RuleCount = 1
            Status    = 'already'
        }
    }
    try {
        $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        if ($null -eq $sid) {
            throw 'SID do usuario atual indisponivel'
        }
        if ($Directory) {
            $acl = [System.Security.AccessControl.DirectorySecurity]::new()
            $acl.SetAccessRuleProtection($true, $false)
            $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
                [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $sid,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                $inheritance,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $acl.AddAccessRule($rule)
        } else {
            $acl = [System.Security.AccessControl.FileSecurity]::new()
            $acl.SetAccessRuleProtection($true, $false)
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $sid,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
    } catch {
        throw "XPZ_MCP_ACL_NAO_APLICAVEL: $Path :: $($_.Exception.Message)"
    }

    $check = Get-Acl -LiteralPath $Path
    if (-not $check.AreAccessRulesProtected) {
        throw "XPZ_MCP_ACL_NAO_APLICAVEL: heranca permaneceu ativa em $Path"
    }
    $rules = @($check.Access)
    if ($rules.Count -ne 1) {
        throw "XPZ_MCP_ACL_NAO_APLICAVEL: esperada uma regra de acesso em $Path; encontradas $($rules.Count)"
    }
    if ([string]$rules[0].AccessControlType -ne 'Allow') {
        throw "XPZ_MCP_ACL_NAO_APLICAVEL: regra de acesso nao e Allow em $Path"
    }
    return [pscustomobject]@{
        Path      = $Path
        Protected = $true
        RuleCount = $rules.Count
        Identity  = [string]$rules[0].IdentityReference
        Status    = 'applied'
    }
}

function Protect-McpSecret {
    param([Parameter(Mandatory = $true)][string]$Secret)
    if ([string]::IsNullOrWhiteSpace($Secret)) {
        throw 'XPZ_MCP_SECRET_EMPTY: segredo vazio'
    }
    Add-Type -AssemblyName System.Security.Cryptography.ProtectedData -ErrorAction Stop
    $plain = [System.Text.Encoding]::UTF8.GetBytes($Secret)
    try {
        $cipher = [System.Security.Cryptography.ProtectedData]::Protect(
            $plain,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return [Convert]::ToBase64String($cipher)
    } finally {
        [Array]::Clear($plain, 0, $plain.Length)
    }
}

function Unprotect-McpSecret {
    param([Parameter(Mandatory = $true)][string]$CipherText)
    if ([string]::IsNullOrWhiteSpace($CipherText)) {
        throw 'XPZ_MCP_CIPHER_EMPTY: cipherText vazio'
    }
    Add-Type -AssemblyName System.Security.Cryptography.ProtectedData -ErrorAction Stop
    $cipher = [Convert]::FromBase64String($CipherText)
    $plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
        $cipher,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::CurrentUser
    )
    try {
        return [System.Text.Encoding]::UTF8.GetString($plain)
    } finally {
        [Array]::Clear($plain, 0, $plain.Length)
    }
}

function ConvertFrom-McpSecureString {
    param([Parameter(Mandatory = $true)][System.Security.SecureString]$SecureString)
    $bstr = [IntPtr]::Zero
    try {
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function Ensure-McpAclFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $stream.Dispose()
    }
    return (Set-McpAcl -Path $Path)
}

function Write-McpVault {
    param(
        [Parameter(Mandatory = $true)][System.Security.SecureString]$SecureSecret,
        [string]$Mode = 'compatible',
        [string]$SecretEnvVar = 'JEV_API_KEY',
        [switch]$WhatIf
    )
    $plain = ConvertFrom-McpSecureString -SecureString $SecureSecret
    if ([string]::IsNullOrWhiteSpace($plain)) {
        throw 'XPZ_MCP_SECRET_EMPTY: segredo vazio'
    }

    $vaultDir = Get-McpVaultDir
    $blobPath = Get-McpVaultBlobPath
    if (-not (Test-Path -LiteralPath $vaultDir -PathType Container)) {
        if ($WhatIf) {
            return [pscustomobject]@{ Status = 'planned'; Path = $blobPath; Verified = $false }
        }
        New-Item -ItemType Directory -Path $vaultDir -Force | Out-Null
    }
    $null = Set-McpAcl -Path $vaultDir -Directory
    if (-not (Test-Path -LiteralPath $blobPath)) {
        if ($WhatIf) {
            return [pscustomobject]@{ Status = 'planned'; Path = $blobPath; Verified = $false }
        }
        $null = Ensure-McpAclFile -Path $blobPath
    }

    $cipherText = Protect-McpSecret -Secret $plain
    $blob = [ordered]@{
        version      = 1
        mode         = $Mode
        secretEnvVar = $SecretEnvVar
        cipherText   = $cipherText
    }
    $json = (($blob | ConvertTo-Json -Depth 6) -replace "`r`n", "`n") + "`n"
    $existing = $null
    if (Test-Path -LiteralPath $blobPath) {
        try {
            $existing = Read-McpTextDocument -Path $blobPath
        } catch {
            $existing = $null
        }
    }
    $expectedHash = $null
    $expectedLength = $null
    $expectedMtime = $null
    if ($null -ne $existing) {
        $expectedHash = $existing.Hash
        $expectedLength = [long]$existing.Length
        $expectedMtime = $existing.LastWriteTimeUtc
    }
    $writeResult = Write-McpTextTransactional `
        -Path $blobPath `
        -Text $json `
        -EncodingKind 'utf8-nobom' `
        -ExpectedHash $expectedHash `
        -ExpectedLength $expectedLength `
        -ExpectedLastWriteTimeUtc $expectedMtime `
        -WhatIf:$WhatIf
    if ($WhatIf) {
        return [pscustomobject]@{ Status = 'planned'; Path = $blobPath; Verified = $false }
    }
    if (-not (Test-McpAcl -Path $blobPath)) {
        $null = Set-McpAcl -Path $blobPath
    }
    $roundTrip = Read-McpVault
    if ($roundTrip -cne $plain) {
        throw 'XPZ_MCP_VAULT_VERIFY_FAILED: o blob gravado nao descriptografa para o mesmo valor'
    }
    return [pscustomobject]@{
        Status   = $writeResult.Status
        Path     = $blobPath
        Backup   = $writeResult.BackupPath
        Verified = $true
    }
}

function Read-McpVault {
    $blobPath = Get-McpVaultBlobPath
    if (-not (Test-McpRegularFile -Path $blobPath)) {
        throw 'XPZ_MCP_VAULT_MISSING: cofre DPAPI ausente'
    }
    try {
        $blob = Get-McpJsonFile -Path $blobPath
    } catch {
        throw "XPZ_MCP_VAULT_INVALID: $($_.Exception.Message)"
    }
    if ($null -eq $blob -or $blob.version -ne 1) {
        throw 'XPZ_MCP_VAULT_INVALID: versao do blob invalida'
    }
    if ([string]$blob.mode -ne 'compatible' -or [string]$blob.secretEnvVar -ne 'JEV_API_KEY') {
        throw 'XPZ_MCP_VAULT_INVALID: metadados do blob incompativeis'
    }
    return (Unprotect-McpSecret -CipherText ([string]$blob.cipherText))
}

function Test-McpVaultExists {
    return (Test-McpRegularFile -Path (Get-McpVaultBlobPath))
}

function Remove-McpVault {
    param([switch]$WhatIf)
    $blobPath = Get-McpVaultBlobPath
    if (-not (Test-Path -LiteralPath $blobPath)) {
        return [pscustomobject]@{ Status = 'absent'; Path = $blobPath }
    }
    if ($WhatIf) {
        return [pscustomobject]@{ Status = 'planned'; Path = $blobPath }
    }
    Remove-Item -LiteralPath $blobPath -Force
    return [pscustomobject]@{ Status = 'removed'; Path = $blobPath }
}

function Test-McpDpapiRoundTrip {
    param([string]$TestSecret = 'xpz-mcp-integrations-setup-dpapi-roundtrip')
    $cipher = Protect-McpSecret -Secret $TestSecret
    $plain = Unprotect-McpSecret -CipherText $cipher
    return ($plain -ceq $TestSecret)
}

function ConvertTo-McpCredentialEntries {
    param([Parameter(Mandatory = $true)][AllowNull()]$Root)
    $entries = @()
    if ($null -eq $Root) {
        return $entries
    }
    if ($Root -is [System.Collections.IEnumerable] -and $Root -isnot [string] -and $Root -isnot [System.Collections.IDictionary]) {
        foreach ($item in $Root) {
            $entries += $item
        }
        return $entries
    }
    if ($Root -is [System.Collections.IDictionary] -and
        ($Root.Contains('integrationID') -or $Root.Contains('integrationId') -or $Root.Contains('value'))) {
        return @([pscustomobject](ConvertTo-McpOrdered -Value $Root))
    }
    if ($Root -is [System.Collections.IDictionary]) {
        foreach ($key in $Root.Keys) {
            $value = $Root[$key]
            if ($key -in @('credentials', 'providers', 'auth', 'accounts') -and
                $value -is [System.Collections.IEnumerable] -and
                $value -isnot [string]) {
                foreach ($item in $value) {
                    $entries += $item
                }
            } elseif ($value -is [System.Collections.IDictionary] -or $value -is [System.Management.Automation.PSCustomObject]) {
                $candidate = ConvertTo-McpOrdered -Value $value
                if ($candidate -is [System.Collections.IDictionary] -and
                    -not $candidate.Contains('provider') -and
                    -not $candidate.Contains('integrationID') -and
                    -not $candidate.Contains('integrationId')) {
                    $candidate['provider'] = [string]$key
                }
                $entries += [pscustomobject]$candidate
            }
        }
        return $entries
    }
    if ($Root -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Root.PSObject.Properties) {
            if ($property.Name -in @('credentials', 'providers', 'auth', 'accounts') -and
                $property.Value -is [System.Collections.IEnumerable] -and
                $property.Value -isnot [string]) {
                foreach ($item in $property.Value) {
                    $entries += $item
                }
            } elseif ($property.Value -is [System.Management.Automation.PSCustomObject]) {
                $candidate = ConvertTo-McpOrdered -Value $property.Value
                if ($candidate -is [System.Collections.IDictionary] -and -not $candidate.Contains('provider')) {
                    $candidate['provider'] = $property.Name
                }
                $entries += [pscustomobject]$candidate
            }
        }
    }
    return $entries
}

function Get-McpCredentialFromEntries {
    param(
        [object[]]$Entries = @(),
        [Parameter(Mandatory = $true)][string]$Source
    )
    $matches = @()
    foreach ($entry in $Entries) {
        if ($null -eq $entry) { continue }
        $record = ConvertTo-McpOrdered -Value $entry
        if ($record -isnot [System.Collections.IDictionary]) { continue }
        $integration = [string]($record['integrationID'] ?? $record['integrationId'] ?? $record['provider'] ?? $record['id'])
        if ($integration -ne 'commandcode') { continue }
        if ($record.Contains('active') -and $record['active'] -eq $false) { continue }
        $value = $record['value']
        $kind = $null
        $secret = $null
        if ($value -is [System.Collections.IDictionary]) {
            $kind = [string]$value['type']
            $secret = [string]($value['key'] ?? $value['value'])
        } elseif ($value -is [System.Management.Automation.PSCustomObject]) {
            $kind = [string]$value.type
            $secret = [string]$value.key
        }
        if ([string]::IsNullOrWhiteSpace($kind)) {
            $kind = [string]($record['type'])
        }
        if ([string]::IsNullOrWhiteSpace($secret)) {
            $secret = [string]($record['key'] ?? $record['secret'])
        }
        if ($kind -ne 'key' -or [string]::IsNullOrWhiteSpace($secret)) { continue }
        $matches += [pscustomobject]@{ Secret = $secret; Source = $Source }
    }
    if ($matches.Count -eq 0) {
        return [pscustomobject]@{ Status = 'absent'; Secret = $null; Source = $Source }
    }
    if ($matches.Count -gt 1) {
        return [pscustomobject]@{ Status = 'ambiguous'; Secret = $null; Source = $Source }
    }
    return [pscustomobject]@{ Status = 'ok'; Secret = $matches[0].Secret; Source = $Source }
}

function Get-McpAuthJsonCredential {
    $path = Join-Path (Get-McpProfileRoot) '.config\opencode\auth.json'
    if (-not (Test-McpRegularFile -Path $path)) {
        return [pscustomobject]@{ Status = 'absent'; Secret = $null; Source = 'auth.json'; Path = $path }
    }
    try {
        $root = Get-McpJsonFile -Path $path
    } catch {
        return [pscustomobject]@{ Status = 'invalid'; Secret = $null; Source = 'auth.json'; Path = $path; Error = $_.Exception.Message }
    }
    if ($null -eq $root) {
        return [pscustomobject]@{ Status = 'absent'; Secret = $null; Source = 'auth.json'; Path = $path }
    }
    $candidate = Get-McpDictionaryValue -Object $root -Key 'commandcode'
    if ($null -eq $candidate) {
        return [pscustomobject]@{ Status = 'absent'; Secret = $null; Source = 'auth.json'; Path = $path }
    }
    $record = ConvertTo-McpOrdered -Value $candidate
    $kind = [string]($record['type'])
    $secret = [string]($record['key'] ?? $record['value'])
    if ($record.Contains('active') -and $record['active'] -eq $false) {
        return [pscustomobject]@{ Status = 'absent'; Secret = $null; Source = 'auth.json'; Path = $path }
    }
    if ($kind -ne 'key' -or [string]::IsNullOrWhiteSpace($secret)) {
        return [pscustomobject]@{ Status = 'absent'; Secret = $null; Source = 'auth.json'; Path = $path }
    }
    return [pscustomobject]@{ Status = 'ok'; Secret = $secret; Source = 'auth.json'; Path = $path }
}

function Get-McpOpenCodeCredential {
    <#
    .SYNOPSIS
        Bootstrap unico: export do OpenCode (preferido) e auth.json (reserva).
    #>
    $export = [pscustomobject]@{ Status = 'unavailable'; Secret = $null; Source = 'opencode-auth-export' }
    $command = Get-McpCommandInfo -Name 'opencode' -VersionArguments @('--version')
    if ($command.Present) {
        try {
            $output = @(& $command.Path 'auth' 'export' 2>&1)
            $exitCode = $LASTEXITCODE
            $text = (($output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
            if ($exitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($text)) {
                $firstBrace = $text.IndexOf('{')
                $firstBracket = $text.IndexOf('[')
                $start = -1
                if ($firstBrace -lt 0) { $start = $firstBracket }
                elseif ($firstBracket -lt 0) { $start = $firstBrace }
                else { $start = [Math]::Min($firstBrace, $firstBracket) }
                if ($start -lt 0) {
                    throw 'export sem objeto/array JSON'
                }
                $lastBrace = $text.LastIndexOf('}')
                $lastBracket = $text.LastIndexOf(']')
                $end = [Math]::Max($lastBrace, $lastBracket)
                if ($end -lt $start) {
                    throw 'export com JSON incompleto'
                }
                $jsonText = $text.Substring($start, $end - $start + 1)
                $parsed = $jsonText | ConvertFrom-Json -Depth 30
                $entries = @(ConvertTo-McpCredentialEntries -Root $parsed)
                $export = Get-McpCredentialFromEntries -Entries $entries -Source 'opencode-auth-export'
            }
        } catch {
            $export = [pscustomobject]@{ Status = 'invalid'; Secret = $null; Source = 'opencode-auth-export'; Error = $_.Exception.Message }
        }
    }

    if ($export.Status -eq 'ok') {
        return $export
    }
    if ($export.Status -eq 'ambiguous') {
        return $export
    }
    $authJson = Get-McpAuthJsonCredential
    if ($authJson.Status -eq 'ok') {
        return $authJson
    }
    if ($authJson.Status -eq 'invalid') {
        return $authJson
    }
    return [pscustomobject]@{
        Status = $export.Status
        Secret = $null
        Source = $export.Source
        FallbackSource = $authJson.Source
    }
}
