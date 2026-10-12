#requires -Version 7.4

<#
.SYNOPSIS
    Self-test da reconciliacao GUID-aware de rename em Sync-GeneXusXpzToXml.ps1.

.DESCRIPTION
    Cobre os caminhos de Resolve-GuidAwareRenames sob -FullSnapshot:
      A. Rename real (Apply): mesmo GUID, nome diferente -> Move-Item antigo->novo;
         um arquivo so, sem residuo Extra, sem throw, RenamedByGuid = 1.
      B. Conferencia (-VerifyOnly): nao toca o disco; classifica o residuo
         (RenameResidualsDetected = 1, Action 'detected'). A conferencia ainda
         acusa o acervo desatualizado (exit nao-zero), mas o relatorio, gravado
         antes do throw, ja explica que e um rename.
      C. Zero renames (Apply): acervo ja sincronizado -> exit 0, sem erro
         (regressao StrictMode quando a lista de renames vinha vazia).
      D. Orfao de materializacao anterior: nome antigo e nome novo existem com
         mesmo GUID -> remove o nome antigo e preserva o alvo.
      E. Colisao de GUID (Apply): o nome novo ja pertence a OUTRO objeto (GUID
         diferente) -> fail-closed (throw) ANTES da escrita; o objeto existente e
         o de nome antigo sao preservados (sem perda de dado).
      F. Rename so de caixa (Apply): mesmo GUID, nome diferente apenas na caixa ->
         o arquivo no disco passa a ter o nome com a caixa nova.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'Sync-GeneXusXpzToXml.ps1'
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-sync-guid-rename-selftest-{0}' -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $tempRoot -Force)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function New-AttrFile {
    param([string]$Path, [string]$Guid, [string]$Name, [string]$LastUpdate, [string]$Description = '')
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Attribute lastUpdate="$LastUpdate" guid="$Guid" name="$Name" description="$Description"><Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c" /></Attribute>
"@
    Write-Utf8 -Path $Path -Content $xml
}

function New-Package {
    param([string]$Path, [string]$Guid, [string]$Name, [string]$LastUpdate, [string]$Description = '')
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<ExportFile>
  <Objects />
  <Attributes>
    <Attribute lastUpdate="$LastUpdate" guid="$Guid" name="$Name" description="$Description"><Part type="ad3ca970-19d0-44e1-a7b7-db05556e820c" /></Attribute>
  </Attributes>
</ExportFile>
"@
    Write-Utf8 -Path $Path -Content $xml
}

function New-CaseDir {
    param([string]$Name)
    $acervo = Join-Path (Join-Path $tempRoot $Name) 'ObjetosDaKbEmXml'
    $attrDir = Join-Path $acervo 'Attribute'
    [void](New-Item -ItemType Directory -Path $attrDir -Force)
    return [pscustomobject]@{ Root = (Join-Path $tempRoot $Name); Acervo = $acervo; AttrDir = $attrDir }
}

function Invoke-Sync {
    param([string]$Pkg, [string]$Acervo, [switch]$VerifyOnly, [string]$ReportPath, [string[]]$ExpectedItems)
    $psArgs = @('-NoProfile', '-File', $scriptPath, '-InputPath', $Pkg, '-DestinationRoot', $Acervo, '-FullSnapshot')
    if ($VerifyOnly) { $psArgs += '-VerifyOnly' }
    if ($ReportPath) { $psArgs += @('-ReportPath', $ReportPath, '-KeepReport') }
    if ($ExpectedItems) { $psArgs += @('-ExpectedItems', ($ExpectedItems -join ',')) }
    # stdout e stderr capturados SEPARADAMENTE: o contrato exige stdout = JSON puro de uma
    # linha, com todo texto humano no stderr. 2>$errFile isola os dois streams do filho.
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $stdout = & pwsh @psArgs 2>$errFile
        $exit = $LASTEXITCODE
        $stderr = Get-Content -LiteralPath $errFile -Raw
    } finally {
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    $stdoutText = ($stdout | Out-String)
    return [pscustomobject]@{
        ExitCode = $exit
        StdOut = $stdoutText
        StdErr = $stderr
        Output = ($stdoutText + [Environment]::NewLine + $stderr)
    }
}

function Assert-StdoutIsPureJson {
    param([string]$Case, [object]$Result)
    $raw = $Result.StdOut.Trim()
    # Stdout deve ser EXCLUSIVAMENTE o JSON do resumo: uma unica linha, parseavel, sem
    # texto humano vazado. (Write-Host vazaria; por isso o motor usa [Console]::Error.)
    if ($raw -match "`n") { throw "${Case}: stdout deveria ser uma unica linha JSON (-Compress); contem quebras. StdOut: $raw" }
    try {
        $obj = $raw | ConvertFrom-Json
    } catch {
        throw "${Case}: stdout deveria ser JSON parseavel; falhou: $($_.Exception.Message). StdOut: $raw"
    }
    if ($obj.Kind -ne 'xpz-sync-result') { throw "${Case}: stdout JSON.Kind deveria ser 'xpz-sync-result'; obtido '$($obj.Kind)'" }
    if ($obj.SchemaVersion -ne 1) { throw "${Case}: stdout JSON.SchemaVersion deveria ser 1; obtido '$($obj.SchemaVersion)'" }
    return $obj
}

try {
    $guid1 = '11111111-1111-1111-1111-111111111111'
    $guid2 = '22222222-2222-2222-2222-222222222222'

    # --- A: rename real (Apply) ---
    $a = New-CaseDir -Name 'apply'
    New-AttrFile -Path (Join-Path $a.AttrDir 'DistribuidoraNome.xml') -Guid $guid1 -Name 'DistribuidoraNome' -LastUpdate '2020-01-01T00:00:00.0000000Z'
    $pkgA = Join-Path $a.Root 'pacote.xml'
    New-Package -Path $pkgA -Guid $guid1 -Name 'DistribuidoraNomeTeste' -LastUpdate '2026-01-01T00:00:00.0000000Z'
    $repA = Join-Path $a.Root 'report.json'
    $rA = Invoke-Sync -Pkg $pkgA -Acervo $a.Acervo -ReportPath $repA
    if ($rA.ExitCode -ne 0) { throw "A: esperava exit 0; obtido $($rA.ExitCode). Saida: $($rA.Output)" }
    if (-not (Test-Path -LiteralPath (Join-Path $a.AttrDir 'DistribuidoraNomeTeste.xml'))) { throw "A: arquivo novo deveria existir" }
    if (Test-Path -LiteralPath (Join-Path $a.AttrDir 'DistribuidoraNome.xml')) { throw "A: arquivo antigo deveria ter sido renomeado" }
    $repAObj = Get-Content -LiteralPath $repA -Raw | ConvertFrom-Json
    if ($repAObj.Summary.RenamedByGuid -ne 1) { throw "A: RenamedByGuid deveria ser 1; obtido $($repAObj.Summary.RenamedByGuid)" }
    if ($repAObj.Summary.FullSnapshotExtra -ne 0) { throw "A: FullSnapshotExtra deveria ser 0; obtido $($repAObj.Summary.FullSnapshotExtra)" }
    # Contrato de stdout: JSON puro de uma linha, sem texto humano vazado.
    $aObj = Assert-StdoutIsPureJson -Case 'A' -Result $rA
    if (@($aObj.RenamedByGuidItems).Count -ne 1) { throw "A: RenamedByGuidItems deveria ter 1 item; obtido $(@($aObj.RenamedByGuidItems).Count)" }
    if ($aObj.RenamedByGuidItems[0].Action -ne 'renamed') { throw "A: Action deveria ser 'renamed'; obtido '$($aObj.RenamedByGuidItems[0].Action)'" }
    if ($aObj.RenamedByGuidItems[0].OldName -ne 'DistribuidoraNome' -or $aObj.RenamedByGuidItems[0].NewName -ne 'DistribuidoraNomeTeste') { throw "A: RenamedByGuidItems deveria expor Old->New; obtido '$($aObj.RenamedByGuidItems[0].OldName)'->'$($aObj.RenamedByGuidItems[0].NewName)'" }
    # Invariante len(*Names) == contador (UpdatedNames, pois o rename reescreve o conteudo).
    if (@($aObj.UpdatedNames).Count -ne $aObj.Updated) { throw "A: len(UpdatedNames) ($(@($aObj.UpdatedNames).Count)) != Updated ($($aObj.Updated))" }
    # ExpectedItems nao foi passado: as listas de esperados devem ser null (nao [] nem ausentes).
    if ($null -ne $aObj.ExpectedReturnedNames) { throw "A: sem -ExpectedItems, ExpectedReturnedNames deveria ser null" }

    # --- B: conferencia (-VerifyOnly) classifica sem mover ---
    $b = New-CaseDir -Name 'verify'
    New-AttrFile -Path (Join-Path $b.AttrDir 'DistribuidoraNome.xml') -Guid $guid1 -Name 'DistribuidoraNome' -LastUpdate '2020-01-01T00:00:00.0000000Z'
    $pkgB = Join-Path $b.Root 'pacote.xml'
    New-Package -Path $pkgB -Guid $guid1 -Name 'DistribuidoraNomeTeste' -LastUpdate '2026-01-01T00:00:00.0000000Z'
    $repB = Join-Path $b.Root 'report.json'
    $rB = Invoke-Sync -Pkg $pkgB -Acervo $b.Acervo -VerifyOnly -ReportPath $repB
    if (-not (Test-Path -LiteralPath (Join-Path $b.AttrDir 'DistribuidoraNome.xml'))) { throw "B: VerifyOnly nao deveria tocar o disco (antigo)" }
    if (Test-Path -LiteralPath (Join-Path $b.AttrDir 'DistribuidoraNomeTeste.xml')) { throw "B: VerifyOnly nao deveria criar o novo" }
    if (-not (Test-Path -LiteralPath $repB)) { throw "B: relatorio deveria ter sido gravado antes do throw (exit=$($rB.ExitCode))" }
    $repBObj = Get-Content -LiteralPath $repB -Raw | ConvertFrom-Json
    if ($repBObj.Summary.RenameResidualsDetected -ne 1) { throw "B: RenameResidualsDetected deveria ser 1; obtido $($repBObj.Summary.RenameResidualsDetected)" }
    if ($repBObj.Summary.RenamedByGuid -ne 0) { throw "B: RenamedByGuid deveria ser 0 em VerifyOnly; obtido $($repBObj.Summary.RenamedByGuid)" }
    # Contrato: o JSON e emitido ANTES do throw de verificacao, entao o stdout tem JSON
    # parseavel mesmo com exit nao-zero. Em VerifyOnly as listas de writes sao vazias por
    # construcao -> serializam [] (array vazio), nunca null nem escalar.
    $bObj = Assert-StdoutIsPureJson -Case 'B' -Result $rB
    if (@($bObj.CreatedNames).Count -ne 0) { throw "B: VerifyOnly -> CreatedNames deveria ser [] vazio; obtido $(@($bObj.CreatedNames).Count)" }
    if (@($bObj.UnchangedNames).Count -ne 0) { throw "B: VerifyOnly -> UnchangedNames deveria ser [] vazio" }
    if (@($bObj.RenamedByGuidItems).Count -ne 0) { throw "B: VerifyOnly -> RenamedByGuidItems deveria ser [] vazio (detected nao entra)" }
    # O resumo humano (Format-List, multi-linha) deve estar no STDERR, nunca no stdout.
    if ($rB.StdErr -notmatch 'MaterializationInterpretation') { throw "B: o resumo humano deveria sair no stderr; nao encontrado" }

    # --- C: zero renames (acervo ja sincronizado) ---
    $c = New-CaseDir -Name 'zero'
    New-AttrFile -Path (Join-Path $c.AttrDir 'Alpha.xml') -Guid $guid1 -Name 'Alpha' -LastUpdate '2020-01-01T00:00:00.0000000Z'
    $pkgC = Join-Path $c.Root 'pacote.xml'
    New-Package -Path $pkgC -Guid $guid1 -Name 'Alpha' -LastUpdate '2020-01-01T00:00:00.0000000Z'
    $repC = Join-Path $c.Root 'report.json'
    $rC = Invoke-Sync -Pkg $pkgC -Acervo $c.Acervo -ReportPath $repC
    if ($rC.ExitCode -ne 0) { throw "C: FullSnapshot sem renames deveria sair com exit 0; obtido $($rC.ExitCode). Saida: $($rC.Output)" }
    $repCObj = Get-Content -LiteralPath $repC -Raw | ConvertFrom-Json
    if ($repCObj.Summary.RenamedByGuid -ne 0) { throw "C: RenamedByGuid deveria ser 0; obtido $($repCObj.Summary.RenamedByGuid)" }
    if ($repCObj.Summary.RenameResidualsDetected -ne 0) { throw "C: RenameResidualsDetected deveria ser 0; obtido $($repCObj.Summary.RenameResidualsDetected)" }

    # --- D: orfao de materializacao anterior (nome novo ja existe com o mesmo GUID) ---
    $d = New-CaseDir -Name 'orphan'
    New-AttrFile -Path (Join-Path $d.AttrDir 'Old.xml') -Guid $guid1 -Name 'Old' -LastUpdate '2020-01-01T00:00:00.0000000Z' -Description 'G1 renomeado para New'
    New-AttrFile -Path (Join-Path $d.AttrDir 'New.xml') -Guid $guid1 -Name 'New' -LastUpdate '2026-01-01T00:00:00.0000000Z' -Description 'G1 ja materializado com nome novo'
    $pkgD = Join-Path $d.Root 'pacote.xml'
    New-Package -Path $pkgD -Guid $guid1 -Name 'New' -LastUpdate '2026-01-01T00:00:00.0000000Z'
    $repD = Join-Path $d.Root 'report.json'
    $rD = Invoke-Sync -Pkg $pkgD -Acervo $d.Acervo -ReportPath $repD
    if ($rD.ExitCode -ne 0) { throw "D: orfao de mesmo GUID deveria sair com exit 0; obtido $($rD.ExitCode). Saida: $($rD.Output)" }
    if (Test-Path -LiteralPath (Join-Path $d.AttrDir 'Old.xml')) { throw "D: o arquivo antigo deveria ter sido removido como orfao" }
    if (-not (Test-Path -LiteralPath (Join-Path $d.AttrDir 'New.xml'))) { throw "D: o arquivo novo deveria ser preservado" }
    $repDObj = Get-Content -LiteralPath $repD -Raw | ConvertFrom-Json
    if ($repDObj.Summary.RenamedByGuid -ne 1) { throw "D: RenamedByGuid deveria contar o orfao removido; obtido $($repDObj.Summary.RenamedByGuid)" }
    # Cobertura do Action 'orphan-removed' no item estruturado (nao so no contador).
    $dObj = Assert-StdoutIsPureJson -Case 'D' -Result $rD
    if (@($dObj.RenamedByGuidItems).Count -ne 1) { throw "D: RenamedByGuidItems deveria ter 1 item; obtido $(@($dObj.RenamedByGuidItems).Count)" }
    if ($dObj.RenamedByGuidItems[0].Action -ne 'orphan-removed') { throw "D: Action deveria ser 'orphan-removed'; obtido '$($dObj.RenamedByGuidItems[0].Action)'" }

    # --- E: colisao de GUID (nome novo ja pertence a outro objeto) ---
    $e = New-CaseDir -Name 'collision'
    New-AttrFile -Path (Join-Path $e.AttrDir 'Old.xml') -Guid $guid1 -Name 'Old' -LastUpdate '2020-01-01T00:00:00.0000000Z' -Description 'G1 renomeado para New'
    New-AttrFile -Path (Join-Path $e.AttrDir 'New.xml') -Guid $guid2 -Name 'New' -LastUpdate '2020-01-01T00:00:00.0000000Z' -Description 'G2 legitimo nao relacionado'
    $pkgE = Join-Path $e.Root 'pacote.xml'
    New-Package -Path $pkgE -Guid $guid1 -Name 'New' -LastUpdate '2026-01-01T00:00:00.0000000Z'
    $rE = Invoke-Sync -Pkg $pkgE -Acervo $e.Acervo
    if ($rE.ExitCode -eq 0) { throw "E: colisao de GUID deveria falhar (fail-closed), nao exit 0" }
    if ($rE.Output -notmatch 'Colisao de nome no acervo') { throw "E: deveria reportar colisao de nome; saida: $($rE.Output)" }
    if (-not (Test-Path -LiteralPath (Join-Path $e.AttrDir 'Old.xml'))) { throw "E: o arquivo antigo deveria ter sido preservado" }
    $newGuidE = (Select-String -LiteralPath (Join-Path $e.AttrDir 'New.xml') -Pattern 'guid="([0-9a-f-]+)"').Matches[0].Groups[1].Value
    if ($newGuidE -ne $guid2) { throw "E: New.xml deveria preservar o GUID de G2 ($guid2); obtido $newGuidE (objeto destruido!)" }

    # --- F: rename so de caixa ---
    $f = New-CaseDir -Name 'caseonly'
    New-AttrFile -Path (Join-Path $f.AttrDir 'Alpha.xml') -Guid $guid1 -Name 'Alpha' -LastUpdate '2020-01-01T00:00:00.0000000Z'
    $pkgF = Join-Path $f.Root 'pacote.xml'
    New-Package -Path $pkgF -Guid $guid1 -Name 'alpha' -LastUpdate '2026-01-01T00:00:00.0000000Z'
    $repF = Join-Path $f.Root 'report.json'
    $rF = Invoke-Sync -Pkg $pkgF -Acervo $f.Acervo -ReportPath $repF
    if ($rF.ExitCode -ne 0) { throw "F: rename so de caixa deveria sair com exit 0; obtido $($rF.ExitCode). Saida: $($rF.Output)" }
    $namesF = @(Get-ChildItem -LiteralPath $f.AttrDir -Filter *.xml -File | ForEach-Object { $_.Name })
    if ($namesF.Count -ne 1) { throw "F: deveria sobrar um unico arquivo; encontrados $($namesF.Count): $($namesF -join ', ')" }
    if ($namesF[0] -cne 'alpha.xml') { throw "F: o filename deveria ter a caixa nova 'alpha.xml'; obtido '$($namesF[0])'" }
    $repFObj = Get-Content -LiteralPath $repF -Raw | ConvertFrom-Json
    if ($repFObj.Summary.RenamedByGuid -ne 1) { throw "F: RenamedByGuid deveria ser 1; obtido $($repFObj.Summary.RenamedByGuid)" }

    # --- G: criacao + -ExpectedItems (listas nominais e Expected*Names achatado) ---
    $g = New-CaseDir -Name 'expected'
    $pkgG = Join-Path $g.Root 'pacote.xml'
    New-Package -Path $pkgG -Guid $guid1 -Name 'Gamma' -LastUpdate '2026-01-01T00:00:00.0000000Z'
    $repG = Join-Path $g.Root 'report.json'
    $rG = Invoke-Sync -Pkg $pkgG -Acervo $g.Acervo -ReportPath $repG -ExpectedItems @('Attribute:Gamma', 'Attribute:Delta')
    if ($rG.ExitCode -ne 0) { throw "G: criacao deveria sair com exit 0; obtido $($rG.ExitCode). Saida: $($rG.Output)" }
    $gObj = Assert-StdoutIsPureJson -Case 'G' -Result $rG
    # Invariante len(*Names) == contador.
    if (@($gObj.CreatedNames).Count -ne $gObj.Created) { throw "G: len(CreatedNames) ($(@($gObj.CreatedNames).Count)) != Created ($($gObj.Created))" }
    if ($gObj.CreatedNames -notcontains 'Attribute:Gamma') { throw "G: CreatedNames deveria conter 'Attribute:Gamma'; obtido [$($gObj.CreatedNames -join ', ')]" }
    # Listas sem itens serializam [] (array), nao null nem escalar.
    if ($null -eq $gObj.UpdatedNames -or @($gObj.UpdatedNames).Count -ne 0) { throw "G: UpdatedNames deveria ser [] vazio (nao null)" }
    # Expected*Names achatado: a fonte das tres partes do handoff.
    if ($gObj.ExpectedReturnedNames -notcontains 'Attribute:Gamma') { throw "G: ExpectedReturnedNames deveria conter 'Attribute:Gamma'; obtido [$($gObj.ExpectedReturnedNames -join ', ')]" }
    if ($gObj.ExpectedMissingNames -notcontains 'Attribute:Delta') { throw "G: ExpectedMissingNames deveria conter 'Attribute:Delta'; obtido [$($gObj.ExpectedMissingNames -join ', ')]" }
    # Confronto com o $report no arquivo: as mesmas listas existem em Summary.
    $repGObj = Get-Content -LiteralPath $repG -Raw | ConvertFrom-Json
    if ($repGObj.Summary.CreatedNames -notcontains 'Attribute:Gamma') { throw "G: report.Summary.CreatedNames deveria conter 'Attribute:Gamma'" }

    Write-Output 'OK: Test-XpzSyncGuidRenameSelfTest.ps1'
    exit 0
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
