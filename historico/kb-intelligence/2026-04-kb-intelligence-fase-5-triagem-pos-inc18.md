# KB Intelligence Fase 5 - Triagem Pos Incremento 18

## Papel do documento
registro de triagem

## Data
2026-04-22

## Objetivo

Registrar a decisao metodologica tomada apos o incremento 18 da Fase 5, quando o eixo incremental de `ATTCUSTOMTYPE` passou a mostrar baixo ganho marginal para novos incrementos conservadores.

## Contexto

A Fase 5 chegou ao incremento 18 com:

- resolucao literal e resolvida de `ATTCUSTOMTYPE`
- resolucao para `SDT`, `Domain` e `ExternalObject` quando o alvo existe no inventario local
- ampliacao controlada de origem para `API`, `DataSelector`, `Domain` e `SDT` top-level
- cobertura de BC simples por `.Load(...)`, `.Save()`, `.Delete()`, `.Check()`, `.Insert()` e `.Update()`

Nesse ponto, a pergunta operacional deixou de ser "qual proximo incremento pequeno ainda e seguro?" e passou a ser "ainda existe ganho real sem degradar a qualidade semantica do indice?".

## Triagem executada

Foram reavaliadas tres frentes que ainda pareciam plausiveis:

- `Success()` em variavel `bc:*`
- `Fail()` em variavel `bc:*`
- `GetMessages()` em variavel `bc:*`

A medicao foi feita sobre `Procedure`, `WebPanel` e `DataProvider`, resolvendo a variavel por `ATTCUSTOMTYPE` `bc:<Transaction>` exatamente com o mesmo criterio local ja usado pelos incrementos fortes de BC.

## Resultado medido

- `Success()`: `371` ocorrencias, `280` pares unicos `origem -> Transaction`
- `Fail()`: `48` ocorrencias, `43` pares unicos `origem -> Transaction`
- `GetMessages()`: `419` ocorrencias, `306` pares unicos `origem -> Transaction`

Ao comparar esses pares com a cobertura forte ja existente por `.Load(...)`, `.Save()`, `.Delete()`, `.Check()`, `.Insert()` e `.Update()`, o delta liquido foi:

- `Success()`: `0` pares novos
- `Fail()`: `0` pares novos
- `GetMessages()`: `0` pares novos

## Interpretacao

Esses tres sinais continuam semanticamente mais fracos do que as chamadas diretas de operacao em BC e, no acervo atual da KB `KBExemplo`, nao acrescentam novas arestas tecnicas ao grafo.

Na pratica:

- abririam regras novas
- exigiriam documentacao, testes e manutencao
- aumentariam o ruido metodologico
- sem ganho liquido de cobertura de relacoes `origem -> Transaction`

## Decisao

Nao aprovar incremento 19 nesse eixo.

A subtrilha incremental atual da Fase 5 fica consolidada apos o incremento 18, e qualquer continuacao futura deve atender pelo menos um destes criterios:

- produzir pares novos nao cobertos por regras mais fortes ja existentes
- trazer evidencia estrutural nova, nao apenas indicio redundante de estado
- justificar contrato proprio de evidencia fraca com valor operacional claro

## Observacao complementar

Na mesma rodada de triagem, `Attribute`, `PackagedModule` e `Stencil` continuaram sem novos alvos resolviveis por `ATTCUSTOMTYPE` com a regra conservadora hoje adotada. `ext:*` continua util apenas como literal de propriedade, nao como resolucao segura para objeto local.
