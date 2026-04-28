---
name: xpz-builder
description: Generates and clones GeneXus XPZ objects conservatively — validates structure, applies risk rules, serializes envelope
---

# xpz-builder

Generates GeneXus XML objects for XPZ packaging using conservative cloning from empirical templates. Applies risk rules, validates structure, and serializes the correct XPZ envelope. Does not affirm import or build success — that requires external IDE validation.

---

## GUIDELINE

Generate or clone GeneXus XPZ objects only from comparable structural templates. Abort when a suitable template does not exist. Never invent structure.

If the flow depends on a KB parallel folder structure and that structure is not yet mounted or validated, stop and use `xpz-kb-parallel-setup` first.

## PATH RESOLUTION

- This `SKILL.md` lives inside a skill subfolder under the repository root.
- Resolve every `../arquivo.md` reference relative to the directory of this `SKILL.md`, not relative to the current working directory.
- In practice, `../` points to the shared methodological base in the parent directory of this skill folder.

---

## TRIGGERS

Use this skill for:
- User asks to generate an XPZ for a specific GeneXus object type
- User asks to clone, rename, or adapt an existing XML object
- User asks to package one or more objects into an XPZ envelope
- User asks to validate an XML object before packaging
- User asks which template or molde to use for a given object type
- User asks how to construct the `<ExportFile>` envelope

Do NOT use this skill for:
- Analyzing or classifying existing XML without modification intent (use `xpz-reader`)
- Questions about GeneXus runtime, build behavior, or IDE configuration
- Generating KnowledgeBase-level exports or full KB backups
- Affirming that generated XPZ will import or build without errors
- Locating or finding objects in the KB corpus by name, type, or function (use `xpz-index-triage` first when a KbIntelligence index is available)

If the main need is to prepare or validate the initial folder structure around the KB before any packaging flow, use `xpz-kb-parallel-setup`.

---

## RESPONSIBILITIES

- Identify the target object type and locate the most comparable structural template
- Apply risk assessment from [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md) before proceeding
- Abort if no comparable structural template exists and risk is high or very high
- Clone conservatively: preserve `Object/@guid`, `parent*`, `moduleGuid`, all recurring Part types
- Apply XPZ envelope rules from [02-regras-operacionais-e-runtime](../02-regras-operacionais-e-runtime.md)
- Choose package format for deltas of existing objects by validated local precedent first, distinguishing explicitly between embedded-object packages under `<Objects>` and packages that use `<FilePath>` to point to external XML
- Treat local precedent as strong only when the same KB trail shows compatible object type, compatible operation nature, and compatible batch materialization style
- Abort for confirmation instead of extrapolating from weak analogy when no strong enough local precedent justifies the package format
- Treat `runtime`, `Import File Load`, `Import`, and `Specification` as distinct validation layers; success in one does not authorize conclusions about the others
- Validate `Source` compatibility by methodology first: GeneXus semantic rules plus the XPZ trail and `nexa`; use KB corpus search only as fallback when the methodological base does not cover the case
- For simple report `Procedure`, prefer the documented sanitized canonical template first; use it as a materialization source only when the selected block in [05b-procedure-relatorio-familias-e-templates](../05b-procedure-relatorio-familias-e-templates.md) is marked as `molde pronto`; escalate to KB corpus only when the methodological base does not cover the case, when the initial attempt plus one short structural corrective attempt fail, or when KB-local dialect/localism appears
- Classify each package candidate by content delta as `requested change`, `necessary auxiliary change`, or `extra unrequested change` before packaging
- Require explicit signaling before packaging when a candidate item remains as `extra unrequested change`, including metadata, reserialization, or known noise that is not strictly required
- Generate valid `lastUpdate` timestamp (real local time, not placeholder)
- Treat `ObjetosDaKbEmXml` as official snapshot and read-only for agents
- Treat any detected or intended edit in `ObjetosDaKbEmXml` for a delta that has not yet returned by official KB re-export as an explicit process error, not as a mere operational detail
- If the object has not yet returned from the KB by official export, perform the work only in `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- When the user does not provide alternative names, assume these standard KB subfolders for initial load:
  - `ObjetosDaKbEmXml`
  - `XpzExportadosPelaIDE`
  - `scripts`
  - `Temp`
  - `KbIntelligence`
  - `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  - `PacotesGeradosParaImportacaoNaKbNoGenexus`
- If some subfolders do not exist yet, prefer creating them in this order:
  1. `scripts`
  2. `Temp`
  3. `XpzExportadosPelaIDE`
  4. `ObjetosDaKbEmXml`
  5. `KbIntelligence`
  6. `ObjetosGeradosParaImportacaoNaKbNoGenexus`
  7. `PacotesGeradosParaImportacaoNaKbNoGenexus`
- If `XpzExportadosPelaIDE` does not exist yet, ask where the user wants to store exported `.xpz` files
- If `ObjetosDaKbEmXml` does not exist yet, stop and treat the KB as not yet materialized
- Use `ObjetosGeradosParaImportacaoNaKbNoGenexus` as the working area for locally generated or preserved XML
- For each active front, create or reuse a dedicated subfolder under `ObjetosGeradosParaImportacaoNaKbNoGenexus` in the format `NomeCurto_GUID_YYYYMMDD`
- Treat `YYYYMMDD` in that identifier as the creation date of the front, defined at the same moment the GUID is created; it is not the package date
- Distinguish explicitly between `same object` and `same front`
- Do NOT reuse front identity, short-name prefix, front GUID, front creation date, or package counter only because the target object is the same
- Reuse the existing front subfolder only when the work is explicitly confirmed or directly evidenced as a continuation of that same front; do NOT create a second front folder for the same active front without explicit reason
- Use `PacotesGeradosParaImportacaoNaKbNoGenexus` as the destination area for locally generated packages
- Detect workspace contamination before packaging and abort when more than one plausible batch is active
- Treat the workspace as contaminated when the active root of `ObjetosGeradosParaImportacaoNaKbNoGenexus` contains XMLs from different fronts, different target objects, superseded deltas, or unrelated older files that could be mistaken for the current batch
- Build or validate a manifest for the candidate batch before packaging, treating the manifest first as structured output in the conversation
- When the user already signals manual IDE import/testing, treat `import_file.xml` as the primary deliverable and generate it promptly instead of postponing packaging
- Prefer `import_file.xml` as the operational package artifact for manual IDE import unless `.xpz` is explicitly required by the user or by a documented local flow
- Do NOT generate `.xpz` as an extra artifact by default when `import_file.xml` already satisfies the intended manual IDE import flow
- Name locally generated packages for IDE import using the preferred pattern `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- In that package name, the front is identified only by the prefix `NomeCurto_GUID_YYYYMMDD`; `nn` is only the short package round for that front
- Before writing `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, check whether a package with the same front prefix `NomeCurto_GUID_YYYYMMDD` and the same `nn` already exists in `PacotesGeradosParaImportacaoNaKbNoGenexus`
- If the same front prefix and the same `nn` already exist, abort the write; do NOT silently overwrite that round
- When there is an `nn` collision, return an explicit error with the next free `nn` suggested for that front, but do NOT auto-increment or write automatically with the suggested value
- Keep `PacotesGeradosParaImportacaoNaKbNoGenexus` flat, without subfolders by front
- Classify each active XML root as `Object`, `Attribute`, or unsupported before serializing the package
- For a new `Transaction` package, treat top-level `Attribute` items referenced by the `Level` as mandatory package members under `<Attributes>`, never as `Domain`/object payload under `<Objects>`
- Validate UTF-8 without BOM hygiene on active XMLs before packaging
- Reread and apply local repository documentation (`AGENTS.md`, `README.md`, and equivalent project docs) before packaging whenever the target KB/repository defines specific functional review rules, contracts, or operational flow
- Use local repository documentation as the mandatory specialization layer for KB-specific contracts and review chains, without promoting those local rules to the shared XPZ methodology
- Keep general XPZ methodology separate from KB-specific architecture; flows such as `WorkWithWeb -> action -> parm(...) -> For each` may be mandatory in a given repository but are not universal GeneXus or XPZ rules
- Ensure all GUIDs are syntactically valid (no text placeholders like `"YOUR-GUID-HERE"`)
- Validate XML structure before delivery
- Declare confidence level and limitations explicitly at the end of every output
- Keep `WorkWithWeb` noise that is already proven in this trail as non-functional in the manifest, especially `Load Code` in `Selection` and the affected `View` tabs; do not generalize this to unrelated `WorkWithWeb` cases
- When changing a `Procedure`, run a minimum semantic pre-packaging gate on the `Procedure` itself:
  - if `parm(...)` changed, every new parm variable must exist in the variables section of the object
  - if `parm(...)` changed, variable name, base type, and presence must remain coherent
  - if `parm(...)` changed or a direct call is reviewed, distinguish the callee signature line from each caller call-site line
  - do NOT treat the callee `parm(...)` line as evidence that a caller invokes that `Procedure`
  - for report `Procedure`, classify every edited fragment as `Source`, `Rules`, or layout before accepting the change
  - for report `Procedure`, keep `Output_file`, `Header`, `Footer`, `For each`, and `print printBlock...` in `Source`
  - for report `Procedure`, keep `parm(...)` in `Rules`
  - for report `Procedure`, keep `Bands`, `PrintBlock`, `ReportLabel`, and `ReportAttribute` in layout `Part c414ed00-8cc4-4f44-8820-4baf93547173`
  - for report `Procedure`, never invent GXML-like layout, unsupported controls, or unproved shape to "complete" the object
  - after one initial structural attempt plus at most one short corrective attempt for report `Procedure`, stop iterating by analogy and escalate to comparable real XML
  - if the current `Source` delta introduces a new helper variable, that variable must exist in the variables section and its declared type must remain coherent with the way it is used
  - if the current `Source` delta introduces a method call on a variable, accept it only when that method is compatible with the declared variable type and is anchored by the methodological base loaded for the case
  - if the current `Source` delta introduces cleanup or reinitialization of a collection, SDT, or `Messages, GeneXus.Common`, accept only patterns anchored by the methodological base for that declared type
  - for collection reinitialization introduced by the current `Source` delta and already covered by the methodological base, prefer `= new()`; do NOT accept unsupported cleanup forms such as `SetEmpty()` only by plausibility or analogy
  - if a period filter is introduced over a `DateTime` field, prefer direct comparison on the `DateTime` column: `>=` start and `<` next day after end
  - treat function on the database column, especially `ToDate()` over the column, as explicit navigation/performance risk
  - if a function on the column is kept, justify it explicitly
  - when the user asks for an initial-date/final-date pair, prefer two independent `where` clauses instead of branching into unnecessary scenarios
  - when the object already has a clear local form in `Source`, prefer following that form as a weak readability heuristic, not as a hard methodological rule

---

## COMMUNICATION

- Respond in the same language the user writes in
- Lead with the decision (proceed / abort) and the reason
- State which template was used and why it was selected
- Always end output with a limitations block: what was followed, what requires external validation
- In the closing, declare explicitly whether the front identity was confirmed, directly evidenced, or assumed under local rule
- In the closing, declare explicitly whether the package reused an existing front or opened a new front
- In the closing, declare explicitly why the final package name was chosen
- In the closing, explicitly state that the saved XML was reread, the persisted `lastUpdate` was confirmed, and the applicable local repository rules were reread and satisfied before packaging
- Use NEVER and ABORT as hard stops, not suggestions
- NEVER use speculative or reassuring language about import/build success

---

## STRUCTURE

Reference files and when to load them:

| Reference | Load when |
|-----------|-----------|
| [00-indice-da-base-genexus-xpz-xml.md](../00-indice-da-base-genexus-xpz-xml.md) | Always — absolute rules and envelope structure |
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Always — envelope serialization, timestamp, GUID, ObjectsIdentityMapping rules |
| [03-risco-e-decisao-por-tipo.md](../03-risco-e-decisao-por-tipo.md) | Always — risk level and abort conditions |
| [04-webpanel-familias-e-templates.md](../04-webpanel-familias-e-templates.md) | Target is a WebPanel object |
| [05-transaction-familias-e-templates.md](../05-transaction-familias-e-templates.md) | Target is a Transaction object |
| [07-open-points-e-checklist.md](../07-open-points-e-checklist.md) | Edge cases, provisional decisions, or checklist for new templates |
| [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md) | Decision formula, precedence rules, materialization rules, refuse conditions |
| `xpz-index-triage` skill | When a KbIntelligence index is available and locating comparable corpus XMLs or confirming object existence is needed before opening XML files |

---

## WORKFLOW

1. Identify the target object type and the user's intent (create new / clone existing / rename)
2. If the KB parallel folder structure is not yet mounted, not yet validated, or still ambiguous for this repository → **ABORT** and use `xpz-kb-parallel-setup` first
3. Reread local repository documentation and resolve the operational topology for this KB/repository:
   - `ObjetosDaKbEmXml` = official snapshot, read-only for agents
   - `XpzExportadosPelaIDE` = input area where the user stores `.xpz` exported by the IDE
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` = working area for local XMLs to import manually, organized by front subfolder `NomeCurto_GUID_YYYYMMDD`
   - each front subfolder is the active unit of that work front
   - `PacotesGeradosParaImportacaoNaKbNoGenexus` = output area for locally generated packages, kept flat without subfolders by front
   - if the object has not yet returned from the KB by official export, the work must stay in `ObjetosGeradosParaImportacaoNaKbNoGenexus`
4. Before generating or packaging a front, resolve the front identifier explicitly:
   - determine whether the case is `same front` or `new front`
   - do NOT infer `same front` only because the object is the same
   - if continuity was not explicitly stated and no direct repository evidence closes that ambiguity, block automatic inheritance of the previous front identity and follow the applicable local rule
   - only after that, define:
     - `NomeCurto`
     - `GUID` generated when the front is opened
     - `YYYYMMDD` = creation date of the front, defined together with the GUID; it is not the package date
     - front folder = `ObjetosGeradosParaImportacaoNaKbNoGenexus\NomeCurto_GUID_YYYYMMDD\`
     - if that front folder already exists for the current front, reuse it
     - that front folder is the active unit of the work front
5. When the task is packaging, list active XMLs only inside the current front folder and treat them as the candidate batch
6. Evaluate batch isolation before packaging:
   - If more than one plausible batch is present inside the current front folder → **ABORT**
   - Do NOT infer the correct batch only from recency when there is contamination risk
   - If the current front needs a new isolated single-object delta and the current front folder contains remnant XMLs that do not belong to the current front decision, treat that front folder as contaminated and **ABORT** until the unitary batch is isolated explicitly
   - Treat a front-folder XML as a remnant contaminant when it is not part of the current front decision, is not part of the package being assembled now, was superseded by change of direction, or remains inside the active front folder without operational justification for the current batch
   - Preferred operational resolution for a new unitary delta: keep only the current object XML inside the current front folder as the active batch
   - Before generating new files, offer to move remnant contaminant XMLs from the current front folder to `ArquivoMorto`; do so only after explicit user approval
   - Do NOT silently reuse a contaminated front folder batch when the current front is unitary
   - Distinguish explicitly between `artifact of the current front` and `pre-existing parallel change`:
     - current-front artifact = XML intentionally produced, adjusted, or preserved for the current package decision
     - pre-existing parallel change = unrelated XML/package/workspace modification that already existed and is not part of the current batch decision
   - Do NOT absorb pre-existing parallel changes into the package of the current front only because they are present in the workspace
   - Classify current-batch content as `requested change`, `necessary auxiliary change`, or `extra unrequested change`
   - Signal any `extra unrequested change` explicitly before packaging; do NOT silently absorb it into the package
   - If an older package lost validity after a change of direction, either rename it with prefix `OBSOLETO_` or present a structured manifest in the conversation stating that package X was replaced by package Y; save that manifest as a local file only when local traceability is concretely needed
7. Check for improper local changes in `ObjetosDaKbEmXml`:
   - If detected, treat this as an explicit process error
   - Preserve those XMLs in `ObjetosGeradosParaImportacaoNaKbNoGenexus`, restore `ObjetosDaKbEmXml` to the official Git version, present a structured manifest of preserved items in the conversation, save it as a local file when incident traceability requires it, and **ABORT** packaging until the snapshot is sane
   - If the target object has not yet returned from the KB by official export, keep working only from `ObjetosGeradosParaImportacaoNaKbNoGenexus`
8. Load [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md) → assign risk level
9. Evaluate abort conditions:
   - Risk is high/very high AND no comparable internal template exists → **ABORT**
   - Type is not in the empirical corpus → **ABORT**
   - User requests affirmation of import/build success → **REFUSE**, state limitation
10. Locate template:
   - Transaction → use family F1–F6 from [05-transaction-familias-e-templates](../05-transaction-familias-e-templates.md)
   - WebPanel → use closest family from [04-webpanel-familias-e-templates](../04-webpanel-familias-e-templates.md)
   - Simple report `Procedure` → use the canonical sanitized family from [05b-procedure-relatorio-familias-e-templates](../05b-procedure-relatorio-familias-e-templates.md) first when the case fits simple F2/F3 coverage and the selected block is marked as `molde pronto`
   - Other types → use sanitized representative from [08-guia-para-agente-gpt](../08-guia-para-agente-gpt.md) materialization rules
   - For simple report `Procedure`, escalate to comparable real XML only when the request falls outside the documented simple family, when the initial attempt plus one short structural corrective attempt already failed, or when KB-local dialect/localism appears
   - For simple report `Procedure`, every output or handoff must label the basis used as exactly one of: `molde sanitizado`, `XML real da KB atual`, `XML real de outra KB`, or `hipotese`
   - If the object has already returned from the KB via official XPZ processing, prefer the current XML in the official corpus over any older delta/import working copy when selecting the base for a new change
   - Before cloning identity fields, classify the container from comparable corpus XML using `Object/@parentType` — never from the directory name in `ObjetosDaKbEmXml`, which varies across KBs:
     - `00000000-0000-0000-0000-000000000008` = Module/Folder (user-created container; GeneXus IDE shows "Module/Folder: X" in Properties)
     - `c88fffcd-b6f8-0000-8fec-00b5497e2117` = PackagedModule (installed module, cube icon in IDE)
     - `afa47377-41d5-4ae8-9755-6f53150aa361` = Root Module (virtual KB root; no XML file in acervo; objects here show "Module/Folder: Root Module" in Properties)
     - `00000000-0000-0000-0000-000000000006` = system Folder (Main Programs, ToBeDefined); never appears as parentType of packagable objects
11. Apply conservative cloning:
   - Preserve `Object/@guid` (new GUID only for new objects, never reuse existing object's GUID)
   - Preserve `parent`, `parentGuid`, `parentType`, `moduleGuid`
   - Keep all recurring Part types present, even if content is empty
   - Do NOT invent Part types not present in the template
   - Validate identity as a 6-field set before serializing: `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, `moduleGuid`
   - For cloned or newly created objects based on an existing XML, validate expanded internal identity before packaging: `Object/@name`, `fullyQualifiedName`, `guid`, `Name` property, `Description`, `Source`, `Rules/parm`, internal calls, dependencies, and `ObjectsIdentityMapping`
   - Search for residual template object name, description, GUID, and calls; classify each residual occurrence as intentional, necessary dependency, or clone error
   - If any residual template identity remains unclassified, **ABORT** before packaging
   - Do NOT derive `fullyQualifiedName` by concatenating `parent + "." + name`
   - If `parentType` is `00000000-0000-0000-0000-000000000008` (Module/Folder), treat the container name as container only; it must appear in `parent`/`parentGuid`, not be promoted automatically into `fullyQualifiedName`
   - If `parentType` is `c88fffcd-b6f8-0000-8fec-00b5497e2117` (PackagedModule), allow module qualification in `fullyQualifiedName` only when comparable corpus objects of the same KB confirm that pattern
   - For `WebPanel`, verify where each relevant property is actually persisted before editing: `Conditions` may live in its own `Part`, while `ControlWhere`, `ControlBaseTable`, `ControlOrder`, `ControlUnique`, `PATTERN_ELEMENT_CUSTOM_PROPERTIES`, and `WebUserControlProperties` often live inside serialized layout metadata; follow the operational rules in [02-regras-operacionais-e-runtime](../02-regras-operacionais-e-runtime.md)
   - For `WebPanel`, do NOT treat template defaults mentioning `Conditions` as proof that a real filter is materialized in the object
   - Before generating a new delta for an object that already returned from the KB, compare any intermediate import/delta copy against the official corpus XML and rebase on the official corpus if the working copy is stale
   - If a filter, business rule, or functional interpretation depends on a calculated or derived field, open the field formula/source and review the immediate chain of called procedures before defining the condition
   - Do NOT conclude the semantic meaning of a calculated or derived field from its name, label, or mere XML presence
   - If the change introduces or rewrites `Source`, classify every new operator, function, conversion, and string/numeric pattern introduced by the change
   - Each introduced `Source` construct must be anchored by layer-1 methodological evidence from this XPZ trail: explicit rule, sanitized example, or documented template
   - Local KB corpus may confirm or disambiguate the choice, but does NOT replace layer-1 methodological evidence
   - If an essential `Source` construct is still justified only by plausibility, generic GeneXus memory, or isolated local corpus evidence, rewrite it using documented patterns or **ABORT**
   - For report `Procedure`, classify each edited fragment before serialization as `Source`, `Rules`, or layout and reject any cross-layer mixture
   - For report `Procedure`, verify coherence between layout `PrintBlock` names and each `print printBlock...` reference in `Source`
   - For report `Procedure`, if an import error points to invalid control, report block, or layout shape, inspect layout first before altering envelope
12. Apply envelope rules from [02-regras-operacionais-e-runtime](../02-regras-operacionais-e-runtime.md):
   - For delta of an existing object, prefer the package format with validated local precedent in the same KB trail before any generic preference
   - Distinguish explicitly between embedded-object package under `<Objects>` and package using `<FilePath>` to external XML
   - Consider local precedent strong only when object type, operation nature, and batch materialization style are compatible with the current case
   - If precedent is only partial or analogical, justify it explicitly or **ABORT** for confirmation instead of extrapolating
   - If the user has already signaled manual IDE import/testing, generate `import_file.xml` as soon as the delta is materially ready instead of postponing package creation
   - Use `import_file.xml` as the primary package artifact for manual IDE import unless `.xpz` is explicitly required
   - Wrap in `<ExportFile>` with `<KMW>`, `<Source>`, `<Objects>`, `<Dependencies>`
   - Keep `Source/@kb` and `Source/Version/@guid` in valid GUID format
   - Do NOT include special KB block unless explicitly documented as required
13. Set or preserve `lastUpdate` according to the batch-role classification:
   - Classify each active XML as `modified in this round` or `reused unchanged for mandatory dependency closure`
   - If any textual change was persisted in the final XML, classify the item as `modified in this round`
   - Modified object → set `lastUpdate` to the real local timestamp of the final write
   - Unchanged dependency object → preserve the official `lastUpdate` from the official corpus XML
   - If classification and materialized `lastUpdate` diverge → **ABORT**
14. Audit `lastUpdate` after every local write:
   - After writing or rewriting an object XML, reopen the saved file and confirm the root `lastUpdate`
   - If the object was actually modified, `lastUpdate` must reflect the real instant of that last write
   - If the object was not modified and is included only for mandatory dependency closure, preserve the official `lastUpdate` from the corpus XML
   - Do NOT continue to packaging until the saved-file header has been checked
15. Before packaging, classify active XML roots and validate packaging hygiene:
   - `Object` top-level → serialize under `<Objects>`
   - `Attribute` top-level → serialize under `<Attributes>`
   - Unsupported root type → **ABORT** or require explicit treatment
   - For `Transaction`, every attribute referenced by `Level/Attribute` must exist as top-level `Attribute` under `<Attributes>` when the package is meant to create or complete those attributes in the target KB
   - Do NOT serialize those required attributes as `Domain` or any other object type under `<Objects>`
   - Canonical minimum valid package for a new `Transaction`:
     - `<Objects>` = the `Transaction`
     - `<Attributes>` = at minimum the PK and the description/display attribute used by the `Transaction`
     - `<Dependencies>` = only what the selected shape really requires
   - `TransactionOrObject`, when present in a comparable export, may be included as an auxiliary object in `<Objects>`, but it does NOT replace the mandatory top-level `<Attributes>` required by the `Transaction`
   - Validate UTF-8 without BOM on every active XML
   - If BOM is present, remove it and register the correction
   - Prefer package names in the form `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
   - `NomeCurto` must be short, human-readable, and semantically strong
   - `GUID` and `YYYYMMDD` identify the front opening, not the package generation instant
   - `nn` is only the short incremental round counter for that front, not semantic versioning
   - Before writing the package, check whether the same front prefix `NomeCurto_GUID_YYYYMMDD` already has the same `nn` in `PacotesGeradosParaImportacaoNaKbNoGenexus`
   - If the same front prefix already has that `nn`, **ABORT** instead of overwriting the existing file
   - In that collision case, report the next free `nn` suggestion, but do NOT auto-increment or silently save under the suggested value
   - Do NOT default to name-only, date-only/time-only, excessively long conversation descriptions, or always overwriting the same package name
   - Produce or validate a manifest in the conversation containing at minimum: batch front or short description, batch origin, total XML count, `Objects` count, `Attributes` count, included files list or summary, `lastUpdate` applied or preserved, generated package, superseded package when present, and risk/pending notes
   - Save that manifest as a file only when there is an incident involving `ObjetosDaKbEmXml`, package supersession that needs local traceability, explicit user request, or real need for future handoff outside the immediate conversation
   - Validate the final envelope materialized inside `import_file.xml`, not only the source XML files
   - If an object is embedded under `<Objects>`, it must appear as XML element content only; embedded XML declaration such as `<?xml version="1.0" ...?>` inside `<Objects>` is a blocking envelope error
   - If the current flow is manual IDE import and `import_file.xml` is still missing, do NOT treat the packaging task as complete
16. Reread and apply local repository documentation before packaging:
   - Reopen `AGENTS.md`, `README.md`, and any equivalent local KB/repository documentation that defines project-specific functional review chains, contracts, or operational flow
   - Treat those local conventions as mandatory only for that repository, not as universal XPZ methodology
   - If the local documentation requires a functional review chain for the current change type, verify that chain end-to-end in the local XML before packaging
   - Do NOT continue to packaging while any applicable local rule remains pending, ambiguous, or inconsistent in the saved XML
17. Validate:
   - XML is well-formed
   - All recurring Part types present
   - No text placeholder GUIDs remaining
   - Template and target share the same structural family
   - Container identity matches comparable corpus evidence for `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, and `moduleGuid`
   - When the case depends on IDE-oriented editing, prefer the syntax and structure accepted by the editor/importer, not only what appears to work at runtime
   - Validate `Source` compatibility separately from XML well-formedness
   - A plausible GeneXus `Source` is NOT ready unless every new operator, function, conversion, and string/numeric pattern is backed by methodological evidence from this trail
   - Treat local corpus evidence as confirmation or tie-breaker, not as the sole basis for accepting a new `Source` construct
   - For large GeneXus XML, especially `Procedure` with long `Source` or `CDATA`, do not rely on heredoc/here-string as the primary generation mechanism when a structured script or serializer is available
   - If heredoc, here-string, or an equivalent shell writer is used, inspect stderr and reject any artifact whose writer ended by EOF before the expected delimiter
   - Before packaging generated large XML, reread the file header, tail, and affected functional block; confirm the expected root closing tag, complete `CDATA`, and no truncated final line
   - For `WorkWithForWeb`, do not use broad text substitution over repeated tags such as `<actions>`; locate the target `Selection` structurally inside the internal XML before editing actions
   - For `WorkWithForWeb`, confirm any new action appears exactly once in the intended `Selection`; duplicates or ambiguous action scope block packaging
   - When the current delta edits `Source`, reread the saved snippet before packaging and confirm coherent indentation, visually consistent block closure, and absence of visually broken blocks
   - If the current delta introduced or moved `if/endif`, `do case/endcase`, nested blocks, or comparable control-flow boundaries, treat this local readability review as mandatory operational hygiene
   - Treat structural XML validation, package-envelope validation, and semantic-contract validation as separate checks
   - Well-formed XML and an acceptable envelope do NOT prove that signatures, formulas, or business meaning are correct
   - Validate package-envelope serialization explicitly before concluding that the package is ready
   - If the package embeds object XML under `<Objects>`, confirm that no embedded XML declaration remains inside the object payload
   - If a shared procedure changed its `parm(...)`, run the minimum semantic gate on the `Procedure` itself before concluding the delta
   - Minimum semantic gate for `Procedure`:
     - every new parm variable exists in the variables section
     - variable name, base type, and presence remain coherent
     - the saved line for the callee `parm(...)` is classified as signature, not caller evidence
     - every reviewed direct caller has its own call-site evidence in that caller's effective `Source` or explicit call metadata
     - variables referenced by the edited `Source` exist
     - every new helper variable introduced by the current `Source` delta exists in the variables section and remains coherent with its declared type
     - every new method call introduced by the current `Source` delta on a variable is compatible with the declared type of that variable and is anchored by the methodological base loaded for the case
     - cleanup or reinitialization introduced by the current `Source` delta for a collection, SDT, or `Messages, GeneXus.Common` must use a pattern anchored by the methodological base loaded for that declared type
     - for collection reinitialization introduced by the current `Source` delta and already covered by the methodological base, prefer `= new()`; do NOT accept unsupported forms such as `SetEmpty()` only by plausibility or analogy
     - when the current `Source` delta changes identity, uniqueness, ambiguity, count, existence, candidate selection, or materialization filters in a `for each`, search for paired cursor blocks in the same `Source`
     - classify related paired blocks such as `count/then-copy`, `exists/then-load`, `validate/then-apply`, and `select-candidate/then-materialize`
     - if paired blocks share the same logical candidate record, reconcile their identity criteria or justify explicitly why only one block changed
   - If the local repository documentation explicitly requires direct-call review, then review all applicable direct call sites before concluding the delta
   - When direct-call review cites XML line numbers, cite caller and callee separately: caller line = `call site`; callee `parm(...)` line = `signature`
   - Treat chains such as `WorkWithWeb -> action -> parm(...) -> For each`, `WorkWith` to `procPlanilha`, wrappers, or equivalent flows as KB-specific review chains unless the local documentation makes them mandatory for this repository
   - Do NOT universalize a KB-specific architectural chain as if it were a global XPZ rule
   - For filters over `DateTime`, prefer direct comparison on the column: `>=` period start and `<` next day after period end
   - Treat function on the database column, especially `ToDate()` on the field, as an explicit navigation/performance risk
   - If the chosen `Source` keeps a function on the column, justify it explicitly
   - When the intent is a simple initial-date/final-date period, prefer two independent `where` clauses
   - When the object already has a clear local shape in `Source`, prefer following it as a weak readability heuristic
   - Avoid treating parentheses style or relative complexity of the `Source` as a general XPZ methodological rule when that depends on KB convention
   - When import logs are available, classify each message by stage and failure category before concluding anything
   - For `Transaction`, run a semantic pre-import gate before final packaging:
     - each `Level/Attribute@guid` must exist in `<Attributes>/Attribute@guid`
     - each `Level/Attribute` name must exist in `<Attributes>/Attribute@name`
     - each `DescriptionAttribute`, when present, must exist in the same `Level` and also in `<Attributes>`
     - if any of these checks fails → **ABORT** with an objective error message before generating the final package
   - Treat the following pre-import errors as hard blockers that require rebuilding the package, not as recoverable warnings:
     - `Cannot convert Domain to Attribute`
     - `Attribute 'X' in 'Transaction Y' does not exist`
     - `DescriptionAttribute ... could not be found in level attributes`
   - Separate at minimum: XML/package structural error, object identity/serialization error, Source syntax/semantic error, IDE-side lateral error, non-blocking warning, and terminal import success
   - Do NOT conclude from an isolated line; use the terminal relevant stage of the log plus the set of blocking messages
   - If some objects failed and others succeeded, report the result as partial instead of collapsing it into full success or full package failure
   - When creating a corrective package after partial import failure, report the original package, successfully imported objects, failed objects, probable failure category, and corrective package path/name
   - Corrective packages must contain only the necessary delta for failed objects and strictly required dependencies; do NOT resend all original package objects by default
   - Confirm before packaging that all applicable local repository rules were reread and satisfied in the saved XML
18. Deliver XML with limitations block:
   - Which template was used
   - Confidence level
   - That the saved XML was reread and the persisted `lastUpdate` was confirmed after the final local write
   - Which applicable local repository rules were reread and satisfied before packaging
   - What requires external IDE validation (`Import File Load`, `Import`, `Specification`, runtime)

---

## WWP PACKAGING

Aplica-se quando o pacote contém objetos WorkWithPlus. Se a KB não usa WWP, ignorar esta seção inteiramente.

### Regra central

`Apply:WWP` em uma Transaction não garante que todos os objetos WWP já estão presentes no pacote. Considerar WWP completo apenas quando houver evidência dos três elementos:

1. `PatternInstance` da entidade/instância (`WorkWithPlus...`)
2. Objetos derivados (`...WW`, `...WWDS`, `...LoadDVCombo`, `...WWGetFilterData`)
3. Callers e componentes customizados referenciando os nomes reais gerados na KB destino

Se algum desses estiver ausente do pacote: gerar na IDE via Apply Pattern e reexportar, **ou** incluir explicitamente os objetos faltantes no pacote seguinte.

### Decision tree antes de empacotar

1. **Erro de referência para `*WW` ou `wc*` após import?**
   - Sim → confirmar se o pacote trouxe apenas `Apply:WWP` sem os objetos gerados.
2. **`PatternInstance WorkWithPlus*` presente para cada Transaction alvo?**
   - Não → gerar pacote de instâncias por Transaction.
3. **Web component customizado clonado (`wcX`) com pattern próprio?**
   - Sim → transportar trio completo: `wcX`, `WorkWithPluswcX`, `wcXLoadDVCombo`.
4. **Chave ou nome estrutural da entidade mudou?**
   - Sim → revisar duplicatas de atributos/parâmetros no XML da PatternInstance.

### Estratégia de pacotes

Usar fases pequenas e previsíveis:

1. **Estrutura base (`SEM_WWP`)** — Transactions, Attributes, SubtypeGroups, regras/fórmulas sem pattern aplicado.
2. **Estrutura + Apply (`COM_WWP`)** — mesmo conteúdo com `Apply:WWP` nas Transactions alvo.
3. **Instâncias WWP** — `PatternInstance` por Transaction e instâncias customizadas (`wc*`, `wp*`).
4. **Correção cirúrgica** — pacote mínimo para corrigir um ou poucos objetos quebrados.

### Clonagem de instância customizada

Ao clonar tela customizada WorkWithPlus:

- Sempre transportar o trio completo: `wcAlvo`, `WorkWithPluswcAlvo`, `wcAlvoLoadDVCombo`
- Atualizar chamadas para procedures novas (`prGrava*`, `prAltera*`, `prDados*`)
- Remover campos/IDs extintos no modelo novo
- Atualizar callers (`wp*`) para criar o `wc` correto
- Revisar referências a grids `*WW` conforme nome real gerado pelo WWP na KB

---

## QUALITY CHECKLIST

- [ ] Risk level assessed before proceeding
- [ ] Abort condition evaluated explicitly
- [ ] Template selected from empirical corpus (not reconstructed from descriptions)
- [ ] `Object/@guid` valid and appropriate (preserved or newly generated)
- [ ] `parent*` and `moduleGuid` preserved from template or context
- [ ] `fullyQualifiedName`, `name`, `parent`, `parentGuid`, `parentType`, and `moduleGuid` were checked together against comparable corpus XML
- [ ] For cloned/new objects, expanded internal identity was checked: `Object/@name`, `fullyQualifiedName`, `guid`, `Name` property, `Description`, `Source`, `Rules/parm`, internal calls, dependencies, and `ObjectsIdentityMapping`
- [ ] Residual template object names, descriptions, GUIDs, and calls were classified as intentional, necessary dependency, or clone error
- [ ] All recurring Part types present (even if empty)
- [ ] No invented Part type GUIDs
- [ ] Envelope complete: `<ExportFile>`, `<KMW>`, `<Source>`, `<Objects>`, `<Dependencies>`
- [ ] Package format for delta was chosen from validated local precedent when such precedent exists
- [ ] Embedded-object package under `<Objects>` versus package using `<FilePath>` was distinguished explicitly
- [ ] Weak analogy was not used as the sole basis for envelope choice
- [ ] `lastUpdate` is a real timestamp, not a placeholder
- [ ] Active XMLs were classified as `modified in this round` or `reused unchanged for mandatory dependency closure`
- [ ] Every modified object XML was reread after writing and its saved `lastUpdate` was confirmed
- [ ] Every unchanged object reused only for dependency closure preserved the official `lastUpdate`
- [ ] Embedded objects in `import_file.xml` were checked for correct `lastUpdate` handling before delivery
- [ ] `ObjetosDaKbEmXml` was treated as read-only official snapshot
- [ ] Current front folder `NomeCurto_GUID_YYYYMMDD` was created or reused explicitly
- [ ] Active front folder format was validated before packaging; if local rules require `NomeCurto_GUID_YYYYMMDD`, nonconforming folders were reported and realigned before package generation
- [ ] When the task was packaging, active XMLs were listed from the current front folder under `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- [ ] Candidate batch was isolated; no workspace contamination remained
- [ ] When the front required a new unitary delta, the current front folder under `ObjetosGeradosParaImportacaoNaKbNoGenexus` was isolated explicitly before packaging
- [ ] Current-front artifacts were distinguished explicitly from pre-existing parallel changes before packaging
- [ ] Root type of every active XML was classified before package serialization
- [ ] No top-level `Attribute` was placed under `<Objects>`
- [ ] For `Transaction`, every `Level/Attribute@guid` exists in `<Attributes>/Attribute@guid`
- [ ] For `Transaction`, every `Level/Attribute` name exists in `<Attributes>/Attribute@name`
- [ ] For `Transaction`, every `DescriptionAttribute` present exists in the same `Level` and also in `<Attributes>`
- [ ] For `Transaction`, no required `Attribute` was serialized as `Domain` or other object type under `<Objects>`
- [ ] UTF-8 BOM hygiene was checked on every active XML
- [ ] Generated package name followed the preferred `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml` pattern when applicable
- [ ] Package write was blocked if the same front prefix already had the same `nn`
- [ ] Any `nn` collision returned an explicit next-free-round suggestion without auto-incrementing or silent overwrite
- [ ] Batch manifest was produced or validated before packaging, by default in the conversation
- [ ] Any superseded package was either renamed with prefix `OBSOLETO_` or recorded in a structured manifest in the conversation before continuing
- [ ] Manifest file was created only when there was a concrete operational reason
- [ ] When the user had already signaled manual IDE import/testing, `import_file.xml` was generated as the primary deliverable
- [ ] `.xpz` was not generated unless explicitly required by the user or by a documented local flow
- [ ] Applicable local repository documentation was reread before packaging
- [ ] Applicable local functional review chains, contracts, and operational rules were verified end-to-end in the saved XML before packaging
- [ ] Local repository rules were treated as repository-specific specialization, not as universal XPZ methodology
- [ ] `Source/@kb` and `Source/Version/@guid` are valid GUIDs
- [ ] Every new operator, function, conversion, and string/numeric pattern introduced in `Source` is backed by layer-1 methodological evidence
- [ ] Local corpus evidence, when used for `Source`, was treated only as confirmation or tie-breaker
- [ ] No essential `Source` construct was accepted only because it looked plausible
- [ ] For generated large XML, header, tail, expected root closing tag, complete `CDATA`, and absence of truncated final line were verified before packaging
- [ ] Any heredoc/here-string writer stderr was checked, and no artifact ended by EOF before the expected delimiter
- [ ] For `WorkWithForWeb` action changes, the target `Selection` was located structurally and the action appears exactly once in that scope
- [ ] Procedure `Source` deltas that changed candidate/identity filters searched for paired cursor blocks and reconciled or justified `count/then-copy`, `exists/then-load`, `validate/then-apply`, or `select-candidate/then-materialize` criteria
- [ ] If local repository documentation required direct-call review after `parm(...)` change, all applicable direct call sites were reviewed explicitly
- [ ] If `parm(...)` changed, every new parm variable exists in the variables section of the `Procedure`
- [ ] If `parm(...)` changed, variable name, base type, and presence remained coherent
- [ ] Variables referenced by the edited `Source` exist in the `Procedure`
- [ ] Every new helper variable introduced by the current `Source` delta exists in the variables section and remains coherent with its declared type
- [ ] Every new method call introduced by the current `Source` delta on a variable is compatible with the declared type of that variable and is anchored by the methodological base loaded for the case
- [ ] Cleanup or reinitialization introduced by the current `Source` delta for a collection, SDT, or `Messages, GeneXus.Common` uses a pattern anchored by the methodological base loaded for that declared type
- [ ] For collection reinitialization introduced by the current `Source` delta and already covered by the methodological base, `= new()` was preferred and unsupported forms such as `SetEmpty()` were not accepted only by plausibility or analogy
- [ ] Filters over `DateTime` prefer direct comparison on the column and do not use function on the column without explicit justification
- [ ] Simple initial/final period filters were expressed as two independent `where` clauses when applicable
- [ ] When useful for readability, edited `Source` considered the local form already present in the object without turning that into a hard methodological requirement
- [ ] Final package-envelope serialization was validated explicitly, not inferred only from source XML well-formedness
- [ ] No embedded XML declaration remained inside object payload under `<Objects>`
- [ ] When import logs were used, messages were classified by stage and category before diagnosis
- [ ] The final conclusion was based on the terminal relevant stage, not on an isolated warning or side error
- [ ] Partial success was reported explicitly when only some objects failed
- [ ] Any corrective package after partial failure reports original package, successful objects, failed objects, and contains only the necessary delta
- [ ] Final closing explicitly states that the saved XML was reread, the persisted `lastUpdate` was confirmed, and the applicable local rules were reread and satisfied
- [ ] Limitations block included in output
- [ ] If the package contains a WWP PatternInstance (`WorkWithPlus*`): rename collisions were checked (two old fields mapping to the same new name)
- [ ] If the package contains a WWP PatternInstance: duplicate nodes in `<attribute>`, `<gridAttribute>`, and `<parameter>` were removed
- [ ] If the package contains a WWP PatternInstance: `parentGuid` points to the correct target Transaction, not to the source entity
- [ ] If the package contains a WWP PatternInstance: references to attributes apparently removed from the model were reviewed

---

## CONSTRAINTS

- NEVER invent a Part type GUID not present in the selected template
- NEVER affirm import or build success — state "requires external IDE validation"
- NEVER treat `runtime`, `Import File Load`, `Import`, and `Specification` as interchangeable evidence
- NEVER interpret `Import File Load` success as confirmation that an object was imported into the KB; it is a listing and preview step only — actual import requires explicit user confirmation in the subsequent `Import` step
- NEVER use an integer value for `ObjectIdentity/@Type`; always derive it from `Object/@parentType` in the source XML of the object being packaged; an integer causes `Guid should contain 32 digits with 4 dashes` during Import File Load
- NEVER promote a Module/Folder (`parentType="00000000-0000-0000-0000-000000000008"`) container name into `fullyQualifiedName` by analogy or by string concatenation alone
- NEVER propose a business filter over status, authorization, cancellation, invoicing, balance, availability, or similar functional meaning if the chosen field is still semantically justified only by its name or UI label
- NEVER treat plausible GeneXus `Source` as ready when its new syntax is not anchored in the methodological base of this trail
- NEVER deliver XML or package with static, inherited, stale, or non-rechecked `lastUpdate`
- NEVER create, alter, move, rename, or overwrite files in `ObjetosDaKbEmXml`
- NEVER treat an intended edit in `ObjetosDaKbEmXml` for a delta not yet returned by official KB export as acceptable; it is an explicit process error
- NEVER treat locally generated XML as if it were the official KB snapshot
- NEVER keep the active front batch directly in the root of `ObjetosGeradosParaImportacaoNaKbNoGenexus`; use the front folder `NomeCurto_GUID_YYYYMMDD`
- NEVER create automatic subfolders by type under the active front folder in `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- NEVER treat a contaminated active front folder as acceptable for a new isolated single-object delta
- NEVER mix a pre-existing parallel change into the package of the current front only because both are present in the same workspace
- NEVER move files to `ArquivoMorto` without explicit user request
- NEVER place a top-level `Attribute` under `<Objects>`
- NEVER serialize a required `Transaction` attribute as `Domain` under `<Objects>` when the package is supposed to create or supply that attribute
- NEVER embed XML declaration text such as `<?xml version="1.0" ...?>` inside `<Objects>` payload of `import_file.xml`
- NEVER postpone generation of `import_file.xml` after the user has already signaled manual IDE import/testing and the delta is materially ready
- NEVER generate `.xpz` by default when manual IDE import is the target flow and `import_file.xml` is sufficient
- NEVER create subfolders by front under `PacotesGeradosParaImportacaoNaKbNoGenexus`; that package area must remain flat
- NEVER ignore `Cannot convert Domain to Attribute`, `Attribute 'X' in 'Transaction Y' does not exist`, or `DescriptionAttribute ... could not be found in level attributes`; these are blocking package-construction errors for this trail
- NEVER treat `OBSOLETO_` as the default naming convention for normal package generation
- NEVER default to package names that are only subject, only date/time, excessively long conversation prose, or permanent overwrite of the same file name
- NEVER treat an IDE-side lateral error as proof that the XML/package structure failed
- NEVER treat a successful package load as proof that Source, Specification, or runtime are valid
- NEVER universalize a repository-specific functional review rule, contract, or operational convention as if it were a global rule of the shared XPZ methodology
- NEVER pick envelope format for an existing-object delta by generic preference when there is validated local precedent in the same KB trail
- NEVER justify envelope choice only by broad similarity of front, family, or object name
- NEVER treat `WorkWith`, `WorkWithWeb`, `procPlanilha`, wrappers, or action chains as universal architectural obligations of XPZ methodology
- NEVER apply function over a `DateTime` database column in a period filter without treating it as an explicit navigation/performance risk and justifying the exception
- NEVER generate from a text description or markdown summary alone — requires comparable raw XML template
- NEVER generate special KB block (`KnowledgeBase`, `Settings`) for normal single-object XPZ
- NEVER mix base structural changes and surgical corrections in the same large package when patterns are active — keep package phases separate
- NEVER assume that a COM_WWP package includes the objects generated by the pattern — verify PatternInstance and derived objects explicitly
- NEVER import a custom instance (`wc*`, `wp*`) without transporting its corresponding `WorkWithPlus*` object
- NEVER re-apply a pattern over a Transaction without reviewing the diff of existing customizations
- NEVER rename an entity with WWP active without checking for attribute collisions that would break the PatternInstance XML
- ABORT if risk is high/very high and no internal comparable template is available
- ABORT if type has fewer than 5 specimens in the corpus and no sanitized template exists
- ABORT if container identity is unresolved among Module/Folder (`00000000-0000-0000-0000-000000000008`), PackagedModule (`c88fffcd-b6f8-0000-8fec-00b5497e2117`), and Root Module (`afa47377-41d5-4ae8-9755-6f53150aa361`) for the target object
- ABORT if more than one plausible batch is active in the workspace
- ABORT if improper local changes are detected in `ObjetosDaKbEmXml` and the snapshot has not been sanitized yet
- ABORT if classification of an item as modified vs unchanged dependency does not match the materialized `lastUpdate`
- ABORT if an active XML has an unsupported top-level root type for the current package flow
- ABORT if a modified object was rewritten locally but the saved-file `lastUpdate` was not verified before packaging
- ABORT if applicable local repository documentation was not reread before packaging
- ABORT if a local functional review chain, contract, or operational rule required by the target KB is still pending or inconsistent in the saved XML
- ABORT if an essential `Source` construct depends only on intuition, generic GeneXus memory, or isolated local corpus evidence
- Absolute rules in [00-indice-da-base-genexus-xpz-xml.md](../00-indice-da-base-genexus-xpz-xml.md) and [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md) take precedence over all other heuristics

---

## PACKAGE EXAMPLES

- Sanitized single-object `Domain` import package:
  - active XML lives in `ObjetosGeradosParaImportacaoNaKbNoGenexus\NomeCurto_GUID_YYYYMMDD\ObjetoExemplo.xml`
  - package output lives flat in `PacotesGeradosParaImportacaoNaKbNoGenexus\NomeCurto_GUID_YYYYMMDD_01.import_file.xml`
  - the object payload is embedded under `<Objects>`, without an inner XML declaration
  - `<Dependencies />` may be empty, but remains present in the envelope
  - `<ObjectsIdentityMapping>` may contain only the root module identity when that is the only required context in the comparable package
  - the same XML must not be copied into `ObjetosDaKbEmXml`; promotion to that official snapshot only happens after IDE export and the official sync flow

---

## TRANSACTION ERROR EXAMPLES

- `Cannot convert Domain to Attribute`
  - Meaning in this trail: the package exposed a required `Transaction` attribute with the wrong top-level kind
  - Expected correction: keep the `Transaction` in `<Objects>` and place the required top-level `Attribute` nodes in `<Attributes>`
- `Attribute 'TesteId' in 'Teste' does not exist`
  - Meaning in this trail: the `Transaction` level references an attribute that is missing from the target and also missing from `<Attributes>` in the package
  - Expected correction: add the missing top-level `Attribute` to `<Attributes>` with consistent `guid` and `name`
- `DescriptionAttribute ... could not be found in level attributes`
  - Meaning in this trail: `DescriptionAttribute` points to an attribute that is not present in the same `Level` and/or is absent from `<Attributes>`
  - Expected correction: point `DescriptionAttribute` to a real attribute of the same `Level` and include that attribute in `<Attributes>` when the package must create or supply it
