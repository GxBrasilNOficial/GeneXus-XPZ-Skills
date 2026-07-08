#requires -Version 7.4
<#
.SYNOPSIS
    Sugere metadata Java/Tomcat para kb-source-metadata.md sem gravar arquivo.

.DESCRIPTION
    Assistente opt-in do xpz-kb-parallel-setup. Le evidencias locais de model.ini e
    gradle.properties, valida topologia WEB-INF\classes, sentinela WEB-INF\lib\GeneXus.jar
    e pacote da app, e emite candidatos para KbEnvironmentServletDirs/KbEnvironmentAppPackage/
    KbEnvironmentServletFlavor. O script e read-only: nunca altera kb-source-metadata.md.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KbNativePath,

    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,

    [string]$OutputDir,

    [string]$WebDir,

    [string]$ModelIniPath,

    [string]$GradlePropertiesPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-KeyValueFile {
    param([string]$Path)

    $result = [ordered]@{}
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $result
    }

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) {
            continue
        }

        $parts = @($trimmed -split '=', 2)
        if ($parts.Count -ne 2) {
            continue
        }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if ($key.Length -gt 0) {
            $result[$key] = $value
        }
    }

    return $result
}

function Read-ModelIniMergedSections {
    param([string]$Path)

    $byNumber = @{}
    $currentNumber = '__global'

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0 -or $trimmed.StartsWith(';') -or $trimmed.StartsWith('#')) {
            continue
        }

        $sectionMatch = [regex]::Match($trimmed, '^\[(?<kind>[^\]\s]+)\s+(?<num>\d+)\]$')
        if ($sectionMatch.Success) {
            $currentNumber = $sectionMatch.Groups['num'].Value
            if (-not $byNumber.ContainsKey($currentNumber)) {
                $byNumber[$currentNumber] = [ordered]@{}
            }
            continue
        }

        if ($trimmed -match '^\[[^\]]+\]$') {
            $currentNumber = '__global'
            if (-not $byNumber.ContainsKey($currentNumber)) {
                $byNumber[$currentNumber] = [ordered]@{}
            }
            continue
        }

        $parts = @($trimmed -split '=', 2)
        if ($parts.Count -ne 2) {
            continue
        }

        if (-not $byNumber.ContainsKey($currentNumber)) {
            $byNumber[$currentNumber] = [ordered]@{}
        }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if ($key.Length -gt 0) {
            $byNumber[$currentNumber][$key] = $value
        }
    }

    return $byNumber
}

function Convert-EscapedWindowsPath {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return $Value.Trim().Replace('\\', '\')
}

function Get-PathLeafSafe {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    return Split-Path -Leaf ($Path.TrimEnd('\', '/'))
}

function Test-JavaTargetCandidate {
    param(
        [AllowNull()][string]$ServletDir,
        [AllowNull()][string]$AppPackage
    )

    $checks = [ordered]@{
        servletDirEndsWithWebInfClasses = $false
        servletDirExists = $false
        sentinelExists = $false
        appPackageExists = $false
    }

    $messages = New-Object System.Collections.Generic.List[string]

    if ([string]::IsNullOrWhiteSpace($ServletDir)) {
        $messages.Add('SERVLET_DIR candidato ausente.') | Out-Null
        return [pscustomobject]@{ checks = $checks; messages = $messages.ToArray(); valid = $false; webappRoot = $null }
    }

    $normalized = $ServletDir.TrimEnd('\', '/')
    $leaf = Split-Path -Leaf $normalized
    $parent = Split-Path -Parent $normalized
    $parentLeaf = if ($parent) { Split-Path -Leaf $parent } else { '' }
    $checks.servletDirEndsWithWebInfClasses = (($leaf -ieq 'classes') -and ($parentLeaf -ieq 'WEB-INF'))
    if (-not $checks.servletDirEndsWithWebInfClasses) {
        $messages.Add("SERVLET_DIR nao termina em WEB-INF\classes: $ServletDir") | Out-Null
    }

    $checks.servletDirExists = (Test-Path -LiteralPath $normalized -PathType Container)
    if (-not $checks.servletDirExists) {
        $messages.Add("SERVLET_DIR nao existe como diretorio: $ServletDir") | Out-Null
    }

    $webappRoot = if ($parent) { Split-Path -Parent $parent } else { $null }
    if ($webappRoot) {
        $sentinelPath = Join-Path $webappRoot 'WEB-INF\lib\GeneXus.jar'
        $checks.sentinelExists = (Test-Path -LiteralPath $sentinelPath -PathType Leaf)
        if (-not $checks.sentinelExists) {
            $messages.Add("Sentinela WEB-INF\lib\GeneXus.jar ausente sob $webappRoot") | Out-Null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($AppPackage)) {
        $packagePath = Join-Path $normalized ($AppPackage.Trim().TrimStart('\', '/').TrimEnd('\', '/'))
        $checks.appPackageExists = (Test-Path -LiteralPath $packagePath -PathType Container)
        if (-not $checks.appPackageExists) {
            $messages.Add("Pacote da app nao encontrado em WEB-INF\classes: $AppPackage") | Out-Null
        }
    } else {
        $messages.Add('Pacote da app ausente; nao varrer com\ inteiro para inferir.') | Out-Null
    }

    $valid = $checks.servletDirEndsWithWebInfClasses -and $checks.servletDirExists -and $checks.sentinelExists -and $checks.appPackageExists
    return [pscustomobject]@{ checks = $checks; messages = $messages.ToArray(); valid = $valid; webappRoot = $webappRoot }
}

$resolvedKbNativePath = [System.IO.Path]::GetFullPath($KbNativePath)
if (-not (Test-Path -LiteralPath $resolvedKbNativePath -PathType Container)) {
    throw "BLOCK: KbNativePath nao encontrado: $resolvedKbNativePath"
}

if ([string]::IsNullOrWhiteSpace($ModelIniPath)) {
    $ModelIniPath = Join-Path $resolvedKbNativePath 'model.ini'
}
if ([string]::IsNullOrWhiteSpace($WebDir) -and -not [string]::IsNullOrWhiteSpace($OutputDir)) {
    $WebDir = Join-Path (Join-Path $resolvedKbNativePath $OutputDir) 'web'
}
if ([string]::IsNullOrWhiteSpace($GradlePropertiesPath) -and -not [string]::IsNullOrWhiteSpace($WebDir)) {
    $GradlePropertiesPath = Join-Path $WebDir 'gradle.properties'
}

$warnings = New-Object System.Collections.Generic.List[string]
$evidence = [ordered]@{
    modelIniPath = $ModelIniPath
    modelIniFound = (Test-Path -LiteralPath $ModelIniPath -PathType Leaf)
    gradlePropertiesPath = $GradlePropertiesPath
    gradlePropertiesFound = (Test-Path -LiteralPath $GradlePropertiesPath -PathType Leaf)
    modelIniCandidates = @()
    gradleCandidate = $null
}

$modelCandidate = $null
if ($evidence.modelIniFound) {
    $sections = Read-ModelIniMergedSections -Path $ModelIniPath
    $matches = New-Object System.Collections.Generic.List[object]
    foreach ($sectionNumber in $sections.Keys) {
        $section = $sections[$sectionNumber]
        $modelName = if ($section.Contains('Model')) { $section['Model'] } else { $null }
        $targetFullPath = if ($section.Contains('TargetFullPath')) { $section['TargetFullPath'] } else { $null }
        $targetLeaf = Get-PathLeafSafe -Path $targetFullPath

        $nameMatches = ($modelName -and ($modelName -ieq $EnvironmentName))
        $outputMatches = (-not [string]::IsNullOrWhiteSpace($OutputDir) -and $targetLeaf -and ($targetLeaf -ieq (Get-PathLeafSafe -Path $OutputDir)))
        if (-not $nameMatches -and -not $outputMatches) {
            continue
        }

        $candidate = [ordered]@{
            sectionNumber = $sectionNumber
            model = $modelName
            targetFullPath = $targetFullPath
            servletDir = if ($section.Contains('SERVLET_DIR')) { $section['SERVLET_DIR'] } else { $null }
            javaPlatformSupport = if ($section.Contains('JAVA_PLATFORM_SUPPORT')) { $section['JAVA_PLATFORM_SUPPORT'] } else { $null }
            tomcatVersion = if ($section.Contains('TOMCAT_VERSION')) { $section['TOMCAT_VERSION'] } else { $null }
        }
        $matches.Add([pscustomobject]$candidate) | Out-Null
    }

    $evidence.modelIniCandidates = $matches.ToArray()
    if ($matches.Count -eq 1) {
        $modelCandidate = $matches[0]
    } elseif ($matches.Count -gt 1) {
        $warnings.Add('model.ini tem mais de um bloco candidato; nao escolher automaticamente.') | Out-Null
    }
}

$gradleCandidate = $null
if ($evidence.gradlePropertiesFound) {
    $gradle = Read-KeyValueFile -Path $GradlePropertiesPath
    $webappRoot = if ($gradle.Contains('TOMCAT_WEBAPP_PATH')) { Convert-EscapedWindowsPath $gradle['TOMCAT_WEBAPP_PATH'] } else { $null }
    $servletDir = if ($webappRoot) { Join-Path $webappRoot 'WEB-INF\classes' } else { $null }
    $appPackage = if ($gradle.Contains('JAVA_PACKAGE_NAME_FOLDER')) { Convert-EscapedWindowsPath $gradle['JAVA_PACKAGE_NAME_FOLDER'] } else { $null }
    $javaPlatform = if ($gradle.Contains('JAVA_PLATFORM')) { $gradle['JAVA_PLATFORM'] } else { $null }
    $servletVersion = if ($gradle.Contains('SERVLET_VERSION')) { $gradle['SERVLET_VERSION'] } else { $null }
    $flavor = $null
    if ($javaPlatform -and $javaPlatform -match 'jakarta') {
        $flavor = 'jakarta'
    } elseif ($javaPlatform -and $javaPlatform -match 'javaEE') {
        $warnings.Add('JAVA_PLATFORM=javaEE nao prova stack javax puro; servlet_flavor exige confirmacao humana.') | Out-Null
    }

    $gradleCandidate = [pscustomobject][ordered]@{
        webappRoot = $webappRoot
        servletDir = $servletDir
        appPackage = $appPackage
        javaPlatform = $javaPlatform
        servletVersion = $servletVersion
        servletFlavor = $flavor
    }
    $evidence.gradleCandidate = $gradleCandidate
}

$selectedServletDir = $null
$selectedAppPackage = $null
$selectedFlavor = $null
$source = $null

if ($gradleCandidate -and $gradleCandidate.servletDir) {
    $selectedServletDir = $gradleCandidate.servletDir
    $selectedAppPackage = $gradleCandidate.appPackage
    $selectedFlavor = $gradleCandidate.servletFlavor
    $source = 'gradle.properties'
} elseif ($modelCandidate -and $modelCandidate.servletDir) {
    $selectedServletDir = $modelCandidate.servletDir
    $source = 'model.ini'
}

if ($gradleCandidate -and $modelCandidate -and $gradleCandidate.servletDir -and $modelCandidate.servletDir) {
    $gradleNorm = $gradleCandidate.servletDir.TrimEnd('\', '/')
    $modelNorm = $modelCandidate.servletDir.TrimEnd('\', '/')
    if ($gradleNorm -ine $modelNorm) {
        $warnings.Add('model.ini e gradle.properties apontam SERVLET_DIR/TOMCAT_WEBAPP_PATH diferentes; tratar como auditoria, nao escrita cega.') | Out-Null
    }
}

$validation = Test-JavaTargetCandidate -ServletDir $selectedServletDir -AppPackage $selectedAppPackage
foreach ($message in $validation.messages) {
    $warnings.Add($message) | Out-Null
}

$status = if ($validation.valid -and $selectedServletDir -and $selectedAppPackage) {
    if ($warnings.Count -gt 0) { 'needs-confirmation' } else { 'suggestion-ready' }
} elseif ($selectedServletDir) {
    'blocked'
} else {
    'not-found'
}

$result = [ordered]@{
    status = $status
    readOnly = $true
    environmentName = $EnvironmentName
    outputDir = $OutputDir
    webDir = $WebDir
    suggestionSource = $source
    suggestedMetadata = [ordered]@{
        KbEnvironmentServletDirs = if ($selectedServletDir) { "$EnvironmentName=$selectedServletDir" } else { $null }
        KbEnvironmentAppPackage = if ($selectedAppPackage) { "$EnvironmentName=$selectedAppPackage" } else { $null }
        KbEnvironmentServletFlavor = if ($selectedFlavor) { "$EnvironmentName=$selectedFlavor" } else { $null }
    }
    validation = $validation
    warnings = $warnings.ToArray()
    evidence = $evidence
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 10
} else {
    "JAVA_TOMCAT_METADATA_SUGGESTION: status=$status source=$source"
    foreach ($key in $result.suggestedMetadata.Keys) {
        $value = $result.suggestedMetadata[$key]
        if ($value) {
            "${key}: $value"
        }
    }
    foreach ($warning in $result.warnings) {
        "WARNING: $warning"
    }
}
