# xpz-mcp-integrations — design da skill (v9)

## Papel do documento

Design **vivo** (não congelado) da skill `xpz-mcp-integrations`, com decisões de **2026-10-02** e a
evidência empírica coletada.

- **v2** pré-análise · **v3** F0-1 (4 titulares) · **v4–v8** refinos opencode (segundas opiniões) ·
  **v9** incorpora a **validação cara** (`openai/gpt-5.6-terra` via codex; voz única = segunda
  opinião).

**Autor e diversidade:** `authorFamily=deepseek` (o agente orquestrador). Pelo `15`, revisores devem
ser de **famílias distintas da do autor**. As rodadas F0-2..F0-6 (opencode: meta+deepseek) são
**segundas opiniões** (deepseek = família do autor; meta sozinho não fecha o piso). A **liberação**
exige **≥2 Criadores distintos do autor** **e ≥1 voz fora do harness dominante** (este último =
**endurecimento desta frente**, não regra do `15`).

**Processo:** refino barato via opencode → **validação cara (insumo, sem poder decisório)** →
**painel de liberação** (≥2 criadores distintos do autor + ≥1 fora do harness dominante) sobre a
versão final, com volta aos dissidentes. Alternativa auditada: humano **congela**
(`resubmissionDeclinedByHuman` + quem + motivo + `RoundId`). Até lá,
`vNextState=pendingResubmission`; nada é implementado. Nas rodadas F0-4..F0-7 os revisores afirmam
"nenhum gap reabre a arquitetura — é precisão de especificação/procedimento" — sinal favorável ao
congelamento, que é decisão humana.

## Problema

Usuários das skills XPZ com acesso ao **Jev/System One** não têm caminho gerenciado para
instalar/auditar/reparar/atualizar/remover esse componente MCP. A configuração validada na máquina
de referência é manual e **não portátil** (path pessoal absoluto, rede/cache em runtime, transitivas
sem pin, chave amarrada ao `auth.json` do OpenCode). A `xpz-skills-setup` não cobre MCP de terceiros.

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
| 3 | Node | detectar ausência **e** `< 22`; `winget` id `OpenJS.NodeJS.LTS` com aprovação; com `nvm`/`fnm`/`volta`, **relatar**; node sem npm = corrompido → relatar |
| 4 | Plataforma | **Windows** (cofre sem roaming) |
| 5 | Escopo v1 | **OpenCode + Codex** (completa no F2) |
| 6 | Credencial | **cofre** DPAPI, **vault-first**; env = **override explícito**; `auth.json` só import opcional |
| 7 | Fornecedor | 5 modos; `compatible`/Command Code **parcial**; outros 4 **experimental opt-in** |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade |

## Arquitetura

### Motor dirigido por descritor

Componente = comando, stdio, mapa de env, fonte de credencial, clientes, validação. Descritor de
dados (`components/jev.json`) com **schema fail-closed** e self-test. A **exceção de endpoint** do
modo `compatible` é **campo explícito do descritor**.

### Contrato dos motores novos

Seguem `02`: **JSON de máquina**, `-InputPath`, `-WhatIf`/`ShouldProcess`. Labels `*_SKIPPED` sob
`-WhatIf` são propriedade de `xpz-skills-setup/SKILL.md`. **Tabela de contrato por motor (publicada
ANTES do motor):** parâmetros aceitos, classe (`blocking|warn|info`) por estado, `exitCode`.
**Faixa de `exitCode` reservada no F1-pre** (prova de não-colisão com
`msbuild-exit-codes.catalog.json`). Motores com `-InputPath`: decidir entrada na **lista de cobertura**
do `Test-XpzParameterNamingContract.ps1` (`02:972/977`) — default: entram. **Vocabulário de
evidência:** o `02` é **centrado em XML** (4 níveis) → **declarar extensão** para artefatos externos
(JS/`provider.js`), com rótulo próprio (ex.: "evidência externa versionada"), sem reusar "Evidência
direta".

### Fronteira com `xpz-skills-setup` e aresta de dependência

- `xpz-mcp-integrations`: MCP **externos opcionais**; `xpz-skills-setup`: skills, instrucionais,
  `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- **Arquivos de cliente compartilhados — protocolo transacional (contra corrida):**
  1. **Ler** o arquivo e calcular **hash** (sha256) do conteúdo original;
  2. **Calcular** o novo conteúdo (merge preservando comentários/entradas alheias);
  3. **Escrever** em arquivo temporário **na mesma pasta**;
  4. **Re-ler o original e conferir o hash**; se **mudou** desde a leitura → **recusar** ("alteração
     concorrente; refaça") — nunca sobrescrever mudança legítima de outro cliente;
  5. **Backup imutável** (cópia com hash registrado) **antes** da troca;
  6. **Troca atômica** (rename/substituição atômica no mesmo volume);
  7. **Idempotência por conteúdo** (se o resultado já é o desejado, no-op).
  Backup: local, **retenção/limpeza** declaradas, ACL (o arquivo alheio pode conter segredos de
  outros MCPs), restore. O F1-pre **não** adiciona backup aos instaladores existentes (isolamento).
- Ponteiro **documental** na setup, na área de **não-escopo/fronteira** e **excluído do recibo**
  (anti-padrão `reviewer-ro`, `xpz-skills-setup/SKILL.md:84-88`). **Dono do registro =**
  `xpz-skills-setup`. `AGENTS.md` **enumeração (`:49`)** precisa de **duas** entradas: a skill nova
  **e** `xpz-codex-apply-patch-alternative` (esta está em `AGENTS.md:11`, mas **não** na enumeração;
  `README.md` já a lista).
- **Aresta de dependência:** `OpenCodeJsoncSupport.ps1` (a **criar**; dono-doc proposto
  `xpz-llm-delegate/SKILL.md`, alternativa "cabeçalho do script" como `Utf8NoBomEncodingSupport.ps1`)
  ganha consumidor novo; a aresta se registra nos dois documentos donos. Consumidor novo adota
  **fail-closed de support-library** (`Test-Path` + `throw "BLOCK: … ausente"`).
- **Rastreabilidade privada (`AGENTS.md`):** fixtures sanitizadas de `dist` **são** molde sanitizado
  publicável → avaliar `GeneXus-XPZ-PrivateMap`; reconciliar `README.md:107` × `AGENTS.md:92-96`.
  **Licença:** cópia integral da licença MIT + atribuição junto do artefato versionado.

### Suporte JSONC compartilhado — frente própria (F1-pre), arquivo **a criar**

Diagnóstico verificado no código:

- `Find-JsoncMatchingBrace` (instalador): ciente de string, **cego a comentários**.
- `Find-JsoncKeyValueSpan` (instalador): **não** ciente de string nem comentário (acha por
  `IndexOf`; comentário promete heurística de aspas **inexistente**).
- `ConvertFrom-Jsonc` (Guard): char-a-char, string/comentário-aware; **scanner de referência**;
  **sem** trailing comma.
- `ConvertFrom-JsoncText` (manifesto): regex, **não** string-safe; **remove** trailing comma
  (`,\s*[\}\]`) — regex que **também dispara dentro de strings** (corrompe valor com `, }`). **Roda
  hoje** lendo o `opencode.jsonc` real.
- **Bug vivo:** `Install-OpenCodeReviewerRoAgent.ps1:252` valida o arquivo inteiro com
  `ConvertFrom-Jsonc` → trailing comma alheio derruba com `BLOCK`.

**Correção — o suporte é um *localizador estrutural*, não só um scanner:**

- **Tokenizador → stream de tokens com spans (byte/offset)**: strings, escapes, `//`, `/* */`,
  trailing comma, aspas escapadas, bloco não-terminado; UTF-8 sem BOM; preservar EOL do original.
- **Busca por caminho estrutural** (ex.: `mcp.jev`, `agent.reviewer-ro`) que navega tokens/objetos —
  **abandona** `IndexOf` e os dois `Find-*`; erro tipado se o caminho cair em não-objeto.
- **Operações sobre spans** (insert/update/remove) que **nunca** recaem sobre comentário ou string,
  provadas por **round-trip + byte-diff**.
- O instalador **deixa de usar** `Find-JsoncMatchingBrace`/`Find-JsoncKeyValueSpan`; o manifesto de
  capacidade migra para o suporte. **Golden de paridade old-vs-new** (inclui string com `, }`) antes
  de trocar o manifesto. **Lockstep de motor compartilhado** (`AGENTS.md`): a skill que **audita
  consumidores** recebe o check de drift **no mesmo PR**. **Passo de maior risco = a extração.**
  **Ordem:** núcleo + instalador primeiro; **manifesto por último**, com **pin de fallback definido**.
  **Fixtures negativas:** chave comentada; forma-de-chave dentro de string; `{}` dentro de `/* */`;
  `//` dentro de string; **`//` trailing**; aspas escapadas; bloco não-terminado; trailing comma; e
  o caso "edição não recai sobre comentário/string". **Revisão do F1-pre:** painel com **≥2 Criadores
  distintos do autor** + **≥1 voz fora do harness afetado**.

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`; **versão fixada `0.13.0`**; **pin = sha512 + tag**; valores =
  fatos externos.
- **Evidência commitada (pré-condição de qualquer motor):** em `xpz-mcp-integrations/fixtures/`
  (pasta rastreada; `.gitignore` re-inclui `/xpz-*/`): trechos **sanitizados** de `provider.js`,
  `engines.node`, boot `initialize`, **+ licença MIT integral + atribuição**. Até então, a tabela de
  Fornecedor é **hipótese** (Apêndice). **Artefatos de pin** em `xpz-mcp-integrations/vendor/`:
  `package.json` de pin exato (`"0.13.0"`) + `package-lock.json`.
- **Integridade — dois níveis:** (1) **lockfile** = sha512 do **tarball do registro** (verdade no ato
  do `npm ci`, não comparável na árvore); (2) **manifesto de instalação próprio** — **sha256 por
  arquivo da árvore vendorizada**, gerado no `npm ci`, com o hash do manifesto no descritor — base de
  `vendor_divergente`.
- **Vendor:** `npm ci --ignore-scripts --no-audit --no-fund` em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`. **Sem indireção mutável**: **launcher
  versionado por path absoluto**; comando do cliente aponta para o launcher daquela versão. **Update**
  = instalar `vendor-<versao>` + gerar launcher + re-emitir config; **rollback** = re-emitir config
  para o launcher anterior. **Sem junction/symlink** para o vendor (evita o hazard de
  `historico/pretooluse-auto-allow-trajetoria-20260622-20260922.md:48`). **Retenção** de versões
  antigas declarada (limpeza explícita). `npm` é pré-requisito próprio.
- **Semântica de rede (normativa, 3 contextos):**
  1. **Instalador/vendorizador:** sem acesso ao **registro** fora de install/update.
  2. **Launcher/MCP em runtime:** **sem** busca de pacote; **somente** a conectividade **do endpoint**
     do fornecedor (a razão de existir do MCP).
  3. **Teste isolado:** mecanismo **executável** — servidor apontado a um **sink loopback**
     (`JEV_API_BASE_URL=http://127.0.0.1:<porta-morto>`), com asserção de que **nenhuma** tentativa de
     egresso **não-loopback** ocorre (verificação no nível de processo/rede) e que o pacote não busca
     o registro. **Varredura estática e boot sem chave não bastam** como prova.
- **Re-verificação isolada do `dist` (gating de F1):** (1) instalação (rede de registro permitida);
  (2) execução isolada (contexto 3). Allowlist de hosts, ocorrências de
  `fetch`/`undici`/`HttpClient`/telemetria, comportamento das **N transitivas do lockfile**, limite
  estático/heurístico reconhecido, **relatório sanitizado**.
- **Caminhos/segurança (cofre, backup, vendor):** validar que todo caminho gerenciado permanece sob
  `%LOCALAPPDATA%\xpz-mcp-integrations` após **canonicalização**, **rejeitando reparse points**
  (symlink/junction) na ancestralidade e raízes de outro drive; **ACL antes de persistir** o segredo;
  **escrita atômica** (temp na mesma pasta + troca atômica).

### Launcher portátil (molde gerado pela skill)

- **Comando = launcher PowerShell** (`["pwsh","-NoProfile","-File","<launcher-<versao>.ps1"]`):
  desprotege a chave via **DPAPI** em memória (**nunca argv**); resolve o `node` **absoluto**; inicia
  `…\vendor-<versao>\node_modules\@jkudish\jev-mcp\dist\index.js` com a variável **só** no env do
  filho.
- **Stdio — rota travada `& node` no próprio processo.** **Invariante mecanizada:** silenciar
  `$ProgressPreference`/`$InformationPreference`; **nenhum** `Write-*` para stdout (**scan estático**
  do launcher); logs só em stderr/arquivo; nenhum valor de chave em log; **`exit $LASTEXITCODE` como
  última instrução**; provar **payload binário grande** (sem re-encode) e **zero bytes** fora do
  filho. **Negativos pré-filho** (cofre ausente, blob corrompido, DPAPI outra máquina, `node` não
  resolvido) com **exit code próprio** e **zero bytes** no stdout. Self-test byte-a-byte.
  `ProcessStartInfo`+proxy = **fallback documentado**.
- **Runtime:** exige `pwsh` (7.4+); auditoria reporta se faltar. Rota Node→pwsh **descartada**
  (transcrição). **Staleness do `node`:** reparo = **re-resolver e re-emitir o launcher**.
- **Marcador de propriedade:** sentinela + **manifesto**; uninstall remove **só se** sentinela **e**
  path no manifesto; órfão = reportar.

### Detecção de pré-requisitos

Espelhar `GeneXusPythonPrerequisite.ps1`/`Test-XpzPowerShellRuntime.ps1`: **executável utilizável de
verdade** (rejeitar stub `WindowsApps`/alias da Store) para `node`/`npm`/`pwsh`.

## Fornecedor

Cinco modos (`JevProvider`). **Wire = hipótese** até as fixtures (Apêndice).

- `compatible` **não** é "API OpenAI qualquer": exige o contrato System One/Jev; URL vai como veio;
  `cloudflare`/`vercel` não intercambiáveis. **Inferência `auto`:** com **múltiplas** famílias de env
  setadas, o setup exige `JEV_PROVIDER` explícito (não adivinha).
- **`endpoint_nao_verificado` — regra única:** presets fechados (allowlist do **provedor**) =
  **blocking** se o host divergir; `compatible` de terceiro (URL arbitrária) = **`warn` + confirmação
  explícita registrada** (exceção = **campo do descritor**). Fornecedor e Auditoria dizem o **mesmo**.
- **`compatible` = parcial** (handshake MCP, não a decisão E2E). **Command Code** = preset sugerido.
  **Experimental opt-in:** os 4 não provados fora do caminho feliz e dos self-tests do F1. **Import
  `auth.json`:** opcional, com ressalva (credencial `commandcode/*` do OpenCode é de **gateway de
  LLM**).

## Credencial

- **Cofre:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\` (`%LOCALAPPDATA%` do ambiente; separado do
  `vendor-*/`). **Blob:** DPAPI `CurrentUser`, **sem entropia adicional**, **campo `version`**.
- **Tabela fonte × modo × comportamento:** launcher resolve por modo (vault-first; env só com
  `-CredentialSource env`); auditor **compara** env-vs-cofre e só sinaliza
  `credencial_divergente_env_vs_cofre` (**blocking**) quando **não** houve override intencional.
- **Entrada:** `Read-Host -AsSecureString`; **sem persistência** em transcript/history
  (`-HistorySaveStyle SaveNothing`); não-eco em log. **ACL antes de persistir** o blob.
- **Backup do cofre:** local, retenção, **mesma ACL**, restore. **Restore inter-máquina:** DPAPI
  **não roaming** → backup em outra máquina/usuário **não abre**; procedimento = **re-inserir a
  chave** (backup **não** promete migração).
- **ACL:** `ICACLS` (remover herança + só o dono). **`acl_nao_aplicavel`:** volume sem suporte a ACL
  (FAT32/exFAT/removíveis) → **warn**. **Não** hospedar segredos de privilégio maior que a chave do
  provedor.
- **Três eventos separados:** **rotação** (re-cifrar), **remoção** (preservar o cofre), **incidente**
  (apagar o blob + revogar a chave no provedor + orientar restart do MCP).
- **Limite honesto:** DPAPI protege em repouso; não contra processo do mesmo usuário, inspeção do env
  do filho, nem roaming. **Fronteira:** pacote + transitivas + endpoint. Chave nunca
  impressa/logada/copiada; fronteira no `SECURITY.md`.

## Adaptadores de cliente (v1)

- **OpenCode** — `~/.config/opencode/opencode.jsonc`, `mcp.jev` (`type: local`,
  `command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`). Merge
  via o **suporte JSONC** (localizador estrutural); protocolo transacional; idempotente. Entrada `jev`
  divergente → `entrada_em_conflito`. **Shape = fato externo** + **fixture sanitizada** no F1.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**). **Suporte TOML próprio e escopado**
  (declarar gramática: tabelas/sub-tabelas, strings básicas/literais, inteiros, booleanos,
  comentários; cobrir `[`/`]` em string, multilinha `'''`/`"""`, `#` após valor, cabeçalho comentado,
  `enabled=false`) — **sem** terceiro (evita 2ª superfície de cadeia de suprimentos); **ou**, se
  preferir biblioteca, esta vem com **pin + integridade + licença** no rigor do `jev-mcp`.
  **Proibido** "span textual até o próximo cabeçalho". **`env_vars` filtra o herdado** → launcher
  define **conjunto mínimo explícito provado empiricamente** (`SystemRoot`, `SystemDrive`,
  `TEMP`/`TMP`, `PATHEXT`, `COMSPEC`, `PATH` mínimo) com **filho falso**. Fixture sanitizada do
  `config.toml` no F2.

## Auditoria (estados e contrato)

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`. **Tabela estado → `exitCode`/classe
  por motor** (faixa reservada no F1-pre). **Precedência:** `versao_defasada` (pin do **descritor**)
  antes de `vendor_divergente` (manifesto de árvore).
- **Offline:** `OK`; `ausente`;   `entrada_quebrada`/`entrada_divergente`/`entrada_em_conflito`;
  `versao_defasada`; `vendor_ausente`/`vendor_divergente`/`vendor_sem_launcher`;
  `launcher_ausente`/`launcher_divergente`; `node_ausente`/`node_incompativel`/`node_path_nao_resolve`;
  `pwsh_ausente`; `fornecedor_ausente`; `fornecedor_nao_validado` (**warn**); `credencial_ausente`;
  `credencial_divergente_env_vs_cofre` (**blocking**, salvo override registrado);
  `endpoint_nao_verificado` (**blocking** preset fechado; **warn**+confirmação `compatible`);
  `acl_nao_aplicavel` (**warn**).
- **Online opt-in** (`-CheckUpdates`, com rede — contexto **distinto** do runtime): `atualizacao_disponivel`
  — informa, nunca auto-atualiza; fora do gate offline. Canonicalização de path antes de
  `entrada_divergente`.

## Atualizar e remover

- **Atualizar:** consciente (release notes, breaking changes, backup, instalar `vendor-<versao>` +
  gerar launcher + re-emitir config, teste, rollback por re-emissão). Nunca por existir versão nova.
- **Remover:** manifesto registra **referências por cliente**; o launcher só sai quando **não restar
  referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre,
  `auth.json`, fornecedor e demais MCPs; no Codex, `enabled=false` quando manter a config.

## Testes

- **Self-tests offline:** detecção (rejeitar stub `WindowsApps`); JSONC — **localizador estrutural**
  (edição não recai sobre comentário/string; round-trip + byte-diff), fixtures negativas, **golden de
  paridade** (manifesto, inclui `, }` em string); idempotência; **protocolo transacional** (corrida:
  alteração concorrente → recusa); backup+restore; rollback; schema do descritor; **round-trip DPAPI**;
  **re-emissão de launcher por versão**; **launcher** com filho falso (stdio binário, zero bytes fora
  do filho, exit code) **e negativos pré-filho**; **isolamento de rede** (contexto 3, sink loopback).
- **Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
  Self-tests de **TOML** no **F2**.
- **E2E** com `jev_classify` = validação manual opt-in; pré-requisito de qualquer "validado".

## Documentação e paridade

- `README.md` trilíngue (duas listas por língua ×3 = seis pontos); `CHANGELOG.md` trilíngue;
  **`SECURITY.md` trilíngue** (seção do cofre nas três).
- `09` (`Dono:` + `Validação:`/`Tokens:`/`Exit:`); `02` (contrato de motor + vocabulário de evidência);
  `08` (nomear seções ou retirar).
- `AGENTS.md` (enumeração `:49`, duas entradas) + ponteiro documental na setup (fora do recibo);
  `xpz-llm-delegate/SKILL.md` (dono do JSONC + aresta).
- **`999`:** `:3283` já com pin "sha512+tag, valores a re-verificar" e preset **parcial**; `:3277`
  **atualizado** (validação cara como insumo, painel de liberação, re-submissão). **Consultar o `998`**
  (lição de exit-code: `998:919-923`).
- Conformidade: `#requires -Version 7.4`; UTF-8 sem BOM; molde `.example.ps1`;
  `Test-XpzParameterNamingContract.ps1` **não** é gate geral; não enumerar ≥2 gates numa linha.
- **Ledger:** efêmero/gitignored em `Temp/revisao-por-pares/<RoundId>/`; **não versionar**, **superando
  explicitamente** o precedente legado **não rastreado** `.peer-review-rounds/matriz-14-*` (o `15`
  trata o livro-razão como **opcional**).

## Fases

- **F0** — design + revisão (F0-1..F0-7; faltam **validação final** e **painel de liberação**).
- **F1-pre** (frente própria; painel com ≥2 Criadores distintos do autor + ≥1 fora do harness afetado)
  — criar `OpenCodeJsoncSupport.ps1` (**localizador estrutural**) + golden + fixtures negativas +
  migração dos consumidores + self-tests + **lockstep**.
- **F1** — skill (OpenCode + núcleo) + descritor Jev + launcher versionado + cofre/DPAPI +
  vendorizador + **evidência sanitizada do `dist`** + **re-verificação isolada gating** + self-tests +
  docs. **F1 ≠ v1.**
- **F2** — Codex (suporte TOML escopado, prova empírica do env mínimo) + self-tests TOML + auditoria de
  versão/drift + update/rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1` no mesmo
  `~/.cursor/mcp.json`).
- **F4** — opcionais: fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** — rota travada; invariante mecanizada; negativos no self-test.
- **Suporte TOML (Codex)** — próprio/escopado ou biblioteca com pin+integridade+licença; prova do env
  mínimo; fixture no F2.
- **`dist`** — evidência sanitizada + re-verificação isolada (contextos de rede) = gating; `SECURITY.md`.
- **Fatos externos a re-verificar no F1/F2:** integridade/tag/commit; `engines.node`; tabela dos 5
  modos; boot MCP; shape do `opencode.jsonc`; semântica TOML do Codex.
- **Fornecedores experimentais** só sob opt-in. **Node/pwsh/npm** são dependências de runtime.

## Evidência coletada (2026-10-02)

- `node v24.18.0`/`python 3.14`; pacote vendorizado em pasta temporária; **boot offline** com env
  fictício + `initialize` MCP (`server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`).
- **`dist/provider.js` lido** em `%TEMP%\opencode\jev-probe\` (evidência **externa**; a commitar
  sanitizada em `xpz-mcp-integrations/fixtures/`).
- **Rodadas F0** (vereditos efêmeros; F0-2..F0-7 via opencode = segundas opiniões; `authorFamily=deepseek`):

| Rodada | RoundId (submetida) | Produzida | Revisores | Vereditos |
|---|---|---|---|---|
| F0-1 | `mcp-integrations-f0-v2` (v2) | v3 | meta, stealth, openai, anthropic | 4× revisa |
| F0-2 | `mcp-integrations-f0-v3` (v3) | v4 | meta, stealth, deepseek | 3× revisa |
| F0-3 | `mcp-integrations-f0-v4` (v4) | v5 | meta, stealth, deepseek | 3× revisa |
| F0-4 | `mcp-integrations-f0-v5` (v5) | v6 | meta, stealth, deepseek | 3× revisa |
| F0-5 | `mcp-integrations-f0-v6` (v6) | v7 | meta, stealth, deepseek | 3× revisa |
| F0-6 | `mcp-integrations-f0-v7` (v7) | v8 | meta, stealth, deepseek | 3× revisa |
| F0-7 (cara) | `mcp-integrations-f0-codex-gpt` (v8) | v9 | openai/gpt-5.6-terra (codex) | 1× revisa |

- **Recibo F0-1** (via `xpz-llm-delegate`): `preferenceSource=orchestrator`,
  `effectivePreferredPath=…\preferred-reviewers.opencode.json`; `attemptRole=primary`, `fallbackOf`
  vazio, `countsForDiversity=true`; `closeoutReady=false` (`vnext-pending-resubmission`).
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

## Apêndice — tabela de fornecedor (HIPÓTESE, não spec)

`typesafe` (`TYPESAFE_API_KEY`, transport do SDK, `jev-latest`); `openrouter` (`OPENROUTER_API_KEY`,
`…/alpha/decisions`, headers, `jev-latest`→`jev-1.13`); `cloudflare` (`JEV_CLOUDFLARE_*`/`CLOUDFLARE_*`
+ `CLOUDFLARE_ACCOUNT_ID`, `/accounts/<id>/ai/run`, `{model, input:{state,questions}}`); `vercel`
(`AI_GATEWAY_API_KEY`, transport do SDK); `compatible` (`JEV_API_KEY`, POST na URL completa,
`{model,state,questions}` → `{answers,usage?}`; **parcial**).

## Referências

- `https://github.com/jkudish/jev-mcp` (MIT); `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md`; `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md` —
  `commandcode/*` como **catálogo de vozes** (não confundir com o endpoint do Jev).
