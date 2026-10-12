#requires -Version 7.4

<#
.SYNOPSIS
  Executor de faxina (fail-safe) da Fase 2a da rotina pre-push de pasta paralela de KB
  (skill xpz-kb-parallel-pre-push). Remove frentes nao-conformes e pacotes orfaos que o
  motor de DIAGNOSTICO Test-XpzKbFrenteHygiene.ps1 flagou.

.DESCRIPTION
  FONTE DE VERDADE UNICA = o motor Test-XpzKbFrenteHygiene.ps1. Este executor NAO
  reimplementa o matching pacote<->frente: ele consome o JSON do motor. Em -Apply,
  re-invoca o motor a cada passada e age SO sobre o conjunto autoritativo atual.

  FAIL-SAFE: sem -Apply o comportamento e dry-run (lista o que SERIA removido, apaga
  nada). -WhatIf tambem funciona. Deleção real so com -Apply.

  SEGURANCA: ancora os diretorios-base sob -RepoRoot canonico e recusa reparse point
  (junction/symlink) em qualquer componente do caminho; pre-varre cada item sem seguir
  links e recusa reparse no item ou em descendente; remove diretorio por descida
  bottom-up (nunca -Recurse). -Backup (opcional) move para fora das pastas-alvo, so no
  mesmo volume.

  CONTRATO DE SAIDA: 1 linha JSON no stdout (Kind='xpz-frente-hygiene-cleanup-result',
  SchemaVersion=1). Texto humano so por stderr. status NORMATIVO (autoridade primaria):
  clean | findings | applied-clean | applied-with-skips | not-stabilized | error.
  EXIT: 0 clean/applied-clean; 2 findings (dry-run com itens); 3 applied-with-skips e
  not-stabilized; 1 error. Automacao deve ler status, nao o numero do exit (o exit 2
  coincide com o warn do motor, semantica distinta).

  LOCKSTEP: consumidor do contrato de Test-XpzKbFrenteHygiene.ps1; travado por
  Test-XpzKbFrenteHygieneCleanupSelfTest.ps1 (tipos + fixture end-to-end).

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual).
.PARAMETER FrentesDirName
  Pasta de geracao por frente (default: ObjetosGeradosParaImportacaoNaKbNoGenexus).
.PARAMETER PacotesDirName
  Pasta de pacotes (default: PacotesGeradosParaImportacaoNaKbNoGenexus).
.PARAMETER Scope
  Frentes | Pacotes | Ambos (default Ambos).
.PARAMETER Apply
  Executa a deleção real. Ausente = dry-run.
.PARAMETER JsonPath
  JSON capturado do motor para PRE-VISUALIZAR (dry-run) ou CRUZAR/avisar drift (-Apply).
  Nunca e autoridade de deleção sob -Apply (a autoridade e o motor re-invocado).
.PARAMETER Backup
  Diretorio de backup (move-aside) fora das pastas-alvo, mesmo volume. Requer -RunStamp.
.PARAMETER RunStamp
  Carimbo unico da execução para o subdiretorio de backup (script nao chama relogio).
.PARAMETER MaxPasses
  Fusivel de iteracao ate ponto-fixo (default 5).
.PARAMETER EnginePath
  Caminho do motor (default: Test-XpzKbFrenteHygiene.ps1 irmao deste script).
.PARAMETER AsText
  Saida humana em texto no stdout em vez do JSON padrao.

.EXAMPLE
  Remove-XpzKbFrenteHygieneFindings.ps1 -RepoRoot C:\kb-paralela
  (dry-run: mostra o que seria removido)
.EXAMPLE
  Remove-XpzKbFrenteHygieneFindings.ps1 -RepoRoot C:\kb-paralela -Apply
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$RepoRoot = (Get-Location).Path,
  [string]$FrentesDirName = 'ObjetosGeradosParaImportacaoNaKbNoGenexus',
  [string]$PacotesDirName = 'PacotesGeradosParaImportacaoNaKbNoGenexus',
  [ValidateSet('Frentes', 'Pacotes', 'Ambos')]
  [string]$Scope = 'Ambos',
  [switch]$Apply,
  [string]$JsonPath,
  [string]$Backup,
  [string]$RunStamp,
  [ValidateRange(1, 50)]
  [int]$MaxPasses = 5,
  [string]$EnginePath,
  [switch]$AsText
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $EnginePath) { $EnginePath = Join-Path $PSScriptRoot 'Test-XpzKbFrenteHygiene.ps1' }

$reparse = [System.IO.FileAttributes]::ReparsePoint
$sep = [System.IO.Path]::DirectorySeparatorChar

function Write-Human { param([string]$Text) [Console]::Error.WriteLine($Text) }

function Get-Canon { param([string]$Path) return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\', '/') }

function Test-PathsEqual {
  param([string]$A, [string]$B)
  return [string]::Equals((Get-Canon $A), (Get-Canon $B), [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-IsUnder {
  param([string]$Child, [string]$Parent)
  $c = Get-Canon $Child
  $p = Get-Canon $Parent
  return $c.StartsWith($p + $sep, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-IsReparse {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $false }
  $it = Get-Item -LiteralPath $Path -Force
  return (($it.Attributes -band $reparse) -ne 0)
}

# Pre-varredura sem seguir links: $true se o root OU qualquer descendente for reparse.
function Test-TreeHasReparse {
  param([string]$Root)
  if (Test-IsReparse $Root) { return $true }
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $false }
  $children = Get-ChildItem -LiteralPath $Root -Force
  foreach ($c in $children) {
    if (($c.Attributes -band $reparse) -ne 0) { return $true }
    if ($c.PSIsContainer) {
      if (Test-TreeHasReparse $c.FullName) { return $true }
    }
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

function Get-VolumeRoot { param([string]$Path) return ([System.IO.Path]::GetPathRoot((Get-Canon $Path))) }

# Remoção bottom-up sem -Recurse (pre-varredura ja garantiu ausencia de reparse interno).
function Remove-DirBottomUp {
  param([string]$Dir)
  $all = @(Get-ChildItem -LiteralPath $Dir -Force -Recurse)
  $ordered = $all | Sort-Object { $_.FullName.Length } -Descending
  foreach ($i in $ordered) { Remove-Item -LiteralPath $i.FullName -Force }
  Remove-Item -LiteralPath $Dir -Force
}

# --- Motor (fonte de verdade) -------------------------------------------------
function Invoke-HygieneEngine {
  $out = & pwsh -NoProfile -File $EnginePath -RepoRoot $RepoRoot -FrentesDirName $FrentesDirName -PacotesDirName $PacotesDirName 2>$null
  $code = $LASTEXITCODE
  if ($code -ne 0 -and $code -ne 2) { throw "BLOCK: motor de diagnostico falhou (exit $code)." }
  return ($out | Out-String | ConvertFrom-Json)
}

function Get-FrenteTargets { param($Json) return @(Get-Prop $Json 'frentesNaoConformes') }
function Get-PacoteTargets {
  param($Json)
  $orf = @(Get-Prop $Json 'pacotesOrfaos')
  $names = @()
  foreach ($o in $orf) { $names += (Get-Prop $o 'pacote') }
  return @($names)
}

# --- Estado de execução -------------------------------------------------------
$result = $null
$exitCode = 1
try {
  $doFrentes = ($Scope -eq 'Frentes' -or $Scope -eq 'Ambos')
  $doPacotes = ($Scope -eq 'Pacotes' -or $Scope -eq 'Ambos')

  $repoRootCanon = Get-Canon $RepoRoot
  $frentesDirCanon = Get-Canon (Join-Path $RepoRoot (($FrentesDirName -replace '\\', '/').Trim().TrimEnd('/')))
  $pacotesDirCanon = Get-Canon (Join-Path $RepoRoot (($PacotesDirName -replace '\\', '/').Trim().TrimEnd('/')))

  # --- Ancora de seguranca dos diretorios-base --------------------------------
  if (-not (Test-IsUnder $frentesDirCanon $repoRootCanon)) { throw "BLOCK: frentesDir nao esta sob repoRoot." }
  if (-not (Test-IsUnder $pacotesDirCanon $repoRootCanon)) { throw "BLOCK: pacotesDir nao esta sob repoRoot." }
  if (Test-ChainHasReparse $repoRootCanon $frentesDirCanon) { throw "BLOCK: reparse point no caminho ate frentesDir." }
  if (Test-ChainHasReparse $repoRootCanon $pacotesDirCanon) { throw "BLOCK: reparse point no caminho ate pacotesDir." }

  # --- Validacao de -Backup ---------------------------------------------------
  $backupRoot = $null
  if ($Backup) {
    if (-not $RunStamp) { throw "BLOCK: -Backup exige -RunStamp (o script nao gera carimbo de tempo)." }
    $backupCanon = Get-Canon $Backup
    if ((Test-IsUnder $backupCanon $frentesDirCanon) -or [string]::Equals($backupCanon, $frentesDirCanon, [System.StringComparison]::OrdinalIgnoreCase)) { throw "BLOCK: -Backup nao pode estar dentro de frentesDir." }
    if ((Test-IsUnder $backupCanon $pacotesDirCanon) -or [string]::Equals($backupCanon, $pacotesDirCanon, [System.StringComparison]::OrdinalIgnoreCase)) { throw "BLOCK: -Backup nao pode estar dentro de pacotesDir." }
    if (-not [string]::Equals((Get-VolumeRoot $backupCanon), (Get-VolumeRoot $repoRootCanon), [System.StringComparison]::OrdinalIgnoreCase)) { throw "BLOCK: -Backup cross-volume nao suportado no v1 (use mesmo volume; follow-up no 999)." }
    $backupRoot = Join-Path $backupCanon $RunStamp
    if ((Test-Path -LiteralPath $backupRoot) -and @(Get-ChildItem -LiteralPath $backupRoot -Force).Count -gt 0) { throw "BLOCK: subdir de backup '$backupRoot' ja existe e nao esta vazio (nao sobrescreve)." }
  }

  # --- JSON capturado (se houver) ---------------------------------------------
  $capturedJson = $null
  if ($JsonPath) {
    if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) { throw "BLOCK: -JsonPath nao encontrado: $JsonPath" }
    $capturedJson = (Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json)
    $k = Get-Prop $capturedJson 'Kind'
    if ($k -ne 'xpz-frente-hygiene-result') { throw "BLOCK: JSON capturado sem Kind esperado (obtido '$k')." }
    $sv = Get-Prop $capturedJson 'SchemaVersion'
    if ($sv -ne 1) { throw "BLOCK: SchemaVersion incompativel (obtido '$sv', esperado 1)." }
    if (-not (Test-PathsEqual (Get-Prop $capturedJson 'repoRoot') $RepoRoot)) { throw "BLOCK: repoRoot do JSON difere do alvo." }
    if (-not (Test-PathsEqual (Get-Prop $capturedJson 'frentesDir') $frentesDirCanon)) { throw "BLOCK: frentesDir do JSON difere do alvo." }
    if (-not (Test-PathsEqual (Get-Prop $capturedJson 'pacotesDir') $pacotesDirCanon)) { throw "BLOCK: pacotesDir do JSON difere do alvo." }
  }

  $passes = [System.Collections.Generic.List[object]]::new()
  $untouchedNonStandard = @()
  $remainingOrfaos = @()
  $mode = if ($Apply) { 'apply' } else { 'dry-run' }

  # Resolve o caminho fisico de um item flagado, com checagens fisicas (sem matching).
  function Resolve-Item {
    param([string]$Name, [string]$Kind)
    $baseDir = if ($Kind -eq 'frente') { $frentesDirCanon } else { $pacotesDirCanon }
    if ($Name -match '[\\/:]' -or $Name -eq '..' -or $Name -eq '.') {
      return [pscustomobject]@{ ok = $false; reason = 'unsafe-name'; path = $null }
    }
    $path = Join-Path $baseDir $Name
    $canon = Get-Canon $path
    $parent = [System.IO.Path]::GetDirectoryName($canon)
    if (-not [string]::Equals($parent, $baseDir, [System.StringComparison]::OrdinalIgnoreCase)) {
      return [pscustomobject]@{ ok = $false; reason = 'unsafe-name'; path = $null }
    }
    $wantContainer = ($Kind -eq 'frente')
    if (-not (Test-Path -LiteralPath $canon)) {
      return [pscustomobject]@{ ok = $false; reason = 'already-absent'; path = $canon }
    }
    if ($wantContainer -ne (Test-Path -LiteralPath $canon -PathType Container)) {
      return [pscustomobject]@{ ok = $false; reason = 'type-mismatch'; path = $canon }
    }
    if (Test-TreeHasReparse $canon) {
      return [pscustomobject]@{ ok = $false; reason = 'reparse-point'; path = $canon }
    }
    return [pscustomobject]@{ ok = $true; reason = $null; path = $canon }
  }

  if (-not $Apply) {
    # ---------------- DRY-RUN (uma avaliacao) ----------------
    $json = if ($capturedJson) { $capturedJson } else { Invoke-HygieneEngine }
    $untouchedNonStandard = @(Get-Prop $json 'pacotesNaoPadronizados')
    $wouldFrentes = @()
    $wouldPacotes = @()
    $skipped = [System.Collections.Generic.List[object]]::new()
    if ($doFrentes) {
      foreach ($n in (Get-FrenteTargets $json)) {
        $r = Resolve-Item -Name $n -Kind 'frente'
        if ($r.ok) { $wouldFrentes += $n } else { $skipped.Add([pscustomobject]@{ item = $n; kind = 'frente'; reason = $r.reason }) }
      }
    }
    if ($doPacotes) {
      foreach ($n in (Get-PacoteTargets $json)) {
        $r = Resolve-Item -Name $n -Kind 'pacote'
        if ($r.ok) { $wouldPacotes += $n } else { $skipped.Add([pscustomobject]@{ item = $n; kind = 'pacote'; reason = $r.reason }) }
      }
    }
    $passes.Add([pscustomobject]@{ pass = 1; removedFrentes = @($wouldFrentes); removedPacotes = @($wouldPacotes); skipped = @($skipped) })
    $hasItems = (($wouldFrentes.Count + $wouldPacotes.Count) -gt 0)
    if ($hasItems -and $wouldFrentes.Count -gt 0 -and $doPacotes) {
      Write-Human "AVISO cascata: remover $($wouldFrentes.Count) frente(s) deve orfanar pacotes-irmaos; re-rode apos -Apply para tratar a cascata."
    }
    if ($untouchedNonStandard.Count -gt 0) { Write-Human "$($untouchedNonStandard.Count) item(ns) fora do escopo do executor (pacotesNaoPadronizados, nao tocados)." }
    $status = if ($hasItems) { 'findings' } else { 'clean' }
    $exitCode = if ($hasItems) { 2 } else { 0 }
    $remainingOrfaos = @()
  }
  else {
    # ---------------- APPLY (iteracao ate ponto-fixo) ----------------
    $stabilized = $null
    $pass = 0
    $lastJson = $null
    while ($pass -lt $MaxPasses) {
      $pass++
      $json = Invoke-HygieneEngine
      $lastJson = $json
      $untouchedNonStandard = @(Get-Prop $json 'pacotesNaoPadronizados')

      # Drift vs JSON capturado (so aviso; autoridade e o motor fresco)
      if ($capturedJson -and $pass -eq 1) {
        $capF = @(Get-FrenteTargets $capturedJson)
        $freshF = @(Get-FrenteTargets $json)
        $appeared = @($freshF | Where-Object { $capF -notcontains $_ })
        $gone = @($capF | Where-Object { $freshF -notcontains $_ })
        if ($appeared.Count -gt 0 -or $gone.Count -gt 0) {
          Write-Human "AVISO drift: frentes surgidas desde a captura=$($appeared.Count), sumidas=$($gone.Count). Autoridade = motor fresco."
        }
      }

      $targets = [System.Collections.Generic.List[object]]::new()
      if ($doFrentes) { foreach ($n in (Get-FrenteTargets $json)) { $targets.Add([pscustomobject]@{ name = $n; kind = 'frente' }) } }
      if ($doPacotes) { foreach ($n in (Get-PacoteTargets $json)) { $targets.Add([pscustomobject]@{ name = $n; kind = 'pacote' }) } }

      if ($targets.Count -eq 0) { $stabilized = $true; break }

      $removedFrentes = @()
      $removedPacotes = @()
      $skipped = [System.Collections.Generic.List[object]]::new()
      $removedThisPass = 0

      foreach ($t in $targets) {
        $r = Resolve-Item -Name $t.name -Kind $t.kind
        if (-not $r.ok) {
          $skipped.Add([pscustomobject]@{ item = $t.name; kind = $t.kind; reason = $r.reason })
          continue
        }
        if (-not $PSCmdlet.ShouldProcess($r.path, "Remover ($($t.kind))")) {
          $skipped.Add([pscustomobject]@{ item = $t.name; kind = $t.kind; reason = 'whatif' })
          continue
        }
        # re-check de reparse imediatamente antes da operacao final (estreita TOCTOU)
        if (Test-IsReparse $r.path) {
          $skipped.Add([pscustomobject]@{ item = $t.name; kind = $t.kind; reason = 'reparse-point' })
          continue
        }
        try {
          if ($backupRoot) {
            $sub = if ($t.kind -eq 'frente') { 'frentes' } else { 'pacotes' }
            $destDir = Join-Path $backupRoot $sub
            if (-not (Test-Path -LiteralPath $destDir)) { [void](New-Item -ItemType Directory -Path $destDir -Force) }
            $dest = Join-Path $destDir $t.name
            Move-Item -LiteralPath $r.path -Destination $dest
            $manifest = Join-Path $backupRoot 'backup-manifest.json'
            $entry = [pscustomobject]@{ pass = $pass; kind = $t.kind; name = $t.name; from = $r.path; to = (Get-Canon $dest) }
            $acc = @()
            if (Test-Path -LiteralPath $manifest) { $acc = @(Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json) }
            $acc += $entry
            $acc | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifest -Encoding utf8
          }
          elseif ($t.kind -eq 'frente') {
            Remove-DirBottomUp $r.path
          }
          else {
            Remove-Item -LiteralPath $r.path -Force
          }
          if ($t.kind -eq 'frente') { $removedFrentes += $t.name } else { $removedPacotes += $t.name }
          $removedThisPass++
        }
        catch {
          $skipped.Add([pscustomobject]@{ item = $t.name; kind = $t.kind; reason = 'partial-removal' })
        }
      }

      $passes.Add([pscustomobject]@{ pass = $pass; removedFrentes = @($removedFrentes); removedPacotes = @($removedPacotes); skipped = @($skipped) })

      if ($removedThisPass -eq 0) { $stabilized = $false; break }
    }

    # Reconciliacao final do estado autoritativo
    $finalJson = Invoke-HygieneEngine
    $untouchedNonStandard = @(Get-Prop $finalJson 'pacotesNaoPadronizados')
    $finalTargets = @()
    if ($doFrentes) { foreach ($n in (Get-FrenteTargets $finalJson)) { $finalTargets += [pscustomobject]@{ kind = 'frente'; item = $n } } }
    if ($doPacotes) { foreach ($n in (Get-PacoteTargets $finalJson)) { $finalTargets += [pscustomobject]@{ kind = 'pacote'; item = $n } } }
    $remainingOrfaos = @($finalTargets)
    if ($null -eq $stabilized) { $stabilized = ($finalTargets.Count -eq 0) }

    # status com precedencia mutuamente exclusiva
    $dangerSkips = 0
    foreach ($p in $passes) { foreach ($s in $p.skipped) { if ($s.reason -eq 'reparse-point' -or $s.reason -eq 'partial-removal' -or $s.reason -eq 'unsafe-name' -or $s.reason -eq 'type-mismatch') { $dangerSkips++ } } }
    if (-not $stabilized) {
      $status = 'not-stabilized'; $exitCode = 3
    }
    elseif ($dangerSkips -gt 0) {
      $status = 'applied-with-skips'; $exitCode = 3
    }
    else {
      $status = 'applied-clean'; $exitCode = 0
    }
    if ($untouchedNonStandard.Count -gt 0) { Write-Human "$($untouchedNonStandard.Count) item(ns) fora do escopo do executor (pacotesNaoPadronizados, nao tocados)." }
  }

  $result = [pscustomobject]@{
    Kind                 = 'xpz-frente-hygiene-cleanup-result'
    SchemaVersion        = 1
    mode                 = $mode
    repoRoot             = $RepoRoot
    frentesDir           = $frentesDirCanon
    pacotesDir           = $pacotesDirCanon
    scope                = $Scope
    passes               = @($passes)
    totalRemovedFrentes  = (@($passes) | ForEach-Object { @($_.removedFrentes).Count } | Measure-Object -Sum).Sum
    totalRemovedPacotes  = (@($passes) | ForEach-Object { @($_.removedPacotes).Count } | Measure-Object -Sum).Sum
    stabilized           = if ($Apply) { [bool]$stabilized } else { $null }
    remainingOrfaos      = @($remainingOrfaos)
    untouchedNonStandard = @($untouchedNonStandard)
    status               = $status
    exitCode             = $exitCode
  }
}
catch {
  $msg = $_.Exception.Message
  Write-Human $msg
  $errMode = if ($Apply) { 'apply' } else { 'dry-run' }
  $result = [pscustomobject]@{
    Kind = 'xpz-frente-hygiene-cleanup-result'; SchemaVersion = 1; mode = $errMode
    repoRoot = $RepoRoot; scope = $Scope; status = 'error'; exitCode = 1; error = $msg
  }
  $exitCode = 1
}

if ($AsText) {
  "=== Faxina Fase 2a ($($result.mode)) — status: $($result.status) ==="
  $result | ConvertTo-Json -Depth 8
}
else {
  [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 8 -Compress))
}

exit $exitCode
