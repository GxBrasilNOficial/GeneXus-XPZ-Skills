# 24 - KB Intelligence Fase 6 - Status Operacional

## Papel do documento
status operacional

## Nivel de confianca predominante
medio

## Depende de
17-kb-intelligence-fase-6-contrato.md, 18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md, 20-kb-intelligence-fase-6-piloto-investigacao-funcional.md, 21-kb-intelligence-fase-6-checklist-operacional-agente.md, 22-kb-intelligence-fase-6-contrato-functional-trace-basic.md, 23-kb-intelligence-fase-6-exemplos-functional-trace-basic.md, scripts/README-kb-intelligence.md

## Usado por
agentes que precisem consultar o status da primeira entrega operacional da Fase 6 antes do encerramento consolidado

## Objetivo
Registrar o estado operacional da primeira entrega da Fase 6 depois da implementacao e publicacao de `functional-trace-basic`.

## Estado consolidado

Em 2026-04-22, a Fase 6 deixou de ser apenas documental e passou a ter uma consulta auxiliar operacional.

Este documento registra esse marco intermediario. O encerramento operacional consolidado da fase ficou registrado depois em `28-kb-intelligence-fase-6-encerramento.md`.

Artefatos consolidados:

- `17-kb-intelligence-fase-6-contrato.md`: contrato da fase
- `18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md`: roteiro manual de investigacao
- `19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md`: exemplos funcionais baseados em trilha de evidencia
- `20-kb-intelligence-fase-6-piloto-investigacao-funcional.md`: piloto com `FabricaBrasil`
- `21-kb-intelligence-fase-6-checklist-operacional-agente.md`: checklist recorrente para agentes
- `22-kb-intelligence-fase-6-contrato-functional-trace-basic.md`: contrato e estado da consulta auxiliar
- `23-kb-intelligence-fase-6-exemplos-functional-trace-basic.md`: exemplos do comando implementado
- `scripts/kb-intelligence-fabricabrasil.phase6.validation-cases.json`: bateria minima da Fase 6

## Funcionalidade operacional

`functional-trace-basic` esta disponivel em:

- `scripts/Query-KbIntelligenceIndex.py`
- `scripts/Query-KbIntelligenceIndex.ps1`

Ele:

- localiza o objeto principal
- combina dependentes e dependencias diretas
- prioriza objetos resolvidos e locais antes de literais `CustomType`
- monta `technical_trace`
- monta `xml_reading_plan`
- devolve o contrato de resposta da Fase 6
- nao abre XML automaticamente
- nao interpreta regra de negocio
- nao produz conclusao funcional automatica

## Validacoes executadas

Validacoes executadas na implementacao:

- compilacao Python de `Query-KbIntelligenceIndex.py` e `Test-KbIntelligenceQueries.py`
- regressao da Fase 3 com `kb-intelligence-fabricabrasil.phase3.validation-cases.json`
- validacao da Fase 6 com `kb-intelligence-fabricabrasil.phase6.validation-cases.json`

Casos cobertos na bateria da Fase 6:

- `WorkWithForWeb:WorkWithWebAbateOrdem`
- `Procedure:procAjustaCompraGadoIdDeAnimais`
- `API:apiPDV_Integracao`

## Indice canonico

O indice canonico de `FabricaBrasil` foi regenerado por decisao explicita do usuario, usando a rotina oficial:

- `C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite`

Resultado registrado:

- objetos escritos: `14928`
- relacoes escritas: `60494`
- validacao da Fase 5: `64` casos aprovados

## Limites preservados

A Fase 6 continua com estes limites:

- o indice tecnico e trilha de triagem
- o XML oficial continua sendo fonte normativa
- conclusao funcional depende de leitura adicional do XML quando houver semantica GeneXus
- a resposta final deve separar `Evidencia direta`, `Leitura adicional do XML`, `Inferencia forte` e `Hipotese`
- `functional-trace-basic` nao substitui `impact-basic` nem `show-evidence`
- `functional-trace-basic` nao deve ser descrito como prova funcional

## Desfecho posterior

Depois deste status intermediario, a Fase 6 recebeu:

- estabilizacao curta em `25-kb-intelligence-fase-6-estabilizacao-curta.md`
- verificacao pos-filtro em `26-kb-intelligence-fase-6-verificacao-pos-filtro.md`
- primeira resposta funcional controlada em `27-kb-intelligence-fase-6-primeira-resposta-funcional.md`
- encerramento operacional consolidado em `28-kb-intelligence-fase-6-encerramento.md`

Com isso, este documento deve ser lido como fotografia da primeira entrega operacional, nao como estado final aberto da fase.

## Criterio para nao avancar

Nao abrir nova automacao se o problema for apenas uma pergunta funcional isolada. Nesse caso, usar o checklist da Fase 6 e `functional-trace-basic` manualmente.

Nao abrir nova relacao semantica tecnica dentro da Fase 6. Relacao nova pertence a contrato incremental proprio da trilha tecnica, nao ao suporte funcional.
