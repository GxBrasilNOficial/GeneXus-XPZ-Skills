#requires -Version 7.4

<#
.SYNOPSIS
    Compara XMLs Object e Attribute da frente contra o acervo e emite findings de drift.

.DESCRIPTION
    Para cada <Object> na pasta da frente, busca o XML correspondente no acervo
    (ObjetosDaKbEmXml) por GUID ou por nome, e compara lastUpdate, Object/@type e
    fidelidade textual parcial. XMLs Object ausentes no acervo são presumidos novos.
    O gate não enumera objetos do acervo ausentes da frente, porque a frente é o
    escopo operacional do empacotamento.

    Para cada <Attribute> top-level na frente, compara por GUID a assinatura
    funcional contra XMLs Attribute do acervo: ATTCUSTOMTYPE, idBasedOn, Length,
    Decimals, AttMaxLen, AttAvgLen, AttCollection, Signed e idDATEFORMAT. Drift,
    identidade sem GUID, GUID duplicado no acervo ou propriedade de assinatura
    duplicada bloqueiam. Mudança de tipo e redução de Length/AttMaxLen sempre
    bloqueiam. Aumento desses campos só passa com -ApprovedAttributeSizeGrowth,
    vinculado a GUID, campo e valores exatos, após solicitação explícita do
    usuário na sessão. Attribute sem GUID correspondente no acervo é tratado
    como novo e não tem baseline comparável.

    Código de severidade por finding:
      info    — sem bloqueio (frente mais nova, objeto/Attribute novo no acervo)
      warn    — revisão obrigatória (lastUpdate igual ao acervo ou não parseável)
      fail    — bloqueio por lastUpdate antigo, Object/@type divergente, assinatura
                 de Attribute divergente/inválida/ambígua ou remoção forte de
                 trailing whitespace herdado
.PARAMETER FrontFolder
    Caminho da pasta da frente (ObjetosGeradosParaImportacaoNaKbNoGenexus/<NomeCurto_GUID_YYYYMMDD>).

.PARAMETER AcervoFolder
    Caminho da pasta do acervo oficial (ObjetosDaKbEmXml).

.PARAMETER ApprovedAttributeSizeGrowth
    Exceção pontual para aumento numérico de Length ou AttMaxLen, no formato
    '<GUID>|<campo>|<valor-no-acervo>|<valor-na-frente>'. Só informar após
    solicitação explícita do usuário para essa mudança exata. Pode ser repetido.

.PARAMETER AsJson
    Emite resultado estruturado em JSON.

.EXAMPLE
    .\Test-GeneXusFrontAcervoDrift.ps1 -FrontFolder C:\Kb\ObjetosGeradosParaImportacaoNaKbNoGenexus\GtaP3_c34f_20260528 -AcervoFolder C:\Kb\ObjetosDaKbEmXml -AsJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Folder')]
    [string]$FrontFolder,

    [Parameter(Mandatory = $true, ParameterSetName = 'Explicit')]
    [string[]]$ObjectXmlPaths,

    [Parameter(Mandatory = $true)]
    [string]$AcervoFolder,

    [string[]]$ApprovedAttributeSizeGrowth = @(),

    [string]$ApprovedDomainChangesPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$objectTypeDriftSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusObjectTypeDriftSupport.ps1'
if (-not (Test-Path -LiteralPath $objectTypeDriftSupportPath -PathType Leaf)) {
    throw "Object type drift support script not found: $objectTypeDriftSupportPath"
}
. $objectTypeDriftSupportPath

function Format-GeneXusLastUpdate {
    param([Parameter(Mandatory = $true)][DateTime]$Value)
    return $Value.ToUniversalTime().ToString(
        "yyyy-MM-dd'T'HH:mm:ss'.0000000Z'",
        [System.Globalization.CultureInfo]::InvariantCulture
    )
}

function Read-ObjectLastUpdateSafe {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Root
    )
    $raw = $Root.GetAttribute("lastUpdate")
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $raw,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed
    )
    if (-not $ok) {
        return $null
    }
    return $parsed.UtcDateTime
}

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$ObjectName,
        [string]$ObjectGuid,
        [string]$ObjectFile,
        [string]$AcervoFile,
        [string]$AcervoPath,
        [string]$FrontLastUpdate,
        [string]$AcervoLastUpdate,
        [string]$FrontObjectType,
        [string]$AcervoObjectType,
        [string]$FrontObjectTypeNormalized,
        [string]$AcervoObjectTypeNormalized,
        [string]$MatchBasis,
        [string[]]$CandidateAcervoPaths,
        [hashtable]$ExtraFields
    )
    $protectedKeys = @(
        'code',
        'severity',
        'objectName',
        'objectGuid',
        'objectFile',
        'message',
        'acervoFile',
        'acervoPath',
        'candidateAcervoPaths',
        'frontObjectType',
        'acervoObjectType',
        'frontObjectTypeNormalized',
        'acervoObjectTypeNormalized',
        'frontLastUpdate',
        'acervoLastUpdate',
        'matchBasis'
    )
    $finding = [ordered]@{
        severity         = $Severity
        code             = $Code
        message          = $Message
        objectName       = $ObjectName
        objectGuid       = $ObjectGuid
        objectFile       = $ObjectFile
        frontLastUpdate  = $FrontLastUpdate
        acervoLastUpdate = $AcervoLastUpdate
    }
    if ($Code -notin @('front-object-type-drift', 'front-object-type-drift-ambiguous-acervo')) {
        $finding.acervoFile = $AcervoFile
    }
    if (-not [string]::IsNullOrWhiteSpace($FrontObjectType)) {
        $finding.frontObjectType = $FrontObjectType
    }
    if (-not [string]::IsNullOrWhiteSpace($AcervoObjectType)) {
        $finding.acervoObjectType = $AcervoObjectType
    }
    if (-not [string]::IsNullOrWhiteSpace($FrontObjectTypeNormalized)) {
        $finding.frontObjectTypeNormalized = $FrontObjectTypeNormalized
    }
    if (-not [string]::IsNullOrWhiteSpace($AcervoObjectTypeNormalized)) {
        $finding.acervoObjectTypeNormalized = $AcervoObjectTypeNormalized
    }
    if (-not [string]::IsNullOrWhiteSpace($MatchBasis)) {
        $finding.matchBasis = $MatchBasis
    }
    if (-not [string]::IsNullOrWhiteSpace($AcervoPath)) {
        $finding.acervoPath = $AcervoPath.Replace('\', '/')
    }
    if ($CandidateAcervoPaths -and $CandidateAcervoPaths.Count -gt 0) {
        $finding.candidateAcervoPaths = @($CandidateAcervoPaths | ForEach-Object { ([string]$_).Replace('\', '/') })
    }
    if ($null -ne $ExtraFields) {
        foreach ($key in $ExtraFields.Keys) {
            if ([string]$key -in $protectedKeys) {
                throw "ExtraFields nao pode sobrescrever campo protegido de finding: $key"
            }
        }
        foreach ($key in $ExtraFields.Keys) {
            $finding[[string]$key] = $ExtraFields[$key]
        }
    }
    return [pscustomobject]$finding
}

$domainDriftSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'GeneXusDomainDriftSupport.ps1'
if (-not (Test-Path -LiteralPath $domainDriftSupportPath -PathType Leaf)) {
    throw "Domain drift support script not found: $domainDriftSupportPath"
}
. $domainDriftSupportPath

function Read-ComparableUtf8Lines {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
    } catch {
        return [pscustomobject]@{
            ok     = $false
            reason = 'read-failed'
            lines  = @()
        }
    }
    $offset = 0
    if ($bytes.Length -ge 4) {
        if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
            return [pscustomobject]@{ ok = $false; reason = 'utf-32-le-bom'; lines = @() }
        }
        if ($bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
            return [pscustomobject]@{ ok = $false; reason = 'utf-32-be-bom'; lines = @() }
        }
    }
    if ($bytes.Length -ge 2) {
        if ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
            return [pscustomobject]@{ ok = $false; reason = 'utf-16-le-bom'; lines = @() }
        }
        if ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
            return [pscustomobject]@{ ok = $false; reason = 'utf-16-be-bom'; lines = @() }
        }
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $offset = 3
    }

    try {
        $encoding = [System.Text.UTF8Encoding]::new($false, $true)
        $stream = [System.IO.MemoryStream]::new($bytes, $offset, $bytes.Length - $offset, $false)
        $reader = [System.IO.StreamReader]::new($stream, $encoding, $false)
        try {
            $lines = [System.Collections.Generic.List[string]]::new()
            while (-not $reader.EndOfStream) {
                $lines.Add($reader.ReadLine()) | Out-Null
            }
            return [pscustomobject]@{ ok = $true; reason = ''; lines = @($lines) }
        } finally {
            $reader.Dispose()
            $stream.Dispose()
        }
    } catch {
        return [pscustomobject]@{ ok = $false; reason = 'utf-8-decode-failed'; lines = @() }
    }
}

function ConvertTo-CanonicalGeneXusTextLine {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Line)

    $result = [regex]::Replace(
        $Line,
        'lastUpdate\s*=\s*"[^"]*"',
        'lastUpdate="__GENEXUS_LASTUPDATE__"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $result = [regex]::Replace(
        $result,
        "lastUpdate\s*=\s*'[^']*'",
        "lastUpdate='__GENEXUS_LASTUPDATE__'",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    return $result
}

function New-LineMultiset {
    param([string[]]$Lines)

    $dict = [System.Collections.Generic.Dictionary[string, int]]::new([System.StringComparer]::Ordinal)
    foreach ($line in $Lines) {
        if ($dict.ContainsKey($line)) { $dict[$line] += 1 }
        else { $dict[$line] = 1 }
    }
    return $dict
}

function Get-LineResidue {
    param(
        [Parameter(Mandatory = $true)]$Left,
        [Parameter(Mandatory = $true)]$Right
    )

    $residue = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $Left.Keys) {
        $rightCount = 0
        if ($Right.ContainsKey($key)) { $rightCount = $Right[$key] }
        $remaining = $Left[$key] - $rightCount
        for ($i = 0; $i -lt $remaining; $i++) {
            $residue.Add($key) | Out-Null
        }
    }
    return @($residue)
}

function Test-FrontTextualFidelity {
    param(
        [Parameter(Mandatory = $true)]$FMeta,
        [Parameter(Mandatory = $true)]$AMeta,
        [Parameter(Mandatory = $true)][string]$FRel,
        [Parameter(Mandatory = $true)][string]$ARel
    )

    $frontRead = Read-ComparableUtf8Lines -Path $FMeta.Path
    $acervoRead = Read-ComparableUtf8Lines -Path $AMeta.Path
    if (-not $frontRead.ok -or -not $acervoRead.ok) {
        $reasons = @()
        if (-not $frontRead.ok) { $reasons += "frente=$($frontRead.reason)" }
        if (-not $acervoRead.ok) { $reasons += "acervo=$($acervoRead.reason)" }
        return @(
            New-Finding -Severity 'info' -Code 'front-textual-fidelity-info' `
                -Message "Baseline unico por GUID encontrado para '$($FMeta.Name)', mas a leitura/decodificacao UTF-8 comparavel falhou ($($reasons -join '; ')); o empacotamento nao foi bloqueado por trim global nesse caso." `
                -ObjectName $FMeta.Name -ObjectGuid $FMeta.Guid `
                -ObjectFile $FRel -AcervoFile $ARel -AcervoPath $ARel `
                -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid' `
                -ExtraFields @{
                    classification = 'not-applicable'
                    reason = ($reasons -join '; ')
                }
        )
    }

    $frontLines = @($frontRead.lines | ForEach-Object { ConvertTo-CanonicalGeneXusTextLine -Line $_ })
    $acervoLines = @($acervoRead.lines | ForEach-Object { ConvertTo-CanonicalGeneXusTextLine -Line $_ })
    $frontSet = New-LineMultiset -Lines $frontLines
    $acervoSet = New-LineMultiset -Lines $acervoLines
    $resAcervo = @(Get-LineResidue -Left $acervoSet -Right $frontSet)
    $resFront = @(Get-LineResidue -Left $frontSet -Right $acervoSet)
    if ($resAcervo.Count -eq 0 -and $resFront.Count -eq 0) {
        return @()
    }

    $frontResidueByTrim = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new([System.StringComparer]::Ordinal)
    foreach ($line in $resFront) {
        $trimmed = $line.TrimEnd()
        if (-not $frontResidueByTrim.ContainsKey($trimmed)) {
            $frontResidueByTrim[$trimmed] = [System.Collections.Generic.List[string]]::new()
        }
        $frontResidueByTrim[$trimmed].Add($line) | Out-Null
    }

    $acervoResidueByTrim = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new([System.StringComparer]::Ordinal)
    foreach ($line in $resAcervo) {
        $trimmed = $line.TrimEnd()
        if (-not $acervoResidueByTrim.ContainsKey($trimmed)) {
            $acervoResidueByTrim[$trimmed] = [System.Collections.Generic.List[string]]::new()
        }
        $acervoResidueByTrim[$trimmed].Add($line) | Out-Null
    }

    $whitespaceTrimPairCount = 0
    foreach ($key in $acervoResidueByTrim.Keys) {
        if (-not $frontResidueByTrim.ContainsKey($key)) { continue }
        $aWs = @($acervoResidueByTrim[$key] | Where-Object { $_ -ne $_.TrimEnd() }).Count
        $fTrim = @($frontResidueByTrim[$key] | Where-Object { $_ -eq $key }).Count
        $whitespaceTrimPairCount += [Math]::Min($aWs, $fTrim)
    }

    $functionalChangedLineEstimate = [Math]::Max(
        $resAcervo.Count - $whitespaceTrimPairCount,
        $resFront.Count - $whitespaceTrimPairCount
    )
    $minWhitespaceChurnLines = 25
    $churnDominanceFactor = 3
    $globalTrimRatio = 0.50
    $dominantTrim = $whitespaceTrimPairCount -ge ($churnDominanceFactor * [Math]::Max($functionalChangedLineEstimate, 1))
    $globalTrim = $whitespaceTrimPairCount -ge ($globalTrimRatio * [Math]::Max($acervoLines.Count, 1))
    if ($whitespaceTrimPairCount -ge $minWhitespaceChurnLines -and ($dominantTrim -or $globalTrim)) {
        return @(
            New-Finding -Severity 'fail' -Code 'front-textual-fidelity-trim-removal-churn' `
                -Message "Objeto '$($FMeta.Name)' removeu trailing whitespace herdado do acervo em escala forte ($whitespaceTrimPairCount linha(s)); reconstruir via Copy-GeneXusAcervoToFront.ps1 com alvo explicito e reaplicar apenas o delta funcional." `
                -ObjectName $FMeta.Name -ObjectGuid $FMeta.Guid `
                -ObjectFile $FRel -AcervoFile $ARel -AcervoPath $ARel `
                -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid' `
                -ExtraFields @{
                    classification = 'trim-removal-churn'
                    whitespaceTrimPairCount = $whitespaceTrimPairCount
                    functionalChangedLineEstimate = $functionalChangedLineEstimate
                    acervoLineCount = $acervoLines.Count
                    thresholds = [ordered]@{
                        MinWhitespaceChurnLines = $minWhitespaceChurnLines
                        ChurnDominanceFactor = $churnDominanceFactor
                        GlobalTrimRatio = $globalTrimRatio
                    }
                }
        )
    }

    return @()
}

function Get-ObjectMetadata {
    param([string]$XmlPath)
    try {
        [xml]$doc = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    } catch {
        return $null
    }
    $root = $doc.DocumentElement
    if ($null -eq $root -or $root.LocalName -ne 'Object') { return $null }
    $objType = $root.GetAttribute('type')
    $objName = ''
    foreach ($prop in $doc.SelectNodes('/Object/Properties/Property')) {
        if ($prop.Name -eq 'Name') { $objName = $prop.Value; break }
    }
    $objGuid = $root.GetAttribute('guid')
    $objFqn = $root.GetAttribute('fullyQualifiedName')
    $rootName = $root.GetAttribute('name')
    $lastUpdate = Read-ObjectLastUpdateSafe $root
    return [pscustomobject]@{
        Path       = $XmlPath
        Name       = $objName
        RootName   = $rootName
        TypeGuid   = $objType
        Guid       = $objGuid
        Fqn        = $objFqn
        LastUpdate = $lastUpdate
    }
}

$attributeTypeSignaturePropertyNames = @(
    'ATTCUSTOMTYPE',
    'idBasedOn',
    'Length',
    'Decimals',
    'AttMaxLen',
    'AttAvgLen',
    'AttCollection',
    'Signed',
    'idDATEFORMAT'
)

function Normalize-GeneXusAttributeSignatureValue {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return $Value.Trim().ToLowerInvariant()
}

$attributeSizeFieldNames = @('Length', 'AttMaxLen')

function ConvertTo-GeneXusAttributeSizeNumber {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $parsed = [decimal]0
    $style = [System.Globalization.NumberStyles]::Number
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ([decimal]::TryParse($Value.Trim(), $style, $culture, [ref]$parsed)) { return $parsed }
    return $null
}

function Get-GeneXusAttributeSizeApprovalKey {
    param(
        [string]$Guid,
        [string]$FieldName,
        [string]$AcervoValue,
        [string]$FrontValue
    )

    return ('{0}|{1}|{2}|{3}' -f $Guid.Trim().ToLowerInvariant(), $FieldName.Trim().ToLowerInvariant(), $AcervoValue.Trim(), $FrontValue.Trim())
}

function Get-AttributeMetadata {
    param([string]$XmlPath)

    try {
        [xml]$doc = Get-Content -LiteralPath $XmlPath -Raw -Encoding UTF8
    } catch {
        return $null
    }

    $root = $doc.DocumentElement
    if ($null -eq $root -or $root.LocalName -ne 'Attribute') { return $null }

    $valuesByName = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($property in $root.SelectNodes('./Properties/Property')) {
        $nameNode = $property.SelectSingleNode('./Name')
        if ($null -eq $nameNode) { continue }
        $propertyName = [string]$nameNode.InnerText
        if ($propertyName -notin $attributeTypeSignaturePropertyNames) { continue }

        $valueNode = $property.SelectSingleNode('./Value')
        $propertyValue = if ($null -eq $valueNode) { '' } else { [string]$valueNode.InnerText }
        if (-not $valuesByName.ContainsKey($propertyName)) {
            $valuesByName[$propertyName] = [System.Collections.Generic.List[string]]::new()
        }
        $valuesByName[$propertyName].Add($propertyValue) | Out-Null
    }

    $signature = [ordered]@{}
    $normalizedSignature = [ordered]@{}
    $duplicateSignatureFields = [System.Collections.Generic.List[string]]::new()
    foreach ($fieldName in $attributeTypeSignaturePropertyNames) {
        $rawValue = ''
        if ($valuesByName.ContainsKey($fieldName)) {
            $fieldValues = $valuesByName[$fieldName]
            if ($fieldValues.Count -gt 1) {
                $duplicateSignatureFields.Add($fieldName) | Out-Null
            }
            if ($fieldValues.Count -gt 0) {
                $rawValue = $fieldValues[0]
            }
        }
        $signature[$fieldName] = $rawValue.Trim()
        $normalizedSignature[$fieldName] = Normalize-GeneXusAttributeSignatureValue -Value $rawValue
    }

    return [pscustomobject]@{
        Path = $XmlPath
        Name = $root.GetAttribute('name')
        Guid = $root.GetAttribute('guid')
        Fqn = $root.GetAttribute('fullyQualifiedName')
        Signature = $signature
        NormalizedSignature = $normalizedSignature
        DuplicateSignatureFields = @($duplicateSignatureFields.ToArray())
    }
}

function New-GeneXusAttributeGuidIndex {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $index = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $untrustedFiles = [System.Collections.Generic.List[string]]::new()
    $attributeRoot = Join-Path $RootPath 'Attribute'
    if (-not (Test-Path -LiteralPath $attributeRoot -PathType Container)) {
        return [pscustomobject]@{ ByGuid = $index; UntrustedFiles = @() }
    }

    $attributeFiles = @()
    try {
        $attributeFiles = @(Get-ChildItem -LiteralPath $attributeRoot -Recurse -File -Filter '*.xml' -ErrorAction Stop)
    } catch {
        $untrustedFiles.Add([System.IO.Path]::GetRelativePath($RootPath, $attributeRoot).Replace('\', '/')) | Out-Null
        return [pscustomobject]@{ ByGuid = $index; UntrustedFiles = @($untrustedFiles.ToArray()) }
    }

    foreach ($file in $attributeFiles) {
        $acervoPath = [System.IO.Path]::GetRelativePath($RootPath, $file.FullName).Replace('\', '/')
        try {
            [xml]$doc = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        } catch {
            $untrustedFiles.Add($acervoPath) | Out-Null
            continue
        }

        $root = $doc.DocumentElement
        if ($null -eq $root -or $root.LocalName -ne 'Attribute') {
            $untrustedFiles.Add($acervoPath) | Out-Null
            continue
        }
        $guidNormalized = Normalize-GeneXusAttributeSignatureValue -Value $root.GetAttribute('guid')
        if ([string]::IsNullOrWhiteSpace($guidNormalized)) {
            $untrustedFiles.Add($acervoPath) | Out-Null
            continue
        }

        if (-not $index.ContainsKey($guidNormalized)) {
            $index[$guidNormalized] = [System.Collections.Generic.List[object]]::new()
        }
        $index[$guidNormalized].Add([pscustomobject]@{
            FullPath = $file.FullName
            AcervoPath = $acervoPath
        }) | Out-Null
    }

    return [pscustomobject]@{
        ByGuid = $index
        UntrustedFiles = @($untrustedFiles.ToArray() | Sort-Object -Unique)
    }
}

function Get-GeneXusAttributeGuidIndexMatches {
    param(
        [Parameter(Mandatory = $true)]$Index,
        [AllowNull()][string]$Guid
    )

    $guidNormalized = Normalize-GeneXusAttributeSignatureValue -Value $Guid
    $guidIndex = $Index.ByGuid
    if ([string]::IsNullOrWhiteSpace($guidNormalized) -or -not $guidIndex.ContainsKey($guidNormalized)) {
        return @()
    }

    return @($guidIndex[$guidNormalized].ToArray() | Sort-Object AcervoPath)
}

function Find-AcervoObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][pscustomobject]$FrontMeta
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $null
    }

    $candidateFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    foreach ($attrName in @('fullyQualifiedName', 'name')) {
        $value = $null
        if ($attrName -eq 'fullyQualifiedName') { $value = $FrontMeta.Fqn }
        elseif ($attrName -eq 'name') { $value = $FrontMeta.Name }
        if ([string]::IsNullOrWhiteSpace($value)) { continue }

        $leaf = "$value.xml"
        $found = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter $leaf -ErrorAction SilentlyContinue)
        foreach ($f in $found) {
            $candidateFiles.Add($f) | Out-Null
        }
    }

    if ($candidateFiles.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($FrontMeta.Guid)) {
        $guidHits = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue |
            Select-String -SimpleMatch $FrontMeta.Guid |
            ForEach-Object { $_.Path } |
            Sort-Object -Unique |
            ForEach-Object { Get-Item -LiteralPath $_ })
        foreach ($f in $guidHits) {
            $candidateFiles.Add($f) | Out-Null
        }
    }

    foreach ($file in @($candidateFiles | Sort-Object FullName -Unique)) {
        try {
            [xml]$doc = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        } catch {
            continue
        }
        $baseRoot = $doc.DocumentElement
        if ($null -eq $baseRoot -or $baseRoot.LocalName -ne 'Object') { continue }

        $matched = $false
        $baseGuid = $baseRoot.GetAttribute('guid')
        if (-not [string]::IsNullOrWhiteSpace($FrontMeta.Guid) -and $FrontMeta.Guid -eq $baseGuid) {
            $matched = $true
        }
        if (-not $matched) {
            $baseFqn = $baseRoot.GetAttribute('fullyQualifiedName')
            if (-not [string]::IsNullOrWhiteSpace($FrontMeta.Fqn) -and $FrontMeta.Fqn -eq $baseFqn) {
                $matched = $true
            }
        }
        if (-not $matched) {
            $baseName = $baseRoot.GetAttribute('name')
            if (-not [string]::IsNullOrWhiteSpace($FrontMeta.Name) -and $FrontMeta.Name -eq $baseName) {
                $matched = $true
            }
        }

        if ($matched) {
            $baseMeta = Get-ObjectMetadata $file.FullName
            if ($null -ne $baseMeta) {
                return $baseMeta
            }
        }
    }

    return $null
}

# Validar parâmetros
$explicitXmlMode = $PSCmdlet.ParameterSetName -eq 'Explicit'
if (-not $explicitXmlMode -and -not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
    throw "FRENTE_NAO_ABERTA: FrontFolder nao encontrado ou nao e diretorio: $FrontFolder. Abra/retome a frente com New-GeneXusXpzFront.ps1 (wrapper local New-*KbFront.ps1) com -ReuseIfExists antes deste gate; nao crie a pasta manualmente."
}
if ($explicitXmlMode -and @($ObjectXmlPaths).Count -eq 0) {
    throw 'ObjectXmlPaths vazio: informe pelo menos um XML explícito para o modo Domain.'
}
if (-not (Test-Path -LiteralPath $AcervoFolder -PathType Container)) {
    throw "AcervoFolder nao encontrado ou nao e diretorio: $AcervoFolder"
}
if (-not $explicitXmlMode) { $FrontFolder = (Resolve-Path -LiteralPath $FrontFolder).Path }
$AcervoFolder = (Resolve-Path -LiteralPath $AcervoFolder).Path
$catalogPath = Join-Path $PSScriptRoot 'gx-object-type-catalog.json'
$domainApprovalPathSupplied = $PSBoundParameters.ContainsKey('ApprovedDomainChangesPath')

if ($explicitXmlMode) {
    $domainDriftResult = Invoke-GeneXusDomainDriftClassifier -ObjectXmlPaths @($ObjectXmlPaths) -AcervoRootPath $AcervoFolder -FrontRootPath '' -ApprovedDomainChangesPath $ApprovedDomainChangesPath -ApprovedDomainChangesPathSupplied $domainApprovalPathSupplied -CatalogPath $catalogPath -DetectNestedDomainRoots
    $domainFailures = @($domainDriftResult.findings | Where-Object { $_.severity -eq 'fail' })
    $domainStatus = if ($domainFailures.Count -gt 0) { 'fail' } else { 'pass' }
    $explicitResult = [pscustomobject]@{
        status = $domainStatus
        frontFolder = ''
        acervoFolder = $AcervoFolder
        objectsScanned = 0
        attributesScanned = 0
        domainsScanned = $domainDriftResult.domainsScanned
        findings = @($domainDriftResult.findings)
    }
    if ($AsJson) { $explicitResult | ConvertTo-Json -Depth 15 } else {
        Write-Output "status: $domainStatus"
        Write-Output "domainsScanned: $($domainDriftResult.domainsScanned)"
        foreach ($finding in $domainDriftResult.findings) { Write-Output "  - [$($finding.severity)] $($finding.code): $($finding.message)" }
    }
    return
}

$objectTypeGuidIndex = New-GeneXusObjectTypeGuidIndex -RootPath $AcervoFolder

# 1. Enumerar XMLs na pasta da frente
$frontXmls = @(Get-ChildItem -LiteralPath $FrontFolder -File -Filter '*.xml')
$domainDriftResult = Invoke-GeneXusDomainDriftClassifier -ObjectXmlPaths @($frontXmls | ForEach-Object { $_.FullName }) -AcervoRootPath $AcervoFolder -FrontRootPath $FrontFolder -ApprovedDomainChangesPath $ApprovedDomainChangesPath -ApprovedDomainChangesPathSupplied $domainApprovalPathSupplied -CatalogPath $catalogPath
$findings = @($domainDriftResult.findings)
$approvedAttributeSizeGrowthKeys = @{}
$usedAttributeSizeGrowthKeys = [System.Collections.Generic.HashSet[string]]::new()
foreach ($approvalEntry in @($ApprovedAttributeSizeGrowth)) {
    $parts = @($approvalEntry.Split([char]'|'))
    $approvalProblem = ''
    if ($parts.Count -ne 4) {
        $approvalProblem = 'formato esperado: <GUID>|<campo>|<valor-no-acervo>|<valor-na-frente>'
    } else {
        $approvalGuidValue = [guid]::Empty
        if (-not [guid]::TryParse($parts[0].Trim(), [ref]$approvalGuidValue)) {
            $approvalProblem = 'GUID invalido'
        } else {
            $approvalField = @($attributeSizeFieldNames | Where-Object { $_ -ieq $parts[1].Trim() } | Select-Object -First 1)
            if ($approvalField.Count -eq 0) {
                $approvalProblem = "campo nao autorizavel; campos aceitos: $($attributeSizeFieldNames -join ', ')"
            } else {
                $oldSize = ConvertTo-GeneXusAttributeSizeNumber -Value $parts[2]
                $newSize = ConvertTo-GeneXusAttributeSizeNumber -Value $parts[3]
                if ($null -eq $oldSize -or $null -eq $newSize -or $oldSize -lt 0 -or $newSize -le $oldSize) {
                    $approvalProblem = 'a autorizacao precisa descrever aumento numerico, nao negativo, do valor do acervo para o valor da frente'
                } else {
                    $key = Get-GeneXusAttributeSizeApprovalKey -Guid $approvalGuidValue.ToString('D') -FieldName $approvalField[0] -AcervoValue $parts[2] -FrontValue $parts[3]
                    if ($approvedAttributeSizeGrowthKeys.ContainsKey($key)) {
                        $approvalProblem = 'autorizacao duplicada'
                    } else {
                        $approvedAttributeSizeGrowthKeys[$key] = $approvalEntry
                    }
                }
            }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($approvalProblem)) {
        $findings += New-Finding -Severity 'fail' -Code 'front-attribute-size-approval-invalid' -Message "Autorizacao de aumento de tamanho de Attribute invalida: $approvalProblem." -ObjectName '' -ObjectGuid '' -ObjectFile '' -AcervoFile '' -AcervoPath '' -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'attribute-size-approval' -ExtraFields @{ suppliedApproval = $approvalEntry }
    }
}
$frontMetas = @()
$frontAttributeMetas = @()
foreach ($xml in $frontXmls) {
    $meta = Get-ObjectMetadata $xml.FullName
    $metaIsDomain = $null -ne $meta -and $domainDriftResult.byPath.ContainsKey([System.IO.Path]::GetFullPath($meta.Path))
    if ($metaIsDomain -and [string]::IsNullOrWhiteSpace($meta.Name)) { $meta.Name = $meta.RootName }
    if ($null -ne $meta -and (-not [string]::IsNullOrWhiteSpace($meta.Name) -or $metaIsDomain)) {
        $frontMetas += $meta
        continue
    }

    $attributeMeta = Get-AttributeMetadata $xml.FullName
    if ($null -ne $attributeMeta) {
        $frontAttributeMetas += $attributeMeta
    }
}

$objectsScanned = $frontMetas.Count
$attributesScanned = $frontAttributeMetas.Count
$attributeGuidIndex = $null
$attributeAcervoUntrustedPaths = @()
if ($attributesScanned -gt 0) {
    $attributeGuidIndex = New-GeneXusAttributeGuidIndex -RootPath $AcervoFolder
    $attributeAcervoUntrustedPaths = @($attributeGuidIndex.UntrustedFiles)
}

if ($objectsScanned -eq 0 -and $attributesScanned -eq 0 -and $frontXmls.Count -eq 0 -and $findings.Count -eq 0) {
    $status = 'not-applicable'
} else {
    # 2. Para cada objeto da frente, buscar homonimo no acervo e comparar
    foreach ($fMeta in $frontMetas) {
        $fRel = [System.IO.Path]::GetRelativePath($FrontFolder, $fMeta.Path)
        $matchBasis = ''
        $typeDriftFatalForObject = $false
        $aMeta = $null
        $isDomainObject = $domainDriftResult.byPath.ContainsKey([System.IO.Path]::GetFullPath($fMeta.Path))
        if ($isDomainObject) {
            $domainPathKey = [System.IO.Path]::GetFullPath($fMeta.Path)
            if (-not $domainDriftResult.byPath.ContainsKey($domainPathKey)) { continue }
            $domainState = $domainDriftResult.byPath[$domainPathKey]
            if ($domainState.state -eq 'blocked') { continue }
            if ($domainState.state -eq 'new') {
                $findings += New-Finding -Severity 'info' -Code 'front-only-new-object' `
                    -Message "Domain '$($fMeta.Name)' existe na frente mas não na pasta direta Domain/ do acervo; classificado como novo após validar as varreduras de identidade." `
                    -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid -ObjectFile $fRel -AcervoFile '' `
                    -FrontLastUpdate $(if ($null -ne $fMeta.LastUpdate) { Format-GeneXusLastUpdate $fMeta.LastUpdate } else { '' }) -AcervoLastUpdate ''
                continue
            }
            $aMeta = Get-ObjectMetadata ([string]$domainState.baseline)
            if ($null -eq $aMeta) { continue }
            $matchBasis = 'guid'
        } else {
            $guidAcervoMatches = @(Get-GeneXusObjectTypeGuidIndexMatches -Index $objectTypeGuidIndex -Guid $fMeta.Guid)
            $guidAcervoPaths = @($guidAcervoMatches | ForEach-Object { $_.FullPath })
            $guidAcervoRelPaths = @($guidAcervoMatches | ForEach-Object { $_.AcervoPath })

            if ($guidAcervoMatches.Count -eq 1) {
                $aMeta = Get-ObjectMetadata $guidAcervoMatches[0].FullPath
                if ($null -ne $aMeta) {
                    $frontTypeNorm = Normalize-GeneXusObjectTypeDriftValue -Value $fMeta.TypeGuid
                    $acervoTypeNorm = Normalize-GeneXusObjectTypeDriftValue -Value $aMeta.TypeGuid
                    $objectGuidNorm = Normalize-GeneXusObjectTypeDriftValue -Value $fMeta.Guid
                    $acervoGuidNorm = Normalize-GeneXusObjectTypeDriftValue -Value $aMeta.Guid
                    if (-not [string]::IsNullOrWhiteSpace($objectGuidNorm) -and $objectGuidNorm -eq $acervoGuidNorm) {
                        $matchBasis = 'guid'
                        if (-not [string]::IsNullOrWhiteSpace($frontTypeNorm) -and -not [string]::IsNullOrWhiteSpace($acervoTypeNorm) -and $frontTypeNorm -ne $acervoTypeNorm) {
                            $typeDriftFatalForObject = $true
                            $typeMessage = "Objeto '$($fMeta.Name)' tem o mesmo guid na frente e no acervo, mas Object/@type diverge (frente='$($fMeta.TypeGuid)', acervo='$($aMeta.TypeGuid)'). Decisao humana requerida antes de empacotar."
                            $common = New-GeneXusObjectTypeDriftCommonFields -ObjectGuid $fMeta.Guid -ObjectName $fMeta.Name -FullyQualifiedName $fMeta.Fqn -FrontObjectType $fMeta.TypeGuid -AcervoObjectType $aMeta.TypeGuid -MatchBasis $matchBasis -AcervoPath $guidAcervoMatches[0].AcervoPath -Message $typeMessage -Code 'front-object-type-drift'
                            $findings += New-Finding -Severity 'fail' -Code 'front-object-type-drift' -Message $common['message'] -ObjectName $fMeta.Name -ObjectGuid $common['objectGuid'] -ObjectFile $fRel -AcervoFile '' -AcervoPath $common['acervoPath'] -FrontLastUpdate '' -AcervoLastUpdate '' -FrontObjectType $common['frontObjectType'] -AcervoObjectType $common['acervoObjectType'] -FrontObjectTypeNormalized $common['frontObjectTypeNormalized'] -AcervoObjectTypeNormalized $common['acervoObjectTypeNormalized'] -MatchBasis $common['matchBasis']
                        }
                    }
                }
            } elseif ($guidAcervoMatches.Count -gt 1) {
                $ambiguousMessage = "Objeto '$($fMeta.Name)' tem guid presente em mais de um XML do acervo; drift de Object/@type nao foi decidido automaticamente."
                $common = New-GeneXusObjectTypeDriftCommonFields -ObjectGuid $fMeta.Guid -ObjectName $fMeta.Name -FullyQualifiedName $fMeta.Fqn -FrontObjectType $fMeta.TypeGuid -MatchBasis 'guid-ambiguous' -CandidateAcervoPaths $guidAcervoRelPaths -Message $ambiguousMessage -Code 'front-object-type-drift-ambiguous-acervo'
                $findings += New-Finding -Severity 'info' -Code 'front-object-type-drift-ambiguous-acervo' -Message $common['message'] -ObjectName $fMeta.Name -ObjectGuid $common['objectGuid'] -ObjectFile $fRel -AcervoFile '' -FrontLastUpdate '' -AcervoLastUpdate '' -FrontObjectType $common['frontObjectType'] -AcervoObjectType '' -FrontObjectTypeNormalized $common['frontObjectTypeNormalized'] -AcervoObjectTypeNormalized '' -MatchBasis $common['matchBasis'] -CandidateAcervoPaths $common['candidateAcervoPaths']
            }

            if ($null -eq $aMeta) { $aMeta = Find-AcervoObjectXml -RootPath $AcervoFolder -FrontMeta $fMeta }
            if ($null -eq $aMeta) {
                $findings += New-Finding -Severity 'info' -Code 'front-only-new-object' -Message "Objeto '$($fMeta.Name)' existe na frente mas nao no acervo; presumido novo (nao copiado do acervo)." -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid -ObjectFile $fRel -AcervoFile '' -FrontLastUpdate $(if ($null -ne $fMeta.LastUpdate) { Format-GeneXusLastUpdate $fMeta.LastUpdate } else { '' }) -AcervoLastUpdate ''
                continue
            }
        }

        $aRel = [System.IO.Path]::GetRelativePath($AcervoFolder, $aMeta.Path)

        $fLastStr = if ($null -ne $fMeta.LastUpdate) { Format-GeneXusLastUpdate $fMeta.LastUpdate } else { '' }
        $aLastStr = if ($null -ne $aMeta.LastUpdate) { Format-GeneXusLastUpdate $aMeta.LastUpdate } else { '' }

        if ($matchBasis -eq 'guid') {
            $findings += @(Test-FrontTextualFidelity -FMeta $fMeta -AMeta $aMeta -FRel $fRel -ARel $aRel)
        }

        if ($null -eq $fMeta.LastUpdate -or $null -eq $aMeta.LastUpdate) {
            $findings += New-Finding -Severity 'warn' -Code 'lastupdate-unparseable' `
                -Message "Objeto '$($fMeta.Name)' com lastUpdate nao parseavel (frente='$fLastStr', acervo='$aLastStr'). Comparacao manual necessaria." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile $aRel `
                -FrontLastUpdate $fLastStr -AcervoLastUpdate $aLastStr
            continue
        }

        if ($fMeta.LastUpdate -lt $aMeta.LastUpdate) {
            $findings += New-Finding -Severity 'fail' -Code 'front-older-than-acervo' `
                -Message "Objeto '$($fMeta.Name)' na frente tem lastUpdate ($fLastStr) anterior ao acervo ($aLastStr). A frente esta desatualizada — copiar do acervo antes de empacotar." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile $aRel `
                -FrontLastUpdate $fLastStr -AcervoLastUpdate $aLastStr
        } elseif ($fMeta.LastUpdate -eq $aMeta.LastUpdate) {
            $findings += New-Finding -Severity 'warn' -Code 'front-equals-acervo' `
                -Message "Objeto '$($fMeta.Name)' na frente preserva lastUpdate igual ao acervo ($fLastStr). Se o objeto foi modificado na frente, o lastUpdate deveria ser mais recente." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile $aRel `
                -FrontLastUpdate $fLastStr -AcervoLastUpdate $aLastStr
        } else {
            if (-not $typeDriftFatalForObject) {
                $findings += New-Finding -Severity 'info' -Code 'front-newer-than-acervo' `
                    -Message "Objeto '$($fMeta.Name)' na frente tem lastUpdate ($fLastStr) mais recente que o acervo ($aLastStr). Consistente com edicao na frente." `
                    -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                    -ObjectFile $fRel -AcervoFile $aRel `
                    -FrontLastUpdate $fLastStr -AcervoLastUpdate $aLastStr `
                    -MatchBasis $matchBasis
            }
        }
    }

    # 3. Para cada Attribute top-level, comparar assinatura funcional por GUID.
    foreach ($fAttribute in $frontAttributeMetas) {
        $fRel = [System.IO.Path]::GetRelativePath($FrontFolder, $fAttribute.Path)
        $frontGuidNorm = Normalize-GeneXusAttributeSignatureValue -Value $fAttribute.Guid
        if ([string]::IsNullOrWhiteSpace($frontGuidNorm)) {
            $findings += New-Finding -Severity 'fail' -Code 'front-attribute-identity-incomplete' -Message "Attribute '$($fAttribute.Name)' nao tem GUID; a assinatura de tipo nao pode ser reconciliada com o acervo antes de empacotar." -ObjectName $fAttribute.Name -ObjectGuid '' -ObjectFile $fRel -AcervoFile '' -AcervoPath '' -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid-missing' -ExtraFields @{ reason = 'attribute-guid-missing' }
            continue
        }

        if ($attributeAcervoUntrustedPaths.Count -gt 0) {
            $firstUntrustedPath = [string]$attributeAcervoUntrustedPaths[0]
            $findings += New-Finding -Severity 'fail' -Code 'front-attribute-acervo-unreadable' -Message "Acervo Attribute contem XML(s) ilegivel(is), sem raiz Attribute ou sem GUID; a comparacao de baseline nao e confiavel. Requer revisao manual antes de classificar '$($fAttribute.Name)' como novo ou comparar sua assinatura." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile $firstUntrustedPath -AcervoPath $firstUntrustedPath -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid' -ExtraFields @{ untrustedAcervoPaths = @($attributeAcervoUntrustedPaths) }
            continue
        }

        $guidMatches = @(Get-GeneXusAttributeGuidIndexMatches -Index $attributeGuidIndex -Guid $frontGuidNorm)
        if ($guidMatches.Count -eq 0) {
            $findings += New-Finding -Severity 'info' -Code 'front-only-new-attribute' -Message "Attribute '$($fAttribute.Name)' nao tem Attribute correspondente por GUID no acervo; tratado como novo, sem baseline de assinatura comparavel." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile '' -AcervoPath '' -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid-not-found'
            continue
        }

        $candidateAcervoPaths = @($guidMatches | ForEach-Object { $_.AcervoPath })
        if ($guidMatches.Count -gt 1) {
            $findings += New-Finding -Severity 'fail' -Code 'front-attribute-type-signature-ambiguous-acervo' -Message "Attribute '$($fAttribute.Name)' tem GUID presente em mais de um XML Attribute do acervo; a assinatura funcional nao pode ser escolhida com seguranca." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile '' -AcervoPath '' -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid-ambiguous' -CandidateAcervoPaths $candidateAcervoPaths
            continue
        }

        $aAttribute = Get-AttributeMetadata $guidMatches[0].FullPath
        if ($null -eq $aAttribute) {
            $findings += New-Finding -Severity 'fail' -Code 'front-attribute-acervo-unreadable' -Message "Attribute '$($fAttribute.Name)' tem GUID localizado no acervo, mas o XML oficial nao pode ser lido como Attribute." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile '' -AcervoPath $guidMatches[0].AcervoPath -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid'
            continue
        }

        if ($fAttribute.DuplicateSignatureFields.Count -gt 0 -or $aAttribute.DuplicateSignatureFields.Count -gt 0) {
            $findings += New-Finding -Severity 'fail' -Code 'front-attribute-type-signature-invalid' -Message "Attribute '$($fAttribute.Name)' tem propriedade(s) de assinatura de tipo duplicada(s) na frente ou no acervo; revisao manual necessaria." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile '' -AcervoPath $guidMatches[0].AcervoPath -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid' -ExtraFields @{ frontDuplicateSignatureFields = @($fAttribute.DuplicateSignatureFields); acervoDuplicateSignatureFields = @($aAttribute.DuplicateSignatureFields) }
            continue
        }

        $signatureDifferences = @()
        foreach ($fieldName in $attributeTypeSignaturePropertyNames) {
            $frontValue = [string]$fAttribute.Signature[$fieldName]
            $acervoValue = [string]$aAttribute.Signature[$fieldName]
            if ($fAttribute.NormalizedSignature[$fieldName] -ne $aAttribute.NormalizedSignature[$fieldName]) {
                $signatureDifferences += [pscustomobject]@{
                    fieldName = $fieldName
                    frontValue = $frontValue
                    acervoValue = $acervoValue
                }
            }
        }

        $typeSignatureDifferences = @()
        $sizeReductions = @()
        $sizeGrowth = @()
        foreach ($difference in $signatureDifferences) {
            if ($difference.fieldName -notin $attributeSizeFieldNames) {
                $typeSignatureDifferences += $difference
                continue
            }
            $acervoSize = ConvertTo-GeneXusAttributeSizeNumber -Value $difference.acervoValue
            $frontSize = ConvertTo-GeneXusAttributeSizeNumber -Value $difference.frontValue
            if ($null -eq $acervoSize -or $null -eq $frontSize -or $acervoSize -eq $frontSize) {
                $typeSignatureDifferences += $difference
            } elseif ($frontSize -lt $acervoSize) {
                $sizeReductions += $difference
            } else {
                $sizeGrowth += $difference
            }
        }

        if ($typeSignatureDifferences.Count -gt 0) {
            $differenceSummary = @($typeSignatureDifferences | ForEach-Object {
                $frontValueText = if ([string]::IsNullOrWhiteSpace($_.frontValue)) { '(ausente/vazio)' } else { $_.frontValue }
                $acervoValueText = if ([string]::IsNullOrWhiteSpace($_.acervoValue)) { '(ausente/vazio)' } else { $_.acervoValue }
                "$($_.fieldName): frente='$frontValueText', acervo='$acervoValueText'"
            }) -join '; '
            $findings += New-Finding -Severity 'fail' -Code 'front-attribute-type-signature-drift' -Message "Attribute '$($fAttribute.Name)' tem tipo ou propriedade funcional divergente do acervo ($differenceSummary). Mudancas desse tipo sao sempre bloqueadas pelo pacote; corrigir pela IDE GeneXus e reexportar." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile '' -AcervoPath $guidMatches[0].AcervoPath -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid' -ExtraFields @{ signatureDifferences = @($typeSignatureDifferences) }
        }

        if ($sizeReductions.Count -gt 0) {
            $differenceSummary = @($sizeReductions | ForEach-Object { "$($_.fieldName): $($_.acervoValue) -> $($_.frontValue)" }) -join '; '
            $findings += New-Finding -Severity 'fail' -Code 'front-attribute-size-reduction' -Message "Attribute '$($fAttribute.Name)' reduz tamanho definido no acervo ($differenceSummary); reducoes sao sempre bloqueadas pelo pacote." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile '' -AcervoPath $guidMatches[0].AcervoPath -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid' -ExtraFields @{ signatureDifferences = @($sizeReductions) }
        }

        foreach ($growth in $sizeGrowth) {
            $approvalKey = Get-GeneXusAttributeSizeApprovalKey -Guid $frontGuidNorm -FieldName $growth.fieldName -AcervoValue $growth.acervoValue -FrontValue $growth.frontValue
            $requiredApproval = '{0}|{1}|{2}|{3}' -f $frontGuidNorm, $growth.fieldName, $growth.acervoValue, $growth.frontValue
            if ($approvedAttributeSizeGrowthKeys.ContainsKey($approvalKey)) {
                [void]$usedAttributeSizeGrowthKeys.Add($approvalKey)
                $findings += New-Finding -Severity 'info' -Code 'front-attribute-size-growth-authorized' -Message "Aumento de $($growth.fieldName) em Attribute '$($fAttribute.Name)' corresponde a autorizacao explicita e pontual recebida na chamada do gate ($($growth.acervoValue) -> $($growth.frontValue))." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile '' -AcervoPath $guidMatches[0].AcervoPath -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid' -ExtraFields @{ signatureDifferences = @($growth); approvalTuple = $requiredApproval }
            } else {
                $findings += New-Finding -Severity 'fail' -Code 'front-attribute-size-growth-requires-user-request' -Message "Aumento de $($growth.fieldName) em Attribute '$($fAttribute.Name)' ($($growth.acervoValue) -> $($growth.frontValue)) exige solicitacao explicita do usuario para essa mudanca exata antes de empacotar." -ObjectName $fAttribute.Name -ObjectGuid $frontGuidNorm -ObjectFile $fRel -AcervoFile '' -AcervoPath $guidMatches[0].AcervoPath -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'guid' -ExtraFields @{ signatureDifferences = @($growth); requiredApproval = $requiredApproval }
            }
        }
    }

    foreach ($approvalKey in @($approvedAttributeSizeGrowthKeys.Keys)) {
        if (-not $usedAttributeSizeGrowthKeys.Contains([string]$approvalKey)) {
            $approvalEntry = [string]$approvedAttributeSizeGrowthKeys[$approvalKey]
            $findings += New-Finding -Severity 'fail' -Code 'front-attribute-size-approval-unmatched' -Message 'A autorizacao de aumento informada nao corresponde a uma divergencia exata de GUID, campo e valores nesta frente; o pacote continua bloqueado.' -ObjectName '' -ObjectGuid '' -ObjectFile '' -AcervoFile '' -AcervoPath '' -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'attribute-size-approval' -ExtraFields @{ suppliedApproval = $approvalEntry }
        }
    }
    # 4. Status agregado
    $hasFail = $findings | Where-Object { $_.severity -eq 'fail' } | Select-Object -First 1
    $hasWarn  = $findings | Where-Object { $_.severity -eq 'warn' } | Select-Object -First 1
    if ($hasFail) { $status = 'fail' }
    elseif ($hasWarn) { $status = 'alert' }
    else { $status = 'pass' }
}

# 4. Emitir resultado
$result = [pscustomobject]@{
    status          = $status
    frontFolder     = $FrontFolder
    acervoFolder    = $AcervoFolder
    objectsScanned  = $objectsScanned
    attributesScanned = $attributesScanned
    domainsScanned = $domainDriftResult.domainsScanned
    findings        = $findings
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 10
} else {
    Write-Output "status: $status"
    Write-Output "frontFolder: $FrontFolder"
    Write-Output "acervoFolder: $AcervoFolder"
    Write-Output "objectsScanned: $objectsScanned"
    Write-Output "attributesScanned: $attributesScanned"
    if ($findings.Count -eq 0) {
        Write-Output "findings: (none)"
    } else {
        Write-Output "findings:"
        foreach ($f in $findings) {
            Write-Output "  - [$($f.severity)] $($f.code): $($f.message)"
            Write-Output "    object: $($f.objectName) ($($f.objectFile))"
            Write-Output "    acervoFile: $($f.acervoFile)"
        }
    }
}
