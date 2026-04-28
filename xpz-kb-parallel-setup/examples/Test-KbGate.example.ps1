#requires -version 5.1
<#
.SYNOPSIS
Wrapper local sanitizado para executar o gate de compatibilidade da pasta paralela.

.DESCRIPTION
Verifica sequencialmente: estrutura da pasta paralela via Test-*KbStructure.ps1,
pasta KbIntelligence, kb-intelligence.sqlite, wrapper local de consulta,
metadado de build do indice via index-metadata, kb-source-metadata.md e campo
last_xpz_materialization_run_at. Compara timestamps e retorna GATE_OK em stdout
quando o indice esta apto, ou lanca excecao com BLOCK: <motivo> quando nao esta.

Deve ser o unico ponto de execucao do gate da pasta paralela da KB.
Dependencias: Query-KbIntelligence.ps1 e Test-KbStructure.ps1 na mesma pasta.

.PARAMETER QueryWrapperPath
Caminho opcional para o wrapper local de consulta do indice.
Quando omitido, usa Query-KbIntelligence.ps1 na mesma pasta deste script.

.PARAMETER StructureWrapperPath
Caminho opcional para o wrapper local de verificacao de estrutura.
Quando omitido, usa Test-KbStructure.ps1 na mesma pasta deste script.

.EXAMPLE
.\Test-KbGate.ps1

.EXAMPLE
& (Join-Path $kbRoot 'scripts\Test-FabricaBrasilKbGate.ps1')
#>

param(
    [string]$QueryWrapperPath,
    [string]$StructureWrapperPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$indexDir = Join-Path $repoRoot 'KbIntelligence'
$indexPath = Join-Path $indexDir 'kb-intelligence.sqlite'
$sourceMetadata = Join-Path $repoRoot 'kb-source-metadata.md'

if (-not $QueryWrapperPath) {
    $QueryWrapperPath = Join-Path $PSScriptRoot 'Query-KbIntelligence.ps1'
}

if (-not $StructureWrapperPath) {
    $StructureWrapperPath = Join-Path $PSScriptRoot 'Test-KbStructure.ps1'
}

if (-not (Test-Path -LiteralPath $StructureWrapperPath -PathType Leaf)) {
    throw 'BLOCK: wrapper local de estrutura ausente'
}
$structureOutput = & $StructureWrapperPath *>&1
$structureText = ($structureOutput | Where-Object { $_ -is [string] } | Out-String)
$structureWarnings = @($structureOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
foreach ($w in $structureWarnings) { Write-Warning $w.Message }
if ((-not $?) -or $structureText -notmatch 'STRUCTURE_OK') {
    throw "BLOCK: estrutura da pasta paralela falhou: $($structureText.Trim())"
}

if (-not (Test-Path -LiteralPath $indexDir -PathType Container)) {
    throw 'BLOCK: pasta KbIntelligence ausente'
}
if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw 'BLOCK: KbIntelligence\kb-intelligence.sqlite ausente'
}
if (-not (Test-Path -LiteralPath $QueryWrapperPath -PathType Leaf)) {
    throw 'BLOCK: wrapper local de consulta ausente'
}

$indexMetadata = & $QueryWrapperPath -Query index-metadata -Format text
$indexMetadataText = ($indexMetadata | Out-String)
if ([string]::IsNullOrWhiteSpace($indexMetadataText) -or ($indexMetadataText -notmatch 'last_index_build_run_at')) {
    throw 'BLOCK: index-metadata ausente ou sem last_index_build_run_at'
}

if (-not (Test-Path -LiteralPath $sourceMetadata -PathType Leaf)) {
    throw 'BLOCK: kb-source-metadata.md ausente'
}
$sourceMaterialization = Select-String -LiteralPath $sourceMetadata -Pattern 'last_xpz_materialization_run_at' -SimpleMatch
if (-not $sourceMaterialization) {
    throw 'BLOCK: kb-source-metadata.md sem last_xpz_materialization_run_at'
}

$indexMatch = [regex]::Match($indexMetadataText, 'last_index_build_run_at\s*[:=]\s*(?<value>\S+)')
$sourceMatch = [regex]::Match($sourceMaterialization.Line, 'last_xpz_materialization_run_at\s*[:=]\s*(?<value>\S+)')
if (-not $indexMatch.Success) {
    throw 'BLOCK: index-metadata sem valor parseavel de last_index_build_run_at'
}
if (-not $sourceMatch.Success) {
    throw 'BLOCK: kb-source-metadata.md sem valor parseavel de last_xpz_materialization_run_at'
}

$lastIndexBuild = [datetimeoffset]::Parse($indexMatch.Groups['value'].Value)
$lastXpzMaterialization = [datetimeoffset]::Parse($sourceMatch.Groups['value'].Value)
if ($lastIndexBuild -lt $lastXpzMaterialization) {
    throw 'BLOCK: indice defasado em relacao a last_xpz_materialization_run_at'
}

'GATE_OK'
