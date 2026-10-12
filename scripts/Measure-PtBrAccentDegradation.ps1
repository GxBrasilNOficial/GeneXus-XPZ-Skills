#requires -Version 7.4

<#
.SYNOPSIS
    Mede degradacao de acentuacao pt-BR (palavras gravadas em ASCII onde deveria
    haver caractere acentuado) nos arquivos versionados do repositório.

.DESCRIPTION
    Detector deterministico e reusavel (medidor de progresso entre sessoes de
    correcao e, depois, guarda de regressao). NÃO corrige nada: só mede e reporta.

    Método (ver também ptbr-accent-wordlist.json e o relatório gerado):
    - Lista curada de palavras INEQUIVOCAS (forma sem acento nunca e lexema pt-BR
      valido e não colide com ingles comum) => coluna PISO FIRME.
    - Tokens AMBIGUOS (esta/tem/vem/so) contados a parte como TETO SOLTO, rotulados
      "não confirmados". 'e/e' não e contado (frequência da conjuncao inviabiliza).
    - Supressao de código: em .md ignora blocos cercados (```), code inline (`...`)
      e tokens colados a path/slug/identificador. Em .ps1/.example.ps1 mede SOMENTE
      comentarios de linha e de bloco; strings de mensagem ficam de fora
      (limite declarado) para garantir zero falso positivo de identificador.
    - Enumeracao via 'git ls-files' => só arquivos versionados; exclui
      automaticamente Temp/, work/, _audit*/ e qualquer scratch ignorado.

    Segmentos (no TOTAL de trabalho pendente): skill-md, skill-satelite, raiz-md,
    outros-md, example-ps1, ps1. FORA do total (diagnostico): historico (registro
    imutavel) e aportes-comunidade (SKILL.md de terceiros).

    PISO, NÃO TETO: a lista e finita; não pega palavras fora dela, troca de acento,
    crase faltante nem erros nao-acentuais.

.PARAMETER RepoRoot
    Raiz do repositório. Default: a pasta acima de scripts/.
.PARAMETER WordlistPath
    Caminho da lista curada. Default: scripts/ptbr-accent-wordlist.json.
.PARAMETER OutputDir
    Pasta dos artefatos (mapa .md + dados .json). Default: <RepoRoot>/work.
.EXAMPLE
    pwsh -NoProfile -File scripts/Measure-PtBrAccentDegradation.ps1
#>
[CmdletBinding()]
param(
    [string] $RepoRoot,
    [string] $WordlistPath,
    [string] $OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}
if ([string]::IsNullOrWhiteSpace($WordlistPath)) {
    $WordlistPath = Join-Path $PSScriptRoot 'ptbr-accent-wordlist.json'
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $RepoRoot 'work'
}

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')

# ---------------------------------------------------------------------------
# Carrega lista curada e monta os regex (inequivocas + ambiguas)
# ---------------------------------------------------------------------------
$wordlist = [System.IO.File]::ReadAllText($WordlistPath) | ConvertFrom-Json
$correctMap = @{}
$asciiForms = New-Object System.Collections.Generic.List[string]
foreach ($entry in $wordlist.entries) {
    $correctMap[$entry.a.ToLowerInvariant()] = $entry.c
    $asciiForms.Add([regex]::Escape($entry.a))
}
$ambiguousForms = New-Object System.Collections.Generic.List[string]
foreach ($tok in $wordlist.ambiguousTokens) {
    $ambiguousForms.Add([regex]::Escape($tok))
}

# Boundary: não colar a path/slug/identificador (/, \, -, _) nem a word char.
# (Deliberadamente sem '.' na classe, para não matar "nao." em fim de frase.)
$boundaryBefore = '(?<![\w/\\\-_])'
$boundaryAfter  = '(?![\w/\\\-_])'
$ignoreCase = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase

$inequivRegex = [regex]::new(
    $boundaryBefore + '(' + ($asciiForms -join '|') + ')' + $boundaryAfter, $ignoreCase)
$ambiguousRegex = [regex]::new(
    $boundaryBefore + '(' + ($ambiguousForms -join '|') + ')' + $boundaryAfter, $ignoreCase)

# ---------------------------------------------------------------------------
# NUCLEO: varredura de um texto. Usado pelo main e pelo self-test.
# Retorna { Inequivocas = List[finding]; Ambiguous = hashtable token->count }
# finding = { Line; Word; Correct; Snippet }
# ---------------------------------------------------------------------------
function Measure-AccentInText {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Text,
        [switch] $IsPowerShell
    )

    $findings = New-Object System.Collections.Generic.List[object]
    $ambCounts = @{}
    foreach ($tok in $wordlist.ambiguousTokens) { $ambCounts[$tok] = 0 }

    $lines = @($Text -split "`r?`n")
    $inFence = $false        # markdown: dentro de bloco cercado ```
    $inPsBlock = $false      # powershell: dentro de <# ... #>

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNumber = $i + 1
        $target = ''

        if ($IsPowerShell) {
            if ($inPsBlock) {
                if ($line -match '#>') {
                    $target = @($line -split '#>', 2)[0]
                    $inPsBlock = $false
                } else {
                    $target = $line
                }
            } elseif ($line -match '<#') {
                $after = @($line -split '<#', 2)[1]
                if ($after -match '#>') {
                    $target = @($after -split '#>', 2)[0]
                } else {
                    $target = $after
                    $inPsBlock = $true
                }
            } elseif ($line.Contains('#')) {
                $target = @($line -split '#', 2)[1]
            } else {
                $target = ''
            }
        } else {
            if ($line -match '^\s*(```|~~~)') {
                $inFence = -not $inFence
                continue
            }
            if ($inFence) { continue }
            # remove code inline `...`
            $target = [regex]::Replace($line, '`[^`]*`', ' ')
        }

        if ([string]::IsNullOrEmpty($target)) { continue }

        $snippet = $line.Trim()
        if ($snippet.Length -gt 160) { $snippet = $snippet.Substring(0, 157) + '...' }

        foreach ($m in $inequivRegex.Matches($target)) {
            $word = $m.Value
            $correct = $correctMap[$word.ToLowerInvariant()]
            $findings.Add([pscustomobject]@{
                Line    = $lineNumber
                Word    = $word
                Correct = $correct
                Snippet = $snippet
            }) | Out-Null
        }
        foreach ($m in $ambiguousRegex.Matches($target)) {
            $key = $m.Value.ToLowerInvariant()
            if ($ambCounts.ContainsKey($key)) { $ambCounts[$key] = $ambCounts[$key] + 1 }
        }
    }

    return [pscustomobject]@{
        Inequivocas = $findings
        Ambiguous   = $ambCounts
    }
}

# ---------------------------------------------------------------------------
# Segmentacao por caminho relativo
# ---------------------------------------------------------------------------
function Get-Segment {
    param([Parameter(Mandatory)] [string] $RelPath)
    $p = ($RelPath -replace '\\', '/')
    if ($p -like 'historico/*') { return 'historico' }
    if ($p -like 'AportesDaComunidadeParaAvaliacao/*') { return 'aportes-comunidade' }
    if ($p -like '*.example.ps1') { return 'example-ps1' }
    if ($p -like '*.ps1') { return 'ps1' }
    if (($p -like 'xpz-*') -and ($p -like '*/SKILL.md')) { return 'skill-md' }
    if ($p -like 'xpz-*') { return 'skill-satelite' }
    if ($p -notmatch '/') { return 'raiz-md' }
    return 'outros-md'
}

# ---------------------------------------------------------------------------
# Fronteira pt-BR em arquivos trilingues (PT/ES/EN).
# Este medidor cobre SÓ o pt-BR. Em arquivos com seção '## Español'/'## English'
# (ex.: README, CHANGELOG, CODE_OF_CONDUCT, SECURITY, CONTRIBUTING), palavras
# espanholas validas colidem com a forma pt-ascii (repositorio, usuario,
# criterio, experiencia, existencia, transferencia) e gerariam falso positivo
# e re-corrupcao se medidas/editadas. Só a faixa do inicio ate o primeiro
# cabecalho ES/EN e dominio deste detector e dos aplicadores que o reusam.
# Retorna a contagem de linhas pt-BR (todas, se monolingue).
function Get-PtBrLineCount {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $lines = @($Text -split "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^#{1,6}\s+(Español|Espanol|English|Spanish)\b') { return $i }
    }
    return $lines.Count
}

# Devolve só o prefixo pt-BR do texto (para medicao). Preserva numeração de
# linha 1..N do prefixo (identica a do arquivo, por ser o inicio).
function Get-PtBrText {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $end = Get-PtBrLineCount -Text $Text
    $lines = @($Text -split "`r?`n")
    if ($end -ge $lines.Count) { return $Text }
    if ($end -le 0) { return '' }
    return (($lines[0..($end - 1)]) -join "`n")
}

$includedSegments = @('skill-md', 'skill-satelite', 'raiz-md', 'outros-md', 'example-ps1', 'ps1')

# ---------------------------------------------------------------------------
# Se rodado com dot-source (self-test), não executa o main
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -eq '.') { return }

# ---------------------------------------------------------------------------
# MAIN: enumera arquivos versionados e mede
# ---------------------------------------------------------------------------
$commitSha = (& git -C $RepoRoot rev-parse --short HEAD).Trim()
$tracked = @(& git -C $RepoRoot ls-files)
$targets = @($tracked | Where-Object { $_ -match '\.(md|ps1)$' })

$fileResults = New-Object System.Collections.Generic.List[object]
foreach ($rel in $targets) {
    $full = Join-Path $RepoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $text = [System.IO.File]::ReadAllText($full)
    $isPs = $rel -match '\.ps1$'
    $seg = Get-Segment -RelPath $rel
    # Mede só a faixa pt-BR (em .md trilingue, ignora seções ES/EN).
    if ($isPs) { $measureText = $text } else { $measureText = Get-PtBrText -Text $text }
    $res = Measure-AccentInText -Text $measureText -IsPowerShell:$isPs

    $ambTotal = 0
    foreach ($k in $res.Ambiguous.Keys) { $ambTotal += $res.Ambiguous[$k] }

    $fileResults.Add([pscustomobject]@{
        File         = ($rel -replace '\\', '/')
        Segment      = $seg
        Included     = ($includedSegments -contains $seg)
        InequivCount = $res.Inequivocas.Count
        AmbigCount   = $ambTotal
        Findings     = $res.Inequivocas
    }) | Out-Null
}

# ---------------------------------------------------------------------------
# Agregacoes
# ---------------------------------------------------------------------------
$allSegments = @('skill-md', 'skill-satelite', 'raiz-md', 'outros-md', 'example-ps1', 'ps1', 'historico', 'aportes-comunidade')
$segSummary = New-Object System.Collections.Generic.List[object]
foreach ($seg in $allSegments) {
    $segFiles = @($fileResults | Where-Object { $_.Segment -eq $seg })
    $ineq = 0; $amb = 0; $withHits = 0
    foreach ($f in $segFiles) {
        $ineq += $f.InequivCount
        $amb += $f.AmbigCount
        if ($f.InequivCount -gt 0) { $withHits++ }
    }
    $segSummary.Add([pscustomobject]@{
        Segment      = $seg
        Included     = ($includedSegments -contains $seg)
        Files        = $segFiles.Count
        FilesWithHit = $withHits
        Inequiv      = $ineq
        Ambiguous    = $amb
    }) | Out-Null
}

$totalIneq = 0; $totalAmb = 0
foreach ($s in $segSummary) { if ($s.Included) { $totalIneq += $s.Inequiv; $totalAmb += $s.Ambiguous } }

# Top palavras por frequência (só segmentos incluidos)
$wordFreq = @{}
foreach ($f in $fileResults) {
    if (-not $f.Included) { continue }
    foreach ($fd in $f.Findings) {
        $w = $fd.Word.ToLowerInvariant()
        if ($wordFreq.ContainsKey($w)) { $wordFreq[$w] = $wordFreq[$w] + 1 } else { $wordFreq[$w] = 1 }
    }
}
$topWords = @($wordFreq.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 25)

# ---------------------------------------------------------------------------
# Escreve artefatos
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$enc = Get-Utf8NoBomEncoding
$generatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')

# --- JSON (dados de maquina) ---
$jsonObj = [pscustomobject]@{
    generatedAt      = $generatedAt
    commitSha        = $commitSha
    repoRoot         = $RepoRoot
    wordlistEntries  = $wordlist.entries.Count
    method           = 'piso-firme (inequivocas) + teto-solto (ambiguas); ver ptbr-accent-wordlist.json'
    totalIncluded    = [pscustomobject]@{ inequivocas = $totalIneq; ambiguasTetoSolto = $totalAmb }
    segments         = $segSummary
    topWords         = @($topWords | ForEach-Object { [pscustomobject]@{ word = $_.Key; count = $_.Value } })
    files            = @($fileResults | ForEach-Object {
        [pscustomobject]@{
            file = $_.File; segment = $_.Segment; included = $_.Included
            inequivocas = $_.InequivCount; ambiguasTetoSolto = $_.AmbigCount
            occurrences = @($_.Findings | ForEach-Object {
                [pscustomobject]@{ line = $_.Line; word = $_.Word; correct = $_.Correct; snippet = $_.Snippet }
            })
        }
    })
}
$jsonPath = Join-Path $OutputDir 'ptbr-accent-map.json'
[System.IO.File]::WriteAllText($jsonPath, ($jsonObj | ConvertTo-Json -Depth 8), $enc)

# --- Markdown (mapa legivel) ---
$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine('# Mapa de degradacao de acentuacao pt-BR')
$null = $sb.AppendLine('')
$null = $sb.AppendLine("- Gerado em: $generatedAt")
$null = $sb.AppendLine("- Commit medido: ``$commitSha``")
$null = $sb.AppendLine("- Lista curada: $($wordlist.entries.Count) palavras inequivocas")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('> **Artefato transitorio (work/, git-ignored).** Reproduzivel a qualquer momento pelo script versionado. Sera descartado ao fim da missao de correcao.')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('## Limites desta medicao (PISO, NAO TETO)')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('- **Piso firme** = palavras inequivocas (forma sem acento sempre errada). E um minimo garantido, nao o total real.')
$null = $sb.AppendLine('- **Ambiguas (teto solto)** = `esta/tem/vem/so/numero`, contadas sem confirmacao; superestimam (forma sem acento muitas vezes valida: ele tem, esta coisa, eu numero; `so` colide com ingles). `e/e` nao e contado.')
$null = $sb.AppendLine('- Nao captura: palavras fora da lista, troca de acento (esta/esta), crase faltante (a/a), erros nao-acentuais (mas/mais), nem trechos em ingles separadamente.')
$null = $sb.AppendLine('- `.ps1`/`.example.ps1`: mede so comentarios; mensagens em string ficam de fora.')
$null = $sb.AppendLine('- Supressao de codigo em `.md` cobre cercas triplas e code inline; codigo indentado por 4 espacos NAO e suprimido.')
$null = $sb.AppendLine('- O ponto final NAO e fronteira de token (decisao deliberada, para nao perder palavra antes de ponto de frase); logo `funcao.md`/`indice.json` em prosa corrida contam.')
$null = $sb.AppendLine('- **Nao comparavel 1:1** com a medicao de 2026-05-11 (metodo e lista diferentes). Esta substitui aquela como nova baseline.')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('## Total (segmentos no trabalho pendente)')
$null = $sb.AppendLine('')
$null = $sb.AppendLine("- **Inequivocas (piso firme): $totalIneq**")
$null = $sb.AppendLine("- Ambiguas (teto solto, nao confirmadas): $totalAmb")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('## Por segmento')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('| Segmento | No total? | Arquivos | Com defeito | Inequivocas | Ambiguas (teto) |')
$null = $sb.AppendLine('|---|---|---|---|---|---|')
foreach ($s in $segSummary) {
    $inTotal = if ($s.Included) { 'sim' } else { 'NAO (diagnostico)' }
    $null = $sb.AppendLine("| $($s.Segment) | $inTotal | $($s.Files) | $($s.FilesWithHit) | $($s.Inequiv) | $($s.Ambiguous) |")
}
$null = $sb.AppendLine('')
$null = $sb.AppendLine('## Top palavras inequivocas (segmentos incluidos)')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('| Palavra (ASCII) | Forma correta | Ocorrencias |')
$null = $sb.AppendLine('|---|---|---|')
foreach ($w in $topWords) {
    $corr = $correctMap[$w.Key]
    $null = $sb.AppendLine("| $($w.Key) | $corr | $($w.Value) |")
}
$null = $sb.AppendLine('')
$null = $sb.AppendLine('## Mapa por arquivo (ocorrencias inequivocas)')
$null = $sb.AppendLine('')
$filesWithHits = @($fileResults | Where-Object { $_.InequivCount -gt 0 } | Sort-Object -Property @{ Expression = 'Included'; Descending = $true }, @{ Expression = 'InequivCount'; Descending = $true })
foreach ($f in $filesWithHits) {
    $tag = if ($f.Included) { '' } else { ' _(diagnostico, fora do total)_' }
    $null = $sb.AppendLine("### $($f.File) — $($f.InequivCount) inequivocas$tag")
    $null = $sb.AppendLine('')
    foreach ($fd in $f.Findings) {
        $null = $sb.AppendLine("- L$($fd.Line): ``$($fd.Word)`` -> $($fd.Correct)  |  $($fd.Snippet)")
    }
    $null = $sb.AppendLine('')
}
$mdPath = Join-Path $OutputDir 'ptbr-accent-map.md'
[System.IO.File]::WriteAllText($mdPath, $sb.ToString(), $enc)

# ---------------------------------------------------------------------------
# Resumo no stdout
# ---------------------------------------------------------------------------
Write-Host "Commit medido: $commitSha"
Write-Host "Arquivos versionados analisados (.md/.ps1): $($targets.Count)"
Write-Host ''
Write-Host 'Por segmento (inequivocas | ambiguas-teto | arquivos-com-defeito/arquivos):'
foreach ($s in $segSummary) {
    $mark = if ($s.Included) { ' ' } else { '*' }
    Write-Host ("  {0}{1,-20} {2,5} | {3,5} | {4}/{5}" -f $mark, $s.Segment, $s.Inequiv, $s.Ambiguous, $s.FilesWithHit, $s.Files)
}
Write-Host ''
Write-Host "TOTAL (incluidos): inequivocas=$totalIneq  ambiguas-teto=$totalAmb"
Write-Host "(* = segmento de diagnostico, fora do total)"
Write-Host ''
Write-Host "Mapa:  $mdPath"
Write-Host "Dados: $jsonPath"
