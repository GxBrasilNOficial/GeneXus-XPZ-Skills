#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test de Resolve-LlmDelegatePeerReviewCloseout.ps1 (skill xpz-llm-delegate).
# Cobre o bug real: sem preferred-reviewers.json + selecao manual + oferta omitida
# deve bloquear o fechamento da revisao por pares.

$target = Join-Path $PSScriptRoot 'Resolve-LlmDelegatePeerReviewCloseout.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $target -PathType Leaf) "Script ausente: $target"

function Invoke-Closeout {
    param(
        [bool] $HadPreferredReviewers,
        [bool] $ManualReviewerSelection,
        [string] $OfferState,
        [string] $SelectedReviewersJson = '[]',
        [string] $PreferredReviewerStatesJson = '[]',
        [string] $VNextState = 'notProduced',
        [string] $ResubmissionDeclinedBy = '',
        [string] $ResubmissionDeclineReason = '',
        [string] $RoundId = '',
        [string] $PreferredReviewersSnapshotJson = '',
        [string] $EffectivePreferredPath = '',
        [string] $PreferenceSource = '',
        [string] $ProposedPreferredPath = '',
        [string] $PreferredRoot = '',
        [string] $Orchestrator = ''
    )
    $hadStr = if ($HadPreferredReviewers) { 'true' } else { 'false' }
    $manualStr = if ($ManualReviewerSelection) { 'true' } else { 'false' }
    $args = @{
        HadPreferredReviewers          = $hadStr
        ManualReviewerSelection        = $manualStr
        PreferredReviewersOfferState   = $OfferState
        SelectedReviewersJson          = $SelectedReviewersJson
        PreferredReviewerStatesJson    = $PreferredReviewerStatesJson
        VNextState                     = $VNextState
        ResubmissionDeclinedBy         = $ResubmissionDeclinedBy
        ResubmissionDeclineReason      = $ResubmissionDeclineReason
        RoundId                        = $RoundId
    }
    if (-not [string]::IsNullOrWhiteSpace($PreferredReviewersSnapshotJson)) {
        $args['PreferredReviewersSnapshotJson'] = $PreferredReviewersSnapshotJson
    }
    if (-not [string]::IsNullOrWhiteSpace($EffectivePreferredPath)) {
        $args['EffectivePreferredPath'] = $EffectivePreferredPath
    }
    if (-not [string]::IsNullOrWhiteSpace($PreferenceSource)) {
        $args['PreferenceSource'] = $PreferenceSource
    }
    if (-not [string]::IsNullOrWhiteSpace($ProposedPreferredPath)) {
        $args['ProposedPreferredPath'] = $ProposedPreferredPath
    }
    if (-not [string]::IsNullOrWhiteSpace($PreferredRoot)) {
        $args['PreferredRoot'] = $PreferredRoot
    }
    if (-not [string]::IsNullOrWhiteSpace($Orchestrator)) {
        $args['Orchestrator'] = $Orchestrator
    }
    return (& $target @args | ConvertFrom-Json)
}

function New-TestSnapshot {
    param([string]$SelectedReviewersJson, [string]$Path = 'C:\tmp\preferred-reviewers.json')
    $revs = $SelectedReviewersJson | ConvertFrom-Json
    $snap = [pscustomobject]@{
        hasPreferences         = $true
        schemaVersion          = 3
        preferenceSource       = 'machine'
        effectivePreferredPath = $Path
        reviewers              = @($revs)
    }
    return ($snap | ConvertTo-Json -Depth 8 -Compress)
}

# (1) Caso do bug: sem preferencias previas, escolha manual, oferta omitida -> bloqueia.
$r1 = Invoke-Closeout $false $true 'not_made' '[{"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro"}]'
Assert-True ($r1.closeoutReady -eq $false) 'Caso 1: fechamento deveria bloquear.'
Assert-True (@($r1.blockingReasons) -contains 'preferred-reviewers-offer-missing') 'Caso 1: razao de bloqueio ausente.'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$r1.requiredUserPrompt)) 'Caso 1: prompt obrigatorio ausente.'

# (2) Oferta apresentada, mesmo sem resposta final, libera a rodada.
$r2 = Invoke-Closeout $false $true 'offered'
Assert-True ($r2.closeoutReady -eq $true) 'Caso 2: oferta apresentada deveria liberar fechamento.'

# (3) Usuario recusou salvar curadoria -> libera e registra no recibo.
$r3 = Invoke-Closeout $false $true 'declined'
Assert-True ($r3.closeoutReady -eq $true) 'Caso 3: recusa deveria liberar fechamento.'
Assert-True ([string]$r3.receiptAddendum -match 'oferta=declined') 'Caso 3: recibo deveria registrar declined.'

# (4) Usuario adiou salvar curadoria -> libera e registra no recibo.
$r4 = Invoke-Closeout $false $true 'deferred'
Assert-True ($r4.closeoutReady -eq $true) 'Caso 4: adiamento deveria liberar fechamento.'
Assert-True ([string]$r4.receiptAddendum -match 'oferta=deferred') 'Caso 4: recibo deveria registrar deferred.'

# (5) Ja havia preferred-reviewers.json -> exige estados dos preferidos para fechar.
$r5 = Invoke-Closeout $true $false 'not_applicable'
Assert-True ($r5.closeoutReady -eq $false) 'Caso 5: preferencias existentes sem estados deveriam bloquear.'
Assert-True (
    (@($r5.blockingReasons) -contains 'preferred-reviewer-states-missing') -or
    (@($r5.blockingReasons) -contains 'preferred-snapshot-missing')
) 'Caso 5: deveria bloquear por states-missing e/ou snapshot-missing.'

# (6) Ja havia lista preferida resolvida + estados finais + snapshot -> not_applicable e valido.
$statesOk = @'
[
  {"backend":"claude-code","targetModelKey":"anthropic/claude-opus-4-8","family":"anthropic","state":"responded"},
  {"backend":"codex","targetModelKey":"openai/gpt-5.5","family":"openai","state":"responded"},
  {"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro","family":"ollama-cloud","state":"noResponse"},
  {"backend":"opencode","targetModelKey":"ollama-cloud/glm-5.2","family":"ollama-cloud","state":"stoppedOnGap"}
]
'@
$selectedOk = @'
[
  {"backend":"claude-code","targetModelKey":"anthropic/claude-opus-4-8"},
  {"backend":"codex","targetModelKey":"openai/gpt-5.5"},
  {"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro"},
  {"backend":"opencode","targetModelKey":"ollama-cloud/glm-5.2"}
]
'@
$snap6 = New-TestSnapshot -SelectedReviewersJson $selectedOk
$r6 = Invoke-Closeout $true $false 'not_applicable' $selectedOk $statesOk -PreferredReviewersSnapshotJson $snap6
Assert-True ($r6.closeoutReady -eq $true) ("Caso 6: preferencias existentes com estados finais deveriam liberar. reasons=$($r6.blockingReasons -join ',')")
Assert-True ($r6.requiresPreferredOffer -eq $false) 'Caso 6: requiresPreferredOffer deveria ser false.'
Assert-True (@($r6.preferredReviewerStates).Count -eq 4) 'Caso 6: deveria ecoar 4 estados de revisores preferidos.'
Assert-True ([string]$r6.receiptAddendum -match 'registrados=4') 'Caso 6: recibo deveria registrar quantidade de estados.'
Assert-True ([string]$r6.receiptAddendum -match 'lista preferida ja resolvida no inicio da rodada') 'Caso 6: motivo de curadoria nao deve citar so preferred-reviewers.json.'
Assert-True ([string]$r6.receiptAddendum -notmatch 'preferred-reviewers\.json ja existia') 'Caso 6: frase legada do motivo de curadoria nao deve voltar.'

# (7) Estado incompleto em revisor preferido -> bloqueia.
$statesIncomplete = '[{"backend":"opencode","targetModelKey":"ollama-cloud/kimi-k2.7-code","family":"ollama-cloud","state":"gateAllow"}]'
$sel7 = '[{"backend":"opencode","targetModelKey":"ollama-cloud/kimi-k2.7-code"}]'
$snap7 = New-TestSnapshot -SelectedReviewersJson $sel7
$r7 = Invoke-Closeout $true $false 'not_applicable' $sel7 $statesIncomplete -PreferredReviewersSnapshotJson $snap7
Assert-True ($r7.closeoutReady -eq $false) 'Caso 7: estado incompleto gateAllow deveria bloquear.'
Assert-True (@($r7.blockingReasons) -contains 'preferred-reviewer-state-incomplete:ollama-cloud/kimi-k2.7-code:gateAllow') 'Caso 7: razao de estado incompleto ausente.'

# (8) not_applicable indevido com selecao manual sem preferencias previas -> fail-closed.
$r8 = Invoke-Closeout $false $true 'not_applicable'
Assert-True ($r8.closeoutReady -eq $false) 'Caso 8: not_applicable indevido deveria bloquear.'
Assert-True (@($r8.blockingReasons) -contains 'preferred-reviewers-offer-state-invalid-for-manual-selection') 'Caso 8: razao fail-closed ausente.'

# (9) JSON invalido deve falhar de forma explicita.
$failed = $false
try {
    [void](Invoke-Closeout $false $true 'not_made' '{')
} catch {
    $failed = ($_.Exception.Message -match 'SelectedReviewersJson')
}
Assert-True $failed 'Caso 9: JSON invalido deveria falhar citando SelectedReviewersJson.'

# (10) JSON invalido de estados deve falhar de forma explicita.
$failedStates = $false
try {
    [void](Invoke-Closeout $true $false 'not_applicable' '[]' '{')
} catch {
    $failedStates = ($_.Exception.Message -match 'PreferredReviewerStatesJson')
}
Assert-True $failedStates 'Caso 10: JSON invalido deveria falhar citando PreferredReviewerStatesJson.'

# (11) Contrato C: valor invalido para -HadPreferredReviewers e barrado por ValidateSet
#      (string 'true'/'false'; nunca [bool] nem token nu $true/$false via Bash).
$failedSet = $false
try {
    [void](& $target -HadPreferredReviewers 'sim' -ManualReviewerSelection 'true' -PreferredReviewersOfferState not_made | ConvertFrom-Json)
} catch {
    $failedSet = $true
}
Assert-True $failedSet 'Caso 11: valor invalido em -HadPreferredReviewers deveria ser barrado por ValidateSet.'

# (12) Contrato C: strings 'false'/'true' produzem o mesmo resultado do caso do bug (1).
$r12 = (& $target -HadPreferredReviewers 'false' -ManualReviewerSelection 'true' -PreferredReviewersOfferState not_made -SelectedReviewersJson '[{"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro"}]' | ConvertFrom-Json)
Assert-True ($r12.closeoutReady -eq $false) 'Caso 12: string false/true deveria bloquear como o caso 1.'
Assert-True ($r12.hadPreferredReviewers -eq $false) 'Caso 12: hadPreferredReviewers deveria ecoar booleano $false.'
Assert-True ($r12.manualReviewerSelection -eq $true) 'Caso 12: manualReviewerSelection deveria ecoar booleano $true.'

# --- Eixo de estado da vN+1 (Achado A2) ---

# (13) vN+1 autorada e nao re-submetida -> bloqueia + prompt oferece 2a rodada + ecoa estado.
$r13 = Invoke-Closeout $false $false 'not_applicable' '[]' '[]' 'pendingResubmission' '' '' 'v3'
Assert-True ($r13.closeoutReady -eq $false) 'Caso 13: pendingResubmission deveria bloquear.'
Assert-True (@($r13.blockingReasons) -contains 'vnext-pending-resubmission') 'Caso 13: razao vnext-pending-resubmission ausente.'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$r13.requiredUserPrompt)) 'Caso 13: prompt de 2a rodada ausente.'
Assert-True ([string]$r13.receiptAddendum -match 'vNextState=pendingResubmission') 'Caso 13: recibo deveria ecoar vNextState.'

# (14) Declinio sem quem/motivo -> bloqueia (decline-unaudited).
$r14 = Invoke-Closeout $false $false 'not_applicable' '[]' '[]' 'resubmissionDeclinedByHuman' '' '' 'v3'
Assert-True ($r14.closeoutReady -eq $false) 'Caso 14: declinio sem quem/motivo deveria bloquear.'
Assert-True (@($r14.blockingReasons) -contains 'vnext-resubmission-decline-unaudited') 'Caso 14: razao vnext-resubmission-decline-unaudited ausente.'

# (15) Declinio auditado (quem+motivo+RoundId) -> libera e ecoa quem/motivo/RoundId no recibo.
$r15 = Invoke-Closeout $false $false 'not_applicable' '[]' '[]' 'resubmissionDeclinedByHuman' 'Antonio' 'diff trivial; risco baixo' 'v9'
Assert-True ($r15.closeoutReady -eq $true) 'Caso 15: declinio auditado deveria liberar.'
Assert-True ([string]$r15.receiptAddendum -match 'declinadoPor=Antonio') 'Caso 15: recibo deveria ecoar quem declinou.'
Assert-True ([string]$r15.receiptAddendum -match 'RoundId=v9') 'Caso 15: recibo deveria ecoar o RoundId do declinio.'
Assert-True ($r15.vNextState -eq 'resubmissionDeclinedByHuman') 'Caso 15: vNextState deveria ser ecoado no objeto.'
Assert-True ($r15.resubmissionDeclinedBy -eq 'Antonio') 'Caso 15: objeto deveria ecoar resubmissionDeclinedBy.'
Assert-True ([string]$r15.resubmissionDeclineReason -match 'trivial') 'Caso 15: objeto deveria ecoar resubmissionDeclineReason.'

# (16) vN+1 re-submetida -> neutro, libera.
$r16 = Invoke-Closeout $false $false 'not_applicable' '[]' '[]' 'resubmitted'
Assert-True ($r16.closeoutReady -eq $true) 'Caso 16: resubmitted deveria liberar.'
Assert-True (@($r16.blockingReasons).Count -eq 0) 'Caso 16: resubmitted nao deveria gerar bloqueio.'

# (17) notProduced (default) -> neutro e SEMPRE ecoado no recibo (corrige o risco do silencio).
$r17 = Invoke-Closeout $false $false 'not_applicable'
Assert-True ($r17.closeoutReady -eq $true) 'Caso 17: notProduced deveria liberar.'
Assert-True ($r17.vNextState -eq 'notProduced') 'Caso 17: vNextState default deveria ser notProduced.'
Assert-True ([string]$r17.receiptAddendum -match 'vNextState=notProduced') 'Caso 17: recibo deveria ecoar vNextState mesmo no default.'

# (18) Precedencia: vN+1 pendente E oferta de curadoria omitida -> ambos bloqueiam, mas o
#      requiredUserPrompt e o da vN+1 (precedencia), nao o da curadoria.
$r18 = Invoke-Closeout $false $true 'not_made' '[{"backend":"opencode","targetModelKey":"ollama-cloud/minimax-m3"}]' '[]' 'pendingResubmission' '' '' 'v3'
Assert-True ($r18.closeoutReady -eq $false) 'Caso 18: bloqueio combinado deveria manter closeoutReady=false.'
Assert-True (@($r18.blockingReasons) -contains 'vnext-pending-resubmission') 'Caso 18: razao vnext-pending-resubmission ausente.'
Assert-True (@($r18.blockingReasons) -contains 'preferred-reviewers-offer-missing') 'Caso 18: razao de curadoria ausente.'
Assert-True ([string]$r18.requiredUserPrompt -match 'não re-submetida') 'Caso 18: prompt deveria priorizar a vN+1, nao a curadoria.'

# (19) Declinio com quem+motivo mas SEM RoundId -> bloqueia (RoundId escopa o declinio).
$r19 = Invoke-Closeout $false $false 'not_applicable' '[]' '[]' 'resubmissionDeclinedByHuman' 'Antonio' 'motivo qualquer' ''
Assert-True ($r19.closeoutReady -eq $false) 'Caso 19: declinio sem RoundId deveria bloquear.'
Assert-True (@($r19.blockingReasons) -contains 'vnext-resubmission-decline-unaudited') 'Caso 19: razao decline-unaudited ausente (RoundId).'

# (20) Declinio com quem+RoundId mas SEM motivo -> bloqueia (um campo so nao basta).
$r20 = Invoke-Closeout $false $false 'not_applicable' '[]' '[]' 'resubmissionDeclinedByHuman' 'Antonio' '' 'v9'
Assert-True ($r20.closeoutReady -eq $false) 'Caso 20: declinio sem motivo deveria bloquear.'
Assert-True (@($r20.blockingReasons) -contains 'vnext-resubmission-decline-unaudited') 'Caso 20: razao decline-unaudited ausente (motivo).'

# (21) Declinio com campos preenchidos mas com whitespace nas bordas -> libera (Trim) e ecoa
#      o valor sem as bordas; whitespace-puro contaria como vazio (IsNullOrWhiteSpace).
$r21 = Invoke-Closeout $false $false 'not_applicable' '[]' '[]' 'resubmissionDeclinedByHuman' '  Antonio  ' '  motivo ok  ' 'v9'
Assert-True ($r21.closeoutReady -eq $true) 'Caso 21: declinio com bordas de whitespace deveria liberar apos Trim.'
Assert-True ($r21.resubmissionDeclinedBy -eq 'Antonio') 'Caso 21: objeto deveria ecoar o valor com Trim.'
Assert-True ([string]$r21.receiptAddendum -match 'declinadoPor=Antonio;') 'Caso 21: recibo deveria ecoar o valor com Trim.'

# (22) Estados de fallback finais sao aceitos quando skips nao contam diversidade.
$statesFallbackOk = @'
[
  {"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro","family":"ollama-cloud","state":"responded","attemptRole":"primary","countsForDiversity":true},
  {"backend":"opencode","targetModelKey":"nvidia/deepseek-ai/deepseek-v4-pro","family":"nvidia","state":"skippedAfterSuccess","attemptRole":"fallback","fallbackOf":"ollama-cloud/deepseek-v4-pro","countsForDiversity":false},
  {"backend":"opencode","targetModelKey":"ollama-cloud/glm-5.2","family":"ollama-cloud","state":"timeout","attemptRole":"primary","countsForDiversity":false},
  {"backend":"opencode","targetModelKey":"nvidia/z-ai/glm-5.1","family":"nvidia","state":"notAttempted","attemptRole":"fallback","fallbackOf":"ollama-cloud/glm-5.2","countsForDiversity":false},
  {"backend":"opencode","targetModelKey":"ollama-cloud/minimax-m3","family":"ollama-cloud","state":"gateDeny","attemptRole":"primary","countsForDiversity":false},
  {"backend":"opencode","targetModelKey":"nvidia/minimaxai/minimax-m3","family":"nvidia","state":"skippedByPolicy","attemptRole":"fallback","fallbackOf":"ollama-cloud/minimax-m3","countsForDiversity":false}
]
'@
$selectedFallbackOk = @'
[
  {"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro","fallbackChain":[{"backend":"opencode","targetModelKey":"nvidia/deepseek-ai/deepseek-v4-pro"}]},
  {"backend":"opencode","targetModelKey":"ollama-cloud/glm-5.2","fallbackChain":[{"backend":"opencode","targetModelKey":"nvidia/z-ai/glm-5.1"}]},
  {"backend":"opencode","targetModelKey":"ollama-cloud/minimax-m3","fallbackChain":[{"backend":"opencode","targetModelKey":"nvidia/minimaxai/minimax-m3"}]}
]
'@
$r22 = Invoke-Closeout $true $false 'not_applicable' $selectedFallbackOk $statesFallbackOk -PreferredReviewersSnapshotJson (New-TestSnapshot $selectedFallbackOk)
Assert-True ($r22.closeoutReady -eq $true) ("Caso 22: estados finais de fallback deveriam liberar. reasons=$($r22.blockingReasons -join ',')")
Assert-True (@($r22.preferredReviewerStates).Count -eq 6) 'Caso 22: deveria ecoar primarios + fallbacks.'
Assert-True ([string]($r22.preferredReviewerStates | Where-Object { $_.attemptRole -eq 'fallback' } | Select-Object -First 1).effortApplied -eq 'unset') 'Caso 22: effortApplied de fallback deve ser unset.'

# (23) Skip contando diversidade bloqueia.
$sel23 = '[{"backend":"opencode","targetModelKey":"ollama-cloud/x","fallbackChain":[{"backend":"opencode","targetModelKey":"nvidia/x"}]}]'
$statesSkipBad = '[{"backend":"opencode","targetModelKey":"nvidia/x","family":"nvidia","state":"skippedAfterSuccess","attemptRole":"fallback","fallbackOf":"ollama-cloud/x","countsForDiversity":true}]'
$r23 = Invoke-Closeout $true $false 'not_applicable' $sel23 $statesSkipBad -PreferredReviewersSnapshotJson (New-TestSnapshot $sel23)
Assert-True ($r23.closeoutReady -eq $false) 'Caso 23: skip com countsForDiversity=true deveria bloquear.'
Assert-True (@($r23.blockingReasons) -contains 'preferred-reviewer-state-skip-counts-diversity:nvidia/x:skippedAfterSuccess') 'Caso 23: razao de diversidade inflada ausente.'

# (24) notAttempted como estado primario silencioso bloqueia.
$sel24 = '[{"backend":"opencode","targetModelKey":"ollama-cloud/x"}]'
$statesPrimaryNotAttempted = '[{"backend":"opencode","targetModelKey":"ollama-cloud/x","family":"ollama-cloud","state":"notAttempted","attemptRole":"primary","countsForDiversity":false}]'
$r24 = Invoke-Closeout $true $false 'not_applicable' $sel24 $statesPrimaryNotAttempted -PreferredReviewersSnapshotJson (New-TestSnapshot $sel24)
Assert-True ($r24.closeoutReady -eq $false) 'Caso 24: primario notAttempted silencioso deveria bloquear.'
Assert-True (@($r24.blockingReasons) -contains 'preferred-reviewer-primary-notattempted-silent:ollama-cloud/x') 'Caso 24: razao primario notAttempted ausente.'

# (25) Diversidade insuficiente apos fallback bloqueia o recibo de revisao por pares.
$r25 = (& $target -HadPreferredReviewers 'false' -ManualReviewerSelection 'false' -PreferredReviewersOfferState not_applicable -DiversityState insufficientDiversityAfterFallback | ConvertFrom-Json)
Assert-True ($r25.closeoutReady -eq $false) 'Caso 25: insufficientDiversityAfterFallback deveria bloquear closeout.'
Assert-True (@($r25.blockingReasons) -contains 'insufficient-diversity-after-fallback') 'Caso 25: razao insufficient-diversity-after-fallback ausente.'
Assert-True ([string]$r25.requiredUserPrompt -match 'diversidade insuficiente') 'Caso 25: prompt deveria mencionar diversidade insuficiente.'

# (26) Com preferred-reviewers existente, SelectedReviewersJson nao pode vir vazio: sem lista
#      esperada nao ha como provar completude dos estados.
$snap26 = New-TestSnapshot '[{"backend":"codex","targetModelKey":"openai/gpt-5.5"}]'
$r26 = Invoke-Closeout $true $false 'not_applicable' '[]' '[{"backend":"codex","targetModelKey":"openai/gpt-5.5","state":"responded","countsForDiversity":true}]' -PreferredReviewersSnapshotJson $snap26
Assert-True ($r26.closeoutReady -eq $false) 'Caso 26: HadPreferred=true com SelectedReviewersJson vazio deveria bloquear.'
Assert-True (
    (@($r26.blockingReasons) -contains 'preferred-reviewer-expected-states-missing') -or
    (@($r26.blockingReasons) -contains 'preferred-snapshot-invalid')
) 'Caso 26: deveria bloquear por expected-states-missing ou snapshot-invalid (reviewers vs selected vazio).'

# (27) Estado parcial nao pode liberar: todo titular esperado precisa aparecer.
$selectedTwo = '[{"backend":"codex","targetModelKey":"openai/gpt-5.5"},{"backend":"opencode","targetModelKey":"nvidia/z-ai/glm-5.2"}]'
$stateOne = '[{"backend":"codex","targetModelKey":"openai/gpt-5.5","state":"responded","countsForDiversity":true}]'
$r27 = Invoke-Closeout $true $false 'not_applicable' $selectedTwo $stateOne -PreferredReviewersSnapshotJson (New-TestSnapshot $selectedTwo)
Assert-True ($r27.closeoutReady -eq $false) 'Caso 27: estado parcial deveria bloquear.'
Assert-True (@($r27.blockingReasons) -contains 'preferred-reviewer-state-missing:nvidia/z-ai/glm-5.2') 'Caso 27: titular esperado omitido deveria ser apontado.'

# (28) Fallback esperado tambem precisa ter estado auditavel quando consta na lista preferida.
$selectedWithFallback = '[{"backend":"codex","targetModelKey":"openai/gpt-5.5","fallbackChain":[{"backend":"opencode","targetModelKey":"nvidia/z-ai/glm-5.2"}]}]'
$r28 = Invoke-Closeout $true $false 'not_applicable' $selectedWithFallback $stateOne -PreferredReviewersSnapshotJson (New-TestSnapshot $selectedWithFallback)
Assert-True ($r28.closeoutReady -eq $false) 'Caso 28: fallback esperado omitido deveria bloquear.'
Assert-True (@($r28.blockingReasons) -contains 'preferred-reviewer-state-missing:nvidia/z-ai/glm-5.2') 'Caso 28: fallback esperado omitido deveria ser apontado.'

# (29) Estado duplicado nao pode mascarar ausencia de outro preferido esperado.
$stateDuplicate = @'
[
  {"backend":"codex","targetModelKey":"openai/gpt-5.5","state":"responded","countsForDiversity":true},
  {"backend":"codex","targetModelKey":"openai/gpt-5.5","state":"responded","countsForDiversity":true}
]
'@
$r29 = Invoke-Closeout $true $false 'not_applicable' $selectedTwo $stateDuplicate -PreferredReviewersSnapshotJson (New-TestSnapshot $selectedTwo)
Assert-True ($r29.closeoutReady -eq $false) 'Caso 29: duplicata de estado deveria bloquear.'
Assert-True (@($r29.blockingReasons) -contains 'preferred-reviewer-state-duplicate:openai/gpt-5.5') 'Caso 29: duplicata deveria ser apontada.'
Assert-True (@($r29.blockingReasons) -contains 'preferred-reviewer-state-missing:nvidia/z-ai/glm-5.2') 'Caso 29: duplicata nao pode mascarar ausencia do outro esperado.'

# (30) Selecao manual tambem vira contrato de completude quando SelectedReviewersJson e
#      informado: nao pode fechar com estado parcial depois da oferta de curadoria.
$r30 = Invoke-Closeout $false $true 'offered' $selectedTwo $stateOne
Assert-True ($r30.closeoutReady -eq $false) 'Caso 30: selecao manual com estado parcial deveria bloquear.'
Assert-True (@($r30.blockingReasons) -contains 'preferred-reviewer-state-missing:nvidia/z-ai/glm-5.2') 'Caso 30: revisor manual esperado omitido deveria ser apontado.'

# (31) Oferta com -ProposedPreferredPath / -PreferredRoot / -Orchestrator: prompt e recibo
#      devem ecoar o path resolvido (preferred-reviewers.<orch>.json), nao o literal machine.
$orchRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'xpz-llm-delegate'
$orchProposed = Join-Path $orchRoot 'preferred-reviewers.cursor.json'
$r31 = Invoke-Closeout $false $true 'not_made' '[{"backend":"opencode","targetModelKey":"ollama-cloud/deepseek-v4-pro"}]' `
    -ProposedPreferredPath $orchProposed -PreferredRoot $orchRoot -Orchestrator 'cursor'
Assert-True ($r31.closeoutReady -eq $false) 'Caso 31: oferta omitida deveria bloquear.'
Assert-True (@($r31.blockingReasons) -contains 'preferred-reviewers-offer-missing') 'Caso 31: razao de oferta ausente.'
Assert-True ([string]$r31.requiredUserPrompt -match 'preferred-reviewers\.cursor\.json') 'Caso 31: prompt deveria citar preferred-reviewers.cursor.json.'
Assert-True ([string]$r31.requiredUserPrompt -match "orquestrador 'cursor'") 'Caso 31: prompt deveria rotular orquestrador cursor, nao so desta maquina.'
Assert-True ([string]$r31.requiredUserPrompt -notmatch 'preferidos desta máquina em %LOCALAPPDATA%\\xpz-llm-delegate\\preferred-reviewers\.json') 'Caso 31: prompt nao deve citar so o literal machine fixo.'
Assert-True ([string]$r31.receiptAddendum -match 'destino=.*preferred-reviewers\.cursor\.json') 'Caso 31: recibo destino= deveria ecoar o path do orquestrador.'
Assert-True ([string]$r31.effectivePreferredPath -match 'preferred-reviewers\.cursor\.json$') 'Caso 31: effectivePreferredPath deveria ser o path proposto.'

<#
Casos antigos mantidos por cobertura historica:
  - sem preferencias previas + escolha manual + oferta omitida -> bloqueia;
  - oferta apresentada/recusada/adiada -> libera a rodada ad-hoc;
  - estados de preferidos existentes agora sao obrigatorios no fechamento.
Casos da vN+1 (Achado A2): pendingResubmission/decline-unaudited bloqueiam;
declinio auditado e resubmitted/notProduced liberam; vNextState sempre ecoado.
#>

Write-Output 'OK: Test-LlmDelegatePeerReviewCloseoutSelfTest.ps1'
