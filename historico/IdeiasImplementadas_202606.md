# Ideias Implementadas

Registro de ideias que sairam de `999-ideias-pendentes.md` por terem sido implementadas ou incorporadas ao contrato metodologico vigente.

## Colisão cross-fluxo moderno↔legado na materialização do acervo (export legado GeneXus 9)

**Importância original:** baixa (caso raro, limite conhecido declarado; sem perda silenciosa no fluxo normal de uma única KB).
**Status:** implementada em 2026-06-25 — detecção fail-soft + bloqueio opt-in (escopo (b)).

### Origem

`scripts/Sync-GeneXusXpzToXml.ps1` materializa cada item em `<FolderType>/<NormalizedName>.xml` e o `Write-ItemToDestination` ignorava o `dataSource`: se o **mesmo** objeto fosse materializado primeiro por um export **moderno** e depois por um **legado GeneXus 9** (ou vice-versa) na mesma pasta/nome, o segundo sobrescrevia o primeiro silenciosamente por `lastUpdate`, ainda que os envelopes diferissem (`dataSource="gx-legacy-export"` + `GxLegacyPayload` + `guid=""` no legado vs envelope moderno). Distinto do fail-closed de pacote **misto** (dentro de um único `ExportFile`); esta colisão é **entre execuções de sync**. Deferido na Fase 2 (manuscrito §9: documentar, não tratar); tratado agora.

### Implementação

- **`scripts/Sync-GeneXusXpzToXml.ps1`** — nova função `Get-GeneXusCrossFlowDataSourceCollisions` (compara o `dataSource` do nó entrante com o do arquivo já materializado, parse encoding-aware `XmlDocument.Load`; **Decisão E.2** — na ausência do atributo, o filho direto `<GxLegacyPayload>` é sinal de legado, `guid=""` só corrobora; parse-falho → warning fail-safe, **Decisão G**); helper `Resolve-ItemDestinationPath` (path único reusado por `Write-ItemToDestination`); orquestrador `Invoke-GeneXusCrossFlowDetection` (agrega warnings; sob `-Block` + colisão emite `CROSSFLOW_BLOCKED_ERRORID:` no stderr e um terminating error `ErrorId=CrossFlowDataSourceCollisionBlocked`). Campos aditivos `Summary.CrossFlowCollisions` (stdout) + `Writes[].CrossFlowCollision` (`-ReportPath`); mitigação stderr universal JSONL (`CROSSFLOW_COLLISION:`/`CROSSFLOW_WARNING:`). Switch `-BlockCrossFlowDataSource` (opt-in). **`SchemaVersion` mantém `1`** (aditivo; varredura de consumidores: o único molde que lê o JSON, `Update-KbFromXpz.example.ps1`, acessa por nome). Ramo **moderno** reordenado (`catálogo → unknown → Convert → detecção → metadata`): os fail-closed de tipo desconhecido e intra-pacote passam a **pré-metadata**; o rename `-FullSnapshot` segue **pós-metadata** (assimetria declarada).
- **`scripts/Test-XpzSyncCrossFlowCollisionSelfTest.ps1`** (novo) — token `GENEXUS_XPZ_SYNC_CROSSFLOW_SELFTEST_OK`; processo filho; cobre fail-soft, `-Block` com atomicidade de metadata, `-VerifyOnly`, E.2, não-parseável e o booleano por-item. Self-tests existentes do Sync (KbMetadata/GuidRename/LegacyFullSnapshot) seguem verdes (sem regressão).
- **Paridade:** `02`, `08`, `09`, `xpz-sync/SKILL.md`, `01k`, `CHANGELOG.md`.

### Decisão final

Plano **congelado por revisão por pares** (v1→v16, 5 vozes / 3 famílias: anthropic nativo, openai/Codex gpt-5.5, ollama-cloud deepseek-v4-pro/glm-5.2/kimi-k2.7-code). A v15 atingiu **4/5 CONVERGE**; os gaps remanescentes eram puramente redacionais/de implementação (revisores "coder" geram redação inesgotável sobre o papel), e o design foi **congelado por decisão humana** (`resubmissionDeclinedByHuman`, motivo "prova transferida para implementação/self-test"). Limitações residuais declaradas: legado depositado à mão sem nenhum sinal (Decisão E) e XML não-parseável tratado como moderno sob `-Block` (Decisão G). Derivada do fechamento do **Motor de export legado GeneXus 9**.

### Rastreabilidade

- Arquivos: `scripts/Sync-GeneXusXpzToXml.ps1`, `scripts/Test-XpzSyncCrossFlowCollisionSelfTest.ps1`, `02`, `08`, `09`, `01k`, `xpz-sync/SKILL.md`, `CHANGELOG.md`, `999-ideias-pendentes.md` (entrada removida → esta).
- Revisão por pares: livro-razão em `Temp/` (`xpz-crossflow-v1.txt`…`v16.txt`, gitignored).
- Commit: `1d3f126` (implementação da frente); ajustes da revisão pré-push reforçada nos commits seguintes.

## Descoberta documental do switch `-BlockCrossFlowDataSource` e da colisão cross-fluxo no `xpz-sync/SKILL.md`

**Importância original:** baixa (descoberta/conveniência; não-gap).
**Status:** implementada em 2026-06-27 — dois acréscimos documentais no `xpz-sync/SKILL.md`, sem mudança de código.

### Origem

Entrada do `999-ideias-pendentes.md` levantada pelo revisor `ollama-cloud/kimi-k2.7-code` na revisão pré-push reforçada da frente-mãe «Colisão cross-fluxo moderno↔legado» (acima). O switch `-BlockCrossFlowDataSource` e os campos `CrossFlowCollisions`/`Writes[].CrossFlowCollision` já estavam no **workflow** (interpretação de resultado) do `xpz-sync/SKILL.md` e nas bases, mas duas seções de descoberta do próprio `SKILL.md` não tinham sido tocadas — reduzindo a descoberta do recurso por um agente que consultasse só elas.

### Implementação

- **`xpz-sync/SKILL.md` (a)** — na lista "Wrapper de atualização diária" (antes de `-NoGitSummary`): linha do `-BlockCrossFlowDataSource` *(switch, opt-in)* + duas notas — fail-soft **não introduz gate adicional** (a colisão é só registrada; a materialização segue a regra de `lastUpdate`), e switch do **motor compartilhado** eventualmente não repassado pelo wrapper local (mesma postura de `-ExpectedItems`).
- **`xpz-sync/SKILL.md` (b)** — na seção "EXPORTS LEGADOS (GeneXus 9)": bullet de **colisão cross-fluxo** quando o mesmo `FolderType|NormalizedName` já existe no acervo como **moderno**, com cross-reference ao "Wrapper de atualização diária" e à interpretação de resultado.
- **Sem mudança de código.** Bases (`02`/`08`/`01k`/`09`/`CHANGELOG`) já cobriam o switch/campos — sem ajuste adicional (confirmado na revisão pré-push e pelo painel).

### Decisão final

Validada por **revisão por pares** (manuscrito v1→v4, 3 famílias: `openai`/Codex gpt-5.5, `anthropic`/Claude Opus 4.8 nativo, `nvidia` glm-5.1/kimi-k2.6/minimax-m2.7). Codex revisou v1→v2 (núcleo); o dissidente kimi-k2.6 percorreu v2→v3→v4 e **concordou na v4**; minimax-m2.7 confirmou a v4. Design **declarado estável por decisão humana** (`resubmissionDeclinedByHuman`, motivo "delta v2→v4 puramente redacional; núcleo aprovado por 3 famílias na v2; full-panel sobre v4 dispensado"). Não é convergência plena no sentido forte da régua.

### Rastreabilidade

- Arquivos: `xpz-sync/SKILL.md`, `999-ideias-pendentes.md` (entrada removida → esta).
- Revisão por pares: livro-razão em `Temp/revisao-por-pares/20260626-224728-blockcrossflow/` (manuscrito v1→v4 + prompts, gitignored).
- Commit: `07acfa2` (acréscimos na `SKILL.md`) + `dd2f866` (esta migração 999→histórico).

## Forma canônica de invocação dos adapters documentada (resíduo (b1) do item URGENTE)

**Importância original:** alta (atrito operacional recorrente; resíduo (b1) do item URGENTE «Reduzir as variações de chamada dos adapters de delegação»).
**Status:** concluída em 2026-06-22 (documentação (b1)). (b2 = enxugar allowlist) segue como resíduo opcional/local no `999`.

### Origem

Resíduo (b) do item URGENTE do `999` (a parte (a) `-MessagePath` foi concluída antes — ver a entrada própria «`-MessagePath` estendido aos adapters…»). (b1): a convenção de invocação só vivia na memória pessoal de um agente; o repo serve vários (Claude Code, Codex, Cursor, OpenCode), então a forma canônica tem que morar onde **todo** agente lê.

### Implementação

- **`xpz-llm-delegate/SKILL.md`** — nova seção `## Forma canônica de invocação dos adapters`, ao final do bloco `## SCRIPTS` (antes de `## MANUSCRITO/PROMPT PARA REVISORES`): princípio atômico + `-MessagePath` (zero aspas embutidas); **forma por ferramenta** (Bash com path relativo `pwsh -NoProfile -File scripts/<Adapter>.ps1 …` casando `Bash(pwsh -NoProfile -File scripts/*)`; PowerShell fallback com path absoluto `& "<abs>\scripts\<Adapter>.ps1" …` casando `PowerShell(& "<repo>\scripts\*" *)`; o call-operator `&` com path relativo **não** é coberto); síncrono `Invoke-*` vs jobs `Start-*Job` existentes (`-TimeoutSec` só nos síncronos); `-Cd` só nos adapters que o suportam (opencode não tem); ressalva ~32KB (cross-ref) — `-MessagePath` tira a substituição inline no chamador em todos, mas só os stdin-based escapam do teto, argument-based (Gemini/Copilot) mantêm o teto com guard de 30000 chars; o caso real de 2026-06-21 com a causa correta (aspas embutidas quebrando o match literal, **mesma família** PowerShell, não descasamento de ferramenta); nota não-normativa do padrão de allowlist.
- **`AGENTS.md`** — nova seção `## Invocação dos adapters de delegação` (forma canônica condensada + ponteiro ao SKILL.md) + bullet de paridade na seção «Alinhamento entre documentos».
- **`CHANGELOG.md`** — entrada trilíngue (Unreleased).

### Decisão final

(b1) é o entregável **durável e cross-agente**; (b2) enxugar a allowlist é housekeeping **local** (`.claude/settings.json`/`settings.local.json` são git-ignored, máquina-local) e fica como resíduo opcional no `999` — **(b1) elimina a deriva na origem, tornando (b2) praticamente opcional**. Plano convergido por **revisão por pares** (v1→v4): painel multi-família — anthropic nativo, openai/Codex gpt-5.5, ollama-cloud deepseek-v4-pro/glm-5.2 — convergiu em zero gaps de conteúdo sobre a v4; a voz nvidia/kimi-k2.6 entrou tarde (leu o working tree já editado por sessão paralela) e o preferido ollama `kimi-k2.7-code` foi excluído por decisão humana (flakiness/truncagem, Achado D). Correção-chave entre versões: a causa-raiz do incidente de 2026-06-21 é **aspas embutidas** quebrando o match literal (mesma família PowerShell), **não** descasamento de ferramenta (achado da voz anthropic nativa, ratificado contra `999:35`).

### Rastreabilidade

- Arquivos: `xpz-llm-delegate/SKILL.md`, `AGENTS.md`, `CHANGELOG.md` (trilíngue), `999-ideias-pendentes.md` (entrada URGENTE → resíduo (b2)).
- Revisão por pares: livro-razão em `Temp/peer-review-adapters-canonico/` (gitignored).
- Rastreabilidade: ver o commit de fechamento desta frente (forma canônica + CHANGELOG trilíngue + migração da entrada do `999`).

## Harness `Invoke-LlmDelegatePanelDispatch.ps1` (frente A) — disparo+coleta do painel de revisão por pares

**Importância original:** média-alta (o «harness de disparo do painel» previsto como futuro em `15-revisao-por-pares.md:94`; a orquestração da revisão por pares era ad-hoc).
**Status:** concluída e pushada em 2026-06-22 (`origin/main` em `2e88905`).

### Origem

Entrada do `999` "Implementar `Invoke-LlmDelegatePanelDispatch.ps1` (frente A)". Design congelado em `Temp/revisao-por-pares/panel-v11/manuscrito.md` (gitignored), convergido por **revisão por pares** (painel inteiro, 3 famílias: anthropic nativo, openai/Codex gpt-5.5, ollama-cloud deepseek-v4-pro+kimi-k2.7-code; 4 aprova / zero gaps sobre a v11, incluindo o dissidente Codex, que achou o gap P1 da circularidade do `$effectiveModel` do opencode na v10 e reaprovou na v11).

### Implementação

- `scripts/Invoke-LlmDelegatePanelDispatch.ps1` — harness **MECÂNICO**: por revisor resolve o modelo efetivo (+ fail-closeds por backend), roda o gate `Resolve-LlmDelegateAuthorization.ps1` sem autorizar, despacha os `allow` aos adapters `Invoke-*.ps1` em paralelo (`ForEach-Object -Parallel -ThrottleLimit 8` + `SemaphoreSlim($OllamaConcurrency)` via `$using:` só para `ollama-cloud/*`; `$collected` capturado antes do `Dispose`), classifica de forma estrutural (texto→`responded`; cota→`unavailable`; timeout→`timeout`; resto→`error`) e emite `panel-summary.json` (1 linha de stdout, `Kind`/`SchemaVersion` PascalCase, UTF-8 sem BOM, texto humano por `[Console]::Error`) + `manifest.json` + ledger por estado. Contenção per-backend recusada em `securityBlockedArgs` (Posição B); opencode só-`public` no v1; `-Cd` precedência+fail-closed (opencode nunca recebe `-Cd`); single-flight diferido; NÃO injeta nativo/piso/closeout/triagem/convergência (do orquestrador).
- `scripts/Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1` (token `OK: Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1`) — fake-exe por backend via `-BackendExeMap` no adapter REAL + gate dirigido por config/política sintéticas; cobre modelo efetivo + fail-closeds, gate codex com oss, gate que lança, opencode-kb→unavailable, splat+contenção, paralelismo (ocupação ≤OllamaConcurrency, outros livres, bloco que lança não aborta, OllamaConcurrency=0→validação), sem single-flight, classificação mecânica, cota→unavailable, timeout→timeout, ollamaQuotaWarning, despacho real de claude-code/copilot/gemini, `-Cd` e o contrato.
- Paridade: `09-inventario-e-rastreabilidade-publica.md` (ponteiro + self-test), `xpz-llm-delegate/SKILL.md` (SCRIPTS + seção «Harness de disparo do painel» com o split orquestrador↔harness e as decisões), `15-revisao-por-pares.md` (futuro→implementado), `08-guia-para-agente-gpt.md`, `CHANGELOG.md` (trilíngue), `999` (entrada→ponteiro).

### Decisão final

Decisões fechadas da v11: **I-a** (`ForEach-Object -Parallel`, NÃO `ThreadJob` — ausente na máquina); **II-b** (single-flight diferido); contenção fora da allowlist = **Posição B** (decisão de segurança); opencode **só-`public`** no v1; **NÃO** refatorar os 6 adapters (status tipado é frente própria). A **implementação** também passou por revisão por pares: v1 (4 aprova / 1 revisa por cobertura de self-test) → **v2 endurecida** (family no fail-closed do codex; bloco FOP inteiro em `try/catch` com `[void]` no `Release` — que pegou um **bug real** de int vazando para `$collected`; cobertura de cota/timeout/quota + despacho dos 3 backends restantes) → painel inteiro convergiu em **zero gaps sobre a v2**, dissidente Codex reaprovou; closeout `closeoutReady=true`, `vNextState=resubmitted`; kimi-k2.7-code = `noResponse` (off-task, família coberta por glm+deepseek).

### Rastreabilidade

- Arquivos: `scripts/Invoke-LlmDelegatePanelDispatch.ps1` (novo), `scripts/Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1` (novo), `09`, `15`, `08`, `xpz-llm-delegate/SKILL.md`, `CHANGELOG.md`, `999`.
- Commit: `2e88905` (pushado no bundle `52db98b..2e88905`, junto da frente `-MessagePath` `4f3ccf1`/`f946ac6`).
- Revisão por pares (design v6→v11 + implementação v1→v2): livro-razão em `Temp/revisao-por-pares/panel-v11/` e `Temp/revisao-por-pares/impl-A/` (gitignored).
- Resíduos abertos no `999`: «contrato de saída estruturado dos adapters» (consumidor do single-flight automático) e «agente reviewer sem execução/escrita» (confinamento do opencode).

## `-MessagePath` estendido aos adapters de delegacao restantes (Codex/ClaudeCode/Gemini/Copilot) + guard de tamanho

**Importancia original:** alta (atrito operacional recorrente: despacho de adapter com prompt grande disparava prompt de autorizacao em toda sessao, atrasando o usuario)
**Status:** concluida em 2026-06-22 (eixo `-MessagePath` + guard de tamanho). Residuos seguem no `999`.

### Origem

Duas entradas do `999`: "URGENTE — Reduzir as variacoes de chamada dos adapters de delegacao" (direcao (a)) e "Migrar Invoke-Gemini/Invoke-Copilot para stdin e/ou guard de tamanho" (direcao (b) guard). Problema-raiz sofrido por meses: a allowlist do harness casa comandos **atomicos**; despachar um adapter com prompt grande exigia `-Message (Get-Content -Raw '<arq>')` inline -> comando composto -> prompt de autorizacao toda vez. O `Invoke-OpenCode.ps1`/`Start-OpenCodeJob.ps1` ja tinham `-MessagePath` (referencia pronta).

### Implementacao

- **`-MessagePath` (ParameterSet `Inline`/`FromFile` exclusivo, `Get-Content -LiteralPath -Raw -Encoding utf8` + guarda `Test-Path -LiteralPath -PathType Leaf`, espelhando `Invoke-OpenCode.ps1:61-89`)** em: `Invoke-Codex.ps1`, `Start-CodexJob.ps1`, `Invoke-ClaudeCode.ps1`, `Start-ClaudeCodeJob.ps1` (stdin-based) e `Invoke-Gemini.ps1`, `Invoke-Copilot.ps1` (argument-based). Nos `Start-*Job`, `$Message` e populado **antes** de montar `request.json`/`stdin.txt`. Aditivo, default inalterado.
- **Guard de tamanho fail-closed** nos argument-based (`$MaxArgvPromptChars = 30000`, heuristico em chars/UTF-16 code units, margem sob ~32767, cobre `-Message` e `-MessagePath`): o prompt segue no argv via runner, entao `-MessagePath` **nao** levanta o teto ~32KB; o guard recusa prompts grandes com `BLOCK` antes do `Argument list too long`.
- **Self-test** `Test-LlmDelegateStdinHandlingSelfTest.ps1` estendido (nao recriado — ja provava `-MessagePath` no opencode, caso C): guard estatico por tokens independentes nos 6 adapters + asercao do guard de tamanho; prova comportamental dedicada de `-MessagePath` no `Invoke-Codex` (fake-exe via `-CodexExe` escrevendo texto bruto no `-o output-last-message`, cadeia `-MessagePath -> $Message -> stdin -> -o -> return`).
- **Paridade:** `09-inventario-e-rastreabilidade-publica.md` (6 ponteiros + entrada do self-test), `xpz-llm-delegate/SKILL.md` (assinaturas SCRIPTS + secoes anti-hang stdin e limite 32KB), `CHANGELOG.md` (entrada trilingue), `999` (entradas encolhidas aos residuos).

### Decisao final

Escopo expandido para incluir os adapters Claude Code (achado de Codex/glm na revisao): a fricca de chamador e identica a do Codex. Convergido por **revisao por pares** (4 rodadas v1->v4, 5 revisores / 3 familias: anthropic nativo, openai/Codex gpt-5.5, ollama-cloud deepseek-v4-pro/glm-5.2/kimi-k2.7-code; v4 aprovada 5/5; redesenho do teste comportamental do Codex e guard de tamanho = achados do glm). **Residuos:** (b1) documentar a forma canonica de invocacao — **concluido** (ver a entrada propria «Forma canônica de invocação dos adapters documentada»); (b2) enxugar a allowlist = housekeeping **local** (git-ignored), opcional, segue no `999`; a migracao **stdin real** de Gemini/Copilot segue aberta no `999` (bloqueada por falta de assinatura para validar).

## `.ContainsKey` sobre `OrderedDictionary` quebrava o pos-processamento do BuildAll/SpecifyGenerate sob StrictMode

**Importancia original:** alta (nao corrompia o build, mas mascarava um resultado limpo como falha e empobrecia o diagnostico)
**Status:** concluida em 2026-06-21

### Origem

Caso real em 2026-06-17 (KB `FabricaBrasil18`, environment `.NET Core`): BuildAll concluiu limpo (`msBuildExitCode=0`, `__BUILDALL_DONE__=true`), mas o pos-processamento lançou excecao e degradou o JSON para `status=compilou limpo com falha no pos-processamento` com `postProcessingError`. Entrada registrada como URGENTE no `999`.

### Problema concreto

- `scripts/GeneXusKbDeployBinSupport.ps1:482` chamava `.ContainsKey('sentinelFreshSinceBuild')` sobre `$freshness.binCheck`, um `[ordered]@{}` (`:336`, repassado em `:476`). Sob `Set-StrictMode -Version Latest` (`:14`), `OrderedDictionary` nao expoe `.ContainsKey` (so `.Contains`) — erro de runtime no ramo `status='fresh'` (publicacao .NET Core fresca).
- A excecao **nao** era tratada pelo catch interno `:1962` (esse fecha o try de eventos pos-build/hashes); a chamada deploy-bin esta em `Invoke-GeneXusKbBuildAll.ps1:2016`, dentro do try externo de `:695`, e a excecao caia no catch externo `:2206`, que define `status='compilou limpo com falha no pos-processamento'` (`:2208`) + `postProcessingFailed` (`:2234`). Ponteiros do `999` original (catch `:1962`, consumo `:1845-1873`) estavam imprecisos.
- **Segundo consumidor:** `Invoke-GeneXusKbSpecifyGenerate.ps1:1533` chama a mesma funcao (mesmos params, `-OperationLabel 'SpecifyGenerate'`); catch analogo em `:1716`.
- **Bug latente irmao (Fix B), achado na revisao:** `Add-GeneXusKbDeployBinPublicationFieldsToBinCheck` declarava `[hashtable]$BinCheck` (`:250`), mas o unico call site (`:357`) passa o `[ordered]@{}` — passar `OrderedDictionary` a parametro `[hashtable]` **cria copia**, entao os 11 campos de publicacao (`:254-264`) nunca chegavam ao `binCheck` reportado. O `msbuild-exit-codes.catalog.json` (exit 49) ja prometia `publicationFreshSinceBuild`/`objectDllMaxWriteTime`/`configMaxWriteTime` em `jsonHints` — campos suprimidos pelo bug.

### Implementacao

- **Fix A:** `.ContainsKey('sentinelFreshSinceBuild')` -> `.Contains('sentinelFreshSinceBuild')` em `GeneXusKbDeployBinSupport.ps1:482`.
- **Fix B:** `[hashtable]$BinCheck` -> `[System.Collections.IDictionary]$BinCheck` em `:250` (aceita `OrderedDictionary` por referencia, preserva ordem). Call site unico — sem regressao.
- Self-test novo `scripts/Test-GeneXusDeployBinClassificationSelfTest.ps1` (token `GENEXUS_DEPLOY_BIN_CLASSIFICATION_SELFTEST_OK`): KB temporaria `dotnet-core-self-host`, timestamps fixados via `LastWriteTime`, asserçoes sobre `deployBinCheck.binCheck` (publicacao + sentinela) e `warnings`. Falha sem Fix A (lança) e sem Fix B (campos de publicacao ausentes).
- Varredura repo-wide: `:482` e o unico `.ContainsKey` sobre `[ordered]`; `.ContainsValue`=0; `.Remove`/`.Add` existem em `OrderedDictionary` (seguros; ex.: `GeneXusMsBuildWatcherSupport.ps1:174`).
- Paridade: `CHANGELOG.md` (Unreleased), `09-inventario-e-rastreabilidade-publica.md:189` (self-test + token). `xpz-msbuild-build/SKILL.md`, `02`/`08` e o catalogo de exit codes conferidos sem necessidade de edicao (o catalogo ja prometia os campos; o fix alinha a saida ao contrato).

### Decisao final

A+B na mesma frente (o self-test so e significativo travando os dois). No Fix B, trocou-se o **tipo do parametro** em `:250` para `[System.Collections.IDictionary]` em vez de trocar o `[ordered]@{}` de `:336` por `@{}` (alternativa que resolveria igual, mas mudaria a ordem das chaves do diagnostico); `:336` permanece `[ordered]@{}`. A ordem das chaves e decisao editorial, nao contrato travado por teste.

### Rastreabilidade

- Arquivos: `scripts/GeneXusKbDeployBinSupport.ps1` (`:250`, `:482`), `scripts/Test-GeneXusDeployBinClassificationSelfTest.ps1` (novo), `CHANGELOG.md`, `09-inventario-e-rastreabilidade-publica.md`.
- Commit: `bd2abb8` (`Corrige .ContainsKey sobre OrderedDictionary no pós-processamento do deploy-bin`).
- Revisao por pares: 5 versoes / 4 vozes / 3 familias (livro-razao em `Temp/revisao-por-pares/contains-key-fix/`).

## Unificar `Get-Utf8NoBomEncoding` repo-wide

**Importancia original:** baixa
**Status:** concluida em 2026-06-04

### Origem

Frente combinada 2026-05-25 (Parte C). O escopo conservador daquela frente tinha limitado a padronizacao de UTF-8 sem BOM ao sidecar `package-inventory.json`, deixando a higiene repo-wide registrada em `999-ideias-pendentes.md`.

### Problema concreto

Scripts PowerShell da raiz gravavam texto em UTF-8 sem BOM por padroes locais diferentes: funcoes `Get-Utf8NoBomEncoding` duplicadas, funcao especifica de inventario de environment, construtores inline `[System.Text.UTF8Encoding]::new($false)` e `New-Object System.Text.UTF8Encoding($false)`.

### Implementacao

- `scripts/Utf8NoBomEncodingSupport.ps1`: novo suporte compartilhado com `Get-Utf8NoBomEncoding`.
- Scripts em `scripts/*.ps1` que faziam escrita simples em UTF-8 sem BOM passaram a carregar o suporte compartilhado e chamar `Get-Utf8NoBomEncoding`.
- Casos de leitura/deteccao de encoding, BOM deliberado ou validacao estrita de bytes permaneceram inline, porque usam semantica diferente de escrita simples sem BOM.
- `02-regras-operacionais-e-runtime.md` e `09-inventario-e-rastreabilidade-publica.md` passaram a registrar o contrato para novas manutencoes.

### Decisao final

A trilha adotou helper compartilhado em vez de manter duplicacao local ou padronizar apenas por estilo inline. A regra futura e reutilizar `scripts/Utf8NoBomEncodingSupport.ps1` para escrita simples em UTF-8 sem BOM e reservar construtores inline de `UTF8Encoding` para casos semanticamente especiais.

### Rastreabilidade

- Commit: `95cf6d8` (`Centraliza codificacao UTF-8 sem BOM`)

## Detecção robusta de eventos pós-build por marcador de fase

**Importancia original:** baixa
**Status:** concluida em 2026-06-04

### Origem

Ideia levantada em 2026-05-12 como evolução natural do tratamento de eventos pós-build introduzido na frente de filtro de ruído GAM/NetCore.

### Problema concreto

A detecção de eventos pós-build em `Invoke-GeneXusKbBuildAll.ps1` e `Invoke-GeneXusKbSpecifyGenerate.ps1` usava regex enumerativa para linhas `start c:` / `start cmd`, com ou sem `REM`. Isso cobria os formatos vistos, mas deixava invisíveis comandos pós-build com formatos novos, como `call`, `cmd /k`, `powershell` ou comando direto sem `start`.

### Implementacao

- `scripts/GeneXusMsBuildPostBuildEventsSupport.ps1`: novo suporte compartilhado para extrair `postBuildEvents`.
- `scripts/Invoke-GeneXusKbBuildAll.ps1` e `scripts/Invoke-GeneXusKbSpecifyGenerate.ps1` passaram a usar a janela iniciada por `Executando eventos pos-construcao ...` e encerrada pelo próximo separador `==========`.
- A regex histórica para `start c:` / `start cmd` permanece como fallback quando o marcador de fase não existe no log.
- `scripts/Test-GeneXusMsBuildPostBuildEventsSupportSelfTest.ps1` cobre comandos `start`, `call`, `cmd /k`, `powershell`, `REM` e fallback legado.
- `02-regras-operacionais-e-runtime.md` e `xpz-msbuild-build/SKILL.md` foram atualizados para documentar a janela por marcador e o fallback.

### Decisao final

A trilha adotou detecção por fase como caminho preferencial, sem remover compatibilidade com a regex antiga. Assim o wrapper cobre formatos futuros observados dentro da fase pós-build e evita regressão em logs antigos ou variantes que ainda não emitam o marcador.

### Rastreabilidade

- Commit: `be4ac59` (`Detecta eventos pos-build por janela MSBuild`)

## Gate para opções caras de build (`CompileMains=true` / `DetailedNavigation=true`)

**Importancia original:** baixa
**Status:** concluida em 2026-06-05

### Origem

Ideia levantada em 2026-05-13 durante a frente que introduziu o gate de
`-ForceRebuild=true` em `Invoke-GeneXusKbBuildAll.ps1` e
`Invoke-GeneXusKbSpecifyGenerate.ps1`.

### Problema concreto

`CompileMains=true` compila também objetos Main além do Developer Menu.
`DetailedNavigation=true` executa navegação detalhada durante a especificação. Essas
opções não equivalem a `Rebuild All`, mas podem ampliar bastante o custo de uma
validação cotidiana em KB grande.

### Implementacao

- `Invoke-GeneXusKbBuildAll.ps1`: bloqueia `CompileMains=true` e
  `DetailedNavigation=true` sem `-AllowCostlyBuildOptions`.
- `Invoke-GeneXusKbSpecifyGenerate.ps1`: bloqueia `DetailedNavigation=true` sem
  `-AllowCostlyBuildOptions`.
- `Invoke-GeneXusXpzImportThenBuild.ps1`: propaga `-AllowCostlyBuildOptions` e
  `-ConfirmCostlyBuildOptions` para o build pós-import.
- `scripts/msbuild-exit-codes.catalog.json`, `10-base-operacional-msbuild-headless.md`
  e `xpz-msbuild-build/SKILL.md`: documentam o novo gate.

### Decisao final

A trilha adotou gate separado de `-AllowWideRebuild` para não misturar regeneração
total (`ForceRebuild=true`) com opções caras de build incremental. A confirmação exige
a frase exata `entendo que estas opcoes podem ampliar muito o custo do build e aceito executar`.

### Rastreabilidade

- Commit: `c2a09b7` (`Adiciona gate para opções caras de build`)

## Documentos de governança na raiz

**Importancia original:** baixa
**Status:** concluida em 2026-06-05

### Origem

Ideia registrada em `999-ideias-pendentes.md` a partir do alinhamento com upstream FBgx18MCP v2.0.0→v2.3.6, sessão 2026-05-17, e reforçada na frente pré-push de 2026-05-21 como lacuna de orientação para contribuidores humanos.

### Problema concreto

O repositório já era público e continha base metodológica com potencial de adoção externa, mas não tinha os arquivos canônicos de governança para orientar segurança, contribuição, conduta e registro de mudanças.

### Implementacao

- `SECURITY.md`: política mínima para reporte privado de vulnerabilidades, vazamento de dados e riscos operacionais.
- `CONTRIBUTING.md`: guia curto para contribuidores humanos, com leitura obrigatória, anti-duplicata em `998`/`999`, cuidado com dados reais e ponte para a revisão pré-push.
- `CODE_OF_CONDUCT.md`: código de conduta trilíngue, alinhado ao propósito GeneXus XPZ/XML e explícito contra desqualificação de participantes por trabalharem com GeneXus ou IA.
- `CHANGELOG.md`: registro inicial de mudanças a partir desta adoção, sem reconstrução retroativa de versões.

### Decisao final

A frente adotou documentos mínimos e trilíngues, com português como fonte editorial primária, sem duplicar integralmente `README.md` ou `AGENTS.md`. O histórico anterior permanece nos commits, em `historico/` e na documentação das frentes já encerradas.

### Rastreabilidade

- Commit: `b0408a0` (`Adiciona documentos de governança do repositório`)
- Commit: `1ef85e1` (`Documenta contato privado para contribuicoes`)
- Commit: `4e919ff` (`Ajusta email de contato comunitario`)
- Commit: `0123b9b` (`Vincula contribuicao ao changelog`)

## Teste de integração para bloqueio de XML de referência no `Build-GeneXusImportFileEnvelope`

**Importancia original:** baixa
**Status:** concluida em 2026-06-04

### Origem

Fechamento da frente de bloqueio de XML de referência/exemplo/template em empacotamento, discutida em 2026-05-23 e registrada em `999-ideias-pendentes.md`.

### Problema concreto

`Build-GeneXusImportFileEnvelope.ps1` bloqueava arquivos de entrada explícita em `-ObjectXmlPaths` e `-TopLevelAttributesXmlPaths` quando o nome indicava XML de referência, exemplo, template ou molde, mas esse contrato só estava coberto por parse PowerShell e inspeção do diff.

### Implementacao

- `scripts/Test-BuildGeneXusImportFileEnvelopeSelfTest.ps1`: novo autoteste com fixture temporária mínima.
- O teste chama o script real `Build-GeneXusImportFileEnvelope.ps1`, com template `ExportFile`, XML de objeto com `lastUpdate`, acervo baseline e atributo top-level sintético.
- A cobertura confirma bloqueio em `-ObjectXmlPaths`, bloqueio equivalente em `-TopLevelAttributesXmlPaths` e controle positivo em que `-TemplatePackagePath` contém `template` no nome sem acionar o bloqueio.

### Decisao final

A trilha passou a ter cobertura executável para o bloqueio nominal dos XMLs de entrada do pacote, preservando o uso legítimo de pacote template como fonte comparável do envelope.

### Rastreabilidade

- Commit: `2bf4e05` (`Cobre bloqueio de XML de referencia no envelope`)

## Gates consultivos de reforço da fase semântica da pré-push

**Importancia original:** média
**Status:** concluida em 2026-06-06

### Origem

Uma revisão pré-push perdeu a propagação de um alias novo (`-ObjectList`) a uma menção pré-existente. Investigar a causa levou a um padrão maior: a fase semântica acerta a verificação "para frente" (o que entrou está presente?) e é cega à verificação reversa/invariante (adicionar isto tornou alguma afirmação existente falsa? algum conteúdo viola regra documentada?).

### Problema concreto

Gaps dessa classe não eram capturados de forma reproduzível. Bateria empírica: 12 execuções de revisão pré-push, 6 modelos (Claude/Opus, GPT-5.5, DeepSeek, GLM, MiniMax, Kimi), 3 harnesses; sobre 3 gaps reais plantados, 10 das 12 não acharam nenhum, e só o GPT-5.5 achou algo (2 runs, subconjuntos disjuntos). Diligência, amplitude de busca e nível de raciocínio não mudaram o resultado.

### Implementacao

Quatro gates consultivos no orquestrador `Invoke-PrePushMechanicalChecks.ps1`, cada um com self-test, e reforço conceitual no `13` (passos 2 e 3):
- `Test-PrePushNewTokenPropagation.ps1` — termo de contrato novo não propagado a menções co-localizadas (transição no diff, filtro por morfema).
- `Test-PrePushSharedScriptSkillCoverage.ps1` — script compartilhado alterado documentado em `SKILL.md`/`quality-checklist.md` fora do diff.
- `Test-PrePushHistoryCommitPlaceholder.ps1` — placeholder genérico em campo `Commit:`/`PR:` de `historico/`.
- `Test-PrePushGateEnumerationParity.ps1` — enumeração de gates na doc que ficou subconjunto próprio do que o orquestrador executa (deriva a verdade do código).
Também: preenchimento de hashes reais no histórico e correção de gaps nos self-tests (regra UTF-8 `09:103`; cobertura de caso vazio).

### Decisao final

Mecanizar só a classe cuja fonte-de-verdade é derivável do código (paridade de enumeração, propagação de termo). Para o resíduo semântico puro ("o que virou falso"), a salvaguarda é diversidade de modelo na revisão — mitigante probabilístico, não garantia. Ideia de lint UTF-8 avaliada e descartada (`998-ideias-descartadas-e-porque.md`).

### Rastreabilidade

- Commit: `a5b9ef6` (`Adiciona gate consultivo de propagacao de termo novo a pre-push`)
- Commit: `7b0ff77` (`Adiciona gate consultivo de cobertura de skill transversal a pre-push`)
- Commit: `7cc62fa` (`Adiciona gate consultivo de placeholder de rastreabilidade a pre-push`)
- Commit: `173cb9a` (`Preenche hash real nos campos Commit: do historico de junho`)
- Commit: `19b5859` (`Adiciona gate de paridade de enumeracao de gates e fecha a causa-raiz`)
- Commit: `2db41f8` (`Corrige gaps dos self-tests da pre-push achados na bateria de harnesses`)

## Contrato de nomenclatura de parametros das skills XPZ

**Importancia original:** media
**Status:** concluida em 2026-06-07

### Origem

Feedback de uma sessao real operando a pasta paralela de KB com as skills XPZ: num unico ciclo de empacotar/importar, varias chamadas falharam por inconsistencia de contrato entre wrappers. A parte de saida/`-AsJson` ja fora tratada em frente anterior; restava a nomenclatura de parametros, que nunca foi registrada em `999-ideias-pendentes.md` (entrou direto como frente nesta sessao).

### Problema concreto

Conceitos equivalentes apareciam com nomes diferentes entre wrappers/motores: selecao de objeto como `-ObjectNames` (Copy) vs `-ObjectList` (export/preflight/governance); entrada primaria como `-InputPath` (sync/sanity/extract/summary) vs `-XpzPath` (import). Sem vocabulario canonico unico nem aliases, um agente caia em tentativa-erro de flag. Conceitos so aparentemente irmaos (`-ExpectedItems`, `-ModifiedObject*`, `-IncludeItems`/`-ExcludeItems`) corriam risco de unificacao indevida.

### Implementacao

- Selecao por nome: `-ObjectList` canonico, `-ObjectNames` sinonimo. `Invoke-GeneXusXpzExport.ps1` passou `-ObjectList` a `[string[]]` com alias `ObjectNames` e normalizacao interna; `Copy-GeneXusAcervoToFront.ps1` reframeado (aceita ambos).
- Entrada primaria: `-InputPath` canonico com alias `-Path` em 7 scripts (`Sync-GeneXusXpzToXml`, `Edit-GeneXusXmlSurgical`, `Extract-XpzObject`, `Get-GeneXusObjectSummary`, `Test-GeneXusObjectVariableDelta`, `Test-GeneXusTransactionCoherence`, `New-GeneXusUnknownTypeMaintainerPrompt`).
- Familia de import (decisao C3): `-InputPath` canonico com aliases `-XpzPath` (retrocompativel) e `-Path` em `Invoke-GeneXusXpzImport.ps1`, `Invoke-GeneXusXpzImportThenBuild.ps1` e `Test-GeneXusXpzImportPreview.ps1`; chaves `XpzPath` do JSON de saida preservadas.
- Regra de direcao: artefato de saida mantem nome por papel (`-XpzPath` no export, sem alias `-InputPath`).
- Conceitos distintos preservados: `-ModifiedObjectNames`/`-ModifiedObjectGuids` (handoff), `-ExpectedItems` (assercao), `-IncludeItems`/`-ExcludeItems` (task MSBuild).
- Trava deterministica nova: `scripts/Test-XpzParameterNamingContract.ps1` (nomes, aliases, tipo e regra de direcao via metadados, sem KB).
- Vocabulario canonico documentado em `02-regras-operacionais-e-runtime.md`; propagacao em `10-base-operacional-msbuild-headless.md`, `xpz-msbuild-import-export/SKILL.md`, `xpz-kb-parallel-setup/SKILL.md` e no exemplo `Copy-KbAcervoToFront.example.ps1`. `README.md` (trilingue) e `08-guia-para-agente-gpt.md` ja traziam a preferencia canonica.

### Decisao final

Em vez de renomear a familia, fixou-se vocabulario canonico com aliases aditivos (sem quebra), preservando conceitos genuinamente distintos e a regra de direcao entrada/saida. A decisao C3 (renomear o primario do import para `-InputPath` mantendo `-XpzPath` como alias) foi escolhida sobre aliasar so o import, para evitar excecao permanente no canone — preferencia por coerencia de medio/longo prazo. Pre-push revisada tambem por modelo independente: os gates consultivos `newTokenPropagation` e `sharedScriptSkillCoverage` foram integralmente justificados.

### Rastreabilidade

- Commit: `13a33eb` (`Unifica contrato de nomenclatura de parametros nas skills XPZ`)

## Endurecimento do gate de propagacao por classe e o teto da revisao de modelo unico

**Importancia original:** media
**Status:** concluida em 2026-06-07

### Origem

Fechamento da frente de nomenclatura (acima): a revisao pre-push por um modelo distinto (MiniMax) encontrou um gap de propagacao (lista de parametros gemea divergente: `10-base...md:765` vs `xpz-msbuild-import-export/SKILL.md:322`, e `xpz-kb-parallel-setup/SKILL.md:557`) que tres passadas do mesmo modelo (Opus) descartaram em lote sob justificativa coletiva. Investigar levou a uma cadeia de endurecimento do gate `Test-PrePushNewTokenPropagation.ps1` e a um aprendizado sobre o limite do revisor de modelo unico.

### Problema concreto

O gate emitia todas as candidatas com severidade uniforme `warn`, sem distinguir prosa (que cita o nome canonico) de lista de parametros gemea (que de fato divergiu); isso convidava o revisor a descartar tudo em lote. Alem disso, o teto `-MaxFindings` truncava o total em ordem de varredura, derrubando candidatas de subpastas (skills) antes de alcanca-las.

### Implementacao

- `mentionClass` por candidata (`prose`/`param-list-item`/`param-table-cell`/`command-example`), em campo estruturado e no sufixo `[classe=...]` da mensagem; rastreio de blocos de codigo cercados (commit `2485f20`).
- Truncamento ciente de classe: o teto aplica-se so a `prose`; nao-prosa nunca truncada; campos `classCounts` e `truncatedProseCount` (commit `4b50e62`).
- Orquestrador segrega as nao-prosa em `nonProseVerdictRequired` e injeta no `agentSemanticChecklist` a exigencia de livro-razao item a item; acima de 5 nao-prosa recomenda segunda passada por modelo distinto (commit `fc8533d`).
- `13-revisao-pre-push.md`: disciplina de confronto por classe (prosa admite justificativa coletiva, nao-prosa exige veredito individual contra a lista-gemea) e salvaguarda de diversidade de modelo promovida de reserva para recomendada-acima-de-limiar. `08-guia-para-agente-gpt.md` espelhou as regras novas. Self-test do gate estendido com asserts de classe e de truncamento por classe.

### Decisao final

A mecanica foi util mas tem teto: forcar exaustividade num revisor de modelo unico nao garante veredito correto. Em experimento controlado (mesmo prompt minimo, mesmo modelo, so a rotina mudando entre rodadas), o Opus melhorou o processo (passou a confrontar todas as candidatas em livro-razao) mas piorou o veredito — racionalizou cada item como justificado, inclusive revertendo um veredito antes correto. So um modelo distinto pegou os gaps. Conclusao registrada em `998-ideias-descartadas-e-porque.md`: a diversidade de modelo e o backstop; nao tentar mecanicamente consertar o revisor unico. Os gaps de propagacao e o espelho do `08` foram mantidos abertos como fixtures durante os experimentos e corrigidos no fechamento desta frente.

### Rastreabilidade

- Commit: `2485f20` (`Classifica candidatas do gate de propagacao por forma da mencao`)
- Commit: `4b50e62` (`Torna o truncamento do gate de propagacao ciente de classe`)
- Commit: `fc8533d` (`Forca veredito individual das candidatas nao-prosa na pre-push`)

## Gate de drift 9-FD fail-closed e motor de re-carimbo de `lastUpdate`

**Importancia original:** media
**Status:** concluida em 2026-06-07

### Origem

Frente operacional do empacotamento por frente: o gate de drift frente-vs-acervo (9-FD) do `New-XpzImportPackage.ps1` so rodava quando `-AcervoPath` era informado, o que permitia pular silenciosamente a verificacao de `lastUpdate` simplesmente omitindo o parametro. Junto, faltava um motor dedicado para apenas re-carimbar o `lastUpdate` de um XML da frente ja editado em rodadas subsequentes, sem copiar do acervo nem reaplicar delta.

### Problema concreto

Footgun nomeado: um pacote cujo objeto tem `lastUpdate` menor ou igual ao objeto vivo na KB e aceito pelo import sem erro (`exitCode 0`), mas a KB nao atualiza o objeto — desperdicando um ciclo import+build inteiro. O contrato condicional do gate (so com `-AcervoPath`) deixava esse footgun escapar por omissao. Para re-bumpar o timestamp, agentes recorriam a busca-e-troca textual manual do atributo, fragil e sem validacao de well-formedness.

### Implementacao

- `New-XpzImportPackage.ps1`: gate de drift 9-FD tornado **fail-closed** — executa sempre antes do motor Python; `-AcervoPath` virou opcional e, quando omitido, o acervo canonico `<RepoRoot>/ObjetosDaKbEmXml` e auto-resolvido; sem acervo resolvivel o empacotamento e bloqueado; o JSON ganhou `acervoResolvedBy` (`explicit`/`convention`). Self-test do contrato fail-closed: `scripts/Test-NewXpzImportPackageDriftSelfTest.ps1`.
- Novo motor compartilhado `scripts/Set-GeneXusXmlLastUpdate.ps1` (com `scripts/Test-SetGeneXusXmlLastUpdateSelfTest.ps1`): re-carimba o `lastUpdate` da raiz do Object in-place, recalculando `max(UtcNow + margem, baseline + margem)` via `Get-GeneXusXpzLastUpdate.ps1` e reusando as funcoes de leitura/gravacao/validacao de `GeneXusXmlSurgicalEditSupport.ps1`, com backup `.bak`, restauracao em `XML_NOT_WELLFORMED_AFTER`, `-DryRun` e `-AsJson`. Contrato `-InputPath` (alias `-Path`) adicionado a enumeracao de `scripts/Test-XpzParameterNamingContract.ps1`.
- Footgun do import inocuo por `lastUpdate` velho/igual nomeado e documentado em `xpz-msbuild-import-export/SKILL.md`, com o limite honesto da protecao (os gates comparam contra o acervo, nao contra a KB viva).
- Propagacao do contrato fail-closed em `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `README.md` (trilingue), `xpz-builder/SKILL.md`, `xpz-builder/quality-checklist.md`, `xpz-kb-parallel-setup/SKILL.md` e no exemplo `xpz-kb-parallel-setup/examples/New-KbImportPackage.example.ps1`. Entrada correspondente em `CHANGELOG.md` (`Unreleased`, trilingue).

### Decisao final

Optou-se por fail-closed com auto-resolucao canonica em vez de manter o gate condicional: omitir `-AcervoPath` nao pode ser um caminho para pular a verificacao. A protecao cobre o caso comum (esquecer de bumpar), mas nao substitui ressincronizar o acervo quando ha suspeita de defasagem frente a KB viva — limite registrado explicitamente na doc. A propagacao do contrato antigo (condicional) para o novo (fail-closed) foi inicialmente incompleta e so fechada apos revisao pre-push por modelos distintos (GLM, DeepSeek, MiniMax), que tambem apontaram a paridade de enumeracao no gate de parametros, a entrada de CHANGELOG e este registro de historico.

### Rastreabilidade

- Commit: `2c8b699` (`Torna fail-closed o gate de drift de lastUpdate no empacotamento por frente`)
- Commit: `8949c76` (`Adiciona Set-GeneXusXmlLastUpdate para re-bumpar lastUpdate sem delta`)
- Commit: `5aa96cb` (`Atualiza o inventario 09 com o contrato fail-closed e o motor Set-`)
- Commit: `e77c67e` (`Alinha README trilingue e molde da kb-parallel-setup ao contrato fail-closed do gate de drift`)
- Commit: `94fc0cf` (`Completa a propagacao do contrato fail-closed do gate de drift em 02, 08 e kb-parallel-setup`)

## Sync GUID-aware: rename de atributo/objeto tratado como rename, nao delete+create

**Importancia original:** media
**Status:** concluida em 2026-06-13

### Origem

Levantada em 2026-06-12 durante a probe de rename (`DistribuidoraNome` -> `DistribuidoraNomeTeste`, KB `wsEducacaoSpTeste`). O full sync deixou o arquivo do nome antigo como residuo no acervo e abortou com `Extra=1`. O dev apontou que, do ponto de vista do acervo de XMLs, o sync deveria ter reconhecido o rename sozinho — sem deixar dois XMLs separados e de modo que o git trate como rename, nao delete+create.

### Problema concreto

`Get-FullSnapshotComparison` em `scripts/Sync-GeneXusXpzToXml.ps1` montava a chave de reconciliacao como `FolderType|name`, so pelo nome logico; `Get-LogicalNameFromExtractedFile` lia apenas `rootNode.GetAttribute("name")`. O `guid` estava no mesmo no raiz mas era ignorado. Por isso um rename virava drift: o export trazia o nome novo, o acervo ficava com novo + residuo antigo, e comparado por nome o antigo caia como `Extra` -> `throw`, sem ver que era o mesmo GUID do recem-materializado. Resultado: residuo no acervo, full sync abortado e historico git poluido (delete-antigo + create-novo, sem rename detectavel).

### Implementacao

- `Get-LogicalNameFromExtractedFile` passou a extrair tambem o `guid`; `Convert-PackageToItems` passou a carregar o `guid` nos itens (Object e Attribute).
- Nova funcao `Resolve-GuidAwareRenames`: indexa o acervo por `guid` e, para cada item do pacote com GUID valido que casa no mesmo `FolderType` sob nome diferente, trata como rename — `Move-Item` antigo -> novo antes da gravacao. Gated por `-FullSnapshot`; em `-VerifyOnly` apenas classifica o residuo sem tocar o disco.
- Quando o nome novo ja existe no acervo: se for o **mesmo** GUID (orfao de materializacao anterior), remove o arquivo de nome antigo; se for GUID **diferente** (colisao de nome com outro objeto), **aborta fail-closed** antes do laco de escrita, preservando o objeto existente. Rename que difere so na caixa e efetivado via etapa intermediaria (NTFS trata nomes que diferem so na caixa como o mesmo arquivo).
- Guardas: GUID zero/ausente e ignorado (fallback ao nome); GUID duplicado no acervo emite warning e e pulado; GUID que casa em `FolderType` diferente (troca de tipo) fica fora de escopo e segue o caminho atual; lista de renames vazia retorna array vazio (sem regressao StrictMode no caminho de zero renames).
- Novos campos: `RenamedByGuid` e `RenameResidualsDetected` no summary, `Renames` no relatorio.
- Self-test `scripts/Test-XpzSyncGuidRenameSelfTest.ps1` cobre 6 cenarios: rename real (`-FullSnapshot`), classificacao sem mover (`-VerifyOnly`), zero renames (acervo sincronizado), orfao de materializacao anterior (mesmo GUID, remove o nome antigo), colisao de GUID (fail-closed preservando o existente) e rename so de caixa.

### Decisao final

A reconciliacao por GUID e gated por `-FullSnapshot`, o unico regime que ja varre o acervo inteiro e onde o residuo era erro — sem regressao no sync direcionado e sem custo extra no caminho comum. A premissa original da ideia (de que existiria limpeza de residuo por GUID cobrindo `<Object>` e ignorando `<Attribute>`) foi corrigida na implementacao: nao havia limpeza nenhuma; o motor so lancava `throw` em `Extra > 0`. O comportamento foi introduzido ja cobrindo Object e Attribute. Troca de tipo e GUID ausente ficaram registrados como fora de escopo.

### Rastreabilidade

- Commit: `a4288cc` (`Reconcilia rename por GUID no Sync-GeneXusXpzToXml`)

## Suporte a WebPanel classico: inspetor de shape, regra de botao e Add-GeneXusButton

**Importancia original:** media
**Status:** concluida em 2026-06-08

### Origem

Prompt de agente externo de pasta paralela de KB (relato de adicionar botoes e remover marcadores de teste no source de eventos de um `WebPanel`). O agente travava em engenharia reversa do `CDATA`, distincao Flex vs Responsive e edicao whitespace-fragil. Campanha de quatro frentes (A, B, C, D) avaliada sob a regua de priorizar a comunidade usuaria das skills no longo prazo, nao o pedido literal.

### Problema concreto

- O `Get-GeneXusObjectSummary.ps1` so calculava shape para `Panel` (SD), devolvendo `panel=null` para `WebPanel` classico — sem inspetor, o agente lia o `CDATA` na mao.
- A estrutura de botao em `WebPanel` nao estava documentada como regra: duas serializacoes (`<action>` e `<ucw>` Button), confundiveis com `<actions>` de pattern WorkWith e com referencias `.Visible`/`.Icon` em codigo.
- Nao havia helper para inserir botao com a serializacao correta (em especial o `ucw` escapado) tratando Flex vs Responsive.
- A skill `xpz-msbuild-import-export` nao demarcava que edicao de source pertence ao `xpz-builder`.

### Implementacao

- Frente A — `scripts/Get-GeneXusObjectSummary.ps1` ganhou o bloco `webpanel` (parse estrutural do `GxMultiForm`): `tables` com `tableType` Flex/Responsive e `depth`, `controls`, `buttons` nas duas formas, `eventNames` e `coverage` honesto (`unknownUcwControlTypes`). Catalogo versionado `scripts/gx-ucw-gxcontroltype-catalog.json` (doc em `04b-ucw-gxcontroltype-reference.md`). Teste `scripts/Test-GeneXusWebPanelShapeContract.ps1`.
- Frente B — regra interpretativa de botao em `xpz-builder/responsibilities-by-type/webpanel.md` (declaracao unica + On Click Event; desambiguacao layout/`<actions>`/`.Visible`), com cross-ref no `04b`. Sem molde redundante: os moldes do `04` ja cobrem ambas as formas.
- Frente C — `scripts/Add-GeneXusButton.ps1`: insere `<cell>` com botao (forma action/ucw) apos controle folha em tabela Flex, com stub de Event e bump de `lastUpdate`, reusando `GeneXusXmlSurgicalEditSupport.ps1`; gate fail-closed `RESPONSIVE_UNSAFE`. Teste `scripts/Test-GeneXusAddButtonContract.ps1`.
- Frente D — fronteira de escopo em `xpz-msbuild-import-export/SKILL.md`, com descarte da alternativa em `998-ideias-descartadas-e-porque.md`.
- Decisao derivada — `Compare-GeneXusPanelShape.ps1` orienta ao bloco `webpanel` (permanece Panel-only); extensao a WebPanel registrada em `999-ideias-pendentes.md`.

### Decisao final

A distincao `<action>` vs `<ucw>` Button e de serializacao, nao de modelagem (confirmado por evidencia da KB FabricaBrasil, Wiki GeneXus e skill Nexa) — conceitualmente e o mesmo Button. O inspetor declara a propria cobertura para nunca induzir falso negativo; o helper falha de forma segura (`RESPONSIVE_UNSAFE`) no caso Responsive arriscado em vez de reescrever o array de breakpoints.

### Rastreabilidade

- Commit: `83a50b4` (`Demarca fronteira de edicao de source na import-export e registra descarte no 998`)
- Commit: `8260923` (`Adiciona inspetor de shape de WebPanel classico ao Get-GeneXusObjectSummary`)
- Commit: `5cb5b30` (`Cita o bloco webpanel do inspetor no guia do agente (08)`)
- Commit: `5b6add3` (`Orienta WebPanel no Compare-GeneXusPanelShape e registra extensao no 999`)
- Commit: `9ca850d` (`Documenta a regra interpretativa de botao em WebPanel (Frente B)`)
- Commit: `8b26fcb` (`Adiciona Add-GeneXusButton: insercao cirurgica de botao em WebPanel (Frente C)`)
- O commit de fechamento desta frente (paridade de enumeracao no gate de parametros, entrada de `CHANGELOG.md` e este registro) e majoritariamente meta-documental e permanece visivel via `git blame` no arquivo mensal, conforme `historico/AGENTS.md`

## Eventos pos-build declarativos e gate de deploy bin por sucesso operacional factual

**Importancia original:** media
**Status:** concluida em 2026-06-08

### Origem

Relato de sessao real: build do environment `NETPostgreSQL` da KB FabricaBrasil com `-PostImportDeployValidation` apos importar um WebPanel. Um evento pos-build benigno — um "sino" de fim de build (`SoundPlayer ... PlaySync()`) configurado na KB — rebaixava o status do build e, como efeito colateral, suprimia o gate de validacao de deploy que o usuario pedira; o hand-off manual de `-BuildStartedAt` para o diagnostico avulso completava a friccao.

### Problema concreto

- O gate de `web\bin` (`-PostImportDeployValidation`) decidia rodar pela **string de status**: qualquer rebaixamento (inclusive um sino benigno) tirava o status de `compilou limpo` e pulava a validacao pedida.
- O rebaixamento por evento pos-build era cego: qualquer item em `stdoutSignals.postBuildEvents` rebaixava, mesmo um deploy `.Bat` legitimo configurado pelo usuario.
- `Test-GeneXusDeployBinFreshness.ps1` exigia `-BuildStartedAt` manual, forcando extracao do `timing.msbuildStart` do JSON do build na mao.

### Implementacao

- Frente 1 — `scripts/GeneXusKbDeployBinSupport.ps1`: a decisao do gate passou de string (`-BuildSuccessStatus`) para sucesso operacional factual (`-BuildOperationallySucceeded`: MSBuild exit 0 + marcador de conclusao); funcao `Test-GeneXusKbDeployBinBuildSuccessStatus` e array `GeneXusKbDeployBinSuccessStatuses` removidos. Teste `scripts/Test-GeneXusDeployBinPolicySelfTest.ps1`.
- Frente 2 — `scripts/GeneXusMsBuildPostBuildEventsSupport.ps1` ganhou classificacao declarativa (`Get-GeneXusPostBuildEventClassification` + `Get-GeneXusPostBuildEventNormalizedHash` SHA-256, `Test-GeneXusPostBuildEventInert` para `REM`, `Test-GeneXusPostBuildEventBenignBySound`); campo novo `kb_environment_post_build_event_hashes` em `kb-source-metadata.md`, lido por `Get-GeneXusRegisteredPostBuildEventHashesForEnvironment` em `scripts/GeneXusKbDeploymentEnvironmentSupport.ps1`; `scripts/Register-GeneXusKbPostBuildEvents.ps1` registra os eventos conhecidos por environment (campo de fingerprints + secao-espelho legivel; confirmacao por frase exata interativa ou `-ConfirmRegistration` em modo agente). Evento registrado = esperado (nao rebaixa); nao registrado/nao reconhecido = rebaixa por cautela. Testes `scripts/Test-GeneXusPostBuildEventClassificationSelfTest.ps1` e `scripts/Test-GeneXusKbPostBuildEventsRegistrationSelfTest.ps1`.
- Frente 3 — `scripts/Test-GeneXusDeployBinFreshness.ps1` ganhou `-BuildResultJsonPath` (deriva a linha de corte de `timing.msbuildStart` do build; `-BuildStartedAt` opcional, explicito prevalece; `buildStartedAtSource` no resultado). Teste `scripts/Test-GeneXusDeployBinFreshnessBuildStartedAtSelfTest.ps1`.
- Paridade documental: `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `10-base-operacional-msbuild-headless.md`, README trilingue, `CHANGELOG.md` trilingue, `xpz-kb-parallel-setup/SKILL.md` (+ molde `examples/Register-KbPostBuildEvents.example.ps1`), `xpz-msbuild-build/SKILL.md` (catalogo de status do BuildAll) e `xpz-msbuild-import-export/SKILL.md` (propagacao das flags de validacao de deploy bin pelo wrapper integrador, como categoria distinta dos gates de autorizacao).

### Decisao final

O gate de deploy e uma verificacao factual e ortogonal a cautela de seguranca do status — por isso decide por exit 0 + marcador de conclusao, nao pela narrativa. Eventos pos-build legitimos sao reconhecidos por registro declarativo por environment (fingerprint), nao por heuristica de padrao, porque ambientes reais tem comandos legitimos (ex.: deploy `.Bat`) que nenhuma allowlist generica pode confiar; uma rede de seguranca reconhece player de som como benigno quando nao ha registro. A revisao pre-push por multiplos modelos independentes (prompt nu, sem contaminacao do contexto) fechou os gaps de paridade restantes.

### Rastreabilidade

- Commit: `07e5408` (`Desacopla gate de deploy bin da string de status (Frente 1)`)
- Commit: `cd92f41` (`Classifica eventos pos-build por registro declarativo (Frente 2)`)
- Commit: `a083dd1` (`Deriva BuildStartedAt do JSON do build no diagnostico avulso (Frente 3)`)
- Commit: `b7df50f` (`Fecha gaps de paridade documental da campanha pos-build (revisao pre-push)`)
- Commit: `5a5681e` (`Fecha gap do 08 e adiciona molde de registro de eventos pos-build`)
- Commit: `328bf92` (`Espelha classificacao de evento pos-build no catalogo de status do BuildAll`)
- Commit: `cafa134` (`Documenta propagacao das flags de validacao de deploy bin no import-then-build`)

## Catalogo e rastreabilidade de classes CSS no indice KbIntelligence (camadas 1 e 2)

**Importancia original:** media
**Status:** concluida em 2026-06-10

### Origem

Registrada em `999-ideias-pendentes.md` (pronta para implementar, decisoes de design fechadas em 2026-06-10). Surgiu de prompt de agente externo que apontou lacuna de texto livre no indice e propos uma camada full-text geral (FTS5); na discussao com o usuario foi afunilada para o que tinha valor barato e imediato: catalogar as classes CSS e rastrear onde sao usadas. A camada 3 (texto livre geral) ficou de fora e virou entrada propria no `999`.

### Problema concreto

Dois falsos "nao existe", o erro que a base mais teme: (1) inventario incompleto — as classes do modelo moderno (DesignSystem) sao texto SCSS dentro do objeto, nao viram objeto, entao `search-objects` por uma delas devolvia "nao existe"; (2) uso invisivel — o uso nao esta so no layout (`class="..."`); tambem e atribuido por codigo em eventos (`Controle.Class = ...`), e uma deteccao que olhe so o layout perde centenas de usos.

### Implementacao

- Camada 1 — `scripts/Build-KbIntelligenceIndex.py` cataloga classes na tabela nova `css_class`: `model` `legacy-theme` (de `ThemeClass`, nome pela propriedade `Name` — nunca o stem, que corrompe `:` em `_`, ex.: `ImageHandCenter_hover.xml` cujo Name real e `ImageHandCenter:hover`) / `design-system` (de SCSS no Part Styles `c6b14574-...` de `DesignSystem` e de `DesignSystem` aninhado em `PackagedModule`); `origin` `kb-authored`/`packaged-module`; `parent_class` de heranca; `UNIQUE(model, class_name, defining_object_name)` que de proposito nao colapsa entre modelos (mesma classe em legacy e DS = sinal de migracao). `INSERT OR IGNORE` + dedup por `@media`.
- Camada 2 — uso reusa `relations`+`evidence` (sem tabela nova): `uses_css_class` resolvivel (`evidence_role` `css_layout`/`css_event`) e `uses_css_class_dynamic` para `.Class=` por variavel/`Format()` (`target_name` = a expressao, nao um sentinela; M conta por `relation_kind`, nunca por `COUNT(DISTINCT target_name)`). Cobre as 7 formas da matriz; vetores de layout `class`/`cellClass`/`rowClass`/`formClass` (nao o `gxObjClass` numerico); ignora comentarios `//` e `/* */`. Localizador = objeto + snippet.
- Consultas `css-classes` (catalogo; visao padrao so `kb-authored`, lookup nominal `case-sensitive` nunca filtra origem, `legacy-theme` marcado depreciado) e `css-class-usage` (uso; declara `dynamic_uses_total`/`found_in_catalog` e lista usadas-mas-nao-catalogadas) em `scripts/Query-KbIntelligenceIndex.py` e no wrapper `.ps1` (`-Model`/`-Origin`/`-IncludeImported`). Bump `schema_version` `2`->`3` e `EXTRACTOR_SIGNATURE_VERSION` `5`->`6` (rebuild esperado nas pastas paralelas).
- Self-test `scripts/Test-KbIntelligenceCssClassExtractionSelfTest.ps1` (7 formas + `:hover` + heranca + dedup `@media` + comentarios + `PackagedModule` + classe usada-mas-nao-catalogada); 4 self-tests KbIntelligence existentes seguem verdes.
- Paridade de doc: `README.md` (trilingue), `scripts/README-kb-intelligence.md`, `xpz-index-triage/SKILL.md`, `02-regras-operacionais-e-runtime.md`, `08-guia-para-agente-gpt.md`, `09-inventario-e-rastreabilidade-publica.md`, `CHANGELOG.md` (trilingue) e correcao de `schema_version=2`->`>=2` em 4 docs de writability.

### Decisao final

O design foi fechado com o usuario em quatro pontos (dinamico via expressao; nome legacy pela propriedade `Name`; escopo inclui `PackagedModule` com `origin` filtrado por padrao; tabela `css_class` fora de `objects`), com dois confirmados por subagente Opus e o plano revisado por painel multi-modelo (DeepSeek V4 Pro, GLM 5.1, MiniMax M3 via opencode). A validacao empirica no corpus FabricaBrasil reproduziu a regua e corrigiu dois numeros do `999`: AttributeAvisos esta em **15** WebPanels (verdade de campo: 16 arquivos = 1 DS + 15 WebPanels), nao 14; e o layout tem **6077** vetores reais de classe (`class`+`cellClass`+`rowClass`+`formClass`), nao 6229 — a regua antiga incluia o `gxObjClass` numerico. A validacao tambem pegou um gap real de regra de ouro (sem `cellClass` eu perderia 1.746 usos), corrigido antes do commit.

### Rastreabilidade

- Commit: `c33f82f` (`Adiciona catalogo e rastreabilidade de classes CSS ao indice KbIntelligence`)

## Gate de coerencia para Transaction `GenerateObject=False` carregando bagagem WorkWithPlus

**Importancia original:** média
**Status:** concluida (Fase 1) em 2026-06-10

### Origem

Relato de validação de outro agente (KB CPJAPP, frente NFS-e, 2026-06-10), registrado no `999-ideias-pendentes.md`. A entrada do `999` permanece com a Fase 2 (nível de pacote) como subfrente residual aberta.

### Problema concreto

Uma Transaction com `GenerateObject=False` (estrutura/tabela ou Business Component, sem geração da própria tela) empacotada ainda carregando código de tela gerado pelo WorkWithPlus DVelop nas partes `Events`/`Rules` — `Call("LoadWWPContext")`, `Call("<Trn>WW")` — referencia runtime inexistente. O import falha com `src0246`/`src0294` (confirmado-import, GeneXus 18 U13 + WorkWithPlus_Web 16.0.3.1). O gate de coerência de Transaction não detectava isso.

### Implementacao

- `scripts/Test-GeneXusTransactionCoherence.ps1`: nova função `Test-OrphanWwpScreenCode` + auxiliar `Get-ObjectGeneratesProgram` (lê `GenerateObject` do `<Properties>` de nível Object — leitura que o gate não fazia, via XPath `./Properties`). Gatilho `fail` (`wwp-screen-code-on-non-generated-transaction`): `GenerateObject=False` + chamada de tela WWP órfã (`Call("LoadWWPContext")`/`Call("<Trn>WW")`) nas partes Events/Rules. `Apply:<wwp-guid>` e o marcador "DVelop Work With Plus" são corroborantes, não disparadores. GUID WWP `07135890-...` (catálogo `gx-object-type-catalog.json`, `WorkWithPlusInstance`); Work With nativo (`78cecefe`) explicitamente fora de escopo. Early-return em `GenerateObject=True` → zero efeito no acervo atual.
- `scripts/Test-GeneXusTransactionCoherenceSelfTest.ps1`: novo self-test (positivo + 2 negativos), sentinela `OK: Test-GeneXusTransactionCoherenceSelfTest.ps1`.
- `xpz-builder/responsibilities-by-type/transaction.md`: linha no Catálogo 3 (`src0246`/`src0294`), item de checklist e nota no gate relacionado.
- `xpz-builder/wwp-packaging.md`: seção distinguindo este gap do gap inverso (derivados faltando) + nota do pré-requisito de Theme (condição de ambiente, fora do gate).

### Decisao final

Desenho D1-D4 revisado por painel multi-modelo (deepseek-v4-pro, glm-5.1, minimax-m3 via opencode) + subagente Opus. A divergência foi decidida pelo usuário a favor da posição do Opus: o `fail` amarra-se ao **sinal causal** (código órfão em Events/Rules), não à mera presença de `Apply:WWP` — que pode ser legítimo num BC com WW de listagem. O achado empírico do Opus (o acervo FabricaBrasil usa Work With **nativo**, `Apply:78cecefe` em 182/183 Transactions, não DVelop) evitou um falso positivo em massa. Fase 2 (correlação de pacote `PatternInstance`/derivados ↔ Transaction) adiada como subfrente no `999`.

### Rastreabilidade

- Commit: `29a37ee` (`Adiciona gate de coerencia para Transaction GenerateObject=False com bagagem WorkWithPlus`)

## Gate type-aware procedural-in-conditions: Procedure nao deve ter codigo na parte Conditions

**Importancia original:** média
**Status:** concluida em 2026-06-13

### Origem

Frente A do lote CPJAPP (item 1/7). Erro real `src0055` ("Missed ';' at the end of the condition") quando codigo procedural foi parar indevidamente na parte Conditions de um Procedure. Parqueada em 2026-06-10 aguardando o exemplo sanitizado real do CPJAPP; recebido em 2026-06-13, ele mudou o desenho (de heuristica de construcoes para type-aware).

### Problema concreto

A parte Conditions (`763f0d8b`) tem `<Source>`, entao o `Test-GeneXusSourceSanity.ps1` ja a percorre, mas aplicava o balanceador procedural a toda parte sem ramificar por tipo. Em Procedure, qualquer codigo na Conditions causa `src0055` no import — e Procedure nao tem filtro de Conditions (predicados vivem em `For Each ... Where`, parte `528d1c06`). O exemplo real do CPJAPP trouxe comentario `//`, atribuicoes a variavel (`&var = ...`), `If`, `Return`, `For Each`/`Endfor`, `Where`, `defined by`, `.IsEmpty()`, `procY.Call(...)` — `Do Case` e `Sub` nem apareceram, o que tornou fragil a heuristica de blocos do desenho anterior.

### Implementacao

- `scripts/Test-GeneXusSourceSanity.ps1`: regra type-aware via mapa extensivel `$script:ForbiddenNonEmptyParts` (objectType -> partType -> mensagem; hoje so Procedure `84a12160` -> Conditions `763f0d8b`). Procedure com Conditions nao-vazia -> finding `procedural-in-conditions` (`fail`). Aditivo: o loop ja pula Source vazio/whitespace, entao Procedure normal (Conditions vazia) nao dispara. Match por `type` GUID exato.
- `scripts/Test-GeneXusSourceSanitySelfTest.ps1`: novo self-test, 6 casos (positivo Procedure; negativos Conditions vazia, whitespace-only, sem a parte, WebPanel com filtro legitimo, ExportFile com 2 objetos).
- Docs: `CHANGELOG.md` (trilingue), `02-regras-operacionais-e-runtime.md` e `09-inventario-e-rastreabilidade-publica.md`.

### Decisao final

Desenho type-aware (Procedure + Conditions nao-vazia = fail) revisado por painel multi-modelo (deepseek-v4-pro, glm-5.1, minimax-m3 via opencode) + subagente Opus, mais uma 2a passada de revisao de implementacao do Opus. Decisoes-chave: severidade `fail` (confirmado-import `src0055` + confirmado-acervo 0/milhares no FabricaBrasil — o Opus varreu o acervo inteiro e achou 0 Procedures com Conditions nao-vazia, refutando o catch de `For Each` do minimax); escopo so Procedure (Data Selector tem Conditions legitima — catch do glm); descartar a heuristica de construcoes (seria nociva em filtro legitimo de WebPanel/Prompt). Extensao a DataProvider/outros tipos fica como residuo no `999`, condicionada a evidencia.

### Rastreabilidade

- Commit: `b759d70` (`Adiciona gate type-aware procedural-in-conditions ao Test-GeneXusSourceSanity`)

## Gate fail-fast de `-LogPath` (rejeitar diretorio) nos wrappers MSBuild

**Importancia original:** média
**Status:** concluida em 2026-06-14

### Origem

Prompt de outro agente a partir de uso real (frente OperacaoItem / Titulo Intermediario na KB FabricaBrasil18), 2026-06-13. Plano revisado por 3 analises independentes convergentes (verificacao propria + subagente Opus + Codex/GPT-5.5).

### Problema concreto

O `-LogPath` dos wrappers MSBuild era resolvido cedo mas sem validar que aponta para um arquivo. Quando o chamador passava por engano um diretorio existente como `-LogPath`, o wrapper rodava a operacao inteira (abria a KB, buildava/importava) e so falhava na gravacao final do diagnostico JSON via `[System.IO.File]::WriteAllText(<diretorio>, ...)`, caindo no catch e retornando exit 90 ("falha operacional") quando a operacao na verdade concluira. O guard de escrita so checava o diretorio-pai, e um diretorio existente passava nesse gate.

### Implementacao

- Motor puro compartilhado `scripts/GeneXusMsBuildLogPathSupport.ps1`: `Get-GeneXusMsBuildLogPathRejection` (condicao `Test-Path -PathType Container`, nunca `-not -PathType Leaf`, para nao bloquear arquivo-a-criar com pai valido) e `New-GeneXusMsBuildLogPathBlockJson` (bloco exit 50, categoria `parametro-invalido`). Funcao pura: nao grava nada, nao resolve caminho (recebe o `-LogPath` ja resolvido pelo `Get-FullPathSafe` local de cada wrapper).
- Descoberta-chave: o probe `Test-GeneXusMsBuildSetup.ps1` (`Validate-LogPath`, exit 14) nao valida o `-LogPath` do wrapper — os wrappers chamam o probe com um LogPath interno (`probe-stage.json`). Logo o gate roda no proprio wrapper com o `-LogPath` real, emitindo o bloco so no stdout (sem `Write-JsonLog`, para nao tentar gravar no `-LogPath` invalido).
- Gate fiado cedo (antes de abrir a KB / registrar tarefa) nos 10 wrappers: `Invoke-GeneXusKbBuildAll`, `Invoke-GeneXusXpzImport`, `Get-GeneXusKbProperty`, `Start-GeneXusKbBuildDetached` (nuance: cria o diretorio-pai do log/sentinela — o gate bloqueia "diretorio existente" mas preserva arquivo-a-criar), `Invoke-GeneXusXpzImportThenBuild`, `Invoke-GeneXusKbSpecifyGenerate`, `Invoke-GeneXusXpzExport`, `Test-GeneXusXpzImportPreview`, `Open-GeneXusKbHeadless`, `Test-GeneXusKbConsistency` (os 2 ultimos achados pelo Codex).
- Exit 50 novo em `scripts/msbuild-exit-codes.catalog.json` (nao reusou 46 nem 14); `wrapperScanList` de `scripts/Test-MsBuildExitCodesCatalog.ps1` ampliado com `Start-GeneXusKbBuildDetached` e `Invoke-GeneXusXpzImportThenBuild`.
- Self-test `scripts/Test-GeneXusMsBuildLogPathSupportSelfTest.ps1` (5 cenarios); smoke real exit 50 + JSON confirmado em `Open-GeneXusKbHeadless`.
- Docs: `10-base-operacional-msbuild-headless.md`, `09-inventario-e-rastreabilidade-publica.md`, `xpz-msbuild-build/SKILL.md`, `xpz-msbuild-import-export/SKILL.md` (com correcao do exemplo de `-LogPath` que apontava para o que parecia um diretorio) e `CHANGELOG.md` (trilingue).

### Decisao final

Exit 50 novo (categoria `parametro-invalido`), nao reuso de 46 (politica multi-causa) nem 14 (probe). Funcao pura compartilhada com escopo minimo, condicao `Test-Path -PathType Container` exata para nao regredir o arquivo-a-criar legitimo. README trilingue ficou de fora por ser detalhe operacional dos wrappers, nao regra geral.

### Rastreabilidade

- Commit: `79d759a` (`Adiciona gate fail-fast de -LogPath (exit 50) aos wrappers MSBuild`)

## Catalogar o anti-padrao `src0239` (regra `Default` com condicional) em Transaction

**Importancia original:** baixa
**Status:** concluida em 2026-06-14

### Origem

Prompt de outro agente, 2026-06-13. Reproducao real `confirmado-import` na propria maquina: `src0239: 'Default' rule does not support a conditional expression. (Transaction 'OperacaoItem' Rules, Linha: 116, Char: 1)`, `importTaskSuccess=false`, KB FabricaBrasil18 / environment NETPostgreSQL.

### Problema concreto

Uma regra de Transaction na forma `Default(<Atributo>, <expressao>)` nao aceita clausula condicional. Escrever `Default(OperacaoItemTituloIntermediarioEmpresaId, procEmpresaPessoa()) if not OperacaoItemTituloIntermediarioId.IsEmpty();` faz o specify/import falhar com `src0239`. O anti-padrao nao estava catalogado.

### Implementacao

- Corpo nomeado `transaction-default-rule-with-conditional` em `02-regras-operacionais-e-runtime.md`, na secao "Anti-padroes nomeados (`Transaction` — motor XPZ)", no mesmo formato das irmas (`src0056`/`spc0150`): sintoma observado / erro exato verbatim / causa raiz / correcao idiomatica, rotulo `confirmado-import`.
- Ponteiro curto no Catalog 3 de `xpz-builder/responsibilities-by-type/transaction.md` apontando ao `02`, seguindo o precedente da entrada da cascata.
- Cross-ref a secao "Cascade ordering" como tema relacionado mas mecanismo distinto: `src0239` e rejeicao no import (o Specifier barra antes); a cascata e sombreamento em runtime com import/build limpos. Nao fundir.
- `CHANGELOG.md` (trilingue).

### Decisao final

Ressalva semantica explicita: a correcao "manter o `Default` incondicional e mover a condicao para uma regra de assignment separada" nao e equivalente de runtime ao `Default` condicional pretendido — os gatilhos diferem (`Default` = valor inicial quando o atributo esta vazio; assignment = avaliacao de rule). Documentado como forma idiomatica sem afirmar equivalencia; a semantica correta de cada uma e conhecimento de modelagem GeneXus (fronteira nexa), como nas irmas.

### Rastreabilidade

- Commit: `f798c1a` (`Cataloga o anti-padrao src0239 (Default com condicional) em Transaction`)

## Promoção da rotina pré-push de pasta paralela à skill `xpz-kb-parallel-pre-push`

**Importancia original:** média
**Status:** concluida em 2026-06-15

### Origem

Registrada em `999-ideias-pendentes.md` como «Plano B», sessão 2026-06-12. A rotina pré-push de pasta paralela de KB existia apenas como experimento incubado e hardcoded na FabricaBrasil (`C:\Dev\Prod\Gx_FabricaBrasil\pre-push-routine`: README + 8 experimentos + `decisao-001`). O objetivo era promovê-la a skill no padrão das demais (`SKILL.md` + satélites), generalizada para qualquer pasta paralela. Nome final travado pelo dono: `xpz-kb-parallel-pre-push` (irmã de `xpz-kb-parallel-setup`). O plano foi endurecido e convergido por um ciclo de «Revisão por Pares» (painel multi-modelo via `xpz-llm-delegate` — deepseek-v4-pro, glm-5.1, kimi-k2.7-code, minimax-m3, opus 4.8, codex gpt-5.5 — mais revisão de pares de código), em duas rodadas (v1→v2→v3).

### Problema concreto

A lógica-fonte da pré-push de pasta paralela vivia só na FabricaBrasil, com nomes hardcoded, sem skill que a generalizasse nem documentação metodológica. Não havia separação entre motor compartilhado e wrapper local por-KB (padrão `xpz-sync`), nem contrato estruturado para os gates que dependem de wrappers locais (K8 auditoria de setup, K9 gate de índice — a lógica de K9 vivia inline no molde local).

### Implementacao

- **Fase 1 (mecânica) — núcleo de engenharia:** 5 motores generalizados em `scripts/` (`Test-XpzKbDangerousPaths` K1/K2, `Test-XpzKbLayerDiff` K3/K4, `Test-XpzNotNotIsAntipattern` K11, `Test-XpzKbFrenteHygiene` Fase 2a parcial, `Compare-XpzChecksums` F1), JSON por padrão, tokens de camada parametrizados, `git -C` com captura de exit (`unknown` bloqueia), StrictMode-safe. Orquestrador `scripts/Invoke-XpzKbParallelPrePushPhase1.ps1` (G0–G5 + K1–K4/K8/K9/K11, `pushReadiness` 0/2/1, descoberta de wrapper local por config → convenção → fail-closed). Contrato estruturado K8/K9: `Test-XpzSetupAudit.ps1` ganhou `-AsJson` aditivo (K8) e o gate de índice foi promovido a motor compartilhado `scripts/Test-XpzKbIndexGate.ps1` com `-AsJson` (K9), corrigindo a assimetria de a lógica viver inline no molde local.
- **Bloco A** — pasta `xpz-kb-parallel-pre-push/`: `SKILL.md` enxuto (estrutura de `xpz-sync`) + 3 satélites (`fase1-mecanica`/`fase2a-estrutural`/`fase2b-classificador-de-regime`) + `agents/openai.yaml` + `examples/` (wrapper fino, config com `layerTokens`, catálogo de padrões aceitos por-KB, 2 moldes de relatório).
- **Bloco C** — 8 self-tests + helper `XpzKbPrePushSelfTestSupport.ps1` (monta repos git de fixture), sentinela em CAIXA-ALTA, todos verdes.
- **Blocos D–G** — paridade documental: README trilíngue, `AGENTS.md` (raiz), `02`, `08`, `09` (2 entradas de evidência), `13` (desambiguação no §Escopo: esta skill é a pré-push de pasta paralela, distinta da rotina pré-push do repo de skills), `14` (nota consultiva), `CHANGELOG.md` trilíngue, adendo no `xpz-llm-delegate/SKILL.md` (como complemento) e cross-ref no `xpz-kb-parallel-setup/SKILL.md`; `Test-XpzKbIndexGate.ps1` adicionado ao `setup-contract.manifest.json`.
- **Bloco H (lado pasta paralela — outro contexto operacional):** adendo de superação na `decisao-001` do experimento da FabricaBrasil e registro global da skill via `xpz-skills-setup`. A `kb-parallel-pre-push.config.json` foi verificada **dispensável** na FabricaBrasil: os wrappers locais batem a convenção (`Test-FabricaBrasilKbSetupAudit.ps1` + `Test-FabricaBrasilKbIndexGate.ps1`, exatamente 1 de cada), então o orquestrador resolve por convenção sem config — só seria necessária com 0 (`none`) ou ≥2 (`ambiguous`) candidatos.

### Decisao final

A skill não depende da FabricaBrasil — usa-a só como referência (generalizar, não copiar). Saída JSON de máquina por padrão. A Fase 2b é classificador de regime, não runbook com selo: a autoridade sobre regressão destrutiva, troca de tipo ou de chave é o build com `FailIfReorg`, e a estática só agrega no aditivo data-bearing (shortlist de omissão). Por isso a frente não dependeu do Plano A (`references_attribute`). A `decisao-001` foi superada pelo classificador. O plano foi convergido por «Revisão por Pares» antes da implementação; a revisão pré-push reforçada (painel de 6 modelos) convergiu sobre o estado final, com o Codex (gpt-5.5, dissidente) sendo o único a achar 3 gaps de precisão (config inexistente citada como literal; rótulo «fail-open» ambíguo no K1/K2; orquestrador descrito como «na pasta paralela») que os outros 5 não viram — todos corrigidos antes do push. A entrada-diagnóstico «Maturar a Fase 2b…» permanece aberta no `999` como direção de pesquisa independente.

### Rastreabilidade

- Commit: `578fc9f` (`Adiciona os 5 motores generalizados da rotina pre-push de pasta paralela`)
- Commit: `5857e0e` (`Adiciona modo -AsJson aditivo ao motor Test-XpzSetupAudit (contrato K8)`)
- Commit: `0cc8092` (`Adiciona o orquestrador Invoke-XpzKbParallelPrePushPhase1 (Fase 1)`)
- Commit: `74816e4` (`Promove o gate de indice a motor compartilhado Test-XpzKbIndexGate (contrato K9)`)
- Commit: `870e971` (`Moldes locais de K8/K9 repassam -AsJson (lado local do contrato estruturado)`)
- Commit: `47f4d65` (`Cria a pasta da skill xpz-kb-parallel-pre-push (Bloco A)`)
- Commit: `3ae3dd9` (`Adiciona self-tests da rotina pre-push de pasta paralela (Bloco C)`)
- Commit: `06d4de9` (`Paridade documental da skill xpz-kb-parallel-pre-push (Bloco D-G)`)
- Commit: `efe3213` (`09: nomeia tokens literais pushReadiness e estado_operacional_sugerido`)
- Commit: `239e0f9` (`Corrige 2 gaps de precisao achados na pre-push reforcada (Codex)`)
- Commit: `e9b8f3e` (`Corrige rotulo "fail-open" ambiguo no K1/K2 (3a passada Codex)`)
- Commit: `207cab4` (`999: marca config do pré-push como dispensável na FabricaBrasil (Bloco H)`)

## Enxugar o inventário de scripts do `09` para ponteiros de 1 linha

**Importancia original:** média
**Status:** concluída em 2026-06-15

### Origem

Sessão de 2026-06-07 (frente do gate fail-closed de drift de `lastUpdate`): a revisão pré-push detectou que a propagação havia esquecido o `09`; ao investigar, viu-se que a seção de inventário de scripts do `09` duplicava informação já documentada nos donos lógicos (cabeçalho do script, skill dona, `13`, `02`/`08`, `README-kb-intelligence`). Registrada como ideia em `999-ideias-pendentes.md`.

### Problema concreto

O `09-inventario-e-rastreabilidade-publica.md` acumulou ~111 entradas `Evidência direta` descrevendo cada motor de `scripts/` com contrato, parâmetros, exit codes, sentinelas e consumo normativo — um quarto caminho para a mesma informação driftar (o mesmo anti-padrão que o `998` registrou ao descartar um "README agregado em `scripts/`"). Mudar o contrato de um script exigia atualizar 5 lugares, e o `09` ficava para trás.

### Implementacao

- Cada entrada de script do `09` virou um ponteiro de 1 linha (Caminho 1): `scripts/X` (categoria) — papel em 1 frase; Dono: <normativo>; Validação: <self-test.ps1>; Tokens/Exit nus. A prosa de contrato migrou para o dono; os tokens rastreáveis pelo gate `Test-PrePushTraceabilityCoverage.ps1` e as sentinelas de self-test foram preservados nus, então o token-check do gate não foi alterado.
- Consolidação conservadora: 1 ponteiro por script distinto (bullet multi-script vira N ponteiros); os wrappers de build embutidos (`Invoke-GeneXusKbBuildAll`/`SpecifyGenerate`) ganharam ponteiro dedicado. Seções não-script intocadas (governança, `PrivateMap`, `Inferência forte`, `Regra operacional`/`Regra editorial`, histórico empírico `KB_Teste_*`).
- Downstream: `AGENTS.md` (alinhamento entre documentos), `08-guia-para-agente-gpt.md` e `13-revisao-pre-push.md` passaram a descrever o `09` como índice de ponteiros (a comparação verifica ponteiro→dono + papel, não o detalhe); `998-ideias-descartadas-e-porque.md:1446` reancorado da regra UTF-8 sem BOM ao dono `02-regras-operacionais-e-runtime.md:1075`; entrada no `CHANGELOG.md`.
- Trava anti-regressão (candidato 1): novo sinal consultivo `PUBLIC_TRACEABILITY_VERBOSE_LINE` no `Test-PrePushTraceabilityCoverage.ps1` — detecta deterministicamente uma entrada de script que volte ao formato verboso antigo (rótulo `Evidência direta` colado num caminho `scripts/`); `warn`, invariante, com o self-test novo `Test-PrePushTraceabilityCoverageSelfTest.ps1` (o gate não tinha self-test). O candidato 2 (gêmeo `09↔dono`) ficou como ideia no `999`.
- Formato e regras validados por painel de revisão por pares multi-modelo (Claude Opus nativo + Codex gpt-5.5 + deepseek-v4-pro + minimax-m3), que pegou a duplicata `02:1075` (que parecia órfã), a consolidação ampla-demais (que apagaria ~19 scripts do llm-delegate) e a necessidade de `.ps1` na Validação. Os modelos Mistral Large 3 e Nemotron 3 Ultra foram vetados na mesma frente por baixo aterramento.

### Decisao final

Caminho A (enxugar) sobre o status quo: o `09` permanece índice agregado e perde a duplicação de detalhe que driftava. Tokens nus preservados mantêm o gate verde sem rework; a trava `PUBLIC_TRACEABILITY_VERBOSE_LINE` impede a verbosidade de voltar silenciosamente.

### Rastreabilidade

- Commit: `33bd9aa` (`governanca: veta Mistral Large 3 e Nemotron 3 Ultra na lista de modelos a evitar`)
- Commit: `d8844c4` (`wip: enxuga o 09 (inventario) — secao motor operacional compartilhado parcial`)
- Commit: `45dbc2b` (`enxuga o 09: motor compartilhado + skill experimental MSBuild → ponteiros`)
- Commit: `a259358` (`09 enxuto: downstream (AGENTS/08/13 + 998 + CHANGELOG)`)
- Commit: `ae58629` (`Trava anti-regressao do 09 enxuto: sinal PUBLIC_TRACEABILITY_VERBOSE_LINE`)
- Commit: `55391a0` (`historico: migra o enxugamento do 09 do 999 e conserta particao do fingerprint`)
- Commit: `720f1f6` (`999: registra a faceta b (gate "motor novo sem entrada no 09") com decisoes abertas`)

## Formalizar o ciclo «Revisão por Pares» (validação de plano por painel multi-modelo)

**Importancia original:** média
**Status:** implementada em 2026-06-17

### Origem

Registrada no `999-ideias-pendentes.md` em 2026-06-14 (sessão do Plano B). O nome «Revisão por Pares» foi escolhido pelo usuário, ancorado no conceito acadêmico de *peer review*. A formalização foi pedida e executada em 2026-06-17, ela própria conduzida pelo ciclo que formaliza (dogfooding: painel multi-modelo v1→v4 sobre o plano, com Codex pegando gaps de paridade que os demais não pegaram e Claude Code corrigindo o alvo de migração defasado por edição paralela).

### O que foi implementado

- Novo `15-revisao-por-pares.md`: metodologia genérica de revisão por pares (manuscrito = leitura do problema + solução + fontes + decisões em aberto → painel independente de modelos distintos que leem as fontes → *revise-and-resubmit* → convergência do painel inteiro sobre a versão final → execução liberável após nó humano). Tornado **fonte normativa** da régua de convergência, mapeada regra-a-regra (versões de manuscrito, não commits; "pronto" = execução liberável, não push). Inclui papéis (agente monta/opina, humano decide), composição (famílias distintas, política do README), confidencialidade (autor classifica o manuscrito + gate por revisor), livro-razão opcional em `Temp\revisao-por-pares\<ts-ou-guid>\` e prompt mínimo.
- Estrutura **C pura**: o `14-revisao-pre-push-reforcada.md` virou a **aplicação pré-push** do `15` — a seção "A régua" e os papéis deixaram de ser atribuídos ao `14` e passaram a remeter ao `15`, mantendo só o específico de pré-push (prompt verbatim, *stale*-por-commit, push-ready, lista de modelos). Reconciliadas as paráfrases da régua em `09:93` e `08:121` (apontam ao `15`); `13:7`/`AGENTS:58` ficaram (ponteiros corretos ao tier pré-push).
- Skill `xpz-llm-delegate`: cross-ref ampliado (revisão por pares → `15` genérico + `14` pré-push), gatilho novo nos `TRIGGERS`, e o motor `scripts/Build-LlmDelegateCapabilityManifest.ps1` (sonda backends instalados + enumera modelos opencode/Codex via config — Claude/Copilot/Gemini sem enumeração nativa —, reusa os `Resolve-*ModelLocality`; manifesto **sanitizado** machine-level `%LOCALAPPDATA%\xpz-llm-delegate\capabilities.json` + snapshot por-KB opcional em `Temp/`; dica de oferta, nunca verdade do gate) com self-test `scripts/Test-LlmDelegateCapabilityManifestSelfTest.ps1`.
- `xpz-kb-parallel-setup`: oferta gravar o snapshot no momento (opcional, não-bloqueante) da política de delegação; motor incluído no `setup-contract.manifest.json` (dispara re-auditoria de contrato).
- Paridade: `00-indice-da-base-genexus-xpz-xml.md`, `09-inventario-e-rastreabilidade-publica.md` (entradas novas + reconciliação), `08-guia-para-agente-gpt.md`, `AGENTS.md`, `README.md` (trilíngue), `CHANGELOG.md` (trilíngue).

### Decisão final

Estrutura C pura (15 = metodologia genérica/normativa; 14 = aplicação pré-push) convergida por painel multi-modelo diverso (Claude Code, Codex gpt-5.5, deepseek-v4-pro, glm-5.1, minimax-m3, kimi-k2.7-code) em quatro versões. O manifesto de capacidade é **dica de oferta sanitizada, nunca verdade do gate** (o `Resolve-LlmDelegateAuthorization.ps1` reavalia destino e sensibilidade sempre); capacidade ≠ autorização (arquivos separados); snapshot por-KB em `Temp/` (gitignored, cache re-derivável). Resíduos deixados abertos como futuros no `999`: harness de disparo do painel, backends one-shot (`llm`/`mods`) e personas de revisão.

### Rastreabilidade

- Commit: `0267a5b` (`Revisão por Pares: cria o 15 (metodologia genérica) e aponta 14 + xpz-llm-delegate a ele`)
- Commit: `d191ca7` (`Revisão por Pares: motor de capacidade + oferta de snapshot no setup`)
- Commit: `b9def3e` (`Revisão por Pares: paridade downstream (00/08/09/AGENTS/README/CHANGELOG)`)

## Auditoria detecta drift de contrato de consumo de motor (`consumes_legacy_text_stdout`) + regra de lockstep pré-push

**Importancia original:** média-alta
**Status:** concluída (etapa 1) em 2026-06-20

### Origem

Duas entradas do `999-ideias-pendentes.md` (introduzidas nos commits `7442e19` e `f8b529b`), apontadas por agente mantenedor de pasta paralela após o push da frente do contrato JSON do `Sync-GeneXusXpzToXml.ps1` (`e11ffbc`/`ef8530b`). O plano foi convergido por **revisão por pares** (painel multi-modelo via `xpz-llm-delegate`: Claude nativo, Codex gpt-5.5, deepseek-v4-pro, kimi-k2.7-code, glm-5.2, minimax-m2.7 — 6 revisores / 4 famílias) com closeout auditado (RoundId `drift-consumo-contrato-2026-06-20-r1`; v2 = endurecimento, re-submissão declinada pelo humano com registro no recibo).

### Problema concreto

A frente do contrato JSON do sync fez breaking change no stdout do motor (texto `Format-List` → JSON `Kind=xpz-sync-result`/`SchemaVersion=1`), mas a skill que **audita** os wrappers locais consumidores (`xpz-kb-parallel-setup`, via `scripts/Test-XpzWrapperInventory.ps1`) **não** ganhou check correspondente. Um `Update-*KbFromXpz.ps1` que ainda consome o stdout textual antigo passava como `INVENTORY_OK`/não-customizado — defasagem invisível ao gate de setup. Em paralelo, faltava a regra de método que evita a CLASSE do erro (todo motor compartilhado consumido por wrapper local).

### Implementacao

- **B (núcleo):** `scripts/Test-XpzWrapperInventory.ps1` ganhou um bloco dedicado (escopado a `baseName -ieq 'Update-KbFromXpz'`, separado do bloco K8/K9) que emite `INVENTORY_CUSTOMIZED(reason=consumes_legacy_text_stdout)` quando o molde `Update-KbFromXpz.example.ps1` consome `ConvertFrom-Json` e o wrapper local não — mesma mecânica heurística texto-vs-molde do precedente `missing_AsJson_passthrough`. Limite documentado no próprio código: heurística textual conservadora, não detecta migração parcial nem parsers alternativos (`System.Text.Json`).
- **D (doc + teste):** `xpz-kb-parallel-setup/SKILL.md` — dimensão "consome o contrato de saída ATUAL do motor" na classificação 8.a.ii e o motivo novo na tabela 8.h e na regra de `INVENTORY_CUSTOMIZED` por motivo (linhas do catálogo). Self-test `scripts/Test-XpzWrapperInventorySelfTest.ps1` estendido (wrapper textual → sinalizado; wrapper migrado para JSON v1 → não sinalizado).
- **Regra de método (lockstep, commit isolado):** `13-revisao-pre-push.md` (§3 Comparação documental), `AGENTS.md` raiz (Revisão pré-push) e o espelho no `08-guia-para-agente-gpt.md` passam a perguntar, na fase semântica, se uma frente que altera de forma *breaking* o contrato de consumo de um motor compartilhado deu à skill que audita os consumidores o check de drift no mesmo PR.
- **Paridade:** `09-inventario-e-rastreabilidade-publica.md` (linhas-ponteiro do motor e do self-test), `CHANGELOG.md` (trilíngue, registrando o efeito de alteração de assinatura de `setup-contract.manifest.json`). `02`/`README` verificados e descartados (não mantêm catálogo de motivos nem citam o inventário); `08-guia-para-agente-gpt.md` **não** foi descartado — recebeu o espelho da regra de lockstep. `setup-contract.manifest.json` não editado (assinatura derivada do conteúdo).

### Decisao final

Discriminador único `ConvertFrom-Json` (não os tokens `$result.Campo`/`Get-ResultValue`/`Format-List`, que existem no molde correto e dariam falso positivo), fiel ao precedente. O sub-check de roteamento por stderr foi deixado para o follow-up de versão-de-contrato. A regra-doc de lockstep ficou na mesma frente, em commit isolado (compromisso do dissidente glm no Q2, que defendia frente irmã). **Adiado como follow-up no `999` (etapa 2 = C + gate consultivo):** amarrar `SchemaVersion`/`Kind` a uma versão-de-contrato confrontável e um gate consultivo análogo a `Test-PrePushSharedScriptSkillCoverage.ps1` focado em skill auditora. Limite registrado explicitamente: o check atual é **cego a drift de versão dentro do JSON** (um wrapper que parseia v1 com `ConvertFrom-Json` passa mesmo com o motor em `SchemaVersion=2`); gatilho de revisão = próximo bump de contrato.

### Rastreabilidade

- Commits de fechamento desta frente: ver `CHANGELOG.md` (`Unreleased`, trilíngue) e `git log` da frente «drift de contrato de consumo» (closing commits desta sessão; visíveis via `git blame` no arquivo mensal, conforme `historico/AGENTS.md`).

## Variante de prompt read-only para vozes "coder" do painel — investigação concluída (truncamento = não-determinismo raro; fix = `-MaxAttempts`)

**Importância original:** baixa (workaround conhecido de dispatch de revisor).
**Status:** investigação concluída em 2026-06-22; corroborada por experimento controlado em 2026-06-23. Fix (`-MaxAttempts`) já implementado e no despacho do painel. Frentes derivadas de **segurança** seguem **abertas** no `999`.

### Origem

Teste do ollama-cloud durante a reforçada do pacote `.ContainsKey`+429 (2026-06-21): vozes coder (`kimi-k2.7-code`, `minimax-m3`) pareciam truncar (`reason=tool-calls`, Achado D) com o prompt que manda **executar** a rotina. Levantou-se a hipótese de uma "variante read-only" de prompt como mitigação.

### Investigação e evidência

- **CONTESTAÇÃO (2026-06-21):** a tese "coder trunca por tool-calls" não se reproduziu de forma confiável; os logs do opencode mostraram que os runs truncados **pós-renovação** **não tinham 429** → não era cota mascarada.
- **RESOLUÇÃO (2026-06-22):** 8 chamadas `-Raw`. Orçamento-de-passos **refutado** (kimi fez 7 tool-calls e fechou no 8º passo com `reason=stop`); truncagem **real mas intermitente e rara** → hipótese sobrevivente = **não-determinismo de cauda**.
- **Experimento controlado (2026-06-23):** 12 chamadas, 4 modelos × 3, **sequenciais** (sem concorrência de cota), `-Raw`, medindo o último `step_finish.reason` + 429 por janela. Resultado: kimi-k2.7-code 3/3 `stop`, deepseek-v4-pro 3/3 `stop`, glm-5.2 3/3 `stop`; minimax-m3 = 1 cheia (`stop`, 16k) / 1 `stop` raquítica (414 chars) / 1 **truncada** (`reason=tool-calls`, 28 `tool_use`, **sem 429**). Confirma: não é cota, não é propriedade fixa de "coder" (kimi, coder, completou 3/3), é instabilidade intermitente específica do minimax-m3.

### Decisão final

- **Correção implementada:** `-MaxAttempts` (retry-once opt-in) em `scripts/Invoke-OpenCode.ps1` — agnóstica à causa (re-sorteia o não-determinismo; re-tenta só `truncated`/`no-completion`, com guarda anti-429), já passada como `MaxAttempts=2` no `scripts/Invoke-LlmDelegatePanelDispatch.ps1` (despacho do painel). Self-test `Test-OpenCodeRetrySelfTest.ps1`.
- **"Variante read-only por prompt" descartada como solução de truncamento:** não se faz por prompt (`--agent plan` **auto-aprova bash em headless** — refutado empiricamente). A substância de menor-privilégio migrou para frentes de **segurança** que seguem **abertas** no `999` («Painel … concede execução de código…» e «Agente reviewer sem execução/escrita»).
- **Gap derivado novo:** resposta `stop` porém quase-vazia (minimax-m3 run2, 414 chars) é classificada como `ok` e escapa do veredito e do retry — registrada como entrada própria no `999`.
- Convergência por **revisão por pares** (v1→v5, 5 vozes / 3 famílias: anthropic nativo, openai/Codex gpt-5.5, ollama-cloud deepseek-v4-pro/glm-5.2/kimi-k2.7-code) em 2026-06-22; o painel de 2026-06-23 (mesmas 3 famílias) corrigiu o rumo da migração (**histórico, não 998** — a ideia foi resolvida/implementada, não rejeitada) e confirmou os gaps.

### Rastreabilidade

- Commit material (frente fechada em sessão anterior, já em `origin/main`): `7713dc6` — "Invoke-OpenCode: retry-once opt-in (-MaxAttempts) + achados de segurança/reviewer no 999"; follow-ups `b0c2e20` (precedência/429) e `52db98b` (comentário do laço de retry).
- Código (já existente): `scripts/Invoke-OpenCode.ps1` (`-MaxAttempts`), `scripts/Invoke-LlmDelegatePanelDispatch.ps1` (`MaxAttempts=2` no despacho), `scripts/OpenCodeStreamSupport.ps1` (`Get-OpenCodeCompletionVerdict`), `scripts/Test-OpenCodeRetrySelfTest.ps1`, `CHANGELOG.md` (entrada do retry).
- `999-ideias-pendentes.md` — entrada → ponteiro «RESOLVIDA E MIGRADA»; frentes de segurança derivadas seguem **abertas**.
- Revisão por pares: livro-razão efêmero em `Temp/xpz-llm-panel-dispatch/` (gitignored).

## Motor de export/materialização legado GeneXus 9 (consumidor do registro `gx-legacy-export-element-registry.json`)

**Importância original:** média (gap real com workaround — KBs GeneXus 9 não sincronizavam pelo fluxo XPZ→XML).
**Status:** implementada em 2026-06-25 (parser/conversor + integração nos ramos Sync/Inventory + metadata `-IsLegacyExport` + self-tests ponta-a-ponta verdes). Pré-push reforçada e push são passos de processo (humanos), não resíduo de ideia. Resíduo derivado **novo** (deferido por design à época) registrado à parte no `999`: colisão cross-fluxo moderno↔legado — **implementada depois** em 2026-06-25/26 (ver a entrada própria no topo deste arquivo; a entrada do `999` foi então removida).

### Origem

"O resto do PR de export legado" (autor Felipe Neves): a camada de representação/governança (registro `gx-legacy-export-element-registry.json` + doc-dono `01k`) já existia; faltava o **motor** que a consome — parse do `ExportFile` GeneXus 9 (`<GXObject><Elemento>` por nome, sem GUID de tipo), materialização em `ObjetosDaKbEmXml` e integração no sync/inventário. Gatilho de caso real atendido em 2026-06-24 (amostra `FinGX90`, KB "Financeiro", gitignored em `Temp/`), que corrigiu o registro empiricamente (10 equivalent + 2 orphan).

### Implementação

- **Parser/conversor próprio** `scripts/GeneXusLegacyExportFileSupport.ps1` (motor isolado, commit local `d4706ff`): converte `/ExportFile/GXObject/<Elemento>` e `/ExportFile/Attributes/GXAtt/Attribute` em envelopes modernos `Object`/`Attribute` (`dataSource="gx-legacy-export"`, payload em `GxLegacyPayload`, `guid=""`), consumindo o registro (equivalent→GUID real do catálogo; orphan→`type="gxlegacy/<Elemento>"`); sentinela `0001-01-01` para `lastUpdate` ausente; fail-closed para misto/tag-fora-do-registro/>1-filho/colisão.
- **Integração (PASSO 4)** nos ramos legados de `scripts/Sync-GeneXusXpzToXml.ps1` (leitura encoding-aware `XmlDocument.Load`; ordem perfil→misto-throw-sem-metadata→catálogo→itens-fail-closed→metadata→materializar; ramo moderno inalterado; `LegacyFormatDetected`/`legacy-export-adapted` no JSON) e `scripts/Get-GeneXusImportPackageObjectInventory.ps1` (leitura `.xpz` `Load($entry.Open())`; itens `known-legacy`; `unknownTypeCount=0`/`unknownTypesDiscovery=[]`; delta órfão registry-aware).
- **Metadata** `scripts/XpzKbSourceMetadataEditSupport.ps1`: `-IsLegacyExport` usa `KMW/MaxGxBuildSaved` como Build e emite hint legado no lugar do warning genérico.
- **Self-tests:** `Test-GeneXusLegacyExportFileSupportSelfTest.ps1` (motor isolado), `Test-XpzSyncLegacyExportFullSnapshotSelfTest.ps1` (reproduz/resolve o crash StrictMode `property 'Guid'` sob `-FullSnapshot`), `Test-XpzKbSourceMetadataLegacySelfTest.ps1` (ramo legado + não-regressão moderna) e `Test-XpzInventoryLegacyExportSelfTest.ps1` (ramo legado do Inventory por processo filho; follow-up da pré-push reforçada). Parse gate 289/0.
- **Doc/paridade:** `01k`, `02`, `08`, `09`, `README` (3 idiomas), `CHANGELOG` (3 idiomas), `xpz-sync/SKILL.md` (seção EXPORTS LEGADOS), `xpz-reader/SKILL.md` (envelope `gx-legacy-export`/`GxLegacyPayload`), `scripts/README-kb-intelligence.md`, `xpz-kb-parallel-setup/SKILL.md`.

### Decisão final

Plano **convergido/congelado por revisão por pares** Fase 2 (6 rodadas, manuscritos v2.6→v2.8.5; 5 revisores / 3 famílias: anthropic nativo, openai/Codex gpt-5.5, ollama-cloud kimi-k2.7-code/glm-5.2/deepseek-v4-pro). Decisão de não versionar a fixture iso-8859-1 (Opção B): gerada on-the-fly em Temp pelo `GeneXusLegacyExportFileFixtureSupport.ps1`. `Theme` segue presumido (não observado na amostra desktop) — coberto por fail-closed de tag desconhecida. Limitação conhecida deferida por design (manuscrito §9): `Write-ItemToDestination` ignora `dataSource`, então um objeto materializado por moderno e depois por legado pode sobrescrever silenciosamente — rara; documentada no `01k` e registrada como entrada própria no `999`.

### Rastreabilidade

- Código: `scripts/GeneXusLegacyExportFileSupport.ps1`, `scripts/GeneXusLegacyExportFileFixtureSupport.ps1`, `scripts/Sync-GeneXusXpzToXml.ps1`, `scripts/Get-GeneXusImportPackageObjectInventory.ps1`, `scripts/XpzKbSourceMetadataEditSupport.ps1` + 4 self-tests.
- Commit base do motor isolado: `d4706ff` (`Co-Authored-By: Felipe Neves`). Commits do PASSO 4 (integração + doc): ver o commit de fechamento desta frente.
- Revisão por pares Fase 2: manuscrito congelado em `Temp/revpares-pr1motor/manuscrito-v2.8.5-fase2-CONGELADO.md` (gitignored).
- `999-ideias-pendentes.md` — entrada do motor retirada (esta migração); substituída pela entrada nova da limitação §9.
