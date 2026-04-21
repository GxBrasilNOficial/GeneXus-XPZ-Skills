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

## Fase 3 - suporte a agentes de programacao

So iniciar depois de existir banco tecnico confiavel.

Entregas possiveis:

- comando `who-uses`
- comando `what-uses`
- comando `show-evidence`
- comando `impact-basic`
- guia para agente consultar o indice antes de alterar `Procedure`, `WebPanel`, `Transaction` ou objetos relacionados

Esta fase deve priorizar respostas curtas, baratas e rastreaveis.

## Fase 4 - suporte funcional por agentes

So iniciar depois da base tecnica sustentar consultas confiaveis.

Entregas possiveis:

- agente de suporte consultando relacoes tecnicas e trechos de evidencia
- resumos funcionais gerados sob demanda
- explicacao de regras e fluxos com indicacao de evidencias

Esta fase nao deve depender de humanos lendo documentacao estatica extensa.

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

## Proximas decisoes abertas

- nome final da frente tecnica ou skill futura
- linguagem principal dos scripts compartilhados
- local dos scripts genericos nesta raiz
- local dos adaptadores por KB real
- estrategia de calculo de linha exata em XML com `CDATA`
- politica de snapshots pequenos para validacao em Git
