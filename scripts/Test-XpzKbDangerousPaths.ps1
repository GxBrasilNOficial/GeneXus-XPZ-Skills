#requires -Version 7.4

<#
.SYNOPSIS
  Gates K1 e K2 da rotina pre-push de pasta paralela de KB (skill
  xpz-kb-parallel-pre-push): detecta paths proibidos no diff git BaseRef..HEAD.

.DESCRIPTION
  Motor compartilhado, agnostico de KB. Os nomes de camada sao parametros com
  defaults iguais aos nomes-padrao da casa (ver README / xpz-sync); o orquestrador
  resolve overrides a partir de kb-parallel-pre-push.config.json e os repassa aqui.

  K1 - pasta descartavel no diff
    A(s) pasta(s) descartavel(eis) (default: Temp/) nunca devem ser versionadas.
    Cobertura defensiva contra `git add Temp/...` acidental. Severidade: block.

  K2 - pasta nativa da KB no diff
    Examina os NOMES de arquivo do intervalo (nivel de path, NAO o conteudo dos
    arquivos): qualquer path do diff cujo segmento bata o padrao da pasta nativa
    da KB GeneXus (default: segmento 'GxModels' em qualquer separador) e terreno
    proibido por contrato. Como git diff --name-only da paths repo-relativos com
    '/', o default casa 'GxModels/' nesse formato e tambem a variante com '\'.
    Assertion defensiva contra symlink ou pasta nativa versionada por engano.
    Severidade: block.

  CONTRATO DE SAIDA: JSON de maquina por padrao no stdout (sem -AsJson, conforme
  a regra da casa para motores novos). Campos: status (ok|block|unknown),
  exitCode, baseRef, repoRoot, range, blockingReasons, gates. -AsText da saida
  humana; -AsJson e tolerado como no-op (JSON ja e o default) para nao quebrar
  invocacao por habito.

  EXIT CODE do motor e informativo (pior status entre os gates): 0 ok, 1 block,
  3 unknown (falha tecnica de git). O orquestrador consome gates[].status no
  JSON, nao o exit code do motor.

.PARAMETER BaseRef
  Referencia git base (default: origin/main).

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual). Usado como
  -C do git para nao depender do cwd.

.PARAMETER TempDirNames
  Nome(s) de pasta descartavel que nunca deve ser versionada (default: Temp).

.PARAMETER NativeKbRootPattern
  Padrao regex que casa um SEGMENTO de path da pasta nativa da KB GeneXus em
  qualquer separador (default casa 'GxModels/' ou 'GxModels\' em qualquer posicao
  do path; git diff --name-only emite paths com '/').

.PARAMETER AsText
  Saida humana em texto em vez do JSON padrao.

.PARAMETER AsJson
  No-op: JSON ja e a saida padrao. Aceito para compatibilidade de invocacao.

.EXAMPLE
  Test-XpzKbDangerousPaths.ps1
  # JSON: avalia K1 e K2 contra origin/main..HEAD na pasta paralela atual

.EXAMPLE
  Test-XpzKbDangerousPaths.ps1 -BaseRef HEAD~10 -AsText
#>
[CmdletBinding()]
param(
  [string]$BaseRef = 'origin/main',
  [string]$RepoRoot = (Get-Location).Path,
  [string[]]$TempDirNames = @('Temp'),
  [string]$NativeKbRootPattern = '(?i)(^|[\\/])GxModels[\\/]',
  [switch]$AsText,
  [switch]$AsJson
)

Set-StrictMode -Version Latest

$range = "$BaseRef..HEAD"

# Normaliza tokens de pasta descartavel: barra invertida -> /, sem barra final,
# sem vazio, deduplicado.
$tempPrefixes = @(
  $TempDirNames |
    ForEach-Object { ($_ -replace '\\', '/').Trim().TrimEnd('/') } |
    Where-Object { $_ -ne '' } |
    Select-Object -Unique |
    ForEach-Object { "$_/" }
)

# git diff com captura de exit code (sem silent-pass): falha tecnica vira status
# unknown, nunca "zero achados".
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
  if ($AsText) { "K1/K2 [UNKNOWN]: $reason" } else { $unknown | ConvertTo-Json -Depth 4 }
  exit 3
}

$k1Hits = @($diffFiles | Where-Object {
  $f = $_
  @($tempPrefixes | Where-Object { $f -like "$_*" }).Count -gt 0
})
$k2Hits = @($diffFiles | Where-Object { $_ -match $NativeKbRootPattern })

$k1 = [pscustomobject]@{
  gate    = 'K1'
  status  = if ($k1Hits.Count -gt 0) { 'block' } else { 'ok' }
  hits    = $k1Hits
  message = if ($k1Hits.Count -gt 0) {
    "$($k1Hits.Count) arquivo(s) em pasta descartavel ($($TempDirNames -join ', ')) no diff -- nunca deve ser versionada"
  } else { "sem toques em pasta descartavel ($($TempDirNames -join ', '))" }
}

$k2 = [pscustomobject]@{
  gate    = 'K2'
  status  = if ($k2Hits.Count -gt 0) { 'block' } else { 'ok' }
  hits    = $k2Hits
  message = if ($k2Hits.Count -gt 0) {
    "$($k2Hits.Count) path(s) batendo o padrao da pasta nativa da KB ($NativeKbRootPattern) no diff -- terreno proibido"
  } else { "sem paths da pasta nativa da KB ($NativeKbRootPattern) no diff" }
}

$overall = if ($k1.status -eq 'block' -or $k2.status -eq 'block') { 'block' } else { 'ok' }
$blockingReasons = @(@($k1, $k2) | Where-Object { $_.status -eq 'block' } | ForEach-Object { $_.message })
$exitCode = if ($overall -eq 'block') { 1 } else { 0 }

$result = [pscustomobject]@{
  status          = $overall
  exitCode        = $exitCode
  baseRef         = $BaseRef
  repoRoot        = $RepoRoot
  range           = $range
  blockingReasons = $blockingReasons
  gates           = @($k1, $k2)
}

if ($AsText) {
  "Range: $range"
  ('K1 [{0}]: {1}' -f $k1.status.ToUpper(), $k1.message)
  if ($k1.hits.Count -gt 0) { $k1.hits | ForEach-Object { "    $_" } }
  ('K2 [{0}]: {1}' -f $k2.status.ToUpper(), $k2.message)
  if ($k2.hits.Count -gt 0) { $k2.hits | ForEach-Object { "    $_" } }
  ""
  "Overall: $($overall.ToUpper())"
} else {
  $result | ConvertTo-Json -Depth 5
}

exit $exitCode
