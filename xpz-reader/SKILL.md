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

---

## RESPONSIBILITIES

- Identify `Object/@type` and map to known object category using [01-base-empirica-geral](../01-base-empirica-geral.md)
- Map Part types present in input against observed frequencies and known patterns
- Classify object family when applicable: WebPanel families in [04-webpanel-familias-e-templates](../04-webpanel-familias-e-templates.md), Transaction families in [05-transaction-familias-e-templates](../05-transaction-familias-e-templates.md)
- Classify container identity from `parentType` and check whether the object is under `Folder` or `Module`
- Assign risk level using [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md)
- Identify structural anomalies: unexpected Part types, missing recurring parts, malformed envelope
- Identify identity anomalies involving `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
- Treat object lookup in repository-backed workflows as `type + name`, never `name` alone
- Confirm the real folder where the XML exists before citing, comparing, or using a local object as evidence
- When citing a line from GeneXus XML, classify the cited fragment as `effective Source`, `Rules/parm`, `XML metadata`, `call in caller`, or `signature in callee`
- When reading GeneXus variable declarations or variable metadata, classify `ATTCUSTOMTYPE` `bc:<Transaction>` together with `AttCollection=True/False`; never treat BC simple and BC collection as equivalent contracts
- When reading BC method calls in `Source`, classify the method family as `operation`, `status/message`, `serialization/copy`, or `collection`, and keep that classification separate from runtime semantics not directly proved by the XML
- Declare confidence level for every conclusion: `Direct evidence` / `Strong inference` / `Hypothesis`
- Never affirm import or build compatibility — structural analysis only
- When the task depends on a local KB parallel folder structure, require that structure to be clarified or validated first via `xpz-kb-parallel-setup`

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
| [00-readme-genexus-xpz-xml.md](../00-readme-genexus-xpz-xml.md) | Always — absolute rules and envelope spec |
| [01-base-empirica-geral.md](../01-base-empirica-geral.md) | Identifying object type, Part type frequencies, structural catalog |
| [03-risco-e-decisao-por-tipo.md](../03-risco-e-decisao-por-tipo.md) | Risk classification for any object type |
| [04-webpanel-familias-e-templates.md](../04-webpanel-familias-e-templates.md) | Input contains WebPanel XML |
| [05-transaction-familias-e-templates.md](../05-transaction-familias-e-templates.md) | Input contains Transaction XML |
| [06-padroes-de-objeto-e-nomenclatura.md](../06-padroes-de-objeto-e-nomenclatura.md) | User asks about naming conventions or object organization |
| [09-historico-e-inventario-publico.md](../09-historico-e-inventario-publico.md) | User asks about corpus history, validation trail, or inventory |

---

## WORKFLOW

1. Receive XML input or fragment from user
2. If the task depends on locating files in a local KB parallel folder structure and that structure is still undefined, ambiguous, or unvalidated → **ABORT** and use `xpz-kb-parallel-setup` first
3. Locate `Object/@type` attribute → cross-reference against [01-base-empirica-geral](../01-base-empirica-geral.md) type catalog
4. Enumerate Part types present (`<Part type="...">`) → compare against observed frequencies for that type
5. Identify missing or unexpected Part types relative to the known structural pattern
6. Read container identity fields (`fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, `moduleGuid`) and classify the container as `Folder`, `Module`, or unresolved from comparable corpus evidence
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
12. If type is WebPanel → load [04-webpanel-familias-e-templates](../04-webpanel-familias-e-templates.md) and classify family
13. If type is Transaction → load [05-transaction-familias-e-templates](../05-transaction-familias-e-templates.md) and classify family (F1–F6)
14. Assign risk level from [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md)
15. Report result:
   - Object type and canonical name
   - Container classification (`Folder`, `Module`, or unresolved)
   - Structural family (if applicable)
   - Risk level
   - Part types: present / expected / missing
   - Identity fields: `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, `moduleGuid`
   - Confidence level for each conclusion
   - Any structural anomalies detected

---

## QUALITY CHECKLIST

- [ ] `Object/@type` identified and mapped to known category
- [ ] Part types enumerated and compared against corpus frequencies
- [ ] Any cited XML line has an explicit evidence role (`effective Source`, `Rules/parm`, `XML metadata`, `call in caller`, or `signature in callee`)
- [ ] BC variables cited from XML metadata or `Source` were classified as simple or collection using `ATTCUSTOMTYPE` together with `AttCollection`
- [ ] BC methods cited from `Source` were classified by family (`operation`, `status/message`, `serialization/copy`, or `collection`)
- [ ] Container identity classified from `parentType` and comparable corpus evidence
- [ ] Risk level stated with source reference
- [ ] Family classified when type supports it (WebPanel, Transaction)
- [ ] Confidence level declared for every conclusion
- [ ] No import/build compatibility claims made
- [ ] No Part type GUIDs invented outside observed corpus

---

## CONSTRAINTS

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
- Absolute rules in [00-readme-genexus-xpz-xml.md](../00-readme-genexus-xpz-xml.md) take precedence over all heuristics
