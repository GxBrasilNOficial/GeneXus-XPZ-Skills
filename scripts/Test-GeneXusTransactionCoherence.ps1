#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TransactionTypeGuid = "1db606f2-af09-4cf9-a3b5-b481519d28f6"
$NonWritableClassifications = @("extended-parent-fk", "formula", "extended-subtype-descriptive")

# DVelop WorkWithPlus (third-party) — objectTypeGuid do catalogo gx-object-type-catalog.json
# (WorkWithPlusInstance). Também e o sufixo da propriedade Apply:<guid> na Transaction.
# NÃO confundir com o Work With nativo do GeneXus (78cecefe-...), quase universal no acervo.
$WorkWithPlusInstanceTypeGuid = "07135890-56fc-489b-b408-063722fa9f7d"

$GxKeywords = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($kw in @("if", "else", "elseif", "endif", "for", "each", "endfor", "do", "case", "endcase",
                   "when", "where", "not", "and", "or", "new", "true", "false", "null", "return",
                   "call", "commit", "rollback", "sub", "endsub", "event", "endevent",
                   "defined", "is", "in", "like", "between", "order", "print")) {
    $GxKeywords.Add($kw) | Out-Null
}

function Get-LinePreview {
    param([string]$Line)
    if ($null -eq $Line) { return "" }
    $trimmed = $Line.Trim()
    if ($trimmed.Length -le 140) { return $trimmed }
    return $trimmed.Substring(0, 140) + "..."
}

function New-Finding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [int]$LineNumber,
        [string]$LinePreview
    )
    return [pscustomobject]@{
        severity    = $Severity
        code        = $Code
        message     = $Message
        lineNumber  = $LineNumber
        linePreview = $LinePreview
    }
}

function Get-AttributeClassification {
    param(
        [string]$AttName,
        [hashtable]$ClassMap,
        [hashtable]$FormulaSet,
        [System.Collections.Generic.HashSet[string]]$KnownNames
    )
    if (-not $KnownNames.Contains($AttName)) { return "not-in-level" }
    if ($FormulaSet.ContainsKey($AttName)) { return "formula" }
    if ($ClassMap.ContainsKey($AttName)) { return $ClassMap[$AttName] }
    return "own-physical"
}

function Get-ObjectGeneratesProgram {
    # Le GenerateObject do <Properties> de NÍVEL OBJECT (filho direto de <Object>),
    # não os <Properties> aninhados das Parts. Só e serializada quando False; ausente => True.
    param([System.Xml.XmlElement]$ObjectNode)

    $propsNode = $ObjectNode.SelectSingleNode("./Properties")
    if ($null -eq $propsNode) { return $true }

    foreach ($p in $propsNode.SelectNodes("./Property")) {
        $nameNode = $p.SelectSingleNode("./Name")
        if ($null -ne $nameNode -and $nameNode.InnerText -eq "GenerateObject") {
            $valNode = $p.SelectSingleNode("./Value")
            if ($null -ne $valNode -and $valNode.InnerText -eq "False") { return $false }
        }
    }
    return $true
}

function Test-OrphanWwpScreenCode {
    # Gate D (confirmado-import, GX18U13 + WorkWithPlus_Web 16.0.3.1): Transaction com
    # GenerateObject=False não gera tela; carregar código de tela WorkWithPlus DVelop nas
    # partes Events/Rules — Call("LoadWWPContext") / Call("<Trn>WW") — referencia runtime
    # inexistente e o import falha com src0246/src0294. Sinal causal = a chamada orfa;
    # Apply:<wwp-guid>=True e o marcador "DVelop Work With Plus" são corroborantes.
    # NÃO confundir com Work With nativo (Apply:78cecefe), legitimo e quase universal.
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$ObjectName
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    if (Get-ObjectGeneratesProgram -ObjectNode $ObjectNode) { return $findings }

    $appliesWwp = $false
    $propsNode = $ObjectNode.SelectSingleNode("./Properties")
    if ($null -ne $propsNode) {
        foreach ($p in $propsNode.SelectNodes("./Property")) {
            $nameNode = $p.SelectSingleNode("./Name")
            if ($null -ne $nameNode -and $nameNode.InnerText -eq "Apply:$WorkWithPlusInstanceTypeGuid") {
                $valNode = $p.SelectSingleNode("./Value")
                if ($null -ne $valNode -and $valNode.InnerText -eq "True") { $appliesWwp = $true }
            }
        }
    }

    foreach ($partNode in $ObjectNode.SelectNodes("./Part[Source]")) {
        $srcNode = $partNode.SelectSingleNode("./Source")
        if ($null -eq $srcNode) { continue }
        $srcText = $srcNode.InnerText
        if ([string]::IsNullOrWhiteSpace($srcText)) { continue }

        if ($srcText -match '(?im)^\s*Event\s+[A-Za-z_]') { $partLabel = "Events" } else { $partLabel = "Rules" }

        $lines = $srcText -split "`r?`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $lineNc = [regex]::Replace($lines[$i], '//.*$', '')
            $m = [regex]::Match($lineNc, '(?i)\bCall\s*\(\s*"(LoadWWPContext|[A-Za-z_][A-Za-z0-9_]*WW)"')
            if (-not $m.Success) { continue }

            $callee = $m.Groups[1].Value
            if ($appliesWwp) { $corro = " Corroborado por Apply:WorkWithPlus=True." } else { $corro = "" }
            $msg = "Transaction '$ObjectName': GenerateObject=False, mas a parte $partLabel chama '$callee' (codigo de tela WorkWithPlus DVelop). A tela desta Transaction nao e gerada; o import falha com src0246/src0294. Para pacote estrutural, remover Events/Rules e o Apply WorkWithPlus, e nao levar PatternInstance/derivados.$corro"
            $findings.Add((New-Finding -Severity "fail" -Code "wwp-screen-code-on-non-generated-transaction" `
                -Message $msg -LineNumber ($i + 1) -LinePreview (Get-LinePreview -Line $lines[$i]))) | Out-Null
        }
    }

    return $findings
}

function Get-LevelAttributeName {
    param([System.Xml.XmlElement]$AttributeNode)
    $name = $AttributeNode.InnerText.Trim()
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $AttributeNode.GetAttribute('name').Trim() }
    return $name
}

function Build-ClassificationData {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [System.Xml.XmlDocument]$XmlDoc
    )

    $classMap   = @{}
    $knownNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $formulaSet = @{}

    foreach ($attNode in $ObjectNode.SelectNodes(".//Level/Attribute")) {
        $name = Get-LevelAttributeName -AttributeNode $attNode
        if ([string]::IsNullOrEmpty($name)) { continue }
        $knownNames.Add($name) | Out-Null
        if ($attNode.GetAttribute("isRedundant") -eq "True") {
            $classMap[$name] = "extended-parent-fk"
        }
    }

    # Formula attributes from Attributes section (available when input is a full ExportFile)
    foreach ($attNode in $XmlDoc.SelectNodes("//Attributes/Attribute")) {
        $name = $attNode.GetAttribute("name")
        if ([string]::IsNullOrEmpty($name)) { continue }
        if ($null -ne $attNode.SelectSingleNode("./Properties/Property[Name='Formula']")) {
            $formulaSet[$name] = "formula"
        }
    }

    return @{ classMap = $classMap; knownNames = $knownNames; formulaSet = $formulaSet }
}

function Check-LevelIntegrity {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$ObjectName
    )

    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($levelNode in $ObjectNode.SelectNodes(".//Level")) {
        if ($levelNode.SelectNodes("Attribute[@key='True']").Count -eq 0) {
            $findings.Add((New-Finding -Severity "fail" -Code "level-no-key" `
                -Message "Transaction '$ObjectName': Level sem atributo com key='True'." `
                -LineNumber 0 -LinePreview "")) | Out-Null
        }

        $descNode = $levelNode.SelectSingleNode('./DescriptionAttribute')
        $descAtt = ''
        if ($null -ne $descNode) { $descAtt = $descNode.InnerText.Trim() }
        if ([string]::IsNullOrWhiteSpace($descAtt)) { $descAtt = $levelNode.GetAttribute('DescriptionAttribute').Trim() }
        if (-not [string]::IsNullOrWhiteSpace($descAtt) -and $descAtt -ine '(None)') {
            $levelNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($attNode in $levelNode.SelectNodes('./Attribute')) {
                [void]$levelNames.Add((Get-LevelAttributeName -AttributeNode $attNode))
            }
            if (-not $levelNames.Contains($descAtt)) {
                $findings.Add((New-Finding -Severity "fail" -Code "description-attribute-not-in-level" `
                    -Message "Transaction '$ObjectName': DescriptionAttribute '$descAtt' nao encontrado como Attribute do mesmo Level." `
                    -LineNumber 0 -LinePreview "")) | Out-Null
            }
        }
    }

    return $findings
}

function Test-SourceForAttributeIssues {
    param(
        [string]$SourceText,
        [string]$ContextLabel,
        [hashtable]$ClassMap,
        [hashtable]$FormulaSet,
        [System.Collections.Generic.HashSet[string]]$KnownNames,
        [bool]$IsEventsPart
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $lines    = $SourceText -split "`r?`n"

    if ($IsEventsPart) {
        $seenEvents  = @{}
        $inBlock     = $false
        $currentName = ""

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $lineNum = $i + 1
            $rawLine = $lines[$i]
            $trimmed = $rawLine.Trim()

            if (-not $inBlock -and $trimmed -match '^(?i)Event\s+([A-Za-z_][A-Za-z0-9_]*)') {
                $currentName = $Matches[1]
                $inBlock = $true
                if ($seenEvents.ContainsKey($currentName.ToLower())) {
                    $findings.Add((New-Finding -Severity "warn" -Code "duplicate-event" `
                        -Message "${ContextLabel}: Event '$currentName' declarado mais de uma vez." `
                        -LineNumber $lineNum `
                        -LinePreview (Get-LinePreview -Line $rawLine))) | Out-Null
                }
                $seenEvents[$currentName.ToLower()] = $lineNum
                continue
            }

            if ($inBlock -and $trimmed -match '^(?i)EndEvent\s*$') {
                $inBlock = $false
                $currentName = ""
                continue
            }

            if (-not $inBlock) { continue }

            $lineNc  = [regex]::Replace($rawLine, '//.*$', '')
            $preview = Get-LinePreview -Line $rawLine

            # Pattern 1 (anchored): AttName.Property = value
            $m1 = [regex]::Match($lineNc, '^\s*([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)')
            if ($m1.Success) {
                $attName  = $m1.Groups[1].Value
                $propName = $m1.Groups[2].Value
                if (-not $GxKeywords.Contains($attName)) {
                    $cls = Get-AttributeClassification -AttName $attName -ClassMap $ClassMap -FormulaSet $FormulaSet -KnownNames $KnownNames
                    if ($cls -eq "not-in-level") {
                        $findings.Add((New-Finding -Severity "warn" -Code "property-on-unknown-attribute" `
                            -Message "${ContextLabel} Event '${currentName}': '${attName}.${propName} = ...' — '${attName}' nao encontrado nos Levels desta Transaction." `
                            -LineNumber $lineNum -LinePreview $preview)) | Out-Null
                    } elseif ($NonWritableClassifications -contains $cls) {
                        $findings.Add((New-Finding -Severity "warn" -Code "property-on-non-writable-attribute" `
                            -Message "${ContextLabel} Event '${currentName}': '${attName}.${propName} = ...' — atributo classificado como '${cls}'; nao suporta manipulacao de propriedades em eventos web. (ref: src0246/src0216)" `
                            -LineNumber $lineNum -LinePreview $preview)) | Out-Null
                    }
                }
            }

            # Pattern 2 (anchored): AttName = value — direct assignment, not property chain
            if (-not $m1.Success) {
                $m2 = [regex]::Match($lineNc, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)')
                if ($m2.Success) {
                    $attName = $m2.Groups[1].Value
                    if (-not $GxKeywords.Contains($attName)) {
                        $cls = Get-AttributeClassification -AttName $attName -ClassMap $ClassMap -FormulaSet $FormulaSet -KnownNames $KnownNames
                        if ($cls -eq "not-in-level") {
                            $findings.Add((New-Finding -Severity "warn" -Code "assignment-to-unknown-name" `
                                -Message "${ContextLabel} Event '${currentName}': '${attName} = ...' — '${attName}' nao encontrado nos Levels desta Transaction; verifique se o nome esta correto ou se deveria usar '&${attName}'." `
                                -LineNumber $lineNum -LinePreview $preview)) | Out-Null
                        } elseif ($NonWritableClassifications -contains $cls) {
                            $findings.Add((New-Finding -Severity "warn" -Code "assignment-to-non-writable-attribute" `
                                -Message "${ContextLabel} Event '${currentName}': atribuicao direta a '${attName}' — atributo classificado como '${cls}'; nao suporta escrita em contexto web." `
                                -LineNumber $lineNum -LinePreview $preview)) | Out-Null
                        }
                    }
                }
            }
        }
    } else {
        # Rules mode: flat line scan
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $lineNum = $i + 1
            $rawLine = $lines[$i]
            $lineNc  = [regex]::Replace($rawLine, '//.*$', '')
            $preview = Get-LinePreview -Line $rawLine

            $m1 = [regex]::Match($lineNc, '^\s*([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)')
            if ($m1.Success) {
                $attName  = $m1.Groups[1].Value
                $propName = $m1.Groups[2].Value
                if (-not $GxKeywords.Contains($attName)) {
                    $cls = Get-AttributeClassification -AttName $attName -ClassMap $ClassMap -FormulaSet $FormulaSet -KnownNames $KnownNames
                    if ($cls -eq "not-in-level") {
                        $findings.Add((New-Finding -Severity "warn" -Code "property-on-unknown-attribute" `
                            -Message "${ContextLabel} Rules: '${attName}.${propName} = ...' — '${attName}' nao encontrado nos Levels desta Transaction." `
                            -LineNumber $lineNum -LinePreview $preview)) | Out-Null
                    } elseif ($NonWritableClassifications -contains $cls) {
                        $findings.Add((New-Finding -Severity "warn" -Code "property-on-non-writable-attribute" `
                            -Message "${ContextLabel} Rules: '${attName}.${propName} = ...' — atributo classificado como '${cls}'; nao suporta esta operacao." `
                            -LineNumber $lineNum -LinePreview $preview)) | Out-Null
                    }
                }
            }
        }
    }

    return $findings
}

# ── Main ─────────────────────────────────────────────────────────────────────

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "InputPath not found: $InputPath"
}

$rawXml = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8

$result = [ordered]@{
    inputPath          = (Resolve-Path -LiteralPath $InputPath).Path
    xmlWellFormed      = $false
    rootElement        = $null
    sourceSanityStatus = "not-applicable"
    probablyImportable = $false
    objectCount        = 0
    sourcePartCount    = 0
    failCount          = 0
    warnCount          = 0
    findings           = @()
}

try {
    $xmlDoc = New-Object System.Xml.XmlDocument
    $xmlDoc.PreserveWhitespace = $true
    $xmlDoc.LoadXml($rawXml)
    $result.xmlWellFormed = $true
    $result.rootElement   = $xmlDoc.DocumentElement.LocalName
} catch {
    $result.findings  = @([pscustomobject]@{
        severity    = "fail"
        code        = "xml-parse"
        message     = "XML malformado: $($_.Exception.Message)"
        lineNumber  = 0
        linePreview = ""
    })
    $result.failCount = 1
    if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { [pscustomobject]$result }
    return
}

$root     = $xmlDoc.DocumentElement
$trnNodes = [System.Collections.Generic.List[System.Xml.XmlElement]]::new()

if ($root.LocalName -eq "ExportFile") {
    foreach ($o in $root.SelectNodes("./Objects/Object[@type='$TransactionTypeGuid']")) {
        $trnNodes.Add($o) | Out-Null
    }
    $result.objectCount = $root.SelectNodes("./Objects/Object").Count
} elseif ($root.LocalName -eq "Object" -and $root.GetAttribute("type") -eq $TransactionTypeGuid) {
    $trnNodes.Add($root) | Out-Null
    $result.objectCount = 1
}

if ($trnNodes.Count -eq 0) {
    $result.probablyImportable = $result.xmlWellFormed
    if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { [pscustomobject]$result }
    return
}

$allFindings = [System.Collections.Generic.List[object]]::new()

foreach ($trnObj in $trnNodes) {
    $objName = $trnObj.GetAttribute("name")
    $ctx     = "Object:$objName"
    $clsData = Build-ClassificationData -ObjectNode $trnObj -XmlDoc $xmlDoc

    foreach ($f in (Check-LevelIntegrity -ObjectNode $trnObj -ObjectName $objName)) {
        $allFindings.Add($f) | Out-Null
    }

    foreach ($f in (Test-OrphanWwpScreenCode -ObjectNode $trnObj -ObjectName $objName)) {
        $allFindings.Add($f) | Out-Null
    }

    foreach ($partNode in $trnObj.SelectNodes("./Part[Source]")) {
        $srcText = $partNode.SelectSingleNode("./Source").InnerText
        if ([string]::IsNullOrWhiteSpace($srcText)) { continue }
        $result.sourcePartCount++
        $isEvents = $srcText -match '(?im)^\s*Event\s+[A-Za-z_]'
        foreach ($f in (Test-SourceForAttributeIssues `
                -SourceText $srcText -ContextLabel $ctx `
                -ClassMap $clsData.classMap -FormulaSet $clsData.formulaSet `
                -KnownNames $clsData.knownNames -IsEventsPart $isEvents)) {
            $allFindings.Add($f) | Out-Null
        }
    }
}

$result.findings  = $allFindings.ToArray()
$result.failCount = @($allFindings | Where-Object { $_.severity -eq "fail" }).Count
$result.warnCount = @($allFindings | Where-Object { $_.severity -eq "warn" }).Count

if ($result.failCount -gt 0) {
    $result.sourceSanityStatus = "fail"
    $result.probablyImportable = $false
} elseif ($result.warnCount -gt 0) {
    $result.sourceSanityStatus = "warn"
    $result.probablyImportable = $true
} else {
    $result.sourceSanityStatus = "pass"
    $result.probablyImportable = $true
}

if ($AsJson) { $result | ConvertTo-Json -Depth 6 } else { [pscustomobject]$result }
