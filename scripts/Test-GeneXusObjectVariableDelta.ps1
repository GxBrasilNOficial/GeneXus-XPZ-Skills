#requires -Version 7.4

<#
.SYNOPSIS
    Diagnostica variáveis GeneXus em XML de objeto, com foco em variáveis tocadas pelo delta.

.DESCRIPTION
    Valida a coerência mínima de blocos <Variable> sem reserializar o XML.
    Quando -VariableName e informado, trata essas variáveis como o delta da rodada
    e aplica checks mais fortes. Sem -VariableName, faz varredura consultiva do
    objeto inteiro para orientar revisao sem reprovar formas legadas raras.

.PARAMETER InputPath
    XML de objeto GeneXus.

.PARAMETER VariableName
    Uma ou mais variáveis declaradas como novas ou tocadas no delta.

.PARAMETER AllowShapeOnlyType
    Para variáveis do delta, aceita forma sem idBasedOn/ATTCUSTOMTYPE quando
    houver propriedades estruturais de tipo base (Length, AttMaxLen, Decimals,
    ATT_PICTURE ou Signed). Por padrão, essa forma gera fail no delta.

.PARAMETER AsJson
    Saida estruturada JSON.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [Alias('Path')]
    [string]$InputPath,

    [string[]]$VariableName = @(),

    [switch]$AllowShapeOnlyType,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Finding {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('fail', 'warn', 'info')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Variable,

        [string]$TypeEvidence,

        [string[]]$Properties = @()
    )

    return [pscustomobject]@{
        severity     = $Severity
        code         = $Code
        message      = $Message
        variable     = $Variable
        typeEvidence = $TypeEvidence
        properties   = @($Properties)
    }
}

function Get-VariableProperties {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$VariableNode
    )

    $props = [ordered]@{}
    foreach ($propertyNode in $VariableNode.SelectNodes('./Properties/Property')) {
        $nameNode = $propertyNode.SelectSingleNode('./Name')
        if ($null -eq $nameNode) {
            continue
        }

        $valueNode = $propertyNode.SelectSingleNode('./Value')
        if ($null -eq $valueNode) {
            $props[$nameNode.InnerText] = ''
        } else {
            $props[$nameNode.InnerText] = $valueNode.InnerText
        }
    }

    return $props
}

function Get-TypeEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Properties
    )

    if ($Properties.Contains('idBasedOn')) {
        $value = [string]$Properties['idBasedOn']
        if ($value.StartsWith('Domain:', [System.StringComparison]::OrdinalIgnoreCase)) {
            return 'idBasedOn:Domain'
        }
        if ($value.StartsWith('Attribute:', [System.StringComparison]::OrdinalIgnoreCase)) {
            return 'idBasedOn:Attribute'
        }
        return 'idBasedOn:Other'
    }

    if ($Properties.Contains('ATTCUSTOMTYPE')) {
        $value = [string]$Properties['ATTCUSTOMTYPE']
        if ($value -match '^([^:]+):') {
            return "ATTCUSTOMTYPE:$($Matches[1])"
        }
        return 'ATTCUSTOMTYPE:no-prefix'
    }

    $shapeOnlyKeys = @('Length', 'AttMaxLen', 'Decimals', 'ATT_PICTURE', 'Signed')
    foreach ($key in $shapeOnlyKeys) {
        if ($Properties.Contains($key)) {
            return 'shape-only-type-properties'
        }
    }

    return 'none'
}

function Get-ObjectSourceText {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$Document
    )

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($sourceNode in $Document.SelectNodes('//Source')) {
        if (-not [string]::IsNullOrEmpty($sourceNode.InnerText)) {
            $parts.Add($sourceNode.InnerText) | Out-Null
        }
    }
    return ($parts -join "`n")
}

if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
    throw "InputPath nao encontrado: $InputPath"
}

$resolvedInput = (Resolve-Path -LiteralPath $InputPath).Path
$rawXml = [System.IO.File]::ReadAllText($resolvedInput)

$doc = [System.Xml.XmlDocument]::new()
$doc.PreserveWhitespace = $true
$doc.LoadXml($rawXml)

if ($null -eq $doc.DocumentElement -or $doc.DocumentElement.LocalName -ne 'Object') {
    throw "InputPath nao e XML de objeto GeneXus com raiz <Object>: $resolvedInput"
}

$requestedVariables = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @($VariableName)) {
    if (-not [string]::IsNullOrWhiteSpace($name)) {
        foreach ($namePart in @($name -split ',')) {
            if ([string]::IsNullOrWhiteSpace($namePart)) {
                continue
            }
            $normalized = $namePart.Trim()
            if ($normalized.StartsWith('&', [System.StringComparison]::Ordinal)) {
                $normalized = $normalized.Substring(1)
            }
            if (-not [string]::IsNullOrWhiteSpace($normalized)) {
                [void]$requestedVariables.Add($normalized)
            }
        }
    }
}

$scanOnlyRequested = ($requestedVariables.Count -gt 0)
$variablesByName = @{}
$allVariableRows = New-Object System.Collections.Generic.List[object]
$findings = New-Object System.Collections.Generic.List[object]

foreach ($variableNode in $doc.SelectNodes('//Variable')) {
    $attributeName = $variableNode.GetAttribute('Name')
    $props = Get-VariableProperties -VariableNode $variableNode
    $typeEvidence = Get-TypeEvidence -Properties $props
    $propertyNames = @($props.Keys)

    if (-not [string]::IsNullOrWhiteSpace($attributeName)) {
        $key = $attributeName.ToLowerInvariant()
        if (-not $variablesByName.ContainsKey($key)) {
            $variablesByName[$key] = New-Object System.Collections.Generic.List[object]
        }
        $variablesByName[$key].Add([pscustomobject]@{
            attributeName = $attributeName
            properties    = $props
            typeEvidence  = $typeEvidence
            propertyNames = @($propertyNames)
        }) | Out-Null
    }

    $allVariableRows.Add([pscustomobject]@{
        attributeName = $attributeName
        properties    = $props
        typeEvidence  = $typeEvidence
        propertyNames = @($propertyNames)
    }) | Out-Null
}

if ($scanOnlyRequested) {
    foreach ($requested in $requestedVariables) {
        $key = $requested.ToLowerInvariant()
        if (-not $variablesByName.ContainsKey($key)) {
            $findings.Add((New-Finding -Severity 'fail' -Code 'delta-variable-missing' -Message "Variavel '$requested' declarada no delta nao existe em <Variables>." -Variable $requested -TypeEvidence 'absent')) | Out-Null
            continue
        }

        if ($variablesByName[$key].Count -gt 1) {
            $findings.Add((New-Finding -Severity 'fail' -Code 'delta-variable-duplicate' -Message "Variavel '$requested' aparece mais de uma vez em <Variables>." -Variable $requested -TypeEvidence 'duplicate')) | Out-Null
        }
    }
}

$sourceText = Get-ObjectSourceText -Document $doc

foreach ($row in $allVariableRows) {
    $attributeName = [string]$row.attributeName
    if ($scanOnlyRequested -and -not $requestedVariables.Contains($attributeName)) {
        continue
    }

    $props = [System.Collections.IDictionary]$row.properties
    $propertyNames = @($row.propertyNames)
    $typeEvidence = [string]$row.typeEvidence
    $scopeLabel = if ($scanOnlyRequested) { 'delta' } else { 'objeto' }

    if ([string]::IsNullOrWhiteSpace($attributeName)) {
        $severity = if ($scanOnlyRequested) { 'fail' } else { 'warn' }
        $findings.Add((New-Finding -Severity $severity -Code "$scopeLabel-variable-without-attribute-name" -Message 'Bloco <Variable> sem atributo Name.' -Variable '' -TypeEvidence $typeEvidence -Properties $propertyNames)) | Out-Null
        continue
    }

    if (-not $props.Contains('Name')) {
        $severity = if ($scanOnlyRequested) { 'fail' } else { 'warn' }
        $findings.Add((New-Finding -Severity $severity -Code "$scopeLabel-variable-without-name-property" -Message "Variavel '$attributeName' nao tem propriedade Name." -Variable $attributeName -TypeEvidence $typeEvidence -Properties $propertyNames)) | Out-Null
    } elseif ([string]$props['Name'] -ne $attributeName) {
        $severity = if ($scanOnlyRequested) { 'fail' } else { 'warn' }
        $findings.Add((New-Finding -Severity $severity -Code "$scopeLabel-variable-name-mismatch" -Message "Variavel '$attributeName' tem propriedade Name='$($props['Name'])'." -Variable $attributeName -TypeEvidence $typeEvidence -Properties $propertyNames)) | Out-Null
    }

    if ($props.Contains('idBasedOn') -and $props.Contains('ATTCUSTOMTYPE')) {
        $severity = if ($scanOnlyRequested) { 'fail' } else { 'warn' }
        $findings.Add((New-Finding -Severity $severity -Code "$scopeLabel-variable-multiple-type-evidence" -Message "Variavel '$attributeName' tem idBasedOn e ATTCUSTOMTYPE simultaneamente; exige revisao manual." -Variable $attributeName -TypeEvidence $typeEvidence -Properties $propertyNames)) | Out-Null
    }

    if ($typeEvidence -eq 'none') {
        $severity = if ($scanOnlyRequested) { 'fail' } else { 'info' }
        $findings.Add((New-Finding -Severity $severity -Code "$scopeLabel-variable-without-type-evidence" -Message "Variavel '$attributeName' nao tem idBasedOn, ATTCUSTOMTYPE nem propriedades estruturais de tipo base reconhecidas." -Variable $attributeName -TypeEvidence $typeEvidence -Properties $propertyNames)) | Out-Null
    } elseif ($scanOnlyRequested -and $typeEvidence -eq 'shape-only-type-properties' -and -not $AllowShapeOnlyType.IsPresent) {
        $findings.Add((New-Finding -Severity 'fail' -Code 'delta-variable-shape-only-type' -Message "Variavel '$attributeName' usa apenas propriedades estruturais de tipo base; para delta novo, prefira clonar variavel comparavel com idBasedOn ou ATTCUSTOMTYPE, ou rerode com -AllowShapeOnlyType e justificativa." -Variable $attributeName -TypeEvidence $typeEvidence -Properties $propertyNames)) | Out-Null
    }

    if ($scanOnlyRequested -and -not [string]::IsNullOrWhiteSpace($sourceText)) {
        $escapedName = [regex]::Escape($attributeName)
        if ($sourceText -notmatch "(?<![A-Za-z0-9_])&$escapedName(?![A-Za-z0-9_])") {
            $findings.Add((New-Finding -Severity 'warn' -Code 'delta-variable-not-referenced-in-source' -Message "Variavel '$attributeName' foi declarada no delta, mas nao aparece como &$attributeName no Source." -Variable $attributeName -TypeEvidence $typeEvidence -Properties $propertyNames)) | Out-Null
        }
    }
}

$failCount = @($findings | Where-Object { $_.severity -eq 'fail' }).Count
$warnCount = @($findings | Where-Object { $_.severity -eq 'warn' }).Count

$status = if ($failCount -gt 0) {
    'fail'
} elseif ($warnCount -gt 0) {
    'warn'
} elseif ($scanOnlyRequested) {
    'pass'
} else {
    'pass'
}

$mode = 'full-scan-consultative'
if ($scanOnlyRequested) {
    $mode = 'delta'
}
$requestedVariableList = @()
foreach ($requested in $requestedVariables) {
    $requestedVariableList += $requested
}
$findingList = @()
foreach ($finding in $findings) {
    $findingList += $finding
}

$result = [pscustomobject]@{
    inputPath          = $resolvedInput
    status             = $status
    mode               = $mode
    variableCount      = $allVariableRows.Count
    requestedVariables = $requestedVariableList
    failCount          = $failCount
    warnCount          = $warnCount
    findings           = $findingList
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    if ($status -eq 'pass') {
        Write-Output 'VARIABLE_DELTA_OK'
    } elseif ($status -eq 'warn') {
        Write-Output 'VARIABLE_DELTA_WARN'
    } else {
        Write-Output 'VARIABLE_DELTA_FAIL'
    }
    Write-Output ("  input      : {0}" -f $result.inputPath)
    Write-Output ("  mode       : {0}" -f $result.mode)
    Write-Output ("  variables  : {0}" -f $result.variableCount)
    Write-Output ("  fail/warn  : {0}/{1}" -f $result.failCount, $result.warnCount)
    foreach ($finding in $findings) {
        Write-Output ("  {0}: {1}: {2}" -f $finding.severity.ToUpperInvariant(), $finding.code, $finding.message)
    }
}

if ($failCount -gt 0) {
    exit 42
}

exit 0
