#requires -Version 7.4

<#
.SYNOPSIS
  Executor de faxina da Fase 2a da rotina pre-push de pasta paralela de KB
  (skill xpz-kb-parallel-pre-push). Remove frentes nao conformes e pacotes orfaos
  flagados pelo motor de DIAGNOSTICO Test-XpzKbFrenteHygiene.ps1 (SchemaVersion 2).

.DESCRIPTION
  FONTE DE VERDADE UNICA = o motor. Este executor nao reimplementa o matching
  pacote<->frente: usa o campo pacotesVinculados do motor para mostrar a cascata.

  FLUXO EM DUAS ETAPAS (obrigatorio):
    1) Dry-run (sem -Apply): monta o plano (frentes, pacotes, sidecars, exclusoes,
       metodo por item). Com -PlanPath grava o plano em arquivo novo, fora de
       frentesDir e pacotesDir. Nada e apagado.
    2) -Apply -JsonPath <plano salvo>: recalcula o plano; se diferir do salvo, para
       sem remover nada. Se igual, executa exatamente a lista salva, numa passada.

  METODO PADRAO: envio a Lixeira do Windows (RecycleOption.SendToRecycleBin).
    -Backup <dir> -RunStamp <id>: move-aside no mesmo volume (nao apaga).
    -Permanente: apagamento definitivo (explicito). -Backup e -Permanente sao
    mutuamente exclusivos.
  Pre-condicoes do metodo Lixeira (verificadas antes da primeira acao): sessao nao
  elevada; volume fixo local; NukeOnDelete = 0 explicito; MaxCapacity legivel; lista
  inteira cabe no limite descontando a ocupacao do usuario atual.
  Verificacao apos cada envio: caminho original sumiu; registro $I novo com esse
  caminho e tamanho; par $R presente. Falha -> hard-stop, fila parada.

  STATUS (um de): clean | findings | whatif | blocked | applied-clean |
  applied-with-skips | hard-stop. EXIT: 0 clean/whatif/applied-clean; 2 findings;
  3 applied-with-skips; 1 blocked/hard-stop. Automacao deve ler status.

  LOCKSTEP: consumidor do contrato de Test-XpzKbFrenteHygiene.ps1 (SchemaVersion 2);
  travado por Test-XpzKbFrenteHygieneCleanupSelfTest.ps1.

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual).
.PARAMETER FrentesDirName
  Pasta de geracao por frente (default: ObjetosGeradosParaImportacaoNaKbNoGenexus).
.PARAMETER PacotesDirName
  Pasta de pacotes (default: PacotesGeradosParaImportacaoNaKbNoGenexus).
.PARAMETER Scope
  Frentes | Pacotes | Ambos (default Ambos).
.PARAMETER Apply
  Executa a remocao. Exige -JsonPath.
.PARAMETER PlanPath
  (so dry-run) grava o plano em arquivo novo, fora das pastas-alvo.
.PARAMETER JsonPath
  (so -Apply) plano salvo pelo dry-run com -PlanPath.
.PARAMETER Permanente
  Apagamento definitivo em vez de Lixeira. Nao combina com -Backup.
.PARAMETER Backup
  Diretorio de backup (move-aside), fora das pastas-alvo, mesmo volume. Requer -RunStamp.
.PARAMETER RunStamp
  Carimbo unico da execucao para o subdiretorio de backup.
.PARAMETER ExcludeFrente
  Nomes exatos de frentes a preservar.
.PARAMETER ExcludePacote
  Nomes exatos de pacotes a preservar.
.PARAMETER EnginePath
  Caminho do motor (default: Test-XpzKbFrenteHygiene.ps1 irmao deste script).
.PARAMETER AsText
  Saida humana resumida no stdout, em vez do JSON.

.EXAMPLE
  Remove-XpzKbFrenteHygieneFindings.ps1 -RepoRoot C:\kb -PlanPath C:\temp\plano.json
.EXAMPLE
  Remove-XpzKbFrenteHygieneFindings.ps1 -RepoRoot C:\kb -Apply -JsonPath C:\temp\plano.json
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$FrentesDirName = 'ObjetosGeradosParaImportacaoNaKbNoGenexus',
  [string]$PacotesDirName = 'PacotesGeradosParaImportacaoNaKbNoGenexus',
  [ValidateSet('Frentes', 'Pacotes', 'Ambos')]
  [string]$Scope = 'Ambos',
  [switch]$Apply,
  [string]$PlanPath,
  [string]$JsonPath,
  [switch]$Permanente,
  [string]$Backup,
  [string]$RunStamp,
  [string[]]$ExcludeFrente = @(),
  [string[]]$ExcludePacote = @(),
  [string]$EnginePath,
  [switch]$AsText
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $EnginePath) { $EnginePath = Join-Path $PSScriptRoot 'Test-XpzKbFrenteHygiene.ps1' }

$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:reparseAttr = [System.IO.FileAttributes]::ReparsePoint
$script:sep = [System.IO.Path]::DirectorySeparatorChar
$script:blockers = [System.Collections.Generic.List[string]]::new()
$script:items = @()
$script:exclusions = @()
$script:actionsDone = 0
$script:backupRoot = $null
$script:doFrentes = ($Scope -eq 'Frentes' -or $Scope -eq 'Ambos')
$script:doPacotes = ($Scope -eq 'Pacotes' -or $Scope -eq 'Ambos')
$script:method = if ($Permanente) { 'permanent' } elseif ($Backup) { 'backup' } else { 'recycle' }

function Write-Human { param([string]$Text) [Console]::Error.WriteLine($Text) }
function Get-Canon { param([string]$Path) return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\', '/') }

function Test-PathsEqual {
  param([string]$A, [string]$B)
  return [string]::Equals((Get-Canon $A), (Get-Canon $B), [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-IsUnder {
  param([string]$Child, [string]$Parent)
  return (Get-Canon $Child).StartsWith((Get-Canon $Parent) + $script:sep, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-IsReparse {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $it = Get-Item -LiteralPath $Path -Force
  return (($it.Attributes -band $script:reparseAttr) -ne 0)
}

# Pre-varredura sem seguir links: $true se o root OU qualquer descendente for reparse.
function Test-TreeHasReparse {
  param([string]$Root)
  if (Test-IsReparse $Root) { return $true }
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $false }
  foreach ($c in (Get-ChildItem -LiteralPath $Root -Force)) {
    if (($c.Attributes -band $script:reparseAttr) -ne 0) { return $true }
    if ($c.PSIsContainer -and (Test-TreeHasReparse $c.FullName)) { return $true }
  }
  return $false
}

# Reparse em qualquer componente de Base..Leaf (inclusive).
function Test-ChainHasReparse {
  param([string]$Base, [string]$Leaf)
  $b = Get-Canon $Base
  $cur = Get-Canon $Leaf
  while ($true) {
    if (Test-IsReparse $cur) { return $true }
    if ([string]::Equals($cur, $b, [System.StringComparison]::OrdinalIgnoreCase)) { break }
    $parent = [System.IO.Path]::GetDirectoryName($cur)
    if ([string]::IsNullOrEmpty($parent) -or $parent.Length -lt $b.Length) { break }
    $cur = $parent
  }
  return $false
}

function Get-Prop {
  param($Obj, [string]$Name)
  if ($null -eq $Obj) { return $null }
  $pp = $Obj.PSObject.Properties[$Name]
  if ($null -eq $pp) { return $null }
  return $pp.Value
}

function Get-TreeStats {
  param([string]$Path)
  if (Test-Path -LiteralPath $Path -PathType Container) {
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force)
    $bytes = [int64]0
    $max = [int64]0
    foreach ($f in $files) {
      $bytes += [int64]$f.Length
      if ($f.LastWriteTimeUtc.Ticks -gt $max) { $max = $f.LastWriteTimeUtc.Ticks }
    }
    return [pscustomobject]@{ bytes = $bytes; files = [int]$files.Count; mtimeMaxTicks = $max }
  }
  $it = Get-Item -LiteralPath $Path -Force
  return [pscustomobject]@{ bytes = [int64]$it.Length; files = 1; mtimeMaxTicks = $it.LastWriteTimeUtc.Ticks }
}

# Digest dos caminhos relativos (arquivos e pastas), ordinal; detecta rename e pasta vazia.
function Get-TreePathsHash {
  param([string]$Path)
  $base = Get-Canon $Path
  if (Test-Path -LiteralPath $Path -PathType Container) {
    $entries = @(Get-ChildItem -LiteralPath $Path -Recurse -Force | ForEach-Object {
      $rel = $_.FullName.Substring($base.Length).TrimStart('\', '/')
      if ($_.PSIsContainer) { $rel + '/' } else { $rel }
    })
  }
  else { $entries = @((Get-Item -LiteralPath $Path -Force).Name) }
  $arr = [string[]]$entries
  [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
  $text = (($arr -join "`n") + "`n")
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $h = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text)) } finally { $sha.Dispose() }
  return ([System.BitConverter]::ToString($h) -replace '-', '').ToLowerInvariant()
}

function Get-TreeBytes {
  param([string]$Path)
  return [int64](Get-TreeStats -Path $Path).bytes
}

# Remocao bottom-up sem -Recurse; recusa reparse point em cada item antes de remover.
function Remove-DirBottomUp {
  param([string]$Dir)
  $rootItem = Get-Item -LiteralPath $Dir -Force
  if (($rootItem.Attributes -band $script:reparseAttr) -ne 0) { throw "reparse point na raiz da remocao: $Dir" }
  $ordered = @(Get-ChildItem -LiteralPath $Dir -Force -Recurse) | Sort-Object { $_.FullName.Length } -Descending
  foreach ($i in $ordered) {
    if (($i.Attributes -band $script:reparseAttr) -ne 0) { throw "reparse point durante a remocao: $($i.FullName)" }
    Remove-Item -LiteralPath $i.FullName -Force
  }
  Remove-Item -LiteralPath $Dir -Force
}

# Arquivos bloqueados por outro processo (leitura exclusiva falha). Retorna lista de caminhos.
function Get-LockedFiles {
  param([string]$Path)
  $locked = @()
  $targets = if (Test-Path -LiteralPath $Path -PathType Container) { @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force) } else { @(Get-Item -LiteralPath $Path -Force) }
  foreach ($f in $targets) {
    try {
      $fs = [System.IO.File]::Open($f.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
      $fs.Close()
    }
    catch { $locked += $f.FullName }
  }
  return $locked
}

# Politicas globais que tornam a Lixeira inutilizavel (retorna motivo ou $null).
function Test-RecycleGlobalPolicy {
  foreach ($k in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer')) {
    if (Test-Path -LiteralPath $k) {
      $p = Get-ItemProperty -LiteralPath $k
      if ($null -ne $p.PSObject.Properties['NoRecycleFiles'] -and [int]$p.NoRecycleFiles -eq 1) { return "politica NoRecycleFiles ativa ($k)" }
    }
  }
  $g = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket'
  if (Test-Path -LiteralPath $g) {
    $p = Get-ItemProperty -LiteralPath $g
    if ($null -ne $p.PSObject.Properties['NukeOnDelete'] -and [int]$p.NukeOnDelete -ne 0) { return 'NukeOnDelete global ativo' }
  }
  return $null
}

# --- Motor (fonte de verdade) -------------------------------------------------
function Invoke-HygieneEngine {
  # Leitura pura: -WhatIf nao deve afetar a captura do motor (redirecao e temporario).
  $WhatIfPreference = $false
  $errFile = [System.IO.Path]::GetTempFileName()
  try {
    $out = & pwsh -NoProfile -File $EnginePath -RepoRoot $RepoRoot -FrentesDirName $FrentesDirName -PacotesDirName $PacotesDirName 2>$errFile
    $code = $LASTEXITCODE
    $errTxt = Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue
  }
  finally { Remove-Item -LiteralPath $errFile -Force -WhatIf:$false -ErrorAction SilentlyContinue }
  if ($errTxt -and $errTxt.Trim()) { Write-Human ("motor: " + $errTxt.Trim()) }
  if ($code -ne 0 -and $code -ne 2) { throw "BLOCK: motor de diagnostico falhou (exit $code)." }
  $json = ($out | Out-String | ConvertFrom-Json)
  if ((Get-Prop $json 'SchemaVersion') -ne 2) { throw "BLOCK: motor com SchemaVersion incompativel (esperado 2)." }
  return $json
}

# Resolve o caminho fisico de um item flagado, com checagens fisicas (sem matching).
function Resolve-Item {
  param([string]$Name, [string]$Kind)
  $baseDir = if ($Kind -eq 'frente') { $script:frentesDirCanon } else { $script:pacotesDirCanon }
  if ($Name -match '[\\/:]' -or $Name -eq '..' -or $Name -eq '.') {
    return [pscustomobject]@{ ok = $false; reason = 'unsafe-name'; path = $null }
  }
  $canon = Get-Canon (Join-Path $baseDir $Name)
  $parent = [System.IO.Path]::GetDirectoryName($canon)
  if (-not [string]::Equals($parent, $baseDir, [System.StringComparison]::OrdinalIgnoreCase)) {
    return [pscustomobject]@{ ok = $false; reason = 'unsafe-name'; path = $null }
  }
  if (-not (Test-Path -LiteralPath $canon)) {
    return [pscustomobject]@{ ok = $false; reason = 'already-absent'; path = $canon }
  }
  if (($Kind -eq 'frente') -ne (Test-Path -LiteralPath $canon -PathType Container)) {
    return [pscustomobject]@{ ok = $false; reason = 'type-mismatch'; path = $canon }
  }
  if (Test-TreeHasReparse $canon) {
    return [pscustomobject]@{ ok = $false; reason = 'reparse-point'; path = $canon }
  }
  return [pscustomobject]@{ ok = $true; reason = $null; path = $canon }
}

# Nome de exclusao: exato, sem separadores nem curingas. Retorna $null se valido.
function Test-ExclName {
  param([string]$N)
  if ([string]::IsNullOrWhiteSpace($N)) { return 'vazio' }
  if ($N -ne $N.Trim()) { return 'espacos-nas-bordas' }
  if ($N -match '[\\/:*?"<>|]' -or $N.Contains('..') -or $N -eq '.') { return 'caractere-invalido' }
  if ($N.EndsWith('.')) { return 'termina-em-ponto' }
  if ($N -match '[\x00-\x1F]') { return 'caractere-de-controle' }
  return $null
}

# --- Plano -------------------------------------------------------------------------
function Build-Plan {
  $json = Invoke-HygieneEngine
  $naoConf = @(Get-Prop $json 'frentesNaoConformes')
  $orf = @(Get-Prop $json 'pacotesOrfaos')
  $vinc = @(Get-Prop $json 'pacotesVinculados')

  $frTargets = @()
  if ($script:doFrentes) { $frTargets = @($naoConf | ForEach-Object { [string]$_ }) }
  $exclSeen = @{}
  foreach ($n in @($ExcludeFrente)) {
    $e = Test-ExclName $n
    if ($e) { $script:blockers.Add("exclusao de frente invalida ($e): '$n'"); continue }
    if ($exclSeen.ContainsKey("frente|$n")) { continue }
    $exclSeen["frente|$n"] = $true
    if ($script:doFrentes -and ($frTargets -contains $n)) {
      $actual = @($frTargets | Where-Object { $_ -eq $n })[0]
      $frTargets = @($frTargets | Where-Object { $_ -ne $n })
      $script:exclusions += [pscustomobject]@{ kind = 'frente'; name = $actual; status = 'excluido' }
    }
    else { $script:blockers.Add("exclusao de frente que nao e alvo desta execucao (fail-closed): '$n'") }
  }

  # Pacotes alvo: orfaos + cascata (pacotes de frentes nao conformes que serao removidas)
  $pTargets = @()
  if ($script:doPacotes) {
    foreach ($o in $orf) { $pTargets += [string](Get-Prop $o 'pacote') }
    if ($script:doFrentes) {
      foreach ($v in $vinc) {
        if ((Get-Prop $v 'frenteStatus') -eq 'naoConforme' -and ($frTargets -contains [string](Get-Prop $v 'frente'))) {
          $pTargets += [string](Get-Prop $v 'pacote')
        }
      }
    }
  }
  $pTargets = @($pTargets | Select-Object -Unique)

  foreach ($n in @($ExcludePacote)) {
    $e = Test-ExclName $n
    if ($e) { $script:blockers.Add("exclusao de pacote invalida ($e): '$n'"); continue }
    if ($exclSeen.ContainsKey("pacote|$n")) { continue }
    $exclSeen["pacote|$n"] = $true
    if ($pTargets -contains $n) {
      $actual = @($pTargets | Where-Object { $_ -eq $n })[0]
      $pTargets = @($pTargets | Where-Object { $_ -ne $n })
      $script:exclusions += [pscustomobject]@{ kind = 'pacote'; name = $actual; status = 'excluido' }
    }
    else { $script:blockers.Add("exclusao de pacote que nao e alvo desta execucao (fail-closed): '$n'") }
  }

  # Ordem: pacote antes do sidecar (se o sidecar falhar, sobra so sidecar orfao, informativo;
  # se o pacote falhasse depois do sidecar, o pacote ficaria sem inventario)
  $ordered = @()
  foreach ($p in $pTargets) {
    $ordered += [pscustomobject]@{ kind = 'pacote'; name = $p }
    $sc = "$p.package-inventory.json"
    if (Test-Path -LiteralPath (Join-Path $script:pacotesDirCanon $sc) -PathType Leaf) {
      $ordered += [pscustomobject]@{ kind = 'sidecar'; name = $sc }
    }
  }
  foreach ($f in $frTargets) { $ordered += [pscustomobject]@{ kind = 'frente'; name = $f } }

  $planItems = @()
  foreach ($t in $ordered) {
    $kindRes = if ($t.kind -eq 'frente') { 'frente' } else { 'pacote' }
    $r = Resolve-Item -Name $t.name -Kind $kindRes
    if (-not $r.ok) {
      if ($r.reason -ne 'already-absent') { $script:blockers.Add("item bloqueado ($($r.reason)): $($t.name)") }
      continue
    }
    $st = Get-TreeStats -Path $r.path
    $planItems += [pscustomobject]@{
      kind = $t.kind; name = $t.name; path = $r.path; method = $script:method
      bytes = [int64]$st.bytes; files = [int]$st.files; mtimeMaxTicks = [int64]$st.mtimeMaxTicks
      pathsSha256 = (Get-TreePathsHash -Path $r.path)
    }
  }
  $script:items = @($planItems)
  return $json
}

function Get-NormPath {
  param([string]$P)
  $c = (Get-Canon $P) -replace '^\\\\\?\\', ''
  return $c.Normalize([System.Text.NormalizationForm]::FormC).ToUpperInvariant()
}

function Get-PlanKeys {
  param($Items, $Exclusions)
  $list = [System.Collections.Generic.List[string]]::new()
  foreach ($i in @($Items | Where-Object { $null -ne $_ })) {
    $list.Add("item|$(Get-Prop $i 'kind')|$(Get-Prop $i 'name')|$(Get-Prop $i 'method')|$(Get-Prop $i 'files')|$(Get-Prop $i 'bytes')|$(Get-Prop $i 'mtimeMaxTicks')|$(Get-Prop $i 'pathsSha256')")
  }
  foreach ($e in @($Exclusions | Where-Object { $null -ne $_ })) { $list.Add("excl|$(Get-Prop $e 'kind')|$(Get-Prop $e 'name')|$(Get-Prop $e 'status')") }
  $arr = $list.ToArray()
  [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
  return , $arr
}

# --- Lixeira -----------------------------------------------------------------------
function Test-IsElevated {
  $p = [System.Security.Principal.WindowsPrincipal]::new([System.Security.Principal.WindowsIdentity]::GetCurrent())
  return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Le a configuracao da Lixeira do volume (somente leitura). Lanca BLOCK se nao confiavel.
function Get-RecycleVolumeInfo {
  param([string]$Root)
  if ($Root -notmatch '^[A-Za-z]:\\$') { throw "BLOCK: volume nao e unidade local com letra ($Root)." }
  $di = [System.IO.DriveInfo]::new($Root)
  if ($di.DriveType -ne [System.IO.DriveType]::Fixed) { throw "BLOCK: volume $Root nao e fixo local ($($di.DriveType))." }
  try { $vol = Get-Volume -DriveLetter $Root.Substring(0, 1) -ErrorAction Stop }
  catch { throw "BLOCK: nao foi possivel identificar o volume $Root." }
  $guid = ([string]$vol.UniqueId) -replace '^\\\\\?\\Volume\{', '' -replace '\}\\?$', ''
  $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\BitBucket\Volume\{$guid}"
  if (-not (Test-Path -LiteralPath $key)) { throw "BLOCK: chave da Lixeira ausente para o volume $Root ($key)." }
  $p = Get-ItemProperty -LiteralPath $key
  if ($null -eq $p.PSObject.Properties['NukeOnDelete'] -or [int]$p.NukeOnDelete -ne 0) {
    throw "BLOCK: Lixeira do volume $Root nao confirmada (NukeOnDelete ausente ou diferente de 0)."
  }
  if ($null -eq $p.PSObject.Properties['MaxCapacity']) {
    throw "BLOCK: limite da Lixeira (MaxCapacity) nao configurado para o volume $Root (chave $key). Para remover nesta maquina, use -Backup <dir> -RunStamp <id> (move-aside) ou -Permanente (definitivo), ambos explicitos."
  }
  $maxMB = [int64]$p.MaxCapacity
  if ($maxMB -le 0) { throw "BLOCK: MaxCapacity invalido ($maxMB MB) para o volume $Root." }
  return [pscustomobject]@{ root = $Root; maxBytes = ($maxMB * 1MB); binDir = ($Root + '$Recycle.Bin') }
}

# Arquivos em uso bloqueiam QUALQUER metodo, antes da primeira acao (inclui -Permanente e -Backup).
function Test-ItemLocks {
  foreach ($it in $script:items) {
    $locked = @(Get-LockedFiles -Path $it.path)
    if ($locked.Count -gt 0) { $script:blockers.Add("arquivo em uso por outro processo ($($locked.Count)), ex.: $($locked[0])") }
  }
}

function Test-RecyclePrecheck {
  $recItems = @($script:items | Where-Object { $_.method -eq 'recycle' })
  if ($recItems.Count -eq 0) { return }
  if (Test-IsElevated) { $script:blockers.Add('sessao elevada: a verificacao da Lixeira so cobre o usuario atual'); return }
  $pol = Test-RecycleGlobalPolicy
  if ($pol) { $script:blockers.Add("Lixeira indisponivel por politica: $pol"); return }
  $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $groups = $recItems | Group-Object { [System.IO.Path]::GetPathRoot((Get-Canon $_.path)) }
  foreach ($g in $groups) {
    try { $info = Get-RecycleVolumeInfo -Root $g.Name }
    catch { $script:blockers.Add($_.Exception.Message); continue }
    $binUser = Join-Path $info.binDir $sid
    if (-not (Test-Path -LiteralPath $binUser)) { $script:blockers.Add("pasta da Lixeira do usuario ausente em $($g.Name)"); continue }
    $occ = [int64](Get-TreeBytes $binUser)
    $need = [int64](($g.Group | Measure-Object -Property bytes -Sum).Sum)
    foreach ($it in $g.Group) {
      if ($it.bytes -gt $info.maxBytes) { $script:blockers.Add("item acima do limite da Lixeira: $($it.name)") }
    }
    if (($occ + $need) -gt $info.maxBytes) {
      $script:blockers.Add("lista nao cabe no limite da Lixeira de $($g.Name) (ocupacao=$occ, lista=$need, limite=$($info.maxBytes))")
    }
  }
}

# Le um arquivo $I (versoes 1 e 2). Versao desconhecida -> excecao (unverified).
function Read-RecycleIndex {
  param([string]$Path)
  $b = [System.IO.File]::ReadAllBytes($Path)
  if ($b.Length -lt 28) { throw 'unverified: indice $I curto demais' }
  $ver = [System.BitConverter]::ToInt64($b, 0)
  $size = [System.BitConverter]::ToInt64($b, 8)
  $ft = [System.BitConverter]::ToInt64($b, 16)
  if ($ver -eq 1) {
    $txt = [System.Text.Encoding]::Unicode.GetString($b, 24, [Math]::Min(520, $b.Length - 24))
    $orig = $txt.Split([char]0)[0]
  }
  elseif ($ver -eq 2) {
    $len = [System.BitConverter]::ToInt32($b, 24)
    if ($len -lt 1 -or (28 + $len * 2) -gt $b.Length) { throw 'unverified: indice $I v2 com tamanho invalido' }
    $orig = [System.Text.Encoding]::Unicode.GetString($b, 28, $len * 2).TrimEnd([char]0)
  }
  else { throw ('unverified: versao de indice $I desconhecida (' + $ver + ')') }
  return [pscustomobject]@{ version = $ver; size = $size; fileTime = $ft; path = $orig }
}

# Envio a Lixeira + verificacao. Lanca excecao se nao verificado.
function Invoke-ItemRecycle {
  param($Item, [DateTime]$StartUtc)
  $root = [System.IO.Path]::GetPathRoot((Get-Canon $Item.path))
  $info = Get-RecycleVolumeInfo -Root $root
  $binUser = Join-Path $info.binDir ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
  $before = @{}
  foreach ($f in @(Get-ChildItem -LiteralPath $binUser -Filter '$I*' -Force -File -ErrorAction SilentlyContinue)) { $before[$f.Name] = $true }
  Add-Type -AssemblyName Microsoft.VisualBasic
  # So mostra janela do Windows em caso de erro (OnlyErrorDialogs). NoUI nao existe no enum UIOption.
  $ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
  $rec = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
  $script:actionsDone++
  if ($Item.kind -eq 'frente') {
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($Item.path, $ui, $rec, [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
  }
  else {
    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($Item.path, $ui, $rec)
  }
  if (Test-Path -LiteralPath $Item.path) { throw "unverified: caminho original ainda existe ($($Item.name))" }
  $novos = @(Get-ChildItem -LiteralPath $binUser -Filter '$I*' -Force -File | Where-Object { -not $before.ContainsKey($_.Name) })
  $alvo = Get-NormPath $Item.path
  $candidatos = @()
  foreach ($n in $novos) {
    $idx = Read-RecycleIndex -Path $n.FullName
    if ((Get-NormPath $idx.path) -cne $alvo) { continue }
    if ([DateTime]::FromFileTimeUtc($idx.fileTime) -lt $StartUtc) { continue }
    if ($Item.kind -ne 'frente' -and $idx.size -ne [int64]$Item.bytes) { continue }
    $candidatos += $n
  }
  if ($candidatos.Count -eq 0) { throw "unverified: registro na Lixeira nao encontrado ($($Item.name))" }
  if ($candidatos.Count -gt 1) { throw "unverified: registros ambiguos na Lixeira ($($candidatos.Count)) para ($($Item.name))" }
  $rPath = Join-Path $binUser ('$R' + $candidatos[0].Name.Substring(2))
  $rIsDir = Test-Path -LiteralPath $rPath -PathType Container
  $rIsFile = Test-Path -LiteralPath $rPath -PathType Leaf
  if (-not ((($Item.kind -eq 'frente') -and $rIsDir) -or (($Item.kind -ne 'frente') -and $rIsFile))) {
    throw ('unverified: par $R ausente ou de tipo inesperado (' + $Item.name + ')')
  }
  return 'recycle-verified'
}

function Invoke-ItemBackup {
  param($Item)
  $sub = if ($Item.kind -eq 'frente') { 'frentes' } else { 'pacotes' }
  $destDir = Join-Path $script:backupRoot $sub
  if (-not (Test-Path -LiteralPath $destDir)) { [void](New-Item -ItemType Directory -Path $destDir -Force) }
  $dest = Join-Path $destDir $Item.name
  $script:actionsDone++
  Move-Item -LiteralPath $Item.path -Destination $dest
  $line = [pscustomobject]@{ kind = $Item.kind; name = $Item.name; from = $Item.path; to = (Get-Canon $dest); method = 'backup' } | ConvertTo-Json -Compress
  [System.IO.File]::AppendAllText((Join-Path $script:backupRoot 'backup-manifest.jsonl'), $line + "`n", $script:utf8NoBom)
  return 'backup'
}

function Invoke-ItemPermanent {
  param($Item)
  $script:actionsDone++
  if ($Item.kind -eq 'frente') { Remove-DirBottomUp $Item.path } else { Remove-Item -LiteralPath $Item.path -Force }
  return 'permanent'
}

# --- Estado de execucao -------------------------------------------------------
$result = $null
$exitCode = 1
$mode = if ($Apply) { 'apply' } else { 'dry-run' }
$status = 'blocked'
$itemResults = @()
$residuo = @()
$sidecarsOrfaos = @()
$pacotesRejeitados = @()
$planSaved = $null
$rejeitadosRestantes = @()

try {
  $repoRootCanon = Get-Canon $RepoRoot
  $script:frentesDirCanon = Get-Canon (Join-Path $RepoRoot (($FrentesDirName -replace '\\', '/').Trim().TrimEnd('/')))
  $script:pacotesDirCanon = Get-Canon (Join-Path $RepoRoot (($PacotesDirName -replace '\\', '/').Trim().TrimEnd('/')))

  # Ancora de seguranca dos diretorios-base
  if (-not (Test-IsUnder $script:frentesDirCanon $repoRootCanon)) { $script:blockers.Add('frentesDir nao esta sob repoRoot') }
  if (-not (Test-IsUnder $script:pacotesDirCanon $repoRootCanon)) { $script:blockers.Add('pacotesDir nao esta sob repoRoot') }
  if (-not (Test-Path -LiteralPath $repoRootCanon -PathType Container)) { $script:blockers.Add('RepoRoot inexistente') }
  elseif (-not ((Test-Path -LiteralPath $script:frentesDirCanon -PathType Container) -or (Test-Path -LiteralPath $script:pacotesDirCanon -PathType Container))) {
    $script:blockers.Add('nenhuma das pastas de frentes/pacotes existe em RepoRoot')
  }
  if ($script:blockers.Count -eq 0) {
    if (Test-ChainHasReparse $repoRootCanon $script:frentesDirCanon) { $script:blockers.Add('reparse point no caminho ate frentesDir') }
    if (Test-ChainHasReparse $repoRootCanon $script:pacotesDirCanon) { $script:blockers.Add('reparse point no caminho ate pacotesDir') }
  }

  # Combinacoes (H-6)
  if ($Permanente -and $Backup) { $script:blockers.Add('-Permanente e -Backup sao mutuamente exclusivos') }
  if ($Backup -and -not $RunStamp) { $script:blockers.Add('-Backup exige -RunStamp') }
  if ($PlanPath -and $Apply) { $script:blockers.Add('-PlanPath so vale no dry-run') }
  if ($Apply -and -not $JsonPath) { $script:blockers.Add('-Apply exige -JsonPath (plano salvo pelo dry-run com -PlanPath)') }
  if ($JsonPath -and -not $Apply) { $script:blockers.Add('-JsonPath so vale com -Apply') }

  if ($Backup -and $RunStamp -and $script:blockers.Count -eq 0) {
    $backupCanon = Get-Canon $Backup
    if ((Test-IsUnder $backupCanon $script:frentesDirCanon) -or [string]::Equals($backupCanon, $script:frentesDirCanon, [System.StringComparison]::OrdinalIgnoreCase)) { $script:blockers.Add('-Backup nao pode estar dentro de frentesDir') }
    if ((Test-IsUnder $backupCanon $script:pacotesDirCanon) -or [string]::Equals($backupCanon, $script:pacotesDirCanon, [System.StringComparison]::OrdinalIgnoreCase)) { $script:blockers.Add('-Backup nao pode estar dentro de pacotesDir') }
    if (-not [string]::Equals([System.IO.Path]::GetPathRoot($backupCanon), [System.IO.Path]::GetPathRoot($repoRootCanon), [System.StringComparison]::OrdinalIgnoreCase)) { $script:blockers.Add('-Backup em outro volume nao suportado') }
    if ($RunStamp -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' -or $RunStamp.Contains('..')) { $script:blockers.Add("-RunStamp invalido (use letras, numeros, '.', '_' ou '-'; sem '..'): '$RunStamp'") }
    $script:backupRoot = Join-Path $backupCanon $RunStamp
    if ($script:blockers.Count -eq 0) {
      if ((Test-IsUnder $script:backupRoot $script:frentesDirCanon) -or (Test-IsUnder $script:backupRoot $script:pacotesDirCanon)) { $script:blockers.Add('destino do backup (backupCanon + RunStamp) cairia dentro das pastas-alvo') }
      if (Test-ChainHasReparse ([System.IO.Path]::GetPathRoot($backupCanon)) $backupCanon) { $script:blockers.Add('reparse point no caminho do -Backup') }
      if ((Test-Path -LiteralPath $script:backupRoot) -and @(Get-ChildItem -LiteralPath $script:backupRoot -Force).Count -gt 0) { $script:blockers.Add("subdir de backup '$($script:backupRoot)' ja existe e nao esta vazio") }
    }
  }

  if ($script:blockers.Count -eq 0) {
    $json = Build-Plan
    $sidecarsOrfaos = @(Get-Prop $json 'sidecarsOrfaos')
    $pacotesRejeitados = @(Get-Prop $json 'pacotesRejeitados')
  }

  if ($script:blockers.Count -eq 0 -and -not $Apply) {
    # ---------------- DRY-RUN ----------------
    if ($PlanPath -and $WhatIfPreference) { Write-Human '-WhatIf: o plano nao foi gravado.' }
    elseif ($PlanPath) {
      $pp = Get-Canon $PlanPath
      if ((Test-IsUnder $pp $script:frentesDirCanon) -or (Test-IsUnder $pp $script:pacotesDirCanon)) { $script:blockers.Add('-PlanPath nao pode estar dentro das pastas-alvo') }
      elseif (Test-Path -LiteralPath $pp) { $script:blockers.Add("-PlanPath ja existe (nao sobrescreve): $pp") }
      elseif (-not (Test-Path -LiteralPath (Split-Path -Parent $pp) -PathType Container)) { $script:blockers.Add('pasta de -PlanPath inexistente') }
      else {
        $plan = [pscustomobject]@{
          Kind = 'xpz-frente-hygiene-plan'; SchemaVersion = 1; repoRoot = $repoRootCanon
          frentesDir = $script:frentesDirCanon; pacotesDir = $script:pacotesDirCanon
          scope = $Scope; method = $script:method; backupRoot = $script:backupRoot
          exclusions = @($script:exclusions); items = @($script:items)
        }
        # CreateNew: falha se o arquivo aparecer entre o teste e a escrita (sem sobrescrita)
        $fs = [System.IO.File]::Open($pp, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try { $bytes = $script:utf8NoBom.GetBytes(($plan | ConvertTo-Json -Depth 6)); $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
        $planSaved = $pp
      }
    }
  }

  if ($script:blockers.Count -eq 0 -and $Apply) {
    # ---------------- APPLY (plano salvo) ----------------
    if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) { $script:blockers.Add("-JsonPath nao encontrado: $JsonPath") }
    else {
      $saved = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
      if ((Get-Prop $saved 'Kind') -ne 'xpz-frente-hygiene-plan' -or (Get-Prop $saved 'SchemaVersion') -ne 1) { $script:blockers.Add('-JsonPath nao e um plano do executor (Kind/SchemaVersion)') }
      elseif (-not (Test-PathsEqual (Get-Prop $saved 'repoRoot') $repoRootCanon) -or -not (Test-PathsEqual (Get-Prop $saved 'frentesDir') $script:frentesDirCanon) -or -not (Test-PathsEqual (Get-Prop $saved 'pacotesDir') $script:pacotesDirCanon)) {
        $script:blockers.Add('plano salvo pertence a outra raiz/pasta')
      }
      elseif ((Get-Prop $saved 'scope') -ne $Scope) {
        $script:blockers.Add("plano salvo foi gerado com Scope '$(Get-Prop $saved 'scope')' (esta execucao usa '$Scope')")
      }
      else {
        $savedKeys = Get-PlanKeys (Get-Prop $saved 'items') (Get-Prop $saved 'exclusions')
        $curKeys = Get-PlanKeys $script:items $script:exclusions
        $savedSet = [System.Collections.Generic.HashSet[string]]::new($savedKeys, [System.StringComparer]::Ordinal)
        $curSet = [System.Collections.Generic.HashSet[string]]::new($curKeys, [System.StringComparer]::Ordinal)
        $appeared = @($curKeys | Where-Object { -not $savedSet.Contains($_) })
        $gone = @($savedKeys | Where-Object { -not $curSet.Contains($_) })
        if ($appeared.Count -gt 0 -or $gone.Count -gt 0) {
          $script:blockers.Add("plano atual difere do salvo: surgiram=$($appeared.Count), sumiram=$($gone.Count) (nada removido)")
          foreach ($a in $appeared) { Write-Human "  + $a" }
          foreach ($g in $gone) { Write-Human "  - $g" }
        }
        $savedBk = [string](Get-Prop $saved 'backupRoot')
        $curBk = [string]$script:backupRoot
        if ($savedBk -cne $curBk) { $script:blockers.Add("destino de backup difere do plano salvo (salvo='$savedBk', atual='$curBk')") }
      }
    }
    if ($script:blockers.Count -eq 0 -and -not $WhatIfPreference) { Test-ItemLocks }
    if ($script:blockers.Count -eq 0 -and -not $WhatIfPreference) { Test-RecyclePrecheck }
    if ($script:blockers.Count -eq 0 -and $WhatIfPreference) {
      $status = 'whatif'; $exitCode = 0
      $itemResults = @($script:items | ForEach-Object { 'planned' })
    }
    elseif ($script:blockers.Count -eq 0) {
      # ---- execucao da lista salva (uma passada) ----
      $startUtc = [DateTime]::UtcNow.AddSeconds(-2)
      $results = [System.Collections.Generic.List[string]]::new()
      $hardStop = $null
      try {
        foreach ($it in $script:items) {
          $kindRes = if ($it.kind -eq 'frente') { 'frente' } else { 'pacote' }
          $r = Resolve-Item -Name $it.name -Kind $kindRes
          if (-not $r.ok) {
            if ($r.reason -eq 'already-absent') { $results.Add('already-absent'); continue }
            throw "item mudou desde o plano ($($r.reason)): $($it.name)"
          }
          $it.path = $r.path
          $res = switch ($it.method) {
            'recycle' { Invoke-ItemRecycle -Item $it -StartUtc $startUtc }
            'backup' { Invoke-ItemBackup -Item $it }
            'permanent' { Invoke-ItemPermanent -Item $it }
            default { throw "metodo desconhecido no plano: $($it.method)" }
          }
          $results.Add($res)
        }
      }
      catch { $hardStop = $_.Exception.Message }
      $itemResults = @($results)

      # .rejected de pacotes removidos NESTA execucao: evidencia forense, nunca removida; so informada.
      foreach ($it in $script:items) {
        if ($it.kind -ne 'pacote' -or (Test-Path -LiteralPath $it.path)) { continue }
        $rej = @(Get-ChildItem -LiteralPath $script:pacotesDirCanon -File -Force -ErrorAction Stop | Where-Object {
          $_.Name.StartsWith($it.name + '.rejected.', [System.StringComparison]::Ordinal) -and ($_.Name -cmatch '\.rejected\.[A-Z]$')
        })
        foreach ($rf in $rej) { $rejeitadosRestantes += $rf.Name }
      }

      # Residuo: o que ainda sobrou no estado autoritativo (exceto exclusoes intencionais)
      $fin = Invoke-HygieneEngine
      $exclKeys = @($script:exclusions | Where-Object { $_.status -eq 'excluido' } | ForEach-Object { "$($_.kind)|$($_.name)" })
      $residuo = @()
      foreach ($n in @(Get-Prop $fin 'frentesNaoConformes')) { if ($exclKeys -notcontains "frente|$n") { $residuo += "frente:$n" } }
      foreach ($o in @(Get-Prop $fin 'pacotesOrfaos')) { $pn = [string](Get-Prop $o 'pacote'); if ($exclKeys -notcontains "pacote|$pn") { $residuo += "pacote:$pn" } }

      if ($hardStop) {
        Write-Human $hardStop
        if ($script:actionsDone -eq 0) { $status = 'blocked'; $exitCode = 1 }
        else { $status = 'hard-stop'; $exitCode = 1 }
      }
      elseif ($residuo.Count -gt 0 -or @($script:exclusions | Where-Object { $_.status -eq 'excluido' }).Count -gt 0) {
        $status = 'applied-with-skips'; $exitCode = 3
      }
      else { $status = 'applied-clean'; $exitCode = 0 }
      if ($hardStop) { $script:blockers.Add($hardStop) }
    }
  }

  if ($script:blockers.Count -gt 0 -and $status -eq 'blocked') { $exitCode = 1 }
  elseif (-not $Apply -and $script:blockers.Count -eq 0) {
    $hasItems = (@($script:items).Count -gt 0)
    $status = if ($hasItems) { 'findings' } else { 'clean' }
    $exitCode = if ($hasItems) { 2 } else { 0 }
  }
}
catch {
  $script:blockers.Add($_.Exception.Message)
  $status = if ($script:actionsDone -gt 0) { 'hard-stop' } else { 'blocked' }
  $exitCode = 1
}

if ($script:blockers.Count -gt 0 -and $status -notin @('hard-stop')) { $status = 'blocked'; $exitCode = 1 }

$excludedList = @($script:exclusions)
$itemsOut = @()
for ($i = 0; $i -lt @($script:items).Count; $i++) {
  $it = @($script:items)[$i]
  $resI = if ($i -lt @($itemResults).Count) { @($itemResults)[$i] } elseif ($Apply) { 'not-reached' } else { 'planned' }
  $itemsOut += [pscustomobject]@{ kind = $it.kind; name = $it.name; method = $it.method; bytes = [int64]$it.bytes; result = $resI }
}
$removedFr = @($itemsOut | Where-Object { $_.kind -eq 'frente' -and $_.result -notin @('planned', 'not-reached', 'already-absent') }).Count
$removedPc = @($itemsOut | Where-Object { $_.kind -ne 'frente' -and $_.result -notin @('planned', 'not-reached', 'already-absent') }).Count
$totalBytes = [int64]0
foreach ($x in $itemsOut) { $totalBytes += [int64]$x.bytes }

$result = [pscustomobject]@{
  Kind                = 'xpz-frente-hygiene-cleanup-result'
  SchemaVersion       = 2
  mode                = if ($WhatIfPreference -and $Apply) { 'whatif' } else { $mode }
  status              = $status
  exitCode            = $exitCode
  repoRoot            = (Get-Canon $RepoRoot)
  scope               = $Scope
  method              = $script:method
  planPath            = $planSaved
  items               = @($itemsOut)
  exclusions          = @($excludedList)
  blockers            = @($script:blockers)
  sidecarsOrfaos      = @($sidecarsOrfaos)
  pacotesRejeitados   = @($pacotesRejeitados)
  residuo             = @($residuo)
  rejeitadosRestantes = @($rejeitadosRestantes)
  totalFrentesRemovidas = [int]$removedFr
  totalPacotesRemovidos = [int]$removedPc
  totalBytesPlanejados  = [int64]$totalBytes
}

if ($AsText) {
  "=== Faxina Fase 2a ($($result.mode)) -- status: $($result.status) ==="
  "Metodo: $($result.method)   Itens: $(@($result.items).Count)   Bytes: $($result.totalBytesPlanejados)"
  foreach ($x in @($result.items)) { "  [$($x.result)] $($x.kind) $($x.name)" }
  foreach ($b in @($result.blockers)) { "  BLOQUEIO: $b" }
  foreach ($r in @($result.residuo)) { "  RESIDUO: $r" }
  foreach ($r in @($result.rejeitadosRestantes)) { "  REJEITADO (mantido, limpeza manual): $r" }
  if ($result.planPath) { "Plano salvo em: $($result.planPath)" }
}
else {
  [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 8 -Compress))
}

exit $exitCode
