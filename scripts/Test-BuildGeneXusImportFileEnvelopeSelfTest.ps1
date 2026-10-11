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

function Assert-PropertyAbsent {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Assert-True ($null -eq $Object.PSObject.Properties[$PropertyName]) $Message
}

function New-DomainXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][string]$LastUpdate
    )
    return @"
<Object type="00972a17-9975-449e-aab1-d26165d51393" name="$Name" fullyQualifiedName="$Name" guid="$Guid" lastUpdate="$LastUpdate">
  <Properties>
    <Property><Name>Name</Name><Value>$Name</Value></Property>
    <Property><Name>Description</Name><Value>$Description</Value></Property>
  </Properties>
</Object>
"@
}

function Write-DomainBaseline {
    param(
        [Parameter(Mandatory = $true)][string]$AcervoRoot,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Xml
    )
    $domainDir = Join-Path $AcervoRoot 'Domain'
    [void](New-Item -ItemType Directory -Path $domainDir -Force)
    Write-Utf8NoBomText -Path (Join-Path $domainDir "$Name.xml") -Content $Xml
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
    $domainTypeGuid = '00972a17-9975-449e-aab1-d26165d51393'

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

    $domainName = 'DomainEnvelopeTeste'
    $domainGuid = 'bbbbbbbb-1111-2222-3333-444444444444'
    $domainBaseXml = New-DomainXml -Name $domainName -Guid $domainGuid -Description 'descrição antiga' -LastUpdate '2026-01-01T00:00:00.0000000Z'
    $domainFrontXml = New-DomainXml -Name $domainName -Guid $domainGuid -Description 'descrição nova' -LastUpdate '2026-02-01T00:00:00.0000000Z'
    $domainFrontPath = Join-Path $tempRoot "$domainName.xml"
    Write-Utf8NoBomText -Path $domainFrontPath -Content $domainFrontXml
    Write-DomainBaseline -AcervoRoot $acervoDir -Name $domainName -Xml $domainBaseXml

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
    Assert-True ((@($control.frontObjectTypeDrift.warnings)).Count -eq 0) 'frontObjectTypeDrift.warnings deveria existir como array vazio.'
    Assert-True ((@($control.frontObjectTypeDrift.blockingReasons)).Count -eq 0) 'frontObjectTypeDrift.blockingReasons deveria existir como array vazio.'
    Assert-True ((@($control.frontObjectTypeDrift.blockingDetails)).Count -eq 0) 'frontObjectTypeDrift.blockingDetails deveria existir como array vazio.'
    $matchCheck = @($control.frontObjectTypeDrift.checks | Where-Object { $_.code -eq 'object-type-match' } | Select-Object -First 1)
    Assert-True ($matchCheck.Count -eq 1) 'controle deveria emitir object-type-match.'
    Assert-True ($matchCheck[0].status -eq 'pass') 'object-type-match deveria ter status pass.'
    Assert-True ($matchCheck[0].objectGuid -eq $objectGuid) "object-type-match deveria emitir objectGuid normalizado; obtido $($matchCheck[0].objectGuid)."
    Assert-True ($matchCheck[0].acervoPath -eq 'Cliente.xml') "object-type-match deveria emitir acervoPath relativo; obtido $($matchCheck[0].acervoPath)."
    Assert-PropertyAbsent -Object $matchCheck[0] -PropertyName 'guid' -Message 'object-type-match nao deve emitir guid como chave publica.'
    Assert-PropertyAbsent -Object $matchCheck[0] -PropertyName 'baselinePath' -Message 'object-type-match nao deve emitir baselinePath.'
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
    Assert-True ($typeDrift.frontObjectTypeDrift.blockingDetails[0].objectGuid -eq $objectGuid) 'blockingDetails deveria preservar objectGuid normalizado.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$typeDrift.frontObjectTypeDrift.blockingDetails[0].message)) 'blockingDetails deveria preservar message.'
    Assert-True ($typeDrift.frontObjectTypeDrift.blockingDetails[0].acervoPath -eq 'Cliente.xml') "blockingDetails deveria preservar acervoPath relativo; obtido $($typeDrift.frontObjectTypeDrift.blockingDetails[0].acervoPath)."
    foreach ($legacyName in @('frontGuid', 'guid', 'baselinePath', 'candidateBaselinePaths', 'baselineObjectType', 'baselineObjectTypeNormalized', 'acervoFile')) {
        Assert-PropertyAbsent -Object $typeDrift.frontObjectTypeDrift.blockingDetails[0] -PropertyName $legacyName -Message "blockingDetails de type drift nao deve emitir $legacyName."
    }
    Assert-True (-not (Test-Path -LiteralPath $typeDriftOutputPath -PathType Leaf)) 'pacote nao deveria ser gravado quando ha drift de tipo.'

    # Domain pré-gate continua ativo com -SkipGate e preserva envelope existente sob -Force.
    $domainOutputPath = Join-Path $outDir 'Front_00000000000000000000000000000000_20260604_05.import_file.xml'
    $sentinelText = 'envelope anterior que deve permanecer byte a byte'
    Write-Utf8NoBomText -Path $domainOutputPath -Content $sentinelText
    $sentinelBefore = [System.Convert]::ToHexString([System.IO.File]::ReadAllBytes($domainOutputPath))
    $domainBlockRaw = & pwsh -NoProfile -File $builderScript `
        -ObjectXmlPaths $domainFrontPath `
        -TemplatePackagePath $templatePath `
        -OutputPath $domainOutputPath `
        -AcervoPath $acervoDir `
        -ModifiedObjectNames $domainName `
        -SkipGate `
        -Force 2>&1
    $domainBlockExitCode = $LASTEXITCODE
    $domainBlock = (($domainBlockRaw | Out-String).Trim()) | ConvertFrom-Json
    $sentinelAfter = [System.Convert]::ToHexString([System.IO.File]::ReadAllBytes($domainOutputPath))
    Assert-True ($domainBlockExitCode -eq 20 -and $domainBlock.status -eq 'bloqueado') 'Domain condicional sem aprovação deveria bloquear o envelope.'
    Assert-True ($domainBlock.stage -eq 'front-domain-drift') "stage Domain inesperado: '$($domainBlock.stage)'."
    Assert-True ($domainBlock.domainsScanned -eq 1 -and $domainBlock.domainDrift.domainsScanned -eq 1) "bloqueio deveria expor domainsScanned=1; topo='$($domainBlock.domainsScanned)' domínio='$($domainBlock.domainDrift.domainsScanned)' findings='$(@($domainBlock.domainDrift.findings | ForEach-Object { $_.code }) -join ',')' raw='$($domainBlockRaw | Out-String)'."
    Assert-True (@($domainBlock.domainDrift.findings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' }).Count -eq 1) 'bloqueio deveria expor a diferença condicional de Domain.'
    Assert-True ($sentinelAfter -ceq $sentinelBefore) 'pré-gate Domain alterou bytes do envelope existente.'

    # Aprovação exata libera o pré-gate e o envelope expõe somente a superfície pública necessária.
    $approval = [ordered]@{
        kind = 'domain-drift-approvals'
        schemaVersion = 1
        approvals = @([ordered]@{
            objectGuid = $domainGuid
            field = 'Description'
            locationKind = 'property'
            container = 'Object/Properties'
            partType = ''
            component = 'value'
            enumStoredValue = ''
            oldState = 'value'
            oldValue = 'descrição antiga'
            newState = 'value'
            newValue = 'descrição nova'
        })
    }
    $approvalPath = Join-Path $tempRoot 'domain-approval.json'
    Write-Utf8NoBomText -Path $approvalPath -Content (ConvertTo-Json -InputObject $approval -Depth 8)
    $approvedOutputPath = Join-Path $outDir 'Front_00000000000000000000000000000000_20260604_06.import_file.xml'
    $approved = (& $builderScript `
        -ObjectXmlPaths $domainFrontPath `
        -TemplatePackagePath $templatePath `
        -OutputPath $approvedOutputPath `
        -AcervoPath $acervoDir `
        -ApprovedDomainChangesPath $approvalPath `
        -ModifiedObjectNames $domainName `
        -SkipGate `
        -Force | ConvertFrom-Json)
    Assert-True ($approved.status -eq 'apto para prosseguir') "aprovação exata deveria liberar o envelope; status='$($approved.status)'."
    Assert-True ($approved.domainDrift.status -eq 'pass' -and $approved.domainDrift.domainsScanned -eq 1 -and $approved.domainsScanned -eq 1) 'resultado aprovado deveria preservar status e contagem Domain.'
    Assert-True (@($approved.domainDrift.findings | Where-Object { $_.code -eq 'domain-change-approved' }).Count -eq 1) 'resultado deveria expor a aprovação exata reconhecida.'
    Assert-PropertyAbsent -Object $approved.domainDrift -PropertyName 'byPath' -Message 'domainDrift público não deve expor o mapa interno por caminho absoluto.'
    Assert-True (Test-Path -LiteralPath $approvedOutputPath -PathType Leaf) 'envelope aprovado deveria ter sido gravado.'

    # ExportFile aninhado com Domain também bloqueia antes da escrita do envelope.
    $nestedDomainPath = Join-Path $tempRoot 'nested-domain.import_file.xml'
    $nestedDomainXml = "<ExportFile><Objects>$domainFrontXml</Objects></ExportFile>"
    Write-Utf8NoBomText -Path $nestedDomainPath -Content $nestedDomainXml
    $nestedOutputPath = Join-Path $outDir 'Front_00000000000000000000000000000000_20260604_07.import_file.xml'
    $nestedRaw = & pwsh -NoProfile -File $builderScript `
        -ObjectXmlPaths $nestedDomainPath `
        -TemplatePackagePath $templatePath `
        -OutputPath $nestedOutputPath `
        -AcervoPath $acervoDir `
        -SkipGate `
        -Force 2>&1
    $nestedExitCode = $LASTEXITCODE
    $nestedResult = (($nestedRaw | Out-String).Trim()) | ConvertFrom-Json
    Assert-True ($nestedExitCode -eq 20 -and $nestedResult.stage -eq 'front-domain-drift') 'Domain dentro de ExportFile deveria bloquear na etapa de pré-gate.'
    Assert-True (@($nestedResult.domainDrift.findings | Where-Object { $_.code -eq 'domain-nested-root-unsupported' }).Count -eq 1) "ExportFile aninhado deveria bloquear a raiz Domain não autônoma; codes='$(@($nestedResult.domainDrift.findings | ForEach-Object { $_.code }) -join ',')'."
    Assert-True (-not (Test-Path -LiteralPath $nestedOutputPath -PathType Leaf)) 'ExportFile aninhado bloqueado não deveria produzir envelope.'

    # ExportFile com Object não-Domain aninhado não cria finding Domain.
    $nonDomainNestedPath = Join-Path $tempRoot 'nested-procedure.import_file.xml'
    $nonDomainNestedXml = "<ExportFile><Objects>$objectFreshXml</Objects></ExportFile>"
    Write-Utf8NoBomText -Path $nonDomainNestedPath -Content $nonDomainNestedXml
    $nonDomainNested = (& (Join-Path $scriptDir 'Test-GeneXusFrontAcervoDrift.ps1') `
        -ObjectXmlPaths $nonDomainNestedPath `
        -AcervoFolder $acervoDir `
        -AsJson | ConvertFrom-Json)
    Assert-True ($nonDomainNested.status -eq 'pass' -and $nonDomainNested.domainsScanned -eq 0) 'ExportFile com apenas Object não-Domain não deve contar Domain.'
    Assert-True (@($nonDomainNested.findings | Where-Object { $_.code -like '*domain*' }).Count -eq 0) 'Object não-Domain aninhado não deve criar finding Domain.'

    Write-Output 'BUILD_GENEXUS_IMPORT_FILE_ENVELOPE_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
