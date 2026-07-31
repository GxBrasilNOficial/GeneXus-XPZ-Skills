#requires -Version 7.4
<#
.SYNOPSIS
    Filtro compartilhado de ruido estrutural conhecido no stderr MSBuild GeneXus.
#>

Set-StrictMode -Version Latest

function Get-GeneXusMsBuildStderrNoiseClassification {
    param(
        [AllowNull()]
        [string]$Text
    )

    $source = if ($null -eq $Text) { '' } else { $Text }
    $pattern = '(?m)^(?:context \[anonymous\] \d+:\d+ attribute component isn''t defined|context \[/g_service_worker\] \d+:\d+ attribute obj isn''t defined)\r?$'
    $noiseText = @(
        [regex]::Matches($source, $pattern) |
        ForEach-Object { $_.Value.TrimEnd("`r") }
    ) -join "`n"
    $filteredText = ([regex]::Replace($source, $pattern + '\r?\n?', '')).Trim()

    return [pscustomobject][ordered]@{
        FilteredText = $filteredText
        NoiseText    = $noiseText
    }
}
