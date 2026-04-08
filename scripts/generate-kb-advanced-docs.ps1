param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,

    [Parameter(Mandatory = $true)]
    [string]$OutputRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Format-MdCell {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    $text = $text -replace '\r?\n', '<br/>'
    $text = $text -replace '\|', '\|'
    return $text.Trim()
}

function Add-Table {
    param(
        [System.Text.StringBuilder]$Builder,
        [string[]]$Headers,
        [object[]]$Rows
    )

    [void]$Builder.AppendLine(('| ' + (($Headers | ForEach-Object { Format-MdCell $_ }) -join ' | ') + ' |'))
    [void]$Builder.AppendLine(('| ' + (($Headers | ForEach-Object { '---' }) -join ' | ') + ' |'))
    foreach ($row in $Rows) {
        $cells = foreach ($header in $Headers) { Format-MdCell $row.$header }
        [void]$Builder.AppendLine(('| ' + ($cells -join ' | ') + ' |'))
    }
    [void]$Builder.AppendLine()
}

function Get-ObjectNodePropertyValue {
    param(
        [System.Xml.XmlElement]$ObjectNode,
        [string]$PropertyName
    )
    $property = $ObjectNode.SelectSingleNode("./Properties/Property[Name='$PropertyName']/Value")
    if ($null -ne $property) { return $property.InnerText }
    return $null
}

function Get-PartTextLength {
    param([System.Xml.XmlElement]$PartNode)
    if ($null -eq $PartNode) { return 0 }
    return ($PartNode.InnerXml | Out-String).Trim().Length
}

function Test-PartApparentlyEmpty {
    param([System.Xml.XmlElement]$PartNode)

    if ($null -eq $PartNode) { return $true }

    $sourceNode = $PartNode.SelectSingleNode("./Source")
    $propertiesNode = $PartNode.SelectSingleNode("./Properties")
    $childElements = @($PartNode.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })

    if ($childElements.Count -eq 0) { return $true }

    if ($childElements.Count -eq 1 -and $null -ne $sourceNode) {
        return [string]::IsNullOrWhiteSpace($sourceNode.InnerText)
    }

    if ($childElements.Count -eq 1 -and $null -ne $propertiesNode) {
        return ($propertiesNode.ChildNodes.Count -eq 0)
    }

    if ($childElements.Count -eq 2 -and $null -ne $sourceNode -and $null -ne $propertiesNode) {
        return [string]::IsNullOrWhiteSpace($sourceNode.InnerText) -and ($propertiesNode.ChildNodes.Count -eq 0)
    }

    return $false
}

function Get-ReferenceSummary {
    param(
        [xml]$XmlDocument,
        [System.Xml.XmlElement]$ObjectNode
    )

    $refs = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($attr in @("parent", "parentGuid", "parentType", "moduleGuid")) {
        $value = $ObjectNode.GetAttribute($attr)
        if ($value) { [void]$refs.Add("${attr}:$value") }
    }

    $propValues = $XmlDocument.SelectNodes("//Property[Name='idBasedOn' or Name='BasedOn' or Name='DataSelector' or Name='MasterPage']/Value")
    foreach ($prop in $propValues) {
        if ($prop.InnerText) { [void]$refs.Add("property:$($prop.InnerText.Trim())") }
    }

    $attributeNodes = $XmlDocument.SelectNodes("//link/@webpanel | //attribute/@attribute | //descriptionAttribute/@attribute | //variable/@domain | //transaction/@transaction")
    foreach ($node in $attributeNodes) {
        if ($node.Value) { [void]$refs.Add("$($node.Name):$($node.Value.Trim())") }
    }

    return ($refs | Sort-Object) -join "; "
}

if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "SourceRoot not found: $SourceRoot"
}

if (-not (Test-Path -LiteralPath $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot | Out-Null
}

$files = Get-ChildItem -Path $SourceRoot -Recurse -File -Filter *.xml | Sort-Object FullName
$records = New-Object System.Collections.Generic.List[object]
$problemFiles = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($SourceRoot.Length).TrimStart('\')
    $folderType = Split-Path -Path $relativePath -Parent
    if ($folderType -match '\\') { $folderType = ($folderType -split '\\')[0] }

    try {
        [xml]$xmlDoc = Get-Content -LiteralPath $file.FullName -Raw
        $objectNode = $xmlDoc.SelectSingleNode("/Object")
        if ($null -eq $objectNode) {
            $problemFiles.Add([pscustomobject]@{
                RelativePath = $relativePath
                Issue = "Sem no /Object"
            }) | Out-Null
            continue
        }

        $partNodes = @($objectNode.SelectNodes("./Part"))
        $partInfos = foreach ($part in $partNodes) {
            [pscustomobject]@{
                PartType = $part.GetAttribute("type")
                ApparentlyEmpty = Test-PartApparentlyEmpty -PartNode $part
                TextLength = Get-PartTextLength -PartNode $part
            }
        }

        $record = [pscustomobject]@{
            RelativePath = $relativePath
            FileName = $file.Name
            FolderType = $folderType
            ObjectName = $objectNode.GetAttribute("name")
            ObjectGuid = $objectNode.GetAttribute("guid")
            ObjectTypeGuid = $objectNode.GetAttribute("type")
            Parent = $objectNode.GetAttribute("parent")
            ParentGuid = $objectNode.GetAttribute("parentGuid")
            ParentType = $objectNode.GetAttribute("parentType")
            ModuleGuid = $objectNode.GetAttribute("moduleGuid")
            FullyQualifiedName = $objectNode.GetAttribute("fullyQualifiedName")
            Description = $objectNode.GetAttribute("description")
            AttrNames = @($objectNode.Attributes | ForEach-Object { $_.Name })
            PartInfos = $partInfos
            PartCount = $partInfos.Count
            NonEmptyPartCount = @($partInfos | Where-Object { -not $_.ApparentlyEmpty }).Count
            PartTypes = @($partInfos | ForEach-Object { $_.PartType } | Where-Object { $_ } | Sort-Object -Unique)
            ReferenceSummary = Get-ReferenceSummary -XmlDocument $xmlDoc -ObjectNode $objectNode
            HasParent = -not [string]::IsNullOrWhiteSpace($objectNode.GetAttribute("parent"))
            HasModuleGuid = -not [string]::IsNullOrWhiteSpace($objectNode.GetAttribute("moduleGuid"))
            HasPatternData = ($xmlDoc.SelectNodes("//Data[@Pattern]").Count -gt 0)
            HasSource = ($xmlDoc.SelectNodes("//Source").Count -gt 0)
            FileSize = $file.Length
        }

        $records.Add($record) | Out-Null
    } catch {
        $problemFiles.Add([pscustomobject]@{
            RelativePath = $relativePath
            Issue = $_.Exception.Message
        }) | Out-Null
    }
}

$groups = $records | Group-Object FolderType | Sort-Object Name
$priorityMax = @("Transaction", "Procedure", "WebPanel", "Panel", "WorkWithForWeb", "DataProvider", "SDT")
$priorityMed = @("Theme", "ThemeClass", "DesignSystem", "API", "Module", "PackagedModule")
$priorityTypes = $priorityMax + $priorityMed

$typeSummaries = foreach ($group in $groups) {
    $items = @($group.Group)
    $count = $items.Count
    $sampleTypeGuid = ($items | Select-Object -First 1).ObjectTypeGuid
    $avgParts = [math]::Round((($items | Measure-Object -Property PartCount -Average).Average), 2)
    $withParent = @($items | Where-Object { $_.HasParent }).Count
    $withPattern = @($items | Where-Object { $_.HasPatternData }).Count
    $withModule = @($items | Where-Object { $_.HasModuleGuid }).Count
    $partCatalog = foreach ($partGroup in ($items | ForEach-Object { $_.PartInfos } | Group-Object PartType | Sort-Object Name)) {
        $presentCount = @($partGroup.Group | Select-Object -ExpandProperty PartType).Count
        $emptyCount = @($partGroup.Group | Where-Object { $_.ApparentlyEmpty }).Count
        $presencePct = if ($count -gt 0) { [math]::Round(($presentCount / $count) * 100, 1) } else { 0 }
        $emptyPct = if ($presentCount -gt 0) { [math]::Round(($emptyCount / $presentCount) * 100, 1) } else { 0 }
        $classification = if ($presencePct -ge 99) {
            "aparentemente obrigatorio"
        } elseif ($presencePct -lt 20) {
            "aparentemente raro"
        } elseif ($emptyPct -ge 80) {
            "aparentemente vazio/estrutural"
        } else {
            "aparentemente opcional"
        }
        if ($count -lt 3) {
            $classification = "$classification (amostra muito pequena)"
        }
        $examples = ($items | Where-Object { $_.PartTypes -contains $partGroup.Name } | Select-Object -First 3 | ForEach-Object { "$($_.ObjectName) [$($_.RelativePath)]" }) -join "; "
        [pscustomobject]@{
            FolderType = $group.Name
            ObjectTypeGuid = $sampleTypeGuid
            PartType = $partGroup.Name
            ObjectsWithPart = $presentCount
            PresencePct = $presencePct
            EmptyPct = $emptyPct
            PreliminaryClass = $classification
            Examples = $examples
        }
    }

    $attrCatalog = foreach ($attrGroup in ($items | ForEach-Object { $_.AttrNames } | Group-Object | Sort-Object Name)) {
        $attrCount = $attrGroup.Count
        $presencePct = if ($count -gt 0) { [math]::Round(($attrCount / $count) * 100, 1) } else { 0 }
        $bucket = if ($presencePct -ge 95) { "quase sempre" } elseif ($presencePct -ge 20) { "as vezes" } else { "raro" }
        $criticality = if ($attrGroup.Name -in @("guid", "name", "type")) {
            "forte indicio de criticidade estrutural"
        } elseif ($attrGroup.Name -in @("parent", "parentGuid", "parentType", "moduleGuid")) {
            "ligado a parent/module"
        } else {
            "papel ainda nao fechado"
        }
        [pscustomobject]@{
            FolderType = $group.Name
            Attribute = $attrGroup.Name
            ObjectsWithAttribute = $attrCount
            PresencePct = $presencePct
            PresenceBucket = $bucket
            Reading = $criticality
        }
    }

    $simpleSample = $items | Sort-Object PartCount, FileSize | Select-Object -First 2
    $complexSample = $items | Sort-Object @{Expression="PartCount";Descending=$true}, @{Expression="FileSize";Descending=$true} | Select-Object -First 2

    [pscustomobject]@{
        FolderType = $group.Name
        ObjectTypeGuid = $sampleTypeGuid
        Count = $count
        AveragePartCount = $avgParts
        WithParent = $withParent
        WithPattern = $withPattern
        WithModuleGuid = $withModule
        PartCatalog = $partCatalog
        AttrCatalog = $attrCatalog
        SimpleSample = $simpleSample
        ComplexSample = $complexSample
    }
}

$prioritySummaries = $typeSummaries | Where-Object { $_.FolderType -in $priorityTypes }

$matrixBuilder = New-Object System.Text.StringBuilder
[void]$matrixBuilder.AppendLine("# 10 - Matriz de Part Types por Tipo")
[void]$matrixBuilder.AppendLine()
[void]$matrixBuilder.AppendLine("- Evidência direta: frequências calculadas a partir do acervo XML informado ao script.")
[void]$matrixBuilder.AppendLine("- Inferência forte: a classificação preliminar abaixo usa presença e vazios recorrentes como heurística do acervo, não teste de importação.")
[void]$matrixBuilder.AppendLine()
foreach ($summary in $typeSummaries) {
    [void]$matrixBuilder.AppendLine("## $($summary.FolderType)")
    [void]$matrixBuilder.AppendLine()
    [void]$matrixBuilder.AppendLine("- Evidência direta: Object/@type = $($summary.ObjectTypeGuid) em $($summary.Count) objetos.")
    [void]$matrixBuilder.AppendLine("- Evidência direta: média de Part por objeto: $($summary.AveragePartCount).")
    [void]$matrixBuilder.AppendLine("- Inferência forte: classificações aparentemente obrigatorio/opcional/raro/vazio dependem da recorrência observada nesta KB.")
    if ($summary.Count -lt 3) {
        [void]$matrixBuilder.AppendLine("- Hipótese: como a amostra deste tipo tem menos de 3 objetos, a leitura de obrigatoriedade/opcionalidade deve ser tratada com cautela extra.")
    }
    [void]$matrixBuilder.AppendLine()
    Add-Table -Builder $matrixBuilder -Headers @("PartType", "ObjectsWithPart", "PresencePct", "EmptyPct", "PreliminaryClass", "Examples") -Rows @($summary.PartCatalog)
}
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "10-matriz-part-types-por-tipo.md"), $matrixBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

$fieldsBuilder = New-Object System.Text.StringBuilder
[void]$fieldsBuilder.AppendLine("# 11 - Campos Estaveis vs Variaveis do no Object")
[void]$fieldsBuilder.AppendLine()
[void]$fieldsBuilder.AppendLine("- Evidência direta: presença por atributo calculada por tipo extraído.")
[void]$fieldsBuilder.AppendLine("- Inferência forte: leituras como forte indicio de criticidade estrutural continuam heurísticas e não prova de importação.")
[void]$fieldsBuilder.AppendLine()
foreach ($summary in $typeSummaries) {
    [void]$fieldsBuilder.AppendLine("## $($summary.FolderType)")
    [void]$fieldsBuilder.AppendLine()
    [void]$fieldsBuilder.AppendLine("- Evidência direta: $($summary.Count) objetos analisados.")
    [void]$fieldsBuilder.AppendLine("- Evidência direta: objetos com parent: $($summary.WithParent); com moduleGuid: $($summary.WithModuleGuid).")
    [void]$fieldsBuilder.AppendLine("- Inferência forte: atributos ligados a parent/module tendem a importar contexto estrutural do objeto.")
    [void]$fieldsBuilder.AppendLine()
    Add-Table -Builder $fieldsBuilder -Headers @("Attribute", "ObjectsWithAttribute", "PresencePct", "PresenceBucket", "Reading") -Rows @($summary.AttrCatalog)
    $examples = @($summary.SimpleSample) + @($summary.ComplexSample) | Select-Object -Unique RelativePath,ObjectName
    foreach ($example in $examples) {
        [void]$fieldsBuilder.AppendLine("- Evidência direta: exemplo citado: $($example.ObjectName) em $($example.RelativePath).")
    }
    [void]$fieldsBuilder.AppendLine()
}
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "11-campos-estaveis-vs-variaveis.md"), $fieldsBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

$diffBuilder = New-Object System.Text.StringBuilder
[void]$diffBuilder.AppendLine("# 12 - Diffs Estruturais por Tipo")
[void]$diffBuilder.AppendLine()
[void]$diffBuilder.AppendLine("- Evidência direta: amostras simples/complexas foram escolhidas por menor/maior combinação de PartCount e tamanho de arquivo.")
[void]$diffBuilder.AppendLine("- Inferência forte: simples e complexo aqui significam complexidade estrutural no XML extraído, não complexidade funcional garantida.")
[void]$diffBuilder.AppendLine()
foreach ($summary in $prioritySummaries) {
    [void]$diffBuilder.AppendLine("## $($summary.FolderType)")
    [void]$diffBuilder.AppendLine()
    $simple = @($summary.SimpleSample)
    $complex = @($summary.ComplexSample)
    foreach ($item in $simple) {
        [void]$diffBuilder.AppendLine("- Evidência direta: amostra simples: $($item.ObjectName) em $($item.RelativePath) com $($item.PartCount) Part e $($item.NonEmptyPartCount) Part nao vazias.")
    }
    foreach ($item in $complex) {
        [void]$diffBuilder.AppendLine("- Evidência direta: amostra complexa: $($item.ObjectName) em $($item.RelativePath) com $($item.PartCount) Part e tamanho de $($item.FileSize) bytes.")
    }
    $simpleParts = @($simple | ForEach-Object { $_.PartTypes } | Sort-Object -Unique)
    $complexParts = @($complex | ForEach-Object { $_.PartTypes } | Sort-Object -Unique)
    $onlyComplex = @($complexParts | Where-Object { $_ -notin $simpleParts })
    $onlySimple = @($simpleParts | Where-Object { $_ -notin $complexParts })
    $onlyComplexText = if($onlyComplex.Count -gt 0){ [string]::Join('; ', $onlyComplex) } else { 'nenhum' }
    $onlySimpleText = if($onlySimple.Count -gt 0){ [string]::Join('; ', $onlySimple) } else { 'nenhum' }
    [void]$diffBuilder.AppendLine("- Evidência direta: Part type nas amostras simples: $(([string]::Join('; ', $simpleParts))).")
    [void]$diffBuilder.AppendLine("- Evidência direta: Part type nas amostras complexas: $(([string]::Join('; ', $complexParts))).")
    [void]$diffBuilder.AppendLine("- Evidência direta: Part type apenas nas amostras complexas: $onlyComplexText.")
    [void]$diffBuilder.AppendLine("- Evidência direta: Part type apenas nas amostras simples: $onlySimpleText.")
    [void]$diffBuilder.AppendLine("- Inferência forte: blocos recorrentes entre simples e complexos tendem a ser mais estáveis do que blocos exclusivos dos casos complexos.")
    [void]$diffBuilder.AppendLine("- Hipótese: editar primeiro blocos claramente textuais e recorrentes pode ter risco menor do que alterar blocos raros/opacos, mas isso ainda depende de validação posterior.")
    [void]$diffBuilder.AppendLine()
}
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "12-diffs-estruturais-por-tipo.md"), $diffBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

$cloneBuilder = New-Object System.Text.StringBuilder
[void]$cloneBuilder.AppendLine("# 13 - Guia de Clonagem Segura")
[void]$cloneBuilder.AppendLine()
[void]$cloneBuilder.AppendLine("Este guia e operacional, mas conservador.")
[void]$cloneBuilder.AppendLine()
[void]$cloneBuilder.AppendLine("- Evidência direta: ele se baseia em recorrencia de atributos, Part type, parent/module e blocos textuais observados.")
[void]$cloneBuilder.AppendLine("- Inferência forte: pode alterar aqui significa bom candidato para clonagem controlada, nao garantia de importacao.")
[void]$cloneBuilder.AppendLine()
foreach ($summary in $prioritySummaries) {
    $topParts = @($summary.PartCatalog | Sort-Object @{Expression="PresencePct";Descending=$true}, PartType | Select-Object -First 6)
    $rareParts = @($summary.PartCatalog | Where-Object { $_.PresencePct -lt 20 } | Select-Object -First 4)
    $confidence = if (($summary.WithPattern -gt 0) -or ($summary.WithParent -gt ($summary.Count / 2))) {
        "baixo"
    } elseif ($summary.AveragePartCount -le 3) {
        "alto"
    } else {
        "medio"
    }
    [void]$cloneBuilder.AppendLine("## $($summary.FolderType)")
    [void]$cloneBuilder.AppendLine()
    [void]$cloneBuilder.AppendLine("- Evidência direta: template recomendado: escolher objeto do mesmo diretório e mesmo Object/@type = $($summary.ObjectTypeGuid).")
    [void]$cloneBuilder.AppendLine("- Inferência forte: preservar guid, type, parent* e moduleGuid ate entender explicitamente a mudanca desejada.")
    [void]$cloneBuilder.AppendLine("- Inferência forte: blocos com Source, nomes e descricoes textuais sao candidatos mais plausiveis para edicao controlada quando aparecem de forma recorrente.")
    [void]$cloneBuilder.AppendLine("- Hipótese: blocos raros ou quase sempre vazios podem ser estruturais/reservados e merecem template real antes de alteracao.")
    [void]$cloneBuilder.AppendLine("- Nivel de confianca atual da clonagem: $confidence.")
    [void]$cloneBuilder.AppendLine("- Evidência direta: Part type mais recorrentes: $(([string]::Join('; ', ($topParts | ForEach-Object { $_.PartType })))).")
    if ($rareParts.Count -gt 0) {
        [void]$cloneBuilder.AppendLine("- Evidência direta: Part type raros observados: $(([string]::Join('; ', ($rareParts | ForEach-Object { $_.PartType })))).")
    }
    [void]$cloneBuilder.AppendLine("- Evidência direta: objetos com parent: $($summary.WithParent)/$($summary.Count); com pattern: $($summary.WithPattern)/$($summary.Count).")
    [void]$cloneBuilder.AppendLine()
}
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "13-guia-de-clonagem-segura.md"), $cloneBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

$mandatoryBuilder = New-Object System.Text.StringBuilder
[void]$mandatoryBuilder.AppendLine("# 14 - Indicios de Obrigatoriedade")
[void]$mandatoryBuilder.AppendLine()
[void]$mandatoryBuilder.AppendLine("- Evidência direta: percentuais abaixo saem da frequencia de Part type por tipo extraído.")
[void]$mandatoryBuilder.AppendLine("- Inferência forte: aparentemente obrigatorio significa presenca em ~100% das amostras do tipo nesta KB.")
[void]$mandatoryBuilder.AppendLine("- Hipótese: so teste real de importacao pode transformar isso em obrigatoriedade comprovada.")
[void]$mandatoryBuilder.AppendLine()
foreach ($summary in $prioritySummaries) {
    $mandatory = @($summary.PartCatalog | Where-Object { $_.PresencePct -ge 99 })
    $optional = @($summary.PartCatalog | Where-Object { $_.PresencePct -ge 20 -and $_.PresencePct -lt 99 -and $_.EmptyPct -lt 80 })
    $structural = @($summary.PartCatalog | Where-Object { $_.EmptyPct -ge 80 })
    $mandatoryText = if($mandatory.Count -gt 0){ [string]::Join('; ', ($mandatory | ForEach-Object { $_.PartType })) } else { 'nenhum' }
    $optionalText = if($optional.Count -gt 0){ [string]::Join('; ', ($optional | ForEach-Object { $_.PartType })) } else { 'nenhum' }
    $structuralText = if($structural.Count -gt 0){ [string]::Join('; ', ($structural | ForEach-Object { $_.PartType })) } else { 'nenhum' }
    [void]$mandatoryBuilder.AppendLine("## $($summary.FolderType)")
    [void]$mandatoryBuilder.AppendLine()
    [void]$mandatoryBuilder.AppendLine("- Evidência direta: total de objetos analisados: $($summary.Count).")
    [void]$mandatoryBuilder.AppendLine("- Evidência direta: Part type com forte indicio de obrigatoriedade: $mandatoryText.")
    [void]$mandatoryBuilder.AppendLine("- Evidência direta: Part type com indicio de opcionalidade: $optionalText.")
    [void]$mandatoryBuilder.AppendLine("- Evidência direta: Part type com indicio de vazio/estrutural: $structuralText.")
    [void]$mandatoryBuilder.AppendLine("- Inferência forte: blocos em todos os objetos do tipo merecem preservacao prioritaria na clonagem.")
    [void]$mandatoryBuilder.AppendLine("- Hipótese: blocos quase sempre vazios podem continuar sendo necessarios mesmo sem carregar conteudo util.")
    [void]$mandatoryBuilder.AppendLine()
}
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "14-indicios-de-obrigatoriedade.md"), $mandatoryBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

$readinessBuilder = New-Object System.Text.StringBuilder
[void]$readinessBuilder.AppendLine("# 15 - Tipos Prontos para Geracao Conservadora")
[void]$readinessBuilder.AppendLine()
[void]$readinessBuilder.AppendLine("- Evidência direta: a classificacao usa media de Part, dependencia de parent/module, presenca de pattern e raridade estrutural observada.")
[void]$readinessBuilder.AppendLine("- Inferência forte: apto aqui significa melhor candidato relativo dentro deste acervo, nao tipo comprovadamente importavel.")
[void]$readinessBuilder.AppendLine()
$readinessRows = foreach ($summary in $prioritySummaries) {
    $classification = if ($summary.Count -lt 10) {
        "apto somente por clonagem muito controlada"
    } elseif ($summary.WithPattern -gt 0 -or $summary.WithParent -gt ($summary.Count / 2)) {
        "apto somente por clonagem muito controlada"
    } elseif ($summary.AveragePartCount -le 3) {
        "apto para geracao conservadora"
    } else {
        "ainda nao apto sem template real"
    }
    $justification = if ($classification -eq "apto para geracao conservadora") {
        "menor complexidade estrutural observada e menos dependencia contextual aparente"
    } elseif ($summary.Count -lt 10) {
        "amostra pequena demais para liberar geracao sem forte controle de template"
    } elseif ($classification -eq "apto somente por clonagem muito controlada") {
        "relacoes de parent/pattern/module aparecem com frequencia relevante"
    } else {
        "mais `Part`, mais variacao estrutural ou pouco sinal de simplicidade repetivel"
    }
    [pscustomobject]@{
        FolderType = $summary.FolderType
        Classification = $classification
        Evidence = "$($summary.Count) objetos; media de Part = $($summary.AveragePartCount); parent = $($summary.WithParent); pattern = $($summary.WithPattern)"
        Reading = $justification
    }
}
Add-Table -Builder $readinessBuilder -Headers @("FolderType", "Classification", "Evidence", "Reading") -Rows $readinessRows
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "15-tipos-prontos-para-geracao-conservadora.md"), $readinessBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

$riskBuilder = New-Object System.Text.StringBuilder
[void]$riskBuilder.AppendLine("# 16 - Mapa de Risco por Tipo")
[void]$riskBuilder.AppendLine()
$riskRows = foreach ($summary in $prioritySummaries) {
    $risk = if ($summary.WithPattern -gt 0 -or $summary.AveragePartCount -ge 5) { "alto" } elseif ($summary.AveragePartCount -ge 3) { "medio" } else { "baixo" }
    $parentDep = if ($summary.WithParent -gt 0) { "$($summary.WithParent)/$($summary.Count)" } else { "0/$($summary.Count)" }
    $patternDep = if ($summary.WithPattern -gt 0) { "$($summary.WithPattern)/$($summary.Count)" } else { "0/$($summary.Count)" }
    $confidence = if ($risk -eq "baixo") { "media" } elseif ($risk -eq "medio") { "media-baixa" } else { "baixa" }
    $recommendation = if ($risk -eq "baixo") { "clonar a partir de template minimo do mesmo tipo" } elseif ($risk -eq "medio") { "clonar com diff estrutural e validacao manual" } else { "exigir template real muito proximo do caso alvo" }
    [pscustomobject]@{
        FolderType = $summary.FolderType
        StructuralRisk = $risk
        ParentModuleDependency = $parentDep
        PatternDependency = $patternDep
        CurrentConfidence = $confidence
        PracticalRecommendation = $recommendation
    }
}
Add-Table -Builder $riskBuilder -Headers @("FolderType", "StructuralRisk", "ParentModuleDependency", "PatternDependency", "CurrentConfidence", "PracticalRecommendation") -Rows $riskRows
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "16-mapa-de-risco-por-tipo.md"), $riskBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

$opsBuilder = New-Object System.Text.StringBuilder
[void]$opsBuilder.AppendLine("# 17 - Resumo Operacional para Gerador XPZ")
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("## Algoritmo sugerido por clonagem conservadora")
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("1. Selecionar o tipo alvo e localizar um template real do mesmo diretório e mesmo Object/@type.")
[void]$opsBuilder.AppendLine("2. Preferir template com estrutura simples quando o objetivo for um primeiro experimento controlado.")
[void]$opsBuilder.AppendLine("3. Preservar Object/@type, guid, parent* e moduleGuid e todos os Part type recorrentes do tipo ate existir motivo claro para alteracao.")
[void]$opsBuilder.AppendLine("4. Alterar primeiro apenas nomes, descricoes e blocos textuais recorrentes.")
[void]$opsBuilder.AppendLine("5. Abortar a geracao quando o tipo depender fortemente de parent, pattern ou Part type raros/opacos sem template equivalente.")
[void]$opsBuilder.AppendLine("6. Validar XML bem-formado, presenca dos Part type recorrentes e coerencia basica de atributos antes de qualquer empacotamento.")
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("## Quando abortar")
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("- Inferência forte: abortar quando o tipo tiver alto risco estrutural e nenhum template suficientemente proximo.")
[void]$opsBuilder.AppendLine("- Inferência forte: abortar quando o objeto alvo exigir pattern/contexto pai que nao esteja representado no template.")
[void]$opsBuilder.AppendLine("- Hipótese: abortar tambem quando surgirem Part type nao catalogados para o tipo alvo.")
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("## Quando exigir template real")
[void]$opsBuilder.AppendLine()
foreach ($row in ($riskRows | Where-Object { $_.StructuralRisk -eq "alto" })) {
    [void]$opsBuilder.AppendLine("- Evidência direta: $($row.FolderType) entrou em risco estrutural alto no acervo; recomendacao: $($row.PracticalRecommendation).")
}
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("## Quando aceitar geracao conservadora")
[void]$opsBuilder.AppendLine()
foreach ($row in ($readinessRows | Where-Object { $_.Classification -eq "apto para geracao conservadora" })) {
    [void]$opsBuilder.AppendLine("- Inferência forte: $($row.FolderType) e candidato relativamente melhor dentro desta KB: $($row.Reading).")
}
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("## Validacoes minimas antes de empacotar")
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("- XML bem-formado.")
[void]$opsBuilder.AppendLine("- Object/@type coerente com o tipo clonado.")
[void]$opsBuilder.AppendLine("- Part type recorrentes preservados.")
[void]$opsBuilder.AppendLine("- parent* e moduleGuid preservados quando presentes no template.")
[void]$opsBuilder.AppendLine("- Revisao manual dos campos textuais alterados.")
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("## Estrategia incremental recomendada")
[void]$opsBuilder.AppendLine()
[void]$opsBuilder.AppendLine("- Inferência forte: começar por tipos com menor complexidade estrutural relativa nesta KB.")
[void]$opsBuilder.AppendLine("- Inferência forte: depois avancar para tipos com mais contexto, sempre partindo de templates reais muito proximos.")
[void]$opsBuilder.AppendLine("- Hipótese: so apos alguns ciclos de validacao externa valera endurecer regras como obrigatorio ou seguro para editar.")
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "17-resumo-operacional-para-gerador-xpz.md"), $opsBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

$checklistBuilder = New-Object System.Text.StringBuilder
[void]$checklistBuilder.AppendLine("# 18 - Checklist para Novos Templates")
[void]$checklistBuilder.AppendLine()
[void]$checklistBuilder.AppendLine("- Inferência forte: para fechar lacunas, ainda vale exportar da IDE exemplos simples e complexos do mesmo tipo.")
[void]$checklistBuilder.AppendLine("- Hipótese: os templates abaixo devem reduzir duvidas sobre Part type raros, pattern e dependencia de parent/module.")
[void]$checklistBuilder.AppendLine()
[void]$checklistBuilder.AppendLine("## Itens sugeridos")
[void]$checklistBuilder.AppendLine()
foreach ($summary in $prioritySummaries) {
    $need = if ($summary.WithPattern -gt 0 -or $summary.AveragePartCount -ge 5) { "alta" } elseif ($summary.AveragePartCount -ge 3) { "media" } else { "baixa" }
    [void]$checklistBuilder.AppendLine("- Exportar pelo menos 1 template adicional de $($summary.FolderType) com necessidade $need, preferindo um caso simples e outro com mais contexto.")
}
[void]$checklistBuilder.AppendLine("- Exportar casos em que o mesmo tipo exista com e sem parent.")
[void]$checklistBuilder.AppendLine("- Exportar casos em que o mesmo tipo exista com e sem pattern.")
[void]$checklistBuilder.AppendLine("- Exportar exemplos onde Part type raro apareca acompanhado de comportamento conhecido na IDE.")
[System.IO.File]::WriteAllText((Join-Path $OutputRoot "18-checklist-para-novos-templates.md"), $checklistBuilder.ToString(), [System.Text.UTF8Encoding]::new($false))

Write-Output "Advanced KB docs generated under: $OutputRoot"
