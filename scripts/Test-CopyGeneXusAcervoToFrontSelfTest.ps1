#requires -Version 7.4
<#
.SYNOPSIS
    Regressões sanitizadas de seleção, identidade, reserva física e tempo do Copy.
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
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Guid,
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

$scriptPath = Join-Path $PSScriptRoot 'Copy-GeneXusAcervoToFront.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('copy-acervo-front-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
$acervo = Join-Path $tempRoot 'ObjetosDaKbEmXml'
$procedureDir = Join-Path $acervo 'Procedure'
$frontEmpty = Join-Path $tempRoot 'FrontEmpty'
$frontSeed = Join-Path $tempRoot 'FrontSeed'
$frontSeedObjectList = Join-Path $tempRoot 'FrontSeedObjectList'
$frontSeedGuid = Join-Path $tempRoot 'FrontSeedGuid'
$frontMissing = Join-Path $tempRoot 'FrontMissing'
$frontTypeDrift = Join-Path $tempRoot 'FrontTypeDrift'
$frontExplicitNewer = Join-Path $tempRoot 'FrontExplicitNewer'
$frontExplicitNewerDryRun = Join-Path $tempRoot 'FrontExplicitNewerDryRun'
[void](New-Item -ItemType Directory -Path $procedureDir, $frontEmpty, $frontSeed, $frontSeedObjectList, $frontSeedGuid, $frontMissing, $frontTypeDrift, $frontExplicitNewer, $frontExplicitNewerDryRun -Force)

$objName = 'procSeedTeste'
$objGuid = '11111111-1111-1111-1111-111111111111'
$procedureTypeGuid = '84a12160-f59b-4ad7-a683-ea4481ac23e9'
$webPanelTypeGuid = '7a7686a8-90de-4598-9406-014bcbcf3d82'
$objXml = New-FixtureObjectXml -Name $objName -Guid $objGuid -LastUpdate '2026-01-01T00:00:00.0000000Z'
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$objName.xml"), $objXml, (Get-Utf8NoBomEncoding))

$objGuidName = 'procSeedPorGuid'
$objGuidOnly = '22222222-2222-2222-2222-222222222222'
$objGuidXml = New-FixtureObjectXml -Name $objGuidName -Guid $objGuidOnly -LastUpdate '2026-01-02T00:00:00.0000000Z'
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$objGuidName.xml"), $objGuidXml, (Get-Utf8NoBomEncoding))

$emptyResult = & $scriptPath -FrontFolder $frontEmpty -AcervoFolder $acervo | ConvertFrom-Json
if ($emptyResult.status -ne 'not-applicable') {
    throw "Frente vazia sem alvo explicito deveria retornar not-applicable; obtido $($emptyResult.status)"
}
if ((Test-Path -LiteralPath (Join-Path $frontEmpty "$objName.xml") -PathType Leaf)) {
    throw 'Frente vazia sem alvo explicito nao deveria receber seed.'
}

$seedResult = & $scriptPath -FrontFolder $frontSeed -AcervoFolder $acervo -ObjectNames $objName | ConvertFrom-Json
if ($seedResult.status -ne 'pass') {
    throw "Seed explicito deveria retornar pass; obtido $($seedResult.status)"
}
$seedFinding = @($seedResult.findings | Where-Object { $_.code -eq 'seeded-and-bumped' })
if ($seedFinding.Count -ne 1) {
    throw "Seed explicito deveria gerar uma finding seeded-and-bumped; obtido $($seedFinding.Count)"
}
$seededPath = Join-Path $frontSeed "$objName.xml"
if (-not (Test-Path -LiteralPath $seededPath -PathType Leaf)) {
    throw 'Seed explicito nao criou XML na frente.'
}
$seededText = Get-Content -LiteralPath $seededPath -Raw -Encoding UTF8
if ($seededText -notmatch 'lastUpdate="([^"]+)"') {
    throw 'XML semeado nao contem lastUpdate.'
}
if ($Matches[1] -eq '2026-01-01T00:00:00.0000000Z') {
    throw 'Seed explicito deveria bumpar lastUpdate acima do acervo.'
}

$seedObjectListResult = & $scriptPath -FrontFolder $frontSeedObjectList -AcervoFolder $acervo -ObjectList "Procedure:$objName" | ConvertFrom-Json
if ($seedObjectListResult.status -ne 'pass') {
    throw "Seed explicito via ObjectList deveria retornar pass; obtido $($seedObjectListResult.status)"
}
$seedObjectListFinding = @($seedObjectListResult.findings | Where-Object { $_.code -eq 'seeded-and-bumped' -and $_.objectName -eq $objName })
if ($seedObjectListFinding.Count -ne 1) {
    throw "Seed via ObjectList deveria gerar uma finding seeded-and-bumped; obtido $($seedObjectListFinding.Count)"
}
if (-not (Test-Path -LiteralPath (Join-Path $frontSeedObjectList "$objName.xml") -PathType Leaf)) {
    throw 'Seed via ObjectList nao criou XML na frente.'
}

$seedGuidResult = & $scriptPath -FrontFolder $frontSeedGuid -AcervoFolder $acervo -ObjectGuids $objGuidOnly | ConvertFrom-Json
if ($seedGuidResult.status -ne 'pass') {
    throw "Seed explicito por GUID deveria retornar pass; obtido $($seedGuidResult.status)"
}
$seedGuidFinding = @($seedGuidResult.findings | Where-Object { $_.code -eq 'seeded-and-bumped' -and $_.objectGuid -eq $objGuidOnly })
if ($seedGuidFinding.Count -ne 1) {
    throw "Seed explicito por GUID deveria gerar uma finding seeded-and-bumped; obtido $($seedGuidFinding.Count)"
}
if (-not (Test-Path -LiteralPath (Join-Path $frontSeedGuid "$objGuidName.xml") -PathType Leaf)) {
    throw 'Seed explicito por GUID nao criou XML na frente.'
}

$explicitNewerName = 'procExplicitNewer'
$explicitNewerGuid = '44444444-4444-4444-4444-444444444444'
$explicitNewerAcervoXml = New-FixtureObjectXml -Name $explicitNewerName -Guid $explicitNewerGuid -LastUpdate '2026-01-01T00:00:00.0000000Z'
$explicitNewerFrontXml = New-FixtureObjectXml -Name $explicitNewerName -Guid $explicitNewerGuid -LastUpdate '2026-03-01T00:00:00.0000000Z'
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$explicitNewerName.xml"), $explicitNewerAcervoXml, (Get-Utf8NoBomEncoding))
$explicitNewerFrontPath = Join-Path $frontExplicitNewer "$explicitNewerName.xml"
[System.IO.File]::WriteAllText($explicitNewerFrontPath, $explicitNewerFrontXml, (Get-Utf8NoBomEncoding))
$explicitUnlistedName = 'procExplicitUnlisted'
$explicitUnlistedGuid = '55555555-5555-5555-5555-555555555555'
$explicitUnlistedAcervoXml = New-FixtureObjectXml -Name $explicitUnlistedName -Guid $explicitUnlistedGuid -LastUpdate '2026-01-01T00:00:00.0000000Z'
$explicitUnlistedFrontXml = New-FixtureObjectXml -Name $explicitUnlistedName -Guid $explicitUnlistedGuid -LastUpdate '2026-04-01T00:00:00.0000000Z'
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$explicitUnlistedName.xml"), $explicitUnlistedAcervoXml, (Get-Utf8NoBomEncoding))
$explicitUnlistedFrontPath = Join-Path $frontExplicitNewer "$explicitUnlistedName.xml"
[System.IO.File]::WriteAllText($explicitUnlistedFrontPath, $explicitUnlistedFrontXml, (Get-Utf8NoBomEncoding))
$explicitNewerResult = & $scriptPath -FrontFolder $frontExplicitNewer -AcervoFolder $acervo -ObjectList "Procedure:$explicitNewerName" | ConvertFrom-Json
if ($explicitNewerResult.status -ne 'pass') {
    throw "Reconstrucao explicita de frente mais nova deveria retornar pass; obtido $($explicitNewerResult.status)"
}
$explicitNewerFinding = @($explicitNewerResult.findings | Where-Object { $_.code -eq 'copied-and-bumped' -and $_.objectName -eq $explicitNewerName })
if ($explicitNewerFinding.Count -ne 1) {
    throw "Reconstrucao explicita de frente mais nova deveria gerar copied-and-bumped; obtido $($explicitNewerFinding.Count)"
}
$explicitNewerText = Get-Content -LiteralPath $explicitNewerFrontPath -Raw -Encoding UTF8
if ($explicitNewerText -match 'lastUpdate="2026-03-01T00:00:00.0000000Z"') {
    throw 'Reconstrucao explicita nao deveria preservar o lastUpdate antigo da frente mais nova.'
}
$explicitUnlistedText = Get-Content -LiteralPath $explicitUnlistedFrontPath -Raw -Encoding UTF8
if ($explicitUnlistedText -notmatch 'lastUpdate="2026-04-01T00:00:00.0000000Z"') {
    throw 'Reconstrucao explicita nao deveria sobrescrever objeto mais novo fora do alvo listado.'
}
$explicitUnlistedFinding = @($explicitNewerResult.findings | Where-Object { $_.objectName -eq $explicitUnlistedName })
if ($explicitUnlistedFinding.Count -ne 0) {
    throw "Reconstrucao explicita nao deveria gerar finding para objeto fora do alvo listado; obtido $($explicitUnlistedFinding.Count)"
}

$explicitNewerDryRunFrontPath = Join-Path $frontExplicitNewerDryRun "$explicitNewerName.xml"
[System.IO.File]::WriteAllText($explicitNewerDryRunFrontPath, $explicitNewerFrontXml, (Get-Utf8NoBomEncoding))
$explicitNewerDryRunResult = & $scriptPath -FrontFolder $frontExplicitNewerDryRun -AcervoFolder $acervo -ObjectList "Procedure:$explicitNewerName" -DryRun | ConvertFrom-Json
if ($explicitNewerDryRunResult.status -ne 'pass') {
    throw "DryRun de reconstrucao explicita de frente mais nova deveria retornar pass; obtido $($explicitNewerDryRunResult.status)"
}
$explicitNewerDryRunFinding = @($explicitNewerDryRunResult.findings | Where-Object { $_.code -eq 'dry-run-copy' -and $_.objectName -eq $explicitNewerName })
if ($explicitNewerDryRunFinding.Count -ne 1) {
    throw "DryRun de reconstrucao explicita deveria gerar dry-run-copy; obtido $($explicitNewerDryRunFinding.Count)"
}
$explicitNewerDryRunText = Get-Content -LiteralPath $explicitNewerDryRunFrontPath -Raw -Encoding UTF8
if ($explicitNewerDryRunText -notmatch 'lastUpdate="2026-03-01T00:00:00.0000000Z"') {
    throw 'DryRun de reconstrucao explicita nao deveria gravar sobre frente mais nova.'
}

$missingResult = & $scriptPath -FrontFolder $frontMissing -AcervoFolder $acervo -ObjectNames 'procInexistente' | ConvertFrom-Json
if ($missingResult.status -ne 'fail') {
    throw "Seed de alvo inexistente deveria retornar fail; obtido $($missingResult.status)"
}
$missingFinding = @($missingResult.findings | Where-Object { $_.code -eq 'seed-target-not-found' })
if ($missingFinding.Count -ne 1) {
    throw "Seed de alvo inexistente deveria gerar seed-target-not-found; obtido $($missingFinding.Count)"
}

$typeDriftName = 'procTypeDrift'
$typeDriftGuid = '33333333-3333-3333-3333-333333333333'
$typeDriftAcervoXml = New-FixtureObjectXml -Name $typeDriftName -Guid $typeDriftGuid -LastUpdate '2026-02-01T00:00:00.0000000Z' -TypeGuid $procedureTypeGuid
$typeDriftFrontXml = New-FixtureObjectXml -Name $typeDriftName -Guid $typeDriftGuid -LastUpdate '2026-01-01T00:00:00.0000000Z' -TypeGuid $webPanelTypeGuid
[System.IO.File]::WriteAllText((Join-Path $procedureDir "$typeDriftName.xml"), $typeDriftAcervoXml, (Get-Utf8NoBomEncoding))
$typeDriftFrontPath = Join-Path $frontTypeDrift "$typeDriftName.xml"
[System.IO.File]::WriteAllText($typeDriftFrontPath, $typeDriftFrontXml, (Get-Utf8NoBomEncoding))
$typeDriftResult = & $scriptPath -FrontFolder $frontTypeDrift -AcervoFolder $acervo | ConvertFrom-Json
if ($typeDriftResult.status -ne 'fail') {
    throw "Drift de Object/@type deveria bloquear autocopia com status fail; obtido $($typeDriftResult.status)"
}
$typeDriftFinding = @($typeDriftResult.findings | Where-Object { $_.code -eq 'front-object-type-drift-skip' })
if ($typeDriftFinding.Count -ne 1) {
    throw "Drift de Object/@type deveria gerar front-object-type-drift-skip; obtido $($typeDriftFinding.Count)"
}
$typeDriftFrontText = Get-Content -LiteralPath $typeDriftFrontPath -Raw -Encoding UTF8
if ($typeDriftFrontText -notmatch [regex]::Escape("type=`"$webPanelTypeGuid`"")) {
    throw 'Drift de Object/@type nao deveria copiar o XML do acervo sobre a frente.'
}

$typeDriftExplicitResult = & $scriptPath -FrontFolder $frontTypeDrift -AcervoFolder $acervo -ObjectList "Procedure:$typeDriftName" | ConvertFrom-Json
if ($typeDriftExplicitResult.status -ne 'fail') {
    throw 'Alvo explicito nao deveria furar bloqueio de Object/@type divergente.'
}
$typeDriftExplicitFinding = @($typeDriftExplicitResult.findings | Where-Object { $_.code -eq 'front-object-type-drift-skip' -and $_.objectName -eq $typeDriftName })
if ($typeDriftExplicitFinding.Count -ne 1) {
    throw 'Alvo explicito deveria manter finding front-object-type-drift-skip.'
}
$typeDriftExplicitFrontText = Get-Content -LiteralPath $typeDriftFrontPath -Raw -Encoding UTF8
if ($typeDriftExplicitFrontText -notmatch [regex]::Escape("type=`"$webPanelTypeGuid`"")) {
    throw 'Alvo explicito com Object/@type divergente nao deveria sobrescrever a frente.'
}

# Matriz v7: fixtures sanitizadas e tipos obtidos do catálogo efetivo.
$catalog = Get-Content (Join-Path $PSScriptRoot 'gx-object-type-catalog.json') -Raw | ConvertFrom-Json
$script:matrixCount = 0
function Assert-Matrix {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "MATRIX_FAILED: $Message" }
}
function New-CopyCase {
    $script:matrixCount++
    $root = Join-Path $tempRoot "matrix-$script:matrixCount"
    $a = Join-Path $root 'ObjetosDaKbEmXml'
    $f = Join-Path $root 'ObjetosGeradosParaImportacaoNaKbNoGenexus/Front'
    [void](New-Item -ItemType Directory -Path $a, $f -Force)
    [pscustomobject]@{ Root = $root; Acervo = $a; Front = $f }
}
function Set-CopyXml {
    param([string]$Root, [string]$Relative, [string]$Name, [string]$Guid, [string]$Type = 'Transaction', [string]$PropertyName, [string]$Date = '2026-01-01T00:00:00Z')
    $path = Join-Path $Root $Relative
    [void](New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force)
    $typeGuid = ''
    if ($Type) { $typeGuid = $catalog.types.PSObject.Properties[$Type].Value.objectTypeGuid }
    $text = New-FixtureObjectXml -Name 'placeholder' -Guid $Guid -LastUpdate $Date -TypeGuid $typeGuid
    $text = $text.Replace('name="placeholder"', "name=`"$Name`"").Replace('fullyQualifiedName="placeholder"', "fullyQualifiedName=`"$Name`"")
    if (-not $PSBoundParameters.ContainsKey('PropertyName')) { $PropertyName = $Name }
    $text = $text.Replace('<Value>placeholder</Value>', "<Value>$PropertyName</Value>")
    [IO.File]::WriteAllText($path, $text, (Get-Utf8NoBomEncoding))
    return $path
}
function Invoke-CopyCase {
    param([object]$Case, [hashtable]$Selectors = @{}, [switch]$DryRun)
    $r = & $scriptPath -FrontFolder $Case.Front -AcervoFolder $Case.Acervo @Selectors -DryRun:$DryRun | ConvertFrom-Json
    return $r
}
function Assert-Code {
    param([object]$Result, [string]$Code, [int]$Count = 1)
    Assert-Matrix (@($Result.findings | Where-Object code -eq $Code).Count -eq $Count) "$Code quantidade $Count; $($Result | ConvertTo-Json -Depth 5 -Compress)"
}
$g1 = 'aaaaaaaa-1111-1111-1111-111111111111'
$g2 = 'bbbbbbbb-2222-2222-2222-222222222222'
$g3 = 'cccccccc-3333-3333-3333-333333333333'

# GUID fornecido mas vazio mantém a seleção: nenhuma cópia ou semeadura implícita.
$copyActionCodes = @('dry-run-copy', 'copied-and-bumped', 'dry-run-seed', 'seeded-and-bumped')
foreach ($dry in @($true, $false)) {
    foreach ($invalidGuid in @('', ' ')) {
        $c = New-CopyCase
        $beforeHashes = @{}
        foreach ($fixture in @(
            @{ Name = 'X'; Guid = $g1; Date = '2025-12-01T00:00:00Z' },
            @{ Name = 'Y'; Guid = $g2; Date = '2026-01-01T00:00:00Z' },
            @{ Name = 'Z'; Guid = $g3; Date = '2026-03-01T00:00:00Z' }
        )) {
            $null = Set-CopyXml $c.Acervo "$($fixture.Name).xml" $fixture.Name $fixture.Guid
            $p = Set-CopyXml $c.Front "$($fixture.Name).xml" $fixture.Name $fixture.Guid -Date $fixture.Date
            $beforeHashes[$p] = (Get-FileHash -LiteralPath $p).Hash
        }
        $r = Invoke-CopyCase $c @{ ObjectGuids = @($invalidGuid) } -DryRun:$dry
        Assert-Matrix ($r.status -eq 'fail' -and @($r.findings | Where-Object code -eq 'selector-invalid').Count -gt 0) 'GUID vazio falha sem perder dimensão'
        Assert-Matrix (@($r.findings | Where-Object { $_.code -in $copyActionCodes }).Count -eq 0) 'GUID vazio não libera ações'
        foreach ($p in $beforeHashes.Keys) {
            Assert-Matrix ((Get-FileHash -LiteralPath $p).Hash -eq $beforeHashes[$p]) 'GUID vazio preserva antigas, iguais e mais novas'
        }
        Assert-Matrix (@(Get-ChildItem $c.Front -File).Count -eq $beforeHashes.Count) 'GUID vazio não semeia outros arquivos'
    }

    # Mistura mantém execução parcial e preserva o existente não solicitado elegível.
    $c = New-CopyCase
    $null = Set-CopyXml $c.Acervo 'X.xml' X $g1
    $null = Set-CopyXml $c.Acervo 'Y.xml' Y $g2
    $selectedPath = Set-CopyXml $c.Front 'X.xml' X $g1
    $unlistedPath = Set-CopyXml $c.Front 'Y.xml' Y $g2
    $selectedHash = (Get-FileHash -LiteralPath $selectedPath).Hash
    $unlistedHash = (Get-FileHash -LiteralPath $unlistedPath).Hash
    $r = Invoke-CopyCase $c @{ ObjectGuids = @($g1, '') } -DryRun:$dry
    Assert-Matrix ($r.status -eq 'fail' -and @($r.findings | Where-Object code -eq 'selector-invalid').Count -gt 0) 'mistura válido e vazio conserva fail'
    $action = 'copied-and-bumped'
    if ($dry) { $action = 'dry-run-copy' }
    Assert-Code $r $action
    Assert-Matrix (@($r.findings | Where-Object { $_.code -in $copyActionCodes -and $_.objectGuid -ne $g1 }).Count -eq 0) 'mistura só processa o GUID válido'
    Assert-Matrix ((Get-FileHash -LiteralPath $unlistedPath).Hash -eq $unlistedHash) 'mistura preserva não solicitado'
    Assert-Matrix (((Get-FileHash -LiteralPath $selectedPath).Hash -eq $selectedHash) -eq $dry) 'mistura respeita escrita e DryRun do selecionado'
}

$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$r = Invoke-CopyCase $c @{ ObjectGuids = @('') }
Assert-Matrix ($r.status -eq 'fail' -and @($r.findings | Where-Object code -eq 'selector-invalid').Count -gt 0) 'frente vazia com GUID vazio não é not-applicable'
Assert-Matrix (@($r.findings | Where-Object { $_.code -in $copyActionCodes }).Count -eq 0 -and @(Get-ChildItem $c.Front).Count -eq 0) 'frente vazia não recebe seed implícito'

# Nome simples/tipado de existente não contorna a interseção vazia pelo seed.
foreach ($selection in @(@{ ObjectNames = 'X'; ObjectGuids = @(' ') }, @{ ObjectList = 'Transaction:X'; ObjectGuids = @('') })) {
    $c = New-CopyCase
    $null = Set-CopyXml $c.Acervo 'X.xml' X $g1
    $p = Set-CopyXml $c.Front 'X.xml' X $g1 -Date '2026-03-01T00:00:00Z'
    $beforeHash = (Get-FileHash -LiteralPath $p).Hash
    $r = Invoke-CopyCase $c $selection
    Assert-Matrix ($r.status -eq 'fail' -and @($r.findings | Where-Object code -eq 'selector-invalid').Count -gt 0) 'nome com GUID vazio conserva fail'
    Assert-Matrix (@($r.findings | Where-Object { $_.code -in $copyActionCodes }).Count -eq 0) 'nome existente não contorna filtro GUID vazio'
    Assert-Matrix ((Get-FileHash -LiteralPath $p).Hash -eq $beforeHash -and @(Get-ChildItem $c.Front -File).Count -eq 1) 'interseção vazia preserva existente mais novo'
}

# Nome realmente ausente continua válido pela união de pedidos para semeadura.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$r = Invoke-CopyCase $c @{ ObjectNames = 'X'; ObjectGuids = @(' ') }
Assert-Matrix ($r.status -eq 'fail' -and @($r.findings | Where-Object code -eq 'selector-invalid').Count -gt 0) 'seed parcial conserva fail'
Assert-Code $r 'seeded-and-bumped'
Assert-Matrix (Test-Path -LiteralPath (Join-Path $c.Front 'X.xml') -PathType Leaf) 'nome ausente semeia apesar do GUID inválido'

# Omitido e array vazio mantêm a varredura normal em fixtures elegíveis independentes.
foreach ($selection in @(@{}, @{ ObjectGuids = @() })) {
    $c = New-CopyCase
    $null = Set-CopyXml $c.Acervo 'X.xml' X $g1
    $p = Set-CopyXml $c.Front 'X.xml' X $g1
    $beforeHash = (Get-FileHash -LiteralPath $p).Hash
    $r = Invoke-CopyCase $c $selection
    Assert-Matrix ($r.status -eq 'pass') 'GUID omitido/array vazio mantém varredura normal'
    Assert-Code $r 'selector-invalid' 0
    Assert-Code $r 'copied-and-bumped'
    Assert-Matrix ((Get-FileHash -LiteralPath $p).Hash -ne $beforeHash) 'varredura normal altera existente elegível'
}

# Espaço em processo filho: falha estruturada permanece distinta do exit de infraestrutura.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$p = Set-CopyXml $c.Front 'X.xml' X $g1
$beforeHash = (Get-FileHash -LiteralPath $p).Hash
$r = & pwsh -NoProfile -File $scriptPath -FrontFolder $c.Front -AcervoFolder $c.Acervo -ObjectGuids ' ' -DryRun | ConvertFrom-Json
Assert-Matrix ($LASTEXITCODE -eq 0 -and $r.status -eq 'fail') 'GUID vazio: JSON fail com exit 0'
Assert-Matrix (@($r.findings | Where-Object code -eq 'selector-invalid').Count -gt 0) 'processo filho diagnostica GUID vazio'
Assert-Matrix (@($r.findings | Where-Object { $_.code -in $copyActionCodes }).Count -eq 0 -and (Get-FileHash -LiteralPath $p).Hash -eq $beforeHash) 'processo filho não libera cópia'

# Todos os quatro caminhos originais em processo filho: JSON e exit medidos separadamente.
foreach ($selection in @(@{ ObjectList = 'Transaction:X' }, @{ ObjectNames = 'X' }, @{ ObjectGuids = " $($g1.ToUpperInvariant()) " }, @{ ObjectList = 'Transaction:X'; ObjectNames = 'X' })) {
    $c = New-CopyCase
    $null = Set-CopyXml $c.Acervo 'Transaction/X.xml' X $g1
    $argv = @('-NoProfile', '-File', $scriptPath, '-FrontFolder', $c.Front, '-AcervoFolder', $c.Acervo, '-DryRun')
    foreach ($key in $selection.Keys) { $argv += "-$key"; $argv += $selection[$key] }
    $r = & pwsh @argv | ConvertFrom-Json
    Assert-Matrix ($LASTEXITCODE -eq 0 -and $r.status -eq 'pass') 'seletor original JSON/exit'
    Assert-Code $r 'dry-run-seed'
    Assert-Matrix (@(Get-ChildItem $c.Front).Count -eq 0) 'DryRun sem escrita'
}

foreach ($type in @('Folder', 'Table', 'Transaction', 'Module', 'WorkWith', 'WorkWithForWeb')) {
    $c = New-CopyCase
    $null = Set-CopyXml $c.Acervo 'A/X.xml' X $g1 $type
    $null = Set-CopyXml $c.Acervo 'Z/X.xml' X $g2 Procedure
    $r = Invoke-CopyCase $c @{ ObjectList = "$($type.ToLowerInvariant()):X" }
    Assert-Code $r 'seeded-and-bumped'
    [xml]$written = Get-Content (Join-Path $c.Front 'X.xml') -Raw
    Assert-Matrix ($written.DocumentElement.GetAttribute('guid') -eq $g1) "XML em pasta enganosa / $type"
}
foreach ($type in @('WorkWithDevices', 'NaoExiste', 'Attribute', 'RootModule', ':X', 'X:')) {
    $c = New-CopyCase
    $null = Set-CopyXml $c.Acervo 'X.xml' X $g1
    $null = Set-CopyXml $c.Front 'X.xml' X $g1
    $selector = "$($type):X"
    if ($type.Contains(':')) { $selector = $type }
    $r = Invoke-CopyCase $c @{ ObjectList = $selector }
    Assert-Matrix ($r.status -eq 'fail') "tipo inválido $type"
    Assert-Code $r 'copied-and-bumped' 0
}

# Ambiguidade simples e tipada; diagnóstico simples não some pela união/deduplicação.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'Folder/X.xml' X $g3 Folder
$null = Set-CopyXml $c.Acervo 'Table/X.xml' X $g2 Table
$null = Set-CopyXml $c.Acervo 'Transaction/X.xml' X $g1
$r = Invoke-CopyCase $c @{ ObjectList = @('X', 'Transaction:X') } -DryRun
Assert-Code $r 'seed-target-ambiguous'
Assert-Code $r 'dry-run-seed'
$null = Set-CopyXml $c.Acervo 'Outro/X.xml' X $g3
$r = Invoke-CopyCase $c @{ ObjectList = 'Transaction:X' } -DryRun
Assert-Code $r 'seed-target-ambiguous'

# GUID certo após homônimo; existente é resolvido globalmente por identidade.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'A/X.xml' X $g2 Table
$null = Set-CopyXml $c.Acervo 'Z/X.xml' X $g1
$frontPath = Set-CopyXml $c.Front 'X.xml' X $g1
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' }
Assert-Code $r 'copied-and-bumped'
[xml]$written = Get-Content $frontPath -Raw
Assert-Matrix ($written.DocumentElement.GetAttribute('guid') -eq $g1) 'homônimo não vence GUID'
$null = Set-CopyXml $c.Acervo 'Duplicado/Y.xml' Y $g1
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' }
Assert-Code $r 'front-acervo-guid-ambiguous-skip'

# Nome interno repetido em destinos distintos continua pareado individualmente.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'A/X.xml' X $g1
$null = Set-CopyXml $c.Acervo 'B/X.xml' X $g2
$null = Set-CopyXml $c.Front 'Um.xml' X $g1
$null = Set-CopyXml $c.Front 'Dois.xml' X $g2
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' }
Assert-Code $r 'copied-and-bumped' 2

foreach ($acervoType in @('Table', 'Transaction')) {
    foreach ($selector in @('X', 'Table:X')) {
        $c = New-CopyCase
        $null = Set-CopyXml $c.Acervo 'Tipo/X.xml' X $g2 $acervoType
        $p = Set-CopyXml $c.Front 'X.xml' X $g1 Transaction -Date '2026-03-01T00:00:00Z'
        $before = [IO.File]::ReadAllText($p)
        $r = Invoke-CopyCase $c @{ ObjectList = $selector }
        if ($selector -eq 'X') {
            if ($acervoType -eq 'Table') { Assert-Matrix ($r.status -eq 'pass' -and $r.findings.Count -eq 0) 'simples atendido preserva novo' }
            else { Assert-Code $r 'front-object-identity-conflict-skip' }
            Assert-Code $r 'seed-destination-exists' 0
        } elseif ($acervoType -eq 'Table') { Assert-Code $r 'seed-destination-exists' }
        else { Assert-Code $r 'seed-target-not-found' }
        Assert-Matrix ([IO.File]::ReadAllText($p) -eq $before) 'preservação do ocupante'
    }
}

# Interseção excluída não é contornada pelo seed; GUID ausente ainda é união.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$null = Set-CopyXml $c.Acervo 'Y.xml' Y $g2
$null = Set-CopyXml $c.Front 'X.xml' X $g1
$r = Invoke-CopyCase $c @{ ObjectNames = 'X'; ObjectGuids = $g2 } -DryRun
Assert-Code $r 'dry-run-copy' 0
Assert-Code $r 'dry-run-seed'
$r = Invoke-CopyCase $c @{ ObjectNames = 'X'; ObjectGuids = $g1 } -DryRun
Assert-Code $r 'dry-run-copy'
Assert-Code $r 'dry-run-seed' 0

# GUID presente sem Name; atributo name e propriedade Name são critérios distintos.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$null = Set-CopyXml $c.Front 'SemNome.xml' '' $g1
$r = Invoke-CopyCase $c @{ ObjectGuids = $g1 } -DryRun
Assert-Code $r 'dry-run-copy'
Assert-Code $r 'dry-run-seed' 0
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g2 Table
$null = Set-CopyXml $c.Front 'X.xml' X $g1 Transaction -PropertyName Y
$r = Invoke-CopyCase $c @{ ObjectNames = 'Y' } -DryRun
Assert-Matrix ($r.findings.Count -eq 0) 'atendimento pelo nome efetivo Y'
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' } -DryRun
Assert-Code $r 'seed-destination-exists'
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' Z $g2 Transaction -PropertyName X
$null = Set-CopyXml $c.Front 'X.xml' X $g1
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' } -DryRun
Assert-Matrix ($r.findings.Count -eq 0) 'homônimo legado usa atributo name/FQN, não Property'
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'arquivo_renomeado.xml' X $g1
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' } -DryRun
Assert-Code $r 'seed-target-not-found'
$r = Invoke-CopyCase $c @{ ObjectGuids = $g1 } -DryRun
Assert-Code $r 'dry-run-seed'

# Reserva física equivalente nos dois modos, incluindo XML inválido.
foreach ($dry in @($true, $false)) {
    $c = New-CopyCase
    $null = Set-CopyXml $c.Acervo 'A/X.xml' X $g1
    $null = Set-CopyXml $c.Acervo 'B/X.xml' X $g2 Table
    $r = Invoke-CopyCase $c @{ ObjectGuids = @($g1, $g2) } -DryRun:$dry
    Assert-Code $r 'seed-destination-exists'
    $action = 'seeded-and-bumped'
    if ($dry) { $action = 'dry-run-seed' }
    Assert-Code $r $action
    foreach ($bad in @('<broken', '<Object name="X" />', '<ExportFile />')) {
        $c = New-CopyCase
        $null = Set-CopyXml $c.Acervo 'X.xml' X $g1
        $p = Join-Path $c.Front 'X.xml'
        [IO.File]::WriteAllText($p, $bad, (Get-Utf8NoBomEncoding))
        $r = Invoke-CopyCase $c @{ ObjectGuids = $g1 } -DryRun:$dry
        Assert-Code $r 'seed-destination-exists'
        Assert-Matrix ([IO.File]::ReadAllText($p) -eq $bad) 'ocupante inválido intacto'
    }
}
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X '' Transaction
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' }
Assert-Code $r 'copy-identity-incomplete-skip'
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$null = Set-CopyXml $c.Front 'X.xml' X $g1 ''
$r = Invoke-CopyCase $c @{ ObjectGuids = $g1 }
Assert-Code $r 'copy-identity-incomplete-skip'

# Override inválido não aborta os pedidos puros.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$badOverride = Join-Path $c.Root 'bad.json'
[IO.File]::WriteAllText($badOverride, '{invalid', (Get-Utf8NoBomEncoding))
$r = Invoke-CopyCase $c @{ ObjectList = 'Transaction:X'; ObjectGuids = $g1; CatalogOverridePath = $badOverride } -DryRun
Assert-Code $r 'selector-catalog-override-blocked'
Assert-Code $r 'dry-run-seed'
$r = Invoke-CopyCase $c @{ ObjectList = 'Transaction:X'; CatalogOverridePath = $badOverride } -DryRun
Assert-Code $r 'dry-run-seed' 0
$r = Invoke-CopyCase $c @{ ObjectNames = 'X'; CatalogOverridePath = $badOverride } -DryRun
Assert-Matrix ($r.status -eq 'pass') 'override não carregado para nomes puros'

# Molde instalado em temp/scripts, SharedSkillsRoot real e override derivado da raiz.
$c = New-CopyCase
$localScripts = Join-Path $c.Root 'scripts'
[void](New-Item -ItemType Directory -Path $localScripts -Force)
$overrideGuid = 'dddddddd-4444-4444-4444-444444444444'
$override = @{ types = @{ CustomCopy = @{ objectTypeGuid = $overrideGuid; rootKind = 'Object'; folderName = 'CustomCopy'; inventoryEligible = $true; queryableByKbIntelligence = $false; containerType = $false } } } | ConvertTo-Json -Depth 6
$overridePath = Join-Path $localScripts 'gx-object-type-catalog.override.json'
[IO.File]::WriteAllText($overridePath, $override, (Get-Utf8NoBomEncoding))
$customText = New-FixtureObjectXml X $g1 '2026-01-01T00:00:00Z' $overrideGuid
[IO.File]::WriteAllText((Join-Path $c.Acervo 'X.xml'), $customText, (Get-Utf8NoBomEncoding))
$wrapper = Join-Path $localScripts 'Copy-DemoKbAcervoToFront.ps1'
Copy-Item (Join-Path $PSScriptRoot '../xpz-kb-parallel-setup/examples/Copy-KbAcervoToFront.example.ps1') $wrapper
$r = & pwsh -NoProfile -File $wrapper -FrontName Front -SharedSkillsRoot (Split-Path $PSScriptRoot -Parent) -ObjectList 'CustomCopy:X' -DryRun | ConvertFrom-Json
Assert-Matrix ($LASTEXITCODE -eq 0 -and $r.status -eq 'pass') 'molde ObjectList sozinho / raiz repassada'
Assert-Code $r 'dry-run-seed'
$r = Invoke-CopyCase $c @{ ObjectList = 'CustomCopy:X'; CatalogOverridePath = $overridePath } -DryRun
Assert-Code $r 'dry-run-seed'
$r = Invoke-CopyCase $c @{ ObjectList = 'CustomCopy:X' } -DryRun
Assert-Code $r 'selector-type-unknown'

# Infraestrutura da base ausente/corrompida: testar uma cópia isolada do motor, nunca a base real.
$isolated = Join-Path $c.Root 'isolated'
[void](New-Item -ItemType Directory -Path $isolated -Force)
foreach ($leaf in @('Copy-GeneXusAcervoToFront.ps1', 'GeneXusObjectTypeCatalogSupport.ps1', 'GeneXusObjectTypeDriftSupport.ps1', 'Utf8NoBomEncodingSupport.ps1')) {
    Copy-Item (Join-Path $PSScriptRoot $leaf) (Join-Path $isolated $leaf)
}
$isolatedMotor = Join-Path $isolated 'Copy-GeneXusAcervoToFront.ps1'
foreach ($baseState in @('missing', 'corrupt', 'types-array', 'types-scalar', 'base-array')) {
    if ($baseState -eq 'corrupt') { [IO.File]::WriteAllText((Join-Path $isolated 'gx-object-type-catalog.json'), '{bad', (Get-Utf8NoBomEncoding)) }
    if ($baseState -eq 'types-array') { [IO.File]::WriteAllText((Join-Path $isolated 'gx-object-type-catalog.json'), '{"types":[]}', (Get-Utf8NoBomEncoding)) }
    if ($baseState -eq 'types-scalar') { [IO.File]::WriteAllText((Join-Path $isolated 'gx-object-type-catalog.json'), '{"types":1}', (Get-Utf8NoBomEncoding)) }
    if ($baseState -eq 'base-array') { [IO.File]::WriteAllText((Join-Path $isolated 'gx-object-type-catalog.json'), '[]', (Get-Utf8NoBomEncoding)) }
    $raw = & pwsh -NoProfile -File $isolatedMotor -FrontFolder $c.Front -AcervoFolder $c.Acervo -ObjectList 'Transaction:X' -DryRun 2>$null
    Assert-Matrix ($LASTEXITCODE -ne 0 -and -not $raw) "base $baseState falha de infraestrutura"
    $r = & pwsh -NoProfile -File $isolatedMotor -FrontFolder $c.Front -AcervoFolder $c.Acervo -ObjectGuids $g1 -DryRun | ConvertFrom-Json
    Assert-Matrix ($LASTEXITCODE -eq 0 -and $r.status -eq 'pass') "base $baseState dispensada para GUID puro"
}
# FQN do caminho legado continua elegível à classificação, sem FQN no seed.
$c = New-CopyCase
$p = Set-CopyXml $c.Front 'X.xml' X $g1
$text = [IO.File]::ReadAllText($p).Replace('fullyQualifiedName="X"', 'fullyQualifiedName="M.X"')
[IO.File]::WriteAllText($p, $text, (Get-Utf8NoBomEncoding))
$p = Set-CopyXml $c.Acervo 'M.X.xml' Z $g2
$text = [IO.File]::ReadAllText($p).Replace('fullyQualifiedName="Z"', 'fullyQualifiedName="M.X"')
[IO.File]::WriteAllText($p, $text, (Get-Utf8NoBomEncoding))
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' } -DryRun
Assert-Code $r 'front-object-identity-conflict-skip'
# Pedidos repetidos conservam uma ação; tipo inválido não apaga pedido puro válido.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$r = Invoke-CopyCase $c @{ ObjectList = @('Transaction:X', 'Transaction:X'); ObjectNames = 'X'; ObjectGuids = $g1.ToUpperInvariant() } -DryRun
Assert-Code $r 'dry-run-seed'
$r = Invoke-CopyCase $c @{ ObjectList = 'Invalido:X'; ObjectNames = 'X' } -DryRun
Assert-Code $r 'selector-type-unknown'
Assert-Code $r 'dry-run-seed'
# Propriedade Name substitui atributo no seed explícito.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1 Transaction -PropertyName Y
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' } -DryRun
Assert-Code $r 'seed-target-not-found'
$r = Invoke-CopyCase $c @{ ObjectGuids = $g1 } -DryRun
Assert-Code $r 'dry-run-seed'
# Metadata com data inválida não é eliminada do cache, nem autoriza escrita.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1 Transaction -Date 'invalida'
$r = Invoke-CopyCase $c @{ ObjectNames = 'X' }
Assert-Code $r 'lastupdate-unparseable-skip'
Assert-Matrix (@(Get-ChildItem $c.Front).Count -eq 0) 'lastUpdate incompleto preserva'
# Override inseguro também é isolado dos pedidos puros.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'X.xml' X $g1
$unsafeOverride = Join-Path $c.Root 'unsafe.json'
$unsafeText = @{ types = @{ Transaction = @{ objectTypeGuid = $g3 } } } | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($unsafeOverride, $unsafeText, (Get-Utf8NoBomEncoding))
$r = Invoke-CopyCase $c @{ ObjectList = 'Transaction:X'; ObjectGuids = $g1; CatalogOverridePath = $unsafeOverride } -DryRun
Assert-Code $r 'selector-catalog-override-blocked'
Assert-Code $r 'dry-run-seed'
# Cache: exatamente uma enumeração global, sem Select-String ou busca global por objeto.
$c = New-CopyCase
$null = Set-CopyXml $c.Acervo 'A/X.xml' X $g1
$null = Set-CopyXml $c.Acervo 'B/Y.xml' Y $g1 Table
$r = Invoke-CopyCase $c @{ ObjectList = @('Transaction:X', 'Table:Y') } -DryRun
Assert-Code $r 'seed-target-ambiguous' 2
Assert-Code $r 'dry-run-seed' 0
# Findings não mudam exit, inclusive quando todos os seletores tipados são inválidos.
$r = & pwsh -NoProfile -File $scriptPath -FrontFolder $c.Front -AcervoFolder $c.Acervo -ObjectList 'Invalido:X' -DryRun | ConvertFrom-Json
Assert-Matrix ($LASTEXITCODE -eq 0 -and $r.status -eq 'fail') 'fail JSON não é exit de infraestrutura'
$r = & pwsh -NoProfile -File $wrapper -FrontName Front -SharedSkillsRoot (Split-Path $PSScriptRoot -Parent) -ObjectList 'Invalido:X' -DryRun | ConvertFrom-Json
Assert-Matrix ($LASTEXITCODE -eq 0 -and $r.status -eq 'fail') 'molde preserva status e exit'
$motorText = [IO.File]::ReadAllText($scriptPath)
Assert-Matrix ([regex]::Matches($motorText, 'Get-ChildItem -LiteralPath \$AcervoFolder -Recurse').Count -eq 1 -and $motorText -notmatch 'Select-String') 'cache por execução'
Write-Output "MATRIX_OK: $script:matrixCount cenários v7"
Write-Output 'OK: Test-CopyGeneXusAcervoToFrontSelfTest.ps1'
exit 0
