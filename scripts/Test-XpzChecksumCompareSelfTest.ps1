#requires -Version 7.4
<#
.SYNOPSIS
  Self-test do motor Compare-XpzChecksums.ps1 (filtro F1 da Fase 2b da rotina
  pre-push de pasta paralela de KB). Sentinela: XPZ_CHECKSUM_COMPARE_SELFTEST_OK.

.DESCRIPTION
  Cobre a classificacao por checksum (atributo do <Object> raiz) sobre um repo
  git de fixture:
    SAME        - checksum identico entre BaseRef e HEAD (mudou so o lastUpdate).
    DIFF        - checksum mudou.
    NEW         - arquivo novo no HEAD.
    DELETED     - arquivo removido no HEAD.
    NO_CHECKSUM - checksum ausente nos dois lados (arquivo no diff sem atributo).
    unknown     - BaseRef inexistente -> status unknown, exit 3.
  F1 nunca bloqueia: status 'ok', exit 0 (exceto unknown).
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'XpzKbPrePushSelfTestSupport.ps1')

$engine = Join-Path $PSScriptRoot 'Compare-XpzChecksums.ps1'
$repos = [System.Collections.Generic.List[string]]::new()

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}
function Get-StatusFor {
  param($Json, [string]$PathSuffix)
  return @($Json.results | Where-Object { $_.path -like "*$PathSuffix" })[0].status
}
function New-Obj {
  param([string]$Name, [string]$Checksum, [string]$LastUpdate)
  return "<Object name=`"$Name`" checksum=`"$Checksum`" lastUpdate=`"$LastUpdate`" />"
}
function New-ObjNoChecksum {
  param([string]$Name, [string]$LastUpdate)
  return "<Object name=`"$Name`" lastUpdate=`"$LastUpdate`" />"
}

try {
  $root = New-XpzPrePushSelfTestRepo -Slug 'checksums'; $repos.Add($root)
  $acervo = 'ObjetosDaKbEmXml/Transaction'
  Set-XpzPrePushSelfTestFile -Root $root -RelPath "$acervo/Same.xml" -Content (New-Obj -Name 'Same' -Checksum 'aaa' -LastUpdate '2020-01-01')
  Set-XpzPrePushSelfTestFile -Root $root -RelPath "$acervo/Diff.xml" -Content (New-Obj -Name 'Diff' -Checksum 'bbb' -LastUpdate '2020-01-01')
  Set-XpzPrePushSelfTestFile -Root $root -RelPath "$acervo/Del.xml"  -Content (New-Obj -Name 'Del'  -Checksum 'ccc' -LastUpdate '2020-01-01')
  Set-XpzPrePushSelfTestFile -Root $root -RelPath "$acervo/NoChk.xml" -Content (New-ObjNoChecksum -Name 'NoChk' -LastUpdate '2020-01-01')
  $base = New-XpzPrePushSelfTestCommit -Root $root -Message 'base: acervo'

  # HEAD: SAME (checksum igual, lastUpdate diferente), DIFF (checksum muda),
  # DELETED (Del.xml removido), NEW (New.xml adicionado),
  # NO_CHECKSUM (NoChk.xml sem checksum nos dois lados, lastUpdate muda).
  Set-XpzPrePushSelfTestFile -Root $root -RelPath "$acervo/Same.xml" -Content (New-Obj -Name 'Same' -Checksum 'aaa' -LastUpdate '2026-06-14')
  Set-XpzPrePushSelfTestFile -Root $root -RelPath "$acervo/Diff.xml" -Content (New-Obj -Name 'Diff' -Checksum 'ddd' -LastUpdate '2026-06-14')
  Remove-XpzPrePushSelfTestPath -Root $root -RelPath "$acervo/Del.xml"
  Set-XpzPrePushSelfTestFile -Root $root -RelPath "$acervo/New.xml" -Content (New-Obj -Name 'New' -Checksum 'eee' -LastUpdate '2026-06-14')
  Set-XpzPrePushSelfTestFile -Root $root -RelPath "$acervo/NoChk.xml" -Content (New-ObjNoChecksum -Name 'NoChk' -LastUpdate '2026-06-14')
  [void](New-XpzPrePushSelfTestCommit -Root $root -Message 'head: SAME/DIFF/DELETED/NEW/NO_CHECKSUM')

  $r = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $base)
  Assert-True ($r.exit -eq 0) "F1: exit 0 esperado; obtido $($r.exit)"
  Assert-True ($r.json.status -eq 'ok') "F1: status ok esperado; obtido $($r.json.status)"
  Assert-True ((Get-StatusFor $r.json 'Same.xml') -eq 'SAME') "F1: Same.xml deveria ser SAME; obtido $(Get-StatusFor $r.json 'Same.xml')"
  Assert-True ((Get-StatusFor $r.json 'Diff.xml') -eq 'DIFF') "F1: Diff.xml deveria ser DIFF; obtido $(Get-StatusFor $r.json 'Diff.xml')"
  Assert-True ((Get-StatusFor $r.json 'Del.xml')  -eq 'DELETED') "F1: Del.xml deveria ser DELETED; obtido $(Get-StatusFor $r.json 'Del.xml')"
  Assert-True ((Get-StatusFor $r.json 'New.xml')  -eq 'NEW') "F1: New.xml deveria ser NEW; obtido $(Get-StatusFor $r.json 'New.xml')"
  Assert-True ((Get-StatusFor $r.json 'NoChk.xml') -eq 'NO_CHECKSUM') "F1: NoChk.xml deveria ser NO_CHECKSUM; obtido $(Get-StatusFor $r.json 'NoChk.xml')"

  # --- unknown: BaseRef inexistente ---
  $u = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', 'ref-que-nao-existe')
  Assert-True ($u.exit -eq 3) "unknown: exit 3 esperado; obtido $($u.exit)"
  Assert-True ($u.json.status -eq 'unknown') "unknown: status unknown esperado; obtido $($u.json.status)"

  'XPZ_CHECKSUM_COMPARE_SELFTEST_OK'
}
finally {
  foreach ($r in $repos) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
