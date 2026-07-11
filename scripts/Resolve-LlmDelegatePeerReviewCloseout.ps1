#requires -Version 7.4
<#
.SYNOPSIS
    Verifica, de forma deterministica, se uma rodada de revisao por pares pode ser encerrada
    sem omitir a oferta de salvar revisores preferidos.
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.

    Por que existe: em teste real, o agente consumidor leu a regra de persistencia de
    preferred-reviewers.json, pediu os revisores, executou o painel e encerrou a rodada sem
    oferecer salvar a curadoria. Este resolvedor torna esse ponto de fechamento mecanico:
    quando a rodada comeca sem preferred-reviewers.json e o usuario escolhe revisores
    manualmente, o encerramento so fica pronto se a oferta foi feita ou se houve decisao
    explicita equivalente.

    Este script NAO grava preferred-reviewers.json, NAO decide autorizacao por KB e NAO
    recalcula diversidade. Ele so emite JSON de maquina para o orquestrador:
    pronto/bloqueado, razoes, prompt obrigatorio e adendo de recibo. A gravacao continua
    sendo de Set-LlmDelegatePreferredReviewers.ps1.

    Estados de oferta:
      not_made       -> oferta obrigatoria ainda nao feita
      offered        -> oferta apresentada ao usuario; a rodada pode seguir sem resposta
      accepted       -> usuario aceitou salvar curadoria
      declined       -> usuario recusou salvar curadoria
      deferred       -> usuario adiou salvar curadoria
      not_applicable -> nao havia obrigacao de ofertar nesta rodada

    Regra fail-closed: se nao havia preferred-reviewers.json, houve selecao manual, e o estado
    vier not_applicable ou ausente, o fechamento bloqueia. not_applicable so e valido quando
    ja havia preferencias ou quando a rodada nao usou selecao manual de revisores.

    Quando preferred-reviewers.json existia, a lista preferida nao e autorizacao nem obriga
    parecer util de todos, mas tambem nao pode virar pool opcional silencioso. O fechamento
    exige estado auditavel para cada revisor preferido da rodada. Estados incompletos
    (`gateAllow`, `dispatched`, `enqueued`) bloqueiam o recibo final; estados finais como
    `responded`, `noResponse`, `timeout`, `error`, `quota`, `gateAsk`, `gateDeny`, `unavailable`,
    `skippedByHumanDecision`, `stoppedOnGap`, `skippedAfterSuccess`, `skippedByPolicy` e
    `notAttempted` liberam como estados finais auditaveis, desde que o piso de diversidade ja
    tenha sido tratado pelo motor proprio. Estados de nao tentativa devem vir com
    `countsForDiversity=false`.

    Eixo de estado da vN+1 (Achado A): apos o painel, o agente AUTORA uma versao consolidada
    (vN+1) que ainda NAO foi revisada. -VNextState declara onde a vN+1 esta:
      notProduced                 -> nao houve sintese consolidada -> neutro
      pendingResubmission         -> vN+1 autorada e NAO re-submetida -> BLOQUEIA (oferecer 2a rodada)
      resubmitted                 -> vN+1 re-submetida ao painel -> neutro
      resubmissionDeclinedByHuman -> humano cientemente NAO re-submete -> exige registro
                                     auditavel (-ResubmissionDeclinedBy + -ResubmissionDeclineReason
                                     + -RoundId, que escopa o declinio a rodada);
                                     sem quem/motivo/RoundId -> BLOQUEIA (vnext-resubmission-decline-unaudited)
    Este script e STATELESS: o estado chega por parametro e e reavaliado do zero a cada chamada.
    A trilha auditavel (append-only por RoundId) e a monotonicidade entre chamadas sao do
    ORQUESTRADOR + recibo/livro-razao, NAO deste script. A unica forma de mover de
    pendingResubmission para um estado terminal e nova invocacao com o VNextState terminal.
    Limite honesto: o eixo e a prova de SILENCIO (converte um "pulei a re-submissao" em
    afirmacao auditavel e falsificavel), nao a prova de FABRICACAO.
.PARAMETER HadPreferredReviewers
    Indica se Resolve-LlmDelegatePreferredReviewers.ps1 devolveu hasPreferences=true no inicio
    da montagem do painel.
.PARAMETER ManualReviewerSelection
    Indica se o usuario escolheu revisores manualmente para esta rodada.
.PARAMETER PreferredReviewersOfferState
    Estado da oferta de salvar a selecao em preferred-reviewers.json.
.PARAMETER RoundId
    Identificador da rodada, usado para recibo e auditoria. Opcional em geral, mas
    OBRIGATORIO quando -VNextState resubmissionDeclinedByHuman (escopa o declinio a rodada;
    ausente nesse caso bloqueia o fechamento).
.PARAMETER SelectedReviewersJson
    JSON com os revisores esperados da rodada. Quando HadPreferredReviewers=true, e obrigatorio
    para provar completude; quando ManualReviewerSelection=true e a lista e informada, tambem
    vira contrato de completude. Titulares e fallbackChain[] sao expandidos e comparados contra
    PreferredReviewerStatesJson.
.PARAMETER PreferredReviewerStatesJson
    JSON opcional com o estado final de cada revisor esperado/auditado da rodada:
    [{ "targetModelKey": "...", "backend": "...", "state": "responded|noResponse|timeout|error|quota|gateAsk|gateDeny|unavailable|skippedByHumanDecision|stoppedOnGap|skippedAfterSuccess|skippedByPolicy|notAttempted|gateAllow|dispatched|enqueued", "family": "...", "attemptRole": "primary|fallback", "fallbackOf": "...", "countsForDiversity": true|false }].
    Quando HadPreferredReviewers=true ou quando ManualReviewerSelection=true com SelectedReviewersJson
    informado, deve conter todos os revisores esperados. Nessa comparacao, backend, targetModelKey,
    attemptRole e fallbackOf compoem a identidade do revisor esperado; omiti-los pode gerar estado
    ausente ou inesperado no fechamento.
    Estados de nao tentativa (`skippedAfterSuccess`, `skippedByPolicy`, `notAttempted`) devem carregar
    `countsForDiversity=false`; `notAttempted` como estado primario silencioso bloqueia o fechamento.
.PARAMETER DiversityState
    Estado opcional ja calculado por Resolve-LlmDelegatePanelDiversity.ps1. Este script nao
    recalcula diversidade; apenas ecoa o valor no recibo.
.PARAMETER VNextState
    Estado da versao consolidada (vN+1) autorada apos o painel:
    notProduced | pendingResubmission | resubmitted | resubmissionDeclinedByHuman.
    Default notProduced. Sempre ecoado no receiptAddendum (Achado A).
.PARAMETER ResubmissionDeclinedBy
    Quem (humano) decidiu nao re-submeter a vN+1. Exigido apenas quando
    -VNextState resubmissionDeclinedByHuman; ausente/vazio nesse caso bloqueia o fechamento.
    Ignorado nos demais estados.
.PARAMETER ResubmissionDeclineReason
    Por que a re-submissao foi declinada. Exigido apenas quando
    -VNextState resubmissionDeclinedByHuman; ausente/vazio nesse caso bloqueia o fechamento.
    Ignorado nos demais estados.
.EXAMPLE
    .\Resolve-LlmDelegatePeerReviewCloseout.ps1 -HadPreferredReviewers false -ManualReviewerSelection true -PreferredReviewersOfferState not_made

    Nota: -HadPreferredReviewers/-ManualReviewerSelection recebem a string 'true'/'false'
    (NAO o literal $true/$false). Via `pwsh -File` chamado de Bash, $true/$false nus expandem
    para vazio antes do pwsh; por isso o contrato e string validada por ValidateSet.
.EXAMPLE
    .\Resolve-LlmDelegatePeerReviewCloseout.ps1 -HadPreferredReviewers true -ManualReviewerSelection false -RoundId v3 -VNextState pendingResubmission

    vN+1 autorada e ainda nao re-submetida: closeoutReady=false, blockingReason
    vnext-pending-resubmission, e requiredUserPrompt oferece a 2a rodada.
.EXAMPLE
    .\Resolve-LlmDelegatePeerReviewCloseout.ps1 -HadPreferredReviewers true -ManualReviewerSelection false -RoundId v3 -VNextState resubmissionDeclinedByHuman -ResubmissionDeclinedBy "Antonio" -ResubmissionDeclineReason "diff trivial; risco baixo"

    Declinio auditado: closeoutReady=true e o recibo ecoa quem/motivo/RoundId.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('true', 'false')] [string] $HadPreferredReviewers,
    [Parameter(Mandatory)] [ValidateSet('true', 'false')] [string] $ManualReviewerSelection,
    [ValidateSet('not_made', 'offered', 'accepted', 'declined', 'deferred', 'not_applicable')]
    [string] $PreferredReviewersOfferState = 'not_applicable',
    [string] $RoundId,
    [string] $SelectedReviewersJson = '[]',
    [string] $PreferredReviewerStatesJson = '[]',
    [string] $DiversityState,
    [ValidateSet('notProduced', 'pendingResubmission', 'resubmitted', 'resubmissionDeclinedByHuman')]
    [string] $VNextState = 'notProduced',
    [string] $ResubmissionDeclinedBy,
    [string] $ResubmissionDeclineReason
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# HadPreferredReviewers/ManualReviewerSelection chegam como string ('true'/'false'): via
# `pwsh -File` chamado de Bash, os tokens nus $true/$false do shell expandem para vazio antes
# do pwsh (quirk real; dois agentes tropecaram). ValidateSet barra valores invalidos e a
# conversao e textual — NUNCA [bool]$x, que tornaria [bool]'false' = $true. Ver Achado C.
$hadPreferred = ($HadPreferredReviewers -eq 'true')
$manualSelection = ($ManualReviewerSelection -eq 'true')

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) { return $Obj.PSObject.Properties[$Name].Value }
    return $null
}

function Get-ReviewerLabel {
    param($Reviewer)
    $backend = [string](Get-Prop $Reviewer 'backend')
    $target = [string](Get-Prop $Reviewer 'targetModelKey')
    if ([string]::IsNullOrWhiteSpace($target)) { $target = [string](Get-Prop $Reviewer 'model') }
    if ([string]::IsNullOrWhiteSpace($backend)) { return $target }
    if ([string]::IsNullOrWhiteSpace($target)) { return $backend }
    return "$backend -> $target"
}

function Get-ReviewerTarget {
    param($Reviewer)
    $target = [string](Get-Prop $Reviewer 'targetModelKey')
    if ([string]::IsNullOrWhiteSpace($target)) { $target = [string](Get-Prop $Reviewer 'model') }
    return $target
}

function Get-ReviewerStateKey {
    param([string]$Backend, [string]$TargetModelKey, [string]$AttemptRole, [string]$FallbackOf)
    $role = if ($AttemptRole -eq 'fallback' -or -not [string]::IsNullOrWhiteSpace($FallbackOf)) { 'fallback' } else { 'primary' }
    $fallbackOwner = if ($role -eq 'fallback') { $FallbackOf } else { '' }
    return "$Backend|$TargetModelKey|$role|$fallbackOwner"
}

function Add-ExpectedReviewerState {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [System.Collections.Generic.HashSet[string]]$Keys,
        [System.Collections.Generic.List[string]]$BlockingReasons,
        $Reviewer,
        [string]$AttemptRole,
        [string]$FallbackOf
    )
    $backend = [string](Get-Prop $Reviewer 'backend')
    $target = Get-ReviewerTarget $Reviewer
    if ([string]::IsNullOrWhiteSpace($target)) {
        $BlockingReasons.Add('preferred-reviewer-expected-missing-target')
        return
    }
    $key = Get-ReviewerStateKey -Backend $backend -TargetModelKey $target -AttemptRole $AttemptRole -FallbackOf $FallbackOf
    if (-not $Keys.Add($key)) {
        $BlockingReasons.Add("preferred-reviewer-expected-duplicate:$target")
        return
    }
    $Rows.Add([pscustomobject]@{
            targetModelKey = $target
            backend        = $backend
            attemptRole    = $AttemptRole
            fallbackOf     = $FallbackOf
            key            = $key
        })
}

$selectedReviewers = @()
try {
    $parsed = $SelectedReviewersJson | ConvertFrom-Json
    $selectedReviewers = @($parsed)
} catch {
    throw "BLOCK: -SelectedReviewersJson nao e JSON valido: $($_.Exception.Message)"
}

$preferredReviewerStates = @()
try {
    $parsedStates = $PreferredReviewerStatesJson | ConvertFrom-Json
    $preferredReviewerStates = @($parsedStates)
} catch {
    throw "BLOCK: -PreferredReviewerStatesJson nao e JSON valido: $($_.Exception.Message)"
}

$requiresOffer = (-not $hadPreferred) -and $manualSelection
$blockingReasons = [System.Collections.Generic.List[string]]::new()

if ($requiresOffer -and $PreferredReviewersOfferState -eq 'not_made') {
    $blockingReasons.Add('preferred-reviewers-offer-missing')
}

if ($requiresOffer -and $PreferredReviewersOfferState -eq 'not_applicable') {
    $blockingReasons.Add('preferred-reviewers-offer-state-invalid-for-manual-selection')
}

if (-not $requiresOffer -and $PreferredReviewersOfferState -ne 'not_applicable' -and -not $manualSelection) {
    $blockingReasons.Add('preferred-reviewers-offer-state-unexpected-without-manual-selection')
}

$validFinalStates = @(
    'responded',
    'noResponse',
    'timeout',
    'error',
    'quota',
    'gateAsk',
    'gateDeny',
    'unavailable',
    'skippedByHumanDecision',
    'stoppedOnGap',
    'skippedAfterSuccess',
    'skippedByPolicy',
    'notAttempted'
)
$incompleteStates = @('gateAllow', 'dispatched', 'enqueued')
$allKnownStates = @($validFinalStates + $incompleteStates)
$expectedStateRows = [System.Collections.Generic.List[object]]::new()
$expectedStateKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$requiresStateCompleteness = ($hadPreferred -or ($manualSelection -and @($selectedReviewers).Count -gt 0))
if ($requiresStateCompleteness) {
    foreach ($selected in $selectedReviewers) {
        $selectedTarget = Get-ReviewerTarget $selected
        Add-ExpectedReviewerState -Rows $expectedStateRows -Keys $expectedStateKeys -BlockingReasons $blockingReasons -Reviewer $selected -AttemptRole 'primary' -FallbackOf ''
        $fallbackItems = Get-Prop $selected 'fallbackChain'
        if ($null -eq $fallbackItems) { $fallbackItems = @() }
        foreach ($fb in @($fallbackItems)) {
            Add-ExpectedReviewerState -Rows $expectedStateRows -Keys $expectedStateKeys -BlockingReasons $blockingReasons -Reviewer $fb -AttemptRole 'fallback' -FallbackOf $selectedTarget
        }
    }
    if ($expectedStateRows.Count -eq 0) {
        $blockingReasons.Add('preferred-reviewer-expected-states-missing')
    }
}
$preferredStateRows = [System.Collections.Generic.List[object]]::new()
$receivedStateKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($st in $preferredReviewerStates) {
    $target = [string](Get-Prop $st 'targetModelKey')
    $state = [string](Get-Prop $st 'state')
    $backend = [string](Get-Prop $st 'backend')
    $family = [string](Get-Prop $st 'family')
    $attemptRole = [string](Get-Prop $st 'attemptRole')
    $fallbackOf = [string](Get-Prop $st 'fallbackOf')
    $countsForDiversityRaw = Get-Prop $st 'countsForDiversity'

    if ([string]::IsNullOrWhiteSpace($target)) {
        $blockingReasons.Add('preferred-reviewer-state-missing-target')
        continue
    }
    if ([string]::IsNullOrWhiteSpace($state)) {
        $blockingReasons.Add("preferred-reviewer-state-missing-state:$target")
        continue
    }
    if ($allKnownStates -notcontains $state) {
        $blockingReasons.Add("preferred-reviewer-state-invalid:${target}:${state}")
        continue
    }
    if ($incompleteStates -contains $state) {
        $blockingReasons.Add("preferred-reviewer-state-incomplete:${target}:${state}")
    }
    if ($state -in @('skippedByPolicy', 'skippedAfterSuccess', 'notAttempted')) {
        if ($countsForDiversityRaw -ne $false) {
            $blockingReasons.Add("preferred-reviewer-state-skip-counts-diversity:${target}:${state}")
        }
    }
    if ($state -eq 'notAttempted' -and ([string]::IsNullOrWhiteSpace($attemptRole) -or $attemptRole -eq 'primary')) {
        $blockingReasons.Add("preferred-reviewer-primary-notattempted-silent:${target}")
    }
    if ($requiresStateCompleteness) {
        $stateKey = Get-ReviewerStateKey -Backend $backend -TargetModelKey $target -AttemptRole $attemptRole -FallbackOf $fallbackOf
        if (-not $receivedStateKeys.Add($stateKey)) {
            $blockingReasons.Add("preferred-reviewer-state-duplicate:$target")
        } elseif (-not $expectedStateKeys.Contains($stateKey)) {
            $blockingReasons.Add("preferred-reviewer-state-unexpected:$target")
        }
    }

    $preferredStateRows.Add([pscustomobject]@{
            targetModelKey      = $target
            backend             = $backend
            family              = $family
            state               = $state
            attemptRole         = $attemptRole
            fallbackOf          = $fallbackOf
            countsForDiversity  = $countsForDiversityRaw
        })
}

if ($hadPreferred -and $preferredStateRows.Count -eq 0) {
    $blockingReasons.Add('preferred-reviewer-states-missing')
}
if ($requiresStateCompleteness) {
    foreach ($expected in $expectedStateRows) {
        if (-not $receivedStateKeys.Contains([string]$expected.key)) {
            $blockingReasons.Add("preferred-reviewer-state-missing:$($expected.targetModelKey)")
        }
    }
}

# Eixo de estado da vN+1 (Achado A2). Este closeout e STATELESS: VNextState chega como
# parametro de entrada e e reavaliado do zero a cada chamada; nao ha registro mutavel entre
# invocacoes. A trilha auditavel (append-only por RoundId) e responsabilidade do ORQUESTRADOR
# + recibo/livro-razao, NAO deste script (a monotonicidade entre chamadas exigiria estado
# persistente e contradiria o desenho). A unica forma de mover de pendingResubmission para um
# estado terminal e nova invocacao deste closeout com o VNextState terminal; qualquer outra
# forma de alterar o estado afirmado no recibo e bypass de gate. Limite honesto: este eixo e
# a prova de silencio (converte um "pulei a re-submissao" em afirmacao auditavel e
# falsificavel), nao a prova de fabricacao (o script nao le a conversa para provar a mentira).
$vNextDeclinedBy = ''
if ($null -ne $ResubmissionDeclinedBy) { $vNextDeclinedBy = $ResubmissionDeclinedBy.Trim() }
$vNextDeclineReason = ''
if ($null -ne $ResubmissionDeclineReason) { $vNextDeclineReason = $ResubmissionDeclineReason.Trim() }

if ($VNextState -eq 'pendingResubmission') {
    $blockingReasons.Add('vnext-pending-resubmission')
}
if ($VNextState -eq 'resubmissionDeclinedByHuman') {
    # RoundId tambem e exigido: a regua e stale-por-versao, entao um declinio precisa estar
    # escopado a rodada (sem RoundId o declinio "vazaria" para versoes futuras). Alinha com 15.
    if ([string]::IsNullOrWhiteSpace($vNextDeclinedBy) -or [string]::IsNullOrWhiteSpace($vNextDeclineReason) -or [string]::IsNullOrWhiteSpace($RoundId)) {
        $blockingReasons.Add('vnext-resubmission-decline-unaudited')
    }
}

if ($DiversityState -eq 'insufficientDiversityAfterFallback') {
    $blockingReasons.Add('insufficient-diversity-after-fallback')
}

$labels = @($selectedReviewers | ForEach-Object { Get-ReviewerLabel $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$selectedText = if ($labels.Count -gt 0) { ($labels -join ', ') } else { 'os revisores escolhidos nesta rodada' }

$preferredPath = '%LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json'
$roundLabel = 'desta rodada'
if (-not [string]::IsNullOrWhiteSpace($RoundId)) { $roundLabel = "da rodada '$RoundId'" }
$requiredPrompt = $null
if ($blockingReasons -contains 'vnext-pending-resubmission') {
    $requiredPrompt = "Antes de encerrar a revisão por pares: há uma vN+1 autorada e ainda não re-submetida ($roundLabel). Pela opção 1 (D2), ofereça a 2ª rodada ao painel e, após re-submeter, re-rode este closeout com -VNextState resubmitted; se o humano cientemente declinar a re-submissão, re-rode com -VNextState resubmissionDeclinedByHuman + -ResubmissionDeclinedBy, -ResubmissionDeclineReason e -RoundId."
} elseif ($blockingReasons -contains 'vnext-resubmission-decline-unaudited') {
    $requiredPrompt = "Antes de encerrar a revisão por pares: o declínio de re-submissão da vN+1 ($roundLabel) exige registro auditável — informe -ResubmissionDeclinedBy (quem decidiu), -ResubmissionDeclineReason (por quê) e -RoundId (qual rodada)."
} elseif ($blockingReasons -contains 'insufficient-diversity-after-fallback') {
    $requiredPrompt = 'Antes de encerrar a revisão por pares: a composição final após fallback ficou com diversidade insuficiente. Não use o rótulo revisão por pares; registre como parecer solo, segunda opinião ou rodada não concluída.'
} elseif ($requiresOffer -and ($blockingReasons -contains 'preferred-reviewers-offer-missing' -or $blockingReasons -contains 'preferred-reviewers-offer-state-invalid-for-manual-selection')) {
    $requiredPrompt = "Antes de encerrar a revisão por pares: você quer salvar $selectedText como revisores preferidos desta máquina em ${preferredPath}? Se responder sim, vou usar Set-LlmDelegatePreferredReviewers.ps1; se preferir não salvar ou adiar, sigo sem bloquear esta rodada."
} elseif ($blockingReasons -contains 'preferred-reviewer-expected-states-missing') {
    $requiredPrompt = 'Antes de encerrar a revisão por pares: informe -SelectedReviewersJson com a lista esperada da rodada (titulares e fallbackChain[]) e re-rote este closeout junto de -PreferredReviewerStatesJson. Sem a lista esperada, o script não consegue provar completude dos estados auditáveis.'
} elseif ($blockingReasons.Count -gt 0) {
    $requiredPrompt = 'Antes de encerrar a revisão por pares: registre no recibo o estado final de cada revisor preferido da rodada, sem omitir preferidos não consultados. Se algum ficou fora, informe o motivo auditável.'
}

$closeoutReady = ($blockingReasons.Count -eq 0)
$curationReceipt = if ($requiresOffer) {
    "Curadoria de revisores preferidos: oferta=$PreferredReviewersOfferState; destino=$preferredPath."
} else {
    "Curadoria de revisores preferidos: not_applicable; motivo=" + ($(if ($hadPreferred) { 'preferred-reviewers.json ja existia' } else { 'sem selecao manual de revisores' }))
}
$stateReceipt = if ($hadPreferred) {
    "Estados dos revisores preferidos: registrados=$($preferredStateRows.Count)."
} else {
    'Estados dos revisores preferidos: not_applicable.'
}
# vNextState e SEMPRE ecoado (inclusive notProduced): o campo nao pode ficar silenciosamente
# ausente do recibo (Achado A; corrige o risco do default). No declinio, ecoa quem/por que/RoundId.
$vNextReceipt = "Estado da vN+1: vNextState=$VNextState."
if ($VNextState -eq 'resubmissionDeclinedByHuman') {
    $declineWho = if ([string]::IsNullOrWhiteSpace($vNextDeclinedBy)) { '(nao informado)' } else { $vNextDeclinedBy }
    $declineWhy = if ([string]::IsNullOrWhiteSpace($vNextDeclineReason)) { '(nao informado)' } else { $vNextDeclineReason }
    $declineRound = if ([string]::IsNullOrWhiteSpace($RoundId)) { '(sem RoundId)' } else { $RoundId }
    $vNextReceipt = "Estado da vN+1: vNextState=$VNextState; declinadoPor=$declineWho; motivo=$declineWhy; RoundId=$declineRound."
}
$receiptAddendum = "$curationReceipt $stateReceipt $vNextReceipt"

[pscustomobject]@{
    closeoutReady                = $closeoutReady
    blockingReasons             = @($blockingReasons)
    requiresPreferredOffer       = $requiresOffer
    hadPreferredReviewers        = $hadPreferred
    manualReviewerSelection      = $manualSelection
    preferredReviewersOfferState = $PreferredReviewersOfferState
    roundId                      = $RoundId
    diversityState               = $DiversityState
    vNextState                   = $VNextState
    resubmissionDeclinedBy       = $vNextDeclinedBy
    resubmissionDeclineReason    = $vNextDeclineReason
    selectedReviewers            = @($labels)
    expectedPreferredReviewerStates = @($expectedStateRows)
    preferredReviewerStates      = @($preferredStateRows)
    requiredUserPrompt           = $requiredPrompt
    receiptAddendum              = $receiptAddendum
    note                         = 'Fechamento consultivo/deterministico da revisao por pares; nao grava preferencia, nao decide autorizacao e nao recalcula diversidade. Se closeoutReady=false, nao encerrar a rodada nem emitir recibo final sem antes apresentar requiredUserPrompt.'
} | ConvertTo-Json -Depth 8
