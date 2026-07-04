#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do guard/least-privilege do agente opencode `reviewer-ro` (skill xpz-llm-delegate).
.DESCRIPTION
    GATE DE PROCESSO/CI dos claims empiricos do design congelado
    (opencode-reviewer-ro-least-privilege-design.md). Deterministico: um fake-exe REAL (.cmd ->
    leitor pwsh) injetado via -Exe simula `opencode --version` e `opencode agent list` (a partir de
    fixtures versionados), sem rodar modelo nem rede — espelha o padrao fake-exe dos demais
    Test-OpenCode*SelfTest.ps1.

    Cobre (do design):
      (b) fail-closed com MOTIVO distinguido: estatico (frontmatter divergente) / versao nao-testada
          / agent list falho (SQLite transitorio) / allow-set divergente;
      (c) allow-set resolvido EXATAMENTE {read,grep,glob,list} — trava por AUSENCIA e por EXCESSO
          (ex.: bash reaparecendo);
      (d) external_directory padrao '*' resolvendo 'allow' => BLOCK (confinamento de leitura ao cwd);
      (e) pos-check le/varre o warning de fallback silencioso;
      (f) regressao: reviewer-ro NAO habilita edit/webfetch (deny na resolucao);
      (g) instalador global preserva comentarios/formatacao/demais chaves do opencode.jsonc
          (migracao tools:->permission; insercao; arquivo novo).

    Os casos (a) default `-Agent reviewer-ro` no argv (sincrono E assincrono) e o BLOCK do adapter
    ANTES do Start-Process sao exercidos pelo self-test do adapter apos D1+D2 (esta suite valida a
    camada guard/instalador — a barreira de resolucao — de forma isolada e CI-safe).

    Sentinela de sucesso: OPENCODE_REVIEWER_RO_SELFTEST_OK
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
$guard = Join-Path $scriptsDir 'OpenCodeReviewerRoGuard.ps1'
$installer = Join-Path $scriptsDir 'Install-OpenCodeReviewerRoAgent.ps1'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptsDir '..')).Path
$fixtureDir = Join-Path $repoRoot 'xpz-llm-delegate\fixtures\opencode-reviewer-ro'
$sampleAgentList = Join-Path $fixtureDir 'agentlist-reviewer-ro.sample.txt'
$fallbackFixture = Join-Path $fixtureDir 'fallback-warning.txt'
$agentMd = Join-Path $repoRoot '.opencode\agent\reviewer-ro.md'

foreach ($p in @($guard, $installer, $sampleAgentList, $fallbackFixture, $agentMd)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "BLOCK: artefato ausente: $p" }
}

. $guard

$testedVersion = Get-OpenCodeReviewerRoTestedVersion
if ([string]::IsNullOrWhiteSpace($testedVersion)) { throw 'BLOCK: VERSION.txt dos fixtures ausente/vazio.' }

$fail = 0
function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) { Write-Host "PASS  $Message" -ForegroundColor Green }
    else { $script:fail++; Write-Host "FAIL  $Message" -ForegroundColor Red }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-oc-rro-selftest-' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null

# variaveis de ambiente do fake-exe (limpas no finally)
$fakeEnv = @('FAKE_OC_VERSION', 'FAKE_OC_AGENTLIST', 'FAKE_OC_AGENTLIST_EXIT', 'FAKE_OC_RUN_STREAM', 'FAKE_OC_RUN_STDERR', 'FAKE_OC_ARGV_FILE')

try {
    # ── fake-exe: leitor pwsh + wrapper .cmd ───────────────────────────────────
    $fakeReader = Join-Path $tempRoot 'fake-reader.ps1'
    @'
$a = @($args)
if ($a.Count -ge 1 -and $a[0] -eq '--version') { Write-Output $env:FAKE_OC_VERSION; exit 0 }
if ($a.Count -ge 2 -and $a[0] -eq 'agent' -and $a[1] -eq 'list') {
    if ($env:FAKE_OC_AGENTLIST_EXIT -and [int]$env:FAKE_OC_AGENTLIST_EXIT -ne 0) { exit ([int]$env:FAKE_OC_AGENTLIST_EXIT) }
    Get-Content -LiteralPath $env:FAKE_OC_AGENTLIST -Encoding utf8
    exit 0
}
if ($a.Count -ge 1 -and $a[0] -eq 'run') {
    if ($env:FAKE_OC_ARGV_FILE) { Set-Content -LiteralPath $env:FAKE_OC_ARGV_FILE -Value ($a -join ' ') -Encoding utf8 -NoNewline }
    [void][Console]::In.ReadToEnd()
    if ($env:FAKE_OC_RUN_STDERR) { [Console]::Error.WriteLine($env:FAKE_OC_RUN_STDERR) }
    if ($env:FAKE_OC_RUN_STREAM) { Get-Content -LiteralPath $env:FAKE_OC_RUN_STREAM -Encoding utf8 }
    exit 0
}
exit 0
'@ | Set-Content -LiteralPath $fakeReader -Encoding utf8

    $fakeCmd = Join-Path $tempRoot 'fake-opencode.cmd'
    @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-reader.ps1" %*
exit /b %errorlevel%
'@ | Set-Content -LiteralPath $fakeCmd -Encoding ascii

    # variantes de agent list geradas PROGRAMATICAMENTE (parse do sample -> muta o array ->
    # re-serializa como bloco `reviewer-ro (all)` + JSON). Robusto (sem regex sobre texto).
    $sampleRules = @(Get-OpenCodeReviewerRoBlockFromAgentList -Lines @(Get-Content -LiteralPath $sampleAgentList -Encoding utf8) -Name 'reviewer-ro')
    if ($sampleRules.Count -eq 0) { throw 'BLOCK: fixture-sample nao parseou no self-test.' }
    function Write-AgentListVariant {
        param([Parameter(Mandatory)] $Rules, [Parameter(Mandatory)] [string] $Path)
        $json = ($Rules | ConvertTo-Json -Depth 6)
        # ConvertTo-Json de 1 elemento nao vira array; forcar colchetes
        if (@($Rules).Count -eq 1) { $json = "[`n$json`n]" }
        Set-Content -LiteralPath $Path -Value ("reviewer-ro (all)`n" + $json) -Encoding utf8
    }
    # excesso: bash:allow ao final (regra tardia)
    $excessPath = Join-Path $tempRoot 'agentlist-excess.txt'
    Write-AgentListVariant -Rules ($sampleRules + [pscustomobject]@{ permission = 'bash'; action = 'allow'; pattern = '*' }) -Path $excessPath
    # ausencia: renomeia todos os 'read' -> nome inerte (read some do allow-set)
    $absenceRules = foreach ($r in $sampleRules) {
        if ($r.permission -eq 'read') { [pscustomobject]@{ permission = 'zzz_inerte'; action = $r.action; pattern = $r.pattern } }
        else { $r }
    }
    $absencePath = Join-Path $tempRoot 'agentlist-absence.txt'
    Write-AgentListVariant -Rules $absenceRules -Path $absencePath
    # external_directory '*' -> allow (confinamento quebrado)
    $extAllowRules = foreach ($r in $sampleRules) {
        if ($r.permission -eq 'external_directory' -and $r.action -eq 'deny') { [pscustomobject]@{ permission = 'external_directory'; action = 'allow'; pattern = $r.pattern } }
        else { $r }
    }
    $extAllowPath = Join-Path $tempRoot 'agentlist-extallow.txt'
    Write-AgentListVariant -Rules $extAllowRules -Path $extAllowPath

    $env:FAKE_OC_ARGV_FILE = ''

    # ── (c)+(f) allow-set EXATO {read,grep,glob,list}; edit/webfetch NAO no allow-set ──
    $env:FAKE_OC_VERSION = $testedVersion
    $env:FAKE_OC_AGENTLIST = $sampleAgentList
    $env:FAKE_OC_AGENTLIST_EXIT = ''
    $pc = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot
    Assert-True ($pc.pass) "(c) allow-set exato {read,grep,glob,list} + versao ok => pre-check PASSA (detail: $($pc.detail))"
    $al = Get-OpenCodeReviewerRoAllowSetFromExe -Exe $fakeCmd
    Assert-True ($al.ok -and (@($al.allowSet | Sort-Object) -join ',') -eq 'glob,grep,list,read') "(c) allowSet resolvido = {glob,grep,list,read}"
    Assert-True (@($al.allowSet) -notcontains 'edit' -and @($al.allowSet) -notcontains 'webfetch') "(f) regressao: edit/webfetch fora do allow-set"

    # ── (c-excesso) bash reaparece como allow => BLOCK allowset ──
    $env:FAKE_OC_AGENTLIST = $excessPath
    $pcx = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot
    Assert-True ((-not $pcx.pass) -and $pcx.reason -eq 'allowset') "(c) EXCESSO (bash:allow) => BLOCK reason=allowset (got: $($pcx.reason))"

    # ── (c-ausencia) read some do allow-set => BLOCK allowset ──
    $env:FAKE_OC_AGENTLIST = $absencePath
    $pca = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot
    Assert-True ((-not $pca.pass) -and $pca.reason -eq 'allowset') "(c) AUSENCIA (read fora) => BLOCK reason=allowset (got: $($pca.reason))"

    # ── (d) external_directory '*' => allow => BLOCK allowset (confinamento quebrado) ──
    $env:FAKE_OC_AGENTLIST = $extAllowPath
    $pce = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot
    Assert-True ((-not $pce.pass) -and $pce.reason -eq 'allowset' -and $pce.detail -match 'external_directory') "(d) external_directory[*]=allow => BLOCK (nao confinado)"

    # ── (b-versao) versao instalada != testada => BLOCK version ──
    $env:FAKE_OC_AGENTLIST = $sampleAgentList
    $env:FAKE_OC_VERSION = '9.9.9-nao-testada'
    $pcv = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot
    Assert-True ((-not $pcv.pass) -and $pcv.reason -eq 'version') "(b) versao nao-testada => BLOCK reason=version (got: $($pcv.reason))"
    $env:FAKE_OC_VERSION = $testedVersion

    # ── (b-agentlist) agent list falha (exit!=0 transitorio SQLite) => BLOCK agentlist ──
    $env:FAKE_OC_AGENTLIST_EXIT = '1'
    $pcg = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot
    Assert-True ((-not $pcg.pass) -and $pcg.reason -eq 'agentlist') "(b) agent list exit!=0 => BLOCK reason=agentlist (transitorio) (got: $($pcg.reason))"
    $env:FAKE_OC_AGENTLIST_EXIT = ''

    # ── (b-static) frontmatter divergente => BLOCK static (antes de tocar o exe) ──
    $badWd = Join-Path $tempRoot 'bad-wd'
    New-Item -ItemType Directory -Path (Join-Path $badWd '.opencode\agent') -Force | Out-Null
    @'
---
mode: all
permission:
  "*": allow
  read: allow
  bash: allow
---
agente ruim (nao default-deny)
'@ | Set-Content -LiteralPath (Join-Path $badWd '.opencode\agent\reviewer-ro.md') -Encoding utf8
    $pcs = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $badWd
    Assert-True ((-not $pcs.pass) -and $pcs.reason -eq 'static') "(b) frontmatter divergente => BLOCK reason=static (got: $($pcs.reason))"

    # ── (e) pos-check: warning de fallback detectado; texto limpo nao ──
    $fbText = Get-Content -LiteralPath $fallbackFixture -Raw -Encoding utf8
    Assert-True (Test-OpenCodeReviewerRoFallbackWarning -Text $fbText) "(e) pos-check detecta warning de fallback do fixture"
    Assert-True (-not (Test-OpenCodeReviewerRoFallbackWarning -Text "stderr limpo sem warning")) "(e) pos-check nao dispara em stderr limpo"

    # ── (g) instalador preserva comentarios/formatacao/demais chaves ──
    # (g1) migracao tools:->permission
    $g1 = Join-Path $tempRoot 'g1.jsonc'
    @'
{
  // topo preservar
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["x"],
  "agent": {
    "reviewer-ro": {
      "description": "interino",
      "mode": "primary",
      "tools": { "write": false, "edit": false, "bash": false, "patch": false }
    }
  } /* fim */
}
'@ | Set-Content -LiteralPath $g1 -Encoding utf8
    & $installer -JsoncPath $g1 -AgentMarkdownPath $agentMd | Out-Null
    $g1raw = Get-Content -LiteralPath $g1 -Raw -Encoding utf8
    $g1parsed = ConvertFrom-Jsonc -Raw $g1raw
    Assert-True (($g1raw -match '// topo preservar') -and ($g1raw -match '/\* fim \*/') -and ($g1raw -match '"instructions"')) "(g1) migracao preserva comentarios + demais chaves"
    Assert-True ([string]$g1parsed.agent.'reviewer-ro'.permission.'*' -eq 'deny' -and $null -eq $g1parsed.agent.'reviewer-ro'.PSObject.Properties['tools']) "(g1) tools: removido; permission '*'=deny"

    # (g2) insercao em agent existente sem reviewer-ro
    $g2 = Join-Path $tempRoot 'g2.jsonc'
    @'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    // outro agente
    "helper": { "mode": "all" }
  }
}
'@ | Set-Content -LiteralPath $g2 -Encoding utf8
    & $installer -JsoncPath $g2 -AgentMarkdownPath $agentMd | Out-Null
    $g2raw = Get-Content -LiteralPath $g2 -Raw -Encoding utf8
    $g2parsed = ConvertFrom-Jsonc -Raw $g2raw
    Assert-True (($g2raw -match '// outro agente') -and ($null -ne $g2parsed.agent.PSObject.Properties['helper'])) "(g2) insercao preserva agente helper + comentario"
    Assert-True ([string]$g2parsed.agent.'reviewer-ro'.permission.'*' -eq 'deny') "(g2) reviewer-ro inserido com '*'=deny"

    # (g3) arquivo novo (inexistente)
    $g3 = Join-Path $tempRoot 'g3-novo.jsonc'
    & $installer -JsoncPath $g3 -AgentMarkdownPath $agentMd | Out-Null
    Assert-True (Test-Path -LiteralPath $g3) "(g3) arquivo novo criado"
    $g3parsed = ConvertFrom-Jsonc -Raw (Get-Content -LiteralPath $g3 -Raw -Encoding utf8)
    Assert-True ([string]$g3parsed.agent.'reviewer-ro'.permission.'read' -eq 'allow') "(g3) arquivo novo com reviewer-ro valido"
}
finally {
    foreach ($e in $fakeEnv) { Remove-Item "Env:$e" -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-OpenCodeReviewerRoSelfTest.ps1" }
Write-Host 'OPENCODE_REVIEWER_RO_SELFTEST_OK' -ForegroundColor Cyan
