---
name: xpz-llm-delegate
description: Permite ao agente principal delegar tarefas menores, pedir segunda opinião ou conduzir revisão por pares/peer review de plano/design por painel multi-modelo via opencode, Codex, Claude Code (Opus 4.8), GitHub Copilot CLI, Gemini CLI ou Antigravity CLI; ao receber "revisão por pares", carregar esta skill, perguntar revisores preferidos se não houver preferred-reviewers.json, não presumir assinatura externa e nunca rotular parecer solo como revisão por pares; acionamento sempre humano
---

# xpz-llm-delegate

Permite ao agente principal (forte) **delegar tarefas menores** ou **pedir segunda
opinião** a um LLM secundário, sem ceder a ele o juízo das decisões complexas. A
delegação é uma **ferramenta dirigida pelo humano**: nunca é acionada automaticamente
pelo agente — só a pedido do usuário ou com a concordância explícita dele a uma
sugestão.

Há seis motores de delegação (backends): o **opencode** (backend #1, agêntico), o
**Codex** (backend #2, `codex exec`, usando o default da própria ferramenta quando `-Model` é omitido), o **Claude Code**
(backend #3, `claude -p` com Opus 4.8 por padrão), o **GitHub Copilot CLI**
(backend #4, `copilot -p`), o **Gemini CLI** (backend #5, `gemini -p`) e o **Antigravity CLI**
(backend #6, `agy -p`). A skill é **backend-agnóstica**:
o núcleo (classificação de localidade, política de confidencialidade por KB, validação de
saída) é o mesmo para todos; cada backend só contribui seu **adapter de invocação** e seu
**resolvedor de localidade**. O backend é distinguido pelo script que se chama
(`Invoke-Codex`, `Invoke-OpenCode`, `Invoke-ClaudeCode`, `Invoke-Copilot`, `Invoke-Gemini` ou `Invoke-Antigravity`) e pelo parâmetro `-Backend`
do gate — **nunca** pela chave de modelo na política (ver `## ANATOMIA`).

> **Nota de separação conceitual**: O registro do Antigravity como ferramenta de agente gerenciada pela skill `xpz-skills-setup` trata da detecção de instalação, diretórios de skills (`~/.gemini/config/skills/`) e instrucionais globais do Antigravity. Não se confunde com os backends `gemini -p` (backend #5) e Antigravity CLI `agy -p` (backend #6) desta skill, que atuam como adapters de delegação a LLM de forma isolada.

Esta skill é transversal — opera tanto na **raiz de desenvolvimento das skills XPZ**
quanto, com regras mais estreitas, em sessão dentro de uma **pasta paralela de KB**.
Ela não manipula XPZ/XML; o prefixo `xpz-` é marcador de família, como em
`xpz-skills-setup`.

Este mecanismo sustenta a **revisão por pares** — submeter um manuscrito a um painel de
revisores de modelos distintos, que pensam por si e leem as fontes. A **metodologia genérica**
e a régua de convergência são normativas em [`15-revisao-por-pares.md`](../15-revisao-por-pares.md);
o caso **pré-push** dela é o painel de [`14-revisao-pre-push-reforcada.md`](../14-revisao-pre-push-reforcada.md).
Os documentos guardam a metodologia/política; esta skill guarda o mecanismo de delegação.

---

## CONTRATO DE ENTRADA — REVISÃO POR PARES

Quando o usuário pedir `revisão por pares`, `peer review`, `painel multi-modelo` ou
`validar plano multi-modelo`, esta skill deve ser carregada e aplicada antes de responder.
Não trate esses termos como sinônimo de parecer crítico solo.

Regra prática para o agente consumidor:

1. Ler este `SKILL.md` e, quando disponível no repositório de origem/instalação, a
   metodologia [`15-revisao-por-pares.md`](../15-revisao-por-pares.md). Mesmo sem o `15`,
   os passos 2-7 abaixo são o contrato mínimo para não rotular parecer solo como revisão
   por pares.
2. Resolver a lista de revisores preferidos rodando `Resolve-LlmDelegatePreferredReviewers.ps1`.
   O `preferred-reviewers.json` é **machine-level**: vive em
   `%LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json`, **fora do repositório**. **Não**
   procurá-lo no repo (`Glob`/`find`/`ls`/`Grep`) — a busca no repositório sempre dá vazio, e
   concluir `hasPreferences=false` a partir disso é anti-padrão; a **única** fonte de verdade é o
   `hasPreferences` devolvido pelo resolvedor. O mesmo vale para o `capabilities.json` (mesmo
   diretório machine-level).
3. Se não houver lista, perguntar ao usuário quais ferramentas/modelos ele tem disponíveis ou
   prefere, usando nomes reconhecíveis: `Claude Code`, `opencode/Ollama Cloud`, `Codex`,
   `Copilot`, `Gemini`, `Antigravity CLI`, ou subagente nativo da ferramenta atual. A pergunta deve calibrar
   preferência humana, não enumerar tudo que está instalado como menu prescritivo. Backend
   detectado sem preferência registrada deve aparecer como "detectado; confirme se quer usar",
   nunca como recomendação implícita. Não sugerir "caminho mais simples" com serviço externo
   sem preferência confirmada. Se a conversa já registrar ferramentas preferidas do usuário,
   use esse contexto antes de citar alternativas genéricas. Não presumir assinatura de Gemini,
   Copilot, Codex cloud ou qualquer serviço externo sem confirmação ou preferência registrada.
   Depois que o usuário escolher revisores para a rodada sem lista preferida, oferecer salvar
   **essa seleção já feita** como curadoria machine-level em `preferred-reviewers.json`; não
   confundir essa oferta com autorização por KB.
4. Incluir subagente nativo quando fizer sentido: ele pode participar, mas conta como a família
   do orquestrador e não substitui uma família externa para cumprir o piso de diversidade.
5. Rodar o gate de autorização por destino e o piso de diversidade antes de consultar revisores.
6. Antes do recibo final, rodar `Resolve-LlmDelegatePeerReviewCloseout.ps1`. Se a rodada
   começou sem `preferred-reviewers.json` e o usuário escolheu revisores manualmente, o
   closeout deve bloquear enquanto a oferta de salvar essa seleção não tiver sido feita. Se
   `preferred-reviewers.json` já existia, o closeout deve receber o estado final de cada
   revisor preferido da rodada; preferido não pode virar pool opcional silencioso. Ao **autorar**
   a versão consolidada (vN+1), passar `-VNextState pendingResubmission` — o closeout bloqueia
   até `resubmitted` ou declínio auditado (`resubmissionDeclinedByHuman` + `-ResubmissionDeclinedBy`
   + `-ResubmissionDeclineReason` + `-RoundId`). **Dois subcasos do mesmo `resubmissionDeclinedByHuman`**
   distinguem-se pelo `-ResubmissionDeclineReason`: (a) **congelamento do design** — o humano decide
   parar de iterar no papel e transferir a prova para implementação/self-test (motivo ex.: `"prova
   transferida para implementação/self-test"`; ver `15-revisao-por-pares.md`, seção `## Quando o design
   estabiliza: congelar o papel e migrar para o código`); (b) **abandono** do ciclo sem substituto de
   prova. Em ambos o estado **não** é `resubmitted` — a vN+1 não foi revisada pelo painel.
7. Só usar o rótulo `revisão por pares` se houver painel válido (≥2 famílias efetivamente
   consultadas) e recibo mínimo: arquivos lidos, manuscrito/prompt, revisores, famílias,
   resultado do piso, vereditos e o estado da vN+1 (`vNextState`). Sem isso, rotular como
   `parecer solo` ou `segunda opinião (N)`.

Resposta em menos de 30 segundos desde o pedido é evidência de que revisão por pares real não
aconteceu, salvo quando o agente estiver apenas reportando painel anterior identificável por
recibo/livro-razão.

---

## GUIDELINE

- **Acionamento só humano.** Nunca invocar um subagente por conta própria. O agente
  pode **sugerir** delegar; só executa após pedido ou concordância explícita do usuário.
- **O agente forte mantém o juízo.** Nunca delegar decisão estrutural GeneXus
  (classificação de risco de objeto, segurança de import, juízo de família/tipo,
  veredito de gate). Isso fica sempre com o agente principal — ver `## O QUE NÃO DELEGAR`.
- **Validar a saída do subagente.** Toda saída de tarefa delegada é insumo, não verdade.
  O agente forte revisa antes de usar. Modelos fracos não são confiáveis como **piloto
  solo** de conteúdo GeneXus (ver `README.md`, regra de modelos de linguagem); como **voz**
  num painel de revisão por pares são admissíveis (nunca decisivos sozinhos).
- **Confidencialidade por gate determinístico.** Antes de enviar qualquer payload a um
  modelo, classificar o payload (`kb-sensitive` ou `public`) e passar por
  `Resolve-LlmDelegateAuthorization.ps1`. Conteúdo de KB só vai a modelo externo com
  autorização; conteúdo público é livre — ver `## CONFIDENCIALIDADE`.
- **Anunciar o destino.** Mesmo com autorização durável, declarar ao usuário para qual
  modelo (e se local ou externo) o conteúdo está indo a cada uso.
- **Recusa não é o padrão; autorização é.** Para payload sensível a modelo externo sem
  política durável, o gate devolve `ask` — o agente pede autorização explícita e oferece
  **persistir** a escolha no arquivo de política da KB (liberação durável). Em **revisão por
  pares**, os `ask` que faltam para o **piso de diversidade** (≥2 famílias) são apresentados
  **juntos** para uma decisão humana única (anunciando destinos + sensibilidade), **nunca**
  descartados em silêncio — o gate continua decidindo **por destino**. Ver
  `Resolve-LlmDelegatePanelDiversity.ps1` e [`15-revisao-por-pares.md`](../15-revisao-por-pares.md).
- **Não confiar no relógio nem em fatos reportados pelo subagente.** Timestamps,
  contagens e afirmações vindas do modelo secundário podem ser alucinados; validar.

## CONTEXTOS DE USO (uma coisa não atrapalha a outra)

| Contexto | Classe de dado típica | Regra |
|---|---|---|
| Raiz de desenvolvimento das skills XPZ | público (diff do repo, molde sanitizado, README) | externo liberado; é o caso nobre da **diversidade de modelo** (segunda opinião na revisão pré-push) — externo é até desejável, pois diversidade quer um modelo diferente do principal |
| Sessão dentro de pasta paralela de KB | sensível (conteúdo real de KB, `ObjetosDaKbEmXml`, XML) | externo exige autorização (gate); preferir modelo local; o subagente agêntico **não** tem proteção nativa de leitura na pasta paralela — ver `## CONFIDENCIALIDADE` |

A revisão pré-push (`13-revisao-pre-push.md`) **não** se aplica a pastas paralelas. O caso
de diversidade de modelo vive na raiz de desenvolvimento, não na pasta paralela. (A validação
pré-push do **estado** de uma pasta paralela de KB — gates mecânicos antes do push dessa KB — é
a skill [`xpz-kb-parallel-pre-push`](../xpz-kb-parallel-pre-push/SKILL.md): rotina distinta da do
`13` e que **não** usa este mecanismo de delegação.)

## ANATOMIA (cada parte faz o quê, e qual eixo governa)

A skill separa **três eixos independentes**. Confundi-los gera erro (ex.: namespear a
política pelo backend abre brecha de confidencialidade). Os eixos:

| Eixo | Pergunta | Onde mora |
|---|---|---|
| **Tarefa** | é delegável (mecânica/2ª opinião) ou é juízo GeneXus? | `## O QUE NÃO DELEGAR` |
| **Adapter** (como o dado é enviado) | qual motor leva o prompt? | o **script** que se chama (`Invoke-Codex`, `Invoke-OpenCode`, `Invoke-ClaudeCode`, `Invoke-Copilot`, `Invoke-Gemini`, `Invoke-Antigravity`) |
| **Destino** (para onde o dado vai) | o tráfego sai da máquina? para qual provider? | resolvedor de localidade + política |

**Invariante de destino (a regra que evita o erro):** a chave de modelo no gate e na
política é o **`provider/modelo` de DESTINO** — para onde o tráfego vai. Adapters diferentes
que enviam para o **mesmo** provider normalizam para a **mesma** chave; o backend/adapter
**nunca** entra na chave. Por isso o Codex com `gpt-5.5` explícito ou derivado da config (que vai para a OpenAI) casa a chave
`openai/gpt-5.5` e é governado pelas **mesmas** regras `openai/*` que o opencode — não por uma
chave `codex/*`. Namespear por adapter faria uma regra `openai/*: deny-external` deixar o
Codex passar: brecha silenciosa no eixo que o gate existe para proteger. Pelo mesmo motivo,
Claude Code com Opus 4.8 casa `anthropic/claude-opus-4-8`, nunca `claude-code/*`.
GitHub Copilot CLI casa `github-copilot/<modelo>` (ex.: `github-copilot/gpt-5-mini`),
nunca `openai/*`, porque o destino operacional é o serviço Copilot. Gemini CLI casa
`google/<modelo>` (ex.: `google/gemini-3-flash-preview`). Antigravity CLI casa `antigravity/<modelo>` (ex.: `antigravity/gemini-3.6-flash-high`).

Mapa de responsabilidade por componente (em `scripts/`, na raiz):

| Componente | Governa | Não faz |
|---|---|---|
| `Invoke-*` / `Start-*Job` (adapter) | **como** o prompt é enviado (mecânica do motor) | não decide destino nem confidencialidade |
| `Resolve-OpenCodeModelLocality` / `Resolve-CodexModelLocality` / `Resolve-ClaudeCodeModelLocality` / `Resolve-CopilotModelLocality` / `Resolve-GeminiModelLocality` / `Resolve-AntigravityModelLocality` | traduz a invocação → **`provider/modelo` de destino** (`canonicalModel`) + local/external | não lê o payload |
| `Resolve-LlmDelegateAuthorization` (gate) | veredito allow/ask/deny por destino + sensibilidade + política | não envia nada; seleciona o resolvedor por `-Backend` |
| `llm-delegation-policy.json` (política por-KB; nome legado `opencode-delegation-policy.json` ainda aceito) | autorização durável por **chave de destino** | não conhece o adapter |

## CONFIDENCIALIDADE

A classificação **local vs externo é determinística**, lida da config do backend pelo
`baseURL`/`base_url` do provider de destino (loopback ⇒ local; caso contrário ⇒ externo).
No opencode vem da config JSON; provedores cloud conhecidos (`ollama-cloud/*`,
`opencode-go/*`) são classificados como externos mesmo quando a config local não está legível.
No Codex, a classificação vem da `config.toml` (`model`, `model_providers`/`profiles`) ou
das flags `--oss`/`--local-provider`; quando `-Model` é omitido, vale o default do próprio Codex/config.
No Claude Code, modelos Claude explícitos são tratados como destino Anthropic externo;
`opus` é normalizado conservadoramente para `anthropic/claude-opus-4-8`, e aliases não
mapeados ficam `unknown`.
No Copilot CLI, o destino é sempre externo e normalizado para `github-copilot/<modelo>`.
No Gemini CLI, o destino é sempre externo e normalizado para `google/<modelo>`.
No Antigravity CLI, o destino é sempre externo e normalizado para `antigravity/<modelo>`.
Já a pergunta *"este payload é sensível?"* **não** é determinística — ancora no
**contexto/origem**, não em varrer o texto. Não há selo técnico: o que segura é gatilho
humano + gate + contrato.

Dois eixos independentes:

1. **Tipo de tarefa** (governa confiabilidade): mecânica/segunda-opinião pode ir a modelo
   secundário; juízo GeneXus, não.
2. **Sensibilidade do payload** (governa confidencialidade): conteúdo de KB → só modelo
   local, salvo autorização; texto público → externo livre.

Scripts do gate (em `scripts/`, na raiz do repositório):

- `Resolve-OpenCodeModelLocality.ps1 -Model <provider/modelo>` → JSON `{ locality: local|external|unknown, baseUrl, reason }`. Backend opencode; `ollama-cloud/*` e `opencode-go/*` são externos conhecidos mesmo sem config legível.
- `Resolve-CodexModelLocality.ps1 [-Model <m>] [-Oss] [-LocalProvider <ollama|lmstudio>] [-Profile <id>]` → JSON `{ locality, baseUrl, canonicalModel, reason }`. Backend codex; quando `-Model` é omitido, tenta derivar o modelo do `config.toml`; `canonicalModel` é a chave de destino (ex.: `openai/gpt-5.5`).
- `Resolve-ClaudeCodeModelLocality.ps1 [-Model <m>]` → JSON `{ locality, canonicalModel, reason }`. Backend Claude Code; `opus` e `claude-opus-4-8` casam `anthropic/claude-opus-4-8`.
- `Resolve-CopilotModelLocality.ps1 [-Model <m>]` → JSON `{ locality, canonicalModel, reason }`. Backend Copilot; `canonicalModel` casa `github-copilot/<modelo>`.
- `Resolve-GeminiModelLocality.ps1 [-Model <m>]` → JSON `{ locality, canonicalModel, reason }`. Backend Gemini; `canonicalModel` casa `google/<modelo>`.
- `Resolve-AntigravityModelLocality.ps1 [-Model <m>]` → JSON `{ locality, canonicalModel, reason }`. Backend Antigravity; `canonicalModel` casa `antigravity/<modelo>`.
- `Resolve-LlmDelegateAuthorization.ps1 [-Model <m>] -PayloadSensitivity <kb-sensitive|public> [-Backend <opencode|codex|claude-code|copilot|gemini|antigravity>] [-Oss] [-LocalProvider <p>] [-Profile <id>] [-ConfigPath <opencode.json|config.toml>] [-PolicyPath <json>] [-ParallelKbRoot <dir>]` → JSON `{ verdict: allow|ask|deny, targetModelKey, policyNameStatus, ... }`. Núcleo backend-agnóstico; seleciona o resolvedor por `-Backend` e casa a política pela chave de destino. `-ConfigPath` é repassado ao resolvedor de localidade (config do backend: `opencode.json` no opencode, `config.toml` no codex). Com `-ParallelKbRoot` (e sem `-PolicyPath`), descobre a política pelo nome canônico com fallback ao legado e reporta `policyNameStatus`; `-PolicyPath` explícito prevalece.

Lógica do gate:

```
payload = public                  -> allow  (qualquer modelo)
payload = kb-sensitive:
    localidade local              -> allow  (dado não sai da máquina)
    localidade external/unknown   -> política por-KB:
        allow-external            -> allow  (anunciar destino)
        deny-external             -> deny
        ask / não definido        -> ask    (autorização explícita do usuário)
```

## ARQUIVO DE POLÍTICA POR KB

Nome canônico: `llm-delegation-policy.json` na raiz da pasta paralela da KB (criado/ofertado
pelo `xpz-kb-parallel-setup`, ou ao persistir uma autorização). O nome legado
`opencode-delegation-policy.json` — herdado de quando só existia o backend opencode —
permanece aceito **indefinidamente** para retrocompatibilidade; o arquivo governa **todos** os
backends pela chave de destino, então o nome de um backend específico é apenas histórico.
`scripts/Resolve-LlmDelegationPolicyPath.ps1 -ParallelKbRoot <raiz>` resolve o caminho efetivo
(canônico com fallback ao legado) e devolve `status` `new|legacy|both|none`; o gate aceita
`-ParallelKbRoot` e usa esse resolvedor quando `-PolicyPath` é omitido. Granularidade fina por
`provider/modelo`, com curinga de provider e default. Ausente ⇒ comportamento `ask`.

```json
{
  "schemaVersion": 1,
  "defaultExternal": "ask",
  "models": {
    "openai/gpt-5.4": "allow-external",
    "ollama-cloud/*": "deny-external"
  }
}
```

Resolução do modelo na política: chave exata → curinga `provider/*` → curinga `*` →
`defaultExternal` → `ask` (quando não há arquivo). Valores válidos por entrada:
`allow-external`, `deny-external`, `ask`.

A chave é sempre o **provider de destino** (ver `## ANATOMIA`), não o backend. O Codex com
`gpt-5.5` casa `openai/gpt-5.5` / `openai/*` — as **mesmas** entradas que governam o opencode
quando manda para a OpenAI. Não existe (nem deve existir) prefixo `codex/` na política.
O Claude Code com Opus 4.8 casa `anthropic/claude-opus-4-8` / `anthropic/*`; não existe
prefixo `claude-code/` na política.
O Copilot CLI casa `github-copilot/gpt-5-mini` / `github-copilot/*`; não existe prefixo
`copilot/` na política. O Gemini CLI casa `google/gemini-3-flash-preview` / `google/*`;
não existe prefixo `gemini/` na política.

## O QUE NÃO DELEGAR

Fica sempre com o agente forte (nunca no subagente):

- Classificação de risco/família/tipo de objeto GeneXus
- Decisão de segurança de import/build e veredito de qualquer gate
- Interpretação de Source/Rules/Events para decisão de empacotamento
- Qualquer decisão que vire ação de escrita na KB ou no repositório

## TAREFAS DELEGÁVEIS (sugestões iniciais, não exaustivas)

- Resumir um log longo / saída verbosa
- Reformatar ou normalizar texto
- Rascunhar mensagem de commit a partir de um diff
- Tradução das seções `Español`/`English` do `README.md` (trabalho recorrente)
- **Segunda opinião de modelo distinto** na revisão semântica pré-push (diversidade de
  modelo do `13`) — payload público (diff/`.md` do repo)
- Transformações mecânicas de texto que o agente forte valida depois

---

## TRIGGERS

Use esta skill para:
- Delegar uma tarefa menor a um LLM secundário, a pedido do usuário ou com a concordância
  dele a uma sugestão
- Pedir segunda opinião de um modelo distinto (ex.: diversidade de modelo na revisão pré-push)
- Conduzir uma **revisão por pares** de um plano/design — montar um painel multi-modelo e ofertar a composição conforme os modelos/backends disponíveis na máquina (gatilhos: "revisão por pares", "peer review", "painel de modelos", "validar plano multi-modelo"); ver [`15-revisao-por-pares.md`](../15-revisao-por-pares.md)
- Calibrar e usar a **lista de revisores preferidos** (`preferred-reviewers.json`) que alimenta a oferta de painel sem re-sondar; no 1º uso de revisão por pares sem lista, perguntar ao usuário quais ferramentas/modelos ele tem disponíveis ou prefere, em linguagem de ferramenta (`Claude Code`, `opencode/Ollama Cloud`, `Codex`, `Copilot`, `Gemini`, `Antigravity`, subagente nativo), antes de oferecer painel — ver `Set-`/`Resolve-LlmDelegatePreferredReviewers.ps1`
- Disparar uma tarefa longa sem bloquear (job assíncrono com janela de acompanhamento)
- Delegar a um sub-agente Codex (`codex exec`) — síncrono ou assíncrono
- Delegar a um sub-agente Claude Code (`claude -p`, Opus 4.8) — síncrono ou assíncrono
- Delegar consulta curta ao GitHub Copilot CLI (`copilot -p`) — síncrono
- Delegar consulta curta ao Gemini CLI (`gemini -p`) — síncrono
- Delegar consulta curta ao Antigravity CLI (`agy -p`) — síncrono
- Classificar se um modelo do opencode, Codex, Claude Code, Copilot, Gemini ou Antigravity é local ou externo
- Decidir, via gate, se um payload pode ser enviado a um modelo (allow/ask/deny), em qualquer backend

Do NOT use esta skill para:
- Delegar juízo estrutural GeneXus (ver `## O QUE NÃO DELEGAR`)
- Enviar conteúdo de pasta paralela de KB a modelo externo sem passar pelo gate
- Acionar um subagente automaticamente sem pedido/concordância do usuário
- Registrar a própria skill nas ferramentas (use `xpz-skills-setup`)
- Preparar a pasta paralela de uma KB (use `xpz-kb-parallel-setup`)

---

## SCRIPTS (em `scripts/`, na raiz do repositório)

Backend opencode:
- `Invoke-OpenCode.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <p/m>] [-Agent <n>] [-OpenCodeExe <path>] [-Raw] [-AllText] [-TimeoutSec <s>] [-MaxAttempts <1-3>]` — síncrono (prompt → texto). Bloqueia até a resposta. `-AllText` devolve toda a narração (preâmbulos + resposta) em vez de só a resposta final. Entrega o prompt por **stdin** (arquivo via `Start-Process -RedirectStandardInput`), fora do argv; `-MessagePath` lê o prompt de um arquivo (exclusivo com `-Message`); `-OpenCodeExe` força o `opencode.exe`. Sem override, a descoberta aceita `opencode` no `PATH` (WinGet/Scoop/binário direto) e a instalação npm legada. `-MaxAttempts` (default 1) liga o **retry-once** opt-in (ver «Detecção de truncamento (Achado D)» → «Retry-once»). **Sem `-Agent`, o default é `reviewer-ro`** (least-privilege «sem execução/escrita») com **guard fail-closed** (pré-check ANTES do run + pós-check de fallback); `-Agent <x>` explícito com `x ≠ reviewer-ro` = opt-out consciente (confirma só que `<x>` resolve). `-Agent reviewer-ro` explícito recai no enforce (igual ao default). Ver «OPENCODE — REVISOR LEAST-PRIVILEGE».
- `Start-OpenCodeJob.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <p/m>] [-Agent <n>] [-OpenCodeExe <path>] [-NoWatcher] [-TempDir <path>] [-KeepDays <n>]` — assíncrono; retorna `{jobId, pid, stream, result, watcher}`; abre janela de acompanhamento por padrão. Entrega o prompt por **stdin** (`<GUID>.stdin.txt`) e usa um runner mínimo só para gravar `<GUID>.exitcode.txt`, evidência de exit code do opencode consumida pelo watcher. O `pid` retornado é do **runner pwsh**, não do processo opencode; o campo `result` é caminho previsto, não aceite de parecer. **Sem `-Agent`, default `reviewer-ro` + pré-check fail-closed ANTES do spawn do runner** (o spawn é a barreira; ver «OPENCODE — REVISOR LEAST-PRIVILEGE»).
- `Watch-OpenCodeJob.ps1 -JobId <guid> -ProcessId <pid> [-TempDir <path>] [-IntervalSeconds <1-30>] [-SilenceThresholdSeconds <30-3600>]` — monitor incremental; `-ProcessId` delimita a vida do processo observado (no fluxo padrão, o runner pwsh) e `<GUID>.exitcode.txt` é a evidência canônica do exit do opencode. Grava `<GUID>.result.json` local `schemaVersion=2` ao fim. Aceite técnico exige shape v2 válido por `Get-OpenCodeAcceptedResult`, `resultAccepted=true`, `status=completed`, `hasStepFinish=true`, `completionVerdict=ok`, `finishReason=stop`, `watcherExitCode=0`, `opencodeExitCode=0`, `fallbackToBuild=false`, `fallbackDetail=null`, `finalTextDisposition=accepted`, `error=null`, `rejectionReason=''` e `acceptedFinalText` não vazio e igual a `finalText`. Fallback de agente opencode para `build`/default, erro, truncamento, sem conclusão, sem texto ou exit opencode diferente de zero/desconhecido invalidam o aceite (`resultAccepted=false`, `watcherExitCode=20`). Além dos critérios de aceite, `Get-OpenCodeAcceptedResult` valida a coerência interna de resultados rejeitados e recusa `result.json` corrompido ou fabricado; a enumeração canônica desses casos fica no self-test `scripts/Test-OpenCodeStreamSupportSelfTest.ps1`. Falha interna do watcher antes da promoção atômica sai com `99`, emite `WATCHER_INTERNAL_ERROR` e não promove `<GUID>.result.json`. `resultAccepted=true` é aceite técnico do watcher assíncrono opencode; não muda `responded`/`noResponse` nem a utilidade do parecer no painel.
- `OpenCodeCliSupport.ps1` (dot-source) — descoberta do `opencode.exe` por `-OpenCodeExe`, `PATH` e npm legado, validando `opencode --version`. Validação: `Test-OpenCodeCliSupportSelfTest.ps1` (`OPENCODE_CLI_SUPPORT_SELFTEST_OK`).
- `Test-OpenCodeReviewerRoInstalledCompatibility.ps1 [-OpenCodeExe <path>] [-AsJson]` — diagnóstico local sem modelo/rede para quando o guard bloquear por versão: resolve o CLI, verifica o frontmatter do `reviewer-ro`, lê `opencode --version` e confere o allow-set efetivo de `opencode agent list`. Status `needsFixtureRecapture` significa "estrutura local OK, versão ainda não promovida"; não autoriza sozinho o uso do `reviewer-ro`.

No backend opencode, `-Model` deve usar o identificador aceito pelo CLI no formato
`provider/modelo`. Para Ollama Cloud, use `ollama-cloud/deepseek-v4-pro`; o nome curto
`deepseek-v4-pro` não identifica o provider e tende a falhar antes da chamada.

Backend codex (`codex exec`, default da própria ferramenta/config quando `-Model` é omitido, sandbox `read-only` fixo):
- `Invoke-Codex.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <m>] [-Oss] [-LocalProvider <ollama|lmstudio>] [-Profile <id>] [-Cd <dir>] [-CodexExe <path>] [-TimeoutSec <s>]` — síncrono (prompt → texto). Prompt via stdin; resposta final pelo `output-last-message`. `-MessagePath` lê o prompt de arquivo (exclusivo com `-Message`; dispensa `(Get-Content)` inline no chamador); stdin-based, então **não** está sujeito ao teto ~32KB.
- `Start-CodexJob.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <m>] [-Oss] [-LocalProvider <p>] [-Profile <id>] [-Cd <dir>] [-CodexExe <path>] [-NoWatcher] [-TempDir <path>] [-KeepDays <n>]` — assíncrono; retorna `{jobId, pid, stream, lastmsg, result, watcher}`; abre janela de acompanhamento por padrão. `-MessagePath` exclusivo com `-Message` (o texto do prompt segue persistido em `request.json`/`stdin.txt`).
- `Watch-CodexJob.ps1 -JobId <guid> -ProcessId <pid> [-TempDir <path>] [-IntervalSeconds <1-30>] [-SilenceThresholdSeconds <30-3600>]` — monitor incremental do stream `--json`; grava `<GUID>.result.json` ao fim (`status`, `finalText`, `error`, `inputTokens`, `outputTokens`).
- `CodexCliSupport.ps1` (dot-source) — descoberta **fail-closed** do `codex.exe` compatível: prefere o executável canônico `%LOCALAPPDATA%\OpenAI\Codex\bin\codex.exe` quando responde a `--version`, exclui diretórios `backup-*` e só então recorre aos subdiretórios não-backup pela maior versão utilizável; ignora o shim npm do PATH.

Nota de default de modelo: `Invoke-OpenCode.ps1` e `Invoke-Codex.ps1` seguem o mesmo contrato.
Se `-Model` for omitido, o adapter não força modelo e deixa o default da ferramenta/config valer.
`gpt-5.5` permanece apenas como exemplo/sugestão de revisor Codex no painel reforçado, não como
modelo fixado pelo adapter.

Backend Claude Code (`claude -p`, Opus 4.8 por padrão, externo Anthropic):
- `Invoke-ClaudeCode.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <m>] [-PermissionMode <mode>] [-Tools <list>] [-Cd <dir>] [-ClaudeExe <path>] [-TimeoutSec <s>]` — síncrono (prompt → texto). Prompt via stdin (`-MessagePath` lê de arquivo, exclusivo com `-Message`; stdin-based, sem o teto ~32KB); por padrão usa consulta curta restrita (`PermissionMode=plan`, `Tools=Read,Glob,Grep`, sem persistência de sessão). `-Tools ""` desabilita todas as ferramentas (vira `--tools ""`); `-Tools default` libera o conjunto padrão completo da CLI. **Sem limite de turnos** — ver nota abaixo.
- `Invoke-ClaudeCodeAsync.ps1 [-Message <prompt> | -MessagePath <arquivo>] -SidecarPath <json> [-Model <m>] [-PermissionMode <mode>] [-Tools <list>] [-Cd <dir>] [-ClaudeExe <path>] [-TimeoutSec <s>] [-RetentionMode public|kb-sensitive] [-CircuitStateRoot <dir>] [-TempDir <dir>]` — adapter assíncrono **do painel**: usa `--output-format stream-json`, grava sidecar técnico atômico validado pelo dispatcher e só escreve stdout quando existe texto final aceito (`resultAccepted=true`). É o único caminho Claude Code usado por `Invoke-LlmDelegatePanelDispatch.ps1`; `-ClaudeExe` é test-only/diagnóstico e não depende de manipular `PATH`.
- `Start-ClaudeCodeJob.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <m>] [-PermissionMode <mode>] [-Tools <list>] [-Cd <dir>] [-ClaudeExe <path>] [-NoWatcher] [-TempDir <path>] [-KeepDays <n>]` — assíncrono; retorna `{jobId, pid, stream, result, watcher}`; abre janela de acompanhamento por padrão. `-MessagePath` exclusivo com `-Message` (o texto do prompt segue persistido em `request.json`/`stdin.txt`). Mesmo contrato de `-Tools` e mesma ausência de limite de turnos.
- `Watch-ClaudeCodeJob.ps1 -JobId <guid> -ProcessId <pid> [-TempDir <path>] [-IntervalSeconds <1-30>] [-SilenceThresholdSeconds <30-3600>]` — monitor incremental do stream `--output-format stream-json`; grava `<GUID>.result.json` ao fim (`status`, `finalText`, `error`, `failureAfterText`). Reconhece como falha tanto um evento `type=error` quanto o **evento final `type=result` com `is_error=true`** (subtype `error_max_turns` e afins) — medido em 2026-07-25 (`claude 2.1.220`), o desfecho do stream vem no `result`, não num `error`. O erro do stream passa pelos **mesmos** detectores do caminho síncrono: esgotamento de turno vira `max-turns-exhausted` (`status=error`) e a **recusa** por workspace não confiável vira `workspace-not-trusted` com `status=unavailable`, preservando a evidência e a instrução de coleta segura; texto de falha que não casa detector algum segue cru. **Resposta final continua mandando** (`status=completed`), mas a falha que chega **depois** de já haver texto não é descartada: vai em `failureAfterText`, marcando que a resposta pode estar truncada. Isso **pode** acontecer no esgotamento de turno — medido em 2026-07-25 nos dois modos: um ensaio gastou o turno só em `tool_use` (sem texto, desfecho `error` normal), outro teve o assistente emitindo uma frase antes da ferramenta (texto + falha). A extração da evidência lê `subtype`, `terminal_reason`, `result` **e `errors[]`**, porque no evento real de `error_max_turns` o campo `result` não existe e a mensagem legível («Reached maximum number of turns (1)») vive em `errors[]`. Quem decide se um parecer truncado vale é o orquestrador, na reclassificação pós-hoc do [`15`](../15-revisao-por-pares.md) (`responded`→`noResponse`).
- `ClaudeCodeCliSupport.ps1` (dot-source) — descoberta **fail-closed** do `claude.exe`, validação de versão/flags mínimas, extração de erros, texto aceito e sinais de cota a partir de `stdout`/`stderr`/stream. **Descarta ruído de ambiente antes de classificar**: os avisos `Ignoring N permissions.allow entries…` e `Permission allow rule (…)` aparecem inclusive em execução bem-sucedida (medido em 2026-07-25) e não são evidência de falha. Emite `max-turns-exhausted` para esgotamento de turno — por três gatilhos medidos: o texto `Reached max turns` (modo `text`), a mensagem `Reached maximum number of turns (N)` de `errors[]` e o subtype `error_max_turns` do stream — e reserva `workspace-not-trusted` para recusa genuína. `Get-ClaudeCodeStreamAcceptedTextFromEvents` aceita `content_block_delta.delta.text` e, na ausência de deltas, `assistant.message.content[].text`; `result.result` nunca vira parecer. `Get-ClaudeCodeStreamQuotaEvidence` detecta `rate_limit_event.status=rejected`, `assistant.error=rate_limit` e `result` com `api_error_status=429`/`terminal_reason=api_error`.

> **Claude Code — não inferir janela de quota no recibo humano.** Para Claude Code, o estado
> `quota` significa apenas **limite de uso atingido**. O agente pode preservar no sidecar evidência
> técnica bruta (`rateLimitType`, `reportedLimitScope`, `resetsAtUtc`, texto do CLI), mas **não** deve
> traduzir isso em "mensal", "semanal", "5 horas" ou qualquer janela/camada de cobrança no recibo
> humano. Campos técnicos ou texto bruto do CLI podem ser citados apenas como evidência bruta em
> ledger/diagnóstico técnico; no diálogo com o usuário, reportar: `Claude Code retornou limite de uso;
> tipo/período não determinado`.

> **Códigos de saída do Claude Code (fontes oficiais, não tabela exaustiva).** A documentação oficial consultada não publica uma tabela geral de exit codes para `claude`/`claude -p`; os significados abaixo vêm de menções específicas, não de um contrato completo do CLI. `0` = sucesso do processo ou do subcomando quando documentado (ex.: `claude auth status` logado); `1` = falha genérica do processo/subcomando quando `stdout`/`stderr`/stream/log não trazem causa classificável (a própria referência de erros diz que `code N` sozinho não diz o que falhou); `2` = código documentado para **hooks** do Claude Code como bloqueio, não contrato geral do processo `claude -p`; `137` = processo morto, citado na documentação de instalação como encerrado antes de concluir, com possível kill/OOM. Fontes oficiais: Claude Code CLI reference (`claude auth status` 0/1), Error reference (`process exited with code N`, `--settings` sai 1, instalação com 137) e Hooks reference (`exit 2` como bloqueio em hooks). Não inferir quota, autenticação, workspace ou modelo apenas pelo número.

> **Sem `-MaxTurns` (2026-07-25).** O parâmetro existia nos dois adapters e era **descartado em silêncio**: eles só enviavam `--max-turns` se a flag aparecesse no `claude --help`, e a CLI 2.1.215 deixou de anunciá-la. As chamadas sempre rodaram com turnos ilimitados. O parâmetro foi removido em vez de mantido mentindo; a direção de calibrar o limite está **descartada** em `998-ideias-descartadas-e-porque.md`, com a medição que mostra por que "passar a flag sempre" seria danoso.

Backend GitHub Copilot CLI (`copilot -p`, externo GitHub Copilot):
- `Invoke-Copilot.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <m>] [-Cd <dir>] [-CopilotExe <path>] [-TimeoutSec <s>]` — síncrono (prompt → texto). Usa `--no-custom-instructions`, `--disable-builtin-mcps`, `--available-tools=` e JSONL para consulta curta sem ferramentas disponíveis; `--allow-all-tools` permanece porque o CLI exige aprovação automática em modo não interativo. `-MessagePath` lê o prompt de arquivo (exclusivo com `-Message`; elimina o `(Get-Content)` inline), mas é **argument-based** — o prompt segue no argv, então **não** levanta o teto ~32KB; um guard fail-closed (`$MaxArgvPromptChars = 30000`, heurístico em chars) recusa prompts grandes com `BLOCK`.
- `CopilotCliSupport.ps1` (dot-source) — descoberta **fail-closed** do `copilot`, validação de versão/flags mínimas e extração de resposta do JSONL.

Backend Gemini CLI (`gemini -p`, externo Google):
- `Invoke-Gemini.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <m>] [-ApprovalMode plan] [-Cd <dir>] [-GeminiExe <path>] [-TimeoutSec <s>]` — síncrono (prompt → texto). Usa `--approval-mode plan` e `--output-format json`; o adapter bloqueia modos diferentes de `plan`. `-MessagePath` lê o prompt de arquivo (exclusivo com `-Message`; elimina o `(Get-Content)` inline), mas é **argument-based** — o prompt segue no argv, então **não** levanta o teto ~32KB; um guard fail-closed (`$MaxArgvPromptChars = 30000`, heurístico em chars) recusa prompts grandes com `BLOCK`.
- `GeminiCliSupport.ps1` (dot-source) — descoberta **fail-closed** do `gemini`, validação de versão/flags mínimas e extração de erros.

Backend Antigravity CLI (`agy -p`, externo Antigravity/Google):
- `Invoke-Antigravity.ps1 [-Message <prompt> | -MessagePath <arquivo>] [-Model <m>] [-Mode plan] [-Cd <dir>] [-AntigravityExe <path>] [-TimeoutSec <s>]` — síncrono (prompt → texto em JSON `.response`). Usa `--mode plan`, `--output-format json` e `--print-timeout "$($TimeoutSec)s"`; o adapter bloqueia modos diferentes de `plan`. `-MessagePath` lê o prompt de arquivo (exclusivo com `-Message`; elimina o `(Get-Content)` inline), mas é **argument-based** — o prompt segue no argv, então **não** levanta o teto ~32KB; um guard fail-closed (`$MaxArgvPromptChars = 30000`, heurístico em chars) recusa prompts grandes com `BLOCK`.
- `AntigravityCliSupport.ps1` (dot-source) — descoberta **fail-closed** do `agy.exe` (no `PATH` ou `%LOCALAPPDATA%\agy\bin\agy.exe`), validação de contrato **mínimo de descoberta** (`--print`/`--prompt` e `--mode` — basta para distinguir o CLI certo; o adapter usa também `--output-format`, `--print-timeout` e `--model`, cobertos por fake-exe nos self-tests, não por este probe de help) e extração de erros de cota (`$quotaFailurePattern` exportado para autotestes).

**Contrato JSON observado no `agy.exe` instalado** (medição direta, 2026-08-04 — não coberto por self-test, que usa fake-exe):

```json
{"conversation_id":"…","status":"SUCCESS","response":"OK\n","duration_seconds":42.6,"num_turns":1,"usage":{"input_tokens":17125,"output_tokens":43,"thinking_tokens":39,"cache_read_tokens":0,"total_tokens":17168}}
```

Em falha, o mesmo envelope traz `status="ERROR"`, `response=""` e `error` com o motivo — e o processo sai com **exit code ≠ 0**. Ou seja, o caminho de erro que o CLI realmente usa é o do exit code (tratado antes do parse, com `Get-AntigravityErrorMessage`); o guard de `status != SUCCESS` no adapter é **defesa em profundidade** para um exit 0 com status de erro, não o fluxo observado. Campos além de `status`/`response` não são consumidos pelo adapter.

Latência por provedor: modelos externos OAuth (`openai/*`, Codex externo; `anthropic/*`,
Opus 4.8 do Claude Code; `github-copilot/*`; `google/*`) podem passar de 180s — ajustar `-TimeoutSec`; `ollama-cloud/*` e
`opencode-go/*` costumam responder mais rápido.

**Antigravity (`antigravity/*`) é caro e lento mesmo em prompt trivial.** Medição de 2026-08-04:
`responda apenas OK` (18 chars) levou **42,6s** e consumiu **17.125 tokens de input** — o CLI injeta
contexto próprio grande antes do prompt, então o custo **não** acompanha o tamanho do manuscrito.
Com dossiê de pré-push perto do teto de 30000 chars, contar com latência bem acima disso e revisar
`-TimeoutSec` (default 300s, repassado ao `--print-timeout` do CLI) antes de usá-lo em painel.

Em painéis com múltiplos revisores `ollama-cloud/*`, limitar o paralelismo desse provider a
**3 chamadas simultâneas** e enfileirar os demais. Em teste real, disparar 4 modelos
`ollama-cloud/*` ao mesmo tempo produziu ausência de parecer utilizável em um deles; rodado
sozinho, o mesmo modelo respondeu normalmente. Portanto, falha sem texto nesse cenário deve ser
tratada primeiro como possível saturação de concorrência do provider, não como evidência de baixa
qualidade do modelo. A regra vigente **não** faz redisparo isolado automático fora da `fallbackChain`:
falha sem texto colhida em lote concorrente é registrada de forma auditável como falha técnica, com
`concurrencySaturationWarning` quando aplicável, e o orquestrador só redispara isolado se houver
decisão humana explícita. Não transformar esse caso em laço de redisparo nem mascarar o estado no
recibo. Escopo: falha sem texto em lote concorrente — não `gateDeny`/`gateAsk`/timeout legítimo.

Núcleo backend-agnóstico:
- `Resolve-OpenCodeModelLocality.ps1`, `Resolve-CodexModelLocality.ps1`, `Resolve-ClaudeCodeModelLocality.ps1`, `Resolve-CopilotModelLocality.ps1`, `Resolve-GeminiModelLocality.ps1`, `Resolve-AntigravityModelLocality.ps1`, `Resolve-LlmDelegationPolicyPath.ps1` (resolve o caminho do arquivo de política: nome canônico `llm-delegation-policy.json` com fallback ao legado `opencode-delegation-policy.json`; `status` `new|legacy|both|none`) e `Resolve-LlmDelegateAuthorization.ps1` (ver `## ANATOMIA` e `## CONFIDENCIALIDADE`).

Sondagem de capacidade (para a oferta de revisão por pares — ver [`15-revisao-por-pares.md`](../15-revisao-por-pares.md)):
- `Build-LlmDelegateCapabilityManifest.ps1 [-OutputPath <json>] [-SnapshotPath <json>] [-OpenCodeConfigPath <opencode.json|jsonc>] [-CodexConfigPath <config.toml>] [-ClaudeSettingsPath <settings.json>] [-ClaudeStatsCachePath <stats.json>] [-AntigravityExe <path>]` — sonda os backends instalados e enumera capacidade **sem fabricar provider**: opencode lê JSON/JSONC; Codex usa `config.toml`/resolvedor e deixa provider `unknown` quando a fonte não prova o destino; Claude Code combina settings configurado (`sourceKind=configured`, `sourceConfidence=strong`) com cache histórico (`historical`, `weak`, `availableInManifest=false`, `enumeration=settings-or-historical`); Antigravity CLI sonda modelos via `agy models` (`enumeration=cli`, `sourceConfidence=strong`); Copilot/Gemini seguem como capacidade sem enumeração nativa forte (`enumeration=none-native`). Grava manifesto sanitizado machine-level (default `%LOCALAPPDATA%\xpz-llm-delegate\capabilities.json`) com `backend`, `targetModelKey`, `canonicalModel`, `provider`, `family`, `sourceKind`, `sourceConfidence`, `availableInManifest`, `locality`, `reasonCode`, `hardVeto` e `diagnostics` — **nunca** token, chave, baseURL, header, path de config, prompt ou política. É **dica de oferta**: o gate (`Resolve-LlmDelegateAuthorization.ps1`) **não** o consome — reavalia destino e sensibilidade sempre. Self-test `Test-LlmDelegateCapabilityManifestSelfTest.ps1`.
- `Set-LlmDelegatePreferredReviewers.ps1 -ReviewersJson <json> [-OutputPath <json>] [-Preview]` — persiste a **curadoria** de revisores preferidos do usuário em `%LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json` (machine-level), schema v2: metadados `updatedAt` e `migratedFrom` (schema de origem; `1` quando ausente), titulares validados e ordenados por `rank` positivo/único (`rank` omitido é atribuído depois do maior `rank` explícito válido), `targetModelKey`, `backend`, `invokeArgs.backend` e `fallbackChain[]` ordenado `0..N`. Cada fallback é revisor completo (`backend`, `targetModelKey`, `invokeArgs`) e não herda implicitamente do titular; `invokeArgs` é sanitizado (`backend`/`model`/`profile`/`oss`/`localProvider`/`timeoutSec`; **nunca** token/baseURL/header/path). `fallbackPolicy` é restrito ao contrato suportado pelo dispatcher (`ordered-chain`, ativação em `quota`/`timeout`/`error`/`unavailable`, `gateAsk=ask-human`, `gateDeny=stop-or-suggest-manual-alternative`). Bloqueia veto duro, backend inválido, rank inválido/duplicado, política de fallback divergente, divergência `backend` × `invokeArgs.backend`, duplicidade/ciclo na cadeia e escreve com backup + substituição atômica, limpando o `.tmp-*` em falha; `-Preview` valida e mostra a forma normalizada sem gravar.
- `Resolve-LlmDelegatePreferredReviewers.ps1 [-PreferredPath <json>] [-CapabilitiesPath <json>]` — lê curadoria v1 legada ou v2, cruza com `capabilities.json` (`availableInManifest`, `capability`, `diagnostics`, best-effort) e devolve a **composição sugerida** do painel com `schemaVersion`, `updatedAt`, `migratedFrom`, titulares ordenados por `rank` e `fallbackChain` resolvida. Sem arquivo → `hasPreferences=false`. Bloqueia antes do dispatcher hard veto, rank inválido/duplicado, `fallbackPolicy` fora do contrato suportado, ciclo/duplicidade e divergência `invokeArgs.backend != backend`. **Invariante: preferência ≠ autorização** — não consome o manifesto como verdade do gate; o `Resolve-LlmDelegateAuthorization.ps1` reavalia **por revisor** no envio. Self-test `Test-LlmDelegatePreferredReviewersSelfTest.ps1`.
- `Resolve-LlmDelegatePanelDiversity.ps1 -CandidatesJson <json> [-Floor <n>] [-AuthorFamily <fam>]` — avalia (consultivo) o **piso de diversidade** do painel (≥2 famílias distintas, onde a família reflete a fundação estrutural do modelo resolvida via `Get-LlmDelegateTargetFamily`, ex.: `google` para `antigravity/gemini-*`, `anthropic` para `antigravity/claude-*` e `openai` para `openai/*`) a partir dos candidatos + vereditos do gate ou estados pós-despacho. Ignora candidatos com `countsForDiversity=false` (ex.: `skippedAfterSuccess`, `skippedByPolicy`, `notAttempted`) e devolve `insufficientDiversityAfterFallback` quando houve fallback/skip auditável mas as famílias efetivamente respondidas ficaram abaixo do piso. **Não** decide autorização (o gate é soberano). Self-test `Test-LlmDelegatePanelDiversitySelfTest.ps1`.
- `Resolve-LlmDelegatePeerReviewCloseout.ps1 -HadPreferredReviewers <true|false> -ManualReviewerSelection <true|false> [-PreferredReviewersOfferState not_made|offered|accepted|declined|deferred|not_applicable] [-SelectedReviewersJson <json>] [-PreferredReviewerStatesJson <json>] [-DiversityState <state>] [-RoundId <id>] [-VNextState notProduced|pendingResubmission|resubmitted|resubmissionDeclinedByHuman] [-ResubmissionDeclinedBy <quem>] [-ResubmissionDeclineReason <motivo>]` — verifica o **fechamento** da revisão por pares: se não havia `preferred-reviewers.json` e houve escolha manual de revisores, bloqueia o recibo final enquanto a oferta de salvar essa seleção não tiver sido feita; se havia `preferred-reviewers.json`, `-SelectedReviewersJson` é obrigatório e deve conter a lista esperada da rodada; se a seleção manual informou `SelectedReviewersJson`, essa lista também vira contrato de completude. Em ambos os casos, expande titulares + `fallbackChain[]` e bloqueia estado ausente, duplicado ou sem correspondente (identidade por `backend`/`targetModelKey`/`attemptRole`/`fallbackOf`), estado incompleto (`gateAllow`, `dispatched`, `enqueued`) e `notAttempted` como estado primário silencioso. Estados finais de fallback incluem `quota`, `skippedAfterSuccess`, `skippedByPolicy` e `notAttempted`; skips precisam ter `countsForDiversity=false`. `-DiversityState insufficientDiversityAfterFallback` bloqueia o fechamento. **Eixo de estado da vN+1 (Achado A):** `pendingResubmission` bloqueia; `resubmissionDeclinedByHuman` bloqueia sem quem/motivo/`RoundId`; `resubmitted`/`notProduced` são neutros. O recibo ecoa `attemptRole`, `fallbackOf`, `countsForDiversity`, `expectedPreferredReviewerStates`, `preferredReviewerStates` e `vNextState`. Self-test `Test-LlmDelegatePeerReviewCloseoutSelfTest.ps1`.

Harness de disparo do painel (orquestração mecânica — ver `### Harness de disparo do painel`):
- `New-LlmDelegatePeerReviewArtifacts.ps1` — preparador transacional de artefatos para rodada: aceita exatamente um entre `-ManuscriptText` e `-ManuscriptPath`, valida manuscrito não vazio, `RoundId` seguro e `ReviewersJson` com raiz array não vazia e `invokeArgs` objeto, grava `manuscript.md`, `reviewers.json` e `preparation-manifest.json` em UTF-8 sem BOM sob `<TempDir>/<RoundId>` via staging `.prepare-*`, sem chamar dispatcher/adapters. Emite uma linha JSON `xpz-llm-peer-review-artifacts-result`; em falha controlada, `success=false`, `roundStarted=false`, `dispatchStarted=false`, `reviewersDispatched=0` e limpeza do staging. Self-test `Test-NewLlmDelegatePeerReviewArtifactsSelfTest.ps1`.
- `Invoke-LlmDelegatePanelDispatch.ps1 (-ManuscriptPath <arq> | -ManuscriptText <texto>) -ReviewersJson <arq|inline> -PayloadSensitivity <public|kb-sensitive> [-RoundId <id>] [-Cd <dir>] [-ParallelKbRoot <dir>] [-PolicyPath <json>] [-TempDir <dir>] [-OllamaConcurrency <1-16>]` (+ TEST-ONLY `-OpenCodeConfigPath`/`-CodexConfigPath`/`-BackendExeMap`/`-ClaudeCircuitStateRoot`) — harness **MECÂNICO** de despacho+coleta: quando recebe `-ManuscriptText`, prepara artefatos antes de qualquer despacho usando `New-LlmDelegatePeerReviewArtifacts.ps1`; falha de preparação emite `xpz-llm-panel-dispatch-result` próprio com `SchemaVersion=2`, `success=false`, `roundStarted=false`, `dispatchStarted=false` e zero revisores despachados. No fluxo de despacho, valida `invokeArgs.backend` antes do dispatcher; por titular roda o gate (sem autorizar), despacha os `allow` aos adapters `Invoke-*.ps1` em paralelo e registra `attemptRole=primary`, `rank`, `fallbackChain`, `countsForDiversity=true`. Para Claude Code no painel, usa `Invoke-ClaudeCodeAsync.ps1` + sidecar técnico atômico validado; stdout do adapter só é parecer quando `resultAccepted=true`. Depois ativa `fallbackChain` em ordem apenas para estados técnicos emitidos pelo dispatcher (`quota`, `timeout`, `error`, `unavailable`), exceto bloqueio pré-spawn/prompt do circuito de cota do Claude, que é fail-safe e suprime fallback automático sem regra explícita: sucesso do titular gera fallbacks `skippedAfterSuccess`; `gateAsk`/`gateDeny` e bloqueios pré-despacho geram `skippedByPolicy`; fallbacks respondidos contam diversidade, skips não contam; a invocação recursiva do fallback usa o executável PowerShell atual/validado, não `pwsh` cru resolvido pelo `PATH`. `noResponse` é reclassificação pós-hoc do orquestrador para resposta sem parecer utilizável, não gatilho primário do dispatcher. Emite `panel-summary.json` (`Kind=xpz-llm-panel-dispatch-result`, `SchemaVersion=2`, 1 linha de stdout) + `manifest.json` (schema próprio v1) + ledger por estado em `<TempDir>/<RoundId>/`, com contadores v2 de dispatch, processo, sidecar e fallback suprimido. **Não** injeta subagente nativo, **não** calcula piso/closeout/triagem/convergência/autorização — isso é do orquestrador. Self-test `Test-InvokeLlmDelegatePanelDispatchSelfTest.ps1`.

`-ManuscriptText` é reservado para payload curto. Para dossiê/manuscrito grande, use `-ManuscriptPath` para evitar o limite de linha de comando do Windows; origem ausente, origem ambígua e inline grande retornam JSON estruturado (`manuscript-source-missing`, `manuscript-source-ambiguous`, `manuscript-text-too-large`).

**Três artefatos distintos** (não confundir): **política por-KB** (`llm-delegation-policy.json`, autorização durável, raiz da pasta paralela) ≠ **capacidade** (`capabilities.json`, probe do instalado, machine-level) ≠ **preferência** (`preferred-reviewers.json`, curadoria do usuário, machine-level). A curadoria v2 é lista de **titulares** ordenados (`rank`) com `fallbackChain[]` por titular; fallback é substituto auditável, não autorização, não pool opcional e não reduz o piso de diversidade. A curadoria é **ofertada, nunca gravada automaticamente**, em quatro momentos: (a) no 1º uso de revisão por pares sem lista — pergunta *just-in-time* antes de oferecer painel e, depois que o usuário escolher revisores para a rodada, oferta separada para salvar essa seleção; (b) opt-in na `xpz-skills-setup` (setup de máquina); (c) recalibração sob demanda ou por defasagem (`updatedAt`); (d) quando uma seleção manual recorrente divergir da lista existente e o usuário pedir ou confirmar recalibração. Sem lista, o agente não deve presumir assinatura de Gemini/Copilot/Codex cloud nem ignorar `Claude Code`/`opencode`; pergunta ao usuário quais revisores estão disponíveis/preferidos e então roda o gate por destino.

**Quatro eixos na seleção de revisores** (não confundir):

| Eixo | Pergunta | Quem responde |
|---|---|---|
| **Capacidade detectada** | O backend está instalado? Quais modelos aparecem? | `capabilities.json` e sondas locais |
| **Assinatura/login** | O usuário tem conta funcional nesse serviço? | Só o humano ou uma preferência já registrada |
| **Preferência** | O usuário quer usar esse revisor? | `preferred-reviewers.json` ou confirmação explícita |
| **Autorização por KB** | O payload pode ir para esse destino? | `llm-delegation-policy.json` + gate |

Nenhum eixo substitui outro. Um backend instalado sem assinatura/login funcional não é revisor
disponível. Um `allow-external` na política autoriza envio de dados para aquele destino, mas
não escolhe revisor nem prova preferência humana. Um `ask` indica autorização pendente, não
convite obrigatório ao painel. A preferência é humana e nunca deve ser inferida só de
capacidade detectada ou autorização por KB. **Onde cada eixo é mantido (não colapsar num campo
só):** capacidade vem do `capabilities.json`/sondas; assinatura/preferência só do humano ou do
`preferred-reviewers.json`; autorização do gate (`Resolve-LlmDelegateAuthorization.ps1`) por
destino. Nenhum componente decide pelo outro.

**Composição toda-externa em contexto kb-sensitive (Achado B).** A lista preferida é
machine-level e **contexto-agnóstica**: em sessão dentro de pasta paralela de KB (payload
`kb-sensitive`), uma composição preferida **toda-externa** manda conteúdo sensível para fora a
cada revisor. O gate (`Resolve-LlmDelegateAuthorization.ps1`) continua soberano por destino,
mas, **antes** de despachar, o orquestrador deve **avisar** que a composição é toda-externa e
**perguntar** ao humano se quer incluir um revisor **local**. Se **não houver** revisor local
disponível, **parar** e reportar — não escolher externo por inércia/falta de alternativa. Isto
**não veta** envio externo: o humano ainda pode autorizá-lo e o gate por destino continua soberano;
o ponto é **não proceder por inércia** sem o nó humano, não proibir externo autorizado. Descoberta
de local **não** por `Get-Command` como caminho principal (ver `### Protocolo de descoberta e
bootstrap de capacidade`).

**Apresentação do override e camadas permitido≠prudente (reforço do Achado B).** Quando a
composição é toda-externa e **não há revisor local**, o **default declarado** é parar/incluir
local; seguir só com externo é **override consciente**, válido **apenas por autorização textual
explícita** do humano — **ausência de veto não é autorização**. É **proibido** apresentar "seguir
só externo" como opção **neutra co-igual** à de incluir local. O gate de autorização responde
**"é permitido enviar?"**, nunca **"é prudente/recomendado?"**: `allow` autoriza, mas **nunca é,
por si, recomendação**, e a cautela do Achado B é **camada separada que `allow` não dispensa**;
`gate=deny` invalida o override (gate soberano) e `gate=allow` **não substitui** o aviso de risco
abaixo. O default é de **apresentação**, não bloqueio absoluto: o humano pode pré-autorizar
externo numa frente anterior, mas a pré-autorização cobre só o **modo** (o override do Achado B),
**não dispensa** o aviso de risco por destino abaixo (eixos ortogonais) e só vale se precedida de
aviso equivalente. **Não enquadrar** custo/latência do painel inteiro como argumento para
reduzi-lo a subconjunto, salvo pedido explícito do humano (o piso de famílias é mínimo de
validade, não alvo).

**Aviso de risco proporcional antes de envio externo `kb-sensitive`.** Quando o payload é
`kb-sensitive` (definição canônica acima — não redefinir) **e** o destino é externo, antes de
enviar, **na mesma mensagem** do pedido de autorização, o agente **enumera (não rotula)**:
(i) **o quê concretamente sai** — conteúdo enumerado (ex.: "estrutura de transações + ~430
atributos do schema da KB <nome>"), nunca só "kb-sensitive"; (ii) **número + lista nominal** de
destinos, cada destino externo sendo uma **divulgação independente**; (iii) **irreversibilidade
material**: "sem recall sob controle do agente; pode haver retenção/log/treino conforme o
destino" (sem afirmar política específica não verificada). Payload grande: resumir por
**categoria + escopo + amostra** sem perder concretude. Os três pontos cabem na mesma mensagem,
em partes claras, mas **não** comprimidos como "risco + ok?" nem com a resposta sugerida;
**depois o agente para e aguarda**. Consentimento é **por destino**: cada destino externo novo —
inclusive a mesma combinação numa nova invocação ou sessão — dispara novo aviso; **não há
carry-over**. Se parte do payload já saiu, declarar abertamente o que vazou e tratar como novo
aviso. Registro no recibo: `riskNotice{what, destinations[], irreversibility}` e, no override,
`overrideOfAchadoB` (`consciousOverride` quando o humano autoriza externo sem local;
`notApplicable` quando há revisor local em uso), `humanAuthorizer` + `authorizationTextRef`
(a fala que autorizou, não só `by=human`) e `localReviewerStatus`
(`noneAvailable`/`unavailable`/`declined`/`inadequate`). **`consciousOverride` exige
`localReviewerStatus` resolvido** — incompatível com verificação omitida.

Quando `preferred-reviewers.json` existe, ele alimenta a lista preferida de **candidatos** do
painel; não é mera lista opcional para o agente escolher o mínimo, nem autorização para envio.
O orquestrador deve rodar gate por revisor preferido e passar a lista completa de candidatos
preferidos + vereditos para `Resolve-LlmDelegatePanelDiversity.ps1`, não um subconjunto
auto-selecionado. Revisor preferido com `allow` deve ser despachado quando a rodada o alcança,
salvo decisão humana explícita de reduzir o painel; `ask` deve ser apresentado ao humano em lote
quando necessário; `deny`, indisponibilidade, timeout, erro técnico, fallback pulado ou interrupção
por primeiro gap não autorizam omitir os demais em silêncio — cada titular/fallback aplicável recebe
estado no recibo (`responded`, `noResponse`, `timeout`, `quota`, `error`, `gateAsk`, `gateDeny`,
`unavailable`, `skippedAfterSuccess`, `skippedByPolicy`, `notAttempted`,
`skippedByHumanDecision`, `stoppedOnGap`). Estados pulados devem carregar
`countsForDiversity=false`. **`responded` exige parecer utilizável**: um retorno
off-task/sem-parecer/vazio **ou on-task porém substantivamente vazio/raquítico** (terminou em `stop` mas não se posiciona sobre o manuscrito) é **`noResponse`**, não
`responded` — senão o recibo infla o aproveitamento e um off-task pode satisfazer **falsamente** o
piso de "≥2 famílias efetivamente consultadas" (ver [`15-revisao-por-pares.md`](../15-revisao-por-pares.md),
recibo). Preferência continua subordinada à política de papel e
ao gate.

Sem `preferred-reviewers.json`, o agente não deve recomendar composição padrão com Gemini,
Copilot, Codex cloud ou qualquer externo só porque o backend foi detectado ou o gate devolveu
`allow`/`ask`. A pergunta correta é de calibração: quais ferramentas o usuário tem e quer usar.
Quando houver contexto conversacional explícito (por exemplo, o usuário já disse que tem
`Claude Code` e `opencode/Ollama Cloud`, ou que não tem Gemini), esse contexto prevalece sobre
inventário genérico.

### Formato obrigatório sem `preferred-reviewers.json`

Quando `Resolve-LlmDelegatePreferredReviewers.ps1` devolver `hasPreferences=false`, a resposta
ao usuário deve seguir este formato enxuto antes de qualquer envio:

1. Declarar que não há lista de revisores preferidos configurada.
2. Declarar a classe do payload (`public` ou `kb-sensitive`).
3. Perguntar: "Quais ferramentas/modelos você tem e quer usar como revisores?"
4. Citar exemplos de ferramentas em linguagem humana (`Claude Code`, `opencode/Ollama Cloud`,
   `Codex`, `Copilot`, `Gemini`, `Antigravity`, subagente nativo), mas **filtrar** qualquer ferramenta que o
   usuário já tenha descartado na conversa corrente.
5. Declarar que inventário detectado e veredito de autorização são diagnóstico, não preferência:
   o gate será rodado por destino depois da escolha.

É proibido incluir recomendação de composição nesse ponto, em especial frases como "uma opção
objetiva seria", "o caminho mais simples seria" ou "eu sugiro X + Y", quando houver revisor externo
sem preferência registrada. Se for útil citar inventário, rotular como diagnóstico separado e sem
promover itens detectados a opção recomendada. Não usar `allow-external` ou `ask` como argumento
para escolher revisor; autorização decide envio, não preferência.

### Protocolo de descoberta e bootstrap de capacidade

Para descobrir os revisores disponíveis, a ordem é: **(1)** `capabilities.json` (manifesto
sanitizado machine-level) → **(2)** `Resolve-*ModelLocality` por backend → **(3)** `opencode models`
(catálogo opencode). `Get-Command` e sondas de presença (`--version`/`--help`) são **só
diagnóstico auxiliar de último recurso**, nunca prova de assinatura/preferência (não as use como
caminho principal).

**Frescor do `capabilities.json`** é pelo campo **`generatedAt`** (carimbo real do manifesto —
**não** `updatedAt`, que pertence ao `preferred-reviewers.json`). Os três artefatos têm carimbos
distintos: `capabilities.json` = `generatedAt`; snapshot por-KB = `snapshotAt`/`sourceGeneratedAt`;
`preferred-reviewers.json` = `updatedAt`. Manifesto defasado **não** é verdade do gate — é dica
best-effort; ofereça regerar (`Build-LlmDelegateCapabilityManifest.ps1`, opt-in) e use sondas
vivas para desempatar.

**Bootstrap quando `capabilities.json` não existe (máquina virgem)** — não falhar duro, não criar
stub silencioso, não fabricar assinatura: (1) `Resolve-LlmDelegatePreferredReviewers.ps1` devolve
`hasPreferences=false` → perguntar ao usuário (formato acima); (2) resolver capacidade por **sondas
vivas só-para-a-rodada** (`opencode models` + `Resolve-*ModelLocality` do backend escolhido); (3)
**oferecer** gerar o manifesto opt-in — nunca gravá-lo automaticamente. **Fim da cadeia:** se
nenhuma fonte resolver capacidade, **perguntar ao humano/parar** — não inventar composição.
**Fallback de silêncio humano:** se `hasPreferences=false` e o humano **não responde** à pergunta
de calibração, **não** prosseguir para revisor **externo** por heurística; parar (ou só local) e
**registrar o bypass** no recibo/livro-razão. Sem resposta ≠ autorização implícita.

### Persistência após escolha de revisores

Quando não houver `preferred-reviewers.json` e o usuário escolher revisores para a rodada, o
agente deve tratar duas persistências como decisões independentes:

1. **Autorização por KB/projeto**: se o payload for `kb-sensitive`, perguntar se o conteúdo pode
   ser enviado aos destinos externos em `ask`. Se o usuário quiser persistir essa autorização,
   gravar `llm-delegation-policy.json` na raiz da pasta paralela da KB/projeto.
2. **Curadoria de revisores preferidos**: oferecer salvar **a seleção que o usuário já fez** como
   preferência machine-level em `%LOCALAPPDATA%\xpz-llm-delegate\preferred-reviewers.json`, via
   `Set-LlmDelegatePreferredReviewers.ps1`. Essa oferta não bloqueia a rodada: se o usuário recusar
   ou não responder, seguir com a seleção ad-hoc já autorizada para a rodada.

Preferência ≠ autorização. Persistir `llm-delegation-policy.json` autoriza envio para destinos,
mas não escolhe revisores nem prova preferência humana. Persistir `preferred-reviewers.json`
facilita a oferta de painel futuro, mas não substitui o gate por KB/projeto. Se já existir
`preferred-reviewers.json` e o usuário fizer uma escolha manual diferente para uma rodada, tratar
como override ad-hoc: não sobrescrever a lista automaticamente; só oferecer recalibrar se o usuário
pedir, se a divergência parecer recorrente ou se ele confirmar explicitamente.

### Harness de disparo do painel (`Invoke-LlmDelegatePanelDispatch.ps1`)

É o «harness de disparo» previsto em [`15-revisao-por-pares.md`](../15-revisao-por-pares.md) (`## Futuros`): mecaniza o
despacho+coleta que antes era ad-hoc. A fronteira **orquestrador ↔ harness** é estrita:

```
ORQUESTRADOR (fora do harness)                 │  HARNESS (Invoke-LlmDelegatePanelDispatch.ps1)
───────────────────────────────────────────── │ ─────────────────────────────────────────────
injeta subagente nativo                        │  por revisor: modelo efetivo + fail-closeds
piso de diversidade (Resolve-...PanelDiversity)│  gate por revisor (Resolve-...Authorization), sem autorizar
closeout (Resolve-...PeerReviewCloseout)       │  despacho CONCORRENTE dos allow (ForEach-Object -Parallel
triagem do 1º gap / convergência / vN+1        │    -ThrottleLimit 8 + SemaphoreSlim só p/ ollama-cloud/*)
autorização dos `ask` (lote ao humano)         │  classificação ESTRUTURAL do resultado (sem ler a prosa)
recibo humano + livro-razão                    │  ledger por estado + panel-summary.json + manifest.json
reclassificação responded→noResponse (off-task)│  estados emitidos ⊆ {responded,error,quota,unavailable,timeout,
decisão humana sobre redisparo isolado         │    gateAsk,gateDeny,skippedAfterSuccess,
                                                 │    skippedByPolicy,notAttempted}
```

- **Preparação de artefatos:** o harness aceita `-ManuscriptPath` legado ou `-ManuscriptText` para payload curto; para dossiê/manuscrito grande, use `-ManuscriptPath` para evitar o limite de linha de comando do Windows. Com `-ManuscriptText`, antes de qualquer gate/despacho ele chama `New-LlmDelegatePeerReviewArtifacts.ps1`, que publica `manuscript.md`, `reviewers.json` e `preparation-manifest.json` sob `<TempDir>/<RoundId>`; falha nessa etapa termina com resumo estruturado do próprio dispatcher (`roundStarted=false`, `dispatchStarted=false`, zero revisores despachados).
- **Modelo efetivo:** opencode = `invokeArgs.model` ou o `targetModelKey` de **entrada** (o resolvedor opencode exige `-Model`; o gate recebe o mesmo valor); codex = `invokeArgs.model` ou, se ausente, gate **sem** `-Model` → último segmento do `targetModelKey` retornado; claude-code/copilot/gemini/antigravity = `invokeArgs.model` **obrigatório** (ausente → `state=error` fail-closed). `targetModelKey` nulo onde exigido (opencode/codex) → `state=error`.
- **`responded` é MECÂNICO** (texto não-vazio), **não** «parecer válido»: o harness não inspeciona o conteúdo. A reclassificação `responded`→`noResponse` (revisor off-task **ou on-task raquítico**) é **post-hoc do orquestrador** antes do closeout (`15-revisao-por-pares.md`, `## Recibo e livro-razão`) — um off-task **ou parecer raquítico** não soma para o piso.
- **Contenção = trava fail-closed PER-BACKEND (Posição B, decisão de segurança):** as chaves de contenção do backend que as aceita — claude-code `{permissionMode,tools,maxTurns}` (`maxTurns` é **chave morta** desde 2026-07-25: o adapter não tem mais esse parâmetro, e a chave segue recusada só por precaução), opencode `{agent}`, gemini `{approvalMode != plan}`, antigravity `{mode,agent,approvalMode}` — são **recusadas** (`securityBlockedArgs`) e **não** repassadas ao adapter; o mesmo vale, no Claude Code de painel, para chaves internas do adapter assíncrono (`SidecarPath`, `RetentionMode`, `TempDir`, `CircuitStateRoot`, `ClaudeExe`, `MessagePath`/`Message`). O despacho segue com os **defaults seguros** do adapter. **O default seguro do opencode é agora o agente `reviewer-ro` least-privilege** (default escopado + guard fail-closed no adapter — ver «OPENCODE — REVISOR LEAST-PRIVILEGE»); como o painel bloqueia `{agent}`, o revisor opencode **sempre** cai no `reviewer-ro`. O harness **nunca** expõe nem relaxa contenção ou artefatos internos. `approvalMode=plan` (gemini, o default) → `droppedArgs` silencioso; codex/copilot não têm parâmetro de contenção (chave estranha → `droppedArgs`).
- **Claude Code no painel:** o backend não usa o adapter síncrono; usa `Invoke-ClaudeCodeAsync.ps1`, que lê `stream-json`, grava sidecar técnico atômico (`claude-code-async-sidecar`, `SchemaVersion=1`) e só envia ao stdout o texto final aceito quando `resultAccepted=true`. O aceite exige texto não vazio e evento terminal `type=result`, `subtype=success`, `is_error=false`; texto parcial seguido de timeout, encerramento sem terminal válido ou falha de limpeza sensível vira `failureAfterText`/erro, sem stdout aceito. O dispatcher valida o sidecar antes de projetar estados: `completed+true→responded`, `completed+false→error`, `timeout→timeout`, `quota→quota`, `unavailable→unavailable`, `internalError→error`; `cancelled` é inesperado e vira `error`. `panel-summary.json` é `SchemaVersion=2` em sucesso e falhas estruturadas, enquanto `manifest.json` e o preparador mantêm seus schemas próprios. Em `kb-sensitive`, texto bruto parcial não persiste; hashes de stream/stderr são omitidos e o único texto bruto aceito é o `.verdict.txt`.
- **Fontes de `unavailable`:** opencode em `kb-sensitive` → `unavailable` (sem gate/despacho); no Claude Code, um `stderr` que casa o detector **heurístico** de **recusa** por workspace não confiável — avaliado só depois de descartado o ruído de ambiente, que aparece inclusive em execução bem-sucedida — emite `workspace-not-trusted` e é classificado como `unavailable`. Fora do painel, a mensagem canônica preserva o `stderr` bruto e instrui o agente a pedir ao usuário, antes de compartilhar e após remoção de segredos, o texto bruto, `claude --version` e o contexto Desktop/CLI. Assim a próxima ocorrência gera evidência para melhorar o detector sem o agente marcar confiança automaticamente. O bloqueio padrão de leitura fora do cwd pelo agente custom do opencode **está ATIVO** (default `reviewer-ro` sem execução/escrita, `external_directory[*]=deny` para leitura fora do cwd herdado, com exceções internas do opencode observadas nos fixtures 1.17.20); liberar opencode em `kb-sensitive`/pasta paralela + mecanizar cwd-seguro ficou **ADIADO** (`999-ideias-pendentes.md`, eixo de leitura). O recorte `.env` dentro do cwd é **urgente**: o OpenCode 1.17.20 traz `read "*.env" -> ask`, mas o bloco posterior do `reviewer-ro` tende a reabrir `read "*" -> allow`; não usar cwd com `.env` real até a frente ser resolvida. O adapter opencode **não** tem `-Cd` (por isso nunca o recebe; o bloqueio padrão é relativo ao cwd HERDADO); os demais (codex/claude-code/gemini/copilot/antigravity) recebem `-Cd` por precedência (explícito → `ParallelKbRoot` em `kb-sensitive` → cwd em `public`) com **fail-closed** quando `kb-sensitive` e faltam ambos.
- **Fallback de curadoria v2:** depois da rodada dos titulares, o harness ativa `fallbackChain` em ordem para falha técnica/indisponibilidade emitida pelo dispatcher (`quota`, `timeout`, `error`, `unavailable`). Sinais explícitos de falta de saldo/cota/limite (`402`, `Payment Required`, `insufficient coding plan balance`, `quota`, `rate limit`, `weekly usage limit`, `limite de uso`, `sem quota`, `saldo insuficiente`) viram `quota`; a recusa canônica `workspace-not-trusted` vira `unavailable`. No Claude Code, o circuito durável de cota bloqueia antes de spawn/prompt por chave-base (não por `rateLimitType`) e varre variantes da chave; `state-json-invalid` é evidência por variante e não é apagado automaticamente. Bloqueio pré-spawn/prompt suprime fallback automático sem regra explícita (`fallbackSuppressedReason=pre-dispatch-block-not-fallback-safe`). Sucesso do titular gera `skippedAfterSuccess`; `gateAsk`, `gateDeny` e bloqueio de validação pré-despacho geram `skippedByPolicy`. Fallback respondido herda a regra de parecer utilizável do orquestrador e pode contar diversidade; skips e `notAttempted` sempre têm `countsForDiversity=false`. `noResponse` fica reservado à reclassificação pós-hoc do orquestrador quando houve texto sem parecer utilizável; não é gatilho primário do dispatcher.
- **Recibo humano de `quota`:** o estado `quota` é **categoria operacional**, não diagnóstico de
  periodicidade. No recibo final, escrever "bateu limite de uso" ou "retornou limite de uso" e
  preservar a evidência técnica em arquivo/ledger. Não converter mensagens do CLI em "mensal",
  "semanal" ou "janela de 5 horas" por inferência; quando o tipo/período não estiver comprovado,
  declarar explicitamente `tipo/período não determinado`.
- **single-flight DIFERIDO (decisão II-b):** uma falha concorrente de `ollama-cloud/*` vira `error` + ledger cru + `concurrencySaturationWarning` por stderr; a recuperação automática fora da `fallbackChain` depende do **contrato de saída tipado dos adapters** (frente 999) — o orquestrador só pode redisparar isolado com decisão humana explícita.
- **Disciplina de stdout:** o harness é processo filho; `panel-summary.json` é a **única** linha de stdout (`[Console]::Out`); todo texto humano sai por `[Console]::Error` (lição do `Sync-GeneXusXpzToXml`: `Write-Host`/`Write-Warning`/`Write-Information` **vazam** para o stdout capturado). O **chamador captura stdout e stderr separadamente**; redirecionar stderr→stdout corromperia o JSON.
- **NÃO generalizar status tipado para todos os adapters por esta frente:** o contrato tipado foi fechado apenas para Claude Code no painel. A refatoração dos demais adapters continua sendo frente própria no 999.

## Forma canônica de invocação dos adapters

A allowlist do harness (Claude Code, Codex, OpenCode, Cursor) casa comandos **atômicos**, não comandos compostos. Cada variante de forma exige uma entrada de allowlist distinta — deriva que, além de incomodar, gera prompt de autorização desnecessário quando o match literal falha.

**Princípio:** comando **atômico**, prompt sempre por **`-MessagePath <arquivo>`**, zero aspas embutidas para o prompt. A raiz do atrito é prompt inline + múltiplos segmentos entre aspas no mesmo comando quebrando o match literal da allowlist — `-MessagePath` + comando atômico elimina isso.

**Forma por ferramenta (cada uma casa a sua família de entrada na allowlist):**

- Pela ferramenta **Bash** (forma primária), com `cwd` na raiz do repo, path **relativo**:
  `pwsh -NoProfile -File scripts/<Adapter>.ps1 -MessagePath <arquivo> [demais parâmetros do adapter]`
  — casa a entrada `Bash(pwsh -NoProfile -File scripts/*)`.
- Pela ferramenta **PowerShell** (fallback), path **absoluto**:
  `& "<abs>\scripts\<Adapter>.ps1" -MessagePath <arquivo> [demais parâmetros do adapter]`
  — casa as entradas `PowerShell(& "<repo>\scripts\*" *)`.

> **Importante (cobertura por ferramenta):** o path **relativo** é a forma coberta **via Bash**; o fallback **PowerShell** é coberto na forma de path **absoluto**. **Não** existe entrada ampla cobrindo path relativo via PowerShell — então não use `& "scripts\<Adapter>.ps1"` (relativo, via PowerShell) como forma canônica. Manter cada forma na sua ferramenta evita recair em variação não coberta.

**Síncrono vs assíncrono (parâmetros próprios do adapter):**

- Síncrono `Invoke-*`: `-MessagePath <arquivo> [-Model <m>] [-TimeoutSec <s>]`.
- Assíncrono `Start-*Job` (os existentes: opencode, Codex, Claude Code — Gemini/Copilot/Antigravity **não** têm job): `-MessagePath <arquivo> [-Model <m>] [-NoWatcher] [-TempDir <dir>] [-KeepDays <n>]` — `-TimeoutSec` **não** se aplica aos jobs. A regra `-MessagePath`/atômico vale igual para os dois.

**Arquivo de `-MessagePath`:** preferir caminho **sem espaços**, sob o `Temp` do usuário (`%LOCALAPPDATA%\Temp`, já allowlistado para escrita) — fecha o ciclo escrita+leitura sem prompt; se o caminho exigir aspas, um **único** par e nada de prompt inline.

**`-Cd` (quando o adapter suportar):** Codex, Claude Code, Copilot, Gemini e Antigravity aceitam `-Cd`; **opencode NÃO tem** `-Cd`. Quando suportado, omitir `-Cd` se o `cwd` já é a raiz; preferir apontar o diretório pelo parâmetro `workdir` da própria ferramenta em vez de passar `-Cd` no comando; **nunca** `-Cd` como segundo segmento entre aspas (foi exatamente um `-Cd "<path>"` somado a um prompt inline entre aspas que produziu o caso real de 2026-06-21, ver abaixo).

**Ressalva ~32KB (cross-reference):** `-MessagePath` elimina a substituição de comando inline (`(Get-Content)` / `"$(cat ...)"`) **no chamador** em **todos** os adapters; mas só os **stdin-based** (Codex, opencode, Claude Code) também movem o prompt para **fora** do `argv` (escapam do teto). Nos **argument-based** (Gemini/Copilot/Antigravity) o adapter lê o arquivo e repassa o prompt no `argv` interno — o teto ~32KB permanece, com o guard fail-closed de 30000 chars ativo. `-MessagePath` não levanta o teto nesses três. Ver a seção de limite no `SKILL.md` para detalhe.

**O caso real que motivou o item:** em 2026-06-21, `Invoke-Codex.ps1` foi chamado como:
```powershell
& "<abs>\Invoke-Codex.ps1" "<prompt>" -Model gpt-5.5 -Cd "<abs>" -TimeoutSec 420
```
...e **promptou** apesar de existirem entradas `PowerShell(& "…\scripts\*")`. A causa foi **as aspas embutidas** — prompt inline como segmento posicional + `-Cd "<path>"` no mesmo comando — quebrando o match literal da allowlist. Foi uma chamada da **mesma família PowerShell** contra entradas PowerShell existentes, **não** um descasamento de ferramenta. A forma canônica (prompt por `-MessagePath`, comando atômico, zero aspas embutidas) corrige exatamente essa causa. A regra "manter cada forma na sua ferramenta" é um cuidado preventivo adicional.

**Nota não-normativa de allowlist:** como referência para quem configura uma máquina nova, o padrão de entrada ampla que cobre a forma canônica é:
- `Bash(pwsh -NoProfile -File scripts/*)`
- `PowerShell(& "<repo>\scripts\*" *)`

Esses padrões são **exemplo informativo** — não são arquivo versionado e não fazem parte do setup automático.

## MANUSCRITO/PROMPT PARA REVISORES

Ao montar o manuscrito/prompt de revisão por pares, não embutir como fatos conclusões que a
revisão deve validar. Descrever evidências observadas e hipóteses separadamente. Exemplos de
redação a evitar quando ainda são a matéria da revisão: "identificador universal", "sequencial
autogerado" ou "padrão da KB" sem fonte normativa ou validação anterior. Preferir formulações
auditáveis, como "o XML observado tem `AUTONUMBER=True`", "há N usos encontrados" e "a hipótese
do plano é que a descrição curta deva comunicar X". O revisor recebe o manuscrito para confirmar
ou refutar, não para ratificar conclusão já embalada como verdade.

**Blinde o papel do revisor.** O prompt vai a backends **agênticos** (opencode, Codex, Claude Code)
que podem ler o manuscrito como ordem para **executar** o plano ou **conduzir eles mesmos** uma
revisão por pares — risco agudo quando o manuscrito é autorreferente (a própria metodologia).
Instrua de forma imperativa que o destinatário é **um revisor**: deve **emitir o próprio parecer**
(concorda/revisa/rejeita, com justificativa e gaps priorizados) e **não** executar, montar painel,
delegar nem assumir o papel do orquestrador. Um retorno que assume a tarefa em vez de opinar
registra-se como `noResponse`, nunca `responded`.

`PATH RESOLUTION`: este `SKILL.md` fica numa subpasta sob a raiz; os scripts ficam em
`../scripts/` relativos a esta pasta. Resolver caminhos a partir da raiz do repositório.

## WORKFLOW (uma delegação)

1. Confirmar o **gatilho humano**: o usuário pediu, ou aprovou explicitamente uma sugestão
   de delegar. Sem isso, não delegar.
2. Classificar a tarefa: é delegável (mecânica/segunda-opinião) ou é juízo GeneXus? Se for
   juízo, **não delegar** (ver `## O QUE NÃO DELEGAR`).
3. Classificar o payload: `public` (texto do repo público, molde sanitizado) ou
   `kb-sensitive` (conteúdo de pasta paralela). Na dúvida, tratar como `kb-sensitive`.
3a. Em **revisão por pares**, antes de escolher backends, resolver `preferred-reviewers.json`.
    Se não houver lista (`hasPreferences=false`), perguntar ao usuário quais ferramentas/modelos
    ele tem disponíveis ou prefere (`Claude Code`, `opencode/Ollama Cloud`, `Codex`, `Copilot`,
    `Gemini`, `Antigravity`, subagente nativo). A pergunta é de preferência e assinatura/login, não de
    inventário: não substituir por enumeração técnica de providers nem por menu de tudo que está
    instalado. Backend detectado sem preferência deve ser apresentado como "detectado; confirme se
    quer usar"; não sugerir composição padrão com externo sem preferência confirmada. Seguir o
    formato obrigatório da seção acima. Depois que o usuário escolher revisores para a rodada,
    oferecer salvar **essa seleção já feita** em `preferred-reviewers.json`, separadamente da
    autorização por KB; não bloquear a rodada se o usuário não quiser salvar curadoria. Subagente
    nativo pode entrar no painel, mas conta como a família do orquestrador e não substitui uma
    família externa para cumprir o piso.
3b. Em **revisão por pares**, antes de emitir recibo final ou dizer que a rodada foi concluída,
    rodar `Resolve-LlmDelegatePeerReviewCloseout.ps1` com o estado real da rodada. Se
    `closeoutReady=false`, apresentar `requiredUserPrompt` ao usuário e não encerrar a rodada
    como revisão por pares até a oferta ser feita ou registrada como aceita, recusada ou adiada.
    Quando `preferred-reviewers.json` já existia, passar `-PreferredReviewerStatesJson` com o
    estado final de cada preferido da rodada; não usar o piso mínimo (≥2 famílias) como critério
    para omitir preferidos despacháveis sem estado auditável.
    **Eixo da vN+1 (Achado A):** no momento em que você **autora** a versão consolidada (vN+1),
    passe `-VNextState pendingResubmission` — o closeout **bloqueia** o fechamento até a vN+1 ser
    `resubmitted` (re-submetida ao painel) ou o humano declinar de forma auditável
    (`-VNextState resubmissionDeclinedByHuman -ResubmissionDeclinedBy <quem> -ResubmissionDeclineReason <motivo> -RoundId <rodada>`).
    A transição só acontece por **nova invocação** do closeout com o novo `-VNextState`; o `vNextState`
    entra no recibo mínimo (ver [`15-revisao-por-pares.md`](../15-revisao-por-pares.md)).
4. Escolher o backend e o modelo. Rodar `Resolve-LlmDelegateAuthorization.ps1` com modelo +
   sensibilidade + `-Backend opencode|codex|claude-code|copilot|gemini|antigravity` (em pasta paralela, passar
   `-ParallelKbRoot <raiz>` para descobrir a política pelo nome canônico com fallback ao legado, ou
   `-PolicyPath` para um caminho explícito; com `policyNameStatus` `legacy`/`both`, avisar o usuário
   que o nome legado está em uso e oferecer renomear).
   - `allow` → seguir; **anunciar o destino** ao usuário (use `targetModelKey` do resultado).
   - `deny` → não enviar; informar o motivo e oferecer alternativa local.
   - `ask` → pedir autorização explícita ao usuário; se autorizado, oferecer **persistir** a
     escolha no `llm-delegation-policy.json` (liberação durável; nome legado
     `opencode-delegation-policy.json` ainda aceito).
5. Invocar o adapter do backend escolhido: opencode (`Invoke-OpenCode.ps1` / `Start-OpenCodeJob.ps1`),
   codex (`Invoke-Codex.ps1` / `Start-CodexJob.ps1`), Claude Code (`Invoke-ClaudeCode.ps1`,
   `Invoke-ClaudeCodeAsync.ps1` no painel, ou `Start-ClaudeCodeJob.ps1`), Copilot
   (`Invoke-Copilot.ps1`) ou Gemini (`Invoke-Gemini.ps1`) — síncrono (curto), adapter tipado do
   painel quando aplicável, ou assíncrono longo quando o backend tiver job.
6. **Validar a saída** com o agente forte antes de usá-la. Não confiar em timestamps/fatos
   reportados pelo subagente.

## LIMITE CONHECIDO — OPENCODE COM MODELO LOCAL PEQUENO

O backend opencode é **agêntico**: cada chamada carrega system prompt + schemas de todas as
ferramentas + o que estiver em `instructions` da config do opencode (ex.: um `AGENTS.md` global
extenso). Esse prompt por chamada pode passar de ~16k tokens.

Falhas do CLI antes da chamada ao modelo com mensagens de SQLite/`PRAGMA`/`CREATE TABLE` indicam
estado local corrompido do opencode, não erro do adapter. Recuperação operacional conservadora:
fechar o OpenCode desktop e renomear `opencode.db*` na pasta de dados do opencode para backup,
preservando arquivos de autenticação/configuração.

Consequência em GPU de pouca VRAM (medido empiricamente em RX 580 8 GB, Vulkan, com placement
100% GPU e sem spill para RAM/compartilhada):

- modelo local pequeno com janela pequena (8k/16k) → o prompt enche a janela e a resposta sai
  truncada (`reason=length`, ~1 token de saída);
- janela grande (32k) → o prompt cabe, mas o processamento na GPU fica lento demais e estoura o
  timeout.

Ou seja: para modelo **local pequeno**, o gargalo não é VRAM nem janela — é o **tamanho do prompt
do opencode**. Conclusão operacional: usar o backend opencode com modelos **cloud** (janela grande,
validado) e reservar **modelo local pequeno** para o backend **one-shot** futuro (`llm`/`mods`),
que envia só o prompt — sem schemas de ferramentas nem `instructions` — então o modelo local
responde rápido e cabe folgado na VRAM.

**Detecção de truncamento (Achado D).** Tanto o caminho síncrono (`Invoke-OpenCode.ps1` via
`OpenCodeStreamSupport.ps1`) quanto o assíncrono (`Watch-OpenCodeJob.ps1`) classificam a conclusão
pelo `reason` do **último** evento `step_finish` (`Get-OpenCodeCompletionSignal` /
`Get-OpenCodeCompletionVerdict`): **só `reason='stop'` é sucesso**; qualquer outro valor
(`length`, `tool-calls`, `content_filter`, `unknown`, `max_tokens`, …) ou a **ausência** de
`step_finish`/`reason` vira bloqueio (`truncado` / `sem-conclusao`), em vez de devolver o
preâmbulo como se fosse a resposta. O erro explícito do stream continua tendo prioridade. Esse
mapeamento de vocabulário foi validado contra o opencode em uso nesta máquina (2026-06); se uma
versão futura do opencode **renomear** `stop` (ex.: `done`/`finished`), toda chamada legítima
viraria `truncado` — nesse caso, revisar `Get-OpenCodeCompletionVerdict` e este registro. Use
`-Raw` (síncrono) ou o campo `finishReason` do `result.json` (assíncrono) para diagnóstico.

**Retry-once opt-in (`-MaxAttempts`, síncrono).** A truncagem por `tool-calls` observada em vozes
"coder" do ollama-cloud (`kimi-k2.7-code`, `minimax-m3`) é **intermitente e rara** — não é cota, não
é timeout, não é orçamento de passos, não é propriedade fixa do modelo; a hipótese sobrevivente é
**não-determinismo de cauda** (o modelo encerra logo após um tool-call sem o `stop` final). Como some
na repetição, `Invoke-OpenCode.ps1` aceita `-MaxAttempts <1-3>` (default **1** = comportamento
histórico, sem re-tentativa): com 2+, re-despacha **apenas** veredito `truncated`/`no-completion`.
Precedência por tentativa: **(1)** timeout/exit≠0/erro-explícito-de-stream → terminal (lançam antes
do veredito); **(2)** veredito de conclusão — `ok` retorna, **`empty` (stop limpo sem texto) é
terminal**, só `{truncated,no-completion}` são re-tentáveis; **(3)** ao **decidir re-tentar** um
`truncated`/`no-completion`, checa **429 na janela da tentativa** (`Get-OpenCodeUsageLimitError`,
`$startedAt` reatribuído por iteração) → se houver, **terminal** (não re-tentar, para não re-queimar a
cota). Sem re-tentativa pendente (`-MaxAttempts 1` — o default — ou última tentativa), o veredito
reportado é o de conclusão (ex.: `truncado`); a checagem de 429 do passo (3) não se aplica. `-TimeoutSec` é **por tentativa** (com `-MaxAttempts 2` o tempo de
parede pode dobrar); `-Raw` **não** re-tenta (devolve a 1ª execução); cada re-tentativa emite em stderr
`OPENCODE_RETRY: attempt=N status=… reason=…`. **Síncrono-only** — o assíncrono (`Start-`/`Watch-OpenCodeJob`)
sofre a mesma truncagem mas **não** tem retry (follow-up em `999-ideias-pendentes.md`). Guard:
`scripts/Test-OpenCodeRetrySelfTest.ps1` (token `OK: Test-OpenCodeRetrySelfTest.ps1`; fake-exe com
contador em arquivo + seam `XDG_DATA_HOME` para o caso 429).

**LIMITE CONHECIDO — `ok` não garante parecer útil (sem piso de substância).** O veredito `ok` exige
só `reason='stop'` + texto não-vazio — sem piso de tamanho/qualidade. Observado (2026-06-23):
`minimax-m3` terminou `stop` com 414 chars (vs. ~16k de uma run cheia, mesmo pedido) → `ok`, **não**
re-tentado pelo `-MaxAttempts` (só cobre `truncated`/`no-completion`) e contado como `responded` no
painel. Distinto do truncamento (Achado D) e do `empty` (stop sem texto): aqui "termina" limpo mas
raquítico. Ver «`responded` exige parecer utilizável» (estados de revisor preferido, acima) e
«`responded` é MECÂNICO». A **única mitigação atual** é a reclassificação post-hoc (manual) do
orquestrador (`15-revisao-por-pares.md`, §Papéis parágrafo «Recibo mínimo obrigatório» — *dono* — /
§Recibo e livro-razão — *restatement*), que cobre tanto off-task quanto parecer raquítico. **Critério:
descolamento do `ok`/`responded` da matéria do manuscrito, NÃO contagem de chars (ver `15`).** **Não**
é piso automático — piso/heurística segue **frente aberta** no `999`.

**Cobertura por adapter (varredura confirmatória, escopo declarado).** A detecção por `reason`
acima é **opencode-only** — é fenômeno do **streaming agêntico** do opencode. Nenhum dos demais
adapters expõe equivalente a `reason=length`, que é o sinal que importa para truncamento. **Ressalva
(2026-07-25):** o Claude Code **assíncrono** tem, sim, um sinal terminal estruturado — o evento final
`type=result` com `subtype` (`success`, `error_max_turns`, …) e `is_error`, medido em `claude 2.1.220`
e **consumido** desde então pelo `Watch-ClaudeCodeJob.ps1` para classificar **falha** (ver o backend
Claude Code acima). Ele **não** cobre corte por limite de tokens, então o limite residual abaixo
continua de pé; o que caducou foi a formulação absoluta «nenhum tem sinal de finish-reason». Uma
**varredura confirmatória** (inspeção
**estática do código-fonte** dos adapters em 2026-06-20 — contrato de extração, **não** teste de
truncamento ao vivo) mostrou: **Codex** (`output-last-message`, arquivo dedicado), **Claude Code**
(stdout final), **Gemini** (`$json.response`) e **Antigravity** (`$json.response`) entregam a **mensagem final canônica** por **campo
terminal nomeado**; **Copilot** isola a final por **last-wins de stream** (último `assistant.message`
vence) + `result.exitCode`, mecanismo **diferente** mas com a mesma proteção prática. Critério
positivo: o adapter entrega a mensagem final canônica, **não** o stream/preâmbulo. **Resultado:**
o vazamento do Achado D (preâmbulo virar parecer) **não se reproduz** nos quatro não-opencode;
resta um **limite conhecido residual** — truncamento por **limite de tokens** **não é detectado**
fora do opencode (nenhum tem equivalente a `reason=length`). Esse limite (paridade de detecção de
truncamento nos adapters stdin/JSONL), o **risco residual do last-wins do Copilot** (se o agente
reescrever a resposta e a "última" `assistant.message` não for a final canônica) e um **plano de
teste empírico** ficam registrados em `999-ideias-pendentes.md` como frente futura.

## LIMITE CONHECIDO — ANTI-HANG DE STDIN HEADLESS (DOIS REGIMES)

Chamado de uma **shell headless sem TTY** (a ferramenta Bash/PowerShell de um agente), um CLI
agêntico **trava** lendo o stdin herdado (um pipe aberto que nunca dá EOF): medido — o opencode
pendurava por minutos. Todos os adapters dão **EOF** ao CLI, por um de dois regimes:

- **stdin-based** (`Invoke-OpenCode`/`Start-OpenCodeJob`, `Invoke-Codex`/`Start-CodexJob`,
  `Invoke-ClaudeCode`/`Start-ClaudeCodeJob`): entregam o prompt **por stdin** via
  `Start-Process -RedirectStandardInput <arquivo>`; o **fim do arquivo dá o EOF**. O prompt fica
  **fora do argv** (ver a seção do limite ~32KB) e vem de `-Message` (inline) ou `-MessagePath`
  (arquivo, exclusivos) — `-MessagePath` muda só a **origem** do texto, não o transporte por stdin. O opencode lê o prompt do stdin quando o
  argumento posicional de `run` é **omitido** (verificado no opencode em uso nesta máquina, 2026-06).
- **argument-based** (`Invoke-Gemini`, `Invoke-Copilot`, `Invoke-Antigravity`): passam o prompt como **argumento** e
  **fecham o stdin** no runner com `$null | & ([string]$req.exe) @args` (`$null` = EOF puro, sem
  bytes, **não** `'' |`, que mandaria uma linha vazia antes do EOF). O runner é invocado por
  `pwsh -File` (que **não** lê stdin); migrar para `pwsh -Command` reintroduziria o hang.

- **Ressalva de evolução**: para os **argument-based**, se o CLI ganhar um modo `--stdin`/pipe de
  entrada, o stdin fechado quebraria **silenciosamente**; os self-tests de contrato de flags
  (`Test-GeminiCliSupportSelfTest`, `Test-CopilotCliSupportSelfTest`, `Test-AntigravityCliSupportSelfTest`) acusam flag nova no help —
  revisar quando ocorrer. Para os **stdin-based**, a dependência inversa: se o CLI deixar de aceitar
  o prompt por stdin (ex.: voltar a exigir o posicional), o adapter precisaria retornar ao argv —
  vigiar no upgrade do opencode (a forma `run` sem posicional + stdin está fixada no comentário do
  adapter).
- **Guard**: `scripts/Test-LlmDelegateStdinHandlingSelfTest.ps1` (sentinela `OK: Test-LlmDelegateStdinHandlingSelfTest.ps1`)
  prova o EOF (fake-exe que bloqueia em stdin aberto e sai 7 ao receber EOF), trava a regressão
  estaticamente (stdin-based usam `-RedirectStandardInput` e **não** fecham com `$null | &`;
  argument-based fecham com `$null | &`) e prova o opencode stdin-based com prompt > 32KB via
  fake-exe injetado (`-OpenCodeExe`).
- **Sondas `--version`/`--help`** dos `*CliSupport`: medidas em headless (não leem stdin, **não
  penduram**), portanto **não** alteradas.

## LIMITE CONHECIDO — `StandardOutputEncoding` E LINHA DE COMANDO (~32KB)

**Sintoma observado** (relato, não-determinístico): pela ferramenta PowerShell de um agente, "em
algumas sessões", uma chamada de adapter **argument-based** falhava com exit 1 e
`Program '<cli>.exe' failed to run: StandardOutputEncoding is only supported when standard output
is redirected`. Pela ferramenta Bash (stdout = pipe) funcionava.

- **Causa não confirmada.** A hipótese é o host do chamador ter stdout **não-redirecionado**
  (console-handle) e/ou o prompt grande por argv; **não** reproduzido de forma determinística
  (medições mostraram `[Console]::IsOutputRedirected=True` nas sessões testadas, em que o erro
  **não** ocorre). Tratar como **sintoma observado**, não diagnóstico fechado.
- **Workaround** para os adapters **argument-based** (`Invoke-Gemini`, `Invoke-Copilot`, `Invoke-Antigravity`): invocá-los
  pela ferramenta **Bash** (ou shell com stdout em **pipe**) e manter o prompt **enxuto**.
- **opencode resolvido por desenho.** `Invoke-OpenCode` usa `Start-Process -RedirectStandardOutput/-Error`
  direto; `Start-OpenCodeJob` usa um runner mínimo, mas o runner também chama `Start-Process` com
  redireção explícita e prompt por stdin (`<GUID>.stdin.txt`), fora do argv. Assim, o opencode não
  depende de `& exe 1> arquivo` com o prompt na linha de comando e é **host-agnóstico** quanto a esse
  sintoma, qualquer que seja a causa.

**Limite de ~32KB de linha de comando do Windows** (reproduzível): passar o prompt como
**argumento** estoura `Argument list too long` acima de ~32767 caracteres.
- **argument-based** (`Invoke-Gemini`, `Invoke-Copilot`, `Invoke-Antigravity`): o prompt vai no **argv** via runner → o
  teto ~32KB **persiste**. Os três ganharam `-MessagePath` (lê o prompt de arquivo e elimina o
  `(Get-Content)`/`"$(cat ...)"` inline do chamador), mas ele **não** levanta o teto; um **guard de
  tamanho fail-closed** (`$MaxArgvPromptChars = 30000`, **heurístico em chars** — UTF-16 code units,
  margem deliberada conservadora sob o teto físico ~32767 do command line, não um limite em bytes)
  recusa prompts grandes com `BLOCK` claro antes do estouro de `Argument list too long`. A migração
  real para **stdin** segue como follow-up (bloqueada por falta de assinatura para validar
  empiricamente) — `999-ideias-pendentes.md`.
- **stdin-based** (opencode, Codex, ClaudeCode — síncronos e jobs): o prompt vai por **stdin/arquivo**,
  não pelo argv — sem o limite. Use `-MessagePath <arquivo>` (ou `-Message`): além de evitar o limite,
  dispensa `"$(cat ...)"`/`(Get-Content)` na linha de comando do chamador (sem substituição de comando
  = sem prompt de autorização desnecessário no harness).

## LIMITE CONHECIDO — COTA/LIMITE DE USO DO PROVIDER (HTTP 429) PARECE TIMEOUT

Quando a conta do provider estoura a cota (ex.: **ollama-cloud weekly usage limit**, HTTP **429**),
o opencode **retenta em silêncio**: stdout/stderr ficam **vazios** (confirmado até 180s) e o 429 é
gravado **apenas no log próprio** do opencode (`~/.local/share/opencode/log/<ts>.log`; respeita
`XDG_DATA_HOME`). Sem tratamento, a chamada só estoura por `-TimeoutSec` e **parece timeout técnico**.

- **`Invoke-OpenCode.ps1` diagnostica isso:** no branch de timeout, `Get-OpenCodeUsageLimitError`
  (em `OpenCodeStreamSupport.ps1`, dot-source; `-LogDir` para fixture) varre o log da janela do
  processo por `"statusCode":429` + a mensagem de limite e lança um erro **claro** ("limite de uso
  do provider (HTTP 429)… aguardar o reset do ciclo"), em vez de "excedeu Xs". Self-test
  `Test-OpenCodeUsageLimitDetectionSelfTest.ps1` (token `OPENCODE_USAGE_LIMIT_DETECTION_SELFTEST_OK`).
- **Não adianta redisparar nem aumentar o timeout** — só reseta no ciclo de uso (semanal no
  ollama-cloud) ou com upgrade/extra usage. Outras famílias (Codex/Claude Code nativo/nvidia) **não**
  são afetadas pela cota do ollama-cloud.
- **Follow-up:** estender a detecção aos jobs opencode (`Start-`/`Watch-OpenCodeJob`) e aos demais
  backends — `999-ideias-pendentes.md`.

## OPENCODE — REVISOR LEAST-PRIVILEGE "SEM EXECUÇÃO/ESCRITA" (ATIVO)

**Contexto histórico** (opencode 2026-06): em `opencode run` headless (sem TTY), as permissões de
ferramenta do agente default `build` — **e do `--agent plan`** — eram **auto-aprovadas**: o modelo
executava `bash`/`edit` **sem gate interativo**. Ao despachar um revisor opencode com o agente
default, o painel concedia **execução de comandos arbitrários e escrita** na máquina. **Incidente
concreto (2026-06-24, pré-push reforçada):** um revisor opencode (`kimi-k2.7-code`, agente default)
**editou** um `.md` do repo (corrigiu um typo) em vez de só reportar — o eixo `edit` **se
materializou**.

**Correção ATIVA** (design congelado [`opencode-reviewer-ro-least-privilege-design.md`](../opencode-reviewer-ro-least-privilege-design.md),
escopo D-min). Os adapters `Invoke-OpenCode.ps1`/`Start-OpenCodeJob.ps1` aplicam a postura de
segurança no **próprio adapter**, de forma inseparável (nunca "default sem guard"):

- **Default `-Agent reviewer-ro` escopado ao caminho revisor.** Sem `-Agent` explícito, o agente
  efetivo é `reviewer-ro` (forma `permission` com default-deny curinga `"*": deny` + allowlist
  `{read, grep, glob, list}`; `edit`/`bash`/`webfetch`/`websearch`/`task` negados). O painel bloqueia
  a chave `agent` → o revisor **sempre** cai no `reviewer-ro`. `-Agent <x>` **explícito com `x ≠
  reviewer-ro`** = opt-out consciente (uso agêntico fora do painel; o chamador assume a postura de
  segurança), mas o pré-check confirma que `<x>` **resolve** (evita o fallback silencioso ao `build`
  full-access). `-Agent reviewer-ro` **explícito** não é opt-out: recai no **enforce** completo, igual
  ao default (o caminho revisor é reconhecido por `$Agent -eq 'reviewer-ro'`, seja default ou explícito).
- **Guard fail-closed (pré-check ANTES do run/spawn).** Estático (frontmatter do reviewer-ro) +
  `opencode agent list` confirmando o **allow-set resolvido EXATAMENTE `{read, grep, glob, list}`**
  (trava divergência por ausência E por excesso — ex.: `bash` reaparecendo por regra tardia da
  global) + versão do opencode testada. O `agent list` faz **retry curto** (até 3 tentativas com
  pausa breve) para tolerar a falha transitória de SQLite antes de desistir. Qualquer falha ⇒
  **BLOCK** com o motivo no recibo (`static`/`version`/`allowset`/`agentlist`-transitório-SQLite
  `PRAGMA wal_checkpoint`). Pós-check (defesa-em-profundidade, não a barreira): varre o stderr pelo
  warning de fallback silencioso. Em `version`, o agente consumidor **não deve só reportar e parar**:
  deve rodar `scripts/Test-OpenCodeReviewerRoInstalledCompatibility.ps1 -AsJson` para separar
  configuração estrutural quebrada de versão nova ainda sem fixtures. Se o status for
  `needsFixtureRecapture`, o próximo passo é recapturar os fixtures empíricos da versão instalada
  antes de promover o `reviewer-ro`; se for `blocked`, corrigir o motivo estrutural.
  Provisionamento: `.opencode/agent/reviewer-ro.md` (project-local versionado) +
  `scripts/Install-OpenCodeReviewerRoAgent.ps1` (global, dono desta skill). Gate de processo/CI:
  `scripts/Test-OpenCodeReviewerRoSelfTest.ps1` (`OPENCODE_REVIEWER_RO_SELFTEST_OK`) e
  `scripts/Test-OpenCodeCliSupportSelfTest.ps1` para a descoberta do CLI.
- **Eixo de LEITURA — premissa INVERTIDA (medido em opencode 1.17.20).** A doc anterior afirmava que a
  tool `read` lê **qualquer arquivo** da máquina; a **medição refuta**: o opencode tem a dimensão
  nativa `external_directory` (base `ask`, auto-rejeitada em `opencode run` headless) que gateia
  leituras **fora** do workspace do cwd. O reviewer-ro fixa `external_directory: deny` explícito → o
  padrão `external_directory[*]` fica bloqueado independente do modo; fixtures 1.17.20
  ainda mostram exceções `allow` para diretórios internos do opencode, então isso não deve ser
  descrito como proibição absoluta de todo path externo específico. O D-min fecha
  execução/escrita e as **ferramentas** de rede (`webfetch`/`websearch`); **não** fecha o canal do
  próprio parecer ao provider (residual aceito em `public`, inerente a qualquer revisor externo).
- **cwd-seguro é OPERACIONAL (nota de operador).** O D-min **não** mecaniza "o cwd é seguro": o
  bloqueio padrão é relativo ao cwd HERDADO (o adapter opencode não recebe `-Cd`), mas **quem dispara** é
  responsável por escolher um cwd sem segredos não-versionados. Se o cwd contiver `.env` local,
  logs ou cache com segredos, o revisor pode lê-los; iscas de self-test não substituem revisar
  segredos reais no diretório. Em 1.17.20 há proteção nativa `read "*.env" -> ask`, mas o bloco
  posterior do `reviewer-ro` tende a anulá-la com `read "*" -> allow`; esse recorte é alta
  prioridade no `999`. Mecanizar cwd-seguro + liberar opencode em `kb-sensitive`/pasta paralela
  ficou **ADIADO** (`999-ideias-pendentes.md`, entrada do eixo de leitura).
- **O gate de confidencialidade continua ortogonal.** `Resolve-LlmDelegateAuthorization.ps1` governa
  **se o dado sai** (destino/sensibilidade), **não** a capacidade de executar/ler local — é o guard
  do reviewer-ro que fecha execução/escrita e confina a leitura.

## LIMITE CONHECIDO — CODEX É AGÊNTICO (HERDA O AGENTS.md, PODE EXECUTAR)

O `codex exec` também é **agêntico**: carrega o `AGENTS.md`/config do Codex como instruções e,
mesmo com sandbox `read-only` (fixo nos adapters), **pode ler o filesystem do workspace e
executar comandos read-only** para cumprir as instruções herdadas (medido: ~50k tokens de input
e execução espontânea de `Get-Date` por causa de uma regra do `AGENTS.md` global). Consequências:

- **Não** é um backend one-shot: o prompt por chamada é grande e o agente pode agir no workspace.
  Para segunda opinião limpa, confinar com `-Cd <dir>` e preferir um workspace sem dados sensíveis.
- O `read-only` **não** contorna o gate: o Codex envia para a OpenAI (externo). Em pasta paralela
  de KB, payload sensível continua exigindo autorização — o adapter agêntico não tem proteção
  nativa de leitura ali (mesmo alerta do opencode em `## CONTEXTOS DE USO`).
- Reserva-se ainda o backend **one-shot** futuro (`llm`/`mods`) para o caso que precisa enviar
  só o prompt, sem agente nem varredura de filesystem.

## LIMITE CONHECIDO — CLAUDE CODE É AGÊNTICO E EXTERNO

O `claude -p` também é **agêntico**: pode carregar instruções/configurações do Claude Code,
ler o workspace e executar ferramentas conforme permissões. Além disso, Opus 4.8 envia o
payload para Anthropic (`anthropic/claude-opus-4-8`) e, portanto, é externo. Consequências:

- O gate de confidencialidade continua obrigatório: payload `kb-sensitive` para Claude Code
  externo sem política durável devolve `ask`; `allow` exige anunciar `targetModelKey`.
- Para **consulta curta restrita**, usar os defaults do adapter: `-PermissionMode plan`,
  `-Tools Read,Glob,Grep`, persistência de sessão desabilitada e `-Cd` apontando ao menor
  diretório necessário. Não há limite de turnos: `-MaxTurns` foi removido em 2026-07-25 porque a
  CLI parou de anunciar `--max-turns` e o valor era descartado em silêncio.
- Se o `stderr` do Claude Code casar o detector **heurístico** de **recusa** por workspace não
  confiável, isso é tratado como bloqueio operacional do backend, não parecer do revisor. O adapter
  emite `workspace-not-trusted`; no painel o estado deve ser `unavailable`, acionando fallback quando
  houver. A mensagem traz o `stderr` bruto e pede ao agente que informe ao usuário como enviar
  evidência (stderr sem segredos, `claude --version`, Desktop ou CLI) para melhorar a skill; não marcar
  confiança automaticamente nem pedir que o usuário a marque para contornar o bloqueio.
- **Não confundir recusa com aviso.** Workspace não confiável **não impede** a CLI de rodar: ela
  executa e apenas descarta as regras `permissions.allow` do projeto, avisando em `stderr`. Esse
  aviso aparece **também em execução bem-sucedida**, medido em 2026-07-25, e por isso é descartado
  como ruído antes de qualquer classificação. A recusa propriamente dita nunca foi observada — o
  detector segue por precaução, não por evidência.
- Para **revisor pré-push**, a rotina pode precisar de `git` e scripts locais. Definir
  explicitamente ferramentas/permissões suficientes para leitura e comandos de validação
  (sem `bypassPermissions`) **só vale FORA do painel** — via `Invoke-ClaudeCode.ps1` **direto**.
  **In-panel é INALCANÇÁVEL:** `Invoke-LlmDelegatePanelDispatch.ps1` recusa override de
  `tools`/`maxturns`/`permissionmode` e chaves internas do adapter assíncrono do Claude Code (`ContentionKeys`), então no painel o Claude
  Code roda como **semantic-only** (`plan`, `Read,Glob,Grep`) e **não** obtém git. A chave
  `maxturns` segue recusada por precaução, embora o parâmetro não exista mais. Para
  dar git a um revisor pré-push, use um **git-capable** (Codex-delegate ou subagente nativo) ou o
  **modo assistido por dossiê** — o orquestrador roda o mecânico e entrega o dossiê ao semantic-only
  (ver [`13-revisao-pre-push.md`](../13-revisao-pre-push.md) «Modo assistido por dossiê» e
  [`14-revisao-pre-push-reforcada.md`](../14-revisao-pre-push-reforcada.md)). A alegação anterior de
  que o Claude Code in-panel seria **fraco por `MaxTurns=1`** foi **retirada em 2026-07-25**: o
  limite nunca esteve em vigor. Não há medição de qualidade que sustente preferir outra voz por esse
  motivo; se houver preferência pelo opencode `reviewer-ro` como semantic-only, ela precisa de
  justificativa própria.
- Os adapters `Invoke-ClaudeCode.ps1`, `Invoke-ClaudeCodeAsync.ps1` e `Start-ClaudeCodeJob.ps1` bloqueiam
  `PermissionMode=bypassPermissions`; esse modo não faz parte da delegação XPZ.

## LIMITE CONHECIDO — COPILOT CLI, GEMINI CLI E ANTIGRAVITY CLI TAMBÉM SÃO AGÊNTICOS EXTERNOS

O `copilot -p`, o `gemini -p` e o `agy -p` são CLIs agênticas, não backends one-shot puros. Mesmo em
consulta curta, podem carregar contexto próprio e são serviços externos: Copilot casa
`github-copilot/*`; Gemini casa `google/*`; Antigravity casa `antigravity/*`. Consequências:

- O gate de confidencialidade continua obrigatório para payload `kb-sensitive`; sem política
  durável, ambos devolvem `ask`.
- Para Copilot, o adapter usa `--no-custom-instructions`, `--disable-builtin-mcps` e
  `--available-tools=`; o teste local comprovou resposta com `tools_updated` sem ferramentas
  executadas e `filesModified=[]`.
- Para Gemini, o adapter usa `--approval-mode plan`; os testes manuais em PowerShell 7
  comprovaram `tools.totalCalls=0` e `files.totalLinesAdded/Removed=0`.
- Para Antigravity, o adapter usa `--mode plan`; os testes manuais e a medição direta em PowerShell 7
  comprovaram o retorno de status `SUCCESS` ou a rejeição por erro com exit code ≠ 0.
- Nenhum dos três substitui o backend one-shot futuro (`llm`/`mods`/equivalente) para o caso
  em que é essencial enviar só o prompt sem camada agêntica.

## LIMITE CONHECIDO — `opencode run` FALHA EM CWD DE GIT WORKTREE (WINDOWS)

**Sintoma:** `opencode run` (qualquer modelo/provider/agente, inclusive o default `reviewer-ro`)
produz **stdout vazio** e/ou crasha com `uv_spawn ENAMETOOLONG` quando o **diretório de trabalho
atual é um git worktree** — aquele onde `.git` é um **gitlink (arquivo)** apontando para
`.../.git/worktrees/<nome>`, não um diretório. O adapter [`Invoke-OpenCode.ps1`](../scripts/Invoke-OpenCode.ps1)
reporta então `no-completion` (sem `step_finish`/`reason` no stream) ou o crash. Medido em
Windows, opencode 1.4.4. `opencode models` funciona (não spawna subprocesso); só `run` falha.

**Causa provável:** o opencode (Bun/libuv) spawna `git` via `uv_spawn`; num worktree, a resolução
do gitlink monta um caminho/linha-de-comando que estoura o limite do SO → `ENAMETOOLONG`.
Descartado empiricamente como causa: cota, tamanho do prompt/dossiê, o próprio adapter (o binário
direto falha igual) e estado travado (reiniciar a máquina **não** resolve; trocar o cwd resolve).

**Impacto na revisão por pares / pré-push reforçada:** o Claude Code desktop **sempre** roda em
worktree, e o harness fixa o cwd no worktree. Logo, despachar revisores **opencode** do cwd do
worktree **falha em silêncio**. Os demais backends (Codex/Claude Code/Copilot/Gemini/Antigravity) têm `-Cd`
próprio e não dependem disto; o opencode **não** tem `-Cd` (a contenção é pelo cwd herdado).

**Workaround (materializar dir plano):** rodar o opencode de um cwd **fora de worktree**. Para
revisar o estado de um worktree sem o gitlink, materialize-o num diretório plano curto e rode de
lá (o dossiê vai por **stdin**, então independe do cwd; o cwd só precisa conter os arquivos para o
`read`/`grep`/`glob` do `reviewer-ro`):

```powershell
# 1) materializa o HEAD do worktree num dir plano (sem .git)
git -C <worktree> archive --format=tar HEAD | tar -xf - -C C:\Users\<user>\AppData\Local\Temp\xr
# 2) roda o opencode desse cwd (Set-Location dentro do pwsh; o adapter usa (Get-Location).Path)
pwsh -NoProfile -Command "Set-Location 'C:\Users\<user>\AppData\Local\Temp\xr'; & '<repo>\scripts\Invoke-OpenCode.ps1' -MessagePath '<dossie>.txt' -Model opencode-go/glm-5.2 -TimeoutSec 600"
```

## BACKENDS

Ativos: **opencode** (#1), **Codex** (#2), **Claude Code** (#3), **GitHub Copilot CLI** (#4),
**Gemini CLI** (#5) e **Antigravity CLI** (#6). O Codex exerceu o ponto de
extensão do núcleo: o gate ganhou `-Backend` e passou a casar a política pelo `canonicalModel`
do resolvedor (chave de destino), sem renomear `LlmDelegate` nem tocar o resolvedor do
opencode. O Claude Code reaproveita o mesmo eixo: adapter próprio, resolvedor próprio e chave
de destino `anthropic/*`. Copilot, Gemini e Antigravity seguem a mesma regra, com chave de destino
`github-copilot/*`, `google/*` e `antigravity/*`, respectivamente.

Futuros (ex.: CLIs one-shot tipo `llm`/`mods`, mais seguras para segunda opinião pois não varrem
o filesystem) entram do mesmo jeito: um adapter de invocação + um resolvedor de localidade
próprio, plugados no mesmo gate por `-Backend`.

---

## RELAÇÃO COM OUTRAS SKILLS

- `xpz-kb-parallel-setup`: oferta, no setup da pasta paralela, definir a política de
  delegação (`llm-delegation-policy.json`; nome legado `opencode-delegation-policy.json`
  ainda aceito), com opção de **adiar** — adiar mantém o
  comportamento `ask`, nunca abre brecha.
- `xpz-skills-setup`: registra esta skill nas ferramentas de agente instaladas.
