#requires -Version 7.4

<#
.SYNOPSIS
    Suporte para localizar atribuicoes de atributo Transaction em .cs gerado GeneXus (camada web).
#>

Set-StrictMode -Version Latest

$script:MethodSignaturePattern = [regex]::new(
    '^\s*(?:protected|public|private)\s+[\w<>\[\],\s]+\s+([A-Za-z0-9_]+)\s*\('
)
$script:TypeDeclarationLinePattern = [regex]::new(
    '^\s*(?:long|string|bool|int|short|byte|decimal|double|float|DateTime|Guid)\s+',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$script:CanonicalAttributePattern = [regex]::new('^(A\d+)(.+)$')
$script:InsertOverrideConditionPattern = [regex]::new(
    'StringUtil\.StrCmp\s*\(\s*Gx_mode\s*,\s*"INS"\s*\)\s*==\s*0',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$script:InsertOverrideInsertPattern = [regex]::new(
    'Insert_',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$script:DefaultByProcPattern = [regex]::new(
    'new\s+\w+\s*\([^)]*context[^)]*\)\s*\.\s*execute\s*\(',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$script:MaxMethodScanLines = 3000
$script:TripletMaxSpanLines = 30
$script:OutputAssignmentLimit = 50
$script:OutputHeadCount = 20
$script:OutputTailCount = 5

function Read-GeneXusCsFileLines {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CsPath
    )

    $rawLines = [string[]]([System.IO.File]::ReadAllLines($CsPath))
    if ($rawLines.Count -lt 1) {
        return @()
    }

    # Linhas vazias no array quebram o bind de [string[]] em funções dot-sourced no mesmo escopo.
    $normalized = New-Object string[] $rawLines.Length
    for ($i = 0; $i -lt $rawLines.Length; $i++) {
        $lineText = $rawLines[$i]
        if ([string]::IsNullOrEmpty($lineText)) {
            $normalized[$i] = ' '
        } else {
            $normalized[$i] = $lineText
        }
    }
    return $normalized
}

function Get-LineSnippet {
    param(
        [string]$SourceLine,
        [int]$MaxLength = 200
    )

    if ($null -eq $SourceLine) { return '' }
    $trimmed = $SourceLine.Trim()
    if ($trimmed.Length -le $MaxLength) { return $trimmed }
    return $trimmed.Substring(0, $MaxLength) + '...'
}

function Resolve-GeneXusAttributeCanonicalName {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string[]]$CsFileLines,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$AttributeLookupName
    )

    $trimmed = $AttributeLookupName.Trim()
    if ($script:CanonicalAttributePattern.IsMatch($trimmed)) {
        return $trimmed
    }

    $escaped = [regex]::Escape($trimmed)
    $discoveryPattern = [regex]::new("(A\d+$escaped)\s*=")
    foreach ($scanLine in $CsFileLines) {
        $match = $discoveryPattern.Match($scanLine)
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    return $trimmed
}

function Test-IsGeneXusAttributeAssignmentLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AttrScanLine,

        [Parameter(Mandatory = $true)]
        [string]$AttrCanonical
    )

    if ($script:TypeDeclarationLinePattern.IsMatch($AttrScanLine)) {
        return $false
    }

    $escaped = [regex]::Escape($AttrCanonical)
    $assignPattern = [regex]::new("(?<![\w\.])$escaped\s*=")
    return $assignPattern.IsMatch($AttrScanLine)
}

function Get-EnclosingMethodInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CsFileLines,

        [Parameter(Mandatory = $true)]
        [int]$LineNumber
    )

    if ($LineNumber -lt 1) {
        return [pscustomobject]@{
            Name      = '<unknown>'
            StartLine = 1
        }
    }

    $zeroIndex = $LineNumber - 1
    $minIndex = [Math]::Max(0, $zeroIndex - $script:MaxMethodScanLines)

    for ($i = $zeroIndex; $i -ge $minIndex; $i--) {
        $match = $script:MethodSignaturePattern.Match($CsFileLines[$i])
        if ($match.Success) {
            return [pscustomobject]@{
                Name      = $match.Groups[1].Value
                StartLine = $i + 1
            }
        }
    }

    return [pscustomobject]@{
        Name      = '<unknown>'
        StartLine = [Math]::Max(1, $zeroIndex + 1 - $script:MaxMethodScanLines)
    }
}

function Get-MethodEndLine {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CsFileLines,

        [Parameter(Mandatory = $true)]
        [int]$MethodStartLine
    )

    $startIndex = $MethodStartLine - 1
    for ($i = $startIndex + 1; $i -lt $CsFileLines.Length; $i++) {
        if ($script:MethodSignaturePattern.IsMatch($CsFileLines[$i])) {
            return $i
        }
    }
    return $CsFileLines.Length
}

function Test-MethodHasAssignAttri {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CsFileLines,

        [Parameter(Mandatory = $true)]
        [int]$MethodStartLine,

        [Parameter(Mandatory = $true)]
        [int]$MethodEndLine,

        [Parameter(Mandatory = $true)]
        [string]$AttrCanonical
    )

    $escaped = [regex]::Escape($AttrCanonical)
    $pattern = [regex]::new("AssignAttri\s*\([^)]*""$escaped""")
    $startIndex = $MethodStartLine - 1
    $endIndex = $MethodEndLine - 1
    for ($i = $startIndex; $i -le $endIndex; $i++) {
        if ($pattern.IsMatch($CsFileLines[$i])) {
            return $true
        }
    }
    return $false
}

function Get-AssignmentRole {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CsFileLines,

        [Parameter(Mandatory = $true)]
        [int]$LineNumber
    )

    if ($LineNumber -lt 1 -or $LineNumber -gt @($CsFileLines).Count) {
        return $null
    }

    $contextBuilder = [System.Text.StringBuilder]::new()
    $startIndex = [Math]::Max(0, $LineNumber - 4)
    for ($i = $startIndex; $i -lt $LineNumber; $i++) {
        if ($contextBuilder.Length -gt 0) {
            [void]$contextBuilder.Append(' ')
        }
        [void]$contextBuilder.Append($CsFileLines[$i])
    }
    $context = $contextBuilder.ToString()

    if ($script:InsertOverrideConditionPattern.IsMatch($context) -and $script:InsertOverrideInsertPattern.IsMatch($context)) {
        return 'override'
    }
    if ($script:DefaultByProcPattern.IsMatch($CsFileLines[$LineNumber - 1])) {
        return 'default'
    }
    if ($CsFileLines[$LineNumber - 1].Contains('?') -and $CsFileLines[$LineNumber - 1].Contains(':')) {
        return 'fallback'
    }
    return $null
}

function Get-TripletCascadeOrder {
    param(
        [Parameter(Mandatory = $true)]
        [array]$RoleAssignments
    )

    $ordered = @($RoleAssignments | Sort-Object -Property line)
    $labels = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $ordered) {
        switch ($item.role) {
            'override' { $labels.Add('override') | Out-Null }
            'default' { $labels.Add('default') | Out-Null }
            'fallback' { $labels.Add('fallback') | Out-Null }
            default { $labels.Add('unknown') | Out-Null }
        }
    }
    return ($labels -join '-then-')
}

function Get-MethodTripletAnalysis {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$CsFileLines,

        [Parameter(Mandatory = $true)]
        [object[]]$Assignments
    )

    $geneXusFileLinesLocal = $CsFileLines

    if ($Assignments.Count -lt 3) {
        return [pscustomobject]@{
            TripletDetected = $false
            TripletPattern  = $null
        }
    }

    $sorted = @($Assignments | Sort-Object -Property line)
    for ($start = 0; $start -le ($sorted.Count - 3); $start++) {
        $window = @($sorted[$start], $sorted[$start + 1], $sorted[$start + 2])
        $firstLine = [int]$window[0].line
        $lastLine = [int]$window[2].line
        if (($lastLine - $firstLine) -gt $script:TripletMaxSpanLines) {
            continue
        }

        $roles = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $window) {
            $role = Get-AssignmentRole -CsFileLines $geneXusFileLinesLocal -LineNumber $item.line
            if ($null -eq $role) {
                $roles = $null
                break
            }
            $roles.Add([pscustomobject]@{ line = $item.line; role = $role }) | Out-Null
        }

        if ($null -eq $roles -or $roles.Count -ne 3) {
            continue
        }

        $roleNames = @($roles | ForEach-Object { $_.role })
        if ($roleNames -contains 'override' -and $roleNames -contains 'default' -and $roleNames -contains 'fallback') {
            $overrideLine = ($roles | Where-Object { $_.role -eq 'override' } | Select-Object -First 1).line
            $defaultLine = ($roles | Where-Object { $_.role -eq 'default' } | Select-Object -First 1).line
            $fallbackLine = ($roles | Where-Object { $_.role -eq 'fallback' } | Select-Object -First 1).line
            return [pscustomobject]@{
                TripletDetected = $true
                TripletPattern  = [pscustomobject]@{
                    insertOverrideLine = $overrideLine
                    defaultByProcLine  = $defaultLine
                    fallbackRuleLine   = $fallbackLine
                    cascadeOrder       = (Get-TripletCascadeOrder -RoleAssignments $roles)
                }
            }
        }
    }

    return [pscustomobject]@{
        TripletDetected = $false
        TripletPattern  = $null
    }
}

function Get-GeneXusCsAttributeAssignmentReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CsPath,

        [Parameter(Mandatory = $true)]
        [string]$AttributeLookupName
    )

    if (-not (Test-Path -LiteralPath $CsPath -PathType Leaf)) {
        throw "CS_NOT_FOUND: $CsPath"
    }

    $attrLookup = $AttributeLookupName.Trim()
    $gxCsAllLines = Read-GeneXusCsFileLines -CsPath $CsPath
    if ($gxCsAllLines.Count -lt 1) {
        throw "CS_EMPTY: nenhuma linha lida de $CsPath"
    }

    $resolvedCanonical = Resolve-GeneXusAttributeCanonicalName -CsFileLines $gxCsAllLines -AttributeLookupName $attrLookup

    $rawAssignments = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $gxCsAllLines.Length; $i++) {
        $lineNumber = $i + 1
        if (-not (Test-IsGeneXusAttributeAssignmentLine -AttrScanLine $gxCsAllLines[$i] -AttrCanonical $resolvedCanonical)) {
            continue
        }

        $methodInfo = Get-EnclosingMethodInfo -CsFileLines $gxCsAllLines -LineNumber $lineNumber
        $rawAssignments.Add([pscustomobject]@{
            line       = $lineNumber
            snippet    = Get-LineSnippet -SourceLine $gxCsAllLines[$i]
            methodName = $methodInfo.Name
            startLine  = $methodInfo.StartLine
        }) | Out-Null
    }

    $methodGroups = @{}
    foreach ($item in $rawAssignments) {
        $key = '{0}|{1}' -f $item.methodName, $item.startLine
        if (-not $methodGroups.ContainsKey($key)) {
            $methodGroups[$key] = [System.Collections.Generic.List[object]]::new()
        }
        $methodGroups[$key].Add($item) | Out-Null
    }

    $methods = [System.Collections.Generic.List[object]]::new()
    $assignAttriTotal = 0

    foreach ($key in ($methodGroups.Keys | Sort-Object)) {
        $groupItems = @($methodGroups[$key] | Sort-Object -Property line)
        $first = $groupItems[0]
        $methodEnd = Get-MethodEndLine -CsFileLines $gxCsAllLines -MethodStartLine $first.startLine
        $hasAssignAttri = Test-MethodHasAssignAttri `
            -CsFileLines $gxCsAllLines `
            -MethodStartLine $first.startLine `
            -MethodEndLine $methodEnd `
            -AttrCanonical $resolvedCanonical

        if ($hasAssignAttri) {
            $assignAttriTotal++
        }

        $assignmentRows = [System.Collections.Generic.List[object]]::new()
        foreach ($g in $groupItems) {
            $assignmentRows.Add([pscustomobject]@{
                line                   = $g.line
                snippet                = $g.snippet
                hasAssignAttriInMethod = $hasAssignAttri
            }) | Out-Null
        }

        $triplet = Get-MethodTripletAnalysis -CsFileLines $gxCsAllLines -Assignments @($assignmentRows.ToArray())

        $methods.Add([pscustomobject]@{
            name            = $first.methodName
            startLine       = $first.startLine
            assignments     = $assignmentRows.ToArray()
            tripletDetected = $triplet.TripletDetected
            tripletPattern  = $triplet.TripletPattern
        }) | Out-Null
    }

    $assignmentCount = $rawAssignments.Count
    $outputTruncated = $false
    $displayAssignments = $rawAssignments

    if ($assignmentCount -gt $script:OutputAssignmentLimit) {
        $outputTruncated = $true
        $head = @($rawAssignments | Select-Object -First $script:OutputHeadCount)
        $tail = @($rawAssignments | Select-Object -Last $script:OutputTailCount)
        $displayAssignments = @($head + $tail)
    }

    return [pscustomobject]@{
        CsPath                  = (Resolve-Path -LiteralPath $CsPath).Path
        Attribute               = $attrLookup
        AttributeCanonicalName  = $resolvedCanonical
        Methods                 = $methods.ToArray()
        Totals                  = [pscustomobject]@{
            assignmentCount  = $assignmentCount
            methodCount      = $methods.Count
            assignAttriCount = $assignAttriTotal
        }
        OutputTruncated         = $outputTruncated
        TruncationSummary       = if ($outputTruncated) {
            "assignmentCount=$assignmentCount; exibindo primeiras $script:OutputHeadCount e ultimas $script:OutputTailCount"
        } else {
            $null
        }
        DisplayAssignments      = @($displayAssignments)
    }
}
