#requires -Version 7.4
<#
.SYNOPSIS
    Avalia, de forma CONSULTIVA, se um conjunto de candidatos a revisor (com seus vereditos
    de gate) atinge o PISO DE DIVERSIDADE de uma revisao por pares (>=2 familias distintas).
.DESCRIPTION
    Parte do mecanismo da skill xpz-llm-delegate; metodologia em 15-revisao-por-pares.md.

    Por que existe: o modo de falha real foi o painel COLAPSAR para 1 revisor em contexto
    kb-sensitive (os diversos eram externos -> gate `ask` -> agente descartou os `ask` em
    silencio e seguiu com o unico pre-autorizado). Uma "revisao por pares" com 1 voz NAO e
    revisao por pares (guardrail do 15/14). Este motor torna o piso MECANICO, em vez de
    depender de regra textual que pode ser ignorada em silencio.

    INVARIANTE (consultivo, nao autorizacao): este motor NAO decide allow/ask/deny — ele
    recebe os vereditos que o gate (Resolve-LlmDelegateAuthorization.ps1) ja emitiu por
    revisor, e so conta familias. O gate continua soberano por destino+sensibilidade.

    Familia = provider de DESTINO (parte antes da primeira '/' do targetModelKey): openai,
    anthropic, ollama-cloud, google, github-copilot, etc. Modelos do mesmo provider
    compartilham vieses de treino, logo nao contam como diversidade entre si.

    Piso: >=2 familias distintas entre si entre os revisores DESPACHAVEIS (verdict=allow).
    `ask` ainda nao conta como painel montado — conta como candidato AUTORIZAVEL (se
    autorizar fecha o piso, o estado e needsBatchAuthorization). `deny` e ignorado.
    Idealmente as familias sao distintas da do autor (-AuthorFamily); familia do autor no
    painel nao reprova, mas e sinalizada (authorFamilyInPanel).

    Estados:
      panelReady              -> >=2 familias distintas ja em `allow`
      needsBatchAuthorization -> `allow` tem <2 familias, mas allow+ask alcancam >=2:
                                 apresentar askToAuthorize ao usuario para autorizacao EM LOTE
      insufficientDiversity   -> nem allow+ask alcancam >=2 familias: nao ha painel possivel;
                                 fallbackLabel = "segunda opiniao (N)" (N = despachaveis allow)
      insufficientDiversityAfterFallback -> pos-despacho: houve fallback/skip auditavel, mas as
                                 familias efetivamente respondidas ficaram abaixo do piso

    Saida: objeto JSON de maquina no stdout.
.PARAMETER CandidatesJson
    JSON (array) dos candidatos com veredito do gate: [{ "targetModelKey": "openai/gpt-5.5",
    "verdict": "allow|ask|deny", "backend": "codex" }]. `backend` e opcional (so repassado).
    Para avaliacao pos-despacho, aceita tambem `state=responded` e `countsForDiversity=false`
    em tentativas de fallback/skip; skips nao contam familias.
.PARAMETER Floor
    Piso de familias distintas. Default 2. Nao baixar para 1 (reintroduz o bug).
.PARAMETER AuthorFamily
    Familia do autor/orquestrador (ex.: anthropic), para sinalizar falta de cego externo.
.EXAMPLE
    .\Resolve-LlmDelegatePanelDiversity.ps1 -CandidatesJson '[{"targetModelKey":"openai/gpt-5.5","verdict":"allow"},{"targetModelKey":"ollama-cloud/deepseek-v4-pro","verdict":"ask"}]'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)] [string] $CandidatesJson,
    [int] $Floor = 2,
    [string] $AuthorFamily
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'LlmDelegateTargetFamilySupport.ps1')

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -ne $Obj -and -not [string]::IsNullOrEmpty($Name) -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Get-Family {
    param([string]$TargetModelKey)
    return Get-LlmDelegateTargetFamily -TargetModelKey $TargetModelKey
}

$parsed = $null
try { $parsed = $CandidatesJson | ConvertFrom-Json } catch {
    throw "BLOCK: -CandidatesJson nao e JSON valido: $($_.Exception.Message)"
}
$items = @($parsed)

$allowFamilies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$askByNewFamily = [System.Collections.Generic.List[object]]::new()
$potentialFamilies = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$dispatchable = [System.Collections.Generic.List[object]]::new()

# 1) Familias ja despachaveis (allow).
foreach ($it in $items) {
    $countsRaw = Get-Prop $it 'countsForDiversity'
    if ($countsRaw -eq $false) { continue }
    $verdict = [string](Get-Prop $it 'verdict')
    $stateValue = [string](Get-Prop $it 'state')
    if ([string]::IsNullOrWhiteSpace($verdict) -and $stateValue -eq 'responded') { $verdict = 'allow' }
    $target = [string](Get-Prop $it 'targetModelKey')
    $fam = Get-Family $target
    if ([string]::IsNullOrWhiteSpace($fam)) { continue }
    if ($verdict -eq 'allow') {
        [void]$allowFamilies.Add($fam)
        [void]$potentialFamilies.Add($fam)
        $dispatchable.Add([pscustomobject]@{ targetModelKey = $target; family = $fam; backend = [string](Get-Prop $it 'backend') })
    }
}

# 2) `ask` que adicionam familia ainda nao coberta por `allow` (candidatos a autorizar em lote).
foreach ($it in $items) {
    $countsRaw = Get-Prop $it 'countsForDiversity'
    if ($countsRaw -eq $false) { continue }
    $verdict = [string](Get-Prop $it 'verdict')
    $stateValue = [string](Get-Prop $it 'state')
    if ([string]::IsNullOrWhiteSpace($verdict) -and $stateValue -eq 'responded') { $verdict = 'allow' }
    if ($verdict -ne 'ask') { continue }
    $target = [string](Get-Prop $it 'targetModelKey')
    $fam = Get-Family $target
    if ([string]::IsNullOrWhiteSpace($fam)) { continue }
    [void]$potentialFamilies.Add($fam)
    if (-not $allowFamilies.Contains($fam)) {
        $askByNewFamily.Add([pscustomobject]@{ targetModelKey = $target; family = $fam; backend = [string](Get-Prop $it 'backend') })
    }
}

$allowCount = $allowFamilies.Count
$potentialCount = $potentialFamilies.Count

$hasFallbackEvidence = @($items | Where-Object { -not [string]::IsNullOrWhiteSpace([string](Get-Prop $_ 'fallbackOf')) -or [string](Get-Prop $_ 'attemptRole') -eq 'fallback' }).Count -gt 0

$state = if ($allowCount -ge $Floor) { 'panelReady' }
elseif ($potentialCount -ge $Floor) { 'needsBatchAuthorization' }
elseif ($hasFallbackEvidence) { 'insufficientDiversityAfterFallback' }
else { 'insufficientDiversity' }

$authorInPanel = $false
if (-not [string]::IsNullOrWhiteSpace($AuthorFamily)) {
    $authorInPanel = $allowFamilies.Contains($AuthorFamily.Trim())
}

$fallbackLabel = if ($state -ne 'panelReady') { "segunda opiniao ($($dispatchable.Count))" } else { $null }

[pscustomobject]@{
    floor                     = $Floor
    panelReady                = ($state -eq 'panelReady')
    state                     = $state
    distinctFamiliesAllow     = @($allowFamilies)
    distinctFamiliesPotential = @($potentialFamilies)
    dispatchable              = @($dispatchable)
    askToAuthorize            = @($askByNewFamily)
    authorFamily              = $AuthorFamily
    authorFamilyInPanel       = $authorInPanel
    fallbackLabel             = $fallbackLabel
    note                      = 'Consultivo; NAO e autorizacao. O gate Resolve-LlmDelegateAuthorization decide allow/ask/deny por revisor. Familia = provider de destino. Piso conta familias distintas entre despachaveis (allow); ask = autorizavel; deny ignorado.'
} | ConvertTo-Json -Depth 8
