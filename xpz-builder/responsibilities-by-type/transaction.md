# Transaction — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `Transaction` object type. **Load this file end-to-end before generating, editing, or packaging a `Transaction`**, in addition to the main `SKILL.md`.

This file consolidates type-specific RESPONSIBILITIES and QUALITY CHECKLIST entries. Type-agnostic rules (envelope serialization, package collision gate, manifest, etc.) remain in the main `SKILL.md`. Gate scripts (9-BC, 9-IDO, 9-TXW Writability, Transaction Coherence) are referenced here but live in `scripts/` and are invoked from the WORKFLOW in the main `SKILL.md`.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `Transaction structure`, `Attributes and attribute properties`, `Rules`, `Events`, `Execution context`, or `Identity and container`.
- When changing a `Transaction`, declare the primary edit block before touching the XML, use only the adjacent blocks required by explicit functional dependency, name each justified block transition, and state whether the intended effect is via web editing, via BC, or both.

### Business Component and dynamic transaction evidence

- `confirmado-acervo` (OnlineShopSS, 2026-07-23): `Category` was observed with `idISBUSINESSCOMPONENT=True` and `idIsDynTrn=False` in the same Transaction XML while supporting an API list proof through a Procedure that navigated `For each Category`.
- Treat this as dated coexistence evidence, not as a universal recipe. Do not document `idIsDynTrn=False` as a standalone mechanism to suppress every initial-load/DataProvider behavior in every Transaction profile; when initial-load behavior matters, keep the decision in the GeneXus/KB context and record the supporting evidence.
- Keep the execution context explicit: a Procedure that navigates a Transaction/base table with `For each` is not "via BC" unless it uses a `bc:<Transaction>` variable; enabling `idISBUSINESSCOMPONENT=True` matters for actual BC usage and for the 9-BC gate when such variables exist.

### Writability gate (attribute assignments)

- When the delta generates or reviews logic that assigns values to attributes accessed from a Transaction's base table, run the writability classification gate before any assignment is generated. Run `& ..\scripts\Test-GeneXusTransactionWritability.ps1 -TransactionPath <transaction.xml> -CorpusFolder <ObjetosDaKbEmXml> -AsJson` (facade over `GeneXusTransactionWritabilityCore.py`). The script returns a `levelAttributes` list where each item carries `classification` and `writable` (`true`, `false`, or `null` for edge cases). The 8 classifications cover the full algorithm: `key-attribute` (writable) for `key="True"` in the Level; `extended-parent-fk` (non-writable) for `isRedundant="True"` in the Level; `formula` (non-writable) for `Property Formula` in the Attribute XML; `extended-subtype-key` (writable) for SubTypeGroup member whose Supertype is PK in some Transaction; `extended-subtype-descriptive` (non-writable) for SubTypeGroup member whose Supertype is not PK in any Transaction; `extended-fk-key` (writable) when the attribute appears as Member in some Duplicate index of the Transaction's Table XML; `extended-fk-descriptive` (non-writable) when the attribute appears as `key="False"` of some FK entity reachable recursively from the Transaction's Table (max depth 10); `own-physical` (writable) when the attribute is absent from all FK entities in every explored depth. Edge cases return `unclassified-attribute-not-found` (Attribute XML standalone missing from corpus) or `unclassified-table-not-found` (Transaction's Table XML missing from corpus) — these require manual review against `08-guia-para-agente-gpt.md` before generating any assignment. Generating an assignment to an attribute the script reports as `writable=false` is a hard error — **ABORT**. Never conclude a Transaction's physical table has "only keys" before every `key="False"` attribute has been classified.
- When the delta involves `Rules` or `Events` blocks that generate attribute assignments, run the writability classification gate above before writing any assignment; do NOT generate assignments to non-writable attributes.

### Attribute serialization in packages

- For a new `Transaction` package, treat top-level `Attribute` items referenced by the `Level` as mandatory package members under `<Attributes>`, never as `Domain`/object payload under `<Objects>`.

### FK sustained by SubTypeGroup — Table review

- When a phase introduces a new FK sustained by `SubTypeGroup`, the structural review must not stop at the `Transaction` or at a pattern object linked to it.
- Also review the corresponding `Table`, focusing on `Transaction coupling and physical context` and `Secondary indexes and embedded index members`.
- If the new FK depends on later physical materialization or on an embedded index in the `Table`, treat `Transaction`, `SubTypeGroup`, and `Table` as the minimum review set for that phase.

### Evidence labels for Transaction catalogs (XPZ generation)

Canonical policy (Portuguese): [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md), subsection **Politica de evidencia para catalogos `Transaction` (geração XPZ)** under **Politica para `Transaction`**.

Every row in a consultable catalog here (`on <event>`, `Event` types, symptom→error) must carry **exactly one** label:

| Label | Meaning | Generation permission |
|-------|---------|-----------------------|
| `confirmado-import` | Rejection/acceptance observed on MSBuild import with traceable message and `exitCode` | Rejected syntax: do not generate. Accepted syntax: may generate after remaining gates |
| `confirmado-build` | Observed on `BuildAll`/`SpecifyGenerate` (e.g. `spc0150`) | Same |
| `confirmado-acervo` | Real use in parallel KB XML (`ObjetosDaKbEmXml/...` after sync) or reproducible sanitized template in `01*` | May generate, subject to writability and coherence gates |
| `padrao-gx-nao-verificado` | GeneXus convention/docs not tested in this base or parallel corpus in session | **Do not use as generation premise** — separate subsection only |
| `nao-listar` | No minimum evidence | **Do not publish** in the catalog |

Operational rules:

- **Generate only** syntax labeled `confirmado-import`, `confirmado-build`, or `confirmado-acervo`.
- Do not promote to `confirmado-*` from another agent’s report or an offline list alone; require reproducible import/build on the target KB, XML read in the parallel corpus, or a versioned sanitized template in this repo.
- Stable Specifier messages (e.g. `src0056`, `spc0150` with full text) may be documented under `confirmado-import` / `confirmado-build` without copying business `Transaction` XML into this repository.
- File-name examples (`Animal.xml`, etc.) with `confirmado-acervo` must state **parallel KB folder** (`ObjetosDaKbEmXml/...`) unless the example is a sanitized template in `01*`.
- Other skills must cross-reference this catalog section instead of duplicating it; see [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md) for repository scope (XPZ motor rejections vs GeneXus language documentation such as **nexa**).

## Catalog: `on <event>` clauses in declarative `Rules` and `Events` restrictions

Consult **before** generating or editing `Rules` or `Events` in a `Transaction` XPZ delta. This section records what the **XPZ import/build trail** has accepted or rejected — not correct GeneXus usage in general (**nexa** and product documentation own that).

### Catalog 1 — `on <event>` in declarative `Transaction` `Rules`

| Construct | Status | Specifier / motor evidence | Short example |
|-----------|--------|---------------------------|---------------|
| `on AfterValidate(<Attribute>)` or any `on <event>(<parameter>)` | **Rejected** | `confirmado-import` — `src0056: Missed ';' at the end of the rule. (Transaction '<name>' Rules, Line: <n>)` on MSBuild import (GeneXus 18) | `AttrB = expr if cond on AfterValidate(AttrA);` — **do not generate** |
| `on AfterValidate` (no parameters) | **Accepted** | `confirmado-acervo` — real use in parallel KB XML after sync (e.g. `Animal.xml`, `Carga.xml`, `PedidoCompraProdutoItem.xml` under `ObjetosDaKbEmXml/...`) | Level validation timing on commit path — **not** a per-field leave hook |
| `on BeforeInsert` | **Accepted** | `confirmado-import` on controlled trail; `confirmado-acervo` in parallel corpus | `Attr = expr on BeforeInsert;` |
| `on BeforeUpdate` | **Accepted** | `confirmado-import` on controlled trail (same frente as parameterized rejection) | `Attr = expr on BeforeUpdate;` |

#### GeneXus standard — not verified in this base (`padrao-gx-nao-verificado`)

Do **not** generate from this list without **confirmado-import**, **confirmado-build**, or **confirmado-acervo** on the target KB. Keep separate from the table above.

`on BeforeDelete`, `on AfterDelete`, `on BeforeValidate`, `on BeforeComplete`, `on AfterInsert`, `on AfterUpdate`, `on AfterComplete`, and other lifecycle triggers described in GeneXus product documentation or **nexa** (`common-rules.md` TRIGGERS, including `AfterLevel [level <attribute>]` for level-scoped timing — distinct from `on AfterValidate(<Attribute>)`).

### Catalog 2 — `Events` in `Transaction` (web scope unless noted)

| Construct / action | Status | Specifier / motor evidence | Notes |
|--------------------|--------|---------------------------|--------|
| `Event Start`, `Event After Trn` | **Listed** | `padrao-gx-nao-verificado` until `confirmado-acervo` in parallel corpus for your KB | Confirm in `ObjetosDaKbEmXml/...` before first use in a generated delta |
| `Event <Attribute>.ControlValueChanged` `[web]` | **Accepted pattern** | `confirmado-acervo` — parallel corpus examples adjust **control** surface (e.g. `.Caption`, `.Visible`, `.Enabled`), `SetFocus()`, not transaction attribute assignment | Do not copy as license to assign another attribute’s value |
| Assign to **transaction attribute** inside `Event` (`<Attribute> = <value>`) | **Rejected** | `confirmado-build` — `spc0150: Cannot update database. Changes to database are only allowed in procedures. (Transaction '<name>' Events, Line: <n>)` | Put persisted values in declarative `Rules`; use `Events` for UI, variables, `msg`/`Error`, external proc calls |
| Control UI properties, `&var`, `msg`/`Error`, proc `.execute()`, `SetFocus` / `SetEmpty` on variables | **Allowed class** | `confirmado-acervo` for UI-only `ControlValueChanged` bodies in parallel corpus | Still run **9-TXW** if any assignment touches level attributes in `Rules` |

`Event <Attribute>.IsValid` `[web]` stays `nao-listar` in this repository: there is no `confirmado-*` evidence here for Transaction Events. Verify in the target KB before generating; do not assume from commented XML alone.

Architectural note (XPZ scope only): persisting a new attribute value **via `Event`** is structurally blocked by the Specifier message above; attribute values belong in declarative `Rules` (and writability gates), with `Events` limited to non-persisted UI and side effects allowed by the motor.

### Catalog 3 — Symptom → likely cause → idiom (motor-focused)

| Symptom | Likely cause | Idiom |
|---------|--------------|--------|
| Import fails: `src0056` … `end of the rule` in `Transaction` `Rules` | Parameterized `on <event>(…)` (e.g. `on AfterValidate(<Attribute>)`) not accepted in declarative `Transaction` `Rules` on tested GX18 import | Remove the parameter; use only forms from Catalog 1; for per-field timing see **nexa** / product docs — do not reintroduce via `Event` attribute assignment |
| Build fails: `spc0150` … `only allowed in procedures` in `Transaction` `Events` | Transaction attribute assignment inside `Event` | Move value logic to declarative `Rules`; keep `Event` to UI / variables / proc calls (Catalog 2) |
| Import fails: `src0246` (`Call to non-defined object 'LoadWWPContext'` / `'<Trn>WW'`) / `src0294` (`Unknown function 'Call'`) in `Transaction` `Events` | A `GenerateObject=False` Transaction packaged still carrying WorkWithPlus (DVelop) screen code (`Call("LoadWWPContext")`, `Call("<Trn>WW")`): the Transaction's screen is not generated, so the WWP runtime it calls does not exist | For a structural-only Transaction, remove the WWP-generated `Events`/`Rules` and the `Apply:<wwp>` property, and do not carry the `WorkWithPlus*` PatternInstance/derivatives. Caught pre-packaging by `Test-GeneXusTransactionCoherence.ps1` (finding `wwp-screen-code-on-non-generated-transaction`, `confirmado-import` GX18U13 + WorkWithPlus_Web 16.0.3.1). Not the native Work With pattern (`Apply:78cecefe`), which is legitimate and not flagged |
| Import fails: `src0239` … `'Default' rule does not support a conditional expression` in `Transaction` `Rules` | A `Default(<Attr>, <expr>)` rule carrying a conditional clause (`… if <cond>;`); `Default` sets the **initial value when the attribute is empty** and does not accept a condition | Keep `Default(...)` **unconditional**; move the condition to a separate assignment rule (`<Attr> = <expr> if <cond>;`) — **not** a runtime equivalent (`Default` = initial-when-empty vs assignment = rule evaluation). Canonical entry `transaction-default-rule-with-conditional` in [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md). Distinct from the runtime **cascade shadowing** below (`src0239` is import rejection; the cascade is runtime shadowing with clean import/build) |
| Rule present in XML, import OK, field value on screen unchanged when another field changes | Mixing **business timing** with motor-blocked shortcuts | Do **not** “fix” with Catalog 1 rejected forms or Catalog 2 attribute assignment; diagnose evaluation path in target KB — correct GeneXus modeling is **not** duplicated here |
| `Find-CsAttributeAssignments.ps1` reports `tripletDetected=true` with `cascadeOrder` `override-then-default-then-fallback` or `override-then-fallback-then-default` | Effective order of generated `if/else if` assignment branches differs from the intended precedence | See **Cascade ordering: when `Default(X, ...)` shadows an assignment rule on the same attribute (in-XPZ quarantine)** below |

### Cascade ordering: when `Default(X, ...)` shadows an assignment rule on the same attribute (in-XPZ quarantine)

Named anti-pattern in the shared XPZ trail: `transaction-attribute-rule-shadowed-by-default-in-cascade` (canonical Portuguese entry in [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md)).

Observed symptom: the assignment rule exists in the `Transaction` XML, import/specification/build are operationally clean, but the attribute does not receive the rule value at runtime. In web editing, the usual symptom is a derived FK field staying empty after leaving the trigger attribute, or receiving the `Default(...)` value (often `0`) instead.

Generated-code shape: `Default(...)` and an assignment rule targeting the same attribute can become mutually exclusive `if`/`else if` branches in generated web `.cs` methods such as `OnLoadActions<KbId>`, `CheckExtendedTable<KbId>`, `Valid_<FKSide>`, and `GX<n>ASA<ATTR><KbId>`. Textual order in the XML controls branch order.

Diagnosis path: after import OK and generated `.cs` is available, first resolve the `.cs` path with `scripts/Resolve-GeneXusGeneratedCsPath.ps1` (or the local `Resolve-*KbGeneratedCsPath.ps1` wrapper) using `kb_environment_web_dirs` from `kb-source-metadata.md`. If the metadata does not cover the target environment, block and reconcile setup; do not infer by folder name or scan the native KB. Then run `scripts/Find-CsAttributeAssignments.ps1` with the resolved absolute `-CsPath`, `-Attribute`, and `-AsJson`. `tripletPattern.cascadeOrder=override-then-default-then-fallback` means the default branch is ahead of the fallback rule branch and can shadow it. `override-then-fallback-then-default` is the expected order after the textual reordering fix.

Correction path: if the approved fix is textual `Rules` reordering, edit only the front XML with `scripts/Edit-GeneXusXmlSurgical.ps1` using `-DryRun`, a literal anchor, `-ExpectedAnchorCount`, and `lastUpdate` baseline when available. Do not reserialize the whole `Transaction`. Re-import/build and re-read the generated `.cs` before closing.

Evidence labels: `confirmado-acervo` in the XPZ trail (`VendaPedido` in a parallel KB after sync) plus `confirmado-build` by reproducible before/after inspection of generated `.cs`.

Scope note: this is naturally GeneXus modeling knowledge and belongs in product documentation or a skill such as **nexa**. It is documented here because the operational diagnosis uses this repository's `Find-CsAttributeAssignments.ps1`, the approved correction is applied to XML in a parallel KB through XPZ helpers, and **nexa** is not practically contributable from this repository. If **nexa** or an equivalent product skill becomes contributable, this entry is a migration candidate. Do not generalize this quarantine to unrelated GeneXus semantic topics without the same diagnosis-plus-correction link inside XPZ scope.

### Generated `.cs` map: where a Transaction assignment rule lives (in-XPZ quarantine)

This map is the canonical interpretation aid for `methods[].name` emitted by `scripts/Find-CsAttributeAssignments.ps1` when inspecting generated web `.cs` for a `Transaction` assignment rule. It is not a general map of GeneXus runtime semantics; it documents mechanical artifacts observed in generated code because the XPZ diagnostic tool reports these exact method names.

Evidence labels for this map: the four-method shape is `confirmado-acervo` in the XPZ trail (`VendaPedido` in a parallel KB after sync) and `confirmado-build` by reproducible inspection of `vendapedido.cs` before/after the `Rules` textual reordering fix. Negative variations such as "no prompt handler when the attribute has no prompt control" remain `padrao-gx-nao-verificado` here unless a separate Transaction in the local corpus confirms them.

- `OnLoadActions<KbId>`: single generated method per `Transaction`, with `<KbId>` as the generator suffix inserted for the KB (for example `0J44` in the observed case). Runtime scenario: initial form load, light FK refresh, and server-side updates requested by the browser when it asks for partial screen-state refresh. JS trigger: generic AJAX refresh; it can also be reached inside other server calls and does not have a dedicated `LOAD` event name in the observed JS metadata. `AssignAttri` near the assignment is typically present, which lets the calculated value travel back to the browser in the JSON response. Diagnostic role: this is the path where the rule has a chance during light refresh after field-out of a valid FK, a scenario where the browser did not call `Valid_<FKSide>`.

- `CheckExtendedTable<KbId>`: single generated method per `Transaction`. Runtime scenario: heavier validation during Confirm/Save. JS trigger: form submit, usually the `Confirmar` / `btn_enter` flow. `AssignAttri` near the assignment is typically present. Diagnostic role: this explains why a rule can still work at Confirm time even when a light refresh path did not update the browser; the Confirm path runs independently from the light-refresh conditions.

- `Valid_<FKSide>`: generated per validatable FK-side attribute, for example `Valid_Vendapedidoclienteid` when the FK side is `VendaPedidoClienteId`. Runtime scenario: FK validation when the browser decides to call it. In the observed GeneXus 18 web flow, JS called `VALID_<FK>` only when the FK was detected as invalid for error display; when the FK was valid, JS performed a light refresh that reached `OnLoadActions<KbId>` and did not call `Valid_<FKSide>`. JS trigger: AJAX event `VALID_<FK>` in `setEventMetadata`, visible in the payload as `events: ["VALID_<FK>"]`. `AssignAttri` near the assignment can be present or absent. When it is absent, the value can be calculated server-side but not marked as modified for the JSON response, so the browser may keep the old value. Diagnostic role: if the rule depends on this method and JS does not invoke it, the rule can be operationally orphaned; this complements the named anti-pattern `transaction-attribute-rule-shadowed-by-default-in-cascade`.

- `GX<n>ASA<ATTR><KbId>`: generated AJAX handler for the prompt-aggregator-selector of the attribute named by `<ATTR>`, for example `GX100ASAVENDAPEDIDOVENDEDORID0J44`. Runtime scenario: the user interacts with the FK prompt control (opens the prompt, selects a value, closes the popup). JS trigger: AJAX call whose `gxfirstwebparm` matches `gxajaxAggSel<n>_<ATTR>`, for example `gxajaxAggSel100_VENDAPEDIDOVENDEDORID`. `AssignAttri` near the assignment is typically present. Diagnostic role: this handler is expected only for attributes with an associated prompt control; no prompt control means no handler in the current evidence model (`padrao-gx-nao-verificado` unless confirmed in the target corpus).

How to use the map: resolve the Transaction `.cs` path first with `scripts/Resolve-GeneXusGeneratedCsPath.ps1` (or local wrapper) from `kb_environment_web_dirs`; use the returned `csPath` as the absolute `-CsPath` for `scripts/Find-CsAttributeAssignments.ps1` with `-Attribute` and `-AsJson`, then cross each `methods[i].name` with the patterns above. The script reports literal generated method names; it normalizes the attribute lookup, not the method name.

Cross-reference: this map answers **where** a rule assignment lives in generated web `.cs`. The previous section, **Cascade ordering: when `Default(X, ...)` shadows an assignment rule on the same attribute (in-XPZ quarantine)**, answers **why** a rule can stay inert even when it is present in these methods: internal `if`/`else if` ordering can shadow the assignment. A rule can be present in all four methods and still be hidden at runtime if that cascade order is wrong; see the canonical Portuguese anti-pattern `transaction-attribute-rule-shadowed-by-default-in-cascade` in [02-regras-operacionais-e-runtime.md](../../02-regras-operacionais-e-runtime.md).

## Quality Checklist

- [ ] For `Transaction`, every `Level/Attribute@guid` exists in `<Attributes>/Attribute@guid`
- [ ] For `Transaction`, every `Level/Attribute` name exists in `<Attributes>/Attribute@name`
- [ ] For `Transaction`, every `DescriptionAttribute` present exists in the same `Level` and also in `<Attributes>`
- [ ] For `Transaction`, no required `Attribute` was serialized as `Domain` or other object type under `<Objects>`
- [ ] For `Transaction`, the primary edit block was declared before editing, any block transition was justified explicitly, and intended scope via web editing vs BC was stated when relevant
- [ ] When the delta involves `Rules` or `Events` with attribute assignments, writability was closed with `Test-GeneXusTransactionWritability.ps1` for each affected Transaction **or** with `Test-GeneXusKbIntelligenceWritabilityParity.ps1` already passed on that parallel KB folder (index `schema_version>=2`); `transaction-writable-attributes` may have been used for triage only — it does not replace that closure; any `writable=false` attribute was excluded from assignments (or the assignment caused an explicit ABORT); any `writable=null` (`unclassified-*`) was either resolved or explicitly documented as a classification gap before packaging
- [ ] If the phase introduced a new FK sustained by `SubTypeGroup`, the corresponding `Table` was reviewed and the `Transaction + SubTypeGroup + Table` minimum review set was honored
- [ ] When `Find-CsAttributeAssignments.ps1` drove a `Rules` reordering fix, the resolved `.cs` path source (`Resolve-GeneXusGeneratedCsPath.ps1` or local wrapper), report path, attribute, `tripletPattern.cascadeOrder`, surgical edit anchor and post-build `.cs` recheck were recorded; no conclusion was extended from web editing to BC without separate evidence
- [ ] Any new or updated catalog row in this file uses exactly one evidence label (`confirmado-import`, `confirmado-build`, `confirmado-acervo`, `padrao-gx-nao-verificado`); nothing was promoted to `confirmado-*` without import/build, parallel corpus XML, or sanitized template evidence
- [ ] `padrao-gx-nao-verificado` items, if any, live in a clearly titled subsection separate from confirmed rows; no syntax was generated from unverified items alone
- [ ] Before editing `Rules` or `Events`, the agent consulted **Catalog: `on <event>` clauses…** above and did not generate Catalog 1 rejected forms or Catalog 2 attribute assignments in `Events`
- [ ] If the Transaction has `GenerateObject=False` (structure/BC only), it does not carry WorkWithPlus (DVelop) screen baggage — no `Call("LoadWWPContext")`/`Call("<Trn>WW")` in `Events`/`Rules`, no `Apply:<wwp-guid>` property, no `WorkWithPlus*` PatternInstance/derivatives in the package; closed with `Test-GeneXusTransactionCoherence.ps1` (finding `wwp-screen-code-on-non-generated-transaction`). The native Work With (`Apply:78cecefe`) is not in scope of this check

## Related gates and WORKFLOW links

Type-agnostic gates and WORKFLOW steps that involve Transactions remain in the main `SKILL.md`. Cross-references:

- **9-BC (BC dependency preflight gate)** — `Test-GeneXusBCDependency.ps1`. Triggered when a Procedure in the batch references `bc:<Transaction>` or `bc:<Transaction>.<Sublevel>`.
- **9-IDO (Import Dependency Ordering)** — `Test-GeneXusBatchDependencyOrdering.ps1`. Triggered when the batch has 2 or more distinct objects.
- **9-TXW (Transaction Writability gate)** — `Test-GeneXusTransactionWritability.ps1`, or `Test-GeneXusKbIntelligenceWritabilityParity.ps1` when index parity is already validated on the parallel KB folder. Triggered when the delta involves `Rules` or `Events` with attribute assignments. See WORKFLOW step `9-TXW`.
- **Transaction Coherence pre-packaging gate** — `Test-GeneXusTransactionCoherence.ps1`. See WORKFLOW step `9-TWS`. Also flags `wwp-screen-code-on-non-generated-transaction` (`fail`): a `GenerateObject=False` Transaction carrying orphan WorkWithPlus (DVelop) screen calls (`Call("LoadWWPContext")`/`Call("<Trn>WW")`) in `Events`/`Rules` — see Catalog 3 and `xpz-builder/wwp-packaging.md`. The native Work With pattern (`Apply:78cecefe`) is explicitly out of scope.
- **Transaction semantic pre-import gate** (Level/Attribute@guid, DescriptionAttribute coherence). See WORKFLOW step in the validation block of the main `SKILL.md`.
- **Package envelope rules and Attribute serialization rules**. See WORKFLOW steps 15 onward in the main `SKILL.md`.
