#requires -Version 7.4

<#
.SYNOPSIS
    Gate de sanidade estrutural de Source em XML GeneXus/XPZ.

.DESCRIPTION
    Recebe um único arquivo XML em -InputPath (alias -Path) e valida a
    sanidade estrutural dos blocos Source: balanceamento de blocos
    (If/For/Do/Sub) e avisos de estilo conservador. Não itera pastas.

.OUTPUTS
    Emite SEMPRE JSON no stdout (xmlWellFormed, sourceSanityStatus,
    probablyImportable, findings). Este motor NÃO expoe -AsJson; a flag e
    proibida por contrato (ver Test-XpzParameterNamingContract.ps1).
    Wrappers locais não devem repassar -AsJson nem passar uma pasta; se
    precisarem varrer varios XML ou montar JSON próprio, fazem isso no
    próprio wrapper, sem propagar a flag para baixo.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Regra type-aware: partes que NAO devem ter Source nao-vazio em certos tipos de objeto.
# Hoje so Procedure (84a12160): a parte Conditions (763f0d8b) de um Procedure deve estar
# vazia — Procedure nao tem filtro de Conditions (predicados vivem em For Each ... Where,
# parte 528d1c06); conteudo aqui causa erro de import src0055 ("Missed ';' at the end of
# the condition"). Evidencia: confirmado-import (GX18U13 + WorkWithPlus_Web 16.0.3.1) +
# confirmado-acervo (0/milhares de Procedures no FabricaBrasil). Outros tipos ficam fora
# por falta de evidencia (ex.: Data Selector tem Conditions legitima) — ver 999. GUID da
# parte Conditions documentado em 01a-catalogo-e-padroes-empiricos.md:138-139.
$script:ConditionsPartType = '763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9'
$script:ProcedureObjectType = '84a12160-f59b-4ad7-a683-ea4481ac23e9'

$script:ForbiddenNonEmptyParts = @{}
$script:ForbiddenNonEmptyParts[$script:ProcedureObjectType] = @{}
$script:ForbiddenNonEmptyParts[$script:ProcedureObjectType][$script:ConditionsPartType] = 'Procedure nao deve ter codigo na parte Conditions; mover predicados para For Each ... Where ou remover (conteudo aqui causa src0055 no import).'

# Modo declarativo type-aware: pares (Object type, Part type) cujo Source e
# DECLARATIVO, nao procedural. So a parte Rules (9b0a32a3) de uma Transaction
# (1db606f2) entra hoje: as rules de Transaction sao clausulas declarativas
# (`atributo = expr if cond;`, `noaccept(...) if cond;`, `error(...) if cond;`)
# encerradas por ';' e opcionalmente envolvidas por bloco `[web] { ... }`, nao
# blocos procedurais If/For/Do/Sub. O balanceador procedural gera falso
# unexpected-close/mismatched-close/unclosed-block nesse Source. Nesse UNICO par
# suprimimos apenas esses tres findings estruturais e preservamos todos os
# avisos de estilo (elseif, iif, dense-condition, call-in-condition).
# Nao generalizar para Conditions: WebPanel/Prompt/Selection List usam `when`
# multiline (nao casa If/For/Do/Sub) e ja passam no balanceamento procedural;
# DataSelector Condition/Source aninhado fica fora da cobertura. Events,
# Procedure e demais pares seguem no balanceamento procedural.
# GUID da parte Rules documentado em 01a/01b; Transaction em 01a-catalogo.
$script:TransactionObjectType = '1db606f2-af09-4cf9-a3b5-b481519d28f6'
$script:RulesPartType = '9b0a32a3-de6d-4be1-a4dd-1b85d3741534'
$script:DeclarativeBalancingCodes = @('unexpected-close', 'mismatched-close', 'unclosed-block')

$script:DeclarativeSourceParts = @{}
$script:DeclarativeSourceParts[$script:TransactionObjectType] = @{}
$script:DeclarativeSourceParts[$script:TransactionObjectType][$script:RulesPartType] = $true

trap {
    [ordered]@{
        status = 'bloqueado'
        exitCode = 20
        inputPath = $InputPath
        xmlWellFormed = $false
        sourceSanityStatus = 'fail'
        probablyImportable = $false
        blockingReasons = @($_.Exception.Message)
        findings = @(
            [pscustomobject]@{
                severity = 'fail'
                code = 'preflight'
                message = $_.Exception.Message
                lineNumber = 0
                linePreview = ''
            }
        )
    } | ConvertTo-Json -Depth 6
    exit 20
}

function Get-LinePreview {
    param(
        [string]$Line
    )

    if ($null -eq $Line) {
        return ""
    }

    $trimmed = $Line.Trim()
    if ($trimmed.Length -le 140) {
        return $trimmed
    }

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

function Get-OpenTokenKind {
    param(
        [string]$Line
    )

    if ($Line -match '^(?i)\s*sub\b') {
        return "Sub"
    }

    if ($Line -match '^(?i)\s*for\b') {
        return "ForEach"
    }

    if ($Line -match '^(?i)\s*do\s+case\b') {
        return "DoCase"
    }

    if ($Line -match '^(?i)\s*if\b') {
        if ($Line -match ';\s*$') { return $null }
        return "If"
    }

    return $null
}

function Get-CloseTokenKind {
    param(
        [string]$Line
    )

    if ($Line -match '^(?i)\s*endsub\b') {
        return "Sub"
    }

    if ($Line -match '^(?i)\s*endfor\b') {
        return "ForEach"
    }

    if ($Line -match '^(?i)\s*endcase\b') {
        return "DoCase"
    }

    if ($Line -match '^(?i)\s*endif\b') {
        return "If"
    }

    return $null
}

function Get-CallConditionMask {
    # Varredura local por Source, seguindo lex_source: aspas duplicadas e comentarios.
    # So call-in-condition usa a mascara; os demais diagnosticos mantem o texto antigo.
    param([string]$SourceText)
    $chars = $SourceText.ToCharArray()
    $state = 'code'
    $quote = [char]0
    for ($i = 0; $i -lt $chars.Length; $i++) {
        $c = $SourceText[$i]
        $next = [char]0
        if ($i + 1 -lt $chars.Length) { $next = $SourceText[$i + 1] }
        $newline = $c -eq "`r" -or $c -eq "`n"
        if ($state -eq 'line') {
            if ($newline) { $state = 'code' } else { $chars[$i] = ' ' }
        } elseif ($state -eq 'block') {
            if (-not $newline) { $chars[$i] = ' ' }
            if ($c -eq '*' -and $next -eq '/') {
                $chars[++$i] = ' '
                $state = 'code'
            }
        } elseif ($state -eq 'string') {
            if ($c -eq '\' -and $next -eq $quote) {
                return [pscustomobject]@{ conclusive = $false; text = $SourceText }
            }
            if (-not $newline) { $chars[$i] = ' ' }
            if ($c -eq $quote) {
                if ($next -eq $quote) { $chars[++$i] = ' ' } else { $state = 'code' }
            }
        } elseif ($c -eq '/' -and ($next -eq '/' -or $next -eq '*')) {
            if ($next -eq '/') { $state = 'line' } else { $state = 'block' }
            $chars[$i] = ' '
            $chars[++$i] = ' '
        } elseif ($c -eq "'" -or $c -eq '"') {
            $quote = $c
            $state = 'string'
            # Mesmo '' ocupa o argumento; # nao forma identificador seguido de (.
            $chars[$i] = '#'
        }
    }
    return [pscustomobject]@{ conclusive = ($state -eq 'code' -or $state -eq 'line'); text = (-join $chars) }
}

function Get-TransactionAttributeNames {
    param([System.Xml.XmlElement]$ObjectNode)
    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($ObjectNode.GetAttribute('type') -eq $script:TransactionObjectType) {
        foreach ($att in $ObjectNode.SelectNodes('.//Level/Attribute')) {
            $name = $att.InnerText.Trim()
            if ([string]::IsNullOrWhiteSpace($name)) { $name = $att.GetAttribute('name').Trim() }
            if (-not [string]::IsNullOrWhiteSpace($name)) { [void]$names.Add($name) }
        }
    }
    return ,$names
}

function Test-SourceTextSanity {
    param(
        [string]$SourceText,
        [string]$SourceLabel,
        [System.Collections.Generic.HashSet[string]]$KnownAttributeNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    )

    $lines = @($SourceText -split "`r?`n")
    $mask = Get-CallConditionMask -SourceText $SourceText
    $callLines = @($mask.text -split "`r?`n")
    $stack = New-Object System.Collections.Generic.List[object]
    $findings = New-Object System.Collections.Generic.List[object]

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $lineNumber = $index + 1
        $rawLine = $lines[$index]
        $lineWithoutComment = [regex]::Replace($rawLine, '//.*$', '')
        $preview = Get-LinePreview -Line $rawLine

        $closeKind = Get-CloseTokenKind -Line $lineWithoutComment
        if ($null -ne $closeKind) {
            if ($stack.Count -eq 0) {
                $findings.Add((New-Finding -Severity "fail" -Code "unexpected-close" -Message "${SourceLabel}: fechamento '$closeKind' sem abertura correspondente." -LineNumber $lineNumber -LinePreview $preview)) | Out-Null
            } else {
                $top = $stack[$stack.Count - 1]
                if ($top.kind -ne $closeKind) {
                    $message = "${SourceLabel}: fechamento '$closeKind' nao corresponde ao ultimo bloco aberto '$($top.kind)' iniciado na linha $($top.lineNumber)."
                    $findings.Add((New-Finding -Severity "fail" -Code "mismatched-close" -Message $message -LineNumber $lineNumber -LinePreview $preview)) | Out-Null
                } else {
                    $stack.RemoveAt($stack.Count - 1)
                }
            }
        }

        $openKind = Get-OpenTokenKind -Line $lineWithoutComment
        if ($null -ne $openKind) {
            $stack.Add([pscustomobject]@{
                kind       = $openKind
                lineNumber = $lineNumber
                preview    = $preview
            }) | Out-Null
        }

        if ($lineWithoutComment -match '(?i)\belseif\b') {
            $findings.Add((New-Finding -Severity "warn" -Code "elseif" -Message "${SourceLabel}: uso de 'elseif' detectado; prefira forma conservadora documentada quando houver duvida." -LineNumber $lineNumber -LinePreview $preview)) | Out-Null
        }

        if ($lineWithoutComment -match '(?i)\biif\s*\(') {
            $findings.Add((New-Finding -Severity "warn" -Code "iif" -Message "${SourceLabel}: uso de 'iif(...)' detectado; revisar se a trilha metodologica sustenta essa forma." -LineNumber $lineNumber -LinePreview $preview)) | Out-Null
        }

        if ($lineWithoutComment -match '^(?i)\s*(if|elseif)\b') {
            $booleanOps = ([regex]::Matches($lineWithoutComment, '(?i)\b(and|or|not)\b')).Count
            if ($booleanOps -ge 4 -or $lineWithoutComment.Length -ge 160) {
                $findings.Add((New-Finding -Severity "warn" -Code "dense-condition" -Message "${SourceLabel}: condicao potencialmente densa; revisar se o delta pode ser reescrito em forma mais conservadora." -LineNumber $lineNumber -LinePreview $preview)) | Out-Null
            }

        }

        $callLine = $lineWithoutComment
        if ($mask.conclusive) { $callLine = $callLines[$index] }
        # Mascara inconclusiva: detector anterior inteiro nesta parte, sem novas exclusoes.
        if ($callLine -match '^(?i)\s*(if|elseif)\b') {
            $conditionBody = $callLine -replace '^(?i)\s*(if|elseif)\b', ''
            if ($mask.conclusive -and $KnownAttributeNames.Count -gt 0) {
                # Consome a cadeia completa: Outro.AttrA nao vira o sufixo AttrA.
                # Colisao entre nome de atributo e modulo fica fora da resolucao semantica.
                $predicatePattern = '(?i)(?<![a-z0-9_&.])(?<receiver>[a-z_][a-z0-9_]*(?:\s*\.\s*[a-z_][a-z0-9_]*)*)\s*\.\s*(IsEmpty|IsNull)\s*\(\s*\)'
                $conditionBody = [regex]::Replace($conditionBody, $predicatePattern, [System.Text.RegularExpressions.MatchEvaluator]{
                    param($match)
                    $before = $match.Index - 1
                    while ($before -ge 0 -and [char]::IsWhiteSpace($conditionBody[$before])) { $before-- }
                    if ($before -ge 0 -and $conditionBody[$before] -in @('.', '&')) { return $match.Value }
                    if ($KnownAttributeNames.Contains($match.Groups['receiver'].Value.Trim())) { return ' ' }
                    return $match.Value
                })
            }
            $stripped = $conditionBody -replace '(?i)\b(and|or|not)\s*\(', '('
            $stripped = $stripped -replace '(?i)\biif\s*\(', '('
            $stripped = $stripped -replace '(?i)&[a-z_][a-z0-9_]*(\.[a-z_][a-z0-9_]*)*\s*\(', ''
            if ($stripped -match '(?i)\b[a-z_][a-z0-9_]*\s*\(') {
                $findings.Add((New-Finding -Severity "warn" -Code "call-in-condition" -Message "${SourceLabel}: chamada detectada dentro de condicao; comparar com o estilo dominante do proprio objeto antes de empacotar." -LineNumber $lineNumber -LinePreview $preview)) | Out-Null
            }
        }
    }

    foreach ($remaining in $stack) {
        $message = "${SourceLabel}: bloco '$($remaining.kind)' aberto na linha $($remaining.lineNumber) sem fechamento correspondente."
        $findings.Add((New-Finding -Severity "fail" -Code "unclosed-block" -Message $message -LineNumber $remaining.lineNumber -LinePreview $remaining.preview)) | Out-Null
    }

    return $findings
}

function Get-ObjectSourceParts {
    param(
        [System.Xml.XmlElement]$ObjectNode
    )

    $parts = New-Object System.Collections.Generic.List[object]
    $partNodes = $ObjectNode.SelectNodes("./Part[Source]")
    foreach ($partNode in $partNodes) {
        $sourceNode = $partNode.SelectSingleNode("./Source")
        if ($null -eq $sourceNode) {
            continue
        }

        $parts.Add([pscustomobject]@{
            partType   = $partNode.GetAttribute("type")
            sourceText = $sourceNode.InnerText
        }) | Out-Null
    }

    return $parts
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "InputPath not found: $InputPath"
}

$rawXml = Get-Content -LiteralPath $InputPath -Raw -Encoding UTF8
$result = [ordered]@{
    inputPath              = (Resolve-Path -LiteralPath $InputPath).Path
    xmlWellFormed          = $false
    rootElement            = $null
    sourceSanityStatus     = "not-applicable"
    probablyImportable     = $false
    objectCount            = 0
    sourcePartCount        = 0
    failCount              = 0
    warnCount              = 0
    findings               = @()
}

try {
    $xmlDocument = New-Object System.Xml.XmlDocument
    $xmlDocument.PreserveWhitespace = $true
    $xmlDocument.LoadXml($rawXml)
    $result.xmlWellFormed = $true
    $result.rootElement = $xmlDocument.DocumentElement.LocalName
} catch {
    $result.findings = @(
        [pscustomobject]@{
            severity    = "fail"
            code        = "xml-parse"
            message     = "XML malformado: $($_.Exception.Message)"
            lineNumber  = 0
            linePreview = ""
        }
    )
    $result.failCount = 1
    $result | ConvertTo-Json -Depth 6
    return
}

$sourceTargets = New-Object System.Collections.Generic.List[object]
$root = $xmlDocument.DocumentElement

if ($root.LocalName -eq "ExportFile") {
    $objectNodes = $root.SelectNodes("./Objects/Object")
    foreach ($objectNode in $objectNodes) {
        $objectName = $objectNode.GetAttribute("name")
        $objectType = $objectNode.GetAttribute("type")
        $knownAttributeNames = Get-TransactionAttributeNames -ObjectNode $objectNode
        $partSources = Get-ObjectSourceParts -ObjectNode $objectNode
        foreach ($partSource in $partSources) {
            $sourceTargets.Add([pscustomobject]@{
                objectName  = $objectName
                objectType  = $objectType
                partType    = $partSource.partType
                sourceLabel = "Object:$objectName Part:$($partSource.partType)"
                sourceText  = $partSource.sourceText
                knownAttributeNames = $knownAttributeNames
            }) | Out-Null
        }
    }
    $result.objectCount = $objectNodes.Count
} elseif ($root.LocalName -eq "Object") {
    $knownAttributeNames = Get-TransactionAttributeNames -ObjectNode $root
    $partSources = Get-ObjectSourceParts -ObjectNode $root
    foreach ($partSource in $partSources) {
        $sourceTargets.Add([pscustomobject]@{
            objectName  = $root.GetAttribute("name")
            objectType  = $root.GetAttribute("type")
            partType    = $partSource.partType
            sourceLabel = "Object:$($root.GetAttribute("name")) Part:$($partSource.partType)"
            sourceText  = $partSource.sourceText
            knownAttributeNames = $knownAttributeNames
        }) | Out-Null
    }
    $result.objectCount = 1
}

$allFindings = New-Object System.Collections.Generic.List[object]
foreach ($sourceTarget in $sourceTargets) {
    if ([string]::IsNullOrWhiteSpace($sourceTarget.sourceText)) {
        continue
    }

    # Type-aware: parte que nao deve ter conteudo neste tipo de objeto (ex.: Conditions em Procedure).
    if ($script:ForbiddenNonEmptyParts.ContainsKey($sourceTarget.objectType) -and
        $script:ForbiddenNonEmptyParts[$sourceTarget.objectType].ContainsKey($sourceTarget.partType)) {
        $nonEmpty = @($sourceTarget.sourceText -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($nonEmpty.Count -gt 0) { $preview = $nonEmpty[0] } else { $preview = '' }
        $message = "$($sourceTarget.sourceLabel): $($script:ForbiddenNonEmptyParts[$sourceTarget.objectType][$sourceTarget.partType])"
        $allFindings.Add((New-Finding -Severity "fail" -Code "procedural-in-conditions" -Message $message -LineNumber 1 -LinePreview (Get-LinePreview -Line $preview))) | Out-Null
        continue
    }

    $findings = Test-SourceTextSanity -SourceText $sourceTarget.sourceText -SourceLabel $sourceTarget.sourceLabel -KnownAttributeNames $sourceTarget.knownAttributeNames

    # Modo declarativo: neste par (Object type, Part type) o Source e declarativo;
    # suprime so os findings de balanceamento procedural, preserva os avisos.
    $isDeclarativePart = $script:DeclarativeSourceParts.ContainsKey($sourceTarget.objectType) -and
        $script:DeclarativeSourceParts[$sourceTarget.objectType].ContainsKey($sourceTarget.partType)

    foreach ($finding in $findings) {
        if ($isDeclarativePart -and ($script:DeclarativeBalancingCodes -contains $finding.code)) {
            continue
        }
        $allFindings.Add($finding) | Out-Null
    }
}

$result.sourcePartCount = $sourceTargets.Count
$result.findings = $allFindings.ToArray()
$result.failCount = @($allFindings | Where-Object { $_.severity -eq "fail" }).Count
$result.warnCount = @($allFindings | Where-Object { $_.severity -eq "warn" }).Count

if ($sourceTargets.Count -eq 0) {
    $result.sourceSanityStatus = "not-applicable"
    $result.probablyImportable = [bool]$result.xmlWellFormed
} elseif ($result.failCount -gt 0) {
    $result.sourceSanityStatus = "fail"
    $result.probablyImportable = $false
} elseif ($result.warnCount -gt 0) {
    $result.sourceSanityStatus = "warn"
    $result.probablyImportable = $true
} else {
    $result.sourceSanityStatus = "pass"
    $result.probablyImportable = $true
}

$result | ConvertTo-Json -Depth 6
