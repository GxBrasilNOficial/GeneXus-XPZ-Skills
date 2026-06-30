# Relatório empírico do Passo F (medição do FIO REAL) — daemon do hook PreToolUse (auto-allow) do Claude Code

## Natureza deste documento (LEIA PRIMEIRO)

Este é o **registro empírico do Passo F** + a **decisão datada do autor** (§9-0f), na §8. A decisão **já foi
proferida pelo autor** (2026-06-30), que **dispensou o painel de pares** por considerar o ponto de mérito
evidente (ver §8). O documento permanece auditável e a porta para uma revisão por pares posterior do
critério continua aberta. Se você o lê **como revisor** de uma revisão futura: **emita o seu próprio
parecer** (concorda / revisa / rejeita) contra as fontes e os dados brutos; o manuscrito é **insumo, não
verdade**.

**Diferença essencial vs passo 0:** o passo 0 mediu um **protótipo descartável** (cliente de pipe mínimo +
daemon de protótipo). O **Passo F mede o FIO REAL**: o cliente NativeAOT `ptu-client.exe` e o daemon pwsh
`ClaudeCodePreToolUseSafeAllowDaemon.ps1` **já buildados e commitados** (Passos A–E), subidos de um deploy
no layout de produção do Passo G. **Settings.json intocado; enforce/fio NÃO ligados; nada de produção
alterado.**

**Fontes:** design CONGELADO `claude-code-pretooluse-daemon-design.md` (§9-0e RE-ENQUADRADO, reproduzido na
§1); plano `claude-code-pretooluse-implementacao-v1-plan.md` (Passo F); base do passo 0
`historico/passo0-daemon-pretooluse-medicao-20260628/relatorio-passo0-v5.md`. Harness/dados deste passo:
`Measure-PassoF.ps1`, `Measure-PassoF-Cold.ps1`, `Measure-PassoF-Breakdown.ps1`, `passoF-series.csv`,
`aot-floor/`. Hashes SHA256 na §10.

---

## 1. Contexto e critério (§9-0e RE-ENQUADRADO do design congelado)

O §9-0e foi re-enquadrado no passo 0 (revisado por pares, congelado): o orçamento absoluto p95 ≤ 80 / p99
≤ 100 ms é fisicamente inatingível enquanto o modelo exigir **um cliente novo por invocação** (o piso de
spawn AOT domina a cauda, ~180 ms p95 no host do passo 0), e foi **substituído** por:

- **(i) GATE de liberação — overhead do daemon sobre o piso de spawn ≤ 5 ms**, para o `defer`-comum **e** o
  `allow`-candidato. **Duas métricas, ambas obrigatórias, teto ≤ 5 ms (a mais estrita vence):**
  (1) **diferença percentil-a-percentil** `e2e_pX − floor_pX` **≤ 5 ms até o p95**;
  (2) **overhead PAREADO** (subtração na mesma iteração) com **p90 ≤ 5 ms** (confiável só até ~p90; o p95
  pareado é jitter de spawn não-correlacionado, **não** é critério).
- **(ii) Guardrail de cauda por-host:** o **`%>80 ms` do e2e não excede o do floor em mais de ~1 pp**.
- **(iii)** o `defer`-comum **não regride** além de **≤ 5 ms** sobre o hook pwsh atual (~520 ms).
- **Alvo/telemetria por host (NÃO gate): p50 ≤ 40 ms, p90 ≤ 60 ms; p95/p99 governados pelo piso de spawn.**

Dois caminhos quentes: `defer`-comum (1º token não read-only) e `allow`-candidato (verbo read-only →
`shlex` via python → `allow`). O floor é um **binário separado** (`return 0;`) — spawn+runtime+teardown de
um processo NativeAOT win-x64, sem IPC.

## 2. Ambiente

Windows 11 Pro 10.0.26200 (máquina de dev). pwsh 7.6.3. Python 3.14.2. .NET SDK 10.0.301 (compila/publica
o TFM `net8.0`; AOT win-x64). MSVC VS2022 BuildTools (vcvars64). Defender RealTime ON. **Uma única
máquina.** Commit `700c95c` (topo do Passo E). `buildContractPin` `03ae5ff78bba4298…` (DLL == EXE,
conferido). Rede de não-regressão §8 (incl. o GATE adversarial `…DaemonSelfTest.ps1`) **verde** antes da
medição (o gate §8 falha sob contenção concorrente — medido isolado).

## 3. Metodologia (reusa o passo 0; aplicada ao FIO REAL)

- Wall-clock por invocação via `Stopwatch` em volta de `Process.Start` → escreve o JSON do hook no stdin →
  `StandardOutput.ReadToEnd()` → `WaitForExit()`. Fiel ao §5 do passo 0 (o Claude Code lê o stdout até o EOF
  coincidente com o exit; o teardown está no caminho crítico).
- **#robusto: 1000 iterações + 50 warmup, INTERCALADO** (floor/defer/allow na mesma iteração → subtração
  pareada sob as mesmas condições instantâneas) + série temporal completa (`passoF-series.csv`).
- Inputs: `defer`=`npm run build`; `allow`=`git status` (cwd em escopo = o próprio deploy). **0 mismatch**
  em 1000 (todo `defer` deu `defer`, todo `allow` deu `allow`).
- Floor = binário SEPARADO `aot-floor` (`Program.cs` literalmente `return 0;`), props AOT espelhando o
  `ptu-client.csproj`.
- **Cliente e daemon REAIS**, de um **deploy temporário** (exe + `PtuCanon.dll` + scripts do daemon +
  marcador `.ptu-safe-allow-root`), idêntico ao layout do Passo G. `PTU_SAFE_ALLOW_ROOTS` = deploy. Daemon
  subido explicitamente e **aquecido** (warmup descartado) antes da medição estacionária.
- **WARMUP:** o daemon recém-subido aquece nas 1ªs reqs (1ª req ~245–262 ms → `defer`; 2ª já `allow` ~60 ms).
  Medido o **estacionário** (warmup contabilizado à parte; orçamento estacionário de 80 ms NÃO inflado).
- High prio no harness/daemon/clientes. Defender ATIVO. **Um cliente por vez** (sequencial; o daemon é
  single-threaded — sem fila artificial).

## 4. Dados (ms wall-clock por invocação)

### 4.1 ROBUST1k — fio real, 1000 iter intercaladas, High, Defender ON
| cenário | min | p50 | p75 | p90 | p95 | p99 | max | mean | %>80ms |
|---|---|---|---|---|---|---|---|---|---|
| `floor` (AOT no-op `return 0;`) | 27,5 | 29,0 | 30,2 | 33,5 | 40,0 | 327,0 | 373,6 | 43,3 | **4,60%** |
| `e2e-defer` | 44,5 | 49,8 | 54,3 | 62,3 | 64,4 | 362,7 | 396,8 | 61,5 | **3,30%** |
| `e2e-allow` | 45,5 | 48,1 | 52,4 | 63,2 | 64,8 | 361,4 | 395,6 | 63,1 | **4,10%** |

### 4.2 Overhead — as DUAS métricas do gate (i)
**Cross-check percentil-a-percentil (`e2e_pX − floor_pX`), ms:**
| | p50 | p75 | p90 | p95 | p99 |
|---|---|---|---|---|---|
| `defer − floor` | 20,8 | 24,1 | 28,8 | **24,4** | 35,7 |
| `allow − floor` | 19,1 | 22,2 | 29,7 | **24,8** | 34,4 |

**Subtração PAREADA (overhead = e2e − floor na MESMA iteração), ms:**
| par | p50 | p75 | p90 | p95 | média | neg% |
|---|---|---|---|---|---|---|
| `defer − floor` | 20,84 | 22,75 | **31,77** | 34,94 | 18,22 | 4,6 |
| `allow − floor` | 19,21 | 21,40 | **33,70** | 35,63 | 19,78 | 4,6 |

→ Pelo cross-check, o overhead é **~19–30 ms em TODO percentil até o p95** (não ~3 ms como no protótipo).
Pelo pareado, **p90 ~32–34 ms** (não ~4 ms). **As duas métricas concordam em ~20–34 ms** — bem acima do
teto de **5 ms**.

### 4.3 Breakdown — localização da causa (n=500, intercalado floor/identity/e2e-allow)
`identity` = `ptu-client.exe --emit-identity` (spawn + `ClientIdentity.Compute`, SEM stdin/pipe).
| cenário | p50 | p75 | p90 | p95 | mean |
|---|---|---|---|---|---|
| `floor` (spawn) | 28,9 | 29,9 | 32,0 | 38,4 | 40,3 |
| `identity` (spawn+id) | 34,5 | 35,9 | 37,9 | 42,9 | 44,1 |
| `e2e-allow` (full) | 51,6 | 59,9 | 62,1 | 64,0 | 60,7 |

**Decomposição perc-a-perc:**
| | identidade (id−floor) | daemon (e2e−id) | total (e2e−floor) |
|---|---|---|---|
| p50 | 5,5 | **17,1** | 22,7 |
| p75 | 5,9 | **24,0** | 29,9 |
| p90 | 5,9 | **24,2** | 30,1 |
| p95 | 4,6 | **21,1** | 25,6 |

→ O overhead **NÃO** é dominado pela identidade do cliente (**~5,5 ms**, ela própria já ~no teto), e sim
pelo **round-trip do pipe + processamento PowerShell do daemon por requisição (~17–24 ms)**: `ConvertFrom-Json`
do payload, matriz de staleness (5 artefatos), barreiras versão/pin, canon do cwd e `Get-PtuDecision`
(Support.ps1 + IPC com o python persistente). `defer` e `allow` têm overhead ~igual (§4.1) → **não** é o
python; é o custo fixo do daemon em PS por requisição.

### 4.4 Canon do `cwd` isolado ([Ptu.CwdWorker]::Canonicalize, in-process, n=1000)
p50 0,3 · p90 0,4 · p95 0,4 · max 2,0 ms. **Desprezível** (não é a causa do overhead).

### 4.5 Baseline (iii) — hook pwsh string-puro ORIGINAL (decisor via `pwsh -File` por chamada, n=60)
`defer`-comum: p50 453,2 · p90 467,8 · p95 473,2 · mean 466,5 ms. (Confirma o ~520 ms da §4.1 do passo 0.)

### 4.6 Frio sob contenção (F3)
- **coldReadyMs** (spawn → pipe conectável): 725 ms (rodada principal); 825 / 697 / 700 ms (3 amostras,
  média 741, máx 825).
- **Burst K=20** (daemon parado no arranque; o cold-path REAL do cliente disputa o guard mutex e sobe o
  daemon DETACHED):

| modo | daemons observados | loserSpawns | pico RSS | vida agregada | pipe up |
|---|---|---|---|---|---|
| simultâneo | 2 | **1** | 99,8 MB | 4394 ms | sim |
| escalonado (50 ms) | 4 | **3** | 121,4 MB | 5487 ms | sim |

→ Simultâneo: **1 sobrevivente** + **1 loserSpawn** (≈0 esperado; 1 é limítrofe — o burst paralelo não é
perfeitamente instantâneo, um 2º cliente reacquire o guard liberado antes do pipe ficar pronto; o loser
perde o singleton e sai). Escalonado: **3 loserSpawns**, **dentro** do teto `ceil(coldMax/guardWindow)+2 =
ceil(825/50)+2 = 19`. RSS e vida agregada modestos.

### 4.7 Concorrência (ADENDO P0, pedido pela revisão por pares) — `Measure-PassoF-Concurrency.ps1`
Daemon QUENTE single-threaded; rajada de N clientes quase-simultâneos; **medição QUALITATIVA** (a
distribuição de decisão é robusta à carga; a latência absoluta é confundida por carga de máquina, ver §9 —
só indicativa). Prioridade NORMAL.

| N (rajada) | allow% | defer% | **other** | p50 (indic.) | p95 (indic.) |
|---|---|---|---|---|---|
| 1 | ~100 | ~0 | **0** | ~50 | — |
| 5 | 90,0 | 10,0 | **0** | 458 | 1043 |
| 10 | 76,7 | 23,3 | **0** | 288 | 1707 |
| 20 | 75,0 | 25,0 | **0** | 671 | 5416 |

- **Fail-closed se mantém sob TODA rajada (`other=0`):** nenhum cliente jamais emite saída ≠ allow/defer; o
  que não é atendido **defere** (cai no prompt). Propriedade de correção, **independente de carga**.
- **Degradação graciosa para defer:** defer sobe (~10→25%) e allow cai (90→75%) com a concorrência — o
  benefício degrada **com segurança**.
- **Latência infla sob rajada** (p95 ~1 s @N=5 → ~5 s @N=20) — confundida por carga; confirma que os ~50 ms
  são regime sequencial/quente. **A latência sob carga em uso real fica para a Fase 3 (observe) do Passo G.**
- **Achado:** sob rajada alta e sustentada (N≈20), o cold-path dispara tempestade de spawns de
  daemon-perdedor (janela de recriação do pipe → "pipe ausente" → tentativa de subir outro daemon → perde o
  singleton e sai). Fail-closed, mas pressiona recursos; parcialmente artefato de rajada sintética, raiz real
  — candidato a backpressure/otimização, a vigiar na Fase 3.

## 5. Validação da métrica

Idêntica ao passo 0 §5 (fonte: docs do Claude Code; o stdout é lido até o EOF coincidente com o exit). A
medição até `WaitForExit` é fiel ao que o usuário sente. O harness deste passo invoca o cliente REAL
exatamente como o Claude Code o invocaria (JSON no stdin, lê stdout até EOF).

## 6. Afirmações (a confirmar ou refutar)

- **B1.** O fio REAL tem **mediana ~48–50 ms** (e2e), ~**9–10×** melhor que o hook pwsh original (~466 ms).
  A experiência do usuário melhora muito (iii satisfeito com folga).
- **B2 (CENTRAL).** O **overhead sobre o piso de spawn é ~20–34 ms** (cross-check ~19–30 ms até p95;
  pareado p90 ~32–34 ms), **~4–7× acima do teto de 5 ms** do GATE (i). **O GATE (i) REPROVA**, robustamente
  (n=1000, 0 mismatch), tanto para `defer` quanto para `allow`.
- **B3.** A causa decompõe-se em **~5,5 ms de identidade do cliente** + **~17–24 ms de processamento
  PowerShell do daemon por requisição** (§4.3). O **protótipo do passo 0 subestimou ambos** (mediu ~1 ms):
  seu cliente não computava identidade e seu daemon fazia menos trabalho por requisição (sem a matriz de
  staleness completa, sem dupla desserialização JSON, decisão mais enxuta).
- **B4.** Guardrail (ii) **SATISFEITO**: `%>80 ms` e2e (3,3–4,1%) **abaixo** do floor (4,6%) — o daemon
  **não acrescenta** cauda; ela é o jitter de spawn (igual ao passo 0). (iii) **SATISFEITO**.
- **B5.** Alvos de telemetria (NÃO gate): p50 ≤ 40 → e2e ~48–50 (ligeiramente **acima**); p90 ≤ 60 → ~62–63
  (ligeiramente acima). p95/p99 governados pelo piso (cauda ~360 ms p99, igual floor).

## 7. Veredito §9-0e

| condição | teto | medido | resultado |
|---|---|---|---|
| **(i) overhead — cross-check perc-a-perc até p95** | ≤ 5 ms | ~19–30 ms | **REPROVA** |
| **(i) overhead — pareado p90** | ≤ 5 ms | ~32–34 ms | **REPROVA** |
| (ii) guardrail `%>80 ms` (e2e − floor) | ≤ ~1 pp | −0,5 a −1,3 pp | satisfaz |
| (iii) `defer`-comum vs hook ~466 ms | ≤ +5 ms (sem regredir) | ~−416 ms (melhora) | satisfaz |
| (alvo) p50 ≤ 40 ms | telemetria | ~48–50 | acima (não gate) |
| (alvo) p90 ≤ 60 ms | telemetria | ~62–63 | acima (não gate) |

**O GATE (i) — a única condição de liberação controlável pela implementação — REPROVA por ~4–7×.** As
demais condições passam, mas o §9-0e exige as condições **conjuntas**; (i) é a que governa a liberação.

## 8. Decisão datada do autor (§9-0f) — 2026-06-30

**Decisão: o fio é APROVADO no mérito; o Passo G (gravar o fio via `xpz-skills-setup`) fica DESBLOQUEADO**
(frente própria, NÃO executada aqui — o `settings.json` permanece intocado no Passo F).

**Fundamento — o GATE (i) compara contra a grandeza errada.** A medição é fato e não muda: contra o piso de
spawn + 5 ms, o GATE (i) do §9-0e **reprova** (overhead real ~20–34 ms; §4.2/§7). Mas o autor julga que o
**próprio critério (i) normaliza contra o baseline errado.** O fio não substitui "um spawn AOT + 5 ms"; ele
elimina, para comandos read-only já reconhecidos como seguros:

- o **clique humano de autorização** — ler o comando, entender, decidir, clicar: da ordem de **1.500–10.000
  ms**; e
- o **hook pwsh atual** (~466 ms, §4.5).

Contra esses dois baselines operativos, o daemon a **~50 ms (e2e), 0 mismatch em 1000, fail-closed (nunca
`allow` isolado)** é decisivamente superior: **~9×** sobre o hook atual e **~30–200×** sobre o clique humano.
O overhead de ~20–34 ms sobre o piso de spawn é real, porém **irrelevante na escala do que está sendo
eliminado** — otimizá-lo (o termo dominante é o processamento PowerShell do daemon por requisição, ~17–24 ms,
§4.3; identidade do cliente ~5,5 ms; canon ~0,4 ms) continua sendo um **aprimoramento desejável, NÃO uma
condição de liberação**. Guardrail (ii) e não-regressão (iii) já passam; a segurança (fail-closed, §8 verde)
não é tocada por esta decisão.

**Sobre o processo.** O §9-0f prevê revisão por pares vinculante da decisão. O autor **dispensou o painel
para esta decisão**, por ser de mérito evidente (50 ms << clique humano em algo já autorizado) e por o ponto
ser a **má-formulação do critério (i)** — não a leitura de um número de borda nem "re-enquadrar o critério
porque ele reprovou". Registrado para auditoria; a porta para uma revisão por pares posterior do critério
permanece aberta.

**Eventual desdobramento (NÃO condição de liberação):** reduzir o custo fixo do daemon em PS por requisição
(evitar dupla desserialização JSON, enxugar a matriz de staleness no caminho quente, ou mover o laço quente
para fora do PowerShell) é uma frente própria, com seu próprio design + revisão por pares se for aberta.

**ADENDO PÓS-PAINEL (2026-06-30):** a decisão acima foi **submetida a revisão por pares vinculante** (5 vozes/3
famílias; registro em `revisao-por-pares-passoF-v1.md`). Veredito unânime **"revisa com gaps"**: a tese
**procede no mérito**, mas (1) a *forma* "(i) gate→alvo porque reprovou" foi corrigida — o (i) é re-rotulado
como **alvo de eficiência que sempre foi** (não um gate de segurança/correção), com **meta ≤ 10 ms até o
Passo H** e **salvaguarda** contra uma 3ª reclassificação sem painel; (2) a **condição de liberação** passa a
ser (ii)+(iii)+**concorrência fail-closed**; (3) **concorrência é P0** — caracterizada na §4.7 (fail-closed
`other=0`; degradação para defer; latência sob carga para a Fase 3). A reconciliação final está na
`NOTA PÓS-PASSO-F + PAINEL` do §9-0e do design. **Enforce (Passo G) condicionado** à Fase 3 (observe) fechar a
latência sob carga em uso real.

## 9. Ameaças à validade (reconhecidas)

- **Uma única máquina.** O overhead (i), pretensamente host-independente, foi medido só aqui. O harness é
  portátil (rodar `Measure-PassoF.ps1` noutro host Windows 11 + pwsh 7.6+). Mas o **veredito não depende da
  portabilidade**: ~20–34 ms >> 5 ms com margem larga; nenhum host plausível o reduziria a ≤ 5 ms, dado que
  o termo dominante é processamento PS por requisição (não jitter de host).
- **Floor = `return 0;`** (por spec §9-0e). O cliente real **precisa** computar identidade (pipe por
  identidade, segurança), o que o floor não faz; o §4.3 isola esse termo (~5,5 ms) para transparência.
- **Sequencial (um cliente por vez).** O daemon é single-threaded; sob concorrência real a latência poderia
  subir (fila), nunca cair. Conservador para o veredito.
- **§8 (gate adversarial) verde só isolado** — falha sob contenção concorrente; a medição foi feita isolada.
- **Cache de processo/disco entre iterações** pode tornar o p50 otimista para uso esparso; reforça o
  veredito (o overhead real esparso só tende a ser ≥).

## 10. Auditabilidade — hashes SHA256 dos artefatos (16 primeiros hex)

- `Measure-PassoF.ps1` — `92ea2f65019ffb15` (17402 b) — ms do CSV agora em ponto decimal invariante
- `Measure-PassoF-Cold.ps1` — `388bfadbfd271ff7` (10561 b)
- `Measure-PassoF-Breakdown.ps1` — `91038f405c3834c9` (7981 b)
- `Measure-PassoF-Concurrency.ps1` — `80fbc6833f8221f1` (9692 b) — adendo P0 de concorrência (§4.7)
- `passoF-series.csv` — `ade4e090b1652354` (64474 b) — série temporal completa, 1000×3; reparsada para
  ponto decimal (Import-Csv lê as 4 colunas; percentis idênticos aos do §4.1, validados no reparse)
- `revisao-por-pares-passoF-v1.md` — `fda27c12ebf2d4a8` (11368 b) — manuscrito + 5 pareceres + recibo
- `aot-floor/Program.cs` — `8eb8da778efaf708` (279 b) — literalmente `return 0;`
- `aot-floor/floor.csproj` — `be956b5d467fbad2` (749 b)
- `aot-floor/publish.bat` — `e503785a1418d655` (492 b)

## 11. Pergunta para uma eventual revisão posterior

A decisão da §8 (aprovar no mérito) repousa numa tese verificável: **o GATE (i) normaliza contra a grandeza
errada** — o baseline operativo é o clique humano (~1.500–10.000 ms) e o hook atual (~466 ms), não o piso de
spawn + 5 ms. Essa tese se sustenta? Os dados (~50 ms e2e, 0 mismatch, fail-closed; overhead ~20–34 ms sobre
o piso) estão corretos e a decomposição da causa (§4.3) é sólida? Há algum risco de segurança/correção que a
escala de latência esteja escondendo? Gaps remanescentes priorizados, se houver.
