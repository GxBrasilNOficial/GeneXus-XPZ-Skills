<#
.SYNOPSIS
Wrapper local sanitizado para validar o runtime PowerShell mínimo da pasta paralela da KB.

.DESCRIPTION
Delega ao motor compartilhado `Test-XpzPowerShellRuntime.ps1`.
Este gate deve ser executado antes de qualquer uso operacional da pasta paralela.
Este wrapper não usa `#requires -Version 7.4` de proposito, para conseguir
emitir `BLOCK:` também quando chamado a partir de um host PowerShell antigo.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\Test-KbPowerShellRuntime.ps1
#>

param(
    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$enginePath = Join-Path $SharedSkillsRoot 'scripts\Test-XpzPowerShellRuntime.ps1'

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Engine script not found: $enginePath"
}

$global:LASTEXITCODE = $null
& $enginePath -MinimumVersion ([version]'7.4')
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
