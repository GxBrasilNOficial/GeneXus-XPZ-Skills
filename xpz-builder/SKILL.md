---
name: xpz-builder
description: Generates and clones GeneXus XPZ objects conservatively — validates structure, applies risk rules, serializes envelope
---

# xpz-builder

Generates GeneXus XML objects for XPZ packaging using conservative cloning from empirical templates. Applies risk rules, validates structure, and serializes the correct XPZ envelope. Does not affirm import or build success — that requires external IDE validation.

---

## GUIDELINE

Generate or clone GeneXus XPZ objects only from comparable structural templates. Abort when a suitable template does not exist. Never invent structure.

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

---

## RESPONSIBILITIES

- Identify the target object type and locate the most comparable structural template
- Apply risk assessment from [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md) before proceeding
- Abort if no comparable structural template exists and risk is high or very high
- Clone conservatively: preserve `Object/@guid`, `parent*`, `moduleGuid`, all recurring Part types
- Apply XPZ envelope rules from [02-regras-operacionais-e-runtime](../02-regras-operacionais-e-runtime.md)
- Generate valid `lastUpdate` timestamp (real local time, not placeholder)
- Ensure all GUIDs are syntactically valid (no text placeholders like `"YOUR-GUID-HERE"`)
- Validate XML structure before delivery
- Declare confidence level and limitations explicitly at the end of every output

---

## COMMUNICATION

- Respond in the same language the user writes in
- Lead with the decision (proceed / abort) and the reason
- State which template was used and why it was selected
- Always end output with a limitations block: what was followed, what requires external validation
- Use NEVER and ABORT as hard stops, not suggestions
- NEVER use speculative or reassuring language about import/build success

---

## STRUCTURE

Reference files and when to load them:

| Reference | Load when |
|-----------|-----------|
| [00-readme-genexus-xpz-xml.md](../00-readme-genexus-xpz-xml.md) | Always — absolute rules and envelope structure |
| [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md) | Always — envelope serialization, timestamp, GUID, ObjectsIdentityMapping rules |
| [03-risco-e-decisao-por-tipo.md](../03-risco-e-decisao-por-tipo.md) | Always — risk level and abort conditions |
| [04-webpanel-familias-e-templates.md](../04-webpanel-familias-e-templates.md) | Target is a WebPanel object |
| [05-transaction-familias-e-templates.md](../05-transaction-familias-e-templates.md) | Target is a Transaction object |
| [07-open-points-e-checklist.md](../07-open-points-e-checklist.md) | Edge cases, provisional decisions, or checklist for new templates |
| [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md) | Decision formula, precedence rules, materialization rules, refuse conditions |

---

## WORKFLOW

1. Identify the target object type and the user's intent (create new / clone existing / rename)
2. Load [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md) → assign risk level
3. Evaluate abort conditions:
   - Risk is high/very high AND no comparable internal template exists → **ABORT**
   - Type is not in the empirical corpus → **ABORT**
   - User requests affirmation of import/build success → **REFUSE**, state limitation
4. Locate template:
   - Transaction → use family F1–F6 from [05-transaction-familias-e-templates](../05-transaction-familias-e-templates.md)
   - WebPanel → use closest family from [04-webpanel-familias-e-templates](../04-webpanel-familias-e-templates.md)
   - Other types → use sanitized representative from [08-guia-para-agente-gpt](../08-guia-para-agente-gpt.md) materialization rules
5. Apply conservative cloning:
   - Preserve `Object/@guid` (new GUID only for new objects, never reuse existing object's GUID)
   - Preserve `parent`, `parentGuid`, `parentType`, `moduleGuid`
   - Keep all recurring Part types present, even if content is empty
   - Do NOT invent Part types not present in the template
6. Apply envelope rules from [02-regras-operacionais-e-runtime](../02-regras-operacionais-e-runtime.md):
   - Wrap in `<ExportFile>` with `<KMW>`, `<Source>`, `<Objects>`, `<Dependencies>`
   - Keep `Source/@kb` and `Source/Version/@guid` in valid GUID format
   - Do NOT include special KB block unless explicitly documented as required
7. Set `lastUpdate` to real local timestamp
8. Validate:
   - XML is well-formed
   - All recurring Part types present
   - No text placeholder GUIDs remaining
   - Template and target share the same structural family
9. Deliver XML with limitations block:
   - Which template was used
   - Confidence level
   - What requires external IDE validation (import, build, runtime)

---

## QUALITY CHECKLIST

- [ ] Risk level assessed before proceeding
- [ ] Abort condition evaluated explicitly
- [ ] Template selected from empirical corpus (not reconstructed from descriptions)
- [ ] `Object/@guid` valid and appropriate (preserved or newly generated)
- [ ] `parent*` and `moduleGuid` preserved from template or context
- [ ] All recurring Part types present (even if empty)
- [ ] No invented Part type GUIDs
- [ ] Envelope complete: `<ExportFile>`, `<KMW>`, `<Source>`, `<Objects>`, `<Dependencies>`
- [ ] `lastUpdate` is a real timestamp, not a placeholder
- [ ] `Source/@kb` and `Source/Version/@guid` are valid GUIDs
- [ ] Limitations block included in output

---

## CONSTRAINTS

- NEVER invent a Part type GUID not present in the selected template
- NEVER affirm import or build success — state "requires external IDE validation"
- NEVER generate from a text description or markdown summary alone — requires comparable raw XML template
- NEVER generate special KB block (`KnowledgeBase`, `Settings`) for normal single-object XPZ
- ABORT if risk is high/very high and no internal comparable template is available
- ABORT if type has fewer than 5 specimens in the corpus and no sanitized template exists
- Absolute rules in [00-readme-genexus-xpz-xml.md](../00-readme-genexus-xpz-xml.md) and [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md) take precedence over all other heuristics
