# KB Intelligence Fase 5 - Incremento 2 - FabricaBrasil

## Papel do documento
registro de incremento

## Data
2026-04-21

## Escopo

O segundo incremento da Fase 5 adicionou resolucao semantica controlada de `Attribute` para `Domain` a partir da propriedade `idBasedOn`.

O escopo consolidado cobre:

- origem `Attribute`
- destino `Domain`, somente quando o dominio existir no inventario local
- regra de extracao `attribute_idbasedon_domain`
- evidencia `Property idBasedOn`
- bloqueio de dominios externos ou built-in sem objeto local correspondente

## Validacao final

- KB laboratorio: `FabricaBrasil`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 39512
- casos da Fase 2 preservados: 40 `passed`
- casos da Fase 3 preservados: 4 `passed`
- casos da Fase 4 preservados: 6 `passed`
- casos da Fase 5 ampliados para cobrir os incrementos 1 e 2: 9 `passed`

## Fora do incremento

- criar dominio inexistente
- resolver dominios externos do GeneXus sem objeto local
- inferir semantica de atributo por nome
- inferir relacao de `Transaction`, `Table` ou `Source`

## Recomendacao

Proximos incrementos da Fase 5 devem seguir tratando uma familia de relacao por vez. O candidato natural seguinte e `Transaction` -> `Attribute`, mas ele exige leitura cuidadosa da estrutura da transacao antes de contrato.
