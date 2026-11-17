#requires -Version 7.4

<#
.SYNOPSIS
    Verificador consultivo de indentacao de Source GeneXus (v1).

.DESCRIPTION
    Motor separado do SourceSanity. Findings de indentacao na fase 0 sao
    so warn/inconclusive (nunca alimentam probablyImportable). Allowlist v1:
    par Procedure + Source. Emite SEMPRE JSON no stdout. Nao expoe -AsJson.
    Exit 0 = JSON de analise emitido (inclui XML malformado no JSON);
    exit 20 = bloqueio de preflight/input invalido ou erro interno (trap),
    com JSON de status=bloqueado no stdout — nao e finding de indentacao.

.PARAMETER InputPath
    XML Object ou ExportFile.

.PARAMETER AcervoPath
    Pasta ObjetosDaKbEmXml (ou arquivo) para resolver baseline pelo GUID.

.PARAMETER BaselinePath
    Override explicito do XML baseline.

.PARAMETER AbsoluteIndentCheck
    Checa indentacao em todas as linhas de conteudo elegiveis da part
    (inclui preserved quando ha baseline compared), mesmo sem baseline;
    baseline ainda e resolvida/reportada quando possivel.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string]$AcervoPath,

    [string]$BaselinePath,

    [switch]$AbsoluteIndentCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProcedureObjectType = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$script:SourcePartType = '528d1c06-a9c2-420d-bd35-21dca83f12ff'
$script:ForEachHeadClausePattern = '(?i)^(where|order(\s+by)?|defined\s+by|unique|blocking|using)\b'
$script:NativeStartPattern = '(?i)^[ \t]*(csharp|java)(?=[ \t]|$)'
$script:StatusRank = @{
    'warn'           = 3
    'inconclusive'   = 2
    'pass'           = 1
    'not-applicable' = 0
}
$script:BaselineRank = @{
    'no-baseline-unresolved' = 3
    'no-baseline-new-object' = 2
    'compared'               = 1
    'not-applicable'         = 0
}

trap {
    [ordered]@{
        status             = 'bloqueado'
        exitCode           = 20
        inputPath          = $InputPath
        xmlWellFormed      = $false
        sourceIndentStatus = 'inconclusive'
        baselineCompared   = $false
        baselineStatus     = 'not-applicable'
        absoluteCheckApplied = [bool]$AbsoluteIndentCheck
        blockingReasons    = @($_.Exception.Message)
        findings           = @(
            [pscustomobject]@{
                severity         = 'fail'
                code             = 'preflight'
                message          = $_.Exception.Message
                sourceLineNumber = 0
                xmlLineNumber    = 0
                linePreview      = ''
            }
        )
        parts              = @()
    } | ConvertTo-Json -Depth 8
    exit 20
}

function Get-LinePreview {
    param([string]$Line)
    if ($null -eq $Line) { return '' }
    $trimmed = $Line.Trim()
    if ($trimmed.Length -le 140) { return $trimmed }
    return $trimmed.Substring(0, 140) + '...'
}

function New-IndentFinding {
    param(
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [int]$SourceLineNumber,
        [int]$XmlLineNumber,
        [string]$LinePreview,
        [string]$ObjectName = '',
        [string]$ObjectGuid = '',
        [string]$PartType = ''
    )
    return [pscustomobject]@{
        severity         = $Severity
        code             = $Code
        message          = $Message
        sourceLineNumber = $SourceLineNumber
        xmlLineNumber    = $XmlLineNumber
        linePreview      = $LinePreview
        objectName       = $ObjectName
        objectGuid       = $ObjectGuid
        partType         = $PartType
    }
}

function Get-ContentKey {
    param([string]$Line)
    return ($Line -replace '^[ \t]+', '')
}

function Get-LeadingWs {
    param([string]$Line)
    if ($Line -match '^([ \t]+)') { return $Matches[1] }
    return ''
}

function Test-IsBlankOrCommentOnly {
    param([string]$Line)
    $t = ($Line -replace '//.*$', '').Trim()
    return [string]::IsNullOrWhiteSpace($t)
}

function Get-OpenDepthKind {
    param([string]$CodeLine)
    if ($CodeLine -match '(?i)^\s*sub\b') { return 'Sub' }
    if ($CodeLine -match '(?i)^\s*header\b') { return 'Header' }
    if ($CodeLine -match '(?i)^\s*footer\b') { return 'Footer' }
    if ($CodeLine -match '(?i)^\s*do\s+case\b') { return 'DoCase' }
    if ($CodeLine -match '(?i)^\s*do\s+while\b') { return 'DoWhile' }
    if ($CodeLine -match "(?i)^\s*do\s+'") { return $null }
    if ($CodeLine -match '(?i)^\s*for\b') { return 'ForEach' }
    if ($CodeLine -match '(?i)^\s*if\b') {
        if ($CodeLine -match ';\s*$') { return $null }
        return 'If'
    }
    return $null
}

function Get-CloseDepthKind {
    param([string]$CodeLine)
    if ($CodeLine -match '(?i)^\s*endsub\b') { return 'Sub' }
    if ($CodeLine -match '(?i)^\s*endfor\b') { return 'ForEach' }
    if ($CodeLine -match '(?i)^\s*endcase\b') { return 'DoCase' }
    if ($CodeLine -match '(?i)^\s*enddo\b') { return 'DoWhile' }
    if ($CodeLine -match '(?i)^\s*endif\b') { return 'If' }
    if ($CodeLine -match '(?i)^\s*end\b') { return 'EndGeneric' }
    return $null
}

function Test-IsIntermediate {
    param([string]$CodeLine)
    if ($CodeLine -match '(?i)^\s*else\b') { return $true }
    if ($CodeLine -match '(?i)^\s*case\b') { return $true }
    if ($CodeLine -match '(?i)^\s*otherwise\b') { return $true }
    if ($CodeLine -match '(?i)^\s*when\s+(none|duplicate)\b') { return $true }
    return $false
}

function Test-IsForEachHeadClause {
    param([string]$CodeLine)
    return [bool]($CodeLine -match $script:ForEachHeadClausePattern)
}

function Test-LooksIncompleteForEachHead {
    # Conservador: "for each X" terminando com virgula/\ ou sem token de corpo na mesma linha
    # e a proxima linha util nao e clausula nem parece statement — marca inconclusive local.
    param([string]$CodeLine)
    if ($CodeLine -notmatch '(?i)^\s*for\b') { return $false }
    if ($CodeLine -match '(?i)\b(where|order|defined|unique|blocking|using)\b') { return $false }
    if ($CodeLine -match ',\s*$' -or $CodeLine -match '\\\s*$') { return $true }
    return $false
}

function Get-SourceLineModel {
    param([string]$SourceText)

    # Em PowerShell, o 2o arg de -split e Max-substrings: -1 NAO preserva todas as
    # linhas (vira 1 elemento). Usar 0 = sem limite, como o irmao SourceSanity.
    $rawLines = @($SourceText -split "`r?`n", 0)
    $models = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Generic.List[string]
    $inNative = $false
    $nativeStart = 0
    $incompleteHead = $false

    for ($i = 0; $i -lt $rawLines.Count; $i++) {
        $raw = $rawLines[$i]
        $lineNumber = $i + 1
        $code = [regex]::Replace($raw, '//.*$', '')
        $blank = Test-IsBlankOrCommentOnly -Line $raw
        $leading = Get-LeadingWs -Line $raw
        $contentKey = Get-ContentKey -Line $raw
        $excludeFromSignals = $false
        $inconclusiveLocal = $false
        $kind = 'content'
        $expectedDepth = $stack.Count

        if ($inNative) {
            if ($code -match $script:NativeStartPattern) {
                # novo nativo aninhado textual: permanece nativo
                $excludeFromSignals = $true
                $kind = 'native'
            } elseif (
                (Get-OpenDepthKind -CodeLine $code) -or
                (Get-CloseDepthKind -CodeLine $code) -or
                (Test-IsIntermediate -CodeLine $code) -or
                (Test-IsForEachHeadClause -CodeLine $code)
            ) {
                $inNative = $false
            } else {
                $excludeFromSignals = $true
                $kind = 'native'
            }
        }

        if (-not $inNative -and -not $blank -and ($code -match $script:NativeStartPattern)) {
            $inNative = $true
            $nativeStart = $lineNumber
            $excludeFromSignals = $true
            $kind = 'native'
        }

        if ($incompleteHead -and -not $blank -and -not $excludeFromSignals) {
            if (Test-IsForEachHeadClause -CodeLine $code) {
                $expectedDepth = $stack.Count
                $kind = 'foreach-head'
            } else {
                $incompleteHead = $false
            }
        }

        if (-not $blank -and -not $excludeFromSignals) {
            $closeKind = Get-CloseDepthKind -CodeLine $code
            if ($null -ne $closeKind) {
                $kind = 'close'
                if ($stack.Count -eq 0) {
                    $inconclusiveLocal = $true
                    $expectedDepth = 0
                } else {
                    $top = $stack[$stack.Count - 1]
                    if ($closeKind -eq 'EndGeneric') {
                        if ($top -eq 'Header' -or $top -eq 'Footer') {
                            $expectedDepth = $stack.Count - 1
                            $stack.RemoveAt($stack.Count - 1)
                        } else {
                            $inconclusiveLocal = $true
                            $expectedDepth = [Math]::Max(0, $stack.Count - 1)
                        }
                    } elseif ($top -ne $closeKind) {
                        $inconclusiveLocal = $true
                        $expectedDepth = [Math]::Max(0, $stack.Count - 1)
                    } else {
                        $expectedDepth = $stack.Count - 1
                        $stack.RemoveAt($stack.Count - 1)
                    }
                }
            } elseif (Test-IsIntermediate -CodeLine $code) {
                $kind = 'intermediate'
                $expectedDepth = [Math]::Max(0, $stack.Count - 1)
            } elseif (Test-IsForEachHeadClause -CodeLine $code) {
                $kind = 'foreach-head'
                if ($stack.Count -gt 0 -and $stack[$stack.Count - 1] -eq 'ForEach') {
                    $expectedDepth = $stack.Count
                } else {
                    $inconclusiveLocal = $true
                    $expectedDepth = $stack.Count
                }
            } else {
                $openKind = Get-OpenDepthKind -CodeLine $code
                if ($null -ne $openKind) {
                    $kind = 'open'
                    $expectedDepth = $stack.Count
                    if ($openKind -eq 'ForEach' -and (Test-LooksIncompleteForEachHead -CodeLine $code)) {
                        $incompleteHead = $true
                        $inconclusiveLocal = $true
                    }
                    $stack.Add($openKind) | Out-Null
                } else {
                    $kind = 'content'
                    $expectedDepth = $stack.Count
                }
            }
        }

        if ($blank) {
            $kind = 'blank'
            $excludeFromSignals = $true
        }

        $unit = 'none'
        if ($leading.Length -gt 0) {
            if ($leading -match '^\t+$') { $unit = 'tab' }
            elseif ($leading -match '^ +$') { $unit = 'space' }
            else { $unit = 'mixed' }
        }

        $models.Add([pscustomobject]@{
            sourceLineNumber   = $lineNumber
            raw                = $raw
            contentKey         = $contentKey
            leading            = $leading
            leadingLength      = $leading.Length
            unit               = $unit
            expectedDepth      = $expectedDepth
            kind               = $kind
            excludeFromSignals = $excludeFromSignals
            inconclusiveLocal  = $inconclusiveLocal
            preview            = (Get-LinePreview -Line $raw)
        }) | Out-Null
    }

    if ($inNative) {
        for ($j = 0; $j -lt $models.Count; $j++) {
            if ($models[$j].sourceLineNumber -ge $nativeStart -and $models[$j].kind -eq 'native') {
                $models[$j].inconclusiveLocal = $true
            }
        }
    }

    # Nao usar "return ,$array": o chamador com @() receberia 1 elemento (o array interno).
    return $models.ToArray()
}

function Get-IndentUnitMode {
    param([object[]]$Models)
    $tab = 0
    $space = 0
    foreach ($m in $Models) {
        if ($m.excludeFromSignals -or $m.kind -eq 'blank') { continue }
        if ($m.unit -eq 'tab') { $tab++ }
        elseif ($m.unit -eq 'space') { $space++ }
    }
    if ($tab -eq 0 -and $space -eq 0) { return 'none' }
    if ($tab -gt $space) { return 'tab' }
    if ($space -gt $tab) { return 'space' }
    return 'mixed'
}

function Get-SpaceUnitWidth {
    param([object[]]$Models)
    $widths = New-Object System.Collections.Generic.List[int]
    foreach ($m in $Models) {
        if ($m.excludeFromSignals) { continue }
        if ($m.unit -ne 'space') { continue }
        if ($m.expectedDepth -le 0) { continue }
        if (($m.leadingLength % $m.expectedDepth) -eq 0) {
            $widths.Add([int]($m.leadingLength / $m.expectedDepth)) | Out-Null
        }
    }
    if ($widths.Count -eq 0) { return 4 }
    $groups = $widths | Group-Object | Sort-Object Count -Descending
    return [int]$groups[0].Name
}

function Get-ExpectedLeadingLength {
    param(
        [object]$Model,
        [string]$UnitMode,
        [int]$SpaceWidth
    )
    if ($Model.expectedDepth -le 0) { return 0 }
    if ($UnitMode -eq 'tab') { return $Model.expectedDepth }
    if ($UnitMode -eq 'space') { return $Model.expectedDepth * $SpaceWidth }
    return $Model.expectedDepth
}

function Get-LcsLineDiff {
    param(
        [object[]]$OldModels,
        [object[]]$NewModels
    )

    $oldKeys = @($OldModels | ForEach-Object { $_.contentKey })
    $newKeys = @($NewModels | ForEach-Object { $_.contentKey })
    $n = $oldKeys.Count
    $m = $newKeys.Count
    $dp = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = $n - 1; $i -ge 0; $i--) {
        for ($j = $m - 1; $j -ge 0; $j--) {
            if ($oldKeys[$i] -ceq $newKeys[$j]) {
                $dp[$i, $j] = $dp[($i + 1), ($j + 1)] + 1
            } else {
                $a = $dp[($i + 1), $j]
                $b = $dp[$i, ($j + 1)]
                if ($a -ge $b) { $dp[$i, $j] = $a } else { $dp[$i, $j] = $b }
            }
        }
    }

    $ops = New-Object System.Collections.Generic.List[object]
    $i2 = 0
    $j2 = 0
    while ($i2 -lt $n -and $j2 -lt $m) {
        if ($oldKeys[$i2] -ceq $newKeys[$j2]) {
            $oldM = $OldModels[$i2]
            $newM = $NewModels[$j2]
            $class = 'preserved'
            if ($oldM.leading -cne $newM.leading) { $class = 'reindented' }
            $ops.Add([pscustomobject]@{
                classification = $class
                oldIndex       = $i2
                newIndex       = $j2
                oldModel       = $oldM
                newModel       = $newM
            }) | Out-Null
            $i2++
            $j2++
        } elseif ($dp[($i2 + 1), $j2] -ge $dp[$i2, ($j2 + 1)]) {
            $ops.Add([pscustomobject]@{
                classification = 'removed'
                oldIndex       = $i2
                newIndex       = -1
                oldModel       = $OldModels[$i2]
                newModel       = $null
            }) | Out-Null
            $i2++
        } else {
            $ops.Add([pscustomobject]@{
                classification = 'added'
                oldIndex       = -1
                newIndex       = $j2
                oldModel       = $null
                newModel       = $NewModels[$j2]
            }) | Out-Null
            $j2++
        }
    }
    while ($i2 -lt $n) {
        $ops.Add([pscustomobject]@{
            classification = 'removed'
            oldIndex       = $i2
            newIndex       = -1
            oldModel       = $OldModels[$i2]
            newModel       = $null
        }) | Out-Null
        $i2++
    }
    while ($j2 -lt $m) {
        $ops.Add([pscustomobject]@{
            classification = 'added'
            oldIndex       = -1
            newIndex       = $j2
            oldModel       = $null
            newModel       = $NewModels[$j2]
        }) | Out-Null
        $j2++
    }

    # Desempate local: pares remove+add adjacentes com indices proximos e
    # conteudo diferente no match LCS ja viram added/removed; marcar changed
    # quando contentKey difere mas estamos no mesmo "slot" nao se aplica no LCS puro.
    # Heuristica: se um removed e um added consecutivos e ambos nao-blank, classificar
    # o added como changed e descartar o removed do delta de indent
    # (removed nao entra em indent-under-depth / indent-unit-mismatch-in-delta).
    $refined = New-Object System.Collections.Generic.List[object]
    $k = 0
    $arr = $ops.ToArray()
    while ($k -lt $arr.Count) {
        if (
            $k + 1 -lt $arr.Count -and
            $arr[$k].classification -eq 'removed' -and
            $arr[$k + 1].classification -eq 'added' -and
            $null -ne $arr[$k].oldModel -and
            $null -ne $arr[$k + 1].newModel -and
            -not (Test-IsBlankOrCommentOnly -Line $arr[$k].oldModel.raw) -and
            -not (Test-IsBlankOrCommentOnly -Line $arr[$k + 1].newModel.raw)
        ) {
            $refined.Add([pscustomobject]@{
                classification = 'changed'
                oldIndex       = $arr[$k].oldIndex
                newIndex       = $arr[$k + 1].newIndex
                oldModel       = $arr[$k].oldModel
                newModel       = $arr[$k + 1].newModel
            }) | Out-Null
            $k += 2
            continue
        }
        $refined.Add($arr[$k]) | Out-Null
        $k++
    }
    return $refined.ToArray()
}

function Get-XmlSourceLineOffset {
    param(
        [string]$RawXml,
        [string]$ObjectGuid,
        [string]$PartType
    )
    # Aproximacao: primeira ocorrencia de Part type + Source apos o guid do objeto.
    if ([string]::IsNullOrWhiteSpace($RawXml)) { return 0 }
    $guidIdx = $RawXml.IndexOf($ObjectGuid, [System.StringComparison]::OrdinalIgnoreCase)
    if ($guidIdx -lt 0) { $guidIdx = 0 }
    $partNeedle = 'type="' + $PartType + '"'
    $partIdx = $RawXml.IndexOf($partNeedle, $guidIdx, [System.StringComparison]::OrdinalIgnoreCase)
    if ($partIdx -lt 0) { return 0 }
    $sourceIdx = $RawXml.IndexOf('<Source>', $partIdx, [System.StringComparison]::OrdinalIgnoreCase)
    if ($sourceIdx -lt 0) { return 0 }
    # Conta a linha de <Source> (1-based). O chamador faz
    # xmlLine = offset + sourceLineNumber - 1 (CDATA costuma abrir na mesma linha).
    $prefix = $RawXml.Substring(0, $sourceIdx)
    $lineOfSourceTag = @($prefix -split "`r?`n", 0).Count
    if ($lineOfSourceTag -lt 1) { return 1 }
    return $lineOfSourceTag
}

function Resolve-BaselineObjectNode {
    param(
        [string]$ObjectGuid,
        [string]$ObjectType,
        [string]$BaselinePathLocal,
        [string]$AcervoPathLocal
    )

    $result = [ordered]@{
        status     = 'no-baseline-unresolved'
        objectNode = $null
        path       = $null
        message    = ''
    }

    $usedBaselinePath = -not [string]::IsNullOrWhiteSpace($BaselinePathLocal)
    $usedAcervoPath = (-not $usedBaselinePath) -and (-not [string]::IsNullOrWhiteSpace($AcervoPathLocal))
    if (-not $usedBaselinePath -and -not $usedAcervoPath) {
        $result.message = 'Sem AcervoPath/BaselinePath'
        return [pscustomobject]$result
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $candidateSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    function Add-BaselineCandidate {
        param([string]$Path)
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        if ($candidateSet.Add($Path)) {
            $candidates.Add($Path) | Out-Null
        }
    }

    function Find-BaselineObjectMatches {
        param([System.Collections.Generic.List[string]]$Paths)
        $localMatches = New-Object System.Collections.Generic.List[object]
        foreach ($path in $Paths) {
            try {
                $doc = New-Object System.Xml.XmlDocument
                $doc.PreserveWhitespace = $true
                $doc.Load($path)
                $nodes = @($doc.SelectNodes("//Object[@guid='$ObjectGuid']"))
                if ($nodes.Count -eq 0 -and $doc.DocumentElement.LocalName -eq 'Object' -and $doc.DocumentElement.GetAttribute('guid') -eq $ObjectGuid) {
                    $nodes = @($doc.DocumentElement)
                }
                foreach ($node in $nodes) {
                    $localMatches.Add([pscustomobject]@{ path = $path; node = $node }) | Out-Null
                }
            } catch {
                return [pscustomobject]@{
                    ok      = $false
                    matches = @()
                    message = "Falha ao ler baseline $path : $($_.Exception.Message)"
                }
            }
        }
        return [pscustomobject]@{
            ok      = $true
            matches = $localMatches.ToArray()
            message = ''
        }
    }

    if ($usedBaselinePath) {
        if (-not (Test-Path -LiteralPath $BaselinePathLocal -PathType Leaf)) {
            $result.message = "BaselinePath not found: $BaselinePathLocal"
            return [pscustomobject]$result
        }
        Add-BaselineCandidate -Path ((Resolve-Path -LiteralPath $BaselinePathLocal).Path)
    } else {
        if (-not (Test-Path -LiteralPath $AcervoPathLocal)) {
            $result.message = "AcervoPath not found: $AcervoPathLocal"
            return [pscustomobject]$result
        }
        $acervoResolved = (Resolve-Path -LiteralPath $AcervoPathLocal).Path
        if (Test-Path -LiteralPath $acervoResolved -PathType Leaf) {
            Add-BaselineCandidate -Path $acervoResolved
        } else {
            # Varredura completa dos *.xml sob o acervo (sem teto): pre-filtro textual do GUID
            # em toda profundidade, depois Object[@guid]. Assim hit raso nao esconde o profundo
            # e Object duplicado entre profundidades vira unresolved.
            $xmlFiles = @()
            try {
                $xmlFiles = @(Get-ChildItem -LiteralPath $acervoResolved -Filter *.xml -File -Recurse -ErrorAction Stop)
            } catch {
                $result.message = "Falha ao enumerar AcervoPath: $($_.Exception.Message)"
                return [pscustomobject]$result
            }
            foreach ($xmlFile in $xmlFiles) {
                $full = $xmlFile.FullName
                try {
                    $hasGuidText = [bool](Select-String -LiteralPath $full -Pattern $ObjectGuid -SimpleMatch -Quiet -ErrorAction Stop)
                } catch {
                    $result.message = "Falha ao ler arquivo do acervo ${full}: $($_.Exception.Message)"
                    return [pscustomobject]$result
                }
                if ($hasGuidText) {
                    Add-BaselineCandidate -Path $full
                }
            }
        }
    }

    if ($candidates.Count -eq 0) {
        if ($usedBaselinePath) {
            $result.message = "BaselinePath sem candidato legivel: $BaselinePathLocal"
            return [pscustomobject]$result
        }
        $result.status = 'no-baseline-new-object'
        $result.message = "GUID $ObjectGuid ausente no acervo informado"
        return [pscustomobject]$result
    }

    $found = Find-BaselineObjectMatches -Paths $candidates
    if (-not $found.ok) {
        $result.message = $found.message
        return [pscustomobject]$result
    }
    $matches = @($found.matches)

    if ($matches.Count -eq 0) {
        if ($usedBaselinePath) {
            # Arquivo explicito existe mas nao prova objeto novo — so baseline errado/incompleto.
            $result.message = "BaselinePath nao contem Object com GUID $ObjectGuid"
            return [pscustomobject]$result
        }
        $result.status = 'no-baseline-new-object'
        $result.message = "GUID $ObjectGuid nao encontrado como Object no acervo"
        return [pscustomobject]$result
    }
    if ($matches.Count -gt 1) {
        $result.status = 'no-baseline-unresolved'
        $result.message = "GUID $ObjectGuid duplicado no acervo ($($matches.Count) hits)"
        return [pscustomobject]$result
    }

    $hit = $matches[0]
    $type = $hit.node.GetAttribute('type')
    if ($type -ne $ObjectType) {
        $result.status = 'no-baseline-unresolved'
        $result.message = "Object/@type divergente (input=$ObjectType baseline=$type)"
        return [pscustomobject]$result
    }

    $result.status = 'compared'
    $result.objectNode = $hit.node
    $result.path = $hit.path
    return [pscustomobject]$result
}

function Get-PartSourceText {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$PartType
    )
    $part = $ObjectNode.SelectSingleNode("./Part[@type='$PartType']/Source")
    if ($null -eq $part) { return $null }
    return $part.InnerText
}

function Get-ObjectTargets {
    param([System.Xml.XmlDocument]$XmlDocument)
    $list = New-Object System.Collections.Generic.List[object]
    $root = $XmlDocument.DocumentElement
    $objectNodes = @()
    if ($root.LocalName -eq 'ExportFile') {
        $objectNodes = @($root.SelectNodes('./Objects/Object'))
    } elseif ($root.LocalName -eq 'Object') {
        $objectNodes = @($root)
    }
    foreach ($objectNode in $objectNodes) {
        $list.Add([pscustomobject]@{
            objectName = $objectNode.GetAttribute('name')
            objectGuid = $objectNode.GetAttribute('guid')
            objectType = $objectNode.GetAttribute('type')
            node       = $objectNode
        }) | Out-Null
    }
    return $list.ToArray()
}

function Merge-WorstStatus {
    param([string[]]$Statuses)
    $best = 'not-applicable'
    $bestRank = -1
    foreach ($s in $Statuses) {
        if (-not $script:StatusRank.ContainsKey($s)) { continue }
        $r = $script:StatusRank[$s]
        if ($r -gt $bestRank) {
            $bestRank = $r
            $best = $s
        }
    }
    return $best
}

function Merge-WorstBaseline {
    param([string[]]$Statuses)
    $attempted = @($Statuses | Where-Object { $_ -ne 'not-applicable' })
    if ($attempted.Count -eq 0) { return 'not-applicable' }
    $best = 'compared'
    $bestRank = -1
    foreach ($s in $attempted) {
        if (-not $script:BaselineRank.ContainsKey($s)) { continue }
        $r = $script:BaselineRank[$s]
        if ($r -gt $bestRank) {
            $bestRank = $r
            $best = $s
        }
    }
    return $best
}

function Test-PartIndentation {
    param(
        [object]$Target,
        [string]$SourceText,
        [string]$RawXml,
        [bool]$Absolute,
        [string]$BaselinePathLocal,
        [string]$AcervoPathLocal
    )

    $xmlOffset = Get-XmlSourceLineOffset -RawXml $RawXml -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType
    $findings = New-Object System.Collections.Generic.List[object]
    $part = [ordered]@{
        objectName           = $Target.objectName
        objectGuid           = $Target.objectGuid
        objectType           = $Target.objectType
        partType             = $script:SourcePartType
        status               = 'pass'
        baselineStatus       = 'not-applicable'
        baselineCompared     = $false
        absoluteCheckApplied = $Absolute
        baselinePath         = $null
        findings             = @()
    }

    if ($null -eq $SourceText -or [string]::IsNullOrWhiteSpace($SourceText)) {
        $part.status = 'not-applicable'
        return [pscustomobject]$part
    }

    $newModels = @(Get-SourceLineModel -SourceText $SourceText)
    $unitMode = Get-IndentUnitMode -Models $newModels
    $spaceWidth = 4
    if ($unitMode -eq 'space') {
        $spaceWidth = Get-SpaceUnitWidth -Models $newModels
    } elseif ($unitMode -eq 'mixed') {
        $findings.Add((New-IndentFinding -Severity 'inconclusive' -Code 'indent-inconclusive' `
            -Message "$($Target.objectName): unidade de indentacao mista sem moda clara." `
            -SourceLineNumber 0 -XmlLineNumber $xmlOffset -LinePreview '' `
            -ObjectName $Target.objectName -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType)) | Out-Null
    }


    $baseline = Resolve-BaselineObjectNode -ObjectGuid $Target.objectGuid -ObjectType $Target.objectType `
        -BaselinePathLocal $BaselinePathLocal -AcervoPathLocal $AcervoPathLocal
    $part.baselineStatus = $baseline.status
    $part.baselinePath = $baseline.path
    $part.baselineCompared = ($baseline.status -eq 'compared')

    $deltaOps = @()
    $canCheckIndent = $false

    if ($baseline.status -eq 'compared') {
        $oldText = Get-PartSourceText -ObjectNode $baseline.objectNode -PartType $script:SourcePartType
        if ($null -eq $oldText) { $oldText = '' }
        $oldModels = @(Get-SourceLineModel -SourceText $oldText)
        $deltaOps = @(Get-LcsLineDiff -OldModels $oldModels -NewModels $newModels)
        $canCheckIndent = $true
    } elseif ($baseline.status -eq 'no-baseline-new-object') {
        $deltaOps = @(
            for ($i = 0; $i -lt $newModels.Count; $i++) {
                [pscustomobject]@{
                    classification = 'added'
                    oldIndex       = -1
                    newIndex       = $i
                    oldModel       = $null
                    newModel       = $newModels[$i]
                }
            }
        )
        $canCheckIndent = $true
    } elseif ($Absolute) {
        $deltaOps = @(
            for ($i = 0; $i -lt $newModels.Count; $i++) {
                [pscustomobject]@{
                    classification = 'added'
                    oldIndex       = -1
                    newIndex       = $i
                    oldModel       = $null
                    newModel       = $newModels[$i]
                }
            }
        )
        $canCheckIndent = $true
    } else {
        $findings.Add((New-IndentFinding -Severity 'inconclusive' -Code 'indent-inconclusive' `
            -Message "$($Target.objectName): baseline nao resolvida ($($baseline.status)): $($baseline.message)" `
            -SourceLineNumber 0 -XmlLineNumber $xmlOffset -LinePreview '' `
            -ObjectName $Target.objectName -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType)) | Out-Null
        $part.status = 'inconclusive'
        $part.findings = $findings.ToArray()
        return [pscustomobject]$part
    }

    if (-not $canCheckIndent) {
        $part.status = 'inconclusive'
        $part.findings = $findings.ToArray()
        return [pscustomobject]$part
    }

    # Absoluto: tambem linhas preserved (defeito herdado no baseline).
    $checkClasses = @('added', 'changed', 'reindented')
    if ($Absolute) {
        $checkClasses = @('added', 'changed', 'reindented', 'preserved')
    }

    foreach ($op in $deltaOps) {
        if ($op.classification -notin $checkClasses) { continue }
        $m = $op.newModel
        if ($null -eq $m) { continue }
        if ($m.excludeFromSignals) { continue }
        if ($m.kind -eq 'blank') { continue }

        $xmlLine = if ($xmlOffset -gt 0) { [Math]::Max(1, $xmlOffset + $m.sourceLineNumber - 1) } else { 0 }

        if ($m.inconclusiveLocal) {
            $findings.Add((New-IndentFinding -Severity 'inconclusive' -Code 'indent-inconclusive' `
                -Message "$($Target.objectName): trecho inconclusivo para profundidade (linha $($m.sourceLineNumber))." `
                -SourceLineNumber $m.sourceLineNumber -XmlLineNumber $xmlLine -LinePreview $m.preview `
                -ObjectName $Target.objectName -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType)) | Out-Null
            continue
        }

        if ($unitMode -eq 'mixed') {
            continue
        }

        if ($unitMode -eq 'tab' -and $m.unit -eq 'space') {
            $findings.Add((New-IndentFinding -Severity 'warn' -Code 'indent-unit-mismatch-in-delta' `
                -Message "$($Target.objectName): linha do delta usa espacos; moda da part e tab." `
                -SourceLineNumber $m.sourceLineNumber -XmlLineNumber $xmlLine -LinePreview $m.preview `
                -ObjectName $Target.objectName -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType)) | Out-Null
            continue
        }
        if ($unitMode -eq 'space' -and $m.unit -eq 'tab') {
            $findings.Add((New-IndentFinding -Severity 'warn' -Code 'indent-unit-mismatch-in-delta' `
                -Message "$($Target.objectName): linha do delta usa tab; moda da part e espacos." `
                -SourceLineNumber $m.sourceLineNumber -XmlLineNumber $xmlLine -LinePreview $m.preview `
                -ObjectName $Target.objectName -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType)) | Out-Null
            continue
        }
        if ($m.unit -eq 'mixed') {
            $findings.Add((New-IndentFinding -Severity 'warn' -Code 'indent-unit-mismatch-in-delta' `
                -Message "$($Target.objectName): leading WS misto (tab+espaco) na linha do delta." `
                -SourceLineNumber $m.sourceLineNumber -XmlLineNumber $xmlLine -LinePreview $m.preview `
                -ObjectName $Target.objectName -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType)) | Out-Null
            continue
        }

        if ($unitMode -eq 'none') {
            # Part sem indentacao observada: so cobra depth>0
            if ($m.expectedDepth -gt 0 -and $m.leadingLength -lt $m.expectedDepth) {
                $findings.Add((New-IndentFinding -Severity 'warn' -Code 'indent-under-depth' `
                    -Message "$($Target.objectName): recuo $($m.leadingLength) < profundidade esperada $($m.expectedDepth)." `
                    -SourceLineNumber $m.sourceLineNumber -XmlLineNumber $xmlLine -LinePreview $m.preview `
                    -ObjectName $Target.objectName -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType)) | Out-Null
            }
            continue
        }

        $expectedLen = Get-ExpectedLeadingLength -Model $m -UnitMode $unitMode -SpaceWidth $spaceWidth
        # under-depth: recuo estritamente menor que o esperado (1+ nivel)
        if ($m.expectedDepth -ge 1 -and $m.leadingLength -lt $expectedLen) {
            $findings.Add((New-IndentFinding -Severity 'warn' -Code 'indent-under-depth' `
                -Message "$($Target.objectName): recuo $($m.leadingLength) < esperado $expectedLen (depth $($m.expectedDepth), unidade $unitMode)." `
                -SourceLineNumber $m.sourceLineNumber -XmlLineNumber $xmlLine -LinePreview $m.preview `
                -ObjectName $Target.objectName -ObjectGuid $Target.objectGuid -PartType $script:SourcePartType)) | Out-Null
        }
    }

    $part.findings = $findings.ToArray()
    $hasWarn = @($findings | Where-Object { $_.severity -eq 'warn' }).Count -gt 0
    $hasInc = @($findings | Where-Object { $_.severity -eq 'inconclusive' -or $_.code -eq 'indent-inconclusive' }).Count -gt 0
    if ($hasWarn) { $part.status = 'warn' }
    elseif ($hasInc) { $part.status = 'inconclusive' }
    else { $part.status = 'pass' }
    return [pscustomobject]$part
}

# --- main ---

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "InputPath not found or not a file: $InputPath"
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$rawXml = Get-Content -LiteralPath $resolvedInput -Raw -Encoding UTF8

$result = [ordered]@{
    inputPath              = $resolvedInput
    xmlWellFormed          = $false
    rootElement            = $null
    sourceIndentStatus     = 'not-applicable'
    baselineCompared       = $false
    baselineStatus         = 'not-applicable'
    absoluteCheckApplied   = [bool]$AbsoluteIndentCheck
    warnCount              = 0
    inconclusiveCount      = 0
    passCount              = 0
    notApplicableCount     = 0
    objectCount            = 0
    inScopePartCount       = 0
    findings               = @()
    parts                  = @()
}

try {
    $xmlDocument = New-Object System.Xml.XmlDocument
    $xmlDocument.PreserveWhitespace = $true
    $xmlDocument.LoadXml($rawXml)
    $result.xmlWellFormed = $true
    $result.rootElement = $xmlDocument.DocumentElement.LocalName
} catch {
    $result.findings = @(
        New-IndentFinding -Severity 'inconclusive' -Code 'xml-parse' `
            -Message "XML malformado: $($_.Exception.Message)" `
            -SourceLineNumber 0 -XmlLineNumber 0 -LinePreview ''
    )
    $result.sourceIndentStatus = 'inconclusive'
    $result.inconclusiveCount = 1
    $result.baselineCompared = $false
    $result.baselineStatus = 'not-applicable'
    $result | ConvertTo-Json -Depth 8
    return
}

$targets = @(Get-ObjectTargets -XmlDocument $xmlDocument)
$result.objectCount = $targets.Count
$partResults = New-Object System.Collections.Generic.List[object]
$allFindings = New-Object System.Collections.Generic.List[object]

foreach ($target in $targets) {
    $isInScope = ($target.objectType -eq $script:ProcedureObjectType)
    $sourceText = Get-PartSourceText -ObjectNode $target.node -PartType $script:SourcePartType

    if (-not $isInScope) {
        if ($null -ne $sourceText) {
            $partResults.Add([pscustomobject]@{
                objectName           = $target.objectName
                objectGuid           = $target.objectGuid
                objectType           = $target.objectType
                partType             = $script:SourcePartType
                status               = 'not-applicable'
                baselineStatus       = 'not-applicable'
                baselineCompared     = $false
                absoluteCheckApplied = $false
                baselinePath         = $null
                findings             = @()
            }) | Out-Null
        }
        continue
    }

    $result.inScopePartCount++
    $partResult = Test-PartIndentation -Target $target -SourceText $sourceText -RawXml $rawXml `
        -Absolute:([bool]$AbsoluteIndentCheck) -BaselinePathLocal $BaselinePath -AcervoPathLocal $AcervoPath
    $partResults.Add($partResult) | Out-Null
    foreach ($f in @($partResult.findings)) {
        $allFindings.Add($f) | Out-Null
    }
}

$result.parts = $partResults.ToArray()
$result.findings = $allFindings.ToArray()

$inScopeStatuses = @($partResults | Where-Object { $_.objectType -eq $script:ProcedureObjectType } | ForEach-Object { $_.status })
if ($inScopeStatuses.Count -eq 0) {
    $result.sourceIndentStatus = 'not-applicable'
} else {
    $result.sourceIndentStatus = Merge-WorstStatus -Statuses $inScopeStatuses
}

$baselineStatuses = @($partResults | Where-Object { $_.objectType -eq $script:ProcedureObjectType } | ForEach-Object { $_.baselineStatus })
$result.baselineStatus = Merge-WorstBaseline -Statuses $baselineStatuses
$result.baselineCompared = @($partResults | Where-Object { $_.baselineCompared }).Count -gt 0
$result.absoluteCheckApplied = [bool]$AbsoluteIndentCheck -or (@($partResults | Where-Object { $_.absoluteCheckApplied }).Count -gt 0)

$result.warnCount = @($partResults | Where-Object { $_.status -eq 'warn' }).Count
$result.inconclusiveCount = @($partResults | Where-Object { $_.status -eq 'inconclusive' }).Count
$result.passCount = @($partResults | Where-Object { $_.status -eq 'pass' }).Count
$result.notApplicableCount = @($partResults | Where-Object { $_.status -eq 'not-applicable' }).Count

$result | ConvertTo-Json -Depth 8
