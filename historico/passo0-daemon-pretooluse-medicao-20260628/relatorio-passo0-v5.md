# Manuscrito v5 — revisão por pares — relatório empírico do passo 0 (medição) do daemon do hook PreToolUse do Claude Code

## Seu papel (LEIA PRIMEIRO)

Você é **um revisor independente**. Leia este manuscrito e as fontes que cita e **emita o SEU PRÓPRIO
parecer**: **concorda** / **revisa (com gaps)** / **rejeita**, com justificativa e gaps priorizados.
**NÃO** execute nada, **NÃO** conduza você mesmo uma revisão por pares, **NÃO** delegue. O manuscrito é
**insumo, não verdade** — confirme ou refute contra as fontes.

**Esta é a v5.** Trajetória: v1 (gaps de design) → v2 (fechados; arquitetura convergiu) → v3 (transparência;
3 famílias "pode congelar") → v4 (2 correções factuais do CSV) → **v5** fecha as **2 imprecisões numéricas do
orçamento** que a única família que ainda não tinha visto a versão final (openai/Codex) apontou: (1) o **p90 do
overhead pareado** agora está numérico (4 ms) + um **cross-check percentil-a-percentil** (≤3 ms até p95); (2) o
**`%>80ms`** virou critério definido (e2e não excede o floor em >~1 pp). Changelog §9. **Se você concluir que a
v5 não tem mais gap real, diga explicitamente "converge / pode congelar".**

**Auditabilidade (correção v2→v3):** os artefatos brutos estão acessíveis para auditoria. Se você é um
revisor com acesso ao filesystem **na pasta do experimento** (`-Cd` apontado ao scratchpad), pode abrir e
re-rodar `Measure-Robust1k.ps1` e inspecionar `robust1k-series.csv`. Hashes SHA256 (16 primeiros hex) para
verificação de integridade na §11.

**Fontes:** design CONGELADO `claude-code-pretooluse-daemon-design.md` (§9, §9-0e, §4.1/4.2/4.4, §1) — o
critério §9-0e está reproduzido na §1 abaixo, então você pode revisar sem abri-lo. Protótipos/dados:
`Measure-Robust1k.ps1`, `robust1k-series.csv`, `Measure-0dColdBurst.ps1`, `daemon-pipe-persistpy.ps1`,
`aot-floor\Program.cs`.

**Avalie:** (1) o orçamento re-enquadrado (§7/§4.2) está agora **numericamente fechado** (overhead pareado p90
= 4 ms; percentil-a-percentil ≤3 ms até p95; %>80 = +0,3-0,5 pp sobre o floor)? (2) o confronto (a)/(b)/(c) é
justo com (a)? (3) A4/A5 com a redação causal estreitada está sólido? (4) gaps remanescentes, se houver.

---

## 1. Contexto e critério (§9-0e do design congelado)

Passo 0 = **protótipo descartável de medição** (sem fio no hook real; `settings.json` intocado; nada
commitado). Critério de liberação (§9-0e), **três condições conjuntas**: (i) `allow`-candidato p95 ≤ 80 /
p99 ≤ 100 ms; (ii) `defer`-comum idem; (iii) `defer`-comum não regride > 5 ms vs hook pwsh atual. Dois
caminhos quentes: `defer`-comum (fast-path, sem python) e `allow`-candidato (`shlex` via python → `allow`).

## 2. Ambiente

Windows 11 Pro 10.0.26200 (máquina de dev). pwsh 7.6.3. Python 3.14.2. .NET SDK 8/9/10. MSVC VS2022
BuildTools 14.44; Windows SDK 10.0.26100. Defender RealTime+Tamper ON. **Uma única máquina** (ameaça §8;
protocolo de reprodução portátil em §8).

## 3. Metodologia

- Wall-clock por invocação via `Stopwatch` em volta de `Process.Start` → escreve JSON no stdin →
  `StandardOutput.ReadToEnd()` → `WaitForExit()`. **Métrica validada como fiel** (§5).
- Percentis nearest-rank (ceiling). **#4 robusto: 1000 iter + 50 warmup, intercalado** (floor/defer/allow na
  mesma iteração → subtração pareada sob as mesmas condições instantâneas) + série temporal completa (CSV).
- Inputs: `defer`=`npm run build`; `allow`=`git status` (cwd em escopo).
- Floor = **binário SEPARADO** `aot-floor` (`Program.cs` literalmente `return 0;`) — spawn+exit puro, sem IPC.

## 4. Dados (ms wall-clock por invocação)

### 4.1 Baseline (hook pwsh atual) — o problema
`pwsh` isolado: p50 ~298 / p95 ~382. Hook pwsh completo: `defer` p50 494 / p95 584; `allow` p50 583 / p95 693.

### 4.2 #4 — primário pipe+AOT + python persistente, **1000 iter intercaladas, High prio**
| cenário | p50 | p75 | p90 | p95 | p99 | %>80ms |
|---|---|---|---|---|---|---|
| `floor` (no-op AOT, `return 0;`) | 27,1 | 28,2 | 31,4 | 180,1 | 212,0 | 6,4% |
| `e2e-defer` (pipe) | 28,0 | 29,1 | 32,3 | 182,7 | 200,3 | 6,9% |
| `e2e-allow` (pipe) | 28,3 | 29,5 | 32,3 | 183,3 | 197,7 | 6,7% |

**Overhead do daemon (subtração pareada, e2e − floor na mesma iteração) — transparência da cauda
(correção v2→v3):**
- **Overhead pareado por percentil (defer / allow, conferido no CSV):** p50 **1 / 1 ms** · p75 **2 / 2 ms** ·
  **p90 4 / 4 ms** (≤ 5 ms) · p95 **154 / 156 ms** (a cauda, ver abaixo). Média ~1,0 ms (0,96 / 1,06).
- **Cross-check percentil-a-percentil (e2e_pX − floor_pX), métrica robusta (correção v3→v5):** p50 **1 ms** ·
  p75 **1 ms** · p90 **1 ms** · p95 **2 / 3 ms** · p99 **−12 / −15 ms** (e2e abaixo do floor — ruído). Ou seja,
  **em nenhum percentil até o p95 o daemon adiciona mais que ~3 ms** sobre o piso de spawn.
- **Na cauda o pareamento por-iteração se desfaz** (p95 pareado ~154 ms): floor e e2e ficam lentos em iterações
  **DIFERENTES** (jitter de spawn **não-correlacionado**) — **~21% negativos no conjunto inteiro** (`defer`
  21,8% / `allow` 21,2%; no **subconjunto modo-rápido** são ~16%, `defer` 16,1% / `allow` 15,6% — recompute
  autoritativo do CSV, n=1000, na rodada de re-enquadramento do §9-0e), min −480 / max +626. Não é overhead do
  daemon: das 64 iterações de floor lento, só **9 (`defer`) / 6 (`allow`)** têm o e2e lento junto. **Reforça A4**
  (jitter independente por processo). Por isso o cross-check percentil-a-percentil acima é a métrica honesta do
  overhead, não o p95 do pareado.
- **Telemetria obrigatória por host:** p95/p99 e %>80 ms (floor 6,4% · e2e 6,7-6,9% = **+0,3-0,5 pp**) reportados.

**Série temporal (histograma, n=1000 por cenário):** bimodal com **vão limpo** (balde 50–100 ms ≈ vazio):
modo rápido <50 ms (~93%) + modo lento >100 ms (~6,5%). Fração lenta **idêntica** nos 3 (6,4/6,9/6,7%) → a
cauda é do **floor (spawn)**. Lentas **predominantemente isoladas** (maior bloco consecutivo = 3).

### 4.3 #6 — fallback TCP+Python, **quieto, 500 iter**
`tcp-defer` p50 65,3 / p90 200,5 / p95 225,1 · `tcp-allow` p50 66,4 / p90 217,5 / p95 229,3. Mesmo quieto:
p50 ~2,3× e **p90 ~6×** o pipe. Loopback sem prompt de firewall (pessoal; **DLP corporativo não testado**).

### 4.4 #5 — 0d (frio sob contenção): K clientes simultâneos, daemon parado
K=10 → 1 daemon, 9 defers; K=20 → 1 daemon, 19 defers; pós-`ready` cliente solto conecta `ok`. Coordenação
§5 (mutex+lazy-spawn+ready) ok: **um único daemon**; só o vencedor sobe; demais simultâneos **deferem**
(fail-closed). Pior caso = **~K−1 prompts uma vez** num burst simultâneo; comum (tools sequenciais) = **~1**.

## 5. Validação da métrica (a métrica até `WaitForExit` é fiel?)

Fonte: docs oficiais do Claude Code — **`https://code.claude.com/docs/en/hooks.md`** (consultada via agente
claude-code-guide, 2026-06-28). O Claude Code **lê o stdout até EOF (coincide com o exit) e coleta o exit
code** (contrato 0/2/outro; timeout default 600 s). Logo o **teardown do processo do hook está no caminho
crítico**; medir até `WaitForExit` é fiel ao que o usuário sente. **Nota de risco (correção v2→v3):** se uma
versão futura do Claude Code adotasse *early-return* (seguir ao 1º JSON válido sem esperar o exit) ou buffer
de stdout que quebrasse a sincronia exit↔percepção, a cauda **percebida** seria **menor** que a medida — o
que **não muda a conclusão** (o piso de spawn ainda domina e o daemon seria ainda mais favorável). A premissa
é **citada como premissa auditável**, não como prova formal.

## 6. Afirmações (a confirmar ou refutar)

- **A1.** Gargalo = startup do `pwsh` por chamada (~520 ms); o daemon leva a mediana a **~28 ms** (~10–18×).
- **A2.** Python persistente (§4.1(b)) zera o 2º python: `allow` 79,8 → 29,1 ≈ `defer`. (b) basta; **0c
  (equivalência de (a)) fica formalmente dispensado pela escolha de (b)**; **os self-tests adversariais do §8
  continuam OBRIGATÓRIOS** antes de qualquer liberação.
- **A3.** Primário pipe+AOT (p50 ~28, p90 ~32) **>>** fallback TCP+Python (p50 ~65, p90 ~200), inclusive quieto.
- **A4 (redação causal estreitada — correção v2→v3).** A cauda p95 ~180 ms é o **piso do cliente/processo
  AOT medido NESTE HOST e neste modelo "hook-nasce-cliente"** — que inclui criação de processo, runtime
  NativeAOT, antivírus, prioridade, scheduling e teardown observado pelo harness. **Não** afirmamos "criação
  de processo do SO" isolada nem "no Windows" universal. Evidência: floor `return 0;` p95 180,1, idêntico ao
  e2e (n=1000), bimodal de vão limpo, lentas isoladas e não-correlacionadas entre processos.
- **A5.** Overhead do daemon sobre o floor = **~1 ms (modo rápido)** (§4.2). Mesmo no p95 o daemon é **3–4×**
  melhor que o hook atual (~180 vs ~584/693). O orçamento absoluto **p95 ≤ 80 ms é inatingível** neste
  modelo/host: o piso (~180 ms p95) domina e nenhuma implementação o reduz.

## 7. Veredito 0e e proposta de decisão

**Leitura estrita do 0e:** REPROVA (i)/(ii) no p95 (~180), exclusivamente pelo piso de spawn; (iii) melhora
muito (p50 494→28). A reprovação **não é do daemon**.

**Proposta de orçamento re-enquadrado (calibrada — correção v2→v3):**
- **overhead do daemon sobre o floor ≤ 5 ms**, medido pela **diferença percentil-a-percentil `e2e_pX − floor_pX`
  até o p95** (métrica robusta — correção v3→v5; medido: **≤1 ms até p90, ≤3 ms no p95, negativo no p99**) **e**
  pelo **p90 do pareado** (medido: **4 ms**, ≤5 ms). **Não** se usa o p95 do pareado (~154 ms) como critério: ele
  é jitter de spawn não-correlacionado, não overhead (§4.2);
- **p50 ≤ 40 ms** (medido ~28);
- **p90 ≤ 60 ms** (medido ~32). **Justificativa do 60:** ~2× a mediana (~28 ms), folga consistente com a
  **baixíssima variância do modo rápido** (p50→p90 vai de 28 a 32 ms) e ainda **abaixo** do ~80 ms que o piso
  de spawn já estoura no p95;
- **`%>80 ms` como TELEMETRIA por host** (não "limitado" como gate aberto — correção v3→v5): o critério é
  **`%>80ms` do e2e não exceder o do floor em mais de ~1 pp** (medido: floor 6,4% vs e2e 6,7-6,9% = **+0,3-0,5 pp**),
  pois o excedente sobre o floor é o que o daemon **acrescenta**; o valor absoluto é governado pelo piso de spawn.
  **p95/p99 mantidos como telemetria obrigatória por host** (não gate de aprovação, pois governados pelo piso);
- declarar que **p95/p99 são governados pelo piso do cliente/processo neste host (~180 ms)**, fora do controle
  de qualquer implementação do modelo; o **p95 ≤ 80 / p99 ≤ 100 absoluto do §9-0e é inatingível e deve ser
  substituído** pelos critérios acima;
- **(iii) preservado** com base **inalterada** (hook pwsh atual, ~520 ms), trivialmente satisfeito.

**Ressalva de processo (consenso unânime do painel v1 e v2):** re-enquadrar o §9-0e é **mudança de design
congelado**, **NÃO pré-aprovada** — exige **rodada própria de revisão** antes de re-congelar. O passo 0
**não tem autoridade** para alterar o §9-0e; apresenta o **caso** para o re-enquadramento. Se o painel dessa
rodada **rejeitar**, a saída honesta é **reprovar o passo 0 / dissolver**.

**Confronto honesto (a)/(b)/(c) do §9-0f:**
- **(a) dissolver / voltar ao in-process pwsh enxuto** — **na prática: não fazer nada, e o usuário segue com
  os ~520 ms de latência por comando.** **Não é espantalho:** é a saída **correta** se o critério absoluto
  (p95 ≤ 80) for mantido, pois **nenhuma** poda de pwsh o atinge (0a: pwsh isolado já dá p95 ~382). A favor:
  zero código/superfície. (a) **vence automaticamente** se o re-enquadramento for rejeitado.
- **(b) NativeAOT+pipe + python persistente** — **recomendada pelos dados:** mediana ~28 ms (~10×), overhead
  ~1 ms, build viável neste host. Custo: binário AOT + exclusão/assinatura do Defender (p90; o p95 é do
  piso) + superfície de v1 (§5/6/7/8).
- **(c) TCP+Python** — **só fallback** quando (b) inviável no host alvo: p50 ~65 ms, cauda pior, **risco de
  DLP corporativo não testado**.

## 8. Ameaças à validade (reconhecidas)

- **Uma única máquina.** **Protocolo de reprodução portátil (correção v2→v3):** rodar
  `Measure-Robust1k.ps1` (mesmos parâmetros: 1000 iter, 50 warmup, intercalado) em **outro host Windows 11 +
  pwsh 7.6+**, comparando o p95 do floor `return 0;`. Se o piso ~180 ms se confirmar, A4/A5 generalizam além
  desta máquina; se diferir muito, o número é idiossincrásico e o orçamento (§7) deve ser por-host.
- **0d:** pior caso ~K−1 prompts uma vez; mitigação (pré-aquecer o daemon no login) é **v1**, não passo 0.
- **DLP corporativo do TCP** não testado (loopback pessoal).
- **§8 (self-tests) e endurecimento (§5/6/7) NÃO prototipados** — **v1**, pendências formais **obrigatórias**.
- **0c** dispensada por (b); reabre se (a) voltar.
- **Cache de processo entre iterações** pode tornar o p50 otimista para uso esparso; reforça A4.

## 9. Changelog (guarda contra regressão auto-infligida)

**v4 → v5 (2 imprecisões numéricas do orçamento apontadas pela voz openai/Codex na v4 — única família que ainda não vira a versão final):**
- **§4.2/§7 overhead por p90 agora numérico:** o critério "mediana E p90 do pareado" faltava o p90; agora reportado — **p90 pareado = 4 ms** (≤5 ms) + **cross-check percentil-a-percentil `e2e_pX−floor_pX` ≤3 ms até p95** (métrica mais robusta que o pareado, que tem cauda não-correlacionada). Nenhuma conclusão muda.
- **§7 `%>80ms` definido:** era "reportado e limitado" sem teto; agora é critério explícito — **e2e não excede o floor em >~1 pp** (medido +0,3-0,5 pp); p95/p99 seguem telemetria, não gate.
- Nenhuma decisão de arquitetura/A4/A5/confronto revertida — só precisão numérica do orçamento.

**v3 → v4 (2 correções factuais de uma linha, da auditoria do CSV pela voz Claude no painel v3 — que convergiu):**
- **§4.2 "% negativos" corrigido:** era "~21%", o CSV real dá **~16%** (`defer` 16,1% / `allow` 15,6%) — reconferido pelo autor. Nenhuma conclusão muda (segue jitter não-correlacionado). **[CORREÇÃO 2026-06-28 (rodada de re-enquadramento do §9-0e): esta "correção" v3→v4 estava EQUIVOCADA — o ~16% é o subconjunto modo-rápido; o conjunto inteiro é **~21% (`defer` 21,8% / `allow` 21,2%)**, reconferido por recompute autoritativo do CSV (n=1000), confirmado por 3 famílias do painel (openai/anthropic/nvidia). O §4.2 acima foi corrigido; a interseção também passou de "11" para "9/6". A direção certa é ~21% no conjunto, com ~16% rotulado como subconjunto.]**
- **§4.2 rótulo da mediana pareada corrigido:** "0,96 / 1,26" era a **média** mal-rotulada; a **mediana** (nearest-rank, do CSV) é **1,0 / 1,0** e a média é 0,96 / 1,06. Rótulo↔número alinhados.
- Nenhum outro item: o painel v3 convergiu ("pode congelar") nestes 2 pontos como únicos resíduos.

**v2 → v3:**
- **Auditabilidade (Codex#1/kimi P2/Claude G-v2-2):** hashes SHA256 (§11) + reviewers com `-Cd` no scratchpad
  auditam os brutos; depósito em `historico/` previsto no 0f (sujeito à aprovação humana).
- **Transparência da cauda pareada (Claude G-v2-1/Codex#3):** §4.2 declara que ~1 ms é do modo rápido; a cauda
  é jitter não-correlacionado (~16% negativos), não overhead. Overhead por mediana+p90; %>80 e p95/p99 como
  telemetria.
- **Redação causal de A4 (Codex#4):** "piso do cliente/processo AOT neste host" (não "criação de processo do SO").
- **Fonte do §5 (kimi P1/Claude G-v2-2):** URL citada + nota de risco (early-return → cauda menor, não muda conclusão).
- **Justificar 60 + protocolo portátil (kimi):** §7 (60 = ~2× mediana) e §8 (rodar o harness noutro host).
- **Nenhuma decisão fechada da v1/v2 revertida** — só refinada. A arquitetura (b) permanece; o re-enquadramento
  permanece explicitamente não-pré-aprovado (rodada própria).

## 10. Pergunta final

A v4 aplica as 2 correções factuais que o painel v3 apontou como únicos resíduos. Resta algum gap real, ou
**converge / pode congelar**? O orçamento (§7) está calibrado e o confronto (a)/(b)/(c) é justo com (a)? A4/A5
está sólido com a redação estreitada? Gaps remanescentes priorizados, se houver.

## 11. Auditabilidade — hashes SHA256 dos artefatos (16 primeiros hex)

- `Measure-Robust1k.ps1` — `A25E537FB43BB1E2` (7644 b)
- `robust1k-series.csv` — `77AABA5EAE7FC769` (53527 b) — série temporal completa, 1000×3 amostras
- `Measure-0dColdBurst.ps1` — `16B77FBBD8E16CC3` (7191 b)
- `daemon-pipe-persistpy.ps1` — `21093732B48689EC` (5003 b)
- `shlex-persistent.py` — `56353EAC70CFF602` (2132 b)
- `aot-floor\Program.cs` — `98990752209C33BD` (95 b) — literalmente `return 0;`
