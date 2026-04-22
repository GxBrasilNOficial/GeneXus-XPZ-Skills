# KB Intelligence Scripts

## Papel do documento
guia operacional

## Escopo atual

Estes scripts implementam a Fase 1 do KB Intelligence, os incrementos aprovados da Fase 2, a consulta operacional da Fase 3, o inventario ampliado da Fase 4 e os incrementos aprovados da Fase 5.

A Fase 3 foi aberta por contrato em `..\14-kb-intelligence-fase-3-contrato.md` para formalizar o uso operacional por agentes e o comando `impact-basic`.

A Fase 5 foi aberta por contrato em `..\16-kb-intelligence-fase-5-contrato.md` para ampliar relacoes semanticas por incrementos pequenos.

Escopo de inventario atual:

- todos os tipos com XML em subpastas imediatas de `ObjetosDaKbEmXml`

Escopo de extracao de relacoes atual:

- origens por `Source` efetivo: `Procedure`, `WebPanel` e `DataProvider`
- destinos por `Source` efetivo: `Procedure`, `WebPanel` e `DataProvider`
- origem por action: `WorkWithForWeb`
- destino por action: `Procedure` ou `WebPanel`
- vinculacao explicita: `WorkWithForWeb` para `Transaction`
- link explicito: `WorkWithForWeb` para `WebPanel`
- prompt explicito: `WorkWithForWeb` para `WebPanel`
- condicao explicita: `WorkWithForWeb` para `Procedure`
- atributo de condicao: `WorkWithForWeb` para `Procedure`
- alvo literal por propriedade: `CustomType:<valor>` a partir de `ATTCUSTOMTYPE`
- alvo resolvido por propriedade: `SDT` ou `Domain` a partir de `ATTCUSTOMTYPE`, quando o objeto existir no inventario e a regra aprovada resolver o prefixo com seguranca
- dominio base de atributo: `Attribute` para `Domain` a partir de `idBasedOn`, quando o dominio existir no inventario local
- atributo estrutural de transacao: `Transaction` para `Attribute` a partir de `<Level>/<Attribute>`, quando o atributo existir no inventario local
- relacoes: chamadas diretas em `Source efetivo`, actions `gxobject` resolvidas, vinculacoes explicitas de `Transaction`, links e prompts explicitos de `WebPanel` em `WorkWithForWeb`, condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`, propriedades `ATTCUSTOMTYPE`, `idBasedOn` de `Attribute` e atributos estruturais de `Transaction`
- artefato principal: SQLite derivado

A Fase 2 consolidada cobre `DataProvider` como origem e como destino de chamada direta, actions de `WorkWithForWeb` com `gxobject` resolvido para `Procedure` ou `WebPanel`, vinculacao explicita de `WorkWithForWeb` para `Transaction`, links e prompts explicitos de `WorkWithForWeb` para `WebPanel`, condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`, e `ATTCUSTOMTYPE` como `CustomType` literal. Ela nao cobre semantica completa de `Transaction`, semantica de `WorkWithForWeb` alem dos recortes ja cobertos, `for each`, `.Load(...)` nem resolucao semantica de `CustomType` para `SDT` ou `Domain`.

Eles nao substituem o acervo XML em `ObjetosDaKbEmXml` e nao provam comportamento runtime.

## Gerar indice

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase1.validation-cases.json" `
  -FailOnValidationFailure
```

Para outra KB, troque `-SourceRoot`, `-OutputPath` e, se aplicavel, `-ValidationCasesPath`.

Para validar os incrementos aprovados da Fase 2 em `FabricaBrasil`, use:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase2.validation-cases.json" `
  -FailOnValidationFailure
```

O local operacional padrao dentro da pasta paralela da KB e `KbIntelligence\kb-intelligence.sqlite`. Este banco e derivado e regeneravel; a fonte normativa continua sendo `ObjetosDaKbEmXml`.

## Buscar objetos por nome

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -Query search-objects `
  -ObjectName "*PlanilhaVolume*" `
  -Limit 10 `
  -Format text
```

## Localizar um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -Query object-info `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Format text
```

## Consultar quem usa um objeto

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -Query who-uses `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

## Consultar o que um objeto usa

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -Query what-uses `
  -ObjectType WebPanel `
  -ObjectName wpRelatoriosDeMovimentosDeVolumes `
  -Limit 10 `
  -Format text
```

## Consultar evidencia

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -Query show-evidence `
  -SourceType WebPanel `
  -SourceName wpRelatoriosDeMovimentosDeVolumes `
  -TargetType Procedure `
  -TargetName procPlanilhaVolumeMovimento `
  -Format text
```

## Triagem de impacto basico

O comando `impact-basic` resume dependentes diretos e dependencias diretas do objeto, ainda sem alterar o escopo de extracao.

```powershell
.\scripts\Query-KbIntelligenceIndex.ps1 `
  -IndexPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -Query impact-basic `
  -ObjectType Procedure `
  -ObjectName procPlanilhaVolumeMovimento `
  -Limit 10 `
  -Format text
```

Para auditar uma relacao especifica retornada por `impact-basic`, use `show-evidence`.

Essa consulta representa impacto tecnico direto baseado no indice. Ela nao prova impacto runtime completo.

## Validar consultas da Fase 3

Depois de gerar ou localizar um indice SQLite, valide o comportamento operacional de `impact-basic` com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase3.validation-cases.json" `
  -ValidationReportPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence-phase3-validation.json" `
  -FailOnValidationFailure
```

Os casos de validacao da Fase 3 conferem comportamento de consulta. Eles nao regeneram o indice nem substituem a bateria de extracao da Fase 2.

## Validar inventario ampliado da Fase 4

Depois de regenerar o indice, valide a presenca de tipos ampliados com:

```powershell
.\scripts\Test-KbIntelligenceQueries.ps1 `
  -IndexPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase4.validation-cases.json" `
  -ValidationReportPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence-phase4-validation.json" `
  -FailOnValidationFailure
```

Os casos da Fase 4 conferem inventario de objetos e comportamento conservador de `impact-basic` para tipos sem relacoes extraidas.

## Validar relacoes semanticas da Fase 5

Depois de regenerar o indice, valide a resolucao semantica aprovada com:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase5.validation-cases.json" `
  -FailOnValidationFailure
```

Os casos da Fase 5 conferem relacoes semanticas novas. Eles devem ser executados junto com as baterias anteriores quando houver rodada oficial.

## Saidas

- `json`: formato padrao para consumo por agentes e automacoes
- `text`: formato curto para leitura rapida em conversa ou terminal

## Regras de uso por agente

- consultar por `tipo + nome`, nunca apenas nome
- procurar primeiro por `KbIntelligence\kb-intelligence.sqlite` na pasta paralela da KB
- ignorar pastas `ArquivoMorto`, salvo pedido explicito do usuario para analise historica
- tratar o SQLite como derivado e regeneravel
- manter o XML oficial como fonte normativa
- antes de alterar objeto GeneXus coberto pelo indice, executar `impact-basic`
- tratar `impact-basic` como impacto tecnico direto, nao como prova funcional completa
- usar a linha e o `snippet` apenas como evidencia tecnica, nao como prova funcional completa
- quando a mudanca exigir semantica GeneXus, abrir o XML e revisar o `Source` efetivo
