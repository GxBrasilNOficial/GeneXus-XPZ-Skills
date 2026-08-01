#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do gate 9-FD para drift frente-vs-acervo e fidelidade textual parcial.

.DESCRIPTION
    Cobre lastUpdate, Object/@type, GUID ambiguo e a protecao textual parcial contra
    remocao forte de trailing whitespace herdado, incluindo o finding informativo de
    falha de leitura/decodificacao UTF-8 comparavel.
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

function Write-Utf8BomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($true))
}

function Write-Utf16LeBomText {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UnicodeEncoding]::new($false, $true))
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

function New-TextualFidelityFixtureObjectXml {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][string]$TypeGuid,
        [Parameter(Mandatory = $true)][string]$LastUpdate,
        [int]$TrailingWhitespaceLines = 0,
        [switch]$TrimTrailingWhitespace,
        [int]$FunctionalChanges = 0,
        [int]$StableLines = 0
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $rootLine = "<Object type=""$TypeGuid"" name=""$Name"" guid=""$Guid"" fullyQualifiedName=""$Name"" lastUpdate=""$LastUpdate"">"
    if ($TrailingWhitespaceLines -gt 0 -and -not $TrimTrailingWhitespace) { $rootLine += '  ' }
    $lines.Add($rootLine) | Out-Null
    $lines.Add('  <Properties>') | Out-Null
    $lines.Add('    <Property>') | Out-Null
    $lines.Add('      <Name>Name</Name>') | Out-Null
    $lines.Add("      <Value>$Name</Value>") | Out-Null
    $lines.Add('    </Property>') | Out-Null
    for ($i = 1; $i -le $TrailingWhitespaceLines; $i++) {
        $value = "      <Property><Name>P$i</Name><Value>V$i</Value></Property>"
        if (-not $TrimTrailingWhitespace) { $value += '  ' }
        $lines.Add($value) | Out-Null
    }
    for ($i = 1; $i -le $FunctionalChanges; $i++) {
        $lines.Add("      <Property><Name>Func$i</Name><Value>$Name-$i</Value></Property>") | Out-Null
    }
    for ($i = 1; $i -le $StableLines; $i++) {
        $lines.Add("      <Property><Name>Stable$i</Name><Value>Stable$i</Value></Property>") | Out-Null
    }
    $lines.Add('  </Properties>') | Out-Null
    $lines.Add('  <Source><![CDATA[]]></Source>') | Out-Null
    $lines.Add('</Object>') | Out-Null
    return ($lines -join "`n") + "`n"
}

function Write-FixtureObjectContent {
    param(
        [Parameter(Mandatory = $true)][string]$Folder,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$Utf8Bom
    )

    [void](New-Item -ItemType Directory -Path $Folder -Force)
    $path = Join-Path $Folder "$Name.xml"
    if ($Utf8Bom) {
        Write-Utf8BomText -Path $path -Content $Content
    } else {
        Write-Utf8NoBomText -Path $path -Content $Content
    }
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
    Assert-True ($r3Codes -notcontains 'front-textual-fidelity-info') 'Caso 3: GUID ambiguo nao deve emitir front-textual-fidelity-info.'
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

    $front5 = Join-Path $tempRoot 'case5-front'
    $acervo5 = Join-Path $tempRoot 'case5-acervo'
    $obj5 = 'ObjTrimGlobal'
    $guid5 = '55555555-5555-5555-5555-555555555555'
    $acervo5Xml = New-TextualFidelityFixtureObjectXml -Name $obj5 -Guid $guid5 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -TrailingWhitespaceLines 40
    $front5Xml = New-TextualFidelityFixtureObjectXml -Name $obj5 -Guid $guid5 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -TrailingWhitespaceLines 40 -TrimTrailingWhitespace -FunctionalChanges 2
    Write-FixtureObjectContent -Folder $front5 -Name $obj5 -Content $front5Xml
    Write-FixtureObjectContent -Folder (Join-Path $acervo5 'Procedure') -Name $obj5 -Content $acervo5Xml
    $r5 = & $gateScript -FrontFolder $front5 -AcervoFolder $acervo5 -AsJson | ConvertFrom-Json
    Assert-True ($r5.objectsScanned -eq 1) "Caso 5: objectsScanned esperado 1; obtido $($r5.objectsScanned)"
    Assert-True ($r5.status -eq 'fail') "Caso 5: status fail esperado; obtido $($r5.status)"
    $textFinding5 = @($r5.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' } | Select-Object -First 1)
    Assert-True ($textFinding5.Count -eq 1) 'Caso 5: finding de trim global forte ausente.'
    Assert-True ($textFinding5[0].classification -eq 'trim-removal-churn') "Caso 5: classification inesperado: $($textFinding5[0].classification)"
    Assert-True ($textFinding5[0].whitespaceTrimPairCount -ge 40) "Caso 5: contagem de trim inesperada: $($textFinding5[0].whitespaceTrimPairCount)"
    Assert-True ($null -ne $textFinding5[0].functionalChangedLineEstimate) 'Caso 5: functionalChangedLineEstimate ausente.'
    Assert-True ($textFinding5[0].acervoLineCount -gt 0) "Caso 5: acervoLineCount inesperado: $($textFinding5[0].acervoLineCount)"
    Assert-True ($null -ne $textFinding5[0].thresholds) 'Caso 5: thresholds ausente.'
    Assert-True ($textFinding5[0].thresholds.MinWhitespaceChurnLines -eq 25) "Caso 5: thresholds.MinWhitespaceChurnLines inesperado: $($textFinding5[0].thresholds.MinWhitespaceChurnLines)"
    Assert-True ($textFinding5[0].thresholds.ChurnDominanceFactor -eq 3) "Caso 5: thresholds.ChurnDominanceFactor inesperado: $($textFinding5[0].thresholds.ChurnDominanceFactor)"
    Assert-True ([double]$textFinding5[0].thresholds.GlobalTrimRatio -eq 0.50) "Caso 5: thresholds.GlobalTrimRatio inesperado: $($textFinding5[0].thresholds.GlobalTrimRatio)"

    $front6 = Join-Path $tempRoot 'case6-front'
    $acervo6 = Join-Path $tempRoot 'case6-acervo'
    $obj6 = 'ObjTrimGlobalRatio'
    $guid6 = '66666666-6666-6666-6666-666666666666'
    $acervo6Xml = New-TextualFidelityFixtureObjectXml -Name $obj6 -Guid $guid6 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -TrailingWhitespaceLines 40
    $front6Xml = New-TextualFidelityFixtureObjectXml -Name $obj6 -Guid $guid6 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -TrailingWhitespaceLines 40 -TrimTrailingWhitespace -FunctionalChanges 20
    Write-FixtureObjectContent -Folder $front6 -Name $obj6 -Content $front6Xml
    Write-FixtureObjectContent -Folder (Join-Path $acervo6 'Procedure') -Name $obj6 -Content $acervo6Xml
    $r6 = & $gateScript -FrontFolder $front6 -AcervoFolder $acervo6 -AsJson | ConvertFrom-Json
    Assert-True ($r6.objectsScanned -eq 1) "Caso 6: objectsScanned esperado 1; obtido $($r6.objectsScanned)"
    Assert-True (@($r6.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' }).Count -eq 1) 'Caso 6: trim forte por proporcao do acervo deveria falhar.'

    $front7 = Join-Path $tempRoot 'case7-front'
    $acervo7 = Join-Path $tempRoot 'case7-acervo'
    $obj7 = 'ObjSemBaseline'
    [void](New-Item -ItemType Directory -Path $acervo7 -Force)
    Write-FixtureObject -Folder $front7 -Name $obj7 -Guid '77777777-7777-7777-7777-777777777777' -TypeGuid $procedureTypeGuid -LastUpdate $newStamp
    $r7 = & $gateScript -FrontFolder $front7 -AcervoFolder $acervo7 -AsJson | ConvertFrom-Json
    $r7Codes = @($r7.findings | ForEach-Object { $_.code })
    Assert-True ($r7.status -ne 'fail') "Caso 7: objeto novo sem baseline nao deveria falhar; obtido $($r7.status)"
    Assert-True ($r7Codes -contains 'front-only-new-object') 'Caso 7: front-only-new-object esperado.'
    Assert-True ($r7Codes -notcontains 'front-textual-fidelity-info') 'Caso 7: objeto novo sem baseline nao deve emitir finding textual extra.'

    $front8 = Join-Path $tempRoot 'case8-front'
    $acervo8 = Join-Path $tempRoot 'case8-acervo'
    $obj8 = 'ObjDeltaDominante'
    $guid8 = '88888888-8888-8888-8888-888888888888'
    $acervo8Xml = New-TextualFidelityFixtureObjectXml -Name $obj8 -Guid $guid8 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -TrailingWhitespaceLines 5 -StableLines 40
    $front8Xml = New-TextualFidelityFixtureObjectXml -Name $obj8 -Guid $guid8 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -TrailingWhitespaceLines 5 -TrimTrailingWhitespace -FunctionalChanges 40 -StableLines 40
    Write-FixtureObjectContent -Folder $front8 -Name $obj8 -Content $front8Xml
    Write-FixtureObjectContent -Folder (Join-Path $acervo8 'Procedure') -Name $obj8 -Content $acervo8Xml
    $r8 = & $gateScript -FrontFolder $front8 -AcervoFolder $acervo8 -AsJson | ConvertFrom-Json
    Assert-True ($r8.objectsScanned -eq 1) "Caso 8: objectsScanned esperado 1; obtido $($r8.objectsScanned)"
    Assert-True (@($r8.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' }).Count -eq 0) 'Caso 8: delta funcional dominante com poucos trims nao deveria bloquear por fidelidade textual.'

    $front9 = Join-Path $tempRoot 'case9-front'
    $acervo9 = Join-Path $tempRoot 'case9-acervo'
    $obj9 = 'ObjBomUtf8'
    $guid9 = '99999999-9999-9999-9999-999999999999'
    $same9Acervo = New-TextualFidelityFixtureObjectXml -Name $obj9 -Guid $guid9 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -StableLines 5
    $same9Front = New-TextualFidelityFixtureObjectXml -Name $obj9 -Guid $guid9 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -StableLines 5
    Write-FixtureObjectContent -Folder $front9 -Name $obj9 -Content $same9Front -Utf8Bom
    Write-FixtureObjectContent -Folder (Join-Path $acervo9 'Procedure') -Name $obj9 -Content $same9Acervo
    $r9 = & $gateScript -FrontFolder $front9 -AcervoFolder $acervo9 -AsJson | ConvertFrom-Json
    Assert-True ($r9.objectsScanned -eq 1) "Caso 9: objectsScanned esperado 1; obtido $($r9.objectsScanned)"
    Assert-True (@($r9.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' }).Count -eq 0) 'Caso 9: BOM UTF-8 unilateral nao deve criar residuo funcional nem trim churn.'

    $front10 = Join-Path $tempRoot 'case10-front'
    $acervo10 = Join-Path $tempRoot 'case10-acervo'
    $obj10 = 'ObjUtf16Info'
    $guid10 = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    $same10Acervo = New-TextualFidelityFixtureObjectXml -Name $obj10 -Guid $guid10 -TypeGuid $procedureTypeGuid -LastUpdate $oldStamp -StableLines 5
    $same10Front = New-TextualFidelityFixtureObjectXml -Name $obj10 -Guid $guid10 -TypeGuid $procedureTypeGuid -LastUpdate $newStamp -StableLines 5
    Write-FixtureObjectContent -Folder $front10 -Name $obj10 -Content $same10Front
    $acervo10ObjectFolder = Join-Path $acervo10 'Procedure'
    [void](New-Item -ItemType Directory -Path $acervo10ObjectFolder -Force)
    Write-Utf16LeBomText -Path (Join-Path $acervo10ObjectFolder "$obj10.xml") -Content $same10Acervo
    $r10 = & $gateScript -FrontFolder $front10 -AcervoFolder $acervo10 -AsJson | ConvertFrom-Json
    Assert-True ($r10.objectsScanned -eq 1) "Caso 10: objectsScanned esperado 1; obtido $($r10.objectsScanned)"
    Assert-True ($r10.status -ne 'fail') "Caso 10: comparacao textual informativa nao deveria falhar; obtido $($r10.status)"
    $infoFinding10 = @($r10.findings | Where-Object { $_.code -eq 'front-textual-fidelity-info' } | Select-Object -First 1)
    Assert-True ($infoFinding10.Count -eq 1) 'Caso 10: front-textual-fidelity-info esperado quando baseline por GUID existe mas leitura UTF-8 comparavel falha.'
    Assert-True ($infoFinding10[0].classification -eq 'not-applicable') "Caso 10: classification inesperado: $($infoFinding10[0].classification)"
    Assert-True ([string]$infoFinding10[0].reason -match 'acervo=utf-16-le-bom') "Caso 10: reason deveria registrar acervo=utf-16-le-bom; obtido $($infoFinding10[0].reason)"
    Assert-True (@($r10.findings | Where-Object { $_.code -eq 'front-textual-fidelity-trim-removal-churn' }).Count -eq 0) 'Caso 10: info textual nao deve emitir bloqueio de trim churn.'

    Write-Output 'GENEXUS_FRONT_ACERVO_DRIFT_SELFTEST_OK'
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
