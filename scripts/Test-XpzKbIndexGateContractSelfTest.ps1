#requires -Version 7.4

<#
.SYNOPSIS
  Self-test do CONTRATO -AsJson do motor Test-XpzKbIndexGate.ps1 (gate K9 da
  rotina pre-push de pasta paralela de KB). Sentinela:
  XPZ_KB_INDEX_GATE_CONTRACT_SELFTEST_OK.

.DESCRIPTION
  Foca o contrato consumido pelo orquestrador K9, nao o caminho verde (que exige
  SQLite real + assinatura de extrator). Sobre uma pasta sem estrutura/indice:
    A. -AsJson NUNCA lanca: bloqueio vira { status: BLOCK, reason } + exit 1
       (JSON parseavel), nao um throw.
    B. Default (texto) lanca BLOCK: exit nao-zero e sem JSON estruturado no stdout
       (caminho retrocompativel por grep GATE_OK).
  Uma fixture sintetica tambem chega a etapa de assinatura e simula a excecao
  PREREQUISITO AUSENTE: o modo texto deve prefixar BLOCK e o JSON deve preservar
  status BLOCK, exit 1 e a causa original.
  Fixtures com assinatura valida cobrem o estado da mascara:
    D. source_mask_degraded=true expoe o aviso em texto e JSON, sem bloquear.
    E. source_mask_degraded=false nao emite aviso.
    F. Metadata sem source_mask_degraded bloqueia (campo obrigatorio).
    G. Valores com sufixo (false-corrompido, true-lixo) bloqueiam; nao ha
       aceitacao por prefixo.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'XpzKbPrePushSelfTestSupport.ps1')

$engine = Join-Path $PSScriptRoot 'Test-XpzKbIndexGate.ps1'
$roots = [System.Collections.Generic.List[string]]::new()

function Assert-True {
  param([bool]$Cond, [string]$Message)
  if (-not $Cond) { throw "FALHA: $Message" }
}

try {
  # Pasta vazia (sem wrapper de estrutura, sem indice): o gate deve bloquear.
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-indexgate-{0}" -f ([guid]::NewGuid().ToString('N')))
  [void](New-Item -ItemType Directory -Path $root -Force); $roots.Add($root)

  # --- A: -AsJson nunca lanca -> { status: BLOCK, reason } + exit 1 ---
  $a = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root, '-AsJson')
  Assert-True ($a.exit -eq 1) "A: exit 1 esperado; obtido $($a.exit)"
  Assert-True ($null -ne $a.json) "A: stdout deveria ser JSON parseavel (contrato -AsJson nunca lanca)"
  Assert-True ($a.json.status -eq 'BLOCK') "A: status BLOCK esperado; obtido $($a.json.status)"
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$a.json.reason)) "A: reason deveria estar preenchido"

  # --- B: default (texto) lanca -> exit nao-zero, sem JSON estruturado ---
  $b = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $root)
  Assert-True ($b.exit -ne 0) "B: exit nao-zero esperado no caminho texto (throw BLOCK); obtido $($b.exit)"
  Assert-True ($null -eq $b.json -or $null -eq $b.json.status) "B: caminho texto nao deveria emitir JSON estruturado no stdout"

  # --- C: excecao na etapa de assinatura (simula Python ausente) ---
  $signatureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-indexgate-signature-{0}" -f ([guid]::NewGuid().ToString('N')))
  [void](New-Item -ItemType Directory -Path $signatureRoot -Force); $roots.Add($signatureRoot)
  $signatureIndexDir = Join-Path $signatureRoot 'KbIntelligence'
  [void](New-Item -ItemType Directory -Path $signatureIndexDir -Force)
  $structureWrapper = Join-Path $signatureRoot 'Test-KbStructure.ps1'
  $queryWrapper = Join-Path $signatureRoot 'Query-KbIntelligence.ps1'
  $signatureContract = Join-Path $signatureRoot 'GeneXusKbIntelligenceExtractorContract.ps1'
  $signatureMetadata = Join-Path $signatureIndexDir 'kb-intelligence.sqlite'
  $sourceMetadata = Join-Path $signatureRoot 'kb-source-metadata.md'
  [System.IO.File]::WriteAllText($signatureMetadata, '')
  [System.IO.File]::WriteAllText($sourceMetadata, 'last_xpz_materialization_run_at: 2026-10-02T11:00:00Z')
  [System.IO.File]::WriteAllLines($structureWrapper, [string[]]@("'STRUCTURE_OK'"), [System.Text.UTF8Encoding]::new($false))

  $queryLines = @(
    'param([string]$Query, [string]$Format)',
    '$metadata = @(',
    "  'last_index_build_run_at: 2026-10-02T12:00:00Z'",
    "  'inventory_validation_status: OK'",
    "  'writability_coverage: complete-in-model'",
    "  'writability_rows_expected: 0'",
    "  'writability_rows_written: 0'",
    "  'writability_rows_lost: 0'",
    ')',
    '$metadata -join "`n"'
  )
  [System.IO.File]::WriteAllLines($queryWrapper, [string[]]$queryLines, [System.Text.UTF8Encoding]::new($false))

  $contractLines = @(
    'function Get-GeneXusKbIntelligenceExtractorSignatureFromIndexMetadataText {',
    '  param([string]$IndexMetadataText)',
    '  return @{}',
    '}',
    'function Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata {',
    '  param([hashtable]$Metadata)',
    "  throw 'PREREQUISITO AUSENTE: Python 3 utilizavel nao encontrado no PATH.'",
    '}'
  )
  [System.IO.File]::WriteAllLines($signatureContract, [string[]]$contractLines, [System.Text.UTF8Encoding]::new($false))

  $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
  $textErrorPath = Join-Path $signatureRoot 'text-error.log'
  $textStdout = & $pwshPath -NoProfile -File $engine -RepoRoot $signatureRoot -StructureWrapperPath $structureWrapper -QueryWrapperPath $queryWrapper -ExtractorContractPath $signatureContract 2> $textErrorPath | Out-String
  $textExit = $LASTEXITCODE
  $textStderr = [System.IO.File]::ReadAllText($textErrorPath)
  Assert-True ($textExit -ne 0) "C: exit nao-zero esperado no caminho texto; obtido $textExit"
  Assert-True ($textStderr -match 'BLOCK:\s*PREREQUISITO AUSENTE') 'C: excecao de Python ausente deveria manter BLOCK: no modo texto'
  Assert-True ([string]::IsNullOrWhiteSpace($textStdout)) 'C: excecao no modo texto nao deveria emitir JSON ou sucesso no stdout'

  $pythonJson = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @('-RepoRoot', $signatureRoot, '-StructureWrapperPath', $structureWrapper, '-QueryWrapperPath', $queryWrapper, '-ExtractorContractPath', $signatureContract, '-AsJson')
  Assert-True ($pythonJson.exit -eq 1) "C: exit 1 esperado sob -AsJson; obtido $($pythonJson.exit)"
  Assert-True ($null -ne $pythonJson.json -and $pythonJson.json.status -eq 'BLOCK') 'C: excecao de Python ausente deveria virar status BLOCK sob -AsJson'
  Assert-True ([string]$pythonJson.json.reason -match '^PREREQUISITO AUSENTE:') 'C: JSON deveria preservar a causa original sem prefixo textual'

  # --- D/E/F: estado da mascara de Source no contrato do gate ---
  function New-IndexGateFixture {
    param([string[]]$ExtraMetadata = @())

    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-indexgate-mask-{0}" -f ([guid]::NewGuid().ToString('N')))
    [void](New-Item -ItemType Directory -Path $root -Force); $roots.Add($root)
    $indexDir = Join-Path $root 'KbIntelligence'
    [void](New-Item -ItemType Directory -Path $indexDir -Force)

    $structure = Join-Path $root 'Test-KbStructure.ps1'
    $query = Join-Path $root 'Query-KbIntelligence.ps1'
    $contract = Join-Path $root 'GeneXusKbIntelligenceExtractorContract.ps1'
    $utf8 = [System.Text.UTF8Encoding]::new($false)

    [System.IO.File]::WriteAllText((Join-Path $indexDir 'kb-intelligence.sqlite'), '', $utf8)
    [System.IO.File]::WriteAllText((Join-Path $root 'kb-source-metadata.md'), "last_xpz_materialization_run_at: 2026-10-02T11:00:00Z`n", $utf8)
    [System.IO.File]::WriteAllText($structure, "'STRUCTURE_OK'`n", $utf8)

    $metadataLines = @(
      "  'last_index_build_run_at: 2026-10-02T12:00:00Z'",
      "  'inventory_validation_status: OK'",
      "  'writability_coverage: complete-in-model'",
      "  'writability_rows_expected: 0'",
      "  'writability_rows_written: 0'",
      "  'writability_rows_lost: 0'"
    ) + $ExtraMetadata

    $queryTemplate = @'
param([string]$Query, [string]$Format)
$metadata = @(
__METADATA__
)
$metadata -join "`n"
'@
    [System.IO.File]::WriteAllText($query, $queryTemplate.Replace('__METADATA__', ($metadataLines -join "`n")), $utf8)

    $contractText = @'
function Get-GeneXusKbIntelligenceExtractorSignatureFromIndexMetadataText {
  param([string]$IndexMetadataText)
  return @{ extractor_signature_version = '19'; extractor_signature_hash = 'h'; extractor_signature_format = 'manifest-lf-v1' }
}
function Test-GeneXusKbIntelligenceExtractorSignatureFromMetadata {
  param([hashtable]$Metadata)
  return @{ ok = $true; summary = ''; stored = @{ extractor_signature_version = '19'; extractor_signature_hash = 'h'; extractor_signature_format = 'manifest-lf-v1' } }
}
'@
    [System.IO.File]::WriteAllText($contract, $contractText, $utf8)

    return [pscustomobject]@{
      Root = $root
      Structure = $structure
      Query = $query
      Contract = $contract
    }
  }

  $degradedFixture = New-IndexGateFixture -ExtraMetadata @(
    "  'source_mask_degraded: true'",
    "  'source_mask_degraded_blocks: [[`"Attribute/A.xml`",12,`"unterminated string`"]]'"
  )
  $rd = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-RepoRoot', $degradedFixture.Root,
    '-StructureWrapperPath', $degradedFixture.Structure,
    '-QueryWrapperPath', $degradedFixture.Query,
    '-ExtractorContractPath', $degradedFixture.Contract,
    '-AsJson')
  Assert-True ($rd.exit -eq 0) "D: exit 0 esperado com mascara degradada; obtido $($rd.exit)"
  Assert-True ($null -ne $rd.json -and $rd.json.status -eq 'OK') 'D: status OK esperado com mascara degradada'
  Assert-True ($rd.json.sourceMaskDegraded -eq $true) 'D: sourceMaskDegraded=true esperado'
  Assert-True ([string]$rd.json.sourceMaskDegradedWarning -match 'degradada') 'D: aviso de mascara degradada esperado'

  $maskTextErrorPath = Join-Path $degradedFixture.Root 'mask-text-error.log'
  $maskTextStdout = & $pwshPath -NoProfile -File $engine -RepoRoot $degradedFixture.Root -StructureWrapperPath $degradedFixture.Structure -QueryWrapperPath $degradedFixture.Query -ExtractorContractPath $degradedFixture.Contract 2> $maskTextErrorPath | Out-String
  $maskTextExit = $LASTEXITCODE
  Assert-True ($maskTextExit -eq 0) "D: exit 0 esperado no modo texto; obtido $maskTextExit"
  Assert-True ($maskTextStdout -match 'source_mask_degraded: true') 'D: modo texto deveria expor source_mask_degraded: true'
  Assert-True ($maskTextStdout -match 'source_mask_degraded_warning:') 'D: modo texto deveria expor o aviso de mascara'
  Assert-True ($maskTextStdout -match '\bGATE_OK\b') 'D: modo texto deveria manter GATE_OK'

  $cleanFixture = New-IndexGateFixture -ExtraMetadata @(
    "  'source_mask_degraded: false'",
    "  'source_mask_degraded_blocks: []'"
  )
  $re = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-RepoRoot', $cleanFixture.Root,
    '-StructureWrapperPath', $cleanFixture.Structure,
    '-QueryWrapperPath', $cleanFixture.Query,
    '-ExtractorContractPath', $cleanFixture.Contract,
    '-AsJson')
  Assert-True ($re.exit -eq 0) "E: exit 0 esperado sem degradacao; obtido $($re.exit)"
  Assert-True ($re.json.sourceMaskDegraded -eq $false) 'E: sourceMaskDegraded=false esperado'
  Assert-True ($null -eq $re.json.sourceMaskDegradedWarning) 'E: sem aviso quando a mascara nao esta degradada'

  $missingFixture = New-IndexGateFixture
  $rf = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
    '-RepoRoot', $missingFixture.Root,
    '-StructureWrapperPath', $missingFixture.Structure,
    '-QueryWrapperPath', $missingFixture.Query,
    '-ExtractorContractPath', $missingFixture.Contract,
    '-AsJson')
  Assert-True ($rf.exit -eq 1) "F: exit 1 esperado sem source_mask_degraded; obtido $($rf.exit)"
  Assert-True ($null -ne $rf.json -and $rf.json.status -eq 'BLOCK') 'F: status BLOCK esperado sem source_mask_degraded'
  Assert-True ([string]$rf.json.reason -match 'source_mask_degraded') 'F: motivo deveria citar source_mask_degraded'

  # --- G: valores invalidos nao podem ser aceitos por prefixo ---
  foreach ($invalidMaskValue in @('false-corrompido', 'true-lixo')) {
    $invalidFixture = New-IndexGateFixture -ExtraMetadata @(
      "  'source_mask_degraded: $invalidMaskValue'",
      "  'source_mask_degraded_blocks: []'"
    )
    $rg = Invoke-XpzSelfTestScript -ScriptPath $engine -ScriptArgs @(
      '-RepoRoot', $invalidFixture.Root,
      '-StructureWrapperPath', $invalidFixture.Structure,
      '-QueryWrapperPath', $invalidFixture.Query,
      '-ExtractorContractPath', $invalidFixture.Contract,
      '-AsJson')
    Assert-True ($rg.exit -eq 1) "G: exit 1 esperado para '$invalidMaskValue'; obtido $($rg.exit)"
    Assert-True ($null -ne $rg.json -and $rg.json.status -eq 'BLOCK') "G: status BLOCK esperado para '$invalidMaskValue'"
    Assert-True ([string]$rg.json.reason -match 'source_mask_degraded') "G: motivo deveria citar source_mask_degraded para '$invalidMaskValue'"
  }

  'XPZ_KB_INDEX_GATE_CONTRACT_SELFTEST_OK'
}
finally {
  foreach ($r in $roots) { Remove-Item -LiteralPath $r -Recurse -Force -ErrorAction SilentlyContinue }
}

exit 0
