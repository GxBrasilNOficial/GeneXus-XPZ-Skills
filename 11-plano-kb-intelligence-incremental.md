# 11 - Plano KB Intelligence Incremental

## Papel do documento
planejamento operacional

## Nivel de confianca predominante
baixo a medio

## Depende de
README.md, AGENTS.md, 02-regras-operacionais-e-runtime.md, 08-guia-para-agente-gpt.md, xpz-doc-builder/SKILL.md

## Usado por
agentes que forem evoluir scripts e skills para indexacao tecnica reutilizavel de pastas paralelas de KB GeneXus

## Objetivo
Definir uma frente incremental e validavel para construir uma base tecnica reutilizavel sobre o acervo XML de uma pasta paralela de KB GeneXus, com foco inicial em reduzir custo e tempo de agentes ao localizar objetos, referencias e impacto basico antes de criar ou alterar objetos.

Este plano substitui a sugestao externa `Plano_GeneXus_KB_Intelligence_v1.md` como orientacao de trabalho. A sugestao externa deve permanecer apenas como registro historico enquanto for util para rastreabilidade.

## Direcao decidida

- a prioridade inicial e apoiar agentes de IA durante programacao, criacao de objetos e alteracao de objetos existentes
- a segunda linha de valor e apoiar agentes de IA para suporte, onboarding e entendimento funcional, preferencialmente via chat, nao por documentacao estatica consumida diretamente por humanos
- a primeira entrega estrutural deve ser um banco tecnico reutilizavel, nao uma pagina Markdown manual nem um RAG
- a documentacao versionada deve cobrir metodo, schema, scripts, testes e validacoes; artefatos derivados grandes devem ser regeneraveis a partir dos XMLs oficiais

## Estado atual da frente

Em 2026-04-21, a Fase 1 foi concluida e validada na KB real `FabricaBrasil`, com local canonico operacional em `C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite`.

A Fase 2 foi aberta e consolidada em 2026-04-21, com primeiro incremento limitado a `DataProvider` como nova origem de relacoes em `Source` efetivo.

Na mesma data, a Fase 2 recebeu um segundo incremento pequeno: `DataProvider` como destino de chamada direta em `Source` efetivo.

Na mesma data, a Fase 2 recebeu mais dois incrementos controlados: actions de `WorkWithForWeb` com atributo `gxobject` resolvido para `Procedure` ou `WebPanel`, e propriedades `ATTCUSTOMTYPE` indexadas como alvo literal `CustomType:<valor>`.

Ainda na mesma data, a Fase 2 recebeu um quinto incremento controlado: vinculacao explicita de `WorkWithForWeb` para `Transaction` por tag interna `<transaction transaction="guid-Nome">`.

Depois disso, a Fase 2 recebeu um sexto incremento controlado: links explicitos de `WorkWithForWeb` para `WebPanel` por tag interna `<link webpanel="Nome">`.

Na sequencia, a Fase 2 recebeu um setimo incremento controlado: prompts explicitos de `WorkWithForWeb` para `WebPanel` por atributo `prompt="guid-Nome"`.

Na sequencia, a Fase 2 recebeu um oitavo incremento controlado: expressoes de condicao de `WorkWithForWeb` chamando `Procedure` por `<condition value="...procNome(...)...">`.

Na sequencia, a Fase 2 recebeu um nono incremento controlado: atributos de condicao de `WorkWithForWeb`, como `condition="..."` e `DeleteCondition="..."`, chamando `Procedure`.

A Fase 2 fica consolidada com estes nove incrementos validados.

Em 2026-04-21, a Fase 3 foi aberta, implementada e encerrada como camada operacional de consulta para agentes, sem ampliar extracao. O incremento consolidou `impact-basic`, validacao automatizada propria de consulta e guia de uso operacional.

Continuam fora da Fase 2: semantica completa de `Transaction`, semantica de `WorkWithForWeb` alem dos recortes ja cobertos, `for each`, `.Load(...)`, resolucao semantica de `CustomType` para `SDT` ou `Domain`, e inferencias por layout ou comentarios.

## Principios da frente

- passos pequenos e validaveis prevalecem sobre cobertura ampla rapida
- cada fase so avanca depois de pronta, testada e validada em casos reais
- a fonte normativa continua sendo `ObjetosDaKbEmXml`, atualizado apenas por export oficial da KB via fluxo local
- o indice tecnico e artefato derivado; ele nao substitui o acervo XML
- toda relacao indexada deve guardar evidencia rastreavel
- quando houver inferencia, ela deve ser classificada separadamente de evidencia direta
- a solucao deve ser generica para qualquer pasta paralela de KB, com a KB `FabricaBrasil` apenas como laboratorio real
- resultados de prototipos anteriores podem servir como anti-exemplos e casos de teste, mas nao como arquitetura definitiva

## Nao objetivos iniciais

- nao criar RAG ou chat na primeira fase
- nao gerar documentacao humana extensa como entrega principal
- nao indexar todos os 33 ou 34 tipos de objeto no primeiro recorte
- nao confiar em validacao que apenas prove consistencia interna do indice
- nao versionar banco derivado grande como fonte primaria, salvo decisao posterior explicita

## Arquitetura alvo inicial

### Fonte normativa

XMLs individuais em `ObjetosDaKbEmXml`, organizados por tipo de objeto, vindos de export oficial da KB.

### Banco tecnico local

Banco SQLite gerado a partir dos XMLs. Deve ser tratado como artefato derivado e reconstruivel.

O local operacional padrao em uma pasta paralela de KB deve ser `KbIntelligence\kb-intelligence.sqlite`. A pasta `KbIntelligence` e estavel para descoberta por agentes, mas seus artefatos gerados continuam derivados de `ObjetosDaKbEmXml`.

### Exportes auxiliares

JSONL ou JSON pequenos podem existir para debug, amostras, testes e auditoria pontual. Eles nao devem ser a base operacional principal.

### Consulta para agente

Script simples para responder perguntas operacionais:

- quem usa `Tipo:Nome`
- o que `Tipo:Nome` usa
- onde esta a evidencia
- qual regra de extracao encontrou a evidencia
- qual nivel de confianca foi atribuido

## Modelo minimo de dados

### `objects`

Campos minimos:

- `object_id`
- `type`
- `name`
- `file_path`
- `last_update`
- `file_hash`

### `relations`

Campos minimos:

- `source_object_id`
- `target_type`
- `target_name`
- `relation_kind`
- `evidence_id`
- `confidence`

### `evidence`

Campos minimos:

- `evidence_id`
- `source_file`
- `line`
- `column`
- `snippet`
- `evidence_role`
- `extractor_rule`

## Fase 1 - indice minimo confiavel

### Objetivo

Construir o menor indice util para agentes identificarem chamadas diretas entre objetos principais, com evidencia de linha e regra de extracao.

### Escopo inicial

Origens:

- `Procedure`
- `WebPanel`

Destinos:

- `Procedure`
- `WebPanel`

Padroes seguros iniciais:

- `procNome(...)`
- `procNome.Call(...)`
- `WebPanelNome.Link(...)`
- `WWNome.Link(...)`

Padroes a avaliar antes de aceitar:

- `WebPanelNome(...)`
- chamadas indiretas por variavel
- chamadas dinamicas
- referencias em comentarios
- referencias dentro de layout HTML ou XML visual, quando nao forem `Source` efetivo

### Evidencia obrigatoria

Cada relacao deve guardar:

- tipo e nome do objeto origem
- tipo e nome do objeto destino
- arquivo XML de origem
- linha exata ou a melhor linha calculada a partir do XML salvo
- trecho curto da evidencia
- papel da evidencia, por exemplo `Source efetivo`
- regra de extracao aplicada
- confianca inicial

### Gate de validacao

A fase so pode ser considerada pronta quando:

- o banco for gerado a partir de uma pasta paralela real
- a consulta `who-uses` funcionar para casos conhecidos
- a consulta `what-uses` funcionar para casos conhecidos
- chamadas `procNome.Call(...)` forem detectadas corretamente
- comentarios e layout visual nao forem tratados como chamada efetiva
- houver bateria pequena de casos reais documentada

Caso conhecido obrigatorio para a bateria:

- `WebPanel:wpRelatoriosDeMovimentosDeVolumes` chama `Procedure:procPlanilhaVolumeMovimento` em `Source` efetivo por `procPlanilhaVolumeMovimento.Call(...)`

## Fase 2 - ampliacao controlada

So iniciar depois da Fase 1 validada.

Estado em 2026-04-21: fase consolidada com ampliacao controlada para `DataProvider` como origem e destino direto, actions de `WorkWithForWeb` por `gxobject`, vinculacoes explicitas `WorkWithForWeb` -> `Transaction`, links explicitos `WorkWithForWeb` -> `WebPanel`, prompts explicitos `WorkWithForWeb` -> `WebPanel`, condicoes por tag e atributo de `WorkWithForWeb` -> `Procedure`, e propriedades `ATTCUSTOMTYPE` como alvo literal `CustomType`.

Possiveis ampliacoes:

- `DataProvider`
- `WorkWithForWeb`
- `Transaction`
- relacoes por `ATTCUSTOMTYPE`
- relacoes por actions de `WorkWithForWeb`
- relacoes por `for each` e `Load`, com classificacao propria e cautela runtime

Cada novo tipo ou padrao deve entrar com:

- exemplos reais positivos
- exemplos reais negativos
- regra de extracao nomeada
- teste de regressao
- classificacao de evidencia

### Primeiro incremento - `DataProvider` como origem

Escopo aceito:

- origem: `DataProvider`
- destinos: `Procedure` e `WebPanel`
- regras: `procedure_direct_call`, `procedure_dot_call` e `webpanel_dot_link`
- evidencia: `Source efetivo`
- confianca: `direct`

Fora do primeiro incremento:

- inferir relacoes por `for each`
- inferir relacoes por `.Load(...)`
- interpretar estrutura semantica completa do `DataProvider`
- tratar `DataProvider` como destino
- ampliar `Transaction` ou `WorkWithForWeb`

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- adicionar casos reais positivos e negativos para `DataProvider`
- validar que comentario em `DataProvider` nao cria relacao direta

### Segundo incremento - `DataProvider` como destino

Escopo aceito:

- origens: `Procedure`, `WebPanel` e `DataProvider`
- destino: `DataProvider`
- regra: `dataprovider_direct_call`
- evidencia: `Source efetivo`
- confianca: `direct`

Fora do segundo incremento:

- interpretar `for each` como relacao de entidade
- interpretar `.Load(...)`
- inferir dependencia por SDT de saida
- ampliar `Transaction` ou `WorkWithForWeb`

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- manter os casos do primeiro incremento de `DataProvider` passando
- adicionar casos reais positivos de chamadas de `DataProvider` por `Procedure` e `WebPanel`
- validar que comentario com chamada de `DataProvider` nao cria relacao direta

### Terceiro incremento - actions de `WorkWithForWeb`

Escopo aceito:

- origem: `WorkWithForWeb`
- destinos: `Procedure` e `WebPanel`
- regra: `workwith_action_gxobject`
- evidencia: `WorkWith action`
- confianca: `direct`

Fora do terceiro incremento:

- interpretar `Selection` ou grids como dependencia semantica
- inferir relacao por caption, tooltip, imagem ou nome da action
- tratar `gxobject` que nao resolva para `Procedure` ou `WebPanel`
- ampliar `Transaction` por associacao com o `WorkWithForWeb`

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- manter os casos anteriores da Fase 2 passando
- adicionar casos reais positivos para action chamando `Procedure` e `WebPanel`
- adicionar caso negativo que prove que alvo inexistente nao cria relacao

### Quarto incremento - `ATTCUSTOMTYPE` como `CustomType` literal

Escopo aceito:

- origens: objetos ja coletados pelo indice
- destino: `CustomType`
- regra: `attcustomtype_property`
- evidencia: `Property ATTCUSTOMTYPE`
- confianca: `direct`

Fora do quarto incremento:

- resolver `CustomType` para objeto `SDT`, `Domain` ou outro tipo GeneXus
- inferir uso efetivo em runtime
- interpretar estrutura interna do tipo referenciado

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- manter os casos anteriores da Fase 2 passando
- adicionar casos reais positivos em `Transaction` e `Procedure`
- adicionar caso negativo para `CustomType` inexistente

### Quinto incremento - vinculacao explicita de `WorkWithForWeb` com `Transaction`

Escopo aceito:

- origem: `WorkWithForWeb`
- destino: `Transaction`
- regra: `workwith_transaction_binding`
- evidencia: `WorkWith transaction`
- confianca: `direct`

Fora do quinto incremento:

- interpretar semantica completa da `Transaction`
- inferir relacao por nome do arquivo ou por convencao `WorkWithWeb<Transacao>`
- inferir entidade por atributo, filtro, `Selection` ou grid
- tratar `for each` como relacao de entidade

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- manter os casos anteriores da Fase 2 passando
- adicionar casos reais positivos para `WorkWithForWeb` referenciando `Transaction`
- adicionar caso negativo para `Transaction` inexistente

### Sexto incremento - links explicitos de `WorkWithForWeb` para `WebPanel`

Escopo aceito:

- origem: `WorkWithForWeb`
- destino: `WebPanel`
- regra: `workwith_link_webpanel`
- evidencia: `WorkWith link`
- confianca: `direct`

Fora do sexto incremento:

- inferir relacao por atributo, caption, prompt, autolink ou nome de coluna
- interpretar parametros do link
- ampliar semantica de `WorkWithForWeb` alem da tag explicita `<link webpanel="...">`
- tratar links nao resolvidos como relacoes

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- manter os casos anteriores da Fase 2 passando
- adicionar casos reais positivos para `WorkWithForWeb` linkando `WebPanel`
- adicionar caso que prove canonizacao de nome do `WebPanel`
- adicionar caso negativo para `WebPanel` inexistente

### Setimo incremento - prompts explicitos de `WorkWithForWeb` para `WebPanel`

Escopo aceito:

- origem: `WorkWithForWeb`
- destino: `WebPanel`
- regra: `workwith_prompt_webpanel`
- evidencia: `WorkWith prompt`
- confianca: `direct`

Fora do setimo incremento:

- inferir prompt por nome de atributo ou caption
- interpretar parametros ou contrato funcional do prompt
- tratar prompts nao resolvidos como relacoes

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- manter os casos anteriores da Fase 2 passando
- adicionar casos reais positivos para `WorkWithForWeb` apontando prompts `WebPanel`
- adicionar caso negativo para `WebPanel` inexistente

### Oitavo incremento - condicoes de `WorkWithForWeb` chamando `Procedure`

Escopo aceito:

- origem: `WorkWithForWeb`
- destino: `Procedure`
- regra: `workwith_condition_procedure`
- evidencia: `WorkWith condition`
- confianca: `direct`

Fora do oitavo incremento:

- interpretar semantica de filtros, atributos ou operadores da condicao
- inferir relacao por nome de atributo usado na condicao
- tratar chamadas dinamicas ou procedures nao resolvidas como relacoes

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- manter os casos anteriores da Fase 2 passando
- adicionar casos reais positivos para `WorkWithForWeb` chamando `Procedure` em `<condition value="...">`
- adicionar caso negativo para `Procedure` inexistente

### Nono incremento - atributos de condicao de `WorkWithForWeb` chamando `Procedure`

Escopo aceito:

- origem: `WorkWithForWeb`
- destino: `Procedure`
- regra: `workwith_condition_attribute_procedure`
- evidencia: `WorkWith condition attribute`
- confianca: `direct`

Fora do nono incremento:

- interpretar semantica de filtros, atributos ou operadores da condicao
- inferir relacao por nome de atributo usado na condicao
- tratar trecho apos comentario `//` como chamada efetiva
- tratar chamadas dinamicas ou procedures nao resolvidas como relacoes

Gate minimo:

- manter os 15 casos reais da Fase 1 passando
- manter os casos anteriores da Fase 2 passando
- adicionar casos reais positivos para `condition="..."` e `DeleteCondition="..."`
- adicionar caso negativo para chamada apos comentario `//`

## Fase 3 - suporte a agentes de programacao

Aberta por contrato em `14-kb-intelligence-fase-3-contrato.md`, depois do encerramento validado da Fase 2.

Estado em 2026-04-21: implementada e encerrada, com registro em `historico/2026-04-kb-intelligence-fase-3-encerramento.md`.

A Fase 3 nao amplia o escopo de extracao. Ela formaliza o uso operacional do indice tecnico por agentes antes de alterar objetos GeneXus.

Entregas:

- manter os comandos `search-objects`, `object-info`, `who-uses`, `what-uses`, `show-evidence` e `impact-basic`
- documentar guia para agente consultar o indice antes de alterar `Procedure`, `WebPanel`, `DataProvider`, `Transaction`, `WorkWithForWeb` ou objetos relacionados
- deixar claro que `impact-basic` representa impacto tecnico direto baseado no indice, nao impacto runtime completo

Esta fase deve priorizar respostas curtas, baratas e rastreaveis.

## Fase 4 - inventario ampliado de tipos

Aberta por contrato em `15-kb-intelligence-fase-4-contrato.md`, depois do encerramento validado da Fase 3.

Estado em 2026-04-21: implementada e encerrada, com registro em `historico/2026-04-kb-intelligence-fase-4-encerramento.md`.

Objetivo:

- ampliar a tabela `objects` para todos os tipos materializados em `ObjetosDaKbEmXml`
- manter `search-objects`, `object-info` e `impact-basic` funcionando para tipos sem relacoes extraidas
- nao ampliar relacoes semanticas nesta fase

## Fase 5 - relacoes semanticas ampliadas

Aberta por contrato em `16-kb-intelligence-fase-5-contrato.md`, depois do encerramento validado da Fase 4.

Estado em 2026-04-22: a subtrilha principal da Fase 5 ficou consolidada ate o incremento 18.

O escopo validado ate aqui cobre:

- resolucao de `CustomType:<valor>` para `SDT`, `Domain` e `ExternalObject` quando houver objeto inventariado correspondente e regra aprovada para o prefixo
- `Attribute` para `Domain` por `idBasedOn` quando o dominio existir no inventario local
- `Transaction` para `Attribute` por `<Level>/<Attribute>`
- `Table` para `Attribute` por `<Key>/<Item>`
- `Transaction` para `Table` por `Type` em `<Level>`
- `Table` para `Attribute` por membros de indice
- `SDT` para `SDT` por `ATTCUSTOMTYPE` em item interno
- ampliacao de origem de `ATTCUSTOMTYPE` resolvido para `API`, `DataSelector`, `Domain` e `SDT` top-level
- `Procedure`/`WebPanel` para `Table` por `for each <Nome>` explicito em `Source` efetivo
- `Procedure`/`WebPanel` para `Table` pelo prefixo de `for each <Nome>.<Membro>` qualificado
- `Procedure`/`WebPanel`/`DataProvider` para `Transaction` por `.Load(...)`, `.Save()`, `.Delete()`, `.Check()`, `.Insert()` e `.Update()` de variavel BC com `ATTCUSTOMTYPE` `bc:*` resolvido, mantendo colecoes fora do incremento de `.Insert()`/`.Update()`

Para novas propostas de incremento no eixo `ATTCUSTOMTYPE`, a triagem deve separar primeiro os valores por prefixo real observado no acervo, em vez de decidir por volume bruto agregado. Prefixos com semanticas diferentes, como `bas:`, `sdt:`, `bc:`, `exo:` e `ext:`, devem ser tratados como subtrilhas distintas antes de qualquer proposta metodologica nova.

Tambem ficou medido e registrado que `Success()`, `Fail()` e `GetMessages()` em variavel `bc:*` nao acrescentam pares novos `origem -> Transaction` fora da cobertura forte ja existente, e por isso nao justificam um incremento 19 no mesmo eixo.

Entregas possiveis:

- abrir familia nova de relacao com evidencia estrutural nova e ganho liquido de cobertura
- abrir contrato proprio para evidencia mais fraca somente se houver valor operacional claro
- encerrar tecnicamente a Fase 5 antes de abrir a Fase 6, caso nao apareca nova familia defensavel

Cada relacao nova deve entrar por contrato incremental, com exemplos reais positivos, exemplos reais negativos, regra de extracao, evidencia e teste de regressao.

## Fase 6 - suporte funcional por agentes

Aberta por contrato em `17-kb-intelligence-fase-6-contrato.md`, com foco inicial em metodo de triagem funcional assistida, ainda sem automacao funcional nova.

So iniciar depois da base tecnica sustentar consultas confiaveis e depois de decidir se ainda ha expansao tecnica relevante pendente na Fase 5.

A antiga previsao de Fase 4 foi renumerada para Fase 6 antes de abertura formal, para preservar a sequencia: inventario, relacoes semanticas, suporte funcional.

Entregas possiveis:

- agente de suporte consultando relacoes tecnicas e trechos de evidencia
- resumos funcionais gerados sob demanda
- explicacao de regras e fluxos com indicacao de evidencias

Esta fase nao deve depender de humanos lendo documentacao estatica extensa.

Estado em 2026-04-22: contrato de abertura preparado para formalizar a trilha de suporte funcional assistido por agentes, preservando a precedencia do XML oficial sobre o indice tecnico.

Na mesma data, foi executado o primeiro piloto operacional da Fase 6 em `20-kb-intelligence-fase-6-piloto-investigacao-funcional.md`, usando `FabricaBrasil` como laboratorio real. O piloto confirmou o uso do indice como trilha de triagem e do XML oficial como fonte normativa, alem de registrar que o indice canonico operacional parecia defasado em relacao aos incrementos finais da Fase 5 e nao deveria ser sobrescrito sem decisao explicita. Depois de decisao explicita do usuario, o indice canonico de `FabricaBrasil` foi regenerado pela rotina oficial e validado com a bateria consolidada da Fase 5.

Na sequencia, a Fase 6 recebeu um checklist operacional para agentes em `21-kb-intelligence-fase-6-checklist-operacional-agente.md`, consolidando a ordem minima de triagem, abertura do XML oficial e classificacao da resposta funcional.

Depois disso, foi preparado e implementado o contrato da consulta auxiliar `functional-trace-basic` em `22-kb-intelligence-fase-6-contrato-functional-trace-basic.md`, para reduzir repeticao operacional de triagem sem produzir conclusao funcional automatica.

## Versionamento recomendado

Versionar:

- plano da frente
- schema
- scripts
- testes
- casos de validacao
- relatorios pequenos de validacao
- documentacao metodologica consolidada

Nao versionar como regra:

- banco SQLite derivado grande
- exports JSON/JSONL completos derivados do acervo
- artefatos temporarios de execucao

Excecoes devem ser decididas explicitamente por frente.

## Tratamento do experimento `Mapeamento`

O experimento em `C:\Dev\Prod\Gx_FabricaBrasil\Mapeamento` deve ser tratado como:

- prototipo descartavel
- fonte de anti-exemplos
- fonte de casos reais para bateria inicial
- evidencia de que a dor operacional existe

Ele nao deve ser evoluido como base arquitetural definitiva nem competir com `KbIntelligence` como fonte operacional.

Quando a nova frente nao precisar mais dele para comparacao, a pasta `Mapeamento` da KB real pode ser movida para `ArquivoMorto\Mapeamento` por decisao explicita do usuario no repositorio da KB, nao nesta raiz metodologica.

Na KB `FabricaBrasil`, essa movimentacao foi executada em 2026-04-21, junto com a regra local em `README.md` e `AGENTS.md` da pasta paralela.

O `AGENTS.md` da raiz da pasta paralela deve orientar agentes a ignorar `ArquivoMorto`, ou tratar seu conteudo como nao confiavel, salvo pedido explicito do usuario para analise historica.

## Tratamento da sugestao externa v1

`Plano_GeneXus_KB_Intelligence_v1.md` veio como sugestao de outro agente que nao leu as skills desta pasta nem estudou uma pasta paralela real da KB.

Ele deve ser preservado apenas como registro historico e substituido por este plano como orientacao vigente.

## Divida tecnica e decisoes adiaveis

- definir nome final da frente tecnica ou skill futura
- confirmar politica de snapshots pequenos para validacao em Git
- manter como decisao tecnica futura a estrategia de calculo de linha exata em XML com `CDATA`
