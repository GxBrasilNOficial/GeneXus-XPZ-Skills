# Prompt de Retomada - KB Intelligence Fase 6

Use este prompt para abrir uma nova conversa com contexto limpo.

```text
Estamos em C:\Dev\Knowledge\GeneXus-XPZ-Skills.

Antes de agir, leia:
- README.md
- AGENTS.md
- 11-plano-kb-intelligence-incremental.md
- 17-kb-intelligence-fase-6-contrato.md
- 18-kb-intelligence-fase-6-roteiro-investigacao-funcional.md
- 19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md
- 21-kb-intelligence-fase-6-checklist-operacional-agente.md
- 22-kb-intelligence-fase-6-contrato-functional-trace-basic.md
- 24-kb-intelligence-fase-6-status-operacional.md
- 25-kb-intelligence-fase-6-estabilizacao-curta.md
- 26-kb-intelligence-fase-6-verificacao-pos-filtro.md
- 27-kb-intelligence-fase-6-primeira-resposta-funcional.md
- 08-guia-para-agente-gpt.md

Contexto operacional:
- A Fase 5 foi consolidada e encerrada operacionalmente no eixo incremental curto ate o incremento 18.
- A Fase 6 esta operacional, nao apenas documental.
- O indice tecnico continua sendo trilha de triagem.
- O XML oficial em ObjetosDaKbEmXml continua sendo a fonte normativa.
- A resposta funcional deve separar explicitamente:
  - Evidencia direta
  - Leitura adicional do XML
  - Inferencia forte
  - Hipotese
- Nao alterar o indice canonico sem pedido explicito:
  C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite
- Usar indices temporarios em:
  C:\KB\KBExemplo\Temp\
- Antes de agir na primeira vez em C:\KB\KBExemplo, avisar a troca de contexto e ler README.md e AGENTS.md de la.
- C:\KB\KBExemplo pode ter logs/ pre-existente; nao tocar sem pedido explicito.

Estado versionado:
- O indice canonico de KBExemplo foi regenerado por decisao explicita do usuario e validado pela rotina oficial.
- functional-trace-basic foi implementado em scripts/Query-KbIntelligenceIndex.py e scripts/Query-KbIntelligenceIndex.ps1.
- A bateria minima da Fase 6 esta em scripts/kb-intelligence-kbexemplo.phase6.validation-cases.json.
- O filtro conservador de literais CustomType redundantes ja foi implementado.
- A primeira resposta funcional controlada foi registrada em 27-kb-intelligence-fase-6-primeira-resposta-funcional.md usando API:apiPDV_Integracao.

Commits relevantes ja enviados para origin/main:
- 50c3ee7 Add KB Intelligence phase 6 functional trace
- ef5cde1 Add phase 6 functional trace examples
- b6ded1b Add phase 6 operational status
- fb1c857 Document phase 6 stabilization findings
- 6dd4615 Filter redundant custom types in functional trace
- 4def9bf Document phase 6 post-filter verification
- 70b75e3 Add phase 6 functional answer example

O que falta para encerrar a Fase 6:
1. Criar um segundo exemplo funcional com Transaction + WorkWithWeb, validando a terminologia local:
   - via edicao web
   - via BC
2. Criar um terceiro exemplo curto de impacto funcional ou suspeita de fluxo.
3. Criar o documento final de encerramento da Fase 6, provavelmente:
   28-kb-intelligence-fase-6-encerramento.md
4. Atualizar 11-plano-kb-intelligence-incremental.md declarando a Fase 6 encerrada operacionalmente.
5. Decidir se abre ou nao uma Fase 7; recomendacao atual: nao abrir ainda, apenas listar possibilidades futuras.

Objetivo da nova conversa:
Retomar exatamente desse ponto e executar a proxima entrega util para encerrar a Fase 6, com seguranca documental e sem inflar escopo.

Primeira entrega sugerida:
Criar o segundo exemplo funcional da Fase 6 com Transaction + WorkWithWeb, usando functional-trace-basic apenas como triagem e o XML oficial como fonte normativa.
```
