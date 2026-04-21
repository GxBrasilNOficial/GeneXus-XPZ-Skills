# Validacao KB Intelligence Fase 1 - FabricaBrasil

## Papel do documento
historico de validacao

## Nivel de confianca predominante
medio

## Data da rodada
2026-04-20

## Repositorio metodologico
`C:\Dev\Knowledge\GeneXus-XPZ-Skills`

## Pasta paralela usada como laboratorio
`C:\Dev\Prod\Gx_FabricaBrasil`

## Fonte XML
`C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml`

## Objetivo
Registrar a primeira validacao operacional da Fase 1 do KB Intelligence contra uma pasta paralela real, usando apenas `Procedure` e `WebPanel` como escopo inicial.

## Comandos executados

Geracao do indice com casos de validacao:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-phase1-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase1.validation-cases.json" `
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
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-forced-failure.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-forced-failure-validation.json" `
  -ValidationCasesPath ".\Temp\kb-intelligence-forced-failure-cases.json" `
  -FailOnValidationFailure
```

## Resultado da geracao

- `Procedure` lidas: 2302
- `WebPanel` lidos: 1198
- objetos gravados no SQLite: 3500
- relacoes gravadas: 19229
- artefato principal: `.\\Temp\\kb-intelligence-phase1.sqlite`
- relatorio de validacao: `.\\Temp\\kb-intelligence-phase1-validation.json`

Os artefatos em `Temp` sao derivados e nao foram versionados.

## Casos de validacao

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

Este caso evita repetir o falso negativo observado no experimento anterior em `C:\Dev\Prod\Gx_FabricaBrasil\Mapeamento`.

### Caso 2 - Procedure chamando Procedure por chamada direta

- origem: `Procedure:PreenchXmlNFE`
- destino: `Procedure:procLeParteDeStringXml`
- regra esperada: `procedure_direct_call`
- expectativa: criar relacao direta
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

## Gate negativo

Foi executado um caso de falha proposital em `Temp`, apontando para `Procedure:ObjetoInexistenteParaFalhar`.

Resultado esperado e observado:

- caso marcado como `failed`
- comando retornou `EXIT=2`

Isso valida o uso de `-FailOnValidationFailure` como gate operacional de rodada oficial.

## Limites desta validacao

- nao cobre `Transaction`
- nao cobre `WorkWithForWeb`
- nao cobre `DataProvider`
- nao cobre relacoes por `for each`
- nao cobre `.Load(...)`
- nao prova impacto funcional ou runtime
- nao substitui leitura do XML quando a mudanca exigir revisao semantica

## Conclusao

A Fase 1 tem uma primeira implementacao operacional validada para o recorte `Procedure` e `WebPanel`, com SQLite derivado, evidencia rastreavel, consulta por agente e gate de validacao.

O proximo passo tecnico deve ser ampliar testes e ergonomia de consulta antes de expandir novos tipos de objeto.
