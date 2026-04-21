# 15 - KB Intelligence Fase 4 - Contrato

## Papel do documento
contrato operacional

## Nivel de confianca predominante
medio

## Depende de
11-plano-kb-intelligence-incremental.md, 14-kb-intelligence-fase-3-contrato.md, scripts/README-kb-intelligence.md

## Usado por
agentes que forem ampliar o inventario de objetos do KB Intelligence sem ampliar ainda as relacoes semanticas

## Objetivo
Definir a Fase 4 do KB Intelligence como ampliacao de inventario de tipos no SQLite.

A Fase 4 deve fazer o indice conhecer todos os tipos materializados em `ObjetosDaKbEmXml`, permitindo localizar e consultar objetos por tipo e nome mesmo quando ainda nao houver regras de relacao semantica para esses tipos.

## Escopo da Fase 4

### Inventario de objetos

O gerador do indice deve coletar todos os diretorios imediatos de `ObjetosDaKbEmXml` que contenham XMLs individualizados e gravar esses objetos na tabela `objects`.

Para cada objeto coletado, manter os campos ja existentes:

- `object_id`
- `type`
- `name`
- `file_path`
- `last_update`
- `file_hash`

### Consultas impactadas

As consultas abaixo devem passar a funcionar para todos os tipos inventariados:

- `search-objects`
- `object-info`
- `impact-basic`

Para tipos sem relacoes extraidas, `impact-basic` deve encontrar o objeto e retornar contagens zero ou as relacoes existentes, sem inferir semantica nova.

## Fora do escopo da Fase 4

- resolver `CustomType:<valor>` para `SDT`, `Domain` ou outro tipo GeneXus
- extrair relacoes novas entre `Transaction`, `Attribute`, `Domain`, `Table`, `SDT` ou outros tipos
- inferir `for each`
- inferir `.Load(...)`
- interpretar semantica funcional de tipos recem-inventariados
- alterar o schema minimo das tabelas principais
- criar chat, RAG ou suporte funcional por agentes

Essas frentes devem ficar para Fase 5 ou posterior, com contrato proprio.

## Regras de coleta

- cada subpasta imediata de `SourceRoot` que contenha `*.xml` deve ser tratada como tipo de objeto
- o tipo do objeto deve ser o nome da subpasta
- o nome do objeto deve continuar sendo o nome do arquivo sem extensao
- `file_path` deve continuar relativo ao `SourceRoot`
- `last_update` deve ser extraido quando existir no XML; ausencia nao deve bloquear inventario
- tipos sem XML nao devem aparecer no indice
- a coleta ampliada nao deve alterar as regras de extracao de relacoes da Fase 2

## Gate minimo

A Fase 4 so deve ser considerada pronta quando:

- o indice gravar todos os tipos com XML sob `ObjetosDaKbEmXml`
- a validacao da Fase 2 continuar com 40 casos `passed`
- a validacao da Fase 3 continuar com 4 casos `passed`
- existir validacao pequena propria da Fase 4 para tipos antes nao coletados
- `search-objects` e `object-info` funcionarem para tipos ampliados
- `impact-basic` encontrar tipos ampliados e nao inventar relacoes

## Validacao minima recomendada

Usar pelo menos:

- um `Attribute` real
- um `Domain` real
- um `SDT` real
- um `Table` real
- um objeto inexistente de tipo ampliado

Os casos devem validar existencia, tipo, arquivo relativo e comportamento conservador de `impact-basic`.

## Artefatos esperados

- atualizacao de `scripts/New-KbIntelligenceIndex.py`
- casos de validacao pequenos da Fase 4
- atualizacao de `scripts/README-kb-intelligence.md`
- registro historico de encerramento ao final da fase

O banco SQLite continua sendo derivado e regeneravel. A fonte normativa permanece `ObjetosDaKbEmXml`.

## Relacao com fases seguintes

A Fase 5 deve tratar relacoes semanticas ampliadas por contratos incrementais.

A Fase 6 deve tratar suporte funcional por agentes e deve ser aberta preferencialmente em conversa nova depois do encerramento das fases tecnicas necessarias.
