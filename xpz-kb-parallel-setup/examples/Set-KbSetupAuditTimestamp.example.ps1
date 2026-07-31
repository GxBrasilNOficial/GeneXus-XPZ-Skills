#requires -Version 7.4
<#
.SYNOPSIS
Wrapper local para gravar last_setup_audit_run_at e setup_contract_signature_* após auditoria de setup bem-sucedida.

.DESCRIPTION
Delega ao motor compartilhado Set-XpzSetupAuditTimestamp.ps1 com a raiz fixa desta pasta paralela.
Atualiza last_setup_audit_run_at e setup_contract_signature_* em kb-source-metadata.md;
não altera campos de xpz-sync.

Usar após auditoria completa com estado canonico bem-sucedido (WORKFLOW passo 34) ou no subestado
setup_apto_com_metadata_pendente da PRE-CONDICAO, com aprovacao explicita quando regras locais exigirem.

Depois de gravar, rerodar Test-*KbSetupFreshness.ps1 (esperar GATE_ONLY) e Test-*KbIndexGate.ps1 (GATE_OK).

.PARAMETER AuditTimestamp
Timestamp ISO 8601 opcional. Quando omitido, o motor usa o instante atual.

.PARAMETER AsJson
Repassa saida JSON do motor compartilhado.

.EXAMPLE
.\Set-KbSetupAuditTimestamp.ps1

.EXAMPLE
.\Set-KbSetupAuditTimestamp.ps1 -AuditTimestamp "2026-05-27T22:45:00-03:00" -AsJson
#>

param(
    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills",

    [string]$AuditTimestamp,

    [switch]$AsJson,

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

$enginePath = Join-Path $SharedSkillsRoot 'scripts\Set-XpzSetupAuditTimestamp.ps1'

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Engine script not found: $enginePath"
}

$params = @{
    KbParallelRoot = $KbParallelRoot
    SkillsRoot = $SharedSkillsRoot
}

if ($AuditTimestamp) {
    $params['AuditTimestamp'] = $AuditTimestamp
}

if ($AsJson) {
    $params['AsJson'] = $true
}

$global:LASTEXITCODE = $null
& $enginePath @params
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
