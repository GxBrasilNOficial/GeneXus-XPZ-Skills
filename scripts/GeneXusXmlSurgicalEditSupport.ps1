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
$script:FreshnessMarginSecondsDefault = 60

function Get-AnchorOccurrenceCount {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Anchor
    )

    if ([string]::IsNullOrEmpty($Anchor)) {
        return 0
    }

    $escaped = [regex]::Escape($Anchor)
    return [regex]::Matches($Text, $escaped).Count
}

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

function Invoke-GeneXusXmlLiteralPatch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Anchor,

        [Parameter(Mandatory = $true)]
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

        [int]$ExitCode
    )

    return [pscustomobject]@{
        Status    = 'ERROR'
        Code      = $Code
        Message   = $Message
        ExitCode  = $ExitCode
    }
}

function Invoke-GeneXusXmlSurgicalEditCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputPath,

        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$Anchor,

        [Parameter(Mandatory = $true)]
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
        if ([string]::IsNullOrWhiteSpace($outputParent)) {
            return (New-GeneXusXmlSurgicalError -Code 'OUTPUT_DIR_MISSING' -Message "OUTPUT_DIR_MISSING: diretorio de destino invalido: $OutputPath" -ExitCode 15)
        }
        if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
            return (New-GeneXusXmlSurgicalError -Code 'OUTPUT_DIR_MISSING' -Message "OUTPUT_DIR_MISSING: diretorio nao existe: $outputParent" -ExitCode 15)
        }
        $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    }

    $sourceText = [System.IO.File]::ReadAllText($resolvedInput)
    $bytesBefore = [System.Text.Encoding]::UTF8.GetByteCount($sourceText)

    $anchorCount = Get-AnchorOccurrenceCount -Text $sourceText -Anchor $Anchor
    if ($anchorCount -ne $ExpectedAnchorCount) {
        $message = "ANCHOR_FAIL: contagem=$anchorCount esperada=$ExpectedAnchorCount"
        return (New-GeneXusXmlSurgicalError -Code 'ANCHOR_FAIL' -Message $message -ExitCode 11)
    }

    $lastUpdateBeforeInfo = Get-FirstObjectLastUpdateFromText -Text $sourceText
    $lastUpdateBefore = if ($null -ne $lastUpdateBeforeInfo) { $lastUpdateBeforeInfo.Value } else { $null }

    $patchedText = Invoke-GeneXusXmlLiteralPatch -Text $sourceText -Anchor $Anchor -Replacement $Replacement -EditMode $EditMode
    $replacementPreview = Get-ReplacementPreview -Text $Replacement

    $willBump = -not $PreserveLastUpdate.IsPresent
    $lastUpdateAfter = $lastUpdateBefore
    $baselinePathUsed = $null

    if ($willBump) {
        if ($null -eq $lastUpdateBeforeInfo) {
            return (New-GeneXusXmlSurgicalError -Code 'NO_LASTUPDATE' -Message 'NO_LASTUPDATE: bump solicitado mas XML sem lastUpdate na primeira ocorrencia.' -ExitCode 12)
        }

        if (-not [string]::IsNullOrWhiteSpace($LastUpdateBaselinePath)) {
            $baselinePathUsed = (Resolve-Path -LiteralPath $LastUpdateBaselinePath).Path
        } else {
            $baselinePathUsed = $resolvedInput
        }

        try {
            $lastUpdateAfter = Get-NewGeneXusLastUpdateValueFromEngine -BaselineXmlPath $baselinePathUsed
        } catch {
            return (New-GeneXusXmlSurgicalError -Code 'NO_LASTUPDATE' -Message $_.Exception.Message -ExitCode 12)
        }

        $patchedText = Set-FirstObjectLastUpdateInText -Text $patchedText -NewLastUpdateValue $lastUpdateAfter
    }

    $bytesAfter = [System.Text.Encoding]::UTF8.GetByteCount($patchedText)
    $bytesDelta = $bytesAfter - $bytesBefore

    $wellFormed = $null
    $wellFormedError = $null

    $bakPath = $null
    if (-not $DryRun.IsPresent) {
        $utf8NoBom = (Get-Utf8NoBomEncoding)
        if (Test-Path -LiteralPath $resolvedOutput -PathType Leaf) {
            $bakPath = "$resolvedOutput.bak"
            [System.IO.File]::Copy($resolvedOutput, $bakPath, $true)
        }

        [System.IO.File]::WriteAllText($resolvedOutput, $patchedText, $utf8NoBom)

        if ($AssertWellFormedAfter) {
            $writtenText = [System.IO.File]::ReadAllText($resolvedOutput)
            $postWrite = Test-GeneXusXmlWellFormed -Text $writtenText
            $wellFormed = $postWrite.WellFormed
            $wellFormedError = $postWrite.ErrorMessage
            if (-not $postWrite.WellFormed) {
                if ($null -ne $bakPath -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
                    [System.IO.File]::Copy($bakPath, $resolvedOutput, $true)
                }
                $message = "XML_NOT_WELLFORMED_AFTER: $($postWrite.ErrorMessage)"
                return (New-GeneXusXmlSurgicalError -Code 'XML_NOT_WELLFORMED_AFTER' -Message $message -ExitCode 13)
            }
        }

        if ($null -ne $bakPath -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
            Remove-Item -LiteralPath $bakPath -Force
            $bakPath = $null
        }
    } elseif ($AssertWellFormedAfter) {
        $wfDry = Test-GeneXusXmlWellFormed -Text $patchedText
        $wellFormed = $wfDry.WellFormed
        $wellFormedError = $wfDry.ErrorMessage
    }

    return [pscustomobject]@{
        Status                 = 'OK'
        Code                   = 'EDIT_OK'
        Message                = 'EDIT_OK'
        ExitCode               = 0
        DryRun                 = [bool]$DryRun.IsPresent
        EditMode               = $EditMode
        InputPath              = $resolvedInput
        OutputPath             = $resolvedOutput
        AnchorCount            = $anchorCount
        ExpectedAnchorCount    = $ExpectedAnchorCount
        BytesBefore            = $bytesBefore
        BytesAfter             = $bytesAfter
        BytesDelta             = $bytesDelta
        LastUpdateBefore       = $lastUpdateBefore
        LastUpdateAfter        = $lastUpdateAfter
        PreserveLastUpdate     = [bool]$PreserveLastUpdate.IsPresent
        WillBumpLastUpdate     = $willBump
        LastUpdateBaselinePath = $baselinePathUsed
        WellFormed             = $wellFormed
        WellFormedError        = $wellFormedError
        ReplacementPreview     = $replacementPreview
        BakPath                = $bakPath
    }
}
