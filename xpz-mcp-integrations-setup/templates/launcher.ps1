#requires -Version 7.4
# xpz-mcp-integrations-setup:launcher v1
# template-revision: 2
# package: @jkudish/jev-mcp@__XPZ_MCP_PACKAGE_VERSION__
#
# Launcher gerado pela skill xpz-mcp-integrations-setup. Nao editar a mao: a copia
# emitida e reconhecida por sentinela e hash no install-manifest.json. A revisao do
# molde sobe quando o comportamento do launcher muda; copia com revisao menor (ou
# sem a linha) e launcher_desatualizado e pede reparo.
#
# Contrato: stdio herdado do cliente (sem RedirectStandard*), ambiente do filho
# limpo e montado por allowlist, zero bytes do launcher em stdout, exit code do
# filho propagado como ultima instrucao.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$mcpManagedRoot = '__XPZ_MCP_MANAGED_ROOT__'
$mcpNodePath = '__XPZ_MCP_NODE_PATH__'
$mcpEntryPath = '__XPZ_MCP_ENTRY_PATH__'
$mcpVendorDir = '__XPZ_MCP_VENDOR_DIR__'
$mcpPresetHost = '__XPZ_MCP_PRESET_HOST__'
$mcpConfigPath = Join-Path $mcpManagedRoot 'config.json'
$mcpVaultPath = Join-Path $mcpManagedRoot 'vault\credential.blob'

function Write-McpLauncherError {
    param([Parameter(Mandatory = $true)][string]$Message)
    [Console]::Error.WriteLine("xpz-mcp-integrations-setup launcher: $Message")
}

function Test-McpLauncherRegularFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    $item = Get-Item -LiteralPath $Path -Force
    return -not (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint)
}

function Get-McpLauncherConfig {
    if (-not (Test-McpLauncherRegularFile -Path $mcpConfigPath)) {
        throw [System.IO.InvalidDataException]::new('config.json ausente ou nao regular')
    }
    try {
        $config = Get-Content -LiteralPath $mcpConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
        throw [System.IO.InvalidDataException]::new('config.json invalido')
    }
    if ($null -eq $config -or $config.schemaVersion -ne 1) {
        throw [System.IO.InvalidDataException]::new('config.json com schemaVersion invalido')
    }
    if ([string]$config.provider -ne 'compatible') {
        throw [System.IO.InvalidDataException]::new('config.json com provider nao suportado')
    }
    $baseUrl = [string]$config.baseUrl
    $model = [string]$config.model
    if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($model)) {
        throw [System.IO.InvalidDataException]::new('config.json sem baseUrl/model')
    }
    # Mesma regra do install e da auditoria, antes de abrir o cofre: so https, e host
    # fora do preset exige endpointConfirmed booleano verdadeiro.
    if ($baseUrl -notmatch '^https://[^\s]+$') {
        throw [System.IO.InvalidDataException]::new('config.json com baseUrl que nao e https')
    }
    $baseUri = $null
    if (-not [Uri]::TryCreate($baseUrl, [UriKind]::Absolute, [ref]$baseUri)) {
        throw [System.IO.InvalidDataException]::new('config.json com baseUrl invalida')
    }
    $confirmedProperty = $config.PSObject.Properties['endpointConfirmed']
    $endpointConfirmed = ($null -ne $confirmedProperty -and $confirmedProperty.Value -is [bool] -and $confirmedProperty.Value)
    if (-not [string]::Equals($baseUri.Host, $mcpPresetHost, [System.StringComparison]::OrdinalIgnoreCase) -and -not $endpointConfirmed) {
        throw [System.IO.InvalidDataException]::new('config.json com host fora do preset sem endpoint confirmado; execute o reparo da skill com -ConfirmEndpoint')
    }
    return [pscustomobject]@{
        BaseUrl = $baseUrl
        Model   = $model
    }
}

function Get-McpLauncherSecret {
    if (-not (Test-McpLauncherRegularFile -Path $mcpVaultPath)) {
        throw [System.IO.FileNotFoundException]::new('cofre DPAPI ausente')
    }
    try {
        $blob = Get-Content -LiteralPath $mcpVaultPath -Raw -Encoding utf8 | ConvertFrom-Json
    } catch {
        throw [System.IO.InvalidDataException]::new('blob do cofre invalido')
    }
    if ($null -eq $blob -or $blob.version -ne 1 -or [string]$blob.mode -ne 'compatible' -or [string]$blob.secretEnvVar -ne 'JEV_API_KEY') {
        throw [System.IO.InvalidDataException]::new('blob do cofre incompativel com o modo compatible')
    }
    try {
        Add-Type -AssemblyName System.Security.Cryptography.ProtectedData -ErrorAction Stop
        $cipher = [Convert]::FromBase64String([string]$blob.cipherText)
        $plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $cipher,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
    } catch {
        throw [System.Security.Cryptography.CryptographicException]::new('falha ao descriptografar o cofre DPAPI')
    }
    try {
        $secret = [System.Text.Encoding]::UTF8.GetString($plain)
        if ([string]::IsNullOrWhiteSpace($secret)) {
            throw [System.IO.InvalidDataException]::new('cofre DPAPI vazio')
        }
        return $secret
    } finally {
        [Array]::Clear($plain, 0, $plain.Length)
    }
}

function New-McpLauncherStartInfo {
    param(
        [Parameter(Mandatory = $true)][string]$NodePath,
        [Parameter(Mandatory = $true)][string]$EntryPath,
        [Parameter(Mandatory = $true)][string]$VendorDir,
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Model,
        [Parameter(Mandatory = $true)][string]$Secret
    )

    if ($EntryPath.Contains('"')) {
        throw [System.IO.InvalidDataException]::new('caminho de entrada com aspas duplas')
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $NodePath
    $psi.Arguments = '"' + $EntryPath + '"'
    $psi.WorkingDirectory = $VendorDir
    $psi.UseShellExecute = $false
    # CreateNoWindow=true impede a heranca dos handles de stdio do cliente neste
    # runtime; o filho precisa herdar stdout/stderr do launcher (sem redirecionar).
    $psi.CreateNoWindow = $false
    $psi.Environment.Clear()

    $systemRoot = [Environment]::GetEnvironmentVariable('SystemRoot')
    if ([string]::IsNullOrWhiteSpace($systemRoot)) {
        $systemRoot = [Environment]::GetFolderPath('Windows')
    }
    $systemDrive = [Environment]::GetEnvironmentVariable('SystemDrive')
    if ([string]::IsNullOrWhiteSpace($systemDrive) -and -not [string]::IsNullOrWhiteSpace($systemRoot)) {
        $systemDrive = [System.IO.Path]::GetPathRoot($systemRoot).TrimEnd('\')
    }
    $tempPath = [Environment]::GetEnvironmentVariable('TEMP')
    if ([string]::IsNullOrWhiteSpace($tempPath)) {
        $tempPath = [System.IO.Path]::GetTempPath()
    }

    $systemEnvironment = [ordered]@{
        SystemRoot   = $systemRoot
        SystemDrive  = $systemDrive
        TEMP         = $tempPath
        TMP          = $tempPath
        PATHEXT      = [Environment]::GetEnvironmentVariable('PATHEXT')
        COMSPEC      = [Environment]::GetEnvironmentVariable('COMSPEC')
        LOCALAPPDATA = [Environment]::GetEnvironmentVariable('LOCALAPPDATA')
        USERPROFILE  = [Environment]::GetEnvironmentVariable('USERPROFILE')
        APPDATA      = [Environment]::GetEnvironmentVariable('APPDATA')
    }
    foreach ($name in $systemEnvironment.Keys) {
        $value = $systemEnvironment[$name]
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $psi.Environment[$name] = [string]$value
        }
    }

    $minimalPath = @()
    if (-not [string]::IsNullOrWhiteSpace($systemRoot)) {
        $minimalPath += (Join-Path $systemRoot 'System32')
        $minimalPath += $systemRoot
    }
    if ($minimalPath.Count -gt 0) {
        $psi.Environment['PATH'] = ($minimalPath -join ';')
    }

    $psi.Environment['JEV_API_KEY'] = $Secret
    $psi.Environment['JEV_API_BASE_URL'] = $BaseUrl
    $psi.Environment['JEV_MCP_MODEL'] = $Model
    return $psi
}

$mcpExitCode = 69
$mcpSecret = $null
try {
    $mcpConfig = Get-McpLauncherConfig
    $mcpSecret = Get-McpLauncherSecret

    if (-not (Test-McpLauncherRegularFile -Path $mcpNodePath)) {
        Write-McpLauncherError 'node resolvido no install nao existe; execute o reparo da skill'
        exit 63
    }
    if (-not (Test-McpLauncherRegularFile -Path $mcpEntryPath)) {
        Write-McpLauncherError 'entrada do pacote vendorizado nao existe; execute o reparo da skill'
        exit 64
    }
    if (-not (Test-Path -LiteralPath $mcpVendorDir -PathType Container)) {
        Write-McpLauncherError 'arvore vendorizada ausente; execute o reparo da skill'
        exit 64
    }

    $mcpStartInfo = New-McpLauncherStartInfo `
        -NodePath $mcpNodePath `
        -EntryPath $mcpEntryPath `
        -VendorDir $mcpVendorDir `
        -BaseUrl $mcpConfig.BaseUrl `
        -Model $mcpConfig.Model `
        -Secret $mcpSecret

    $mcpProcess = [System.Diagnostics.Process]::Start($mcpStartInfo)
    if ($null -eq $mcpProcess) {
        Write-McpLauncherError 'falha ao iniciar o processo filho'
        exit 69
    }
    $mcpProcess.WaitForExit()
    $mcpExitCode = [int]$mcpProcess.ExitCode
} catch [System.IO.FileNotFoundException] {
    Write-McpLauncherError 'cofre DPAPI ausente; execute Set-McpCredential.ps1'
    exit 61
} catch [System.Security.Cryptography.CryptographicException] {
    Write-McpLauncherError 'cofre DPAPI ilegivel para este usuario; re-insira a chave'
    exit 61
} catch [System.IO.InvalidDataException] {
    Write-McpLauncherError $_.Exception.Message
    exit 62
} catch {
    Write-McpLauncherError ('falha interna: ' + $_.Exception.Message)
    exit 69
} finally {
    if ($null -ne $mcpSecret) {
        $mcpSecret = $null
    }
}

exit $mcpExitCode
