# KB Intelligence Fase 5 - Incremento 12 - KBExemplo

## Papel do documento
registro de incremento

## Data
2026-04-22

## Escopo

O decimo segundo incremento da Fase 5 adicionou resolucao semantica controlada de `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de chamadas `.Delete()` em variaveis Business Component no `Source` efetivo.

O escopo consolidado cobre:

- origem `Procedure`, `WebPanel` e `DataProvider`
- destino `Transaction`, somente quando a variavel receptora tiver `ATTCUSTOMTYPE` `bc:<Transaction>` e a transacao existir no inventario local
- regra de extracao `source_bc_delete_transaction`
- evidencia `Source BC Delete`
- confianca `direct`

## Classificacao

A relacao representa evidencia estrutural de exclusao via Business Component declarada no `Source`. Ela nao prova sucesso da exclusao, commit, rollback, validacoes disparadas, mensagens de erro ou comportamento runtime completo.

## Fora do incremento

- inferir tipo do receptor pelo nome da variavel
- criar relacao quando a variavel nao tiver `ATTCUSTOMTYPE` `bc:*` resolvido localmente
- resolver `.Delete()` de `File`, `Directory`, `ExternalObject`, documentos, GAM externo ou outro tipo nao `Transaction`
- inferir `.Load(...)`, `.Save()`, `.Success()`, `.Fail()`, commit, rollback ou mensagens
- provar sucesso da exclusao ou comportamento runtime

## Validacao final

- KB laboratorio: `KBExemplo`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 53202 na validacao isolada do incremento 12; 53328 na validacao acumulada com o incremento 13
- relacoes da regra `source_bc_delete_transaction`: 22
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 46/46 casos passing
