#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do gate 9-FD para drift de Object/@type entre frente e acervo.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$gateScript = Join-Path $scriptDir 'Test-GeneXusFrontAcervoDrift.ps1'
$encodingSupportPath = Join-Path $scriptDir 'Utf8NoBomEncodingSupport.ps1'

if (-not (Test-Path -LiteralPath $gateScript -PathType Leaf)) {
    throw "Gate script not found: $gateScript"
}
if (-not (Test-Path -LiteralPath $encodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $encodingSupportPath"
}
. $encodingSupportPath

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

function Write-Utf8NoBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, (Get-Utf8NoBomEncoding))
}

function New-FixtureObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeGuid,
        [Parameter(Mandatory = $true)][string]$LastUpdate
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

function Write-FixtureObject {
    param(
        [Parameter(Mandatory = $true)][string]$Folder,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeGuid,
        [Parameter(Mandatory = $true)][string]$LastUpdate
    )

    [void](New-Item -ItemType Directory -Path $Folder -Force)
    Write-Utf8NoBomText -Path (Join-Path $Folder "$Name.xml") -Content (New-FixtureObjectXml -Name $Name -Guid $Guid -TypeGuid $TypeGuid -LastUpdate $LastUpdate)
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-front-acervo-drift-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))

try {
    $procedureTypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
    $webPanelTypeGuid = '7a7686a8-90de-4598-9406-014bcbcf3d82'
    $guid = '11111111-1111-1111-1111-111111111111'
    $oldStamp = '2026-01-01T00:00:00.0000000Z'
    $newStamp = '2026-01-01T00:02:00.0000000Z'

    $front1 = Join-Path $tempRoot 'case1-front'
    $acervo1 = Join-Path $tempRoot 'case1-acervo'
    Write-FixtureObject -Folder $front1 -Name 'ObjDrift' -Guid $guid -TypeGuid $webPanelTypeGuid -LastUpdate $newStamp
    Write-FixtureObject -Folder (Join-Path $acervo1 'Procedure') -Name 'ObjDrift' -Guid $guid -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp
    $r1 = & $gateScript -FrontFolder $front1 -AcervoFolder $acervo1 -AsJson | ConvertFrom-Json
    Assert-True ($r1.status -eq 'fail') "Caso 1: status esperado fail; obtido $($r1.status)"
    $r1Codes = @($r1.findings | ForEach-Object { $_.code })
    Assert-True ($r1Codes -contains 'front-object-type-drift') 'Caso 1: finding front-object-type-drift ausente.'
    Assert-True ($r1Codes -notcontains 'front-newer-than-acervo') 'Caso 1: front-newer-than-acervo deveria ser suprimido quando ha drift fatal de tipo.'
    $typeFinding = @($r1.findings | Where-Object { $_.code -eq 'front-object-type-drift' } | Select-Object -First 1)[0]
    Assert-True ($typeFinding.matchBasis -eq 'guid') "Caso 1: matchBasis esperado guid; obtido $($typeFinding.matchBasis)"
    Assert-True ($typeFinding.objectGuid -eq $guid) "Caso 1: objectGuid normalizado esperado $guid; obtido $($typeFinding.objectGuid)"
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$typeFinding.message)) 'Caso 1: finding fatal deveria preservar message.'
    Assert-True ($typeFinding.acervoPath -eq 'Procedure/ObjDrift.xml') "Caso 1: acervoPath relativo inesperado: $($typeFinding.acervoPath)"
    Assert-True ($typeFinding.frontObjectTypeNormalized -eq $webPanelTypeGuid) 'Caso 1: tipo normalizado da frente nao preservado.'
    Assert-True ($typeFinding.acervoObjectTypeNormalized -eq $procedureTypeGuid) 'Caso 1: tipo normalizado do acervo nao preservado.'
    Assert-PropertyAbsent -Object $typeFinding -PropertyName 'acervoFile' -Message 'Caso 1: finding novo de type drift nao deve emitir acervoFile.'
    foreach ($legacyName in @('frontGuid', 'baselinePath', 'candidateBaselinePaths', 'baselineObjectType', 'baselineObjectTypeNormalized')) {
        Assert-PropertyAbsent -Object $typeFinding -PropertyName $legacyName -Message "Caso 1: finding novo de type drift nao deve emitir $legacyName."
    }

    $front2 = Join-Path $tempRoot 'case2-front'
    $acervo2 = Join-Path $tempRoot 'case2-acervo'
    Write-FixtureObject -Folder $front2 -Name 'ObjDriftOld' -Guid $guid -TypeGuid $webPanelTypeGuid -LastUpdate $oldStamp
    Write-FixtureObject -Folder (Join-Path $acervo2 'Procedure') -Name 'ObjDriftOld' -Guid $guid -TypeGuid $procedureTypeGuid -LastUpdate $newStamp
    $r2 = & $gateScript -FrontFolder $front2 -AcervoFolder $acervo2 -AsJson | ConvertFrom-Json
    $r2Codes = @($r2.findings | ForEach-Object { $_.code })
    Assert-True ($r2Codes -contains 'front-object-type-drift') 'Caso 2: drift de tipo deveria coexistir com lastUpdate antigo.'
    Assert-True ($r2Codes -contains 'front-older-than-acervo') 'Caso 2: front-older-than-acervo deveria ser preservado.'

    $front3 = Join-Path $tempRoot 'case3-front'
    $acervo3 = Join-Path $tempRoot 'case3-acervo'
    Write-FixtureObject -Folder $front3 -Name 'ObjAmbiguo' -Guid $guid -TypeGuid $webPanelTypeGuid -LastUpdate $newStamp
    Write-FixtureObject -Folder (Join-Path $acervo3 'ProcedureA') -Name 'ObjAmbiguo' -Guid $guid -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp
    Write-FixtureObject -Folder (Join-Path $acervo3 'ProcedureB') -Name 'ObjAmbiguoCopia' -Guid $guid -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp
    $r3 = & $gateScript -FrontFolder $front3 -AcervoFolder $acervo3 -AsJson | ConvertFrom-Json
    $r3Codes = @($r3.findings | ForEach-Object { $_.code })
    Assert-True ($r3Codes -contains 'front-object-type-drift-ambiguous-acervo') 'Caso 3: ambiguidade por GUID deveria gerar diagnostico nao fatal.'
    Assert-True ($r3Codes -notcontains 'front-object-type-drift') 'Caso 3: ambiguidade nao deveria afirmar drift fatal.'
    $ambiguousFinding = @($r3.findings | Where-Object { $_.code -eq 'front-object-type-drift-ambiguous-acervo' } | Select-Object -First 1)[0]
    Assert-True ($ambiguousFinding.severity -eq 'info') "Caso 3: ambiguidade deveria ser info; obtido $($ambiguousFinding.severity)."
    Assert-True ($ambiguousFinding.objectGuid -eq $guid) "Caso 3: objectGuid normalizado esperado $guid; obtido $($ambiguousFinding.objectGuid)"
    Assert-True ($ambiguousFinding.matchBasis -eq 'guid-ambiguous') "Caso 3: matchBasis esperado guid-ambiguous; obtido $($ambiguousFinding.matchBasis)."
    Assert-True ((@($ambiguousFinding.candidateAcervoPaths)).Count -eq 2) 'Caso 3: candidateAcervoPaths deveria ter dois candidatos.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$ambiguousFinding.message)) 'Caso 3: ambiguidade deveria preservar message.'
    Assert-PropertyAbsent -Object $ambiguousFinding -PropertyName 'acervoObjectType' -Message 'Caso 3: ambiguidade nao deve escolher acervoObjectType arbitrario.'
    Assert-PropertyAbsent -Object $ambiguousFinding -PropertyName 'acervoObjectTypeNormalized' -Message 'Caso 3: ambiguidade nao deve escolher acervoObjectTypeNormalized arbitrario.'
    foreach ($legacyName in @('frontGuid', 'baselinePath', 'candidateBaselinePaths', 'baselineObjectType', 'baselineObjectTypeNormalized')) {
        Assert-PropertyAbsent -Object $ambiguousFinding -PropertyName $legacyName -Message "Caso 3: ambiguidade nao deve emitir $legacyName."
    }

    $front4 = Join-Path $tempRoot 'case4-front'
    $acervo4 = Join-Path $tempRoot 'case4-acervo'
    Write-FixtureObject -Folder $front4 -Name 'ObjNominal' -Guid '22222222-2222-2222-2222-222222222222' -TypeGuid $webPanelTypeGuid -LastUpdate $newStamp
    Write-FixtureObject -Folder (Join-Path $acervo4 'Procedure') -Name 'ObjNominal' -Guid '33333333-3333-3333-3333-333333333333' -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp
    $r4 = & $gateScript -FrontFolder $front4 -AcervoFolder $acervo4 -AsJson | ConvertFrom-Json
    $r4Codes = @($r4.findings | ForEach-Object { $_.code })
    Assert-True ($r4Codes -notcontains 'front-object-type-drift') 'Caso 4: match nominal sem GUID igual nao deve gerar drift de tipo.'

    Write-Output 'GENEXUS_FRONT_ACERVO_DRIFT_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
