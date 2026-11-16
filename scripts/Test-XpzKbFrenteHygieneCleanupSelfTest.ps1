#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do executor Remove-XpzKbFrenteHygieneFindings.ps1 (faxina Fase 2a, fase 1).
  Sentinela: XPZ_KB_FRENTE_HYGIENE_CLEANUP_SELFTEST_OK.

.DESCRIPTION
  Pastas sinteticas em %TEMP%, motor real como fonte de verdade. Os casos de -Apply usam
  -Permanente (nao tocam a Lixeira do usuario). O caso de Lixeira real e opt-in:
  defina XPZ_FAXINA_SELFTEST_LIXEIRA=1; ele envia um item de teste a Lixeira e o
  restaura pelo verbo da propria Lixeira.

  Casos: A lockstep do motor (SchemaVersion 2 e campos); B dry-run gera plano e nao
  apaga; C -Apply com plano remove frente e cascata; D -Apply sem plano -> blocked;
  E plano divergente -> blocked sem remover; F reparse -> blocked; G Scope=Frentes deixa
  orfao -> applied-with-skips; H exclusao -> applied-with-skips e preservado; I exclusao
  sem correspondencia -> blocked; J -WhatIf -> whatif; K backup (move-aside + jsonl) e
  combinacoes; L sidecar sai com o pacote e orfao so e reportado; M .rejected informativo;
  N totais inteiros; O raiz vazia -> clean; P PlanPath dentro da pasta-alvo -> blocked.
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
function Invoke-Engine {
  param([string]$Root)
  $out = & pwsh -NoProfile -File $engine '-RepoRoot' $Root 2>$null | Out-String
  return ($out | ConvertFrom-Json)
}
function Invoke-Cleanup {
  param([string[]]$Arguments)
  $out = & pwsh -NoProfile -File $exe @Arguments 2>$null | Out-String
  return [pscustomobject]@{ exit = $LASTEXITCODE; json = ($out | ConvertFrom-Json) }
}
function Assert-True { param([bool]$Cond, [string]$Message) if (-not $Cond) { throw "FALHA: $Message" } }

# Planeja (dry-run gravando o plano em pasta propria, fora das pastas-alvo)
$planDir = New-TempRoot -Slug 'planos'
function Invoke-Plan {
  param([string]$Root, [string[]]$Extra = @())
  $plan = Join-Path $planDir ("plano-{0}.json" -f ([guid]::NewGuid().ToString('N')))
  $r = Invoke-Cleanup -Arguments (@('-RepoRoot', $Root, '-PlanPath', $plan) + $Extra)
  return [pscustomobject]@{ r = $r; plan = $plan }
}
function Invoke-Apply {
  param([string]$Root, [string]$Plan, [string[]]$Extra = @())
  return Invoke-Cleanup -Arguments (@('-RepoRoot', $Root, '-Apply', '-JsonPath', $Plan) + $Extra)
}

try {
  # ===== A. lockstep do motor =====
  $a = New-TempRoot -Slug 'lockstep'
  New-Frente -Root $a -Name 'FrenteSemPadrao'
  New-Pacote -Root $a -File 'Inexistente_01.import_file.xml'
  $ja = Invoke-Engine -Root $a
  Assert-True ($ja.Kind -eq 'xpz-frente-hygiene-result') "A: Kind do motor"
  Assert-True ($ja.SchemaVersion -eq 2) "A: SchemaVersion do motor = 2; obtido $($ja.SchemaVersion)"
  Assert-True (@($ja.frentesNaoConformes) -contains 'FrenteSemPadrao') "A: frentesNaoConformes string[]"
  Assert-True (@($ja.pacotesOrfaos).Count -eq 1) "A: pacotesOrfaos"
  Assert-True (@($ja.pacotesVinculados | Where-Object { $_.frenteStatus -eq 'ausente' }).Count -eq 1) "A: pacotesVinculados marca frente ausente"
  Assert-True ($null -ne $ja.sidecarsOrfaos -and $null -ne $ja.pacotesRejeitados) "A: campos sidecarsOrfaos e pacotesRejeitados presentes"

  # ===== B. dry-run gera plano e nao apaga =====
  $b = New-TempRoot -Slug 'dry'
  New-Frente -Root $b -Name 'FrenteX'
  New-Pacote -Root $b -File 'FrenteX_01.import_file.xml'   # pacote de frente nao conforme (cascata)
  New-Pacote -Root $b -File 'Orfao_01.import_file.xml'     # orfao independente
  $pb = Invoke-Plan -Root $b
  Assert-True ($pb.r.exit -eq 2 -and $pb.r.json.status -eq 'findings') "B: exit 2 findings; obtido $($pb.r.json.status)"
  Assert-True (Test-Path -LiteralPath $pb.plan) "B: plano gravado"
  Assert-True (@($pb.r.json.items | Where-Object { $_.name -eq 'FrenteX_01.import_file.xml' }).Count -eq 1) "B: cascata (pacote da frente nao conforme) aparece no plano"
  Assert-True (Test-Path -LiteralPath (Join-Path $b "$FRENTES/FrenteX")) "B: dry-run NAO apagou a frente"

  # ===== C. -Apply com plano remove frente + cascata =====
  $c = New-TempRoot -Slug 'apply'
  New-Frente -Root $c -Name 'FrenteC'
  New-Pacote -Root $c -File 'FrenteC_01.import_file.xml'
  $pc = Invoke-Plan -Root $c -Extra @('-Permanente')
  $rc = Invoke-Apply -Root $c -Plan $pc.plan -Extra @('-Permanente')
  Assert-True ($rc.exit -eq 0 -and $rc.json.status -eq 'applied-clean') "C: applied-clean; obtido $($rc.json.status) blockers=$(@($rc.json.blockers) -join ';')"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $c "$FRENTES/FrenteC"))) "C: frente removida"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $c "$PACOTES/FrenteC_01.import_file.xml"))) "C: pacote da cascata removido"
  Assert-True ($rc.json.totalFrentesRemovidas -eq 1 -and $rc.json.totalPacotesRemovidos -eq 1) "C: totais removidos = 1 frente e 1 pacote"

  # ===== D. -Apply sem plano -> blocked =====
  $d = New-TempRoot -Slug 'semplano'
  New-Frente -Root $d -Name 'FrenteD'
  $rd = Invoke-Cleanup -Arguments @('-RepoRoot', $d, '-Apply')
  Assert-True ($rd.exit -eq 1 -and $rd.json.status -eq 'blocked') "D: -Apply sem -JsonPath -> blocked; obtido $($rd.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $d "$FRENTES/FrenteD")) "D: nada removido"

  # ===== E. plano divergente -> blocked =====
  $e = New-TempRoot -Slug 'divergente'
  New-Frente -Root $e -Name 'FrenteE'
  $pe = Invoke-Plan -Root $e -Extra @('-Permanente')
  New-Pacote -Root $e -File 'Novo_01.import_file.xml'   # apareceu depois do dry-run
  $re = Invoke-Apply -Root $e -Plan $pe.plan -Extra @('-Permanente')
  Assert-True ($re.exit -eq 1 -and $re.json.status -eq 'blocked') "E: plano divergente -> blocked; obtido $($re.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $e "$FRENTES/FrenteE")) "E: frente planejada intacta"
  Assert-True (Test-Path -LiteralPath (Join-Path $e "$PACOTES/Novo_01.import_file.xml")) "E: item novo intacto"

  # ===== F. reparse-point -> blocked no plano =====
  $f = New-TempRoot -Slug 'reparse'
  $target = New-TempRoot -Slug 'reparse-target'
  Write-File -Path (Join-Path $target 'sentinela.txt') -Content 'NAO APAGAR'
  [void](New-Item -ItemType Directory -Path (Join-Path $f $FRENTES) -Force)
  $link = Join-Path $f "$FRENTES/FrenteJunction"
  [void](New-Item -ItemType Junction -Path $link -Value $target)
  $pf = Invoke-Plan -Root $f
  Assert-True ($pf.r.exit -eq 1 -and $pf.r.json.status -eq 'blocked') "F: junction -> blocked; obtido $($pf.r.json.status)"
  Assert-True (Test-Path -LiteralPath $link) "F: junction intacta"
  Assert-True (Test-Path -LiteralPath (Join-Path $target 'sentinela.txt')) "F: alvo do junction intacto"

  # ===== G. Scope=Frentes deixa orfao -> applied-with-skips =====
  $g = New-TempRoot -Slug 'scope'
  New-Frente -Root $g -Name 'FrenteG'
  New-Pacote -Root $g -File 'Orfao_01.import_file.xml'
  $pg = Invoke-Plan -Root $g -Extra @('-Scope', 'Frentes', '-Permanente')
  $rg = Invoke-Apply -Root $g -Plan $pg.plan -Extra @('-Scope', 'Frentes', '-Permanente')
  Assert-True ($rg.exit -eq 3 -and $rg.json.status -eq 'applied-with-skips') "G: orfao fora do escopo -> applied-with-skips; obtido $($rg.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $g "$PACOTES/Orfao_01.import_file.xml")) "G: orfao preservado"

  # ===== H. exclusao de pacote -> applied-with-skips e preservado =====
  $h = New-TempRoot -Slug 'excl'
  New-Frente -Root $h -Name 'FrenteH'
  New-Pacote -Root $h -File 'Orfao_01.import_file.xml'
  $ph = Invoke-Plan -Root $h -Extra @('-Permanente', '-ExcludePacote', 'Orfao_01.import_file.xml')
  $rh = Invoke-Apply -Root $h -Plan $ph.plan -Extra @('-Permanente', '-ExcludePacote', 'Orfao_01.import_file.xml')
  Assert-True ($rh.exit -eq 3 -and $rh.json.status -eq 'applied-with-skips') "H: exclusao -> applied-with-skips; obtido $($rh.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $h "$PACOTES/Orfao_01.import_file.xml")) "H: pacote excluido preservado"
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $h "$FRENTES/FrenteH"))) "H: frente nao excluida removida"

  # ===== I. exclusao sem correspondencia -> blocked =====
  $i = New-TempRoot -Slug 'unmatched'
  New-Frente -Root $i -Name 'FrenteI'
  $ri = Invoke-Cleanup -Arguments @('-RepoRoot', $i, '-ExcludePacote', 'NaoExiste_01.import_file.xml')
  Assert-True ($ri.exit -eq 1 -and $ri.json.status -eq 'blocked') "I: exclusao sem correspondencia -> blocked; obtido $($ri.json.status)"

  # ===== J. -WhatIf -> whatif, nada removido =====
  $j = New-TempRoot -Slug 'whatif'
  New-Frente -Root $j -Name 'FrenteJ'
  $pj = Invoke-Plan -Root $j -Extra @('-Permanente')
  $rj = Invoke-Apply -Root $j -Plan $pj.plan -Extra @('-Permanente', '-WhatIf')
  Assert-True ($rj.exit -eq 0 -and $rj.json.status -eq 'whatif') "J: -WhatIf -> whatif; obtido $($rj.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $j "$FRENTES/FrenteJ")) "J: -WhatIf nao removeu"

  # ===== K. backup: move-aside, jsonl, combinacoes =====
  $k = New-TempRoot -Slug 'backup'
  New-Frente -Root $k -Name 'FrenteK'
  New-Pacote -Root $k -File 'OrfK_01.import_file.xml'
  $bk = New-TempRoot -Slug 'backup-dest'
  $pk = Invoke-Plan -Root $k -Extra @('-Backup', $bk, '-RunStamp', 'run001')
  $rk = Invoke-Apply -Root $k -Plan $pk.plan -Extra @('-Backup', $bk, '-RunStamp', 'run001')
  Assert-True ($rk.json.status -eq 'applied-clean') "K: backup applied-clean; obtido $($rk.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $bk 'run001/frentes/FrenteK')) "K: frente movida"
  Assert-True (Test-Path -LiteralPath (Join-Path $bk 'run001/pacotes/OrfK_01.import_file.xml')) "K: pacote movido"
  Assert-True (Test-Path -LiteralPath (Join-Path $bk 'run001/backup-manifest.jsonl')) "K: manifesto jsonl gravado"
  $k2 = Invoke-Cleanup -Arguments @('-RepoRoot', (New-TempRoot -Slug 'k2'), '-Backup', (New-TempRoot -Slug 'k2b'))
  Assert-True ($k2.exit -eq 1 -and $k2.json.status -eq 'blocked') "K2: -Backup sem -RunStamp -> blocked"
  $k3root = New-TempRoot -Slug 'k3'
  New-Frente -Root $k3root -Name 'FrenteK3'
  $k3 = Invoke-Cleanup -Arguments @('-RepoRoot', $k3root, '-Backup', (Join-Path $k3root $FRENTES), '-RunStamp', 'r')
  Assert-True ($k3.exit -eq 1 -and $k3.json.status -eq 'blocked') "K3: -Backup dentro de frentesDir -> blocked"
  $k4bk = New-TempRoot -Slug 'k4'
  Write-File -Path (Join-Path $k4bk 'run001/ocupado.txt') -Content 'x'
  $k4 = Invoke-Cleanup -Arguments @('-RepoRoot', (New-TempRoot -Slug 'k4root'), '-Backup', $k4bk, '-RunStamp', 'run001')
  Assert-True ($k4.exit -eq 1 -and $k4.json.status -eq 'blocked') "K4: subdir de backup nao vazio -> blocked"
  $kl = Invoke-Cleanup -Arguments @('-RepoRoot', (New-TempRoot -Slug 'kl'), '-Permanente', '-Backup', (New-TempRoot -Slug 'klb'), '-RunStamp', 'r')
  Assert-True ($kl.exit -eq 1 -and $kl.json.status -eq 'blocked') "K-L: -Permanente com -Backup -> blocked"

  # ===== L. sidecar sai com o pacote; orfao so e reportado =====
  $l = New-TempRoot -Slug 'sidecar'
  New-Frente -Root $l -Name 'FrenteL'
  New-Pacote -Root $l -File 'FrenteL_01.import_file.xml'
  Write-File -Path (Join-Path $l "$PACOTES/FrenteL_01.import_file.xml.package-inventory.json") -Content '{}'
  Write-File -Path (Join-Path $l "$PACOTES/Solto_02.import_file.xml.package-inventory.json") -Content '{}'
  $pl = Invoke-Plan -Root $l -Extra @('-Permanente')
  $rl = Invoke-Apply -Root $l -Plan $pl.plan -Extra @('-Permanente')
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $l "$PACOTES/FrenteL_01.import_file.xml.package-inventory.json"))) "L: sidecar removido junto com o pacote"
  Assert-True (Test-Path -LiteralPath (Join-Path $l "$PACOTES/Solto_02.import_file.xml.package-inventory.json")) "L: sidecar orfao preservado"
  Assert-True (@($rl.json.sidecarsOrfaos) -contains 'Solto_02.import_file.xml.package-inventory.json') "L: sidecar orfao reportado"
  Assert-True ($rl.json.status -eq 'applied-clean') "L: sidecar orfao informativo nao muda status; obtido $($rl.json.status)"

  # ===== M. .rejected informativo =====
  $m = New-TempRoot -Slug 'rejected'
  New-Pacote -Root $m -File 'Frente_01.import_file.xml.rejected.A'
  New-Pacote -Root $m -File 'Frente_01.import_file.xml.rejected.B'
  $rm = Invoke-Engine -Root $m
  $contM = @($rm.pacotesRejeitados | Where-Object { $_.base -eq 'Frente_01.import_file.xml' })
  Assert-True ($contM.Count -eq 1 -and $contM[0].contagem -eq 2) "M: rejeitados contados por nome-base"
  $mRun = Invoke-Cleanup -Arguments @('-RepoRoot', $m)
  Assert-True ($mRun.exit -eq 0 -and $mRun.json.status -eq 'clean') "M: rejeitados nao alteram o status do dry-run; obtido $($mRun.json.status)"

  # ===== O. raiz vazia -> clean =====
  $o = New-TempRoot -Slug 'vazia'
  [void](New-Item -ItemType Directory -Path (Join-Path $o $FRENTES) -Force)
  $ro = Invoke-Cleanup -Arguments @('-RepoRoot', $o)
  Assert-True ($ro.exit -eq 0 -and $ro.json.status -eq 'clean') "O: raiz sem achados -> clean"

  # ===== P. PlanPath dentro da pasta-alvo -> blocked =====
  $p = New-TempRoot -Slug 'planinside'
  New-Frente -Root $p -Name 'FrenteP'
  $rp = Invoke-Cleanup -Arguments @('-RepoRoot', $p, '-PlanPath', (Join-Path $p "$FRENTES/plano.json"))
  Assert-True ($rp.exit -eq 1 -and $rp.json.status -eq 'blocked') "P: PlanPath dentro de frentesDir -> blocked"

  # ===== Y. .rejected de pacote removido em cascata: mantido, informado, status inalterado =====
  $y = New-TempRoot -Slug 'rejcascata'
  New-Frente -Root $y -Name 'FrenteY'
  New-Pacote -Root $y -File 'FrenteY_01.import_file.xml'
  New-Pacote -Root $y -File 'FrenteY_01.import_file.xml.rejected.A'
  New-Pacote -Root $y -File 'Outro_09.import_file.xml.rejected.A'
  $py = Invoke-Plan -Root $y -Extra @('-Permanente')
  $ry = Invoke-Apply -Root $y -Plan $py.plan -Extra @('-Permanente')
  Assert-True ($ry.json.status -eq 'applied-clean' -and $ry.exit -eq 0) "Y: .rejected nao altera status; obtido $($ry.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $y "$PACOTES/FrenteY_01.import_file.xml.rejected.A")) "Y: .rejected preservado"
  Assert-True (@($ry.json.rejeitadosRestantes) -contains 'FrenteY_01.import_file.xml.rejected.A') "Y: rejeitado de pacote removido informado"
  Assert-True (-not (@($ry.json.rejeitadosRestantes) -contains 'Outro_09.import_file.xml.rejected.A')) "Y: rejeitado de pacote nao removido nao e informado"

  # ===== Q. frente com sufixo opcional e valida (nao entra no plano) =====
  $q = New-TempRoot -Slug 'sufixo'
  Write-File -Path (Join-Path $q "$FRENTES/${conforme}_ba03/Obj.xml") -Content '<Object />'
  $rq = Invoke-Cleanup -Arguments @('-RepoRoot', $q)
  Assert-True ($rq.exit -eq 0 -and $rq.json.status -eq 'clean') "Q: frente com sufixo _ba03 e valida -> clean; obtido $($rq.json.status)"

  # ===== R. -Permanente com arquivo em uso -> blocked, nada removido =====
  $rr = New-TempRoot -Slug 'lockperm'
  New-Frente -Root $rr -Name 'FrenteR'
  $prr = Invoke-Plan -Root $rr -Extra @('-Permanente')
  $heldR = [System.IO.File]::Open((Join-Path $rr "$FRENTES/FrenteR/Obj.xml"), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
  try { $rrr = Invoke-Apply -Root $rr -Plan $prr.plan -Extra @('-Permanente') } finally { $heldR.Close() }
  Assert-True ($rrr.exit -eq 1 -and $rrr.json.status -eq 'blocked') "R: -Permanente com arquivo em uso -> blocked; obtido $($rrr.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $rr "$FRENTES/FrenteR/Obj.xml")) "R: nada removido"

  # ===== S2. rename depois do dry-run -> blocked (identidade de caminhos) =====
  $rs2 = New-TempRoot -Slug 'rename'
  New-Frente -Root $rs2 -Name 'FrenteS2'
  $ps2 = Invoke-Plan -Root $rs2 -Extra @('-Permanente')
  Rename-Item -LiteralPath (Join-Path $rs2 "$FRENTES/FrenteS2/Obj.xml") -NewName 'Outro.xml'
  $rrs2 = Invoke-Apply -Root $rs2 -Plan $ps2.plan -Extra @('-Permanente')
  Assert-True ($rrs2.exit -eq 1 -and $rrs2.json.status -eq 'blocked') "S2: rename apos o plano -> blocked; obtido $($rrs2.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $rs2 "$FRENTES/FrenteS2/Outro.xml")) "S2: nada removido"

  # ===== T. destino de -Backup diferente do plano -> blocked =====
  $t = New-TempRoot -Slug 'bkdif'
  New-Frente -Root $t -Name 'FrenteT'
  $bkA = New-TempRoot -Slug 'bkA'
  $bkB = New-TempRoot -Slug 'bkB'
  $pt = Invoke-Plan -Root $t -Extra @('-Backup', $bkA, '-RunStamp', 'r1')
  $rt = Invoke-Apply -Root $t -Plan $pt.plan -Extra @('-Backup', $bkB, '-RunStamp', 'r1')
  Assert-True ($rt.exit -eq 1 -and $rt.json.status -eq 'blocked') "T: -Backup diferente do plano -> blocked; obtido $($rt.json.status)"
  Assert-True (Test-Path -LiteralPath (Join-Path $t "$FRENTES/FrenteT")) "T: nada movido"

  # ===== U. RunStamp com '..' -> blocked =====
  $u = Invoke-Cleanup -Arguments @('-RepoRoot', (New-TempRoot -Slug 'stamp'), '-Backup', (New-TempRoot -Slug 'stampb'), '-RunStamp', '..\x')
  Assert-True ($u.exit -eq 1 -and $u.json.status -eq 'blocked') "U: RunStamp com '..' -> blocked"

  # ===== V. -WhatIf na dry-run nao grava o plano =====
  $v = New-TempRoot -Slug 'whatifplan'
  New-Frente -Root $v -Name 'FrenteV'
  $planV = Join-Path $planDir ("plano-whatif-{0}.json" -f ([guid]::NewGuid().ToString('N')))
  [void](Invoke-Cleanup -Arguments @('-RepoRoot', $v, '-PlanPath', $planV, '-WhatIf'))
  Assert-True (-not (Test-Path -LiteralPath $planV)) "V: -WhatIf nao gravou o plano"

  # ===== W. -PlanPath ja existente -> blocked (nao sobrescreve) =====
  $w = New-TempRoot -Slug 'planexist'
  New-Frente -Root $w -Name 'FrenteW'
  $planW = Join-Path $planDir ("plano-existe-{0}.json" -f ([guid]::NewGuid().ToString('N')))
  Write-File -Path $planW -Content 'sentinela'
  $rw = Invoke-Cleanup -Arguments @('-RepoRoot', $w, '-PlanPath', $planW)
  Assert-True ($rw.exit -eq 1 -and $rw.json.status -eq 'blocked') "W: PlanPath existente -> blocked"
  Assert-True ((Get-Content -LiteralPath $planW -Raw).Trim() -eq 'sentinela') "W: arquivo existente preservado"

  # ===== X. exclusao com caixa diferente da do alvo =====
  $x = New-TempRoot -Slug 'casing'
  New-Frente -Root $x -Name 'FrenteX'
  New-Pacote -Root $x -File 'Orfao_01.import_file.xml'
  $px = Invoke-Plan -Root $x -Extra @('-Permanente', '-ExcludePacote', 'orfao_01.import_file.xml')
  $rx = Invoke-Apply -Root $x -Plan $px.plan -Extra @('-Permanente', '-ExcludePacote', 'orfao_01.import_file.xml')
  Assert-True ($rx.exit -eq 3 -and (Test-Path -LiteralPath (Join-Path $x "$PACOTES/Orfao_01.import_file.xml"))) "X: exclusao com caixa diferente preservada; obtido $($rx.json.status)"

  # ===== S. Lixeira real (opt-in) =====
  if ($env:XPZ_FAXINA_SELFTEST_LIXEIRA -eq '1') {
    # S0: arquivo em uso por outro processo -> blocked antes de qualquer envio
    $s0 = New-TempRoot -Slug 'lixeira-lock'
    New-Frente -Root $s0 -Name 'FrenteS0'
    $ps0 = Invoke-Plan -Root $s0
    $held = [System.IO.File]::Open((Join-Path $s0 "$FRENTES/FrenteS0/Obj.xml"), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
    try { $rs0 = Invoke-Apply -Root $s0 -Plan $ps0.plan } finally { $held.Close() }
    Assert-True ($rs0.json.status -eq 'blocked') "S0: arquivo em uso -> blocked; obtido $($rs0.json.status)"
    Assert-True (Test-Path -LiteralPath (Join-Path $s0 "$FRENTES/FrenteS0")) "S0: nada removido"

    $s = New-TempRoot -Slug 'lixeira'
    New-Frente -Root $s -Name 'FrenteS'
    $ps = Invoke-Plan -Root $s
    $rs = Invoke-Apply -Root $s -Plan $ps.plan
    Assert-True ($rs.json.status -eq 'applied-clean') "S: Lixeira applied-clean; obtido $($rs.json.status) blockers=$(@($rs.json.blockers) -join ';')"
    Assert-True (@($rs.json.items | Where-Object { $_.result -eq 'recycle-verified' }).Count -eq 1) "S: envio verificado"
    # restaura o item pelo verbo da propria Lixeira
    $shell = New-Object -ComObject Shell.Application
    $bin = $shell.Namespace(10)
    $it = $bin.Items() | Where-Object { $_.Name -eq 'FrenteS' } | Select-Object -First 1
    if ($it) {
      $v = $it.Verbs() | Where-Object { ($_.Name -replace '&', '') -match '^(Restaurar|Restore)$' } | Select-Object -First 1
      if ($v) { $v.DoIt() }
    }
    for ($tries = 0; $tries -lt 20 -and -not (Test-Path -LiteralPath (Join-Path $s "$FRENTES/FrenteS")); $tries++) { Start-Sleep -Milliseconds 500 }
    Assert-True (Test-Path -LiteralPath (Join-Path $s "$FRENTES/FrenteS")) "S: item restaurado da Lixeira"
  }

  'XPZ_KB_FRENTE_HYGIENE_CLEANUP_SELFTEST_OK'
}
finally {
  foreach ($r in $tmpRoots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
