# API — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `API` object type. **Load this file end-to-end before generating, editing, or packaging an `API`**, in addition to the main `SKILL.md`.

## Responsibilities

### Block classification and edit scope

- Classify the current delta by functional block before editing: `Service contract`, `Events and orchestration`, `Calls and dependencies`, `Data contract`, or `Identity and container`.

### Security level annotation (GAM) — bridge to nexa

- The security level is set by the `[SecurityLevel(<mode>)]` annotation on each service. **Valid modes (parser-verified, GeneXus 18 / KMW 4.0.187794 + GAM 3.15.78): `None`, `Authentication`, `Authorization`.** The short form `Authorize` is **REJECTED** by the parser (`mismatched input 'Authorize' expecting {ModeNone, ModeAuthorization, ModeAuthentication}`); do NOT use it, even though nexa `object-api.md` (SecurityLevel annotation section) lists `Authorize` — that reference is wrong; the object-property enum (`properties-common-integrated-security.md`) and the generated grammar use `Authorization`.
- C# mapping (dated, same version): `None → GAMSecurityLevel.SecurityNone`, `Authentication → SecurityLow`, `Authorization → SecurityHigh`.
- For the GAM concept itself (levels, permissions), reference nexa `object-api.md` and `properties-common-integrated-security.md`; do NOT duplicate. Runtime GAM configuration (enabling authorization, roles, permission binding) is a **precondition documented in [api-gam-runtime.md](api-gam-runtime.md)**, out of XPZ automation scope — an API generated as `SecurityHigh` is NOT proven secure until that precondition is met (see satellite).

### `[SecurityPermission]` ↔ generated `*_Services_*` permission (conditional)

- `[SecurityPermission("<name>")]` is optional. When present, its literal must match a generated `<apiname>_Services_*` permission; check this statically. When absent (the common case), the API relies on `[SecurityLevel]` alone and the check does not apply.

### Dependency resolution and import order (real import validates references)

- An `API` service delegates to an implementation object (`=> Proc(...)`). **The real import validates this reference**: it FAILS (`Object Reference <name> not found`) when the implementation Procedure is absent from BOTH the import batch AND the target KB. GeneXus resolves the reference intra-batch (API + its Procedure in the same package → OK) or against the pre-existing KB (staging).
- **Rule:** package the `API` together with its implementation Procedure(s), OR stage the Procedure(s) into the KB before the API. NEVER import an `API` whose implementation Procedure is absent from both. The batch dependency-ordering gate (`Test-GeneXusBatchDependencyOrdering.ps1`, 9-IDO) does NOT model the `API → Procedure` edge (it only derives edges from `Procedure` objects); this is safe because the import itself resolves the reference — but it means the gate gives no ordering signal for API chains, so the packaging/staging rule above is the operative safeguard.

### Preview is not API validation

- The import **preview** reports `importTaskSuccess: true` even for an API the **real import rejects** (invalid `[SecurityLevel]` value, missing implementation reference). Preview parses but does NOT run the API grammar/reference validation. **Validate a from-spec `API` by REAL import, never by preview.**

### OpenAPI is not security evidence

- The generated OpenAPI shows `oAuthGXGAM` even when the API is `SecurityLevel(None)`. Do NOT use OpenAPI as proof of enforcement; the reliable evidence is the generated C# (`GAMSecurityLevel.*`) plus a real HTTP smoke (see satellite). Authorization-via-event (`If NOT IsRegisteredUser → 403`, nexa Example 3) is a **non-canonical 4th mode**, outside the standard GAM path — do not conflate it with `[SecurityLevel]` enforcement.

## Quality Checklist

- [ ] For `API`, the primary edit block was declared before editing and any block transition was justified explicitly
- [ ] For `API`, contract deltas were reviewed explicitly against the published operation and the effective orchestration before packaging
- [ ] For `API`, `[SecurityLevel]` uses only `None`/`Authentication`/`Authorization` (never `Authorize`)
- [ ] For `API` with write operations, `SecurityLevel(None)` is NOT the final state; the GAM runtime precondition in `api-gam-runtime.md` was satisfied and the 2-phase smoke passed
- [ ] For `API`, the implementation Procedure(s) are in the same package or already in the KB (real-import reference resolution)
- [ ] For `API`, validation used a REAL import (not preview) and enforcement was checked by C# + HTTP smoke (not OpenAPI)

## Related rules in main SKILL.md WORKFLOW

The following API-specific rules live inside WORKFLOW step 11 (Locate template, Apply conservative cloning). They remain in the main `SKILL.md`:

- Declare the primary edit block before touching the XML and use only the adjacent blocks required by explicit functional dependency.
- Treat `Service contract` and `Data contract` as their own functional layers; do NOT collapse endpoint contract, response shape, and internal orchestration into a generic code reading.
- If the delta touches exposed method, endpoint, signature, published operation, input/output shape, or response structure, classify `Service contract` or `Data contract` as the primary edit block unless explicit evidence points elsewhere.
- If the delta depends on `.Before/.After`, internal validation, transformation, or orchestration flow, open `Events and orchestration` only as an explicitly justified adjacent block.
- Do NOT treat `Procedure`, `SDT`, `Domain`, `Transaction`, `EXO`, or `DataProvider` dependency inventory by itself as proof of the published contract.
- Name each justified block transition during review (`Service contract -> Data contract` or `Events and orchestration -> Calls and dependencies`).
- If the current reasoning no longer needs a new block, stop expanding; do NOT reopen the whole object by reflex.

## Related references

- [api-gam-runtime.md](api-gam-runtime.md) — GAM runtime precondition (Face 2) and the 2-phase enforcement smoke; blocks an unwarranted "secure" conclusion.
- nexa `object-api.md` and `properties-common-integrated-security.md` — API syntax and integrated-security levels (layer 1). Reference, do not duplicate. Note: nexa `object-api.md` lists `Authorize` for the annotation, which is a documentation bug — use `Authorization`.
- [01e-moldes-sanitizados-core.md](../../01e-moldes-sanitizados-core.md) — sanitized API molds: the dense `APIExemploIntegracao` and the minimal self-contained triad (API + implementation Procedure + a single response SDT; the request is a path parameter plus a body-enveloped payload — a consumption contract documented in `api-gam-runtime.md`, not a separate request SDT in this minimal mold).
- `historico/IdeiasImplementadas_202607.md` — implemented-idea entry «Criar/alterar objeto GeneXus do tipo `API` (from-spec, com segurança GAM)» with its «Resultados da Fase 0 empírica» block (empirical evidence, dated KMW 4.0.187794 + GAM 3.15.78); the `999-ideias-pendentes.md` entry migrated here on close, leaving only the future scripted-gate item in `999`.
