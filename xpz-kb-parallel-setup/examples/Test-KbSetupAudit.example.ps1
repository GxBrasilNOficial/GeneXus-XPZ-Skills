#requires -version 5.1
<#
.SYNOPSIS
Wrapper local sanitizado para auditoria agregada da pasta paralela da KB.

.DESCRIPTION
Executa o script compartilhado `Test-XpzSetupAudit.ps1` para consolidar, em
saida deterministica, as evidencias principais de auditoria operacional da
pasta paralela: `sync/materializacao`, `indice/gate`, `metadata wrapper`,
`empacotamento local` e `estado_operacional_sugerido`.

Este wrapper nao substitui os gates especificos. Ele apenas centraliza a
execucao deles para handoff e diagnostico curto em `modo_atualizacao`.

.PARAMETER KbRoot
Caminho opcional para a raiz da pasta paralela da KB.
Quando omitido, usa a pasta pai de `scripts`.

.PARAMETER GateWrapperPath
Caminho opcional para `Test-KbGate.ps1`.

.PARAMETER MetadataWrapperTestPath
Caminho opcional para `Test-KbMetadataWrapper.ps1`.

.PARAMETER SourceSanityWrapperPath
Caminho opcional para `Test-KbSourceSanity.ps1`.

.PARAMETER PackageCollisionWrapperPath
Caminho opcional para `Test-KbPackageCollision.ps1`.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\Test-KbSetupAudit.ps1

.EXAMPLE
.\Test-KbSetupAudit.ps1 -KbRoot C:\KB
#>

param(
    [string]$KbRoot,

    [string]$GateWrapperPath,

    [string]$MetadataWrapperTestPath,

    [string]$SourceSanityWrapperPath,

    [string]$PackageCollisionWrapperPath,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $KbRoot) {
    $KbRoot = Split-Path -Parent $PSScriptRoot
}

if (-not $GateWrapperPath) {
    $GateWrapperPath = Join-Path $PSScriptRoot 'Test-KbGate.ps1'
}

if (-not $MetadataWrapperTestPath) {
    $MetadataWrapperTestPath = Join-Path $PSScriptRoot 'Test-KbMetadataWrapper.ps1'
}

if (-not $SourceSanityWrapperPath) {
    $candidate = Join-Path $PSScriptRoot 'Test-KbSourceSanity.ps1'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $SourceSanityWrapperPath = $candidate
    }
}

if (-not $PackageCollisionWrapperPath) {
    $candidate = Join-Path $PSScriptRoot 'Test-KbPackageCollision.ps1'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        $PackageCollisionWrapperPath = $candidate
    }
}

$enginePath = Join-Path $SharedSkillsRoot 'scripts\Test-XpzSetupAudit.ps1'
if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared setup audit script not found: $enginePath"
}

& $enginePath `
    -KbRoot $KbRoot `
    -GateWrapperPath $GateWrapperPath `
    -MetadataWrapperTestPath $MetadataWrapperTestPath `
    -SourceSanityWrapperPath $SourceSanityWrapperPath `
    -PackageCollisionWrapperPath $PackageCollisionWrapperPath
