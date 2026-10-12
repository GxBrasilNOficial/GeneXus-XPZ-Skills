#requires -Version 7.4

<#
.SYNOPSIS
  Fase 2a parcial (mecanicamente verificavel) da rotina pre-push de pasta paralela
  de KB (skill xpz-kb-parallel-pre-push): valida higiene estrutural das pastas de
  geracao e de pacotes de importacao.

.DESCRIPTION
  Motor compartilhado, agnostico de KB. Nomes de pasta sao parametros com defaults
  iguais aos nomes-padrao da casa. Filesystem-only (nao usa git).

  Cheque 1 - subpasta de frente deve seguir NomeCurto_GUID_YYYYMMDD (regra de
    xpz-kb-parallel-setup). NomeCurto pode conter underscores (frentes derivadas
    como `CriaAnimalRefatora_..._20260520_ba03` sao legitimas); GUID e YYYYMMDD
    ancoram o final. Severidade: warn.

  Cheque 2 - pacote <frenteName>_<nn>.{import_file.xml,xpz} deve ter <frenteName>
    existindo como subpasta-fonte de frente. Pacote orfao = sem subpasta-fonte
    rastreavel. Severidade: warn.

  Ambos warn (nao bloqueiam) porque podem ter justificativa legitima (frente
  deletada apos import bem-sucedido, frente experimental fora do padrao); o
  usuario decide aceitar ou corrigir.

  CONTRATO DE SAIDA: JSON de maquina por padrao no stdout. Campos: Kind
  ('xpz-frente-hygiene-result'), SchemaVersion (1), status (ok|warn), exitCode,
  repoRoot, frentesDir, pacotesDir (caminhos resolvidos/normalizados),
  frentesValidas, frentesNaoConformes[], pacotesOk, pacotesOrfaos[],
  pacotesNaoPadronizados[]. -AsText da saida humana; -AsJson e no-op (JSON ja e o
  default).

  CONSUMIDOR: scripts/Remove-XpzKbFrenteHygieneFindings.ps1 (executor de faxina)
  consome este JSON como fonte de verdade. Renomear/retipar campos aqui quebra o
  contrato; o lockstep e travado por Test-XpzKbFrenteHygieneCleanupSelfTest.ps1
  (asserta tipos + caso fixture end-to-end).

  EXIT CODE: 0 ok, 2 warn. Fase 2a nunca bloqueia push.

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual).

.PARAMETER FrentesDirName
  Nome da pasta de geracao por frente (default:
  ObjetosGeradosParaImportacaoNaKbNoGenexus).

.PARAMETER PacotesDirName
  Nome da pasta de pacotes (default: PacotesGeradosParaImportacaoNaKbNoGenexus).

.PARAMETER AsText
  Saida humana em texto em vez do JSON padrao.

.PARAMETER AsJson
  No-op: JSON ja e a saida padrao.

.EXAMPLE
  Test-XpzKbFrenteHygiene.ps1
#>
[CmdletBinding()]
param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$FrentesDirName = 'ObjetosGeradosParaImportacaoNaKbNoGenexus',
  [string]$PacotesDirName = 'PacotesGeradosParaImportacaoNaKbNoGenexus',
  [switch]$AsText,
  [switch]$AsJson
)

Set-StrictMode -Version Latest

$frentesDir = Join-Path $RepoRoot (($FrentesDirName -replace '\\', '/').Trim().TrimEnd('/'))
$pacotesDir = Join-Path $RepoRoot (($PacotesDirName -replace '\\', '/').Trim().TrimEnd('/'))

# Caminhos resolvidos/normalizados (absolutos) para o contrato de saida. GetFullPath
# normaliza sem exigir existencia (Resolve-Path falharia em pasta inexistente).
$frentesDirResolved = [System.IO.Path]::GetFullPath($frentesDir)
$pacotesDirResolved = [System.IO.Path]::GetFullPath($pacotesDir)

# Padrao: <NomeCurto>_<GUID>_<YYYYMMDD>; NomeCurto pode conter underscores
$frentePattern = [regex]::new(
  '^(?<nome>.+)_(?<guid>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})_(?<data>\d{8})$',
  [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

# Cheque 1: nomes de frente
$frentesNaoConformes = @()
$frentesValidas = @()
if (Test-Path -LiteralPath $frentesDir) {
  $subpastas = Get-ChildItem -LiteralPath $frentesDir -Directory -ErrorAction SilentlyContinue
  foreach ($sp in $subpastas) {
    if ($frentePattern.IsMatch($sp.Name)) { $frentesValidas += $sp.Name }
    else { $frentesNaoConformes += $sp.Name }
  }
}

# Cheque 2: pacotes orfaos
$pacoteFilePattern = [regex]::new('^(?<frente>.+)_\d+\.(import_file\.xml|xpz)$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$pacotesOrfaos = @()
$pacotesOk = 0
$pacotesNaoPadronizados = @()
if (Test-Path -LiteralPath $pacotesDir) {
  $arquivos = @(Get-ChildItem -LiteralPath $pacotesDir -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '\.(import_file\.xml|xpz)$' })
  foreach ($a in $arquivos) {
    $m = $pacoteFilePattern.Match($a.Name)
    if (-not $m.Success) { $pacotesNaoPadronizados += $a.Name; continue }
    $frenteEsperada = $m.Groups['frente'].Value
    if ($frentesValidas -contains $frenteEsperada -or $frentesNaoConformes -contains $frenteEsperada) {
      $pacotesOk++
    } else {
      $pacotesOrfaos += [pscustomobject]@{ pacote = $a.Name; frenteEsperada = $frenteEsperada }
    }
  }
}

$cheque1Status = if ($frentesNaoConformes.Count -gt 0) { 'warn' } else { 'ok' }
$cheque2Status = if ($pacotesOrfaos.Count -gt 0 -or $pacotesNaoPadronizados.Count -gt 0) { 'warn' } else { 'ok' }
$overall = if ($cheque1Status -eq 'warn' -or $cheque2Status -eq 'warn') { 'warn' } else { 'ok' }
$exitCode = if ($overall -eq 'warn') { 2 } else { 0 }

$result = [pscustomobject]@{
  Kind                   = 'xpz-frente-hygiene-result'
  SchemaVersion          = 1
  status                 = $overall
  exitCode               = $exitCode
  repoRoot               = $RepoRoot
  frentesDir             = $frentesDirResolved
  pacotesDir             = $pacotesDirResolved
  frentesValidas         = $frentesValidas.Count
  frentesNaoConformes    = @($frentesNaoConformes)
  pacotesOk              = $pacotesOk
  pacotesOrfaos          = @($pacotesOrfaos)
  pacotesNaoPadronizados = @($pacotesNaoPadronizados)
}

if ($AsText) {
  "=== Fase 2a parcial: higiene de frente/pacote ==="
  "Frentes validas: $($frentesValidas.Count)"
  if ($frentesNaoConformes.Count -gt 0) {
    "Frentes NAO conformes ($($frentesNaoConformes.Count)) -- esperado NomeCurto_GUID_YYYYMMDD:"
    $frentesNaoConformes | ForEach-Object { "    $_" }
  } else { "Frentes nao conformes: 0" }
  "Pacotes OK: $pacotesOk"
  if ($pacotesOrfaos.Count -gt 0) {
    "Pacotes orfaos ($($pacotesOrfaos.Count)) -- sem subpasta-fonte:"
    $pacotesOrfaos | ForEach-Object { "    $($_.pacote)  (esperava frente: $($_.frenteEsperada))" }
  } else { "Pacotes orfaos: 0" }
  if ($pacotesNaoPadronizados.Count -gt 0) {
    "Pacotes fora do padrao <frenteName>_<nn>.{import_file.xml,xpz} ($($pacotesNaoPadronizados.Count)):"
    $pacotesNaoPadronizados | ForEach-Object { "    $_" }
  }
  ""
  "Overall: $($overall.ToUpper())"
} else {
  $result | ConvertTo-Json -Depth 4
}

exit $exitCode
