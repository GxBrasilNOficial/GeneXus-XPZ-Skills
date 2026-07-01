# Daemon do hook `PreToolUse` (auto-allow) do Claude Code — design

> **STATUS: CONGELADO (v4) — congelado em 2026-06-27 por Antonio José (antonio@frigobyte.com).** Esta v4 incorpora **quatro rodadas** de revisão
> por pares (5 vozes / 3 famílias cada: `anthropic`/Claude Opus subagente nativo, `openai`/Codex
> gpt-5.5, `nvidia`/glm-5.1+kimi-k2.6+minimax-m2.7; os `ollama-cloud` preferidos caíram por cota e
> foram substituídos pelos NVIDIA). Trajetória: rodada 1 (v1) unânime "revisar" → rodada 2 (v2)
> 4 aprova-com-ressalvas + 1 revisar → **rodada 3 (v3) 3 *congelar* + 2 aprova-com-ressalvas** (ambas
> condicionadas a 4 ajustes pequenos). Esta v4 crava esses 4 ajustes: (1) `defer`-comum respeita o
> **orçamento absoluto** além de não regredir (§9-0e); (2) distinção **congelamento do design ≠
> liberação pós-medição** + gate de saída do passo 0 (§4.4/§9-0f); (3) **recuperação do `defer-only`**
> por watchdog interno + telemetria (§6); (4) enquadramento **honesto** do transporte — named
> pipe+NativeAOT é o **default preferido**, TCP+Python é **fallback** (§4.2/4.4). A **rodada 4 (v4) + a
> re-consulta da versão final** confirmaram o congelamento **por unanimidade** (5 vozes / 3 famílias,
> zero gap de papel). **Design CONGELADO** — a prova restante é empírica: passo 0 de medição +
> self-tests, em frente separada.
>
> **(Nota pós-passo-0, 2026-06-28: o item (1) acima — orçamento absoluto do §9-0e — foi RE-ENQUADRADO por
> rodada própria de revisão por pares (3 famílias, convergiu); o p95/p99 absoluto é fisicamente inatingível
> (piso de spawn) e foi substituído pelo overhead-sobre-o-piso ≤ 5 ms. Ver §9-0e e a rodada de
> re-enquadramento em §11.)**
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
**(Nota pós-passo-0: este orçamento absoluto foi re-enquadrado em §9-0e — a medição provou que a cauda p95
é o piso do cliente/processo AOT neste host e neste modelo "hook-nasce-cliente", fora do controle da
implementação enquanto o modelo exigir um cliente novo por invocação; o gate de liberação passou a ser o
overhead do daemon sobre esse piso ≤ 5 ms.)**

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

- **caminho `defer`-comum** (1º token não é verbo read-only): hoje é sub-ms in-process **dentro** do
  pwsh-hook — mas o **custo real ao usuário** inclui o startup do pwsh (~520 ms). **Com daemon** paga
  startup do cliente + IPC para um `defer`. **Baseline correto** = o **hook atual completo** (pwsh do
  zero), não o sub-ms in-process (que é só o limite inferior teórico). Critério de regressão em §9.
- **caminho `allow`-candidato** (verbo read-only): hoje paga pwsh + python(shlex); com daemon paga
  cliente + IPC + (conforme §4.1) o `shlex` no cliente **ou** no daemon.

## 2. Invariantes herdados (não-negociáveis) — aprovados pelo painel

Tudo da spec congelada continua valendo e o daemon **não pode** afrouxar nada:

1. **Só `allow` ou `defer`, nunca `deny`.** Pior caso = prompt como hoje.
2. **Fail-closed para `defer`** em qualquer erro, timeout, daemon ausente/subindo, resposta
   inesperada, versão divergente, staleness suspeita ou ambiguidade. Indisponível **nunca** vira `allow`.
3. **Fonte única da lógica de decisão = `ClaudeCodePreToolUseSafeAllowSupport.ps1`.** O daemon
   **reusa** `Get-PtuDecision` por dot-source; **proibido** reimplementar o classificador noutra
   linguagem (divergência = falso-allow silencioso). **(reforço v3)** "Fonte única" inclui a
   **semântica de tokenização** (o `shlex` que produz os segmentos), não só o veredito — ver §4.1.
4. **O daemon nunca executa o comando do usuário.** Recebe o JSON do hook, **classifica**, devolve
   `allow`/`defer`. Não há caminho de execução do `command`.
5. **Gate de segurança = self-test adversarial**, agora também através do daemon **e do cliente** (§8).
6. **O cliente só tokeniza e transporta — nunca decide `allow`.** Mesmo que o `shlex` migre para o
   cliente (§4.1), todo **veredito** fica no daemon (`Get-PtuDecision`). O cliente, isolado, é
   **incapaz** de emitir `allow` — invariante provado por self-test, análogo ao já provado para
   `Get-PtuBashFastPath` (`...Support.ps1:132-133`).

## 3. Arquitetura proposta

```
Claude Code  --(stdin: hook JSON)-->  [CLIENTE leve]  --(IPC: ver §4.2)-->  [DAEMON pwsh persistente]
                                            |                                         |
                                            |<---  resposta = enum {allow|defer}  ----| (Get-PtuDecision)
                                            v
                                   stdout: hookSpecificOutput (montado PELO cliente, JSON exato em §3.1)
```

- **Daemon:** `pwsh` persistente que dot-source o `...Support.ps1` **uma vez**, abre o canal IPC
  **só após `ready`** (§5) e entra em loop: lê uma requisição enquadrada, valida, chama
  `Get-PtuDecision`, devolve **o enum**. Custo de startup pago **uma vez**.
- **Cliente (o comando do hook):** programa de **inicialização rápida** que conecta, repassa o JSON
  do stdin (ou os segmentos já tokenizados, §4.1), lê **o enum** e **monta ele mesmo** o
  `hookSpecificOutput` (§3.1). Em qualquer falha (canal ausente/ocupado/subindo, timeout, lixo,
  versão divergente) → imprime **`defer`** e sai 0 (fail-closed). **Nunca** monta `allow` sozinho.
- **Resposta como enum estreito** (correção do painel): o daemon devolve **apenas** `allow`|`defer`
  (+ campos diagnósticos que o cliente ignora), **não** JSON arbitrário. Reduz superfície de injeção.

### 3.1 JSON exato que o cliente emite (contrato, da spec congelada)

O cliente reproduz **byte-a-byte** o formato do decisor atual (`Get-PtuHookOutput` em
`Invoke-ClaudeCodePreToolUseSafeAllow.ps1`), trocando só `permissionDecision`:

```json
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"ptu-daemon vX"}}
```

Para **abster-se** (o `defer` **interno** da decisão), o cliente **NÃO emite `permissionDecision`** —
stdout vazio, exit 0 (ver a **CORREÇÃO APLICADA** logo abaixo, verificada no fio real 2026-07-01).
**Nunca** `deny` nem `ask`. O self-test (§8) compara o payload do cliente com o do decisor in-process para
o mesmo input (allow → JSON idêntico; abster → ambos vazios).

> **CORREÇÃO APLICADA 2026-07-01 (verificação empírica das sondas em 2026-06-30 — autorizada pelo autor, dispensa painel):
> abster-se = NÃO emitir `permissionDecision` (saída vazia), NUNCA `defer` NEM `ask`.** Duas sondas no
> Claude Code **interativo** (hook temporário, backup/restore do settings.json): (a) `permissionDecision
> "defer"` **QUEBRA** (erro interno / tool result perdido) — `defer` é **headless-only** (`-p`/Agent SDK;
> hooks-guide l.586); (b) `permissionDecision "ask"` **força prompt mesmo sobre comando que a allowlist do
> usuário JÁ auto-aprovaria** (medido: `ls` na allowlist rodou **sem** prompt com o hook sem opinar; o
> mesmo `ls` com o hook emitindo `ask` **disparou prompt**) — logo mapear abster→`ask` seria **REGRESSÃO**
> (e no observe passivo pediria prompt em TODA ferramenta, deixando de ser passivo). O mecanismo oficial de
> "não opino → segue o fluxo normal" é **exit 0 SEM `permissionDecision`** (hooks-guide l.556: "the normal
> permission flow still applies" → a allowlist decide). Logo a "boca" §3.1: decisão `allow` → emitir
> `permissionDecision:"allow"`; decisão de abster (o `defer` **INTERNO**) → **NÃO emitir `permissionDecision`**
> (stdout vazio, exit 0); nunca `ask`, nunca `deny`. `defer` permanece **token interno** do
> protocolo/decisão/gate §8. Toca a "boca" (`HookClient.WriteHookOutput` + `Get-PtuHookOutput`) + os
> self-tests que conferem a saída §3.1 (passam a esperar saída **VAZIA** na abstenção) + este §3.1.
> **APLICADO 2026-07-01:** `EmitStep31` no cliente (`HookClient.cs`) emite `permissionDecision` só no
> `allow`; abster → nada. Mesma regra no decisor in-process (`Invoke-ClaudeCodePreToolUseSafeAllow.ps1`,
> condicional em `Get-PtuHookOutput`) e nos self-tests que conferem a saída §3.1 (sentinela `(abstain)` p/
> saída vazia; o wire do daemon mantém `defer`). 4 self-tests verdes (ClientStepD, Observe, SafeAllow
> in-process, gate §8). **Confirmado no fio real:** hook `PreToolUse[Bash] --observe` no Claude Code
> interativo — `echo` rodou sem prompt (a allowlist decidiu) e o log de medição registrou a linha, provando
> que `abster` = saída vazia é aceita como *no decision*. Wire (Passo G2.2) entregue via
> `Install -Wire observe|enforce|off` e ativo em observe (Fase 3).

## 4. A decisão central — tokenização, IPC e runtime do cliente

### 4.1 Onde roda o `shlex` (o 2º python) — e a prova de equivalência

Duas saídas, **igualmente válidas até o passo 0** (sem preferência provisória — o painel apontou
viés de confirmação em pré-escolher (a)):

- **(a) Cliente tokeniza:** o cliente roda o `shlex` e manda ao daemon os **segmentos já tokenizados**;
  o daemon só roda as `Test-Ptu*SegmentAllowed` (in-process puras, sem python). **Elimina o 2º python.**
  **Condição de aceite (cravada):** a tokenização do cliente deve ser **identidade de artefato** — o
  **mesmo** `Get-ClaudeCodeBashSafeSegments.py` (mesmo arquivo/hash), **não** uma reimplementação
  "equivalente". `shlex.split` (Python) ≠ o split do PowerShell em aspas/escapes; uma 2ª implementação
  diverge silenciosamente → segmentos errados → `allow` indevido (viola §2.3). **Não basta paridade
  por corpus** (seria circular: testa o caminho novo contra si mesmo).
- **(b) Daemon mantém o `shlex`:** o daemon segura um **processo Python persistente** para o `shlex`
  (ex.: `Start-Process python -RedirectStandardInput`, mantido vivo pelo loop do daemon; o startup do
  python é pago **uma vez**, não por requisição). Mantém a fronteira atual (cliente burro). Custo: um
  2º processo de longa vida a gerenciar (memória + ciclo de vida).

**Regra de decisão (cravada):** **(a)** só é aceita se o self-test de equivalência (§8) passar com
**identidade de artefato + modo de decomposição auditável** (abaixo). **Se a equivalência não
fechar no passo 0, (b) é OBRIGATÓRIA, não opcional.**

**Modo de decomposição auditável (pré-requisito de (a)):** `Get-PtuDecision` ganha um modo que
**expõe os segmentos** que ele produziria internamente a partir da **string crua**. O self-test então
compara, sobre o **mesmo corpus adversarial**: `in-process(string crua) → segmentos` **vs**
`cliente(string crua) → segmentos`. Divergência de **segmentos** (não só de veredito) = falha. Sem
esse modo, a paridade é circular e não prova nada.

### 4.2 Transporte IPC: named pipe vs TCP loopback

| Opção | Prós | Contras |
|---|---|---|
| **Named pipe** | **ACL nativa por-usuário** (modelo de confiança forte); sem porta de escuta | `open(r'\\.\pipe\...')` da stdlib Python **não** basta para `PIPE_ACCESS_DUPLEX`/message-mode → exige `pywin32`/`ctypes` (**derruba o "zero dep"**) ou um cliente **NativeAOT** (que fala pipe nativamente) |
| **TCP loopback** | stdlib `socket` puro (zero dep), simples em Python | `127.0.0.1` ≠ "só este hook" → **token de sessão** obrigatório (auth caseira, mais frágil que ACL nativa); **porta de escuta dispara DLP/endpoint-protection corporativo** (apontado pelo painel) — pode ser **inviável** para devs em ambiente corporativo |

**Dissidência registrada do painel:** glm-5.1 preferiu TCP stdlib (zero-dep); Codex e Claude
preferiram named pipe (ACL nativa > token-em-arquivo). A própria objeção corporativa (DLP) de glm-5.1
**reforça** named pipe. **Posição da v4 (enquadramento honesto — correção da rodada 3):** o painel
apontou que chamar os dois de "co-primários" e ao mesmo tempo dar vitória ao pipe "no empate" era uma
**pré-escolha disfarçada de empírica**. Então, sem rodeio: **named pipe + cliente NativeAOT é o
default PREFERIDO** (por ACL nativa); **TCP+token + cliente Python é FALLBACK**, usado só quando o
primário for **inviável** (build NativeAOT impossível/incompatível na máquina alvo) ou seu p95
estourar. O passo 0 **valida o primário e mede o fallback** — **não** "desempata". A ACL é **parte do
contrato, não default**: pipe → ACL explícita pelo SID; TCP → token + ACL do arquivo de descoberta (§7).

### 4.3 Runtime do cliente

| Opção | Startup típico (Win) | Dependência | Casa com |
|---|---|---|---|
| **Python** (stdlib `socket`) | ~30–60 ms + `import json` + conexão | já é dep (`shlex`); zero build **se** stdlib bastar | **TCP+token** |
| **.NET exe (NativeAOT)** | ~10–30 ms; named pipe nativo | passo de build + binário | **named pipe** |
| **`pwsh` cliente** | ~500 ms | nenhuma | **proibido** (é o problema) |

### 4.4 Tabela de decisão binária (passo 0 → escolha, sem "decidir depois")

Medir o primário (NativeAOT+pipe) e o fallback (Python+TCP) no passo 0 e aplicar, **nesta ordem**:

1. Se **`pwsh -NoProfile` isolado já cabe** no orçamento (improvável, dado os 520 ms) → **sem daemon**;
   volta ao modelo in-process com pwsh enxuto. (Gate teórico; ver §9-0a — é baseline, não saída esperada.)
2. Senão, **validar o primário (NativeAOT+pipe)** pelo **critério §9-0e re-enquadrado** (§9-0b): se o
   **overhead do daemon sobre o piso de spawn ≤ 5 ms** (gate **pretensamente host-independente** —
   controlável pela implementação e normalizado contra o floor; portabilidade a confirmar noutro host —,
   pelas duas métricas obrigatórias do §9-0e) e o build NativeAOT é viável na máquina alvo → **adota-se o
   pipe — fim**. (O p95/p99 absoluto da redação original é governado pelo piso de spawn — vira telemetria
   por host, ver §9-0e.) Mede-se o **fallback Python+TCP** só para o caso de o primário ser **inviável** ou
   **regredir o overhead** (a redação original dizia "estourar [o orçamento absoluto]"; com o re-enquadramento
   o gatilho do fallback passa a ser **regredir o overhead-sobre-o-piso**, não estourar um teto absoluto):
   - primário inviável/**regride o overhead** **e** TCP cabe **e** TCP **viável** (sem bloqueio de DLP) → adota **TCP+Python**.
   - TCP **inviável por DLP** → permanece **NativeAOT+pipe**; se nem ele couber, reabre §4.3.
   Ou seja: o passo 0 **confirma** o primário e só recorre ao fallback por **inviabilidade medida** —
   **não** é um "empate" com vencedor pré-fixado.
3. A escolha de §4.1 (a/b) é **independente** e decidida pela equivalência (§4.1), não pelo transporte.

**Dois estados distintos (correção da rodada 3):** *congelamento do design* (este documento, ao fim da
4ª rodada — encerra a iteração de papel) **≠** *liberação da implementação* (v1/observe/enforce). Os
números medidos atualizam este doc **antes da liberação**, **não** antes do congelamento do design.

## 5. Ciclo de vida do daemon — mutex, `ready` e corrida

- **Canal só existe após `ready`.** O daemon **não** cria o pipe / **não** faz `listen` (TCP) antes
  de: dot-source OK, self-check de hash/versão OK. Assim, **antes de `ready` a única semântica é
  "canal ausente"** — não há "canal existe mas não responde". Mata a janela do daemon meio-inicializado.
- **Subida única guardada por mutex, segurado até `ready`.** Antes de spawnar, o cliente adquire um
  **named mutex** cuja identidade segue §7 (SID + repo + roots). **Só** quem adquire o mutex spawna; o
  spawner **segura o mutex até observar `ready`** (ou até **timeout de subida ≤ 2 s**, então libera —
  daemon que morre na subida não pode prender o mutex eternamente). Clientes que **não** adquirem o
  mutex devolvem **`defer` imediatamente, sem tentar conectar nem spawnar** outro daemon.
- **Cliente distingue, mas tudo vira `defer`.** "canal ausente" (→ tenta mutex/spawn, **uma vez**) vs
  "canal existe mas recusa/ocupado" (→ só `defer`). Toda falha → `defer`.
- **Backoff hard-coded (não "opt-in").** Para reduzir avalanche no arranque, o cliente tenta
  reconectar **2 vezes em ≤ 30 ms total** (hard-coded na v1; configurável é evolução). Estourou o
  micro-orçamento → `defer`. O **máximo de `defer`s por arranque** é medido no passo 0 (§9-0d).
- **Persistência entre reboots:** fora da v1. Auto-start no login é **evolução** e deve **reusar os
  padrões da skill `xpz-daemon`** (dependência documentada), não inventar outro mecanismo.
- **Watchdog (dívida):** detecção de daemon travado/órfão (PID + heartbeat) é evolução; o timeout do
  cliente já garante `defer`.

## 6. Frescor da lógica (staleness) — regra única + backoff

Servir lógica velha como boa = falso-allow. Decisão cravada:

- **Primário: hash SHA256** do `...Support.ps1` (e do helper `shlex` se §4.1(a)) por requisição.
  **Não** mtime como primário (`git checkout`/`stash` não preservam mtime; granularidade NTFS engana).
- **Cache `(path,size,mtime)` com recomputo, não skip:** o cache **não pula** o hash — ele evita
  reler o arquivo quando `(size,mtime)` batem, mas o caso perigoso (git restaurando **tamanho igual**
  com conteúdo diferente entre commits) é coberto porque, na dúvida de mtime, recomputa-se o hash.
  Anotado: cache seguro **só** em disco local; `...Support.ps1` deve estar em disco local.
- **Hash com timeout (ex.: 20 ms):** estourou (AV segurando o arquivo) → `defer` **na requisição
  corrente** e marca `stale-uncertain`; **não** dispara restart na 1ª falha.
- **Secundário: handshake de versão** (`$script:PtuSafeAllowVersion`) — segunda barreira (o número é
  manual e não bumpa sozinho; pega incompatibilidade de contrato, não edição).
- **Regra única "dúvida → `defer` + restart", COM backoff e cap:** hash divergente → `defer-only` +
  re-dot-source. O re-dot-source é **envolto em try/catch que mantém o loop vivo**. Se o reload
  **falhar** (arquivo meio-escrito/sintaxe quebrada), **backoff exponencial** (1 s, 2 s, 4 s … cap
  30 s); **após N=3 falhas consecutivas**, o daemon **suspende os retries ativos** e fica em
  `defer-only` — **nunca** busy-loop devorando CPU.
- **Recuperação do `defer-only` (cravado — correção da rodada 3):** a saída do `defer-only` **não**
  depende de `touch`/restart manual (senão o daemon fica órfão por tempo indeterminado). Um
  **watchdog interno** re-tenta o hash/reload num intervalo **lento** (ex.: a cada 30 s, **fora** do
  caminho quente) enquanto estiver `defer-only`; reload bem-sucedido → volta a `ready`. **Telemetria
  obrigatória:** toda entrada/saída de `defer-only` e `stale-uncertain` vai ao **log mínimo da v1**
  (§7) com rate-limit — sem isso, um daemon degradado vira "tudo virou prompt" invisível ao usuário.
  (O watchdog de processo **travado/órfão** — PID+heartbeat — segue evolução; este é só o re-hash
  periódico para sair de `defer-only`.)

## 7. Concorrência, identidade e segurança

- **Concorrência:** v1 é **single-threaded síncrona** (uma conexão por vez); cada decisão é sub-ms.
  **Limiar explícito (delta de contenção, não o piso de spawn):** se a medição de contenção mostrar que a
  **espera em fila** — o acréscimo do e2e sob contenção sobre o e2e sem contenção, **medido no mesmo harness,
  mesmo percentil e mesma classe de cenário, comparando `ready` sem contenção vs `ready` sob contenção** —
  empurra o caminho quente de forma perceptível, a saída é **canal por sessão**
  (identidade + `<sessionId>`), **não** múltiplas instâncias de daemon. (O p95 e2e **absoluto** é governado
  pelo piso de spawn — §9-0e —, não pela fila; o gatilho é o **delta de contenção**. Este limiar **não**
  altera o *deadline* monotônico de ~80 ms do cliente, abaixo, que é orçamento de espera de resposta, não
  percentil e2e.)
- **Identidade (TODOS os artefatos de coordenação — cravado):** mutex, canal (pipe/porta), token e
  arquivo de descoberta incluem o hash de **(SID do usuário + caminho canônico do repo + conjunto
  `PTU_SAFE_ALLOW_ROOTS` resolvido)**. "Caminho canônico" = `Resolve-Path` seguindo symlinks/junctions
  (não o `$PWD` cru). Nome por **SID**, não `$env:USERNAME` (muda em renomeação). Isso impede que um
  daemon de **outro checkout/branch** ou com **roots divergentes** responda por engano (a 1ª barreira
  de `Get-PtuDecision` é `Test-PtuCwdInScope`, `...Support.ps1:190` — daemon com roots errados a furaria).
- **ACL como requisito verificável (não mecanismo fixo):** o **self-test inspeciona a ACL efetiva** do
  canal; o mecanismo pode variar (PowerShell puro ou helper C# inline para pipe; ACL do arquivo de
  token para TCP), mas o **resultado** (só o usuário corrente) é testado.
- **Token de sessão TCP — ciclo de vida cravado:** recriado pelo daemon a cada subida, escrito
  **atomicamente** (move-from-tmp) em arquivo com ACL só-usuário, em diretório com ACL só-usuário. Se
  o cliente não acha o token → `defer` (não cria outro daemon; isso é do mutex). Conexão sem token
  válido → daemon responde "token rejeitado" → cliente trata como `defer`.
- **Protocolo do wire (cravado):** framing **length-prefixed** (4 bytes big-endian + payload UTF-8),
  **não** line-delimited. **`protocolVersion` no framing** (separado de `$script:PtuSafeAllowVersion`,
  que é da lógica). **Tamanho máximo = 64 KB** (cobre qualquer comando razoável; acima → `defer`). O
  daemon valida JSON + tipos de `tool_name`/`tool_input.command`/`cwd`; anomalia → `defer`. Handshake
  de versão **por-requisição** (TCP persistente pode atravessar um reload). Resposta = enum `allow|defer`.
- **Shutdown — plano de controle separado por opcode:** **magic byte** no início do frame
  (`0x01`=dados/classificação, `0x02`=controle/shutdown). Shutdown exige a mesma auth (token/ACL).
  **Não** é "JSON de hook com campo especial" (seria DoS por input que parece shutdown).
- **Timeout do cliente = deadline monotônico único (~80 ms)** do qual se derivam connect/read (não
  50+50 fixos, que sozinhos já comem 100 ms). Estouro → `defer` e sai 0. **Sem timeout o hook pendura**
  (pior que prompt). Self-test com daemon que dorme (§8).
- **Log mínimo NA v1 (promovido de dívida):** decisão + estado do daemon (`ready`/`defer-only`/
  `stale-uncertain`) + timestamp + código de erro, **sem o `command` completo** (privacidade), com
  limite de tamanho e rotação. Gravado em **local conhecido e inspecionável** —
  `%LOCALAPPDATA%\xpz-pretooluse\ClaudeCodePreToolUseSafeAllowDaemon.log` — e a v1 **documenta como
  verificar o estado** do daemon (senão a telemetria de `defer-only`/`stale-uncertain` é "observável
  em teoria, invisível na prática"). Sem ele, um daemon degradado é indistinguível de "tudo virou prompt".

## 8. Prova (self-test) — o gate continua sendo a segurança

- **Equivalência de tokenização (gate de §4.1(a)):** modo de decomposição auditável; compara
  `in-process(string crua) → segmentos` vs `cliente(string crua) → segmentos` no corpus adversarial.
  Divergência de segmentos = falha. + identidade de artefato (mesmo `.py`/hash). Falhou → (b) obrigatória.
- **Paridade daemon↔in-process** e **cliente↔daemon:** mesma decisão final + mesmo payload (§3.1).
- **Invariante do cliente:** o cliente, isolado, **nunca** emite `allow` (só `defer`/tokens).
- **Fail-closed:** daemon parado/subindo → `defer` para todo o corpus; daemon que **dorme** além do
  deadline → cliente devolve `defer` **dentro do orçamento**, sem pendurar.
- **Staleness ao vivo:** edita o `...Support.ps1` com o daemon vivo → decisão muda ou vira
  `defer`+restart; reload quebrado → `defer-only` com backoff, sem busy-loop.
- **ACL efetiva:** inspeciona a ACL do canal (só o usuário).
- **Protocolo:** framing adversarial (`\n`/`\0`/delimitador embutido, JSON truncado, > 64 KB) → `defer`.
- **Carga paralela — BLOQUEANTE na v1 (subido de "desejável"):** mínimo de dois testes: N clientes
  simultâneos **na subida lazy** (conta `defer`s, exige no máximo um daemon) e N clientes simultâneos
  **com daemon `ready`** (p95 sob contenção). Pré-requisito: `...Support.ps1` sem estado mutável global.
- **Sentinela** `OK: Test-...DaemonSelfTest.ps1`. O self-test é o **gate**; o observe mede cobertura/latência.

## 9. Sequência de implementação — passo 0 é PROTÓTIPO DESCARTÁVEL

**Passo 0 — MEDIÇÃO (protótipo instrumentado e descartável; sem fio no hook real; nada vira código
final automaticamente; nada se implementa como v1 antes de fechar):**
- **0a. Baseline obrigatória (NÃO gate de existência):** medir `pwsh -NoProfile -NoLogo -NonInteractive`
  isolado e o hook atual completo. Os 520 ms já são conhecidos → 0a quase certamente confirma o daemon;
  serve de **baseline** (não de saída prematura). Só no caso improvável de caber sem daemon, voltar ao
  modelo in-process com pwsh enxuto e **dissolver** o resto desta frente.
- **0b. Caminho real e2e** do primário (NativeAOT+pipe) e do fallback (Python+TCP), com o código de
  conexão **real**, medindo **p95/p99 end-to-end**, com Defender ativo e carga, ≥100 invocações, **separando**
  `defer`-comum de `allow`-candidato, **+ check de viabilidade corporativa do TCP** (a porta de escuta
  passa pelo DLP do ambiente alvo?).
- **0c. Equivalência de tokenização** (§4.1/§8) para decidir (a) vs (b).
- **0d. Caminho frio sob paralelismo:** com o daemon parado, rajada de K tools simultâneas (arranque de
  sessão) → conta `defer`s até `ready`; teto aceitável e **um** único daemon.
- **0e. Critério de veredito (RE-ENQUADRADO pós-passo-0 — substitui o orçamento absoluto da v4; base
  empírica em `historico/passo0-daemon-pretooluse-medicao-20260628/relatorio-passo0-v5.md` + recompute do
  `robust1k-series.csv`; revisado por rodada própria de revisão por pares, ver §11):** a medição do passo 0
  provou que a cauda **p95 ~180 ms é o piso do cliente/processo AOT neste host e neste modelo
  "hook-nasce-cliente"** (o floor `return 0;` dá p95 ~180 ms, idêntico ao e2e) — piso que agrega runtime,
  antivírus, prioridade, agendamento e teardown, **fora do controle da implementação do daemon enquanto o
  modelo continuar exigindo um cliente novo por invocação**; o overhead do daemon sobre esse piso é **~1 ms**.
  Logo o **p95 ≤ 80 / p99 ≤ 100 ms absoluto é fisicamente inatingível** sob este modelo e é **substituído**
  pelos critérios abaixo. O daemon **só é liberado** se valerem juntas:
  - **(i) GATE de liberação — overhead do daemon sobre o piso de spawn ≤ 5 ms, pretensamente
    host-independente (controlável pela implementação e normalizado contra o floor; portabilidade a confirmar
    pelo protocolo portátil noutro host, §8 do relatório do passo 0)**, para o `defer`-comum **e** o
    `allow`-candidato. **Duas métricas, ambas obrigatórias, ambas com teto ≤ 5 ms (a mais estrita vence se
    divergirem):** (1) **diferença percentil-a-percentil** `e2e_pX − floor_pX` **≤ 5 ms até o p95** (medido:
    p50–p90 ≤ 1 ms; p95 defer 2,6 / allow 3,3 ms — todos dentro) — métrica robusta sobre duas distribuições
    marginais ordenadas; **não** é overhead pareado verdadeiro e pode subestimá-lo se as caudas divergirem
    (p99 negativo = "e2e abaixo do floor", ruído); (2) **overhead pareado** (subtração na mesma iteração) com
    **p90 ≤ 5 ms** (medido: defer 3,9 / allow 4,4 ms) — overhead verdadeiro, confiável só **até ~p90**: acima
    disso o pareamento **se descorrelaciona** (p95 pareado ~154 ms = jitter de spawn não-correlacionado,
    **não** overhead — das **64 iterações de floor lento (>80 ms)**, só **9 (`defer`) / 6 (`allow`)** têm o
    e2e lento junto, e **~21% das iterações** [defer 21,8 / allow 21,2%] têm overhead pareado negativo;
    recompute do CSV, n=1000) e o overhead **deixa de ser medível por pareamento** → por isso a telemetria
    por host, abaixo. **Não** se usa o p95 pareado como critério.
  - **(ii) Guardrail de cauda por-host (normalizado contra o floor, NÃO parte da tese de host-independência):**
    o **`%>80 ms` do e2e não excede o do floor em mais de ~1 pp** (medido: floor 6,4% vs e2e 6,7–6,9% =
    +0,3–0,5 pp) — é o que o daemon **acrescenta**; o valor absoluto é governado pelo piso.
  - **(iii)** o `defer`-comum **não regride** além de **≤ 5 ms** sobre o hook pwsh atual completo (**base
    inalterada**, ~520 ms) — preservado da v4; trivialmente satisfeito.
  - **Alvo/telemetria por host (NÃO gate de liberação): p50 ≤ 40 ms, p90 ≤ 60 ms** (calibrados **neste host**;
    medido ~28 / ~32). São **host-dependentes** como p95/p99 (todos contêm o piso de spawn como termo aditivo);
    tratá-los como gate repetiria, em host mais lento, o erro conceitual que motivou este re-enquadramento.
    Úteis para detectar regressão **neste host**; não bloqueiam liberação noutro.
  - **Telemetria por host (NÃO gate de aprovação): p95/p99** — governados pelo piso de spawn (~180 ms p95
    **neste host**), fora do controle de qualquer implementação; reportados, não usados como liberação.
  - **Ressalva de processo:** este re-enquadramento foi **mudança de design congelado, NÃO pré-aprovada**,
    submetida a **rodada própria de revisão por pares** antes do re-congelamento (ver §11). Se o painel tivesse
    rejeitado, o §9-0e absoluto **permaneceria** e a saída honesta seria **(a) dissolver** (§9-0f) — **nunca**
    liberar o primário sob o critério antigo violado. Aplicar a tabela §4.4 com os números.
  - **NOTA PÓS-PASSO-F + PAINEL (reconciliação, 2026-06-30 — decisão datada do autor; revisão por pares VINCULANTE: 5 vozes/3 famílias, unânime "revisa com gaps"; fontes: `historico/passoF-daemon-pretooluse-medicao-20260630/relatorio-passoF-v1.md` + `.../revisao-por-pares-passoF-v1.md`):** a medição do **FIO REAL** (cliente NativeAOT + daemon pwsh já buildados, **não** o protótipo do passo 0) deu overhead-sobre-o-piso **~20–34 ms** (cross-check perc-a-perc ~19–30 ms até p95; pareado p90 ~32–34 ms; n=1000, 0 mismatch) → o teto de **5 ms do (i) REPROVA**. **Esta nota SUBSTITUI a leitura inicial do autor** ("(i) gate→alvo porque reprovou"), corrigida pelo painel. **(1) Re-rotulação honesta:** o (i) — overhead sobre o piso de spawn — **sempre foi um ALVO de EFICIÊNCIA do daemon, não um gate de segurança/correção** (o protótipo ~1 ms calibrou o teto de 5 ms de forma não-representativa: cliente sem identidade ~5,5 ms; daemon sem a matriz de staleness nem a dupla desserialização ~17–24 ms/req); o (i) fica **reclassificado como ALVO de eficiência** e o sinal que captou (~17–24 ms de processamento PowerShell por requisição) vira **dívida de engenharia rastreada**, não descartada. **(2) Alvo numérico+datado** (senão "alvo" = "ignorado"): reduzir o processamento do daemon por requisição para **≤ 10 ms até o Passo H** (evitar a dupla desserialização JSON; enxugar a matriz de staleness no caminho quente; eventualmente mover o laço quente para fora do PowerShell). **(3) Novo gate de liberação operacional** (substitui o (i) como *condição*, não remove o controle): o fio só liga sob **(ii)** guardrail de cauda **e (iii)** não-regressão vs hook pwsh (ambos passam) **e** a caracterização de **concorrência** do daemon single-threaded — (a) nenhuma saída ≠ allow/defer sob rajada [medido qualitativamente: `other=0` em N=1/5/10/20], (b) degradação sempre para defer [defer sobe ~10→25% de N=5 a N=20, benigna], (c) latência sob carga documentada [a caracterizar na **Fase 3 (observe)** do Passo G em uso real — a latência absoluta é confundida por carga da máquina; indicativa em bancada: p95 ~1 s @N=5, ~5 s @N=20]. **(4) Salvaguarda:** o §9-0e já foi re-enquadrado **2× ao reprovar** — **qualquer 3ª alteração exige nova rodada de revisão por pares (≥2 famílias), nunca decisão solo**; esta nota É essa rodada para a 2ª alteração. **Decisão do autor (2026-06-30):** fio **APROVADO no mérito** (~50 ms fail-closed, 0 mismatch, vs ~466 ms do hook / ~1.500–10.000 ms do clique humano); **enforce (Passo G) condicionado** à Fase 3 (observe) fechar (c). Segurança (§8 verde) intocada.
- **0f. Gate de saída do passo 0 (cravado — correção da rodada 3):** o passo 0 conclui com um
  **relatório empírico** versionado (no histórico do repo: números brutos, metodologia, ambiente,
  commit) **e uma decisão explícita e datada do autor** entre (a) dissolver a frente, (b) adotar
  NativeAOT+pipe, ou (c) adotar TCP+Python. Essa decisão é **revisada por outro par**, e essa revisão
  é **obrigatória e vinculante** (não consultiva): se o par discordar, o **default é conservador** —
  adotar o fallback ou dissolver a frente, **nunca** liberar o primário sob divergência. Sem esse
  gate, o passo 0 degenera em laço de "só mais uma medição".
1–5. Só após 0 fechar: daemon + `ready`/mutex (§5); cliente (a/b e runtime conforme §4.4); staleness
   (§6) + protocolo (§7) + log; self-tests (§8, incl. paralelo bloqueante); Fase 3 (observe) → Fase 4
   (enforce) → Fase 5 (fio via `xpz-skills-setup`, subindo o daemon por máquina, fora da v1).

## 10. Questões abertas remanescentes (pós-rodada 2)

Todas dependem **dos números** do passo 0 — não há mais decisão de papel pendente:

- **§4.1** (a) vs (b): decidida pela equivalência de tokenização (0c).
- **§4.2/4.3/4.4** named pipe+NativeAOT (**default preferido**) vs TCP+Python (**fallback**): validada
  por 0b + tabela §4.4 (o passo 0 confirma o primário; recorre ao fallback só por inviabilidade medida).
- **§7** limiar de contenção que dispara "canal por sessão": decidido por 0b/0d.

## 11. Proveniência (revisão por pares)

- **Rodada 1 `daemon-design-v1`** (2026-06-27): manuscrito = v1; veredito unânime "revisar — direção
  certa, não congelar"; 7 gaps convergentes.
- **Rodada 2** (2026-06-27): manuscrito = v2 (commit `a8c1bc1`); mesmo painel (Claude Opus nativo
  `anthropic`; Codex `gpt-5.5` `openai`; `nvidia/z-ai/glm-5.1`, `nvidia/moonshotai/kimi-k2.6`,
  `nvidia/minimaxai/minimax-m2.7`; preferidos `ollama-cloud/*` `unavailable` por cota, substituídos
  pelos NVIDIA). **5 vozes / 3 famílias.** Veredito: **4 aprova-com-ressalvas + 1 revisar** — os 7 gaps
  aceitos como fechados; bloqueio restante = §4.1(a) (identidade de artefato + decomposição auditável),
  tabela de decisão de transporte, identidade completa (repo+roots), critério de regressão do
  `defer`-comum, staleness com backoff, ciclo mutex↔ready, protocolo versionado, log na v1. Dissidência
  de transporte (TCP zero-dep vs pipe ACL) registrada em §4.2.
- **Rodada 3** (2026-06-27): manuscrito = v3 (commit `7d464a8`); mesmo painel (Claude Opus nativo;
  Codex `gpt-5.5`; NVIDIA glm-5.1/kimi-k2.6/minimax-m2.7; `ollama-cloud` segue `unavailable` por cota).
  **5 vozes / 3 famílias.** Veredito: **3 *congelar* (Claude, glm-5.1, minimax) + 2 aprova-com-ressalvas
  (Codex, kimi)** — os 7 gaps da rodada 1 e os convergentes da rodada 2 aceitos como fechados; as 2
  ressalvas condicionaram o "congelar" a 4 ajustes: orçamento absoluto do `defer`-comum, distinção
  congelamento≠liberação + gate de saída do passo 0, recuperação do `defer-only`, e enquadramento
  honesto do transporte. Minoria (kimi) sobre o transporte: registrada e acatada (default preferido +
  fallback).
- **Rodada 4** (2026-06-27): manuscrito = v4 (commit `60094ea`); mesmo painel. **5 vozes / 3 famílias.**
  Veredito: **4 *congelar* (Claude, Codex, glm-5.1, minimax) + 1 aprova-com-ressalvas (kimi)**, esta
  última condicionada a 3 polish de contrato (gate 0f vinculante, caminho do log, resíduo lexical) e
  **sem exigir nova rodada**. Polish aplicado no commit `b575b74`.
- **Re-consulta da versão final** (2026-06-27, sobre `b575b74`): por decisão humana de escopo,
  consultaram-se primeiro os 2 revisores que levantaram os 3 itens (kimi: ressalvas A/B fechadas;
  Claude: lexical limpo) e, em seguida, o **painel inteiro** confirmou a versão exata final — **5/5
  "pode congelar", 3 famílias, zero gap de papel**. (1ª tentativa do Codex inválida por contradição no
  manuscrito → `noResponse`; re-disparo confirmou.)
- **CONGELAMENTO (2026-06-27):** design **congelado** na v4 (`b575b74`) por Antonio José
  (antonio@frigobyte.com), após confirmação unânime do painel. Closeout auditado:
  `resubmissionDeclinedByHuman` — a prova restante (números) é transferida para o **passo 0 de
  medição** + self-tests, frente separada. Nenhum código de daemon implementado.
- **Rodada de re-enquadramento do §9-0e (2026-06-28):** manuscrito v1→…→v6 (6 rodadas), painel de **3
  famílias efetivamente consultadas** (siliconflow, openai, anthropic; **nvidia** entrou na r6 ao re-disparar
  vozes; piso `panelReady`). Motivada pelo passo 0: a cauda p95 ~180 ms é o piso do cliente/processo AOT
  neste host (**fora do controle da implementação enquanto o modelo exigir um cliente novo por invocação**),
  tornando o orçamento absoluto p95 ≤ 80 / p99 ≤ 100 do §9-0e **fisicamente inatingível**. O re-enquadramento
  **substitui** o orçamento absoluto pelo **overhead-sobre-o-piso ≤ 5 ms** (gate) e **dissolve a sub-condição
  (ii)** do §9-0e original — o `defer`-comum **deixa** de estar sujeito ao orçamento absoluto p95/p99;
  sobrevive a (iii) não-regressão ≤ 5 ms; p50/p90/p95/p99 viram alvo/telemetria por-host.
  - **Trajetória:** R1 (mérito aprovado + questão aberta p50/p90=telemetria resolvida por unanimidade) → R2
    (refinos de redação) → **R3: 5/5 concordam, zero gaps bloqueantes**, (b) NativeAOT+pipe endossado por
    todos → R4 (Codex achou gap de número, confirmado por recompute) → R5 (correção dos números de cauda;
    contradição entre recomputes adjudicada) → **R6 (v6): convergência — 3 famílias (openai/Codex,
    anthropic/Opus, nvidia/GLM-5.1) CONCORDA com recompute próprio independente; siliconflow/MiniMax concorda
    no conceito; DeepSeek-V4-Pro `timeout` em ambos os provedores.**
  - **Adjudicação empírica (recompute autoritativo do `robust1k-series.csv`, n=1000):** negativos do conjunto
    **21,8% (defer) / 21,2% (allow)**; interseção floor-lenta ∩ e2e-lenta **9 / 6**; floor-lentas **64/1000**;
    perc-a-perc p95 defer 2,6 / allow 3,3 ms; p90 pareado 3,9 / 4,4 ms. A dissidência da r5 (DeepSeek, "~16%
    no conjunto") foi **refutada por recompute** (o ~16% é o subconjunto modo-rápido) e registrada
    `skippedByHumanDecision`.
  - **Revisores preferidos (`preferred-reviewers.json`):** `anthropic/claude-opus-4-8` e `openai/gpt-5.5`
    `responded`; tríade `ollama-cloud` `unavailable` (cota semanal) → substituída por SiliconFlow/NVIDIA por
    decisão humana. Closeout: `closeoutReady=true`, `vNextState=resubmitted`. Convergência declarada pelo
    autor; **§9-0e re-congelado** com o critério re-enquadrado. Nenhum código de daemon implementado.
