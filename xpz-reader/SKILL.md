---
name: xpz-reader
description: Analyzes GeneXus XPZ/XML objects — identifies type, family, structure, and risk from raw XML input
---

# xpz-reader

Interprets raw XML from GeneXus XPZ exports. Identifies object type, structural family, Part type mapping, and risk classification based on empirical evidence from a corpus of 7,219 real XMLs.

---

## GUIDELINE

Read and classify GeneXus XML objects from XPZ packages. Answer only what the evidence supports. Always declare confidence level.

## PATH RESOLUTION

- This `SKILL.md` lives inside a skill subfolder under the repository root.
- Resolve every `../arquivo.md` reference relative to the directory of this `SKILL.md`, not relative to the current working directory.
- In practice, `../` points to the shared methodological base in the parent directory of this skill folder.

---

## TRIGGERS

Use this skill for:
- User provides raw XML or XML fragment from a GeneXus XPZ export
- User asks to identify an object type, family, or structure
- User asks which Part types are present, expected, or missing
- User asks about risk classification for a given object type
- User asks to compare two XML structures or families
- User asks what `Object/@type` value corresponds to a given GeneXus object

Do NOT use this skill for:
- Generating or cloning XPZ objects (use `xpz-builder`)
- Questions about GeneXus IDE behavior, build, or runtime execution beyond structural classification
- Questions unrelated to GeneXus XPZ/XML structure
- Locating or finding objects by name or type within the KB corpus (use `xpz-index-triage` first when a KbIntelligence index is available, to identify which XML to open)

---

## RESPONSIBILITIES

- Identify `Object/@type` and map to known object category using [01-base-empirica-geral](../01-base-empirica-geral.md) as the index plus [01a-catalogo-e-padroes-empiricos](../01a-catalogo-e-padroes-empiricos.md) for the actual catalog
- Map Part types present in input against observed frequencies and known patterns, using [01b-matriz-part-types-por-tipo](../01b-matriz-part-types-por-tipo.md) when needed
- Classify object family when applicable: WebPanel families in [04-webpanel-familias-e-templates](../04-webpanel-familias-e-templates.md), Transaction families in [05-transaction-familias-e-templates](../05-transaction-familias-e-templates.md)
- For `WebPanel`, classify the review by functional block before fine analysis: `layout`, `events`, `variables`, `serialized functional metadata`, `identity and container`, or `dependencies`
- For `WebPanel`, when a textual search finds a term inside `<Source><![CDATA[<GxMultiForm...`, classify that evidence as `layout` or `serialized functional metadata`, not as `events`; for event/code-behind questions, prefer `scripts\Search-GeneXusXmlSourceBlock.ps1 -Block events` over raw `rg`/`grep`
- For `WorkWithForWeb`, classify the review by functional block before fine analysis: `Transaction binding`, `Pattern structure and navigation`, `Actions, links and prompts`, `Attribute references and data contract`, or `Identity and container`
- For `DataSelector`, classify the review by functional block before fine analysis: `Selection contract`, `Selection logic and conditions`, `Attribute and function dependencies`, `Navigation context`, or `Identity and container`
- For `Panel`, classify the review by functional block before fine analysis: `Panel structure and layout`, `Serialized behavior and configuration`, `Pattern and parent coupling`, `External dependencies`, or `Identity and container`
- For `Transaction`, classify the review by functional block before fine analysis: `Transaction structure`, `Attributes and attribute properties`, `Rules`, `Events`, `Execution context`, or `Identity and container`
- For `Transaction`, when the primary block is `Attributes and attribute properties`, classify each `key="False"` attribute in the Level by writability using the detection signals in order: `isRedundant="True"` in Level → `extended-parent-fk` (non-writable); `Formula` property in its Attribute XML → `formula` (non-writable); listed in a SubTypeGroup as mapped to a non-key Supertype attribute → `extended-subtype-descriptive` (non-writable); listed in a SubTypeGroup as mapped to a PK Supertype attribute → `extended-subtype-key` (writable); when no SubTypeGroup covers the attribute, apply the naked-FK test using the Transaction's Table XML: if the attribute appears in a Duplicate index of that Table XML → `extended-fk-key` (writable, FK column stored in this table); otherwise, identify direct FK entities as the Transactions whose own `key="True"` PK attribute matches a PK member or Duplicate-index column of this table — read each FK entity's Level and collect its `key="False"` attributes — if the candidate attribute appears in any of those collections → `extended-fk-descriptive` (non-writable); for transitive extension, repeat the FK-entity lookup recursively on those FK entities; only if the attribute is absent from all FK entities at all depths → `own-physical` (writable); declare the writability classification explicitly in the analysis output; never declare a Transaction's physical table as "only keys" without verifying that every `key="False"` attribute was classified and confirmed as non-writable
- For `Procedure`, classify the review by functional block before fine analysis: `Source`, `Rules/parm`, `Variables`, `Calls and dependencies`, `Identity and container`, and `Report layout` when applicable
- For `Procedure`, when the review touches any block that could motivate an edit by the caller, recommend reading the complete `Source` before proposing any change — especially when the object contains validation logic, print `Cases`, or variable declarations that may interact with the intended edit; partial `Source` reading is a known source of editing the wrong layer
- For `DataProvider`, classify the review by functional block before fine analysis: `Output structure`, `Source`, `Navigation context`, `Calls and dependencies`, or `Identity and container`
- For `API`, classify the review by functional block before fine analysis: `Service contract`, `Events and orchestration`, `Calls and dependencies`, `Data contract`, or `Identity and container`
- For `Table`, classify the review by functional block before fine analysis: `Primary key structure`, `Secondary indexes and embedded index members`, `Transaction coupling and physical context`, or `Identity and container`
- For `ExternalObject`, classify the review by functional block before fine analysis: `External contract surface`, `Method signatures and parameter typing`, `Platform and native binding metadata`, or `Identity and container`
- For `UserControl`, classify the review by functional block before fine analysis: `Control contract surface`, `Properties and event bindings`, `Runtime resources and external dependencies`, or `Identity and container`
- For `SubTypeGroup`, classify the review by functional block before fine analysis: `Group definition and member structure`, `Subtype mappings and role assignments`, `Contextual usage contract`, or `Identity and container`
- For `File`, classify the review by functional block before fine analysis: `File identity and declared surface`, `Binary or textual payload fidelity`, `References and consumption context`, or `Identity and container`
- For `Dashboard`, classify the review by functional block before fine analysis: `Dashboard composition and layout`, `Widgets and data bindings`, `Navigation and interaction context`, or `Identity and container`
- For `Stencil`, classify the review by functional block before fine analysis: `Stencil definition and structural surface`, `Parameters and configurable slots`, `Pattern or generation consumption context`, or `Identity and container`
- For `DataStore`, classify the review by functional block before fine analysis: `Store definition and declared connection surface`, `Configuration parameters and runtime options`, `Model and consumption context`, or `Identity and container`
- For `Generator`, classify the review by functional block before fine analysis: `Generator definition and declared surface`, `Generation options and technical parameters`, `Model and target-platform usage context`, or `Identity and container`
- For `Language`, classify the review by functional block before fine analysis: `Language definition and declared surface`, `Localization parameters and technical options`, `Model and runtime usage context`, or `Identity and container`
- For `Document`, classify the review by functional block before fine analysis: `Document identity and declared surface`, `Materialized content and payload fidelity`, `References and functional consumption context`, or `Identity and container`
- For `DeploymentUnit`, classify the review by functional block before fine analysis: `Deployment unit definition and declared surface`, `Packaging parameters and technical options`, `Runtime or delivery context`, or `Identity and container`
- Treat any extra block opened after the first one as an `adjacent block` and open it only when there is explicit functional dependency with the primary block
- Name every justified block transition in the analysis and handoff, instead of silently widening the scope
- State the conclusion scope at the smallest functional level supported by evidence, including execution context when that distinction matters
- For report `Procedure`, classify whether the case fits the documented simple coverage from [05b-procedure-relatorio-familias-e-templates](../05b-procedure-relatorio-familias-e-templates.md), and treat sanitized coverage as materialization-ready only when the selected block is marked as `molde pronto`
- Classify container identity from `parentType` using the GUIDs: `00000000-0000-0000-0000-000000000008` = Module/Folder (user-created container), `c88fffcd-b6f8-0000-8fec-00b5497e2117` = PackagedModule, `afa47377-41d5-4ae8-9755-6f53150aa361` = Root Module (virtual, no XML file in acervo), `00000000-0000-0000-0000-000000000006` = system Folder (Main Programs, ToBeDefined; never a valid parentType of packagable objects); never use the directory name in `ObjetosDaKbEmXml` as a type indicator — it varies across KBs
- Assign risk level using [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md)
- Identify structural anomalies: unexpected Part types, missing recurring parts, malformed envelope
- For report `Procedure`, classify anomalies by layer: `Source`, `Rules`, or layout `Part c414ed00-8cc4-4f44-8820-4baf93547173`
- Identify identity anomalies involving `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
- Treat object lookup in repository-backed workflows as `type + name`, never `name` alone
- Confirm the real folder where the XML exists before citing, comparing, or using a local object as evidence
- When citing a line from GeneXus XML, classify the cited fragment as `effective Source`, `Rules/parm`, `XML metadata`, `call in caller`, or `signature in callee`
- When reading GeneXus variable declarations or variable metadata, classify `ATTCUSTOMTYPE` `bc:<Transaction>` together with `AttCollection=True/False`; never treat BC simple and BC collection as equivalent contracts
- For SDTs used as parameter collections with boolean control flags, extract each flag name from the XML structure and recommend crosschecking its domain semantics against the `Source` of the `Procedure` or `DataProvider` that consumes it; do not infer meaning from the attribute name alone — similar names (`ComSaldo`, `ComSaldoOuAembarcar`) may encode different conditions depending on the consumer's `Cases`
- When reading BC method calls in `Source`, classify the method family as `operation`, `status/message`, `serialization/copy`, or `collection`, and keep that classification separate from runtime semantics not directly proved by the XML
- Declare confidence level for every conclusion: `Direct evidence` / `Strong inference` / `Hypothesis`
- Never affirm import or build compatibility — structural analysis only
- When the task depends on a local KB parallel folder structure, require that structure to be clarified or validated first via `xpz-kb-parallel-setup`
- When the object analyzed is a WWP PatternInstance (`WorkWithPlus*`): flag as structural anomaly any duplicate nodes in `<attribute>`, `<gridAttribute>`, or `<parameter>`; `parentGuid` inconsistent with the object name; and references to attributes apparently absent from the current model — if the user intends to package or clone the object, encaminhar para `xpz-builder`
- When the analysis is motivated by a GeneXus warning about an unknown provider, unknown item, designer, or extension metadata: classify the cited item before searching the XPZ/XML — (a) common exportable GeneXus object; (b) internal part or metadata; (c) designer or extension provider; (d) unknown type. If the XPZ/XML search returns no result and the item is not type (a), state only the limited conclusion: "not found in XPZ/XML" — never "does not exist in the KB". Refer to the conceptual boundary rule in `02-regras-operacionais-e-runtime.md` section "Limite do XPZ/XML frente a providers e extensões GeneXus".

---

## COMMUNICATION

- Respond in the same language the user writes in
- Lead with the classification result, then supporting evidence
- Always state confidence level explicitly
- Use concise language; avoid speculation beyond what the evidence supports
- When certainty is low, say so before proceeding
- NEVER invent Part type GUIDs or object attributes not observed in the corpus

---

## STRUCTURE

Reference files and when to load them:

| Reference | Load when |
|-----------|-----------|
| [00-indice-da-base-genexus-xpz-xml.md](../00-indice-da-base-genexus-xpz-xml.md) | Always — absolute rules and envelope spec |
| [01-base-empirica-geral.md](../01-base-empirica-geral.md) | Entry point and routing across the empirical `01` series |
| [01a-catalogo-e-padroes-empiricos.md](../01a-catalogo-e-padroes-empiricos.md) | Identifying object type and reading the structural catalog |
| [01b-matriz-part-types-por-tipo.md](../01b-matriz-part-types-por-tipo.md) | Checking recurring `Part type` inventory by object type |
| [01c-campos-estaveis-vs-variaveis.md](../01c-campos-estaveis-vs-variaveis.md) | Checking which fields tend to remain stable or vary |
| [01d-diffs-estruturais-por-tipo.md](../01d-diffs-estruturais-por-tipo.md) | Comparing structural density and per-type differences |
| [03-risco-e-decisao-por-tipo.md](../03-risco-e-decisao-por-tipo.md) | Risk classification for any object type |
| [04-webpanel-familias-e-templates.md](../04-webpanel-familias-e-templates.md) | Input contains WebPanel XML |
| [05-transaction-familias-e-templates.md](../05-transaction-familias-e-templates.md) | Input contains Transaction XML |
| [05b-procedure-relatorio-familias-e-templates.md](../05b-procedure-relatorio-familias-e-templates.md) | Input contains report `Procedure` XML |
| [06-padroes-de-objeto-e-nomenclatura.md](../06-padroes-de-objeto-e-nomenclatura.md) | User asks about naming conventions or object organization |
| [09-inventario-e-rastreabilidade-publica.md](../09-inventario-e-rastreabilidade-publica.md) | User asks about corpus history, validation trail, or inventory |
| `xpz-index-triage` skill | When a KbIntelligence index is available and the user needs to locate or confirm which object XML to open before structural analysis |

---

## WORKFLOW

1. Receive XML input or fragment from user
2. If the task depends on locating files in a local KB parallel folder structure and that structure is still undefined, ambiguous, or unvalidated → **ABORT** and use `xpz-kb-parallel-setup` first
3. Locate `Object/@type` attribute → use [01-base-empirica-geral](../01-base-empirica-geral.md) to route and cross-reference against [01a-catalogo-e-padroes-empiricos](../01a-catalogo-e-padroes-empiricos.md); if the root element is `<Attribute>` (not `<Object>`), the type is `Attribute` — it uses a distinct envelope and has no `Object/@type`
4. Check [01b-matriz-part-types-por-tipo](../01b-matriz-part-types-por-tipo.md) for the identified type: if 01b confirms the type uses no Parts (e.g. `ThemeClass`, `ThemeColor`, `Generator`, `DataStore`, `Module/Folder`), skip Part enumeration — absence of `<Part>` is expected for these types, not an anomaly; otherwise enumerate Part types present and compare against observed frequencies
5. Identify missing or unexpected Part types relative to the known structural pattern — this step is not applicable for types confirmed in 01b as using no Parts
6. Read container identity fields (`fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, `moduleGuid`) and classify the container from `parentType` GUID — never from the directory name in `ObjetosDaKbEmXml`, which varies across KBs:
   - `00000000-0000-0000-0000-000000000008` → Module/Folder (user-created container)
   - `c88fffcd-b6f8-0000-8fec-00b5497e2117` → PackagedModule
   - `afa47377-41d5-4ae8-9755-6f53150aa361` → Root Module (virtual; no XML file in acervo)
   - `00000000-0000-0000-0000-000000000006` → system Folder (never a valid parentType of packagable objects)
   - unresolved when parentType is absent or unknown
7. When the task depends on locating an object in a local GeneXus repository, confirm the object by `type + name` and verify the actual folder where the file exists before proceeding
8. Before citing a local line as evidence, classify the line role:
   - effective `Source` of the current object
   - `Rules/parm` or signature of the current object
   - XML metadata or structural wrapper
   - direct call site inside the caller object
   - callee signature inside the called object
9. If variable metadata or declaration indicates `ATTCUSTOMTYPE` `bc:<Transaction>`, classify the variable as BC simple or BC collection using `AttCollection=True/False` before interpreting method calls
10. If the task cites BC methods in `Source`, classify each cited method by family:
   - `operation`: `.Load(...)`, `.Save()`, `.Delete()`, `.Check()`, `.Insert()`, `.Update()`
   - `status/message`: `.Success()`, `.Fail()`, `.GetMessages()`
   - `serialization/copy`: `.ToJson()`, `.FromJson()`, `.ToXml()`, `.FromXml()`, `.Clone()`
   - `collection`: `.Add()`, `.Item()`, `.Sort()`, and `.Insert()` when the variable was confirmed as collection
11. If the conclusion is "object A calls object B", require evidence in A's effective `Source` or in explicit call metadata belonging to A; a `parm(...)` line in B is only callee signature evidence
12. If type is WebPanel → load [04-webpanel-familias-e-templates](../04-webpanel-familias-e-templates.md), classify family, and classify the primary review block before fine analysis:
   - `events` for user actions, refresh, start, load, procedural validation, and direct calls
   - `layout` for visual composition, control hierarchy, grid/tab/action structure, and visible bindings
   - `variables` for declaration contract, type coherence, and collection-vs-simple review
   - `serialized functional metadata` for `Conditions`, `ControlWhere`, `ControlBaseTable`, `ControlOrder`, `ControlUnique`, `PATTERN_ELEMENT_CUSTOM_PROPERTIES`, `WebUserControlProperties`, and pattern marks
   - `identity and container` for `fullyQualifiedName`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
   - `dependencies` for `MasterPage`, pattern links, user controls, and relevant external object references
12a. For WebPanel textual search in a local XML, do not treat a match in inline `GxMultiForm` layout as behavioral evidence; if the question is about calls, actions, validation, filters, or event flow, use `scripts\Search-GeneXusXmlSourceBlock.ps1 -Block events` or an equivalent structured extraction before citing the line
13. For `WebPanel`, open adjacent blocks only when there is explicit functional dependency with the primary block, and name that transition in the analysis
14. If type is `WorkWithForWeb` → classify the primary review block before fine analysis:
   - `Transaction binding` for `parent`, `parentGuid`, `parentType`, associated `Transaction`, structural coupling, and suspicion that the WW is attached to the wrong parent
   - `Pattern structure and navigation` for `selection`, tabs, `view`, filters, navigation, and functional organization inside the serialized pattern
   - `Actions, links and prompts` for actions, buttons, menu items, `gxobject`, links, prompts, and explicit openings of external objects from the WW
   - `Attribute references and data contract` for displayed attributes, attribute-based filters, columns, tabs depending on attributes, broken references, and the structural convention `adbb33c9-0906-4971-833c-998de27e0676-NomeDoAtributo`
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `moduleGuid`, container, and risk of confusing the target instance with another similar one
15. For `WorkWithForWeb`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and treat surrounding generated `WebPanel` or `WorkWithPlus` artifacts only as explicit external dependencies, never as canonical internal blocks of `WorkWithForWeb`
16. If type is `DataSelector` → classify the primary review block before fine analysis:
   - `Selection contract` for parameters, input signature, declarative selector variables, and the contract expected by the selector
   - `Selection logic and conditions` for `Condition`, filters, expressions, selection criteria, and the effective logic that decides the returned set
   - `Attribute and function dependencies` for referenced attributes, functions used in filters, broken names, unresolved references, and semantic dependencies that must really exist in the KB
   - `Navigation context` for implicit or explicit base, transactional/physical context, and the functional frame in which the selector operates
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
17. For `DataSelector`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep parameter contract, applied filter, and real KB dependency as separate layers until evidence supports joining them
18. If type is `Panel` → classify the primary review block before fine analysis:
   - `Panel structure and layout` for visual composition, controls, declarative organization, and the apparent functional shape of the panel
   - `Serialized behavior and configuration` for serialized behavior, persisted configuration, and functional metadata that cannot be reduced to visual decoration
   - `Pattern and parent coupling` for `parent`, `parentGuid`, `parentType`, `moduleGuid`, origin pattern, and the structural coupling that makes the panel depend on its context
   - `External dependencies` for external objects called, referenced, or needed to sustain the functional reading of the panel
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, container, and structural classification of the object
19. For `Panel`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep the panel surface separate from the structural coupling around it until evidence supports joining them
20. If type is Transaction → load [05-transaction-familias-e-templates](../05-transaction-familias-e-templates.md), classify family (F1–F6), and classify the primary review block before fine analysis:
   - `Transaction structure` for `Level`, key, `DescriptionAttribute`, structural shape, and transactional composition
   - `Attributes and attribute properties` for attributes, `AttributeProperties`, subtype linkage, and data-contract questions
   - `Rules` for declarative rules, obligation, and normative transaction behavior
   - `Events` for interface-driven behavior and flow via web editing
   - `Execution context` when the main ambiguity is the distinction between web editing and BC usage
   - `Identity and container` for `fullyQualifiedName`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
21. For `Transaction`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and state whether the conclusion applies via web editing, via BC, or remains unresolved across contexts
22. If type is `DataProvider` → classify the primary review block before fine analysis:
   - `Output structure` for collection vs simple, nested groups, node names, cardinality, and coherence of the promised return shape
   - `Source` for conditions, assignments, assembly logic, calculations, population of output nodes, and internal flow
   - `Navigation context` for implicit or declared base, `For each`, filters, base table, and navigation ambiguity
   - `Calls and dependencies` for `SDT`, `Procedure`, `BC`, `Transaction`, and immediate external dependencies needed to justify the conclusion
   - `Identity and container` for `fullyQualifiedName`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
23. For `DataProvider`, open adjacent blocks only when there is explicit functional dependency with the primary block, and name that transition in the analysis
24. If type is `API` → classify the primary review block before fine analysis:
   - `Service contract` for exposed method, endpoint, external signature, and published operation shape
   - `Events and orchestration` for `.Before/.After`, internal flow, validation, transformation, and orchestration behavior
   - `Calls and dependencies` for `Procedure`, `SDT`, `Domain`, `Transaction`, `EXO`, `DataProvider`, and immediate external dependencies needed to justify the conclusion
   - `Data contract` for input/output shape, type coherence, response structure, and mapping between contract and processed data
   - `Identity and container` for `fullyQualifiedName`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
25. For `API`, open adjacent blocks only when there is explicit functional dependency with the primary block, and name that transition in the analysis
26. If type is `SDT` → classify the primary review block before fine analysis:
   - `Structure definition` for `Level`, `LevelInfo`, item sequence, hierarchy, composition, and collection-vs-simple structural shape
   - `Item typing and dependencies` for `idBasedOn`, `ATTCUSTOMTYPE`, domain base, referenced `SDT`, and item-level semantic coherence
   - `External serialization contract` for `ExternalName`, `ExternalNamespace`, `idXmlName`, `idXmlNamespace`, `soaptype`, `idCollectionItemName`, and equivalent serialization metadata
   - `Top-level type properties` for properties declared on the `SDT` object itself, especially top-level typing or structural behavior that does not belong to one specific item
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
27. For `SDT`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep internal shape, item typing, and external serialization as separate layers until evidence supports joining them
28. If type is `Theme` → classify the primary review block before fine analysis:
   - `Theme core definition` for the theme baseline, central properties, object shape, and global theme definition
   - `Class graph and references` for the `ThemeClass` graph, internal class-to-class references, visual inheritance, and dependencies inside the theme class graph
   - `Predefined types and style bindings` for `PredefinedTypes`, `Styles`, and normative bindings between GeneXus visual types and the concrete `ThemeClass`/`ThemeColor`/`ColorPalette`/`DesignSystem` stack when that coupling is materialized in the theme
   - `Visual simplification and override surface` for controlled simplification, overrides, visual reduction, and removal of theme surface after the basic visual coupling has already been established
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
29. For `Theme`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, keep theme baseline, class graph, normative bindings, and simplification layers separate until evidence supports joining them, and do not use simplification as a shortcut before class graph and normative bindings are sufficiently grounded
30. If type is `ThemeClass` → classify the primary review block before fine analysis:
   - `Direct class surface` for top-level `Properties`, concrete visual properties, direct object shape, and what the class declares without `Part`
   - `Inheritance and parent linkage` for `parent`, `parentGuid`, `parentType`, visual inheritance chain, base class, derived variants, and visual states such as `hover`
   - `Theme applicability and internal classification` for `ThemeElementThemeTypes`, `ThemeElementInternalType`, applicability scope, and internal thematic classification
   - `Visual references and external dependencies` for nominal references to colors, images, helper classes, and other external visual resources the class depends on
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, and `moduleGuid`; do not collapse `parent*` here when evidence points to functional inheritance
31. For `ThemeClass`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep direct class surface, inheritance chain, applicability markers, and external visual dependencies separate until evidence supports joining them
32. If type is `ThemeColor` → classify the primary review block before fine analysis:
   - `Color identity and naming` for the logical color name, nominal identity, and expected thematic role
   - `Direct color value surface` for top-level `Properties`, serialized color value, direct object shape, and the concrete color definition without `Part`
   - `Theme applicability and palette coupling` for relation with `Theme`, `ColorPalette`, `DesignSystem`, applicability scope, and semantic fit inside the visual family
   - `Visual references and usage dependencies` for consumption by `ThemeClass`, `Theme`, styles, and other visual elements that depend on this color identity and value
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, and `moduleGuid`
33. For `ThemeColor`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep nominal identity, direct value, thematic coupling, and visual usage dependencies separate until evidence supports joining them
34. If type is `ColorPalette` → classify the primary review block before fine analysis:
   - `Palette identity and naming` for the logical palette name, nominal identity, and expected thematic role
   - `Palette composition and declared members` for the palette's internal composition, declared items, direct object shape, and the functional list it materializes
   - `Theme and design-system coupling` for relation with `Theme`, `DesignSystem`, and architectural fit inside the broader visual layer
   - `Color references and usage surface` for relation with `ThemeColor` and visual consumers that depend on this palette
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, and `moduleGuid`
35. For `ColorPalette`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep palette identity, declared composition, architectural coupling, and usage surface separate until evidence supports joining them
36. If type is `DesignSystem` → classify the primary review block before fine analysis:
   - `System identity and naming` for the logical system name, nominal identity, and expected architectural role
   - `Design tokens and declared resources` for tokens, declared resources, internal composition, and the functional shape the design system materializes
   - `Theme and palette coupling` for relation with `Theme`, `ColorPalette`, and architectural coupling across the visual layers
   - `Visual rules and consumption surface` for visual rules consumed by other layers and the practical surface where the system affects rendering
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, and `moduleGuid`
37. For `DesignSystem`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep system identity, declared tokens/resources, theme-palette coupling, and consumption surface separate until evidence supports joining them
38. If type is `PackagedModule` → classify the primary review block before fine analysis:
   - `Module identity and naming` for the logical module name, nominal identity, and expected semantic role
   - `Packaging boundary and declared members` for the package boundary, declared members, internal composition, and the functional set the packaged module delimits
   - `Parent and installation context` for installation relation, structural parent, and hierarchical fit of the packaged module
   - `Dependency and consumption surface` for module dependencies and the way other layers or objects consume it
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, and `moduleGuid`
39. For `PackagedModule`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep module identity, package boundary, installation context, and dependency-consumption surface separate until evidence supports joining them
40. If type is `Image` → classify the primary review block before fine analysis:
   - `Image identity and naming` for the logical image name, nominal identity, and expected semantic role of the resource
   - `Image item set and declared variants` for `ImageItem`, declared variants, internal composition, and the functional shape of the image resource
   - `Binary payload and extraction fidelity` for `base64Binary`, payload integrity, content preservation, and extraction-materialization fidelity
   - `Theme and language references` for `ThemeReference`, `LanguageReference`, and external presentation dependencies tied to the image
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, and `moduleGuid`
41. For `Image`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep image identity, declared variants, binary payload, and theme-language references separate until evidence supports joining them
42. If type is `Attribute` → classify the primary review block before fine analysis:
   - `Attribute core definition` for top-level shape, central definition, and baseline attribute structure
   - `Typing and base linkage` for `idBasedOn`, base domain, declared type, and typed contract coherence
   - `Semantic property references` for `ControlItemDescription`, broken nominal references, and dependencies on other real attributes in the KB
   - `Presentation and control semantics` for functional presentation/control properties and serialized behavior that affect attribute usage
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
43. For `Attribute`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep baseline definition, typing, nominal references, and control/presentation semantics separate until evidence supports joining them
44. If type is `PatternSettings` → classify the primary review block before fine analysis:
   - `Pattern registration and environment fit` for pattern availability, environment compatibility, registration fit, and symptoms such as `pattern not registered` or `was not changed`
   - `Internal pattern configuration` for `CDATA`, persisted flags, internal declarative shape, and the pattern configuration stored in the object
   - `Context and callable dependencies` for `ContextVariable`, `LoadProcedure`, called procedures, and functional context required by the pattern
   - `Security and auxiliary references` for `Security` and other auxiliary references that the pattern needs outside its main context
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
45. For `PatternSettings`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep pattern registration, internal configuration, callable context, and auxiliary/security references separate until evidence supports joining them
46. If type is `Folder` → classify the primary review block before fine analysis:
   - `Minimal structural shape` for XML envelope, `Object/@type`, minimal structural shape, and baseline serialization
   - `Parent and module context` for `parent`, `parentGuid`, `parentType`, `moduleGuid`, and the folder's structural placement
   - `IDE semantic reading` for how the IDE/importer interprets the object, including `Category` as a UI label
   - `Identity and naming semantics` for naming ambiguity, displayed naming expectations, and the distinction between XML type and UI label
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, and container-level structural identity
47. For `Folder`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep structural shape, parent/module context, IDE reading, and naming semantics separate until evidence supports joining them
48. If type is `Domain` → classify the primary review block before fine analysis:
   - `Base type definition` for base type, `ATTCUSTOMTYPE` when applicable, and the domain's primary typed contract
   - `Limits and scalar constraints` for length, precision, scale, flags, and scalar constraints
   - `Enumerated values contract` for `IDEnumDefinedValues`, value lists, descriptions, and enumerated contract coherence
   - `Usage-facing semantic contract` for how the domain is meant to be consumed by other objects, UI, or data contracts
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
49. For `Domain`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep base typing, scalar limits, enumerated contract, and usage-facing semantics separate until evidence supports joining them
50. If type is `Table` → classify the primary review block before fine analysis:
   - `Primary key structure` for primary key composition, structural order, key members, and the coherence of the table's main physical core
   - `Secondary indexes and embedded index members` for embedded indexes, index members, ordering, search coverage, and reading `Index` as internal structure of the `Table`
   - `Transaction coupling and physical context` for physical reassociation with the `Transaction` of the same name, structural context in the target, and contextual dependency that still exists even when named `parent` is absent
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parentGuid`, `moduleGuid`, and the risk of reading the wrong `Table` in the wrong structural context
51. For `Table`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, keep primary key, embedded indexes, and transaction-coupling/context layers separate until evidence supports joining them, and do not promote embedded `Index` to a separate top-level object in this reading
52. If type is `ExternalObject` → classify the primary review block before fine analysis:
   - `External contract surface` for exposed surface, external naming, published methods/properties, and the functional role of the wrapper
   - `Method signatures and parameter typing` for methods, parameters, return values, signature coherence, and typed dependencies such as `SDT`, domains, or helper types
   - `Platform and native binding metadata` for assembly, target library, platform metadata, native binding, and technical coupling specific to the `ExternalObject`
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
53. For `ExternalObject`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep exposed surface, typed signatures, and native-binding/platform metadata separate until evidence supports joining them
54. If type is `UserControl` → classify the primary review block before fine analysis:
   - `Control contract surface` for declared interface, exposed surface, the functional role of the control, and its general host-facing shape
   - `Properties and event bindings` for properties, events, parameters, and binding contract between the control and its host
   - `Runtime resources and external dependencies` for scripts, assets, auxiliary resources, technical dependencies, and execution-time coupling of the `UserControl`
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
55. For `UserControl`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep declared control contract, property/event bindings, and runtime-dependency layers separate until evidence supports joining them
56. If type is `SubTypeGroup` → classify the primary review block before fine analysis:
   - `Group definition and member structure` for group composition, declared members, structural shape, and grouping integrity
   - `Subtype mappings and role assignments` for supertype/subtype mapping, member roles, and internal subtype assignments
   - `Contextual usage contract` for how the group supports usage in `Attribute`, `Transaction`, and other consumer objects of the model
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
57. For `SubTypeGroup`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep group definition, subtype-role mapping, and contextual-usage layers separate until evidence supports joining them
58. If type is `File` → classify the primary review block before fine analysis:
   - `File identity and declared surface` for resource naming, declared extension/logical role, and top-level resource surface
   - `Binary or textual payload fidelity` for materialized content, payload integrity, byte/text preservation, and extraction fidelity
   - `References and consumption context` for external references, consumers of the file, runtime dependency, and usage context
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
59. For `File`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep resource identity/surface, payload, and consumption-context layers separate until evidence supports joining them
60. If type is `Dashboard` → classify the primary review block before fine analysis:
   - `Dashboard composition and layout` for sections, visual blocks, structural organization, and dashboard composition shape
   - `Widgets and data bindings` for widgets, components, data bindings, parameters, and the linkage between visible parts and their data providers
   - `Navigation and interaction context` for actions, links, drill-down, user interaction, and the dashboard's functional placement in the wider flow
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
61. For `Dashboard`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep composition, widget-binding, and navigation-interaction layers separate until evidence supports joining them
62. If type is `Stencil` → classify the primary review block before fine analysis:
   - `Stencil definition and structural surface` for artifact shape, declared composition, base structure, and structural surface of the stencil
   - `Parameters and configurable slots` for parameters, placeholders, variable slots, and configurable contract of the stencil
   - `Pattern or generation consumption context` for how the stencil is consumed by patterns, generation, or dependent flows
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
63. For `Stencil`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep structural definition, parameterization, and pattern/generation-consumption layers separate until evidence supports joining them
64. If type is `DataStore` → classify the primary review block before fine analysis:
   - `Store definition and declared connection surface` for declared store identity, primary connection surface, and the main shape of the definition
   - `Configuration parameters and runtime options` for parameters, flags, options, and runtime-operational configuration
   - `Model and consumption context` for how the store fits into the model, its runtime role, and consumption by dependent objects
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
65. For `DataStore`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep store definition, runtime configuration, and consumption-context layers separate until evidence supports joining them
66. If type is `Generator` → classify the primary review block before fine analysis:
   - `Generator definition and declared surface` for what the generator declares itself to be, its main role, and its structural surface
   - `Generation options and technical parameters` for parameters, flags, options, and technical generation behavior
   - `Model and target-platform usage context` for model fit, generation target, effective consumption, and role in the flow
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
67. For `Generator`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep declared surface, technical parameters, and usage-context layers separate until evidence supports joining them
68. If type is `Language` → classify the primary review block before fine analysis:
   - `Language definition and declared surface` for what the object declares itself to be, its main role, and its structural surface
   - `Localization parameters and technical options` for parameters, options, codes, flags, and technical localization behavior
   - `Model and runtime usage context` for model fit, effective consumption, runtime linkage, and functional role of the language
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
69. For `Language`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep declared surface, localization parameters, and usage-context layers separate until evidence supports joining them
70. If type is `Document` → classify the primary review block before fine analysis:
   - `Document identity and declared surface` for what the document declares itself to be, its main role, naming, and structural surface
   - `Materialized content and payload fidelity` for materialized content, payload integrity, text/byte preservation, and extraction fidelity
   - `References and functional consumption context` for consumers of the document, external links, functional dependency, and role in the wider flow
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
71. For `Document`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep declared surface, payload, and consumption-context layers separate until evidence supports joining them
72. If type is `DeploymentUnit` → classify the primary review block before fine analysis:
   - `Deployment unit definition and declared surface` for what the unit declares itself to be, its main role, and its structural surface
   - `Packaging parameters and technical options` for parameters, options, flags, and technical packaging or delivery behavior
   - `Runtime or delivery context` for flow fit, delivery target, effective consumption, and operational role
   - `Identity and container` for `fullyQualifiedName`, `name`, `guid`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
73. For `DeploymentUnit`, open adjacent blocks only when there is explicit functional dependency with the primary block, name that transition in the analysis, and keep declared surface, technical parameters, and delivery-context layers separate until evidence supports joining them
74. If type is `Procedure` → classify the primary review block before fine analysis:
   - `Source` for filters, flow, conditions, assignments, navigation, and calls made in the body
   - `Rules/parm` for signature, parameters, declarative contract, and rule-focused errors
   - `Variables` for existence, type, helper declarations, and collection-vs-simple coherence
   - `Calls and dependencies` for callee review, dependency chain, and proof of caller call-site
   - `Identity and container` for `fullyQualifiedName`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
   - `Report layout` only when the `Procedure` is a report and the symptoms involve `Bands`, `PrintBlock`, `ReportLabel`, `ReportAttribute`, or layout shape
75. For `Procedure`, open adjacent blocks only when there is explicit functional dependency with the primary block, and name that transition in the analysis
76. If type is report `Procedure` → load [05b-procedure-relatorio-familias-e-templates](../05b-procedure-relatorio-familias-e-templates.md), classify family, and separate observed evidence into `Source`, `Rules`, and layout
77. For report `Procedure`, if the symptoms point to `invalid control`, `printBlock`, `ReportLabel`, or `ReportAttribute`, classify the primary suspicion as layout; if they point to `parm(...)` or missing `;`, classify the primary suspicion as `Rules`; if they point to `Header`, `Footer`, `For each`, or `Output_file`, classify the primary suspicion as `Source`
78. For report `Procedure`, if the case still fits simple F2/F3 coverage with no repeated structural failure signal, report that sanitized canonical coverage is still available and label the basis as `molde sanitizado`; otherwise recommend escalation to comparable real XML explicitly
79. Assign risk level from [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md)
80. Report result:
   - Object type and canonical name
   - Container classification (`Folder`, `Module`, or unresolved)
   - Structural family (if applicable)
   - For `WebPanel`, primary review block and any justified block transition used in the analysis
   - For `WorkWithForWeb`, primary review block and any justified block transition used in the analysis
   - For `DataSelector`, primary review block and any justified block transition used in the analysis
   - For `Panel`, primary review block and any justified block transition used in the analysis
   - For `Transaction`, primary review block and any justified block transition used in the analysis, plus explicit scope via web editing, via BC, or unresolved
   - For `DataProvider`, primary review block and any justified block transition used in the analysis
   - For `API`, primary review block and any justified block transition used in the analysis
   - For `SDT`, primary review block and any justified block transition used in the analysis
   - For `Theme`, primary review block and any justified block transition used in the analysis
   - For `Attribute`, primary review block and any justified block transition used in the analysis
   - For `PatternSettings`, primary review block and any justified block transition used in the analysis
   - For `Folder`, primary review block and any justified block transition used in the analysis
   - For `Domain`, primary review block and any justified block transition used in the analysis
   - For `Table`, primary review block and any justified block transition used in the analysis
   - For `ExternalObject`, primary review block and any justified block transition used in the analysis
   - For `UserControl`, primary review block and any justified block transition used in the analysis
   - For `SubTypeGroup`, primary review block and any justified block transition used in the analysis
   - For `File`, primary review block and any justified block transition used in the analysis
   - For `Dashboard`, primary review block and any justified block transition used in the analysis
   - For `Stencil`, primary review block and any justified block transition used in the analysis
   - For `DataStore`, primary review block and any justified block transition used in the analysis
   - For `Generator`, primary review block and any justified block transition used in the analysis
   - For `Language`, primary review block and any justified block transition used in the analysis
   - For `Document`, primary review block and any justified block transition used in the analysis
   - For `DeploymentUnit`, primary review block and any justified block transition used in the analysis
   - For `Procedure`, primary review block and any justified block transition used in the analysis
   - Risk level
   - Part types: present / expected / missing — or N/A if the type is confirmed in [01b] as using no Parts
   - For report `Procedure`, anomaly layer and escalation recommendation (`sanitized canonical template still fits` vs `escalate to comparable real XML`)
   - For report `Procedure`, basis used labeled as exactly one of: `molde sanitizado`, `XML real da KB atual`, `XML real de outra KB`, or `hipótese`
   - Identity fields: `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, `moduleGuid`
   - Confidence level for each conclusion
   - Any structural anomalies detected

---

## QUALITY CHECKLIST

- [ ] `Object/@type` identified and mapped to known category
- [ ] Part types enumerated and compared against corpus frequencies — or confirmed N/A for types that use no Parts per [01b]
- [ ] Any cited XML line has an explicit evidence role (`effective Source`, `Rules/parm`, `XML metadata`, `call in caller`, or `signature in callee`)
- [ ] BC variables cited from XML metadata or `Source` were classified as simple or collection using `ATTCUSTOMTYPE` together with `AttCollection`
- [ ] BC methods cited from `Source` were classified by family (`operation`, `status/message`, `serialization/copy`, or `collection`)
- [ ] Container identity classified from `parentType` and comparable corpus evidence
- [ ] Risk level stated with source reference
- [ ] Family classified when type supports it (WebPanel, Transaction)
- [ ] For `WebPanel`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `WorkWithForWeb`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `DataSelector`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Panel`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Transaction`, the primary review block was declared before fine analysis, any block transition was justified explicitly, and web editing vs BC scope was stated when relevant
- [ ] For `DataProvider`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `API`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Table`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `ExternalObject`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `UserControl`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `SubTypeGroup`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `File`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Dashboard`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Stencil`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `DataStore`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Generator`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Language`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Document`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `DeploymentUnit`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For `Procedure`, the primary review block was declared before fine analysis and any block transition was justified explicitly
- [ ] For report `Procedure`, evidence was separated into `Source`, `Rules`, and layout and the escalation status was made explicit
- [ ] Confidence level declared for every conclusion
- [ ] No import/build compatibility claims made
- [ ] No Part type GUIDs invented outside observed corpus

---

## CONSTRAINTS

- NEVER flag absence of `<Part>` as a structural anomaly for types confirmed in [01b-matriz-part-types-por-tipo](../01b-matriz-part-types-por-tipo.md) as using no Parts (`ThemeClass`, `ThemeColor`, `Generator`, `DataStore`, `Module/Folder`)
- NEVER invent a Part type GUID not observed in the empirical corpus
- NEVER promote a Hypothesis to Strong Inference without new direct evidence
- NEVER affirm import or build success — structural analysis only
- When `dataSource="gx-legacy-export"` or a `GxLegacyPayload` node is present, treat the modern envelope as adaptation for inventory; analyze structure inside the payload and do not assume modern `Part type` layout without evidence
- ABORT analysis if XML is too malformed to identify `Object/@type`
- When sample is small or type is rare, state it explicitly before concluding
- When object lookup depends on a local repository, ABORT if the file was not confirmed in the folder implied by the validated object type
- When repository-backed analysis depends on the KB parallel folder structure, ABORT if that structure was not clarified or validated first
- NEVER present a `parm(...)` line from the called object's XML as the caller's call site
- NEVER treat `ATTCUSTOMTYPE` `bc:<Transaction>` alone as enough to collapse BC simple and BC collection into the same contract
- NEVER turn BC `status/message` methods such as `.Success()`, `.Fail()`, or `.GetMessages()` into a new functional operation without direct evidence beyond the cited line
- NEVER infer runtime semantics for BC collection methods from name similarity alone; require the simple-vs-collection classification first
- For `WebPanel`, NEVER jump from one functional block to another without explicit dependency rationale
- For `WorkWithForWeb`, NEVER jump from one functional block to another without explicit dependency rationale, and NEVER treat surrounding generated `WebPanel` or `WorkWithPlus` artifacts as canonical internal blocks of the WW itself
- For `DataSelector`, NEVER collapse parameter contract, applied filter, and real KB dependency into a single conclusion without explicit evidence joining those layers
- For `Panel`, NEVER collapse the panel surface and the structural coupling around it into the same conclusion without explicit evidence joining those layers
- For `Transaction`, NEVER collapse web editing and BC behavior into the same conclusion without explicit evidence
- For `DataProvider`, NEVER treat output shape as proved only by dependency inventory, or navigation context as proved only by the return shape
- For `API`, NEVER treat dependency inventory as enough to prove service contract, or service contract text as enough to prove the full orchestration chain
- For `Table`, NEVER treat embedded `Index` as an independent top-level object in this review, and NEVER treat absence of named `parent` as proof that the `Table` has no contextual dependency
- For `ExternalObject`, NEVER treat native-binding/platform metadata as enough to prove method signatures, or exposed surface text as enough to prove technical binding correctness
- For `UserControl`, NEVER treat runtime dependency presence as enough to prove property/event binding correctness, or declared control surface as enough to prove runtime integration is complete
- For `SubTypeGroup`, NEVER treat contextual usage in another object as enough to prove internal subtype-role mapping correctness, or internal group composition as enough to prove contextual usage is coherent
- For `File`, NEVER treat declared resource identity/surface as enough to prove payload fidelity, or payload fidelity as enough to prove correct consumption context
- For `Dashboard`, NEVER treat visual composition as enough to prove widget/data binding correctness, or widget/data binding as enough to prove navigation/interaction coherence
- For `Stencil`, NEVER treat structural definition as enough to prove parameterization correctness, or consumption by pattern/generation as enough to prove internal stencil definition is coherent
- For `DataStore`, NEVER treat declared connection surface as enough to prove runtime configuration correctness, or runtime configuration as enough to prove coherent consumption context in the model
- For `Generator`, NEVER treat declared generator surface as enough to prove technical-parameter correctness, or technical parameters as enough to prove coherent target-platform usage context
- For `Language`, NEVER treat declared language surface as enough to prove localization-parameter correctness, or localization parameters as enough to prove coherent model/runtime usage context
- For `Document`, NEVER treat declared document surface as enough to prove payload fidelity, or payload fidelity as enough to prove coherent functional consumption context
- For `DeploymentUnit`, NEVER treat declared deployment-unit surface as enough to prove packaging-parameter correctness, or technical parameters as enough to prove coherent delivery/runtime context
- For `Procedure`, NEVER jump from one functional block to another without explicit dependency rationale
- Absolute rules in [00-indice-da-base-genexus-xpz-xml.md](../00-indice-da-base-genexus-xpz-xml.md) take precedence over all heuristics
