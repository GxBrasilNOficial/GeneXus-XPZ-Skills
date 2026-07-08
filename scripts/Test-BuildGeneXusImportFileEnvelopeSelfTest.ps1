#requires -Version 7.4
<#
.SYNOPSIS
    Regression test for Build-GeneXusImportFileEnvelope.ps1 package-input guards.

.DESCRIPTION
    Exercises the real envelope builder with synthetic minimal fixtures. Verifies
    that reference/example/template-like XML names are rejected only for package
    inputs, while TemplatePackagePath may still point to a template file. Also
    verifies the pre-write front/acervo Object/@type drift block.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$builderScript = Join-Path $scriptDir 'Build-GeneXusImportFileEnvelope.ps1'
$encodingSupportPath = Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1'

if (-not (Test-Path -LiteralPath $builderScript -PathType Leaf)) {
    throw "Builder script not found: $builderScript"
}
if (-not (Test-Path -LiteralPath $encodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $encodingSupportPath"
}
. $encodingSupportPath

function Write-Utf8NoBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
}

function Assert-True {
    param(
        [bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw "ASSERT_FAILED: $Message"
    }
}

function Assert-BuilderBlocksPath {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Invocation,
        [Parameter(Mandatory = $true)][string]$ExpectedRole
    )

    try {
        $output = & $Invocation
        $result = ($output | Out-String) | ConvertFrom-Json
        Assert-True ($result.status -eq 'bloqueado' -or $result.status -eq 'erro') `
            "status de bloqueio inesperado para ${ExpectedRole}: $($result.status)"
        Assert-True (@($result.blockingReasons | Where-Object { $_ -like "*$ExpectedRole nao pode ser XML de referencia/exemplo/template/molde:*" }).Count -gt 0) `
            "blockingReasons inesperado para ${ExpectedRole}: $(@($result.blockingReasons) -join '; ')"
        return
    } catch {
        $message = $_.Exception.Message
        Assert-True ($message -like "BLOCK: $ExpectedRole nao pode ser XML de referencia/exemplo/template/molde:*") `
            "mensagem de bloqueio inesperada para ${ExpectedRole}: $message"
        return
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-build-envelope-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))

try {
    $acervoDir = Join-Path $tempRoot 'acervo'
    $outDir = Join-Path $tempRoot 'out'
    [void](New-Item -ItemType Directory -Path $acervoDir -Force)
    [void](New-Item -ItemType Directory -Path $outDir -Force)

    $procedureTypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
    $webPanelTypeGuid = '7a7686a8-90de-4598-9406-014bcbcf3d82'
    $objectGuid = '11111111-1111-1111-1111-111111111111'
    $attributeGuid = '22222222-2222-2222-2222-222222222222'

    $templateXml = @"
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <KMW name="KbExemplo" guid="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" />
  <Source kb="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" />
  <Attributes>
    <Attribute name="AttrTemplate" guid="33333333-3333-3333-3333-333333333333" />
  </Attributes>
  <Dependencies />
  <ObjectsIdentityMapping />
</ExportFile>
"@

    $objectBaselineXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureTypeGuid" name="Cliente" fullyQualifiedName="Cliente" guid="$objectGuid" lastUpdate="2026-01-01T00:00:00.0000000Z">
  <Properties />
</Object>
"@

    $objectFreshXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$procedureTypeGuid" name="Cliente" fullyQualifiedName="Cliente" guid="$objectGuid" lastUpdate="2026-01-01T00:02:00.0000000Z">
  <Properties />
</Object>
"@

    $objectTypeDriftXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Object type="$webPanelTypeGuid" name="Cliente" fullyQualifiedName="Cliente" guid="$objectGuid" lastUpdate="2025-12-31T23:59:00.0000000Z">
  <Properties />
</Object>
"@

    $attributeXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Attribute name="ClienteId" guid="$attributeGuid" />
"@

    $templatePath = Join-Path $tempRoot 'envelope_template.import_file.xml'
    $objectPath = Join-Path $tempRoot 'Cliente.xml'
    $objectReferencePath = Join-Path $tempRoot 'Cliente_referencia.xml'
    $objectTypeDriftPath = Join-Path $tempRoot 'ClienteTypeDrift.xml'
    $attributePath = Join-Path $tempRoot 'ClienteId.xml'
    $attributeReferencePath = Join-Path $tempRoot 'ClienteId_template.xml'
    $baselinePath = Join-Path $acervoDir 'Cliente.xml'

    Write-Utf8NoBomText -Path $templatePath -Content $templateXml
    Write-Utf8NoBomText -Path $objectPath -Content $objectFreshXml
    Write-Utf8NoBomText -Path $objectReferencePath -Content $objectFreshXml
    Write-Utf8NoBomText -Path $objectTypeDriftPath -Content $objectTypeDriftXml
    Write-Utf8NoBomText -Path $attributePath -Content $attributeXml
    Write-Utf8NoBomText -Path $attributeReferencePath -Content $attributeXml
    Write-Utf8NoBomText -Path $baselinePath -Content $objectBaselineXml

    Assert-BuilderBlocksPath -ExpectedRole 'ObjectXml' -Invocation {
        & $builderScript `
            -ObjectXmlPaths $objectReferencePath `
            -TemplatePackagePath $templatePath `
            -OutputPath (Join-Path $outDir 'Front_00000000000000000000000000000000_20260604_01.import_file.xml') `
            -AcervoPath $acervoDir `
            -ModifiedObjectNames 'Cliente' `
            -SkipGate `
            -Force
    }

    Assert-BuilderBlocksPath -ExpectedRole 'TopLevelAttributeXml' -Invocation {
        & $builderScript `
            -ObjectXmlPaths $objectPath `
            -TopLevelAttributesXmlPaths $attributeReferencePath `
            -TemplatePackagePath $templatePath `
            -OutputPath (Join-Path $outDir 'Front_00000000000000000000000000000000_20260604_02.import_file.xml') `
            -AcervoPath $acervoDir `
            -ModifiedObjectNames 'Cliente' `
            -SkipGate `
            -Force
    }

    $controlOutputPath = Join-Path $outDir 'Front_00000000000000000000000000000000_20260604_03.import_file.xml'
    $control = (& $builderScript `
        -ObjectXmlPaths $objectPath `
        -TopLevelAttributesXmlPaths $attributePath `
        -TemplatePackagePath $templatePath `
        -OutputPath $controlOutputPath `
        -AcervoPath $acervoDir `
        -ModifiedObjectNames 'Cliente' `
        -SkipGate `
        -Force | ConvertFrom-Json)

    Assert-True ($control.status -eq 'apto para prosseguir') "status de controle inesperado: $($control.status)"
    Assert-True ($control.objectCount -eq 1) "objectCount de controle esperado 1; obtido $($control.objectCount)"
    Assert-True ($control.topLevelAttrCount -eq 1) "topLevelAttrCount de controle esperado 1; obtido $($control.topLevelAttrCount)"
    Assert-True (Test-Path -LiteralPath $controlOutputPath -PathType Leaf) 'pacote de controle deveria ter sido gravado'

    $typeDriftOutputPath = Join-Path $outDir 'Front_00000000000000000000000000000000_20260604_04.import_file.xml'
    $typeDriftRaw = & pwsh -NoProfile -File $builderScript `
        -ObjectXmlPaths $objectTypeDriftPath `
        -TemplatePackagePath $templatePath `
        -OutputPath $typeDriftOutputPath `
        -AcervoPath $acervoDir `
        -ModifiedObjectNames 'Cliente' `
        -SkipGate `
        -Force 2>&1
    $typeDriftExitCode = $LASTEXITCODE
    $typeDrift = (($typeDriftRaw | Out-String).Trim()) | ConvertFrom-Json

    Assert-True ($typeDriftExitCode -eq 20) "type drift deveria sair com exit 20; obtido $typeDriftExitCode"
    Assert-True ($typeDrift.status -eq 'bloqueado') "type drift deveria retornar bloqueado; obtido $($typeDrift.status)"
    Assert-True ($typeDrift.stage -eq 'front-acervo-coherence') "stage inesperado para type drift: $($typeDrift.stage)"
    Assert-True (@($typeDrift.blockingReasons) -contains 'front-object-type-drift') 'blockingReasons deveria incluir front-object-type-drift.'
    Assert-True ((@($typeDrift.lastUpdateFreshness.blockingReasons)).Count -gt 0) 'lastUpdateFreshness deveria preservar bloqueio de lastUpdate antigo.'
    Assert-True (@($typeDrift.frontObjectTypeDrift.blockingReasons) -contains 'front-object-type-drift') 'frontObjectTypeDrift deveria preservar o bloqueio.'
    Assert-True ($typeDrift.frontObjectTypeDrift.blockingDetails[0].code -eq 'front-object-type-drift') 'blockingDetails deveria preservar codigo front-object-type-drift.'
    Assert-True ($typeDrift.frontObjectTypeDrift.blockingDetails[0].matchBasis -eq 'guid') 'blockingDetails deveria preservar matchBasis guid.'
    Assert-True (-not (Test-Path -LiteralPath $typeDriftOutputPath -PathType Leaf)) 'pacote nao deveria ser gravado quando ha drift de tipo.'

    Write-Output 'BUILD_GENEXUS_IMPORT_FILE_ENVELOPE_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
