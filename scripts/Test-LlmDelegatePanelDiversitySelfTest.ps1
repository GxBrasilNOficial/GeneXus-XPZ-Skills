#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test de Resolve-LlmDelegatePanelDiversity.ps1 (skill xpz-llm-delegate).
# Cobre o piso de diversidade (>=2 familias distintas) e os tres estados:
#  panelReady / needsBatchAuthorization / insufficientDiversity, mais o sinal de familia
#  do autor no painel e a indiferenca a `deny`.

$target = Join-Path $PSScriptRoot 'Resolve-LlmDelegatePanelDiversity.ps1'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $target -PathType Leaf) "Script ausente: $target"

function Invoke-Diversity {
    param([string]$Json, [string]$AuthorFamily)
    if ([string]::IsNullOrWhiteSpace($AuthorFamily)) {
        return (& $target -CandidatesJson $Json | ConvertFrom-Json)
    }
    return (& $target -CandidatesJson $Json -AuthorFamily $AuthorFamily | ConvertFrom-Json)
}

# (1) 2 allow de familias distintas -> panelReady
$r1 = Invoke-Diversity '[{"targetModelKey":"openai/gpt-5.5","verdict":"allow"},{"targetModelKey":"anthropic/claude-opus-4-8","verdict":"allow"}]'
Assert-True ($r1.state -eq 'panelReady') "Caso 1: esperado panelReady; veio '$($r1.state)'."
Assert-True ($r1.panelReady -eq $true) 'Caso 1: panelReady deveria ser true.'

# (2) 1 allow + 1 ask de NOVA familia -> needsBatchAuthorization, ask listado
$r2 = Invoke-Diversity '[{"targetModelKey":"openai/gpt-5.5","verdict":"allow"},{"targetModelKey":"ollama-cloud/deepseek-v4-pro","verdict":"ask"}]'
Assert-True ($r2.state -eq 'needsBatchAuthorization') "Caso 2: esperado needsBatchAuthorization; veio '$($r2.state)'."
Assert-True (@($r2.askToAuthorize).Count -eq 1) 'Caso 2: deveria listar 1 candidato a autorizar.'
Assert-True (@($r2.askToAuthorize)[0].family -eq 'ollama-cloud') 'Caso 2: o ask a autorizar deveria ser ollama-cloud.'

# (3) 1 allow so -> insufficientDiversity, fallback "segunda opiniao (1)"
$r3 = Invoke-Diversity '[{"targetModelKey":"openai/gpt-5.5","verdict":"allow"}]'
Assert-True ($r3.state -eq 'insufficientDiversity') "Caso 3: esperado insufficientDiversity; veio '$($r3.state)'."
Assert-True ($r3.fallbackLabel -eq 'segunda opiniao (1)') "Caso 3: fallbackLabel deveria ser 'segunda opiniao (1)'; veio '$($r3.fallbackLabel)'."

# (4) 1 allow + 1 ask da MESMA familia -> insufficientDiversity (ask nao adiciona familia)
$r4 = Invoke-Diversity '[{"targetModelKey":"openai/gpt-5.5","verdict":"allow"},{"targetModelKey":"openai/gpt-5-mini","verdict":"ask"}]'
Assert-True ($r4.state -eq 'insufficientDiversity') "Caso 4: ask de mesma familia nao deveria habilitar painel; veio '$($r4.state)'."
Assert-True (@($r4.askToAuthorize).Count -eq 0) 'Caso 4: ask de familia ja coberta nao entra em askToAuthorize.'

# (5) familia do autor no painel -> panelReady, mas authorFamilyInPanel sinalizado
$r5 = Invoke-Diversity '[{"targetModelKey":"anthropic/claude-opus-4-8","verdict":"allow"},{"targetModelKey":"openai/gpt-5.5","verdict":"allow"}]' -AuthorFamily 'anthropic'
Assert-True ($r5.state -eq 'panelReady') "Caso 5: esperado panelReady; veio '$($r5.state)'."
Assert-True ($r5.authorFamilyInPanel -eq $true) 'Caso 5: authorFamilyInPanel deveria ser true (anthropic no painel).'

# (6) `deny` e ignorado: 1 allow + 1 deny -> insufficientDiversity (deny nao conta)
$r6 = Invoke-Diversity '[{"targetModelKey":"openai/gpt-5.5","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"deny"}]'
Assert-True ($r6.state -eq 'insufficientDiversity') "Caso 6: deny nao deveria contar para diversidade; veio '$($r6.state)'."

# (7) invariante consultiva: a saida nao carrega veredito de autorizacao
Assert-True ($null -eq ($r1.PSObject.Properties['verdict'])) 'Caso 7: a saida NAO deve ter campo verdict (e consultiva, nao autorizacao).'
Assert-True (-not [string]::IsNullOrWhiteSpace([string]$r1.note)) 'Caso 7: note (invariante consultivo) ausente.'

# (8) Pos-fallback: skip nao conta diversidade; uma familia respondida apos fallback ainda e insuficiente.
$r8 = Invoke-Diversity '[{"targetModelKey":"openai/gpt-5.5","state":"responded","attemptRole":"fallback","fallbackOf":"ollama-cloud/deepseek","countsForDiversity":true},{"targetModelKey":"ollama-cloud/deepseek","state":"skippedAfterSuccess","attemptRole":"fallback","fallbackOf":"ollama-cloud/primary","countsForDiversity":false}]'
Assert-True ($r8.state -eq 'insufficientDiversityAfterFallback') "Caso 8: esperado insufficientDiversityAfterFallback; veio '$($r8.state)'."
Assert-True ($r8.panelReady -eq $false) 'Caso 8: panelReady deveria ser false.'
Assert-True (@($r8.distinctFamiliesAllow).Count -eq 1) 'Caso 8: skips com countsForDiversity=false nao devem inflar familias.'

# (9) antigravity/gemini-* colapsa em google (sem diversidade contra google direto)
$r9 = Invoke-Diversity '[{"targetModelKey":"antigravity/gemini-3.6-flash","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r9.state -eq 'insufficientDiversity') "Caso 9: antigravity/gemini e google compartilham familia google; esperado insufficientDiversity; veio '$($r9.state)'."

# (10) antigravity/claude-* pontua como anthropic (diversidade real contra google)
$r10 = Invoke-Diversity '[{"targetModelKey":"antigravity/claude-sonnet-4.6","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r10.state -eq 'panelReady') "Caso 10: antigravity/claude e google sao familias distintas; esperado panelReady; veio '$($r10.state)'."

Write-Output 'OK: Test-LlmDelegatePanelDiversitySelfTest.ps1'
