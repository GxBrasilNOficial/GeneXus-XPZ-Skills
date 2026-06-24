# 01a - Catalogo e Padrões Empiricos

## Papel do documento
empirico

## Objetivo
Concentrar panorama do acervo, catalogo observado de tipos, padrões recorrentes e limites gerais de leitura estrutural.

## Origem incorporada - 01-base-empirica-geral.md

## Papel do documento
conceitual

## Nível de confiança predominante
alto

## Depende de
30-inventario-bruto-kb.md

## Usado por
02-genexus-xpz-generation-rules.md, 10-matriz-part-types-por-tipo.md, 11-campos-estaveis-vs-variaveis.md, 12-diffs-estruturais-por-tipo.md, 02-regras-operacionais-e-runtime.md

## Objetivo
Consolidar a leitura estrutural do acervo XML extraído da KB.
Servir como base conceitual para os documentos empíricos e operacionais.

## Fonte usada

- `Evidência direta`: a consolidação abaixo usa o inventário em `C:\Dev\Knowledge\GeneXus\30-inventario-bruto-kb.md`.
- `Evidência direta`: foram lidos XMLs do acervo `C:\SANITIZED\ObjetosDaKbEmXml`.

## Panorama do acervo

- `Evidência direta`: o acervo contém `7219` XMLs distribuídos em `32` diretórios de tipos extraídos.
- `Evidência direta`: os maiores conjuntos por diretório são `Procedure` (`2281`), `WebPanel` (`1196`), `SubTypeGroup` (`709`), `SDT` (`594`), `Domain` (`592`), `ThemeClass` (`501`), `Module` (`279`), `Image` (`250`), `Index` (`228`), `Transaction` (`183`) e `WorkWithForWeb` (`183`).
- `Evidência direta`: o inventário bruto registrou `0` arquivos problemáticos na leitura XML.

## Estrutura XML recorrente

- `Evidência direta`: os objetos extraídos seguem o formato geral `<Object ...>` com atributos como `guid`, `name`, `type`, `parent`, `parentGuid`, `moduleGuid` e `fullyQualifiedName`.
- `Evidência direta`: a maioria dos tipos armazena conteúdo interno em blocos `<Part type="...">...</Part>` dentro de `<Object>`.
- `Evidência direta`: uma classe de tipos armazena propriedades diretamente em `<Properties>` sob `<Object>`, sem qualquer wrapper `<Part>`. Tipos confirmados com essa estrutura no acervo FabricaBrasil: `ThemeClass` (501 objetos), `Module/Folder` (279 objetos, `000...0008`), `ThemeColor` (24 objetos), `Generator` (5 objetos), `DataStore` (2 objetos).
- `Evidência direta`: em 2026-05-30, amostra em quatro pastas paralelas (`Gx_FabricaBrasil`, `Gx_wsEducacaoSpTeste` em Prod e Test, `Gx_OnlineShopSS` em Test) via `scripts/Invoke-ParallelKbEnvelopeScan.ps1` confirmou `only_properties_in_sample` para `Generator`, `DataStore`, `ThemeClass`, `ThemeColor` (quando presente) e `Folder` em todas as KBs que tinham o tipo; `PatternSettings` tem `<Part>` com `<Data>` em CDATA, mas o extrator do índice não parseia esse bloco.
- `Regra editorial`: `queryableByKbIntelligence=false` no catálogo técnico (`scripts/gx-object-type-catalog.json`) marca tipos para os quais **o motor atual do índice não deve** ser usado em `who-uses`, `what-uses`, `impact-basic` nem `functional-trace-basic` — critério é cobertura do extrator, não “objeto irrelevante na KB”. Lista canônica: campo `queryableByKbIntelligence` em cada entrada do JSON (atualizada em 2026-05-30 com amostra multi-KB + grafo zero em `kb-intelligence.sqlite` de FabricaBrasil).
- `Evidência direta`: segunda passagem 2026-05-30 — tipos com `<Part>` no export mas **zero arestas** de entrada e saída no índice de FabricaBrasil (ex.: `SubTypeGroup` 710 objetos, `Image` 251, `Theme`, `File`, `Module`, `PackagedModule`, `Stencil`, `UserControl`, `Panel`, …) passaram a `queryableByKbIntelligence=false`; `Query`, `DataView`, `WorkPanel` e similares **permanecem** `true` no catálogo enquanto não houver reclassificação explícita.
- `Regra editorial`: tipos que **permanecem** `queryableByKbIntelligence=true` apesar de grafo assimétrico (`API`, `DataSelector`, `WorkWithForWeb`, `ExternalObject`) estão documentados em `scripts/README-kb-intelligence.md` — consultas semânticas ainda podem informar dependências **de saída** ou entrada esparsa; não confundir com “sem impacto”.
- `Evidência direta`: `Attribute` tem envelope próprio e diferente de todos os demais — raiz `<Attributes><Attribute>` no lugar de `<Object type="...">`. Possui `<Part type="...">` interno, mas não segue o envelope padrão.
- `Inferência forte`: a ausência de `<Part>` em um XML não indica objeto vazio ou corrompido — pode ser a estrutura normal do tipo.
- `Inferência forte`: para este acervo, o GUID em `Object/@type` é um identificador estável do tipo extraído do objeto.
- `Regra editorial`: na base XPZ, cada `objectTypeGuid` registrado em `scripts/gx-object-type-catalog.json` é tratado como **estável** para o tipo GeneXus correspondente — não se assume mudança de GUID em upgrades menores do GeneXus nem em novas versões de addons (K2BTools, SmartDevicesPlus, etc.) salvo evidência contrária documentada.
- `Hipótese`: o mesmo catálogo de `Object/@type` e `Part/@type` pode se repetir em outros exports GeneXus 18, mas isso não foi provado aqui para todos os tipos.

## Referência de Tipos de Objeto GeneXus

Tipos que geram arquivo XML próprio no acervo. Containers de organização estão na seção seguinte.

- `Regra editorial`: a fonte técnica canônica executável desta lista fica em `scripts/gx-object-type-catalog.json`.
- `Regra editorial`: este catálogo cobre **só** tipos modernos identificados por GUID em `Object/@type`. Elementos de export **legado GeneXus 9** (`ExportFile` com `<GXObject><Elemento>` por **nome**, sem GUID de tipo) ficam **fora** deste catálogo, no registro próprio `scripts/gx-legacy-export-element-registry.json` (doc-dono `01k-registro-elementos-legados.md`) — não inventar GUID nem reusar o GUID do tipo moderno sucessor para representar um elemento legado.
- `Regra editorial`: este documento continua como referência explicativa e histórica, não como ponto único de leitura por scripts.
- `Regra editorial`: na coluna Descrição, `queryableByKbIntelligence=false` indica que o motor atual do índice **não** deve ser usado em `who-uses`, `what-uses`, `impact-basic` nem `functional-trace-basic` (lista canônica no JSON). Tipos sem essa marca na tabela permanecem `true` no catálogo — inclusive com grafo assimétrico (`API`, `DataSelector`, `WorkWithForWeb`, `ExternalObject`; ver `scripts/README-kb-intelligence.md`).

| Tipo | GUID em `Object/@type` | Descrição | Dir. Sugerido |
| --- | --- | --- | --- |
| `API` | `36e32e2d-023e-4188-95df-d13573bac2e0` | Interface de serviço REST ou SOAP | `API/` |
| `Attribute` | *(envelope próprio: `<Attributes><Attribute>`; sem `Object/@type`)* | Atributo de domínio da KB | `Attribute/` |
| `CategoryDiagram` | `280c149c-48b2-4284-a532-0c999df9e006` | Categoria/diagrama organizacional exportado pela KB | `CategoryDiagram/` |
| `ColorPalette` | `3affc0b3-494b-4d84-9ec1-3a6ab8349cda` | Paleta de cores para temas; `queryableByKbIntelligence=false` | `ColorPalette/` |
| `Dashboard` | `526aba9f-a725-4bc7-b1db-0b9f92ac9550` | Painel visual composto; `queryableByKbIntelligence=false` | `Dashboard/` |
| `DataProvider` | `2a9e9aba-d2de-4801-ae7f-5e3819222daf` | Fonte de dados parametrizada | `DataProvider/` |
| `DataSelector` | `ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af` | Seletor de dados reutilizável | `DataSelector/` |
| `DataView` | `19abc6ff-2cd2-0000-0006-6d172bc2333b` | Data View (mapeamento de tabela externa; `DataViewAttribute`, plataformas) | `DataView/` |
| `DataStore` | `dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0` | Configuração de repositório de dados; `queryableByKbIntelligence=false` | `DataStore/` |
| `DeploymentUnit` | `bf08dfb1-361c-4e7e-ad54-391e56e60b49` | Unidade de empacotamento para deploy; `queryableByKbIntelligence=false` | `DeploymentUnit/` |
| `DesignSystem` | `78b3fa0e-174c-4b2b-8716-718167a428b5` | Design System; `queryableByKbIntelligence=false` | `DesignSystem/` |
| `Document` | `faeb588c-dcce-4dad-9af3-cdd11b961a32` | Documento de conhecimento (wiki interna); `queryableByKbIntelligence=false` | `Document/` |
| `Domain` | `00972a17-9975-449e-aab1-d26165d51393` | Domínio (tipo de dado reutilizável) | `Domain/` |
| `ExternalObject` | `c163e562-42c6-4158-ad83-5b21a14cf30e` | Wrapper de API ou biblioteca nativa | `ExternalObject/` |
| `File` | `1132ac08-290f-4fd1-bd18-64777b7329d1` | Arquivo estático embarcado; `queryableByKbIntelligence=false` | `File/` |
| `Generator` | `ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0` | Gerador de código; `queryableByKbIntelligence=false` | `Generator/` |
| `Image` | `9fb193d9-64a4-4d30-b129-ff7c76830f7e` | Recurso de imagem; `queryableByKbIntelligence=false` | `Image/` |
| `Language` | `88313f43-5eb2-0000-0028-e8d9f5bf9588` | Configuração de idioma; `queryableByKbIntelligence=false` | `Language/` |
| `Panel` | `d82625fd-5892-40b0-99c9-5c8559c197fc` | Panel para dispositivos móveis (SmartDevices); `queryableByKbIntelligence=false` | `Panel/` |
| `PatternSettings` | `83476c1e-fa72-4229-9930-f51b954fca2d` | Configuração de padrão aplicado; `queryableByKbIntelligence=false` | `PatternSettings/` |
| `Procedure` | `84a12160-f59b-4ad7-a683-ea4481ac23e9` | Procedure (código GeneXus) | `Procedure/` |
| `Query` | `926a06b9-3417-4ab4-9f8c-09c2f626bb1c` | Query object GeneXus (`QueryElement`, filtros, parâmetros, chart/card settings) | `Query/` |
| `SDT` | `447527b5-9210-4523-898b-5dccb17be60a` | Structured Data Type | `SDT/` |
| `SmartDevicesApplication` | `9bdcc055-174e-4af6-96cb-a2ceef6c5f09` | Aplicação Smart Devices do addon SmartDevicesPlus/WWPM (dashboard + eventos em `Source`; **não** é o tipo `Dashboard` do catálogo) | `SmartDevicesApplication/` |
| `SmartDevicesPlus` | `c84ec0ea-d159-46e2-a118-2108860379bb` | Objeto de configuração global do addon Smart Devices Plus (`SDPlus_Settings_*` em `Properties`; pai típico `RootModule`); no catálogo técnico `queryableByKbIntelligence=false` — inventário sim, `who-uses`/`impact-basic` não | `SmartDevicesPlus/` |
| `Stencil` | `624a8b31-36f0-4292-adba-2d270d1e3537` | Stencil de pattern; `queryableByKbIntelligence=false` | `Stencil/` |
| `SubTypeGroup` | `87313f43-5eb2-41d7-9b8c-e8d9f5bf9588` | Grupo de subtipos de domínio; `queryableByKbIntelligence=false` | `SubTypeGroup/` |
| `Table` | `857ca50e-7905-0000-0007-c5d9ff2975ec` | Índice ou tabela de base de dados | `Table/` |
| `Theme` | `c804fdbd-7c0b-440d-8527-4316c92649a6` | Tema visual completo; `queryableByKbIntelligence=false` | `Theme/` |
| `ThemeClass` | `d4876646-98dd-419b-8c1c-896f83c48368` | Classe dentro de um tema; `queryableByKbIntelligence=false` | `ThemeClass/` |
| `ThemeColor` | `5592de59-d30a-499d-9100-a7006d3674f2` | Cor nomeada dentro de um tema; `queryableByKbIntelligence=false` | `ThemeColor/` |
| `Transaction` | `1db606f2-af09-4cf9-a3b5-b481519d28f6` | Transação (formulário + modelo de dados) | `Transaction/` |
| `UserControl` | `562f4793-aabe-449f-8821-fc77e550698e` | User Control customizado; `queryableByKbIntelligence=false` | `UserControl/` |
| `WebPanel` | `c9584656-94b6-4ccd-890f-332d11fc2c25` | Tela web (eventos e layout) | `WebPanel/` |
| `WorkPanel` | `198e8ea4-1d49-4c9c-8a9a-417024baa9d1` | Work Panel legado GeneXus (deprecated desde GeneXus 15); `Form Type=Windows` | `WorkPanel/` |
| `WorkWithForWeb` | `78cecefe-be7d-4980-86ce-8d6e91fba04b` | Work With For Web (gerado por padrão) | `WorkWithForWeb/` |
| `WorkWithPlusInstance` | `07135890-56fc-489b-b408-063722fa9f7d` | Instância do Pattern WorkWithPlus (third-party) aplicada a objeto GeneXus, tipicamente `WebPanel`; XML traz `Pattern="07135890-…"` | `WorkWithPlusInstance/` |
| `WorkWithPlusTemplate` | `083f1b21-5715-45e1-8a8d-ceadef141e02` | Template do WorkWithPlus (`WWPTemplate_Type`, `WWPTemplate_TemplateXml`) | `WorkWithPlusTemplate/` |

- `Evidência direta` (KB `NewWaySystem`, XPZ `NewWaySystem16052026FULL.xpz`, 2026-05-16): as linhas `Query`, `WorkPanel`, `WorkWithPlusInstance` e `WorkWithPlusTemplate` acima foram registradas a partir de bloqueio do `Sync-GeneXusXpzToXml.ps1` por GUIDs desconhecidos. Contagens observadas naquele XPZ: `WorkWithPlusInstance` = 420 (ex.: `WorkWithPlusHome`, `WorkWithPlusGAMApplicationEntry`); `WorkWithPlusTemplate` = 67 (ex.: `ListNoBaseTable`, `Dashboard1`, `CardWithMainImage`); `Query` = 31 (ex.: `QVendaPeriodo`, `QFaturamentoPeriodo`); `WorkPanel` = 1 (`ImpressaoEtiqueta`). As contagens do panorama no início deste documento referem-se ao acervo FabricaBrasil e não foram refeitas.
- `Evidência direta` (KB `Evo1`, GeneXus `18.0.13.186738` U13, XPZ/XML 2026-05): `DataView` = 8 (ex.: `Tgol421`, `CEP001`); `SmartDevicesApplication` = 2 (`Evo`, `MDFSampleApp`); `SmartDevicesPlus` = 1 (`SmartDevicesPlus`, propriedades `SDPlus_Settings_*`). XML com `DataViewAttribute` / `DataViewStructurePlatform`, `Dashboard` embutido em `Part`, e `parentGuid`/`moduleGuid` apontando para `RootModule` (`afa47377-41d5-4ae8-9755-6f53150aa361`). Pesquisa C4: wiki GeneXus (Data View), docs WorkWithPlus (addon SDP), fórum 2015 com o mesmo GUID de `SmartDevicesApplication` em erro de import.

## Containers de organização da KB

Estes não são tipos de objeto programáveis. São a infraestrutura de organização da KB. O nome do diretório no acervo local **não é indicador confiável de tipo entre KBs** — use sempre o GUID em `Object/@type`.

| Container | GUID em `Object/@type` | Descrição | Dir. Sugerido |
| --- | --- | --- | --- |
| Pasta de sistema | `00000000-0000-0000-0000-000000000006` | Pastas internas do GeneXus (Main Programs, ToBeDefined); **nunca** é `parentType` válido de objetos exportáveis; `queryableByKbIntelligence=false` | `Module/` |
| Pasta/Módulo do usuário | `00000000-0000-0000-0000-000000000008` | Container criado pelo usuário; a IDE exibe como "Module/Folder" no painel Properties; `queryableByKbIntelligence=false` | `Folder/` |
| Módulo instalado | `c88fffcd-b6f8-0000-8fec-00b5497e2117` | Módulos GeneXus instalados (GAM, módulos de pacote); ícone de cubo na IDE; `queryableByKbIntelligence=false` | `PackagedModule/` |
| RootModule | `afa47377-41d5-4ae8-9755-6f53150aa361` | Raiz virtual da KB; **não gera arquivo XML** no acervo; aparece apenas como `parentGuid`/`moduleGuid`; `queryableByKbIntelligence=false` | *(sem pasta)* |

## Padrões internos observados por grupos

### `Procedure`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\Procedure\PRCExemplo0001.xml` aparecem `Part type="528d1c06-a9c2-420d-bd35-21dca83f12ff"`, `9b0a32a3-de6d-4be1-a4dd-1b85d3741534`, `e4c4ade7-53f0-4a56-bdfd-843735b66f47`, `ad3ca970-19d0-44e1-a7b7-db05556e820c` e `babf62c5-0111-49e9-a1c3-cc004d90900a`.
- `Evidência direta`: nesse mesmo XML há um trecho `parm(...)` dentro de um bloco `Part`, o que mostra que parâmetros podem estar armazenados separadamente do código principal.
- `Inferência forte`: objetos em `Procedure` usam um conjunto recorrente de `Part type` para código, parâmetros, variáveis e propriedades, mas esta documentação não nomeia semanticamente cada `Part type` além do que foi visto.

### `WebPanel`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\WebPanel\WPExemplo0001.xml` há um `Source` com `GxMultiForm`.
- `Evidência direta`: no mesmo arquivo há outro `Source` com blocos `Event`.
- `Inferência forte`: em `WebPanel`, layout declarativo e código de eventos tendem a aparecer em partes distintas do XML.

### Persistencia real de propriedades em `WebPanel`

- `Evidência direta`: numa releitura operacional posterior de `1197` `WebPanel`, os `7` `Part type` recorrentes do tipo continuaram presentes em `100%` dos casos.
- `Evidência direta`: o `Part type="d24a58ad-57ba-41b7-9e6e-eaca3543c778"` concentrou o layout declarativo e a quase totalidade das propriedades estruturais de controle observadas nesta frente.
- `Evidência direta`: `PATTERN_ELEMENT_CUSTOM_PROPERTIES` apareceu em `411/1197` `WebPanel`, sempre no `Source` do `Part` de layout.
- `Evidência direta`: `WebUserControlProperties` apareceu em `172/1197` `WebPanel`, sempre no `Source` do `Part` de layout.
- `Evidência direta`: `ControlWhere` apareceu em `101/1197` casos; `100` deles vieram do `Part` de layout, serializados dentro de propriedades de controle, e `1` caso apareceu em `Part` de variáveis.
- `Evidência direta`: `ControlBaseTable` apareceu em `23/1197`, `ControlOrder` em `86/1197` e `ControlUnique` em `13/1197`; nesses casos, a persistência observada ficou concentrada no `Source` do `Part` de layout, dentro de metadado serializado de controles.
- `Evidência direta`: o `Part type="763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9"` apareceu em `1197/1197` `WebPanel`, mas só `141` casos tinham `Source` não vazio nesse `Part`.
- `Evidência direta`: `Conditions` como filtro materializado apareceu nesses `141` casos via `Source` do `Part` `763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9`, e não como atributo do layout.
- `Evidência direta`: a busca textual por `Conditions` supercontou casos de template, porque `183` objetos usavam `ViewConditions.dkt` e `179` usavam `TabGridConditions.dkt` apenas em metadado de `Defaults`.
- `Evidência direta`: em `Prompt`/`Selection List`, a materialização de filtro no `Part` de `Conditions` foi forte: `92/100` `prompt*` tinham `Source` não vazio nesse `Part`, e os `30` casos com `Selection List` pertenciam a essa familia.
- `Evidência direta`: em `FreeStyleGrid`, houve `10` casos; todos tinham `ControlWhere` no layout, `8/10` tinham `ControlOrder` e `9/10` tinham `WebUserControlProperties`.
- `Evidência direta`: em grids tradicionais com tag `<grid`, houve `26` casos; `16` com `ControlWhere`, `9` com `ControlBaseTable`, `14` com `ControlOrder` e `5` com `ControlUnique`.
- `Evidência direta`: em controles com `Dynamic Combo Box`, houve `58` casos; `56` deles coexistiam com `ControlWhere` no layout e `50` com `WebUserControlProperties`.
- `Exemplo sanitizado`: `WPExemploSelectionPromptA` mostra `Selection List` com filtro materializado no `Part` de `Conditions`, enquanto `ControlOrder` e `WebUserControlProperties` permanecem no layout.
- `Exemplo sanitizado`: `WPExemploGridEstruturalA` mostra grid tradicional com `ControlBaseTable`, `ControlOrder`, `ControlWhere` e `ControlUnique` serializados no layout.
- `Exemplo sanitizado`: `WPExemploComboDinamicoA` mostra `Dynamic Combo Box` com `ControlWhere` persistido no layout e configuração adicional em `WebUserControlProperties`.
- `Exemplo sanitizado`: `WPExemploGridLivreA` mostra `FreeStyleGrid` com filtro persistido no layout via `ControlWhere`, junto com metadado adicional de controle no mesmo `Part`.
- `Exemplo sanitizado`: `WPExemploConditionsTemplateA` mostra caso em que o termo `Conditions` aparece só por `Defaults` de template, sem filtro materializado no `Source` do `Part` de condições.
- `Inferência forte`: para `WebPanel`, "a propriedade existe no XML" e "a propriedade persiste no mesmo lugar em todas as familias" são afirmacoes diferentes; o ponto de persistencia varia por familia e por tipo de controle.
- `Inferência forte`: para trilha `xpz-*`, a leitura segura e distinguir pelo menos `Conditions` materializado em `Part` próprio, metadado de layout serializado e defaults de template antes de decidir clonagem, comparacao ou documentação.

### `Transaction`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\Transaction\TRNExemplo0001.xml` e `TRNExemplo0002.xml` aparecem nós `<Level ...>` e vários `<AttributeProperties Attribute="...">`.
- `Inferência forte`: objetos em `Transaction` carregam estrutura hierárquica e configuração de atributos dentro de `Part type` próprios.

### `SDT`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\SDT\SDTExemplo0001.xml` aparecem `<Level>`, `<LevelInfo>` e `<Item>`.
- `Inferência forte`: no acervo observado, `SDT` representa estrutura hierárquica declarada, distinta do padrão de `Transaction`.

### `SubTypeGroup`

- `Evidência direta`: em `C:\SANITIZED\ObjetosDaKbEmXml\SubTypeGroup\STGExemplo0001.xml` aparecem vários nós `<Subtype guid="...">`.
- `Inferência forte`: `SubTypeGroup` registra vínculos de subtype/supertype por GUID e nome, não regras procedurais.

### `ThemeClass`

- `Evidência direta`: arquivos como `ActionAttribute.xml` e `ActionButtons.xml` contêm propriedades `ThemeElementThemeTypes` e `ThemeElementInternalType`.
- `Inferência forte`: essas propriedades são marcadores estáveis para reconhecer objetos do diretório `ThemeClass` neste acervo.

### `WorkWithForWeb`

- `Evidência direta`: arquivos como `WorkWithWebTRNExemplo0001.xml` exibem `Object/@name` iniciando com `WorkWithWeb`.
- `Evidência direta`: nesses mesmos arquivos aparece `<Data Pattern="78cecefe-be7d-4980-86ce-8d6e91fba04b">`.
- `Inferência forte`: os XMLs em `WorkWithForWeb` guardam configuração de artefatos gerados por padrão web associada ao objeto pai.

## Relações aparentes observadas

- `Evidência direta`: muitos objetos trazem `parent`, `parentGuid` e `parentType` no próprio nó `<Object>`.
- `Evidência direta`: objetos em `WorkWithForWeb` usam `parentType="1db606f2-af09-4cf9-a3b5-b481519d28f6"` quando ligados a `Transaction`, como em `WorkWithWebTRNExemplo0001.xml`.
- `Evidência direta`: `WebPanel\WPExemplo0001.xml` referencia outros objetos no código de eventos, como `WPExemploA`, `WWExemploA`, `WWExemploB` e `WPExemploB`.
- `Inferência forte`: dependências entre objetos podem ser detectadas combinando `parent*`, referências em propriedades e chamadas nominais em blocos de código.
- `Hipótese`: uma etapa futura pode transformar essas relações aparentes em um grafo de dependências mais confiável, desde que haja validação adicional por tipo de objeto.

## Leitura cautelosa dos GUIDs de `Part type`

- `Evidência direta`: o inventário bruto catalogou GUIDs de `Part type` por ocorrência.
- `Inferência forte`: alguns `Part type` aparecem recorrentemente dentro do mesmo grupo de objetos e podem ser usados como assinatura estrutural.
- `Hipótese`: o significado funcional exato de cada `Part type` ainda precisa ser rotulado com validação mais fina, objeto a objeto.

## Limites desta consolidação

- `Evidência direta`: o acervo foi analisado já decomposto em XMLs por objeto, não como o `XPZ` binário/original completo.
- `Inferência forte`: a documentação atual descreve bem a organização dos XMLs extraídos desta KB.
- `Hipótese`: ainda não é seguro generalizar todos os padrões acima para qualquer KB GeneXus 18 sem nova amostragem.

## Evidencia complementar - consulta ao acervo real após a bateria de importação

## Papel do complemento
empirico complementar

## Objetivo
Registrar o que a leitura direta do acervo real em `C:\SANITIZED\ObjetosDaKbEmXml` acrescentou aos resultados da bateria controlada de importação.
Separar com mais precisao o que e falta de shape, o que e dependencia semantica da KB e o que e apenas diferenca de nomenclatura reconhecida pela IDE.

- `Evidência direta`: a consulta real foi direcionada aos tipos que ficaram problemáticos ou ambíguos na bateria: `Folder`, `PatternSettings`, `Theme`, `API`, `Transaction` e depois também `Attribute`.
- `Evidência direta`: numa primeira passada em `C:\SANITIZED\ObjetosDaKbEmXml`, `Attribute` não apareceu como diretório próprio e os atributos observados surgiam principalmente embutidos em `Transaction`.
- `Evidência direta`: depois foi consultado um XML extraido de export full da KB em caminho privado sanitizado, onde apareceram objetos `Attribute` top-level com raiz `<Attribute ... name="...">`.
- `Evidência direta`: esses `Attribute` top-level foram extraidos para `C:\SANITIZED\ObjetosDaKbEmXml\Attribute` e a pasta foi saneada para manter apenas os atributos reais, removendo referencias inline.
- `Inferência forte`: `Attribute` deixou de estar sem evidencia top-level; o risco atual passa a ser distinguir definicao real de atributo contra ocorrência contextual dentro de outros objetos.

### `Folder`

- `Evidência direta`: exemplos reais em `ObjetosDaKbEmXml\Folder\` (ex.: `ACESSO.xml`, `APIs.xml`) usam `Object/@type="00000000-0000-0000-0000-000000000008"`.
- `Evidência direta`: o shape XML de `Folder` é mínimo — sem elemento `<Part>`, apenas `<Properties>` com `Name` e `IsDefault`.
- `Evidência direta`: o campo `moduleGuid` aponta para o Root Module (`afa47377-41d5-4ae8-9755-6f53150aa361`) ou para outro container `...0008`; `parentType` é `00000000-0000-0000-0000-000000000008` quando o folder pai é também um folder de usuário.
- `Inferência forte`: `Folder` (`...0008`) é o container criado pelo usuário na IDE ("New Folder" / "New Module"); a IDE exibe o nome na propriedade "Module/Folder" no painel Properties, mas o GUID canônico do tipo é `...0008` e o diretório de acervo é `Folder/`.

### `Module`

- `Evidência direta`: exemplos reais em `ObjetosDaKbEmXml\Module\` (ex.: `Main Programs.xml`, `ToBeDefined.xml`, `GAM.xml`) usam `Object/@type="00000000-0000-0000-0000-000000000006"`.
- `Evidência direta`: o shape XML de `Module` inclui `<Part type="babf62c5-0111-49e9-a1c3-cc004d90900a">` com `<Properties />` vazio, mais propriedades adicionais em `<Properties>`: `Name`, `ShowInModelTree`, `Query`, `Properties` (ex.: `main_program=true`), `IsDefault`.
- `Evidência direta`: o campo `moduleGuid` é `00000000-0000-0000-0000-000000000000` (sem módulo pai — nível raiz da KB); `Main Programs` e `ToBeDefined` têm `parentGuid` e `moduleGuid` zerados.
- `Inferência forte`: `Module` (`...0006`) agrupa tanto containers de sistema internos do GeneXus (`Main Programs`, `ToBeDefined`) quanto módulos de pacote instalados (`GAM`, `GAM_Frontend-web`) — todos residem no diretório `Module/` do acervo.
- `Inferência forte`: objetos `...0006` nunca aparecem como `parentType` de objetos exportáveis pelo usuário; são containers organizacionais do motor GeneXus, não da lógica da aplicação.

### `PatternSettings`

- `Evidência direta`: os exemplos reais `WorkWith.xml` e `WorkWithDevices.xml` guardam configuração dentro de `<Data Pattern="..."> <![CDATA[ ... ]]> </Data>`.
- `Evidência direta`: o XML interno referencia IDs de `Pattern`, `ContextVariable`, `LoadProcedure`, `Security` e outros artefatos associados ao pattern registrado.
- `Inferência forte`: `PatternSettings` não deve ser tratado como objeto declarativo autocontido; ele depende fortemente do pattern correspondente estar registrado no ambiente de destino.
- `Evidência direta`: num teste posterior isolado com o objeto real `WorkWith`, `Pattern Settings 'WorkWith'` importou com sucesso no ambiente de teste.
- `Inferência forte`: `PatternSettings` deixa de ser uma pendencia estrutural aberta nesta trilha; o ponto operacional passa a ser usar caso real compativel com pattern efetivamente reconhecido no alvo.

### `Theme`

- `Evidência direta`: o exemplo real `ThemeExemploMobileA.xml` contem `PredefinedTypes` e classes visuais concretas como `TableDetail`, `TableSection` e `TextBlockGroupCaption`.
- `Evidência direta`: essas classes aparecem referenciadas por outras classes no próprio tema, por exemplo `Group` referencia `TextBlockGroupCaption` e `TableSection` referencia `HorizontalLine`.
- `Inferência forte`: um tema simples mas valido precisa preservar não apenas classes isoladas, e sim o grafo mínimo de classes referenciadas internamente.
- `Evidência direta`: num consolidado revisado posterior, o próprio `ThemeExemploMobileA` real foi importado no ambiente de teste e ainda assim falhou com `Theme class 'TableDetail' does not exist`, `Theme class 'TableSection' does not exist` e `Theme class 'TextBlockGroupCaption' does not exist`.
- `Evidência direta`: a pasta real `C:\SANITIZED\ObjetosDaKbEmXml\ThemeClass` contem objetos `ThemeClass` top-level separados para `TableDetail`, `TableSection` e `TextBlockGroupCaption`.
- `Evidência direta`: num teste isolado posterior, esses tres `ThemeClass` reais foram importados com sucesso e, logo em seguida, o `Theme 'ThemeExemploMobileA'` também importou com sucesso.
- `Inferência forte`: nesta trilha, `Theme` deixa de parecer um problema de serializacao pura; o requisito operacional observado e materializar também as `ThemeClass` auxiliares referenciadas pelo tema.

### `API`

- `Evidência direta`: nesta trilha, a KB observada traz apenas `1` objeto `API` real.
- `Evidência direta`: esse único caso real corresponde a uma construcao manual/local da KB, e não a uma familia ampla observada com múltiplos exemplos comparaveis.
- `Evidência direta`: nesta trilha documental, não ha evidencia de ferramenta complementar de automacao de `API` atuando sobre esse caso.
- `Evidência direta`: o exemplo real `APIExemploIntegracaoA.xml` usa varios `ATTCUSTOMTYPE` validos, incluindo `exo:GAMSession, GeneXusSecurity`, `exo:GAMError, GeneXusSecurity`, `exo:GAMUser, GeneXusSecurity`, `sdt:Messages, GeneXus.Common`, `sdt:SDTExemploProdutoBasicoA` e `sdt:SDTExemploTribSelecaoA`.
- `Evidência direta`: o mesmo exemplo também depende de `Procedure` e eventos reais no código fonte.
- `Inferência forte`: por haver apenas um caso real na KB, `API` deve ser lida aqui como estudo de caso operacional da KB analisada, e não como familia GeneXus já generalizavel nesta base.
- `Inferência forte`: em `API`, o envelope XML e relativamente bem definido, mas os tipos customizados e procedimentos referenciados precisam existir de fato na KB de destino.
- `Inferência forte`: não é seguro inventar `ATTCUSTOMTYPE`; ele deve copiar um valor comprovado ou apontar para tipo efetivamente existente no alvo.
- `Evidência direta`: num teste isolado posterior, os SDTs reais `SDTExemploProdutoBasicoA`, `SDTExemploProdutoBasicoB`, `SDTExemploProdutoBasicoC`, `SDTExemploProdutoBasicoD`, `SDTExemploTribA` e `SDTExemploTribSelecaoA` importaram com sucesso antes da tentativa da `API`.
- `Evidência direta`: nesse mesmo teste, `API 'APIExemploIntegracaoA'` deixou de falhar por `ATTCUSTOMTYPE` e passou a falhar por `Object Reference PRCExemploListaA not found`, `Invalid attribute 'DomainExemploTipoA'` e `'TRNExemploProdutoA' invalid property`.
- `Inferência forte`: o gargalo atual de `API` nesta trilha já não é mais tipagem `SDT`; ele ficou reduzido a `Procedure` e contexto de negocio realmente existentes na KB de destino.
- `Evidência direta`: numa rodada posterior, `Domain 'DomainExemploTipoA'` importou com sucesso e a `Procedure 'PRCExemploListaA'` foi localizada no acervo real.
- `Evidência direta`: ao tentar incluir essa `Procedure`, ela falhou por depender de uma cadeia grande de transacoes e atributos da entidade principal e de satelites relacionados, além de dominios auxiliares como `SimOuNao`, `DomainExemploGrupoA` e `DomainExemploLocalA`.
- `Evidência direta`: na mesma tentativa, a `API` avancou mais um passo e passou a falhar por outra `Procedure` faltante: `PRCExemploTribSelecaoA`.
- `Evidência direta`: essa segunda `Procedure` também existe no acervo real e, ao ser inspecionada, mostrou dependencia adicional de `Data Provider` (`DPExemploTribSelecaoA`), `Domain 'DomainExemploRomaneioA'` e atributos tributarios adicionais da cadeia funcional.
- `Inferência forte`: `API` entra definitivamente na zona de dependencia de negocio pesada; para este caso, fechar a importação deixou de ser tarefa de empacotar poucos objetos auxiliares e passou a exigir uma subarvore funcional relevante da KB.

### `Transaction`

- `Evidência direta`: exemplos reais como `TRNExemploComplexaA.xml` trazem `<Level ...>` com muitos `<Attribute ... guid="...">NomeDoAtributo</Attribute>` e varios blocos `<AttributeProperties Attribute="...">`.
- `Evidência direta`: no mesmo tipo aparecem variáveis nomeadas `Context`, `TrnContext` e `TrnContextAtt`, com `ATTCUSTOMTYPE` como `sdt:Context`, `sdt:TransactionContext` e `sdt:TransactionContext.Attribute`.
- `Inferência forte`: em `Transaction`, o shape estrutural pode ser inferido por familia, mas o objeto final continua dependente da existência real dos atributos e SDTs de contexto na KB.
- `Inferência forte`: a falha observada na bateria foi coerente com o acervo real; não faltava apenas envelope, faltavam atributos reais e tipos de contexto validos.
- `Evidência direta`: num teste isolado posterior, os `Attribute` reais de `TRNExemploMinBancoA`, o `SDT 'Context'` e o `SDT 'TransactionContext'` importaram com sucesso antes da tentativa da `Transaction`.
- `Evidência direta`: nesse mesmo teste, `Transaction 'TRNExemploMinBancoA'` importou com sucesso e ainda disparou geração de pattern bem-sucedida para `WWExemploMinBancoA`.
- `Evidência direta`: em outro teste prático controlado, uma `Transaction` mínima só foi importada com sucesso após a inclusao explicita dos `Attribute` top-level correspondentes no mesmo pacote.
- `Evidência direta`: nesse caso, os nos `<Attribute>` dentro de `<Level>` não bastaram para definir os atributos; eles funcionaram apenas como referencia contextual do `Level`.
- `Evidência direta`: numa bateria posterior de importação real, uma `Transaction` mínima também foi validada com `DescriptionAttribute` e `AttributeProperties`, desde que os `Attribute` top-level correspondentes estivessem presentes no pacote e o `Part` principal preservasse o shape esperado da familia.
- `Evidência direta`: nessa mesma bateria, `AttributeProperties` funcionou tanto isoladamente quanto combinado com `DescriptionAttribute`.
- `Evidência direta`: `DescriptionAttribute` foi aceito no caso mínimo expandido quando apontava para atributo existente no mesmo `Level`.
- `Inferência forte`: a distincao entre `Attribute` top-level e `Attribute` inline em `Level` continua essencial nos casos validados de montagem de pacote mínimo de `Transaction`.
- `Inferência forte`: `Transaction` fica destravada nesta trilha quando o pacote inclui os atributos top-level reais do `Level` e os SDTs de contexto exigidos pelo caso.

### `Attribute`

- `Evidência direta`: o XML extraido de export full da KB, mantido em caminho privado sanitizado, contem objetos `Attribute` top-level com raiz `<Attribute ...>`, e não `<Object ...>`.
- `Evidência direta`: um atributo real completo, como `AtributoExemploComplexoA`, traz atributos XML como `guid`, `name`, `fullyQualifiedName`, `description`, `moduleGuid`, `parentGuid`, além de `Part` e `Properties`.
- `Evidência direta`: no mesmo export também aparecem nos curtos `<Attribute key="True|False" guid="...">NomeDoAtributo</Attribute>` dentro de `<Level>` de `Transaction`.
- `Evidência direta`: os nos curtos compartilham o mesmo `guid` do atributo real top-level correspondente; eles funcionam como referencia contextual do atributo no nível da `Transaction`, não como definicao top-level.
- `Evidência direta`: na saneacao da pasta `C:\SANITIZED\ObjetosDaKbEmXml\Attribute`, permaneceram `7646` atributos reais top-level e foram removidas `8539` referencias inline `Attribute_*.xml`.
- `Evidência direta`: na ampliacao da busca para um diretório privado sanitizado do modelo GeneXus, nomes sugestivos como `GAMExampleUserCustomAttributes.xml` não se revelaram objeto `Attribute`; esse arquivo se apresentou como `Web Panel`.
- `Evidência direta`: arquivos como `KBExemplo18selectAttributes.Filters` se mostraram apenas configuracoes auxiliares de filtro/interface, não export de objeto `Attribute`.
- `Inferência forte`: `Attribute` top-level já está empiricamente provado nesta trilha, mas exige cuidado extra porque o mesmo nome de elemento XML também aparece como referencia inline em `Transaction`.
- `Inferência forte`: para montar ou extrair corpus de `Attribute`, o filtro correto não é “todo no chamado Attribute”, e sim apenas o no raiz completo com `name` e estrutura de `Part` e `Properties`.
- `Evidência direta`: no teste combinado posterior, `Attribute 'AtributoExemploTesteA'` já não falhou por shape; falhou em propriedade semantica, com `ControlItemDescription='AtributoExemploDescricaoRelacionada'` apontando para atributo desconhecido no destino.
- `Inferência forte`: `Attribute` saiu da zona “shape insuficiente” e entrou na mesma classe metodologica de dependencia contextual de KB em propriedades como `ControlItemDescription`, `idBasedOn` e outras referencias nominais a atributos reais.
- `Evidência direta`: num consolidado revisado posterior, o `Attribute 'AtributoExemploFechadoA'`, extraido do acervo real e sem `ControlItemDescription`, importou com sucesso.
- `Inferência forte`: `Attribute` passa a ser considerado estruturalmente destravado nesta trilha, desde que o caso escolhido seja top-level real e semanticamente fechado no ambiente de destino.

### `Table`

- `Evidência direta`: leitura direta de `228` objetos `Table` em `C:\SANITIZED\ObjetosDaKbEmXml\Table` confirma exatamente `2` `Part type` em `100%` dos casos — sem variação entre os exemplares.
- `Evidência direta`: `Part type="00000000-0000-0000-0002-000000000004"` contém `<Key>` com lista de `<Item guid="...">NomeDoAtributo</Item>`, representando a chave primária da tabela.
- `Evidência direta`: `Part type="a5c0e770-560d-0001-0001-7fe71c260de3"` contém `<Indexes>` com um ou mais `<TableIndex><Index ... type="9e750647-3679-0000-0100-2529de263960">`, representando os índices da tabela.
- `Evidência direta`: nenhum terceiro `Part type` foi encontrado em nível de `Object` nos 228 exemplares.
- `Evidência direta`: o nó `<Object>` de `Table` NÃO possui atributo `parent` por nome; possui apenas `parentGuid` e `moduleGuid`. Esse comportamento difere de `Transaction`, `Procedure` e outros tipos que carregam `parent` nominal — `Table` é a única família de tamanho relevante observada sem `parent` nomeado.
- `Evidência direta`: cardinalidade da chave primária nos 228 objetos: 1 campo (34 tabelas, 15%), 2 campos (106, 46%), 3 campos (59, 26%), 4 campos (15, 7%), 5 campos (9, 4%), 6 campos (5, 2%). Chaves compostas representam 85% do corpus.
- `Evidência direta`: número de índices por `Table`: mínimo 2, máximo 59, média 6,5 — observado nos 228 exemplares.
- `Evidência direta`: todos os `1480` objetos `Index` embutidos usam `type="9e750647-3679-0000-0100-2529de263960"` e contêm exatamente `1` `Part type` interno: `62cfa789-c127-0001-0100-77676175e433` (lista de `<Members>`).
- `Evidência direta`: dos 1480 índices, `1036` têm `Source="Automatic"` (gerados pelo GeneXus) e `444` têm `Source="User"` (definidos manualmente). Todo `Table` tem ao menos `1` índice `Type="Unique" Source="Automatic"` correspondente à chave primária.
- `Inferência forte`: `Table` não carrega referência explícita à `Transaction` correspondente no XML; a associação é feita por convenção nominal — mesmo nome de objeto.
- `Inferência forte`: o risco residual de `Table` está na reassociação correta com a `Transaction` no destino, não no envelope ou Part types — ambos são estruturalmente simples, fixos e sem variação entre famílias.

## Complemento posterior - IDE exportando `Table`, `Index` e `WorkWithForWeb`

- `Evidência direta`: o export isolado `XPZExemploTabelaA.xpz` contem `228` objetos top-level no tipo `857ca50e-7905-0000-0007-c5d9ff2975ec`.
- `Evidência direta`: esses objetos top-level de `Table` usam nomes iguais aos das `Transaction` correspondentes, e não uma convenção paralela exclusiva da camada física.
- `Evidência direta`: dentro de cada `Table` exportada aparecem blocos `<Indexes>` com filhos `<Index ... type="9e750647-3679-0000-0100-2529de263960">`.
- `Evidência direta`: o export isolado `XPZExemploIndiceVazioA.xpz` veio vazio, sem `Objects` nem `Attributes`.
- `Inferência forte`: nesta trilha da IDE, `Table` existe como familia top-level própria, enquanto `Index` aparece subordinado a `Table`, e não como conjunto top-level isolado.
- `Evidência direta`: o export `XPZExemploTabelaIndiceA.xpz` repetiu exatamente o mesmo comportamento de `Table`: `228` objetos top-level do tipo `857ca50e-7905-0000-0007-c5d9ff2975ec` e nenhum objeto top-level adicional para `Index`.
- `Inferência forte`: pedir `Table + Index` explicitamente na IDE não muda a forma de serializacao observada; `Index` continua consolidado dentro de `Table`.
- `Evidência direta`: em `WorkWithForWeb` real, as referencias de atributo dentro do `CDATA` do pattern usam o prefixo estrutural fixo `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`.
- `Inferência forte`: para `WorkWithForWeb`, esse formato deve ser tratado como convenio estrutural do pattern, e não como reflexo do GUID do `Attribute` top-level nem do GUID inline do `Level` da `Transaction`.
- `Evidência direta`: o export `XPZExemploTabelaTRNWWPatternA.xpz` veio com `596` objetos: `228` `Table`, `183` `Transaction`, `183` `WorkWithForWeb` e `2` `PatternSettings`, sem `Attributes`.
- `Evidência direta`: o export `XPZExemploTabelaTRNDataSelectorA.xpz` veio com `413` objetos: `228` `Table`, `183` `Transaction` e `2` `DataSelector`, também sem `Attributes`.
- `Evidência direta`: no export combinado com `WorkWithForWeb`, a `Transaction` mantem a propriedade `Apply:78cecefe-be7d-4980-86ce-8d6e91fba04b=True`.
- `Evidência direta`: no mesmo export, `PatternSettings 'WorkWith'` materializa `ContextVariable`, `LoadProcedure`, `Security Check` e `NotAuthorized` no XML interno.
- `Inferência forte`: a ponte operacional real do pattern web observado fica distribuida entre `Transaction` (aplicação do pattern), `WorkWithForWeb` (instancia por objeto), `PatternSettings` (configuração global do pattern) e `Table` (camada física com índices internos).
- `Evidência direta`: o par de exports `XPZExemploTRNWWComparacaoSemWW.xpz` e `XPZExemploTRNWWComparacaoComWW.xpz` forneceu um recorte mínimo comparavel da mesma `Transaction 'TRNExemploMinPaisA'`.
- `Evidência direta`: `XPZExemploTRNWWComparacaoSemWW` veio com `7` objetos, `10` atributos top-level e `25` identidades; `XPZExemploTRNWWComparacaoComWW` veio com `8` objetos, os mesmos `10` atributos e `49` identidades.
- `Evidência direta`: a única diferenca de objeto entre os dois recortes foi a entrada de `WWExemploMinPaisA`.
- `Evidência direta`: apesar disso, a entrada de `WWExemploMinPaisA` quase dobrou o total de identidades de contexto em `ObjectsIdentityMapping`, incluindo referencias adicionais a `DomainExemploUfA`, `WPExemploRelacionamentoA`, `WPExemploAtualizacaoServidorA` e atributos relacionados.
- `Inferência forte`: num caso mínimo real, incluir `WorkWithForWeb` acrescenta pouco no bloco `<Objects>`, mas pode expandir bastante o grafo de contexto que o pacote precisa descrever em `ObjectsIdentityMapping`.

## Complemento posterior - export combinado de `API` e da pilha visual

### `Table + Domain + Transaction + SDT + API + Procedure + DataProvider`

- `Evidência direta`: o export `XPZExemploCadeiaAPIA.xpz` veio com `3904` objetos e `0` atributos top-level.
- `Evidência direta`: a distribuicao observada foi `2282` `Procedure`, `594` `SDT`, `593` `Domain`, `228` `Table`, `183` `Transaction`, `24` `DataProvider` e `1` `API`.
- `Evidência direta`: o `API` exportado nesse pacote e `APIExemploIntegracaoA`.
- `Evidência direta`: o mesmo pacote prova que a trilha real de export da IDE para `API` relevante de negocio já puxa junto uma massa grande de `Procedure`, `SDT`, `Domain`, `Table`, `Transaction` e `DataProvider`.
- `Evidência direta`: no pacote, ha `Domain` enumerado como `DomainExemploTipoA`, com valores de negocio distintos no mesmo conjunto exportado.
- `Evidência direta`: no mesmo recorte, `SDT` como `SDTExemploProdutoBasicoA` e `Procedure` como `PRCExemploListaA` aparecem no mesmo conjunto exportado.
- `Inferência forte`: para `API`, o melhor recorte de engenharia reversa deixa de ser o objeto isolado e passa a ser essa combinacao funcional mais ampla.
- `Inferência forte`: isso reforca a leitura anterior de que a pendencia remanescente de `API` não é serializacao do envelope, e sim dependencia de subarvore funcional de negocio.

### `Table + Transaction + ColorPalette + DesignSystem + Theme + WebTheme + Category + ThemeClass + ThemeColor`

- `Evidência direta`: o export `XPZExemploTemaA.xpz` veio com `947` objetos e `0` atributos top-level.
- `Evidência direta`: a distribuicao observada foi `501` `ThemeClass`, `228` `Table`, `183` `Transaction`, `24` `ThemeColor`, `7` `Theme`, `2` `DesignSystem`, `1` `Folder` e `1` `ColorPalette`.
- `Evidência direta`: o pacote contem uma pasta organizacional `GAM_Samples-web`, reforcando que a familia visual também pode carregar o agrupador estrutural junto.
- `Evidência direta`: o mesmo pacote mostrou `ThemeClass` como `ActionAttribute`, `ActionButtons` e `ActionButtonsHovered`, além de varios `ThemeColor` e `Theme` reais.
- `Evidência direta`: nesse export, `Theme`, `ThemeClass`, `DesignSystem`, `ColorPalette` e `ThemeColor` aparecem juntos no mesmo recorte exportado pela IDE.
- `Inferência forte`: a pilha visual completa pode e deve ser estudada como familia combinada, e não como tipos totalmente independentes.
- `Inferência forte`: esse recorte reduz o risco de interpretar `Theme`, `ThemeClass`, `DesignSystem`, `ColorPalette` e `ThemeColor` fora do contexto visual em que a IDE os serializa de fato.

### `Attribute + Domain + Transaction + SubtypeGroup`

- `Evidência direta`: o export `XPZExemploFamiliaMistaA.xpz` veio com `1117` objetos, `7646` atributos top-level e `1576` identidades em `ObjectsIdentityMapping`.
- `Evidência direta`: o contêiner desse pacote usou `KMW`, `Source`, `Objects`, `Attributes`, `Dependencies` e `ObjectsIdentityMapping`.
- `Evidência direta`: a presenca simultanea de `Objects` e `Attributes` top-level no mesmo `.xpz` confirma que a trilha normal da IDE também pode exportar familia mista de objetos e atributos reais, e não apenas pacotes com `Objects` sem bloco `Attributes`.
- `Inferência forte`: para engenharia reversa de `Attribute` top-level e de sua relacao com `Transaction`, `Domain` e `SubtypeGroup`, esse recorte e mais informativo do que os pacotes sem `Attributes`.

### `Attribute + Domain + Transaction + SubtypeGroup + Table + Index`

- `Evidência direta`: o export `XPZExemploFamiliaMistaB.xpz` veio com `1712` objetos, os mesmos `7646` atributos top-level e `1611` identidades.
- `Evidência direta`: esse pacote também usou o contêiner `KMW`, `Source`, `Objects`, `Attributes`, `Dependencies` e `ObjectsIdentityMapping`.
- `Evidência direta`: a diferenca de `1117` para `1712` objetos entre os dois pacotes coincide com a entrada da camada física `Table`, enquanto o bloco de `Attributes` permaneceu estavel em `7646`.
- `Inferência forte`: isso reforca que `Table/Index` entram como ampliacao da familia lógica anterior, sem deslocar `Attribute` top-level para dentro de `Objects` nem eliminar o bloco `Attributes`.

### Sintese operacional provisoria de `Table/Index`

- `Evidência direta`: na trilha observada, `Table` aparece como objeto top-level exportavel, enquanto `Index` aparece embutido dentro de `Table`.
- `Evidência direta`: pedir `Table + Index` na IDE não criou objetos top-level adicionais de `Index`; a serializacao observada permaneceu centrada em `Table`.
- `Evidência direta`: os nomes top-level de `Table` acompanham os nomes das `Transaction` correspondentes.
- `Evidência direta`: em comparacao privada posterior de pares reais simples e densos da KB de origem, essa correspondencia nominal `Transaction` -> `Table` também se repetiu fora dos pacotes já resumidos na base.
- `Evidência direta`: na mesma comparacao privada, os `Index` seguiram aparecendo apenas no bloco interno `<Indexes>` do objeto físico, e não como objeto top-level separado.
- `Evidência direta`: nessa mesma amostra privada, a lista de atributos-chave do primeiro `Level` da `Transaction` coincidiu com a lista do bloco `<Key>` da `Table`, tanto em chave simples quanto em chave composta.
- `Evidência direta`: na amostra privada comparada, cada `Table` observada trouxe exatamente `1` índice `Unique` automático para a chave e um conjunto variável de índices `Duplicate`, misturando casos `Automatic` e `User`.
- `Evidência direta`: nos mesmos pares privados comparados, todos os membros de índices `Automatic` observados já estavam presentes no primeiro `Level` da `Transaction` correspondente.
- `Evidência direta`: na KB analisada, prefixo `I` identifica índice automaticamente criado pelo GeneXus a partir de PK ou FK definidas pelo modelador.
- `Evidência direta`: na mesma KB, prefixo `U` identifica índice criado manualmente pelo operador humano.
- `Evidência direta`: quando um índice automático `I...` recebe nome mais descritivo nesta KB, a mudanca e apenas editorial; os campos e sua ordem permanecem exatamente os mesmos do índice criado pelo GeneXus.
- `Evidência direta`: o naming default do GeneXus para esses índices automáticos e pouco descritivo, normalmente centrado no nome da `Table` com numeração incremental nos casos seguintes.
- `Evidência direta`: nos índices automáticos de FK, os campos seguem a mesma ordem definida pelo modelador na relacao da `Transaction` e refletida na `Table`.
- `Evidência direta`: na mesma amostra privada, os índices `Automatic` `Duplicate` apareceram principalmente em dois formatos recorrentes: atributo único `...Id` e pares `...EmpresaId + ...Id|...Codigo`.
- `Evidência direta`: nessa mesma investigacao privada, muitos atributos `...Id` e `...Codigo` presentes no primeiro `Level` não reapareceram em índices `Automatic`, inclusive em objetos mais densos.
- `Evidência direta`: os nomes amigaveis observados para varios índices `Duplicate` refletem convencao editorial/local da KB analisada, e não devem ser tratados como padrão default do GeneXus.
- `Evidência direta`: os nomes mais amigaveis, abreviacoes e formas descritivas observadas em varios índices desta KB surgem da renomeacao humana para facilitar manutencao, leitura de erro e leitura de log; não devem ser lidos como naming automático do GeneXus nem como resposta normal a limite de 63 caracteres.
- `Evidência direta`: numa ampliacao posterior da amostra privada para todo o conjunto local de `Table`, os formatos mais recorrentes de índice `Automatic` `Duplicate` foram `...EmpresaId + ...Id|...Codigo`, depois atributos únicos de auditoria de usuário (`...InclusaoUsuarioId`, `...UltimaAtualizacaoUsuarioId`), depois `...EmpresaId` isolado, e só depois outros `...Id` únicos menos frequentes.
- `Evidência direta`: nessa mesma ampliacao, `101/228` `Table` locais combinavam ao mesmo tempo algum par `...EmpresaId + ...Id|...Codigo` e algum índice automático de auditoria de usuário; `41/228` não mostraram nenhum desses dois sinais na leitura aplicada.
- `Evidência direta`: numa releitura posterior do conjunto local completo com parse direto do bloco `<Indexes>`, `143/228` `Table` apresentaram pelo menos um índice `User`, enquanto `85/228` não apresentaram nenhum `User`.
- `Evidência direta`: nesse mesmo recorte, entre as `Table` sem `User`, `69/85` ficaram com apenas `1` ou `2` índices `Automatic` `Duplicate`, e apenas `16/85` passaram de `2` índices `Automatic` `Duplicate`.
- `Evidência direta`: no recorte complementar, entre as `Table` com `User`, `124/143` ficaram na faixa de `1` a `3` índices `User`, e apenas `19/143` passaram de `3` índices `User`.
- `Evidência direta`: a releitura ampla encontrou apenas `3` `Table` sem qualquer índice `Automatic` `Duplicate`: `OperacaoFiscal`, `Pais` e `TipoDocumento`; nas tres, ainda assim havia pelo menos um índice `User`.
- `Evidência direta`: nesses tres casos excepcionais, o índice `User` observado cobria ordenacao ou busca por atributo simples de negocio, como `Descricao`, `Nome` ou `Id Descendente`.
- `Inferência forte`: esses tres casos devem ser lidos como exceção local da KB e possível alvo de revisao de modelagem, não como perfil representativo para materialização conservadora de `Table`.
- `Evidência direta`: no mesmo recorte amplo, o acervo totalizou `429` índices `User`; `239/429` continham pelo menos um `Member` em `Descending`, e `229/429` terminavam com o último `Member` em `Descending`.
- `Evidência direta`: no mesmo recorte, `190/429` índices `User` ficaram totalmente em `Ascending`, mostrando que nem todo índice manual desta KB existe para ordenacao descendente; parte deles cobre navegacao/consulta por combinacoes específicas de negocio.
- `Inferência forte`: dentro dessa amostra, os índices `Automatic` aparecem como recombinacoes de atributos já materializados na própria `Transaction`, e não como introducao de atributos fisicos alheios ao primeiro `Level`.
- `Inferência forte`: dentro dessa amostra, o padrão `...EmpresaId + ...Id|...Codigo` parece um dos sinais mais fortes de índice automático adicional na camada física.
- `Inferência forte`: ao mesmo tempo, esse padrão por nome não é suficiente sozinho para prever índice automático; ele funciona como pista estrutural, não como regra deterministica.
- `Inferência forte`: na KB analisada, a combinacao entre relacionamento principal (`...EmpresaId + ...Id|...Codigo`) e trilha de auditoria de usuário parece formar o nucleo mais recorrente dos índices `Automatic` adicionais.
- `Inferência forte`: os índices automáticos de auditoria observados na amostra devem ser lidos como mais um caso de FK automática renomeada de forma amigavel, e não como familia especial criada por regra separada.
- `Inferência forte`: a presenca de índice `User` (`U...`) deve ser lida como tuning manual e empirico por volume e ordenacao real, e não como desdobramento estrutural obrigatório da `Transaction`.
- `Inferência forte`: na KB analisada, um índice `User` tende a surgir quando a ordenacao real de grid, relatório ou procedure diverge dos índices automáticos disponíveis e a massa de registros já justifica um índice dedicado.
- `Inferência forte`: um caso recorrente de índice `User` e reaproveitar quase a mesma base de um índice automático, mas ajustando direcao de ordenacao, especialmente com o último campo em `Descending` para buscar o registro mais recente.
- `Inferência forte`: a ausencia de índice `User` em varias `Table` deve ser lida como decisão valida e consciente do modelador, quando o volume esperado e pequeno e o custo de manutencao do índice não compensa.
- `Inferência forte`: fora do nucleo mais carregado de `User`, a familia residual mais comum não é ausencia total de índices, e sim `Table` resolvida apenas com PK e poucos `Automatic` `Duplicate`, sem necessidade de tuning manual adicional.
- `Inferência forte`: os raros casos sem `Automatic` `Duplicate` formam exceção de tabela muito simples, onde um único `User` pode cumprir papel de busca ou ordenacao sem haver malha de FK automática relevante.
- `Inferência forte`: para geração conservadora de `XPZ`, o erro mais provavel do agente passa a ser excesso de `User` inventado; a distribuicao observada recomenda preferir ausencia de `User` ou poucos `User` antes de extrapolar tuning pesado.
- `Inferência forte`: para ler a camada física desta base, o eixo primario de correlacao deve ser `Transaction -> Table`, tratando os `Index` como estrutura interna da `Table`.
- `Inferência forte`: para evolucao metodologica da base, o pacote mais informativo não é `Index` isolado, e sim combinacoes como `Transaction + Table`, `Transaction + Table + WorkWithForWeb + PatternSettings` e `Attribute + Domain + Transaction + SubtypeGroup + Table`.




