# KB Intelligence Fase 5 - Incremento 4 - KBExemplo

## Papel do documento
registro de incremento

## Data
2026-04-21

## Escopo

O quarto incremento da Fase 5 adicionou resolucao semantica controlada de `Table` para `Attribute` a partir dos elementos estruturais `<Key>/<Item>`.

O escopo consolidado cobre:

- origem `Table`
- destino `Attribute`, somente quando o atributo existir no inventario local
- regra de extracao `table_key_attribute`
- evidencia `Key Item`
- atributos de chave primaria declarados no XML da tabela

## Validacao final

- KB laboratorio: `KBExemplo`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 48452
- casos da Fase 2 preservados: 40 `passed`
- casos da Fase 3 preservados: 4 `passed`
- casos da Fase 4 preservados: 6 `passed`
- casos da Fase 5 ampliados para cobrir os incrementos 1, 2, 3 e 4: 17 `passed`

## Fora do incremento

- usar membros de indice como composicao completa da tabela
- inferir atributos nao chave
- inferir chave estrangeira ou relacao runtime
- criar relacao para atributo ausente do inventario local
- tratar `<Members>/<Member>` como `table_key_attribute`

## Recomendacao

`Table` -> `Attribute` por membros de indice deve, se necessario, entrar como regra separada e nomeada. O incremento 4 cobre apenas a chave primaria.
