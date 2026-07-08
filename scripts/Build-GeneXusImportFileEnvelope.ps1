#requires -Version 7.4

<#
.SYNOPSIS
    Monta um import_file.xml a partir de XMLs de objeto e um pacote template.

.DESCRIPTION
    Monta o envelope de importação a partir de XMLs declarados e de um template
    comparavel. Executa o gate canonico de envelope por padrão; para Panel, usa
    TemplatePackagePath como referencia comparavel e propaga no resultado
    information para panel-level-layout-confirmed, ou warnings quando o par
    level/layout não puder ser confirmado.

.PARAMETER TemplatePackagePath
    Pacote XML ou XPZ comparavel usado como template do envelope e, para Panel,
    como referencia do par level id/layout id no gate final.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ObjectXmlPaths,

    [Parameter(Mandatory = $true)]
    [string]$TemplatePackagePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string[]]$TopLevelAttributesXmlPaths,

    [Parameter(Mandatory = $true)]
    [string]$AcervoPath,

    [string[]]$ModifiedObjectNames,

    [string[]]$ModifiedObjectGuids,

    [ValidateRange(1, 3600)]
    [int]$FreshnessMarginSeconds = 60,

    [ValidateRange(0, 3600)]
    [int]$FutureToleranceSeconds = 120,

    [ValidateSet("pass", "warn", "block")]
    [string]$NewObjectPolicy = "warn",

    [switch]$SkipGate,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-BuildEnvelopeJsonAndExit {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][int]$ExitCode
    )

    $InputObject | ConvertTo-Json -Depth 10
    exit $ExitCode
}

trap {
    $message = $_.Exception.Message
    try {
        $structured = $message | ConvertFrom-Json
        if ($null -eq $structured.PSObject.Properties['exitCode']) {
            $structured | Add-Member -NotePropertyName exitCode -NotePropertyValue 20 -Force
        }
        Write-BuildEnvelopeJsonAndExit -InputObject $structured -ExitCode ([int]$structured.exitCode)
    } catch {
        $exitCode = if ($message.StartsWith('BLOCK:')) { 20 } else { 90 }
        $status = if ($exitCode -eq 20) { 'bloqueado' } else { 'erro' }
        Write-BuildEnvelopeJsonAndExit -InputObject ([ordered]@{
            status = $status
            exitCode = $exitCode
            stage = 'build-envelope'
            blockingReasons = @($message)
            warnings = @()
        }) -ExitCode $exitCode
    }
}

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$objectTypeDriftSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusObjectTypeDriftSupport.ps1'
if (-not (Test-Path -LiteralPath $objectTypeDriftSupportPath -PathType Leaf)) {
    throw "Object type drift support script not found: $objectTypeDriftSupportPath"
}
. $objectTypeDriftSupportPath

function Resolve-NextRejectedPath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath
    )
    $letters = [char[]](65..90)
    foreach ($letter in $letters) {
        $candidate = "$BasePath.rejected.$letter"
        if (-not (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }
    throw "Limite de rejeicoes atingido: '$BasePath.rejected.A'..'.Z' ja existem. Limpar rejeicoes anteriores antes de tentar novamente."
}

function Assert-XmlWellFormed {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Role
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Role nao encontrado: $Path"
    }
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
        $doc.LoadXml($raw)
    } catch {
        throw "$Role nao e XML bem-formado ('$Path'): $($_.Exception.Message)"
    }
    return $doc
}

function Assert-NotReferenceLikePackageInput {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Role
    )

    $leafName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    if ($leafName -match '(^|[-_.\s])(referencia|referência|reference|exemplo|example|template|molde)([-_.\s]|$)') {
        throw "BLOCK: $Role nao pode ser XML de referencia/exemplo/template/molde: $Path"
    }
}

function Format-GeneXusLastUpdate {
    param([Parameter(Mandatory = $true)][DateTime]$Value)

    return $Value.ToUniversalTime().ToString(
        "yyyy-MM-dd'T'HH:mm:ss'.0000000Z'",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Read-ObjectLastUpdate {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Root,
        [Parameter(Mandatory = $true)][string]$SourceLabel
    )

    $raw = $Root.GetAttribute("lastUpdate")
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "$SourceLabel sem Object/@lastUpdate."
    }

    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $raw,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed
    )
    if (-not $ok) {
        throw "$SourceLabel com Object/@lastUpdate invalido: '$raw'."
    }

    return $parsed.UtcDateTime
}

function Test-ObjectIdentityMatch {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Candidate,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Baseline
    )

    $candidateGuid = $Candidate.GetAttribute("guid")
    $baselineGuid = $Baseline.GetAttribute("guid")
    if (-not [string]::IsNullOrWhiteSpace($candidateGuid) -and $candidateGuid -eq $baselineGuid) {
        return $true
    }

    $candidateFqn = $Candidate.GetAttribute("fullyQualifiedName")
    $baselineFqn = $Baseline.GetAttribute("fullyQualifiedName")
    if (-not [string]::IsNullOrWhiteSpace($candidateFqn) -and $candidateFqn -eq $baselineFqn) {
        return $true
    }

    $candidateName = $Candidate.GetAttribute("name")
    $baselineName = $Baseline.GetAttribute("name")
    if (-not [string]::IsNullOrWhiteSpace($candidateName) -and $candidateName -eq $baselineName) {
        return $true
    }

    return $false
}

function Test-FrontObjectTypeDrift {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlDocument[]]$Docs,
        [Parameter(Mandatory = $true)][string]$BaselineRootPath,
        [Parameter(Mandatory = $true)]$GuidIndex
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $blockingReasons = [System.Collections.Generic.List[string]]::new()
    $blockingDetails = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($doc in $Docs) {
        $root = $doc.DocumentElement
        if ($null -eq $root -or $root.LocalName -ne 'Object') {
            continue
        }

        $name = $root.GetAttribute('name')
        $fqn = $root.GetAttribute('fullyQualifiedName')
        $guid = $root.GetAttribute('guid')
        $label = if (-not [string]::IsNullOrWhiteSpace($fqn)) { $fqn } elseif (-not [string]::IsNullOrWhiteSpace($name)) { $name } else { $guid }
        $frontGuidNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $guid
        if ([string]::IsNullOrWhiteSpace($frontGuidNormalized)) {
            $checks.Add([pscustomobject]@{
                objectName = $name
                fullyQualifiedName = $fqn
                guid = $guid
                status = 'not-applicable'
                code = 'front-guid-missing'
                matchBasis = ''
            }) | Out-Null
            continue
        }

        $candidatePaths = @(Get-GeneXusObjectTypeGuidIndexMatches -Index $GuidIndex -Guid $guid)
        $candidateRelativePaths = @($candidatePaths | ForEach-Object { [System.IO.Path]::GetRelativePath($BaselineRootPath, $_) })
        if ($candidatePaths.Count -eq 0) {
            $checks.Add([pscustomobject]@{
                objectName = $name
                fullyQualifiedName = $fqn
                guid = $guid
                status = 'pass'
                code = 'baseline-guid-missing'
                matchBasis = ''
            }) | Out-Null
            continue
        }

        if ($candidatePaths.Count -gt 1) {
            $checks.Add([pscustomobject]@{
                objectName = $name
                fullyQualifiedName = $fqn
                guid = $guid
                status = 'info'
                code = 'front-object-type-drift-ambiguous-baseline'
                matchBasis = 'guid-ambiguous'
                candidateBaselinePaths = $candidateRelativePaths
            }) | Out-Null
            continue
        }

        try {
            $baselineDoc = Assert-XmlWellFormed -Path $candidatePaths[0] -Role "BaselineObjectXml"
        } catch {
            $warnings.Add("front-object-type-baseline-unreadable: '$label' baseline '$($candidatePaths[0])' nao pode ser lida.") | Out-Null
            continue
        }

        $baselineRoot = $baselineDoc.DocumentElement
        if ($null -eq $baselineRoot -or $baselineRoot.LocalName -ne 'Object') {
            continue
        }

        $baselineGuidNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $baselineRoot.GetAttribute('guid')
        if ($frontGuidNormalized -ne $baselineGuidNormalized) {
            continue
        }

        $frontType = $root.GetAttribute('type')
        $baselineType = $baselineRoot.GetAttribute('type')
        $frontTypeNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $frontType
        $baselineTypeNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $baselineType
        $status = 'pass'
        $code = 'object-type-match'

        if (
            -not [string]::IsNullOrWhiteSpace($frontTypeNormalized) -and
            -not [string]::IsNullOrWhiteSpace($baselineTypeNormalized) -and
            $frontTypeNormalized -ne $baselineTypeNormalized
        ) {
            $status = 'fail'
            $code = 'front-object-type-drift'
            if (-not $blockingReasons.Contains('front-object-type-drift')) {
                $blockingReasons.Add('front-object-type-drift') | Out-Null
            }
            $detail = [ordered]@{
                code = 'front-object-type-drift'
                objectName = $name
                fullyQualifiedName = $fqn
                frontGuid = $guid
                frontObjectType = $frontType
                baselineObjectType = $baselineType
                frontObjectTypeNormalized = $frontTypeNormalized
                baselineObjectTypeNormalized = $baselineTypeNormalized
                matchBasis = 'guid'
                baselinePath = $candidateRelativePaths[0]
            }
            $blockingDetails.Add([pscustomobject]$detail) | Out-Null
        }

        $checks.Add([pscustomobject]@{
            objectName = $name
            fullyQualifiedName = $fqn
            guid = $guid
            status = $status
            code = $code
            frontObjectType = $frontType
            baselineObjectType = $baselineType
            frontObjectTypeNormalized = $frontTypeNormalized
            baselineObjectTypeNormalized = $baselineTypeNormalized
            matchBasis = 'guid'
            baselinePath = $candidateRelativePaths[0]
        }) | Out-Null
    }

    return [pscustomobject]@{
        checks = $checks.ToArray()
        blockingReasons = $blockingReasons.ToArray()
        blockingDetails = $blockingDetails.ToArray()
        warnings = $warnings.ToArray()
    }
}

function Find-BaselineObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$CandidateRoot
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        throw "AcervoPath nao encontrado ou nao e pasta: $RootPath"
    }

    $candidateNames = [System.Collections.Generic.List[string]]::new()
    foreach ($attrName in @("fullyQualifiedName", "name")) {
        $value = $CandidateRoot.GetAttribute($attrName)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $candidateNames.Add($value) | Out-Null
        }
    }

    $candidateFiles = @()
    foreach ($candidateName in @($candidateNames | Select-Object -Unique)) {
        $leaf = "$candidateName.xml"
        $candidateFiles += @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue)
    }

    if ($candidateFiles.Count -eq 0) {
        $guid = $CandidateRoot.GetAttribute("guid")
        if (-not [string]::IsNullOrWhiteSpace($guid)) {
            $candidateFiles += @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter "*.xml" -ErrorAction SilentlyContinue | Select-String -SimpleMatch $guid | ForEach-Object { $_.Path } | Sort-Object -Unique | ForEach-Object { Get-Item -LiteralPath $_ })
        }
    }

    foreach ($file in @($candidateFiles | Sort-Object FullName -Unique)) {
        try {
            $doc = Assert-XmlWellFormed -Path $file.FullName -Role "BaselineObjectXml"
        } catch {
            continue
        }
        if ($doc.DocumentElement.LocalName -eq "Object" -and (Test-ObjectIdentityMatch -Candidate $CandidateRoot -Baseline $doc.DocumentElement)) {
            return $doc
        }
    }

    return $null
}

function Test-LastUpdateFreshness {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlDocument[]]$Docs,
        [Parameter(Mandatory = $true)][string]$BaselineRootPath
    )

    $checks = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $blockingReasons = [System.Collections.Generic.List[string]]::new()
    $nowUtc = [DateTime]::UtcNow
    $maxFuture = $nowUtc.AddSeconds($FutureToleranceSeconds)
    $modifiedNamesSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $modifiedGuidsSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($name in @($ModifiedObjectNames)) {
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            [void]$modifiedNamesSet.Add($name)
        }
    }
    foreach ($guid in @($ModifiedObjectGuids)) {
        if (-not [string]::IsNullOrWhiteSpace($guid)) {
            [void]$modifiedGuidsSet.Add($guid)
        }
    }

    foreach ($doc in $Docs) {
        $root = $doc.DocumentElement
        $name = $root.GetAttribute("name")
        $fqn = $root.GetAttribute("fullyQualifiedName")
        $guid = $root.GetAttribute("guid")
        $label = if (-not [string]::IsNullOrWhiteSpace($fqn)) { $fqn } elseif (-not [string]::IsNullOrWhiteSpace($name)) { $name } else { $guid }
        $candidateLastUpdate = Read-ObjectLastUpdate -Root $root -SourceLabel "ObjectXml '$label'"
        $isDeclaredModified = $modifiedNamesSet.Contains($name) -or $modifiedNamesSet.Contains($fqn) -or $modifiedGuidsSet.Contains($guid)
        $baselineDoc = Find-BaselineObjectXml -RootPath $BaselineRootPath -CandidateRoot $root

        if ($null -eq $baselineDoc) {
            $message = "last-update-baseline-missing: '$label' nao foi encontrado em AcervoPath; NewObjectPolicy=$NewObjectPolicy."
            $statusCode = "baseline-missing"
            if ($NewObjectPolicy -eq "block") {
                $blockingReasons.Add($message) | Out-Null
                $status = "fail"
            } elseif ($NewObjectPolicy -eq "warn") {
                $warnings.Add($message) | Out-Null
                $status = "warn"
            } else {
                $status = "pass"
            }
            if ($candidateLastUpdate -gt $maxFuture) {
                $status = "fail"
                $statusCode = "baseline-missing-too-far-in-future"
                $blockingReasons.Add("last-update-too-far-in-future: '$label' sem baseline oficial tem lastUpdate $(Format-GeneXusLastUpdate -Value $candidateLastUpdate), maior que UtcNow + $FutureToleranceSeconds segundos.") | Out-Null
            }
            $checks.Add([pscustomobject]@{
                objectName       = $name
                fullyQualifiedName = $fqn
                guid             = $guid
                role             = if ($isDeclaredModified) { "declared-modified" } else { "unclassified-or-new" }
                candidateLastUpdate = Format-GeneXusLastUpdate -Value $candidateLastUpdate
                baselineLastUpdate  = $null
                status           = $status
                code             = $statusCode
            }) | Out-Null
            continue
        }

        $baselineLastUpdate = Read-ObjectLastUpdate -Root $baselineDoc.DocumentElement -SourceLabel "BaselineObjectXml '$label'"
        $minimumFreshLastUpdate = $baselineLastUpdate.AddSeconds($FreshnessMarginSeconds)
        $maxAllowedFuture = $maxFuture
        if ($minimumFreshLastUpdate -gt $maxAllowedFuture) {
            $maxAllowedFuture = $minimumFreshLastUpdate
        }
        $statusCode = "pass"
        $status = "pass"

        if ($candidateLastUpdate -lt $baselineLastUpdate) {
            $status = "fail"
            $statusCode = "older-than-baseline"
            $blockingReasons.Add("last-update-older-than-baseline: '$label' tem lastUpdate $(Format-GeneXusLastUpdate -Value $candidateLastUpdate), anterior ao acervo $(Format-GeneXusLastUpdate -Value $baselineLastUpdate).") | Out-Null
        } elseif ($candidateLastUpdate -eq $baselineLastUpdate) {
            if ($isDeclaredModified) {
                $status = "fail"
                $statusCode = "declared-modified-equals-baseline"
                $blockingReasons.Add("last-update-not-fresh: '$label' foi declarado como modificado, mas preserva lastUpdate igual ao acervo $(Format-GeneXusLastUpdate -Value $baselineLastUpdate).") | Out-Null
            } else {
                $status = "warn"
                $statusCode = "equals-baseline-presumed-preserved"
                $warnings.Add("last-update-preserved: '$label' preserva lastUpdate igual ao acervo; aceito apenas se for dependencia/objeto reenviado sem mudanca.") | Out-Null
            }
        } elseif ($isDeclaredModified -and $candidateLastUpdate -lt $minimumFreshLastUpdate) {
            $status = "fail"
            $statusCode = "declared-modified-below-freshness-margin"
            $blockingReasons.Add("last-update-margin-too-small: '$label' foi declarado como modificado, mas lastUpdate $(Format-GeneXusLastUpdate -Value $candidateLastUpdate) e menor que acervo + $FreshnessMarginSeconds segundos ($(Format-GeneXusLastUpdate -Value $minimumFreshLastUpdate)).") | Out-Null
        } elseif ((-not $isDeclaredModified) -and $candidateLastUpdate -gt $baselineLastUpdate -and $candidateLastUpdate -lt $minimumFreshLastUpdate) {
            $status = "warn"
            $statusCode = "freshness-margin-small-unclassified"
            $warnings.Add("last-update-margin-small: '$label' esta acima do acervo, mas abaixo de acervo + $FreshnessMarginSeconds segundos; se for objeto alterado, recalcular lastUpdate.") | Out-Null
        } elseif ($candidateLastUpdate -gt $maxAllowedFuture) {
            $status = "fail"
            $statusCode = "too-far-in-future"
            $blockingReasons.Add("last-update-too-far-in-future: '$label' tem lastUpdate $(Format-GeneXusLastUpdate -Value $candidateLastUpdate), maior que UtcNow + $FutureToleranceSeconds segundos e sem justificativa pelo acervo + margem.") | Out-Null
        }

        $checks.Add([pscustomobject]@{
            objectName       = $name
            fullyQualifiedName = $fqn
            guid             = $guid
            role             = if ($isDeclaredModified) { "declared-modified" } else { "unclassified-or-preserved" }
            candidateLastUpdate = Format-GeneXusLastUpdate -Value $candidateLastUpdate
            baselineLastUpdate  = Format-GeneXusLastUpdate -Value $baselineLastUpdate
            freshnessMarginSeconds = $FreshnessMarginSeconds
            futureToleranceSeconds = $FutureToleranceSeconds
            status           = $status
            code             = $statusCode
        }) | Out-Null
    }

    return [pscustomobject]@{
        checks          = $checks.ToArray()
        warnings        = $warnings.ToArray()
        blockingReasons = $blockingReasons.ToArray()
    }
}

function Read-TemplatePackage {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "TemplatePackage nao encontrado: $Path"
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -ne ".xpz" -and $extension -ne ".zip") {
        return (Assert-XmlWellFormed -Path $Path -Role "TemplatePackage")
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Path).Path)
    try {
        foreach ($entry in @($zip.Entries | Where-Object { $_.FullName -match '\.xml$' } | Sort-Object FullName)) {
            $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8, $true)
            try {
                $text = $reader.ReadToEnd()
            } finally {
                $reader.Dispose()
            }
            $doc = New-Object System.Xml.XmlDocument
            $doc.PreserveWhitespace = $true
            try {
                $doc.LoadXml($text)
            } catch {
                continue
            }
            if ($doc.DocumentElement.LocalName -eq "ExportFile") {
                return $doc
            }
        }
    } finally {
        $zip.Dispose()
    }

    throw "TemplatePackage XPZ nao contem XML com raiz 'ExportFile': $Path"
}

# 1 - validação de entradas
if (-not $ObjectXmlPaths -or $ObjectXmlPaths.Count -eq 0) {
    throw "ObjectXmlPaths vazio: nenhum XML de objeto informado."
}

# 1a - gate de colisao de pacote (antes de qualquer escrita)
# Garante reserva determinista do _nn: se houver colisao, o script aborta sem
# materializar nada. Bypass intencional via -Force, alinhado a semantica já
# existente de sobrescrita explicita.
if (-not $Force) {
    $collisionScript = Join-Path $PSScriptRoot "Test-XpzPackageCollision.ps1"
    if (-not (Test-Path -LiteralPath $collisionScript)) {
        throw "Gate de colisao nao encontrado em '$collisionScript'."
    }
    $absOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $leafName = Split-Path -Leaf $absOutputPath
    $nameMatch = [regex]::Match(
        $leafName,
        '^(?<front>.+)_(?<nn>\d+)\.import_file\.xml$',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $nameMatch.Success) {
        throw "BLOCK: nome de OutputPath fora do padrao '<FrontPrefix>_<nn>.import_file.xml': $leafName"
    }
    $collisionFront = $nameMatch.Groups['front'].Value
    $collisionNN    = $nameMatch.Groups['nn'].Value
    $collisionDir   = Split-Path -Parent $absOutputPath
    if (-not (Test-Path -LiteralPath $collisionDir -PathType Container)) {
        New-Item -ItemType Directory -Path $collisionDir -Force | Out-Null
    }
    $collisionOutput = & pwsh -NoProfile -File $collisionScript -FrontPrefix $collisionFront -NN $collisionNN -OutputDir $collisionDir
    $collisionExitCode = $LASTEXITCODE
    $collisionJson = ($collisionOutput | Out-String).Trim()
    try {
        $collisionResult = $collisionJson | ConvertFrom-Json
    } catch {
        throw "BLOCK: gate de colisao retornou saida nao JSON: $collisionJson"
    }
    if ($collisionExitCode -ne 0 -or $collisionResult.status -ne 'ok') {
        throw $collisionJson
    }
}

if (Test-Path -LiteralPath $OutputPath) {
    if (-not $Force) {
        throw "OutputPath ja existe: '$OutputPath'. Use -Force para sobrescrever."
    }
    Remove-Item -LiteralPath $OutputPath -Force
}

$templateDoc = Read-TemplatePackage -Path $TemplatePackagePath
if ($templateDoc.DocumentElement.LocalName -ne "ExportFile") {
    throw "TemplatePackage nao tem raiz 'ExportFile': raiz encontrada '$($templateDoc.DocumentElement.LocalName)'."
}

$templateRoot = $templateDoc.DocumentElement
$templateBlocks = @{}
foreach ($name in @("KMW", "Source", "Attributes", "Dependencies", "ObjectsIdentityMapping")) {
    $node = $templateRoot.SelectSingleNode("./$name")
    if ($null -ne $node) {
        $templateBlocks[$name] = $node
    }
}
foreach ($required in @("KMW", "Source")) {
    if (-not $templateBlocks.ContainsKey($required)) {
        throw "TemplatePackage nao contem bloco obrigatorio '<$required>'."
    }
}

# 2 - validação previa dos XMLs de objeto (cada um deve carregar isoladamente)
$objectDocs = @()
foreach ($path in $ObjectXmlPaths) {
    Assert-NotReferenceLikePackageInput -Path $path -Role "ObjectXml"
    $objectDocs += (Assert-XmlWellFormed -Path $path -Role "ObjectXml")
}

$objectTypeGuidIndex = New-GeneXusObjectTypeGuidIndex -RootPath $AcervoPath
$lastUpdateFreshness = Test-LastUpdateFreshness -Docs $objectDocs -BaselineRootPath $AcervoPath
$frontObjectTypeDrift = Test-FrontObjectTypeDrift -Docs $objectDocs -BaselineRootPath $AcervoPath -GuidIndex $objectTypeGuidIndex
$preWriteBlockingReasons = @(@($lastUpdateFreshness.blockingReasons) + @($frontObjectTypeDrift.blockingReasons))
if ($preWriteBlockingReasons.Count -gt 0) {
    Write-BuildEnvelopeJsonAndExit -InputObject ([ordered]@{
        status = 'bloqueado'
        exitCode = 20
        stage = 'front-acervo-coherence'
        blockingReasons = $preWriteBlockingReasons
        blockingDetails = @($frontObjectTypeDrift.blockingDetails)
        lastUpdateFreshness = $lastUpdateFreshness
        frontObjectTypeDrift = $frontObjectTypeDrift
        warnings = @(@($lastUpdateFreshness.warnings) + @($frontObjectTypeDrift.warnings))
    }) -ExitCode 20
}

$attributeDocs = @()
if ($TopLevelAttributesXmlPaths -and $TopLevelAttributesXmlPaths.Count -gt 0) {
    foreach ($path in $TopLevelAttributesXmlPaths) {
        Assert-NotReferenceLikePackageInput -Path $path -Role "TopLevelAttributeXml"
        $attributeDocs += (Assert-XmlWellFormed -Path $path -Role "TopLevelAttributeXml")
    }
}

# 3 - montagem do novo documento
$outDoc = New-Object System.Xml.XmlDocument
$outDoc.PreserveWhitespace = $false

$xmlDecl = $outDoc.CreateXmlDeclaration("1.0", "UTF-8", $null)
[void]$outDoc.AppendChild($xmlDecl)

$newRoot = $outDoc.CreateElement("ExportFile")
foreach ($attr in $templateRoot.Attributes) {
    $copiedAttr = $outDoc.CreateAttribute($attr.Name)
    $copiedAttr.Value = $attr.Value
    [void]$newRoot.Attributes.Append($copiedAttr)
}
[void]$outDoc.AppendChild($newRoot)

# 3a - KMW e Source clonados do template
foreach ($name in @("KMW", "Source")) {
    $imported = $outDoc.ImportNode($templateBlocks[$name], $true)
    [void]$newRoot.AppendChild($imported)
}

# 3b - <Objects> com cada objeto via ImportNode(DocumentElement) — sem prologo interno
$objectsElement = $outDoc.CreateElement("Objects")
[void]$newRoot.AppendChild($objectsElement)
foreach ($doc in $objectDocs) {
    $imported = $outDoc.ImportNode($doc.DocumentElement, $true)
    [void]$objectsElement.AppendChild($imported)
}

# 3c - <Attributes> top-level: explicito vence; senao, clonar do template quando existir
$topLevelAttrSource = "none"
if ($attributeDocs.Count -gt 0) {
    $attributesElement = $outDoc.CreateElement("Attributes")
    [void]$newRoot.AppendChild($attributesElement)
    foreach ($doc in $attributeDocs) {
        $imported = $outDoc.ImportNode($doc.DocumentElement, $true)
        [void]$attributesElement.AppendChild($imported)
    }
    $topLevelAttrSource = "explicit"
} elseif ($templateBlocks.ContainsKey("Attributes")) {
    $imported = $outDoc.ImportNode($templateBlocks["Attributes"], $true)
    [void]$newRoot.AppendChild($imported)
    $topLevelAttrSource = "template"
}

# 3d - Dependencies clonado (ou vazio se template não tiver)
if ($templateBlocks.ContainsKey("Dependencies")) {
    $imported = $outDoc.ImportNode($templateBlocks["Dependencies"], $true)
    [void]$newRoot.AppendChild($imported)
} else {
    $depElement = $outDoc.CreateElement("Dependencies")
    [void]$newRoot.AppendChild($depElement)
}

# 3e - ObjectsIdentityMapping clonado (warn-only quando template não tem)
if ($templateBlocks.ContainsKey("ObjectsIdentityMapping")) {
    $imported = $outDoc.ImportNode($templateBlocks["ObjectsIdentityMapping"], $true)
    [void]$newRoot.AppendChild($imported)
}

# 4 - serializacao para arquivo
$outputDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrEmpty($outputDir) -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$writerSettings = New-Object System.Xml.XmlWriterSettings
$writerSettings.Encoding = (Get-Utf8NoBomEncoding)
$writerSettings.Indent = $true
$writerSettings.IndentChars = "  "
$writerSettings.OmitXmlDeclaration = $false
$writerSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace

$writer = [System.Xml.XmlWriter]::Create($OutputPath, $writerSettings)
try {
    $outDoc.Save($writer)
} finally {
    $writer.Close()
}

$buildResult = [ordered]@{
    outputPath        = (Resolve-Path -LiteralPath $OutputPath).Path
    templatePackage   = (Resolve-Path -LiteralPath $TemplatePackagePath).Path
    objectCount       = $objectDocs.Count
    topLevelAttrCount = $attributeDocs.Count
    topLevelAttrSource = $topLevelAttrSource
    lastUpdateFreshness = $lastUpdateFreshness
    frontObjectTypeDrift = $frontObjectTypeDrift
    gateStatus        = $null
    gateInvoked       = (-not $SkipGate.IsPresent)
    blockingReasons   = @()
    warnings          = @(
        @($lastUpdateFreshness.warnings)
    )
    information       = @()
    rejectedPath      = $null
    status            = "apto para prosseguir"
}

# 5 - gate final (default)
if (-not $SkipGate) {
    $gateScript = Join-Path $PSScriptRoot "Test-GeneXusImportFileEnvelope.ps1"
    if (-not (Test-Path -LiteralPath $gateScript)) {
        throw "Gate nao encontrado em '$gateScript'. Use -SkipGate apenas se souber o que esta fazendo."
    }
    $gateResult = & $gateScript -InputPath $OutputPath -PanelReferencePath $TemplatePackagePath | ConvertFrom-Json
    $buildResult.gateStatus      = $gateResult.status
    $buildResult.blockingReasons = @($gateResult.blockingReasons)
    $buildResult.warnings        = @($buildResult.warnings + $gateResult.warnings | Sort-Object -Unique)
    $buildResult.information     = @($gateResult.information)
    $buildResult.status          = $gateResult.status

    if ($gateResult.status -eq "não apto para prosseguir") {
        $rejected = Resolve-NextRejectedPath -BasePath $OutputPath
        Move-Item -LiteralPath $OutputPath -Destination $rejected -Force
        $buildResult.rejectedPath = $rejected
        $buildResult.outputPath   = $null
    }
}

if (-not [string]::IsNullOrWhiteSpace([string]$buildResult.outputPath)) {
    . (Join-Path $PSScriptRoot 'GeneXusPackageInventorySupport.ps1')
    $declaredDelta = ConvertTo-DeclaredDeltaItemsFromObjectDocuments `
        -ObjectDocuments $objectDocs `
        -ModifiedObjectNames $ModifiedObjectNames `
        -ModifiedObjectGuids $ModifiedObjectGuids
    $sidecarInventoryPath = Join-Path (Split-Path -Parent $buildResult.outputPath) (
        ([System.IO.Path]::GetFileName($buildResult.outputPath)) + '.package-inventory.json'
    )
    $inventoryBlock = New-PackageInventoryResult `
        -InputPath $buildResult.outputPath `
        -DeclaredDeltaItems $declaredDelta `
        -SidecarInventoryPath $sidecarInventoryPath
    $buildResult.packageInventory = $inventoryBlock.packageInventory
    $buildResult.inventoryDegraded = $inventoryBlock.inventoryDegraded
    $buildResult.inventoryError = $inventoryBlock.inventoryError
}

$buildResult | ConvertTo-Json -Depth 6
