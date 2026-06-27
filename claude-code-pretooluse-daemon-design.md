# Daemon do hook `PreToolUse` (auto-allow) do Claude Code — design

> **STATUS: RASCUNHO v2 (não congelado).** Esta v2 incorpora a revisão por pares
> `daemon-design-v1` (5 vozes efetivamente consultadas, 3 famílias — `anthropic`/Claude Opus
> subagente nativo, `openai`/Codex gpt-5.5, `nvidia`/glm-5.1+kimi-k2.6+minimax-m2.7; os 3
> `ollama-cloud` preferidos caíram por cota e foram substituídos pelos NVIDIA). Veredito do painel:
> **unânime "revisar — direção certa, não congelar"**. Os invariantes (§2) foram aprovados sem
> ressalva; o bloqueio é **empírico e de protocolo**. Esta v2 fecha as decisões de protocolo,
> identidade, staleness e corrida que a v1 deixava em aberto, e move a prova numérica para um
> **passo 0 de medição** (§9). **Ainda não congelada:** depende do passo 0 e de re-submissão ao painel.
>
> **ESCOPO — Claude Code apenas** (herdado da spec congelada `claude-code-pretooluse-auto-allow-design.md`):
> depende do hook `PreToolUse` + `permissionDecision`, recurso que não existe em Codex/Cursor/OpenCode.
> O fio em `~/.claude/settings.json` é **máquina-local**; os scripts viajam com o repositório.
>
> **Nome:** todos os artefatos novos usam o prefixo **`ClaudeCodePreToolUseSafeAllowDaemon`**, para
> herdar a convenção dos arquivos irmãos e **nunca** colidir com a skill `xpz-daemon` (monitor de
> XPZ — processo diferente, finalidade diferente).

## 1. O problema, com precisão

A latência medida (2026-06-22) é **~520 ms/comando**, dominada pelo **startup do `pwsh` a cada
chamada** — não pela lógica. O fast-path (`Get-PtuBashFastPath`) já é **in-process e sub-ms**, mas
isso não ajuda: o custo é **fazer o `pwsh` nascer**. O orçamento da frente é **p95 do caminho quente
≤ 100 ms**. Enquanto o hook for um `pwsh -File ...` que sobe do zero, o orçamento é estourado em ~5×.

**Consequência de design:** o daemon (processo persistente que já tem a lógica carregada) resolve o
lado **servidor**. Mas o hook continua sendo **disparado pelo Claude Code como um comando novo a cada
ferramenta**. Logo o gargalo se desloca para o **cliente** — o programinha que o hook executa para
falar com o daemon. **Se o cliente for outro `pwsh`, não ganhamos nada.** Esta é a decisão central.

**Correção do painel (crítica):** a v1 modelava o custo como "tira o pwsh, sobra só o startup do
cliente". Mas o caminho real candidato a `allow` (`Get-PtuBashDecision`, `...Support.ps1:153-157`)
**sobe um segundo `python`** para o `shlex` helper a cada requisição. Mover `Get-PtuDecision` para
dentro do daemon **não** elimina esse segundo python — ele é chamado por `& $PythonExe $HelperPath`.
Sem resolver isso (ver §4.1), o daemon resolve **metade** do problema. E há **dois caminhos quentes
distintos** a medir separadamente, não um só:

- **caminho `defer`-comum** (1º token não é verbo read-only): hoje é sub-ms in-process no pwsh-hook;
  **com daemon fica mais lento** (paga startup do cliente + IPC para um `defer`). Não pode regredir.
- **caminho `allow`-candidato** (verbo read-only): hoje paga pwsh + python(shlex); com daemon paga
  cliente + IPC + (possivelmente) python(shlex) no daemon.

## 2. Invariantes herdados (não-negociáveis) — aprovados pelo painel

Tudo da spec congelada continua valendo e o daemon **não pode** afrouxar nada:

1. **Só `allow` ou `defer`, nunca `deny`.** Pior caso = prompt como hoje.
2. **Fail-closed para `defer`** em qualquer erro, timeout, daemon ausente/subindo, resposta
   inesperada, versão divergente, staleness suspeita ou ambiguidade. Indisponível **nunca** vira `allow`.
3. **Fonte única da lógica de decisão = `ClaudeCodePreToolUseSafeAllowSupport.ps1`.** O daemon
   **reusa** `Get-PtuDecision` por dot-source; **proibido** reimplementar o classificador noutra
   linguagem (divergência = falso-allow silencioso).
4. **O daemon nunca executa o comando do usuário.** Recebe o JSON do hook, **classifica**, devolve
   `allow`/`defer`. Não há caminho de execução do `command`.
5. **Gate de segurança = self-test adversarial**, agora também através do daemon **e do cliente** (§8).
6. **(NOVO) O cliente só tokeniza e transporta — nunca decide `allow`.** Mesmo que o `shlex` migre
   para o cliente (§4.1), todo **veredito** fica no daemon (`Get-PtuDecision`). O cliente, isolado,
   é **incapaz** de emitir `allow` — invariante provado por self-test, análogo ao já provado para
   `Get-PtuBashFastPath` (`...Support.ps1:132-133`). Isso preserva (3) mesmo com a fronteira deslocada.

## 3. Arquitetura proposta

```
Claude Code  --(stdin: hook JSON)-->  [CLIENTE leve]  --(IPC: ver §4.2)-->  [DAEMON pwsh persistente]
                                            |                                         |
                                            |<---  resposta = enum {allow|defer}  ----| (Get-PtuDecision)
                                            v
                                   stdout: {"hookSpecificOutput": ...}   (montado PELO cliente)
```

- **Daemon:** `pwsh` persistente que dot-source o `...Support.ps1` **uma vez**, abre o canal IPC e
  entra em loop: lê uma requisição enquadrada, valida, chama `Get-PtuDecision`, devolve **o enum**.
  Custo de startup pago **uma vez**. **Estado `ready` explícito** (§5): antes de `ready`, não aceita
  conexão (ou responde só `defer`).
- **Cliente (o comando do hook):** programa de **inicialização rápida** que conecta, repassa o JSON
  do stdin (ou os segmentos já tokenizados, §4.1), lê **o enum** e **monta ele mesmo** o
  `hookSpecificOutput`. Em qualquer falha (canal ausente/ocupado/subindo, timeout, lixo, versão
  divergente) → imprime **`defer`** e sai 0 (fail-closed). **Nunca** monta `allow` por conta própria.
- **Resposta como enum estreito** (correção do painel): o daemon devolve **apenas** `allow`|`defer`
  (+ campos diagnósticos que o cliente ignora), **não** JSON arbitrário. O cliente é quem constrói o
  payload final do hook. Reduz superfície de injeção e impede que resposta malformada vire saída
  inesperada ao Claude Code.

## 4. A decisão central — runtime do cliente, IPC e o 2º python

### 4.1 Onde roda o `shlex` (resolve o 2º python)

Duas saídas, a decidir **por medição** no passo 0 (§9):

- **(a) Cliente tokeniza:** o cliente Python roda o `shlex` (reaproveitando o processo Python que já
  nasceu) e manda ao daemon os **segmentos já tokenizados**; o daemon só roda as `Test-Ptu*SegmentAllowed`
  (in-process puras, sem python). **Elimina o 2º python.** Custo: desloca a fronteira — coberto pelo
  invariante §2.6 (cliente nunca decide `allow`) + self-test de paridade **cliente↔daemon** (§8).
- **(b) Daemon mantém python persistente:** um processo/runspace Python vivo no daemon para o `shlex`.
  Mantém a fronteira atual (cliente burro), mas adiciona um 2º processo de longa vida para gerenciar.

**Preferência provisória:** (a), por ser mais simples no agregado e matar o 2º python — **se** o
self-test de paridade cliente↔daemon provar zero divergência. Confirmar no passo 0.

### 4.2 Transporte IPC: named pipe vs TCP loopback

| Opção | Prós | Contras (apontados pelo painel) |
|---|---|---|
| **Named pipe** | ACL nativa por-usuário; sem porta/firewall | `open(r'\\.\pipe\...')` da stdlib Python **não** basta para `PIPE_ACCESS_DUPLEX`/message-mode → exige `pywin32`/`ctypes` (nova dependência, **derruba o "zero build/zero dep"**); ACL "default" de pipe criado por pwsh é **incerta** |
| **TCP loopback** | stdlib `socket` puro (zero dep), **drasticamente mais simples** em Python | `127.0.0.1` ≠ "só este hook": **exige token de sessão** (nonce em arquivo com ACL só-usuário, apresentado no handshake); superfície de firewall (rara em default) |

**Decisão de design:** medir os dois no passo 0. Se o named pipe exigir `pywin32`, a comparação
Python-vs-NativeAOT **se inverte** (o exe fala pipe nativamente, sem dep runtime). **Default
provisório:** TCP loopback stdlib **com token de sessão** — mais portável e sem dep extra —, com
named pipe (via exe NativeAOT) como alternativa se a medição favorecer. Qualquer que seja, a **ACL é
parte do contrato, não "default"**: pipe → ACL explícita pelo SID do usuário; TCP → token + ACL do
arquivo de descoberta.

### 4.3 Runtime do cliente

| Opção | Startup típico (Win) | Dependência | Veredito |
|---|---|---|---|
| **Python** (cliente mínimo, stdlib `socket`) | ~30–60 ms nu; +`import json`/socket; +`pywin32` se pipe | já é dep (`shlex`); zero build **se** stdlib bastar | **candidato v1, gated na medição** |
| **.NET exe (NativeAOT)** | ~10–30 ms; named pipe nativo | passo de build + binário | **co-candidato real** se pipe exigir `pywin32` ou se p95 do Python estourar |
| **`pwsh` cliente** | ~500 ms | nenhuma | **proibido** (é o problema) |

**Critério objetivo de escolha (do painel):** Python **falha** e cai-se para NativeAOT se o **p95
end-to-end real** (não isolado) exceder ~80 ms ou o **p99** exceder 100 ms, na máquina alvo, com
Defender ativo e carga moderada. O startup "30–60 ms" da v1 era otimista: não contava `import json`,
custo de conexão real, nem o overhead do shell que dispara o hook.

## 5. Ciclo de vida do daemon — corrida e estado `ready`

- **Subida única guardada por mutex.** Antes de spawnar, o cliente adquire um **named mutex** por
  usuário (`Local\ClaudeCodePreToolUseSafeAllowDaemon-<userSID>`). Só quem adquire o mutex spawna o
  daemon; os demais **apenas devolvem `defer`**. Evita N daemons quando N hooks acham o canal ausente
  ao mesmo tempo (o Claude Code dispara ferramentas em paralelo).
- **Estado `ready` explícito.** O daemon só passa a aceitar conexões (ou só responde algo diferente
  de `defer`) **depois** de: dot-source OK, self-check de versão/hash OK, canal criado e escutando.
  Antes disso → conexão recusada ou `defer`. Mata a janela "daemon meio-inicializado responde default".
- **Cliente distingue as falhas, mas todas viram `defer`.** "canal ausente" (→ tenta adquirir mutex
  e spawnar, **uma vez**) ≠ "canal existe mas ocupado/subindo" (`ERROR_PIPE_BUSY`/connection refused
  → **só `defer`**, **não** spawna outro daemon). **Toda** falha de conexão resulta em `defer`.
- **Backoff curto opt-in.** Para reduzir avalanche de `defer` nos primeiros ~800 ms de uma sessão
  (enquanto o daemon sobe), o cliente pode tentar reconectar com backoff **dentro do orçamento de
  tempo** (ex.: 2 tentativas em ≤ 30 ms total). Estourou o micro-orçamento → `defer`. Documentar o
  **máximo de `defer`s por arranque** esperado.
- **Persistência entre reboots:** fora do escopo da v1. A subida lazy cobre "daemon caiu". Auto-start
  no login (Task Scheduler/Startup) é **evolução** e deve **reusar os padrões da skill `xpz-daemon`**
  (dependência documentada), não inventar outro mecanismo.
- **Watchdog (dívida registrada):** detecção de daemon **travado/órfão** (PID file + heartbeat) não
  entra na v1, mas fica listado — o timeout do cliente já garante `defer`, mas o processo órfão precisa
  de quem o detecte/mate na evolução.

## 6. Frescor da lógica (staleness) — regra única decisiva

O daemon segura a versão de `...Support.ps1` de quando subiu. Servir lógica velha como boa = falso-allow.
Decisão do painel (não mais "uma ou outra"):

- **Primário: hash SHA256** do `...Support.ps1` por requisição (sub-ms; cacheável por `(path,size,mtime)`
  para não reler quando nada mudou). **Não** usar mtime como primário — `git checkout`/`stash` não
  preservam mtime de forma confiável (grava conteúdo, não timestamp), e a granularidade NTFS engana.
- **Secundário: handshake de versão** (`$script:PtuSafeAllowVersion`): o cliente envia a versão
  esperada; divergência → `defer`. Segunda barreira (pega incompatibilidade de contrato), nunca a
  primária (o número é manual e não bumpa sozinho durante desenvolvimento).
- **Regra única: "dúvida → `defer` + restart".** Hash divergente ou reload que falha (arquivo
  meio-escrito sob `Set-StrictMode`) → o daemon entra em **`defer-only`** e se reinicia; **nunca**
  continua servindo a lógica anterior nem tenta "ajustar no voo". O re-dot-source é **envolto em
  try/catch que mantém o loop vivo** e marca `stale-unsafe` até um reload bem-sucedido.
- **Custo worst-case:** em disco local SSD o hash é ~0.1–0.3 ms; em UNC/antivírus pode subir — por
  isso o cache por `(path,size,mtime)` e a anotação de que o `...Support.ps1` deve estar em disco local.

## 7. Concorrência e segurança

- **Concorrência:** v1 é **single-threaded síncrona** (uma conexão por vez); cada decisão é sub-ms.
  **Limiar explícito:** se a medição de contenção (2+ chamadas simultâneas) levar o **p95 acima de
  100 ms** por espera na fila, a saída é **pipe/porta por sessão**
  (`...-<userSID>-<sessionId>`), **não** múltiplas instâncias de daemon (evita sincronização entre
  processos). Medir antes de complicar.
- **ACL/identidade (parte do contrato, não "default"):**
  - **Pipe:** criado com ACL **explícita** pelo SID do usuário corrente (`ReadWrite`); se PowerShell
    puro não garantir, usar helper C# inline. Nome inclui o **SID** (não `$env:USERNAME`, que muda em
    renomeação de conta).
  - **TCP:** token de sessão (nonce aleatório) em arquivo com ACL só-usuário, exigido no handshake;
    sem token válido → conexão rejeitada → `defer` no cliente.
  - **Identidade por checkout/repo:** o nome do canal inclui um hash do **caminho canônico do repo**,
    não só o usuário — senão um daemon de **outro checkout/branch** poderia responder por engano.
- **Protocolo do wire (especificado):** framing **length-prefixed** (4 bytes big-endian + payload
  UTF-8), **não** line-delimited (um `\n` interno mal escapado quebraria o enquadramento). Encoding
  UTF-8 fixo nas duas pontas. **Tamanho máximo** de mensagem (rejeita acima → `defer`). O daemon
  valida que o JSON parseia e que `tool_name`/`tool_input.command`/`cwd` existem com os tipos certos;
  qualquer anomalia → `defer`. Resposta = **enum** `allow|defer`. Corpus adversarial (§8) inclui
  `\n`/`\r`/`\0`/delimitador embutido no `command` e JSON truncado, exigindo `defer`.
- **Shutdown — plano de controle separado do plano de dados:** o encerramento **não** trafega como
  "um JSON de hook com campo especial" (seria vetor de DoS: input que parece shutdown derruba o
  daemon). É um canal/verbo de controle **autenticado** (mesmo token/ACL), distinto do caminho de
  classificação. Qualquer processo do mesmo usuário derrubar o daemon → degrada para prompts, não é
  catastrófico, mas exige a barreira de auth.
- **Timeout agressivo do cliente (materializa o fail-closed):** connect ≤ 50 ms, read ≤ 50 ms
  (coerente com o orçamento de 100 ms). Estouro → imprime `defer` e sai 0. **Sem timeout o hook
  pendura**, o que é **pior que um prompt** (trava a tool call inteira) e quebraria silenciosamente a
  promessa "pior caso = prompt como hoje". Self-test com daemon que dorme de propósito (§8).
- **Log/diagnóstico (dívida registrada):** um log mínimo (decisão + timestamp, sem o `command`
  completo por privacidade) é essencial para depurar um processo persistente; entra como item de v1
  leve ou evolução próxima.

## 8. Prova (self-test) — o gate continua sendo a segurança

- **Paridade daemon↔in-process:** `Test-ClaudeCodePreToolUseSafeAllowDaemonSelfTest.ps1` roda o
  **mesmo corpus adversarial** **através do daemon** e exige decisão **idêntica** à de `Get-PtuDecision`
  direto. Divergência = falha.
- **Paridade cliente↔daemon e invariante do cliente:** se o `shlex` migrar para o cliente (§4.1),
  novo caso provando que o cliente, isolado, **nunca** emite `allow` (só `defer` ou "tokeniza e
  transporta") — análogo ao invariante de `Get-PtuBashFastPath`. E paridade: cliente+daemon juntos =
  mesma decisão do in-process.
- **Fail-closed com daemon fora/subindo/lento:** com o daemon parado, o cliente produz `defer` para
  todo o corpus (inclusive os que seriam `allow` quente). Com daemon que **dorme** além do timeout →
  cliente devolve `defer` **dentro do orçamento**, sem pendurar.
- **Staleness:** caso que **edita o `...Support.ps1` com o daemon vivo** e prova que a decisão muda
  (ou vira `defer`+restart), não permanece a antiga.
- **Protocolo:** casos adversariais de framing (§7) exigindo `defer`.
- **Carga paralela (desejável, não bloqueante v1):** stress com N requisições simultâneas; pré-requisito
  é o `...Support.ps1` **não** carregar estado mutável global (`$script:`) que vaze entre requisições.
- **Sentinela** no padrão dos demais (`OK: Test-...DaemonSelfTest.ps1`). O self-test é o **gate**; o
  observe mede cobertura/latência, não segurança.

## 9. Sequência de implementação proposta (após aprovação)

**Passo 0 — MEDIÇÃO (gate empírico; nada se implementa antes disto fechar):**
0a. **Medir `pwsh -NoProfile -NoLogo -NonInteractive` isolado** na máquina alvo. Se o startup enxuto
   do pwsh já chegar perto do orçamento, **o daemon pode virar evolução, não pré-requisito** — pode
   tornar a frente inteira desnecessária. Medida mais barata, feita primeiro.
0b. **Cliente Python mínimo real** (com o código de conexão IPC de verdade — pipe via `pywin32`/`ctypes`
   E TCP via stdlib `socket`), medindo **p95/p99 end-to-end** (Claude Code → hook → cliente → IPC →
   daemon → volta), com Defender ativo e carga, ≥100 invocações, **separando** o caminho `defer`-comum
   do `allow`-candidato. Confirmar que o `defer`-comum **não regride** vs o sub-ms in-process de hoje.
0c. **Decidir** §4.1 (shlex no cliente vs daemon), §4.2 (pipe vs TCP) e §4.3 (Python vs NativeAOT)
   **com os números**, não por argumento. Atualizar este doc com as medições coladas.
1. Daemon `pwsh` + canal IPC + estado `ready` + mutex de subida única, reusando `Get-PtuDecision`.
2. Cliente (Python ou exe, conforme 0c): conecta, transporta/tokeniza, monta `hookSpecificOutput`,
   fail-closed + timeout agressivo.
3. Staleness (§6) + protocolo enquadrado (§7).
4. Self-tests: paridade daemon↔in-process, cliente↔daemon, fail-closed, staleness, protocolo (§8).
5. Fase 3 (observe medindo p95 dos **dois** caminhos com daemon) → só então Fase 4 (enforce), e Fase 5
   (fio via `xpz-skills-setup`, subindo o daemon por máquina; manter fora da v1 até o lazy provar-se).

## 10. Questões abertas remanescentes (pós-painel)

A maioria das questões da v1 foi fechada acima. Restam, todas **dependentes do passo 0**:

- **§4.1** shlex no cliente (a) vs daemon python persistente (b) — decidir pela paridade + medição.
- **§4.2/4.3** pipe+`pywin32`/exe vs TCP+token/Python — a medição pode inverter a recomendação.
- **§7** limiar de contenção que dispara "canal por sessão" — só com número de carga real.
- Itens de **dívida registrada** (watchdog, log, auto-start reusando `xpz-daemon`) — evolução, não v1.

## 11. Proveniência (revisão por pares)

- **Rodada `daemon-design-v1`** (2026-06-27): manuscrito = v1 deste doc, blindado de papel; payload
  público. Painel: Claude Opus (subagente nativo, `anthropic`), Codex `gpt-5.5` (`openai`),
  `nvidia/z-ai/glm-5.1`, `nvidia/moonshotai/kimi-k2.6`, `nvidia/minimaxai/minimax-m2.7`. Os preferidos
  `ollama-cloud/*` (deepseek-v4-pro, kimi-k2.7-code, glm-5.2) voltaram `unavailable` (cota semanal/429)
  e foram substituídos pelos NVIDIA. **5 vozes / 3 famílias; piso de diversidade superado.** Veredito
  unânime: "revisar — direção certa, não congelar". Esta v2 endereça os gaps convergentes; **pende
  re-submissão ao painel** (vN+1) antes de congelar.
