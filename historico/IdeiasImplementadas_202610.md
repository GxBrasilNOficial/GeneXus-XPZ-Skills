# Ideias Implementadas — 2026-10

Registro de ideias que saíram de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodológico vigente.

## Qualidade dos avisos de coerência de Transaction e sanidade de Source — recorte v2

Implementado e validado localmente em 2026-10-11, conforme plano v2 congelado e execução autorizada. Origem: itens A2/C1 do relato de 2026-10-05 ([resíduo de controles no 999](../999-ideias-pendentes.md#xpz-relato-20261005-avisos)). O relato registrava nomes textuais em Level/Attribute tratados como desconhecidos e quatro avisos de IsEmpty/IsNull na referência oficial, além de IsAuthorized.

`Test-GeneXusTransactionCoherence.ps1` passa a ler texto normalizado de Attribute, com fallback para @name e precedência textual. DescriptionAttribute usa filho direto, com fallback XML quando ausente/vazio; `(None)` representa ausência e prevalece quando escrito no filho. A comparação nominal é sem distinção de caixa e restrita aos atributos diretos do nível, inclusive níveis aninhados. Chaves, classificações, códigos e severidades existentes permanecem: descritor inválido antes invisível pode revelar fail; atributo reconhecido pode revelar warn de classificação não gravável.

`Test-GeneXusSourceSanity.ps1` mantém nomes por Transaction/objeto e exclui somente IsEmpty/IsNull sem argumentos de receptor simples conhecido. Não exclui cadeias adicionais, nomes desconhecidos, chamadas globais ou argumentos, inclusive literal vazio; outras chamadas na condição permanecem examinadas. Só call-in-condition usa a varredura lexical de literais/comentários por Source, preservando linhas/previews. Literal/comentário de bloco não fechado ou escape por barra invertida antes do delimitador retorna ao detector anterior na parte. Balanceamento, elseif, iif e dense-condition conservam texto/regras anteriores e seus limites. Colisão módulo/atributo não recebe resolução semântica. Interfaces públicas e JSON permanecem.

**Validação.** Ambos os self-tests existentes passaram após ampliação com fixtures sintéticas: precedência/fallback, descritores e limites por nível, isRedundant/fórmula, Events/Rules, isolamento entre objetos/partes, predicados positivos/negativos, argumentos residuais, literais/comentários, fallback, linhas/previews e preservação dos demais findings. Parse de 367 scripts/exemplos: zero erros; `Test-XpzParameterNamingContract.ps1`: `XPZ_PARAMETER_NAMING_CONTRACT_OK`. Comparação dos dois motores atuais contra as versões de HEAD, somente por leitura de `C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml\Transaction\TabelaDeRendimento.xml`: Coherence 6→2 avisos (restam Caption/TooltipText de btn_Enter), SourceSanity 6→2 (call-in-condition 5→1, mantendo IsAuthorized; dense-condition 1→1); zero falhas antes/depois. Não substitui a medição histórica de DocumentoFiscal de 2026-08-17.

**Paridade e limites.** Contratos alinhados em 02, xpz-builder/SKILL.md, quality-checklist e satélites Transaction/DataView; inventário 09 aponta os donos. README, 07 e 08 foram conferidos por seções/termos pertinentes e não exigiram alteração; não se afirma leitura integral dessas bases longas. Sem importação, build ou runtime na IDE, sem nova consulta de painel, commit, push ou alteração de corpus/KB. Não há molde novo derivado de corpus: fixtures sintéticas não exigem anotação correspondente no PrivateMap, que não foi alterado. Reconhecimento de controles de formulário permanece no 999; sem regra por prefixo btn_*, sem comparação relativa ao baseline e sem expansão para outros predicados.

## Entrada por arquivos no editor cirúrgico e orientação de contratos JSON

Implementado em 2026-10-11 conforme plano v4 autorizado. Origem: itens B2/C3 do relato de 2026-10-05, que registravam atrito com strings multilinha, CRLF/tabs, interpolação e scripts envoltórios por frente, além de tentativas de usar `-AsJson` em motores com JSON por padrão. O relato não provava defeito no patch literal existente.

`scripts/Edit-GeneXusXmlSurgical.ps1` ganhou `AnchorPath`/`ReplacementPath` opcionais, exatamente uma origem por conteúdo, UTF-8 estrito com/sem BOM (remove somente um inicial), leitura literal de texto/EOL e erros estruturados 32–36 com details antes do núcleo. Nomes completos e posições existentes preservados; `-Anc`/`-Rep` passam a ser ambíguos. Strings vazias/$null coagido mantêm a semântica. O núcleo `GeneXusXmlSurgicalEditSupport.ps1`, citado como candidato no registro original, não precisou mudar: leitor e resolução ficaram locais ao wrapper, sem utilitário compartilhado novo.

Contrato e limites em `xpz-builder/SKILL.md`, checklist e exemplo `xpz-builder/examples/Edit-GeneXusXmlSurgical.example.ps1`; alinhamentos 02/08/09, adendo no desenho congelado e CHANGELOG trilíngue. Exemplo prepara auxiliares fora da frente e só aplica após exit zero, JSON válido, status=OK e wellFormed=true. Preservação dos auxiliares exige caminhos distintos do destino efetivo e seu .bak, inclusive por links/aliases; não há bloqueio novo de colisão. Sem assinatura não há heurística de codificação (41 00 42 00 permanece UTF-8 válido literal).

Validações sintéticas: `Test-PsScriptsParse.ps1` (367 arquivos, zero erros), `Test-EditGeneXusXmlSurgicalContract.ps1` (47 casos, incluindo matrizes e exemplo em processo filho), `Test-GeneXusLastUpdateConsumerContract.ps1` (372 verificações) e `Test-XpzParameterNamingContract.ps1`; `git diff --check`. Sem importação/build/runtime de IDE, KB real, commit ou push nesta execução. Exemplos/fixtures são sintéticos; não há molde derivado de KB real a registrar no PrivateMap.

Permanecem independentes no 999: migração global de AsJson, LineNumber/ExpectedLineText, NormalizeAnchorEol e lote de Source/Rules. A extensão por arquivos não normaliza quebras nem fornece atomicidade entre várias edições.

## Proteção determinística contra drift — Object/@type, Attribute e Domain

Recortes implementados em 2026-10-10 e 2026-10-11 da entrada «Drift de tipagem entre delta empacotado e snapshot oficial». O objetivo é impedir que XML gerado incorretamente por um agente siga para empacotamento sem uma comparação determinística com o acervo oficial; a execução da verificação local não depende de LLM nem consome tokens.

### Recorte implementado

- A Fase 1 compara `Object/@type` entre frente e acervo para o mesmo GUID. O recorte de `Attribute` top-level compara por GUID único a assinatura funcional; mudança de tipo/estrutura e redução de `Length`/`AttMaxLen` bloqueiam. Aumento exige solicitação explícita do usuário para a mudança exata, transmitida em `-ApprovedAttributeSizeGrowth`.
- O recorte de `Domain` autônomo compara atributos de raiz e propriedades por container com a pasta direta `Domain/` do acervo. Mudanças condicionais exigem aprovação JSON exata em `-ApprovedDomainChangesPath`; mudanças destrutivas, reduções de tamanho, identidade ambígua e varreduras incompletas bloqueiam. Os GUIDs dos Domains embutidos em `PackagedModule`, lidos de `Object/Part/ExportFile/Objects`, servem apenas para impedir classificação incorreta como novo; suas propriedades não são comparadas.
- `New-XpzImportPackage.ps1` executa o 9-FD antes do motor Python. `Build-GeneXusImportFileEnvelope.ps1` executa o pré-gate de Domain antes de remover/substituir `OutputPath`, inclusive com `-SkipGate` e `-Force`; essa rota continua sem comparação de assinatura de Attribute e sem proteção contra remoção textual global forte.

### Evidências e rastreabilidade

- `39b04cc`: bloqueio de drift de tipo e tamanho de Attribute.
- `e0fb283`: proteção de Domain no empacotamento; `30743fc`: alinhamento documental.
- `1dc429d` e `a37d582`: correções de colisões de identidade, transmissão de aprovações e entradas duplicadas; `4c8f94c`: leitura de Domains embutidos na estrutura real de PackagedModule.
- Self-tests sintéticos: `Test-GeneXusFrontAcervoDriftSelfTest.ps1`, `Test-NewXpzImportPackageDriftSelfTest.ps1` e `Test-BuildGeneXusImportFileEnvelopeSelfTest.ps1`. Na conferência de `4c8f94c`, as três baterias passaram e a reprodução independente bloqueou a colisão embutida nos modos por pasta e por lista explícita.

### Limites e pendências preservadas

As provas são locais e sintéticas: não demonstram importação pela IDE, build, runtime, referências ou compatibilidade de SQL/DBMS. Uma aprovação correspondente ao XML não comprova, por si, autorização humana nem essas evidências externas. A chamada direta ao motor Python não executa as proteções do wrapper. Não foi criado molde publicável derivado de KB real neste recorte; não há atualização correspondente a registrar no PrivateMap por esta consolidação documental.

Permanecem no [999](../999-ideias-pendentes.md#drift-de-tipagem-entre-delta-empacotado-e-snapshot-oficial--fases-residuais) as fases residuais: SDT/Item, Variable, drift entre objetos e `parm(...)`, além dos pontos de sanidade, contratos e endurecimento de rotas ali listados. Este registro não encerra a comparação ampla.

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

## Contexto de abertura e classificação de saída nos wrappers MSBuild (Export, Import, Preview, OpenHeadless)

Implementado em 2026-10-12, conforme plano aprovado e estabilizado (revisão por pares com estado "estável, não convergido"; a prova restante migrou para implementação/self-test). Origem: entrada correspondente do `999` (item 1 do defeito de mensagem de `Set` falho e itens 2/3 da armadilha de `Get-OperationExitCode`).

**Defeito 1 — mensagem de `Set` falho citava `(desconhecido)`.** `Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1`, `Test-GeneXusXpzImportPreview.ps1` e `Open-GeneXusKbHeadless.ps1` geravam o `.msbuild` com `Set*` antes de `Get*`; quando o `Set` falhava, o `blockingReason` dizia que o ativo na abertura era `(desconhecido)`/`(desconhecida)`. Os quatro passam a ler o contexto antes e depois dos `Set` (`Get` -> `Set` -> `Get`), com os `Get` de abertura incondicionais (`PropertyName="...AtOpenOutput"`, sem `Condition`) e os `Set*` mantendo o `Condition`; o parse migra de `Get-RegexValue` (valor único) para `Resolve-GeneXusKbActiveContextReadings` e o JSON ganha `observedContext.Active{Version,Environment}AtOpen`. O bloqueio de `Set` falho cita a abertura. Exits de Export/Import/Preview preservados (`41`/`31`/`32`). Preview mantém `<OpenKnowledgeBase>` sem `CaptureOutput`.

**Defeito 2 — `Get-OperationExitCode` classificava pelo nome da task em qualquer linha.** O `Open-GeneXusKbHeadless.ps1` procurava `GetActiveEnvironment`(24)/`GetActiveVersion`(23)/`SetActiveEnvironment`(22)/`SetActiveVersion`(21)/`CloseKnowledgeBase`(25) em qualquer parte de stdout+stderr, então linhas de sucesso de `Get` (ex.: `> GetActiveEnvironment Sucesso`) faziam uma falha posterior sair como 23/24. Substituído por `Get-GeneXusMsBuildOperationExitCode`, que classifica por **cadeia de prioridade** sobre marcadores com severidade `error`: `Open`(20) -> `SetVersion`(21) -> `SetEnvironment`(22) -> `Close`(25); formato não mapeado também é `20`. `23`/`24` ficam **`reservado`-sem-ramo** (sem evidência empírica de marcador próprio de `Get*`; nunca emitidos); `25` é `emitido-por-inferencia` (`CloseOnError` usa `ContinueOnError="WarnAndContinue"`; o `Run` usa `<CloseKnowledgeBase />`). Nunca casa os nomes PascalCase. Política stdout/stderr por helper único: stdout primário; stderr filtrado só quando o stdout não tem marcador `error` classificado; stdout vence em conflito.

**Suporte folha.** `Resolve-GeneXusKbActiveContextReadings` foi **movida** de `GeneXusKbDeploymentEnvironmentSupport.ps1` para a nova folha `scripts/GeneXusMsBuildActiveContextSupport.ps1` (sem dependência de deploy/hosting), que também hospeda o marcador único de falha (`Resolve-GeneXusMsBuildFailureMarker`; modos `Loose` para as flags e `ErrorSeverity` para o exit) e o classificador. Os 4 alvos carregam só a folha; o suporte de deploy passa a carregá-la por transitividade. `Read-MsBuildImportSignals.ps1` aceita o contexto do wrapper e ecoa `active{Version,Environment}AtOpen` + `contextQuality` (`legacy`|`partial`|`complete`); sem contexto, modo legado best-effort. Catálogo `msbuild-exit-codes.catalog.json` ganha `status` (`emitido`/`emitido-por-inferencia`/`reservado`) e `corpusDate`.

**Evidência empírica (corpus).** Em 2026-10-12 foram varridos 538 `msbuild.stdout.log` locais de `Temp/xpz-msbuild-build/` (logs de 2026-05-07 a 2026-10-09; pasta não versionada por conter saída de KB real). Toda linha de falha de task segue `<arquivo>.msbuild(L,C): <severidade> : > <rótulo da task> falhou`, com rótulo espaçado (`Set Active Environment`, `Open Knowledge Base Task`), nunca o nome PascalCase. Contagens: `error : > Set Active Environment falhou` 9; `error : > Set Active Version falhou` 1; `error : > Open Knowledge Base Task falhou` 4; `warning : > Close Knowledge Base Task falhou` 4, todas em logs que também têm falha de Open (limpeza do `CloseOnError`); nenhuma linha de falha de `GetActiveVersion`/`GetActiveEnvironment`. Os nomes PascalCase aparecem só em sucesso (`> GetActiveEnvironment Sucesso`, 561). Consequências: `20`/`21`/`22` têm marcador observado; `25` fica `emitido-por-inferencia` (só há Close em `warning`, de limpeza); `23`/`24` ficam `reservado`-sem-ramo; casar o nome PascalCase transformaria sucesso de `Get` em falha.

**Validação.** Self-tests: `Test-GeneXusMsBuildActiveContextSupportSelfTest.ps1` (ciclo folha↔deploy, guarda de dupla definição, semântica do marcador, política de fonte, matriz do classificador), `Test-OpenGeneXusKbHeadlessEndToEndSelfTest.ps1` (fake MSBuild + probe: exits 20/21/22/25/desconhecido, troca, Set falho, stderr só, conflito, estrutural) e `Test-GeneXusMsBuildActiveContextWrappersEndToEndSelfTest.ps1` (Export/Import/Preview com assembly sintética versionada; teste decisivo `observedContext` = `compactSignals` = arquivo; Set falho cita abertura; exits preservados; Preview sem `CaptureOutput`). `Test-MsBuildImportSignalsClassifier.ps1` ampliado com casos de contexto; `Test-MsBuildExitCodesCatalog.ps1` ganha schema de `status` e invariante "23/24 nunca como `return`". Baseline de BuildAll/SpecifyGenerate E2E, suporte de deploy, context self-test, stderr-noise e category B permanecem verdes; parse de `scripts/` sem erros. Fixture C# versionada em `scripts/fixtures/msbuild-e2e/SyntheticGeneXusMsBuildTasks.cs`.

**Paridade e limites.** `10-base-operacional-msbuild-headless.md`, `09-inventario-e-rastreabilidade-publica.md`, `scripts/msbuild-exit-codes.catalog.json`, `CHANGELOG.md` (3 línguas) e `xpz-msbuild-import-export/SKILL.md`. Provas sintéticas (fake MSBuild + assembly sintética), sem import/build/runtime reais. O closeout da revisão por pares (declínio de re-submissão da vN+1) ficou pendente em conversa dedicada (registrado no `999`).

**Eixo vizinho deixado aberto.** `Test-GeneXusKbConsistency.ps1` também abre a KB e lê o contexto só após os `Set` (template `Set` -> `Get`, sem `Get` de abertura), **não** detecta `Set` falho nem emite essa mensagem, e faz o parse com `Get-RegexValue` local (sem `*AtOpen`/`Resolve-GeneXusKbActiveContextReadings`) — o mesmo padrão corrigido nos 4 alvos desta frente. Foi **deixado fora do escopo**; incluí-lo exige antes decidir se o script deve bloquear em `Set` falho. `Get-GeneXusKbProperty.ps1` tem o mesmo padrão e também ficou fora do escopo: gera `Set` sem nenhuma leitura `GetActive*` e não detecta `Set` falho (cai em bloqueio genérico com exit `20`), de modo que nem a regra anterior de bloqueio explícito valia para ele. Decisão registrada como pendente no `999`.

### Rastreabilidade

- Commit material: `c6053ad` (Corrige contexto de abertura e classificacao de saida nos wrappers MSBuild).
- Arquivos materiais: `scripts/GeneXusMsBuildActiveContextSupport.ps1`, `scripts/Invoke-GeneXusXpzExport.ps1`, `scripts/Invoke-GeneXusXpzImport.ps1`, `scripts/Test-GeneXusXpzImportPreview.ps1`, `scripts/Open-GeneXusKbHeadless.ps1`, `scripts/Read-MsBuildImportSignals.ps1`, `scripts/GeneXusKbDeploymentEnvironmentSupport.ps1`, `scripts/msbuild-exit-codes.catalog.json`, `scripts/Test-GeneXusMsBuildActiveContextSupportSelfTest.ps1`, `scripts/Test-OpenGeneXusKbHeadlessEndToEndSelfTest.ps1`, `scripts/Test-GeneXusMsBuildActiveContextWrappersEndToEndSelfTest.ps1`, `scripts/Test-MsBuildImportSignalsClassifier.ps1`, `scripts/Test-MsBuildExitCodesCatalog.ps1`, `scripts/Test-GeneXusKbDeploymentEnvironmentContextSelfTest.ps1`, `scripts/fixtures/msbuild-e2e/SyntheticGeneXusMsBuildTasks.cs`, `10-base-operacional-msbuild-headless.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md`, `xpz-msbuild-import-export/SKILL.md`, `999-ideias-pendentes.md`.

## Prevenção de comment-based help inconsistente no inventário de wrappers

Recorte de **prevenção** da entrada «`Get-Help` não enxerga o comment-based help da maioria dos scripts» do [999](../999-ideias-pendentes.md#get-help-não-enxerga-o-comment-based-help-da-maioria-dos-scripts-falta-linha-em-branco-após-requires), implementado em 2026-10-12 conforme plano congelado e revisado por pares multi-modelo.

O defeito original era duplo: (1) um wrapper local com uma flag órfã no `.EXAMPLE` do comment-based help (ex.: `-AsJson` inexistente no `param()`) escapava da autoauditoria; (2) `#requires` colado ao `<#` torna o bloco de ajuda invisível a `Get-Help`. O recorte implementado faz a autoauditoria **detectar** essa classe em vez de classificá-la como conforme, para o caso de wrappers **já materializados** em pastas paralelas.

**Motor.** Novo helper `Get-XpzHelpSurfaceFinding` em `scripts/XpzWrapperEngineParamSupport.ps1`: audita o comment-based help do wrapper contra o próprio `param()` (grafias de nome/alias/CommonParameters montadas de `Get-Command.Parameters`; `Get-XpzEngineAcceptedParam` classifica o script como advanced/simple), reusa `Get-XpzAstJoinPathLeaf` para a forma `& (Join-Path … '<leaf>.ps1')` e aceita `-AlternateSelfLeaf` (nome-base do molde) e `-MoldePath` (paridade). Roteamento: flag órfã no `.EXAMPLE` de script **advanced** → bloqueio (`INVENTORY_CUSTOMIZED`, reason `help_example_undeclared_param:-<flag>`, mesma rota do `surface_mismatch`, sem token bloqueante novo); ajuda invisível, `.PARAMETER` órfão e flag desconhecida em script **simple** → `INVENTORY_HELP_ADVISORY` (consultivo, fora do regex de 4 tokens); `Get-Help` indisponível e defeito no molde de paridade → `INVENTORY_ENGINE_DIAGNOSTIC` (`help_query_failed`/`help_molde_<...>`). A paridade por molde suprime apenas o bloqueio idêntico achado num molde sadio.

**Integração.** `Test-XpzWrapperInventory.ps1` chama o helper no ramo `$standardExists` e emite a linha `INVENTORY_HELP_ADVISORY:`; o agregador `Test-XpzSetupAudit.ps1` ganha apenas comentário inline (regex de 4 tokens intacto). A `SKILL.md` de `xpz-kb-parallel-setup` normatiza o rótulo, a exceção determinística de remediação da flag órfã (8.c, Exceção 3) e a obrigação de reproduzir a linha literalmente no handoff.

**Validação.** Casos de unidade H1–H18 em `Test-XpzWrapperEngineParamSupportSelfTest.ps1` (flag órfã, alias, prefixo ambíguo/não-ambíguo de nome E de alias, CommonParameters, outro script, simple, sem `param()`/`dynamicparam`, formas de parse `;`/crase/`-Param:$v`/comentário, `Join-Path`, `.PARAMETER` órfão, ajuda invisível, `-AlternateSelfLeaf`, paridade de molde, dedup de achados repetidos e seção `.EXAMPLE` que não parseia — pulada); end-to-end + guarda-regressão do regex ampliada em `Test-XpzWrapperInventorySelfTest.ps1`; recorrência sobre os 24 moldes travada em `Test-XpzWrapperEngineParamMoldesSelfTest.ps1` (20 com invocação do próprio nome no `.EXAMPLE`, 0 achados). **Prova reproduzível:** os self-tests E2E-4 (flag órfã no `.EXAMPLE` → `INVENTORY_CUSTOMIZED(reason=help_example_undeclared_param)`) e E2E-5 (`#requires` colado ao `<#` → `INVENTORY_HELP_ADVISORY(reason=help_invisible)`) reproduzem as duas classes em fixture determinística. **Medição real datada, não re-executável no estado atual:** em 2026-10-12, **antes** da normalização da pasta paralela, o inventário sobre `C:\Dev\Prod\Gx_FabricaBrasil` (somente leitura) reportou `Copy-FabricaBrasilKbAcervoToFront.ps1` com `help_example_undeclared_param:-AsJson` (bloqueio) + 22 `help_invisible`; a pasta foi normalizada às 20:06 do mesmo dia e hoje emite zero achados de help — a medição fica como registro datado, não como prova (a prova reproduzível são os self-tests). Premissa verificada empiricamente (PowerShell 7.6.6): `#requires` colado → sinopse auto-gerada; com linha em branco → sinopse documentada.

**Limites preservados.** O gate de recorrência para os `scripts/*.ps1` do próprio repositório e a inconsistência de `TempDir` continuam abertos no 999; este recorte cobre wrappers de pasta paralela, não o acervo interno do repositório. Alterar os dois motores muda a assinatura de setup e pode exigir reauditoria das pastas paralelas; a prova externa é leitura, sem gravação.

### Rastreabilidade

- Commit material: `6772a94` (Detecta comment-based help inconsistente no inventário de wrappers).
- Commit material (dedup de achados): `7538e62` (Evita duplicação de achados de comment-based help no inventário).
- Commit material (correção): `6d360b5` (Corrige dois falsos positivos de bloqueio no check de comment-based help).
- Arquivos materiais: `scripts/XpzWrapperEngineParamSupport.ps1`, `scripts/Test-XpzWrapperInventory.ps1`, `scripts/Test-XpzSetupAudit.ps1`, `scripts/Test-XpzWrapperInventorySelfTest.ps1`, `scripts/Test-XpzWrapperEngineParamSupportSelfTest.ps1`, `scripts/Test-XpzWrapperEngineParamMoldesSelfTest.ps1`, `xpz-kb-parallel-setup/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`, `02-regras-operacionais-e-runtime.md`, `CHANGELOG.md`, `999-ideias-pendentes.md`.

## Aprendizados de GeneXus 18 medidos e paridade do fechamento pré-push

Implementado em 2026-10-16/17 a partir de handoff com sete aprendizados e de medições na KB de teste `wsEducacaoSpTeste` (GX18): `spc0024` como warning não bloqueante, com o `in` final omitido recebendo o default do tipo e a pré-condição "sem `out`" refutada; renome de `Attribute` por reimport restrito à janela pré-primeira-reorg (cautela no `02`, proposta descartada no `998`); Views do `WorkWithForWeb` (recusas `spc0045` por controle e `spc0012` em `.Create()`, mecanismos de chamada, embed por URL com nuance `wplogin`, exceções agregadas de `wcname`); frente cumulativa (semear a working copy da rodada anterior, sem enfraquecer o 9-FD); `class` em `<cell>` descartada no round-trip (usar `cellClass`); combo em `Attribute` de `Transaction` medido (resíduo no `999`); regressão `AddWhere` U14→U15.

Fechamento de 2026-10-17: rótulos de evidência do Catalog 3 alinhados à importação observada (`src0229`/`src0294` → `confirmado-import`; a definição dos rótulos passa a exigir importação **real** (`stage=import-real`; preview excluído) com resultado da tarefa rastreável (`importTaskSuccess`/`exitCode` do wrapper)), enumeração do satélite `dataview.md` completada e `09` atualizado.

**Validação.** Passo mecânico (`Invoke-PrePushMechanicalChecks.ps1`) sobre o intervalo pendente: árvore limpa, 0 atrás, parse sem erros; fase semântica em duas rodadas de revisão — enumeração do satélite `dataview.md` (gap confirmado) e exigência de `stage=import-real` na definição de `confirmado-import` —, ambas corrigidas e re-verificadas antes do fechamento.

### Rastreabilidade

- Commit material: `61a9546` (Documenta aprendizados recentes de GeneXus 18).
- Commit material: `f844af6` (Confirma `class` em `<cell>` por round-trip e DOM).
- Commit material: `5645a3f` (Mede em KB de teste as incertezas de `in` omitido e embed de View).
- Commit material: `febc791` (Corrige a pré-condição de `out` do faseamento e pina os dois códigos da View).
- Commit material: `e85ab07` (Mede o combo em Attribute de Transaction e registra import parcial).
- Commit material: `d5f9ff5` (Alinha coerência pós-pré-push: prova do default e embed autenticado).
- Arquivos materiais: `01j-workwithweb-cdata-padroes.md`, `02-regras-operacionais-e-runtime.md`, `04-webpanel-familias-e-templates.md`, `08-guia-para-agente-gpt.md`, `998-ideias-descartadas-e-porque.md`, `999-ideias-pendentes.md`, `CHANGELOG.md`, `xpz-builder/SKILL.md`, `xpz-builder/quality-checklist.md`, `xpz-builder/responsibilities-by-type/transaction.md`, `xpz-builder/responsibilities-by-type/workwithforweb.md`, `xpz-builder/responsibilities-by-type/dataview.md`, `xpz-msbuild-build/SKILL.md`, `09-inventario-e-rastreabilidade-publica.md`.
