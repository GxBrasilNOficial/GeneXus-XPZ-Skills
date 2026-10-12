#requires -Version 7.4

<#
.SYNOPSIS
  Gates K3 e K4 da rotina pre-push de pasta paralela de KB (skill
  xpz-kb-parallel-pre-push): detecta toques anomalos em camadas derivadas/oficiais
  da KB no intervalo git BaseRef..HEAD.

.DESCRIPTION
  Motor compartilhado, agnostico de KB. Nomes de camada sao parametros com
  defaults iguais aos nomes-padrao da casa; o orquestrador resolve overrides a
  partir de kb-parallel-pre-push.config.json.

  K3 - pasta do indice derivado no diff (default: KbIntelligence/)
    O SQLite e os relatorios de validacao do indice sao gitignored. Qualquer
    arquivo dessa pasta no diff implica `git add -f` deliberado. Severidade: warn.

  K4 - acervo oficial no diff sem evidencia de sync (default: ObjetosDaKbEmXml/)
    O snapshot oficial so deveria mudar via fluxo de sync, que tambem atualiza o
    arquivo de metadados (default: kb-source-metadata.md, campo
    last_xpz_materialization_run_at). Se o intervalo toca o acervo mas NENHUM
    commit do intervalo toca o metadata, evidencia fraca de sync. Severidade:
    warn. Heuristica por intervalo (aceita N commits de sync agrupados, contanto
    que ao menos um atualize o metadata).

  CONTRATO DE SAIDA: JSON de maquina por padrao no stdout. Campos: status
  (ok|warn|unknown), exitCode, baseRef, repoRoot, range, gates. -AsText da saida
  humana; -AsJson e no-op (JSON ja e o default).

  EXIT CODE do motor e informativo: 0 ok, 2 warn, 3 unknown (falha de git). O
  orquestrador consome gates[].status, nao o exit code.

.PARAMETER BaseRef
  Referencia git base (default: origin/main).

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual).

.PARAMETER IndexDirName
  Nome da pasta do indice derivado (default: KbIntelligence).

.PARAMETER AcervoDirName
  Nome da pasta do acervo oficial (default: ObjetosDaKbEmXml).

.PARAMETER MetadataFileName
  Nome do arquivo de metadados de materializacao (default: kb-source-metadata.md).

.PARAMETER AsText
  Saida humana em texto em vez do JSON padrao.

.PARAMETER AsJson
  No-op: JSON ja e a saida padrao.

.EXAMPLE
  Test-XpzKbLayerDiff.ps1
#>
[CmdletBinding()]
param(
  [string]$BaseRef = 'origin/main',
  [string]$RepoRoot = (Get-Location).Path,
  [string]$IndexDirName = 'KbIntelligence',
  [string]$AcervoDirName = 'ObjetosDaKbEmXml',
  [string]$MetadataFileName = 'kb-source-metadata.md',
  [switch]$AsText,
  [switch]$AsJson
)

Set-StrictMode -Version Latest

$range = "$BaseRef..HEAD"

function ConvertTo-DirPrefix {
  param([string]$Name)
  $clean = ($Name -replace '\\', '/').Trim().TrimEnd('/')
  return "$clean/"
}
$indexPrefix = ConvertTo-DirPrefix $IndexDirName
$acervoPrefix = ConvertTo-DirPrefix $AcervoDirName
$metadataName = ($MetadataFileName -replace '\\', '/').Trim()

$diffFiles = @(git -C $RepoRoot diff --name-only $range 2>$null)
$gitExit = $LASTEXITCODE
if ($gitExit -ne 0) {
  $reason = "git diff falhou (exit $gitExit) para range '$range' em '$RepoRoot' -- BaseRef inexistente ou repo invalido?"
  $unknown = [pscustomobject]@{
    status          = 'unknown'
    exitCode        = 3
    baseRef         = $BaseRef
    repoRoot        = $RepoRoot
    range           = $range
    blockingReasons = @($reason)
    gates           = @()
  }
  if ($AsText) { "K3/K4 [UNKNOWN]: $reason" } else { $unknown | ConvertTo-Json -Depth 4 }
  exit 3
}

$k3Hits = @($diffFiles | Where-Object { $_ -like "$indexPrefix*" })
$acervoHits = @($diffFiles | Where-Object { $_ -like "$acervoPrefix*" })

$metadataTouchedInRange = $false
if ($acervoHits.Count -gt 0) {
  $commitsInRange = @(git -C $RepoRoot log --format='%H' $range 2>$null)
  foreach ($sha in $commitsInRange) {
    $touched = @(git -C $RepoRoot show --name-only --format='' $sha 2>$null)
    if ($touched -contains $metadataName) {
      $metadataTouchedInRange = $true
      break
    }
  }
}

$k3 = [pscustomobject]@{
  gate    = 'K3'
  status  = if ($k3Hits.Count -gt 0) { 'warn' } else { 'ok' }
  hits    = $k3Hits
  message = if ($k3Hits.Count -gt 0) {
    "$($k3Hits.Count) arquivo(s) de $IndexDirName/ no diff -- camada derivada regeneravel, esperado gitignored"
  } else { "sem toques em $IndexDirName/" }
}

$k4Status = if ($acervoHits.Count -eq 0) { 'ok' } elseif ($metadataTouchedInRange) { 'ok' } else { 'warn' }
$k4 = [pscustomobject]@{
  gate                   = 'K4'
  status                 = $k4Status
  acervoHits             = $acervoHits.Count
  metadataTouchedInRange = $metadataTouchedInRange
  message                = switch ($k4Status) {
    'ok' {
      if ($acervoHits.Count -eq 0) { "sem toques em $AcervoDirName/" }
      else { "$($acervoHits.Count) arquivo(s) em $AcervoDirName/, $metadataName atualizado no intervalo -- sync oficial plausivel" }
    }
    'warn' { "$($acervoHits.Count) arquivo(s) em $AcervoDirName/ sem nenhum commit do intervalo tocar $metadataName -- sync oficial nao evidente" }
  }
}

$overall = if ($k3.status -eq 'warn' -or $k4.status -eq 'warn') { 'warn' } else { 'ok' }
$exitCode = if ($overall -eq 'warn') { 2 } else { 0 }

$result = [pscustomobject]@{
  status          = $overall
  exitCode        = $exitCode
  baseRef         = $BaseRef
  repoRoot        = $RepoRoot
  range           = $range
  blockingReasons = @()
  gates           = @($k3, $k4)
}

if ($AsText) {
  "Range: $range"
  ('K3 [{0}]: {1}' -f $k3.status.ToUpper(), $k3.message)
  if ($k3.hits.Count -gt 0) { $k3.hits | ForEach-Object { "    $_" } }
  ('K4 [{0}]: {1}' -f $k4.status.ToUpper(), $k4.message)
  ""
  "Overall: $($overall.ToUpper())"
} else {
  $result | ConvertTo-Json -Depth 5
}

exit $exitCode
