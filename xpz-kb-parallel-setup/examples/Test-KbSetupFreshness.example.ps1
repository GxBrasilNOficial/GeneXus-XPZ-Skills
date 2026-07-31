#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local para verificar frescor do setup da pasta paralela da KB em relacao ao contrato de setup XPZ.

.DESCRIPTION
Delega ao motor compartilhado Test-XpzSetupFreshness.ps1 com os caminhos fixos desta pasta paralela.
Retorna GATE_ONLY quando a assinatura de contrato auditada em kb-source-metadata.md coincide
com a assinatura atual de xpz-kb-parallel-setup; retorna AUDIT_REQUIRED com motivo nos demais casos.

Usado como primeira ação obrigatória da PRE-CONDICAO em xpz-kb-parallel-setup ao ser invocado
pelo gatilho global (quando o usuário não pede explicitamente setup, atualizacao ou auditoria).

.EXAMPLE
.\Test-KbSetupFreshness.ps1
#>

param(
    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills",

    [string]$PowerShellRuntimeWrapperPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$KbParallelRoot = Split-Path -Parent $PSScriptRoot
$PowerShellRuntimeWrapperPath = if ($PowerShellRuntimeWrapperPath) {
    $PowerShellRuntimeWrapperPath
} else {
    Join-Path $PSScriptRoot 'Test-KbPowerShellRuntime.ps1'
}

if (-not (Test-Path -LiteralPath $PowerShellRuntimeWrapperPath -PathType Leaf)) {
    throw "BLOCK: wrapper de runtime PowerShell ausente: $PowerShellRuntimeWrapperPath"
}

$global:LASTEXITCODE = $null
& $PowerShellRuntimeWrapperPath
$runtimeCommandSucceeded = $?
$runtimeExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $runtimeExitCodeVariable -and $runtimeExitCodeVariable.Value -is [int] -and $runtimeExitCodeVariable.Value -ne 0) {
    exit $runtimeExitCodeVariable.Value
}
if (-not $runtimeCommandSucceeded) {
    exit 1
}

$enginePath = Join-Path $SharedSkillsRoot 'scripts\Test-XpzSetupFreshness.ps1'

if (-not (Test-Path -LiteralPath $enginePath)) {
    throw "Engine script not found: $enginePath"
}

$global:LASTEXITCODE = $null
& $enginePath -KbParallelRoot $KbParallelRoot -SkillsRoot $SharedSkillsRoot
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
