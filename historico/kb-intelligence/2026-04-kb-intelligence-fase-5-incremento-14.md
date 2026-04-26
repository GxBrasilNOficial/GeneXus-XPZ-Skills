# KB Intelligence Fase 5 - Incremento 14 - KBExemplo

## Papel do documento
registro de incremento

## Data
2026-04-22

## Escopo

O decimo quarto incremento da Fase 5 adicionou resolucao semantica controlada de `Procedure`, `WebPanel` e `DataProvider` para `Transaction` a partir de chamadas `.Insert()` e `.Update()` em variaveis Business Component simples no `Source` efetivo.

O escopo consolidado cobre:

- origem `Procedure`, `WebPanel` e `DataProvider`
- destino `Transaction`, somente quando a variavel receptora tiver `ATTCUSTOMTYPE` `bc:<Transaction>` e a transacao existir no inventario local
- variaveis sem `AttCollection=True`
- regras de extracao `source_simple_bc_insert_transaction` e `source_simple_bc_update_transaction`
- evidencias `Source Simple BC Insert` e `Source Simple BC Update`
- confianca `direct`

## Classificacao

A relacao representa evidencia estrutural de insercao ou atualizacao via Business Component simples declarada no `Source`. Ela nao prova sucesso da operacao, commit, rollback, mensagens de erro ou comportamento runtime completo.

## Fora do incremento

- variaveis com `AttCollection=True`
- inferir tipo do receptor pelo nome da variavel
- criar relacao quando a variavel nao tiver `ATTCUSTOMTYPE` `bc:*` resolvido localmente
- resolver `.Insert()` ou `.Update()` de `ExternalObject`, GAM externo ou outro tipo nao `Transaction`
- inferir `.Load(...)`, `.Save()`, `.Delete()`, `.Check()`, `.Success()`, `.Fail()`, commit, rollback ou mensagens
- provar sucesso da insercao/atualizacao ou comportamento runtime

## Validacao final

- KB laboratorio: `KBExemplo`
- indice usado para validacao: SQLite derivado regenerado em `Temp`
- objetos escritos: 14928
- relacoes escritas: 53331
- relacoes da regra `source_simple_bc_insert_transaction`: 1
- relacoes da regra `source_simple_bc_update_transaction`: 2
- Fase 2: 40/40 casos passing
- Fase 3: 4/4 casos passing
- Fase 4: 6/6 casos passing
- Fase 5: 52/52 casos passing
