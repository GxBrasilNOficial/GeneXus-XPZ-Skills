# 01k - Registro de Elementos Legados (export GeneXus 9)

## Papel do documento
operacional e de governança

## Nível de confiança predominante
alto para os 11 elementos observados em um export GeneXus 9 real (amostra `FinGX90`): classificação, mapeamento, tag e casing confirmados por inspeção direta. `Theme` é o único elemento classificado mas **não observado** nesta amostra (mantido por decisão de cobertura — ver «Resíduos conhecidos»); sua tag/casing exata será confirmada quando o motor de export legado parsear via sync um GX9 que o contenha (o parser **e** a integração no sync/inventário já existem; falta apenas um GX9 que contenha o elemento).

## Depende de
01a-catalogo-e-padroes-empiricos.md

## Usado por
scripts/Test-GeneXusLegacyRegistrySchemaSelfTest.ps1, scripts/Test-GeneXusLegacyRegistryDisjointSelfTest.ps1 (validam o registro). `scripts/Build-KbIntelligenceIndex.py` (indexador registry-aware: reconhece e pula pastas órfãs `gxlegacy/*`, com skip content-aware) e `scripts/Test-XpzObjetosDaKbNaming.ps1` (audit de naming: classifica órfão por `materializedFolderName`) já consomem `scripts/gx-legacy-export-element-registry.json`. O **parser/conversor** legado `scripts/GeneXusLegacyExportFileSupport.ps1` (com self-test isolado `scripts/Test-GeneXusLegacyExportFileSupportSelfTest.ps1`) também consome o registro. A **integração no fluxo de sync/inventário** já está em produção: `scripts/Sync-GeneXusXpzToXml.ps1` (materialização no acervo via ramo legado) e `scripts/Get-GeneXusImportPackageObjectInventory.ps1` (itens `known-legacy`) consomem o registro pelo motor compartilhado, com os self-tests `scripts/Test-XpzSyncLegacyExportFullSnapshotSelfTest.ps1`, `scripts/Test-XpzKbSourceMetadataLegacySelfTest.ps1` e `scripts/Test-XpzInventoryLegacyExportSelfTest.ps1`.

## Objetivo

Documentar a **camada de representação e governança** dos elementos de export legado GeneXus 9 — sem poluir o catálogo moderno `scripts/gx-object-type-catalog.json`.

Um export GeneXus 9 é um `ExportFile` cujos objetos aparecem como `<GXObject><Elemento>...`, identificados pelo **nome do elemento** (ex.: `<Report>`, `<Menubar>`), **sem** o `Object/@type` (GUID de tipo) que o export moderno GeneXus 18 carrega. Por isso esses elementos não têm lugar no catálogo moderno, cuja chave é o GUID de tipo. O **registro** `scripts/gx-legacy-export-element-registry.json` é a fonte técnica executável desta classificação; este documento é a referência explicativa e normativa.

> Escopo: este documento e o registro definem **representação e governança** (como cada elemento legado se relaciona com o mundo moderno). O **motor de export** (parse do `ExportFile` GeneXus 9, materialização em `ObjetosDaKbEmXml` e integração no sync/inventário) **já existe** — em `scripts/GeneXusLegacyExportFileSupport.ps1` e nos ramos legados de `Sync-GeneXusXpzToXml.ps1`/`Get-GeneXusImportPackageObjectInventory.ps1` —, mas seu **funcionamento interno** não é descrito aqui: este documento é a referência de representação/governança, não a spec do motor.

## Modelo: equivalent vs orphan

Cada elemento legado pertence a uma de duas classes:

- **`equivalent`** — o elemento legado tem um **tipo moderno real** no catálogo (`catalogType`). Materializa-se exatamente como o tipo moderno correspondente; **reusa o `folderName` do catálogo** (não define pasta própria). O campo `modernSuccessor` não se aplica: não há sucessão, há identidade de tipo.
- **`orphan`** — o elemento legado **não tem** equivalente moderno direto. Materializa-se em pasta própria (`materializedFolderName`) sob um token de tipo sintético `typeToken` no formato `gxlegacy/<Elemento>`, que o distingue inequivocamente de qualquer tipo do catálogo moderno.

A reconciliação por GUID (`reconcilableByGuid`) é **invariante de classe**, não campo do registro. Atenção a **dois GUIDs distintos**: o **GUID de tipo** (`Object/@type`) — que falta aos elementos legados e por isso eles ficam fora do catálogo moderno — **não** é o usado pelo rename GUID-aware do `Sync-GeneXusXpzToXml.ps1`, que reconcilia por **`guid` do nó raiz do objeto** (identidade da instância). O **motor de export legado** materializa os itens com `guid` de objeto **vazio** (`guid=""`) — a amostra `FinGX90` confirma que o export GeneXus 9 não traz `guid` de objeto —, logo eles **não participam** do rename por GUID (`Test-IsMeaningfulGuid("")==false`); se/como participarão no futuro dependeria de um export legado que trouxesse identidade estável de instância. Isso vale para ambas as classes e não precisa ser repetido por elemento.

### Campos por classe

`equivalent`:

| Campo | Significado |
| --- | --- |
| `class` | Sempre `"equivalent"`. |
| `catalogType` | Nome do tipo moderno em `scripts/gx-object-type-catalog.json`. Define a materialização e o `folderName` reusado. |

`orphan`:

| Campo | Significado |
| --- | --- |
| `class` | Sempre `"orphan"`. |
| `materializedFolderName` | Pasta própria em `ObjetosDaKbEmXml` onde o órfão é materializado. Não colide com nenhum `folderName`/tipo do catálogo. |
| `typeToken` | Token de tipo sintético, formato travado `^gxlegacy/[A-Za-z][A-Za-z0-9]*$`. É o identificador interno do artefato órfão; **estende-se trivialmente** se um elemento legado futuro tiver `_`/`-` na tag (revisar o regex com caso real). |
| `modernSuccessor` | **Metadado de migração**, não identidade: o tipo moderno que absorveu ou sucedeu o conceito. **Nunca** vira o `type` do artefato materializado (o artefato órfão é representado por seu `typeToken`, não pelo sucessor). `null` quando não há sucessor. |
| `successorRelation` | Relação com o sucessor. Enum cobre **só o corpus conhecido**: `absorbed` (o conceito foi absorvido pelo sucessor) e `none` (sem sucessor; exige `modernSuccessor: null`). Novos valores só com critério explícito e caso real. |

## Inventário dos 12 elementos

Tabela peer-validada e **confirmada por export GeneXus 9 real** (amostra `FinGX90`, KB "Financeiro": 11 dos 12 elementos observados; só `Theme` não observado). `equivalent` (10):

| Elemento GX9 | `catalogType` (moderno) |
| --- | --- |
| `Transaction` | `Transaction` |
| `StructureDataType` | `SDT` |
| `Language` | `Language` |
| `Table` | `Table` |
| `Procedure` | `Procedure` |
| `DataView` | `DataView` |
| `WorkPanel` | `WorkPanel` |
| `Folder` | `Folder` |
| `Group` | `SubTypeGroup` |
| `Theme` | `Theme` (não observado na amostra — ver «Resíduos conhecidos») |

Nota sobre `Group`: na nomenclatura GeneXus o **Subtype Group** é chamado "Group" (a wiki descreve-o como *"A Group can be viewed as a 'virtual' transaction"*); por isso o elemento legado `Group` mapeia para o tipo moderno `SubTypeGroup`. O elemento legado `Folder` (pasta organizacional) é separado e mapeia para o tipo `Folder`. Ambos confirmados na amostra (`Group` traz `<Subtype><Name>/<Supertype>`; `Folder` é pasta organizacional).

Nota sobre `WorkPanel`: o elemento legado `WorkPanel` mapeia para o tipo moderno **`WorkPanel`** (objeto do gerador desktop/Windows, *deprecated* desde GeneXus 15, com GUID próprio no catálogo) — **não** para `WebPanel` (página web, runtime distinto). A entrada anterior `WebPanel` do registro era erro de tag/tipo da versão validada sem amostra; `FinGX90` confirma a tag real `WorkPanel` (169 ocorrências).

`orphan` (2):

| Elemento GX9 | `materializedFolderName` | `typeToken` | `modernSuccessor` | `successorRelation` |
| --- | --- | --- | --- | --- |
| `Report` | `Report` | `gxlegacy/Report` | `Procedure` | `absorbed` |
| `Menubar` | `Menubar` | `gxlegacy/Menubar` | `null` | `none` |

### Descontinuação dos órfãos (prosa)

- **`Report`**: o objeto Report do GeneXus clássico foi **absorvido** pela Procedure moderna (geração de saída por procedure com layout de impressão). `modernSuccessor` registra `Procedure` apenas como rastro de migração — o artefato legado continua representado por `gxlegacy/Report`, não como Procedure.
- **`Menubar`**: conceito sem sucessor moderno direto no GeneXus 18 (`successorRelation: none`, `modernSuccessor: null`). Materializa-se isolado em `gxlegacy/Menubar` para preservar o objeto no acervo sem inventar identidade moderna.

## Resíduos conhecidos (não bloqueiam a representação)

- 11 dos 12 elementos do registro foram **confirmados por inspeção direta de um export GeneXus 9 real** (amostra `FinGX90`, KB "Financeiro", export GeneXus 9.0): tag, casing (`Menubar` em minúsculo após a primeira letra; `WorkPanel`, `DataView`, `StructureDataType`, `Procedure`, etc.) e estrutura batem com a classificação. Ajuste de tag/casing, caso algum dia divergir em outra KB GX9, é correção do registro, não mudança de classe nem de mapeamento.
- **`Theme` é o único elemento não observado** na amostra `FinGX90` (KB de perfil desktop/Windows — 169 `WorkPanel`, sem páginas web → sem Themes). É mantido no registro por **decisão de cobertura**, não por evidência da amostra: o objeto Theme existe no GeneXus desde o 8.0 (codinome Olimar, 2003) e o GeneXus 9.0 (Yi, 2005) o suportava — fato de **documentação oficial GeneXus**, não verificado contra esta amostra nem contra o repositório. A tag/casing exata de `<Theme>` em export GX9 segue **presumida** até o motor de export legado (que já existe) materializar via sync um GX9 que a contenha; se a tag real divergir, é fail-closed de tag desconhecida no parser (correção de registro, não de motor).

## Detecção cross-fluxo moderno↔legado (divergência de origem `dataSource`)

A identidade de acervo é apenas `FolderType|NormalizedName`. Se o **mesmo** objeto for materializado primeiro por um export **moderno** e depois por um export **legado GeneXus 9** (ou vice-versa) na mesma pasta/nome, os envelopes diferem (`dataSource="gx-legacy-export"` + `GxLegacyPayload` + `guid=""` no legado vs envelope moderno) mas a identidade não — e, antes desta frente, o segundo sync **sobrescrevia** o primeiro silenciosamente por `lastUpdate`. É **raro** (uma KB real costuma ser moderna **ou** legada). A limitação foi **deferida por design** na Fase 2 e depois **tratada** (entrada «Colisão cross-fluxo…» migrada de `999-ideias-pendentes.md` para `historico/IdeiasImplementadas_202606.md`):

- **`Sync-GeneXusXpzToXml.ps1` detecta** a divergência de origem antes de gravar metadata/XML (`Get-GeneXusCrossFlowDataSourceCollisions`, pré-rename): compara o `dataSource` do nó entrante com o do arquivo já materializado. Postura padrão **fail-soft** — campo `Summary.CrossFlowCollisions` no stdout, booleano `Writes[].CrossFlowCollision` no relatório, e a colisão também por stderr (`CROSSFLOW_COLLISION:` JSONL); o `lastUpdate` ainda decide a sobrescrita, mas a colisão deixa de ser silenciosa. Bloqueio **opt-in** `-BlockCrossFlowDataSource` aborta antes de tocar metadata/XML (distinto do fail-closed de pacote **misto**, que é dentro de um único `ExportFile`; esta colisão é **entre execuções de sync**).
- **Sinal secundário (Decisão E.2):** quando o arquivo existente **não** tem `dataSource`, o filho direto `<GxLegacyPayload>` é o sinal de legado (exclusivo do legado); `guid=""` é só corroborante.
- **Limitação residual (Decisão E):** (a) ausência do atributo `dataSource` / `dataSource=""` em XML **moderno** é origem moderna **por desenho** (desejado); (b) um arquivo **legado** depositado à mão **sem nenhum sinal** (sem `dataSource`, sem `<GxLegacyPayload>`, sem `guid=""`) é tratado como moderno e **não** dispara colisão — marginal, pois o motor legado sempre carimba `dataSource="gx-legacy-export"`.
- **Risco residual (Decisão G):** para um XML existente **não-parseável**, a detecção não produz origem confiável: **não gera colisão nem bloqueia** (nem sob `-BlockCrossFlowDataSource`), só emite um warning (`CROSSFLOW_WARNING:`). Isso **não garante a sobrescrita** do arquivo: o sync pode falhar adiante ao processar um arquivo existente corrompido (estágios de parse preexistentes — `Get-LastUpdateInfoFromFile`/`Test-PackageMaterialization` —, **fora do escopo desta frente**).

## Invariantes validados por self-test

- `Test-GeneXusObjectTypeCatalogPuritySelfTest.ps1` — pureza do catálogo moderno: `objectTypeGuid: null` só é aceito em entrada com `rootKind: "Attribute"` (envelope próprio); todo `rootKind` diferente exige UUID válido; fail-safe para `rootKind` novo (qualquer `rootKind` fora de `Object`/`Virtual`/`Attribute` falha, forçando revisão consciente da regra de pureza). Não usa heurística "parece sintético" — GUIDs com padrão repetido (`dcdcdcdc-…` DataStore, `ecececec-…` Generator) são reais. Token: `GENEXUS_CATALOG_PURITY_SELFTEST_OK`.
- `Test-GeneXusLegacyRegistrySchemaSelfTest.ps1` — forma intra-registro: `schemaVersion: 1`; `class` em `{equivalent, orphan}`; `equivalent` tem exatamente `class`+`catalogType`; `orphan` tem `materializedFolderName`/`typeToken`/`modernSuccessor`/`successorRelation`; `typeToken` casa o regex; `successorRelation` em `{absorbed, none}` com a coerência `none ⟺ modernSuccessor null`. Token: `GENEXUS_LEGACY_REGISTRY_SCHEMA_SELFTEST_OK`.
- `Test-GeneXusLegacyRegistryDisjointSelfTest.ps1` — disjunção registro × catálogo: nome de órfão, `typeToken` e `materializedFolderName` não colidem com nenhum tipo/`folderName` do catálogo; `catalogType` de cada `equivalent` existe no catálogo; `modernSuccessor` não nulo existe no catálogo. Token: `GENEXUS_LEGACY_REGISTRY_DISJOINT_SELFTEST_OK`.
