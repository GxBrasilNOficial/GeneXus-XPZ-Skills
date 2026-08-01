#requires -Version 7.4
<#
.SYNOPSIS
  Orquestrador da Fase 1 (mecanica) da rotina pre-push de pasta paralela de KB
  GeneXus (skill xpz-kb-parallel-pre-push). Roda G0-G5 + K1-K4/K8/K9/K11 e
  consolida pushReadiness. NAO e a rotina pre-push do repositorio de skills (essa
  e o documento 13); valida o estado de uma PASTA PARALELA DE KB antes do push.

.DESCRIPTION
  Motor compartilhado, agnostico de KB. Os motores K1-K4/K11/F1 sao scripts irmaos
  em scripts/ da raiz das skills (mesma pasta deste orquestrador). Os wrappers K8/K9
  sao LOCAIS da pasta paralela, resolvidos por kb-parallel-pre-push.config.json
  (campos setupAuditWrapper/indexGateWrapper) com fallback por convencao e
  fail-closed; consumidos por CONTRATO ESTRUTURADO (-AsJson), nunca por grep de texto.

  Gates:
    G0 git fetch origin                       unknown se falhar (nao silenciado)
    G1 commitsBehind > 0                       block (unknown se BaseRef invalido)
    G2 branch != main                          warn
    G3 working tree com mudancas nao commitadas warn (ignora pasta do indice)
    G4 git diff --check (whitespace)           block, warn em acervo ou XML novo da frente
    G5 parse de *.ps1 em <RepoRoot>/scripts    block
    K1/K2 paths perigosos                      block   [Test-XpzKbDangerousPaths]
    K3/K4 camadas derivada/oficial             warn    [Test-XpzKbLayerDiff]
    K8 auditoria de setup (estruturado)        warn/block [wrapper local + Test-XpzSetupAudit]
    K9 gate de indice (estruturado)            block se nao OK [wrapper local]
    K11 antipattern not-not                    block   [Test-XpzNotNotIsAntipattern]

  CONTRATO DE SAIDA: JSON de maquina por padrao no stdout. -AsText da saida humana;
  -AsJson e no-op (JSON ja e o default). EXIT CODE: 0 ready, 2 warn, 1 blocked.

.PARAMETER BaseRef
  Referencia git base (default: origin/main).

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual).

.PARAMETER ConfigPath
  Caminho do kb-parallel-pre-push.config.json (default: <RepoRoot>/kb-parallel-pre-push.config.json).

.PARAMETER SkipFetch
  Pula git fetch origin (usa a BaseRef local atual, conscientemente).

.PARAMETER AsText
  Saida humana em texto em vez do JSON padrao.

.PARAMETER AsJson
  No-op: JSON ja e a saida padrao.

.EXAMPLE
  Invoke-XpzKbParallelPrePushPhase1.ps1 -RepoRoot C:\Dev\Prod\Gx_FabricaBrasil
#>
[CmdletBinding()]
param(
  [string]$BaseRef = 'origin/main',
  [string]$RepoRoot = (Get-Location).Path,
  [string]$ConfigPath,
  [switch]$SkipFetch,
  [switch]$AsText,
  [switch]$AsJson
)

Set-StrictMode -Version Latest

$sharedScripts = $PSScriptRoot
$localScripts = Join-Path $RepoRoot 'scripts'

# ---- Config ----
if (-not $ConfigPath) { $ConfigPath = Join-Path $RepoRoot 'kb-parallel-pre-push.config.json' }
$config = $null
$configFound = $false
if (Test-Path -LiteralPath $ConfigPath -PathType Leaf) {
  try { $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json; $configFound = $true } catch { $config = $null }
}

function Get-CfgProp {
  param($Object, [string]$Name)
  if ($null -ne $Object -and ($Object.PSObject.Properties.Name -contains $Name)) { return $Object.$Name }
  return $null
}
function Get-LayerToken {
  param([string]$Name, $Default)
  $lt = Get-CfgProp $config 'layerTokens'
  $v = Get-CfgProp $lt $Name
  if ($null -ne $v) { return $v }
  return $Default
}

$tempDirNames        = @(Get-LayerToken 'tempDirNames' @('Temp'))
$nativeKbRootPattern = [string](Get-LayerToken 'nativeKbRootPattern' '(?i)(^|[\\/])GxModels[\\/]')
$indexDirName        = [string](Get-LayerToken 'indexDirName' 'KbIntelligence')
$acervoDirName       = [string](Get-LayerToken 'acervoDirName' 'ObjetosDaKbEmXml')
$frontDirName        = [string](Get-LayerToken 'frontDirName' 'ObjetosGeradosParaImportacaoNaKbNoGenexus')
$metadataFileName    = [string](Get-LayerToken 'metadataFileName' 'kb-source-metadata.md')

$gates = [System.Collections.Generic.List[object]]::new()
function Add-Gate {
  param($Id, $Status, $Message, $Detail = $null)
  $gates.Add([pscustomobject]@{ id = $Id; status = $Status; message = $Message; detail = $Detail })
}

function Format-GateDetailForText {
  param($Detail)

  if ($null -eq $Detail) { return '' }
  if ($Detail -is [string]) { return $Detail }

  $propertyNames = @($Detail.PSObject.Properties.Name)
  if ($propertyNames -contains 'path' -and $propertyNames -contains 'line' -and $propertyNames -contains 'message') {
    $path = [string]$Detail.path
    $line = $Detail.line
    $message = [string]$Detail.message
    $classification = if ($propertyNames -contains 'classification') { [string]$Detail.classification } else { '' }

    if (-not [string]::IsNullOrWhiteSpace($path) -and $null -ne $line) {
      $rendered = "${path}:${line}: $message"
    } else {
      $rendered = $message
    }
    if (-not [string]::IsNullOrWhiteSpace($classification)) {
      $rendered = "$rendered [classification=$classification]"
    }
    return $rendered
  }

  try {
    return ($Detail | ConvertTo-Json -Depth 4 -Compress)
  } catch {
    return [string]$Detail
  }
}

function Resolve-LocalWrapper {
  param([string]$GateId, $ConfigName, [string]$Convention)
  if ($ConfigName) {
    $p = Join-Path $localScripts ([string]$ConfigName)
    if (Test-Path -LiteralPath $p -PathType Leaf) { return [pscustomobject]@{ ok = $true; path = $p; resolvedBy = 'config' } }
    return [pscustomobject]@{ ok = $false; resolvedBy = 'config'; message = "wrapper '$ConfigName' do config nao encontrado em $localScripts" }
  }
  $cands = @()
  if (Test-Path -LiteralPath $localScripts -PathType Container) {
    $cands = @(Get-ChildItem -LiteralPath $localScripts -Filter $Convention -File -ErrorAction SilentlyContinue)
  }
  if ($cands.Count -eq 1) { return [pscustomobject]@{ ok = $true; path = $cands[0].FullName; resolvedBy = 'convention' } }
  if ($cands.Count -eq 0) { return [pscustomobject]@{ ok = $false; resolvedBy = 'none'; message = "nenhum wrapper '$Convention' em $localScripts e sem config -- fail-closed" } }
  return [pscustomobject]@{ ok = $false; resolvedBy = 'ambiguous'; message = "$($cands.Count) wrappers '$Convention' em $localScripts e sem config para desambiguar -- fail-closed (declare em kb-parallel-pre-push.config.json)" }
}

function Normalize-GitPathForG4 {
  param([AllowEmptyString()][string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
  $p = ([string]$Path).Trim()
  if (($p.Length -ge 2) -and (($p[0] -eq '"' -and $p[$p.Length - 1] -eq '"') -or ($p[0] -eq "'" -and $p[$p.Length - 1] -eq "'"))) {
    $p = $p.Substring(1, $p.Length - 2)
  }
  $p = $p -replace '\\', '/'
  return $p.TrimStart('/')
}

function ConvertFrom-GitDiffCheckLine {
  param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)

  $raw = [string]$Line
  $text = $raw.Trim()
  if (($text.Length -ge 2) -and (($text[0] -eq '"' -and $text[$text.Length - 1] -eq '"') -or ($text[0] -eq "'" -and $text[$text.Length - 1] -eq "'"))) {
    $text = $text.Substring(1, $text.Length - 2)
  }
  $m = [regex]::Match($text, '^(.+?):(\d+):\s*(.+)$')
  if (-not $m.Success) {
    return [pscustomobject]@{ path = $null; line = $null; message = $raw; classification = 'unparsed' }
  }
  return [pscustomobject]@{
    path = (Normalize-GitPathForG4 -Path $m.Groups[1].Value)
    line = [int]$m.Groups[2].Value
    message = $m.Groups[3].Value
    classification = ''
  }
}

function Get-G4WhitespaceClassification {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)]$AddedPathSet,
    [Parameter(Mandatory)][string]$AcervoDirName,
    [Parameter(Mandatory)][string]$FrontDirName
  )

  $acervoPrefix = "$(Normalize-GitPathForG4 -Path $AcervoDirName)/"
  $frontPrefix = "$(Normalize-GitPathForG4 -Path $FrontDirName)/"
  if ($Path.StartsWith($acervoPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { return 'warn' }
  if ($Path.StartsWith($frontPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    if ($AddedPathSet.Contains($Path) -and $Path.EndsWith('.xml', [System.StringComparison]::OrdinalIgnoreCase)) { return 'warn' }
    return 'block'
  }
  return 'block'
}

# ---- G0: fetch ----
$fetchStatus = 'skipped'
if (-not $SkipFetch) {
  git -C $RepoRoot fetch origin 2>$null
  if ($LASTEXITCODE -ne 0) {
    $fetchStatus = 'failed'
    Add-Gate 'G0' 'unknown' "git fetch origin falhou (exit $LASTEXITCODE) -- BaseRef pode estar defasado contra o remoto; rode -SkipFetch para usar a ref local conscientemente"
  } else {
    $fetchStatus = 'ok'
  }
}

$range = "$BaseRef..HEAD"

# ---- G1: commitsBehind ----
$ahead = [int](git -C $RepoRoot rev-list --count "$BaseRef..HEAD" 2>$null)
$revExit = $LASTEXITCODE
if ($revExit -ne 0) {
  Add-Gate 'G1' 'unknown' "rev-list falhou (exit $revExit) para BaseRef '$BaseRef' -- ref inexistente?"
  $behind = $null
} else {
  $behind = [int](git -C $RepoRoot rev-list --count "HEAD..$BaseRef" 2>$null)
  if ($behind -gt 0) { Add-Gate 'G1' 'block' "commitsBehind=$behind -- push proibido ate integrar o remoto" }
  else { Add-Gate 'G1' 'ok' "commitsAhead=$ahead; commitsBehind=0" }
}

# ---- G2: branch ----
# Guarda contra $null: em detached HEAD (rebase/checkout de commit) o git nao
# retorna ramo -> .Trim() em null derrubaria o orquestrador sob StrictMode.
$branchRaw = git -C $RepoRoot branch --show-current 2>$null
$branch = if ($branchRaw) { ([string]$branchRaw).Trim() } else { '' }
if ($branch -ne 'main') { Add-Gate 'G2' 'warn' "branch=$branch (esperado: main)" }
else { Add-Gate 'G2' 'ok' 'branch=main' }

# ---- G3: working tree ----
$indexIgnore = "^\?\? $([regex]::Escape($indexDirName))/"
$dirty = @(git -C $RepoRoot status --porcelain 2>$null | Where-Object { $_ -notmatch $indexIgnore })
if ($dirty.Count -gt 0) { Add-Gate 'G3' 'warn' "$($dirty.Count) entrada(s) nao commitada(s) no working tree" $dirty }
else { Add-Gate 'G3' 'ok' "working tree limpo ($indexDirName/ untracked ignorado)" }

# ---- G4: diff --check ----
# Trailing whitespace em XMLs do acervo (default ObjetosDaKbEmXml/) vem do exportador
# do GeneXus IDE (saida de gerador, nao codigo humano) -- policy override declarada:
# warn, nao block. XML novo/adicionado na frente tambem fica warn nesta versao,
# porque G4 nao prova se o whitespace foi herdado ou introduzido; o 9-FD decide
# trim forte por baseline de GUID unico quando houver baseline. Arquivo rastreado
# modificado na frente e demais caminhos continuam block.
# Stringifica a saida (incl. stderr via 2>&1): evita ErrorRecord profundo no
# detail, que truncaria o JSON de maquina; mantem o -match por linha funcionando.
$diffCheck = @(git -C $RepoRoot -c core.quotePath=false diff --no-renames --check $range 2>&1 | ForEach-Object { $_.ToString() })
$diffCheckExit = $LASTEXITCODE
$addedPathsRaw = @(git -C $RepoRoot -c core.quotePath=false diff --no-renames --name-only --diff-filter=A $range 2>$null | ForEach-Object { $_.ToString() })
$addedPathSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($addedPath in $addedPathsRaw) {
  $normalizedAddedPath = Normalize-GitPathForG4 -Path $addedPath
  if (-not [string]::IsNullOrWhiteSpace($normalizedAddedPath)) { [void]$addedPathSet.Add($normalizedAddedPath) }
}
if ($diffCheckExit -ne 0) {
  $parsedLines = @($diffCheck | ForEach-Object { ConvertFrom-GitDiffCheckLine -Line $_ })
  $parseableLines = @($parsedLines | Where-Object { $_.classification -ne 'unparsed' })
  if ($parseableLines.Count -eq 0) {
    # exit != 0 sem nenhuma linha no formato de erro de whitespace = falha tecnica
    # do git (ex.: BaseRef/range invalido), NAO "0 erros". Nao mascarar como warn.
    Add-Gate 'G4' 'unknown' "git diff --check retornou exit $diffCheckExit sem linhas parseaveis de erro de whitespace -- BaseRef/range invalido?" $parsedLines
  } else {
    foreach ($line in $parseableLines) {
      $line.classification = Get-G4WhitespaceClassification -Path $line.path -AddedPathSet $addedPathSet -AcervoDirName $acervoDirName -FrontDirName $frontDirName
    }
    $blockHits = @($parseableLines | Where-Object { $_.classification -eq 'block' })
    $warnHits = @($parseableLines | Where-Object { $_.classification -eq 'warn' })
    if ($blockHits.Count -gt 0) {
      Add-Gate 'G4' 'block' "$($blockHits.Count) whitespace error(s) em arquivos que nao sao acervo nem XML novo/adicionado da frente" $parsedLines
    } elseif ($warnHits.Count -gt 0) {
      Add-Gate 'G4' 'warn' "$($warnHits.Count) whitespace error(s) apenas em acervo ou XML novo/adicionado da frente; nao limpar arquivo inteiro, corrigir so linhas novas/editadas; 9-FD decide trim forte quando houver baseline" $parsedLines
    } else {
      Add-Gate 'G4' 'unknown' 'git diff --check retornou linhas parseaveis, mas nenhuma classificacao G4 conhecida foi atribuida' $parsedLines
    }
  }
} else {
  Add-Gate 'G4' 'ok' 'sem whitespace errors'
}

# ---- G5: parse PS dos wrappers locais ----
$psFiles = @()
if (Test-Path -LiteralPath $localScripts -PathType Container) {
  $psFiles += Get-ChildItem -LiteralPath $localScripts -Filter '*.ps1' -File -ErrorAction SilentlyContinue
}
$parseErrors = @()
foreach ($pf in $psFiles) {
  $errs = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($pf.FullName, [ref]$null, [ref]$errs)
  if ($errs.Count -gt 0) {
    foreach ($e in $errs) { $parseErrors += "$($pf.Name):$($e.Extent.StartLineNumber) $($e.Message)" }
  }
}
if ($parseErrors.Count -gt 0) { Add-Gate 'G5' 'block' "$($parseErrors.Count) erro(s) de parse em $($psFiles.Count) .ps1 locais" $parseErrors }
else { Add-Gate 'G5' 'ok' "$($psFiles.Count) .ps1 locais parseados sem erros" }

# ---- K1/K2 ----
try {
  $k1k2 = & (Join-Path $sharedScripts 'Test-XpzKbDangerousPaths.ps1') -BaseRef $BaseRef -RepoRoot $RepoRoot -TempDirNames $tempDirNames -NativeKbRootPattern $nativeKbRootPattern | ConvertFrom-Json
  if ($k1k2.status -eq 'unknown') {
    # Motor falhou (ex.: git) e retorna gates vazio -> ler o status top-level
    # (anti-fail-open): senao o gate sumiria da consolidacao (isso seria fail-open);
    # com ele o unknown propaga e consolida em blocked (fail-closed).
    Add-Gate 'K1/K2' 'unknown' (@($k1k2.blockingReasons) -join '; ')
  } else {
    foreach ($g in $k1k2.gates) {
      $st = switch ($g.status) { 'block' { 'block' } 'unknown' { 'unknown' } default { 'ok' } }
      Add-Gate $g.gate $st $g.message $g.hits
    }
  }
} catch { Add-Gate 'K1/K2' 'unknown' "falha ao executar Test-XpzKbDangerousPaths: $($_.Exception.Message)" }

# ---- K3/K4 ----
try {
  $k3k4 = & (Join-Path $sharedScripts 'Test-XpzKbLayerDiff.ps1') -BaseRef $BaseRef -RepoRoot $RepoRoot -IndexDirName $indexDirName -AcervoDirName $acervoDirName -MetadataFileName $metadataFileName | ConvertFrom-Json
  if ($k3k4.status -eq 'unknown') {
    Add-Gate 'K3/K4' 'unknown' (@($k3k4.blockingReasons) -join '; ')
  } else {
    foreach ($g in $k3k4.gates) {
      $st = switch ($g.status) { 'warn' { 'warn' } 'unknown' { 'unknown' } default { 'ok' } }
      Add-Gate $g.gate $st $g.message
    }
  }
} catch { Add-Gate 'K3/K4' 'unknown' "falha ao executar Test-XpzKbLayerDiff: $($_.Exception.Message)" }

# ---- K8: auditoria de setup (contrato estruturado) ----
$k8w = Resolve-LocalWrapper -GateId 'K8' -ConfigName (Get-CfgProp $config 'setupAuditWrapper') -Convention 'Test-*KbSetupAudit.ps1'
if (-not $k8w.ok) {
  Add-Gate 'K8' 'block' $k8w.message
} else {
  try {
    $raw = (& $k8w.path -AsJson 2>$null | Out-String).Trim()
    $j = $raw | ConvertFrom-Json
    $estado = [string]$j.'estado_operacional_sugerido'
    $erroK8 = if ($j.PSObject.Properties.Name -contains 'error') { [string]$j.error } else { $null }
    $verdes = @('materializado_e_indice_validado', 'wrappers_atualizados', 'pronto_para_primeira_materializacao')
    # Estados explicitamente bloqueantes (fail-closed): runtime PowerShell quebrado
    # ou auditoria que nao pode concluir (ex.: metadata ausente) -> block, nao warn.
    $vermelhos = @('runtime_powershell_bloqueado', 'auditoria_incompleta')
    $st = if ($estado -in $vermelhos) { 'block' } elseif ($estado -in $verdes) { 'ok' } else { 'warn' }
    $msgK8 = "estado_operacional_sugerido=$estado (resolvedBy=$($k8w.resolvedBy))"
    if ($erroK8) { $msgK8 += " -- $erroK8" }
    Add-Gate 'K8' $st $msgK8
  } catch {
    Add-Gate 'K8' 'block' "setup desatualizado: wrapper de auditoria de setup nao emitiu contrato estruturado (-AsJson) -- atualize via xpz-kb-parallel-setup (resolvedBy=$($k8w.resolvedBy))"
  }
}

# ---- K9: gate de indice (contrato estruturado) ----
$k9w = Resolve-LocalWrapper -GateId 'K9' -ConfigName (Get-CfgProp $config 'indexGateWrapper') -Convention 'Test-*KbIndexGate.ps1'
if (-not $k9w.ok) {
  Add-Gate 'K9' 'block' $k9w.message
} else {
  try {
    $raw = (& $k9w.path -AsJson 2>$null | Out-String).Trim()
    $j = $raw | ConvertFrom-Json
    if ([string]$j.status -eq 'OK') {
      Add-Gate 'K9' 'ok' "indice apto (resolvedBy=$($k9w.resolvedBy))"
    } else {
      Add-Gate 'K9' 'block' "indice bloqueado: $([string]$j.reason) (resolvedBy=$($k9w.resolvedBy))"
    }
  } catch {
    Add-Gate 'K9' 'block' "setup desatualizado: gate de indice nao emitiu contrato estruturado (-AsJson) -- atualize via xpz-kb-parallel-setup (resolvedBy=$($k9w.resolvedBy))"
  }
}

# ---- K11 ----
try {
  $k11 = & (Join-Path $sharedScripts 'Test-XpzNotNotIsAntipattern.ps1') -BaseRef $BaseRef -RepoRoot $RepoRoot -AcervoDirName $acervoDirName | ConvertFrom-Json
  switch ($k11.status) {
    'block'   { Add-Gate 'K11' 'block' "$($k11.findings.Count) achado(s) de antipattern not-not em $($k11.scanned) XML(s)" $k11.findings }
    'unknown' { Add-Gate 'K11' 'unknown' (@($k11.blockingReasons) -join '; ') }
    default   { Add-Gate 'K11' 'ok' "$($k11.scanned) XML(s) varrido(s); zero achados" }
  }
} catch { Add-Gate 'K11' 'unknown' "falha ao executar Test-XpzNotNotIsAntipattern: $($_.Exception.Message)" }

# ---- Consolidacao ----
$hasBlock   = @($gates | Where-Object { $_.status -eq 'block' })
$hasUnknown = @($gates | Where-Object { $_.status -eq 'unknown' })
$hasWarn    = @($gates | Where-Object { $_.status -eq 'warn' })
$pushReadiness = if ($hasBlock.Count -gt 0) { 'blocked' }
                 elseif ($hasUnknown.Count -gt 0) { 'blocked' }
                 elseif ($hasWarn.Count -gt 0) { 'warn' }
                 else { 'ready' }

$result = [pscustomobject]@{
  range         = $range
  baseRef       = $BaseRef
  repoRoot      = $RepoRoot
  pushReadiness = $pushReadiness
  fetchStatus   = $fetchStatus
  configFound   = $configFound
  commitsAhead  = $ahead
  commitsBehind = $behind
  gates         = $gates
}

if ($AsText) {
  "=== xpz-kb-parallel-pre-push -- Fase 1 (mecanica) ==="
  "RepoRoot: $RepoRoot"
  "Range: $range   commitsAhead=$ahead  commitsBehind=$behind  fetch=$fetchStatus  config=$configFound"
  ""
  foreach ($g in $gates) {
    $sigil = switch ($g.status) { 'block' { '[BLOCK]  ' } 'unknown' { '[UNKNOWN]' } 'warn' { '[WARN]   ' } default { '[OK]     ' } }
    "$sigil $($g.id): $($g.message)"
    if ($g.detail -and $g.status -ne 'ok') {
      $detailList = @($g.detail)
      $shown = $detailList | Select-Object -First 5
      foreach ($d in $shown) { "           $(Format-GateDetailForText -Detail $d)" }
      if ($detailList.Count -gt 5) { "           ... (+$($detailList.Count - 5) linha(s); use o JSON para detalhe completo)" }
    }
  }
  ""
  "pushReadiness: $($pushReadiness.ToUpper())"
} else {
  $result | ConvertTo-Json -Depth 8
}

switch ($pushReadiness) {
  'ready'   { exit 0 }
  'warn'    { exit 2 }
  default   { exit 1 }
}
