#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do motor Test-XpzNotNotIsAntipattern.ps1 (gate K11 da rotina pre-push
  de pasta paralela de KB). Sentinela de sucesso: XPZ_NOT_NOT_ANTIPATTERN_SELFTEST_OK.

.DESCRIPTION
  Cobre os caminhos do motor sobre um repo git de fixture:
    A. XML do acervo sem o antipattern no diff -> status ok, exit 0.
    B. <Source> com `not not X.IsNull()` -> status block, exit 1, finding registrado.
    C. Antipattern em linha de comentario (// ...) -> filtrado, status ok.
    unknown. BaseRef inexistente -> status unknown, exit 3.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'XpzKbPrePushSelfTestSupport.ps1')

$engine = Join-Path $PSScriptRoot 'Test-XpzNotNotIsAntipattern.ps1'
$repos = [System.Collections.Generic.List[string]]::new()

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}

function New-ProcXml {
  param([string]$Name, [string]$SourceBody)
  return "<Object type=`"Procedure`" name=`"$Name`"><Source>$SourceBody</Source></Object>"
}

try {
  $root = New-XpzPrePushSelfTestRepo -Slug 'notnot'; $repos.Add($root)
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'README.md' -Content "fixture`n"
  $base = New-XpzPrePushSelfTestCommit -Root $root -Message 'base'

  # --- A: limpo (sem antipattern) ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'ObjetosDaKbEmXml/Procedure/Limpo.xml' -Content (New-ProcXml -Name 'Limpo' -SourceBody 'if (&Cliente.IsNull()) return endif')
  $headA = New-XpzPrePushSelfTestCommit -Root $root -Message 'A: proc limpo'
  $a = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $base)
  Assert-True ($a.exit -eq 0) "A: exit 0 esperado; obtido $($a.exit)"
  Assert-True ($a.json.status -eq 'ok') "A: status ok esperado; obtido $($a.json.status)"

  # --- B: antipattern not not -> block ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'ObjetosDaKbEmXml/Procedure/Bug.xml' -Content (New-ProcXml -Name 'Bug' -SourceBody 'if (not not Cliente.IsNull()) msg(1) endif')
  $headB = New-XpzPrePushSelfTestCommit -Root $root -Message 'B: antipattern'
  $b = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $headA)
  Assert-True ($b.exit -eq 1) "B: exit 1 esperado; obtido $($b.exit)"
  Assert-True ($b.json.status -eq 'block') "B: status block esperado; obtido $($b.json.status)"
  Assert-True (@($b.json.findings).Count -ge 1) "B: ao menos 1 finding esperado"

  # --- C: antipattern em comentario -> filtrado ---
  Set-XpzPrePushSelfTestFile -Root $root -RelPath 'ObjetosDaKbEmXml/Procedure/Comentado.xml' -Content (New-ProcXml -Name 'Comentado' -SourceBody "// not not Cliente.IsNull() comentado")
  $headC = New-XpzPrePushSelfTestCommit -Root $root -Message 'C: comentario'
  $c = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', $headB)
  Assert-True ($c.json.status -eq 'ok') "C: status ok esperado (comentario filtrado); obtido $($c.json.status)"

  # --- unknown: BaseRef inexistente ---
  $u = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-BaseRef', 'ref-que-nao-existe')
  Assert-True ($u.exit -eq 3) "unknown: exit 3 esperado; obtido $($u.exit)"
  Assert-True ($u.json.status -eq 'unknown') "unknown: status unknown esperado; obtido $($u.json.status)"

  'XPZ_NOT_NOT_ANTIPATTERN_SELFTEST_OK'
}
finally {
  foreach ($r in $repos) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
