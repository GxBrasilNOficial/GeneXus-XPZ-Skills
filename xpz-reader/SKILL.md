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
- For `WorkWithForWeb`, classify the review by functional block before fine analysis: `Transaction binding`, `Pattern structure and navigation`, `Actions, links and prompts`, `Attribute references and data contract`, or `Identity and container`
- For `DataSelector`, classify the review by functional block before fine analysis: `Selection contract`, `Selection logic and conditions`, `Attribute and function dependencies`, `Navigation context`, or `Identity and container`
- For `Panel`, classify the review by functional block before fine analysis: `Panel structure and layout`, `Serialized behavior and configuration`, `Pattern and parent coupling`, `External dependencies`, or `Identity and container`
- For `Transaction`, classify the review by functional block before fine analysis: `Transaction structure`, `Attributes and attribute properties`, `Rules`, `Events`, `Execution context`, or `Identity and container`
- For `Procedure`, classify the review by functional block before fine analysis: `Source`, `Rules/parm`, `Variables`, `Calls and dependencies`, `Identity and container`, and `Report layout` when applicable
- For `DataProvider`, classify the review by functional block before fine analysis: `Output structure`, `Source`, `Navigation context`, `Calls and dependencies`, or `Identity and container`
- For `API`, classify the review by functional block before fine analysis: `Service contract`, `Events and orchestration`, `Calls and dependencies`, `Data contract`, or `Identity and container`
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
- When reading BC method calls in `Source`, classify the method family as `operation`, `status/message`, `serialization/copy`, or `collection`, and keep that classification separate from runtime semantics not directly proved by the XML
- Declare confidence level for every conclusion: `Direct evidence` / `Strong inference` / `Hypothesis`
- Never affirm import or build compatibility — structural analysis only
- When the task depends on a local KB parallel folder structure, require that structure to be clarified or validated first via `xpz-kb-parallel-setup`
- When the object analyzed is a WWP PatternInstance (`WorkWithPlus*`): flag as structural anomaly any duplicate nodes in `<attribute>`, `<gridAttribute>`, or `<parameter>`; `parentGuid` inconsistent with the object name; and references to attributes apparently absent from the current model — if the user intends to package or clone the object, encaminhar para `xpz-builder`

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
26. If type is `Procedure` → classify the primary review block before fine analysis:
   - `Source` for filters, flow, conditions, assignments, navigation, and calls made in the body
   - `Rules/parm` for signature, parameters, declarative contract, and rule-focused errors
   - `Variables` for existence, type, helper declarations, and collection-vs-simple coherence
   - `Calls and dependencies` for callee review, dependency chain, and proof of caller call-site
   - `Identity and container` for `fullyQualifiedName`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
   - `Report layout` only when the `Procedure` is a report and the symptoms involve `Bands`, `PrintBlock`, `ReportLabel`, `ReportAttribute`, or layout shape
27. For `Procedure`, open adjacent blocks only when there is explicit functional dependency with the primary block, and name that transition in the analysis
28. If type is report `Procedure` → load [05b-procedure-relatorio-familias-e-templates](../05b-procedure-relatorio-familias-e-templates.md), classify family, and separate observed evidence into `Source`, `Rules`, and layout
29. For report `Procedure`, if the symptoms point to `invalid control`, `printBlock`, `ReportLabel`, or `ReportAttribute`, classify the primary suspicion as layout; if they point to `parm(...)` or missing `;`, classify the primary suspicion as `Rules`; if they point to `Header`, `Footer`, `For each`, or `Output_file`, classify the primary suspicion as `Source`
30. For report `Procedure`, if the case still fits simple F2/F3 coverage with no repeated structural failure signal, report that sanitized canonical coverage is still available and label the basis as `molde sanitizado`; otherwise recommend escalation to comparable real XML explicitly
31. Assign risk level from [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md)
32. Report result:
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
   - For `Procedure`, primary review block and any justified block transition used in the analysis
   - Risk level
   - Part types: present / expected / missing — or N/A if the type is confirmed in [01b] as using no Parts
   - For report `Procedure`, anomaly layer and escalation recommendation (`sanitized canonical template still fits` vs `escalate to comparable real XML`)
   - For report `Procedure`, basis used labeled as exactly one of: `molde sanitizado`, `XML real da KB atual`, `XML real de outra KB`, or `hipotese`
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
- For `Procedure`, NEVER jump from one functional block to another without explicit dependency rationale
- Absolute rules in [00-indice-da-base-genexus-xpz-xml.md](../00-indice-da-base-genexus-xpz-xml.md) take precedence over all heuristics
