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
- For each GeneXus object type present in the batch, load the corresponding satellite under `responsibilities-by-type/` end-to-end before generating, editing, or packaging the XML, in addition to this `SKILL.md`. Satellites consolidate type-specific RESPONSIBILITIES and QUALITY CHECKLIST entries. Available satellites: `responsibilities-by-type/transaction.md` (Transaction), `responsibilities-by-type/webpanel.md` (WebPanel), `responsibilities-by-type/panel.md` (Panel, especialmente Panel SD), `responsibilities-by-type/dataprovider.md` (DataProvider), `responsibilities-by-type/api.md` (API; carrega também `responsibilities-by-type/api-gam-runtime.md`, a pré-condição de segurança GAM em runtime que bloqueia declarar "seguro" sem o smoke 2 fases), `responsibilities-by-type/procedure.md` (Procedure, incluindo simple report Procedure), `responsibilities-by-type/workwithforweb.md` (WorkWithForWeb).
- Treat any extra block opened after the first one as an `adjacent block` and open it only when there is explicit functional dependency with the primary edit block
- Name every justified block transition in the review or packaging rationale, instead of silently widening the edit scope
- State the intended conclusion or effect scope at the smallest functional level supported by the delta, including execution context when that distinction matters
- Clone conservatively: preserve `Object/@guid`, `parent*`, `moduleGuid`, all recurring Part types
- Apply XPZ envelope rules from [02-regras-operacionais-e-runtime](../02-regras-operacionais-e-runtime.md)
- Choose package format for deltas of existing objects by validated local precedent first, distinguishing explicitly between embedded-object packages under `<Objects>` and packages that use `<FilePath>` to point to external XML
- Treat local precedent as strong only when the same KB trail shows compatible object type, compatible operation nature, and compatible batch materialization style
- Abort for confirmation instead of extrapolating from weak analogy when no strong enough local precedent justifies the package format
- Treat `runtime`, `Import File Load`, `Import`, and `Specification` as distinct validation layers; success in one does not authorize conclusions about the others
- Validate `Source` compatibility by methodology first: GeneXus semantic rules plus the XPZ trail and `nexa`; use KB corpus search only as fallback when the methodological base does not cover the case
- Separate explicitly `well-formed XML` from `probably importable object` before packaging; never treat XML parse success alone as enough when the object depends materially on `Source`
- When a local XML candidate already exists on disk and depends materially on `Source`, run `..\scripts\Test-GeneXusSourceSanity.ps1 -InputPath <arquivo>` before packaging; treat `sourceSanityStatus=fail` as a hard stop and `warn` as consultative conservative review
- Classify each package candidate by content delta as `requested change`, `necessary auxiliary change`, or `extra unrequested change` before packaging
- Require explicit signaling before packaging when a candidate item remains as `extra unrequested change`, including metadata, reserialization, or known noise that is not strictly required
- Generate valid GeneXus `lastUpdate` timestamp by mechanical rule, not by literal guess: for a modified object use `max(UtcNow + 60s, official-corpus lastUpdate + 60s)` and then reread the saved XML to confirm the persisted value
- Preserve the official `lastUpdate` only for objects that are intentionally reenviados sem mudanca as dependency or package-composition closure
- Treat `lastUpdate` equal to or older than the official corpus as a blocking defect when the object was modified in the round
- Treat manually rounded timestamps, copied timestamps from another file, copied baseline `lastUpdate` on a modified object, or arbitrary future values as invalid `lastUpdate` generation
- Treat `ObjetosDaKbEmXml` as official snapshot and read-only for agents
- Treat any detected or intended edit in `ObjetosDaKbEmXml` for a delta that has not yet returned by official KB re-export as an explicit process error, not as a mere operational detail
- Editing `ObjetosDaKbEmXml` does **not** affect the packaging output — the packaging motor reads from the front folder (`ObjetosGeradosParaImportacaoNaKbNoGenexus/<Frente>/`), never from the corpus; if the agent edits the corpus expecting the package to pick up that version, the package will use the stale version from the front; this is an anti-pattern that the 9-FD gate detects (see `02-regras-operacionais-e-runtime.md`, anti-padrão "editar acervo esperando que o pacote pegue")
- If the object has not yet returned from the KB by official export, perform the work only in `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- When creating an altered copy of GeneXus XML in `ObjetosGeradosParaImportacaoNaKbNoGenexus`, preserve the source XML outside the approved functional delta; the default operation is surgical editing, not broad reconstruction or full-file reserialization
- Outside the approved delta, preserve comments, `CDATA`, indentation, blank lines, node order, line endings, and inherited whitespace; do not introduce trailing spaces or tabs on new or modified lines
- Before packaging, compare the altered copy against the source XML and confirm that the diff contains only the intended delta; whitespace-only changes, indentation churn, line-ending churn, removed comments, or serialization churn outside the delta are process noise and must be corrected or explicitly approved before delivery

### Edição cirúrgica de XML e limitações da ferramenta Edit do harness

- Fluxo obrigatório: copiar o XML oficial de `ObjetosDaKbEmXml` para a frente em `ObjetosGeradosParaImportacaoNaKbNoGenexus` e editar **somente** o delta funcional aprovado na cópia de trabalho; nunca editar `ObjetosDaKbEmXml` diretamente.
- A edição cirúrgica padrão **não** é a ferramenta **Edit** do harness (substituição por trecho em chat) em XML GeneXus com `Source`, `Rules` ou `CDATA` longos. Essa ferramenta pode: (1) normalizar linhas em branco indentadas (tabs/espaços herdados) para quebra de linha pura; (2) tratar `\n\t\t\t\t\n` e `\n\n` como equivalentes na comparação, impedindo correção por novo Edit; (3) introduzir espaços ou tabs no fim de linha ou ampliar o diff para longe do trecho pretendido.
- **Preferido** para alterar XML de objeto: `scripts/Edit-GeneXusXmlSurgical.ps1` (modos `Replace` e `InsertAfter`, validação de âncora, bump automático de `lastUpdate` com escape `-PreserveLastUpdate` para dependência reenviada sem mudança, `-DryRun` e `-AsJson`). Quando o baseline oficial estiver disponível, passar `-LastUpdateBaselinePath` apontando para o XML em `ObjetosDaKbEmXml`. Exemplo copiável: [examples/Edit-GeneXusXmlSurgical.example.ps1](examples/Edit-GeneXusXmlSurgical.example.ps1). Evitar script ad-hoc por frente ou a ferramenta **Edit** do harness como caminho principal.
- Regravar o arquivo inteiro com `Write` só para XML **pequeno** e montado programaticamente a partir da leitura raw da origem; para Procedure/WebPanel/Transaction com `Source` longo, tratar `Write` do arquivo completo como alto risco de churn e evitar como caminho padrão.
- **Não confiar** em nova tentativa da mesma ferramenta Edit só para “recolocar” tabs em linhas em branco ou remover trailing spaces.
- Antes de empacotar: comparar a cópia alterada com o XML de origem da mesma frente. Se o diff trouxer mudanças fora do bloco primário declarado, whitespace-only fora do delta, linhas em branco com indentação herdada alteradas, trailing spaces novos em linhas não tocadas funcionalmente, ou centenas de linhas alteradas longe do delta → **ABORT**, refazer por script/raw e registrar o ruído como erro de processo.
- Quando a edição tiver usado Edit do harness ou o diff suspeitar de whitespace: inspecionar com `scripts/Show-FileWhitespace.ps1` (modos `whitespace` ou `mixed`; `-AsJson` para agentes) conforme `AGENTS.md` na raiz do repositório ativo — no arquivo inteiro ou no intervalo de linhas do delta.

### Edição combinada de `Source` + `Variables` em objeto existente

- Quando o delta inserir código em `Source`/`CDATA` e também criar ou alterar variáveis, declarar explicitamente a transição de bloco `Source -> Variables` (ou `events -> variables`, conforme o tipo) como bloco adjacente justificado; não tratar a seção `Variables` como detalhe implícito do patch de código.
- Antes de montar o patch, medir a política textual do XML-alvo: EOL real do arquivo, regra aplicável em `.gitattributes` do repositório da KB, presença de BOM e estilo dominante de indentação no trecho. Em KB real analisada, `Source` usava tabs e `Variables` usava espaços, mas isso é evidência de corpus, não licença para sobrescrever o estilo do arquivo-alvo.
- Para inserir em `Source`, preferir `scripts/Edit-GeneXusXmlSurgical.ps1` com âncora literal e `-DryRun`; o `Replacement` deve ser construído já com a quebra de linha e a indentação observadas no arquivo-alvo. O helper preserva o texto fora do delta e faz bump de `lastUpdate`, mas não inventa a indentação correta para o chamador.
- Para apenas re-carimbar o `lastUpdate` de um XML da frente já editado (rodada 2+), sem copiar do acervo nem aplicar delta, usar `scripts/Set-GeneXusXmlLastUpdate.ps1` (`-InputPath`, `-BaselineXmlPath` opcional, `-DryRun`, `-AsJson`): recalcula `max(UtcNow + margem, baseline + margem)` e grava in-place com backup e validação, em vez de busca-e-troca manual do atributo. Sem `-BaselineXmlPath`, o baseline é o próprio arquivo — suficiente para ficar acima do objeto vivo na KB, que preserva o `lastUpdate` importado como Modified Date; para garantir acima do acervo, apontar `-BaselineXmlPath` para o XML oficial em `ObjetosDaKbEmXml`.
- Para criar variável, não montar um bloco rígido universal. Clonar primeiro uma variável comparável do próprio objeto; se não existir, procurar uma variável comparável em objeto do mesmo tipo e da mesma KB; só então recorrer a molde sanitizado. Preservar a indentação estrutural da seção `Variables`.
- O corpus real mostra famílias de tipagem por `idBasedOn=Domain:*`, `idBasedOn=Attribute:*`, `ATTCUSTOMTYPE=bas:*`, `sdt:*`, `exo:*`, `bc:*`, `ext:*` e formas legadas sem `idBasedOn`/`ATTCUSTOMTYPE`. Portanto, validações amplas sobre todo o legado devem ser consultivas; checks bloqueantes devem focar as variáveis novas ou declaradas como tocadas no delta.
- Depois de inserir ou alterar variáveis, executar `scripts/Test-GeneXusObjectVariableDelta.ps1 -InputPath <xml> -VariableName <nomes> -AsJson` para as variáveis novas/tocadas. Tratar `status=fail` como bloqueio antes do pacote; tratar `status=warn` como revisão conservadora explícita. Sem `-VariableName`, o script é varredura consultiva do objeto inteiro, não reprovação automática do legado.
- Não validar ingenuamente todas as ocorrências de `&X` no `Source` contra `<Variables>`: o corpus contém entidades XML, variáveis especiais e formas geradas que produzem falsos positivos. Para pacote, validar as variáveis do delta e o trecho funcional tocado.
- Alterar `Source` ou `Variables` no XML não altera `lastUpdate` por si só. O arquivo final modificado deve sair com `lastUpdate` calculado pelo helper ou por regra equivalente antes de empacotar; `checksum` defasado pode ser observado como ressalva, mas não substitui o gate de `lastUpdate`.

- The set of standard KB parallel-folder subfolders (`ObjetosDaKbEmXml`, `XpzExportadosPelaIDE`, `scripts`, `Temp`, `KbIntelligence`, `ObjetosGeradosParaImportacaoNaKbNoGenexus`, `PacotesGeradosParaImportacaoNaKbNoGenexus`) and their recommended creation order are normative in the `xpz-kb-parallel-setup` skill — see [xpz-kb-parallel-setup/SKILL.md](../xpz-kb-parallel-setup/SKILL.md). This builder assumes those names by default and falls back to `xpz-kb-parallel-setup` when alternative naming, structural ambiguity, or missing setup is detected.
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
- When an earlier round of the same front has already been validated, the next round should prefer a delta package with the new increment, not an unnecessarily large accumulated package
- Reusing the same front does not authorize automatically re-packaging the whole active history of that front; the candidate batch for the current round must be reduced to the delta that is still needed
- A phased front is a legitimate pattern when a GeneXus operational limitation makes a safe monolithic package impractical; in that case, splitting the delivery into sequential rounds is part of the methodology, not an ad hoc workaround
- Classify the package intent explicitly before packaging as exactly one of:
  - `pacote funcional` = objetivo principal e alterar comportamento funcional esperado
  - `pacote experimental` = objetivo principal e testar serialização, roundtrip IDE/XPZ, preservação textual, envelope ou comportamento metodológico do fluxo
  - `pacote arquitetural` = objetivo principal e reorganizar estrutura, dependências ou forma de implementação sem provar sozinho mudança funcional
  - `pacote cirurgico` = objetivo principal e corrigir falha localizada ou objeto pontual com delta mínimo
- Treat that package-intent classification as mandatory narrative context, not as optional labeling
- Require a single primary intent per package; if the candidate batch mixes functional change, textual experiment, and architectural adjustment without clear separability, **ABORT** for confirmation or split the package plan before writing
- For `pacote experimental`, describe the expected proof narrowly and do not imply functional validation unless an external IDE/import/specification step actually covered it
- When the user already signals manual IDE import/testing, treat `import_file.xml` as the primary deliverable and generate it promptly instead of postponing packaging
- Prefer `import_file.xml` as the operational package artifact for manual IDE import unless `.xpz` is explicitly required by the user or by a documented local flow
- Do NOT generate `.xpz` as an extra artifact by default when `import_file.xml` already satisfies the intended manual IDE import flow
- Name locally generated packages for IDE import using the preferred pattern `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`
- In that package name, the front is identified only by the prefix `NomeCurto_GUID_YYYYMMDD`; `nn` is only the short package round for that front
- For successive micro-adjustments in the same active front, keep the same front subfolder and the same package prefix `NomeCurto_GUID_YYYYMMDD`; advance only `nn`
- Before writing `NomeCurto_GUID_YYYYMMDD_nn.import_file.xml`, run a deterministic collision gate in `.ps1`; do NOT leave this decision to ad hoc reasoning
- Shared packaging helpers emit machine JSON on stdout by default and do not use `-AsJson`; update old local wrappers through `xpz-kb-parallel-setup`
- When the recommended helper `Build-GeneXusImportFileEnvelope.ps1` is used, the collision gate is embedded and runs before any byte is written; the file is materialized only when the gate returns JSON with `status=ok`
- When the recommended helper `Build-GeneXusImportFileEnvelope.ps1` is used, pass `-AcervoPath <ObjetosDaKbEmXml>`; before serializing the package, the helper always checks front-vs-acervo coherence: the `lastUpdate` gate and `Object/@type` drift by same `guid`. Declaring modified objects with `-ModifiedObjectNames` or `-ModifiedObjectGuids` lets it block `lastUpdate` older than the acervo, `lastUpdate` equal to the acervo for declared modified objects, and unjustified future timestamps.
- When the target flow is **headless MSBuild import** (`xpz-msbuild-import-export`) and the object XML already exists in the parallel KB tree (`ObjetosDaKbEmXml` as read-only reference or `ObjetosGeradosParaImportacaoNaKbNoGenexus` as working copy), prefer assembling **`import_file.xml`** with a shared structured engine: `Build-GeneXusImportFileEnvelope.ps1` for direct template-based assembly, or the safe wrapper `New-XpzImportPackage.ps1` for front-based assembly from the parallel KB folder. Use a validated template (`KMW`, `Source`, `ObjectsIdentityMapping` from local precedent, or metadata such as `kb-source-metadata.md` per `xpz-kb-parallel-setup` for simple/minimal envelopes), then import that package — do **not** run a KB **export** only to obtain a `.xpz` "shell" to patch in parallel XML unless the user explicitly requests that path or confirms that envelope metadata cannot be obtained otherwise (if an exported `.xpz` is used anyway, `xpz-msbuild-import-export` requires a full pre-import object inventory)
- For compact inspection of XML/XPZ without dumping large `CDATA`, use `scripts\Extract-XpzObject.ps1`, `scripts\Get-GeneXusObjectSummary.ps1`, and, for Panel shape checks, `scripts\Compare-GeneXusPanelShape.ps1` before resorting to raw `Select-String` or broad `rg` output; when comparing Panel SD, observe at least `actionEventCoverage`, `namedEventNames`, `standardEventNames`, `variableEventNames`, and `tapEventNames`. For `WebPanel`, the same script exposes a `webpanel` block (tables with `tableType`, controls, buttons in both forms, events, and a `coverage` block); load [responsibilities-by-type/webpanel.md](responsibilities-by-type/webpanel.md) before editing WebPanel layout or events. To add a button to a WebPanel, prefer `scripts\Add-GeneXusButton.ps1` (inserts before or after a named leaf control in a Flex table via `-BeforeControlName`/`-AfterControlName`; fail-closed on populated Responsive) instead of hand-editing the CDATA.
- If a textual search in the corpus returns multiple XML paths, list every match, state a recommended path with reason from user context, and confirm before opening one file; never default to the first tool result.
- In the manual fallback path (textual envelope assembly without the helper), prefer a local wrapper such as `Test-*KbPackageCollision.ps1`, delegating to the shared engine `scripts\Test-XpzPackageCollision.ps1`
- If the collision gate returns JSON with `status=bloqueado` or non-zero exit code, abort the write; do NOT silently overwrite that round
- When there is an `nn` collision, the suggested next free `nn` must come from the collision gate output itself; do NOT auto-increment or write automatically with the suggested value
- Keep `PacotesGeradosParaImportacaoNaKbNoGenexus` flat, without subfolders by front
- Classify each active XML root as `Object`, `Attribute`, or unsupported before serializing the package
- Validate UTF-8 without BOM hygiene on active XMLs before packaging
- Validate textual delta fidelity on active XMLs before packaging: only the approved functional delta should appear in comparison against the source XML
- Reread and apply local repository documentation (`AGENTS.md`, `README.md`, and equivalent project docs) before packaging whenever the target KB/repository defines specific functional review rules, contracts, or operational flow
- Use local repository documentation as the mandatory specialization layer for KB-specific contracts and review chains, without promoting those local rules to the shared XPZ methodology
- Keep general XPZ methodology separate from KB-specific architecture; flows such as `WorkWithWeb -> action -> parm(...) -> For each` may be mandatory in a given repository but are not universal GeneXus or XPZ rules
- Ensure all GUIDs are syntactically valid (no text placeholders like `"YOUR-GUID-HERE"`)
- Validate XML structure before delivery
- Declare confidence level and limitations explicitly at the end of every output
- When generating an object for a small or new KB that has no comparable local XML: follow the resource ladder from [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md); if reaching level 2 (best-effort attempt without commitment), declare explicitly which source sustains the generation (`molde sanitizado`, `XML real da KB atual`, `XML real de KB externa inspecionada`, or `hipótese`), signal the confidence level, and require validation before import; if the probability of success is assessed as low, present the options to the user and wait for a decision before generating
- Keep `WorkWithWeb` noise that is already proven in this trail as non-functional in the manifest, especially `Load Code` in `Selection` and the affected `View` tabs; do not generalize this to unrelated `WorkWithWeb` cases
- When declaring a variable as an SDT collection in any object type (`WebPanel`, `Procedure`, `DataProvider`): use `AttCollection=True`; NEVER use `Collection=True` or `IsCollection=True` — both are invalid and will be rejected; this applies to the variable's `<Properties>` block in the XML
  - for collection reinitialization introduced by the current `Source` delta and already covered by the methodological base, prefer `= new()`; do NOT accept unsupported cleanup forms such as `SetEmpty()` only by plausibility or analogy
  - if a period filter is introduced over a `DateTime` field, prefer direct comparison on the `DateTime` column: `>=` start and `<` next day after end
  - treat function on the database column, especially `ToDate()` over the column, as explicit navigation/performance risk
  - if a function on the column is kept, justify it explicitly
  - when the user asks for an initial-date/final-date pair, prefer two independent `where` clauses instead of branching into unnecessary scenarios
  - when the object already has a clear local form in `Source`, prefer following that form as a weak readability heuristic, not as a hard methodological rule
- When the candidate batch contains 2 or more distinct objects, run the Import Dependency Ordering gate (9-IDO) after all other object-level gates: detect structural dependencies between batch objects, assign each object to a topological layer, alert when ordering risk exists across 2 or more layers, and ABORT when circular dependencies are found

---

## COMMUNICATION

- Respond in the same language the user writes in
- Lead with the decision (proceed / abort) and the reason
- State which template was used and why it was selected
- State the package intent explicitly as `pacote funcional`, `pacote experimental`, `pacote arquitetural`, or `pacote cirurgico`
- When the case is experimental or methodological, say that clearly in the narrative and separate it from any claim about functional behavior
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
| [05b-procedure-relatorio-familias-e-templates.md](../05b-procedure-relatorio-familias-e-templates.md) | Target is a simple report `Procedure`, especially F2/F3 covered by `molde pronto` |
| [07-open-points-e-checklist.md](../07-open-points-e-checklist.md) | Edge cases, provisional decisions, or checklist for new templates |
| [08-guia-para-agente-gpt.md](../08-guia-para-agente-gpt.md) | Decision formula, precedence rules, materialization rules, refuse conditions |
| [01j-workwithweb-cdata-padroes.md](../01j-workwithweb-cdata-padroes.md) | When editing CDATA of a `WorkWithForWeb` object — CDATA hierarchy, anchor rules, sanitized examples |
| [04b-ucw-gxcontroltype-reference.md](../04b-ucw-gxcontroltype-reference.md) | When the target is a `WebPanel` with UCW (`<ucw gxControlType="...">`) — gxControlType catalog, upload context table, event rules, SDT FileUploadData, AttCollection rule |
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
3b. When the user goal is **headless import via MSBuild** and the delta XML already lives in the parallel folder, plan delivery as **`import_file.xml`** through `Build-GeneXusImportFileEnvelope.ps1` (mandatory `-AcervoPath <ObjetosDaKbEmXml>`; front-vs-acervo coherence by `lastUpdate` and `Object/@type`; declare objects actually modified in the round via `-ModifiedObjectNames` or `-ModifiedObjectGuids`) or the front-based safe wrapper `New-XpzImportPackage.ps1` flow (and skill `xpz-msbuild-import-export` for execution + package inventory); do **not** default to KB export to manufacture a `.xpz` shell unless the user explicitly chooses that path or confirms envelope assembly is blocked
3c. For `Panel`, especially Panel SD, treat `level id` and `layout id` as an internally coherent pair. NEVER generate them as independent random GUIDs. Clone or preserve the pair from a comparable real template exported by the IDE from the same KB whenever possible; if the exact derivation rule is unknown, declare the risk and use a coherent template pair instead of isolated GUID substitution.
3d. When packaging a `Panel`, prefer a full comparable IDE-exported envelope through `-TemplatePackagePath` (accepted as `.import_file.xml`/XML or `.xpz`) so `KMW`, `Source`, `Dependencies`, `Attributes` when present, and `ObjectsIdentityMapping` come from a real package. If the package is generated from the minimal `kb-source-metadata.md` envelope, report that as a warning for Panel SD instead of implying equivalence with a full IDE envelope.
3e. For Panel SD with `<action onClickEvent=...>`, read the serialized behavior in `detail/@events`. Do not synthesize `Event Controle.Tap` without equivalent evidence in a comparable real Panel from the target KB; prefer a named `Event 'Nome'` whose quoted name matches the action `onClickEvent`.
4. Before generating or packaging a front, resolve the front identifier explicitly:
   - determine whether the case is `same front` or `new front`
   - do NOT infer `same front` only because the object is the same
   - if continuity was not explicitly stated and no direct repository evidence closes that ambiguity, block automatic inheritance of the previous front identity and follow the applicable local rule
   - When the repository publishes a local front-opening wrapper (for example `New-*KbFront.ps1`) or the shared engine `scripts\New-GeneXusXpzFront.ps1` is directly approved, prefer that atomic wrapper/engine to create or reuse the front folder, generate the front GUID, calculate `YYYYMMDD`, and return any extra GUIDs needed by the batch
   - Treat front-opening wrappers as convenience and permission-hygiene helpers, not as proof that the front is semantically correct; the `same front` vs `new front` decision above remains mandatory
   - only after that, define:
     - `NomeCurto`
     - `GUID` generated when the front is opened
     - `YYYYMMDD` = creation date of the front, defined together with the GUID; it is not the package date
     - front folder = `ObjetosGeradosParaImportacaoNaKbNoGenexus\NomeCurto_GUID_YYYYMMDD\`
     - if that front folder already exists for the current front, reuse it
     - that front folder is the active unit of the work front
4b. Before listing the workspace, declare the round spec for this packaging round:
   - State explicitly which objects (name + type) are expected in the candidate batch for this round
   - This declaration must come from the user's intent or the front's declared scope — not from reading the workspace first
   - If the expected object list is unclear or has not been declared in this conversation → ask the user before proceeding to step 5
   - Record the declared list as the `round spec` for this round; it is the committed delivery target before the workspace is inspected
   - The declared round spec is also the authoritative source of `objetos-foco` for any `xpz-sync` invoked in the same session for this front
5. When the task is packaging, list active XMLs only inside the current front folder and treat them as the candidate batch
   - After listing, verify that the workspace matches the round spec declared in step 4b:
     - Object in round spec but absent from workspace → report the gap explicitly; do NOT silently proceed as if the object were already present
     - Object in workspace but absent from round spec → classify as potential contaminant; do NOT silently absorb into the batch
   - If workspace and round spec diverge, require explicit reconciliation before continuing to step 6
6. Before any package write, execute the deterministic collision gate for the intended `FrontPrefix + nn` in `PacotesGeradosParaImportacaoNaKbNoGenexus`:
   - When the package is assembled via `Build-GeneXusImportFileEnvelope.ps1` (recommended path), pass mandatory `-AcervoPath <ObjetosDaKbEmXml>` and declare modified objects with `-ModifiedObjectNames` or `-ModifiedObjectGuids`; the collision gate is embedded: the helper runs `Test-XpzPackageCollision.ps1` as its first action and aborts with zero bytes materialized when `_nn` is taken; the helper also blocks before writing when front-vs-acervo coherence fails by `lastUpdate` or by same `guid` with divergent `Object/@type`; in that flow, no explicit pre-call to the wrapper is required
   - When the package is assembled via the manual fallback (textual envelope assembly without the helper), the collision gate must be executed explicitly before any `Set-Content`, rename, move, or overwrite of the package artifact
   - Prefer the local wrapper `Test-*KbPackageCollision.ps1` when the KB/repository publishes it
   - The wrapper should delegate to the shared engine `scripts\Test-XpzPackageCollision.ps1`
   - Expected outputs (JSON on stdout by default, no `-AsJson`):
     - free round: `status=ok`, `reason=COLLISION_OK`, exit 0
     - collision: `status=bloqueado`, `reason=PACKAGE_ROUND_COLLISION`, `blockingReasons`, `nextFreeNN`/`nextFreeRound`, exit 20
   - If the gate blocks (`status=bloqueado` or non-zero exit code), **ABORT** packaging before any `Set-Content`, rename, move, or overwrite of the package artifact
7. Classify the package intent before packaging and record it in the conversation/manifests:
   - `pacote funcional`
   - `pacote experimental`
   - `pacote arquitetural`
   - `pacote cirurgico`
   - if the candidate batch does not have one dominant primary intent, **ABORT** and require split or explicit confirmation before packaging
   - if the case is `pacote experimental`, state the bounded proof target explicitly, such as `serialização`, `roundtrip IDE/XPZ`, `preservação textual`, or `envelope/importação`
   - if the case is `pacote experimental`, do NOT narrate the package as if it already proved business behavior
8. Evaluate batch isolation before packaging:
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
   - When the agent received a package from MSBuild export or another source with more objects than the declared delta, treat surplus items as **extra unrequested change** until the user explicitly accepts them; **ABORT** packaging rather than merging surplus into the surgical import package
   - If an older package lost validity after a change of direction, either rename it with prefix `OBSOLETO_` or present a structured manifest in the conversation stating that package X was replaced by package Y; save that manifest as a local file only when local traceability is concretely needed
9-BC. BC dependency preflight gate — run before any packaging when the batch contains a `Procedure`:
   - Run `& ..\scripts\Test-GeneXusBCDependency.ps1 -FrontFolder <pasta-da-frente> -CorpusFolder <ObjetosDaKbEmXml> -AsJson`
   - `not-applicable` (no Procedure in the batch) → proceed normally
   - `pass` (all BC dependencies resolved as info; Transactions exist as BC in the corpus) → proceed normally
   - `alert` (one or more `warn` findings) → present each `warn` finding to the user; require explicit confirmation to package the Procedure(s) and Transaction(s) together, or stage into two packages — package 1 with the Transaction(s), package 2 with the dependent Procedure(s)
   - `fail` (any `fail` finding) → **ABORT** packaging; report each finding (procedureName, transactionName, code, location) and the corrective action implied by the code:
     - `bc-isbc-false-batch` / `bc-isbc-property-absent-batch`: correct the Transaction XML in the batch to set `idISBUSINESSCOMPONENT=True` before packaging
     - `bc-isbc-false-corpus` / `bc-isbc-property-absent-corpus`: the Transaction exists in the official corpus but is not a Business Component; the `bc:` dependency cannot be satisfied without correcting and reimporting the Transaction first
     - `bc-missing-everywhere`: the Transaction is absent from both the batch and the official corpus; add it to the batch or confirm its existence in the target KB before packaging
   - Do not package while any `fail` finding remains unresolved
9-WW. WorkWithWeb Apply-mark preflight gate — run before any packaging when the batch contains a `WorkWithForWeb` object:
   - Run `& ..\scripts\Test-GeneXusWorkWithWebApply.ps1 -FrontFolder <pasta-da-frente> -CorpusFolder <ObjetosDaKbEmXml> -AsJson`
   - The script detects each WorkWithForWeb's structural form (Form A = Part `babfa2b2-...` with explicit `Apply` property; Form B = Part `a51ced48-...` with `<Data Pattern="...">` and linked Transaction in CDATA; Form B implicitly treats `Apply` as `True`), resolves the linked Transaction name (Property in Form A, `<transaction transaction="<guid>-<name>" />` element in Form B), and verifies `Apply:78cecefe-be7d-4980-86ce-8d6e91fba04b = True` on that Transaction in the batch or in the corpus.
   - `not-applicable` (no WorkWithForWeb in the batch) → proceed normally
   - `pass` (only `info` findings: `Apply:GUID=True` confirmed in batch or corpus) → proceed normally
   - `alert` (one or more `warn` findings) → review each finding; for `ww-form-a-apply-false` confirm whether pattern disablement is intentional; for `ww-applyguid-absent-corpus` verify KB state preserves the pattern; for `ww-applyguid-tx-missing` document the gap before packaging
   - `fail` (any `fail` finding) → **ABORT** packaging; the script reports each finding with `code` and the corrective action implied:
     - `ww-no-form-detected`: the XML is unrecognizable as a WorkWithForWeb in either expected form — structural error
     - `ww-form-a-apply-property-absent`: add `<Name>Apply</Name><Value>True</Value>` to the Part `babfa2b2-...` before packaging
     - `ww-linked-transaction-missing`: the WorkWithForWeb does not expose the linked Transaction name in an extractable way — fix the source XML
     - `ww-applyguid-false-batch`: the linked Transaction is in the batch but lacks `Apply:78cecefe-...=True` — add the property before packaging
   - The script also emits `info` findings for diagnostic context (`ww-both-forms-detected` for the rare case of coexistence, `ww-applyguid-true-batch`/`ww-applyguid-true-corpus` for confirmed cases). These do not require action.
9-TWS. Transaction Coherence preflight gate — run before any packaging when the batch contains a `Transaction`:
   - Run `& ..\scripts\Test-GeneXusTransactionCoherence.ps1 -InputPath <arquivo> -AsJson` for each Transaction XML in the batch
   - `not-applicable` (object is not a Transaction or no Transaction found) → proceed normally
   - `fail` → **ABORT**: correct the structural issue (missing key in Level, DescriptionAttribute not found in Level, or WorkWithPlus DVelop screen code — `Call("LoadWWPContext")`/`Call("<Trn>WW")` — carried by a `GenerateObject=False` Transaction, finding `wwp-screen-code-on-non-generated-transaction`; see `responsibilities-by-type/transaction.md`) before packaging
   - `warn` → keep packaging blocked; each flagged finding must be reviewed and either corrected or explicitly justified before proceeding; accepted justifications must be recorded in the closing declaration
   - `pass` → proceed to next gate
9-TXW. Transaction Writability gate — run before any packaging when the batch contains a `Transaction` whose delta involves `Rules` or `Events` with attribute assignments:
   - When the parallel KB has a fresh KbIntelligence index (`schema_version>=2`), you may use `transaction-writable-attributes` for triage before opening XMLs; packaging still requires `Test-GeneXusTransactionWritability.ps1` unless `Test-GeneXusKbIntelligenceWritabilityParity.ps1` has passed on that parallel KB folder
   - Run `& ..\scripts\Test-GeneXusTransactionWritability.ps1 -TransactionPath <transaction.xml> -CorpusFolder <ObjetosDaKbEmXml> -AsJson` for each Transaction XML whose delta assigns attributes (PowerShell facade over `GeneXusTransactionWritabilityCore.py`)
   - The script is descriptive: it returns `pass` after classifying every (level, attribute) pair into `levelAttributes` with `writable=true|false|null` and a `classification` (`key-attribute`, `extended-parent-fk`, `formula`, `extended-subtype-key`, `extended-subtype-descriptive`, `extended-fk-key`, `extended-fk-descriptive`, `own-physical`, `unclassified-attribute-not-found`, `unclassified-table-not-found`)
   - Any attribute with `writable=false` must be excluded from assignments in the delta; assigning to a non-writable attribute requires an explicit **ABORT** of the assignment before packaging
   - `writable=null` (any `unclassified-*` classification) means the corpus lookup did not resolve and the writability cannot be decided; resolve the corpus gap or document the limitation before assigning that attribute
   - This gate never returns `fail` by itself — the ABORT comes from the assignment policy above
9-PNW. Procedure New Writability gate — run before any packaging when the batch contains a `Procedure` whose `Source` contains `New`:
   - Run `& ..\scripts\Test-GeneXusNewWritableTargets.ps1 -FrontFolder <pasta-da-frente> -CorpusFolder <ObjetosDaKbEmXml> -AsJson` (PowerShell facade; writability classification via `GeneXusTransactionWritabilityCore.py` batch)
   - The script extracts direct left-side assignments inside each `New`/`EndNew` block, infers candidate `Transaction` targets from the assigned attribute set, and applies the same writability classifications used by 9-TXW.
   - `pass` (only `info` findings) → proceed normally
   - `alert` (ambiguous target with all assigned attributes writable in more than one candidate) → confirm and record the intended base table before packaging
   - `fail` (`new-assignment-non-writable`, `new-assignment-unclassified`, or `new-target-unresolved`) → **ABORT** packaging; remove the invalid assignment or prove the intended base table with a stronger local reference before re-running
   - Never treat an attribute as writable in `New` only because it is visible, inferable, descriptive, formula-derived, or reachable through an extended table; the target must be physically assignable in the base table inferred for that `New`
9-PSM. Procedure Sub-pattern Mirroring gate (advisory) — run before any packaging when the batch contains a `Procedure`:
   - Run `& ..\scripts\Test-GeneXusProcedureSubPattern.ps1 -FrontFolder <pasta-da-frente> -CorpusFolder <ObjetosDaKbEmXml> -AsJson`
   - `not-applicable` (no Procedure in the batch) → proceed normally
   - `pass` (only `info` findings: no pattern to mirror, Procedure new, or new Sub coherent with dominant pattern) → proceed normally
   - `alert` (one or more `warn` findings with code `psm-new-sub-mixed-diverges`) → present each alert to the user using the message from the script; the dominant pattern (`iterationSub` → `unitSub`) is in the finding's `dominantPattern` field; require the user to either confirm the divergence is intentional (justification recorded in the closing declaration) or restructure the new Sub to mirror the pattern before packaging
   - This gate is architectural coherence signal, not syntactic — it **never** returns `fail` and **never** ABORTs packaging by itself
   - Known limitation: the gate detects newly introduced Subs only; materially expanded Subs (existing Sub whose body changed substantially) are not detected — agent review of Source diff remains required when expansion is the kind of change in question
9-IDO. Import Dependency Ordering gate — run before any packaging when the batch contains 2 or more distinct objects:
   - Run `& ..\scripts\Test-GeneXusBatchDependencyOrdering.ps1 -FrontFolder <pasta-da-frente> -CorpusFolder <ObjetosDaKbEmXml> -AsJson`
   - `not-applicable` (fewer than 2 objects in the batch) → proceed normally
   - `pass` (single layer — no in-batch dependency edges detected) → proceed normally
   - `alert` (`warn` finding `ido-multiple-layers`) → present the suggested staging (layers in the finding) to the user; require explicit confirmation or justification before proceeding with single-bundle packaging
   - `fail` (`fail` finding `ido-cycle-detected`) → **ABORT** packaging: present the cycle (listed in the finding) to the user and require resolution before re-running
   - When the batch contains `WorkWithForWeb` objects, the script also emits an `info` finding with code `ido-ww-detection-pending` — the WorkWithForWeb → linked Transaction dependency detection is **not** yet wired into this script, even though the 9-WW gate itself now reads both structural forms. When this info finding is present and the batch mixes a WorkWithForWeb and its linked Transaction, the agent must verify ordering manually (read the linked Transaction from the WorkWithForWeb XML using the 9-WW form detection rules, then check whether that Transaction is in the batch) before packaging
   - Detection scope: (a) Procedure with `bc:<X>` → Transaction X when X is in the batch; (b) Procedure A → Procedure B when A calls B in its Source and B is new in this delta (not in `ObjetosDaKbEmXml`). Procedure → Procedure detection is best-effort scan of Source — false positives may be filtered by user review
9-FD. Front-Acervo drift gate — run before any packaging when `ObjetosDaKbEmXml` exists as the official corpus:
   - Run `& ..\scripts\Test-GeneXusFrontAcervoDrift.ps1 -FrontFolder <pasta-da-frente> -AcervoFolder <ObjetosDaKbEmXml> -AsJson`
   - `not-applicable` (no Object XMLs in the front) → proceed normally
   - `pass` (only `info` findings) → proceed normally
   - `alert` (one or more `warn` findings) → present each `warn` finding to the user; for `front-equals-acervo` confirm whether the lastUpdate was intentionally preserved (dependency re-sent without change) or needs updating; for `lastupdate-unparseable` resolve manually before packaging
   - `fail` (any `fail` finding) → **ABORT** packaging; report each finding and the corrective action:
      - `front-older-than-acervo`: the XML in the front has an older `lastUpdate` than the corresponding XML in the official corpus — use `Copy-GeneXusAcervoToFront.ps1` (`& ..\scripts\Copy-GeneXusAcervoToFront.ps1 -FrontFolder <pasta-da-frente> -AcervoFolder <ObjetosDaKbEmXml>`) to copy the newer version from the corpus to the front with automatic `lastUpdate` bump, or copy manually and bump the `lastUpdate`; for initial seed of an existing corpus object that is not yet in the front, call the same script with explicit `-ObjectList`, `-ObjectNames` or `-ObjectGuids`; after resolution, re-run the 9-FD gate to confirm the drift is cleared. Pre-requisite for any populate/seed: the front folder must already exist, opened by `New-GeneXusXpzFront.ps1` (wrapper `New-*KbFront.ps1`, `-ReuseIfExists` to resume) — do not create it manually; `Copy-GeneXusAcervoToFront.ps1` and the gates only populate/inspect an existing front
      - `front-object-type-drift`: the front XML and official corpus XML have the same `guid` but different non-empty `Object/@type` after `Trim()` — **ABORT** and ask for a human decision. Do not auto-copy from the corpus or bump `lastUpdate`; first determine whether the correct object is the front XML, the corpus XML, or whether the generated/selected XML is contaminated. Public type-drift payload uses normalized `objectGuid`, `matchBasis=guid`, `acervoPath`, and `message`.
      - `front-object-type-drift-ambiguous-acervo`: the same normalized `guid` appears in more than one corpus XML — informational only in Phase 1, with `matchBasis=guid-ambiguous` and non-empty `candidateAcervoPaths`; do not choose an official `Object/@type` arbitrarily.
   - When using `New-XpzImportPackage.ps1` (the front-based packaging wrapper), this gate **always** runs before the Python motor is invoked (fail-closed): `-AcervoPath` is optional and, when omitted, the canonical acervo `<RepoRoot>/ObjetosDaKbEmXml` is auto-resolved; with no acervo resolvable, packaging is **blocked** (the gate is never skipped by omission). The JSON field `acervoResolvedBy` reports `explicit` or `convention`. `fail` and `alert` both block automatic packaging, because `warn` findings require explicit acknowledgment or resolution before another packaging attempt
   - This gate does **not** replace 12 (check for improper local changes in `ObjetosDaKbEmXml`); 9-FD compares front vs. corpus content, while 12 detects direct edits in the read-only corpus
12. Check for improper local changes in `ObjetosDaKbEmXml`:
   - If detected, treat this as an explicit process error
   - Preserve those XMLs in `ObjetosGeradosParaImportacaoNaKbNoGenexus`, restore `ObjetosDaKbEmXml` to the official Git version, present a structured manifest of preserved items in the conversation, save it as a local file when incident traceability requires it, and **ABORT** packaging until the snapshot is sane
   - If the target object has not yet returned from the KB by official export, keep working only from `ObjetosGeradosParaImportacaoNaKbNoGenexus`
13. Load [03-risco-e-decisao-por-tipo](../03-risco-e-decisao-por-tipo.md) → assign risk level
14. Evaluate abort conditions:
   - Risk is high/very high AND no comparable internal template exists → **ABORT**
   - Type is not in the empirical corpus → **ABORT**
   - User requests affirmation of import/build success → **REFUSE**, state limitation
15. Locate template:
   - Transaction → use family F1–F6 from [05-transaction-familias-e-templates](../05-transaction-familias-e-templates.md)
   - WebPanel → use closest family from [04-webpanel-familias-e-templates](../04-webpanel-familias-e-templates.md)
   - For `WebPanel`, declare the primary edit block before touching the XML and use only the adjacent blocks required by explicit functional dependency
   - For `DataProvider`, declare the primary edit block before touching the XML and use only the adjacent blocks required by explicit functional dependency
   - For `API`, declare the primary edit block before touching the XML and use only the adjacent blocks required by explicit functional dependency
   - Simple report `Procedure` → use the canonical sanitized family from [05b-procedure-relatorio-familias-e-templates](../05b-procedure-relatorio-familias-e-templates.md) first when the case fits simple F2/F3 coverage and the selected block is marked as `molde pronto`
   - Other types → use sanitized representative from [08-guia-para-agente-gpt](../08-guia-para-agente-gpt.md) materialization rules
   - For simple report `Procedure`, escalate to comparable real XML only when the request falls outside the documented simple family, when the initial attempt plus one short structural corrective attempt already failed, or when KB-local dialect/localism appears
   - For simple report `Procedure`, every output or handoff must label the basis used as exactly one of: `molde sanitizado`, `XML real da KB atual`, `XML real de outra KB`, or `hipótese`
   - If the object has already returned from the KB via official XPZ processing, prefer the current XML in the official corpus over any older delta/import working copy when selecting the base for a new change
   - Before cloning identity fields, classify the container from comparable corpus XML using `Object/@parentType` — never from the directory name in `ObjetosDaKbEmXml`, which varies across KBs. The canonical mapping of container GUIDs lives in [scripts/gx-object-type-catalog.json](../scripts/gx-object-type-catalog.json) (entries `Folder` for user-created containers, `Module` for GeneXus system/organizational containers, `PackagedModule` for installed modules, and `RootModule` for the virtual KB root that has no XML file in the acervo). Read the GUID from the corpus XML and look it up in the catalog; do NOT hardcode parentType GUIDs inline.
16. Apply conservative cloning:
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
   - For `WebPanel`, treat serialized functional metadata as its own functional layer; do NOT collapse it into visual layout when planning or reviewing the delta
   - For `WebPanel`, do NOT treat template defaults mentioning `Conditions` as proof that a real filter is materialized in the object
   - For `WebPanel`, NEVER manually reconstruct serialized layout `CDATA` after truncated reading; extract the full block structurally or apply a surgical substitution on the full raw file while preserving the original serialized layout byte-for-byte outside the intended delta
   - For `WebPanel`, name each justified block transition during review, for example `events -> variables` or `layout -> serialized functional metadata`
   - For `WebPanel`, if the current reasoning no longer needs a new block, stop expanding; do NOT reopen the whole object by reflex
   - For `DataProvider`, treat `Output structure` as its own functional layer; do NOT collapse return shape into a generic `Source` reading
   - For `DataProvider`, if the delta touches collection vs simple, nested groups, node names, or return cardinality, classify `Output structure` as the primary edit block unless explicit evidence points elsewhere
   - For `DataProvider`, if the delta depends on `For each`, base table, filters, or navigation ambiguity, open `Navigation context` only as an explicitly justified adjacent block
   - For `DataProvider`, do NOT treat `SDT`, `Procedure`, `BC`, or `Transaction` dependency inventory by itself as proof of the output shape
   - For `DataProvider`, name each justified block transition during review, for example `Output structure -> Source` or `Source -> Navigation context`
   - For `DataProvider`, if the current reasoning no longer needs a new block, stop expanding; do NOT reopen the whole object by reflex
   - For `API`, treat `Service contract` and `Data contract` as their own functional layers; do NOT collapse endpoint contract, response shape, and internal orchestration into a generic code reading
   - For `API`, if the delta touches exposed method, endpoint, signature, published operation, input/output shape, or response structure, classify `Service contract` or `Data contract` as the primary edit block unless explicit evidence points elsewhere
   - For `API`, if the delta depends on `.Before/.After`, internal validation, transformation, or orchestration flow, open `Events and orchestration` only as an explicitly justified adjacent block
   - For `API`, do NOT treat `Procedure`, `SDT`, `Domain`, `Transaction`, `EXO`, or `DataProvider` dependency inventory by itself as proof of the published contract
   - For `API`, name each justified block transition during review, for example `Service contract -> Data contract` or `Events and orchestration -> Calls and dependencies`
   - For `API`, if the current reasoning no longer needs a new block, stop expanding; do NOT reopen the whole object by reflex
   - Before generating a new delta for an object that already returned from the KB, compare any intermediate import/delta copy against the official corpus XML and rebase on the official corpus if the working copy is stale
   - If a filter, business rule, or functional interpretation depends on a calculated or derived field, open the field formula/source and review the immediate chain of called procedures before defining the condition
   - Do NOT conclude the semantic meaning of a calculated or derived field from its name, label, or mere XML presence
   - If the change introduces or rewrites `Source`, classify every new operator, function, conversion, and string/numeric pattern introduced by the change
   - Each introduced `Source` construct must be anchored by layer-1 methodological evidence from this XPZ trail: explicit rule, sanitized example, or documented template
   - Local KB corpus may confirm or disambiguate the choice, but does NOT replace layer-1 methodological evidence
   - If an essential `Source` construct is still justified only by plausibility, generic GeneXus memory, or isolated local corpus evidence, rewrite it using documented patterns or **ABORT**
   - Before packaging an object that depends materially on `Source`, classify the result explicitly as `well-formed XML` and `minimum Source sanity gate passed` or `failed`
   - If XML is well-formed but the minimum `Source` sanity gate failed, **ABORT** packaging
   - Use lightweight automated `Source` sanity checks from the repository only as advisory support; a pass does not prove import/build success
   - Recommended local check command when the XML file is already materialized: `& ..\scripts\Test-GeneXusSourceSanity.ps1 -InputPath .\Objeto.xml`
   - Interpret the JSON result conservatively:
     - `xmlWellFormed=false` -> **ABORT** before any packaging discussion
   - `sourceSanityStatus=fail` -> **ABORT** packaging and correct structural balance first
     - `fail` also covers the type-aware finding `procedural-in-conditions`: a `Procedure` with a non-empty `Conditions` part is rejected because `Procedure` has no `Conditions` filter (predicates live in `For Each ... Where`) and code there triggers `src0055` on import; `WebPanel`/`Prompt`/`Selection List`, where `Conditions` is a legitimate filter, and `Data Selector`, which has its own `Conditions`, stay out
   - `sourceSanityStatus=warn` with `probablyImportable=true` -> keep packaging blocked until each warning is either rewritten to a documented conservative form or explicitly justified as residual risk
   - `sourceSanityStatus=pass` with `xmlWellFormed=true` -> proceed only to the next packaging gate; do NOT describe this as proof of import/build success
   - If GeneXus `Source` is serialized inside `CDATA`, scan the saved block before packaging and **ABORT** if the literal code still contains XML entity spellings such as `&amp;`, `&quot;`, `&gt;`, or `&lt;` that should have remained raw code characters
   - For report `Procedure`, classify each edited fragment before serialization as `Source`, `Rules`, or layout and reject any cross-layer mixture
   - For simple report `Procedure`, load [05b-procedure-relatorio-familias-e-templates.md](../05b-procedure-relatorio-familias-e-templates.md) as a mandatory reference before generating from `molde pronto`; do NOT treat that read as optional
   - For report `Procedure`, verify coherence between layout `PrintBlock` names and each `print printBlock...` reference in `Source`
   - For report `Procedure`, if `Source` prints `printBlockX`, require a matching layout `PrintBlock` with coherent `RPT_INTERNAL_NAME`; if the pair is missing, **ABORT** before packaging
   - For report `Procedure`, when cloning or adapting `PrintBlock` elements, verify that each `RPT_INTERNAL_NAME` value is unique across all sibling blocks in the layout Part; duplicate `RPT_INTERNAL_NAME` values across distinct blocks are a hard structural error — **ABORT** before packaging
   - For report `Procedure`, treat the total layout width as a structural constant inherited from the source template or reference XML; do NOT invent or assume a default value — read it from the canonical template or cloned source; when the value is ambiguous, document the observed value explicitly in the packaging rationale before proceeding
   - For report `Procedure`, if an import error points to invalid control, report block, or layout shape, inspect layout first before altering envelope
17. Apply envelope rules from [02-regras-operacionais-e-runtime](../02-regras-operacionais-e-runtime.md):
   - For delta of an existing object, prefer the package format with validated local precedent in the same KB trail before any generic preference
   - Distinguish explicitly between embedded-object package under `<Objects>` and package using `<FilePath>` to external XML
   - Consider local precedent strong only when object type, operation nature, and batch materialization style are compatible with the current case
   - If precedent is only partial or analogical, justify it explicitly or **ABORT** for confirmation instead of extrapolating
   - If the user has already signaled manual IDE import/testing, generate `import_file.xml` as soon as the delta is materially ready instead of postponing package creation
   - Use `import_file.xml` as the primary package artifact for manual IDE import unless `.xpz` is explicitly required
   - Wrap in `<ExportFile>` with `<KMW>`, `<Source>`, `<Objects>`, `<Dependencies>`
   - Keep `Source/@kb` and `Source/Version/@guid` in valid GUID format
   - Valid GUID format is not enough for headless import: when a local target KB identity is known, `Source/@kb` from the package or template must match that native KB. If it differs, treat the package as cross-KB, **ABORT** agent automation, and route the case to manual IDE evaluation per [02-regras-operacionais-e-runtime.md](../02-regras-operacionais-e-runtime.md).
   - Do NOT include special KB block unless explicitly documented as required
18. Set or preserve `lastUpdate` according to the batch-role classification:
   - Classify each active XML as `modified in this round` or `reused unchanged for mandatory dependency closure`
   - If any textual change was persisted in the final XML, classify the item as `modified in this round`
   - Modified object → set `lastUpdate` to `max(UtcNow + 60s, official-corpus lastUpdate + 60s)`; when available, prefer a local wrapper such as `Get-*KbLastUpdate.ps1` or the shared engine `scripts\Get-GeneXusXpzLastUpdate.ps1 -BaselineXmlPath <xml-do-acervo>` to capture that value in one atomic call
   - Unchanged dependency object → preserve the official `lastUpdate` from the official corpus XML
   - If classification and materialized `lastUpdate` diverge → **ABORT**
19. Audit `lastUpdate` after every local write:
   - After writing or rewriting an object XML, reopen the saved file and confirm the root `lastUpdate`
   - If the object was actually modified, `lastUpdate` must be strictly fresher than the official corpus baseline and normally use the 60-second freshness margin
   - If the object was not modified and is included only for mandatory dependency closure, preserve the official `lastUpdate` from the corpus XML
   - Do NOT continue to packaging until the saved-file header has been checked
20. Before packaging, classify active XML roots and validate packaging hygiene:
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
   - Prefer a shared structured engine for `import_file.xml` assembly. Use `scripts\Build-GeneXusImportFileEnvelope.ps1` for direct object XML inputs and a validated template package, with mandatory `-AcervoPath <ObjetosDaKbEmXml>` and `-ModifiedObjectNames` or `-ModifiedObjectGuids` for objects actually modified in the round; that helper clones `KMW`/`Source`/`Dependencies`/`ObjectsIdentityMapping` from the template, clones top-level `Attributes` from the template when no explicit `-TopLevelAttributesXmlPaths` were passed, embeds each object via `ImportNode` (which guarantees no inner `<?xml ...?>` is carried over), runs the deterministic collision gate (`Test-XpzPackageCollision.ps1`) before any write so a colliding `_nn` aborts the script with zero bytes materialized, checks front-vs-acervo coherence (`lastUpdate` and `Object/@type` by same `guid`) before serializing, and runs the envelope gate automatically before delivery. Use the safe wrapper `scripts\New-XpzImportPackage.ps1` when the package source is a named front under `ObjetosGeradosParaImportacaoNaKbNoGenexus`; pass `-TemplatePackagePath` for mixed/complex packages so the front-based engine clones a comparable real envelope instead of relying on metadata-only minimal envelope, including top-level `Attributes` from the template when the front does not provide explicit `Attribute` roots. `-TemplatePackagePath` may point to `.import_file.xml`/XML or to a `.xpz` that contains an `ExportFile` XML.
   - When passing `-TemplatePackagePath`, ensure the chosen template is **comparable** to the current case: same KB origin, similar package nature (full vs surgical delta vs migration), and import-flow context aligned with current intent. Cloning from a non-comparable template can contaminate the new package with `Dependencies` and `ObjectsIdentityMapping` bindings from an unrelated context — that is a worse outcome than the metadata-derived minimal envelope. If a comparable template is not available, prefer the minimal envelope (omit `-TemplatePackagePath`) and accept the engine's `envelope-minimo` warning explicitly in the packaging rationale. When local evidence shows that the active import flow expects a full IDE-style `ExportFile` envelope, prefer a comparable IDE-exported template regardless of GeneXus major version; do not encode this as a GeneXus 16-only rule. When the parallel folder documents a known-good reference package path (e.g., in its local `AGENTS.md`), use that path as default candidate for `-TemplatePackagePath`; verify comparability before passing it.
   - `ObjetosGeradosParaImportacaoNaKbNoGenexus` and `PacotesGeradosParaImportacaoNaKbNoGenexus` are agent-managed work areas, not user drop folders. If an example/reference/template XML appears inside the active front, including root-valid `Object`/`Attribute` XML explicitly marked as reference material, or if any unsupported XML appears there, **ABORT** packaging and move the reference outside the generated-objects area only with explicit user approval and traceability; do not silently ignore it.
   - Treat manual text-level assembly of `import_file.xml` (string concatenation of object XMLs into the envelope) as a discouraged fallback subject to the NEVER constraint above (CONSTRAINTS): allowed only when both shared engines are demonstrably unusable AND the user has explicitly acknowledged the exception
   - When the helper rejects the package, the candidate file is preserved as `<OutputPath>.rejected.<A..Z>` for forensic inspection; do NOT rename it back to the canonical `*.import_file.xml` to retry — fix the input and rerun
   - Run `scripts\Test-GeneXusImportFileEnvelope.ps1 -InputPath <package>` after writing the final `import_file.xml`; the gate emits JSON by default. For Panel with a comparable package/object available, also pass `-PanelReferencePath <template-or-object>` so a confirmed `level id`/`layout id` pair is information rather than an unresolved warning. Treat `não apto para prosseguir` as a hard stop before delivery. `Build-GeneXusImportFileEnvelope.ps1` already calls this canonical gate and passes its `-TemplatePackagePath` as the Panel reference; `New-XpzImportPackage.ps1` performs its own internal envelope validation, so the canonical gate must still be run explicitly before delivery unless it has already been run after package assembly.
   - When the user has explicitly authorized **headless import** in the same session and `Test-GeneXusImportFileEnvelope.ps1` returned `apto para prosseguir`, do **not** treat packaging as the end of the round: hand off to `xpz-msbuild-import-export` and execute `Invoke-GeneXusXpzImport.ps1` per that skill (`-StartWatcher` and `-MonitorLogPath` mandatory). Envelope validation alone is not the final step.
   - NEVER copy objects from an exported `.xpz` or external package into the current front's `import_file.xml` without classifying each item as requested change, necessary auxiliary change, or **extra unrequested change**; any **extra unrequested change** blocks packaging until explicitly resolved with the user — do not silently absorb export bloat (platform modules and similar extras can trigger very long builds).
   - After `Build-GeneXusImportFileEnvelope.ps1` or `New-XpzImportPackage.ps1` returns, read embedded `packageInventory` from the JSON before closing the packaging round. When the summary points to a sidecar (`packageInventory.nominalInventoryAt`, `packageInventoryPath`, or `<outputPath>.package-inventory.json`), open it for the full nominal list — do not rely on `extrasSample` alone (`extrasSample` covers only `<Objects>` extras when `extrasCount <= 50`; top-level `<Attributes>` are never in `extrasSample`). When `extrasSampleTruncated=true`, when `nominalInventoryAt` is present, or (in selective delta comparison) when `extrasFullListAt` is present, use the sidecar for the full extras list (`extrasSample` may already list extras inline when `extrasCount <= 50`). For manual-only paths, run `scripts\Get-GeneXusImportPackageObjectInventory.ps1 -InputPath <import_file.xml ou .xpz>` with `-DeclaredDeltaPath` or `-DeclaredDeltaItems` as needed; the inventory emits JSON by default. On later user questions about nominal package content (same round or a new session), re-read the sidecar when it still exists (path A) or re-run the inventory motor on the final artifact (path B) before answering — see **INVENTÁRIO PÓS-BUILD DO PACOTE**; for `.xpz` from KB export MSBuild, follow `xpz-msbuild-import-export` inventory rules.
   - If an object is embedded under `<Objects>`, it must appear as XML element content only; embedded XML declaration such as `<?xml version="1.0" ...?>` inside `<Objects>` is a blocking envelope error
   - Verify that `<Objects>` contains no text nodes or placeholder literals (strings such as `YOUR-GUID-HERE`, `PLACEHOLDER`, `TODO`) — these indicate the object XML was not properly embedded
   - If the current flow is manual IDE import and `import_file.xml` is still missing, do NOT treat the packaging task as complete
21. Reread and apply local repository documentation before packaging:
   - Reopen `AGENTS.md`, `README.md`, and any equivalent local KB/repository documentation that defines project-specific functional review chains, contracts, or operational flow
   - Treat those local conventions as mandatory only for that repository, not as universal XPZ methodology
   - If the local documentation requires a functional review chain for the current change type, verify that chain end-to-end in the local XML before packaging
   - Do NOT continue to packaging while any applicable local rule remains pending, ambiguous, or inconsistent in the saved XML
22. Validate:
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
   - For cloned `WebPanel`, if the delta should preserve the original binding surface, extract and compare the relevant serialized bindings from original and clone before packaging; at minimum, confirm matching `fieldSpecifier` count and names, and classify any divergence as intentional delta or clone error
   - For `WorkWithForWeb`, load [01j-workwithweb-cdata-padroes](../01j-workwithweb-cdata-padroes.md) before any textual edit inside the CDATA; the internal XML has at minimum two distinct `<actions>` scopes and often more when Grid tabs are present — empirically, 2/3 of objects in production KBs have `<actions>` in both `<selection>` (list-level) and `<tab>` (detail/grid-level)
   - For `WorkWithForWeb`, do not use broad text substitution over repeated tags such as `<actions>`; a pattern-only regex will match across all levels: `<selection>/<actions>` (list actions), `<tab type="Tabular">/<actions>` (per-record actions), and each `<tab type="Grid">/<actions>` (child grid actions)
   - For `WorkWithForWeb`, anchor any textual insertion at the intended scope using the parent block's unique structural identifier: `<selection>` for list-level actions; `<tab code="General">` for the main Tabular detail tab; `<tab code="X">` for a specific Grid tab — the `code` attribute is the stable KB-side identifier generated by the pattern and does not vary by locale
   - For `WorkWithForWeb`, confirm any new action appears exactly once in the intended scope; duplicates or ambiguous action scope block packaging
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
23. Deliver XML with limitations block:
   - Which template was used
   - Confidence level
   - That the saved XML was reread and the persisted `lastUpdate` was confirmed after the final local write
   - Which applicable local repository rules were reread and satisfied before packaging
   - What requires external IDE validation (`Import File Load`, `Import`, `Specification`, runtime)

---

## INVENTÁRIO PÓS-BUILD DO PACOTE

- Após gravar `import_file.xml` (ou `.xpz` equivalente), os motores `scripts/Build-GeneXusImportFileEnvelope.ps1` e `scripts/New-XpzImportPackage.ps1` embutem `packageInventory` resumido no JSON de retorno quando o pacote foi materializado com sucesso (`outputPath` presente), via `scripts/GeneXusPackageInventorySupport.ps1` (mesmo motor do export MSBuild documentado em `xpz-msbuild-import-export`).
- O inventário usa `scripts/Get-GeneXusImportPackageObjectInventory.ps1` sobre o arquivo gerado, grava sidecar `<outputPath>.package-inventory.json` e confronta o conteúdo real com o delta declarado (`-ModifiedObjectNames`/`-ModifiedObjectGuids` no build direto; objetos `Object` da frente no wrapper por pasta). O resumo expõe `nominalInventoryAt` (lista nominal completa no sidecar) sempre que o sidecar for gravado; `extrasSample` (somente extras de `<Objects>` quando `extrasCount <= 50`), `extrasSampleTruncated` quando `extrasCount > 50` (omissão de `extrasSample` no resumo); em confronto seletivo com delta, `extrasFullListAt` aponta para o mesmo sidecar (lista completa de extras de `<Objects>`); atributos top-level **não** entram em `extrasSample`.
- Reproduzir no relatório ao usuário **antes** de fechar a rodada de empacotamento: `totalObjects`, `totalAttributes`, `objectsByType`, `systemObjectsPresent`, `attributesTopLevelUnreconciled` e `inventoryWarnings` quando existirem.
- Em confronto seletivo com `extrasCount > 0`, listar **todos** os extras do bloco `<Objects>` por nome (`Tipo:Nome`); com `extrasCount <= 50` podem estar em `extrasSample`, mas com `extrasSampleTruncated=true` ou para lista nominal completa abrir `nominalInventoryAt` / `extrasFullListAt` ou o sidecar.
- Com `attributesTopLevelUnreconciled=true` (envelope seletivo sem `Transaction` na lista declarada), listar **cada** atributo top-level do bloco `<Attributes>` por nome (não só `totalAttributes`); com `Transaction` na lista declarada, atributos top-level esperados não exigem enumeração nominal no fechamento, salvo pedido explícito do utilizador.
- Quando `systemObjectsPresent` não estiver vazio num pacote tratado como delta cirúrgico, declarar cada entrada (`kind` + `name`) antes de entregar o pacote ou encaminhar import MSBuild.
- Perguntas sobre conteúdo nominal do pacote (**mesma rodada** ou **sessão nova** sobre o `import_file.xml`/`.xpz` já gerado) exigem fonte autoritativa antes de responder. **Caminho A:** reler o sidecar via `packageInventory.nominalInventoryAt` ou `<outputPath>.package-inventory.json` quando ainda existir. **Caminho B:** reexecutar `Get-GeneXusImportPackageObjectInventory.ps1 -InputPath <artefato>` quando o sidecar não existir mais. `extrasSample`, `objectsByType` e contagens do JSON de retorno são resumo amostral ou agregado; memória de conversa anterior também é amostral.
- **Anti-padrão (nomeado): contagem nominal no lugar do pacote** — relatar «empacotei N objetos» usando só a contagem de `-ModifiedObjectNames`, entradas da frente ou XMLs listados na conversa, sem ler `packageInventory` do retorno do motor ou inventário manual equivalente sobre o arquivo final.
- **Anti-padrão (nomeado): amostra de extras no lugar da lista completa** — relatar `extrasSample` ou `totalAttributes` como se fossem o conteúdo real do pacote, omitir atributos top-level quando `attributesTopLevelUnreconciled=true`, ou ignorar o sidecar quando o motor já gravou `nominalInventoryAt`. O JSON resumido serve à máquina; não substitui a comunicação nominal ao humano.
- Pacotes vindos de **export MSBuild** seguem a governança completa em `xpz-msbuild-import-export` (secção inventário após export seletivo); esta secção cobre o pós-build via `xpz-builder`.

---

## WWP PACKAGING

WWP packaging guidance lives in the satellite [wwp-packaging.md](wwp-packaging.md). **Load it when the package contains WorkWithPlus objects** (PatternInstance `WorkWithPlus*`, derived `*WW`/`*WWDS`/`*LoadDVCombo`/`*WWGetFilterData`, or custom screens `wc*`/`wp*`). The satellite consolidates: regra central (3 elementos), decision tree, estratégia de pacotes faseada, regras de clonagem de instância customizada, and WWP-specific Quality Checklist items. CONSTRAINTS about WWP remain in this `SKILL.md`.

---

## QUALITY CHECKLIST

The end-to-end Quality Checklist for any packaging round lives in the satellite [quality-checklist.md](quality-checklist.md). **Load it before declaring the packaging task complete.** General items (identity, envelope, package collision, manifest, gates) are consolidated there; type-specific checklist items live in `responsibilities-by-type/<type>.md` satellites; WWP-specific items live in `wwp-packaging.md`.

---

## CONSTRAINTS

- NEVER list the workspace and infer the candidate batch before declaring the round spec (object names + types expected in this round); the round spec must come from user intent or front scope — not from what happens to be in the workspace folder
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
- NEVER reserialize, reconstruct, or normalize a whole GeneXus XML object when the task is a surgical change and the source XML can be edited locally; preserve text outside the approved delta
- NEVER use the harness Edit tool as the primary mechanism to change GeneXus object XML with long `Source`, `Rules`, or serialized `CDATA`; NEVER deliver an altered copy whose diff against the source shows material changes outside the declared primary edit block without explicit user approval
- NEVER remove existing comments, alter unrelated `CDATA`, or introduce whitespace-only changes outside the approved delta without explicit user approval
- NEVER deliver locally generated object XML with trailing spaces or tabs introduced on new or modified lines
- NEVER keep the active front batch directly in the root of `ObjetosGeradosParaImportacaoNaKbNoGenexus`; use the front folder `NomeCurto_GUID_YYYYMMDD`
- NEVER create automatic subfolders by type under the active front folder in `ObjetosGeradosParaImportacaoNaKbNoGenexus`
- NEVER create a new front subfolder or change the package base name for another attempt, visual adjustment, or reimport that is still part of the same active front
- NEVER treat a contaminated active front folder as acceptable for a new isolated single-object delta
- NEVER mix a pre-existing parallel change into the package of the current front only because both are present in the same workspace
- NEVER move files to `ArquivoMorto` without explicit user request
- NEVER place a top-level `Attribute` under `<Objects>`
- NEVER serialize a required `Transaction` attribute as `Domain` under `<Objects>` when the package is supposed to create or supply that attribute
- NEVER embed XML declaration text such as `<?xml version="1.0" ...?>` inside `<Objects>` payload of `import_file.xml`
- NEVER postpone generation of `import_file.xml` after the user has already signaled manual IDE import/testing and the delta is materially ready
- NEVER generate `.xpz` by default when manual IDE import is the target flow and `import_file.xml` is sufficient
- NEVER initiate MSBuild export from the KB solely to obtain an XPZ envelope for importing XML that already exists in the parallel folder, unless the user explicitly requests it or confirms that valid `KMW`/`Source`/envelope context cannot be assembled otherwise (see `xpz-msbuild-import-export` for inventory rules on any imported `.xpz`)
- NEVER declare packaging complete without reading `packageInventory` from `Build-GeneXusImportFileEnvelope.ps1` / `New-XpzImportPackage.ps1` when those motors were used, or without equivalent manual inventory on the final `import_file.xml` or `.xpz`
- NEVER report the count of `-ModifiedObjectNames`, front XML files, or conversation-listed objects as the package object count when `packageInventory.totalObjects` differs
- NEVER close a packaging round reporting only `extrasSample`, `totalAttributes`, or conversation memory as the nominal package content when `extrasCount > 0`, `attributesTopLevelUnreconciled=true`, or `systemObjectsPresent` is non-empty — open the sidecar (`nominalInventoryAt` or `*.package-inventory.json`) or re-run `Get-GeneXusImportPackageObjectInventory.ps1` on the final artifact and reproduce the full nominal list to the user first
- NEVER answer later user questions about nominal package content (same round or new session) using only prior chat memory, `extrasSample`, or aggregate counts from the motor JSON — re-read the sidecar when it still exists (path A) or re-run `Get-GeneXusImportPackageObjectInventory.ps1` on the final `import_file.xml` or `.xpz` (path B) before answering
- NEVER assemble `import_file.xml` inline (string concatenation of object XMLs into the envelope, in PowerShell, Bash, or any other shell) when one of the shared engines is available. The shared engines are `scripts/Build-GeneXusImportFileEnvelope.ps1` (for direct object XML inputs with validated template) and the safe wrapper `scripts/New-XpzImportPackage.ps1` (for front-based assembly). Inline assembly diverges from envelope contracts the engines validate (KMW, Source, Dependencies, ObjectsIdentityMapping ordering) and skips embedded gates such as collision and front-vs-acervo coherence (`lastUpdate`/`Object/@type`). The textual fallback path described in WORKFLOW step 15 is allowed only when both engines are demonstrably unusable for the case AND the user has explicitly acknowledged the exception
- NEVER create subfolders by front under `PacotesGeradosParaImportacaoNaKbNoGenexus`; that package area must remain flat
- NEVER change `NomeCurto_GUID_YYYYMMDD` inside the same active front; keep that prefix stable and change only the final `nn` package counter
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
- NEVER write, package, or present a manual correction directly against a pattern-generated derivative (`*General`, `*Selection`, `*WW`, `*WWDS`, `*LoadDVCombo`, `*WWGetFilterData`, or equivalent — to confirm a derivative deterministically rather than by name, the KbIntelligence index materializes `is_generated_object`, see `wwp-packaging.md`) as the primary delta; identify the declarative source and work there instead, such as the pattern parent, PatternInstance, parent object, custom wrapper, or called object
- NEVER start routine analysis from a pattern-generated derivative when the declarative source is known or can be located; read the derivative only for concrete diagnostics such as confirming a build error, generated caller, or runtime artifact
- NEVER assume that a COM_WWP package includes the objects generated by the pattern — verify PatternInstance and derived objects explicitly
- NEVER import a custom instance (`wc*`, `wp*`) without transporting its corresponding `WorkWithPlus*` object
- NEVER re-apply a pattern over a Transaction without reviewing the diff of existing customizations
- NEVER rename an entity with WWP active without checking for attribute collisions that would break the PatternInstance XML
- NEVER silently accept a new `Sub` block in a `Procedure` that diverges strongly from the identified dominant local pattern without showing the 9-PSM architectural alert and recording user acknowledgment or justification in the closing declaration
- NEVER proceed with single-bundle packaging when 9-IDO identified 2 or more topological layers without obtaining explicit user confirmation or justification for the ordering risk
- NEVER treat absence of detected cross-references in 9-IDO as proof that no ordering risk exists when the `Source` scan for Procedure call chains was declared as not fully performed
- ABORT if 9-IDO detects a circular dependency in the batch dependency graph
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
- NEVER package a `Procedure` with a `bc:<X>` variable when Transaction `X` is confirmed as not having `idISBUSINESSCOMPONENT=True` in the batch or in `ObjetosDaKbEmXml`
- ABORT if a `bc:<X>` variable exists in a `Procedure` in the batch and Transaction `X` cannot be confirmed as `idISBUSINESSCOMPONENT=True` either in the batch or in `ObjetosDaKbEmXml`
- NEVER package a `WorkWithForWeb` (`WorkWithWeb*`) object when it is in Form A (packaging form) and the `Apply` property is absent from Part `babfa2b2-19a0-4ef1-b5f4-81b7c7be79dc`. For Form B (acervo form, Part `a51ced48-...` with `<Data Pattern="...">`), `Apply` is implicitly `True` by construction
- NEVER package a `WorkWithForWeb` (`WorkWithWeb*`) object whose XML matches neither Form A (Part `babfa2b2-...`) nor Form B (Part `a51ced48-...` with `<Data Pattern="...">`) — the structure is unrecognizable; **ABORT** with structural error
- ABORT if a `WorkWithForWeb` in the batch has its linked Transaction also in the batch and that Transaction lacks `Apply:78cecefe-be7d-4980-86ce-8d6e91fba04b = True` in its Properties
- NEVER package a `Transaction` when `Test-GeneXusTransactionCoherence.ps1` returned `fail` findings
- ABORT if `Test-GeneXusTransactionCoherence.ps1` returned `warn` findings that have not been reviewed and explicitly justified before packaging
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
