# 01k - Registro de Elementos Legados (export GeneXus 9)

## Papel do documento
operacional e de governança

## Nível de confiança predominante
alto (classificação e mapeamento peer-validados; tag/casing exatos de cada elemento confirmados pelo motor ao parsear GX9 real)

## Depende de
01a-catalogo-e-padroes-empiricos.md

## Usado por
xpz-sync/SKILL.md (motor de export legado, frente futura), scripts/gx-legacy-export-element-registry.json

## Objetivo

Documentar a **camada de representação e governança** dos elementos de export legado GeneXus 9 — sem poluir o catálogo moderno `scripts/gx-object-type-catalog.json`.

Um export GeneXus 9 é um `ExportFile` cujos objetos aparecem como `<GXObject><Elemento>...`, identificados pelo **nome do elemento** (ex.: `<Report>`, `<Menubar>`), **sem** o `Object/@type` (GUID de tipo) que o export moderno GeneXus 18 carrega. Por isso esses elementos não têm lugar no catálogo moderno, cuja chave é o GUID de tipo. O **registro** `scripts/gx-legacy-export-element-registry.json` é a fonte técnica executável desta classificação; este documento é a referência explicativa e normativa.

> Escopo: este documento e o registro definem **representação e governança** (como cada elemento legado se relaciona com o mundo moderno). O **motor de export** (parse do `ExportFile` GeneXus 9, materialização em `ObjetosDaKbEmXml` e integração no sync) é frente separada e não é descrito aqui.

## Modelo: equivalent vs orphan

Cada elemento legado pertence a uma de duas classes:

- **`equivalent`** — o elemento legado tem um **tipo moderno real** no catálogo (`catalogType`). Materializa-se exatamente como o tipo moderno correspondente; **reusa o `folderName` do catálogo** (não define pasta própria). O campo `modernSuccessor` não se aplica: não há sucessão, há identidade de tipo.
- **`orphan`** — o elemento legado **não tem** equivalente moderno direto. Materializa-se em pasta própria (`materializedFolderName`) sob um token de tipo sintético `typeToken` no formato `gxlegacy/<Elemento>`, que o distingue inequivocamente de qualquer tipo do catálogo moderno.

A reconciliação por GUID (`reconcilableByGuid`) é **invariante de classe**, não campo do registro: elementos legados não carregam GUID de tipo, logo **não participam** de rename por GUID no sync (o reconciliador GUID-aware ignora-os). Isso vale para ambas as classes e não precisa ser repetido por elemento.

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

## Inventário dos 10 elementos

Tabela peer-validada (Codex, Kimi-K2.6, deepseek-v4-pro, glm-5.2). `equivalent` (8):

| Elemento GX9 | `catalogType` (moderno) |
| --- | --- |
| `Transaction` | `Transaction` |
| `StructureDataType` | `SDT` |
| `Language` | `Language` |
| `Table` | `Table` |
| `Theme` | `Theme` |
| `Folder` | `Folder` |
| `WebPanel` | `WebPanel` |
| `Group` | `SubTypeGroup` |

Nota sobre `Group`: na nomenclatura GeneXus o **Subtype Group** é chamado "Group" (a wiki descreve-o como *"A Group can be viewed as a 'virtual' transaction"*); por isso o elemento legado `Group` mapeia para o tipo moderno `SubTypeGroup`. O elemento legado `Folder` (pasta organizacional) é separado e mapeia para o tipo `Folder`.

`orphan` (2):

| Elemento GX9 | `materializedFolderName` | `typeToken` | `modernSuccessor` | `successorRelation` |
| --- | --- | --- | --- | --- |
| `Report` | `Report` | `gxlegacy/Report` | `Procedure` | `absorbed` |
| `Menubar` | `Menubar` | `gxlegacy/Menubar` | `null` | `none` |

### Descontinuação dos órfãos (prosa)

- **`Report`**: o objeto Report do GeneXus clássico foi **absorvido** pela Procedure moderna (geração de saída por procedure com layout de impressão). `modernSuccessor` registra `Procedure` apenas como rastro de migração — o artefato legado continua representado por `gxlegacy/Report`, não como Procedure.
- **`Menubar`**: conceito sem sucessor moderno direto no GeneXus 18 (`successorRelation: none`, `modernSuccessor: null`). Materializa-se isolado em `gxlegacy/Menubar` para preservar o objeto no acervo sem inventar identidade moderna.

## Resíduos conhecidos (não bloqueiam a representação)

- O **casing exato** de `Menubar` e a **tag exata** de cada elemento são os melhores conhecidos; o motor de export confirma ao parsear um `ExportFile` GeneXus 9 real. Ajuste de casing/tag é correção do registro, não mudança de classe nem de mapeamento.
- Amostra real de referência (`GXW_alunoturma_re.xpz`, do autor do PR de export legado) não está nesta máquina; a classificação acima foi derivada por evidência de documentação GeneXus + revisão por pares.

## Invariantes validados por self-test

- `Test-GeneXusObjectTypeCatalogPuritySelfTest.ps1` — pureza do catálogo moderno: `objectTypeGuid: null` só é aceito em entrada com `rootKind: "Attribute"` (envelope próprio); todo `rootKind` diferente exige UUID válido; fail-safe para `rootKind` novo (qualquer `rootKind` fora de `Object`/`Virtual`/`Attribute` falha, forçando revisão consciente da regra de pureza). Não usa heurística "parece sintético" — GUIDs com padrão repetido (`dcdcdcdc-…` DataStore, `ecececec-…` Generator) são reais. Token: `GENEXUS_CATALOG_PURITY_SELFTEST_OK`.
- `Test-GeneXusLegacyRegistrySchemaSelfTest.ps1` — forma intra-registro: `schemaVersion: 1`; `class` em `{equivalent, orphan}`; `equivalent` tem exatamente `class`+`catalogType`; `orphan` tem `materializedFolderName`/`typeToken`/`modernSuccessor`/`successorRelation`; `typeToken` casa o regex; `successorRelation` em `{absorbed, none}` com a coerência `none ⟺ modernSuccessor null`. Token: `GENEXUS_LEGACY_REGISTRY_SCHEMA_SELFTEST_OK`.
- `Test-GeneXusLegacyRegistryDisjointSelfTest.ps1` — disjunção registro × catálogo: nome de órfão, `typeToken` e `materializedFolderName` não colidem com nenhum tipo/`folderName` do catálogo; `catalogType` de cada `equivalent` existe no catálogo; `modernSuccessor` não nulo existe no catálogo. Token: `GENEXUS_LEGACY_REGISTRY_DISJOINT_SELFTEST_OK`.
