# Passo 0 (medição) — daemon do hook PreToolUse do Claude Code — registro histórico

Data: 2026-06-28. Autor: Antonio José (antonio@frigobyte.com).

Registro durável do **passo 0 (medição)** da frente do daemon do hook `PreToolUse` (auto-allow) do
Claude Code. O design congelado (fonte da verdade) é `../../claude-code-pretooluse-daemon-design.md`
(§9 = passo 0; §9-0e = critério; §9-0f = gate de saída). Este passo 0 foi um **protótipo descartável
de medição**: sem fio no hook real, `settings.json` intocado. Os scripts aqui são **protótipos de
medição descartáveis** preservados só para **auditoria e reprodução** — **não** são o código da v1.

## Entregável principal

- [`relatorio-passo0-v5.md`](relatorio-passo0-v5.md) — relatório empírico (versão v5, convergida).

## Resultado em uma linha

O daemon resolve o gargalo: a mediana cai de **~520 ms → ~28 ms** por comando (~10×), com **overhead
do daemon ~1 ms**. A cauda **p95 ~180 ms** é o **piso do cliente/processo AOT neste host e neste modelo
"hook-nasce-cliente"** (provado pelo floor `return 0;`) — agrega criação de processo, runtime, antivírus,
prioridade, agendamento e teardown, **fora do controle da implementação enquanto o modelo exigir um cliente
novo por invocação** — por isso o
orçamento absoluto **p95 ≤ 80 ms do §9-0e é inatingível** e o relatório propõe **re-enquadrá-lo**
(overhead ≤ 5 ms + p50 ≤ 40 + p90 ≤ 60; p95/p99 como telemetria por host). Primário **NativeAOT+pipe**
(p50 ~28 ms) ≫ fallback **TCP+Python** (p50 ~65 ms).

## Decisão datada do §9-0f

**Adotar (b) NativeAOT+pipe + python persistente**, decidida por Antonio José em **2026-06-28**.
O **re-enquadramento do §9-0e é mudança de design congelado** e passou por **rodada própria de revisão**
antes de re-congelar (concluída em 2026-06-28; ver `../../claude-code-pretooluse-daemon-design.md` §11). O
aval unânime das 3 famílias do painel do passo 0 valida o **passo 0** (a medição) e **alimenta** a decisão
(b); a **revisão de par vinculante do §9-0f sob o critério re-enquadrado** é essa rodada própria do
re-enquadramento, não o aval do passo 0 (régua *stale a cada versão*, `../../15-revisao-por-pares.md`).
Próximo: construção da v1 (§5/6/7/8) → fio (Fase 5).

## Recibo da revisão por pares (5 rodadas, 3 famílias — convergiu)

Metodologia: `../../15-revisao-por-pares.md` + `../../xpz-llm-delegate/SKILL.md`. Famílias:
`anthropic` (Claude Opus, subagente nativo), `openai` (Codex gpt-5.5), `nvidia` (glm-5.1, kimi-k2.6,
minimax-m2.7 via opencode). Preferidos `ollama-cloud` indisponíveis (cota semanal).

| versão | veredito do painel |
|---|---|
| v1 | todas as famílias *revisa* — gaps de design |
| v2 | arquitetura **convergiu**; gaps de transparência |
| v3 | 3 famílias **"pode congelar"**; anthropic auditou o CSV byte-a-byte; 1 erro factual (~21%→~16%) |
| v4 | openai/Codex aponta 2 imprecisões numéricas do orçamento |
| **v5** | openai/Codex **"concorda / converge / pode congelar"**; sem gap bloqueante |

Convergência declarada pelo autor em 2026-06-28 (delta v4→v5 = só a precisão numérica que o Codex pediu).

## Hashes SHA256 dos dados/scripts (16 primeiros hex, no momento da medição)

- `Measure-Robust1k.ps1` — `A25E537FB43BB1E2`
- `robust1k-series.csv` — `77AABA5EAE7FC769` (1000×3 amostras; série temporal completa)
- `Measure-0dColdBurst.ps1` — `16B77FBBD8E16CC3`
- `daemon-pipe-persistpy.ps1` — `21093732B48689EC`
- `shlex-persistent.py` — `56353EAC70CFF602`
- `aot-floor/Program.cs` — `98990752209C33BD` (literalmente `return 0;`)

## Inventário dos artefatos (protótipos descartáveis de medição)

- **Dados:** `robust1k-series.csv` (a fonte das tabelas do §4.2 do relatório).
- **Harness principal:** `Measure-Robust1k.ps1` (1000 iter intercaladas: floor/defer/allow + subtração pareada + série temporal).
- **0d (frio sob contenção):** `Measure-0dColdBurst.ps1` (mutex + lazy-spawn + ready; K clientes simultâneos).
- **Outros harnesses:** `Measure-ClientFloor.ps1`, `Measure-PipeE2E.ps1`, `Measure-PipePersistPy.ps1`, `Measure-TcpE2E.ps1`, `AB-Defender.ps1` (A/B do Defender com exclusão temporária + revert).
- **Daemons (pwsh persistente):** `daemon-pipe.ps1` (python por-requisição), `daemon-pipe-persistpy.ps1` (python persistente — o primário), `daemon-tcp-persistpy.ps1` (fallback TCP+token).
- **Clientes/helpers:** `aot/` (cliente named pipe, NativeAOT — `Program.cs`+`client.csproj`+`publish.bat`), `aot-floor/` (floor `return 0;`), `shlex-persistent.py` (tokenizador em loop), `tcp-client.py` (cliente TCP), `py-floor.py` (floor Python).

## Como reproduzir

1. Pré-requisitos: Windows x64, pwsh 7.6+, Python 3.x, .NET SDK 8+, MSVC (BuildTools 14.4x) + Windows SDK.
2. Publicar os exes NativeAOT: rodar `aot/publish.bat` e `aot-floor/publish.bat` (dentro do `vcvars64` do **BuildTools** + dir do VS Installer no PATH — ver comentários nos `.bat`).
3. Ajustar os caminhos absolutos no topo dos `Measure-*.ps1` (apontam para o scratchpad original).
4. Rodar `Measure-Robust1k.ps1` (gera novo CSV) e comparar o **p95 do floor** com ~180 ms (protocolo portátil do §8 do relatório). `Measure-0dColdBurst.ps1 -K 10`/`-K 20` reproduz o 0d.

## Pendências formais (v1, fora do passo 0)

Endurecimento (§5/6/7: identidade SID+repo+roots, ACL, token, staleness, protocolo, log) e **self-tests
adversariais (§8)** — **obrigatórios antes de qualquer liberação**. `0c` (equivalência de tokenização)
dispensada pela escolha de (b). DLP corporativo do TCP não testado. Generalização de A4/A5 condicional ao
protocolo portátil noutro host.
