# KB Intelligence Fase 5 - Incremento 10 - KBExemplo

## Papel do documento
registro de incremento

## Data
2026-04-22

## Escopo

O decimo incremento da Fase 5 adicionou resolucao semantica controlada de `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de chamadas `.Load(...)` em variaveis Business Component no `Source` efetivo.

O escopo consolidado cobre:

- origem `Procedure`, `WebPanel` e `DataProvider`
- destino `Transaction`, somente quando a variavel receptora tiver `ATTCUSTOMTYPE` `bc:<Transaction>` e a transacao existir no inventario local
- regra de extracao `source_bc_load_transaction`
- evidencia `Source BC Load`
- confianca `direct`

## Classificacao

A relacao representa evidencia estrutural de carga de Business Component declarada no `Source`. Ela nao prova sucesso da carga, tabela fisica, parametros de chave, save posterior ou comportamento runtime completo.

## Fora do incremento

- inferir tipo do receptor pelo nome da variavel
- criar relacao quando a variavel nao tiver `ATTCUSTOMTYPE` `bc:*` resolvido localmente
- resolver `.Load(...)` de `SDT`, `ExternalObject`, GAM externo ou outro tipo nao `Transaction`
- resolver tabela fisica, chave, sucesso da carga, save posterior ou comportamento runtime
- interpretar `Grid.Load(...)` ou chamadas sem receptor de variavel GeneXus

## Validacao final

- KB laboratorio: `KBExemplo`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 52778
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 40/40 casos passing
