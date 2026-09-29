# v6 — Especificação congelada — correção do motor `Edit-GeneXusXmlSurgical.ps1`

> Documento de especificação (papel) para implementação. Fecha os defeitos 1 e 2, com os gaps das rodadas v1–v5 incorporados. Decisão do humano (2026-09-28): **congelar o design** e transferir a prova para a implementação + self-tests (`15-revisao-por-pares.md`, «Quando o design estabiliza»).

## Estado da implementação — nota aditiva de 2026-09-28

Este bloco é **posterior ao congelamento** e existe porque o corpo abaixo não muda: ele foi escrito antes da implementação e continua sendo o registro do que se decidiu. Quem precisa do estado atual lê aqui.

**Implementado** em `scripts/GeneXusXmlSurgicalEditSupport.ps1` (núcleo), `scripts/Edit-GeneXusXmlSurgical.ps1` (wrapper), `scripts/GeneXusXmlBatchMetadataSupport.ps1` (consumidor das funções descidas) e `scripts/Test-EditGeneXusXmlSurgicalContract.ps1` (bateria). Dono normativo do contrato: `xpz-builder/SKILL.md` (satélites `quality-checklist.md` e `responsibilities-by-type/transaction.md`); regra operacional em `02-regras-operacionais-e-runtime.md`; ponteiro de rastreabilidade em `09-inventario-e-rastreabilidade-publica.md`.

**Desvios declarados frente ao texto congelado** (a prova ficou na implementação):

1. **§4.1 — `return ,$indexes`.** O idioma literal é defeituoso combinado com `@(...)` no chamador: `,` cria um array de um elemento e `@()` não achata (medido: `@(f).Count = 1` para um array de dois). A função devolve o array puro e o chamador materializa com `@(...)`, que então achata corretamente (`[int[]]@(...)`).
2. **§4.4 — derivação de `detectedEol`.** A função descida `Get-GeneXusTextEolProfile` mantém o contrato do lote (`Eol` literal + `Mixed` + contagens) e cai em LF quando não há quebra. Por isso o token (`NONE`/`MIXED`/`CRLF`/`CR`/`LF`) é derivado **pelas contagens**, não por `.Eol`.
3. **§4.1 — consumidor do lote.** `Remove-GeneXusIntervals` e `Get-GeneXusTextEolProfile` desceram verbatim; `Test-GeneXusByteIdentityOutsideMutations` permanece com a assinatura `Tracker` como **adaptador fino** sobre o novo `Test-GeneXusXmlCharIdentityOutsideMutations` (o nome histórico diz «Byte», mas a comparação é de caracteres, Ordinal).
4. **§4.2/§4.5 — BOM.** O motor não detecta BOM; a leitura consome um BOM eventual e a gravação é sempre UTF-8 sem BOM. O teste 27 fixa esse comportamento; detecção de BOM seria capacidade nova.
5. **§4.2 — rollback.** A falha 19 detectada **em memória** (pré-gravação) não tem `.bak` a restaurar (`details.bakPath` nulo). A falha 19 detectada **no arquivo relido** (pós-gravação) restaura o `.bak` e expõe `details.bakPath`, simétrico ao 13.

## 1. Objetivo e escopo

Motor `scripts/Edit-GeneXusXmlSurgical.ps1` (núcleo `scripts/GeneXusXmlSurgicalEditSupport.ps1`): edição textual cirúrgica de XML GeneXus.

**Entra:** defeitos 1 e 2; enumerador único literal; patch indexado; pós-condição por construção (contagem + conteúdo por mutação + strip-both, verificada **na memória e no arquivo gravado**); `catch` mapeado; erro JSON `exitCode`+`details`; `-ApplyToAllOccurrences`; `Replacement ''`; aviso diagnóstico de EOL; testes dos consumidores; paridade de documentação.

**Sai (frente própria em `999`):** `-LineNumber`/`-ExpectedLineText`; o **switch** `-NormalizeAnchorEol`.

## 2. Defeitos (evidência)

- **Defeito 1 (grave).** `-EditMode Replace -ExpectedAnchorCount 2` com âncora 2× → `Support.ps1:245-249` valida a contagem, mas `Invoke-GeneXusXmlLiteralPatch` (`Support.ps1:114`) faz um único `IndexOf` e troca só a 1ª; responde `OK`.
- **Defeito 2.** `-ExpectedAnchorCount 0` com âncora ausente → `ValidateRange(0,100000)` (`Edit-…:63`) aceita, a contagem 0 passa, o primitivo lança `ANCHOR_FAIL`, e o `catch` cego (`Edit-…:184-195`) converte em `INTERNAL_ERROR`/90.

## 3. Decisões congeladas

1. `ExpectedAnchorCount` **só valida**; `-ApplyToAllOccurrences` decide o escopo de aplicação; N>1 sem o switch → **18**.
2. `ExpectedAnchorCount < 1` → **17** (não `ValidateRange`; sem teto superior).
3. Enumeração **não sobreposta, esquerda→direita, literal Ordinal**; contar e gravar usam a mesma lista.
4. O primitivo compartilhado **não** muda de comportamento; o apply-to-all vive num primitivo novo, indexado, só do core.
5. Pós-condição por construção: gate de contagem + **conteúdo por mutação** + **strip-both de caracteres**, verificada na memória (dry-run) e **no arquivo lido de volta** (apply).
6. Erros conhecidos sempre **estruturados** (`code`, `exitCode`, `details`); `INTERNAL_ERROR`/90 só para o inesperado.
7. `code` (string) é o contrato; `exitCode` é **por script**; sem promessa de faixa global livre de colisão.
8. `-LineNumber`/`-ExpectedLineText` e o switch `-NormalizeAnchorEol` ficam para frente própria (`999`).

## 4. Desenho

### 4.1 `GeneXusXmlSurgicalEditSupport.ps1`
- `Get-GeneXusXmlAnchorOccurrenceIndexes` → `[OutputType([int[]])]`, `[int[]]` de retorno **não sobreposto** (avança `Anchor.Length`), literal Ordinal; `-Anchor` vazio → array vazio. Testar âncora ausente pelo enumerador **e** por `Get-AnchorOccurrenceCount`.
- `Get-AnchorOccurrenceCount` → `([int[]]@(Get-GeneXusXmlAnchorOccurrenceIndexes …)).Count` (mesma semântica, sem regex).
- `Invoke-GeneXusXmlIndexedPatch -Text -Anchor -Replacement -EditMode -Indexes` → `{ Text; AppliedIndexes; Mutations = @({ OriginalStart; OriginalLength; FinalStart; FinalLength }) }`. `ValidateSet('Replace','InsertAfter')`; aplica **de trás para frente** com `StringBuilder`; intervalo igual ao lote (`Batch:514-521`): Replace → `OriginalStart=index`, `OriginalLength=Anchor.Length`; InsertAfter → `OriginalStart=index+Anchor.Length`, `OriginalLength=0`; `FinalLength=Replacement.Length`.
- `Remove-GeneXusIntervals` (**nome atual**) + `Test-GeneXusXmlCharIdentityOutsideMutations` (strip-both, Ordinal).
- `Get-GeneXusTextEolProfile` (**nome atual**, descida de `BatchMetadataSupport.ps1:111-156`; regra "qualquer CRLF vence"; expõe `Mixed` + contagens). O lote passa a consumi-la do suporte (já dot-sourceia em `Batch:48`). Remover as definições antigas, sem ciclo.
- `[AllowEmptyString()]`:
  - `Invoke-GeneXusXmlLiteralPatch`: **só no `-Replacement`**. O `-Anchor` do primitivo **não** ganha o atributo — assim nunca ocorre `IndexOf('', 0)` por chamador direto (`Add-GeneXusButton:293`, `Batch:510`).
  - core e wrapper: `-Anchor` **e** `-Replacement`.

### 4.2 `Invoke-GeneXusXmlSurgicalEditCore` — ordem fixa
1. Lê `sourceText`.
2. `-Anchor` vazio (inclusive com `ExpectedAnchorCount 0`) → **27 `ANCHOR_EMPTY`**.
3. `ExpectedAnchorCount < 1` (inclui negativo e 0) → **17**. Sem teto superior.
4. `[int[]]$indexes = @(Get-GeneXusXmlAnchorOccurrenceIndexes …)`; `.Count != ExpectedAnchorCount` → **11** (`details.anchorCount`).
5. `.Count > 1` **sem** `-ApplyToAllOccurrences` → **18** (mensagem: informe a contagem real **e** o switch). O switch **não** relaxa a contagem.
6. Escopo: sem switch → `$indexes[0]`; com switch → todos.
7. No-op: `InsertAfter` + `Replacement ''`, **ou** `Replace` com `Replacement -eq Anchor` em **todos** os pontos → **26 `NOOP_REPLACEMENT`**. (`Replace ''` é remoção válida.) Este passo precede a pós-condição.
8. `Invoke-GeneXusXmlIndexedPatch`; `replacementsApplied = .AppliedIndexes.Count`.
9. Gate (secundário): `replacementsApplied -ne escopoPretendido` → **19**.
10. **Disjunção:** as mutações de âncora têm de ser dois a dois disjuntas (asserção da enumeração; se não → **19**). O bump do `lastUpdate` **não** entra neste conjunto: é mutação própria, reportada em `mutatedIntervals.lastUpdate`.
11. **Pós-condição por mutação** (trata comprimento 0): para cada mutação, o slice no texto final `[FinalStart, FinalStart+FinalLength)` é `== $Replacement` (Ordinal) — slice vazio só é válido quando `FinalLength -eq 0` e `Replacement -eq ''`. Senão → **19**.
12. **Strip-both**: identidade de caracteres fora da união das mutações → senão **19**.
13. `postPatchAnchorCount` no texto final **antes do bump** (diagnóstico).
14. **`lastUpdate`** — com `i0` = índice da 1ª ocorrência de `lastUpdate="` no texto de entrada, `delta_j = FinalLength_j - OriginalLength_j` e `f0` = mapa de `i0` pelas mutações de âncora (soma dos `delta_j` das mutações **inteiramente antes** de `i0`; se uma mutação **cobre** `i0`, o `Replacement` dela tem de conter `lastUpdate="` e `f0` = `FinalStart` + deslocamento interno):
   - (a) `willBump` e fonte sem `lastUpdate` → **12** (fail-fast, como hoje).
   - (b) após o patch, se a 1ª ocorrência no texto patchado **não** estiver em `f0` → **28 `LASTUPDATE_TARGET_MOVED`** (cobre inserção de um `lastUpdate` **antes** do alvo). Se o patch removeu o alvo → **12** (mesmo com `-PreserveLastUpdate`).
   - (c) `-LastUpdateBaselinePath` **só exigido se `willBump`**: `Test-Path -PathType Leaf` → senão **16 `BASELINE_NOT_FOUND`** (`details.baselinePath`), validado **antes** do `Resolve-Path`. Com `-PreserveLastUpdate` e baseline inexistente → **passa**.
   - Relação com o lote: `28` é a versão cirúrgica de `LASTUPDATE_TARGET_OUTSIDE_ROOT` (`edit-genexus-xml-batch-metadata-design.md`); registrar a nota cruzada.
15. Bump; **verificação no arquivo lido de volta**: reler o texto gravado, recomputar o conjunto completo de mutações (âncora + `lastUpdate`) e aplicar passos 11/12 sobre o texto de disco; só então validar well-formedness. Em dry-run, os passos 11/12 rodam sobre o texto em memória. Em falha 13, `details.bakPath`.

### 4.3 Saída
**Sucesso JSON:** + `replacementsApplied`, `postPatchAnchorCount`, `detectedEol`, `sourceEolMixed`, `replacementEolMismatch`, `mutatedIntervals`.
`mutatedIntervals` = `{ anchor: [ { OriginalStart; OriginalLength; FinalStart; FinalLength } ], lastUpdate: { … } | null, total; truncated; limit = 100 }`. Ordem = **ordem do documento**; `anchor[]` limitado aos 100 primeiros; `total`/`truncated` **sempre**; a verificação interna usa a lista **completa**.
**Erro JSON:** `status`,`code`,`message`,`exitCode`,`details` (sempre).
**Humano:** `replacements_applied`, `post_patch_anchor_count`, `detected_eol`, linha de aviso quando `replacementEolMismatch -eq $true`.

### 4.4 EOL (diagnóstico, sem normalizar)
`detectedEol` ∈ {`CRLF`,`LF`,`CR`,`MIXED`,`NONE`} (regra "qualquer CRLF vence"; `Mixed` = há CRLF **e** quebra só-LF e/ou CR solto).
- `Replacement` **sem** quebra → `replacementEolMismatch = false`.
- fonte `Mixed` → `replacementEolMismatch = null` (desconhecido) + `sourceEolMixed = true` + contagens.
- fonte uniforme (CRLF/LF/CR) → `true` se o `Replacement` contém quebra cujo EOL difere da dominante (ou EOL misto); senão `false`.

### 4.5 Wrapper
`[AllowEmptyString()]` em `-Anchor`/`-Replacement`; `-ApplyToAllOccurrences`; remove `ValidateRange(0,100000)`; `.PARAMETER` de todos (incl. "ocorrências literais **não sobrepostas**, esquerda→direita"); tabela de códigos no help; `catch` mapeia prefixos conhecidos (`ANCHOR_FAIL:`/`NO_LASTUPDATE:`/`XML_NOT_WELLFORMED_AFTER:`/`BASELINE_NOT_FOUND:`/`EXPECTED_ANCHOR_COUNT_INVALID:`/`AMBIGUOUS_APPLY_SCOPE:`/`ANCHOR_EMPTY:`/`NOOP_REPLACEMENT:`/`LASTUPDATE_TARGET_MOVED:`/`SELFCHECK_MUTATION_MISMATCH:`) e emite `INTERNAL_ERROR` só para o resto; bootstrap (dot-source) dentro do `try`. Erros de binding antes do corpo → sem JSON: **limitação declarada**.

### 4.6 Tabela de códigos (regra: `code` é o contrato; número por script)
`11 ANCHOR_FAIL` (só cirúrgico), `12 NO_LASTUPDATE`, `13 XML_NOT_WELLFORMED_AFTER`, `14 INPUT_NOT_FOUND`, `15 OUTPUT_DIR_MISSING`, `16 BASELINE_NOT_FOUND` (alinhado a `Set-GeneXusXmlLastUpdate`; divergência preexistente com o 16 do botão, declarada), `17 EXPECTED_ANCHOR_COUNT_INVALID`, `18 AMBIGUOUS_APPLY_SCOPE`, `19 SELFCHECK_MUTATION_MISMATCH`, `26 NOOP_REPLACEMENT`, `27 ANCHOR_EMPTY`, `28 LASTUPDATE_TARGET_MOVED`, `90 INTERNAL_ERROR`. Consumidor compara **`code` string**, nunca o número. (Grep confirma: 26/27/28 livres em `scripts/`.)

### 4.7 Quebras (CHANGELOG PT/ES/EN) — quatro
1. `ExpectedAnchorCount > 1` sem `-ApplyToAllOccurrences` deixa de responder `OK` → **18**.
2. `-Replacement ''` deixa de ser erro de binding → **remoção** funcional.
3. `-Anchor ''` deixa de ser erro de binding → **27**.
4. `ExpectedAnchorCount < 1` (ex.: `0`) → **17** (antes: `ANCHOR_FAIL`/90 conforme a âncora), e some o teto do `ValidateRange` (ex.: `100001` antes era erro de binder; agora conta real decide → 11).
Regex→ordinal **não** é quebra (refactor equivalente, provado por teste).

## 5. Testes (`Test-EditGeneXusXmlSurgicalContract.ps1`)
Harness `Invoke-SurgicalScript` tolerante a stdout não-JSON (erros de binding/bootstrap): preservar `Raw` + `exitCode` em `try/catch`, sem engolir `stderr`.
Base 1–8 + : (1) Replace 2× +switch → 2, **texto final exato**; (2) Replace 2× sem switch → 18, arquivo **byte-idêntico** (apply e dry-run); (3) InsertAfter 2× ± switch; (4) count 0/negativo → 17; (5) âncora ausente default → 11, pelo público **e** pelo enumerador; (6) `-Anchor ''` → 27 (inclusive com count 0); (7) `R>0`; (8) emenda `abb`/`ab`→`a`; (9) sobreposição `aa`/`aaa` (count 1 OK, 2 → 11); (10) âncora sobre o `lastUpdate` (mantendo o token → OK); (11) âncora que remove `lastUpdate` → 12; (12) `Replace ''` remoção; (13) `InsertAfter ''` → 26; (14) `Replace` idêntico → 26; (15) CRLF multilinha + `Replacement` LF → `replacementEolMismatch=true`; (16) `Mixed` → `null` + `sourceEolMixed=true`; (17) `Replacement` sem quebra → `false`; fonte só-CR; (18) dry-run paridade; (19) `mutatedIntervals` = delta real + `truncated/total`; (20) baseline inexistente → 16; baseline diretório → 16; `-PreserveLastUpdate` + baseline inexistente → passa; (21) `OutputPath` dir ausente → 15; `InputPath` ausente → 14; (22) limites offset 0/último; (23) replay `a`→`aa`; (24) `ApplyToAll` sem `ExpectedAnchorCount` 2 → 11; (25) `InsertAfter` inserindo `lastUpdate` anterior → 28; (26) metachars de regex/case/zero-width (equivalência de contagem); (27) BOM na entrada; (28) `mutatedIntervalsTruncated` com N grande; (29) `ExpectedAnchorCount` gigante → 11; (30) esquema JSON; (31) `.bak` após erro 13 com `details.bakPath`; (32) pós-condição no arquivo lido de volta (apply); (33) consumidores: `Add-GeneXusButton` (unicidade via `Get-AnchorOccurrenceCount`), `Test-EditGeneXusXmlBatchMetadataContract` (remoção `''`), `Test-GeneXusLastUpdateEngineOptionalBaselineSelfTest`.

## 6. Documentação
`xpz-builder/SKILL.md` (`:84`, `:95`); `examples/Edit-GeneXusXmlSurgical.example.ps1`; `02:202`/`:1497`; `08:901`/`:952`; `xpz-msbuild-build/SKILL.md:308`; `quality-checklist.md:27`; `transaction.md:110`; `09:108` (uma linha); `edit-genexus-xml-batch-metadata-design.md` (reconciliação §6 e §718 + nota de `28` vs `LASTUPDATE_TARGET_OUTSIDE_ROOT` + dono das funções descidas); `CHANGELOG.md` PT/ES/EN (quatro quebras); `999` (frente de `-LineNumber`/switch de EOL + lote de `Source`, tensão de EOL); `README.md` declarado sem mudança.

## 7. Varredura de consumidores (executar e trazer o resultado antes do push)
Repo interno: `Edit-GeneXusXmlSurgical`, `Add-GeneXusButton:293`, `Set-GeneXusXmlLastUpdate`, `GeneXusXmlBatchMetadataSupport:48/510`, `Test-GeneXusLastUpdateEngineOptionalBaselineSelfTest:21`. Pastas paralelas (leitura de fora): chamadores de `Edit-GeneXusXmlSurgical.ps1` e usos de `ExpectedAnchorCount > 1` / `== 0`.

## 8. Registro de congelamento
Decisão humana de 2026-09-28: encerrar o ciclo de papel (v1–v5, revisores: opencode `meta`/`stealth`, Claude Code `claude-opus-5`; GPT indisponível por limite de uso) e **transferir a prova para a implementação + self-tests**. Estado da v6 (congelada): **`resubmissionDeclinedByHuman`**, motivo "prova transferida para implementação/self-test". Isto **não** é convergência: a v6 não foi revisada pelo painel; é o encerramento auditado do ciclo de design.
