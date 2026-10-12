#requires -Version 7.4

<#
.SYNOPSIS
    Corrige a degradacao de acentuacao pt-BR INEQUIVOCA (palavras cuja forma sem
    acento nunca e lexema pt-BR valido) nos arquivos indicados, preservando caixa.

.DESCRIPTION
    Contraparte aplicadora do detector Measure-PtBrAccentDegradation.ps1. NÃO toca
    em tokens ambiguos (esta/tem/vem/so/numero) nem na conjuncao 'e': esses exigem
    decisão humana e ficam de fora por construcao.

    Garantias de fidelidade ao detector:
    - Faz dot-source do detector para reaproveitar EXATAMENTE a mesma lista curada
      ($correctMap), o mesmo regex de inequivocas ($inequivRegex) e a mesma
      supressao de código (cercas ``` / ~~~ e code inline `...`).
    - A mascara de code inline e LENGTH-PRESERVING (cada span vira o mesmo número de
      espacos), de modo que os offsets de match no texto mascarado batem 1:1 com o
      texto original; a substituicao ocorre sempre no texto original.
    - Preserva caixa: ALLCAPS -> ALLCAPS, Title -> Title, resto -> minuscula curada.
    - Preserva EOL exato (split com captura de '(\r?\n)') e grava UTF-8 sem BOM,
      conforme .gitattributes (*.md text eol=lf) e a regra do repositório.

    Em .ps1/.example.ps1 corrige SOMENTE comentarios, isolados pelo tokenizer do
    PowerShell (tokens Comment, com offset exato) — nunca toca codigo nem strings.
    Esse caminho e mais seguro que o split-por-'#' que o detector usa ao MEDIR: um
    '#' dentro de string nao vira correcao aqui (o detector pode conta-lo como ruido;
    divergencia conhecida e deliberada — o aplicador prefere nao corromper string).
    Dispatch por extensao: .md usa a supressao de Markdown (cercas/code inline) acima;
    .ps1/.example.ps1 usa o tokenizer.

.PARAMETER Files
    Caminhos (relativos a RepoRoot ou absolutos) dos arquivos a corrigir
    (.md, .ps1 ou .example.ps1).
.PARAMETER RepoRoot
    Raiz do repositório. Default: a pasta acima de scripts/.
.PARAMETER DryRun
    Não grava nada; só reporta quantas substituicoes ocorreriam por arquivo.
.EXAMPLE
    pwsh -NoProfile -File scripts/Repair-PtBrAccentDegradation.ps1 -Files 02-regras-operacionais-e-runtime.md -DryRun
.EXAMPLE
    pwsh -NoProfile -File scripts/Repair-PtBrAccentDegradation.ps1 -Files 02-regras-operacionais-e-runtime.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string[]] $Files,
    [string] $RepoRoot,
    [switch] $DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

# Dot-source o detector: define $correctMap, $inequivRegex, supressao e
# Get-Utf8NoBomEncoding (o detector retorna antes do main quando dot-sourced).
. (Join-Path $PSScriptRoot 'Measure-PtBrAccentDegradation.ps1')

# ---------------------------------------------------------------------------
# Preserva a caixa da forma encontrada ao aplicar a forma correta (minuscula).
# ---------------------------------------------------------------------------
function Get-CasedReplacement {
    param(
        [Parameter(Mandatory)] [string] $Found,
        [Parameter(Mandatory)] [string] $Correct
    )
    $upper = $Found.ToUpperInvariant()
    $lower = $Found.ToLowerInvariant()
    # ALLCAPS (tem ao menos uma letra com caixa): NAO -> NAO
    if (($Found -ceq $upper) -and ($Found -cne $lower)) {
        return $Correct.ToUpperInvariant()
    }
    # Title: primeira maiuscula, restante minusculo -> Padrao -> Padrao
    $first = $Found.Substring(0, 1)
    if ($Found.Length -gt 1) { $rest = $Found.Substring(1) } else { $rest = '' }
    if (($first -ceq $first.ToUpperInvariant()) -and ($first -cne $first.ToLowerInvariant()) `
            -and ($rest -ceq $rest.ToLowerInvariant())) {
        return $Correct.Substring(0, 1).ToUpperInvariant() + $Correct.Substring(1)
    }
    # default: forma curada (minuscula)
    return $Correct
}

# ---------------------------------------------------------------------------
# Corrige uma linha de markdown, respeitando cercas e code inline.
# Retorna [pscustomobject]{ Line; Count }.
# ---------------------------------------------------------------------------
function Repair-MarkdownLine {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Line,
        [Parameter(Mandatory)] [ref] $InFence
    )
    if ($Line -match '^\s*(```|~~~)') {
        $InFence.Value = -not $InFence.Value
        return [pscustomobject]@{ Line = $Line; Count = 0 }
    }
    if ($InFence.Value) {
        return [pscustomobject]@{ Line = $Line; Count = 0 }
    }

    # Mascara code inline preservando comprimento (offsets continuam batendo).
    $masked = [regex]::Replace($Line, '`[^`]*`', { param($m) ' ' * $m.Value.Length })
    $matches = @($inequivRegex.Matches($masked))
    if ($matches.Count -eq 0) {
        return [pscustomobject]@{ Line = $Line; Count = 0 }
    }

    $sb = [System.Text.StringBuilder]::new($Line)
    $n = 0
    # Da direita para a esquerda: preserva os offsets ainda não processados.
    for ($k = $matches.Count - 1; $k -ge 0; $k--) {
        $m = $matches[$k]
        $found = $Line.Substring($m.Index, $m.Length)
        $correct = $correctMap[$found.ToLowerInvariant()]
        if ([string]::IsNullOrEmpty($correct)) { continue }
        $repl = Get-CasedReplacement -Found $found -Correct $correct
        [void]$sb.Remove($m.Index, $m.Length)
        [void]$sb.Insert($m.Index, $repl)
        $n++
    }
    return [pscustomobject]@{ Line = $sb.ToString(); Count = $n }
}

# ---------------------------------------------------------------------------
# Corrige inequivocas SOMENTE em comentarios de um .ps1/.example.ps1, via tokenizer
# do PowerShell (tokens Comment, offset exato): nunca toca codigo nem strings.
# Retorna [pscustomobject]{ Text; Count }.
# ---------------------------------------------------------------------------
function Repair-Ps1Comments {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $tokens = $null; $perr = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$perr)
    if ($perr -and $perr.Count -gt 0) {
        throw "PARSE_ERRO ao tokenizar: $($perr[0].Message)"
    }
    $comments = @($tokens | Where-Object { $_.Kind -eq 'Comment' })
    $edits = New-Object System.Collections.Generic.List[object]
    foreach ($c in $comments) {
        $ct = $c.Text
        $start = $c.Extent.StartOffset
        foreach ($m in $inequivRegex.Matches($ct)) {
            $word = $m.Value
            $correct = $correctMap[$word.ToLowerInvariant()]
            if ([string]::IsNullOrEmpty($correct)) { continue }
            $edits.Add([pscustomobject]@{
                Off  = $start + $m.Index
                Len  = $m.Length
                Repl = (Get-CasedReplacement -Found $word -Correct $correct)
            }) | Out-Null
        }
    }
    $out = $Text
    # De tras pra frente: preserva os offsets ainda nao aplicados.
    foreach ($e in ($edits | Sort-Object Off -Descending)) {
        $out = $out.Remove($e.Off, $e.Len).Insert($e.Off, $e.Repl)
    }
    return [pscustomobject]@{ Text = $out; Count = $edits.Count }
}

# ---------------------------------------------------------------------------
# Processa cada arquivo
# ---------------------------------------------------------------------------
$enc = Get-Utf8NoBomEncoding
$grandTotal = 0
foreach ($rel in $Files) {
    if ([System.IO.Path]::IsPathRooted($rel)) {
        $full = $rel
    } else {
        $full = Join-Path $RepoRoot $rel
    }
    if (-not (Test-Path -LiteralPath $full)) {
        Write-Host "AUSENTE: $rel"
        continue
    }
    $text = [System.IO.File]::ReadAllText($full)
    if ($full -match '\.ps1$') {
        # .ps1/.example.ps1: corrige SOMENTE comentarios, via tokenizer.
        $r = Repair-Ps1Comments -Text $text
        $newText = $r.Text
        $fileCount = $r.Count
    } elseif ($full -match '\.md$') {
        # Markdown: corrige a faixa pt-BR, com supressao de cercas/code inline.
        # Em arquivo trilingue, ignora secoes ES/EN (colisao com espanhol).
        $ptBrEnd = Get-PtBrLineCount -Text $text
        # Split com captura: indices pares = conteudo de linha; impares = EOL.
        $parts = @([regex]::Split($text, '(\r?\n)'))
        $inFence = $false
        $fileCount = 0
        for ($i = 0; $i -lt $parts.Count; $i += 2) {
            $lineNo = ($i / 2) + 1
            if ($lineNo -gt $ptBrEnd) { continue }
            $res = Repair-MarkdownLine -Line $parts[$i] -InFence ([ref]$inFence)
            $parts[$i] = $res.Line
            $fileCount += $res.Count
        }
        $newText = -join $parts
    } else {
        Write-Host "IGNORADO (extensao nao suportada): $rel"
        continue
    }

    if ($DryRun) {
        Write-Host ("[dry-run] {0}: {1} substituicoes" -f ($rel -replace '\\', '/'), $fileCount)
    } else {
        if ($newText -ne $text) {
            [System.IO.File]::WriteAllText($full, $newText, $enc)
        }
        Write-Host ("{0}: {1} substituicoes" -f ($rel -replace '\\', '/'), $fileCount)
    }
    $grandTotal += $fileCount
}

Write-Host ''
$prefix = if ($DryRun) { '[dry-run] ' } else { '' }
Write-Host ("{0}TOTAL: {1} substituicoes inequivocas" -f $prefix, $grandTotal)
