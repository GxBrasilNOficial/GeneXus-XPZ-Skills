#requires -Version 7.4
<#
.SYNOPSIS
    Funções compartilhadas para edicao cirurgica de XML GeneXus em modo raw.
#>

Set-StrictMode -Version Latest

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$script:LastUpdateAttributePattern = [regex]::new('lastUpdate="([0-9T:.\-Z]+)"')
$script:LastUpdateToken = 'lastUpdate="'
$script:FreshnessMarginSecondsDefault = 60
$script:MutatedIntervalLimit = 100

# ---------------------------------------------------------------------------
# EOL (descido do motor em lote; contrato identico ao consumido por la)
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

function Get-GeneXusEolToken {
    <#
        Token de EOL a partir do perfil. Nao usar .Eol: ele cai em LF quando o
        texto nao tem quebra alguma, o que colapsaria NONE em LF. Por isso a
        derivacao e pelas contagens.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Profile
    )

    $total = $Profile.CrLfCount + $Profile.LoneLfCount + $Profile.LoneCrCount
    if ($total -eq 0) { return 'NONE' }
    if ($Profile.Mixed) { return 'MIXED' }
    if ($Profile.CrLfCount -gt 0) { return 'CRLF' }
    if ($Profile.LoneCrCount -gt 0) { return 'CR' }
    return 'LF'
}

function Get-GeneXusReplacementEolMismatch {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Replacement,

        [Parameter(Mandatory = $true)]
        [string]$SourceToken
    )

    $replProfile = Get-GeneXusTextEolProfile -Text $Replacement
    $replTotal = $replProfile.CrLfCount + $replProfile.LoneLfCount + $replProfile.LoneCrCount
    if ($replTotal -eq 0) { return $false }
    if ($SourceToken -eq 'MIXED') { return $null }
    if ($SourceToken -eq 'NONE') { return $false }

    $replToken = Get-GeneXusEolToken -Profile $replProfile
    if ($replToken -eq 'MIXED') { return $true }
    if ($replToken -ne $SourceToken) { return $true }
    return $false
}

# ---------------------------------------------------------------------------
# Enumeracao literal nao sobreposta (fonte unica de contagem e aplicacao)
# ---------------------------------------------------------------------------

function Get-GeneXusXmlAnchorOccurrenceIndexes {
    <#
        [int[]] de indices nao sobrepostos, esquerda->direita, comparacao
        Ordinal. Ancora vazia devolve array vazio.

        Desvio declarado da v6 §4.1: o idioma "return ,$indexes" somado a
        "@(...)" no chamador NAO achata (verificado: @(f).Count = 1 para um
        array de 2). Por isso a funcao devolve o array puro e o chamador
        materializa com @(...), que entao achata corretamente.
    #>
    [OutputType([int[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Anchor
    )

    if ([string]::IsNullOrEmpty($Anchor)) {
        return @()
    }

    $indexes = [System.Collections.Generic.List[int]]::new()
    $limit = $Text.Length - $Anchor.Length
    $cursor = 0
    while ($cursor -le $limit) {
        $index = $Text.IndexOf($Anchor, $cursor, [System.StringComparison]::Ordinal)
        if ($index -lt 0) { break }
        [void]$indexes.Add($index)
        $cursor = $index + $Anchor.Length
    }
    return $indexes.ToArray()
}

function Get-AnchorOccurrenceCount {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Anchor
    )

    return ([int[]]@(Get-GeneXusXmlAnchorOccurrenceIndexes -Text $Text -Anchor $Anchor)).Count
}

# ---------------------------------------------------------------------------
# Identidade de caracteres fora de intervalos
# ---------------------------------------------------------------------------

function Remove-GeneXusIntervals {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Intervals
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

function Test-GeneXusXmlCharIdentityOutsideMutations {
    <#
        Identidade de CARACTERES (strings, Ordinal) fora da uniao dos
        intervalos. Recebe os dois conjuntos {Start;Length} — original e final.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$OriginalText,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$FinalText,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$OriginalIntervals,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$FinalIntervals
    )

    $strippedOriginal = Remove-GeneXusIntervals -Text $OriginalText -Intervals $OriginalIntervals
    $strippedFinal = Remove-GeneXusIntervals -Text $FinalText -Intervals $FinalIntervals
    return [string]::Equals($strippedOriginal, $strippedFinal, [System.StringComparison]::Ordinal)
}

# ---------------------------------------------------------------------------
# Leitura/escrita de lastUpdate (inalterado)
# ---------------------------------------------------------------------------

function Get-FirstObjectLastUpdateFromText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $match = $script:LastUpdateAttributePattern.Match($Text)
    if (-not $match.Success) {
        return $null
    }

    return [pscustomobject]@{
        Value = $match.Groups[1].Value
        Index = $match.Index
        Length = $match.Length
    }
}

function Get-NewGeneXusLastUpdateValueFromEngine {
    <#
        -BaselineXmlPath e OPCIONAL: quando omitido (ou vazio), o valor e
        UtcNow + margem, comportamento herdado de Get-GeneXusXpzLastUpdate.ps1,
        que ja aceita o parametro como opcional. O ramo sem baseline e exigido
        pelo chamador em lote quando nem o alvo nem o acervo tem lastUpdate
        legivel.
    #>
    param(
        [string]$BaselineXmlPath,

        [int]$FreshnessMarginSeconds = $script:FreshnessMarginSecondsDefault
    )

    $enginePath = Join-Path $PSScriptRoot 'Get-GeneXusXpzLastUpdate.ps1'
    if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
        throw "Motor Get-GeneXusXpzLastUpdate.ps1 nao encontrado: $enginePath"
    }

    if ([string]::IsNullOrWhiteSpace($BaselineXmlPath)) {
        $timestamp = & $enginePath -FreshnessMarginSeconds $FreshnessMarginSeconds -Count 1
    } else {
        $timestamp = & $enginePath -BaselineXmlPath $BaselineXmlPath -FreshnessMarginSeconds $FreshnessMarginSeconds -Count 1
    }
    return [string]$timestamp
}

function Set-FirstObjectLastUpdateInText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$NewLastUpdateValue
    )

    $current = Get-FirstObjectLastUpdateFromText -Text $Text
    if ($null -eq $current) {
        throw 'NO_LASTUPDATE: XML sem lastUpdate="..." na primeira ocorrencia.'
    }

    $replacementToken = 'lastUpdate="' + $NewLastUpdateValue + '"'
    return $Text.Substring(0, $current.Index) + $replacementToken + $Text.Substring($current.Index + $current.Length)
}

# ---------------------------------------------------------------------------
# Primitivo e patch indexado
# ---------------------------------------------------------------------------

function Invoke-GeneXusXmlLiteralPatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Anchor,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Replacement,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Replace', 'InsertAfter', 'InsertBefore')]
        [string]$EditMode
    )

    $index = $Text.IndexOf($Anchor, [System.StringComparison]::Ordinal)
    if ($index -lt 0) {
        throw 'ANCHOR_FAIL: ancora nao encontrada para patch literal.'
    }

    if ($EditMode -eq 'Replace') {
        return $Text.Substring(0, $index) + $Replacement + $Text.Substring($index + $Anchor.Length)
    }

    if ($EditMode -eq 'InsertBefore') {
        return $Text.Substring(0, $index) + $Replacement + $Text.Substring($index)
    }

    $insertAt = $index + $Anchor.Length
    return $Text.Substring(0, $insertAt) + $Replacement + $Text.Substring($insertAt)
}

function Invoke-GeneXusXmlIndexedPatch {
    <#
        Aplica o patch em varios indices literais NAO sobrepostos. Aplica de
        tras para frente com StringBuilder e devolve, alem do texto, os indices
        aplicados e o mapa de mutacoes (OriginalStart;OriginalLength;
        FinalStart;FinalLength) em ordem de documento.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Anchor,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Replacement,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Replace', 'InsertAfter')]
        [string]$EditMode,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [int[]]$Indexes
    )

    $ordered = @($Indexes) | Sort-Object -Descending
    $builder = [System.Text.StringBuilder]::new($Text)
    $applied = [System.Collections.Generic.List[int]]::new()
    $mutations = [System.Collections.Generic.List[object]]::new()

    foreach ($idx in $ordered) {
        if ($idx -lt 0 -or ($idx + $Anchor.Length) -gt $Text.Length) { continue }
        if (-not [string]::Equals($Text.Substring($idx, $Anchor.Length), $Anchor, [System.StringComparison]::Ordinal)) { continue }

        if ($EditMode -eq 'Replace') {
            [void]$builder.Remove($idx, $Anchor.Length)
            [void]$builder.Insert($idx, $Replacement)
            [void]$applied.Add($idx)
            [void]$mutations.Add([pscustomobject]@{
                OriginalStart  = $idx
                OriginalLength = $Anchor.Length
                FinalStart     = $idx
                FinalLength    = $Replacement.Length
            })
        } else {
            $insertAt = $idx + $Anchor.Length
            [void]$builder.Insert($insertAt, $Replacement)
            [void]$applied.Add($idx)
            [void]$mutations.Add([pscustomobject]@{
                OriginalStart  = $insertAt
                OriginalLength = 0
                FinalStart     = $insertAt
                FinalLength    = $Replacement.Length
            })
        }
    }

    # FinalStart em coordenadas finais: acumula os deltas das mutacoes anteriores.
    $orderedMutations = @($mutations | Sort-Object -Property OriginalStart)
    $delta = 0
    foreach ($m in $orderedMutations) {
        $m.FinalStart = $m.OriginalStart + $delta
        $delta += ($m.FinalLength - $m.OriginalLength)
    }

    return [pscustomobject]@{
        Text           = $builder.ToString()
        AppliedIndexes = [int[]]@($applied | Sort-Object)
        Mutations      = [object[]]@($orderedMutations)
    }
}

function Test-GeneXusXmlWellFormed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    try {
        $doc = New-Object System.Xml.XmlDocument
        $doc.PreserveWhitespace = $true
        $doc.LoadXml($Text)
        return [pscustomobject]@{
            WellFormed = $true
            ErrorMessage = $null
        }
    } catch {
        return [pscustomobject]@{
            WellFormed = $false
            ErrorMessage = $_.Exception.Message
        }
    }
}

function Get-ReplacementPreview {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [int]$MaxLength = 200
    )

    if ($null -eq $Text) {
        return ''
    }

    if ($Text.Length -le $MaxLength) {
        return $Text
    }

    return $Text.Substring(0, $MaxLength) + '...'
}

function New-GeneXusXmlSurgicalError {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [int]$ExitCode,

        [object]$Details = $null
    )

    return [pscustomobject]@{
        Status    = 'ERROR'
        Code      = $Code
        Message   = $Message
        ExitCode  = $ExitCode
        Details   = $Details
    }
}

# ---------------------------------------------------------------------------
# Verificacoes internas do core
# ---------------------------------------------------------------------------

function Test-GeneXusMutationDisjunction {
    <#
        Mutacoes de ancora disjuntas dois a dois, em coordenadas originais e
        semantica de intervalo semiaberto [Start,Start+Length).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Mutations
    )

    $ordered = @($Mutations | Sort-Object -Property OriginalStart)
    for ($i = 1; $i -lt $ordered.Count; $i++) {
        $prev = $ordered[$i - 1]
        $cur = $ordered[$i]
        $prevEnd = $prev.OriginalStart + $prev.OriginalLength
        if ($cur.OriginalStart -lt $prevEnd) { return $false }
    }
    return $true
}

function Test-GeneXusFinalTextPostCondition {
    <#
        Pos-condicao por mutacao (slice == conteudo esperado, tratando
        comprimento zero) + strip-both de caracteres, sobre o conjunto
        completo (ancoras + lastUpdate) no texto final.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$FinalText,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$AnchorMutations,

        [object]$LastUpdateMutation,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$OriginalText
    )

    foreach ($m in $AnchorMutations) {
        if ($m.FinalLength -eq 0) {
            if (-not [string]::IsNullOrEmpty($m.Expected)) { return $false }
            continue
        }
        if (($m.FinalStart + $m.FinalLength) -gt $FinalText.Length) { return $false }
        $slice = $FinalText.Substring($m.FinalStart, $m.FinalLength)
        if (-not [string]::Equals($slice, $m.Expected, [System.StringComparison]::Ordinal)) { return $false }
    }

    $originalIntervals = @()
    $finalIntervals = @()
    foreach ($m in $AnchorMutations) {
        $originalIntervals += [pscustomobject]@{ Start = $m.OriginalStart; Length = $m.OriginalLength }
        $finalIntervals += [pscustomobject]@{ Start = $m.FinalStart; Length = $m.FinalLength }
    }
    if ($null -ne $LastUpdateMutation) {
        $originalIntervals += [pscustomobject]@{ Start = $LastUpdateMutation.OriginalStart; Length = $LastUpdateMutation.OriginalLength }
        $finalIntervals += [pscustomobject]@{ Start = $LastUpdateMutation.FinalStart; Length = $LastUpdateMutation.FinalLength }
    }

    return (Test-GeneXusXmlCharIdentityOutsideMutations -OriginalText $OriginalText -FinalText $FinalText -OriginalIntervals $originalIntervals -FinalIntervals $finalIntervals)
}

function Get-GeneXusMutatedIntervals {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$AnchorMutations,

        [object]$LastUpdateMutation
    )

    $ordered = @($AnchorMutations | Sort-Object -Property OriginalStart)
    $anchor = @()
    foreach ($m in $ordered) {
        if ($anchor.Count -ge $script:MutatedIntervalLimit) { break }
        $anchor += [pscustomobject]@{
            OriginalStart  = $m.OriginalStart
            OriginalLength = $m.OriginalLength
            FinalStart     = $m.FinalStart
            FinalLength    = $m.FinalLength
        }
    }

    $total = $ordered.Count
    return [pscustomobject]@{
        anchor     = $anchor
        lastUpdate = $LastUpdateMutation
        total      = $total
        truncated  = ($total -gt $script:MutatedIntervalLimit)
        limit      = $script:MutatedIntervalLimit
    }
}

# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

function Invoke-GeneXusXmlSurgicalEditCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Anchor,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Replacement,

        # Subconjunto intencional: este core (consumido pelo wrapper geral
        # Edit-GeneXusXmlSurgical.ps1) só expoe Replace/InsertAfter, pois não ha
        # caso de uso para InsertBefore por aqui. O primitivo
        # Invoke-GeneXusXmlLiteralPatch aceita também InsertBefore, consumido
        # diretamente pelo Add-GeneXusButton.ps1 (ancora -BeforeControlName).
        [Parameter(Mandatory = $true)]
        [ValidateSet('Replace', 'InsertAfter')]
        [string]$EditMode,

        [int]$ExpectedAnchorCount = 1,

        [switch]$ApplyToAllOccurrences,

        [switch]$PreserveLastUpdate,

        [string]$LastUpdateBaselinePath,

        [switch]$DryRun,

        [bool]$AssertWellFormedAfter = $true
    )

    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        return (New-GeneXusXmlSurgicalError -Code 'INPUT_NOT_FOUND' -Message "INPUT_NOT_FOUND: arquivo nao encontrado: $InputPath" -ExitCode 14)
    }

    $resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
    $resolvedOutput = $resolvedInput
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        $outputParent = [System.IO.Path]::GetDirectoryName($OutputPath)
        if ([string]::IsNullOrWhiteSpace($outputParent) -or -not (Test-Path -LiteralPath $outputParent -PathType Container)) {
            return (New-GeneXusXmlSurgicalError -Code 'OUTPUT_DIR_MISSING' -Message "OUTPUT_DIR_MISSING: diretorio nao existe: $outputParent" -ExitCode 15)
        }
        $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    }

    # 1) Le o texto.
    $sourceText = [System.IO.File]::ReadAllText($resolvedInput)
    $bytesBefore = [System.Text.Encoding]::UTF8.GetByteCount($sourceText)

    # 2) Ancora vazia.
    if ([string]::IsNullOrEmpty($Anchor)) {
        return (New-GeneXusXmlSurgicalError -Code 'ANCHOR_EMPTY' -Message 'ANCHOR_EMPTY: -Anchor vazio; informe a substring literal.' -ExitCode 27)
    }

    # 3) Contagem esperada invalida (sem teto superior).
    if ($ExpectedAnchorCount -lt 1) {
        return (New-GeneXusXmlSurgicalError -Code 'EXPECTED_ANCHOR_COUNT_INVALID' -Message "EXPECTED_ANCHOR_COUNT_INVALID: ExpectedAnchorCount=$ExpectedAnchorCount (minimo 1)." -ExitCode 17)
    }

    # 4) Enumeracao literal nao sobreposta.
    $indexes = [int[]]@(Get-GeneXusXmlAnchorOccurrenceIndexes -Text $sourceText -Anchor $Anchor)
    if ($indexes.Count -ne $ExpectedAnchorCount) {
        return (New-GeneXusXmlSurgicalError -Code 'ANCHOR_FAIL' -Message "ANCHOR_FAIL: contagem=$($indexes.Count) esperada=$ExpectedAnchorCount" -ExitCode 11 -Details ([pscustomobject]@{ anchorCount = $indexes.Count }))
    }

    # 5) Ambiguidade sem switch.
    if ($indexes.Count -gt 1 -and -not $ApplyToAllOccurrences.IsPresent) {
        return (New-GeneXusXmlSurgicalError -Code 'AMBIGUOUS_APPLY_SCOPE' -Message "AMBIGUOUS_APPLY_SCOPE: $($indexes.Count) ocorrencias; informe -ExpectedAnchorCount $($indexes.Count) e -ApplyToAllOccurrences para aplicar em todas." -ExitCode 18 -Details ([pscustomobject]@{ anchorCount = $indexes.Count }))
    }

    # 6) Escopo.
    if ($ApplyToAllOccurrences.IsPresent) {
        $scopedIndexes = [int[]]$indexes
    } else {
        $scopedIndexes = [int[]]@($indexes[0])
    }
    $scopeIntended = $scopedIndexes.Count

    # 7) No-op.
    $isNoop = $false
    if ($EditMode -eq 'InsertAfter' -and [string]::IsNullOrEmpty($Replacement)) { $isNoop = $true }
    if ($EditMode -eq 'Replace' -and [string]::Equals($Replacement, $Anchor, [System.StringComparison]::Ordinal)) { $isNoop = $true }
    if ($isNoop) {
        return (New-GeneXusXmlSurgicalError -Code 'NOOP_REPLACEMENT' -Message 'NOOP_REPLACEMENT: a operacao nao altera o texto.' -ExitCode 26)
    }

    # 8) Patch indexado.
    $patch = Invoke-GeneXusXmlIndexedPatch -Text $sourceText -Anchor $Anchor -Replacement $Replacement -EditMode $EditMode -Indexes $scopedIndexes
    $patchedText = $patch.Text
    $anchorMutations = @($patch.Mutations)
    $replacementsApplied = $patch.AppliedIndexes.Count

    # 9) Gate de aplicacao.
    if ($replacementsApplied -ne $scopeIntended) {
        return (New-GeneXusXmlSurgicalError -Code 'SELFCHECK_MUTATION_MISMATCH' -Message "SELFCHECK_MUTATION_MISMATCH: aplicadas=$replacementsApplied pretendidas=$scopeIntended" -ExitCode 19)
    }

    # 10) Disjuncao das mutacoes de ancora.
    if (-not (Test-GeneXusMutationDisjunction -Mutations $anchorMutations)) {
        return (New-GeneXusXmlSurgicalError -Code 'SELFCHECK_MUTATION_MISMATCH' -Message 'SELFCHECK_MUTATION_MISMATCH: mutacoes de ancora sobrepostas.' -ExitCode 19)
    }

    # 11) Pos-condicao por mutacao (pre-bump, texto patchado).
    foreach ($m in $anchorMutations) {
        $m | Add-Member -NotePropertyName Expected -NotePropertyValue $Replacement -Force
        if ($m.FinalLength -eq 0) { continue }
        $slice = $patchedText.Substring($m.FinalStart, $m.FinalLength)
        if (-not [string]::Equals($slice, $Replacement, [System.StringComparison]::Ordinal)) {
            return (New-GeneXusXmlSurgicalError -Code 'SELFCHECK_MUTATION_MISMATCH' -Message 'SELFCHECK_MUTATION_MISMATCH: conteudo da mutacao diverge do Replacement.' -ExitCode 19)
        }
    }

    # 12) Strip-both (pre-bump).
    $preOriginalIntervals = @()
    $preFinalIntervals = @()
    foreach ($m in $anchorMutations) {
        $preOriginalIntervals += [pscustomobject]@{ Start = $m.OriginalStart; Length = $m.OriginalLength }
        $preFinalIntervals += [pscustomobject]@{ Start = $m.FinalStart; Length = $m.FinalLength }
    }
    if (-not (Test-GeneXusXmlCharIdentityOutsideMutations -OriginalText $sourceText -FinalText $patchedText -OriginalIntervals $preOriginalIntervals -FinalIntervals $preFinalIntervals)) {
        return (New-GeneXusXmlSurgicalError -Code 'SELFCHECK_MUTATION_MISMATCH' -Message 'SELFCHECK_MUTATION_MISMATCH: identidade fora das mutacoes violada.' -ExitCode 19)
    }

    # 13) Diagnostico: contagem de ancora no texto patchado, antes do bump.
    $postPatchAnchorCount = ([int[]]@(Get-GeneXusXmlAnchorOccurrenceIndexes -Text $patchedText -Anchor $Anchor)).Count

    # 14) Invariante do lastUpdate.
    $willBump = -not $PreserveLastUpdate.IsPresent
    $lastUpdateBeforeInfo = Get-FirstObjectLastUpdateFromText -Text $sourceText
    $lastUpdateBefore = if ($null -ne $lastUpdateBeforeInfo) { $lastUpdateBeforeInfo.Value } else { $null }
    $i0 = $sourceText.IndexOf($script:LastUpdateToken, [System.StringComparison]::Ordinal)
    $f0 = -1
    $coverMutation = $null
    $targetRemoved = $false

    if ($i0 -ge 0) {
        $f0 = $i0
        foreach ($m in $anchorMutations) {
            $mEnd = $m.OriginalStart + $m.OriginalLength
            if ($m.OriginalLength -gt 0 -and $m.OriginalStart -le $i0 -and $i0 -lt $mEnd) {
                # A mutacao cobre o token: o Replacement dela tem de preserva-lo.
                $coverMutation = $m
                $innerOffset = $Replacement.IndexOf($script:LastUpdateToken, [System.StringComparison]::Ordinal)
                if ($innerOffset -lt 0) { $targetRemoved = $true; break }
                $f0 = $m.FinalStart + $innerOffset
            } elseif ($mEnd -le $i0) {
                $f0 += ($m.FinalLength - $m.OriginalLength)
            }
        }

        if ($targetRemoved) {
            return (New-GeneXusXmlSurgicalError -Code 'NO_LASTUPDATE' -Message 'NO_LASTUPDATE: o patch removeu o alvo lastUpdate.' -ExitCode 12)
        }

        # 14b) A primeira ocorrencia no texto patchado tem de estar em f0.
        $firstAfter = $patchedText.IndexOf($script:LastUpdateToken, [System.StringComparison]::Ordinal)
        if ($firstAfter -ne $f0) {
            return (New-GeneXusXmlSurgicalError -Code 'LASTUPDATE_TARGET_MOVED' -Message "LASTUPDATE_TARGET_MOVED: a primeira ocorrencia de lastUpdate mudou de lugar (esperado em $f0, encontrado em $firstAfter)." -ExitCode 28 -Details ([pscustomobject]@{ expectedIndex = $f0; actualIndex = $firstAfter }))
        }
    } elseif ($willBump) {
        # 14a) fail-fast, como hoje.
        return (New-GeneXusXmlSurgicalError -Code 'NO_LASTUPDATE' -Message 'NO_LASTUPDATE: bump solicitado mas XML sem lastUpdate na primeira ocorrencia.' -ExitCode 12)
    }

    # 14c) Baseline: exigido apenas no bump; valida Leaf antes do Resolve-Path.
    $baselinePathUsed = $null
    if ($willBump) {
        if (-not [string]::IsNullOrWhiteSpace($LastUpdateBaselinePath)) {
            if (-not (Test-Path -LiteralPath $LastUpdateBaselinePath -PathType Leaf)) {
                return (New-GeneXusXmlSurgicalError -Code 'BASELINE_NOT_FOUND' -Message "BASELINE_NOT_FOUND: baseline nao encontrado: $LastUpdateBaselinePath" -ExitCode 16 -Details ([pscustomobject]@{ baselinePath = $LastUpdateBaselinePath }))
            }
            $baselinePathUsed = (Resolve-Path -LiteralPath $LastUpdateBaselinePath).Path
        } else {
            $baselinePathUsed = $resolvedInput
        }
    }

    # 15) Bump + verificacao no texto final.
    $lastUpdateAfter = $lastUpdateBefore
    $lastUpdateMutation = $null
    $finalText = $patchedText

    if ($willBump) {
        try {
            $lastUpdateAfter = Get-NewGeneXusLastUpdateValueFromEngine -BaselineXmlPath $baselinePathUsed
        } catch {
            return (New-GeneXusXmlSurgicalError -Code 'NO_LASTUPDATE' -Message $_.Exception.Message -ExitCode 12)
        }

        $valueStart = $f0 + $script:LastUpdateToken.Length
        $valueEnd = $patchedText.IndexOf('"', $valueStart, [System.StringComparison]::Ordinal)
        if ($valueEnd -lt 0) {
            return (New-GeneXusXmlSurgicalError -Code 'NO_LASTUPDATE' -Message 'NO_LASTUPDATE: token lastUpdate malformado.' -ExitCode 12)
        }

        $oldTokenLength = ($valueEnd + 1) - $f0
        $newToken = $script:LastUpdateToken + $lastUpdateAfter + '"'
        $deltaLastUpdate = $newToken.Length - $oldTokenLength
        $finalText = $patchedText.Substring(0, $f0) + $newToken + $patchedText.Substring($valueEnd + 1)

        foreach ($m in $anchorMutations) {
            $mEnd = $m.FinalStart + $m.FinalLength
            if ($f0 -ge $m.FinalStart -and $f0 -lt $mEnd) {
                $m.FinalLength += $deltaLastUpdate
            } elseif ($m.FinalStart -ge ($f0 + $oldTokenLength)) {
                $m.FinalStart += $deltaLastUpdate
            }
        }

        if ($null -ne $coverMutation) {
            # O token bumpado vive dentro do Replacement; ajusta o conteudo esperado.
            $innerValueStart = $coverMutation.Expected.IndexOf($script:LastUpdateToken, [System.StringComparison]::Ordinal) + $script:LastUpdateToken.Length
            $innerValueEnd = $coverMutation.Expected.IndexOf('"', $innerValueStart, [System.StringComparison]::Ordinal)
            $coverMutation.Expected = $coverMutation.Expected.Substring(0, $innerValueStart) + $lastUpdateAfter + $coverMutation.Expected.Substring($innerValueEnd)
            $luOriginalStart = $coverMutation.OriginalStart
            $luOriginalLength = $coverMutation.OriginalLength
        } else {
            $originalValueStart = $i0 + $script:LastUpdateToken.Length
            $originalValueEnd = $sourceText.IndexOf('"', $originalValueStart, [System.StringComparison]::Ordinal)
            $luOriginalStart = $i0
            $luOriginalLength = ($originalValueEnd + 1) - $i0
        }

        $lastUpdateMutation = [pscustomobject]@{
            OriginalStart  = $luOriginalStart
            OriginalLength = $luOriginalLength
            FinalStart     = $f0
            FinalLength    = $newToken.Length
        }
    }

    $bytesAfter = [System.Text.Encoding]::UTF8.GetByteCount($finalText)
    $bytesDelta = $bytesAfter - $bytesBefore

    $wellFormed = $null
    $wellFormedError = $null
    $bakPath = $null

    if ($DryRun.IsPresent) {
        # Passos 11/12 sobre o texto em memoria, com o conjunto completo.
        if (-not (Test-GeneXusFinalTextPostCondition -FinalText $finalText -AnchorMutations $anchorMutations -LastUpdateMutation $lastUpdateMutation -OriginalText $sourceText)) {
            return (New-GeneXusXmlSurgicalError -Code 'SELFCHECK_MUTATION_MISMATCH' -Message 'SELFCHECK_MUTATION_MISMATCH: pos-condicao falhou no texto final (dry-run).' -ExitCode 19)
        }
        if ($AssertWellFormedAfter) {
            $wfDry = Test-GeneXusXmlWellFormed -Text $finalText
            $wellFormed = $wfDry.WellFormed
            $wellFormedError = $wfDry.ErrorMessage
        }
    } else {
        $utf8NoBom = (Get-Utf8NoBomEncoding)
        if (Test-Path -LiteralPath $resolvedOutput -PathType Leaf) {
            $bakPath = "$resolvedOutput.bak"
            [System.IO.File]::Copy($resolvedOutput, $bakPath, $true)
        }

        [System.IO.File]::WriteAllText($resolvedOutput, $finalText, $utf8NoBom)

        # Rele o arquivo gravado e reaplica 11/12 sobre o texto de disco.
        $writtenText = [System.IO.File]::ReadAllText($resolvedOutput)
        if (-not (Test-GeneXusFinalTextPostCondition -FinalText $writtenText -AnchorMutations $anchorMutations -LastUpdateMutation $lastUpdateMutation -OriginalText $sourceText)) {
            if ($null -ne $bakPath -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
                [System.IO.File]::Copy($bakPath, $resolvedOutput, $true)
            }
            return (New-GeneXusXmlSurgicalError -Code 'SELFCHECK_MUTATION_MISMATCH' -Message 'SELFCHECK_MUTATION_MISMATCH: pos-condicao falhou no arquivo gravado.' -ExitCode 19 -Details ([pscustomobject]@{ bakPath = $bakPath }))
        }

        if ($AssertWellFormedAfter) {
            $postWrite = Test-GeneXusXmlWellFormed -Text $writtenText
            $wellFormed = $postWrite.WellFormed
            $wellFormedError = $postWrite.ErrorMessage
            if (-not $postWrite.WellFormed) {
                if ($null -ne $bakPath -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
                    [System.IO.File]::Copy($bakPath, $resolvedOutput, $true)
                }
                return (New-GeneXusXmlSurgicalError -Code 'XML_NOT_WELLFORMED_AFTER' -Message "XML_NOT_WELLFORMED_AFTER: $($postWrite.ErrorMessage)" -ExitCode 13 -Details ([pscustomobject]@{ bakPath = $bakPath }))
            }
        }

        if ($null -ne $bakPath -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
            Remove-Item -LiteralPath $bakPath -Force
            $bakPath = $null
        }
    }

    # EOL (diagnostico).
    $sourceProfile = Get-GeneXusTextEolProfile -Text $sourceText
    $detectedEol = Get-GeneXusEolToken -Profile $sourceProfile
    $replacementEolMismatch = Get-GeneXusReplacementEolMismatch -Replacement $Replacement -SourceToken $detectedEol

    return [pscustomobject]@{
        Status                  = 'OK'
        Code                    = 'EDIT_OK'
        Message                 = 'EDIT_OK'
        ExitCode                = 0
        DryRun                  = [bool]$DryRun.IsPresent
        EditMode                = $EditMode
        InputPath               = $resolvedInput
        OutputPath              = $resolvedOutput
        AnchorCount             = $indexes.Count
        ExpectedAnchorCount     = $ExpectedAnchorCount
        ApplyToAllOccurrences   = [bool]$ApplyToAllOccurrences.IsPresent
        ReplacementsApplied     = $replacementsApplied
        PostPatchAnchorCount    = $postPatchAnchorCount
        BytesBefore             = $bytesBefore
        BytesAfter              = $bytesAfter
        BytesDelta              = $bytesDelta
        LastUpdateBefore        = $lastUpdateBefore
        LastUpdateAfter         = $lastUpdateAfter
        PreserveLastUpdate      = [bool]$PreserveLastUpdate.IsPresent
        WillBumpLastUpdate      = $willBump
        LastUpdateBaselinePath  = $baselinePathUsed
        DetectedEol             = $detectedEol
        SourceEolMixed          = [bool]$sourceProfile.Mixed
        ReplacementEolMismatch  = $replacementEolMismatch
        MutatedIntervals        = (Get-GeneXusMutatedIntervals -AnchorMutations $anchorMutations -LastUpdateMutation $lastUpdateMutation)
        WellFormed              = $wellFormed
        WellFormedError         = $wellFormedError
        ReplacementPreview      = (Get-ReplacementPreview -Text $Replacement)
        BakPath                 = $bakPath
    }
}
