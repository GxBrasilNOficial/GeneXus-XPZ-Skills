#requires -Version 7.4
<#
.SYNOPSIS
    Harness MECANICO de despacho+coleta de um painel de revisores da skill xpz-llm-delegate:
    dispara cada revisor ao backend LLM via os adapters Invoke-*.ps1, coleta os vereditos num
    ledger por estado e emite um panel-summary.json de maquina no stdout (uma linha).
.DESCRIPTION
    Implementa o «harness de disparo do painel» previsto como futuro em 15-revisao-por-pares.md.
    E estritamente MECANICO: NAO injeta subagente nativo, NAO calcula piso de diversidade, NAO faz
    closeout, triagem, convergencia, autorizacao de 'ask', recibo humano, reclassificacao semantica
    responded->noResponse (off-task), single-flight nem confinamento do opencode. Tudo isso e do
    ORQUESTRADOR (fora deste script). Ver 15-revisao-por-pares.md e xpz-llm-delegate/SKILL.md.

    Por revisor (sequencial, pre-despacho):
      - opencode em kb-sensitive -> state=unavailable (sem gate, sem despacho; confinamento diferido);
      - modelo efetivo + fail-closeds (ver -ReviewersJson);
      - gate Resolve-LlmDelegateAuthorization.ps1 (NAO autoriza): allow->fila de despacho,
        ask/deny->gateAsk/gateDeny, throw->error;
      - classifica invokeArgs por allowlist PER-BACKEND; contencao (permissionMode/tools/maxTurns,
        agent, approvalMode!=plan) e RECUSADA (securityBlockedArgs) e NAO repassada ao adapter:
        o despacho segue com os defaults seguros do adapter (decisao de seguranca, Posicao B);
      - resolve -Cd (precedencia + fail-closed; opencode nunca recebe -Cd).

    Despacho CONCORRENTE: ForEach-Object -Parallel -ThrottleLimit 8 + SemaphoreSlim($OllamaConcurrency)
    via $using: SO para family 'ollama-cloud' (validado empirico PS 7.6.2). Captura antes do Dispose.

    Classificacao do resultado (ESTRUTURAL, sem parsear prosa de parecer): texto nao-vazio -> responded;
    sentinela de cota/saldo/limite -> quota; timeout (BLOCK excedeu ... encerrado) -> timeout;
    vazio/resto -> error. Sem single-flight (diferido).

    DISCIPLINA DE STDOUT: este harness e processo filho. panel-summary.json e a UNICA linha de stdout.
    Todo texto humano sai por [Console]::Error (Write-Host/Write-Warning/Write-Information VAZAM para o
    stdout capturado num processo filho; so [Console]::Error fica fora). O chamador DEVE capturar stdout
    e stderr SEPARADAMENTE; redirecionar stderr->stdout corromperia o JSON.
.PARAMETER ManuscriptPath
    Caminho do manuscrito enviado a cada revisor (UTF-8). Repassado como -MessagePath ao adapter.
.PARAMETER ReviewersJson
    Array JSON [{backend, targetModelKey, invokeArgs, family?}] inline OU caminho de arquivo. O
    orquestrador ja decidiu o conjunto (subagente nativo injetado FORA). family por ordem: explicita
    -> targetModelKey canonico do gate (split '/'[0]) -> $null (despachavel, mas nao conta no piso).
    Modelo efetivo: opencode = invokeArgs.model ou o targetModelKey de ENTRADA (o resolvedor opencode
    exige -Model; o gate recebe o mesmo valor); codex = invokeArgs.model ou, se ausente, gate SEM -Model
    -> ultimo segmento do targetModelKey retornado; claude-code/copilot/gemini = invokeArgs.model
    OBRIGATORIO (ausente -> state=error fail-closed). targetModelKey nulo no opencode/codex onde exigido
    -> state=error fail-closed.
.PARAMETER PayloadSensitivity
    Classe do payload: 'public' ou 'kb-sensitive'. Repassado ao gate por revisor.
.PARAMETER RoundId
    Identificador da rodada (subpasta do ledger). Default: [guid]::NewGuid().ToString('N').
.PARAMETER Cd
    Diretorio de trabalho explicito para os adapters que aceitam -Cd (codex/claude-code/gemini/copilot).
    Precedencia: explicito -> $ParallelKbRoot em kb-sensitive -> cwd em public. opencode NUNCA recebe -Cd.
.PARAMETER ParallelKbRoot
    Raiz da pasta paralela de KB; repassada ao gate (descoberta de politica) e usada como -Cd em kb-sensitive.
.PARAMETER PolicyPath
    Caminho explicito do arquivo de politica; repassado ao gate (prevalece sobre -ParallelKbRoot).
.PARAMETER TempDir
    Raiz do ledger. Default: <temp do sistema>\xpz-llm-panel-dispatch. O ledger fica em <TempDir>\<RoundId>\.
.PARAMETER OllamaConcurrency
    Teto de chamadas simultaneas a family 'ollama-cloud' (semaforo). [ValidateRange(1,16)];
    16 = teto mecanico, default 3 = recomendacao do SKILL.md.
.PARAMETER OpenCodeConfigPath
    (SO TESTE) -ConfigPath repassado ao gate no backend opencode (opencode.json sintetico).
.PARAMETER CodexConfigPath
    (SO TESTE) -ConfigPath repassado ao gate no backend codex (config.toml sintetico).
.PARAMETER BackendExeMap
    (SO TESTE) JSON {backend: caminho-de-exe} (inline OU caminho de arquivo) para injetar fake-exe
    no adapter real via -<Backend>Exe.
.EXAMPLE
    .\Invoke-LlmDelegatePanelDispatch.ps1 -ManuscriptPath .\manuscrito.md -ReviewersJson .\revisores.json -PayloadSensitivity public
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ManuscriptPath,
    [Parameter(Mandatory)] [string] $ReviewersJson,
    [Parameter(Mandatory)] [ValidateSet('public', 'kb-sensitive')] [string] $PayloadSensitivity,
    [string] $RoundId,
    [string] $Cd,
    [string] $ParallelKbRoot,
    [string] $PolicyPath,
    [string] $TempDir,
    [ValidateRange(1, 16)] [int] $OllamaConcurrency = 3,
    # --- SO TESTE ---
    [string] $OpenCodeConfigPath,
    [string] $CodexConfigPath,
    [string] $BackendExeMap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Disciplina de stdout: UTF-8 sem BOM; o JSON-resumo e a UNICA linha de stdout.
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }

# Adapter por backend; parametro de exe-override (so teste) por backend.
$AdapterScript = @{
    'opencode'    = 'Invoke-OpenCode.ps1'
    'codex'       = 'Invoke-Codex.ps1'
    'claude-code' = 'Invoke-ClaudeCode.ps1'
    'copilot'     = 'Invoke-Copilot.ps1'
    'gemini'      = 'Invoke-Gemini.ps1'
}
$ExeParam = @{
    'opencode'    = 'OpenCodeExe'
    'codex'       = 'CodexExe'
    'claude-code' = 'ClaudeExe'
    'copilot'     = 'CopilotExe'
    'gemini'      = 'GeminiExe'
}
# Chaves de contencao recusadas (securityBlockedArgs) por backend. gemini.approvalMode e condicional.
$ContentionKeys = @{
    'claude-code' = @('permissionmode', 'tools', 'maxturns')
    'opencode'    = @('agent')
    'gemini'      = @('approvalmode')
    'codex'       = @()
    'copilot'     = @()
}

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and -not [string]::IsNullOrEmpty($Name) -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Get-Slug {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'na' }
    return ([regex]::Replace($Value, '[^A-Za-z0-9._-]', '-'))
}

$quotaFailurePattern = '(?i)(^|[^0-9])402([^0-9]|$)|Payment Required|insufficient coding plan balance|quota|rate limit|weekly usage limit|limite de uso|sem quota|saldo insuficiente'

function Test-QuotaFailureMessage {
    param([AllowNull()] [string] $Message)
    if ([string]::IsNullOrWhiteSpace($Message)) { return $false }
    return ($Message -match $script:quotaFailurePattern)
}

function Test-InvokeArgsBackendDivergence {
    param($Reviewer, [string]$Label)
    $backend = [string](Get-Prop $Reviewer 'backend')
    $invokeArgs = Get-Prop $Reviewer 'invokeArgs'
    $invBackend = [string](Get-Prop $invokeArgs 'backend')
    if (-not [string]::IsNullOrWhiteSpace($invBackend) -and $invBackend -ne $backend) {
        return "invokeArgs.backend ('$invBackend') diverge de backend ('$backend') em $Label"
    }
    return $null
}

function Get-FallbackItems {
    param($Reviewer)
    $fallbackItems = Get-Prop $Reviewer 'fallbackChain'
    if ($null -eq $fallbackItems) { return @() }
    return @($fallbackItems)
}

function Add-SkippedFallbackRecords {
    param(
        [System.Collections.Generic.List[object]]$Records,
        [object[]]$FallbackItems,
        [string]$FallbackOf,
        [string]$State,
        [string]$Reason,
        [int]$BaseRank
    )
    for ($skipIdx = 0; $skipIdx -lt @($FallbackItems).Count; $skipIdx++) {
        $fb = @($FallbackItems)[$skipIdx]
        $idx = $Records.Count
        $fbTarget = [string](Get-Prop $fb 'targetModelKey')
        $fbBackend = [string](Get-Prop $fb 'backend')
        $Records.Add([ordered]@{
                index              = $idx
                backend            = $fbBackend
                family             = if ($fbTarget) { @($fbTarget -split '/', 2)[0] } else { $null }
                targetModelKey     = $fbTarget
                effectiveModel     = [string](Get-Prop (Get-Prop $fb 'invokeArgs') 'model')
                gateVerdict        = $null
                state              = $State
                verdictPath        = $null
                errorPath          = $null
                statePath          = $null
                startedAt          = $null
                endedAt            = $null
                durationMs         = $null
                attempts           = 0
                reason             = $Reason
                droppedArgs        = @()
                securityBlockedArgs = @()
                attemptRole        = 'fallback'
                fallbackOf         = $FallbackOf
                fallbackIndex      = $skipIdx
                activationReason   = $null
                countsForDiversity = $false
                rank               = $BaseRank
                fallbackChain      = @()
            })
    }
}

# 0) Precondicoes de chamador (erro de uso -> nao produz summary)
if (-not (Test-Path -LiteralPath $ManuscriptPath -PathType Leaf)) {
    throw "BLOCK: -ManuscriptPath nao encontrado: $ManuscriptPath"
}
$manuscriptFull = (Resolve-Path -LiteralPath $ManuscriptPath).Path

$scriptsDir = $PSScriptRoot
$gateScript = Join-Path $scriptsDir 'Resolve-LlmDelegateAuthorization.ps1'
if (-not (Test-Path -LiteralPath $gateScript -PathType Leaf)) {
    throw "BLOCK: gate nao encontrado: $gateScript"
}

if ([string]::IsNullOrWhiteSpace($RoundId)) { $RoundId = [guid]::NewGuid().ToString('N') }

$tempRoot = $TempDir
if ([string]::IsNullOrWhiteSpace($tempRoot)) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'xpz-llm-panel-dispatch'
}
$ledgerDir = Join-Path $tempRoot $RoundId
New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null

# Mapa de fake-exe (so teste): inline OU arquivo
$exeMap = $null
if (-not [string]::IsNullOrWhiteSpace($BackendExeMap)) {
    $exeMapRaw = $BackendExeMap
    if (Test-Path -LiteralPath $BackendExeMap -PathType Leaf) {
        $exeMapRaw = Get-Content -LiteralPath $BackendExeMap -Raw -Encoding utf8
    }
    try { $exeMap = $exeMapRaw | ConvertFrom-Json } catch { throw "BLOCK: -BackendExeMap JSON invalido: $($_.Exception.Message)" }
}

# Entrada de revisores: inline ou arquivo
$reviewersRaw = $null
if (Test-Path -LiteralPath $ReviewersJson -PathType Leaf) {
    $reviewersRaw = Get-Content -LiteralPath $ReviewersJson -Raw -Encoding utf8
} else {
    $reviewersRaw = $ReviewersJson
}
$reviewers = $null
try { $reviewers = @($reviewersRaw | ConvertFrom-Json) } catch { throw "BLOCK: -ReviewersJson JSON invalido: $($_.Exception.Message)" }

# --------------------------------------------------------------------------------------------
# FASE PRE-DESPACHO (sequencial): para cada revisor produz um registro; os 'allow' viram planos
# de despacho. Cada registro e um [ordered]@{} mutavel; a ordem das chaves casa o contrato.
# --------------------------------------------------------------------------------------------
$records = [System.Collections.Generic.List[object]]::new()
$dispatchList = [System.Collections.Generic.List[object]]::new()

for ($i = 0; $i -lt $reviewers.Count; $i++) {
    $r = $reviewers[$i]
    $backend = [string](Get-Prop $r 'backend')
    $invokeArgs = Get-Prop $r 'invokeArgs'
    $fallbackItems = @(Get-FallbackItems -Reviewer $r)

    $inputKey = [string](Get-Prop $r 'targetModelKey')
    if ([string]::IsNullOrWhiteSpace($inputKey)) { $inputKey = $null }
    $familyExplicit = [string](Get-Prop $r 'family')
    if ([string]::IsNullOrWhiteSpace($familyExplicit)) { $familyExplicit = $null }

    # Registro base (todas as chaves do contrato; mutado adiante)
    $rec = [ordered]@{
        index              = $i
        backend            = $backend
        family             = $familyExplicit
        targetModelKey     = $inputKey
        effectiveModel     = $null
        gateVerdict        = $null
        state              = $null
        verdictPath        = $null
        errorPath          = $null
        statePath          = $null
        startedAt          = $null
        endedAt            = $null
        durationMs         = $null
        attempts           = 0
        reason             = $null
        droppedArgs        = @()
        securityBlockedArgs = @()
        attemptRole        = 'primary'
        fallbackOf         = $null
        fallbackIndex      = $null
        activationReason   = $null
        countsForDiversity = $false
        rank               = if ($null -ne (Get-Prop $r 'rank')) { [int](Get-Prop $r 'rank') } else { $i + 1 }
        fallbackChain      = @($fallbackItems)
    }

    $backendDivergence = Test-InvokeArgsBackendDivergence -Reviewer $r -Label "revisor[$i]"
    if ($backendDivergence) {
        $rec.state = 'error'
        $rec.reason = "BLOCK: $backendDivergence"
        $records.Add($rec); continue
    }
    $fallbackDivergence = $null
    for ($fbIdx = 0; $fbIdx -lt $fallbackItems.Count; $fbIdx++) {
        $fallbackDivergence = Test-InvokeArgsBackendDivergence -Reviewer $fallbackItems[$fbIdx] -Label "fallbackChain[$fbIdx] de $inputKey"
        if ($fallbackDivergence) { break }
    }
    if ($fallbackDivergence) {
        $rec.state = 'error'
        $rec.reason = "BLOCK: $fallbackDivergence"
        $records.Add($rec); continue
    }

    # Backend invalido -> erro defensivo
    if (-not $AdapterScript.ContainsKey($backend)) {
        $rec.state = 'error'
        $rec.reason = "backend desconhecido: '$backend'"
        $records.Add($rec); continue
    }

    # --- Classificacao de invokeArgs (independente do gate): securityBlockedArgs / droppedArgs / extraSplat ---
    $dropped = [System.Collections.Generic.List[string]]::new()
    $secBlocked = [System.Collections.Generic.List[string]]::new()
    $extraSplat = @{}
    if ($null -ne $invokeArgs) {
        foreach ($prop in $invokeArgs.PSObject.Properties) {
            $k = $prop.Name
            $kl = $k.ToLowerInvariant()
            $v = $prop.Value
            if ($kl -eq 'model') { continue }   # tratado como modelo efetivo
            # contencao per-backend
            if ($ContentionKeys[$backend] -contains $kl) {
                if ($backend -eq 'gemini' -and $kl -eq 'approvalmode') {
                    if ([string]$v -eq 'plan') { $dropped.Add($k) }   # default; drop silencioso (nao relaxa)
                    else { $secBlocked.Add($k) }                       # !=plan -> recusado (fail-closed precoce)
                } else {
                    $secBlocked.Add($k)
                }
                continue
            }
            # allowlist de despacho
            if ($kl -eq 'timeoutsec') { $extraSplat['TimeoutSec'] = [int]$v; continue }
            if ($backend -eq 'codex') {
                if ($kl -eq 'profile') { $extraSplat['Profile'] = [string]$v; continue }
                if ($kl -eq 'oss') { if ($v) { $extraSplat['Oss'] = $true }; continue }   # -Oss so quando verdadeiro
                if ($kl -eq 'localprovider') { $extraSplat['LocalProvider'] = [string]$v; continue }
            }
            $dropped.Add($k)
        }
    }
    $rec.droppedArgs = @($dropped)
    $rec.securityBlockedArgs = @($secBlocked)

    # --- opencode em kb-sensitive: terminal unavailable (sem gate/despacho) ---
    if ($backend -eq 'opencode' -and $PayloadSensitivity -eq 'kb-sensitive') {
        $rec.state = 'unavailable'
        $rec.reason = 'opencode em kb-sensitive: confinamento por agente custom diferido (frente 999); sem gate nem despacho'
        if (-not $rec.family -and $inputKey) { $rec.family = @($inputKey -split '/', 2)[0] }
        $records.Add($rec); continue
    }

    # --- Modelo efetivo + fail-closeds pre-gate ---
    $invModel = [string](Get-Prop $invokeArgs 'model')
    if ([string]::IsNullOrWhiteSpace($invModel)) { $invModel = $null }
    $effectiveModel = $null
    $gateModel = $null   # o que vai ao gate como -Model (pode ser omitido no codex)

    if ($backend -eq 'opencode') {
        if ($invModel) { $effectiveModel = $invModel } elseif ($inputKey) { $effectiveModel = $inputKey }
        if (-not $effectiveModel) {
            $rec.state = 'error'
            $rec.reason = 'opencode exige modelo (invokeArgs.model ou targetModelKey provider/modelo); ambos ausentes'
            $records.Add($rec); continue
        }
        $gateModel = $effectiveModel
    }
    elseif ($backend -eq 'codex') {
        # modelo efetivo so se resolve apos o gate (gate sem -Model deriva da config -> targetModelKey)
        if ($invModel) { $gateModel = $invModel }   # senao omite -Model
    }
    else {
        # claude-code / copilot / gemini -> invokeArgs.model OBRIGATORIO
        if (-not $invModel) {
            $rec.state = 'error'
            $rec.reason = "invokeArgs.model obrigatorio para backend ${backend}: o default do adapter e implicito e pode divergir da chave resolvida pelo gate; exigir model torna o destino declarado e auditavel"
            if (-not $rec.family -and $inputKey) { $rec.family = @($inputKey -split '/', 2)[0] }
            $records.Add($rec); continue
        }
        $effectiveModel = $invModel
        $gateModel = $invModel
    }

    # --- Gate (sem autorizar) ---
    $gateArgs = @{ Backend = $backend; PayloadSensitivity = $PayloadSensitivity }
    if ($gateModel) { $gateArgs['Model'] = $gateModel }
    if ($PolicyPath) { $gateArgs['PolicyPath'] = $PolicyPath }
    elseif ($ParallelKbRoot) { $gateArgs['ParallelKbRoot'] = $ParallelKbRoot }
    if ($backend -eq 'codex') {
        if ($extraSplat.ContainsKey('Oss')) { $gateArgs['Oss'] = $true }
        if ($extraSplat.ContainsKey('LocalProvider')) { $gateArgs['LocalProvider'] = $extraSplat['LocalProvider'] }
        if ($extraSplat.ContainsKey('Profile')) { $gateArgs['Profile'] = $extraSplat['Profile'] }
        if (-not [string]::IsNullOrWhiteSpace($CodexConfigPath)) { $gateArgs['ConfigPath'] = $CodexConfigPath }
    }
    if ($backend -eq 'opencode' -and -not [string]::IsNullOrWhiteSpace($OpenCodeConfigPath)) {
        $gateArgs['ConfigPath'] = $OpenCodeConfigPath
    }

    $gateOut = $null
    try {
        $gateOut = & $gateScript @gateArgs | ConvertFrom-Json
    } catch {
        $rec.state = 'error'
        $rec.gateVerdict = $null
        $rec.reason = "gate lancou: $($_.Exception.Message)"
        if (-not $rec.family -and $inputKey) { $rec.family = @($inputKey -split '/', 2)[0] }
        $records.Add($rec); continue
    }

    $gateVerdict = [string]$gateOut.verdict
    $returnedKey = [string](Get-Prop $gateOut 'targetModelKey')
    if ([string]::IsNullOrWhiteSpace($returnedKey)) { $returnedKey = $null }

    $rec.gateVerdict = $gateVerdict
    if ($returnedKey) { $rec.targetModelKey = $returnedKey }

    # codex: deriva o modelo nu do targetModelKey retornado; nulo -> fail-closed
    if ($backend -eq 'codex') {
        if (-not $returnedKey) {
            $rec.state = 'error'
            $rec.reason = 'codex sem modelo resolvivel: gate sem -Model nao derivou targetModelKey da config (fail-closed)'
            if (-not $rec.family -and $inputKey) { $rec.family = @($inputKey -split '/', 2)[0] }
            $records.Add($rec); continue
        }
        $effectiveModel = @($returnedKey -split '/')[-1]
    }
    $rec.effectiveModel = $effectiveModel

    # family definitiva
    if (-not $rec.family) {
        if ($returnedKey) { $rec.family = @($returnedKey -split '/', 2)[0] }
        elseif ($inputKey) { $rec.family = @($inputKey -split '/', 2)[0] }
    }

    # Verdito
    if ($gateVerdict -eq 'ask') {
        $rec.state = 'gateAsk'
        $rec.reason = [string](Get-Prop $gateOut 'reason')
        $records.Add($rec); continue
    }
    if ($gateVerdict -eq 'deny') {
        $rec.state = 'gateDeny'
        $rec.reason = [string](Get-Prop $gateOut 'reason')
        $records.Add($rec); continue
    }
    if ($gateVerdict -ne 'allow') {
        $rec.state = 'error'
        $rec.reason = "gate devolveu verdict inesperado: '$gateVerdict'"
        $records.Add($rec); continue
    }

    # --- allow: monta o despacho ---
    $splat = @{ MessagePath = $manuscriptFull; Model = $effectiveModel }

    # -Cd: precedencia + fail-closed (opencode nunca recebe -Cd)
    $cdCapable = ($backend -in @('codex', 'claude-code', 'gemini', 'copilot'))
    if ($cdCapable) {
        if ($PayloadSensitivity -eq 'kb-sensitive' -and -not $Cd -and -not $ParallelKbRoot) {
            $rec.state = 'error'
            $rec.reason = "kb-sensitive sem -Cd/-ParallelKbRoot para adapter com -Cd ($backend): fail-closed (nao confinar o cwd em conteudo sensivel)"
            $records.Add($rec); continue
        }
        $cdVal = $null
        if ($Cd) { $cdVal = $Cd }
        elseif ($PayloadSensitivity -eq 'kb-sensitive') { $cdVal = $ParallelKbRoot }
        else { $cdVal = (Get-Location).Path }
        $splat['Cd'] = $cdVal
    }

    # fake-exe (so teste)
    if ($null -ne $exeMap) {
        $exeOverride = [string](Get-Prop $exeMap $backend)
        if (-not [string]::IsNullOrWhiteSpace($exeOverride)) { $splat[$ExeParam[$backend]] = $exeOverride }
    }

    # retry-once so opencode
    if ($backend -eq 'opencode') { $splat['MaxAttempts'] = 2 }

    # args allowlistados (TimeoutSec / codex Profile/Oss/LocalProvider)
    foreach ($ek in $extraSplat.Keys) { $splat[$ek] = $extraSplat[$ek] }

    $adapterPath = Join-Path $scriptsDir $AdapterScript[$backend]
    $dispatchList.Add([pscustomobject]@{
        index       = $i
        family      = $rec.family
        adapterPath = $adapterPath
        splat       = $splat
    })

    $rec.state = 'PENDING'
    $records.Add($rec)
}

# --------------------------------------------------------------------------------------------
# DESPACHO CONCORRENTE: ForEach-Object -Parallel + SemaphoreSlim via $using: (so 'ollama-cloud').
# --------------------------------------------------------------------------------------------
$ollamaDispatched = @($dispatchList | Where-Object { $_.family -eq 'ollama-cloud' }).Count
$ollamaQuotaWarning = $null
if ($ollamaDispatched -ge 2) {
    $ollamaQuotaWarning = "ollamaQuotaWarning: $ollamaDispatched revisores ollama-cloud/* despachados no mesmo lote; a cota (ex.: weekly usage limit) pode ser compartilhada — ver LIMITE CONHECIDO HTTP 429."
}

$collected = @()
$sem = [System.Threading.SemaphoreSlim]::new($OllamaConcurrency, $OllamaConcurrency)
try {
    if ($dispatchList.Count -gt 0) {
        $collected = $dispatchList | ForEach-Object -Parallel {
            $item = $_
            $sem = $using:sem
            Set-StrictMode -Version Latest

            $useSem = ($item.family -eq 'ollama-cloud')
            $acquired = $false
            $result = $null
            $quotaPattern = $using:quotaFailurePattern
            # try EXTERNO envolve TODO o corpo: nada (nem Wait, nem Get-Date, nem o build do objeto)
            # escapa do runspace (conforme v11 "o bloco nunca lanca para fora").
            try {
                if ($useSem) { $sem.Wait(); $acquired = $true }
                $startedAt = (Get-Date).ToUniversalTime()
                $outVal = $null
                $errRec = $null
                try {
                    $p = $item.splat
                    $outVal = & $item.adapterPath @p
                } catch {
                    $errRec = $_
                }
                $endedAt = (Get-Date).ToUniversalTime()

                $joined = $null
                if ($null -ne $outVal) {
                    if ($outVal -is [array]) { $joined = ($outVal -join "`n") } else { $joined = [string]$outVal }
                }

                $state = $null; $textOut = $null; $errText = $null
                if ($null -ne $errRec) {
                    $msg = [string]$errRec.Exception.Message
                    if ($msg -match 'BLOCK:' -and $msg -match $quotaPattern) {
                        $state = 'quota'
                    } elseif ($msg -match 'excedeu' -and $msg -match 'foi encerrado') {
                        $state = 'timeout'
                    } else {
                        $state = 'error'
                    }
                    $errText = $msg
                } else {
                    if ([string]::IsNullOrWhiteSpace($joined)) {
                        $state = 'error'
                        $errText = 'BLOCK: adapter retornou texto vazio (defensivo).'
                    } else {
                        $state = 'responded'
                        $textOut = $joined
                    }
                }

                $result = [pscustomobject]@{
                    index      = $item.index
                    state      = $state
                    text       = $textOut
                    errorText  = $errText
                    startedAt  = $startedAt.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    endedAt    = $endedAt.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    durationMs = [int]($endedAt - $startedAt).TotalMilliseconds
                    attempts   = 1
                }
            } catch {
                # Defesa em profundidade: qualquer excecao inesperada no runspace (ex.: Wait,
                # Get-Date) vira um resultado 'error' — nunca escapa do bloco (conforme v11).
                $result = [pscustomobject]@{
                    index      = $item.index
                    state      = 'error'
                    text       = $null
                    errorText  = "BLOCK: falha inesperada no runspace: $($_.Exception.Message)"
                    startedAt  = $null
                    endedAt    = $null
                    durationMs = $null
                    attempts   = 1
                }
            } finally {
                # [void]: SemaphoreSlim.Release() devolve o contador anterior (int); sem o [void]
                # esse int vazaria para a saida do runspace e poluiria $collected.
                if ($acquired) { [void]$sem.Release() }
            }
            $result
        } -ThrottleLimit 8
    }
} finally {
    $sem.Dispose()
}
$collected = @($collected)

# Merge dos resultados (por index) nos registros PENDING
$byIndex = @{}
foreach ($rec in $records) { $byIndex[[int]$rec.index] = $rec }
foreach ($res in $collected) {
    $rec = $byIndex[[int]$res.index]
    if ($null -eq $rec) { continue }
    $rec.state = $res.state
    $rec.startedAt = $res.startedAt
    $rec.endedAt = $res.endedAt
    $rec.durationMs = $res.durationMs
    $rec.attempts = $res.attempts
    $rec['__text'] = $res.text
    $rec['__errorText'] = $res.errorText
}

# --------------------------------------------------------------------------------------------
# FALLBACK ORDENADO (segunda passagem): o primario falhou por estado ativavel, entao cada
# fallback passa pelo mesmo gate/adapter via invocacao recursiva sem herdar autorizacao.
# Estados de nao tentativa nunca contam diversidade.
# --------------------------------------------------------------------------------------------
$activateFallbackOn = @('quota', 'timeout', 'error', 'unavailable')
$skipPolicyStates = @('gateAsk', 'gateDeny')
$originalRecords = @($records)
foreach ($rec in $originalRecords) {
    $fallbackItems = @($rec.fallbackChain)
    if ($fallbackItems.Count -eq 0) { continue }
    if ($rec.state -eq 'responded') {
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'skippedAfterSuccess' -Reason 'fallback nao tentado porque o primario respondeu' -BaseRank ([int]$rec.rank)
        continue
    }
    if ([string]$rec.state -eq 'error' -and [string]$rec.reason -like 'BLOCK:*') {
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'skippedByPolicy' -Reason "fallback nao tentado por erro de validacao pre-despacho: $($rec.reason)" -BaseRank ([int]$rec.rank)
        continue
    }
    if ($skipPolicyStates -contains [string]$rec.state) {
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'skippedByPolicy' -Reason "fallback nao tentado porque o primario terminou em $($rec.state)" -BaseRank ([int]$rec.rank)
        continue
    }
    if ($activateFallbackOn -notcontains [string]$rec.state) {
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'notAttempted' -Reason "fallback nao alcançado; estado primario=$($rec.state)" -BaseRank ([int]$rec.rank)
        continue
    }

    $fallbackSucceeded = $false
    for ($fbIdx = 0; $fbIdx -lt $fallbackItems.Count; $fbIdx++) {
        $fb = $fallbackItems[$fbIdx]
        if ($fallbackSucceeded) {
            Add-SkippedFallbackRecords -Records $records -FallbackItems @($fb) -FallbackOf ([string]$rec.targetModelKey) `
                -State 'skippedAfterSuccess' -Reason 'fallback nao tentado porque tentativa anterior da cadeia respondeu' -BaseRank ([int]$rec.rank)
            continue
        }

        $fbJsonPath = Join-Path $ledgerDir ("fallback-$($rec.index)-$fbIdx.reviewers.json")
        $fbClean = [pscustomobject]@{
            backend        = [string](Get-Prop $fb 'backend')
            targetModelKey = [string](Get-Prop $fb 'targetModelKey')
            invokeArgs     = (Get-Prop $fb 'invokeArgs')
            family         = (Get-Prop $fb 'family')
            rank           = [int]$rec.rank
        }
        @($fbClean) | ConvertTo-Json -Depth 10 -AsArray | Set-Content -LiteralPath $fbJsonPath -Encoding utf8
        $fbArgs = @{
            ManuscriptPath     = $manuscriptFull
            ReviewersJson      = $fbJsonPath
            PayloadSensitivity = $PayloadSensitivity
            RoundId            = "$RoundId-fb-$($rec.index)-$fbIdx"
            TempDir            = $tempRoot
            OllamaConcurrency  = $OllamaConcurrency
        }
        if ($Cd) { $fbArgs['Cd'] = $Cd }
        if ($ParallelKbRoot) { $fbArgs['ParallelKbRoot'] = $ParallelKbRoot }
        if ($PolicyPath) { $fbArgs['PolicyPath'] = $PolicyPath }
        if ($OpenCodeConfigPath) { $fbArgs['OpenCodeConfigPath'] = $OpenCodeConfigPath }
        if ($CodexConfigPath) { $fbArgs['CodexConfigPath'] = $CodexConfigPath }
        if ($BackendExeMap) { $fbArgs['BackendExeMap'] = $BackendExeMap }

        $fbRecord = $null
        try {
            $fbOutPath = Join-Path $ledgerDir ("fallback-$($rec.index)-$fbIdx.stdout.json")
            $fbErrPath = Join-Path $ledgerDir ("fallback-$($rec.index)-$fbIdx.stderr.txt")
            $argList = @(
                '-NoProfile', '-File', $PSCommandPath,
                '-ManuscriptPath', $fbArgs.ManuscriptPath,
                '-ReviewersJson', $fbArgs.ReviewersJson,
                '-PayloadSensitivity', $fbArgs.PayloadSensitivity,
                '-RoundId', $fbArgs.RoundId,
                '-TempDir', $fbArgs.TempDir,
                '-OllamaConcurrency', ([string]$fbArgs.OllamaConcurrency)
            )
            foreach ($optionalKey in @('Cd', 'ParallelKbRoot', 'PolicyPath', 'OpenCodeConfigPath', 'CodexConfigPath', 'BackendExeMap')) {
                if ($fbArgs.ContainsKey($optionalKey)) { $argList += @("-$optionalKey", [string]$fbArgs[$optionalKey]) }
            }
            $p = Start-Process -FilePath 'pwsh' -ArgumentList $argList -NoNewWindow -PassThru `
                -RedirectStandardOutput $fbOutPath -RedirectStandardError $fbErrPath
            $exited = $p.WaitForExit(180000)
            if (-not $exited) {
                try {
                    $p.Kill($true)
                    $p.WaitForExit()
                } catch { }
                throw 'fallback dispatcher timeout excedeu 180000ms; processo encerrado'
            }
            $fbStdout = ''
            if (Test-Path -LiteralPath $fbOutPath -PathType Leaf) {
                $fbStdout = Get-Content -LiteralPath $fbOutPath -Raw -Encoding utf8
            }
            if ($p.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($fbStdout)) {
                throw "fallback dispatcher exit=$($p.ExitCode)"
            }
            $fbSummary = ($fbStdout.Trim() -split "`r?`n" | Select-Object -Last 1) | ConvertFrom-Json
            $fbRecord = @($fbSummary.reviewers)[0]
        } catch {
            $fallbackState = 'error'
            if ([string]$_.Exception.Message -match 'timeout|excedeu') { $fallbackState = 'timeout' }
            elseif (Test-QuotaFailureMessage -Message ([string]$_.Exception.Message)) { $fallbackState = 'quota' }
            $fbRecord = [pscustomobject]@{
                backend        = [string](Get-Prop $fb 'backend')
                targetModelKey = [string](Get-Prop $fb 'targetModelKey')
                family         = (Get-Prop $fb 'family')
                state          = $fallbackState
                reason         = "fallback dispatcher falhou: $($_.Exception.Message)"
                attempts       = 0
            }
        }
        $newIdx = $records.Count
        $fbState = [string](Get-Prop $fbRecord 'state')
        $counts = ($fbState -eq 'responded')
        $records.Add([ordered]@{
                index              = $newIdx
                backend            = [string](Get-Prop $fbRecord 'backend')
                family             = [string](Get-Prop $fbRecord 'family')
                targetModelKey     = [string](Get-Prop $fbRecord 'targetModelKey')
                effectiveModel     = [string](Get-Prop $fbRecord 'effectiveModel')
                gateVerdict        = [string](Get-Prop $fbRecord 'gateVerdict')
                state              = $fbState
                verdictPath        = [string](Get-Prop $fbRecord 'verdictPath')
                errorPath          = [string](Get-Prop $fbRecord 'errorPath')
                statePath          = [string](Get-Prop $fbRecord 'statePath')
                startedAt          = [string](Get-Prop $fbRecord 'startedAt')
                endedAt            = [string](Get-Prop $fbRecord 'endedAt')
                durationMs         = Get-Prop $fbRecord 'durationMs'
                attempts           = [int](Get-Prop $fbRecord 'attempts')
                reason             = [string](Get-Prop $fbRecord 'reason')
                droppedArgs        = @(Get-Prop $fbRecord 'droppedArgs')
                securityBlockedArgs = @(Get-Prop $fbRecord 'securityBlockedArgs')
                attemptRole        = 'fallback'
                fallbackOf         = [string]$rec.targetModelKey
                fallbackIndex      = $fbIdx
                activationReason   = [string]$rec.state
                countsForDiversity = $counts
                rank               = [int]$rec.rank
                fallbackChain      = @()
            })
        if ($fbState -eq 'responded') { $fallbackSucceeded = $true }
    }
}

foreach ($rec in $records) {
    if ($rec.state -eq 'responded') { $rec.countsForDiversity = $true }
    if ($rec.state -in @('skippedByPolicy', 'skippedAfterSuccess', 'notAttempted')) { $rec.countsForDiversity = $false }
}

# --------------------------------------------------------------------------------------------
# LEDGER + SUMMARY
# --------------------------------------------------------------------------------------------
$reviewerFiles = [System.Collections.Generic.List[object]]::new()
foreach ($rec in $records) {
    $nn = '{0:D2}' -f [int]$rec.index
    $famSlug = if ([string]::IsNullOrWhiteSpace([string]$rec.family)) { 'na' } else { Get-Slug ([string]$rec.family) }
    $keySlug = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$rec.targetModelKey)) { $keySlug = Get-Slug ([string]$rec.targetModelKey) }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$rec.effectiveModel)) { $keySlug = Get-Slug ([string]$rec.effectiveModel) }
    else { $keySlug = 'na' }
    $baseName = "$nn-$famSlug-$keySlug"

    $text = $null; $errText = $null
    if ($rec.Contains('__text')) { $text = [string]$rec['__text'] }
    if ($rec.Contains('__errorText')) { $errText = [string]$rec['__errorText'] }

    switch ($rec.state) {
        'responded' {
            if ([string]::IsNullOrWhiteSpace([string]$rec.verdictPath)) {
                $path = Join-Path $ledgerDir "$baseName.verdict.txt"
                Set-Content -LiteralPath $path -Value ([string]$text) -Encoding utf8
                $rec.verdictPath = $path
            }
        }
        { $_ -in @('error', 'timeout') } {
            if ([string]::IsNullOrWhiteSpace([string]$rec.errorPath)) {
                $path = Join-Path $ledgerDir "$baseName.error.txt"
                $content = if ($errText) { $errText } else { [string]$rec.reason }
                Set-Content -LiteralPath $path -Value ([string]$content) -Encoding utf8
                $rec.errorPath = $path
            }
        }
            { $_ -in @('gateAsk', 'gateDeny', 'quota', 'unavailable', 'skippedByPolicy', 'skippedAfterSuccess', 'notAttempted') } {
            if ([string]::IsNullOrWhiteSpace([string]$rec.statePath)) {
                $path = Join-Path $ledgerDir "$baseName.state.txt"
                Set-Content -LiteralPath $path -Value ([string]$rec.reason) -Encoding utf8
                $rec.statePath = $path
            }
        }
    }
    $reviewerFiles.Add([pscustomobject]@{
        index = [int]$rec.index
        path  = @($rec.verdictPath, $rec.errorPath, $rec.statePath | Where-Object { $_ }) | Select-Object -First 1
    })
    # campos internos fora do contrato
    if ($rec.Contains('__text')) { $rec.Remove('__text') }
    if ($rec.Contains('__errorText')) { $rec.Remove('__errorText') }
}

# concurrencySaturationWarning: 2+ ollama-cloud/* em error neste lote (sem redisparo automatico - single-flight diferido)
$ollamaErrors = @($records | Where-Object { $_.family -eq 'ollama-cloud' -and $_.state -eq 'error' }).Count
$concurrencySaturationWarning = $null
if ($ollamaErrors -ge 2) {
    $concurrencySaturationWarning = "concurrencySaturationWarning: $ollamaErrors revisores ollama-cloud/* terminaram em error neste lote; possivel saturacao de concorrencia. Sem redisparo automatico (single-flight diferido) — o orquestrador so pode redisparar isolado com decisao humana explicita."
}

# Contagens
$dispatched = @($records | Where-Object { [int]$_.attempts -ge 1 }).Count
$respondedCount = @($records | Where-Object { $_.state -eq 'responded' }).Count
$errorCount = @($records | Where-Object { $_.state -eq 'error' }).Count
$timeoutCount = @($records | Where-Object { $_.state -eq 'timeout' }).Count
$quotaCount = @($records | Where-Object { $_.state -eq 'quota' }).Count
$unavailableCount = @($records | Where-Object { $_.state -eq 'unavailable' }).Count
$gateAskCount = @($records | Where-Object { $_.state -eq 'gateAsk' }).Count
$gateDenyCount = @($records | Where-Object { $_.state -eq 'gateDeny' }).Count

$reviewerObjs = @($records | ForEach-Object { [pscustomobject]$_ })

$parallelKbRootOut = $null; if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) { $parallelKbRootOut = $ParallelKbRoot }
$policyPathOut = $null; if (-not [string]::IsNullOrWhiteSpace($PolicyPath)) { $policyPathOut = $PolicyPath }

$summary = [ordered]@{
    Kind                         = 'xpz-llm-panel-dispatch-result'
    SchemaVersion                = 1
    roundId                      = $RoundId
    payloadSensitivity           = $PayloadSensitivity
    parallelKbRoot               = $parallelKbRootOut
    policyPath                   = $policyPathOut
    manuscriptPath               = $manuscriptFull
    ollamaConcurrency            = $OllamaConcurrency
    reviewers                    = @($reviewerObjs)
    dispatched                   = $dispatched
    respondedCount               = $respondedCount
    errorCount                   = $errorCount
    timeoutCount                 = $timeoutCount
    quotaCount                   = $quotaCount
    unavailableCount             = $unavailableCount
    gateAsk                      = $gateAskCount
    gateDeny                     = $gateDenyCount
    ollamaQuotaWarning           = $ollamaQuotaWarning
    concurrencySaturationWarning = $concurrencySaturationWarning
}

$summaryPath = Join-Path $ledgerDir 'panel-summary.json'
$summaryJson = $summary | ConvertTo-Json -Compress -Depth 8
Set-Content -LiteralPath $summaryPath -Value $summaryJson -Encoding utf8

$manifest = [ordered]@{
    Kind          = 'xpz-llm-panel-dispatch-manifest'
    SchemaVersion = 1
    roundId       = $RoundId
    tempDir       = $tempRoot
    summaryPath   = $summaryPath
    reviewerFiles = @($reviewerFiles)
}
$manifestPath = Join-Path $ledgerDir 'manifest.json'
($manifest | ConvertTo-Json -Compress -Depth 6) | Set-Content -LiteralPath $manifestPath -Encoding utf8

# Avisos -> stderr (nunca stdout)
if ($ollamaQuotaWarning) { [Console]::Error.WriteLine($ollamaQuotaWarning) }
if ($concurrencySaturationWarning) { [Console]::Error.WriteLine($concurrencySaturationWarning) }

# stdout = UNICA linha (o panel-summary.json)
[Console]::Out.WriteLine($summaryJson)
