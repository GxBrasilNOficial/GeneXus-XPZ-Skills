#requires -Version 7.4

<#
.SYNOPSIS
    Self-test deterministico de Build-PrePushReviewDossier.ps1.

.DESCRIPTION
    Monta repositorios git temporarios locais (sem rede) e confere o contrato do
    dossie pre-push (design congelado v15, casos 9(a-f,n)):

      (a) repo com commits pendentes: Secoes A/B presentes, cabecalho literal da
          Secao B, sentinelas HEAD:/END_DOSSIER; RECOMPUTA o sha256 do corpo e confere.
      (b) dossierReady=false SO sem git (b1) ou sem origin/main (b2).
      (c) parse quebrado no scripts/ do repo => mechanicalStatus=failed, dossierReady=true.
      (d) commitsBehind>0 => pushReadiness=blocked + intervalDiffDiagnosticOnly.
      (e) -FetchStatus not-fetched/fetch-failed => remoteFreshness=stale; fetched => fresh.
      (f) sizeChars reportado e igual ao tamanho do dossierText.
      (n) status --porcelain nao-vazio => workingTreeDirty=true + lista de paths carimbada.

    Requer o executavel git (o proprio recurso depende dele).
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# O dossie carrega acentos; decodificar a saida do builder-filho como UTF-8 sem BOM
# (o builder tambem forca UTF-8 no proprio stdout) evita corrupcao por code page.
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$builder = Join-Path $PSScriptRoot 'Build-PrePushReviewDossier.ps1'
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
    throw "BLOCK: script alvo nao encontrado: $builder"
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'BLOCK: git ausente; este self-test requer o executavel git.'
}

. (Join-Path $PSScriptRoot 'Utf8NoBomEncodingSupport.ps1')

$failures = 0
$cases = 0

function New-TempDir {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ('xpz-dossier-selftest-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

function Remove-TempDir {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Attributes = 'Normal' }
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Set-RepoFile {
    param([string]$Root, [string]$RelativePath, [string]$Content)
    $full = Join-Path $Root $RelativePath
    $dir = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $dir)) {
        [void](New-Item -ItemType Directory -Path $dir -Force)
    }
    # -NoNewline: o proprio $Content ja traz o \n final desejado; sem isso, Set-Content
    # adiciona um segundo => linha em branco no EOF => git diff --check acusa whitespace.
    Set-Content -LiteralPath $full -Value $Content -Encoding utf8 -NoNewline
}

function Initialize-DossierRepo {
    # Repo com 1 commit base (=> origin/main) e 1 commit adiante (=> HEAD ahead).
    param([string]$Root, [switch]$BrokenScript)

    & git -C $Root init -b main *> $null
    & git -C $Root config user.email 'selftest@example.com' *> $null
    & git -C $Root config user.name 'Self Test' *> $null

    if ($BrokenScript) {
        Set-RepoFile -Root $Root -RelativePath 'scripts/broken.ps1' -Content "function Foo {`n"
    } else {
        Set-RepoFile -Root $Root -RelativePath 'scripts/valid.ps1' -Content "Write-Output 'ok'`n"
    }
    # Um .py valido garante que o gate de parse Python do mecanico rode sem tropecar
    # no acesso a array vazio ($files.FullName) sob StrictMode em scripts/ sem .py.
    Set-RepoFile -Root $Root -RelativePath 'scripts/valid.py' -Content "x = 1`n"
    Set-RepoFile -Root $Root -RelativePath 'README.md' -Content "# base`n"
    & git -C $Root add -A *> $null
    & git -C $Root commit -m 'base' *> $null
    $baseSha = (& git -C $Root rev-parse HEAD).Trim()
    & git -C $Root update-ref refs/remotes/origin/main $baseSha *> $null

    Set-RepoFile -Root $Root -RelativePath 'feature.md' -Content "# feature`n"
    & git -C $Root add -A *> $null
    & git -C $Root commit -m 'feature' *> $null

    return $baseSha
}

function Invoke-Builder {
    param([string[]]$BuilderArgs)
    $out = & pwsh -NoProfile -File $builder @BuilderArgs 2>&1 | Out-String
    return $out.Trim()
}

function Assert-True {
    param([string]$CaseName, [bool]$Condition, [string]$Detail = '')
    $script:cases++
    if ($Condition) {
        Write-Output ("PASS: {0}" -f $CaseName)
    } else {
        $script:failures++
        Write-Output ("FAIL: {0}" -f $CaseName)
        if ($Detail) { Write-Output ("      {0}" -f $Detail) }
    }
}

function Copy-EnumerationFixtureScripts {
    param([string]$Root)
    foreach ($name in @(
        'Invoke-PrePushMechanicalChecks.ps1',
        'Test-PsScriptsParse.ps1',
        'Test-PyScriptsParse.ps1',
        'Test-PrePushGateEnumerationParity.ps1',
        'Test-PrePushBackendEnumerationParity.ps1',
        'Invoke-LlmDelegatePanelDispatch.ps1'
    )) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $Root "scripts/$name") -Force
    }
}

function Initialize-EnumerationFixtureRepo {
    param([string]$Root)
    [void](New-Item -ItemType Directory -Path $Root -Force)
    [void](New-Item -ItemType Directory -Path (Join-Path $Root 'scripts') -Force)
    [void](New-Item -ItemType Directory -Path (Join-Path $Root 'xpz-llm-delegate') -Force)
    Copy-EnumerationFixtureScripts -Root $Root
    Set-RepoFile -Root $Root -RelativePath 'scripts/valid.py' -Content "x = 1`n"
    Set-RepoFile -Root $Root -RelativePath 'README.md' -Content @'
# Fixture de enumeração

Os gates consultivos cobrem `Test-PrePushTraceabilityCoverage.ps1` e `Test-PrePushMsBuildProbeDocParity.ps1`.
'@
    Set-RepoFile -Root $Root -RelativePath 'xpz-llm-delegate/SKILL.md' -Content @'
# Dispatcher

Backends documentados: OpenCode, Codex e Claude Code.
Menção de teste ao backend future-llm, ainda não canônico.
'@

    & git -C $Root init -b main *> $null
    & git -C $Root config user.email 'selftest@example.com' *> $null
    & git -C $Root config user.name 'Self Test' *> $null
    & git -C $Root add -A *> $null
    & git -C $Root commit -m 'base' *> $null
    $baseSha = (& git -C $Root rev-parse HEAD).Trim()
    & git -C $Root update-ref refs/remotes/origin/main $baseSha *> $null
    Set-RepoFile -Root $Root -RelativePath 'feature.md' -Content "# feature`n"
    & git -C $Root add -A *> $null
    & git -C $Root commit -m 'feature' *> $null
    return $baseSha
}

function Get-MechanicalPayloadFromDossier {
    param($Dossier)
    $text = [string]$Dossier.dossierText
    $header = '=== SEÇÃO B — DIAGNÓSTICO MECÂNICO DO ORQUESTRADOR (candidatas a verificar, NÃO verdade) ==='
    $headerIndex = $text.IndexOf($header, [System.StringComparison]::Ordinal)
    $headIndex = $text.LastIndexOf("`nHEAD: ", [System.StringComparison]::Ordinal)
    if ($headerIndex -lt 0 -or $headIndex -le $headerIndex) {
        throw 'Não foi possível localizar o JSON mecânico na Seção B do dossiê.'
    }
    $jsonStart = $headerIndex + $header.Length
    $jsonText = $text.Substring($jsonStart, $headIndex - $jsonStart).Trim()
    return ($jsonText | ConvertFrom-Json -ErrorAction Stop)
}

function New-TriageEntry {
    param($Finding, [string]$Kind, [string[]]$CanonicalMembers, [string]$Reason)
    $entry = [ordered]@{
        code = [string]$Finding.code
        file = [string]$Finding.file
        unitHash = [string]$Finding.unitHash
        listedMembers = @($Finding.listedMembers | ForEach-Object { [string]$_ })
        verdict = 'non-gap'
        reason = $Reason
        triagedAt = '2026-10-18'
        triagedBy = 'selftest'
        kind = $Kind
        excerpt = ''
    }
    if ($Kind -eq 'live-contract') { $entry.canonicalMembers = @($CanonicalMembers) }
    return $entry
}

function Write-TriageCatalog {
    param([string]$Root, [object[]]$Entries, [string]$RawJson)
    $catalogPath = Join-Path $Root 'scripts/PrePushEnumerationTriage.json'
    if ($PSBoundParameters.ContainsKey('RawJson')) {
        Set-RepoFile -Root $Root -RelativePath 'scripts/PrePushEnumerationTriage.json' -Content $RawJson
        return
    }
    $catalog = [ordered]@{ schemaVersion = 1; entries = @($Entries) }
    Set-RepoFile -Root $Root -RelativePath 'scripts/PrePushEnumerationTriage.json' -Content (($catalog | ConvertTo-Json -Depth 8) + "`n")
}

function Invoke-EnumerationFixtureBuilder {
    param([string]$Root)
    $mechanicalPath = Join-Path $Root 'scripts/Invoke-PrePushMechanicalChecks.ps1'
    $jsonText = Invoke-Builder -BuilderArgs @('-RootPath', $Root, '-MechanicalScriptPath', $mechanicalPath, '-AsJson')
    return ($jsonText | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-EnumerationMechanicalPass {
    param([string]$Name, $Dossier, $Mechanical)
    Assert-True -CaseName "${Name}: dossier mechanicalStatus=passed" -Condition ($Dossier.mechanicalStatus -eq 'passed') -Detail ("mechanicalStatus={0}" -f $Dossier.mechanicalStatus)
    Assert-True -CaseName "${Name}: mechanical status pass" -Condition ($Mechanical.status -eq 'pass') -Detail ("status={0}" -f $Mechanical.status)
    Assert-True -CaseName "${Name}: mechanicalFailures vazias" -Condition (@($Dossier.mechanicalFailures).Count -eq 0) -Detail ("mechanicalFailures={0}" -f (@($Dossier.mechanicalFailures) -join ', '))
}

# ---------------------------------------------------------------------------
# Caso (a): dossie completo + recomputo do sha256 do corpo
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    [void](Initialize-DossierRepo -Root $tmp)
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-AsJson') | ConvertFrom-Json

    Assert-True -CaseName 'a: dossierReady=true' -Condition ($json.dossierReady -eq $true)
    Assert-True -CaseName 'a: mechanicalStatus=passed' -Condition ($json.mechanicalStatus -eq 'passed') -Detail ("mechanicalStatus={0} exit={1}" -f $json.mechanicalStatus, $json.mechanicalExitCode)

    $text = [string]$json.dossierText
    Assert-True -CaseName 'a: Secao A presente' -Condition ($text -match '=== SEÇÃO A — GIT BRUTO \(FATO\) ===')
    $expectedBHeader = '=== SEÇÃO B — DIAGNÓSTICO MECÂNICO DO ORQUESTRADOR (candidatas a verificar, NÃO verdade) ==='
    Assert-True -CaseName 'a: cabecalho literal Secao B' -Condition ($text.Contains($expectedBHeader)) -Detail 'cabecalho da Secao B ausente/divergente'

    $headMatch = [regex]::Match($text, '(?m)^HEAD:\s*([0-9a-f]{40})\s*$')
    $endMatch = [regex]::Match($text, '(?m)^END_DOSSIER sha256=([0-9a-f]{64})\s*$')
    Assert-True -CaseName 'a: sentinela HEAD:' -Condition $headMatch.Success
    Assert-True -CaseName 'a: sentinela END_DOSSIER' -Condition $endMatch.Success

    # Recomputo: corpo = tudo antes de "\nHEAD: "; hash UTF-8 sem BOM, LF.
    $idx = $text.LastIndexOf("`nHEAD: ")
    Assert-True -CaseName 'a: fronteira do corpo localizada' -Condition ($idx -gt 0)
    if ($idx -gt 0 -and $endMatch.Success) {
        $body = $text.Substring(0, $idx)
        $bodyLf = ($body -replace "`r`n", "`n" -replace "`r", "`n")
        $enc = Get-Utf8NoBomEncoding
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $hashBytes = $sha.ComputeHash($enc.GetBytes($bodyLf)) } finally { $sha.Dispose() }
        $recomputed = (([System.BitConverter]::ToString($hashBytes)) -replace '-', '').ToLowerInvariant()
        $sentinelHash = $endMatch.Groups[1].Value.ToLowerInvariant()
        Assert-True -CaseName 'a: sha256 recomputado == sentinela' -Condition ($recomputed -eq $sentinelHash) -Detail ("recomputado={0} sentinela={1}" -f $recomputed, $sentinelHash)
        Assert-True -CaseName 'a: sha256 recomputado == bodySha256' -Condition ($recomputed -eq ([string]$json.bodySha256))
    }
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (b1): sem git => dossierReady=false
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    Set-RepoFile -Root $tmp -RelativePath 'README.md' -Content '# nao e repo'
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'b1: sem git => dossierReady=false' -Condition ($json.dossierReady -eq $false) -Detail ("reason={0}" -f $json.notReadyReason)
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (b2): repo git sem origin/main => dossierReady=false
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    & git -C $tmp config user.email 'selftest@example.com' *> $null
    & git -C $tmp config user.name 'Self Test' *> $null
    Set-RepoFile -Root $tmp -RelativePath 'README.md' -Content '# base'
    & git -C $tmp add -A *> $null
    & git -C $tmp commit -m 'base' *> $null
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'b2: sem origin/main => dossierReady=false' -Condition ($json.dossierReady -eq $false) -Detail ("reason={0}" -f $json.notReadyReason)
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (c): JSON VALIDO + exit != 0 (parse-gate do mecanico falho) => mechanicalStatus
# =failed, dossierReady=true, e os campos vem DO JSON (parseOk=true). Contrasta com o
# caso (o) (JSON imparseavel => modo degradado => pushReadiness/intervalDiffDiagnosticOnly
# indeterminados). O .ps1 quebrado faz o parse-gate reprovar: o mecanico sai 1 mas emite
# JSON valido; commitsBehind=0 (HEAD a frente por 1, atras por 0) => pushReadiness='ok'.
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    [void](Initialize-DossierRepo -Root $tmp -BrokenScript)
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'c: dossierReady=true (mesmo com parse quebrado)' -Condition ($json.dossierReady -eq $true)
    Assert-True -CaseName 'c: mechanicalStatus=failed' -Condition ($json.mechanicalStatus -eq 'failed') -Detail ("mechanicalStatus={0} exit={1}" -f $json.mechanicalStatus, $json.mechanicalExitCode)
    Assert-True -CaseName 'c: mechanicalExitCode != 0 com JSON valido' -Condition ($json.mechanicalExitCode -ne 0) -Detail ("exit={0}" -f $json.mechanicalExitCode)
    Assert-True -CaseName 'c: pushReadiness vem do JSON (ok, NAO degradado unknown)' -Condition ($json.pushReadiness -eq 'ok') -Detail ("pushReadiness={0}" -f $json.pushReadiness)
    Assert-True -CaseName 'c: intervalDiffDiagnosticOnly do JSON (false bool, NAO null)' -Condition ($json.intervalDiffDiagnosticOnly -eq $false) -Detail ("intervalDiffDiagnosticOnly={0}" -f $json.intervalDiffDiagnosticOnly)
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (d): commitsBehind>0 => pushReadiness=blocked + intervalDiffDiagnosticOnly
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    $baseSha = Initialize-DossierRepo -Root $tmp
    # origin/main aponta para HEAD (feature); reseta HEAD para base => HEAD atras por 1.
    $featureSha = (& git -C $tmp rev-parse HEAD).Trim()
    & git -C $tmp update-ref refs/remotes/origin/main $featureSha *> $null
    & git -C $tmp reset --hard $baseSha *> $null
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'd: commitsBehind>0' -Condition ($json.commitsBehind -gt 0) -Detail ("commitsBehind={0}" -f $json.commitsBehind)
    Assert-True -CaseName 'd: pushReadiness=blocked' -Condition ($json.pushReadiness -eq 'blocked') -Detail ("pushReadiness={0}" -f $json.pushReadiness)
    Assert-True -CaseName 'd: intervalDiffDiagnosticOnly=true' -Condition ($json.intervalDiffDiagnosticOnly -eq $true)
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (e): remoteFreshness derivado do FetchStatus
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    [void](Initialize-DossierRepo -Root $tmp)
    $jsonNotFetched = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-FetchStatus', 'not-fetched', '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'e: not-fetched => remoteFreshness=stale' -Condition ($jsonNotFetched.remoteFreshness -eq 'stale')
    $jsonFailed = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-FetchStatus', 'fetch-failed', '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'e: fetch-failed => remoteFreshness=stale' -Condition ($jsonFailed.remoteFreshness -eq 'stale')
    $jsonFetched = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-FetchStatus', 'fetched', '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'e: fetched => remoteFreshness=fresh' -Condition ($jsonFetched.remoteFreshness -eq 'fresh')
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (f): sizeChars reportado e coerente com o dossierText
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    [void](Initialize-DossierRepo -Root $tmp)
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'f: sizeChars>0' -Condition ($json.sizeChars -gt 0)
    Assert-True -CaseName 'f: sizeChars == len(dossierText)' -Condition ($json.sizeChars -eq ([string]$json.dossierText).Length) -Detail ("sizeChars={0} len={1}" -f $json.sizeChars, ([string]$json.dossierText).Length)
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (n): working tree suja => workingTreeDirty + lista de paths
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    [void](Initialize-DossierRepo -Root $tmp)
    Set-RepoFile -Root $tmp -RelativePath 'README.md' -Content "# base modificado sem commit`n"
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'n: workingTreeDirty=true' -Condition ($json.workingTreeDirty -eq $true)
    $dirty = @($json.dirtyPaths)
    Assert-True -CaseName 'n: lista de paths sujos carimbada' -Condition ($dirty.Count -gt 0 -and ($dirty -contains 'README.md')) -Detail ("dirtyPaths={0}" -f ($dirty -join ', '))
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (o): mecanico imparseavel (modo degradado, a') => builder reafirma SO o fato
# bruto commitsBehind; pushReadiness/intervalDiffDiagnosticOnly ficam indeterminados
# (a politica push-ready do motor NAO e reencenada pelo builder sob falha).
# ---------------------------------------------------------------------------
$tmp = New-TempDir
$fakeMech = Join-Path ([System.IO.Path]::GetTempPath()) ('fake-mech-' + [Guid]::NewGuid().ToString('N') + '.ps1')
try {
    $baseSha = Initialize-DossierRepo -Root $tmp
    # HEAD atras de origin/main por 1 (commitsBehind>0), como no caso (d)
    $featureSha = (& git -C $tmp rev-parse HEAD).Trim()
    & git -C $tmp update-ref refs/remotes/origin/main $featureSha *> $null
    & git -C $tmp reset --hard $baseSha *> $null
    # Mecanico falso: saida NAO-JSON + exit 1 => builder parseOk=false (modo degradado)
    Set-Content -LiteralPath $fakeMech -Value "param([string]`$RootPath,[string]`$BaseRef,[switch]`$AsJson)`nWrite-Output 'BOOM: saida nao-JSON do mecanico'`nexit 1" -Encoding utf8 -NoNewline
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-MechanicalScriptPath', $fakeMech, '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'o: dossierReady=true (mecanico imparseavel)' -Condition ($json.dossierReady -eq $true)
    Assert-True -CaseName 'o: mechanicalStatus=failed' -Condition ($json.mechanicalStatus -eq 'failed') -Detail ("status={0}" -f $json.mechanicalStatus)
    Assert-True -CaseName 'o: commitsBehind bruto preservado (>0)' -Condition ($json.commitsBehind -gt 0) -Detail ("commitsBehind={0}" -f $json.commitsBehind)
    Assert-True -CaseName 'o: pushReadiness=unknown (politica NAO reencenada)' -Condition ($json.pushReadiness -eq 'unknown') -Detail ("pushReadiness={0}" -f $json.pushReadiness)
    Assert-True -CaseName 'o: intervalDiffDiagnosticOnly indeterminado (null)' -Condition ($null -eq $json.intervalDiffDiagnosticOnly) -Detail ("intervalDiffDiagnosticOnly={0}" -f $json.intervalDiffDiagnosticOnly)
}
finally {
    Remove-TempDir -Path $tmp
    if (Test-Path -LiteralPath $fakeMech) { Remove-Item -LiteralPath $fakeMech -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# Caso (p): origin/main existe mas HEAD NAO-NASCIDO (symref pendente) => o builder
# nao lanca sob StrictMode; devolve dossierReady=false, notReadyReason='head-unresolved'.
# Setup: commit (cria refs/heads/main + origin/main) e depois deleta refs/heads/main,
# deixando HEAD apontando para uma ref inexistente (rev-parse HEAD falha).
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    & git -C $tmp init -b main *> $null
    & git -C $tmp config user.email 'selftest@example.com' *> $null
    & git -C $tmp config user.name 'Self Test' *> $null
    Set-RepoFile -Root $tmp -RelativePath 'README.md' -Content '# base'
    & git -C $tmp add -A *> $null
    & git -C $tmp commit -m 'base' *> $null
    $baseSha = (& git -C $tmp rev-parse HEAD).Trim()
    & git -C $tmp update-ref refs/remotes/origin/main $baseSha *> $null
    & git -C $tmp update-ref -d refs/heads/main *> $null   # HEAD -> refs/heads/main inexistente
    $json = Invoke-Builder -BuilderArgs @('-RootPath', $tmp, '-AsJson') | ConvertFrom-Json
    Assert-True -CaseName 'p: HEAD nao-nascido => dossierReady=false (nao lanca)' -Condition ($json.dossierReady -eq $false) -Detail ("reason={0}" -f $json.notReadyReason)
    Assert-True -CaseName 'p: notReadyReason=head-unresolved' -Condition ($json.notReadyReason -eq 'head-unresolved') -Detail ("reason={0}" -f $json.notReadyReason)
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (q): triagem versionada, varredura completa e invocacao real pelo builder
# ---------------------------------------------------------------------------
$tmp = New-TempDir
try {
    [void](Initialize-EnumerationFixtureRepo -Root $tmp)
    $dispatcherPath = Join-Path $tmp 'scripts/Invoke-LlmDelegatePanelDispatch.ps1'
    $dispatcherOriginal = [System.IO.File]::ReadAllText($dispatcherPath)
    $initialReadme = [System.IO.File]::ReadAllText((Join-Path $tmp 'README.md'))

    $firstDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $firstMechanical = Get-MechanicalPayloadFromDossier -Dossier $firstDossier
    Assert-EnumerationMechanicalPass -Name 'q1 initial' -Dossier $firstDossier -Mechanical $firstMechanical
    Assert-True -CaseName 'q1: catálogo resolvido sob RootPath' -Condition ($firstMechanical.enumerationTriage.catalog.path -eq 'scripts/PrePushEnumerationTriage.json')
    Assert-True -CaseName 'q1: ausência do catálogo registrada' -Condition (@($firstMechanical.enumerationTriage.catalog.problems | Where-Object { $_.code -eq 'TRIAGE_CATALOG_MISSING' }).Count -eq 1)
    Assert-True -CaseName 'q1: ambas as varreduras completas' -Condition ($firstMechanical.enumerationTriage.scanComplete -and $firstMechanical.gates.gateEnumerationParity.scanComplete -and $firstMechanical.gates.backendEnumerationParity.scanComplete)

    $gateFinding = @($firstMechanical.gates.gateEnumerationParity.findings | Where-Object { $_.code -eq 'GATE_ENUMERATION_SUBSET' })[0]
    $backendFinding = @($firstMechanical.gates.backendEnumerationParity.findings | Where-Object { $_.code -eq 'BACKEND_ENUMERATION_SUBSET' })[0]
    if ($null -eq $gateFinding -or $null -eq $backendFinding) {
        throw 'A fixture deveria produzir uma candidata de gate e uma candidata de backend.'
    }
    Assert-True -CaseName 'q1: candidatos gate/backend novos' -Condition (@($firstMechanical.enumerationTriage.newFindings).Count -eq 2)
    $gateEntry = New-TriageEntry -Finding $gateFinding -Kind 'closed' -CanonicalMembers @() -Reason 'Recorte de exemplo nao declara o conjunto integral.'
    $backendCanonical = @($firstMechanical.gates.backendEnumerationParity.canonicalMembers | ForEach-Object { [string]$_ })
    $backendEntry = New-TriageEntry -Finding $backendFinding -Kind 'live-contract' -CanonicalMembers $backendCanonical -Reason 'A frase descreve um recorte documentado.'
    $validEntries = @($gateEntry, $backendEntry)

    Write-TriageCatalog -Root $tmp -Entries $validEntries
    $triagedDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $triagedMechanical = Get-MechanicalPayloadFromDossier -Dossier $triagedDossier
    Assert-EnumerationMechanicalPass -Name 'q2 catalogo valido' -Dossier $triagedDossier -Mechanical $triagedMechanical
    Assert-True -CaseName 'q2: catálogo válido e duas triagens' -Condition ($triagedMechanical.enumerationTriage.catalog.valid -and $triagedMechanical.enumerationTriage.counts.triaged -eq 2 -and $triagedMechanical.enumerationTriage.counts.new -eq 0)
    Assert-True -CaseName 'q2: motivo de triagem visível' -Condition (@($triagedMechanical.enumerationTriage.triagedFindings | Where-Object { $_.reason -eq 'A frase descreve um recorte documentado.' }).Count -eq 1)

    Write-TriageCatalog -Root $tmp -Entries @() -RawJson '{ JSON invalido'
    $invalidDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $invalidMechanical = Get-MechanicalPayloadFromDossier -Dossier $invalidDossier
    Assert-EnumerationMechanicalPass -Name 'q3 catalogo invalido' -Dossier $invalidDossier -Mechanical $invalidMechanical
    Assert-True -CaseName 'q3: JSON inválido não suprime candidatos' -Condition (-not $invalidMechanical.enumerationTriage.catalog.valid -and $invalidMechanical.enumerationTriage.counts.new -eq 2 -and @($invalidMechanical.enumerationTriage.catalog.problems | Where-Object { $_.code -eq 'TRIAGE_CATALOG_INVALID_JSON' }).Count -eq 1)

    Write-TriageCatalog -Root $tmp -Entries @() -RawJson '{"schemaVersion":"not-a-number","entries":[]}'
    $invalidSchemaDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $invalidSchemaMechanical = Get-MechanicalPayloadFromDossier -Dossier $invalidSchemaDossier
    Assert-EnumerationMechanicalPass -Name 'q3b schemaVersion nao numerico' -Dossier $invalidSchemaDossier -Mechanical $invalidSchemaMechanical
    Assert-True -CaseName 'q3b: schemaVersion não numérico mantém candidatos novos' -Condition (-not $invalidSchemaMechanical.enumerationTriage.catalog.valid -and $invalidSchemaMechanical.enumerationTriage.counts.new -eq 2 -and @($invalidSchemaMechanical.enumerationTriage.catalog.problems | Where-Object { $_.code -eq 'TRIAGE_CATALOG_SCHEMA_INVALID' }).Count -eq 1)

    Write-TriageCatalog -Root $tmp -Entries @() -RawJson '{"schemaVersion":true,"entries":[]}'
    $coercibleSchemaDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $coercibleSchemaMechanical = Get-MechanicalPayloadFromDossier -Dossier $coercibleSchemaDossier
    Assert-EnumerationMechanicalPass -Name 'q3c schemaVersion booleano' -Dossier $coercibleSchemaDossier -Mechanical $coercibleSchemaMechanical
    Assert-True -CaseName 'q3c: schemaVersion booleano não é aceito por coerção' -Condition (-not $coercibleSchemaMechanical.enumerationTriage.catalog.valid -and $coercibleSchemaMechanical.enumerationTriage.counts.new -eq 2 -and @($coercibleSchemaMechanical.enumerationTriage.catalog.problems | Where-Object { $_.code -eq 'TRIAGE_CATALOG_SCHEMA_INVALID' }).Count -eq 1)

    Write-TriageCatalog -Root $tmp -Entries @() -RawJson 'null'
    $nullCatalogDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $nullCatalogMechanical = Get-MechanicalPayloadFromDossier -Dossier $nullCatalogDossier
    Assert-EnumerationMechanicalPass -Name 'q3d raiz JSON nula' -Dossier $nullCatalogDossier -Mechanical $nullCatalogMechanical
    Assert-True -CaseName 'q3d: raiz JSON nula mantém candidatos novos' -Condition (-not $nullCatalogMechanical.enumerationTriage.catalog.valid -and $nullCatalogMechanical.enumerationTriage.counts.new -eq 2 -and @($nullCatalogMechanical.enumerationTriage.catalog.problems | Where-Object { $_.code -eq 'TRIAGE_CATALOG_SCHEMA_INVALID' }).Count -eq 1)

    $validCatalogJson = [ordered]@{ schemaVersion = 1; entries = $validEntries } | ConvertTo-Json -Depth 8 -Compress
    $invalidCatalogRoots = [ordered]@{
        'empty-array' = '[]'
        'null-array' = '[null]'
        'object-array' = ('[' + $validCatalogJson + ']')
        'scalar' = '42'
    }
    foreach ($rootKind in $invalidCatalogRoots.Keys) {
        Write-TriageCatalog -Root $tmp -Entries @() -RawJson $invalidCatalogRoots[$rootKind]
        $rootDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
        $rootMechanical = Get-MechanicalPayloadFromDossier -Dossier $rootDossier
        Assert-EnumerationMechanicalPass -Name "q3root $rootKind" -Dossier $rootDossier -Mechanical $rootMechanical
        Assert-True -CaseName "q3root ${rootKind}: raiz inválida não suprime candidatos" -Condition (-not $rootMechanical.enumerationTriage.catalog.valid -and $rootMechanical.enumerationTriage.counts.new -eq 2 -and @($rootMechanical.enumerationTriage.catalog.problems | Where-Object { $_.code -eq 'TRIAGE_CATALOG_SCHEMA_INVALID' }).Count -eq 1)
    }

    $manyInvalidEntries = @(foreach ($number in 1..55) { [pscustomobject]@{ code = "INVALID_$number" } })
    Write-TriageCatalog -Root $tmp -Entries $manyInvalidEntries
    $manyProblemsDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $manyProblemsMechanical = Get-MechanicalPayloadFromDossier -Dossier $manyProblemsDossier
    Assert-EnumerationMechanicalPass -Name 'q3e problemas integrais do catálogo' -Dossier $manyProblemsDossier -Mechanical $manyProblemsMechanical
    Assert-True -CaseName 'q3e: 55 problemas permanecem visíveis e candidatos seguem novos' -Condition (-not $manyProblemsMechanical.enumerationTriage.catalog.valid -and @($manyProblemsMechanical.enumerationTriage.catalog.problems).Count -eq 55 -and $manyProblemsMechanical.enumerationTriage.counts.new -eq 2)
    Assert-True -CaseName 'q3e: problemas integrais não contam como truncamento' -Condition (-not $manyProblemsMechanical.enumerationTriage.displayTruncated -and $manyProblemsMechanical.enumerationTriage.displayTruncatedCount -eq 0)
    Assert-True -CaseName 'q3e: não avisa omissão quando todos os itens são apresentados' -Condition (@($manyProblemsMechanical.agentWarnings | Where-Object { $_ -like '*fora dos limites de apresentação por grupo*' }).Count -eq 0)

    Write-TriageCatalog -Root $tmp -Entries @($gateEntry, $gateEntry, $backendEntry)
    $duplicateDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $duplicateMechanical = Get-MechanicalPayloadFromDossier -Dossier $duplicateDossier
    Assert-EnumerationMechanicalPass -Name 'q4 ancora duplicada' -Dossier $duplicateDossier -Mechanical $duplicateMechanical
    Assert-True -CaseName 'q4: âncora duplicada segue nova e outra triagem funciona' -Condition ($duplicateMechanical.enumerationTriage.catalog.valid -and $duplicateMechanical.enumerationTriage.counts.new -eq 1 -and $duplicateMechanical.enumerationTriage.counts.triaged -eq 1 -and @($duplicateMechanical.enumerationTriage.catalog.problems | Where-Object { $_.code -eq 'TRIAGE_ENTRY_DUPLICATE' }).Count -eq 1)

    Write-TriageCatalog -Root $tmp -Entries $validEntries
    $needle = "    'antigravity' = 'Invoke-Antigravity.ps1'"
    if (-not $dispatcherOriginal.Contains($needle, [System.StringComparison]::Ordinal)) { throw 'Não achei a linha canônica antigravity na fixture do dispatcher.' }
    $dispatcherExpanded = $dispatcherOriginal.Replace($needle, $needle + [Environment]::NewLine + "    'future-llm'  = 'Invoke-FutureLlm.ps1'")
    [System.IO.File]::WriteAllText($dispatcherPath, $dispatcherExpanded, [System.Text.UTF8Encoding]::new($false))
    $expiredDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $expiredMechanical = Get-MechanicalPayloadFromDossier -Dossier $expiredDossier
    Assert-EnumerationMechanicalPass -Name 'q5 contrato vivo alterado' -Dossier $expiredDossier -Mechanical $expiredMechanical
    $changedBackendFinding = @($expiredMechanical.enumerationTriage.newFindings | Where-Object { $_.code -eq 'BACKEND_ENUMERATION_SUBSET' })[0]
    Assert-True -CaseName 'q5: conjunto canônico novo expira contrato vivo' -Condition (@($expiredMechanical.enumerationTriage.expiredEntries | Where-Object { $_.entry.code -eq 'BACKEND_ENUMERATION_SUBSET' }).Count -eq 1 -and $null -ne $changedBackendFinding -and @($changedBackendFinding.listedMembers | Where-Object { $_ -eq 'future-llm' }).Count -eq 1)
    [System.IO.File]::WriteAllText($dispatcherPath, $dispatcherOriginal, [System.Text.UTF8Encoding]::new($false))

    Write-TriageCatalog -Root $tmp -Entries $validEntries
    $editedReadme = $initialReadme.Replace('gates consultivos cobrem', 'gates consultivos incluem')
    Set-RepoFile -Root $tmp -RelativePath 'README.md' -Content $editedReadme
    $orphanDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $orphanMechanical = Get-MechanicalPayloadFromDossier -Dossier $orphanDossier
    Assert-EnumerationMechanicalPass -Name 'q6 texto editado' -Dossier $orphanDossier -Mechanical $orphanMechanical
    Assert-True -CaseName 'q6: edição invalida âncora e ocorrência antiga fica órfã' -Condition (@($orphanMechanical.enumerationTriage.newFindings | Where-Object { $_.code -eq 'GATE_ENUMERATION_SUBSET' }).Count -eq 1 -and @($orphanMechanical.enumerationTriage.orphanedEntries | Where-Object { $_.entry.code -eq $gateEntry.code -and $_.entry.unitHash -eq $gateEntry.unitHash }).Count -eq 1)

    Write-TriageCatalog -Root $tmp -Entries $validEntries
    Remove-Item -LiteralPath $dispatcherPath -Force
    $incompleteDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $incompleteMechanical = Get-MechanicalPayloadFromDossier -Dossier $incompleteDossier
    Assert-EnumerationMechanicalPass -Name 'q7 varredura incompleta' -Dossier $incompleteDossier -Mechanical $incompleteMechanical
    Assert-True -CaseName 'q7: scanner incompleto impede declarar órfãos' -Condition (-not $incompleteMechanical.enumerationTriage.scanComplete -and @($incompleteMechanical.enumerationTriage.scanIssues).Count -gt 0 -and @($incompleteMechanical.enumerationTriage.orphanedEntries).Count -eq 0)

    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-LlmDelegatePanelDispatch.ps1') -Destination $dispatcherPath -Force
    Write-TriageCatalog -Root $tmp -Entries $validEntries
    $manyGateLines = [System.Collections.Generic.List[string]]::new()
    for ($number = 1; $number -le 55; $number++) {
        $manyGateLines.Add(("Recorte {0:D2}: `{1}` e `{2}` são citados." -f $number, $gateEntry.listedMembers[0], $gateEntry.listedMembers[1]))
    }
    Set-RepoFile -Root $tmp -RelativePath 'README.md' -Content ('# Fixture de enumeração' + "`n`n" + ($manyGateLines -join "`n"))
    $cappedDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $cappedMechanical = Get-MechanicalPayloadFromDossier -Dossier $cappedDossier
    Assert-EnumerationMechanicalPass -Name 'q8 limite de apresentação' -Dossier $cappedDossier -Mechanical $cappedMechanical
    Assert-True -CaseName 'q8: classificação completa antes do teto 50' -Condition ($cappedMechanical.enumerationTriage.counts.new -eq 55 -and @($cappedMechanical.enumerationTriage.newFindings).Count -eq 50 -and $cappedMechanical.enumerationTriage.displayTruncated -and $cappedMechanical.enumerationTriage.displayTruncatedCount -eq 5)

    # Neste cenário, as 55 candidatas são somente as linhas de gates do README.
    Set-RepoFile -Root $tmp -RelativePath 'xpz-llm-delegate/SKILL.md' -Content "# Fixture sem enumeração de backends`n"
    Write-TriageCatalog -Root $tmp -Entries $manyInvalidEntries
    $mixedCappedDossier = Invoke-EnumerationFixtureBuilder -Root $tmp
    $mixedCappedMechanical = Get-MechanicalPayloadFromDossier -Dossier $mixedCappedDossier
    Assert-EnumerationMechanicalPass -Name 'q8b candidatos truncados e problemas integrais' -Dossier $mixedCappedDossier -Mechanical $mixedCappedMechanical
    Assert-True -CaseName 'q8b: todos os problemas do catálogo continuam visíveis' -Condition (@($mixedCappedMechanical.enumerationTriage.catalog.problems).Count -eq 55)
    Assert-True -CaseName 'q8b: somente os cinco candidatos omitidos entram na contagem' -Condition ($mixedCappedMechanical.enumerationTriage.counts.new -eq 55 -and @($mixedCappedMechanical.enumerationTriage.newFindings).Count -eq 50 -and $mixedCappedMechanical.enumerationTriage.displayTruncated -and $mixedCappedMechanical.enumerationTriage.displayTruncatedCount -eq 5)
}
finally { Remove-TempDir -Path $tmp }

# ---------------------------------------------------------------------------
# Caso (r): falhas consultivas do gate permanecem estruturadas e nao mecanicas,
# inclusive exit zero + JSON/contrato validos com stderr nao vazio.
# ---------------------------------------------------------------------------
function Invoke-EnumerationGateFailureCase {
    param([string]$Mode, [string]$ExpectedIssue, [string]$RootJson, [switch]$CheckTextOutput)
    $caseRoot = New-TempDir
    try {
        [void](Initialize-EnumerationFixtureRepo -Root $caseRoot)
        $gatePath = Join-Path $caseRoot 'scripts/Test-PrePushGateEnumerationParity.ps1'
        switch ($Mode) {
            'missing' { Remove-Item -LiteralPath $gatePath -Force }
            'throw' { Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content "throw 'synthetic gate exception'`n" }
            { $_ -like 'root-*' -or $_ -like 'issue-*' } {
                $baselineDossier = Invoke-EnumerationFixtureBuilder -Root $caseRoot
                $baselineMechanical = Get-MechanicalPayloadFromDossier -Dossier $baselineDossier
                $baselineFinding = @($baselineMechanical.gates.gateEnumerationParity.findings)[0]
                if ($null -eq $baselineFinding) { throw 'A fixture deveria produzir uma candidata antes de simular a resposta do scanner.' }
                $staleEntry = New-TriageEntry -Finding $baselineFinding -Kind 'closed' -CanonicalMembers @() -Reason 'Triagem de regressão para cobertura de órfãos.'
                Write-TriageCatalog -Root $caseRoot -Entries @($staleEntry)
                Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content ("Write-Output '{0}'`nexit 0`n" -f $RootJson)
            }
            'nonzero-json' {
                $validJson = '{"status":"pass","scanComplete":true,"scanIssues":[],"canonicalMembers":[],"files":[],"candidateCount":0,"displayTruncated":false,"findings":[]}'
                Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content ("Write-Output '{0}'`nexit 7`n" -f $validJson)
            }
            'valid-json-stderr' {
                $validJson = '{"status":"pass","scanComplete":true,"scanIssues":[],"canonicalMembers":[],"files":[],"candidateCount":0,"displayTruncated":false,"findings":[]}'
                Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content ("Write-Output '{0}'`n[Console]::Error.WriteLine('synthetic advisory stderr')`nexit 0`n" -f $validJson)
            }
            'null-candidate-count' {
                $baselineDossier = Invoke-EnumerationFixtureBuilder -Root $caseRoot
                $baselineMechanical = Get-MechanicalPayloadFromDossier -Dossier $baselineDossier
                $baselineFinding = @($baselineMechanical.gates.gateEnumerationParity.findings)[0]
                if ($null -eq $baselineFinding) { throw 'A fixture deveria produzir uma candidata de gate antes de simular candidateCount nulo.' }
                $staleEntry = New-TriageEntry -Finding $baselineFinding -Kind 'closed' -CanonicalMembers @() -Reason 'Triagem de regressão para cobertura de órfãos.'
                Write-TriageCatalog -Root $caseRoot -Entries @($staleEntry)
                $invalidContractJson = '{"status":"pass","scanComplete":true,"scanIssues":[],"canonicalMembers":[],"files":[],"candidateCount":null,"displayTruncated":false,"findings":[]}'
                Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content ("Write-Output '{0}'`nexit 0`n" -f $invalidContractJson)
            }
            'null-file-state' {
                $baselineDossier = Invoke-EnumerationFixtureBuilder -Root $caseRoot
                $baselineMechanical = Get-MechanicalPayloadFromDossier -Dossier $baselineDossier
                $baselineFinding = @($baselineMechanical.gates.gateEnumerationParity.findings)[0]
                if ($null -eq $baselineFinding) { throw 'A fixture deveria produzir uma candidata de gate antes de simular estado por arquivo nulo.' }
                $staleEntry = New-TriageEntry -Finding $baselineFinding -Kind 'closed' -CanonicalMembers @() -Reason 'Triagem de regressão para cobertura de órfãos.'
                Write-TriageCatalog -Root $caseRoot -Entries @($staleEntry)
                $invalidContractJson = '{"status":"pass","scanComplete":true,"scanIssues":[],"canonicalMembers":[],"files":[null],"candidateCount":0,"displayTruncated":false,"findings":[]}'
                Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content ("Write-Output '{0}'`nexit 0`n" -f $invalidContractJson)
            }
            'null-finding' {
                $baselineDossier = Invoke-EnumerationFixtureBuilder -Root $caseRoot
                $baselineMechanical = Get-MechanicalPayloadFromDossier -Dossier $baselineDossier
                $baselineFinding = @($baselineMechanical.gates.gateEnumerationParity.findings)[0]
                if ($null -eq $baselineFinding) { throw 'A fixture deveria produzir uma candidata de gate antes de simular achado nulo.' }
                $staleEntry = New-TriageEntry -Finding $baselineFinding -Kind 'closed' -CanonicalMembers @() -Reason 'Triagem de regressão para cobertura de órfãos.'
                Write-TriageCatalog -Root $caseRoot -Entries @($staleEntry)
                $invalidContractJson = '{"status":"pass","scanComplete":true,"scanIssues":[],"canonicalMembers":[],"files":[],"candidateCount":1,"displayTruncated":false,"findings":[null]}'
                Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content ("Write-Output '{0}'`nexit 0`n" -f $invalidContractJson)
            }
            'complete-with-scan-issues' {
                $baselineDossier = Invoke-EnumerationFixtureBuilder -Root $caseRoot
                $baselineMechanical = Get-MechanicalPayloadFromDossier -Dossier $baselineDossier
                $baselineFinding = @($baselineMechanical.gates.gateEnumerationParity.findings)[0]
                if ($null -eq $baselineFinding) { throw 'A fixture deveria produzir uma candidata de gate antes de simular scanComplete contraditório.' }
                $staleEntry = New-TriageEntry -Finding $baselineFinding -Kind 'closed' -CanonicalMembers @() -Reason 'Triagem de regressão para cobertura de órfãos.'
                Write-TriageCatalog -Root $caseRoot -Entries @($staleEntry)
                $inconsistentJson = '{"status":"pass","scanComplete":true,"scanIssues":[{"code":"SYNTHETIC_SCAN_ISSUE","path":"README.md","message":"synthetic issue"}],"canonicalMembers":[],"files":[{"file":"README.md","complete":true}],"candidateCount":0,"displayTruncated":false,"findings":[]}'
                Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content ("Write-Output '{0}'`nexit 0`n" -f $inconsistentJson)
            }
            'complete-with-incomplete-file' {
                $baselineDossier = Invoke-EnumerationFixtureBuilder -Root $caseRoot
                $baselineMechanical = Get-MechanicalPayloadFromDossier -Dossier $baselineDossier
                $baselineFinding = @($baselineMechanical.gates.gateEnumerationParity.findings)[0]
                if ($null -eq $baselineFinding) { throw 'A fixture deveria produzir uma candidata de gate antes de simular arquivo incompleto.' }
                $staleEntry = New-TriageEntry -Finding $baselineFinding -Kind 'closed' -CanonicalMembers @() -Reason 'Triagem de regressão para cobertura de órfãos.'
                Write-TriageCatalog -Root $caseRoot -Entries @($staleEntry)
                $inconsistentJson = '{"status":"pass","scanComplete":true,"scanIssues":[],"canonicalMembers":[],"files":[{"file":"README.md","complete":false}],"candidateCount":0,"displayTruncated":false,"findings":[]}'
                Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content ("Write-Output '{0}'`nexit 0`n" -f $inconsistentJson)
            }
            'invalid-json' { Set-RepoFile -Root $caseRoot -RelativePath 'scripts/Test-PrePushGateEnumerationParity.ps1' -Content "Write-Output '{ not-json'`nexit 0`n" }
            default { throw "Modo de falha não reconhecido: $Mode" }
        }
        $dossier = Invoke-EnumerationFixtureBuilder -Root $caseRoot
        $mechanical = Get-MechanicalPayloadFromDossier -Dossier $dossier
        $gate = $mechanical.gates.gateEnumerationParity
        Assert-EnumerationMechanicalPass -Name "r $Mode" -Dossier $dossier -Mechanical $mechanical
        Assert-True -CaseName "r ${Mode}: triagem declara varredura incompleta" -Condition (-not $mechanical.enumerationTriage.scanComplete -and -not $gate.scanComplete)
        Assert-True -CaseName "r ${Mode}: código de falha estruturado" -Condition (@($gate.scanIssues | Where-Object { $_.code -eq $ExpectedIssue }).Count -eq 1) -Detail ("issues={0}" -f (@($gate.scanIssues | ForEach-Object { $_.code }) -join ', '))
        if ($Mode -eq 'valid-json-stderr') {
            Assert-True -CaseName 'r valid-json-stderr: exit zero mantem status do gate em warn' -Condition ($gate.invocationExitCode -eq 0 -and $gate.status -eq 'warn')
            Assert-True -CaseName 'r valid-json-stderr: stderr preservado no diagnóstico estruturado' -Condition (@($gate.scanIssues | Where-Object { $_.code -eq 'GATE_STDERR_NONEMPTY' -and $_.message -eq 'synthetic advisory stderr' }).Count -eq 1)
        }
        if ($Mode -eq 'null-candidate-count') {
            Assert-True -CaseName 'r null-candidate-count: triagem não é classificada como órfã' -Condition (@($mechanical.enumerationTriage.orphanedEntries).Count -eq 0)
        }
        if ($Mode -eq 'null-file-state' -or $Mode -eq 'null-finding' -or $Mode -like 'root-*' -or $Mode -like 'issue-*') {
            Assert-True -CaseName "r ${Mode}: diagnóstico permanece consultivo" -Condition ($gate.invocationExitCode -eq 0 -and $gate.status -eq 'warn')
            Assert-True -CaseName "r ${Mode}: triagem incompleta não declara entrada órfã" -Condition (@($mechanical.enumerationTriage.orphanedEntries).Count -eq 0)
        }
        if ($Mode -eq 'issue-valid') {
            Assert-True -CaseName 'r issue-valid: diagnóstico válido preservado no JSON' -Condition (@($gate.scanIssues).Count -eq 1 -and $gate.scanIssues[0].path -eq 'README.md' -and $gate.scanIssues[0].message -eq 'synthetic issue')
        }
        if ($CheckTextOutput) {
            $mechanicalPath = Join-Path $caseRoot 'scripts/Invoke-PrePushMechanicalChecks.ps1'
            $textOutput = & pwsh -NoProfile -File $mechanicalPath -RootPath $caseRoot 2>&1 | Out-String
            $textExitCode = $LASTEXITCODE
            Assert-True -CaseName "r ${Mode}: projeção textual termina com exit zero" -Condition ($textExitCode -eq 0) -Detail $textOutput
            Assert-True -CaseName "r ${Mode}: diagnóstico estruturado visível no texto" -Condition ($textOutput.Contains("SCAN_ISSUE: $ExpectedIssue ["))
            Assert-True -CaseName "r ${Mode}: texto mantém varredura incompleta sem órfãos" -Condition ($textOutput -match 'SCAN_COMPLETE=false' -and $textOutput -match 'orphaned=0')
        }
        if ($Mode -eq 'complete-with-scan-issues' -or $Mode -eq 'complete-with-incomplete-file') {
            Assert-True -CaseName "r ${Mode}: diagnóstico torna o gate consultivo incompleto" -Condition ($gate.status -eq 'warn' -and @($gate.scanIssues | Where-Object { $_.code -eq 'GATE_CONTRACT_INVALID' }).Count -eq 1)
            Assert-True -CaseName "r ${Mode}: contradição não declara triagem órfã" -Condition (@($mechanical.enumerationTriage.orphanedEntries).Count -eq 0)
        }
    }
    finally { Remove-TempDir -Path $caseRoot }
}

Invoke-EnumerationGateFailureCase -Mode 'missing' -ExpectedIssue 'GATE_SCRIPT_MISSING'
Invoke-EnumerationGateFailureCase -Mode 'throw' -ExpectedIssue 'GATE_NONZERO_EXIT'
Invoke-EnumerationGateFailureCase -Mode 'nonzero-json' -ExpectedIssue 'GATE_NONZERO_EXIT'
Invoke-EnumerationGateFailureCase -Mode 'valid-json-stderr' -ExpectedIssue 'GATE_STDERR_NONEMPTY'
Invoke-EnumerationGateFailureCase -Mode 'null-candidate-count' -ExpectedIssue 'GATE_CONTRACT_INVALID'
Invoke-EnumerationGateFailureCase -Mode 'null-file-state' -ExpectedIssue 'GATE_CONTRACT_INVALID'
Invoke-EnumerationGateFailureCase -Mode 'null-finding' -ExpectedIssue 'GATE_CONTRACT_INVALID'
Invoke-EnumerationGateFailureCase -Mode 'complete-with-scan-issues' -ExpectedIssue 'GATE_CONTRACT_INVALID'
Invoke-EnumerationGateFailureCase -Mode 'complete-with-incomplete-file' -ExpectedIssue 'GATE_CONTRACT_INVALID'
Invoke-EnumerationGateFailureCase -Mode 'invalid-json' -ExpectedIssue 'GATE_INVALID_JSON'

$validGateRoot = '{"status":"pass","scanComplete":true,"scanIssues":[],"canonicalMembers":[],"files":[],"candidateCount":0,"displayTruncated":false,"findings":[]}'
$invalidGateRoots = [ordered]@{
    'null' = 'null'
    'null-array' = '[null]'
    'empty-array' = '[]'
    'object-array' = ('[' + $validGateRoot + ']')
    'scalar' = '42'
}
foreach ($rootKind in $invalidGateRoots.Keys) {
    Invoke-EnumerationGateFailureCase -Mode "root-$rootKind" -ExpectedIssue 'GATE_CONTRACT_INVALID' -RootJson $invalidGateRoots[$rootKind]
}

$scanIssueCases = [ordered]@{
    'null' = '[null]'
    'null-complete' = '[null]'
    'empty-object' = '[{}]'
    'scalar' = '[42]'
    'missing-path' = '[{"code":"TEST_SCAN_ISSUE","message":"synthetic issue"}]'
    'missing-message' = '[{"code":"TEST_SCAN_ISSUE","path":"README.md"}]'
    'code-type' = '[{"code":42,"path":"README.md","message":"synthetic issue"}]'
    'path-type' = '[{"code":"TEST_SCAN_ISSUE","path":null,"message":"synthetic issue"}]'
    'message-type' = '[{"code":"TEST_SCAN_ISSUE","path":"README.md","message":[]}]'
    'valid' = '[{"code":"TEST_SCAN_ISSUE","path":"README.md","message":"synthetic issue"}]'
}
foreach ($issueCase in $scanIssueCases.Keys) {
    $completeJson = 'false'
    if ($issueCase -eq 'null-complete') { $completeJson = 'true' }
    $issuePayload = '{"status":"warn","scanComplete":' + $completeJson + ',"scanIssues":' + $scanIssueCases[$issueCase] + ',"canonicalMembers":[],"files":[],"candidateCount":0,"displayTruncated":false,"findings":[]}'
    $expectedIssue = 'GATE_CONTRACT_INVALID'
    if ($issueCase -eq 'valid') { $expectedIssue = 'TEST_SCAN_ISSUE' }
    $checkText = $issueCase -in @('null', 'null-complete', 'empty-object', 'valid')
    Invoke-EnumerationGateFailureCase -Mode "issue-$issueCase" -ExpectedIssue $expectedIssue -RootJson $issuePayload -CheckTextOutput:$checkText
}

Write-Output '---'
if ($failures -eq 0) {
    Write-Output ("SELFTEST_OK: {0}/{0} asserts passaram" -f $cases)
    Write-Output 'BUILD_PREPUSH_REVIEW_DOSSIER_SELFTEST_OK'
    exit 0
} else {
    Write-Output ("SELFTEST_FAIL: {0} de {1} asserts falharam" -f $failures, $cases)
    exit 1
}
