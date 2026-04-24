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
Mantem o relatorio JSON mesmo quando a execucao termina sem erro.

.PARAMETER ExpectedItems
Lista opcional de itens esperados para comparacao com o retorno oficial do XPZ,
no formato `Tipo:Nome`.
.EXAMPLE
.\Sync-GeneXusXpzToXml.ps1 -InputPath C:\Exports\MeuPacote.xpz -DestinationRoot C:\Acervo\ObjetosDaKbEmXml

.EXAMPLE
.\Sync-GeneXusXpzToXml.ps1 -InputPath C:\Exports\MeuFull.xml -DestinationRoot C:\Acervo\ObjetosDaKbEmXml -VerifyOnly -FullSnapshot
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,

    [switch]$VerifyOnly,

    [switch]$FullSnapshot,

    [string]$ReportPath,

    [switch]$KeepReport,

    [string[]]$ExpectedItems = @(),

    [string]$KbMetadataPath = ""
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$KnownTypeMap = [ordered]@{
    "36e32e2d-023e-4188-95df-d13573bac2e0" = "API"
    "3affc0b3-494b-4d84-9ec1-3a6ab8349cda" = "ColorPalette"
    "526aba9f-a725-4bc7-b1db-0b9f92ac9550" = "Dashboard"
    "2a9e9aba-d2de-4801-ae7f-5e3819222daf" = "DataProvider"
    "ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af" = "DataSelector"
    "dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0" = "DataStore"
    "bf08dfb1-361c-4e7e-ad54-391e56e60b49" = "DeploymentUnit"
    "78b3fa0e-174c-4b2b-8716-718167a428b5" = "DesignSystem"
    "faeb588c-dcce-4dad-9af3-cdd11b961a32" = "Document"
    "00972a17-9975-449e-aab1-d26165d51393" = "Domain"
    "c163e562-42c6-4158-ad83-5b21a14cf30e" = "ExternalObject"
    "1132ac08-290f-4fd1-bd18-64777b7329d1" = "File"
    "00000000-0000-0000-0000-000000000006" = "Folder"
    "ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0" = "Generator"
    "9fb193d9-64a4-4d30-b129-ff7c76830f7e" = "Image"
    "857ca50e-7905-0000-0007-c5d9ff2975ec" = "Table"
    "88313f43-5eb2-0000-0028-e8d9f5bf9588" = "Language"
    "00000000-0000-0000-0000-000000000008" = "Module"
    "c88fffcd-b6f8-0000-8fec-00b5497e2117" = "PackagedModule"
    "d82625fd-5892-40b0-99c9-5c8559c197fc" = "Panel"
    "83476c1e-fa72-4229-9930-f51b954fca2d" = "PatternSettings"
    "84a12160-f59b-4ad7-a683-ea4481ac23e9" = "Procedure"
    "447527b5-9210-4523-898b-5dccb17be60a" = "SDT"
    "624a8b31-36f0-4292-adba-2d270d1e3537" = "Stencil"
    "87313f43-5eb2-41d7-9b8c-e8d9f5bf9588" = "SubTypeGroup"
    "c804fdbd-7c0b-440d-8527-4316c92649a6" = "Theme"
    "d4876646-98dd-419b-8c1c-896f83c48368" = "ThemeClass"
    "5592de59-d30a-499d-9100-a7006d3674f2" = "ThemeColor"
    "1db606f2-af09-4cf9-a3b5-b481519d28f6" = "Transaction"
    "562f4793-aabe-449f-8821-fc77e550698e" = "UserControl"
    "c9584656-94b6-4ccd-890f-332d11fc2c25" = "WebPanel"
    "78cecefe-be7d-4980-86ce-8d6e91fba04b" = "WorkWithForWeb"
}

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

function Get-DestinationTypeMap {
    param([string]$Root)

    $map = @{}
    foreach ($entry in $KnownTypeMap.GetEnumerator()) {
        $map[$entry.Key] = $entry.Value
    }

    if (-not (Test-Path -LiteralPath $Root)) {
        return $map
    }

    $dirs = Get-ChildItem -LiteralPath $Root -Directory
    foreach ($dir in $dirs) {
        if ($dir.Name -eq "Attribute") {
            continue
        }

        $sample = Get-ChildItem -LiteralPath $dir.FullName -Filter *.xml -File | Select-Object -First 1
        if ($null -eq $sample) {
            continue
        }

        try {
            [xml]$sampleXml = Get-Content -LiteralPath $sample.FullName -Raw
            $rootNode = $sampleXml.SelectSingleNode("/Object")
            if ($null -ne $rootNode) {
                $typeGuid = $rootNode.GetAttribute("type")
                if ($typeGuid) {
                    $map[$typeGuid.ToLowerInvariant()] = $dir.Name
                }
            }
        } catch {
        }
    }

    return $map
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

    $expectedKeys = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
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

    $actualKeys = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
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

    return [pscustomobject]@{
        ExpectedItemsProvided = $true
        ExpectedItems = @($expectedEntries | ForEach-Object {
            [pscustomobject]@{
                FolderType = $_.FolderType
                LogicalName = $_.LogicalName
            }
        })
        ExpectedReturned = @($expectedReturned)
        ExpectedMissing = @($expectedMissing)
        AdditionalOfficial = @($additionalOfficial)
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

function Get-KbSourceMetadataSnapshot {
    param([string]$MetadataPath)

    $snapshot = [ordered]@{
        MajorVersion = ""
        MinorVersion = ""
        Build = ""
        Kb = ""
        Username = ""
        UNCPath = ""
        VersionGuid = ""
        VersionName = ""
    }

    if (-not (Test-Path -LiteralPath $MetadataPath)) {
        return [pscustomobject]$snapshot
    }

    $section = ""
    foreach ($line in Get-Content -LiteralPath $MetadataPath) {
        if ($line -match '^##\s+KMW\b') {
            $section = "KMW"
            continue
        }

        if ($line -match '^##\s+Source/Version\b') {
            $section = "SourceVersion"
            continue
        }

        if ($line -match '^##\s+Source\b') {
            $section = "Source"
            continue
        }

        if ($line -match '^##\s+') {
            $section = ""
            continue
        }

        switch ($section) {
            "KMW" {
                if ($line -match '^\|\s*MajorVersion\s*\|\s*(.*?)\s*\|\s*$') {
                    $snapshot.MajorVersion = $Matches[1].Trim()
                    continue
                }
                if ($line -match '^\|\s*MinorVersion\s*\|\s*(.*?)\s*\|\s*$') {
                    $snapshot.MinorVersion = $Matches[1].Trim()
                    continue
                }
                if ($line -match '^\|\s*Build\s*\|\s*(.*?)\s*\|\s*$') {
                    $snapshot.Build = $Matches[1].Trim()
                    continue
                }
            }
            "Source" {
                if ($line -match '^\|\s*kb \(GUID\)\s*\|\s*(.*?)\s*\|\s*$') {
                    $snapshot.Kb = $Matches[1].Trim()
                    continue
                }
                if ($line -match '^\|\s*username\s*\|\s*(.*?)\s*\|\s*$') {
                    $snapshot.Username = $Matches[1].Trim()
                    continue
                }
                if ($line -match '^\|\s*UNCPath\s*\|\s*(.*?)\s*\|\s*$') {
                    $snapshot.UNCPath = $Matches[1].Trim()
                    continue
                }
            }
            "SourceVersion" {
                if ($line -match '^\|\s*guid\s*\|\s*(.*?)\s*\|\s*$') {
                    $snapshot.VersionGuid = $Matches[1].Trim()
                    continue
                }
                if ($line -match '^\|\s*name\s*\|\s*(.*?)\s*\|\s*$') {
                    $snapshot.VersionName = $Matches[1].Trim()
                    continue
                }
            }
        }
    }

    return [pscustomobject]$snapshot
}

function Convert-PackageToItems {
    param(
        [xml]$XmlDocument,
        [hashtable]$TypeMap
    )

    $items = New-Object System.Collections.Generic.List[object]
    $unknownTypeCounts = @{}

    $objectsNode = $XmlDocument.SelectSingleNode("/ExportFile/Objects")
    if ($null -ne $objectsNode) {
        foreach ($node in $objectsNode.SelectNodes("./Object")) {
            $typeGuid = $node.GetAttribute("type").ToLowerInvariant()
            if (-not $TypeMap.ContainsKey($typeGuid)) {
                if (-not $unknownTypeCounts.ContainsKey($typeGuid)) {
                    $unknownTypeCounts[$typeGuid] = 0
                }
                $unknownTypeCounts[$typeGuid] += 1
                continue
            }

            $logicalName = $node.GetAttribute("name")
            $folderType = $TypeMap[$typeGuid]
            $normalizedName = Normalize-FileBaseName -LogicalName $logicalName
            $items.Add([pscustomobject]@{
                PackageSection = "Objects"
                RootTag = "Object"
                FolderType = $folderType
                LogicalName = $logicalName
                NormalizedName = $normalizedName
                TypeGuid = $typeGuid
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
                Node = $node
            }) | Out-Null
        }
    }

    if ($unknownTypeCounts.Count -gt 0) {
        $unknownList = $unknownTypeCounts.GetEnumerator() |
            Sort-Object Name |
            ForEach-Object { "$($_.Name) [$($_.Value)]" }

        throw "Package contains object type GUIDs not mapped to destination folders: $($unknownList -join ', '). Update the type map before materializing this package."
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
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
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
        [System.IO.File]::WriteAllText($filePath, $xmlText, (New-Object System.Text.UTF8Encoding($false)))
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

    $packageKeys = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Items) {
        [void]$packageKeys.Add("$($item.FolderType)|$($item.LogicalName)")
    }

    $localKeys = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
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

function Update-KbSourceMetadata {
    param(
        [xml]$XmlDocument,
        [string]$SourceXpzPath,
        [string]$MetadataPath
    )

    $kmwNode    = $XmlDocument.SelectSingleNode("/ExportFile/KMW")
    $sourceNode = $XmlDocument.SelectSingleNode("/ExportFile/Source")
    $versionNode = $XmlDocument.SelectSingleNode("/ExportFile/Source/Version")

    $existingMetadata = Get-KbSourceMetadataSnapshot -MetadataPath $MetadataPath

    $packageMajorVersion = if ($null -ne $kmwNode -and $null -ne $kmwNode.SelectSingleNode("MajorVersion")) { $kmwNode.SelectSingleNode("MajorVersion").InnerText } else { "" }
    $packageMinorVersion = if ($null -ne $kmwNode -and $null -ne $kmwNode.SelectSingleNode("MinorVersion")) { $kmwNode.SelectSingleNode("MinorVersion").InnerText } else { "" }
    $packageBuild        = if ($null -ne $kmwNode -and $null -ne $kmwNode.SelectSingleNode("Build"))        { $kmwNode.SelectSingleNode("Build").InnerText }        else { "" }

    $packageKbGuid      = if ($null -ne $sourceNode) { $sourceNode.GetAttribute("kb") } else { "" }
    $packageUsername    = if ($null -ne $sourceNode) { $sourceNode.GetAttribute("username") } else { "" }
    $packageUncPath     = if ($null -ne $sourceNode) { $sourceNode.GetAttribute("UNCPath") } else { "" }
    $packageVersionGuid = if ($null -ne $versionNode) { $versionNode.GetAttribute("guid") } else { "" }
    $packageVersionName = if ($null -ne $versionNode) { $versionNode.GetAttribute("name") } else { "" }

    $majorVersion = if ([string]::IsNullOrWhiteSpace($packageMajorVersion)) { $existingMetadata.MajorVersion } else { $packageMajorVersion }
    $minorVersion = if ([string]::IsNullOrWhiteSpace($packageMinorVersion)) { $existingMetadata.MinorVersion } else { $packageMinorVersion }
    $build        = if ([string]::IsNullOrWhiteSpace($packageBuild))        { $existingMetadata.Build }        else { $packageBuild }

    $kbGuid      = if ([string]::IsNullOrWhiteSpace($packageKbGuid))      { $existingMetadata.Kb }          else { $packageKbGuid }
    $username    = if ([string]::IsNullOrWhiteSpace($packageUsername))    { $existingMetadata.Username }    else { $packageUsername }
    $uncPath     = if ([string]::IsNullOrWhiteSpace($packageUncPath))     { $existingMetadata.UNCPath }     else { $packageUncPath }
    $versionGuid = if ([string]::IsNullOrWhiteSpace($packageVersionGuid)) { $existingMetadata.VersionGuid } else { $packageVersionGuid }
    $versionName = if ([string]::IsNullOrWhiteSpace($packageVersionName)) { $existingMetadata.VersionName } else { $packageVersionName }

    $hasCompleteSourceFromPackage = @(
        $packageKbGuid,
        $packageUsername,
        $packageUncPath,
        $packageVersionGuid,
        $packageVersionName
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $hasCompleteSourceFromPackage = @($hasCompleteSourceFromPackage)
    $hasCompleteSourceFromPackage = ($hasCompleteSourceFromPackage.Count -eq 5)
    $hasStableMetadataBaseline = @(
        $existingMetadata.Kb,
        $existingMetadata.Username,
        $existingMetadata.UNCPath,
        $existingMetadata.VersionGuid,
        $existingMetadata.VersionName
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $hasStableMetadataBaseline = @($hasStableMetadataBaseline)
    $hasStableMetadataBaseline = ($hasStableMetadataBaseline.Count -gt 0)

    $metadataStatus = if ($hasCompleteSourceFromPackage) {
        "complete"
    } elseif ($hasStableMetadataBaseline) {
        "partial-preserved"
    } else {
        "partial-new"
    }

    $warnings = New-Object System.Collections.Generic.List[string]
    if ($null -eq $kmwNode -or $null -eq $sourceNode) {
        $warnings.Add("KbMetadataPath: pacote aceito para sync de objetos, mas KMW ou Source vieram ausentes/incompletos; valores estaveis anteriores foram preservados e kb-source-metadata.md recebeu refresh parcial.") | Out-Null
    } elseif (-not $hasCompleteSourceFromPackage) {
        if ($hasStableMetadataBaseline) {
            $warnings.Add("KbMetadataPath: pacote aceito para sync de objetos, mas Source incompleto; valores estaveis anteriores foram preservados e kb-source-metadata.md recebeu refresh parcial.") | Out-Null
        } else {
            $warnings.Add("KbMetadataPath: pacote aceito para sync de objetos, mas Source incompleto e sem baseline estavel previa; kb-source-metadata.md recebeu refresh parcial.") | Out-Null
        }
    }

    $timestamp   = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.0000000Z")

    $content = @"
---
name: KB Source Metadata
description: Valores de KMW e Source extraidos do XPZ mais recente da IDE — usados para montar o envelope de import_file.xml
updated: $timestamp
last_xpz_materialization_run_at: $timestamp
source_xpz: $SourceXpzPath
source_refresh_status: $metadataStatus
---

## KMW

| Campo        | Valor          |
|---|---|
| MajorVersion | $majorVersion  |
| MinorVersion | $minorVersion  |
| Build        | $build         |

## Source

| Campo    | Valor       |
|---|---|
| kb (GUID) | $kbGuid    |
| username  | $username  |
| UNCPath   | $uncPath   |

## Source/Version

| Campo | Valor        |
|---|---|
| guid  | $versionGuid |
| name  | $versionName |

## Uso

Ao gerar um ``import_file.xml`` ou ``.xpz`` para importacao na KB, usar estes valores
nos blocos ``<KMW>`` e ``<Source>`` do envelope ``<ExportFile>``.
"@

    [System.IO.File]::WriteAllText($MetadataPath, $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "KbMetadataPath atualizado: $MetadataPath" -ForegroundColor Cyan

    if ($warnings.Count -gt 0) {
        Write-Warning ($warnings[0])
    }

    return [pscustomobject]@{
        MetadataStatus = $metadataStatus
        SourceComplete = $hasCompleteSourceFromPackage
        Warnings = @($warnings)
    }
}

function Write-Report {
    param(
        [string]$Path,
        [object]$Payload
    )

    $json = $Payload | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

$package = $null
$warnings = New-Object System.Collections.Generic.List[string]
try {
    $package = Resolve-PackageXmlPath -RawInputPath $InputPath
    [xml]$packageXml = Get-Content -LiteralPath $package.XmlPath -Raw

    if ($packageXml.DocumentElement.LocalName -ne "ExportFile") {
        throw "Expected root element 'ExportFile', found '$($packageXml.DocumentElement.LocalName)'."
    }

    if ($KbMetadataPath) {
        $metadataResult = Update-KbSourceMetadata -XmlDocument $packageXml -SourceXpzPath $InputPath -MetadataPath $KbMetadataPath
        foreach ($warning in $metadataResult.Warnings) {
            if (-not [string]::IsNullOrWhiteSpace($warning)) {
                $warnings.Add($warning) | Out-Null
            }
        }
    }

    $typeMap = Get-DestinationTypeMap -Root $DestinationRoot
    $items = Convert-PackageToItems -XmlDocument $packageXml -TypeMap $typeMap
    $expectedComparison = Convert-ExpectedItemsToComparison -ExpectedItems $ExpectedItems -ActualItems $items

    $objectsBlockCount = @($items | Where-Object { $_.PackageSection -eq "Objects" }).Count
    $attributesBlockCount = @($items | Where-Object { $_.PackageSection -eq "Attributes" }).Count
    $preExistingOfficialXmlCount = Get-OfficialXmlCount -Root $DestinationRoot

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

    $materializationInterpretation = if ($VerifyOnly) {
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
        InputPath = (Resolve-Path -LiteralPath $InputPath).Path
        PackageXmlPath = $package.XmlPath
        VerifyOnly = [bool]$VerifyOnly
        FullSnapshot = [bool]$FullSnapshot
        ObjectsBlockCount = $objectsBlockCount
        AttributesBlockCount = $attributesBlockCount
        TotalExportedItems = $items.Count
        PackageHasExportedItems = ($items.Count -gt 0)
        PackageInterpretation = if ($items.Count -gt 0) { "exported-items-found" } else { "no-exportable-items" }
        PreExistingOfficialXmlCount = $preExistingOfficialXmlCount
        MaterializationInterpretation = $materializationInterpretation
        Created = $createdCount
        Updated = $updatedCount
        Unchanged = $unchangedCount
        SkippedOlderLastUpdate = $skippedOlderLastUpdateCount
        NormalizedFileNames = $normalizedFileNamesCount
        MissingAfterVerification = $verification.Missing.Count
        MismatchesAfterVerification = $verification.Mismatch.Count
        FullSnapshotMissing = if ($null -ne $fullSnapshotResult) { $fullSnapshotResult.MissingKeys.Count } else { $null }
        FullSnapshotExtra = if ($null -ne $fullSnapshotResult) { $fullSnapshotResult.ExtraKeys.Count } else { $null }
        ExpectedItemsProvided = ($null -ne $expectedComparison)
        ExpectedItemsCount = if ($null -ne $expectedComparison) { $expectedComparison.ExpectedItems.Count } else { 0 }
        ExpectedReturnedCount = if ($null -ne $expectedComparison) { $expectedComparison.ExpectedReturned.Count } else { $null }
        ExpectedMissingCount = if ($null -ne $expectedComparison) { $expectedComparison.ExpectedMissing.Count } else { $null }
        AdditionalOfficialCount = if ($null -ne $expectedComparison) { $expectedComparison.AdditionalOfficial.Count } else { $null }
    }

    $report = [pscustomobject]@{
        Summary = $summary
        Missing = $verification.Missing
        Mismatch = $verification.Mismatch
        FullSnapshot = $fullSnapshotResult
        ExpectedComparison = $expectedComparison
        Writes = $writeResults
        Warnings = @($warnings)
        KbMetadataStatus = if ($null -ne $metadataResult) { $metadataResult.MetadataStatus } else { "not-requested" }
        KbMetadataSourceComplete = if ($null -ne $metadataResult) { [bool]$metadataResult.SourceComplete } else { $null }
    }

    if ($ReportPath) {
        Write-Report -Path $ReportPath -Payload $report
    }

    $summary | Format-List | Out-String | Write-Output

    $expectedSummary = Format-ExpectedItemsSummary -ExpectedComparison $expectedComparison
    if (-not [string]::IsNullOrWhiteSpace($expectedSummary)) {
        Write-Output ""
        Write-Output $expectedSummary
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
