# xpz-mcp-integrations — design da skill (v8)

## Papel do documento

Design **vivo** (não congelado) da skill `xpz-mcp-integrations`, com decisões de **2026-10-02** e a
evidência empírica coletada.

- **v2** pré-análise · **v3** F0-1 (4 titulares) · **v4** F0-2 · **v5** F0-3 · **v6** F0-4 · **v7**
  F0-5 · **v8** F0-6 (opencode; veredito **revisa**).

**Autor e diversidade:** o autor do manuscrito é o agente orquestrador, cujo Criador de Modelo é
**`deepseek`** (`authorFamily=deepseek`). Pelo `15`, os revisores devem ser **cegos de famílias
distintas da do autor**. Consequência honesta: as rodadas F0-2..F0-6 (opencode: meta+deepseek) são
**segundas opiniões** — o `deepseek` é a família **do autor** e **não** conta como independente; o
`meta` sozinho não fecha o piso. A **liberação** exige **≥2 Criadores distintos do autor** **e ≥1 voz
fora do harness dominante** (este último é **endurecimento desta frente**, não regra do `15`).

**Processo de F0:** refinar via **opencode** (segundas opiniões baratas) e, quando o autor julgar que
não há mais gaps, submeter a **uma validação com um modelo mais caro** — que é **insumo, sem poder
decisório** (voz única = segunda opinião; "caro" ≠ diversidade) e **não libera implementação**. A
liberação exige **painel diverso sobre a versão final** (acima) + volta aos dissidentes. Alternativa
auditada: o humano **congela** (`resubmissionDeclinedByHuman` + quem + motivo + `RoundId`). Até lá,
`vNextState=pendingResubmission` e nada é implementado.

O `15` registra o **congelamento** como gatilho humano quando a arquitetura deixa de ser reaberta e
as objeções viram precisão de implementação. Nas rodadas F0-4..F0-6, os próprios revisores afirmam
"nenhum gap reabre a arquitetura — é precisão de especificação/procedimento".

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
modo `compatible` é **campo explícito do descritor** (mantém o schema fechado).

### Contrato dos motores novos

Seguem `02`: **JSON de máquina**, `-InputPath`, `-WhatIf`/`ShouldProcess`. Labels `*_SKIPPED` sob
`-WhatIf` são propriedade de `xpz-skills-setup/SKILL.md`. **Tabela de contrato por motor
(pré-requisito, publicada ANTES do motor):** parâmetros aceitos, classe (`blocking|warn|info`) por
estado, e `exitCode`. **Faixa de `exitCode` reservada no F1-pre** (prova de não-colisão com
`msbuild-exit-codes.catalog.json`). Motores que usam `-InputPath`: decidir se entram na **lista de
cobertura** do `Test-XpzParameterNamingContract.ps1` (`02:972/977`; `:108-138`) — default: entram.
**Vocabulário de evidência:** o `02` tem **4 níveis** (Hipótese → Inferência forte → Evidência
direta, + o de KB externa); a evidência do design é **não-XML** — **declarar a extensão** do
vocabulário (ou rótulo próprio), não reusar "Evidência direta" para boot/`provider.js`.

### Fronteira com `xpz-skills-setup` e aresta de dependência

- `xpz-mcp-integrations`: MCP **externos opcionais**; `xpz-skills-setup`: skills, instrucionais,
  `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- Arquivos de cliente compartilhados: **merge sempre**, **backup** antes de escrever, **nunca**
  remover entrada alheia. **Contrato do backup (novo):** local, **retenção/limpeza**, ACL (o
  `opencode.jsonc` alheio pode conter segredos de outros MCPs) e restore. O F1-pre **não** adiciona
  backup aos instaladores existentes (isolamento); se tocá-los, vira item próprio.
- Ponteiro **documental** na setup, posicionado na área de **não-escopo/fronteira** e **excluído do
  recibo** de auditoria (anti-padrão `reviewer-ro`, `xpz-skills-setup/SKILL.md:84-88`). O **dono do
  registro** é a `xpz-skills-setup`; a skill entra no inventário como `ausente` até ser registrada.
  `AGENTS.md` **enumeração (`:49`)** precisa de **duas** entradas: a skill nova **e**
  `xpz-codex-apply-patch-alternative` (esta **está** em `AGENTS.md:11`, mas **não** na enumeração de
  skills; `README.md` já a lista).
- **Aresta de dependência:** o `OpenCodeJsoncSupport.ps1` (a **criar**; dono-doc **proposto**
  `xpz-llm-delegate/SKILL.md`, alternativa "cabeçalho do script" como `Utf8NoBomEncodingSupport.ps1`)
  ganhará consumidor novo; a aresta se registra nos dois documentos donos. Consumidor novo adota o
  **fail-closed de support-library** (`Test-Path` do `.ps1` + `throw "BLOCK: … ausente"`).
- **Avaliação de rastreabilidade privada (`AGENTS.md`):** fixtures sanitizadas de `dist` de terceiro
  **são** molde sanitizado publicável → avaliar anotação no `GeneXus-XPZ-PrivateMap`; reconciliar a
  tensão `README.md:107` (anotar todo exemplo) × `AGENTS.md:92-96` (avaliar) explicitamente. Licença:
  **cópia integral da licença MIT + atribuição** junto do artefato versionado.

### Suporte JSONC compartilhado — frente própria (F1-pre), arquivo **a criar**

Diagnóstico verificado no código:

- `Find-JsoncMatchingBrace` (embutida em `Install-OpenCodeReviewerRoAgent.ps1`): ciente de string,
  **cego a comentários**.
- `Find-JsoncKeyValueSpan` (mesmo arquivo): **não** ciente de string (comentário promete heurística
  de aspas **inexistente**).
- `ConvertFrom-Jsonc` (`OpenCodeReviewerRoGuard.ps1`): char-a-char, string/comentário-aware;
  **scanner de referência**; **sem** trailing comma.
- `ConvertFrom-JsoncText` (`Build-LlmDelegateCapabilityManifest.ps1`): regex, **não** string-safe;
  **remove** trailing comma (`,\s*[\}\]`) — e esse regex **também dispara dentro de strings** (valor
  contendo `, }` é corrompido hoje). **Roda hoje** lendo o `opencode.jsonc` real.
- **Bug vivo:** `Install-OpenCodeReviewerRoAgent.ps1:252` valida o arquivo inteiro com
  `ConvertFrom-Jsonc` → trailing comma alheio derruba com `BLOCK`.

**Correção:** o `OpenCodeJsoncSupport.ps1` (**a criar**) extrai o **scanner** do `ConvertFrom-Jsonc`
e **introduz** a tolerância a trailing comma (hoje ausente no scanner; o `ConvertFrom-JsoncText`
apenas a remove por regex) — **não** "mantém". **Golden de paridade old-vs-new** (incluindo string
contendo `, }`) antes de trocar o manifesto de capacidade. **Lockstep de motor compartilhado**
(`AGENTS.md`): o motor é consumido por wrappers/consumidores; a skill que **audita consumidores**
precisa do **check de drift no mesmo PR** (paridade documental não basta). **Passo de maior risco =
a extração** (tirar código de dois arquivos e trocar a origem). **Ordem:** núcleo + instalador
primeiro; **manifesto de capacidade por último**, com **pin de fallback definido**. Consumidores:
`OpenCodeReviewerRoGuard.ps1`; `Build-LlmDelegateCapabilityManifest.ps1`;
`Install-OpenCodeReviewerRoAgent.ps1` (**hoje** dot-sourceia o Guard em `:49`). **Fixtures
negativas:** chave comentada; forma-de-chave dentro de string; `{}` dentro de `/* */`; `//` dentro de
string; **`//` trailing** (o `ConvertFrom-JsoncText:99` só remove `^\s*//`, linha inteira); aspas
escapadas; **bloco não-terminado**; trailing comma. **Revisão do F1-pre:** painel com **≥2
Criadores distintos do autor** e **≥1 voz fora do harness afetado** (endurecimento).

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`; **versão fixada `0.13.0`**; **mecanismo de pin = sha512 + tag**;
  **valores** = fatos externos.
- **Evidência commitada (pré-condição de qualquer motor):** em `xpz-mcp-integrations/fixtures/`
  (pasta rastreada — `.gitignore` re-inclui `/xpz-*/`): trechos **sanitizados** de `provider.js` que
  sustentam cada linha da tabela, `engines.node`, boot `initialize`, **+ licença MIT integral +
  atribuição**. Até então, a **tabela de Fornecedor é hipótese** (Apêndice).
- **Artefatos de pin:** em `xpz-mcp-integrations/vendor/`: `package.json` de pin **exato**
  (`"0.13.0"`) + `package-lock.json`.
- **Integridade — dois níveis, declarados:** (1) o **lockfile** guarda sha512 **do tarball do
  registro** (verdade no ato do `npm ci`, **não** comparável na árvore extraída); (2) **manifesto de
  instalação próprio** — **sha256 por arquivo da árvore vendorizada**, gerado no `npm ci`, com o hash
  do manifesto no descritor — é a base de `vendor_divergente`. `dist.integrity` do descritor =
  asserção do tarball conforme o lock.
- **Vendor:** `npm ci --ignore-scripts --no-audit --no-fund` em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`. **Sem indireção mutável** (`current`): o
  **launcher é versionado por path absoluto** e o comando do cliente aponta para o launcher daquela
  versão — **update** = instalar `vendor-<versao>` + gerar launcher + re-emitir config; **rollback**
  = re-emitir config para o launcher anterior. **Sem junction/symlink** para o vendor (evita o
  hazard documentado em `historico/pretooluse-auto-allow-trajetoria-20260622-20260922.md:48`:
  `Remove-Item -Recurse` numa junction pode apagar o alvo). **Retenção** de versões antigas
  declarada (limpeza explícita, nunca automática durante o uso). `npm` é pré-requisito próprio; sem
  rede no runtime do wrapper; o pacote não é comitado.
- **Re-verificação isolada do `dist` (gating de F1) — duas fases:** (1) **Instalação** (rede de
  registro permitida): `npm ci` contra o lock, `--ignore-scripts --no-audit --no-fund`; (2)
  **Execução** (isolamento): **sem rede, sem chave real** — allowlist de hosts, ocorrências de
  `fetch`/`undici`/`HttpClient`/telemetria, comportamento das **N transitivas do lockfile**, limite
  **estático/heurístico** reconhecido (boot sem chave/rede não exercita todos os ramos), **relatório
  sanitizado**.

### Launcher portátil (molde gerado pela skill)

- **Comando = launcher PowerShell** (`["pwsh","-NoProfile","-File","<launcher-<versao>.ps1"]`):
  desprotege a chave via **DPAPI** em memória (**nunca argv**); resolve o `node` **absoluto**; inicia
  `…\vendor-<versao>\node_modules\@jkudish\jev-mcp\dist\index.js` com a variável **só** no env do
  filho.
- **Stdio — rota travada `& node` no próprio processo.** **Invariante mecanizada:** silenciar
  `$ProgressPreference`/`$InformationPreference`; **nenhum** `Write-*` para stdout (**scan estático**
  do launcher, além da norma); logs só em stderr/arquivo; nenhum valor de chave em log; **`exit
  $LASTEXITCODE` como última instrução**; provar **payload binário grande** (sem re-encode) e
  **zero bytes** fora do filho. **Caminhos negativos (pré-filho):** cofre ausente, blob corrompido
  (`Unprotect` lança), DPAPI em outra máquina/usuário, `node` não resolvido — cada um com **exit code
  próprio** na tabela e **zero bytes** no stdout. Self-test byte-a-byte para felizes e negativos.
  `ProcessStartInfo`+proxy = **fallback documentado**.
- **Runtime:** exige `pwsh` (7.4+); auditoria reporta se faltar. Rota Node→pwsh (desproteger por
  filho) **descartada** (transcrição).
- **Staleness do `node`:** `node_path_nao_resolve` → **reparo = re-resolver e re-emitir o launcher**
  (sem reinstalar Node).
- **Marcador de propriedade:** sentinela no cabeçalho + **manifesto**; uninstall remove **só se**
  sentinela **e** path no manifesto; órfão = reportar.

### Detecção de pré-requisitos (lição do Windows já paga)

`GeneXusPythonPrerequisite.ps1` existe porque um **stub `WindowsApps`** resolvia e não executava.
Aplicar o mesmo a `node`/`npm`/`pwsh`: **executável utilizável de verdade** (não stub/alias da
Store), espelhando `GeneXusPythonPrerequisite.ps1` e `Test-XpzPowerShellRuntime.ps1`.

## Fornecedor

Cinco modos (`JevProvider`). **Detalhes de wire = hipótese** até as fixtures (Apêndice).

- `compatible` **não** é "API OpenAI qualquer": exige o contrato System One/Jev; a URL vai como veio;
  `cloudflare`/`vercel` não são intercambiáveis.
- **Inferência `auto` (precedência explícita):** o pacote infere pela presença de env; quando
  **múltiplas** famílias de env estão setadas, o setup **exige `JEV_PROVIDER` explícito** (não
  adivinha).
- **`endpoint_nao_verificado` — regra única (fecha a indecisão):** presets fechados (allowlist
  derivada do **provedor/preset**) = **blocking** se o host divergir; `compatible` de terceiro (URL
  arbitrária) = **`warn` + confirmação explícita do usuário registrada** (exceção é **campo do
  descritor**). As duas seções (Fornecedor e Auditoria) dizem a mesma coisa.
- **`compatible` = parcial:** prova o handshake MCP, não a decisão E2E. **Command Code** = preset
  sugerido. **Experimental opt-in:** os 4 não provados fora do caminho feliz e dos self-tests do F1.
  **Import `auth.json`:** opcional, com ressalva (credencial `commandcode/*` do OpenCode é de
  **gateway de LLM**).

## Credencial

- **Cofre:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\` (`%LOCALAPPDATA%` do ambiente; separado do
  `vendor-*/`). **Blob:** DPAPI `CurrentUser`, **sem entropia adicional**, **campo `version`**.
- **Tabela fonte × modo × comportamento:** o launcher resolve a fonte por modo (vault-first; env só
  com `-CredentialSource env`); o auditor **compara** env-vs-cofre e só sinaliza
  `credencial_divergente_env_vs_cofre` (**blocking**) quando **não** houve override intencional
  (override registrado não gera falso bloqueio).
- **Entrada:** `Read-Host -AsSecureString`; **sem persistência** em transcript/history
  (`Set-PSReadLineOption -HistorySaveStyle SaveNothing`); não-eco em log.
- **Backup do cofre:** local, retenção, **mesma ACL**, restore. **Restore inter-máquina:** DPAPI
  `CurrentUser` **não roaming** → backup restaurado em outra máquina/usuário **não abre**; o
  procedimento diz **"re-inserir a chave"** (o backup **não** promete migração).
- **ACL:** `ICACLS` (remover herança + só o dono). **`acl_nao_aplicavel`:** volume sem suporte a ACL
  (FAT32/exFAT/alguns removíveis) → **warn** (a proteção do cofre não se aplica ali). **Não** hospedar
  segredos de privilégio maior que a chave do provedor.
- **Três eventos separados:** **rotação** (re-cifrar o blob), **remoção** (preservar o cofre),
  **incidente** (apagar o blob + revogar a chave no provedor + orientar restart do MCP). Sem
  confundir "preservar" com "revogar".
- **Limite honesto:** DPAPI protege em repouso; não contra processo do mesmo usuário, inspeção do env
  do filho (visível a processo do mesmo usuário), nem roaming. **Fronteira:** pacote + transitivas +
  endpoint. Chave nunca impressa/logada/copiada. Fronteira no `SECURITY.md`.

## Adaptadores de cliente (v1)

- **OpenCode** — `~/.config/opencode/opencode.jsonc`, `mcp.jev` (`type: local`,
  `command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`). Merge
  via o **suporte JSONC**; backup; idempotente. Entrada `jev` divergente → `entrada_em_conflito`.
  **Shape = fato externo** + **fixture sanitizada** do `opencode.jsonc` no F1.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**). **Parser TOML real** (biblioteca
  TOML **versionada/pinada** ou implementação completa) — **proibido** "span textual até o próximo
  cabeçalho" como rota travada (repetiria o anti-padrão do JSONC). Cobrir: `[`/`]` dentro de
  string/literal, strings multilinha `'''`/`"""`, comentário `#` após valor, cabeçalho comentado,
  `enabled=false`. **`env_vars` filtra o herdado** → o launcher define um **conjunto mínimo explícito
  provado empiricamente** (`SystemRoot`, `SystemDrive`, `TEMP`/`TMP`, `PATHEXT`, `COMSPEC`, `PATH`
  mínimo — ou resolve tudo por caminho absoluto) com **filho falso** antes de virar spec. Fixture
  sanitizada do `config.toml` no F2.

## Auditoria (estados e contrato)

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`. **Tabela estado → `exitCode`/classe
  por motor** (com faixa reservada no F1-pre). **Precedência:** `versao_defasada` (pin do **descritor**,
  não a versão reportada pelo pacote) avalia **antes** de `vendor_divergente` (manifesto de árvore).
- **Offline:** `OK`; `ausente`; `entrada_quebrada`/`entrada_divergente`/`entrada_em_conflito`;
  `versao_defasada`; `vendor_ausente`/`vendor_divergente`/`vendor_sem_launcher`;
  `launcher_ausente`/`launcher_divergente`; `node_ausente`/`node_incompativel`/`node_path_nao_resolve`;
  `pwsh_ausente`; `fornecedor_ausente`; `fornecedor_nao_validado` (**warn**); `credencial_ausente`;
  `credencial_divergente_env_vs_cofre` (**blocking**, salvo override registrado);
  `endpoint_nao_verificado` (**blocking** em preset fechado; **warn**+confirmação em `compatible`);
  `acl_nao_aplicavel` (**warn**).
- **Online opt-in** (`-CheckUpdates`, com rede — contexto **distinto** do runtime sem rede):
  `atualizacao_disponivel` (registro remoto) — informa, nunca auto-atualiza; fora do gate offline.
  Canonicalização de path (case-insensitive, barras, EOL) antes de `entrada_divergente`.

## Atualizar e remover

- **Atualizar:** consciente (release notes, breaking changes, backup, instalar `vendor-<versao>` +
  gerar launcher + re-emitir config, teste, rollback por re-emissão). Nunca por existir versão nova.
- **Remover:** manifesto registra **referências por cliente**; o launcher só sai quando **não restar
  referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre,
  `auth.json`, fornecedor e demais MCPs; no Codex, `enabled=false` quando manter a config.

## Testes

- **Self-tests offline:** detecção (com rejeição de stub `WindowsApps`); merge JSONC (fixtures
  negativas); idempotência; backup+restore; rollback; schema do descritor; **round-trip DPAPI**
  (segredo fictício, efêmero); **re-emissão de launcher por versão** (concorrência + versões
  concorrentes, sem indireção mutável); **launcher** com filho falso (stdio binário, zero bytes no
  stdout além do filho, exit code) **e negativos pré-filho** com exit codes próprios. **Golden de
  paridade** JSONC (manifesto) incluindo string com `, }`.
- **Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
  Self-tests de **TOML** no **F2**.
- **E2E** com `jev_classify` = validação manual opt-in; pré-requisito de qualquer "validado".

## Documentação e paridade

- `README.md` trilíngue (skills em **duas listas por língua** ×3 = seis pontos); `CHANGELOG.md`
  trilíngue; **`SECURITY.md` trilíngue** (seção do cofre nas três).
- `09` (`Dono:` + `Validação:`/`Tokens:`/`Exit:`); `02` (contrato de motor + vocabulário de evidência).
- `08` — nomear as seções exatas a tocar (ou retirar).
- `AGENTS.md` (enumeração `:49`, duas entradas) + ponteiro documental na setup (fora do recibo);
  `xpz-llm-delegate/SKILL.md` (dono do JSONC + aresta).
- **`999`:** `:3283` já registra pin "sha512+tag, valores a re-verificar" e preset **parcial**;
  **`:3277` (Maturidade)** defasado → **corrigir já** (validação cara como insumo, painel de
  liberação, re-submissão). **Consultar o `998`** antes do F1 (há lição de exit-code:
  `998:919-923` — string-matching sem `ExitCode` foi rejeitado nesta base).
- Conformidade: `#requires -Version 7.4`; UTF-8 sem BOM; molde `.example.ps1`;
  `Test-XpzParameterNamingContract.ps1` **não** é gate geral (pontos: `02:972/977`); não enumerar ≥2
  gates numa linha.
- **Ledger:** efêmero/gitignored em `Temp/revisao-por-pares/<RoundId>/` (o `15` diz
  `<timestamp-ou-guid>`; `RoundId` é aceito). **Decisão: não versionar o ledger**, **superando
  explicitamente** o precedente legado **não rastreado** `.peer-review-rounds/matriz-14-*`; o `15`
  trata o livro-razão como **opcional** — mantido efêmero (sem endurecer a norma).

## Fases

- **F0** — design + revisão (em andamento: F0-1..F0-6; faltam a **validação cara (insumo)** e o
  **painel de liberação** com ≥2 Criadores distintos do autor + ≥1 fora do harness dominante).
- **F1-pre** (frente própria; revisão por painel com piso acima) — criar `OpenCodeJsoncSupport.ps1` +
  golden de paridade + fixtures negativas + migração dos consumidores + self-tests + **lockstep**.
- **F1** — skill (OpenCode + núcleo) + descritor Jev + launcher versionado + cofre/DPAPI +
  vendorizador + **evidência sanitizada do `dist`** + **re-verificação isolada gating** + self-tests +
  docs. **F1 ≠ v1.**
- **F2** — Codex (parser TOML real, prova empírica do env mínimo) + self-tests TOML + auditoria de
  versão/drift + update/rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1` no mesmo
  `~/.cursor/mcp.json`).
- **F4** — opcionais: fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** — rota travada; invariante mecanizada; negativos no self-test.
- **Parser TOML (Codex)** — biblioteca real; prova empírica do env mínimo; fixture no F2.
- **`dist`** — evidência sanitizada + re-verificação isolada em duas fases = gating; `SECURITY.md`.
- **Fatos externos a re-verificar no F1/F2:** integridade/tag/commit; `engines.node`; tabela dos 5
  modos; boot MCP; shape do `opencode.jsonc`; semântica TOML do Codex.
- **Fornecedores experimentais** só sob opt-in. **Node/pwsh/npm** são dependências de runtime.

## Evidência coletada (2026-10-02)

- `node v24.18.0`/`python 3.14`; pacote vendorizado em pasta temporária; **boot offline** com env
  fictício + `initialize` MCP (`server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`).
- **`dist/provider.js` lido** em `%TEMP%\opencode\jev-probe\` (evidência **externa**; a commitar
  sanitizada em `xpz-mcp-integrations/fixtures/`).
- **Rodadas F0** (vereditos efêmeros; **submetida → produzida**; F0-2..F0-6 via opencode = **segundas
  opiniões**, `authorFamily=deepseek`):

| Rodada | RoundId (submetida) | Produzida | Revisores | Piso | Vereditos |
|---|---|---|---|---|---|
| F0-1 | `mcp-integrations-f0-v2` (v2) | v3 | meta, stealth, openai, anthropic | meta+openai+anthropic | 4× revisa |
| F0-2 | `mcp-integrations-f0-v3` (v3) | v4 | meta, stealth, deepseek | meta(deepseek=autor) | 3× revisa |
| F0-3 | `mcp-integrations-f0-v4` (v4) | v5 | meta, stealth, deepseek | meta(deepseek=autor) | 3× revisa |
| F0-4 | `mcp-integrations-f0-v5` (v5) | v6 | meta, stealth, deepseek | meta(deepseek=autor) | 3× revisa |
| F0-5 | `mcp-integrations-f0-v6` (v6) | v7 | meta, stealth, deepseek | meta(deepseek=autor) | 3× revisa |
| F0-6 | `mcp-integrations-f0-v7` (v7) | v8 | meta, stealth, deepseek | meta(deepseek=autor) | 3× revisa |

- **Recibo F0-1** (via `xpz-llm-delegate`): `preferenceSource=orchestrator`,
  `effectivePreferredPath=…\preferred-reviewers.opencode.json`; `attemptRole=primary`, `fallbackOf`
  vazio, `countsForDiversity=true`; `closeoutReady=false` (`vnext-pending-resubmission`).
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

## Apêndice — tabela de fornecedor (HIPÓTESE, não spec)

Até a fixture sanitizada do `dist`: `typesafe` (`TYPESAFE_API_KEY`, transport do SDK, `jev-latest`);
`openrouter` (`OPENROUTER_API_KEY`, `…/alpha/decisions`, headers, `jev-latest`→`jev-1.13`);
`cloudflare` (`JEV_CLOUDFLARE_*`/`CLOUDFLARE_*` + `CLOUDFLARE_ACCOUNT_ID`, `/accounts/<id>/ai/run`,
`{model, input:{state,questions}}`); `vercel` (`AI_GATEWAY_API_KEY`, transport do SDK); `compatible`
(`JEV_API_KEY`, POST na URL completa, `{model,state,questions}` → `{answers,usage?}`; **parcial**).

## Referências

- `https://github.com/jkudish/jev-mcp` (MIT); `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md`; `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md` —
  `commandcode/*` como **catálogo de vozes** (não confundir com o endpoint do Jev).
