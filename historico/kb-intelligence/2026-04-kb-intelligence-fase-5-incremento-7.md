# KB Intelligence Fase 5 - Incremento 7 - KBExemplo

## Papel do documento
registro de incremento

## Data
2026-04-21

## Escopo

O setimo incremento da Fase 5 adicionou resolucao semantica controlada de `SDT` para `SDT` a partir de `ATTCUSTOMTYPE` em itens internos de `SDT`.

O escopo consolidado cobre:

- origem `SDT`
- destino `SDT`, somente quando o valor de `ATTCUSTOMTYPE` tiver prefixo `sdt:` e existir como SDT no inventario local
- regra de extracao `sdt_item_attcustomtype_resolved_sdt`
- evidencia `SDT Item ATTCUSTOMTYPE`
- pares unicos de SDT de origem e SDT de destino

## Validacao final

- KB laboratorio: `KBExemplo`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 50637
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 29/29 casos passing

## Fora do incremento

- criar objeto proprio para membro de `SDT`
- resolver tipos `bas:*`
- resolver `Domain` a partir de item de `SDT` sem evidencia real aprovada
- inferir uso runtime, serializacao ou contrato de API
- expandir estrutura interna completa do `SDT`

## Recomendacao

Relacoes por `for each`, `.Load(...)`, contrato de API, serializacao ou comportamento runtime devem continuar separadas em incrementos proprios, com regra e evidencias especificas.
