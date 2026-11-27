#requires -Version 7.4

<#
.SYNOPSIS
  Filtro F1 da Fase 2b da rotina pre-push de pasta paralela de KB (skill
  xpz-kb-parallel-pre-push): seleciona XMLs do acervo no intervalo BaseRef..HEAD
  e compara o checksum em BaseRef com o do arquivo atual no disco.

.DESCRIPTION
  Motor compartilhado, agnostico de KB. Por padrao, usa git diff --name-only no
  intervalo BaseRef..HEAD para selecionar caminhos; para cada caminho, le o
  checksum em BaseRef (git show) e o do arquivo atual no disco. Classifica cada
  XML como SAME (checksum identico -- sugere re-export, mas nao prova conteudo
  igual; uma cascata de rename pode alterar conteudo com o checksum igual),
  DIFF, NEW, DELETED ou NO_CHECKSUM (checksum ausente nos dois lados). Uma
  alteracao local em caminho selecionado pode afetar o resultado mesmo com HEAD
  inalterado. E classificador puro: nao bloqueia, so rotula para triagem.

  ATENCAO METODOLOGICA (checksum): em XMLs GeneXus exportados pela IDE o checksum
  e ATRIBUTO do elemento raiz <Object> (checksum="..."), NAO tag <Checksum>.
  Implementacoes que buscam tag retornam NONE dos dois lados, dando SAME falso em
  100% do universo. Este helper canoniza a leitura correta.

  ATENCAO METODOLOGICA (cabeca-detalhe): SAME no ARQUIVO X NAO prova que o
  arquivo nao mudou nem implica que a cabeca/objeto associado a X esteja fora de
  escopo. Um objeto cabeca pode ter checksum inalterado enquanto seu detalhe
  (outro arquivo) mudou e carrega dependentes. Descartar SAME cedo e aceitavel
  para a triagem de regime, mas o analista NAO pode concluir, so do SAME, que a
  cabeca esta fora do raio de impacto. A Fase 2a/2b trata isso (ver satelite
  fase2a-estrutural.md).

  CONTRATO DE SAIDA: JSON de maquina por padrao no stdout. Campos: status
  (ok|unknown), exitCode, baseRef, repoRoot, range, results[]. -AsText da saida
  humana; -AsJson e no-op (JSON ja e o default).

  EXIT CODE: 0 ok (classificacao concluida), 3 unknown (falha de git). F1 nunca
  bloqueia.

.PARAMETER BaseRef
  Referencia git para comparar (default: origin/main).

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual).

.PARAMETER AcervoDirName
  Nome da pasta do acervo oficial (default: ObjetosDaKbEmXml).

.PARAMETER Files
  Lista explicita de arquivos. Se omitida, usa git diff --name-only no intervalo
  BaseRef..HEAD para selecionar os XML do acervo a classificar (lado novo = disco).

.PARAMETER AsText
  Saida humana em texto em vez do JSON padrao.

.PARAMETER AsJson
  No-op: JSON ja e a saida padrao.

.EXAMPLE
  Compare-XpzChecksums.ps1
#>
[CmdletBinding()]
param(
  [string]$BaseRef = 'origin/main',
  [string]$RepoRoot = (Get-Location).Path,
  [string]$AcervoDirName = 'ObjetosDaKbEmXml',
  [string[]]$Files,
  [switch]$AsText,
  [switch]$AsJson
)

Set-StrictMode -Version Latest

$range = "$BaseRef..HEAD"
$acervoDir = ($AcervoDirName -replace '\\', '/').Trim().TrimEnd('/')

if (-not $Files) {
  $diffOutput = @(git -C $RepoRoot diff --name-only $range -- "$acervoDir/*.xml" 2>$null)
  $gitExit = $LASTEXITCODE
  if ($gitExit -ne 0) {
    $reason = "git diff falhou (exit $gitExit) para range '$range' em '$RepoRoot' -- BaseRef inexistente ou repo invalido?"
    $unknown = [pscustomobject]@{
      status   = 'unknown'
      exitCode = 3
      baseRef  = $BaseRef
      repoRoot = $RepoRoot
      range    = $range
      results  = @()
      reason   = $reason
    }
    if ($AsText) { "F1 [UNKNOWN]: $reason" } else { $unknown | ConvertTo-Json -Depth 4 }
    exit 3
  }
  $Files = @($diffOutput | Where-Object { $_ -match '\.xml$' -and $_ -notmatch 'AGENTS\.md' })
}

$results = @(foreach ($f in $Files) {
  $oldXml = git -C $RepoRoot show "${BaseRef}:$f" 2>$null | Out-String
  $absPath = if ([System.IO.Path]::IsPathRooted($f)) { $f } else { Join-Path $RepoRoot $f }
  $newXml = if (Test-Path -LiteralPath $absPath) { Get-Content -LiteralPath $absPath -Raw } else { '' }

  $oldChk = if ($oldXml -match 'checksum="([^"]+)"') { $Matches[1] } else { $null }
  $newChk = if ($newXml -match 'checksum="([^"]+)"') { $Matches[1] } else { $null }

  $status = switch ($true) {
    ($null -eq $oldChk -and $null -eq $newChk) { 'NO_CHECKSUM' ; break }
    ($null -eq $oldChk -and $null -ne $newChk) { 'NEW' ; break }
    ($null -ne $oldChk -and $null -eq $newChk) { 'DELETED' ; break }
    ($oldChk -eq $newChk)                      { 'SAME' ; break }
    default                                    { 'DIFF' }
  }

  [pscustomobject]@{
    status      = $status
    path        = $f
    oldChecksum = $oldChk
    newChecksum = $newChk
  }
})

$result = [pscustomobject]@{
  status   = 'ok'
  exitCode = 0
  baseRef  = $BaseRef
  repoRoot = $RepoRoot
  range    = $range
  results  = $results
}

if ($AsText) {
  foreach ($r in $results) { "{0,-8} {1}" -f $r.status, $r.path }
} else {
  $result | ConvertTo-Json -Depth 4
}

exit 0
