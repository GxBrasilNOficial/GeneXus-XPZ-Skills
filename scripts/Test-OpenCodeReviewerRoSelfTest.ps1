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

    (a) default `-Agent reviewer-ro` no argv (sincrono E assincrono), o BLOCK do adapter ANTES do
    run/Start-Process, o opt-out (`-Agent <x>`) e o pos-check sincrono end-to-end tambem sao
    exercidos NESTA suite (secao «INTEGRACAO com os adapters»), via fake-exe injetado por
    `-OpenCodeExe`. A suite cobre tanto a camada guard/instalador quanto a integracao com os adapters.

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
$equivFixture = Join-Path $fixtureDir 'equiv-permission-vs-tools.sample.txt'
$mergeFixture = Join-Path $fixtureDir 'merge-global-only-reviewer-ro.sample.txt'
$readOutsideFixture = Join-Path $fixtureDir 'read-outside-cwd-blocked.sample.txt'
$agentMd = Join-Path $repoRoot '.opencode\agent\reviewer-ro.md'

foreach ($p in @($guard, $installer, $sampleAgentList, $fallbackFixture, $equivFixture, $mergeFixture, $readOutsideFixture, $agentMd)) {
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
$fakeEnv = @('FAKE_OC_VERSION', 'FAKE_OC_AGENTLIST', 'FAKE_OC_AGENTLIST_EXIT', 'FAKE_OC_RUN_STREAM', 'FAKE_OC_RUN_STDERR', 'FAKE_OC_ARGV_FILE', 'FAKE_OC_AGENTLIST_FAIL_UNTIL', 'FAKE_OC_AGENTLIST_FAILCOUNTER')

try {
    # ── fake-exe: leitor pwsh + wrapper .cmd ───────────────────────────────────
    $fakeReader = Join-Path $tempRoot 'fake-reader.ps1'
    @'
$a = @($args)
if ($a.Count -ge 1 -and $a[0] -eq '--version') { Write-Output $env:FAKE_OC_VERSION; exit 0 }
if ($a.Count -ge 2 -and $a[0] -eq 'agent' -and $a[1] -eq 'list') {
    # falha transitoria simulada: exit 1 nas primeiras FAIL_UNTIL tentativas (conta em arquivo)
    if ($env:FAKE_OC_AGENTLIST_FAIL_UNTIL -and $env:FAKE_OC_AGENTLIST_FAILCOUNTER) {
        $n = 0
        if (Test-Path -LiteralPath $env:FAKE_OC_AGENTLIST_FAILCOUNTER) { $n = [int](Get-Content -LiteralPath $env:FAKE_OC_AGENTLIST_FAILCOUNTER -Raw) }
        $n++
        Set-Content -LiteralPath $env:FAKE_OC_AGENTLIST_FAILCOUNTER -Value $n -Encoding ascii -NoNewline
        if ($n -le [int]$env:FAKE_OC_AGENTLIST_FAIL_UNTIL) { exit 1 }
    }
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

    # ── (d-behavioral) fixture golden da captura real "leitura fora do cwd bloqueada" (design D4) ──
    # O self-test deterministico nao re-executa o modelo; aqui so verifica que a captura documenta o
    # desfecho (sem-leak) e nao contem sentinela literal. A asserção mecanica CI e o caso (d) acima.
    $roText = Get-Content -LiteralPath $readOutsideFixture -Raw -Encoding utf8
    Assert-True (($roText -match 'SEM LEAK') -and ($roText -match 'external_directory') -and (-not ($roText -match 'ZQX789'))) "(d-behavioral) fixture documenta leitura-fora-do-cwd bloqueada (sem-leak, sem sentinela literal)"

    # ── (b-versao) versao instalada != testada => BLOCK version ──
    $env:FAKE_OC_AGENTLIST = $sampleAgentList
    $env:FAKE_OC_VERSION = '9.9.9-nao-testada'
    $pcv = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot
    Assert-True ((-not $pcv.pass) -and $pcv.reason -eq 'version') "(b) versao nao-testada => BLOCK reason=version (got: $($pcv.reason))"
    $env:FAKE_OC_VERSION = $testedVersion

    # ── (b-agentlist) agent list falha SEMPRE (exit!=0) => BLOCK agentlist apos retries ──
    $env:FAKE_OC_AGENTLIST_EXIT = '1'
    $pcg = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot -RetryDelayMs 0
    Assert-True ((-not $pcg.pass) -and $pcg.reason -eq 'agentlist') "(b) agent list exit!=0 (sempre) => BLOCK reason=agentlist apos retries (got: $($pcg.reason))"
    $env:FAKE_OC_AGENTLIST_EXIT = ''

    # ── (retry) agent list falha TRANSITORIA (1a tentativa) + sucesso (2a) => PASSA (design :73) ──
    $failCounter = Join-Path $tempRoot 'agentlist-failcounter.txt'
    Set-Content -LiteralPath $failCounter -Value '0' -Encoding ascii -NoNewline
    $env:FAKE_OC_AGENTLIST_FAILCOUNTER = $failCounter
    $env:FAKE_OC_AGENTLIST_FAIL_UNTIL = '1'   # falha so na 1a tentativa, sucesso na 2a
    $pcr = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot -RetryDelayMs 0
    Assert-True ($pcr.pass) "(retry) agent list transitorio (falha 1a, ok 2a) => retry curto RECUPERA => PASSA (detail: $($pcr.detail))"
    Assert-True ([int](Get-Content -LiteralPath $failCounter -Raw) -ge 2) "(retry) o retry re-executou o agent list (contador >= 2)"
    $env:FAKE_OC_AGENTLIST_FAIL_UNTIL = ''
    $env:FAKE_OC_AGENTLIST_FAILCOUNTER = ''

    # ── (b-version-inobtivel) opencode --version vazio => BLOCK version (distinto de divergente) ──
    $env:FAKE_OC_VERSION = ''
    $pcvu = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot -RetryDelayMs 0
    Assert-True ((-not $pcvu.pass) -and $pcvu.reason -eq 'version' -and $pcvu.detail -match 'nao foi possivel obter') "(b) versao inobtivel (--version vazio) => BLOCK reason=version 'nao foi possivel obter' (got: $($pcvu.reason))"
    $env:FAKE_OC_VERSION = $testedVersion

    # ── (b-version-esperada-ausente) VERSION.txt ausente (ExpectedVersion vazio) => BLOCK version ──
    # FAIL-CLOSED: sem versao esperada nao se pode validar a clausula; NUNCA pular o check.
    $pcve = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot -ExpectedVersion '' -RetryDelayMs 0
    Assert-True ((-not $pcve.pass) -and $pcve.reason -eq 'version' -and $pcve.detail -match 'clausula de validade') "(b) versao esperada ausente (VERSION.txt sumiu) => BLOCK reason=version fail-closed (got: $($pcve.reason))"

    # ── (b-ausencia-total) nem project-local nem global => BLOCK static 'ausente' ──
    $emptyWd = Join-Path $tempRoot 'empty-wd'
    New-Item -ItemType Directory -Path $emptyWd -Force | Out-Null
    $stAbs = Test-OpenCodeReviewerRoStatic -WorkingDirectory $emptyWd -GlobalJsoncPath (Join-Path $tempRoot 'nao-existe-global.jsonc')
    Assert-True ((-not $stAbs.ok) -and $stAbs.reason -eq 'static' -and $stAbs.detail -match 'ausente') "(b) definicao completamente ausente => static 'ausente' (got: $($stAbs.reason))"

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

    # ── (b-mode-ausente) frontmatter sem `mode: all` => BLOCK static (mode e obrigatorio) ──
    $noModeWd = Join-Path $tempRoot 'nomode-wd'
    New-Item -ItemType Directory -Path (Join-Path $noModeWd '.opencode\agent') -Force | Out-Null
    @'
---
permission:
  "*": deny
  read: allow
  grep: allow
  glob: allow
  list: allow
  edit: deny
  bash: deny
  webfetch: deny
  websearch: deny
  task: deny
  external_directory: deny
---
sem mode
'@ | Set-Content -LiteralPath (Join-Path $noModeWd '.opencode\agent\reviewer-ro.md') -Encoding utf8
    $pcm = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $noModeWd
    Assert-True ((-not $pcm.pass) -and $pcm.reason -eq 'static' -and $pcm.detail -match 'mode') "(b) mode ausente => BLOCK reason=static (obrigatorio) (got: $($pcm.reason))"

    # ── (b-agente-ausente) agent list VALIDO (exit 0) porem SEM o bloco reviewer-ro => BLOCK ──
    # distinto do SQLite-transitorio: aqui o `agent list` funcionou, mas o agente nao resolve
    # (provisionamento nao carregado); a detail cita "nao encontrado", nao "codigo N".
    $absentPath = Join-Path $tempRoot 'agentlist-agente-ausente.txt'
    Set-Content -LiteralPath $absentPath -Value ("build (primary)`n[`n{`"permission`":`"*`",`"action`":`"allow`",`"pattern`":`"*`"}`n]") -Encoding utf8
    $env:FAKE_OC_AGENTLIST = $absentPath
    $pcaa = Test-OpenCodeReviewerRoPrecheck -Exe $fakeCmd -WorkingDirectory $repoRoot
    Assert-True ((-not $pcaa.pass) -and $pcaa.reason -eq 'agentlist' -and $pcaa.detail -match 'nao encontrado') "(b) agente ausente (agent list valido sem reviewer-ro) => BLOCK reason=agentlist detail 'nao encontrado' (got: $($pcaa.reason))"
    $env:FAKE_OC_AGENTLIST = $sampleAgentList

    # ── (B4) equivalencia permission:deny == tools:false (fixture medido em 1.4.4) ──
    $equivLines = @(Get-Content -LiteralPath $equivFixture -Encoding utf8)
    $permBlock = Resolve-OpenCodeReviewerRoAllowSet -Rules (Get-OpenCodeReviewerRoBlockFromAgentList -Lines $equivLines -Name 'probe-perm')
    $toolsBlock = Resolve-OpenCodeReviewerRoAllowSet -Rules (Get-OpenCodeReviewerRoBlockFromAgentList -Lines $equivLines -Name 'probe-tools')
    Assert-True ([string]$permBlock.effective['webfetch'] -eq 'deny' -and [string]$toolsBlock.effective['webfetch'] -eq 'deny') "(B4) permission:deny E tools:false resolvem webfetch=deny (equivalencia)"

    # ── (B5) merge global<->project = substituicao, nao campo a campo (fixture medido) ──
    $mergeGlobal = Resolve-OpenCodeReviewerRoAllowSet -Rules (Get-OpenCodeReviewerRoBlockFromAgentList -Lines @(Get-Content -LiteralPath $mergeFixture -Encoding utf8) -Name 'reviewer-ro')
    $mergeProject = Resolve-OpenCodeReviewerRoAllowSet -Rules (Get-OpenCodeReviewerRoBlockFromAgentList -Lines @(Get-Content -LiteralPath $sampleAgentList -Encoding utf8) -Name 'reviewer-ro')
    Assert-True (@($mergeGlobal.allowSet) -contains '*') "(B5) so-global (tools:) resolve '*'=allow (allow-set wide)"
    Assert-True (@($mergeProject.allowSet) -notcontains '*' -and (@($mergeProject.allowSet | Sort-Object) -join ',') -eq 'glob,grep,list,read') "(B5) com project-local resolve '*'=deny + allow-set {read,grep,glob,list} => SUBSTITUICAO integral (nao merge campo a campo)"

    # ── (e) pos-check: warning de fallback detectado; texto limpo nao ──
    $fbText = Get-Content -LiteralPath $fallbackFixture -Raw -Encoding utf8
    $pattern1 = Get-OpenCodeReviewerRoFallbackWarningPattern
    $pattern2 = Get-OpenCodeReviewerRoFallbackWarningPattern
    Assert-True (-not [string]::IsNullOrWhiteSpace($pattern1) -and $pattern1 -eq $pattern2) "(e) accessor Get-OpenCodeReviewerRoFallbackWarningPattern retorna padrao estavel nao vazio"
    Assert-True ($fbText -match $pattern1) "(e) fixture real casa com o padrao logico unico do fallback"
    Assert-True (Test-OpenCodeReviewerRoFallbackWarning -Text $fbText) "(e) pos-check detecta warning de fallback do fixture"
    Assert-True (Test-OpenCodeReviewerRoFallbackWarning -Text ("ruido antes`n" + $fbText + "`nruido depois")) "(e) pos-check detecta warning com ruido antes/depois"
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

    # (g4) chave `reviewer-ro` HOMONIMA fora de `agent` (em metadata) + agent sem reviewer-ro:
    # o instalador deve escopar ao bloco agent (inserir agent.reviewer-ro) SEM tocar o homonimo.
    $g4 = Join-Path $tempRoot 'g4-homonimo.jsonc'
    @'
{
  "$schema": "https://opencode.ai/config.json",
  "metadata": { "reviewer-ro": { "note": "homonimo fora de agent — nao tocar" } },
  "agent": {
    "helper": { "mode": "all" }
  }
}
'@ | Set-Content -LiteralPath $g4 -Encoding utf8
    & $installer -JsoncPath $g4 -AgentMarkdownPath $agentMd | Out-Null
    $g4raw = Get-Content -LiteralPath $g4 -Raw -Encoding utf8
    $g4parsed = ConvertFrom-Jsonc -Raw $g4raw
    Assert-True ([string]$g4parsed.agent.'reviewer-ro'.permission.'*' -eq 'deny') "(g4) reviewer-ro inserido DENTRO de agent (nao no homonimo)"
    Assert-True ([string]$g4parsed.metadata.'reviewer-ro'.note -eq 'homonimo fora de agent — nao tocar') "(g4) metadata.reviewer-ro homonimo preservado intacto"
    Assert-True ($null -ne $g4parsed.agent.PSObject.Properties['helper']) "(g4) agent.helper preservado"

    # ── (a)+(b-adapter) INTEGRACAO com os adapters (D1+D2) ──────────────────────
    # Push-Location na raiz do repo: o pre-check descobre o project-local subindo do cwd herdado.
    $invoke = Join-Path $scriptsDir 'Invoke-OpenCode.ps1'
    $start = Join-Path $scriptsDir 'Start-OpenCodeJob.ps1'
    $prompt = Join-Path $tempRoot 'prompt.txt'
    Set-Content -LiteralPath $prompt -Value 'oi' -Encoding utf8 -NoNewline
    $runStream = Join-Path $tempRoot 'run-stream.jsonl'
    @(
        '{"type":"text","part":{"messageID":"m1","text":"OK-ADAPTER"}}'
        '{"type":"step_finish","part":{"reason":"stop"}}'
    ) | Set-Content -LiteralPath $runStream -Encoding utf8

    $env:FAKE_OC_VERSION = $testedVersion
    $env:FAKE_OC_AGENTLIST = $sampleAgentList
    $env:FAKE_OC_AGENTLIST_EXIT = ''
    $env:FAKE_OC_RUN_STREAM = $runStream
    $env:FAKE_OC_RUN_STDERR = ''

    Push-Location $repoRoot
    try {
        # (a-sync) sem -Agent => default reviewer-ro no argv; pre-check passa; run devolve a saida
        $argvSync = Join-Path $tempRoot 'argv-sync.txt'
        $env:FAKE_OC_ARGV_FILE = $argvSync
        $ans = & $invoke -OpenCodeExe $fakeCmd -MessagePath $prompt -Model 'fake/model' -TimeoutSec 30
        Assert-True (([string]$ans) -match 'OK-ADAPTER') "(a-sync) run devolveu a saida do fake (pre-check passou)"
        $argvSyncText = if (Test-Path -LiteralPath $argvSync) { Get-Content -LiteralPath $argvSync -Raw } else { '' }
        Assert-True ($argvSyncText -match '--agent reviewer-ro') "(a-sync) default -Agent reviewer-ro no argv do run (got: $argvSyncText)"

        # (e-adapter) pos-check SINCRONO end-to-end: exit 0 mas o stderr tem o warning de fallback =>
        # o adapter (caminho revisor) le $err cru e lanca BLOCK: pos-check, descartando a saida.
        $env:FAKE_OC_RUN_STDERR = (Get-Content -LiteralPath $fallbackFixture -Raw -Encoding utf8).Trim()
        $threwPc = $false; $msgPc = ''
        try { & $invoke -OpenCodeExe $fakeCmd -MessagePath $prompt -Model 'fake/model' -TimeoutSec 30 | Out-Null }
        catch { $threwPc = $true; $msgPc = $_.Exception.Message }
        Assert-True ($threwPc -and $msgPc -match 'pos-check reviewer-ro') "(e-adapter) warning de fallback no stderr => adapter lanca BLOCK pos-check (got: $msgPc)"
        $env:FAKE_OC_RUN_STDERR = ''

        # (b-adapter) allow-set divergente => BLOCK ANTES do run (argv do run NAO e escrito)
        $argvBlock = Join-Path $tempRoot 'argv-block.txt'
        $env:FAKE_OC_ARGV_FILE = $argvBlock
        $env:FAKE_OC_AGENTLIST = $excessPath
        $threw = $false; $msg = ''
        try { & $invoke -OpenCodeExe $fakeCmd -MessagePath $prompt -Model 'fake/model' -TimeoutSec 30 | Out-Null }
        catch { $threw = $true; $msg = $_.Exception.Message }
        Assert-True ($threw -and $msg -match 'guard reviewer-ro fail-closed') "(b-adapter) allow-set divergente => BLOCK do adapter (got: $msg)"
        Assert-True (-not (Test-Path -LiteralPath $argvBlock)) "(b-adapter) BLOCK ANTES do run: argv do run nao foi escrito"
        $env:FAKE_OC_AGENTLIST = $sampleAgentList

        # (a-async) Start-OpenCodeJob sem -Agent => default reviewer-ro no argv (spawn e a barreira)
        $argvAsync = Join-Path $tempRoot 'argv-async.txt'
        $env:FAKE_OC_ARGV_FILE = $argvAsync
        $jobDir = Join-Path $tempRoot 'jobs'
        $null = & $start -OpenCodeExe $fakeCmd -MessagePath $prompt -Model 'fake/model' -NoWatcher -TempDir $jobDir
        $waited = 0
        while (-not (Test-Path -LiteralPath $argvAsync) -and $waited -lt 15) { Start-Sleep -Milliseconds 300; $waited++ }
        $argvAsyncText = if (Test-Path -LiteralPath $argvAsync) { Get-Content -LiteralPath $argvAsync -Raw } else { '' }
        Assert-True ($argvAsyncText -match '--agent reviewer-ro') "(a-async) default -Agent reviewer-ro no argv do spawn (got: $argvAsyncText)"

        # (b-adapter-async) Start-OpenCodeJob com allow-set divergente => BLOCK ANTES do Start-Process
        # (o pre-check no spawn e a barreira do assincrono; o job NAO deve spawnar).
        $argvAsyncBlock = Join-Path $tempRoot 'argv-async-block.txt'
        $env:FAKE_OC_ARGV_FILE = $argvAsyncBlock
        $env:FAKE_OC_AGENTLIST = $excessPath
        $threwA = $false; $msgA = ''
        try { & $start -OpenCodeExe $fakeCmd -MessagePath $prompt -Model 'fake/model' -NoWatcher -TempDir (Join-Path $tempRoot 'jobs-block') | Out-Null }
        catch { $threwA = $true; $msgA = $_.Exception.Message }
        Start-Sleep -Milliseconds 500
        Assert-True ($threwA -and $msgA -match 'guard reviewer-ro fail-closed') "(b-adapter-async) allow-set divergente => BLOCK do Start-OpenCodeJob (got: $msgA)"
        Assert-True (-not (Test-Path -LiteralPath $argvAsyncBlock)) "(b-adapter-async) BLOCK ANTES do spawn: argv do job nao foi escrito (nao spawnou)"
        $env:FAKE_OC_AGENTLIST = $sampleAgentList

        # (opt-out) -Agent <x> explicito (x != reviewer-ro): opt-out consciente. So confirma que <x>
        # RESOLVE (Test-OpenCodeAgentResolves), sem enforce read-only. Caso resolve => despacha.
        $argvOpt = Join-Path $tempRoot 'argv-optout.txt'
        $env:FAKE_OC_ARGV_FILE = $argvOpt
        $optList = Join-Path $tempRoot 'agentlist-optout.txt'
        Set-Content -LiteralPath $optList -Value ("reviewer-fake (all)`n[`n{`"permission`":`"*`",`"action`":`"allow`",`"pattern`":`"*`"}`n]") -Encoding utf8
        $env:FAKE_OC_AGENTLIST = $optList
        $ansOpt = & $invoke -OpenCodeExe $fakeCmd -Agent 'reviewer-fake' -MessagePath $prompt -Model 'fake/model' -TimeoutSec 30
        Assert-True (([string]$ansOpt) -match 'OK-ADAPTER') "(opt-out) -Agent <x> que resolve => despacha (sem enforce reviewer-ro)"
        $argvOptText = if (Test-Path -LiteralPath $argvOpt) { Get-Content -LiteralPath $argvOpt -Raw } else { '' }
        Assert-True ($argvOptText -match '--agent reviewer-fake') "(opt-out) argv usa o agente explicito (nao reviewer-ro) (got: $argvOptText)"

        # (opt-out) -Agent <x> que NAO resolve (ausente do agent list) => BLOCK antes do run
        $argvOptBlk = Join-Path $tempRoot 'argv-optout-block.txt'
        $env:FAKE_OC_ARGV_FILE = $argvOptBlk
        $env:FAKE_OC_AGENTLIST = $sampleAgentList   # so tem reviewer-ro, nao 'agente-nao-existe'
        $threwO = $false; $msgO = ''
        try { & $invoke -OpenCodeExe $fakeCmd -Agent 'agente-nao-existe' -MessagePath $prompt -Model 'fake/model' -TimeoutSec 30 | Out-Null }
        catch { $threwO = $true; $msgO = $_.Exception.Message }
        Assert-True ($threwO -and $msgO -match 'nao resolve') "(opt-out) -Agent <x> que NAO resolve => BLOCK (evita fallback ao build) (got: $msgO)"
        Assert-True (-not (Test-Path -LiteralPath $argvOptBlk)) "(opt-out) BLOCK antes do run: argv nao foi escrito"
        $env:FAKE_OC_AGENTLIST = $sampleAgentList
    }
    finally { Pop-Location -ErrorAction SilentlyContinue }
}
finally {
    foreach ($e in $fakeEnv) { Remove-Item "Env:$e" -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($fail -gt 0) { throw "BLOCK: $fail caso(s) falharam em Test-OpenCodeReviewerRoSelfTest.ps1" }
Write-Host 'OPENCODE_REVIEWER_RO_SELFTEST_OK' -ForegroundColor Cyan
