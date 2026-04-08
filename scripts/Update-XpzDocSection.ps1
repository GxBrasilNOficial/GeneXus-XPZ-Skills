param(
    [Parameter(Mandatory = $true)]
    [string]$TargetMarkdown,

    [Parameter(Mandatory = $true)]
    [string]$SectionTitle,

    [string[]]$IntroLines = @(),

    [Parameter(Mandatory = $true)]
    [string[]]$XmlExamplePaths,

    [string[]]$ExampleTitles = @(),

    [string[]]$ExampleNotes = @(),

    [string]$CodeFenceLanguage = "xml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ExistingPath {
    param(
        [string]$Path,
        [string]$ParameterName
    )

    try {
        return (Resolve-Path -LiteralPath $Path).Path
    } catch {
        throw ("{0} not found: {1}" -f $ParameterName, $Path)
    }
}

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function Get-SectionStartPattern {
    param([string]$Title)

    return "(?m)^" + [regex]::Escape($Title) + "\s*$"
}

function Get-NextSectionMatch {
    param(
        [string]$Content,
        [int]$StartIndex
    )

    $remaining = $Content.Substring($StartIndex)
    return [regex]::Match($remaining, '(?m)^##\s+.+$')
}

function Remove-ExistingSection {
    param(
        [string]$Content,
        [string]$Title
    )

    $startMatch = [regex]::Match($Content, (Get-SectionStartPattern -Title $Title))
    if (-not $startMatch.Success) {
        return $Content.TrimEnd()
    }

    $startIndex = $startMatch.Index
    $searchFrom = $startMatch.Index + $startMatch.Length
    $nextSection = Get-NextSectionMatch -Content $Content -StartIndex $searchFrom

    if ($nextSection.Success) {
        $endIndex = $searchFrom + $nextSection.Index
        $prefix = $Content.Substring(0, $startIndex).TrimEnd()
        $suffix = $Content.Substring($endIndex).TrimStart()
        if ([string]::IsNullOrWhiteSpace($suffix)) {
            return $prefix
        }
        return ($prefix + "`r`n`r`n" + $suffix).TrimEnd()
    }

    return $Content.Substring(0, $startIndex).TrimEnd()
}

function Format-FencedBlock {
    param(
        [string]$Path,
        [string]$Language
    )

    $content = Get-Content -LiteralPath $Path -Raw
    $fence = [string]([char]96) * 3
    return ($fence + $Language + "`r`n" + $content + "`r`n" + $fence)
}

if ($XmlExamplePaths.Count -eq 0) {
    throw "At least one XmlExamplePaths entry is required."
}

$resolvedTarget = Resolve-ExistingPath -Path $TargetMarkdown -ParameterName "TargetMarkdown"
$resolvedExamples = @(
    foreach ($path in $XmlExamplePaths) {
        Resolve-ExistingPath -Path $path -ParameterName "XmlExamplePaths"
    }
)

if ($ExampleTitles.Count -gt 0 -and $ExampleTitles.Count -ne $resolvedExamples.Count) {
    throw "ExampleTitles count must match XmlExamplePaths count when provided."
}

if ($ExampleNotes.Count -gt 0 -and $ExampleNotes.Count -ne $resolvedExamples.Count) {
    throw "ExampleNotes count must match XmlExamplePaths count when provided."
}

$raw = Get-Content -LiteralPath $resolvedTarget -Raw
$base = Remove-ExistingSection -Content $raw -Title $SectionTitle

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add($SectionTitle)
$lines.Add("")

foreach ($intro in $IntroLines) {
    $lines.Add($intro)
}

if ($IntroLines.Count -gt 0) {
    $lines.Add("")
}

for ($i = 0; $i -lt $resolvedExamples.Count; $i++) {
    if ($ExampleTitles.Count -gt 0) {
        $lines.Add($ExampleTitles[$i])
        $lines.Add("")
    }

    if ($ExampleNotes.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($ExampleNotes[$i])) {
        $noteLines = $ExampleNotes[$i] -split "\r?\n"
        foreach ($noteLine in $noteLines) {
            $lines.Add($noteLine)
        }
        $lines.Add("")
    }

    $lines.Add((Format-FencedBlock -Path $resolvedExamples[$i] -Language $CodeFenceLanguage))
    $lines.Add("")
}

$newSection = ($lines -join "`r`n").TrimEnd()
$newContent = if ([string]::IsNullOrWhiteSpace($base)) {
    $newSection + "`r`n"
} else {
    $base + "`r`n`r`n" + $newSection + "`r`n"
}

[System.IO.File]::WriteAllText($resolvedTarget, $newContent, (Get-Utf8NoBomEncoding))
