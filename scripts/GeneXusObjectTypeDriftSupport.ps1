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

    $index = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new(
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

        $relativePath = [System.IO.Path]::GetRelativePath($RootPath, $file.FullName).Replace('\', '/')
        if (-not $index.ContainsKey($guidNormalized)) {
            $index[$guidNormalized] = [System.Collections.Generic.List[object]]::new()
        }

        $index[$guidNormalized].Add([pscustomobject]@{
            FullPath = $file.FullName
            AcervoPath = $relativePath
        }) | Out-Null
    }

    return $index
}

function Get-GeneXusObjectTypeGuidIndexMatches {
    param(
        [Parameter(Mandatory = $true)]$Index,
        [AllowNull()][string]$Guid
    )

    if ($null -eq $Index) {
        throw 'GeneXus Object/@type drift index is null. Build the GUID-first index before querying it.'
    }

    $guidNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $Guid
    if ([string]::IsNullOrWhiteSpace($guidNormalized)) {
        return @()
    }

    if (-not $Index.ContainsKey($guidNormalized)) {
        return @()
    }

    $itemsByPath = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($Index[$guidNormalized].ToArray())) {
        $pathKey = [string]$item.AcervoPath
        if (-not $itemsByPath.ContainsKey($pathKey)) {
            $itemsByPath[$pathKey] = $item
            $paths.Add($pathKey) | Out-Null
        }
    }
    $pathArray = $paths.ToArray()
    [array]::Sort($pathArray, [System.StringComparer]::Ordinal)
    $ordered = foreach ($path in $pathArray) { $itemsByPath[$path] }
    return @($ordered)
}

function New-GeneXusObjectTypeDriftCommonFields {
    param(
        [AllowNull()][string]$ObjectGuid,
        [AllowNull()][string]$MatchBasis,
        [AllowNull()][string]$FrontObjectType,
        [AllowNull()][string]$FrontObjectTypeNormalized,
        [AllowNull()][string]$AcervoObjectType,
        [AllowNull()][string]$AcervoObjectTypeNormalized,
        [AllowNull()][string]$AcervoPath,
        [string[]]$CandidateAcervoPaths = @(),
        [AllowNull()][string]$ObjectName,
        [AllowNull()][string]$FullyQualifiedName,
        [AllowNull()][string]$Message,
        [AllowNull()][string]$Code
    )

    $trimmedCode = if ($null -eq $Code) { '' } else { $Code.Trim() }
    $trimmedMessage = if ($null -eq $Message) { '' } else { $Message.Trim() }
    if (($trimmedCode -eq 'front-object-type-drift' -or $trimmedCode -eq 'front-object-type-drift-ambiguous-acervo') -and [string]::IsNullOrWhiteSpace($trimmedMessage)) {
        throw "Message obrigatorio para Code=$trimmedCode"
    }

    $candidatePaths = @($CandidateAcervoPaths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { ([string]$_).Trim().Replace('\', '/') })
    if ($candidatePaths.Count -gt 1) {
        [array]::Sort($candidatePaths, [System.StringComparer]::Ordinal)
    }
    if ($trimmedCode -eq 'front-object-type-drift-ambiguous-acervo' -and $candidatePaths.Count -eq 0) {
        throw "CandidateAcervoPaths obrigatorio para Code=$trimmedCode"
    }

    $fields = [ordered]@{}
    $normalizedObjectGuid = Normalize-GeneXusObjectTypeDriftValue -Value $ObjectGuid
    if (-not [string]::IsNullOrWhiteSpace($normalizedObjectGuid)) {
        $fields.objectGuid = $normalizedObjectGuid
    }
    if (-not [string]::IsNullOrWhiteSpace($ObjectName)) {
        $fields.objectName = $ObjectName.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($FullyQualifiedName)) {
        $fields.fullyQualifiedName = $FullyQualifiedName.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($FrontObjectType)) {
        $fields.frontObjectType = $FrontObjectType.Trim()
    }
    $frontTypeNormalized = if ([string]::IsNullOrWhiteSpace($FrontObjectTypeNormalized)) { Normalize-GeneXusObjectTypeDriftValue -Value $FrontObjectType } else { Normalize-GeneXusObjectTypeDriftValue -Value $FrontObjectTypeNormalized }
    if (-not [string]::IsNullOrWhiteSpace($frontTypeNormalized)) {
        $fields.frontObjectTypeNormalized = $frontTypeNormalized
    }
    if (-not [string]::IsNullOrWhiteSpace($AcervoObjectType)) {
        $fields.acervoObjectType = $AcervoObjectType.Trim()
    }
    $acervoTypeNormalized = if ([string]::IsNullOrWhiteSpace($AcervoObjectTypeNormalized)) { Normalize-GeneXusObjectTypeDriftValue -Value $AcervoObjectType } else { Normalize-GeneXusObjectTypeDriftValue -Value $AcervoObjectTypeNormalized }
    if (-not [string]::IsNullOrWhiteSpace($acervoTypeNormalized)) {
        $fields.acervoObjectTypeNormalized = $acervoTypeNormalized
    }
    if (-not [string]::IsNullOrWhiteSpace($MatchBasis)) {
        $fields.matchBasis = $MatchBasis.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($AcervoPath)) {
        $fields.acervoPath = $AcervoPath.Trim().Replace('\', '/')
    }
    if ($candidatePaths.Count -gt 0) {
        $fields.candidateAcervoPaths = @($candidatePaths)
    }
    if (-not [string]::IsNullOrWhiteSpace($trimmedMessage)) {
        $fields.message = $trimmedMessage
    }

    return $fields
}
