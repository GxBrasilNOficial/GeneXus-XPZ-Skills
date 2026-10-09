# Ideias Implementadas — 2026-10

Registro de ideias que saíram de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodológico vigente.

## `xpz-skills-setup` oferecer instalar o agente `reviewer-ro` do OpenCode (resolução ativa do gap)

Entrada original no 999 (Importância média; Maturidade ideia), implementada em 2026-10-09.

**Origem (preservada do 999).** Decisão do usuário em 2026-07-04 (opção B): a `xpz-skills-setup` é a dona operacional da instalação **global** do `reviewer-ro`, não só quem a cita. Até esta frente, a skill só apontava o instalador `scripts/Install-OpenCodeReviewerRoAgent.ps1` (dono `xpz-llm-delegate`) e um anti-padrão **proibia** auditar, reportar status ou rodar o diagnóstico/instalador enquanto não houvesse motor. O `reviewer-ro` só estava garantido **project-local** na raiz do repositório; de outras pastas, o guard caía em fail-closed `static` até o `opencode.jsonc` global ser migrado.

**Evidência real (preservada do 999).** O commit `8f61c28` (2026-10-08) endureceu o contrato (`read` por mapa com proteção `.env`, `grep: deny`), mas o `agent.reviewer-ro` do `~/.config/opencode/opencode.jsonc` desta máquina continuou na forma anterior (`read: "allow"`, `grep: "allow"`). Em 2026-10-09, um painel de revisão por pares disparado de `C:\Dev\Prod\MCP_FabricaBrasil18` perdeu os 3 revisores opencode por `BLOCK ... motivo=static` antes de chegar ao modelo e caiu para `insufficientDiversity`. O guard fail-closed funcionou, mas a deriva só apareceu no despacho.

**Armadilhas encontradas na avaliação do plano.** (1) O diagnóstico usava a pasta atual: da raiz deste repositório, tanto a checagem estática quanto o `opencode agent list` (que roda na pasta do processo) mediam o project-local, já canônico, e a defasagem global não aparecia. (2) A checagem estática do bloco do `.jsonc` pode dar OK falso; só o `agent list` mostra a configuração efetiva. (3) Arquivo com comentário contendo chaves é lido pelo guard (que descarta comentários) e recusado pelo instalador; sem rótulo próprio, a auditoria ofereceria uma correção que falharia. (4) A pasta "neutra" precisa ser comprovada: a busca do project-local sobe pelas pastas acima, e um `%TEMP%` fica dentro do perfil do usuário.

**Recorte implementado.**

1. **Guard e diagnóstico (dono `xpz-llm-delegate`, commit `bf98785`).** `Test-OpenCodeReviewerRoStatic -GlobalOnly` lê só o bloco global; o `agent list` aceita pasta opcional, com a pasta original restaurada em `try/finally` (os adapters seguem sem o parâmetro); a pré-checagem de ambiguidade do instalador foi levada ao guard como `Test-OpenCodeReviewerRoJsoncEditable`, sem mudança de comportamento, para auditoria e instalador nunca divergirem. `Test-OpenCodeReviewerRoInstalledCompatibility.ps1` ganha `-WorkingDirectory` (estático e `agent list`) e `-ExpectGlobal`, que recusa com `status=invalidVantage` (exit `21`, sem rodar o `agent list`) pasta dentro de repositório git ou com project-local acima, e expõe `sourceKind`/`vantage`.
2. **Motor e skill (dono `xpz-skills-setup`, commit `8b6c0a0`).** `Test-XpzSkillsRegistration.ps1` ganha a seção `opencodeReviewerRo`, só leitura e só estática (sem CLI, sem imprimir o arquivo): `REVIEWER_RO_NOT_APPLICABLE`, `REVIEWER_RO_OK`, `REVIEWER_RO_MISSING` (sem gap; oferta), `REVIEWER_RO_STALE` e `REVIEWER_RO_NOT_AUTOFIXABLE` (marcam `REGISTRATION_GAPS`). O `SKILL.md` troca o anti-padrão pelo contrato novo, com gate de ativação que exige o diagnóstico `-ExpectGlobal` numa pasta neutra (o self-test com executável simulado deixa de contar como prova), e ganha o passo 10 do `WORKFLOW`: efeito, `-WhatIf`, confirmação explícita, backup, confirmação na pasta neutra e idempotência. Separação dos revisores preferidos mantida.
3. **Mensagem de divergência (fechamento).** As divergências de ação passam a dizer o valor encontrado e o esperado (ex.: `permission grep: acao divergente (encontrado 'allow', esperado 'deny')`); valor fora de `allow`/`deny`/`ask` não é ecoado. Motivo: no teste de aceitação, o agente só conseguiu dizer que o `grep` tinha «valor diferente do esperado».
4. **Raiz que não é objeto (achado da pré-push).** `ConvertFrom-Jsonc` passa a exigir raiz objeto. O `ConvertFrom-Json` desembrulha listas, e `$obj.agent` achava o `agent` dentro de `[{...}]`: medido em JSONC sintético, o instalador gravou `[{ "agent": { "reviewer-ro": ... } }]` com backup e «OK», e a checagem estática aprovou; com `[]`/escalar a auditoria oferecia instalação que o instalador recusava; com `null` a auditoria inteira caía. Por ser o ponto único de leitura, a correção alinha editabilidade, instalador, checagem estática e adapters: lista, escalar e `null` dão `REVIEWER_RO_NOT_AUTOFIXABLE`, recusa sem escrita nem backup, static não OK. Self-tests: 7 raízes em `Test-OpenCodeReviewerRoSelfTest.ps1` (h2) e 4 em `Test-XpzSkillsRegistrationSelfTest.ps1` (52/52), que falham com o guard anterior.

**Provas.** `Test-OpenCodeReviewerRoSelfTest.ps1` seção (h) e casos de mensagem na multi-divergência (seção (g) intacta); `Test-XpzSkillsRegistrationSelfTest.ps1` com `opencode.jsonc` sintético em perfil falso (não aplicável, ausente, defasado, forma `tools:`, canônico, comentário com chaves defasado e canônico, homônimo, JSONC inválido e sentinela de chave de provedor que não pode aparecer na saída), 44/44. **Teste de aceitação real**, conduzido por uma sessão nova que só recebeu `/xpz-skills-setup auditoria completa`, sem dicas: detectou `REVIEWER_RO_STALE` com as duas divergências, mediu numa pasta vazia fora de repositório (`blocked`), rodou `-WhatIf`, explicou o efeito, instalou só após aprovação humana e informou o backup `opencode.jsonc.rro-backup-20261009-131554-870864b9`; depois, `REGISTRATION_OK`/`REVIEWER_RO_OK`, diagnóstico `compatible` na pasta neutra e instalador «já canônico». Verificação independente nesta frente, sem mostrar o conteúdo: fora do bloco, o arquivo é idêntico ao backup (151 e 1.730 caracteres), sem BOM, só LF, sem quebra final, como o original; um único backup; de `C:\Dev\Prod\MCP_FabricaBrasil18`, sem flag (visão dos adapters) `compatible` com fonte global, allow-set `{glob,list,read}`, `external_directory` negado e versão 1.18.33 = testada; com `-ExpectGlobal`, `invalidVantage` por ser repositório git. Isso prova o perfil válido; não prova acesso aos modelos nem que um parecer vai chegar. Nenhum LLM, painel ou `opencode run` foi disparado.

### Residuais

Outras camadas de configuração do opencode (`opencode.json` ao lado do `.jsonc`, `OPENCODE_CONFIG`, agentes em markdown no diretório global) não são lidas pelo motor estático; ele informa `opencodeJsonPresent` e o passo 10 delega a palavra final ao diagnóstico na pasta neutra. O passo 10 só roda quando alguém executa a auditoria de setup; outra máquina que puxar um contrato novo sem rodar a `xpz-skills-setup` continua sendo avisada só no despacho, pelo guard fail-closed.

### Rastreabilidade

- Commit material: `bf98785` (Mede o reviewer-ro global a partir de pasta neutra).
- Commit material: `8b6c0a0` (Faz a xpz-skills-setup auditar e oferecer reinstalar o reviewer-ro global).
- Commit material: `0680fe3` (Recusa opencode.jsonc com raiz que não é objeto no reviewer-ro).

## Instalador e diagnóstico do `reviewer-ro` — backup, idempotência e deriva pós-contrato

Entrada original no 999 (Importância média; Maturidade pronta para implementar), implementada em 2026-10-09.

**Origem e evidência (preservada do 999).** O commit `8f61c28` (2026-10-08) endureceu o contrato do `reviewer-ro` (`read` por mapa com proteção `.env`, `grep: deny`), mas o `agent.reviewer-ro` do `~/.config/opencode/opencode.jsonc` desta máquina ficou na forma anterior (`read: "allow"`, `grep: "allow"`). Em 2026-10-09, um painel de revisão por pares disparado de `C:\Dev\Prod\MCP_FabricaBrasil18` perdeu os 3 revisores opencode por `BLOCK ... motivo=static`, antes de chegar ao modelo. O diagnóstico `Test-OpenCodeReviewerRoInstalledCompatibility.ps1` reportou só `mapa read: chaves/ordem divergentes`; a divergência de `grep` não apareceu porque `Test-OpenCodeReviewerRoDefinition` retornava na primeira diferença.

**Recorte implementado (itens 1–5 do 999).**

1. **Backup no instalador** — antes de gravar sobre arquivo existente, `Install-OpenCodeReviewerRoAgent.ps1` copia o `opencode.jsonc` na mesma pasta como `<arquivo>.rro-backup-<yyyyMMdd-HHmmss>-<guid8>` (`File.Copy` sem sobrescrever; padrão de `Install-ClaudeCodePreToolUseSafeAllow.ps1`) e imprime só o caminho. O sufixo não termina em `.json`/`.jsonc`. Arquivo novo não gera backup.
2. **Idempotência** — texto resultante idêntico ao atual (comparação ordinal após leitura UTF-8) não é regravado nem gera backup; o instalador reporta «já canônico». `-WhatIf` não grava nem faz backup.
3. **`nextAction` acionável** — com bloqueio `static` vindo do `opencode.jsonc` global, o diagnóstico aponta o comando do instalador (com `-WhatIf` antes); vindo de um project-local, aponta a correção do markdown, porque o instalador global não o substitui.
4. **Todas as divergências** — `Test-OpenCodeReviewerRoDefinition` acumula `mode`, chaves/ordem (com ausentes/extras), mapa escalar no lugar de mapa e ação por chave e por padrão; devolve `divergences` e `detail` unido por `; `. `ok` continua `$false` com qualquer divergência. `Test-OpenCodeReviewerRoStatic` repassa a lista. Os consumidores de `.detail` (adapters, instalador, pré-check) só o interpolam em mensagem, sem casar texto.
5. **Aviso de deriva pós-contrato** — gate consultivo novo `scripts/Test-PrePushOpenCodeReviewerRoDrift.ps1`, chamado pelo orquestrador: quando o intervalo `BaseRef..HEAD` altera `.opencode/agent/reviewer-ro.md`, emite `OPENCODE_REVIEWER_RO_CONTRACT_CHANGED` em `agentWarnings` (severity `warn`, não falha o mecânico). Não lê a configuração da máquina. O 999 previa caso «no self-test do orquestrador», que não existe; por decisão do usuário (opção a), o aviso virou gate com self-test próprio, no padrão dos demais `Test-PrePush*`.

**Provas.** `Test-OpenCodeReviewerRoSelfTest.ps1` ganhou na seção (g): backup único na mesma pasta, byte a byte idêntico ao original e informado no stdout; segunda execução «já canônico» sem regravar nem criar backup; `-WhatIf` sem gravação nem backup; arquivo novo sem backup; e o caso de múltiplas divergências (forma anterior com `read` escalar + `grep: allow` → 2 divergências; com `mode` divergente → 3; controle canônico → 0; `static` global repassa a lista). `Test-PrePushOpenCodeReviewerRoDriftSelfTest.ps1` cobre intervalo com e sem o contrato, outro agente na mesma pasta, `-ChangedFiles` com barra invertida e caixa diferente. Nenhum LLM, painel ou `opencode run` foi disparado. Dono normativo: `xpz-llm-delegate/SKILL.md` (instalador e diagnóstico) e `13-revisao-pre-push.md` (gate); ponteiros no `09`, resumo no `08`, `CHANGELOG` trilíngue.

### Residuais

Quando esta frente foi registrada, a fiação do instalador na `xpz-skills-setup` (detectar a deriva na auditoria pós-`git pull` e oferecer a reinstalação com confirmação) ficou aberta numa entrada própria do 999. Ela foi concluída no mesmo dia, em `8b6c0a0` e `775b6a1`; ver [`xpz-skills-setup` oferecer instalar o agente `reviewer-ro` do OpenCode](#xpz-skills-setup-oferecer-instalar-o-agente-reviewer-ro-do-opencode-resolução-ativa-do-gap). O gate pré-push só lembra quem faz o push; outra máquina que puxar o contrato novo é avisada pela auditoria da `xpz-skills-setup`, se alguém a rodar, ou, sem ela, só no despacho pelo guard fail-closed.

### Rastreabilidade

- Commit material: `bfd2d93` (Torna o instalador do reviewer-ro idempotente e com backup).

## lastUpdate em edições sucessivas — recorte v5

Implementação validada em 2026-10-09 com fixtures sintéticas dos consumidores reais. Editor cirúrgico e setter recebem `-NewObjectNotImported` para novo nunca importado, sem acumular baseline; conflitos de contexto retornam 30 e baseline explícito com recarimbo exige mesma raiz Object/Attribute e GUID válido não zero igual (31). Lote recebe `-NewObjectsNotImported` apenas para `objectState=new`, após validar valores presentes, com rastro aditivo no relatório/journal e fonte `new-not-imported`, sem mudar manifesto.

Defaults, existing, Preserve fora do modo novo, gerador/formato `.0000000Z` e tolerâncias permanecem. Recarimbo final de preparação acumulada usa referência oficial atual do mesmo objeto para existente, ou modo explícito para novo nunca importado; renovar a referência após importação. Documentado também o consumo de JSON sem coerção de datas. Dono normativo: `xpz-builder/SKILL.md`, seção de recarimbo final; regras em 02/08, checklist e exemplo cirúrgico, ponteiros no 09, notas aditivas nos desenhos congelados e README/CHANGELOG trilíngues.

Provas: 372 verificações integradas em `scripts/Test-GeneXusLastUpdateConsumerContract.ps1`, além das baterias pertinentes de editor, setter, baseline opcional, lote, envelope e botão. `SkipGate` na prova isola a validação temporal, sem ser contorno operacional. Não houve IDE/import/build/runtime reais; o envelope decide pelo acervo fornecido, não pela KB viva, e não valida temporalmente Attribute de topo. Não houve molde derivado de KB real ou necessidade de atualização do PrivateMap.

### Residuais

A [entrada original no 999](../999-ideias-pendentes.md#xpz-relato-20261005-datas) permanece com os residuais. `Add-GeneXusButton.ps1` continua acumulativo e sem comparar a identidade do baseline explícito com o objeto editado; recarimbo final não substitui essa validação. Alteração de GUID pelo patch, aviso temporal novo de existing, alerta lastUpdateRegressed e refatoração dot-sourceável seguem fora do recorte implementado. O relato de formato não identifica consumidor externo específico nem comprova defeito na emissão do gerador.

### Rastreabilidade

- Commit material: `c73b1a8` (Corrige lastUpdate em edições sucessivas de objetos nunca importados).

## Proteção mínima de conteúdo .env no reviewer-ro

Implementação local validada em 2026-10-08; publicação Git depende de autorização própria.
Recorte aprovado: read com mapa ordenado * allow / *.env deny / *.env.* deny /
.env.example allow / */.env.example allow; grep deny integral.
Catch-all * deny, mode all e contenção de execução/escrita/rede preservados.

Guard e instalador usam validação canônica comum; mapas/ordem preservados;
definição local inválida não cai no global. Parser restrito, duplicatas/ações/indentação/
profundidade inválidas e reaberturas tardias bloqueiam. JSONC ambíguo é recusado antes da escrita.
Nenhuma configuração global foi instalada nem alterada.

Provas: self-test com fake-exe (adapters default/explícito sync/async e instalador);
33 sondas debug agent em Markdown/JSONC, incluindo cwd em subpasta Git; captura real
run com commandcode/deepseek/deepseek-v4.1-flash: quatro read, dois erros de permissão,
fonte/exemplo legíveis, token protegido ausente. Fixtures completos recapturados
na política final e VERSION promovido para 1.18.33; diagnóstico instalado compatible.
Go respondeu usage limit; openai estava indisponível; essas tentativas não contam como prova.
Design congelado anterior preservado. Não houve nova convergência de plano nesta sessão.

### Diagnóstico anterior preservado

As linhas abaixo registram o estado anterior, substituído neste recorte pela nova prova:

- **Maturidade** — pronta para implementar para o recorte `.env`; pesquisa/ideia para o restante do eixo de leitura. O bloqueio padrão de leitura fora do cwd **HERDADO** já está **ATIVO** (o reviewer-ro fixa `external_directory: deny`, medido nos fixtures ativos em 1.18.30), sem proteger segredos dentro do próprio cwd; falta **mecanizar cwd-seguro**, **blindar `.env`/segredos locais dentro do cwd** e **liberar `kb-sensitive`**.
- **Urgente — `.env` dentro do cwd:** a captura ativa **1.18.30** (e a medição anterior em 1.17.20) mostra que o OpenCode traz regras nativas `read "*.env" -> ask` e `read "*.env.*" -> ask`; o bloco posterior do `reviewer-ro` adiciona `read "*" -> allow`. **Confirmado por medição em 2026-08-16 — não é mais hipótese:** resolvendo o bloco do `reviewer-ro` com `Resolve-OpenCodeReviewerRoAllowSet`, a **última** regra que casa um caminho `.env` é `read "*" -> allow` (posição **[51]** de 62 no opencode **1.17.20**), **depois** de `*.env -> ask` em **[47]** e `*.env.* -> ask` em **[48]**; por `last-match-wins`, a proteção nativa **é anulada**. O mesmo padrão, nas mesmas posições relativas, apareceu no fork `mimo` 0.1.12 (**[103]** e **[99]** de 204) — ou seja, é traço **estrutural herdado do upstream**, não acidente de uma versão; o fork em si foi descartado (`998-ideias-descartadas-e-porque.md`), mas a medição vale como confirmação independente. Arquivos `.env` normalmente guardam segredos locais (`DATABASE_URL`, `API_KEY`, `OPENAI_API_KEY`, `JWT_SECRET`, senhas SMTP etc.) e são justamente o tipo de arquivo que não deve ser lido por um revisor externo. Frente curta a implementar: decidir se o `reviewer-ro` deve preservar/bloquear `*.env`/`*.env.*` (mantendo `.env.example` legível), ajustar frontmatter/guard/fixtures/self-test, documentar a decisão e recapturar evidência. Até lá, tratar revisão opencode em cwd com `.env` como risco alto.

### Residuais

Cwd-seguro, links/aliases, outros formatos de segredo, nomes visíveis, dados no prompt/dossiê,
instruções automáticas, liberação kb-sensitive/pasta paralela e instalação global via
xpz-skills-setup seguem abertos no 999, sem serem requisitos novos desta frente.
A exceção .env.example exige conteúdo sanitizado pelo operador; .env~/.env-example
ficam fora dos padrões e diretório com .env. pode ser negado conservadoramente.

Dono normativo e provas: xpz-llm-delegate/SKILL.md e fixtures/opencode-reviewer-ro/README.md.
O 999 retém a entrada pelo título com os residuais; o recorte concluído está registrado aqui.

### Rastreabilidade

- Commit material: `8f61c28` (Protege conteúdo .env no revisor OpenCode).

## Cobertura da assinatura do extrator no gate de rastreabilidade

### Registro de origem

- **Importância** — baixa (risco de falso-negativo restrito a um gate consultivo, com a revisão semântica como backstop). `scripts/Test-PrePushTraceabilityCoverageSelfTest.ps1` cobria `PUBLIC_TRACEABILITY_VERBOSE_LINE`, mas não os ramos que resolvem a assinatura do extrator e detectam referências documentais antigas. A mudança da constante de `Build-KbIntelligenceIndex.py` para `GeneXusKbIntelligenceExtractorSignature.py` expôs a dependência do consumidor em relação ao local da versão; o caso real foi corrigido, mas ainda não tinha regressão permanente. O ramo sem fonte resolvível emite `EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED` como aviso; faltava fixar esse comportamento em teste.
- **Maturidade** — pronta para implementar. Criar fixtures com repositório Git temporário e fontes sintéticas para cobrir: (1) formato legado, com a versão declarada em `Build-KbIntelligenceIndex.py`; (2) formato atual, com `Build-KbIntelligenceIndex.py` importando `GeneXusKbIntelligenceExtractorSignature.py`, bump da versão e referência anterior em documento, que deve gerar `EXTRACTOR_SIGNATURE_STALE_DOC_REF`; e (3) ausência de versão resolvível no estado atual ou base, que deve gerar `EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED` em vez de passar silenciosamente. Incluir também o acionamento quando apenas o módulo de assinatura estiver entre os arquivos alterados. Preservar o caráter consultivo (`warn`, `exit 0`).
- **Origem** — área não coberta identificada na revisão do commit `e03fa3d` (2026-10-02); relacionada ao item sobre propagação de tokens de self-test, mas com cenário e comportamento distintos.

### Resultado da implementação

Implementado em 2026-10-03. `Test-PrePushTraceabilityCoverage.ps1` agora compara afirmações explícitas de versão corrente com a assinatura atual do extrator e detecta instrução de próximo bump numérico já consumido. A detecção relaciona os termos de atualidade à afirmação sobre o extrator; uma palavra como “atualmente” ligada a outro fato numa referência datada não dispara sozinha. A busca continua limitada a Markdown rastreado ou não ignorado pelo Git, fora de `historico/` e `.git/`.

O self-test cobre a fonte de assinatura no módulo atual, a fonte legada em `Build-KbIntelligenceIndex.py`, o acionamento quando apenas o módulo de assinatura muda, afirmações correntes em português e inglês, próximo bump obsoleto, menções históricas sem afirmação corrente, menção datada de atualidade referente a Domains, exclusão de `Temp/` ignorado e `EXTRACTOR_SIGNATURE_VERSION_UNRESOLVED` quando não há fonte resolvível.

O complemento material de `4693d33` aceita números entre crases ou aspas nas afirmações correntes, reconhece `EXTRACTOR_SIGNATURE_VERSION atual` e a constante com `=` ou `:` nos contextos operacionais documentados, além do contrato `schema_version / extrator` com verbo de indexação. Antes de normalizar os delimitadores, desconsidera o trecho de contrato introduzido por `Registro de AAAA-MM-DD:` e a citação delimitada após “O manual antigo dizia”, com formas correspondentes em espanhol e inglês. Essas exclusões são específicas; não representam interpretação geral de conteúdo histórico. O self-test cobre as seis formas normativas antes não detectadas, versões corretas, os dois falsos avisos históricos reproduzidos e afirmações vigentes incompatíveis antes ou depois desses trechos, inclusive na mesma frase.

### Rastreabilidade

- Commit material: `d4dca9f` (Refina avisos de versão do extrator e amplia testes de rastreabilidade).
- Commit material: `4693d33` (Corrige detecção de versões documentais e citações históricas do extrator).
- Arquivos materiais: `scripts/Test-PrePushTraceabilityCoverage.ps1`, `scripts/Test-PrePushTraceabilityCoverageSelfTest.ps1`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `13-revisao-pre-push.md`, `CHANGELOG.md` e `999-ideias-pendentes.md`.

## Listas de «ação por motivo» do `INVENTORY_CUSTOMIZED` sem os motivos com seção própria

### Registro de origem

- **Importância** — baixa (falso-negativo de leitura, sem dano mecânico: o inventário continuava emitindo o motivo e a ação existia no `SKILL.md`, só não na lista que o agente consulta para montar a tabela de correções).
- **Maturidade** — pronta para implementar.
- **Gap** — em `xpz-kb-parallel-setup/SKILL.md`, as listas «quando o motivo for X, a ação é Y» da tabela de 8.h e da regra «NUNCA ignorar `INVENTORY_CUSTOMIZED`» não citavam `copy_objectlist_type_loss` nem `WRITABILITY_CONSUMER_CONTRACT_STALE`, que tinham apenas seção própria.
- **Origem** — pré-push de 2026-10-04 da frente da cópia tipada acervo → frente. A entrada foi registrada no `999` pelo commit `e4ef1c0` com atribuição incorreta: tratou os dois motivos como padrão pré-existente. A atribuição correta separa os casos: a omissão de `WRITABILITY_CONSUMER_CONTRACT_STALE` era anterior; `copy_objectlist_type_loss` foi introduzido na própria frente (`fa1aa1c`) e, pelo §2 do `13-revisao-pre-push.md` (conjunto enumerado), deveria ter entrado nas listas na mesma frente. Revisão externa apontou as duas falhas.

### Resultado da implementação

Implementado em 2026-10-04, ainda dentro da mesma frente e antes do push, para não gerar uma segunda mudança de assinatura de setup nas pastas paralelas. As duas listas receberam uma ação curta para cada motivo, com ponteiro para a seção própria: realinhar `Copy-*KbAcervoToFront.ps1` ao molde para repassar `ObjectList` intacto e `ParallelKbRoot`, com reauditoria; atualizar `Test-*KbSetupAudit.ps1` para `WRITABILITY_COVERAGE_CONTRACT_V1`. A sugestão de converter as listas em ponteiro único não foi adotada nesta correção; reavaliar se a defasagem se repetir no próximo motivo.

### Rastreabilidade

- Commit material: `d545496` (Inclui motivos com seção própria nas listas de ação do inventário).
- Arquivos materiais: `xpz-kb-parallel-setup/SKILL.md` e `999-ideias-pendentes.md`.

## Avaliar rastreabilidade privada do molde `Copy-KbAcervoToFront.example.ps1`

### Registro de origem

- **Importância** — baixa (pendência de fechamento metodológico, sem efeito no comportamento dos scripts públicos).
- **Maturidade** — ideia (faltava confirmar se o `GeneXus-XPZ-PrivateMap` rastreia moldes de wrapper ou só exemplos sanitizados).
- **Contexto** — na frente de 2026-10-04 o molde `xpz-kb-parallel-setup/examples/Copy-KbAcervoToFront.example.ps1` passou a repassar `ObjectList` intacto e a enviar `ParallelKbRoot=$repoRoot` ao motor. O `xpz-kb-parallel-setup/SKILL.md` (seção «Cópia acervo → frente e detector dirigido») pede avaliar a rastreabilidade privada do molde no fechamento, e o `AGENTS.md` (seção «Rastreabilidade privada de moldes sanitizados») exige essa avaliação. A entrada foi registrada no `999` pelo commit `e4ef1c0`.

### Resultado da avaliação

Avaliação concluída em 2026-10-04 pela documentação pública, sem leitura do repositório privado: não há anotação a registrar no `GeneXus-XPZ-PrivateMap`. O `README.md` define o PrivateMap como rastreabilidade editorial privada entre aliases públicos e artefatos reais, e exige anotação para todo **novo exemplo sanitizado** incorporado à base pública; `09` e `02` descrevem a mesma separação. O diff da frente no molde alterou apenas a lógica de repasse e o texto de ajuda; não incorporou nome de objeto, frente ou pacote real novo — os exemplos de chamada já existentes permaneceram inalterados.

Correção de regra: a entrada original afirmava que até a **leitura** do repositório privado exigia confirmação humana. As regras aplicáveis exigem aviso de troca de contexto (e necessidade concreta) para leitura fora da pasta de trabalho, e confirmação explícita para **edição** (`AGENTS.md` global, «Contexto de repositório»; `AGENTS.md` local, «Rastreabilidade privada de moldes sanitizados»). A exigência adicional não tinha fundamento e não foi mantida. Apontado por revisão externa.

Limite: a conclusão se apoia na finalidade documentada do PrivateMap, não em inspeção do seu conteúdo. Se uma frente futura constatar que ele também acompanha moldes `.example.ps1`, reabrir a avaliação.

### Rastreabilidade

- Avaliação documental, sem commit material de código: `e7b884c` (Conclui avaliação de rastreabilidade privada do molde Copy), que retira a entrada do `999` e cria este registro.
- Arquivos: `999-ideias-pendentes.md` e este histórico.

## Divergência de `observedContext.ActiveEnvironment` após `SetActiveEnvironment`

### Registro de origem

- **Importância** — média (não mascarou erro nem bloqueou a aceitação do PR #2, mas enfraquecia a rastreabilidade em KB multi-environment e podia induzir diagnóstico errado de validação deploy).
- **Maturidade** — pesquisa feita (caso real em builds headless de duas KBs multi-environment; faltava isolar se o problema era comportamento do GeneXus/MSBuild, timing do wrapper ou leitura de contexto após a troca de environment).
- **Contexto** — na revisão do PR #2 (`fix: refine build post-processing classification`), builds com `-EnvironmentName` explícito registraram `observedContext.ActiveEnvironment` divergente do environment solicitado/resolvido. A direção registrada era montar um repro, comparar o stdout bruto de `GetActiveEnvironment` com o JSON final e decidir quando capturar o environment ativo.

### Resultado da implementação

Causa isolada em 2026-10-04 no wrapper, não no GeneXus/MSBuild. O commit `4a40bbb` (maio de 2026) moveu `GetActiveVersion`/`GetActiveEnvironment` para antes de `SetActiveVersion`/`SetActiveEnvironment` no `.msbuild` do `Invoke-GeneXusKbBuildAll.ps1`. O objetivo era citar, no bloqueio de `Set` falho, o contexto ativo na abertura; o efeito colateral foi que esse valor de abertura passou a ser reportado como contexto do build. Caso real: `-EnvironmentName NETPostgreSQL` na KB FabricaBrasil18, aberta em `.Net Environment`. O stdout do MSBuild mostrava `The active environment is '.Net Environment'` antes de `Set Active Environment Sucesso`, e o build de fato foi para `NETPostgreSQL`. O wrapper, porém, registrou `.Net Environment`, emitiu aviso falso de divergência e classificou os eventos pós-build com os hashes registrados do outro environment. As linhas do `PostBuild-Gx.bat` do NETPostgreSQL, embora registradas, saíram como não registradas, e o status caiu para `operacao concluida, pendente de confirmacao funcional`. O mesmo valor era o padrão de environment do `Register-GeneXusKbPostBuildEvents.ps1`. O `Invoke-GeneXusKbSpecifyGenerate.ps1` lia só depois do `Set`: o valor efetivo estava certo, mas o bloqueio de `Set` falho citava `(desconhecido)`.

Os dois wrappers agora leem o contexto antes e depois dos `Set`. `Resolve-GeneXusKbActiveContextReadings` (`GeneXusKbDeploymentEnvironmentSupport.ps1`) usa a primeira leitura como abertura e a última como efetiva. Com uma leitura só, ela vale como efetiva apenas quando nenhuma troca foi pedida ou quando o `Set` falhou; caso contrário, o efetivo fica nulo, com aviso. `observedContext.ActiveEnvironment`/`ActiveVersion` passam a ser o efetivo, e `ActiveEnvironmentAtOpen`/`ActiveVersionAtOpen` registram a abertura.

Os self-tests de ponta a ponta dos dois wrappers cobrem a troca bem-sucedida, a troca sem leitura posterior, o `Set` falho e a ordem das tasks no `.msbuild` gerado. Rodados contra os wrappers anteriores, falham com o sintoma real. O self-test do suporte cobre a função isolada. A correção não foi validada em novo build real na KB; a evidência é o stdout do build de 2026-10-04 mais os testes com MSBuild falso.

### Rastreabilidade

- Commit material: `be24ecd` (Corrige o environment efetivo reportado pelo BuildAll e pelo SpecifyGenerate), que também retira a entrada do `999` e cria este registro.
- Arquivos materiais: `scripts/Invoke-GeneXusKbBuildAll.ps1`, `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1`, `scripts/GeneXusKbDeploymentEnvironmentSupport.ps1`, `scripts/Test-GeneXusMsBuildBuildAllEndToEndSelfTest.ps1`, `scripts/Test-GeneXusMsBuildSpecifyGenerateEndToEndSelfTest.ps1`, `scripts/Test-GeneXusKbDeploymentEnvironmentContextSelfTest.ps1`, `xpz-msbuild-build/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md` e `999-ideias-pendentes.md`.
