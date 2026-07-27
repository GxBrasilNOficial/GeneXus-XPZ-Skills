# 10a — Rótulos da task Export vs catálogo interno

## Status

Documento de divergências entre o vocabulário aceito pela task MSBuild `Export` em `-ObjectList` (`Tipo:Nome`) e os rótulos usados em `scripts/gx-object-type-catalog.json`, KbIntelligence e pastas do acervo (`folderName`).

## Regra operacional

- Montar `-ObjectList` com o **rótulo da task Export**, não com o nome do tipo no catálogo ou no índice, quando existir divergência documentada abaixo.
- Consultar `exportTaskLabel` em `scripts/gx-object-type-catalog.json` quando o consumidor montar lista a partir do catálogo ou de `search-objects` / `list-by-type`.
- `exportTaskLabel` é vocabulário textual da task MSBuild; o GUID do tipo não o substitui. Ensaios com os dois GUIDs de Work With foram rejeitados como tipo inválido e só produziram objeto por fallback nominal, portanto são Categoria B e não exportações confiáveis.
- A identidade canônica continua sendo o GUID do `Object/@type`. Nomes atuais ou históricos de patterns não classificam o objeto e podem ser ambíguos entre WW para SD/mobile e WW para Web.
- Na pré-validação seletiva de **exportação**, uma coincidência explícita em `exportTaskLabel` precede nome canônico e `folderName`; por isso `WorkWith` resolve o tipo web e `WorkWithDevices` resolve o mobile. Fora do contexto Export, o nome canônico `WorkWith` continua resolvendo o tipo mobile.
- O inventário pós-export (`packageInventory`, `Get-GeneXusImportPackageObjectInventory.ps1`) classifica objetos pelo **catálogo/GUID** (`WorkWithForWeb` para `78cecefe-...`). Após export com `-ObjectList "WorkWith:Nome"`, o par no pacote aparece como `WorkWithForWeb:Nome` — isso **não** é falha de export. O motor de inventário reconcilia via `deltaComparison.aliasResolutions[]` quando existir `exportTaskLabel` no catálogo (regra `exportTaskLabel`: declarado `WorkWith:Nome` ↔ inventário `WorkWithForWeb:Nome`); `requestedItemsFound` / `missingCount` já refletem o alias. Resumo compacto em `packageInventory` (`aliasResolutionCount`, `aliasResolutions` ou `aliasResolutionsFullListAt` no sidecar).
- Em importação, equivalências diferentes podem existir (ex.: `Panel` vs `SDPanel` em `itemAliasMatches` — ver `10-base-operacional-msbuild-headless.md`); não assumir que o mesmo alias vale na exportação.

## Contrato `deltaComparison.aliasResolutions[]`

Presente quando há delta declarado (`-DeclaredDeltaItems` / `-DeclaredDeltaPath`). Lista vazia `[]` quando nenhum par foi reconciliado por alias.

Cada entrada (exemplo):

| Campo | Exemplo |
|-------|---------|
| `declaredTypeName` / `declaredName` / `declaredKey` | `WorkWith`, `Cliente`, `workwith:cliente` |
| `inventoryTypeName` / `inventoryName` / `inventoryKey` | `WorkWithForWeb`, `Cliente`, `workwithforweb:cliente` |
| `rule` | `exportTaskLabel` |
| `exportTaskLabel` | `WorkWith` |
| `catalogTypeName` / `catalogTypeGuid` | `WorkWithForWeb`, `78cecefe-...` |

Efeito: o declarado entra em `requestedItemsFound`; deixa `requestedItemsMissing`; a chave do inventário não conta como **extra** por divergência de rótulo. Não cobre homônimo nem fallback silencioso sem regra no catálogo.

## Fallback silencioso por nome vs divergência de rótulo

- **Divergência de rótulo** (este documento): lista com `exportTaskLabel` da task (`WorkWith:Nome`) e pacote com tipo do catálogo (`WorkWithForWeb:Nome`) — export correto; o motor preenche `aliasResolutions[]` conforme tabela acima.
- **Fallback silencioso por nome** (anti-padrão em `xpz-msbuild-import-export/SKILL.md`): a task GeneXus (ou camada equivalente) resolve por nome global ignorando o tipo pedido, ou entrega objeto homônimo de outro tipo, **sem** `invalidTypesRejected` / Categoria B — `exitCode=0` engana se o agente não confrontar identidade no inventário e, quando possível, no índice antes do MSBuild.
- **Tipo inválido no log** (`WorkWithForWeb:Nome` com `error : ... is not a valid type`): **não** é silêncio — wrapper rebaixa para **exit 48**; ver Categorias A/B na skill MSBuild.

## Tabela de divergências conhecidas

| GUID | Catálogo / pasta / índice | `exportTaskLabel` (task Export) | Evidência | Notas |
|------|---------------------------|----------------------------------|-----------|-------|
| `15cf49b5-fc38-4899-91b5-395d02d79889` | `WorkWith` | `WorkWithDevices` | Matriz GxTest3 em 2026-07-26, `WorkWithRoute` | WW para SD/mobile. `WorkWithDevices:Nome` exportou limpo e o inventário classificou pelo GUID como `WorkWith`; `WorkWith:Nome` procurou o tipo web e não encontrou o objeto mobile. |
| `78cecefe-be7d-4980-86ce-8d6e91fba04b` | `WorkWithForWeb` | `WorkWith` | Matriz A1 em 2026-05-25, KB FabricaBrasil18, `WorkWithWebCliente`; artefatos em `C:\Dev\Prod\Gx_FabricaBrasil\Temp\export-task-label-matrix-20260525\` | Controle positivo quebrado: `WorkWithForWeb:Nome` → `error : WorkWithForWeb is not a valid type`, `invalidTypesRejected` contém `WorkWithForWeb`. `WorkWith:Nome` → sem `invalidTypesRejected`, XPZ com o objeto (tipo no pacote: `WorkWithForWeb`). |

### Matriz A1 (resumo)

| Candidato `-ObjectList` | `invalidTypesRejected` | `error : ... is not a valid type` | Objeto no XPZ |
|-------------------------|------------------------|-----------------------------------|---------------|
| `WorkWithForWeb:WorkWithWebCliente` | `WorkWithForWeb` | sim | sim (fallback por nome) |
| `WWP:...` | `WWP` | sim | não |
| `WorkWith:...` | (vazio) | não | sim (`WorkWithForWeb` no inventário) |
| `WorkWithDevicesForWeb:...` | `WorkWithDevicesForWeb` | sim | não |
| `WorkWith for Web:...` | `Web` (parser) | sim | não |
| `PatternInstance:...` | `PatternInstance` | sim | não |
| só `WorkWithWebCliente` | (vazio) | não | inventário degradado (formato exige `Tipo:Nome`) |

### Matriz GxTest3 — coexistência mobile e web (2026-07-26)

Ensaios controlados na KB de teste `GxTest3`, com inventário do XPZ por GUID. O resultado confiável exige rótulo aceito sem erro de tipo e identidade exata no pacote.
Artefatos: `C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\workwith-export-matrix-20260726\` (matriz e Categoria B), `C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\workwith-global-export-20260726\` (mobile) e `C:\Dev\Knowledge\GeneXus-XPZ-Skills\Temp\workwith-web-global-export-20260726\` (web).

| Candidato `-ObjectList` | Sinal da task | Resultado confiável |
|-------------------------|----------------|----------------------|
| `WorkWithDevices:WorkWithRoute` | sem erro de tipo | sim: um `WorkWith`, GUID `15cf49b5-fc38-4899-91b5-395d02d79889` |
| `WorkWith:WorkWithRoute` | a task procura “Work With for Web”; objeto não encontrado | não: pacote vazio |
| `15cf49b5-fc38-4899-91b5-395d02d79889:WorkWithRoute` | GUID rejeitado como tipo; fallback por nome | não: Categoria B, embora o objeto mobile apareça |
| `WorkWith:WorkWithWebRoute` | sem erro de tipo | sim: um `WorkWithForWeb`, GUID `78cecefe-be7d-4980-86ce-8d6e91fba04b` |
| `WorkWithForWeb:WorkWithWebRoute` | tipo rejeitado; fallback por nome | não: Categoria B |
| `78cecefe-be7d-4980-86ce-8d6e91fba04b:WorkWithWebRoute` | GUID rejeitado como tipo; fallback por nome | não: Categoria B |

## Campanha P5 multi-KB (2026-05-30)

Artefatos: `historico/export-task-label-matrix-20260530/` (`coverage-map.json`, `consolidation-report.json`, `campaign-log.json`, `matrix/**/matrix-summary.json` e `export.json` por candidato).

KBs com índice KbIntelligence na campanha: FabricaBrasil18 (`C:\GxModels\FabricaBrasil18`), wsEducacaoSpTeste (`C:\KBs\wsEducacaoSpTeste`), OnlineShopSS (`C:\KBs\OnlineShopSS`). Espécime por tipo: primeira KB por prioridade com instância no índice.

| Métrica | Valor |
|---------|-------|
| Tipos `inventoryEligible` + `rootKind=Object` no catálogo | 40 |
| Com espécime (matriz executada) | 33 |
| Sem instância nas 3 KBs | 7 |
| Divergência `exportTaskLabel` observada naquela campanha de maio | só `WorkWithForWeb` → `WorkWith` (reconfirma A1); o tipo mobile ainda não fazia parte do catálogo avaliado |
| Rótulo da task = nome do catálogo em `Tipo:Nome` | 22 |
| Inconcluso ou export limpo só com nome (sem `Tipo:`) | 10 |

### Tipos testados sem divergência de rótulo (2026-05-30)

`API`, `ColorPalette`, `DataProvider`, `DataSelector`, `DesignSystem`, `Document`, `Domain`, `ExternalObject`, `File`, `Folder`, `Image`, `Language`, `Procedure`, `SDT`, `Stencil`, `Table`, `Theme`, `ThemeClass`, `ThemeColor`, `Transaction`, `UserControl`, `WebPanel`.

### Tipos sem espécime nas KBs da campanha (sem teste MSBuild nesta rodada)

`DataView`, `Query`, `SmartDevicesApplication`, `SmartDevicesPlus`, `WorkPanel`, `WorkWithPlusInstance`, `WorkWithPlusTemplate` — **não** registrar `exportTaskLabel` no catálogo até haver instância e export reproduzível.

### Observações (não viraram campo `exportTaskLabel`)

- **Inconclusos** (`Tipo:Nome` sem export limpo com o objeto no XPZ): `DataStore`, `PatternSettings`.
- **Export limpo só com nome** (inventário degradado; não usar em automação — ver anti-padrão fallback silencioso): `CategoryDiagram`, `Dashboard`, `DeploymentUnit`, `Generator`, `Module`, `PackagedModule`, `Panel`, `SubTypeGroup`.

Motores de manutenção da base (não são runtime público das skills em pastas paralelas): `scripts-maintenance/Build-ExportTaskLabelCoverageMap.ps1`, `scripts-maintenance/Run-ExportTaskLabelMatrix.ps1`, `scripts-maintenance/Invoke-ExportTaskLabelCampaign.ps1` (opção `-ParseOnly` reaproveita `export.json` já gerados), `scripts-maintenance/Merge-ExportTaskLabelCampaignResults.ps1`.

## Pré-validação no índice (export/import seletivo, P1 / P1 v2)

Antes do MSBuild, `Invoke-GeneXusXpzExport.ps1` (`-ObjectList`) e `Invoke-GeneXusXpzImport.ps1` / `Test-GeneXusXpzImportPreview.ps1` (`-IncludeItems`) com `-ParallelKbRoot` ou `-IndexPath` consultam KbIntelligence (`objectListPreflight` no `export.json` / `import.json`; `gateContext` = `export` ou `import`). Homônimo ou índice inválido/ausente → **exit 35**. Objeto ausente no índice (`not_in_index`) → aviso e MSBuild segue (pode existir só na KB nativa). Não substitui inventário pós-pacote nem `exportTaskLabel`. Equivalências pós-import no log (`Panel`↔`SDPanel`) permanecem em `Read-MsBuildImportSignals.ps1`, distintas de `exportTaskLabel`.

## Critério de aceite (smoke)

Para cada candidato em KB com instância real:

- `invalidTypesRejected` vazio no top-level de `export.json`
- Nenhuma linha `error : ... is not a valid type` em `msbuild.stdout.log` / `exportErrors`
- Objeto alvo presente no XPZ (ver `objectsByType` / inventário; com lista `WorkWith:Nome`, conferir `aliasResolutions[]` ou `requestedItemsFound` — não tratar `requestedItemsMissing` isolado como falha quando o alias estiver registrado)

## Referências

- `scripts/gx-object-type-catalog.json` — campo `exportTaskLabel` por tipo
- `xpz-msbuild-import-export/SKILL.md` — parâmetro `-ObjectList`, anti-padrão **fallback silencioso por nome**, Categorias A/B e barragem `exitCode=48`
- `scripts/Invoke-GeneXusXpzExport.ps1` — `invalidTypesRejected`, inventário pós-export, `exportErrors` → exit 48
- `scripts/msbuild-exit-codes.catalog.json` — código 48 (Categoria B)
- `historico/export-task-label-matrix-20260530/` — campanha P5 (2026-05-30)
- `scripts-maintenance/GeneXusExportTaskLabelSupport.ps1`, `scripts-maintenance/Build-ExportTaskLabelCoverageMap.ps1`, `scripts-maintenance/Run-ExportTaskLabelMatrix.ps1`, `scripts-maintenance/Invoke-ExportTaskLabelCampaign.ps1`, `scripts-maintenance/Merge-ExportTaskLabelCampaignResults.ps1`
