# xpz-mcp-integrations — design da skill (v7)

## Papel do documento

Design **vivo** (não congelado) da skill `xpz-mcp-integrations`, com decisões de **2026-10-02** e a
evidência empírica coletada.

- **v2** pré-análise · **v3** F0-1 (4 titulares) · **v4** F0-2 · **v5** F0-3 · **v6** F0-4 · **v7**
  F0-5 (todas as rodadas de refino: opencode; veredito **revisa**).

**Processo de F0:** refinar via **opencode** até o autor não identificar mais gaps; depois submeter a
**uma validação final com um modelo mais caro** — que é **insumo, sem poder decisório** (voz única =
segunda opinião; "caro" ≠ diversidade) e **não libera implementação**. A liberação exige **painel
diverso sobre a versão final**: **≥2 Criadores de Modelo** (piso do `15`) **e ≥1 voz fora do harness
dominante** (quebra cegueira correlacionada). Alternativa auditada: o humano **congela**
(`resubmissionDeclinedByHuman` + quem + motivo + `RoundId`). Até lá, `vNextState=pendingResubmission`
e nada é implementado.

Nota do `15` sobre congelamento: a arquitetura **não é mais reaberta** nas rodadas F0-4/F0-5; as
objeções restantes são de **precisão de especificação/procedimento**, não de design. Isso é sinal
favorável ao gatilho de congelamento, que **segue sendo decisão humana**.

Este documento não é doc operacional; o contrato operacional viverá em `xpz-mcp-integrations/SKILL.md`.

## Problema

Usuários das skills XPZ com acesso ao **Jev/System One** não têm caminho gerenciado para
instalar/auditar/reparar/atualizar/remover esse componente MCP. A configuração validada na máquina
de referência é manual e **não portátil** (path pessoal absoluto, rede/cache em runtime, transitivas
sem pin, chave amarrada ao `auth.json` do OpenCode). A `xpz-skills-setup` não cobre MCP de terceiros.

## Escopo da v1

- **Componente:** Jev/System One via `@jkudish/jev-mcp`. **Clientes:** OpenCode e Codex.
- **Plataforma:** **Windows** (KB/IDE do usuário típico). **Exceção:** cofre DPAPI **sem roaming**.
- **Ciclo:** detectar → instalar → auditar → reparar → atualizar → remover. **Credencial:** cofre
  neutro. **Público:** comunidade.
- **A v1 (OpenCode + Codex) só se completa ao fim do F2**; F1 sozinho não é a v1.

## Não-escopo da v1

Fork; Cursor e Claude Code; macOS/Linux; instalar ferramentas; criar conta; `skills/jev/`; uso
automático; MCPs sem descritor; vender fornecedores não provados como validados.

## Decisões travadas (2026-10-02)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Nome | `xpz-mcp-integrations` |
| 2 | Runtime | pacote **vendorizado** e pinado; **sem `npx`** |
| 3 | Node | detectar ausência **e** `< 22`; `winget` id `OpenJS.NodeJS.LTS` com aprovação; com `nvm`/`fnm`/`volta`, **relatar**; node sem npm = instalação corrompida → relatar |
| 4 | Plataforma | **Windows** (cofre sem roaming) |
| 5 | Escopo v1 | **OpenCode + Codex** (completa no F2) |
| 6 | Credencial | **cofre** DPAPI, **vault-first**; env = **override explícito**; `auth.json` só import opcional |
| 7 | Fornecedor | 5 modos; `compatible`/Command Code **parcial**; outros 4 **experimental opt-in** |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade |

## Arquitetura

### Motor dirigido por descritor

Componente = comando, stdio, mapa de env, fonte de credencial, clientes, validação. Descritor de
dados (`components/jev.json`) com **schema fail-closed** e self-test. Vocabulário de evidência
seguindo a taxonomia do `02` (Hipótese → Inferência forte → Evidência direta) — sem "promoção
reconciliada" (termo inexistente no `02`).

### Contrato dos motores novos

Seguem `02`: **JSON de máquina**, `-InputPath`, `-WhatIf`/`ShouldProcess`. Labels `*_SKIPPED` sob
`-WhatIf` são propriedade de `xpz-skills-setup/SKILL.md`. **Tabela de contrato por motor
(pré-requisito do F1):** parâmetros aceitos (`-AsJson`? `-CheckUpdates`? `-CredentialSource`?),
classe (`blocking|warn|info`) por estado, e `exitCode`. **Obrigação (não asserção):** a tabela
**provará** não-colisão com `msbuild-exit-codes.catalog.json`, reservando faixa fora dele.

### Fronteira com `xpz-skills-setup` e aresta de dependência

- `xpz-mcp-integrations`: MCP **externos opcionais**; `xpz-skills-setup`: skills, instrucionais,
  `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- Arquivos de cliente compartilhados: **merge sempre**, **backup** antes de escrever, **nunca**
  remover entrada alheia. **Contrato do backup (novo):** local, retenção e ACL (o `opencode.jsonc`
  alheio pode conter segredos de outros MCPs), com restore. Os consumidores atuais
  (`Install-OpenCodeReviewerRoAgent.ps1`, `Install-CursorGlobalInstructionsMcp.ps1`) **não** fazem
  backup hoje — item de trabalho se tocados.
- Ponteiro **documental** na setup. A skill entra sozinha no inventário; **registrar ≠ instalar**.
  `AGENTS.md` precisa de **duas** entradas: a skill nova **e** `xpz-codex-apply-patch-alternative`
  (já ausente; `README.md` já a lista).
- **Aresta de dependência:** o `OpenCodeJsoncSupport.ps1` (a **criar** no F1-pre; dono-doc
  **proposto** `xpz-llm-delegate/SKILL.md`) ganhará consumidor novo; a aresta se registra nos dois
  documentos donos.
- **Avaliação de rastreabilidade privada (`AGENTS.md`, "moldes sanitizados"):** o F1 commita
  **fixtures sanitizadas** de `dist` de terceiro e de formatos de config de cliente — isso **é**
  molde sanitizado novo publicável → avaliar anotação no `GeneXus-XPZ-PrivateMap` (mesmo que a
  conclusão seja "nada a registrar").

### Suporte JSONC compartilhado — frente própria (F1-pre), arquivo **a criar**

Diagnóstico verificado no código:

- `Find-JsoncMatchingBrace` (embutida em `Install-OpenCodeReviewerRoAgent.ps1`): ciente de string,
  **cego a comentários**.
- `Find-JsoncKeyValueSpan` (mesmo arquivo): **não** ciente de string (comentário promete heurística
  de aspas **inexistente**).
- `ConvertFrom-Jsonc` (`OpenCodeReviewerRoGuard.ps1`): char-a-char, string/comentário-aware;
  **scanner de referência**; **sem** trailing comma.
- `ConvertFrom-JsoncText` (`Build-LlmDelegateCapabilityManifest.ps1`): regex, **não** string-safe;
  **remove** trailing comma.
- **Bug vivo:** `Install-OpenCodeReviewerRoAgent.ps1:252` valida o arquivo inteiro com
  `ConvertFrom-Jsonc` → trailing comma alheio derruba com `BLOCK`.

**Correção:** o `OpenCodeJsoncSupport.ps1` (**a criar**) extrai o **scanner** do `ConvertFrom-Jsonc`
**e mantém** a tolerância a trailing comma; política de trailing comma é pré-condição dura. O passo
de **maior risco** é a **extração** (tirar código de dois arquivos e trocar a origem), não o último.
**Ordem:** núcleo + instalador primeiro; **manifesto de capacidade por último**, com pin de fallback.
Consumidores refatorados: `OpenCodeReviewerRoGuard.ps1`; `Build-LlmDelegateCapabilityManifest.ps1`;
`Install-OpenCodeReviewerRoAgent.ps1` (**hoje** dot-sourceia o Guard em `:49`). **Fixtures negativas**
(pré-condição): chave comentada; forma-de-chave dentro de string; `{}` dentro de `/* */`; `//` dentro
de string; trailing comma. **Revisão do F1-pre:** painel com **≥2 Criadores** (piso do `15`) **e
obrigatoriamente ≥1 voz fora do harness afetado** — não substituir uma condição pela outra.

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`; **versão fixada `0.13.0`**; **mecanismo de pin = sha512 + tag**;
  **valores** = fatos externos.
- **Evidência commitada (pré-condição de qualquer motor):** fixtures **sanitizadas** do `dist`
  (trecho mínimo de `provider.js` que sustenta cada linha da tabela, `engines.node`, boot
  `initialize`) **com o aviso de licença MIT do pacote junto do artefato** versionado. Até então, a
  **tabela de Fornecedor é hipótese** (ver Apêndice).
- **Artefatos commitados:** `package.json` de pin **exato** (`"0.13.0"`) + `package-lock.json`.
  **Lockfile = fonte autoritativa de integridade**; `dist.integrity` do descritor = **asserção**
  (declarar **algoritmo e conjunto coberto** — conteúdo, independente de path/junction).
- **Vendor:** `npm ci --ignore-scripts --no-audit --no-fund` em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`, exposto pela indireção `current`
  (`...\current\node_modules\@jkudish\jev-mcp\dist\index.js`) que **launcher e auditoria** resolvem.
  **Switch por re-apontamento** (não atômico no Windows): remover+recriar link; **citar o precedente
  do repo** (`historico/pretooluse-auto-allow-trajetoria-20260628`: `Remove-Item -Recurse` numa
  junction **pode apagar o alvo**; remover com `[System.IO.Directory]::Delete($link,$false)`);
  symlink exige privilégio/Developer Mode → **junction fallback**. **Detecção de "MCP em execução":**
  por lock de arquivo aberto / verificação de processo (mecanismo declarado no F1) → **falha segura**
  com mensagem, sem retry cego. `npm` é pré-requisito próprio; **sem rede no runtime** do wrapper; o
  pacote não é comitado.
- **Re-verificação isolada do `dist` (gating de F1) — duas fases:**
  1. **Instalação** (rede de registro permitida): `npm ci` contra o lockfile pinado, `--ignore-scripts
     --no-audit --no-fund`, cache/registro declarados.
  2. **Execução** (isolamento): **sem rede, sem chave real** — allowlist de hosts, ocorrências de
     `fetch`/`undici`/`HttpClient`/telemetria, comportamento das **N transitivas do lockfile** (N do
     lock). Limites reconhecidos: a varredura é **estática/heurística**; um boot sem chave/rede **não**
     exercita todos os ramos de provider. **Relatório sanitizado** (dump de env sem valores de segredo).

### Launcher portátil (molde gerado pela skill)

- **Comando = launcher PowerShell** (`["pwsh","-NoProfile","-File","<launcher>.ps1"]`): desprotege a
  chave via **DPAPI** em memória (**nunca argv**); resolve o `node` **absoluto**; inicia
  `...\current\node_modules\@jkudish\jev-mcp\dist\index.js` com a variável **só** no env do filho.
- **Stdio — rota travada `& node` no próprio processo** (herda stdio). **Invariante dura:** silenciar
  `$ProgressPreference`/`$InformationPreference`; **nenhum** `Write-*` para stdout; logs só em
  stderr/arquivo; nenhum valor de chave em log; **`exit $LASTEXITCODE` como última instrução**, sem
  statement intermediário que o sobrescreva; provar **payload binário grande** (sem re-encode).
  `ProcessStartInfo`+proxy = **fallback documentado**. **Caminhos negativos (pré-filho):** cofre
  ausente, blob corrompido (`Unprotect` lança), DPAPI em outra máquina/usuário, `node` não resolvido —
  cada um com **exit code próprio** na tabela de contrato e **zero bytes** no stdout. Self-test cobre
  caminho feliz **e** negativos.
- **Runtime:** exige `pwsh` (7.4+); auditoria reporta se faltar. Rota Node→pwsh (desproteger por
  filho) **descartada** (transcrição).
- **Staleness do `node`:** auditoria detecta `node_path_nao_resolve` → **reparo = re-resolver e
  re-emitir o launcher** (sem reinstalar Node).
- **Marcador de propriedade:** sentinela no cabeçalho + **manifesto**; uninstall remove **só se**
  sentinela **e** path no manifesto; órfão = reportar.

## Fornecedor

Cinco modos (`JevProvider`). **Detalhes de wire = hipótese** até as fixtures sanitizadas (Apêndice).

- `compatible` **não** é "API OpenAI qualquer": exige o contrato System One/Jev; a URL vai como veio;
  `cloudflare`/`vercel` não são intercambiáveis; sem `JEV_PROVIDER` (`auto`), infere pela presença de
  env. **`compatible` = parcial:** prova o handshake MCP, não a decisão E2E.
- **`endpoint_nao_verificado` × `compatible` (fechar):** a allowlist de hosts é derivada do
  **provedor/preset escolhido**; para `compatible` de terceiro (URL arbitrária), o estado é **`warn`
  com confirmação explícita do usuário** (não blocking), ou a exceção de `compatible` é declarada.
  Regra única escrita no F1.
- **Command Code** = preset sugerido, nunca presumido. **Experimental opt-in:** os 4 não provados
  ficam fora do caminho feliz e dos self-tests do F1. **Import `auth.json`:** opcional, com ressalva
  (credencial `commandcode/*` do OpenCode é de **gateway de LLM**).

## Credencial

- **Cofre:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\` (`%LOCALAPPDATA%` do ambiente; separado do
  `vendor-*/`). **Blob:** DPAPI `CurrentUser`, **sem entropia adicional**, **com campo `version`**
  (evolução do formato).
- **Entrada:** `Read-Host -AsSecureString`; **sem persistência** em transcript/history
  (`Set-PSReadLineOption -HistorySaveStyle SaveNothing`; não iniciar transcript); não-eco em log.
- **Backup do cofre:** local, retenção, **mesma ACL** (backup herda a sensibilidade), restore.
- **ACL:** `ICACLS` (remover herança + só o dono). **Não** hospedar segredos de privilégio maior que
  a chave do provedor (ex.: credenciais de produção GeneXus) — o threat model não cobre isso.
- **Rotação/revogação:** re-cifrar o blob; **revogação por comprometimento** = apagar o blob + revogar
  a chave no provedor (≠ "preservar o cofre" do uninstall normal). Avisar MCP em execução.
- **Vault-first (default):** (1) cofre; (2) env como **override explícito** (`-CredentialSource env`);
  `credencial_divergente_env_vs_cofre` = **blocking até confirmação**.
- **Limite honesto:** DPAPI protege em repouso; não contra processo do mesmo usuário, inspeção do env
  do filho, nem roaming. **Fronteira:** pacote + transitivas + endpoint. Chave nunca
  impressa/logada/copiada.

## Adaptadores de cliente (v1)

- **OpenCode** — `~/.config/opencode/opencode.jsonc`, `mcp.jev` (`type: local`,
  `command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`). Merge
  via o **suporte JSONC**; backup (contrato acima); idempotente. Entrada `jev` divergente →
  `entrada_em_conflito`. **Shape = fato externo** + **fixture sanitizada** do `opencode.jsonc` no F1.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**) com prova empírica: env em
  **sub-tabela**, literal `'...'`, span até próximo cabeçalho não-filho, `enabled=false` para manter a
  config; remover a seção só no desinstalar. **`env_vars` filtra o herdado** → **mitigação:** o
  launcher define um **conjunto mínimo explícito** (`SystemRoot`, `TEMP`/`TMP`, `PATH` mínimo para
  `node`/DLLs, ou resolve tudo por caminho absoluto) e **não** depende de herança ampla. Fixture do
  `config.toml` (sanitizada) no F2.

## Auditoria (estados e contrato)

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`. **Tabela estado → `exitCode`/classe
  por motor.** **Precedência de versão:** `versao_defasada` (pin do descritor) avalia **antes** de
  `vendor_divergente` (lock); rótulo combinado definido no F1.
- **Offline:** `OK`; `ausente`; `entrada_quebrada`/`entrada_divergente`/`entrada_em_conflito`;
  `versao_defasada`; `vendor_ausente`/`vendor_divergente`; `launcher_ausente`/`launcher_divergente`;
  `node_ausente`/`node_incompativel`/`node_path_nao_resolve`; `pwsh_ausente`; `fornecedor_ausente`;
  `fornecedor_nao_validado` (**warn**); `credencial_ausente`; `credencial_divergente_env_vs_cofre`
  (**blocking**); `endpoint_nao_verificado` (**blocking** por padrão; `warn`+confirmação p/ o
  `compatible` de terceiro); `acl_nao_aplicavel` (**warn**).
- **Online opt-in** (`-CheckUpdates`): `atualizacao_disponivel` (registro remoto) — informa, nunca
  auto-atualiza; fora do gate offline. Canonicalização de path (case-insensitive, barras, EOL) antes
  de `entrada_divergente`.

## Atualizar e remover

- **Atualizar:** consciente (release notes, breaking changes, backup, re-apontamento, teste,
  rollback). Nunca por existir versão nova.
- **Remover:** manifesto registra **referências por cliente**; o launcher só sai quando **não restar
  referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre,
  `auth.json`, fornecedor e demais MCPs; no Codex, `enabled=false` quando manter a config.

## Testes

- **Self-tests offline:** detecção; merge JSONC (fixtures negativas); idempotência; backup+restore;
  rollback; schema do descritor; **round-trip DPAPI** (segredo fictício, efêmero); **re-apontamento**
  (concorrência + MCP em execução + remoção segura por tipo de link); **launcher** com filho falso
  (stdio binário, zero bytes no stdout além do filho, exit code) **e caminhos negativos pré-filho**
  (cofre ausente/corrompido, DPAPI de outra máquina, node não resolvido) com exit codes próprios.
- **Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
  Self-tests de **TOML** no **F2**.
- **E2E** com `jev_classify` = validação manual opt-in; pré-requisito de qualquer "validado".

## Documentação e paridade

- `README.md` trilíngue — skills em **duas listas por língua** (abertura + seção "Skills para
  agentes") ×3 = seis pontos; `CHANGELOG.md` trilíngue; **`SECURITY.md` trilíngue** (seção do cofre
  nas três, mesma posição).
- `09` (formato completo: `Dono:` + `Validação:`/`Tokens:`/`Exit:`); `02` (contrato de motor).
- `08` — nomear as seções exatas a tocar (ou retirar o item).
- `AGENTS.md` (duas entradas) + ponteiro documental na setup; `xpz-llm-delegate/SKILL.md` (dono
  proposto do JSONC + aresta).
- **`999`:** `:3283` já registra pin "sha512+tag, valores a re-verificar" e preset **parcial**;
  **`999:3277` (Maturidade)** ainda está defasado (não menciona validação cara como insumo, painel de
  liberação nem re-submissão) → **corrigir já**.
- Conformidade: `#requires -Version 7.4`; UTF-8 sem BOM; molde `.example.ps1`;
  `Test-XpzParameterNamingContract.ps1` **não** é gate geral (pontos: `02:972/977`); não enumerar ≥2
  gates numa linha (`09:132`).
- **Ledger:** efêmero/gitignored em `Temp/revisao-por-pares/<RoundId>/` (o `15` diz `<timestamp-ou-
  guid>`; `RoundId` é aceito). **Decisão: não introduzir ledger versionado**, **superando
  explicitamente** o precedente legado `.peer-review-rounds/matriz-14-*` (não rastreado); o `15`
  trata o livro-razão como **opcional** — esta frente o mantém efêmero (sem endurecer a norma).

## Fases

- **F0** — design + revisão (em andamento: F0-1..F0-5; faltam refinamento, **validação cara
  (insumo)** e **painel de liberação**).
- **F1-pre** (frente própria; revisão por painel **≥2 Criadores + ≥1 voz fora do harness afetado**) —
  criar `OpenCodeJsoncSupport.ps1` + fixtures negativas + migração dos consumidores + self-tests.
- **F1** — skill (OpenCode + núcleo) + descritor Jev + launcher + cofre/DPAPI + vendorizador +
  **evidência sanitizada do `dist`** + **re-verificação isolada gating** + self-tests + docs. **F1 ≠ v1.**
- **F2** — Codex (TOML, prova empírica) + self-tests TOML + auditoria de versão/drift + update/
  rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1` no mesmo
  `~/.cursor/mcp.json`).
- **F4** — opcionais: fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** — rota travada; invariante de stdout; caminhos negativos no self-test.
- **Merge TOML (Codex)** — prova empírica no F2; conjunto mínimo de env.
- **`dist`** — evidência sanitizada + re-verificação isolada em duas fases = gating; refletir em
  `SECURITY.md`; licença MIT junto das fixtures.
- **Fatos externos a re-verificar no F1/F2:** integridade/tag/commit; `engines.node`; tabela dos 5
  modos; boot MCP; shape do `opencode.jsonc`; semântica TOML do Codex.
- **Fornecedores experimentais** só sob opt-in. **Node/pwsh/npm** são dependências de runtime.

## Evidência coletada (2026-10-02)

- `node v24.18.0`/`python 3.14`; pacote vendorizado em pasta temporária; **boot offline** com env
  fictício + `initialize` MCP (`server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`).
- **`dist/provider.js` lido** em `%TEMP%\opencode\jev-probe\` (evidência **externa**; a commitar
  sanitizada antes do F1).
- **Rodadas F0** (vereditos efêmeros em `Temp/revisao-por-pares/<RoundId>/`; **submetida → produzida**):

| Rodada | RoundId (submetida) | Produzida | Revisores | Piso | Vereditos |
|---|---|---|---|---|---|
| F0-1 | `mcp-integrations-f0-v2` (v2) | v3 | meta, stealth, openai, anthropic | meta+openai+anthropic | 4× revisa |
| F0-2 | `mcp-integrations-f0-v3` (v3) | v4 | meta, stealth, deepseek | meta+deepseek | 3× revisa |
| F0-3 | `mcp-integrations-f0-v4` (v4) | v5 | meta, stealth, deepseek | meta+deepseek | 3× revisa |
| F0-4 | `mcp-integrations-f0-v5` (v5) | v6 | meta, stealth, deepseek | meta+deepseek | 3× revisa |
| F0-5 | `mcp-integrations-f0-v6` (v6) | v7 | meta, stealth, deepseek | meta+deepseek | 3× revisa |

- **Recibo F0-1** (via `xpz-llm-delegate`): `preferenceSource=orchestrator`,
  `effectivePreferredPath=…\preferred-reviewers.opencode.json`; `attemptRole=primary`, `fallbackOf`
  vazio, `countsForDiversity=true`; `closeoutReady=false` (`vnext-pending-resubmission`);
  `receiptAddendum` com curadoria `not_applicable`.
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

## Apêndice — tabela de fornecedor (HIPÓTESE, não spec)

Até a fixture sanitizada do `dist`, os valores abaixo são **hipótese** (não decisão): `typesafe`
(`TYPESAFE_API_KEY`, transport do SDK, `jev-latest`); `openrouter` (`OPENROUTER_API_KEY`,
`…/alpha/decisions`, headers, `jev-latest`→`jev-1.13`); `cloudflare` (`JEV_CLOUDFLARE_*`/
`CLOUDFLARE_*` + `CLOUDFLARE_ACCOUNT_ID`, `/accounts/<id>/ai/run`, `{model, input:{state,questions}}`);
`vercel` (`AI_GATEWAY_API_KEY`, transport do SDK); `compatible` (`JEV_API_KEY`, POST na URL completa,
`{model,state,questions}` → `{answers,usage?}`; **parcial**).

## Referências

- `https://github.com/jkudish/jev-mcp` (MIT); `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md`; `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md` —
  `commandcode/*` como **catálogo de vozes** (não confundir com o endpoint do Jev).
