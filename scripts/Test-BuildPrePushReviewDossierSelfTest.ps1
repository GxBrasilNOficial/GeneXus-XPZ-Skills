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

Write-Output '---'
if ($failures -eq 0) {
    Write-Output ("SELFTEST_OK: {0}/{0} asserts passaram" -f $cases)
    Write-Output 'BUILD_PREPUSH_REVIEW_DOSSIER_SELFTEST_OK'
    exit 0
} else {
    Write-Output ("SELFTEST_FAIL: {0} de {1} asserts falharam" -f $failures, $cases)
    exit 1
}
