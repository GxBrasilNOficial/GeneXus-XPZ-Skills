# 14 - KB Intelligence Fase 3 - Contrato

## Papel do documento
contrato operacional

## Nivel de confianca predominante
medio

## Depende de
11-plano-kb-intelligence-incremental.md, historico/kb-intelligence/12-kb-intelligence-fase-1-contrato.md, historico/kb-intelligence/13-kb-intelligence-fase-2-contrato.md, scripts/README-kb-intelligence.md

## Usado por
agentes que forem usar ou evoluir consultas operacionais do KB Intelligence antes de alterar objetos GeneXus

## Objetivo
Definir a Fase 3 do KB Intelligence como camada de suporte a agentes de programacao, sem ampliar o escopo de extracao da Fase 2.

A Fase 3 deve transformar o indice tecnico ja validado em consultas curtas, baratas e rastreaveis para orientar alteracoes em objetos GeneXus. Ela nao deve prometer impacto runtime completo nem substituir a leitura do XML oficial quando a mudanca exigir semantica GeneXus.

## Escopo da Fase 3

### Consultas operacionais

A Fase 3 formaliza o uso operacional das consultas ja existentes:

- `search-objects`
- `object-info`
- `who-uses`
- `what-uses`
- `show-evidence`

A Fase 3 tambem define o contrato do novo comando:

- `impact-basic`

### Objetos cobertos pelo uso operacional

O guia de uso por agentes deve cobrir, no minimo:

- `Procedure`
- `WebPanel`
- `DataProvider`
- `Transaction`
- `WorkWithForWeb`

O suporte a `Transaction` e `WorkWithForWeb` nesta fase e limitado as relacoes diretas ja indexadas nas fases anteriores. Isso nao autoriza semantica completa desses tipos.

## Fora do escopo da Fase 3

- novas regras de extracao
- novas tabelas obrigatorias no schema
- semantica completa de `Transaction`
- semantica de `WorkWithForWeb` alem dos recortes ja cobertos
- inferencia por `for each`
- inferencia por `.Load(...)`
- resolucao semantica de `CustomType:<valor>` para `SDT`, `Domain` ou outro tipo GeneXus
- chat ou RAG
- documentacao funcional extensa para humanos
- prova de impacto runtime completo

Se alguma dessas frentes for desejada, deve ser aberta como fase futura ou contrato separado.

## Contrato de `impact-basic`

### Entrada minima

- `ObjectType`: tipo do objeto consultado
- `ObjectName`: nome do objeto consultado
- `Limit`: limite opcional de itens por grupo
- `Format`: `json` ou `text`

### Saida minima

A resposta deve conter:

- objeto consultado
- indicacao se o objeto foi encontrado
- arquivo XML relativo, quando encontrado
- quantidade de relacoes de entrada
- quantidade de relacoes de saida
- lista curta de dependentes diretos, baseada em `who-uses`
- lista curta de dependencias diretas, baseada em `what-uses`
- para cada item listado: tipo, nome, tipo da relacao, linha, snippet curto, regra de extracao e confianca
- aviso explicito de que o resultado representa impacto tecnico direto baseado no indice, nao impacto runtime completo

### Regras de interpretacao

- `impact-basic` deve usar apenas relacoes diretas registradas no SQLite.
- `impact-basic` nao deve inferir chamadas indiretas, fluxo funcional, navegacao dinamica ou dependencia por nome parecido.
- Quando houver muitas relacoes, a resposta deve resumir por contagem e respeitar `Limit`.
- Quando o objeto nao existir no indice, a resposta deve falhar de forma clara, sem tentar localizar por heuristica fora do indice.
- Quando a mudanca planejada depender de semantica GeneXus, o agente deve abrir o XML oficial e revisar o trecho relevante.

## Guia operacional para agentes

Antes de alterar objeto GeneXus coberto pelo indice, o agente deve:

1. localizar o objeto com `object-info` ou `search-objects`
2. consultar `impact-basic` para obter dependentes e dependencias diretas
3. usar `show-evidence` quando uma relacao influenciar a decisao de alteracao
4. abrir o XML oficial em `ObjetosDaKbEmXml` apenas para leitura quando a evidencia tecnica nao for suficiente
5. declarar na resposta se a avaliacao se baseia em evidencia direta do indice, leitura adicional do XML ou inferencia

O indice deve orientar triagem e reduzir custo de busca, mas o XML oficial continua sendo a fonte normativa.

## Gate minimo

A Fase 3 so deve ser considerada pronta quando:

- `impact-basic` estiver implementado nos wrappers e no motor de consulta
- `impact-basic` funcionar em `json` e `text`
- os comandos existentes continuarem funcionando
- existir validacao pequena com casos reais em `FabricaBrasil`
- a validacao preservar os 40 casos da Fase 2 quando o indice for regenerado
- o guia operacional estiver documentado em `scripts/README-kb-intelligence.md`
- o contrato deixar claro que nao houve ampliacao de extracao

## Validacao minima recomendada

Usar pelo menos estes casos:

- `Procedure:procPlanilhaVolumeMovimento`, para confirmar dependentes diretos conhecidos
- `WebPanel:wpRelatoriosDeMovimentosDeVolumes`, para confirmar dependencias diretas conhecidas
- um `WorkWithForWeb` com relacoes diretas da Fase 2, para confirmar que a resposta nao promete semantica completa do pattern
- um objeto inexistente, para confirmar falha clara sem heuristica

## Artefatos esperados

- atualizacao de `scripts/Query-KbIntelligenceIndex.ps1`
- atualizacao de `scripts/Query-KbIntelligenceIndex.py`
- `scripts/Test-KbIntelligenceQueries.ps1`
- `scripts/Test-KbIntelligenceQueries.py`
- atualizacao de `scripts/README-kb-intelligence.md`
- casos de validacao pequenos, se o comando passar a ter validacao automatizada propria

O banco SQLite continua sendo derivado e regeneravel. O indice canonico operacional em uma pasta paralela segue o padrao `KbIntelligence\kb-intelligence.sqlite`.

## Decisoes adiaveis

- decidir se `impact-basic` deve ter agrupamento adicional por `relation_kind`
- decidir se deve existir saida compacta propria para agentes em modo conversacional
- decidir se a Fase 3 justifica uma skill futura especifica de KB Intelligence
