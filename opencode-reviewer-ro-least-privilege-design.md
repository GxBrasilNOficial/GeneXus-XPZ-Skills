# Least-privilege do revisor opencode — "sem execução/escrita" (design congelado, escopo D-min)

## Papel do documento

Design **congelado** da frente de segurança das entradas #1+#2 do `999-ideias-pendentes.md`
(least-privilege do revisor opencode). Congelado por revisão por pares: **8 rodadas**, **4 famílias**
(anthropic, openai, ollama-cloud, nvidia), arquitetura **nunca reaberta**; encerramento por freeze
(`resubmissionDeclinedByHuman`, motivo "prova transferida para implementação e self-test"). Este
documento é a fonte-verdade da implementação; a prova dos claims empíricos vive nos self-tests.

## Problema

O painel de revisão-por-pares (`xpz-llm-delegate`) despacha revisores opencode. Em `opencode run`
headless, o agente default `build` (e `--agent plan`) **auto-aprova** `bash`/`edit` sem gate — o
revisor pode executar comandos e editar arquivos. Incidente real (2026-06-24): um revisor opencode
(`kimi-k2.7-code`, agente default) **editou** um `.md` do repo. O harness
`scripts/Invoke-LlmDelegatePanelDispatch.ps1` **bloqueia** a chave `agent` do opencode
(`$ContentionKeys['opencode']=@('agent')`, `:113`; classificação `:230-237`), então não há via
oficial para passar um agente seguro — o revisor sempre cai no `build`. A mitigação atual é só
textual (`xpz-llm-delegate/SKILL.md:818-842`). O gate `Resolve-LlmDelegateAuthorization.ps1` governa
**se o dado sai** (`public`→`allow` automático em `:173-178`), **não** a capacidade de executar/ler
local.

Eixos de risco: (i) execução/escrita local; (ii) exfiltração (agravante do modelo externo).

## Escopo D-min (o que esta frente faz e o que NÃO faz)

- **Fecha:** escrita/execução (`bash`/`edit`) e as **ferramentas** de rede (`webfetch`/`websearch`).
- **NÃO fecha (residual nomeado e aceito em `public`):** o canal do próprio parecer ao provider
  (inerente a qualquer revisor externo). `external_directory` bloqueia por padrão leitura fora
  do workspace do cwd (ver D4), mas não prova isolamento absoluto nem torna o cwd seguro.
- **ADIADO para outra sessão:** liberar opencode em `kb-sensitive`/pasta paralela de KB, e mecanizar
  a contenção de leitura (cwd-seguro). Hoje opencode em `kb-sensitive` é `unavailable`
  (`Invoke-LlmDelegatePanelDispatch.ps1:253-258`).

## Decisões (D1–D4)

### D1 — Postura segura no ADAPTER, escopada ao caminho revisor

<!-- backend-parity: ignore -->
`Invoke-OpenCode.ps1` e `Start-OpenCodeJob.ps1` ganham **default `-Agent reviewer-ro`** (`$Agent`
hoje é opcional sem default). Espelha os 4 backends que fixam a postura no adapter: claude-code
`Invoke-ClaudeCode.ps1:41` (`plan`), codex `Invoke-Codex.ps1:133` (`-s read-only`), gemini
`Invoke-Gemini.ps1:36`+`:49-51` (throw≠plan), copilot `Invoke-Copilot.ps1:96` (`--available-tools=`
vazio; `--allow-all-tools` em `:97` é **necessário** pelo CLI e vira no-op sob cardápio vazio). O
painel bloqueia `agent` (`:143`) → o revisor **sempre** cai no default `reviewer-ro`.

**Escopo do enforce (fold-in G2):** o enforce read-only do D2 vale quando o **agente efetivo é o
default `reviewer-ro`** (o caminho revisor). Um chamador que passa `-Agent <x>` **explicitamente**
faz **opt-out consciente** (uso agêntico legítimo fora do painel) — não é barrado pelo enforce
read-only, mas o pré-check ainda confirma que o agente pedido **resolve** (existe), para não recair
no fallback silencioso ao `build`. Override ⇒ o **chamador assume a postura de segurança**. O
opt-out só existe em chamadas diretas do adapter (fora do painel); dentro do painel o `agent` é
sempre bloqueado. Mudança de default é **breaking change** documentada no `CHANGELOG`; uso agêntico
não-revisor exige `-Agent <x>` explícito.

D1 e D2 são **inseparáveis** (default + pré-check gravados juntos): nunca existe "default sem guard".

### D2 — Guard fail-closed no ADAPTER (runtime)

`--agent <ausente/errado>` **não falha** — cai **silenciosamente** no `build` (`* allow *`); warning
verbatim medido: `agent "..." not found. Falling back to default agent`.

**Pré-check (no adapter, ANTES do `Start-Process`) — mecanismo de RUNTIME.** No caminho revisor
(agente efetivo = reviewer-ro), o despacho só ocorre se TODAS passarem:
1. frontmatter estático do `reviewer-ro` confere (determinístico, não toca o DB do opencode);
2. `opencode agent list` confirma que o **allow-set resolvido é EXATAMENTE `{read,grep,glob,list}`**
   — assere o **conjunto** (trava divergência por **ausência** E por **excesso**, ex.: `bash`
   reaparecendo por regra tardia da config global);
3. versão do opencode é a testada.

Qualquer falha — agente ausente, allow-set divergente, versão não-testada, **ou** falha/timeout/erro
SQLite do próprio `agent list` (mesmo com o estático OK) — ⇒ **BLOCK**. `agent list` é **intermitente**
(mediu-se falha transitória SQLite `PRAGMA wal_checkpoint(PASSIVE)`); retry curto, senão BLOCK. O
estático é primário (barato/determinístico) mas **não dispensa** o `agent list` — só ele prova a
**resolução efetiva** (contra regra tardia da global). **Fail-closed TOTAL** (não existe "despachou
sem confirmar"). O BLOCK registra no recibo **qual** check falhou: **estático divergente**
(= provisionamento quebrado → consertar o `reviewer-ro`) vs **`agent list` falho/SQLite**
(= transitório → retentar). Contingência (fold-in E): se `agent list` se provar instável demais em
campo, cair para estático + hash do arquivo, aceitando o ponto cego de merge-global (frente futura).

**Pós-check (DEFESA-EM-PROFUNDIDADE, não a barreira).** Síncrono (`Invoke-OpenCode.ps1`): lê o
CONTEÚDO de `$err` (arquivo temp descartado no `finally` em `:200`) **antes** do `Remove-Item`, e
varre pelo warning de fallback. Assíncrono: `Start-OpenCodeJob.ps1` mantém artefatos do job por
idade e `Watch-OpenCodeJob.ps1` lê o stderr persistido. Depois do contrato v2 do watcher, fallback
assíncrono para `build`/default não é mais apenas diagnóstico aceitável: ele invalida o aceite
técnico (`resultAccepted=false`, `watcherExitCode=20`) e só permanece como diagnóstico em
`fallbackDetail`.

**Limite operacional:** o fail-closed torna o opencode-revisor **indisponível** sob contenção
transitória de SQLite. Registrar `unavailable` (+ motivo) no recibo e aplicar a régua normal de
diversidade — **não** presumir "a diversidade não quebra": se a **única** família ollama cair por
SQLite, a rodada pode ficar **abaixo do piso** → declarar + re-despacho humano.

### D3 — Provisionamento

**Ordem: D3 (provisionar) ANTES de D1+D2 (ativar).** Sem o `reviewer-ro` provisionado, o default do
adapter cairia no fallback ao `build` — mas o pré-check do D2 **bloqueia** nesse caso (fail-closed:
roda seguro, porém indisponível). Não inverter.

**(a) Project-local (fonte canônica):** `.opencode/agent/reviewer-ro.md` versionado na **raiz do
repo** (descoberto pelo cwd do painel). **Exceção no `.gitignore`** necessária (o `.gitignore` usa
`/*` + allowlist; `.opencode/` não é allowlistado): habilitar **só** o arquivo do agente, não o
estado runtime do opencode:
```
!/.opencode/
!/.opencode/agent/
!/.opencode/agent/reviewer-ro.md
```
Forma `permission` com **default-deny curinga** (medido — last-match-wins):
```yaml
permission:
  "*": deny            # PRIMEIRO — default-deny; tool não-listada cai aqui (robusto a tools futuras)
  read: allow
  grep: allow
  glob: allow
  list: allow
  edit: deny           # reforço documental (já coberto por "*": deny)
  bash: deny
  webfetch: deny
  websearch: deny
  task: deny
  external_directory: deny   # bloqueia por padrão leitura fora do cwd (ver D4)
```
`mode: all` (garante seleção por `--agent` em headless). Medido em opencode 1.17.20: `permission:deny`
≡ `tools:false` (resolvem idêntico, removem a tool em headless); `webfetch/websearch/task: deny`
removem as tools; `"*": deny` curinga funciona. A nota de `999:168` ("`tools:false` mais forte que
`permission:deny`") é **refutada pela medição** — corrigir **condicionada** ao self-test confirmar.

**(b) Global (qualquer cwd):** instalador dedicado `scripts/Install-OpenCodeReviewerRoAgent.ps1`,
**dono `xpz-llm-delegate`**. `Read-McpRoot` de `Install-CursorGlobalInstructionsMcp.ps1:191-213` é
hardcoded para `mcpServers` e **não** reusável → função nova. Alvo:
`~/.config/opencode/opencode.jsonc`. **Contrato:** edição **localizada** do bloco
`agent.reviewer-ro` preservando comentários/formatação/demais chaves (não reescrita total); a
definição global é **derivada** do markdown project-local (fonte única) + guard de deriva por
self-test; passo de **migração** do interino global (forma antiga `tools:` → `permission`). O
`xpz-skills-setup` ganha **só** um hook de auditoria read-only citando este instalador como
dependência de setup (o `agentsPath` dele é do MCP do Cursor — `999:167` — não cobre agentes
opencode).

**Global-only e project-local resolvem o contrato least-privilege:** o global provisionado e o
project-local resolvem `*` final `deny` + allow-set `{read,grep,glob,list}`. A captura sanitizada
1.17.20 ficou byte-equivalente entre os dois caminhos; isso cobre o contrato efetivo fora da raiz
do repo, mas não deve ser lido como prova independente de semântica de merge/substituição campo a
campo.

**Pré-requisito de cwd:** opencode **não** recebe `-Cd` (`Invoke-LlmDelegatePanelDispatch.ps1:362-363`
`$cdCapable` exclui opencode; `:373` `(Get-Location).Path` é código morto para opencode). Herda a
cwd ambiente (`Invoke-OpenCode.ps1:135`, `Start-Process` sem `-WorkingDirectory`).

### D4 — Escopo D-min; bloqueio padrão fora do cwd herdado; cwd-seguro é OPERACIONAL

Fecha escrita/execução e as **ferramentas** de rede (`webfetch/websearch` negadas) — **não** o canal
do parecer ao provider (residual aceito).

**Confinamento de leitura (MEDIDO):** a tool `read` **não** lê qualquer arquivo da máquina. O
opencode tem a dimensão nativa **`external_directory`** (base `action: ask`) que gateia leituras
**fora** do workspace do cwd; em `opencode run` headless o `ask` é **auto-rejeitado** → ler fora do
cwd é **bloqueado por padrão** (provado: agentes com e sem curinga ambos bloquearam a leitura
do arquivo-sentinela fora do cwd pela mesma regra base). `external_directory: deny` explícito
(D3) torna o padrão `external_directory[*]` bloqueado independente do modo. Em 1.17.20 há
exceções `allow` para diretórios internos do opencode, como o tool-output; elas não autorizam
tratar o cwd como "seguro" nem como proibição absoluta de todo path externo específico.
**Este achado INVERTE a premissa** de
`SKILL.md:838-840` (que hoje diz que `read` lê "qualquer arquivo") — tratar a reescrita da doc como
**correção de premissa**, versionada por fixture, condicionada ao self-test na versão instalada.

**Qual é o cwd:** herdado do orquestrador (`Invoke-OpenCode.ps1:135`, sem `-WorkingDirectory`);
opencode nunca recebe `-Cd`. Confinamento por **herança**, não por controle explícito.

**Garante / NÃO garante:** garante mecanicamente o bloqueio padrão de leitura fora do cwd herdado
(`external_directory`, self-test), sem provar isolamento absoluto de todo path externo específico.
**Não** mecaniza "o cwd é seguro" — não há BLOCK por cwd em `public` (só em `kb-sensitive`).
cwd-seguro em `public` é **operacional**: o operador dispara revisão `public` da raiz do repo de
skills (onde, medido, não há segredo REAL versionado — só iscas de self-test).
**Nota de operador** (em `SKILL.md`/`15`): "cwd-seguro é responsabilidade de quem dispara; se o cwd
contiver segredos não-versionados (`.env` local, logs, cache), o revisor pode lê-los; iscas de
self-test não substituem revisar segredos reais no diretório." Em 1.17.20 o OpenCode traz proteção
nativa `read "*.env" -> ask`, mas o bloco posterior `read "*" -> allow` do `reviewer-ro` tende a
anulá-la por `last-match-wins`; resolver esse recorte é urgente no `999`. Mecanizar cwd-seguro
pertence ao read-containment **adiado**.

Renomear "read-only" → **"sem execução/escrita"** (a leitura não está totalmente contida).

## Self-tests, fixtures e GATE DE ATIVAÇÃO

**Fixtures versionados** (capturados em opencode 1.17.20; ancoram os self-tests contra drift de
versão): warning de fallback; `agent list` do `reviewer-ro` (allow-set + `external_directory`);
equivalência `permission`↔`tools`; merge global↔project; `webfetch/websearch/task: deny` resolvido;
`"*": deny` curinga; **leitura fora do cwd bloqueada por padrão** em headless.

**Novo `scripts/Test-OpenCodeReviewerRoSelfTest.ps1`** (token `OPENCODE_REVIEWER_RO_SELFTEST_OK`):
(a) default `reviewer-ro` no argv (síncrono E assíncrono); (b) fail-closed com agente ausente /
`agent list` falho (⇒ BLOCK **esperado**, registrado) / versão não-testada / allow-set divergente,
distinguindo o **motivo**; (c) allow-set resolvido EXATAMENTE `{read,grep,glob,list}` — trava
divergência por **excesso** (ex.: `bash`), não só por ausência; (d) `external_directory` efetivo
**não** permite ler fora do cwd em headless; (e) pós-check lê `$err` cru (síncrono; assíncrono via
watcher); (f) regressão: `reviewer-ro` **não** edita E **não** faz webfetch; (g) o instalador global
preserva comentários/formatação/demais chaves do `opencode.jsonc`. **Não** há self-test de "cwd
`public` fora da raiz ⇒ BLOCK" (o D-min não mecaniza cwd-seguro).

**Detecção de versão:** o adapter detecta a versão instalada (`opencode --version`) e a cláusula de
validade compara contra a versão dos fixtures — não fixar uma versão como produção sem checar.

**Natureza HONESTA do gate (fold-in G1):** o **runtime** é protegido pelo **pré-check do D2**
(código, fail-closed) — esse é o mecanismo. O "bloqueio de ativação" pelos self-tests é um **GATE DE
PROCESSO/CI** (análogo ao closeout de `15:87`): os self-tests devem passar na versão-alvo
(pré-push/CI) **antes** de a frente ser considerada ativada e o default `-Agent reviewer-ro` ser
ligado. **Não** é mecanismo de runtime; o token no `09` é **rastreabilidade**, não enforcement.
Cláusula de validade: fixture que não reproduz na versão instalada ⇒ **não ativar** + revisitar
D2/D3.

## Paridade doc (fase final)

`xpz-llm-delegate/SKILL.md:818-842` (reescrever a seção "LIMITE CONHECIDO — OPENCODE…", inclui rename
"read-only obrigatório" → "sem execução/escrita" em `:842`; `external_directory` como **inversão de
premissa**), `:534-535`; `15-revisao-por-pares.md:83` (+ nota de operador cwd);
`xpz-skills-setup/SKILL.md` (hook de auditoria citando o instalador); `08-guia-para-agente-gpt.md`
(runtime da delegação); `09-inventario-e-rastreabilidade-publica.md` (scripts novos + token
`OPENCODE_REVIEWER_RO_SELFTEST_OK`); `CHANGELOG` (+ breaking-change do default); `999-ideias-pendentes.md:145-168`
(mover #1+#2 para `historico/IdeiasImplementadas_202607.md`; corrigir a nota `:168` condicionada ao
self-test; manter o eixo de leitura/`kb-sensitive` como entrada **adiada**). **NÃO** usar
`02-regras-operacionais-e-runtime.md` (é runtime do GeneXus/XPZ, não do harness de delegação).
README trilíngue: refletir em ES/EN se a regra operacional mudar.

## Ordem de implementação

1. **D3** — `.gitignore` (exceção); `.opencode/agent/reviewer-ro.md`; fixtures; instalador;
   self-test. Suíte verde.
2. **D1+D2** — `Invoke-OpenCode.ps1` (default escopado + pré/pós-check); `Start-OpenCodeJob.ps1`
   (default + pré-check no spawn); `Watch-OpenCodeJob.ps1` (contrato aceito/rejeitado; fallback
   invalida aceite).
3. **Doc** — paridade acima.
4. **Fechamento** — pré-push reforçada (revisão por pares do código real) → push (com ok humano).

## Proveniência

<!-- backend-parity: ignore -->
Congelado após 8 rodadas de revisão por pares (v1→v8) — anthropic (subagente nativo), openai
(Codex gpt-5.5), ollama-cloud (glm-5.2/kimi-k2.7-code/deepseek-v4-pro), nvidia
(glm-5.2/kimi-k2.6/deepseek-v4-pro/minimax-m3). Arquitetura nunca reaberta; freeze por decisão
humana com a prova transferida para os self-tests. Claims empíricos promovidos para opencode 1.17.20
(fixtures versionados).
