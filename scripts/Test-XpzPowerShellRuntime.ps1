<#
.SYNOPSIS
    Verifica se o runtime PowerShell mínimo da base XPZ está disponível.

.DESCRIPTION
    Gate consultivo para pastas paralelas de KB. Ele deve ser chamado antes
    dos demais wrappers locais para garantir que `pwsh` existe e atende ao
    contrato mínimo da base: PowerShell 7.4 LTS ou superior.
#>

[CmdletBinding()]
param(
    [version]$MinimumVersion = [version]'7.4'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'XpzProcessProbeSupport.ps1')

$pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
if ($null -eq $pwsh) {
    Write-Output "BLOCK: pwsh nao encontrado no PATH; instale PowerShell $MinimumVersion ou superior antes de usar esta pasta paralela"
    exit 1
}

$probe = Invoke-XpzProcessProbe -FilePath $pwsh.Source -ArgumentList @(
    '-NoProfile', '-Command', '$PSVersionTable.PSVersion.ToString()'
) -TimeoutMs 8000
if (-not $probe.Started) {
    Write-Output "BLOCK: falha ao iniciar pwsh: $($probe.Error)"
    exit 1
}
if ($probe.TimedOut) {
    Write-Output "BLOCK: pwsh nao respondeu dentro de 8000 ms; verifique o runtime em $($pwsh.Source)"
    exit 1
}
if (-not $probe.Completed -or $probe.ExitCode -ne 0) {
    $detail = if (-not [string]::IsNullOrWhiteSpace([string]$probe.StandardError)) { [string]$probe.StandardError.Trim() } else { [string]$probe.Error }
    Write-Output "BLOCK: consulta de versao do pwsh terminou com exit code $($probe.ExitCode): $detail"
    exit 1
}

$versionText = [string]$probe.StandardOutput
$actualVersion = $null
if (-not [version]::TryParse($versionText.Trim(), [ref]$actualVersion)) {
    Write-Output "BLOCK: nao foi possivel determinar versao do pwsh: '$versionText'"
    exit 1
}

if ($actualVersion -lt $MinimumVersion) {
    Write-Output "BLOCK: PowerShell $MinimumVersion ou superior requerido; encontrado $actualVersion em $($pwsh.Source)"
    exit 1
}

Write-Output "POWERSHELL_RUNTIME_OK: pwsh $actualVersion em $($pwsh.Source)"
exit 0
