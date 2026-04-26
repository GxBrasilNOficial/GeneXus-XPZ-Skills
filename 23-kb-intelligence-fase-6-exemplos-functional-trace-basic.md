# 23 - KB Intelligence Fase 6 - Exemplos com `functional-trace-basic`

## Papel do documento
exemplos operacionais de consulta

## Nivel de confianca predominante
medio

## Depende de
17-kb-intelligence-fase-6-contrato.md, 21-kb-intelligence-fase-6-checklist-operacional-agente.md, 22-kb-intelligence-fase-6-contrato-functional-trace-basic.md, scripts/README-kb-intelligence.md

## Usado por
agentes que forem usar `functional-trace-basic` como atalho de triagem funcional antes de abrir XML oficial

## Objetivo
Mostrar exemplos curtos de uso do comando `functional-trace-basic` depois da implementacao da Fase 6.

Estes exemplos nao substituem `19-kb-intelligence-fase-6-exemplos-investigacao-funcional.md`. Eles apenas mostram como iniciar a mesma trilha usando o novo comando.

## Regra comum

Mesmo quando `functional-trace-basic` retornar uma trilha boa, a resposta funcional final ainda deve separar:

- `Evidencia direta`
- `Leitura adicional do XML`
- `Inferencia forte`
- `Hipotese`

O comando nao abre XML automaticamente e nao prova comportamento runtime completo.

## Exemplo 1 - `WorkWithForWeb:WorkWithWebAbateOrdem`

### Pergunta

Qual trilha inicial devo abrir para investigar regras ligadas a ordem de abate?

### Comando

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query functional-trace-basic `
  -ObjectType WorkWithForWeb `
  -ObjectName WorkWithWebAbateOrdem `
  -Limit 80 `
  -Format text
```

### Resultado esperado da triagem

- objeto principal: `WorkWithForWeb:WorkWithWebAbateOrdem`
- XML principal a abrir: `WorkWithForWeb/WorkWithWebAbateOrdem.xml`
- relacoes esperadas na trilha:
  - `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Transaction:AbateOrdem`
  - `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procLeEmpresaSessao`

### Uso correto

Usar o retorno para abrir o XML do `WorkWithForWeb` e revisar o trecho da vinculacao da `Transaction`, as condicoes e as actions relevantes.

### Limite

Nao concluir o fluxo funcional completo da tela apenas com base no comando.

## Exemplo 2 - `Procedure:procAjustaCompraGadoIdDeAnimais`

### Pergunta

Ha indício tecnico de manipulacao direta de `Transaction:Animal`?

### Comando

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query functional-trace-basic `
  -ObjectType Procedure `
  -ObjectName procAjustaCompraGadoIdDeAnimais `
  -Limit 80 `
  -Format text
```

### Resultado esperado da triagem

- objeto principal: `Procedure:procAjustaCompraGadoIdDeAnimais`
- XML principal a abrir: `Procedure/procAjustaCompraGadoIdDeAnimais.xml`
- relacao de entrada esperada:
  - `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procAjustaCompraGadoIdDeAnimais`
- relacoes de saida esperadas:
  - `Procedure:procAjustaCompraGadoIdDeAnimais` -> `Transaction:Animal` por `source_bc_load_transaction`
  - `Procedure:procAjustaCompraGadoIdDeAnimais` -> `Transaction:Animal` por `source_bc_save_transaction`

### Uso correto

Usar a trilha para abrir o `Source` da procedure nos pontos de `&animal.Load(...)` e `&animal.Save()`, depois revisar o bloco ao redor para diferenciar leitura, alteracao, persistencia e mensagens.

### Limite

O comando mostra indício técnico forte de uso de BC, mas nao fecha sozinho se a procedure consulta, altera, persiste ou aborta em todos os cenarios.

## Exemplo 3 - `API:apiPDV_Integracao`

### Pergunta

Qual tipo local devo abrir primeiro para entender parte do contrato tecnico da API?

### Comando

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -Query functional-trace-basic `
  -ObjectType API `
  -ObjectName apiPDV_Integracao `
  -Limit 20 `
  -Format text
```

### Resultado esperado da triagem

- objeto principal: `API:apiPDV_Integracao`
- XML principal a abrir: `API/apiPDV_Integracao.xml`
- relacao resolvida esperada:
  - `API:apiPDV_Integracao` -> `SDT:sdtProdutoDadosBasicos`

### Uso correto

Usar o retorno para abrir o XML da `API` e depois o XML de `SDT:sdtProdutoDadosBasicos` quando a pergunta for sobre o formato tecnico de dados de produto.

### Limite

O comando nao prova se o `SDT` e payload principal, retorno parcial ou estrutura auxiliar. Essa conclusao depende da leitura do XML oficial da `API` e do `SDT`.

## Validacao associada

Os exemplos acima sao cobertos por:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase6.validation-cases.json" `
  -ValidationReportPath "C:\KB\KBExemplo\KbIntelligence\kb-intelligence-phase6-validation.json" `
  -FailOnValidationFailure
```

## Criterio de sucesso

O uso esta correto quando o agente consegue reduzir a trilha inicial e, ainda assim, preserva a classificacao final da Fase 6 sem transformar indice em prova funcional completa.
