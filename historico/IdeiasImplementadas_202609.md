# Ideias Implementadas — 2026-09

Registro de ideias que sairam de 999-ideias-pendentes.md por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Preservar mais evidencia quando o `claude` sai `1` sem saida classificavel

Implementado em 2026-09-01 a partir do manuscrito `Temp/manuscript-claude-evidence-preservation-v3.md`.

Quatro falhas de diagnostico e runtime foram corrigidas nos adapters (`Invoke-ClaudeCode.ps1`, `Invoke-ClaudeCodeAsync.ps1`), no dispatcher (`Invoke-LlmDelegatePanelDispatch.ps1`) e na biblioteca de suporte (`ClaudeCodeCliSupport.ps1`):

1. **Filtro de ruido de ambiente ampliado para `deny`:** `Test-ClaudeCodeEnvironmentNoiseLine` e `Remove-ClaudeCodeEnvironmentNoise` passaram a filtrar avisos `Permission deny rule (...)` e `Ignoring N permissions.deny entries...` alem dos `allow` ja cobertos. Corrige o incidente de 2026-08-31 onde avisos `Write vs Edit` no stderr dominaram o diagnostico erroneamente.

2. **Sentinelas de spend-limit/session-limit/cota adicionadas:** `Get-ClaudeCodeErrorMessage` agora busca `spend limit`, `monthly limit`, `session limit`, `rate limit`, `usage limit`, `quota` e a URL `claude.ai/settings/usage` no texto combinado de stdout+stderr limpo. A rota sincrona preserva a evidencia textual no BLOCK sem criar o estado estruturado `quota` reservado ao sidecar assincrono.

3. **Ramo de erro reestruturado em `Invoke-ClaudeCode.ps1`:** Em `exit != 0` sem erro reconhecido, o adapter agora preserva evidencia de ambos os canais (stdout + stderr limpo de ruido, ate 8 linhas cada) em vez de despejar stderr bruto. O caso `exit 0 + stdout vazio` mantem o comportamento anterior. A mensagem nao afirma mais "sem resposta" quando ha texto presente em algum canal.

4. **Correcao de overflow em `durationMs`:** `Invoke-ClaudeCodeAsync.ps1` e `Invoke-LlmDelegatePanelDispatch.ps1` migraram o casting de `durationMs` para `[long]`, eliminando estouro de `Int32` ao calcular milissegundos em intervalos de calendario e desbloqueando a suite `Test-ClaudeCodeAsyncSelfTest.ps1`.

Testes adicionados em `Test-ClaudeCodeCliSupportSelfTest.ps1`: filtragem de deny (unitario), extracao simetrica de spend-limit (stdout e stderr), session limit medido em producao, stderr misto (ruido + erro real), ruido puro, exit 0 com ruido + resposta valida, e 3 cenarios E2E com `New-FakeClaudeCodeExe` refatorado para goto/labels (SPEND_LIMIT, NOISE_ONLY, UNCLASSIFIED). Total: 97 testes passando no suporte síncrono e suite assíncrona verde.

Documentacao atualizada: `xpz-llm-delegate/SKILL.md` (deny + spend-limit/session-limit sync), `09-inventario-e-rastreabilidade-publica.md` (ponteiros dos scripts), `CHANGELOG.md` (3 idiomas).

Entrada residual preservada em `999-ideias-pendentes.md`: item 5 (avaliar paridade minima de evidencia de cota na rota sync sem misturar o circuito do painel — frente dedicada futura).

### Rastreabilidade

- Commit material: `0e61cc8` (`feat(claude-code): preservar evidencia textual em exit 1 e ampliar filtro de ruido`)
- Commit material (refinamento em producao): `94ffe02` (`feat(claude-code): adicionar sentinela de session limit ao extrator de erro`)
- Commit material (alinhamento documental): `2919d39` (`docs(claude-code): alinhar session limit na documentacao, changelog e rastreabilidade historica`)
- Commit material (fix factual e durationMs): `1ef6ca8` (`fix(claude-code): corrigir contagem de testes, paridade deny no SKILL e overflow de durationMs no async`)
- Commit material (documentacao durationMs): `8a4e64b` (`docs(claude-code): documentar correcao durationMs no changelog e atualizar historico`)
- Commit material (uniformizacao dispatcher): `0a6ca4a` (`fix(llm-delegate): uniformizar durationMs para long em Invoke-LlmDelegatePanelDispatch`)
- Arquivos materiais: `scripts/ClaudeCodeCliSupport.ps1`, `scripts/Invoke-ClaudeCode.ps1`, `scripts/Invoke-ClaudeCodeAsync.ps1`, `scripts/Invoke-LlmDelegatePanelDispatch.ps1`, `scripts/Test-ClaudeCodeCliSupportSelfTest.ps1`, `xpz-llm-delegate/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md`, `999-ideias-pendentes.md`.

## Deteccao de erro, cota/rate-limit e preservacao de evidencia no backend Codex

Implementado em 2026-09-01 conforme previsto em `999-ideias-pendentes.md` (fatia Codex de «Estender a detecção de limite de uso/taxa do provider aos adapters de delegação irmãos» e residuais da captura durável).

Três aprimoramentos principais no backend Codex (`CodexCliSupport.ps1`, `Invoke-Codex.ps1`, `Watch-CodexJob.ps1`):

1. **Extracao ampliada de mensagens de erro em `Get-CodexExecErrorMessage`:**
   - Mantida extracao de linhas `ERROR: {json}` e fallback `ERROR: <texto>`.
   - Adicionada extracao de objetos JSON de erro nativos da API (ex: `{"error":{"message":"...","type":"..."}}` ou `{"error":"..."}`) sem a obrigatoriedade do prefixo literal `ERROR:`.
   - Adicionada deteccao de sentinelas de cota/rate-limit (`429`, `rate_limit`, `insufficient_quota`, `quota`, `credit balance`, `token limit`, `too many requests`, `usage limit`), autenticacao (`unauthorized`, `authentication`, `auth error`, `invalid_api_key`, `token expired`, `session expired`, `forbidden`) e servico/modelo (`overloaded`, `service unavailable`, `model ... does not exist`, `not supported`, `not available`, `not found`) no texto combinado de stdout e stderr limpos.

2. **Preservacao de status `error` em `Resolve-CodexJobStatus` (`Watch-CodexJob.ps1`):**
   - Na ausencia de resposta final (`FinalText` vazio), quando `Get-CodexExecErrorMessage` reconhece erro no stream ou stderr, o status do job e classificado como `error` com a mensagem preservada, evitando classificacao incorreta como `sem-texto`.

3. **Preservacao simetrica de evidencia em `Invoke-Codex.ps1`:**
   - Em `exit != 0`, quando `Get-CodexExecErrorMessage` extrai erro, propaga `BLOCK: codex retornou erro: <msg>`.
   - Quando nao ha erro reconhecido, porem ha texto em `stdout` e/ou `stderr`, preserva ate 8 linhas limpas de cada canal sob `stdout:` / `stderr:`, sem afirmar "sem resposta" quando ha saida nos canais.
   - Quando ambos os canais estao vazios, preserva a mensagem `BLOCK: codex saiu com codigo N sem resposta.`.

Testes adicionados e validados:
- 17 novos casos em `Test-CodexCliSupportSelfTest.ps1` cobrindo JSON de erro da API sem prefixo, sentinelas de rate limit/429/cota/saldo/autenticacao/modelo inexistente/servidor sobrecarregado, e classificacao `Resolve-CodexJobStatus` com preservacao de mensagem. Total: 32 asserts PASS.
- Caso 12q adicionado em `Test-CodexDurableCaptureSelfTest.ps1` validando preservacao de stdout/stderr em `exit 1` sem erro reconhecido. Suite inteira PASS.

Documentacao atualizada: `xpz-llm-delegate/SKILL.md` (backend Codex), `09-inventario-e-rastreabilidade-publica.md` (ponteiros de `CodexCliSupport.ps1` e `Invoke-Codex.ps1`), `CHANGELOG.md` (trilingue) e `999-ideias-pendentes.md`.

### Rastreabilidade

- Commit material: `bad2cdb` (`feat(codex): aprimorar deteccao de erros, cota e preservacao de evidencia`)
- Arquivos materiais: `scripts/CodexCliSupport.ps1`, `scripts/Invoke-Codex.ps1`, `scripts/Test-CodexCliSupportSelfTest.ps1`, `scripts/Test-CodexDurableCaptureSelfTest.ps1`, `xpz-llm-delegate/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md`, `999-ideias-pendentes.md`, `historico/IdeiasImplementadas_202609.md`.

## Estabilizacao do painel no Cursor e taxonomia de Criador para os nativos do harness

Implementado em 2026-09-04, em quatro commits encadeados mais a rodada de correcao de gaps apontada por revisao externa. Frente pontual, sem item previo no `999`.

### O que motivou

Revisao agentica longa conduzida a partir do Cursor esbarrava em dois problemas distintos que se apresentavam juntos: (a) titulares `codex` e `opencode` estouravam o default de 180s do adapter em manuscritos grandes, e (b) os subagentes nativos do proprio Cursor nao tinham Criador do Modelo resolvivel, entao nao contavam no piso de diversidade e o painel montado de dentro do Cursor nunca fechava `panelReady` sem um backend CLI externo.

### O que foi feito

1. **Timeout e transporte do painel (`ec7c5d3`):** default de `TimeoutSec` de `codex`/`opencode` passou de 180 para 1200, injetado no splat somente nesses dois backends quando `invokeArgs` omite `timeoutSec`; TempDir Bound do Codex isolado em `%TEMP%\xpz-llm-panel-codex\<RoundId>`, fora do `-Cd` e do ledger; validacao fail-closed de `RoundId` antes de qualquer despacho (o valor compoe caminho); `ValidateRange(1, 3600)` em `-TimeoutSec` nos dois adapters; fallback com overhead de 120s e `MaxAttempts=2` no opencode.

2. **Criador `xai` para o Grok nativo (`49dca32`, `8369ba7`, `c1ec5e0`):** allowlist de Criadores ampliada com `xai`; `cursor-grok-*` (slug de harness sem barra) e `cursor/grok-*` passam a resolver `xai`; `Resolve-OrchestratorNativeModelLocality.ps1` classifica esses slugs como `external`/`native-cloud-creator`.

3. **Criador `anysphere` para o Composer nativo e contrato de chave de harness:** allowlist ampliada com `anysphere`; `cursor-composer-*` / `cursor/composer-*` resolvem `anysphere`. A decisao humana registrada aqui e a que importa para o futuro: **Criador do Modelo e quem treinou os pesos, nao o dono societario**. A xAI ter comprado o Cursor nao funde as linhagens — Composer (Anysphere) e Grok (xAI) continuam Criadores distintos e somam duas familias no piso, do mesmo modo que `microsoft` e `openai` ja conviviam na tabela do `15`. Fundir os dois em `xai` teria o efeito oposto ao desejado: um painel Composer + Grok cairia em `insufficientDiversity`.

4. **Contrato de chave de harness Cursor na curadoria:** `Test-CursorPrefix` saiu do `Set-LlmDelegatePreferredReviewers.ps1` e virou `Test-LlmDelegateCursorHarnessKey` na biblioteca compartilhada `LlmDelegateTargetFamilySupport.ps1`, reconhecendo as duas grafias. Chave de harness Cursor agora e aceita apenas como titular **nativo** com Criador conhecido; como alvo CLI (nenhum backend da lista despacha para modelo que so existe dentro do Cursor) e como elo de `fallbackChain[]` fica bloqueada com `native-cursor-prefix` e exit 3. O bloqueio passou a cobrir tambem o slug sem barra, que antes escapava por o `split` em `/` devolver a chave inteira.

   O predicado ficou na biblioteca porque a mesma regra vale nos dois sentidos: o `Resolve-LlmDelegatePreferredReviewers.ps1` passou a aplica-la na **leitura**. Antes, so o escritor validava — arquivo de curadoria editado a mao com chave de harness Cursor sob backend CLI era lido sem reclamacao e entregava ao painel um titular indespachavel, que so falhava no adapter como `state=error`. Assimetria pre-existente, encontrada na fase semantica da propria pre-push desta frente e fechada aqui a pedido do usuario: gap pre-existente nao deixa de ser gap.

5. **Paridade documental e higiene:** faixa `1..3600` de `-TimeoutSec` e validacao fail-closed de `RoundId` descritas no dono normativo (`xpz-llm-delegate/SKILL.md`), e o gate de `RoundId` tambem registrado no ponteiro do dispatcher no `09` — a linha ja citava o caminho `%TEMP%\xpz-llm-panel-codex\<RoundId>` sem citar a validacao que o protege; normalizacao de um `} else {` deformado no dispatcher.

### Como isso foi encontrado

Os itens 4 e 5 nao vieram da frente original: sairam de revisao externa sobre os commits de 04/09, e a triagem humana confirmou dois gaps reais. A correcao recomendada pelo revisor para o item 4 (abrir excecao para `cursor/grok-*` dentro do `Test-CursorPrefix`) foi **recusada** na triagem por trocar o gap de lado — liberaria a chave tambem para titular CLI e para elo de cadeia, ambos indespachaveis. O eixo correto e nativo vs CLI, nao qual modelo.

### Testes

- `Test-LlmDelegatePreferredReviewersSelfTest.ps1`: bloco (K2) no escritor — nativo `cursor/grok-4` e `cursor-composer-2-medium` aceitos; nativo sem Criador conhecido, alvo CLI nas duas grafias e elo de fallback bloqueados. Bloco (K3) no leitor — arquivo schema 3 escrito a mao com chave de harness Cursor sob backend CLI ou como elo e recusado na leitura; nativo `cursor/grok-4` resolve com `family=xai`.
- `Test-LlmDelegatePanelDiversitySelfTest.ps1`: casos 25 a 27 — `cursor-grok-*` resolve `xai` e abre piso contra `openai`; as duas grafias do Grok contam como um unico criador; `cursor/<modelo>` sem mapeamento continua desconhecido. Casos 28 e 29 — Composer resolve `anysphere` e abre piso contra `openai`; Composer + Grok formam `panelReady` com duas familias.
- `Test-ResolveOrchestratorNativeModelLocalitySelfTest.ps1`: casos 8 e 9 nas duas grafias do Composer; o caso 3 passou a usar `cursor/modelo-sem-mapeamento` para preservar a cobertura do ramo desconhecido.

### Rastreabilidade

- Commits materiais: `ec7c5d3` (`fix(llm-delegate): estabilizar painel Cursor para Codex/OpenCode em revisao longa`), `49dca32` (`feat(llm-delegate): reconhecer familia xai para Grok nativo no Cursor`), `8369ba7` (`docs(llm-delegate): documentar mapeamento cursor-grok -> xai no 15 e SKILL`), `c1ec5e0` (`test(llm-delegate): reforcar diversidade do Cursor/Grok`), `f123f84` (`feat(llm-delegate): Criador anysphere e contrato de chave de harness Cursor`, correcao dos gaps apontados em revisao externa) e `f644c41` (`fix(llm-delegate): aplicar contrato de chave de harness Cursor tambem na leitura`, predicado compartilhado + paridade escritor/leitor).
- Arquivos materiais: `scripts/LlmDelegateTargetFamilySupport.ps1`, `scripts/Set-LlmDelegatePreferredReviewers.ps1`, `scripts/Resolve-OrchestratorNativeModelLocality.ps1`, `scripts/Invoke-Codex.ps1`, `scripts/Invoke-OpenCode.ps1`, `scripts/Invoke-LlmDelegatePanelDispatch.ps1`, os tres self-tests acima, `scripts/Test-CodexDurableCaptureSelfTest.ps1`, `scripts/Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1`, `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md`.

## Titular de subagente nativo pertence ao orquestrador, nao a maquina

Implementado em 2026-09-04, no fechamento da mesma frente. Achado da fase semantica da pre-push, nao previsto no `999`.

### O defeito

A curadoria de revisores preferidos aceita dois escopos: `preferred-reviewers.json` (machine) e `preferred-reviewers.<orquestrador>.json`. Nada — nem doc nem motor — impedia gravar um titular `orchestrator-native-subagent` no escopo machine. Mas `harnessModelId` e, por definicao, um id DENTRO de um harness: o nativo do Cursor e o Grok, o do Claude Code e o Claude.

Verificacao empirica que fechou o diagnostico: com um `preferred-reviewers.json` machine contendo titular nativo `cursor/grok-4` + `harnessModelId: grok-4`, o comando

    Resolve-LlmDelegatePreferredReviewers.ps1 -Orchestrator claude-code -PreferredRoot <dir>

devolvia `exit 0` e entregava esse titular ao Claude Code como se fosse o nativo dele. O unico sinal era `availableInManifest=false`, que o proprio envelope rotula como diagnostico e nao bloqueio.

O dano nao e o titular falhar no despacho: e o **piso de diversidade** contar a familia (`xai`, no caso) de um revisor que nunca sera consultado naquele harness, permitindo declarar `panelReady` sobre uma voz fantasma.

### O que foi feito

1. **Escritor:** `Set-LlmDelegatePreferredReviewers.ps1` recusa titular nativo com `-Scope machine` (`native-machine-scope-forbidden`, exit 3). Nativo vai em `-Scope orchestrator`, na sessao da ferramenta que o oferece.
2. **Leitor:** `Resolve-LlmDelegatePreferredReviewers.ps1` nao bloqueia arquivos machine gravados antes do gate — eles ja existem e nao ha como reescreve-los retroativamente —, mas marca o titular nativo com `diagnostics` de escopo, para o orquestrador confirmar antes de compor o painel.
3. **Documentacao:** paragrafo novo «Curadoria de nativo e por orquestrador, nunca machine» no `15-revisao-por-pares.md`; regra nos ponteiros do `09` e nas descricoes do `xpz-llm-delegate/SKILL.md`; e ajuste na oferta de 1o uso da `xpz-skills-setup/SKILL.md`, que documenta gravar machine-scope por padrao — agora diz explicitamente que titular nativo nao cabe ali.

### Atribuicao honesta

O defeito e **pre-existente** e vale para qualquer nativo, nao so os do Cursor: um `moonshot/kimi-k3-max` nativo gravado em machine e resolvido pelo Codex tem exatamente o mesmo problema. O que mudou nesta frente foi a **visibilidade**: ate entao uma chave `cursor/*` sequer podia ser persistida, e ela e o caso onde o erro e inequivoco, porque `cursor/grok-4` so existe no Cursor.

O achado veio de um aviso consultivo (`SHARED_SCRIPT_SKILL_DOC_NOT_IN_DIFF` sobre `xpz-skills-setup/SKILL.md`) que dois revisores — este agente e um agente externo — haviam classificado, corretamente, como descartavel quanto ao contrato do `Set-`. O gap real nao estava no contrato, e sim na interacao entre aquele arquivo (que documenta o default machine-scope) e titulares nativos. Licao de metodo: descartar um aviso pelo motivo certo nao dispensa olhar o que ele tangencia.

### Testes

- `Test-LlmDelegatePreferredReviewersSelfTest.ps1`, bloco (K4): gravacao de nativo em `-Scope machine` bloqueada; leitura de arquivo machine legado nao bloqueia e traz o diagnostico; o mesmo titular em escopo orquestrador nao traz o diagnostico. Os blocos nativos pre-existentes (K) e (K2) passaram a gravar em `-Scope orchestrator`, coerentes com o novo contrato.

### Rastreabilidade

- Commit material: `5e11685` (`fix(llm-delegate): titular nativo exige escopo de orquestrador`)
- Arquivos materiais: `scripts/Set-LlmDelegatePreferredReviewers.ps1`, `scripts/Resolve-LlmDelegatePreferredReviewers.ps1`, `scripts/Test-LlmDelegatePreferredReviewersSelfTest.ps1`, `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md`, `xpz-skills-setup/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md`.

## Harness x orquestrador na curadoria e honestidade do recoveredAfterTimeout em kb-sensitive

Implementado em 2026-09-04, fechando cinco apontamentos de uma segunda revisao externa sobre os commits do dia.

### 1. Voz fantasma pelo eixo do orquestrador (gap comportamental)

O gate `native-machine-scope-forbidden` da rodada anterior fechou o eixo machine, mas nao o eixo do orquestrador. Verificado empiricamente: `Set- -Orchestrator claude-code -Scope orchestrator` com titular nativo `cursor/grok-4` gravava `preferred-reviewers.claude-code.json` com `written:1`, sem reclamar — a mesma voz fantasma por outra porta, e a chave ainda somaria `xai` no piso de diversidade.

Correcao: novo predicado `Get-LlmDelegateKeyHarness` na biblioteca compartilhada e gate `native-harness-orchestrator-mismatch` (exit 3) no `Set-`; o `Resolve-` diagnostica o mesmo caso em arquivos anteriores ao gate, sem bloquear.

**Limite declarado:** o casamento so e verificavel quando a propria chave carrega o harness (`cursor/*`, `cursor-*`). Chave neutra como `moonshot/kimi-k3-max` nao diz de qual harness veio e continua aceita em qualquer orquestrador. Isso esta escrito no `15` como limite, nao deixado implicito.

### 2. `recoveredAfterTimeout` silenciosamente falso em kb-sensitive (gap comportamental)

Em `kb-sensitive`, o `Invoke-Codex.ps1` apaga `lastmsg` e `request.json` no caminho de **sucesso** — e recuperacao pos-timeout e sucesso. O dispatcher pareia por esses ficheiros, entao o campo saia `false` mesmo quando houve recuperacao.

A sugestao do revisor era aproveitar a sentinela `XPZ_CODEX_RECOVERED_AFTER_TIMEOUT=1`. **Ela nao e aplicavel:** a sentinela e escrita com `[Console]::Error.WriteLine`, ou seja, no stderr do PROCESSO — nao passa pelo fluxo de erro do PowerShell e o dispatcher so a veria se o adapter lancasse (no ramo de sucesso, nao lanca). Capturar exigiria `2>&1`, que misturaria a sentinela ao parecer, ou reter um recibo em `kb-sensitive`, o que contraria a promessa do modo (o modo apaga tudo).

Correcao adotada: em `kb-sensitive` o campo fica `null` (desconhecido) em vez de `false`. `null` ja e o valor para "nao aplicavel" nos demais backends, e deixa de afirmar uma negativa que o dispatcher nao tem como saber.

### 3, 4 e 5. Rastreabilidade e residuais

- `f644c41` acrescentado a rastreabilidade da secao anterior, e a subsecao de testes dela passou a citar tambem os casos 25 a 27 da diversidade.
- `999`: a linha «`Kill()` simples permanece no Invoke» estava invertida — o `Invoke-Codex.ps1` usa `Kill($true)` com fallback desde 2026-09-04; marcada como resolvida. **Nao** havia no arquivo o texto «timeout com bytes no lastmsg continua timeout» que a revisao externa atribuiu a linha 840; essa metade do apontamento era falsa e foi descartada.
- `999`: residual novo para a retencao do diretorio `%TEMP%\xpz-llm-panel-codex\<RoundId>` — nada limpa rodadas anteriores e o `KeepDays` do adapter e inerte ali, porque o TempDir muda a cada rodada. Retencao hoje e diagnostica e manual; ponteiro tambem no `SKILL`.

### Testes

- `Test-LlmDelegatePreferredReviewersSelfTest.ps1`, bloco (K5): nativo `cursor/grok-4` sob `-Orchestrator claude-code` recusado; chave neutra aceita em outro orquestrador (limite declarado); arquivo legado com harness divergente lido sem bloqueio e com diagnostico.
- `Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1`: guarda textual de que o ramo de projecao exclui `kb-sensitive`.

### Rastreabilidade

- Commit material: `63b34f8` (`fix(llm-delegate): fechar harness x orquestrador e nao afirmar recuperacao desconhecida`)
- Arquivos materiais: `scripts/LlmDelegateTargetFamilySupport.ps1`, `scripts/Set-LlmDelegatePreferredReviewers.ps1`, `scripts/Resolve-LlmDelegatePreferredReviewers.ps1`, `scripts/Invoke-LlmDelegatePanelDispatch.ps1`, `scripts/Test-LlmDelegatePreferredReviewersSelfTest.ps1`, `scripts/Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1`, `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `999-ideias-pendentes.md`, `CHANGELOG.md`.

## Primeira aplicacao da regra de eixos vizinhos na pre-push

Implementado em 2026-09-04, logo apos registrar a regra no `13-revisao-pre-push.md` (§5) e no `08-guia-para-agente-gpt.md`.

### Por que a regra existe

Tres rodadas seguidas da frente do dia fecharam um eixo cada e deixaram o vizinho aberto — escritor sem leitor; `-Scope machine` sem o eixo do orquestrador; `public` sem `kb-sensitive`. Nas tres, a pre-push mecanica passou e a fase semantica foi executada. A falha nao era de execucao: a fase semantica pergunta se o termo propagou e se a enumeracao recebeu o membro novo, e nenhuma dessas perguntas alcanca «este gate fecha um caminho; por quais outros o mesmo defeito ainda chega?».

### O que a primeira execucao achou

Ao enumerar os eixos do `ValidateRange(1, 3600)` que a frente adicionou em `Invoke-Codex.ps1` e `Invoke-OpenCode.ps1`, apareceram tres adapters irmaos sem faixa nenhuma: `Invoke-ClaudeCode.ps1`, `Invoke-Copilot.ps1` e `Invoke-Gemini.ps1`. Os tres chamam `WaitForExit($TimeoutSec * 1000)`; sem faixa, `-TimeoutSec -1` vira `WaitForExit(-1)`, que em .NET e **espera infinita** — um revisor do painel travaria sem timeout —, e `0` da timeout imediato. Corrigido nos tres, com as assinaturas atualizadas no `SKILL`.

Tambem foi corrigida uma afirmacao fechada demais no proprio item novo do `999` («por que os gates atuais nao pegam» -> «por que os gates de propagacao e enumeracao nao pegam»), sinalizada pelo `Test-PrePushGateEnumerationParity.ps1`.

### Um falso gap evitado, que vale registrar

A varredura de eixos do gate de `RoundId` sugeriu que o motor irmao `New-LlmDelegatePeerReviewArtifacts.ps1` nao bloqueava traversal: `grep "RoundId inseguro"` nao casa nesse arquivo, e a validacao dele (`-match '[^A-Za-z0-9._-]'`) parece deixar `..` passar, ja que o ponto esta no conjunto permitido. Antes de reportar, foi feito o teste: `-RoundId '..'` devolve `BLOCK: roundId-path-traversal` com `failureCode` proprio. O motor bloqueia, so com mensagem diferente. Registrar aqui porque o erro evitado — concluir ausencia a partir de `grep` que nao casou a redacao — e exatamente o que a propria sessao tinha acabado de apontar num parecer externo.

### Rastreabilidade

- Commit material: `27529bb` (`fix(llm-delegate): faixa 1..3600 de -TimeoutSec nos tres adapters restantes`); regra registrada em `dc85f04` (`docs(pre-push): exigir enumeracao dos eixos vizinhos ao introduzir gate`)
- Arquivos materiais: `scripts/Invoke-ClaudeCode.ps1`, `scripts/Invoke-Copilot.ps1`, `scripts/Invoke-Gemini.ps1`, `xpz-llm-delegate/SKILL.md`, `999-ideias-pendentes.md`, `CHANGELOG.md`.

## Subdiretorio por revisor na captura Codex do painel

Implementado em 2026-09-05, a partir de apontamento externo do Codex GPT.

### O defeito

O `TempDir` Bound do Codex era `%TEMP%\xpz-llm-panel-codex\<RoundId>` — um diretorio para a rodada inteira, compartilhado por todos os titulares `codex` dela. O pareamento de `recoveredAfterTimeout` percorre os `*.lastmsg.txt` do diretorio, casa por igualdade de texto com o parecer devolvido e usa a **primeira** coincidencia, sem identidade de job. Dois titulares `codex` que devolvessem o mesmo texto na mesma rodada — plausivel em parecer curto como «sem gaps» — podiam ter a recuperacao atribuida ao revisor errado.

### A correcao

Subdiretorio por revisor: `<RoundId>\<NN>`. A colisao deixa de existir na origem, em vez de ser desempatada por heuristica (a alternativa considerada era marcar `null` quando houvesse mais de uma coincidencia, o que degradaria o campo em vez de corrigi-lo).

Eixos vizinhos varridos conforme a regra do `13` §5: o fallback recursivo usa outro `RoundId`, entao ja tinha diretorio proprio e agora tambem ganha o subnivel; `kb-sensitive` continua com o campo `null` porque o adapter apaga a evidencia no sucesso; a acumulacao de diretorios orfaos entre rodadas permanece como residual ja registrado no `999`, agora um nivel mais fundo.

### Sobre os outros apontamentos da mesma leva

Um segundo revisor (opencode/Nemotron) apontou seis itens; quatro ele mesmo classificou como coerentes. Dos dois restantes:

- «Os tres adapters novos desta frente (`Invoke-Gemini`, `Invoke-Copilot`, `Invoke-Antigravity`) nao tem entrada no `09`» — **falso em dois pontos**, verificado: os tres tem entrada no `09` (linhas 176, 179 e 182), e nao sao desta frente: Copilot e Gemini existem desde 2026-06-13 (`17e0ab1`), Antigravity desde 2026-08-04 (`2e80a70`). O unico toque neles no intervalo foi o `27529bb`, que so acrescentou a faixa de `-TimeoutSec`.
- Auditoria do agente `reviewer-ro` pelo motor da `xpz-skills-setup` — limitacao **ja declarada** na propria skill e com entrada no `999`; nao e gap desta frente, e priorizar essa frente e decisao humana.
- Verificacao trilingue do `CHANGELOG` — conferida por contagem: cada entrada da frente aparece nas tres secoes.

### Rastreabilidade

- Commit material: `e32de6f` (`fix(llm-delegate): subdiretorio por revisor na captura Codex do painel`)
- Arquivos materiais: `scripts/Invoke-LlmDelegatePanelDispatch.ps1`, `scripts/Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1`, `xpz-llm-delegate/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `999-ideias-pendentes.md`, `CHANGELOG.md`.

## Varredura da suite inteira de self-tests apos a frente do painel

Executada em 2026-09-05, ao fim da frente. Motivo: ao longo de 16 commits foram tocados motores compartilhados (biblioteca de familia, dispatcher, tres adapters, escritor e leitor da curadoria), e ate entao so tinham sido rodados os self-tests julgados afetados. Julgar quem e afetado e a suposicao que falhou tres vezes nesta mesma frente; a varredura troca o julgamento por medicao.

### Resultado

130 self-tests, um processo por teste, teto de 300s cada: **128 PASS, 2 FAIL, 0 TIMEOUT**. As duas falhas sao **pre-existentes** — `git log origin/main..HEAD` sobre os arquivos envolvidos volta vazio nos dois casos.

### Falha 1 — falso positivo do guard de fonte unica (CORRIGIDA)

`Test-GeneXusKbHostingKindSupportDriftSelfTest.ps1` acusava `Test-GeneXusRuntimeFreshness.ps1` de redigitar o literal `skipped-hosting-unsupported` fora do registro. A ocorrencia estava num **comentario de comment-based help** descrevendo o comportamento, nao em codigo emissor — o guard varre o arquivo inteiro com `ReadAllText` + regex e nao distingue prosa de codigo.

Corrigido pelo lado da prosa: o texto passa a apontar o registro (`Get-GeneXusKbHostingKindSupportRecord`) em vez de repetir o literal. A alternativa — ensinar o guard a ignorar comentarios — foi descartada: um literal em comentario tambem enverelhece e engana quem le, e afrouxar o guard custa mais do que reescrever uma frase. Self-test volta a `GENEXUS_HOSTING_KIND_DRIFT_SELFTEST_OK`.

### Falha 2 — self-test do daemon PreToolUse (REGISTRADA, nao corrigida)

`Test-ClaudeCodePreToolUseSafeAllowDaemonSelfTest.ps1` falha com 2 asseracoes no cenario `F-stale-classify`. E frente propria (produto PreToolUse, Fases 3-5), depende de daemon/pipe/mutex e respawn, e nao foi tocada por esta frente. Registrada na entrada existente do `999` com o diagnostico do que se sabe e do que nao se sabe, e com a consequencia operacional: **precisa fechar antes da Fase 4**, porque ligar `enforce` com o self-test adversarial vermelho seria ligar efeito real sem a rede de protecao que o justifica.

### Rastreabilidade

- Commit material: `30f47f6` (`fix(selftests): fechar falso positivo do guard de fonte unica e registrar daemon vermelho`)
- Arquivos materiais: `scripts/Test-GeneXusRuntimeFreshness.ps1`, `scripts/Invoke-LlmDelegatePanelDispatch.ps1` (comentario do gate de RoundId), `999-ideias-pendentes.md`.
