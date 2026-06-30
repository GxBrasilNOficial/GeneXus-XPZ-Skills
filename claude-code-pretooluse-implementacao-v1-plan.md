# Plano de implementação da v1 do daemon `PreToolUse` (auto-allow) do Claude Code

> **STATUS: CONGELADO (v2.22) — congelado em 2026-06-29 por Antonio José (antonio@frigobyte.com).**
> Este é o **plano de implementação** da v1 (o *como construir*), derivado dos designs congelados
> `claude-code-pretooluse-daemon-design.md` (v4 + §9-0e re-enquadrado) e
> `claude-code-pretooluse-auto-allow-design.md`. O **design** (arquitetura, transporte, §9-0e) **não**
> é reaberto aqui; este documento crava a precisão de implementação, os contratos e os self-tests.
>
> **Convergência por revisão por pares (régua de `15-revisao-por-pares.md`):** o plano evoluiu v1 → v2.22
> ao longo da campanha e a **versão final exata (v2.22)** foi confirmada pelo **painel inteiro — 5 linhagens
> de modelo distintas**, com **zero gaps de design** e **zero regressões**:
>
> | Linhagem | Modelo | Veredito (v2.22 exata) |
> |---|---|---|
> | anthropic | Opus 4.8 (subagente nativo) | CONCORDA — apto a congelar, sem regressão |
> | Moonshot | kimi-k2.7-code (opencode) | CONCORDA — estável para congelar |
> | Z-ai | glm-5.2 (opencode) | CONCORDA — "pode congelar v2.22" |
> | openai | Codex gpt-5.5 | CONCORDA — sem gap bloqueante |
> | DeepSeek | deepseek-v4-pro (opencode) | CONCORDA — zero gap de design, zero regressão |
>
> A arquitetura **nunca foi reaberta** nas ~22 versões; todas as objeções foram precisão de implementação/
> endurecimento fail-closed, e cada gap foi incorporado. Closeout mecânico (`xpz-llm-delegate`):
> `closeoutReady=true`, `vNextState=resubmitted`, 5 preferidos `responded`, piso de diversidade ≫ 2 famílias.
> A prova restante é **empírica** (spike do Passo B, self-tests do Passo E, medição do Passo F).
>
> **Escopo — Claude Code apenas; Windows x64 only.** Onde o cliente NativeAOT não rodar, o fio não liga e
> cai nos prompts de hoje (sem regressão). Refinações **§5(b)** (singleton garantido pelo daemon + cliente
> dispara-e-sai) e **G2(a)** (canonicalização do `cwd` por-requisição) são decisões humanas aprovadas.

## 1. Problema (resumo)

Latência ~520 ms/comando, dominada pelo startup do `pwsh` por chamada. §9-0f datada: **(b) cliente NativeAOT
+ named pipe + python persistente** no daemon. Passo 0: overhead do daemon ~1 ms; cauda p95 ~180 ms = piso de
spawn do cliente; §9-0e re-enquadrado: gate = **overhead-sobre-o-piso ≤ 5 ms**. O teardown do processo do
hook está no caminho crítico (o Claude Code lê stdout até EOF coincidente com o exit) — base do §5(b).

## 2. Invariantes (não-negociáveis, herdados do design §2)

Só `allow`/`defer`, nunca `deny`; **fail-closed** para `defer` em qualquer erro/timeout/ausência/versão
divergente/staleness/ambiguidade; **fonte única** da decisão E da tokenização = `ClaudeCodePreToolUseSafeAllowSupport.ps1`
(dot-source) + a mesma `classify` do `.py` (por import); o **cliente isolado NUNCA emite `allow`**.

## 3. Plano (Passos A–G)

### Passo A — Fonte única (tokenizador injetável; `-Decompose`; `classify` importável)
- `Support.ps1`: extrair `Get-PtuSegmentsVerdict($Parsed)` (NÃO é 2º despacho). `Get-PtuDecision` mantém TODO
  o despacho top-level (`Test-PtuCwdInScope`; switch `ToolName`: Bash / PowerShell→defer / default→defer;
  shape inválido → defer) e ganha `-Tokenizer` OPCIONAL.
- **Contrato do `-Tokenizer`:** delegate `string → objeto` com `status` (string) sempre; `segments` SÓ em
  `status=='ok'`. **Contrato formal de `segments`:** array-NÃO-VAZIO de arrays-NÃO-VAZIOS de strings.
  Validação StrictMode-safe: `$null -ne $Parsed`; `$Parsed.PSObject.Properties.Name -contains 'segments'`;
  o externo NÃO é string e é enumerável e não-vazio; **cada segmento NÃO é string escalar** (rejeitar string
  ANTES de enumerar — em PS string é `IEnumerable<char>`), é enumerável e não-vazio; cada token `-is [string]`
  (NÃO `-is [string[]]`, `ConvertFrom-Json` dá `object[]`); qualquer violação → `defer` (`@($null).Count` é 1).
  No daemon o `-Tokenizer` é o round-trip ao python persistente que roda a MESMA `classify`.
- **Modo `-Decompose`:** retorna SEGMENTOS da string crua via o MESMO `.py` one-shot (`Support.ps1` não tem
  tokenizer PS puro; reimplementar é proibido por §2.3). O gate do Passo A prova SÓ que o **canal persistente
  não corrompe os segmentos vs o one-shot (TRANSPORTE)** — NÃO a `classify` (seria circular). Fonte única da
  `classify` = por IMPORT; corretude = corpus §8 existente.
- `Get-ClaudeCodeBashSafeSegments.py`: extrair `classify(cmd)` importável (constantes COM a função). O
  `__main__` ONE-SHOT mantém UMA LINHA JSON (compatível com o self-test in-process atual). Novo
  `ClaudeCodePreToolUseSafeAllowDaemonShlexLoop.py` IMPORTA `classify` e fala LENGTH-PREFIXED. **Rejeição
  Unicode (fail-closed):** a `classify` rejeita categorias de controle/formato Unicode (Cc/Cf — zero-width
  U+200B/U+FEFF, bidi U+202E) em QUALQUER token → `defer`. `classify` exporta marcador = SHA256 do source em
  RUNTIME.
- **Gate do Passo A:** `Test-ClaudeCodePreToolUseSafeAllowSelfTest.ps1` VERDE antes e depois (rede de
  não-regressão) + comparar a LISTA DE SEGMENTOS byte-a-byte (in-process via `-Decompose` vs caminho-novo) no
  corpus adversarial.

### Passo B — Identidade (SID+repo+roots, §7) E escopo por UM `.cs` único, em DUAS compilações
- UM arquivo-fonte C# ÚNICO (`canonicalizePath` + P/Invoke `GetFinalPathNameByHandle`) em DUAS compilações
  SEPARADAS: (i) NativeAOT no cliente (entry-point); (ii) **DLL gerenciada de biblioteca non-AOT** (Add-Type
  -Path; sem SDK/Roslyn em runtime).
- **Pin sem circularidade:** target MSBuild computa SHA256 do `.cs` SOURCE e GERA arquivo SEPARADO
  (`BuildPin.g.cs`) com a constante; o `.cs` nunca é alterado. **`buildContractPin` = SHA256( `.cs` source +
  o gerador do `BuildPin.g.cs` + APENAS props semânticas IDÊNTICAS nas duas compilações que afetam
  `canonicalizePath`: `InvariantGlobalization`, `TargetFramework`, `LangVersion` )**. EXCLUI knobs que diferem
  por natureza entre AOT e DLL (`PublishAot`, `OutputType`, `TrimMode`, root descriptors) — incluí-los faria o
  pin divergir SEMPRE → todo request `defer` → daemon inútil. A garantia residual fica no spike (canonicalizePath
  byte-idêntico empírico).
- **`canonicalizePath`:** handle com `FILE_FLAG_BACKUP_SEMANTICS` (dir); `GetFinalPathNameByHandle`
  `VOLUME_NAME_DOS` + fallback explícito GUID→letra; remover `\\?\`/`\\?\UNC\`; `ToLowerInvariant()` EXPLÍCITO;
  sem AppDomain/reflexão (DllImport AOT-safe); `InvariantGlobalization` consistente nas duas. Timeout do
  open-handle por worker (ver Passo A-escopo). Inválido/timeout → `defer`.
- **Identidade (sem `PTU_REPO`):** `IdentityHash = SHA256(sid + "\0" + repoCanonical + "\0" + rootsCanonical)`.
  `repoCanonical` = `canonicalizePath` da RAIZ DO REPO por ASCENSÃO determinística da localização do binário/
  script. **Sentinela primário = marcador dedicado `.ptu-safe-allow-root`** na raiz do repo (criado pelo
  install — Passo G), único e editorialmente estável (não o `.md`, que move/renomeia; não `.git`, que aninha).
  Regra de parada precisa: casar EXATAMENTE o nome normalizado; parar no PRIMEIRO match ao subir; conjunto +
  regra de parada IDÊNTICOS nas duas compilações. **Fail-closed:** ZERO, MÚLTIPLOS ou AUSENTE → identidade
  INVÁLIDA → `defer`. `rootsCanonical` = cada root de `Get-PtuRoots` por `canonicalizePath`, dedup, ordenado
  ordinal, `;`. (Roots largos como `C:\Dev` → `repoCanonical` distinto evita colisão entre checkouts.)
- **Spike (gate do Passo B):** o `.cs` byte-idêntico (i) entra no publish AOT E (ii) compila como DLL
  Add-Type-ável SEM `#if`; `canonicalizePath` byte-a-byte idêntico EXE-AOT vs DLL no corpus — incl. NÃO-ASCII
  (İ turco, ß), `\\?\`, volume-GUID, UNC, junction aninhado, symlink de arquivo, relativo a drive; **paridade
  cliente↔daemon de `repoCanonical`** (ascensão à raiz; regra de parada idêntica; fail-closed; fixture `.git`
  ancestral + marcador órfão em ancestral intermediário + EXE em subpasta profunda vs daemon em `scripts\`) E
  de `rootsCanonical`; timeout do open-handle PROVADO contra UNC inacessível sem acúmulo descontrolado;
  trimming + `InvariantGlobalization` + P/Invoke idênticos; `buildContractPin` idêntico. Falhou → plano-B (lib
  sem entry-point + shim só no cliente, canonicalização byte-idêntica); decisão volta ao autor.
- Nomes do MESMO hash: pipe, mutex singleton, mutex guarda, log.

### Passo A-escopo — G2(a): `Test-PtuCwdInScope` canonicaliza o `cwd` POR-REQUISIÇÃO; threading
- A DLL é carregada 1× na subida; os ROOTS são canonicalizados 1× na subida (congelados). O `cwd` é
  canonicalizado **POR-REQUISIÇÃO** (vem no payload de cada hook — §5) pela DLL, ANTES da comparação com os
  roots canônicos. junction/symlink p/ fora não passa; symlink p/ dentro deixa de dar `defer` espúrio.
  Baseline do §9-0e-iii = hook string-puro ORIGINAL inalterado. DLL ausente → `defer`. O hook invoca
  **SEMPRE** o CLIENTE NativeAOT — tanto no observe (Fase 3) quanto no enforce (Fase 4); ver a reconciliação
  pós-Passo F na seção «Passo G». O `Invoke-...ps1 -Observe` in-process **NÃO** é o observe do fio: mede só
  cobertura e não sobe o daemon (logo não caracteriza a latência de concorrência).
- **Threading (reconcilia o §7 "v1 single-threaded síncrona"):** o loop principal segue SINGLE-THREADED para
  DECISÕES. A canonicalização do `cwd` (I/O que pode BLOQUEAR em UNC ruim, pois `CreateFile`/`GetFinalPathNameByHandle`
  não cancelam pelo token) é offloaded a um WORKER curto com **CAP EXPLÍCITO** (pool limitado): ao atingir o
  cap, novas canonicalizações → `defer` imediato (sem spawn ilimitado nem fila crescente). Worker usa
  `using`/`try-finally`; o timeout cancela a I/O quando possível e, quando não, marca o worker ABANDONADO e não
  o reutiliza. **Contrato do self-test:** prova LIMITE POR CAP, não igualdade — sob N timeouts de I/O
  não-cancelável, threads/handles presas ficam ≤ cap (sem crescimento ilimitado); `ANTES==DEPOIS` NÃO é
  exigido (é inatingível com I/O não-cancelável). Evolução (dívida monitorada): isolar a canonicalização num
  **processo auxiliar matável** (kill no timeout mata thread/handle de verdade).
- **Orçamento/ordem:** o `cwd` local resolve em microssegundos; o custo só pesa em UNC/rede (raro). O Passo F
  mede o custo da canonicalização ISOLADO (defer-comum com/sem). Se a medição justificar inverter a ordem
  (fast-path barato in-process ANTES da canonicalização), a inversão SÓ pula a canonicalização no caminho
  **defer-comum** (onde o fast-path já decide `defer`); no caminho **escalate (allow-candidato)** a
  canonicalização do `cwd` permanece OBRIGATÓRIA antes do veredito — a 1ª-barreira de escopo para `allow`
  NÃO é afrouxada.

### Passo C — Daemon `pwsh` persistente (§5/§6/§7; §5(b))
- `ClaudeCodePreToolUseSafeAllowDaemon.ps1` (StrictMode): **singleton pelo daemon** (named mutex de vida
  própria, ACL só-usuário); a aquisição trata `AbandonedMutexException` (dono anterior morreu → ADQUIRIDO).
  Não adquiriu → sai cedo. Vencedor: dot-source 1×; python persistente 1×; carrega a DLL 1× (Join-Path
  `$PSScriptRoot` — a DLL fica ao lado do `Daemon.ps1`); self-check; SÓ ENTÃO cria o pipe (ready = pipe
  conectável; SEM ready file).
- **Corrida de cleanup do pipe:** novo singleton que falha em criar o pipe (velho em teardown lazy) →
  retry+backoff curto; persistiu → `defer-only`. **Morte silenciosa do python:** checa `$pyProcess.HasExited`
  no loop → respawn imediato.
- **Roots em runtime = separação por canal (não staleness):** `rootsCanonical` é parte da IDENTIDADE (no hash
  do pipe/mutex). Mudar `PTU_SAFE_ALLOW_ROOTS` faz o CLIENTE NOVO computar um CANAL DIFERENTE → usa/dispara
  OUTRO daemon (identidade nova); o daemon antigo segue servindo seus clientes de identidade antiga até morrer
  (dívida "daemon antigo roda até morrer"). NÃO há "defer-only por staleness de roots" — a separação por canal
  é o mecanismo (o daemon antigo nunca recebe requisições de roots novos).
- **Protocolo/payload:** framing `[magic 1B][protocolVersion 2B BE][payloadLen 4B BE][payload UTF-8]`; cap
  64 KB; `0x01` dados / `0x02` shutdown. Payload = `{ tool_name, tool_input.command, cwd, ptuSafeAllowVersion,
  buildContractPin, requestId }`. Resposta = frame válido com payload EXATAMENTE `allow`/`defer`.
  `protocolVersion` / `ptuSafeAllowVersion` (2ª barreira §6, por-requisição) / `buildContractPin` divergentes
  → `defer`. **Timeout no servidor** (adição registrada) → fecha+`defer`. ACL só-usuário; shutdown `0x02` pela
  mesma ACL.
- **Transição segura do python** (`.py` muda OU `HasExited`): sobe NOVO python, valida que o módulo importado
  reporta o HASH NOVO (SHA256 do source em runtime), SÓ ENTÃO troca o handle; durante → `defer`. (Implementação:
  mutex interno curto no daemon para evitar estados mistos antigo/novo sob requisições concorrentes.)
- **Staleness §6 (matriz):** `Support.ps1`=re-dot-source; `.py`/`ShlexLoop.py`=respawn (transição segura);
  `Daemon.ps1`=defer-only ate restart; `.cs`/DLL=defer-only ate restart. A staleness HASHEIA o ARQUIVO DLL EM
  DISCO (não só o pin em memória) → substituição pós-Add-Type → `defer-only`; hash com timeout (arquivo travado)
  → `stale-uncertain` → `defer` (nunca `allow`). Anti-`.pyc`: o respawn LIMPA `__pycache__` (obrigatório) +
  `PYTHONDONTWRITEBYTECODE=1`. Hash SHA256 por artefato, cache (path,size,mtime) com RECOMPUTO; N=3 →
  `defer-only`; watchdog re-hash ~30 s.
- **Log do daemon:** SEM o `command` E SEM `commandHash` (SHA256 de comando estereotipado é reversível por
  dicionário). Só `requestId` + decisão + estado + timestamp + código de erro. ACL só-usuário no pipe, nos 2
  mutexes E no arquivo de log.

### Passo D — Cliente NativeAOT (§5(b) dispara-e-sai; orçamento; integridade; log de falha de subida)
- Pasta do cliente (`Program.cs` + `.csproj` + o `.cs` compartilhado + `BuildPin.g.cs` gerado + publish).
  Envia no payload: `protocolVersion` + `ptuSafeAllowVersion` + `buildContractPin` + `requestId`; divergência
  → `defer`. Identidade = SID + `repoCanonical` (ascensão à raiz, fail-closed) + `rootsCanonical`; inválida →
  `defer`. stdin do hook com cap ≤ 64 KB + deadline. Parsing ESTRITO da resposta (só `allow`/`defer` exatos em
  frame válido).
- **Dispara-e-sai:** conectável → request/enum/monta payload/sai. "Canal ausente" → `TryAcquire` NÃO-bloqueante
  do mutex de GUARDA: adquire → dispara o daemon DETACHED, segura `guardWindowMs`, escreve `defer`, sai; não
  adquire → `defer` e sai. NUNCA segura até ready.
- **Log de falha de subida pelo cliente (complementar ao do daemon):** como o daemon pode NUNCA nascer, o
  cliente grava um marcador mínimo em `...SafeAllowClient.log` (ACL só-usuário, rate-limited, SEM `command`):
  timestamp + `requestId` + código (`spawn-failed`, `daemon-not-ready`, `identity-invalid`, `dll-missing`).
  Sucesso normal NÃO loga.
- **Orçamento (fonte única):** `responseDeadlineMs` (~80 ms, QUENTE) e `guardWindowMs` (~50 ms, FRIO) SEPARADOS
  (uma invocação é quente XOR fria). Latência fria percebida = floor de spawn do cliente (~28 ms p50) +
  `guardWindowMs`. Ajuste `guardWindowMs = clamp(50, ~coldReadyMs_p95, 200)`, fixado aqui, medido no Passo F.
- **Concorrência:** **≤1 daemon SOBREVIVENTE POR `IdentityHash`** (singleton por identidade; identidades
  distintas — ex.: roots diferentes — PODEM coexistir até o daemon antigo morrer). Burst SIMULTÂNEO (mesma
  identidade) → `loserSpawns≈0`; ESCALONADO → teto `ceil(coldReadyMs/guardWindowMs)+margem`. Passo F mede os
  dois + vida agregada + pico RSS.
- **Integridade do EXE:** handshake (`protocolVersion`/`ptuSafeAllowVersion`/`buildContractPin`) barra cliente
  velho/divergente; self-test §8 gateia o binário; Passo G rebuilda. Swap malicioso de mesma versão = fora do
  threat model (escrita local = já comprometido) → dívida documentada.
- NUNCA emite `allow` sozinho; falha → `defer` exit 0. Toolchain ausente → PARA com diagnóstico; build AOT
  falho = instalação FALHA; NUNCA ativa TCP automaticamente.

### Passo C-fallback — TCP+Python (só por decisão humana, se o toolchain AOT faltar)
NÃO é liberável como fio só por ser medido NEM ativado por acidente. Só após decisão humana explícita, e exige
a MESMA bateria do pipe: cliente TCP stdlib; token de sessão atômico com ACL só-usuário; arquivo de descoberta
por identidade; shutdown por opcode + token; staleness §6 equivalente; self-tests próprios (token ausente/
inválido → `defer`; ACL do arquivo; viabilidade DLP corporativo da porta). Até passar, fica em medição/observe.

### Passo E — Self-tests §8 (o GATE de segurança)
`Test-ClaudeCodePreToolUseSafeAllowDaemonSelfTest.ps1` (sentinela `OK:`):
- paridade daemon↔in-process; cliente↔daemon (comparador: ordem dos 3 campos do `Get-PtuHookOutput`;
  byte-a-byte normalizando SÓ o valor de `permissionDecisionReason`; ausência/tipo/whitespace/extra/casing/
  ordem → FALHA); invariante do cliente (isolado, nunca `allow`).
- **Daemon falso hostil:** `"allow\x00"`, `"allow\r\n"`, `"allow "`, `" allow"`, `"ALLOW"`,
  `"{\"decision\":\"allow\"}"`, `"allowdefer"`, truncado, magic inesperado, tamanho errado → sempre `defer`.
- **Entrada/protocolo adversarial:** >64 KB; `payloadLen<real`; `payloadLen=0`; múltiplos frames (ler 1);
  `0x02` em resposta a `0x01` → `defer`; `payloadLen=0x7FFFFFFF` + poucos bytes; `=0xFFFFFFFF` (signed -1);
  magic fora de `{0x01,0x02}`; JSON `tool_name` ausente/tipo errado; `{}` → `defer` SEM exceção. Handshake:
  `ptuSafeAllowVersion`/`buildContractPin` divergentes → `defer`; downgrade de `buildContractPin` (EXE novo +
  DLL velha e vice-versa) → `defer`. StrictMode: python retorna `{"status":"defer",...}` e `{}` → `defer`.
- **Segments:** `[]`, `[[]]`, `["git"]` (segmento string escalar → `defer`), `[["git","log"],["head"]]` (ok),
  token null, objeto, string vazia.
- **Unicode:** tokens concretos U+200B, U+FEFF, U+202E no verbo, flag E argumento → `defer`; NFC vs NFD.
- **ACL:** AUSÊNCIA de `Everyone`/`Authenticated Users`/`NetworkService` na DACL do pipe, 2 mutexes E AMBOS os
  logs (daemon E cliente) + conexão negativa de outro SID onde o ambiente permitir; shutdown `0x02` autorizado.
- **Identidade:** MESMO corpus pelas DUAS compilações (EXE AOT E DLL via Add-Type) → `canonicalizePath`
  byte-idêntico POR CASO (incl. İ/ß); paridade cliente↔daemon de `repoCanonical` (ascensão; regra de parada
  idêntica; fail-closed zero/múltiplos/ausente; fixture `.git` ancestral + marcador órfão intermediário + EXE
  subpasta profunda vs daemon `scripts\`) E de `rootsCanonical`; checkouts distintos sob roots largos → pipes
  distintos.
- **Escopo:** junction/symlink DENTRO → `allow`; ESCAPA → `defer`; `cwd` handle INDISPONÍVEL → `defer` no
  deadline SEM travar o loop; `cwd` FORA do escopo + comando allow-candidato → `defer` mesmo com fast-path
  otimizado; ROOTS VAZIO/TODOS INVÁLIDOS → `defer`; `cwd` canonicalizado POR-REQUISIÇÃO.
- **Concorrência:** simultâneo → ≤1 SOBREVIVENTE por `IdentityHash` E `loserSpawns≈0`; escalonado → ≤ teto;
  vida agregada + pico RSS; nunca >1 daemon por `IdentityHash` após `guardWindowMs+coldReadyMs` (identidades
  distintas podem coexistir); `AbandonedMutex` (matar+subir outro → adquire); cleanup do pipe → retry →
  `defer-only`; canonicalização sob N timeouts de UNC não-cancelável → threads/handles presas ≤ cap E o loop
  continua servindo.
- **Staleness bloqueante:** editar SÓ `Support.ps1`; SÓ o `.py` ISOLADO (mudança adversarial em `classify` →
  após editar+limpar `__pycache__`+transição-segura, PROVAR pela decisão E pelo hash do MÓDULO IMPORTADO em
  runtime); `ShlexLoop.py`; `Daemon.ps1`; `.cs`/DLL (substituir a DLL em disco pós-load → `defer-only`; hash
  com timeout → `defer`).
- comparação de SEGMENTOS = TRANSPORTE (Passo A); `defer-only` (3 reloads quebrados → recupera ≤30 s);
  `PTU_SAFE_ALLOW_ROOTS` ao vivo → pipe diferente; encoding não-ASCII no veredito → mesmo veredito; privacidade
  dos logs (sentinela ausente em ambos; só `requestId`/estado/timestamp); log de falha de subida (forçar
  daemon-não-pronto → cliente grava o marcador; assert presença + ACL + sem `command`).

### Passo F — Medição vs §9-0e (metodologia do passo 0)
Floor binário NA MESMA RODADA + e2e; ≥1000 iterações intercaladas; cross-check perc-a-perc até p95 E p90
pareado; separar defer-comum de allow-candidato; guardrail `%>80 ms`; p95/p99 como telemetria por host. **Gate
= overhead ≤ 5 ms.** Mede `coldReadyMs`, `loserSpawns` (simultâneo≈0 e escalonado) + vida agregada + pico de RSS
sob burst K=20, com `guardWindowMs` fixado; custo da canonicalização do `cwd` ISOLADO; latência fria reportada
= floor + `guardWindow`. §9-0e-iii baseline = hook string-puro ORIGINAL. Modo observe.

> **NOTA PÓS-EXECUÇÃO (2026-06-30):** o Passo F foi executado; o fio real deu overhead **~20–34 ms** (não ~1 ms
> do protótipo), então o **"Gate = overhead ≤ 5 ms" acima foi RECONCILIADO** — ver a `NOTA PÓS-PASSO-F + PAINEL`
> no §9-0e de `claude-code-pretooluse-daemon-design.md` (revisão por pares vinculante): o (i) vira **alvo de
> eficiência** (meta ≤ 10 ms até o Passo H), e a **condição de liberação** passa a ser (ii)+(iii)+concorrência
> fail-closed. Decisão datada: fio **aprovado no mérito**; enforce (Passo G) condicionado à Fase 3 (observe).
> Relatório + revisão por pares + medições em `historico/passoF-daemon-pretooluse-medicao-20260630/`.

### Passo G — Fio (install via `xpz-skills-setup`)
Fase 3 (observe) → 4 (enforce) → 5: o fio em `~/.claude/settings.json` é gravado por
`Install-ClaudeCodePreToolUseSafeAllow.ps1`, **sempre invocado pela `xpz-skills-setup`** (mantém a atribuição
do design §5/§9 a essa skill), NUNCA standalone. O install: valida que o EXE existe e que o `buildContractPin`
(.cs↔DLL↔EXE) bate; valida self-tests §8 VERDES antes de gravar; **deposita o EXE E a DLL em subpasta da raiz
marcada** (a DLL ao lado do `Daemon.ps1` para `$PSScriptRoot` resolvê-la); **cria um único marcador
`.ptu-safe-allow-root` na raiz do repo, limpando marcadores órfãos** de instalações antigas; rebuilda o cliente
AOT E a DLL (gerando `BuildPin.g.cs` do `.cs` corrente). Máquina-local, Windows x64.

> **Recorte da v1 (reconciliação 2026-06-30, confirmada pelo autor):** o install que grava o fio via
> `xpz-skills-setup` está **dentro** da v1/Passo G (máquina local: deploy + observe → enforce, condicionado);
> o "fora da v1" do design §9 refere-se a **persistência entre reboots, auto-start no login e distribuição
> multi-máquina** (§5, reusando os padrões da skill `xpz-daemon`), não ao ato de gravar o fio.

> **Observe da Fase 3 = FIO REAL (reconciliação pós-Passo F, 2026-06-30, confirmada pelo autor):** a fase de
> medição (observe) roda pelo **caminho completo** — o hook executa o cliente NativeAOT, que fala com o daemon,
> o daemon **decide** `allow`/`defer` e mede-se a latência —, mas o cliente **sempre devolve `defer`** ao Claude
> Code (passivo: mede tudo, não altera nada). É o ÚNICO caminho que caracteriza a **latência de concorrência**
> (a fila do daemon single-threaded), que é a condição pendente para liberar o enforce (§9-0e). **Supera** as
> menções anteriores que descreviam o observe como in-process (`Invoke-...ps1 -Observe`): no Passo A-escopo
> acima e no `claude-code-pretooluse-auto-allow-design.md` §5 (Fase 1–2, anterior ao daemon). O `-Observe`
> in-process fica restrito a medir **cobertura** offline — não é o observe do fio.

## 4. Notas de codificação (da passada de confirmação; não alteram o design)

Levantadas pelo painel na confirmação da v2.22, para atenção durante os Passos A–G:
- **Co-localização DLL↔`Daemon.ps1`** sob a raiz marcada; se o `xpz-skills-setup` depositar o EXE fora do repo,
  a ascensão falha-fecha (defer) — registrar para não virar "tudo defer" silencioso (Opus, glm).
- **Lado DLL do `buildContractPin`:** o spike do Passo B deve cravar se a DLL é pré-buildada por MSBuild (alvo
  gera o `BuildPin.g.cs` para ela) ou compilada via `Add-Type` em runtime — senão o daemon não tem o pin do
  handshake (glm). O gerador do `BuildPin.g.cs` deve ser deterministicamente reproduzível entre máquinas de
  build (kimi).
- **Burst frio = K `defer`s, não K−1:** com o fire-and-forget o spawner também defere; o Passo F mede
  `loserSpawns` (métrica certa), mas registrar a mudança de contagem user-facing (glm).
- Helper centralizado e testável para o contrato de `segments` (StrictMode) (kimi); `unicodedata.category` por
  token na rejeição Cc/Cf, sem pegar controles legítimos já decodificados pelo `shlex` (kimi); detecção de
  marcador órfão na ascensão (Codex); NFC vs NFD explícito no corpo do teste Unicode (Codex); conexão negativa
  por outro SID pode exigir harness próprio, sem tratar a inspeção de DACL como substituto silencioso (Codex);
  o "processo auxiliar matável" do worker pode ser necessário mais cedo do que parece — dívida monitorada (kimi).

## 5. Restrições e dívidas

- Trabalhar em `main`; comandos atômicos; **não commitar nem pushar sem ordem explícita**; **não ligar enforce
  nem o fio antes dos self-tests §8 passarem**; não reabrir o design congelado nem o §9-0e (exceto §5(b) e
  G2(a), aprovados).
- **Adições registradas** (não desvios — todas fail-closed/mais restritivas): timeout no servidor; proibição
  de `commandHash` no log; rejeição Unicode Cc/Cf na `classify`; worker de canonicalização com timeout duro +
  cap; log de falha de subida pelo cliente; `buildContractPin` como 3ª barreira de handshake por-requisição
  (aditiva ao §7); anti-`.pyc`; roots em runtime → canal diferente; hash do módulo importado em runtime;
  transição segura do python = respawn com handover.
- **Dívidas não-bloqueantes:** protocolo portátil noutro host Win11; DLP do TCP (só se fallback (c));
  persistência reboot/auto-start (reusar padrões da skill `xpz-daemon`); watchdog de processo travado;
  integridade do EXE (swap malicioso de mesma versão); daemon antigo com roots antigos roda até morrer (sem
  vida máxima na v1); processo auxiliar matável para a canonicalização.

## 6. Proveniência (revisão por pares)

Campanha conduzida pela skill `xpz-llm-delegate` sob a régua de `15-revisao-por-pares.md`; acionamento humano.
Painel de **5 linhagens distintas** (anthropic/Opus 4.8 via subagente nativo; openai/Codex gpt-5.5; e via
opencode/Ollama-Cloud: Moonshot/kimi-k2.7-code, Z-ai/glm-5.2, DeepSeek/deepseek-v4-pro). O plano iterou v1 →
v2.22; cada gap apontado foi triado e incorporado (ou descartado com justificativa); a **versão final exata
(v2.22)** foi confirmada pelo painel inteiro com **zero gap de design e zero regressão**. Achados de maior peso
na passada final: o `buildContractPin` insatisfazível (glm) e duas incoerências de contrato — roots ao vivo e
o self-test `ANTES==DEPOIS` inatingível (Codex) — todos corrigidos antes do congelamento. Closeout mecânico:
`closeoutReady=true`, `vNextState=resubmitted`. **Congelado em 2026-06-29.** A prova restante é empírica
(Passo B spike, Passo E self-tests, Passo F medição), na implementação.
