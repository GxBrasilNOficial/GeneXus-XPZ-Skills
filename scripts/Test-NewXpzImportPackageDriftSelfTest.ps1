#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do contrato fail-closed de drift frente-vs-acervo em New-XpzImportPackage.ps1.

.DESCRIPTION
    Cobre os tres caminhos da resolucao de acervo, todos saindo ANTES do motor
    Python (sem dependencia de python no ambiente):
      1. Sem -AcervoPath e sem acervo canonico -> bloqueado, footgun nomeado,
         acervoResolvedBy=null.
      2. Sem -AcervoPath, acervo canonico <RepoRoot>/ObjetosDaKbEmXml presente com
         objeto mais novo que a frente -> bloqueado por drift, acervoResolvedBy=convention.
      3. -AcervoPath explicito com objeto mais novo que a frente -> bloqueado por
         drift, acervoResolvedBy=explicit.
      4. -AcervoPath explicito com mesmo guid e Object/@type divergente -> bloqueado
         antes do motor Python, com campos estruturados preservados em driftFindings.
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
if ($typeFinding4[0].frontObjectTypeNormalized -ne $webPanelTypeGuid) {
    throw "Caso 4: frontObjectTypeNormalized inesperado: '$($typeFinding4[0].frontObjectTypeNormalized)'."
}
if ($typeFinding4[0].acervoObjectTypeNormalized -ne $procedureTypeGuid) {
    throw "Caso 4: acervoObjectTypeNormalized inesperado: '$($typeFinding4[0].acervoObjectTypeNormalized)'."
}

Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Output 'OK: Test-NewXpzImportPackageDriftSelfTest.ps1'
exit 0
