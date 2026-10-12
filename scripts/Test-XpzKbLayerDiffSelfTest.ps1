#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do motor Test-XpzKbLayerDiff.ps1 (gates K3/K4 da rotina pre-push de
  pasta paralela de KB). Sentinela de sucesso: XPZ_KB_LAYER_DIFF_SELFTEST_OK.

.DESCRIPTION
  Cobre os caminhos do motor sobre um repo git de fixture:
    A. Limpo: diff fora de indice/acervo -> status ok, exit 0.
    K3. Arquivo de KbIntelligence/ no diff -> K3 warn, status warn.
    K4-warn. Acervo tocado SEM commit de metadata no intervalo -> K4 warn.
    K4-ok. Acervo + kb-source-metadata.md no mesmo commit -> K4 ok.
    unknown. BaseRef inexistente -> status unknown, exit 3.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'XpzKbPrePushSelfTestSupport.ps1')

$engine = Join-Path $PSScriptRoot 'Test-XpzKbLayerDiff.ps1'
$repos = [System.Collections.Generic.List[string]]::new()

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}
function Get-Gate {
  param($Json, [string]$Name)
  return @($Json.gates | Where-Object { $_.gate -eq $Name })[0]
}

try {
  $root = New-XpzPrePushSelfTestRepo -Slug 'layerdiff'; $repos.Add($root)
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'README.md' -Content "fixture`n"
  $base = New-XpzPrePushSelfTestCommit -Root $root -Message 'base'

  # --- A: limpo (so README muda) ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'README.md' -Content "fixture v2`n"
  $headA = New-XpzPrePushSelfTestCommit -Root $root -Message 'A: neutro'
  $a = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $base)
  Assert-True ($a.exit -eq 0) "A: exit 0 esperado; obtido $($a.exit)"
  Assert-True ($a.json.status -eq 'ok') "A: status ok esperado; obtido $($a.json.status)"

  # --- K3: KbIntelligence/ no diff -> warn ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'KbIntelligence/kb-intelligence.sqlite' -Content 'fake-sqlite'
  $headK3 = New-XpzPrePushSelfTestCommit -Root $root -Message 'K3: indice no diff'
  $k3r = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $headA)
  Assert-True ($k3r.json.status -eq 'warn') "K3: status warn esperado; obtido $($k3r.json.status)"
  Assert-True ((Get-Gate $k3r.json 'K3').status -eq 'warn') "K3: gate K3 warn esperado"

  # --- K4-warn: acervo sem metadata no intervalo ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'ObjetosDaKbEmXml/Transaction/Cliente.xml' -Content '<Object name="Cliente" />'
  $headK4w = New-XpzPrePushSelfTestCommit -Root $root -Message 'K4: acervo sem metadata'
  $k4w = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $headK3)
  Assert-True ((Get-Gate $k4w.json 'K4').status -eq 'warn') "K4-warn: gate K4 warn esperado; obtido $((Get-Gate $k4w.json 'K4').status)"

  # --- K4-ok: acervo + kb-source-metadata.md no mesmo commit ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'ObjetosDaKbEmXml/Transaction/Cliente.xml' -Content '<Object name="Cliente" v="2" />'
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'kb-source-metadata.md' -Content "last_xpz_materialization_run_at: 2026-06-14T00:00:00Z`n"
  $headK4ok = New-XpzPrePushSelfTestCommit -Root $root -Message 'K4: acervo + metadata (sync plausivel)'
  $k4ok = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $headK4w)
  Assert-True ((Get-Gate $k4ok.json 'K4').status -eq 'ok') "K4-ok: gate K4 ok esperado; obtido $((Get-Gate $k4ok.json 'K4').status)"

  # --- unknown: BaseRef inexistente ---
  $u = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', 'ref-que-nao-existe')
  Assert-True ($u.exit -eq 3) "unknown: exit 3 esperado; obtido $($u.exit)"
  Assert-True ($u.json.status -eq 'unknown') "unknown: status unknown esperado; obtido $($u.json.status)"

  'XPZ_KB_LAYER_DIFF_SELFTEST_OK'
}
finally {
  foreach ($r in $repos) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
