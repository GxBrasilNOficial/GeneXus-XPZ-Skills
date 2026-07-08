#requires -Version 7.4

Set-StrictMode -Version Latest

function Normalize-GeneXusObjectTypeDriftValue {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return $Value.Trim().ToLowerInvariant()
}

function New-GeneXusObjectTypeGuidIndex {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        throw "AcervoPath nao encontrado ou nao e pasta: $RootPath"
    }

    $index = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($file in @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue)) {
        try {
            [xml]$doc = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        } catch {
            continue
        }

        $root = $doc.DocumentElement
        if ($null -eq $root -or $root.LocalName -ne 'Object') {
            continue
        }

        $guidNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $root.GetAttribute('guid')
        if ([string]::IsNullOrWhiteSpace($guidNormalized)) {
            continue
        }

        if (-not $index.ContainsKey($guidNormalized)) {
            $index[$guidNormalized] = [System.Collections.Generic.List[string]]::new()
        }

        $index[$guidNormalized].Add($file.FullName) | Out-Null
    }

    return $index
}

function Get-GeneXusObjectTypeGuidIndexMatches {
    param(
        [Parameter(Mandatory = $true)]$Index,
        [AllowNull()][string]$Guid
    )

    $guidNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $Guid
    if ([string]::IsNullOrWhiteSpace($guidNormalized)) {
        return @()
    }

    if (-not $Index.ContainsKey($guidNormalized)) {
        return @()
    }

    return @($Index[$guidNormalized].ToArray())
}

function New-GeneXusObjectTypeDriftDiagnostic {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$MatchBasis,
        [AllowNull()][string]$FrontObjectType,
        [AllowNull()][string]$BaselineObjectType,
        [string[]]$CandidateBaselinePaths
    )

    return [ordered]@{
        code                         = $Code
        matchBasis                   = $MatchBasis
        frontObjectType              = $FrontObjectType
        baselineObjectType           = $BaselineObjectType
        frontObjectTypeNormalized    = Normalize-GeneXusObjectTypeDriftValue -Value $FrontObjectType
        baselineObjectTypeNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $BaselineObjectType
        candidateBaselinePaths       = @($CandidateBaselinePaths)
    }
}
