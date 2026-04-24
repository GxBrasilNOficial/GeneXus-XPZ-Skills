# 26 - KB Intelligence Fase 6 - Verificacao Pos-Filtro

## Papel do documento
registro de verificacao operacional

## Nivel de confianca predominante
baixo a medio

## Depende de
22-kb-intelligence-fase-6-contrato-functional-trace-basic.md, historico/kb-intelligence/25-kb-intelligence-fase-6-estabilizacao-curta.md

## Usado por
agentes que forem decidir se a consulta `functional-trace-basic` ja esta estavel o bastante para uso assistido na Fase 6

## Objetivo
Registrar a verificacao manual executada depois do filtro conservador de literais `CustomType` redundantes em `functional-trace-basic`.

O filtro nao altera `impact-basic` nem `show-evidence`. Ele afeta apenas a consulta auxiliar da Fase 6 e apenas quando ha literal `CustomType` redundante com relacao resolvida equivalente no mesmo arquivo, direcao, linha e payload.

## Evidencia direta

### `API:apiPDV_Integracao`

Resultado observado:

- `technical_trace_shown`: 18
- `suppressed_redundant_custom_type_relations`: 2
- relacoes resolvidas para `SDT:sdtProdutoDadosBasicos` e `SDT:sdtTributacaoDadosBasicosSelecao` permaneceram visiveis
- literais primitivos e externos continuaram visiveis quando nao havia relacao resolvida local equivalente

Leitura operacional:

- o filtro removeu duplicidade de `CustomType` local sem esconder a dependencia resolvida
- a trilha continuou util para abrir os XMLs normativos depois da triagem

### `WebPanel:wpRelatoriosDeMovimentosDeVolumes`

Resultado observado:

- `technical_trace_shown`: 13
- `suppressed_redundant_custom_type_relations`: 0
- relacoes para procedures auxiliares permaneceram visiveis
- literais `bas:*` e `ext:*` permaneceram visiveis porque nao havia objeto local resolvido equivalente

Leitura operacional:

- o filtro nao reduziu evidencia quando nao havia duplicidade local segura
- a consulta preservou rastreabilidade para tipos externos ou primitivos

### `Procedure:procAnimaisContagemDeUmPeriodo`

Resultado observado:

- `technical_trace_shown`: 2
- `suppressed_redundant_custom_type_relations`: 0
- dependente direto: `Procedure:procRelatorioAbatePorOrdem`
- dependencia direta: `Table:Animal`

Leitura operacional:

- a trilha permaneceu curta
- o filtro nao interferiu em relacoes de chamada ou tabela

## Leitura adicional do XML

A consulta continua sendo triagem. Para resposta funcional, o agente ainda deve abrir o XML oficial dos objetos apontados e separar:

- evidencia direta
- leitura adicional do XML
- inferencia forte
- hipotese

## Inferencia forte

O comportamento pos-filtro e compativel com o contrato da Fase 6:

- reduz ruido operacional em casos de `CustomType` local duplicado
- preserva relacoes resolvidas
- preserva literais sem equivalente local
- nao cria resumo funcional automatico
- nao altera schema nem extracao

## Hipotese

Se aparecerem novos casos reais com excesso de ruido, a proxima evolucao provavel nao deve ser uma nova familia de extracao. Deve ser um parametro operacional conservador, por exemplo:

- incluir ou omitir incoming
- filtrar por tipo de alvo
- filtrar por familia de relacao
- mostrar literais redundantes sob demanda

## Decisao recomendada

Manter `functional-trace-basic` como entrega operacional curta da Fase 6 e nao ampliar codigo ate haver pergunta funcional real que demonstre lacuna concreta.

Proximo uso recomendado:

- escolher uma pergunta funcional real da KB
- rodar `functional-trace-basic` apenas para triagem
- abrir XML oficial dos objetos apontados
- responder separando evidencia direta, leitura adicional do XML, inferencia forte e hipotese
