# Validacao KB Intelligence Fase 1 - KBExemplo

## Papel do documento
historico de validacao

## Nivel de confianca predominante
medio

## Data da rodada
2026-04-20

## Repositorio metodologico
`C:\Dev\Knowledge\GeneXus-XPZ-Skills`

## Pasta paralela usada como laboratorio
`C:\KB\KBExemplo`

## Fonte XML
`C:\KB\KBExemplo\ObjetosDaKbEmXml`

## Objetivo
Registrar as rodadas de validacao operacional da Fase 1 do KB Intelligence contra uma pasta paralela real, usando apenas `Procedure` e `WebPanel` como escopo inicial.

## Comandos executados

Geracao do indice com casos de validacao:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-phase1-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-kbexemplo.phase1.validation-cases.json" `
  -FailOnValidationFailure
```

Consulta de evidencia do caso principal:

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -Query show-evidence `
  -SourceType WebPanel `
  -SourceName wpRelatoriosDeMovimentosDeVolumes `
  -TargetType Procedure `
  -TargetName procPlanilhaVolumeMovimento
```

Teste negativo controlado de falha de validacao:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\KB\KBExemplo\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-forced-failure.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-forced-failure-validation.json" `
  -ValidationCasesPath ".\Temp\kb-intelligence-forced-failure-cases.json" `
  -FailOnValidationFailure
```

## Resultado da geracao

- `Procedure` lidas: 2302
- `WebPanel` lidos: 1198
- objetos gravados no SQLite: 3500
- relacoes gravadas: 19364
- artefato principal: `.\\Temp\\kb-intelligence-phase1.sqlite`
- relatorio de validacao: `.\\Temp\\kb-intelligence-phase1-validation.json`

Os artefatos em `Temp` sao derivados e nao foram versionados.

## Casos de validacao

A rodada inicial continha 5 casos. Em seguida, a validacao foi ampliada para 15 casos reais escolhidos no acervo da KB, mantendo o mesmo recorte de Fase 1 e sem incluir novos tipos de objeto.

### Caso 1 - WebPanel chamando Procedure por `.Call(...)`

- origem: `WebPanel:wpRelatoriosDeMovimentosDeVolumes`
- destino: `Procedure:procPlanilhaVolumeMovimento`
- regra esperada: `procedure_dot_call`
- expectativa: criar relacao direta
- resultado: `passed`

Evidencia consultada:

- arquivo: `WebPanel/wpRelatoriosDeMovimentosDeVolumes.xml`
- linha: 131
- papel: `Source efetivo`
- regra: `procedure_dot_call`
- trecho: `procPlanilhaVolumeMovimento.Call(...)`

Este caso evita repetir o falso negativo observado no experimento anterior em `C:\KB\KBExemplo\Mapeamento`.

### Caso 2 - Procedure chamando Procedure por chamada direta

- origem: `Procedure:PreenchXmlNFE`
- destino: `Procedure:procLeParteDeStringXml`
- regra esperada: `procedure_direct_call`
- expectativa: criar relacao direta
- resultado: `passed`

### Caso 2b - Procedure com diferenca de maiusculas/minusculas

- origem: `Procedure:PreenchXmlNFE`
- destino: `Procedure:ProcCodigodeBarraCode128`
- regra esperada: `procedure_direct_call`
- expectativa: resolver chamada `ProcCodigodeBarraCode128(...)` para o nome canonico do arquivo
- resultado: `passed`

### Caso 3 - Comentario nao deve gerar relacao direta

- origem: `Procedure:PreenchXmlNFE`
- destino: `Procedure:procCodigoDeBarrasDobson2of5`
- regra observada: `procedure_direct_call`
- expectativa: nao criar relacao direta quando a referencia aparece apenas em comentario
- resultado: `passed`

### Caso 4 - Layout visual nao deve gerar relacao direta

- origem: `WebPanel:promptCompradorDeGado`
- destino: `Procedure:procEmpresaLiberadaProUsuario`
- regra observada: `procedure_direct_call`
- expectativa: nao criar relacao direta a partir de `Source` visual/layout
- resultado: `passed`

### Casos 5 a 15 - Ampliacao com relacoes reais

A ampliacao cobriu:

- chamadas diretas de `Procedure` em expressoes e atribuicoes
- chamadas diretas aninhadas
- chamadas por `.Call(...)` com nomes curtos e longos
- links de `Procedure` para `WebPanel` por `.Link(...)`
- chamadas diretas de `Procedure` dentro de `WebPanel`

Todos os 15 casos passaram com `-FailOnValidationFailure`.

## Gate negativo

Foi executado um caso de falha proposital em `Temp`, apontando para `Procedure:ObjetoInexistenteParaFalhar`.

Resultado esperado e observado:

- caso marcado como `failed`
- comando retornou `EXIT=2`

Isso valida o uso de `-FailOnValidationFailure` como gate operacional de rodada oficial.

## Teste de uso real por outro agente

Foi executado um teste conversacional em outra conversa, pedindo que o agente consultasse o indice antes de abrir XMLs para entender `WebPanel:wpRelatoriosDeMovimentosDeVolumes`.

Resultado observado:

- o agente seguiu parcialmente o fluxo esperado de procurar um indice antes de abrir XML
- como ainda nao havia local canonico operacional em `KbIntelligence`, ele encontrou e usou artefatos antigos em `Mapeamento`
- o agente misturou achados do experimento antigo com validacao direta por XML
- a resposta confirmou a utilidade operacional do fluxo, mas tambem confirmou o risco de descoberta errada quando `Mapeamento` permanece visivel na raiz da pasta paralela

Decisao decorrente:

- o local padrao do SQLite passa a ser `KbIntelligence\kb-intelligence.sqlite` dentro da pasta paralela da KB
- experimentos antigos como `Mapeamento` devem ir para `ArquivoMorto\Mapeamento` quando o usuario autorizar a movimentacao
- o `AGENTS.md` da pasta paralela deve orientar agentes a ignorar `ArquivoMorto` ou tratar seu conteudo como nao confiavel

## Arquivamento do experimento anterior

Em 2026-04-21, apos autorizacao do usuario, o experimento anterior foi movido na pasta paralela real:

```text
C:\KB\KBExemplo\Mapeamento
```

para:

```text
C:\KB\KBExemplo\ArquivoMorto\Mapeamento
```

Tambem foram ajustados `README.md` e `AGENTS.md` da pasta paralela para registrar que `ArquivoMorto` deve ser ignorado por agentes ou tratado como nao confiavel, salvo pedido explicito de analise historica.

## Fechamento do local canonico

Em 2026-04-21, foi gerado e validado o indice canonico da Fase 1 na pasta paralela real:

```text
C:\KB\KBExemplo\KbIntelligence\kb-intelligence.sqlite
```

Tambem foi gerado o relatorio derivado:

```text
C:\KB\KBExemplo\KbIntelligence\kb-intelligence-validation.json
```

A geracao usou `ObjetosDaKbEmXml` como fonte normativa e os 15 casos reais de `scripts\kb-intelligence-kbexemplo.phase1.validation-cases.json`, com `-FailOnValidationFailure`.

Resultado da rodada canonica:

- `Procedure` lidas: 2302
- `WebPanel` lidos: 1198
- objetos gravados no SQLite: 3500
- relacoes gravadas: 19364
- 15 casos de validacao: `passed`

Consultas reais executadas contra o indice canonico:

- `object-info` para `WebPanel:wpRelatoriosDeMovimentosDeVolumes`: objeto localizado em `WebPanel/wpRelatoriosDeMovimentosDeVolumes.xml`, com 9 relacoes de saida
- `what-uses` para `WebPanel:wpRelatoriosDeMovimentosDeVolumes`: 9 relacoes diretas retornadas
- `who-uses` para `Procedure:procPlanilhaVolumeMovimento`: 2 usos diretos retornados
- `show-evidence` para `WebPanel:wpRelatoriosDeMovimentosDeVolumes` -> `Procedure:procPlanilhaVolumeMovimento`: evidencia direta na linha 131 por `procedure_dot_call`

Foi criado `C:\KB\KBExemplo\KbIntelligence\README.md` para orientar agentes a tratar o SQLite como derivado e regeneravel, mantendo `ObjetosDaKbEmXml` como fonte normativa.

A Fase 2 nao foi iniciada nesta rodada.

## Limites desta validacao

- nao cobre `Transaction`
- nao cobre `WorkWithForWeb`
- nao cobre `DataProvider`
- nao cobre relacoes por `for each`
- nao cobre `.Load(...)`
- nao prova impacto funcional ou runtime
- nao substitui leitura do XML quando a mudanca exigir revisao semantica

## Conclusao

A Fase 1 tem uma implementacao operacional validada para o recorte `Procedure` e `WebPanel`, com SQLite derivado, evidencia rastreavel, consulta por agente, gate de validacao e local canonico em `KbIntelligence`.

Antes de expandir novos tipos de objeto, deve haver decisao explicita de abertura da Fase 2.
