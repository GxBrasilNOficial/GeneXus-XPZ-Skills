# xpz-mcp-integrations — design da skill (v6)

## Papel do documento

Design **vivo** (não congelado) da skill nova `xpz-mcp-integrations`, com decisões de
**2026-10-02** e a evidência empírica coletada nela.

- **v2** pré-análise · **v3** F0-1 (4 titulares; 4× revisa) · **v4** F0-2 (opencode; 3× revisa) ·
  **v5** F0-3 (opencode; 3× revisa) · **v6** F0-4 (opencode; 3× revisa).

**Processo de F0:** refinar via **opencode** até o autor não identificar mais gaps; depois submeter
a **uma validação final com um modelo mais caro**. Essa validação final **é insumo, sem poder
decisório** (voz única = segunda opinião, e "caro" ≠ diversidade): **não libera implementação**. A
liberação exige **painel diverso (≥2 famílias) sobre a versão final** + volta aos dissidentes
(`15`). Alternativa auditada: o humano **congela** o papel (`resubmissionDeclinedByHuman` + quem +
motivo + `RoundId`), transferindo a prova para self-test/implementação. Até lá,
`vNextState=pendingResubmission` e **nada é implementado**.

Este documento **não** é doc operacional; o contrato operacional viverá em
`xpz-mcp-integrations/SKILL.md`.

## Problema

Usuários das skills XPZ com acesso ao **Jev/System One** (modelo de decisão do TypeSafe, exposto
por MCP) não têm caminho gerenciado para instalar/auditar/reparar/atualizar/remover esse
componente. A configuração validada na máquina de referência é manual e **não portátil**: path
pessoal absoluto, rede/cache em runtime, transitivas sem pin e chave amarrada ao `auth.json` do
OpenCode. A `xpz-skills-setup` não cobre MCP de terceiros.

## Escopo da v1

- **Componente:** Jev/System One via `@jkudish/jev-mcp`. **Clientes:** OpenCode e Codex.
- **Plataforma:** **Windows** (a KB/IDE do usuário típico é Windows; macOS/Linux fora). **Exceção:**
  o cofre DPAPI **não faz roaming** — em máquina nova, reinserir a chave.
- **Ciclo:** detectar → instalar (vendorizado) → auditar → reparar → atualizar → remover.
- **Credencial:** cofre neutro. **Público:** comunidade.

**A v1 (OpenCode + Codex) só se completa ao fim do F2**; F1 sozinho **não** é a v1.

## Não-escopo da v1

Fork; Cursor e Claude Code; macOS/Linux; instalar ferramentas de agente; criar conta; instalar
`skills/jev/`; uso automático; MCPs sem descritor; vender fornecedores não provados como validados.

## Decisões travadas (2026-10-02)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Nome | `xpz-mcp-integrations` |
| 2 | Runtime | pacote **vendorizado** e pinado; **sem `npx`** |
| 3 | Node | detectar ausência **e** `< 22`; `winget` id `OpenJS.NodeJS.LTS` com aprovação; com `nvm`/`fnm`/`volta`, **relatar** |
| 3b | npm | pré-requisito próprio (node sem npm = instalação corrompida → relatar) |
| 4 | Plataforma | **Windows** (cofre sem roaming) |
| 5 | Escopo v1 | **OpenCode + Codex** (completa no F2) |
| 6 | Credencial | **cofre** DPAPI, **vault-first**; env = **override explícito**; `auth.json` só import opcional |
| 7 | Fornecedor | 5 modos; `compatible`/Command Code **parcial**; outros 4 **experimental opt-in** |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade |

## Arquitetura

### Motor dirigido por descritor

Componente = comando, stdio, mapa de env, fonte de credencial, clientes, validação. Cada componente
é um **descritor de dados** (`components/jev.json`) com **schema fail-closed** e self-test.

### Contrato dos motores novos

Seguem `02`: **JSON de máquina**, `-InputPath`, `-WhatIf`/`ShouldProcess`. Labels `*_SKIPPED` sob
`-WhatIf` são **propriedade de `xpz-skills-setup/SKILL.md`** (promover ao `02` só por promoção
reconciliada). **Tabela de contrato por motor (pré-requisito do F1):** para cada motor — parâmetros
aceitos (`-AsJson`? `-CheckUpdates`? `-CredentialSource`?), faixa de `exitCode`, e classe
(`blocking|warn|info`) por estado. `-AsJson` em motor sem a flag é erro de binding **invisível ao
parse**; a agenda de exits **não colide** com `msbuild-exit-codes.catalog.json`.

### Fronteira com `xpz-skills-setup` e aresta de dependência

- `xpz-mcp-integrations`: MCP **externos opcionais**; `xpz-skills-setup`: skills, instrucionais,
  `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- Nos arquivos de cliente compartilhados: **merge sempre**, **backup** antes de escrever, **nunca**
  remover entrada alheia. Os consumidores atuais (`Install-OpenCodeReviewerRoAgent.ps1`,
  `Install-CursorGlobalInstructionsMcp.ps1`) **não** fazem backup hoje — item de trabalho se tocados.
- Ponteiro **documental** na setup (sem motor). A skill entra sozinha no inventário; **registrar ≠
  instalar**. `AGENTS.md` precisa de **duas** entradas: a skill nova **e**
  `xpz-codex-apply-patch-alternative` (já ausente em `AGENTS.md:49`; o `README.md` já a lista).
- **Aresta de dependência:** `OpenCodeJsoncSupport.ps1` (dono-doc `xpz-llm-delegate/SKILL.md`) ganha
  consumidor novo; a aresta é registrada nos dois documentos donos.

### Suporte JSONC compartilhado — frente própria (F1-pre)

Diagnóstico verificado no código:

- `Find-JsoncMatchingBrace`: ciente de string, **cego a comentários**.
- `Find-JsoncKeyValueSpan`: **não** ciente de string (o comentário promete heurística de aspas que
  **não existe**).
- `ConvertFrom-Jsonc` (`OpenCodeReviewerRoGuard.ps1`): char-a-char, string/escape/comentário-aware;
  **scanner de referência**; **não** trata trailing comma.
- `ConvertFrom-JsoncText` (`Build-LlmDelegateCapabilityManifest.ps1`): regex, **não** string-safe;
  **remove** trailing comma (self-test cobre).
- **Bug vivo:** `Install-OpenCodeReviewerRoAgent.ps1:252` valida o arquivo inteiro com
  `ConvertFrom-Jsonc` → trailing comma alheio à edição derruba com `BLOCK`.

**Correção (sem regressão):** `OpenCodeJsoncSupport.ps1` consolida o **scanner** do
`ConvertFrom-Jsonc` **e mantém** a tolerância a trailing comma; política de trailing comma é
**pré-condição dura**. **Ordem de migração (reduz risco auto-referente):** núcleo + instalador
primeiro; **manifesto de capacidade por último**, com pin de fallback. Consumidores refatorados:
`OpenCodeReviewerRoGuard.ps1`; `Build-LlmDelegateCapabilityManifest.ps1`;
`Install-OpenCodeReviewerRoAgent.ps1` (**hoje** dot-sourceia o Guard em `:49`). **Fixtures
negativas** (pré-condição): chave comentada; forma-de-chave dentro de string; `{}` dentro de
`/* */`; `//` dentro de string; trailing comma. O F1-pre exige **revisão própria por painel com
≥1 voz fora do harness afetado** (não só auto-revisão) e pré-push próprio.

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`; **versão fixada `0.13.0`**. **Mecanismo de pin = sha512 + tag**
  (decidido); **valores** exatos = fatos externos.
- **Pré-condição de evidência (F1-pre/F1):** antes de qualquer motor, **commitar fixtures
  sanitizadas** do `dist` (trecho mínimo de `provider.js` que sustenta cada linha da tabela,
  `engines.node`, boot `initialize` observado). Até então, a **tabela de Fornecedor é hipótese**,
  não decisão.
- **Artefatos commitados:** `package.json` de pin **exato** (`"0.13.0"`) + `package-lock.json`.
  **Lockfile = fonte autoritativa de integridade**; `dist.integrity` do descritor = **asserção**.
- **Vendor:** `npm ci` + `--ignore-scripts` em `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`,
  exposto pela indireção estável `current` (`...\current\node_modules\@jkudish\jev-mcp\dist\index.js`)
  que **launcher e auditoria** resolvem. **Switch por re-apontamento** (não é atômico no Windows:
  remover+recriar link; **comando exato por tipo de link** para não apagar o alvo; symlink exige
  privilégio/Developer Mode → **junction fallback** como a setup faz); **MCP em execução** → falha
  segura com mensagem, sem retry cego. `npm` é pré-requisito próprio; sem rede no runtime; o pacote
  não é comitado.
- **Re-verificação isolada do `dist` (gating de F1):** rodar em ambiente **sem chave real e sem
  rede**, `npm ci --ignore-scripts`, com **relatório** de allowlist de hosts, ocorrências de
  `fetch`/`undici`/`HttpClient`/telemetria, dump de env, e comportamento das **N transitivas do
  lockfile** (N do lock, não fixo).

### Launcher portátil (molde gerado pela skill)

- **Comando = launcher PowerShell** (`["pwsh","-NoProfile","-File","<launcher>.ps1"]`): (1) desprotege
  a chave do cofre via **DPAPI** em memória (**nunca argv**); (2) resolve o `node` **absoluto**;
  (3) inicia `...\current\node_modules\@jkudish\jev-mcp\dist\index.js` com a variável **só** no env
  do filho.
- **Stdio — rota travada:** primário **`& node …` no próprio processo** (herda stdio). **Invariante
  dura:** o launcher **emite zero bytes no stdout** além do filho; logs só em **stderr/arquivo**;
  nenhum valor de chave em log; exit code propagado (`$LASTEXITCODE`). `ProcessStartInfo`+proxy de
  bytes = **fallback documentado** só se `& node` falhar comprovadamente. Self-test prova **stdio
  binário (payload grande) + exit code**.
- **Runtime:** exige `pwsh` (7.4+); auditoria reporta se faltar. Rota Node→pwsh (desproteger por
  filho) **descartada** por risco de transcrição.
- **Marcador de propriedade:** sentinela no cabeçalho + **manifesto**; uninstall remove **só se**
  sentinela **e** path no manifesto; órfão = reportar.

## Fornecedor

Cinco modos (`JevProvider`). **Tabela = hipótese** até a evidência sanitizada do `dist` ser
commitada (ver Vendorização).

| Modo (`JEV_PROVIDER`) | Credencial | Endpoint / wire (hipótese) | Status |
|---|---|---|---|
| `typesafe` (padrão do pacote) | `TYPESAFE_API_KEY` | transport do SDK; default `jev-latest` | experimental opt-in |
| `openrouter` | `OPENROUTER_API_KEY` | `POST {JEV_OPENROUTER_BASE_URL:-https://openrouter.ai/api}/alpha/decisions`; headers `HTTP-Referer`/`X-Title`/`X-OpenRouter-Title`; `jev-latest`→`jev-1.13` | experimental opt-in |
| `cloudflare` | `JEV_CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` | `POST {JEV_CLOUDFLARE_BASE_URL:-https://api.cloudflare.com/client/v4}/accounts/<id>/ai/run`; `{model, input:{state,questions}}` | experimental opt-in |
| `vercel` | `AI_GATEWAY_API_KEY` | transport do SDK (Vercel AI Gateway) | experimental opt-in |
| `compatible` | `JEV_API_KEY` | `POST` direto na **URL completa** `JEV_API_BASE_URL`, `Bearer`; `{model,state,questions}` → `{answers,usage?}` | **parcial** |

- `compatible` **não** é "API OpenAI qualquer": exige o contrato System One/Jev; a URL vai como veio;
  `cloudflare`/`vercel` não são intercambiáveis. Sem `JEV_PROVIDER` (`auto`), infere pela presença de
  env.
- **`compatible` = parcial:** prova o **handshake MCP**, não a decisão E2E (validação manual opt-in).
- **Command Code** = preset sugerido, nunca presumido. **Experimental opt-in:** os 4 não provados
  ficam fora do caminho feliz e dos self-tests do F1. **Import `auth.json`:** opcional, com ressalva
  (credencial `commandcode/*` do OpenCode é de **gateway de LLM**).

## Credencial

- **Cofre:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\` (`%LOCALAPPDATA%` lido do ambiente;
  separado do `vendor-*/`). **Blob:** formato declarado (DPAPI `CurrentUser`, **sem entropia
  adicional** — decidido); **ACL** via `ICACLS` (remover herança + só o dono); **backup do cofre**
  explícito.
- **Rotação/revogação:** re-cifrar o blob a partir do segredo novo; **revogação por comprometimento**
  = apagar o blob + orientar revogar a chave no provedor (≠ "preservar o cofre" do uninstall
  normal — são casos distintos). Avisar MCP em execução (chave nova vale no próximo start).
- **Vault-first (default):** (1) cofre; (2) env como **override explícito** (`-CredentialSource env`).
  `credencial_divergente_env_vs_cofre` é **blocking até confirmação**.
- **Limite honesto:** DPAPI protege em repouso; **não** contra processo do mesmo usuário, inspeção do
  env do filho, nem roaming. **Fronteira:** pacote + transitivas + endpoint. **Chave nunca**
  impressa/logada/copiada; entrada só por comando local oculto.

## Adaptadores de cliente (v1)

- **OpenCode** — `~/.config/opencode/opencode.jsonc`, `mcp.jev` (`type: local`,
  `command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`). Merge
  via o **suporte JSONC**; backup; idempotente. Entrada `jev` divergente → `entrada_em_conflito`.
  **Fato externo** (shape) na lista de re-verificação + **fixture sanitizada** do `opencode.jsonc`
  no F1.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**) com prova empírica: env em
  **sub-tabela** `[mcp_servers.jev.env]`, literal `'...'`, span até próximo cabeçalho não-filho,
  `enabled=false` como "desabilitar", remover a seção só no desinstalar definitivo. **`env_vars`
  filtra o ambiente herdado** → **mitigação:** o launcher **define tudo explicitamente** e **não
  depende** de herança (o passo "env presente" vira só override explícito). Fixture do `config.toml`
  (sanitizada) no F2.

## Auditoria (estados e contrato)

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`. **Tabela estado → `exitCode` e
  classe** (`blocking|warn|info`) por motor (ver Contrato dos motores).
- **Offline/determinístico:** `OK`; `ausente`; `entrada_quebrada`/`entrada_divergente`/
  `entrada_em_conflito`; `versao_defasada` (fonte: **pin do descritor**);
  `vendor_ausente`/`vendor_divergente` (vs lock); `launcher_ausente`/`launcher_divergente` (termo
  unificado: **launcher**); `node_ausente`/`node_incompativel`/`node_path_nao_resolve`;
  `pwsh_ausente`; `fornecedor_ausente`; `fornecedor_nao_validado` (**warn**);
  `credencial_ausente`; `credencial_divergente_env_vs_cofre` (**blocking**);
  **`endpoint_nao_verificado`** (chave iria a host fora da allowlist verificada — **blocking**;
  cobre falha silenciosa de destino); **`acl_nao_aplicavel`** (volume sem suporte a ACL — **warn**;
  cobre cofre que degrada sem sinal).
- **Online opt-in** (`-CheckUpdates`, com rede): `atualizacao_disponivel` (fonte: registro remoto) —
  informa, nunca auto-atualiza; fora do gate offline. Canonicalização de path (case-insensitive,
  barras, EOL) antes de `entrada_divergente`, para não gerar falso positivo.

## Atualizar e remover

- **Atualizar:** consciente (release notes, breaking changes, backup, re-apontamento, teste,
  rollback). Nunca por existir versão nova.
- **Remover:** manifesto registra **referências por cliente**; o launcher só sai quando **não restar
  referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre,
  `auth.json`, fornecedor e demais MCPs; no Codex, `enabled=false` quando quiser manter a config.

## Testes

- **Self-tests offline:** detecção; merge JSONC (**fixtures negativas:** comentário, string,
  `/* */`, `//`, trailing comma); idempotência; backup; rollback; schema do descritor; **round-trip
  DPAPI** (segredo fictício, diretório efêmero); **re-apontamento** (concorrência + MCP em execução
  + comando seguro por tipo de link); **launcher com filho falso** (stdio binário, **zero bytes no
  stdout além do filho**, exit code, injeção exata, sem vazamento, sem rede).
- **Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
  Self-tests de **TOML** no **F2**.
- **E2E** com `jev_classify` = validação manual opt-in; pré-requisito de qualquer "validado".

## Documentação e paridade

- `README.md` trilíngue — skills enumeradas em **duas listas por língua** (abertura + seção "Skills
  para agentes"), ×3 = **seis pontos**; `CHANGELOG.md` trilíngue; **`SECURITY.md` também é
  trilíngue** (seção do cofre entra nas três, mesma posição).
- `09` com formato completo (`Dono:` + `Validação:`/`Tokens:`/`Exit:`); `02` (contrato de motor);
  `08` (nomear os pontos exatos **ou** retirar).
- `AGENTS.md` (duas entradas) e ponteiro documental na setup; `xpz-llm-delegate/SKILL.md` (dono do
  JSONC + aresta).
- **`999`:** já **reconciliado** — `999:3283` registra o pin como "sha512 + tag, valores a
  re-verificar no F1" (mecanismo decidido, valores provisórios) e o preset como **parcial**. Não há
  pendência aberta; manter alinhado no congelamento.
- Conformidade: `#requires -Version 7.4`; UTF-8 **sem BOM**; molde `.example.ps1`;
  `Test-XpzParameterNamingContract.ps1` **não** é gate geral; não enumerar ≥2 gates numa linha.
- **Ledger:** **efêmero e gitignored** em `Temp/revisao-por-pares/<RoundId>/`, conforme `15`;
  **decisão: não persistir versionado** (não introduzir `.peer-review-rounds/`).

## Fases

- **F0** — design + revisão (em andamento: F0-1..F0-4; faltam refinamento, **validação cara
  (insumo)** e **painel diverso de liberação**).
- **F1-pre (frente própria, revisão por painel com ≥1 voz externa ao harness afetado)** —
  `OpenCodeJsoncSupport.ps1` + fixtures negativas + migração ordenada dos consumidores + self-tests.
- **F1** — skill (OpenCode + núcleo) + descritor Jev + launcher + cofre/DPAPI + vendorizador +
  **evidência sanitizada do `dist`** + **revisão do `dist` gating** + self-tests + docs. **F1 ≠ v1.**
- **F2** — Codex (TOML, prova empírica) + self-tests TOML + auditoria de versão/drift + update/
  rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1` no mesmo
  `~/.cursor/mcp.json`).
- **F4** — opcionais: validação dos fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** — rota travada (`& node`); invariante de stdout; prova no self-test.
- **Merge TOML (Codex)** — prova empírica no F2; mitigação do `env_vars`.
- **Revisão do `dist`** — **item gating** de F1, com procedimento isolado e relatório; refletir em
  `SECURITY.md`.
- **Fatos externos a re-verificar no F1/F2:** integridade/tag/commit; `engines.node`; tabela dos 5
  modos; boot MCP; shape do `opencode.jsonc`; semântica TOML do Codex.
- **Fornecedores experimentais** só sob opt-in. **Node/pwsh/npm** são dependências de runtime.

## Evidência coletada (2026-10-02)

- `node v24.18.0`/`python 3.14`; pacote vendorizado em pasta temporária; **boot offline** com env
  fictício + `initialize` MCP (`server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`).
- **`dist/provider.js` lido** em `%TEMP%\opencode\jev-probe\` (evidência **externa**; a commitar
  sanitizada antes do F1).
- **Rodadas F0** (vereditos em `Temp/revisao-por-pares/<RoundId>/`, efêmero/gitignored):

| Rodada | RoundId | Revisores | Piso | Vereditos |
|---|---|---|---|---|
| F0-1 | `mcp-integrations-f0-v2` | meta, stealth, openai, anthropic | meta+openai+anthropic | 4× revisa |
| F0-2 | `mcp-integrations-f0-v3` | meta, stealth, deepseek | meta+deepseek | 3× revisa |
| F0-3 | `mcp-integrations-f0-v4` | meta, stealth, deepseek | meta+deepseek | 3× revisa |
| F0-4 | `mcp-integrations-f0-v5` | meta, stealth, deepseek | meta+deepseek | 3× revisa |

- **Recibo F0-1** (via `xpz-llm-delegate`): `preferenceSource=orchestrator`,
  `effectivePreferredPath=…\preferred-reviewers.opencode.json`; `attemptRole=primary`, `fallbackOf`
  vazio, `countsForDiversity=true`; `closeoutReady=false` (`vnext-pending-resubmission`);
  `receiptAddendum` com curadoria `not_applicable`.
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

## Referências

- `https://github.com/jkudish/jev-mcp` (MIT); `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md`; `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md` —
  `commandcode/*` como **catálogo de vozes** do painel (não confundir com o endpoint do Jev).
