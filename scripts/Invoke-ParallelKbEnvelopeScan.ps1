#Requires -Version 7.4

<#
.SYNOPSIS
  Amostra envelope XML (Properties vs Part) por tipo em pastas paralelas ObjetosDaKbEmXml.
#>
param(
    [string[]]$KbRoots,
    [string[]]$Types,
    [int]$MaxSamplePerType = 50,
    [string]$OutJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $KbRoots) {
    $discovered = [System.Collections.Generic.List[string]]::new()
    foreach ($parent in @('C:\Dev\Test', 'C:\Dev\Prod')) {
        if (-not (Test-Path -LiteralPath $parent)) { continue }
        Get-ChildItem -LiteralPath $parent -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $xmlRoot = Join-Path $_.FullName 'ObjetosDaKbEmXml'
            if (Test-Path -LiteralPath $xmlRoot) {
                [void]$discovered.Add($xmlRoot)
            }
        }
    }
    $KbRoots = @($discovered)
}
if (-not $Types) {
    $Types = @(
        'PatternSettings', 'Generator', 'DataStore', 'ThemeColor', 'ThemeClass', 'Folder',
        'SmartDevicesPlus', 'ColorPalette', 'DesignSystem', 'Theme', 'Language', 'Image',
        'DeploymentUnit', 'API', 'Module', 'PackagedModule', 'Document', 'File', 'Stencil'
    )
}

function Get-EnvelopeStats {
    param([string]$Dir, [int]$Max)
    $stats = [ordered]@{
        total          = 0
        sampled        = 0
        onlyProperties = 0
        partOnly       = 0
        both           = 0
        noEnvelope     = 0
    }
    if (-not (Test-Path -LiteralPath $Dir)) { return $stats }
    $all = @(Get-ChildItem -LiteralPath $Dir -Filter '*.xml' -File)
    $stats.total = $all.Count
    $sample = @($all | Select-Object -First $Max)
    $stats.sampled = $sample.Count
    foreach ($f in $sample) {
        $text = $null
        try {
            $text = [System.IO.File]::ReadAllText($f.FullName)
        }
        catch {
            $stats.noEnvelope++
            continue
        }
        $hasPart = $text -match '<Part[\s>]'
        $hasProps = $text -match '<Properties[\s>]'
        if ($hasPart -and $hasProps) { $stats.both++ }
        elseif ($hasPart) { $stats.partOnly++ }
        elseif ($hasProps) { $stats.onlyProperties++ }
        else { $stats.noEnvelope++ }
    }
    return $stats
}

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($root in $KbRoots) {
    $kb = (Split-Path (Split-Path $root -Parent) -Leaf)
    foreach ($type in $Types) {
        $dir = Join-Path $root $type
        $s = Get-EnvelopeStats -Dir $dir -Max $MaxSamplePerType
        $verdict = 'absent'
        if ($s.total -gt 0) {
            if ($s.partOnly -gt 0 -or $s.both -gt 0) { $verdict = 'has_part_in_sample' }
            elseif ($s.onlyProperties -eq $s.sampled) { $verdict = 'only_properties_in_sample' }
            else { $verdict = 'mixed_or_inconclusive' }
        }
        $rows.Add([pscustomobject]@{
                kb       = $kb
                type     = $type
                total    = $s.total
                sampled  = $s.sampled
                onlyProperties = $s.onlyProperties
                partOnly = $s.partOnly
                both     = $s.both
                noEnvelope = $s.noEnvelope
                verdict  = $verdict
            })
    }
}

if ($OutJson) {
    $rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutJson -Encoding utf8NoBOM
}
$rows | Format-Table -AutoSize
