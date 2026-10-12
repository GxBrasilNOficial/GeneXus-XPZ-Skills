#requires -Version 7.4

<#
.SYNOPSIS
  Gate K11 da rotina pre-push de pasta paralela de KB (skill
  xpz-kb-parallel-pre-push): detecta o antipattern `not not X.IsNull()` /
  `not not X.IsEmpty()` em blocos <Source> de XMLs GeneXus do acervo.

.DESCRIPTION
  Motor compartilhado, agnostico de KB. `not not X.IsNull()` colapsa para
  `IsNull()`; combinado com `not IsEmpty()` em rules, a condicao nunca dispara
  (impossivel logico = bug real). Por isso K11 e BLOQUEANTE, independentemente do
  build -- nao e classificacao de regime, e erro logico inequivoco.

  GRAMATICA EXATA detectada (regex, case-insensitive -- GeneXus e
  case-insensitive em identificadores):
    \bnot\s+not\s+\w+(\.\w+)*\.Is(Null|Empty)\s*\(\s*\)
  Word boundary inicial evita falso positivo em palavras terminando em "not".
  Trata <Source>...</Source> com ou sem <![CDATA[...]]> e multiplos blocos por
  arquivo. Filtra comentarios GeneXus: linhas iniciando (apos whitespace) com //.

  LIMITES CONHECIDOS (fora da gramatica acima -- silenciosos nesta versao):
  - Comentario inline (`code()  // not not X.IsNull()`) NAO e filtrado: dispara
    achado (decisao consciente -- raro e vale revisao humana).
  - `not` e `not` em linhas separadas NAO sao detectados (varredura linha a
    linha; o formatter do GeneXus mantem em linha unica).
  - Dentro de <Property><Value> (prompts) NAO e varrido (parametro, nao corpo).
  - Variantes equivalentes (`X.IsNull() = false`, `not X.IsNull() = false`) NAO
    sao cobertas nesta versao.

  CONTRATO DE SAIDA: JSON de maquina por padrao no stdout. Campos: status
  (ok|block|unknown), exitCode, baseRef, repoRoot, scanned, findings[]. -AsText
  da saida humana; -AsJson e no-op (JSON ja e o default).

  EXIT CODE: 0 ok, 1 block, 3 unknown (falha de git ao montar a lista do diff).

.PARAMETER BaseRef
  Referencia git base (default: origin/main). Ignorado se -ScanAll for usado.

.PARAMETER RepoRoot
  Raiz da pasta paralela da KB (default: diretorio de trabalho atual).

.PARAMETER AcervoDirName
  Nome da pasta do acervo oficial (default: ObjetosDaKbEmXml).

.PARAMETER Files
  Lista explicita de XMLs. Se omitida e sem -ScanAll, usa git diff --name-only
  no intervalo BaseRef..HEAD para coletar XMLs do acervo.

.PARAMETER ScanAll
  Varre TODO o acervo recursivamente, ignorando -BaseRef/-Files (auditoria).

.PARAMETER AsText
  Saida humana em texto em vez do JSON padrao.

.PARAMETER AsJson
  No-op: JSON ja e a saida padrao.

.EXAMPLE
  Test-XpzNotNotIsAntipattern.ps1

.EXAMPLE
  Test-XpzNotNotIsAntipattern.ps1 -ScanAll
#>
[CmdletBinding()]
param(
  [string]$BaseRef = 'origin/main',
  [string]$RepoRoot = (Get-Location).Path,
  [string]$AcervoDirName = 'ObjetosDaKbEmXml',
  [string[]]$Files,
  [switch]$ScanAll,
  [switch]$AsText,
  [switch]$AsJson
)

Set-StrictMode -Version Latest

$acervoDir = ($AcervoDirName -replace '\\', '/').Trim().TrimEnd('/')
$range = "$BaseRef..HEAD"

$pattern = [regex]::new(
  '\bnot\s+not\s+\w+(\.\w+)*\.Is(Null|Empty)\s*\(\s*\)',
  [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$commentLine = [regex]::new('^\s*//')
$sourceBlock = [regex]::new(
  '<Source>(?<body>.*?)</Source>',
  [System.Text.RegularExpressions.RegexOptions]::Singleline
)

if ($ScanAll) {
  $acervoPath = Join-Path $RepoRoot $acervoDir
  $Files = @(Get-ChildItem -Path $acervoPath -Recurse -Filter '*.xml' -File -ErrorAction SilentlyContinue |
             ForEach-Object { $_.FullName })
} elseif (-not $Files) {
  $diffOutput = @(git -C $RepoRoot diff --name-only $range -- "$acervoDir/*.xml" 2>$null)
  $gitExit = $LASTEXITCODE
  if ($gitExit -ne 0) {
    $reason = "git diff falhou (exit $gitExit) para range '$range' em '$RepoRoot' -- BaseRef inexistente ou repo invalido?"
    $unknown = [pscustomobject]@{
      status          = 'unknown'
      exitCode        = 3
      baseRef         = $BaseRef
      repoRoot        = $RepoRoot
      scanned         = 0
      blockingReasons = @($reason)
      findings        = @()
    }
    if ($AsText) { "K11 [UNKNOWN]: $reason" } else { $unknown | ConvertTo-Json -Depth 4 }
    exit 3
  }
  $Files = @($diffOutput | Where-Object { $_ -match '\.xml$' })
}

$findings = [System.Collections.Generic.List[object]]::new()
$scannedCount = 0

foreach ($f in $Files) {
  $absPath = if ([System.IO.Path]::IsPathRooted($f)) { $f } else { Join-Path $RepoRoot $f }
  if (-not (Test-Path -LiteralPath $absPath)) { continue }
  $scannedCount++
  $content = Get-Content -LiteralPath $absPath -Raw
  if ([string]::IsNullOrEmpty($content)) { continue }

  $srcMatches = $sourceBlock.Matches($content)
  foreach ($m in $srcMatches) {
    $body = $m.Groups['body'].Value
    $body = $body -replace '<!\[CDATA\[', '' -replace '\]\]>', ''

    $prefix = $content.Substring(0, $m.Index)
    $sourceStartLine = @($prefix -split "`n").Count

    $lines = @($body -split "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]
      if ($commentLine.IsMatch($line)) { continue }
      $pm = $pattern.Match($line)
      if ($pm.Success) {
        [void]$findings.Add([pscustomobject]@{
          path        = $f
          line        = $sourceStartLine + $i
          matchedText = $pm.Value
          lineContent = $line.Trim()
        })
      }
    }
  }
}

$status = if ($findings.Count -gt 0) { 'block' } else { 'ok' }
$exitCode = if ($findings.Count -gt 0) { 1 } else { 0 }

$result = [pscustomobject]@{
  status          = $status
  exitCode        = $exitCode
  baseRef         = $BaseRef
  repoRoot        = $RepoRoot
  scanned         = $scannedCount
  blockingReasons = @($findings | ForEach-Object { "{0}:{1} {2}" -f $_.path, $_.line, $_.matchedText })
  findings        = @($findings)
}

if ($AsText) {
  if ($findings.Count -eq 0) {
    "OK ($scannedCount XML(s) varrido(s); zero achados)"
  } else {
    foreach ($x in $findings) { "BLOCK {0}:{1}  {2}" -f $x.path, $x.line, $x.matchedText }
    ""
    ("{0} achado(s) em {1} XML(s) varrido(s)" -f $findings.Count, $scannedCount)
  }
} else {
  $result | ConvertTo-Json -Depth 4
}

exit $exitCode
