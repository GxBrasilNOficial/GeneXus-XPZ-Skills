# xpz-mcp-integrations — design da skill (v10)

## Papel do documento

Design **vivo** (não congelado) da skill `xpz-mcp-integrations`, com decisões de **2026-10-02** e a
evidência empírica coletada.

- **v2** pré-análise · **v3** F0-1 (4 titulares) · **v4–v8** refinos opencode (segundas opiniões) ·
  **v9** 1ª validação cara · **v10** 2ª validação cara (`openai/gpt-5.6-terra` via codex).

**Autor e diversidade:** `authorFamily=deepseek` (agente orquestrador). Pelo `15`, revisores devem ser
de **famílias distintas da do autor**; rodadas por opencode (meta+deepseek) são **segundas opiniões**
(o deepseek é a família do autor). **Liberação** exige **≥2 Criadores distintos do autor** + **≥1 voz
fora do harness dominante** (endurecimento desta frente). Alternativa auditada: humano **congela**
(`resubmissionDeclinedByHuman` + quem + motivo + `RoundId`). Até lá, `vNextState=pendingResubmission`;
nada é implementado.

## Problema

Usuários das skills XPZ com acesso ao **Jev/System One** não têm caminho gerenciado para
instalar/auditar/reparar/atualizar/remover esse componente MCP. A configuração validada na máquina de
referência é manual e **não portátil** (path pessoal absoluto, rede/cache em runtime, transitivas sem
pin, chave amarrada ao `auth.json` do OpenCode). A `xpz-skills-setup` não cobre MCP de terceiros.

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
| 2 | Runtime | pacote **vendorizado** e pinado por **commit**; **sem `npx`** |
| 3 | Node | ausência **e** `< 22`; `winget` id `OpenJS.NodeJS.LTS` com aprovação; com `nvm`/`fnm`/`volta`, **relatar**; node sem npm = corrompido → relatar |
| 4 | Plataforma | **Windows** (cofre sem roaming) |
| 5 | Escopo v1 | **OpenCode + Codex** (completa no F2) |
| 6 | Credencial | **cofre** DPAPI, **vault-first**; env = **override explícito**; `auth.json` só import opcional |
| 7 | Fornecedor | 5 modos; `compatible`/Command Code **parcial**; outros 4 **experimental opt-in** |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade |

## Arquitetura

### Motor dirigido por descritor

Componente = comando, stdio, mapa de env, fonte de credencial, clientes, validação. Descritor de dados
(`components/jev.json`) com **schema fail-closed** e self-test. A **exceção de endpoint** do modo
`compatible` é **campo explícito do descritor**.

### Classes de artefato e contrato por classe

| Classe | Contrato |
|---|---|
| **Biblioteca dot-source** (ex.: `OpenCodeJsoncSupport.ps1`) | **sem** JSON de stdout, **sem** `-InputPath`, **sem** `ShouldProcess`; apenas funções; fail-closed se o suporte não existir (`Test-Path` + `throw`) |
| **Diagnóstico read-only** (auditor) | JSON de máquina, `overall`, tabela estado→`exitCode`/classe, `-InputPath` quando houver entrada; **sem** `-WhatIf` |
| **Mutador** (instalar/reparar/remover/atualizar/vendorizar) | JSON de máquina, `-WhatIf`/`ShouldProcess` (labels `*_SKIPPED` = propriedade de `xpz-skills-setup/SKILL.md`), `exitCode`, backup transacional |

**Faixa de `exitCode` reservada no F1-pre** (prova de não-colisão com `msbuild-exit-codes.catalog.json`;
tabela publicada **antes** do motor). Motores com `-InputPath`: entram na lista de cobertura do
`Test-XpzParameterNamingContract.ps1` (`02:972/977`) — default sim. **Vocabulário de evidência:** o `02`
é centrado em XML → **declarar extensão** para artefatos externos (JS/`provider.js`), com rótulo próprio.

### Fronteira com `xpz-skills-setup` e aresta de dependência

- `xpz-mcp-integrations`: MCP **externos opcionais**; `xpz-skills-setup`: skills, instrucionais,
  `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- **Arquivos de cliente compartilhados — escrita serializada + transacional:**
  1. Adquirir um **lock** (`<arquivo>.xpz-mcp.lock` via create-new / `FileShare.None`) — **serializa
     concorrentes desta skill**; falha de lock → **recusar** (não escrever).
  2. **Ler** o original + **hash** (sha256).
  3. **Calcular** o novo conteúdo (merge preservando comentários/entradas alheias).
  4. **Escrever** temp **na mesma pasta**.
  5. **Re-hash** do original imediatamente antes da troca; se mudou → **recusar**.
  6. **Backup imutável** (cópia + hash).
  7. **Troca atômica** (`File.Replace`/rename no mesmo volume).
  8. **Idempotência por conteúdo** (no-op se já é o desejado).
  - **Honestidade:** o lock serializa **as invocações desta skill**; contra um terceiro que ignore o
    lock, a detecção é **best-effort** (re-hash + `File.Replace` reduzem, não anulam, a janela) — dito
    explicitamente. **Recuperação:** lock preso → instruir/limpar; crash → temp+journal limpos na
    re-execução; destino inexistente → criação (sem corrida com existente).
  - Backup: local, retenção/limpeza, ACL, restore. O F1-pre **não** adiciona backup aos instaladores
    existentes (isolamento).
- Ponteiro **documental** na setup (área de não-escopo/fronteira; **excluído do recibo**, anti-padrão
  `reviewer-ro`, `xpz-skills-setup/SKILL.md:84-88`). Dono do registro = `xpz-skills-setup`.
  `AGENTS.md` **enumeração (`:49`)** recebe **duas** entradas (skill nova **e**
  `xpz-codex-apply-patch-alternative`).
- **Aresta de dependência:** `OpenCodeJsoncSupport.ps1` (a **criar**; dono-doc proposto
  `xpz-llm-delegate/SKILL.md`, alt.: cabeçalho do script) ganha consumidor novo; registrada nos dois
  donos.
- **Rastreabilidade privada (`AGENTS.md`):** fixtures sanitizadas de `dist` são molde publicável →
  avaliar `GeneXus-XPZ-PrivateMap`; reconciliar `README.md:107` × `AGENTS.md:92-96`. **Licença:** cópia
  integral MIT + atribuição junto do artefato.

### Suporte JSONC compartilhado — frente própria (F1-pre), arquivo **a criar**

Diagnóstico verificado: `Find-JsoncMatchingBrace` (instalador) é ciente de string/cego a comentário;
`Find-JsoncKeyValueSpan` acha por `IndexOf` (comentário promete heurística de aspas **inexistente**);
`ConvertFrom-Jsonc` (Guard) é o scanner de referência **sem** trailing comma; `ConvertFrom-JsoncText`
(manifesto) é regex **não string-safe** que **remove** trailing comma e **também dispara dentro de
strings**; **bug vivo** em `Install-OpenCodeReviewerRoAgent.ps1:252` (valida o arquivo inteiro).

**Correção — *localizador estrutural*:**
- **Tokenizador → stream de tokens com spans.** **Unidade canônica de span = índice de code unit
  UTF-16** (`string` do .NET/PowerShell); quando precisar de offset de bytes, converter explicitamente.
- **Preservar encoding e BOM do arquivo existente** (ler bytes, detectar BOM, reescrever no **mesmo**
  encoding/BOM) e **preservar EOL**; testar **não-ASCII** (acentos/emoji).
- **Busca por caminho estrutural** (`mcp.jev`, `agent.reviewer-ro`) navegando tokens/objetos;
  **abandona** `IndexOf` e os `Find-*`; erro tipado se o caminho cair em não-objeto.
- **Operações sobre spans** (insert/update/remove) que **nunca** recaem sobre comentário/string.
  **"Byte-diff" = regiões fora dos spans editados preservadas** (não igualdade integral após edição).
- **Golden de paridade old-vs-new** (inclui string com `, }`) antes de trocar o manifesto. **Ordem:**
  núcleo+instalador primeiro; **manifesto por último**, com **pin de fallback**. **Passo de maior risco
  = a extração.**
- **Lockstep — corrigido:** criar **inventário/self-test de consumidores na própria raiz**; **não**
  ampliar a auditoria de `xpz-kb-parallel-setup` (o lockstep do `AGENTS.md` cobre motor quebrado
  consumido por wrappers de KB paralela, o que **não** é este caso) — só tocar a auditoria de wrappers
  se existir consumidor de pasta paralela efetivamente coberto.
- **Fixtures negativas:** chave comentada; forma-de-chave em string; `{}` em `/* */`; `//` em string;
  `//` **trailing**; aspas escapadas; bloco não-terminado; trailing comma; **edição não recai em
  comentário/string**; **não-ASCII**.
- **Revisão do F1-pre:** painel com **≥2 Criadores distintos do autor** + **≥1 voz fora do harness
  afetado**.

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`; **versão `0.13.0`**. **Identidade imutável = hash de commit**
  (`5e0ca5cacd1556dc0b8c227648843d3ebf5bdc93`); a **tag `v0.13.0` é mutável** e serve só de rótulo.
- **Cadeia de suprimentos (dois baselines):**
  1. **Lockfile comitado** (`xpz-mcp-integrations/vendor/package-lock.json`, `resolved`+`integrity`).
  2. **Manifesto de árvore ESPERADO, comitado** (`vendor/manifest.sha256`: sha256 por arquivo),
     **gerado em release controlada** (não pelo `npm ci` do usuário). O installer compara a árvore
     instalada **contra esse baseline comitado** — detecta artefato divergente no destino.
  - **Limite honesto:** o baseline congela **o que auditamos**; se o pacote foi comprometido **na
     publicação**, o baseline também o congela — daí a **re-verificação do `dist`** (abaixo).
- **Evidência commitada (pré-condição de qualquer motor):** em `xpz-mcp-integrations/fixtures/`
  (rastreada; `.gitignore` re-inclui `/xpz-*/`): trechos **sanitizados** de `provider.ts`/`provider.js`
  (5 modos + vars do `compatible`), `engines.node` (**≥ 22**), o `prepare` do `package.json`, boot
  `initialize`, **+ licença MIT integral + atribuição**. Até então, a tabela de Fornecedor é **hipótese**.
- **`npm ci --ignore-scripts` — justificado e testado:** o pacote declara `prepare`; usamos o `dist`
  **pré-compilado**. O teste isolado prova que `dist/index.js` existe e o servidor sobe **sem** rodar
  `prepare`.
- **Vendor:** `npm ci --ignore-scripts --no-audit --no-fund` em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`; comparação contra o **manifesto esperado**.
  **Sem indireção mutável**: **launcher versionado por path absoluto**; comando do cliente aponta para o
  launcher daquela versão. Update = instalar + gerar launcher + re-emitir config; rollback = re-emitir
  config anterior. **Sem junction/symlink** (evita o hazard de
  `historico/pretooluse-auto-allow-trajetoria-20260622-20260922.md:48`). Retenção declarada.
- **Semântica de rede (3 contextos):** (1) instalador/vendorizador: sem registro fora de install/update;
  (2) launcher/MCP: só a conectividade do **endpoint**; (3) **teste isolado** (abaixo).
- **Re-verificação isolada do `dist` (gating de F1):** (1) instalação (registro permitido); (2)
  **execução contida** com **mecanismo Windows concreto**: rodar sob **AppContainer sem
  `internetClient`** (nega rede para a **árvore de processos**), ou `Windows Sandbox` com firewall de
  saída negando não-loopback; **permissões** necessárias declaradas; **condição de falha** = qualquer
  egresso não-loopback ou tentativa de DNS; **limpeza** do perfil/regra. **Se a contenção não puder ser
  aplicada no ambiente, o teste NÃO passa e o F1 fica bloqueado** (não se "aprova por ausência de
  prova"). Allowlist de hosts, ocorrências `fetch`/`undici`/`HttpClient`/telemetria, N transitivas,
  relatório sanitizado.
- **Caminhos/segurança:** todo caminho gerenciado sob `%LOCALAPPDATA%\xpz-mcp-integrations` após
  **canonicalização**, **rejeitando reparse points** e raízes de outro drive; **ACL antes de persistir**;
  **escrita atômica**.

### Launcher portátil (molde gerado pela skill)

- **Comando = launcher PowerShell** (`["pwsh","-NoProfile","-File","<launcher-<versao>.ps1"]`).
- **Rota travada = `ProcessStartInfo`** (`UseShellExecute=$false`), que define o **ambiente
  por-filho** (`Environment` do filho recebe `JEV_API_KEY`; **a chave NÃO entra no ambiente do
  launcher**) e faz **proxy de bytes** de stdin/stdout/stderr. **`& node` foi DESCARTADO** porque
  obrigaria a expor a chave no ambiente do **próprio** launcher — contradiz o isolamento.
- **Invariante mecanizada:** silenciar `$ProgressPreference`/`$InformationPreference`; **nenhum
  `Write-*`** para stdout (**scan estático**); logs só em stderr/arquivo; nenhum valor de chave em log;
  **exit code = do filho**, propagado como última instrução; provar **payload binário grande** (sem
  re-encode, sem deadlock) e **zero bytes** fora do filho.
- **Negativos pré-filho** (cofre ausente, blob corrompido, DPAPI outra máquina, `node` não resolvido)
  com **exit code próprio** e **zero bytes** no stdout. Self-test byte-a-byte.
- **Runtime:** exige `pwsh` (7.4+); auditoria reporta se faltar. **Staleness do `node`:** reparo =
  re-resolver e re-emitir o launcher.
- **Marcador de propriedade:** sentinela + manifesto; uninstall remove **só se** sentinela **e** path no
  manifesto; órfão = reportar.

### Detecção de pré-requisitos

Espelhar `GeneXusPythonPrerequisite.ps1`/`Test-XpzPowerShellRuntime.ps1`: **executável utilizável de
verdade** (rejeitar stub `WindowsApps`/alias da Store) para `node`/`npm`/`pwsh`.

## Fornecedor

Cinco modos. **Wire = hipótese** até as fixtures (Apêndice). `compatible` exige o contrato System
One/Jev; URL vai como veio; `cloudflare`/`vercel` não intercambiáveis. **`auto`:** com múltiplas
famílias de env, exigir `JEV_PROVIDER` explícito. **`endpoint_nao_verificado` — regra única:** presets
fechados = **blocking** se host divergir; `compatible` de terceiro = **`warn`+confirmação registrada**
(exceção = campo do descritor). **`compatible` = parcial** (handshake, não E2E). **Command Code** =
preset sugerido. **Experimental opt-in:** 4 não provados fora do caminho feliz e dos self-tests do F1.
**Import `auth.json`:** opcional, com ressalva (credencial `commandcode/*` do OpenCode é de gateway LLM).

## Credencial

- **Cofre:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\` (`%LOCALAPPDATA%` do ambiente). **Blob:**
  DPAPI `CurrentUser`, **sem entropia adicional**, **campo `version`**.
- **Tabela fonte × modo × comportamento:** vault-first; env só com `-CredentialSource env`; auditor
  sinaliza `credencial_divergente_env_vs_cofre` (**blocking**) só quando **não** houve override
  intencional.
- **Entrada:** `Read-Host -AsSecureString`; sem persistência em transcript/history; não-eco. **ACL antes
  de persistir**.
- **`acl_nao_aplicavel` — endurecido:** a auditoria **avisa**, mas **criação/import/rotação/restore do
  blob BLOQUEIAM** nesse estado, salvo **modo inseguro explicitamente autorizado e rotulado**.
- **Backup do cofre:** local, retenção, mesma ACL, restore. **Restore inter-máquina** = **re-inserir a
  chave** (DPAPI não roaming). **Três eventos separados:** rotação (re-cifrar), remoção (preservar),
  incidente (apagar blob + revogar no provedor + orientar restart).
- **Limite honesto:** DPAPI protege em repouso; não contra processo do mesmo usuário, inspeção do env do
  filho, nem roaming. **Fronteira:** pacote + transitivas + endpoint. Chave nunca impressa/logada/copiada.

## Adaptadores de cliente (v1)

- **OpenCode — descoberta determinística:** procurar `opencode.json` e depois `opencode.jsonc`
  (espelha o motor existente); **se ambos existirem → `entrada_em_conflito`/bloqueio** (exigir escolha);
  **serializar para o formato efetivamente usado** (`.json` → JSON válido; `.jsonc` → via localizador
  estrutural preservando comentários). `mcp.jev` (`type: local`, `command: ["pwsh","-NoProfile","-File",
  "<launcher>"]`, campo **`environment`**, não `env`). Merge transacional; idempotente. **Shape = fato
  externo** + fixture sanitizada no F1.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**). **Biblioteca TOML vendorizada**
  (pin por commit + integridade + licença + re-verificação), **no mesmo rigor do `jev-mcp`** — o
  "subconjunto próprio" foi **descartado**: a config real usa **arrays** (`args`, `env_vars`), **mapa**
  (`env`) e possivelmente multiline, que o subconjunto não leria. Prova de **round-trip** das formas
  reais (`command`, `args[]`, `env{}`, `env_vars[]`, `enabled`, `startup_timeout_sec`). Proibido "span
  textual". **`env_vars` filtra o herdado** → launcher define **conjunto mínimo explícito provado com
  filho falso** (`SystemRoot`, `SystemDrive`, `TEMP`/`TMP`, `PATHEXT`, `COMSPEC`, `PATH` mínimo) — ou
  resolve tudo por caminho absoluto. Fixture sanitizada do `config.toml` no F2.

## Auditoria (estados e contrato)

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`. **Tabela estado → `exitCode`/classe por
  motor** (faixa reservada no F1-pre). **Precedência:** `versao_defasada` (pin do descritor) antes de
  `vendor_divergente` (manifesto).
- **Ciclo de sucesso do cliente (novo):** `configurado` (arquivo escrito) → `cliente-recarregado` →
  `handshake-confirmado` → `E2E-opt-in`. A skill **informa a ação de recarga/reinício** necessária e
  **não** declara integração operacional validada antes de `handshake-confirmado`/`E2E`.
- **Offline:** `OK`; `ausente`; `entrada_quebrada`/`entrada_divergente`/`entrada_em_conflito`;
  `versao_defasada`; `vendor_ausente`/`vendor_divergente`/`vendor_sem_launcher`;
  `launcher_ausente`/`launcher_divergente`; `node_ausente`/`node_incompativel`/`node_path_nao_resolve`;
  `pwsh_ausente`; `fornecedor_ausente`; `fornecedor_nao_validado` (**warn**); `credencial_ausente`;
  `credencial_divergente_env_vs_cofre` (**blocking**, salvo override); `endpoint_nao_verificado`
  (**blocking** preset; **warn**+confirmação `compatible`); `acl_nao_aplicavel` (**warn** na auditoria;
  **blocking** nos mutadores de blob).
- **Online opt-in** (`-CheckUpdates`, com rede — contexto distinto): `atualizacao_disponivel` — informa,
  nunca auto-atualiza. Canonicalização de path antes de `entrada_divergente`.

## Atualizar e remover

- **Reconciliação obrigatória:** antes de limpar/reparar, **ler as configs reais de cada cliente**
  suportado e cruzar com o manifesto (o manifesto não é autoridade sobre a config viva). Produzir
  **plano/diff** e exigir **aprovação explícita por escrita/remoção material**.
- **Atualizar:** consciente (release notes, breaking changes, backup, instalar + launcher + re-emitir
  config, teste, rollback por re-emissão). Nunca por existir versão nova.
- **Remover:** manifesto registra referências por cliente; launcher só sai quando **não restar
  referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre, `auth.json`,
  fornecedor e demais MCPs; no Codex, `enabled=false` quando manter a config.

## Testes

- **Self-tests offline:** detecção (rejeitar stub `WindowsApps`); JSONC — **localizador estrutural**
  (edição não recai em comentário/string; **byte-diff** fora dos spans; **não-ASCII**; encoding/BOM/EOL
  preservados), fixtures negativas, **golden de paridade**; idempotência; **escrita serializada/
  transacional** (lock, corrida → recusa, recuperação); backup+restore; rollback; schema do descritor;
  **round-trip DPAPI**; **re-emissão de launcher por versão**; **launcher** com filho falso (stdio
  binário, zero bytes fora do filho, exit code = do filho, sem deadlock) **e negativos pré-filho**;
  **isolamento de rede contido** (AppContainer/Sandbox); **comparação contra o manifesto esperado**.
- **Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
  Self-tests de **TOML** no **F2**.
- **E2E** com `jev_classify` = validação manual opt-in; pré-requisito de `handshake-confirmado`.

## Documentação e paridade

- `README.md` trilíngue (duas listas por língua ×3 = seis pontos); `CHANGELOG.md` trilíngue;
  **`SECURITY.md` trilíngue** (seção do cofre nas três).
- `09` (`Dono:` + `Validação:`/`Tokens:`/`Exit:`); `02` (contrato de motor + vocabulário); `08` (nomear
  seções ou retirar).
- `AGENTS.md` (enumeração `:49`, duas entradas) + ponteiro documental na setup (fora do recibo);
  `xpz-llm-delegate/SKILL.md` (dono do JSONC + aresta).
- **`999`:** `:3283` com pin "commit + sha512/tag, valores a re-verificar" e preset **parcial**;
  **`:3277` alinhado**: a **validação cara foi feita (insumo)** e o que falta é o **painel de
  liberação** + execução. **Consultar o `998`** (lição de exit-code: `998:919-923`).
- Conformidade: `#requires -Version 7.4`; UTF-8 sem BOM (preservando BOM preexistente do arquivo do
  usuário); molde `.example.ps1`; `Test-XpzParameterNamingContract.ps1` **não** é gate geral; não
  enumerar ≥2 gates numa linha.
- **Ledger:** efêmero/gitignored em `Temp/revisao-por-pares/<RoundId>/`; **não versionar**, superando
  explicitamente o precedente legado não rastreado `.peer-review-rounds/matriz-14-*`.

## Fases

- **F0** — design + revisão (F0-1..F0-8; faltam **painel de liberação**).
- **F1-pre** (frente própria; painel ≥2 Criadores distintos do autor + ≥1 fora do harness afetado) —
  criar `OpenCodeJsoncSupport.ps1` + golden + fixtures + migração + self-tests + inventário de
  consumidores na raiz.
- **F1** — skill (OpenCode + núcleo) + descritor Jev + launcher (`ProcessStartInfo`) + cofre/DPAPI +
  vendorizador (baselines + manifesto) + evidência sanitizada do `dist` + re-verificação isolada gating +
  self-tests + docs. **F1 ≠ v1.**
- **F2** — Codex (biblioteca TOML vendorizada, prova de round-trip + env mínimo) + self-tests TOML +
  auditoria de versão/drift + update/rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1`).
- **F4** — opcionais: fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** — `ProcessStartInfo` (env por-filho + proxy); invariante mecanizada; negativos.
- **Biblioteca TOML (Codex)** — vendorizada sob rigor (pin+integridade+licença) ou implementação própria
  completa; prova de round-trip; fixture.
- **`dist`** — evidência sanitizada + re-verificação **contida** (gating; sem contenção, bloqueia).
- **Fatos externos a re-verificar no F1/F2:** hash de commit; `engines.node`; tabela dos 5 modos; boot;
  shape do `opencode.json`/`.jsonc`; semântica TOML do Codex.
- **Fornecedores experimentais** só sob opt-in. **Node/pwsh/npm** são dependências de runtime.

## Evidência coletada (2026-10-02)

- `node v24.18.0`/`python 3.14`; pacote vendorizado em pasta temporária; **boot offline** com env fictício
  + `initialize` MCP (`server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`).
- **`dist/provider.js` lido** em `%TEMP%\opencode\jev-probe\` (evidência **externa**; a commitar
  sanitizada). **Confirmado por fonte externa:** `0.13.0` exige Node **≥ 22** e declara `prepare`; o
  `provider.ts` confirma os 5 modos.
- **Rodadas F0** (vereditos efêmeros; F0-2..F0-6 opencode = segundas opiniões; `authorFamily=deepseek`):

| Rodada | RoundId (submetida) | Produzida | Revisores | Vereditos |
|---|---|---|---|---|
| F0-1 | `…-f0-v2` (v2) | v3 | meta, stealth, openai, anthropic | 4× revisa |
| F0-2..F0-6 | `…-f0-v3..v7` | v4..v8 | meta, stealth, deepseek | 3× revisa |
| F0-7 (cara) | `…-f0-codex-gpt` (v8) | v9 | openai/gpt-5.6-terra (codex) | 1× revisa |
| F0-8 (cara) | `…-f0-codex-gpt-v9` (v9) | v10 | openai/gpt-5.6-terra (codex) | 1× revisa |

- **Recibo F0-1** (via `xpz-llm-delegate`): `preferenceSource=orchestrator`,
  `effectivePreferredPath=…\preferred-reviewers.opencode.json`; `attemptRole=primary`, `countsForDiversity=true`;
  `closeoutReady=false` (`vnext-pending-resubmission`).
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

## Apêndice — tabela de fornecedor (HIPÓTESE, não spec)

`typesafe` (`TYPESAFE_API_KEY`, transport do SDK, `jev-latest`); `openrouter` (`OPENROUTER_API_KEY`,
`…/alpha/decisions`, headers, `jev-latest`→`jev-1.13`); `cloudflare` (`JEV_CLOUDFLARE_*`/`CLOUDFLARE_*`
+ `CLOUDFLARE_ACCOUNT_ID`, `/accounts/<id>/ai/run`, `{model, input:{state,questions}}`); `vercel`
(`AI_GATEWAY_API_KEY`, transport do SDK); `compatible` (`JEV_API_KEY`, POST na URL completa,
`{model,state,questions}` → `{answers,usage?}`; **parcial**).

## Referências

- `https://github.com/jkudish/jev-mcp` (MIT); `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md`; `15-revisao-por-pares.md`, `xpz-llm-delegate/SKILL.md` — `commandcode/*`
  como **catálogo de vozes** (não confundir com o endpoint do Jev).
