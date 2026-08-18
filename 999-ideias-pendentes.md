# Ideias Pendentes

## Política de retirada de pendências

Quando uma entrada deste arquivo for resolvida, implementada ou incorporada ao contrato metodológico vigente, ela deve ser movida para o arquivo mensal correspondente em `historico/IdeiasImplementadas_YYYYMM.md` antes de ser retirada daqui. Este arquivo deve manter apenas ideias ainda pendentes ou subfrentes residuais explicitamente abertas.

Cada entrada usa dois campos curtos logo abaixo do titulo:

- **Importância** — quanto dói se a ideia nunca for implementada. Valores: `baixa` (útil mas dispensável), `média` (gap real com workaround manual), `alta` (risco de dano efetivo, como contaminação de KB, perda de trabalho ou falso negativo crítico).
- **Maturidade** — quão pronta a ideia está para virar frente de implementação. Valores: `ideia` (direção identificada, decisões de design em aberto), `pesquisa feita` (direção técnica resolvida, falta gatilho de caso real), `pronta para implementar` (caso concreto identificado, decisões fechadas, falta executar).

Entradas legadas sem avaliação carregam `FALTA AVALIAR` em ambos os campos até que sejam revistas em sessão dedicada.

**Editar a substância de um gap já registrado (neste arquivo ou no `998-ideias-descartadas-e-porque.md`) exige justificativa no corpo do commit.** Enfraquecer, reprecisar ou descartar a severidade de uma afirmação — não apenas corrigir redação, adicionar contexto ou reorganizar — precisa dizer **por que**: nova evidência medida, releitura do código, ou correção de erro anterior. Motivo: uma edição que suaviza um gap sem dizer por que **parece resolvido** para quem lê depois, e é pior do que o gap não ter sido achado — quem lê para de investigar. Caso real (2026-08-17): um commit sem corpo trocou «não é citado em lugar nenhum» por «não era coberto na documentação normativa»; a formulação nova era defensável à primeira vista, mas escondia que a única outra menção ao símbolo no repositório era uma cópia **defasada** num self-test — a frase sugeria mitigação onde havia agravante. Só foi achado porque outra sessão foi verificar; sem corpo no commit, não havia como saber se a mudança vinha de leitura nova ou só de estilo.

## Centralizar a fonte de verdade do conjunto de backends/adapters (três níveis)

- **Importância** — média (o modo de falha já se materializou **nove vezes numa única frente**, em três classes distintas, e é invisível para os gates atuais).
- **Maturidade** — ideia (o **nível 1** já foi aplicado em 2026-08-06; os níveis 2 e 3 têm decisões de desenho **em aberto** — ver as ressalvas; não classificar como «pronta para implementar»).

**Motivação medida (2026-08-06, frente do 6º backend Antigravity).** Ao inserir um backend novo, nove enumerações ficaram para trás, em **três classes** que exigem defesas diferentes:

- **(i) listas de nomes** — `09` (ponteiro do dossiê), `999` (varredura do Achado D, frente de migração stdin, frente de contrato tipado) + a referência cruzada quebrada pela própria correção;
- **(ii) listas de scripts** — enumerações de adapters/resolvedores em prosa;
- **(iii) contagens numéricas** — «nos **quatro** não-opencode», «nos **6** adapters», «os **2** argument-based».

Oito das nove foram achadas **depois** da pré-push formal: por revisão externa e pelas varreduras que ela provocou.

**Por que os gates atuais não pegam.** O `Test-PrePushNewTokenPropagation.ps1` procura o termo **novo** (`Antigravity`) em vizinhança do termo introduzido; a linha defasada **não contém** o termo novo — é justamente por isso que está defasada. A classe (iii) é ainda pior: **nenhuma busca por nome de backend a encontra**, porque a palavra «quatro» não contém «Antigravity». Só uma busca por contagem a acha, e ela não existia.

**Direção decidida (usuário, 2026-08-06): centralizar a fonte de verdade em vez de multiplicar listas.** A política já existia em parte — vários pontos do `02` e do `15` trazem «dono normativo: `xpz-llm-delegate/SKILL.md` — não duplicar aqui», e os commits `0711394`, `1f661ce` e `bb22400` desta frente já converteram enumerações em ponteiro. Os gaps de 2026-08-06 são exatamente os lugares onde isso **não** foi feito. Três níveis, do mais barato ao mais caro:

**Nível 1 — eliminar contagens numéricas (FEITO em 2026-08-06).** A contagem quase nunca acrescenta informação e é a forma mais traiçoeira de defasagem. Corrigidas por **remoção**, não por atualização, **inclusive as que ainda estavam certas** — contagem correta hoje é bomba-relógio no próximo backend, e o custo de removê-la é zero:

- `xpz-llm-delegate/SKILL.md` — «Há **seis** motores de delegação» → «Os motores de delegação (backends) ativos são»; «nos **quatro** não-opencode» → «nos não-opencode listados acima». Os identificadores `#1`..`#6` **permanecem**: são identidade estável de cada backend (citada em todo o repo como «backend #6»), não contagem do conjunto.
- `scripts/Test-LlmDelegateStdinHandlingSelfTest.ps1` — cabeçalho da seção (D) e o texto sobre stdin-based/argument-based passam a referir a lista `$messagePathAdapters`, sem número.
- `09-inventario-e-rastreabilidade-publica.md` — «nos **7** adapters Codex/…/Antigravity» → «nos adapters Codex/…/Antigravity» (a lista completa já está na própria frase; o número era redundante).
- `999` (entrada do `mimo`) — «os **6** backends atuais» → «os backends atuais». *(Aquela entrada foi **descartada** em 2026-08-16 e migrada para `998-ideias-descartadas-e-porque.md`; o item permanece aqui como registro do que o nível 1 corrigiu, não como ponteiro para frente viva.)*

- `999` (origem da varredura do Achado D) — «nenhum dos **cinco**» → «nenhum deles». Este sobreviveu a **duas** passadas de limpeza e foi achado por revisão externa; ver as lições de instrumento abaixo.

Regra derivada: **não introduzir contagem de backends/adapters em prosa; referir a lista.** Fora do escopo por serem registro imutável: `CHANGELOG`, `historico/` e documentos de design congelados (ex.: `opencode-reviewer-ro-least-privilege-design.md`, que fala de «4 backends» porque eram quatro quando foi escrito).

**Duas lições de INSTRUMENTO — insumo direto para o v1 do nível 3 (medidas em 2026-08-06).** A varredura por contagem falhou duas vezes seguidas na **mesma linha** (`999`, origem do Achado D), por defeitos do buscador, não por ausência de busca:

1. **Uma ocorrência por linha mascara as demais.** O script parava no primeiro padrão que casasse. A linha começa com «frente **dos 4** achados» (nome próprio de uma frente histórica); o buscador reportou esse trecho, a triagem o classificou como falso positivo e **descartou a linha inteira** — onde, mais adiante, estava a contagem real. Corolário para o gate: reportar **todas** as ocorrências por linha, nunca a primeira.
2. **Marcação markdown quebra o casamento.** O texto era `nenhum dos **cinco**`; exigir `\s+` entre a preposição e o número não casa por causa do negrito. Mesmo modo de falha já registrado para crases em regex de identificador. Corolário: o separador do gate precisa tolerar `*`, `_` e `` ` `` entre as peças.

Ambas se somam à causa já registrada (truncar a linha em N chars para triar rápido). As três são a mesma doença: **reduzir a evidência antes de triá-la**. Um gate que reincida em qualquer uma delas produz falso negativo com cara de varredura limpa — pior que não ter gate.

**Nível 2 — ponteiro onde é duplicação pura (ABERTO).** Seguir o que `0711394` já fez, caso a caso. A decisão em aberto é **onde não se aplica**: nem toda lista é duplicação. O `09` é inventário público — enumerar é a razão de existir dele; comentários de código precisam ser autocontidos (um comentário «ver `SKILL.md`» é pior para quem lê o script); e `13`/`14` **não** repetem a lista da skill, elas a **recortam por outro eixo** (`git-capable` vs `semantic-only`, `argv-limited` vs `stdin-dossier-capable`) — esse recorte é conhecimento da pré-push, não da skill. Distinção que governa a triagem: **enumeração normativa** (define o conjunto — deve ter dono único) vs **enumeração derivada** (aplica o conjunto a um eixo — legítima, mas precisa do nível 3).

**Nível 3 — gate consultivo derivando do CÓDIGO (ABERTO).** Para as listas que sobrarem por função própria. `scripts/Test-PrePushGateEnumerationParity.ps1` já resolve este modo de falha para o domínio dos **gates**: deriva a verdade do código e sinaliza linha que enumere ≥2 membros como **subconjunto próprio**; o cabeçalho dele registra que «três revisões perderam isso» antes de existir. Aqui seria o mesmo gate com outra fonte de verdade — e a fonte tem de ser o **código**, não a prosa da skill: `$AdapterScript` em `scripts/Invoke-LlmDelegatePanelDispatch.ps1` ou o `ValidateSet` de `-Backend` em `scripts/Resolve-LlmDelegateAuthorization.ps1` (escolher **uma** e justificar). Motivo de não ser a prosa: em 2026-08-06 o próprio `SKILL.md`, dono normativo, estava com a contagem errada — fonte única errada faz todo mundo apontar para o erro.

**Invariante irmão a absorver no desenho do nível 3 (não é um segundo gate).** O dispatcher não tem só a lista de backends: tem **quatro** mapas de registro (`$AdapterScript`, `$ExeParam`, `$ContentionKeys`, **`$AdapterDefaultTimeoutSec`**). O quarto ficou invisível em docs/checklists — backend ausente nele não falha ruidosamente, só perde timeout próprio. Quando o nível 3 sair do papel, a fonte escolhida deve servir também para exigir **paridade de chaves entre os quatro mapas** (ou self-test do dispatcher equivalente). Achado e detalhe: entrada «Registro de backend novo na `xpz-llm-delegate`» abaixo — **não** desenhar gate paralelo; absorver o invariante aqui.

**Arquivos previstos (nível 3)** — novos: `scripts/Test-PrePushBackendEnumerationParity.ps1` + self-test próprio. Alterados: `scripts/Invoke-PrePushMechanicalChecks.ps1` (tabela de gates, execução e objeto `gates` do JSON), `13-revisao-pre-push.md` (dono da rotina: prosa + tabela de gates), `09-inventario-e-rastreabilidade-publica.md` (entrada do script) e `08-guia-para-agente-gpt.md` (bullet do gate). Mais `CHANGELOG` trilíngue.

**Ressalva de desenho do nível 3 (o motivo de não estar pronta).** O `newTokenPropagation` já emite **41 candidatas consultivas** por rodada, todas falsos positivos há semanas. Ruído consultivo demais é o que leva o revisor a truncar a saída para triar rápido — e foi **exatamente** assim que o gap do `09:114` passou em 2026-08-06: o filtro certo foi rodado, o gap veio em primeiro lugar na lista, e a linha foi cortada em 220 chars antes do trecho problemático. Um gate novo com heurística ampla **agrava** a causa em vez de curá-la. O v1 precisa fechar antes: (a) restringir a linhas em **contexto normativo** (contrato/inventário/regra), não qualquer menção em prosa ou comentário; (b) excluir por construção os falsos positivos conhecidos — quebras de linha em que o membro faltante está na linha seguinte, comentários de self-test cuja lista restrita é correta (ex.: `enumeration=none-native` deve conter só copilot/gemini), documentos de design congelados e o `CHANGELOG` (registro histórico, não se reescreve); (c) definir se o `999` entra no escopo — as três defasagens dele mostram que **deve** entrar, ainda que seja «ideias futuras», porque é onde o escopo das frentes vive. Evidência viva do risco: ao registrar esta própria entrada, a linha «Relacionado» abaixo disparou `GATE_ENUMERATION_SUBSET` no gate irmão, por citar dois gates entre sete — falso positivo correto pela heurística, inútil para o revisor.

**Relacionado:** `scripts/Test-PrePushGateEnumerationParity.ps1` (padrão a espelhar), `scripts/Test-PrePushNewTokenPropagation.ps1` (o gate cego a este caso), a entrada «Registro de backend novo na `xpz-llm-delegate`» (invariante dos quatro mapas + nota de `$ContentionKeys`) e a entrada «Destino do backend Gemini CLI (#5)» abaixo, que nasceu da mesma frente.

## Destino do backend Gemini CLI (#5) — inelegível para conta individual desde 2026-08-06

- **Importância** — média (o backend #5 está **inoperante** nesta máquina; há workaround via Antigravity para a família `google`, mas a documentação segue descrevendo o Gemini como ativo).
- **Maturidade** — pesquisa feita (o diagnóstico está fechado; falta **decisão humana** sobre a via de autenticação antes de qualquer mudança documental).

**Medido em 2026-08-06** (despacho real de saúde por backend). O `Invoke-Gemini.ps1` falha com:

```
Error authenticating: IneligibleTierError: This client is no longer supported for Gemini
Code Assist for individuals. To continue using Gemini, please migrate to the Antigravity
suite of products: https://antigravity.google        (reasonCode: UNSUPPORTED_CLIENT)
```

**Não é versão do cliente:** atualizar 0.35.3 → **0.54.0** (`npm install -g @google/gemini-cli@0.54.0`) reproduz o mesmo erro. «This client» é o Gemini CLI como cliente do **Code Assist para contas individuais**, não o binário desatualizado.

**O adapter não está quebrado:** com 0.54.0 o `Resolve-GeminiExe` continua passando — versão mínima validada (`0.35.3`) e contrato de flags (`--prompt`, `--approval-mode`, `--output-format`, `--model`) seguem compatíveis. O que falha é a autorização do serviço, fora do alcance do adapter.

**Decisão em aberto (humana).** Restam duas vias de auth não testadas, ambas fora do Code Assist tier: **Gemini API Key** (AI Studio) e **Vertex AI**. Em 2026-08-06 o usuário decidiu **não** testá-las nem buscar essas assinaturas. Enquanto a decisão não for tomada:

- **não** aposentar nem marcar o backend #5 como removido em `xpz-llm-delegate/SKILL.md`, `02`, `09` e `14` — ele pode voltar por outra via de auth;
- ao montar painel nesta máquina, tratar o Gemini como indisponível de fato e lembrar que a família `google` só entra por `antigravity/gemini-*` (que colapsa para `google` via `Get-LlmDelegateTargetFamily`).

**Subfrente residual do detector (camadas 2 e 3).** A **camada 1** já foi feita em 2026-08-06 (o adapter consulta `Get-GeminiErrorMessage` antes de desistir no parse, e o extrator passou a reconhecer as formas flexionadas `authenticat*`/`authoriz*`/`sign in` — antes, `\bauth\b` **não** casava «authentication»). Ficam pendentes:

- **(2)** classificar falha de auth como **`unavailable`** em vez de `error` no painel — retentar não resolve, e é o mesmo tratamento que o `workspace-not-trusted` do Claude Code já recebe. Exige detector nomeado no `GeminiCliSupport.ps1` + entrada no `$unavailableFailurePattern` do dispatcher.
- **(3)** tratar `IneligibleTierError`/`UNSUPPORTED_CLIENT` como **permanente**: nem fallback nem retry ajudam; a mensagem deve dizer que a ação é humana (trocar a via de auth ou usar o Antigravity), em vez de cair no balaio genérico de erro de auth. Só vale investir depois da decisão acima.

**Dois estados de falha distintos, ambos medidos** (importam para quem for mexer no detector): **sem** credencial em cache o CLI escreve o prompt interativo de login no **stdout** e sai **0**; **com** credencial em cache sai **1** com o stderr estruturado acima. O primeiro estado é o que derrubava o diagnóstico antes da camada 1.

## Evolução futura de fidelidade textual em XML GeneXus antes do empacotamento

- **Importância** — média (a primeira proteção bloqueia o churn global forte observado, mas ainda há falsos negativos conscientes).
- **Maturidade** — pesquisa feita (escopo inicial implementado de forma enxuta; sobras deliberadas devem ser retomadas só com caso real ou decisão explícita).

A primeira implementação cobre `New-XpzImportPackage.ps1` via 9-FD: detecção de remoção forte de trailing whitespace herdado contra baseline por GUID único. O foco desta entrada é whitespace/EOL/diff textual, sem duplicar a ideia já existente de mojibake/UTF-8 por bytes.

Pendências deliberadas: levar detector textual para `Build-GeneXusImportFileEnvelope.ps1`; detectar trailing whitespace introduzido em arquivo novo/adicionado da frente usando baseline por GUID quando existir; avaliar bloqueio independente de flip de EOL, reindentação global e calibração de limites por fixtures reais.

## Follow-up do override de catálogo XPZ: auditor simétrico de wrappers e `-AllowRedundant`

- **Importância** — média (a frente atual bloqueia redundancia no registro e classifica lembretes, mas ainda falta auditoria dedicada de clones locais antigos e não há modo consciente para registrar redundante).
- **Maturidade** — pesquisa feita (decisões adiadas no plano v17).

Pendências deliberadamente fora da implementação do plano v17: avaliar `-AllowRedundant` no `Register-GeneXusObjectTypeCatalogOverride.ps1` somente se surgir caso real justificável; e implementar detector em `Test-XpzWrapperInventory.ps1` para apontar wrappers locais que ainda tratam qualquer override como `REMINDER_REQUIRED` ou não leem `noticeRequired`/listas `redundantTypeNames`/`divergentTypeNames`.

## Avaliar contrato v2/finalizador compartilhado para wrappers MSBuild GeneXus

- **Importância** — média (risco real de regressão e duplicação em pós-processamento de wrappers, mas a Fase 0 cobre a dor atual sem precisar desta arquitetura).
- **Maturidade** — ideia (motivação e riscos mapeados; desenho deve ser refeito como frente própria depois da Fase 0, sem herdar automaticamente a pilha de planos temporários).

Ideia futura: avaliar se os wrappers MSBuild GeneXus (`Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1` e consumidores relacionados) devem ganhar contrato de resultado v2/finalizador compartilhado para reduzir duplicação, centralizar serialização JSON stdout/`LogPath`, preservar `watcherContext`/timing e endurecer falhas de pós-processamento.

Não faz parte da correção atual/Fase 0. A Fase 0 deve sanar o incidente estreito observado: build operacional limpo com ruído conhecido em stderr não pode virar JSON degradado por variável não inicializada.

Adendo de retomada (2026-07-23, revisão do PR #2 `fix: refine build post-processing classification`): a frente v2/finalizador também deve absorver os follow-ups de cobertura que ficaram fora do aceite do PR. Subcasos concretos:

- confirmar paridade explícita de `Invoke-GeneXusKbSpecifyGenerate.ps1` frente ao filtro de ruído em `stderr` e à extração/classificação de eventos pós-build, não só por leitura de implementação compartilhada;
- coletar, quando houver KB disponível, evidência empírica de `.NET Framework` com build limpo e sem rebaixamento por pós-build real não registrado.

Detalhes e critérios para retomada: [`msbuild-result-contract-v2-finalizador-compartilhado.md`](msbuild-result-contract-v2-finalizador-compartilhado.md).

## Registrar evidência detalhada do ruído `g_service_worker`/`obj`

- **Importância** — média (o filtro já é fechado e preserva pares cruzados, mas a documentação não deve tratar o par como empiricamente provado sem registrar KB, versão, data e ocorrência observada).
- **Maturidade** — pesquisa feita (padrão já isolado no helper e coberto por self-test; falta anexar evidência operacional concreta em frente própria).

Coletar e registrar evidência empírica do ruído `context [/g_service_worker] N:N attribute obj isn't defined` em KB Java/Tomcat: KB/environment, versão GeneXus, data, quantidade/posição das linhas, stdout de sucesso e confirmação de que pares cruzados continuam stderr real. Até esse registro existir, a documentação deve descrever o par como observado/conhecido, não como "provado" no mesmo nível do par `anonymous`/`component`.

## Wrapper local opcional para pacote a partir de delta Git do acervo

- **Importância** — média (gap real com workaround manual: identificar o ultimo push, separar XML importavel de metadado local, abrir frente, copiar do acervo, resolver `lastUpdate`/9-FD, empacotar e inventariar).
- **Maturidade** — pesquisa feita (direção técnica delimitada; falta decisão explícita antes de criar molde opcional, script compartilhado ou ampliar cobertura de tipos).

Caso real motivador: numa pasta paralela de KB, o pedido "gere um pacote do que entrou no último push" terminou em pacote de um `WebPanel` (`wpProcessaArquivoDeTransacaoDePagamento`). O fluxo manual confirmou que a metodologia existente já cobre quase tudo: `New-GeneXusXpzFront.ps1`, `Copy-GeneXusAcervoToFront.ps1`, gate 9-FD, `Set-GeneXusXmlLastUpdate.ps1` quando necessário, `New-XpzImportPackage.ps1` e inventário pós-build do pacote.

Decisão registrada: não criar uma nova metodologia paralela nem um orquestrador compartilhado que replique o WORKFLOW do `xpz-builder`. Se a ideia for retomada, a forma candidata deve ser um wrapper local opcional em `xpz-kb-parallel-setup/examples/`, que derive `Object` XMLs alterados em `ObjetosDaKbEmXml` por intervalo Git, exija working tree limpa, bloqueie deletes/metadados/raízes não-`Object`, abra ou retome frente via wrapper local, semeie por GUID com `Copy-*KbAcervoToFront.ps1` e delegue o pacote a `New-*KbImportPackage.ps1`.

Follow-ups antes de promover:

- validar em uma segunda pasta paralela real se o default `HEAD~1..HEAD` cobre bem "último push" ou se o wrapper deve preferir `origin/main@{1}..origin/main`/range explícito no fluxo local;
- decidir se `Attribute` e outros roots importáveis devem entrar no wrapper ou permanecer bloqueados para empacotamento manual guiado por `xpz-builder`;
- decidir se o wrapper deve ser apenas exemplo opcional ou entrar como wrapper recomendado no inventário de setup;
- se virar script compartilhado, atualizar `09`, `CHANGELOG`, self-tests e paridade com `xpz-builder`/`xpz-kb-parallel-setup`.

## Investigar divergência de `observedContext.ActiveEnvironment` após `SetActiveEnvironment`

- **Importância** — média (não mascarou erro nem bloqueou a aceitação do PR #2, mas enfraquece a rastreabilidade em KB multi-environment e pode induzir diagnóstico errado de validação deploy).
- **Maturidade** — pesquisa feita (caso real observado em builds headless de duas KBs multi-environment; falta isolar se é comportamento do GeneXus/MSBuild, timing do wrapper ou leitura de contexto após troca de environment).

Durante a revisão do PR #2 (`fix: refine build post-processing classification`), builds reais com `-EnvironmentName` explícito em KBs multi-environment registraram `observedContext.ActiveEnvironment` divergente do environment solicitado/resolvido em alguns JSONs. O MSBuild respeitou a execução e o PR não mascarou erro real; por isso o achado não bloqueou a aceitação do PR. Ainda assim, o campo é usado como evidência operacional e merece frente própria.

Premissa relacionada em `998-ideias-descartadas-e-porque.md`: a entrada `CreateEnvironment` registra que `SetActiveEnvironment` via `-EnvironmentName` e `GetActiveEnvironment` cobrem o fluxo existente. O achado atual não reabre `CreateEnvironment`; ele pede revalidar a fidelidade do diagnóstico `observedContext.ActiveEnvironment` após troca de environment em KB multi-environment.

Direção: montar repro mínimo com dois environments, registrar requested/resolved/observed antes e depois de `BuildAll`/`SpecifyGenerate`, comparar stdout bruto do `GetActiveEnvironment` com o JSON final e decidir se o wrapper deve capturar o active environment em outro momento, manter ambos os valores ou rebaixar a confiança desse campo.

## Drift de tipagem entre delta empacotado e snapshot oficial — fases residuais

- **Importância** — alta para o falso-negativo original; Fase 1 implementada para `Object/@type` por `guid`, mas a assinatura funcional ampla ainda tem gaps.
- **Maturidade** — pesquisa feita (Fase 1 executada; fases residuais dependem de desenho próprio e novos self-tests).

Fase 1 implementada: proteção determinística contra delta de frente que tenha o mesmo `guid` do acervo oficial, ambos com `Object/@type` não vazio após `Trim()`, mas tipos normalizados divergentes. O contrato público novo usa `objectGuid` normalizado, `acervoPath`/`candidateAcervoPaths`, `acervoObjectType*` e `message`; acervo com GUID duplicado gera `front-object-type-drift-ambiguous-acervo` informativo.

Fica pendente:

- Fase 2: assinatura de tipo funcional para `Attribute`, `Domain`, `SDT/Item` e `Variable`.
- Fase 3: drift interno/intra-pacote e `parm(...)` versus variáveis/assinaturas.
- Endurecer chamada direta a `New-XpzImportPackage.py`, se varredura de consumidores diretos indicar que a quebra de compatibilidade é aceitável.
- Avaliar se o finding `front-object-type-drift-skip` em `Copy-GeneXusAcervoToFront.ps1` deve aderir ao contrato público novo de drift de tipo (`acervoPath`/`candidateAcervoPaths`/`message`) ou permanecer com contrato próprio do fluxo de cópia temporal/seed. Hoje ele bloqueia autocópia corretamente; a pendência é de consistência de contrato e diagnóstico, não de segurança imediata da Fase 1.
- Sanidade do acervo para XML ilegível, corrompido, sem raiz efetiva `Object` quando esperado, ou sem `guid` extraível.
- Decidir shape/tipo de elementos em `frontObjectTypeDrift.warnings` se algum warning nominal de type drift for proposto.
- Validação formal de formato GUID além de `Trim()` + não vazio.
- Reavaliar as entradas irmãs da pendência original, especialmente "Acervo conhecido no sanity..." e "Gate de dependências GeneXus...".

## Verificação empírica de claim factual na revisão (comportamento de runtime testado, não raciocinado)

- **Importância** — média (não é bug de produto; é lacuna de método que já deixou passar um erro factual em conteúdo pushado). Evita que um claim sobre comportamento de linguagem/API/ferramenta seja "convergido" por consenso de painel sem ninguém executar.
- **Maturidade** — ideia (direção clara; decisão de escopo em aberto — ver pergunta a resolver abaixo). Texto candidato esboçado, não redigido nos docs.

Incidente-origem (2026-07-02, frente Java/Tomcat Fase 1): a afirmação "o lookup `Get-GeneXusKbHostingKindSupportRecord` casa case-sensitive (`.Contains` sobre `[ordered]@{}`), com mismatch vs o `ArgumentCompleter` (`OrdinalIgnoreCase`)" nasceu num revisor e foi "confirmada" por **3 famílias** (anthropic/openai/ollama) ao longo de v1→v9 + pré-push reforçada — **ninguém testou**. Virou nota FALSA no design pushado (`java-tomcat-paridade-gerador-design.md:79`). Só o agente que gerou o handoff, rodando fresco com o código local, testou (`[ordered]@{'x'=1}.Contains('X')` → `True`; o lookup É case-insensitive) e pegou. Corrigido em `a1fa7e4`; a re-revisão exigiu que todos os revisores testassem `.Contains`.

Melhoria candidata: norma de **"verificação empírica de claim factual"** — quando uma objeção/afirmação depende do **comportamento de runtime** de linguagem/API/ferramenta (case-folding, coerção de tipo, `null` vs `''`, ordem de avaliação, exit code, etc.), não só do que o código *diz*, o revisor verifica por **execução** (comando de 1 linha), não por leitura; e o orquestrador **não conta "N revisores afirmaram o mesmo" como convergência** sobre um claim factual behavioral sem ao menos uma checagem empírica (consenso não substitui teste; suposição compartilhada não some com mais revisores da mesma família de suposição). É norma de disciplina, **não mecanizável** (nenhum `.ps1` detecta estaticamente uma prosa não-testada).

**PERGUNTA A RESOLVER (escopo da melhoria):** a norma entra **só na revisão pré-push** (`13-revisao-pre-push.md`, fase semântica que cada revisor executa; e `14` reforçada) **ou TAMBÉM na revisão por pares geral** (`15-revisao-por-pares.md`, a régua que vale para validação de plano/design/implementação)? O incidente ocorreu na revisão por pares da **implementação** (não na pré-push), o que aponta para o `15`; mas a pré-push é onde "executar a rotina" já é natural. Decidir: `13`(+`14`) só, `15` só, ou os dois — evitando duplicar a norma em dois lugares sem dono claro. Mexer no `15`/`13` é frente que merece o próprio tratamento (revisão por pares + pré-push reforçada).

**REFORÇO EMPÍRICO (2026-07-02, frente Java/Tomcat Fase 2 — a MESMA armadilha reincidiu):** na **pré-push reforçada** da Fase 2 (implementação), com o claim de case-folding já corrigido no design e travado por self-test obrigatório de `JAVA-TOMCAT`, **deepseek-v4-pro e kimi-k2.7-code** (2 vozes ollama, fase semântica) **reincidiram no erro exato da Fase 1**: ambas "confirmaram", raciocinando pela doc do **.NET puro** (`OrderedDictionary.Contains` usa `Object.Equals` Ordinal → case-sensitive), que o lookup seria case-SENSITIVE e que o comentário do código estaria "factualmente incorreto". É FALSO no PowerShell (`([ordered]@{'java-tomcat'=1}).Contains('JAVA-TOMCAT')` → `True`; o `[ordered]@{}` do PowerShell usa comparador case-insensitive, diferente do `OrderedDictionary` .NET default). Barrado por **dois guardas**: (1) o one-liner empírico; (2) o **self-test obrigatório** (`Test-GeneXusDeployBinHostingKindRoutingSelfTest.ps1` caso `JAVA-TOMCAT` + `Test-GeneXusRuntimeFreshnessHostingGuardSelfTest.ps1`), que asseram `JAVA-TOMCAT`→skip end-to-end — se o lookup fosse case-sensitive, esses testes FALHARIAM (não passariam verdes). **Contraprova a favor de documentar a norma:** `glm-5.2` (mesma família ollama, mesma sessão) **ACERTOU** — resolveu a nuance consultando o registro empírico deste `999` + os asserts dos self-tests, em vez de raciocinar pela doc. Ou seja, a disciplina, quando existe como referência escrita, funciona.

**Isto informa a PERGUNTA A RESOLVER:** o erro agora ocorreu na **fase semântica da pré-push** (Fase 2), tendo antes ocorrido na **revisão por pares da implementação** (Fase 1) → é **transversal**; aponta para a norma no `15` (régua geral, herdada por `13`/`14`), não só no `13`. **Ângulo novo (barato e forte) a incorporar:** além de "testar o claim uma vez", **travar o claim factual behavioral com um self-test** onde viável — foi o self-test obrigatório (não a checagem ad-hoc) que barrou a reincidência de revisores que não testaram; a norma deveria recomendar o self-test como **guarda durável**, não só a verificação pontual. (Crédito da insistência em tornar esse self-test obrigatório: Opus 4.8 + GPT-5.5 na revisão do plano da Fase 2, v7→v11.) **Handoff p/ outro agente:** editar `15` (e avaliar `13`/`14`) é doc-only mas é frente própria — apresentar proposta → triagem humana → pré-push reforçada antes de push; ver o incidente-origem (Fase 1, acima) + este reforço; o texto candidato da norma está esboçado no parágrafo "Melhoria candidata" acima.

## Paridade de gerador Java/Tomcat nas skills XPZ (deploy-bin, diagnóstico, metadata)

- **Importância** — média (gap real com workaround manual; escala para alta assim que uma KB Java for aferida em produção).
- **Maturidade** — v1 prática encerrada formalmente para metadata/setup + deploy-bin Java/Tomcat; permanecem apenas follow-ups pós-v1.

A v1 prática já cobre representação de `java-tomcat` em metadata, assistente read-only/opt-in de metadata no setup e co-gate Java/Tomcat do Eixo A (`deploy-bin`) sobre `WEB-INF\classes` externo. Os Eixos B/C seguem em modo seguro de skip explícito para KB Java, sem fingir diagnóstico .NET.

Detalhes de evidência e histórico ficam em [`evidence-catalog-java-tomcat.md`](evidence-catalog-java-tomcat.md), [`java-tomcat-paridade-gerador-design.md`](java-tomcat-paridade-gerador-design.md) e [`java-tomcat-fase3-replano.md`](java-tomcat-fase3-replano.md). O plano retomável das frentes futuras fica em [`java-tomcat-pos-v1-frentes-futuras.md`](java-tomcat-pos-v1-frentes-futuras.md).

Follow-ups vivos:

- motor Java do Eixo B (fonte gerado `.java`);
- motor Java do Eixo C (runtime-freshness Java por `ObjNavig`, XMLs de navegação/specification e artefatos locais `.java`/`.class`/`.js`);
- aferição eventual de stack clássico puro Tomcat 8/9 + JDK 8;
- decidir o destino do quadrante `unexpected-publication` diante de clean/rebuild dedicado: a medição da Fase 5 confirmou `Lf=∅, Pf≠∅` (medido `Lf=0, Pf=624`), que é o fail-safe **projetado** — não prova de que todo «Rebuild All» caia nele. O design já previa «se frequente, avaliar estado de última publicação bem-sucedida»; decidir entre **relaxar** para recompile-only e **manter** o conservador (o checklist da Fase 3 §8a ainda sugere renomear o rótulo para `unattested-publication`);
- retirada dos aliases legados do registro após um ciclo de release;
- automação futura de metadata Java além do assistente read-only, se algum dia for aprovada sem perder confirmação explícita.

## Cobrir padrões de delegação não-auditados pelo check `forwards_unknown_engine_param`

- **Importância** — baixa (limite conhecido declarado, sem falso-positivo). O check `forwards_unknown_engine_param` (helper `scripts/XpzWrapperEngineParamSupport.ps1`) audita o repasse wrapper→motor-compartilhado só para o padrão seguro `& $V` com `$V = Join-Path … 'scripts\<Leaf>.ps1'` (literal `'scripts'` no AST, resolução transitiva profundidade 1). Por desenho conservador (falso-positivo bloqueia pré-push de pasta paralela), **pula** — sem auditar — padrões reais possíveis em wrappers materializados: repasse **posicional** (`& $engine $valor`), splat por variável automática `@PSBoundParameters`, raiz **totalmente dinâmica**/concatenada (`"scripts\$leaf"`), resolução **multi-hop** (`$d = Join-Path $S 'scripts'; $e = Join-Path $d 'X.ps1'`), reatribuição não-rastreável da variável-raiz/intermediária, `Invoke-Expression`/dot-source/pipeline. Nenhum molde atual usa esses; o risco é um wrapper local divergir do molde nessas formas e escapar à auditoria (falso-negativo, nunca falso-positivo). Caso-borda residual: `Join-Path $repoRoot 'scripts\<X>.ps1'` apontando para arquivo LOCAL cujo leaf coincide com motor canônico (fora do padrão dos moldes).
- **Maturidade** — ideia (decisões de design em aberto). Direção: estender a resolução AST por forma, sempre preservando a postura conservadora (na dúvida, pular sem sinalizar); um caso-prova real (wrapper que escape e cause erro de binding em runtime) seria o gatilho para priorizar. Sub-ideia da mesma frente: **mecanizar a regra de engine-path da 8.a.ii reusando o helper** — hoje a 8.a.ii é texto single-literal (`Join-Path $SharedSkillsRoot 'scripts\<nome>.ps1'`), e o helper já cobre as formas aninhada/multi-arg/raiz-renomeada; a 8.a.ii poderia passar a apontar para o sinal mecanizado em vez de só descrever o caso por texto.

## Auditor de superfície de wrapper local defasada frente ao motor (direção motor→wrapper)

- **Importância** — média (gap real, sem falso-positivo; descoberto por reverse-lookup). Complementa a seção acima (`forwards_unknown_engine_param`), mas na **direção inversa**: o inventário (`Test-XpzWrapperInventory.ps1` + helper `XpzWrapperEngineParamSupport.ps1`) só detecta param/query que o wrapper local **repassa** e o motor **não** aceita (wrapper→motor-desconhecido); **não** detecta o caso simétrico — o motor compartilhado passa a expor uma **query nova** (no `ValidateSet`) ou um **parâmetro novo** (ex.: `-InstanceKey`) que um wrapper local **defasado não repassa**. Consequência: após uma capacidade nova no motor, wrappers locais que não acompanham ficam **silenciosamente sem** a capacidade, sem serem flagrados como defasados (o usuário só descobre ao tentar usar). Foi exatamente a assimetria que motivou escolher parâmetro em `search-objects` (em vez de query nomeada) para o reverse-lookup por instância — mas a Opção B só **reduz**, não elimina, essa classe de deriva. Origem: revisão por pares da implementação do reverse-lookup por instância (2026-07-03).
- **Maturidade** — ideia (decisões de design em aberto). Direção: o check certo é **simétrico** (cobrir queries **e** parâmetros), comparando a superfície do wrapper local (`[ValidateSet]` de `-Query` + bloco `param()`) contra a do motor canônico (choices do argparse + params declarados), sinalizando `stale-local-wrapper-surface` quando o motor tem item que o wrapper não expõe. Cuidado de contrato: `Test-XpzWrapperInventory.ps1` e `XpzWrapperEngineParamSupport.ps1` estão no manifesto de setup (`xpz-kb-parallel-setup/setup-contract.manifest.json`), então tocá-los **muda a assinatura de contrato de setup** — a frente precisa contar com o `AUDIT_REQUIRED`/recarimbo resultante. Gatilho de priorização: um caso real em que um wrapper local defasado cause confusão por capacidade "sumida".

## Limites conhecidos do diff de superfície de wrapper (direção wrapper→molde)

- **Importância** — média (limites conhecidos declarados; a maioria é falso-negativo silencioso — sem dano ativo —, mas dois casos [`[Alias]` renomeado e `ParameterSetName`] podem produzir **falso-positivo espúrio**, que é pior porque acusa um wrapper legítimo. Mitigado por nenhum molde atual usar esses padrões: o falso-positivo só dispara se um wrapper local divergir do molde exatamente por essas formas). O check `surface_mismatch`/`INVENTORY_SURFACE_ADVISORY` (helpers `Get-XpzScriptParamSurface`/`Get-XpzWrapperSurfaceFinding` em `scripts/XpzWrapperEngineParamSupport.ps1`, frente **implementada**) compara a superfície {nomes de parâmetro; `Mandatory`; conjunto de valores de cada `[ValidateSet]`} do wrapper local contra o molde `.example.ps1`. O que fica **fora de escopo** por desenho, com a severidade de cada lacuna:
  - `[Alias]` — três modos, todos sem cobertura: (a) renome de parâmetro + alias apontando para o nome do molde, com o param **obrigatório** → **BLOQUEIO espúrio** (`mandatory_param_missing` do nome do molde + `extra_mandatory_added` do nome renomeado, quando na verdade o alias preserva o contrato); (b) mesmo caso com param **opcional** → **ADVISORY espúrio**; (c) alias do molde **removido** no local (o molde `Test-KbSourceSanity.example.ps1` tem `[Alias('Path')]`) → **falso-negativo silencioso** (perda de alias não é vista). Remédio quando surgir caso real: realinhar molde + aliases preservando defaults locais, e/ou ensinar o helper a colher `[Alias]` como nomes equivalentes do mesmo parâmetro.
  - `ParameterSetName` — a superfície não modela parameter-sets; um param obrigatório só em um set é tratado como obrigatório global (IMPL5, determinístico: obrigatório SSE qualquer `[Parameter]` marca `Mandatory=$true`). Divergência de set entre molde e local pode gerar **bloqueio espúrio**. Determinístico, sem heurística.
  - Wrapper em **forma de função/filter** (sem `param()` de topo) — hoje classificado como `no_param_block` (a superfície vem só do `$ast.ParamBlock` de topo, nunca recursivo). Suporte real exigiria detectar a chamada de topo com `$PSBoundParameters`/repasse. Severidade: **falso-negativo/ruído** (advisory ou bloqueio por `no_param_block` conforme a superfície do molde).
  - `DynamicParam` — parâmetros dinâmicos não aparecem no `param()` estático; molde que os use sem `param()` de topo vira zero-superfície → **falso-negativo silencioso**.
  - Drift de **tipo** (`[string]` vs `[int]`) e drift de **default** (valor do `= ...`) — **fora de escopo por desenho** (o default do molde é placeholder como `SharedSkillsRoot`); nenhum sinal. Falso-negativo por construção.
  - `[ValidateSet(IgnoreCase=$false)]` divergente — argumentos nomeados são ignorados; a comparação é sempre `OrdinalIgnoreCase`. Divergência de case-sensitivity → **falso-negativo silencioso**.
  - **Múltiplos** `[ValidateSet]` no mesmo param (AND/interseção, verificado por teste: `[ValidateSet('a','b')][ValidateSet('b','c')]` só aceita `'b'`) e `[ValidateSet]` **não-string** (`[ValidateSet(1,2,3)]`) — tratados como **não-comparáveis** (quietos). Falso-negativo por desenho conservador.
  - **Opt-out de superfície** — não há mecanismo para um wrapper declarar "não me compare por superfície"; a única saída é realinhar ou aceitar o advisory. Se surgir necessidade real (wrapper deliberadamente divergente), avaliar um marcador de opt-out.
- **Maturidade** — ideia (cada lacuna vira frente própria só sob caso real). Direção geral: estender a extração AST por forma, sempre preservando a postura conservadora (na dúvida, quieto), e priorizar primeiro os dois casos de **falso-positivo espúrio** (`[Alias]` obrigatório, `ParameterSetName`) porque acusam wrapper legítimo. Cuidado de contrato idêntico ao da seção acima: `XpzWrapperEngineParamSupport.ps1` e `Test-XpzWrapperInventory.ps1` estão no manifesto de setup — mexer neles dispara `AUDIT_REQUIRED`/recarimbo nas pastas paralelas.

## Atualizar wrappers locais `Update-*KbFromXpz.ps1` em pastas paralelas para o contrato JSON do sync

- **Importância** — média (gap real com workaround). O `Sync-GeneXusXpzToXml.ps1` passou a emitir JSON de máquina no stdout (texto humano no stderr); os wrappers locais clonados em pastas paralelas — "hardcoded em praticamente todas" — ainda foram escritos para a saída textual antiga. Até atualizá-los, o consumo nominal programático do resultado fica comprometido nessas pastas (o `-ReportPath` segue como contorno).
- **Maturidade** — pronta para implementar. O molde `xpz-kb-parallel-setup/examples/Update-KbFromXpz.example.ps1` já foi corrigido nesta frente e serve de referência: consumir o JSON via `ConvertFrom-Json`, rotear todo diagnóstico humano para stderr (`Write-Host`/`Write-Warning`/`Write-Information` vazam para o stdout capturado de processo filho), `.Count`→`[int]` em `FullSnapshotMissing/Extra`, e re-emitir só a linha JSON no stdout.

Derivada da frente do contrato JSON do `Sync-GeneXusXpzToXml.ps1` (ver `CHANGELOG`). A propagação aos clones deve passar pela skill `xpz-kb-parallel-setup`. Sub-ideia relacionada: um **checador de conformidade portátil** ("o wrapper local emite JSON conformante no stdout?") com casa natural na `xpz-kb-parallel-pre-push`, para um agente confirmar a conformidade do clone local após a migração. Caveat de gate: trabalhar dentro de uma pasta paralela aciona `xpz-kb-parallel-setup`.

## Trava contra o agente reduzir o painel de revisão por pares por conta própria (oferecer ≠ decidir)

- **Importância** — média (gap de governança real). A régua (`15-revisao-por-pares.md`/`14-revisao-pre-push-reforcada.md`/`xpz-llm-delegate`) diz "não descartar revisor preferido em silêncio" e que reduzir o painel exige **decisão humana explícita**, mas **não há trava** que impeça o agente de declarar suficiência no **piso** (≥2 famílias) e **recomendar convergência/push** por conta própria. Incidente real (2026-06-20, pré-push reforçada da frente do contrato JSON do sync): o agente rodou só 2 revisores, declarou "piso atingido" e recomendou o push; o usuário corrigiu — o agente pode **oferecer** painel menor, nunca **decidir** reduzi-lo. Parar no piso e recomendar push é justamente o que o guardrail do `14`/`15` proíbe.
- **Maturidade** — ideia (decisões de design em aberto). Direção: regra **positiva** no `15` (composição/régua) e `14` — por padrão o agente despacha a **lista preferida inteira**; painel menor só como **pergunta**, e parar no piso + recomendar convergência/push fica proibido sem decisão humana de reduzir. Avaliar suporte mecânico (ex.: o closeout/`Resolve-LlmDelegatePanelDiversity` sinalizar "preferidos despacháveis não despachados" como bloqueio de recibo, análogo ao que o closeout já faz para estados auditáveis incompletos). A própria correção deve passar por revisão por pares.

Reforça a lição "consultar a lista INTEIRA, não parar no piso" registrada na frente Revisão por Pares formalizada.

## Backup cross-volume no executor de faxina da Fase 2a (`Remove-XpzKbFrenteHygieneFindings.ps1`)

- **Importância** — baixa (limite conhecido declarado, com workaround). O `-Backup` do executor de faxina move-aside **só no mesmo volume** (via `Move-Item` atômico); `-Backup` em outro volume é **recusado** com mensagem clara (erro de contrato). Workaround: apontar `-Backup` para um diretório no mesmo volume da pasta paralela, ou rodar sem backup (a deleção segue fail-safe: dry-run por padrão, reparse/ancoragem, idempotência).
- **Maturidade** — ideia (decisão de design em aberto). O cross-volume exigiria `copy+delete` **não-atômico**, que reabre superfície real (cópia órfã se o delete falhar após copy; item parcial se copy falhar no meio; rollback) — o painel da v3→v4 recomendou deixar fora do v1 por isso. Direção: se houver demanda, implementar copy+delete com ordem segura (gravar o manifesto só após confirmar a cópia íntegra; deletar a origem só após verificar a cópia; política explícita para cópia órfã), com self-test próprio para colisão/restauração/falha parcial. A correção deve passar por revisão por pares.

Derivada da frente do executor de faxina da Fase 2a (ver `CHANGELOG`).

## Hook PreToolUse positivo (auto-allow) do Claude Code — Fases 3–5

- **Escopo: Claude Code apenas.** Depende do hook `PreToolUse` + `permissionDecision: allow`, recurso que **não existe** em Codex/Cursor/OpenCode — não viaja transversalmente para os outros agentes (só o classificador é agnóstico, mas não há onde plugá-lo hoje). É a ferramenta que o usuário mais usa (Opus 4.8) e onde está o atrito.
- **Importância** — baixa (ganho de **conforto local**: reduz prompts de autorização para comandos read-only compostos que a allowlist literal não expressa). O **cérebro viaja** (lógica versionada em `scripts/`), mas o **fio não** (a entrada de hook em `~/.claude/settings.json` é máquina-local).
- **Maturidade** — **em implementação avançada (Passo G)**. Design **congelado** (v4 do daemon + plano v1) após revisão por pares (3 famílias) + Fase 0. **Passos A–G implementados:** fonte única Bash + self-test adversarial, **daemon `pwsh` persistente** (singleton/pipe/decisão), **cliente NativeAOT** (dispara-e-sai §5(b)), **gate de segurança §8**, e `Install-ClaudeCodePreToolUseSafeAllow.ps1` (deploy + wire `-Wire observe|enforce|off`). A saída §3.1 foi corrigida (**abster = não emitir `permissionDecision`**, verificado no fio real 2026-07-01). **Fase 3 (observe do FIO REAL) ATIVA** desde 2026-07-01: o hook `PreToolUse[Bash] --observe` mede a latência de concorrência do daemon e **sempre abstém** (passivo). **Pendente:** análise da Fase 3 (latência de concorrência sob carga real, condição do §9-0e), Fase 4 (ligar **enforce** só após a Fase 3 fechar a latência), Fase 5 (caminho **PowerShell** + distribuição via `xpz-skills-setup`). Ver [`claude-code-pretooluse-implementacao-v1-plan.md`](claude-code-pretooluse-implementacao-v1-plan.md) e [`claude-code-pretooluse-daemon-design.md`](claude-code-pretooluse-daemon-design.md).
- **BLOQUEIO de latência (medido 2026-06-22):** ~520 ms/comando (caminho comum, só `pwsh`) e ~570 ms (candidato, sobe `python`) — dominado pelo **startup do `pwsh` por chamada**, **5× o orçamento p95 ≤ 100ms**. O enforce inline é **inviável**; o **daemon** deixou de ser dissidência e virou **pré-requisito da Fase 4**. Próxima frente real = daemon (processo persistente consultado pelo hook), não enforce.
- **Polaridade negativa descartada** (ver `998-ideias-descartadas-e-porque.md`): este é o oposto útil — auto-aprova em vez de barrar.
- **Paridade documental — para o push FINAL da feature, não os intermediários:** enquanto a feature está **parcial e não-viva** (sem enforce; o wire `observe` é **passivo** — sobe o daemon e mede, mas **sempre abstém**, sem efeito real sobre as decisões do Claude Code), os scripts versionados **não exigem** entrada no `09` nem no `CHANGELOG`. A revisão pré-push reforçada de 2026-06-22 (painel de 5 preferidos, 3 famílias; 3 de 4 vozes — Codex, deepseek, glm — classificaram como follow-up; 1 voz minoritária recomendou bloqueio) confirmou isto. Quando o **enforce** for ligado (a feature passar a ter **efeito real** — o daemon subir em modo `observe` **não** conta, por ser medição passiva), aí sim: inventariar os scripts no `09` e registrar no `CHANGELOG`. `README` trilíngue: **avaliado e dispensado** (infra interna Claude-Code-only, não regra operacional de tipo GeneXus).
- **Dissidência ainda aberta:** escopo **global** em vez de só-o-repo (deepseek — risco baixo dada a gramática estreita).
- **Limitação conhecida do wire (`-Wire`, verificada empiricamente 2026-07-01):** o merge textual do `settings.json` (`Invoke-PtuWire` em `Install-ClaudeCodePreToolUseSafeAllow.ps1`) reconhece **só** o formato multi-linha canônico do objeto `hooks`/bloco `PreToolUse`; um `PreToolUse` pré-existente em formato compacto/inline faz `Install -Wire` abortar **fail-closed** por «formato inesperado» (nunca corrompe o arquivo). Aceitável hoje (o `settings.json` do Claude Code é multi-linha; a proteção anti-hook-de-terceiro e os demais ramos fail-closed — sem `hooks`, arquivo inexistente, JSON de saída inválido — foram verificados). Robustez a formatos arbitrários = frente futura junto com o G3 (distribuição via `xpz-skills-setup`).
- **Fase 3 (observe) — RESULTADO após 2 dias de uso real (medido 2026-07-03):** 1406 medições no `ptu-observe-<hash>.log`. **O P0 de concorrência FECHOU A FAVOR: ZERO outcomes `busy`** (o daemon single-threaded **nunca enfileirou** em uso real, mesmo com sessões paralelas). Latência do fio quente p50 **2,4 ms** / p95 **5,4** / máx 76,4 (bem dentro do deadline de 80 ms; melhor que o ~17-24 ms estimado no Passo F — daemon aquecido). **14% dos comandos Bash (201/1406) seriam auto-aprovados** pelo enforce. Estabilidade: 0,3% cold + 0,4% deadline, **0 erros** de parse/identidade. Singleton **verificado OK** — os `loserSpawn` transitórios de cold-path (quando um cliente pega a janela de pipe-ausente) perdem o mutex e **saem sozinhos** (`exit 0`); raro (4 cold em 1406). **Conclusão: Fase 4 (enforce) desbloqueada no mérito** (o P0 que a condicionava não existe em uso real); falta a decisão datada + ligar o wire enforce + inventariar no `09`/`CHANGELOG` (paridade documental que a l.47 desta entrada difere para o enforce/efeito real).
- **Higiene: auto-faxina de logs de deploys temporários (achado da Fase 3, 2026-07-03):** os self-tests que rodam de deploys temporários (StepC/StepD/gate §8) geram `ptu-daemon-<hash>.log`/`ptu-client-<hash>.log` de identidade única em `%LOCALAPPDATA%\ClaudeCodePreToolUseSafeAllow\` que **nunca são limpos** — acumularam **324 arquivos órfãos** (limpos manualmente nesta data, preservando só os 3 da identidade real viva). O self-test/produto deveria remover os logs do deploy temporário no teardown, ou uma rotina de faxina por idade + identidade-morta. Não-crítico (~2 MB) mas cresce a cada self-test; frente futura.

## Reorganizar a árvore de fontes do produto PreToolUse (daemon auto-allow)

- **Importância** — baixa (cosmético; o produto **instalado** já fica numa pasta só, via o deploy do install — a bagunça é só na **árvore de fontes**). Hoje o produto está espalhado em três lugares sem casa única: 3 docs `claude-code-pretooluse-*.md` na **raiz**; fontes C# em `ptu-native/`; 13 scripts em `scripts/` (pasta *flat* com ~298 scripts do repo), agrupados só pelo **prefixo longo** `ClaudeCodePreToolUseSafeAllow…` no nome — o prefixo gigante é o sintoma da falta de subpasta.
- **Maturidade** — ideia (decisões de design em aberto; **alto risco de execução**). Boa parte do espalhamento é **imposta** pelo formato do monorepo: scripts têm de ficar em `scripts/` (a allowlist e o invocador canônico casam `scripts/X.ps1`; `.ps1` fora de `scripts/` é proibido), C# exige projeto próprio, docs soltos na raiz é o padrão do repo. Mover **agora** é arriscado: design **congelado** (3ª alteração exige painel), **caminhos hard-coded** em vários lugares (gate §8, deploy do install, self-tests, `publish.bat`), e estamos no meio do Passo G. Direção: tratar como **frente dedicada após o Passo G fechar** — avaliar pasta própria (se a allowlist permitir subpasta de scripts), encurtar o prefixo dos nomes, agrupar os docs. A correção deve passar por revisão por pares.

Origem: levantado pelo usuário em 2026-06-30 ao ver o mapa por subpasta durante o Passo G/G2.1; decisão conjunta de **adiar** (opção (a) — seguir o install como está; a árvore de fontes fica para depois).

## Enxugar a allowlist para a forma canônica de invocação dos adapters (resíduo (b2), opcional/local)

- **Importância** — baixa (housekeeping local; **(b1) já eliminou a deriva na origem** documentando a forma canônica, tornando (b2) praticamente opcional). A allowlist do Claude Code (`.claude/settings.json`/`settings.local.json`, **git-ignored**, máquina-local) acumula entradas literais antigas dos adapters; a entrada ampla `Bash(pwsh -NoProfile -File scripts/*)` já cobre a forma canônica, então não há ganho durável em podar — e a poda não viaja para outros agentes/máquinas.
- **Maturidade** — ideia (opcional, a critério do usuário; **não** podar em massa o `settings.local.json`). As partes **(a)** `-MessagePath` e **(b1)** forma canônica documentada estão **concluídas** — ver `historico/IdeiasImplementadas_202606.md` («`-MessagePath` estendido aos adapters…» e «Forma canônica de invocação dos adapters documentada»).
- **NÃO** criar um wrapper guarda-chuva novo só para driblar o matcher: custa inventário (`09`), paridade e manutenção. Princípio: **menos variação > mais scripts**.
- **Relacionada:** a entrada seguinte (migração stdin de `Invoke-Gemini`/`Invoke-Copilot`/`Invoke-Antigravity` + limite de 32KB) segue aberta, dependente de assinatura/acesso funcional para validação empírica.

## Migrar `Invoke-Gemini`/`Invoke-Copilot`/`Invoke-Antigravity` para stdin e/ou guard de tamanho de prompt

- **Importância** — baixa (workaround trivial existe). Os adapters argument-based `Invoke-Gemini.ps1`, `Invoke-Copilot.ps1` e `Invoke-Antigravity.ps1` ainda passam o prompt por **argv**, sujeitos ao **limite ~32KB de linha de comando do Windows** (`Argument list too long`) e ao sintoma não-determinístico `StandardOutputEncoding` em host com stdout não-redirecionado. Workaround atual: invocá-los pela ferramenta Bash (stdout em pipe) com prompt enxuto. **O Antigravity (backend #6, 2026-08-04) é o caso mais sensível dos três:** por injetar contexto próprio grande, é o que mais tende a estourar o teto e ser omitido com `dossier-too-large` na pré-push reforçada.
- **Maturidade** — (b) IMPLEMENTADA 2026-06-22 (estendida ao Antigravity em 2026-08-04); resíduo (a) bloqueado por dependência externa. Direções: (a) **AINDA ABERTO** — quando houver **assinatura/acesso funcional** de Gemini/Copilot/Antigravity nesta máquina, testar `gemini -p`/`copilot -p`/`agy -p` lendo stdin e, se aceitarem, migrá-los ao padrão **stdin-based** espelhando o opencode (`Invoke-OpenCode`/`Start-OpenCodeJob`); só assim o teto ~32KB cai de fato para esses três. Sobre o Gemini, ver a entrada «Destino do backend Gemini CLI (#5)» — hoje ele nem autentica, então a validação empírica dele está duplamente bloqueada. (b) **guard de tamanho — IMPLEMENTADO** (2026-06-22): `$MaxArgvPromptChars = 30000` fail-closed (heurístico em chars) em `Invoke-Gemini`/`Invoke-Copilot` e, desde 2026-08-04, em `Invoke-Antigravity`; recusa com `BLOCK` claro antes do `Argument list too long`; cobre `-Message` e `-MessagePath`. Migrado ao `historico/IdeiasImplementadas_202606.md`; ver `CHANGELOG`.

## Follow-up: versão-de-contrato confrontável + gate consultivo de lockstep (etapa 2 da auditoria de drift de consumo)

- **Importância** — média (a etapa 1 já fecha o caso atual; isto endurece contra bumps futuros e mecaniza a regra de método).
- **Maturidade** — ideia (versão-de-contrato tem design em aberto; o gate consultivo é direto).

**Já implementado (etapa 1, migrado para `historico/IdeiasImplementadas_202606.md`):** o motivo `INVENTORY_CUSTOMIZED(reason=consumes_legacy_text_stdout)` em `scripts/Test-XpzWrapperInventory.ps1` (heurística texto-vs-molde para `Update-*KbFromXpz.ps1` × `Sync-GeneXusXpzToXml.ps1`) + 8.a.ii / tabela 8.h / regra de `INVENTORY_CUSTOMIZED` por motivo no `SKILL.md` + self-test; e a **regra-doc de lockstep** no `13` (§3 Comparação documental) e no `AGENTS.md` raiz (Revisão pré-push). Origem: relato de agente de pasta paralela após o push do contrato JSON do sync (`e11ffbc`/`ef8530b`, ver [[project_sync_json_contract]]).

**C (etapa 2) — versão-de-contrato confrontável:** amarrar o `SchemaVersion`/`Kind` que o motor `Sync-GeneXusXpzToXml.ps1` carimba a uma noção de versão-de-contrato que a auditoria confronte. Motivo concreto: a heurística textual da etapa 1 é **cega a drift de versão dentro do JSON** — um wrapper que parseia v1 com `ConvertFrom-Json` passa **mesmo** com o motor em `SchemaVersion=2`. Também não detecta migração parcial nem parsers alternativos (`System.Text.Json`). Gatilho de revisão = **próximo bump de contrato** do motor de sync (até lá só há v1 em campo).

**Gate consultivo (opcional) — lockstep mecânico:** um gate no orquestrador da pré-push análogo ao `scripts/Test-PrePushSharedScriptSkillCoverage.ps1`, mas focado em **skill que AUDITA consumidores**: quando o diff toca um motor compartilhado com contrato de saída e existe skill de auditoria de consumidores conhecida não-tocada, avisar. Hoje a regra de lockstep vive só como pergunta-doc (etapa 1); este gate a tornaria mecânica. Ver [[project_xpz_kb_parallel_pre_push]] para o precedente do mecanismo.

**Relacionada:** a frente derivada (lado pasta paralela) "atualizar wrappers locais `Update-*KbFromXpz.ps1`" — corrige os clones reais nas pastas paralelas; esta etapa apenas torna o **gate** mais robusto a versões.

## Rebaixar o warning `envelope-minimo`/`panel-envelope-minimo` de "apto com ressalvas" para informativo no pacote seletivo normal

- **Importância** — baixa (ruído de status, sem dano). Todo pacote seletivo de objeto único gerado sem `--template-package-path` sobe com `status="apto com ressalvas"` por causa do warning `envelope-minimo` (`scripts/New-XpzImportPackage.py:101`; `panel-envelope-minimo` em `:265` para Panel), mesmo sendo o caminho normal e correto. O rótulo "ressalvas" perde sinal: o operador não distingue o caso esperado do caso que realmente merece atenção (pacote misto/complexo).
- **Maturidade** — ideia (decisão de design em aberto). Direção: quando o pacote for pequeno/seletivo e não houver `--template-package-path` comparável disponível, rebaixar `envelope-minimo`/`panel-envelope-minimo` de warning para `information` (ou nível equivalente que **não** dispare `apto com ressalvas`), preservando o aviso real para pacotes mistos/complexos e **sem** enfraquecer o gate de `error :` no log. O status é decidido em `scripts/New-XpzImportPackage.py:414`/`:463` (`apto com ressalvas` sempre que há `warnings`); avaliar mover esses dois avisos para a lista `information` nesses casos, mantendo `warnings` para envelope ausente em pacote que de fato precisaria do template.

Skills consumidoras: `xpz-builder`, `xpz-msbuild-import-export`. Motor: `scripts/New-XpzImportPackage.ps1` / `.py`. Origem: tarefa secundária opcional levantada no prompt de um agente de pasta paralela (2026-06-21), fora do escopo da frente do `.ContainsKey`/OrderedDictionary; registrada aqui para outra sessão cuidar.

## Inverter o gate de placeholder de commit no histórico: de denylist de frases para checagem de forma de hash

- **Importância** — baixa (gate **consultivo**, `severity=warn`, `exit 0` sempre — não bloqueia push; mas é **falso-negativo silencioso de rastreabilidade**: deixa entrada de histórico ser commitada com o campo `Commit:` não preenchido sem avisar). Caso real 2026-06-21 (frente `.ContainsKey`/OrderedDictionary): a entrada migrada para `historico/IdeiasImplementadas_202606.md` foi commitada com `- Commit: a registrar no commit desta frente.` e o gate **passou**; o gap só foi pego pela **fase semântica** da pré-push (grep dirigido por frases de placeholder), não pelo gate mecânico — depois corrigido (commit `e5a2ccb` preencheu `bd2abb8`).
- **Maturidade** — pronta para implementar (direção técnica resolvida; falta executar + self-test).

**Raiz (no código):** `scripts/Test-PrePushHistoryCommitPlaceholder.ps1`, função `Test-IsPlaceholderValue` (`:119`). Hoje um valor de `Commit:`/`PR:` só é considerado placeholder se: (a) vazio/espaços; (b) casar `^<[^>]*>$` (marcador entre angulos); ou (c) casar a **denylist de frases** `$placeholderWordRegex` (`:90`): `este commit|este pr|este pull request|todo|tbd|tba|a preencher|preencher depois`. Qualquer redação livre de "preencho depois" **fora** dessa lista escapa — e em PT há muitas variantes (`a registrar`, `a confirmar`, `pendente`, `do commit desta frente`, `depois`, etc.). É denylist de vocabulário, não verificação de que um `Commit:` válido **tem forma de hash** — gato-e-rato com a linguagem.

**Fix proposto (inverter para allowlist de forma):** considerar **preenchido** apenas o valor que casa a forma de um hash de commit entre crases — ex.: `` `[0-9a-f]{7,40}` `` opcionalmente seguido de `` (`mensagem`) `` —; **qualquer outro** valor (texto livre, vazio, `<...>`, sinônimo novo) vira `warn`, independentemente da redação. Isso elimina o gato-e-rato. Tratar `PR:` por forma análoga (número de PR e/ou URL). Preservar a **exceção legítima** ("hash será preenchido no commit seguinte") pela própria natureza **consultiva** do gate (continua `warn`/`exit 0`; o agente confronta a candidata na fase semântica e confirma "a preencher" ou corrige) — **não** tornar bloqueante.

**Cuidados:** calibrar o regex de hash aceito contra os formatos **reais já usados** em `historico/IdeiasImplementadas_*.md` (varrer antes, para não gerar falso-positivo em entradas legadas corretamente preenchidas — algumas citam `` `hash` `` + `(mensagem)`, conferir variações). Manter `severity=warn` (consultivo); o objetivo é reduzir falso-negativo, não passar a reprovar.

**Validação:** self-test próprio (casos: `` `bd2abb8` `` → pass; `a registrar...`/`a confirmar`/`pendente`/vazio/`<...>` → warn; forma de `PR:` válida/inválida). Arquivos: `scripts/Test-PrePushHistoryCommitPlaceholder.ps1` (+ novo self-test). O orquestrador `scripts/Invoke-PrePushMechanicalChecks.ps1` já consome o gate (chave `historyCommitPlaceholder`); refletir no inventário `09-inventario-e-rastreabilidade-publica.md` e, se a descrição do passo mecânico mudar, no `13-revisao-pre-push.md`. Origem: nota da fase semântica da pré-push 2026-06-21; registrada para outra sessão.

## Validar a propagação do token de self-test no gate de rastreabilidade da pré-push

- **Importância** — baixa (falso-negativo de **gate consultivo**, com backstop). O `scripts/Test-PrePushTraceabilityCoverage.ps1` confere que um script no diff é referenciado no `09` (nome do arquivo + motor), mas **não** valida que o **token** `*_SELFTEST_OK` emitido por um self-test novo foi propagado ao `09`: o `$scriptRiskPattern` (~`:152`) não cobre a família `GENEXUS_*_SELFTEST_OK`, e o bloco de self-tests (~`:183-220`) valida menção a nome/motor, não ao token. Se uma frente futura adicionar self-test com token novo sem registrar o token no `09`, o gate **não avisaria**. **Não** é dano efetivo (`alta`): o backstop é a fase semântica + o painel reforçado (que de fato verificaram a propagação do `GENEXUS_DEPLOY_BIN_CLASSIFICATION_SELFTEST_OK` nesta frente); o gate só deixaria de avisar. Mesmo tipo de ponto cego de gate consultivo do follow-up acima (placeholder de commit).
- **Maturidade** — ideia (design em aberto). Direção: ensinar o gate a, para cada self-test novo/alterado no diff, extrair o(s) token(s) `*_SELFTEST_OK` que ele **emite** (string literal no `.ps1`) e confrontar a presença desse token no `09` (e/ou cobrir a família `GENEXUS_*_SELFTEST_OK` no `$scriptRiskPattern`). Decisões em aberto: como extrair o token de forma robusta (literal vs. interpolado), mapear token→linha do `09`, e manter consultivo (`warn`, sem reprovar). Self-test próprio. Origem: lacuna pré-existente apontada pelo deepseek-v4-pro na pré-push reforçada da frente `.ContainsKey` (2026-06-21); registrada para outra sessão.

## Reavaliar enriquecimento do manifesto de capacidades LLM e preservação de metadados de preferidos

- **Importância** — baixa (não bloqueia o uso atual: o manifesto é dica de oferta, nunca verdade do gate; há workaround manual/sondas vivas por rodada).
- **Maturidade** — ideia com triagem feita (há evidência local para uma parte, mas a frente precisa decidir escopo e risco antes de implementar).

Origem: reavaliação de 2026-07-11 após a pré-push reforçada da frente de fallback auditável da `xpz-llm-delegate`. Um revisor comparou a implementação com o plano temporário `Temp/revisao-por-pares/capability-fallback-plan-20260709-1458/manuscrito-v11.md` e apontou três itens previstos no plano, mas não implementados. Após reavaliação, eles **não foram tratados como essenciais para o push atual**; ficaram como ideias a revisar, porque "plano pediu" não basta para provar vantagem de produto.

Triagem dos itens:

1. **Codex `~/.codex/models_cache.json`** — candidato mais promissor. Nesta máquina existe `models_cache.json` com estrutura limpa (`fetched_at`, `etag`, `client_version`, `models`) e modelos reais listados. Vantagem: enriquecer o manifesto sem rede e sem depender de quota. Risco/decisão: só promover entrada quando o cache provar destino suficiente; não inventar `openai/<modelo>` quando a fonte não comprovar provider. Direção provável: fonte `cache`, confiança `medium`, sanitização agressiva e filtro de modelos ocultos/internos.
2. **`opencode models <provider>` no build do manifesto** — não implementar como default sem novo desenho. É sonda viva, útil em rodada operacional, mas volátil para um manifesto cacheável: pode depender de rede/provider, quota, latência e erro transitório. Direção aceitável: se virar frente, ser opt-in explícito (`probe`/snapshot), falha não fatal, erro resumido/sanitizado e sem quebrar o manifesto inteiro.
3. **Preservar campos desconhecidos no `preferred-reviewers.json`** — não preservar genericamente. A forward compatibility é desejável, mas este arquivo tem contrato de sanitização forte; campos desconhecidos podem carregar token, endpoint, path local, política velha ou semântica futura que o script atual não entende. Direção mais segura se houver caso real: bloquear `schemaVersion` futuro desconhecido e/ou preservar apenas uma whitelist explícita e sanitizada (`metadata`/`notes`), mantendo backup atômico como proteção contra perda irreversível.

Critério para retomar: caso real em que a ausência do cache Codex prejudique a oferta de revisores, ou decisão explícita de criar uma frente de capacidade LLM com probes opt-in. Não bundlar com correções de pré-push; tratar como evolução separada da `xpz-llm-delegate`, com self-tests e paridade no `09`/`SKILL.md` se algum contrato mudar.

## Estender a detecção de limite de uso (HTTP 429) do provider aos adapters de delegação irmãos

- **Importância** — média (mesmo atrito que custou horas numa pré-push reforçada, mas agora coberto só na rota síncrona do opencode). O `scripts/Invoke-OpenCode.ps1` já **diagnostica o 429 no timeout** lendo o log do opencode via `Get-OpenCodeUsageLimitError` (em `scripts/OpenCodeStreamSupport.ps1`, dot-source, com `-LogDir`) — ver `CHANGELOG`. Falta o mesmo para: (a) **jobs opencode** `Start-OpenCodeJob.ps1`/`Watch-OpenCodeJob.ps1` (mesmo log do opencode; o watcher classifica `finishReason` mas **não** diagnostica o 429 — quando a cota estoura, o job assíncrono também mascara); (b) **outros backends** — `Invoke-Codex`/`Start-CodexJob`, `Invoke-Gemini`, `Invoke-Copilot` — que têm logs/retries próprios.
- **Maturidade** — pronta para implementar no caso **opencode-jobs** (reusar o `Get-OpenCodeUsageLimitError` já compartilhado, com o `-SinceTime` do início do job; self-test análogo ao `Test-OpenCodeUsageLimitDetectionSelfTest.ps1`). **Ideia/pesquisa** para os demais backends: depende de descobrir **onde** Codex/Gemini/Copilot expõem o 429/limite (stderr? log próprio? silêncio como o opencode?) — e Gemini/Copilot **não têm assinatura nesta máquina** para reproduzir o caso real.

**Origem:** frente da detecção de 429 no `Invoke-OpenCode` (2026-06-21), nascida de uma pré-push reforçada em que 3 modelos `ollama-cloud` (kimi/minimax/glm) "estouraram timeout" sem causa visível — era a **cota semanal** esgotada da conta ollama-cloud. Deixado como follow-up para não bundlar na frente do `.ContainsKey`.

## Reclassificar mecanicamente `failureAfterText` do Claude Code no painel

- **Importância** — baixa-média. O campo `failureAfterText` do `<GUID>.result.json` (backend claude-code, 2026-07-25) marca que o job produziu texto **e depois** falhou — tipicamente esgotamento de turno —, ou seja, que o parecer pode estar truncado. No painel, o Claude Code passou a usar `Invoke-ClaudeCodeAsync.ps1` via `Invoke-LlmDelegatePanelDispatch.ps1` (2026-07-29): o sidecar tipado já impede aceitar stdout em timeout, encerramento sem terminal válido ou falha de limpeza sensível. Ainda resta a política de decisão: quando houver texto aceito com evidência residual de truncamento em `failureAfterText`, a decisão sobre aproveitar o parecer continua na reclassificação **pós-hoc humana** do `15` (`responded`→`noResponse`). «Registrado no sidecar/ledger» não é «impedido por política».
- **Maturidade** — ideia, agora reescopada. O consumidor natural continua sendo o orquestrador/closeout da revisão por pares, não o adapter síncrono: a frente de 2026-07-29 já fechou a mudança de transporte do Claude Code no painel e o contrato tipado mínimo. O que falta decidir é se `failureAfterText` deve virar sinal mecânico de `noResponse`, ressalva obrigatória no recibo, ou apenas critério de triagem humana com exposição mais visível.
- **Não** transformar em bloqueio automático sem essa decisão: um parecer com texto parcial ainda pode ser utilizável, e recusá-lo mecanicamente derrubaria respostas legítimas.

**Origem:** revisão pré-push reforçada de 2026-07-25, ao fechar o gap encadeado do caminho assíncrono (ver `historico/IdeiasImplementadas_202607.md`). Apontado na triagem como limite consciente da correção: o campo fecha a perda de evidência, não a decisão.

**Relacionado:** «Detecção de truncamento fora do opencode (paridade dos adapters stdin/JSONL)» abaixo (contrato de saída tipado dos adapters restantes); `scripts/Invoke-ClaudeCodeAsync.ps1`, `scripts/ClaudeCodeCliSupport.ps1`, `scripts/Watch-ClaudeCodeJob.ps1`, `scripts/Invoke-LlmDelegatePanelDispatch.ps1`; `15-revisao-por-pares.md`.

## Preservar mais evidência quando o `claude` sai `1` sem saída classificável

- **Importância** — baixa-média. Em 2026-07-26, uma chamada real `Invoke-ClaudeCode.ps1 -Message "responda OK" -Tools "" -TimeoutSec 60` retornou `exit 1` sem resposta e sem `stderr` capturado, durante janela em que o limite de 5 horas do Claude Code estava zerado. Esse contexto operacional deve ser preservado, mas a causa permanece **não classificável** pela evidência disponível: a documentação oficial do Claude Code não publica uma tabela geral de exit codes para `claude`/`claude -p`, e a própria referência de erros diz que `code N` sozinho não informa o que falhou.
- **Maturidade** — ideia curta. O `SKILL.md` agora registra o glossário operacional baseado em menções oficiais (`0` sucesso; `1` falha genérica quando sem causa textual; `2` bloqueio de hook, não contrato geral do `claude -p`; `137` processo morto/kill/OOM em contexto de instalação). Falta decidir se o adapter deve enriquecer o `BLOCK` opaco com versão, cwd, argv sanitizado, existência/tamanho dos arquivos temporários, `claude auth status`/`claude doctor` opcional, ou outro caminho oficial de log, sempre sem inferir causa pelo número.
- **Não** mapear `exit 1` para quota/limite/auth/workspace/modelo sem sinal textual ou fixture oficial. A melhoria é de **observabilidade**, não de classificação por número.

**Origem:** teste operacional solicitado pelo usuário em 2026-07-26 após a frente do falso `workspace-not-trusted` do backend Claude Code.

**Relacionado:** `xpz-llm-delegate/SKILL.md` (backend Claude Code, códigos de saída); `scripts/Invoke-ClaudeCode.ps1`; `scripts/ClaudeCodeCliSupport.ps1`; contrato de saída tipado dos adapters na entrada «Detecção de truncamento fora do opencode (paridade dos adapters stdin/JSONL)».

## Variante de prompt read-only para vozes "coder" do painel de revisão por pares (evitar truncamento por tool-calls) — RESOLVIDA E MIGRADA

> Investigação concluída e migrada para `historico/IdeiasImplementadas_202606.md` em 2026-06-23. Truncamento das vozes coder = **não-determinismo de cauda raro** (não cota/429, não orçamento-de-passos, não propriedade fixa "coder=trunca"); corroborado por experimento controlado (12 runs, 4 modelos × 3) que reproduziu 1 truncamento real (`reason=tool-calls`, 28 `tool_use`, sem 429). Correção **implementada**: `-MaxAttempts` (retry-once) em `Invoke-OpenCode.ps1`, já no despacho do painel (`Invoke-LlmDelegatePanelDispatch.ps1`). A "variante read-only por prompt" foi **descartada como solução de truncamento** (`--agent plan` auto-aprova bash); a substância de menor-privilégio foi **implementada** (frente D-min do reviewer-ro, 2026-07-04 — ver `historico/IdeiasImplementadas_202607.md`), restando apenas o eixo de leitura como entrada **ADIADA** abaixo. Gap derivado novo (resposta `stop` quase-vazia escapa do veredito/retry) registrado em entrada própria abaixo.

## Confinar leitura do revisor opencode + liberar em `kb-sensitive`/pasta paralela (eixo de leitura — ADIADO)

- **Importância** — alta (risco de vazamento efetivo de segredo local: arquivos `.env` costumam conter senhas, tokens, chaves de API e strings de conexão; os eixos de execução/escrita e rede por tool já foram fechados, mas a leitura dentro do cwd ainda pode expor segredo ao modelo externo).
- **Maturidade** — pronta para implementar para o recorte `.env`; pesquisa/ideia para o restante do eixo de leitura. O bloqueio padrão de leitura fora do cwd **HERDADO** já está **ATIVO** (o reviewer-ro fixa `external_directory: deny`, medido nos fixtures ativos em 1.17.20), sem proteger segredos dentro do próprio cwd; falta **mecanizar cwd-seguro**, **blindar `.env`/segredos locais dentro do cwd** e **liberar `kb-sensitive`**.
- **Já fechado (frente D-min, 2026-07-04):** default `-Agent reviewer-ro` + guard fail-closed nos adapters opencode; execução/escrita (`bash`/`edit`) e rede (`webfetch`/`websearch`/`task`) negadas; leitura fora do cwd herdado bloqueada por padrão, sem prometer isolamento absoluto. Detalhes e correção de premissas (`permission: deny` ≡ `tools: false`; leitura **não** é machine-wide) no histórico.
- **Durabilidade da contenção — medida em 2026-08-16 (garantia, não gap):** o catch-all `"*": deny` do frontmatter do `reviewer-ro` **absorve permissão que ainda não existia** quando o agente foi escrito. Evidência: entre o opencode **1.17.20** (**62** regras resolvidas) e um fork com superfície bem maior (**204** regras), surgiu a permissão `skill` — inexistente no opencode — e desapareceu `plan_enter`, e ainda assim o allow-set resolveu **idêntico**: `{glob, grep, list, read}` com `external_directory[*] = deny`, com `Get-OpenCodeReviewerRoBlockFromAgentList` e `Resolve-OpenCodeReviewerRoAllowSet` rodando **sem alteração**. Consequência de desenho: **nunca** trocar o catch-all `"*": deny` por lista explícita de negações — é ele que faz a contenção sobreviver ao CLI ganhar ferramentas novas entre versões. Serve de resposta antecipada a «o `reviewer-ro` ainda contém depois do upgrade?»: contém, **desde que** o catch-all continue lá.
- **Urgente — `.env` dentro do cwd:** a captura 1.17.20 mostra que o OpenCode passou a trazer regras nativas `read "*.env" -> ask` e `read "*.env.*" -> ask`; o bloco posterior do `reviewer-ro` adiciona `read "*" -> allow`. **Confirmado por medição em 2026-08-16 — não é mais hipótese:** resolvendo o bloco do `reviewer-ro` com `Resolve-OpenCodeReviewerRoAllowSet`, a **última** regra que casa um caminho `.env` é `read "*" -> allow` (posição **[51]** de 62 no opencode **1.17.20**), **depois** de `*.env -> ask` em **[47]** e `*.env.* -> ask` em **[48]**; por `last-match-wins`, a proteção nativa **é anulada**. O mesmo padrão, nas mesmas posições relativas, apareceu no fork `mimo` 0.1.12 (**[103]** e **[99]** de 204) — ou seja, é traço **estrutural herdado do upstream**, não acidente de uma versão; o fork em si foi descartado (`998-ideias-descartadas-e-porque.md`), mas a medição vale como confirmação independente. Arquivos `.env` normalmente guardam segredos locais (`DATABASE_URL`, `API_KEY`, `OPENAI_API_KEY`, `JWT_SECRET`, senhas SMTP etc.) e são justamente o tipo de arquivo que não deve ser lido por um revisor externo. Frente curta a implementar: decidir se o `reviewer-ro` deve preservar/bloquear `*.env`/`*.env.*` (mantendo `.env.example` legível), ajustar frontmatter/guard/fixtures/self-test, documentar a decisão e recapturar evidência. Até lá, tratar revisão opencode em cwd com `.env` como risco alto.
- **Segue ADIADO após o recorte urgente:** (a) **mecanizar cwd-seguro** — o bloqueio padrão é relativo ao cwd HERDADO, mas escolher um cwd sem segredos **não-versionados** (logs, cache, credenciais locais além de `.env`) é responsabilidade **operacional** de quem dispara; não há BLOCK por cwd em `public`. Mecanizar = read-containment por allowlist de paths / validação do cwd antes do despacho. (b) **liberar opencode em `kb-sensitive`/pasta paralela** — hoje `unavailable` (`Invoke-LlmDelegatePanelDispatch.ps1`); depende de (a) + provisão project-local do `reviewer-ro` na pasta paralela (dono natural `xpz-kb-parallel-setup`).

**Origem:** recorte **adiado** da frente least-privilege do revisor opencode (D-min), congelada por revisão por pares (8 rodadas / 4 famílias) e **implementada** em 2026-07-04. Ver o histórico.

## `xpz-skills-setup` oferecer instalar o agente `reviewer-ro` do OpenCode (resolução ativa do gap)

- **Importância** — média (fecha a lacuna operacional do provisionamento **global** do revisor opencode; hoje o `reviewer-ro` só está garantido **project-local** na raiz do repo, e de outros cwd o guard cai em fail-closed `static` até o `opencode.jsonc` global ser migrado).
- **Maturidade** — ideia (decisão do usuário 2026-07-04: **opção B** — a `xpz-skills-setup` deve ser a dona operacional da instalação, não só auditar). O **script** `scripts/Install-OpenCodeReviewerRoAgent.ps1` já existe (dono `xpz-llm-delegate`; edição JSONC localizada, migra o interino `tools:`→`permission`; testado por `Test-OpenCodeReviewerRoSelfTest.ps1`). Falta a **fiação na `xpz-skills-setup`**: no fluxo «audita → oferece resolver», detectar ausência/deriva do `reviewer-ro` no `~/.config/opencode/opencode.jsonc` e **oferecer invocá-lo após confirmação explícita** (padrão do passo 9 do `WORKFLOW`, análogo ao `Install-CursorGlobalInstructionsMcp.ps1`), sem edição silenciosa.
- **Recorte:** a frente D-min (implementada) deixou na `xpz-skills-setup` **só** a auditoria read-only (cita o instalador como dependência). Esta entrada é a **extensão para resolução ativa** — provavelmente + um check de presença/deriva e um passo de oferta no `WORKFLOW`, com paridade em `09` se nascer contrato novo.

**Origem:** decisão do usuário (2026-07-04) ao fechar a frente least-privilege do revisor opencode — «deixar o trabalho [de instalação global] para a `xpz-skills-setup`» (opção B).

## Registro de backend novo na `xpz-llm-delegate` — pontos incompletos e sem gate

- **Importância** — média (não quebra nada hoje; morde no **próximo** backend, e de forma **silenciosa**: um ponto de registro esquecido não falha com erro, só deixa de valer).
- **Maturidade** — ideia (dois achados colaterais medidos em 2026-08-16, ao conferir a superfície de um plano de backend que acabou descartado — ver `998-ideias-descartadas-e-porque.md`).

**Gap 1 — o dispatcher tem QUATRO pontos de registro, e o quarto não é coberto por documento normativo NEM por teste.** Além de `$AdapterScript`, `$ExeParam` e `$ContentionKeys`, existe **`$AdapterDefaultTimeoutSec`** em `scripts/Invoke-LlmDelegatePanelDispatch.ps1` (todos os backends ativos têm entrada lá). Um backend registrado nos três primeiros e ausente no quarto **não** falha ruidosamente — apenas não tem timeout próprio. Nenhum documento normativo ou checklist de skill enumera os quatro.

E a **única outra menção ao símbolo no repositório é uma cópia defasada** (medido 2026-08-17): o probe de `Get-FallbackDispatcherTimeoutMs` em `scripts/Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1` **redefine** o mapa à mão com **cinco** backends — sem `antigravity`, ativo no dispatcher desde `2e80a70` — e valida a função contra os próprios números que escreve (`300`→`330000`, `180`→`210000`). Consequência: mudar um default no dispatcher **não** torna o self-test vermelho. Não quebra nada hoje (a sonda só exercita `claude-code` e `opencode`), mas é uma **enumeração-gêmea subconjunto próprio** — a mesma classe que o `Test-PrePushGateEnumerationParity.ps1` persegue —, logo **evidência viva deste gap, não cobertura dele**. Corolário de desenho: um «self-test equivalente do dispatcher» precisa **derivar** do mapa real; recriá-lo à mão reproduz o defeito que se quer travar.

**Gap 2 — `$ContentionKeys` copiado de um CLI para outro envelhece mal.** A lista de chaves recusadas é específica da **superfície de flags** daquele CLI, e forks/versões novas ganham flags próprias. Medido: um fork do opencode trazia `--never-ask`, `--trust` e `--no-auth`, inexistentes no opencode, nenhuma delas coberta por um `$ContentionKeys` copiado. Corolário: ao registrar backend novo (ou ao subir a versão de um existente), a lista precisa ser derivada do **`--help` daquele CLI naquela versão**, não herdada por analogia. Registrar também a equivalência já observada — `--dangerously-skip-permissions`/`--yolo` do fork é o **mesmo** que `--auto` do opencode, com descrição literalmente idêntica —, para não contar como risco novo o que é a mesma flag renomeada.

**Casa da mecanização do Gap 1:** a entrada «Centralizar a fonte de verdade do conjunto de backends/adapters (três níveis)» — **nível 3** — já prevê `Test-PrePushBackendEnumerationParity.ps1` a partir do código. **Não** criar um segundo gate só para os quatro mapas. O Gap 1 é **invariante a absorver** nesse desenho (paridade de chaves entre `$AdapterScript` / `$ExeParam` / `$ContentionKeys` / `$AdapterDefaultTimeoutSec`, ou self-test equivalente do dispatcher). Escopos distintos: o nível 3 pega defasagem **doc ↔ conjunto de backends**; este Gap 1 pega registro **incompleto dentro do dispatcher**.

**Direção do Gap 2 (ortogonal ao gate de enumeração):** nota normativa no `SKILL.md` de que `$ContentionKeys` se deriva do `--help` da versão, nunca por cópia — pode sair antes do nível 3, sem mecanizar.

**Origem:** achados colaterais da re-verificação empírica de 2026-08-16 que levou ao descarte do backend `mimo`. Sobreviveram ao descarte por serem independentes daquele backend — valem para qualquer motor futuro.

## Piso de diversidade subconta em provedor agregador — `nvidia/*` sem o tratamento que `antigravity/*` já tem

- **Importância** — alta (o piso de diversidade é **gate mecânico** da revisão por pares: subcontar família **reprova painel legítimo**, e pode levar o orquestrador a incluir voz desnecessária ou a concluir que não há diversidade quando há).
- **Maturidade** — pronta para implementar no recorte `nvidia/*` (o precedente idêntico já está resolvido no código); decisão em aberto para os demais agregadores.

**O defeito.** O [`15-revisao-por-pares.md`](15-revisao-por-pares.md) define família como **fundação estrutural do modelo** — linhagem, não provedor — e `Get-LlmDelegateTargetFamily` (`scripts/LlmDelegateTargetFamilySupport.ps1`) já trata `antigravity/*` como agregador, colapsando na fundação do modelo subjacente (`antigravity/claude-*` → `anthropic`). O provedor **`nvidia` é agregador igual e não recebeu esse tratamento**. Medido em 2026-08-16:

```
nvidia/minimaxai/minimax-m3              -> nvidia
nvidia/z-ai/glm-5.2                      -> nvidia
nvidia/nvidia/nemotron-3-super-120b-a12b -> nvidia
```

São **três fundações distintas** (MiniMax, Z.ai/GLM, NVIDIA Nemotron) contadas como **uma**. Um painel formado só por elas falharia o piso de ≥2 famílias sendo, de fato, três linhagens independentes.

**Por que o fix é barato neste recorte.** O catálogo NVIDIA já nomeia `nvidia/<criador>/<modelo>`, então a linhagem é o **segundo segmento**: `nvidia/deepseek-ai/*` → `deepseek-ai`, `nvidia/meta/llama-*` → `meta`, `nvidia/openai/gpt-oss-*` → `openai`. Mesma forma do fix do `antigravity`.

**Paridade obrigatória ao implementar** (lista completa — não só self-test + `15`):

- `scripts/LlmDelegateTargetFamilySupport.ps1` (synopsis/description + ramo `nvidia`)
- `scripts/Resolve-LlmDelegatePanelDiversity.ps1` (cabeçalho `.DESCRIPTION`: hoje lista `nvidia` como família de prefixo e só cita colapso de `antigravity/*` — **passaria a mentir** após o fix)
- [`15-revisao-por-pares.md`](15-revisao-por-pares.md) (definição de família / exceção de agregador)
- `scripts/Test-LlmDelegatePanelDiversitySelfTest.ps1` (casos `nvidia/<criador>/*`)
- `xpz-llm-delegate/SKILL.md` — **duas** coisas: (a) bullet de `Resolve-LlmDelegatePanelDiversity` / `Get-LlmDelegateTargetFamily` ganha exemplo `nvidia/<criador>/*` → linhagem; (b) **linha 881 — trocar «famílias» por «caminhos»**. Hoje: «Outras famílias (Codex/Claude Code nativo/nvidia) **não** são afetadas pela cota do ollama-cloud» — mas a lista mistura **backend** (`Codex`), **subagente nativo** e **provedor** (`nvidia`); nunca foi enumeração de família, e é a **única** enumeração concreta do termo no arquivo, contra ~10 usos no sentido estrito do piso (`:71`, `:72`, `:87`, `:88`, `:118`, `:451`, `:488`, `:678`, `:679`, `:685`). Redação-alvo: «Os demais **caminhos** (Codex, Claude Code nativo, provedor `nvidia` via opencode) **não** são afetados pela cota do `ollama-cloud`». O **conteúdo não muda** (segue verdadeiro antes e depois do fix — o provedor `nvidia` não passa pela cota do ollama-cloud); muda o **termo**, que pós-fix contradiria a definição usada no resto do documento. **Revisão de redação, não de contrato.**

**Decisão em aberto — os outros agregadores.** `opencode-go/*` e `ollama-cloud/*` têm **dois** níveis (`opencode-go/glm-5.2`), logo a linhagem **não** é derivável do nome e exigiria mapa mantido à mão, que envelhece a cada modelo novo. Decidir entre: (a) entram no mesmo fix, por mapa; (b) ficam de fora, com a subcontagem aceita e **documentada** como limite conhecido; (c) o schema passa a admitir família estrutural **declarada** por revisor.

**Cuidado de método:** família de **destino** (o provedor, consumida pelo gate de autorização) e família **estrutural** (a linhagem, consumida pelo piso de diversidade) são eixos distintos. O campo `family` do `preferred-reviewers.json` segue sendo o de destino; o fix é no resolvedor do piso, **não** no gate.

**Origem:** achado ao conferir a lista de revisores preferidos em 2026-08-16, depois de o usuário fixar o critério «diversidade de **linhagem**, não de provedor». Precedente: o mesmo modo de falha já corrigido para `antigravity/*`.

## Declarar o nível de esforço de raciocínio por revisor/harness

- **Importância** — média-alta (afeta a **qualidade** do parecer e a **auditabilidade** do recibo: hoje um rebaixamento de esforço é **invisível** — não aparece na preferência nem no recibo mínimo).
- **Maturidade** — ideia (levantamento por fazer; nenhum harness pesquisado além do Codex).

**O problema.** `scripts/Set-LlmDelegatePreferredReviewers.ps1` aceita em `invokeArgs` apenas `backend`, `model`, `profile`, `oss`, `localProvider` e `timeoutSec` — **não há campo para esforço de raciocínio**. Medido em 2026-08-16: o revisor Codex roda em `xhigh` porque o `~/.codex/config.toml` **global** traz `model_reasoning_effort = "xhigh"`; a preferência **não** grava isso. Se esse default global mudar por qualquer motivo alheio ao painel, o revisor passa a opinar com esforço menor **sem aviso**, e o **recibo mínimo** do `15-revisao-por-pares.md` não mostraria a diferença — a rodada pareceria idêntica.

**A levantar, por harness:** como (e se) cada backend expõe nível de esforço — Codex (`model_reasoning_effort`, e se um `[profiles.*]` dedicado torna a preferência auto-contida via o `profile` **já aceito** pelo schema), Claude Code, opencode, Copilot, Gemini, Antigravity. Nem todos devem expor; registrar **quais não expõem** também é resultado útil, para não prometer o que não existe.

**Direção a decidir:** (a) campo novo em `invokeArgs` — exige mexer na **sanitização por desenho** do `Set-`, hoje allowlist estrita, e por isso não é mudança trivial; (b) só convenção — perfil dedicado por harness, referenciado pelo `profile` existente, **sem** tocar no schema; (c) nada no schema, mas o **recibo** passa a registrar o esforço efetivo quando o harness o reporta.

**Origem:** ressalva levantada em 2026-08-16 ao promover o Codex `gpt-5.6-luna` a rank 1 da lista de preferidos — o «Extra alto» escolhido pelo usuário não tinha onde ser gravado.

## Resposta `stop` porém quase-vazia escapa do veredito e do retry (gate de qualidade/aderência ausente)

- **Importância** — baixa-média (ruído **silencioso** no painel: uma voz pode "responder" sem opinar e ainda contar como revisor válido, enfraquecendo a diversidade sem alarme).
- **Maturidade** — ideia (achado empírico; direção em aberto).
- **Achado (experimento controlado 2026-06-23):** o `Get-OpenCodeCompletionVerdict` (`scripts/OpenCodeStreamSupport.ps1`) classifica como `ok` **qualquer** stream que termine em `reason=stop` **com texto não-vazio** — não há piso de tamanho/substância. Observado: `minimax-m3` terminou `stop` com **414 chars** (vs. ~16k da run cheia do mesmo modelo no mesmo pedido). Como o veredito é `ok`, o `-MaxAttempts` **não** re-tenta (só re-tenta `truncated`/`no-completion`) e, no painel, entra como `responded`. É modo de falha **distinto** do truncamento (lá o turno para no meio em `tool-calls`; aqui "termina" limpo sem dizer nada).
- **Hoje:** a única rede é o orquestrador reclassificar para `noResponse` **post-hoc** (`15-revisao-por-pares.md`) — manual e fácil de escapar.
- **Direção em aberto:** heurística de piso (ex.: tamanho mínimo, ou razão texto-final vs. narração) ou checagem de aderência pós-stream. **Ortogonal** ao Achado D e ao `-MaxAttempts` — não confundir com truncamento. Cuidado: piso por tamanho pode gerar **falso-positivo** em parecer legitimamente curto (ex.: "sem gaps").

**Origem:** experimento controlado do truncamento das vozes coder (2026-06-23); gap derivado da frente «variante read-only» (migrada ao histórico). Achado e priorizado por **revisão por pares** (5 vozes / 3 famílias: anthropic nativo, openai/Codex gpt-5.5, ollama-cloud deepseek-v4-pro/glm-5.2/kimi-k2.7-code).

## Formalizar regra de retirada de pendências: reler estado atual + distinção 998 vs histórico

- **Importância** — média (sem a regra, agente propõe destino errado: entrada resolvida vai para 998 em vez do histórico mensal, ou manuscrito é construído sobre visão stale da entrada).
- **Maturidade** — pronta para implementar (lição extraída e validada; falta só gravar no lugar certo).
- **Achado (2026-06-23):** agente construiu manuscrito inteiro de migração ao 998 sem reler a entrada do 999 — que já tinha uma RESOLUÇÃO e pertencia ao **histórico mensal**, não ao 998 (rejeitadas). O painel diverso (5 vozes / 3 famílias) é que pegou a contradição com o estado real da entrada. Dois gaps distintos: (1) não reler o estado atual antes de propor retirada; (2) não distinguir 998 (ideia rejeitada) de `historico/IdeiasImplementadas` (ideia resolvida/implementada).
- **Direção:** adicionar regra curta ao `AGENTS.md` (seção «Revisão pré-push») e/ou à própria «Política de retirada» no topo deste arquivo. Texto candidato: *"Antes de propor migrar ou descartar uma entrada, reler o estado ATUAL da entrada — ela pode já ter RESOLUÇÃO ou estado avançado. Entrada resolvida/implementada vai ao histórico mensal; entrada rejeitada vai ao 998."*

**Origem:** sessão de investigação do truncamento de vozes coder (2026-06-23); erro de processo do agente corrigido pelo painel de revisão por pares.

## Fallback de voz anthropic no painel quando o subagente nativo cai em 529

- **Importância** — baixa-média (atrito real: bloqueou a 4ª voz do painel por ~15 min). O painel de revisão por pares usa o **subagente nativo** (ferramenta Agent) como voz **anthropic**, **fixado no modelo da sessão** (ex.: `claude-opus-4-8`). Quando a API anthropic está sobrecarregada, o spawn falha com **HTTP 529 Overloaded** repetido (observado 2026-06-21: `opus-4.8` deu 529 ×4 seguidos), e **não há fallback** — a família anthropic ficou descoberta até o usuário rodar `opus-4.7` manualmente em outra sessão.
- **Maturidade** — pronta para implementar (a rota já existe). Direção: quando o subagente nativo (anthropic) estiver indisponível por 529, o painel pode despachar a voz anthropic por um revisor `backend=claude-code` com `model=claude-opus-4-7`; no painel, essa rota deve usar o contrato assíncrono `scripts/Invoke-ClaudeCodeAsync.ps1` via dispatcher, não o adapter síncrono. É a mesma família, voz forte, independente do spawn nativo. Formalizar em `15-revisao-por-pares.md` (composição/resiliência) e/ou `xpz-llm-delegate/SKILL.md` (mecanismo). Cuidado: `claude-opus-4-7` casa a chave de destino `anthropic/claude-opus-4-7` (gate por destino inalterado); é voz da **mesma família** do orquestrador, então não substitui diversidade externa — só recupera a voz anthropic do painel. Origem: pré-push reforçada do pacote `.ContainsKey`+429 (2026-06-21); alinhada ao contrato assíncrono do Claude Code no painel em 2026-07-29.

## `Test-PrePushNewTokenPropagation`: não sinalizar termo que já existia em `origin/main` (falso-positivo de "introduzido")

- **Importância** — baixa (consultivo, não bloqueia; mas o ruído custa triagem repetida em toda rodada e por revisor). Na reforçada de 2026-06-21, o gate disparou **16 candidatas** do par `KbMetadataPath`/`BuildResultJsonPath` que **todos** os revisores tiveram de triar como justificadas. O glm-5.2 provou que a **premissa do gate é falsa**: `KbMetadataPath` **já existia** em `origin/main` (não foi "introduzido no diff") — o gate casou a **co-ocorrência** do termo no diff, não a introdução.
- **Maturidade** — pronta para implementar. Direção: antes de sinalizar um termo como "novo/introduzido", o `scripts/Test-PrePushNewTokenPropagation.ps1` confronta o termo contra o **`BaseRef`** (`origin/main`): se o token **já aparece** em `origin/main` (fora do diff), não é novo → não gerar candidata. Reduz falso-positivo sem perder a detecção de termos genuinamente novos. Self-test próprio. Manter consultivo (`warn`). Origem: pré-push reforçada do pacote `.ContainsKey`+429 (2026-06-21).

## Maturar a Fase 2b da rotina pré-push de pasta paralela de KB (Fase 2b da skill `xpz-kb-parallel-pre-push`, hoje classificador documental)

**Importância:** média (o sub-caso **destrutivo** tende a `alta` — falso negativo de regressão por dependente não enumerado; hoje mitigado só pelo build)
**Maturidade:** ideia (decisões de runbook em aberto por `decisao-001`; alguns sub-achados abaixo já são "pesquisa feita")

**Origem:** sessão 2026-06-12, a pedido do usuário. Estudo do experimento incubado em `C:\Dev\Prod\Gx_FabricaBrasil\pre-push-routine` (8 experimentos + `decisao-001`) e coleta de dados **read-only (consulta de fora)** contra o push real pendente da KB FabricaBrasil (10 commits, frente "OperacaoItem — Título Intermediário"). O experimento ainda **não** é referenciado em nenhuma skill nem no `09`.

### O experimento existente (resumo)

Rotina pré-push específica para pasta paralela de KB, em 3 fases: **Fase 1 mecânica** (orquestrador `Invoke-FabricaBrasilPrePushPhase1.ps1`, 11 gates G1–G5/K1–K4/K8/K9/K11, exit codes, `-AsJson`, princípio de delegação — K8/K9 consomem gates canônicos), **Fase 2a estrutural** (parcial scriptada: higiene de frente/pacote + checklist de agente) e **Fase 2b regressão** (deliberadamente **não** scriptada — `decisao-001`). Conclusão empírica dos experimentos 005/006: o cheque **autoritativo** de regressão é o **Specify+Build** (`xpz-msbuild-build`), não a análise estática de XML; o estático é triagem barata antes do build.

### O buraco empírico: perfil estrutural-aditivo

Os 8 experimentos só exercitaram mudança em rules `[web]` (003) e em corpo de Procedure (004-piloto). O perfil **Transaction ganhando atributos via FK de subtype** nunca foi coberto. Caso real estudado: `OperacaoItem` ganha 5 atributos via `SubTypeGroup OperacaoItemTituloIntermediario` (FK a `Pessoa`), todos nullable, **zero removidos**.

### Achados coletados (dados)

1. **Eixo 2 incompleto** [pesquisa feita]: `who-uses(Transaction:OperacaoItem)` = **6** (só BC Load/Save + binding WorkWith); `who-uses(Table:OperacaoItem)` = **14** (navegadores `For each`, relação `navigates_explicit_table`). Os experimentos só consultaram a Transaction. Receita correta para mudança estrutural: **`who-uses(Transaction)` ∪ `who-uses(Table)`** — senão os navegadores `For each` somem do relatório. Prova: `procAtualizaLancamentoItens...` navega `for each OperacaoItem` (linha 197) e **consome os atributos novos** (linhas 264–267), mas é invisível no who-uses da Transaction.
2. **who-uses de atributo recém-criado** retorna só auto-declarações estruturais (Table index member + Transaction level attribute), não consumidores — semântica diferente da dependência-de-consumo que os experimentos assumiram.
3. **Sutileza cabeça-detalhe no F1**: `Operacao.xml` é SAME (descartada pelo filtro) mas é a **cabeça** cujo detalhe mudou; carrega 20 dependentes. "Descartar SAME cedo" está certo para o arquivo, mas o analista não pode concluir que a cabeça está fora do escopo.
4. **Roteamento por perfil de risco**: zero atributos removidos ⇒ o eixo `quebrado`-por-referência-órfã é **no-op por construção**; o esforço migra para o eixo de **omissão**. Sinal mecânico: F1 + "algum `<Attribute>` removido no diff?".
5. **Status novo `suspeito-por-omissão`** [pesquisa feita como heurística]: 11 navegadores da Table, **2 tocados, 9 intocados**. Ranqueados por afinidade de nome ao conceito novo, os 2 de topo (`procAtualizaTituloDaTroca`, `procCompensacaoDeTitulos`) validaram-se como candidatos de domínio **real** (ambos manipulam `Titulo`/`TituloFavorecido`/parte do título). Heurística = **sinal, não ruído** (2/2 checados). **Não** confirmados como bugs — confirmar exige intenção de negócio + dev + build. A shortlist sai de graça do cruzamento `who-uses(Table)` × diff git.
6. **Assinatura mecânica da FK-de-subtype aditiva**: `SubTypeGroup` NEW (mapeando subtipos a supertipos de `Pessoa`) + `Table` ganha índice **`Automatic` Duplicate** sobre as colunas FK + Transaction ganha level attributes nullable. Reconhecível por padrão ⇒ um motor futuro baixa o nível de alarme de quebra automaticamente e redireciona atenção à omissão.

### Direção proposta para a "Fase 2b madura"

Para o caso estrutural, a 2b não é um runbook que dá selo de "sem regressão" — é um **classificador de perfil de risco**:

- Consulta de Eixo 2 = `who-uses(Transaction)` ∪ `who-uses(Table)`.
- F1 + "algum atributo removido?" roteia: **removido** → eixo de quebra (build é autoritativo); **nenhum removido** → eixo de omissão.
- Novo status `suspeito-por-omissão` com shortlist de navegadores intocados ranqueada por afinidade.
- Reconhecimento mecânico da FK-de-subtype aditiva para calibrar o alarme.

### Sub-caso destrutivo (caracterizado em 2026-06-12)

O sub-caso **destrutivo** (atributo removido/renomeado, domínio trocado, chave alterada) — onde o eixo de quebra realmente morde — foi caracterizado por sondagem em atributo estabelecido (`OperacaoItemContaId`, sem mudança real; experimento mental sobre estado atual):

- **Índice cego**: `who-uses(Attribute:OperacaoItemContaId)` = **2**, ambos auto-declarações estruturais (Table index member + Transaction level attribute). O extrator **não modela** "objeto X referencia atributo A no `Source`/conditions".
- **Verdade textual**: **119 ocorrências em 25 arquivos** (~21 objetos consumidores reais: DataSelectors, ~15 Procedures de relatório/lançamento, WebPanels, SDTs).
- Para uma remoção, o `who-uses` reportaria **2 (ambos estruturais = "ninguém")** contra **~21 que quebrariam**. Ponto cego catastrófico.
- **Nem `who-uses(Table)` basta**: os consumidores grep incluem `procRelatorioTitulos*`, `dsRelatoriosDeTitulosViaLancamentos`, `sdtTituloParametros` — **nenhum** deles estava nos 14 navegadores da Table.

**Receita de Eixo-2 para o caso destrutivo** (diferente do aditivo): o enumerador confiável é **grep textual do nome do atributo** (estilo D1, com filtro de comentário `//`), **não** `who-uses`; o veredito de quebra é o **build**. Isso fundamenta, por caminho direto, a conclusão dos experimentos 005/006 de que o build é autoritativo: para remoção/rename de atributo, a análise estática via índice **não enumera** sequer o raio de impacto.

**Assimetria aditivo↔destrutivo** (fato de design central): aditivo → eixo de quebra é no-op, `who-uses(Table)` dá superfície útil + shortlist de omissão (sinal); destrutivo → eixo de quebra morde, `who-uses` cego, só grep+build enumeram/julgam. O roteamento "algum `<Attribute>` removido no diff?" (achado 4) é o que separa os dois regimes.

### Experimento real de rename (2026-06-12, KB `wsEducacaoSpTeste`)

Atributo `DistribuidoraNome` → `DistribuidoraNomeTeste` produzido sob medida pelo dev (rename na IDE + sync). Achado: o rename do GeneXus **propaga perfeitamente** para todo código/estrutura antes do export — **zero órfãos** nos ~7 consumidores. As 27 ocorrências do nome antigo que sobraram no acervo são todas legítimas: variável homônima `&DistribuidoraNome` (variável não renomeia com o atributo), nome do objeto `procDistribuidoraNome`, e o arquivo-resíduo de sync. A única referência ao atributo nu (`procDistribuidoraNome:9`, RHS) foi atualizada para o novo nome.

**Conclusões:** (1) rename **não** é destrutivo — sai do regime; o destrutivo real é **remoção** (delete), sem alvo de propagação — é o que a próxima probe deve testar. (2) **Prova empírica de que grep sozinho dá falso alarme**: o grep ingênuo deu 27 ocorrências/8 arquivos (leitura ingênua = "KB quebrada"), mas a classificação precisa deu **zero órfãos** — só parser/build distinguem atributo nu de variável homônima. Valida o build como autoridade e o `references_attribute` do Plano A (que faria essa distinção que o grep não faz).

**Cross-validação pelo full sync do dev (mesmo episódio):** GUID idêntico nos dois arquivos confirma rename (não delete+add); full export limpo (485 objetos, exitCode=0, sem Categoria B). Dois aprendizados: (a) **detectar** o regime destrutivo é barato — o `-FullSnapshot` acusou o nome antigo como `Extra=1` (reconciliação de full export sinaliza rename/remoção de graça; no incremental, `git diff` mostra o arquivo deletado/criado). O difícil não é detectar, é **enumerar consumidores + veredito** (grep ambíguo, build autoritativo). (b) Gap de tooling **identificado na época e já resolvido**: na verdade **não havia limpeza de resíduo nenhuma** — o sync apenas lançava `throw` em `Extra > 0`, deixando o arquivo de nome antigo como resíduo no acervo (a premissa original da ideia, de que existiria limpeza por GUID cobrindo `<Object>` e ignorando `<Attribute>`, foi corrigida na implementação). **Resolvido** pela frente Sync GUID-aware (`Resolve-GuidAwareRenames` em `scripts/Sync-GeneXusXpzToXml.ps1`), que sob `-FullSnapshot` reconcilia o rename pela identidade `guid` cobrindo **`Attribute` e `Object`** desde a introdução (renomeia o arquivo existente em vez de deixar resíduo); ver `CHANGELOG.md` e `xpz-sync/SKILL.md`.

### Experimento real de remoção (2026-06-12, KB `wsEducacaoSpTeste`) — a IDE bloqueia

Tentar deletar o atributo (`DistribuidoraNomeTeste`) na IDE GeneXus 18 retornou: **"Object(s) could not be deleted: Attribute 'DistribuidoraNomeTeste' is referenced at least by Attribute 'EscolaDistribuidoraNome'. (Artech.Layers.BL)"**. A IDE **bloqueia** a deleção de atributo referenciado (fail-fast no primeiro referenciador — aqui, o subtipo). A probe se resolveu sem sync.

**Implicação (fecha o regime destrutivo):** combinado com a probe de rename (a IDE propaga), o GeneXus **previne estruturalmente os dois caminhos** pelos quais uma mudança de atributo orfanaria consumidores: rename → propaga; delete → bloqueado enquanto referenciado. Para deletar, o dev precisa **remover todas as referências antes** — e nesse ponto os consumidores já foram atualizados, então o diff mostra mudança **coordenada**, não órfão silencioso. O regime destrutivo de "referência órfã de atributo chegando ao acervo" é **essencialmente inalcançável** pelo desenvolvimento normal mediado pela IDE — coerente com os 223 commits sem nenhum caso destrutivo (não só raro: estruturalmente impedido).

**Recalibração honesta do Plano A:** isso **enfraquece a motivação destrutiva** do `references_attribute` (o caso que ele enumeraria é o que a IDE previne). O Plano A mantém valor para **troca de domínio** (dois saltos, não bloqueada) e impacto geral / `who-uses(Attribute)` significativo, mas sua **urgência cai** — reavaliar prioridade à luz disto.

**Nuance aberta (última ponta):** o bloqueio aqui foi por referência **estrutural** (subtipo). Se a guarda da IDE também cobre referência **só em código** (`<Source>`, sem subtipo/transação) é o que falta confirmar; mas a direção está clara e a conclusão central se sustenta.

### Sub-caso troca de domínio (caracterizado em 2026-06-12) — consulta de dois saltos

Sonda em `Domain:Aliquota`: `who-uses(Domain:Aliquota)` = **64**, relação **`based_on_domain`** (Property `idBasedOn`). O índice **cobre** o salto 1 (Domain → atributos baseados nele). Mas o salto 2 (cada atributo afetado → quem o consome e quebraria) **cai no mesmo buraco** do caso destrutivo (consumo de atributo no corpo é cego). Receita = `who-uses(Domain)` para o conjunto de atributos (índice) → por atributo, **grep + build** para consumidores.

### Experimento real de troca de tipo (2026-06-12, KB `wsEducacaoSpTeste`) — build OK, reorg não-backward-compatible

Atributo `ContratoNumero` (que é a **PK** da Contrato) trocado de `Numeric(10)` → `Character(15)` na IDE.
- **IDE:** aceitou salvar **sem bloquear nem avisar** (assimetria com o delete, que bloqueia).
- **Build:** **SUCCESS, zero erro de cast/compilação** — o GeneXus propagou o novo tipo a todos os consumidores e **auto-gerou conversão de dados** (`ContratoNumero.tostring(10,0)`).
- **Database Impact Analysis:** `nfo0003: reorganization not backward compatible` — `ALTER COLUMN ContratoNumero TYPE CHAR(15)`, **DROP/ADD da PK**, e **cascata para a tabela `GuiaPed`** (FK via subtipo `GuiaPedContrato`).

**Conclusão:** troca de tipo (mesmo em PK) **não é risco de regressão de código** — o GeneXus resolve o código e gera a migração. É **risco de schema/dados**: reorg não-backward-compatible em produção. A autoridade é a **Database Impact Analysis / detecção de reorg**, que o `xpz-msbuild-build` **já porta** via `FailIfReorg` (uma troca de tipo dispara `ReorgDetected=true`). Análise estática de XML e o índice **não enxergam** isto.

**Reavaliação cumulativa (4 probes em `wsEducacaoSpTeste`):** aditivo → triagem estática; rename → IDE propaga (não-evento); delete → IDE bloqueia (prevenido); troca de tipo/chave → build + reorg detection (gate já existe). O **build** (Specify + Impact Analysis + `FailIfReorg`) é a autoridade dos regimes estrutural/tipo/chave. A motivação de **detecção de regressão** do Plano A (`references_attribute`) encolhe a cada probe — resta valor de impacto geral / `who-uses(Attribute)` significativo, não de regressão. **Reavaliar a prioridade do Plano A à luz disto.**

### Caracterização precisa do índice SQLite (refinada em 2026-06-12)

O índice **não é cego em bloco** — a cegueira é **estreita e específica**. Cobre bem: objeto→objeto (`calls_procedure`, `navigates_explicit_table`, `loads/saves_business_component`, `formula_*`, `workwith_*`), casas estruturais do atributo (`has_level_attribute`, `has_index_member_attribute`) e **`Attribute → Domain` (`based_on_domain`)**. O **único** buraco material é **"objeto X lê/escreve atributo A no `Source`/conditions"** — relação faltante, não carência ampla.

**Decisão de design A↔B** (em aberto): (A) **melhorar o índice** adicionando relação `references_attribute` (consumo de atributo no corpo) — fecha de uma vez os saltos-2 do destrutivo **e** do domínio; esforço comparável ao fix `fdb4b3f` (Formula-em-Attribute), que é precedente exato do mesmo tipo de extrator; vs (B) **não mexer no índice** e a rotina rotear por ferramenta (`who-uses` objeto / grep atributo / build veredito). Como o buraco é uma única relação estreita e precedente-corrigível, (A) é mais tratável do que parecia. **Preferência do usuário (2026-06-12): (A)** — baixo custo de manutenção do índice e capacidade de atender mais consultas.

**Quantificação do ruído do grep (caminho B) — sonda em `OperacaoItemContaId`, 2026-06-12:** grep ingênuo = 119 ocorrências / 25 arquivos; com word-boundary cai para 102/24 (~17 falsos positivos por substring, ~14%); ~20 ocorrências são linhas de comentário `//`; ~16 são casas estruturais (Transaction 14, Table 1, SubTypeGroup 1), não consumo. Net ≈ 66 referências de consumo real em ~21 objetos. O caminho B exige **dois filtros** (boundary + comentário) e ainda assim devolve "o nome aparece aqui", não "o atributo é consumido aqui" (não distingue leitura de escrita, código de literal). Uma relação `references_attribute` no índice seria **exata** (como `navigates_explicit_table`/`based_on_domain` já são, com linha + evidência). Conclusão: **(A) é a escolha de engenharia melhor, não só aceitável** — endossada pelo usuário.

**Nota de escopo para o extrator (A) — mapa de formas (sondado em 2026-06-12 sobre `OperacaoItemContaId`):**

| Contexto | Forma da referência | Mecânica de extração |
|---|---|---|
| Procedure / DataSelector / WebPanel | `<Source><![CDATA[ código ]]>` | tokenizar código (já existe para `navigates_explicit_table`) |
| SDT member | `<Item><Property>idBasedOn → Attribute:X</Property>` | XPath estruturado — **reusa máquina do `based_on_domain`** |
| WorkWith coluna | `<attribute attribute="GUID-Nome"/>` | XPath (resolver GUID→nome) |
| WorkWith filtro | `<filterAttribute name="X"/>` | XPath estruturado |
| WorkWith condition | `<condition value="X = &amp;... ">` | XPath + parsear código embutido (XML-escapado) |

Dois aprendizados: (a) parte do extrator **reusa máquina existente** (`idBasedOn` para SDT; tokenizer de Source para código) — custo menor que parecia; cobre **mais que `<Source>`**, mesma lição incremental de `122a171`/`fdb4b3f`. (b) Precisão exige distinguir **atributo nu** de **membro de SDT** (`&sdt.X`) de **variável** (`&X`) de mesmo nome — o que grep não faz e parser faz (reforça (A)).

### Caveat de generalização (para promoção a skill)

Tudo hoje é `FabricaBrasil`-hardcoded (gates K8/K9 delegam a wrappers locais; catálogo de padrões aceitos é específico da KB). O padrão de skill (como `xpz-sync`) é **motor compartilhado em `scripts/` + wrappers locais finos** cujos nomes o README local define; o catálogo de padrões aceitos vira arquivo **por-KB**. Esse é o "passo da promoção" que a `decisao-001`/D1 adiou.

### Sub-casos chave e volume (sondados em 2026-06-12) — confirmam, não abrem regime novo

- **Mudança de chave**: `who-uses(Attribute:OperacaoItemId)` (atributo-chave) = 3, todas estruturais (`has_key_attribute`, `has_index_member_attribute`, `has_level_attribute`). Mesma cegueira de consumo do caso destrutivo + 1 relação estrutural; stakes maiores (rippla a tabelas-filhas via FK e a contratos BC). Regime = **destrutivo amplificado**; build essencial.
- **Procedure com muitos callers**: `who-uses(procParametroDinamicoConteudo)` = **204**, todas `calls_procedure` (relação única). Em volume assim, tabela linear é inviável e não há agregação por `relation_kind` (todas iguais) — revisão manual não escala, **o build é o cheque**. Formato de tabela só importa no regime de **baixo volume** (≤~15-20, onde `Transaction ∪ Table` cabe em sub-tabelas).

### Relação com `decisao-001` (reorientação proposta)

A `decisao-001` adiou o runbook 2b até 2 experimentos (003 Transaction + 004 Procedure >10 callers); 003 existe e o dado de >10 callers agora existe (204 em `procParametroDinamicoConteudo`). Ele **dissolve parcialmente a premissa Q1**: "melhor formato de tabela para 10+ dependentes" importa menos que reconhecer **alto volume = território de build**, baixo volume = território de tabela. O eixo de design central que emergiu desta coleta é **(a)** classificar o regime (aditivo / destrutivo / domínio / chave) + **(b)** melhorar o índice (caminho A, `references_attribute`) — **não** o formato de tabela. Proposta: reorientar o critério de desbloqueio do runbook 2b em torno de (a)+(b).

## Plano A — Implementar relação `references_attribute` no índice KbIntelligence

**Importância:** baixa (rebaixada em 2026-06-12 — ver «Reavaliação» abaixo; a motivação de detecção de regressão ficou largamente coberta por IDE+build)
**Maturidade:** tecnicamente pronta para implementar, mas **gatilho reaberto** — decidir se ainda vale, dado que IDE+build cobrem o caso de regressão (ver «Reavaliação»)

**Origem:** diagnóstico da entrada "Maturar a Fase 2b da rotina pré-push..." (2026-06-12). **Ler aquela entrada primeiro** — contém a evidência (índice cego para consumo de atributo no corpo: `who-uses(Attribute:OperacaoItemContaId)` = 2 estruturais vs ~21 consumidores reais; grep como fallback é ~30% ruidoso e impreciso).

**Para o agente da sessão futura:** frente no repositório de skills (`C:\Dev\Knowledge\GeneXus-XPZ-Skills`), motor compartilhado. **Não** precisa setar a pasta paralela; usar a KB FabricaBrasil só como corpus de validação (consulta de fora, read-only).

### Reavaliação após as probes de 2026-06-12 (wsEducacaoSpTeste)

As 4 probes mostraram que a motivação **original** (detecção de regressão) está largamente coberta **a montante**: **delete** de atributo referenciado é **bloqueado pela IDE**; **rename** é **propagado pela IDE**; **troca de tipo/domínio** (mesmo em PK) é pega pela **Database Impact Analysis / `FailIfReorg`** do build. Logo, usar `who-uses(Attribute:X)` para "impacto de remoção/rename/troca-de-domínio" é, na prática, **redundante com IDE+build**. **Valor remanescente** do `references_attribute`: consultas de **impacto geral** (tornar `who-uses(Attribute)` significativo para exploração/triagem) — um nice-to-have, **não** segurança contra regressão. Decidir se vale implementar à luz disto antes de tratar como "pronta".

### Objetivo

Adicionar ao extrator a relação **`references_attribute`** ("objeto X referencia atributo A no corpo/estrutura"). Hoje o índice modela só as casas estruturais do atributo (`has_level_attribute`, `has_key_attribute`, `has_index_member_attribute`) e `based_on_domain` — não o consumo. Isso torna `who-uses(Attribute:X)` cego ao consumo no corpo — útil para **impacto geral**; para **regressão** de remoção/rename/troca-de-domínio, ver «Reavaliação» (IDE+build cobrem).

### Arquivo e âncoras (estado em 2026-06-12)

`scripts/Build-KbIntelligenceIndex.py`:
- `EXTRACTOR_SIGNATURE_VERSION` (linha ~42) — em 2026-06-12 era `"6"`; **atualização 2026-06-24:** já está em `"7"` (frente de export legado GX9); **atualização 2026-07-03:** o valor `"8"` foi consumido pela frente de objetos gerados por Pattern no KbIntelligence; **atualização 2026-07-16:** o valor `"9"` foi consumido pela frente de chamadas de `Procedure` resolvidas por inventário real; **atualização 2026-07-27:** o valor `"10"` foi consumido pela cobertura de `WorkWith` mobile nos mesmos extratores de relações de `WorkWithForWeb`, preservando `source_type`; **atualização 2026-07-31:** o valor `"11"` foi consumido pela cobertura de `Procedure.Link(...)` em `Source`/`Formula` e em parâmetros de action `WorkWithForWeb`. Portanto, **esta** frente futura (`references_attribute`) deve usar o próximo bump material disponível quando for implementada, não presumir `10→11`. O bump muda `extractor_signature_version`, e **qualquer edição no `.py` muda o hash SHA-256 dos bytes** (também parte da assinatura). O gate canônico `Test-*KbIndexGate.ps1` **lê a assinatura** (via `GeneXusKbIntelligenceExtractorContract.ps1`) e **bloqueia com `BLOCK:`** quando a metadata do índice diverge do motor (ver `scripts/README-kb-intelligence.md:124-125` e `xpz-kb-parallel-setup/examples/Test-KbIndexGate.example.ps1:122-132`); o que o gate **não** faz é **executar** o rebuild. Logo: **rodar o rebuild explicitamente** após editar o extrator. (A instância local `Test-FabricaBrasilKbIndexGate.ps1` está **defasada** — sem o check de assinatura; wrapper stale, não o contrato canônico.)
- Cada `def extract_*` devolve `list[Evidence]` com `relation_kind` e é registrado; espelhar:
  - **Código em `<Source>`**: `extract_source_for_each_explicit_table_evidence` (~728, `navigates_explicit_table`) — reusar o tokenizador de Source/CDATA.
  - **idBasedOn**: `extract_attribute_idbasedon_domain_evidence` (~1577, `based_on_domain`) + regex `idBasedOn` (~96). O value pode ser `Domain:X` **ou** `Attribute:X` (membro de SDT é `Attribute:OperacaoItemContaId`). Hoje filtra Domain; **estender** para emitir `references_attribute` quando o value for `Attribute:` — quase uma extensão, não código do zero.
  - **WorkWith**: `extract_workwith_condition_evidence` (~1263), `extract_workwith_condition_attribute_evidence` (~1302) — estender/criar para `<attribute attribute="GUID-Nome"/>` (coluna), `<filterAttribute name="X"/>` (filtro), `<condition value="X = &amp;...">` (código XML-escapado).

### Escopo de contextos

Ver a tabela "mapa de formas" na entrada "Maturar a Fase 2b..." (seção "Nota de escopo para o extrator (A)"): Source code (Procedure/DataSelector/WebPanel), SDT idBasedOn, WorkWith coluna/filtro/condition. Cobre **mais que `<Source>`**.

### Precisão exigida

Distinguir **atributo nu** (`OperacaoItemContaId`) de **membro de SDT** (`&sdt.OperacaoItemContaId`) de **variável** (`&OperacaoItemContaId`) de mesmo nome. Só atributo nu (e membro de SDT via idBasedOn) é `references_attribute`. Em `<Source>`, identificador precedido de `&` é variável/SDT-member, não atributo nu — os extratores de Source já fazem essa distinção para navigates/calls; reusar.

### Precedentes (mesma natureza)

`122a171` (Transaction/API/DataSelector em INDEXED_SOURCE_TYPES), `ad69de79` (`WebComponent.Create`), **`fdb4b3f`** (Formula em Attribute — precedente mais próximo: novo extrator + bump de assinatura).

### Validação (caso canônico reproduzível)

Após implementar + rebuild:
- `who-uses(Attribute:OperacaoItemContaId)` deve saltar de **2** para **~21 consumidores** — incluindo `dsRelatoriosDeTitulosViaLancamentos`, `procRelatorioTitulosPor*`, `sdtTituloParametros`, `WorkWithWebOperacaoItem`, `procAtualizaLancamentoItens...` (os mesmos que o grep textual achou e o índice não).
- Conferir que **variável** homônima **não** gera falso positivo.
- O gate canônico **bloqueia** (`BLOCK:`) quando a assinatura do índice diverge do motor, mas **não executa** o rebuild — rodar o rebuild **explicitamente** (`Rebuild-...KbIntelligenceIndex.ps1`) após editar o extrator.

### Decisões fechadas / não fazer

- **Não** usar grep como solução (caminho B descartado).
- `references_attribute` é **aditiva** — não quebrar relações existentes.
- Rodar a rotina pré-push do repo de skills (`13`/`14`) antes de push; paridade doc: `02`, `08`, `09`, `scripts/README-kb-intelligence.md`, `kb-intelligence-guia-metodologico-agente.md` e skills que citam o extrator; entrada no `historico/IdeiasImplementadas_YYYYMM.md` ao mover esta entrada do `999`.

## Plano B — Promover a `pre-push-routine` a skill `xpz-kb-parallel-pre-push` — IMPLEMENTADO E MIGRADO

> Implementado e migrado para `historico/IdeiasImplementadas_202606.md` em 2026-06-15. Lado-repo: skill `xpz-kb-parallel-pre-push` (Fase 1 mecânica + Blocos A/C/D–G), PUSHADO. Lado pasta paralela (Bloco H): adendo de superação na `decisao-001` do experimento da FabricaBrasil + registro global via `xpz-skills-setup`; a `kb-parallel-pre-push.config.json` é dispensável na FabricaBrasil (wrappers locais resolvidos por convenção). A entrada-diagnóstico «Maturar a Fase 2b…» permanece **aberta** acima como direção de pesquisa independente.

## Formalizar o ciclo «Revisão por Pares» (validação de plano por painel multi-modelo) — IMPLEMENTADO E MIGRADO

> Implementado e migrado para `historico/IdeiasImplementadas_202606.md` em 2026-06-17. Estrutura **C pura**: `15-revisao-por-pares.md` (metodologia genérica, fonte normativa da régua) + `14` como aplicação pré-push + motor `scripts/Build-LlmDelegateCapabilityManifest.ps1` e gatilho de revisão por pares na `xpz-llm-delegate`. Decisões em aberto resolvidas (C pura; manifesto sanitizado dica-de-oferta-nunca-verdade-do-gate; livro-razão opcional em `Temp/`; ponto de autorização = autor classifica + gate por revisor). Resíduos seguem **abertos** como futuros: harness de disparo do painel, backends one-shot (`llm`/`mods`) e personas de revisão.

## Exceção "relay auditável" na oferta de 2ª rodada de revisão por pares (otimização do D2)

**Importância:** baixa (é otimização de custo; o caminho seguro já está adotado e cobre a correção)
**Maturidade:** ideia (a decisão de design foi adiar; a mecânica do marcador auditável fica em aberto)

**Origem:** frente dos 4 achados da revisão por pares, decisão D2, 2026-06-19. Ao sintetizar os pareceres do painel, o agente produz uma versão consolidada do manuscrito (vN+1). A régua atual (`15-revisao-por-pares.md:41`) trata qualquer vN+1 ainda não revisada como **convergência falsa** — exige re-submissão ao painel. O D2 perguntou qual o gatilho da oferta proativa de 2ª rodada no momento da síntese.

**Decisão tomada (opção 1, adotada agora):** *qualquer vN+1 autorada ⇒ oferecer 2ª rodada*. Painel: opção 1 (claude-opus + Codex) venceu opção 2 (minimax + autor); Codex desempatou. Motivo: não afrouxa o `15:41` e não reintroduz julgamento auto-interessado do agente no ponto vulnerável (declarar convergência).

**O que esta frente futura faria (a otimização adiada):** introduzir uma exceção em que uma vN+1 de **mero relay** (só agrupa/numera/marca convergência, sem acrescentar nada) **dispensa** a re-submissão, separando-a de uma **consolidação autoral** (que acrescenta afirmação que nenhum revisor escreveu, reordena divergências ou resolve conflito entre ressalvas). Requisitos para ser segura, **não** atendidos hoje:

- **emendar `15-revisao-por-pares.md:41`** para reconhecer a categoria `relay` (hoje a régua não tem exceção);
- **marcador auditável no recibo** (`vN+1Type=relay|authoredConsolidation`), nunca auto-certificado em silêncio;
- **checklist objetivo** (proposta do minimax) — a vN+1 exige 2ª rodada se QUALQUER for "sim": (1) inclui afirmação que nenhum revisor escreveu textualmente? (2) prioriza/ordena divergências de um modo que não estava no painel? (3) resolve um conflito entre ressalvas? (senão: só estrutura/agrupa = relay → dispensa);
- evidência comparável de que a vN+1 não introduziu afirmação, ordenação, resolução de conflito nem prioridade nova.

**Risco a vigiar se for implementada:** a linha relay-vs-consolidação é fácil de o próprio agente racionalizar a seu favor para pular a rodada custosa — exatamente o autoengano que o método quer evitar. Só vale a pena com o marcador auditável e a emenda da norma juntos.

**Rascunho da emenda ao `15:41`** (para a entrada ser auto-suficiente; texto-semente, a refinar quando a frente abrir):

> *Exceção (relay auditável):* uma vN+1 classificada como `relay` — que **apenas** agrupa, numera ou marca convergência, **sem** introduzir afirmação que nenhum revisor escreveu, reordenação de divergências, resolução de conflito entre ressalvas ou priorização ausente do painel — **dispensa** a re-submissão, desde que o recibo registre `vN+1Type=relay` e a classificação seja auditável pelo checklist abaixo. Qualquer vN+1 que falhe uma das perguntas é `authoredConsolidation` e **exige** re-submissão. Na dúvida, `authoredConsolidation`.

**Checklist objetivo** (a vN+1 exige 2ª rodada se QUALQUER for "sim"): (1) inclui afirmação que nenhum revisor escreveu textualmente? (2) prioriza/ordena divergências de um modo que não estava no painel? (3) resolve um conflito entre ressalvas (escolhe um caminho)? — senão, só estrutura/agrupa = `relay` → dispensa.

**Exemplo do marcador no recibo:**

```json
{ "vN+1Type": "relay", "roundId": "<id>", "checklist": { "newClaim": false, "reordered": false, "resolvedConflict": false }, "classifiedBy": "human" }
```

**Relacionado:** `15-revisao-por-pares.md` (régua `:41`); `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1` (onde o estado de re-submissão da vN+1 será mecanizado no Achado A); frente dos 4 achados da revisão por pares.

## Escolha de escopo do painel na revisão por pares (o agente não encolhe o painel sozinho)

**Importância:** média (gap real de metodologia; causou incidente em 2026-06-20 — gap de paridade trilíngue do CHANGELOG quase foi ao push)
**Maturidade:** plano refinado por painel de 6 modelos / 3 famílias (todos «aprovado com ressalvas»); vN+1 consolidada pendente de re-submissão

**Origem:** incidente 2026-06-20. Em pré-push reforçada com `preferred-reviewers.json` de 6 revisores, o agente despachou 2 (piso de 2 famílias), viu «0 gaps até aqui» e PAROU por decisão própria. O usuário mandou consultar os 4 restantes; o único gap real só apareceu no 6º revisor. Parar no piso teria mandado o gap ao push. Causa raiz (catch do minimax): terminação por **convergência intermediária** — 3ª regra implícita que nem o `14`/`15` vedavam.

**O que a frente faria (doc + motor; NÃO é doc-only):**
1. Vedar textualmente a terminação por convergência intermediária: painel só termina em (a) 1º gap *após* o piso atingido, (b) fim do escopo escolhido, (c) falha de comunicação.
2. Usuário decide o escopo: com lista preferida, o agente apresenta composição + opções (inteira / subconjunto / ad-hoc) + custo estimado; recomenda, não decide. Pergunta **depois** dos gates mecânico+semântico e após resolver `ask`/`allow`.
3. Default não-bloqueante = lista inteira (silêncio → inteira, registrado `scopeSource`); nunca cair ao piso.
4. Subconjunto deve manter ≥2 famílias; abaixo disso rebaixa o rótulo para «segunda opinião (N)». Ad-hoc não conta para diversidade nem dispensa o gate de autorização por destino.
5. Dono normativo no `15` (composição do painel); aplicação pré-push no `14`.
6. Recibo/motor `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1`: campos `scopeDecision`/`scopeSource`/`deviationReason` + enum de estado por preferido (`responded`|`skippedByUserScope`|`skippedByGapStop`|`notReached`|`failedCommunication`|`unavailable`).
7. `defaultScope` opcional em `preferred-reviewers.json` (`full`|`minimumValid`|`manual`) com guarda anti-erosão.
8. Paridade `02`/`08`/`09`/`README`/`xpz-llm-delegate/SKILL.md` + CHANGELOG trilíngue.

**Painel consultado (plano):** Codex (gpt-5.5) + deepseek-v4-pro + kimi-k2.7-code + glm-5.2 + minimax-m3 + síntese Anthropic. RoundId `plan-panel-scope-2026-06-20`; `vNextState=pendingResubmission`.

**Parcialmente implementado (2026-06-20):** a proibição de **enquadrar custo/latência do painel** para reduzi-lo a subconjunto (a faceta de viés de enquadramento) foi gravada como regra no `xpz-llm-delegate/SKILL.md` (reforço do Achado B); o restante do mecanismo de escolha de escopo (apresentar opções e deixar o usuário decidir, default = lista inteira, recibo de escopo) segue **aberto**.

**Relacionado:** `14-revisao-pre-push-reforcada.md`, `15-revisao-por-pares.md`, `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1`; exceção «relay auditável» acima (otimização distinta da mesma régua); correção do commit `f35bbe5` que motivou.

## Detecção de truncamento fora do opencode (paridade dos adapters stdin/JSONL)

**Importância:** baixa-média (rede de segurança; o vazamento crítico já está fechado). **2026-06-22:** ganhou **consumidor concreto** — o harness `Invoke-LlmDelegatePanelDispatch` (frente A) precisa classificar o resultado de cada revisor sem parsear prosa. Isso move a frente de "rede de segurança" para "há quem consuma", mas a frente A **deliberadamente não bloqueia** nela (ver bullet do contrato estruturado).
**Maturidade:** pesquisa feita (varredura estática concluída; falta teste empírico + eventual código)

**Origem:** frente dos 4 achados da revisão por pares, Achado D / G1-R, 2026-06-20. O D-fix da Fase 1 detecta truncamento (`reason` do `step_finish`) **só no opencode**. A varredura confirmatória dos demais adapters (inspeção **estática** do código em 2026-06-20) concluiu: o **vazamento-do-D** (preâmbulo virar parecer) **não se reproduz** em Codex/Claude Code/Gemini/Copilot — todos entregam a mensagem final canônica (campo terminal nomeado; Copilot por last-wins de stream). O **Antigravity** (backend #6, 2026-08-04) entra na mesma conclusão: entrega a final por campo terminal nomeado (`$json.response`) — ver a varredura por adapter em `xpz-llm-delegate/SKILL.md`. **Mas** nenhum deles detecta **truncamento por limite de tokens** (não há equivalente a `reason=length`) — isso segue verdadeiro.

**Ressalva (2026-07-25/26), espelhando a do `xpz-llm-delegate/SKILL.md` («Detecção de truncamento (Achado D)»).** A conclusão «não se reproduz em Claude Code — entrega a mensagem final canônica» veio de inspeção **estática** e **não vale para o caminho assíncrono em esgotamento de turno**: medido em `claude 2.1.220`, o job morre sem mensagem final canônica e o texto acumulado até ali sai como `finalText` com `status=completed` — parcial entregue como se fosse completo, que é exatamente o vazamento que a frase nega. Mitigado, **não** eliminado: o `<GUID>.result.json` ganhou `failureAfterText`, que registra a falha ocorrida depois de já haver texto; a decisão sobre aproveitar parecer truncado continua na reclassificação pós-hoc do `15`, e consumir esse campo mecanicamente é entrada própria acima («Consumir `failureAfterText` do job claude-code de forma mecânica»). O corte por **limite de tokens** — o objeto desta entrada — continua sem sinal em qualquer adapter não-opencode.

**O que esta frente futura faria:**

- **Plano de teste empírico** (a varredura foi estática, não ao vivo): injetar resposta longa que force corte por limite em cada adapter não-opencode e verificar se a extração devolve parcial como se fosse completo; definir critério pass/fail e registrar versões das ferramentas.
- **Risco residual do last-wins do Copilot:** se o agente reescrever a resposta e a "última" `assistant.message` não for a final canônica, a extração pode errar. Confirmar empiricamente e, se real, ancorar a extração num sinal mais forte.
- **Eventual paridade de detecção:** se algum adapter expuser sinal de término, aplicar verdito análogo ao `Get-OpenCodeCompletionVerdict`; senão, declarar contrato explícito "sem sinal de completude disponível; risco aceito/mitigado por X".
- **Contrato de saída ESTRUTURADO dos adapters (surfado na frente A, `Invoke-LlmDelegatePanelDispatch`, 2026-06-22; reescopado em 2026-07-29):** o Claude Code do painel já ganhou contrato tipado próprio por `Invoke-ClaudeCodeAsync.ps1` + sidecar (`completed`/`timeout`/`quota`/`unavailable`/`internalError`, `resultAccepted`, `failureAfterText`). Nos adapters restantes, falhas ainda chegam majoritariamente como `BLOCK:` em prosa pt-BR ou por sinais estruturais pobres; mesmo o opencode tem `Get-OpenCodeCompletionVerdict`, mas ainda lança truncagem como string. Um consumidor que precise classificar resultado fora do Claude Code fica entre (a) classificar por exit code + stdout vazio/não-vazio e por sentinelas explícitas de infraestrutura, guardando a prosa **crua** no ledger, ou (b) **parsear a prosa de forma ampla** (frágil). A frente futura: dar status de saída tipado aos adapters restantes (`Invoke-Codex`, `Start-CodexJob`, `Invoke-Gemini`, `Invoke-Copilot`, `Invoke-Antigravity` — backend #6, que também devolve falha como `BLOCK:` em prosa — e a rota opencode onde ainda faltar), com verdict machine-readable (`ok|empty|timeout|quota|unavailable|error|truncated` ou equivalente) para o harness e outros consumidores. **Decisão vigente:** não generalizar todos os adapters nesta frente; o Claude Code no painel foi fechado como caso prioritário, e a paridade ampla segue aberta.

**Relacionado:** `xpz-llm-delegate/SKILL.md` (seção «Detecção de truncamento (Achado D)», cobertura por adapter); `scripts/Invoke-Codex.ps1`, `scripts/Invoke-ClaudeCode.ps1`, `scripts/Invoke-Gemini.ps1`, `scripts/Invoke-Copilot.ps1`, `scripts/Invoke-Antigravity.ps1`, `scripts/CopilotCliSupport.ps1`; do caminho assíncrono do Claude Code, `scripts/Watch-ClaudeCodeJob.ps1` e `scripts/ClaudeCodeCliSupport.ps1`; frente dos 4 achados da revisão por pares; frente A (`Invoke-LlmDelegatePanelDispatch`) e `15-revisao-por-pares.md`.

## Implementar `Invoke-LlmDelegatePanelDispatch.ps1` (frente A) — CONCLUÍDA E PUSHADA (origin/main `2e88905`)

**Migrada para `historico/IdeiasImplementadas_202606.md`** (2026-06-22). Harness MECÂNICO de disparo+coleta do painel de revisão por pares (o «harness de disparo» previsto em `15-revisao-por-pares.md:108`), conforme o design convergido v11; implementação convergida por revisão por pares (v1→v2). Resíduos relacionados: «contrato de saída estruturado dos adapters» (consumidor do single-flight automático) **segue aberto** no 999; o eixo **execução/escrita** do confinamento do revisor opencode foi **implementado** (frente D-min, 2026-07-04 — ver `historico/IdeiasImplementadas_202607.md`), restando aberto apenas o **eixo de leitura/cwd-seguro** (ADIADO) e a fiação da `xpz-skills-setup` para oferecer a instalação global do `reviewer-ro`.

## Normalizar a caixa do -VNextState no eco do closeout

**Importância:** muito baixa (cosmético; a lógica do gate já está correta)
**Maturidade:** ideia

**Origem:** frente dos 4 achados, revisão do diff (minimax), 2026-06-20. O `ValidateSet` do `-VNextState` em `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1` é **case-insensitive** (default do PowerShell), então `-VNextState NOTPRODUCED` é aceito. O **gate funciona em qualquer caixa** (o `-eq` do PowerShell também é case-insensitive, então os bloqueios disparam corretamente); o único efeito é o campo `vNextState` no objeto/`receiptAddendum` ecoar a caixa que o chamador passou, em vez da forma canônica.

**O que esta frente faria:** normalizar `$VNextState` para a forma canônica (`notProduced`/`pendingResubmission`/`resubmitted`/`resubmissionDeclinedByHuman`) antes de ecoar/emitir, para um consumidor downstream que faça comparação case-sensitive do JSON não tropeçar. Risco prático hoje ~nulo (o ecossistema é PowerShell, case-insensitive).

**Relacionado:** `scripts/Resolve-LlmDelegatePeerReviewCloseout.ps1`; frente dos 4 achados da revisão por pares.

## Unificar build sob fundação desacoplada (janela vira visualizador plugado)

**Importância:** média
**Maturidade:** pesquisa feita

**Origem:** frente do modo desacoplado de build (`Start-GeneXusKbBuildDetached.ps1`), 2026-06-12. Decisão (b) do usuário: janela visível continua o default; desacoplado é opt-in. Durante a frente, o usuário perguntou se a janela default ganharia proteção contra fechamento acidental — e ela **não** ganha: o paliativo de título/aviso `NÃO FECHAR` em `Watch-GeneXusMsBuildLog.ps1` reduz o acidente humano, mas não impede o fechamento.

### Problema concreto que motiva a ideia

O fluxo de janela visível (default) continua acoplado à console/sessão do agente: fechar a janela ainda derruba wrapper + MSBuild + GeneXus. A frente cobriu o build longo (modo desacoplado opt-in via Tarefa Agendada), mas o default segue tecnicamente frágil para builds curtos.

### Direção técnica proposta

Tornar **todo** build sempre desacoplado por baixo (fundação `Start-GeneXusKbBuildDetached.ps1`), e a janela visível passar a ser apenas um **visualizador** (`Watch-GeneXusMsBuildLog.ps1` lendo `msbuild.stdout.log` + sentinela). Fechar a janela perderia só a visão, nunca o build; reabrir um visualizador reconectaria.

### Por que **não** foi feito agora

Custo: pôr o mecanismo desacoplado (Tarefa Agendada) no caminho mais usado da skill — ainda não comprovado em uso real — arrisca regredir o build comum, hoje confiável; e paga overhead de registro/limpeza de tarefa em todo build, inclusive curtos. Decisão consciente do usuário: introduzir só **depois** que o desacoplado provar valor no uso real, quando deixa de ser código novo no caminho crítico e vira promoção segura.

### Decisões em aberto

- Overhead real da Tarefa Agendada em builds curtos desta skill (medir).
- Fallback quando o registro da tarefa falhar em algum ambiente (voltar à janela acoplada atual?).
- Política/elevação do Task Scheduler no caminho comum.

## Estender o modo desacoplado opt-in ao import real longo

**Importância:** baixa
**Maturidade:** ideia

**Origem:** mesma frente, 2026-06-12. O modo desacoplado foi restrito a `xpz-msbuild-build` (`BuildAll`/`SpecifyGenerate`) por escopo. O import real (`Invoke-GeneXusXpzImport.ps1`) também pode ser longo e tem gate de watcher visível — mais estrito: na **Decisão pós-gates** é obrigatório, sem exceção por justificativa.

### Direção técnica proposta

Avaliar um orquestrador análogo (ou generalizar `Start-GeneXusKbBuildDetached.ps1`) para import real longo, preservando o gate de import — "monitoramento legível obrigatório — janela **ou** sentinela" — sem afrouxar a barragem da Decisão pós-gates.

### Decisões em aberto

- Generalizar o orquestrador existente ou criar um por trilha.
- Como o gate mais estrito da Decisão pós-gates interage com o monitoramento por sentinela.

## Eliminar globalmente o uso de `-AsJson`

**Importância:** média
**Maturidade:** ideia

**Origem:** fechamento da frente de padronização JSON nos wrappers XPZ de pacote, 2026-06-06. A frente já removeu `-AsJson` dos scripts compartilhados de empacotamento, inventário, sanidade e wrappers locais derivados, mas deixou scripts fora dessa frente com contrato humano/JSON próprio.

### Problema concreto que motiva a ideia

O contrato misto `texto humano por padrão` versus `JSON com -AsJson` ainda existe em outros scripts públicos da base. Mesmo que esses scripts não façam parte da frente de empacotamento, a existência de dois padrões mantém risco operacional para agentes:

- tentativa-erro de flag em scripts diferentes;
- parse frágil quando um wrapper espera JSON e outro ainda alterna formato;
- documentação e exemplos precisando explicar exceções;
- chance de wrappers locais em pastas paralelas perpetuarem contratos antigos.

### Ideia de melhoria

Fazer uma frente separada para inventariar todos os `-AsJson` restantes e decidir, script a script, o novo contrato:

1. scripts de motor/automação devem emitir JSON de máquina por padrão no stdout e remover `-AsJson`;
2. scripts que ainda precisem de saída humana devem usar outro contrato explícito, por exemplo `-HumanReadable`, ou ter wrapper humano separado;
3. chamadas internas, exemplos `.example.ps1`, skills e documentos devem ser atualizados juntos;
4. pastas paralelas devem receber wrappers atualizados por `xpz-kb-parallel-setup`, sem promessa de compatibilidade com wrappers locais antigos.

### Decisões em aberto

- Se algum script deve manter saída humana como contrato primário.
- Se `-HumanReadable` vale a complexidade ou se JSON sempre é suficiente.
- Ordem de migração para scripts MSBuild, gates de setup, diagnósticos de runtime e helpers de edição XML.

## LlamaIndex / LangChain + vector store como alternativa ao indice SQLite atual

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** sugestao recebida em 2026-04-25 para exploracao futura.

### Problema concreto que motiva a ideia

Hoje o usuario GeneXus que trabalha com a pasta paralela via agente e obrigado a informar o nome exato do objeto que quer consultar. O custo de um agente varrer ate 15 mil arquivos XML do acervo em `ObjetosDaKbEmXml` sem um nome preciso e proibitivo — em tokens e em tempo. O indice SQLite mitiga isso com triagem estrutural, mas a busca continua dependendo de nome exato ou tipo conhecido.

O efeito pratico: o usuario que nao lembra o nome do objeto nao consegue explorar a KB de forma fluida; precisa saber o que procura antes de perguntar.

### Framework de orquestracao: LlamaIndex ou LangChain

Ambos resolvem o mesmo problema e suportam os mesmos vector stores (ChromaDB, Redis Stack). A escolha e de preferencia de ecossistema:

- **LlamaIndex**: especializado em indexacao e recuperacao de dados; API mais direta para RAG puro; escolha natural quando o unico objetivo e "indexar e buscar".
- **LangChain**: framework mais abrangente (agentes, chains, memoria, ferramentas, RAG); comunidade maior; util se o mesmo framework ja for usado em outras partes do projeto.

Para o caso especifico de indexar XMLs GeneXus e buscar por intencao funcional, ambos chegam no mesmo resultado.

### O que a camada vetorial resolveria

**Busca por intencao funcional**
Com embeddings vetoriais, uma pergunta como "qual procedure atualiza o saldo de estoque mensal?" localizaria o objeto correto mesmo sem o nome exato. O usuario descreveria o que precisa em linguagem natural e o agente encontraria os candidatos relevantes — invertendo a dependencia atual de nomenclatura precisa.

**Contexto recortado (chunking)**
Cada XML de objeto GeneXus pode ser extenso. Em vez de enviar o XML inteiro ao agente, o framework fatiaria em blocos logicos (`Source`, `Rules`, `Events`). A resposta usaria apenas os trechos realmente relevantes, reduzindo tokens e ruido.

**Custo de busca constante**
O vector store organiza vetores matematicamente. O custo de busca nao degrada com o crescimento do acervo.

### Opcoes de vector store

**ChromaDB**
Proposito unico, simples de instalar, disk-first por padrao. Boa opcao para comecar.

**Redis Stack**
Redis com modulo de busca vetorial (RediSearch / HNSW). Open source e gratuito. Nao tem versao nativa para Windows, mas roda sem custo via WSL2 ou Docker Desktop — ambos gratuitos e funcionais no Windows 11 Pro. Com 32 GB de RAM, o custo de memoria e irrelevante: os 15 mil XMLs da KB grande ocupam 180 MB em disco; os embeddings correspondentes ficam estimados em 200-300 MB de vetores (modelo de 1536 dimensoes, ~2,5 chunks por objeto). Redis tem vantagem em velocidade bruta por ser in-memory, e o LlamaIndex ja o suporta como backend nativo.

### Perguntas a responder antes de decidir

- Qual o custo de geracao dos embeddings para o acervo? Precisa de API externa ou modelo local funciona com qualidade suficiente?
- O ganho de descoberta por intencao compensa a complexidade de manter dois indices (SQLite estrutural + vetorial)?
- Adotar LlamaIndex/LangChain + vector store exigiria reescrever os wrappers locais (`Query-*KbIntelligence.ps1`, gate, etc.) em todas as pastas paralelas?
- O chunking por bloco logico do XML (`Source`, `Rules`, `Events`) e viavel dado o formato dos XMLs GeneXus?

## Baseline conhecido no sanity e na revisao de objeto legado

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** ideia discutida em 2026-04-29 e adiada para frente separada.

### Problema concreto que motiva a ideia

Hoje a trilha distingue bem `xmlWellFormed`, `sourceSanityStatus` e os gates minimos de `Source`, mas ainda nao expressa de forma curta e operacional a comparacao entre um delta novo e o XML oficial ja aceito do mesmo objeto.

Em objeto legado grande, isso gera ruido de decisao:

- warning antigo do baseline oficial pode ser lido como defeito novo do delta
- piora nova pode passar despercebida sob o argumento de que "o objeto ja era ruim"
- o agente pode misturar sanidade absoluta do XML com comparacao relativa contra o estado oficial anterior

### Ideia de melhoria

Adicionar, em frente separada, uma camada comparativa explicita e distinta do sanity absoluto, com saidas como:

- `same as official baseline`
- `worse than official baseline`
- `better than official baseline`
- `no official baseline compared`

Essa camada nao substituiria `xmlWellFormed`, `sourceSanityStatus` nem os gates metodologicos atuais. Ela serviria para comparar o delta com o baseline oficial quando houver XML oficial comparavel do mesmo objeto.

### Perguntas a responder antes de decidir

- O que exatamente conta como `official baseline` em cada fluxo: XML oficial atual em `ObjetosDaKbEmXml`, ultimo delta aceito, ou outro marco explicitamente documentado?
- A comparacao deve nascer primeiro como regra metodologica de handoff/revisao, ou ja como evolucao automatizada do `Test-GeneXusSourceSanity.ps1`?
- Como impedir que baseline ruim vire permissao implicita para aceitar piora nova?

## Rename de `kb-source-metadata.md` para `kb-parallel-state.md`

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliacao de resultado de setup em 2026-05-03.

### Problema concreto que motiva a ideia

O arquivo `kb-source-metadata.md` acumula tres responsabilidades distintas: dados de envelope de importacao (blocos `KMW` e `Source` extraidos do XPZ), timestamps operacionais de materializacao (`last_xpz_materialization_run_at`) e, com a adicao de `last_setup_audit_run_at`, timestamps de auditoria de setup. O nome atual descreve apenas a primeira responsabilidade e induz leitura incorreta da funcao real do arquivo.

Nome proposto: `kb-parallel-state.md` — descreve o estado corrente da pasta paralela como um todo, independente de qual dado especifico estiver armazenado.

### Impacto do rename

Alto. O nome atual esta hardcoded em praticamente todos os wrappers locais de cada pasta paralela (`Update-*KbFromXpz.ps1`, `Get-*KbMetadata.ps1`, `Test-*KbIndexGate.ps1`, `Test-*KbStructure.ps1`) e nos scripts do motor compartilhado (`Sync-GeneXusXpzToXml.ps1`, `Test-XpzKbMetadataWrapper.ps1` e outros). Um rename exige atualizar o motor compartilhado, todos os exemplos sanitizados da skill e cada wrapper local de cada pasta paralela existente.

### O que justificaria implementar agora vs. aguardar

Aguardar ate que haja uma frente de refatoracao maior no motor compartilhado ou nos exemplos sanitizados que justifique o custo de migracao em cascata. Nao implementar de forma isolada so por higiene de nomenclatura.

### Perguntas a responder antes de decidir

- Ha outras renomeclaturas de campo ou arquivo pendentes que pudessem ser agrupadas na mesma frente de migracao para amortizar o custo?
- O rename deve ser feito com compatibilidade retroativa (suporte temporario aos dois nomes) ou como corte limpo?

## Tríade de diagnóstico de schema: WriteDatabaseSchema + WriteKnowledgeBaseSchema + CompareSchemas

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de inventário de tasks MSBuild — domínio Database, 2026-05-06.

### Problema concreto que motiva a ideia

Quando uma KB apresenta reorgs inesperadas, erros de impacto ou comportamento anômalo após migração, o desenvolvedor precisa entender se o banco físico está em sincronia com o modelo definido pela KB. Hoje esse diagnóstico depende da IDE. As três tasks permitem fazer essa análise headless, gerando XMLs comparáveis e um arquivo de diferenças.

### Confirmação técnica

Todas as três confirmadas por reflexão do assembly e documentadas em `3908.html`:

- `WriteDatabaseSchema`: lê o banco físico real (via conexão do Environment) e grava um XML com o schema atual. Parâmetro obrigatório: `File` (String).
- `WriteKnowledgeBaseSchema`: lê o modelo da KB (sem acessar o banco) e grava um XML com o schema esperado. Parâmetros: `File` (obrigatório), `DesignModel` (Boolean — `true` = modelo de design, `false` = modelo alvo, default `false`), `SortByName` (Boolean, default `false`).
- `CompareSchemas`: compara os dois XMLs e grava as diferenças. Parâmetros: `DBFile` (obrigatório), `KBFile` (obrigatório), `DiffFile` (opcional — arquivo de saída das diferenças).

`CompareSchemas` **não exige KB aberta** — opera sobre arquivos já gerados. `WriteDatabaseSchema` e `WriteKnowledgeBaseSchema` exigem KB aberta.

### Distinção operacional importante

`WriteDatabaseSchema` conecta ao banco físico (SQL Server, LocalDB). Pode falhar se a conexão não estiver disponível no contexto headless — risco diferente de `WriteKnowledgeBaseSchema`, que opera apenas sobre o modelo da KB. Implementar os dois de forma independente, não acoplada.

### Enquadramento correto de uso

Não é um gate pré-import. Import trata de objetos GeneXus; o schema do banco é alterado por Reorg. O caso de uso real é diagnóstico de estado: "por que minha reorg falhou?", "o banco está alinhado com o que a KB espera?", "qual o impacto de uma migração recente no schema físico?"

### Perguntas a responder antes de decidir

- Um único script combinado (`Test-GeneXusSchemaSync.ps1`) que executa as três etapas em sequência é melhor do que três scripts separados?
- Onde esse script deve ficar: nova skill `xpz-msbuild-db`, ou adicionado como diagnóstico complementar na `xpz-msbuild-build`?
- `WriteDatabaseSchema` exige que o Environment tenha uma conexão de banco válida e acessível no contexto headless? Isso precisa de teste empírico.
- O `DiffFile` de `CompareSchemas` tem formato legível diretamente, ou exige parsing para ser útil ao usuário?

### Limiar para implementar

Implementar quando houver caso concreto de diagnóstico de drift DB-KB que a IDE não consiga resolver de forma conveniente, ou quando o fluxo de `Invoke-GeneXusDbImpact.ps1` precisar de contexto de schema para interpretar o script de impacto gerado.

## DeleteObject — limpeza headless pós-import

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

A skill `xpz-msbuild-import-export` documenta explicitamente no bloco `WWP IMPORT ORDER` que `import_file` não remove objetos antigos automaticamente. A limpeza de Transactions antigas substituídas, SubtypeGroups obsoletos, PatternInstances antigas e Procedures/WebPanels gerados automaticamente é feita hoje de forma manual na IDE.

`DeleteObject` é a task MSBuild oficial que remove objetos da KB. Parâmetros documentados: `Objects` (obrigatório), `IncludeChildren` (true/false, para pastas e módulos), `FailWhenNone` (true/false). Não requer GeneXus Server e não pressupõe estrutura de Team Development.

### Posicionamento

Candidato prioritário entre as tasks do domínio de versionamento. Fecha gap concreto e documentado no fluxo atual da skill, sem exigir nova skill — caberia como extensão de `xpz-msbuild-import-export`.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.DeleteObject` está exposta no assembly `Genexus.MsBuild.Tasks.dll` com as propriedades documentadas (`Objects`, `IncludeChildren`, `FailWhenNone`)
- Definir gate de segurança alto: confirmação nominal por objeto (ou lista) + declaração explícita ao usuário de que não há rollback automático
- Avaliar se o usuário fornece a lista de objetos explicitamente ou se há mecanismo auxiliar para derivá-la (por comparação entre estado pré e pós-import)

### Perguntas a responder antes de decidir

- `Objects` aceita lista separada por vírgula no mesmo formato de `Export`/`Import`, ou tem sintaxe própria?
- `IncludeChildren` é seguro como default `false` ou deve ser proibido sem confirmação explícita adicional?
- O gate deve exigir confirmação por objeto individualmente ou basta confirmação da lista completa?

## CreateVersion — snapshot pré-import de baixo risco

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

Antes de uma importação de XPZ arriscada, criar uma versão frozen da KB serve como ponto de restauração. `CreateVersion` cria uma versão frozen a partir da versão ativa ou especificada. Parâmetros documentados: `VersionName` (obrigatório), `VersionDescription` (opcional), `Parent` (nome da versão pai; `*Trunk` ou nome da KB para raiz). Operação não-destrutiva: apenas cria, não altera nem remove nada.

A alternativa existente para o mesmo problema — cópia da pasta da KB (LocalDB) ou backup `.bak` via SQL Server — não exige task MSBuild, mas também não deixa rastreabilidade dentro da própria KB.

### Condições antes de implementar

- Verificar empiricamente se `CreateVersion` está exposta no assembly com os parâmetros documentados
- Avaliar se o público-alvo da skill usa estrutura de múltiplas versões — em KB local simples sem Team Development, criar versões frozen antes de cada import pode ser overhead sem benefício claro
- Se o public-alvo não usa versões, documentar `CreateVersion` como capacidade disponível mas não recomendar como passo padrão do fluxo

### Relacionamento com RevertToVersion

`CreateVersion` sozinha é de baixo risco. `RevertToVersion` como par de rollback é avaliada separadamente abaixo e depende de análise de perfil de versões da KB.

### Perguntas a responder antes de decidir

- O público-alvo desta skill usa estrutura de múltiplas versões de desenvolvimento (Team Development) ou KB local com versão única (Root)?
- `CreateVersion` com `Parent=*Trunk` cria versão diretamente de Root sem abrir fluxo de merge?

## RevertToVersion — rollback de snapshot, gate muito restritivo

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

Par com `CreateVersion` para o fluxo snapshot+rollback: se o import deu errado, reverter para a versão frozen criada antes. Parâmetro: `VersionName` (obrigatório).

### Risco crítico que bloqueia implementação imediata

A documentação oficial é explícita: `RevertToVersion` **sobrescreve a versão Root com a versão especificada**. Qualquer alteração feita na versão Root após o snapshot é perdida permanentemente. Isso é mais destrutivo que uma importação mal-sucedida.

Consequência para o fluxo XPZ: se o import foi feito diretamente na Root (cenário mais comum em KB local), `RevertToVersion` desfaz o import — mas também desfaz todo e qualquer outro trabalho feito na Root desde o snapshot. Se o import foi feito em versão de teste separada, `RevertToVersion` não desfaz aquela versão de teste — afeta Root.

### Condições antes de implementar

- Dependente de `CreateVersion` estar implementada e em uso real
- Dependente de evidência de que o público-alvo usa múltiplas versões com Root claramente separada do fluxo de trabalho cotidiano
- Gate precisa ser mais restritivo que os gates atuais de importação real: confirmação explícita + listagem das alterações que serão perdidas, se houver mecanismo para derivá-las
- Verificar empiricamente a task no assembly antes de qualquer implementação

### Perguntas a responder antes de decidir

- Há mecanismo headless para listar diferenças entre a versão Root atual e a versão frozen antes de executar o revert?
- O fluxo snapshot+rollback é mais seguro do que a alternativa já documentada (cópia da pasta da KB)?

## RestoreRevision — desfazer cirúrgico por objeto

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Problema concreto que motiva a ideia

`RestoreRevision` restaura um objeto específico para uma revisão específica de sua história. Parâmetros: `Object` (formato `"ObjectType:ObjectName"`), `RevisionId`. Mais cirúrgico que `RevertToVersion`: desfaz apenas o objeto indicado, sem afetar o restante da KB.

### Bloqueio atual

Para usar `RestoreRevision` é necessário saber o `RevisionId` concreto do estado anterior desejado. Não há task headless documentada para listar o histórico de revisões de um objeto. Sem esse mecanismo, o fluxo não é autônomo: o usuário precisaria obter o `RevisionId` manualmente pela IDE antes de invocar o wrapper.

### Condições antes de implementar

- Identificar task ou mecanismo headless que permita listar revisões de um objeto e seus IDs
- Sem esse mecanismo, `RestoreRevision` só seria utilizável como wrapper de conveniência para `RevisionId` já conhecido pelo usuário

### Perguntas a responder antes de decidir

- Existe task headless que liste o histórico de revisões de um objeto GeneXus?
- Se não houver, faz sentido implementar o wrapper mesmo exigindo que o usuário forneça o `RevisionId` explicitamente?

## Leitura da wiki 24612 (Team Development MSBuild Tasks)

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio de Versionamento (Team Development MSBuild), 2026-05-07.

### Motivação

A documentação offline instalada do GeneXus 18 indexa as tasks MSBuild em `3908.html`. O agente externo identificou que a wiki oficial tem página dedicada ao domínio Team Development (`id=24612`) com potencialmente mais tasks que as listadas no índice local.

As tasks avaliadas nesta frente (`CreateVersion`, `RevertToVersion`, `MergeVersions`, `RestoreRevision`, `DeleteObject`) foram analisadas com base nas informações disponíveis no prompt externo. A leitura da wiki 24612 pode revelar tasks adicionais, parâmetros não documentados na instalação local ou restrições de uso não identificadas até agora.

### Condições

- Pesquisa de inventário — não bloqueante para as decisões registradas acima
- Útil antes de qualquer implementação concreta de task deste domínio
- Não requer GeneXus Server: a wiki documenta também o uso local das tasks

### O que buscar na wiki 24612

- Tasks não listadas em `3908.html`
- Parâmetros adicionais de `CreateVersion`, `RevertToVersion`, `MergeVersions`, `RestoreRevision` e `DeleteObject`
- Restrições ou pré-condições de uso das tasks em contexto sem GeneXus Server
- Mecanismo de listagem de revisões de objetos (necessário para `RestoreRevision`)

## RestoreModule — pré-requisito de build para KBs com dependências de módulo

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Módulos (MSBuild Tasks), 2026-05-07.
Documentação oficial confirmada em `46830.html` da instalação local. Task registrada em
`Genexus.Tasks.targets` e mapeada para `Genexus.MsBuild.Tasks.dll`.

### Problema concreto que motiva a ideia

A skill `xpz-msbuild-build` não trata o caso em que a KB tem módulos instalados (AWSCore,
AzureCore, etc.) e esses módulos precisam estar restaurados antes de o build ter sucesso. Sem
`RestoreModule`, o build falha com erro de referência não resolvida — mas o erro parece ser
do XPZ importado, não da ausência de módulo. O agente pode diagnosticar incorretamente a causa.

`RestoreModule` sem parâmetro `ModuleName` restaura a implementação de todos os módulos instalados
na KB a partir do cache local (`%USERPROFILE%\.gxmodules\.cache\`). É o equivalente de `npm install`
antes de `npm build`. Não requer GeneXus Server — funciona com o cache já populado pela IDE
ou pela instalação do GeneXus (servidor `Local`).

### Parâmetros documentados

- `ModuleName` (string, opcional): nome do módulo a restaurar. Se omitido, restaura todos.

### O que justificaria implementar agora vs. aguardar

Implementar quando houver KB concreta com módulos instalados no portfólio onde o build headless
falhe por ausência de restauração. O gate de adição ao pipeline da `xpz-msbuild-build` seria:
verificar antes do build se a KB tem módulos instalados e, em caso afirmativo, executar
`RestoreModule` automaticamente como etapa anterior ao `BuildAll`.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.RestoreModule` expõe `ModuleName` como
  propriedade pública no assembly desta instalação
- Confirmar que `RestoreModule` sem parâmetro opera sobre módulos referenciados pela KB aberta,
  não sobre o cache global
- Definir se deve ser etapa automática do pipeline ou gate explícito com confirmação do usuário

### Perguntas a responder antes de decidir

- `RestoreModule` sem `ModuleName` já é idempotente (não falha se não há módulos)? Ou exige
  que haja ao menos um módulo instalado?
- O cache `%USERPROFILE%\.gxmodules\.cache\` já existe numa instalação limpa com módulos
  instalados pela IDE? Ou precisa de pré-aquecimento headless?
- Qual o comportamento quando o servidor de origem do módulo não está acessível? `RestoreModule`
  falha ou usa o cache existente?

## InstallModule / UpdateModule / GetModulesServer / AddModulesServer — gestão de dependências headless

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Módulos (MSBuild Tasks), 2026-05-07.
Documentação oficial confirmada em `46830.html` e `45933.html` da instalação local. Tasks
registradas em `Genexus.Tasks.targets`.

### Contexto

Módulos GeneXus não requerem GeneXus Server. Funcionam com três tipos de servidor:

- `Directory` — pasta local no sistema de arquivos (sem servidor de rede)
- `Nexus-Maven` / `Nexus-NuGet` — repositórios Maven ou NuGet genéricos (Nexus OSS)
- Servidores pré-configurados: `Local` (módulos da instalação GeneXus) e `Global Matrix`
  (repositório público da GeneXus, visível na IDE em "Manage Module References")

### O que cada task faz

- `InstallModule(ModuleName, Version?)` — instala módulo do servidor configurado na KB aberta
- `UpdateModule(ModuleName, Version?)` — atualiza módulo instalado para versão especificada
  ou mais recente
- `GetModulesServer` — lista servidores de módulo configurados (saída: `Servers`)
- `AddModulesServer(Type, Name, Source, Preserve?, OverwriteDefinition?, User?, Password?)` —
  registra novo servidor de módulos no ambiente headless

### Relevância para o fluxo de KB paralela

`GetModulesServer` é útil como diagnóstico: antes de um `RestoreModule` ou `InstallModule`,
confirmar quais servidores estão acessíveis no contexto headless. `AddModulesServer` com
`Type="Directory"` pode registrar um servidor local (pasta) sem acesso à rede.

`InstallModule` e `UpdateModule` abrem a possibilidade de um pipeline headless de atualização
de dependências: "instalar ou atualizar este módulo de terceiro na KB sem abrir a IDE".

### O que justificaria implementar agora vs. aguardar

Aguardar até que `RestoreModule` esteja implementado e validado. Só então avaliar se o caso
de uso de instalação/atualização headless de módulos aparece no portfólio. O cenário mais
provável de chegada não é importação de XPZ, mas setup inicial de KB de teste que precisa
das mesmas dependências de módulo que a KB de origem.

### Perguntas a responder antes de decidir

- `InstallModule` com `Version` vazio usa a versão mais recente disponível no servidor ou
  a versão especificada no arquivo de dependências da KB?
- `AddModulesServer` com `Preserve=true` persiste a configuração entre sessões MSBuild ou
  apenas para a sessão corrente?
- Em que arquivo ou estrutura o GeneXus armazena a lista de servidores configurados? É por
  KB ou por instalação?

## GetCategoryObjects — seleção de objetos por categoria para Export/Import

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Documentada no índice `3908.html` da instalação oficial.

### Problema concreto que motiva a ideia

Hoje, quando a skill `xpz-msbuild-import-export` faz export ou import com recorte, o
chamador precisa fornecer a lista de objetos explicitamente em `Objects`, `IncludeItems`
ou `ExcludeItems`. Em projetos que usam categorias GeneXus como convenção de organização
("todos os objetos da categoria `Faturamento`", "todos os da categoria `Integrações`"),
o usuário precisa enumerar os nomes manualmente ou extrair a lista de outra forma.

`GetCategoryObjects` retorna a lista de todos os objetos pertencentes a uma categoria.
O fluxo seria: chamar `GetCategoryObjects` com `CategoryName`, capturar a lista
resultante, usá-la diretamente como entrada de `Export` ou `IncludeItems` de `Import`.

### Parâmetros documentados

- `CategoryName` (obrigatório) — nome da categoria GeneXus
- Saída via `<Output TaskParameter="Objects" PropertyName="..."/>` — lista capturável
  em propriedade MSBuild nomeada pelo chamador

### Distinção importante

Categorias GeneXus são agrupamentos organizacionais criados manualmente pelo desenvolvedor
na IDE — diferentes de tipos (`Procedure`, `WebPanel`), módulos e pastas. A task opera
sobre essa classificação visual, não sobre a estrutura interna de tipos.

### Condições antes de implementar

- Verificar empiricamente se `Genexus.MsBuild.Tasks.GetCategoryObjects` está exposta no
  assembly com o parâmetro documentado
- Confirmar que o formato de saída é compatível com `IncludeItems`/`ExcludeItems` de `Import`
  sem transformação intermediária

### Perguntas a responder antes de decidir

- `Genexus.MsBuild.Tasks.GetCategoryObjects` aparece no assembly com `CategoryName`
  como propriedade pública?
- O formato de saída é lista plana de nomes de objeto no mesmo formato que `IncludeItems`
  aceita, ou exige transformação?
- O que a task retorna quando a categoria está vazia ou não existe — falha, lista vazia ou
  `exitCode` diferente?
- "Categoria" aqui corresponde exatamente ao conceito visual da IDE ou a outro agrupamento
  interno do GeneXus?

### Limiar para implementar

Implementar quando houver: (a) reflexão do assembly confirmando a task acessível com os
parâmetros documentados, e (b) caso concreto de projeto que usa categorias como convenção
de organização de objetos, tornando a seleção por categoria mais prática que a lista manual.

## Seleção temporal de objetos salvos para exportação incremental

**Importância:** média
**Maturidade:** ideia (direção identificada; contrato e fontes de leitura ainda exigem validação empírica)

**Origem:** necessidade de exportar por MSBuild apenas objetos da KB nativa alterados desde um instante de corte, quando o exportador aceita lista nominal ou tudo. A disponibilidade de `LastUpdate` no SDK Artech foi observada no plugin FBGxBrain; a IDE também permite seleção por objetos modificados após data/hora. Essas evidências não confirmam, por si, toda a semântica nem o fuso da propriedade.

### Problema concreto que motiva a ideia

O exportador MSBuild seletivo aceita uma lista de objetos, mas não oferece seleção temporal. Sem uma fonte confiável dessa lista, o usuário precisa montar nomes manualmente ou exportar tudo. Isso torna oneroso o fluxo incremental baseado em uma janela de alteração.

### Direção técnica proposta

Criar uma capacidade **somente de leitura** que receba um instante de corte e devolva objetos **salvos** com `LastUpdate >= corte`, prontos para conversão ao formato de lista nominal aceito pela exportação MSBuild.

O primeiro contrato não deve alegar distinguir criação de modificação: deve reportar «alterado desde». Criação entra naturalmente apenas se o microteste confirmar que o primeiro salvamento estabelece `LastUpdate` conforme esperado.

Cada item deve devolver, quando disponível: nome, tipo, módulo, GUID e `lastUpdate`. A resposta também deve declarar o corte recebido, a zona/representação temporal observada e limitações conhecidas.

### Alternativas a estudar

1. **Plugin GeneXus/MCP somente leitura, via SDK Artech** — enumerar `model.Objects.GetAll()` e ler `LastUpdate`. É a rota preferencial se a semântica e a disponibilidade na versão-alvo forem confirmadas.
2. **Script PowerShell ou Python com consultas SQL somente leitura ao banco `GX_KB_*`** — alternativa sem plugin/IDE ativa, condicionada a identificar e validar o esquema interno por versão. Nunca escrever no banco fonte da KB.
3. **Seleção manual na IDE** — referência comportamental e fallback operacional.

As rotas automatizadas devem devolver o mesmo contrato de saída; a escolha não pode ficar implícita no agente.

### Perguntas e gates antes de implementar

- Executar microteste controlado: criar e salvar objeto, medir `LastUpdate`; editar/salvar e confirmar avanço; avaliar rename e objeto não salvo.
- Confirmar precisão, fuso horário e `DateTime.Kind`; aceitar corte RFC 3339 explicitamente e só declarar conversão a UTC após prova.
- Declarar que objetos removidos não aparecem na enumeração de objetos existentes; rename só entra se a operação atualiza `LastUpdate`, até confirmação.
- Validar formato da lista (`Tipo:Nome` ou equivalente) contra o wrapper/exportador MSBuild real, inclusive tipos com nomes de task divergentes.
- Preservar operação somente de leitura: a capacidade seleciona e relata; nunca exporta, importa ou altera KB por conta própria.

### Limiar para implementar

Implementar quando houver uma KB e uma janela real de exportação incremental a automatizar, mais microteste que confirme a semântica operacional de `LastUpdate` na versão-alvo e teste de ponta a ponta que prove que a lista retornada seleciona exatamente os objetos esperados no exportador MSBuild.

### Relacionado

- `xpz-msbuild-import-export/SKILL.md` e `10a-gx-export-task-labels.md`;
- `GetCategoryObjects — seleção de objetos por categoria para Export/Import`, nesta seção;
- `02-regras-operacionais-e-runtime.md` (evidência de seleção temporal pela IDE);
- [Options — Build](https://docs.genexus.com/en/wiki?24030) (dependência de relógio correto em mecanismos de alteração).

---

## CalculateChecksums + AreObjectsEqual — diagnóstico de integridade de objeto pré/pós-operação

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Tasks registradas em `Genexus.Tasks.targets`; **sem documentação oficial em `3908.html`**.

### Problema concreto que motiva a ideia

O fluxo de verificação pós-import hoje depende de `importedItems` (lista de o que entrou),
`exitCode` e varredura de stdout/stderr. Nenhum desses verifica se o objeto que entrou
é de fato diferente do que estava antes, nem se o objeto na KB de destino ficou idêntico
ao objeto da KB de origem. Há um gap de evidência objetiva entre "o import foi executado"
e "o objeto mudou da forma esperada".

### O que cada task faz (hipótese — sem documentação oficial confirmada)

`CalculateChecksums` — calcula checksums de um conjunto de objetos da KB. Potencial uso:
registrar o checksum dos objetos antes do import, recalcular depois, comparar para
confirmar quais mudaram e quais permaneceram inalterados.

`AreObjectsEqual` — compara dois objetos e retorna se são idênticos. Potencial uso:
comparar o estado de um objeto na KB de destino com o mesmo objeto na KB de origem,
ou comparar o estado antes e depois de uma operação dentro da mesma KB.

### Distinção entre as duas

São mecanismos complementares mas de granularidade diferente. `CalculateChecksums` opera
sobre um conjunto de objetos em lote; `AreObjectsEqual` opera sobre dois objetos
comparados par a par. Para o fluxo de verificação pós-import, `CalculateChecksums` seria
mais prático: calcula o checksum do conjunto importado antes e depois da operação.

### Risco adicional desta dupla

Diferente das tasks documentadas em `3908.html`, estas duas são registradas apenas em
`Genexus.Tasks.targets` sem documentação offline correspondente. O risco de comportamento
imprevisível ou interface não estável é maior. A investigação começa pela reflexão do
assembly antes de qualquer uso.

### Condições antes de implementar

- Verificar empiricamente se ambas estão expostas no assembly com propriedades acessíveis
- Para `CalculateChecksums`: qual é a granularidade do checksum? Objeto inteiro ou por
  part-type? A saída é capturável via `TaskOutput`/`CaptureOutput`?
- Para `AreObjectsEqual`: os dois objetos são da mesma KB aberta (dois estados) ou de
  duas KBs distintas? Como se passa o segundo objeto para comparação?

### Perguntas a responder antes de decidir

- `CalculateChecksums` e `AreObjectsEqual` aparecem no assembly com propriedades públicas
  acessíveis?
- `CalculateChecksums` opera sobre a KB aberta no contexto headless corrente ou precisa
  de parâmetro de escopo adicional?
- A saída de `CalculateChecksums` é legível e comparável entre duas execuções, ou é
  representação interna não determinística?
- `AreObjectsEqual` compara objetos da mesma KB ou permite comparar entre KBs distintas?
- O resultado de `AreObjectsEqual` é capturável programaticamente ou apenas emitido em
  stdout?

### Limiar para implementar

Implementar quando houver: (a) reflexão do assembly confirmando ambas as tasks acessíveis,
(b) formato de saída de `CalculateChecksums` legível e determinístico, e (c) caso concreto
de verificação pós-import em que a lista de `importedItems` não for evidência suficiente
de que o objeto mudou da forma esperada.

---

## CompressKB — manutenção da KB após importações de grande volume

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** avaliação de prompt externo sobre domínio Outros (MSBuild Tasks), 2026-05-07.
Arquivo `CompressKB.msbuild` confirmado como presente na instalação oficial do GeneXus 18,
idêntico em todas as instalações inspecionadas (21 linhas).

### Problema concreto que motiva a ideia

Importações de grande volume inserem e atualizam muitos registros no banco interno da KB
(SQL Server ou LocalDB). Com o tempo, o banco pode ficar fragmentado internamente. A operação
`CompressKB` abre a KB com o parâmetro `CompressData='true'` em `OpenKnowledgeBase` e a
fecha — possivelmente acionando compactação ou reorganização interna do banco da KB.

Diferente da reorg do GeneXus (que altera o banco da **aplicação**), `CompressKB` afeta
o banco **interno da KB** — o repositório de objetos, regras e metadados.

### Distinção técnica importante

`CompressData` não é uma task separada — é um parâmetro de `OpenKnowledgeBase`. O arquivo
`CompressKB.msbuild` já é o wrapper pronto entregue pela instalação oficial. A skill não
precisaria gerar um `.msbuild` dinamicamente: apenas invocaria `CompressKB.msbuild` com o
parâmetro `-p:kbLocation=<caminho>`, reusando o arquivo permanente da instalação.

### Condições antes de implementar

- Verificar empiricamente o que `CompressData='true'` faz de fato no banco interno da KB:
  compressão SQL Server (ROW/PAGE), compactação lógica interna do GeneXus ou outro mecanismo
- Verificar se é seguro executar sem confirmação interativa — a operação não importa nem
  exporta objetos, mas altera o banco interno da KB
- Medir o tempo de execução em KBs de médio e grande porte
- Verificar se há efeito colateral ao reabrir a KB na IDE depois da operação

### Perguntas a responder antes de decidir

- O que `CompressData='true'` faz exatamente no banco interno da KB? É seguro executar
  sem confirmação interativa?
- O `CompressKB.msbuild` existente aceita apenas `-p:kbLocation` ou há outros parâmetros?
- Qual o tempo de execução típico em KBs de médio porte (~5.000 objetos)?
- A KB reabre normalmente na IDE após `CompressKB`? Há warning ou efeito colateral observável?
- A operação é idempotente — executar duas vezes seguidas é seguro?

### Limiar para implementar

Implementar quando houver: (a) verificação empírica do efeito real de `CompressData='true'`
confirmando operação segura sem efeito colateral grave, e (b) caso concreto de KB com
degradação de performance pós-import que se beneficiaria da compactação.

## Diagnóstico SQL somente leitura do banco interno da KB para provider/item desconhecido

**Importância:** FALTA AVALIAR
**Maturidade:** FALTA AVALIAR

**Origem:** sugestão recebida de agente externo em 2026-05-10, verificada empiricamente na
mesma sessão contra `GX_KB_wsEducacaoSpTeste`.

**Status em 2026-05-20:** a subfrente conceitual de classificação e comunicação foi registrada em `historico/IdeiasImplementadas_202605.md`. Esta entrada permanece pendente apenas quanto à capacidade operacional de diagnóstico SQL somente leitura.

### Problema concreto que motiva a ideia

As skills XPZ operam sobre XPZ/XML exportados, acervo `ObjetosDaKbEmXml` e índice derivado
SQLite (`KbIntelligence`). Nenhuma dessas camadas cobre o banco interno da KB (`GX_KB_*`
no SQL Server ou LocalDB). Metadados de designer de providers como K2BTools são persistidos
diretamente no banco interno em tabelas como `EntityType`, `Entity`, `EntityVersion` e
`EntityVersionComposition` — e, **no caso empírico que motivou esta entrada** (`FormDesigner` /
`FormDesignerPart` e registros de tipo só no SQL), **não** aparecem como objetos comuns no XPZ.

**Ressalva (2026-08-12):** a frase absoluta «nunca aparecem em XPZ» **não** vale para os tipos
`WebPanelDesigner` (GUID `562b39a3-…`) e `SDPanelDesigner` (GUID `a84e76c6-…`), promovidos ao
catálogo compartilhado como objetos **exportáveis** (`inventoryEligible=true`, evidência em XPZ
da KB `siawk603_P14web_GX18_UP15`; ver `01a` e `CHANGELOG`). Continuam distintos de
`FormDesignerPart` e demais parts internos que seguem só no banco. Os GUIDs cruzam com a
investigação SQL abaixo (bloco `EntityVersion` / `EntityVersionName=WebPanelDesigner` e
`SDPanelDesigner`, mesmo `ProviderId` K2B); o cruzamento é bidirecional — SQL e XPZ.

O risco prático é o **falso negativo**: agente busca `FormDesigner`, `K2B Object Designer`
ou o GUID do provider no XPZ/XML, não encontra nada, e conclui prematuramente que não há
resíduo do K2BTools na KB. No caso real (verificado empiricamente), havia resíduo — 36
entidades `FormDesignerPart` e 3 registros de tipo de designer com `ProviderId` do K2BTools
— mas tudo confinado ao banco interno.

O risco inverso também existe: ao encontrar os registros no SQL, o agente se sentir
autorizado a propor deleção. As tabelas envolvem metamodelo, versionamento e composição
interna da KB. Diagnóstico SQL serve para evidência e suporte; nunca para limpeza direta.

### Contexto empírico verificado — KB wsEducacaoSpTeste (2026-05-10)

**Ambiente:**
- KB: `C:\KBs\wsEducacaoSpTeste`
- Banco: `GX_KB_wsEducacaoSpTeste`
- `knowledgebase.connection`: `<ServerInstance>DESKTOPW11AJRS</ServerInstance>`, `<IntegratedSecurity>False</IntegratedSecurity>`, `<HostName>localhost</HostName>`
- String de conexão que funciona empiricamente: `Server=localhost;Database=GX_KB_wsEducacaoSpTeste;Integrated Security=True;Encrypt=False;TrustServerCertificate=True`
- Nota: o arquivo `knowledgebase.connection` registra `IntegratedSecurity=False` (campo GeneXus próprio), mas o SQL Server aceita Windows auth com `Integrated Security=True` normalmente. A leitura direta do campo `IntegratedSecurity` do XML não deve ser usada para montar a string de conexão sem esse ajuste.

**Achados confirmados empiricamente:**

*EntityType — tipos de designer registrados:*
```
EntityTypeId=155  EntityTypeName=WebPanelDesigner  EntityTypeNamespace=K2BTools
EntityTypeId=156  EntityTypeName=SDPanelDesigner   EntityTypeNamespace=K2BTools
EntityTypeId=161  EntityTypeName=FormDesigner      EntityTypeNamespace=''  (vazio)
```
Importante: `FormDesigner` **não** tem `Namespace=K2BTools`. Uma query que filtre por
`Namespace='K2BTools'` **não** encontrará FormDesigner.

*EntityVersion — registros de tipo com ProviderId do K2BTools:*

Três registros em `EntityVersion` com `EntityTypeId=1` (Root), `EntityVersionId=1`:
```
EntityVersionName=WebPanelDesigner  GUID=562b39a3-dde2-4349-9252-e9e69090c53e  ProviderId=be15a055-f4cc-408a-9218-c71184d2bc61
EntityVersionName=SDPanelDesigner   GUID=a84e76c6-ccf5-4b03-a9d2-7c31c3d717e6  ProviderId=be15a055-f4cc-408a-9218-c71184d2bc61
EntityVersionName=FormDesigner      GUID=0b6c8a65-e172-4196-a2b6-abd64ebd96d6  ProviderId=be15a055-f4cc-408a-9218-c71184d2bc61
```
Os três compartilham o mesmo `ProviderId=be15a055` (K2B Object Designer). Esse GUID
`be15a055` é o identificador do provider K2BTools — aparece 3 vezes em
`EntityVersionProperties`.

O GUID `562b39a3` pertence ao **WebPanelDesigner**, não ao FormDesigner. A row em `Entity`
com `EntityGuid=562b39a3` tem `EntityTypeId=1` (Root) e `EntityId=155`. Não é uma entidade
FormDesigner. O detalhe estrutural: `EntityId=155` coincide com o `EntityTypeId` do
WebPanelDesigner — padrão que sugere que tipos de designer se registram como entidades Root
com `EntityId = seu próprio EntityTypeId`. Não documentado oficialmente; observação empírica
desta KB.

*EntityVersion — instâncias FormDesignerPart:*
```
EntityVersion WHERE EntityTypeId=161: 36 registros
  Todos com EntityVersionName='FormDesignerPart'  (não 'FormDesigner')
EntityVersion WHERE EntityVersionName='FormDesigner': 1 registro
  (é o registro de tipo, TypeId=1/Root, não uma instância FormDesigner)
```
Total de ocorrências com algum nome contendo "FormDesigner": 37 (1 + 36), mas são dois
nomes distintos — não 37 registros para o mesmo nome.

*Entity:*
```
Entity WHERE EntityTypeId=161: 36 entidades
  Cada uma com EntityLastVersionId=1
```

*EntityVersionComposition — pais das FormDesignerPart (18 WebPanels distintos, verificados 2026-05-10):*
```
CardPhotoActions, CardPhotoCompact, CardWithSummary, CardWithSummaryVariant1,
DetailPopOver, DetailVariant1, DetailVariant2, DetailWithPhoto,
GenericEntityList, GenericEntityListWithImage, K2BT_SimplePriceList,
NotificationList, PhotoWithTitle, SelectedItem, SelectedItemTag,
StructuredList, StructuredPeopleList, Timeline
```
Cada um aparece com 2 linhas de composição de `FormDesignerPart` (36 linhas totais / 18 pais).
Lista completa, não parcial: query verificada com `COUNT(DISTINCT CompoundEntityId)=18`
e `rows_not_matching_exact_version_join=0`.

Nota: WebPanelDesigner (EntityTypeId=155) e SDPanelDesigner (EntityTypeId=156) não possuem
entradas em `EntityVersionComposition` como componentes nesta KB — apenas FormDesigner (161)
tem linhas de composição. Isso implica que o escopo desta query é completo para
"WebPanels com composição de FormDesignerPart", mas incompleto para audit total de
resíduos K2BTools internos (que exigiria checar outros ângulos além de ComponentEntityTypeId=161).

**Divergências encontradas no relato do agente externo:**
1. `EntityTypeNamespace=K2BTools` atribuído ao FormDesigner (EntityTypeId=161) — **incorreto**; namespace é vazio.
2. `EntityVersion.EntityVersionName='FormDesigner': 37 ocorrências` — **incorreto**; são 1 para 'FormDesigner' e 36 para 'FormDesignerPart'.
3. GUID `562b39a3` associado ao "contexto FormDesigner" — **impreciso**; é o GUID do WebPanelDesigner na EntityVersionProperties; a row em Entity com esse GUID é Root (EntityTypeId=1), não FormDesigner.

Essas imprecisões não invalidam o diagnóstico central, mas afetam queries de busca: uma
query filtrando `Namespace='K2BTools'` não encontraria FormDesigner, gerando novo falso
negativo.

### Tabelas candidatas para diagnóstico

- `EntityType` — tipos de designer; campos úteis: `EntityTypeId`, `EntityTypeName`, `EntityTypeNamespace`
- `Entity` — instâncias; campos úteis: `EntityId`, `EntityGuid`, `EntityTypeId`, `EntityLastVersionId`
- `EntityVersion` — versões e propriedades XML; campos úteis: `EntityVersionId`, `EntityTypeId`, `EntityVersionName`, `EntityVersionProperties`, `EntityVersionTimestamp`
- `EntityVersionComposition` — composição pai-filho; campos úteis: `ComponentEntityTypeId`, `ComponentEntityId`, `CompoundEntityTypeId`, `CompoundEntityId`, `CompoundEntityVersionId`
- `[OBJECT]` — opcional, apenas para tentar correlacionar com objetos GeneXus comuns exportáveis

### Escopo de uso

- Usar apenas quando houver evidência de provider/item desconhecido na abertura/build/export da KB **e** a busca no XPZ/XML não localizar o item
- A consulta SQL é somente leitura; serve para diagnóstico e geração de relatório para suporte, não para correção
- Nunca recomendar remoção direta por SQL de entidades internas da KB

### Cuidados metodológicos para o diagnóstico SQL

Derivados da análise de três imprecisões introduzidas durante a investigação desta KB
(2026-05-10), cada uma com mecanismo de origem distinto:

- **Namespace**: citar o valor de `EntityTypeNamespace` somente com query literal que retorne
  a linha específica (`WHERE EntityTypeId = <id>`). Nunca inferir por proximidade com linhas
  vizinhas da mesma família — tipos de designer da mesma extensão podem ter namespaces
  diferentes entre si.

- **Contagem de EntityVersion**: citar contagem de linhas relacionadas a um nome somente
  com `GROUP BY EntityVersionName`. COUNT sem agrupamento por nome vira narrativa ambígua
  quando o critério de busca casa com nomes distintos (ex.: `FormDesigner` e
  `FormDesignerPart` são dois nomes, não um).

- **GUIDs**: citar GUID somente com a linha exata de origem, a coluna em que apareceu e o
  `EntityVersionName` da linha. GUIDs de providers distintos podem aparecer juntos na mesma
  busca textual; agrupar sem preservar a cardinalidade "tipo → GUID → coluna → linha de
  origem" produz associação incorreta.

### Questões abertas antes de implementar

1. A `xpz-kb-parallel-setup` já lê `knowledgebase.connection`? Se sim, a string de conexão pode ser derivada automaticamente no contexto de setup — esse seria o home natural para a capacidade.
2. O acesso deve ser via script PowerShell com `System.Data.SqlClient` no motor compartilhado, ou apenas documentado como procedimento narrativo para o agente executar inline?
3. O GeneXus documenta oficialmente o esquema `EntityType`/`Entity`/`EntityVersion`? Se não, há risco de quebra em upgrade — essa limitação precisa ficar documentada explicitamente junto com a capacidade.
4. A normalização `Server=localhost` a partir de `<HostName>localhost</HostName>` (e não de `<ServerInstance>`) é confiável em todos os ambientes? Verificar se `HostName` sempre está presente ou se a derivação deve usar `ServerInstance` como fallback.

### Frente de regras conceituais — encerrada em 2026-05-10

A dimensão de **regras de classificação e comunicação** desta ideia foi tratada como frente
separada, registrada em `historico/IdeiasImplementadas_202605.md` e aplicada diretamente nas skills e na base compartilhada:

- `02-regras-operacionais-e-runtime.md` — nova seção "Limite do XPZ/XML frente a providers
  e extensoes GeneXus" com as oito regras operacionais conceituais
- `xpz-reader/SKILL.md` — bullet de classificação de item antes de concluir ausência
- `xpz-index-triage/SKILL.md` — bullet análogo para resultado negativo do índice

O que permanece pendente nesta entrada é apenas a capacidade operacional de **diagnóstico SQL somente leitura** no banco interno da KB, coberta pelo limiar abaixo.

### Limiar para implementar (diagnóstico SQL)

Implementar quando houver: (a) resposta para a questão 1 acima (home no setup ou skill
própria), e (b) caso concreto adicional de warning de provider em KB diferente que confirme
o padrão de busca para além do caso K2BTools verificado aqui.

## Gate de mojibake/UTF-8 por bytes em XML pré-empacotamento

**Importância:** alta
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11.

### Problema concreto que motiva a ideia

Payloads textuais de objetos GeneXus podem entrar no fluxo de empacotamento com bytes corrompidos por interpretação dupla de encoding (clássico `Ã§` no lugar de `ç`, `Ã£` no lugar de `ã`, `NÃ£o` no lugar de `Não`, `usuÃ¡rio` no lugar de `usuário`). Causas típicas: arquivo salvo em CP1252 e lido como UTF-8, ou o inverso, com a conversão silenciosa em alguma etapa intermediária do fluxo (export da IDE, edição manual, conversão de encoding por ferramenta externa).

Se esse texto entra num `import_file.xml` e é importado pela IDE, o conteúdo fica permanentemente errado na KB de destino — só corrigível por novo import corretivo após localizar todos os pontos contaminados.

Detecção visual em terminal não é confiável: o terminal pode estar mascarando o problema (renderizando bytes incorretos como caracteres certos por configuração de fonte/encoding) ou inventando-o (mostrando lixo onde os bytes estão corretos). A verificação tem de ser **por bytes**, não por render.

### Direção técnica proposta

Wrapper `.ps1` no motor compartilhado, candidato a nome `Test-XmlMojibakeSanity.ps1`:

- entrada: path de arquivo XML, ou pasta + glob recursivo
- algoritmo: ler bytes brutos, procurar sequências características de mojibake UTF-8↔CP1252 (`Ã[\x80-\xBF]`, `Â[\x80-\xBF]` em contexto suspeito, etc.) com lista finita e bem documentada de assinaturas
- saída estruturada: `OK` ou lista de arquivos com ofsets e contexto suspeito
- política de falha: a definir entre bloqueio rígido e alerta

Skills consumidoras:

- `xpz-builder`: gate pré-empacotamento, chamado antes de gerar `import_file.xml`
- `xpz-msbuild-import-export`: gate opcional pré-import, como camada extra de defesa
- wrapper local da pasta paralela pode chamar no fluxo de empacotamento local

A escolha por script (e não por regra textual em SKILL.md) segue a preferência metodológica desta base: comportamento determinístico mora em `.ps1`, regra textual em skill fica reservada para o que exige julgamento de agente.

### Perguntas a responder antes de decidir

- Qual a lista exata de assinaturas de mojibake a detectar? Falso positivo aqui é caro — bloquear pacote legítimo é pior que deixar passar um caso raro.
- O gate **bloqueia** o empacotamento ou apenas **alerta**? Depende de quanto o repositório-alvo admite texto legado com acentuação degradada.
- O escopo cobre apenas `Source` e equivalentes textuais editáveis, ou inclui `Description`, `Documentation` e nomes de identificadores?
- Há caso real recente de mojibake em pacote dentro do portfólio que sirva para calibrar a heurística empiricamente?

### Limiar para implementar

Implementar quando houver: (a) caso real de mojibake detectado em pacote do portfólio para calibrar empiricamente as assinaturas e a política de bloqueio/alerta, e (b) decisão fechada sobre escopo de partes do XML cobertas.

## Gate de dependências GeneXus no empacotamento de delta

**Importância:** alta
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11.

### Problema concreto que motiva a ideia

Ao gerar um delta XPZ alterando um `Attribute` (ou qualquer objeto referenciado por outros), é tentador empacotar só o objeto modificado. Em GeneXus, porém, esse atributo aparece **estruturalmente embutido** em outros objetos:

- `Transaction` que tem o atributo no seu level
- `SDT` que espelha o atributo (campo de mesmo nome e mesmo tipo)
- `DataProvider` que produz ou lê o atributo
- `WebPanel`/Work With que exibe ou recebe o atributo
- `Procedure` que lê ou escreve o atributo

Se o pacote contém só o atributo e os dependentes ficam de fora:

- a Transaction importada ainda carrega a definição anterior embutida (não há rebuild automático da estrutura do level)
- SDTs continuam com o tipo antigo, gerando type-drift silencioso
- callers compilam contra o shape antigo
- o build pode até passar e a aplicação rodar errada sem erro visível

O extremo oposto também é problema: empacotar tudo que toca o atributo gera pacote inflado e arrasta objetos não relacionados ao delta real, aumentando risco do import.

Hoje a decisão do que entra no pacote é narrativa do agente, sem consulta sistemática à grade real de dependências.

### Direção técnica proposta

Separar duas camadas:

**Camada determinística (`.ps1`):** consulta de dependências. Dado um conjunto de objetos `S`, retornar todos os objetos da KB que referenciam algum objeto de `S`, classificados por tipo de referência (estrutural embutida em level vs uso por chamada em Source vs apenas leitura em Rules, etc.). Dado puro — se o SQLite de `KbIntelligence` já tem a grade de referências, é uma query nova; se não tem, há frente preparatória de extrair essa grade dos XMLs no build do índice.

**Camada de julgamento (regra textual em `xpz-builder`):** dado o resultado da consulta acima, o agente apresenta ao usuário a sugestão de "pacote mínimo coerente". O gate não automatiza a inclusão — força o agente a **declarar explicitamente** quais dependentes está deixando de fora e por quê. Regra mínima textual em `xpz-builder`: "ao empacotar um objeto que tem dependentes, listá-los explicitamente e justificar exclusões".

Handshake entre skills:

- `xpz-builder` é o consumidor (vai empacotar)
- `xpz-index-triage` é o provedor da consulta (já é o lugar natural de "quem chama/referencia quem")
- conecta também com os itens "callers/migração" do mesmo prompt externo (a serem avaliados separadamente)

### Parentesco com a frente de drift de tipagem

Esta entrada e "Drift de tipagem entre Attribute, SDT, DataProvider e callers" (entrada subsequente) são parentes próximas, mas com perguntas distintas:

- esta entrada pergunta **"quem mais precisa entrar no pacote?"**
- a entrada de drift pergunta **"o que está no pacote bate com o que está na KB de destino?"**

Ambas consomem a mesma grade de dependências, mas com semânticas diferentes. Mantidas como entradas separadas porque os limiares de implementação podem divergir; se uma virar frente, a outra deve ser reavaliada na mesma sessão para decidir se entra junto.

### Perguntas a responder antes de decidir

- O SQLite de `KbIntelligence` já registra a grade de referências entre objetos? Se sim, qual a granularidade — só "objeto A referencia objeto B" ou também o tipo de referência (embutida em level, chamada em Source, leitura em Rules)?
- Se a grade não existir no índice atual, qual o custo de extrair durante o build do índice? Há heurística estrutural confiável por tipo de objeto (level de Transaction, structure de SDT, source de Procedure, etc.)?
- O gate deve **bloquear** o empacotamento na ausência de declaração explícita sobre dependentes, ou apenas **exigir manifesto** que o agente liste e justifique?
- Como o gate se comporta quando a KB de destino é diferente da KB de origem (cenário de migração entre KBs)? A grade da KB de origem pode não cobrir referências que existem apenas na destino.

### Limiar para implementar

Implementar quando houver: (a) confirmação empírica de que o SQLite atual cobre (ou pode cobrir com custo aceitável) a grade de referências entre objetos com granularidade suficiente, e (b) caso real recente de empacotamento que deixou dependente importante de fora e contaminou KB de destino, para calibrar a política do gate.

## Drift de tipagem entre delta empacotado e snapshot oficial

**Importância:** alta
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11.

**Filiação editorial:** esta entrada é o caso prático concreto da camada de comparação proposta de forma abstrata em "Baseline conhecido no sanity e na revisao de objeto legado" (mesma seção 999). Se uma das duas virar frente de implementação, a outra deve ser reavaliada na mesma sessão.

### Problema concreto que motiva a ideia

Cenário típico: o agente recebe pedido para alterar o atributo `Email` e gera um delta XPZ declarando o tipo `Character(60)`. O snapshot oficial em `ObjetosDaKbEmXml` mostra que `Email` na KB atual está como `Numeric(15)`. Se o delta é importado, o tipo na KB é sobrescrito silenciosamente. A aplicação rodando depende do tipo atual — registros existentes, callers compilados, banco com coluna no tipo antigo — e quebra em cascata só depois, no build ou em runtime, longe do momento do import.

Causas típicas:

- agente gerou o delta a partir de premissa antiga (snapshot que tinha em contexto não era o snapshot atual)
- source do delta foi redigido com tipo errado por engano de transcrição
- drift interno na própria KB que já existia antes do delta — atributo com um tipo, SDT que deveria espelhar com tipo diferente — detectável só lendo o snapshot

Variações estruturais do mesmo problema:

- Attribute no delta com tipo X, snapshot com tipo Y
- SDT no delta com campo de tipo X, atributo homônimo no snapshot com tipo Y
- DataProvider no delta retornando shape que não bate com SDT consumidor já existente no snapshot
- Procedure no delta com parâmetro de tipo X, callers no snapshot chamando com tipo Y

Hoje `xpz-builder` valida XML bem-formado e sanity absoluto do `Source` do delta, mas não compara o tipo do que entra contra o tipo do que já está no snapshot. Há ponto cego entre "`import_file.xml` válido" e "`import_file.xml` coerente com o snapshot oficial da KB que vai recebê-lo".

### Direção técnica proposta

Mesmo padrão das outras frentes determinísticas: separar camadas.

**Camada determinística (`.ps1`):** para cada objeto no delta, extrair os tipos relevantes (tipo do Attribute, tipos dos campos do SDT, assinaturas de parâmetros de Procedure, etc.) e comparar contra o mesmo objeto em `ObjetosDaKbEmXml`. Saída estruturada por objeto: `same`, `drifted (tipo X → tipo Y)`, `new (não existe no snapshot)`.

Variante adicional sem delta: passar só o snapshot e detectar **drift interno** entre objetos que deveriam espelhar tipos (Attribute ↔ SDT homônimo, Procedure parameter ↔ caller signature).

**Camada de julgamento (regra textual em `xpz-builder`):** dado o resultado da comparação, o agente apresenta o drift detectado ao usuário com classificação de risco e exige confirmação explícita para drifts não triviais. Classificação proposta:

- drift estrutural em level de Transaction → alto risco
- drift em parâmetro de Procedure com callers existentes → médio risco
- novo objeto (não existe no snapshot) → baixo risco, apenas declarar

### Parentesco com item de dependências GeneXus

Esta entrada e "Gate de dependências GeneXus no empacotamento de delta" consomem a mesma grade de informações estruturais do snapshot, mas com perguntas distintas:

- gate de dependências pergunta "quem mais precisa entrar no pacote?"
- esta entrada pergunta "o que está no pacote bate com o snapshot?"

Mantidas separadas porque os limiares de implementação podem divergir; se uma virar frente, a outra deve ser reavaliada na mesma sessão.

### Perguntas a responder antes de decidir

- A extração de tipo é confiável por leitura estrutural do XML para todos os tipos de objeto envolvidos (Attribute, SDT, DataProvider, Procedure, Transaction level)? Quais part-types do XML carregam essa informação?
- O drift interno detectável só pelo snapshot (Attribute vs SDT homônimo) deve viver em script separado ou na mesma ferramenta de comparação delta-vs-snapshot?
- O gate deve **bloquear** o empacotamento quando houver drift de alto risco, ou apenas **exigir manifesto** que o agente liste e justifique?
- Como a saída se integra com o gate de dependências (1.2)? Drift de tipagem em objeto que tem dependentes não incluídos é cenário composto que precisa de tratamento conjunto.

### Limiar para implementar

Implementar quando houver: (a) caso real recente de drift de tipagem detectado tarde demais (no build ou em runtime) que tenha gerado dano efetivo, para calibrar a classificação de risco, e (b) decisão fechada se a frente vai junto com o gate de dependências (1.2) ou separada — depende de quanto da infraestrutura de leitura estrutural é compartilhada entre as duas.

## Parsing estruturado de log de build — agrupamento, classificação e resumo de impacto

**Importância:** média
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11. Fusão dos itens 3.1 (agrupador de causa raiz, P0 no prompt externo), 3.3 (classificador de erro por tipo, P1) e 3.4 (resumo de impacto — causa direta vs cascata, P1) do mesmo prompt. Os três sempre serão discutidos juntos: mesmo insumo (log do MSBuild), mesma técnica (heurísticas sobre mensagens), mesmo consumidor (`xpz-msbuild-build`).

### Problema concreto que motiva a ideia

Quando `Invoke-GeneXusKbBuildAll.ps1` retorna `compilou com erros`, hoje o agente reporta o status e expõe o log bruto. O usuário precisa ler dezenas ou centenas de linhas para identificar a causa real. Em casos típicos de GeneXus, dezenas de erros derivam de **uma única causa raiz** — um atributo com tipo errado pode gerar erros em cascata em todos os SDTs, DataProviders e Procedures que o consomem. Sem agrupamento, o usuário pode gastar tempo investigando um erro derivado em vez da causa.

A skill atual classifica o **resultado da operação** em categorias claras ("compilou com erros", "reorg detectada ou executada", etc.), mas não classifica nem agrupa **os erros individuais dentro do log**.

### Três camadas da mesma frente

**Agrupamento por causa raiz (item 3.1 do prompt externo):** dado um log com N erros, identificar quais são derivados de uma mesma causa estrutural e apresentar apenas a causa raiz com os derivados como "cascata de M erros relacionados".

**Classificação por tipo de causa (item 3.3 do prompt externo):** rotular cada causa raiz por categoria:

- erro de conteúdo — Source GeneXus mal-formado, sintaxe incorreta
- erro de tipagem — drift de tipo detectado em tempo de build
- erro de dependência — objeto chamado/referenciado não existe ou referência quebrada
- erro de encoding — bytes corrompidos detectados em compile
- erro de reorg — banco/schema desalinhado com o modelo

**Resumo de impacto (item 3.4 do prompt externo):** separar objetos que falharam por causa direta dos que falharam por efeito cascata, declarando explicitamente o grafo de impacto.

### Direção técnica proposta

Camada determinística (`.ps1`): parser estruturado do log do MSBuild que extrai erros, normaliza mensagens, identifica grafos de derivação por nome de objeto/atributo, agrupa por causa raiz, classifica por padrão de mensagem. Saída estruturada (JSON) consumível pelo agente.

Camada de julgamento (regra textual em `xpz-msbuild-build`): apresentação ao usuário do parsing estruturado, com formatação que enfatiza causa raiz e oculta derivações repetitivas até que o usuário peça.

### Loop de feedback com gates upstream

A categoria de classificação (1.1 encoding, 1.2 dependência, 1.3 tipagem) mapeia diretamente para os gates upstream propostos em outras entradas desta seção. Um erro classificado como "tipagem" que aparece no build é, em tese, um caso que o gate de drift de tipagem (1.3) deveria ter pego antes. Esse mapeamento fecha um loop de feedback: erro classificado X no build → revisar gate X upstream.

O valor real desse loop só se materializa quando pelo menos um gate upstream estiver implementado e gerando casos de teste reais de "erro que escapou".

### Perguntas a responder antes de decidir

- As mensagens de erro do GeneXus 18 nesta instalação têm formato estável o suficiente para heurística confiável? Em que medida mudam entre minor versions? É necessário um catálogo empírico de mensagens por categoria como pré-requisito.
- Como distinguir erros que vêm de specify do GeneXus, errors de generate, erros de compile (Java/C#) e erros de MSBuild puro? Cada fonte tem padrão próprio.
- Como tratar erros sem objeto identificável (erro de infraestrutura, erro de configuração de ambiente)? Categoria residual "ambiente"?
- Falso negativo (não identificar derivação que existia) é melhor ou pior que falso positivo (agrupar erros não relacionados)? Provavelmente falso negativo é menos ruim — não esconde nada do usuário.
- Quanto do parsing deve viver em script vs ser delegado ao agente? Pattern matching é determinístico; correlação semântica entre erros pode exigir julgamento.

### Limiar para implementar

Implementar quando houver: (a) pelo menos um gate upstream (1.1 mojibake, 1.2 dependências ou 1.3 drift de tipagem) implementado e em uso real, gerando casos concretos de "erro que escapou ao gate" para calibrar o classificador empiricamente; e (b) catálogo empírico de mensagens de erro do GeneXus 18 mapeado por categoria, construído a partir de logs reais de build com erro.

## Manifesto semântico de pacote — saída agregada dos gates de empacotamento

**Importância:** média
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11.

**Filiação editorial:** esta entrada é a saída agregada das frentes "Gate de mojibake/UTF-8 por bytes em XML pré-empacotamento", "Gate de dependências GeneXus no empacotamento de delta" e "Drift de tipagem entre delta empacotado e snapshot oficial" (todas em 999). Sem pelo menos uma dessas frentes implementada, o manifesto fica oco — o invólucro existe mas as seções "dependências confirmadas/presumidas" e "riscos" não têm conteúdo estruturado para preencher.

### Problema concreto que motiva a ideia

Hoje o agente narra o pacote durante a sessão de empacotamento: o que entrou, o que deliberadamente ficou de fora e por quê, riscos avaliados. Quando a sessão fecha, essa narrativa some. Restam apenas `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml` na pasta de pacotes — opaco para auditoria posterior.

Em frente longa, ou em handoff entre agentes (mesmo entre sessões consecutivas do mesmo agente), perder essa camada custa caro. Outro agente que pegue o mesmo `import_file.xml` daqui a duas semanas precisa reconstruir do zero o raciocínio de inclusão/exclusão. Não há fonte persistente da **intenção** de empacotamento, apenas do resultado.

Diferente do log de import (que registra o que aconteceu no MSBuild), o manifesto mostra o que se pretendia fazer e por quê.

### Conteúdo proposto

Quatro seções derivadas das frentes upstream:

- **objetos alterados** — lista de objetos no pacote (já trivial sem dependência de outra frente)
- **dependências confirmadas** — referenciados pelos objetos alterados que foram **incluídos** no pacote por decisão explícita; alimentada pelo gate de dependências
- **dependências presumidas** — referenciados pelos objetos alterados que foram **deixados de fora** por decisão explícita, com justificativa; alimentada pelo mesmo gate
- **riscos** — alertas detectados pelos gates de mojibake, drift e qualquer outro gate que vier a existir; categorizados por severidade

### Direção técnica proposta

Camada determinística (saída de scripts): cada gate upstream emite resultado estruturado (JSON) que serve como insumo do manifesto.

Camada de julgamento (regra textual em `xpz-builder`): consolidar os resultados estruturados, adicionar a narrativa de inclusão/exclusão deliberada e gerar o manifesto final como artefato persistente no momento do empacotamento.

### Decisões editoriais ainda em aberto

- **Formato:** JSON estruturado (consumível por outro agente), MD legível (consumível por humano), ou ambos? A combinação JSON + MD lado a lado tende a inflar custo de manutenção; um único formato consumível por ambos os públicos seria mais limpo.
- **Posição:** raiz de `PacotesGeradosParaImportacaoNaKbNoGenexus` junto com `import_file.xml`, ou subpasta dedicada? A regra atual exige que a pasta permaneça plana — manifesto na raiz parece natural.
- **Nomenclatura:** `NomeCurto_GUID_YYYYMMDD_nn.manifest.{ext}` segue o padrão atual de prefixo de frente.
- **Versionamento Git:** por default, `PacotesGeradosParaImportacaoNaKbNoGenexus` não é versionada; manifesto pode ser exceção por valor de auditoria, mas isso é decisão de política do repositório, não automatismo do agente.
- **Produtor:** `xpz-builder` é o consumidor natural; manifesto seria saída adicional do mesmo fluxo de empacotamento, não wrapper separado.

### Perguntas a responder antes de decidir

- A camada de "dependências presumidas" exige enumerar **todos** os referenciados não incluídos, ou apenas aqueles que o gate de dependências sinalizou como potencialmente relevantes? A primeira opção é exaustiva mas pode ser ruidosa; a segunda é seletiva mas depende de heurística confiável no gate.
- O manifesto deve ser regenerável a partir do `import_file.xml` sozinho, ou pressupõe acesso ao contexto da sessão de empacotamento? Regenerável tem custo (re-rodar gates contra o snapshot atual), mas dá robustez de auditoria.
- Há valor em manifesto também para a saída do build (causa raiz, classificação, impacto — entrada "Parsing estruturado de log de build")? Ou manifesto é estritamente da fase de empacotamento?

### Limiar para implementar

Implementar quando houver: (a) pelo menos um gate upstream (1.1 mojibake, 1.2 dependências ou 1.3 drift de tipagem) implementado e em uso real, gerando saída estruturada que sirva de conteúdo para uma das seções do manifesto; e (b) decisão editorial fechada sobre formato, posição, nomenclatura e política de versionamento Git.

## Expansão do índice SQLite para fingerprint de call site

**Importância:** média
**Maturidade:** ideia

**Origem:** avaliação de prompt externo em 2026-05-11. Surgiu como evolução adjacente à proposta original "Consulta de migração (Origem → Destino)" — a leitura cosmética foi descartada para 998; o ângulo estrutural sobrevive aqui.

### Problema concreto que motiva a ideia

A consulta `who-uses Procedure:X` no índice atual retorna a lista de objetos que referenciam o alvo — apenas os nomes. Para editar cirurgicamente cada caller (substituir referência antiga por nova, ajustar parâmetros, remover uso obsoleto), o agente precisa abrir o XML de cada caller e localizar o local exato da referência. Em uma migração que afeta 20 ou 30 callers, isso vira leitura manual extensiva mesmo com o índice ajudando a triagem inicial.

O índice já varre todos os XMLs uma vez durante o build (`Build-KbIntelligenceIndex.py`). Agregar **o local** de cada referência no mesmo passo de varredura é custo marginal frente ao trabalho já realizado.

### Direção técnica proposta

Estender o schema do SQLite para registrar, em cada relação de referência entre objetos, metadados de localização:

- `part` — qual part-type do XML contém a referência (Event, Action, Source, Rules, Conditions, Layout, etc.)
- `block` — nome do bloco nominal dentro do part (qual Event, qual Action, etc.) quando aplicável
- `line` — linha aproximada no Source quando aplicável
- `context` — trecho curto do XML em torno da referência, para o agente confirmar antes de editar

Resultado: `who-uses Procedure:X` passa a retornar não só "estes N objetos te referenciam" mas "te referenciam aqui — `WPRelatorio` no Event 'Refresh' linha ~47, `PRecalcular` no Source linha ~12, etc.".

### Por que **não** substitui a frente vetorial em 999

A frente "LlamaIndex / LangChain + vector store como alternativa ao indice SQLite atual" e esta entrada respondem perguntas diferentes:

- **Vetorial:** descoberta semântica por intenção em linguagem natural ("qual procedure atualiza o saldo de estoque mensal?"); ajuda a achar **o quê** quando o nome do objeto é desconhecido
- **Fingerprint no SQLite:** endereçamento estrutural preciso ("onde exatamente cada caller referencia este alvo?"); ajuda a achar **onde** quando os nomes já são conhecidos

São complementares. Implementar uma não dispensa a outra. Custos de implementação são muito diferentes — vetorial exige camada nova completa (embeddings, vector store, novo wrapper); fingerprint é evolução incremental do índice atual.

### Perguntas a responder antes de decidir

- Qual a granularidade de localização que de fato basta para edição cirúrgica? Part + bloco nominal é suficiente, ou precisa linha aproximada e trecho de contexto também?
- O custo de varredura adicional durante o build do índice é aceitável? Validar empiricamente em KB grande (~15k objetos).
- O schema atual do SQLite comporta a expansão sem migração disruptiva? Provavelmente sim (nova tabela de localizações vinculada à tabela de relações), mas precisa confirmação.
- A informação de fingerprint deve ser exposta como capacidade nova no wrapper local (`who-uses-detailed`?), ou enriquecer a saída de `who-uses` existente? Compatibilidade retroativa é uma decisão editorial.
- Como tratar referências em part-types com formato não-linear (Layout XML, Rules, Conditions)? "Linha aproximada" não faz sentido em todos os casos.

### Limiar para implementar

Implementar quando houver: (a) caso real recente de migração em lote (10+ callers) que tenha custado caro por leitura manual de XML após o `who-uses` apontar os nomes; e (b) decisão fechada sobre granularidade do fingerprint (qual nível de localização vale o custo de armazenar e manter).

## Enxugar o inventário de scripts do `09` para ponteiros (remover duplicação que drifta) — IMPLEMENTADO E MIGRADO

> Implementado e migrado para `historico/IdeiasImplementadas_202606.md` em 2026-06-15 (commits `d8844c4`/`45dbc2b`/`a259358`; veto de modelos em `33bd9aa`; trava `PUBLIC_TRACEABILITY_VERBOSE_LINE` no gate de rastreabilidade). As ~111 entradas de script do `09` viraram ponteiros de 1 linha (Caminho 1: tokens/sentinelas/exits nus, prosa de contrato no dono), com downstream em `AGENTS`/`08`/`13`/`998`/`CHANGELOG`; pré-push mecânica verde e fase semântica limpa; **não pushado** (decisão do usuário). O candidato 2 da trava (gêmeo `09↔dono`) ficou como ideia própria abaixo.

## Trava anti-regressão do `09` enxuto — gêmeo `09↔dono` (candidato 2)

**Importância:** baixa
**Maturidade:** ideia

**Origem:** fechamento do enxugamento do `09` (2026-06-15). O candidato 1 (sinal `PUBLIC_TRACEABILITY_VERBOSE_LINE`, que detecta entrada de script voltando ao formato verboso) foi implementado junto da frente. Sobra o candidato 2, mais complexo.

### Problema

O ponteiro curto realocou o risco de drift para `09`↔dono: o token-check do gate passa (tokens nus preservados), mas a referência pode ficar semanticamente errada quando o **dono** muda e o ponteiro do `09` não (ou vice-versa). O `Test-PrePushTraceabilityCoverage.ps1` hoje não cobre essa assimetria.

### Direção

Um "gêmeo" do `Test-PrePushSharedScriptSkillCoverage.ps1` para `09`↔dono: quando o diff altera um dono normativo (skill / `02` / `08` / `13` / catálogo) sem tocar o ponteiro correspondente no `09` (ou vice-versa), avisar como candidata a conferir. `warn`, não bloqueante.

### Dificuldade / limiar

O "dono" no ponteiro é texto livre (`Dono: <skill/doc>`), então mapear ponteiro→dono de forma robusta é o ponto duro (alto risco de falso positivo). Implementar quando aparecer a primeira regressão real de `09`↔dono, ou ao consolidar os gates consultivos da pré-push numa próxima rodada.

## Faceta b — gate "motor novo sem entrada no `09`" (ampliar `PUBLIC_TRACEABILITY_MISSING_SCRIPT`)

**Importância:** baixa
**Maturidade:** pesquisa feita (painel de pares 2026-06-15 mapeou as decisões abertas)

**Origem:** "faceta dependente (b)" da entrada do enxugamento do `09` (migrada ao histórico). Hoje o `Test-PrePushTraceabilityCoverage.ps1` só emite `PUBLIC_TRACEABILITY_MISSING_SCRIPT` quando o diff do script casa um token do `$scriptRiskPattern` (`INVENTORY_*`/`executionEvidence`/etc.); um motor novo que **não** emite esses tokens (ex.: `Set-GeneXusXmlLastUpdate.ps1`) passa batido mesmo ausente do `09`.

### Direção

Para todo `scripts/*.{ps1,py}` tocado no diff cujo basename **não** apareça no texto do `09` → `warn`, **independente** de token de risco (afrouxar a condição `$scriptHasTraceabilityRisk` da regra de basename, reusando o `code=PUBLIC_TRACEABILITY_MISSING_SCRIPT` existente). Consultivo, com teto; self-test no molde do `PUBLIC_TRACEABILITY_VERBOSE_LINE`.

### Decisões abertas (mapeadas pelo painel de pares 2026-06-15)

- **O `09` NÃO é índice nominal completo hoje** (premissa que o painel derrubou). Há ~12-17 `.ps1`/`.py` reais ausentes (`Extract-XpzObject`, `Query-KbIntelligenceIndex`, `Watch-GeneXusMsBuildLog`, `Test-XpzPowerShellRuntime`, `Update-XpzDocSection`, `Show-FileWhitespace`, gates 9-BC/9-IDO/9-PSM/9-WW, `Test-KbIntelligenceQueries.py`…) + ~14 fixtures `kb-intelligence-*.validation*.json`. A faceta b **alarga o contrato** do `09` de "índice de ponteiros das entradas que ele descreve" para "índice nominal completo de `scripts/`": decisão editorial — decidir o que o `09` promete cobrir e **reconciliar os ausentes** (ou documentar a exclusão) ANTES de ligar o gate, e registrar a virada de contrato no `13`/`08`/`02`.
- **`.json`**: excluir as fixtures de validação do escopo (senão toda frente que adiciona um caso de teste a uma bateria dispara falso positivo estrutural). Limitar a `.ps1`/`.py`, ou só catálogos/contratos `.json`.
- **`scripts-maintenance/`**: hoje o gate filtra `^scripts/` mas o `09` indexa `scripts-maintenance/` (entrada coletiva da campanha `exportTaskLabel`). Decidir: ampliar para `scripts(-maintenance)?/` ou remover do `09` a expectativa de indexar `scripts-maintenance/`.
- **`added` vs `added`+`modified`**: Claude recomenda só `added` (tocar um dos ~17 legados ausentes geraria warn); Codex/minimax recomendam `added`+`modified` (tocar um legado ausente é o momento barato de decidir se entra). Tratar `A`/`M`/`R`(destino), nunca `D`.
- **Match por fronteira de token**, não substring: `Foo.ps1` casa dentro de `Test-Foo.ps1`; usar `[regex]::Escape($base)` ancorado por fronteira. Manter a auto-exclusão do próprio gate (`$isTraceabilityDetector`).

### Distinção das outras travas do `09`

- `PUBLIC_TRACEABILITY_VERBOSE_LINE` (**implementada**): entrada existente que **re-incha** ao formato verboso.
- Gêmeo `09↔dono` (**candidato 2, acima**): dono muda e o ponteiro **não acompanha** (drift).
- Faceta b (**esta**): motor **novo nunca entrou** no `09` (lacuna no lado da adição).

### Limiar para implementar

Depois de reconciliar o contrato de cobertura do `09` (decidir e completar/excluir os ~17 ausentes + documentar no `13`/`08`). Só então abrir a frente do gate, com self-test.

## Correção de acentuação pt-BR degradada nos SKILL.md

**Importância:** alta
**Maturidade:** todos os segmentos versionados concluídos em 2026-06-11 — raiz `.md`, `skill-md`, `skill-satelite`, `outros-md`, comentários de `ps1` e `example-ps1` (ver as três subseções «Execução 2026-06-11» ao fim). Resíduo é só intencional (citações dos 3 arquivos do instrumento, conteúdo de string). **Dívidas abertas:** cópula geral `e/é` e textos pt-BR dentro de strings de `.ps1`

**Origem:** avaliação de prompt externo em 2026-05-11 com verificação empírica feita na mesma sessão.

### Problema concreto confirmado empiricamente

Varredura nos 10 SKILL.md do repositório em 2026-05-11 confirmou degradação de acentuação pt-BR generalizada. **Mojibake real (bytes corrompidos `Ã§`/`Ã£`/etc.) não existe** — o agente externo que reportou o problema possivelmente viu renderização errada de UTF-8 válido como CP1252 no terminal dele. O defeito real é de outra natureza: acentos perdidos por degradação a ASCII em palavras pt-BR. Exemplos colhidos diretamente de `xpz-index-triage/SKILL.md`:

- "indice derivado" → `índice derivado`
- **"O indice e artefato derivado"** → `O índice é artefato derivado` (caso clássico apontado pelo usuário — `e` conjunção onde devia ser `é` verbo, mudando completamente o sentido)
- "nao substitui... e nao autoriza conclusao funcional automatica" → `não substitui... e não autoriza conclusão funcional automática`
- "gate e obrigatorio... existencia" → `é obrigatório... existência`

Distribuição por arquivo (palavras inequivocamente acentuadas detectadas por regex restrito; número real é maior — cada `e`/`area`/`referencia` etc. é falso negativo do regex):

| arquivo | hits |
|---|---|
| xpz-kb-parallel-setup | 331 |
| xpz-sync | 99 |
| xpz-index-triage | 98 |
| xpz-msbuild-build | 22 |
| xpz-msbuild-import-export | 17 |
| xpz-builder | 10 |
| xpz-doc-builder | 5 |
| xpz-daemon | 3 |
| xpz-skills-setup | 3 |
| xpz-reader | 2 |
| **total** | **590+** |

> **Nota 2026-06-11 — a tabela acima (2026-05-11) está superada.** Veja a medição fresca abaixo.

### Medição fresca 2026-06-11 (nova baseline; substitui a tabela de 2026-05-11)

Re-medição empírica no estado do commit `e5b3e89`, com detector determinístico versionado (`scripts/Measure-PtBrAccentDegradation.ps1` + `scripts/ptbr-accent-wordlist.json` + self-test). **Não é comparável 1:1** com os 590+ de 2026-05-11: lista curada maior (165 palavras inequívocas), escopo ampliado (todos os `.md` versionados + `.example.ps1` + comentários de `.ps1`) e supressão de código/identificador. É **piso firme** (palavras cuja forma sem acento é sempre erro), não teto. A medição já inclui os próprios arquivos do medidor (contribuição pequena, nos comentários `.ps1`). `numero` foi movido ao teto solto por ser também forma verbal (*eu numero*, de *numerar*), mantendo `numeros` no piso firme — alinhado às exclusões de `referencia`/`publico`/`pagina`. Casos de borda `sao`/`ja`/`numeros` foram avaliados e mantidos no piso firme: a forma sem acento nunca é lexema pt-BR válido (inclusive o topônimo `São` também leva acento).

**Total no trabalho pendente: 7.812 ocorrências inequívocas** (+ 745 ambíguas "teto solto", não confirmadas).

| Segmento | No total? | Arquivos | Com defeito | Inequívocas | Ambíguas (teto) |
|---|---|---|---|---|---|
| skill-md | sim | 11 | 4 | 1412 | 162 |
| skill-satelite | sim | 9 | 1 | 1 | 5 |
| raiz-md | sim | 37 | 32 | 5304 | 459 |
| outros-md | sim | 2 | 2 | 213 | 12 |
| example-ps1 | sim | 25 | 22 | 101 | 6 |
| ps1 (comentários) | sim | 174 | 118 | 781 | 101 |
| historico/ | não (diagnóstico) | 53 | 48 | 1591 | 72 |
| aportes-comunidade | não (diagnóstico) | 0 | 0 | 0 | 0 |

Achados que mudam o enquadramento:

- **O grosso não está nos SKILL.md.** Os `.md` numerados da raiz (base empírica `01*`–`12`) concentram 5.304 ocorrências; os comentários de `.ps1` somam 781. A medição de 2026-05-11 só olhava SKILL.md, por isso subdimensionava o trabalho real.
- **A campanha interrompida corrigiu parte.** Dos 11 SKILL.md, só 4 ainda têm defeito (7 já limpos) — confirma o relato de que a frente foi iniciada e parada no meio.
- **`historico/` (1.591)** fica fora do total: registro imutável, não se corrige (só diagnóstico da dívida histórica preservada).
- **`AportesDaComunidadeParaAvaliacao/`** é git-ignored (não versionado) → fora do universo medido.

O **mapa cirúrgico** (`arquivo:linha:palavra`) é gerado em `work/ptbr-accent-map.{md,json}` (git-ignored, transitório), regenerável a qualquer momento pelo detector; a sessão de correção parte dele.

> **Distinção do `998`:** o `998-ideias-descartadas-e-porque.md` descartou um *gate por-KB sobre payload de objeto* (e-mail/HTML), que dependeria de vocabulário calibrado por KB. Este medidor é outra coisa — *auto-QA das próprias docs do repositório de skills*, corpus único e conhecido, lista curada fixa mais supressão de código —, por isso não reabre aquele descarte.

### Direção técnica proposta

**Correção manual contextual, não substituição cega por regex.** Algumas palavras têm forma válida com ou sem acento:

- `esta` pode ser `está` (verbo) ou `esta` (pronome demonstrativo — válido sem acento)
- `tem` pode ser `tem` (3ª p. singular, válido) ou `têm` (3ª p. plural)
- `vem` pode ser `vem` (3ª p. singular, válido) ou `vêm` (3ª p. plural)
- `e` é a conjunção (válida) ou `é` o verbo
- `so` é forma estrangeira (raramente válida no contexto) ou `só`

Substituição em massa por regex causaria regressões. A correção precisa ser decisão contextual linha a linha.

### Por que é frente própria, dedicada e sequencial

Três motivos para frente separada:

- **Volume**: 590+ hits no regex restrito; número real maior. `xpz-kb-parallel-setup` sozinho concentra 331 — execução não cabe em sessão genérica.
- **Risco de revisão cega**: substituição mecânica gera regressões nas palavras ambíguas listadas acima.
- **Política de edição segura de MD longo**: regra do `AGENTS.md` global exige edições pequenas, locais, ancoradas por seção, com releitura imediata após cada gravação. Aplicar isso em centenas de pontos pede sessão dedicada.

### Plano de execução proposto

> **Nota 2026-06-11:** a medição fresca acima re-prioriza o plano — o grosso está nos `.md` numerados da raiz (5.314) e em comentários de `.ps1` (734), não nos SKILL.md; e 7 dos 11 SKILL.md já estão limpos. Antes de corrigir cada arquivo, rodar o detector (`scripts/Measure-PtBrAccentDegradation.ps1`) para o estado atual e usar o mapa em `work/`.

1. Sessão dedicada para a correção, com escopo declarado: "correção de acentuação pt-BR degradada nos SKILL.md".
2. Atacar um SKILL.md por vez, começando pelos menores (xpz-reader, xpz-daemon, xpz-skills-setup, xpz-doc-builder, xpz-builder) para calibrar a estratégia.
3. Para cada arquivo: ler integralmente, gerar lista de correções propostas, aplicar em edições pequenas e ancoradas por seção, reler trecho alterado após cada gravação.
4. `xpz-kb-parallel-setup` (331 hits) provavelmente exige sessão própria adicional só para ele.
5. Atualizar lista quando concluir cada arquivo; preservar rastreabilidade do progresso.

### Perguntas respondidas em 2026-05-11 (antes de iniciar execução)

- **Há regras editoriais que justifiquem manter alguma palavra sem acento?** Não. Todos os hits são defeitos.
- **O escopo cobre só SKILL.md ou também outros `.md`?** Todos os `.md` do repositório, incluindo `historico/` (~70 arquivos).
- **Os `.example.ps1` com comentários pt-BR entram?** Sim — qualquer `.ps1` com texto em português legível por agente deve ter acentuação correta.

### Regra operacional para palavras ambíguas

Qualquer palavra cujo acento muda o sentido — `e/é`, `esta/está`, `tem/têm`, `vem/vêm`, `so/só`, e análogos — deve ser perguntada ao usuário antes de alterar. Nunca corrigir por inferência mecânica nesses casos.

### Limiar para implementar

**Pronto agora.** Não há gate técnico, não há pesquisa pendente, não há decisão de design em aberto. Falta apenas alocar sessão dedicada com escopo declarado.

### Execução 2026-06-11 (raiz `.md` concluída)

Sessão dedicada executou a correção nos `.md` da raiz, partindo do mapa regenerado pelo detector. Resultado e decisões:

- **Inequívocas:** corrigidas em todos os `.md` da raiz pelo aplicador determinístico versionado `scripts/Repair-PtBrAccentDegradation.ps1` (contraparte do detector; reusa lista, regex e supressão de código; preserva caixa, EOL LF e UTF-8 sem BOM). O total do repositório caiu de 7.812 para 2.535 inequívocas; na raiz, de 5.304 para 0 reais — o resíduo medido na raiz (43) são apenas os exemplos degradados de propósito deste `999` e do `998`.
- **Tokens ambíguos:** `so`→`só` (verificado: nenhum «so» inglês na prosa pt-BR; as duas ocorrências inglesas em `README`/`CHANGELOG` foram excluídas), `numero`→`número` (substantivo) e `esta`→`está` decididos linha a linha (verbo vira `está`; demonstrativo «esta base/família/frente/seção/raiz» permanece). `tem`/`vem` no singular permanecem.
- **`e/é` — molduras de alta precisão** aplicadas por serem determinísticas: `não e`, `qual e`, `(esta|este|esse|essa|isso|isto) e`, `e:`. A **cópula geral** (`<sujeito> e <predicado>`) **não** é coberta: o detector não a mede, a forma colide com a conjunção e o risco de regressão é alto. Fica como **dívida documentada**; só o `02-regras-operacionais-e-runtime.md` recebeu a cópula completa (caso-modelo, com âncoras verificadas a mão).

Endurecimentos do instrumento (detector + lista curada), feitos nesta frente:

- **Demoção de 7 formas verbais** de `entries` para `ambiguousTokens`: `analise`, `calculo`, `especifico`, `especifica`, `pratico`, `pratica`, `modulo` — são substantivo/adjetivo acentuado **e** flexão verbal válida sem acento (mesma natureza do `numero` já demovido antes). Motivador: o aplicador trocou uma forma imperativa («analise o impacto») por «análise» no `AGENTS.md`, revertido. Os plurais (`especificos`/`especificas`/`modulos`) permanecem no piso firme. Há guard no self-test travando a regressão.
- **Consciência de seção pt-BR** no detector e nos aplicadores (`Get-PtBrLineCount`/`Get-PtBrText`): em arquivos trilíngues (PT/ES/EN — `README`, `CHANGELOG`, `CODE_OF_CONDUCT`, `SECURITY`, `CONTRIBUTING`), só a faixa pt-BR (até o primeiro cabeçalho `## Español`/`## English`) é medida e editada. Motivo: várias entradas colidem com **espanhol** válido sem acento (`repositorio`, `usuario`, `criterio`, `experiencia`, `existencia`, `transferencia`); a lista, vetada apenas contra inglês, corrompeu o espanhol antes do fix (revertido e reaplicado só à faixa pt-BR). O self-test ganhou golden multilíngue (18 asserts no total).

Pendente (frentes separadas, fora do «maior retorno = raiz» desta sessão): `skill-md` (~1.396), comentários de `.ps1` (~786), `outros-md` (~211) e `.example.ps1` (~98). A cópula geral `e/é` permanece como dívida em toda a base.

### Execução 2026-06-11 (continuação: `skill-md`, `skill-satelite`, `outros-md` concluídos)

Sessão seguinte, mesmo dia, partindo do mapa regenerado pelo detector. Resultado e decisões:

- **Inequívocas:** o aplicador determinístico `scripts/Repair-PtBrAccentDegradation.ps1` corrigiu 1.608 ocorrências nos 7 `.md` com defeito (`xpz-kb-parallel-setup/SKILL.md` 1.380, `scripts/README-kb-intelligence.md` 208, `xpz-msbuild-build`/`xpz-msbuild-import-export` 6 cada, `xpz-sync` 4, `scripts-maintenance/README.md` 3, satélite `transaction.md` 1). Total do repositório caiu de 2.549 para 941 inequívocas (o resíduo são `ps1`/`example-ps1` + os 43 exemplos propositais da raiz neste `999` e no `998`).
- **Ambíguas (85, decididas linha a linha com o usuário):** uniformes — `so`→`só` (42; as 2 de `transaction.md` são **inglês** e ficaram), `especifico`→`específico` (12), `especifica`→`específica` (4), `analise`→`análise` (2, ambas substantivo); posicionais — `esta`→`está` (24 casos-cópula, ex.: «está pronta/apto/limpa/disponível/fora do escopo») e `tem`→`têm` (1, plural «motores diferentes têm contratos» em `xpz-kb-parallel-setup/SKILL.md:972`). Preservados: `vem` e `tem` no singular, todos os `esta` demonstrativos («esta skill/seção/regra»), e o `so` inglês de `transaction.md`. Aplicadas por aplicador transitório em `work/` (git-ignored) que reusa boundary, supressão de código e faixa pt-BR do detector; `esta`/`tem` por âncora (linha + predicado), nunca por troca cega.
- **Estado dos segmentos `.md`:** `skill-md`, `skill-satelite` e `outros-md` ficaram com **0 inequívocas e 0 ambíguas-defeito**; o resíduo ambíguo medido nesses segmentos (104+5+3) são demonstrativos/singulares/inglês corretos, não defeito.

Pendente após esta continuação (estado **ao fim da continuação 1**, superado pela continuação 2 abaixo): comentários de `.ps1` (800 inequívocas + 125 ambíguas) e `.example.ps1` (98 + 9). À época, o aplicador `Repair-PtBrAccentDegradation.ps1` ainda rejeitava não-`.md` por construção, e atacar `.ps1` exigiria um aplicador irmão que operasse **apenas** comentários (`#` de linha e `<#…#>` de bloco), reusando a mesma lista/regex e a detecção de comentário do detector — **resolvido na continuação 2** (commit `8633225`), que estendeu o próprio Repair para `.ps1` via tokenizer. A cópula geral `e/é` segue como dívida em toda a base.

### Execução 2026-06-11 (continuação 2: comentários `.ps1` e `.example.ps1` concluídos)

Mesma sessão. Aplicador **tokenizer-based** (tokens `Comment` do PowerShell, offset exato — nunca toca código nem strings; mais seguro que o split-por-`#` do detector). Decisões:

- **Inequívocas:** 802 corrigidas em 138 arquivos (`example-ps1` zerado; `ps1` reduzido). Parse dos 200 scripts: 0 erros; self-test do detector: OK; EOL LF preservado.
- **Ambíguas (68 de 108, decididas linha a linha):** uniformes `so`→`só` (34; 1 `so` **inglês** em `Test-PyScriptsParse.ps1:8` ficou), `módulo` (8), `específico` (3), `cálculo` (2), `número` (2), `prática` (1) — as 4 formas demovidas e `especifico` apareceram **todas** como substantivo/adjetivo nos comentários; posicionais `esta`→`está` (16), `tem`→`têm` (1 em `Start-OpenCodeJob.ps1:66`), `vem`→`vêm` (1 em `Test-XpzGlobalInstructionsSelfTest.ps1:15`). Preservados: `tem`/`vem` singular, `esta` demonstrativo.
- **3 arquivos do próprio instrumento** (`Measure`/`Repair`/`Test-Measure…SelfTest`): tratados à parte por misturarem prosa degradada e **citações ASCII deliberadas**. Corrigida só a prosa clara de `Measure` (27) e `Repair` (15); **preservadas** as citações — 6 palavras-exemplo de colisão com espanhol (`repositorio/usuario/criterio/experiencia/existencia/transferencia`), id de segmento `historico`, token-exemplo `"nao."`, exemplos de caixa `NAO -> NAO`/`Padrao -> Padrao`. O `Test-Measure…SelfTest.ps1` (quase só citações de golden, ex.: `# L1 funcao,nao (2)`) ficou **intacto** — análogo aos 43 resíduos propositais da raiz no `999`/`998`.

Resíduo medido após esta etapa (tudo correto-a-permanecer): `ps1` 66 inequívocas + 52 ambíguas = self-test intacto (~36) + 18 conteúdo de **string** (mensagens/fixtures/doc gerada, falso-positivo do detector pelo `#`) + citações preservadas de Measure/Repair + singular/demonstrativo. **Dívida remanescente:** a cópula geral `e/é` em toda a base, e os textos pt-BR dentro de **strings** de `.ps1` (ex.: mensagens `-Message "...nao..."`, doc gerada por `generate-kb-*`) — fora do escopo "comentários" desta frente.

### Frente derivada — detector de `e/é` por molduras de alta precisão (proposta 2026-06-11)

**Origem:** pergunta do usuário ao fim da frente de acentuação — vale uma ferramenta que um agente rode a qualquer tempo para conferir erros que **mudam o sentido**, em especial `e`↔`é`? O detector `Measure-PtBrAccentDegradation.ps1` já sinaliza `esta/tem/vem/so/numero` + formas verbais (teto solto), mas **não** mede `e/é`: a conjunção «e» é válida e ubíqua, então uma lista simples geraria falso-positivo em massa (motivo documentado na `ptbr-accent-wordlist.json`).

**Ideia:** detector consultivo dedicado que cobre só o **subconjunto determinístico** onde «e» é quase certamente «é» — as **molduras de alta precisão** já validadas a mão na frente da raiz: `não e`→`não é`, `qual e`→`qual é`, `(esta|este|esse|essa|isso|isto) e`→`… é`, `e:` em fim de oração, e análogas a calibrar. Pega o mais perigoso com ruído baixo; **não** cobre a cópula geral `<sujeito> e <predicado>` (essa permanece dívida que exige julgamento humano/LLM). Cobertura **parcial e honesta** por construção.

**Decisões de design em aberto:**
- Ferramenta avulsa (`Measure-`/`Test-` irmão, com self-test e mapa em `work/`) **vs.** gate consultivo integrado ao `Invoke-PrePushMechanicalChecks.ps1`. Se virar gate, exige paridade em `13` (lista de gates do orquestrador), `09` e possivelmente `08`.
- Aplicador opcional (corrigir as molduras) ou só detector (sinalizar para revisão).
- Calibração das molduras contra o corpus real (medir falso-positivo antes de promover a gate — falso-positivo em gate destrói a confiança).

**Por que ficou para frente dedicada (e não no push da acentuação):** a frente de acentuação não usou `e/é` (dívida assumida); construir antes do push invalidaria o painel reforçado já convergido e misturaria escopos. Ferramenta ortogonal → frente própria, idealmente em sessão de contexto limpo. Ver a dívida no parágrafo acima.

## Síntese operacional pós-build — descoberta de URL/hosting da aplicação gerada

**Importância:** média
**Maturidade:** ideia

**Origem:** relato de agente em pasta paralela `C:\Dev\Test\Gx_wsEducacaoSpTeste` em 2026-05-17. Após build bem-sucedido, o agente precisou descobrir manualmente como abrir a aplicação gerada, com caminhos diferentes por generator.

### Problema concreto que motiva a ideia

Build bem-sucedido gera aplicação acessível, mas o caminho para abrir varia por generator/environment e não é exposto pela skill `xpz-msbuild-build`. Casos relatados:

- **NETPostgreSQL / .NET Core**:
  - web dir: `C:\KBs\wsEducacaoSpTeste\NETPostgreSQL155\web`
  - hospedagem: `dotnet GxNetCoreStartup.dll` self-host
  - URL: `http://127.0.0.1:50155`

- **NETFrameworkSQLServer / .NET Framework**:
  - web dir: `C:\KBs\wsEducacaoSpTeste\NETFrameworkSQLServer004\web`
  - hospedagem: IIS
  - virtual directory em `applicationHost.config`: `/wsEducacaoSpTesteNETFrameworkSQLServer`
  - URL: `http://localhost/wsEducacaoSpTesteNETFrameworkSQLServer/wwescola.aspx`

A informação existe no ambiente (estrutura de pastas da KB, `applicationHost.config` do IIS) mas o agente precisa reconstruí-la manualmente.

### Direção de implementação

Etapa complementar ao classificador principal de `xpz-msbuild-build`, **não parte dele**. Sugestão de wrapper novo: `scripts/Get-GeneXusRuntimeLaunchInfo.ps1`, retornando JSON com:

- `activeEnvironment` — nome do environment ativo
- `generatorType` — `dotnet-self-host` ou `iis` ou `unknown`
- `webOutputDirectory` — caminho absoluto do diretório `web` gerado
- `hostingStrategy` — string descritiva
- `probableUrl` — URL provável (para self-host: porta do `appsettings.json`; para IIS: virtual directory + entrypoint padrão)
- `entrypoints` — lista de entrypoints conhecidos no `web` (ex.: `developermenu.html`, `wplogin.aspx`, e qualquer objeto web identificado por triagem)

### Escopo recomendado para primeira versão

Cortar pelo caso mais simples primeiro: **só `dotnet self-host`**. IIS exige ler `applicationHost.config` (caminho pode variar, ACL pode bloquear leitura sem elevação) — superfície grande para uma primeira entrega. Adicionar IIS em segunda iteração, somente se houver caso concreto.

### Decisões em aberto

- Onde reside a porta canônica do self-host: `appsettings.json`, `web.config`, ou arquivo gerado pelo build?
- O wrapper deve invocar o runtime para validar que a URL responde, ou só inferir? (Inferir é mais barato e não acopla a wrapper a estado do host.)
- Integração com `Test-GeneXusRuntimeFreshness.ps1` (que verifica frescor do runtime, não descobre URL): coordenação ou independência?

### Relacionado

- `scripts/Test-GeneXusRuntimeFreshness.ps1` — verifica frescor, não cobre descoberta de URL.
- Skill `xpz-msbuild-build` — classificador de build atual, foco no resultado da compilação, não no acesso à aplicação gerada.

## Sinalização de snapshot paralelo defasado após import real

**Importância:** média
**Maturidade:** ideia

**Origem:** relato de agente em pasta paralela `C:\Dev\Test\Gx_wsEducacaoSpTeste` em 2026-05-17. Após importar `Domain DasNeves` via MSBuild na KB nativa `C:\KBs\wsEducacaoSpTeste`, a pasta paralela (`ObjetosDaKbEmXml/` e índice `KbIntelligence/`) permaneceu refletindo o último XPZ full materializado anterior à importação.

### Problema concreto que motiva a ideia

Import real bem-sucedido muda a KB nativa, mas:

- `ObjetosDaKbEmXml/` na pasta paralela só reflete a mudança após novo export/sync/materialização
- `KbIntelligence/` (índice SQLite) idem
- Triagem por índice continua "cega" para o objeto recém-importado até nova materialização

Isso não é erro do wrapper de import — é uma **lacuna de handoff** entre `xpz-msbuild-import-export` e `xpz-sync`/`xpz-doc-builder`. O risco é o usuário (ou outro agente em sessão seguinte) consultar o índice e concluir erroneamente que o objeto não existe.

### Direção de implementação

Ao concluir `Invoke-GeneXusXpzImport.ps1` com sucesso real (import efetivado), enriquecer o JSON de saída com campos de sinalização:

- `kbNativeChanged: true`
- `parallelSnapshotStale: true`
- `importedItems: ["Domain:DasNeves", ...]` (já planejado pela ideia de pós-processamento resiliente)
- `suggestedNextSyncScope: "importedItems"` (sugere escopo mínimo de re-sync, não sync total)
- `parallelSnapshotPath` e `kbIntelligenceIndexPath` quando inferíveis do `kb-source-metadata.md`

A skill **sinaliza**, não **automatiza**. O re-sync continua sendo responsabilidade explícita de `xpz-sync` invocado em frente separada. Acoplar import a sync aumentaria superfície e blast radius do wrapper de import.

### Critério de aceite

Após import real bem-sucedido na KB nativa, o JSON do wrapper precisa expor de forma máquina-legível que (a) houve mudança efetiva na KB nativa, (b) o snapshot paralelo desta pasta está defasado, (c) quais objetos foram importados. O agente seguinte deve conseguir tomar decisão de re-sync apenas lendo esse JSON, sem inspecionar manualmente a KB nativa.

### Decisões em aberto

- Onde fica a inferência de `parallelSnapshotPath`/`kbIntelligenceIndexPath`: dentro do wrapper de import (leitura de `kb-source-metadata.md`) ou em camada separada?
- Comportamento quando o wrapper rodar **fora** de pasta paralela conhecida (caso de uso direto na KB nativa, sem snapshot paralelo): omitir os campos ou marcar `parallelSnapshotKnown: false`?
- Coordenação com a ideia de pós-processamento resiliente (Problema 2): os dois mexem no contrato de saída do mesmo wrapper, melhor consolidar em uma frente.

### Relacionado

- Skill `xpz-sync` — receptora natural da próxima ação sugerida.
- `kb-source-metadata.md` — fonte canônica para localizar pasta paralela e índice.

## Auditoria de drift de identidade estável da KB

**Importância:** média
**Maturidade:** ideia

**Origem:** revisão crítica pós-fechamento da frente `Resolve-GeneXusKbIdentity` em 2026-05-20. A frente original de preenchimento de metadata vazio foi registrada em `historico/IdeiasImplementadas_202605.md`; esta é uma frente nova, limitada a auditoria de drift quando o metadata já está preenchido.

### Problema concreto

A auditoria atual detecta `kb-source-metadata.md` ausente, campos críticos vazios, GUID inválido e wrapper `Get-*KbMetadata.ps1` incapaz de expor os campos documentados. Isso cobre metadata incompleto ou quebrado.

Ela não prova, porém, que identidade preenchida e sintaticamente válida ainda corresponde à KB nativa local atual. Casos possíveis:

- GUID antigo depois de recriar, mover ou substituir a KB nativa
- `kb-source-metadata.md` copiado de outra pasta paralela
- `username` ou `UNCPath` defasados, com GUID ainda válido
- valores preenchidos manualmente no passado

Nesses casos, `Test-XpzKbMetadataWrapper.ps1` pode retornar `METADATA_WRAPPER_OK`, porque compara o wrapper contra o próprio `kb-source-metadata.md`; `Test-XpzSetupAudit.ps1` propaga essa dimensão, mas não chama `Resolve-GeneXusKbIdentity.ps1` para comparar metadata gravado contra identidade resolvida agora.

### Direção de investigação

Adicionar uma comparação somente leitura de identidade estável ao fluxo de auditoria, sem transformar `Resolve` em fallback ad hoc de `xpz-sync`, `xpz-builder` ou import MSBuild.

Alternativas a avaliar:

- estender `scripts/Test-XpzSetupAudit.ps1` para executar uma comparação read-only quando houver caminho de KB nativa local confiável
- criar gate dedicado, por exemplo `scripts/Test-XpzKbIdentityDrift.ps1`
- reaproveitar `scripts/Update-XpzKbSourceMetadataIdentity.ps1 -WhatIf` se a saída for suficientemente estável e legível para auditoria

### Critério de aceite

Uma pasta com `kb-source-metadata.md` preenchido, wrappers de metadata OK e identidade divergente da KB nativa local deve produzir finding explícito de drift de identidade. A correção automática continua proibida: preenchimento ou sobrescrita de campos deve seguir por frente aprovada de reconciliação via `Update-XpzKbSourceMetadataIdentity.ps1`.

### Relacionado

- `historico/IdeiasImplementadas_202605.md` — caso concluído de preenchimento de metadata a partir da KB nativa quando o XPZ vem com `Source` vazio
- `scripts/Resolve-GeneXusKbIdentity.ps1`
- `scripts/Update-XpzKbSourceMetadataIdentity.ps1`
- `scripts/Test-XpzSetupAudit.ps1`
- `scripts/Test-XpzKbMetadataWrapper.ps1`

## Dry-run com diff unificado padronizado em scripts de escrita XPZ

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `00ecd7d feat(worker): standardized dryRun plan with unified diff and impact seam`
- `5331ca1 feat(worker): genexus_edit returns post_state.diff by default`

Anti-duplicata: buscado em 999/998 por `dry.?run|diff unificado|post.?state|WhatIf` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado nesta sessão — detalhes finos de formato/contrato devem ser confirmados nos commits-âncora antes da implementação.

### Problema concreto que motiva a ideia

Skills que escrevem em disco — `xpz-builder` (gera `import_file.xml`), `xpz-sync` (materializa XMLs a partir de XPZ exportado), `xpz-msbuild-import-export` (consome XPZ na IDE) — hoje executam mutação sem mostrar consistentemente um plano "antes/depois" para o agente. PowerShell tem `-WhatIf` nativo, mas adoção e formato não são padronizados entre wrappers.

No FBgx18MCP, o padrão adotado é: toda escrita devolve `post_state.diff` por padrão, em formato diff unificado. O agente vê o que vai mudar antes de aplicar (ou imediatamente após, com chance de rollback declarado).

### Design em aberto

- **Formato do diff**: texto unificado linha-a-linha (universal, fácil de ler) vs XML diff por part (semântico, mais útil pra XPZ mas exige biblioteca). Escolha provavelmente varia por contexto.
- **Adoção gradual ou universal**: começar por `xpz-builder` (alto risco, escrita de pacote final), depois `xpz-sync`?
- **`post_state` ou `pre_state` + plano**: o MCP devolve `post_state.diff` após a operação real; em PowerShell faz mais sentido oferecer `-DryRun` que devolve o plano sem executar.

### Decisões em aberto

- Qual estrutura de saída adotar? JSON com campo `diff` (string), ou objeto estruturado com `added[]/removed[]/changed[]`?
- Como sinalizar quando o diff é truncado por tamanho (ver ideia "Resposta mínima por padrão" abaixo)?

### Relacionado

- `xpz-builder/SKILL.md`, `xpz-sync/SKILL.md`, `xpz-msbuild-import-export/SKILL.md`
- `02-regras-operacionais-e-runtime.md` (sede natural da regra geral)
- Ideia "Idempotência declarativa" abaixo tem sobreposição: dry-run mostra; idempotência detecta repetição.

## Idempotência declarativa em wrappers de escrita XPZ

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commit-âncora:

- `6e266ee feat(gateway): IdempotencyCache + IdempotencyMiddleware on write tools`

Anti-duplicata: buscado em 999/998 por `idempot|colis|hash do payload` em 2026-05-17. Matches encontrados foram restritos a perguntas sobre operações específicas (`RestoreModule`, `CompressKB`), não cobrem a ideia generalizada. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

A regra `Test-XpzPackageCollision.ps1` (já citada em `README.md`) é exatamente um caso particular de idempotência: chave = `NomeCurto_GUID_YYYYMMDD_nn`; em colisão, aborta e sugere próximo `nn` livre. O conceito ainda **não foi promovido a princípio operacional** aplicável a outras escritas (geração de XMLs em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, snapshots de metadados, recriação de pasta paralela).

No FBgx18MCP, `IdempotencyCache` é middleware: toda escrita declara chave por hash do payload; chamada repetida com mesma chave é no-op declarada (não silenciosa).

### Design em aberto

- **Chave canônica por contexto**: pacote = nome+nn; geração de XML = guid+lastUpdate; metadados = hash do conteúdo. Cada escrita declara sua chave.
- **Onde mora o cache**: arquivo `.idempotency.json` na pasta da frente (`NomeCurto_GUID_YYYYMMDD/`)? Tabela no `KbIntelligence/`? Em memória apenas?
- **No-op declarado vs silencioso**: usuário sabe que "rodada repetida foi detectada", não só vê sucesso silencioso.

### Decisões em aberto

- TTL/expiração do cache? Pacotes ficam por tempo indeterminado; chave de geração talvez expire por sessão.
- Como integrar com `-DryRun` (ideia anterior): dry-run também consulta a chave e reporta "essa operação já foi feita"?

### Relacionado

- `Test-XpzPackageCollision.ps1` (caso particular já existente)
- `02-regras-operacionais-e-runtime.md` (sede natural da regra)
- Wrappers candidatos: `Sync-GeneXusXpzToXml.ps1`, `xpz-builder` (geração de pacote)

## Resposta mínima por padrão + `empty_reason` + `suggested_next` em scripts de consulta

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `915750b feat(worker): minimal-by-default list shape; verbose=true opt-in`
- `2447965 feat(worker): _meta.suggested_next on list_objects`
- `35d4afc feat(worker): _meta.suggested_next on query/structure/search`
- `545ac74 feat(worker): _meta.aggregates and empty_reason on list responses`

Anti-duplicata: buscado em 999/998 por `empty_reason|suggested_next|resposta m[ií]nima|verbose` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

Os scripts `-Query` da trilha `KbIntelligence` (em `scripts/`) e a saída de `xpz-index-triage` hoje retornam estruturas razoavelmente verbosas mesmo quando o agente só precisa de uma confirmação curta. Pior: quando o resultado é vazio, **não dizem por quê**, e o agente "chuta" o próximo passo. Isso queima tokens e turnos.

No FBgx18MCP, o contrato adotado é:

- Lista vem **mínima por padrão**; `verbose=true` traz detalhes.
- Quando vazio, devolve `empty_reason` estruturado ("nenhum objeto com tipo X", "filtro Y excluiu N candidatos", etc.).
- Devolve `suggested_next`: próximo passo recomendado em forma executável (ex: `tente Get-XpzObjects -Type WebPanel sem filtro de Family`).

### Design em aberto

- **Onde aplicar primeiro**: `xpz-index-triage` é o candidato natural (vocação de triagem curta). Scripts `-Query` do `KbIntelligence` em segundo.
- **Forma do `suggested_next`**: string com comando literal? Objeto com `command`+`reason`? Lista de alternativas?
- **`empty_reason` taxonômico**: vocabulário fechado (ex: `no-matches`, `filter-too-narrow`, `index-stale`, `kb-not-resolved`) vs string livre.

### Decisões em aberto

- Como conviver com o `-Verbose` nativo do PowerShell? Provável: `verbose=true` como parâmetro próprio do contrato JSON, distinto do `-Verbose` switch.
- Output em PowerShell é "objeto" por natureza; aplicar literalmente "resposta mínima por padrão" exige `Select-Object` por padrão e `-Full` opt-in.

### Relacionado

- `xpz-index-triage/SKILL.md`
- `scripts/README-kb-intelligence.md`
- `02-regras-operacionais-e-runtime.md` (regra geral de contrato de saída)

## Did-you-mean / sugestão por edit-distance em erros de parâmetro de scripts XPZ

**Importância:** baixa
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commit-âncora:

- `8218122 feat(gateway): genexus_whoami MCP tool, edit schema validation with did-you-mean, GeneXus version check`

Anti-duplicata: buscado em 999/998 por `did.?you.?mean|fuzzy|edit.?distance` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

Scripts PowerShell que recebem `-Type`, `-Family`, `-Name` ou outros enums frequentemente falham com erro genérico ("parâmetro X não é válido") quando o agente passa valor próximo do correto ("Transactioon" em vez de "Transaction"). O agente então gasta turno experimentando variações.

No FBgx18MCP, o validador de schema de `genexus_edit` calcula edit-distance contra valores conhecidos e sugere o termo provável ("did you mean: ...").

### Design em aberto

- **Dicionário-fonte por parâmetro**: enum hardcoded? Lê do índice (`KbIntelligence/` para nomes de objeto)? Mix?
- **Threshold de edit-distance**: 1, 2, ou proporcional ao tamanho?
- **Onde aplicar primeiro**: parâmetros com domínio fechado e pequeno (`-Type`) trazem mais benefício; `-Name` contra catálogo de 15k objetos é caro e talvez fora de escopo.

### Decisões em aberto

- Implementação: helper compartilhado em `scripts/_lib/` ou cópia por script?
- Comportamento: continua erro fatal com sugestão, ou erro recuperável "vou usar X?". Provavelmente erro fatal — não deduzir.

### Relacionado

- Wrappers candidatos: qualquer um que valide enums (build, sync, import-export, triage)

## Pré-push: reduzir dependência de interpretação em `.md` (opções B e C)

**Importância:** média
**Maturidade:** ideia — **reavaliar** após a frente pré-push estabilizada em produção (orquestrador + regra em camadas + satélites) e mais um ciclo de testes com prompt mínimo («executar rotina pré-push»).

**Origem:** conversa em 2026-05-22. Testes com Codex, Claude e Cursor no mesmo intervalo (22 commits): o orquestrador alinhou fatos (git, parse, `PUSH_READINESS`), mas gaps documentais divergiram (1 vs 5) conforme a profundidade da leitura semântica de `.md`. Conclusão: `Invoke-PrePushMechanicalChecks.ps1` resolveu risco **operacional**, não risco **editorial/semântico** completo.

### Modelo vigente (opção A — adotado, não é pendência)

- **Mecânico:** `scripts/Invoke-PrePushMechanicalChecks.ps1` + parse global (`Test-PsScriptsParse.ps1`).
- **Semântico:** agente lê `AGENTS.md` / `08`, busca cruzada, relatório (gaps / flags descartados / não coberto), sem auto-gravação.
- **Humano:** aprova correções e push; segundo agente ou segunda passagem em frentes grandes quando fizer sentido.

Não substituir A por B ou C sem evidência de que o custo de manutenção compensa.

### Opção B — lints mecânicos pontuais (scripts de coerência documental)

Heurísticas em `.ps1` (ex.: `Test-DocContractCoherence.ps1` ou extensão do orquestrador) para casos recorrentes já vistos na pré-push, sem NLP:

- satélite de checklist (`quality-checklist.md`) desalinhado de termos obrigatórios no `SKILL.md` da mesma skill;
- skills que citam `Build-GeneXusImportFileEnvelope.ps1` sem mencionar `-AcervoPath` / `-ModifiedObjectNames` / `-ModifiedObjectGuids` no mesmo arquivo (handoff MSBuild);
- scripts novos em `scripts/` no intervalo ausentes de `09-inventario-e-rastreabilidade-publica.md` (se a política do inventário for mantê-lo atualizado);
- opcional: `README.md` trilíngue citando helper sem parâmetros que `02`/`08` já tornaram obrigatórios (alto risco de falso positivo por ser resumo).

**Prós:** menos variância entre agentes nos mesmos gaps; falha/warning objetivo. **Contras:** cada regra vira dívida de manutenção; falsos positivos; não cobre nuances (ex.: cross-ref WWP em `02`).

### Opção C — contrato machine-readable paralelo ao `.md`

Schema (JSON/YAML) com parâmetros obrigatórios por script, satélites obrigatórios por skill, entradas de inventário — consumido por lint/CI e, no futuro, por agentes.

**Prós:** verificação determinística de contrato. **Contras:** duplicação com prosa em `SKILL.md`/`02`; custo alto de adoção e sincronização; só vale se várias ferramentas consumirem o mesmo schema.

### Gatilho sugerido para reavaliar B ou C

- Repetição do mesmo gap semântico em duas pré-push seguidas **depois** de endurecer `AGENTS.md` (handoff, README, `09`).
- Ou decisão explícita de fechar frente editorial (ex.: `quality-checklist` + `xpz-msbuild-import-export`) e medir se ainda há divergência entre agentes.

### Relacionado

- `scripts/Invoke-PrePushMechanicalChecks.ps1`, `AGENTS.md` (Revisão pré-push), `08-guia-para-agente-gpt.md`
- Gap **fechado** (2026-05-22): `xpz-builder/quality-checklist.md` vs `xpz-builder/SKILL.md` (`lastUpdate` / `-AcervoPath`) — alinhado nos commits `1e17d5d`, `7fa279a` e `46cfe30`; pré-push semântica do mesmo dia não reabriu o item. A heurística da opção B (checklist vs `SKILL.md`) permanece como candidata a lint, não como pendência aberta.

## Ciclo de friction-report datado como motor de evolução das skills XPZ

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora (mostram o ciclo):

- `0a5214b perf+fix(v2.3.5): preventive perf audit + friction-report 2026-05-14 sweep`
- `5296f75 fix(v2.3.5): second pass on friction-report 2026-05-14 (#2 #3 #4 #5 #11 #14 #15 #16 #17)`
- `0a673b3 fix(worker,gateway): close 8 items from mcp-friction-report-2026-05-13`
- `e10d382 fix(mcp): address 5 friction items from session report`

Anti-duplicata: buscado em 999/998 por `friction|fric[çc][ãa]o|relat[óo]rio de uso` em 2026-05-17, sem match.

### Problema concreto que motiva a ideia

O repo já tem `999-ideias-pendentes.md` (backlog de ideias estruturadas) e `998-ideias-descartadas-e-porque.md` (memória de não-fazer). O que falta é o **artefato datado de fricção observada em uso real** — separado do backlog conceitual. Esse artefato faz a ponte uso real → backlog → fix.

No FBgx18MCP, o padrão é: cada release significativa tem um `mcp-friction-report-YYYY-MM-DD.md` listando itens numerados. Commits posteriores referenciam explicitamente "closes #3 #4 #5 from friction-report-YYYY-MM-DD". Essa rastreabilidade dá ao mantenedor visão de "quanto da fricção observada virou fix".

### Design em aberto

- **Pasta sede**: `historico/friction-reports/`? Raiz com prefixo numérico (ex: `13-friction-reports/`)?
- **Esquema**: itens numerados, severidade (baixa/média/alta/bloqueante), origem (sessão, skill, contexto), estado (aberto/fechado), commit que fechou.
- **Quem captura**: o agente, ao final de sessão complexa, propõe entradas? O usuário, manualmente? Híbrido?
- **Relação com 999**: itens de friction-report viram entradas em 999 quando exigem design, ou ficam só no report quando são fix mecânico?

### Decisões em aberto

- Política de captura: oportunista (quando lembra) vs sistemática (toda sessão fecha com pergunta "houve fricção?").
- Histórico longo: quando arquivar reports antigos.

### Relacionado

- `998-ideias-descartadas-e-porque.md`
- `999-ideias-pendentes.md`
- `historico/` (sede candidata)

## Comandos `doctor` e `whoami` para `xpz-skills-setup`

**Importância:** média
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `c464165 feat(cli): onboarding UX — auto-discovery, whoami, uninstall, kb catalog + docs`
- `8218122 feat(gateway): genexus_whoami MCP tool, edit schema validation with did-you-mean, GeneXus version check`

Anti-duplicata: buscado em 999/998 por `doctor|whoami` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

A skill `xpz-skills-setup` já audita o registro de skills XPZ cross-tool (Claude/Codex/Cursor/OpenCode) e oferece resolução de gaps. Faltam dois comandos irmãos com utilidade alta:

- **`doctor`**: verifica saúde do ambiente — frescor do índice (`last_index_build_run_at` vs `last_xpz_materialization_run_at`), drift documental local, `GATE_OK` semântico, existência de skills em todas as ferramentas registradas. Devolve relatório taxonômico (`ok/warn/err`).
- **`whoami`**: lista quais skills XPZ estão ativas neste host, em qual ferramenta, apontando para a fonte (caminho do symlink/junction). Útil quando o usuário tem múltiplas instalações ou faz troubleshooting.

### Design em aberto

- **Forma**: scripts `.ps1` em `xpz-skills-setup/`, ou novos verbos da skill?
- **Saída**: JSON estruturado por padrão (consumível por agente) com formatação humana opcional.
- **`doctor` cobertura**: começa enxuto (registro de skills + frescor do índice) e cresce por demanda; tentar cobrir tudo de uma vez é armadilha.

### Decisões em aberto

- Onde ficam os checks individuais? Funções em `xpz-skills-setup/_lib/` agregadas pelo `doctor`?
- Integração com regra do `AGENTS.md` global sobre "auditoria pós-git-pull" — `doctor` é o canal natural.

### Relacionado

- `xpz-skills-setup/SKILL.md` (sede principal)
- Regra "Após git pull" no AGENTS.md global do usuário

## Modo `-Async` + long-poll de status em `xpz-msbuild-build` e `xpz-msbuild-import-export`

**Importância:** baixa
**Maturidade:** ideia

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `6501de2 feat(gateway): async lifecycle build with sync fast-path for short estimates`
- `518169f feat(gateway): long-poll on lifecycle status when wait_seconds is set`
- `51bc64c feat(gateway): BackgroundJobRegistry for async job tracking`
- `ff9c38e feat(gateway): piggyback background_jobs on every response when active`

Anti-duplicata: buscado em 999/998 por `long.?poll|ass[íi]ncron|background.?job` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

`xpz-msbuild-build` e `xpz-msbuild-import-export` rodam MSBuild que pode tomar minutos em KB grande. Hoje o wrapper é síncrono — o agente fica bloqueado, e timeouts de orquestração (ex: limite de execução de comando do harness) podem abortar prematuramente.

No FBgx18MCP, build longo vira job em background; o canal MCP devolve `job_id` rápido; agente faz `Get-Status -JobId -WaitSeconds N` quando quiser, com fast-path síncrono para builds curtos estimados.

### Design em aberto

- **Heurística de fast-path**: como decidir "build curto"? Por tamanho da KB? Histórico de builds passados? Always-async com poll imediato é mais simples.
- **Sede do registry**: arquivo JSON em `Temp/` com PID + status? Process job nativo do Windows?
- **Política de cleanup**: jobs concluídos ficam por quanto tempo?
- **Cancelamento**: agente pode pedir kill do job? Provavelmente sim, com gate.

### Decisões em aberto

- PowerShell tem `Start-Job` nativo, mas estado vive na sessão. Para sobreviver a fim de sessão, precisa de wrapper baseado em processo + arquivo de estado.
- Como integrar com a regra "operação concluída, pendente de confirmação funcional" do classificador atual.

### Relacionado

- `xpz-msbuild-build/SKILL.md` (sede principal)
- `xpz-msbuild-import-export/SKILL.md`
- `scripts/Invoke-GeneXusKbBuildAll.ps1` e equivalente de import

## Catálogo semântico de operações em `xpz-builder` (alternativa a edição XML livre)

**Importância:** média
**Maturidade:** ideia (primeira operação materializada)

**Atualização (2026-06-08, Frente C):** a primeira operação do catálogo foi **materializada** — `scripts/Add-GeneXusButton.ps1` adiciona botão a `WebPanel` (forma `<action>`/`<ucw>`, inserção em tabela Flex após controle folha nomeado, stub de `Event`, bump de `lastUpdate`, fail-closed `RESPONSIVE_UNSAFE`); regressão em `scripts/Test-GeneXusAddButtonContract.ps1`. O restante do catálogo (outras operações e tipos) permanece ideia.

**Atualização (2026-06-09):** o `Add-GeneXusButton.ps1` ganhou a âncora simétrica `-BeforeControlName` (insere a nova `<cell>` **antes** da célula do controle folha; mutuamente exclusiva com `-AfterControlName` via parameter sets). Reusa toda a validação fail-closed existente (folha, `RESPONSIVE_UNSAFE`, unicidade) sem alteração; o primitivo `Invoke-GeneXusXmlLiteralPatch` em `GeneXusXmlSurgicalEditSupport.ps1` ganhou o modo `InsertBefore`. Permanecem ideia, neste mesmo helper: âncora por tabela nomeada / inserção como última célula, célula não-folha e reescrita segura de `responsiveSizes` em Responsive preenchido.

### Insumo da `nexa`: piloto de correspondência semântica para propriedades XPZ

**Origem (2026-07-26):** estudo comparativo da skill `nexa`, mantida no repositório `genexuslabs/genexus-skills`, frente aos catálogos, moldes e gates desta base.

Antes de implementar `Set-XpzTransactionProperty`, avaliar um piloto de correspondência entre o conceito documentado pela `nexa` e sua serialização XPZ empiricamente comprovada. Exemplo inicial: conceito `Business Component` na `nexa` versus propriedade `idISBUSINESSCOMPONENT` no XML XPZ.

O piloto deve registrar, para cada candidata:

- conceito e referência de origem na `nexa`;
- nome efetivo da propriedade no XML XPZ;
- tipo e valores serializados observados;
- evidência XPZ (`confirmado-import`, `confirmado-build`, `confirmado-acervo` ou não comprovado);
- versão GeneXus em que a evidência foi obtida;
- estado da correspondência: confirmada, parcial, contraditória ou ainda não comprovada.

A `nexa` é fonte semântica e lista de candidatas, **não** autoridade de serialização XPZ. Nenhum nome, valor padrão, enumeração ou restrição deve migrar automaticamente de artefatos `.gx`/GeneXus Next para XPZ de GeneXus 18 ou formato legado. A autoridade operacional continua sendo XML comparável, molde sanitizado e evidência real de importação/build desta trilha.

O piloto só deve virar contrato de escrita após provar valor sobre leitura/validação e fechar o mapeamento com evidência suficiente. Também é válido concluir que a correspondência não cabe no catálogo semântico, que outro tipo de objeto é piloto melhor ou que a ideia deve ser descartada.

**Margem de reavaliação:** quem retomar deve reler o estado atual da `nexa` e desta base, verificar se já existe mecanismo equivalente e redesenhar o piloto se necessário; este registro não fixa `Transaction`, o formato da tabela nem `Set-XpzTransactionProperty` como implementação obrigatória.

### Desdobramentos derivados (registrados em 2026-06-09, sem código)

Ao avaliar "outros tipos poderiam ter inserção como o botão", separar duas camadas — a generalização barata (mesmo modelo estrutural) das operações de tipo diferente (cada uma é frente própria):

- **`Add-GeneXusControl` — generalizar o botão para outros controles do mesmo modelo de célula de WebPanel/Panel.** O `Add-GeneXusButton` já resolve a parte difícil: subir ao `<cell>` folha do controle-âncora, validar folha, aplicar a guarda `RESPONSIVE_UNSAFE`, delimitar a célula literal, checar unicidade e aplicar `InsertBefore`/`InsertAfter`. Para inserir um `textblock`, um controle de atributo/variável, uma imagem etc., **só muda o snippet da `<cell>`** — toda a navegação e o fail-closed se reusam. O botão é um caso particular. Desenho provável: extrair a máquina comum (resolução de âncora + validação + patch) e parametrizar o corpo da célula por tipo de controle, mantendo `Add-GeneXusButton` como atalho fino por cima. Custo baixo, alto valor; candidato natural ao próximo passo do catálogo no eixo WebPanel.
- **Expor `InsertBefore` no wrapper geral `Edit-GeneXusXmlSurgical.ps1`.** Hoje o wrapper geral (edição de `Source`/`Rules`/`CDATA` de **qualquer** tipo) só expõe `Replace`/`InsertAfter` por `ValidateSet`, embora o primitivo `Invoke-GeneXusXmlLiteralPatch` já aceite `InsertBefore` (subconjunto intencional documentado em comentário no `Invoke-GeneXusXmlSurgicalEditCore`). Expor `InsertBefore` ali é uma adição pequena e **agnóstica a tipo**, beneficiando todos os tipos de uma vez. Só fazer quando houver caso de uso concreto de "inserir antes de uma âncora literal" fora do botão (evitar superfície especulativa); ao fazer, propagar contrato/doc do wrapper (`.PARAMETER EditMode`, `08`, `xpz-builder/SKILL.md`, exemplo e teste de contrato).
- **Operações semânticas para tipos de modelo diferente (Transaction, Procedure, Grid, SDT).** Já previstas acima neste mesmo verbete (`Add-XpzAttributeToTransaction`, `Set-XpzTransactionProperty`, `Add-XpzVariableToProcedure`). A máquina do botão **não** transfere: níveis/atributos/`Rules` de Transaction, `Source`/`Variables` de Procedure, colunas de Grid têm navegação e invariantes próprios, e um insert ingênuo ali é **mais** arriscado (chaves estrangeiras, subtype groups, ordem de nós) — exigem design de invariantes e fail-closed dedicados, um helper por vez com seu próprio teste. Não derivar do botão por analogia.

### Âncora por tabela nomeada / inserir como última célula (`-TableName`) — para retomar em outra sessão

**Maturidade:** ideia (avaliada em 2026-06-09; sem código). **Onde entraria:** `scripts/Add-GeneXusButton.ps1`, como um terceiro parameter set (ex.: `LastCellOfTable`) ao lado de `After`/`Before`, recebendo `-TableName` em vez de um controle-âncora.

**O que é:** hoje `Add-GeneXusButton` só ancora em **controle folha nomeado** (`-AfterControlName`/`-BeforeControlName`) e insere a nova `<cell>` ao lado da célula desse controle. Falta a forma "insira como **última célula** de uma **tabela nomeada**", em que a âncora é a própria `<table controlName="X">`, não um controle dentro dela. (Citada no relato/avaliação original como "última célula de uma tabela nomeada".)

**Por que NÃO é simétrica ao `-Before`/`-After` (foi o que tornou aqueles baratos):** em `-Before`/`-After` a âncora é um controle **único e determinístico**; o script sobe dele até a `<cell>` folha (`ancestor-or-self::cell[1]`), valida e insere ao lado. Em `-TableName` a âncora é a tabela, e "última célula" é **ambíguo e estrutural**. Três armadilhas concretas:

1. **"Última célula" é ambíguo em tabela com linhas.** A estrutura é `table > row > cell`. Em tabela Flex sem `row` explícito, "última célula" é clara. Mas com várias `<row>`, "última célula" pode significar (a) última célula da última linha, (b) **nova** célula numa nova linha ao final, ou (c) última célula de uma linha específica. Precisa de decisão de contrato explícita antes de codar — `-Before`/`-After` nunca enfrenta isso porque a âncora já é uma célula concreta.
2. **Filhas diretas vs. aninhadas.** "Última `<cell>` filha **direta** da tabela X" exige distinguir `table[@controlName=X]/row/cell` das células de tabelas **aninhadas** dentro dela. Um `LastIndexOf('</cell>')` ingênuo no texto pegaria o fechamento de uma célula aninhada profunda, não o da última célula de topo. Tem que navegar estruturalmente (ex.: `//table[@controlName='X']/row[last()]/cell[last()]`, ou o equivalente quando não há `row`) e só então mapear de volta ao texto literal para o patch — mais frágil que o caminho atual, que ancora num `controlName` único e já validado.
3. **A guarda de Responsive fica mais nervosa.** Inserir "ao final de uma tabela" é exatamente onde mais se mexe no array `responsiveSizes` (a última posição costuma ser a descrita por último nos breakpoints). O fail-closed `RESPONSIVE_UNSAFE` continua valendo, mas o caso de uso "real mais comum" cairia nele quase sempre — ou seja, entregaria **pouco valor** sem a reescrita de breakpoints, que é justamente o que a skill recusa por design. Não acoplar este item à reescrita de `responsiveSizes`.

**Como atacar (esboço, quando houver demanda):** reusar a máquina já existente do helper — guarda `RESPONSIVE_UNSAFE`, validação de folha da célula-alvo, derivação da âncora literal e checagem de unicidade, patch via `Invoke-GeneXusXmlLiteralPatch` (com `InsertAfter` sobre a **última célula** encontrada). O trabalho novo é só: (i) resolver a tabela por `controlName` (incluindo o caso de tabela aninhada com mesmo nome → tratar como `ANCHOR_NOT_UNIQUE`), (ii) localizar estruturalmente a última `<cell>` filha **direta**, (iii) **decidir e documentar** qual semântica de "última" o contrato adota (recomendado começar pelo caso simples: tabela Flex de uma linha, sem `row` explícito, e recusar fail-closed os casos com múltiplas `<row>` até haver decisão — `MULTIROW_AMBIGUOUS` ou similar). Teste de regressão espelhando `Test-GeneXusAddButtonContract.ps1`. Manter o padrão fail-closed: na dúvida estrutural, abortar com código próprio em vez de adivinhar a posição.

**Relacionado:** `scripts/Add-GeneXusButton.ps1` (sede), `scripts/GeneXusXmlSurgicalEditSupport.ps1` (primitivo de patch), `scripts/Test-GeneXusAddButtonContract.ps1` (regressão), `xpz-builder/responsibilities-by-type/webpanel.md` (regra de botão). Ver também, neste mesmo verbete, o desdobramento `Add-GeneXusControl` — se ele for feito antes, esta âncora deve nascer já na máquina generalizada, não só no botão.

**Origem:** alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17. Commits-âncora:

- `1efd0c1 feat: wire mode:ops end-to-end through gateway and worker`
- `5659cab feat(worker): SemanticOpsService catalog with attribute, rule, and generic set_property ops`
- `21a67ca feat: JSON-Patch (RFC 6902) edit mode over canonical JSON`

Anti-duplicata: buscado em 999/998 por `cat[áa]logo sem[âa]ntico|semantic.?ops|set_property` em 2026-05-17, sem match. Limitação: código C# do FBgx18MCP não inspecionado.

### Problema concreto que motiva a ideia

`xpz-builder` hoje apoia a materialização de artefatos XPZ a partir de moldes sanitizados (`01e` a `01h`). A geração inclui edição de XML cru, que tem superfície de risco grande: agente pode inserir tag malformada, atributo fora do contrato, ordem errada de elementos.

No FBgx18MCP, a evolução foi: além de edição livre, oferecer um **catálogo de operações estruturais nomeadas** (`set_property`, `add_attribute`, regras específicas por tipo de objeto). Cada operação é auditável, testável e tem schema próprio.

Para `xpz-builder`, isso significaria expor um vocabulário de operações de alto nível (ex: `Add-XpzAttributeToTransaction`, `Set-XpzTransactionProperty`, `Add-XpzVariableToProcedure`) por cima do XML, validadas contra os padrões empíricos já documentados em `01a-catalogo-e-padroes-empiricos.md`.

### Design em aberto

- **Cobertura inicial**: começar pelos tipos mais arriscados de edição cega (`Transaction` em `05-...`, `WebPanel` em `04-...`) e operações mais frequentes.
- **Forma**: cmdlets PowerShell `Verb-XpzNoun` com schema validado, ou um único `Invoke-XpzOp -Op <name> -Args @{}`.
- **Relação com moldes**: operação semântica é "molde paramétrico" — ponte natural entre `xpz-builder/responsibilities-by-type/` e este catálogo.
- **JSON-Patch RFC 6902**: o MCP também oferece edição via JSON-Patch sobre representação canônica. Para PowerShell, JSON-Patch sobre XML transformado tem custo de design alto e provavelmente fica fora do escopo inicial.

### Decisões em aberto

- Que tipos cobrir primeiro?
- Como conviver com edição livre (não eliminar — deixar como fallback para casos que o catálogo não cobre).

### Relacionado

- `xpz-builder/SKILL.md` e `xpz-builder/responsibilities-by-type/`
- `01a-catalogo-e-padroes-empiricos.md` (fonte de validação dos padrões)
- `01e-moldes-sanitizados-core.md` a `01h-moldes-sanitizados-metadados-e-artefatos.md` (insumo)

## Reclassificar `queryableByKbIntelligence` de `SmartDevicesApplication` após medição de grafo

**Importância:** média
**Maturidade:** pesquisa feita

**Origem:** fechamento da frente Evo1 / prompts externos de pasta paralela (KB com addon Smart Devices Plus, GeneXus 18 U13), 2026-05-30. Entrada no catálogo upstream em commit `1866c52`; self-test fixture Evo1 descartado em `998-ideias-descartadas-e-porque.md`.

### Problema concreto que motiva a ideia

`SmartDevicesApplication` entrou em `scripts/gx-object-type-catalog.json` com `queryableByKbIntelligence=true` por analogia a tipos com `Source` e eventos. `SmartDevicesPlus` (mesmo addon) ficou com `queryableByKbIntelligence=false` porque o motor atual só vê `Properties` — consultas semânticas vazias enganam.

Ainda **não** houve medição empírica de arestas de entrada/saída no índice para `SmartDevicesApplication` (Part dashboard embutido + `Source` com eventos). Se o grafo for zero ou irrelevante, a flag deveria ser `false` e a nota do JSON/`01a`/`scripts/README-kb-intelligence.md` alinhadas — mesmo padrão já aplicado a `SmartDevicesPlus`.

### Ideia de melhoria

Em **qualquer** pasta paralela com objetos `SmartDevicesApplication` materializados (não precisa ser Evo1):

1. rebuild do índice com motor atual;
2. contagem de arestas envolvendo objetos desse tipo (consulta ao SQLite ou script de amostra existente, ex. `scripts/Invoke-ParallelKbEnvelopeScan.ps1` + inspeção de grafo);
3. se grafo zero ou assimétrico sem relações úteis → `queryableByKbIntelligence=false` no catálogo + documentação;
4. se houver arestas reais → manter `true` e registrar evidência breve em `01a` ou `09`.

### Limiar para implementar

Implementar quando houver acesso a uma KB com addon SDP materializada **ou** quando um usuário da base reportar `who-uses`/`impact-basic` enganoso para `SmartDevicesApplication`. Não reabrir fixture Evo1 no código de teste.

## Estender `Compare-GeneXusPanelShape` a WebPanel (equivalência de shape em clone)

**Importância:** baixa-média
**Maturidade:** ideia

**Origem:** decorrência da Frente A (inspetor de shape de WebPanel, sessão 2026-06-08). O relato externo pediu o inspetor, não a comparação; por decisão explícita do usuário, `Compare-GeneXusPanelShape.ps1` permanece Panel-only. Hoje, ao receber WebPanel, o script orienta o usuário ao bloco `webpanel` de `Get-GeneXusObjectSummary.ps1` em vez de comparar.

### Problema concreto que motiva a ideia

`Compare-GeneXusPanelShape.ps1` confronta dois Panels por shape compacto (level/layout, controles, cobertura action/event) para validar equivalência antes de concluir clonagem. Para WebPanel, `xpz-builder/responsibilities-by-type/webpanel.md` já manda validar equivalência em clone (ex.: `fieldSpecifier`), mas não há confronto de shape automatizado análogo. Um `Compare` ciente de WebPanel diffaria `tables`/`tableType`, `controls`, `buttons` e `eventNames` — sinais que o bloco `webpanel` já produz.

### Design em aberto

- **Forma:** estender `Compare-GeneXusPanelShape` para despachar por tipo (Panel vs WebPanel) ou criar `Compare-GeneXusObjectShape` genérico type-aware. O nome atual sugere Panel; um genérico envelheceria melhor.
- **Sinais a confrontar no WebPanel:** `tables` (controlName+tableType+depth), `controls`, `buttons` (forma/event/caption), `eventNames`, `coverage` — reusando o bloco `webpanel` do summary, como o Compare de Panel já reusa o bloco `panel`.
- **`Read-Summary`:** hoje força `ObjectType='Panel'`; um Compare type-aware precisaria resolver o tipo real de cada lado.

### Limiar para implementar

Implementar quando surgir necessidade recorrente concreta de confrontar dois WebPanels por shape (ex.: usuário da base validando clone de WebPanel contra template e pedindo confronto automatizado). Sem essa demanda, manter Panel-only com a orientação atual — não construir superfície especulativa.

### Relacionado

- `scripts/Compare-GeneXusPanelShape.ps1` (sede; hoje Panel-only com orientação para WebPanel)
- `scripts/Get-GeneXusObjectSummary.ps1` (bloco `webpanel` — insumo pronto)
- `xpz-builder/responsibilities-by-type/webpanel.md` (validação de clone)

## Camada 3 — texto livre geral no índice KbIntelligence (captions, SQL/HTML em CDATA)

**Importância:** média
**Maturidade:** ideia (carece de desenho)

**Origem:** desmembrada da frente "Catálogo e rastreabilidade de classes CSS" (implementada e migrada para `historico/IdeiasImplementadas_202606.md` em 2026-06-10). Aquela frente afunilou de propósito uma proposta maior de "full-text geral" (SQLite FTS5) para o que tinha valor barato e imediato: classes CSS (camadas 1 e 2). A camada 3 — texto livre geral — ficou explicitamente **fora** e foi deslocada para esta entrada própria para não sair do radar junto com a entrada-mãe.

### Problema que motivaria a ideia

Há texto útil para triagem que hoje só sai por `rg` no acervo, não pelo índice: `caption`/títulos de controle, fragmentos de SQL e HTML embutidos em `CDATA` (ex.: `<Source>` de procedures, `UserControl` com `<style>`/template). Uma busca por termo literal ("onde aparece este caption?", "qual objeto tem este trecho de SQL?") não tem capacidade equivalente a `who-uses`.

### Por que não foi feita junto

- A classe CSS tinha um alvo nítido e barato (nome literal + onde é usado); texto livre geral é muito mais amplo e ambíguo (o que indexar? como evitar ruído? FTS5 muda o contrato do índice).
- Risco de inchar o índice e o contrato (`schema_version`, assinatura do extrator) sem régua de valor clara.

### O que precisa ser desenhado antes de implementar

- Escopo do que entra (captions? só SQL? HTML? todo CDATA?) e como evitar falso positivo.
- Mecanismo: FTS5 dedicado vs tabela simples de tokens vs reuso de `evidence`.
- Régua empírica de valor num corpus real (ex.: FabricaBrasil) antes de bumpar contrato.
- Não confundir com descoberta semântica por intenção (frente "LlamaIndex / LangChain + vector store") nem com fingerprint de call site.

### Relacionado

- `historico/IdeiasImplementadas_202606.md` (entrada-mãe das classes CSS, camadas 1 e 2)
- `scripts/Build-KbIntelligenceIndex.py`, `scripts/Query-KbIntelligenceIndex.py`

## Diagramas determinísticos focais no `xpz-doc-builder`

**Importância:** baixa-média
**Maturidade:** ideia (escopo inicial delimitado; aguarda demanda empírica)

**Origem:** avaliação do repositório `FBGxBrain` em 2026-07-26. O pipeline de documentação daquele projeto calcula grafos e diagramas a partir do SDK antes de apresentá-los ao LLM. A inspiração válida aqui é o princípio de visualização derivada de fatos determinísticos, não o seu pipeline de LLM/D2.

### Problema concreto que motivaria a ideia

O modo `advanced-docs` do `xpz-doc-builder` já gera matrizes, catálogos, diffs e guias, mas não uma visualização focal das relações que já podem ser extraídas do XML oficial ou do `KbIntelligence`. Em uma triagem humana, a saída textual de `impact-basic`, `who-uses` ou da estrutura de uma `Transaction`/SDT pode exigir leitura cruzada de vários resultados para compreender relações diretas.

### Direção técnica proposta

Adicionar, de forma **opt-in** ao `advanced-docs`, geração de Markdown com bloco Mermaid e artefato de cobertura para um alvo explícito, limitado inicialmente à profundidade 1:

- grafo de impacto direto, somente após o gate de índice aplicável estar OK;
- estrutura de `Transaction` (`Level → Attribute`, chave/FK) e de SDT (`Level → Item`) a partir do XML oficial;
- relações `Attribute → Transaction`/SDT apenas quando houver evidência estrutural explícita, nunca por homonímia.

Cada aresta deve declarar `relationKind`, fonte (`index` ou XML oficial), objeto/caminho de origem e cobertura. Tipo com `queryableByKbIntelligence=false`, índice inválido ou chamada dinâmica não é grafo vazio: deve aparecer como indisponibilidade ou limitação declarada.

### Limites e não fazer

- não gerar grafo da KB inteira, nem UI interativa;
- não usar LLM para criar, completar, reparar ou interpretar o diagrama;
- não usar D2, SVG/PNG ou renderização externa na primeira versão;
- não inferir chamadas dinâmicas, fluxo funcional, nem `Attribute ↔ SDT` por nome parecido;
- o XML oficial e as consultas do índice continuam fontes normativas; o diagrama é visualização derivada.

### Filiação e reavaliação conjunta

Esta entrada pertence à família «evidência de relações da KB». Antes de implementar qualquer frente desta família, reavaliar conjuntamente:

- `Plano A — Implementar relação references_attribute no índice KbIntelligence`;
- `Expansão do índice SQLite para fingerprint de call site`;
- `Camada 3 — texto livre geral no índice KbIntelligence`;
- consultas existentes de impacto e rastreio funcional.

As frentes de índice ampliam a matéria-prima; esta frente só a apresenta e não pode antecipar relações que elas ainda não provam. Uma evolução em qualquer membro deve revisar cobertura, contrato de saída e impacto nos demais.

### Limiar para implementar

Implementar somente após dois pedidos reais de documentação/triagem humana, em KBs distintas, nos quais a saída textual atual não baste para compreender relações diretas, ou após caso concreto de retrabalho causado por relações dispersas. A primeira entrega deve ser um diagrama focal determinístico, com fixtures sanitizadas e asserts de nós, arestas e cobertura.

### Relacionado

- `xpz-doc-builder/SKILL.md` e `scripts/generate-kb-advanced-docs.ps1`;
- `xpz-index-triage/SKILL.md` e `scripts/README-kb-intelligence.md`;
- `scripts/Build-KbIntelligenceIndex.py`, `scripts/Query-KbIntelligenceIndex.py`;
- entradas de `999` citadas em «Filiação e reavaliação conjunta».

## Gate de coerência para `Transaction` `GenerateObject=False` — Fase 2 (nível de pacote)

**Importância:** baixa
**Maturidade:** pesquisa feita (Fase 1 implementada; Fase 2 carece de caso concreto)

**Origem:** a Fase 1 desta frente foi implementada em 2026-06-10 (gate intra-objeto em `Test-GeneXusTransactionCoherence.ps1`, finding `wwp-screen-code-on-non-generated-transaction`) e migrada para `historico/IdeiasImplementadas_202606.md`. Restou esta subfrente residual. Contexto e desenho completo (D1-D4, distinção WWP DVelop × Work With nativo, painel multi-modelo) estão no histórico.

### O que falta (Fase 2)

A Fase 1 detecta a contradição **dentro do XML da Transaction** (`GenerateObject=False` + código de tela WWP órfão em Events/Rules). A Fase 2 é a checagem de **nível de pacote**: um batch que carrega `PatternInstance WorkWithPlus*` e/ou derivados (`*WW`, `*WWDS`, `*General`, `*Prompt`, `*View`) cujo pai é uma Transaction `GenerateObject=False`. É outra natureza de análise (correlação cross-objeto no `ExportFile`, não intra-objeto), por isso seria um **script novo** (ex.: `Test-GeneXusPackageWWPCoherence.ps1`), não extensão do gate de coerência.

### Por que adiada

- A Fase 1 já dá `fail` e barra o pacote pelo sinal causal (código órfão), então a Fase 2 é diagnóstico complementar, não bloqueio adicional necessário.
- Sem um caso real onde só a correlação de pacote (sem código órfão na Transaction) quebre o import, a régua de severidade fica `padrao-gx-nao-verificado`.

### Relacionado

- `historico/IdeiasImplementadas_202606.md` (Fase 1 implementada)
- `scripts/Test-GeneXusTransactionCoherence.ps1`, `xpz-builder/wwp-packaging.md`

## Gate `procedural-in-conditions` — estender a outros tipos sem filtro de Conditions

**Importância:** baixa
**Maturidade:** pesquisa feita (Procedure implementado; outros tipos carecem de acervo com evidência)

**Origem:** a Frente A do lote CPJAPP foi **implementada em 2026-06-13** — gate type-aware `procedural-in-conditions` (`fail`) no `Test-GeneXusSourceSanity.ps1` para **Procedure** (`type 84a12160`) com a parte Conditions (`763f0d8b`) não-vazia; migrada para `historico/IdeiasImplementadas_202606.md`. Restou esta subfrente residual.

### O que falta

O gate usa um mapa extensível `objectType → partes-proibidas-não-vazias` (hoje só `Procedure→Conditions`, em `$script:ForbiddenNonEmptyParts`). Outros tipos **sem tela/filtro** poderiam ter a mesma invariante (parte Conditions sempre vazia) — candidato principal: `DataProvider`. **NÃO** estender a `Data Selector`: ele tem Conditions legítima (catch do glm no painel). Adicionar um tipo = uma entrada no mapa, trivial.

### Por que adiada

- Sem evidência empírica (nem de bug, nem de "sempre vazio") para esses tipos — o acervo FabricaBrasil consultado nem tem pasta `DataProvider`.
- Estender sem varrer um acervo que contenha esses tipos arrisca falso positivo. Régua (a mesma usada para Procedure): confirmar o GUID do tipo + 0 ocorrências legítimas de Conditions não-vazia no acervo, antes de habilitar.

### Relacionado

- `historico/IdeiasImplementadas_202606.md` (Procedure implementado, 2026-06-13)
- `scripts/Test-GeneXusSourceSanity.ps1` (mapa `$script:ForbiddenNonEmptyParts`), `scripts/Test-GeneXusSourceSanitySelfTest.ps1`

## Mensagem acionável uniforme de "frente não aberta" nos demais scripts que recebem `-FrontFolder`

**Importância:** baixa (gap de ergonomia/DX; o fluxo real — `Copy-GeneXusAcervoToFront.ps1` e o gate 9-FD `Test-GeneXusFrontAcervoDrift.ps1` — já foi tratado)
**Maturidade:** pesquisa feita (direção resolvida por painel de 4 modelos em 2026-06-13; falta decidir entre duplicação e helper compartilhado)

**Origem:** sessão 2026-06-13, relato externo (agente pulou `New-KbFront`, criou a pasta da frente manualmente e bateu no `throw` opaco do `Copy`). O caminho mínimo foi aplicado: mensagem acionável (prefixo `FRENTE_NAO_ABERTA:`, cita `-ReuseIfExists`, aponta o `New-`) em `Copy-GeneXusAcervoToFront.ps1` e em `Test-GeneXusFrontAcervoDrift.ps1` (único gate comprovadamente upstream do Copy), mais reforço documental (`xpz-builder/SKILL.md` gate 9-FD, `quality-checklist.md`). Esta entrada é o resíduo deliberadamente adiado.

### O gap

O mesmo `throw "FrontFolder nao encontrado ou nao e diretorio"` existe em **7 scripts** que recebem `-FrontFolder`. Dois já foram tornados acionáveis (Copy + drift gate). Restam **5 gates downstream**, de baixa probabilidade de serem o primeiro script chamado sem frente aberta (sempre rodam depois do populate/edição):

- `Test-GeneXusWorkWithWebApply.ps1` (9-WW)
- `Test-GeneXusBatchDependencyOrdering.ps1` (9-IDO)
- `Test-GeneXusProcedureSubPattern.ps1` (9-PSM)
- `Test-GeneXusBCDependency.ps1` (9-BC)
- `Test-GeneXusNewWritableTargets.ps1` (9-PNW)

### Decisão a fechar em sessão dedicada

(a) **Duplicar** a frase-sentinela acionável nos 5 gates restantes (≈5 linhas, zero acoplamento novo); ou (b) **extrair um helper compartilhado** (ex.: `Assert-GeneXusFrontFolderExists` em um `*Support.ps1`) consumido pelos 7 — uma única fonte de mensagem, ao custo de uma dependência nova entre scripts.

Painel dividido (2026-06-13): deepseek-v4-pro, glm-5.1 e minimax-m3 inclinaram a **não** padronizar agora (over-engineering para N pequeno; os gates são downstream — minimax sugeriu primeiro medir "quantos realmente podem ser o primeiro chamado" antes de padronizar); o subagente Opus inclinou ao **helper** por consistência e por ter confirmado que o drift gate (já tratado) roda antes do Copy. Régua sugerida: o helper só compensa se a política realmente abraçar os 7; caso contrário, aplicar a frase incrementalmente quando cada gate for tocado.

### Relacionado

- `scripts/Copy-GeneXusAcervoToFront.ps1`, `scripts/Test-GeneXusFrontAcervoDrift.ps1`, `scripts/New-GeneXusXpzFront.ps1`
- `xpz-builder/SKILL.md` (gate 9-FD), `xpz-builder/quality-checklist.md`

## Revisar a memória pessoal do agente por conhecimento que pertence às skills XPZ

**Importância:** média (conhecimento útil preso na memória de um harness/máquina não melhora as skills, que rodam em N harnesses e N máquinas)
**Maturidade:** ideia (varredura e triagem por fazer; alguns itens são claros, outros são mistos local/skill)

**Origem:** 2026-06-19. Este é um repositório de skills feitas para rodar em N harnesses (Claude Code, Codex, Cursor, OpenCode) e N máquinas; a memória pessoal de um agente **não viaja com a skill**. Conhecimento de skill registrado só na memória fica invisível aos demais consumidores e desencontra a fonte de verdade.

**A fazer (sessão dedicada):** varrer a memória pessoal do agente e migrar para a `SKILL.md`/doc/script da skill correspondente todo conhecimento **comportamental / de invocação / de limitação de adapter / de quirk operacional**, deixando na memória apenas o **genuinamente local** (hardware da máquina, preferências do usuário, estado/rastreabilidade de frentes em curso). Triar item a item — alguns são mistos (ex.: hardware local + limitação de adapter na mesma anotação). Regra de fronteira já registrada na memória do agente (`feedback_skill_knowledge_nao_vai_pra_memoria`).

**Nota:** o subconjunto da **`xpz-llm-delegate`** (adapters opencode, composição de painel) está sendo tratado na própria sessão de 2026-06-19 — não esperar esta frente para ele.

**Progresso e dimensão nova (2026-06-23):** uma sessão fez a 1ª passada concreta. Removeu da memória pessoal o conhecimento de skill que **já estava no repo** (frentes fechadas+pushadas cujo registro vive em `historico/`/`CHANGELOG`/`999`; quirks de XML GeneXus da antiga `reference_genexus_xml_quirks.md`, hoje cobertos em `01a/01b/01d/01g/01h`, `02`, `03`, `05b`, `xpz-builder/SKILL`, `transaction.md`, `xpz-reader/SKILL`; lição empírica "`Write-Host`/`Warning`/`Information` vazam pro stdout em processo filho, só `[Console]::Error` escapa", já em `xpz-sync/SKILL.md:272`). `MEMORY.md` caiu de 27,1 KB para 13,3 KB. **Dimensão que esta entrada não previa:** boa parte do que sobrou na memória é **feedback comportamental**, cujo destino correto **não é uma skill** (não é domínio xpz) e sim o **`AGENTS.md` global** (contrato lido por todos os harness). E parte do que parece "feedback" é, na verdade, **metodologia de skill** → vai pro repo (`15-revisao-por-pares`/`SKILL.md`), não pro `AGENTS.md`.

**A fazer (sessão dedicada) — ordem obrigatória: LEVANTAR primeiro, só então deletar da memória** (nunca apagar um feedback que ainda não esteja no destino):

1. **`AGENTS.md` global — propor adição** (barra alta: muda comportamento de todos os agentes; aprovar item a item): `feedback_resposta_enxuta_por_ponto`, `feedback_perguntas_por_texto` (prosa, não AskUserQuestion), `feedback_preexistente_nao_ignora` (triagem em 3), `feedback_verificacao_empirica_relato_externo`, `feedback_frustracao_cronica_investigar_raiz`, `feedback_script_para_deterministico`.
2. **Repo (15/SKILL) — conferir cobertura e completar:** `feedback_painel_inteiro_versao_final` + `feedback_prompt_subagente_verbatim` → `15-revisao-por-pares`; `feedback_opencode_async_validar_conclusao` + `feedback_delegar_via_skill_direto` → `xpz-llm-delegate/SKILL`; `feedback_paridade_02_readme_regra_operacional` + `feedback_busca_semantica_crases_markdown` → já são regra do repo (13/pré-push), só validar.
3. **Deleção limpa (já literais no `AGENTS.md`, redundantes):** `feedback_cherrypick_imediato`, `feedback_git_consulta_sem_prompt`, `feedback_grep_nativo`, `feedback_leitura_arquivo_grande`, `feedback_pre_push_nao_e_pipeline`, `feedback_revisao_pre_push`, `feedback_reconhecer_pasta_paralela`, `feedback_invocacao_canonica_sem_variar`, `feedback_invocacao_script_sem_prompt`, `feedback_ferramentas_nativas_e_atomico`, `feedback_evitar_composto_self_tests`, `feedback_sem_pipe_tail_em_scripts` (confirmar literal antes de cada deleção).
4. **Fica local (não migra):** `feedback_skill_knowledge_nao_vai_pra_memoria` (disciplina da própria memória), `feedback_scripts_repo_sem_prompt`/`feedback_readonly_sem_prompt` (mapeiam `settings.json` allow, não prosa), `feedback_sessao_paralela_mesma_pasta`/`feedback_worktree_*`/`feedback_branch_deletion` (worktree do desktop app, Claude-Code-specific), `feedback_verificacao_propria_sql`, `feedback_git_add_relativo`; e o ambiente de máquina/conta (hook PreToolUse, cota ollama, SqlClient, GPU, permissões de leitura de KB).

**Caveat:** a classificação acima foi feita contra o `AGENTS.md` em contexto de 2026-06-23, possivelmente não exaustivo — reconfirmar cada item contra o `AGENTS.md` atual antes de deletar.

## Tier `primary`/`backup` na lista de revisores preferidos (`preferred-reviewers.json`)

**Status 2026-07-10:** eixo `primary`/`backup` implementado como schema v2 com titulares ordenados por `rank` e `fallbackChain[]` ordenado `0..N` por titular, com recibo auditável (`skippedAfterSuccess`, `skippedByPolicy`, `notAttempted`, `countsForDiversity=false`) e bloqueio de `insufficientDiversityAfterFallback`. A entrada permanece aqui só pelos resíduos: decisões de escopo do painel (`scopeDecision`/`defaultScope`) e single-flight fora da `fallbackChain`.

- **Importância** — baixa-média (atrito real recorrente, com workaround operacional). Antes do schema v2, o `preferred-reviewers.json` era **lista plana** (`Set-LlmDelegatePreferredReviewers.ps1` gravava `{backend, targetModelKey, invokeArgs}`; `Resolve-LlmDelegatePreferredReviewers.ps1` devolvia a composição sem ordem nem tier). A régua (`15-revisao-por-pares.md` / `xpz-llm-delegate`) manda **despachar a lista preferida inteira**, então adicionar revisores de reserva à lista plana os tornaria **co-iguais** (despachados sempre) — o oposto de "backup". O schema v2 resolveu esse eixo; permanecem pendentes as decisões de escopo e single-flight citadas acima.
- **Maturidade** — parcialmente implementada; resíduos em aberto.

**Direção implementada:** schema v2 com `fallbackChain[]` por titular e ativação só quando o titular fica indisponível/falha. Preserva o invariante **preferência ≠ autorização** (o gate `Resolve-LlmDelegateAuthorization.ps1` segue soberano por destino); a régua passa a significar "titulares + fallbacks ativados dos titulares que falharam", com skips auditáveis para os demais.

**Decisões já fechadas pelo schema v2:** ativa em `quota`/`timeout`/`error`/`unavailable`; `noResponse` é reclassificação pós-hoc do orquestrador, não gatilho primário do dispatcher. Fallback é **por-titular** (`fallbackChain[]`); ativação e skips aparecem no dispatcher/recibo; diversidade e closeout tratam `countsForDiversity=false` e `insufficientDiversityAfterFallback`. **Resíduos em aberto:** política de escopo do painel (`scopeDecision`/`defaultScope`) e single-flight fora da `fallbackChain` com contrato tipado e decisão humana explícita.

**Sub-ideia relacionada (2026-07-11) — exclusão operacional de revisor/modelo problemático:** avaliar uma camada explícita de supressão/denylist de revisores para o resolvedor de painel, sem alterar o catálogo bruto de capacidades. Caso concreto: `nvidia/openai/gpt-oss-120b` apareceu como modelo disponível no snapshot gerado (`capabilities.json`), mas em rodadas recentes de pré-push reforçada falhou tecnicamente com `max_tokens must be at least 1, got -27670` e consumiu tempo sem entregar parecer válido. Ele não estava na lista preferida atual; entrou por composição ad hoc de helper. A decisão provisória foi remover de helpers reutilizáveis, mas **não** apagar manualmente de `capabilities.json`, porque esse arquivo é inventário gerado e a remoção reapareceria no próximo rebuild.

- **Importância** — baixa-média: evita que agentes desperdicem rodada com modelo conhecido como ruim/instável, sem confundir "modelo existe" com "modelo deve ser escolhido".
- **Maturidade** — ideia; precisa desenho antes de implementar.
- **Direção a estudar** — `suppressedReviewers[]`/`excludedModelKeys[]` em artefato de curadoria da máquina, com `targetModelKey`, backend/provedor quando necessário, motivo, data e talvez validade/retentativa. O resolvedor (`Resolve-LlmDelegatePreferredReviewers.ps1`/composição de painel) deveria filtrar ou rebaixar esses candidatos e explicar o skip no recibo. Separar dois conceitos: (1) "não escolher automaticamente/não oferecer como fallback" por baixa qualidade ou falha operacional; (2) veto forte de segurança/autorização, que continua sendo responsabilidade do gate de autorização. Relaciona-se aos resíduos de escopo do painel e single-flight fora da `fallbackChain`.

**Caso concreto que motivou (2026-06-28):** o usuário queria as 4 vozes **NVIDIA** (`nvidia/deepseek-ai/deepseek-v4-pro`, `nvidia/z-ai/glm-5.1`, `nvidia/moonshotai/kimi-k2.6`, `nvidia/minimaxai/minimax-m2.7`) como **backup** das 3 `ollama-cloud` (`deepseek-v4-pro`, `kimi-k2.7-code`, `glm-5.2`), usadas quando o ollama-cloud está em cota. Observado na mesma frente: as NVIDIA de raciocínio (`deepseek-v4-pro`/`glm-5.1`) tendiam a **estourar 280s** (agravado por sessão concorrente) e as coder (`kimi-k2.6`/`minimax-m2.7`) **truncavam por `tool-calls`** — então o backup precisava de **tolerância a falha por voz**, não só troca de provider. O schema v2 cobre esse caso como `fallbackChain[]`.

**Origem:** frente de revisão por pares da feature de criação/alteração de objeto `API` GeneXus (2026-06-28); pedido explícito do usuário. A implementação passa por **revisão por pares + pré-push** como toda mudança de mecanismo da skill.

## Gate scriptado da Face 3 da API (smoke de runtime automatizado) — evolução futura

**Origem:** desmembrado da frente «Criar/alterar objeto GeneXus do tipo `API` (from-spec, com segurança GAM) nas skills XPZ», **concluída e migrada** para `historico/IdeiasImplementadas_202607.md` (2026-07-01). Aquela frente resolveu a **Face 3** (prova de runtime do enforcement GAM) por **checklist textual + sub-estado pós-build**, documentado em `xpz-builder/responsibilities-by-type/api-gam-runtime.md`.

**Ideia:** automatizar o **smoke de 2 fases** (anônimo→401; usuário sem papel→403; com papel→200) + OAuth + reversibilidade num **gate `.ps1`**, em vez do checklist manual. **Não cabe como gate `9-*`** (que é preflight estático pré-import): é um **teste HTTP de runtime pós-deploy**, outra categoria — por isso ficou como evolução futura (decisão D2 da frente original). **Gatilho:** quando houver demanda real de automatizar a prova de enforcement (e uma forma estável de subir/consultar o app headless no fluxo).

## `Get-Help` não enxerga o comment-based help da maioria dos scripts (falta linha em branco após `#requires`)

- **Importância** — média. Não há risco de dano (nem contaminação de KB, nem perda de trabalho, nem falso negativo em gate) e o contorno é trivial — abrir o arquivo, que é o que todo mundo já faz. O que pesa é a **extensão**: **218 de 248** scripts em `scripts/` com bloco de ajuda real (`.SYNOPSIS`) ficam invisíveis ao `Get-Help`. É **deriva de convenção**, não convenção ausente: 29 arquivos já usam o padrão correto, então o repositório tem as duas formas convivendo e a errada é a maioria — cada script novo tende a nascer quebrado. Já induziu erro factual: em 2026-07-26 uma mensagem de commit justificou documentar parâmetros alegando que `Get-Help` passaria a mostrá-los — não passa.
- **Maturidade** — pronta para implementar. Causa isolada por experimento controlado, correção verificada, e o padrão-alvo já existe no próprio repositório; falta executar e decidir o gate.

**Causa, medida em 2026-07-26.** Não é o `#requires` estar antes do bloco de ajuda — é ele estar **colado** ao bloco. Sem uma linha em branco separando a diretiva do `<#`, o PowerShell descarta o comment-based help inteiro. Contraste entre dois arquivos reais do repositório:

| Arquivo | Cabeçalho | `Get-Help -Full` |
|---|---|---|
| `Start-ClaudeCodeJob.ps1` | `#requires` **colado** ao `<#` | `params=1` (só a sintaxe auto-gerada) |
| `Build-GeneXusImportFileEnvelope.ps1` | `#requires`, linha em branco, `<#` | `params=12` + sinopse real |

Confirmado por injeção: acrescentar **uma linha em branco** numa cópia do primeiro devolve `params=10` e a sinopse real, sem mover a diretiva.

**Levantamento de `scripts/` (auditoria por `Get-Help` real, script a script, não por regex):**

| | |
|---|---|
| Scripts em `scripts/` com bloco de ajuda real (`.SYNOPSIS`) | 248 |
| Com `#requires` colado ao `<#` — **quebrados** | **218** |
| Com linha em branco — já funcionam | 29 |
| Sem `#requires` antes do help — `Test-XpzPowerShellRuntime.ps1`, exceção 5.1 | 1 |
| Dos 89 com `.PARAMETER`, quebrados | 72 |

Ressalva de medição: a auditoria por `Get-Help` contou 14 scripts renderizando parâmetros e a contagem por adjacência prevê 17; a diferença vem do filtro `> 1 parâmetro` usado na auditoria, que descarta scripts de um parâmetro só. Os três casos não foram conferidos individualmente — não muda a conclusão, mas quem retomar deve refazer a contagem antes de tratar 218 como lista definitiva. `scripts-maintenance/` foi conferido separadamente em 2026-07-26: são 5 arquivos com bloco de ajuda real, todos com `#requires` colado ao `<#`; se a frente incluir esse diretório, o alvo total de adjacência quebrada passa de 218 para 223.

**A diretiva fica onde está.** `#requires -Version 7.4` em ponto de entrada público é regra operacional obrigatória (`02-regras-operacionais-e-runtime.md`, seção de regra operacional; `README.md` trilíngue). A correção **não** a move nem a remove: acrescenta uma linha em branco depois dela. Não há trade-off com a proteção de runtime.

**Exceções nominais, já medidas:** o `1` da tabela é `Test-XpzPowerShellRuntime.ps1`, que não tem `#requires` (precisa rodar em 5.1) nem `.PARAMETER` — fica fora por construção. `Invoke-ParallelKbEnvelopeScan.ps1` **não** é exceção sem diretiva: tem `#Requires -Version 7.4` em caixa mista, colado ao `<#`, e portanto pertence ao grupo de adjacência quebrada quando o detector tratar a diretiva sem depender de caixa.

**O que a frente faria:** inserir a linha em branco nos 218 arquivos afetados de `scripts/` e decidir explicitamente se inclui também os 5 de `scripts-maintenance/` (mecânico, um caractere por arquivo); criar **gate de regressão** — detectar `#requires`/`#Requires` imediatamente seguido de `<#` em arquivo com bloco de ajuda é uma regex de uma linha com comparação sem depender de caixa, e os 29 arquivos corretos servem de referência —; e avaliar se a regra do `02`/`README` deve passar a dizer **como** a diretiva convive com o bloco de ajuda, não só que ela deve existir. Sem o gate, a frente vira dívida recorrente.

**Origem:** revisão do commit `83d4c6a` (documentação dos parâmetros do `Start-ClaudeCodeJob.ps1`), 2026-07-26. A verificação da justificativa do commit — «quem chamasse `Get-Help` não encontrava nada» — revelou que continua não encontrando, e que o defeito atinge quase todo o `scripts/`.

**Correção do próprio registro (mesma data).** A primeira versão desta entrada afirmava «89 de 89, zero visíveis» e propunha **reordenar** a diretiva. Estava errada na causa, nos números e na correção: o experimento inicial removia a linha do `#requires` e portanto mudava **duas** variáveis ao mesmo tempo — a diretiva e a adjacência —, atribuindo o efeito à errada. O erro só apareceu porque uma segunda voz estranhou que as duas contagens casassem exatamente e pediu conferência independente; a auditoria por `Get-Help` real mostrou 14 scripts funcionando, o que era incompatível com a causa alegada. Fica como lição de método: contagem por regex não substitui medição do comportamento, e experimento que muda duas variáveis não isola causa nenhuma.

## Divulgação progressiva nos `SKILL.md` extensos

- **Importância** — média (arquivos muito extensos aumentam custo de contexto e tornam mais difícil distinguir regra sempre obrigatória de detalhe condicional; há contorno manual por leitura dirigida e satélites já existentes).
- **Maturidade** — ideia (arquitetura candidata identificada, mas ainda sem medição de perda real de aderência, desenho fechado ou escolha definitiva de skill-piloto).

**Origem (2026-07-26):** estudo comparativo da organização modular da `nexa` — `SKILL.md` como fluxo principal e referências `object-*`, `common-*`, `global-*`, `model-*` e `properties-*` carregadas conforme o caso — frente à estrutura atual das skills XPZ.

### Problema a verificar

Algumas skills XPZ concentram grande volume no arquivo principal, apesar de já haver precedentes internos de satélites:

- `xpz-kb-parallel-setup/SKILL.md`: cerca de 207 KB;
- `xpz-msbuild-import-export/SKILL.md`: cerca de 118 KB;
- `xpz-builder/SKILL.md`: cerca de 108 KB;
- `xpz-msbuild-build/SKILL.md`: cerca de 107 KB.

Tamanho sozinho **não prova defeito**. Regras absolutas, sequência de gates e fronteiras de segurança podem perder aderência se forem deslocadas para arquivos que o agente não carrega. A investigação precisa medir se há custo ou falha concreta antes de tratar modularização como correção.

### Hipótese de melhoria

Avaliar divulgação progressiva: manter no `SKILL.md` um roteador operacional compacto e deslocar apenas conteúdo realmente condicional para referências explicitamente acionadas.

Em um desenho possível, não obrigatório:

- o arquivo principal preserva gatilhos, fronteiras, ordem do workflow, regras `NEVER`/`ABORT` e chamadas obrigatórias;
- satélites concentram detalhes por tipo, variante, gate ou fase;
- cada referência tem gatilho explícito e deve ser lida integralmente quando acionada;
- o checklist final confere que todos os satélites aplicáveis foram carregados.

### Reavaliação obrigatória antes de propor mudança

Esta entrada registra uma direção para estudo, não uma decisão de refatoração. Quem retomar deve:

1. reler a skill candidata e seus satélites no estado atual;
2. medir tamanho, duplicação, referências cruzadas e sinais reais de falha de carregamento/aderência;
3. mapear o que precisa permanecer sempre carregado e o que é genuinamente condicional;
4. comparar alternativas como compactação local, remoção de duplicação, índice roteador ou nenhuma mudança;
5. admitir como resultados válidos escolher outra skill-piloto, manter a estrutura atual ou descartar a ideia.

### Piloto possível, não fixado

`xpz-builder` é candidata inicial porque já possui `responsibilities-by-type/`, `quality-checklist.md` e `wwp-packaging.md`, permitindo testar o desenho com menor invenção estrutural. Isso **não** fixa a `xpz-builder` como primeira implementação: a análise futura pode escolher outra skill ou concluir que o piloto não se justifica.

### Decisões em aberto

- Qual dor empírica justificaria a reorganização: limite de contexto, regra omitida, duplicação ou dificuldade de manutenção?
- Que conteúdo é invariavelmente carregado e não pode sair do `SKILL.md`?
- Como impedir que o roteador e os satélites divirjam?
- Como fazer a migração em recortes pequenos, preservando histórico e evitando reescrita ampla de Markdown?

### Relacionado

- `xpz-builder/SKILL.md`, `xpz-builder/quality-checklist.md`, `xpz-builder/wwp-packaging.md` e `xpz-builder/responsibilities-by-type/`;
- `xpz-kb-parallel-pre-push/SKILL.md` e seus satélites, precedente interno de skill principal enxuta;
- entrada «Pré-push: reduzir dependência de interpretação em `.md` (opções B e C)» neste arquivo, pela preocupação comum com contratos espalhados;
- entrada «Catálogo semântico de operações em `xpz-builder`» neste arquivo, que pode criar novos satélites condicionais.

## Hipótese técnica: `Rows` para `Character` longo em layout `GxMultiForm` (WebPanel)

- **Importância** — baixa/média (conforto de geração de WebPanel). Medido na frente GamAuditoria (KB `FabricaBrasil18`, GX 18 U13, 2026-08-15/17): variável `Character(254)` em WebPanel com layout responsivo (`GxMultiForm`) renderiza como `textarea` de três linhas; `ControlType = Edit` nas propriedades da **variável** não converteu para input de uma linha.
- **Hipótese (não validada)**: a altura pode ser controlada por propriedade de **layout** no controle correspondente dentro do CDATA do `GxMultiForm` (candidata: `Rows=1`), em vez de propriedade da variável.
- **Ressalva obrigatória**: não empacotar objetos com essa propriedade até validação em fixture com `.cs` conferido e renderização visual confirmada. A propriedade `Rows` é candidata, não padrão confirmado; há riscos de nomenclatura/propriedade divergentes entre versões do GeneXus.
- **Rastreabilidade**: medição empírica na frente GamAuditoria (KB `FabricaBrasil18`, GX 18 U13, 2026-08-15/17); síntese documentada em `04-webpanel-familias-e-templates.md` (armadilha sem solução) e em `04b-ucw-gxcontroltype-reference.md` (seção «Hipótese técnica: `Rows` para `Character` longo em `GxMultiForm`»).
- **Frente futura sugerida**: fixture de WebPanel com Character longo testando `Rows=1` no layout + build com `.cs` conferido + renderização; se validado, promover a propriedade a regra operacional no `04b` e registrar o molde no `01e`.

## Ferramental: Diagnóstico de existência ativa de objeto na KB (`Test-GeneXusObjectExists.ps1` / Lacuna de verificação)

- **Importância** — média (segurança operacional e prevenção de erros em ferramentas e automações).
- **Problema identificado (2026-08-17, frente GamAuditoria)**: ausência de método direto e confiável para responder programmaticamente: *"este objeto ainda existe ativamente nesta KB?"*. Três tentativas investigadas falharam:
  1. *Tabelas `Entity` e `EntityVersion` no banco relacional SQL Server da KB (`GX_KB_<NomeDaKB>`)*: guardam histórico completo e registros túmulo de objetos excluídos, inviabilizando a filtragem direta de objetos ativos;
  2. *Tabela `OBJECT` no banco SQL Server da KB*: não contém o inventário ativo dos objetos de modelo da aplicação;
  3. *Arquivo `nav_objs.xml` do MSBuild*: reflete somente o escopo da última geração parcial realizada pelo MSBuild, omitindo objetos não compilados na rodada.
- **Proposta de frente futura**: desenvolvimento de ferramenta dedicada (`scripts/Test-GeneXusObjectExists.ps1`) baseada em introspecção segura do acervo exportado ou catálogo consolidado para verificar a existência e o estado ativo de um objeto antes de disparar automações de import/export/build.
