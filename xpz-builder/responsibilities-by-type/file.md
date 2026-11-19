# File — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for `File` objects. **Load it before generating, editing, or packaging a `File`**, in addition to the main `SKILL.md`.

The satellite has two parts: a **generic** part (any `File` payload) and an **`.xlsx`** part that applies only when the `File` carries a spreadsheet used as an `ExcelDocument` template. Read the generic part always; read the `.xlsx` part when the batch contains a `File` with `.xlsx`, or a `Procedure` whose `Source` uses `ExcelDocument` with a `Template` (the template `File` can then be read from the acervo for the checks; if the `File` is not in the batch/package, it is an unchanged dependency and there is no front×package body to compare).

## Generic: identity, payload, and extraction

- Body: `Part[@type='9b6155f9-f286-4ed5-bd15-67672e8ea320']/Data/base64Binary`. In the observed corpus there is exactly one such node; if more than one, stop and investigate. Identify the `File` by `Object/@guid`/`@name`, not by the Base64 node.
- Data-part properties: `FileName`, `FileExtension`, `IsDefault`. Object properties: `Name`, `Description`, `NetExtract`, `NetExtractFolder`, `NetCoreExtract`, `NetCoreExtractFolder`, `IsDefault`.
- The `base64Binary` body is the source of truth; the extracted copy in the environment is a deployment artifact. Importing a `File` does not update the served copy; build/deploy does. Follow `xpz-msbuild-build` for the applicable phase.
- Preserve the body byte-for-byte outside the approved delta. Do not reserialize; patch the Base64 surgically (main `SKILL.md`) and re-read the final body.
- Molds: `01h` has three sanitized `File` molds — `ArquivoImagemExemplo_gif` (small binary), `ArquivoConfiguracaoExemplo_props` (small text), and `ArquivoModeloPlanilhaExemplo_xlsx` (spreadsheet template). They are structural references; do **not** clone the `.gif`/`.props` body for an `.xlsx` template. The `.xlsx` mold is a small generic workbook, a starting point, not a full report layout.
- `07-open-points-e-checklist.md:153` (an additional `File` template with a small binary and a textual/config file) remains open; the `.xlsx` profile is covered by the mold above, not by that open point.

## `.xlsx` used as an `ExcelDocument` template

Applies when the `File` carries an `.xlsx` used by a `Procedure` via `ExcelDocument`. The template is the only place where number formats live (`ExcelDocument` does not expose `NumberFormat`).

### Column/type contract (with the Procedure)

- List the writes by type — `Cells(row, FirstColumn + N).Date | Number | Text` (and `.Bold`) — and map `N` to the column letter. `N=0 → A` is a premise to anchor from the `Source`/API; if the column index or the written type is dynamic/conditional and cannot be resolved, mark the column **inconclusive**.
- Classify by **(column, band)**: header, detail, subtotal, total. A column can hold a date in one band and a number in another.
- If `FirstColumn` is not anchored, treat the whole map as inconclusive until a `Source`/API anchor exists.

### Effective number-format resolution (consumer-specific, simplified)

The goal is the **number format applied to the cells the writer will fill**, not a full OOXML style audit. When any of these is not resolvable for a column, mark it **inconclusive**:

1. Cell `s` defaults to `0` → `cellXfs[0]`. For a cell with `s`, read `cellXfs[s]`; the format is the `numFmtId` **only when `applyNumberFormat` is not 0**. If `applyNumberFormat=0`, the format is inherited and the resolution is inconclusive for that cell.
2. Cells **absent** from `sheetData` (beyond the template's rows) inherit from `<col style>` and row defaults; this is the boundary region and a case of its own.
3. `cellStyleXfs`/`xfId`, `conditionalFormatting`/`dxf`, and table styles are **out of scope**; when present and relevant to the column, mark inconclusive.
4. Row (`row/@s` with `customFormat="1"`) versus column precedence is implementation-specific; do not assert it without local evidence.
5. `xf 0` is the default cell format. A **custom** `xf` with `numFmtId 0` is not proven equivalent to the default; for a mixed column treat it as **inconclusive**.

### Judgment (storage and display are separate)

- The value is always a serial/number (or a string); the number format only changes the **display**. Validate the underlying value **and** the displayed mask, not the mask alone.
- **mixed** (date + number in the same column) + **default** → observed to work in this consumer; for another generator/runtime, verify the output. mixed + custom "General" (`numFmtId != 0`, code `General`) or a fixed date format on the whole column → **finding**.
- **date-only** + date format → ok; date-only + custom "General" → finding.
- **number-only** + number/default → ok; number-only + date format → finding.
- **text-only** + a format whose text section hides text → finding/inconclusive; zero-hiding (`0` masked by a format) is a conscious choice with formula/count verification, not a defect by itself.
- Do **not** flag a `numFmt` merely because it exists in `styles.xml`; flag it only when a column uses it. (Two current models in the corpus carry a custom "General" used by other columns while the mixed column stays default — a presence-only scan would false-positive.)
- **Inconclusive exit:** declare the pending validation and request functional verification in the consumer; the package may proceed with the pending declared, consistent with the "checks, not guarantees" contract.

### Namespace

- The roots of `xl/worksheets/sheet*.xml` must declare the spreadsheet namespace as default (`xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"`), with no prefix. A prefixed root is valid OOXML but is not safe for this consumer: the writer regenerates `sheetData/row/c` without namespace, and with a prefixed root those elements land outside the namespace, so a namespace-resolving reader shows an empty sheet.
- Pin the rule to the **consumer/generator version and the verification reader** (which reader is used to check). Require a minimal fixture before promoting the rule: prefixed template → generated output → inspect the `sheetData/row/c` namespace. If the runtime changes, revalidate.
- Re-run this check on the final embedded body, not on an intermediate `.xlsx`.

### Widths and column ranges

- For OOXML widths, check the `<col min="..." max="...">` ranges: a per-column query in `openpyxl.column_dimensions` may return a default for columns covered by a grouped entry. Read the `min`/`max`/`width` attributes from the ZIP for the actual range; do not treat the per-column default as the effective width.
- The `[$R$-416]...` currency literal and the PowerShell hazard are covered in "Custom formats and styles" below.

### Custom formats and styles

- Do not create a custom `numFmt`/`xf` by default; the default is the contract. Do not remove an existing format that is part of the contract (date, currency, percentage, `#,##0.00`, `0`).
- If the user requests a custom format: record the exact code and the cells/columns, apply only where requested, verify in the consumer and, when possible, in the real generation, and record the limit. Do not use a format to "fix" a symptom.
- `[$R$-416]...` currency: preserve the literal. When patching through PowerShell, use a single-quoted string or a literal here-string, never an expandable string (see `999`).
- Pre-formatted line limit: test the boundary (e.g., 2000/20000) in the served environment; do not assert a mechanism; follow `xpz-msbuild-build` for the build/deploy phase.

### Final body (batch/package or acervo dependency)

- **File in the batch/package:** after any rewrite, re-extract the body from the **front XML** and, when a package exists, from the **package**, and compare bytes/hash; then inspect the ZIP/XML. Validating only the intermediate `.xlsx` is not enough. This is an `ABORT` at closing: if the final body was not re-extracted and compared, abort before concluding.
- **File only as a dependency** (not in the batch/package, referenced by a `Procedure` with `ExcelDocument.Template`): read the body from the **acervo**, run the `.xlsx` checks on it, and declare the `File` as an unchanged dependency with its acervo path/GUID/lastUpdate; there is no front×package body to compare, and no abort for that comparison. The package contains the Procedure, not the `File`.

## Quality Checklist

- [ ] For every `File` in the batch: the generic part above was read; the body was extracted from the final front XML (one `base64Binary`, two Parts) and the shape was confirmed.
- [ ] For every `File` with `.xlsx` (or `Procedure` with `ExcelDocument.Template`): the column/type map, the band classification and the effective number-format resolution were run per column, on the body from the batch/package or, when the `File` is only a dependency, from the acervo; every column ended `ok` or `inconclusive`, with the pending validation declared.
- [ ] No custom `numFmt`/`xf` was introduced without an explicit user request and a verification record; existing contract formats (date, currency, percentage, `0`, `#,##0.00`) were preserved.
- [ ] The worksheet roots use the default namespace (no prefix) on the final body; the consumer/generator version and the verification reader were recorded.
- [ ] For a `File` in the batch/package: the final body was re-extracted from the front XML and from the package and compared (bytes/hash); the origin, hash/size and what counts as proof were recorded; `ABORT` if that was not done.
- [ ] For a `File` `.xlsx` that is only a dependency (not in the batch/package, referenced by a `Procedure` with `ExcelDocument.Template`): the body was read from the acervo, the `.xlsx` checks were run on it, and the `File` was declared as an unchanged dependency with its acervo path/GUID/lastUpdate; no front×package comparison was claimed.
- [ ] `MATCH`/inventory was not treated as proof of content or cell format.

## Related references

- `xpz-builder/responsibilities-by-type/procedure.md` — the Procedure-side contract and the checks that remain there (AutoFit, Base64 extraction, output validation); the column/type map and the OOXML width check are owned by this satellite.
- `01h-moldes-sanitizados-metadados-e-artefatos.md` — the three sanitized `File` molds.
- `999-ideias-pendentes.md` — the three `.xlsx` entries of 2026-11-14 (`$R$`, `col min/max`, AutoFit/boundary).
- `02-regras-operacionais-e-runtime.md` — "Validação funcional pós-import: objetos com insumo externo oficial".
- `xpz-msbuild-build/SKILL.md` — the build/deploy phase for the served copy.
