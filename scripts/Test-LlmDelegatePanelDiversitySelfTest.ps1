#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Self-test de Resolve-LlmDelegatePanelDiversity.ps1 (skill xpz-llm-delegate).
# Cobre o piso de diversidade (>=2 familias distintas) e os estados:
#  panelReady / needsBatchAuthorization / insufficientDiversity /
#  insufficientDiversityAfterFallback, mais droppedUnknownFamilies.

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

# (8) Pos-fallback: exige dispatchAttempted=true OU attempts>=1 para AfterFallback
$r8 = Invoke-Diversity '[{"targetModelKey":"openai/gpt-5.5","state":"responded","attemptRole":"fallback","fallbackOf":"ollama-cloud/deepseek","dispatchAttempted":true,"countsForDiversity":true},{"targetModelKey":"ollama-cloud/deepseek","state":"skippedAfterSuccess","attemptRole":"fallback","fallbackOf":"ollama-cloud/primary","countsForDiversity":false}]'
Assert-True ($r8.state -eq 'insufficientDiversityAfterFallback') "Caso 8: esperado insufficientDiversityAfterFallback; veio '$($r8.state)'."
Assert-True ($r8.panelReady -eq $false) 'Caso 8: panelReady deveria ser false.'
Assert-True (@($r8.distinctFamiliesAllow).Count -eq 1) 'Caso 8: skips com countsForDiversity=false nao devem inflar familias.'

# (9) antigravity/gemini-* colapsa em google (sem diversidade contra google direto)
$r9 = Invoke-Diversity '[{"targetModelKey":"antigravity/gemini-3.6-flash","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r9.state -eq 'insufficientDiversity') "Caso 9: antigravity/gemini e google compartilham familia google; esperado insufficientDiversity; veio '$($r9.state)'."

# (10) antigravity/claude-* vs google/gemini-* sao 2 familias distintas (anthropic vs google)
$r10 = Invoke-Diversity '[{"targetModelKey":"antigravity/claude-sonnet-4-6","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r10.state -eq 'panelReady') "Caso 10: antigravity/claude-* (anthropic) + google (google) -> panelReady; veio '$($r10.state)'."

# (11) chave 'unknown' (sem barra) e descartada; so google conta -> insufficientDiversity
$r11 = Invoke-Diversity '[{"targetModelKey":"unknown","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r11.state -eq 'insufficientDiversity') "Caso 11: unknown descartado; esperado insufficientDiversity; veio '$($r11.state)'."
Assert-True ($r11.unknownFamiliesPresent -eq $true) 'Caso 11: unknownFamiliesPresent deveria ser true.'
Assert-True (@($r11.dispatchable).Count -eq 1) "Caso 11: so google deve ser dispatchable; veio '$(@($r11.dispatchable).Count)'."

# (12) nvidia/minimaxai/* vs nvidia/z-ai/* sao 2 criadores distintos (minimaxai vs z-ai) -> panelReady
$r12 = Invoke-Diversity '[{"targetModelKey":"nvidia/minimaxai/minimax-m3","verdict":"allow"},{"targetModelKey":"nvidia/z-ai/glm-5.2","verdict":"allow"}]'
Assert-True ($r12.state -eq 'panelReady') "Caso 12: nvidia/minimaxai e nvidia/z-ai sao criadores distintos; esperado panelReady; veio '$($r12.state)'."
Assert-True (@($r12.distinctFamiliesAllow).Count -eq 2) "Caso 12: esperado 2 distinctFamiliesAllow; veio '$(@($r12.distinctFamiliesAllow).Count)'."

# (13) nvidia/meta/* vs meta/* direto compartilham criador meta -> insufficientDiversity
$r13 = Invoke-Diversity '[{"targetModelKey":"nvidia/meta/llama-3.3-70b-instruct","verdict":"allow"},{"targetModelKey":"meta/llama-3.3-70b-instruct","verdict":"allow"}]'
Assert-True ($r13.state -eq 'insufficientDiversity') "Caso 13: nvidia/meta e meta direto compartilham criador meta; esperado insufficientDiversity; veio '$($r13.state)'."

# (14) normalizacao canonica de sub-org: nvidia/deepseek-ai/* colapsa em deepseek
$r14 = Invoke-Diversity '[{"targetModelKey":"nvidia/deepseek-ai/deepseek-r1","verdict":"allow"},{"targetModelKey":"deepseek/deepseek-r1","verdict":"allow"}]'
Assert-True ($r14.state -eq 'insufficientDiversity') "Caso 14: deepseek-ai e deepseek normalizam para o mesmo criador; esperado insufficientDiversity; veio '$($r14.state)'."

# (15) normalizacao canonica de sub-org: nvidia/mistralai/* colapsa em mistral
$r15 = Invoke-Diversity '[{"targetModelKey":"nvidia/mistralai/mistral-large","verdict":"allow"},{"targetModelKey":"mistral/mistral-large","verdict":"allow"}]'
Assert-True ($r15.state -eq 'insufficientDiversity') "Caso 15: mistralai e mistral normalizam para o mesmo criador; esperado insufficientDiversity; veio '$($r15.state)'."

# (16) normalizacao canonica de sub-org: nvidia/qwen/* colapsa em alibaba
$r16 = Invoke-Diversity '[{"targetModelKey":"nvidia/qwen/qwen2.5-coder-32b","verdict":"allow"},{"targetModelKey":"alibaba/qwen2.5-coder-32b","verdict":"allow"}]'
Assert-True ($r16.state -eq 'insufficientDiversity') "Caso 16: qwen e alibaba normalizam para o mesmo criador; esperado insufficientDiversity; veio '$($r16.state)'."

# (17) nvidia/nvidia/* (Nemotron) vs nvidia/minimaxai/* sao 2 criadores distintos (nvidia vs minimaxai)
$r17 = Invoke-Diversity '[{"targetModelKey":"nvidia/nvidia/nemotron-3-super-120b-a12b","verdict":"allow"},{"targetModelKey":"nvidia/minimaxai/minimax-m3","verdict":"allow"}]'
Assert-True ($r17.state -eq 'panelReady') "Caso 17: nvidia/nvidia e nvidia/minimaxai sao criadores distintos; esperado panelReady; veio '$($r17.state)'."

# (18) chave nvidia de 2 niveis (ex.: nvidia/nemotron-*) resolve criador nvidia
$r18 = Invoke-Diversity '[{"targetModelKey":"nvidia/nemotron-3-super-120b-a12b","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r18.state -eq 'panelReady') "Caso 18: chave nvidia de 2 niveis deve resolver criador nvidia; veio '$($r18.state)'."
Assert-True (@($r18.distinctFamiliesAllow) -contains 'nvidia') "Caso 18: distinctFamiliesAllow deve conter 'nvidia'."

# (19) sub-org desconhecida sob nvidia e descartada (custom-lab fora da allowlist)
$r19 = Invoke-Diversity '[{"targetModelKey":"nvidia/custom-lab/model-x","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r19.state -eq 'insufficientDiversity') "Caso 19: custom-lab descartado; esperado insufficientDiversity; veio '$($r19.state)'."
Assert-True ($r19.unknownFamiliesPresent -eq $true) 'Caso 19: unknownFamiliesPresent deveria ser true.'
Assert-True (-not (@($r19.distinctFamiliesAllow) -contains 'custom-lab')) 'Caso 19: custom-lab nao deve contar no piso.'

# (20) antigravity/gpt-* colapsa em openai
$r20 = Invoke-Diversity '[{"targetModelKey":"antigravity/gpt-5-preview","verdict":"allow"},{"targetModelKey":"openai/gpt-5.5","verdict":"allow"}]'
Assert-True ($r20.state -eq 'insufficientDiversity') "Caso 20: antigravity/gpt-* e openai compartilham criador openai; esperado insufficientDiversity; veio '$($r20.state)'."

# (21) antigravity com modelo desconhecido preserva default historico google
$r21 = Invoke-Diversity '[{"targetModelKey":"antigravity/custom-model-y","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r21.state -eq 'insufficientDiversity') "Caso 21: antigravity com modelo desconhecido deve cair no default google; esperado insufficientDiversity; veio '$($r21.state)'."

# (22) chaves nvidia de 2 niveis desconhecidas colapsam ambas no fallback conservador nvidia (evita supercontagem)
$r22 = Invoke-Diversity '[{"targetModelKey":"nvidia/custom-model-a","verdict":"allow"},{"targetModelKey":"nvidia/custom-model-b","verdict":"allow"}]'
Assert-True ($r22.state -eq 'insufficientDiversity') "Caso 22: chaves nvidia de 2 niveis desconhecidas devem colapsar em nvidia (sem supercontar); esperado insufficientDiversity; veio '$($r22.state)'."
Assert-True (@($r22.distinctFamiliesAllow).Count -eq 1) "Caso 22: esperado 1 distinctFamiliesAllow ('nvidia'); veio '$(@($r22.distinctFamiliesAllow).Count)'."
Assert-True (@($r22.distinctFamiliesAllow) -contains 'nvidia') "Caso 22: distinctFamiliesAllow deve conter 'nvidia'."

# (23) dois primarios, um responde, sem cadeia -> insufficientDiversity (nao AfterFallback)
$r23 = Invoke-Diversity '[{"targetModelKey":"openai/gpt-5.5","state":"responded","attemptRole":"primary"},{"targetModelKey":"anthropic/claude-opus-4-8","state":"error","attemptRole":"primary"}]'
Assert-True ($r23.state -eq 'insufficientDiversity') "Caso 23: esperado insufficientDiversity (sem evidencia de fallback); veio '$($r23.state)'."
Assert-True ($r23.state -ne 'insufficientDiversityAfterFallback') 'Caso 23: nao deve ser AfterFallback sem cadeia despachada.'

# (24) unknown descartado aparece em droppedUnknownFamilies
$r24 = Invoke-Diversity '[{"targetModelKey":"unknown","verdict":"allow"},{"targetModelKey":"google/gemini-3-flash-preview","verdict":"allow"}]'
Assert-True ($r24.unknownFamiliesPresent -eq $true) 'Caso 24: unknownFamiliesPresent deveria ser true.'
$droppedKeys = @($r24.droppedUnknownFamilies | ForEach-Object { [string]$_.targetModelKey })
Assert-True ($droppedKeys -contains 'unknown') "Caso 24: droppedUnknownFamilies deveria conter 'unknown'; veio '$($droppedKeys -join ',')'."

# (25) Grok nativo no Cursor sem barra resolve em xai e abre diversidade contra openai
$r25 = Invoke-Diversity '[{"targetModelKey":"cursor-grok-4.6-medium","verdict":"allow"},{"targetModelKey":"openai/gpt-5.6","verdict":"allow"}]'
Assert-True ($r25.state -eq 'panelReady') "Caso 25: cursor-grok-* + openai deveriam formar panelReady; veio '$($r25.state)'."
Assert-True (@($r25.distinctFamiliesAllow).Count -eq 2) "Caso 25: esperado xai + openai; veio '$(@($r25.distinctFamiliesAllow) -join ',')'."
Assert-True (@($r25.distinctFamiliesAllow) -contains 'xai') "Caso 25: distinctFamiliesAllow deveria conter 'xai'."
Assert-True (@($r25.distinctFamiliesAllow) -contains 'openai') "Caso 25: distinctFamiliesAllow deveria conter 'openai'."

# (26) as duas grafias do Grok nativo no Cursor representam o mesmo criador xai
$r26 = Invoke-Diversity '[{"targetModelKey":"cursor-grok-4.6-medium","verdict":"allow"},{"targetModelKey":"cursor/grok-4","verdict":"allow"}]'
Assert-True ($r26.state -eq 'insufficientDiversity') "Caso 26: as duas grafias de Cursor/Grok nao deveriam criar diversidade; veio '$($r26.state)'."
Assert-True (@($r26.distinctFamiliesAllow).Count -eq 1) "Caso 26: esperado um unico criador; veio '$(@($r26.distinctFamiliesAllow) -join ',')'."
Assert-True (@($r26.distinctFamiliesAllow) -contains 'xai') "Caso 26: distinctFamiliesAllow deveria conter 'xai'."

# (27) Cursor sem mapeamento explicito continua desconhecido no piso de diversidade
$r27 = Invoke-Diversity '[{"targetModelKey":"cursor/modelo-sem-mapeamento","verdict":"allow"},{"targetModelKey":"openai/gpt-5.6","verdict":"allow"}]'
Assert-True ($r27.state -eq 'insufficientDiversity') "Caso 27: cursor/<modelo> desconhecido nao deveria abrir diversidade; veio '$($r27.state)'."
Assert-True ($r27.unknownFamiliesPresent -eq $true) 'Caso 27: cursor/<modelo> sem mapeamento deveria sinalizar familia desconhecida.'
Assert-True (@($r27.distinctFamiliesAllow).Count -eq 1) "Caso 27: apenas openai deveria contar; veio '$(@($r27.distinctFamiliesAllow) -join ',')'."
Assert-True (-not (@($r27.distinctFamiliesAllow) -contains 'cursor')) "Caso 27: cursor nao deveria contar como criador conhecido."

# (28) Composer nativo resolve em anysphere (Criador dos pesos) e abre diversidade contra openai
$r28 = Invoke-Diversity '[{"targetModelKey":"cursor/composer-2","verdict":"allow"},{"targetModelKey":"openai/gpt-5.6","verdict":"allow"}]'
Assert-True ($r28.state -eq 'panelReady') "Caso 28: cursor/composer-* + openai deveriam formar panelReady; veio '$($r28.state)'."
Assert-True (@($r28.distinctFamiliesAllow) -contains 'anysphere') "Caso 28: distinctFamiliesAllow deveria conter 'anysphere'; veio '$(@($r28.distinctFamiliesAllow) -join ',')'."

# (29) Composer e Grok sao Criadores DISTINTOS: aquisicao societaria nao funde linhagem de pesos
$r29 = Invoke-Diversity '[{"targetModelKey":"cursor-composer-2-medium","verdict":"allow"},{"targetModelKey":"cursor/grok-4","verdict":"allow"}]'
Assert-True ($r29.state -eq 'panelReady') "Caso 29: Composer + Grok deveriam formar panelReady; veio '$($r29.state)'."
Assert-True (@($r29.distinctFamiliesAllow).Count -eq 2) "Caso 29: esperado anysphere + xai; veio '$(@($r29.distinctFamiliesAllow) -join ',')'."
Assert-True (@($r29.distinctFamiliesAllow) -contains 'anysphere') "Caso 29: distinctFamiliesAllow deveria conter 'anysphere'."
Assert-True (@($r29.distinctFamiliesAllow) -contains 'xai') "Caso 29: distinctFamiliesAllow deveria conter 'xai'."

Write-Host "OK: Test-LlmDelegatePanelDiversitySelfTest.ps1"
