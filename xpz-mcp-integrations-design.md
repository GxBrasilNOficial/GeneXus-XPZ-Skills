# xpz-mcp-integrations — design da skill (v11)

## Papel do documento

Design **vivo** (não congelado) da skill `xpz-mcp-integrations`, com decisões de **2026-10-02** e a
evidência empírica coletada.

- **v2** pré-análise · **v3** F0-1 (4 titulares) · **v4–v8** refinos opencode (segundas opiniões) ·
  **v9/v10** validações caras · **v11** 3ª validação cara (`openai/gpt-5.6-terra` via codex).

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

## Arquitetura

### Motor dirigido por descritor

Componente = comando, stdio, mapa de env, fonte de credencial, clientes, validação. Descritor de dados
(`components/jev.json`) com **schema fail-closed** e self-test. **Credencial por modo:** o descritor
declara, para cada fornecedor, **`secretEnvVar`**, **vars públicas permitidas**, **campos
obrigatórios** e **regras de exclusividade** (ver Fornecedor). A **exceção de endpoint** do modo
`compatible` é campo explícito do descritor.

### Classes de artefato e contrato por classe

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
- **Arquivos de cliente compartilhados — escrita serializada + transacional:**
  - **Alvo:** config do cliente, lock, temporário e backup devem ser **arquivos regulares**, **sem
    reparse point** (symlink/junction), **sem diretório/arquivo especial** — validado por
    `GetAttributes` (não só no diretório gerenciado da skill, também nos caminhos de config).
  - **Lock:** `<arquivo>.xpz-mcp.lock` (create-new / `FileShare.None`); falha → **recusar**.
  - **Ramos separados:** **criação exclusiva** (`FileMode.CreateNew`) e **substituição**
    (`File.Replace` com backup). Antes da promoção, **revalidar identidade/atributos** (tamanho, mtime,
    hash) **imediatamente**.
  - Sequência: ler+hash → calcular novo conteúdo → temp na mesma pasta → re-hash → **recusar se
    mudou** → backup imutável → check final (create×replace) → promoção atômica → idempotência por
    conteúdo.
  - **Honestidade:** o lock serializa **esta skill**; contra terceiro que ignore o lock, a detecção é
    **best-effort** (re-hash + `File.Replace`). **Recuperação:** lock preso → instruir; crash →
    temp+journal limpos na re-execução; destino inexistente → criação.
- Ponteiro **documental** na setup (fora do recibo; anti-padrão `reviewer-ro`). Dono do registro =
  `xpz-skills-setup`. **`AGENTS.md`/`README.md`:** **reconciliar** as listas (três seções do README +
  enumeração vigente do AGENTS), **adicionando só o que faltar** (`xpz-codex-apply-patch-alternative`
  já aparece em `AGENTS.md:11`; conferir a enumeração `:49` sem assumir).
- **Aresta de dependência:** `OpenCodeJsoncSupport.ps1` (a **criar**; dono-doc proposto
  `xpz-llm-delegate/SKILL.md`) ganha consumidor novo; registrada nos dois donos.
- **Rastreabilidade privada:** fixtures sanitizadas de `dist` são molde publicável → avaliar
  `GeneXus-XPZ-PrivateMap`; reconciliar `README.md:107` × `AGENTS.md:92-96`. **Licença:** cópia
  integral MIT + atribuição.

### Suporte JSONC compartilhado — frente própria (F1-pre), arquivo **a criar**

Diagnóstico verificado: `Find-JsoncMatchingBrace` ciente de string/cego a comentário;
`Find-JsoncKeyValueSpan` acha por `IndexOf` (comentário promete heurística de aspas inexistente);
`ConvertFrom-Jsonc` (Guard) é o scanner de referência **sem** trailing comma; `ConvertFrom-JsoncText`
(manifesto) é regex **não string-safe** que remove trailing comma e **também dispara dentro de
strings**; **bug vivo** em `Install-OpenCodeReviewerRoAgent.ps1:252`.

**Correção — *localizador estrutural*:** tokenizador → stream de tokens com spans; **unidade canônica
= code unit UTF-16** (`string` do .NET); **preservar encoding/BOM/EOL** do arquivo; buscar por
**caminho estrutural** (`mcp.jev`, `agent.reviewer-ro`); operações **sobre spans** que nunca recaem em
comentário/string. **"Byte-diff" = preservar regiões fora dos spans** (não igualdade integral).

**Matriz de migração obrigatória** (cada item aponta para a **biblioteca única**; o F1-pre só fecha com
trailing-comma e comentário/string passando por **cada rota real**):

| Consumidor | Defeito atual | Migra para |
|---|---|---|
| `Install-OpenCodeReviewerRoAgent.ps1` | `Find-JsoncMatchingBrace`/`Find-JsoncKeyValueSpan`; valida o arquivo inteiro (bug `:252`) | localizador estrutural |
| `OpenCodeReviewerRoGuard.ps1` | `ConvertFrom-Jsonc` (sem trailing comma) | suporte (scanner + trailing comma) |
| `Build-LlmDelegateCapabilityManifest.ps1` | `ConvertFrom-JsoncText` (regex não string-safe) | suporte (scanner) |
| `Test-OpenCodeReviewerRoSelfTest.ps1` + `Test-LlmDelegateCapabilityManifestSelfTest.ps1` | fixtures insufficientes | fixtures negativas novas |
| Futuros consumidores | — | biblioteca única |

**Golden de paridade** old-vs-new (inclui string com `, }`); **ordem:** núcleo+instalador primeiro,
**manifesto por último** com **pin de fallback**; **passo de maior risco = a extração**. **Lockstep
corrigido:** inventário/self-test de consumidores **na raiz**; **não** ampliar a auditoria de
`xpz-kb-parallel-setup` (o lockstep do `AGENTS.md` é para motor quebrado consumido por wrappers de KB
paralela — não este caso). **Fixtures negativas:** chave comentada; forma-de-chave em string; `{}` em
`/* */`; `//` em string; `//` trailing; aspas escapadas; bloco não-terminado; trailing comma; edição
fora de comentário/string; **não-ASCII**. **Revisão do F1-pre:** painel com ≥2 Criadores distintos do
autor + ≥1 voz fora do harness afetado.

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`; **versão `0.13.0`**.
- **Identidade e cadeia verificável (corrige o "commit imutável"):** a **identidade do artefato = o
  `integrity` sha512 do tarball** registrado no **lockfile comitado** (`resolved`+`integrity`); o
  **commit Git é proveniência**, não âncora (evita afirmar `commit == tarball`). Se houver archive Git
  aprovado, a equivalência commit→tarball é **registrada e verificada** explicitamente (sha512,
  conteúdo extraído, data, procedimento).
- **Manifesto de árvore ESPERADO, comitado** (`vendor/manifest.sha256`), **gerado em release
  controlada** com metadados: **commit**, **versão de npm e Node usadas**, **sha512 do tarball**,
  **sha256 por arquivo**, **data de captura**, escopo. O installer **compara a árvore instalada** contra
  esse baseline e **rejeita**: arquivos **ausentes ou excedentes**, **caminhos duplicados** após
  normalização, **reparse points**. Divergência de **ferramenta** (npm/Node) é reportada **separada** da
  divergência do **pacote**.
- **Evidência commitada (pré-condição de qualquer motor):** em `xpz-mcp-integrations/fixtures/`
  (rastreada): trechos **sanitizados** de `provider.ts`/`provider.js` (5 modos + vars), `engines.node`
  (**≥ 22**), `prepare` do `package.json`, boot `initialize`, **+ licença MIT integral + atribuição**.
  **Proveniência por fixture:** `commit`, origem, hash, **data de captura**, escopo — **sem** usar o
  README da `main` como prova da `0.13.0`. Até então, a tabela de Fornecedor é **hipótese**.
- **`npm ci --ignore-scripts` — justificado e testado:** o pacote declara `prepare`; usamos o `dist`
  pré-compilado. O teste prova que `dist/index.js` existe e o servidor sobe **sem** rodar `prepare`.
- **Vendor:** `npm ci --ignore-scripts --no-audit --no-fund` em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`; comparação contra o manifesto esperado.
  **Sem indireção mutável**: launcher versionado por path absoluto; comando do cliente aponta para o
  launcher daquela versão. Update = instalar + launcher + re-emitir config; rollback = re-emitir config
  anterior. **Sem junction/symlink** (hazard de `historico/...20260622-20260922.md:48`).
- **Semântica de rede (3 contextos):** (1) instalador/vendorizador: sem registro fora de install/update;
  (2) launcher/MCP: só o endpoint; (3) teste isolado (abaixo).
- **Contenção de rede — UMA implementação para o F1 (executável):** **regra de firewall de saída**
  (`New-NetFirewallRule`) **bloqueando não-loopback (e DNS/UDP-TCP 53) para o `node.exe` absoluto do
  vendor** durante a janela do teste; **requer elevação** (pré-requisito declarado). **Controle
  positivo:** um processo que **tenta** egressar **deve** ser detectado como bloqueado (não basta "não
  conectou"). **Evidência:** a regra + a tentativa bloqueada + ausência de resolução DNS. **Limpeza:**
  `Remove-NetFirewallRule`. **Fail-closed:** sem elevação/contensão disponível, o teste **não passa** e
  o **F1 fica bloqueado**.
- **Caminhos/segurança:** todo caminho gerenciado sob `%LOCALAPPDATA%\xpz-mcp-integrations` após
  **canonicalização**, **rejeitando reparse points** e raízes de outro drive; **ACL antes de persistir**;
  escrita atômica.

### Launcher portátil (molde gerado pela skill)

- **Comando = launcher PowerShell** (`["pwsh","-NoProfile","-File","<launcher-<versao>.ps1"]`).
- **Rota travada = `ProcessStartInfo`** (`UseShellExecute=$false`): define o **ambiente por-filho**
  (**só a variável de credencial do modo**; a chave **não** entra no ambiente do launcher) e faz
  **proxy de bytes** de stdin/stdout/stderr. **`& node` DESCARTADO** (exigiria expor a chave no
  ambiente do launcher).
- **Terminação/árvore:** o filho roda num **Job Object** com
  `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`; política: **EOF/cancelamento** → fechar streams, prazo curto,
  **encerrar a árvore**; **filho inesperado/orfão** → fechar todos os pipes e propagar estado. Garante
  que `node` não sobreviva com a chave no ambiente. Self-tests: **cancelamento, órfão, stderr intenso,
  término durante tráfego bidirecional**.
- **Invariante mecanizada:** silenciar preferences; **nenhum `Write-*`** para stdout (scan estático);
  logs só em stderr/arquivo; sem chave em log; **exit code = do filho**, propagado como última
  instrução; provar **payload binário grande** (sem re-encode/deadlock) e **zero bytes** fora do filho;
  **negativos pré-filho** com exit code próprio.
- **Runtime:** exige `pwsh` (7.4+). **Staleness do `node`:** reparo = re-resolver e re-emitir launcher.
- **Marcador de propriedade:** sentinela + manifesto; uninstall remove só se sentinela **e** path no
  manifesto; órfão = reportar.

### Detecção de pré-requisitos

Espelhar `GeneXusPythonPrerequisite.ps1`/`Test-XpzPowerShellRuntime.ps1`: **executável utilizável de
verdade** (rejeitar stub `WindowsApps`/alias da Store) para `node`/`npm`/`pwsh`.

## Fornecedor

Cinco modos. **Wire = hipótese** até as fixtures (Apêndice). **Credencial por modo** (o launcher injeta
**só** a var do modo selecionado):

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
  `compatible` de terceiro = **`warn` + confirmação explícita** **amarrada a** `hash(URL do endpoint) +
  modo + modelo + data` (invalidada se algum mudar), com **host/caminho redigidos** antes da
  confirmação; a chave **nunca** é persistida junto da autorização.
- **Cofre e tipo de credencial:** o cofre guarda o **modo ativo** + metadados do **tipo** (qual
  `secretEnvVar`), **sem** registrar o segredo em claro; trocar de modo exige re-entrada.
- **`compatible` = parcial** (handshake, não E2E). **Command Code** = preset sugerido. **Experimental
  opt-in:** 4 não provados fora do caminho feliz e dos self-tests do F1. **Import `auth.json`:**
  opcional, com ressalva (credencial `commandcode/*` do OpenCode é de gateway LLM).

## Credencial

- **Cofre:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`. **Blob:** DPAPI `CurrentUser`, **sem entropia
  adicional**, **campo `version`**, e **metadados do tipo** (modo + `secretEnvVar`) — **sem** o tipo
  misturado ao valor.
- **Tabela fonte × modo × comportamento:** vault-first; env só com `-CredentialSource env`; auditor
  sinaliza `credencial_divergente_env_vs_cofre` (**blocking**) só quando **não** houve override.
- **Entrada:** `Read-Host -AsSecureString`; sem transcript/history; não-eco; **ACL antes de persistir**.
- **`acl_nao_aplicavel` — bloqueia mutadores de blob** (criação/import/rotação/restore), salvo modo
  inseguro explicitamente autorizado e rotulado.
- **Backup do cofre:** local, retenção, mesma ACL, restore. **Restore inter-máquina** = **re-inserir a
  chave** (DPAPI não roaming). **Três eventos:** rotação (re-cifrar), remoção (preservar), incidente
  (apagar blob + revogar no provedor + orientar restart).
- **Limite honesto:** DPAPI protege em repouso; não contra processo do mesmo usuário, inspeção do env do
  filho, nem roaming. **Fronteira:** pacote + transitivas + endpoint. Chave nunca impressa/logada/copiada.

## Adaptadores de cliente (v1)

- **OpenCode — descoberta:** enumerar **todos** os candidatos (`opencode.json` e `opencode.jsonc`),
  **relatar**, declarar a regra observada do cliente/versão; em **ambiguidade real** (ambos presentes,
  sem precedência comprovada) → **bloquear sem escrever** e pedir escolha. Serializar para o formato
  efetivo (`.json` → JSON válido; `.jsonc` → localizador estrutural). `mcp.jev` (`type: local`,
  `command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`). Merge
  transacional; idempotente. **Shape = fato externo** + fixture sanitizada no F1.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**). **Biblioteca TOML vendorizada**
  (pin pelo commit do **próprio** lockfile + integridade + licença + re-verificação), no rigor do
  `jev-mcp`; o "subconjunto próprio" foi **descartado** (a config usa arrays `args`/`env_vars`, mapa
  `env`, possivelmente multiline). Prova de **round-trip** das formas reais (`command`, `args[]`,
  `env{}`, `env_vars[]`, `enabled`, `startup_timeout_sec`); proibido "span textual". **`env_vars`
  filtra o herdado** → launcher define **conjunto mínimo explícito provado com filho falso**
  (`SystemRoot`, `SystemDrive`, `TEMP`/`TMP`, `PATHEXT`, `COMSPEC`, `PATH` mínimo). Fixture sanitizada
  do `config.toml` no F2.

## Auditoria (estados e contrato)

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`. **Tabela estado → `exitCode`/classe por
  motor** (faixa reservada no F1-pre). **Precedência:** `versao_defasada` (pin do descritor) antes de
  `vendor_divergente` (manifesto).
- **Estado por cliente (novo):** `notConfigured` | `written` | `reloadPending` | `handshakeConfirmed` |
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

## Atualizar e remover

- **Reconciliação obrigatória:** antes de limpar/reparar, **ler as configs reais de cada cliente** e
  cruzar com o manifesto (o manifesto não é autoridade sobre a config viva); **plano/diff** + aprovação
  explícita por escrita/remoção material.
- **Atualizar:** consciente (release notes, breaking changes, backup, instalar + launcher + re-emitir
  config, teste, rollback por re-emissão). Nunca por existir versão nova.
- **Remover:** manifesto registra referências por cliente; launcher só sai quando **não restar
  referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre, `auth.json`,
  fornecedor e demais MCPs; no Codex, `enabled=false` quando manter a config.

## Testes

- **Self-tests offline:** detecção (rejeitar stub); JSONC — **localizador estrutural** (edição fora de
  comentário/string; **byte-diff** fora dos spans; **não-ASCII**; encoding/BOM/EOL preservados), fixtures
  negativas, **golden de paridade**, **matriz de migração** por rota; idempotência; **escrita
  serializada/transacional** (create×replace, corrida → recusa, arquivo especial → recusa,
  recuperação); backup+restore; rollback; schema do descritor; **round-trip DPAPI**; **re-emissão de
  launcher por versão**; **launcher** com filho falso (stdio binário, zero bytes fora do filho, exit
  code = do filho, sem deadlock; **cancel/órfão/stderr intenso**); **contenção de rede** (firewall +
  **controle positivo**); **comparação contra o manifesto esperado**.
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

- **F0** — design + revisão (F0-1..F0-9; faltam **painel de liberação**).
- **F1-pre** (frente própria; painel ≥2 Criadores distintos do autor + ≥1 fora do harness afetado) —
  criar `OpenCodeJsoncSupport.ps1` + golden + fixtures + **matriz de migração** + self-tests + inventário
  de consumidores na raiz.
- **F1** — skill (OpenCode + núcleo) + descritor Jev + launcher (`ProcessStartInfo` + Job Object) +
  cofre/DPAPI + vendorizador (baselines + manifesto + ferramenta versionada) + evidência sanitizada do
  `dist` + re-verificação **contida** gating + self-tests + docs. **F1 ≠ v1.**
- **F2** — Codex (biblioteca TOML vendorizada, round-trip + env mínimo) + self-tests TOML + auditoria de
  versão/drift + update/rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1`).
- **F4** — opcionais: fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** — `ProcessStartInfo` + Job Object; invariante mecanizada; cancel/órfão.
- **Biblioteca TOML (Codex)** — vendorizada sob rigor; round-trip; fixture.
- **`dist`** — evidência sanitizada + re-verificação **contida** (gating; sem contenção, bloqueia).
- **Fatos externos a re-verificar no F1/F2:** sha512 do tarball; `engines.node`; tabela dos 5 modos;
  boot; shape do `opencode.json`/`.jsonc`; semântica TOML do Codex.
- **Fornecedores experimentais** só sob opt-in. **Node/pwsh/npm** são dependências de runtime.

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

- **Recibo F0-1** (via `xpz-llm-delegate`): `preferenceSource=orchestrator`; `attemptRole=primary`,
  `countsForDiversity=true`; `closeoutReady=false` (`vnext-pending-resubmission`).
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

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
