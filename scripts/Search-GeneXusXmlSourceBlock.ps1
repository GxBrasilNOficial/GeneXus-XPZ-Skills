#requires -Version 7.4

<#
.SYNOPSIS
    Busca texto em blocos Source de XML GeneXus sem despejar CDATA extenso.

.DESCRIPTION
    Le XMLs de objeto ou pacotes exportados e separa cada <Source> por papel
    textual antes de aplicar a busca. O objetivo principal e evitar que uma
    busca em WebPanel confunda o layout <GxMultiForm> em uma linha gigante com
    code-behind de events.

.PARAMETER Path
    Arquivo XML ou diretório contendo XMLs. Diretórios são lidos no primeiro
    nível por padrão; use -Recurse para descer subpastas.

.PARAMETER Pattern
    Expressao regular a procurar dentro do texto efetivo do Source.

.PARAMETER Block
    all: todos os blocos Source.
    code: blocos Source que não são layout nem XML serializado.
    events: blocos code que contem linhas Event ou Sub.
    layout: blocos Source cujo conteúdo comeca com <GxMultiForm.
    serialized: blocos Source cujo conteúdo comeca com XML, mas não GxMultiForm.

.PARAMETER CaseSensitive
    Usa comparacao sensivel a maiusculas/minusculas.

.PARAMETER Recurse
    Quando Path for diretório, busca XMLs recursivamente.

.PARAMETER AsJson
    Emite JSON estruturado.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [string]$Pattern,

    [ValidateSet('all', 'code', 'events', 'layout', 'serialized')]
    [string]$Block = 'all',

    [switch]$CaseSensitive,

    [switch]$Recurse,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-TextFileFlexible {
    param([string]$FilePath)

    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    foreach ($encoding in @(
        [System.Text.UTF8Encoding]::new($false, $true),
        [System.Text.UTF8Encoding]::new($true, $true),
        [System.Text.UnicodeEncoding]::new($false, $true, $true),
        [System.Text.UnicodeEncoding]::new($true, $true, $true)
    )) {
        try {
            return $encoding.GetString($bytes)
        } catch {
            continue
        }
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-XmlFiles {
    param([string]$InputPath)

    $resolved = [System.IO.Path]::GetFullPath($InputPath)
    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        return @(Get-Item -LiteralPath $resolved)
    }
    if (Test-Path -LiteralPath $resolved -PathType Container) {
        return @(Get-ChildItem -LiteralPath $resolved -Filter '*.xml' -File -Recurse:$Recurse)
    }
    throw "Path nao encontrado: $InputPath"
}

function Get-LineNumberAt {
    param(
        [string]$Text,
        [int]$Index
    )

    if ($Index -le 0) {
        return 1
    }
    return ([regex]::Matches($Text.Substring(0, $Index), "`n")).Count + 1
}

function Get-ObjectNameAtIndex {
    param(
        [string]$XmlText,
        [int]$Index
    )

    $regex = [regex]::new('<Object\b[^>]*\bname="(?<name>[^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::RightToLeft)
    $match = $regex.Match($XmlText, $Index)
    if ($match.Success) {
        return [System.Net.WebUtility]::HtmlDecode($match.Groups['name'].Value)
    }
    return $null
}

function Unwrap-SourceBody {
    param([string]$RawBody)

    $cdata = [regex]::Match($RawBody, '^\s*<!\[CDATA\[(?<body>.*)\]\]>\s*$', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($cdata.Success) {
        return $cdata.Groups['body'].Value
    }
    return [System.Net.WebUtility]::HtmlDecode($RawBody)
}

function Get-SourceBodyStartOffset {
    param([string]$RawBody)

    $cdataPrefix = [regex]::Match($RawBody, '^\s*<!\[CDATA\[', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($cdataPrefix.Success) {
        return $cdataPrefix.Length
    }
    return 0
}

function Get-SourceBlockKind {
    param([string]$SourceText)

    $trimmed = $SourceText.TrimStart()
    if ($trimmed.StartsWith('<GxMultiForm', [System.StringComparison]::OrdinalIgnoreCase)) {
        return 'layout'
    }
    if ($trimmed.StartsWith('<', [System.StringComparison]::Ordinal)) {
        return 'serialized'
    }
    if ($SourceText -match '(?im)^\s*(Event|Sub)\b') {
        return 'events'
    }
    return 'code'
}

function Test-BlockSelected {
    param(
        [string]$Actual,
        [string]$Selected
    )

    if ($Selected -eq 'all') { return $true }
    if ($Selected -eq 'code') { return ($Actual -eq 'code' -or $Actual -eq 'events') }
    return ($Actual -eq $Selected)
}

function Get-LinePreview {
    param([string]$Line)

    if ($null -eq $Line) { return '' }
    $trimmed = $Line.Trim()
    if ($trimmed.Length -le 180) {
        return $trimmed
    }
    return $trimmed.Substring(0, 180) + '...'
}

function Search-SourceBlocksInFile {
    param(
        [System.IO.FileInfo]$File,
        [regex]$Regex,
        [string]$SelectedBlock
    )

    $xmlText = Read-TextFileFlexible -FilePath $File.FullName
    $sourceRegex = [regex]::new('<Source(?:\s[^>]*)?>(?<body>.*?)</Source>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $sourceIndex = 0
    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($sourceMatch in $sourceRegex.Matches($xmlText)) {
        $sourceIndex++
        $rawBody = $sourceMatch.Groups['body'].Value
        $body = Unwrap-SourceBody -RawBody $rawBody
        if ([string]::IsNullOrWhiteSpace($body)) {
            continue
        }

        $objectName = Get-ObjectNameAtIndex -XmlText $xmlText -Index $sourceMatch.Index
        $kind = Get-SourceBlockKind -SourceText $body
        if (-not (Test-BlockSelected -Actual $kind -Selected $SelectedBlock)) {
            continue
        }

        $bodyStart = $sourceMatch.Groups['body'].Index + (Get-SourceBodyStartOffset -RawBody $rawBody)
        $sourceStartLine = Get-LineNumberAt -Text $xmlText -Index $bodyStart
        $lines = @([regex]::Split($body, "`r?`n"))

        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            $line = $lines[$lineIndex]
            foreach ($match in $Regex.Matches($line)) {
                $results.Add([pscustomobject]@{
                    path          = $File.FullName
                    objectName    = $objectName
                    block         = $kind
                    sourceIndex   = $sourceIndex
                    xmlLine       = $sourceStartLine + $lineIndex
                    blockLine     = $lineIndex + 1
                    column        = $match.Index + 1
                    match         = $match.Value
                    preview       = Get-LinePreview -Line $line
                }) | Out-Null
            }
        }
    }

    return @($results)
}

$regexOptions = [System.Text.RegularExpressions.RegexOptions]::None
if (-not $CaseSensitive) {
    $regexOptions = $regexOptions -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
}
$searchRegex = [regex]::new($Pattern, $regexOptions)

$allResults = [System.Collections.Generic.List[object]]::new()
foreach ($file in Get-XmlFiles -InputPath $Path) {
    foreach ($result in Search-SourceBlocksInFile -File $file -Regex $searchRegex -SelectedBlock $Block) {
        $allResults.Add($result) | Out-Null
    }
}

if ($AsJson) {
    @($allResults) | ConvertTo-Json -Depth 5
    return
}

foreach ($result in $allResults) {
    $objectPart = if ([string]::IsNullOrWhiteSpace($result.objectName)) { '' } else { " object=$($result.objectName)" }
    "{0}:{1}: block={2} source={3} blockLine={4}{5}: {6}" -f $result.path, $result.xmlLine, $result.block, $result.sourceIndex, $result.blockLine, $objectPart, $result.preview
}
