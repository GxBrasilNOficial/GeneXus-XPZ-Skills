# Procedure — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `Procedure` object type (including simple report Procedures). **Load this file end-to-end before generating, editing, or packaging a `Procedure`**, in addition to the main `SKILL.md`.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `Source`, `Rules/parm`, `Variables`, `Calls and dependencies`, `Identity and container`, and `Report layout` when applicable.

### Simple report Procedure — sanitized canonical template

- Prefer the documented sanitized canonical template first; use it as a materialization source only when the selected block in [05b-procedure-relatorio-familias-e-templates](../../05b-procedure-relatorio-familias-e-templates.md) is marked as `molde pronto`. Escalate to KB corpus only when the methodological base does not cover the case, when the initial attempt plus one short structural corrective attempt fail, or when KB-local dialect/localism appears.

### Minimum semantic pre-packaging gate

When changing a `Procedure`, run a minimum semantic pre-packaging gate on the `Procedure` itself:

- declare the primary edit block before touching the XML
- For `Source` inside `CDATA`, follow **Edição cirúrgica de XML e limitações da ferramenta Edit do harness** in the main `SKILL.md`: prefer raw/script patch over harness Edit; ABORT when the saved diff shows changes outside the declared `Source` block.
- use only the adjacent blocks required by explicit functional dependency
- name each justified block transition during review, for example `Rules/parm -> Variables` or `Source -> Calls and dependencies`
- if the current reasoning no longer needs a new block, stop expanding; do NOT reopen the whole object by reflex
- distinguish `well-formed XML` from `minimum Source sanity gate passed`
- if the object depends on `Source`, do not package while the `Source` gate is still unresolved
- review structural pair balance touched by the delta, such as `Sub/EndSub`, `For each/EndFor`, `Do Case/EndCase`, and `If/EndIf`
- treat `elseif`, `iif(...)`, newly dense conditions, and calls inside conditions that diverge from the object's dominant local style as conservative warnings to rewrite when the form is not methodologically anchored
- if `parm(...)` changed, every new parm variable must exist in the variables section of the object
- if `parm(...)` changed, variable name, base type, and presence must remain coherent
- if the current `Source` delta inserts a new `Case` inside a `Do Case` that depends materially on `parm(...)`, compare the new branch against adjacent sibling `Case` branches in the same block before accepting the delta
- in that `Do Case` review, verify that relevant input parms expected by the local pattern are actually used in the new branch; if a comparably expected parm is not used, require an explicit justification before concluding the delta
- if the new `Case` diverges from the local pattern of sibling branches without explicit justification, block the delta instead of accepting a hardcoded or weakly analogous branch
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

### Procedure returning an SDT collection

- When a `Procedure` returns a list as `parm(out:&<Collection>)`, verify the `Rules/parm` and `Variables` blocks together: the output variable must exist, use `ATTCUSTOMTYPE=sdt:<ItemSdt>`, and carry `AttCollection=True`; the item/helper variable should use the same `ATTCUSTOMTYPE` without `AttCollection=True` unless a nested collection shape is explicitly intended.
- If the `Source` builds the collection with `For each <Transaction>` over a real Transaction/base table, describe the mechanism as `For each` navigation over that Transaction/base table. Do not describe it as "via BC" unless the Procedure declares and uses a variable with `ATTCUSTOMTYPE=bc:<Transaction>`.
- For every attribute copied from the `For each` navigation into the response SDT, confirm that the attribute exists in the target KB/corpus and that the SDT item shape matches the published API data contract.

### Collection operations, Sub control flow, and parameter hygiene

- **Collection sorting**: `.Sort()` on GeneXus collections supports both ascending and descending criteria (ref: skill `nexa`, `references/common-collections.md` and production usage in `FabricaBrasil18`):
  - `&Col.Sort()` or `&Col.Sort("")`: ascending order (default);
  - `&Numbers.Sort("()")`: descending order for collections of basic/scalar types;
  - `&Products.Sort("Member1, Member2")`: ascending order by multiple SDT members;
  - `&Products.Sort("Member1, (Member2)")`: mixed order on SDT collections, where parentheses `(MemberName)` specify descending sort for that specific member (e.g. `&lista.Sort("ItemId, (DataDeEntrada)")`).
  - Iterating backwards with `&i = &Col.Count`, `Do While &i >= 1 ... &i -= 1`, `.Item(&i)` (1-based index) remains a valid pattern for reverse traversal, but is not required as a workaround for sorting.
- **Collection count**: `.Count` is an unsigned property without parentheses (e.g. `&Col.Count`), not a method call.
- **Control flow in `Sub`**: calling `Return` inside a sub-routine (`Sub ... EndSub`) in a Procedure was avoided in practice as an operational precaution to ensure predictable control flow; structure sub-routines with explicit `If` blocks around the body rather than early returns. Do not use `Exit` as a substitute for exiting a sub-routine (`Exit` exits the innermost `For`/`Do While` loop, not the `Sub`).
- **Parameter hygiene**: reassigning a variable declared as `in` in `parm(in:...)` works technically, but masks the source of the input value; as a style and clarity convention, assign to and manipulate a dedicated local variable instead.

### Type-specific gate triggers

- **BC dependency preflight gate (9-BC)**: when the candidate batch contains a `Procedure` that declares a variable with `ATTCUSTOMTYPE = bc:<X>`, run `& ..\scripts\Test-GeneXusBCDependency.ps1` before packaging. The script locates Transaction `X` in the batch or in `ObjetosDaKbEmXml`, verifies `idISBUSINESSCOMPONENT=True`, and supports `bc:Pai.Filho` sublevel references. Treat absence of confirmation as a hard blocker (fail). A `Procedure` that only navigates a Transaction/base table with `For each` does not trigger 9-BC unless it also declares a `bc:<X>` variable.
- **Procedure New Writability gate (9-PNW)**: when the candidate batch contains a `Procedure` whose `Source` has `New`, run `& ..\scripts\Test-GeneXusNewWritableTargets.ps1` before packaging (facade over `GeneXusTransactionWritabilityCore.py` for classification; PowerShell retains `New` block parsing and target resolution). The script checks direct left-side assignments inside each `New` against Transaction writability classification. Treat assignment to `formula`, descriptive/extended, subtype-derived descriptive, unclassified, or unresolved-base attributes as a hard blocker (fail); do not confuse readable attributes with attributes physically assignable in the `New` target.
- **Sub-pattern Mirroring gate (9-PSM)**: when the candidate batch contains a `Procedure` whose `Source` delta introduces or materially expands a `Sub` block, run `& ..\scripts\Test-GeneXusProcedureSubPattern.ps1`. The script scans the procedure's pre-existing `Sub` delegation structure; if a dominant `iteration-sub → unit-sub` pattern exists and the new block is `mixed`, the script emits an `alert` finding. Treat as advisory, not as a hard packaging blocker — require user acknowledgment or restructuring.

## Quality Checklist

- [ ] For `Procedure`, the primary edit block was declared before editing and any block transition was justified explicitly
- [ ] If `Procedure` `Source` contains `New`, `Test-GeneXusNewWritableTargets.ps1` was run and no `fail` finding remained before packaging
- [ ] If `Procedure` returns an SDT collection, the `parm(out:...)`, collection variable, item/helper variable, and response SDT item shape were reviewed as one data contract; 9-BC was required only when a `bc:<Transaction>` variable exists

## Related rules in main SKILL.md WORKFLOW

The following Procedure-specific rules live inside WORKFLOW steps (Validate). They remain in the main `SKILL.md`:

- For report `Procedure`, WORKFLOW step 17 (Validate) covers: classify each edited fragment as `Source`/`Rules`/layout; verify coherence between layout `PrintBlock` names and `print printBlock...` references in `Source`; require matching `PrintBlock` with coherent `RPT_INTERNAL_NAME`; verify unique `RPT_INTERNAL_NAME` across siblings; treat total layout width as structural constant inherited from template; on import error pointing to invalid control/report block/layout, inspect layout first.

## Related references

- [05b-procedure-relatorio-familias-e-templates.md](../../05b-procedure-relatorio-familias-e-templates.md) — Procedure-report families F2/F3 (used when target is a simple report Procedure).
- [08-guia-para-agente-gpt.md](../../08-guia-para-agente-gpt.md) — resource ladder and materialization rules.
