#requires -Version 7.4

<#
.SYNOPSIS
    Copia XMLs do acervo para a frente, com bump de lastUpdate.

.DESCRIPTION
    Para cada XML de objeto na pasta da frente que tem homonimo no acervo com lastUpdate
    mais recente, copia o arquivo do acervo sobre o da frente e bumpa o lastUpdate para
    garantir que o novo arquivo fique estritamente mais novo que o acervo. Excecao:
    quando o mesmo guid tem Object/@type divergente, a copia automatica e bloqueada.

    Resolve o anti-padrao "editar acervo esperando que o pacote pegue": em vez de editar
    o acervo, o agente copia a versão mais recente do acervo para a frente e depois edita
    a copia. O gate 9-FD (Test-GeneXusFrontAcervoDrift.ps1) detecta o drift; este script
    resolve apenas drift temporal copiando e bumpando; drift de Object/@type
    por mesmo guid exige decisao humana antes de qualquer autocopia.

    Comportamento por finding do gate 9-FD:
      - front-older-than-acervo: copia do acervo e bumpa lastUpdate (ação primaria)
      - front-equals-acervo: copia do acervo e bumpa lastUpdate (conservative; o agente
        pode querer preservar, mas copiar e bumpar e o caminho seguro para edicoes futuras)
      - front-only-new-object: ignorado (objeto novo, sem homonimo no acervo)
      - front-newer-than-acervo: ignorado (frente já e mais recente)
      - lastupdate-unparseable: ignorado (requer resolucao manual)
      - front-object-type-drift: ignorado (requer decisao humana; nao autocopiar)

    Quando -ObjectList, -ObjectNames ou -ObjectGuids e fornecido, só os objetos listados
    são considerados para copia. Quando omitido, todos os objetos com drift são copiados.
    Se um objeto listado explicitamente ainda não existir na frente, o script faz seed
    inicial desse objeto a partir do acervo. Seed nunca ocorre sem alvo explicito.

.PARAMETER FrontFolder
    Caminho da pasta da frente (ObjetosGeradosParaImportacaoNaKbNoGenexus/<NomeCurto_GUID_YYYYMMDD>).
    Pre-condicao: a frente deve ter sido aberta por New-GeneXusXpzFront.ps1 (wrapper local
    New-*KbFront.ps1, com -ReuseIfExists para retomar); este script apenas popula uma frente
    existente, nao a cria.

.PARAMETER AcervoFolder
    Caminho da pasta do acervo oficial (ObjetosDaKbEmXml).

.PARAMETER ObjectList
    Nome canonico do contrato de selecao de objeto por nome. Aceita nomes simples
    ou entradas `Tipo:Nome`; o script usa apenas o nome para localizar o XML no
    acervo. Quando omitido (junto com -ObjectNames/-ObjectGuids), copia todos com
    drift. Para seed inicial, deve identificar um único XML no acervo.

.PARAMETER ObjectNames
    Sinonimo aceito de -ObjectList (mesma semantica de selecao por nome); mantido
    por retrocompatibilidade. Itens informados por -ObjectNames e -ObjectList são
    combinados.

.PARAMETER ObjectGuids
    GUIDs de objetos a copiar (opcional). Quando omitido, copia todos com drift.
    Para seed inicial, deve identificar um único XML no acervo.

.PARAMETER FreshnessMarginSeconds
    Margem em segundos aplicada sobre o lastUpdate do acervo ao bumpar. Default: 60.

.PARAMETER DryRun
    Mostra o que seria copiado sem gravar. Útil para preview.

.EXAMPLE
    # Refresh por drift: copia do acervo todos os objetos da frente que estiverem mais antigos.
    .\Copy-GeneXusAcervoToFront.ps1 -FrontFolder C:\Kb\ObjetosGeradosParaImportacaoNaKbNoGenexus\GtaP3_c34f_20260528 -AcervoFolder C:\Kb\ObjetosDaKbEmXml

.EXAMPLE
    # Seed inicial: copia objetos específicos do acervo para uma frente em que eles ainda
    # não existem. Seed só ocorre com alvo explicito (-ObjectList/-ObjectNames/-ObjectGuids);
    # sem alvo, nada e semeado e o status pode vir 'not-applicable'/objectsScanned:0 — esperado, não erro.
    .\Copy-GeneXusAcervoToFront.ps1 -FrontFolder C:\Kb\ObjetosGeradosParaImportacaoNaKbNoGenexus\GtaP3_c34f_20260528 -AcervoFolder C:\Kb\ObjetosDaKbEmXml -ObjectList 'Procedure:PReabastecerEstoque','SDT_Item'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FrontFolder,

    [Parameter(Mandatory = $true)]
    [string]$AcervoFolder,

    [string[]]$ObjectNames,

    [string[]]$ObjectList,

    [string[]]$ObjectGuids,

    [ValidateRange(1, 3600)]
    [int]$FreshnessMarginSeconds = 60,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

if ($null -ne $ObjectList -and $ObjectList.Count -gt 0) {
    $objectListNames = @($ObjectList | ForEach-Object {
        $item = [string]$_
        if ($item -match '^[^:]+:(?<name>.+)$') { $Matches['name'] } else { $item }
    })
    $ObjectNames = @($ObjectNames) + $objectListNames
}

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
        [string]$Action,
        [string]$FrontLastUpdateBefore,
        [string]$AcervoLastUpdate,
        [string]$FrontLastUpdateAfter
    )
    return [pscustomobject]@{
        severity             = $Severity
        code                 = $Code
        message              = $Message
        objectName           = $ObjectName
        objectGuid           = $ObjectGuid
        objectFile           = $ObjectFile
        acervoFile           = $AcervoFile
        action               = $Action
        frontLastUpdateBefore = $FrontLastUpdateBefore
        acervoLastUpdate     = $AcervoLastUpdate
        frontLastUpdateAfter = $FrontLastUpdateAfter
    }
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
    $objName = $root.GetAttribute('name')
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

function Find-AcervoObjectXmlByExplicitTarget {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [string]$ObjectName,
        [string]$ObjectGuid
    )
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return [pscustomobject]@{ Status = 'not-found'; Meta = $null; Candidates = @() }
    }

    $candidateFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    if (-not [string]::IsNullOrWhiteSpace($ObjectName)) {
        $found = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter "$ObjectName.xml" -ErrorAction SilentlyContinue)
        foreach ($f in $found) {
            $candidateFiles.Add($f) | Out-Null
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($ObjectGuid)) {
        $guidHits = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.xml' -ErrorAction SilentlyContinue |
            Select-String -SimpleMatch $ObjectGuid |
            ForEach-Object { $_.Path } |
            Sort-Object -Unique |
            ForEach-Object { Get-Item -LiteralPath $_ })
        foreach ($f in $guidHits) {
            $candidateFiles.Add($f) | Out-Null
        }
    }

    $matches = @()
    foreach ($file in @($candidateFiles | Sort-Object FullName -Unique)) {
        $meta = Get-ObjectMetadata $file.FullName
        if ($null -eq $meta) { continue }
        $matched = $false
        if (-not [string]::IsNullOrWhiteSpace($ObjectGuid) -and $meta.Guid -eq $ObjectGuid) {
            $matched = $true
        }
        if (-not $matched -and -not [string]::IsNullOrWhiteSpace($ObjectName) -and $meta.Name -eq $ObjectName) {
            $matched = $true
        }
        if ($matched) {
            $matches += $meta
        }
    }

    if ($matches.Count -eq 0) {
        return [pscustomobject]@{ Status = 'not-found'; Meta = $null; Candidates = @() }
    }
    if ($matches.Count -gt 1) {
        return [pscustomobject]@{ Status = 'ambiguous'; Meta = $null; Candidates = $matches }
    }
    return [pscustomobject]@{ Status = 'found'; Meta = $matches[0]; Candidates = $matches }
}

function Copy-AcervoMetaToFront {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$AcervoMeta,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [Parameter(Mandatory = $true)][string]$ActionCode,
        [Parameter(Mandatory = $true)][string]$DryRunCode,
        [Parameter(Mandatory = $true)][string]$MessagePrefix,
        [string]$FrontLastUpdateBefore = ''
    )

    if ($null -eq $AcervoMeta.LastUpdate) {
        $script:findings += New-Finding -Severity 'warn' -Code 'lastupdate-unparseable-skip' `
            -Message "Objeto '$($AcervoMeta.Name)' com lastUpdate do acervo nao parseavel; copia manual necessaria." `
            -ObjectName $AcervoMeta.Name -ObjectGuid $AcervoMeta.Guid `
            -ObjectFile ([System.IO.Path]::GetFileName($DestinationPath)) `
            -AcervoFile ([System.IO.Path]::GetRelativePath($AcervoFolder, $AcervoMeta.Path)) `
            -Action 'skip' `
            -FrontLastUpdateBefore $FrontLastUpdateBefore `
            -AcervoLastUpdate '' `
            -FrontLastUpdateAfter ''
        return
    }

    $aLastStr = Format-GeneXusLastUpdate $AcervoMeta.LastUpdate
    $aRel = [System.IO.Path]::GetRelativePath($AcervoFolder, $AcervoMeta.Path)
    $fRel = [System.IO.Path]::GetRelativePath($FrontFolder, $DestinationPath)

    $utcNow = [DateTime]::UtcNow
    $baseCandidate = $utcNow.AddSeconds($FreshnessMarginSeconds)
    $baselineCandidate = $AcervoMeta.LastUpdate.AddSeconds($FreshnessMarginSeconds)
    if ($baselineCandidate -gt $baseCandidate) {
        $baseCandidate = $baselineCandidate
    }
    $newLastUpdate = Format-GeneXusLastUpdate -Value $baseCandidate

    if ($DryRun) {
        $script:findings += New-Finding -Severity 'info' -Code $DryRunCode `
            -Message "DRY RUN: $MessagePrefix '$($AcervoMeta.Path)' -> '$DestinationPath' e bump lastUpdate de $aLastStr para $newLastUpdate." `
            -ObjectName $AcervoMeta.Name -ObjectGuid $AcervoMeta.Guid `
            -ObjectFile $fRel -AcervoFile $aRel `
            -Action $DryRunCode `
            -FrontLastUpdateBefore $FrontLastUpdateBefore -AcervoLastUpdate $aLastStr -FrontLastUpdateAfter $newLastUpdate
        return
    }

    Copy-Item -LiteralPath $AcervoMeta.Path -Destination $DestinationPath -Force

    $rawText = [System.IO.File]::ReadAllText($DestinationPath)
    $pattern = [regex]::new('lastUpdate="[^"]*"')
    $newText = $pattern.Replace($rawText, "lastUpdate=""$newLastUpdate""", 1)

    $utf8NoBom = (Get-Utf8NoBomEncoding)
    [System.IO.File]::WriteAllText($DestinationPath, $newText, $utf8NoBom)

    $script:findings += New-Finding -Severity 'info' -Code $ActionCode `
        -Message "Objeto '$($AcervoMeta.Name)' $MessagePrefix e bumpado: lastUpdate $aLastStr -> $newLastUpdate." `
        -ObjectName $AcervoMeta.Name -ObjectGuid $AcervoMeta.Guid `
        -ObjectFile $fRel -AcervoFile $aRel `
        -Action $ActionCode `
        -FrontLastUpdateBefore $FrontLastUpdateBefore -AcervoLastUpdate $aLastStr -FrontLastUpdateAfter $newLastUpdate
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
    throw "FRENTE_NAO_ABERTA: FrontFolder nao encontrado ou nao e diretorio: $FrontFolder. A frente deve ser aberta/retomada por New-GeneXusXpzFront.ps1 (wrapper local New-*KbFront.ps1) com -ReuseIfExists antes de popular; nao crie a pasta manualmente."
}
if (-not (Test-Path -LiteralPath $AcervoFolder -PathType Container)) {
    throw "AcervoFolder nao encontrado ou nao e diretorio: $AcervoFolder"
}
$FrontFolder  = (Resolve-Path -LiteralPath $FrontFolder).Path
$AcervoFolder = (Resolve-Path -LiteralPath $AcervoFolder).Path

# Sem dependencia de motor externo: o bump de lastUpdate e feito inline por
# Format-GeneXusLastUpdate / max(UtcNow + margin, acervoLastUpdate + margin)

# 1. Enumerar XMLs na pasta da frente
$findings = @()
$nameFilter = $null
if ($null -ne $ObjectNames -and $ObjectNames.Count -gt 0) {
    $nameFilter = @($ObjectNames | ForEach-Object { $_.ToLowerInvariant() })
}
$guidFilter = $null
if ($null -ne $ObjectGuids -and $ObjectGuids.Count -gt 0) {
    $guidFilter = @($ObjectGuids | ForEach-Object { $_.ToLowerInvariant() })
}
$explicitTargetsProvided = ($null -ne $nameFilter -and $nameFilter.Count -gt 0) -or ($null -ne $guidFilter -and $guidFilter.Count -gt 0)
$seededKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$frontXmls = @(Get-ChildItem -LiteralPath $FrontFolder -File -Filter '*.xml')
$frontMetas = @()
foreach ($xml in $frontXmls) {
    $meta = Get-ObjectMetadata $xml.FullName
    if ($null -ne $meta -and -not [string]::IsNullOrWhiteSpace($meta.Name)) {
        $frontMetas += $meta
    }
}

if ($frontMetas.Count -eq 0 -and $frontXmls.Count -eq 0) {
    $status = 'not-applicable'
} else {
    # 2. Para cada objeto da frente, buscar homonimo no acervo e copiar se mais recente
    foreach ($fMeta in $frontMetas) {
        # Aplicar filtros de nome/GUID se fornecidos
        if ($null -ne $nameFilter -and -not $nameFilter.Contains($fMeta.Name.ToLowerInvariant())) {
            continue
        }
        if ($null -ne $guidFilter -and -not $guidFilter.Contains($fMeta.Guid.ToLowerInvariant())) {
            continue
        }

        $fRel = [System.IO.Path]::GetRelativePath($FrontFolder, $fMeta.Path)
        $aMeta = Find-AcervoObjectXml -RootPath $AcervoFolder -FrontMeta $fMeta

        if ($null -eq $aMeta) {
            # Objeto novo, sem homonimo no acervo
            continue
        }

        $frontGuidNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $fMeta.Guid
        $acervoGuidNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $aMeta.Guid
        $frontTypeNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $fMeta.TypeGuid
        $acervoTypeNormalized = Normalize-GeneXusObjectTypeDriftValue -Value $aMeta.TypeGuid
        if (
            -not [string]::IsNullOrWhiteSpace($frontGuidNormalized) -and
            $frontGuidNormalized -eq $acervoGuidNormalized -and
            -not [string]::IsNullOrWhiteSpace($frontTypeNormalized) -and
            -not [string]::IsNullOrWhiteSpace($acervoTypeNormalized) -and
            $frontTypeNormalized -ne $acervoTypeNormalized
        ) {
            $findings += New-Finding -Severity 'fail' -Code 'front-object-type-drift-skip' `
                -Message "Objeto '$($fMeta.Name)' tem mesmo guid na frente e no acervo, mas Object/@type diverge (frente='$($fMeta.TypeGuid)', acervo='$($aMeta.TypeGuid)'). Copia automatica bloqueada; decisao humana requerida." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile ([System.IO.Path]::GetRelativePath($AcervoFolder, $aMeta.Path)) `
                -Action 'skip' `
                -FrontLastUpdateBefore $(if ($null -ne $fMeta.LastUpdate) { Format-GeneXusLastUpdate $fMeta.LastUpdate } else { '' }) `
                -AcervoLastUpdate $(if ($null -ne $aMeta.LastUpdate) { Format-GeneXusLastUpdate $aMeta.LastUpdate } else { '' }) `
                -FrontLastUpdateAfter ''
            continue
        }

        if ($null -eq $fMeta.LastUpdate -or $null -eq $aMeta.LastUpdate) {
            # lastUpdate não parseavel em um dos lados
            $findings += New-Finding -Severity 'warn' -Code 'lastupdate-unparseable-skip' `
                -Message "Objeto '$($fMeta.Name)' com lastUpdate nao parseavel; copia manual necessaria." `
                -ObjectName $fMeta.Name -ObjectGuid $fMeta.Guid `
                -ObjectFile $fRel -AcervoFile ([System.IO.Path]::GetRelativePath($AcervoFolder, $aMeta.Path)) `
                -Action 'skip' `
                -FrontLastUpdateBefore $(if ($null -ne $fMeta.LastUpdate) { Format-GeneXusLastUpdate $fMeta.LastUpdate } else { '' }) `
                -AcervoLastUpdate $(if ($null -ne $aMeta.LastUpdate) { Format-GeneXusLastUpdate $aMeta.LastUpdate } else { '' }) `
                -FrontLastUpdateAfter ''
            continue
        }

        if ($fMeta.LastUpdate -gt $aMeta.LastUpdate) {
            # Frente já e mais recente
            continue
        }

        # Frente e mais antiga ou igual: copiar do acervo e bumpar lastUpdate
        $fLastStr = Format-GeneXusLastUpdate $fMeta.LastUpdate
        $aLastStr = Format-GeneXusLastUpdate $aMeta.LastUpdate
        $aRel = [System.IO.Path]::GetRelativePath($AcervoFolder, $aMeta.Path)

        Copy-AcervoMetaToFront `
            -AcervoMeta $aMeta `
            -DestinationPath $fMeta.Path `
            -ActionCode 'copied-and-bumped' `
            -DryRunCode 'dry-run-copy' `
            -MessagePrefix 'copiado do acervo' `
            -FrontLastUpdateBefore $fLastStr
    }
}

# 3. Seed inicial para alvos explicitos que ainda não existem na frente
if ($explicitTargetsProvided) {
    $existingFrontNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $existingFrontGuids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($fMeta in $frontMetas) {
        if (-not [string]::IsNullOrWhiteSpace($fMeta.Name)) { [void]$existingFrontNames.Add($fMeta.Name) }
        if (-not [string]::IsNullOrWhiteSpace($fMeta.Guid)) { [void]$existingFrontGuids.Add($fMeta.Guid) }
    }

    foreach ($objectName in @($ObjectNames)) {
        if ([string]::IsNullOrWhiteSpace($objectName) -or $existingFrontNames.Contains($objectName)) { continue }
        $seedLookup = Find-AcervoObjectXmlByExplicitTarget -RootPath $AcervoFolder -ObjectName $objectName
        if ($seedLookup.Status -eq 'not-found') {
            $findings += New-Finding -Severity 'fail' -Code 'seed-target-not-found' `
                -Message "Seed solicitado para '$objectName', mas nenhum XML correspondente foi encontrado no acervo." `
                -ObjectName $objectName -ObjectGuid '' -ObjectFile '' -AcervoFile '' -Action 'seed-skip' `
                -FrontLastUpdateBefore '' -AcervoLastUpdate '' -FrontLastUpdateAfter ''
            continue
        }
        if ($seedLookup.Status -eq 'ambiguous') {
            $candidates = @($seedLookup.Candidates | ForEach-Object { [System.IO.Path]::GetRelativePath($AcervoFolder, $_.Path) })
            $findings += New-Finding -Severity 'fail' -Code 'seed-target-ambiguous' `
                -Message "Seed solicitado para '$objectName', mas o alvo e ambiguo no acervo: $($candidates -join ', ')." `
                -ObjectName $objectName -ObjectGuid '' -ObjectFile '' -AcervoFile '' -Action 'seed-skip' `
                -FrontLastUpdateBefore '' -AcervoLastUpdate '' -FrontLastUpdateAfter ''
            continue
        }
        $seedMeta = $seedLookup.Meta
        $seedKey = if (-not [string]::IsNullOrWhiteSpace($seedMeta.Guid)) { $seedMeta.Guid } else { $seedMeta.Name }
        if (-not $seededKeys.Add($seedKey)) { continue }
        $destinationPath = Join-Path $FrontFolder ([System.IO.Path]::GetFileName($seedMeta.Path))
        if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
            $findings += New-Finding -Severity 'fail' -Code 'seed-destination-exists' `
                -Message "Seed solicitado para '$($seedMeta.Name)', mas o destino ja existe: $destinationPath." `
                -ObjectName $seedMeta.Name -ObjectGuid $seedMeta.Guid -ObjectFile ([System.IO.Path]::GetFileName($destinationPath)) `
                -AcervoFile ([System.IO.Path]::GetRelativePath($AcervoFolder, $seedMeta.Path)) -Action 'seed-skip' `
                -FrontLastUpdateBefore '' -AcervoLastUpdate '' -FrontLastUpdateAfter ''
            continue
        }
        Copy-AcervoMetaToFront `
            -AcervoMeta $seedMeta `
            -DestinationPath $destinationPath `
            -ActionCode 'seeded-and-bumped' `
            -DryRunCode 'dry-run-seed' `
            -MessagePrefix 'semeado do acervo'
    }

    foreach ($objectGuid in @($ObjectGuids)) {
        if ([string]::IsNullOrWhiteSpace($objectGuid) -or $existingFrontGuids.Contains($objectGuid)) { continue }
        $seedLookup = Find-AcervoObjectXmlByExplicitTarget -RootPath $AcervoFolder -ObjectGuid $objectGuid
        if ($seedLookup.Status -eq 'not-found') {
            $findings += New-Finding -Severity 'fail' -Code 'seed-target-not-found' `
                -Message "Seed solicitado para GUID '$objectGuid', mas nenhum XML correspondente foi encontrado no acervo." `
                -ObjectName '' -ObjectGuid $objectGuid -ObjectFile '' -AcervoFile '' -Action 'seed-skip' `
                -FrontLastUpdateBefore '' -AcervoLastUpdate '' -FrontLastUpdateAfter ''
            continue
        }
        if ($seedLookup.Status -eq 'ambiguous') {
            $candidates = @($seedLookup.Candidates | ForEach-Object { [System.IO.Path]::GetRelativePath($AcervoFolder, $_.Path) })
            $findings += New-Finding -Severity 'fail' -Code 'seed-target-ambiguous' `
                -Message "Seed solicitado para GUID '$objectGuid', mas o alvo e ambiguo no acervo: $($candidates -join ', ')." `
                -ObjectName '' -ObjectGuid $objectGuid -ObjectFile '' -AcervoFile '' -Action 'seed-skip' `
                -FrontLastUpdateBefore '' -AcervoLastUpdate '' -FrontLastUpdateAfter ''
            continue
        }
        $seedMeta = $seedLookup.Meta
        $seedKey = if (-not [string]::IsNullOrWhiteSpace($seedMeta.Guid)) { $seedMeta.Guid } else { $seedMeta.Name }
        if (-not $seededKeys.Add($seedKey)) { continue }
        $destinationPath = Join-Path $FrontFolder ([System.IO.Path]::GetFileName($seedMeta.Path))
        if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
            $findings += New-Finding -Severity 'fail' -Code 'seed-destination-exists' `
                -Message "Seed solicitado para '$($seedMeta.Name)', mas o destino ja existe: $destinationPath." `
                -ObjectName $seedMeta.Name -ObjectGuid $seedMeta.Guid -ObjectFile ([System.IO.Path]::GetFileName($destinationPath)) `
                -AcervoFile ([System.IO.Path]::GetRelativePath($AcervoFolder, $seedMeta.Path)) -Action 'seed-skip' `
                -FrontLastUpdateBefore '' -AcervoLastUpdate '' -FrontLastUpdateAfter ''
            continue
        }
        Copy-AcervoMetaToFront `
            -AcervoMeta $seedMeta `
            -DestinationPath $destinationPath `
            -ActionCode 'seeded-and-bumped' `
            -DryRunCode 'dry-run-seed' `
            -MessagePrefix 'semeado do acervo'
    }
}

# 4. Status agregado
if ($findings.Count -eq 0 -and $frontMetas.Count -eq 0 -and $frontXmls.Count -eq 0 -and -not $explicitTargetsProvided) {
    $status = 'not-applicable'
} else {
    $hasFail = $findings | Where-Object { $_.severity -eq 'fail' } | Select-Object -First 1
    if ($hasFail) { $status = 'fail' } else { $status = 'pass' }
}

# 5. Emitir resultado
$result = [pscustomobject]@{
    status          = $status
    frontFolder     = $FrontFolder
    acervoFolder    = $AcervoFolder
    dryRun          = $DryRun.IsPresent
    objectsScanned  = $frontMetas.Count
    findings        = $findings
}

$result | ConvertTo-Json -Depth 6
