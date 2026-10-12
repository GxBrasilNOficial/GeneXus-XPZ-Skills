#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do executor Remove-XpzKbFrenteHygieneFindings.ps1 (faxina fail-safe da Fase 2a).
  Sentinela: XPZ_KB_FRENTE_HYGIENE_CLEANUP_SELFTEST_OK.

.DESCRIPTION
  Cobre, com pastas sinteticas reais (filesystem-only, motor real como fonte de verdade):
    A. LOCKSTEP de tipos: o motor emite Kind/SchemaVersion/frentesDir/pacotesDir e os tipos
       que o executor consome (frentesNaoConformes string[], pacotesOrfaos object[]).
    B. dry-run nao apaga (fixture end-to-end) e reporta findings.
    C. -Apply remove frente + pacote orfao -> applied-clean; itens somem.
    D. cascata estabiliza por progresso (remover frente orfana pacote-irmao -> removido).
    E. seletividade Scope=Frentes deixa o pacote orfao intacto.
    F. reparse-point (junction) no item -> recusado, link/target intactos.
    G. idempotencia: -Apply 2x -> 2a no-op (applied-clean).
    H. JSON sem Kind -> error; repoRoot divergente -> error.
    I. JSON stale (item ausente no FS) -> skipped(already-absent), nao apaga.
    J. pacotesNaoPadronizados intocado + espelhado em untouchedNonStandard.
    K. backup mesmo-volume: itens movidos + manifesto; -Backup sem -RunStamp -> error;
       -Backup dentro da pasta-alvo -> error; subdir de backup pre-existente -> error.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$exe = Join-Path $PSScriptRoot 'Remove-XpzKbFrenteHygieneFindings.ps1'
$engine = Join-Path $PSScriptRoot 'Test-XpzKbFrenteHygiene.ps1'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$tmpRoots = [System.Collections.Generic.List[string]]::new()

$FRENTES = 'ObjetosGeradosParaImportacaoNaKbNoGenexus'
$PACOTES = 'PacotesGeradosParaImportacaoNaKbNoGenexus'
$conforme = 'Refatora_11111111-1111-1111-1111-111111111111_20260101'

function New-TempRoot {
  param([string]$Slug)
  $r = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-faxina-$Slug-{0}" -f ([guid]::NewGuid().ToString('N')))
  [void](New-Item -ItemType Directory -Path $r -Force)
  $tmpRoots.Add($r)
  return $r
}
function Write-File {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}
function New-Frente { param([string]$Root, [string]$Name) Write-File -Path (Join-Path $Root "$FRENTES/$Name/Obj.xml") -Content '<Object />' }
function New-Pacote { param([string]$Root, [string]$File) Write-File -Path (Join-Path $Root "$PACOTES/$File") -Content '<ExportFile />' }
function Invoke-Engine { param([string]$Root) return (& pwsh -NoProfile -File $engine '-RepoRoot' $Root 2>$null | Out-String | ConvertFrom-Json) }
function Invoke-Cleanup {
  param([string[]]$Arguments)
  $out = & pwsh -NoProfile -File $exe @Arguments 2>$null | Out-String
  return [pscustomobject]@{ exit = $LASTEXITCODE; json = ($out | ConvertFrom-Json) }
}
function Assert-True { param([bool]$Cond, [string]$Message) if (-not $Cond) { throw "FALHA: $Message" } }

try {
  # ===== A. lockstep de tipos do motor =====
  $a = New-TempRoot -Slug 'lockstep'
  New-Frente -Root $a -Name 'FrenteSemPadrao'
  New-Pacote -Root $a -File 'Inexistente_01.import_file.xml'
  $ja = Invoke-Engine -Root $a
  Assert-True ($ja.Kind -eq 'xpz-frente-hygiene-result') "A: Kind do motor"
  Assert-True ($ja.SchemaVersion -eq 1) "A: SchemaVersion do motor"
  Assert-True ([bool]$ja.frentesDir -and [bool]$ja.pacotesDir) "A: dirs resolvidos no motor"
  Assert-True (@($ja.frentesNaoConformes) -contains 'FrenteSemPadrao') "A: frentesNaoConformes string[]"
  Assert-True (@($ja.pacotesOrfaos).Count -ge 1 -and [bool]$ja.pacotesOrfaos[0].pacote) "A: pacotesOrfaos[].pacote"

  # ===== B. dry-run nao apaga (E2E) =====
  $rb = Invoke-Cleanup -Arguments @('-RepoRoot', $a)
  Assert-True ($rb.exit -eq 2) "B: exit 2 (findings) esperado; obtido $($rb.exit)"
  Assert-True ($rb.json.status -eq 'findings') "B: status findings; obtido $($rb.json.status)"
  Assert-True ($rb.json.mode -eq 'dry-run') "B: mode dry-run"
  Assert-True (@($rb.json.passes[0].removedFrentes) -contains 'FrenteSemPadrao') "B: frente apareceria em removedFrentes"
  Assert-True (Test-Path -LiteralPath (Join-Path $a "$FRENTES/FrenteSemPadrao")) "B: dry-run NAO apagou a frente"

  # ===== C. -Apply remove frente + pacote orfao =====
  $rc = Invoke-Cleanup -Arguments @('-RepoRoot', $a, '-Apply')
  Assert-True ($rc.exit -eq 0) "C: exit 0 (applied-clean); obtido $($rc.exit)"
  Assert-True ($rc.json.status -eq 'applied-clean') "C: status applied-clean; obtido $($rc.json.status)"
  Assert-True ($rc.json.stabilized -eq $true) "C: stabilized true"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $a "$FRENTES/FrenteSemPadrao"))) "C: frente removida"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $a "$PACOTES/Inexistente_01.import_file.xml"))) "C: pacote orfao removido"

  # ===== D. cascata estabiliza =====
  $d = New-TempRoot -Slug 'cascata'
  New-Frente -Root $d -Name 'FrenteX'
  New-Pacote -Root $d -File 'FrenteX_01.import_file.xml'   # OK enquanto FrenteX existe
  $rd = Invoke-Cleanup -Arguments @('-RepoRoot', $d, '-Apply')
  Assert-True ($rd.json.status -eq 'applied-clean') "D: status applied-clean; obtido $($rd.json.status)"
  Assert-True ($rd.json.stabilized -eq $true) "D: cascata estabilizou"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $d "$PACOTES/FrenteX_01.import_file.xml"))) "D: pacote-irmao orfanado removido na cascata"
  Assert-True (@($rd.json.passes).Count -ge 2) "D: precisou de >=2 passadas"

  # ===== E. seletividade Scope=Frentes =====
  $e = New-TempRoot -Slug 'scope'
  New-Frente -Root $e -Name 'FrenteY'
  New-Pacote -Root $e -File 'Orfao_01.import_file.xml'   # orfao independente
  $re = Invoke-Cleanup -Arguments @('-RepoRoot', $e, '-Apply', '-Scope', 'Frentes')
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $e "$FRENTES/FrenteY"))) "E: frente removida no scope Frentes"
  Assert-True (Test-Path -LiteralPath (Join-Path $e "$PACOTES/Orfao_01.import_file.xml")) "E: pacote orfao PRESERVADO fora do scope"

  # ===== F. reparse-point (junction) recusado =====
  $f = New-TempRoot -Slug 'reparse'
  $target = New-TempRoot -Slug 'reparse-target'
  Write-File -Path (Join-Path $target 'sentinela.txt') -Content 'NAO APAGAR'
  [void](New-Item -ItemType Directory -Path (Join-Path $f $FRENTES) -Force)
  $link = Join-Path $f "$FRENTES/FrenteJunction"
  [void](New-Item -ItemType Junction -Path $link -Value $target)
  $rf = Invoke-Cleanup -Arguments @('-RepoRoot', $f, '-Apply')
  Assert-True ($rf.exit -eq 3) "F: exit 3 esperado (item flagado nao removivel); obtido $($rf.exit)"
  $fSkips = @(); foreach ($p in $rf.json.passes) { foreach ($s in $p.skipped) { $fSkips += $s.reason } }
  Assert-True ($fSkips -contains 'reparse-point') "F: skipped reparse-point registrado"
  Assert-True (Test-Path -LiteralPath $link) "F: junction NAO removida"
  Assert-True (Test-Path -LiteralPath (Join-Path $target 'sentinela.txt')) "F: alvo do junction intacto"

  # ===== G. idempotencia =====
  $g = New-TempRoot -Slug 'idemp'
  New-Frente -Root $g -Name 'FrenteZ'
  [void](Invoke-Cleanup -Arguments @('-RepoRoot', $g, '-Apply'))
  $rg2 = Invoke-Cleanup -Arguments @('-RepoRoot', $g, '-Apply')
  Assert-True ($rg2.exit -eq 0 -and $rg2.json.status -eq 'applied-clean') "G: 2a passada no-op applied-clean; obtido $($rg2.json.status)"

  # ===== H. JSON sem Kind / repoRoot divergente =====
  $h = New-TempRoot -Slug 'badjson'
  New-Frente -Root $h -Name 'FrenteH'
  $noKind = Join-Path $h 'nokind.json'
  '{"status":"warn","frentesNaoConformes":["FrenteH"],"pacotesOrfaos":[]}' | Set-Content -LiteralPath $noKind -Encoding utf8
  $rh = Invoke-Cleanup -Arguments @('-RepoRoot', $h, '-JsonPath', $noKind)
  Assert-True ($rh.exit -eq 1 -and $rh.json.status -eq 'error') "H: JSON sem Kind -> error; obtido $($rh.json.status)"
  $jh = Invoke-Engine -Root $h
  $divergente = Join-Path $h 'diverg.json'
  ($jh | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $divergente -Encoding utf8
  $rh2 = Invoke-Cleanup -Arguments @('-RepoRoot', (New-TempRoot -Slug 'outro'), '-JsonPath', $divergente)
  Assert-True ($rh2.exit -eq 1 -and $rh2.json.status -eq 'error') "H: repoRoot divergente -> error; obtido $($rh2.json.status)"

  # ===== I. JSON stale (item virou ausente) =====
  $i = New-TempRoot -Slug 'stale'
  New-Frente -Root $i -Name 'FrenteStale'
  $ji = Invoke-Engine -Root $i
  $capI = Join-Path $i 'cap.json'
  ($ji | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $capI -Encoding utf8
  Remove-Item -LiteralPath (Join-Path $i "$FRENTES/FrenteStale") -Recurse -Force   # some apos a captura
  $ri = Invoke-Cleanup -Arguments @('-RepoRoot', $i, '-JsonPath', $capI)
  $iSkips = @(); foreach ($p in $ri.json.passes) { foreach ($s in $p.skipped) { $iSkips += $s.reason } }
  Assert-True ($iSkips -contains 'already-absent') "I: JSON stale -> skipped already-absent; obtidos: $($iSkips -join ',')"
  Assert-True ($ri.json.status -eq 'clean') "I: nada a remover de fato -> clean; obtido $($ri.json.status)"

  # ===== J. pacotesNaoPadronizados intocado + espelhado =====
  $j = New-TempRoot -Slug 'naopadr'
  New-Frente -Root $j -Name 'FrenteJ'
  New-Pacote -Root $j -File 'weird.xpz'   # casa extensao, nao casa <frente>_<nn>
  $rj = Invoke-Cleanup -Arguments @('-RepoRoot', $j, '-Apply')
  Assert-True (@($rj.json.untouchedNonStandard) -contains 'weird.xpz') "J: weird.xpz espelhado em untouchedNonStandard"
  Assert-True (Test-Path -LiteralPath (Join-Path $j "$PACOTES/weird.xpz")) "J: pacote nao-padronizado NAO tocado"

  # ===== K. backup =====
  $k = New-TempRoot -Slug 'backup'
  New-Frente -Root $k -Name 'FrenteK'
  New-Pacote -Root $k -File 'OrfK_01.import_file.xml'
  $bkRoot = New-TempRoot -Slug 'backup-dest'
  $rk = Invoke-Cleanup -Arguments @('-RepoRoot', $k, '-Apply', '-Backup', $bkRoot, '-RunStamp', 'run001')
  Assert-True ($rk.json.status -eq 'applied-clean') "K: backup applied-clean; obtido $($rk.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $bkRoot 'run001/frentes/FrenteK')) "K: frente movida ao backup"
  Assert-True (Test-Path -LiteralPath (Join-Path $bkRoot 'run001/pacotes/OrfK_01.import_file.xml')) "K: pacote movido ao backup"
  Assert-True (Test-Path -LiteralPath (Join-Path $bkRoot 'run001/backup-manifest.json')) "K: manifesto de backup gravado"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $k "$FRENTES/FrenteK"))) "K: original removido apos backup"

  # K2: -Backup sem -RunStamp -> error
  $k2 = New-TempRoot -Slug 'backup-norunstamp'
  New-Frente -Root $k2 -Name 'FrenteK2'
  $rk2 = Invoke-Cleanup -Arguments @('-RepoRoot', $k2, '-Apply', '-Backup', (New-TempRoot -Slug 'bk2'))
  Assert-True ($rk2.exit -eq 1 -and $rk2.json.status -eq 'error') "K2: -Backup sem -RunStamp -> error"

  # K3: -Backup dentro da pasta-alvo -> error
  $k3 = New-TempRoot -Slug 'backup-inside'
  New-Frente -Root $k3 -Name 'FrenteK3'
  $rk3 = Invoke-Cleanup -Arguments @('-RepoRoot', $k3, '-Apply', '-Backup', (Join-Path $k3 $FRENTES), '-RunStamp', 'r')
  Assert-True ($rk3.exit -eq 1 -and $rk3.json.status -eq 'error') "K3: -Backup dentro de frentesDir -> error"

  # K4: subdir de backup pre-existente nao-vazio -> error
  $k4 = New-TempRoot -Slug 'backup-preexist'
  New-Frente -Root $k4 -Name 'FrenteK4'
  $bk4 = New-TempRoot -Slug 'bk4'
  Write-File -Path (Join-Path $bk4 'run001/ocupado.txt') -Content 'x'
  $rk4 = Invoke-Cleanup -Arguments @('-RepoRoot', $k4, '-Apply', '-Backup', $bk4, '-RunStamp', 'run001')
  Assert-True ($rk4.exit -eq 1 -and $rk4.json.status -eq 'error') "K4: subdir de backup pre-existente -> error"

  'XPZ_KB_FRENTE_HYGIENE_CLEANUP_SELFTEST_OK'
}
finally {
  foreach ($r in $tmpRoots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
