#requires -Version 7.4

<#
.SYNOPSIS
Extrai sinais compactos de logs MSBuild de preview/importacao GeneXus.

.DESCRIPTION
Le msbuild.stdout.log e msbuild.stderr.log, ou um diretório que contenha esses
arquivos, e retorna JSON compacto para evitar colagem de logs longos na conversa.

.PARAMETER Path
Caminho de um diretório de artefatos MSBuild ou de um arquivo stdout.log.

.PARAMETER StdOutPath
Caminho explicito para msbuild.stdout.log.

.PARAMETER StdErrPath
Caminho explicito para msbuild.stderr.log.

.PARAMETER RequestedVersionName
Nome de versao solicitado pelo wrapper (contexto). Quando informado (junto das flags), o leitor
usa a funcao compartilhada de leitura de contexto e separa activeVersion (efetivo) de
activeVersionAtOpen. Omitido => modo legado.

.PARAMETER RequestedEnvironmentName
Nome de Environment solicitado pelo wrapper (contexto). Mesmo contrato de -RequestedVersionName.

.PARAMETER SetVersionFailed
Flag explicita de falha de SetActiveVersion. Distingue omitido de $false explicito; quando
informada, permite decidir o contexto efetivo com uma unica leitura.

.PARAMETER SetEnvironmentFailed
Flag explicita de falha de SetActiveEnvironment. Mesmo contrato de -SetVersionFailed.

.PARAMETER Stage
Nome livre da etapa consumidora, por exemplo import-preview ou import-real.

.PARAMETER OutputPath
Quando informado, grava o mesmo JSON compacto nesse caminho.

.PARAMETER AsJson
Retorna JSON estruturado.
#>

[CmdletBinding()]
param(
    [string]$Path,
    [string]$StdOutPath,
    [string]$StdErrPath,
    [string]$ExpectedItems,
    [string]$RequestedVersionName,
    [string]$RequestedEnvironmentName,
    [switch]$SetVersionFailed,
    [switch]$SetEnvironmentFailed,
    [string]$Stage = 'import',
    [string]$OutputPath,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$activeContextSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusMsBuildActiveContextSupport.ps1'
if (-not (Test-Path -LiteralPath $activeContextSupportPath -PathType Leaf)) {
    throw "Active context support script not found: $activeContextSupportPath"
}
. $activeContextSupportPath


function Read-TextFileSafe {
    param([string]$FilePath)

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return ''
    }
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return ''
    }
    return [System.IO.File]::ReadAllText($FilePath)
}

function Split-NonEmptyLines {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @($Text -split "\r?\n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
}

function Get-MatchingLines {
    param(
        [string]$Text,
        [string]$Prefix
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @(
        $Text -split "\r?\n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_.StartsWith($Prefix, [System.StringComparison]::Ordinal) } |
            ForEach-Object { $_.Substring($Prefix.Length).Trim() }
    )
}

function Get-RegexValue {
    param(
        [string]$Text,
        [string]$Pattern
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }
    $match = [regex]::Match($Text, $Pattern)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value
}

function Get-WarningLines {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @(
        [regex]::Matches($Text, '(?im)^[^\r\n]*(?:\(\d+,\d+\)\s*:\s*)?warning\s*:[^\r\n]*') |
            ForEach-Object { $_.Value.Trim() }
    )
}

function Split-ItemFilter {
    param([string]$FilterText)

    if ([string]::IsNullOrWhiteSpace($FilterText)) {
        return @()
    }

    return @($FilterText -split ',|;|\r\n|\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() })
}

function ConvertTo-CanonicalGeneXusItem {
    param([string]$Item)

    if ([string]::IsNullOrWhiteSpace($Item)) {
        return $null
    }

    $trimmed = $Item.Trim()
    $parts = @($trimmed -split ':', 2)
    if ($parts.Count -ne 2) {
        return $trimmed
    }

    $typeName = $parts[0].Trim()
    $objectName = $parts[1].Trim()
    if ([string]::IsNullOrWhiteSpace($typeName) -or [string]::IsNullOrWhiteSpace($objectName)) {
        return $trimmed
    }

    $canonicalType = switch -Regex ($typeName) {
        '^(?i:Panel|SDPanel)$' { 'Panel'; break }
        default { $typeName }
    }

    return ('{0}:{1}' -f $canonicalType, $objectName)
}

function Get-GeneXusItemAliasMatches {
    param(
        [string[]]$ExpectedRaw,
        [string[]]$ImportedRaw
    )

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($expected in @($ExpectedRaw)) {
        $expectedCanonical = ConvertTo-CanonicalGeneXusItem -Item $expected
        if ([string]::IsNullOrWhiteSpace($expectedCanonical)) {
            continue
        }

        foreach ($imported in @($ImportedRaw)) {
            $importedCanonical = ConvertTo-CanonicalGeneXusItem -Item $imported
            if ([string]::IsNullOrWhiteSpace($importedCanonical)) {
                continue
            }
            if ($expectedCanonical -eq $importedCanonical -and $expected -ne $imported) {
                [void]$result.Add([ordered]@{
                    expectedRaw = $expected
                    importedRaw = $imported
                    canonical = $expectedCanonical
                })
            }
        }
    }

    return @($result)
}

function Get-ErrorLines {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }
    return @(
        [regex]::Matches($Text, '(?im)^[^\r\n]*(?:\(\d+,\d+\)\s*:\s*)?error\s*:[^\r\n]*') |
            ForEach-Object { $_.Value.Trim() }
    )
}

function Get-LayoutWarnings {
    param([string[]]$Warnings)

    $groups = [ordered]@{}
    $pattern = "Layout com identificador incorreto '([^']+)'\s+\(Panel '([^']+)', Layout\)"
    foreach ($warning in $Warnings) {
        $match = [regex]::Match($warning, $pattern)
        if (-not $match.Success) {
            continue
        }
        $layoutId = $match.Groups[1].Value
        $panelName = $match.Groups[2].Value
        if (-not $groups.Contains($panelName)) {
            $groups[$panelName] = [System.Collections.Generic.List[string]]::new()
        }
        if (-not $groups[$panelName].Contains($layoutId)) {
            [void]$groups[$panelName].Add($layoutId)
        }
    }

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($panelName in $groups.Keys) {
        $entry = [ordered]@{
            panelName = $panelName
            layoutIds = @($groups[$panelName])
            count = $groups[$panelName].Count
        }
        [void]$result.Add($entry)
    }
    return @($result)
}

function Get-KnownStdOutNoise {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($line in (Split-NonEmptyLines -Text $Text)) {
        if ($line -match "O acesso ao caminho 'C:\\Program Files \(x86\)\\GeneXus\\GeneXus18\\CssProperties\.json' foi negado\.") {
            [void]$result.Add([ordered]@{
                code = 'cssproperties-access-denied'
                classification = 'known-environment-noise'
                line = $line
            })
        }
    }
    return @($result)
}

function Get-InvalidTypesRejected {
    param([string[]]$ErrorLines)

    $rejected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($line in @($ErrorLines)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        $match = [regex]::Match($line, '(?i)(\S+)\s+is not a valid type')
        if ($match.Success) {
            [void]$rejected.Add($match.Groups[1].Value)
        }
    }
    return @($rejected | Sort-Object)
}

function Get-GxImportLogReadSignal {
    param([string[]]$Texts)

    foreach ($text in @($Texts)) {
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        foreach ($line in (Split-NonEmptyLines -Text $text)) {
            if ($line -notmatch 'GxImport\.log') {
                continue
            }

            if ($line -match '(?i)(being used by another process|used by another process|process cannot access the file|processo.*nao.*pode.*acessar.*arquivo.*sendo usado|processo.*não.*pode.*acessar.*arquivo.*sendo usado|bloqueado por outro processo)') {
                return [ordered]@{
                    status = 'locked'
                    error = $line
                    diagnosticDegraded = $true
                }
            }

            if ($line -match '(?i)(cannot access|access.*denied|acesso.*negado|erro.*GxImport\.log|falha.*GxImport\.log)') {
                return [ordered]@{
                    status = 'error'
                    error = $line
                    diagnosticDegraded = $true
                }
            }
        }
    }

    return [ordered]@{
        status = 'ok'
        error = $null
        diagnosticDegraded = $false
    }
}

if (-not [string]::IsNullOrWhiteSpace($Path)) {
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $resolvedPath -PathType Container) {
        if ([string]::IsNullOrWhiteSpace($StdOutPath)) {
            $StdOutPath = Join-Path $resolvedPath 'msbuild.stdout.log'
        }
        if ([string]::IsNullOrWhiteSpace($StdErrPath)) {
            $StdErrPath = Join-Path $resolvedPath 'msbuild.stderr.log'
        }
    } elseif (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
        if ([string]::IsNullOrWhiteSpace($StdOutPath)) {
            $StdOutPath = $resolvedPath
        }
        if ([string]::IsNullOrWhiteSpace($StdErrPath)) {
            $candidateErr = $resolvedPath -replace 'stdout', 'stderr'
            if ($candidateErr -ne $resolvedPath -and (Test-Path -LiteralPath $candidateErr -PathType Leaf)) {
                $StdErrPath = $candidateErr
            }
        }
    } else {
        throw "Path nao encontrado: $Path"
    }
}

if ([string]::IsNullOrWhiteSpace($StdOutPath) -and [string]::IsNullOrWhiteSpace($StdErrPath)) {
    throw 'Informe -Path, -StdOutPath ou -StdErrPath.'
}

$stdOutText = Read-TextFileSafe -FilePath $StdOutPath
$stdErrText = Read-TextFileSafe -FilePath $StdErrPath

# Contexto ativo: com contexto informado pelo wrapper, usa a funcao compartilhada
# (AtOpen/Effective); sem contexto (chamada direta/legado), best-effort com a 1a leitura e
# AtOpen nulo. Omitido vs nome vazio vs flag $false explicita sao distinguidos via
# $PSBoundParameters e refletidos em contextQuality (legacy|partial|complete).
$versionPattern = "The active version is '([^']+)'"
$environmentPattern = "The active environment is '([^']+)'"
$requestedProvided = $PSBoundParameters.ContainsKey('RequestedVersionName') -or $PSBoundParameters.ContainsKey('RequestedEnvironmentName')
$flagsProvided = $PSBoundParameters.ContainsKey('SetVersionFailed') -or $PSBoundParameters.ContainsKey('SetEnvironmentFailed')
$contextProvided = $requestedProvided -or $flagsProvided

$activeContextFields = [ordered]@{
    activeVersion           = $null
    activeEnvironment       = $null
    activeVersionAtOpen     = $null
    activeEnvironmentAtOpen = $null
    contextQuality          = $null
}

if (-not $contextProvided) {
    $activeContextFields.contextQuality = 'legacy'
    $activeContextFields.activeVersion = Get-RegexValue -Text $stdOutText -Pattern $versionPattern
    $activeContextFields.activeEnvironment = Get-RegexValue -Text $stdOutText -Pattern $environmentPattern
}
else {
    $contextQuality = if ($requestedProvided -and $flagsProvided) { 'complete' } else { 'partial' }
    $activeContextFields.contextQuality = $contextQuality
    $versionReadings = Resolve-GeneXusKbActiveContextReadings -Text $stdOutText -Pattern $versionPattern -RequestedName $RequestedVersionName -SetFailed $SetVersionFailed.IsPresent
    $environmentReadings = Resolve-GeneXusKbActiveContextReadings -Text $stdOutText -Pattern $environmentPattern -RequestedName $RequestedEnvironmentName -SetFailed $SetEnvironmentFailed.IsPresent
    $activeContextFields.activeVersion = $versionReadings.Effective
    $activeContextFields.activeEnvironment = $environmentReadings.Effective
    $activeContextFields.activeVersionAtOpen = $versionReadings.AtOpen
    $activeContextFields.activeEnvironmentAtOpen = $environmentReadings.AtOpen
}

if ($Stage -eq 'export') {
    $exportErrors = @()
    $exportErrors += @(Get-ErrorLines -Text $stdOutText)
    $exportErrors += @(Get-ErrorLines -Text $stdErrText)
    $invalidTypesRejected = @(Get-InvalidTypesRejected -ErrorLines $exportErrors)
    $gxWarnings = @(Get-WarningLines -Text $stdOutText)
    $knownStdOutNoise = @(Get-KnownStdOutNoise -Text $stdOutText)

    $signals = [ordered]@{
        status = 'export-signals-read'
        stage = $Stage
        exportErrors = @($exportErrors)
        invalidTypesRejected = @($invalidTypesRejected)
        gxWarnings = @($gxWarnings)
        knownStdOutNoise = @($knownStdOutNoise)
        exportMarkerFound = ($stdOutText -match '__EXPORTED_FILE__=')
        exportTaskSuccess = ($stdOutText -match 'Export (Sucesso|Success)')
        activeVersion = $activeContextFields.activeVersion
        activeEnvironment = $activeContextFields.activeEnvironment
        activeVersionAtOpen = $activeContextFields.activeVersionAtOpen
        activeEnvironmentAtOpen = $activeContextFields.activeEnvironmentAtOpen
        contextQuality = $activeContextFields.contextQuality
        counts = [ordered]@{
            exportErrors = $exportErrors.Count
            invalidTypesRejected = $invalidTypesRejected.Count
            gxWarnings = $gxWarnings.Count
            knownStdOutNoise = $knownStdOutNoise.Count
        }
        artifacts = [ordered]@{
            StdOutPath = if ([string]::IsNullOrWhiteSpace($StdOutPath)) { $null } else { [System.IO.Path]::GetFullPath($StdOutPath) }
            StdErrPath = if ([string]::IsNullOrWhiteSpace($StdErrPath)) { $null } else { [System.IO.Path]::GetFullPath($StdErrPath) }
        }
    }
} else {
    $warnings = @(Get-WarningLines -Text $stdOutText)
    $errors = @()
    $errors += @(Get-ErrorLines -Text $stdOutText)
    $errors += @(Get-ErrorLines -Text $stdErrText)
    $expectedItemsRaw = @(Split-ItemFilter -FilterText $ExpectedItems)
    $importedItems = @(Get-MatchingLines -Text $stdOutText -Prefix '__IMPORTED_ITEM__=')
    $expectedItemsCanonical = @($expectedItemsRaw | ForEach-Object { ConvertTo-CanonicalGeneXusItem -Item $_ })
    $importedItemsCanonical = @($importedItems | ForEach-Object { ConvertTo-CanonicalGeneXusItem -Item $_ })
    $itemAliasMatches = @(Get-GeneXusItemAliasMatches -ExpectedRaw $expectedItemsRaw -ImportedRaw $importedItems)
    $layoutWarnings = @(Get-LayoutWarnings -Warnings $warnings)
    $knownStdOutNoise = @(Get-KnownStdOutNoise -Text $stdOutText)
    $gxImportLogReadSignal = Get-GxImportLogReadSignal -Texts @($stdOutText, $stdErrText)

    $signals = [ordered]@{
        status = 'signals-read'
        stage = $Stage
        expectedItemsRaw = $expectedItemsRaw
        expectedItemsCanonical = $expectedItemsCanonical
        importedItems = $importedItems
        importedItemsRaw = $importedItems
        importedItemsCanonical = $importedItemsCanonical
        itemAliasMatches = $itemAliasMatches
        warnings = $warnings
        errors = $errors
        knownStdOutNoise = $knownStdOutNoise
        gxImportLogReadStatus = $gxImportLogReadSignal.status
        gxImportLogReadError = $gxImportLogReadSignal.error
        diagnosticDegraded = $gxImportLogReadSignal.diagnosticDegraded
        activeVersion = $activeContextFields.activeVersion
        activeEnvironment = $activeContextFields.activeEnvironment
        activeVersionAtOpen = $activeContextFields.activeVersionAtOpen
        activeEnvironmentAtOpen = $activeContextFields.activeEnvironmentAtOpen
        contextQuality = $activeContextFields.contextQuality
        importTaskSuccess = ($stdOutText -match 'Import Task (Sucesso|Success)')
        layoutWarnings = $layoutWarnings
        counts = [ordered]@{
            importedItems = $importedItems.Count
            itemAliasMatches = $itemAliasMatches.Count
            warnings = $warnings.Count
            errors = $errors.Count
            knownStdOutNoise = $knownStdOutNoise.Count
            layoutWarnings = $layoutWarnings.Count
        }
        artifacts = [ordered]@{
            StdOutPath = if ([string]::IsNullOrWhiteSpace($StdOutPath)) { $null } else { [System.IO.Path]::GetFullPath($StdOutPath) }
            StdErrPath = if ([string]::IsNullOrWhiteSpace($StdErrPath)) { $null } else { [System.IO.Path]::GetFullPath($StdErrPath) }
        }
    }
}

$json = $signals | ConvertTo-Json -Depth 8
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($resolvedOutputPath)
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    }
    [System.IO.File]::WriteAllText($resolvedOutputPath, $json + [Environment]::NewLine, (Get-Utf8NoBomEncoding))
}

if ($AsJson) {
    $json
} else {
    $signals
}
