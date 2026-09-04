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

    Aceita exatamente uma origem de manuscrito: -ManuscriptPath (legado) OU -ManuscriptText.
    No modo -ManuscriptText, prepara artefatos transacionais com New-LlmDelegatePeerReviewArtifacts.ps1
    antes de qualquer gate/despacho; falha de preparacao emite summary proprio com rodada/despacho
    nao iniciados e zero revisores despachados.

    Por revisor (sequencial, pre-despacho):
      - opencode em kb-sensitive -> state=unavailable (sem gate, sem despacho; confinamento diferido);
      - modelo efetivo + fail-closeds (ver -ReviewersJson);
      - gate Resolve-LlmDelegateAuthorization.ps1 (NAO autoriza): allow->fila de despacho,
        ask/deny->gateAsk/gateDeny, throw->error;
      - Antigravity public-review com gate allow em kb-sensitive -> unavailable/refusedSensitivity
        antes do adapter; ask/deny permanecem estados do gate;
      - classifica invokeArgs por allowlist PER-BACKEND; contencao (permissionMode/tools/maxTurns,
        agent, approvalMode!=plan) e chaves internas do adapter sao RECUSADAS (securityBlockedArgs)
        e NAO repassadas ao adapter:
        o despacho segue com os defaults seguros do adapter (decisao de seguranca, Posicao B);
      - resolve -Cd (precedencia + fail-closed; opencode nunca recebe -Cd; Antigravity
        public-review cria scratch proprio e recusa cwd herdado).

    Despacho CONCORRENTE: ForEach-Object -Parallel -ThrottleLimit 8 + SemaphoreSlim($OllamaConcurrency)
    via $using: SO para family 'ollama-cloud' (validado empirico PS 7.6.2). Captura antes do Dispose.

    Classificacao do resultado (ESTRUTURAL, sem parsear prosa de parecer): adapters legados seguem
    texto nao-vazio -> responded; sentinela de cota/saldo/limite -> quota; timeout (BLOCK excedeu ...
    encerrado) -> timeout; vazio/resto -> error. Claude Code no painel usa sidecar tecnico atomico:
    o stdout so conta quando o sidecar aceito traz resultAccepted=true. Sem single-flight (diferido).

    DISCIPLINA DE STDOUT: este harness e processo filho. panel-summary.json e a UNICA linha de stdout.
    Todo texto humano sai por [Console]::Error (Write-Host/Write-Warning/Write-Information VAZAM para o
    stdout capturado num processo filho; so [Console]::Error fica fora). O chamador DEVE capturar stdout
    e stderr SEPARADAMENTE; redirecionar stderr->stdout corromperia o JSON.
.PARAMETER ManuscriptPath
    Caminho do manuscrito enviado a cada revisor (UTF-8). Exclusivo com -ManuscriptText.
.PARAMETER ManuscriptText
    Texto do manuscrito. Exclusivo com -ManuscriptPath; gera manuscript.md/reviewers.json/manifest
    em <TempDir>\<RoundId> antes de iniciar o despacho. Use apenas para payload curto; para
    payload grande, use -ManuscriptPath para evitar o limite de linha de comando do Windows.
.PARAMETER ReviewersJson
    Array JSON [{backend, targetModelKey, invokeArgs, family?, rank?, fallbackChain?}] inline OU caminho de arquivo. O
    orquestrador ja decidiu o conjunto (subagente nativo injetado FORA). fallbackChain[] e lista ordenada
    de revisores completos; o harness registra attemptRole/fallbackOf/countsForDiversity no resultado.
    family por ordem: explicita
    -> familia resolvida via Get-LlmDelegateTargetFamily -> $null (despachavel, mas nao conta no piso).
    Modelo efetivo: opencode = invokeArgs.model ou o targetModelKey de ENTRADA (o resolvedor opencode
    exige -Model; o gate recebe o mesmo valor); codex = invokeArgs.model ou, se ausente, gate SEM -Model
    -> ultimo segmento do targetModelKey retornado; claude-code/copilot/gemini/antigravity = invokeArgs.model
    OBRIGATORIO (ausente -> state=error fail-closed). targetModelKey nulo no opencode/codex onde exigido
    -> state=error fail-closed.
.PARAMETER PayloadSensitivity
    Classe do payload: 'public' ou 'kb-sensitive'. Repassado ao gate por revisor.
.PARAMETER RoundId
    Identificador da rodada (subpasta do ledger). Default: [guid]::NewGuid().ToString('N').
.PARAMETER Cd
    Diretorio de trabalho explicito para os adapters que aceitam -Cd (codex/claude-code/gemini/copilot).
    Precedencia: explicito -> $ParallelKbRoot em kb-sensitive -> cwd em public. opencode NUNCA recebe
    -Cd; Antigravity public-review cria scratch proprio e nao recebe a raiz do repositorio.
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
.PARAMETER ClaudeCircuitStateRoot
    (SO TESTE) raiz do circuito de cota do adapter assíncrono do Claude Code.
.EXAMPLE
    .\Invoke-LlmDelegatePanelDispatch.ps1 -ManuscriptPath .\manuscrito.md -ReviewersJson .\revisores.json -PayloadSensitivity public
#>
[CmdletBinding()]
param(
    [string] $ManuscriptPath,
    [AllowEmptyString()] [string] $ManuscriptText,
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
    [string] $BackendExeMap,
    [string] $ClaudeCircuitStateRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Disciplina de stdout: UTF-8 sem BOM; o JSON-resumo e a UNICA linha de stdout.
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch { }
. (Join-Path $PSScriptRoot 'LlmDelegateTargetFamilySupport.ps1')

$MaxInlineManuscriptChars = 30000

# Adapter por backend; parametro de exe-override (so teste) por backend.
$AdapterScript = @{
    'opencode'    = 'Invoke-OpenCode.ps1'
    'codex'       = 'Invoke-Codex.ps1'
    'claude-code' = 'Invoke-ClaudeCodeAsync.ps1'
    'copilot'     = 'Invoke-Copilot.ps1'
    'gemini'      = 'Invoke-Gemini.ps1'
    'antigravity' = 'Invoke-Antigravity.ps1'
}
$ExeParam = @{
    'opencode'    = 'OpenCodeExe'
    'codex'       = 'CodexExe'
    'claude-code' = 'ClaudeExe'
    'copilot'     = 'CopilotExe'
    'gemini'      = 'GeminiExe'
    'antigravity' = 'AntigravityExe'
}
# Chaves de contencao/internas recusadas (securityBlockedArgs) por backend. gemini.approvalMode e condicional.
$ContentionKeys = @{
    'claude-code' = @(
        'permissionmode', 'tools', 'maxturns',
        'sidecarpath', 'retentionmode', 'tempdir', 'circuitstateroot', 'claudeexe',
        'message', 'messagepath'
    )
    'opencode'    = @('agent')
    'gemini'      = @('approvalmode')
    'antigravity' = @(
        'mode', 'agent', 'approvalmode', 'profile', 'cd', 'scratchpath', 'simulatecleanupfailure', 'receiptpath',
        'antigravityexe', 'message', 'messagepath'
    )
    'codex'       = @()
    'copilot'     = @()
}
$AdapterDefaultTimeoutSec = @{
    # Revisao agentica (ler repo) costuma passar de 180s; medido 2026-09-04: Codex Luna ~646s.
    'opencode'    = 1200
    'codex'       = 1200
    'claude-code' = 300
    'copilot'     = 300
    'gemini'      = 300
    'antigravity' = 300
}
$AdapterCdCapable = @{
    'opencode'    = $false # contrato: opencode nunca recebe -Cd
    'codex'       = $true
    'claude-code' = $true
    'copilot'     = $true
    'gemini'      = $true
    'antigravity' = $false # public-review cria scratch proprio; nunca herda cwd do dispatcher
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

# `exhausted` NAO entra solto: erro generico de rede/contexto ("retries exhausted", "connection pool
# exhausted", "context window exhausted") viraria quota em TODOS os backends e mandaria o operador
# esperar reset de ciclo por falha que nao e cota. Ancorar no sujeito esgotado (resource_exhausted,
# credits/balance/saldo exhausted); "quota exhausted" ja casa pelo termo `quota`.
$quotaFailurePattern = '(?i)(^|[^0-9])(402|429)([^0-9]|$)|Payment Required|insufficient coding plan balance|quota|rate limit|resource_exhausted|(?:credits?|balance|saldo)\s+exhausted|too many requests|weekly usage limit|limite de uso|sem quota|saldo insuficiente'
$unavailableFailurePattern = '(?i)workspace-not-trusted'

function Test-QuotaFailureMessage {
    param([AllowNull()] [string] $Message)
    if ([string]::IsNullOrWhiteSpace($Message)) { return $false }
    return ($Message -match $script:quotaFailurePattern)
}

function Test-UnavailableFailureMessage {
    param([AllowNull()] [string] $Message)
    if ([string]::IsNullOrWhiteSpace($Message)) { return $false }
    return ($Message -match $script:unavailableFailurePattern)
}

function Get-FallbackDispatcherTimeoutMs {
    param([string]$Backend, $InvokeArgs)
    $defaultTimeoutMs = 180000
    # Folga apos o adapter: classificacao, ledger, summary (era 30s; GAP-4 GLM 2026-09-04).
    $overheadMs = 120000
    $adapterDefaultTimeoutSec = 180
    if (-not [string]::IsNullOrWhiteSpace($Backend) -and $script:AdapterDefaultTimeoutSec.ContainsKey($Backend)) {
        $adapterDefaultTimeoutSec = [int]$script:AdapterDefaultTimeoutSec[$Backend]
    }
    $timeoutSecValue = Get-Prop $InvokeArgs 'timeoutSec'
    $timeoutSec = 0
    if ($null -eq $timeoutSecValue -or -not [int]::TryParse([string]$timeoutSecValue, [ref]$timeoutSec) -or $timeoutSec -lt 1) {
        $timeoutSec = $adapterDefaultTimeoutSec
    }

    # OpenCode no painel: MaxAttempts=2 e TimeoutSec por tentativa (parede ~2x).
    $attemptFactor = 1
    if ($Backend -eq 'opencode') {
        $attemptFactor = 2
    }

    $derivedTimeoutMs = ([int64]$timeoutSec * 1000 * [int64]$attemptFactor) + $overheadMs
    if ($derivedTimeoutMs -lt $defaultTimeoutMs) { return $defaultTimeoutMs }
    if ($derivedTimeoutMs -gt [int]::MaxValue) { return [int]::MaxValue }
    return [int]$derivedTimeoutMs
}

function Get-CurrentPowerShellExecutable {
    $currentExe = ''
    try { $currentExe = [string]([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch { }
    if (-not [string]::IsNullOrWhiteSpace($currentExe) -and (Test-Path -LiteralPath $currentExe -PathType Leaf)) {
        return $currentExe
    }

    $psHomeExeName = if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }
    $psHomeExe = Join-Path $PSHOME $psHomeExeName
    if (Test-Path -LiteralPath $psHomeExe -PathType Leaf) {
        return $psHomeExe
    }

    throw "BLOCK: executavel PowerShell atual nao resolvido para fallback recursivo"
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
        [int]$BaseRank,
        [string]$FallbackSuppressedReason,
        [int]$EntryIndex
    )
    for ($skipIdx = 0; $skipIdx -lt @($FallbackItems).Count; $skipIdx++) {
        $fb = @($FallbackItems)[$skipIdx]
        $idx = $Records.Count
        $fbTarget = [string](Get-Prop $fb 'targetModelKey')
        $fbBackend = [string](Get-Prop $fb 'backend')
        $Records.Add([ordered]@{
                index              = $idx
                ledgerIndex        = $script:LedgerSeq++
                entryIndex         = $EntryIndex
                suppressedFallbackChain = @()
                dispatchChannel    = 'cli'
                backend            = $fbBackend
                family             = if ($fbTarget) { Get-LlmDelegateTargetFamily -TargetModelKey $fbTarget } else { $null }
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
                dispatchAttempted  = $false
                preDispatchBlocked = $false
                processCreated     = $null
                sidecarPath        = $null
                sidecarAccepted    = $null
                sidecarValidationReason = $null
                technicalStatus    = $null
                resultAccepted     = $null
                acceptanceRejectionReason = $null
                acceptedFinalTextSha256 = $null
                acceptedFinalTextBytes = $null
                promptTransmission = $null
                quotaCircuitDecision = $null
                quotaCircuitVariantDecisions = @()
                fallbackSuppressedReason = $FallbackSuppressedReason
            })
    }
}

function Get-TextSha256 {
    param([AllowNull()] [string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
}

function Read-PanelJsonFileWithDeadline {
    param([string]$Path, [int]$DeadlineMs = 250)

    $deadline = [datetime]::UtcNow.AddMilliseconds($DeadlineMs)
    do {
        try {
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
                Start-Sleep -Milliseconds 25
                continue
            }
            $raw = Get-Content -LiteralPath $Path -Raw -Encoding utf8 -ErrorAction Stop
            return [pscustomobject]@{ status = 'ok'; value = ($raw | ConvertFrom-Json); error = $null }
        } catch [System.IO.IOException] {
            Start-Sleep -Milliseconds 25
        } catch {
            return [pscustomobject]@{ status = 'json-invalid'; value = $null; error = $_.Exception.Message }
        }
    } while ([datetime]::UtcNow -lt $deadline)

    return [pscustomobject]@{ status = 'read-inconclusive'; value = $null; error = 'deadline' }
}

function Test-ClaudeCodeSidecarShape {
    param([AllowNull()] $Sidecar, [AllowNull()] [string]$StdoutText)

    if ($null -eq $Sidecar) { return [pscustomobject]@{ accepted = $false; reason = 'sidecar-missing' } }
    $forbidden = @(
        'sidecarAccepted', 'sidecarValidationReason', 'state', 'countsForDiversity',
        'preDispatchBlocked', 'dispatchAttempted', 'fallbackSuppressedReason',
        'reviewersDispatched', 'reviewersProcessCreated', 'processCreatedUnknownCount', 'vNextState'
    )
    foreach ($name in $forbidden) {
        if ($Sidecar.PSObject.Properties[$name]) {
            return [pscustomobject]@{ accepted = $false; reason = "sidecar-forbidden-field:$name" }
        }
    }
    $required = @(
        'Kind', 'SchemaVersion', 'adapterName', 'backend', 'model', 'jobId', 'startedAtUtc',
        'endedAtUtc', 'durationMs', 'technicalStatus', 'resultAccepted',
        'acceptanceRejectionReason', 'exitCode', 'terminalReason', 'apiErrorStatus',
        'failureAfterText', 'stderrSha256', 'streamSha256', 'acceptedFinalTextSha256',
        'acceptedFinalTextBytes', 'finalTextDisposition', 'promptTransmission',
        'spawnAttempted', 'processCreated', 'processIdentity', 'processIdentityVerified',
        'cancelRequested', 'cancelIssued', 'cancelIdentityUnverifiable', 'quotaEvidence',
        'quotaCircuitDecision', 'retentionMode', 'retentionCleanupFailed'
    )
    foreach ($name in $required) {
        if (-not $Sidecar.PSObject.Properties[$name]) {
            return [pscustomobject]@{ accepted = $false; reason = "sidecar-missing-field:$name" }
        }
    }
    if ([string](Get-Prop $Sidecar 'Kind') -ne 'claude-code-async-sidecar') {
        return [pscustomobject]@{ accepted = $false; reason = 'sidecar-kind-invalid' }
    }
    $schemaVersion = Get-Prop $Sidecar 'SchemaVersion'
    if (($schemaVersion -isnot [int] -and $schemaVersion -isnot [long]) -or [int]$schemaVersion -ne 1) {
        return [pscustomobject]@{ accepted = $false; reason = 'sidecar-schema-invalid' }
    }
    if ([string](Get-Prop $Sidecar 'backend') -ne 'claude-code') {
        return [pscustomobject]@{ accepted = $false; reason = 'sidecar-backend-invalid' }
    }
    $acceptedValue = Get-Prop $Sidecar 'resultAccepted'
    if ($acceptedValue -isnot [bool]) {
        return [pscustomobject]@{ accepted = $false; reason = 'sidecar-resultAccepted-not-boolean' }
    }
    $accepted = [bool]$acceptedValue
    $technicalStatus = [string](Get-Prop $Sidecar 'technicalStatus')
    $finalTextDisposition = [string](Get-Prop $Sidecar 'finalTextDisposition')
    $retentionCleanupFailedValue = Get-Prop $Sidecar 'retentionCleanupFailed'
    if ($retentionCleanupFailedValue -isnot [bool]) {
        return [pscustomobject]@{ accepted = $false; reason = 'sidecar-retentionCleanupFailed-not-boolean' }
    }
    $retentionCleanupFailed = [bool]$retentionCleanupFailedValue
    if ($accepted) {
        if ($technicalStatus -ne 'completed') {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-accepted-with-noncompleted-status' }
        }
        if ($finalTextDisposition -ne 'stdout') {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-accepted-without-stdout-disposition' }
        }
        if ($retentionCleanupFailed) {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-accepted-with-retention-cleanup-failed' }
        }
        if ([string]::IsNullOrWhiteSpace([string]$StdoutText)) {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-accepted-with-empty-stdout' }
        }
        $hash = [string](Get-Prop $Sidecar 'acceptedFinalTextSha256')
        if ([string]::IsNullOrWhiteSpace($hash) -or $hash -ne (Get-TextSha256 -Text ([string]$StdoutText))) {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-accepted-hash-mismatch' }
        }
        $bytes = Get-Prop $Sidecar 'acceptedFinalTextBytes'
        if ($bytes -isnot [int] -and $bytes -isnot [long]) {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-accepted-bytes-invalid' }
        }
        if ([long]$bytes -ne [System.Text.Encoding]::UTF8.GetByteCount([string]$StdoutText)) {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-accepted-bytes-mismatch' }
        }
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace([string]$StdoutText)) {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-rejected-with-stdout' }
        }
        if ($finalTextDisposition -eq 'stdout') {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-rejected-with-stdout-disposition' }
        }
        if ($null -ne (Get-Prop $Sidecar 'acceptedFinalTextSha256')) {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-rejected-with-accepted-hash' }
        }
        if ($null -ne (Get-Prop $Sidecar 'acceptedFinalTextBytes')) {
            return [pscustomobject]@{ accepted = $false; reason = 'sidecar-rejected-with-accepted-bytes' }
        }
    }
    return [pscustomobject]@{ accepted = $true; reason = 'ok' }
}

function Convert-ClaudeCodeSidecarToPanelState {
    param([object]$Sidecar)
    $technicalStatus = [string](Get-Prop $Sidecar 'technicalStatus')
    $resultAccepted = [bool](Get-Prop $Sidecar 'resultAccepted')
    if ($technicalStatus -eq 'completed' -and $resultAccepted) { return [pscustomobject]@{ state = 'responded'; reason = $null } }
    if ($technicalStatus -eq 'completed') { return [pscustomobject]@{ state = 'error'; reason = 'completed-without-accepted-result' } }
    switch ($technicalStatus) {
        'timeout' { return [pscustomobject]@{ state = 'timeout'; reason = [string](Get-Prop $Sidecar 'acceptanceRejectionReason') } }
        'quota' { return [pscustomobject]@{ state = 'quota'; reason = [string](Get-Prop $Sidecar 'acceptanceRejectionReason') } }
        'unavailable' { return [pscustomobject]@{ state = 'unavailable'; reason = [string](Get-Prop $Sidecar 'acceptanceRejectionReason') } }
        'internalError' { return [pscustomobject]@{ state = 'error'; reason = [string](Get-Prop $Sidecar 'acceptanceRejectionReason') } }
        'cancelled' { return [pscustomobject]@{ state = 'error'; reason = 'unexpected-cancelled-status' } }
        default { return [pscustomobject]@{ state = 'error'; reason = "unexpected-technical-status:$technicalStatus" } }
    }
}

$scriptsDir = $PSScriptRoot
$gateScript = Join-Path $scriptsDir 'Resolve-LlmDelegateAuthorization.ps1'
if (-not (Test-Path -LiteralPath $gateScript -PathType Leaf)) {
    throw "BLOCK: gate nao encontrado: $gateScript"
}

if ([string]::IsNullOrWhiteSpace($RoundId)) { $RoundId = [guid]::NewGuid().ToString('N') }
# Mesma higiene do New-LlmDelegatePeerReviewArtifacts: RoundId entra em ledger e em
# %TEMP%\xpz-llm-panel-codex\<RoundId> — fail-closed contra chars inseguros / traversal.
if ($RoundId -match '[^A-Za-z0-9._-]' -or $RoundId -match '\.\.' -or $RoundId -match '[/\\]') {
    throw "BLOCK: RoundId inseguro: '$RoundId'. Use apenas letras, numeros, ponto, hifen e underscore."
}

$tempRoot = $TempDir
if ([string]::IsNullOrWhiteSpace($tempRoot)) {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'xpz-llm-panel-dispatch'
}

# 0) Precondicoes de chamador: exatamente um entre -ManuscriptPath e -ManuscriptText
$useManuscriptText = ($PSBoundParameters.ContainsKey('ManuscriptText'))
$useManuscriptPath = ($PSBoundParameters.ContainsKey('ManuscriptPath'))
if ($useManuscriptText -eq $useManuscriptPath) {
    $failureCode = if ($useManuscriptText) { 'manuscript-source-ambiguous' } else { 'manuscript-source-missing' }
    $message = if ($useManuscriptText) {
        'Informe apenas um entre -ManuscriptText e -ManuscriptPath.'
    } else {
        'Informe exatamente um entre -ManuscriptText e -ManuscriptPath.'
    }
    $blockResult = [ordered]@{
        Kind                         = 'xpz-llm-panel-dispatch-result'
        SchemaVersion                = 3
        success                      = $false
        roundStarted                 = $false
        dispatchStarted              = $false
        reviewersDispatched          = 0
        reviewersDispatchAttempted   = 0
        reviewersProcessCreated      = 0
        processCreatedUnknownCount   = 0
        preDispatchBlockedCount      = 0
        sidecarAcceptedCount         = 0
        sidecarRejectedCount         = 0
        fallbackSuppressedCount      = 0
        roundId                      = $RoundId
        payloadSensitivity           = $PayloadSensitivity
        parallelKbRoot               = $null
        policyPath                   = $null
        manuscriptPath               = $null
        ollamaConcurrency            = $OllamaConcurrency
        reviewers                    = @()
        dispatched                   = 0
        respondedCount               = 0
        errorCount                   = 0
        timeoutCount                 = 0
        quotaCount                   = 0
        unavailableCount             = 0
        gateAsk                      = 0
        gateDeny                     = 0
        ollamaQuotaWarning           = $null
        concurrencySaturationWarning = $null
        preparationError             = [ordered]@{
            failureStage = 'parameter-validation'
            failureCode  = $failureCode
            message      = $message
        }
    }
    [Console]::Error.WriteLine("BLOCK: ${failureCode}: $message")
    [Console]::Out.WriteLine(($blockResult | ConvertTo-Json -Compress -Depth 8))
    exit 1
}
if ($useManuscriptText -and $ManuscriptText.Length -gt $MaxInlineManuscriptChars) {
    $blockResult = [ordered]@{
        Kind                         = 'xpz-llm-panel-dispatch-result'
        SchemaVersion                = 3
        success                      = $false
        roundStarted                 = $false
        dispatchStarted              = $false
        reviewersDispatched          = 0
        reviewersDispatchAttempted   = 0
        reviewersProcessCreated      = 0
        processCreatedUnknownCount   = 0
        preDispatchBlockedCount      = 0
        sidecarAcceptedCount         = 0
        sidecarRejectedCount         = 0
        fallbackSuppressedCount      = 0
        roundId                      = $RoundId
        payloadSensitivity           = $PayloadSensitivity
        parallelKbRoot               = $null
        policyPath                   = $null
        manuscriptPath               = $null
        ollamaConcurrency            = $OllamaConcurrency
        reviewers                    = @()
        dispatched                   = 0
        respondedCount               = 0
        errorCount                   = 0
        timeoutCount                 = 0
        quotaCount                   = 0
        unavailableCount             = 0
        gateAsk                      = 0
        gateDeny                     = 0
        ollamaQuotaWarning           = $null
        concurrencySaturationWarning = $null
        preparationError             = [ordered]@{
            failureStage = 'parameter-validation'
            failureCode  = 'manuscript-text-too-large'
            message      = "-ManuscriptText excede $MaxInlineManuscriptChars caracteres; use -ManuscriptPath para payload grande."
        }
    }
    [Console]::Error.WriteLine("BLOCK: manuscript-text-too-large: -ManuscriptText excede $MaxInlineManuscriptChars caracteres; use -ManuscriptPath.")
    [Console]::Out.WriteLine(($blockResult | ConvertTo-Json -Compress -Depth 8))
    exit 1
}
if ($useManuscriptPath) {
    if (-not (Test-Path -LiteralPath $ManuscriptPath -PathType Leaf)) {
        $blockResult = [ordered]@{
            Kind                         = 'xpz-llm-panel-dispatch-result'
            SchemaVersion                = 3
            success                      = $false
            roundStarted                 = $false
            dispatchStarted              = $false
            reviewersDispatched          = 0
            reviewersDispatchAttempted   = 0
            reviewersProcessCreated      = 0
            processCreatedUnknownCount   = 0
            preDispatchBlockedCount      = 0
            sidecarAcceptedCount         = 0
            sidecarRejectedCount         = 0
            fallbackSuppressedCount      = 0
            roundId                      = $RoundId
            payloadSensitivity           = $PayloadSensitivity
            parallelKbRoot               = $null
            policyPath                   = $null
            manuscriptPath               = $null
            ollamaConcurrency            = $OllamaConcurrency
            reviewers                    = @()
            dispatched                   = 0
            respondedCount               = 0
            errorCount                   = 0
            timeoutCount                 = 0
            quotaCount                   = 0
            unavailableCount             = 0
            gateAsk                      = 0
            gateDeny                     = 0
            ollamaQuotaWarning           = $null
            concurrencySaturationWarning = $null
            preparationError             = [ordered]@{
                failureStage = 'parameter-validation'
                failureCode  = 'manuscript-path-not-found'
                message      = "-ManuscriptPath nao encontrado: $ManuscriptPath"
            }
        }
        [Console]::Error.WriteLine("BLOCK: manuscript-path-not-found: -ManuscriptPath nao encontrado.")
        [Console]::Out.WriteLine(($blockResult | ConvertTo-Json -Compress -Depth 8))
        exit 1
    }
    $manuscriptFull = (Resolve-Path -LiteralPath $ManuscriptPath).Path
    $ledgerDir = Join-Path $tempRoot $RoundId
    New-Item -ItemType Directory -Path $ledgerDir -Force | Out-Null
} else {
    # -ManuscriptText: preparar artefatos transacionalmente
    $preparerScript = Join-Path $scriptsDir 'New-LlmDelegatePeerReviewArtifacts.ps1'
    if (-not (Test-Path -LiteralPath $preparerScript -PathType Leaf)) {
        throw "BLOCK: preparador de artefatos nao encontrado: $preparerScript"
    }
    $prepReviewers = if (Test-Path -LiteralPath $ReviewersJson -PathType Leaf) {
        Get-Content -LiteralPath $ReviewersJson -Raw -Encoding utf8
    } else {
        $ReviewersJson
    }
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    $prepGuid = [guid]::NewGuid().ToString('N')
    $prepInputPath = Join-Path $tempRoot ".dispatch-prep-$prepGuid.manuscript.md"
    $prepReviewersPath = Join-Path $tempRoot ".dispatch-prep-$prepGuid.reviewers.json"
    $prepStdoutPath = Join-Path $tempRoot ".dispatch-prep-$prepGuid.stdout"
    $prepStderrPath = Join-Path $tempRoot ".dispatch-prep-$prepGuid.stderr"
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($prepInputPath, $ManuscriptText, $utf8NoBom)
    [System.IO.File]::WriteAllText($prepReviewersPath, $prepReviewers, $utf8NoBom)

    $prepExitCode = $null
    $prepJson = $null
    $prepFailureMessage = $null
    try {
        $prepArgList = @(
            '-NoProfile',
            '-File', $preparerScript,
            '-ManuscriptPath', $prepInputPath,
            '-ReviewersJson', $prepReviewersPath,
            '-RoundId', $RoundId,
            '-TempDir', $tempRoot
        )
        $prepProcess = Start-Process -FilePath (Get-CurrentPowerShellExecutable) -ArgumentList $prepArgList -NoNewWindow -PassThru -RedirectStandardOutput $prepStdoutPath -RedirectStandardError $prepStderrPath
        if (-not $prepProcess.WaitForExit(120000)) {
            try { $prepProcess.Kill() } catch { }
            $prepExitCode = 124
            $prepFailureMessage = 'Preparador de artefatos excedeu 120s e foi encerrado.'
        } else {
            $prepExitCode = [int]$prepProcess.ExitCode
        }

        $prepStdout = Get-Content -LiteralPath $prepStdoutPath -Raw -Encoding utf8 -ErrorAction SilentlyContinue
        if ($null -eq $prepStdout) { $prepStdout = '' }
        if (-not [string]::IsNullOrWhiteSpace($prepStdout)) {
            $prepJsonLine = @($prepStdout.Trim() -split "`r?`n") | Select-Object -Last 1
            try { $prepJson = $prepJsonLine | ConvertFrom-Json } catch { $prepFailureMessage = "Preparador retornou JSON invalido: $($_.Exception.Message)" }
        } elseif ($null -eq $prepFailureMessage) {
            $prepFailureMessage = 'Preparador nao emitiu JSON no stdout.'
        }
    } finally {
        foreach ($p in @($prepInputPath, $prepReviewersPath, $prepStdoutPath, $prepStderrPath)) {
            try { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue } catch { }
        }
    }

    $prepSuccess = $false
    if ($null -ne $prepJson -and $prepJson.PSObject.Properties['success']) {
        $prepSuccess = [bool]$prepJson.success
    }
    if ($prepExitCode -ne 0 -or -not $prepSuccess) {
        $failureStage = 'artifactPreparation'
        $failureCode = 'artifact-preparation-failed'
        $message = $prepFailureMessage
        if ($null -ne $prepJson) {
            if ($prepJson.PSObject.Properties['failureStage']) { $failureStage = [string]$prepJson.failureStage }
            if ($prepJson.PSObject.Properties['failureCode']) { $failureCode = [string]$prepJson.failureCode }
            if ($prepJson.PSObject.Properties['message']) { $message = [string]$prepJson.message }
        }
        if ([string]::IsNullOrWhiteSpace($message)) { $message = 'Preparacao de artefatos falhou.' }
        $blockResult = [ordered]@{
            Kind                         = 'xpz-llm-panel-dispatch-result'
            SchemaVersion                = 3
            success                      = $false
            roundStarted                 = $false
            dispatchStarted              = $false
            reviewersDispatched          = 0
            reviewersDispatchAttempted   = 0
            reviewersProcessCreated      = 0
            processCreatedUnknownCount   = 0
            preDispatchBlockedCount      = 0
            sidecarAcceptedCount         = 0
            sidecarRejectedCount         = 0
            fallbackSuppressedCount      = 0
            roundId                      = $RoundId
            payloadSensitivity           = $PayloadSensitivity
            parallelKbRoot               = $null
            policyPath                   = $null
            manuscriptPath               = $null
            ollamaConcurrency            = $OllamaConcurrency
            reviewers                    = @()
            dispatched                   = 0
            respondedCount               = 0
            errorCount                   = 0
            timeoutCount                 = 0
            quotaCount                   = 0
            unavailableCount             = 0
            gateAsk                      = 0
            gateDeny                     = 0
            ollamaQuotaWarning           = $null
            concurrencySaturationWarning = $null
            preparationError             = [ordered]@{
                failureStage = $failureStage
                failureCode  = $failureCode
                message      = $message
            }
        }
        $blockJson = $blockResult | ConvertTo-Json -Compress -Depth 8
        [Console]::Error.WriteLine("BLOCK: preparacao de artefatos falhou: $failureCode - $message")
        [Console]::Out.WriteLine($blockJson)
        exit 1
    }
    $manuscriptFull = [string]$prepJson.artifactPaths.manuscript
    $ReviewersJson = [string]$prepJson.artifactPaths.reviewers
    $ledgerDir = Join-Path $tempRoot $RoundId
}

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
$script:LedgerSeq = 0

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
        ledgerIndex        = $script:LedgerSeq++
        entryIndex         = $i
        suppressedFallbackChain = @()
        dispatchChannel    = 'cli'
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
        dispatchAttempted  = $false
        preDispatchBlocked = $false
        processCreated     = $null
        sidecarPath        = $null
        sidecarAccepted    = $null
        sidecarValidationReason = $null
        technicalStatus    = $null
        resultAccepted     = $null
        acceptanceRejectionReason = $null
        acceptedFinalTextSha256 = $null
        acceptedFinalTextBytes = $null
        promptTransmission = $null
        quotaCircuitDecision = $null
        quotaCircuitVariantDecisions = @()
        fallbackSuppressedReason = $null
        adapterReceiptPath = $null
        publicReviewProfile = $null
        cliVersion = $null
        cliVersionMatchesBaseline = $null
        cleanupStatus = $null
        cleanupIssues = @()
        keyringIsolation = $null
        recoveredAfterTimeout = $null
    }

    # Defesa em profundidade: nativo nao despacha neste harness
    if ($rec.backend -eq 'orchestrator-native') {
        $rec.state = 'error'
        $rec.reason = 'orchestrator-native-leaked-to-dispatch'
        $rec.dispatchAttempted = $false
        $rec.attempts = 0
        $rec.countsForDiversity = $false
        $rec.suppressedFallbackChain = @($rec.fallbackChain)
        $rec.fallbackChain = @()
        $rec.entryIndex = $i
        $records.Add($rec)
        continue
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
    $timeoutSecParseError = $null
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
            if ($kl -eq 'timeoutsec') {
                # GAP-2: nao usar [int]$v (throw global). Revisor local em error; painel segue.
                $parsedTs = 0
                if (-not [int]::TryParse([string]$v, [ref]$parsedTs) -or $parsedTs -lt 1 -or $parsedTs -gt 3600) {
                    $timeoutSecParseError = "invokeArgs.timeoutSec invalido: '$v' (exige inteiro 1..3600)"
                } else {
                    $extraSplat['TimeoutSec'] = $parsedTs
                }
                continue
            }
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

    if ($null -ne $timeoutSecParseError) {
        $rec.state = 'error'
        $rec.reason = $timeoutSecParseError
        if (-not $rec.family -and $inputKey) { $rec.family = Get-LlmDelegateTargetFamily -TargetModelKey $inputKey }
        $records.Add($rec); continue
    }

    # --- opencode em kb-sensitive: terminal unavailable (sem gate/despacho) ---
    if ($backend -eq 'opencode' -and $PayloadSensitivity -eq 'kb-sensitive') {
        $rec.state = 'unavailable'
        $rec.reason = 'opencode em kb-sensitive: confinamento por agente custom diferido (frente 999); sem gate nem despacho'
        if (-not $rec.family -and $inputKey) { $rec.family = Get-LlmDelegateTargetFamily -TargetModelKey $inputKey }
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
        # claude-code / copilot / gemini / antigravity -> invokeArgs.model OBRIGATORIO
        if (-not $invModel) {
            $rec.state = 'error'
            $rec.reason = "invokeArgs.model obrigatorio para backend ${backend}: o default do adapter e implicito e pode divergir da chave resolvida pelo gate; exigir model torna o destino declarado e auditavel"
            if (-not $rec.family -and $inputKey) { $rec.family = Get-LlmDelegateTargetFamily -TargetModelKey $inputKey }
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
        if (-not $rec.family -and $inputKey) { $rec.family = Get-LlmDelegateTargetFamily -TargetModelKey $inputKey }
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
            if (-not $rec.family -and $inputKey) { $rec.family = Get-LlmDelegateTargetFamily -TargetModelKey $inputKey }
            $records.Add($rec); continue
        }
        $effectiveModel = @($returnedKey -split '/')[-1]
    }
    $rec.effectiveModel = $effectiveModel

    # family definitiva
    if (-not $rec.family) {
        if ($returnedKey) { $rec.family = Get-LlmDelegateTargetFamily -TargetModelKey $returnedKey }
        elseif ($inputKey) { $rec.family = Get-LlmDelegateTargetFamily -TargetModelKey $inputKey }
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

    # Antigravity public-review e exclusivamente publico. O gate continua dono da confidencialidade
    # e sempre roda primeiro: ask/deny preservam seus estados normativos. Se uma politica duravel
    # permitir kb-sensitive, a postura fixa recusa o despacho antes do adapter e registra a
    # divergencia como unavailable + refusedSensitivity; o adapter nao classifica o payload.
    if ($backend -eq 'antigravity' -and $PayloadSensitivity -eq 'kb-sensitive') {
        $rec.state = 'unavailable'
        $rec.reason = 'refusedSensitivity'
        $rec.preDispatchBlocked = $true
        $rec.publicReviewProfile = 'public-review'
        $records.Add($rec); continue
    }

    # --- allow: monta o despacho ---
    $splat = @{ MessagePath = $manuscriptFull; Model = $effectiveModel }

    # -Cd: precedencia + fail-closed (opencode nunca recebe -Cd)
    $cdCapable = [bool]$AdapterCdCapable[$backend]
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

    # Claude Code no painel usa adapter assincrono tipado: o dispatcher valida o sidecar tecnico
    # e so aceita stdout como parecer quando resultAccepted=true.
    if ($backend -eq 'claude-code') {
        $sidecarPath = Join-Path $ledgerDir ('{0:D2}-claude-code.sidecar.json' -f $i)
        $splat['SidecarPath'] = $sidecarPath
        $splat['RetentionMode'] = $PayloadSensitivity
        $splat['TempDir'] = $ledgerDir
        if (-not [string]::IsNullOrWhiteSpace($ClaudeCircuitStateRoot)) {
            $splat['CircuitStateRoot'] = $ClaudeCircuitStateRoot
        }
        $rec.sidecarPath = $sidecarPath
    }
    elseif ($backend -eq 'codex') {
        # TempDir FORA do -Cd/workspace sob revisao: job files (request/stream/lastmsg) no %TEMP%
        # evitam o agente explorar artefatos do proprio despacho. Ledger do painel continua em
        # $ledgerDir (verdict/error). Bound vence; invokeArgs.tempdir cai em droppedArgs.
        $codexCaptureRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'xpz-llm-panel-codex'
        $codexCaptureDir = Join-Path $codexCaptureRoot $RoundId
        [void][System.IO.Directory]::CreateDirectory($codexCaptureDir)
        $splat['RetentionMode'] = $PayloadSensitivity
        $splat['TempDir'] = $codexCaptureDir
    }
    elseif ($backend -eq 'antigravity') {
        $receiptPath = Join-Path $ledgerDir ('{0:D2}-antigravity-public-review.receipt.json' -f $i)
        $splat['Profile'] = 'public-review'
        $splat['ReceiptPath'] = $receiptPath
        $rec.adapterReceiptPath = $receiptPath
        $rec.publicReviewProfile = 'public-review'
    }

    # TimeoutSec: so codex/opencode (defaults de adapter 180 < mapa 1200). Demais backends
    # mantem o default do proprio adapter (300) — evita apertar teto por injecao universal.
    if (-not $extraSplat.ContainsKey('TimeoutSec') -and $backend -in @('codex', 'opencode') -and
        $AdapterDefaultTimeoutSec.ContainsKey($backend)) {
        $extraSplat['TimeoutSec'] = [int]$AdapterDefaultTimeoutSec[$backend]
    }

    # args allowlistados (TimeoutSec / codex Profile/Oss/LocalProvider)
    foreach ($ek in $extraSplat.Keys) { $splat[$ek] = $extraSplat[$ek] }

    $adapterPath = Join-Path $scriptsDir $AdapterScript[$backend]
    $dispatchList.Add([pscustomobject]@{
        index       = $i
        backend     = $backend
        family      = $rec.family
        adapterPath = $adapterPath
        splat       = $splat
        sidecarPath = if ($backend -eq 'claude-code') { $rec.sidecarPath } else { $null }
        adapterReceiptPath = if ($backend -eq 'antigravity') { $rec.adapterReceiptPath } else { $null }
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
            $unavailablePattern = $using:unavailableFailurePattern
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
                if ($item.backend -eq 'claude-code') {
                    $state = 'PENDING-SIDECAR'
                    $textOut = $joined
                    if ($null -ne $errRec) { $errText = [string]$errRec.Exception.Message }
                }
                elseif ($null -ne $errRec) {
                    # $errText = mensagem completa (sentinelas XPZ_CODEX_* + captura kb-sensitive).
                    # $msgClassificado = prefixo ANTES da primeira linha XPZ_CODEX_ (apos normalizar
                    # \r\n -> \n). NAO chamar funcao do runspace pai — inline / $using: apenas.
                    $errText = [string]$errRec.Exception.Message
                    $errNorm = $errText -replace "`r`n", "`n"
                    $msgClassificado = $errNorm
                    $cut = -1
                    if ($errNorm.StartsWith('XPZ_CODEX_')) {
                        $cut = 0
                    } else {
                        $marker = "`nXPZ_CODEX_"
                        $cut = $errNorm.IndexOf($marker)
                    }
                    if ($cut -eq 0) {
                        $msgClassificado = ''
                    } elseif ($cut -gt 0) {
                        $msgClassificado = $errNorm.Substring(0, $cut)
                    }
                    $msg = $msgClassificado
                    if ($msg -match 'BLOCK:' -and $msg -match $quotaPattern) {
                        $state = 'quota'
                    # `refusedSensitivity` NAO entra aqui: o adapter nunca a emite (nao recebe
                    # sensibilidade) e o bloqueio pre-despacho registra o estado e faz `continue`
                    # antes de qualquer chamada, entao este classificador jamais a veria.
                    } elseif ($item.backend -eq 'antigravity' -and $msg -match 'reason=(cliMissing|inputTooLarge|unsafeWorkspace)') {
                        $state = 'unavailable'
                    } elseif ($item.backend -eq 'antigravity' -and $msg -match 'reason=timeout') {
                        $state = 'timeout'
                    } elseif ($msg -match 'BLOCK:' -and $msg -match $unavailablePattern) {
                        $state = 'unavailable'
                    } elseif ($msg -match 'excedeu' -and $msg -match 'foi encerrado') {
                        $state = 'timeout'
                    } else {
                        $state = 'error'
                    }
                    # errorPath / __errorText usam $errText completo (sentinelas + captura).
                }                 else {
                    if ([string]::IsNullOrWhiteSpace($joined)) {
                        $state = 'error'
                        $errText = 'BLOCK: adapter retornou texto vazio (defensivo).'
                    } else {
                        $state = 'responded'
                        $textOut = $joined
                    }
                }

                # GAP-3: projetar recoveredAfterTimeout do request.json Codex (pareamento por lastmsg).
                $recoveredAfterTimeout = $null
                if ($state -eq 'responded' -and $item.backend -eq 'codex' -and -not [string]::IsNullOrWhiteSpace($textOut)) {
                    $recoveredAfterTimeout = $false
                    try {
                        $codexTd = $null
                        if ($null -ne $item.splat -and $item.splat.ContainsKey('TempDir')) {
                            $codexTd = [string]$item.splat['TempDir']
                        }
                        if (-not [string]::IsNullOrWhiteSpace($codexTd) -and (Test-Path -LiteralPath $codexTd -PathType Container)) {
                            $want = $textOut.TrimEnd("`r", "`n")
                            foreach ($lm in @(Get-ChildItem -LiteralPath $codexTd -Filter '*.lastmsg.txt' -File -ErrorAction SilentlyContinue)) {
                                $body = Get-Content -LiteralPath $lm.FullName -Raw -Encoding utf8 -ErrorAction SilentlyContinue
                                if ($null -eq $body) { continue }
                                if ($body.TrimEnd("`r", "`n") -ne $want) { continue }
                                $reqSibling = $lm.FullName -replace '\.lastmsg\.txt$', '.request.json'
                                if (-not (Test-Path -LiteralPath $reqSibling -PathType Leaf)) { break }
                                $ro = Get-Content -LiteralPath $reqSibling -Raw -Encoding utf8 | ConvertFrom-Json
                                if ($null -ne $ro -and $ro.PSObject.Properties['recoveredAfterTimeout'] -and [bool]$ro.recoveredAfterTimeout) {
                                    $recoveredAfterTimeout = $true
                                }
                                break
                            }
                        }
                    } catch {
                        $recoveredAfterTimeout = $false
                    }
                }

                $result = [pscustomobject]@{
                    index      = $item.index
                    backend    = $item.backend
                    state      = $state
                    text       = $textOut
                    errorText  = $errText
                    startedAt  = $startedAt.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    endedAt    = $endedAt.ToString('yyyy-MM-ddTHH:mm:ssZ')
                    durationMs = [long]($endedAt - $startedAt).TotalMilliseconds
                    attempts   = 1
                    sidecarPath = $item.sidecarPath
                    adapterReceiptPath = $item.adapterReceiptPath
                    recoveredAfterTimeout = $recoveredAfterTimeout
                }
            } catch {
                # Defesa em profundidade: qualquer excecao inesperada no runspace (ex.: Wait,
                # Get-Date) vira um resultado 'error' — nunca escapa do bloco (conforme v11).
                $result = [pscustomobject]@{
                    index      = $item.index
                    backend    = $item.backend
                    state      = 'error'
                    text       = $null
                    errorText  = "BLOCK: falha inesperada no runspace: $($_.Exception.Message)"
                    startedAt  = $null
                    endedAt    = $null
                    durationMs = $null
                    attempts   = 1
                    sidecarPath = $item.sidecarPath
                    adapterReceiptPath = $item.adapterReceiptPath
                    recoveredAfterTimeout = $null
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
    $rec.startedAt = $res.startedAt
    $rec.endedAt = $res.endedAt
    $rec.durationMs = $res.durationMs
    $rec.attempts = $res.attempts
    $rec.dispatchAttempted = ([int]$res.attempts -ge 1)

    if ([string]$rec.backend -eq 'claude-code') {
        $rec.sidecarPath = [string]$res.sidecarPath
        $sidecar = $null
        $sidecarReadReason = $null
        if (-not [string]::IsNullOrWhiteSpace([string]$rec.sidecarPath) -and (Test-Path -LiteralPath ([string]$rec.sidecarPath) -PathType Leaf)) {
            $sidecarRead = Read-PanelJsonFileWithDeadline -Path ([string]$rec.sidecarPath) -DeadlineMs 250
            if ($sidecarRead.status -eq 'ok') { $sidecar = $sidecarRead.value }
            else { $sidecarReadReason = "sidecar-$($sidecarRead.status):$($sidecarRead.error)" }
        }
        else {
            $sidecarReadReason = 'sidecar-file-missing'
        }

        $validation = if ($null -eq $sidecar) {
            [pscustomobject]@{ accepted = $false; reason = $sidecarReadReason }
        }
        else {
            Test-ClaudeCodeSidecarShape -Sidecar $sidecar -StdoutText ([string]$res.text)
        }
        $rec.sidecarAccepted = [bool]$validation.accepted
        $rec.sidecarValidationReason = [string]$validation.reason

        if (-not [bool]$validation.accepted) {
            $rec.state = 'error'
            $rec.reason = "claude-code-sidecar-rejected:$($validation.reason)"
            if (-not [string]::IsNullOrWhiteSpace([string]$res.errorText)) {
                $rec.reason = "$($rec.reason); adapterError=$($res.errorText)"
            }
            $rec['__text'] = $null
            $rec['__errorText'] = $rec.reason
            continue
        }

        $projection = Convert-ClaudeCodeSidecarToPanelState -Sidecar $sidecar
        $rec.state = [string]$projection.state
        $rec.technicalStatus = [string](Get-Prop $sidecar 'technicalStatus')
        $rec.resultAccepted = [bool](Get-Prop $sidecar 'resultAccepted')
        $rec.acceptanceRejectionReason = [string](Get-Prop $sidecar 'acceptanceRejectionReason')
        $rec.acceptedFinalTextSha256 = Get-Prop $sidecar 'acceptedFinalTextSha256'
        $rec.acceptedFinalTextBytes = Get-Prop $sidecar 'acceptedFinalTextBytes'
        $rec.promptTransmission = [string](Get-Prop $sidecar 'promptTransmission')
        $rec.processCreated = [bool](Get-Prop $sidecar 'processCreated')
        $rec.quotaCircuitDecision = [string](Get-Prop $sidecar 'quotaCircuitDecision')
        $quotaEvidence = Get-Prop $sidecar 'quotaEvidence'
        $rec.quotaCircuitVariantDecisions = @(Get-Prop $quotaEvidence 'variantDecisions')
        $spawnAttempted = [bool](Get-Prop $sidecar 'spawnAttempted')
        $rec.preDispatchBlocked = (-not $spawnAttempted -and [string]$rec.promptTransmission -eq 'none')
        $reason = [string]$projection.reason
        if ([string]::IsNullOrWhiteSpace($reason)) { $reason = [string]$rec.acceptanceRejectionReason }
        if (-not [string]::IsNullOrWhiteSpace($reason)) { $rec.reason = $reason }
        $rec['__text'] = if ($rec.state -eq 'responded') { $res.text } else { $null }
        $rec['__errorText'] = if ($rec.state -eq 'responded') { $null } else { $rec.reason }
        continue
    }

    if ([string]$rec.backend -eq 'antigravity') {
        $rec.adapterReceiptPath = [string]$res.adapterReceiptPath
        $receipt = $null
        if (-not [string]::IsNullOrWhiteSpace([string]$rec.adapterReceiptPath) -and
            (Test-Path -LiteralPath ([string]$rec.adapterReceiptPath) -PathType Leaf)) {
            try { $receipt = Get-Content -LiteralPath ([string]$rec.adapterReceiptPath) -Raw -Encoding utf8 | ConvertFrom-Json } catch { $receipt = $null }
        }
        if ($null -eq $receipt -or [string](Get-Prop $receipt 'Kind') -ne 'antigravity-public-review-receipt' -or
            [int](Get-Prop $receipt 'SchemaVersion') -ne 1 -or [string](Get-Prop $receipt 'Profile') -ne 'public-review') {
            $rec.state = 'error'
            $rec.reason = 'invalidOutput'
            $rec['__text'] = $null
            $rec['__errorText'] = 'invalidOutput: recibo public-review ausente ou invalido'
            continue
        }
        $rec.cliVersion = [string](Get-Prop $receipt 'CliVersion')
        $rec.cliVersionMatchesBaseline = [bool](Get-Prop $receipt 'CliVersionMatchesBaseline')
        $rec.cleanupStatus = [string](Get-Prop $receipt 'CleanupStatus')
        $rec.cleanupIssues = @(Get-Prop $receipt 'CleanupIssues')
        $rec.keyringIsolation = [string](Get-Prop $receipt 'KeyringIsolation')
        $receiptReason = [string](Get-Prop $receipt 'Reason')
        if (-not [string]::IsNullOrWhiteSpace($receiptReason)) {
            # PRECEDENCIA: a classificacao de estado por sentinela especifica (cota/timeout)
            # vence a reason do recibo. O adapter nao conhece cota — um `agy` que sai por
            # limite de uso vira `processFailure` no recibo enquanto o dispatcher ja
            # classificou `quota` pelo texto. Sobrescrever cru produzia o par contraditorio
            # `state=quota` + `reason=processFailure`, apagando do campo lido pelo operador
            # a unica evidencia de cota (e o recibo humano de `quota` tem tratamento proprio,
            # alem de a fallbackChain ativar nesse estado). Compor preserva as duas leituras
            # em vez de o dispatcher escolher qual verdade descartar.
            if ($res.state -in @('quota', 'timeout') -and $receiptReason -ne [string]$res.state) {
                $rec.reason = ('{0}; adapterReason={1}' -f $res.state, $receiptReason)
            } else {
                $rec.reason = $receiptReason
            }
        }
    }

    $rec.state = $res.state
    $rec['__text'] = $res.text
    $rec['__errorText'] = $res.errorText
    if ($null -ne (Get-Prop $res 'recoveredAfterTimeout')) {
        $rec.recoveredAfterTimeout = [bool](Get-Prop $res 'recoveredAfterTimeout')
    }
    if ([string]::IsNullOrWhiteSpace([string]$rec.reason) -and -not [string]::IsNullOrWhiteSpace([string]$res.errorText)) {
        $rec.reason = [string]$res.errorText
    }
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
    # Leak nativo: fonte efetiva e suppressedFallbackChain (fallbackChain ja vazia)
    if ([string]$rec.reason -eq 'orchestrator-native-leaked-to-dispatch') {
        $suppressed = @($rec.suppressedFallbackChain)
        if ($suppressed.Count -gt 0) {
            Add-SkippedFallbackRecords -Records $records -FallbackItems $suppressed -FallbackOf ([string]$rec.targetModelKey) `
                -State 'skippedByPolicy' -Reason 'fallback nao tentado porque o primario nativo vazou no dispatcher' `
                -BaseRank ([int]$rec.rank) -FallbackSuppressedReason 'primary-native-leaked' -EntryIndex ([int]$rec.entryIndex)
        }
        continue
    }
    $fallbackItems = @($rec.fallbackChain)
    if ($fallbackItems.Count -eq 0) { continue }
    if ($rec.state -eq 'responded') {
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'skippedAfterSuccess' -Reason 'fallback nao tentado porque o primario respondeu' -BaseRank ([int]$rec.rank) -EntryIndex ([int]$rec.entryIndex)
        continue
    }
    if ([string]$rec.state -eq 'error' -and [int]$rec.attempts -eq 0 -and [string]$rec.reason -like 'BLOCK:*') {
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'skippedByPolicy' -Reason "fallback nao tentado por erro de validacao pre-despacho: $($rec.reason)" -BaseRank ([int]$rec.rank) -EntryIndex ([int]$rec.entryIndex)
        continue
    }
    if ([bool]$rec.preDispatchBlocked) {
        $rec.fallbackSuppressedReason = 'pre-dispatch-block-not-fallback-safe'
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'skippedByPolicy' -Reason "fallback nao tentado porque o primario foi bloqueado antes de enviar prompt: $($rec.reason)" `
            -BaseRank ([int]$rec.rank) -FallbackSuppressedReason ([string]$rec.fallbackSuppressedReason) -EntryIndex ([int]$rec.entryIndex)
        continue
    }
    if ($skipPolicyStates -contains [string]$rec.state) {
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'skippedByPolicy' -Reason "fallback nao tentado porque o primario terminou em $($rec.state)" -BaseRank ([int]$rec.rank) -EntryIndex ([int]$rec.entryIndex)
        continue
    }
    if ($activateFallbackOn -notcontains [string]$rec.state) {
        Add-SkippedFallbackRecords -Records $records -FallbackItems $fallbackItems -FallbackOf ([string]$rec.targetModelKey) `
            -State 'notAttempted' -Reason "fallback nao alcançado; estado primario=$($rec.state)" -BaseRank ([int]$rec.rank) -EntryIndex ([int]$rec.entryIndex)
        continue
    }

    $fallbackSucceeded = $false
    for ($fbIdx = 0; $fbIdx -lt $fallbackItems.Count; $fbIdx++) {
        $fb = $fallbackItems[$fbIdx]
        if ($fallbackSucceeded) {
            Add-SkippedFallbackRecords -Records $records -FallbackItems @($fb) -FallbackOf ([string]$rec.targetModelKey) `
                -State 'skippedAfterSuccess' -Reason 'fallback nao tentado porque tentativa anterior da cadeia respondeu' -BaseRank ([int]$rec.rank) -EntryIndex ([int]$rec.entryIndex)
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
        if ($ClaudeCircuitStateRoot) { $fbArgs['ClaudeCircuitStateRoot'] = $ClaudeCircuitStateRoot }

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
            foreach ($optionalKey in @('Cd', 'ParallelKbRoot', 'PolicyPath', 'OpenCodeConfigPath', 'CodexConfigPath', 'BackendExeMap', 'ClaudeCircuitStateRoot')) {
                if ($fbArgs.ContainsKey($optionalKey)) { $argList += @("-$optionalKey", [string]$fbArgs[$optionalKey]) }
            }
            $p = Start-Process -FilePath (Get-CurrentPowerShellExecutable) -ArgumentList $argList -NoNewWindow -PassThru `
                -RedirectStandardOutput $fbOutPath -RedirectStandardError $fbErrPath
            $fallbackDispatcherTimeoutMs = Get-FallbackDispatcherTimeoutMs -Backend ([string]$fbClean.backend) -InvokeArgs $fbClean.invokeArgs
            $exited = $p.WaitForExit($fallbackDispatcherTimeoutMs)
            if (-not $exited) {
                try {
                    $p.Kill($true)
                    $p.WaitForExit()
                } catch { }
                throw "fallback dispatcher timeout excedeu ${fallbackDispatcherTimeoutMs}ms; processo encerrado"
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
            elseif (Test-UnavailableFailureMessage -Message ([string]$_.Exception.Message)) { $fallbackState = 'unavailable' }
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
                ledgerIndex        = $script:LedgerSeq++
                entryIndex         = [int]$rec.entryIndex
                suppressedFallbackChain = @()
                dispatchChannel    = 'cli'
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
                dispatchAttempted  = [bool](Get-Prop $fbRecord 'dispatchAttempted')
                preDispatchBlocked = [bool](Get-Prop $fbRecord 'preDispatchBlocked')
                processCreated     = Get-Prop $fbRecord 'processCreated'
                sidecarPath        = [string](Get-Prop $fbRecord 'sidecarPath')
                sidecarAccepted    = Get-Prop $fbRecord 'sidecarAccepted'
                sidecarValidationReason = [string](Get-Prop $fbRecord 'sidecarValidationReason')
                technicalStatus    = [string](Get-Prop $fbRecord 'technicalStatus')
                resultAccepted     = Get-Prop $fbRecord 'resultAccepted'
                acceptanceRejectionReason = [string](Get-Prop $fbRecord 'acceptanceRejectionReason')
                acceptedFinalTextSha256 = Get-Prop $fbRecord 'acceptedFinalTextSha256'
                acceptedFinalTextBytes = Get-Prop $fbRecord 'acceptedFinalTextBytes'
                promptTransmission = [string](Get-Prop $fbRecord 'promptTransmission')
                quotaCircuitDecision = [string](Get-Prop $fbRecord 'quotaCircuitDecision')
                quotaCircuitVariantDecisions = @(Get-Prop $fbRecord 'quotaCircuitVariantDecisions')
                fallbackSuppressedReason = [string](Get-Prop $fbRecord 'fallbackSuppressedReason')
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
                $content = if ($errText) { $errText } else { [string]$rec.reason }
                Set-Content -LiteralPath $path -Value ([string]$content) -Encoding utf8
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
$reviewersDispatchAttempted = @($records | Where-Object { $_.dispatchAttempted -eq $true }).Count
$reviewersProcessCreated = @($records | Where-Object { $_.processCreated -eq $true }).Count
$processCreatedUnknownCount = @($records | Where-Object { $_.dispatchAttempted -eq $true -and $null -eq $_.processCreated }).Count
$preDispatchBlockedCount = @($records | Where-Object { $_.preDispatchBlocked -eq $true }).Count
$sidecarAcceptedCount = @($records | Where-Object { $_.sidecarAccepted -eq $true }).Count
$sidecarRejectedCount = @($records | Where-Object { $_.sidecarAccepted -eq $false }).Count
$fallbackSuppressedCount = @($records | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.fallbackSuppressedReason) }).Count

$reviewerObjs = @($records | ForEach-Object { [pscustomobject]$_ })

$parallelKbRootOut = $null; if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) { $parallelKbRootOut = $ParallelKbRoot }
$policyPathOut = $null; if (-not [string]::IsNullOrWhiteSpace($PolicyPath)) { $policyPathOut = $PolicyPath }

$summary = [ordered]@{
    Kind                         = 'xpz-llm-panel-dispatch-result'
    SchemaVersion                = 3
    success                      = $true
    roundStarted                 = $true
    dispatchStarted              = $true
    reviewersDispatched          = $dispatched
    reviewersDispatchAttempted   = $reviewersDispatchAttempted
    reviewersProcessCreated      = $reviewersProcessCreated
    processCreatedUnknownCount   = $processCreatedUnknownCount
    preDispatchBlockedCount      = $preDispatchBlockedCount
    sidecarAcceptedCount         = $sidecarAcceptedCount
    sidecarRejectedCount         = $sidecarRejectedCount
    fallbackSuppressedCount      = $fallbackSuppressedCount
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
    preparationError             = $null
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
