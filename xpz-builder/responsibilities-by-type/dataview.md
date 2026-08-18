# DataView — Responsibilities and Quality Checklist

Satellite of `xpz-builder/SKILL.md` for the `DataView` object type. **Load this file end-to-end before generating, editing, or packaging a `DataView`**, in addition to the main `SKILL.md`.

This file consolidates type-specific RESPONSIBILITIES and QUALITY CHECKLIST entries. Type-agnostic rules (envelope serialization, package collision gate, manifest, etc.) remain in the main `SKILL.md`.

Evidence base: KB `FabricaBrasil18` (GX 18 U13), frente GamAuditoria, 2026-08-15/17. Todos os GUIDs e shapes abaixo vêm de XPZ exportado pela IDE, validados por import + build com `-FailIfReorg true` nos environments PostgreSQL e SQL Server da KB de origem.

## Responsibilities

### The four mandatory pieces

To read a table that already exists in the database and **must not** be created or altered by GeneXus, a `DataView` requires four pieces together:

1. **`Attribute`** for each column, with an exclusive prefix (e.g. `GamUserMemRoleCreUser`). Dates come via `idBasedOn = Domain:<DominioDeDataHora>`; no attribute declares a date by raw type.
2. **`Transaction`** with the same attributes. It exists **only** to give structure to the DataView — no screen, no rules. It materializes a `Table` in the model, which **does not** become a table in the database.
3. **`DataView`** with `<DataViewStructurePlatform Dbms="NN">`, `NAME` = physical table name and `SCHEMA`.
4. **`DataView` properties**: `DVDataStore` (DataStore name, e.g. `GAM`) and `DVAssocTable`.

**Without `DVAssocTable` the specification fails with `spc0031: No relationship found among attributes`** — the DataView alone does not form a base table for `For Each`.

`DVAssocTable` references attributes by **GUID, not by name**: `<guid-do-tipo-Attribute>-<NomeDoAtributo>`, separated by `;`, in primary key order. `adbb33c9-0906-4971-833c-998de27e0676` is the GUID of the `Attribute` **type** (constant), not of each attribute.

### Multi-DBMS platform declaration — critical production alert

**This is the highest-impact rule for DataView.** The DataView only marks the table as external **on the platforms it declares**. On an environment whose DBMS has no `<DataViewStructurePlatform>`, the `Transaction` becomes a regular model table again and the impact analysis **asks for table creation — including on a client installation, in production.**

Observed symptom: KB with two environments (PostgreSQL and SQL Server); DataViews declaring only PostgreSQL. The SQL Server environment build showed `CREATE TABLE GamUserMemRole (...)` in the impact analysis. After adding one `<DataViewStructurePlatform>` per DBMS present in the environments, both environments closed with `reorgDetected: None` and **zero** `CREATE`/`ALTER TABLE` in the log.

DBMS codes read from the KB `model.ini`:

| DBMS | `Dbms` |
|---|---|
| Oracle | 7 |
| SQL Server | 12 |
| PostgreSQL | 15 |

### Indexes: declare only where the name is stable

`<DataViewIndexesPlatform>` records the **physical index name**. Portable on PostgreSQL, **not** on SQL Server:

- PostgreSQL: deterministic name, `<tabela>_pkey` (`role_pkey`, `usermemrole_pkey`). Same on any installation.
- SQL Server: a PK without explicit name receives a generated suffix on creation — `PK__Role__97C0052AA095D3D6`, `PK__User__81B7740CFF2E4DDD`. **Changes per installation.**

Validated solution: declare the **structure** platform for both DBMS and the **index** platform only for PostgreSQL. It worked — the specification did not require an index for SQL Server.

Measured justification: the index name **never reaches runtime**. `grep -c "pkey\|IdvGam"` on the generated `.cs` = **0**; the SQL comes out without an index hint. It is specification metadata.

### Identifier delimiters are asymmetric between DBMS

Proven by the two `.cs` files of the same object:

| | PostgreSQL | SQL Server |
|---|---|---|
| Generator delimits by itself? | **no** | **yes** |
| Value to write in `NAME` | `"User"` (with quotes) | `User` (bare) |
| Generated SQL | `FROM gam."User"` | `FROM gam.[User]` |
| If written wrong | `User` → `FROM gam.User` → Postgres lowercases to `gam.user` → `relação não existe` | `[User]` → `FROM gam.[[User]]` → `Sintaxe incorreta` |

It only matters when the physical name has uppercase or is a reserved word. In GAM, table `User` is both at once — PostgreSQL keeps `gam."User"` and the rest lowercase; SQL Server keeps everything PascalCase. This cost two import+build rounds: the first for missing quotes on PostgreSQL, the second for extra brackets on SQL Server.

## GUID matrix

Observed in GX 18 U13 (KB `FabricaBrasil18`, XPZ exported by the IDE). Confidence: `confirmado-acervo` (sanitized template derived from real XML, validated by build) for the five GUIDs; the `Attribute` type GUID `adbb33c9-0906-4971-833c-998de27e0676` is also `confirmado-acervo` (same source, used in `DVAssocTable`).

| Element | GUID |
|---|---|
| `DataView` object | `19abc6ff-2cd2-0000-0006-6d172bc2333b` |
| Structure part | `19abc6ff-2cd2-1000-0006-6d172bc2333b` |
| Indexes part | `7706bd3b-212a-1000-0006-8aaeb59068b9` |
| Index object | `fc1b76c4-95c5-0000-0101-44f9543121bd` |
| Index members part | `fe47b55c-ea2a-1000-0101-5b38901e24f7` |
| `Attribute` type (for `DVAssocTable`) | `adbb33c9-0906-4971-833c-998de27e0676` |

## Sanitized named fixtures

- `dvExemploMultiDbms` — canonical template: structure platform per DBMS present in the KB environments (PostgreSQL `Dbms="15"` + SQL Server `Dbms="12"`), index platform only where the index name is stable, `DVAssocTable` + `DVDataStore` present. This is the only shape to generate.
- `dvExemploSingleDbmsMissingPlatform` — anti-example: structure platform declared only for PostgreSQL on a KB that also has a SQL Server environment. The SQL Server environment treats the `Transaction` as a regular table and the impact analysis requests `CREATE TABLE` — including on a client installation, in production. Do **not** generate this shape.

## Quality Checklist

- [ ] For `DataView`, the four mandatory pieces exist together: `Attribute`(s) with exclusive prefix, structural-only `Transaction` (no screen, no rules), `DataView` with `<DataViewStructurePlatform>` and `NAME`/`SCHEMA`, and `DVDataStore` + `DVAssocTable` properties
- [ ] `DVAssocTable` lists the primary key attributes in key order, each as `<Attribute-type-GUID>-<Name>` separated by `;`, using the constant `Attribute` type GUID
- [ ] One `<DataViewStructurePlatform>` exists per DBMS present in the KB environments (Oracle `7`, SQL Server `12`, PostgreSQL `15` — read from `model.ini`), so no environment falls back to `CREATE TABLE` on the structural `Transaction`
- [ ] `<DataViewIndexesPlatform>` is declared only where the physical index name is stable between installations (PostgreSQL `_pkey` pattern); omitted for SQL Server generated PK names
- [ ] `NAME` delimiter matches the DBMS: quoted (`"User"`) for PostgreSQL, bare (`User`) for SQL Server; no stray brackets
- [ ] Build with `-FailIfReorg true` on **each** environment: `reorgDetected` must be `None`
- [ ] `grep -c -E "CREATE TABLE|ALTER TABLE|DROP TABLE"` on the `msbuild.stdout.log` = `0`
- [ ] `grep -o "FROM <schema>[^ ]*"` on each environment's generated `.cs` confirms the delimiter; running the SQL extracted from the `.cs` directly against the database closes the cycle
- [ ] The DataView does not use `For Each` in a WebPanel event — reading goes through a `Procedure` (see `src0065` in `02-regras-operacionais-e-runtime.md`); grid loads iterate the collection with `For &Item in &Itens ... Load ... EndFor`

## Related rules in main SKILL.md WORKFLOW

- Risk assessment before proceeding: `03-risco-e-decisao-por-tipo.md` — `DataView` is `StructuralRisk: alto` (see recalibration note 2026-08-17)
- Source sanity before packaging: `Test-GeneXusSourceSanity.ps1` — `call-in-condition` excludes variable-receiver methods (`&var.Metodo()`) and indexations (`&col(1)`), but flags global procedures, built-in functions and module-qualified calls
- Envelope and `lastUpdate` rules: `02-regras-operacionais-e-runtime.md`
- Part-type matrix and sanitized molds: `01b-matriz-part-types-por-tipo.md` and `01e-moldes-sanitizados-core.md`

## Related references

- `03-risco-e-decisao-por-tipo.md` — risk table, `## DataView` section and recalibration note
- `02-regras-operacionais-e-runtime.md` — source error table (`spc0031`, `src0013`, `src0051`, `src0054`, `src0065`, `src0216`, `src0294`/`src0246`, `src0294` scalar `.IsNull`, `src0229` scalar `.SetNull`, `CS2001` `right()`/`left()`) and Impact Analysis heuristic
- `04-webpanel-familias-e-templates.md` — grid by SDT without base table (Event Grid.Load with `For &Item in &Itens ... Load ... EndFor`)
- `08-guia-para-agente-gpt.md` — quick DataView synthesis and source error table