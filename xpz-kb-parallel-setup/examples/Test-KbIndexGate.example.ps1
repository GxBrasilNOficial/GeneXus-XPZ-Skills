#requires -Version 7.4
<#
.SYNOPSIS
Molde do wrapper LOCAL do gate de indice KbIntelligence de uma pasta paralela de KB.

.DESCRIPTION
Wrapper fino: delega toda a logica ao motor compartilhado
`scripts/Test-XpzKbIndexGate.ps1` da base `GeneXus-XPZ-Skills`, injetando os
caminhos locais e repassando -AsJson. Simetrico ao molde de auditoria de setup
(que delega a Test-XpzSetupAudit.ps1).

Contrato de saida herdado do motor:
- Default (texto): emite GATE_OK no sucesso, lanca `BLOCK: <motivo>` no bloqueio.
  Retrocompativel com o consumo por grep (Test-XpzSetupAudit / agentes).
- -AsJson: { status: OK|BLOCK, reason, extractor_signature_*, ... }. Sob -AsJson
  nunca lanca; bloqueio vira { status: BLOCK, reason } + exit 1. Consumido pelo
  gate K9 do orquestrador Invoke-XpzKbParallelPrePushPhase1.ps1.

IMPORTANTE: este e um molde. Ao materializar o wrapper local final, ajustar
`SharedSkillsRoot` para o caminho real da base compartilhada e, se a KB usar nomes
locais proprios de Query/Structure, informa-los nos parametros.

Deve ser o unico ponto de execucao do gate de indice da pasta paralela da KB.

.PARAMETER QueryWrapperPath
Caminho do wrapper local de consulta do indice (default: Query-KbIntelligence.ps1
na mesma pasta deste wrapper).

.PARAMETER StructureWrapperPath
Caminho do wrapper local de verificacao de estrutura (default: Test-KbStructure.ps1
na mesma pasta deste wrapper).

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills` (motor em `scripts/`).

.PARAMETER AsJson
Repassa o modo de contrato estruturado ao motor compartilhado.

.EXAMPLE
& (Join-Path $kbRoot 'scripts\Test-FabricaBrasilKbIndexGate.ps1') -AsJson
#>

param(
    [string]$QueryWrapperPath,
    [string]$StructureWrapperPath,
    [string]$SharedSkillsRoot = 'C:\CAMINHO\PARA\GeneXus-XPZ-Skills',
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $QueryWrapperPath) { $QueryWrapperPath = Join-Path $PSScriptRoot 'Query-KbIntelligence.ps1' }
if (-not $StructureWrapperPath) { $StructureWrapperPath = Join-Path $PSScriptRoot 'Test-KbStructure.ps1' }

$engine = Join-Path $SharedSkillsRoot (Join-Path 'scripts' 'Test-XpzKbIndexGate.ps1')
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) {
    throw "BLOCK: motor compartilhado do gate de indice ausente: $engine"
}

$forward = @{
    RepoRoot             = $repoRoot
    QueryWrapperPath     = $QueryWrapperPath
    StructureWrapperPath = $StructureWrapperPath
}
if ($AsJson) { $forward['AsJson'] = $true }

$global:LASTEXITCODE = $null
& $engine @forward
$lastCommandSucceeded = $?
$lastExitCodeVariable = Get-Variable -Name LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
if ($null -ne $lastExitCodeVariable -and $lastExitCodeVariable.Value -is [int]) {
    exit $lastExitCodeVariable.Value
}
if (-not $lastCommandSucceeded) {
    exit 1
}
exit 0
