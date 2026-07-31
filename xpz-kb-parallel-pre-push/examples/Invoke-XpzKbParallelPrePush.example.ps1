#requires -Version 7.4
<#
.SYNOPSIS
Molde do wrapper LOCAL da rotina pre-push de uma pasta paralela de KB.

.DESCRIPTION
Wrapper fino: delega toda a logica ao motor compartilhado
`scripts/Invoke-XpzKbParallelPrePushPhase1.ps1` da base `GeneXus-XPZ-Skills`,
injetando a raiz local da pasta paralela (-RepoRoot) e repassando os parametros.
Simetrico aos demais wrappers locais (que delegam aos motores compartilhados).

Contrato de saida herdado do motor:
- JSON de maquina por padrao no stdout (campos pushReadiness, fetchStatus,
  configFound, commitsAhead, commitsBehind, gates[]). -AsText da saida humana.
- EXIT: 0 ready, 2 warn, 1 blocked. `unknown` em qualquer gate consolida em
  blocked (fail-closed).

IMPORTANTE: este e um molde. Ao materializar o wrapper local final, ajustar
`SharedSkillsRoot` para o caminho real da base compartilhada.

Deve ser o unico ponto de execucao da rotina pre-push da pasta paralela da KB.

.PARAMETER BaseRef
Referencia git base (default: origin/main); intervalo avaliado BaseRef..HEAD.

.PARAMETER ConfigPath
Caminho do kb-parallel-pre-push.config.json (default: na raiz da pasta paralela).

.PARAMETER SkipFetch
Pula git fetch origin; usa a BaseRef local conscientemente.

.PARAMETER AsText
Saida humana em texto em vez do JSON padrao.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills` (motor em `scripts/`).

.EXAMPLE
& (Join-Path $kbRoot 'scripts\Invoke-FabricaBrasilPrePush.ps1') -AsText
#>

param(
    [string]$BaseRef = 'origin/main',
    [string]$ConfigPath,
    [switch]$SkipFetch,
    [switch]$AsText,
    [string]$SharedSkillsRoot = 'C:\CAMINHO\PARA\GeneXus-XPZ-Skills'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Raiz da pasta paralela da KB = pasta-mae de scripts/ (onde este wrapper vive).
$repoRoot = Split-Path -Parent $PSScriptRoot

$engine = Join-Path $SharedSkillsRoot (Join-Path 'scripts' 'Invoke-XpzKbParallelPrePushPhase1.ps1')
if (-not (Test-Path -LiteralPath $engine -PathType Leaf)) {
    throw "BLOCK: motor compartilhado da rotina pre-push ausente: $engine"
}

$forward = @{
    RepoRoot = $repoRoot
    BaseRef  = $BaseRef
}
if ($ConfigPath) { $forward['ConfigPath'] = $ConfigPath }
if ($SkipFetch)  { $forward['SkipFetch']  = $true }
if ($AsText)     { $forward['AsText']     = $true }

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
