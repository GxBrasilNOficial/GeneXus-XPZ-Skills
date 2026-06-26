#requires -Version 7.4

<#
.SYNOPSIS
Extrai e verifica objetos exportados de um pacote GeneXus XPZ/XML.

.DESCRIPTION
Lê um pacote GeneXus exportado a partir de um arquivo .xpz, de um arquivo .xml
ou de uma pasta contendo esse XML, materializa os objetos exportados em uma árvore
de diretórios por tipo e pode verificar se o pacote foi refletido corretamente
no destino.

.PARAMETER InputPath
Caminho para um .xpz, para o XML do pacote exportado ou para a pasta que contém
esse XML.

.PARAMETER DestinationRoot
Raiz da árvore de XMLs individualizados por tipo.

.PARAMETER VerifyOnly
Executa apenas conferência, sem regravar arquivos no destino.

.PARAMETER FullSnapshot
Além da conferência do pacote atual, compara o snapshot inteiro do destino com o
conteúdo do pacote. Use este modo para exports completos da KB.

.PARAMETER ReportPath
Caminho opcional para salvar um relatório JSON com o resultado.

.PARAMETER KeepReport
Mantem o relatório JSON mesmo quando a execução termina sem erro.

.PARAMETER ExpectedItems
Lista opcional de itens esperados para comparacao com o retorno oficial do XPZ,
no formato `Tipo:Nome`.

.PARAMETER KbMetadataPath
Caminho opcional para kb-source-metadata.md da pasta paralela.

.PARAMETER CatalogPath
Caminho opcional para gx-object-type-catalog.json (padrão: scripts/ da base compartilhada).

.PARAMETER CatalogOverridePath
Caminho opcional para gx-object-type-catalog.override.json (paliativo local; não silencioso).

.PARAMETER ParallelKbRoot
Raiz da pasta paralela; quando informada, resolve override em scripts/gx-object-type-catalog.override.json.

.PARAMETER DiscoveryReportPath
Quando o pacote contiver GUID de tipo desconhecido, grava relatório JSON de triagem antes de falhar.

.PARAMETER BlockCrossFlowDataSource
Bloqueio opt-in: quando um item entrante colide no acervo com um arquivo de origem
(`dataSource`) divergente — caso central moderno↔legado (export GeneXus 9) —, aborta o sync
ANTES de gravar metadata ou XML, em vez do comportamento padrão fail-soft (que só sinaliza a
colisão em `Summary.CrossFlowCollisions` e no stderr e segue). Separado do fail-closed de pacote
misto. Quanto a um XML existente **não-parseável**: a detecção não gera colisão nem bloqueia (nem
sob este switch), só um warning — mas isso **não garante a sobrescrita**: o sync pode falhar
adiante ao processar um arquivo existente corrompido (estágios de parse preexistentes, fora do
escopo desta frente).

.EXAMPLE
.\Sync-GeneXusXpzToXml.ps1 -InputPath C:\Exports\MeuPacote.xpz -DestinationRoot C:\Acervo\ObjetosDaKbEmXml

.EXAMPLE
.\Sync-GeneXusXpzToXml.ps1 -InputPath C:\Exports\MeuFull.xml -DestinationRoot C:\Acervo\ObjetosDaKbEmXml -VerifyOnly -FullSnapshot
#>

param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,

    [switch]$VerifyOnly,

    [switch]$FullSnapshot,

    [string]$ReportPath,

    [switch]$KeepReport,

    [string[]]$ExpectedItems = @(),

    [string]$KbMetadataPath = "",

    [string]$CatalogPath = "",

    [string]$CatalogOverridePath = "",

    [string]$ParallelKbRoot = "",

    [string]$DiscoveryReportPath = "",

    [switch]$BlockCrossFlowDataSource
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

$kbMetadataEditSupportScript = Join-Path $PSScriptRoot 'XpzKbSourceMetadataEditSupport.ps1'
if (-not (Test-Path -LiteralPath $kbMetadataEditSupportScript -PathType Leaf)) {
    throw "BLOCK: suporte de edicao de kb-source-metadata nao encontrado: $kbMetadataEditSupportScript"
}

. $kbMetadataEditSupportScript

$supportScript = Join-Path $PSScriptRoot 'GeneXusObjectTypeCatalogSupport.ps1'
if (-not (Test-Path -LiteralPath $supportScript -PathType Leaf)) {
    throw "Required support script not found: $supportScript"
}
. $supportScript

$fileBaseNameNormalizationSupportScript = Join-Path $PSScriptRoot 'GeneXusFileBaseNameNormalizationSupport.ps1'
if (-not (Test-Path -LiteralPath $fileBaseNameNormalizationSupportScript -PathType Leaf)) {
    throw "Required support script not found: $fileBaseNameNormalizationSupportScript"
}
. $fileBaseNameNormalizationSupportScript

$legacyExportSupportScript = Join-Path $PSScriptRoot 'GeneXusLegacyExportFileSupport.ps1'
if (-not (Test-Path -LiteralPath $legacyExportSupportScript -PathType Leaf)) {
    throw "Required support script not found: $legacyExportSupportScript"
}
. $legacyExportSupportScript

function New-TempDirectory {
    $tempBase = [System.IO.Path]::GetTempPath()
    $tempName = "gx-xpz-" + [System.Guid]::NewGuid().ToString("N")
    $tempPath = Join-Path $tempBase $tempName
    [System.IO.Directory]::CreateDirectory($tempPath) | Out-Null
    return $tempPath
}

function Resolve-PackageXmlPath {
    param([string]$RawInputPath)

    $resolved = (Resolve-Path -LiteralPath $RawInputPath).Path

    if (Test-Path -LiteralPath $resolved -PathType Container) {
        $xmlFiles = @(Get-ChildItem -LiteralPath $resolved -Filter *.xml -File)
        if ($xmlFiles.Count -ne 1) {
            throw "Expected exactly one XML file inside folder '$resolved', found $($xmlFiles.Count)."
        }
        return @{
            XmlPath = $xmlFiles[0].FullName
            TempPath = $null
        }
    }

    if ($resolved.ToLowerInvariant().EndsWith(".xml")) {
        return @{
            XmlPath = $resolved
            TempPath = $null
        }
    }

    if ($resolved.ToLowerInvariant().EndsWith(".xpz")) {
        $tempPath = New-TempDirectory
        $zipPath = Join-Path $tempPath "package.zip"
        Copy-Item -LiteralPath $resolved -Destination $zipPath
        Expand-Archive -LiteralPath $zipPath -DestinationPath $tempPath -Force
        $xmlFiles = @(Get-ChildItem -LiteralPath $tempPath -Filter *.xml -File)
        if ($xmlFiles.Count -ne 1) {
            throw "Expected exactly one XML file inside XPZ '$resolved', found $($xmlFiles.Count)."
        }
        return @{
            XmlPath = $xmlFiles[0].FullName
            TempPath = $tempPath
        }
    }

    throw "Unsupported InputPath '$resolved'. Use a folder, .xml, or .xpz."
}

function Convert-ExpectedItemsToComparison {
    param(
        [string[]]$ExpectedItems,
        [object[]]$ActualItems
    )

    $rawExpectedItems = New-Object System.Collections.Generic.List[string]
    foreach ($entry in @($ExpectedItems)) {
        if ($null -eq $entry) {
            continue
        }

        foreach ($part in ($entry -split '[,\r\n;]+')) {
            $normalizedPart = $part.Trim()
            if (-not [string]::IsNullOrWhiteSpace($normalizedPart)) {
                $rawExpectedItems.Add($normalizedPart) | Out-Null
            }
        }
    }

    if ($rawExpectedItems.Count -eq 0) {
        return $null
    }

    $expectedKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $expectedEntries = New-Object System.Collections.Generic.List[object]
    foreach ($rawItem in $rawExpectedItems) {
        $separatorIndex = $rawItem.IndexOf(':')
        if ($separatorIndex -lt 1 -or $separatorIndex -ge ($rawItem.Length - 1)) {
            throw "Invalid ExpectedItems entry '$rawItem'. Use the format 'Tipo:Nome'."
        }

        $folderType = $rawItem.Substring(0, $separatorIndex).Trim()
        $logicalName = $rawItem.Substring($separatorIndex + 1).Trim()
        if ([string]::IsNullOrWhiteSpace($folderType) -or [string]::IsNullOrWhiteSpace($logicalName)) {
            throw "Invalid ExpectedItems entry '$rawItem'. Use the format 'Tipo:Nome'."
        }

        $key = "$folderType|$logicalName"
        if ($expectedKeys.Add($key)) {
            $expectedEntries.Add([pscustomobject]@{
                FolderType = $folderType
                LogicalName = $logicalName
                Key = $key
            }) | Out-Null
        }
    }

    $actualKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $actualMap = @{}
    foreach ($item in $ActualItems) {
        $key = "$($item.FolderType)|$($item.LogicalName)"
        [void]$actualKeys.Add($key)
        if (-not $actualMap.ContainsKey($key)) {
            $actualMap[$key] = [pscustomobject]@{
                FolderType = $item.FolderType
                LogicalName = $item.LogicalName
                PackageSection = $item.PackageSection
            }
        }
    }

    $expectedReturned = New-Object System.Collections.Generic.List[object]
    $expectedMissing = New-Object System.Collections.Generic.List[object]
    foreach ($expectedEntry in $expectedEntries) {
        if ($actualKeys.Contains($expectedEntry.Key)) {
            $expectedReturned.Add([pscustomobject]@{
                FolderType = $expectedEntry.FolderType
                LogicalName = $expectedEntry.LogicalName
            }) | Out-Null
        } else {
            $expectedMissing.Add([pscustomobject]@{
                FolderType = $expectedEntry.FolderType
                LogicalName = $expectedEntry.LogicalName
            }) | Out-Null
        }
    }

    $additionalOfficial = New-Object System.Collections.Generic.List[object]
    foreach ($actualKey in $actualMap.Keys | Sort-Object) {
        if (-not $expectedKeys.Contains($actualKey)) {
            $additionalOfficial.Add($actualMap[$actualKey]) | Out-Null
        }
    }

    $expectedItemsForReport = New-Object System.Collections.Generic.List[object]
    foreach ($expectedEntry in $expectedEntries) {
        $expectedItemsForReport.Add([pscustomobject]@{
            FolderType = $expectedEntry.FolderType
            LogicalName = $expectedEntry.LogicalName
        }) | Out-Null
    }

    return [pscustomobject]@{
        ExpectedItemsProvided = $true
        ExpectedItems = @($expectedItemsForReport.ToArray())
        ExpectedReturned = @($expectedReturned.ToArray())
        ExpectedMissing = @($expectedMissing.ToArray())
        AdditionalOfficial = @($additionalOfficial.ToArray())
    }
}

function Format-ExpectedItemsSummary {
    param([object]$ExpectedComparison)

    if ($null -eq $ExpectedComparison) {
        return $null
    }

    $expectedCount = @($ExpectedComparison.ExpectedItems).Count
    $expectedReturnedCount = @($ExpectedComparison.ExpectedReturned).Count
    $expectedMissingCount = @($ExpectedComparison.ExpectedMissing).Count
    $additionalOfficialCount = @($ExpectedComparison.AdditionalOfficial).Count

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add(
        "Comparativo da frente: $expectedCount esperados; $expectedReturnedCount voltaram; $expectedMissingCount nao voltaram; $additionalOfficialCount adicionais oficiais da KB."
    ) | Out-Null
    $lines.Add("A materializacao oficial seguiu normalmente. O comparativo e complementar.") | Out-Null

    if ($additionalOfficialCount -gt 0) {
        $lines.Add("Itens adicionais podem representar retorno oficial adicional da KB ou mudanca paralela legitima.") | Out-Null
    }

    if ($expectedMissingCount -gt 0) {
        $lines.Add("Itens esperados ausentes devem ser investigados no contexto da frente, sem bloquear o sync.") | Out-Null
    }

    return ($lines -join [Environment]::NewLine)
}

function Convert-PackageToItems {
    param(
        [xml]$XmlDocument,
        [hashtable]$CatalogGuidToFolderMap
    )

    $items = New-Object System.Collections.Generic.List[object]

    $objectsNode = $XmlDocument.SelectSingleNode("/ExportFile/Objects")
    if ($null -ne $objectsNode) {
        foreach ($node in $objectsNode.SelectNodes("./Object")) {
            $typeGuid = $node.GetAttribute("type").ToLowerInvariant()
            if (-not $CatalogGuidToFolderMap.ContainsKey($typeGuid)) {
                continue
            }

            $logicalName = $node.GetAttribute("name")
            $folderType = $CatalogGuidToFolderMap[$typeGuid]
            $normalizedName = Normalize-FileBaseName -LogicalName $logicalName
            $items.Add([pscustomobject]@{
                PackageSection = "Objects"
                RootTag = "Object"
                FolderType = $folderType
                LogicalName = $logicalName
                NormalizedName = $normalizedName
                TypeGuid = $typeGuid
                Guid = $node.GetAttribute("guid")
                Node = $node
            }) | Out-Null
        }
    }

    $attributesNode = $XmlDocument.SelectSingleNode("/ExportFile/Attributes")
    if ($null -ne $attributesNode) {
        foreach ($node in $attributesNode.SelectNodes("./Attribute")) {
            $logicalName = $node.GetAttribute("name")
            $normalizedName = Normalize-FileBaseName -LogicalName $logicalName
            $items.Add([pscustomobject]@{
                PackageSection = "Attributes"
                RootTag = "Attribute"
                FolderType = "Attribute"
                LogicalName = $logicalName
                NormalizedName = $normalizedName
                TypeGuid = "attribute-top-level"
                Guid = $node.GetAttribute("guid")
                Node = $node
            }) | Out-Null
        }
    }

    $collisions = @(
        $items |
        Group-Object { "$($_.FolderType)|$($_.NormalizedName)" } |
        Where-Object {
            $_.Count -gt 1 -and
            @($_.Group | Select-Object -ExpandProperty LogicalName | Sort-Object -Unique).Count -gt 1
        }
    )

    if ($collisions.Count -gt 0) {
        $details = foreach ($collision in $collisions) {
            $names = $collision.Group | Select-Object -ExpandProperty LogicalName | Sort-Object -Unique
            "$($collision.Name) <= $($names -join ', ')"
        }
        throw "Filename normalization collision detected: $($details -join '; ')"
    }

    return ,($items.ToArray())
}

function Convert-NodeToXmlString {
    param(
        [System.Xml.XmlNode]$Node
    )

    $doc = New-Object System.Xml.XmlDocument
    $declaration = $doc.CreateXmlDeclaration("1.0", "utf-8", $null)
    [void]$doc.AppendChild($declaration)
    $imported = $doc.ImportNode($Node, $true)
    [void]$doc.AppendChild($imported)

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = (Get-Utf8NoBomEncoding)
    $settings.Indent = $true
    $settings.NewLineChars = "`r`n"
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
    $settings.OmitXmlDeclaration = $false

    $stream = New-Object System.IO.MemoryStream
    $writer = [System.Xml.XmlWriter]::Create($stream, $settings)
    $doc.Save($writer)
    $writer.Close()
    $bytes = $stream.ToArray()
    $stream.Dispose()
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-LastUpdateInfoFromXmlDocument {
    param(
        [xml]$XmlDocument,
        [string]$SourceLabel
    )

    $rootNode = $XmlDocument.DocumentElement
    if ($null -eq $rootNode) {
        throw "Missing root element while reading lastUpdate from $SourceLabel."
    }

    $rawValue = $rootNode.GetAttribute("lastUpdate")
    if ([string]::IsNullOrWhiteSpace($rawValue)) {
        throw "Missing lastUpdate on '$($rootNode.LocalName)' from $SourceLabel."
    }

    $parsedValue = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse($rawValue, [ref]$parsedValue)) {
        throw "Invalid lastUpdate '$rawValue' on '$($rootNode.LocalName)' from $SourceLabel."
    }

    return [pscustomobject]@{
        RootTag = $rootNode.LocalName
        RawValue = $rawValue
        ParsedValue = $parsedValue.ToUniversalTime()
    }
}

function Get-LastUpdateInfoFromNode {
    param([System.Xml.XmlNode]$Node)

    $ownerDocument = New-Object System.Xml.XmlDocument
    $importedNode = $ownerDocument.ImportNode($Node, $true)
    [void]$ownerDocument.AppendChild($importedNode)
    return Get-LastUpdateInfoFromXmlDocument -XmlDocument $ownerDocument -SourceLabel "package item '$($Node.Attributes['name'].Value)'"
}

function Get-LastUpdateInfoFromFile {
    param([string]$FilePath)

    [xml]$xmlDocument = Get-Content -LiteralPath $FilePath -Raw
    return Get-LastUpdateInfoFromXmlDocument -XmlDocument $xmlDocument -SourceLabel $FilePath
}

function Resolve-ItemDestinationPath {
    # SO compoe o caminho de destino do item (FolderType/NormalizedName.xml); NAO cria diretorio
    # nem faz I/O. Fonte unica reusada por Write-ItemToDestination e
    # Get-GeneXusCrossFlowDataSourceCollisions (evita drift na regra de path).
    param(
        [string]$Root,
        [string]$FolderType,
        [string]$NormalizedName
    )
    return Join-Path (Join-Path $Root $FolderType) ($NormalizedName + ".xml")
}

function Write-ItemToDestination {
    param(
        [object]$Item,
        [string]$Root,
        [bool]$CrossFlowCollision = $false
    )

    $folderPath = Join-Path $Root $Item.FolderType
    if (-not (Test-Path -LiteralPath $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath | Out-Null
    }

    $filePath = Resolve-ItemDestinationPath -Root $Root -FolderType $Item.FolderType -NormalizedName $Item.NormalizedName
    $xmlText = Convert-NodeToXmlString -Node $Item.Node
    $incomingLastUpdate = Get-LastUpdateInfoFromNode -Node $Item.Node
    $status = "created"
    $existingLastUpdate = $null

    if (Test-Path -LiteralPath $filePath) {
        $existing = Get-Content -LiteralPath $filePath -Raw
        if ($existing -eq $xmlText) {
            $status = "unchanged"
        } else {
            $existingLastUpdate = Get-LastUpdateInfoFromFile -FilePath $filePath
            if ($incomingLastUpdate.ParsedValue -lt $existingLastUpdate.ParsedValue) {
                $status = "skipped-older-lastUpdate"
            } else {
                $status = "updated"
            }
        }
    }

    if ($status -eq "created" -or $status -eq "updated") {
        [System.IO.File]::WriteAllText($filePath, $xmlText, (Get-Utf8NoBomEncoding))
    }

    return [pscustomobject]@{
        FolderType = $Item.FolderType
        LogicalName = $Item.LogicalName
        FilePath = $filePath
        Status = $status
        WasNormalized = ($Item.LogicalName -ne $Item.NormalizedName)
        IncomingLastUpdate = $incomingLastUpdate.RawValue
        ExistingLastUpdate = if ($null -ne $existingLastUpdate) { $existingLastUpdate.RawValue } else { $null }
        CrossFlowCollision = [bool]$CrossFlowCollision
    }
}

function Get-GeneXusCrossFlowDataSourceCollisions {
    <#
        Deteccao de DIVERGENCIA DE ORIGEM (dataSource) cross-fluxo no acervo (caso central
        moderno<->legado GeneXus 9). Compara o dataSource do no incoming com o do arquivo JA
        materializado no destino. A FUNCAO NUNCA lanca; retorna { Collisions, Warnings } e o
        chamador decide bloquear (Decisao K) ou seguir (fail-soft). Roda pre-rename, antes da
        metadata. Ver doc-dono 01k e xpz-sync/SKILL.md.
    #>
    param(
        [object[]]$Items,
        [string]$Root
    )

    $collisions = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[string]

    foreach ($item in $Items) {
        $filePath = Resolve-ItemDestinationPath -Root $Root -FolderType $item.FolderType -NormalizedName $item.NormalizedName
        if (-not (Test-Path -LiteralPath $filePath)) { continue }  # inexistente => sem colisao (sem parse)

        # Incoming: o no ja esta em $item.Node (XmlElement em ambos os ramos); ausencia => "".
        $incomingDataSource = [string]$item.Node.GetAttribute('dataSource')

        # Existente: parse encoding-aware (XmlDocument.Load, como a pre-leitura do pacote), NAO o
        # [xml]Get-Content -Raw de Get-LogicalNameFromExtractedFile. Parse-falho => warning fail-safe.
        $existingDataSource = $null
        try {
            $existingDoc = New-Object System.Xml.XmlDocument
            $existingDoc.PreserveWhitespace = $true
            $existingDoc.Load($filePath)
            $existingRoot = $existingDoc.DocumentElement
            if ($null -eq $existingRoot) { throw "sem no raiz" }
            $existingDataSource = [string]$existingRoot.GetAttribute('dataSource')
            # Decisao E.2: atributo presente vence; so na AUSENCIA consulta o sinal secundario
            # <GxLegacyPayload> (filho direto, exclusivo do legado; LocalName tolerante a namespace).
            if ([string]::IsNullOrEmpty($existingDataSource)) {
                foreach ($child in $existingRoot.ChildNodes) {
                    if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element -and $child.LocalName -eq 'GxLegacyPayload') {
                        $existingDataSource = 'gx-legacy-export'
                        break
                    }
                }
            }
        } catch {
            # parse-falho: nao produz ExistingDataSource confiavel => sem colisao, sem bloqueio.
            $w = (@{ FilePath = $filePath; ExceptionType = $_.Exception.GetType().Name } | ConvertTo-Json -Compress)
            [Console]::Error.WriteLine("CROSSFLOW_WARNING: $w")
            $warnings.Add("dataSource indeterminavel em '$filePath' (parse falhou: $($_.Exception.GetType().Name)); item tratado sem colisao cross-fluxo.") | Out-Null
            continue
        }

        # COLISAO quando os dataSource DIVERGEM (Decisao E: comparacao ordinal, sem normalizacao).
        if (-not [string]::Equals($incomingDataSource, $existingDataSource, [System.StringComparison]::Ordinal)) {
            $collision = [pscustomobject]@{
                FolderType = $item.FolderType
                NormalizedName = $item.NormalizedName
                LogicalName = $item.LogicalName
                ExistingDataSource = $existingDataSource
                IncomingDataSource = $incomingDataSource
                FilePath = $filePath
            }
            $collisions.Add($collision) | Out-Null
            # Mitigacao stderr UNIVERSAL (JSONL): emitida sempre no ponto da deteccao, para a colisao
            # nunca se perder mesmo nos caminhos que abortam antes do Summary do stdout.
            $line = ($collision | ConvertTo-Json -Compress)
            [Console]::Error.WriteLine("CROSSFLOW_COLLISION: $line")
        }
    }

    return [pscustomobject]@{
        Collisions = $collisions.ToArray()
        Warnings = $warnings.ToArray()
    }
}

function Invoke-GeneXusCrossFlowDetection {
    # Orquestra a deteccao no fluxo do sync: roda Get-GeneXusCrossFlowDataSourceCollisions, agrega
    # os warnings em $Warnings e, sob -Block + colisao, EMITE o terminating error (Decisao K) apos
    # sinalizar o ErrorId por stderr (para o processo filho do self-test confirmar sem dot-source).
    # Retorna o array de colisoes (vazio quando nao ha) para o Summary/Writes[]. Pre-metadata.
    param(
        [object[]]$Items,
        [string]$Root,
        [object]$Warnings,
        [switch]$Block
    )
    $result = Get-GeneXusCrossFlowDataSourceCollisions -Items $Items -Root $Root
    foreach ($w in $result.Warnings) {
        if (-not [string]::IsNullOrWhiteSpace($w)) { $Warnings.Add($w) | Out-Null }
    }
    $collisions = @($result.Collisions)
    if ($Block -and $collisions.Count -gt 0) {
        [Console]::Error.WriteLine("CROSSFLOW_BLOCKED_ERRORID: CrossFlowDataSourceCollisionBlocked")
        Write-Error -Message ("BLOCK: colisao cross-fluxo de dataSource detectada ({0} item(ns)); -BlockCrossFlowDataSource ativo. Nenhuma metadata nem XML foi gravado." -f $collisions.Count) -ErrorId 'CrossFlowDataSourceCollisionBlocked' -Category InvalidOperation -ErrorAction Stop
    }
    return ,$collisions
}

function Get-LogicalNameFromExtractedFile {
    param([string]$FilePath)

    [xml]$xmlDoc = Get-Content -LiteralPath $FilePath -Raw
    $rootNode = $xmlDoc.DocumentElement
    return [pscustomobject]@{
        RootTag = $rootNode.LocalName
        LogicalName = $rootNode.GetAttribute("name")
        Guid = $rootNode.GetAttribute("guid")
    }
}

function Test-PackageMaterialization {
    param(
        [object[]]$Items,
        [string]$Root
    )

    $missing = New-Object System.Collections.Generic.List[object]
    $mismatch = New-Object System.Collections.Generic.List[object]

    foreach ($item in $Items) {
        $filePath = Join-Path (Join-Path $Root $item.FolderType) ($item.NormalizedName + ".xml")
        if (-not (Test-Path -LiteralPath $filePath)) {
            $missing.Add([pscustomobject]@{
                FolderType = $item.FolderType
                LogicalName = $item.LogicalName
                ExpectedPath = $filePath
            }) | Out-Null
            continue
        }

        $details = Get-LogicalNameFromExtractedFile -FilePath $filePath
        if ($details.RootTag -ne $item.RootTag -or $details.LogicalName -ne $item.LogicalName) {
            $mismatch.Add([pscustomobject]@{
                FolderType = $item.FolderType
                ExpectedName = $item.LogicalName
                ActualName = $details.LogicalName
                ExpectedRootTag = $item.RootTag
                ActualRootTag = $details.RootTag
                FilePath = $filePath
            }) | Out-Null
        }
    }

    return [pscustomobject]@{
        Missing = $missing
        Mismatch = $mismatch
    }
}

function Get-OfficialXmlCount {
    param(
        [string]$Root
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return 0
    }

    return @(Get-ChildItem -Path $Root -Recurse -File -Filter *.xml).Count
}

function Get-FullSnapshotComparison {
    param(
        [object[]]$Items,
        [string]$Root
    )

    $packageKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Items) {
        [void]$packageKeys.Add("$($item.FolderType)|$($item.LogicalName)")
    }

    $localKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $xmlFiles = Get-ChildItem -LiteralPath $Root -Recurse -Filter *.xml -File
    foreach ($file in $xmlFiles) {
        $folderType = $file.Directory.Name
        $details = Get-LogicalNameFromExtractedFile -FilePath $file.FullName
        [void]$localKeys.Add("$folderType|$($details.LogicalName)")
    }

    $missing = foreach ($key in $packageKeys) {
        if (-not $localKeys.Contains($key)) { $key }
    }

    $extra = foreach ($key in $localKeys) {
        if (-not $packageKeys.Contains($key)) { $key }
    }

    return [pscustomobject]@{
        MissingKeys = @($missing | Sort-Object)
        ExtraKeys = @($extra | Sort-Object)
    }
}

function Test-IsMeaningfulGuid {
    param([string]$Guid)

    if ([string]::IsNullOrWhiteSpace($Guid)) { return $false }
    if ($Guid.Trim().ToLowerInvariant() -eq "00000000-0000-0000-0000-000000000000") { return $false }
    return $true
}

function Resolve-GuidAwareRenames {
    <#
        Reconcilia o acervo com o pacote pela identidade estavel (GUID do no raiz),
        nao pelo nome logico. Quando o mesmo GUID aparece no acervo sob um nome de
        arquivo diferente do alvo do pacote, trata como rename: renomeia o arquivo
        existente no disco (Move-Item antigo -> novo) em vez de criar-novo +
        abandonar-antigo. Assim o resultado e um arquivo so e o git detecta rename.

        -Apply $true  : executa o rename/limpeza no disco (modo materializacao).
        -Apply $false : apenas detecta e classifica (modo -VerifyOnly), sem tocar disco.

        Escopo: casa GUID dentro do MESMO FolderType. GUID que casa em FolderType
        diferente (troca de tipo) fica fora de escopo e segue o caminho atual.
    #>
    param(
        [object[]]$Items,
        [string]$Root,
        [System.Collections.Generic.List[string]]$Warnings,
        [bool]$Apply
    )

    $renames = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return ,($renames.ToArray())
    }

    $acervoByGuid = @{}
    $xmlFiles = Get-ChildItem -LiteralPath $Root -Recurse -Filter *.xml -File
    foreach ($file in $xmlFiles) {
        $details = Get-LogicalNameFromExtractedFile -FilePath $file.FullName
        if (-not (Test-IsMeaningfulGuid -Guid $details.Guid)) { continue }
        $guidKey = $details.Guid.Trim().ToLowerInvariant()
        $info = [pscustomobject]@{
            FilePath = $file.FullName
            FolderType = $file.Directory.Name
            LogicalName = $details.LogicalName
            FileBaseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        }
        if (-not $acervoByGuid.ContainsKey($guidKey)) {
            $acervoByGuid[$guidKey] = New-Object System.Collections.Generic.List[object]
        }
        $acervoByGuid[$guidKey].Add($info)
    }

    foreach ($item in $Items) {
        if (-not (Test-IsMeaningfulGuid -Guid $item.Guid)) { continue }
        $guidKey = $item.Guid.Trim().ToLowerInvariant()
        if (-not $acervoByGuid.ContainsKey($guidKey)) { continue }

        $sameFolderMatches = @($acervoByGuid[$guidKey] | Where-Object { $_.FolderType -eq $item.FolderType })
        if ($sameFolderMatches.Count -eq 0) { continue }
        $folderPath = Join-Path $Root $item.FolderType
        $newPath = Join-Path $folderPath ($item.NormalizedName + ".xml")
        if ($sameFolderMatches.Count -gt 1) {
            $targetMatches = @($sameFolderMatches | Where-Object { $_.FileBaseName -ceq $item.NormalizedName })
            $oldMatches = @($sameFolderMatches | Where-Object { $_.FileBaseName -cne $item.NormalizedName })
            if ($targetMatches.Count -eq 1 -and $oldMatches.Count -eq 1) {
                $existing = $oldMatches[0]
            } else {
                $Warnings.Add("GUID duplicado no acervo ($guidKey) em $($item.FolderType); rename por GUID ignorado para '$($item.LogicalName)'.") | Out-Null
                continue
            }
        } else {
            $existing = $sameFolderMatches[0]
        }

        if ($existing.FileBaseName -ceq $item.NormalizedName) { continue }

        $oldPath = $existing.FilePath
        $isCaseOnlyRename = ($existing.FileBaseName -ieq $item.NormalizedName)
        $action = "detected"

        if ($Apply) {
            if ($isCaseOnlyRename) {
                # No NTFS, nomes que diferem so na caixa apontam para o mesmo
                # arquivo; renomear via etapa intermediaria efetiva a troca de caixa.
                $tempPath = Join-Path $folderPath ($item.NormalizedName + ".gxcasetmp")
                Move-Item -LiteralPath $oldPath -Destination $tempPath
                Move-Item -LiteralPath $tempPath -Destination $newPath
                $action = "renamed"
            } elseif (Test-Path -LiteralPath $newPath) {
                $newPathGuidRaw = (Get-LogicalNameFromExtractedFile -FilePath $newPath).Guid
                if (Test-IsMeaningfulGuid -Guid $newPathGuidRaw) {
                    $newPathGuid = $newPathGuidRaw.Trim().ToLowerInvariant()
                } else {
                    $newPathGuid = ""
                }
                if ($newPathGuid -eq $guidKey) {
                    # Orfao real: o alvo ja e o MESMO objeto (mesmo GUID), resquicio
                    # de materializacao anterior; remover o arquivo de nome antigo.
                    Remove-Item -LiteralPath $oldPath -Force
                    $action = "orphan-removed"
                } else {
                    # Colisao: o alvo pertence a outro objeto (GUID diferente).
                    # Fail-closed antes do laco de escrita sobrescrever o existente.
                    throw "Colisao de nome no acervo: '$($item.NormalizedName).xml' em '$($item.FolderType)' ja existe com GUID diferente ('$newPathGuid') do item renomeado (GUID '$guidKey', '$($existing.FileBaseName)' -> '$($item.NormalizedName)'). Rename por GUID abortado para preservar o arquivo existente."
                }
            } else {
                Move-Item -LiteralPath $oldPath -Destination $newPath
                $action = "renamed"
            }
        }

        $renames.Add([pscustomobject]@{
            Guid = $guidKey
            FolderType = $item.FolderType
            OldName = $existing.LogicalName
            OldFileBaseName = $existing.FileBaseName
            NewName = $item.LogicalName
            NewFileBaseName = $item.NormalizedName
            Action = $action
        }) | Out-Null
    }

    return ,($renames.ToArray())
}

function Write-Report {
    param(
        [string]$Path,
        [object]$Payload
    )

    $json = $Payload | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, (Get-Utf8NoBomEncoding))
}

$package = $null
$metadataResult = $null
$warnings = New-Object System.Collections.Generic.List[string]
try {
    $package = Resolve-PackageXmlPath -RawInputPath $InputPath
    # Leitura encoding-aware: XmlDocument.Load respeita o atributo encoding do prologo. Export
    # legado GeneXus 9 e iso-8859-1; Get-Content -Raw assumiria UTF-8 e corromperia acentos
    # Latin-1. Vale para moderno (UTF-8) e legado (iso-8859-1) por igual.
    $packageXml = New-Object System.Xml.XmlDocument
    $packageXml.PreserveWhitespace = $true
    $packageXml.Load($package.XmlPath)

    if ($null -eq $packageXml.DocumentElement -or $packageXml.DocumentElement.LocalName -ne "ExportFile") {
        $foundRoot = if ($null -eq $packageXml.DocumentElement) { '<null>' } else { $packageXml.DocumentElement.LocalName }
        throw "Expected root element 'ExportFile', found '$foundRoot'."
    }

    # Classificacao de perfil ANTES de qualquer gravacao de metadata. Pacote MISTO (elementos
    # legados <GXObject> e modernos <Objects>/<Attributes> no mesmo ExportFile) e fail-closed
    # SEM tocar kb-source-metadata.md (spec congelada Fase 2 v2.8.5, secao 4.1, ramo 5).
    $LegacyFormatDetected = $false
    $crossFlowCollisions = @()
    if (Test-GeneXusMixedExportFilePackage -XmlDocument $packageXml) {
        throw "BLOCK: pacote de export MISTO (elementos legados <GXObject> e modernos <Objects>/<Attributes> no mesmo ExportFile); fora de escopo do motor de export legado. Exporte os formatos separadamente. Nenhum metadata foi gravado."
    }

    if (Test-GeneXusLegacyExportFilePackage -XmlDocument $packageXml) {
        # ===== RAMO LEGADO (export GeneXus 9) =====
        # Ordem (v2.8.5 secao 4.1): resolver catalogo -> construir/validar itens (fail-closed
        # de tag fora do registro / >1 elemento-filho / colisao AQUI, antes da metadata) ->
        # metadata (-IsLegacyExport) -> materializacao/rename/verificacao compartilhados.
        $LegacyFormatDetected = $true
        $catalogResolution = Resolve-GeneXusObjectTypeCatalogPaths -BaseCatalogPath $CatalogPath -CatalogOverridePath $CatalogOverridePath -ParallelKbRoot $ParallelKbRoot
        $legacyRegistry = Get-GeneXusLegacyExportElementRegistry
        $legacySyncResult = Get-GeneXusLegacyExportFileSyncItems -XmlDocument $packageXml -MergedCatalog $catalogResolution.MergedCatalog -Registry $legacyRegistry
        $items = @($legacySyncResult.Items)

        # Deteccao cross-fluxo: pos-$items, ANTES da metadata e do rename (snapshot pre-rename).
        $crossFlowCollisions = Invoke-GeneXusCrossFlowDetection -Items $items -Root $DestinationRoot -Warnings $warnings -Block:$BlockCrossFlowDataSource

        if ($KbMetadataPath) {
            # GRAVACAO DE METADATA (legado): pos-catalogo/itens. Mutuamente exclusiva com a
            # gravacao do ramo moderno abaixo (apos a classificacao de perfil) — nunca ambas
            # numa mesma execucao, pois os ramos legado/moderno sao disjuntos por perfil [R6-b].
            $metadataResult = Update-XpzKbSourceMetadataFromSync -XmlDocument $packageXml -SourceXpzPath $InputPath -MetadataPath $KbMetadataPath -IsLegacyExport $true
            [Console]::Error.WriteLine("KbMetadataPath atualizado: $KbMetadataPath ($($metadataResult.WriteMode))")
            if ($metadataResult.Warnings.Count -gt 0) {
                [Console]::Error.WriteLine("AVISO: " + $metadataResult.Warnings[0])
            }
            foreach ($warning in $metadataResult.Warnings) {
                if (-not [string]::IsNullOrWhiteSpace($warning)) {
                    $warnings.Add($warning) | Out-Null
                }
            }
        }
    }
    else {
        # ===== RAMO MODERNO =====
        # REORDENADO (frente cross-fluxo): catalogo -> unknown-throw -> Convert($items) ->
        # DETECCAO cross-fluxo -> metadata. Antes a metadata era gravada ANTES de $items existir;
        # agora os fail-closed de tipo desconhecido e de colisao intra-pacote (Convert-PackageToItems)
        # passam a disparar ANTES da gravacao de kb-source-metadata.md (mudanca de comportamento
        # intencional; ver CHANGELOG/xpz-sync). Update-XpzKbSourceMetadataFromSync nao recebe $items,
        # entao mover $items para antes dela e seguro.
        $catalogResolution = Resolve-GeneXusObjectTypeCatalogPaths -BaseCatalogPath $CatalogPath -CatalogOverridePath $CatalogOverridePath -ParallelKbRoot $ParallelKbRoot
        $catalogGuidMap = Get-GeneXusCatalogGuidToFolderMap -MergedCatalog $catalogResolution.MergedCatalog
        $unknownTypes = @(Get-GeneXusUnknownObjectTypesFromExportFile -XmlDocument $packageXml -GuidToFolderMap $catalogGuidMap)
        if ($unknownTypes.Count -gt 0) {
            if ($DiscoveryReportPath) {
                Write-GeneXusUnknownTypeDiscoveryReport -Path $DiscoveryReportPath -UnknownTypes $unknownTypes -CatalogResolution $catalogResolution -InputPath $InputPath
            }
            $errorMessage = Format-GeneXusUnknownObjectTypesErrorMessage -UnknownTypes $unknownTypes -OverrideActive $catalogResolution.OverrideActive
            throw $errorMessage
        }

        $items = Convert-PackageToItems -XmlDocument $packageXml -CatalogGuidToFolderMap $catalogGuidMap

        # Deteccao cross-fluxo: pos-$items, ANTES da metadata e do rename (snapshot pre-rename).
        $crossFlowCollisions = Invoke-GeneXusCrossFlowDetection -Items $items -Root $DestinationRoot -Warnings $warnings -Block:$BlockCrossFlowDataSource

        if ($KbMetadataPath) {
            # GRAVACAO DE METADATA (moderno): agora pos-catalogo/unknown/Convert/deteccao.
            # Mutuamente exclusiva com a gravacao do ramo legado acima [R6-b].
            $metadataResult = Update-XpzKbSourceMetadataFromSync -XmlDocument $packageXml -SourceXpzPath $InputPath -MetadataPath $KbMetadataPath
            [Console]::Error.WriteLine("KbMetadataPath atualizado: $KbMetadataPath ($($metadataResult.WriteMode))")
            if ($metadataResult.Warnings.Count -gt 0) {
                # stderr (nao Write-Warning): o stream de warning tambem vaza para o stdout
                # capturado de um processo filho, contaminando o contrato JSON.
                [Console]::Error.WriteLine("AVISO: " + $metadataResult.Warnings[0])
            }
            foreach ($warning in $metadataResult.Warnings) {
                if (-not [string]::IsNullOrWhiteSpace($warning)) {
                    $warnings.Add($warning) | Out-Null
                }
            }
        }
    }

    $expectedComparison = Convert-ExpectedItemsToComparison -ExpectedItems $ExpectedItems -ActualItems $items

    $objectsBlockCount = @($items | Where-Object { $_.PackageSection -eq "Objects" }).Count
    $attributesBlockCount = @($items | Where-Object { $_.PackageSection -eq "Attributes" }).Count
    $preExistingOfficialXmlCount = Get-OfficialXmlCount -Root $DestinationRoot

    $renameResults = @()
    if ($FullSnapshot) {
        $renameResults = Resolve-GuidAwareRenames -Items $items -Root $DestinationRoot -Warnings $warnings -Apply (-not [bool]$VerifyOnly)
    }

    # Chaves FolderType|NormalizedName das colisoes cross-fluxo (pre-rename); coincidem com o
    # destino final do par cross-fluxo (Decisao I), entao indexam o booleano por-item do Writes[].
    $crossFlowKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($c in $crossFlowCollisions) {
        [void]$crossFlowKeys.Add("$($c.FolderType)|$($c.NormalizedName)")
    }

    $writeResults = @()
    if (-not $VerifyOnly) {
        foreach ($item in $items) {
            $itemCrossFlow = $crossFlowKeys.Contains("$($item.FolderType)|$($item.NormalizedName)")
            $writeResults += Write-ItemToDestination -Item $item -Root $DestinationRoot -CrossFlowCollision $itemCrossFlow
        }
    }

    $verification = Test-PackageMaterialization -Items $items -Root $DestinationRoot
    $fullSnapshotResult = $null
    if ($FullSnapshot) {
        $fullSnapshotResult = Get-FullSnapshotComparison -Items $items -Root $DestinationRoot
    }

    $createdCount = @($writeResults | Where-Object { $_.Status -eq "created" }).Count
    $updatedCount = @($writeResults | Where-Object { $_.Status -eq "updated" }).Count
    $unchangedCount = @($writeResults | Where-Object { $_.Status -eq "unchanged" }).Count
    $skippedOlderLastUpdateCount = @($writeResults | Where-Object { $_.Status -eq "skipped-older-lastUpdate" }).Count
    $normalizedFileNamesCount = @($writeResults | Where-Object { $_.WasNormalized }).Count

    # Listas nominais (dado de maquina): "Tipo:Nome" por status, ordenadas e estaveis.
    # Construidas como array e expostas como propriedade de pscustomobject: ConvertTo-Json
    # serializa array vazio como [] e array unitario como ["x"] (nao colapsa nem vira null).
    $createdNames = @($writeResults | Where-Object { $_.Status -eq "created" } | ForEach-Object { "$($_.FolderType):$($_.LogicalName)" } | Sort-Object)
    $updatedNames = @($writeResults | Where-Object { $_.Status -eq "updated" } | ForEach-Object { "$($_.FolderType):$($_.LogicalName)" } | Sort-Object)
    $unchangedNames = @($writeResults | Where-Object { $_.Status -eq "unchanged" } | ForEach-Object { "$($_.FolderType):$($_.LogicalName)" } | Sort-Object)
    $skippedOlderLastUpdateNames = @($writeResults | Where-Object { $_.Status -eq "skipped-older-lastUpdate" } | ForEach-Object { "$($_.FolderType):$($_.LogicalName)" } | Sort-Object)
    $renamedByGuidItems = @($renameResults |
        Where-Object { $_.Action -eq "renamed" -or $_.Action -eq "orphan-removed" } |
        Sort-Object FolderType, NewName |
        ForEach-Object { [pscustomobject]@{ Guid = $_.Guid; FolderType = $_.FolderType; OldName = $_.OldName; NewName = $_.NewName; Action = $_.Action } })

    # ExpectedComparison achatado em listas nominais (a fonte das tres partes do handoff
    # da skill xpz-sync). null quando -ExpectedItems nao foi informado, para distinguir
    # "nao pedido" de "pedido, porem vazio".
    if ($null -ne $expectedComparison) {
        $expectedReturnedNames = @($expectedComparison.ExpectedReturned | ForEach-Object { "$($_.FolderType):$($_.LogicalName)" } | Sort-Object)
        $expectedMissingNames = @($expectedComparison.ExpectedMissing | ForEach-Object { "$($_.FolderType):$($_.LogicalName)" } | Sort-Object)
        $additionalOfficialNames = @($expectedComparison.AdditionalOfficial | ForEach-Object { "$($_.FolderType):$($_.LogicalName)" } | Sort-Object)
    } else {
        $expectedReturnedNames = $null
        $expectedMissingNames = $null
        $additionalOfficialNames = $null
    }

    $materializationInterpretation = if ($LegacyFormatDetected) {
        "legacy-export-adapted"
    } elseif ($VerifyOnly) {
        "verify-only"
    } elseif ($items.Count -eq 0) {
        "no-exportable-items"
    } elseif ($preExistingOfficialXmlCount -eq 0 -and $createdCount -gt 0) {
        "first-materialization"
    } elseif ($preExistingOfficialXmlCount -gt 0 -and ($createdCount -gt 0 -or $updatedCount -gt 0)) {
        "existing-snapshot-updated"
    } elseif ($preExistingOfficialXmlCount -gt 0 -and $createdCount -eq 0 -and $updatedCount -eq 0 -and $unchangedCount -gt 0) {
        "existing-snapshot-confirmed-unchanged"
    } else {
        "materialization-result-requires-context"
    }

    $summary = [pscustomobject]@{
        SchemaVersion = 1
        Kind = "xpz-sync-result"
        InputPath = (Resolve-Path -LiteralPath $InputPath).Path
        PackageXmlPath = $package.XmlPath
        VerifyOnly = [bool]$VerifyOnly
        FullSnapshot = [bool]$FullSnapshot
        LegacyFormatDetected = [bool]$LegacyFormatDetected
        ObjectsBlockCount = $objectsBlockCount
        AttributesBlockCount = $attributesBlockCount
        TotalExportedItems = $items.Count
        PackageHasExportedItems = ($items.Count -gt 0)
        PackageInterpretation = if ($LegacyFormatDetected) { "legacy-export-adapted" } elseif ($items.Count -gt 0) { "exported-items-found" } else { "no-exportable-items" }
        PreExistingOfficialXmlCount = $preExistingOfficialXmlCount
        MaterializationInterpretation = $materializationInterpretation
        Created = $createdCount
        Updated = $updatedCount
        Unchanged = $unchangedCount
        SkippedOlderLastUpdate = $skippedOlderLastUpdateCount
        NormalizedFileNames = $normalizedFileNamesCount
        RenamedByGuid = @($renameResults | Where-Object { $_.Action -eq "renamed" -or $_.Action -eq "orphan-removed" }).Count
        RenameResidualsDetected = @($renameResults | Where-Object { $_.Action -eq "detected" }).Count
        MissingAfterVerification = $verification.Missing.Count
        MismatchesAfterVerification = $verification.Mismatch.Count
        FullSnapshotMissing = if ($null -ne $fullSnapshotResult) { $fullSnapshotResult.MissingKeys.Count } else { $null }
        FullSnapshotExtra = if ($null -ne $fullSnapshotResult) { $fullSnapshotResult.ExtraKeys.Count } else { $null }
        ExpectedItemsProvided = ($null -ne $expectedComparison)
        ExpectedItemsCount = if ($null -ne $expectedComparison) { $expectedComparison.ExpectedItems.Count } else { 0 }
        ExpectedReturnedCount = if ($null -ne $expectedComparison) { $expectedComparison.ExpectedReturned.Count } else { $null }
        ExpectedMissingCount = if ($null -ne $expectedComparison) { $expectedComparison.ExpectedMissing.Count } else { $null }
        AdditionalOfficialCount = if ($null -ne $expectedComparison) { $expectedComparison.AdditionalOfficial.Count } else { $null }
        CreatedNames = $createdNames
        UpdatedNames = $updatedNames
        UnchangedNames = $unchangedNames
        SkippedOlderLastUpdateNames = $skippedOlderLastUpdateNames
        RenamedByGuidItems = $renamedByGuidItems
        ExpectedReturnedNames = $expectedReturnedNames
        ExpectedMissingNames = $expectedMissingNames
        AdditionalOfficialNames = $additionalOfficialNames
        CrossFlowCollisions = @($crossFlowCollisions)
    }

    $overrideReminder = $null
    if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) {
        $overrideReminder = Get-GeneXusCatalogOverrideSessionReminder -ParallelKbRoot $ParallelKbRoot -CatalogOverridePath $CatalogOverridePath
        if ($overrideReminder.reminderRequired -and -not [string]::IsNullOrWhiteSpace($overrideReminder.message)) {
            $warnings.Add($overrideReminder.message) | Out-Null
        }
    }

    $report = [pscustomobject]@{
        Summary = $summary
        Missing = $verification.Missing
        Mismatch = $verification.Mismatch
        FullSnapshot = $fullSnapshotResult
        ExpectedComparison = $expectedComparison
        Renames = $renameResults
        Writes = $writeResults
        Warnings = @($warnings)
        KbMetadataStatus = if ($null -ne $metadataResult) { $metadataResult.MetadataStatus } else { "not-requested" }
        KbMetadataSourceComplete = if ($null -ne $metadataResult) { [bool]$metadataResult.SourceComplete } else { $null }
        CatalogOverrideActive = $catalogResolution.OverrideActive
        CatalogOverridePath = $catalogResolution.OverridePath
        CatalogUpstreamPending = $catalogResolution.UpstreamPending
        CatalogOverrideReminder = $overrideReminder
    }

    if ($ReportPath) {
        Write-Report -Path $ReportPath -Payload $report
    }

    # Warnings tambem no objeto de stdout (alem de $report.Warnings), para o agente que
    # so le o stdout. Add-Member apos o bloco de override reminder para captura-las todas.
    $summary | Add-Member -NotePropertyName Warnings -NotePropertyValue @($warnings) -Force

    # CONTRATO DE STDOUT: exclusivamente o JSON de maquina do resumo (-Compress = uma linha,
    # robusto na fronteira de processo). Todo texto humano vai para o STDERR, nunca para o
    # stdout: Write-Host vaza para o stdout capturado de um processo filho (pwsh -File),
    # contaminando o JSON. Ver xpz-sync/SKILL.md (contrato de saida).
    $summary | ConvertTo-Json -Depth 8 -Compress | Write-Output

    $humanSummary = $summary |
        Select-Object -Property * -ExcludeProperty CreatedNames, UpdatedNames, UnchangedNames, SkippedOlderLastUpdateNames, RenamedByGuidItems, ExpectedReturnedNames, ExpectedMissingNames, AdditionalOfficialNames, Warnings |
        Format-List | Out-String
    [Console]::Error.WriteLine($humanSummary)

    $expectedSummary = Format-ExpectedItemsSummary -ExpectedComparison $expectedComparison
    if (-not [string]::IsNullOrWhiteSpace($expectedSummary)) {
        [Console]::Error.WriteLine("")
        [Console]::Error.WriteLine($expectedSummary)
    }

    if ($verification.Missing.Count -gt 0 -or $verification.Mismatch.Count -gt 0) {
        throw "Verification failed after materialization. Missing=$($verification.Missing.Count), Mismatch=$($verification.Mismatch.Count)."
    }

    if ($null -ne $fullSnapshotResult -and ($fullSnapshotResult.MissingKeys.Count -gt 0 -or $fullSnapshotResult.ExtraKeys.Count -gt 0)) {
        throw "Full snapshot verification failed. Missing=$($fullSnapshotResult.MissingKeys.Count), Extra=$($fullSnapshotResult.ExtraKeys.Count)."
    }

    if ($ReportPath -and -not $KeepReport -and (Test-Path -LiteralPath $ReportPath)) {
        Remove-Item -LiteralPath $ReportPath -Force
    }
} finally {
    if ($null -ne $package -and $null -ne $package.TempPath -and (Test-Path -LiteralPath $package.TempPath)) {
        Remove-Item -LiteralPath $package.TempPath -Recurse -Force
    }
}
