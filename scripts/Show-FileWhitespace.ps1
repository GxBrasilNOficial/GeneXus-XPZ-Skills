#requires -Version 7.4

<#
.SYNOPSIS
    Mostra whitespace, encoding e EOL de um arquivo em formato legivel.

.DESCRIPTION
    Helper de leitura pura para inspecao cirurgica de arquivos em que tabs,
    espacos e finais de linha precisam ficar visiveis antes de uma edicao
    literal. Não depende de GeneXus instalado nem de KB aberta.

.PARAMETER Path
    Caminho do arquivo a inspecionar.

.PARAMETER FromLine
    Linha inicial da janela, 1-based. Quando omitida, usa uma janela curta.

.PARAMETER ToLine
    Linha final da janela, 1-based. Quando omitida, usa uma janela curta.

.PARAMETER Mode
    whitespace: mostra tabs como [T], espacos como "." e EOL como [LF]/[CRLF]/[CR].
    encoding: mostra BOM, encoding inferido e EOL dominante.
    mixed: lista linhas cuja indentacao inicial mistura tabs e espacos.

.PARAMETER AsJson
    Retorna saida estruturada em JSON.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [int]$FromLine,

    [int]$ToLine,

    [ValidateSet('whitespace', 'encoding', 'mixed')]
    [string]$Mode = 'whitespace',

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ValidUtf8 {
    param(
        [byte[]]$Bytes,
        [int]$Offset
    )

    try {
        $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
        [void]$utf8Strict.GetString($Bytes, $Offset, $Bytes.Length - $Offset)
        return $true
    } catch {
        return $false
    }
}

function Get-FileEncodingInfo {
    param(
        [byte[]]$Bytes
    )

    $bom = 'none'
    $bomLength = 0
    $encoding = $null
    $inferred = 'ASCII'

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $bom = 'UTF-8 BOM'
        $bomLength = 3
        $encoding = [System.Text.UTF8Encoding]::new($true, $true)
        $inferred = 'UTF-8 with BOM'
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        $bom = 'UTF-16 LE BOM'
        $bomLength = 2
        $encoding = [System.Text.UnicodeEncoding]::new($false, $true, $true)
        $inferred = 'UTF-16 LE'
    } elseif ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
        $bom = 'UTF-16 BE BOM'
        $bomLength = 2
        $encoding = [System.Text.UnicodeEncoding]::new($true, $true, $true)
        $inferred = 'UTF-16 BE'
    } else {
        $hasNonAscii = $false
        foreach ($byte in $Bytes) {
            if ($byte -gt 0x7F) {
                $hasNonAscii = $true
                break
            }
        }

        if (-not $hasNonAscii) {
            $encoding = [System.Text.UTF8Encoding]::new($false, $true)
            $inferred = 'ASCII'
        } elseif (Test-ValidUtf8 -Bytes $Bytes -Offset 0) {
            $encoding = [System.Text.UTF8Encoding]::new($false, $true)
            $inferred = 'UTF-8'
        } else {
            $encoding = [System.Text.Encoding]::GetEncoding(1252)
            $inferred = 'unknown-8bit'
        }
    }

    return [pscustomobject]@{
        bom              = $bom
        bomLength        = $bomLength
        inferredEncoding = $inferred
        decoder          = $encoding
    }
}

function Split-TextWithEol {
    param(
        [string]$Text
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $start = 0
    $index = 0

    while ($index -lt $Text.Length) {
        $ch = $Text[$index]
        if ($ch -eq "`r") {
            $lineText = $Text.Substring($start, $index - $start)
            if (($index + 1) -lt $Text.Length -and $Text[$index + 1] -eq "`n") {
                $items.Add([pscustomobject]@{ text = $lineText; eol = 'CRLF' }) | Out-Null
                $index += 2
            } else {
                $items.Add([pscustomobject]@{ text = $lineText; eol = 'CR' }) | Out-Null
                $index++
            }
            $start = $index
            continue
        }

        if ($ch -eq "`n") {
            $lineText = $Text.Substring($start, $index - $start)
            $items.Add([pscustomobject]@{ text = $lineText; eol = 'LF' }) | Out-Null
            $index++
            $start = $index
            continue
        }

        $index++
    }

    if ($start -lt $Text.Length) {
        $items.Add([pscustomobject]@{ text = $Text.Substring($start); eol = 'none' }) | Out-Null
    }

    return $items
}

function Get-EolSummary {
    param(
        [System.Collections.Generic.List[object]]$Lines
    )

    $counts = [ordered]@{
        CRLF = 0
        LF   = 0
        CR   = 0
        none = 0
    }

    foreach ($line in $Lines) {
        $counts[$line.eol] = $counts[$line.eol] + 1
    }

    $present = @($counts.GetEnumerator() | Where-Object { $_.Value -gt 0 -and $_.Key -ne 'none' })
    $dominant = 'none'
    if ($present.Count -eq 1) {
        $dominant = $present[0].Key
    } elseif ($present.Count -gt 1) {
        $dominant = 'mixed'
    }

    return [pscustomobject]@{
        dominant = $dominant
        counts   = [pscustomobject]$counts
    }
}

function Resolve-LineWindow {
    param(
        [int]$TotalLines,
        [int]$RequestedFrom,
        [int]$RequestedTo
    )

    if ($TotalLines -eq 0) {
        return [pscustomobject]@{ from = 0; to = 0 }
    }

    $windowSize = 120
    $hasFrom = $PSBoundParameters.ContainsKey('RequestedFrom') -and $RequestedFrom -gt 0
    $hasTo = $PSBoundParameters.ContainsKey('RequestedTo') -and $RequestedTo -gt 0

    if ($hasFrom -and $hasTo) {
        $from = $RequestedFrom
        $to = $RequestedTo
    } elseif ($hasFrom) {
        $from = $RequestedFrom
        $to = $RequestedFrom + $windowSize - 1
    } elseif ($hasTo) {
        $to = $RequestedTo
        $from = $RequestedTo - $windowSize + 1
    } else {
        $from = 1
        $to = [Math]::Min($TotalLines, $windowSize)
    }

    $from = [Math]::Max(1, $from)
    $to = [Math]::Min($TotalLines, $to)

    if ($from -gt $to) {
        throw "BLOCK: janela de linhas invalida: FromLine=$RequestedFrom ToLine=$RequestedTo"
    }

    return [pscustomobject]@{ from = $from; to = $to }
}

function Convert-LineToVisibleWhitespace {
    param(
        [string]$LineText,
        [string]$Eol
    )

    $visible = $LineText.Replace("`t", '[T]').Replace(' ', '.')
    if ($Eol -eq 'none') {
        return "$visible[NOEOL]"
    }

    return "$visible[$Eol]"
}

function Get-MixedIndentLines {
    param(
        [System.Collections.Generic.List[object]]$Lines
    )

    $items = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]
        $match = [regex]::Match($line.text, "^[ `t]+")
        if (-not $match.Success) {
            continue
        }

        $indent = $match.Value
        if ($indent.Contains("`t") -and $indent.Contains(' ')) {
            $items.Add([pscustomobject]@{
                lineNumber    = $index + 1
                visibleIndent = $indent.Replace("`t", '[T]').Replace(' ', '.')
                visibleLine   = Convert-LineToVisibleWhitespace -LineText $line.text -Eol $line.eol
            }) | Out-Null
        }
    }

    return $items
}

if ($FromLine -lt 0 -or $ToLine -lt 0) {
    throw 'BLOCK: FromLine e ToLine devem ser positivos'
}

$resolvedPath = [System.IO.Path]::GetFullPath($Path)
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    throw "BLOCK: arquivo nao encontrado: $resolvedPath"
}

$bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
$encodingInfo = Get-FileEncodingInfo -Bytes $bytes
$text = $encodingInfo.decoder.GetString($bytes, $encodingInfo.bomLength, $bytes.Length - $encodingInfo.bomLength)
$lines = Split-TextWithEol -Text $text
$eolSummary = Get-EolSummary -Lines $lines

if ($Mode -eq 'encoding') {
    $result = [pscustomobject]@{
        path             = $resolvedPath
        byteLength       = $bytes.Length
        bom              = $encodingInfo.bom
        hasBom           = ($encodingInfo.bom -ne 'none')
        inferredEncoding = $encodingInfo.inferredEncoding
        eolDominant      = $eolSummary.dominant
        eolCounts        = $eolSummary.counts
        lineCount        = $lines.Count
    }

    if ($AsJson) {
        $result | ConvertTo-Json -Depth 5
    } else {
        Write-Output "Path: $($result.path)"
        Write-Output "Bytes: $($result.byteLength)"
        Write-Output "BOM: $($result.bom)"
        Write-Output "Encoding: $($result.inferredEncoding)"
        Write-Output "EOL dominante: $($result.eolDominant)"
        Write-Output "EOL counts: CRLF=$($result.eolCounts.CRLF) LF=$($result.eolCounts.LF) CR=$($result.eolCounts.CR) none=$($result.eolCounts.none)"
        Write-Output "Linhas: $($result.lineCount)"
    }
    exit 0
}

if ($Mode -eq 'mixed') {
    $mixedLines = @(Get-MixedIndentLines -Lines $lines)
    $result = [pscustomobject]@{
        path      = $resolvedPath
        mode      = 'mixed'
        lineCount = $lines.Count
        count     = $mixedLines.Count
        lines     = @($mixedLines)
    }

    if ($AsJson) {
        $result | ConvertTo-Json -Depth 6
    } elseif ($mixedLines.Count -eq 0) {
        Write-Output 'MIXED_INDENT_OK'
    } else {
        Write-Output "MIXED_INDENT: $($mixedLines.Count) linha(s)"
        foreach ($item in $mixedLines) {
            Write-Output ("L{0}: [{1}]" -f $item.lineNumber, $item.visibleLine)
        }
    }
    exit 0
}

$window = Resolve-LineWindow -TotalLines $lines.Count -RequestedFrom $FromLine -RequestedTo $ToLine
$visibleLines = [System.Collections.Generic.List[object]]::new()
if ($window.from -gt 0) {
    for ($lineNumber = $window.from; $lineNumber -le $window.to; $lineNumber++) {
        $line = $lines[$lineNumber - 1]
        $visibleLines.Add([pscustomobject]@{
            lineNumber = $lineNumber
            text       = $line.text
            eol        = $line.eol
            visible    = Convert-LineToVisibleWhitespace -LineText $line.text -Eol $line.eol
        }) | Out-Null
    }
}

$result = [pscustomobject]@{
    path       = $resolvedPath
    mode       = 'whitespace'
    lineCount  = $lines.Count
    fromLine   = $window.from
    toLine     = $window.to
    truncated  = ($window.from -gt 1 -or $window.to -lt $lines.Count)
    lines      = @($visibleLines)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    foreach ($item in $visibleLines) {
        Write-Output ("L{0}: [{1}]" -f $item.lineNumber, $item.visible)
    }
}
