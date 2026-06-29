#requires -Version 7.4
<#
.SYNOPSIS
Self-test do Passo B3 (identidade do daemon PreToolUse auto-allow do Claude Code):
scripts/ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1. Sentinela de sucesso: "OK:" na ultima linha.

.DESCRIPTION
Valida a LOGICA de identidade (ascensao/marcador/orfao, dedup/ordenacao de roots, hashing, nomes)
SEM depender de artefato em disco: carrega [Ptu.Canon] do FONTE (ptu-native/PtuCanon.cs) via
Add-Type -TypeDefinition (Roslyn em sessao). A paridade byte-a-byte EXE-AOT vs DLL e o carregamento
real por Add-Type -Path sao o gate do spike B4 -- nao deste self-test.

Cobre:
  A) ascensao do marcador: cliente profundo e daemon em scripts\ -> MESMA raiz canonica.
  B) marcador orfao em ancestral (>=2) -> identidade invalida ($null).
  C) ausencia de marcador -> $null.
  D) homonimo DIRETORIO (nao arquivo) nao conta como marcador -> $null.
  E) hashing puro: determinismo + sensibilidade a cada um dos 3 componentes + formato 64-hex.
  F) rootsCanonical: dedup, independente de ordem, minusculo; root vazio/inexistente -> $null.
  G) nomes derivados do hash: distintos, contem o hash, hash invalido -> $null.
  H) Get-PtuIdentity fim-a-fim (roots injetados): objeto valido; arvore orfa/bad-roots -> $null.
  I) Import-PtuCanon = $true quando o tipo ja esta carregado (independe do DllPath).
Tudo em diretorio temporario, limpo no fim. Nao toca arquivos versionados do repo.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$idScript = Join-Path $PSScriptRoot 'ClaudeCodePreToolUseSafeAllowDaemonIdentity.ps1'
if (-not (Test-Path -LiteralPath $idScript)) { throw "identidade ausente: $idScript" }
. $idScript

# Carrega [Ptu.Canon] do fonte (sem build) para exercitar a logica de identidade.
if (-not ('Ptu.Canon' -as [type])) {
    $csPath = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\ptu-native\PtuCanon.cs')
    $csText = [System.IO.File]::ReadAllText($csPath)
    Add-Type -TypeDefinition $csText -Language CSharp
}
if (-not ('Ptu.Canon' -as [type])) { throw "nao foi possivel carregar [Ptu.Canon] do fonte" }

$failures = [System.Collections.Generic.List[string]]::new()
function Assert-True {
    param([bool] $Cond, [string] $Msg)
    if (-not $Cond) { $script:failures.Add($Msg) }
}

function New-MarkerFile {
    param([string] $Dir)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $Dir '.ptu-safe-allow-root'), '')
}

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("ptu-identity-selftest-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root -Force | Out-Null

try {
    # ---------- A) ascensao do marcador (paridade cliente profundo x daemon em scripts\) ----------
    $repoA   = Join-Path $root 'A\repo'
    $scripts = Join-Path $repoA 'scripts'
    $deep    = Join-Path $repoA 'a\b\c\deep'
    New-MarkerFile -Dir $repoA
    New-Item -ItemType Directory -Path $scripts -Force | Out-Null
    New-Item -ItemType Directory -Path $deep -Force | Out-Null

    $mFromScripts = Resolve-PtuRepoMarkerDir -StartDirectory $scripts
    $mFromDeep    = Resolve-PtuRepoMarkerDir -StartDirectory $deep
    Assert-True ($null -ne $mFromScripts) "A: marcador nao encontrado a partir de scripts\"
    Assert-True ($mFromScripts -ceq $mFromDeep) "A: raiz divergente entre scripts\ e subpasta profunda"

    $repoCanonScripts = Get-PtuCanonicalRepoRoot -StartDirectory $scripts
    $repoCanonDeep    = Get-PtuCanonicalRepoRoot -StartDirectory $deep
    Assert-True ($null -ne $repoCanonScripts) "A: repoCanonical nulo a partir de scripts\"
    Assert-True ($repoCanonScripts -ceq $repoCanonDeep) "A: repoCanonical divergente cliente x daemon"
    Assert-True ($repoCanonScripts -ceq $repoCanonScripts.ToLowerInvariant()) "A: repoCanonical nao esta minusculo"

    # ---------- B) marcador orfao em ancestral (>=2 -> invalido) ----------
    $outerB = Join-Path $root 'B\outer'
    $repoB  = Join-Path $outerB 'repo'
    $scrB   = Join-Path $repoB 'scripts'
    New-MarkerFile -Dir $outerB   # orfao
    New-MarkerFile -Dir $repoB    # verdadeiro
    New-Item -ItemType Directory -Path $scrB -Force | Out-Null
    Assert-True ($null -eq (Resolve-PtuRepoMarkerDir -StartDirectory $scrB)) "B: marcador orfao (>=2) NAO invalidou"

    # ---------- C) ausencia de marcador ----------
    $noMark = Join-Path $root 'C\x\y\z'
    New-Item -ItemType Directory -Path $noMark -Force | Out-Null
    Assert-True ($null -eq (Resolve-PtuRepoMarkerDir -StartDirectory $noMark)) "C: ausencia de marcador NAO deu invalido"

    # ---------- D) homonimo DIRETORIO nao conta ----------
    $repoD = Join-Path $root 'D\repo'
    $scrD  = Join-Path $repoD 'scripts'
    New-Item -ItemType Directory -Path (Join-Path $repoD '.ptu-safe-allow-root') -Force | Out-Null  # dir, nao file
    New-Item -ItemType Directory -Path $scrD -Force | Out-Null
    Assert-True ($null -eq (Resolve-PtuRepoMarkerDir -StartDirectory $scrD)) "D: diretorio homonimo contou como marcador"

    # ---------- E) hashing puro ----------
    $h1 = Get-PtuIdentityHashFromParts -Sid 'S-1-5-21-1' -RepoCanonical 'c:\repo' -RootsCanonical 'c:\dev'
    $h2 = Get-PtuIdentityHashFromParts -Sid 'S-1-5-21-1' -RepoCanonical 'c:\repo' -RootsCanonical 'c:\dev'
    Assert-True ($h1 -match '^[0-9a-f]{64}$') "E: hash nao e 64-hex minusculo: '$h1'"
    Assert-True ($h1 -ceq $h2) "E: hashing nao-deterministico"
    Assert-True ((Get-PtuIdentityHashFromParts -Sid 'S-1-5-21-2' -RepoCanonical 'c:\repo' -RootsCanonical 'c:\dev') -cne $h1) "E: mudar SID NAO mudou o hash"
    Assert-True ((Get-PtuIdentityHashFromParts -Sid 'S-1-5-21-1' -RepoCanonical 'c:\repo2' -RootsCanonical 'c:\dev') -cne $h1) "E: mudar repoCanonical NAO mudou o hash"
    Assert-True ((Get-PtuIdentityHashFromParts -Sid 'S-1-5-21-1' -RepoCanonical 'c:\repo' -RootsCanonical 'c:\dev2') -cne $h1) "E: mudar rootsCanonical NAO mudou o hash"
    # separador NUL: ("a","b","cd") vs ("a","bc","d") concatenam para "abcd" sem separador -> com NUL diferem
    Assert-True ((Get-PtuIdentityHashFromParts -Sid 'a' -RepoCanonical 'b' -RootsCanonical 'cd') -cne (Get-PtuIdentityHashFromParts -Sid 'a' -RepoCanonical 'bc' -RootsCanonical 'd')) "E: colisao por concatenacao sem separador"

    # ---------- F) rootsCanonical (dedup, ordem, minusculo, fail-closed) ----------
    $r1 = Join-Path $root 'F\r1'
    $r2 = Join-Path $root 'F\r2'
    New-Item -ItemType Directory -Path $r1 -Force | Out-Null
    New-Item -ItemType Directory -Path $r2 -Force | Out-Null
    $rc12 = ConvertTo-PtuRootsCanonical -Roots @($r1, $r2, $r1)   # com duplicata
    $rc21 = ConvertTo-PtuRootsCanonical -Roots @($r2, $r1)        # ordem trocada
    Assert-True ($null -ne $rc12) "F: rootsCanonical nulo p/ roots validos"
    Assert-True ($rc12 -ceq $rc21) "F: rootsCanonical depende da ordem de entrada (deveria ordenar)"
    Assert-True (@($rc12 -split ';').Count -eq 2) "F: duplicata nao foi removida"
    Assert-True ($rc12 -ceq $rc12.ToLowerInvariant()) "F: rootsCanonical nao esta minusculo"
    Assert-True ($null -eq (ConvertTo-PtuRootsCanonical -Roots @($r1, '   '))) "F: root em branco NAO invalidou"
    Assert-True ($null -eq (ConvertTo-PtuRootsCanonical -Roots @($r1, (Join-Path $root 'F\inexistente')))) "F: root inexistente NAO invalidou"
    Assert-True ($null -eq (ConvertTo-PtuRootsCanonical -Roots @())) "F: lista vazia de roots NAO deu invalido"

    # ---------- G) nomes derivados do hash ----------
    $fakeHash = ('a' * 64)
    $names = Get-PtuIdentityNames -IdentityHash $fakeHash
    Assert-True ($null -ne $names) "G: nomes nulos p/ hash valido"
    Assert-True ($names.PipePath -ceq "\\.\pipe\ptu-safe-allow-$fakeHash") "G: PipePath fora do formato esperado"
    Assert-True ($names.PipeName.Contains($fakeHash)) "G: PipeName nao contem o hash"
    Assert-True ($names.SingletonMutexName.Contains($fakeHash)) "G: SingletonMutexName nao contem o hash"
    Assert-True ($names.GuardMutexName.Contains($fakeHash)) "G: GuardMutexName nao contem o hash"
    Assert-True ($names.DaemonLogPath.Contains($fakeHash)) "G: DaemonLogPath nao contem o hash"
    Assert-True ($names.ClientLogPath.Contains($fakeHash)) "G: ClientLogPath nao contem o hash"
    $distinct = @($names.PipeName, $names.SingletonMutexName, $names.GuardMutexName, $names.DaemonLogPath, $names.ClientLogPath) | Sort-Object -Unique
    Assert-True ($distinct.Count -eq 5) "G: nomes de coordenacao nao sao todos distintos"
    Assert-True ($null -eq (Get-PtuIdentityNames -IdentityHash 'NAO-HEX')) "G: hash invalido NAO retornou nulo"
    Assert-True ($null -eq (Get-PtuIdentityNames -IdentityHash ('A' * 64))) "G: hash em MAIUSCULO NAO retornou nulo"

    # ---------- H) Get-PtuIdentity fim-a-fim (roots injetados; tipo ja carregado) ----------
    $idOk = Get-PtuIdentity -StartDirectory $scripts -DllPath 'DUMMY-tipo-ja-carregado' -Roots @($r1, $r2)
    Assert-True ($null -ne $idOk) "H: identidade nula p/ arvore valida"
    if ($null -ne $idOk) {
        Assert-True ($idOk.IdentityHash -match '^[0-9a-f]{64}$') "H: IdentityHash fora de 64-hex"
        Assert-True ($idOk.RepoCanonical -ceq $repoCanonScripts) "H: RepoCanonical divergente do esperado"
        Assert-True ($idOk.RootsCanonical -ceq (ConvertTo-PtuRootsCanonical -Roots @($r1, $r2))) "H: RootsCanonical divergente"
        Assert-True ($idOk.Names.IdentityHash -ceq $idOk.IdentityHash) "H: Names.IdentityHash != IdentityHash"
        $expectHash = Get-PtuIdentityHashFromParts -Sid $idOk.Sid -RepoCanonical $idOk.RepoCanonical -RootsCanonical $idOk.RootsCanonical
        Assert-True ($idOk.IdentityHash -ceq $expectHash) "H: IdentityHash != SHA256 das partes"
    }
    Assert-True ($null -eq (Get-PtuIdentity -StartDirectory $scrB -DllPath 'DUMMY' -Roots @($r1))) "H: arvore com marcador orfao NAO deu identidade nula"
    Assert-True ($null -eq (Get-PtuIdentity -StartDirectory $scripts -DllPath 'DUMMY' -Roots @((Join-Path $root 'inexistente')))) "H: root inexistente NAO deu identidade nula"

    # ---------- I) Import-PtuCanon com tipo ja carregado ----------
    Assert-True (Import-PtuCanon -DllPath 'CAMINHO-INEXISTENTE.dll') "I: Import-PtuCanon nao retornou true com [Ptu.Canon] ja carregado"
}
finally {
    if ([string]::IsNullOrEmpty($env:PTU_SELFTEST_KEEP)) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Warning "PTU_SELFTEST_KEEP setado; fixture preservado em: $root"
    }
}

if ($failures.Count -gt 0) {
    foreach ($f in $failures) { Write-Error $f -ErrorAction Continue }
    throw "FALHA: Test-ClaudeCodePreToolUseSafeAllowDaemonIdentitySelfTest ($($failures.Count) assercao(es))"
}
Write-Output "OK: Test-ClaudeCodePreToolUseSafeAllowDaemonIdentitySelfTest.ps1"
