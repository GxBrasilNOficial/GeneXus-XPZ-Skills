# KB Intelligence Scripts

## Papel do documento
guia operacional

## Escopo atual

Estes scripts implementam a Fase 1 do KB Intelligence:

- origem: `Procedure` e `WebPanel`
- destino: `Procedure` e `WebPanel`
- relacoes: chamadas diretas em `Source efetivo`
- artefato principal: SQLite derivado

Eles nao substituem o acervo XML em `ObjetosDaKbEmXml` e nao provam comportamento runtime.

## Gerar indice

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-phase1-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase1.validation-cases.json" `
  -FailOnValidationFailure
```

Para outra KB, troque `-SourceRoot`, `-OutputPath` e, se aplicavel, `-ValidationCasesPath`.

## Buscar objetos por nome

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -Query search-objects `
  -ObjectName "*PlanilhaVolume*" `
  -Limit 10 `
  -Format text
```

## Localizar um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -Query object-info `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Format text
```

## Consultar quem usa um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -Query who-uses `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

## Consultar o que um objeto usa

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -Query what-uses `
  -ObjectType WebPanel `
  -ObjectName wpRelatoriosDeMovimentosDeVolumes `
  -Limit 10 `
  -Format text
```

## Consultar evidencia

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath ".\Temp\kb-intelligence-phase1.sqlite" `
  -Query show-evidence `
  -SourceType WebPanel `
  -SourceName wpRelatoriosDeMovimentosDeVolumes `
  -TargetType Procedure `
  -TargetName procPlanilhaVolumeMovimento `
  -Format text
```

## Saidas

- `json`: formato padrao para consumo por agentes e automacoes
- `text`: formato curto para leitura rapida em conversa ou terminal

## Regras de uso por agente

- consultar por `tipo + nome`, nunca apenas nome
- tratar o SQLite como derivado e regeneravel
- manter o XML oficial como fonte normativa
- usar a linha e o `snippet` apenas como evidencia tecnica, nao como prova funcional completa
- quando a mudanca exigir semantica GeneXus, abrir o XML e revisar o `Source` efetivo
