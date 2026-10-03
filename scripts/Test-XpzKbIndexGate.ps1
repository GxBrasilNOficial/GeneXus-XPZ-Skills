#requires -Version 7.4
<#
.SYNOPSIS
  Motor compartilhado do gate de indice KbIntelligence (gate K9 da skill
  xpz-kb-parallel-pre-push): valida estrutura, frescor, inventario semantico e
  assinatura do extrator e cobertura de gravabilidade do indice derivado de uma pasta paralela de KB.

.DESCRIPTION
  Promovido a motor compartilhado (antes vivia inline no molde local), simetrico
  ao Test-XpzSetupAudit.ps1 do K8: recebe os caminhos da KB por parametro; o
  wrapper local fino apenas injeta os caminhos e repassa -AsJson.

  Verifica sequencialmente:
    1. estrutura da pasta paralela (STRUCTURE_OK via wrapper local de estrutura);
    2. pasta do indice + kb-intelligence.sqlite presentes;
    3. wrapper local de consulta presente;
    4. index-metadata com last_index_build_run_at e inventory_validation_status;
    5. kb-source-metadata.md com last_xpz_materialization_run_at;
    6. frescor: last_index_build_run_at >= last_xpz_materialization_run_at;
    7. inventory_validation_status literalmente OK;
    8. assinatura do extrator (version/hash/format na metadata do SQLite) contra o motor
       atual via GeneXusKbIntelligenceExtractorContract.ps1;
    9. cobertura e contagem das occurrences de gravabilidade, separadas da validade tecnica.

  CONTRATO DE SAIDA:
    - Default (texto): retrocompativel -- emite as linhas de assinatura,
      inventory_validation_status: OK e GATE_OK no sucesso; lanca excecao
      `BLOCK: <motivo>` no bloqueio (consumido por grep GATE_OK pelo
      Test-XpzSetupAudit e por agentes).
    - -AsJson: contrato estruturado -- objeto { status: OK|BLOCK, reason,
      extractor_signature_version, extractor_signature_hash,
      extractor_signature_format, writabilityCoverage, writabilityCoverageWarning,
      inventory_validation_status, last_index_build_run_at,
      last_xpz_materialization_run_at }. NUNCA lanca sob -AsJson: bloqueio vira
      { status: BLOCK, reason } + exit 1. Consumido pelo orquestrador K9.

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual).

.PARAMETER QueryWrapperPath
  Wrapper local de consulta do indice (default: <RepoRoot>/scripts/Query-KbIntelligence.ps1).

.PARAMETER StructureWrapperPath
  Wrapper local de verificacao de estrutura (default: <RepoRoot>/scripts/Test-KbStructure.ps1).

.PARAMETER IndexDirName
  Nome da pasta do indice derivado (default: KbIntelligence).

.PARAMETER MetadataFileName
  Nome do arquivo de metadados de materializacao (default: kb-source-metadata.md).

.PARAMETER ExtractorContractPath
  Caminho do contrato de assinatura do extrator (default: irmao deste motor em scripts/).

.PARAMETER AsJson
  Emite o contrato estruturado JSON em vez do texto retrocompativel.

.EXAMPLE
  Test-XpzKbIndexGate.ps1 -RepoRoot C:\Dev\Prod\Gx_FabricaBrasil -AsJson
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$QueryWrapperPath,
  [string]$StructureWrapperPath,
  [string]$IndexDirName = 'KbIntelligence',
  [string]$MetadataFileName = 'kb-source-metadata.md',
  [string]$ExtractorContractPath,
  [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $QueryWrapperPath) { $QueryWrapperPath = Join-Path $RepoRoot (Join-Path 'scripts' 'Query-KbIntelligence.ps1') }
if (-not $StructureWrapperPath) { $StructureWrapperPath = Join-Path $RepoRoot (Join-Path 'scripts' 'Test-KbStructure.ps1') }
if (-not $ExtractorContractPath) { $ExtractorContractPath = Join-Path $PSScriptRoot 'GeneXusKbIntelligenceExtractorContract.ps1' }

$indexDir = Join-Path $RepoRoot (($IndexDirName -replace '\\', '/').TrimEnd('/'))
$indexPath = Join-Path $indexDir 'kb-intelligence.sqlite'
$sourceMetadata = Join-Path $RepoRoot (($MetadataFileName -replace '\\', '/').Trim())

# Acumulador para o contrato estruturado.
$out = [ordered]@{ status = 'OK'; reason = $null }

function Fail-Gate {
  param([string]$Reason)
  if ($AsJson) {
    $out['status'] = 'BLOCK'
    $out['reason'] = $Reason
    [pscustomobject]$out | ConvertTo-Json -Depth 4
    exit 1
  }
  throw "BLOCK: $Reason"
}

# Safety-net do contrato "-AsJson nunca lanca": alem dos Fail-Gate conhecidos,
# qualquer excecao inesperada (parse de datetime, wrapper local que lanca, contrato
# de assinatura) tambem vira { status: BLOCK, reason } sob -AsJson, nunca um throw.
try {

# 1. estrutura
if (-not (Test-Path -LiteralPath $StructureWrapperPath -PathType Leaf)) { Fail-Gate 'wrapper local de estrutura ausente' }
$structureOutput = & $StructureWrapperPath *>&1
$structureOk = $?
$structureText = ($structureOutput | Where-Object { $_ -is [string] } | Out-String)
foreach ($w in @($structureOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })) { Write-Warning $w.Message }
if ((-not $structureOk) -or ($structureText -notmatch 'STRUCTURE_OK')) { Fail-Gate "estrutura da pasta paralela falhou: $($structureText.Trim())" }

# 2. indice
if (-not (Test-Path -LiteralPath $indexDir -PathType Container)) { Fail-Gate "pasta $IndexDirName ausente" }
if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) { Fail-Gate "$IndexDirName/kb-intelligence.sqlite ausente" }

# 3. wrapper de consulta
if (-not (Test-Path -LiteralPath $QueryWrapperPath -PathType Leaf)) { Fail-Gate 'wrapper local de consulta ausente' }

# 4. index-metadata
$indexMetadata = & $QueryWrapperPath -Query index-metadata -Format text
$indexMetadataText = ($indexMetadata | Out-String)
if ([string]::IsNullOrWhiteSpace($indexMetadataText) -or ($indexMetadataText -notmatch 'last_index_build_run_at')) { Fail-Gate 'index-metadata ausente ou sem last_index_build_run_at' }
if ($indexMetadataText -notmatch 'inventory_validation_status') { Fail-Gate 'index-metadata ausente ou sem inventory_validation_status' }

# 5. kb-source-metadata
if (-not (Test-Path -LiteralPath $sourceMetadata -PathType Leaf)) { Fail-Gate "$MetadataFileName ausente" }
$sourceMaterialization = Select-String -LiteralPath $sourceMetadata -Pattern 'last_xpz_materialization_run_at' -SimpleMatch
if (-not $sourceMaterialization) { Fail-Gate "$MetadataFileName sem last_xpz_materialization_run_at" }

# 6. frescor
$indexMatch = [regex]::Match($indexMetadataText, 'last_index_build_run_at\s*[:=]\s*(?<value>\S+)')
$sourceMatch = [regex]::Match($sourceMaterialization.Line, 'last_xpz_materialization_run_at\s*[:=]\s*(?<value>\S+)')
if (-not $indexMatch.Success) { Fail-Gate 'index-metadata sem valor parseavel de last_index_build_run_at' }
if (-not $sourceMatch.Success) { Fail-Gate "$MetadataFileName sem valor parseavel de last_xpz_materialization_run_at" }
$lastIndexBuild = [datetimeoffset]::Parse($indexMatch.Groups['value'].Value)
$lastXpzMaterialization = [datetimeoffset]::Parse($sourceMatch.Groups['value'].Value)
$out['last_index_build_run_at'] = $indexMatch.Groups['value'].Value
$out['last_xpz_materialization_run_at'] = $sourceMatch.Groups['value'].Value
if ($lastIndexBuild -lt $lastXpzMaterialization) { Fail-Gate 'indice defasado em relacao a last_xpz_materialization_run_at' }

# 7. inventario semantico
$inventoryStatusMatch = [regex]::Match($indexMetadataText, 'inventory_validation_status\s*[:=]\s*(?<value>\S+)')
if (-not $inventoryStatusMatch.Success) { Fail-Gate 'index-metadata sem valor parseavel de inventory_validation_status' }
if ($inventoryStatusMatch.Groups['value'].Value -ne 'OK') { Fail-Gate 'indice com inventario semantico invalido ou pendente' }

# A cobertura descreve certeza da classificação automática; não autoriza assignments.
$writabilityCoverageMatch = [regex]::Match($indexMetadataText, 'writability_coverage\s*[:=]\s*(?<value>\S+)')
if (-not $writabilityCoverageMatch.Success) { Fail-Gate 'index-metadata sem writability_coverage; regenere o indice' }
$writabilityCoverage = $writabilityCoverageMatch.Groups['value'].Value
if ($writabilityCoverage -notin @('complete-in-model', 'partial', 'invalid')) {
  Fail-Gate "writability_coverage invalida: $writabilityCoverage"
}
$expectedRowsMatch = [regex]::Match($indexMetadataText, 'writability_rows_expected\s*[:=]\s*(?<value>\d+)')
$writtenRowsMatch = [regex]::Match($indexMetadataText, 'writability_rows_written\s*[:=]\s*(?<value>\d+)')
$lostRowsMatch = [regex]::Match($indexMetadataText, 'writability_rows_lost\s*[:=]\s*(?<value>\d+)')
if (-not $expectedRowsMatch.Success -or -not $writtenRowsMatch.Success -or -not $lostRowsMatch.Success) {
  Fail-Gate 'metadata de contagem de occurrences de gravabilidade incompleta; regenere o indice'
}
if ([int]$expectedRowsMatch.Groups['value'].Value -ne [int]$writtenRowsMatch.Groups['value'].Value -or
    [int]$lostRowsMatch.Groups['value'].Value -ne 0) {
  Fail-Gate 'materializacao de gravabilidade perdeu occurrences; regenere o indice'
}
$writabilityCoverageWarning = if ($writabilityCoverage -eq 'complete-in-model') {
  $null
} else {
  "Classificacao automatica com cobertura $writabilityCoverage; GATE_OK confirma validade tecnica do indice, nao gravabilidade nem autorizacao de assignment."
}

# 8. assinatura do extrator
if (-not (Test-Path -LiteralPath $ExtractorContractPath -PathType Leaf)) { Fail-Gate "contrato de assinatura do extrator ausente: $ExtractorContractPath" }
. $ExtractorContractPath
$indexMetadataMap = Get-GeneXusKbIntelligenceExtractorSignatureFromIndexMetadataText -IndexMetadataText $indexMetadataText
$extractorCheck = Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata -Metadata $indexMetadataMap
if (-not $extractorCheck.ok) { Fail-Gate $extractorCheck.summary }

$out['extractor_signature_version'] = $extractorCheck.stored.extractor_signature_version
$out['extractor_signature_hash'] = $extractorCheck.stored.extractor_signature_hash
$out['extractor_signature_format'] = $extractorCheck.stored.extractor_signature_format
$out['writabilityCoverage'] = $writabilityCoverage
$out['writabilityCoverageWarning'] = $writabilityCoverageWarning
$out['inventory_validation_status'] = 'OK'

if ($AsJson) {
  [pscustomobject]$out | ConvertTo-Json -Depth 4
} else {
  ('extractor_signature_version: {0}' -f $extractorCheck.stored.extractor_signature_version)
  ('extractor_signature_hash: {0}' -f $extractorCheck.stored.extractor_signature_hash)
  ('extractor_signature_format: {0}' -f $extractorCheck.stored.extractor_signature_format)
  ('writability_coverage: {0}' -f $writabilityCoverage)
  if ($writabilityCoverageWarning) { ('writability_coverage_warning: {0}' -f $writabilityCoverageWarning) }
  'inventory_validation_status: OK'
  'GATE_OK'
}
exit 0

} catch {
  # Excecao fora dos Fail-Gate conhecidos. Sob -AsJson honra o contrato (nunca
  # lanca): emite { status: BLOCK, reason } + exit 1. Em texto, preserva um
  # prefixo BLOCK existente e adiciona-o quando a excecao nao o trouxe.
  if ($AsJson) {
    $out['status'] = 'BLOCK'
    $out['reason'] = ($_.Exception.Message -replace '^BLOCK:\s*', '')
    [pscustomobject]$out | ConvertTo-Json -Depth 4
    exit 1
  }
  $errorMessage = [string]$_.Exception.Message
  if ($errorMessage -cmatch '^BLOCK:\s*') { throw }
  throw ('BLOCK: {0}' -f $errorMessage)
}
