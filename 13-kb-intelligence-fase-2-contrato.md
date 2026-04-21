# 13 - KB Intelligence Fase 2 - Contrato Inicial

## Papel do documento
contrato operacional

## Nivel de confianca predominante
baixo a medio

## Depende de
11-plano-kb-intelligence-incremental.md, 12-kb-intelligence-fase-1-contrato.md, scripts/README-kb-intelligence.md

## Usado por
agentes que forem ampliar o indice tecnico reutilizavel sem perder o recorte validado da Fase 1

## Objetivo
Definir os incrementos iniciais da Fase 2 do KB Intelligence, mantendo a ampliacao pequena, auditavel e validada em casos reais.

## Alvos aprovados

O primeiro alvo da Fase 2 e `DataProvider` como nova origem de relacoes.

O segundo alvo da Fase 2 e `DataProvider` como destino de chamada direta.

O terceiro alvo da Fase 2 e action de `WorkWithForWeb` com atributo `gxobject` resolvido para `Procedure` ou `WebPanel`.

O quarto alvo da Fase 2 e propriedade `ATTCUSTOMTYPE` como alvo literal `CustomType:<valor>`.

O quinto alvo da Fase 2 e vinculacao explicita de `WorkWithForWeb` para `Transaction`.

O sexto alvo da Fase 2 e link explicito de `WorkWithForWeb` para `WebPanel`.

Destinos do primeiro incremento continuam limitados a:

- `Procedure`
- `WebPanel`

Origem do segundo incremento:

- `Procedure`
- `WebPanel`
- `DataProvider`

Origem do terceiro incremento:

- `WorkWithForWeb`

Origem do quarto incremento:

- objetos ja coletados pelo indice

Origem do quinto incremento:

- `WorkWithForWeb`

Origem do sexto incremento:

- `WorkWithForWeb`

## Padroes aceitos

O incremento reaproveita as regras ja validadas na Fase 1:

- `procedure_direct_call`
- `procedure_dot_call`
- `webpanel_dot_link`

O segundo incremento adiciona:

- `dataprovider_direct_call`

O terceiro incremento adiciona:

- `workwith_action_gxobject`

O quarto incremento adiciona:

- `attcustomtype_property`

O quinto incremento adiciona:

- `workwith_transaction_binding`

O sexto incremento adiciona:

- `workwith_link_webpanel`

Toda relacao deve vir de evidencia direta nomeada, com arquivo, linha, snippet, regra e confianca. Em `Source` efetivo, a evidencia deve continuar classificada como `Source efetivo`; em actions de `WorkWithForWeb`, como `WorkWith action`; em vinculacoes de `WorkWithForWeb` para `Transaction`, como `WorkWith transaction`; em links explicitos de `WorkWithForWeb` para `WebPanel`, como `WorkWith link`; em `ATTCUSTOMTYPE`, como `Property ATTCUSTOMTYPE`.

## Fora do incremento

- semantica completa de `Transaction`
- `WorkWithForWeb` alem de actions `gxobject` resolvidas, vinculacoes explicitas de `Transaction` e links explicitos de `WebPanel`
- `for each`
- `.Load(...)`
- resolucao semantica de `CustomType` para `SDT`, `Domain` ou outro tipo GeneXus
- chamadas dinamicas
- inferencia por layout visual
- comentario como chamada efetiva

## Gate minimo

Antes de considerar este incremento pronto:

- os 15 casos reais da Fase 1 devem continuar passando
- deve existir bateria propria da Fase 2 para `DataProvider`
- a bateria deve incluir casos positivos de chamada de `Procedure`
- a bateria deve incluir casos positivos de `.Link(...)` para `WebPanel`
- a bateria deve incluir casos negativos de comentarios em `DataProvider`
- a bateria deve incluir casos positivos de chamada direta para `DataProvider`
- a bateria deve incluir caso negativo de comentario com chamada de `DataProvider`
- a bateria deve incluir casos positivos de action de `WorkWithForWeb` para `Procedure` e `WebPanel`
- a bateria deve incluir caso negativo para action sem alvo resolvido no recorte aprovado
- a bateria deve incluir casos positivos de `ATTCUSTOMTYPE` em `Transaction` e `Procedure`
- a bateria deve incluir caso negativo de `CustomType` inexistente
- a bateria deve incluir casos positivos de vinculacao explicita `WorkWithForWeb` -> `Transaction`
- a bateria deve incluir caso negativo de `Transaction` inexistente
- a bateria deve incluir casos positivos de link explicito `WorkWithForWeb` -> `WebPanel`
- a bateria deve incluir caso de canonizacao de nome de `WebPanel`
- a bateria deve incluir caso negativo de `WebPanel` inexistente
- a validacao deve ser executada contra `FabricaBrasil` com `-FailOnValidationFailure`

## Decisoes adiaveis

As decisoes abaixo nao bloqueiam os incrementos ja aprovados:

- nome final da skill futura
- politica de snapshots pequenos versionados
- estrategia definitiva para linha exata em XML com `CDATA`
- proximo alvo da Fase 2
- resolucao semantica futura de `CustomType:<valor>` para `SDT`, `Domain` ou outro tipo GeneXus

O proximo alvo da Fase 2 so deve ser escolhido depois que os incrementos ja aprovados estiverem validados e registrados.
