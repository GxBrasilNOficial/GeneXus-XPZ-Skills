# KB Intelligence Fase 5 - Incremento 1 - FabricaBrasil

## Papel do documento
registro de incremento

## Data
2026-04-21

## Escopo

O primeiro incremento da Fase 5 adicionou resolucao semantica controlada de `ATTCUSTOMTYPE`.

O escopo consolidado cobre:

- preservacao da relacao literal `CustomType:<valor>` criada na Fase 2
- relacao resolvida para `SDT` quando o valor tiver prefixo `sdt:` e o objeto existir no inventario
- relacao resolvida para `Domain` quando houver prefixo explicitamente aceito e objeto correspondente
- regra de extracao `attcustomtype_resolved_object`
- evidencia `Property ATTCUSTOMTYPE`

## Validacao final

- KB laboratorio: `FabricaBrasil`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- casos da Fase 2 preservados: 40 `passed`
- casos da Fase 3 preservados: 4 `passed`
- casos da Fase 4 preservados: 6 `passed`
- casos do incremento 1 da Fase 5: 5 `passed`

## Fora do incremento

- interpretar estrutura interna de `SDT`
- inferir uso runtime do tipo
- resolver `bas:*` como `Domain`
- resolver nomes por heuristica agressiva
- remover a relacao literal `CustomType:<valor>`

## Recomendacao

Proximos incrementos da Fase 5 devem continuar pequenos e independentes, por exemplo `Attribute` -> `Domain` ou `Transaction` -> `Attribute`, sempre com contrato, evidencia e casos negativos.
