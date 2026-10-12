#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do motor Test-XpzKbDangerousPaths.ps1 (gates K1/K2 da rotina pre-push
  de pasta paralela de KB). Sentinela de sucesso: XPZ_KB_DANGEROUS_PATHS_SELFTEST_OK.

.DESCRIPTION
  Cobre os caminhos do motor sobre um repo git de fixture:
    A. Limpo: diff sem pasta descartavel nem pasta nativa -> status ok, exit 0.
    B. K1: arquivo sob Temp/ no diff -> K1 block, status block, exit 1.
    C. K2: path sob GxModels/ no diff -> K2 block, status block, exit 1.
    D. Falha de git (BaseRef inexistente) -> status unknown, exit 3 (nunca "0 achados").
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'XpzKbPrePushSelfTestSupport.ps1')

$engine = Join-Path $PSScriptRoot 'Test-XpzKbDangerousPaths.ps1'
$repos = [System.Collections.Generic.List[string]]::new()

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}

try {
  $root = New-XpzPrePushSelfTestRepo -Slug 'dangerouspaths'; $repos.Add($root)
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'README.md' -Content "fixture`n"
  $base = New-XpzPrePushSelfTestCommit -Root $root -Message 'base'

  # --- A: limpo ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'ObjetosDaKbEmXml/Transaction/Cliente.xml' -Content '<Object />'
  $headA = New-XpzPrePushSelfTestCommit -Root $root -Message 'A: acervo limpo'
  $a = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $base)
  Assert-True ($a.exit -eq 0) "A: exit 0 esperado; obtido $($a.exit)"
  Assert-True ($null -ne $a.json -and $a.json.status -eq 'ok') "A: status ok esperado; obtido $($a.json.status)"

  # --- B: K1 (Temp/) ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'Temp/lixo.txt' -Content 'nao versionar'
  $headB = New-XpzPrePushSelfTestCommit -Root $root -Message 'B: Temp no diff'
  $b = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $headA)
  Assert-True ($b.exit -eq 1) "B: exit 1 esperado; obtido $($b.exit)"
  Assert-True ($b.json.status -eq 'block') "B: status block esperado; obtido $($b.json.status)"
  $k1 = @($b.json.gates | Where-Object { $_.gate -eq 'K1' })[0]
  Assert-True ($k1.status -eq 'block') "B: K1 block esperado; obtido $($k1.status)"

  # --- C: K2 (GxModels/) ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'GxModels/MinhaKb/x.dat' -Content 'pasta nativa'
  $headC = New-XpzPrePushSelfTestCommit -Root $root -Message 'C: GxModels no diff'
  $c = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $headB)
  Assert-True ($c.exit -eq 1) "C: exit 1 esperado; obtido $($c.exit)"
  $k2 = @($c.json.gates | Where-Object { $_.gate -eq 'K2' })[0]
  Assert-True ($k2.status -eq 'block') "C: K2 block esperado; obtido $($k2.status)"

  # --- D: BaseRef inexistente -> unknown ---
  $d = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', 'ref-que-nao-existe')
  Assert-True ($d.exit -eq 3) "D: exit 3 esperado; obtido $($d.exit)"
  Assert-True ($d.json.status -eq 'unknown') "D: status unknown esperado; obtido $($d.json.status)"

  'XPZ_KB_DANGEROUS_PATHS_SELFTEST_OK'
}
finally {
  foreach ($r in $repos) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
