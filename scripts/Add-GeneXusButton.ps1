#requires -Version 7.4

<#
.SYNOPSIS
    Adiciona um botao a um WebPanel GeneXus de forma cirurgica e fail-closed.

.DESCRIPTION
    Insere uma nova <cell> com um botao (forma <action> ou <ucw> Button) logo após
    a celula de um controle nomeado (-AfterControlName) ou logo antes dela
    (-BeforeControlName), e opcionalmente um stub de Event de usuário no Part de
    eventos. Reusa GeneXusXmlSurgicalEditSupport.ps1 para o patch literal, o bump de
    lastUpdate e a validação de bem-formado; NÃO re-serializa o CDATA do layout.

    Escopo seguro (MVP): a ancora (-AfterControlName ou -BeforeControlName) deve
    apontar para um controle folha em uma celula simples de tabela Flex (ou
    Responsive com responsiveSizes vazio). Tabela Responsive com responsiveSizes
    preenchido aborta fail-closed (RESPONSIVE_UNSAFE), pois inserir celula exigiria
    reescrever o array de breakpoints. As duas ancoras são mutuamente exclusivas
    (parameter sets); informe exatamente uma.

.PARAMETER InputPath
    Caminho do XML do WebPanel (Object XML).

.PARAMETER AfterControlName
    Nome do controle folha existente após cuja celula o novo botao sera inserido
    (parameter set 'After'). Mutuamente exclusivo com -BeforeControlName.

.PARAMETER BeforeControlName
    Nome do controle folha existente antes de cuja celula o novo botao sera inserido
    (parameter set 'Before'). Mutuamente exclusivo com -AfterControlName.

.PARAMETER ButtonControlName
    ControlName do botao novo.

.PARAMETER EventName
    Nome do evento de usuário disparado pelo botao (sem aspas; as aspas simples são
    adicionadas na serializacao).

.PARAMETER Caption
    Texto exibido no botao.

.PARAMETER Class
    Classe(s) CSS opcional(is).

.PARAMETER Form
    Forma de serializacao do botao: 'action' (default) ou 'ucw' (Button user control).

.PARAMETER EventStub
    Quando $true (default), insere 'Event <Name> ... EndEvent' no Part de eventos.
#>

[CmdletBinding(DefaultParameterSetName = 'After')]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$OutputPath,

    [Parameter(Mandatory = $true, ParameterSetName = 'After')]
    [string]$AfterControlName,

    [Parameter(Mandatory = $true, ParameterSetName = 'Before')]
    [string]$BeforeControlName,

    [Parameter(Mandatory = $true)]
    [string]$ButtonControlName,

    [Parameter(Mandatory = $true)]
    [string]$EventName,

    [Parameter(Mandatory = $true)]
    [string]$Caption,

    [string]$Class,

    [ValidateSet('action', 'ucw')]
    [string]$Form = 'action',

    [bool]$EventStub = $true,

    [switch]$PreserveLastUpdate,

    [string]$LastUpdateBaselinePath,

    [switch]$DryRun,

    [bool]$AssertWellFormedAfter = $true,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supportPath = Join-Path $PSScriptRoot 'GeneXusXmlSurgicalEditSupport.ps1'
if (-not (Test-Path -LiteralPath $supportPath -PathType Leaf)) {
    throw "GeneXusXmlSurgicalEditSupport.ps1 nao encontrado: $supportPath"
}
. $supportPath

$EventsPartType = 'c44bd5ff-f918-415b-98e6-aca44fed84fa'
$ButtonGxControlType = '-2133704903'

function ConvertTo-XmlText {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return ($Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;')
}

function ConvertTo-XmlAttr {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return ($Value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

function New-ButtonError {
    param([string]$Code, [string]$Message, [int]$ExitCode)
    return [pscustomobject]@{ Status = 'ERROR'; Code = $Code; Message = $Message; ExitCode = $ExitCode }
}

function Get-UcwControlNameFromPattern {
    param([string]$PatternValue)
    if ([string]::IsNullOrWhiteSpace($PatternValue) -or ($PatternValue -notmatch '<Properties\b')) { return $null }
    $pdoc = New-Object System.Xml.XmlDocument
    try { $pdoc.LoadXml($PatternValue) } catch { return $null }
    foreach ($propertyNode in @($pdoc.SelectNodes('//Property'))) {
        $nameNode = $propertyNode.SelectSingleNode('Name')
        if (($null -ne $nameNode) -and ($nameNode.InnerText -eq 'ControlName')) {
            $valueNode = $propertyNode.SelectSingleNode('Value')
            if ($null -ne $valueNode) { return $valueNode.InnerText }
        }
    }
    return $null
}

function Write-ButtonResult {
    param([pscustomobject]$Result, [bool]$Json)
    if ($Json) {
        $Result | ConvertTo-Json -Depth 8
    } else {
        $Result | Format-List | Out-String | Write-Output
    }
}

# --- Carrega e valida entrada ---------------------------------------------------
if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    $r = New-ButtonError -Code 'INPUT_NOT_FOUND' -Message "INPUT_NOT_FOUND: arquivo nao encontrado: $InputPath" -ExitCode 14
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}
$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$sourceText = [System.IO.File]::ReadAllText($resolvedInput)
$newline = if ($sourceText -match "`r`n") { "`r`n" } else { "`n" }

# --- Parse estrutural para localizar e validar ----------------------------------
$objectDoc = New-Object System.Xml.XmlDocument
$objectDoc.PreserveWhitespace = $true
try {
    $objectDoc.LoadXml($sourceText)
} catch {
    $r = New-ButtonError -Code 'INPUT_NOT_WELLFORMED' -Message "INPUT_NOT_WELLFORMED: $($_.Exception.Message)" -ExitCode 16
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}

$layoutSourceText = $null
foreach ($srcNode in @($objectDoc.SelectNodes('//Source'))) {
    if ($srcNode.InnerText -match '<GxMultiForm\b') { $layoutSourceText = $srcNode.InnerText; break }
}
if ($null -eq $layoutSourceText) {
    $r = New-ButtonError -Code 'LAYOUT_NOT_FOUND' -Message 'LAYOUT_NOT_FOUND: nenhum Source com GxMultiForm encontrado (objeto nao e WebPanel classico?).' -ExitCode 23
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}

$formDoc = New-Object System.Xml.XmlDocument
try {
    $formDoc.LoadXml($layoutSourceText)
} catch {
    $r = New-ButtonError -Code 'LAYOUT_NOT_WELLFORMED' -Message "LAYOUT_NOT_WELLFORMED: $($_.Exception.Message)" -ExitCode 23
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}

# resolve a ancora pelo parameter set: 'Before' usa -BeforeControlName e insere a
# nova celula ANTES da celula da ancora; 'After' (default) insere DEPOIS. Toda a
# validação de seguranca (folha, Responsive, unicidade) e identica nos dois casos.
$position = $PSCmdlet.ParameterSetName
if ($position -eq 'Before') {
    $anchorControlName = $BeforeControlName
    $insertMode = 'InsertBefore'
} else {
    $anchorControlName = $AfterControlName
    $insertMode = 'InsertAfter'
}

# localizar controle ancora: por atributo controlName ou por ControlName de ucw Button
$anchorNode = $formDoc.SelectSingleNode("//*[@controlName='$anchorControlName']")
if ($null -eq $anchorNode) {
    foreach ($u in @($formDoc.SelectNodes('//ucw'))) {
        $cn = Get-UcwControlNameFromPattern -PatternValue $u.GetAttribute('PATTERN_ELEMENT_CUSTOM_PROPERTIES')
        if ($cn -eq $anchorControlName) { $anchorNode = $u; break }
    }
}
if ($null -eq $anchorNode) {
    $r = New-ButtonError -Code 'ANCHOR_CONTROL_NOT_FOUND' -Message "ANCHOR_CONTROL_NOT_FOUND: controle '$anchorControlName' nao encontrado no layout." -ExitCode 20
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}

# ancestor-or-self::cell[1]: o [1] e obrigatório. SelectSingleNode sem predicado
# escolhe por document order e devolveria a celula mais EXTERNA (o container
# aninhado), não a folha; em eixo reverso, [1] = o ancestral mais próximo.
$cellNode = $anchorNode.SelectSingleNode('ancestor-or-self::cell[1]')
if ($null -eq $cellNode) {
    $r = New-ButtonError -Code 'ANCHOR_NOT_IN_CELL' -Message "ANCHOR_NOT_IN_CELL: controle '$anchorControlName' nao esta dentro de uma <cell>." -ExitCode 21
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}
# celula folha: sem <table> ou <cell> aninhada
if (@($cellNode.SelectNodes('.//table | .//cell')).Count -gt 0) {
    $r = New-ButtonError -Code 'NOT_LEAF_CELL' -Message "NOT_LEAF_CELL: a celula de '$anchorControlName' contem tabela/celula aninhada; insercao automatica nao suportada (use o snippet manual)." -ExitCode 21
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}

$tableNode = $cellNode.SelectSingleNode('ancestor::table[1]')
if ($null -eq $tableNode) {
    $r = New-ButtonError -Code 'TABLE_NOT_FOUND' -Message "TABLE_NOT_FOUND: nenhuma <table> ancestral da celula de '$anchorControlName'." -ExitCode 23
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}
$tableType = $tableNode.GetAttribute('tableType')
$responsiveSizes = $tableNode.GetAttribute('responsiveSizes')
$responsiveNonEmpty = (-not [string]::IsNullOrWhiteSpace($responsiveSizes)) -and ($responsiveSizes -ne '[]')
if (($tableType -ieq 'Responsive') -and $responsiveNonEmpty) {
    $msg = "RESPONSIVE_UNSAFE: tabela '$($tableNode.GetAttribute('controlName'))' e Responsive com responsiveSizes preenchido; inserir celula exigiria reescrever os breakpoints. Gere o botao manualmente e ajuste o responsiveSizes."
    $r = New-ButtonError -Code 'RESPONSIVE_UNSAFE' -Message $msg -ExitCode 22
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}

# --- Monta o snippet do botao ---------------------------------------------------
if ($Form -eq 'ucw') {
    $propsXml = '<Properties>'
    $propsXml += ('<Property><Name>ControlName</Name><Value>{0}</Value></Property>' -f (ConvertTo-XmlText $ButtonControlName))
    $propsXml += '<Property><Name>Enabled</Name><Value>True</Value></Property>'
    $propsXml += ('<Property><Name>Event</Name><Value>{0}</Value></Property>' -f (ConvertTo-XmlText ("'" + $EventName + "'")))
    $propsXml += ('<Property><Name>CaptionExpression</Name><Value>{0}</Value></Property>' -f (ConvertTo-XmlText $Caption))
    if (-not [string]::IsNullOrWhiteSpace($Class)) {
        $propsXml += ('<Property><Name>Class</Name><Value>{0}</Value></Property>' -f (ConvertTo-XmlText $Class))
    }
    $propsXml += '</Properties>'
    $cellSnippet = '<cell><ucw gxControlType="{0}" PATTERN_ELEMENT_CUSTOM_PROPERTIES="{1}" /></cell>' -f $ButtonGxControlType, (ConvertTo-XmlAttr $propsXml)
} else {
    $classAttr = ''
    if (-not [string]::IsNullOrWhiteSpace($Class)) {
        $classAttr = ' class="{0}"' -f (ConvertTo-XmlAttr $Class)
    }
    $cellSnippet = '<cell><action controlName="{0}" onClickEvent="''{1}''" caption="{2}"{3} /></cell>' -f (ConvertTo-XmlAttr $ButtonControlName), (ConvertTo-XmlAttr $EventName), (ConvertTo-XmlAttr $Caption), $classAttr
}

# --- Deriva a ancora literal da celula do controle ancora -----------------------
if ($null -ne $anchorNode.SelectSingleNode('@controlName')) {
    $marker = 'controlName="{0}"' -f $anchorControlName
} else {
    $marker = '&lt;Name&gt;ControlName&lt;/Name&gt;&lt;Value&gt;{0}&lt;/Value&gt;' -f $anchorControlName
}
$idxMarker = $sourceText.IndexOf($marker, [System.StringComparison]::Ordinal)
if ($idxMarker -lt 0) {
    $r = New-ButtonError -Code 'ANCHOR_TEXT_NOT_FOUND' -Message "ANCHOR_TEXT_NOT_FOUND: marcador literal do controle '$anchorControlName' nao localizado no texto." -ExitCode 20
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}
$cellOpen = $sourceText.LastIndexOf('<cell', $idxMarker, [System.StringComparison]::Ordinal)
$cellCloseStart = $sourceText.IndexOf('</cell>', $idxMarker, [System.StringComparison]::Ordinal)
if (($cellOpen -lt 0) -or ($cellCloseStart -lt 0)) {
    $r = New-ButtonError -Code 'ANCHOR_TEXT_NOT_FOUND' -Message "ANCHOR_TEXT_NOT_FOUND: nao foi possivel delimitar a celula literal de '$anchorControlName'." -ExitCode 20
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}
$cellCloseEnd = $cellCloseStart + '</cell>'.Length
$anchorLayout = $sourceText.Substring($cellOpen, $cellCloseEnd - $cellOpen)

$layoutAnchorCount = Get-AnchorOccurrenceCount -Text $sourceText -Anchor $anchorLayout
if ($layoutAnchorCount -ne 1) {
    $r = New-ButtonError -Code 'ANCHOR_NOT_UNIQUE' -Message "ANCHOR_NOT_UNIQUE: a celula literal de '$anchorControlName' ocorre $layoutAnchorCount vezes (esperado 1)." -ExitCode 25
    Write-ButtonResult -Result $r -Json $AsJson.IsPresent
    exit $r.ExitCode
}

# --- Aplica patch de layout (InsertBefore/InsertAfter a celula ancora) ----------
$patchedText = Invoke-GeneXusXmlLiteralPatch -Text $sourceText -Anchor $anchorLayout -Replacement $cellSnippet -EditMode $insertMode

# --- Stub de Event no Part de eventos -------------------------------------------
$eventStubApplied = $false
if ($EventStub) {
    $partMarker = '<Part type="{0}">' -f $EventsPartType
    $idxPart = $patchedText.IndexOf($partMarker, [System.StringComparison]::Ordinal)
    if ($idxPart -lt 0) {
        $r = New-ButtonError -Code 'EVENTS_PART_NOT_FOUND' -Message "EVENTS_PART_NOT_FOUND: Part de eventos ($EventsPartType) nao encontrado; use -EventStub `$false e adicione o evento manualmente." -ExitCode 24
        Write-ButtonResult -Result $r -Json $AsJson.IsPresent
        exit $r.ExitCode
    }
    $idxCdataClose = $patchedText.IndexOf(']]>', $idxPart, [System.StringComparison]::Ordinal)
    if ($idxCdataClose -lt 0) {
        $r = New-ButtonError -Code 'EVENTS_CDATA_NOT_FOUND' -Message 'EVENTS_CDATA_NOT_FOUND: CDATA do Part de eventos nao localizado.' -ExitCode 24
        Write-ButtonResult -Result $r -Json $AsJson.IsPresent
        exit $r.ExitCode
    }
    $stub = "{0}{0}Event '{1}'{0}`t// TODO: implementar{0}EndEvent{0}" -f $newline, $EventName
    $patchedText = $patchedText.Substring(0, $idxCdataClose) + $stub + $patchedText.Substring($idxCdataClose)
    $eventStubApplied = $true
}

# --- Bump de lastUpdate ---------------------------------------------------------
$lastUpdateBeforeInfo = Get-FirstObjectLastUpdateFromText -Text $sourceText
$lastUpdateBefore = if ($null -ne $lastUpdateBeforeInfo) { $lastUpdateBeforeInfo.Value } else { $null }
$willBump = -not $PreserveLastUpdate.IsPresent
$lastUpdateAfter = $lastUpdateBefore
$baselinePathUsed = $null
if ($willBump) {
    if ($null -eq $lastUpdateBeforeInfo) {
        $r = New-ButtonError -Code 'NO_LASTUPDATE' -Message 'NO_LASTUPDATE: bump solicitado mas XML sem lastUpdate na primeira ocorrencia.' -ExitCode 12
        Write-ButtonResult -Result $r -Json $AsJson.IsPresent
        exit $r.ExitCode
    }
    if (-not [string]::IsNullOrWhiteSpace($LastUpdateBaselinePath)) {
        $baselinePathUsed = (Resolve-Path -LiteralPath $LastUpdateBaselinePath).Path
    } else {
        $baselinePathUsed = $resolvedInput
    }
    try {
        $lastUpdateAfter = Get-NewGeneXusLastUpdateValueFromEngine -BaselineXmlPath $baselinePathUsed
    } catch {
        $r = New-ButtonError -Code 'NO_LASTUPDATE' -Message $_.Exception.Message -ExitCode 12
        Write-ButtonResult -Result $r -Json $AsJson.IsPresent
        exit $r.ExitCode
    }
    $patchedText = Set-FirstObjectLastUpdateInText -Text $patchedText -NewLastUpdateValue $lastUpdateAfter
}

# --- Destino, validação e escrita -----------------------------------------------
$resolvedOutput = $resolvedInput
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputParent = [System.IO.Path]::GetDirectoryName($OutputPath)
    if ([string]::IsNullOrWhiteSpace($outputParent) -or (-not (Test-Path -LiteralPath $outputParent -PathType Container))) {
        $r = New-ButtonError -Code 'OUTPUT_DIR_MISSING' -Message "OUTPUT_DIR_MISSING: diretorio de destino invalido: $OutputPath" -ExitCode 15
        Write-ButtonResult -Result $r -Json $AsJson.IsPresent
        exit $r.ExitCode
    }
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
}

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
            if (($null -ne $bakPath) -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
                [System.IO.File]::Copy($bakPath, $resolvedOutput, $true)
            }
            $r = New-ButtonError -Code 'XML_NOT_WELLFORMED_AFTER' -Message "XML_NOT_WELLFORMED_AFTER: $($postWrite.ErrorMessage)" -ExitCode 13
            Write-ButtonResult -Result $r -Json $AsJson.IsPresent
            exit $r.ExitCode
        }
    }
    if (($null -ne $bakPath) -and (Test-Path -LiteralPath $bakPath -PathType Leaf)) {
        Remove-Item -LiteralPath $bakPath -Force
        $bakPath = $null
    }
} elseif ($AssertWellFormedAfter) {
    $wfDry = Test-GeneXusXmlWellFormed -Text $patchedText
    $wellFormed = $wfDry.WellFormed
    $wellFormedError = $wfDry.ErrorMessage
    if (-not $wfDry.WellFormed) {
        $r = New-ButtonError -Code 'XML_NOT_WELLFORMED_AFTER' -Message "XML_NOT_WELLFORMED_AFTER: $($wfDry.ErrorMessage)" -ExitCode 13
        Write-ButtonResult -Result $r -Json $AsJson.IsPresent
        exit $r.ExitCode
    }
}

$result = [pscustomobject]@{
    Status              = 'OK'
    Code                = 'BUTTON_ADDED'
    Message             = 'BUTTON_ADDED'
    ExitCode            = 0
    DryRun              = [bool]$DryRun.IsPresent
    Form                = $Form
    ButtonControlName   = $ButtonControlName
    EventName           = $EventName
    EventStubApplied    = $eventStubApplied
    Position            = $position
    AnchorControlName   = $anchorControlName
    AfterControlName    = $AfterControlName
    BeforeControlName   = $BeforeControlName
    TableControlName    = $tableNode.GetAttribute('controlName')
    TableType           = $tableType
    InputPath           = $resolvedInput
    OutputPath          = $resolvedOutput
    LastUpdateBefore    = $lastUpdateBefore
    LastUpdateAfter     = $lastUpdateAfter
    WillBumpLastUpdate  = $willBump
    WellFormed          = $wellFormed
    CellSnippet         = $cellSnippet
}
Write-ButtonResult -Result $result -Json $AsJson.IsPresent
exit 0
