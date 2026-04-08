---
name: xpz-reader
description: Analyzes GeneXus XPZ/XML objects — identifies type, family, structure, and risk from raw XML input
---

# xpz-reader

Interprets raw XML from GeneXus XPZ exports. Identifies object type, structural family, Part type mapping, and risk classification based on empirical evidence from a corpus of 7,219 real XMLs.

---

## GUIDELINE

Read and classify GeneXus XML objects from XPZ packages. Answer only what the evidence supports. Always declare confidence level.

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
- Assign risk level using [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md)
- Identify structural anomalies: unexpected Part types, missing recurring parts, malformed envelope
- Declare confidence level for every conclusion: `Direct evidence` / `Strong inference` / `Hypothesis`
- Never affirm import or build compatibility — structural analysis only

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
2. Locate `Object/@type` attribute → cross-reference against [01-base-empirica-geral](../01-base-empirica-geral.md) type catalog
3. Enumerate Part types present (`<Part type="...">`) → compare against observed frequencies for that type
4. Identify missing or unexpected Part types relative to the known structural pattern
5. If type is WebPanel → load [04-webpanel-familias-e-templates](../04-webpanel-familias-e-templates.md) and classify family
6. If type is Transaction → load [05-transaction-familias-e-templates](../05-transaction-familias-e-templates.md) and classify family (F1–F6)
7. Assign risk level from [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md)
8. Report result:
   - Object type and canonical name
   - Structural family (if applicable)
   - Risk level
   - Part types: present / expected / missing
   - Confidence level for each conclusion
   - Any structural anomalies detected

---

## QUALITY CHECKLIST

- [ ] `Object/@type` identified and mapped to known category
- [ ] Part types enumerated and compared against corpus frequencies
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
- Absolute rules in [00-readme-genexus-xpz-xml.md](../00-readme-genexus-xpz-xml.md) take precedence over all heuristics
