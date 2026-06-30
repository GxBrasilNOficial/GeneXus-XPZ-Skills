# Revisão por pares da decisão do Passo F (§9-0f) — registro de auditoria

**Data:** 2026-06-30. **Acionamento:** humano (autor Antonio José). **Escopo estrito:** a tese
"o critério §9-0e (i) normaliza contra a grandeza errada" se sustenta? Há risco de
segurança/correção/concorrência que a escala de latência (~50 ms) esconda? **Fora de escopo:** "a
ferramenta deve existir" (decidido pelo autor).

## Recibo

- **Manuscrito:** reproduzido na seção «Manuscrito» abaixo (blindado: evidências + hipótese a
  confirmar/refutar; instrui o destinatário a ser revisor, não executor).
- **Painel:** 5 vozes / **3 famílias** (piso de diversidade ≥2 amplamente cumprido).
- **Closeout** (`Resolve-LlmDelegatePeerReviewCloseout.ps1`): `closeoutReady=true`; `vNextState=notProduced`;
  5 revisores preferidos `responded`.

| Voz | Família | Destino | Estado | Veredito |
|---|---|---|---|---|
| Subagente Claude nativo (Agent) | anthropic | local à ferramenta | responded | revisa (com gaps) |
| Codex `gpt-5.5` | openai | OpenAI (externo) | responded | revisa (com gaps) |
| opencode `deepseek-v4-pro` | ollama-cloud | Ollama Cloud (externo) | responded | revisa (com gaps) |
| opencode `glm-5.2` | ollama-cloud | Ollama Cloud (externo) | responded | revisa (com gaps) |
| opencode `kimi-k2.7-code` | ollama-cloud | Ollama Cloud (externo) | responded | revisa (com gaps) |

Payload **público** (docs do repo) → gate `allow` por destino para todos.

## Síntese (convergência unânime: `revisa (com gaps)`)

1. **A tese se sustenta no mérito** (5/5): o (i) normaliza contra o piso de spawn (custo inevitável),
   não contra o baseline operativo real (hook pwsh ~466 ms / clique humano ~1.500–10.000 ms); o daemon
   a ~50 ms fail-closed, 0 mismatch, com (ii)/(iii)/§8 verdes, **justifica liberar**. Nenhuma voz
   chamou de racionalização pura.
2. **A *forma* "gate→alvo porque reprovou" é o mecanismo errado** (5/5; é a 2ª vez que o §9-0e muda
   ao reprovar → risco de viés de confirmação). Convergência sobre o conserto:
   - re-rotular honestamente — *"(i) sempre foi um alvo de eficiência mal-rotulado como gate"*, não
     *"gate virou alvo porque reprovou"* (anthropic);
   - não dissolver o controle: substituir (i) por um critério operacional **com dentes** (latência
     absoluta e2e sob carga + regressão vs hook + taxa máxima de defer/erro — Codex, kimi) **ou**
     liberar sob **variância explícita documentada** mantendo (i) como gate da próxima iteração (glm,
     Codex);
   - **fixar número + prazo** para o ~17–24 ms do daemon em PowerShell (anthropic/kimi/glm), senão
     "alvo" = "ignorado";
   - **salvaguarda contra a 3ª reclassificação** (deepseek, glm).
3. **BLOQUEADOR P0 para LIGAR o fio (não para a tese): concorrência** (5/5). Daemon single-threaded
   medido só sequencialmente; sob rajada as requisições enfileiram. Medir antes do enforce: latência
   com fila por nível de concorrência, %allow vs %defer sob carga, e **provar fail-closed-para-defer**
   do cliente que não consegue ser atendido (nunca allow, nunca erro mal-interpretado). Idem janela
   fria (~700–825 ms) sob rajada e o caminho do perdedor do singleton (0-mismatch só medido
   sequencialmente).

> Nota: o adendo de concorrência (`Measure-PassoF-Concurrency.ps1` + resultados) responde ao gap P0.

---

## Manuscrito enviado ao painel (verbatim)

> (idêntico ao arquivo enviado a cada voz; reproduzido para auditoria)

### SEU PAPEL
Você é UM revisor independente. Emita o SEU PRÓPRIO parecer (concorda / revisa com gaps / rejeita).
Não execute, não monte painel, não delegue. "A ferramenta deve existir" está fora de escopo. Trate as
afirmações como evidências + hipótese a confirmar/refutar.

### Critério §9-0e (i)
GATE: overhead do daemon sobre o piso de spawn (floor `return 0;`) ≤ 5 ms (duas métricas: perc-a-perc
até p95; pareado p90). (ii) guardrail de cauda; (iii) não-regressão vs hook pwsh. O (i) foi calibrado
num protótipo (~1 ms); agora mediu-se o fio real.

### Evidências (n=1000 intercalado, High, Defender ativo, 0 mismatch)
floor p50 29 / p90 33,5 / p95 40; e2e-defer p50 49,8 / p90 62,3 / p95 64,4; e2e-allow p50 48,1 /
p90 63,2 / p95 64,8. Overhead perc-a-perc ~19–30 ms até p95; pareado p90 ~32–34 ms → (i) reprova por
~4–7×. Decomposição: identidade do cliente ~5,5 ms; daemon PS por requisição ~17–24 ms (dominante);
canon ~0,4 ms. Baseline hook pwsh ~466 ms. (ii) passa (%>80ms e2e abaixo do floor); (iii) passa.
Daemon single-threaded; medição sequencial. Frio ~700–825 ms; burst K=20 ≤1 sobrevivente; RSS ~100–121 MB.

### Hipótese (tese do autor)
Reclassificar (i) de gate para alvo e liberar no mérito, porque o baseline operativo real é o hook/o
clique humano, não o piso de spawn + 5 ms. Contexto: 2ª vez que o §9-0e é contestado ao reprovar.

### Perguntas
1. A tese se sustenta tecnicamente ou é racionalização pós-hoc?
2. Há risco de segurança/correção/concorrência que os ~50 ms escondem (em especial o daemon
   single-threaded medido só sequencialmente)?

---

## Pareceres verbatim

### Voz anthropic (subagente Claude nativo) — revisa (com gaps)

Veredito: revisa (com gaps). Tese tecnicamente correta; problema de governança do critério + lacuna
empírica (concorrência) a fechar antes de ligar, não para reverter a decisão, mas para qualificá-la.
Q1: sustenta-se no mérito (o (i) normaliza contra o piso inevitável, não contra o baseline operativo),
mas o padrão de reescrever o §9-0e quando reprova corrói a função de gate. A reconciliação correta NÃO
é "gate vira alvo": é reconhecer que "(i) sempre foi um alvo de eficiência mal-rotulado como gate" —
reclassificar *porque a métrica nunca foi critério de segurança/correção* é correção de design;
reclassificar *porque reprovou* é viés. Ponto não-negociável: fixar agora um alvo numérico + datado
para o ~17–24 ms, senão "alvo" vira "ignorado". Q2: risco de disponibilidade/correção sob carga e a
frio. P0 concorrência: daemon single-threaded medido só sequencialmente; sob rajada enfileira; a
pergunta crítica em aberto é se o cliente sem-conexão defere (benigno) ou trava/erra — tem que ser
provado fail-closed-para-defer. P1 janela fria. P2 cauda p99 (~360 ms; ~3–4% >80 ms) é o teto realista.
Resumo: aprovar a tese; condicionar o enforce ao fechamento dos P0.

### Voz openai (Codex gpt-5.5) — revisa (com gaps)

Tese se sustenta parcialmente. Baseline operativo real (hook pwsh / clique humano) torna ~50 ms uma
melhora material — faz sentido como decisão de produto. Mas reclassificar o §9-0e(i) exatamente quando
reprova é metodologicamente frágil; o critério media se o daemon adicionava custo quase desprezível, e
a medição mostrou ~20–34 ms reais dominados pelo daemon PowerShell. Mudança pós-falha aceitável só com
contenção: documentar a reprovação, explicar a troca de baseline, congelar o novo critério, impedir
novo afrouxamento sem evidência externa. Maior gap: concorrência (daemon single-threaded medido só
sequencial; com 10–20 simultâneos a fila pode virar centenas de ms / defer em massa / bugs de
timeout/startup/singleton). Gaps: (1) teste concorrente obrigatório (5/10/20/50, p50–p99, allow/defer/
error, timeouts, perdedores do singleton, tempo de fila); (2) critério novo congelado contra baseline
operativo (e2e p95/p99 sob carga sequencial e rajada, regressão vs hook, taxa máxima de defer/error);
(3) validar fail-closed sob falha concorrente; (4) limite de fila/timeout explícito; (5) observabilidade
mínima. Não rejeita a liberação no mérito, mas liberaria primeiro em modo controlado/opt-in/piloto.

### Voz ollama-cloud (deepseek-v4-pro) — revisa (com gaps)

Parcialmente se sustenta, com problema de processo. Argumento técnico tem mérito (~9× sobre o hook).
Padrão de reclassificar ao reprovar (2ª vez) é bandeira vermelha metodológica; exige reconhecer o
padrão e instalar salvaguarda contra a 3ª reclassificação. O critério de 5 ms nasceu descalibrado para
a arquitetura real (protótipo NativeAOT vs daemon PowerShell). Q2: risco de concorrência não
caracterizado (daemon single-threaded, medição sequencial); fail-closed mitiga segurança, mas a fila
derruba o propósito se causar defer generalizado sob carga. Janela fria também não caracterizada. Sem
risco de segurança/correção. Gaps: (1) teste de concorrência sob rajada real [BLOQUEADOR]; (2)
caracterização da janela fria [alto]; (3) salvaguarda contra reclassificação futura [alto]; (4) plano
concreto de otimização do overhead PowerShell [médio]; (5) recalibração do critério para a arquitetura
real [médio]. Com 1–3 resolvidos, o fio pode ser liberado.

### Voz ollama-cloud (glm-5.2) — revisa (com gaps)

Inclina a "liberar com variância documentada", NÃO a "reclassificar gate→alvo". Q1: sustenta-se no
mérito (duas grandezas legítimas; a de ganho visível justifica liberar), mas dois problemas: (1) padrão
de relaxamento na direção da liberação (assinatura de viés de confirmação); (2) o gate (i) capturava
sinal de engenharia real (~17–24 ms de PowerShell por requisição re-feito a cada request) — o
miscalibrado era o *limiar* (1→5 ms otimista), não a *métrica*; reclassificá-la a "alvo" descarta o
sinal em vez de endereçá-lo. O certo: liberar sob variância explícita (reconhecer (i) falhou por 4–7×,
justificar a sobrescrita por (ii)+(iii)+§8+baseline, manter (i) como gate da próxima iteração com o
overhead como dívida rastreada). Q2: (1) concorrência [bloqueante] — (ii) só vale no regime sequencial;
sob fila p99 pode passar de 1 s; medir latência com espera + %>80 ms sob rajada de 5–20; (2) caminho
do perdedor do singleton [bloqueante] — 0-mismatch só sequencial; provar que o perdedor nunca emite
allow; (3) aquecimento frio sob rajada [bloqueante p/ a alegação de ganho] — medir %allow vs
%defer-to-human na janela fria; (4) RSS dos perdedores; (5) estado mutável sob a corrida. Conclusão:
liberar, mas não pela reclassificação proposta, e não antes de medir 1–3.

### Voz ollama-cloud (kimi-k2.7-code) — revisa (com gaps)

Tese não é pura racionalização, mas não está livre de viés; a reclassificação precisa de salvaguardas.
Q1: forte na dimensão custo-benefício (~50 ms vs ~466 ms / clique). Mas o (i) nasceu de medição real e
reclassificá-lo muda a pergunta de "o daemon é economicamente suficiente?" para "é tão enxuto quanto
possível?". A reclassificação só se sustenta se acompanhada de um NOVO gate de latência absoluta — não
como remoção do controle. Q2: concorrência é o gap mais sério (single-threaded, medição sequencial;
20 clientes → ~1 s no pior caso); frio ~700–825 ms penaliza o 1º comando. Outros: timeout do cliente
deve sempre deferir (nunca allow); termo dominante cresce com nº de artefatos de staleness; ponto único
de falha; pico RSS. Gaps: (1) medir sob concorrência realista; (2) definir novo gate de latência
absoluto em substituição ao (i); (3) confirmar timeout→defer; (4) plano de otimização do termo
PowerShell com milestones (cache, pipeline assíncrono, eventualmente C#); (5) backpressure/limite de
fila. Veredito: liberação condicional.
