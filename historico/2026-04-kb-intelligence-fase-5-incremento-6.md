# KB Intelligence Fase 5 - Incremento 6 - FabricaBrasil

## Papel do documento
registro de incremento

## Data
2026-04-21

## Escopo

O sexto incremento da Fase 5 adicionou resolucao semantica controlada de `Table` para `Attribute` a partir dos membros declarados em indices de tabela.

O escopo consolidado cobre:

- origem `Table`
- destino `Attribute`, somente quando o valor do membro existir como atributo no inventario local
- regra de extracao `table_index_member_attribute`
- evidencia `Index Member`
- pares unicos de tabela e atributo, preservando a regra separada `table_key_attribute`

## Validacao final

- KB laboratorio: `FabricaBrasil`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 50291
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 25/25 casos passing

## Fora do incremento

- criar objeto `Index` proprio
- inferir chave estrangeira, navegacao, cardinalidade ou plano SQL
- substituir ou remover a regra `table_key_attribute`
- prometer semantica funcional alem de participacao estrutural em indice

## Recomendacao

Relacoes por chave estrangeira, navegacao, `for each`, `.Load(...)` ou comportamento runtime devem continuar separadas em incrementos proprios, com regra e evidencias especificas.
