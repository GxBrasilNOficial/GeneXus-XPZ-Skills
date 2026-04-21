# Validacao KB Intelligence Fase 2 - DataProvider, WorkWithForWeb e ATTCUSTOMTYPE - FabricaBrasil

## Papel do documento
historico de validacao

## Nivel de confianca predominante
medio

## Data da rodada
2026-04-21

## Repositorio metodologico
`C:\Dev\Knowledge\GeneXus-XPZ-Skills`

## Pasta paralela usada como laboratorio
`C:\Dev\Prod\Gx_FabricaBrasil`

## Fonte XML
`C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml`

## Objetivo
Registrar a consolidacao da Fase 2 do KB Intelligence, adicionando `DataProvider` como origem e destino em `Source` efetivo, actions de `WorkWithForWeb` com `gxobject` resolvido, vinculacoes explicitas de `WorkWithForWeb` para `Transaction`, links e prompts explicitos de `WorkWithForWeb` para `WebPanel`, condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`, e propriedades `ATTCUSTOMTYPE` como alvo literal `CustomType`.

## Escopo

Incluido nesta rodada:

- origem: `DataProvider`
- destino: `DataProvider`
- destinos mantidos para origem `DataProvider`: `Procedure` e `WebPanel`
- origem: `WorkWithForWeb` por action com `gxobject`
- destinos de action: `Procedure` e `WebPanel`
- destino explicito de `WorkWithForWeb`: `Transaction`
- links explicitos de `WorkWithForWeb`: `WebPanel`
- prompts explicitos de `WorkWithForWeb`: `WebPanel`
- condicoes de `WorkWithForWeb`: `Procedure`
- atributos de condicao de `WorkWithForWeb`: `Procedure`
- alvo literal: `CustomType:<valor>` por `ATTCUSTOMTYPE`
- regras: `procedure_direct_call`, `procedure_dot_call`, `webpanel_dot_link`, `dataprovider_direct_call`, `workwith_action_gxobject`, `workwith_transaction_binding`, `workwith_link_webpanel`, `workwith_prompt_webpanel`, `workwith_condition_procedure`, `workwith_condition_attribute_procedure` e `attcustomtype_property`
- evidencias: `Source efetivo`, `WorkWith action`, `WorkWith transaction`, `WorkWith link`, `WorkWith prompt`, `WorkWith condition`, `WorkWith condition attribute` e `Property ATTCUSTOMTYPE`

Continuam fora:

- semantica completa de `Transaction`
- semantica de `WorkWithForWeb` alem dos recortes ja cobertos
- `for each`
- `.Load(...)`
- resolucao semantica de `CustomType` para `SDT`, `Domain` ou outro tipo GeneXus
- chamadas dinamicas
- comentarios como chamada efetiva

## Comandos executados

Regressao dos 15 casos da Fase 1:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-phase2-regression.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-phase2-regression-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase1.validation-cases.json" `
  -FailOnValidationFailure
```

Validacao dos casos de Fase 2:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-phase2.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-phase2-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase2.validation-cases.json" `
  -FailOnValidationFailure
```

Regressao ampliada depois dos incrementos de `WorkWithForWeb` e `ATTCUSTOMTYPE`:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath ".\Temp\kb-intelligence-phase2-workwith-attcustomtype-regression.sqlite" `
  -ValidationReportPath ".\Temp\kb-intelligence-phase2-workwith-attcustomtype-regression-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase1.validation-cases.json" `
  -FailOnValidationFailure
```

Geracao do indice canonico da pasta paralela:

```powershell
.\scripts\New-KbIntelligenceIndex.ps1 `
  -SourceRoot "C:\Dev\Prod\Gx_FabricaBrasil\ObjetosDaKbEmXml" `
  -OutputPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence.sqlite" `
  -ValidationReportPath "C:\Dev\Prod\Gx_FabricaBrasil\KbIntelligence\kb-intelligence-validation.json" `
  -ValidationCasesPath ".\scripts\kb-intelligence-fabricabrasil.phase2.validation-cases.json" `
  -FailOnValidationFailure
```

## Resultado da geracao

- `Procedure` lidas: 2302
- `WebPanel` lidos: 1198
- `DataProvider` lidos: 24
- `WorkWithForWeb` lidos: 183
- `Transaction` lidas: 183
- objetos gravados no SQLite: 3890
- relacoes gravadas: 34276
- casos de regressao da Fase 1: 15 `passed`
- casos de validacao da Fase 2: 40 `passed`

## Casos de validacao da Fase 2

A bateria propria da Fase 2 cobriu:

- chamadas diretas de `Procedure` em expressoes de `DataProvider`
- chamada direta de `Procedure` em `where`
- `.Link(...)` para `WebPanel`
- `.Link(...)` para `WebPanel` com parametros
- chamadas diretas para `DataProvider` em `Procedure`
- chamadas diretas para `DataProvider` em `WebPanel`
- referencia comentada a `Procedure` sem relacao direta
- referencia comentada a `WebPanel` sem relacao direta
- referencia comentada a `DataProvider` sem relacao direta
- action de `WorkWithForWeb` para `Procedure`
- action de `WorkWithForWeb` para `WebPanel`
- alvo inexistente de action sem relacao criada
- `ATTCUSTOMTYPE` em `Transaction`
- `ATTCUSTOMTYPE` em `Procedure`
- `CustomType` inexistente sem relacao criada
- vinculacao explicita de `WorkWithForWeb` para `Transaction`
- `Transaction` inexistente sem relacao criada
- links explicitos de `WorkWithForWeb` para `WebPanel`
- canonizacao de nome de `WebPanel` em link explicito
- `WebPanel` inexistente sem relacao criada
- prompts explicitos de `WorkWithForWeb` para `WebPanel`
- prompt para `WebPanel` inexistente sem relacao criada
- condicoes de `WorkWithForWeb` chamando `Procedure`
- condicao para `Procedure` inexistente sem relacao criada
- atributos de condicao de `WorkWithForWeb` chamando `Procedure`
- chamada apos comentario `//` em atributo de condicao sem relacao criada

## Consultas reais executadas

`object-info` para `DataProvider:dpFixoSidebarItems`:

- objeto localizado em `DataProvider/dpFixoSidebarItems.xml`
- 21 relacoes de saida

`what-uses` para `DataProvider:dpFixoSidebarItems`:

- retornou relacoes diretas para `WebPanel` por `webpanel_dot_link`

`who-uses` para `Procedure:procRecentLinksLoad`:

- retornou usos vindos de `DataProvider`, `Procedure` e `WebPanel`

`show-evidence` para `DataProvider:dpFixoSidebarItems` -> `WebPanel:WWEmbarqueSaida`:

- evidencia direta em `DataProvider/dpFixoSidebarItems.xml`, linha 159, por `webpanel_dot_link`

`who-uses` para `DataProvider:dpFixoSidebarItems`:

- retornou `Procedure:procMenuItens` como origem direta por `dataprovider_direct_call`

`show-evidence` para `Procedure:procMenuItens` -> `DataProvider:dpFixoSidebarItems`:

- evidencia direta em `Procedure/procMenuItens.xml`, linha 5, por `dataprovider_direct_call`

`object-info` para `WorkWithForWeb:WorkWithWebAbateOrdem`:

- objeto localizado em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`
- 87 relacoes de saida

`what-uses` para `WorkWithForWeb:WorkWithWebAbateOrdem`:

- retornou actions resolvidas para `Procedure` e `WebPanel` por `workwith_action_gxobject`

`who-uses` para `Procedure:procLimpaGridState`:

- retornou usos por `Source efetivo` e por action de `WorkWithForWeb`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procLimpaGridState`:

- evidencia direta em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, linha 216, por `workwith_action_gxobject`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `WebPanel:wpPesagemAbate`:

- retornou 3 evidencias diretas por `workwith_action_gxobject`

`who-uses` para `CustomType:sdt:Context`:

- retornou 209 usos por `attcustomtype_property`

`show-evidence` para `Transaction:AbateOrdem` -> `CustomType:sdt:Context`:

- evidencia direta em `Transaction/AbateOrdem.xml`, linha 1134, por `attcustomtype_property`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Transaction:AbateOrdem`:

- evidencia direta em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, por `workwith_transaction_binding`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `WebPanel:ViewPessoa`:

- evidencia direta em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, por `workwith_link_webpanel`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `WebPanel:promptCompraGado`:

- evidencia direta em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, por `workwith_prompt_webpanel`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procLeEmpresaSessao`:

- evidencia direta em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, linha 172, por `workwith_condition_procedure`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procPessoaInscricaoFederal`:

- evidencia direta em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, linha 182, por `workwith_condition_procedure`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procEmpresaGeraNotasDeRetornoPelaOrdemDeAbate`:

- 4 evidencias diretas em `WorkWithForWeb/WorkWithWebAbateOrdem.xml`, por `workwith_condition_attribute_procedure`

`show-evidence` para `WorkWithForWeb:WorkWithWebAnimalPadrao` -> `Procedure:procUsuarioDaSessaoDaEquipeDaFrigobyte`:

- 3 evidencias diretas em `WorkWithForWeb/WorkWithWebAnimalPadrao.xml`, por `workwith_condition_attribute_procedure`

`show-evidence` para `WorkWithForWeb:WorkWithWebAbateOrdem` -> `Procedure:procReferenciadoRomaneioVolumesTotalPesoLiquido`:

- sem resultados, confirmando que chamada apos comentario `//` no atributo de condicao nao foi indexada

## Conclusao

A Fase 2 foi consolidada com nove incrementos implementados e validados: `DataProvider` como origem, `DataProvider` como destino de chamada direta, actions de `WorkWithForWeb` por `gxobject`, vinculacoes explicitas de `WorkWithForWeb` para `Transaction`, links e prompts explicitos de `WorkWithForWeb` para `WebPanel`, condicoes por tag e atributo de `WorkWithForWeb` chamando `Procedure`, e `ATTCUSTOMTYPE` como `CustomType` literal.

Continuam fora: semantica completa de `Transaction`, semantica de `WorkWithForWeb` alem dos recortes ja cobertos, `for each`, `.Load(...)` e resolucao semantica de `CustomType` para `SDT` ou `Domain`.
