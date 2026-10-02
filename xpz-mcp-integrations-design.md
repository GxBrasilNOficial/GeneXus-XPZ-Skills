# xpz-mcp-integrations — design da skill (v21)

## Papel do documento

Design **vivo** (não congelado) da skill `xpz-mcp-integrations`, com decisões de **2026-10-02** e a
evidência empírica coletada.

- **v2** pré-análise · **v3** F0-1 (4 titulares) · **v4–v8** refinos opencode (segundas opiniões) ·
  **v9–v20** validações caras · **v21** **reorganização editorial** (separa DECISÃO de OBRIGAÇÃO DE
  IMPLEMENTAÇÃO; marca o ADIADO). A v21 não reabre decisões.

**Estrutura:** o **corpo** carrega decisão, escopo, fronteira, contrato mínimo, fases e riscos. O
**Anexo A** carrega o detalhe técnico já decidido, a provar por self-test no F1-pre/F1/F2. A seção
**Adiado / escopo-futuro** carrega o que sai da v1.

**Autor e diversidade:** `authorFamily=deepseek`. Revisores de famílias distintas da do autor; as
rodadas opencode (meta+deepseek) são **segundas opiniões**. **Liberação** exige **≥2 Criadores
distintos do autor** + **≥1 voz fora do harness dominante** (endurecimento desta frente). Alternativa
auditada: humano **congela** (`resubmissionDeclinedByHuman` + quem + motivo + `RoundId`). Até lá,
`vNextState=pendingResubmission`; nada é implementado.

## Problema

Usuários das skills XPZ com acesso ao **Jev/System One** não têm caminho gerenciado para
instalar/auditar/reparar/atualizar/remover esse componente MCP. A configuração validada é manual e
**não portátil** (path pessoal absoluto, rede/cache em runtime, transitivas sem pin, chave amarrada ao
`auth.json` do OpenCode). A `xpz-skills-setup` não cobre MCP de terceiros.

## Escopo da v1

- **Componente:** Jev/System One via `@jkudish/jev-mcp`. **Clientes:** OpenCode e Codex.
- **Plataforma:** **Windows** (KB/IDE do usuário típico). **Exceção:** cofre DPAPI **sem roaming**.
- **Ciclo:** detectar → instalar → auditar → reparar → atualizar → remover. **Credencial:** cofre
  neutro. **Público:** comunidade. **A v1 (OpenCode + Codex) completa no F2**; F1 ≠ v1.

## Não-escopo da v1

Fork; Cursor e Claude Code; macOS/Linux; instalar ferramentas; criar conta; `skills/jev/`; uso
automático; MCPs sem descritor; vender fornecedores não provados como validados.

## Decisões travadas (2026-10-02)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Nome | `xpz-mcp-integrations` |
| 2 | Runtime | pacote **vendorizado** e pinado; **sem `npx`** |
| 3 | Node | ausência **e** `< 22`; `winget` id `OpenJS.NodeJS.LTS` com aprovação; com `nvm`/`fnm`/`volta`, **relatar**; node sem npm = corrompido → relatar |
| 4 | Plataforma | **Windows** (cofre sem roaming) |
| 5 | Escopo v1 | **OpenCode + Codex** (completa no F2) |
| 6 | Credencial | **cofre** DPAPI, **vault-first**; env = **override explícito**; `auth.json` só import opcional |
| 7 | Fornecedor | 5 modos; `compatible`/Command Code **parcial**; outros 4 **experimental opt-in** |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade |

## Arquitetura — decisões

### Motor dirigido por descritor

Componente = comando, stdio, mapa de env, fonte de credencial, clientes, validação. Descritor de dados
(`components/jev.json`) com **schema fail-closed** e self-test. O descritor declara, por fornecedor,
**`secretEnvVar`**, **vars públicas permitidas**, **campos obrigatórios** e **regras de exclusividade**;
a **exceção de endpoint** do modo `compatible` é campo explícito. Detalhe: **Anexo A.1**.

### Classes de artefato

| Classe | Contrato |
|---|---|
| **Biblioteca dot-source** (`OpenCodeJsoncSupport.ps1`) | sem JSON de stdout, sem `-InputPath`, sem `ShouldProcess`; fail-closed se ausente |
| **Diagnóstico read-only** (auditor) | JSON de máquina, `overall`, tabela estado→`exitCode`/classe, `-InputPath`; sem `-WhatIf` |
| **Mutador** (instalar/reparar/remover/atualizar/vendorizar) | JSON de máquina, `-WhatIf`, `exitCode`, backup transacional |

**Faixa de `exitCode` reservada no F1-pre** (não-colisão com `msbuild-exit-codes.catalog.json`; tabela
antes do motor). Motores com `-InputPath` entram na lista de `Test-XpzParameterNamingContract.ps1`
(`02:972/977`). **Vocabulário de evidência:** o `02` é centrado em XML → **declarar extensão** para
artefatos externos, com rótulo próprio.

### Fronteira com `xpz-skills-setup` e aresta de dependência

- `xpz-mcp-integrations`: MCP externos opcionais; `xpz-skills-setup`: skills, instrucionais,
  `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- **Arquivos de cliente compartilhados:** escrita **serializada + transacional**, com lock próprio,
  validação de atributos em toda a ancestralidade e promoção atômica. O lock serializa **esta skill**;
  contra terceiro que o ignore, a detecção é **best-effort**. Protocolo completo: **Anexo A.2**.
- Ponteiro **documental** na setup (fora do recibo; anti-padrão `reviewer-ro`). Dono do registro =
  `xpz-skills-setup`. **`AGENTS.md`/`README.md`:** **reconciliar** as listas (três seções do README +
  enumeração vigente do AGENTS), **adicionando só o que faltar** (`xpz-codex-apply-patch-alternative`
  já aparece em `AGENTS.md:11`; conferir a enumeração `:49` sem assumir).
- **Aresta de dependência:** `OpenCodeJsoncSupport.ps1` (a **criar**; dono-doc proposto
  `xpz-llm-delegate/SKILL.md`) ganha consumidor novo; registrada nos dois donos.
- **Rastreabilidade privada:** fixtures sanitizadas de `dist` são molde publicável → avaliar
  `GeneXus-XPZ-PrivateMap`; reconciliar `README.md:107` × `AGENTS.md:92-96`. **Licença:** cópia
  integral MIT + atribuição.

### Suporte JSONC compartilhado — frente própria (F1-pre)

Os motores JSONC hoje espalhados na raiz são insuficientes e há **bug vivo** em
`Install-OpenCodeReviewerRoAgent.ps1:252`. **Decisão:** criar **uma biblioteca única** —
`OpenCodeJsoncSupport.ps1`, arquivo **a criar** — implementando um ***localizador estrutural***
(tokenizador + busca por caminho estrutural + operações sobre spans que nunca recaem em
comentário/string), e **migrar todos os consumidores** para ela. O F1-pre é frente própria, com painel
de ≥2 Criadores distintos do autor + ≥1 voz fora do harness afetado.

Diagnóstico verificado, matriz de migração, golden dividido, fixtures negativas, política de chaves
duplicadas e ordem de execução: **Anexo A.3**.

### Execução do MCP — vendorização

- **Pacote:** `@jkudish/jev-mcp`; **versão `0.13.0`**.
- **Identidade do artefato = `integrity` sha512 do tarball** no **lockfile comitado**; o **commit Git é
  proveniência**, não âncora.
- **Manifesto de árvore esperado, comitado**, gerado em release controlada; o installer compara a
  árvore instalada e **rejeita** divergência.
- **`npm ci --ignore-scripts`** (o pacote declara `prepare`; usamos o `dist` pré-compilado) em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`.
- **Catálogo de bundles aprovados** versionado: update/rollback **só** consomem entradas do catálogo;
  `-CheckUpdates` **apenas informa**. Obter bundle novo = **atualizar o repositório/skill**.
- **Sem indireção mutável**: launcher versionado por path absoluto; **sem junction/symlink** (hazard de
  `historico/...20260622-20260922.md:48`).
- **Evidência sanitizada do `dist`, commitada com proveniência, é pré-condição de qualquer motor.** Até
  lá, a tabela de Fornecedor é **hipótese**.
- **Semântica de rede (3 contextos):** (1) instalador/vendorizador: sem registro fora de install/update;
  (2) launcher/MCP: só o endpoint; (3) teste isolado — **rebaixado a endurecimento opt-in** (ver
  **Adiado**).
- **Caminhos/segurança:** todo caminho gerenciado sob `%LOCALAPPDATA%\xpz-mcp-integrations` após
  **canonicalização**, **rejeitando reparse points em toda a ancestralidade**; **ACL antes de
  persistir**; escrita atômica.

Identidade/cadeia, campos do manifesto e do catálogo, bootstrap executável, retenção e rollback:
**Anexo A.4**.

### Launcher portátil (molde gerado pela skill)

- **Comando = launcher PowerShell** (`["pwsh","-NoProfile","-File","<launcher-<versao>.ps1"]`).
- **Rota travada = API nativa `CreateProcessW`** com **`CREATE_SUSPENDED`** + **Job Object** +
  `ResumeThread` (rota **única**). **`ProcessStartInfo` DESCARTADO**; **`& node` DESCARTADO**.
- **Ambiente do filho = limpo + allowlist do descritor** (não herda): só a variável secreta do modo, as
  vars públicas permitidas daquele modo lidas do `config.json`, e o mínimo de sistema/runtime.
- **Invariante mecanizada:** nenhum byte fora do filho em stdout; **exit code = do filho**; sem chave em
  log.
- **Runtime:** exige `pwsh` (7.4+). **Staleness do `node`:** reparo = re-resolver e re-emitir launcher.
- **Marcador de propriedade:** sentinela + manifesto; uninstall remove só se sentinela **e** path no
  manifesto; órfão = reportar.

Sequência nativa completa, limpeza em falha pós-criação, política de terminação/árvore e lista de
invariantes a mecanizar: **Anexo A.1**.

### Detecção de pré-requisitos

Espelhar `GeneXusPythonPrerequisite.ps1`/`Test-XpzPowerShellRuntime.ps1`: **executável utilizável de
verdade** (rejeitar stub `WindowsApps`/alias da Store) para `node`/`npm`/`pwsh`. A **versão de Node/npm**
usada na liberação é **fixada no catálogo** e **gated** (`>= 22`): `< 22` é bloqueante, acima disso é
reportada. Escopo do manifesto × runtime Node: **Anexo A.5**.

## Fornecedor

Cinco modos. **Wire = hipótese** até as fixtures (Apêndice). O launcher injeta **só** a var do modo
selecionado:

| Modo | `secretEnvVar` | Vars públicas / obrigatórias | Status |
|---|---|---|---|
| `typesafe` | `TYPESAFE_API_KEY` | `JEV_MCP_MODEL` (default `jev-latest`) | experimental opt-in |
| `openrouter` | `OPENROUTER_API_KEY` | `JEV_OPENROUTER_BASE_URL` | experimental opt-in |
| `cloudflare` | `CLOUDFLARE_API_TOKEN` (ou `JEV_CLOUDFLARE_API_TOKEN`) | `CLOUDFLARE_ACCOUNT_ID` (**não-secreta**), `JEV_CLOUDFLARE_BASE_URL` | experimental opt-in |
| `vercel` | `AI_GATEWAY_API_KEY` | — | experimental opt-in |
| `compatible` | `JEV_API_KEY` | `JEV_API_BASE_URL` (**URL completa**), `JEV_MCP_MODEL` | **parcial** |

- `compatible` exige o contrato System One/Jev; URL vai como veio; `cloudflare`/`vercel` não
  intercambiáveis. **`auto`:** com múltiplas famílias de env setadas, exigir `JEV_PROVIDER` explícito.
- **`endpoint_nao_verificado` — regra única:** presets fechados = **blocking** se host divergir;
  `compatible` de terceiro = **`warn` + confirmação explícita**. Host/caminho **redigidos** antes da
  confirmação.
- **Registro de configuração não secreto** `%LOCALAPPDATA%\xpz-mcp-integrations\config.json` (ACL
  só-dono; UTF-8 sem BOM; schema versionado) é a **fonte persistente das variáveis públicas** — é dele
  que o launcher reconstrói o ambiente do filho. **Nunca** contém a chave. Schema e regras de
  invalidação: **Anexo A.6**.
- **Cofre e tipo de credencial:** o cofre guarda o **modo ativo** + metadados do **tipo** (qual
  `secretEnvVar`), **sem** registrar o segredo em claro; trocar de modo exige re-entrada.
- **`compatible` = parcial** (handshake, não E2E). **Command Code** = preset sugerido. **Experimental
  opt-in:** 4 não provados fora do caminho feliz e dos self-tests do F1. **Import `auth.json`:**
  opcional, com ressalva (credencial `commandcode/*` do OpenCode é de gateway LLM).

## Credencial

- **Cofre neutro** em `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`, blob **DPAPI `CurrentUser`**,
  **vault-first**; env só com `-CredentialSource env`.
- `credencial_divergente_env_vs_cofre` é **blocking** quando **não** houve override.
- **`acl_nao_aplicavel` bloqueia mutadores de blob**, salvo modo inseguro explicitamente autorizado e
  rotulado.
- **Restore inter-máquina = re-inserir a chave** (DPAPI não roaming).
- **Limite honesto:** DPAPI protege em repouso; não contra processo do mesmo usuário, inspeção do env do
  filho, nem roaming. **Fronteira:** pacote + transitivas + endpoint. Chave nunca
  impressa/logada/copiada.

Formato do blob, entrada não-eco, ACL, backup/retenção/restore e os três eventos (rotação, remoção,
incidente): **Anexo A.7**.

## Adaptadores de cliente (v1)

- **OpenCode (F1):** raiz gerenciada na v1 = **global** `~/.config/opencode/`; **projeto-local
  (`.opencode/`) fora do escopo da v1**. Entrada `mcp.jev` (`type: local`, `command: ["pwsh",...]`,
  campo **`environment`**, não `env`). Merge transacional, idempotente. **Shape = fato externo** +
  fixture sanitizada no F1.
- **Codex (F2):** `~/.codex/config.toml`, `[mcp_servers.jev]`, com **biblioteca TOML vendorizada** no
  mesmo rigor do `jev-mcp`; o "subconjunto próprio" foi **descartado**. `env_vars` filtra o herdado →
  launcher define **conjunto mínimo explícito**. Fixture sanitizada do `config.toml` no F2.

Algoritmo de descoberta/precedência, casos de `entrada_em_conflito` e prova de round-trip TOML:
**Anexo A.8**.

## Auditoria (estados e contrato)

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`.
- **Estado por cliente:** `notConfigured` | `written` | `reloadPending` | `handshakeConfirmed` |
  `e2eOptInConfirmed`; `overall` **não** promove `written` a sucesso operacional; a skill informa a
  **ação de recarga/reinício** necessária.
- **Nada gravado sem confirmação:** a auditoria reporta estados e **oferece** a ação; a escrita depende
  de aprovação explícita.
- **Online opt-in** (`-CheckUpdates`): `atualizacao_disponivel` — informa, nunca auto-atualiza.

Lista completa de estados offline, classes (`blocking`/`warn`), tabela estado→`exitCode` e precedência:
**Anexo A.9**.

## Atualizar e remover

- **Reconciliação obrigatória:** antes de limpar/reparar, **ler as configs reais de cada cliente** e
  cruzar com o manifesto (o manifesto não é autoridade sobre a config viva); **plano/diff** + aprovação
  explícita por escrita/remoção material.
- **Atualizar:** consciente (release notes, breaking changes, backup, instalar + launcher + re-emitir
  config, teste, rollback por re-emissão). Nunca por existir versão nova.
- **Remover:** manifesto registra referências por cliente; launcher só sai quando **não restar
  referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre, `auth.json`,
  fornecedor e demais MCPs; no Codex, `enabled=false` quando manter a config.

## Testes — nível de decisão

- **Self-tests offline** cobrem detecção, JSONC, idempotência, escrita serializada/transacional,
  backup/restore/rollback, schema do descritor, round-trip DPAPI, re-emissão de launcher por versão e
  launcher com filho falso. Inventário executável: **Anexo A.10**.
- **O gate do `dist` no F1 é revisão estática do `dist` + boot sem chave.** O teste de egresso de rede
  contido **não** é gate (ver **Adiado**).
- **Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
  Self-tests de **TOML** no **F2**.
- **E2E** com `jev_classify` = validação manual opt-in; pré-requisito de `handshakeConfirmed`.

## Documentação e paridade

- `README.md` trilíngue (duas listas por língua ×3); `CHANGELOG.md` trilíngue; **`SECURITY.md`
  trilíngue** (seção do cofre nas três).
- `09` (`Dono:` + `Validação:`/`Tokens:`/`Exit:`); `02` (contrato + vocabulário); `08` (nomear seções ou
  retirar).
- **`AGENTS.md`/`README.md`:** **reconciliar** listas, **adicionando só o que faltar** (não assumir par
  fixo). Ponteiro documental na setup (fora do recibo); `xpz-llm-delegate/SKILL.md` (dono do JSONC +
  aresta).
- **`999`:** `:3283` com pin por commit/sha512 e preset **parcial**; `:3277` **alinhado** (validações
  caras feitas como **insumo**; falta o **painel de liberação** e a execução). **Consultar o `998`**
  (lição de exit-code `998:919-923`).
- Conformidade: `#requires -Version 7.4`; UTF-8 sem BOM (preservando BOM preexistente do arquivo do
  usuário); molde `.example.ps1`; `Test-XpzParameterNamingContract.ps1` **não** é gate geral; não
  enumerar ≥2 gates numa linha.
- **Ledger:** efêmero/gitignored em `Temp/revisao-por-pares/<RoundId>/`; **não versionar** (supera o
  precedente legado `.peer-review-rounds/matriz-14-*`).

## Fases

- **F0** — design + revisão (F0-1..F0-18; falta **painel de liberação**).
- **F1-pre** (frente própria; painel ≥2 Criadores distintos do autor + ≥1 fora do harness afetado) —
  criar `OpenCodeJsoncSupport.ps1` + golden + fixtures + **matriz de migração** + self-tests + inventário
  de consumidores na raiz; **reservar a faixa de `exitCode`**.
- **F1** — skill (OpenCode + núcleo) + descritor Jev + launcher (**`CreateProcessW` suspenso + Job
  Object + `ResumeThread`**, rota única) + cofre/DPAPI + vendorizador (baselines + manifesto + catálogo +
  ferramenta versionada) + **evidência sanitizada do `dist` com proveniência** + **revisão estática do
  `dist` + boot sem chave** (gate) + self-tests + docs. **F1 ≠ v1.**
- **F2** — Codex (biblioteca TOML vendorizada, round-trip + env mínimo) + self-tests TOML + auditoria de
  versão/drift + update/rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1`).
- **F4** — opcionais: fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** — `CreateProcessW` suspenso + Job Object + `ResumeThread` (rota **única**);
  invariante mecanizada; cancel/órfão.
- **Biblioteca TOML (Codex)** — vendorizada sob rigor; round-trip; fixture.
- **`dist`** — evidência sanitizada + **revisão estática + boot sem chave** como gate do F1; sem a
  evidência commitada, bloqueia.
- **Fatos externos a re-verificar no F1/F2:** sha512 do tarball; `engines.node`; tabela dos 5 modos;
  boot; shape do `opencode.json`/`.jsonc`; semântica TOML do Codex.
- **Fornecedores experimentais** só sob opt-in. **Node/pwsh/npm** são dependências de runtime.
- **Risco aceito da contenção opt-in:** sem o teste de egresso contido, a garantia de que a árvore
  vendorizada não fala com a rede fora do endpoint permanece **argumentativa** (código estático + boot),
  não **demonstrada**. Decisão consciente para não travar o F1 em pré-requisito de máquina.

## Adiado / escopo-futuro

- **Teste de egresso de rede contido (Windows Sandbox) — rebaixado a endurecimento opt-in, NÃO é gate
  do F1.** Motivo: exigir **Windows Sandbox** como pré-requisito explícito travava o F1 em máquina que
  não o tem (fail-closed por ambiente, não por defeito do artefato). O **gate do F1 passa a ser revisão
  estática do `dist` + boot sem chave**. Quem quiser o endurecimento roda o protocolo do **Anexo A.4.6**
  (topologia executável em Sandbox com `<Networking>Disable</Networking>`, controle positivo por
  processo filho, recibo verificado no host). O filtro `New-NetFirewallRule` permanece **só
  diagnóstico** — é por programa e **não** contém a árvore; **nunca** critério de aprovação.
- **AppContainer** — frente futura, até ter mecanismo de criação/lançamento e prova de que a árvore
  está no container **especificados e testados**.
- **F3** — Cursor e Claude Code.
- **F4** — fornecedores experimentais promovidos a validados; backend **Python** (`typesafe-mcp` no
  PyPI); fork/espelho do pacote.
- **Projeto-local do OpenCode** (`.opencode/`) — fora da v1.
- **macOS/Linux**; instalar ferramentas de terceiros; criar conta; `skills/jev/`; uso automático; MCPs
  sem descritor.

## Evidência coletada (2026-10-02)

- `node v24.18.0`/`python 3.14`; pacote vendorizado em pasta temporária; **boot offline** com env fictício
  + `initialize` MCP (`server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`).
- **`dist/provider.js` lido** em `%TEMP%\opencode\jev-probe\` (evidência **externa**; a commitar
  sanitizada com proveniência). **Fonte externa confirma:** `0.13.0` exige Node **≥ 22** e declara
  `prepare`; `provider.ts` confirma os 5 modos (usar o **commit/tarball aprovado**, não a `main`).
- **Rodadas F0** (vereditos efêmeros; `authorFamily=deepseek`):

| Rodada | RoundId (submetida) | Produzida | Revisores | Vereditos |
|---|---|---|---|---|
| F0-1 | `…-f0-v2` (v2) | v3 | meta, stealth, openai, anthropic | 4× revisa |
| F0-2..F0-6 | `…-f0-v3..v7` | v4..v8 | meta, stealth, deepseek (segundas opiniões) | 3× revisa |
| F0-7 (cara) | `…-f0-codex-gpt` (v8) | v9 | openai/gpt-5.6-terra (codex) | 1× revisa |
| F0-8 (cara) | `…-f0-codex-gpt-v9` (v9) | v10 | openai/gpt-5.6-terra (codex) | 1× revisa |
| F0-9 (cara) | `…-f0-codex-gpt-v10` (v10) | v11 | openai/gpt-5.6-terra (codex) | 1× revisa |
| F0-10 (cara) | `…-f0-codex-gpt-v11` (v11) | v12 | openai/gpt-5.6-terra (codex) | 1× gap bloqueante |
| F0-11 (cara) | `…-f0-codex-gpt-v12` (v12) | v13 | openai/gpt-5.6-terra (codex) | 1× gap bloqueante |
| F0-12 (cara) | `…-f0-codex-gpt-v13` (v13) | v14 | openai/gpt-5.6-terra (codex) | 4× gap bloqueante |
| F0-13 (cara) | `…-f0-codex-gpt-v14` (v14) | v15 | openai/gpt-5.6-terra (codex) | 2× gap bloqueante |
| F0-14 (cara) | `…-f0-codex-gpt-v15` (v15) | v16 | openai/gpt-5.6-terra (codex) | 2× gap bloqueante |
| F0-15 (cara) | `…-f0-codex-gpt-v16` (v16) | v17 | openai/gpt-5.6-terra (codex) | 4× gap bloqueante |
| F0-16 (cara) | `…-f0-codex-gpt-v17` (v17) | v18 | openai/gpt-5.6-terra (codex) | 1× gap bloqueante |
| F0-17 (cara) | `…-f0-codex-gpt-v18` (v18) | v19 | openai/gpt-5.6-terra (codex) | 3× gap bloqueante |
| F0-18 (cara) | `…-f0-codex-gpt-v19` (v19) | v20 | openai/gpt-5.6-terra (codex) | 2× gap bloqueante |

- **Recibo F0-1** (via `xpz-llm-delegate`): `preferenceSource=orchestrator`; `attemptRole=primary`,
  `countsForDiversity=true`; `closeoutReady=false` (`vnext-pending-resubmission`).
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

---

## Anexo A — Obrigações de implementação (a provar por self-test no F1-pre/F1/F2)

Tudo neste anexo já foi **decidido** no corpo nas versões v2–v20. Nada aqui é requisito novo; é o
detalhe que a implementação deve honrar e o self-test deve demonstrar.

### A.1 Launcher — sequência nativa, ambiente e terminação

**Sequência nativa (rota única):**

1. `CreateProcessW` com **`CREATE_SUSPENDED`**, pipes e **bloco de ambiente construído explicitamente**.
2. Associar o handle ao **Job Object** (`AssignProcessToJobObject`, `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`).
3. Só então `ResumeThread` — assim **nenhum filho nasce fora do Job**.

**Descartados (não reabrir):** `ProcessStartInfo` (não expõe criação suspensa; `Process.Start()` já
inicia o processo) e `& node` (exigiria expor a chave no ambiente do launcher).

**Falha pós-criação / pré-retomada:** se `AssignProcessToJobObject`, a criação dos pipes ou uma
revalidação falhar, **bloco de limpeza obrigatório** — fechar handles de I/O, `TerminateProcess`,
aguardar a terminação, liberar handles — e **só então** devolver erro. Self-test que **força** a falha de
associação ao Job.

**Ambiente do filho = limpo + allowlist do descritor (não herda):** o launcher monta o bloco com
**(a)** a **variável secreta do modo**; **(b)** as **variáveis públicas permitidas daquele modo, lidas do
`config.json`** (`JEV_API_BASE_URL`/`JEV_MCP_MODEL` no `compatible`; `JEV_OPENROUTER_BASE_URL`;
`CLOUDFLARE_ACCOUNT_ID`; etc.); **(c)** o **mínimo de sistema/runtime** (`SystemRoot`, `SystemDrive`,
`TEMP`/`TMP`, `PATHEXT`, `COMSPEC`, `PATH` mínimo). **Não** propaga variáveis de fornecedor **não
selecionado** nem o ambiente inteiro.

**Terminação/árvore:** **EOF/cancelamento** → fechar streams, prazo curto, **encerrar a árvore**;
**filho inesperado/órfão** → fechar pipes e propagar estado. Self-tests: cancelamento, órfão, stderr
intenso, término em tráfego bidirecional.

**Invariante mecanizada:** silenciar preferences; **nenhum `Write-*`** para stdout (scan estático);
logs só em stderr/arquivo; sem chave em log; **exit code = do filho**, propagado como última instrução;
provar **payload binário grande** (sem re-encode/deadlock) e **zero bytes** fora do filho; **negativos
pré-filho** com exit code próprio.

**Descritor — credencial por modo:** o descritor declara, para cada fornecedor, `secretEnvVar`, vars
públicas permitidas, campos obrigatórios e regras de exclusividade; a exceção de endpoint do
`compatible` é campo explícito. Schema **fail-closed** + self-test.

### A.2 Caminhos, atributos/ACL e escrita serializada e transacional

- **Alvo:** config do cliente, lock, temporário e backup devem ser **arquivos regulares**, **sem
  reparse point** (symlink/junction), **sem diretório/arquivo especial** — validado por `GetAttributes`
  **em todos os componentes do caminho até uma raiz confiável** (não só na folha), **revalidado
  imediatamente antes da promoção**.
- **Lock:** `<arquivo>.xpz-mcp.lock` (create-new / `FileShare.None`); falha → **recusar**.
- **Ramos separados:** **criação exclusiva** (`FileMode.CreateNew`) e **substituição** (`File.Replace`
  com backup). Antes da promoção, **revalidar identidade/atributos** (tamanho, mtime, hash)
  **imediatamente**.
- **Sequência:** ler+hash → calcular novo conteúdo → temp na mesma pasta → re-hash → **recusar se
  mudou** → backup imutável → check final (create×replace) → promoção atômica → idempotência por
  conteúdo.
- **Honestidade:** o lock serializa **esta skill**; contra terceiro que ignore o lock, a detecção é
  **best-effort** (re-hash + `File.Replace`). **Recuperação:** lock preso → instruir; crash →
  temp+journal limpos na re-execução; destino inexistente → criação.
- **Caminhos gerenciados:** tudo sob `%LOCALAPPDATA%\xpz-mcp-integrations` após **canonicalização**,
  **rejeitando reparse points em toda a ancestralidade** (não só na folha) e raízes de outro drive;
  **ACL aplicada antes de persistir**; escrita atômica.

### A.3 JSONC — localizador estrutural, migração e fixtures

**Diagnóstico verificado (motivação, não requisito novo):** `Find-JsoncMatchingBrace` ciente de
string/cego a comentário; `Find-JsoncKeyValueSpan` acha por `IndexOf` (comentário promete heurística de
aspas inexistente); `ConvertFrom-Jsonc` (Guard) é o scanner de referência **sem** trailing comma;
`ConvertFrom-JsoncText` (manifesto) é regex **não string-safe** que remove trailing comma e **também
dispara dentro de strings**; **bug vivo** em `Install-OpenCodeReviewerRoAgent.ps1:252`.

**Correção — *localizador estrutural*:** tokenizador → stream de tokens com spans; **unidade canônica =
code unit UTF-16** (`string` do .NET); **preservar encoding/BOM/EOL** do arquivo; buscar por **caminho
estrutural** (`mcp.jev`, `agent.reviewer-ro`); operações **sobre spans** que nunca recaem em
comentário/string. **"Byte-diff" = preservar regiões fora dos spans** (não igualdade integral).

**Matriz de migração obrigatória** (cada item aponta para a **biblioteca única**; o F1-pre só fecha com
trailing-comma e comentário/string passando por **cada rota real**):

| Consumidor | Defeito atual | Migra para |
|---|---|---|
| `Install-OpenCodeReviewerRoAgent.ps1` | `Find-JsoncMatchingBrace`/`Find-JsoncKeyValueSpan`; valida o arquivo inteiro (bug `:252`) | localizador estrutural |
| `OpenCodeReviewerRoGuard.ps1` | `ConvertFrom-Jsonc` (sem trailing comma) | suporte (scanner + trailing comma) |
| `Build-LlmDelegateCapabilityManifest.ps1` | `ConvertFrom-JsoncText` (regex não string-safe) | suporte (scanner) |
| `Test-OpenCodeReviewerRoSelfTest.ps1` + `Test-LlmDelegateCapabilityManifestSelfTest.ps1` | fixtures insuficientes | fixtures negativas novas |
| Futuros consumidores | — | biblioteca única |

**Golden dividido:** **paridade** só para entradas **já suportadas** pelo motor antigo; **regressão com
divergência esperada** para strings/comentários/trailing comma (o `ConvertFrom-JsoncText` antigo corrompe
`, }` dentro de string — divergir é o **objetivo**).

**Chaves duplicadas:** o tokenizador detecta duplicidade em cada objeto; duplicidade em qualquer
segmento do caminho-alvo ou na chave-alvo → `entrada_em_conflito` e **recusa** a escrita.

**Ordem:** núcleo+instalador primeiro, **manifesto por último** com **pin de fallback**; **passo de
maior risco = a extração**.

**Lockstep corrigido:** inventário/self-test de consumidores **na raiz**; **não** ampliar a auditoria de
`xpz-kb-parallel-setup` (o lockstep do `AGENTS.md` é para motor quebrado consumido por wrappers de KB
paralela — não este caso).

**Fixtures negativas:** chave comentada; forma-de-chave em string; `{}` em `/* */`; `//` em string;
`//` trailing; aspas escapadas; bloco não-terminado; trailing comma; edição fora de comentário/string;
**não-ASCII**.

**Revisão do F1-pre:** painel com ≥2 Criadores distintos do autor + ≥1 voz fora do harness afetado.

### A.4 Vendorização — identidade, manifesto, bootstrap e catálogo

#### A.4.1 Identidade e cadeia verificável

A **identidade do artefato = o `integrity` sha512 do tarball** registrado no **lockfile comitado**
(`resolved`+`integrity`); o **commit Git é proveniência**, não âncora (evita afirmar
`commit == tarball`). Se houver archive Git aprovado, a equivalência commit→tarball é **registrada e
verificada** explicitamente (sha512, conteúdo extraído, data, procedimento).

#### A.4.2 Manifesto de árvore esperado

`vendor/manifest.sha256`, **comitado**, **gerado em release controlada**, com metadados: **commit**,
**versão de npm e Node usadas**, **sha512 do tarball**, **sha256 por arquivo**, **data de captura**,
escopo. O installer **compara a árvore instalada** contra esse baseline e **rejeita**: arquivos
**ausentes ou excedentes**, **caminhos duplicados** após normalização, **reparse points**. Divergência de
**ferramenta** (npm/Node) é reportada **separada** da divergência do **pacote**.

#### A.4.3 Bootstrap executável e `npm ci`

- `npm ci --ignore-scripts --no-audit --no-fund` em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`; comparação contra o manifesto esperado.
- **`--ignore-scripts` justificado e testado:** o pacote declara `prepare`; usamos o `dist`
  pré-compilado. O teste prova que `dist/index.js` existe e o servidor sobe **sem** rodar `prepare`.
- `xpz-mcp-integrations/vendor/` contém o **`package.json` (pin exato) + `package-lock.json`**
  versionados; o installer **cria `vendor-<versao>\`, copia os dois para lá** e **só então** roda
  `npm ci`.
- O `manifest.sha256` cobre a **árvore `node_modules\*\*`**; os dois arquivos do projeto são cobertos
  pelos hashes commitados de `package.json`/lock (não pelo manifesto de árvore).
- **Sem indireção mutável:** launcher versionado por path absoluto; comando do cliente aponta para o
  launcher daquela versão. Update = instalar + launcher + re-emitir config; rollback = re-emitir config
  anterior. **Sem junction/symlink** (hazard de `historico/...20260622-20260922.md:48`).

#### A.4.4 Catálogo de bundles aprovados

`xpz-mcp-integrations/vendor/catalog.json` versionado — cada entrada com **descriptor, lockfile,
integridade do tarball, manifesto de árvore e template/hash de launcher**. Update/rollback **só**
consomem entradas do catálogo; `-CheckUpdates` **apenas informa** (nunca instala). Obter um bundle novo =
**atualizar o repositório/skill** (novo catálogo). Rollback re-emite a partir do bundle aprovado
anterior, com **retenção explícita** das versões instaladas.

#### A.4.5 Evidência commitada do `dist` (pré-condição de qualquer motor)

Em `xpz-mcp-integrations/fixtures/` (rastreada): trechos **sanitizados** de `provider.ts`/`provider.js`
(5 modos + vars), `engines.node` (**≥ 22**), `prepare` do `package.json`, boot `initialize`, **+ licença
MIT integral + atribuição**. **Proveniência por fixture:** `commit`, origem, hash, **data de captura**,
escopo — **sem** usar o README da `main` como prova da `0.13.0`. Até então, a tabela de Fornecedor é
**hipótese**.

**Gate do F1:** **revisão estática do `dist` + boot sem chave**.

#### A.4.6 Contenção de rede — protocolo de endurecimento **opt-in** (não é gate)

Preservado como procedimento disponível; **rebaixado** na v21 (ver **Adiado**).

- O filtro `New-NetFirewallRule` é **por programa** e **não** contém a árvore → **nunca** é critério de
  aprovação (só **diagnóstico**).
- A re-verificação isolada roda em **Windows Sandbox com `<Networking>Disable</Networking>`** (rede
  desabilitada para o sandbox inteiro, **incluindo filhos**; descartável).
- **Controle positivo:** tentar egresso **por um processo filho** e confirmar bloqueio. O **runtime Node
  dedicado** (cópia verificada) permanece como **alvo controlado**.
- **Topologia executável (protocolo):** (1) mapear a **árvore vendorizada** e o **runtime Node
  verificado** numa pasta **somente leitura** para o Sandbox; (2) rodar um **harness identificado por
  hash** dentro do Sandbox (rede desabilitada); (3) gravar o **recibo em pasta de saída separada**;
  (4) no **host**, verificar os **hashes**, a **identidade do Node**, o resultado do `initialize` e a
  **falha do egresso do processo filho**. **Evidência + limpeza** declaradas.
- **AppContainer:** adiado (ver **Adiado**).

#### A.4.7 Semântica de rede (3 contextos)

(1) instalador/vendorizador: sem registro fora de install/update; (2) launcher/MCP: só o endpoint;
(3) teste isolado: **A.4.6**, opt-in.

### A.5 Pré-requisitos — escopo do manifesto × runtime Node

Espelhar `GeneXusPythonPrerequisite.ps1`/`Test-XpzPowerShellRuntime.ps1`: **executável utilizável de
verdade** (rejeitar stub `WindowsApps`/alias da Store) para `node`/`npm`/`pwsh`.

O `manifest.sha256` cobre **`node_modules/**`** apenas (produção do npm), **invariante** entre versões
aceitas de Node; a **versão de Node/npm** usada na liberação é **fixada no catálogo** e **gated**
(`>= 22`) — divergência de Node é **bloqueante** se `< 22`, senão reportada. O **runtime dedicado do
teste isolado** é uma **cópia do Node da máquina** com **versão e hash registrados**, vinculada ao
catálogo; o launcher de produção usa o Node **absoluto** resolvido no install (mesmo gate).

### A.6 `config.json` — schema, origem e consumo

`%LOCALAPPDATA%\xpz-mcp-integrations\config.json` — **registro de configuração não secreto**, ACL
só-dono, UTF-8 sem BOM, **schema versionado**:

```
{ provider, model, publicEnv{...}, endpoint{ hash, confirmedAt, confirmedBy } }
```

- **Origem/override** por parâmetro do mutador; **validado contra o descritor** (só as vars públicas
  permitidas do modo).
- **Consumido** por launcher/auditor/reparo/re-emissão — é **dele** que o launcher reconstrói as
  variáveis públicas obrigatórias (inclusive o **endpoint completo** do `compatible`).
- **Nunca** contém a chave.
- `endpointHash` vincula a autorização; mudar provider/mode/model/URL **invalida**. Host/caminho
  **redigidos** antes da confirmação.

### A.7 Cofre — blob, entrada, backup e eventos

- **Local:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`.
- **Blob:** DPAPI `CurrentUser`, **sem entropia adicional**, **campo `version`**, e **metadados do tipo**
  (modo + `secretEnvVar`) — **sem** o tipo misturado ao valor.
- **Tabela fonte × modo × comportamento:** vault-first; env só com `-CredentialSource env`; auditor
  sinaliza `credencial_divergente_env_vs_cofre` (**blocking**) só quando **não** houve override.
- **Entrada:** `Read-Host -AsSecureString`; sem transcript/history; não-eco; **ACL antes de persistir**.
- **`acl_nao_aplicavel` — bloqueia mutadores de blob** (criação/import/rotação/restore), salvo modo
  inseguro explicitamente autorizado e rotulado.
- **Backup do cofre:** local, retenção, mesma ACL, restore. **Restore inter-máquina** = **re-inserir a
  chave** (DPAPI não roaming).
- **Três eventos:** rotação (re-cifrar), remoção (preservar), incidente (apagar blob + revogar no
  provedor + orientar restart).

### A.8 Adaptadores — descoberta, precedência e round-trip

**OpenCode — algoritmo de descoberta:** raiz gerenciada na v1 = **global** `~/.config/opencode/`;
candidatos **`opencode.json` e `opencode.jsonc`** nessa pasta; **projeto-local (`.opencode/`) fora do
escopo da v1** (declarado). **Precedência:** resolver `opencode.json` → `opencode.jsonc` (espelha o motor
atual); **sem precedência comprovada** se ambos existirem → `entrada_em_conflito` (bloquear sem
escrever). **Fixtures** para cada caso. Serializar para o formato efetivo (`.json` → JSON válido;
`.jsonc` → localizador estrutural). Entrada `mcp.jev` (`type: local`,
`command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`). Merge
transacional; idempotente. **Shape = fato externo** + fixture sanitizada no F1.

**Codex (F2):** `~/.codex/config.toml`, `[mcp_servers.jev]`. **Biblioteca TOML vendorizada** (pin pelo
commit do **próprio** lockfile + integridade + licença + re-verificação), no rigor do `jev-mcp`; o
"subconjunto próprio" foi **descartado** (a config usa arrays `args`/`env_vars`, mapa `env`,
possivelmente multiline). Prova de **round-trip** das formas reais (`command`, `args[]`, `env{}`,
`env_vars[]`, `enabled`, `startup_timeout_sec`); **proibido "span textual"**. **`env_vars` filtra o
herdado** → launcher define **conjunto mínimo explícito provado com filho falso** (`SystemRoot`,
`SystemDrive`, `TEMP`/`TMP`, `PATHEXT`, `COMSPEC`, `PATH` mínimo). Fixture sanitizada do `config.toml` no
F2.

### A.9 Auditoria — estados, classes e precedência

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`. **Tabela estado → `exitCode`/classe por
  motor** (faixa reservada no F1-pre). **Precedência:** `versao_defasada` (pin do descritor) antes de
  `vendor_divergente` (manifesto).
- **Estado por cliente:** `notConfigured` | `written` | `reloadPending` | `handshakeConfirmed` |
  `e2eOptInConfirmed`; `overall` **não** promove `written` a sucesso operacional; a skill informa a
  **ação de recarga/reinício** necessária.
- **Offline:** `OK`; `ausente`; `entrada_quebrada`/`entrada_divergente`/`entrada_em_conflito`;
  `versao_defasada`; `vendor_ausente`/`vendor_divergente`/`vendor_sem_launcher`;
  `launcher_ausente`/`launcher_divergente`; `node_ausente`/`node_incompativel`/`node_path_nao_resolve`;
  `pwsh_ausente`; `fornecedor_ausente`/`fornecedor_nao_validado` (**warn**); `credencial_ausente`;
  `credencial_divergente_env_vs_cofre` (**blocking** salvo override); `endpoint_nao_verificado`
  (**blocking** preset; **warn**+confirmação `compatible`); `acl_nao_aplicavel` (**warn** na auditoria;
  **blocking** nos mutadores de blob).
- **Online opt-in** (`-CheckUpdates`): `atualizacao_disponivel` — informa, nunca auto-atualiza.
  Canonicalização de path antes de `entrada_divergente`.

### A.10 Self-tests — inventário executável

**Offline (F1-pre/F1):** detecção (rejeitar stub); JSONC — **localizador estrutural** (edição fora de
comentário/string; **byte-diff** fora dos spans; **não-ASCII**; encoding/BOM/EOL preservados), fixtures
negativas, **golden de paridade**, **matriz de migração** por rota; idempotência; **escrita
serializada/transacional** (create×replace, corrida → recusa, arquivo especial → recusa, recuperação);
backup+restore; rollback; schema do descritor; **round-trip DPAPI**; **re-emissão de launcher por
versão**; **launcher** com filho falso (stdio binário, zero bytes fora do filho, exit code = do filho,
sem deadlock; **cancel/órfão/stderr intenso**; falha forçada de associação ao Job); **re-execução sem
ambiente herdado** (fonte = `config.json`); **comparação contra o manifesto esperado**; **revisão
estática do `dist` + boot sem chave** (gate do F1).

**Opt-in (não gate):** **contenção de rede** — Windows Sandbox sem rede; egresso por **filho**; firewall
só diagnóstico (A.4.6).

**F2:** self-tests de **TOML** (round-trip das formas reais; env mínimo com filho falso).

**Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
**E2E** com `jev_classify` = validação manual opt-in; pré-requisito de `handshakeConfirmed`.

### A.11 Paridade documental mecânica

- `README.md` trilíngue (duas listas por língua ×3); `CHANGELOG.md` trilíngue; **`SECURITY.md`
  trilíngue** (seção do cofre nas três).
- `09` com `Dono:` + `Validação:`/`Tokens:`/`Exit:`; `02` com contrato + vocabulário (declarar a
  **extensão** do vocabulário de evidência para artefatos externos); `08` nomear seções ou retirar.
- **`AGENTS.md`/`README.md`:** reconciliar listas **adicionando só o que faltar** (`AGENTS.md:11`
  já tem `xpz-codex-apply-patch-alternative`; conferir `:49`).
- `README.md:107` × `AGENTS.md:92-96` para a rastreabilidade privada das fixtures.
- **`999`:** `:3283` com pin por commit/sha512 e preset **parcial**; `:3277` **alinhado**. **Consultar o
  `998`** (`998:919-923`).
- Conformidade: `#requires -Version 7.4`; UTF-8 sem BOM (preservando BOM preexistente do arquivo do
  usuário); molde `.example.ps1`; `Test-XpzParameterNamingContract.ps1` **não** é gate geral; não
  enumerar ≥2 gates numa linha.
- **Ledger:** efêmero/gitignored em `Temp/revisao-por-pares/<RoundId>/`; **não versionar**.

---

## Apêndice — tabela de fornecedor (HIPÓTESE, não spec)

`typesafe` (`TYPESAFE_API_KEY`, transport do SDK, `jev-latest`); `openrouter` (`OPENROUTER_API_KEY`,
`…/alpha/decisions`, headers, `jev-latest`→`jev-1.13`); `cloudflare` (`CLOUDFLARE_API_TOKEN` +
`CLOUDFLARE_ACCOUNT_ID`, `/accounts/<id>/ai/run`); `vercel` (`AI_GATEWAY_API_KEY`, transport do SDK);
`compatible` (`JEV_API_KEY`, POST na URL completa, `{model,state,questions}` → `{answers,usage?}`;
**parcial**).

## Referências

- `https://github.com/jkudish/jev-mcp` (MIT); `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md`; `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md` — `commandcode/*`
  como **catálogo de vozes** (não confundir com o endpoint do Jev).

## CHANGELOG desta reorganização

**Foi para o Anexo A (movido, não deletado):**

- **A.1** — sequência nativa do launcher (`CreateProcessW`/`CREATE_SUSPENDED`/Job/`ResumeThread`),
  descartes (`ProcessStartInfo`, `& node`), limpeza em falha pós-criação, composição do bloco de
  ambiente (a/b/c), política de terminação/árvore, lista de invariantes mecanizadas, detalhe do
  descritor por modo.
- **A.2** — protocolo completo de escrita serializada/transacional: validação de atributos em toda a
  ancestralidade, lock, ramos create×replace, sequência de 8 passos, honestidade do lock, recuperação,
  canonicalização e ACL de caminhos gerenciados.
- **A.3** — diagnóstico verificado dos motores JSONC, desenho do localizador estrutural, **matriz de
  migração** (tabela), golden dividido, chaves duplicadas, ordem de execução, lockstep corrigido, lista
  de fixtures negativas, regra de painel do F1-pre.
- **A.4** — identidade/cadeia (sha512 do tarball × commit), campos do `manifest.sha256`, justificativa
  testada do `--ignore-scripts`, bootstrap executável (`vendor/` + cópia + `npm ci`), campos do
  `catalog.json` + retenção/rollback, evidência commitada do `dist` com proveniência, protocolo de
  contenção de rede (agora opt-in), semântica de rede em 3 contextos.
- **A.5** — escopo do manifesto × runtime Node (gate `>= 22`, cópia hash-registrada do Node).
- **A.6** — schema do `config.json`, origem/override, consumo pelo launcher, `endpointHash`.
- **A.7** — formato do blob DPAPI, tabela fonte × modo, entrada não-eco, `acl_nao_aplicavel`,
  backup/retenção/restore, três eventos.
- **A.8** — algoritmo de descoberta/precedência do OpenCode com `entrada_em_conflito`; detalhe da
  biblioteca TOML vendorizada e do round-trip do Codex.
- **A.9** — lista integral de estados offline com classes, tabela estado→`exitCode`, precedência
  `versao_defasada` × `vendor_divergente`.
- **A.10** — inventário executável de self-tests (F1-pre/F1/F2) e o E2E opt-in.
- **A.11** — paridade documental mecânica (`09`, `02`, `08`, README/AGENTS, `999`/`998`, conformidade,
  ledger).

**Marcado como Adiado (único corte de escopo, conforme autorizado):**

- **Teste de egresso de rede contido + Windows Sandbox como pré-requisito/gate obrigatório do F1** →
  **rebaixado a endurecimento opt-in**. O **gate do F1 passa a ser revisão estática do `dist` + boot
  sem chave**. O protocolo de Sandbox foi **preservado integralmente** em **A.4.6**. O risco aceito
  dessa troca está declarado em *Riscos*. Também listados na seção (já eram não-escopo/fases futuras,
  sem corte novo): AppContainer, F3 (Cursor/Claude Code), F4 (fornecedores experimentais, backend
  Python, fork/espelho), projeto-local do OpenCode, macOS/Linux e demais itens do não-escopo.

**Mudou no corpo:**

- Título → `v21`; linha de versões ganhou a entrada v21 como reorganização editorial; novo parágrafo
  **Estrutura** explicando corpo × Anexo A × Adiado.
- `## Arquitetura` → `## Arquitetura — decisões`; cada subseção ficou com a decisão e um ponteiro para
  o anexo correspondente.
- Seções `Fornecedor`, `Credencial`, `Adaptadores de cliente`, `Auditoria`, `Testes` reduzidas ao nível
  de decisão + fronteira, com ponteiro de anexo; `Testes` virou `## Testes — nível de decisão`.
- `Auditoria` ganhou a frase explícita do eixo estável **nada gravado sem confirmação** (já implícita em
  *Atualizar e remover*; nenhuma decisão nova).
- `Fases` — F1-pre ganhou menção à reserva da faixa de `exitCode` (já decidida em *Classes de
  artefato*); F1 trocou "re-verificação **contida** gating" por "revisão estática do `dist` + boot sem
  chave (gate)".
- `Riscos` — item `dist` reescrito para o novo gate; acrescentado **Risco aceito da contenção opt-in**
  (consequência do corte autorizado, não requisito novo).
- Nova seção `## Adiado / escopo-futuro`.
- `Atualizar e remover`, `Documentação e paridade`, `Evidência coletada`, `Apêndice` e `Referências`
  preservados; `Documentação e paridade` permanece no corpo e tem o espelho mecânico em A.11.
- Nenhuma referência a arquivo/linha foi criada ou alterada: `02:972/977`,
  `Install-OpenCodeReviewerRoAgent.ps1:252`, `AGENTS.md:11`, `:49`, `README.md:107`, `AGENTS.md:92-96`,
  `historico/...20260622-20260922.md:48`, `999:3283`, `:3277`, `998:919-923` seguem como estavam.
