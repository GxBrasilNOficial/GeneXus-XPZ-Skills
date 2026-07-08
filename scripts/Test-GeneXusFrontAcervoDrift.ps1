#requires -Version 7.4

<#
.SYNOPSIS
    Compara cada XML da frente contra o homonimo no acervo e emite findings de drift.

.DESCRIPTION
    Para cada <Object> na pasta da frente, busca o XML correspondente no acervo
    (ObjetosDaKbEmXml) por GUID ou por nome, e compara:
      - lastUpdate: se o acervo e mais recente que a frente, emite finding.
      - Object/@type: se frente e acervo compartilham o mesmo guid e têm tipos
        GeneXus divergentes, emite front-object-type-drift fatal.
      - presenca no acervo: se o objeto da frente não existe no acervo, classifica
        como objeto novo presumido. O gate não enumera objetos do acervo ausentes
        da frente, porque a frente e o escopo operacional do empacotamento.

    Código de severidade por finding:
      info    — não ha bloqueio (frente mais recente que acervo, ou objeto só existe
                 na frente = objeto novo)
      warn    — revisao obrigatória antes de empacotar (frente com mesmo lastUpdate
                 do acervo, ou lastUpdate não parseavel)
      fail    — frente com lastUpdate mais antigo que acervo

.PARAMETER FrontFolder
    Caminho da pasta da frente (ObjetosGeradosParaImportacaoNaKbNoGenexus/<NomeCurto_GUID_YYYYMMDD>).

.PARAMETER AcervoFolder
    Caminho da pasta do acervo oficial (ObjetosDaKbEmXml).

.PARAMETER AsJson
    Emite resultado estruturado em JSON.

.EXAMPLE
    .\Test-GeneXusFrontAcervoDrift.ps1 -FrontFolder C:\Kb\ObjetosGeradosParaImportacaoNaKbNoGenexus\GtaP3_c34f_20260528 -AcervoFolder C:\Kb\ObjetosDaKbEmXml -AsJson
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FrontFolder,

    [Parameter(Mandatory = $true)]
    [string]$AcervoFolder,

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
        [string]$FrontLastUpdate,
        [string]$AcervoLastUpdate,
        [string]$FrontObjectType,
        [string]$AcervoObjectType,
        [string]$FrontObjectTypeNormalized,
        [string]$AcervoObjectTypeNormalized,
        [string]$MatchBasis,
        [string[]]$CandidateBaselinePaths
    )
    $finding = [ordered]@{
        severity         = $Severity
        code             = $Code
        message          = $Message
        objectName       = $ObjectName
        objectGuid       = $ObjectGuid
        objectFile       = $ObjectFile
        acervoFile       = $AcervoFile
        frontLastUpdate  = $FrontLastUpdate
        acervoLastUpdate = $AcervoLastUpdate
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
    if ($CandidateBaselinePaths -and $CandidateBaselinePaths.Count -gt 0) {
        $finding.candidateBaselinePaths = @($CandidateBaselinePaths)
    }
    return [pscustomobject]$finding
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
    $lastUpdate = Read-ObjectLastUpdateSafe $root
    return [pscustomobject]@{
        Path       = $XmlPath
        Name       = $objName
        TypeGuid   = $objType
        Guid       = $objGuid
        Fqn        = $objFqn
        LastUpdate = $lastUpdate
    }
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
if (-not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
    throw "FRENTE_NAO_ABERTA: FrontFolder nao encontrado ou nao e diretorio: $FrontFolder. Abra/retome a frente com New-GeneXusXpzFront.ps1 (wrapper local New-*KbFront.ps1) com -ReuseIfExists antes deste gate; nao crie a pasta manualmente."
}
if (-not (Test-Path -LiteralPath $AcervoFolder -PathType Container)) {
    throw "AcervoFolder nao encontrado ou nao e diretorio: $AcervoFolder"
}
$FrontFolder  = (Resolve-Path -LiteralPath $FrontFolder).Path
$AcervoFolder = (Resolve-Path -LiteralPath $AcervoFolder).Path
$objectTypeGuidIndex = New-GeneXusObjectTypeGuidIndex -RootPath $AcervoFolder

# 1. Enumerar XMLs na pasta da frente
$findings = @()
$frontXmls = @(Get-ChildItem -LiteralPath $FrontFolder -File -Filter '*.xml')
$frontMetas = @()
foreach ($xml in $frontXmls) {
    $meta = Get-ObjectMetadata $xml.FullName
    if ($null -ne $meta -and -not [string]::IsNullOrWhiteSpace($meta.Name)) {
        $frontMetas += $meta
    }
}

$objectsScanned = $frontMetas.Count

if ($objectsScanned -eq 0 -and $frontXmls.Count -eq 0) {
    $status = 'not-applicable'
} else {
    # 2. Para cada objeto da frente, buscar homonimo no acervo e comparar
    foreach ($fMeta in $frontMetas) {
        $fRel = [System.IO.Path]::GetRelativePath($FrontFolder, $fMeta.Path)
        $guidBaselinePaths = @(Get-GeneXusObjectTypeGuidIndexMatches -Index $objectTypeGuidIndex -Guid $fMeta.Guid)
        $guidBaselineRelPaths = @($guidBaselinePaths | ForEach-Object { [System.IO.Path]::GetRelativePath($AcervoFolder, $_) })
        $matchBasis = ''
        $typeDriftFatalForObject = $false
        $aMeta = $null

        if ($guidBaselinePaths.Count -eq 1) {
            $aMeta = Get-ObjectMetadata $guidBaselinePaths[0]
            if ($null -ne $aMeta) {
                $frontTypeNorm = Normalize-GeneXusObjectTypeDriftValue -Value $fMeta.TypeGuid
                $acervoTypeNorm = Normalize-GeneXusObjectTypeDriftValue -Value $aMeta.TypeGuid
                $frontGuidNorm = Normalize-GeneXusObjectTypeDriftValue -Value $fMeta.Guid
                $acervoGuidNorm = Normalize-GeneXusObjectTypeDriftValue -Value $aMeta.Guid
                if (-not [string]::IsNullOrWhiteSpace($frontGuidNorm) -and $frontGuidNorm -eq $acervoGuidNorm) {
                    $matchBasis = 'guid'
                    if (
                        -not [string]::IsNullOrWhiteSpace($frontTypeNorm) -and
                        -not [string]::IsNullOrWhiteSpace($acervoTypeNorm) -and
                        $frontTypeNorm -ne $acervoTypeNorm
                    ) {
                        $typeDriftFatalForObject = $true
                        $findings += New-Finding -Severity 'fail' -Code 'front-object-type-drift' `
                            -Message "Objeto '$($fMeta.Name)' tem o mesmo guid na frente e no acervo, mas Object/@type diverge (frente='$($fMeta.TypeGuid)', acervo='$($aMeta.TypeGuid)'). Decisao humana requerida antes de empacotar." `
                            -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                            -ObjectFile $fRel -AcervoFile ([System.IO.Path]::GetRelativePath($AcervoFolder, $aMeta.Path)) `
                            -FrontLastUpdate '' -AcervoLastUpdate '' `
                            -FrontObjectType $fMeta.TypeGuid -AcervoObjectType $aMeta.TypeGuid `
                            -FrontObjectTypeNormalized $frontTypeNorm -AcervoObjectTypeNormalized $acervoTypeNorm `
                            -MatchBasis $matchBasis -CandidateBaselinePaths $guidBaselineRelPaths
                    }
                }
            }
        } elseif ($guidBaselinePaths.Count -gt 1) {
            $findings += New-Finding -Severity 'info' -Code 'front-object-type-drift-ambiguous-baseline' `
                -Message "Objeto '$($fMeta.Name)' tem guid presente em mais de um XML do acervo; drift de Object/@type nao foi decidido automaticamente." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile '' `
                -FrontLastUpdate '' -AcervoLastUpdate '' `
                -FrontObjectType $fMeta.TypeGuid -AcervoObjectType '' `
                -FrontObjectTypeNormalized (Normalize-GeneXusObjectTypeDriftValue -Value $fMeta.TypeGuid) -AcervoObjectTypeNormalized '' `
                -MatchBasis 'guid-ambiguous' -CandidateBaselinePaths $guidBaselineRelPaths
        }

        if ($null -eq $aMeta) {
            $aMeta = Find-AcervoObjectXml -RootPath $AcervoFolder -FrontMeta $fMeta
        }

        if ($null -eq $aMeta) {
            $findings += New-Finding -Severity 'info' -Code 'front-only-new-object' `
                -Message "Objeto '$($fMeta.Name)' existe na frente mas nao no acervo; presumido novo (nao copiado do acervo)." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile '' `
                -FrontLastUpdate $(if ($null -ne $fMeta.LastUpdate) { Format-GeneXusLastUpdate $fMeta.LastUpdate } else { '' }) `
                -AcervoLastUpdate ''
            continue
        }

        $aRel = [System.IO.Path]::GetRelativePath($AcervoFolder, $aMeta.Path)

        $fLastStr = if ($null -ne $fMeta.LastUpdate) { Format-GeneXusLastUpdate $fMeta.LastUpdate } else { '' }
        $aLastStr = if ($null -ne $aMeta.LastUpdate) { Format-GeneXusLastUpdate $aMeta.LastUpdate } else { '' }

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

    # 3. Status agregado
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
    findings        = $findings
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
} else {
    Write-Output "status: $status"
    Write-Output "frontFolder: $FrontFolder"
    Write-Output "acervoFolder: $AcervoFolder"
    Write-Output "objectsScanned: $objectsScanned"
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
