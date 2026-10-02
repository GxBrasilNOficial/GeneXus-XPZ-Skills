# xpz-mcp-integrations — design da skill (v5)

## Papel do documento

Design **vivo** (não congelado) da skill nova `xpz-mcp-integrations`. Registra decisões de
**2026-10-02** e a evidência empírica coletada nela.

- **v2** — pré-análise. **v3** — consolidação F0-1 (4 titulares; 4× revisa). **v4** — consolidação
  F0-2 (opencode; 3× revisa). **v5** — consolidação F0-3 (opencode; 3× revisa).

**Processo de F0:** refinar com os revisores **via opencode** até o autor não identificar mais
gaps; então submeter a **uma validação final com um modelo mais caro**. Importante: essa validação
final, sendo **voz única = segunda opinião**, **não libera implementação**. A liberação exige
**painel diverso (≥2 famílias) sobre a versão final** e volta aos dissidentes (`15`). Enquanto não
houver isso, `vNextState=pendingResubmission` e **nada é implementado**.

Este documento **não** é doc operacional. O contrato operacional viverá em
`xpz-mcp-integrations/SKILL.md`.

## Problema

Usuários das skills XPZ com acesso ao **Jev/System One** (modelo de decisão do TypeSafe, exposto
por MCP) não têm caminho gerenciado para instalar/auditar/reparar/atualizar/remover esse
componente MCP. A configuração validada na máquina de referência é manual e **não portátil**:
**path pessoal absoluto**, **rede/cache em runtime**, **transitivas sem pin** e **chave amarrada ao
`auth.json` do OpenCode**. A `xpz-skills-setup` não cobre MCP de terceiros. Daí a skill dedicada.

## Escopo da v1

- **Componente:** Jev/System One via `@jkudish/jev-mcp`. **Clientes:** OpenCode e Codex.
- **Plataforma:** **Windows** — a KB nativa/IDE do usuário típico desta base é Windows; macOS/Linux
  ficam fora da v1 (a doc não promete portabilidade). **Exceção declarada:** o **cofre DPAPI não faz
  roaming** entre máquinas/perfis — em máquina nova, a chave é reinserida.
- **Ciclo:** detectar → instalar (vendorizado) → auditar → reparar → atualizar → remover.
- **Credencial:** cofre neutro. **Público:** comunidade.

**A `v1` (OpenCode + Codex) só se completa ao fim do F2**; o F1 sozinho **não** é a v1.

## Não-escopo da v1

Fork do pacote; Cursor e Claude Code; macOS/Linux; instalar ferramentas de agente; criar conta;
instalar a skill `skills/jev/` do pacote; configurar uso automático; gerenciar MCPs sem descritor;
vender como "validados" fornecedores não provados.

## Decisões travadas (2026-10-02)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Nome | `xpz-mcp-integrations` |
| 2 | Runtime | pacote **vendorizado** e pinado; **sem `npx`** no início |
| 3 | Node | detectar ausência **e** `< 22`; oferecer `winget` id `OpenJS.NodeJS.LTS` com aprovação; se houver `nvm`/`fnm`/`volta`, **relatar**, não instalar |
| 3b | npm | pré-requisito próprio |
| 4 | Plataforma | **Windows** (explícita; cofre sem roaming) |
| 5 | Escopo v1 | **OpenCode + Codex** (completa no F2) |
| 6 | Credencial | **cofre** em DPAPI (**vault-first**); env como **override explícito**; `auth.json` só import opcional |
| 7 | Fornecedor | 5 modos; `compatible`/Command Code = **parcial**; outros 4 **experimental opt-in** |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade |

## Arquitetura

### Motor dirigido por descritor

Componente MCP externo = comando, stdio, mapa de env, fonte de credencial, clientes e validação.
Cada componente é um **descritor de dados** (`components/jev.json`) com **schema fail-closed** e
self-test.

### Contrato dos motores novos

Seguem o runtime do repo (`02`): **JSON de máquina**, `-InputPath`, `-WhatIf`/`ShouldProcess`. A
convenção de labels `*_SKIPPED` sob `-WhatIf` é **propriedade de `xpz-skills-setup/SKILL.md`**;
promover ao `02` só por promoção reconciliada. O motor de auditoria **declara** se aceita
`-AsJson` (passar `-AsJson` a motor sem a flag é erro de binding **invisível ao parse**).

### Fronteira com `xpz-skills-setup` e aresta de dependência

- `xpz-mcp-integrations`: MCP **externos opcionais**; `xpz-skills-setup`: skills, instrucionais,
  `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- Nos arquivos de cliente compartilhados: **merge sempre**, **backup** antes de escrever, **nunca**
  remover entrada alheia. A regra de backup vale para os **escritores novos**; os consumidores
  atuais (`Install-OpenCodeReviewerRoAgent.ps1`, `Install-CursorGlobalInstructionsMcp.ps1`) **não**
  fazem backup hoje e ganham item de trabalho se tocados.
- Ponteiro **documental** na setup (sem motor). A skill nova entra sozinha no inventário;
  **registrar ≠ instalar**. `AGENTS.md` precisa de **duas** entradas hoje: a skill nova **e**
  `xpz-codex-apply-patch-alternative` (já ausente — `AGENTS.md:49`; o `README.md` já a lista).
- **Aresta de dependência:** o `OpenCodeJsoncSupport.ps1` (dono-doc `xpz-llm-delegate/SKILL.md`)
  passa a ter um **consumidor novo** (`xpz-mcp-integrations`); a aresta é registrada nos dois
  documentos donos.

### Suporte JSONC compartilhado — frente própria (F1-pre)

Diagnóstico verificado no código:

- `Find-JsoncMatchingBrace` (`Install-OpenCodeReviewerRoAgent.ps1`): ciente de string, **cego a
  comentários**.
- `Find-JsoncKeyValueSpan` (mesmo script): **não** é ciente de string (o comentário promete uma
  heurística de aspas que **não existe** no código).
- `ConvertFrom-Jsonc` (`OpenCodeReviewerRoGuard.ps1`): char-a-char, string/escape/comentário-aware
  → **scanner de referência**; porém **não** trata trailing comma.
- `ConvertFrom-JsoncText` (`Build-LlmDelegateCapabilityManifest.ps1`): regex, **não** string-safe,
  **mas remove trailing comma** (e o self-test dele cobre isso). **Roda hoje** lendo o
  `opencode.jsonc` real.
- **Bug vivo:** `Install-OpenCodeReviewerRoAgent.ps1:252` valida o arquivo inteiro resultante com
  `ConvertFrom-Jsonc`; um `opencode.jsonc` com trailing comma em **qualquer** ponto faz o
  instalador do `reviewer-ro` lançar `BLOCK` **sobre entrada não relacionada à edição**.

**Correção (não regredir):** o `OpenCodeJsoncSupport.ps1` consolida o **scanner** do
`ConvertFrom-Jsonc` **e mantém a tolerância a trailing comma** do `ConvertFrom-JsoncText` — a
política de trailing comma é **pré-condição dura** do F1-pre, não item "a decidir". Consumidores
refatorados (arquivo + linhagem): `OpenCodeReviewerRoGuard.ps1`; `Build-LlmDelegateCapabilityManifest.ps1`;
`Install-OpenCodeReviewerRoAgent.ps1` (consome o `ConvertFrom-Jsonc` do Guard por dot-source).
**Fixtures negativas** (pré-condição da refatoração, não consequência): chave comentada;
forma-de-chave dentro de string; `{}` dentro de `/* */`; `//` dentro de string; **trailing comma**.
O F1-pre exige **revisão própria** e pré-push próprio antes de o F1 consumi-lo (risco
auto-referente: toca o instrumento de revisão).

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`; **versão fixada `0.13.0`**. **Mecanismo de pin = sha512 + tag**
  (decidido); **valores exatos** (integridade/tag/commit) = **fatos externos a re-verificar no F1**.
- **Artefatos commitados:** `package.json` de pin **exato** (`"0.13.0"`, sem `^`/`~`) +
  `package-lock.json`. **Lockfile = fonte autoritativa de integridade**; o `dist.integrity` do
  descritor é **asserção** conferida contra o lock.
- **Vendor:** `npm ci` + `--ignore-scripts` em `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`,
  exposto por uma **indireção estável `current`** que **launcher e auditoria** resolvem
  (`...\current(node_modules\@jkudish\jev-mcp\dist\index.js`). **Switch atômico:** link
  `current` → `vendor-<versao>` (symlink preferido, **junction** como fallback, como a setup já
  faz); rollback = reapontar `current`. **MCP em execução:** o switch que falhar por lock do
  Windows é **falha segura** com mensagem (não retry cego). `npm` é pré-requisito próprio. Sem rede
  no runtime; o pacote de terceiros **não** é comitado.

### Launcher portátil (molde gerado pela skill)

- **Comando do MCP = launcher PowerShell** (`command: ["pwsh","-NoProfile","-File","<launcher>.ps1"]`).
  O launcher: (1) desprotege a chave do cofre com **DPAPI** em memória (**nunca argv**);
  (2) resolve o `node` **absoluto**; (3) inicia
  `...\current\node_modules\@jkudish\jev-mcp\dist\index.js` com a variável **só** no ambiente do
  filho.
- **Stdio — rota travada:** primário é **`& node …` no próprio processo** do launcher (herda
  stdin/stdout/stderr naturalmente, sem proxy). A rota `ProcessStartInfo` (`UseShellExecute=$false`
  + redirecionamento + proxy de bytes) fica como **fallback documentado**, usado só se `& node`
  falhar de modo comprovado. O self-test prova **stdio binário (payload grande) + propagação de
  exit code** para a rota travada.
- **Runtime:** exige `pwsh` (7.4+); auditoria reporta se faltar. Rota Node→pwsh (desproteger por
  filho) **descartada** por risco de transcrição.
- **Marcador de propriedade:** sentinela no cabeçalho + **manifesto**; uninstall remove **somente
  se** sentinela **e** path no manifesto; órfão = reportar.

## Fornecedor

Cinco modos (`JevProvider`): `typesafe`, `openrouter`, `cloudflare`, `vercel`, `compatible`.

| Modo (`JEV_PROVIDER`) | Credencial | Endpoint / wire | Status |
|---|---|---|---|
| `typesafe` (padrão do pacote) | `TYPESAFE_API_KEY` | transport do SDK; default `jev-latest` | experimental opt-in |
| `openrouter` | `OPENROUTER_API_KEY` | `POST {JEV_OPENROUTER_BASE_URL:-https://openrouter.ai/api}/alpha/decisions`; headers `HTTP-Referer`/`X-Title`/`X-OpenRouter-Title`; `jev-latest`→`jev-1.13`; slug `typesafe/*` | experimental opt-in |
| `cloudflare` | `JEV_CLOUDFLARE_API_TOKEN`/`CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` | `POST {JEV_CLOUDFLARE_BASE_URL:-https://api.cloudflare.com/client/v4}/accounts/<id>/ai/run`; `{model, input:{state,questions}}`; resposta aninhada | experimental opt-in |
| `vercel` | `AI_GATEWAY_API_KEY` | transport do SDK (Vercel AI Gateway) | experimental opt-in |
| `compatible` | `JEV_API_KEY` | `POST` direto na **URL completa** `JEV_API_BASE_URL`, `Bearer`; `{model,state,questions}` → `{answers,usage?}` | **parcial** |

- `compatible` **não** é "API OpenAI qualquer": exige o contrato System One/Jev; a URL vai **como
  veio**. `cloudflare`/`vercel` têm **envelopes próprios** (não intercambiáveis). Sem `JEV_PROVIDER`
  (`auto`), o pacote infere pela presença de env.
- **`compatible` = parcial:** a evidência prova só o **handshake MCP**; a decisão E2E é validação
  manual opt-in. Doc e relatório usam "parcial", **não** "validado".
- **Command Code** = preset `compatible` sugerido (`…/provider/v1/systemone`, `JEV_MCP_MODEL=typesafe/jev`),
  nunca presumido. **Experimental opt-in:** os 4 não provados ficam fora do caminho feliz e dos
  self-tests do F1. **Import `auth.json`:** opcional, com ressalva (credencial `commandcode/*` do
  OpenCode é de **gateway de LLM**, não necessariamente chave de decisão do System One).

## Credencial

- **Cofre:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\` (`%LOCALAPPDATA%` lido **do ambiente**;
  separado do `vendor-*/`).
- **DPAPI operacional:** escopo **CurrentUser**; **sem entropia adicional** (decidido — entropia
  extra só desloca a guarda do segredo); **ACL** do `vault\` via `ICACLS` (remover herança + só o
  dono); **rotação/revogação** = re-cifrar o blob e avisar MCP em execução (a chave nova vale no
  próximo start); entrada oculta por `Read-Host -AsSecureString`; o launcher **registra a fonte
  usada** (vault×env) **sem o valor**.
- **Vault-first (default):** ordem de resolução **(1) cofre; (2) env como override explícito**
  (ex.: `-CredentialSource env`). Motivo: o alvo é quem migra de env/`auth.json`; env-first anularia
  o ganho de segurança no caso mais provável. `credencial_divergente_env_vs_cofre` é **bloqueante
  até confirmação** (não só aviso).
- **Limite honesto:** DPAPI protege **em repouso**, **não** contra processo do mesmo usuário nem
  inspeção do env do filho; **não** faz roaming. **Fronteira de confiança:** pacote + transitivas +
  endpoint. A chave é entregue ao processo `jev-mcp` e enviada ao endpoint como credencial de
  transporte; o vetado é vazar para log/config/doc/chat. **Chave nunca** impressa/logada/copiada;
  entrada só por comando local oculto.

## Adaptadores de cliente (v1)

- **OpenCode** — `~/.config/opencode/opencode.jsonc`, seção `mcp.jev` (`type: local`,
  `command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`).
  Merge via o **suporte JSONC**; backup; idempotente. Entrada `jev` preexistente divergente →
  `entrada_em_conflito` (bloqueia sobrescrita). O shape é **fato externo**: entra na lista de
  "a re-verificar" e ganha **fixture sanitizada** do `opencode.jsonc` real no F1.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**) com **prova empírica** antes do
  motor: env em **sub-tabela** `[mcp_servers.jev.env]`, string **literal** `'...'`, span até o
  próximo cabeçalho **não-filho**, `env_vars` que filtra o ambiente herdado (ameaça o passo env do
  launcher). **Desabilitar vs remover:** `enabled=false` quando o usuário quiser manter a config;
  remover a seção só no desinstalar definitivo. Fixture do `config.toml` (sanitizada) no F2.

## Auditoria (estados e contrato)

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`.
- **Offline/determinístico**, com `exitCode` por estado e classe `blocking|warn|info`:
  `OK`; `ausente`; `entrada_quebrada`/`entrada_divergente`/`entrada_em_conflito`;
  `versao_defasada` (fonte: **pin do descritor**); `vendor_ausente`/`vendor_divergente` (vs
  lock/integridade); `launcher_ausente`/`launcher_divergente` (terminologia unificada:
  **launcher**, não "wrapper"); `node_ausente`/`node_incompativel`/`node_path_nao_resolve`;
  `pwsh_ausente`; `fornecedor_ausente`; `fornecedor_nao_validado` (**warn**, não bloqueia);
  `credencial_ausente`; `credencial_divergente_env_vs_cofre` (**blocking** até confirmação).
- **Online opt-in** (`-CheckUpdates`, com rede): `atualizacao_disponivel` (fonte: **registro
  remoto**) — informa, nunca auto-atualiza; **fora** do gate offline. A comparação de paths expande
  variáveis antes de decidir `entrada_divergente`.

## Atualizar e remover

- **Atualizar:** consciente (release notes, breaking changes, backup, switch de `current`, teste,
  rollback). Nunca por existir versão nova.
- **Remover:** manifesto registra **referências por cliente**; o launcher só sai quando **não
  restar referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre,
  `auth.json`, fornecedor e demais MCPs; no Codex, `enabled=false` quando quiser manter a config.

## Testes

- **Self-tests offline:** detecção; merge JSONC (com **fixtures negativas**: comentário, string,
  `/* */`, `//`, trailing comma); idempotência; backup; rollback; schema do descritor; **round-trip
  DPAPI** com segredo fictício em diretório efêmero; **atomicidade do switch** (switch + rollback +
  MCP em execução); **launcher com filho falso** (stdio binário, exit code, injeção exata da
  variável, sem vazamento em erro, sem rede).
- **Self-tests não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e
  registra em `09` (`Validação:`/`Tokens:`). Self-tests de **TOML** no **F2**.
- **E2E** com `jev_classify` = validação manual opt-in; pré-requisito de qualquer "validado".

## Documentação e paridade

- `README.md` trilíngue (skills em **seis** pontos); `CHANGELOG.md` trilíngue; **`SECURITY.md`
  também é trilíngue** — a seção do cofre entra nas **três** línguas, na mesma posição.
- `09` com formato completo (`Dono:` + `Validação:`/`Tokens:`/`Exit:`); `02` (contrato de motor).
- `08`: nomear os pontos exatos (a skill é operacional para o agente GPT? em que cenário) **ou**
  retirar o item.
- `AGENTS.md` (duas entradas) e ponteiro documental na setup; `xpz-llm-delegate/SKILL.md` (dono do
  JSONC + aresta de consumo).
- **`999`:** a contradição do "preset validado" **já foi corrigida** (`999:3283` diz "parcial (não
  validado E2E)"). Falta reconciliar o **status da integridade/tag**: o `999` registra
  "sha512 + tag `v0.13.0`" como **decidido**; o correto é "**mecanismo** (sha512+tag) decidido,
  **valores** a re-verificar no F1" — alinhar os dois.
- Conformidade: `#requires -Version 7.4`; UTF-8 **sem BOM**; molde `.example.ps1`.
  `Test-XpzParameterNamingContract.ps1` **não** é gate geral.
- Não enumerar ≥2 gates numa linha (dispara `Test-PrePushGateEnumerationParity`).
- **Ledger:** `.peer-review-rounds/` está **gitignored**; para persistir o ledger no congelamento,
  adicionar a cascata (`!/.peer-review-rounds/` + `/**`) ou usar caminho rastreado — item
  explícito, não efeito colateral.

## Fases

- **F0** — design + revisão (em andamento: F0-1 4 titulares; F0-2/F0-3 opencode; faltam refinamento
  e, ao final, **validação cara** + **painel diverso de liberação**).
- **F1-pre (frente própria, com revisão e pré-push próprios)** — `OpenCodeJsoncSupport.ps1` +
  fixtures negativas + refatoração dos consumidores + self-tests.
- **F1** — skill (parte OpenCode + núcleo) + descritor Jev (Command Code) + launcher + cofre/DPAPI +
  vendorizador + **revisão do `dist` como item gating** + self-tests + docs. **F1 ≠ v1.**
- **F2** — Codex (TOML, prova empírica) + self-tests TOML + auditoria de versão/drift + update/
  rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1` no mesmo
  `~/.cursor/mcp.json`: merge, backup, nunca remover entrada alheia).
- **F4** — opcionais: validação dos fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** — rota travada (`& node` primário; proxy como fallback); prova no self-test.
- **Merge TOML (Codex)** — sub-tabela `.env`, literal, `enabled`, `env_vars`; prova empírica no F2.
- **Revisão do `dist`** — **item gating** de F1 (não aviso): allowlist de hosts + varredura de
  `fetch`/`undici`/`HttpClient`/telemetria + dump de env + comportamento das **N transitivas do
  lockfile** (o número é do lock, não fixo). Refletir em `SECURITY.md`.
- **Fatos externos a re-verificar no F1/F2:** integridade/tag/commit; `engines.node`; tabela dos 5
  modos; boot MCP offline; **shape do `opencode.jsonc`** (`mcp.jev`, `type: local`, `environment`);
  semântica TOML do Codex.
- **Fornecedores experimentais** só sob opt-in. **Node/pwsh** são dependências de runtime.

## Evidência coletada (2026-10-02)

- `node v24.18.0`/`python 3.14`; pacote vendorizado em pasta temporária; **boot offline** com env
  fictício + `initialize` MCP (`server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`).
- **`dist/provider.js` lido** em `%TEMP%\opencode\jev-probe\` (evidência **externa** ao repo).
- **Rodadas F0** (vereditos em `Temp/revisao-por-pares/<RoundId>/`, **efêmero/gitignored**):

| Rodada | RoundId | Revisores | Piso | Vereditos |
|---|---|---|---|---|
| F0-1 | `mcp-integrations-f0-v2` | meta, stealth, openai, anthropic | meta+openai+anthropic | 4× revisa |
| F0-2 | `mcp-integrations-f0-v3` | meta, stealth, deepseek | meta+deepseek | 3× revisa |
| F0-3 | `mcp-integrations-f0-v4` | meta, stealth, deepseek | meta+deepseek | 3× revisa |

- **Recibo da rodada F0-1** (via `xpz-llm-delegate`): `preferenceSource=orchestrator`,
  `effectivePreferredPath=…\preferred-reviewers.opencode.json`; por revisor `attemptRole=primary`,
  `fallbackOf` vazio, `countsForDiversity=true`; `closeoutReady=false`
  (`vnext-pending-resubmission`); `receiptAddendum` registra curadoria `not_applicable` e 4 estados.
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

## Referências

- `https://github.com/jkudish/jev-mcp` (MIT); `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md` — fronteira. `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md` —
  `commandcode/*` como **catálogo de vozes** do painel (não confundir com o endpoint do Jev).
