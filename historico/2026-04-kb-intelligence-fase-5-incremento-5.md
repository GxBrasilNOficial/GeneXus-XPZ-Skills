# KB Intelligence Fase 5 - Incremento 5 - FabricaBrasil

## Papel do documento
registro de incremento

## Data
2026-04-21

## Escopo

O quinto incremento da Fase 5 adicionou resolucao semantica controlada de `Transaction` para `Table` a partir do atributo `Type` de elementos estruturais `<Level>`.

O escopo consolidado cobre:

- origem `Transaction`
- destino `Table`, somente quando o valor de `Type` existir como tabela no inventario local
- regra de extracao `transaction_level_table`
- evidencia `Level Type`
- niveis principais e subniveis resolviveis para tabelas locais

## Validacao final

- KB laboratorio: `FabricaBrasil`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 48633
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 21/21 casos passing

## Fora do incremento

- inferir tabela por nome da transacao
- criar relacao para subnivel sem tabela local correspondente
- inferir chave estrangeira, indice, navegacao ou comportamento runtime
- inferir composicao fisica completa de tabela
- criar relacao para tabela ausente do inventario local

## Recomendacao

Relacoes por indice, chave estrangeira, navegacao ou runtime devem continuar separadas em incrementos proprios, com regra e evidencias especificas.
