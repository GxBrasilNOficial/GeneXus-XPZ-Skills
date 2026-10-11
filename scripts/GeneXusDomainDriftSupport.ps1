#requires -Version 7.4

Set-StrictMode -Version Latest

$script:GeneXusDomainCanonicalTypeGuid = '00972a17-9975-449e-aab1-d26165d51393'
$script:GeneXusDomainConditionalFields = @(
    'AUTONUMBER', 'AUTONUMBER_FORREPLICATION', 'AUTONUMBER_START', 'AUTONUMBER_STEP',
    'AddEmptyItem', 'ATT_PICTURE', 'AttAvgLen', 'AttCollection', 'ControlType',
    'EmptyAsNull', 'idBasedOn', 'idCHARCASE', 'idDATEFORMAT', 'idHOURFORMAT',
    'Name', 'Description', 'NotifyContextChange'
)
$script:GeneXusDomainAlwaysBlockedFields = @(
    'ATT_INITIAL_VALUE', 'ATTCUSTOMTYPE', 'Decimals', 'IsDefault', 'Signed'
)

function ConvertTo-GeneXusDomainGuid {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    $parsed = [guid]::Empty
    if (-not [guid]::TryParse($Value.Trim(), [ref]$parsed) -or $parsed -eq [guid]::Empty) { return '' }
    return $parsed.ToString('D').ToLowerInvariant()
}

function Resolve-GeneXusDomainTypeIdentity {
    param([Parameter(Mandatory = $true)][string]$CatalogPath)

    $canonical = $script:GeneXusDomainCanonicalTypeGuid
    $fallback = [pscustomobject]@{ typeGuid = $canonical; source = 'fallback'; usable = $true; inconsistent = $false; reason = '' }
    if (-not (Test-Path -LiteralPath $CatalogPath -PathType Leaf)) {
        $fallback.reason = 'catalog-missing'
        return $fallback
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($CatalogPath)
        $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
        $jsonText = $utf8.GetString($bytes)
        $document = [System.Text.Json.JsonDocument]::Parse($jsonText)
    } catch {
        $fallback.reason = 'catalog-unreadable-or-invalid'
        return $fallback
    }

    try {
        $root = $document.RootElement
        if ($root.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            $fallback.reason = 'catalog-root-invalid'
            return $fallback
        }
        $typesEntries = @($root.EnumerateObject() | Where-Object { $_.Name -ceq 'types' })
        if ($typesEntries.Count -ne 1 -or $typesEntries[0].Value.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            $fallback.reason = 'catalog-types-invalid'
            return $fallback
        }
        $types = $typesEntries[0].Value

        $domainEntries = @($types.EnumerateObject() | Where-Object { $_.Name -ceq 'Domain' })
        if ($domainEntries.Count -ne 1 -or $domainEntries[0].Value.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            $fallback.reason = 'catalog-domain-entry-missing-or-duplicate'
            return $fallback
        }

        $guidProperties = @($domainEntries[0].Value.EnumerateObject() | Where-Object { $_.Name -ceq 'objectTypeGuid' })
        if ($guidProperties.Count -ne 1 -or $guidProperties[0].Value.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
            $fallback.reason = 'catalog-domain-guid-missing-or-invalid'
            return $fallback
        }

        $catalogGuid = ConvertTo-GeneXusDomainGuid -Value $guidProperties[0].Value.GetString()
        if ([string]::IsNullOrWhiteSpace($catalogGuid)) {
            $fallback.reason = 'catalog-domain-guid-invalid'
            return $fallback
        }
        if ($catalogGuid -cne $canonical) {
            return [pscustomobject]@{ typeGuid = $catalogGuid; source = 'catalog'; usable = $false; inconsistent = $true; reason = 'catalog-domain-guid-diverges-from-canonical' }
        }
        return [pscustomobject]@{ typeGuid = $canonical; source = 'catalog'; usable = $true; inconsistent = $false; reason = '' }
    } finally {
        $document.Dispose()
    }
}

function Test-GeneXusDomainTypeGuid {
    param(
        [AllowNull()][string]$Value,
        [Parameter(Mandatory = $true)]$Identity
    )

    $normalized = ConvertTo-GeneXusDomainGuid -Value $Value
    if ($normalized -ceq $script:GeneXusDomainCanonicalTypeGuid) { return $true }
    return ($Identity.inconsistent -and $normalized -ceq [string]$Identity.typeGuid)
}

function Read-GeneXusDomainXml {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $settings = [System.Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [System.Xml.XmlReader]::Create($Path, $settings)
        try {
            $document = [System.Xml.XmlDocument]::new()
            $document.XmlResolver = $null
            $document.PreserveWhitespace = $true
            $document.Load($reader)
        } finally {
            $reader.Dispose()
        }
        return [pscustomobject]@{ document = $document; error = '' }
    } catch {
        return [pscustomobject]@{ document = $null; error = $_.Exception.Message }
    }
}

function Get-GeneXusDomainDirectChildren {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlNode]$Parent,
        [Parameter(Mandatory = $true)][string]$LocalName
    )
    return @($Parent.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.LocalName -ceq $LocalName })
}

function New-GeneXusDomainValueState {
    param([AllowNull()][string]$Value, [bool]$Present)
    if (-not $Present) { return [pscustomobject]@{ state = 'absent'; value = $null } }
    if ($null -eq $Value -or $Value.Length -eq 0) { return [pscustomobject]@{ state = 'empty'; value = '' } }
    return [pscustomobject]@{ state = 'value'; value = $Value }
}

function Get-GeneXusDomainAttributeState {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlElement]$Root,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if (-not $Root.HasAttribute($Name)) { return New-GeneXusDomainValueState -Present $false -Value $null }
    return New-GeneXusDomainValueState -Present $true -Value $Root.GetAttribute($Name)
}

function Get-GeneXusDomainPropertyObservations {
    param([Parameter(Mandatory = $true)][System.Xml.XmlElement]$Root)

    $observations = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $errors = [System.Collections.Generic.List[string]]::new()
    $containers = [System.Collections.Generic.List[object]]::new()
    $rootProperties = @(Get-GeneXusDomainDirectChildren -Parent $Root -LocalName 'Properties')
    if ($rootProperties.Count -gt 1) {
        $errors.Add('Object/Properties duplicado') | Out-Null
    } elseif ($rootProperties.Count -eq 1) {
        $containers.Add([pscustomobject]@{ container = 'Object/Properties'; partType = ''; node = $rootProperties[0] }) | Out-Null
    }

    foreach ($part in @(Get-GeneXusDomainDirectChildren -Parent $Root -LocalName 'Part')) {
        $partType = $part.GetAttribute('type')
        $partProperties = @(Get-GeneXusDomainDirectChildren -Parent $part -LocalName 'Properties')
        if ($partProperties.Count -gt 1) {
            $errors.Add("Object/Part[@type='$partType']/Properties duplicado") | Out-Null
            continue
        }
        if ($partProperties.Count -eq 1) {
            $containers.Add([pscustomobject]@{ container = 'Object/Part/Properties'; partType = $partType; node = $partProperties[0] }) | Out-Null
        }
    }

    foreach ($containerInfo in $containers) {
        foreach ($property in @(Get-GeneXusDomainDirectChildren -Parent $containerInfo.node -LocalName 'Property')) {
            $nameNodes = @(Get-GeneXusDomainDirectChildren -Parent $property -LocalName 'Name')
            $valueNodes = @(Get-GeneXusDomainDirectChildren -Parent $property -LocalName 'Value')
            $elementNames = @($property.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element } | ForEach-Object { [string]$_.LocalName })
            if ($nameNodes.Count -ne 1 -or $valueNodes.Count -ne 1 -or $elementNames.Count -ne 2 -or $elementNames[0] -cne 'Name' -or $elementNames[1] -cne 'Value') {
                $errors.Add("Propriedade com cardinalidade/ordem Name,Value inválida em $($containerInfo.container)") | Out-Null
                continue
            }
            $propertyName = [string]$nameNodes[0].InnerText
            if ([string]::IsNullOrWhiteSpace($propertyName)) {
                $errors.Add("Propriedade sem Name em $($containerInfo.container)") | Out-Null
                continue
            }
            $location = [ordered]@{ kind = 'property'; container = [string]$containerInfo.container; partType = [string]$containerInfo.partType; field = $propertyName }
            $key = ConvertTo-Json -InputObject @($location.kind, $location.container, $location.partType, $location.field) -Compress
            if ($observations.ContainsKey($key)) {
                $observations[$key].duplicate = $true
                $errors.Add("Propriedade '$propertyName' duplicada no mesmo container $($containerInfo.container) (Part/@type='$($containerInfo.partType)')") | Out-Null
                continue
            }
            $state = New-GeneXusDomainValueState -Present $true -Value ([string]$valueNodes[0].InnerText)
            $observations[$key] = [pscustomobject]@{
                key = $key
                locationKind = 'property'
                container = [string]$containerInfo.container
                partType = [string]$containerInfo.partType
                field = $propertyName
                component = 'value'
                state = $state.state
                value = $state.value
                duplicate = $false
            }
        }
    }
    return [pscustomobject]@{ observations = $observations; errors = @($errors.ToArray()) }
}

function Get-GeneXusDomainObjectModel {
    param(
        [Parameter(Mandatory = $true)][System.Xml.XmlDocument]$Document,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    $root = $Document.DocumentElement
    $propertyResult = Get-GeneXusDomainPropertyObservations -Root $root
    $attributes = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    foreach ($name in @('name', 'fullyQualifiedName', 'moduleGuid', 'parentGuid', 'description')) {
        $attributes[$name] = Get-GeneXusDomainAttributeState -Root $root -Name $name
    }
    $propertyNameKey = ConvertTo-Json -InputObject @('property', 'Object/Properties', '', 'Name') -Compress
    $nameProperty = if ($propertyResult.observations.ContainsKey($propertyNameKey)) { $propertyResult.observations[$propertyNameKey] } else { $null }
    $rootNameState = $attributes['name']
    $nameValue = if ($null -ne $nameProperty) { [string]$nameProperty.value } else { '' }
    $rootNameValue = if ($rootNameState.state -eq 'absent') { '' } else { [string]$rootNameState.value }
    $displayName = if (-not [string]::IsNullOrWhiteSpace($rootNameValue)) { $rootNameValue } else { $nameValue }
    $relativePath = [System.IO.Path]::GetRelativePath($RootPath, $Path).Replace('\', '/')
    return [pscustomobject]@{
        path = $Path
        relativePath = $relativePath
        root = $root
        guid = $root.GetAttribute('guid')
        guidNormalized = ConvertTo-GeneXusDomainGuid -Value $root.GetAttribute('guid')
        acervoPath = ''
        typeGuid = $root.GetAttribute('type')
        name = $displayName
        rootNameState = $rootNameState
        observations = $propertyResult.observations
        attributes = $attributes
        errors = @($propertyResult.errors)
    }
}

function Get-GeneXusDomainObservationKey {
    param(
        [Parameter(Mandatory = $true)][string]$LocationKind,
        [Parameter(Mandatory = $true)][string]$Container,
        [AllowNull()][string]$PartType,
        [Parameter(Mandatory = $true)][string]$Field
    )
    return ConvertTo-Json -InputObject @($LocationKind, $Container, [string]$PartType, $Field) -Compress
}

function Get-GeneXusDomainApprovalKey {
    param([Parameter(Mandatory = $true)]$Approval)
    $parts = @(
        [string]$Approval.objectGuid,
        [string]$Approval.field,
        [string]$Approval.locationKind,
        [string]$Approval.container,
        [string]$Approval.partType,
        [string]$Approval.component,
        [string]$Approval.enumStoredValue,
        [string]$Approval.oldState,
        [string]$Approval.oldValue,
        [string]$Approval.newState,
        [string]$Approval.newValue
    )
    return ConvertTo-Json -InputObject $parts -Compress
}

function Split-GeneXusDomainEscapedDelimiter {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory = $true)][char]$Delimiter
    )
    $parts = [System.Collections.Generic.List[string]]::new()
    $builder = [System.Text.StringBuilder]::new()
    $slashes = 0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $character = $Text[$i]
        if ($character -eq '\') {
            [void]$builder.Append($character)
            $slashes++
            continue
        }
        if ($character -eq $Delimiter) {
            if (($slashes % 2) -eq 1) {
                [void]$builder.Remove($builder.Length - 1, 1)
                [void]$builder.Append($character)
            } else {
                $parts.Add($builder.ToString()) | Out-Null
                [void]$builder.Clear()
            }
            $slashes = 0
            continue
        }
        [void]$builder.Append($character)
        $slashes = 0
    }
    $parts.Add($builder.ToString()) | Out-Null
    return [pscustomobject]@{ parts = @($parts.ToArray()); trailingEscape = (($slashes % 2) -eq 1) }
}

function ConvertFrom-GeneXusDomainEnum {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

    if ($Text.Length -eq 0) { return [pscustomobject]@{ valid = $true; rows = @(); reason = '' } }
    $segments = Split-GeneXusDomainEscapedDelimiter -Text $Text -Delimiter ';'
    if ($segments.trailingEscape) { return [pscustomobject]@{ valid = $false; rows = @(); reason = 'escape terminal' } }
    $rows = [System.Collections.Generic.List[object]]::new()
    $storedValues = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $identifiers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($segment in $segments.parts) {
        if ([string]::IsNullOrWhiteSpace($segment)) { return [pscustomobject]@{ valid = $false; rows = @(); reason = 'item vazio ou separador terminal' } }
        $components = Split-GeneXusDomainEscapedDelimiter -Text $segment -Delimiter ','
        if ($components.trailingEscape -or $components.parts.Count -ne 3) { return [pscustomobject]@{ valid = $false; rows = @(); reason = 'item não possui exatamente três componentes' } }
        $storedValue = [string]$components.parts[0].Trim()
        $identifier = [string]$components.parts[1].Trim()
        $description = [string]$components.parts[2].Trim()
        if ([string]::IsNullOrWhiteSpace($storedValue) -or [string]::IsNullOrWhiteSpace($identifier)) { return [pscustomobject]@{ valid = $false; rows = @(); reason = 'valor armazenado ou identificador vazio' } }
        if (-not $storedValues.Add($storedValue)) { return [pscustomobject]@{ valid = $false; rows = @(); reason = 'valor armazenado duplicado' } }
        if (-not $identifiers.Add($identifier)) { return [pscustomobject]@{ valid = $false; rows = @(); reason = 'identificador duplicado' } }
        $rows.Add([pscustomobject]@{ storedValue = $storedValue; identifier = $identifier; description = $description }) | Out-Null
    }
    return [pscustomobject]@{ valid = $true; rows = @($rows.ToArray()); reason = '' }
}

function Read-GeneXusDomainApprovals {
    param([AllowNull()][string]$Path, [bool]$WasSupplied = $false)

    if (-not $WasSupplied) {
        return [pscustomobject]@{ valid = $true; approvals = @(); reason = '' }
    }
    if ([string]::IsNullOrWhiteSpace($Path)) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'caminho de aprovações vazio' } }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'arquivo de aprovações não encontrado' }
    }

    $document = $null
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'JSON de aprovações deve ser UTF-8 sem BOM' }
        }
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        $document = [System.Text.Json.JsonDocument]::Parse($text)
    } catch {
        return [pscustomobject]@{ valid = $false; approvals = @(); reason = "JSON de aprovações ilegível ou inválido: $($_.Exception.Message)" }
    }

    try {
        $root = $document.RootElement
        if ($root.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'raiz do JSON de aprovações deve ser objeto' }
        }
        $rootProperties = [System.Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([System.StringComparer]::Ordinal)
        foreach ($entry in $root.EnumerateObject()) {
            if ($rootProperties.ContainsKey($entry.Name)) {
                return [pscustomobject]@{ valid = $false; approvals = @(); reason = "campo raiz duplicado: $($entry.Name)" }
            }
            $rootProperties.Add($entry.Name, $entry.Value)
        }
        $rootAllowed = @('kind', 'schemaVersion', 'approvals')
        foreach ($key in $rootProperties.Keys) {
            if ($key -cnotin $rootAllowed) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = "campo raiz não reconhecido: $key" } }
        }
        if (-not $rootProperties.ContainsKey('kind') -or $rootProperties['kind'].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or $rootProperties['kind'].GetString() -cne 'domain-drift-approvals') {
            return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'kind deve ser domain-drift-approvals' }
        }
        if (-not $rootProperties.ContainsKey('schemaVersion') -or $rootProperties['schemaVersion'].ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or $rootProperties['schemaVersion'].GetInt32() -ne 1) {
            return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'schemaVersion deve ser 1' }
        }
        if (-not $rootProperties.ContainsKey('approvals') -or $rootProperties['approvals'].ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
            return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'approvals deve ser um array' }
        }

        $required = @('objectGuid', 'field', 'locationKind', 'container', 'component', 'oldState', 'oldValue', 'newState', 'newValue')
        $allowed = @($required + @('partType', 'enumStoredValue'))
        $approvals = [System.Collections.Generic.List[object]]::new()
        $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($item in $rootProperties['approvals'].EnumerateArray()) {
            if ($item.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
                return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'cada aprovação deve ser objeto' }
            }
            $fields = [System.Collections.Generic.Dictionary[string, System.Text.Json.JsonElement]]::new([System.StringComparer]::Ordinal)
            foreach ($entry in $item.EnumerateObject()) {
                if ($fields.ContainsKey($entry.Name)) {
                    return [pscustomobject]@{ valid = $false; approvals = @(); reason = "campo de aprovação duplicado: $($entry.Name)" }
                }
                if ($entry.Name -cnotin $allowed) {
                    return [pscustomobject]@{ valid = $false; approvals = @(); reason = "campo de aprovação não reconhecido: $($entry.Name)" }
                }
                $fields.Add($entry.Name, $entry.Value)
            }
            foreach ($name in $required) {
                if (-not $fields.ContainsKey($name)) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = "campo obrigatório ausente: $name" } }
            }
            if ($fields['objectGuid'].ValueKind -ne [System.Text.Json.JsonValueKind]::String) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'objectGuid deve ser string' } }
            $guid = ConvertTo-GeneXusDomainGuid -Value $fields['objectGuid'].GetString()
            if ([string]::IsNullOrWhiteSpace($guid)) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'objectGuid inválido ou zero' } }

            foreach ($name in @('field', 'locationKind', 'container', 'component', 'oldState', 'newState')) {
                if ($fields[$name].ValueKind -ne [System.Text.Json.JsonValueKind]::String -or [string]::IsNullOrWhiteSpace($fields[$name].GetString())) {
                    return [pscustomobject]@{ valid = $false; approvals = @(); reason = "$name deve ser string não vazia" }
                }
            }
            $oldValue = $null
            $newValue = $null
            foreach ($pair in @(@('oldValue', 'oldState'), @('newValue', 'newState'))) {
                $valueName = [string]$pair[0]
                $stateName = [string]$pair[1]
                $valueElement = $fields[$valueName]
                $state = [string]$fields[$stateName].GetString()
                if ($state -cnotin @('absent', 'empty', 'value')) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = "$stateName deve ser absent, empty ou value" } }
                if ($state -ceq 'absent') {
                    if ($valueElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Null) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = "$valueName deve ser null quando $stateName=absent" } }
                } elseif ($valueElement.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
                    return [pscustomobject]@{ valid = $false; approvals = @(); reason = "$valueName deve ser string quando $stateName não é absent" }
                } elseif ($state -ceq 'empty' -and $valueElement.GetString().Length -ne 0) {
                    return [pscustomobject]@{ valid = $false; approvals = @(); reason = "$valueName deve ser vazio quando $stateName=empty" }
                } elseif ($state -ceq 'value' -and $valueElement.GetString().Length -eq 0) {
                    return [pscustomobject]@{ valid = $false; approvals = @(); reason = "$valueName não pode ser vazio quando $stateName=value" }
                }
                if ($valueName -ceq 'oldValue' -and $valueElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) { $oldValue = $valueElement.GetString() }
                if ($valueName -ceq 'newValue' -and $valueElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String) { $newValue = $valueElement.GetString() }
            }

            $locationKind = [string]$fields['locationKind'].GetString()
            $container = [string]$fields['container'].GetString()
            $partType = ''
            if ($fields.ContainsKey('partType')) {
                if ($fields['partType'].ValueKind -ne [System.Text.Json.JsonValueKind]::String) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'partType deve ser string' } }
                $partType = [string]$fields['partType'].GetString()
            }
            if ($locationKind -ceq 'rootAttribute' -and $container -cne 'Object') { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'atributo de raiz deve usar container=Object' } }
            if ($locationKind -ceq 'property' -and $container -cnotin @('Object/Properties', 'Object/Part/Properties')) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'container de propriedade não reconhecido' } }
            if ($locationKind -cnotin @('rootAttribute', 'property')) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'locationKind não reconhecido' } }
            if ($locationKind -ceq 'property' -and $container -ceq 'Object/Part/Properties' -and -not $fields.ContainsKey('partType')) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'partType obrigatório para propriedade em Part' } }
            if ($locationKind -ceq 'property' -and $container -ceq 'Object/Properties' -and $partType.Length -gt 0) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'partType deve ser vazio para Object/Properties' } }
            if ($locationKind -ceq 'rootAttribute' -and $partType.Length -gt 0) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'partType deve ser vazio para atributo de raiz' } }

            $enumStoredValue = ''
            if ($fields.ContainsKey('enumStoredValue')) {
                if ($fields['enumStoredValue'].ValueKind -ne [System.Text.Json.JsonValueKind]::String) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'enumStoredValue deve ser string' } }
                $enumStoredValue = [string]$fields['enumStoredValue'].GetString()
            }
            $fieldName = [string]$fields['field'].GetString()
            $component = [string]$fields['component'].GetString()
            if ($fieldName -ceq 'IDEnumDefinedValues' -and $component -cin @('identifier', 'description') -and [string]::IsNullOrWhiteSpace($enumStoredValue)) {
                return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'enumStoredValue obrigatório para alteração de identificador/descrição enumerada' }
            }
            $approval = [pscustomobject]@{
                objectGuid = $guid
                field = $fieldName
                locationKind = $locationKind
                container = $container
                partType = $partType
                component = $component
                enumStoredValue = $enumStoredValue
                oldState = [string]$fields['oldState'].GetString()
                oldValue = $oldValue
                newState = [string]$fields['newState'].GetString()
                newValue = $newValue
            }
            $key = Get-GeneXusDomainApprovalKey -Approval $approval
            if (-not $seen.Add($key)) { return [pscustomobject]@{ valid = $false; approvals = @(); reason = 'aprovação duplicada' } }
            $approvals.Add($approval) | Out-Null
        }
        return [pscustomobject]@{ valid = $true; approvals = @($approvals.ToArray()); reason = '' }
    } finally {
        $document.Dispose()
    }
}

function New-GeneXusDomainFinding {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ObjectName,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ObjectGuid,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$ObjectFile,
        [string]$AcervoPath = '',
        [hashtable]$ExtraFields = @{}
    )
    return New-Finding -Severity 'fail' -Code $Code -Message $Message -ObjectName $ObjectName -ObjectGuid $ObjectGuid -ObjectFile $ObjectFile -AcervoFile $AcervoPath -AcervoPath $AcervoPath -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'domain-guid' -ExtraFields $ExtraFields
}

function Test-GeneXusDomainStatesEqual {
    param($Left, $Right)
    if ([string]$Left.state -cne [string]$Right.state) { return $false }
    if ([string]$Left.state -ceq 'absent') { return $true }
    return [string]$Left.value -ceq [string]$Right.value
}

function ConvertTo-GeneXusDomainNumber {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $number = [decimal]0
    if ([decimal]::TryParse($Value, [System.Globalization.NumberStyles]::Number, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$number)) { return $number }
    return $null
}

function New-GeneXusDomainChange {
    param(
        [Parameter(Mandatory = $true)]$Model,
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)][string]$LocationKind,
        [Parameter(Mandatory = $true)][string]$Container,
        [string]$PartType = '',
        [string]$Component = 'value',
        [string]$EnumStoredValue = '',
        [Parameter(Mandatory = $true)]$OldState,
        [Parameter(Mandatory = $true)]$NewState
    )
    return [pscustomobject]@{
        objectGuid = [string]$Model.guidNormalized
        field = $Field
        locationKind = $LocationKind
        container = $Container
        partType = $PartType
        component = $Component
        enumStoredValue = $EnumStoredValue
        oldState = [string]$OldState.state
        oldValue = $OldState.value
        newState = [string]$NewState.state
        newValue = $NewState.value
    }
}

function Add-GeneXusDomainChangeFinding {
    param(
        [Parameter(Mandatory = $true)]$Change,
        [Parameter(Mandatory = $true)]$Model,
        [Parameter(Mandatory = $true)][System.Collections.Generic.Dictionary[string, object]]$ApprovalsByKey,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$UsedApprovalKeys,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Findings,
        [switch]$ForceBlock,
        [string]$ForcedCode = '',
        [string]$ForcedMessage = ''
    )
    $approvalKey = Get-GeneXusDomainApprovalKey -Approval $Change
    $hasApproval = $ApprovalsByKey.ContainsKey($approvalKey)
    $allowedField = $Change.field -cin $script:GeneXusDomainConditionalFields
    $blockedField = $Change.field -cin $script:GeneXusDomainAlwaysBlockedFields
    $sizeField = $Change.locationKind -ceq 'property' -and $Change.field -cin @('Length', 'AttMaxLen')
    $classification = 'blocked'
    $blockReason = 'mudança fora da matriz aprovada para liberação condicional'
    if ($sizeField) {
        if ($Change.oldState -cne 'value' -or $Change.newState -cne 'value') {
            $blockReason = 'mudança de estado de tamanho sem valores numéricos comparáveis'
        } else {
            $oldNumber = ConvertTo-GeneXusDomainNumber -Value ([string]$Change.oldValue)
            $newNumber = ConvertTo-GeneXusDomainNumber -Value ([string]$Change.newValue)
            if ($null -eq $oldNumber -or $null -eq $newNumber) {
                $blockReason = 'tamanho inválido ou não numérico'
            } elseif ($newNumber -lt $oldNumber) {
                $ForcedCode = 'domain-size-reduction'
                $blockReason = 'redução de capacidade bloqueada para evitar perda de dados persistidos'
            } else {
                $allowedField = $true
                $blockReason = 'aumento de capacidade exige aprovação específica após fanout e SQL exatos'
            }
        }
    } elseif ($blockedField) {
        $blockReason = 'alteração bloqueada pela matriz de segurança Domain'
    } elseif ($Change.field -ceq 'IDEnumDefinedValues') {
        $allowedField = $true
        $blockReason = 'mudança de enumeração exige confirmação pontual e revisão de compatibilidade'
    } elseif ($Change.locationKind -ceq 'rootAttribute' -and $Change.field -cin @('name', 'fullyQualifiedName', 'moduleGuid', 'parentGuid', 'description')) {
        $allowedField = $true
        $blockReason = 'metadado de identidade exige revisão e confirmação pontual'
    }
    if ($ForceBlock) {
        $allowedField = $false
        $classification = 'blocked'
        $blockReason = $ForcedMessage
    } elseif ($allowedField) {
        $classification = 'conditional'
    }

    if ($hasApproval) { [void]$UsedApprovalKeys.Add($approvalKey) }
    if ($classification -eq 'blocked') {
        $code = if (-not [string]::IsNullOrWhiteSpace($ForcedCode)) { $ForcedCode } elseif ($sizeField -and $blockReason.StartsWith('redução')) { 'domain-size-reduction' } elseif ($blockedField) { 'domain-change-always-blocked' } else { 'domain-change-blocked' }
        $changeText = "Domain '$($Model.name)' mudou $($Change.field) em $($Change.locationKind)/$($Change.container): '$($Change.oldValue)' -> '$($Change.newValue)'. $blockReason."
        $Findings.Add((New-GeneXusDomainFinding -Code $code -Message $changeText -ObjectName $Model.name -ObjectGuid $Model.guidNormalized -ObjectFile $Model.relativePath -AcervoPath ([string]$Model.acervoPath) -ExtraFields @{ domainChange = $Change; approvalSupplied = $hasApproval })) | Out-Null
        if ($hasApproval) {
            $Findings.Add((New-GeneXusDomainFinding -Code 'domain-approval-blocked-change' -Message "A aprovação fornecida não pode liberar a mudança bloqueada de '$($Change.field)' no Domain '$($Model.name)'." -ObjectName $Model.name -ObjectGuid $Model.guidNormalized -ObjectFile $Model.relativePath -AcervoPath ([string]$Model.acervoPath) -ExtraFields @{ domainChange = $Change })) | Out-Null
        }
        return
    }

    if (-not $hasApproval) {
        $Findings.Add((New-GeneXusDomainFinding -Code 'domain-change-requires-confirmation' -Message "Domain '$($Model.name)' mudou $($Change.field) em $($Change.locationKind)/$($Change.container): confirmação pontual e evidência manual são necessárias antes de preparar o pacote." -ObjectName $Model.name -ObjectGuid $Model.guidNormalized -ObjectFile $Model.relativePath -AcervoPath ([string]$Model.acervoPath) -ExtraFields @{ domainChange = $Change; requiredApproval = $Change })) | Out-Null
        return
    }

    $Findings.Add((New-Finding -Severity 'info' -Code 'domain-change-approved' -Message "A mudança condicional de $($Change.field) no Domain '$($Model.name)' corresponde à aprovação exata recebida. Evidências externas de referências, SQL, DBMS e Rebuild All continuam sendo responsabilidade da revisão humana." -ObjectName $Model.name -ObjectGuid $Model.guidNormalized -ObjectFile $Model.relativePath -AcervoFile ([string]$Model.acervoPath) -AcervoPath ([string]$Model.acervoPath) -FrontLastUpdate '' -AcervoLastUpdate '' -MatchBasis 'domain-guid' -ExtraFields @{ domainChange = $Change; approval = $ApprovalsByKey[$approvalKey] })) | Out-Null
}

function Get-GeneXusDomainContainerKey {
    param([Parameter(Mandatory = $true)]$Observation)
    return ConvertTo-Json -InputObject @([string]$Observation.container, [string]$Observation.partType) -Compress
}

function Get-GeneXusDomainEnumRowKey {
    param([Parameter(Mandatory = $true)]$Row)
    return ConvertTo-Json -InputObject @([string]$Row.storedValue, [string]$Row.identifier, [string]$Row.description) -Compress
}

function Compare-GeneXusDomainEnum {
    param(
        [Parameter(Mandatory = $true)]$FrontObservation,
        [Parameter(Mandatory = $true)]$AcervoObservation,
        [Parameter(Mandatory = $true)]$FrontModel,
        [Parameter(Mandatory = $true)][System.Collections.Generic.Dictionary[string, object]]$ApprovalsByKey,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$UsedApprovalKeys,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Findings
    )

    if ($FrontObservation.state -ceq 'absent' -or $AcervoObservation.state -ceq 'absent') {
        $oldText = if ($AcervoObservation.state -ceq 'absent') { '' } else { [string]$AcervoObservation.value }
        $newText = if ($FrontObservation.state -ceq 'absent') { '' } else { [string]$FrontObservation.value }
        $oldParsed = ConvertFrom-GeneXusDomainEnum -Text $oldText
        $newParsed = ConvertFrom-GeneXusDomainEnum -Text $newText
        if (-not $oldParsed.valid -or -not $newParsed.valid) {
            $Findings.Add((New-GeneXusDomainFinding -Code 'domain-enumeration-invalid' -Message "Enumeração de '$($FrontModel.name)' inválida: $($oldParsed.reason) $($newParsed.reason)" -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $FrontModel.acervoPath)) | Out-Null
            return
        }
        if ($AcervoObservation.state -ne $FrontObservation.state -and $oldParsed.rows.Count -eq 0 -and $newParsed.rows.Count -eq 0) {
            $change = New-GeneXusDomainChange -Model $FrontModel -Field 'IDEnumDefinedValues' -LocationKind 'property' -Container $FrontObservation.container -PartType $FrontObservation.partType -Component 'value' -OldState $AcervoObservation -NewState $FrontObservation
            Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings -ForceBlock -ForcedCode 'domain-enumeration-state-change' -ForcedMessage 'a representação ausente/vazia da enumeração mudou sem semântica comprovada'
        }
    }

    $oldText = if ($AcervoObservation.state -eq 'absent') { '' } else { [string]$AcervoObservation.value }
    $newText = if ($FrontObservation.state -eq 'absent') { '' } else { [string]$FrontObservation.value }
    $oldParsed = ConvertFrom-GeneXusDomainEnum -Text $oldText
    $newParsed = ConvertFrom-GeneXusDomainEnum -Text $newText
    if (-not $oldParsed.valid -or -not $newParsed.valid) {
        $reason = @($oldParsed.reason, $newParsed.reason) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        $reason = @($reason) -join '; '
        $Findings.Add((New-GeneXusDomainFinding -Code 'domain-enumeration-invalid' -Message "Enumeração de '$($FrontModel.name)' inválida: $reason" -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $FrontModel.acervoPath)) | Out-Null
        return
    }

    $baseByStored = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $baseByIdentifier = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $frontByStored = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $frontByIdentifier = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $oldParsed.rows) { $baseByStored.Add([string]$row.storedValue, $row); $baseByIdentifier.Add([string]$row.identifier, $row) }
    foreach ($row in $newParsed.rows) { $frontByStored.Add([string]$row.storedValue, $row); $frontByIdentifier.Add([string]$row.identifier, $row) }

    $otherChanges = $false
    foreach ($stored in $baseByStored.Keys) {
        $oldRow = $baseByStored[$stored]
        if (-not $frontByStored.ContainsKey($stored)) {
            $otherChanges = $true
            $oldState = New-GeneXusDomainValueState -Present $true -Value ([string]$oldRow.storedValue)
            $newState = New-GeneXusDomainValueState -Present $false -Value $null
            $change = New-GeneXusDomainChange -Model $FrontModel -Field 'IDEnumDefinedValues' -LocationKind 'property' -Container $AcervoObservation.container -PartType $AcervoObservation.partType -Component 'remove' -EnumStoredValue ([string]$oldRow.storedValue) -OldState $oldState -NewState $newState
            Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings -ForceBlock -ForcedCode 'domain-enumeration-value-removal' -ForcedMessage 'remoção ou alteração de valor armazenado bloqueia até revisão de consumidores e dados'
            continue
        }

        $newRow = $frontByStored[$stored]
        if ([string]$oldRow.storedValue -cne [string]$newRow.storedValue) {
            $otherChanges = $true
            $oldState = New-GeneXusDomainValueState -Present $true -Value ([string]$oldRow.storedValue)
            $newState = New-GeneXusDomainValueState -Present $true -Value ([string]$newRow.storedValue)
            $change = New-GeneXusDomainChange -Model $FrontModel -Field 'IDEnumDefinedValues' -LocationKind 'property' -Container $AcervoObservation.container -PartType $AcervoObservation.partType -Component 'storedValue' -EnumStoredValue ([string]$oldRow.storedValue) -OldState $oldState -NewState $newState
            Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings -ForceBlock -ForcedCode 'domain-enumeration-value-change' -ForcedMessage 'mudança do valor persistido bloqueia até revisão de consumidores e dados'
            continue
        }

        if ([string]$oldRow.identifier -cne [string]$newRow.identifier) {
            $otherChanges = $true
            $reusedOld = $false
            foreach ($frontRow in $newParsed.rows) {
                if ($frontRow.storedValue -cne $newRow.storedValue -and [string]$frontRow.identifier -ieq [string]$oldRow.identifier) { $reusedOld = $true }
            }
            $newIdentifierPreviouslyUsed = $baseByIdentifier.ContainsKey([string]$newRow.identifier) -and [string]$baseByIdentifier[[string]$newRow.identifier].storedValue -cne [string]$oldRow.storedValue
            $oldState = New-GeneXusDomainValueState -Present $true -Value ([string]$oldRow.identifier)
            $newState = New-GeneXusDomainValueState -Present $true -Value ([string]$newRow.identifier)
            $change = New-GeneXusDomainChange -Model $FrontModel -Field 'IDEnumDefinedValues' -LocationKind 'property' -Container $AcervoObservation.container -PartType $AcervoObservation.partType -Component 'identifier' -EnumStoredValue ([string]$oldRow.storedValue) -OldState $oldState -NewState $newState
            if ($reusedOld -or $newIdentifierPreviouslyUsed) {
                Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings -ForceBlock -ForcedCode 'domain-enumeration-identifier-reuse' -ForcedMessage 'identificador enumerado reutilizado ou ainda associado a outro valor bloqueia a preparação'
            } else {
                Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings
            }
        }

        if ([string]$oldRow.description -cne [string]$newRow.description) {
            $otherChanges = $true
            $oldState = New-GeneXusDomainValueState -Present $true -Value ([string]$oldRow.description)
            $newState = New-GeneXusDomainValueState -Present $true -Value ([string]$newRow.description)
            $change = New-GeneXusDomainChange -Model $FrontModel -Field 'IDEnumDefinedValues' -LocationKind 'property' -Container $AcervoObservation.container -PartType $AcervoObservation.partType -Component 'description' -EnumStoredValue ([string]$oldRow.storedValue) -OldState $oldState -NewState $newState
            Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings
        }
    }

    foreach ($stored in $frontByStored.Keys) {
        if ($baseByStored.ContainsKey($stored)) { continue }
        $otherChanges = $true
        $newRow = $frontByStored[$stored]
        $oldState = New-GeneXusDomainValueState -Present $false -Value $null
        $newState = New-GeneXusDomainValueState -Present $true -Value (ConvertTo-Json -InputObject ([ordered]@{ storedValue = $newRow.storedValue; identifier = $newRow.identifier; description = $newRow.description }) -Compress)
        $change = New-GeneXusDomainChange -Model $FrontModel -Field 'IDEnumDefinedValues' -LocationKind 'property' -Container $FrontObservation.container -PartType $FrontObservation.partType -Component 'add' -EnumStoredValue ([string]$newRow.storedValue) -OldState $oldState -NewState $newState
        if ($baseByIdentifier.ContainsKey([string]$newRow.identifier)) {
            Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings -ForceBlock -ForcedCode 'domain-enumeration-identifier-reuse' -ForcedMessage 'novo valor reutiliza identificador já associado a outro valor armazenado'
        } else {
            Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings
        }
    }

    if (-not $otherChanges -and $oldParsed.rows.Count -eq $newParsed.rows.Count) {
        $oldTokens = @($oldParsed.rows | ForEach-Object { Get-GeneXusDomainEnumRowKey -Row $_ })
        $newTokens = @($newParsed.rows | ForEach-Object { Get-GeneXusDomainEnumRowKey -Row $_ })
        $oldSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $newSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($token in $oldTokens) { [void]$oldSet.Add([string]$token) }
        foreach ($token in $newTokens) { [void]$newSet.Add([string]$token) }
        if ($oldSet.SetEquals($newSet) -and (@($oldTokens) -join "`n") -cne (@($newTokens) -join "`n")) {
            $oldState = New-GeneXusDomainValueState -Present $true -Value (ConvertTo-Json -InputObject @($oldParsed.rows) -Compress -Depth 5)
            $newState = New-GeneXusDomainValueState -Present $true -Value (ConvertTo-Json -InputObject @($newParsed.rows) -Compress -Depth 5)
            $change = New-GeneXusDomainChange -Model $FrontModel -Field 'IDEnumDefinedValues' -LocationKind 'property' -Container $FrontObservation.container -PartType $FrontObservation.partType -Component 'order' -OldState $oldState -NewState $newState
            Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings
        }
    }
}

function Compare-GeneXusDomainPair {
    param(
        [Parameter(Mandatory = $true)]$FrontModel,
        [Parameter(Mandatory = $true)]$AcervoModel,
        [Parameter(Mandatory = $true)][System.Collections.Generic.Dictionary[string, object]]$ApprovalsByKey,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$UsedApprovalKeys,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Findings
    )

    $FrontModel.acervoPath = $AcervoModel.relativePath
    foreach ($model in @($FrontModel, $AcervoModel)) {
        if ($model.errors.Count -gt 0) {
            $Findings.Add((New-GeneXusDomainFinding -Code 'domain-property-structure-invalid' -Message "Domain '$($FrontModel.name)' contém propriedades incompletas ou ambíguas: $($model.errors -join '; ')" -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $AcervoModel.relativePath -ExtraFields @{ source = $(if ($model.path -eq $FrontModel.path) { 'front' } else { 'acervo' }); errors = @($model.errors) })) | Out-Null
            return
        }
        foreach ($observation in $model.observations.Values) {
            if ($observation.duplicate) {
                $Findings.Add((New-GeneXusDomainFinding -Code 'domain-property-duplicate' -Message "Domain '$($FrontModel.name)' repete a propriedade '$($observation.field)' no mesmo container '$($observation.container)' (Part/@type='$($observation.partType)')." -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $AcervoModel.relativePath -ExtraFields @{ field = $observation.field; container = $observation.container; partType = $observation.partType })) | Out-Null
                return
            }
        }
    }

    $frontNameKey = Get-GeneXusDomainObservationKey -LocationKind 'property' -Container 'Object/Properties' -PartType '' -Field 'Name'
    foreach ($model in @($FrontModel, $AcervoModel)) {
        $rootName = $model.attributes['name']
        if ($rootName.state -eq 'absent' -or $rootName.state -eq 'empty' -or -not $model.observations.ContainsKey($frontNameKey)) {
            $Findings.Add((New-GeneXusDomainFinding -Code 'domain-root-name-incomplete' -Message "Domain '$($FrontModel.name)' não apresenta identidade Name completa na raiz e em Object/Properties." -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $AcervoModel.relativePath)) | Out-Null
            return
        }
        $propertyName = $model.observations[$frontNameKey]
        if ($propertyName.state -eq 'absent' -or $propertyName.state -eq 'empty' -or $propertyName.state -cne $rootName.state -or [string]$propertyName.value -cne [string]$rootName.value) {
            $Findings.Add((New-GeneXusDomainFinding -Code 'domain-root-name-mismatch' -Message "Object/@name e a propriedade Name divergem no Domain '$($FrontModel.name)'; identidade ambígua bloqueia a preparação." -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $AcervoModel.relativePath)) | Out-Null
            return
        }
    }

    $frontDescriptionKey = Get-GeneXusDomainObservationKey -LocationKind 'property' -Container 'Object/Properties' -PartType '' -Field 'Description'
    foreach ($model in @($FrontModel, $AcervoModel)) {
        $rootDescription = $model.attributes['description']
        $propertyDescription = if ($model.observations.ContainsKey($frontDescriptionKey)) { $model.observations[$frontDescriptionKey] } else { New-GeneXusDomainValueState -Present $false -Value $null }
        if ($rootDescription.state -ne 'absent' -and $propertyDescription.state -ne 'absent' -and ($rootDescription.state -cne $propertyDescription.state -or [string]$rootDescription.value -cne [string]$propertyDescription.value)) {
            $Findings.Add((New-GeneXusDomainFinding -Code 'domain-description-representation-mismatch' -Message "Object/@description e a propriedade Description divergem no Domain '$($FrontModel.name)'; representação ambígua bloqueia a preparação." -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $AcervoModel.relativePath)) | Out-Null
            return
        }
    }

    $baseDescriptionLocations = @(
        ('root=' + [string]($AcervoModel.attributes['description'].state -cne 'absent')),
        ('property=' + [string]$AcervoModel.observations.ContainsKey($frontDescriptionKey))
    )
    $frontDescriptionLocations = @(
        ('root=' + [string]($FrontModel.attributes['description'].state -cne 'absent')),
        ('property=' + [string]$FrontModel.observations.ContainsKey($frontDescriptionKey))
    )
    $baseHasDescription = ($AcervoModel.attributes['description'].state -cne 'absent') -or $AcervoModel.observations.ContainsKey($frontDescriptionKey)
    $frontHasDescription = ($FrontModel.attributes['description'].state -cne 'absent') -or $FrontModel.observations.ContainsKey($frontDescriptionKey)
    if ($baseHasDescription -and $frontHasDescription -and (@($baseDescriptionLocations) -join '|') -cne (@($frontDescriptionLocations) -join '|')) {
        $Findings.Add((New-GeneXusDomainFinding -Code 'domain-description-location-changed' -Message "A representação de Description mudou de localização no Domain '$($FrontModel.name)'; a diferença deve ser resolvida manualmente." -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $AcervoModel.relativePath)) | Out-Null
    }

    $baseContainers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $frontContainers = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($observation in $AcervoModel.observations.Values) { [void]$baseContainers.Add((Get-GeneXusDomainContainerKey -Observation $observation)) }
    foreach ($observation in $FrontModel.observations.Values) { [void]$frontContainers.Add((Get-GeneXusDomainContainerKey -Observation $observation)) }
    foreach ($observation in $FrontModel.observations.Values) {
        $containerKey = Get-GeneXusDomainContainerKey -Observation $observation
        if (-not $baseContainers.Contains($containerKey)) {
            $Findings.Add((New-GeneXusDomainFinding -Code 'domain-property-container-new' -Message "Domain '$($FrontModel.name)' introduziu propriedades no container não observado na baseline: $($observation.container), Part/@type='$($observation.partType)'." -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $AcervoModel.relativePath -ExtraFields @{ container = $observation.container; partType = $observation.partType })) | Out-Null
            break
        }
    }

    $baseLocationsByField = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.HashSet[string]]]::new([System.StringComparer]::Ordinal)
    $frontLocationsByField = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.HashSet[string]]]::new([System.StringComparer]::Ordinal)
    foreach ($pair in @(@($AcervoModel.observations, $baseLocationsByField), @($FrontModel.observations, $frontLocationsByField))) {
        $source = $pair[0]
        $target = $pair[1]
        foreach ($observation in $source.Values) {
            $field = [string]$observation.field
            if (-not $target.ContainsKey($field)) { $target[$field] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal) }
            [void]$target[$field].Add((Get-GeneXusDomainContainerKey -Observation $observation))
        }
    }
    $movedFields = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($field in $baseLocationsByField.Keys) {
        if (-not $frontLocationsByField.ContainsKey($field)) { continue }
        if (-not $baseLocationsByField[$field].SetEquals($frontLocationsByField[$field])) {
            [void]$movedFields.Add($field)
            $Findings.Add((New-GeneXusDomainFinding -Code 'domain-property-container-changed' -Message "A propriedade '$field' mudou de container ou Part/@type no Domain '$($FrontModel.name)'; a comparação por localização não pode ser aprovada automaticamente." -ObjectName $FrontModel.name -ObjectGuid $FrontModel.guidNormalized -ObjectFile $FrontModel.relativePath -AcervoPath $AcervoModel.relativePath -ExtraFields @{ field = $field })) | Out-Null
        }
    }

    foreach ($field in @('name', 'fullyQualifiedName', 'moduleGuid', 'parentGuid', 'description')) {
        $oldState = $AcervoModel.attributes[$field]
        $newState = $FrontModel.attributes[$field]
        if (Test-GeneXusDomainStatesEqual -Left $oldState -Right $newState) { continue }
        $change = New-GeneXusDomainChange -Model $FrontModel -Field $field -LocationKind 'rootAttribute' -Container 'Object' -OldState $oldState -NewState $newState
        $force = ($field -ceq 'description' -and $baseHasDescription -and $frontHasDescription -and (@($baseDescriptionLocations) -join '|') -cne (@($frontDescriptionLocations) -join '|'))
        Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings -ForceBlock:$force -ForcedCode 'domain-description-location-changed' -ForcedMessage 'mudança de localização da representação de Description bloqueia a aprovação'
    }

    $allObservationKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($key in $AcervoModel.observations.Keys) { [void]$allObservationKeys.Add($key) }
    foreach ($key in $FrontModel.observations.Keys) { [void]$allObservationKeys.Add($key) }
    foreach ($key in $allObservationKeys) {
        $oldObservation = if ($AcervoModel.observations.ContainsKey($key)) { $AcervoModel.observations[$key] } else { $null }
        $newObservation = if ($FrontModel.observations.ContainsKey($key)) { $FrontModel.observations[$key] } else { $null }
        $observation = if ($null -ne $newObservation) { $newObservation } else { $oldObservation }
        $oldState = if ($null -ne $oldObservation) { [pscustomobject]@{ state = $oldObservation.state; value = $oldObservation.value } } else { New-GeneXusDomainValueState -Present $false -Value $null }
        $newState = if ($null -ne $newObservation) { [pscustomobject]@{ state = $newObservation.state; value = $newObservation.value } } else { New-GeneXusDomainValueState -Present $false -Value $null }

        if ([string]$observation.field -ceq 'IDEnumDefinedValues') {
            if (-not (Test-GeneXusDomainStatesEqual -Left $oldState -Right $newState)) {
                if ($null -eq $oldObservation) { $oldObservation = [pscustomobject]@{ state = 'absent'; value = $null; container = $observation.container; partType = $observation.partType } }
                if ($null -eq $newObservation) { $newObservation = [pscustomobject]@{ state = 'absent'; value = $null; container = $observation.container; partType = $observation.partType } }
                Compare-GeneXusDomainEnum -FrontObservation $newObservation -AcervoObservation $oldObservation -FrontModel $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings
            }
            continue
        }

        $equal = Test-GeneXusDomainStatesEqual -Left $oldState -Right $newState
        if ($observation.field -cin @('Length', 'AttMaxLen') -and $oldState.state -ceq 'value' -and $newState.state -ceq 'value') {
            $oldNumber = ConvertTo-GeneXusDomainNumber -Value ([string]$oldState.value)
            $newNumber = ConvertTo-GeneXusDomainNumber -Value ([string]$newState.value)
            if ($null -ne $oldNumber -and $null -ne $newNumber -and $oldNumber -eq $newNumber) { $equal = $true }
        }
        if ($equal) { continue }
        $change = New-GeneXusDomainChange -Model $FrontModel -Field ([string]$observation.field) -LocationKind 'property' -Container ([string]$observation.container) -PartType ([string]$observation.partType) -OldState $oldState -NewState $newState
        $force = $movedFields.Contains([string]$observation.field) -or (-not $baseContainers.Contains((Get-GeneXusDomainContainerKey -Observation $observation)))
        $forceCode = if ($force -and $movedFields.Contains([string]$observation.field)) { 'domain-property-container-changed' } elseif ($force) { 'domain-property-container-new' } else { '' }
        Add-GeneXusDomainChangeFinding -Change $change -Model $FrontModel -ApprovalsByKey $ApprovalsByKey -UsedApprovalKeys $UsedApprovalKeys -Findings $Findings -ForceBlock:$force -ForcedCode $forceCode -ForcedMessage 'propriedade em container novo ou alterado bloqueia aprovação'
    }
}

function Invoke-GeneXusDomainDriftClassifier {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ObjectXmlPaths,
        [Parameter(Mandatory = $true)][string]$AcervoRootPath,
        [AllowNull()][string]$FrontRootPath,
        [AllowNull()][string]$ApprovedDomainChangesPath,
        [bool]$ApprovedDomainChangesPathSupplied = $false,
        [Parameter(Mandatory = $true)][string]$CatalogPath,
        [switch]$DetectNestedDomainRoots
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $byPath = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $domainCandidates = [System.Collections.Generic.List[object]]::new()
    $approvalRead = Read-GeneXusDomainApprovals -Path $ApprovedDomainChangesPath -WasSupplied $ApprovedDomainChangesPathSupplied
    $approvalsByKey = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $usedApprovalKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $identity = Resolve-GeneXusDomainTypeIdentity -CatalogPath $CatalogPath
    $canonicalTypeGuid = $script:GeneXusDomainCanonicalTypeGuid
    if ($approvalRead.valid) {
        foreach ($approval in $approvalRead.approvals) {
            $approvalsByKey.Add((Get-GeneXusDomainApprovalKey -Approval $approval), $approval)
        }
    }

    if (-not $approvalRead.valid) {
        $findings.Add((New-GeneXusDomainFinding -Code 'domain-approval-envelope-invalid' -Message "Arquivo de aprovações Domain inválido: $($approvalRead.reason)." -ObjectName '' -ObjectGuid '' -ObjectFile '' -ExtraFields @{ approvalPath = $ApprovedDomainChangesPath })) | Out-Null
    }

    $uniqueDomainPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($inputPath in $ObjectXmlPaths) {
        if ([string]::IsNullOrWhiteSpace($inputPath)) { continue }
        $fullPath = [System.IO.Path]::GetFullPath($inputPath)
        $read = Read-GeneXusDomainXml -Path $fullPath
        if ($null -eq $read.document) { continue }
        $root = $read.document.DocumentElement
        if ($null -eq $root) { continue }
        if ($root.LocalName -cne 'Object') {
            if ($DetectNestedDomainRoots) {
                foreach ($nestedRoot in @($read.document.SelectNodes("//*[local-name()='Object']"))) {
                    if (-not (Test-GeneXusDomainTypeGuid -Value $nestedRoot.GetAttribute('type') -Identity $identity)) { continue }
                    $nestedName = $nestedRoot.GetAttribute('name')
                    $nestedGuid = ConvertTo-GeneXusDomainGuid -Value $nestedRoot.GetAttribute('guid')
                    $relative = if (-not [string]::IsNullOrWhiteSpace($FrontRootPath)) { [System.IO.Path]::GetRelativePath($FrontRootPath, $fullPath).Replace('\', '/') } else { $fullPath }
                    $findings.Add((New-GeneXusDomainFinding -Code 'domain-nested-root-unsupported' -Message "A entrada '$relative' tem raiz '$($root.LocalName)' e contém Domain '$nestedName' reconhecível aninhado; a rota aceita somente um objeto Object autônomo e não pode ignorá-lo." -ObjectName $nestedName -ObjectGuid $nestedGuid -ObjectFile $relative -ExtraFields @{ rootName = $root.LocalName; nestedObjectName = $nestedName })) | Out-Null
                }
            }
            continue
        }
        if (-not (Test-GeneXusDomainTypeGuid -Value $root.GetAttribute('type') -Identity $identity)) { continue }
        if (-not $uniqueDomainPaths.Add($fullPath)) {
            $findings.Add((New-GeneXusDomainFinding -Code 'domain-input-duplicate-path' -Message "O mesmo XML Domain foi informado mais de uma vez na entrada: $fullPath." -ObjectName '' -ObjectGuid '' -ObjectFile $fullPath)) | Out-Null
            continue
        }
        $model = Get-GeneXusDomainObjectModel -Document $read.document -Path $fullPath -RootPath $(if (-not [string]::IsNullOrWhiteSpace($FrontRootPath)) { $FrontRootPath } else { Split-Path -Parent $fullPath })
        $domainCandidates.Add($model) | Out-Null
    }

    $domainCount = $domainCandidates.Count
    if ($domainCount -eq 0) {
        foreach ($approval in $approvalRead.approvals) {
            $findings.Add((New-GeneXusDomainFinding -Code 'domain-approval-unmatched' -Message "A aprovação de $($approval.field) para o Domain $($approval.objectGuid) não corresponde a uma diferença desta entrada." -ObjectName '' -ObjectGuid $approval.objectGuid -ObjectFile '' -ExtraFields @{ suppliedApproval = $approval })) | Out-Null
        }
        return [pscustomobject]@{ domainsScanned = 0; findings = @($findings.ToArray()); byPath = $byPath; typeIdentitySource = $identity.source; typeIdentityReason = $identity.reason }
    }

    foreach ($candidate in $domainCandidates) {
        $byPath[[System.IO.Path]::GetFullPath($candidate.path)] = [pscustomobject]@{ state = 'pending'; baseline = $null }
    }

    $directComplete = $true
    $directIssues = [System.Collections.Generic.List[string]]::new()
    $directByGuid = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::Ordinal)
    $directModels = [System.Collections.Generic.List[object]]::new()
    $domainNameKey = Get-GeneXusDomainObservationKey -LocationKind 'property' -Container 'Object/Properties' -PartType '' -Field 'Name'
    $domainFolder = Join-Path $AcervoRootPath 'Domain'
    if (-not (Test-Path -LiteralPath $domainFolder -PathType Container)) {
        $directComplete = $false
        $directIssues.Add('pasta direta Domain/ ausente') | Out-Null
    } else {
        try {
            $directFiles = @(Get-ChildItem -LiteralPath $domainFolder -File -Filter '*.xml' -ErrorAction Stop | Sort-Object FullName)
        } catch {
            $directFiles = @()
            $directComplete = $false
            $directIssues.Add("falha ao enumerar Domain/: $($_.Exception.Message)") | Out-Null
        }
        foreach ($file in $directFiles) {
            $read = Read-GeneXusDomainXml -Path $file.FullName
            if ($null -eq $read.document) {
                $directComplete = $false
                $directIssues.Add("XML ilegível em Domain/: $($file.Name)") | Out-Null
                continue
            }
            $root = $read.document.DocumentElement
            if ($null -eq $root -or $root.LocalName -cne 'Object' -or -not (Test-GeneXusDomainTypeGuid -Value $root.GetAttribute('type') -Identity $identity)) {
                $directComplete = $false
                $directIssues.Add("raiz/tipo inesperado em Domain/: $($file.Name)") | Out-Null
                continue
            }
            $model = Get-GeneXusDomainObjectModel -Document $read.document -Path $file.FullName -RootPath $AcervoRootPath
            $modelName = if ($model.observations.ContainsKey($domainNameKey)) { $model.observations[$domainNameKey] } else { $null }
            $baselineIdentityInvalid = [string]::IsNullOrWhiteSpace($model.guidNormalized) -or
                $model.rootNameState.state -in @('absent', 'empty') -or
                $null -eq $modelName -or
                $modelName.state -in @('absent', 'empty') -or
                [string]$model.root.GetAttribute('name') -cne [string]$modelName.value -or
                $model.errors.Count -gt 0
            if ($baselineIdentityInvalid) {
                $directComplete = $false
                $directIssues.Add("identidade/estrutura inválida em Domain/: $($file.Name)") | Out-Null
            }
            if (-not $directByGuid.ContainsKey($model.guidNormalized)) { $directByGuid[$model.guidNormalized] = [System.Collections.Generic.List[object]]::new() }
            $directByGuid[$model.guidNormalized].Add($model) | Out-Null
            $directModels.Add($model) | Out-Null
        }
    }

    $globalComplete = $true
    $globalIssues = [System.Collections.Generic.List[string]]::new()
    $embeddedComplete = $true
    $embeddedIssues = [System.Collections.Generic.List[string]]::new()
    $globalByGuid = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::Ordinal)
    $embeddedDomainGuids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    try {
        $globalFiles = @(Get-ChildItem -LiteralPath $AcervoRootPath -Recurse -File -Filter '*.xml' -ErrorAction Stop | Sort-Object FullName)
    } catch {
        $globalFiles = @()
        $globalComplete = $false
        $globalIssues.Add("falha ao enumerar índice global Object: $($_.Exception.Message)") | Out-Null
    }
    foreach ($file in $globalFiles) {
        $read = Read-GeneXusDomainXml -Path $file.FullName
        if ($null -eq $read.document) {
            $globalComplete = $false
            $globalIssues.Add("XML ilegível no índice global: $([System.IO.Path]::GetRelativePath($AcervoRootPath, $file.FullName).Replace('\', '/'))") | Out-Null
            continue
        }
        $root = $read.document.DocumentElement
        if ($null -eq $root) { continue }
        if ($root.LocalName -ceq 'Object') {
            $guid = ConvertTo-GeneXusDomainGuid -Value $root.GetAttribute('guid')
            if ([string]::IsNullOrWhiteSpace($guid)) {
                $globalComplete = $false
                $globalIssues.Add("Object sem GUID válido no índice global: $([System.IO.Path]::GetRelativePath($AcervoRootPath, $file.FullName).Replace('\', '/'))") | Out-Null
                continue
            }
            if (-not $globalByGuid.ContainsKey($guid)) { $globalByGuid[$guid] = [System.Collections.Generic.List[object]]::new() }
            $globalByGuid[$guid].Add([pscustomobject]@{
                fullPath = $file.FullName
                relativePath = [System.IO.Path]::GetRelativePath($AcervoRootPath, $file.FullName).Replace('\', '/')
                typeGuid = ConvertTo-GeneXusDomainGuid -Value $root.GetAttribute('type')
                typeRaw = $root.GetAttribute('type')
            }) | Out-Null
        } elseif ($root.LocalName -ceq 'PackagedModule') {
            foreach ($nestedRoot in @($read.document.SelectNodes("//*[local-name()='Object']"))) {
                if (-not (Test-GeneXusDomainTypeGuid -Value $nestedRoot.GetAttribute('type') -Identity $identity)) { continue }
                $guid = ConvertTo-GeneXusDomainGuid -Value $nestedRoot.GetAttribute('guid')
                if (-not [string]::IsNullOrWhiteSpace($guid)) {
                    [void]$embeddedDomainGuids.Add($guid)
                } else {
                    $embeddedComplete = $false
                    $embeddedIssues.Add("Domain embutido sem GUID válido em PackagedModule: $([System.IO.Path]::GetRelativePath($AcervoRootPath, $file.FullName).Replace('\', '/'))") | Out-Null
                }
            }
        }
    }

    $frontByGuid = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[object]]]::new([System.StringComparer]::Ordinal)
    foreach ($candidate in $domainCandidates) {
        if ([string]::IsNullOrWhiteSpace($candidate.guidNormalized)) { continue }
        if (-not $frontByGuid.ContainsKey($candidate.guidNormalized)) { $frontByGuid[$candidate.guidNormalized] = [System.Collections.Generic.List[object]]::new() }
        $frontByGuid[$candidate.guidNormalized].Add($candidate) | Out-Null
    }

    foreach ($candidate in $domainCandidates) {
        $candidateKey = [System.IO.Path]::GetFullPath($candidate.path)
        $candidateState = [pscustomobject]@{ state = 'blocked'; baseline = $null }
        $candidateRelative = $candidate.relativePath
        if ([string]::IsNullOrWhiteSpace($candidate.guidNormalized)) {
            $findings.Add((New-GeneXusDomainFinding -Code 'front-domain-identity-invalid' -Message "Domain '$($candidate.name)' tem GUID ausente, inválido ou zero; não pode ser comparado nem classificado como novo." -ObjectName $candidate.name -ObjectGuid '' -ObjectFile $candidateRelative)) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }
        if ($null -ne $frontByGuid[$candidate.guidNormalized] -and $frontByGuid[$candidate.guidNormalized].Count -gt 1) {
            $findings.Add((New-GeneXusDomainFinding -Code 'front-domain-guid-duplicate' -Message "GUID do Domain '$($candidate.name)' aparece em mais de um XML da frente; identidade ambígua bloqueia a comparação." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ frontPaths = @($frontByGuid[$candidate.guidNormalized] | ForEach-Object { $_.relativePath }) })) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }
        if ($identity.inconsistent) {
            $findings.Add((New-GeneXusDomainFinding -Code 'domain-catalog-inconsistent' -Message 'O GUID válido de Domain no catálogo compartilhado diverge do GUID canônico aprovado; o fallback não pode mascarar essa divergência.' -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ catalogReason = $identity.reason; catalogPath = $CatalogPath })) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }
        if ($candidate.errors.Count -gt 0) {
            $findings.Add((New-GeneXusDomainFinding -Code 'front-domain-structure-invalid' -Message "Domain '$($candidate.name)' contém estrutura de propriedades incompleta ou ambígua: $($candidate.errors -join '; ')." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ errors = @($candidate.errors) })) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }
        $namePropertyKey = Get-GeneXusDomainObservationKey -LocationKind 'property' -Container 'Object/Properties' -PartType '' -Field 'Name'
        if ($candidate.rootNameState.state -in @('absent', 'empty') -or -not $candidate.observations.ContainsKey($namePropertyKey)) {
            $findings.Add((New-GeneXusDomainFinding -Code 'domain-root-name-incomplete' -Message "Domain '$($candidate.name)' não tem Object/@name e propriedade Name completos; permanece reconhecido pelo tipo, mas não pode ser comparado nem classificado como novo." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative)) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }
        $nameProperty = $candidate.observations[$namePropertyKey]
        if ($nameProperty.state -in @('absent', 'empty') -or [string]$candidate.rootNameState.value -cne [string]$nameProperty.value) {
            $findings.Add((New-GeneXusDomainFinding -Code 'domain-root-name-mismatch' -Message "Object/@name e a propriedade Name divergem no Domain '$($candidate.name)'; identidade ambígua bloqueia a preparação." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative)) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }
        if (-not $directComplete -or -not $globalComplete) {
            $findings.Add((New-GeneXusDomainFinding -Code 'domain-baseline-incomplete' -Message "Não foi possível provar a identidade/baseline necessária para o Domain '$($candidate.name)'; classificação bloqueada. Escopos incompletos: $(@($directIssues.ToArray() + $globalIssues.ToArray()) -join '; ')." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ directDomainIssues = @($directIssues.ToArray()); globalObjectIndexIssues = @($globalIssues.ToArray()) })) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }

        if ($directByGuid.ContainsKey($candidate.guidNormalized)) { $baseMatches = @($directByGuid[$candidate.guidNormalized].ToArray()) } else { $baseMatches = @() }
        if ($globalByGuid.ContainsKey($candidate.guidNormalized)) { $globalMatches = @($globalByGuid[$candidate.guidNormalized].ToArray()) } else { $globalMatches = @() }
        if ($baseMatches.Count -gt 1) {
            $findings.Add((New-GeneXusDomainFinding -Code 'domain-acervo-guid-ambiguous' -Message "GUID do Domain '$($candidate.name)' aparece em múltiplos XMLs na pasta direta Domain/ do acervo." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ candidateAcervoPaths = @($baseMatches | ForEach-Object { $_.relativePath }) })) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }

        if ($globalMatches.Count -gt 0) {
            $globalTypes = @($globalMatches | ForEach-Object { $_.typeGuid } | Sort-Object -Unique)
            if (@($globalMatches | Where-Object { $_.typeGuid -cne $canonicalTypeGuid }).Count -gt 0) {
                $findings.Add((New-GeneXusDomainFinding -Code 'front-domain-object-type-drift' -Message "GUID do Domain '$($candidate.name)' está associado a outro Object/@type no acervo; a mudança de tipo bloqueia a preparação." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ acervoMatches = @($globalMatches | ForEach-Object { $_.relativePath }); acervoTypes = $globalTypes })) | Out-Null
                $byPath[$candidateKey] = $candidateState
                continue
            }
            if ($baseMatches.Count -eq 0 -or $globalMatches.Count -ne 1 -or [System.IO.Path]::GetFullPath($globalMatches[0].fullPath) -ine [System.IO.Path]::GetFullPath($baseMatches[0].path)) {
                $findings.Add((New-GeneXusDomainFinding -Code 'front-domain-identity-collision' -Message "GUID do Domain '$($candidate.name)' aparece fora de um pareamento único na pasta direta Domain/; não pode ser tratado como objeto novo ou comparado com segurança." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ acervoMatches = @($globalMatches | ForEach-Object { $_.relativePath }) })) | Out-Null
                $byPath[$candidateKey] = $candidateState
                continue
            }
        }

        $candidateName = [string]$candidate.root.GetAttribute('name')
        $candidateFqn = [string]$candidate.root.GetAttribute('fullyQualifiedName')
        $matchedBaseline = if ($baseMatches.Count -eq 1) { $baseMatches[0] } else { $null }
        $identityChanged = $null -eq $matchedBaseline -or
            $candidateName -cne [string]$matchedBaseline.root.GetAttribute('name') -or
            $candidateFqn -cne [string]$matchedBaseline.root.GetAttribute('fullyQualifiedName')
        if ($identityChanged) {
            $conflicts = [System.Collections.Generic.List[object]]::new()
            foreach ($baseModel in $directModels) {
                if ($baseModel.guidNormalized -ceq $candidate.guidNormalized) { continue }
                $peerName = [string]$baseModel.root.GetAttribute('name')
                $peerFqn = [string]$baseModel.root.GetAttribute('fullyQualifiedName')
                if ($frontByGuid.ContainsKey($baseModel.guidNormalized) -and $frontByGuid[$baseModel.guidNormalized].Count -eq 1) {
                    $frontPeer = $frontByGuid[$baseModel.guidNormalized][0]
                    $peerName = [string]$frontPeer.root.GetAttribute('name')
                    $peerFqn = [string]$frontPeer.root.GetAttribute('fullyQualifiedName')
                }
                $sameName = -not [string]::IsNullOrWhiteSpace($candidateName) -and -not [string]::IsNullOrWhiteSpace($peerName) -and $candidateName -ieq $peerName
                $sameFqn = -not [string]::IsNullOrWhiteSpace($candidateFqn) -and -not [string]::IsNullOrWhiteSpace($peerFqn) -and $candidateFqn -ieq $peerFqn
                if ($sameName -or $sameFqn) { $conflicts.Add([pscustomobject]@{ guid = $baseModel.guidNormalized; name = $peerName; fullyQualifiedName = $peerFqn; path = $baseModel.relativePath }) | Out-Null }
            }
            foreach ($frontPeer in $domainCandidates) {
                if ($frontPeer.guidNormalized -ceq $candidate.guidNormalized -or $directByGuid.ContainsKey($frontPeer.guidNormalized)) { continue }
                $peerName = [string]$frontPeer.root.GetAttribute('name')
                $peerFqn = [string]$frontPeer.root.GetAttribute('fullyQualifiedName')
                $sameName = -not [string]::IsNullOrWhiteSpace($candidateName) -and -not [string]::IsNullOrWhiteSpace($peerName) -and $candidateName -ieq $peerName
                $sameFqn = -not [string]::IsNullOrWhiteSpace($candidateFqn) -and -not [string]::IsNullOrWhiteSpace($peerFqn) -and $candidateFqn -ieq $peerFqn
                if ($sameName -or $sameFqn) { $conflicts.Add([pscustomobject]@{ guid = $frontPeer.guidNormalized; name = $peerName; fullyQualifiedName = $peerFqn; path = $frontPeer.relativePath }) | Out-Null }
            }
            if ($conflicts.Count -gt 0) {
                $findings.Add((New-GeneXusDomainFinding -Code 'front-domain-name-collision' -Message "Domain '$($candidate.name)' tem homônimo ou fullyQualifiedName conflitante com GUID diferente no conjunto final da frente e do acervo; a preparação permanece bloqueada." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ conflictingObjects = @($conflicts.ToArray()) })) | Out-Null
                $byPath[$candidateKey] = $candidateState
                continue
            }
        }

        if ($baseMatches.Count -eq 0) {
            if ($embeddedDomainGuids.Contains($candidate.guidNormalized)) {
                $findings.Add((New-GeneXusDomainFinding -Code 'front-domain-packagedmodule-identity-collision' -Message "GUID do Domain '$($candidate.name)' existe somente embutido em PackagedModule; identidade não comparável bloqueia a classificação como novo." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative)) | Out-Null
                $byPath[$candidateKey] = $candidateState
                continue
            }
            if (-not $embeddedComplete) {
                $findings.Add((New-GeneXusDomainFinding -Code 'domain-embedded-scan-incomplete' -Message "Não foi possível excluir colisão de identidade em PackagedModule para o Domain novo '$($candidate.name)'; classificação bloqueada. Escopos incompletos: $($embeddedIssues -join '; ')." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ embeddedDomainIssues = @($embeddedIssues.ToArray()) })) | Out-Null
                $byPath[$candidateKey] = $candidateState
                continue
            }
            $byPath[$candidateKey] = [pscustomobject]@{ state = 'new'; baseline = $null }
            continue
        }

        $baseline = $baseMatches[0]
        if ($globalMatches.Count -ne 1 -or [System.IO.Path]::GetFullPath($globalMatches[0].fullPath) -ine [System.IO.Path]::GetFullPath($baseline.path)) {
            $findings.Add((New-GeneXusDomainFinding -Code 'front-domain-identity-collision' -Message "GUID do Domain '$($candidate.name)' não tem ocorrência única e alinhada entre o índice global e Domain/ do acervo." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -ExtraFields @{ acervoMatches = @($globalMatches | ForEach-Object { $_.relativePath }) })) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }
        $read = Read-GeneXusDomainXml -Path $baseline.path
        if ($null -eq $read.document) {
            $findings.Add((New-GeneXusDomainFinding -Code 'domain-acervo-unreadable' -Message "XML de baseline do Domain '$($candidate.name)' não pode ser relido após indexação." -ObjectName $candidate.name -ObjectGuid $candidate.guidNormalized -ObjectFile $candidateRelative -AcervoPath $baseline.relativePath)) | Out-Null
            $byPath[$candidateKey] = $candidateState
            continue
        }
        $baselineModel = Get-GeneXusDomainObjectModel -Document $read.document -Path $baseline.path -RootPath $AcervoRootPath
        $byPath[$candidateKey] = [pscustomobject]@{ state = 'matched'; baseline = $baseline.path }
        Compare-GeneXusDomainPair -FrontModel $candidate -AcervoModel $baselineModel -ApprovalsByKey $approvalsByKey -UsedApprovalKeys $usedApprovalKeys -Findings $findings
    }

    foreach ($approval in $approvalRead.approvals) {
        $approvalKey = Get-GeneXusDomainApprovalKey -Approval $approval
        if ($usedApprovalKeys.Contains($approvalKey)) { continue }
        $findings.Add((New-GeneXusDomainFinding -Code 'domain-approval-unmatched' -Message "A aprovação de $($approval.field) para o Domain $($approval.objectGuid) não corresponde a uma diferença exata desta frente; a preparação permanece bloqueada." -ObjectName '' -ObjectGuid $approval.objectGuid -ObjectFile '' -ExtraFields @{ suppliedApproval = $approval })) | Out-Null
    }

    return [pscustomobject]@{
        domainsScanned = $domainCount
        findings = @($findings.ToArray())
        byPath = $byPath
        typeIdentitySource = $identity.source
        typeIdentityReason = $identity.reason
        directBaselineComplete = $directComplete
        globalObjectIndexComplete = $globalComplete
        embeddedDomainScanComplete = $embeddedComplete
    }
}
