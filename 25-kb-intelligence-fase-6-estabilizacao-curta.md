# 25 - KB Intelligence Fase 6 - Estabilizacao Curta

## Papel do documento
registro de estabilizacao

## Nivel de confianca predominante
baixo a medio

## Depende de
22-kb-intelligence-fase-6-contrato-functional-trace-basic.md, 23-kb-intelligence-fase-6-exemplos-functional-trace-basic.md, 24-kb-intelligence-fase-6-status-operacional.md

## Usado por
agentes que forem decidir se a consulta `functional-trace-basic` precisa de ajuste fino antes de novas ampliacoes

## Objetivo
Registrar uma rodada curta de estabilizacao do comando `functional-trace-basic` em objetos reais adicionais.

Esta rodada nao alterou codigo. Ela apenas mediu comportamento e ruido operacional.

## Objetos testados

- `WebPanel:wpRelatoriosDeMovimentosDeVolumes`
- `DataSelector:dsRelatoriosDeTitulosViaLancamentos`
- `Procedure:procAnimaisContagemDeUmPeriodo`

## Resultado observado

### `WebPanel:wpRelatoriosDeMovimentosDeVolumes`

O comando retornou uma trilha util:

- objeto principal localizado em `WebPanel/wpRelatoriosDeMovimentosDeVolumes.xml`
- relacoes diretas de `Source efetivo` para procedures auxiliares
- relacao direta para `Procedure:procPlanilhaVolumeMovimento`
- plano de leitura apontando para o XML principal

O resultado tambem mostrou literais `CustomType` primitivos no fim da trilha, como `bas:VarChar`, `bas:GUID` e `ext:WebSession`.

### `DataSelector:dsRelatoriosDeTitulosViaLancamentos`

O comando retornou a relacao mais relevante primeiro:

- `DataSelector:dsRelatoriosDeTitulosViaLancamentos` -> `SDT:sdtTituloParametros`
- regra: `attcustomtype_resolved_object`

Depois retornou tambem o literal correspondente:

- `CustomType:sdt:sdtTituloParametros`
- regra: `attcustomtype_property`

### `Procedure:procAnimaisContagemDeUmPeriodo`

O comando retornou uma trilha curta e util:

- dependente direto: `Procedure:procRelatorioAbatePorOrdem`
- dependencia direta: `Table:Animal`
- regra para a tabela: `source_for_each_explicit_table`
- plano de leitura com XML da procedure principal e XML do chamador direto

## Achado de estabilizacao

`functional-trace-basic` ja prioriza objetos resolvidos e locais antes de literais `CustomType`, mas ainda inclui o literal correspondente quando ele existe junto com a relacao resolvida.

Esse comportamento preserva rastreabilidade completa, mas pode gerar ruido em respostas funcionais curtas.

## Decisao recomendada

Antes de adicionar novos parametros, avaliar um ajuste pequeno:

- manter `show-evidence` e `impact-basic` completos
- em `functional-trace-basic`, ocultar por padrao literais `CustomType:*` quando houver relacao resolvida equivalente para o mesmo `source_file`, linha e valor semantico
- expor futuramente uma opcao para incluir literais, se necessario

## Nao fazer ainda

- nao alterar schema
- nao ampliar extracao
- nao abrir XML automaticamente
- nao criar resumo funcional narrativo
- nao navegar cadeia profunda automaticamente

## Proximo gate

Se o objetivo for melhorar a qualidade da triagem curta, implementar filtro conservador de literais redundantes em `functional-trace-basic` e validar de novo:

- Fase 3 para regressao
- Fase 6 para comportamento do novo comando
- uma consulta manual em `DataSelector:dsRelatoriosDeTitulosViaLancamentos` para confirmar que `SDT:sdtTituloParametros` permanece visivel
