# KB Intelligence Fase 5 - Incremento 3 - FabricaBrasil

## Papel do documento
registro de incremento

## Data
2026-04-21

## Escopo

O terceiro incremento da Fase 5 adicionou resolucao semantica controlada de `Transaction` para `Attribute` a partir dos elementos estruturais `<Level>/<Attribute>`.

O escopo consolidado cobre:

- origem `Transaction`
- destino `Attribute`, somente quando o atributo existir no inventario local
- regra de extracao `transaction_level_attribute`
- evidencia `Level Attribute`
- atributos chave e nao chave declarados nos niveis da transacao

## Validacao final

- KB laboratorio: `FabricaBrasil`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 47894
- casos da Fase 2 preservados: 40 `passed`
- casos da Fase 3 preservados: 4 `passed`
- casos da Fase 4 preservados: 6 `passed`
- casos da Fase 5 ampliados para cobrir os incrementos 1, 2 e 3: 13 `passed`

## Fora do incremento

- usar `AttributeProperties` como fonte de relacao
- inferir atributo por variaveis, `idBasedOn` interno ou nome no `Source`
- inferir `Transaction` -> `Table`
- inferir participacao em indice, chave estrangeira ou regra runtime
- criar relacao para atributo ausente do inventario local

## Recomendacao

Proximos incrementos da Fase 5 devem seguir pequenos. `Table` -> `Attribute` ainda precisa de contrato proprio, porque membros de indices nao equivalem necessariamente a composicao completa da tabela.
