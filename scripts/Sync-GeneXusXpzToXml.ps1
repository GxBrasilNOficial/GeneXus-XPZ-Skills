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

    [string]$DiscoveryReportPath = ""
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

function Normalize-FileBaseName {
    param([string]$LogicalName)

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $builder = New-Object System.Text.StringBuilder

    foreach ($char in $LogicalName.ToCharArray()) {
        if ($invalidChars -contains $char) {
            [void]$builder.Append('_')
        } else {
            [void]$builder.Append($char)
        }
    }

    return $builder.ToString().TrimEnd('.')
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

function Write-ItemToDestination {
    param(
        [object]$Item,
        [string]$Root
    )

    $folderPath = Join-Path $Root $Item.FolderType
    if (-not (Test-Path -LiteralPath $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath | Out-Null
    }

    $filePath = Join-Path $folderPath ($Item.NormalizedName + ".xml")
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
    }
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
    [xml]$packageXml = Get-Content -LiteralPath $package.XmlPath -Raw

    if ($packageXml.DocumentElement.LocalName -ne "ExportFile") {
        throw "Expected root element 'ExportFile', found '$($packageXml.DocumentElement.LocalName)'."
    }

    if ($KbMetadataPath) {
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

    $catalogResolution = Resolve-GeneXusObjectTypeCatalogPaths -BaseCatalogPath $CatalogPath -CatalogOverridePath $CatalogOverridePath -ParallelKbRoot $ParallelKbRoot
    $catalogGuidMap = Get-GeneXusCatalogGuidToFolderMap -MergedCatalog $catalogResolution.MergedCatalog
    $legacyFormatDetected = Test-GeneXusLegacyExportFilePackage -XmlDocument $packageXml
    if (-not $legacyFormatDetected) {
        $unknownTypes = @(Get-GeneXusUnknownObjectTypesFromExportFile -XmlDocument $packageXml -GuidToFolderMap $catalogGuidMap)
        if ($unknownTypes.Count -gt 0) {
            if ($DiscoveryReportPath) {
                Write-GeneXusUnknownTypeDiscoveryReport -Path $DiscoveryReportPath -UnknownTypes $unknownTypes -CatalogResolution $catalogResolution -InputPath $InputPath
            }
            $errorMessage = Format-GeneXusUnknownObjectTypesErrorMessage -UnknownTypes $unknownTypes -OverrideActive $catalogResolution.OverrideActive
            throw $errorMessage
        }
    }

    $legacyUnmappedElements = @()
    if ($legacyFormatDetected) {
        $legacyResult = Get-GeneXusLegacyExportFileSyncItems `
            -XmlDocument $packageXml `
            -MergedCatalog $catalogResolution.MergedCatalog `
            -NormalizeFileBaseName { param($LogicalName) Normalize-FileBaseName -LogicalName $LogicalName }
        $items = $legacyResult.Items
        $legacyUnmappedElements = @($legacyResult.UnmappedElements)
        if ($legacyUnmappedElements.Count -gt 0) {
            $warnings.Add(("export legado: elementos GXObject ignorados por falta de mapeamento no gx-legacy-export-element-map.json: {0}" -f ($legacyUnmappedElements -join ', '))) | Out-Null
        }
    }
    else {
        $items = Convert-PackageToItems -XmlDocument $packageXml -CatalogGuidToFolderMap $catalogGuidMap
    }
    $expectedComparison = Convert-ExpectedItemsToComparison -ExpectedItems $ExpectedItems -ActualItems $items

    $objectsBlockCount = @($items | Where-Object { $_.PackageSection -eq "Objects" -or $_.PackageSection -eq "GXObject" }).Count
    $attributesBlockCount = @($items | Where-Object { $_.PackageSection -eq "Attributes" }).Count
    $preExistingOfficialXmlCount = Get-OfficialXmlCount -Root $DestinationRoot

    $renameResults = @()
    if ($FullSnapshot) {
        $renameResults = Resolve-GuidAwareRenames -Items $items -Root $DestinationRoot -Warnings $warnings -Apply (-not [bool]$VerifyOnly)
    }

    $writeResults = @()
    if (-not $VerifyOnly) {
        foreach ($item in $items) {
            $writeResults += Write-ItemToDestination -Item $item -Root $DestinationRoot
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

    $materializationInterpretation = if ($VerifyOnly) {
        "verify-only"
    } elseif ($items.Count -eq 0) {
        "no-exportable-items"
    } elseif ($legacyFormatDetected -and $items.Count -gt 0) {
        "legacy-export-adapted"
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
        ObjectsBlockCount = $objectsBlockCount
        AttributesBlockCount = $attributesBlockCount
        TotalExportedItems = $items.Count
        PackageHasExportedItems = ($items.Count -gt 0)
        PackageInterpretation = if ($items.Count -gt 0) {
            if ($legacyFormatDetected) { "legacy-export-adapted" } else { "exported-items-found" }
        } else { "no-exportable-items" }
        LegacyFormatDetected = [bool]$legacyFormatDetected
        LegacyUnmappedElements = $legacyUnmappedElements
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
