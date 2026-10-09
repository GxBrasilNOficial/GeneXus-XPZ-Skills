# Ideias Implementadas — 2026-10

Registro de ideias que saíram de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodológico vigente.

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
