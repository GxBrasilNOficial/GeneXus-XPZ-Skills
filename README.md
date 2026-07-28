# Knowledge GeneXus

## Manutenção trilíngue do README

- a seção `Português (BR)` é a fonte editorial primária do `README.md`
- toda alteração de conteúdo, estrutura, regra operacional ou nomenclatura feita na seção `Português (BR)` deve ser refletida também nas seções `Español` e `English`
- não deixar traduções parciais, defasadas ou estruturalmente incompletas em relação à versão em português
- ao editar apenas uma das três seções, validar explicitamente se as outras duas continuam consistentes
- se a atualização completa das três línguas não puder ser feita na mesma frente, sinalizar isso como pendência explícita antes de concluir

## Português (BR)

Este repositório existe para sustentar e operacionalizar skills para agentes dedicadas ao ecossistema `XPZ`/XML de GeneXus, em especial `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon`, `xpz-kb-parallel-setup`, `xpz-kb-parallel-pre-push`, `xpz-msbuild-import-export`, `xpz-msbuild-build`, `xpz-index-triage`, `xpz-llm-delegate`, `xpz-skills-setup` e `xpz-codex-apply-patch-alternative`.

A documentação consolidada e os scripts desta raiz funcionam como base metodológica e operacional dessas skills, com foco em:

- leitura e interpretação de estrutura XML
- famílias estruturais de objetos
- risco por tipo de objeto
- clonagem conservadora
- apoio à geração assistida de `XPZ`
- validação documental de envelope e importação em casos controlados

### O que você vai encontrar aqui

Os arquivos abaixo formam a base compartilhada principal desta raiz, consolidada para facilitar leitura, manutenção e uso controlado.

Além dessa base principal, a raiz também pode conter documentação operacional complementar de frentes ativas, quando ela ainda precisar permanecer visível fora de `historico/`.

- `00-indice-da-base-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `01a-catalogo-e-padroes-empiricos.md` em diante (filhos da série `01`)
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `04b-ucw-gxcontroltype-reference.md`: catálogo de User Controls (`gxControlType`) em `GxMultiForm`, tabela de upload por contexto, regras de eventos de UC e SDT `FileUploadData`
- `05-transaction-familias-e-templates.md`
- `05b-procedure-relatorio-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-inventario-e-rastreabilidade-publica.md`
- `10-base-operacional-msbuild-headless.md`: base operacional da trilha MSBuild headless, usada pelas skills `xpz-msbuild-import-export` e `xpz-msbuild-build`
- `10a-gx-export-task-labels.md`: divergências entre rótulos da task Export (`-ObjectList`) e o catálogo interno / KbIntelligence; complementa `10-base` na exportação seletiva (`exportTaskLabel`)

Os arquivos `10-matriz-part-types-por-tipo.md`, `11-campos-estaveis-vs-variaveis.md` e `12-diffs-estruturais-por-tipo.md` são stubs de compatibilidade retroativa: cada um redireciona para o equivalente na serie `01` (`01b`, `01c`, `01d`). Não contem conteúdo próprio e não devem ser usados como fonte direta.

### Documentos de governança pública

- `CHANGELOG.md`: registro de mudanças relevantes a partir da adoção do changelog.
- `CONTRIBUTING.md`: guia para contribuições, revisão pré-push e cuidado com dados reais.
- `SECURITY.md`: política para reporte privado de vulnerabilidades, vazamentos e riscos operacionais sensíveis.
- `CODE_OF_CONDUCT.md`: código de conduta para interações ligadas ao projeto.

### Documentação operacional KB Intelligence

Guia operacional e metodologico da trilha KB Intelligence. Contratos de fases encerradas e registros historicos estao em `historico/kb-intelligence/`.

- `kb-intelligence-guia-metodologico-agente.md`: roteiro de investigacao funcional, checklist operacional, exemplos sanitizados e modelo de resposta para agentes
- `scripts/README-kb-intelligence.md`: guia operacional de scripts, comandos de consulta, gates de frescor e baterias de validação

### Skills para agentes

- `xpz-reader`: apoio à leitura e interpretação estrutural de `XPZ` e XMLs relacionados
- `xpz-builder`: apoio à materialização controlada de artefatos e envelopes `XPZ`
- `xpz-sync`: orquestração de sincronização e conferência do acervo XML a partir de parâmetros explícitos e scripts em `scripts/`
- `xpz-daemon`: instalação e gerenciamento de um monitor persistente que observa pastas de XPZ e dispara sincronização automaticamente ao detectar novos arquivos
- `xpz-doc-builder`: geração e recomposição de documentação Markdown a partir do acervo XML e de moldes sanitizados
- `xpz-kb-parallel-setup`: preparação e validação da estrutura inicial da pasta paralela da KB
- `xpz-kb-parallel-pre-push`: validação pré-push do estado de uma pasta paralela da KB antes do push dessa KB (orquestrador de gates mecânicos G0–G5 + K1–K4/K8/K9/K11); distinta da rotina pré-push do repositório de skills (documento 13)
- `xpz-msbuild-import-export`: skill experimental para importação e exportação de `XPZ` via `MSBuild`, com execução sem interface gráfica, parâmetros explícitos, rastreabilidade e gates de segurança
- `xpz-msbuild-build`: skill para validação de build pós-import via `MSBuild`, com execução sem interface gráfica, classificação de resultado e bloqueio de reorg por padrão
- `xpz-index-triage`: triagem inicial por índice derivado para orientar a leitura mínima dos XMLs oficiais da KB
- `xpz-llm-delegate`: delegação de tarefas menores ou segunda opinião a um LLM secundário via opencode (modelos no formato `provider/modelo`, incluindo provedores cloud conhecidos como `ollama-cloud/*` e `opencode-go/*`), Codex (`codex exec`), Claude Code (`claude -p`, Opus 4.8), GitHub Copilot CLI (`copilot -p`) ou Gemini CLI (`gemini -p`), com classificação local/externo determinística e gate de confidencialidade por KB (chave de destino, nunca o adapter); acionamento sempre humano (inclui condução de revisão por pares multi-modelo, ver `15-revisao-por-pares.md`)
- `xpz-skills-setup`: auditoria e manutenção do registro global das skills XPZ nas ferramentas de agente instaladas na máquina; inclui o bootstrap de uma pasta baixada como ZIP do GitHub — instalar o Git quando ausente e ligá-la ao repositório oficial; também valida e registra a skill externa gerenciada `nexa`, clonando seu repositório oficial (`genexuslabs/genexus-skills`) quando ausente
- `xpz-codex-apply-patch-alternative`: backup auditável por motor PowerShell para aplicar patch Git textual aprovado no Codex quando a rota nativa `apply_patch` estiver indisponível, falhar antes de escrita local ou for solicitada explicitamente; o registro global é frente posterior

### Leitura recomendada para humanos

Se você quer entender a base rapidamente:

1. comece por `00-indice-da-base-genexus-xpz-xml.md`
2. siga para `01-base-empirica-geral.md` e desça ao filho da série `01` mais aderente ao caso (`01a` a `01h`, filhos empíricos)
3. depois leia `02-regras-operacionais-e-runtime.md`
4. em seguida leia `03-risco-e-decisao-por-tipo.md`
5. para casos práticos, use `04-webpanel-familias-e-templates.md`, `05-transaction-familias-e-templates.md` e `05b-procedure-relatorio-familias-e-templates.md`
6. se quiser entender limites e próximas frentes, leia `07-open-points-e-checklist.md`
7. para consumo por outro agente GPT, termine em `08-guia-para-agente-gpt.md`
8. para conferir rastreabilidade do inventário, consulte `09-inventario-e-rastreabilidade-publica.md`

`06-padroes-de-objeto-e-nomenclatura.md`: leitura suplementar — indicado quando a dúvida envolver nomenclatura de objetos, prefixos de tipo ou comportamento de `Folder` vs `Module` no `fullyQualifiedName`.

### Avisos importantes

- esta base prioriza evidência estrutural observada em XML
- ela não promete sucesso de importação ou build sem validação externa
- a base já incorpora testes documentados de importação em casos controlados, mas isso não elimina risco
- antes de gerar `import_file.xml` ou pacote importável, a trilha deve separar explicitamente `XML bem-formado` de `Source GeneXus estruturalmente conservador/provavelmente importável`; parse XML sozinho não basta
- em revisão e sanity de objeto legado, a trilha deve separar explicitamente `sanity absoluto do artefato atual` de `comparacao contra baseline oficial`; `igual ao baseline` não significa `bom`, e `pior que o baseline` indica regressao do delta
- moldes sanitizados completos podem servir como ponto de partida em cenários específicos documentados na própria base; resumos textuais e exemplos incompletos não servem como fonte final de materialização
- o conteúdo foi organizado para reduzir tentativa e erro, não para eliminar risco
- existe uma pasta privada separada, `GeneXus-XPZ-PrivateMap`, usada apenas para rastreabilidade editorial privada entre aliases públicos e artefatos reais; a fonte publicada continua sendo esta raiz
- todo novo exemplo sanitizado incorporado na base pública deve receber anotação correspondente no `GeneXus-XPZ-PrivateMap`, ligando o trecho público aos objetos ou pacotes reais de origem
- **modelos de linguagem**: as skills XPZ dependem de carregamento voluntário de skills, execução sequencial de gates e respeito a constraints do tipo NEVER. O critério é a **aderência a instruções observada**, não o nome nem a versão — exemplos datados e não-exaustivos, a ajustar conforme as versões evoluem.
  - **Modelo solo** (piloto de triagem/build GeneXus, ou default recomendado a um usuário): exigir **forte aderência a instruções**; modelos que pulam etapas não são confiáveis nesse papel. Exemplos fortes (em 2026-06): DeepSeek V4 Pro, GPT-5.5, Sonnet 4.6, Opus 4.8.
  - **Voz em painel de revisão por pares** (ver `15-revisao-por-pares.md`): a **diversidade de família** é o valor; modelos menos fortes são admissíveis como **vozes adicionais** — nunca como revisor **decisivo sozinho** —, pois, lendo as fontes, pegam pontos cegos. A objeção de qualquer voz ainda passa por **triagem humana** (régua do `15`); o princípio prevalece sobre qualquer lista fixa.
  - **Veto duro** (não usar nem como voz), por baixo aterramento comprovado: Mistral Large 3, Nemotron 3 Ultra.
- **tipo desconhecido no XPZ**: sync e rebuild do índice KbIntelligence bloqueiam até o GUID estar no catálogo efetivo (base + override); a pasta paralela pode usar `scripts/gx-object-type-catalog.override.json` como paliativo local, sempre auditado por sessão. A auditoria distingue entrada pendente, redundante e divergente; redundância equivalente recomenda limpeza local aprovada em vez de pendência global; ver `02`, `08` e skills `xpz-sync` / `xpz-kb-parallel-setup`.
- **elemento de export legado GeneXus 9**: o `ExportFile` GeneXus 9 traz `<GXObject><Elemento>` por **nome**, sem GUID de tipo — fica **fora** do catálogo moderno, no registro `scripts/gx-legacy-export-element-registry.json` (doc-dono `01k`), que classifica cada elemento como `equivalent` (tipo moderno real) ou `orphan` (`typeToken` `gxlegacy/<Elemento>`); o motor de export legado já existe e está integrado ao sync/inventário (`Sync-GeneXusXpzToXml.ps1` materializa o ramo legado; `Get-GeneXusImportPackageObjectInventory.ps1` inventaria itens `known-legacy`), com pacote misto fail-closed.
- **catálogos `Transaction` (rules/events)**: ao documentar o que o Specifier aceita ou rejeita, usar os rótulos `confirmado-import`, `confirmado-build`, `confirmado-acervo`, `padrao-gx-nao-verificado` e `nao-listar` conforme `02` (Política de evidência para catálogos Transaction) e `xpz-builder/responsibilities-by-type/transaction.md`; exemplos por arquivo `.xml` referem-se à pasta paralela `ObjetosDaKbEmXml/` ou a molde sanitizado em `01*`, salvo indicação contrária.
- **escopo XPZ vs linguagem GeneXus**: esta base documenta rejeições e contratos XPZ verificados pelos scripts e skills desta raiz; o uso correto de rules, gatilhos e linguagem GeneXus é responsabilidade da documentação de produto e de skills dedicadas (ex.: nexa), não um catálogo de erros possíveis da linguagem.

### Topologia operacional

- nesta trilha, a pasta nativa da KB GeneXus e diferente da pasta paralela da KB
- nesta trilha, a pasta nativa da KB deve ser tratada como area proibida para gravacao por agentes; leitura e permitida apenas quando o fluxo operacional explicito realmente exigir
- a pasta paralela da KB e a pasta de trabalho que concentra `XPZ` exportados pela IDE, XMLs materializados pelo fluxo oficial, índice derivado para triagem e artefatos preparados para importação posterior

- `ObjetosDaKbEmXml`: snapshot oficial da KB; somente leitura para agentes
- `KbIntelligence`: pasta do índice SQLite derivado e regenerável, usado para triagem técnica e funcional curta sem substituir o snapshot oficial
- `KbIntelligence` só deve ser usado para triagem ampla quando `last_index_build_run_at` no SQLite for igual ou posterior a `last_xpz_materialization_run_at` em `kb-source-metadata.md`, `inventory_validation_status` estiver literalmente `OK` no `index-metadata` e `extractor_signature_version`/`extractor_signature_hash` na metadata coincidirem com o motor em `scripts/Build-KbIntelligenceIndex.py` do repositório ativo (via `scripts/GeneXusKbIntelligenceExtractorContract.ps1` ou gate `Test-*KbIndexGate.ps1`); todo sync XPZ/XML oficial deve regenerar/validar o índice logo depois da materialização, e índice ausente, defasado, com assinatura de extrator ausente/divergente ou semanticamente bloqueado é exceção operacional que deve bloquear pesquisa ampla/geração e oferecer atualização ao usuário
- **pré-requisito Python**: rebuild do índice KbIntelligence exige **Python 3.x utilizável** no `PATH` (`scripts/GeneXusPythonPrerequisite.ps1` via `Build-KbIntelligenceIndex.ps1`); stub da Microsoft Store (`WindowsApps`) não conta; ausência bloqueia o refresh com exit `8` e mensagem explícita — a materialização XPZ/XML pode já ter concluído; **rigor**: o sync oficial **não** termina sem índice regenerado — não declarar sync OK; ver `xpz-sync` e `08-guia-para-agente-gpt.md`
- **consultas semânticas do índice**: antes de `who-uses`, `what-uses`, `impact-basic` ou `functional-trace-basic`, conferir no catálogo efetivo (`scripts/gx-object-type-catalog.json` + `scripts/gx-object-type-catalog.override.json` na pasta paralela quando existir) se o tipo tem `queryableByKbIntelligence=true`; quando for `false`, `Query-KbIntelligenceIndex` devolve exit `11` e `blocked=true` — **não** tratar como zero dependências; preferir `object-info`, `search-objects`, `list-by-type` ou XML pontual; ver `02`, `08` e `scripts/README-kb-intelligence.md`
- **gravabilidade transacional materializada no índice**: após rebuild com `schema_version>=2`, as consultas `transaction-attributes` e `transaction-writable-attributes` expõem a classificação gravada em `transaction_attribute_writability` (paridade com `Test-GeneXusTransactionWritability.ps1` quando `Test-GeneXusKbIntelligenceWritabilityParity.ps1` passa na pasta paralela); servem para triagem — empacote com `Rules`/`Events` em `Transaction` ou blocos `New` em `Procedure` ainda exige os gates em `xpz-builder` (`Test-GeneXusTransactionWritability.ps1`, `Test-GeneXusNewWritableTargets.ps1`); ver `02`, `08` e `scripts/README-kb-intelligence.md`
- **catálogo e uso de classes CSS no índice**: a partir de `schema_version=3`, o índice cataloga as classes CSS (tabela `css_class`, dimensões `model` legacy-theme/design-system e `origin` kb-authored/packaged-module) e rastreia onde são usadas (relações `uses_css_class`/`uses_css_class_dynamic`), pelas consultas `css-classes` e `css-class-usage`; ataca o falso "não existe" do inventário incompleto (classes do `DesignSystem` não viram objeto) e do uso invisível (atribuição por código `Controle.Class = ...`, não só `class="..."` no layout); `css-class-usage` declara cobertura honesta (usos resolvíveis vs atribuições dinâmicas) e marca o modelo `legacy-theme` como depreciado; é acelerador de triagem com frescor por gate, não verdade exaustiva — operação destrutiva exige conferência por busca literal no XML; ver `02`, `08` e `scripts/README-kb-intelligence.md`
- **objetos gerados por Pattern x autorais no índice**: a partir de `schema_version=4`, o índice materializa na tabela `objects` se um objeto foi gerado por Pattern (WorkWith For Web) — colunas `is_generated_object` (0/1), `pattern_object_id` e `instance_key`, extraídas do `<Properties>` de nível-objeto (escopadas ao objeto raiz, nunca de `<Object>` aninhado em `PackagedModule`); usar o sinal determinístico e o filtro `--generated`/`--authored` (em `search-objects`/`list-by-type`) em vez de heurística de nome (`ww*`/`*WC`/`*General`/`*Selection`) ao separar autoral de gerado; `search-objects -InstanceKey <nome|<GUID>-<nome>>` faz reverse lookup por instância (lista os objetos gerados por uma instância WorkWithForWeb; auto-detecção nome vs chave completa, correspondência exata ignorando caixa) e o campo derivado `instance_name` é servido em `object-info`/`search-objects`/`list-by-type`; ver `02`, `08` e `scripts/README-kb-intelligence.md`
- `AGENTS.md` e `README.md` locais da pasta paralela não devem gravar timestamps literais de materialização ou índice; devem apontar para `kb-source-metadata.md`, para `-Query index-metadata` do wrapper local e para o gate efetivo. Timestamp literal nesses markdowns é drift documental e pendência de setup; a correção é substituir por ponteiros para as fontes autoritativas, não atualizar o valor duplicado
- `XpzExportadosPelaIDE`: pasta onde o usuário grava tanto o `XPZ` completo da Carga Inicial quanto os `XPZ` incrementais do dia a dia
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: área de trabalho para XMLs gerados, ajustados ou preservados para importação manual na IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: área de saída para `import_file.xml` e demais pacotes gerados localmente
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` são áreas gerenciadas por agente, não depósitos gerais do usuário; XML de referência, exemplo ou template deixado na frente ativa deve bloquear o empacotamento até ser removido ou tratado por caminho explícito fora da frente
- ao criar cópia alterada de XML GeneXus em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, o agente deve preservar fielmente o XML de origem fora do delta funcional aprovado: comentários, `CDATA`, indentação, linhas em branco, ordem de nós, quebras de linha e whitespace herdado não devem mudar por reconstrução ou reserialização ampla; linhas novas ou modificadas não devem nascer com espaços ou tabs finais
- em auditoria operacional da pasta paralela, declarar separadamente `sync/materializacao`, `indice/gate`, `indice/semantica` e `empacotamento local`; `GATE_OK` e estrutura OK não bastam, sozinhos, para concluir genericamente que "está tudo certo" quando a semantica do índice ou o fluxo de empacotamento local ainda não foram auditados
- `Temp`: destino preferencial de artefatos efêmeros de execução, como diretórios temporários de wrappers, logs auxiliares e saídas intermediárias que não sejam fonte normativa da base
- `ArquivoMorto`: subpasta opcional de `ObjetosGeradosParaImportacaoNaKbNoGenexus` para preservar XMLs contaminados que não devem ser importados mas precisam de rastreabilidade; não apagar sem autorizacao explicita do usuário
- em `ObjetosGeradosParaImportacaoNaKbNoGenexus`, cada frente ativa deve usar sua própria subpasta no formato `NomeCurto_GUID_YYYYMMDD`
- enquanto a mesma frente não for encerrada, microajustes sucessivos devem reutilizar essa mesma subpasta; não criar nova subpasta nem mudar `NomeCurto_GUID_YYYYMMDD` por tentativa, ajuste visual ou reimportacao da mesma frente
- `NomeCurto_GUID_YYYYMMDD` identifica a frente pela combinacao de nome curto, GUID gerado na abertura da frente e data de criacao da frente; `YYYYMMDD` representa a data de criacao da frente, não a data do pacote
- em `PacotesGeradosParaImportacaoNaKbNoGenexus`, os pacotes devem permanecer na raiz, sem subpastas, usando o formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` representa apenas a rodada curta de pacote daquela frente; não representa versão semantica
- durante a mesma frente, manter o mesmo prefixo `NomeCurto_GUID_YYYYMMDD` em todos os pacotes e alterar somente `nn`; escolher outro nome base para a mesma frente e ruido operacional, não rastreabilidade
- antes de gravar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, verificar se já existe pacote com o mesmo prefixo de frente `NomeCurto_GUID_YYYYMMDD` e o mesmo `nn`
- quando a regra for deterministica, o enforcement primario deve viver em `.ps1`; para colisao de pacote, preferir gate dedicado como `Test-XpzPackageCollision.ps1` ou wrapper local equivalente
- se já existir pacote com o mesmo prefixo de frente e o mesmo `nn`, o gate deve abortar a gravacao; não sobrescrever silenciosamente a rodada
- em caso de colisao, o erro explicito e a sugestao do próximo `nn` livre devem sair do próprio gate, sem autoincrementar nem gravar automaticamente com o valor sugerido
- a promoção para `ObjetosDaKbEmXml` ocorre apenas pelo fluxo oficial do script `.ps1` alimentado por `XPZ` exportado pela IDE
- `ObjetosDaKbEmXml` não deve ser atualizado por edição manual; ele e atualizado pelo fluxo do `.ps1` a partir dos `XPZ` disponibilizados na pasta paralela da KB
- se o objeto ainda não voltou da KB por export oficial, o trabalho deve acontecer em `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- edição detectada ou pretendida em `ObjetosDaKbEmXml` para delta ainda não reexportado oficialmente pela KB deve ser tratada como erro explícito de processo, não como detalhe operacional
- `AGENTS.md`, `README.md` e documentação equivalente da KB funcionam como camada obrigatória de especialização local; suas regras valem para aquele repositório e não devem ser promovidas automaticamente à metodologia compartilhada de XPZ
- frente tecnicamente validada não implica publicacao Git; a publicacao só ocorre com autorizacao explicita do usuário, e ate la o estado preferido e `aguardando_decisao_de_fechamento`

### Importação headless e conteúdo do pacote

- o gate `Test-GeneXusImportFileEnvelope.ps1` valida o **envelope** do pacote (`ExportFile`, `KMW`, `Source`, etc.); **não substitui** a verificacao do **conjunto de objetos** que o import aplicaria na KB
- exportação parcial pela IDE ou por `MSBuild`, mesmo com lista explicita de objetos, pode colocar no `.xpz` **objetos adicionais** (dependencias, referencias, módulos organizacionais); **não** assumir que o conteúdo do pacote coincide com a lista nominal sem inventariar o artefato
- em exportação seletiva/cirurgica via `MSBuild` cujo objetivo seja obter somente os objetos listados em `-ObjectList`, passar `-DependencyType "None" -ReferenceType "None"` para prevenir arrasto na origem; isso não substitui o inventario pos-export obrigatório, e valores além de `None`/default formal seguem em confirmacao na base operacional
- antes de **importação real** headless, o agente deve **listar todos os objetos** do pacote e confrontar com o delta declarado; extras não pedidos num pacote cirurgico exigem **ABORT** ou confirmacao explicita do usuário (pormenor nas skills `xpz-msbuild-import-export` e `xpz-builder`, e em `10-base-operacional-msbuild-headless.md`)
- **Decisão pos-gates** (contrato completo em `xpz-msbuild-import-export/SKILL.md`): com importação real já autorizada na mesma sessao, envelope `apto para prosseguir` (`Test-GeneXusImportFileEnvelope.ps1`) e inventario do pacote sem bloqueio de extras (passo 6c da skill), executar `Invoke-GeneXusXpzImport.ps1` na mesma rodada com `-StartWatcher` e `-MonitorLogPath` (obrigatórios nesse caminho); não encerrar só pelo envelope apto nem exigir `Test-GeneXusXpzImportPreview.ps1` antes do import nesse cenário; preview permanece para rodada exploratoria ou quando import real ainda não foi autorizado; autorizacao de import na sessao não cobre extras, modulos/ExternalObjects de plataforma não pedidos nem `attributesTopLevelUnreconciled` em pacote cirurgico — **ABORT** e listar o pacote completo ao usuário; **`exitCode=48`** (Categoria B: `error :` no log de export/import/preview) **bloqueia** import real na mesma rodada, mesmo com autorizacao de import na sessao; **`exitCode=50`** bloqueia por erro de parametrização de log (`-LogPath` resolvido como diretório existente), exigindo caminho de arquivo/log explícito
- **evitar** o anti-padrao export da KB como “casca” de `.xpz`, substituicao manual de nos e reempacotamento **sem** esse inventario; quando o XML já está na pasta paralela, preferir `import_file.xml` montado por motor estruturado compartilhado (`Build-GeneXusImportFileEnvelope.ps1` ou a entrada segura `New-XpzImportPackage.ps1`) com `KMW`/`Source` valido e, em pacote misto/complexo, molde real comparavel
- wrappers compartilhados de empacotamento e inventario emitem JSON de maquina por padrão no stdout e não usam `-AsJson`; wrappers locais antigos devem ser atualizados pela skill `xpz-kb-parallel-setup`. Para caminho de entrada, preferir `-InputPath`; para lista nominal `Tipo:Nome`, preferir `-ObjectList`. Bloqueios esperados retornam `status`, `exitCode`, `reason`/`stage`, `blockingReasons` e campos acionaveis como `nextFreeNN`, sem stack/ANSI no canal de maquina
- ao usar `Build-GeneXusImportFileEnvelope.ps1`, informar obrigatoriamente `-AcervoPath <ObjetosDaKbEmXml>`; o motor bloqueia antes de gravar quando há `lastUpdate` inválido contra o acervo ou `Object/@type` divergente por mesmo `guid`; objetos realmente modificados devem ser declarados por `-ModifiedObjectNames` ou `-ModifiedObjectGuids` para que o gate mecanico de `lastUpdate` bloqueie timestamps velhos, iguais ao acervo ou futuros sem justificativa antes de gravar o pacote
- ao usar `New-XpzImportPackage.ps1` (entrada segura; o `.py` é motor interno), o gate de drift 9-FD (`Test-GeneXusFrontAcervoDrift.ps1`) executa sempre antes do empacotamento (fail-closed) e bloqueia XMLs na frente com `lastUpdate` mais antigo que o homonimo no acervo ou com mesmo `guid` e `Object/@type` divergente (`front-object-type-drift`); `-AcervoPath <ObjetosDaKbEmXml>` e opcional e, quando omitido, o acervo canonico `<RepoRoot>/ObjetosDaKbEmXml` e resolvido automaticamente; sem acervo resolvivel o empacotamento e bloqueado, e o JSON reporta `acervoResolvedBy` (`explicit` ou `convention`); acervo ambíguo por GUID gera diagnóstico informativo `front-object-type-drift-ambiguous-acervo`; para drift de `Object/@type`, parar para decisao humana em vez de autocopiar/bump; para seed inicial de objeto ainda ausente na frente, usar `Copy-GeneXusAcervoToFront.ps1` com `-ObjectList`, `-ObjectNames` ou `-ObjectGuids` explicito; a pasta da frente deve já existir, aberta por `New-GeneXusXpzFront.ps1` (wrapper `New-*KbFront.ps1`, `-ReuseIfExists` para retomar), nunca criada manualmente — `Copy-GeneXusAcervoToFront.ps1` e os gates 9-* apenas populam ou inspecionam uma frente existente
- `-TemplatePackagePath` em `Build-GeneXusImportFileEnvelope.ps1` e na entrada segura `New-XpzImportPackage.ps1` aceita tanto `.import_file.xml`/XML quanto `.xpz` real comparavel; quando o template traz `Attributes` de topo e a frente não traz raizes `Attribute` explicitas, o motor preserva esses `Attributes`
- para `Panel`, especialmente Panel SD, tratar `level id` + `layout id` como par acoplado; não gera-los como GUIDs independentes; quando a regra de derivacao não estiver provada, preservar o par a partir de Panel SD exportado pela IDE da mesma KB
- em Panel SD com actions, confrontar `onClickEvent="'Nome'"` com os eventos serializados em `detail/@events`; preferir `Event 'Nome'` vindo de molde real comparavel e não sintetizar `Event Controle.Tap` sem evidencia local equivalente, ajustando sempre o nome do controle ao corpus local
- para diagnostico compacto de Panel e WebPanel, preferir `scripts/Get-GeneXusObjectSummary.ps1` (com bloco `webpanel` para WebPanel classico) e, para Panel, `scripts/Compare-GeneXusPanelShape.ps1`, antes de despejar XML/CDATA completo; para adicionar botao a WebPanel, preferir `scripts/Add-GeneXusButton.ps1` (insercao cirurgica antes ou após um controle folha via `-BeforeControlName`/`-AfterControlName`, fail-closed em tabela Responsive com breakpoints)
- no gate de envelope, um par `level id` + `layout id` de Panel só deixa de gerar ressalva quando `-PanelReferencePath` comprovar o mesmo par em pacote ou objeto comparavel explicitamente informado
- os wrappers `Test-GeneXusXpzImportPreview.ps1` e `Invoke-GeneXusXpzImport.ps1` emitem `msbuild.import.signals.json` ao lado dos logs brutos (via `Read-MsBuildImportSignals.ps1`) e também espelham esses sinais em `compactSignals` no diagnostico JSON para leitura compacta de itens importados, warnings, erros e versao/Environment ativos sem despejar stdout inteiro
- nos diagnosticos JSON dos wrappers MSBuild de preview/import/export, o código bruto da task MSBuild fica canonicamente em `executionEvidence.msBuildExitCode`; `exitCode` e o valor classificado pelo wrapper; `msBuildExitCode` top-level, quando existir, e só compatibilidade transitoria — ver `02-regras-operacionais-e-runtime.md` e `10-base-operacional-msbuild-headless.md`
- distinguir **Categoria A** (extras de inventario, modulos/ExternalObjects de plataforma, `attributesTopLevelUnreconciled` — o wrapper pode manter `exitCode=0`; **ABORT** do agente via Decisão pos-gates para extras) de **Categoria B** (linhas `error :` no log MSBuild, `invalidTypesRejected`, `exportErrors`/`importErrors`/`previewErrors`/`buildErrors`/`specifyErrors` — com `executionEvidence.msBuildExitCode=0` mas B populada, o wrapper rebaixa para **`exitCode=48`** e `msBuildCategoryBBlocked=true`; artefato no disco não autoriza entrega operacional limpa); catalogo numerico em `scripts/msbuild-exit-codes.catalog.json`; detalhe em `10-base-operacional-msbuild-headless.md` e `xpz-msbuild-import-export/SKILL.md` (seção «Categorias A e B»)
- quando `exitCode=46` representar bloqueio preventivo de `MSBuild` concorrente na mesma KB, a rodada deve parar e reportar o conflito; a trilha compartilhada não enfileira, não aguarda automaticamente e não faz retentativa em loop
- em `Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1` e em preview/export/import MSBuild longos (`Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1`), usar watcher como fluxo padrão; contrato em `scripts/GeneXusMsBuildWatcherSupport.ps1`; para `Invoke-GeneXusKbBuildAll.ps1`/`Invoke-GeneXusKbSpecifyGenerate.ps1`, o monitoramento legível pode alternativamente ser o **modo desacoplado opt-in** (`Start-GeneXusKbBuildDetached.ps1`: build longo sob Tarefa Agendada fora da sessão do agente + arquivo-sentinela), em que `watcherContext.watcherLaunched=false` é escolha deliberada, não ausência a justificar — a janela visivel permanece o default e o desacoplado é decisão consciente do usuário sob conselho do agente; ao aguardar a conclusão, combinar sentinela + heartbeat da Tarefa Agendada (helper `Wait-GeneXusKbBuildDetached.ps1`), nunca só a sentinela, e o modo não sobrevive a logoff/reboot; **fora** da **Decisão pos-gates**, execução sem watcher visivel exige justificativa operacional explicita e registro por `watcherContext.watcherLaunched=false`; em importação real de pacote amplo ou com muitos `WorkWithForWeb` **fora** desse caminho, ausencia de watcher também exige justificativa; **dentro** da Decisão pos-gates, `-StartWatcher` e `-MonitorLogPath` são obrigatórios na mesma invocacao de `Invoke-GeneXusXpzImport.ps1` (sem exceção por justificativa de ausencia)
- **não** iniciar exportação headless da KB quando o pedido foi **apenas** importar alteracoes já existentes na pasta paralela, salvo pedido ou confirmacao explicita de que o export e indispensavel
- antes de importação real via MSBuild, a skill `xpz-kb-parallel-setup` executa uma verificacao consultiva de **capacidade de importação headless** (presenca de `Test-GeneXusImportFileEnvelope.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzImport.ps1` e `GeneXusMsBuildWatcherSupport.ps1` no motor compartilhado e coerência documental mínima de `xpz-msbuild-import-export` quanto a aceitacao de `.import_file.xml` como insumo e a `ImportKbInformation` tri-state); capacidade defasada deve bloquear a importação real e encaminhar para `xpz-msbuild-import-export`, não reinterpretar o contrato localmente

### Carga inicial

- quando o usuário não informar nomes alternativos, a KB deve assumir estas subpastas padrão:
  - `scripts`
  - `Temp`
  - `XpzExportadosPelaIDE`
  - `ObjetosDaKbEmXml`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- `XpzExportadosPelaIDE` é a pasta de entrada onde o usuário do GeneXus grava os `.xpz` que serão processados
- depois de processado com sucesso pelo fluxo oficial, o `.xpz` pode ser renomeado para `processado_<nome-original>.xpz`
- `scripts` concentra os wrappers `.ps1` que tratam `XPZ` e índice derivado
- quando a pasta paralela da KB for inicializada do zero para operar com fluxo oficial de materialização XPZ/XML, o bootstrap técnico mínimo deve incluir os wrappers locais principais em `scripts`
- não declarar `setup inicial concluido` enquanto essa camada mínima de wrappers locais ainda não existir; nesse caso, o status correto e `estrutura parcial` ou `bootstrap incompleto`
- `Test-*KbSourceSanity.ps1` e recomendado quando a pasta também adotar fluxo local de geração e empacotamento; sua ausencia isolada não impede, por si só, classificar a camada mínima de wrappers do fluxo oficial de materialização ou de `KbIntelligence`
- `KbIntelligence` guarda o SQLite derivado e os relatórios de validação do índice, quando esse fluxo estiver adotado na KB
- a Carga Inicial pode usar um `XPZ` completo novo a qualquer momento para reatualizar `ObjetosDaKbEmXml`
- `XPZ` full define o insumo exportado; a materialização normal desse insumo não implica `-FullSnapshot`, que deve ficar restrito a conferencia full explicita ou exigencia documental nominal
- sob `-FullSnapshot`, o sync reconcilia o acervo por `guid` (identidade estável do nó raiz): um rename (mesmo `guid`, nome diferente) é tratado como rename do arquivo no acervo (`Move-Item`), não como delete-antigo + create-novo; cobre `Attribute` e `Object`, e o git detecta rename por similaridade
- a mesma estrutura também vale para `XPZ` parciais com objetos alterados desde a última atualização
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` guarda objetos temporários destinados à importação manual na IDE
- cada frente ativa em `ObjetosGeradosParaImportacaoNaKbNoGenexus` deve ter sua própria subpasta `NomeCurto_GUID_YYYYMMDD`
- essa subpasta da frente e a unidade ativa da frente de trabalho
- ao retomar uma frente existente, reutilizar a mesma subpasta da frente em vez de criar outra
- XML de referência, exemplo ou template não deve ser salvo na frente ativa em `ObjetosGeradosParaImportacaoNaKbNoGenexus`; se aparecer ali, o empacotamento deve bloquear em vez de tentar classificar ou importar esse arquivo
- `PacotesGeradosParaImportacaoNaKbNoGenexus` guarda o pacote `.xml` e, quando necessário, também `.xpz`, que será importado pela IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus` deve permanecer plano, sem subpastas por frente; o vinculo com a frente fica apenas no prefixo `NomeCurto_GUID_YYYYMMDD` somado ao `nn`
- por padrão, `ObjetosGeradosParaImportacaoNaKbNoGenexus` e `PacotesGeradosParaImportacaoNaKbNoGenexus` não precisam ser versionadas em Git; se houver duvida sobre rastrear ou ignorar seu conteúdo, isso deve ser tratado como decisão de politica do repositório
- `AGENTS.md` e `README.md` podem existir na raiz ou em subpastas quando houver anotação operacional pertinente
- se alguma dessas subpastas ainda não existir, a ordem recomendada de criação é:
  1. `scripts`
  2. `Temp`
  3. `XpzExportadosPelaIDE`
  4. `ObjetosDaKbEmXml`
  5. `KbIntelligence`
  6. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  7. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- quando a pasta paralela já estiver versionada em Git e o setup inicial partir de estrutura vazia, `.gitignore` na raiz e `.gitkeep` nas subpastas vazias fazem parte do bootstrap esperado
- quando a pasta paralela ainda não estiver versionada em Git, o agente pode oferecer inicializar versionamento Git local como passo opcional; não deve executar `git init` sem aprovacao explicita do usuário
- se o usuário aceitar versionamento Git local e o Git não estiver funcional no ambiente, o agente pode oferecer instalar ou orientar a instalacao antes do bootstrap Git
- alterar `.gitignore`, politica de versionamento ou escopo de arquivos rastreados para viabilizar `git add`/`commit` e decisão de politica do repositório; o agente pode diagnosticar e propor opções, mas não deve mudar essa politica automaticamente só para concluir o fechamento
- quando `XpzExportadosPelaIDE` ainda não existir, o agente deve perguntar onde o usuário pretende salvar os `.xpz` antes de prosseguir com o processamento
- no setup inicial da pasta paralela da KB, se o caminho da pasta nativa da KB não vier informado, o agente deve pedir esse caminho ao usuário antes de concluir o setup
- no setup inicial da pasta paralela da KB, `kb-source-metadata.md` deve nascer em formato compativel com o motor compartilhado e preservar o campo nominal `last_xpz_materialization_run_at`
- no setup inicial da pasta paralela da KB, quando a pasta nativa da KB estiver confirmada, a identidade estavel deve ser reconciliada a partir da KB nativa local por `scripts/Resolve-GeneXusKbIdentity.ps1`; campos ausentes em `kb-source-metadata.md` podem ser preenchidos por `scripts/Update-XpzKbSourceMetadataIdentity.ps1` em frente aprovada, preservando os demais metadados
- tratar `kb-source-metadata.md` por autoridade de campo: identidade estavel da KB pertence ao setup/resolvedor da KB nativa local, `KMW` vem de XPZ real ou template comparavel, metadados de materialização pertencem ao `xpz-sync`, e `last_setup_audit_run_at`/`setup_contract_signature_*` pertencem ao setup/auditoria (`xpz-kb-parallel-setup`)
- tratar os campos de environment/deploy/output (`deployment_environment_name`, `deployment_hosting_kind`, `kb_environment_count`, `kb_environment_names`, `kb_environment_output_dirs`, `kb_environment_web_dirs`, `kb_environment_post_build_event_hashes`; para env Java/Tomcat, `kb_environment_servlet_dirs`/`kb_environment_app_package`/`kb_environment_servlet_flavor` — AUDIT_REQUIRED) como autoridade do setup/auditoria (`xpz-kb-parallel-setup`): os nomes vêm de lista declarada pelo usuário em `-KbEnvironmentNames`, os diretórios de output vêm de `-KbEnvironmentOutputDirs` e a validação MSBuild (`SetActiveEnvironment`) é obrigatória, sem scan de pastas da KB nativa; `metadata/deploy` diferente de `OK` bloqueia estado limpo até reconciliação. Para Java/Tomcat, `Resolve-XpzJavaTomcatMetadataSuggestion.ps1` é apenas assistente read-only: lê `model.ini`/`gradle.properties`, valida topologia/sentinelas/pacote e exige confirmação explícita antes de qualquer gravação por `Set-*KbSourceMetadataDeployment.ps1`. Em validação pós-import, `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` devem usar `-ParallelKbRoot`/`-KbMetadataPath` e, quando aplicável, `-PostImportDeployValidation` para checar publicação no `web\bin` resolvido por `kb_environment_web_dirs` por DLL de objeto ou `*.config`; `GxNetCoreStartup.dll` sozinho não prova deploy atualizado; eventos pós-build conhecidos por environment ficam em `kb_environment_post_build_event_hashes` (registro via `Register-GeneXusKbPostBuildEvents.ps1` após confirmação), e o build não rebaixa o status por eventos registrados — não registrado rebaixa por cautela, sem registro um player de som é reconhecido como benigno; esse campo é autoria do `Register-GeneXusKbPostBuildEvents.ps1` (sob `xpz-kb-parallel-setup`) e **não** integra o conjunto de campos de deploy validado pela auditoria de metadata (`Test-XpzKbMetadataWrapper.ps1`); `deployment_hosting_kind` é validado contra o registro-fonte-única `GeneXusKbHostingKindSupport.ps1` (`dotnet-core-self-host`, `dotnet-framework-iis`, `java-tomcat`) com suporte **por eixo** (Fase 3) — para `java-tomcat`, o **Eixo A (deploy-bin) roda o co-gate Java** por família (publicação atestada no `WEB-INF\classes` externo; `fresh`/`stale`/`no-evidence`/`unexpected-publication`/`unknown`); só o diagnóstico de `.cs` gerado (Eixo B) e o runtime-freshness (Eixo C) pulam com `skipped-hosting-unsupported`/`exit 0` (Pós-v1; **skip ≠ deploy validado**)
- após auditoria de setup bem-sucedida com `GATE_OK`, gravar `last_setup_audit_run_at` e `setup_contract_signature_*` na mesma sessao via `scripts/Set-XpzSetupAuditTimestamp.ps1` (wrapper local `Set-*KbSetupAuditTimestamp.ps1`) quando `Test-*KbSetupFreshness.ps1` tiver exigido auditoria completa por campo ausente, assinatura ausente ou assinatura defasada; adiar só com recusa ou adiamento explicito do usuário
- após auditoria mínima de pasta paralela (`xpz-kb-parallel-setup`), o agente deve montar um **plano consolidado de correcoes** com tudo que a skill classificar como corrigivel na pasta, oferecer execução na mesma sessao após aprovacao quando exigida, e não encerrar só com diagnostico quando houver item corrigivel; `GATE_OK` libera a tarefa do usuário mas não dispensa o plano
- quando o sync XPZ/XML atualizar `kb-source-metadata.md` com `-KbMetadataPath`, o motor `scripts/Sync-GeneXusXpzToXml.ps1` (via `scripts/XpzKbSourceMetadataEditSupport.ps1`) faz atualizacao **cirurgica** dos campos de materialização, preservando `last_setup_audit_run_at`, `setup_contract_signature_*`, demais frontmatter fora do escopo e EOL dominante (`scripts/XpzTextFileEolSupport.ps1`)
- `Source` vazio ou incompleto em XPZ pode ser metadado incompleto da própria KB; `Source/@kb` preenchido com GUID de outra KB indica pacote cross-KB e bloqueia importação headless por agente, encaminhando para avaliacao/importacao manual pela IDE
- quando `ObjetosDaKbEmXml` ainda não existir, o agente deve tratar isso como KB ainda não materializada e parar antes de assumir qualquer snapshot
- ao concluir o setup inicial da pasta paralela da KB, o agente deve deixar explicito que a estrutura está pronta, mas `ObjetosDaKbEmXml` ainda não foi materializada
- ao concluir o setup inicial, o agente deve oferecer `A)` exportação do `.xpz` full pela IDE para `XpzExportadosPelaIDE` ou `B)` geração do `.xpz` full a partir da pasta nativa da KB via trilha `MSBuild`, seguida de materialização dos XMLs
- no fechamento do setup inicial, `A)` deve ser apresentado como caminho preferencial e normalmente mais rápido; `B)` deve ser apresentado como caminho possível, porém mais lento por depender da trilha via `MSBuild`

### Automação operacional

- o script `scripts/Sync-GeneXusXpzToXml.ps1` faz parte da infraestrutura operacional desta base e não deve ser removido do repositório público
- esse script pode ser usado por projetos de produção que mantenham acervos versionados de XMLs extraidos de `XPZ`
- esse script emite o resultado como **linha JSON de máquina no stdout** (`Kind=xpz-sync-result`, `SchemaVersion=1`; texto humano no stderr) com listas nominais dos objetos materializados (`CreatedNames`/`UpdatedNames`/`UnchangedNames`/...); o relatório completo continua disponível via `-ReportPath`. Consumidores que liam a saída textual anterior precisam passar a ler o JSON (mudança de contrato registrada no `CHANGELOG`)
- a pasta `scripts/` existe como apoio operacional, analitico e editorial compartilhavel, mas não é fonte normativa da documentação consolidada da raiz
- a pasta `scripts-maintenance/` concentra ferramentas de manutencao desta base, como campanhas empiricas para atualizar catalogos e documentação; esses scripts não são runtime publico das skills em pastas paralelas de KB
- os scripts públicos desta raiz devem operar por parâmetros explícitos de entrada e saída, sem depender de caminhos absolutos privados
- os scripts públicos desta raiz têm contrato de runtime em `pwsh` com PowerShell 7.4 LTS ou superior; usar a versão LTS mais recente disponível é preferível; Windows PowerShell 5.1 (`powershell.exe`) não é runtime suportado para esses scripts
- pontos de entrada públicos em `scripts/*.ps1` devem declarar `#requires -Version 7.4`; a exceção é `Test-XpzPowerShellRuntime.ps1`, que precisa continuar executável em Windows PowerShell 5.1 para localizar `pwsh` e emitir bloqueio claro
- a validação automática de parse PowerShell da base é `scripts/Test-PsScriptsParse.ps1`, também executada pelo workflow `.github/workflows/parse-ps-scripts.yml`; ela verifica `scripts/*.ps1`, `scripts-maintenance/*.ps1` e `.example.ps1` das skills fora de `historico/` sob o contrato `pwsh` 7.4+
- a skill `xpz-kb-parallel-setup` deve criar/validar um wrapper local `Test-*KbPowerShellRuntime.ps1`; esse wrapper precisa barrar qualquer uso operacional da pasta paralela quando `pwsh` 7.4 LTS ou superior estiver ausente
- a auditoria compartilhada `Test-XpzSetupAudit.ps1` detecta autonomamente `scripts/Test-*KbPowerShellRuntime.ps1` quando o caminho não é informado; se o wrapper estiver ausente, emite o caminho sugerido e o molde canônico, sem criar arquivo automaticamente
- os `.example.ps1` publicados nas skills funcionam como exemplos metodologicos importantes para bootstrap técnico e reconstrucao assistida de wrappers locais finais
- esses `.example.ps1` não substituem o wrapper local real da pasta paralela da KB e não devem virar fallback automático de execução no fluxo normal
- quando a sessao já publicar o caminho de uma skill ou de seus exemplos, esse caminho publicado prevalece sobre heuristica local de instalacao
- memoria operacional de setup e compatibilidade deve permanecer primeiro na própria pasta paralela da KB, em `AGENTS.md`, `README.md` e arquivos operacionais locais; memoria externa do agente fora do repositório não deve ser tratada como requisito nem ser gravada sem autorizacao explicita do usuário
- se o motor precisar evoluir, a mudança deve preservar compatibilidade com esse uso ou ser acompanhada de atualização explícita dos wrappers consumidores

---

## Español

Este repositorio reúne documentación consolidada sobre análisis estructural de objetos GeneXus a partir de XMLs extraídos de `XPZ`, con foco en skills para agentes dedicadas al ecosistema `XPZ`/XML de GeneXus, en especial `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon`, `xpz-kb-parallel-setup`, `xpz-kb-parallel-pre-push`, `xpz-msbuild-import-export`, `xpz-msbuild-build`, `xpz-index-triage`, `xpz-llm-delegate`, `xpz-skills-setup` y `xpz-codex-apply-patch-alternative`.

- lectura e interpretación de estructura XML
- familias estructurales de objetos
- riesgo por tipo de objeto
- clonación conservadora
- apoyo a la generación asistida de `XPZ`
- validación documental de contenedor e importación en casos controlados

### Qué encontrarás aquí

Los archivos de abajo forman la base compartida principal de esta raíz, consolidada para facilitar lectura, mantenimiento y uso controlado.

Además de esa base principal, la raíz también puede contener documentación operativa complementaria de frentes activas, cuando todavía necesite permanecer visible fuera de `historico/`.

- `00-indice-da-base-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `01a-catalogo-e-padroes-empiricos.md` en adelante (hijos de la serie `01`)
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `04b-ucw-gxcontroltype-reference.md`: catálogo de User Controls (`gxControlType`) en `GxMultiForm`, tabla de carga por contexto, reglas de eventos de UC y SDT `FileUploadData`
- `05-transaction-familias-e-templates.md`
- `05b-procedure-relatorio-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-inventario-e-rastreabilidade-publica.md`
- `10-base-operacional-msbuild-headless.md`: base operacional de la trilha MSBuild headless, usada por las skills `xpz-msbuild-import-export` y `xpz-msbuild-build`
- `10a-gx-export-task-labels.md`: divergencias entre rótulos de la task Export (`-ObjectList`) y el catálogo interno / KbIntelligence; complementa `10-base` en exportación selectiva (`exportTaskLabel`)

Los archivos `10-matriz-part-types-por-tipo.md`, `11-campos-estaveis-vs-variaveis.md` y `12-diffs-estruturais-por-tipo.md` son stubs de compatibilidad retroactiva: cada uno redirige al equivalente en la serie `01` (`01b`, `01c`, `01d`). No contienen contenido propio y no deben usarse como fuente directa.

### Documentos de gobernanza pública

- `CHANGELOG.md`: registro de cambios relevantes desde la adopción del changelog.
- `CONTRIBUTING.md`: guía para contribuciones, revisión previa al push y cuidado con datos reales.
- `SECURITY.md`: política para reporte privado de vulnerabilidades, filtraciones y riesgos operativos sensibles.
- `CODE_OF_CONDUCT.md`: código de conducta para interacciones vinculadas al proyecto.

### Documentacion operacional KB Intelligence

Guía operacional y metodológica de la trilha KB Intelligence. Los contratos de fases cerradas y los registros históricos están en `historico/kb-intelligence/`.

- `kb-intelligence-guia-metodologico-agente.md`: roteiro de investigación funcional, checklist operacional, ejemplos sanitizados y modelo de respuesta para agentes
- `scripts/README-kb-intelligence.md`: guía operacional de scripts, comandos de consulta, gates de frescura y baterías de validación

### Skills para agentes

- `xpz-reader`: apoyo a la lectura e interpretación estructural de `XPZ` y XMLs relacionados
- `xpz-builder`: apoyo a la materialización controlada de artefactos y envelopes `XPZ`
- `xpz-sync`: orquestación de sincronización y verificación del acervo XML a partir de parámetros explícitos y scripts en `scripts/`
- `xpz-daemon`: instalación y gestión de un monitor persistente que observa carpetas de XPZ y dispara sincronización automáticamente al detectar nuevos archivos
- `xpz-doc-builder`: generación y recomposición de documentación Markdown a partir del acervo XML y de moldes sanitizados
- `xpz-kb-parallel-setup`: preparación y validación de la estructura inicial de la carpeta paralela de la KB
- `xpz-kb-parallel-pre-push`: validación pre-push del estado de una carpeta paralela de la KB antes del push de esa KB (orquestador de gates mecánicos G0–G5 + K1–K4/K8/K9/K11); distinta de la rutina pre-push del repositorio de skills (documento 13)
- `xpz-msbuild-import-export`: skill experimental para importación y exportación de `XPZ` vía `MSBuild`, con ejecución sin interfaz gráfica, parámetros explícitos, trazabilidad y compuertas de seguridad
- `xpz-msbuild-build`: skill para validación de build pós-import vía `MSBuild`, con ejecución sin interfaz gráfica, clasificación de resultado y bloqueo de reorg por defecto
- `xpz-index-triage`: triaje inicial por índice derivado para orientar la lectura mínima de los XML oficiales de la KB
- `xpz-llm-delegate`: delegación de tareas menores o segunda opinión a un LLM secundario vía opencode (modelos en formato `provider/modelo`, incluidos proveedores cloud conocidos como `ollama-cloud/*` y `opencode-go/*`), Codex (`codex exec`), Claude Code (`claude -p`, Opus 4.8), GitHub Copilot CLI (`copilot -p`) o Gemini CLI (`gemini -p`), con clasificación local/externo determinística y gate de confidencialidad por KB (clave de destino, nunca el adapter); activación siempre humana (incluye conducción de revisión por pares multimodelo, ver `15-revisao-por-pares.md`)
- `xpz-skills-setup`: auditoría y mantenimiento del registro global de las skills XPZ en las herramientas de agente instaladas en la máquina; incluye el bootstrap de una carpeta descargada como ZIP de GitHub — instalar Git cuando falte y vincularla al repositorio oficial; también valida y registra la skill externa gestionada `nexa`, clonando su repositorio oficial (`genexuslabs/genexus-skills`) cuando falte
- `xpz-codex-apply-patch-alternative`: backup auditable mediante motor PowerShell para aplicar parches Git textuales aprobados en Codex cuando la ruta nativa `apply_patch` no esté disponible, falle antes de escribir localmente o sea solicitada explícitamente; el registro global queda para una fase posterior

### Lectura recomendada para humanos

Si quieres entender la base rápidamente:

1. empieza por `00-indice-da-base-genexus-xpz-xml.md`
2. continúa con `01-base-empirica-geral.md` y baja al hijo de la serie `01` más adherente al caso (`01a` a `01h`, hijos empíricos)
3. luego lee `02-regras-operacionais-e-runtime.md`
4. después lee `03-risco-e-decisao-por-tipo.md`
5. para casos prácticos, usa `04-webpanel-familias-e-templates.md`, `05-transaction-familias-e-templates.md` y `05b-procedure-relatorio-familias-e-templates.md`
6. si quieres ver límites y siguientes frentes, lee `07-open-points-e-checklist.md`
7. para consumo por otro agente GPT, termina en `08-guia-para-agente-gpt.md`
8. para verificar trazabilidad del inventario, consulta `09-inventario-e-rastreabilidade-publica.md`

`06-padroes-de-objeto-e-nomenclatura.md`: lectura suplementaria — indicado cuando la duda involucre nomenclatura de objetos, prefijos de tipo o comportamiento de `Folder` vs `Module` en `fullyQualifiedName`.

### Avisos importantes

- esta base prioriza evidencia estructural observada en XML
- no promete éxito de importación o build sin validación externa
- la base ya incorpora pruebas documentadas de importación en casos controlados, pero eso no elimina el riesgo
- antes de generar `import_file.xml` o paquete importable, la trilha debe separar explícitamente `XML bien formado` de `Source GeneXus estructuralmente conservador/probablemente importable`; el parseo XML por sí solo no alcanza
- en revisión y sanity de objeto legado, la trilha debe separar explícitamente `sanity absoluto del artefacto actual` de `comparacion contra baseline oficial`; `igual al baseline` no significa `bueno`, y `peor que el baseline` indica regresion del delta
- moldes sanitizados completos pueden servir como punto de partida en escenarios específicos documentados en la propia base; resúmenes textuales y ejemplos incompletos no sirven como fuente final de materialización
- el contenido fue organizado para reducir prueba y error, no para eliminar riesgo
- existe una carpeta privada separada, `GeneXus-XPZ-PrivateMap`, usada solo para trazabilidad editorial privada entre aliases públicos y artefactos reales; la fuente publicada sigue siendo esta raíz
- todo nuevo ejemplo sanitizado incorporado en la base pública debe recibir una anotación correspondiente en `GeneXus-XPZ-PrivateMap`, vinculando el trecho público con los objetos o paquetes reales de origen
- **modelos de lenguaje**: las skills XPZ dependen de carga voluntaria de skills, ejecución secuencial de gates y respeto a constraints del tipo NEVER. El criterio es la **adherencia a instrucciones observada**, no el nombre ni la versión — ejemplos fechados y no exhaustivos, a ajustar conforme evolucionan las versiones.
  - **Modelo solo** (piloto de triaje/build GeneXus, o default recomendado a un usuario): exigir **fuerte adherencia a instrucciones**; los modelos que saltan etapas no son confiables en ese papel. Ejemplos fuertes (en 2026-06): DeepSeek V4 Pro, GPT-5.5, Sonnet 4.6, Opus 4.8.
  - **Voz en panel de revisión por pares** (ver `15-revisao-por-pares.md`): la **diversidad de familia** es el valor; los modelos menos fuertes son admisibles como **voces adicionales** — nunca como revisor **decisivo en solitario** —, pues, leyendo las fuentes, detectan puntos ciegos. La objeción de cualquier voz aún pasa por **triaje humano** (regla del `15`); el principio prevalece sobre cualquier lista fija.
  - **Veto duro** (no usar ni como voz), por bajo anclaje comprobado: Mistral Large 3, Nemotron 3 Ultra.
- **tipo desconocido en XPZ**: el sync y el rebuild del índice KbIntelligence bloquean hasta que el GUID esté en el catálogo efectivo (base + override); la carpeta paralela puede usar `scripts/gx-object-type-catalog.override.json` como paliativo local, siempre auditado por sesión. La auditoría distingue entrada pendiente, redundante y divergente; una redundancia equivalente recomienda limpieza local aprobada en lugar de pendiente global; ver `02`, `08` y skills `xpz-sync` / `xpz-kb-parallel-setup`.
- **elemento de export legado GeneXus 9**: el `ExportFile` GeneXus 9 trae `<GXObject><Elemento>` por **nombre**, sin GUID de tipo — queda **fuera** del catálogo moderno, en el registro `scripts/gx-legacy-export-element-registry.json` (documento dueño `01k`), que clasifica cada elemento como `equivalent` (tipo moderno real) u `orphan` (`typeToken` `gxlegacy/<Elemento>`); el motor de exportación legado ya existe y está integrado al sync/inventario (`Sync-GeneXusXpzToXml.ps1` materializa la rama legada; `Get-GeneXusImportPackageObjectInventory.ps1` inventaria ítems `known-legacy`), con paquete mixto fail-closed.
- **catálogos `Transaction` (rules/events)**: al documentar lo que el Specifier acepta o rechaza, usar las etiquetas `confirmado-import`, `confirmado-build`, `confirmado-acervo`, `padrao-gx-nao-verificado` y `nao-listar` según `02` (Política de evidencia para catálogos Transaction) y `xpz-builder/responsibilities-by-type/transaction.md`; ejemplos por archivo `.xml` apuntan a la carpeta paralela `ObjetosDaKbEmXml/` o a molde sanitizado en `01*`, salvo indicación contraria.
- **alcance XPZ vs lenguaje GeneXus**: esta base documenta rechazos y contratos XPZ verificados por los scripts y skills de esta raíz; el uso correcto de rules, disparadores y lenguaje GeneXus es responsabilidad de la documentación de producto y de skills dedicadas (ej.: nexa), no un catálogo de errores posibles del lenguaje.

### Topología operativa

- en esta trilha, la carpeta nativa de la KB GeneXus es distinta de la carpeta paralela de la KB
- en esta trilha, la carpeta nativa de la KB debe tratarse como área prohibida para escritura por agentes; la lectura solo se permite cuando el flujo operativo explícito realmente lo exija
- la carpeta paralela de la KB es la carpeta de trabajo que concentra `XPZ` exportados por la IDE, XMLs materializados por el flujo oficial, índice derivado para triaje y artefactos preparados para importación posterior

- `ObjetosDaKbEmXml`: snapshot oficial de la KB; solo lectura para agentes
- `KbIntelligence`: carpeta del índice SQLite derivado y regenerable, usado para triaje técnico y funcional corto sin sustituir el snapshot oficial
- `KbIntelligence` solo debe usarse para triaje amplio cuando `last_index_build_run_at` en SQLite sea igual o posterior a `last_xpz_materialization_run_at` en `kb-source-metadata.md`, `inventory_validation_status` sea literalmente `OK` en `index-metadata` y `extractor_signature_version`/`extractor_signature_hash` en la metadata coincidan con el motor en `scripts/Build-KbIntelligenceIndex.py` del repositorio activo (via `scripts/GeneXusKbIntelligenceExtractorContract.ps1` o gate `Test-*KbIndexGate.ps1`); todo sync XPZ/XML oficial debe regenerar/validar el indice inmediatamente despues de la materializacion, y un indice ausente, desfasado, con firma de extractor ausente/divergente o semanticamente bloqueado es una excepcion operativa que debe bloquear investigacion amplia/generacion y ofrecer actualizacion al usuario
- **pre-requisito Python**: el rebuild del indice KbIntelligence exige **Python 3.x utilizable** en el `PATH` (`scripts/GeneXusPythonPrerequisite.ps1` via `Build-KbIntelligenceIndex.ps1`); el stub de Microsoft Store (`WindowsApps`) no cuenta; la ausencia bloquea el refresh con exit `8` y mensaje explicito — la materializacion XPZ/XML puede haber concluido ya; **rigor**: el sync oficial **no** termina sin indice regenerado — no declarar sync OK; ver `xpz-sync` y `08-guia-para-agente-gpt.md`
- **consultas semanticas del indice**: antes de `who-uses`, `what-uses`, `impact-basic` o `functional-trace-basic`, conferir en el catalogo efectivo (`scripts/gx-object-type-catalog.json` + `scripts/gx-object-type-catalog.override.json` en la carpeta paralela cuando exista) si el tipo tiene `queryableByKbIntelligence=true`; cuando sea `false`, `Query-KbIntelligenceIndex` devuelve exit `11` y `blocked=true` — **no** tratar como cero dependencias; preferir `object-info`, `search-objects`, `list-by-type` o XML puntual; ver `02`, `08` y `scripts/README-kb-intelligence.md`
- **gravabilidad transaccional materializada en el indice**: despues del rebuild con `schema_version>=2`, las consultas `transaction-attributes` y `transaction-writable-attributes` exponen la clasificacion grabada en `transaction_attribute_writability` (paridad con `Test-GeneXusTransactionWritability.ps1` cuando `Test-GeneXusKbIntelligenceWritabilityParity.ps1` pasa en la carpeta paralela); sirven para triaje — el empaquetado con `Rules`/`Events` en `Transaction` o bloques `New` en `Procedure` aun exige los gates en `xpz-builder` (`Test-GeneXusTransactionWritability.ps1`, `Test-GeneXusNewWritableTargets.ps1`); ver `02`, `08` y `scripts/README-kb-intelligence.md`
- **catalogo y uso de clases CSS en el indice**: a partir de `schema_version=3`, el indice cataloga las clases CSS (tabla `css_class`, dimensiones `model` legacy-theme/design-system y `origin` kb-authored/packaged-module) y rastrea donde se usan (relaciones `uses_css_class`/`uses_css_class_dynamic`), mediante las consultas `css-classes` y `css-class-usage`; ataca el falso "no existe" del inventario incompleto (las clases del `DesignSystem` no se vuelven objeto) y del uso invisible (asignacion por codigo `Controle.Class = ...`, no solo `class="..."` en el layout); `css-class-usage` declara cobertura honesta (usos resolubles vs asignaciones dinamicas) y marca el modelo `legacy-theme` como obsoleto; es acelerador de triaje con frescura por gate, no verdad exhaustiva — la operacion destructiva exige verificacion por busqueda literal en el XML; ver `02`, `08` y `scripts/README-kb-intelligence.md`
- **objetos generados por Pattern vs autorales en el indice**: a partir de `schema_version=4`, el indice materializa en la tabla `objects` si un objeto fue generado por Pattern (WorkWith For Web) — columnas `is_generated_object` (0/1), `pattern_object_id` e `instance_key`, extraidas del `<Properties>` de nivel-objeto (acotadas al objeto raiz, nunca de `<Object>` anidado en `PackagedModule`); usar la señal determinista y el filtro `--generated`/`--authored` (en `search-objects`/`list-by-type`) en vez de heuristica de nombre (`ww*`/`*WC`/`*General`/`*Selection`) al separar autoral de generado; `search-objects -InstanceKey <nombre|<GUID>-<nombre>>` hace reverse lookup por instancia (lista los objetos generados por una instancia WorkWithForWeb; autodeteccion nombre vs clave completa, coincidencia exacta ignorando mayusculas/minusculas) y el campo derivado `instance_name` se sirve en `object-info`/`search-objects`/`list-by-type`; ver `02`, `08` y `scripts/README-kb-intelligence.md`
- `AGENTS.md` y `README.md` locales de la carpeta paralela no deben grabar timestamps literales de materializacion o indice; deben apuntar a `kb-source-metadata.md`, a `-Query index-metadata` del wrapper local y al gate efectivo. Un timestamp literal en esos markdowns es drift documental y pendiente de setup; la correccion es sustituirlo por punteros a las fuentes autoritativas, no actualizar el valor duplicado
- `XpzExportadosPelaIDE`: carpeta donde el usuario graba tanto el `XPZ` completo de la Carga Inicial como los `XPZ` incrementales del día a día
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: área de trabajo para XMLs generados, ajustados o preservados para importación manual en la IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: área de salida para `import_file.xml` y demás paquetes generados localmente
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` y `PacotesGeradosParaImportacaoNaKbNoGenexus` son áreas gestionadas por agente, no depósitos generales del usuario; un XML de referencia, ejemplo o template dejado en la frente activa debe bloquear el empaquetado hasta que sea removido o tratado por un camino explícito fuera de la frente
- al crear una copia modificada de XML GeneXus en `ObjetosGeradosParaImportacaoNaKbNoGenexus`, el agente debe preservar fielmente el XML de origen fuera del delta funcional aprobado: comentarios, `CDATA`, indentación, líneas en blanco, orden de nodos, saltos de línea y whitespace heredado no deben cambiar por reconstrucción o reserialización amplia; las líneas nuevas o modificadas no deben nacer con espacios o tabs finales
- en auditoría operativa de la carpeta paralela, declarar por separado `sync/materialización`, `índice/gate`, `índice/semántica` y `empaquetado local`; `GATE_OK` y estructura OK no bastan, por sí solos, para concluir genéricamente que "todo está bien" cuando la semántica del índice o el flujo de empaquetado local todavía no fueron auditados
- `Temp`: destino preferente de artefactos efímeros de ejecución, como directorios temporales de wrappers, logs auxiliares y salidas intermedias que no sean fuente normativa de la base
- `ArquivoMorto`: subcarpeta opcional de `ObjetosGeradosParaImportacaoNaKbNoGenexus` para preservar XML contaminados que no deben importarse pero necesitan trazabilidad; no borrar sin autorización explícita del usuario
- en `ObjetosGeradosParaImportacaoNaKbNoGenexus`, cada frente activa debe usar su propia subcarpeta con el formato `NomeCurto_GUID_YYYYMMDD`
- mientras la misma frente no esté cerrada, los microajustes sucesivos deben reutilizar esa misma subcarpeta; no crear una nueva subcarpeta ni cambiar `NomeCurto_GUID_YYYYMMDD` por intento, ajuste visual o reimportación de la misma frente
- `NomeCurto_GUID_YYYYMMDD` identifica la frente por la combinación de nombre corto, GUID generado al abrir la frente y fecha de creación de la frente
- en `PacotesGeradosParaImportacaoNaKbNoGenexus`, los paquetes deben permanecer en la raíz, sin subcarpetas, usando el formato `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` representa solo la ronda corta del paquete en esa frente; no representa versión semántica
- durante la misma frente, mantener el mismo prefijo `NomeCurto_GUID_YYYYMMDD` en todos los paquetes y alterar solo `nn`; elegir otro nombre base para la misma frente es ruido operativo, no trazabilidad
- antes de grabar `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, verificar si ya existe un paquete con el mismo prefijo de frente `NomeCurto_GUID_YYYYMMDD` y el mismo `nn`
- si ya existe un paquete con el mismo prefijo de frente y el mismo `nn`, abortar la grabación; no sobrescribir silenciosamente la ronda
- cuando la regla sea determinística, el enforcement primario debe vivir en `.ps1`; para colisión de paquete, preferir un gate dedicado como `Test-XpzPackageCollision.ps1` o un wrapper local equivalente
- en caso de colisión, el error explícito y la sugerencia del próximo `nn` libre deben salir del propio gate, sin autoincrementar ni grabar automáticamente con el valor sugerido
- la promoción hacia `ObjetosDaKbEmXml` ocurre solo por el flujo oficial del script `.ps1` alimentado por el `XPZ` exportado por la IDE
- `ObjetosDaKbEmXml` no debe actualizarse por edición manual; se actualiza por el flujo del `.ps1` a partir de los `XPZ` disponibilizados en la carpeta paralela de la KB
- si el objeto todavía no volvió de la KB por export oficial, el trabajo debe ocurrir en `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- una edición detectada o pretendida en `ObjetosDaKbEmXml` para un delta aún no reexportado oficialmente por la KB debe tratarse como error explícito de proceso, no como detalle operativo
- `AGENTS.md`, `README.md` y documentación equivalente de la KB funcionan como capa obligatoria de especialización local; sus reglas valen para ese repositorio y no deben promoverse automáticamente a la metodología compartida de XPZ
- una frente técnicamente validada no implica publicación Git; la publicación solo ocurre con autorización explícita del usuario, y hasta entonces el estado preferido es `aguardando_decisao_de_fechamento`

### Importación headless y contenido del paquete

- el gate `Test-GeneXusImportFileEnvelope.ps1` valida el **envoltorio** del paquete (`ExportFile`, `KMW`, `Source`, etc.); **no sustituye** la verificación del **conjunto de objetos** que el import aplicaría a la KB
- la exportación parcial por IDE o por `MSBuild`, aun con lista explícita de objetos, puede incluir en el `.xpz` **objetos adicionales** (dependencias, referencias, módulos organizacionales); **no** asumir que el contenido coincide con la lista nominal sin inventariar el artefacto
- en exportación selectiva/quirúrgica vía `MSBuild` cuyo objetivo sea obtener solo los objetos listados en `-ObjectList`, pasar `-DependencyType "None" -ReferenceType "None"` para prevenir arrastre en origen; esto no sustituye el inventario pos-export obligatorio, y los valores además de `None`/default formal siguen en confirmación en la base operacional
- antes de una **importación real** headless, el agente debe **listar todos los objetos** del paquete y confrontarlos con el delta declarado; extras no pedidos en un paquete quirúrgico implican **ABORT** o confirmación explícita del usuario (detalle en las skills `xpz-msbuild-import-export` y `xpz-builder`, y en `10-base-operacional-msbuild-headless.md`)
- **Decisión pos-gates** (contrato completo en `xpz-msbuild-import-export/SKILL.md`): con importación real ya autorizada en la misma sesión, envelope `apto para prosseguir` (`Test-GeneXusImportFileEnvelope.ps1`) y inventario del paquete sin bloqueo de extras (paso 6c de la skill), ejecutar `Invoke-GeneXusXpzImport.ps1` en la misma ronda con `-StartWatcher` y `-MonitorLogPath` (obligatorios en ese camino); no cerrar solo por envelope apto ni exigir `Test-GeneXusXpzImportPreview.ps1` antes del import en ese escenario; el preview queda para ronda exploratoria o cuando la importación real aún no fue autorizada; la autorización de import en la sesión no cubre extras, módulos/ExternalObjects de plataforma no pedidos ni `attributesTopLevelUnreconciled` en paquete quirúrgico — **ABORT** y listar el paquete completo al usuario; **`exitCode=48`** (Categoría B: `error :` en el log de export/import/preview) **bloquea** import real en la misma ronda, aun con autorización de import en la sesión; **`exitCode=50`** bloquea por error de parametrización de log (`-LogPath` resuelto como directorio existente), exigiendo una ruta explícita de archivo/log
- **evitar** el anti-patrón export de la KB como “cáscara” de `.xpz`, sustitución manual de nodos y reempaquetado **sin** ese inventario; cuando el XML ya está en la carpeta paralela, preferir `import_file.xml` montado por motor estructurado compartido (`Build-GeneXusImportFileEnvelope.ps1` o la entrada segura `New-XpzImportPackage.ps1`) con `KMW`/`Source` válido y, en paquete mixto/complejo, molde real comparable
- los wrappers compartidos de empaquetado e inventario emiten JSON de máquina por defecto en stdout y no usan `-AsJson`; los wrappers locales antiguos deben actualizarse con la skill `xpz-kb-parallel-setup`. Para camino de entrada, preferir `-InputPath`; para lista nominal `Tipo:Nome`, preferir `-ObjectList`. Los bloqueos esperados devuelven `status`, `exitCode`, `reason`/`stage`, `blockingReasons` y campos accionables como `nextFreeNN`, sin stack/ANSI en el canal de máquina
- al usar `Build-GeneXusImportFileEnvelope.ps1`, informar obligatoriamente `-AcervoPath <ObjetosDaKbEmXml>`; el motor bloquea antes de grabar cuando hay `lastUpdate` inválido contra el acervo u `Object/@type` divergente por el mismo `guid`; los objetos realmente modificados deben declararse con `-ModifiedObjectNames` o `-ModifiedObjectGuids` para que el gate mecánico de `lastUpdate` bloquee timestamps antiguos, iguales al acervo o futuros sin justificación antes de grabar el paquete
- al usar `New-XpzImportPackage.ps1` (entrada segura; el `.py` es motor interno), el gate de drift 9-FD (`Test-GeneXusFrontAcervoDrift.ps1`) se ejecuta siempre antes del empaquetado (fail-closed) y bloquea XMLs en el frente con `lastUpdate` más antiguo que el homólogo en el acervo o con el mismo `guid` y `Object/@type` divergente (`front-object-type-drift`); `-AcervoPath <ObjetosDaKbEmXml>` es opcional y, cuando se omite, el acervo canónico `<RepoRoot>/ObjetosDaKbEmXml` se resuelve automáticamente; sin acervo resoluble el empaquetado queda bloqueado, y el JSON reporta `acervoResolvedBy` (`explicit` o `convention`); acervo ambiguo por GUID genera diagnóstico informativo `front-object-type-drift-ambiguous-acervo`; para drift de `Object/@type`, detenerse para decisión humana en vez de autocopiar/bump; para seed inicial de un objeto aún ausente en el frente, usar `Copy-GeneXusAcervoToFront.ps1` con `-ObjectList`, `-ObjectNames` o `-ObjectGuids` explícito; la carpeta del frente debe ya existir, abierta por `New-GeneXusXpzFront.ps1` (wrapper `New-*KbFront.ps1`, `-ReuseIfExists` para retomar), nunca creada manualmente — `Copy-GeneXusAcervoToFront.ps1` y los gates 9-* solo pueblan o inspeccionan un frente existente
- `-TemplatePackagePath` en `Build-GeneXusImportFileEnvelope.ps1` y en la entrada segura `New-XpzImportPackage.ps1` acepta tanto `.import_file.xml`/XML como `.xpz` real comparable; cuando el template trae `Attributes` de tope y el frente no trae raíces `Attribute` explícitas, el motor preserva esos `Attributes`
- para `Panel`, especialmente Panel SD, tratar `level id` + `layout id` como par acoplado; no generarlos como GUIDs independientes; cuando la regla de derivación no esté probada, preservar el par a partir de un Panel SD exportado por la IDE de la misma KB
- en Panel SD con actions, confrontar `onClickEvent="'Nombre'"` con los eventos serializados en `detail/@events`; preferir `Event 'Nombre'` de un molde real comparable y no sintetizar `Event <Control>.Tap` sin evidencia local equivalente, ajustando siempre el nombre del control al corpus local
- para diagnostico compacto de Panel y WebPanel, preferir `scripts/Get-GeneXusObjectSummary.ps1` (con bloque `webpanel` para WebPanel clasico) y, para Panel, `scripts/Compare-GeneXusPanelShape.ps1`, antes de volcar XML/CDATA completo; para agregar un boton a WebPanel, preferir `scripts/Add-GeneXusButton.ps1` (insercion quirurgica antes o tras un control hoja via `-BeforeControlName`/`-AfterControlName`, fail-closed en tabla Responsive con breakpoints)
- en el gate de envelope, un par `level id` + `layout id` de Panel solo deja de generar salvedad cuando `-PanelReferencePath` comprueba el mismo par en un paquete u objeto comparable informado explícitamente
- los wrappers `Test-GeneXusXpzImportPreview.ps1` e `Invoke-GeneXusXpzImport.ps1` emiten `msbuild.import.signals.json` junto a los logs en bruto (vía `Read-MsBuildImportSignals.ps1`) y también espejan esas señales en `compactSignals` dentro del diagnóstico JSON para lectura compacta de ítems importados, warnings, errores y versión/Environment activos sin volcar el stdout completo
- en los diagnósticos JSON de los wrappers MSBuild de preview/import/export, el código bruto de la task MSBuild queda canónicamente en `executionEvidence.msBuildExitCode`; `exitCode` es el valor clasificado por el wrapper; `msBuildExitCode` top-level, cuando exista, es solo compatibilidad transitoria — ver `02-regras-operacionais-e-runtime.md` y `10-base-operacional-msbuild-headless.md`
- distinguir **Categoría A** (extras de inventario, módulos/ExternalObjects de plataforma, `attributesTopLevelUnreconciled` — el wrapper puede mantener `exitCode=0`; **ABORT** del agente vía Decisión pos-gates para extras) de **Categoría B** (líneas `error :` en el log MSBuild, `invalidTypesRejected`, `exportErrors`/`importErrors`/`previewErrors`/`buildErrors`/`specifyErrors` — con `executionEvidence.msBuildExitCode=0` pero B poblada, el wrapper rebaja a **`exitCode=48`** y `msBuildCategoryBBlocked=true`; artefacto en disco no autoriza entrega operacional limpia); catálogo numérico en `scripts/msbuild-exit-codes.catalog.json`; detalle en `10-base-operacional-msbuild-headless.md` y `xpz-msbuild-import-export/SKILL.md` (sección «Categorías A y B»)
- cuando `exitCode=46` represente bloqueo preventivo de `MSBuild` concurrente en la misma KB, la ronda debe parar e informar el conflicto; la ruta compartida no encola, no espera automáticamente y no reintenta en loop
- en `Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1` y en preview/export/import MSBuild largos (`Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1`), usar watcher como flujo estándar; contrato en `scripts/GeneXusMsBuildWatcherSupport.ps1`; para `Invoke-GeneXusKbBuildAll.ps1`/`Invoke-GeneXusKbSpecifyGenerate.ps1`, el monitoreo legible puede alternativamente ser el **modo desacoplado opt-in** (`Start-GeneXusKbBuildDetached.ps1`: build largo bajo Tarea Programada fuera de la sesión del agente + archivo-centinela), donde `watcherContext.watcherLaunched=false` es elección deliberada, no ausencia a justificar — la ventana visible permanece como default y el desacoplado es decisión consciente del usuario bajo consejo del agente; al esperar la conclusión, combinar centinela + heartbeat de la Tarea Programada (helper `Wait-GeneXusKbBuildDetached.ps1`), nunca solo el centinela, y el modo no sobrevive a logoff/reboot; **fuera** de la **Decisión pos-gates**, ejecución sin watcher visible exige justificación operativa explícita y registro por `watcherContext.watcherLaunched=false`; en importación real de paquete amplio o con muchos `WorkWithForWeb` **fuera** de ese camino, la ausencia de watcher también exige justificación; **dentro** de la Decisión pos-gates, `-StartWatcher` y `-MonitorLogPath` son obligatorios en la misma invocación de `Invoke-GeneXusXpzImport.ps1` (sin excepción por justificación de ausencia)
- **no** iniciar exportación headless de la KB cuando lo pedido fue **solo** importar cambios ya existentes en la carpeta paralela, salvo pedido o confirmación explícita de que el export es indispensable
- antes de una importación real vía MSBuild, la skill `xpz-kb-parallel-setup` ejecuta una verificación consultiva de **capacidad de importación headless** (presencia de `Test-GeneXusImportFileEnvelope.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzImport.ps1` y `GeneXusMsBuildWatcherSupport.ps1` en el motor compartido y coherencia documental mínima de `xpz-msbuild-import-export` en cuanto a la aceptación de `.import_file.xml` como insumo y a `ImportKbInformation` tri-state); una capacidad desfasada debe bloquear la importación real y encaminar a `xpz-msbuild-import-export`, no reinterpretar el contrato localmente

### Carga inicial

- cuando el usuario no informe nombres alternativos, la KB debe asumir estas subcarpetas estándar:
  - `scripts`
  - `Temp`
  - `XpzExportadosPelaIDE`
  - `ObjetosDaKbEmXml`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- `XpzExportadosPelaIDE` es la carpeta de entrada donde el usuario de GeneXus graba los `.xpz` que serán procesados
- después de procesado con éxito por el flujo oficial, el `.xpz` puede renombrarse a `processado_<nome-original>.xpz`
- `scripts` concentra los wrappers `.ps1` que tratan `XPZ` e índice derivado
- cuando la carpeta paralela de la KB se inicialice desde cero para operar con el flujo oficial de materialización XPZ/XML, el bootstrap técnico mínimo debe incluir los wrappers locales principales en `scripts`
- no declarar `setup inicial concluido` mientras esa capa mínima de wrappers locales todavía no exista; en ese caso, el estado correcto es `estructura parcial` o `bootstrap incompleto`
- `Test-*KbSourceSanity.ps1` se recomienda cuando la carpeta también adopte flujo local de generación y empaquetado; su ausencia aislada no impide por sí sola clasificar la capa mínima de wrappers del flujo oficial de materialización o de `KbIntelligence`
- `KbIntelligence` guarda el SQLite derivado y los informes de validación del índice, cuando ese flujo esté adoptado en la KB
- la Carga Inicial puede usar un `XPZ` completo nuevo en cualquier momento para reactualizar `ObjetosDaKbEmXml`
- `XPZ` full define el insumo exportado; la materialización normal de ese insumo no implica `-FullSnapshot`, que debe quedar restringido a la verificación full explícita o a exigencia documental nominal
- bajo `-FullSnapshot`, el sync reconcilia el acervo por `guid` (identidad estable del nodo raíz): un rename (mismo `guid`, nombre distinto) se trata como rename del archivo en el acervo (`Move-Item`), no como borrar-antiguo + crear-nuevo; cubre `Attribute` y `Object`, y el git detecta rename por similitud
- la misma estructura también vale para `XPZ` parciales con objetos alterados desde la última actualización
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` guarda objetos temporales destinados a la importación manual en la IDE
- cada frente activa en `ObjetosGeradosParaImportacaoNaKbNoGenexus` debe tener su propia subcarpeta `NomeCurto_GUID_YYYYMMDD`
- esa subcarpeta de la frente es la unidad activa de la frente de trabajo
- al retomar una frente existente, reutilizar la misma subcarpeta de la frente en vez de crear otra
- Un XML de referencia, ejemplo o template no debe guardarse en la frente activa en `ObjetosGeradosParaImportacaoNaKbNoGenexus`; si aparece allí, el empaquetado debe bloquear en vez de intentar clasificar o importar ese archivo
- `PacotesGeradosParaImportacaoNaKbNoGenexus` guarda el paquete `.xml` y, cuando sea necesario, también `.xpz`, que será importado por la IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus` debe permanecer plano, sin subcarpetas por frente; el vínculo con la frente queda solo en el prefijo `NomeCurto_GUID_YYYYMMDD` sumado a `nn`
- por defecto, `ObjetosGeradosParaImportacaoNaKbNoGenexus` y `PacotesGeradosParaImportacaoNaKbNoGenexus` no necesitan versionarse en Git; si hay duda sobre rastrear o ignorar su contenido, eso debe tratarse como decisión de política del repositorio
- `AGENTS.md` y `README.md` pueden existir en la raíz o en subcarpetas cuando haya anotación operativa pertinente
- si alguna de esas subcarpetas todavía no existe, el orden recomendado de creación es:
  1. `scripts`
  2. `Temp`
  3. `XpzExportadosPelaIDE`
  4. `ObjetosDaKbEmXml`
  5. `KbIntelligence`
  6. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  7. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- cuando la carpeta paralela ya esté versionada en Git y el setup inicial parta de estructura vacía, `.gitignore` en la raíz y `.gitkeep` en las subcarpetas vacías forman parte del bootstrap esperado
- cuando la carpeta paralela todavía no esté versionada en Git, el agente puede ofrecer inicializar versionado Git local como paso opcional; no debe ejecutar `git init` sin aprobación explícita del usuario
- si el usuario acepta versionado Git local y Git no está funcional en el entorno, el agente puede ofrecer instalarlo u orientar la instalación antes del bootstrap Git
- cambiar `.gitignore`, la política de versionado o el alcance de archivos rastreados para viabilizar `git add`/`commit` es una decisión de política del repositorio; el agente puede diagnosticar y proponer opciones, pero no debe cambiar esa política automáticamente solo para cerrar la frente
- cuando `XpzExportadosPelaIDE` todavía no exista, el agente debe preguntar dónde el usuario pretende guardar los `.xpz` antes de continuar con el procesamiento
- en el setup inicial de la carpeta paralela de la KB, si el camino de la carpeta nativa de la KB no viene informado, el agente debe pedir ese camino al usuario antes de concluir el setup
- en el setup inicial de la carpeta paralela de la KB, `kb-source-metadata.md` debe nacer en formato compatible con el motor compartido y preservar el campo nominal `last_xpz_materialization_run_at`
- en el setup inicial de la carpeta paralela de la KB, cuando la carpeta nativa de la KB este confirmada, la identidad estable debe reconciliarse desde la KB nativa local mediante `scripts/Resolve-GeneXusKbIdentity.ps1`; los campos ausentes en `kb-source-metadata.md` pueden ser completados por `scripts/Update-XpzKbSourceMetadataIdentity.ps1` en una frente aprobada, preservando los demas metadatos
- tratar `kb-source-metadata.md` por autoridad de campo: la identidad estable de la KB pertenece al setup/resolutor de la KB nativa local, `KMW` viene de un XPZ real o plantilla comparable, los metadatos de materializacion pertenecen a `xpz-sync`, y `last_setup_audit_run_at`/`setup_contract_signature_*` pertenecen al setup/auditoria (`xpz-kb-parallel-setup`)
- tratar los campos de environment/deploy/output (`deployment_environment_name`, `deployment_hosting_kind`, `kb_environment_count`, `kb_environment_names`, `kb_environment_output_dirs`, `kb_environment_web_dirs`, `kb_environment_post_build_event_hashes`; para env Java/Tomcat, `kb_environment_servlet_dirs`/`kb_environment_app_package`/`kb_environment_servlet_flavor` — AUDIT_REQUIRED) como autoridad del setup/auditoria (`xpz-kb-parallel-setup`): los nombres vienen de una lista declarada por el usuario en `-KbEnvironmentNames`, los directorios de output vienen de `-KbEnvironmentOutputDirs` y la validacion MSBuild (`SetActiveEnvironment`) es obligatoria, sin scan de carpetas de la KB nativa; `metadata/deploy` distinto de `OK` bloquea el estado limpio hasta la reconciliacion. Para Java/Tomcat, `Resolve-XpzJavaTomcatMetadataSuggestion.ps1` es solo un asistente read-only: lee `model.ini`/`gradle.properties`, valida topologia/sentinelas/paquete y exige confirmacion explicita antes de cualquier grabacion por `Set-*KbSourceMetadataDeployment.ps1`. En validacion post-import, `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` deben usar `-ParallelKbRoot`/`-KbMetadataPath` y, cuando aplique, `-PostImportDeployValidation` para verificar publicacion en el `web\bin` resuelto por `kb_environment_web_dirs` por DLL de objeto o `*.config`; `GxNetCoreStartup.dll` solo no prueba deploy actualizado; los eventos post-build conocidos por environment quedan en `kb_environment_post_build_event_hashes` (registro vía `Register-GeneXusKbPostBuildEvents.ps1` tras confirmación), y el build no degrada el estado por eventos registrados — uno no registrado degrada por cautela, sin registro un reproductor de sonido se reconoce como benigno; este campo es autoría de `Register-GeneXusKbPostBuildEvents.ps1` (bajo `xpz-kb-parallel-setup`) y **no** integra el conjunto de campos de deploy validado por la auditoría de metadata (`Test-XpzKbMetadataWrapper.ps1`); `deployment_hosting_kind` se valida contra el registro-fuente-única `GeneXusKbHostingKindSupport.ps1` (`dotnet-core-self-host`, `dotnet-framework-iis`, `java-tomcat`) con soporte **por eje** (Fase 3) — para `java-tomcat`, el **Eje A (deploy-bin) ejecuta el co-gate Java** por familia (publicación atestiguada en el `WEB-INF\classes` externo; `fresh`/`stale`/`no-evidence`/`unexpected-publication`/`unknown`); solo el diagnóstico de `.cs` generado (Eje B) y el runtime-freshness (Eje C) se saltan con `skipped-hosting-unsupported`/`exit 0` (Post-v1; **skip ≠ deploy validado**)
- despues de una auditoria de setup exitosa con `GATE_OK`, grabar `last_setup_audit_run_at` y `setup_contract_signature_*` en la misma sesion via `scripts/Set-XpzSetupAuditTimestamp.ps1` (wrapper local `Set-*KbSetupAuditTimestamp.ps1`) cuando `Test-*KbSetupFreshness.ps1` haya exigido auditoria completa por campo ausente, firma ausente o firma desfasada; posponer solo con rechazo o aplazamiento explicito del usuario
- despues de la auditoria minima de la carpeta paralela (`xpz-kb-parallel-setup`), el agente debe armar un **plan consolidado de correcciones** con todo lo que la skill clasifique como corregible en la carpeta, ofrecer ejecucion en la misma sesion tras aprobacion cuando se exija, y no cerrar solo con diagnostico cuando haya al menos un item corregible; `GATE_OK` libera la tarea del usuario pero no dispensa el plan
- cuando el sync XPZ/XML actualice `kb-source-metadata.md` con `-KbMetadataPath`, el motor `scripts/Sync-GeneXusXpzToXml.ps1` (via `scripts/XpzKbSourceMetadataEditSupport.ps1`) hace actualizacion **quirurgica** de los campos de materializacion, preservando `last_setup_audit_run_at`, `setup_contract_signature_*`, el resto del frontmatter fuera de alcance y el EOL dominante (`scripts/XpzTextFileEolSupport.ps1`)
- `Source` vacio o incompleto en un XPZ puede ser metadata incompleta de la propia KB; `Source/@kb` completado con GUID de otra KB indica paquete cross-KB y bloquea la importacion headless por agente, encaminando a evaluacion/importacion manual por la IDE
- cuando `ObjetosDaKbEmXml` todavía no exista, el agente debe tratar esto como KB aún no materializada y detenerse antes de asumir cualquier snapshot
- al concluir el setup inicial de la carpeta paralela de la KB, el agente debe dejar explícito que la estructura está lista, pero `ObjetosDaKbEmXml` todavía no fue materializada
- al concluir el setup inicial, el agente debe ofrecer `A)` exportación del `.xpz` full por la IDE hacia `XpzExportadosPelaIDE` o `B)` generación del `.xpz` full a partir de la carpeta nativa de la KB por la trilha `MSBuild`, seguida de materialización de los XMLs
- en el cierre del setup inicial, `A)` debe presentarse como camino preferencial y normalmente más rápido; `B)` debe presentarse como camino posible, pero más lento por depender de la trilha via `MSBuild`

### Automación operativa

- el script `scripts/Sync-GeneXusXpzToXml.ps1` forma parte de la infraestructura operativa de esta base y no debe ser removido del repositorio público
- ese script puede ser usado por proyectos de producción que mantengan acervos versionados de XML extraídos de `XPZ`
- ese script emite el resultado como **línea JSON de máquina en stdout** (`Kind=xpz-sync-result`, `SchemaVersion=1`; texto humano en stderr) con listas nominales de los objetos materializados (`CreatedNames`/`UpdatedNames`/`UnchangedNames`/...); el reporte completo sigue disponible vía `-ReportPath`. Los consumidores que leían la salida textual anterior deben pasar a leer el JSON (cambio de contrato registrado en el `CHANGELOG`)
- la carpeta `scripts/` existe como apoyo operativo, analítico y editorial compartible, pero no es fuente normativa de la documentación consolidada de la raíz
- la carpeta `scripts-maintenance/` concentra herramientas de mantenimiento de esta base, como campañas empíricas para actualizar catálogos y documentación; esos scripts no son runtime público de las skills en carpetas paralelas de KB
- los scripts públicos de esta raíz deben operar por parámetros explícitos de entrada y salida, sin depender de rutas absolutas privadas
- los scripts públicos de esta raíz tienen contrato de runtime en `pwsh` con PowerShell 7.4 LTS o superior; usar la versión LTS más reciente disponible es preferible; Windows PowerShell 5.1 (`powershell.exe`) no es runtime soportado para esos scripts
- los puntos de entrada públicos en `scripts/*.ps1` deben declarar `#requires -Version 7.4`; la excepción es `Test-XpzPowerShellRuntime.ps1`, que debe seguir ejecutándose en Windows PowerShell 5.1 para localizar `pwsh` y emitir un bloqueo claro
- la validación automática de parse PowerShell de la base es `scripts/Test-PsScriptsParse.ps1`, también ejecutada por el workflow `.github/workflows/parse-ps-scripts.yml`; verifica `scripts/*.ps1`, `scripts-maintenance/*.ps1` y `.example.ps1` de las skills fuera de `historico/` bajo el contrato `pwsh` 7.4+
- la skill `xpz-kb-parallel-setup` debe crear/validar un wrapper local `Test-*KbPowerShellRuntime.ps1`; ese wrapper debe bloquear cualquier uso operativo de la carpeta paralela cuando falte `pwsh` 7.4 LTS o superior
- la auditoría compartida `Test-XpzSetupAudit.ps1` detecta autónomamente `scripts/Test-*KbPowerShellRuntime.ps1` cuando no se informa la ruta; si falta el wrapper, emite la ruta sugerida y el molde canónico, sin crear el archivo automáticamente
- los `.example.ps1` publicados en las skills funcionan como ejemplos metodológicos importantes para bootstrap técnico y reconstrucción asistida de wrappers locales finales
- esos `.example.ps1` no sustituyen el wrapper local real de la carpeta paralela de la KB y no deben convertirse en fallback automático de ejecución en el flujo normal
- cuando la sesión ya publique la ruta de una skill o de sus ejemplos, esa ruta publicada prevalece sobre cualquier heurística local de instalación
- la memoria operativa de setup y compatibilidad debe permanecer primero en la propia carpeta paralela de la KB, en `AGENTS.md`, `README.md` y archivos operativos locales; la memoria externa del agente fuera del repositorio no debe tratarse como requisito ni escribirse sin autorización explícita del usuario
- si el motor necesita evolucionar, el cambio debe preservar compatibilidad con ese uso o venir acompañado de actualización explícita de los wrappers consumidores

---

## English

This repository contains consolidated documentation about structural analysis of GeneXus objects based on XML extracted from `XPZ`, with emphasis on skills for agents dedicated to the `XPZ`/XML ecosystem of GeneXus, especially `xpz-reader`, `xpz-builder`, `xpz-sync`, `xpz-doc-builder`, `xpz-daemon`, `xpz-kb-parallel-setup`, `xpz-kb-parallel-pre-push`, `xpz-msbuild-import-export`, `xpz-msbuild-build`, `xpz-index-triage`, `xpz-llm-delegate`, `xpz-skills-setup`, and `xpz-codex-apply-patch-alternative`.

- reading and interpreting XML structure
- structural object families
- risk by object type
- conservative cloning
- support for assisted `XPZ` generation
- documented envelope and import validation in controlled cases

### What you will find here

The files below form the main shared base in this root, consolidated to make reading, maintenance, and controlled use easier.

In addition to that main base, the root may also contain complementary operational documentation for active workstreams when it still needs to remain visible outside `historico/`.

- `00-indice-da-base-genexus-xpz-xml.md`
- `01-base-empirica-geral.md`
- `01a-catalogo-e-padroes-empiricos.md` onward (children of the `01` series)
- `02-regras-operacionais-e-runtime.md`
- `03-risco-e-decisao-por-tipo.md`
- `04-webpanel-familias-e-templates.md`
- `04b-ucw-gxcontroltype-reference.md`: catalog of User Controls (`gxControlType`) in `GxMultiForm`, upload-by-context table, UC event rules, and SDT `FileUploadData`
- `05-transaction-familias-e-templates.md`
- `05b-procedure-relatorio-familias-e-templates.md`
- `06-padroes-de-objeto-e-nomenclatura.md`
- `07-open-points-e-checklist.md`
- `08-guia-para-agente-gpt.md`
- `09-inventario-e-rastreabilidade-publica.md`
- `10-base-operacional-msbuild-headless.md`: operational base for the headless MSBuild trail, used by the `xpz-msbuild-import-export` and `xpz-msbuild-build` skills
- `10a-gx-export-task-labels.md`: mismatches between Export task labels (`-ObjectList`) and the internal catalog / KbIntelligence; complements `10-base` for selective export (`exportTaskLabel`)

The files `10-matriz-part-types-por-tipo.md`, `11-campos-estaveis-vs-variaveis.md`, and `12-diffs-estruturais-por-tipo.md` are backward-compatibility stubs: each one redirects to its equivalent in the `01` series (`01b`, `01c`, `01d`). They contain no content of their own and must not be used as a direct source.

### Public Governance Documents

- `CHANGELOG.md`: record of relevant changes from the changelog adoption onward.
- `CONTRIBUTING.md`: guide for contributions, pre-push review, and care with real data.
- `SECURITY.md`: policy for private reporting of vulnerabilities, leaks, and sensitive operational risks.
- `CODE_OF_CONDUCT.md`: code of conduct for project-related interactions.

### KB Intelligence operational documentation

Operational and methodological guide for the KB Intelligence workstream. Closed phase contracts and historical records are in `historico/kb-intelligence/`.

- `kb-intelligence-guia-metodologico-agente.md`: functional investigation roteiro, operational checklist, sanitized examples and response model for agents
- `scripts/README-kb-intelligence.md`: script operational guide, query commands, freshness gates and validation batteries

### Skills for agents

- `xpz-reader`: support for reading and structural interpretation of `XPZ` and related XMLs
- `xpz-builder`: support for controlled materialization of `XPZ` artifacts and envelopes
- `xpz-sync`: orchestration of synchronization and verification of the XML archive from explicit parameters and scripts in `scripts/`
- `xpz-daemon`: installation and management of a persistent monitor that watches XPZ folders and automatically triggers synchronization when new files are detected
- `xpz-doc-builder`: generation and recomposition of Markdown documentation from the XML archive and sanitized templates
- `xpz-kb-parallel-setup`: preparation and validation of the initial KB parallel-folder structure
- `xpz-kb-parallel-pre-push`: pre-push validation of a KB parallel-folder state before pushing that KB (orchestrator of mechanical gates G0–G5 + K1–K4/K8/K9/K11); distinct from the skills-repository pre-push routine (document 13)
- `xpz-msbuild-import-export`: experimental skill for `XPZ` import and export via `MSBuild`, with headless execution, explicit parameters, traceability, and safety gates
- `xpz-msbuild-build`: skill for post-import build validation via `MSBuild`, with headless execution, result classification, and reorg blocked by default
- `xpz-index-triage`: initial triage through a derived index to guide the minimum reading of the KB official XMLs
- `xpz-llm-delegate`: delegation of smaller tasks or second opinion to a secondary LLM via opencode (models in `provider/model` format, including known cloud providers such as `ollama-cloud/*` and `opencode-go/*`), Codex (`codex exec`), Claude Code (`claude -p`, Opus 4.8), GitHub Copilot CLI (`copilot -p`), or Gemini CLI (`gemini -p`), with deterministic local/external classification and per-KB confidentiality gate (destination key, never the adapter); always human-triggered (includes running multi-model peer review, see `15-revisao-por-pares.md`)
- `xpz-skills-setup`: auditing and maintaining the global registration of XPZ skills in the installed agent tools on the machine; includes bootstrapping a folder downloaded as a ZIP from GitHub — installing Git when missing and linking it to the official repository; it also validates and registers the managed external skill `nexa`, cloning its official repository (`genexuslabs/genexus-skills`) when missing
- `xpz-codex-apply-patch-alternative`: auditable PowerShell backup for applying approved textual Git patches in Codex when the native `apply_patch` route is unavailable, fails before any local write, or is explicitly requested; global registration remains a later task

### Recommended reading for humans

If you want to understand the repository quickly:

1. start with `00-indice-da-base-genexus-xpz-xml.md`
2. continue with `01-base-empirica-geral.md` and then open the most relevant child in the `01` series (`01a` through `01h`, empirical children)
3. then read `02-regras-operacionais-e-runtime.md`
4. next read `03-risco-e-decisao-por-tipo.md`
5. for practical cases, use `04-webpanel-familias-e-templates.md`, `05-transaction-familias-e-templates.md`, and `05b-procedure-relatorio-familias-e-templates.md`
6. if you want limits and next investigation fronts, read `07-open-points-e-checklist.md`
7. for another GPT agent consuming the base, finish with `08-guia-para-agente-gpt.md`
8. to verify inventory traceability, consult `09-inventario-e-rastreabilidade-publica.md`

`06-padroes-de-objeto-e-nomenclatura.md`: supplemental reading — recommended when the question involves object naming, type prefixes, or `Folder` vs `Module` behavior in `fullyQualifiedName`.

### Important notes

- this base prioritizes structural evidence observed in XML
- it does not guarantee successful import or build without external validation
- the base already includes documented import tests in controlled cases, but that still does not remove risk
- before generating `import_file.xml` or another importable package, the trail must explicitly separate `well-formed XML` from `structurally conservative/probably importable GeneXus Source`; XML parsing alone is not enough
- in legacy object review and sanity, the trail must explicitly separate `absolute sanity of the current artifact` from `comparison against the official baseline`; `same as baseline` does not mean `good`, and `worse than baseline` indicates delta regression
- complete sanitized templates can serve as a starting point in specific scenarios documented in the base itself; textual summaries and incomplete examples are not valid as the final source for materialization
- the content is meant to reduce trial and error, not to eliminate risk
- there is a separate private folder, `GeneXus-XPZ-PrivateMap`, used only for private editorial traceability between public aliases and real artifacts; the published source remains this root
- every new sanitized example incorporated into the public base must receive a corresponding note in `GeneXus-XPZ-PrivateMap`, linking the public excerpt to the real source objects or packages
- **language models**: XPZ skills depend on voluntary skill loading, sequential gate execution, and adherence to NEVER constraints. The criterion is **observed instruction adherence**, not the model name or version — dated, non-exhaustive examples, to be adjusted as versions evolve.
  - **Solo model** (driving GeneXus triage/build, or recommended as a user's default): require **strong instruction adherence**; models prone to skipping steps are not reliable in this role. Strong examples (as of 2026-06): DeepSeek V4 Pro, GPT-5.5, Sonnet 4.6, Opus 4.8.
  - **Voice in a peer-review panel** (see `15-revisao-por-pares.md`): **family diversity** is the value; less-strong models are admissible as **additional voices** — never as a **sole decisive** reviewer —, since, by reading the sources, they catch blind spots. Any voice's objection still goes through **human triage** (the `15` rule); the principle prevails over any fixed list.
  - **Hard veto** (do not use even as a voice), for proven low grounding: Mistral Large 3, Nemotron 3 Ultra.
- **unknown XPZ object type**: sync and KbIntelligence index rebuild stay blocked until the GUID is in the effective catalog (base + override); the parallel KB folder may use `scripts/gx-object-type-catalog.override.json` as a local fallback, always audited per session. The audit distinguishes pending, redundant, and divergent entries; equivalent redundancy recommends approved local cleanup instead of a global pending item; see `02`, `08`, and skills `xpz-sync` / `xpz-kb-parallel-setup`.
- **legacy GeneXus 9 export element**: a GeneXus 9 `ExportFile` carries `<GXObject><Element>` by **name**, with no type GUID — it stays **outside** the modern catalog, in the registry `scripts/gx-legacy-export-element-registry.json` (owner doc `01k`), which classifies each element as `equivalent` (real modern type) or `orphan` (`typeToken` `gxlegacy/<Element>`); the legacy export engine already exists and is integrated into sync/inventory (`Sync-GeneXusXpzToXml.ps1` materializes the legacy branch; `Get-GeneXusImportPackageObjectInventory.ps1` inventories `known-legacy` items), with mixed packages fail-closed.
- **`Transaction` catalogs (rules/events)**: when documenting what the Specifier accepts or rejects, use labels `confirmado-import`, `confirmado-build`, `confirmado-acervo`, `padrao-gx-nao-verificado`, and `nao-listar` per `02` (Transaction catalog evidence policy) and `xpz-builder/responsibilities-by-type/transaction.md`; file-name `.xml` examples refer to parallel folder `ObjetosDaKbEmXml/` or sanitized templates in `01*`, unless stated otherwise.
- **XPZ scope vs GeneXus language**: this base documents rejections and XPZ contracts verified by scripts and skills in this root; correct use of rules, triggers, and GeneXus language belongs to product documentation and dedicated skills (e.g. nexa), not a catalog of every possible misuse of the language.

### Operational Topology

- in this trail, the native GeneXus KB folder is different from the KB parallel folder
- in this trail, the native KB folder must be treated as a write-prohibited area for agents; reading is allowed only when the explicit operational flow truly requires it
- the KB parallel folder is the working folder that concentrates `XPZ` exported by the IDE, XMLs materialized by the official flow, derived index for triage, and artifacts prepared for later import

- `ObjetosDaKbEmXml`: official KB snapshot; read-only for agents
- `KbIntelligence`: folder for the derived and regenerable SQLite index, used for technical and short functional triage without replacing the official snapshot
- `KbIntelligence` should only be used for broad triage when `last_index_build_run_at` in SQLite is equal to or later than `last_xpz_materialization_run_at` in `kb-source-metadata.md`, `inventory_validation_status` is literally `OK` in `index-metadata`, and `extractor_signature_version`/`extractor_signature_hash` in metadata match the engine in `scripts/Build-KbIntelligenceIndex.py` of the active repository (via `scripts/GeneXusKbIntelligenceExtractorContract.ps1` or gate `Test-*KbIndexGate.ps1`); every official XPZ/XML sync must regenerate/validate the index immediately after materialization, and a missing, stale, extractor-signature-mismatched, or semantically blocked index is an operational exception that must block broad search/generation and offer the user an update
- **Python prerequisite**: KbIntelligence index rebuild requires **usable Python 3.x** on `PATH` (`scripts/GeneXusPythonPrerequisite.ps1` via `Build-KbIntelligenceIndex.ps1`); the Microsoft Store stub (`WindowsApps`) does not count; absence blocks refresh with exit `8` and an explicit message — XPZ/XML materialization may already have completed; **strict rule**: official sync **does not** complete without a regenerated index — do not report sync OK; see `xpz-sync` and `08-guia-para-agente-gpt.md`
- **index semantic queries**: before `who-uses`, `what-uses`, `impact-basic`, or `functional-trace-basic`, check the effective catalog (`scripts/gx-object-type-catalog.json` + `scripts/gx-object-type-catalog.override.json` in the parallel folder when present) for `queryableByKbIntelligence=true`; when `false`, `Query-KbIntelligenceIndex` returns exit `11` and `blocked=true` — **do not** treat as zero dependencies; prefer `object-info`, `search-objects`, `list-by-type`, or point XML reads; see `02`, `08`, and `scripts/README-kb-intelligence.md`
- **materialized Transaction writability in the index**: after rebuild with `schema_version>=2`, queries `transaction-attributes` and `transaction-writable-attributes` expose classification stored in `transaction_attribute_writability` (parity with `Test-GeneXusTransactionWritability.ps1` when `Test-GeneXusKbIntelligenceWritabilityParity.ps1` passes on the parallel folder); use for triage only — packaging with `Rules`/`Events` on a `Transaction` or `New` blocks in a `Procedure` still requires gates in `xpz-builder` (`Test-GeneXusTransactionWritability.ps1`, `Test-GeneXusNewWritableTargets.ps1`); see `02`, `08`, and `scripts/README-kb-intelligence.md`
- **CSS class catalog and usage in the index**: starting at `schema_version=3`, the index catalogs CSS classes (table `css_class`, dimensions `model` legacy-theme/design-system and `origin` kb-authored/packaged-module) and tracks where they are used (relations `uses_css_class`/`uses_css_class_dynamic`), via the `css-classes` and `css-class-usage` queries; it tackles the false "does not exist" of the incomplete inventory (`DesignSystem` classes are not objects) and of invisible usage (code assignment `Controle.Class = ...`, not just `class="..."` in the layout); `css-class-usage` declares honest coverage (resolvable uses vs dynamic assignments) and flags the `legacy-theme` model as deprecated; it is a triage accelerator with gate-guaranteed freshness, not exhaustive truth — destructive operations require verification by literal search in the XML; see `02`, `08`, and `scripts/README-kb-intelligence.md`
- **Pattern-generated vs authored objects in the index**: starting at `schema_version=4`, the index materializes in the `objects` table whether an object was generated by a Pattern (WorkWith For Web) — columns `is_generated_object` (0/1), `pattern_object_id`, and `instance_key`, extracted from the object-level `<Properties>` (scoped to the root object, never from a nested `<Object>` in a `PackagedModule`); use the deterministic signal and the `--generated`/`--authored` filter (on `search-objects`/`list-by-type`) instead of name heuristics (`ww*`/`*WC`/`*General`/`*Selection`) when separating authored from generated; `search-objects -InstanceKey <name|<GUID>-<name>>` does reverse lookup by instance (lists the objects generated by a WorkWithForWeb instance; auto-detects name vs full key, exact case-insensitive match) and the derived `instance_name` field is served on `object-info`/`search-objects`/`list-by-type`; see `02`, `08`, and `scripts/README-kb-intelligence.md`
- local `AGENTS.md` and `README.md` files in the parallel folder must not record literal materialization or index timestamps; they must point to `kb-source-metadata.md`, to the local wrapper `-Query index-metadata`, and to the effective gate result. A literal timestamp in those markdown files is documentation drift and a setup pending item; the fix is to replace it with pointers to the authoritative sources, not to update the duplicated value
- `XpzExportadosPelaIDE`: folder where the user stores both the full Initial Load `XPZ` and the day-to-day incremental `XPZ` files
- `ObjetosGeradosParaImportacaoNaKbNoGenexus`: working area for XMLs generated, adjusted, or preserved for manual IDE import
- `PacotesGeradosParaImportacaoNaKbNoGenexus`: output area for `import_file.xml` and other locally generated packages
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` and `PacotesGeradosParaImportacaoNaKbNoGenexus` are agent-managed areas, not general user drop folders; a reference, example, or template XML left in the active front must block packaging until it is removed or handled through an explicit path outside the front
- when creating an altered copy of GeneXus XML in `ObjetosGeradosParaImportacaoNaKbNoGenexus`, the agent must faithfully preserve the source XML outside the approved functional delta: comments, `CDATA`, indentation, blank lines, node order, line breaks, and inherited whitespace must not change through broad reconstruction or reserialization; new or modified lines must not be created with trailing spaces or tabs
- in operational audits of the KB parallel folder, declare `sync/materialization`, `index/gate`, `index/semantics`, and `local packaging` separately; `GATE_OK` and structure OK are not enough, by themselves, to conclude generically that "everything is fine" when the index semantics or the local packaging flow have not yet been audited
- `Temp`: preferred destination for ephemeral execution artifacts, such as wrapper temporary directories, auxiliary logs, and intermediate outputs that are not normative source material for the base
- `ArquivoMorto`: optional subfolder of `ObjetosGeradosParaImportacaoNaKbNoGenexus` used to preserve contaminated XMLs that must not be imported but require traceability; do not delete without explicit user authorization
- in `ObjetosGeradosParaImportacaoNaKbNoGenexus`, each active front must use its own subfolder in the format `NomeCurto_GUID_YYYYMMDD`
- until that front is closed, successive micro-adjustments must reuse the same subfolder; do not create a new subfolder or change `NomeCurto_GUID_YYYYMMDD` for another attempt, visual adjustment, or reimport of the same front
- `NomeCurto_GUID_YYYYMMDD` identifies the front by the combination of short name, GUID generated when the front is opened, and the front creation date
- in `PacotesGeradosParaImportacaoNaKbNoGenexus`, packages must remain in the root, without subfolders, using the format `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- `nn` represents only the short package round for that front; it is not semantic versioning
- during the same front, keep the same `NomeCurto_GUID_YYYYMMDD` prefix across all packages and change only `nn`; choosing another base name for the same front is operational noise, not traceability
- before writing `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, check whether a package with the same front prefix `NomeCurto_GUID_YYYYMMDD` and the same `nn` already exists
- if a package with the same front prefix and the same `nn` already exists, abort the write; do not silently overwrite that round
- when the rule is deterministic, the primary enforcement should live in `.ps1`; for package collision, prefer a dedicated gate such as `Test-XpzPackageCollision.ps1` or an equivalent local wrapper
- on collision, the explicit error and the suggested next free `nn` must come from the gate itself, without auto-incrementing or automatically writing with the suggested value
- promotion into `ObjetosDaKbEmXml` happens only through the official `.ps1` script flow fed by the XPZ exported from the IDE
- `ObjetosDaKbEmXml` must not be updated by manual editing; it is updated by the `.ps1` flow from the XPZ files made available in the KB parallel folder
- if the object has not yet returned from the KB by official export, the work must happen in `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- detected or intended editing in `ObjetosDaKbEmXml` for a delta that has not yet been officially re-exported by the KB must be treated as an explicit process error, not as an operational detail
- `AGENTS.md`, `README.md`, and equivalent KB documentation act as the mandatory local specialization layer; their rules apply to that repository and must not be automatically promoted to the shared XPZ methodology
- a technically validated front does not imply Git publication; publication only occurs with explicit user authorization, and until then the preferred state is `aguardando_decisao_de_fechamento`

### Headless import and package contents

- the `Test-GeneXusImportFileEnvelope.ps1` gate validates the package **envelope** (`ExportFile`, `KMW`, `Source`, etc.); it **does not replace** verifying the full **set of objects** that the import would apply to the KB
- partial export from the IDE or `MSBuild`, even with an explicit object list, may place **additional objects** in the `.xpz` (dependencies, references, organizational modules); **do not** assume package contents match the nominal list without inspecting the artifact
- in selective/surgical `MSBuild` export whose goal is to obtain only the objects listed in `-ObjectList`, pass `-DependencyType "None" -ReferenceType "None"` to prevent drag-in at the source; this does not replace the mandatory post-export inventory, and values beyond `None`/the formal default remain under confirmation in the operational base
- before **real** headless import, the agent must **list every object** in the package and reconcile with the declared delta; unrequested extras in a surgical package require **ABORT** or explicit user confirmation (see skills `xpz-msbuild-import-export` and `xpz-builder`, and `10-base-operacional-msbuild-headless.md`)
- **Post-gates decision** (full contract in `xpz-msbuild-import-export/SKILL.md`): when real import was already authorized in the same session, the envelope is `apto para prosseguir` (`Test-GeneXusImportFileEnvelope.ps1`), and package inventory passed with no extra blocking (skill step 6c), run `Invoke-GeneXusXpzImport.ps1` in the same round with `-StartWatcher` and `-MonitorLogPath` (mandatory on that path); do not stop at an apt envelope alone or require `Test-GeneXusXpzImportPreview.ps1` before real import in that scenario; preview remains for exploratory rounds or when real import is not yet authorized; session import authorization does not cover extras, unrequested platform modules/ExternalObjects, or `attributesTopLevelUnreconciled` in a surgical package — **ABORT** and list the full package to the user; **`exitCode=48`** (Category B: `error :` in export/import/preview log) **blocks** real import in the same round even when session import was authorized; **`exitCode=50`** blocks on log-parameter misuse (`-LogPath` resolved as an existing directory), requiring an explicit log/file path
- **avoid** the anti-pattern of KB export as a `.xpz` "shell", manual node replacement, and repackaging **without** that inventory; when the XML already lives in the parallel folder, prefer `import_file.xml` built by a shared structured engine (`Build-GeneXusImportFileEnvelope.ps1` or the safe entry point `New-XpzImportPackage.ps1`) with valid `KMW`/`Source` and, for mixed/complex packages, a comparable real template
- shared packaging and inventory wrappers emit machine JSON on stdout by default and do not use `-AsJson`; old local wrappers should be updated with the `xpz-kb-parallel-setup` skill. For input paths, prefer `-InputPath`; for nominal `Tipo:Nome` lists, prefer `-ObjectList`. Expected blocks return `status`, `exitCode`, `reason`/`stage`, `blockingReasons`, and actionable fields such as `nextFreeNN`, with no stack/ANSI in the machine channel
- when using `Build-GeneXusImportFileEnvelope.ps1`, `-AcervoPath <ObjetosDaKbEmXml>` is mandatory; the engine blocks before writing when `lastUpdate` is invalid against the acervo or `Object/@type` diverges for the same `guid`; objects actually modified in the round must be declared with `-ModifiedObjectNames` or `-ModifiedObjectGuids` so the mechanical `lastUpdate` gate blocks stale, baseline-equal, or unjustified-future timestamps before writing the package
- when using `New-XpzImportPackage.ps1` (safe entry point; the `.py` is an internal engine), the 9-FD front-acervo drift gate (`Test-GeneXusFrontAcervoDrift.ps1`) always runs before packaging (fail-closed) and blocks XMLs in the front whose `lastUpdate` is older than the matching file in the acervo or whose same `guid` has divergent `Object/@type` (`front-object-type-drift`); `-AcervoPath <ObjetosDaKbEmXml>` is optional and, when omitted, the canonical acervo `<RepoRoot>/ObjetosDaKbEmXml` is auto-resolved; with no acervo resolvable, packaging is blocked, and the JSON reports `acervoResolvedBy` (`explicit` or `convention`); ambiguous acervo by GUID emits informational diagnostic `front-object-type-drift-ambiguous-acervo`; for `Object/@type` drift, stop for human decision instead of auto-copying/bumping; for initial seed of an object still absent from the front, use `Copy-GeneXusAcervoToFront.ps1` with explicit `-ObjectList`, `-ObjectNames`, or `-ObjectGuids`; the front folder must already exist, opened by `New-GeneXusXpzFront.ps1` (wrapper `New-*KbFront.ps1`, `-ReuseIfExists` to resume), never created manually — `Copy-GeneXusAcervoToFront.ps1` and the 9-* gates only populate or inspect an existing front
- `-TemplatePackagePath` in `Build-GeneXusImportFileEnvelope.ps1` and the safe entry point `New-XpzImportPackage.ps1` accepts either `.import_file.xml`/XML or a comparable real `.xpz`; when the template carries top-level `Attributes` and the front does not provide explicit `Attribute` roots, the engine preserves those `Attributes`
- for `Panel`, especially Panel SD, treat `level id` + `layout id` as a coupled pair; do not generate them as independent GUIDs; when the derivation rule is not proven, preserve the pair from a Panel SD exported by the IDE of the same KB
- in Panel SD with actions, compare `onClickEvent="'Name'"` with the events serialized in `detail/@events`; prefer `Event 'Name'` from a comparable real template and do not synthesize `Event <Control>.Tap` without equivalent local evidence, always adjusting the control name to the local corpus
- for compact Panel and WebPanel diagnosis, prefer `scripts/Get-GeneXusObjectSummary.ps1` (with a `webpanel` block for classic WebPanel) and, for Panel, `scripts/Compare-GeneXusPanelShape.ps1`, before dumping full XML/CDATA; to add a button to a WebPanel, prefer `scripts/Add-GeneXusButton.ps1` (surgical insertion before or after a leaf control via `-BeforeControlName`/`-AfterControlName`, fail-closed on a Responsive table with breakpoints)
- in the envelope gate, a Panel `level id` + `layout id` pair stops generating a warning only when `-PanelReferencePath` proves the same pair in an explicitly supplied comparable package or object
- the wrappers `Test-GeneXusXpzImportPreview.ps1` and `Invoke-GeneXusXpzImport.ps1` emit `msbuild.import.signals.json` next to the raw logs (via `Read-MsBuildImportSignals.ps1`) and also mirror those signals in `compactSignals` inside the JSON diagnostic for compact reading of imported items, warnings, errors, and active version/Environment without dumping the full stdout
- in MSBuild preview/import/export wrapper JSON diagnostics, the raw MSBuild task exit code is canonical in `executionEvidence.msBuildExitCode`; `exitCode` is the wrapper-classified value; top-level `msBuildExitCode`, when present, is transitional compatibility only — see `02-regras-operacionais-e-runtime.md` and `10-base-operacional-msbuild-headless.md`
- distinguish **Category A** (inventory extras, platform modules/ExternalObjects, `attributesTopLevelUnreconciled` — wrapper may keep `exitCode=0`; agent **ABORT** via Post-gates decision for extras) from **Category B** (`error :` lines in the MSBuild log, `invalidTypesRejected`, `exportErrors`/`importErrors`/`previewErrors`/`buildErrors`/`specifyErrors` — when `executionEvidence.msBuildExitCode=0` but B is populated, the wrapper downgrades to **`exitCode=48`** and `msBuildCategoryBBlocked=true`; on-disk artifact does not authorize a clean operational handoff); numeric catalog in `scripts/msbuild-exit-codes.catalog.json`; detail in `10-base-operacional-msbuild-headless.md` and `xpz-msbuild-import-export/SKILL.md` (section «Categorias A e B»)
- when `exitCode=46` represents preventive blocking for concurrent `MSBuild` on the same KB, the round must stop and report the conflict; the shared trail does not queue, wait automatically, or retry in a loop
- for `Invoke-GeneXusKbBuildAll.ps1`, `Invoke-GeneXusKbSpecifyGenerate.ps1`, and long MSBuild preview/export/import runs (`Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzExport.ps1`, `Invoke-GeneXusXpzImport.ps1`), use the watcher as the standard flow; contract in `scripts/GeneXusMsBuildWatcherSupport.ps1`; for `Invoke-GeneXusKbBuildAll.ps1`/`Invoke-GeneXusKbSpecifyGenerate.ps1`, readable monitoring may alternatively be the **opt-in detached mode** (`Start-GeneXusKbBuildDetached.ps1`: long build under a Scheduled Task outside the agent session + sentinel file), where `watcherContext.watcherLaunched=false` is a deliberate choice, not an absence to justify — the visible window remains the default and the detached mode is a conscious user decision under the agent's advice; when waiting for completion, combine sentinel + Scheduled Task heartbeat (helper `Wait-GeneXusKbBuildDetached.ps1`), never the sentinel alone, and the mode does not survive logoff/reboot; **outside** the **Post-gates decision**, a run without a visible watcher requires explicit operational justification and recording through `watcherContext.watcherLaunched=false`; for real import of a broad package or many `WorkWithForWeb` **outside** that path, missing watcher also requires justification; **inside** the Post-gates decision, `-StartWatcher` and `-MonitorLogPath` are mandatory in the same `Invoke-GeneXusXpzImport.ps1` invocation (no absence justified by exception)
- **do not** start headless KB export when the user asked **only** to import changes already present in the parallel folder, unless the user explicitly requests export or confirms it is indispensable
- before a real MSBuild import, the `xpz-kb-parallel-setup` skill runs a consultive check of **headless import capability** (presence of `Test-GeneXusImportFileEnvelope.ps1`, `Test-GeneXusXpzImportPreview.ps1`, `Invoke-GeneXusXpzImport.ps1`, and `GeneXusMsBuildWatcherSupport.ps1` in the shared engine, and minimum documentation coherence of `xpz-msbuild-import-export` regarding acceptance of `.import_file.xml` as input and `ImportKbInformation` as tri-state); stale capability must block the real import and route to `xpz-msbuild-import-export`, not reinterpret the contract locally

### Initial load

- when the user does not provide alternative names, the KB must assume these standard subfolders:
  - `scripts`
  - `Temp`
  - `XpzExportadosPelaIDE`
  - `ObjetosDaKbEmXml`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- `XpzExportadosPelaIDE` is the input folder where the GeneXus user stores the `.xpz` files that will be processed
- after being successfully processed by the official flow, the `.xpz` can be renamed to `processado_<nome-original>.xpz`
- `scripts` concentrates the `.ps1` wrappers that handle `XPZ` and the derived index
- when the KB parallel folder is initialized from zero to operate with the official XPZ/XML materialization flow, the minimum technical bootstrap must include the main local wrappers in `scripts`
- do not declare `initial setup complete` while that minimum local wrapper layer does not exist yet; in that case, the correct status is `partial structure` or `incomplete bootstrap`
- `Test-*KbSourceSanity.ps1` is recommended when the folder also adopts a local generation and packaging flow; its isolated absence does not by itself prevent classifying the minimum wrapper layer for the official materialization flow or for `KbIntelligence`
- `KbIntelligence` stores the derived SQLite index and index validation reports when that flow is adopted in the KB
- the Initial Load can use a new full `XPZ` at any time to refresh `ObjetosDaKbEmXml`
- full `XPZ` defines the exported input; normal materialization of that input does not imply `-FullSnapshot`, which must stay restricted to explicit full verification or nominal documentary requirement
- under `-FullSnapshot`, the sync reconciles the store by `guid` (stable root-node identity): a rename (same `guid`, different name) is treated as a file rename in the store (`Move-Item`), not delete-old + create-new; covers `Attribute` and `Object`, and git detects the rename by similarity
- the same structure also applies to partial `XPZ` files with objects changed since the last update
- `ObjetosGeradosParaImportacaoNaKbNoGenexus` stores temporary objects intended for manual IDE import
- each active front in `ObjetosGeradosParaImportacaoNaKbNoGenexus` must have its own `NomeCurto_GUID_YYYYMMDD` subfolder
- that front subfolder is the active unit of the working front
- when resuming an existing front, reuse the same front subfolder instead of creating another one
- Reference, example, or template XML must not be saved in the active front under `ObjetosGeradosParaImportacaoNaKbNoGenexus`; if it appears there, packaging must block instead of trying to classify or import that file
- `PacotesGeradosParaImportacaoNaKbNoGenexus` stores the `.xml` package and, when needed, also `.xpz`, which will be imported by the IDE
- `PacotesGeradosParaImportacaoNaKbNoGenexus` must remain flat, without subfolders by front; the link to the front exists only in the `NomeCurto_GUID_YYYYMMDD` prefix plus `nn`
- by default, `ObjetosGeradosParaImportacaoNaKbNoGenexus` and `PacotesGeradosParaImportacaoNaKbNoGenexus` do not need to be versioned in Git; if there is doubt about tracking or ignoring their contents, treat that as repository policy
- `AGENTS.md` and `README.md` may exist in the root or in subfolders when there is relevant operational annotation
- if any of those subfolders does not exist yet, the recommended creation order is:
  1. `scripts`
  2. `Temp`
  3. `XpzExportadosPelaIDE`
  4. `ObjetosDaKbEmXml`
  5. `KbIntelligence`
  6. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  7. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- when the parallel folder is already versioned in Git and the initial setup starts from an empty structure, `.gitignore` at the root and `.gitkeep` in empty subfolders are part of the expected bootstrap
- when the parallel folder is not yet versioned in Git, the agent may offer to initialize local Git versioning as an optional step; it must not run `git init` without explicit user approval
- if the user accepts local Git versioning and Git is not functional in the environment, the agent may offer to install it or guide the installation before the Git bootstrap
- changing `.gitignore`, versioning policy, or the scope of tracked files just to make `git add`/`commit` work is a repository policy decision; the agent may diagnose and propose options, but must not change that policy automatically just to close the front
- when `XpzExportadosPelaIDE` does not exist yet, the agent must ask where the user intends to save the `.xpz` files before continuing with processing
- in the initial setup of the KB parallel folder, if the native KB folder path is not provided, the agent must ask the user for that path before concluding setup
- in the initial setup of the KB parallel folder, `kb-source-metadata.md` must start in a format compatible with the shared engine and preserve the nominal `last_xpz_materialization_run_at` field
- in the initial setup of the KB parallel folder, when the native KB folder is confirmed, stable identity must be reconciled from the local native KB through `scripts/Resolve-GeneXusKbIdentity.ps1`; missing fields in `kb-source-metadata.md` may be filled by `scripts/Update-XpzKbSourceMetadataIdentity.ps1` in an approved front, preserving the remaining metadata
- treat `kb-source-metadata.md` by field authority: stable KB identity belongs to setup/the local native KB resolver, `KMW` comes from a real XPZ or comparable template, materialization metadata belongs to `xpz-sync`, and `last_setup_audit_run_at`/`setup_contract_signature_*` belong to setup/audit (`xpz-kb-parallel-setup`)
- treat the environment/deploy/output fields (`deployment_environment_name`, `deployment_hosting_kind`, `kb_environment_count`, `kb_environment_names`, `kb_environment_output_dirs`, `kb_environment_web_dirs`, `kb_environment_post_build_event_hashes`; for a Java/Tomcat env, `kb_environment_servlet_dirs`/`kb_environment_app_package`/`kb_environment_servlet_flavor` — AUDIT_REQUIRED) as setup/audit authority (`xpz-kb-parallel-setup`): names come from a user-declared `-KbEnvironmentNames` list, output directories come from `-KbEnvironmentOutputDirs`, and MSBuild (`SetActiveEnvironment`) validation is mandatory, without scanning native KB folders; `metadata/deploy` different from `OK` blocks a clean state until reconciliation. For Java/Tomcat, `Resolve-XpzJavaTomcatMetadataSuggestion.ps1` is only a read-only assistant: it reads `model.ini`/`gradle.properties`, validates topology/sentinels/package, and requires explicit confirmation before any write through `Set-*KbSourceMetadataDeployment.ps1`. In post-import validation, `Invoke-GeneXusKbBuildAll.ps1` and `Invoke-GeneXusKbSpecifyGenerate.ps1` must use `-ParallelKbRoot`/`-KbMetadataPath` and, when applicable, `-PostImportDeployValidation` to check publication in the `web\bin` resolved by `kb_environment_web_dirs` by object DLL or `*.config`; `GxNetCoreStartup.dll` alone does not prove an updated deploy; known post-build events per environment live in `kb_environment_post_build_event_hashes` (registered via `Register-GeneXusKbPostBuildEvents.ps1` after confirmation), and the build does not downgrade the status for registered events — an unregistered one downgrades out of caution, and with no registry a sound player is recognized as benign; this field is authored by `Register-GeneXusKbPostBuildEvents.ps1` (under `xpz-kb-parallel-setup`) and is **not** part of the deploy field set validated by the metadata audit (`Test-XpzKbMetadataWrapper.ps1`); `deployment_hosting_kind` is validated against the single-source registry `GeneXusKbHostingKindSupport.ps1` (`dotnet-core-self-host`, `dotnet-framework-iis`, `java-tomcat`) with **per-axis** support (Phase 3) — for `java-tomcat`, **Axis A (deploy-bin) runs the per-family Java co-gate** (attested publication in the external `WEB-INF\classes`; `fresh`/`stale`/`no-evidence`/`unexpected-publication`/`unknown`); only the generated-`.cs` diagnostic (Axis B) and runtime-freshness (Axis C) skip with `skipped-hosting-unsupported`/`exit 0` (Post-v1; **skip ≠ validated deploy**)
- after a successful setup audit with `GATE_OK`, write `last_setup_audit_run_at` and `setup_contract_signature_*` in the same session via `scripts/Set-XpzSetupAuditTimestamp.ps1` (local wrapper `Set-*KbSetupAuditTimestamp.ps1`) when `Test-*KbSetupFreshness.ps1` required a full audit for a missing field, missing signature, or stale signature; defer only with explicit user refusal or postponement
- after a minimal parallel-folder audit (`xpz-kb-parallel-setup`), the agent must present a **consolidated correction plan** for everything the skill classifies as fixable in the folder, offer execution in the same session after approval when required, and must not close with diagnosis only when there is at least one fixable item; `GATE_OK` releases the user's task but does not replace the plan
- when XPZ/XML sync updates `kb-source-metadata.md` with `-KbMetadataPath`, the engine `scripts/Sync-GeneXusXpzToXml.ps1` (via `scripts/XpzKbSourceMetadataEditSupport.ps1`) performs a **surgical** update of materialization fields, preserving `last_setup_audit_run_at`, `setup_contract_signature_*`, other out-of-scope frontmatter, and dominant EOL (`scripts/XpzTextFileEolSupport.ps1`)
- empty or incomplete `Source` in an XPZ may be incomplete metadata from the KB itself; `Source/@kb` filled with another KB's GUID indicates a cross-KB package and blocks agent-driven headless import, routing the case to manual IDE evaluation/import
- when `ObjetosDaKbEmXml` does not exist yet, the agent must treat this as a KB not yet materialized and stop before assuming any snapshot
- when concluding the initial setup of the KB parallel folder, the agent must make it explicit that the structure is ready, but `ObjetosDaKbEmXml` has not yet been materialized
- when concluding the initial setup, the agent must offer `A)` full `.xpz` export by the IDE into `XpzExportadosPelaIDE` or `B)` full `.xpz` generation from the native KB folder through the `MSBuild` track, followed by XML materialization
- in the initial setup closeout, `A)` must be presented as the preferred and usually faster path; `B)` must be presented as a possible but slower path because it depends on the `MSBuild` track

### Operational automation

- the script `scripts/Sync-GeneXusXpzToXml.ps1` is part of the operational infrastructure of this base and must not be removed from the public repository
- that script can be used by production projects that keep versioned XML archives extracted from `XPZ`
- that script emits its result as a **single machine-JSON line on stdout** (`Kind=xpz-sync-result`, `SchemaVersion=1`; human text on stderr) with nominal lists of the materialized objects (`CreatedNames`/`UpdatedNames`/`UnchangedNames`/...); the full report is still available via `-ReportPath`. Consumers that read the previous textual output must switch to reading the JSON (contract change recorded in the `CHANGELOG`)
- the `scripts/` folder exists as shared operational, analytical, and editorial support, but it is not the normative source of the consolidated root documentation
- the `scripts-maintenance/` folder holds maintenance tools for this base, such as empirical campaigns for updating catalogs and documentation; these scripts are not public skill runtime for parallel KB folders
- the public scripts in this root must operate through explicit input and output parameters, without depending on private absolute paths
- the public scripts in this root have a runtime contract of `pwsh` with PowerShell 7.4 LTS or newer; using the latest available LTS version is preferred; Windows PowerShell 5.1 (`powershell.exe`) is not a supported runtime for these scripts
- public entry points in `scripts/*.ps1` must declare `#requires -Version 7.4`; the exception is `Test-XpzPowerShellRuntime.ps1`, which must remain executable in Windows PowerShell 5.1 to locate `pwsh` and emit a clear block
- the base's automatic PowerShell parse validation is `scripts/Test-PsScriptsParse.ps1`, also run by the `.github/workflows/parse-ps-scripts.yml` workflow; it checks `scripts/*.ps1`, `scripts-maintenance/*.ps1` and skill `.example.ps1` files outside `historico/` under the `pwsh` 7.4+ contract
- the `xpz-kb-parallel-setup` skill must create/validate a local `Test-*KbPowerShellRuntime.ps1` wrapper; that wrapper must block any operational use of the parallel folder when `pwsh` 7.4 LTS or newer is missing
- the shared `Test-XpzSetupAudit.ps1` audit detects `scripts/Test-*KbPowerShellRuntime.ps1` autonomously when no path is provided; if the wrapper is missing, it emits the suggested path and canonical template without creating the file automatically
- the `.example.ps1` files published inside the skills act as important methodological examples for technical bootstrap and assisted reconstruction of final local wrappers
- those `.example.ps1` files do not replace the real local wrapper of the KB parallel folder and must not become an automatic execution fallback in the normal flow
- when the session already publishes the path of a skill or its examples, that published path takes precedence over local installation heuristics
- setup and compatibility operational memory should remain first inside the KB parallel folder itself, in `AGENTS.md`, `README.md`, and local operational files; external agent memory outside the repository must not be treated as a requirement or written without explicit user authorization
- if the engine needs to evolve, the change must preserve compatibility with that use or be accompanied by explicit updates to the consuming wrappers
