# GeneXus XPZ Research Notes

## Resumo em Português Brasileiro

Este arquivo documenta descobertas práticas sobre a estrutura de arquivos `XPZ` do GeneXus a partir da inspeção de um pacote real.

Pontos já confirmados:
- no caso analisado, o `XPZ` é um arquivo `ZIP`
- dentro dele existe um XML principal de exportação
- esse XML usa a raiz `<ExportFile>`
- os objetos GeneXus ficam em nós `<Object ...>`
- cada objeto é composto por várias partes internas identificadas por `Part type`
- já foi possível mapear GUIDs de tipos de objeto como `Web Panel`, `Procedure`, `API`, `Dashboard`, `Data Provider`, `Structured Data Type (SDT)`, `Transaction`, `Module`, `Folder`, `File`, `Domain`, `Subtype Group`, `Theme Class`, `Theme Color`, `Color Palette`, `Image`, `Index`, `Panel`, `User Control`, `Design System`, `Stencil`, `Data Selector`, `Document`, `Generator`, `Language`, `Deployment Unit`, `Theme`, `DataStore`, `WorkWithForWeb` e `Pattern Settings`

Objetivo deste documento:
- servir como base genérica para analisar `XPZ`
- apoiar futura automação de inspeção ou geração de pacotes
- registrar o que já é confiável e o que ainda precisa de validação

Limitação atual:
- o documento ainda não prova que seja possível gerar um `XPZ` novo e importável apenas montando XML manualmente
- ele mostra a estrutura observada e o caminho técnico para continuar a investigação

## Resumen en Español

Este archivo documenta hallazgos prácticos sobre la estructura de archivos `XPZ` de GeneXus a partir de la inspección de un paquete real.

Puntos ya confirmados:
- en el caso analizado, el `XPZ` es un archivo `ZIP`
- dentro existe un XML principal de exportación
- ese XML usa la raíz `<ExportFile>`
- los objetos GeneXus aparecen en nodos `<Object ...>`
- cada objeto está compuesto por varias partes internas identificadas por `Part type`
- ya fue posible mapear GUIDs de tipos de objeto como `Web Panel`, `Procedure`, `API`, `Dashboard`, `Data Provider`, `Structured Data Type (SDT)`, `Transaction`, `Module`, `Folder`, `File`, `Domain`, `Subtype Group`, `Theme Class`, `Theme Color`, `Color Palette`, `Image`, `Index`, `Panel`, `User Control`, `Design System`, `Stencil`, `Data Selector`, `Document`, `Generator`, `Language`, `Deployment Unit`, `Theme`, `DataStore`, `WorkWithForWeb` y `Pattern Settings`

Objetivo del documento:
- servir como base genérica para analizar `XPZ`
- apoyar futura automatización de inspección o generación de paquetes
- registrar qué ya es confiable y qué todavía necesita validación

Limitación actual:
- el documento todavía no prueba que sea posible generar un `XPZ` nuevo e importable solo armando XML manualmente
- muestra la estructura observada y el camino técnico para continuar la investigación

## Scope

This document records practical findings about `XPZ` packages exported by GeneXus, based on inspection of real exported files.

The goal is to build reusable knowledge for:
- identifying object types inside an `XPZ`
- understanding the internal XML structure
- preparing future automation for inspection, validation, or generation of `XPZ` packages

These notes are intended to be generic across projects, even when examples come from a specific exported package.

## Confirmed Packaging Model

From direct inspection of a real package:
- the `XPZ` file can be a `ZIP` container
- the `ZIP` can contain a single large XML file
- the root element of that XML is `<ExportFile>`

Observed evidence from a real package:
- sample file: `FabricaBrasil18_Full_20260324a.xpz`
- ZIP signature: file starts with `PK`
- internal file observed: `FabricaBrasil18_Full_20260324a.xml`

Important:
- do not assume every historical `XPZ` variant is identical
- but for the inspected GeneXus 18 case, `XPZ` behaved as a ZIP containing XML

## Top-Level XML Structure

Observed high-level structure:

```xml
<ExportFile>
  <KMW>...</KMW>
  <Source ... />
  <KnowledgeBase ...>
    <Version ... />
    <Environments>...</Environments>
  </KnowledgeBase>
  <Objects>
    <Object ...>
      <Part type="...">...</Part>
      <Properties>...</Properties>
    </Object>
    ...
  </Objects>
</ExportFile>
```

Meaning:
- `KMW`: export format/version metadata
- `Source`: source KB metadata
- `KnowledgeBase`: KB and environment metadata
- `Objects`: actual exported GeneXus objects

## Confirmed Object Type GUID Mapping

The following mappings were confirmed from real objects found in the inspected XML.

Canonical names below follow GeneXus public documentation when available. Entries that do not appear in the official public object table are kept as operational names inferred from exports and should not yet be treated as fully official object names.

| Object type | GUID |
|---|---|
| `Folder` | `00000000-0000-0000-0000-000000000006` |
| `Generator` | `ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0` |
| `Module` | `00000000-0000-0000-0000-000000000008` |
| `Procedure` | `84a12160-f59b-4ad7-a683-ea4481ac23e9` |
| `API` | `36e32e2d-023e-4188-95df-d13573bac2e0` |
| `Dashboard` | `526aba9f-a725-4bc7-b1db-0b9f92ac9550` |
| `Data Provider` | `2a9e9aba-d2de-4801-ae7f-5e3819222daf` |
| `Data Selector` | `ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af` |
| `DataStore` | `dcdcdcdc-dfe0-4a57-ae8f-c6e31b0dcbc0` |
| `Deployment Unit` | `bf08dfb1-361c-4e7e-ad54-391e56e60b49` |
| `Domain` | `00972a17-9975-449e-aab1-d26165d51393` |
| `Document` | `faeb588c-dcce-4dad-9af3-cdd11b961a32` |
| `File` | `1132ac08-290f-4fd1-bd18-64777b7329d1` |
| `Image` | `9fb193d9-64a4-4d30-b129-ff7c76830f7e` |
| `Index` | `857ca50e-7905-0000-0007-c5d9ff2975ec` |
| `Language` | `88313f43-5eb2-0000-0028-e8d9f5bf9588` |
| `Pattern Settings` | `83476c1e-fa72-4229-9930-f51b954fca2d` |
| `Stencil` | `624a8b31-36f0-4292-adba-2d270d1e3537` |
| `Theme` | `c804fdbd-7c0b-440d-8527-4316c92649a6` |
| `User Control` | `562f4793-aabe-449f-8821-fc77e550698e` |
| `Design System` | `78b3fa0e-174c-4b2b-8716-718167a428b5` |
| `Structured Data Type (SDT)` | `447527b5-9210-4523-898b-5dccb17be60a` |
| `Subtype Group` | `87313f43-5eb2-41d7-9b8c-e8d9f5bf9588` |
| `Theme Class` | `d4876646-98dd-419b-8c1c-896f83c48368` |
| `Theme Color` | `5592de59-d30a-499d-9100-a7006d3674f2` |
| `Transaction` | `1db606f2-af09-4cf9-a3b5-b481519d28f6` |
| `Panel` | `d82625fd-5892-40b0-99c9-5c8559c197fc` |
| `Color Palette` | `3affc0b3-494b-4d84-9ec1-3a6ab8349cda` |
| `Web Panel` | `c9584656-94b6-4ccd-890f-332d11fc2c25` |
| `WorkWithForWeb` | `78cecefe-be7d-4980-86ce-8d6e91fba04b` |
| `External Object` | `c163e562-42c6-4158-ad83-5b21a14cf30e` |
| `Packaged Module` | `c88fffcd-b6f8-0000-8fec-00b5497e2117` |

## Evidence Used For Type Mapping

Examples observed in the inspected XML:
- `wpLogin3` and `ViewCliente` use `type="c9584656-94b6-4ccd-890f-332d11fc2c25"` -> `Web Panel`
- `sdLogin` uses `type="d82625fd-5892-40b0-99c9-5c8559c197fc"` -> `Panel`
- `procViewRomaneio` uses `type="84a12160-f59b-4ad7-a683-ea4481ac23e9"` -> `Procedure`
- `apiPDV_Integracao` uses `type="36e32e2d-023e-4188-95df-d13573bac2e0"`; per user confirmation in the KB, this object type is `API`
- `Carmine` uses `type="3affc0b3-494b-4d84-9ec1-3a6ab8349cda"`; per user confirmation in the KB, this object type is `Color Palette`
- objects using `type="562f4793-aabe-449f-8821-fc77e550698e"`; per user confirmation in the KB, this object type is `User Control`
- objects using `type="78b3fa0e-174c-4b2b-8716-718167a428b5"`; per user confirmation in the KB, this object type is `Design System`
- objects using `type="624a8b31-36f0-4292-adba-2d270d1e3537"`; per user confirmation in the KB, this object type is `Stencil`
- `GAM_ActivityDashboard` uses `type="526aba9f-a725-4bc7-b1db-0b9f92ac9550"` and contains `<Dashboard>` inside `<Data ...>`; no other extracted XML showed `<Dashboard>` -> `Dashboard`
- objects using `type="2a9e9aba-d2de-4801-ae7f-5e3819222daf"` match the `Data Provider` set exported from the KB and show DP-style source, parameters, and `OutputSDT` definitions -> `Data Provider`
- objects using `type="ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af"`; per user confirmation in the KB, this object type is `Data Selector`
- objects using `type="faeb588c-dcce-4dad-9af3-cdd11b961a32"`; per user confirmation in the KB, this object type is `Document`
- objects using `type="ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0"`; per user confirmation in the KB, this object type is `Generator`
- `AbrangenciaDaSelecaoDeCorte`, `Aliquota`, `CEST`, `EnderecoEmail`, and `PrecoComZ` use `type="00972a17-9975-449e-aab1-d26165d51393"` and consistently show `Domain`-style properties such as `ATTCUSTOMTYPE`, `Length`, `AttMaxLen`, `Decimals`, `ATT_PICTURE`, `IDEnumDefinedValues`, or `idBasedOn` -> `Domain`
- objects using `type="1132ac08-290f-4fd1-bd18-64777b7329d1"` match the `File` export set from the KB and show `FileName`, `FileExtension`, embedded binary data, and extraction properties such as `JavaExtract` and `NetExtract` -> `File`
- objects using `type="9fb193d9-64a4-4d30-b129-ff7c76830f7e"` consistently show image payload under `<Images>` and map directly to generated files under the web model's `Web/Resources` output directory -> `Image`
- objects using `type="857ca50e-7905-0000-0007-c5d9ff2975ec"` consistently contain `<Index` and no objects outside that type showed the same pattern in the extracted KB object set -> `Index`
- objects using `type="83476c1e-fa72-4229-9930-f51b954fca2d"` were `WorkWith` and `WorkWithDevices`, each storing `<Data Pattern="...">` configuration for pattern behavior -> `Pattern Settings`
- objects using `type="87313f43-5eb2-41d7-9b8c-e8d9f5bf9588"` consistently contain `<Subtype guid="...">` entries and no objects outside that type showed the same pattern in the extracted KB object set -> `Subtype Group`
- objects using `type="d4876646-98dd-419b-8c1c-896f83c48368"` consistently show `ThemeElementInternalType = GxClass` and `ThemeElementThemeTypes = idWeb` or `idSD`, and their names are referenced as generated UI classes in the web output -> operationally classified as `Theme Class`
- objects using `type="5592de59-d30a-499d-9100-a7006d3674f2"` were confirmed by a dedicated export whose `<Dependencies>` entry declared `Name="Theme Color"` for that GUID -> `Theme Color`
- objects using `type="78cecefe-be7d-4980-86ce-8d6e91fba04b"` all start with `WorkWithWeb` and no extracted object outside that type starts with `WorkWithWeb` -> `WorkWithForWeb`
- `SdtNfe`, `sdtFatura`, `Messages` use `type="447527b5-9210-4523-898b-5dccb17be60a"` -> `Structured Data Type (SDT)`
- `Animal` transaction uses `type="1db606f2-af09-4cf9-a3b5-b481519d28f6"` -> `Transaction`
- `GAMRepository` uses `type="c163e562-42c6-4158-ad83-5b21a14cf30e"` -> `External Object`

## Internal Model Per Object

Objects are not represented as one simple XML fragment. Each exported object is a node:

```xml
<Object ... type="...">
  <Part type="...">...</Part>
  <Part type="...">...</Part>
  ...
  <Properties>...</Properties>
</Object>
```

This means:
- object content is split across multiple `Part type` sections
- to generate a valid `XPZ`, reproducing only the outer `<Object>` is not enough
- the correct set of `Part type` blocks matters

## Observed Part Types By Object Type

### Web Panel

Observed from object `wpLogin3`.

Relevant `Part type` values:
- `d24a58ad-57ba-41b7-9e6e-eaca3543c778`: layout/form XML, usually inside `<Source><![CDATA[<GxMultiForm ...`
- `c44bd5ff-f918-415b-98e6-aca44fed84fa`: events and source code
- `e4c4ade7-53f0-4a56-bdfd-843735b66f47`: variables
- `ad3ca970-19d0-44e1-a7b7-db05556e820c`: help/documentation
- `babf62c5-0111-49e9-a1c3-cc004d90900a`: base properties
- `9b0a32a3-de6d-4be1-a4dd-1b85d3741534`: present, sometimes empty or auxiliary
- `763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9`: present, sometimes empty or auxiliary

### Procedure

Observed from object `procViewRomaneio`.

Relevant `Part type` values:
- `528d1c06-a9c2-420d-bd35-21dca83f12ff`: main procedure source code
- `9b0a32a3-de6d-4be1-a4dd-1b85d3741534`: rules, commonly `parm(...)`
- `e4c4ade7-53f0-4a56-bdfd-843735b66f47`: variables
- `ad3ca970-19d0-44e1-a7b7-db05556e820c`: help/documentation
- `babf62c5-0111-49e9-a1c3-cc004d90900a`: base properties
- `c414ed00-8cc4-4f44-8820-4baf93547173`: present in examples, purpose still to be confirmed
- `763f0d8b-d8ac-4db4-8dd4-de8979f2b5b9`: present in examples, purpose still to be confirmed

### API

Observed from object `apiPDV_Integracao`.

Validation evidence:
- per user confirmation in the GeneXus KB, `apiPDV_Integracao` is an object of type `API`
- the extracted object set for `type="36e32e2d-023e-4188-95df-d13573bac2e0"` currently contains that object

### Color Palette

Observed from object `Carmine`.

Validation evidence:
- per user confirmation in the GeneXus KB, `Carmine` is an object of type `Color Palette`
- the extracted object set for `type="3affc0b3-494b-4d84-9ec1-3a6ab8349cda"` currently contains that object

### Design System

Validation evidence:
- per user confirmation in the GeneXus KB, the extracted object set for `type="78b3fa0e-174c-4b2b-8716-718167a428b5"` is of type `Design System`

### Stencil

Validation evidence:
- per user confirmation in the GeneXus KB, the extracted object set for `type="624a8b31-36f0-4292-adba-2d270d1e3537"` is of type `Stencil`

### User Control

Validation evidence:
- per user confirmation in the GeneXus KB, the extracted object set for `type="562f4793-aabe-449f-8821-fc77e550698e"` is of type `User Control`

### Dashboard

Observed from object `GAM_ActivityDashboard`.

Observed content style:
- dashboard configuration under `<Data ...>` with inner `<Dashboard>` XML
- parameters, layout, filters, cards, charts, and bound dashboard objects

Validation evidence:
- the extracted object set for `type="526aba9f-a725-4bc7-b1db-0b9f92ac9550"` contained `GAM_ActivityDashboard`
- this XML contained `<Dashboard>` inside `<Data ...>`
- no other extracted XML contained `<Dashboard>`

### Data Provider

Observed from objects such as `dpCargaPedidos` and `GAM_GetTotalUsers`.

Observed content style:
- `Source` block with DP syntax and structured output assignment
- parameter rules such as `Parm(...)`
- output structured through `OutputSDT`

Validation evidence:
- the extracted object set for `type="2a9e9aba-d2de-4801-ae7f-5e3819222daf"` matched the `Data Provider` list exported from the KB
- sampled objects showed standard DP structure and semantics

### Data Selector

Validation evidence:
- per user confirmation in the GeneXus KB, the extracted object set for `type="ffd44be7-3bb4-4d01-9e7e-d1c1a3c095af"` is of type `Data Selector`

### Document

Validation evidence:
- per user confirmation in the GeneXus KB, the extracted object set for `type="faeb588c-dcce-4dad-9af3-cdd11b961a32"` is of type `Document`

### Domain

Observed from objects such as `AbrangenciaDaSelecaoDeCorte`, `EnderecoEmail`, and `PrecoComZ`.

Relevant `Part type` values:
- `ad3ca970-19d0-44e1-a7b7-db05556e820c`: help/documentation
- `babf62c5-0111-49e9-a1c3-cc004d90900a`: base properties

Observed content style:
- object-level properties such as `ATTCUSTOMTYPE`, `Length`, `AttMaxLen`, `Decimals`, `ATT_PICTURE`, `IDEnumDefinedValues`, `AddEmptyItem`, or `idBasedOn`
- no procedural source, layout definition, variable block, or transaction level structure

Validation evidence:
- sampled objects with `type="00972a17-9975-449e-aab1-d26165d51393"` consistently matched `Domain` semantics, including built-in based domains like `EnderecoEmail`
- all `592` extracted objects of this type had `Property Name = Name`
- the apparent exceptions without `ATTCUSTOMTYPE` still kept `Domain` characteristics through properties like `idBasedOn`, `Decimals`, `ATT_PICTURE`, `Length`, and `AttMaxLen`

### File

Observed from objects such as `3OF9`, `Correios_Net_dll`, and `jquery-ui-v_1_14_1_js`.

Observed content style:
- embedded binary data under `<Data>` with `<base64Binary>`
- file metadata such as `FileName` and `FileExtension`
- extraction-related properties such as `JavaExtract`, `NetExtract`, and `Extract`

Validation evidence:
- the extracted object set for `type="1132ac08-290f-4fd1-bd18-64777b7329d1"` matched the `File` export list from the KB
- sampled objects showed standard file payload and extraction metadata

### Image

Observed from objects such as `abatebovinos`, `ActionDelete`, `calendar`, and `Close`.

Observed content style:
- image payload under `<Images>` with nested `<ImageItem>` and `<Image>`
- binary content stored as `<base64Binary>`
- object names matching generated files in the web `Resources` directory

Validation evidence:
- sampled objects with `type="9fb193d9-64a4-4d30-b129-ff7c76830f7e"` consistently mapped to files generated under the web model's `Web/Resources` output directory
- the object XML embeds the resource data directly, including file name and image bytes

### Generator

Validation evidence:
- per user confirmation in the GeneXus KB, the extracted object set for `type="ecececec-dfe0-4a57-ae8f-c6e31b0dcbc0"` is of type `Generator`

### Index

Observed from the extracted object set for `type="857ca50e-7905-0000-0007-c5d9ff2975ec"`.

Observed content style:
- index definition under `<Index ...>`

Validation evidence:
- all `228` extracted objects with `type="857ca50e-7905-0000-0007-c5d9ff2975ec"` contained `<Index`
- no extracted object outside that type contained `<Index`

### Panel

Observed from objects such as `sdLogin` and `GAMSDLogin`.

Working note:
- this GUID had previously been labeled `SDPanel` from observed examples
- per user confirmation, the type should be treated as `Panel` in this working catalog

### Pattern Settings

Observed from objects `WorkWith` and `WorkWithDevices`.

Observed content style:
- pattern configuration under `<Data Pattern="...">`
- configuration payloads describing pattern behavior, actions, labels, themes, platforms, and related settings

Validation evidence:
- the extracted object set for `type="83476c1e-fa72-4229-9930-f51b954fca2d"` contained exactly `WorkWith` and `WorkWithDevices`
- both objects stored pattern configuration rather than business object definitions
- per user confirmation, the name shown in the GeneXus IDE for this object type is `Pattern Settings`

### Theme Color

Observed from a dedicated export of only `Theme Color` objects from the KB.

Observed content style:
- lightweight objects with only `Name` and occasional `Description`
- names such as `Action`, `Background`, `Border`, `Header`, `Text`, and `WarningColor`

Validation evidence:
- a dedicated `XPZ` export containing only Theme Color objects produced exactly the same GUID `5592de59-d30a-499d-9100-a7006d3674f2`
- the exported XML `<Dependencies>` block declared `Name="Theme Color"` for that GUID
### Theme Class

Observed from objects such as `ActionAttribute`, `ActionButtons`, and `BigTitle`.

Observed content style:
- object-level properties `ThemeElementInternalType` and `ThemeElementThemeTypes`
- class-like names reused in generated UI artifacts
- hierarchical parent/child organization between theme elements

Validation evidence:
- all `501` extracted objects with `type="d4876646-98dd-419b-8c1c-896f83c48368"` contained both `ThemeElementInternalType` and `ThemeElementThemeTypes`
- `ThemeElementInternalType` was `GxClass` in `501/501`
- `ThemeElementThemeTypes` was `idWeb` in `490` objects and `idSD` in `11`
- names such as `ActionButtons`, `ActionsContainer`, and `BigTitle` were found referenced in generated web output under the web model output directory

Operational note:
- `Theme Class` is a practical working label based on current evidence
- if future GeneXus documentation or broader evidence reveals a more official object-type name for this GUID, this mapping should be revised

### WorkWithForWeb

Observed from the extracted object set for `type="78cecefe-be7d-4980-86ce-8d6e91fba04b"`.

Validation evidence:
- all `183` extracted objects with this type started with `WorkWithWeb`
- no extracted object outside that type started with `WorkWithWeb`
- all extracted objects of this type also contained `<Data Pattern=`, consistent with pattern-generated web artifacts, though that marker was not exclusive to this type

### Structured Data Type (SDT)

Observed from object `SdtNfe`.

Relevant `Part type` values:
- `5c2aa9da-8fc4-4b6b-ae02-8db4fa48976a`: hierarchical SDT definition, with `<Level>`, `<LevelInfo>`, and `<Item>`
- `babf62c5-0111-49e9-a1c3-cc004d90900a`: base properties

Related nested type identifiers observed:
- `a76e9340-bdb9-445d-8f81-cfd4ddd0b0f3`: level metadata items inside SDT structure
- `f76e9340-bdb9-445d-8f81-cfd4ddd0b0f3`: member/item entries inside SDT structure

### Subtype Group

Observed from objects such as `AbateOrdemCompraGado`.

Relevant `Part type` values:
- `74203da2-41b1-402c-0001-d8d564a2c2fa`: subtype definitions with repeated `<Subtype guid="...">` nodes and nested `<Supertype ...>` references

Observed content style:
- `<Subtype guid="...">`
- `<Name>...</Name>`
- `<Supertype guid="...">...</Supertype>`

Validation evidence:
- all extracted objects with `type="87313f43-5eb2-41d7-9b8c-e8d9f5bf9588"` contained `<Subtype guid=`
- no extracted object outside that type contained `<Subtype guid=`

### Transaction

Observed from object `Animal`.

Relevant `Part type` values:
- `264be5fb-1b28-4b25-a598-6ca900dd059f`: transaction structure, levels, and attribute properties

Observed content style:
- `<Level Name="..." Type="..." Description="..." Guid="...">`
- nested `<AttributeProperties Attribute="...">`
- object-level properties outside the `Part`

## Practical Implications

### What is already safe to assume

- an inspected GeneXus 18 `XPZ` can be unpacked as ZIP
- the package can be backed by a central XML export file
- object type detection can be done using the `Object/@type` GUID
- object definitions depend on `Part type` sections

### What is not yet safe to assume

- that all GeneXus versions use exactly the same `XPZ` structure
- that a minimal synthetic XML with guessed parts will import correctly
- that all `Part type` values listed here are mandatory in every case
- that empty-looking parts are always optional

## Recommended Reverse Engineering Workflow

When analyzing a new `XPZ`:
1. Confirm if the file starts with ZIP signature `PK`
2. List internal entries
3. Extract the XML payload
4. Identify object nodes under `<Objects>`
5. Map object `type` GUIDs using known examples
6. Extract one representative block per object type
7. Compare `Part type` usage across simple and complex objects
8. Only after that, attempt synthetic generation or transformation

## Recommended Automation Strategy

Short term:
- use this document as a reference catalog
- build inspection tools first, not generation tools

Medium term:
- create scripts that:
  - unpack `XPZ`
  - index objects by type, name, guid, and parent
  - extract complete object blocks
  - summarize `Part type` usage

Long term:
- create a reusable skill or generator only after the minimum valid object package is understood per object type

## Open Questions

- exact semantic meaning of all recurring `Part type` GUIDs
- minimum required parts for each object type
- checksum behavior and whether GeneXus validates it strictly on import
- whether import accepts partially synthetic objects if metadata is coherent
- which parts differ between GeneXus upgrades

## Suggested Next Investigation

1. Extract a full minimal `Web Panel` object block and compare with another `Web Panel`
2. Extract a full minimal `Procedure` object block and compare with another `Procedure`
3. Extract a simple `Structured Data Type (SDT)`, a simple `Transaction`, and a `Subtype Group`
4. Build a `Part type` catalog with semantic labels
5. Test whether editing a copied object block and repacking the `XPZ` is accepted by GeneXus







