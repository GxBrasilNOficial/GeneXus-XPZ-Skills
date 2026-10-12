#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do motor Test-XpzKbFrenteHygiene.ps1 (Fase 2a estrutural da rotina
  pre-push de pasta paralela de KB). Sentinela: XPZ_KB_FRENTE_HYGIENE_SELFTEST_OK.

.DESCRIPTION
  Motor filesystem-only (sem git). Cobre:
    A. Frente conforme (NomeCurto_GUID_YYYYMMDD) + pacote com subpasta-fonte
       rastreavel -> status ok, exit 0.
    B. Frente fora do padrao + pacote orfao (sem subpasta-fonte) -> status warn,
       exit 2, frentesNaoConformes e pacotesOrfaos preenchidos.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$engine = Join-Path $PSScriptRoot 'Test-XpzKbFrenteHygiene.ps1'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$tmpRoots = [System.Collections.Generic.List[string]]::new()

function New-TempRoot {
  param([string]$Slug)
  $r = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-frente-$Slug-{0}" -f ([guid]::NewGuid().ToString('N')))
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
function Invoke-Engine {
  param([string]$Root)
  $stdout = & pwsh -NoProfile -File $engine '-RepoRoot' $Root 2>$null | Out-String
  return [pscustomobject]@{ exit = $LASTEXITCODE; json = ($stdout | ConvertFrom-Json) }
}
function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}

$frente = 'Refatora_11111111-1111-1111-1111-111111111111_20260101'

try {
  # --- A: conforme ---
  $a = New-TempRoot -Slug 'ok'
  Write-File -Path (Join-Path $a "ObjetosGeradosParaImportacaoNaKbNoGenexus/$frente/Obj.xml") -Content '<Object />'
  Write-File -Path (Join-Path $a "PacotesGeradosParaImportacaoNaKbNoGenexus/${frente}_01.import_file.xml") -Content '<ExportFile />'
  $ra = Invoke-Engine -Root $a
  Assert-True ($ra.exit -eq 0) "A: exit 0 esperado; obtido $($ra.exit)"
  Assert-True ($ra.json.status -eq 'ok') "A: status ok esperado; obtido $($ra.json.status)"
  Assert-True ($ra.json.frentesValidas -eq 1) "A: frentesValidas=1 esperado; obtido $($ra.json.frentesValidas)"
  Assert-True ($ra.json.pacotesOk -eq 1) "A: pacotesOk=1 esperado; obtido $($ra.json.pacotesOk)"
  # Contrato de saida (consumido por Remove-XpzKbFrenteHygieneFindings.ps1)
  Assert-True ($ra.json.Kind -eq 'xpz-frente-hygiene-result') "A: Kind esperado; obtido $($ra.json.Kind)"
  Assert-True ($ra.json.SchemaVersion -eq 1) "A: SchemaVersion=1 esperado; obtido $($ra.json.SchemaVersion)"
  Assert-True ([bool]$ra.json.frentesDir) "A: frentesDir resolvido esperado"
  Assert-True ([bool]$ra.json.pacotesDir) "A: pacotesDir resolvido esperado"
  Assert-True ([System.IO.Path]::IsPathRooted($ra.json.frentesDir)) "A: frentesDir absoluto esperado; obtido $($ra.json.frentesDir)"
  Assert-True ([System.IO.Path]::IsPathRooted($ra.json.pacotesDir)) "A: pacotesDir absoluto esperado; obtido $($ra.json.pacotesDir)"

  # --- B: frente fora do padrao + pacote orfao ---
  $b = New-TempRoot -Slug 'warn'
  Write-File -Path (Join-Path $b 'ObjetosGeradosParaImportacaoNaKbNoGenexus/FrenteSemPadrao/Obj.xml') -Content '<Object />'
  Write-File -Path (Join-Path $b 'PacotesGeradosParaImportacaoNaKbNoGenexus/OutraFrente_01.import_file.xml') -Content '<ExportFile />'
  $rb = Invoke-Engine -Root $b
  Assert-True ($rb.exit -eq 2) "B: exit 2 esperado; obtido $($rb.exit)"
  Assert-True ($rb.json.status -eq 'warn') "B: status warn esperado; obtido $($rb.json.status)"
  Assert-True (@($rb.json.frentesNaoConformes).Count -ge 1) "B: frentesNaoConformes esperado"
  Assert-True (@($rb.json.pacotesOrfaos).Count -ge 1) "B: pacotesOrfaos esperado"

  'XPZ_KB_FRENTE_HYGIENE_SELFTEST_OK'
}
finally {
  foreach ($r in $tmpRoots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
