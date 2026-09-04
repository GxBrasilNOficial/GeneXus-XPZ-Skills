#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do harness Invoke-LlmDelegatePanelDispatch.ps1 (skill xpz-llm-delegate).
.DESCRIPTION
    Determinístico, sem backends reais nem rede: injeta fake-exe por backend via -BackendExeMap
    (no adapter REAL) e dirige o gate REAL por configs/política sintéticas. Cobre a lista de
    self-test da v11: modelo efetivo + fail-closeds; gate codex com oss; gate geral (fixture,
    fail-closed kb-sensitive, gate que LANÇA); opencode kb-sensitive -> unavailable; splat +
    contenção; captura durável Codex no painel (TempDir/RetentionMode Bound, invokeArgs.tempdir→droppedArgs,
    strip XPZ_CODEX_ com 429 no path); paralelismo (ocupação <= OllamaConcurrency p/ ollama-cloud, outros livres, bloco
    que lança não aborta os demais, OllamaConcurrency=0 -> validação, Dispose após captura);
    sem single-flight (fake NÃO re-invocado + concurrencySaturationWarning); classificação
    mecânica (responded mesmo off-task); -Cd (precedência + fail-closed); contrato (stdout 1 linha
    JSON Kind/SchemaVersion PascalCase, acentos íntegros, stderr separado, state subset,
    targetModelKey vazio->null, ledger por estado, unavailableCount, quotaCount, ReviewersJson inline/arquivo/
    inválido, RoundId ausente->guid, slug Windows-safe).

    O harness é invocado como PROCESSO FILHO (pwsh -File) com stdout/stderr redirecionados a
    arquivos — fiel ao consumo real e à disciplina de stdout (o JSON é a única linha de stdout).

    Sentinela de sucesso: OK: Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptsDir = $PSScriptRoot
$harness = Join-Path $scriptsDir 'Invoke-LlmDelegatePanelDispatch.ps1'
if (-not (Test-Path -LiteralPath $harness -PathType Leaf)) { throw "BLOCK: alvo nao encontrado: $harness" }

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "ASSERT FALHOU: $Message" }
}
function Get-Reviewer {
    param($Json, [int]$Index)
    return @($Json.reviewers | Where-Object { [int]$_.index -eq $Index })[0]
}
function Get-ReviewerByTarget {
    param($Json, [string]$TargetModelKey)
    return @($Json.reviewers | Where-Object { [string]$_.targetModelKey -eq $TargetModelKey })[0]
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('gx-panel-dispatch-selftest-' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($tmp) | Out-Null
$ledgerRoot = Join-Path $tmp 'ledger'
$concLog = Join-Path $tmp 'conc.log'
$mutexName = 'panel-fake-mtx-' + [guid]::NewGuid().ToString('N')

# Env compartilhado com o processo filho (e com os fake-exe via Start-Process herdado)
$env:PANEL_FAKE_LOG = $concLog
$env:PANEL_FAKE_MUTEX = $mutexName
# Isola KeepDays do Invoke-Codex (splat Bound TempDir do harness vence env; DISABLE evita limpeza).
$script:prevCodexDisableKeepDays = $env:XPZ_CODEX_DISABLE_KEEPDAYS
$env:XPZ_CODEX_DISABLE_KEEPDAYS = '1'
# Guard D1/D2: versao testada dos fixtures (o fake-opencode a devolve em --version p/ o pre-check)
$repoRoot = Split-Path -Parent $scriptsDir
$env:PANEL_FAKE_OC_VERSION = ((Get-Content -LiteralPath (Join-Path $repoRoot 'xpz-llm-delegate\fixtures\opencode-reviewer-ro\VERSION.txt') -Raw -Encoding utf8).Trim())

# cwd deterministica na raiz do repo: o pre-check do opencode (default reviewer-ro) descobre o
# project-local .opencode/agent/reviewer-ro.md subindo do cwd herdado (harness in-process E filho).
Push-Location $repoRoot
try {
    # ---------------------------------------------------------------------------------------
    # Fixtures: fakes + configs sintéticas
    # ---------------------------------------------------------------------------------------
    # fake-opencode: lê stdin (prompt), parseia --model, registra ENTER/EXIT (mutex) e emite o
    # stream JSON mínimo do opencode. Comportamento por substring do modelo: 'sleep' dorme;
    # 'empty' emite só step_finish (sem texto) -> Invoke-OpenCode classifica 'empty' (terminal);
    # demais -> emite texto (responded), com acentos pt-BR.
    $fakeOcReader = Join-Path $tmp 'fake-oc-reader.ps1'
    @'
$a = @($args)
# Guard D1/D2: o painel usa o default reviewer-ro (bloqueia a chave agent), entao o adapter roda o
# pre-check (--version + agent list). Responder ANTES de ler stdin/model, sem consumir stdin.
if ($a -contains '--version') { $env:PANEL_FAKE_OC_VERSION; exit 0 }
if ($a.Count -ge 2 -and $a[0] -eq 'agent' -and $a[1] -eq 'list') {
    'reviewer-ro (all)'
    '['
    '{"permission":"*","action":"deny","pattern":"*"},'
    '{"permission":"read","action":"allow","pattern":"*"},'
    '{"permission":"grep","action":"allow","pattern":"*"},'
    '{"permission":"glob","action":"allow","pattern":"*"},'
    '{"permission":"list","action":"allow","pattern":"*"},'
    '{"permission":"edit","action":"deny","pattern":"*"},'
    '{"permission":"bash","action":"deny","pattern":"*"},'
    '{"permission":"webfetch","action":"deny","pattern":"*"},'
    '{"permission":"websearch","action":"deny","pattern":"*"},'
    '{"permission":"task","action":"deny","pattern":"*"},'
    '{"permission":"external_directory","action":"deny","pattern":"*"}'
    ']'
    exit 0
}
$model = ''
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '--model') { $model = [string]$args[$i + 1]; break } }
$null = [Console]::In.ReadToEnd()
$fam = @($model -split '/', 2)[0]
$log = $env:PANEL_FAKE_LOG
$mtxName = $env:PANEL_FAKE_MUTEX
function Append-Log([string]$line) {
    if ([string]::IsNullOrEmpty($log)) { return }
    $mtx = [System.Threading.Mutex]::new($false, $mtxName)
    [void]$mtx.WaitOne()
    try { [System.IO.File]::AppendAllText($log, $line + "`n") } finally { $mtx.ReleaseMutex(); $mtx.Dispose() }
}
Append-Log("$fam`tENTER`t$([DateTime]::UtcNow.Ticks)`t$model")
if ($model -match 'sleep') { Start-Sleep -Milliseconds 1200 }
if ($model -match 'timeout') { Start-Sleep -Milliseconds 5000 }
Append-Log("$fam`tEXIT`t$([DateTime]::UtcNow.Ticks)`t$model")
if ($model -match 'cota') {
    # evento de erro de stream com 402/quota/saldo -> Invoke-OpenCode lanca BLOCK; harness -> quota
    '{"type":"error","error":{"data":{"message":"Payment Required: insufficient coding plan balance (HTTP 402) sem quota livre"}}}'
} elseif ($model -match 'exausto') {
    # erro GENERICO que contem a palavra "exhausted" sem ser cota -> deve virar error, NAO quota
    '{"type":"error","error":{"data":{"message":"stream failed: retries exhausted after 3 attempts"}}}'
} elseif ($model -match 'empty') {
    '{"type":"step_finish","part":{"reason":"stop"}}'
} else {
    '{"type":"text","part":{"messageID":"m1","text":"PARECER de ' + $model + ' — revisão, dedução, ação (acentos pt-BR)."}}'
    '{"type":"step_finish","part":{"reason":"stop"}}'
}
exit 0
'@ | Set-Content -LiteralPath $fakeOcReader -Encoding utf8

    $fakeOcCmd = Join-Path $tmp 'fake-opencode.cmd'
    @"
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-oc-reader.ps1" %*
"@ | Set-Content -LiteralPath $fakeOcCmd -Encoding ascii

    # fake-codex: varre args por -o/-C/-m, lê stdin, escreve "CD=<C> MODEL=<m>" (texto bruto) no -o.
    $fakeCxReader = Join-Path $tmp 'fake-cx-reader.ps1'
    @'
$o = $null; $cd = ''; $m = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '-o') { $o = [string]$args[$i + 1] }
    if ($args[$i] -eq '-C') { $cd = [string]$args[$i + 1] }
    if ($args[$i] -eq '-m') { $m = [string]$args[$i + 1] }
}
$null = [Console]::In.ReadToEnd()
if ($o) { Set-Content -LiteralPath $o -Value ("CD=$cd MODEL=$m revisão") -Encoding utf8 -NoNewline }
exit 0
'@ | Set-Content -LiteralPath $fakeCxReader -Encoding utf8

    $fakeCxCmd = Join-Path $tmp 'fake-codex.cmd'
    @"
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-cx-reader.ps1" %*
"@ | Set-Content -LiteralPath $fakeCxCmd -Encoding ascii

    # fake-claude: stdin-based (prompt por stdin; argv so com flags), entao .cmd+reader e seguro.
    # Responde --version (>=2.1.118) e --help (contrato de flags) exigidos por Resolve-ClaudeCodeExe;
    # na execucao emite stdout "CLAUDE cwd=<pwd> model=<m>" (sem palavras de erro). -Cd vira o
    # WorkingDirectory do processo, entao (Get-Location) prova o repasse.
    $fakeClReader = Join-Path $tmp 'fake-cl-reader.ps1'
    @'
$model = ''
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '--model') { $model = [string]$args[$i + 1] } }
if ($args -contains '--version') { '2.1.118 (Claude Code fake)'; exit 0 }
if ($args -contains '--help') {
    '--model --print --output-format --no-session-persistence --permission-mode --tools'
    exit 0
}
if ($model -eq 'claude-untrusted-workspace') {
    [Console]::Error.WriteLine('Claude Code refused to run because this workspace is not trusted. Mark this workspace as trusted to continue.')
    exit 1
}
$null = [Console]::In.ReadToEnd()
if ($model -eq 'claude-sensitive-ledger') {
    [Console]::Error.WriteLine('stderr bruto sensivel')
    [pscustomobject]@{
        type = 'content_block_delta'
        delta = [ordered]@{
            type = 'text_delta'
            text = "PARECER sensivel`n"
        }
    } | ConvertTo-Json -Compress -Depth 5
    [pscustomobject]@{
        type = 'result'
        subtype = 'success'
        is_error = $false
    } | ConvertTo-Json -Compress -Depth 5
    exit 0
}
$text = 'CLAUDE cwd=' + (Get-Location).Path + ' model=' + $model + ' revisao'
[pscustomobject]@{
    type = 'assistant'
    message = [ordered]@{
        content = @([ordered]@{ text = $text })
    }
} | ConvertTo-Json -Compress -Depth 5
[pscustomobject]@{
    type = 'result'
    subtype = 'success'
    is_error = $false
    result = 'NAO_E_VEREDITO'
} | ConvertTo-Json -Compress -Depth 5
exit 0
'@ | Set-Content -LiteralPath $fakeClReader -Encoding utf8
    $fakeClCmd = Join-Path $tmp 'fake-claude.cmd'
    @"
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-cl-reader.ps1" %*
"@ | Set-Content -LiteralPath $fakeClCmd -Encoding ascii

    # fake-copilot/fake-gemini: argument-based; o adapter os invoca por `& `$exe @args` (runner pwsh),
    # entao um .ps1 DIRETO evita o re-parse de cmd %* com prompt multilinha. Responde --version/--help
    # e, na execucao, emite o JSON que cada adapter parseia. cwd com barras p/ JSON valido.
    $fakeCopilot = Join-Path $tmp 'fake-copilot.ps1'
    @'
$model = ''
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '--model') { $model = [string]$args[$i + 1] } }
if ($args -contains '--version') { '1.0.12'; exit 0 }
if ($args -contains '--help') {
    '--prompt --output-format --stream --no-custom-instructions --disable-builtin-mcps --available-tools --allow-all-tools --model'
    exit 0
}
$c = 'COPILOT cwd=' + (Get-Location).Path.Replace('\', '/') + ' model=' + $model + ' revisao'
'{"type":"assistant.message","data":{"content":"' + $c + '"}}'
'{"type":"result","exitCode":0}'
exit 0
'@ | Set-Content -LiteralPath $fakeCopilot -Encoding utf8

    $fakeGemini = Join-Path $tmp 'fake-gemini.ps1'
    @'
$model = ''
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '--model') { $model = [string]$args[$i + 1] } }
if ($args -contains '--version') { '0.35.3'; exit 0 }
if ($args -contains '--help') { '--prompt --approval-mode --output-format --model'; exit 0 }
$c = 'GEMINI cwd=' + (Get-Location).Path.Replace('\', '/') + ' model=' + $model + ' revisao'
'{"response":"' + $c + '"}'
exit 0
'@ | Set-Content -LiteralPath $fakeGemini -Encoding utf8

    # fake-antigravity: argument-based como Gemini/Copilot; --help precisa expor -p/--print e --mode
    # (contrato de Resolve-AntigravityExe). Resposta no envelope {status,response} do agy.
    $fakeAntigravity = Join-Path $tmp 'fake-antigravity.ps1'
    @'
$model = ''
for ($i = 0; $i -lt $args.Count; $i++) { if ($args[$i] -eq '--model') { $model = [string]$args[$i + 1] } }
if ($args -contains '--version') { 'agy 1.1.19'; exit 0 }
if ($args -contains '--help') {
    'Usage of agy: -p Run a prompt --mode Set agent mode --output-format json --model'
    exit 0
}
$args -join ' ' | Add-Content -LiteralPath (Join-Path $PSScriptRoot 'antigravity.calls.log') -Encoding utf8
$c = 'AGY cwd=' + (Get-Location).Path.Replace('\', '/') + ' model=' + $model + ' revisao'
(@{ status = 'SUCCESS'; response = $c } | ConvertTo-Json -Compress)
exit 0
'@ | Set-Content -LiteralPath $fakeAntigravity -Encoding utf8

    # Mapa de fake-exe (arquivo) — backends ativos (lista canônica em xpz-llm-delegate/SKILL.md)
    $exeMapFile = Join-Path $tmp 'exemap.json'
    ([ordered]@{
        opencode      = $fakeOcCmd
        codex         = $fakeCxCmd
        'claude-code' = $fakeClCmd
        copilot       = $fakeCopilot
        gemini        = $fakeGemini
        antigravity   = $fakeAntigravity
    } | ConvertTo-Json -Compress) | Set-Content -LiteralPath $exeMapFile -Encoding utf8

    # config opencode sintética (loopback p/ ollama; usada só onde o gate consulta config)
    $ocCfg = Join-Path $tmp 'opencode.json'
    @'
{ "provider": { "ollama": { "options": { "baseURL": "http://127.0.0.1:11434/v1" } } } }
'@ | Set-Content -LiteralPath $ocCfg -Encoding utf8

    # config.toml codex sintética (default openai/gpt-5.5)
    $cxCfg = Join-Path $tmp 'config.toml'
    @'
model = "gpt-5.5"
'@ | Set-Content -LiteralPath $cxCfg -Encoding utf8
    $cxCfgMissing = Join-Path $tmp 'nope-config.toml'   # NÃO existe (caso 'sem config')

    # política sintética: openai/* allow-external (p/ caminhos de allow em kb-sensitive)
    $pol = Join-Path $tmp 'llm-delegation-policy.json'
    @'
{ "schemaVersion": 1, "defaultExternal": "ask", "models": { "openai/*": "allow-external" } }
'@ | Set-Content -LiteralPath $pol -Encoding utf8

    $polAnthropic = Join-Path $tmp 'llm-delegation-policy-anthropic.json'
    @'
{ "schemaVersion": 1, "defaultExternal": "ask", "models": { "anthropic/*": "allow-external" } }
'@ | Set-Content -LiteralPath $polAnthropic -Encoding utf8

    $polAntigravity = Join-Path $tmp 'llm-delegation-policy-antigravity.json'
    @'
{ "schemaVersion": 1, "defaultExternal": "ask", "models": { "antigravity/*": "allow-external" } }
'@ | Set-Content -LiteralPath $polAntigravity -Encoding utf8

    # manuscrito (acentos)
    $manuscript = Join-Path $tmp 'manuscrito.md'
    @'
# Manuscrito de teste

Conteúdo com acentuação pt-BR: revisão, dedução, ação. Avalie e emita parecer.
'@ | Set-Content -LiteralPath $manuscript -Encoding utf8

    # ---------------------------------------------------------------------------------------
    # Helper de invocação (processo filho, stdout/stderr separados em arquivo)
    # ---------------------------------------------------------------------------------------
    $defaultClaudeCircuitRoot = Join-Path $tmp 'claude-circuit'
    function Invoke-Harness {
        param(
            [Parameter(Mandatory)] [object[]] $Reviewers,
            [string] $Sensitivity = 'public',
            [hashtable] $Extra = @{},
            [switch] $NoRoundId,
            [switch] $NoExeMap,
            [switch] $UseManuscriptText,
            [switch] $OmitManuscriptSource,
            [switch] $BothManuscriptSources,
            [AllowEmptyString()] [string] $ManuscriptText = ''
        )
        $rid = [guid]::NewGuid().ToString('N')
        $revFile = Join-Path $tmp "rev-$rid.json"
        (@($Reviewers) | ConvertTo-Json -Depth 8 -AsArray) | Set-Content -LiteralPath $revFile -Encoding utf8
        $oFile = Join-Path $tmp "out-$rid.txt"
        $eFile = Join-Path $tmp "err-$rid.txt"

        $argList = @(
            '-NoProfile', '-File', $harness,
            '-ReviewersJson', $revFile,
            '-PayloadSensitivity', $Sensitivity,
            '-TempDir', $ledgerRoot
        )
        if ($OmitManuscriptSource) {
            # Intencional: exercita validacao estruturada de origem ausente.
        } elseif ($BothManuscriptSources) {
            $argList += @('-ManuscriptPath', $manuscript, '-ManuscriptText', $ManuscriptText)
        } elseif ($UseManuscriptText) {
            $argList += @('-ManuscriptText', $ManuscriptText)
        } else {
            $argList += @('-ManuscriptPath', $manuscript)
        }
        if (-not $NoRoundId) { $argList += @('-RoundId', $rid) }
        if (-not $NoExeMap) { $argList += @('-BackendExeMap', $exeMapFile) }
        if (-not $Extra.ContainsKey('ClaudeCircuitStateRoot')) { $argList += @('-ClaudeCircuitStateRoot', $defaultClaudeCircuitRoot) }
        foreach ($k in $Extra.Keys) { $argList += @("-$k", [string]$Extra[$k]) }

        $p = Start-Process -FilePath 'pwsh' -ArgumentList $argList -NoNewWindow -PassThru `
            -RedirectStandardOutput $oFile -RedirectStandardError $eFile
        [void]$p.WaitForExit(180000)
        $stdout = Get-Content -LiteralPath $oFile -Raw -Encoding utf8 -ErrorAction SilentlyContinue
        $stderr = Get-Content -LiteralPath $eFile -Raw -Encoding utf8 -ErrorAction SilentlyContinue
        if ($null -eq $stdout) { $stdout = '' }
        if ($null -eq $stderr) { $stderr = '' }
        $json = $null
        if (-not [string]::IsNullOrWhiteSpace($stdout)) { try { $json = $stdout | ConvertFrom-Json } catch { } }
        return [pscustomobject]@{
            stdout    = $stdout
            stderr    = $stderr
            exit      = $p.ExitCode
            json      = $json
            roundId   = $rid
            ledgerDir = Join-Path $ledgerRoot $rid
        }
    }

    # =======================================================================================
    # 1) MODELO EFETIVO + FAIL-CLOSEDS
    # =======================================================================================
    # opencode sem model -> usa targetModelKey de ENTRADA (mesmo valor ao gate e ao adapter)
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/sem-model'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    Assert-True ($null -ne $r.json) 'opencode sem model: deveria emitir summary'
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'responded') "opencode sem model+public: esperado responded; got $($rv.state)"
    Assert-True ($rv.effectiveModel -eq 'openai/sem-model') "opencode sem model: effectiveModel deveria ser o targetModelKey de entrada; got '$($rv.effectiveModel)'"

    # opencode sem model E sem targetModelKey -> error
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; invokeArgs = @{} }) -Sensitivity 'public'
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'error') "opencode sem model e sem targetModelKey: esperado error; got $($rv.state)"

    # codex sem model COM config -> gate sem -Model devolve targetModelKey; harness deriva último segmento
    $r = Invoke-Harness -Reviewers @(@{ backend = 'codex'; invokeArgs = @{} }) `
        -Sensitivity 'kb-sensitive' -Extra @{ CodexConfigPath = $cxCfg }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.effectiveModel -eq 'gpt-5.5') "codex sem model+config: effectiveModel deveria ser 'gpt-5.5' (nu); got '$($rv.effectiveModel)'"
    Assert-True ($rv.targetModelKey -eq 'openai/gpt-5.5') "codex sem model+config: targetModelKey deveria ser 'openai/gpt-5.5'; got '$($rv.targetModelKey)'"
    Assert-True ($rv.state -eq 'gateAsk') "codex sem model+config kb-sensitive sem politica: esperado gateAsk; got $($rv.state)"

    # codex sem model SEM config -> error fail-closed
    $r = Invoke-Harness -Reviewers @(@{ backend = 'codex'; invokeArgs = @{} }) `
        -Sensitivity 'kb-sensitive' -Extra @{ CodexConfigPath = $cxCfgMissing }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'error') "codex sem model e sem config: esperado error; got $($rv.state)"

    # claude-code/copilot/gemini/antigravity sem model -> error
    foreach ($b in @('claude-code', 'copilot', 'gemini', 'antigravity')) {
        $r = Invoke-Harness -Reviewers @(@{ backend = $b; invokeArgs = @{} }) -Sensitivity 'public'
        $rv = Get-Reviewer $r.json 0
        Assert-True ($rv.state -eq 'error') "$b sem model: esperado error fail-closed; got $($rv.state)"
        Assert-True ($null -eq $rv.effectiveModel) "$b sem model: effectiveModel deveria ser null"
    }

    # =======================================================================================
    # 2) GATE CODEX COM OSS (-Oss/-LocalProvider chegam ao gate -> local -> allow -> despacha)
    # =======================================================================================
    # -Cd explicito p/ satisfazer o fail-closed (codex e cd-capable em kb-sensitive, mesmo com modelo local)
    $r = Invoke-Harness -Reviewers @(@{ backend = 'codex'; invokeArgs = @{ model = 'qwen2.5-coder'; oss = $true; localProvider = 'ollama' } }) `
        -Sensitivity 'kb-sensitive' -Extra @{ CodexConfigPath = $cxCfgMissing; Cd = $tmp }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.gateVerdict -eq 'allow') "codex oss local kb-sensitive: gate deveria devolver allow (oss/localProvider chegaram ao gate); got '$($rv.gateVerdict)'"
    Assert-True ($rv.state -eq 'responded') "codex oss local: deveria despachar e responder via fake; got $($rv.state)"

    # =======================================================================================
    # 3) GATE GERAL: fail-closed kb-sensitive sem politica; gate que LANÇA
    # =======================================================================================
    # claude-code externo kb-sensitive sem politica -> ask
    $r = Invoke-Harness -Reviewers @(@{ backend = 'claude-code'; invokeArgs = @{ model = 'claude-opus-4-8' } }) -Sensitivity 'kb-sensitive'
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'gateAsk') "claude-code kb-sensitive sem politica: esperado gateAsk; got $($rv.state)"

    # gate que LANÇA: -ParallelKbRoot inexistente faz o resolvedor de politica lançar (gate nao captura)
    $ghost = Join-Path $tmp 'pasta-inexistente-xyz'
    $r = Invoke-Harness -Reviewers @(@{ backend = 'claude-code'; invokeArgs = @{ model = 'claude-opus-4-8' } }) `
        -Sensitivity 'public' -Extra @{ ParallelKbRoot = $ghost }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'error') "gate que lança: esperado error; got $($rv.state)"
    Assert-True ($null -eq $rv.gateVerdict) "gate que lança: gateVerdict deveria ser null"
    Assert-True ($null -ne $r.json) 'gate que lança: o harness ainda deve emitir summary'

    # =======================================================================================
    # 4) OPENCODE EM KB-SENSITIVE -> unavailable (sem gate/adapter); fake NÃO invocado
    # =======================================================================================
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'ollama-cloud/x'; invokeArgs = @{ model = 'ollama-cloud/x' } }) `
        -Sensitivity 'kb-sensitive'
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'unavailable') "opencode kb-sensitive: esperado unavailable; got $($rv.state)"
    Assert-True ($null -eq $rv.gateVerdict) 'opencode kb-sensitive: gateVerdict deveria ser null'
    Assert-True ([int]$r.json.unavailableCount -ge 1) 'opencode kb-sensitive: unavailableCount >= 1'
    Assert-True ($null -ne $rv.statePath) 'opencode kb-sensitive: deveria ter .state.txt no ledger'

    # =======================================================================================
    # 5) SPLAT + CONTENÇÃO (per-backend) — sem despacho (kb-sensitive -> gateAsk)
    # =======================================================================================
    # claude-code: permissionMode/tools/maxTurns e chaves internas -> securityBlockedArgs
    $r = Invoke-Harness -Reviewers @(@{ backend = 'claude-code'; invokeArgs = @{
                    model = 'claude-opus-4-8'
                    permissionMode = 'bypassPermissions'
                    tools = 'Bash'
                    maxTurns = 9
                    SidecarPath = 'C:\tmp\roubar-sidecar.json'
                    RetentionMode = 'public'
                    TempDir = 'C:\tmp\roubar-ledger'
                    CircuitStateRoot = 'C:\tmp\roubar-circuito'
                    ClaudeExe = 'C:\tmp\fake-claude.exe'
                    MessagePath = 'C:\tmp\outro-prompt.txt'
                } }) -Sensitivity 'kb-sensitive'
    $rv = Get-Reviewer $r.json 0
    $sb = @($rv.securityBlockedArgs)
    Assert-True (($sb -contains 'permissionMode') -and ($sb -contains 'tools') -and ($sb -contains 'maxTurns')) "claude-code contenção: securityBlockedArgs deveria conter permissionMode/tools/maxTurns; got [$($sb -join ',')]"
    foreach ($blockedInternalArg in @('SidecarPath', 'RetentionMode', 'TempDir', 'CircuitStateRoot', 'ClaudeExe', 'MessagePath')) {
        Assert-True ($sb -contains $blockedInternalArg) "claude-code chaves internas: securityBlockedArgs deveria conter $blockedInternalArg; got [$($sb -join ',')]"
    }

    # opencode: agent -> securityBlockedArgs (mesmo em kb-sensitive: classificação precede o unavailable)
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'ollama-cloud/x'; invokeArgs = @{ model = 'ollama-cloud/x'; agent = 'build' } }) -Sensitivity 'kb-sensitive'
    $rv = Get-Reviewer $r.json 0
    Assert-True (@($rv.securityBlockedArgs) -contains 'agent') "opencode contenção: securityBlockedArgs deveria conter agent"

    # gemini approvalMode=plan -> droppedArgs ; approvalMode=yolo -> securityBlockedArgs
    $r = Invoke-Harness -Reviewers @(
        @{ backend = 'gemini'; invokeArgs = @{ model = 'gemini-3-flash-preview'; approvalMode = 'plan' } },
        @{ backend = 'gemini'; invokeArgs = @{ model = 'gemini-3-flash-preview'; approvalMode = 'yolo' } }
    ) -Sensitivity 'kb-sensitive'
    $rvPlan = Get-Reviewer $r.json 0
    $rvYolo = Get-Reviewer $r.json 1
    Assert-True (@($rvPlan.droppedArgs) -contains 'approvalMode') 'gemini approvalMode=plan -> droppedArgs'
    Assert-True (@($rvPlan.securityBlockedArgs).Count -eq 0) 'gemini approvalMode=plan -> NÃO securityBlocked'
    Assert-True (@($rvYolo.securityBlockedArgs) -contains 'approvalMode') 'gemini approvalMode=yolo -> securityBlockedArgs'

    # antigravity public-review: nenhum override de perfil/cwd/conteção ou seam interno atravessa.
    $r = Invoke-Harness -Reviewers @(@{ backend = 'antigravity'; invokeArgs = @{
        model = 'gemini-3.6-flash-high'; mode = 'plan'; profile = 'public-review'; cd = $tmp
        agent = 'custom'; approvalMode = 'plan'; scratchPath = $tmp; receiptPath = 'x.json'
        simulateCleanupFailure = 'failed'; antigravityExe = 'x'; message = 'x'; messagePath = 'x'
    } }) -Sensitivity 'public'
    $rvAgBlocked = Get-Reviewer $r.json 0
    $agyBlocked = @($rvAgBlocked.securityBlockedArgs)
    foreach ($key in @('mode','profile','cd','agent','approvalMode','scratchPath','receiptPath','simulateCleanupFailure','antigravityExe','message','messagePath')) {
        Assert-True ($agyBlocked -contains $key) "antigravity contenção: $key deve ficar em securityBlockedArgs"
    }

    # codex / copilot: chave estranha -> droppedArgs ; não-codex com profile -> droppedArgs
    $r = Invoke-Harness -Reviewers @(
        @{ backend = 'codex'; invokeArgs = @{ model = 'gpt-5.5'; foobar = 'x' } },
        @{ backend = 'copilot'; invokeArgs = @{ model = 'gpt-5-mini'; foobar = 'y' } },
        @{ backend = 'claude-code'; invokeArgs = @{ model = 'claude-opus-4-8'; profile = 'p' } }
    ) -Sensitivity 'kb-sensitive' -Extra @{ CodexConfigPath = $cxCfg }
    Assert-True (@((Get-Reviewer $r.json 0).droppedArgs) -contains 'foobar') 'codex chave estranha -> droppedArgs'
    Assert-True (@((Get-Reviewer $r.json 1).droppedArgs) -contains 'foobar') 'copilot chave estranha -> droppedArgs'
    Assert-True (@((Get-Reviewer $r.json 2).droppedArgs) -contains 'profile') 'claude-code com profile -> droppedArgs (profile é só do codex)'

    # =======================================================================================
    # 5b) CAPTURA DURÁVEL CODEX NO PAINEL: splat Bound + droppedArgs + strip XPZ_CODEX_
    # =======================================================================================
    # (a)+(b) TempDir Bound em %TEMP%\xpz-llm-panel-codex\<RoundId> (fora do ledger/Cd);
    # invokeArgs.tempdir/retentionMode -> droppedArgs. Bound vence.
    $stolenCodexLedger = Join-Path $tmp 'roubar-codex-ledger'
    [IO.Directory]::CreateDirectory($stolenCodexLedger) | Out-Null
    $r = Invoke-Harness -Reviewers @(@{
            backend = 'codex'
            invokeArgs = @{
                model          = 'gpt-5.5'
                tempdir        = $stolenCodexLedger
                retentionMode  = 'kb-sensitive'
            }
        }) -Sensitivity 'public' -Extra @{ CodexConfigPath = $cxCfg }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'responded') "codex durable splat: esperado responded; got $($rv.state)"
    $droppedCodex = @($rv.droppedArgs)
    Assert-True ($droppedCodex -contains 'tempdir') "codex durable: tempdir deveria cair em droppedArgs; got [$($droppedCodex -join ',')]"
    Assert-True ($droppedCodex -contains 'retentionMode') "codex durable: retentionMode deveria cair em droppedArgs; got [$($droppedCodex -join ',')]"
    $secCodex = @($rv.securityBlockedArgs)
    Assert-True ($secCodex -notcontains 'tempdir' -and $secCodex -notcontains 'retentionMode') "codex durable: tempdir/retentionMode NAO sao securityBlockedArgs; got [$($secCodex -join ',')]"
    Assert-True (@(Get-ChildItem -LiteralPath $stolenCodexLedger -Filter '*.request.json' -File -ErrorAction SilentlyContinue).Count -eq 0) 'codex durable: invokeArgs.tempdir NAO deve receber request.json (Bound vence)'
    $codexCaptureDir = Join-Path (Join-Path ([IO.Path]::GetTempPath()) 'xpz-llm-panel-codex') ([string]$r.json.roundId)
    Assert-True (Test-Path -LiteralPath $codexCaptureDir -PathType Container) "codex durable: TempDir Bound em xpz-llm-panel-codex/<RoundId>; missing $codexCaptureDir"
    $boundReqs = @(Get-ChildItem -LiteralPath $codexCaptureDir -Filter '*.request.json' -File -ErrorAction SilentlyContinue)
    $boundMsgs = @(Get-ChildItem -LiteralPath $codexCaptureDir -Filter '*.lastmsg.txt' -File -ErrorAction SilentlyContinue)
    Assert-True ($boundReqs.Count -ge 1) "codex durable splat TempDir: request.json sob xpz-llm-panel-codex Bound; got $($boundReqs.Count)"
    Assert-True ($boundMsgs.Count -ge 1) 'codex durable RetentionMode=public Bound: lastmsg permanece no capture dir (kb-sensitive do invokeArgs foi dropado)'
    Assert-True (@(Get-ChildItem -LiteralPath $r.ledgerDir -Filter '*.request.json' -File -ErrorAction SilentlyContinue).Count -eq 0) 'codex durable: request.json NAO fica no ledger (so verdict/error)'
    $cap = (Get-Content -LiteralPath $boundReqs[0].FullName -Raw -Encoding utf8 | ConvertFrom-Json).captureOutcome
    Assert-True ($cap -eq 'success') "codex durable: captureOutcome=success; got '$cap'"

    # (c) strip XPZ_CODEX_ no Parallel: path/RoundId com 429 nas sentinelas NAO vira quota
    $prevForceTimeout = $env:XPZ_TEST_CODEX_FORCE_TIMEOUT
    $env:XPZ_TEST_CODEX_FORCE_TIMEOUT = '1'
    try {
        $rid429 = 'panel-strip-429-' + [guid]::NewGuid().ToString('N')
        $r = Invoke-Harness -Reviewers @(@{ backend = 'codex'; invokeArgs = @{ model = 'gpt-5.5'; timeoutSec = 2 } }) `
            -Sensitivity 'public' -NoRoundId -Extra @{ RoundId = $rid429; CodexConfigPath = $cxCfg }
        $rv = Get-Reviewer $r.json 0
        Assert-True ($rv.state -eq 'timeout') "codex strip 429: esperado timeout (nao quota); got $($rv.state)"
        Assert-True ([int]$r.json.quotaCount -eq 0) "codex strip 429: quotaCount deveria ser 0; got $($r.json.quotaCount)"
        Assert-True ($null -ne $rv.errorPath) 'codex strip 429: deveria gravar .error.txt com errText completo'
        $errLedger = Get-Content -LiteralPath $rv.errorPath -Raw -Encoding utf8
        Assert-True ($errLedger -match '429') 'codex strip 429: errorPath preserva path/429 (errText completo)'
        Assert-True ($errLedger -match 'excedeu' -and $errLedger -match 'foi encerrado') 'codex strip 429: evidencia de timeout no errorPath'
    } finally {
        if ($null -eq $prevForceTimeout) {
            Remove-Item Env:\XPZ_TEST_CODEX_FORCE_TIMEOUT -ErrorAction SilentlyContinue
        } else {
            $env:XPZ_TEST_CODEX_FORCE_TIMEOUT = $prevForceTimeout
        }
    }

    # (d) GAP-2: timeoutSec invalido -> error so naquele revisor; outro responde
    $r = Invoke-Harness -Reviewers @(
        @{ backend = 'codex'; invokeArgs = @{ model = 'gpt-5.5'; timeoutSec = '600s' } },
        @{ backend = 'codex'; invokeArgs = @{ model = 'gpt-5.5' } }
    ) -Sensitivity 'public' -Extra @{ CodexConfigPath = $cxCfg }
    Assert-True ((Get-Reviewer $r.json 0).state -eq 'error') "GAP-2: timeoutSec '600s' -> error; got $((Get-Reviewer $r.json 0).state)"
    Assert-True ((Get-Reviewer $r.json 0).reason -match 'timeoutSec invalido') 'GAP-2: reason cita timeoutSec invalido'
    Assert-True ((Get-Reviewer $r.json 1).state -eq 'responded') "GAP-2: segundo revisor nao deve cair com o painel; got $((Get-Reviewer $r.json 1).state)"
    Assert-True ([int]$r.json.respondedCount -eq 1 -and [int]$r.json.errorCount -eq 1) 'GAP-2: painel completa com 1 responded + 1 error'

    # =======================================================================================
    # 6) PARALELISMO: ocupação <= OllamaConcurrency p/ ollama-cloud; outros livres; lança não aborta
    # =======================================================================================
    Set-Content -LiteralPath $concLog -Value '' -NoNewline -Encoding utf8
    $revs = @()
    1..5 | ForEach-Object { $revs += @{ backend = 'opencode'; targetModelKey = "ollama-cloud/sleep-$_"; invokeArgs = @{} } }
    1..5 | ForEach-Object { $revs += @{ backend = 'opencode'; targetModelKey = "openai/sleep-$_"; invokeArgs = @{} } }
    $r = Invoke-Harness -Reviewers $revs -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg; OllamaConcurrency = 2 }
    Assert-True ($null -ne $r.json) 'paralelismo: deveria emitir summary'
    Assert-True ([int]$r.json.respondedCount -eq 10) "paralelismo: 10 respondidos esperados; got $($r.json.respondedCount)"
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$r.json.ollamaQuotaWarning)) 'paralelismo: ollamaQuotaWarning deveria estar presente (5 ollama-cloud despachados no lote)'
    Assert-True ($r.stderr -match 'ollamaQuotaWarning') 'paralelismo: ollamaQuotaWarning deveria sair por stderr'

    $logLines = @(Get-Content -LiteralPath $concLog -ErrorAction SilentlyContinue | Where-Object { $_ })
    function Get-MaxOverlap {
        param([string[]]$Lines, [string]$Family)
        $events = @()
        foreach ($ln in $Lines) {
            $parts = @($ln -split "`t")
            if ($parts.Count -lt 3 -or $parts[0] -ne $Family) { continue }
            if ($parts[1] -eq 'ENTER') { $events += [pscustomobject]@{ t = [long]$parts[2]; d = 1 } }
            elseif ($parts[1] -eq 'EXIT') { $events += [pscustomobject]@{ t = [long]$parts[2]; d = -1 } }
        }
        $sorted = @($events | Sort-Object t, d)   # em empate, EXIT(-1) antes de ENTER(+1)
        $cur = 0; $max = 0
        foreach ($e in $sorted) { $cur += $e.d; if ($cur -gt $max) { $max = $cur } }
        return $max
    }
    $ollamaMax = Get-MaxOverlap -Lines $logLines -Family 'ollama-cloud'
    $openaiMax = Get-MaxOverlap -Lines $logLines -Family 'openai'
    Assert-True ($ollamaMax -le 2) "ollama-cloud: ocupação máxima deveria ser <= 2 (OllamaConcurrency); medida $ollamaMax"
    Assert-True ($openaiMax -ge 3) "openai (sem semáforo): ocupação deveria exceder o teto ollama (>=3); medida $openaiMax — sinal de que o semáforo NÃO limita outros providers"

    # bloco que lança não aborta os demais: um 'empty' (lança no adapter -> error) + um responded
    $r = Invoke-Harness -Reviewers @(
        @{ backend = 'opencode'; targetModelKey = 'openai/empty-iso'; invokeArgs = @{} },
        @{ backend = 'opencode'; targetModelKey = 'openai/ok-iso'; invokeArgs = @{} }
    ) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    Assert-True ((Get-Reviewer $r.json 0).state -eq 'error') 'bloco que lança: o empty deveria virar error'
    Assert-True ((Get-Reviewer $r.json 1).state -eq 'responded') 'bloco que lança: o outro revisor NÃO deveria ser abortado'

    # OllamaConcurrency=0 -> erro de validação (sem summary)
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/x'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg; OllamaConcurrency = 0 }
    Assert-True ($r.exit -ne 0) 'OllamaConcurrency=0: deveria falhar a validação (exit != 0)'
    Assert-True ($null -eq $r.json) 'OllamaConcurrency=0: não deveria emitir summary'

    # =======================================================================================
    # 7) SEM SINGLE-FLIGHT: ollama-cloud vazio em lote -> error; fake NÃO re-invocado; saturação
    # =======================================================================================
    Set-Content -LiteralPath $concLog -Value '' -NoNewline -Encoding utf8
    $r = Invoke-Harness -Reviewers @(
        @{ backend = 'opencode'; targetModelKey = 'ollama-cloud/empty-1'; invokeArgs = @{} },
        @{ backend = 'opencode'; targetModelKey = 'ollama-cloud/empty-2'; invokeArgs = @{} }
    ) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    Assert-True ((Get-Reviewer $r.json 0).state -eq 'error') 'single-flight: ollama empty-1 -> error'
    Assert-True ((Get-Reviewer $r.json 1).state -eq 'error') 'single-flight: ollama empty-2 -> error'
    Assert-True ([int]$r.json.errorCount -ge 2) 'single-flight: errorCount >= 2'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$r.json.concurrencySaturationWarning)) 'single-flight: concurrencySaturationWarning deveria estar presente (2+ ollama em error)'
    Assert-True ($r.stderr -match 'concurrencySaturationWarning') 'single-flight: aviso de saturação deveria sair por stderr'
    # cada empty foi invocado UMA vez (sem redisparo)
    $logLines = @(Get-Content -LiteralPath $concLog -ErrorAction SilentlyContinue | Where-Object { $_ })
    $entries1 = @($logLines | Where-Object { ($_ -split "`t")[3] -eq 'ollama-cloud/empty-1' -and ($_ -split "`t")[1] -eq 'ENTER' }).Count
    Assert-True ($entries1 -eq 1) "single-flight: o fake do empty-1 deveria ser invocado UMA vez; medido $entries1"

    # =======================================================================================
    # 8) CLASSIFICAÇÃO MECÂNICA: responded para texto não-vazio mesmo off-task
    # =======================================================================================
    # o fake devolve texto que NÃO é parecer; o harness NÃO reclassifica -> responded
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/offtask'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'responded') "classificação mecânica: texto não-vazio off-task -> responded; got $($rv.state)"
    Assert-True ($null -ne $rv.verdictPath) 'classificação mecânica: deveria gravar .verdict.txt'
    $vtext = Get-Content -LiteralPath $rv.verdictPath -Raw -Encoding utf8
    Assert-True ($vtext -match 'revisão') 'acentos: o texto do verdict deveria preservar acentuação pt-BR (revisão)'

    # =======================================================================================
    # 8b) CLASSIFICAÇÃO EM DESPACHO: cota → quota; timeout → timeout
    # =======================================================================================
    # cota: fake-opencode emite erro de stream com 402/quota/saldo -> adapter lança BLOCK -> quota
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'ollama-cloud/cota-1'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'quota') "cota: 402/quota/saldo em despacho deveria virar quota; got $($rv.state)"
    Assert-True ([int]$r.json.quotaCount -ge 1) 'cota: quotaCount >= 1'
    Assert-True ($null -ne $rv.statePath) 'cota: deveria gravar .state.txt no ledger'
    $quotaLedger = Get-Content -LiteralPath $rv.statePath -Raw -Encoding utf8
    Assert-True ($quotaLedger -match 'Payment Required' -and $quotaLedger -match 'insufficient coding plan balance' -and $quotaLedger -match '402' -and $quotaLedger -match 'sem quota') 'cota: .state.txt deveria preservar a evidencia bruta de quota/saldo/402'

    # NAO-cota: erro generico que contem "exhausted" (rede/contexto) NAO pode virar quota. Trava a
    # regressao do $quotaFailurePattern alargado, que classificava "retries exhausted" como cota em
    # TODOS os backends e mandaria o operador esperar reset de ciclo por falha que nao e de cota.
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/exausto-1'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'error') "nao-cota: 'retries exhausted' deveria virar error, nao quota; got $($rv.state)"
    Assert-True ([int]$r.json.quotaCount -eq 0) "nao-cota: quotaCount deveria seguir 0; got $($r.json.quotaCount)"

    # timeout: fake dorme além do -TimeoutSec (via invokeArgs.timeoutSec) -> adapter "excedeu...encerrado" -> timeout
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/timeout-1'; invokeArgs = @{ timeoutSec = 2 } }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'timeout') "timeout: deveria classificar timeout; got $($rv.state)"
    Assert-True ([int]$r.json.timeoutCount -ge 1) 'timeout: timeoutCount >= 1'
    Assert-True ($null -ne $rv.errorPath) 'timeout: deveria gravar .error.txt'

    # =======================================================================================
    # 8d) FALLBACK: ativacao auditavel, skip por sucesso e divergencia pre-dispatch
    # =======================================================================================
    $r = Invoke-Harness -Reviewers @(@{
            backend = 'opencode'; targetModelKey = 'openai/primary-ok'; invokeArgs = @{}
            fallbackChain = @(
                @{ backend = 'opencode'; targetModelKey = 'openai/fallback-skip'; invokeArgs = @{ backend = 'opencode'; model = 'openai/fallback-skip' } }
            )
        }) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    Assert-True (@($r.json.reviewers).Count -eq 2) 'fallback skip: deveria registrar primario + fallback.'
    $rv0 = Get-Reviewer $r.json 0
    $rv1 = Get-Reviewer $r.json 1
    Assert-True ($rv0.state -eq 'responded') 'fallback skip: primario deveria responder.'
    Assert-True ($rv1.state -eq 'skippedAfterSuccess') "fallback skip: fallback deveria ficar skippedAfterSuccess; got $($rv1.state)"
    Assert-True ($rv1.countsForDiversity -eq $false) 'fallback skip: skippedAfterSuccess nao conta diversidade.'
    Assert-True ($rv1.fallbackOf -eq 'openai/primary-ok') 'fallback skip: fallbackOf deveria apontar para primario.'

    $r = Invoke-Harness -Reviewers @(@{
            backend = 'opencode'; targetModelKey = 'openai/empty-primary'; invokeArgs = @{}
            fallbackChain = @(
                @{ backend = 'opencode'; targetModelKey = 'openai/fallback-ok'; invokeArgs = @{ backend = 'opencode'; model = 'openai/fallback-ok' } }
            )
        }) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    Assert-True (@($r.json.reviewers).Count -eq 2) 'fallback ativado: deveria registrar primario + fallback.'
    $rv0 = Get-Reviewer $r.json 0
    $rv1 = Get-Reviewer $r.json 1
    Assert-True ($rv0.state -eq 'error') 'fallback ativado: primario empty deveria virar error.'
    Assert-True ($rv1.state -eq 'responded') "fallback ativado: fallback deveria responder; got $($rv1.state)"
    Assert-True ($rv1.attemptRole -eq 'fallback') 'fallback ativado: attemptRole=fallback.'
    Assert-True ($rv1.activationReason -eq 'error') 'fallback ativado: activationReason deveria ser error.'
    Assert-True ($rv1.countsForDiversity -eq $true) 'fallback respondido deve contar diversidade.'

    # =======================================================================================
    # 8e) LEAK NATIVO (V40): orchestrator-native no harness -> erro defensivo + cadeia suprimida
    # =======================================================================================
    Set-Content -LiteralPath $concLog -Value '' -NoNewline -Encoding utf8
    $r = Invoke-Harness -Reviewers @(
        @{
            backend = 'orchestrator-native'
            targetModelKey = 'moonshot/kimi-k3-max'
            harnessModelId = 'kimi-k3-max'
            invokeArgs = @{}
            fallbackChain = @(
                @{ backend = 'opencode'; targetModelKey = 'openai/native-fallback-skip'; invokeArgs = @{ model = 'openai/native-fallback-skip' } }
            )
        },
        @{
            backend = 'opencode'
            targetModelKey = 'openai/parallel-after-native'
            invokeArgs = @{}
        }
    ) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    Assert-True (@($r.json.reviewers).Count -eq 3) 'leak nativo: deveria registrar primario nativo + fallback suprimido + revisor CLI paralelo.'
    $rvNative = Get-Reviewer $r.json 0
    Assert-True ($rvNative.state -eq 'error') "leak nativo: state deveria ser error; got $($rvNative.state)"
    Assert-True ($rvNative.reason -eq 'orchestrator-native-leaked-to-dispatch') "leak nativo: reason esperada orchestrator-native-leaked-to-dispatch; got '$($rvNative.reason)'"
    Assert-True ($rvNative.dispatchAttempted -eq $false) 'leak nativo: dispatchAttempted deveria ser false.'
    Assert-True ([int]$rvNative.attempts -eq 0) 'leak nativo: attempts deveria ser 0.'
    Assert-True ($rvNative.countsForDiversity -eq $false) 'leak nativo: nao conta diversidade.'
    Assert-True ([int]$rvNative.ledgerIndex -eq 0) 'leak nativo: ledgerIndex na criacao deveria ser 0.'
    Assert-True (@($rvNative.fallbackChain).Count -eq 0) 'leak nativo: fallbackChain do primario deveria estar vazia.'
    Assert-True (@($rvNative.suppressedFallbackChain).Count -eq 1) 'leak nativo: suppressedFallbackChain deveria preservar a cadeia original.'
    Assert-True ($rvNative.suppressedFallbackChain[0].targetModelKey -eq 'openai/native-fallback-skip') 'leak nativo: suppressedFallbackChain deveria conter o fallback original.'
    $rvNativeSkip = Get-ReviewerByTarget $r.json 'openai/native-fallback-skip'
    Assert-True ($null -ne $rvNativeSkip) 'leak nativo: deveria existir registro do fallback suprimido.'
    Assert-True ($rvNativeSkip.state -eq 'skippedByPolicy') "leak nativo: fallback deveria ser skippedByPolicy; got $($rvNativeSkip.state)"
    Assert-True ($rvNativeSkip.attemptRole -eq 'fallback') 'leak nativo: registro suprimido deveria ser attemptRole=fallback.'
    Assert-True ($rvNativeSkip.fallbackSuppressedReason -eq 'primary-native-leaked') "leak nativo: fallbackSuppressedReason esperado primary-native-leaked; got '$($rvNativeSkip.fallbackSuppressedReason)'"
    Assert-True ($rvNativeSkip.fallbackOf -eq 'moonshot/kimi-k3-max') 'leak nativo: fallbackOf deveria apontar para o primario nativo.'
    Assert-True ($rvNativeSkip.dispatchAttempted -eq $false) 'leak nativo: fallback suprimido nao deveria despachar.'
    $rvParallel = Get-ReviewerByTarget $r.json 'openai/parallel-after-native'
    Assert-True ($rvParallel.state -eq 'responded') "leak nativo: revisor CLI paralelo deveria responder; got $($rvParallel.state)"
    $logLinesLeak = @(Get-Content -LiteralPath $concLog -ErrorAction SilentlyContinue | Where-Object { $_ })
    $parallelEnters = @($logLinesLeak | Where-Object {
        $parts = @($_ -split "`t")
        $parts.Count -ge 4 -and $parts[1] -eq 'ENTER' -and $parts[3] -eq 'openai/parallel-after-native'
    }).Count
    $fallbackEnters = @($logLinesLeak | Where-Object {
        $parts = @($_ -split "`t")
        $parts.Count -ge 4 -and $parts[1] -eq 'ENTER' -and $parts[3] -eq 'openai/native-fallback-skip'
    }).Count
    Assert-True ($parallelEnters -eq 1) "leak nativo: revisor CLI paralelo deveria ser invocado uma vez; medido $parallelEnters"
    Assert-True ($fallbackEnters -eq 0) "leak nativo: fallback suprimido nao deveria invocar adapter; medido $fallbackEnters"

    $r = Invoke-Harness -Reviewers @(
        @{
            backend = 'orchestrator-native'
            targetModelKey = 'moonshot/kimi-k3-max'
            harnessModelId = 'kimi-k3-max'
            invokeArgs = @{}
        }
    ) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    Assert-True (@($r.json.reviewers).Count -eq 1) 'leak nativo sem fallback: deveria registrar so o primario.'
    $rvNativeOnly = Get-Reviewer $r.json 0
    Assert-True ($rvNativeOnly.reason -eq 'orchestrator-native-leaked-to-dispatch') 'leak nativo sem fallback: reason de leak esperada.'
    Assert-True (@($rvNativeOnly.suppressedFallbackChain).Count -eq 0) 'leak nativo sem fallback: suppressedFallbackChain deveria estar vazia.'

    $r = Invoke-Harness -Reviewers @(@{
            backend = 'opencode'; targetModelKey = 'openai/empty-primary-timeout-fallback'; invokeArgs = @{}
            fallbackChain = @(
                @{ backend = 'opencode'; targetModelKey = 'openai/timeout-fallback'; invokeArgs = @{ backend = 'opencode'; model = 'openai/timeout-fallback'; timeoutSec = 2 } }
            )
        }) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    Assert-True (@($r.json.reviewers).Count -eq 2) 'fallback timeout: deveria registrar primario + fallback.'
    $rv1 = Get-Reviewer $r.json 1
    Assert-True ($rv1.state -eq 'timeout') "fallback timeout: fallback deveria registrar timeout; got $($rv1.state)"
    Assert-True ($rv1.countsForDiversity -eq $false) 'fallback timeout nao deve contar diversidade.'

    $harnessText = Get-Content -LiteralPath $harness -Raw -Encoding utf8
    Assert-True ($harnessText -match 'Get-FallbackDispatcherTimeoutMs') 'fallback dispatcher: timeout do processo filho deve derivar do invokeArgs.timeoutSec.'
    $parserErrors = $null
    $tokens = $null
    $harnessAst = [System.Management.Automation.Language.Parser]::ParseFile($harness, [ref]$tokens, [ref]$parserErrors)
    Assert-True (@($parserErrors).Count -eq 0) "fallback dispatcher: harness deveria parsear sem erro; erros=$(@($parserErrors).Count)"
    $functionAsts = @($harnessAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))
    $getPropAst = @($functionAsts | Where-Object { $_.Name -eq 'Get-Prop' })[0]
    $timeoutAst = @($functionAsts | Where-Object { $_.Name -eq 'Get-FallbackDispatcherTimeoutMs' })[0]
    Assert-True ($null -ne $getPropAst -and $null -ne $timeoutAst) 'fallback dispatcher: funcoes Get-Prop/Get-FallbackDispatcherTimeoutMs deveriam existir.'
    $timeoutMapAssign = @($harnessAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $node.Left.Extent.Text.Trim() -eq '$AdapterDefaultTimeoutSec'
    }, $true))[0]
    Assert-True ($null -ne $timeoutMapAssign) 'fallback dispatcher: declaracao de $AdapterDefaultTimeoutSec deve existir no AST.'
    $timeoutProbe = @"
`$script:AdapterDefaultTimeoutSec = $($timeoutMapAssign.Right.Extent.Text)
$($getPropAst.Extent.Text)
$($timeoutAst.Extent.Text)
[pscustomobject]@{
    ClaudeDefault = Get-FallbackDispatcherTimeoutMs -Backend 'claude-code' -InvokeArgs ([pscustomobject]@{})
    OpenCodeDefault = Get-FallbackDispatcherTimeoutMs -Backend 'opencode' -InvokeArgs ([pscustomobject]@{})
    SmallExplicit = Get-FallbackDispatcherTimeoutMs -Backend 'claude-code' -InvokeArgs ([pscustomobject]@{ timeoutSec = 2 })
    InvalidClaude = Get-FallbackDispatcherTimeoutMs -Backend 'claude-code' -InvokeArgs ([pscustomobject]@{ timeoutSec = 'abc' })
}
"@
    $timeoutResult = & ([scriptblock]::Create($timeoutProbe))
    Assert-True ([int]$timeoutResult.ClaudeDefault -eq 420000) "fallback dispatcher: claude-code sem timeoutSec deve esperar 300s+120s; got $($timeoutResult.ClaudeDefault)"
    Assert-True ([int]$timeoutResult.InvalidClaude -eq 420000) "fallback dispatcher: claude-code com timeoutSec invalido deve cair no default 300s+120s; got $($timeoutResult.InvalidClaude)"
    Assert-True ([int]$timeoutResult.OpenCodeDefault -eq 2520000) "fallback dispatcher: opencode sem timeoutSec deve esperar 2*1200s+120s; got $($timeoutResult.OpenCodeDefault)"
    Assert-True ([int]$timeoutResult.SmallExplicit -eq 180000) "fallback dispatcher: timeoutSec pequeno deve manter piso conservador de 180s; got $($timeoutResult.SmallExplicit)"
    Assert-True ($harnessText -match "Get-FallbackDispatcherTimeoutMs\s+-Backend") 'fallback dispatcher: chamada real deve informar o backend para escolher o default correto.'
    Assert-True ($harnessText -match "extraSplat\.ContainsKey\('TimeoutSec'\)") 'painel: TimeoutSec do AdapterDefaultTimeoutSec deve ser injetado no splat quando invokeArgs omite timeoutSec'
    Assert-True ($harnessText -match "backend -in @\('codex', 'opencode'\)") 'painel: injecao TimeoutSec restrita a codex/opencode'
    Assert-True ($harnessText -match 'invokeArgs\.timeoutSec invalido') 'painel: timeoutSec invalido deve virar error local (GAP-2)'
    Assert-True ($harnessText -match 'recoveredAfterTimeout') 'painel: deve projetar recoveredAfterTimeout (GAP-3)'
    Assert-True ($harnessText -notmatch 'WaitForExit\(180000\)') 'fallback dispatcher: nao pode haver timeout fixo de 180000ms no processo filho.'
    Assert-True ($harnessText -match 'Get-CurrentPowerShellExecutable') 'fallback dispatcher: processo filho deve usar o executavel PowerShell atual/validado, nao depender de pwsh cru no PATH.'
    Assert-True ($harnessText -notmatch "Start-Process\s+-FilePath\s+'pwsh'") 'fallback dispatcher: nao pode resolver pwsh cru pelo PATH.'
    Assert-True ($harnessText -notmatch "return\s+'pwsh'") 'fallback dispatcher: nao pode ter fallback silencioso para pwsh cru no PATH.'

    # =======================================================================================
    # AST Guard: Paridade estrita de chaves entre os 5 mapas do dispatcher, ValidateSet e preferences
    # =======================================================================================
    function Get-AstHashtableKeys {
        param($Ast, [string]$VarName)
        $assign = @($Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text.Trim() -eq "`$$VarName"
        }, $true))[0]
        Assert-True ($null -ne $assign) "AST Guard: declaracao de `$$VarName nao encontrada no AST"
        $ht = if ($assign.Right -is [System.Management.Automation.Language.HashtableAst]) {
            $assign.Right
        } else {
            @($assign.Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.HashtableAst] }, $true))[0]
        }
        Assert-True ($null -ne $ht) "AST Guard: HashtableAst nao encontrada para `$$VarName"
        $keys = [System.Collections.Generic.List[string]]::new()
        foreach ($pair in $ht.KeyValuePairs) {
            $keys.Add($pair.Item1.Extent.Text.Trim("'", '"', ' '))
        }
        return @($keys)
    }

    function Get-AstBackendValidateSet {
        param([string]$FilePath)
        $pErrors = $null
        $pTokens = $null
        $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$pTokens, [ref]$pErrors)
        Assert-True (@($pErrors).Count -eq 0) "AST Guard: erro ao parsear $FilePath"
        $paramAst = @($fileAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.ParameterAst] -and
            $node.Name.VariablePath.UserPath -eq 'Backend'
        }, $true))[0]
        Assert-True ($null -ne $paramAst) "AST Guard: parametro Backend nao encontrado em $FilePath"
        $valSetAttr = @($paramAst.Attributes | Where-Object {
            $_.TypeName.FullName -eq 'ValidateSet' -or $_.TypeName.Name -eq 'ValidateSet'
        })[0]
        Assert-True ($null -ne $valSetAttr) "AST Guard: atributo ValidateSet nao encontrado no parametro Backend em $FilePath"
        $vals = [System.Collections.Generic.List[string]]::new()
        foreach ($arg in $valSetAttr.PositionalArguments) {
            $vals.Add($arg.Extent.Text.Trim("'", '"', ' '))
        }
        return @($vals)
    }

    function Get-AstArrayAssignmentValues {
        param([string]$FilePath, [string]$VarName)
        $pErrors = $null
        $pTokens = $null
        $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$pTokens, [ref]$pErrors)
        Assert-True (@($pErrors).Count -eq 0) "AST Guard: erro ao parsear $FilePath"
        $assign = @($fileAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text.Trim() -eq "`$$VarName"
        }, $true))[0]
        Assert-True ($null -ne $assign) "AST Guard: declaracao de `$$VarName nao encontrada em $FilePath"
        $vals = [System.Collections.Generic.List[string]]::new()
        $elements = @($assign.Right.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
        }, $true))
        foreach ($el in $elements) {
            $vals.Add($el.Value)
        }
        return @($vals)
    }

    $mapAdapterScriptKeys = @(Get-AstHashtableKeys $harnessAst 'AdapterScript')
    $canonicalSorted = @($mapAdapterScriptKeys | Sort-Object)
    Assert-True ($canonicalSorted.Count -eq 6) "AST Guard: esperado exatamente 6 backends canonicos; got $($canonicalSorted.Count)"

    $authValidateSet = @(Get-AstBackendValidateSet (Join-Path $scriptsDir 'Resolve-LlmDelegateAuthorization.ps1'))
    $authDispatchOnly = @($authValidateSet | Where-Object { $_ -ne 'orchestrator-native' } | Sort-Object)

    $collectionsToCompare = [ordered]@{
        'Invoke-LlmDelegatePanelDispatch.ps1 ($ExeParam)'                = @(Get-AstHashtableKeys $harnessAst 'ExeParam' | Sort-Object)
        'Invoke-LlmDelegatePanelDispatch.ps1 ($ContentionKeys)'          = @(Get-AstHashtableKeys $harnessAst 'ContentionKeys' | Sort-Object)
        'Invoke-LlmDelegatePanelDispatch.ps1 ($AdapterDefaultTimeoutSec)'= @(Get-AstHashtableKeys $harnessAst 'AdapterDefaultTimeoutSec' | Sort-Object)
        'Invoke-LlmDelegatePanelDispatch.ps1 ($AdapterCdCapable)'        = @(Get-AstHashtableKeys $harnessAst 'AdapterCdCapable' | Sort-Object)
        'Resolve-LlmDelegateAuthorization.ps1 (ValidateSet -Backend, sem orchestrator-native)' = $authDispatchOnly
        'Set-LlmDelegatePreferredReviewers.ps1 ($allowedDispatchBackends)' = @(Get-AstArrayAssignmentValues (Join-Path $scriptsDir 'Set-LlmDelegatePreferredReviewers.ps1') 'allowedDispatchBackends' | Sort-Object)
    }
    Assert-True ($authValidateSet -contains 'orchestrator-native') 'AST Guard: ValidateSet de Authorization deve incluir orchestrator-native'
    foreach ($entry in $collectionsToCompare.GetEnumerator()) {
        $name = $entry.Key
        $keys = $entry.Value
        Assert-True ($keys.Count -eq $canonicalSorted.Count) "AST Guard: contagem de chaves divergente em $name ($($keys.Count) vs $($canonicalSorted.Count))"
        for ($i = 0; $i -lt $canonicalSorted.Count; $i++) {
            Assert-True ($keys[$i] -eq $canonicalSorted[$i]) "AST Guard: chave divergente na posicao $i em $name ('$($keys[$i])' vs '$($canonicalSorted[$i])')"
        }
    }

    $localityPascalTable = [ordered]@{
        'opencode'    = 'OpenCode'
        'codex'       = 'Codex'
        'claude-code' = 'ClaudeCode'
        'copilot'     = 'Copilot'
        'gemini'      = 'Gemini'
        'antigravity' = 'Antigravity'
    }
    $tableKeysSorted = @($localityPascalTable.Keys | Sort-Object)
    Assert-True ($tableKeysSorted.Count -eq $canonicalSorted.Count) "AST Guard: tabela PascalCase de localidade deve conter $($canonicalSorted.Count) entradas; got $($tableKeysSorted.Count)"
    for ($i = 0; $i -lt $canonicalSorted.Count; $i++) {
        Assert-True ($tableKeysSorted[$i] -eq $canonicalSorted[$i]) "AST Guard: tabela PascalCase chave divergente na posicao $i ('$($tableKeysSorted[$i])' vs '$($canonicalSorted[$i])')"
    }
    foreach ($b in $localityPascalTable.Keys) {
        $pascal = $localityPascalTable[$b]
        $resolverScript = Join-Path $scriptsDir "Resolve-${pascal}ModelLocality.ps1"
        $selfTestScript = Join-Path $scriptsDir "Test-${pascal}ModelLocalitySelfTest.ps1"
        Assert-True (Test-Path -LiteralPath $resolverScript -PathType Leaf) "AST Guard: script de localidade $resolverScript nao encontrado"
        Assert-True (Test-Path -LiteralPath $selfTestScript -PathType Leaf) "AST Guard: self-test de localidade $selfTestScript nao encontrado"
    }
    $nativeLocality = Join-Path $scriptsDir 'Resolve-OrchestratorNativeModelLocality.ps1'
    Assert-True (Test-Path -LiteralPath $nativeLocality -PathType Leaf) "AST Guard: script de localidade $nativeLocality nao encontrado"

    Set-Content -LiteralPath $concLog -Value '' -NoNewline -Encoding utf8
    $r = Invoke-Harness -Reviewers @(@{
            backend = 'opencode'; targetModelKey = 'openai/bad-primary'; invokeArgs = @{ backend = 'opencode'; model = 'openai/bad-primary' }
            fallbackChain = @(
                @{ backend = 'opencode'; targetModelKey = 'openai/fb-0'; invokeArgs = @{ backend = 'opencode'; model = 'openai/fb-0' } },
                @{ backend = 'codex'; targetModelKey = 'openai/fb-1'; invokeArgs = @{ backend = 'opencode'; model = 'gpt-5.5' } }
            )
        }) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }
    $rv0 = Get-Reviewer $r.json 0
    Assert-True ($rv0.state -eq 'error') 'fallback divergente: deveria falhar em pre-dispatch.'
    Assert-True ([string]$rv0.reason -match 'invokeArgs.backend') 'fallback divergente: reason deveria citar invokeArgs.backend.'
    $logAfterBad = @(Get-Content -LiteralPath $concLog -ErrorAction SilentlyContinue | Where-Object { $_ })
    $badCalls = @($logAfterBad | Where-Object { $_ -match 'bad-primary|fb-0|fb-1' })
    Assert-True ($badCalls.Count -eq 0) "fallback divergente: fake executor nao deveria ser chamado para a entrada invalida; chamadas=[$($badCalls -join ' | ')]"

    # =======================================================================================
    # 8c) DESPACHO REAL de claude-code / copilot / gemini / antigravity (modelo, cwd e recibo)
    # =======================================================================================
    $r = Invoke-Harness -Reviewers @(
        @{ backend = 'claude-code'; invokeArgs = @{ model = 'claude-opus-4-8' } },
        @{ backend = 'copilot';     invokeArgs = @{ model = 'gpt-5-mini' } },
        @{ backend = 'gemini';      invokeArgs = @{ model = 'gemini-3-flash-preview' } },
        @{ backend = 'antigravity'; invokeArgs = @{ model = 'gemini-3.6-flash-high' } }
    ) -Sensitivity 'public' -Extra @{ Cd = $tmp }
    $tmpFwd = $tmp.Replace('\', '/')

    $rvCl = Get-Reviewer $r.json 0
    Assert-True ($rvCl.state -eq 'responded') "claude-code despacho: esperado responded; got $($rvCl.state)"
    Assert-True ($rvCl.sidecarAccepted -eq $true) 'claude-code despacho: sidecar deveria ser aceito.'
    Assert-True ($rvCl.resultAccepted -eq $true) 'claude-code despacho: resultAccepted=true esperado.'
    Assert-True ($rvCl.technicalStatus -eq 'completed') 'claude-code despacho: technicalStatus completed esperado.'
    Assert-True (Test-Path -LiteralPath ([string]$rvCl.sidecarPath) -PathType Leaf) 'claude-code despacho: sidecarPath deveria existir.'
    $sidecarCl = Get-Content -LiteralPath ([string]$rvCl.sidecarPath) -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$rvCl.acceptedFinalTextSha256)) 'claude-code despacho: acceptedFinalTextSha256 deveria ser preservado no reviewer record.'
    Assert-True ($rvCl.acceptedFinalTextSha256 -eq $sidecarCl.acceptedFinalTextSha256) 'claude-code despacho: acceptedFinalTextSha256 do reviewer deveria casar com sidecar.'
    Assert-True ([int]$rvCl.acceptedFinalTextBytes -eq [int]$sidecarCl.acceptedFinalTextBytes) 'claude-code despacho: acceptedFinalTextBytes do reviewer deveria casar com sidecar.'
    $tCl = Get-Content -LiteralPath $rvCl.verdictPath -Raw -Encoding utf8
    Assert-True ($tCl -match 'model=claude-opus-4-8') 'claude-code despacho: -Model deveria chegar ao adapter'
    Assert-True ($tCl -match [regex]::Escape($tmp)) 'claude-code despacho: -Cd deveria virar o WorkingDirectory (cwd)'
    Assert-True ([int]$r.json.reviewersDispatchAttempted -eq 4) 'contadores v2: reviewersDispatchAttempted=4 esperado.'
    Assert-True ([int]$r.json.reviewersProcessCreated -eq 1) 'contadores v2: apenas Claude async declara processCreated=true.'
    Assert-True ([int]$r.json.processCreatedUnknownCount -eq 3) 'contadores v2: copilot/gemini/antigravity ficam processCreated desconhecido.'
    Assert-True ([int]$r.json.sidecarAcceptedCount -eq 1) 'contadores v2: sidecarAcceptedCount=1 esperado.'

    $rvCp = Get-Reviewer $r.json 1
    Assert-True ($rvCp.state -eq 'responded') "copilot despacho: esperado responded; got $($rvCp.state)"
    $tCp = Get-Content -LiteralPath $rvCp.verdictPath -Raw -Encoding utf8
    Assert-True ($tCp -match 'model=gpt-5-mini') 'copilot despacho: -Model deveria chegar ao adapter'
    Assert-True ($tCp -match [regex]::Escape($tmpFwd)) 'copilot despacho: -Cd deveria virar o WorkingDirectory (cwd)'

    $rvGm = Get-Reviewer $r.json 2
    Assert-True ($rvGm.state -eq 'responded') "gemini despacho: esperado responded; got $($rvGm.state)"
    $tGm = Get-Content -LiteralPath $rvGm.verdictPath -Raw -Encoding utf8
    Assert-True ($tGm -match 'model=gemini-3-flash-preview') 'gemini despacho: -Model deveria chegar ao adapter'
    Assert-True ($tGm -match [regex]::Escape($tmpFwd)) 'gemini despacho: -Cd deveria virar o WorkingDirectory (cwd)'

    $rvAg = Get-Reviewer $r.json 3
    Assert-True ($rvAg.state -eq 'responded') "antigravity despacho: esperado responded; got $($rvAg.state)"
    $tAg = Get-Content -LiteralPath $rvAg.verdictPath -Raw -Encoding utf8
    Assert-True ($tAg -match 'model=gemini-3.6-flash-high') 'antigravity despacho: -Model deveria chegar ao adapter'
    Assert-True ($tAg -notmatch [regex]::Escape($tmpFwd)) 'antigravity public-review nao deve herdar -Cd do dispatcher'
    Assert-True ($rvAg.publicReviewProfile -eq 'public-review') 'antigravity despacho: perfil fixo public-review esperado'
    Assert-True ($rvAg.cliVersion -eq '1.1.19' -and $rvAg.cliVersionMatchesBaseline) 'antigravity despacho: recibo deve registrar cliVersion'
    Assert-True ($rvAg.cleanupStatus -eq 'clean' -and $rvAg.keyringIsolation -eq 'not-isolated-global-keyring') 'antigravity despacho: limpeza clean e limite do keyring registrados'
    Assert-True (Test-Path -LiteralPath ([string]$rvAg.adapterReceiptPath) -PathType Leaf) 'antigravity despacho: recibo tecnico deve existir no ledger'

    # public-review nunca recebe kb-sensitive: o gate roda primeiro e o adapter nunca e invocado.
    $agyCallLog = Join-Path $tmp 'antigravity.calls.log'
    $agyCallsBefore = if (Test-Path $agyCallLog) { @(Get-Content $agyCallLog).Count } else { 0 }
    $r = Invoke-Harness -Reviewers @(@{
        backend = 'antigravity'; targetModelKey = 'antigravity/gemini-3.6-flash-high'
        invokeArgs = @{ model = 'gemini-3.6-flash-high' }
    }) -Sensitivity 'kb-sensitive'
    $rvAgGateAsk = Get-Reviewer $r.json 0
    $agyCallsAfterGateAsk = if (Test-Path $agyCallLog) { @(Get-Content $agyCallLog).Count } else { 0 }
    Assert-True ($rvAgGateAsk.gateVerdict -eq 'ask' -and $rvAgGateAsk.state -eq 'gateAsk') 'antigravity kb-sensitive sem politica preserva gateAsk do gate'
    Assert-True (-not $rvAgGateAsk.dispatchAttempted -and $agyCallsAfterGateAsk -eq $agyCallsBefore) 'gateAsk de antigravity bloqueia antes do adapter'

    # Com politica duravel allow, a postura fixa ainda recusa kb-sensitive via refusedSensitivity.
    $r = Invoke-Harness -Reviewers @(@{
        backend = 'antigravity'; targetModelKey = 'antigravity/gemini-3.6-flash-high'
        invokeArgs = @{ model = 'gemini-3.6-flash-high' }
    }) -Sensitivity 'kb-sensitive' -Extra @{ PolicyPath = $polAntigravity }
    $rvAgSensitive = Get-Reviewer $r.json 0
    $agyCallsAfter = if (Test-Path $agyCallLog) { @(Get-Content $agyCallLog).Count } else { 0 }
    Assert-True ($rvAgSensitive.gateVerdict -eq 'allow') 'antigravity kb-sensitive: gate deve continuar dono da confidencialidade e rodar antes da recusa do perfil'
    Assert-True ($rvAgSensitive.state -eq 'unavailable' -and $rvAgSensitive.reason -eq 'refusedSensitivity') 'antigravity kb-sensitive usa unavailable + refusedSensitivity'
    Assert-True (-not $rvAgSensitive.dispatchAttempted -and $agyCallsAfter -eq $agyCallsBefore) 'gate de perfil bloqueia kb-sensitive antes do adapter'

    $r = Invoke-Harness -Reviewers @(@{
            backend = 'claude-code'
            targetModelKey = 'anthropic/claude-sensitive-ledger'
            invokeArgs = @{ model = 'claude-sensitive-ledger' }
        }) -Sensitivity 'kb-sensitive' -Extra @{ Cd = $tmp; PolicyPath = $polAnthropic }
    $rvClSensitive = Get-Reviewer $r.json 0
    Assert-True ($rvClSensitive.state -eq 'responded') "claude-code kb-sensitive ledger: esperado responded; got $($rvClSensitive.state)"
    Assert-True ($rvClSensitive.sidecarAccepted -eq $true) 'claude-code kb-sensitive ledger: sidecar deveria ser aceito.'
    Assert-True ($rvClSensitive.resultAccepted -eq $true) 'claude-code kb-sensitive ledger: resultAccepted=true esperado.'
    Assert-True (Test-Path -LiteralPath ([string]$rvClSensitive.verdictPath) -PathType Leaf) 'claude-code kb-sensitive ledger: .verdict.txt deveria existir.'
    $rawLedgerFiles = @(Get-ChildItem -LiteralPath $r.ledgerDir -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*.stream.jsonl' -or $_.Name -like '*.stderr.txt' })
    $rawLedgerFileNames = @($rawLedgerFiles | ForEach-Object { $_.Name })
    Assert-True ($rawLedgerFiles.Count -eq 0) ("claude-code kb-sensitive ledger: stream/stderr brutos nao deveriam permanecer no ledger; ficaram: {0}" -f ($rawLedgerFileNames -join ', '))
    $sensitiveSidecar = Get-Content -LiteralPath ([string]$rvClSensitive.sidecarPath) -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ($sensitiveSidecar.retentionMode -eq 'kb-sensitive') 'claude-code kb-sensitive ledger: retentionMode deveria ser kb-sensitive.'
    Assert-True ($sensitiveSidecar.retentionCleanupFailed -eq $false) 'claude-code kb-sensitive ledger: limpeza de stream/stderr deveria completar.'
    Assert-True ($null -eq $sensitiveSidecar.streamSha256) 'claude-code kb-sensitive ledger: streamSha256 deve ser omitido/null.'
    Assert-True ($null -eq $sensitiveSidecar.stderrSha256) 'claude-code kb-sensitive ledger: stderrSha256 deve ser omitido/null.'

    # Claude Code workspace nao confiavel -> unavailable, para permitir fallback em painel.
    $r = Invoke-Harness -Reviewers @(@{ backend = 'claude-code'; invokeArgs = @{ model = 'claude-untrusted-workspace' } }) `
        -Sensitivity 'public' -Extra @{ Cd = $tmp }
    $rvClUntrusted = Get-Reviewer $r.json 0
    Assert-True ($rvClUntrusted.state -eq 'unavailable') "claude-code workspace-not-trusted: esperado unavailable; got $($rvClUntrusted.state)"
    Assert-True ([string]$rvClUntrusted.reason -match 'workspace-not-trusted') 'claude-code workspace-not-trusted: reason deveria citar codigo canonico'

    # workspace-not-trusted do titular deve ativar fallback como qualquer unavailable tecnico.
    $r = Invoke-Harness -Reviewers @(@{
            backend = 'claude-code'; targetModelKey = 'anthropic/claude-opus-4-8'; invokeArgs = @{ model = 'claude-untrusted-workspace' }
            fallbackChain = @(
                @{ backend = 'opencode'; targetModelKey = 'openai/fallback-after-unavailable'; invokeArgs = @{ backend = 'opencode'; model = 'openai/fallback-after-unavailable' } }
            )
        }) -Sensitivity 'public' -Extra @{ Cd = $tmp; OpenCodeConfigPath = $ocCfg }
    Assert-True (@($r.json.reviewers).Count -eq 2) 'fallback workspace-not-trusted: deveria registrar titular + fallback.'
    $rvClUntrusted = Get-Reviewer $r.json 0
    $rvFallbackUntrusted = Get-Reviewer $r.json 1
    Assert-True ($rvClUntrusted.state -eq 'unavailable') "fallback workspace-not-trusted: titular deveria ficar unavailable; got $($rvClUntrusted.state)"
    Assert-True ($rvFallbackUntrusted.state -eq 'responded') "fallback workspace-not-trusted: fallback deveria responder; got $($rvFallbackUntrusted.state)"
    Assert-True ($rvFallbackUntrusted.attemptRole -eq 'fallback') 'fallback workspace-not-trusted: attemptRole=fallback.'
    Assert-True ($rvFallbackUntrusted.activationReason -eq 'unavailable') 'fallback workspace-not-trusted: activationReason deveria ser unavailable.'
    Assert-True ($rvFallbackUntrusted.countsForDiversity -eq $true) 'fallback workspace-not-trusted respondido deve contar diversidade.'

    # =======================================================================================
    # 9) -Cd: precedência (explícito / cwd / ParallelKbRoot) + fail-closed
    # =======================================================================================
    # explícito (public): -Cd vence -> fake-codex escreve CD=<explícito>
    $explicitCd = $tmp
    $r = Invoke-Harness -Reviewers @(@{ backend = 'codex'; invokeArgs = @{ model = 'gpt-5.5' } }) `
        -Sensitivity 'public' -Extra @{ CodexConfigPath = $cxCfg; Cd = $explicitCd }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'responded') "Cd explícito: deveria despachar; got $($rv.state)"
    $vtext = Get-Content -LiteralPath $rv.verdictPath -Raw -Encoding utf8
    Assert-True ($vtext -match ([regex]::Escape("CD=$explicitCd"))) "Cd explícito: o fake deveria receber -C $explicitCd; got '$vtext'"

    # kb-sensitive + ParallelKbRoot + politica allow -> -Cd = ParallelKbRoot
    $kbRoot = Join-Path $tmp 'kb-root'
    New-Item -ItemType Directory -Path $kbRoot -Force | Out-Null
    Copy-Item -LiteralPath $pol -Destination (Join-Path $kbRoot 'llm-delegation-policy.json')
    $r = Invoke-Harness -Reviewers @(@{ backend = 'codex'; invokeArgs = @{ model = 'gpt-5.5' } }) `
        -Sensitivity 'kb-sensitive' -Extra @{ CodexConfigPath = $cxCfg; ParallelKbRoot = $kbRoot }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.gateVerdict -eq 'allow') "Cd/ParallelKbRoot: gate deveria allow pela politica openai/*; got '$($rv.gateVerdict)'"
    Assert-True ($rv.state -eq 'responded') 'Cd/ParallelKbRoot: deveria despachar'
    $vtext = Get-Content -LiteralPath $rv.verdictPath -Raw -Encoding utf8
    Assert-True ($vtext -match ([regex]::Escape("CD=$kbRoot"))) "Cd/ParallelKbRoot: o fake deveria receber -C $kbRoot; got '$vtext'"

    # fail-closed: kb-sensitive + allow (politica) + sem -Cd + sem -ParallelKbRoot -> error
    $r = Invoke-Harness -Reviewers @(@{ backend = 'codex'; invokeArgs = @{ model = 'gpt-5.5' } }) `
        -Sensitivity 'kb-sensitive' -Extra @{ CodexConfigPath = $cxCfg; PolicyPath = $pol }
    $rv = Get-Reviewer $r.json 0
    Assert-True ($rv.state -eq 'error') "Cd fail-closed: kb-sensitive allow sem -Cd/-ParallelKbRoot deveria dar error; got $($rv.state)"
    Assert-True ($rv.reason -match 'fail-closed') 'Cd fail-closed: reason deveria citar fail-closed'

    # =======================================================================================
    # 10) CONTRATO DE SAÍDA
    # =======================================================================================
    $r = Invoke-Harness -Reviewers @(
        @{ backend = 'opencode'; targetModelKey = 'openai/contract'; invokeArgs = @{} },
        @{ backend = 'claude-code'; invokeArgs = @{} }   # sem model -> error, targetModelKey null
    ) -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg }

    # stdout = exatamente 1 linha
    $stdoutTrim = $r.stdout.TrimEnd("`r", "`n")
    Assert-True (@($stdoutTrim -split "`n").Count -eq 1) 'contrato: stdout deveria ter exatamente 1 linha'
    Assert-True ($r.json.Kind -eq 'xpz-llm-panel-dispatch-result') 'contrato: Kind PascalCase'
    Assert-True ([int]$r.json.SchemaVersion -eq 3) 'contrato: SchemaVersion=3 PascalCase'
    # state subset
    $validStates = @('responded', 'error', 'quota', 'unavailable', 'timeout', 'gateAsk', 'gateDeny', 'skippedAfterSuccess', 'skippedByPolicy', 'notAttempted')
    foreach ($rev in $r.json.reviewers) { Assert-True ($validStates -contains $rev.state) "contrato: state '$($rev.state)' deveria estar no subset valido" }
    # targetModelKey vazio -> null (claude-code sem model)
    $rvClaude = Get-Reviewer $r.json 1
    Assert-True ($null -eq $rvClaude.targetModelKey) 'contrato: targetModelKey vazio deveria virar null'
    # slug Windows-safe (sem / : etc.)
    $rvOc = Get-Reviewer $r.json 0
    $base = Split-Path -Leaf $rvOc.verdictPath
    Assert-True ($base -match '^[0-9A-Za-z._-]+\.verdict\.txt$') "contrato: nome de ledger deveria ser Windows-safe; got '$base'"

    # RoundId ausente -> guid
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/x'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg } -NoRoundId
    Assert-True ($r.json.roundId -match '^[0-9a-f]{32}$') "RoundId ausente: deveria gerar guid 'N'; got '$($r.json.roundId)'"

    # ManuscriptText -> preparador transacional antes do despacho
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/texto-inline'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg } -UseManuscriptText `
        -ManuscriptText 'manuscrito-inline'
    Assert-True ($r.exit -eq 0) 'ManuscriptText: exit 0 esperado'
    Assert-True ($r.json.success -eq $true) 'ManuscriptText: success=true'
    Assert-True ($r.json.roundStarted -eq $true) 'ManuscriptText: roundStarted=true'
    Assert-True ($r.json.dispatchStarted -eq $true) 'ManuscriptText: dispatchStarted=true'
    Assert-True ([int]$r.json.reviewersDispatched -eq 1) 'ManuscriptText: reviewersDispatched=1'
    Assert-True ($null -eq $r.json.preparationError) 'ManuscriptText: preparationError=null'
    Assert-True ((Get-Reviewer $r.json 0).state -eq 'responded') 'ManuscriptText: revisor deveria responder'
    $prepManifest = Join-Path $ledgerRoot $r.roundId 'preparation-manifest.json'
    Assert-True (Test-Path -LiteralPath $prepManifest -PathType Leaf) 'ManuscriptText: preparation-manifest.json deveria existir'

    # ManuscriptText grande -> bloqueio estruturado antes de preparar/despachar
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/texto-grande'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg } -UseManuscriptText `
        -ManuscriptText ('x' * 30001)
    Assert-True ($r.exit -eq 1) 'ManuscriptText grande: exit 1 esperado'
    Assert-True ($r.json.Kind -eq 'xpz-llm-panel-dispatch-result') 'ManuscriptText grande: Kind do dispatcher esperado'
    Assert-True ([int]$r.json.SchemaVersion -eq 3) 'ManuscriptText grande: SchemaVersion=3'
    Assert-True ($r.json.roundStarted -eq $false) 'ManuscriptText grande: roundStarted=false'
    Assert-True ($r.json.dispatchStarted -eq $false) 'ManuscriptText grande: dispatchStarted=false'
    Assert-True ([int]$r.json.reviewersDispatched -eq 0) 'ManuscriptText grande: zero despachos'
    Assert-True ($r.json.preparationError.failureCode -eq 'manuscript-text-too-large') 'ManuscriptText grande: failureCode manuscript-text-too-large'

    # Origem ausente/ambigua -> bloqueio estruturado antes de preparar/despachar
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/origem-ausente'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg } -OmitManuscriptSource
    Assert-True ($r.exit -eq 1) 'Origem ausente: exit 1 esperado'
    Assert-True ($r.json.Kind -eq 'xpz-llm-panel-dispatch-result') 'Origem ausente: Kind do dispatcher esperado'
    Assert-True ([int]$r.json.SchemaVersion -eq 3) 'Origem ausente: SchemaVersion=3'
    Assert-True ($r.json.roundStarted -eq $false) 'Origem ausente: roundStarted=false'
    Assert-True ($r.json.dispatchStarted -eq $false) 'Origem ausente: dispatchStarted=false'
    Assert-True ([int]$r.json.reviewersDispatched -eq 0) 'Origem ausente: zero despachos'
    Assert-True ($r.json.preparationError.failureCode -eq 'manuscript-source-missing') 'Origem ausente: failureCode manuscript-source-missing'

    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/origem-ambigua'; invokeArgs = @{} }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg } -BothManuscriptSources -ManuscriptText 'manuscrito-inline'
    Assert-True ($r.exit -eq 1) 'Origem ambigua: exit 1 esperado'
    Assert-True ($r.json.Kind -eq 'xpz-llm-panel-dispatch-result') 'Origem ambigua: Kind do dispatcher esperado'
    Assert-True ([int]$r.json.SchemaVersion -eq 3) 'Origem ambigua: SchemaVersion=3'
    Assert-True ($r.json.roundStarted -eq $false) 'Origem ambigua: roundStarted=false'
    Assert-True ($r.json.dispatchStarted -eq $false) 'Origem ambigua: dispatchStarted=false'
    Assert-True ([int]$r.json.reviewersDispatched -eq 0) 'Origem ambigua: zero despachos'
    Assert-True ($r.json.preparationError.failureCode -eq 'manuscript-source-ambiguous') 'Origem ambigua: failureCode manuscript-source-ambiguous'

    # Falha de preparacao -> summary proprio do dispatcher, sem iniciar rodada/despacho
    $r = Invoke-Harness -Reviewers @(@{ backend = 'opencode'; targetModelKey = 'openai/texto-invalido'; invokeArgs = 'nao-objeto' }) `
        -Sensitivity 'public' -Extra @{ OpenCodeConfigPath = $ocCfg } -UseManuscriptText -ManuscriptText 'manuscrito-inline'
    Assert-True ($r.exit -eq 1) 'ManuscriptText invalido: exit 1 esperado'
    Assert-True ($r.json.Kind -eq 'xpz-llm-panel-dispatch-result') 'ManuscriptText invalido: Kind do dispatcher esperado'
    Assert-True ([int]$r.json.SchemaVersion -eq 3) 'ManuscriptText invalido: SchemaVersion=3'
    Assert-True ($r.json.roundStarted -eq $false) 'ManuscriptText invalido: roundStarted=false'
    Assert-True ($r.json.dispatchStarted -eq $false) 'ManuscriptText invalido: dispatchStarted=false'
    Assert-True ([int]$r.json.reviewersDispatched -eq 0) 'ManuscriptText invalido: zero despachos'
    Assert-True ($r.json.preparationError.failureCode -eq 'reviewer-invalid-invokeArgs') 'ManuscriptText invalido: failureCode reviewer-invalid-invokeArgs'

    # ReviewersJson INLINE (não-arquivo) + INVÁLIDO — testados em processo IN-PROCESS lendo o ledger
    $ridInline = [guid]::NewGuid().ToString('N')
    $inlineJson = '[{"backend":"opencode","targetModelKey":"openai/inline","invokeArgs":{}}]'
    & $harness -ManuscriptPath $manuscript -ReviewersJson $inlineJson -PayloadSensitivity public `
        -RoundId $ridInline -TempDir $ledgerRoot -BackendExeMap $exeMapFile -OpenCodeConfigPath $ocCfg 1> $null
    $inlineSummary = Join-Path $ledgerRoot $ridInline 'panel-summary.json'
    Assert-True (Test-Path -LiteralPath $inlineSummary -PathType Leaf) 'ReviewersJson inline: deveria gravar panel-summary.json'
    $inlineObj = Get-Content -LiteralPath $inlineSummary -Raw -Encoding utf8 | ConvertFrom-Json
    Assert-True ((Get-Reviewer $inlineObj 0).state -eq 'responded') 'ReviewersJson inline: revisor deveria responder'

    $threw = $false
    try { & $harness -ManuscriptPath $manuscript -ReviewersJson '{lixo-invalido' -PayloadSensitivity public -TempDir $ledgerRoot 1> $null 2> $null }
    catch { $threw = $true }
    Assert-True $threw 'ReviewersJson inválido: deveria lançar (BLOCK)'

    Write-Output 'OK: Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1'
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    Remove-Item Env:\PANEL_FAKE_LOG -ErrorAction SilentlyContinue
    Remove-Item Env:\PANEL_FAKE_MUTEX -ErrorAction SilentlyContinue
    Remove-Item Env:\PANEL_FAKE_OC_VERSION -ErrorAction SilentlyContinue
    if ($null -eq $script:prevCodexDisableKeepDays) {
        Remove-Item Env:\XPZ_CODEX_DISABLE_KEEPDAYS -ErrorAction SilentlyContinue
    } else {
        $env:XPZ_CODEX_DISABLE_KEEPDAYS = $script:prevCodexDisableKeepDays
    }
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
