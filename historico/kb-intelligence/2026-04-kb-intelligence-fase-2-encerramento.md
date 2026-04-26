# Encerramento KB Intelligence Fase 2 - KBExemplo

## Papel do documento
registro de encerramento

## Data
2026-04-21

## Escopo encerrado

A Fase 2 foi encerrada como ampliacao controlada da Fase 1, sem iniciar Fase 3.

O escopo consolidado cobre:

- `DataProvider` como origem e destino de chamada direta
- actions de `WorkWithForWeb` com `gxobject` resolvido para `Procedure` ou `WebPanel`
- vinculacoes explicitas de `WorkWithForWeb` para `Transaction`
- links e prompts explicitos de `WorkWithForWeb` para `WebPanel`
- condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`
- `ATTCUSTOMTYPE` como `CustomType:<valor>` literal

## Validacao final

- KB laboratorio: `KBExemplo`
- objetos gravados no indice: 3890
- relacoes gravadas no indice: 34276
- casos de validacao da Fase 2: 40 `passed`
- regressao da Fase 1 preservada

## Fora do encerramento

Continuam fora da Fase 2:

- semantica completa de `Transaction`
- semantica de `WorkWithForWeb` alem dos recortes ja cobertos
- inferencia por `for each`
- inferencia por `.Load(...)`
- resolucao semantica de `CustomType:<valor>` para `SDT`, `Domain` ou outro tipo GeneXus
- inferencias por layout visual ou comentarios

## Divida tecnica e decisoes adiaveis

- definir se `CustomType:<valor>` deve ser resolvido semanticamente em fase futura
- decidir se uma fase futura deve tratar `for each` e `.Load(...)`, com classificacao propria e cautela runtime
- definir contrato de Fase 3 antes de implementar `impact-basic`
- definir politica de snapshots pequenos versionados para baterias de validacao
- manter como decisao futura a estrategia definitiva de linha exata em XML com `CDATA`

## Recomendacao

Abrir conversa nova antes de iniciar Fase 3, para evitar carregar decisoes de implementacao da Fase 2 como premissas implicitas.
