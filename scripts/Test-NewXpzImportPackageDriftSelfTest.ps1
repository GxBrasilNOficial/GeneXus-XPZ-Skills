#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do contrato fail-closed de drift frente-vs-acervo em New-XpzImportPackage.ps1.

.DESCRIPTION
    Cobre os caminhos da resolucao de acervo e confirma que divergencias de
    assinatura funcional de tipo de Attribute bloqueiam o pacote no gate PowerShell,
    antes do motor Python, sem dependencia de Python para esse caminho.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function New-FixtureObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$LastUpdate,
        [string]$TypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
    )
    return @"
<Object type="$TypeGuid" name="$Name" guid="$Guid" fullyQualifiedName="$Name" lastUpdate="$LastUpdate">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>$Name</Value>
    </Property>
  </Properties>
  <Source><![CDATA[]]></Source>
</Object>
"@
}

function New-FixtureDomainXml {
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

function Write-FixtureDomain {
    param(
        [Parameter(Mandatory = $true)][string]$AcervoRoot,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Xml
    )
    $domainDir = Join-Path $AcervoRoot 'Domain'
    [void](New-Item -ItemType Directory -Path $domainDir -Force)
    [System.IO.File]::WriteAllText((Join-Path $domainDir "$Name.xml"), $Xml, (Get-Utf8NoBomEncoding))
}

function New-TextualFidelityFixtureObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$LastUpdate,
        [string]$TypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9',
        [switch]$TrimTrailingWhitespace,
        [int]$FunctionalChanges = 0
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $rootLine = "<Object type=""$TypeGuid"" name=""$Name"" guid=""$Guid"" fullyQualifiedName=""$Name"" lastUpdate=""$LastUpdate"">"
    if (-not $TrimTrailingWhitespace) { $rootLine += '  ' }
    $lines.Add($rootLine) | Out-Null
    $lines.Add('  <Properties>') | Out-Null
    $lines.Add('    <Property>') | Out-Null
    $lines.Add('      <Name>Name</Name>') | Out-Null
    $lines.Add("      <Value>$Name</Value>") | Out-Null
    $lines.Add('    </Property>') | Out-Null
    for ($i = 1; $i -le 40; $i++) {
        $line = "      <Property><Name>P$i</Name><Value>V$i</Value></Property>"
        if (-not $TrimTrailingWhitespace) { $line += '  ' }
        $lines.Add($line) | Out-Null
    }
    for ($i = 1; $i -le $FunctionalChanges; $i++) {
        $lines.Add("      <Property><Name>Func$i</Name><Value>$Name-$i</Value></Property>") | Out-Null
    }
    $lines.Add('  </Properties>') | Out-Null
    $lines.Add('  <Source><![CDATA[]]></Source>') | Out-Null
    $lines.Add('</Object>') | Out-Null
    return ($lines -join "`n") + "`n"
}

function New-FrontWithObject {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$FrontName,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$LastUpdate,
        [string]$TypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
    )
    $frontDir = Join-Path $RepoRoot 'ObjetosGeradosParaImportacaoNaKbNoGenexus' $FrontName
    [void](New-Item -ItemType Directory -Path $frontDir -Force)
    $xml = New-FixtureObjectXml -Name $Name -Guid $Guid -LastUpdate $LastUpdate -TypeGuid $TypeGuid
    [System.IO.File]::WriteAllText((Join-Path $frontDir "$Name.xml"), $xml, (Get-Utf8NoBomEncoding))
    return $frontDir
}

function New-AcervoWithObject {
    param(
        [Parameter(Mandatory = $true)][string]$AcervoRoot,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$LastUpdate,
        [string]$TypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
    )
    $procedureDir = Join-Path $AcervoRoot 'Procedure'
    [void](New-Item -ItemType Directory -Path $procedureDir -Force)
    $xml = New-FixtureObjectXml -Name $Name -Guid $Guid -LastUpdate $LastUpdate -TypeGuid $TypeGuid
    [System.IO.File]::WriteAllText((Join-Path $procedureDir "$Name.xml"), $xml, (Get-Utf8NoBomEncoding))
}

function New-FixtureAttributeXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeValue,
        [string]$Length = '10',
        [string]$MaxLength = '10'
    )
    return @"
<Attribute name="$Name" fullyQualifiedName="$Name" guid="$Guid">
  <Properties>
    <Property><Name>Name</Name><Value>$Name</Value></Property>
    <Property><Name>ATTCUSTOMTYPE</Name><Value>$TypeValue</Value></Property>
    <Property><Name>Length</Name><Value>$Length</Value></Property>
    <Property><Name>AttMaxLen</Name><Value>$MaxLength</Value></Property>
  </Properties>
</Attribute>
"@
}

function Write-FixtureAttribute {
    param(
        [Parameter(Mandatory = $true)][string]$Folder,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeValue,
        [string]$Length = '10',
        [string]$MaxLength = '10'
    )
    [void](New-Item -ItemType Directory -Path $Folder -Force)
    [System.IO.File]::WriteAllText((Join-Path $Folder "$Name.xml"), (New-FixtureAttributeXml -Name $Name -Guid $Guid -TypeValue $TypeValue -Length $Length -MaxLength $MaxLength), (Get-Utf8NoBomEncoding))
}

$scriptPath = Join-Path $PSScriptRoot 'New-XpzImportPackage.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('new-xpz-import-drift-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$objName = 'procDriftTeste'
$objGuid = '11111111-1111-1111-1111-111111111111'
$frontName = 'DriftTeste_11111111_20260101'
$oldStamp = '2026-01-01T00:00:00.0000000Z'
$newStamp = '2026-02-01T00:00:00.0000000Z'
$procedureTypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$webPanelTypeGuid = '7a7686a8-90de-4598-9406-014bcbcf3d82'

# Caso 1: sem -AcervoPath e sem acervo canonico -> bloqueio fail-closed
$repo1 = Join-Path $tempRoot 'repo1'
[void](New-FrontWithObject -RepoRoot $repo1 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $oldStamp)
$r1 = & $scriptPath -RepoRoot $repo1 -FrontName $frontName | ConvertFrom-Json
$code1 = $LASTEXITCODE
if ($r1.status -ne 'bloqueado') {
    throw "Caso 1: status deveria ser 'bloqueado'; obtido '$($r1.status)'."
}
if ($code1 -ne 20) {
    throw "Caso 1: exitCode deveria ser 20; obtido '$code1'."
}
if ($null -ne $r1.acervoResolvedBy) {
    throw "Caso 1: acervoResolvedBy deveria ser null; obtido '$($r1.acervoResolvedBy)'."
}
if ((@($r1.blockingReasons) -join ' ') -notmatch 'Footgun') {
    throw "Caso 1: blockingReasons deveria nomear o footgun; obtido '$(@($r1.blockingReasons) -join ' ')'."
}

# Caso 2: sem -AcervoPath, acervo canonico presente com objeto mais novo -> bloqueio por drift
$repo2 = Join-Path $tempRoot 'repo2'
[void](New-FrontWithObject -RepoRoot $repo2 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $oldStamp)
New-AcervoWithObject -AcervoRoot (Join-Path $repo2 'ObjetosDaKbEmXml') -Name $objName -Guid $objGuid -LastUpdate $newStamp
$r2 = & $scriptPath -RepoRoot $repo2 -FrontName $frontName | ConvertFrom-Json
$code2 = $LASTEXITCODE
if ($r2.status -ne 'bloqueado') {
    throw "Caso 2: status deveria ser 'bloqueado'; obtido '$($r2.status)'."
}
if ($code2 -ne 20) {
    throw "Caso 2: exitCode deveria ser 20; obtido '$code2'."
}
if ($r2.acervoResolvedBy -ne 'convention') {
    throw "Caso 2: acervoResolvedBy deveria ser 'convention'; obtido '$($r2.acervoResolvedBy)'."
}
if ($r2.driftStatus -ne 'fail') {
    throw "Caso 2: driftStatus deveria ser 'fail'; obtido '$($r2.driftStatus)'."
}

# Caso 3: -AcervoPath explicito com objeto mais novo -> bloqueio por drift, resolvido por explicit
$repo3 = Join-Path $tempRoot 'repo3'
[void](New-FrontWithObject -RepoRoot $repo3 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $oldStamp)
$acervo3 = Join-Path $tempRoot 'acervo3'
New-AcervoWithObject -AcervoRoot $acervo3 -Name $objName -Guid $objGuid -LastUpdate $newStamp
$r3 = & $scriptPath -RepoRoot $repo3 -FrontName $frontName -AcervoPath $acervo3 | ConvertFrom-Json
$code3 = $LASTEXITCODE
if ($r3.status -ne 'bloqueado') {
    throw "Caso 3: status deveria ser 'bloqueado'; obtido '$($r3.status)'."
}
if ($code3 -ne 20) {
    throw "Caso 3: exitCode deveria ser 20; obtido '$code3'."
}
if ($r3.acervoResolvedBy -ne 'explicit') {
    throw "Caso 3: acervoResolvedBy deveria ser 'explicit'; obtido '$($r3.acervoResolvedBy)'."
}
if ($r3.driftStatus -ne 'fail') {
    throw "Caso 3: driftStatus deveria ser 'fail'; obtido '$($r3.driftStatus)'."
}

# Caso 4: -AcervoPath explicito com mesmo guid e Object/@type divergente -> bloqueio por drift de tipo
$repo4 = Join-Path $tempRoot 'repo4'
[void](New-FrontWithObject -RepoRoot $repo4 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $newStamp -TypeGuid $webPanelTypeGuid)
$acervo4 = Join-Path $tempRoot 'acervo4'
New-AcervoWithObject -AcervoRoot $acervo4 -Name $objName -Guid $objGuid -LastUpdate $oldStamp -TypeGuid $procedureTypeGuid
$r4 = & $scriptPath -RepoRoot $repo4 -FrontName $frontName -AcervoPath $acervo4 | ConvertFrom-Json
$code4 = $LASTEXITCODE
if ($r4.status -ne 'bloqueado') {
    throw "Caso 4: status deveria ser 'bloqueado'; obtido '$($r4.status)'."
}
if ($code4 -ne 20) {
    throw "Caso 4: exitCode deveria ser 20; obtido '$code4'."
}
if ($r4.driftStatus -ne 'fail') {
    throw "Caso 4: driftStatus deveria ser 'fail'; obtido '$($r4.driftStatus)'."
}
$typeFinding4 = @($r4.driftFindings | Where-Object { $_.code -eq 'front-object-type-drift' } | Select-Object -First 1)
if ($typeFinding4.Count -ne 1) {
    throw "Caso 4: driftFindings deveria preservar front-object-type-drift."
}
if ($typeFinding4[0].matchBasis -ne 'guid') {
    throw "Caso 4: matchBasis deveria ser guid; obtido '$($typeFinding4[0].matchBasis)'."
}
if ($typeFinding4[0].objectGuid -ne $objGuid) {
    throw "Caso 4: objectGuid normalizado inesperado: '$($typeFinding4[0].objectGuid)'."
}
if ([string]::IsNullOrWhiteSpace([string]$typeFinding4[0].message)) {
    throw 'Caso 4: driftFindings deveria preservar message.'
}
if ($typeFinding4[0].acervoPath -ne 'Procedure/procDriftTeste.xml') {
    throw "Caso 4: acervoPath relativo inesperado: '$($typeFinding4[0].acervoPath)'."
}
foreach ($legacyName in @('frontGuid', 'baselinePath', 'candidateBaselinePaths', 'baselineObjectType', 'baselineObjectTypeNormalized', 'acervoFile')) {
    if ($null -ne $typeFinding4[0].PSObject.Properties[$legacyName]) {
        throw "Caso 4: driftFindings nao deveria emitir campo legado '$legacyName'."
    }
}
if ($typeFinding4[0].frontObjectTypeNormalized -ne $webPanelTypeGuid) {
    throw "Caso 4: frontObjectTypeNormalized inesperado: '$($typeFinding4[0].frontObjectTypeNormalized)'."
}
if ($typeFinding4[0].acervoObjectTypeNormalized -ne $procedureTypeGuid) {
    throw "Caso 4: acervoObjectTypeNormalized inesperado: '$($typeFinding4[0].acervoObjectTypeNormalized)'."
}

# Caso 5: trim global forte bloqueia pacote e propaga finding textual
$repo5 = Join-Path $tempRoot 'repo5'
$front5Dir = Join-Path $repo5 'ObjetosGeradosParaImportacaoNaKbNoGenexus' $frontName
$acervo5Dir = Join-Path $tempRoot 'acervo5' 'Procedure'
[void](New-Item -ItemType Directory -Path $front5Dir -Force)
[void](New-Item -ItemType Directory -Path $acervo5Dir -Force)
[System.IO.File]::WriteAllText((Join-Path $front5Dir "$objName.xml"), (New-TextualFidelityFixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $newStamp -TrimTrailingWhitespace -FunctionalChanges 2), (Get-Utf8NoBomEncoding))
[System.IO.File]::WriteAllText((Join-Path $acervo5Dir "$objName.xml"), (New-TextualFidelityFixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate $oldStamp), (Get-Utf8NoBomEncoding))
$r5 = & $scriptPath -RepoRoot $repo5 -FrontName $frontName -AcervoPath (Split-Path -Parent $acervo5Dir) | ConvertFrom-Json
$code5 = $LASTEXITCODE
if ($r5.status -ne 'bloqueado') {
    throw "Caso 5: status deveria ser 'bloqueado'; obtido '$($r5.status)'."
}
if ($code5 -ne 20) {
    throw "Caso 5: exitCode deveria ser 20; obtido '$code5'."
}
$textFinding5 = @($r5.driftFindings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' } | Select-Object -First 1)
if ($textFinding5.Count -ne 1) {
    throw 'Caso 5: driftFindings deveria preservar front-textual-fidelity-trim-removal-churn.'
}
if ((@($r5.blockingReasons) -join ' ') -notmatch 'trailing whitespace') {
    throw "Caso 5: blockingReasons deveria citar trailing whitespace; obtido '$(@($r5.blockingReasons) -join ' ')'."
}

# Caso 6: Attribute com assinatura Numeric/VarChar divergente bloqueia antes do motor Python
$repo6 = Join-Path $tempRoot 'repo6'
$front6Dir = New-FrontWithObject -RepoRoot $repo6 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $newStamp
$attributeName6 = 'attrTipoTeste'
$attributeGuid6 = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
Write-FixtureAttribute -Folder $front6Dir -Name $attributeName6 -Guid $attributeGuid6 -TypeValue 'bas:VarChar'
$acervo6 = Join-Path $tempRoot 'acervo6'
New-AcervoWithObject -AcervoRoot $acervo6 -Name $objName -Guid $objGuid -LastUpdate $oldStamp
Write-FixtureAttribute -Folder (Join-Path $acervo6 'Attribute') -Name $attributeName6 -Guid $attributeGuid6 -TypeValue 'bas:Numeric'
$r6 = & $scriptPath -RepoRoot $repo6 -FrontName $frontName -AcervoPath $acervo6 | ConvertFrom-Json
$code6 = $LASTEXITCODE
if ($r6.status -ne 'bloqueado') {
    throw "Caso 6: status deveria ser 'bloqueado'; obtido '$($r6.status)'."
}
if ($code6 -ne 20) {
    throw "Caso 6: exitCode deveria ser 20; obtido '$code6'."
}
if ($r6.stage -ne 'front-acervo-drift' -or $r6.driftStatus -ne 'fail') {
    throw "Caso 6: pacote deveria parar no gate front-acervo-drift; stage='$($r6.stage)', driftStatus='$($r6.driftStatus)'."
}
if ($r6.driftAttributesScanned -ne 1) {
    throw "Caso 6: driftAttributesScanned deveria ser 1; obtido '$($r6.driftAttributesScanned)'."
}
$attributeFinding6 = @($r6.driftFindings | Where-Object { $_.code -eq 'front-attribute-type-signature-drift' } | Select-Object -First 1)
if ($attributeFinding6.Count -ne 1) {
    throw 'Caso 6: driftFindings deveria preservar front-attribute-type-signature-drift.'
}
if ($attributeFinding6[0].signatureDifferences[0].fieldName -ne 'ATTCUSTOMTYPE') {
    throw "Caso 6: campo divergente inesperado: '$($attributeFinding6[0].signatureDifferences[0].fieldName)'."
}
if ($null -ne $r6.PSObject.Properties['packageInventory']) {
    throw 'Caso 6: gate deveria bloquear antes de produzir inventario do pacote.'
}

# Caso 7: crescimento de tamanho sem solicitação explícita bloqueia o wrapper
$repo7 = Join-Path $tempRoot 'repo7'
$front7Dir = New-FrontWithObject -RepoRoot $repo7 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $newStamp
Write-FixtureAttribute -Folder $front7Dir -Name 'attrCrescimento' -Guid $attributeGuid6 -TypeValue 'bas:Numeric' -Length '12' -MaxLength '10'
$acervo7 = Join-Path $tempRoot 'acervo7'
New-AcervoWithObject -AcervoRoot $acervo7 -Name $objName -Guid $objGuid -LastUpdate $oldStamp
Write-FixtureAttribute -Folder (Join-Path $acervo7 'Attribute') -Name 'attrCrescimento' -Guid $attributeGuid6 -TypeValue 'bas:Numeric' -Length '10' -MaxLength '10'
$r7 = & $scriptPath -RepoRoot $repo7 -FrontName $frontName -AcervoPath $acervo7 | ConvertFrom-Json
$code7 = $LASTEXITCODE
if ($r7.status -ne 'bloqueado' -or $code7 -ne 20 -or $r7.stage -ne 'front-acervo-drift') {
    throw "Caso 7: crescimento sem solicitação explícita deveria bloquear no gate; status='$($r7.status)' exit='$code7' stage='$($r7.stage)'."
}
$growthFinding7 = @($r7.driftFindings | Where-Object { $_.code -eq 'front-attribute-size-growth-requires-user-request' } | Select-Object -First 1)
if ($growthFinding7.Count -ne 1 -or $growthFinding7[0].requiredApproval -ne "$attributeGuid6|Length|10|12") {
    throw 'Caso 7: gate deveria reportar a autorização exata necessária para o crescimento.'
}

# Caso 8: o wrapper repassa a entrada de autorização e continua bloqueando entrada malformada
$repo8 = Join-Path $tempRoot 'repo8'
$front8Dir = New-FrontWithObject -RepoRoot $repo8 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $newStamp
Write-FixtureAttribute -Folder $front8Dir -Name 'attrCrescimento' -Guid $attributeGuid6 -TypeValue 'bas:Numeric' -Length '12' -MaxLength '10'
$acervo8 = Join-Path $tempRoot 'acervo8'
New-AcervoWithObject -AcervoRoot $acervo8 -Name $objName -Guid $objGuid -LastUpdate $oldStamp
Write-FixtureAttribute -Folder (Join-Path $acervo8 'Attribute') -Name 'attrCrescimento' -Guid $attributeGuid6 -TypeValue 'bas:Numeric' -Length '10' -MaxLength '10'
$r8 = & $scriptPath -RepoRoot $repo8 -FrontName $frontName -AcervoPath $acervo8 -ApprovedAttributeSizeGrowth 'invalid' | ConvertFrom-Json
$code8 = $LASTEXITCODE
if ($r8.status -ne 'bloqueado' -or $code8 -ne 20 -or $r8.stage -ne 'front-acervo-drift') {
    throw "Caso 8: autorização malformada deveria bloquear no gate; status='$($r8.status)' exit='$code8' stage='$($r8.stage)'."
}
if (@($r8.driftFindings | Where-Object { $_.code -eq 'front-attribute-size-approval-invalid' }).Count -ne 1) {
    throw 'Caso 8: wrapper não repassou ou gate não identificou a autorização malformada.'
}

# Caso 9: mudança condicional Domain bloqueia no gate PowerShell e expõe contagem/findings
$repo9 = Join-Path $tempRoot 'repo9'
$front9Dir = New-FrontWithObject -RepoRoot $repo9 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $newStamp
$domainGuid9 = 'bbbbbbbb-1111-2222-3333-444444444444'
$domainName9 = 'DomainWrapperTeste'
$domainFront9 = New-FixtureDomainXml -Name $domainName9 -Guid $domainGuid9 -Description 'descrição nova' -LastUpdate $newStamp
$domainBase9 = New-FixtureDomainXml -Name $domainName9 -Guid $domainGuid9 -Description 'descrição antiga' -LastUpdate $oldStamp
[System.IO.File]::WriteAllText((Join-Path $front9Dir "$domainName9.xml"), $domainFront9, (Get-Utf8NoBomEncoding))
$acervo9 = Join-Path $tempRoot 'acervo9'
New-AcervoWithObject -AcervoRoot $acervo9 -Name $objName -Guid $objGuid -LastUpdate $oldStamp
Write-FixtureDomain -AcervoRoot $acervo9 -Name $domainName9 -Xml $domainBase9
$r9 = & $scriptPath -RepoRoot $repo9 -FrontName $frontName -AcervoPath $acervo9 | ConvertFrom-Json
$code9 = $LASTEXITCODE
if ($r9.status -ne 'bloqueado' -or $code9 -ne 20 -or $r9.stage -ne 'front-acervo-drift') {
    throw "Caso 9: mudança Domain sem aprovação deveria bloquear no gate; status='$($r9.status)' exit='$code9' stage='$($r9.stage)'."
}
if ($r9.driftDomainsScanned -ne 1) {
    throw "Caso 9: driftDomainsScanned deveria ser 1; obtido '$($r9.driftDomainsScanned)'."
}
if (@($r9.driftFindings | Where-Object { $_.code -eq 'domain-change-requires-confirmation' }).Count -ne 1) {
    throw "Caso 9: driftFindings deveria expor a confirmação condicional de Domain; codes='$(@($r9.driftFindings | ForEach-Object { $_.code }) -join ',')'."
}
if ($null -ne $r9.PSObject.Properties['packageInventory']) {
    throw 'Caso 9: gate Domain deveria bloquear antes de executar o motor Python.'
}

# Caso 10: aprovação exata é repassada; o gate passa e o resultado preserva contagem/evidência
$repo10 = Join-Path $tempRoot 'repo10'
$front10Dir = New-FrontWithObject -RepoRoot $repo10 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $newStamp
$domainGuid10 = 'cccccccc-1111-2222-3333-444444444444'
$domainName10 = 'DomainWrapperAprovado'
$domainFront10 = New-FixtureDomainXml -Name $domainName10 -Guid $domainGuid10 -Description 'descrição nova' -LastUpdate $newStamp
$domainBase10 = New-FixtureDomainXml -Name $domainName10 -Guid $domainGuid10 -Description 'descrição antiga' -LastUpdate $oldStamp
[System.IO.File]::WriteAllText((Join-Path $front10Dir "$domainName10.xml"), $domainFront10, (Get-Utf8NoBomEncoding))
$acervo10 = Join-Path $tempRoot 'acervo10'
New-AcervoWithObject -AcervoRoot $acervo10 -Name $objName -Guid $objGuid -LastUpdate $oldStamp
Write-FixtureDomain -AcervoRoot $acervo10 -Name $domainName10 -Xml $domainBase10
$approval10 = [ordered]@{
    kind = 'domain-drift-approvals'
    schemaVersion = 1
    approvals = @([ordered]@{
        objectGuid = $domainGuid10
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
$approvalPath10 = Join-Path $tempRoot 'domain-approval-exact.json'
[System.IO.File]::WriteAllText($approvalPath10, (ConvertTo-Json -InputObject $approval10 -Depth 8), (Get-Utf8NoBomEncoding))
$r10 = & $scriptPath -RepoRoot $repo10 -FrontName $frontName -AcervoPath $acervo10 -ApprovedDomainChangesPath $approvalPath10 | ConvertFrom-Json
$code10 = $LASTEXITCODE
if ($r10.driftStatus -ne 'pass' -or $r10.driftDomainsScanned -ne 1) {
    throw "Caso 10: aprovação exata deveria liberar o gate e preservar a contagem Domain; driftStatus='$($r10.driftStatus)' domains='$($r10.driftDomainsScanned)'."
}
if (@($r10.driftFindings | Where-Object { $_.code -eq 'domain-change-approved' }).Count -ne 1) {
    throw 'Caso 10: driftFindings deveria preservar a aprovação exata reconhecida pelo gate.'
}
if ($code10 -eq 20 -and $r10.stage -eq 'front-acervo-drift') {
    throw 'Caso 10: gate do wrapper não pode bloquear uma mudança Domain coberta pela aprovação exata.'
}

# Caso 11: duas aprovações exatas de tamanho atravessam o wrapper pelo payload escalar.
$repo11 = Join-Path $tempRoot 'repo11'
$front11Dir = New-FrontWithObject -RepoRoot $repo11 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $newStamp
$attributeName11A = 'attrCrescimentoA'
$attributeGuid11A = 'dddddddd-bbbb-cccc-dddd-eeeeeeeeeeee'
$attributeName11B = 'attrCrescimentoB'
$attributeGuid11B = 'eeeeeeee-bbbb-cccc-dddd-ffffffffffff'
Write-FixtureAttribute -Folder $front11Dir -Name $attributeName11A -Guid $attributeGuid11A -TypeValue 'bas:Numeric' -Length '12' -MaxLength '10'
Write-FixtureAttribute -Folder $front11Dir -Name $attributeName11B -Guid $attributeGuid11B -TypeValue 'bas:Numeric' -Length '10' -MaxLength '24'
$acervo11 = Join-Path $tempRoot 'acervo11'
New-AcervoWithObject -AcervoRoot $acervo11 -Name $objName -Guid $objGuid -LastUpdate $oldStamp
Write-FixtureAttribute -Folder (Join-Path $acervo11 'Attribute') -Name $attributeName11A -Guid $attributeGuid11A -TypeValue 'bas:Numeric' -Length '10' -MaxLength '10'
Write-FixtureAttribute -Folder (Join-Path $acervo11 'Attribute') -Name $attributeName11B -Guid $attributeGuid11B -TypeValue 'bas:Numeric' -Length '10' -MaxLength '20'
$approval11A = "$attributeGuid11A|Length|10|12"
$approval11B = "$attributeGuid11B|AttMaxLen|20|24"
$r11 = & $scriptPath -RepoRoot $repo11 -FrontName $frontName -AcervoPath $acervo11 -ApprovedAttributeSizeGrowth @($approval11A, $approval11B) | ConvertFrom-Json
$code11 = $LASTEXITCODE
$authorizedFindings11 = @($r11.driftFindings | Where-Object { $_.code -eq 'front-attribute-size-growth-authorized' })
if ($r11.driftStatus -ne 'pass' -or $r11.stage -eq 'front-acervo-drift' -or $authorizedFindings11.Count -ne 2) {
    throw "Caso 11: duas aprovações exatas deveriam passar pelo wrapper; status='$($r11.status)' driftStatus='$($r11.driftStatus)' exit='$code11' aprovações aceitas='$($authorizedFindings11.Count)'."
}
if (@($authorizedFindings11 | ForEach-Object { $_.objectGuid } | Sort-Object -Unique).Count -ne 2) {
    throw 'Caso 11: o gate não preservou as duas identidades Attribute aprovadas.'
}

# Caso 12: GUID de Domain no PackagedModule com estrutura real bloqueia antes do motor Python.
$repo12 = Join-Path $tempRoot 'repo12'
$front12Dir = New-FrontWithObject -RepoRoot $repo12 -FrontName $frontName -Name $objName -Guid $objGuid -LastUpdate $newStamp
$domainGuid12 = 'f0123456-1111-2222-3333-444444444444'
$domainName12 = 'DomainWrapperEmbutido'
$domainFront12 = New-FixtureDomainXml -Name $domainName12 -Guid $domainGuid12 -Description 'Domain autônomo' -LastUpdate $newStamp
[System.IO.File]::WriteAllText((Join-Path $front12Dir "$domainName12.xml"), $domainFront12, (Get-Utf8NoBomEncoding))
$acervo12 = Join-Path $tempRoot 'acervo12'
New-AcervoWithObject -AcervoRoot $acervo12 -Name $objName -Guid $objGuid -LastUpdate $oldStamp
[void](New-Item -ItemType Directory -Path (Join-Path $acervo12 'Domain') -Force)
$packagedModuleXml12 = '<Object type="c88fffcd-b6f8-0000-8fec-00b5497e2117" name="Package" guid="e0123456-aaaa-bbbb-cccc-123456789abc"><Part type="ed1b7b1c-2aaf-46eb-9ec5-db348f6fa3fc"><ExportFile><Objects>' +
    $domainFront12 +
    '</Objects></ExportFile></Part></Object>'
$packagedModuleDir12 = Join-Path $acervo12 'PackagedModule'
[void](New-Item -ItemType Directory -Path $packagedModuleDir12 -Force)
[System.IO.File]::WriteAllText((Join-Path $packagedModuleDir12 'Package.xml'), $packagedModuleXml12, (Get-Utf8NoBomEncoding))
$r12 = & $scriptPath -RepoRoot $repo12 -FrontName $frontName -AcervoPath $acervo12 | ConvertFrom-Json
$code12 = $LASTEXITCODE
if ($r12.status -ne 'bloqueado' -or $code12 -ne 20 -or $r12.stage -ne 'front-acervo-drift' -or $r12.driftStatus -ne 'fail') {
    throw "Caso 12: GUID Domain embutido deveria bloquear no gate; status='$($r12.status)' exit='$code12' stage='$($r12.stage)' driftStatus='$($r12.driftStatus)'."
}
if ($r12.driftDomainsScanned -ne 1 -or @($r12.driftFindings | Where-Object { $_.code -eq 'front-domain-packagedmodule-identity-collision' }).Count -ne 1) {
    throw 'Caso 12: wrapper deveria expor a contagem Domain e a colisão encontrada no PackagedModule.'
}
if ($null -ne $r12.PSObject.Properties['packageInventory']) {
    throw 'Caso 12: colisão Domain embutida deveria bloquear antes de executar o motor Python.'
}

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OK: Test-NewXpzImportPackageDriftSelfTest.ps1'
exit 0
