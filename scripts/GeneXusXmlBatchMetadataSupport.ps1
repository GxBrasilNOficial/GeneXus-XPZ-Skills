#requires -Version 7.4
<#
.SYNOPSIS
    Nucleo da edicao em lote de metadados de XML GeneXus dirigida por manifesto.

.DESCRIPTION
    Implementa o desenho congelado v10 (edit-genexus-xml-batch-metadata-design.md):
    separa a DECLARACAO (manifesto JSON) da EXECUCAO, e obriga a execucao a
    conferir a declaracao contra a realidade do XML antes de tocar em disco.

    Pontos que o desenho fixa e este arquivo implementa literalmente:

      - dois escopos lexicos nomeados (secao 6.0): A = intervalo da tag raiz;
        B = conteudo do elemento raiz EXCLUINDO subarvores <Object> aninhadas.
        A varredura pula CDATA, comentarios e instrucoes de processamento antes
        de contar profundidade; a contagem da ancora e a gravacao do patch
        acontecem no MESMO escopo;
      - lastUpdate composto pelo motor existente a partir de um baseline
        sintetico materializado em -WorkDir (secao 2.1), com a string do
        vencedor verbatim; leitura dos baselines por DOM, nunca por regex;
      - EOL: detector proprio de EOL misto (secao 5.0); o suporte de EOL
        existente entra so para o EOL das linhas novas; gravacao e de texto
        bruto pelo escritor atomico;
      - scanner de referencia a Domain com as tres grafias medidas (secao 7),
        case-insensitive com ancora de cultura explicita.

    Delta declarado frente a secao 10 do desenho: o codigo
    MANIFEST_SCHEMA_INVALID foi acrescentado a lista de bloqueios. A secao 4
    exige uma duzia de regras de schema fail-closed sem nomear um codigo para
    violacao de campo, e a secao 10 so previa MANIFEST_KIND_MISMATCH e
    MANIFEST_SCHEMA_UNSUPPORTED (Kind e SchemaVersion). Reusar
    MANIFEST_SCHEMA_UNSUPPORTED para violacao de campo confundiria "versao de
    schema nao suportada" com "campo invalido".

    Interpretacao declarada da regra de duplicidade (secao 4): "duplicidade por
    guid bloqueia globalmente" e lida como "o mesmo guid em mais de um xmlPath
    (ou duas vezes na mesma operacao)". A leitura literal alternativa - um guid
    so pode aparecer uma vez no manifesto inteiro - tornaria inexequivel a
    composicao da secao 4 (setDocumentation + setParent no MESMO arquivo), que
    o proprio desenho especifica com ordem deterministica.
#>

Set-StrictMode -Version Latest

$batchSupportDir = Split-Path -Parent $PSCommandPath
foreach ($dependency in @(
        'Utf8NoBomEncodingSupport.ps1',
        'GeneXusXmlSurgicalEditSupport.ps1',
        'XpzAtomicTextWriteSupport.ps1',
        'XpzProtectedAreaSupport.ps1',
        'XpzTextFileEolSupport.ps1',
        'GeneXusObjectTypeCatalogSupport.ps1')) {
    $dependencyPath = Join-Path $batchSupportDir $dependency
    if (-not (Test-Path -LiteralPath $dependencyPath -PathType Leaf)) {
        throw "Dependencia nao encontrada: $dependencyPath"
    }
    . $dependencyPath
}

# ---------------------------------------------------------------------------
# Constantes medidas no acervo (ver secoes 6 e 7 do desenho)
# ---------------------------------------------------------------------------

function Get-GeneXusDocumentationPartTypeGuid { return 'babf62c5-0111-49e9-a1c3-cc004d90900a' }
function Get-GeneXusFolderTypeGuid { return '00000000-0000-0000-0000-000000000008' }
function Get-GeneXusModuleTypeGuid { return '00000000-0000-0000-0000-000000000006' }
function Get-GeneXusDomainTypeGuid { return '00972a17-9975-449e-aab1-d26165d51393' }
function Get-GeneXusFrontCanonicalContainerName { return 'ObjetosGeradosParaImportacaoNaKbNoGenexus' }
function Get-GeneXusBatchManifestKind { return 'xpz-batch-metadata-manifest' }
function Get-GeneXusBatchManifestSchemaVersion { return 1 }
function Get-GeneXusBatchOperationOrder { return @('setDocumentation', 'setParent', 'renameDomain') }

# ---------------------------------------------------------------------------
# Utilitarios de leitura defensiva de JSON (StrictMode nao perdoa acesso a
# propriedade ausente em PSCustomObject)
# ---------------------------------------------------------------------------

function Test-GeneXusJsonProperty {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $Object) { return $false }
    if ($Object -isnot [psobject]) { return $false }
    return ($null -ne $Object.PSObject.Properties[$Name])
}

function Get-GeneXusJsonProperty {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [object]$Default = $null
    )

    if (-not (Test-GeneXusJsonProperty -Object $Object -Name $Name)) { return $Default }
    return $Object.PSObject.Properties[$Name].Value
}

function Get-GeneXusJsonPropertyNames {
    param([object]$Object)

    if ($null -eq $Object -or $Object -isnot [psobject]) { return @() }
    return @($Object.PSObject.Properties | ForEach-Object { $_.Name })
}

# ---------------------------------------------------------------------------
# EOL (secao 5.0)
# ---------------------------------------------------------------------------

function Get-GeneXusTextEolProfile {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $crlf = 0
    $loneLf = 0
    $loneCr = 0
    $length = $Text.Length
    $i = 0
    while ($i -lt $length) {
        $current = $Text[$i]
        if ($current -eq "`r") {
            if (($i + 1) -lt $length -and $Text[$i + 1] -eq "`n") {
                $crlf++
                $i += 2
                continue
            }
            $loneCr++
        } elseif ($current -eq "`n") {
            $loneLf++
        }
        $i++
    }

    $mixed = $false
    if ($crlf -gt 0 -and ($loneLf -gt 0 -or $loneCr -gt 0)) { $mixed = $true }
    if ($loneLf -gt 0 -and $loneCr -gt 0) { $mixed = $true }

    $eol = "`n"
    if ($crlf -gt 0) {
        $eol = "`r`n"
    } elseif ($loneCr -gt 0 -and $loneLf -eq 0) {
        $eol = "`r"
    }

    return [pscustomobject]@{
        Eol        = $eol
        Mixed      = $mixed
        CrLfCount  = $crlf
        LoneLfCount = $loneLf
        LoneCrCount = $loneCr
    }
}

function ConvertTo-GeneXusPayloadWithEol {
    <#
        Normaliza o payload vindo do manifesto JSON (que carrega \n) para o EOL
        do arquivo alvo. \r solto e RECUSADO, nunca normalizado em silencio.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Eol
    )

    $length = $Text.Length
    for ($i = 0; $i -lt $length; $i++) {
        if ($Text[$i] -ne "`r") { continue }
        if (($i + 1) -ge $length -or $Text[$i + 1] -ne "`n") {
            return [pscustomobject]@{
                Valid  = $false
                Text   = $null
                Reason = "payload contem CR solto na posicao $i"
            }
        }
        $i++
    }

    $normalized = $Text.Replace("`r`n", "`n")
    if ($Eol -ne "`n") {
        $normalized = $normalized.Replace("`n", $Eol)
    }

    return [pscustomobject]@{
        Valid  = $true
        Text   = $normalized
        Reason = $null
    }
}

# ---------------------------------------------------------------------------
# Varredura lexica (secao 6.0): eventos de elemento com profundidade,
# pulando CDATA, comentarios e instrucoes de processamento.
# ---------------------------------------------------------------------------

function Get-GeneXusXmlElementEvents {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$ElementName,
        [int]$From = 0,
        [int]$To = -1
    )

    $length = $Text.Length
    $limit = $To
    if ($limit -lt 0 -or $limit -gt $length) { $limit = $length }

    $events = [System.Collections.Generic.List[object]]::new()
    # regioes nao-markup (CDATA, comentario, instrucao de processamento): a
    # varredura as pula para contar profundidade, e o chamador as usa para
    # descartar ocorrencia de ancora que caia dentro delas - texto em CDATA nao
    # e elemento.
    $skips = [System.Collections.Generic.List[object]]::new()
    $depth = 0
    $i = $From

    while ($i -lt $limit) {
        $lt = $Text.IndexOf('<', $i)
        if ($lt -lt 0 -or $lt -ge $limit) { break }

        if (($lt + 4) -le $length -and $Text.Substring($lt, 4) -eq '<!--') {
            $end = $Text.IndexOf('-->', $lt + 4, [StringComparison]::Ordinal)
            if ($end -lt 0) { return [pscustomobject]@{ Ok = $false; Events = @(); Skips = @() } }
            [void]$skips.Add([pscustomobject]@{ Start = $lt; End = $end + 2 })
            $i = $end + 3
            continue
        }
        if (($lt + 9) -le $length -and $Text.Substring($lt, 9) -eq '<![CDATA[') {
            $end = $Text.IndexOf(']]>', $lt + 9, [StringComparison]::Ordinal)
            if ($end -lt 0) { return [pscustomobject]@{ Ok = $false; Events = @(); Skips = @() } }
            [void]$skips.Add([pscustomobject]@{ Start = $lt; End = $end + 2 })
            $i = $end + 3
            continue
        }
        if (($lt + 2) -le $length -and $Text.Substring($lt, 2) -eq '<?') {
            $end = $Text.IndexOf('?>', $lt + 2, [StringComparison]::Ordinal)
            if ($end -lt 0) { return [pscustomobject]@{ Ok = $false; Events = @(); Skips = @() } }
            [void]$skips.Add([pscustomobject]@{ Start = $lt; End = $end + 1 })
            $i = $end + 2
            continue
        }
        if (($lt + 2) -le $length -and $Text.Substring($lt, 2) -eq '<!') {
            $end = $Text.IndexOf('>', $lt + 2)
            if ($end -lt 0) { return [pscustomobject]@{ Ok = $false; Events = @(); Skips = @() } }
            [void]$skips.Add([pscustomobject]@{ Start = $lt; End = $end })
            $i = $end + 1
            continue
        }

        $isClose = (($lt + 1) -lt $length -and $Text[$lt + 1] -eq '/')
        $nameStart = $lt + 1
        if ($isClose) { $nameStart = $lt + 2 }

        $nameEnd = $nameStart
        while ($nameEnd -lt $length) {
            $c = $Text[$nameEnd]
            if ([char]::IsLetterOrDigit($c) -or $c -eq '_' -or $c -eq '-' -or $c -eq '.' -or $c -eq ':') {
                $nameEnd++
                continue
            }
            break
        }
        if ($nameEnd -eq $nameStart) {
            $i = $lt + 1
            continue
        }
        $name = $Text.Substring($nameStart, $nameEnd - $nameStart)

        # avanca ate o '>' que fecha a tag, respeitando aspas
        $cursor = $nameEnd
        $quote = [char]0
        $tagEnd = -1
        while ($cursor -lt $length) {
            $c = $Text[$cursor]
            if ($quote -ne [char]0) {
                if ($c -eq $quote) { $quote = [char]0 }
            } elseif ($c -eq '"' -or $c -eq "'") {
                $quote = $c
            } elseif ($c -eq '>') {
                $tagEnd = $cursor
                break
            }
            $cursor++
        }
        if ($tagEnd -lt 0) { return [pscustomobject]@{ Ok = $false; Events = @(); Skips = @() } }

        $selfClosing = ($Text[$tagEnd - 1] -eq '/')

        if ([string]::Equals($name, $ElementName, [StringComparison]::Ordinal)) {
            if ($isClose) {
                $depth--
                [void]$events.Add([pscustomobject]@{ Kind = 'close'; Start = $lt; TagEnd = $tagEnd; Depth = $depth })
            } elseif ($selfClosing) {
                [void]$events.Add([pscustomobject]@{ Kind = 'selfclose'; Start = $lt; TagEnd = $tagEnd; Depth = $depth })
            } else {
                [void]$events.Add([pscustomobject]@{ Kind = 'open'; Start = $lt; TagEnd = $tagEnd; Depth = $depth })
                $depth++
            }
        }

        $i = $tagEnd + 1
    }

    return [pscustomobject]@{ Ok = $true; Events = @($events); Skips = @($skips) }
}

function Get-GeneXusXmlObjectScopes {
    <#
        Devolve os dois escopos do desenho:
          A = [RootTagStart .. RootTagEnd] (o '>' que fecha a tag raiz)
          B = conteudo do elemento raiz MENOS as subarvores <Object> aninhadas,
              como lista de regioes [Start, End] inclusivas.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$ElementName = 'Object'
    )

    $scan = Get-GeneXusXmlElementEvents -Text $Text -ElementName $ElementName
    if (-not $scan.Ok) {
        return [pscustomobject]@{ Valid = $false; Reason = 'MARKUP_UNTERMINATED'; RootCount = 0 }
    }
    $events = @($scan.Events)
    $skipRegions = @($scan.Skips)

    $rootOpens = @($events | Where-Object { $_.Depth -eq 0 -and ($_.Kind -eq 'open' -or $_.Kind -eq 'selfclose') })
    if ($rootOpens.Count -eq 0) {
        return [pscustomobject]@{ Valid = $false; Reason = 'ROOT_NOT_FOUND'; RootCount = 0 }
    }
    if ($rootOpens.Count -gt 1) {
        return [pscustomobject]@{ Valid = $false; Reason = 'MULTIPLE_ROOTS'; RootCount = $rootOpens.Count }
    }

    $root = $rootOpens[0]
    if ($root.Kind -eq 'selfclose') {
        return [pscustomobject]@{
            Valid        = $true
            Reason       = $null
            RootCount    = 1
            RootTagStart = $root.Start
            RootTagEnd   = $root.TagEnd
            ContentStart = -1
            ContentEnd   = -1
            RootEnd      = $root.TagEnd
            ScopeBRegions = @()
            NestedRanges  = @()
            SkipRegions   = @($skipRegions)
        }
    }

    $rootClose = $null
    foreach ($ev in $events) {
        if ($ev.Kind -eq 'close' -and $ev.Depth -eq 0 -and $ev.Start -gt $root.Start) {
            $rootClose = $ev
            break
        }
    }
    if ($null -eq $rootClose) {
        return [pscustomobject]@{ Valid = $false; Reason = 'ROOT_NOT_CLOSED'; RootCount = 1 }
    }

    $contentStart = $root.TagEnd + 1
    $contentEnd = $rootClose.Start - 1

    $nested = [System.Collections.Generic.List[object]]::new()
    $pendingStart = -1
    foreach ($ev in $events) {
        if ($ev.Start -le $root.Start -or $ev.Start -ge $rootClose.Start) { continue }
        if ($ev.Kind -eq 'selfclose' -and $ev.Depth -eq 1) {
            [void]$nested.Add([pscustomobject]@{ Start = $ev.Start; End = $ev.TagEnd })
            continue
        }
        if ($ev.Kind -eq 'open' -and $ev.Depth -eq 1) {
            if ($pendingStart -lt 0) { $pendingStart = $ev.Start }
            continue
        }
        if ($ev.Kind -eq 'close' -and $ev.Depth -eq 1 -and $pendingStart -ge 0) {
            [void]$nested.Add([pscustomobject]@{ Start = $pendingStart; End = $ev.TagEnd })
            $pendingStart = -1
        }
    }

    $regions = [System.Collections.Generic.List[object]]::new()
    $cursor = $contentStart
    foreach ($range in $nested) {
        if ($range.Start -gt $cursor) {
            [void]$regions.Add([pscustomobject]@{ Start = $cursor; End = $range.Start - 1 })
        }
        if (($range.End + 1) -gt $cursor) { $cursor = $range.End + 1 }
    }
    if ($cursor -le $contentEnd) {
        [void]$regions.Add([pscustomobject]@{ Start = $cursor; End = $contentEnd })
    }

    return [pscustomobject]@{
        Valid         = $true
        Reason        = $null
        RootCount     = 1
        RootTagStart  = $root.Start
        RootTagEnd    = $root.TagEnd
        ContentStart  = $contentStart
        ContentEnd    = $contentEnd
        RootEnd       = $rootClose.TagEnd
        ScopeBRegions = @($regions)
        NestedRanges  = @($nested)
        SkipRegions   = @($skipRegions)
    }
}

function Get-GeneXusXmlElementRange {
    <#
        Extensao de um elemento a partir da posicao da sua tag de abertura.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$OpenTagStart,
        [Parameter(Mandatory = $true)][string]$ElementName,
        [int]$Limit = -1
    )

    $scan = Get-GeneXusXmlElementEvents -Text $Text -ElementName $ElementName -From $OpenTagStart -To $Limit
    if (-not $scan.Ok) { return $null }
    $events = @($scan.Events)
    if ($events.Count -eq 0) { return $null }

    $open = $events[0]
    if ($open.Start -ne $OpenTagStart) { return $null }
    if ($open.Kind -eq 'selfclose') {
        return [pscustomobject]@{
            OpenTagStart = $open.Start
            OpenTagEnd   = $open.TagEnd
            SelfClosing  = $true
            ContentStart = -1
            ContentEnd   = -1
            ElementEnd   = $open.TagEnd
        }
    }
    if ($open.Kind -ne 'open') { return $null }

    foreach ($ev in $events) {
        if ($ev.Kind -eq 'close' -and $ev.Depth -eq 0 -and $ev.Start -gt $open.Start) {
            return [pscustomobject]@{
                OpenTagStart = $open.Start
                OpenTagEnd   = $open.TagEnd
                SelfClosing  = $false
                ContentStart = $open.TagEnd + 1
                ContentEnd   = $ev.Start - 1
                ElementEnd   = $ev.TagEnd
            }
        }
    }
    return $null
}

function Get-GeneXusRegionOccurrenceIndexes {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Regions,
        [Parameter(Mandatory = $true)][string]$Anchor,

        # Regioes nao-markup (CDATA, comentario, instrucao de processamento).
        # Ocorrencia que COMECA dentro de uma delas nao e elemento - e texto - e
        # nao conta. Sem isso, um '<Part type="babf62c5-...">' escrito dentro de
        # um <Source> daria ANCHOR_AMBIGUOUS num arquivo perfeitamente operavel.
        [AllowEmptyCollection()][object[]]$SkipRegions = @()
    )

    $found = [System.Collections.Generic.List[int]]::new()
    if ([string]::IsNullOrEmpty($Anchor)) { return @($found) }

    foreach ($region in $Regions) {
        $cursor = $region.Start
        while ($cursor -le $region.End) {
            $index = $Text.IndexOf($Anchor, $cursor, [StringComparison]::Ordinal)
            if ($index -lt 0) { break }
            if (($index + $Anchor.Length - 1) -gt $region.End) { break }
            $inSkip = $false
            foreach ($skip in @($SkipRegions)) {
                if ($index -ge $skip.Start -and $index -le $skip.End) { $inSkip = $true; break }
            }
            if (-not $inSkip) { [void]$found.Add($index) }
            $cursor = $index + 1
        }
    }
    return @($found)
}

function Invoke-GeneXusScopedLiteralPatch {
    <#
        Chama o primitivo compartilhado sobre a SUBSTRING do escopo e rejunta o
        resultado ao texto completo pelos offsets. A contagem ja foi feita no
        mesmo escopo pelo chamador.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$RegionStart,
        [Parameter(Mandatory = $true)][int]$RegionEnd,
        [Parameter(Mandatory = $true)][string]$Anchor,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Replacement,
        [Parameter(Mandatory = $true)][ValidateSet('Replace', 'InsertAfter', 'InsertBefore')][string]$EditMode
    )

    $segment = $Text.Substring($RegionStart, $RegionEnd - $RegionStart + 1)
    $patchedSegment = Invoke-GeneXusXmlLiteralPatch -Text $segment -Anchor $Anchor -Replacement $Replacement -EditMode $EditMode
    $anchorIndexInSegment = $segment.IndexOf($Anchor, [StringComparison]::Ordinal)
    $absoluteAnchorIndex = $RegionStart + $anchorIndexInSegment

    $mutatedStart = $absoluteAnchorIndex
    $mutatedLengthBefore = $Anchor.Length
    if ($EditMode -eq 'InsertAfter') {
        $mutatedStart = $absoluteAnchorIndex + $Anchor.Length
        $mutatedLengthBefore = 0
    } elseif ($EditMode -eq 'InsertBefore') {
        $mutatedLengthBefore = 0
    }

    return [pscustomobject]@{
        Text               = $Text.Substring(0, $RegionStart) + $patchedSegment + $Text.Substring($RegionEnd + 1)
        MutatedStart       = $mutatedStart
        MutatedLengthBefore = $mutatedLengthBefore
        MutatedLengthAfter = $Replacement.Length
    }
}

# ---------------------------------------------------------------------------
# Leitura estrutural (parse valida; nao delimita)
# ---------------------------------------------------------------------------

function Get-GeneXusObjectRootInfo {
    param([Parameter(Mandatory = $true)][string]$Text)

    try {
        $doc = New-Object System.Xml.XmlDocument
        $doc.PreserveWhitespace = $true
        $doc.LoadXml($Text)
    } catch {
        return [pscustomobject]@{ Valid = $false; Reason = "XML_NOT_WELLFORMED: $($_.Exception.Message)" }
    }

    $root = $doc.DocumentElement
    if ($null -eq $root) {
        return [pscustomobject]@{ Valid = $false; Reason = 'XML_NO_ROOT_ELEMENT' }
    }

    $attributes = [ordered]@{}
    foreach ($name in @('guid', 'name', 'type', 'description', 'fullyQualifiedName', 'moduleGuid', 'parent', 'parentGuid', 'parentType', 'lastUpdate', 'checksum')) {
        if ($root.HasAttribute($name)) {
            $attributes[$name] = $root.GetAttribute($name)
        } else {
            $attributes[$name] = $null
        }
    }

    return [pscustomobject]@{
        Valid      = $true
        Reason     = $null
        RootName   = $root.LocalName
        Attributes = $attributes
        Document   = $doc
    }
}

function ConvertTo-GeneXusLastUpdateInstant {
    param([AllowNull()][AllowEmptyString()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{ Present = $false; Parsed = $false; Instant = $null; Raw = $Value }
    }
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse(
        $Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal,
        [ref]$parsed)
    if (-not $ok) {
        return [pscustomobject]@{ Present = $true; Parsed = $false; Instant = $null; Raw = $Value }
    }
    return [pscustomobject]@{ Present = $true; Parsed = $true; Instant = $parsed; Raw = $Value }
}

# ---------------------------------------------------------------------------
# lastUpdate: composicao dos baselines (secao 2.1)
# ---------------------------------------------------------------------------

function New-GeneXusSyntheticBaselineXml {
    <#
        Materializa o XML de baseline sintetico com a STRING ORIGINAL do
        vencedor, verbatim. Nunca uma reformatacao do DateTimeOffset parseado -
        reformatar duplicaria a string de formato no chamador, que e o motivo
        pelo qual "calcular no chamador" foi rejeitado.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$LastUpdateVerbatim,
        [Parameter(Mandatory = $true)][string]$TempDir
    )

    $escaped = [System.Security.SecurityElement]::Escape($LastUpdateVerbatim)
    $xml = '<?xml version="1.0" encoding="utf-8"?>' + "`r`n" + '<Object lastUpdate="' + $escaped + '" />' + "`r`n"
    [void](Write-XpzTextFileAtomic -Path $Path -Text $xml -TempDir $TempDir -ReplaceExisting)
    return $Path
}

function Resolve-GeneXusBatchLastUpdateBaseline {
    <#
        Parse-then-compare dos dois baselines (alvo na frente e arquivo do
        acervo). Devolve qual venceu e a string verbatim do vencedor.
    #>
    param(
        [AllowNull()][string]$FrontLastUpdateRaw,
        [AllowNull()][string]$AcervoLastUpdateRaw
    )

    $front = ConvertTo-GeneXusLastUpdateInstant -Value $FrontLastUpdateRaw
    $acervo = ConvertTo-GeneXusLastUpdateInstant -Value $AcervoLastUpdateRaw

    if ($front.Present -and -not $front.Parsed) {
        return [pscustomobject]@{ Status = 'UNREADABLE'; Source = 'front'; Verbatim = $FrontLastUpdateRaw }
    }
    if ($acervo.Present -and -not $acervo.Parsed) {
        return [pscustomobject]@{ Status = 'UNREADABLE'; Source = 'acervo'; Verbatim = $AcervoLastUpdateRaw }
    }

    if ($front.Parsed -and $acervo.Parsed) {
        if ($acervo.Instant -gt $front.Instant) {
            return [pscustomobject]@{ Status = 'OK'; Source = 'acervo'; Verbatim = $AcervoLastUpdateRaw; Instant = $acervo.Instant }
        }
        return [pscustomobject]@{ Status = 'OK'; Source = 'front'; Verbatim = $FrontLastUpdateRaw; Instant = $front.Instant }
    }
    if ($front.Parsed) {
        return [pscustomobject]@{ Status = 'OK'; Source = 'front'; Verbatim = $FrontLastUpdateRaw; Instant = $front.Instant }
    }
    if ($acervo.Parsed) {
        return [pscustomobject]@{ Status = 'OK'; Source = 'acervo'; Verbatim = $AcervoLastUpdateRaw; Instant = $acervo.Instant }
    }

    # Ambos ausentes: ramo sem baseline (secao 2.1-bis).
    return [pscustomobject]@{ Status = 'NO_BASELINE'; Source = 'none'; Verbatim = $null; Instant = $null }
}

function Get-GeneXusEnvelopeFutureToleranceDefault {
    <#
        Le o default de -FutureToleranceSeconds do CONTRATO do envelope, via
        AST, em vez de repetir o numero como constante magica (secao 9.1).
    #>
    param([string]$EnvelopePath)

    if ([string]::IsNullOrWhiteSpace($EnvelopePath)) {
        $EnvelopePath = Join-Path $batchSupportDir 'Build-GeneXusImportFileEnvelope.ps1'
    }
    if (-not (Test-Path -LiteralPath $EnvelopePath -PathType Leaf)) {
        throw "Build-GeneXusImportFileEnvelope.ps1 nao encontrado: $EnvelopePath"
    }

    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($EnvelopePath, [ref]$null, [ref]$errors)
    if ($null -ne $errors -and $errors.Count -gt 0) {
        throw "Build-GeneXusImportFileEnvelope.ps1 nao parseia; nao da para ler o contrato de tolerancia de futuro."
    }
    $paramBlock = $ast.ParamBlock
    if ($null -eq $paramBlock) {
        throw 'Build-GeneXusImportFileEnvelope.ps1 sem bloco param.'
    }
    foreach ($parameter in $paramBlock.Parameters) {
        if ($parameter.Name.VariablePath.UserPath -ne 'FutureToleranceSeconds') { continue }
        if ($null -eq $parameter.DefaultValue) {
            throw 'FutureToleranceSeconds sem valor default no envelope.'
        }
        return [int]$parameter.DefaultValue.SafeGetValue()
    }
    throw 'Build-GeneXusImportFileEnvelope.ps1 nao expoe -FutureToleranceSeconds.'
}

# ---------------------------------------------------------------------------
# Acentuacao (secao 8): reusa a wordlist e a taxonomia, nao o script
# ---------------------------------------------------------------------------

function Get-GeneXusAccentDetector {
    param([string]$WordlistPath)

    if ([string]::IsNullOrWhiteSpace($WordlistPath)) {
        $WordlistPath = Join-Path $batchSupportDir 'ptbr-accent-wordlist.json'
    }
    if (-not (Test-Path -LiteralPath $WordlistPath -PathType Leaf)) {
        throw "Wordlist de acentuacao nao encontrada: $WordlistPath"
    }

    $wordlist = [System.IO.File]::ReadAllText($WordlistPath) | ConvertFrom-Json
    $correctMap = @{}
    $asciiForms = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $wordlist.entries) {
        $correctMap[$entry.a.ToLowerInvariant()] = $entry.c
        [void]$asciiForms.Add([regex]::Escape($entry.a))
    }

    $boundaryBefore = '(?<![\w/\\\-_])'
    $boundaryAfter = '(?![\w/\\\-_])'
    $pattern = $boundaryBefore + '(' + ($asciiForms -join '|') + ')' + $boundaryAfter
    $regex = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    # Mojibake: UTF-8 lido como Latin-1. Segunda classe sobre o mesmo vocabulario.
    $mojibakeRegex = [regex]::new('(Ã[-¿]|Â[-¿]|â[-])')

    return [pscustomobject]@{
        Regex         = $regex
        MojibakeRegex = $mojibakeRegex
        CorrectMap    = $correctMap
        WordlistPath  = (Get-XpzCanonicalPath -Path $WordlistPath)
        EntryCount    = @($wordlist.entries).Count
    }
}

function Measure-GeneXusAccentDegradation {
    param(
        [Parameter(Mandatory = $true)][object]$Detector,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    if ([string]::IsNullOrEmpty($Text)) { return @($findings) }

    foreach ($match in $Detector.Regex.Matches($Text)) {
        $word = $match.Value
        $correct = $null
        $key = $word.ToLowerInvariant()
        if ($Detector.CorrectMap.ContainsKey($key)) { $correct = $Detector.CorrectMap[$key] }
        [void]$findings.Add([pscustomobject]@{
            kind    = 'missing-accent'
            word    = $word
            correct = $correct
            index   = $match.Index
        })
    }
    foreach ($match in $Detector.MojibakeRegex.Matches($Text)) {
        [void]$findings.Add([pscustomobject]@{
            kind    = 'mojibake'
            word    = $match.Value
            correct = $null
            index   = $match.Index
        })
    }

    return @($findings)
}

# ---------------------------------------------------------------------------
# Manifesto (secao 4)
# ---------------------------------------------------------------------------

function Test-GeneXusJsonDuplicateKey {
    <#
        Detector proprio: caminha objetos E arrays. O detector do catalogo so
        visita objetos, e o manifesto tem as operacoes dentro de um array.
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $document = $null
    try {
        $document = [System.Text.Json.JsonDocument]::Parse([System.IO.File]::ReadAllText($Path))
    } catch {
        return [pscustomobject]@{ Found = $true; Reason = 'invalid-json'; FieldPath = '$'; Message = $_.Exception.Message }
    }

    $stack = [System.Collections.Generic.Stack[object]]::new()
    $stack.Push([pscustomobject]@{ Element = $document.RootElement; Path = '$' })
    $result = [pscustomobject]@{ Found = $false; Reason = $null; FieldPath = $null; Message = $null }
    try {
        while ($stack.Count -gt 0) {
            $node = $stack.Pop()
            $element = $node.Element
            if ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
                $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                foreach ($property in $element.EnumerateObject()) {
                    if (-not $seen.Add($property.Name)) {
                        return [pscustomobject]@{
                            Found     = $true
                            Reason    = 'duplicate-json-key'
                            FieldPath = $node.Path
                            Message   = "Chave JSON duplicada '$($property.Name)' em $($node.Path)."
                        }
                    }
                    $stack.Push([pscustomobject]@{ Element = $property.Value; Path = "$($node.Path).$($property.Name)" })
                }
            } elseif ($element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
                $index = 0
                foreach ($item in $element.EnumerateArray()) {
                    $stack.Push([pscustomobject]@{ Element = $item; Path = "$($node.Path)[$index]" })
                    $index++
                }
            }
        }
    } finally {
        $document.Dispose()
    }
    return $result
}

function New-GeneXusBatchBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$OpId,
        [string]$Path,
        [object]$Detail
    )

    return [ordered]@{
        code    = $Code
        message = $Message
        opId    = $OpId
        path    = $Path
        detail  = $Detail
    }
}

function New-GeneXusBatchWarning {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$OpId,
        [string]$Path,
        [object]$Detail
    )

    return [ordered]@{
        kind    = $Kind
        message = $Message
        opId    = $OpId
        path    = $Path
        detail  = $Detail
    }
}

function Read-GeneXusBatchManifest {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{
            Valid  = $false
            Blocks = @((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message "manifesto nao encontrado: $Path" -Path $Path))
        }
    }

    $duplicate = Test-GeneXusJsonDuplicateKey -Path $Path
    if ($duplicate.Found) {
        return [pscustomobject]@{
            Valid  = $false
            Blocks = @((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message $duplicate.Message -Path $Path -Detail $duplicate.Reason))
        }
    }

    $manifest = $null
    try {
        $manifest = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json -Depth 40
    } catch {
        return [pscustomobject]@{
            Valid  = $false
            Blocks = @((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message "manifesto nao e JSON valido: $($_.Exception.Message)" -Path $Path))
        }
    }

    $kind = [string](Get-GeneXusJsonProperty -Object $manifest -Name 'Kind')
    if ($kind -ne (Get-GeneXusBatchManifestKind)) {
        return [pscustomobject]@{
            Valid  = $false
            Blocks = @((New-GeneXusBatchBlock -Code 'MANIFEST_KIND_MISMATCH' -Message "Kind inesperado: '$kind'; esperado '$(Get-GeneXusBatchManifestKind)'." -Path $Path))
        }
    }

    $schemaVersionRaw = Get-GeneXusJsonProperty -Object $manifest -Name 'SchemaVersion'
    $schemaVersion = -1
    if ($null -ne $schemaVersionRaw) { $schemaVersion = [int]$schemaVersionRaw }
    if ($schemaVersion -ne (Get-GeneXusBatchManifestSchemaVersion)) {
        return [pscustomobject]@{
            Valid  = $false
            Blocks = @((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_UNSUPPORTED' -Message "SchemaVersion inesperada: '$schemaVersionRaw'; esperada $(Get-GeneXusBatchManifestSchemaVersion)." -Path $Path))
        }
    }

    return [pscustomobject]@{ Valid = $true; Blocks = @(); Manifest = $manifest }
}

function Test-GeneXusBatchManifestOperations {
    param(
        [Parameter(Mandatory = $true)][object]$Manifest,
        [Parameter(Mandatory = $true)][object]$Catalog,
        [bool]$AllowDegradedAccentsSwitch
    )

    $blocks = [System.Collections.Generic.List[object]]::new()
    $operations = [System.Collections.Generic.List[object]]::new()

    $rawOperations = Get-GeneXusJsonProperty -Object $Manifest -Name 'operations'
    if ($null -eq $rawOperations) {
        [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'manifesto sem a lista operations.'))
        return [pscustomobject]@{ Blocks = @($blocks); Operations = @() }
    }
    $rawOperations = @($rawOperations)

    $knownTypeNames = @(Get-GeneXusJsonPropertyNames -Object $Catalog.types)
    $supportedOps = Get-GeneXusBatchOperationOrder
    $seenIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $pathByTypeAndPath = @{}
    $guidToPaths = @{}
    $pathToGuids = @{}

    $index = -1
    foreach ($raw in $rawOperations) {
        $index++
        $opId = [string](Get-GeneXusJsonProperty -Object $raw -Name 'id' -Default "op[$index]")
        $op = [string](Get-GeneXusJsonProperty -Object $raw -Name 'op')
        $objectState = [string](Get-GeneXusJsonProperty -Object $raw -Name 'objectState')
        $target = Get-GeneXusJsonProperty -Object $raw -Name 'target'

        if (-not $seenIds.Add($opId)) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'DUPLICATE_OPERATION' -Message "id de operacao repetido: '$opId'." -OpId $opId))
        }

        if ($supportedOps -notcontains $op) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'UNSUPPORTED_OPERATION' -Message "operacao nao suportada: '$op'." -OpId $opId))
            continue
        }
        if (@('existing', 'new') -notcontains $objectState) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message "objectState invalido ou ausente: '$objectState'." -OpId $opId))
            continue
        }
        if ($op -eq 'renameDomain' -and $objectState -eq 'new') {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'UNSUPPORTED_OPERATION' -Message 'renameDomain com objectState new e proibido.' -OpId $opId))
            continue
        }

        $guid = [string](Get-GeneXusJsonProperty -Object $target -Name 'guid')
        $expectedType = [string](Get-GeneXusJsonProperty -Object $target -Name 'expectedType')
        $expectedName = [string](Get-GeneXusJsonProperty -Object $target -Name 'expectedName')
        $xmlPath = [string](Get-GeneXusJsonProperty -Object $target -Name 'xmlPath')

        $parsedGuid = [Guid]::Empty
        if ([string]::IsNullOrWhiteSpace($guid) -or -not [Guid]::TryParse($guid, [ref]$parsedGuid)) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message "target.guid ausente ou invalido: '$guid'." -OpId $opId))
            continue
        }
        foreach ($pair in @(
                @{ Name = 'expectedType'; Value = $expectedType },
                @{ Name = 'expectedName'; Value = $expectedName },
                @{ Name = 'xmlPath'; Value = $xmlPath })) {
            if ([string]::IsNullOrWhiteSpace($pair.Value)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message "target.$($pair.Name) ausente." -OpId $opId))
            }
        }
        if ([string]::IsNullOrWhiteSpace($expectedType) -or [string]::IsNullOrWhiteSpace($expectedName) -or [string]::IsNullOrWhiteSpace($xmlPath)) {
            continue
        }

        if ($knownTypeNames -notcontains $expectedType) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'TYPE_NOT_IN_CATALOG' -Message "expectedType fora do catalogo: '$expectedType'." -OpId $opId))
            continue
        }

        $hasExpected = Test-GeneXusJsonProperty -Object $raw -Name 'expected'
        if ($objectState -eq 'existing' -and -not $hasExpected) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'expected e obrigatorio em objectState existing.' -OpId $opId))
            continue
        }
        if ($objectState -eq 'new' -and $hasExpected) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'expected e proibido em objectState new.' -OpId $opId))
            continue
        }

        $allowDegraded = [bool](Get-GeneXusJsonProperty -Object $raw -Name 'allowDegradedAccents' -Default $false)
        if ($allowDegraded -and -not $AllowDegradedAccentsSwitch) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'allowDegradedAccents so e aceita quando -AllowDegradedAccents foi passado.' -OpId $opId))
            continue
        }

        $newBlock = Get-GeneXusJsonProperty -Object $raw -Name 'new'
        $expectedBlock = Get-GeneXusJsonProperty -Object $raw -Name 'expected'
        $recommended = Get-GeneXusJsonProperty -Object $raw -Name 'recommendedDestination'

        # Nota: sem switch aqui de proposito. 'continue' dentro de um switch do
        # PowerShell continua o SWITCH, nao o foreach - a operacao invalida
        # seguiria para o inventario.
        $operationRejected = $false
        if ($op -eq 'setDocumentation') {
            if (-not (Test-GeneXusJsonProperty -Object $newBlock -Name 'documentation')) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'setDocumentation exige new.documentation (null admitido).' -OpId $opId))
                $operationRejected = $true
            }
        } elseif ($op -eq 'setParent') {
            if ($objectState -eq 'new') {
                if ($null -eq $recommended) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'setParent com objectState new exige recommendedDestination.' -OpId $opId))
                    $operationRejected = $true
                } else {
                    $newBlock = $recommended
                }
            }
            if (-not $operationRejected) {
                foreach ($field in @('parent', 'parentGuid', 'parentType')) {
                    if (-not (Test-GeneXusJsonProperty -Object $newBlock -Name $field)) {
                        [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message "setParent exige o campo '$field' no destino." -OpId $opId))
                        $operationRejected = $true
                    }
                }
            }
            if (-not $operationRejected) {
                $parentType = [string](Get-GeneXusJsonProperty -Object $newBlock -Name 'parentType')
                if ($parentType -eq (Get-GeneXusModuleTypeGuid)) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MODULE_PARENT_UNSUPPORTED' -Message 'destino do tipo Module nao e suportado (D6).' -OpId $opId))
                    $operationRejected = $true
                } elseif (-not [string]::IsNullOrWhiteSpace($parentType) -and $parentType -ne (Get-GeneXusFolderTypeGuid)) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'PARENT_TARGET_NOT_FOLDER' -Message "parentType declarado nao e Folder: '$parentType'." -OpId $opId))
                    $operationRejected = $true
                }
            }
        } elseif ($op -eq 'renameDomain') {
            if ($expectedType -ne 'Domain') {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'UNSUPPORTED_OPERATION' -Message "renameDomain exige expectedType Domain; declarado '$expectedType'." -OpId $opId))
                $operationRejected = $true
            }
            if (-not $operationRejected -and -not (Test-GeneXusJsonProperty -Object $newBlock -Name 'name')) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'renameDomain exige new.name.' -OpId $opId))
                $operationRejected = $true
            }
            if (-not $operationRejected -and -not (Test-GeneXusJsonProperty -Object $raw -Name 'renameFile')) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'renameDomain exige renameFile.' -OpId $opId))
                $operationRejected = $true
            }
            if (-not $operationRejected) {
                $renameFile = [bool](Get-GeneXusJsonProperty -Object $raw -Name 'renameFile' -Default $false)
                if (-not $renameFile) {
                    $justification = [string](Get-GeneXusJsonProperty -Object $raw -Name 'renameFileJustification')
                    if ([string]::IsNullOrWhiteSpace($justification)) {
                        [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message 'renameFile false exige renameFileJustification registrada.' -OpId $opId))
                        $operationRejected = $true
                    }
                }
            }
            if (-not $operationRejected) {
                foreach ($field in @('name', 'fullyQualifiedName', 'propertyName', 'description')) {
                    if (-not (Test-GeneXusJsonProperty -Object $expectedBlock -Name $field)) {
                        [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MANIFEST_SCHEMA_INVALID' -Message "renameDomain exige expected.$field." -OpId $opId))
                        $operationRejected = $true
                    }
                }
            }
        }
        if ($operationRejected) { continue }

        $typeAndPathKey = "$op|" + $xmlPath.ToLowerInvariant()
        if ($pathByTypeAndPath.ContainsKey($typeAndPathKey)) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'DUPLICATE_OPERATION' -Message "xmlPath repetido para a operacao '$op': $xmlPath." -OpId $opId -Path $xmlPath))
        } else {
            $pathByTypeAndPath[$typeAndPathKey] = $opId
        }

        $guidKey = $parsedGuid.ToString()
        $pathKey = $xmlPath.ToLowerInvariant()
        if (-not $guidToPaths.ContainsKey($guidKey)) { $guidToPaths[$guidKey] = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase) }
        [void]$guidToPaths[$guidKey].Add($pathKey)
        if (-not $pathToGuids.ContainsKey($pathKey)) { $pathToGuids[$pathKey] = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase) }
        [void]$pathToGuids[$pathKey].Add($guidKey)

        [void]$operations.Add([pscustomobject]@{
            Id           = $opId
            Op           = $op
            ObjectState  = $objectState
            Guid         = $guidKey
            ExpectedType = $expectedType
            ExpectedName = $expectedName
            XmlPath      = $xmlPath
            Expected     = $expectedBlock
            New          = $newBlock
            RenameFile   = [bool](Get-GeneXusJsonProperty -Object $raw -Name 'renameFile' -Default $false)
            AllowDegradedAccents = $allowDegraded
            UnusedEvidence = (Get-GeneXusJsonProperty -Object $raw -Name 'unusedEvidence')
            Raw          = $raw
        })
    }

    foreach ($guidKey in $guidToPaths.Keys) {
        if ($guidToPaths[$guidKey].Count -gt 1) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'DUPLICATE_TARGET' -Message "guid $guidKey aparece em mais de um xmlPath: $($guidToPaths[$guidKey] -join ', ')." -Detail $guidKey))
        }
    }
    foreach ($pathKey in $pathToGuids.Keys) {
        if ($pathToGuids[$pathKey].Count -gt 1) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'DUPLICATE_TARGET' -Message "xmlPath $pathKey aparece com mais de um guid: $($pathToGuids[$pathKey] -join ', ')." -Path $pathKey))
        }
    }

    return [pscustomobject]@{ Blocks = @($blocks); Operations = @($operations) }
}

# ---------------------------------------------------------------------------
# Scanner de referencias a Domain (secao 7)
# ---------------------------------------------------------------------------

function Get-GeneXusModuleNameByGuid {
    param(
        [Parameter(Mandatory = $true)][string]$AcervoPath,
        [Parameter(Mandatory = $true)][string]$ModuleGuid
    )

    $moduleFolder = Join-Path $AcervoPath 'Module'
    if (-not (Test-Path -LiteralPath $moduleFolder -PathType Container)) { return $null }
    foreach ($file in (Get-ChildItem -LiteralPath $moduleFolder -Filter '*.xml' -File)) {
        $raw = [System.IO.File]::ReadAllText($file.FullName)
        if ($raw.IndexOf($ModuleGuid, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        $info = Get-GeneXusObjectRootInfo -Text $raw
        if (-not $info.Valid) { continue }
        if ([string]::Equals([string]$info.Attributes['guid'], $ModuleGuid, [StringComparison]::OrdinalIgnoreCase)) {
            return [string]$info.Attributes['name']
        }
    }
    return $null
}

function Get-GeneXusXmlCDataNodes {
    param([Parameter(Mandatory = $true)][System.Xml.XmlDocument]$Document)

    $found = [System.Collections.Generic.List[object]]::new()
    $stack = [System.Collections.Generic.Stack[System.Xml.XmlNode]]::new()
    $stack.Push($Document)
    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        foreach ($child in $node.ChildNodes) {
            if ($child.NodeType -eq [System.Xml.XmlNodeType]::CDATA) {
                [void]$found.Add($child)
                continue
            }
            if ($child.HasChildNodes) { $stack.Push($child) }
        }
    }
    return @($found)
}

function Build-GeneXusDomainReferenceIndex {
    <#
        Uma varredura por rodada, nao por operacao: coleta TODA ocorrencia de
        'Domain:' em texto de no <Value> (casamento positivo) e em CDATA
        (classificada por origem). 131 renomes nao podem custar 131 varreduras
        do acervo inteiro; a semantica por operacao e a mesma.
    #>
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ScanRoots
    )

    $valueOccurrences = [System.Collections.Generic.List[object]]::new()
    $cdataOccurrences = [System.Collections.Generic.List[object]]::new()
    $unreadable = [System.Collections.Generic.List[object]]::new()
    $filesScanned = 0
    $docPartGuid = Get-GeneXusDocumentationPartTypeGuid

    foreach ($root in $ScanRoots) {
        if ([string]::IsNullOrWhiteSpace($root)) { continue }
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $root -Filter '*.xml' -File -Recurse)) {
            $filesScanned++
            $raw = $null
            try {
                $raw = [System.IO.File]::ReadAllText($file.FullName)
            } catch {
                [void]$unreadable.Add([pscustomobject]@{ path = $file.FullName; reason = $_.Exception.Message })
                continue
            }
            if ($raw.IndexOf('Domain:', [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }

            $doc = New-Object System.Xml.XmlDocument
            $doc.PreserveWhitespace = $true
            try {
                $doc.LoadXml($raw)
            } catch {
                [void]$unreadable.Add([pscustomobject]@{ path = $file.FullName; reason = "XML invalido: $($_.Exception.Message)" })
                continue
            }

            foreach ($node in $doc.SelectNodes('//Value')) {
                $text = [string]$node.InnerText
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                if (-not $text.StartsWith('Domain:', [StringComparison]::OrdinalIgnoreCase)) { continue }
                [void]$valueOccurrences.Add([pscustomobject]@{
                    path  = $file.FullName
                    value = $text.Trim()
                })
            }

            foreach ($cdata in (Get-GeneXusXmlCDataNodes -Document $doc)) {
                $text = [string]$cdata.Value
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                if ($text.IndexOf('Domain:', [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }

                $origin = 'other'
                $cursor = $cdata.ParentNode
                while ($null -ne $cursor) {
                    if ($cursor.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                        if ([string]::Equals($cursor.LocalName, 'Part', [StringComparison]::Ordinal)) {
                            $partType = ''
                            if ($cursor.HasAttribute('type')) { $partType = $cursor.GetAttribute('type') }
                            if ([string]::Equals($partType, $docPartGuid, [StringComparison]::OrdinalIgnoreCase)) {
                                $origin = 'documentation'
                            }
                            break
                        }
                        if ([string]::Equals($cursor.LocalName, 'Source', [StringComparison]::Ordinal)) {
                            $origin = 'source'
                        }
                    }
                    $cursor = $cursor.ParentNode
                }

                [void]$cdataOccurrences.Add([pscustomobject]@{
                    path   = $file.FullName
                    origin = $origin
                    text   = $text
                })
            }
        }
    }

    return [pscustomobject]@{
        ValueOccurrences = @($valueOccurrences)
        CdataOccurrences = @($cdataOccurrences)
        Unreadable       = @($unreadable)
        FilesScanned     = $filesScanned
    }
}

function Get-GeneXusDomainDefinitionIndex {
    param([Parameter(Mandatory = $true)][string]$AcervoPath)

    $byName = @{}
    $domainFolder = Join-Path $AcervoPath 'Domain'
    if (Test-Path -LiteralPath $domainFolder -PathType Container) {
        foreach ($file in (Get-ChildItem -LiteralPath $domainFolder -Filter '*.xml' -File)) {
            $info = Get-GeneXusObjectRootInfo -Text ([System.IO.File]::ReadAllText($file.FullName))
            if (-not $info.Valid) { continue }
            $name = [string]$info.Attributes['name']
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $key = $name.ToLowerInvariant()
            if (-not $byName.ContainsKey($key)) { $byName[$key] = [System.Collections.Generic.List[object]]::new() }
            [void]$byName[$key].Add([pscustomobject]@{
                Path       = $file.FullName
                Name       = $name
                Guid       = [string]$info.Attributes['guid']
                ModuleGuid = [string]$info.Attributes['moduleGuid']
            })
        }
    }
    return $byName
}

function Test-GeneXusPackagedModuleHomonym {
    param(
        [Parameter(Mandatory = $true)][string]$AcervoPath,
        [Parameter(Mandatory = $true)][string]$DomainName
    )

    $folder = Join-Path $AcervoPath 'PackagedModule'
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) { return @() }

    $domainTypeGuid = Get-GeneXusDomainTypeGuid
    $hits = [System.Collections.Generic.List[object]]::new()
    foreach ($file in (Get-ChildItem -LiteralPath $folder -Filter '*.xml' -File -Recurse)) {
        $raw = [System.IO.File]::ReadAllText($file.FullName)
        if ($raw.IndexOf($DomainName, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
        if ($raw.IndexOf($domainTypeGuid, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }

        $doc = New-Object System.Xml.XmlDocument
        $doc.PreserveWhitespace = $true
        try { $doc.LoadXml($raw) } catch { continue }
        foreach ($node in $doc.SelectNodes('//Object')) {
            $nodeType = ''
            $nodeName = ''
            if ($node.HasAttribute('type')) { $nodeType = $node.GetAttribute('type') }
            if ($node.HasAttribute('name')) { $nodeName = $node.GetAttribute('name') }
            if (-not [string]::Equals($nodeType, $domainTypeGuid, [StringComparison]::OrdinalIgnoreCase)) { continue }
            if (-not [string]::Equals($nodeName, $DomainName, [StringComparison]::OrdinalIgnoreCase)) { continue }
            [void]$hits.Add([pscustomobject]@{ Path = $file.FullName; Name = $nodeName })
            break
        }
    }
    return @($hits)
}

function Resolve-GeneXusDomainReferenceVerdict {
    <#
        Aplica, sobre o indice ja construido, as regras da secao 7 para UM alvo.
        Comparacao case-insensitive com ancora de cultura explicita
        (OrdinalIgnoreCase); nunca a cultura corrente.
    #>
    param(
        [Parameter(Mandatory = $true)][object]$Index,
        [Parameter(Mandatory = $true)][string]$TargetName,
        [Parameter(Mandatory = $true)][string]$TargetGuid,
        [AllowNull()][string]$TargetModuleName,
        [Parameter(Mandatory = $true)][object]$DomainDefinitions,
        [AllowEmptyCollection()][object[]]$PackagedHomonyms = @()
    )

    $blockingOccurrences = [System.Collections.Generic.List[object]]::new()
    $reportOnlyOccurrences = [System.Collections.Generic.List[object]]::new()
    $incompleteReasons = [System.Collections.Generic.List[string]]::new()
    $caseInsensitiveMatches = [System.Collections.Generic.List[object]]::new()

    $shortForm = "Domain:$TargetName"
    $qualifiedForm = $null
    if (-not [string]::IsNullOrWhiteSpace($TargetModuleName)) {
        $qualifiedForm = "Domain:$TargetName, $TargetModuleName"
    }

    foreach ($occurrence in $Index.ValueOccurrences) {
        $value = [string]$occurrence.value
        $suffix = $value.Substring('Domain:'.Length).Trim()
        $namePart = $suffix
        $modulePart = $null
        $commaIndex = $suffix.IndexOf(',')
        if ($commaIndex -ge 0) {
            $namePart = $suffix.Substring(0, $commaIndex).Trim()
            $modulePart = $suffix.Substring($commaIndex + 1).Trim()
        }
        if (-not [string]::Equals($namePart, $TargetName, [StringComparison]::OrdinalIgnoreCase)) { continue }

        $matchedExactly = $false
        if ([string]::Equals($value, $shortForm, [StringComparison]::Ordinal)) { $matchedExactly = $true }
        if ($null -ne $qualifiedForm -and [string]::Equals($value, $qualifiedForm, [StringComparison]::Ordinal)) { $matchedExactly = $true }
        if (-not $matchedExactly) {
            $isKnownForm = $false
            if ([string]::Equals($value, $shortForm, [StringComparison]::OrdinalIgnoreCase)) { $isKnownForm = $true }
            if ($null -ne $qualifiedForm -and [string]::Equals($value, $qualifiedForm, [StringComparison]::OrdinalIgnoreCase)) { $isKnownForm = $true }
            if ($isKnownForm) {
                [void]$caseInsensitiveMatches.Add([pscustomobject]@{ path = $occurrence.path; value = $value })
            }
        }

        if ($null -ne $modulePart) {
            if ([string]::IsNullOrWhiteSpace($TargetModuleName)) {
                [void]$incompleteReasons.Add("ocorrencia qualificada '$value' sem modulo resolvido para o alvo ($($occurrence.path)).")
                continue
            }
            if (-not [string]::Equals($modulePart, $TargetModuleName, [StringComparison]::OrdinalIgnoreCase)) {
                [void]$incompleteReasons.Add("ocorrencia qualificada '$value' aponta para modulo distinto do alvo ($($occurrence.path)).")
                continue
            }
            [void]$blockingOccurrences.Add([pscustomobject]@{ path = $occurrence.path; value = $value; form = 'qualified' })
            continue
        }

        $key = $namePart.ToLowerInvariant()
        $definitions = @()
        if ($DomainDefinitions.ContainsKey($key)) { $definitions = @($DomainDefinitions[$key]) }
        if ($definitions.Count -eq 0) {
            [void]$incompleteReasons.Add("grafia '$value' nao resolve para nenhum Domain do acervo ($($occurrence.path)).")
            continue
        }
        if ($definitions.Count -gt 1) {
            [void]$incompleteReasons.Add("grafia '$value' resolve para mais de um Domain do acervo ($($occurrence.path)).")
            continue
        }
        if (-not [string]::Equals($definitions[0].Guid, $TargetGuid, [StringComparison]::OrdinalIgnoreCase)) {
            continue
        }
        [void]$blockingOccurrences.Add([pscustomobject]@{ path = $occurrence.path; value = $value; form = 'short' })
    }

    if (@($PackagedHomonyms).Count -gt 0) {
        foreach ($homonym in $PackagedHomonyms) {
            [void]$incompleteReasons.Add("Domain homonimo definido dentro de PackagedModule: $($homonym.Path).")
        }
    }

    foreach ($occurrence in $Index.CdataOccurrences) {
        $text = [string]$occurrence.text
        $hit = $false
        foreach ($form in @($shortForm, $qualifiedForm)) {
            if ([string]::IsNullOrWhiteSpace($form)) { continue }
            if ($text.IndexOf($form, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $hit = $true }
        }
        if (-not $hit) { continue }
        if ($occurrence.origin -eq 'documentation') {
            [void]$reportOnlyOccurrences.Add([pscustomobject]@{ path = $occurrence.path; origin = 'documentation' })
            continue
        }
        [void]$blockingOccurrences.Add([pscustomobject]@{ path = $occurrence.path; value = $shortForm; form = "cdata:$($occurrence.origin)" })
    }

    foreach ($entry in $Index.Unreadable) {
        [void]$incompleteReasons.Add("arquivo ilegivel na varredura: $($entry.path) ($($entry.reason)).")
    }

    return [pscustomobject]@{
        Blocking      = @($blockingOccurrences)
        ReportOnly    = @($reportOnlyOccurrences)
        Incomplete    = @($incompleteReasons)
        CaseInsensitive = @($caseInsensitiveMatches)
    }
}

# ---------------------------------------------------------------------------
# Journal (secao 5, Fase 1b)
# ---------------------------------------------------------------------------

function New-GeneXusBatchJournal {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$WorkDir
    )

    $document = [ordered]@{
        Kind          = 'xpz-batch-metadata-journal'
        SchemaVersion = 1
        runId         = $RunId
        startedAtUtc  = [DateTime]::UtcNow.ToString('o')
        workDir       = $WorkDir
        steps         = @()
    }
    $journal = [pscustomobject]@{
        Path     = $Path
        WorkDir  = $WorkDir
        Document = $document
        Sequence = 0
    }
    Save-GeneXusBatchJournal -Journal $journal
    return $journal
}

function Save-GeneXusBatchJournal {
    param([Parameter(Mandatory = $true)][object]$Journal)

    $json = ($Journal.Document | ConvertTo-Json -Depth 12)
    [void](Write-XpzTextFileAtomic -Path $Journal.Path -Text $json -TempDir $Journal.WorkDir -ReplaceExisting)
}

function Add-GeneXusBatchJournalStep {
    param(
        [Parameter(Mandatory = $true)][object]$Journal,
        [Parameter(Mandatory = $true)][string]$OpId,
        [Parameter(Mandatory = $true)][string]$Action,
        [Parameter(Mandatory = $true)][ValidateSet('started', 'committed')][string]$State,
        [string]$PathBefore,
        [string]$PathAfter,
        [string]$BakPath,
        [string]$HashBefore,
        [string]$HashAfter
    )

    $Journal.Sequence = $Journal.Sequence + 1
    $step = [ordered]@{
        seq        = $Journal.Sequence
        opId       = $OpId
        action     = $Action
        state      = $State
        pathBefore = $PathBefore
        pathAfter  = $PathAfter
        bakPath    = $BakPath
        hashBefore = $HashBefore
        hashAfter  = $HashAfter
        atUtc      = [DateTime]::UtcNow.ToString('o')
    }
    $steps = [System.Collections.Generic.List[object]]::new()
    foreach ($existing in @($Journal.Document.steps)) { [void]$steps.Add($existing) }
    [void]$steps.Add($step)
    $Journal.Document.steps = @($steps)
    Save-GeneXusBatchJournal -Journal $Journal
    return $step
}

function Get-GeneXusFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        return [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-GeneXusTextSha256 {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (Get-Utf8NoBomEncoding).GetBytes($Text)
        return [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

# ---------------------------------------------------------------------------
# Lock (Fase 0)
# ---------------------------------------------------------------------------

function Test-GeneXusProcessAlive {
    param([Parameter(Mandatory = $true)][int]$ProcessId)

    if ($ProcessId -le 0) { return $false }
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    return ($null -ne $process)
}

function Request-GeneXusBatchRunLock {
    param(
        [Parameter(Mandatory = $true)][string]$WorkDir,
        [Parameter(Mandatory = $true)][string]$RunId
    )

    $lockPath = Join-Path $WorkDir 'run.lock'
    $staleReclaimed = $null
    if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
        $existing = $null
        try {
            $existing = [System.IO.File]::ReadAllText($lockPath) | ConvertFrom-Json
        } catch {
            $existing = $null
        }
        $existingPid = 0
        if ($null -ne $existing) { $existingPid = [int](Get-GeneXusJsonProperty -Object $existing -Name 'pid' -Default 0) }
        if (Test-GeneXusProcessAlive -ProcessId $existingPid) {
            return [pscustomobject]@{
                Acquired = $false
                Path     = $lockPath
                Reason   = "lock ativo do processo $existingPid"
                StaleReclaimed = $null
            }
        }
        $staleReclaimed = [pscustomobject]@{ pid = $existingPid; path = $lockPath }
    }

    $payload = [ordered]@{
        pid          = $PID
        runId        = $RunId
        startedAtUtc = [DateTime]::UtcNow.ToString('o')
    } | ConvertTo-Json -Depth 3
    [void](Write-XpzTextFileAtomic -Path $lockPath -Text $payload -TempDir $WorkDir -ReplaceExisting)

    return [pscustomobject]@{
        Acquired = $true
        Path     = $lockPath
        Reason   = $null
        StaleReclaimed = $staleReclaimed
    }
}

function Remove-GeneXusBatchRunLock {
    param([Parameter(Mandatory = $true)][string]$LockPath)

    if (Test-Path -LiteralPath $LockPath -PathType Leaf) {
        Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Testemunha de HEAD (secao 11)
# ---------------------------------------------------------------------------

function Get-GeneXusHeadWitnessContext {
    param([Parameter(Mandatory = $true)][string]$AcervoPath)

    $repoRoot = $null
    $output = & git -C $AcervoPath rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $null -ne $output) {
        $repoRoot = ([string]$output).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        return [pscustomobject]@{ State = 'unavailable'; RepoRoot = $null; Reason = 'acervo fora de work tree git' }
    }

    & git -C $repoRoot rev-parse --verify HEAD *> $null
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{ State = 'unavailable'; RepoRoot = $repoRoot; Reason = 'repositorio sem HEAD' }
    }

    $status = & git -C $repoRoot status --porcelain -- $AcervoPath 2>$null
    $dirty = ($null -ne $status -and @($status).Count -gt 0)
    $state = 'available'
    if ($dirty) { $state = 'dirtyWorktree' }
    return [pscustomobject]@{ State = $state; RepoRoot = $repoRoot; Reason = $null }
}

function Get-GeneXusHeadWitnessText {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$AbsolutePath
    )

    $relative = [System.IO.Path]::GetRelativePath($RepoRoot, $AbsolutePath).Replace('\', '/')
    $text = & git -C $RepoRoot show "HEAD:$relative" 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    if ($null -eq $text) { return $null }
    return (@($text) -join "`n")
}

# ---------------------------------------------------------------------------
# Rastreador de intervalos mutados (secao 6, "Mutacoes autorizadas")
#
# Guarda cada mutacao em DUAS coordenadas: a do texto original e a do texto
# final. Com as duas, a pos-condicao de identidade de bytes deixa de ser
# promessa: basta remover os intervalos declarados dos dois textos e exigir
# igualdade do resto.
# ---------------------------------------------------------------------------

function New-GeneXusMutationTracker {
    return [pscustomobject]@{
        Mutations = [System.Collections.Generic.List[object]]::new()
    }
}

function Add-GeneXusMutation {
    param(
        [Parameter(Mandatory = $true)][object]$Tracker,
        [Parameter(Mandatory = $true)][string]$OpId,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][int]$CurrentStart,
        [Parameter(Mandatory = $true)][int]$LengthBefore,
        [Parameter(Mandatory = $true)][int]$LengthAfter
    )

    # posicao equivalente no texto ORIGINAL: desconta o delta das mutacoes ja
    # aplicadas que terminam antes deste ponto.
    $shift = 0
    foreach ($mutation in $Tracker.Mutations) {
        if (($mutation.FinalStart + $mutation.FinalLength) -le $CurrentStart) {
            $shift += ($mutation.FinalLength - $mutation.OriginalLength)
        }
    }
    $originalStart = $CurrentStart - $shift

    $delta = $LengthAfter - $LengthBefore
    foreach ($mutation in $Tracker.Mutations) {
        if ($mutation.FinalStart -ge ($CurrentStart + $LengthBefore)) {
            $mutation.FinalStart = $mutation.FinalStart + $delta
        }
    }

    $entry = [pscustomobject]@{
        OpId           = $OpId
        Kind           = $Kind
        OriginalStart  = $originalStart
        OriginalLength = $LengthBefore
        FinalStart     = $CurrentStart
        FinalLength    = $LengthAfter
    }
    [void]$Tracker.Mutations.Add($entry)
    return $entry
}

function Remove-GeneXusIntervals {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Intervals
    )

    $ordered = @($Intervals | Sort-Object -Property Start)
    $builder = [System.Text.StringBuilder]::new()
    $cursor = 0
    foreach ($interval in $ordered) {
        if ($interval.Start -gt $cursor) {
            [void]$builder.Append($Text.Substring($cursor, $interval.Start - $cursor))
        }
        $next = $interval.Start + $interval.Length
        if ($next -gt $cursor) { $cursor = $next }
    }
    if ($cursor -lt $Text.Length) {
        [void]$builder.Append($Text.Substring($cursor))
    }
    return $builder.ToString()
}

function Test-GeneXusByteIdentityOutsideMutations {
    param(
        [Parameter(Mandatory = $true)][string]$OriginalText,
        [Parameter(Mandatory = $true)][string]$FinalText,
        [Parameter(Mandatory = $true)][object]$Tracker
    )

    $originalIntervals = @()
    $finalIntervals = @()
    foreach ($mutation in $Tracker.Mutations) {
        $originalIntervals += [pscustomobject]@{ Start = $mutation.OriginalStart; Length = $mutation.OriginalLength }
        $finalIntervals += [pscustomobject]@{ Start = $mutation.FinalStart; Length = $mutation.FinalLength }
    }

    $strippedOriginal = Remove-GeneXusIntervals -Text $OriginalText -Intervals $originalIntervals
    $strippedFinal = Remove-GeneXusIntervals -Text $FinalText -Intervals $finalIntervals
    return [string]::Equals($strippedOriginal, $strippedFinal, [StringComparison]::Ordinal)
}

# ---------------------------------------------------------------------------
# Operacao: setDocumentation (secao 6, "Ancoras")
# ---------------------------------------------------------------------------

function Get-GeneXusDocumentationPartContext {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object]$Scopes
    )

    $anchor = '<Part type="' + (Get-GeneXusDocumentationPartTypeGuid) + '">'
    $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $Text -Regions $Scopes.ScopeBRegions -Anchor $anchor -SkipRegions $Scopes.SkipRegions)
    if ($occurrences.Count -eq 0) {
        return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_NOT_FOUND'; Message = 'Part de documentacao ausente no escopo B.'; Count = 0 }
    }
    if ($occurrences.Count -gt 1) {
        return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_AMBIGUOUS'; Message = "Part de documentacao com $($occurrences.Count) ocorrencias no escopo B."; Count = $occurrences.Count }
    }

    $partStart = $occurrences[0]
    $region = $null
    foreach ($candidate in $Scopes.ScopeBRegions) {
        if ($partStart -ge $candidate.Start -and $partStart -le $candidate.End) { $region = $candidate; break }
    }
    if ($null -eq $region) {
        return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_NOT_FOUND'; Message = 'Part de documentacao fora das regioes do escopo B.'; Count = 0 }
    }

    $partRange = Get-GeneXusXmlElementRange -Text $Text -OpenTagStart $partStart -ElementName 'Part' -Limit ($region.End + 1)
    if ($null -eq $partRange -or $partRange.SelfClosing) {
        return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_NOT_FOUND'; Message = 'Part de documentacao sem extensao resolvivel.'; Count = 1 }
    }

    $innerScan = Get-GeneXusXmlElementEvents -Text $Text -ElementName 'InnerHtml' -From $partRange.ContentStart -To ($partRange.ContentEnd + 1)
    $innerRange = $null
    if ($innerScan.Ok) {
        foreach ($occurrence in @($innerScan.Events)) {
            if ($occurrence.Depth -ne 0) { continue }
            if ($occurrence.Kind -eq 'selfclose') {
                $innerRange = [pscustomobject]@{ OpenTagStart = $occurrence.Start; OpenTagEnd = $occurrence.TagEnd; SelfClosing = $true; ContentStart = -1; ContentEnd = -1; ElementEnd = $occurrence.TagEnd }
                break
            }
            if ($occurrence.Kind -eq 'open') {
                $innerRange = Get-GeneXusXmlElementRange -Text $Text -OpenTagStart $occurrence.Start -ElementName 'InnerHtml' -Limit ($partRange.ContentEnd + 1)
                break
            }
        }
    }

    $currentDocumentation = $null
    if ($null -ne $innerRange) {
        $currentDocumentation = ''
        if (-not $innerRange.SelfClosing -and $innerRange.ContentEnd -ge $innerRange.ContentStart) {
            $innerText = $Text.Substring($innerRange.ContentStart, $innerRange.ContentEnd - $innerRange.ContentStart + 1)
            $cdataStart = $innerText.IndexOf('<![CDATA[', [StringComparison]::Ordinal)
            if ($cdataStart -ge 0) {
                $cdataEnd = $innerText.IndexOf(']]>', $cdataStart + 9, [StringComparison]::Ordinal)
                if ($cdataEnd -ge 0) {
                    $currentDocumentation = $innerText.Substring($cdataStart + 9, $cdataEnd - $cdataStart - 9)
                }
            } else {
                $currentDocumentation = $innerText
            }
        }
    }

    $propertiesStart = -1
    $propertiesScan = Get-GeneXusXmlElementEvents -Text $Text -ElementName 'Properties' -From $partRange.ContentStart -To ($partRange.ContentEnd + 1)
    if ($propertiesScan.Ok) {
        foreach ($occurrence in @($propertiesScan.Events)) {
            if ($occurrence.Depth -eq 0 -and ($occurrence.Kind -eq 'open' -or $occurrence.Kind -eq 'selfclose')) {
                $propertiesStart = $occurrence.Start
                break
            }
        }
    }

    $partText = $Text.Substring($partRange.OpenTagStart, $partRange.ElementEnd - $partRange.OpenTagStart + 1)
    $collapsed = ($partText.IndexOf("`n", [StringComparison]::Ordinal) -lt 0 -and $partText.IndexOf("`r", [StringComparison]::Ordinal) -lt 0)

    return [pscustomobject]@{
        Ok                   = $true
        Code                 = $null
        Message              = $null
        Count                = 1
        Region               = $region
        PartRange            = $partRange
        InnerRange           = $innerRange
        CurrentDocumentation = $currentDocumentation
        PropertiesStart      = $propertiesStart
        Collapsed            = $collapsed
    }
}

function Invoke-GeneXusSetDocumentationPatch {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object]$Scopes,
        [Parameter(Mandatory = $true)][object]$Operation,
        [Parameter(Mandatory = $true)][string]$Eol,
        [Parameter(Mandatory = $true)][object]$Tracker,
        [Parameter(Mandatory = $true)][object]$AccentDetector,
        [bool]$AllowDegradedAccentsSwitch
    )

    $context = Get-GeneXusDocumentationPartContext -Text $Text -Scopes $Scopes
    if (-not $context.Ok) {
        return [pscustomobject]@{ Ok = $false; Code = $context.Code; Message = $context.Message; Text = $Text; Warnings = @() }
    }

    $warnings = [System.Collections.Generic.List[object]]::new()

    if ($Operation.ObjectState -eq 'existing') {
        $expectedDocumentation = Get-GeneXusJsonProperty -Object $Operation.Expected -Name 'documentation'
        $current = $context.CurrentDocumentation
        $preconditionOk = $false
        if ($null -eq $expectedDocumentation -and $null -eq $current) {
            $preconditionOk = $true
        } elseif ($null -ne $expectedDocumentation -and $null -ne $current) {
            $preconditionOk = [string]::Equals([string]$expectedDocumentation, [string]$current, [StringComparison]::Ordinal)
        }
        if (-not $preconditionOk) {
            $currentLabel = '<ausente>'
            if ($null -ne $current) { $currentLabel = "'" + $current + "'" }
            return [pscustomobject]@{
                Ok       = $false
                Code     = 'PRECONDITION_MISMATCH'
                Message  = "documentation declarada em expected nao bate com a realidade do arquivo (atual: $currentLabel)."
                Text     = $Text
                Warnings = @()
            }
        }
    }

    $newDocumentation = Get-GeneXusJsonProperty -Object $Operation.New -Name 'documentation'

    # degradacao preexistente: reportada, nao bloqueia (D5'')
    if ($null -ne $context.CurrentDocumentation) {
        foreach ($finding in (Measure-GeneXusAccentDegradation -Detector $AccentDetector -Text ([string]$context.CurrentDocumentation))) {
            [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'degradedAccentsPreexisting' -Message "acentuacao degradada preexistente: '$($finding.word)'" -OpId $Operation.Id -Detail $finding))
        }
    }

    $payload = $null
    if ($null -ne $newDocumentation) {
        $payloadRaw = [string]$newDocumentation
        if ($payloadRaw.IndexOf(']]>', [StringComparison]::Ordinal) -ge 0) {
            return [pscustomobject]@{ Ok = $false; Code = 'CDATA_UNSAFE'; Message = 'texto novo contem a sequencia de fechamento de CDATA.'; Text = $Text; Warnings = @($warnings) }
        }
        $normalized = ConvertTo-GeneXusPayloadWithEol -Text $payloadRaw -Eol $Eol
        if (-not $normalized.Valid) {
            return [pscustomobject]@{ Ok = $false; Code = 'PAYLOAD_EOL_INVALID'; Message = $normalized.Reason; Text = $Text; Warnings = @($warnings) }
        }
        $payload = $normalized.Text

        $introduced = @(Measure-GeneXusAccentDegradation -Detector $AccentDetector -Text $payload)
        if ($introduced.Count -gt 0) {
            if (-not ($Operation.AllowDegradedAccents -and $AllowDegradedAccentsSwitch)) {
                return [pscustomobject]@{
                    Ok       = $false
                    Code     = 'DEGRADED_ACCENTS_INTRODUCED'
                    Message  = "texto novo introduz acentuacao degradada: $(($introduced | ForEach-Object { $_.word }) -join ', ')"
                    Text     = $Text
                    Warnings = @($warnings)
                }
            }
            foreach ($finding in $introduced) {
                [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'degradedAccentsAllowed' -Message "acentuacao degradada aceita por excecao: '$($finding.word)'" -OpId $Operation.Id -Detail $finding))
            }
        }
    }

    # A contagem da ancora e a gravacao acontecem no MESMO escopo (secao 6.0), e
    # esse escopo aqui e o PROPRIO Part - nao a regiao B inteira. A regiao B de
    # um SDT real tem dezenas de '<Properties' na mesma indentacao; contar em B
    # e gravar em B daria ANCHOR_AMBIGUOUS onde a operacao e legitima.
    $region = [pscustomobject]@{ Start = $context.PartRange.OpenTagStart; End = $context.PartRange.ElementEnd }
    $innerRange = $context.InnerRange
    $patch = $null

    if ($null -ne $innerRange) {
        $blockText = $Text.Substring($innerRange.OpenTagStart, $innerRange.ElementEnd - $innerRange.OpenTagStart + 1)
        if ($null -eq $payload) {
            # remocao: tira o bloco e a quebra/indentacao que o precedia, quando
            # ele ocupava linha propria.
            $prefixStart = $innerRange.OpenTagStart
            $scan = $innerRange.OpenTagStart - 1
            while ($scan -ge $region.Start -and ($Text[$scan] -eq ' ' -or $Text[$scan] -eq "`t")) { $scan-- }
            if ($scan -ge $region.Start -and $Text[$scan] -eq "`n") {
                $prefixStart = $scan
                if ($scan -gt $region.Start -and $Text[$scan - 1] -eq "`r") { $prefixStart = $scan - 1 }
            }
            $anchorText = $Text.Substring($prefixStart, $innerRange.ElementEnd - $prefixStart + 1)
            $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $Text -Regions @($region) -Anchor $anchorText)
            if ($occurrences.Count -ne 1) {
                return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_AMBIGUOUS'; Message = "bloco InnerHtml com $($occurrences.Count) ocorrencias no escopo."; Text = $Text; Warnings = @($warnings) }
            }
            $patch = Invoke-GeneXusScopedLiteralPatch -Text $Text -RegionStart $region.Start -RegionEnd $region.End -Anchor $anchorText -Replacement '' -EditMode 'Replace'
        } else {
            $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $Text -Regions @($region) -Anchor $blockText)
            if ($occurrences.Count -ne 1) {
                return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_AMBIGUOUS'; Message = "bloco InnerHtml com $($occurrences.Count) ocorrencias no escopo."; Text = $Text; Warnings = @($warnings) }
            }
            $replacement = '<InnerHtml><![CDATA[' + $payload + ']]></InnerHtml>'
            $patch = Invoke-GeneXusScopedLiteralPatch -Text $Text -RegionStart $region.Start -RegionEnd $region.End -Anchor $blockText -Replacement $replacement -EditMode 'Replace'
        }
    } else {
        if ($null -eq $payload) {
            return [pscustomobject]@{ Ok = $true; Code = 'NOOP'; Message = 'Part ja esta sem InnerHtml.'; Text = $Text; Warnings = @($warnings); Mutation = $null }
        }
        $block = '<InnerHtml><![CDATA[' + $payload + ']]></InnerHtml>'
        if ($context.Collapsed) {
            $anchorText = $Text.Substring($context.PartRange.OpenTagStart, $context.PartRange.OpenTagEnd - $context.PartRange.OpenTagStart + 1)
            $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $Text -Regions @($region) -Anchor $anchorText)
            if ($occurrences.Count -ne 1) {
                return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_AMBIGUOUS'; Message = "tag de abertura do Part com $($occurrences.Count) ocorrencias no escopo."; Text = $Text; Warnings = @($warnings) }
            }
            $patch = Invoke-GeneXusScopedLiteralPatch -Text $Text -RegionStart $region.Start -RegionEnd $region.End -Anchor $anchorText -Replacement $block -EditMode 'InsertAfter'
        } else {
            if ($context.PropertiesStart -lt 0) {
                return [pscustomobject]@{ Ok = $false; Code = 'ATTRIBUTE_INSERTION_ANCHOR_NOT_FOUND'; Message = 'Part sem <Properties> para ancorar a insercao do InnerHtml.'; Text = $Text; Warnings = @($warnings) }
            }
            $indentStart = $context.PropertiesStart
            while ($indentStart -gt $context.PartRange.ContentStart -and ($Text[$indentStart - 1] -eq ' ' -or $Text[$indentStart - 1] -eq "`t")) { $indentStart-- }
            $indent = $Text.Substring($indentStart, $context.PropertiesStart - $indentStart)
            $anchorText = $indent + '<Properties'
            $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $Text -Regions @($region) -Anchor $anchorText)
            if ($occurrences.Count -ne 1) {
                return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_AMBIGUOUS'; Message = "ancora de insercao com $($occurrences.Count) ocorrencias no escopo."; Text = $Text; Warnings = @($warnings) }
            }
            $replacement = $indent + $block + $Eol + $anchorText
            $patch = Invoke-GeneXusScopedLiteralPatch -Text $Text -RegionStart $region.Start -RegionEnd $region.End -Anchor $anchorText -Replacement $replacement -EditMode 'Replace'
        }
    }

    $mutation = Add-GeneXusMutation -Tracker $Tracker -OpId $Operation.Id -Kind 'documentation' `
        -CurrentStart $patch.MutatedStart -LengthBefore $patch.MutatedLengthBefore -LengthAfter $patch.MutatedLengthAfter

    return [pscustomobject]@{ Ok = $true; Code = 'PATCHED'; Message = $null; Text = $patch.Text; Warnings = @($warnings); Mutation = $mutation }
}

# ---------------------------------------------------------------------------
# Micro-patch de atributo da tag raiz (escopo A)
# ---------------------------------------------------------------------------

function Invoke-GeneXusRootAttributePatch {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object]$Scopes,
        [Parameter(Mandatory = $true)][string]$AttributeName,
        [AllowNull()][string]$CurrentValue,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$NewValue,
        [string]$InsertionAnchorName = 'name',
        [AllowNull()][string]$InsertionAnchorValue,
        [string]$AnchorPrefix = '',
        [Parameter(Mandatory = $true)][object]$Tracker,
        [Parameter(Mandatory = $true)][string]$OpId,
        [Parameter(Mandatory = $true)][string]$Kind
    )

    $scopeA = @([pscustomobject]@{ Start = $Scopes.RootTagStart; End = $Scopes.RootTagEnd })
    $patch = $null

    if ($null -ne $CurrentValue) {
        $anchor = $AnchorPrefix + $AttributeName + '="' + $CurrentValue + '"'
        $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $Text -Regions $scopeA -Anchor $anchor)
        if ($occurrences.Count -eq 0) {
            return [pscustomobject]@{
                Ok      = $false
                Code    = 'ATTRIBUTE_LEXICAL_MISMATCH'
                Message = "atributo '$AttributeName' existe no DOM mas a grafia literal nao foi encontrada na tag raiz (espacos em volta do '=' ou aspas simples)."
                Text    = $Text
            }
        }
        if ($occurrences.Count -gt 1) {
            return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_AMBIGUOUS'; Message = "atributo '$AttributeName' com $($occurrences.Count) ocorrencias na tag raiz."; Text = $Text }
        }
        $replacement = $AnchorPrefix + $AttributeName + '="' + [System.Security.SecurityElement]::Escape($NewValue) + '"'
        $patch = Invoke-GeneXusScopedLiteralPatch -Text $Text -RegionStart $Scopes.RootTagStart -RegionEnd $Scopes.RootTagEnd -Anchor $anchor -Replacement $replacement -EditMode 'Replace'
    } else {
        if ([string]::IsNullOrEmpty($InsertionAnchorValue)) {
            return [pscustomobject]@{ Ok = $false; Code = 'ATTRIBUTE_INSERTION_ANCHOR_NOT_FOUND'; Message = "sem valor de ancora ($InsertionAnchorName) para inserir '$AttributeName'."; Text = $Text }
        }
        $anchor = ' ' + $InsertionAnchorName + '="' + $InsertionAnchorValue + '"'
        $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $Text -Regions $scopeA -Anchor $anchor)
        if ($occurrences.Count -ne 1) {
            return [pscustomobject]@{
                Ok      = $false
                Code    = 'ATTRIBUTE_INSERTION_ANCHOR_NOT_FOUND'
                Message = "ancora de insercao '$InsertionAnchorName' com $($occurrences.Count) ocorrencias na tag raiz."
                Text    = $Text
            }
        }
        $replacement = ' ' + $AttributeName + '="' + [System.Security.SecurityElement]::Escape($NewValue) + '"'
        $patch = Invoke-GeneXusScopedLiteralPatch -Text $Text -RegionStart $Scopes.RootTagStart -RegionEnd $Scopes.RootTagEnd -Anchor $anchor -Replacement $replacement -EditMode 'InsertAfter'
    }

    $mutation = Add-GeneXusMutation -Tracker $Tracker -OpId $OpId -Kind $Kind `
        -CurrentStart $patch.MutatedStart -LengthBefore $patch.MutatedLengthBefore -LengthAfter $patch.MutatedLengthAfter

    return [pscustomobject]@{ Ok = $true; Code = 'PATCHED'; Message = $null; Text = $patch.Text; Mutation = $mutation }
}

# ---------------------------------------------------------------------------
# Operacao: setParent
# ---------------------------------------------------------------------------

function Invoke-GeneXusSetParentPatch {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object]$Scopes,
        [Parameter(Mandatory = $true)][object]$Operation,
        [Parameter(Mandatory = $true)][object]$RootAttributes,
        [Parameter(Mandatory = $true)][object]$Tracker
    )

    $warnings = [System.Collections.Generic.List[object]]::new()
    $currentText = $Text
    $currentScopes = $Scopes

    foreach ($attribute in @('parent', 'parentGuid', 'parentType')) {
        $newValue = [string](Get-GeneXusJsonProperty -Object $Operation.New -Name $attribute)
        $currentValue = $RootAttributes[$attribute]

        if ($Operation.ObjectState -eq 'existing') {
            $expectedValue = Get-GeneXusJsonProperty -Object $Operation.Expected -Name $attribute
            $preconditionOk = $false
            if ($null -eq $expectedValue -and $null -eq $currentValue) {
                $preconditionOk = $true
            } elseif ($null -ne $expectedValue -and $null -ne $currentValue) {
                $preconditionOk = [string]::Equals([string]$expectedValue, [string]$currentValue, [StringComparison]::Ordinal)
            }
            if (-not $preconditionOk) {
                return [pscustomobject]@{
                    Ok       = $false
                    Code     = 'PRECONDITION_MISMATCH'
                    Message  = "atributo '$attribute': expected='$expectedValue' nao bate com o arquivo ('$currentValue')."
                    Text     = $Text
                    Warnings = @($warnings)
                }
            }
        }

        if ($null -ne $currentValue -and [string]::Equals([string]$currentValue, $newValue, [StringComparison]::Ordinal)) {
            [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'attributeAlreadyAtTarget' -Message "atributo '$attribute' ja esta no valor de destino." -OpId $Operation.Id))
            continue
        }

        $result = Invoke-GeneXusRootAttributePatch -Text $currentText -Scopes $currentScopes `
            -AttributeName $attribute -CurrentValue $currentValue -NewValue $newValue `
            -InsertionAnchorName 'name' -InsertionAnchorValue ([string]$RootAttributes['name']) `
            -Tracker $Tracker -OpId $Operation.Id -Kind "parent:$attribute"
        if (-not $result.Ok) {
            return [pscustomobject]@{ Ok = $false; Code = $result.Code; Message = $result.Message; Text = $Text; Warnings = @($warnings) }
        }
        $currentText = $result.Text
        $currentScopes = Get-GeneXusXmlObjectScopes -Text $currentText
        if (-not $currentScopes.Valid) {
            return [pscustomobject]@{ Ok = $false; Code = 'MULTIPLE_OBJECT_ROOTS'; Message = "escopos irrecuperaveis apos patch de '$attribute': $($currentScopes.Reason)"; Text = $Text; Warnings = @($warnings) }
        }
    }

    return [pscustomobject]@{ Ok = $true; Code = 'PATCHED'; Message = $null; Text = $currentText; Warnings = @($warnings) }
}

# ---------------------------------------------------------------------------
# Operacao: renameDomain (quatro pontos, secao 6)
# ---------------------------------------------------------------------------

function Get-GeneXusObjectLevelPropertiesRange {
    <#
        O <Properties> do OBJETO: filho direto da raiz, dentro do escopo B e
        FORA de qualquer <Part>.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object]$Scopes
    )

    if ($Scopes.ContentStart -lt 0) { return $null }

    $partRanges = [System.Collections.Generic.List[object]]::new()
    $partScan = Get-GeneXusXmlElementEvents -Text $Text -ElementName 'Part' -From $Scopes.ContentStart -To ($Scopes.ContentEnd + 1)
    if ($partScan.Ok) {
        $pendingStart = -1
        foreach ($occurrence in @($partScan.Events)) {
            if ($occurrence.Kind -eq 'selfclose' -and $occurrence.Depth -eq 0) {
                [void]$partRanges.Add([pscustomobject]@{ Start = $occurrence.Start; End = $occurrence.TagEnd })
                continue
            }
            if ($occurrence.Kind -eq 'open' -and $occurrence.Depth -eq 0) {
                if ($pendingStart -lt 0) { $pendingStart = $occurrence.Start }
                continue
            }
            if ($occurrence.Kind -eq 'close' -and $occurrence.Depth -eq 0 -and $pendingStart -ge 0) {
                [void]$partRanges.Add([pscustomobject]@{ Start = $pendingStart; End = $occurrence.TagEnd })
                $pendingStart = -1
            }
        }
    }

    $regions = [System.Collections.Generic.List[object]]::new()
    foreach ($region in $Scopes.ScopeBRegions) {
        $cursor = $region.Start
        foreach ($part in $partRanges) {
            if ($part.End -lt $region.Start -or $part.Start -gt $region.End) { continue }
            if ($part.Start -gt $cursor) {
                [void]$regions.Add([pscustomobject]@{ Start = $cursor; End = $part.Start - 1 })
            }
            if (($part.End + 1) -gt $cursor) { $cursor = $part.End + 1 }
        }
        if ($cursor -le $region.End) {
            [void]$regions.Add([pscustomobject]@{ Start = $cursor; End = $region.End })
        }
    }

    $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $Text -Regions @($regions) -Anchor '<Properties' -SkipRegions $Scopes.SkipRegions)
    if ($occurrences.Count -eq 0) { return $null }

    $start = $occurrences[0]
    $region = $null
    foreach ($candidate in $regions) {
        if ($start -ge $candidate.Start -and $start -le $candidate.End) { $region = $candidate; break }
    }
    if ($null -eq $region) { return $null }

    $range = Get-GeneXusXmlElementRange -Text $Text -OpenTagStart $start -ElementName 'Properties' -Limit ($region.End + 1)
    if ($null -eq $range) { return $null }
    return [pscustomobject]@{ Range = $range; Region = $region; Count = $occurrences.Count }
}

function Invoke-GeneXusRenameDomainPatch {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object]$Scopes,
        [Parameter(Mandatory = $true)][object]$Operation,
        [Parameter(Mandatory = $true)][object]$RootAttributes,
        [Parameter(Mandatory = $true)][object]$Tracker
    )

    $warnings = [System.Collections.Generic.List[object]]::new()
    $expectedName = [string](Get-GeneXusJsonProperty -Object $Operation.Expected -Name 'name')
    $expectedFqn = [string](Get-GeneXusJsonProperty -Object $Operation.Expected -Name 'fullyQualifiedName')
    $expectedProperty = [string](Get-GeneXusJsonProperty -Object $Operation.Expected -Name 'propertyName')
    $expectedDescription = [string](Get-GeneXusJsonProperty -Object $Operation.Expected -Name 'description')
    $newName = [string](Get-GeneXusJsonProperty -Object $Operation.New -Name 'name')

    $currentName = [string]$RootAttributes['name']
    $currentFqn = [string]$RootAttributes['fullyQualifiedName']
    $currentDescription = $RootAttributes['description']

    if (-not [string]::Equals($currentName, $expectedName, [StringComparison]::Ordinal)) {
        return [pscustomobject]@{ Ok = $false; Code = 'PRECONDITION_MISMATCH'; Message = "name atual '$currentName' difere do expected '$expectedName'."; Text = $Text; Warnings = @($warnings) }
    }
    if (-not [string]::Equals($currentFqn, $expectedFqn, [StringComparison]::Ordinal)) {
        return [pscustomobject]@{ Ok = $false; Code = 'PRECONDITION_MISMATCH'; Message = "fullyQualifiedName atual '$currentFqn' difere do expected '$expectedFqn'."; Text = $Text; Warnings = @($warnings) }
    }

    $currentText = $Text
    $currentScopes = $Scopes

    # 1. Object/@name (ancora com espaco a esquerda: 'name="X"' tambem casaria
    #    dentro de fullyQualifiedName quando os dois valores coincidem)
    $result = Invoke-GeneXusRootAttributePatch -Text $currentText -Scopes $currentScopes `
        -AttributeName 'name' -CurrentValue $currentName -NewValue $newName -AnchorPrefix ' ' `
        -Tracker $Tracker -OpId $Operation.Id -Kind 'rename:name'
    if (-not $result.Ok) {
        return [pscustomobject]@{ Ok = $false; Code = $result.Code; Message = $result.Message; Text = $Text; Warnings = @($warnings) }
    }
    $currentText = $result.Text
    $currentScopes = Get-GeneXusXmlObjectScopes -Text $currentText
    if (-not $currentScopes.Valid) {
        return [pscustomobject]@{ Ok = $false; Code = 'MULTIPLE_OBJECT_ROOTS'; Message = "escopos irrecuperaveis apos patch de name: $($currentScopes.Reason)"; Text = $Text; Warnings = @($warnings) }
    }

    # 2. Object/@fullyQualifiedName: so o segmento final
    $fqnPrefix = ''
    $lastDot = $currentFqn.LastIndexOf('.')
    if ($lastDot -ge 0) { $fqnPrefix = $currentFqn.Substring(0, $lastDot + 1) }
    $finalSegment = $currentFqn.Substring($fqnPrefix.Length)
    if (-not [string]::Equals($finalSegment, $expectedName, [StringComparison]::Ordinal)) {
        return [pscustomobject]@{ Ok = $false; Code = 'PRECONDITION_MISMATCH'; Message = "segmento final de fullyQualifiedName ('$finalSegment') difere do name esperado ('$expectedName')."; Text = $Text; Warnings = @($warnings) }
    }
    $newFqn = $fqnPrefix + $newName
    $result = Invoke-GeneXusRootAttributePatch -Text $currentText -Scopes $currentScopes `
        -AttributeName 'fullyQualifiedName' -CurrentValue $currentFqn -NewValue $newFqn `
        -Tracker $Tracker -OpId $Operation.Id -Kind 'rename:fullyQualifiedName'
    if (-not $result.Ok) {
        return [pscustomobject]@{ Ok = $false; Code = $result.Code; Message = $result.Message; Text = $Text; Warnings = @($warnings) }
    }
    $currentText = $result.Text
    $currentScopes = Get-GeneXusXmlObjectScopes -Text $currentText
    if (-not $currentScopes.Valid) {
        return [pscustomobject]@{ Ok = $false; Code = 'MULTIPLE_OBJECT_ROOTS'; Message = "escopos irrecuperaveis apos patch de fullyQualifiedName: $($currentScopes.Reason)"; Text = $Text; Warnings = @($warnings) }
    }

    # 3. Property[Name='Name']/Value no <Properties> do objeto
    $propertiesContext = Get-GeneXusObjectLevelPropertiesRange -Text $currentText -Scopes $currentScopes
    if ($null -eq $propertiesContext) {
        return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_NOT_FOUND'; Message = 'objeto sem <Properties> de nivel raiz para o ponto Property[Name=Name]/Value.'; Text = $Text; Warnings = @($warnings) }
    }
    $propertyAnchor = '<Name>Name</Name><Value>' + $expectedProperty + '</Value>'
    $propertyRegion = [pscustomobject]@{ Start = $propertiesContext.Range.OpenTagStart; End = $propertiesContext.Range.ElementEnd }
    $occurrences = @(Get-GeneXusRegionOccurrenceIndexes -Text $currentText -Regions @($propertyRegion) -Anchor $propertyAnchor -SkipRegions $currentScopes.SkipRegions)
    if ($occurrences.Count -eq 0) {
        return [pscustomobject]@{ Ok = $false; Code = 'PRECONDITION_MISMATCH'; Message = "Property[Name=Name]/Value nao contem '$expectedProperty' na grafia esperada."; Text = $Text; Warnings = @($warnings) }
    }
    if ($occurrences.Count -gt 1) {
        return [pscustomobject]@{ Ok = $false; Code = 'ANCHOR_AMBIGUOUS'; Message = "Property[Name=Name]/Value com $($occurrences.Count) ocorrencias no <Properties> do objeto."; Text = $Text; Warnings = @($warnings) }
    }
    $propertyReplacement = '<Name>Name</Name><Value>' + [System.Security.SecurityElement]::Escape($newName) + '</Value>'
    $patch = Invoke-GeneXusScopedLiteralPatch -Text $currentText -RegionStart $propertyRegion.Start -RegionEnd $propertyRegion.End `
        -Anchor $propertyAnchor -Replacement $propertyReplacement -EditMode 'Replace'
    [void](Add-GeneXusMutation -Tracker $Tracker -OpId $Operation.Id -Kind 'rename:propertyValue' `
        -CurrentStart $patch.MutatedStart -LengthBefore $patch.MutatedLengthBefore -LengthAfter $patch.MutatedLengthAfter)
    $currentText = $patch.Text
    $currentScopes = Get-GeneXusXmlObjectScopes -Text $currentText
    if (-not $currentScopes.Valid) {
        return [pscustomobject]@{ Ok = $false; Code = 'MULTIPLE_OBJECT_ROOTS'; Message = "escopos irrecuperaveis apos patch de Property: $($currentScopes.Reason)"; Text = $Text; Warnings = @($warnings) }
    }

    # 4. Object/@description: so quando identico ao expectedName
    $descriptionPreserved = $false
    if ($null -eq $currentDescription) {
        $descriptionPreserved = $true
        [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'descriptionPreservedByDivergence' -Message 'objeto sem atributo description; preservado.' -OpId $Operation.Id))
    } elseif (-not [string]::Equals([string]$currentDescription, $expectedDescription, [StringComparison]::Ordinal) -or
              -not [string]::Equals([string]$currentDescription, $expectedName, [StringComparison]::Ordinal)) {
        $descriptionPreserved = $true
        [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'descriptionPreservedByDivergence' `
            -Message "description ('$currentDescription') nao e identica ao nome antigo; preservada e status rebaixado." -OpId $Operation.Id))
    } else {
        $result = Invoke-GeneXusRootAttributePatch -Text $currentText -Scopes $currentScopes `
            -AttributeName 'description' -CurrentValue ([string]$currentDescription) -NewValue $newName `
            -Tracker $Tracker -OpId $Operation.Id -Kind 'rename:description'
        if (-not $result.Ok) {
            return [pscustomobject]@{ Ok = $false; Code = $result.Code; Message = $result.Message; Text = $Text; Warnings = @($warnings) }
        }
        $currentText = $result.Text
    }

    return [pscustomobject]@{
        Ok       = $true
        Code     = 'PATCHED'
        Message  = $null
        Text     = $currentText
        Warnings = @($warnings)
        DescriptionPreserved = $descriptionPreserved
        NewName  = $newName
        OldName  = $expectedName
    }
}

# ---------------------------------------------------------------------------
# lastUpdate: alvo e bump (excecao declarada a regra de ancora, secao 6)
# ---------------------------------------------------------------------------

function Test-GeneXusLastUpdateTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object]$Scopes,
        [AllowNull()][string]$RootLastUpdateRaw
    )

    $info = Get-FirstObjectLastUpdateFromText -Text $Text
    if ($null -eq $info) {
        if ([string]::IsNullOrWhiteSpace($RootLastUpdateRaw)) {
            return [pscustomobject]@{ Ok = $false; Code = 'LASTUPDATE_UNREADABLE'; Message = 'raiz sem atributo lastUpdate.'; Info = $null }
        }
        return [pscustomobject]@{
            Ok      = $false
            Code    = 'LASTUPDATE_UNREADABLE'
            Message = "raiz tem lastUpdate='$RootLastUpdateRaw', que o padrao do motor nao casa (valor com offset, por exemplo)."
            Info    = $null
        }
    }
    if ($info.Index -lt $Scopes.RootTagStart -or ($info.Index + $info.Length - 1) -gt $Scopes.RootTagEnd) {
        return [pscustomobject]@{
            Ok      = $false
            Code    = 'LASTUPDATE_TARGET_OUTSIDE_ROOT'
            Message = "a primeira ocorrencia casavel de lastUpdate esta fora do intervalo da tag raiz (indice $($info.Index))."
            Info    = $info
        }
    }
    return [pscustomobject]@{ Ok = $true; Code = $null; Message = $null; Info = $info }
}

function Invoke-GeneXusLastUpdateBump {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][object]$Scopes,
        [Parameter(Mandatory = $true)][string]$NewValue,
        [Parameter(Mandatory = $true)][object]$Tracker,
        [Parameter(Mandatory = $true)][string]$OpId,
        [AllowNull()][string]$RootLastUpdateRaw
    )

    $target = Test-GeneXusLastUpdateTarget -Text $Text -Scopes $Scopes -RootLastUpdateRaw $RootLastUpdateRaw
    if (-not $target.Ok) {
        return [pscustomobject]@{ Ok = $false; Code = $target.Code; Message = $target.Message; Text = $Text }
    }

    $patched = Set-FirstObjectLastUpdateInText -Text $Text -NewLastUpdateValue $NewValue
    $newTokenLength = ('lastUpdate="' + $NewValue + '"').Length
    [void](Add-GeneXusMutation -Tracker $Tracker -OpId $OpId -Kind 'lastUpdate' `
        -CurrentStart $target.Info.Index -LengthBefore $target.Info.Length -LengthAfter $newTokenLength)

    return [pscustomobject]@{ Ok = $true; Code = 'PATCHED'; Message = $null; Text = $patched }
}

# ---------------------------------------------------------------------------
# Invariantes de arquivo (Fase 0)
# ---------------------------------------------------------------------------

function Test-GeneXusTargetEncoding {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        return [pscustomobject]@{ Ok = $false; Reason = 'arquivo com BOM UTF-8' }
    }
    if ($bytes.Length -ge 2 -and (($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF))) {
        return [pscustomobject]@{ Ok = $false; Reason = 'arquivo com BOM UTF-16' }
    }
    try {
        $strict = [System.Text.UTF8Encoding]::new($false, $true)
        [void]$strict.GetString($bytes)
    } catch {
        return [pscustomobject]@{ Ok = $false; Reason = "bytes nao sao UTF-8 valido: $($_.Exception.Message)" }
    }
    return [pscustomobject]@{ Ok = $true; Reason = $null }
}

function Test-GeneXusHardLink {
    param([Parameter(Mandatory = $true)][string]$Path)

    $output = & fsutil hardlink list $Path 2>$null
    if ($LASTEXITCODE -ne 0 -or $null -eq $output) {
        return [pscustomobject]@{ Determined = $false; IsHardLink = $false; Links = 0 }
    }
    $lines = @(@($output) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    return [pscustomobject]@{ Determined = $true; IsHardLink = ($lines.Count -gt 1); Links = $lines.Count }
}

function Test-GeneXusWindowsFileName {
    param([Parameter(Mandatory = $true)][string]$FileName)

    if ([string]::IsNullOrWhiteSpace($FileName)) {
        return [pscustomobject]@{ Ok = $false; Reason = 'nome vazio' }
    }
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($character in $FileName.ToCharArray()) {
        if ($invalid -contains $character) {
            return [pscustomobject]@{ Ok = $false; Reason = "caractere invalido no nome de arquivo: '$character'" }
        }
    }
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $reserved = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')
    foreach ($name in $reserved) {
        if ([string]::Equals($baseName, $name, [StringComparison]::OrdinalIgnoreCase)) {
            return [pscustomobject]@{ Ok = $false; Reason = "nome reservado do Windows: '$baseName'" }
        }
    }
    if ($FileName.EndsWith(' ') -or $FileName.EndsWith('.')) {
        return [pscustomobject]@{ Ok = $false; Reason = 'nome terminado em espaco ou ponto' }
    }
    return [pscustomobject]@{ Ok = $true; Reason = $null }
}

function Get-GeneXusAcervoTypeFolderIndex {
    <#
        Indice de guid/nome de UMA pasta de tipo do acervo. Escopo declarado: a
        sanidade de objectState:new e feita contra a pasta do tipo declarado,
        nao contra o acervo inteiro - indexar 15 mil XMLs por rodada nao se
        paga, e homonimo de outro tipo nao colide no layout plano.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$AcervoPath,
        [Parameter(Mandatory = $true)][string]$FolderName
    )

    $byGuid = @{}
    $byName = @{}
    $folder = Join-Path $AcervoPath $FolderName
    if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
        return [pscustomobject]@{ ByGuid = $byGuid; ByName = $byName; Scanned = 0; FolderExists = $false }
    }
    $scanned = 0
    foreach ($file in (Get-ChildItem -LiteralPath $folder -Filter '*.xml' -File)) {
        $scanned++
        $info = Get-GeneXusObjectRootInfo -Text ([System.IO.File]::ReadAllText($file.FullName))
        if (-not $info.Valid) { continue }
        $guid = [string]$info.Attributes['guid']
        $name = [string]$info.Attributes['name']
        if (-not [string]::IsNullOrWhiteSpace($guid)) { $byGuid[$guid.ToLowerInvariant()] = $file.FullName }
        if (-not [string]::IsNullOrWhiteSpace($name)) { $byName[$name.ToLowerInvariant()] = $file.FullName }
    }
    return [pscustomobject]@{ ByGuid = $byGuid; ByName = $byName; Scanned = $scanned; FolderExists = $true }
}

function Get-GeneXusFolderObjectIndex {
    <#
        Grafo de pais: so objetos Folder (acervo + frente). Pequeno o bastante
        para indexar por rodada e suficiente para PARENT_TARGET_MISSING,
        PARENT_TARGET_NOT_FOLDER e PARENT_CYCLE.
    #>
    param([AllowEmptyCollection()][string[]]$Roots)

    $byGuid = @{}
    foreach ($root in $Roots) {
        if ([string]::IsNullOrWhiteSpace($root)) { continue }
        $folder = Join-Path $root 'Folder'
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $folder -Filter '*.xml' -File)) {
            $info = Get-GeneXusObjectRootInfo -Text ([System.IO.File]::ReadAllText($file.FullName))
            if (-not $info.Valid) { continue }
            $guid = [string]$info.Attributes['guid']
            if ([string]::IsNullOrWhiteSpace($guid)) { continue }
            $byGuid[$guid.ToLowerInvariant()] = [pscustomobject]@{
                Path       = $file.FullName
                Name       = [string]$info.Attributes['name']
                Type       = [string]$info.Attributes['type']
                ParentGuid = [string]$info.Attributes['parentGuid']
            }
        }
    }
    return $byGuid
}

function Test-GeneXusParentChain {
    param(
        [Parameter(Mandatory = $true)][hashtable]$FolderIndex,
        [Parameter(Mandatory = $true)][string]$TargetGuid,
        [Parameter(Mandatory = $true)][string]$NewParentGuid
    )

    if ([string]::Equals($TargetGuid, $NewParentGuid, [StringComparison]::OrdinalIgnoreCase)) {
        return [pscustomobject]@{ Ok = $false; Code = 'PARENT_SELF_REFERENCE'; Message = 'o objeto seria pai de si mesmo.' }
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    [void]$seen.Add($TargetGuid)
    $cursor = $NewParentGuid
    while (-not [string]::IsNullOrWhiteSpace($cursor)) {
        if (-not $seen.Add($cursor)) {
            return [pscustomobject]@{ Ok = $false; Code = 'PARENT_CYCLE'; Message = "ciclo no grafo de pais em '$cursor'." }
        }
        $key = $cursor.ToLowerInvariant()
        if (-not $FolderIndex.ContainsKey($key)) { break }
        $cursor = $FolderIndex[$key].ParentGuid
        if ([string]::Equals($cursor, '00000000-0000-0000-0000-000000000000', [StringComparison]::OrdinalIgnoreCase)) { break }
    }
    return [pscustomobject]@{ Ok = $true; Code = $null; Message = $null }
}

# ---------------------------------------------------------------------------
# Orquestracao: Fase 0 -> 1a -> 1b -> 2 (secao 5)
# ---------------------------------------------------------------------------

function New-GeneXusBatchMetadataReport {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Phase,
        [AllowEmptyCollection()][object[]]$Blocks = @(),
        [AllowEmptyCollection()][object[]]$Warnings = @(),
        [AllowEmptyCollection()][object[]]$Files = @(),
        [hashtable]$Extra
    )

    $report = [ordered]@{
        Kind          = 'xpz-batch-metadata-report'
        SchemaVersion = 1
        runId         = $RunId
        status        = $Status
        phase         = $Phase
        atUtc         = [DateTime]::UtcNow.ToString('o')
        blocks        = @($Blocks)
        warnings      = @($Warnings)
        files         = @($Files)
    }
    if ($null -ne $Extra) {
        foreach ($key in $Extra.Keys) { $report[$key] = $Extra[$key] }
    }
    return $report
}

function Invoke-GeneXusXmlBatchMetadataCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$FrontFolder,
        [string]$AcervoPath,
        [string]$WorkDir,
        [switch]$Apply,
        [string]$ReportPath,
        [switch]$AcknowledgeReferences,
        [switch]$RequireHeadWitness,
        [switch]$AllowDegradedAccents,
        [int]$FreshnessMarginSeconds = 60
    )

    $runId = [Guid]::NewGuid().ToString('N')
    $blocks = [System.Collections.Generic.List[object]]::new()
    $warnings = [System.Collections.Generic.List[object]]::new()
    $filesReport = [System.Collections.Generic.List[object]]::new()
    $extra = @{}
    $lockPath = $null
    $journal = $null
    $workDirCreated = $false
    $workDirFull = $null

    try {
        # ------------------------------------------------------------------
        # Fase 0 - preparacao
        # ------------------------------------------------------------------
        if (-not (Test-Path -LiteralPath $FrontFolder -PathType Container)) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'FRONT_NOT_CANONICAL' -Message "frente nao encontrada: $FrontFolder" -Path $FrontFolder))
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks)
        }
        $frontFull = Get-XpzCanonicalPath -Path $FrontFolder
        $frontParent = [System.IO.Directory]::GetParent($frontFull)
        if ($null -eq $frontParent -or -not [string]::Equals($frontParent.Name, (Get-GeneXusFrontCanonicalContainerName), [StringComparison]::OrdinalIgnoreCase)) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'FRONT_NOT_CANONICAL' -Message "a frente precisa estar sob $(Get-GeneXusFrontCanonicalContainerName): $frontFull" -Path $frontFull))
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks)
        }
        $reparse = Get-XpzReparsePointInPath -Path $frontFull
        if ($null -ne $reparse) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'FRONT_NOT_CANONICAL' -Message "ponto de reanalise no caminho da frente: $reparse" -Path $frontFull))
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks)
        }

        $repoRoot = $frontParent.Parent.FullName
        $frontName = [System.IO.Path]::GetFileName($frontFull)
        if ([string]::IsNullOrWhiteSpace($AcervoPath)) { $AcervoPath = Join-Path $repoRoot 'ObjetosDaKbEmXml' }
        $acervoFull = Get-XpzCanonicalPath -Path $AcervoPath
        if ([string]::IsNullOrWhiteSpace($WorkDir)) { $WorkDir = Join-Path (Join-Path (Join-Path $repoRoot 'Temp') 'xpz-batch-metadata') $frontName }
        $workDirFull = Get-XpzCanonicalPath -Path $WorkDir

        $protected = Test-XpzProtectedArea -Candidate $workDirFull -RepoRoot $repoRoot
        if ($protected.blocked) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'PROTECTED_AREA' -Message "-WorkDir em area protegida: $($protected.reason)" -Path $workDirFull))
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks)
        }
        if (Test-XpzPathEqualOrUnder -Candidate $workDirFull -Base $frontFull) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'ARTIFACT_PATH_COLLISION' -Message "-WorkDir nao pode ficar dentro da frente: $workDirFull" -Path $workDirFull))
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks)
        }
        if (-not (Test-Path -LiteralPath $workDirFull -PathType Container)) {
            [void](New-Item -ItemType Directory -Path $workDirFull -Force)
            $workDirCreated = $true
        }

        $reportPathFull = $null
        if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
            if (-not [System.IO.Path]::IsPathRooted($ReportPath)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'ARTIFACT_PATH_COLLISION' -Message '-ReportPath deve ser absoluto.' -Path $ReportPath))
                return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks)
            }
            $reportPathFull = Get-XpzCanonicalPath -Path $ReportPath
            if (Test-XpzPathEqualOrUnder -Candidate $reportPathFull -Base $frontFull) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'ARTIFACT_PATH_COLLISION' -Message "-ReportPath dentro da frente: $reportPathFull" -Path $reportPathFull))
                return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks)
            }
        }

        $lock = Request-GeneXusBatchRunLock -WorkDir $workDirFull -RunId $runId
        if (-not $lock.Acquired) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'RUN_LOCKED' -Message $lock.Reason -Path $lock.Path))
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks)
        }
        $lockPath = $lock.Path
        if ($null -ne $lock.StaleReclaimed) {
            [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'staleLockReclaimed' -Message "lock de processo morto ($($lock.StaleReclaimed.pid)) reaproveitado." -Path $lock.Path))
        }

        $manifestResult = Read-GeneXusBatchManifest -Path $InputPath
        if (-not $manifestResult.Valid) {
            foreach ($block in $manifestResult.Blocks) { [void]$blocks.Add($block) }
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks -Warnings $warnings)
        }

        $catalog = Read-GeneXusObjectTypeCatalogFile -Path (Get-GeneXusObjectTypeCatalogDefaultBasePath)
        $schema = Test-GeneXusBatchManifestOperations -Manifest $manifestResult.Manifest -Catalog $catalog -AllowDegradedAccentsSwitch:$AllowDegradedAccents.IsPresent
        foreach ($block in $schema.Blocks) { [void]$blocks.Add($block) }
        if ($blocks.Count -gt 0) {
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase0' -Blocks $blocks -Warnings $warnings)
        }
        $operations = @($schema.Operations)
        if ($operations.Count -eq 0) {
            $extra['operationCount'] = 0
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'ok' -Phase 'phase1a' -Warnings $warnings -Extra $extra)
        }

        $accentDetector = Get-GeneXusAccentDetector
        $futureTolerance = Get-GeneXusEnvelopeFutureToleranceDefault
        $extra['futureToleranceSeconds'] = $futureTolerance
        $extra['freshnessMarginSeconds'] = $FreshnessMarginSeconds
        $extra['frontFolder'] = $frontFull
        $extra['acervoPath'] = $acervoFull
        $extra['workDir'] = $workDirFull
        $extra['apply'] = [bool]$Apply.IsPresent
        # -AcknowledgeReferences REGISTRA a aceitacao do limite de cobertura da
        # varredura; nao transforma medicao incompleta em autorizacao. Fica no
        # relatorio para que "zero com cobertura incompleta" nunca passe por
        # sucesso silencioso.
        $extra['acknowledgeReferences'] = [bool]$AcknowledgeReferences.IsPresent
        if ($AcknowledgeReferences.IsPresent) {
            [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'referenceLimitAcknowledged' -Message 'o chamador declarou aceitar o limite de cobertura da varredura de referencias; REFERENCE_SCAN_INCOMPLETE continua bloqueando.'))
        }

        # agrupa por arquivo; ordem deterministica dentro do arquivo
        $order = Get-GeneXusBatchOperationOrder
        $groups = [ordered]@{}
        foreach ($operation in $operations) {
            $key = $operation.XmlPath.ToLowerInvariant()
            if (-not $groups.Contains($key)) { $groups[$key] = [System.Collections.Generic.List[object]]::new() }
            [void]$groups[$key].Add($operation)
        }

        $headContext = Get-GeneXusHeadWitnessContext -AcervoPath $acervoFull
        $extra['headWitness'] = $headContext.State
        if ($headContext.State -ne 'available' -and $RequireHeadWitness.IsPresent) {
            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'HEAD_DIVERGENCE' -Message "testemunha de HEAD indisponivel ($($headContext.State)) e -RequireHeadWitness foi passado." -Path $acervoFull))
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase1a' -Blocks $blocks -Warnings $warnings)
        }

        $needsReferenceScan = @($operations | Where-Object { $_.Op -eq 'renameDomain' }).Count -gt 0
        $referenceIndex = $null
        $domainDefinitions = $null
        if ($needsReferenceScan) {
            $referenceIndex = Build-GeneXusDomainReferenceIndex -ScanRoots @($acervoFull, $frontFull)
            $domainDefinitions = Get-GeneXusDomainDefinitionIndex -AcervoPath $acervoFull
            $extra['referenceScanFiles'] = $referenceIndex.FilesScanned
        }

        $needsParentGraph = @($operations | Where-Object { $_.Op -eq 'setParent' }).Count -gt 0
        $folderIndex = $null
        if ($needsParentGraph) {
            $folderIndex = Get-GeneXusFolderObjectIndex -Roots @($acervoFull, $frontFull)
        }

        $typeIndexCache = @{}
        $plans = [System.Collections.Generic.List[object]]::new()

        # ------------------------------------------------------------------
        # Fase 1a - plano (nenhuma escrita persistente)
        # ------------------------------------------------------------------
        foreach ($key in @($groups.Keys)) {
            $groupOperations = @($groups[$key] | Sort-Object -Property @{ Expression = { $order.IndexOf($_.Op) } })
            $first = $groupOperations[0]
            $relativePath = $first.XmlPath
            $targetPath = Get-XpzCanonicalPath -Path (Join-Path $frontFull $relativePath)

            if (-not (Test-XpzPathEqualOrUnder -Candidate $targetPath -Base $frontFull)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'PATH_OUTSIDE_FRONT' -Message "alvo fora da frente: $targetPath" -OpId $first.Id -Path $relativePath))
                continue
            }
            if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'TARGET_FILE_MISSING' -Message "alvo inexistente: $targetPath" -OpId $first.Id -Path $relativePath))
                continue
            }
            $targetItem = Get-Item -LiteralPath $targetPath -Force
            if ($targetItem.IsReadOnly) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'TARGET_NOT_WRITABLE' -Message "alvo somente leitura: $targetPath" -OpId $first.Id -Path $relativePath))
                continue
            }
            $hardLink = Test-GeneXusHardLink -Path $targetPath
            if ($hardLink.Determined -and $hardLink.IsHardLink) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'HARDLINK_REFUSED' -Message "alvo com $($hardLink.Links) hard links: $targetPath" -OpId $first.Id -Path $relativePath))
                continue
            }
            if (-not $hardLink.Determined) {
                [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'hardLinkUndetermined' -Message 'nao foi possivel determinar contagem de hard links (fsutil indisponivel).' -Path $relativePath))
            }
            # Leitura defensiva: alvo aberto por outro processo (a IDE, por
            # exemplo) nao pode derrubar a rodada com erro interno - vira
            # bloqueio nomeado, como qualquer outra recusa da Fase 0.
            $encoding = $null
            $originalText = $null
            try {
                $encoding = Test-GeneXusTargetEncoding -Path $targetPath
                $originalText = [System.IO.File]::ReadAllText($targetPath)
            } catch {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'TARGET_NOT_WRITABLE' -Message "alvo nao pode ser lido: $($_.Exception.Message)" -OpId $first.Id -Path $relativePath))
                continue
            }
            if (-not $encoding.Ok) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'ENCODING_UNEXPECTED' -Message $encoding.Reason -OpId $first.Id -Path $relativePath))
                continue
            }
            $eolProfile = Get-GeneXusTextEolProfile -Text $originalText
            if ($eolProfile.Mixed) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'EOL_MIXED' -Message "EOL misto no alvo (CRLF=$($eolProfile.CrLfCount), LF=$($eolProfile.LoneLfCount), CR=$($eolProfile.LoneCrCount))." -OpId $first.Id -Path $relativePath))
                continue
            }

            $scopes = Get-GeneXusXmlObjectScopes -Text $originalText
            if (-not $scopes.Valid) {
                if ($scopes.Reason -eq 'MULTIPLE_ROOTS') {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MULTIPLE_OBJECT_ROOTS' -Message "mais de um <Object> raiz ($($scopes.RootCount))." -OpId $first.Id -Path $relativePath))
                } else {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message "estrutura de raiz nao resolvida: $($scopes.Reason)" -OpId $first.Id -Path $relativePath))
                }
                continue
            }

            $rootInfo = Get-GeneXusObjectRootInfo -Text $originalText
            if (-not $rootInfo.Valid) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message $rootInfo.Reason -OpId $first.Id -Path $relativePath))
                continue
            }
            $rootAttributes = $rootInfo.Attributes

            $identityOk = $true
            if (-not [string]::Equals([string]$rootAttributes['guid'], $first.Guid, [StringComparison]::OrdinalIgnoreCase)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message "guid do arquivo ('$($rootAttributes['guid'])') difere do declarado ('$($first.Guid)')." -OpId $first.Id -Path $relativePath))
                $identityOk = $false
            }
            if (-not [string]::Equals([string]$rootAttributes['name'], $first.ExpectedName, [StringComparison]::Ordinal)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message "name do arquivo ('$($rootAttributes['name'])') difere do expectedName ('$($first.ExpectedName)')." -OpId $first.Id -Path $relativePath))
                $identityOk = $false
            }
            $catalogEntry = Get-GeneXusJsonProperty -Object $catalog.types -Name $first.ExpectedType
            $catalogTypeGuid = [string](Get-GeneXusJsonProperty -Object $catalogEntry -Name 'objectTypeGuid')
            if (-not [string]::IsNullOrWhiteSpace($catalogTypeGuid) -and
                -not [string]::Equals([string]$rootAttributes['type'], $catalogTypeGuid, [StringComparison]::OrdinalIgnoreCase)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message "type do arquivo ('$($rootAttributes['type'])') difere do tipo declarado '$($first.ExpectedType)'." -OpId $first.Id -Path $relativePath))
                $identityOk = $false
            }
            if (-not $identityOk) { continue }

            if (-not [string]::IsNullOrWhiteSpace([string]$rootAttributes['checksum'])) {
                [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'checksumStale' -Message 'checksum preservado como esta; fica obsoleto apos a edicao.' -OpId $first.Id -Path $relativePath))
            }

            $catalogFolder = [string](Get-GeneXusJsonProperty -Object $catalogEntry -Name 'folderName' -Default $first.ExpectedType)
            if ($first.ObjectState -eq 'new') {
                if (-not $typeIndexCache.ContainsKey($catalogFolder)) {
                    $typeIndexCache[$catalogFolder] = Get-GeneXusAcervoTypeFolderIndex -AcervoPath $acervoFull -FolderName $catalogFolder
                }
                $typeIndex = $typeIndexCache[$catalogFolder]
                if ($typeIndex.ByGuid.ContainsKey($first.Guid.ToLowerInvariant()) -or $typeIndex.ByName.ContainsKey($first.ExpectedName.ToLowerInvariant())) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'NEW_OBJECT_EXISTS_IN_ACERVO' -Message "objeto declarado novo ja existe no acervo (pasta $catalogFolder)." -OpId $first.Id -Path $relativePath))
                    continue
                }
            }

            $acervoTargetPath = Join-Path $acervoFull $relativePath
            $acervoText = $null
            $acervoAttributes = $null
            if (Test-Path -LiteralPath $acervoTargetPath -PathType Leaf) {
                $acervoText = [System.IO.File]::ReadAllText($acervoTargetPath)
                $acervoInfo = Get-GeneXusObjectRootInfo -Text $acervoText
                if ($acervoInfo.Valid) { $acervoAttributes = $acervoInfo.Attributes }
            }

            # testemunha de HEAD: so confronta o expected declarado (secao 11)
            if ($first.ObjectState -eq 'existing' -and $headContext.State -eq 'available' -and $null -ne $acervoText) {
                $headText = Get-GeneXusHeadWitnessText -RepoRoot $headContext.RepoRoot -AbsolutePath $acervoTargetPath
                if ($null -ne $headText) {
                    $headInfo = Get-GeneXusObjectRootInfo -Text $headText
                    if ($headInfo.Valid) {
                        foreach ($operation in $groupOperations) {
                            foreach ($field in @(Get-GeneXusJsonPropertyNames -Object $operation.Expected)) {
                                if ($field -eq 'documentation') { continue }
                                if (-not $headInfo.Attributes.Contains($field)) { continue }
                                $expectedValue = [string](Get-GeneXusJsonProperty -Object $operation.Expected -Name $field)
                                $headValue = [string]$headInfo.Attributes[$field]
                                if (-not [string]::Equals($expectedValue, $headValue, [StringComparison]::Ordinal)) {
                                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'HEAD_DIVERGENCE' -Message "expected.$field ('$expectedValue') nao bate com o acervo em HEAD ('$headValue')." -OpId $operation.Id -Path $relativePath))
                                }
                            }
                        }
                    }
                } else {
                    [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'headWitnessMissingFile' -Message 'arquivo do acervo nao existe em HEAD.' -Path $relativePath))
                }
            }

            $tracker = New-GeneXusMutationTracker
            $text = $originalText
            $groupFailed = $false
            $renamePlan = $null
            $descriptionPreserved = $false

            foreach ($operation in $groupOperations) {
                $scopes = Get-GeneXusXmlObjectScopes -Text $text
                if (-not $scopes.Valid) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MULTIPLE_OBJECT_ROOTS' -Message "escopos irrecuperaveis: $($scopes.Reason)" -OpId $operation.Id -Path $relativePath))
                    $groupFailed = $true
                    break
                }
                $currentRoot = Get-GeneXusObjectRootInfo -Text $text
                if (-not $currentRoot.Valid) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message $currentRoot.Reason -OpId $operation.Id -Path $relativePath))
                    $groupFailed = $true
                    break
                }

                $result = $null
                if ($operation.Op -eq 'setDocumentation') {
                    $result = Invoke-GeneXusSetDocumentationPatch -Text $text -Scopes $scopes -Operation $operation `
                        -Eol $eolProfile.Eol -Tracker $tracker -AccentDetector $accentDetector `
                        -AllowDegradedAccentsSwitch:$AllowDegradedAccents.IsPresent
                } elseif ($operation.Op -eq 'setParent') {
                    $parentGuid = [string](Get-GeneXusJsonProperty -Object $operation.New -Name 'parentGuid')
                    $folderKey = $parentGuid.ToLowerInvariant()
                    if ($null -eq $folderIndex -or -not $folderIndex.ContainsKey($folderKey)) {
                        [void]$blocks.Add((New-GeneXusBatchBlock -Code 'PARENT_TARGET_MISSING' -Message "Folder de destino nao encontrado no acervo nem na frente: $parentGuid" -OpId $operation.Id -Path $relativePath))
                        $groupFailed = $true
                        break
                    }
                    $folderEntry = $folderIndex[$folderKey]
                    if (-not [string]::Equals($folderEntry.Type, (Get-GeneXusFolderTypeGuid), [StringComparison]::OrdinalIgnoreCase)) {
                        [void]$blocks.Add((New-GeneXusBatchBlock -Code 'PARENT_TARGET_NOT_FOLDER' -Message "destino $parentGuid nao e Folder (type=$($folderEntry.Type))." -OpId $operation.Id -Path $relativePath))
                        $groupFailed = $true
                        break
                    }
                    $chain = Test-GeneXusParentChain -FolderIndex $folderIndex -TargetGuid $operation.Guid -NewParentGuid $parentGuid
                    if (-not $chain.Ok) {
                        [void]$blocks.Add((New-GeneXusBatchBlock -Code $chain.Code -Message $chain.Message -OpId $operation.Id -Path $relativePath))
                        $groupFailed = $true
                        break
                    }
                    $result = Invoke-GeneXusSetParentPatch -Text $text -Scopes $scopes -Operation $operation `
                        -RootAttributes $currentRoot.Attributes -Tracker $tracker
                } else {
                    $verdict = Resolve-GeneXusDomainReferenceVerdict -Index $referenceIndex `
                        -TargetName $operation.ExpectedName -TargetGuid $operation.Guid `
                        -TargetModuleName (Get-GeneXusModuleNameByGuid -AcervoPath $acervoFull -ModuleGuid ([string]$currentRoot.Attributes['moduleGuid'])) `
                        -DomainDefinitions $domainDefinitions `
                        -PackagedHomonyms (Test-GeneXusPackagedModuleHomonym -AcervoPath $acervoFull -DomainName $operation.ExpectedName)

                    foreach ($occurrence in $verdict.ReportOnly) {
                        [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'cdataOccurrence' -Message "ocorrencia em CDATA de documentacao (report-only): $($occurrence.path)" -OpId $operation.Id))
                    }
                    foreach ($occurrence in $verdict.CaseInsensitive) {
                        [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'caseInsensitiveMatch' -Message "casamento divergente so na caixa: '$($occurrence.value)' em $($occurrence.path)" -OpId $operation.Id))
                    }
                    if (@($verdict.Blocking).Count -gt 0) {
                        [void]$blocks.Add((New-GeneXusBatchBlock -Code 'DOMAIN_STILL_REFERENCED' -Message "$(@($verdict.Blocking).Count) referencia(s) ao Domain '$($operation.ExpectedName)'." -OpId $operation.Id -Path $relativePath -Detail @($verdict.Blocking | Select-Object -First 20)))
                        $groupFailed = $true
                        break
                    }
                    if (@($verdict.Incomplete).Count -gt 0) {
                        [void]$blocks.Add((New-GeneXusBatchBlock -Code 'REFERENCE_SCAN_INCOMPLETE' -Message "cobertura incompleta da varredura de referencias." -OpId $operation.Id -Path $relativePath -Detail @($verdict.Incomplete | Select-Object -First 20)))
                        $groupFailed = $true
                        break
                    }
                    if ($null -ne $operation.UnusedEvidence) {
                        $evidenceResult = [string](Get-GeneXusJsonProperty -Object $operation.UnusedEvidence -Name 'result')
                        if ($evidenceResult -notmatch '^\s*0\b') {
                            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'DOMAIN_STILL_REFERENCED' -Message "unusedEvidence declara uso: '$evidenceResult'." -OpId $operation.Id -Path $relativePath))
                            $groupFailed = $true
                            break
                        }
                    }

                    $result = Invoke-GeneXusRenameDomainPatch -Text $text -Scopes $scopes -Operation $operation `
                        -RootAttributes $currentRoot.Attributes -Tracker $tracker
                    if ($result.Ok -and $operation.RenameFile) {
                        $newFileName = $result.NewName + [System.IO.Path]::GetExtension($targetPath)
                        $nameCheck = Test-GeneXusWindowsFileName -FileName $newFileName
                        if (-not $nameCheck.Ok) {
                            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'INVALID_FILENAME' -Message $nameCheck.Reason -OpId $operation.Id -Path $relativePath))
                            $groupFailed = $true
                            break
                        }
                        $currentFileName = [System.IO.Path]::GetFileName($targetPath)
                        if ([string]::Equals($currentFileName, $newFileName, [StringComparison]::OrdinalIgnoreCase) -and
                            -not [string]::Equals($currentFileName, $newFileName, [StringComparison]::Ordinal)) {
                            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'RENAME_CASE_ONLY' -Message "rename difere so na caixa: '$currentFileName' -> '$newFileName'." -OpId $operation.Id -Path $relativePath))
                            $groupFailed = $true
                            break
                        }
                        $renamePlan = [pscustomobject]@{
                            OpId    = $operation.Id
                            From    = $targetPath
                            To      = Join-Path ([System.IO.Path]::GetDirectoryName($targetPath)) $newFileName
                            OldName = $result.OldName
                            NewName = $result.NewName
                        }
                    }
                    if ($result.Ok -and $result.DescriptionPreserved) { $descriptionPreserved = $true }
                }

                foreach ($warning in @($result.Warnings)) { [void]$warnings.Add($warning) }
                if (-not $result.Ok) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code $result.Code -Message $result.Message -OpId $operation.Id -Path $relativePath))
                    $groupFailed = $true
                    break
                }
                $text = $result.Text
            }

            if ($groupFailed) { continue }

            $finalScopes = Get-GeneXusXmlObjectScopes -Text $text
            if (-not $finalScopes.Valid) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'MULTIPLE_OBJECT_ROOTS' -Message "escopos irrecuperaveis apos a composicao: $($finalScopes.Reason)" -OpId $first.Id -Path $relativePath))
                continue
            }
            $lastUpdateTarget = Test-GeneXusLastUpdateTarget -Text $text -Scopes $finalScopes -RootLastUpdateRaw ([string]$rootAttributes['lastUpdate'])
            if (-not $lastUpdateTarget.Ok) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code $lastUpdateTarget.Code -Message $lastUpdateTarget.Message -OpId $first.Id -Path $relativePath))
                continue
            }

            $acervoLastUpdate = $null
            if ($null -ne $acervoAttributes) { $acervoLastUpdate = [string]$acervoAttributes['lastUpdate'] }
            $baseline = Resolve-GeneXusBatchLastUpdateBaseline -FrontLastUpdateRaw ([string]$rootAttributes['lastUpdate']) -AcervoLastUpdateRaw $acervoLastUpdate
            if ($baseline.Status -eq 'UNREADABLE') {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'LASTUPDATE_UNREADABLE' -Message "lastUpdate presente porem nao parseavel na fonte '$($baseline.Source)': '$($baseline.Verbatim)'." -OpId $first.Id -Path $relativePath))
                continue
            }
            if ($baseline.Status -eq 'OK' -and $null -ne $baseline.Instant) {
                $anomalyThreshold = [DateTimeOffset]::UtcNow.AddSeconds($futureTolerance)
                if ($baseline.Instant -gt $anomalyThreshold) {
                    [void]$warnings.Add((New-GeneXusBatchWarning -Kind 'baselineFutureAnomaly' -Message "baseline anormalmente futuro ('$($baseline.Verbatim)', fonte $($baseline.Source))." -OpId $first.Id -Path $relativePath))
                }
            }

            # secao 9.1: para objeto novo o limiar e sobre o valor que o motor
            # VAI gravar (entrada + margem), nao sobre a entrada.
            if ($first.ObjectState -eq 'new') {
                $predicted = [DateTimeOffset]::UtcNow.AddSeconds($FreshnessMarginSeconds)
                if ($null -ne $baseline.Instant) {
                    $fromBaseline = $baseline.Instant.AddSeconds($FreshnessMarginSeconds)
                    if ($fromBaseline -gt $predicted) { $predicted = $fromBaseline }
                }
                if ($predicted -gt [DateTimeOffset]::UtcNow.AddSeconds($futureTolerance)) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE' -Message "objeto novo gravaria lastUpdate acima da tolerancia do envelope ($futureTolerance s)." -OpId $first.Id -Path $relativePath))
                    continue
                }
            }

            $wellFormed = Test-GeneXusXmlWellFormed -Text $text
            if (-not $wellFormed.WellFormed) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message "texto planejado nao e XML bem formado: $($wellFormed.ErrorMessage)" -OpId $first.Id -Path $relativePath))
                continue
            }
            if (-not (Test-GeneXusByteIdentityOutsideMutations -OriginalText $originalText -FinalText $text -Tracker $tracker)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message 'texto planejado difere do original fora dos intervalos declarados.' -OpId $first.Id -Path $relativePath))
                continue
            }

            [void]$plans.Add([pscustomobject]@{
                RelativePath   = $relativePath
                TargetPath     = $targetPath
                OriginalText   = $originalText
                OriginalHash   = (Get-GeneXusTextSha256 -Text $originalText)
                PlannedText    = $text
                Tracker        = $tracker
                Operations     = $groupOperations
                Baseline       = $baseline
                RootAttributes = $rootAttributes
                AcervoPath     = $acervoTargetPath
                AcervoHash     = $(if ($null -ne $acervoText) { Get-GeneXusTextSha256 -Text $acervoText } else { $null })
                RenamePlan     = $renamePlan
                DescriptionPreserved = $descriptionPreserved
                EolProfile     = $eolProfile
            })
        }

        # colisoes e ciclos de rename, antes do primeiro rename
        $renamePlans = @($plans | Where-Object { $null -ne $_.RenamePlan } | ForEach-Object { $_.RenamePlan })
        if ($renamePlans.Count -gt 0) {
            $destinations = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $sources = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($rename in $renamePlans) { [void]$sources.Add($rename.From) }
            foreach ($rename in $renamePlans) {
                if (-not $destinations.Add($rename.To)) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'NAME_COLLISION' -Message "dois renomes apontam para o mesmo destino: $($rename.To)" -OpId $rename.OpId))
                    continue
                }
                if ($sources.Contains($rename.To)) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'RENAME_CYCLE' -Message "destino do rename e origem de outro rename do lote: $($rename.To)" -OpId $rename.OpId))
                    continue
                }
                if (Test-Path -LiteralPath $rename.To) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'NAME_COLLISION' -Message "destino do rename ja existe na frente: $($rename.To)" -OpId $rename.OpId))
                    continue
                }
                $acervoDestination = Join-Path (Join-Path $acervoFull ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetRelativePath($frontFull, $rename.To)))) ([System.IO.Path]::GetFileName($rename.To))
                if (Test-Path -LiteralPath $acervoDestination) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'NAME_COLLISION' -Message "destino do rename ja existe no acervo: $acervoDestination" -OpId $rename.OpId))
                }
            }
        }

        foreach ($plan in $plans) {
            [void]$filesReport.Add([ordered]@{
                path        = $plan.RelativePath
                operations  = @($plan.Operations | ForEach-Object { $_.Id })
                mutations   = @($plan.Tracker.Mutations | ForEach-Object {
                        [ordered]@{ opId = $_.OpId; kind = $_.Kind; originalStart = $_.OriginalStart; originalLength = $_.OriginalLength; finalStart = $_.FinalStart; finalLength = $_.FinalLength }
                    })
                baselineSource = $plan.Baseline.Source
                renameTo    = $(if ($null -ne $plan.RenamePlan) { [System.IO.Path]::GetFileName($plan.RenamePlan.To) } else { $null })
                descriptionPreservedByDivergence = $plan.DescriptionPreserved
            })
        }

        if ($blocks.Count -gt 0) {
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase1a' -Blocks $blocks -Warnings $warnings -Files $filesReport -Extra $extra)
        }
        if (-not $Apply.IsPresent) {
            $extra['applied'] = $false
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'planned' -Phase 'phase1a' -Warnings $warnings -Files $filesReport -Extra $extra)
        }

        # ------------------------------------------------------------------
        # Fase 1b - materializacao da recuperacao
        # ------------------------------------------------------------------
        $journalPath = Join-Path $workDirFull "$runId.journal.json"
        $journal = New-GeneXusBatchJournal -Path $journalPath -RunId $runId -WorkDir $workDirFull
        $extra['journalPath'] = $journalPath

        foreach ($plan in $plans) {
            $bakName = "$runId." + [System.IO.Path]::GetFileName($plan.TargetPath) + '.bak'
            $bakPath = Join-Path $workDirFull $bakName
            if (Test-Path -LiteralPath $bakPath) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'BAK_EXISTS' -Message "backup preexistente em -WorkDir: $bakPath" -Path $plan.RelativePath))
                continue
            }
            $frontBak = $plan.TargetPath + '.bak'
            if (Test-Path -LiteralPath $frontBak) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'BAK_EXISTS' -Message "backup orfao dentro da frente (convencao de outro motor): $frontBak" -Path $plan.RelativePath))
                continue
            }
            [System.IO.File]::Copy($plan.TargetPath, $bakPath, $false)
            $plan | Add-Member -NotePropertyName BakPath -NotePropertyValue $bakPath -Force

            $baselinePath = Join-Path $workDirFull ("$runId." + $plan.Operations[0].Id + '.baseline.xml')
            $lastUpdateValue = $null
            if ($plan.Baseline.Status -eq 'NO_BASELINE') {
                $lastUpdateValue = Get-NewGeneXusLastUpdateValueFromEngine -FreshnessMarginSeconds $FreshnessMarginSeconds
            } else {
                [void](New-GeneXusSyntheticBaselineXml -Path $baselinePath -LastUpdateVerbatim $plan.Baseline.Verbatim -TempDir $workDirFull)
                $lastUpdateValue = Get-NewGeneXusLastUpdateValueFromEngine -BaselineXmlPath $baselinePath -FreshnessMarginSeconds $FreshnessMarginSeconds
            }
            $plan | Add-Member -NotePropertyName BaselineArtifact -NotePropertyValue $baselinePath -Force

            if ($plan.Operations[0].ObjectState -eq 'new') {
                $written = ConvertTo-GeneXusLastUpdateInstant -Value $lastUpdateValue
                if ($written.Parsed -and $written.Instant -gt [DateTimeOffset]::UtcNow.AddSeconds($futureTolerance)) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'NEW_OBJECT_LASTUPDATE_TOO_FAR_FUTURE' -Message "valor que o motor gravaria ('$lastUpdateValue') passa a tolerancia do envelope ($futureTolerance s)." -Path $plan.RelativePath))
                    continue
                }
            }

            $finalScopes = Get-GeneXusXmlObjectScopes -Text $plan.PlannedText
            $bump = Invoke-GeneXusLastUpdateBump -Text $plan.PlannedText -Scopes $finalScopes -NewValue $lastUpdateValue `
                -Tracker $plan.Tracker -OpId $plan.Operations[0].Id -RootLastUpdateRaw ([string]$plan.RootAttributes['lastUpdate'])
            if (-not $bump.Ok) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code $bump.Code -Message $bump.Message -Path $plan.RelativePath))
                continue
            }
            $plan | Add-Member -NotePropertyName FinalText -NotePropertyValue $bump.Text -Force
            $plan | Add-Member -NotePropertyName LastUpdateValue -NotePropertyValue $lastUpdateValue -Force

            $wellFormed = Test-GeneXusXmlWellFormed -Text $bump.Text
            if (-not $wellFormed.WellFormed) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message "texto final nao e XML bem formado: $($wellFormed.ErrorMessage)" -Path $plan.RelativePath))
                continue
            }
            if (-not (Test-GeneXusByteIdentityOutsideMutations -OriginalText $plan.OriginalText -FinalText $bump.Text -Tracker $plan.Tracker)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'IDENTITY_MISMATCH' -Message 'texto final difere do original fora dos intervalos declarados.' -Path $plan.RelativePath))
                continue
            }
        }

        if ($blocks.Count -gt 0) {
            $extra['journalPreserved'] = $true
            $extra['bakPreserved'] = @($plans | Where-Object { $null -ne $_.PSObject.Properties['BakPath'] } | ForEach-Object { $_.BakPath })
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase1b' -Blocks $blocks -Warnings $warnings -Files $filesReport -Extra $extra)
        }

        # ------------------------------------------------------------------
        # Fase 2 - aplicacao
        # ------------------------------------------------------------------
        foreach ($plan in $plans) {
            $currentHash = Get-GeneXusFileSha256 -Path $plan.TargetPath
            if (-not [string]::Equals($currentHash, $plan.OriginalHash, [StringComparison]::Ordinal)) {
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'PLAN_STALE' -Message "alvo mudou entre o plano e a aplicacao: $($plan.RelativePath)" -Path $plan.RelativePath))
            }
            if ($null -ne $plan.AcervoHash -and (Test-Path -LiteralPath $plan.AcervoPath -PathType Leaf)) {
                $acervoHashNow = Get-GeneXusFileSha256 -Path $plan.AcervoPath
                if (-not [string]::Equals($acervoHashNow, $plan.AcervoHash, [StringComparison]::Ordinal)) {
                    [void]$blocks.Add((New-GeneXusBatchBlock -Code 'PLAN_STALE' -Message "arquivo do acervo consultado mudou: $($plan.AcervoPath)" -Path $plan.RelativePath))
                }
            }
        }
        if ($blocks.Count -gt 0) {
            $extra['journalPreserved'] = $true
            $extra['bakPreserved'] = @($plans | Where-Object { $null -ne $_.PSObject.Properties['BakPath'] } | ForEach-Object { $_.BakPath })
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'blocked' -Phase 'phase2' -Blocks $blocks -Warnings $warnings -Files $filesReport -Extra $extra)
        }

        $writtenPlans = [System.Collections.Generic.List[object]]::new()
        $renamesDone = [System.Collections.Generic.List[object]]::new()
        $failure = $null

        foreach ($plan in $plans) {
            try {
                $hashBefore = Get-GeneXusFileSha256 -Path $plan.TargetPath
                if (-not [string]::Equals($hashBefore, $plan.OriginalHash, [StringComparison]::Ordinal)) {
                    throw "SOURCE_CHANGED: $($plan.RelativePath)"
                }
                $hardLinkNow = Test-GeneXusHardLink -Path $plan.TargetPath
                if ($hardLinkNow.Determined -and $hardLinkNow.IsHardLink) {
                    throw "HARDLINK_REFUSED: $($plan.RelativePath)"
                }
                [void](Add-GeneXusBatchJournalStep -Journal $journal -OpId $plan.Operations[0].Id -Action 'write' -State 'started' `
                        -PathBefore $plan.TargetPath -PathAfter $plan.TargetPath -BakPath $plan.BakPath -HashBefore $hashBefore)
                [void](Write-XpzTextFileAtomic -Path $plan.TargetPath -Text $plan.FinalText -TempDir $workDirFull -ReplaceExisting)
                $hashAfter = Get-GeneXusFileSha256 -Path $plan.TargetPath
                [void](Add-GeneXusBatchJournalStep -Journal $journal -OpId $plan.Operations[0].Id -Action 'write' -State 'committed' `
                        -PathBefore $plan.TargetPath -PathAfter $plan.TargetPath -BakPath $plan.BakPath -HashBefore $hashBefore -HashAfter $hashAfter)
                [void]$writtenPlans.Add($plan)
            } catch {
                $failure = $_.Exception.Message
                break
            }
        }

        if ($null -eq $failure) {
            foreach ($plan in $plans) {
                if ($null -eq $plan.RenamePlan) { continue }
                try {
                    [void](Add-GeneXusBatchJournalStep -Journal $journal -OpId $plan.RenamePlan.OpId -Action 'rename' -State 'started' `
                            -PathBefore $plan.RenamePlan.From -PathAfter $plan.RenamePlan.To -BakPath $plan.BakPath)
                    [System.IO.File]::Move($plan.RenamePlan.From, $plan.RenamePlan.To)
                    [void]$renamesDone.Add($plan.RenamePlan)
                    [void](Add-GeneXusBatchJournalStep -Journal $journal -OpId $plan.RenamePlan.OpId -Action 'rename' -State 'committed' `
                            -PathBefore $plan.RenamePlan.From -PathAfter $plan.RenamePlan.To -BakPath $plan.BakPath)
                } catch {
                    $failure = $_.Exception.Message
                    break
                }
            }
        }

        if ($null -ne $failure) {
            $rollbackErrors = [System.Collections.Generic.List[object]]::new()
            for ($i = $renamesDone.Count - 1; $i -ge 0; $i--) {
                $rename = $renamesDone[$i]
                try {
                    [System.IO.File]::Move($rename.To, $rename.From)
                } catch {
                    [void]$rollbackErrors.Add("rename nao desfeito: $($rename.To) -> $($rename.From): $($_.Exception.Message)")
                }
            }
            foreach ($plan in $writtenPlans) {
                try {
                    [System.IO.File]::Copy($plan.BakPath, $plan.TargetPath, $true)
                    $restoredHash = Get-GeneXusFileSha256 -Path $plan.TargetPath
                    $bakHash = Get-GeneXusFileSha256 -Path $plan.BakPath
                    if (-not [string]::Equals($restoredHash, $bakHash, [StringComparison]::Ordinal)) {
                        [void]$rollbackErrors.Add("restauracao divergente do .bak: $($plan.TargetPath)")
                    }
                } catch {
                    [void]$rollbackErrors.Add("restauracao falhou: $($plan.TargetPath): $($_.Exception.Message)")
                }
            }

            [void]$blocks.Add((New-GeneXusBatchBlock -Code 'SOURCE_CHANGED' -Message "aplicacao interrompida: $failure"))
            $extra['journalPath'] = $journalPath
            $extra['bakPreserved'] = @($plans | Where-Object { $null -ne $_.PSObject.Properties['BakPath'] } | ForEach-Object { $_.BakPath })
            if ($rollbackErrors.Count -gt 0) {
                $extra['rollbackErrors'] = @($rollbackErrors)
                [void]$blocks.Add((New-GeneXusBatchBlock -Code 'ROLLBACK_INCOMPLETE' -Message 'restauracao incompleta; nao apague os .bak listados.'))
                return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'rollbackIncomplete' -Phase 'phase2' -Blocks $blocks -Warnings $warnings -Files $filesReport -Extra $extra)
            }
            return (New-GeneXusBatchMetadataReport -RunId $runId -Status 'rollbackComplete' -Phase 'phase2' -Blocks $blocks -Warnings $warnings -Files $filesReport -Extra $extra)
        }

        $status = 'ok'
        if (@($warnings | Where-Object { $_.kind -eq 'checksumStale' }).Count -gt 0) { $status = 'checksumStale' }
        if (@($plans | Where-Object { $_.DescriptionPreserved }).Count -gt 0 -and $status -eq 'ok') { $status = 'descriptionPreserved' }
        $extra['applied'] = $true
        $extra['bakPreserved'] = @($plans | ForEach-Object { $_.BakPath })
        return (New-GeneXusBatchMetadataReport -RunId $runId -Status $status -Phase 'phase2' -Warnings $warnings -Files $filesReport -Extra $extra)
    } finally {
        if ($null -ne $lockPath) { Remove-GeneXusBatchRunLock -LockPath $lockPath }
        # Sem -Apply a rodada nao deixa artefato persistente: se o -WorkDir foi
        # criado por esta rodada e ficou vazio, ele tambem sai.
        if (-not $Apply.IsPresent -and $workDirCreated -and $null -ne $workDirFull -and (Test-Path -LiteralPath $workDirFull -PathType Container)) {
            if (@(Get-ChildItem -LiteralPath $workDirFull -Force).Count -eq 0) {
                Remove-Item -LiteralPath $workDirFull -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
