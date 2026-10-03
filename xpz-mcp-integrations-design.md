# xpz-mcp-integrations — design da skill (v23.1)

## Papel do documento

Design **vivo** (não congelado) da skill `xpz-mcp-integrations`, com decisões de **2026-10-02**,
redução de escopo de **2026-10-03** e a evidência empírica coletada.

- **v2** pré-análise · **v3** F0-1 (4 titulares) · **v4–v8** refinos opencode (segundas opiniões) ·
  **v9–v20** validações caras · **v21** **reorganização editorial** (separa DECISÃO de OBRIGAÇÃO DE
  IMPLEMENTAÇÃO; marca o ADIADO) · **v22** **redução de escopo** (decisão humana de 2026-10-03, a
  partir de parecer externo). **A v22 reabre decisões explicitamente:** a v1 passa a ser a **menor
  versão que preserva as propriedades de segurança essenciais**; os endurecimentos saem para o
  **Anexo B** (movidos, não apagados) · **v23** **correção de gaps da v22** (segunda opinião de
  subagente + observação de outro agente, **conferidas pelo orquestrador**; ver *Evidência coletada*):
  ciclo de atualização/remoção nos dois clientes, migração da entrada manual, validação do Codex por
  `tomllib`, chave só do cofre na v1 · **v23.1** quatro clarificações de texto (ver CHANGELOG).

**Estrutura:** o **corpo** carrega decisão, escopo, fronteira, contrato mínimo, fases e riscos. O
**Anexo A** carrega o detalhe técnico da **v1**, a provar por self-test no F1. O **Anexo B** preserva
os **endurecimentos adiados** (texto das v2–v21). A seção **Adiado / escopo-futuro** carrega o que sai
da v1.

**Propriedades essenciais da v1 (não cortáveis):** sem `npx` em runtime; pin por **integridade**
(lockfile); `npm ci --ignore-scripts`; chave **só** no cofre DPAPI, nunca no config do cliente; backup
antes de gravar config de cliente; **nada gravado sem aprovação**; ciclo instalar/auditar/reparar/
atualizar/remover.

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
  neutro. **Público:** comunidade. **A v1 (OpenCode + Codex mínimo) completa no F1** (v22).
- **Fornecedor:** só `compatible` com preset **Command Code** (v22).

## Não-escopo da v1

Fork; Cursor e Claude Code; macOS/Linux; instalar ferramentas; criar conta; `skills/jev/`; uso
automático; MCPs sem descritor; vender fornecedores não provados como validados.

## Decisões travadas (2026-10-02; revisadas na v22 em 2026-10-03)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Nome | `xpz-mcp-integrations` |
| 2 | Runtime | pacote **vendorizado** e pinado; **sem `npx`** |
| 3 | Node | ausência **e** `< 22`; `winget` id `OpenJS.NodeJS.LTS` com aprovação; com `nvm`/`fnm`/`volta`, **relatar**; node sem npm = corrompido → relatar |
| 4 | Plataforma | **Windows** (cofre sem roaming) |
| 5 | Escopo v1 | **OpenCode + Codex mínimo** (completa no F1 — v22) |
| 6 | Credencial | **cofre** DPAPI; na v1 a chave vem **só do cofre** (override por env → **Anexo B.7**, v23); `auth.json` só import opcional |
| 7 | Fornecedor | descritor declara os 5 modos como **dado**; a v1 **implementa e testa só `compatible`** com preset **Command Code** (**parcial**); os outros 4 → **F4** (v22) |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade |
| 10 | Tamanho da v1 | **v1 mínima** que preserva as propriedades essenciais; endurecimentos → **Anexo B** (v22) |

## Arquitetura — decisões

### Motor dirigido por descritor

Componente = comando, stdio, mapa de env, fonte de credencial, clientes, validação. Descritor de dados
(`components/jev.json`) com **schema fail-closed** e self-test. O descritor declara, por fornecedor,
**`secretEnvVar`**, **vars públicas permitidas**, **campos obrigatórios** e **regras de exclusividade**;
a **exceção de endpoint** do modo `compatible` é campo explícito. Detalhe: **Anexo A.1**.

### Classes de artefato

| Classe | Contrato |
|---|---|
| **Diagnóstico read-only** (auditor) | JSON de máquina, `overall`, tabela estado→`exitCode`/classe, `-InputPath`; sem `-WhatIf` |
| **Mutador** (instalar/reparar/remover/atualizar/vendorizar) | JSON de máquina, `-WhatIf`, `exitCode`, backup transacional |

A classe **biblioteca dot-source** (`OpenCodeJsoncSupport.ps1`) saiu da v1 na v22 (ver
`999` — «JSONC do OpenCode — biblioteca única e migração dos consumidores»).

**Faixa de `exitCode` reservada no F1** (não-colisão com `msbuild-exit-codes.catalog.json`; tabela
antes do motor). Motores com `-InputPath` entram na lista de `Test-XpzParameterNamingContract.ps1`
(`02:972/977`). **Vocabulário de evidência:** o `02` é centrado em XML → **declarar extensão** para
artefatos externos, com rótulo próprio.

### Fronteira com `xpz-skills-setup` e aresta de dependência

- `xpz-mcp-integrations`: MCP externos opcionais; `xpz-skills-setup`: skills, instrucionais,
  `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- **Arquivos de cliente compartilhados:** escrita **serializada + transacional**, com lock próprio,
  validação de atributos do arquivo-alvo e promoção atômica (ancestralidade inteira → **Anexo B.2**). O lock serializa **esta skill**;
  contra terceiro que o ignore, a detecção é **best-effort**. Protocolo completo: **Anexo A.2**.
- Ponteiro **documental** na setup (fora do recibo; anti-padrão `reviewer-ro`). Dono do registro =
  `xpz-skills-setup`. **`AGENTS.md`/`README.md`:** **reconciliar** as listas (três seções do README +
  enumeração vigente do AGENTS), **adicionando só o que faltar** (`xpz-codex-apply-patch-alternative`
  já aparece em `AGENTS.md:11`; conferir a enumeração `:49` sem assumir).
- **Aresta de dependência:** a v1 **reaproveita** o mecanismo JSONC já usado por
  `Install-OpenCodeReviewerRoAgent.ps1`/`OpenCodeReviewerRoGuard.ps1` (dono-doc
  `xpz-llm-delegate/SKILL.md`), **sem** migrar consumidores; a aresta é registrada nos dois donos. A
  biblioteca única é frente própria no `999`.
- **Rastreabilidade privada:** fixtures sanitizadas de `dist` são molde publicável → avaliar
  `GeneXus-XPZ-PrivateMap`; reconciliar `README.md:107` × `AGENTS.md:92-96`. **Licença:** cópia
  integral MIT + atribuição.

### OpenCode — reaproveitar o mecanismo JSONC existente (v22)

O `opencode.jsonc` real tem comentários (o `reviewer-ro` já grava nele), então recusar JSONC
inviabilizaria a v1. **Decisão (v22):** a v1 **reaproveita** o mecanismo já em uso pelo `reviewer-ro`
— **inserção textual** + **validação pós-edição por parse completo** + checagem de que `mcp.jev` ficou
na forma esperada. Qualquer falha → **nada é gravado**, estado `edicao_manual_necessaria` e o trecho
pronto para o usuário colar. **Sem** criar biblioteca nova e **sem** migrar outros consumidores.

A biblioteca única com *localizador estrutural* e a matriz de migração viraram **frente própria** no
`999` (desenho preservado no **Anexo B.3**); quando ela existir, este consumidor migra junto. Detalhe
da v1: **Anexo A.3**.

### Execução do MCP — vendorização

- **Pacote:** `@jkudish/jev-mcp`; **versão `0.13.0`**.
- **Identidade do artefato = `integrity` sha512 do tarball** no **lockfile comitado**; o **commit Git é
  proveniência**, não âncora. O `npm ci` já confere o `integrity` de cada pacote contra o lockfile.
- **`npm ci --ignore-scripts`** (o pacote declara `prepare`; usamos o `dist` pré-compilado) em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`.
- **Atualizar** = novo `package.json`/lockfile no repositório + reinstalar + re-emitir config.
  **Rollback** = versão anterior do repositório + backup do config. `-CheckUpdates` **apenas informa**.
- **Sem indireção mutável**: launcher versionado por path absoluto; **sem junction/symlink** (hazard de
  `historico/...20260622-20260922.md:48`).
- **Evidência sanitizada do `dist`, commitada com proveniência, é pré-condição de qualquer motor** —
  na v1, restrita ao modo `compatible` + `engines.node` + `prepare` + boot + licença.
- **Semântica de rede (2 contextos na v1):** (1) instalador/vendorizador: sem registro fora de
  install/update; (2) launcher/MCP: só o endpoint. O teste isolado de egresso está no **Anexo B.4.6**.
- **Caminhos/segurança:** todo caminho gerenciado sob `%LOCALAPPDATA%\xpz-mcp-integrations` após
  **canonicalização**; **ACL antes de persistir**; escrita atômica.
- **Adiado para o Anexo B (v22):** manifesto de árvore `manifest.sha256` (sha256 por arquivo),
  catálogo de bundles aprovados, rollback por bundle com retenção, rejeição de reparse points em toda
  a ancestralidade.

Bootstrap executável e evidência do `dist`: **Anexo A.4**.

### Launcher portátil (molde gerado pela skill)

- **Comando = launcher PowerShell** (`["pwsh","-NoProfile","-File","<launcher-<versao>.ps1"]`).
- **Rota da v1 (v22) = `ProcessStartInfo`** com `UseShellExecute=false` e **sem redirecionar o
  stdio**: o `node` **herda os handles** do cliente (sem re-encode, sem cópia de bytes pelo launcher).
  O launcher espera o filho e devolve o **exit code do filho**.
- **Ambiente do filho = limpo + allowlist do descritor** (não herda): só a variável secreta do modo, as
  vars públicas permitidas lidas do `config.json`, e o mínimo de sistema/runtime.
- **Encerramento:** confia no **fim do stdin** — o cliente fecha o pipe e o servidor MCP sai. Prova no
  self-test de boot. Órfão se o cliente não fechar o stdin = **risco aceito** (ver *Riscos*).
- **Por que o `ProcessStartInfo` volta:** nas v2–v21 ele foi descartado por não permitir criação
  suspensa (necessária só para o Job Object, agora adiado). O `& node` segue fora porque herdaria o
  ambiente inteiro do launcher; o `ProcessStartInfo` monta o ambiente limpo do filho. O *Limite
  honesto* da Credencial já aceita que DPAPI não protege contra processo do mesmo usuário.
- **Invariante mecanizada:** nenhum byte do launcher em stdout; **exit code = do filho**; sem chave em
  log.
- **Runtime:** exige `pwsh` (7.4+). **Staleness do `node`:** reparo = re-resolver e re-emitir launcher.
- **Marcador de propriedade:** sentinela + manifesto de instalação (A.12); uninstall remove só se
  sentinela **e** path no manifesto; órfão = reportar.
- **Adiado para o Anexo B.1 (v22):** `CreateProcessW` + `CREATE_SUSPENDED` + Job Object +
  `ResumeThread`, limpeza pós-criação, política de árvore, testes de cancelamento/órfão/stderr
  intenso/payload binário grande.

Detalhe da v1: **Anexo A.1**.

### Detecção de pré-requisitos

Espelhar `GeneXusPythonPrerequisite.ps1`/`Test-XpzPowerShellRuntime.ps1`: **executável utilizável de
verdade** (rejeitar stub `WindowsApps`/alias da Store) para `node`/`npm`/`pwsh`. Node **gated**
(`>= 22`): `< 22` é bloqueante, acima disso é reportada. **Python 3.11+** é **opcional** (v23): só o
adaptador do Codex o usa, para validar o `config.toml`; ausente → Codex em `edicao_manual_necessaria`,
o resto da skill segue. Detalhe: **Anexo A.5**.

## Fornecedor

O descritor declara cinco modos como **dado**; a **v1 implementa e testa só `compatible`** (v22). **Wire
= hipótese** até as fixtures (Apêndice). O launcher injeta **só** a var do modo selecionado:

| Modo | `secretEnvVar` | Vars públicas / obrigatórias | Status |
|---|---|---|---|
| `typesafe` | `TYPESAFE_API_KEY` | `JEV_MCP_MODEL` (default `jev-latest`) | F4 — não implementado na v1 |
| `openrouter` | `OPENROUTER_API_KEY` | `JEV_OPENROUTER_BASE_URL` | F4 — não implementado na v1 |
| `cloudflare` | `CLOUDFLARE_API_TOKEN` (ou `JEV_CLOUDFLARE_API_TOKEN`) | `CLOUDFLARE_ACCOUNT_ID` (**não-secreta**), `JEV_CLOUDFLARE_BASE_URL` | F4 — não implementado na v1 |
| `vercel` | `AI_GATEWAY_API_KEY` | — | F4 — não implementado na v1 |
| `compatible` | `JEV_API_KEY` | `JEV_API_BASE_URL` (**URL completa**), `JEV_MCP_MODEL` | **parcial** (v1) |

- `compatible` exige o contrato System One/Jev; URL vai como veio. Com modo único na v1, a regra
  `auto`/`JEV_PROVIDER` não se aplica (volta no F4).
- **`endpoint_nao_confirmado` — regra da v1:** host igual ao do preset **Command Code** = OK; host
  diferente = **aviso + confirmação explícita** do usuário. Host/caminho **redigidos** antes da
  confirmação.
- **Registro de configuração não secreto** `%LOCALAPPDATA%\xpz-mcp-integrations\config.json` (ACL
  só-dono; UTF-8 sem BOM; schema versionado) é a **fonte persistente das variáveis públicas** — é dele
  que o launcher reconstrói o ambiente do filho. **Nunca** contém a chave. Schema: **Anexo A.6**.
- **Cofre:** guarda a chave do modo `compatible`, **sem** registrar o segredo em claro.
- **`compatible` = parcial** (handshake, não E2E). **Command Code** = preset sugerido. **Import
  `auth.json`:** opcional, com ressalva (credencial `commandcode/*` do OpenCode é de gateway LLM).
  É uma operação **única de bootstrap/migração para o cofre** (v23.1): o launcher **nunca** lê o
  `auth.json` em runtime, e a importação **não altera** o `auth.json`.

## Credencial

- **Cofre neutro** em `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`, blob **DPAPI `CurrentUser`**,
  **única fonte da chave na v1** (v23): o launcher lê do cofre e não aceita chave por variável de
  ambiente. O override por env (`-CredentialSource env`) e o estado
  `credencial_divergente_env_vs_cofre` foram para o **Anexo B.7** — fazê-los funcionar exigiria
  levar a escolha até o launcher e passar a variável pelo filtro de env do Codex.
- **`acl_nao_aplicavel` bloqueia mutadores de blob** (v22: sem «modo inseguro»).
- **Recuperar = re-inserir a chave** (DPAPI não roaming); a v1 **não** mantém backup/retenção do
  cofre (v22).
- **Limite honesto:** DPAPI protege em repouso; não contra processo do mesmo usuário, inspeção do env do
  filho, nem roaming. **Fronteira:** pacote + transitivas + endpoint. Chave nunca
  impressa/logada/copiada.

Formato do blob, entrada não-eco, ACL e os três eventos (rotação, remoção, incidente): **Anexo A.7**.

## Adaptadores de cliente (v1)

- **OpenCode (F1):** raiz gerenciada na v1 = **global** `~/.config/opencode/`; **projeto-local
  (`.opencode/`) fora do escopo da v1**. Entrada `mcp.jev` (`type: local`, `command: ["pwsh",...]`,
  campo **`environment`**, não `env`). Edição pelo mecanismo JSONC existente + validação pós-edição
  (ver *OpenCode — reaproveitar o mecanismo JSONC existente*); transacional, idempotente. **Shape =
  fato externo** + fixture sanitizada no F1.
- **Codex (F1, mínimo — v22/v23):** `~/.codex/config.toml`, bloco `[mcp_servers.jev]` gravado **entre
  marcadores de comentário próprios da skill**, **sem biblioteca TOML de edição**. A **detecção e a
  validação** usam o `tomllib` da biblioteca padrão do Python 3.11+ (só leitura): antes de gravar, o
  arquivo original precisa ser lido sem erro; depois de montado, o texto novo precisa ser lido sem erro
  e conter `mcp_servers.jev` exatamente como emitido. Isso pega **qualquer grafia** equivalente
  (`[mcp_servers.'jev']`, chave pontilhada, tabela inline, `jev.*` dentro de `[mcp_servers]`), que
  uma busca por linha não pegaria e que tornaria o arquivo inválido por declaração duplicada. **Sem
  Python 3.11+** → `edicao_manual_necessaria` com o trecho pronto.
- **Entrada que a skill reconhece (v23):** uma entrada só é tratada como da skill se for
  **byte-idêntica** a um bloco/entrada que a skill emitiu, com o hash registrado no **manifesto de
  instalação** (Anexo A.12). Só essas a skill substitui (atualizar/reparar) ou remove, sempre com diff
  e aprovação. Qualquer outra coisa → `entrada_em_conflito`, sem tocar.
- **Migração da entrada manual (v23):** quem já tem `mcp.jev` (ou `[mcp_servers.jev]`) configurado à
  mão — caso do usuário de referência — recebe o diff e, **com aprovação explícita**, a substituição
  (backup antes). Valores públicos (`JEV_API_BASE_URL`, `JEV_MCP_MODEL`) vão para o `config.json`; se
  houver chave no config do cliente, ela é **oferecida** para importação no cofre e sai do config.
  **Ordem (v23.1):** gravar o blob DPAPI, conferir que ele descriptografa de volta para o mesmo valor
  e **só então** retirar a chave do config. Se o cofre falhar, o config do cliente fica **intocado**.

Que variáveis de ambiente o Codex repassa ao launcher (`env_vars` filtra o herdado) é **fato a
verificar** com filho falso no F1. Fixture sanitizada do `config.toml` no F1. A biblioteca TOML
vendorizada com round-trip está no **Anexo B.8**.

Algoritmo de descoberta/precedência e casos de `entrada_em_conflito`: **Anexo A.8**.

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
  cruzar com o **manifesto de instalação** (A.12; ele não é autoridade sobre a config viva);
  **plano/diff** + aprovação explícita por escrita/remoção material.
- **Atualizar:** consciente (release notes, breaking changes, backup, novo lockfile no repositório,
  instalar + launcher + re-emitir config, teste; rollback = versão anterior do repositório + backup do
  config). Nunca por existir versão nova.
- **Remover:** o manifesto de instalação registra referências por cliente; launcher só sai quando
  **não restar referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar
  cofre, `auth.json`, fornecedor e demais MCPs. Na v1, remover significa **retirar a entrada**; não
  há estado «desabilitado» (`enabled=false`), que exigiria uma segunda forma canônica (v23).

## Testes — nível de decisão

- **Self-tests offline (v1)** cobrem detecção, edição JSONC com validação pós-edição, bloco com
  marcadores do Codex, idempotência, escrita transacional, backup/restore, schema do descritor,
  round-trip DPAPI, re-emissão de launcher por versão, launcher com filho falso e encerramento por fim
  do stdin. Inventário executável: **Anexo A.10**.
- **O gate do `dist` no F1 é revisão estática do `dist` + boot sem chave.** O teste de egresso de rede
  contido **não** é gate (ver **Adiado**).
- **Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
- **E2E** com `jev_classify` = validação manual opt-in; um E2E aprovado **promove** o cliente de
  `handshakeConfirmed` para `e2eOptInConfirmed`.

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

- **F0** — design + revisão (F0-1..F0-18; v22 reduzida; falta **painel de liberação**).
- **F1 = v1 completa (v22)** — **reservar a faixa de `exitCode`** + skill + descritor Jev (só
  `compatible`) + launcher `ProcessStartInfo` + cofre/DPAPI + vendorizador (lockfile + `npm ci
  --ignore-scripts`) + **evidência sanitizada do `dist` com proveniência** + **revisão estática do
  `dist` + boot sem chave** (gate) + OpenCode (mecanismo JSONC existente) + Codex mínimo (bloco com
  marcadores) + auditoria + atualizar/remover + self-tests + docs.
- **F2** — endurecimentos do **Anexo B**, **só quando houver motivo concreto** (cada um entra por
  decisão própria).
- **F3** — Cursor + Claude Code (coordenar com `Install-CursorGlobalInstructionsMcp.ps1`).
- **F4** — opcionais: os outros 4 fornecedores; backend Python; fork/espelho.
- O antigo **F1-pre** (biblioteca JSONC) saiu desta frente e virou entrada própria no `999`.

## Riscos e decisões em aberto

- **Launcher stdio** — `ProcessStartInfo` com stdio herdado; invariante mecanizada; encerramento por
  fim do stdin.
- **`dist`** — evidência sanitizada + **revisão estática + boot sem chave** como gate do F1; sem a
  evidência commitada, bloqueia.
- **Fatos externos a re-verificar no F1:** sha512 do tarball; `engines.node`; modo `compatible`; boot;
  saída do servidor no fim do stdin; shape do `opencode.json`/`.jsonc`; env repassado pelo Codex ao
  launcher.
- **Node/pwsh/npm** são dependências de runtime.
- **Riscos aceitos da v22 (redução de escopo):**
  - **órfão** se o cliente não fechar o stdin (sem Job Object);
  - **arquivo da árvore vendorizada adulterado depois da instalação não é detectado** (sem manifesto
    por arquivo; a integridade vale no momento do `npm ci`);
  - **limites conhecidos do motor JSONC existente** — mitigados pela validação pós-edição fail-closed
    e pelo trecho manual;
  - **edição manual dentro do bloco do Codex** vira `entrada_em_conflito` (a skill não sobrescreve).
- **Risco aceito da v23 — reescrita do `config.toml` pelo próprio Codex:** se o Codex gravar uma
  tabela nova e ela cair entre os marcadores (hipótese **não testada**, deduzida do comportamento de
  editores TOML que mantêm o comentário final no fim do arquivo), o bloco deixa de ser byte-idêntico e
  vira `entrada_em_conflito`. Resultado: resolução manual, **sem perda de dados** (a skill não remove
  nem substitui o que não reconhece). Comportamento a verificar no F1.
- **Risco aceito da contenção opt-in:** sem o teste de egresso contido, a garantia de que a árvore
  vendorizada não fala com a rede fora do endpoint permanece **argumentativa** (código estático + boot),
  não **demonstrada**. Decisão consciente para não travar o F1 em pré-requisito de máquina.

## Adiado / escopo-futuro

- **Endurecimentos da v22 → Anexo B** (texto preservado, entram no F2 por decisão própria): launcher
  nativo com Job Object (**B.1**); validação de atributos em toda a ancestralidade e registro de
  recuperação de escrita interrompida (**B.2**); biblioteca JSONC única + matriz de migração (**B.3**,
  e entrada própria no `999`); manifesto de árvore e catálogo de bundles com rollback por bundle
  (**B.4.2**, **B.4.4**); runtime Node dedicado hash-registrado (**B.5**); biblioteca TOML vendorizada
  com round-trip (**B.8**); backup/retenção do cofre e «modo inseguro» de ACL.
- **Teste de egresso de rede contido (Windows Sandbox) — rebaixado a endurecimento opt-in, NÃO é gate
  do F1.** Motivo: exigir **Windows Sandbox** como pré-requisito explícito travava o F1 em máquina que
  não o tem (fail-closed por ambiente, não por defeito do artefato). O **gate do F1 passa a ser revisão
  estática do `dist` + boot sem chave**. Quem quiser o endurecimento roda o protocolo do **Anexo B.4.6**
  (topologia executável em Sandbox com `<Networking>Disable</Networking>`, controle positivo por
  processo filho, recibo verificado no host). O filtro `New-NetFirewallRule` permanece **só
  diagnóstico** — é por programa e **não** contém a árvore; **nunca** critério de aprovação.
- **AppContainer** — frente futura, até ter mecanismo de criação/lançamento e prova de que a árvore
  está no container **especificados e testados**.
- **F3** — Cursor e Claude Code.
- **F4** — os outros 4 fornecedores (implementar e validar); backend **Python** (`typesafe-mcp` no
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
- **Parecer externo (chat web, 2026-10-03) — insumo, fora do painel:** plano tecnicamente sólido, mas
  cresceu além do problema (biblioteca JSONC como projeto paralelo, launcher nativo, vendorização em
  nível corporativo, 5 fornecedores). Motivou a **v22**. Diagnóstico do orquestrador: as rodadas
  F0-7..F0-18 tiveram **um único revisor** adversarial, e cada gap corrigido virou camada nova sem
  pergunta de proporção. **Próxima rodada:** instruir os revisores a avaliar se a v1 é a **menor** que
  preserva as propriedades essenciais, **sem** acrescentar endurecimento.
- **Segunda opinião sobre a v22 (2026-10-03, subagente do orquestrador; parecer solo, não revisão por
  pares)** — instruída a apontar só gaps em que a v1 não funciona, quebra propriedade essencial,
  contradiz a si mesma ou arrisca dados; 10 gaps. **Observação de outro agente** (3 pontos, 2
  coincidentes). O orquestrador **conferiu cada claim** antes de aceitar:
  - `tomllib` (Python 3.14): `[mcp_servers.'jev']`, `mcp_servers.jev.command`, `jev.command` dentro de
    `[mcp_servers]`, tabela inline e cabeçalho com espaços + o bloco da skill → **todos inválidos**
    («Cannot declare ('mcp_servers', 'jev') twice»). O descarte desse caso pelo subagente estava errado.
  - `opencode.jsonc` real: `mcp.jev` manual com `type`, `command`, `environment`
    (`JEV_PROVIDER`/`JEV_API_BASE_URL`/`JEV_MCP_MODEL`, sem chave) e `enabled` → a migração é o caso real.
  - `Install-OpenCodeReviewerRoAgent.ps1` executa código no nível do script → dot-source grava.
  - pwsh 7.6.6: `ConvertFrom-Json` aceita vírgula final e devolve o último valor em chave duplicada;
    o `ConvertFrom-Jsonc` do Guard só tira comentários e chama `ConvertFrom-Json` → a «hipótese do bug
    da linha 252» **não se reproduz no 7.6** (7.4 não testado).
  - Deslocamento do marcador pelo editor do Codex: **dedução**, não testada (ver *Riscos*).

---

## Anexo A — Obrigações de implementação da v1 (a provar por self-test no F1)

Detalhe que a implementação da **v1** deve honrar e o self-test deve demonstrar. Reescrito na **v22**
para o escopo reduzido; o detalhe dos endurecimentos adiados está no **Anexo B**.

### A.1 Launcher — `ProcessStartInfo`, ambiente e encerramento

**Rota da v1:** `ProcessStartInfo` com `UseShellExecute=false`, **sem** `RedirectStandard*` — o `node`
herda os handles de stdio do launcher (que são os do cliente). O launcher chama `WaitForExit()` e
termina com o **exit code do filho**. `& node` segue fora (herdaria o ambiente inteiro do launcher).

**Ambiente do filho = limpo + allowlist do descritor (não herda):** o launcher **limpa** o
`Environment` do `ProcessStartInfo` e monta com **(a)** `JEV_API_KEY` lida do cofre; **(b)** as
**variáveis públicas do `compatible`, lidas do `config.json`** (`JEV_API_BASE_URL`, `JEV_MCP_MODEL`);
**(c)** o **mínimo de sistema/runtime** (`SystemRoot`, `SystemDrive`, `TEMP`/`TMP`, `PATHEXT`,
`COMSPEC`, `PATH` mínimo). **Não** propaga o ambiente inteiro.

**Encerramento:** o servidor MCP sai no **fim do stdin** (cliente fecha o pipe); o launcher apenas
espera. Self-test de boot prova a saída no fim do stdin. Órfão se o cliente não fechar o stdin = risco
aceito (corpo, *Riscos*).

**Invariante mecanizada:** silenciar preferences; **nenhum `Write-*`** para stdout (scan estático);
logs só em stderr/arquivo; sem chave em log; **exit code = do filho**, propagado como última instrução;
**negativos pré-filho** (cofre ausente, `config.json` inválido, Node ausente) com exit code próprio e
**zero bytes** em stdout.

**Descritor — credencial por modo:** o descritor declara, para cada fornecedor, `secretEnvVar`, vars
públicas permitidas, campos obrigatórios e regras de exclusividade; a exceção de endpoint do
`compatible` é campo explícito. Schema **fail-closed** + self-test.

### A.2 Caminhos, atributos/ACL e escrita serializada e transacional

- **Alvo:** config do cliente, lock, temporário e backup devem ser **arquivos regulares**, **sem
  reparse point** (symlink/junction) **no próprio arquivo** (folha), **sem diretório/arquivo
  especial**. A validação de toda a ancestralidade está no **Anexo B.2**.
- **Lock:** `<arquivo>.xpz-mcp.lock` (create-new / `FileShare.None`); falha → **recusar**.
- **Ramos separados:** **criação exclusiva** (`FileMode.CreateNew`) e **substituição** (`File.Replace`
  com backup). Antes da promoção, **revalidar identidade/atributos** (tamanho, mtime, hash)
  **imediatamente**.
- **Sequência:** ler+hash → calcular novo conteúdo → temp na mesma pasta → re-hash → **recusar se
  mudou** → backup imutável → check final (create×replace) → promoção atômica → idempotência por
  conteúdo.
- **Honestidade:** o lock serializa **esta skill**; contra terceiro que ignore o lock, a detecção é
  **best-effort** (re-hash + `File.Replace`). **Recuperação:** lock preso → instruir; temporário
  órfão → remover na re-execução; destino inexistente → criação.
- **Caminhos gerenciados:** tudo sob `%LOCALAPPDATA%\xpz-mcp-integrations` após **canonicalização**;
  **ACL aplicada antes de persistir**; escrita atômica.

### A.3 OpenCode — edição JSONC pelo mecanismo existente

- **Mecanismo:** o mesmo do `reviewer-ro` — localizar/inserir por texto (`Find-JsoncMatchingBrace`/
  `Find-JsoncKeyValueSpan`, hoje dentro de `Install-OpenCodeReviewerRoAgent.ps1`) e validar com o
  parse completo ciente de comentários (`ConvertFrom-Jsonc`, hoje em `OpenCodeReviewerRoGuard.ps1`).
  **Reaproveitar sem migrar consumidores.** Forma de reuso (v23): as funções do **instalador** entram
  **só por cópia rastreada** — dar dot-source em `Install-OpenCodeReviewerRoAgent.ps1` **executa** o
  script (código no nível do script) e grava o `reviewer-ro` sem backup nem aprovação. O **Guard** só
  define funções e pode ser carregado por dot-source. Registrar nos dois donos.
- **Operações (v23):** **inserir** (`mcp.jev` ausente), **substituir** (entrada reconhecida pelo
  manifesto de instalação, ou migração da entrada manual com aprovação — corpo, *Adaptadores*) e
  **remover** (apagar o trecho `"jev": {…}` e a vírgula vizinha; só entrada reconhecida).
- **Validação pós-edição obrigatória (fail-closed), por comparação de objetos parseados:** o texto
  resultante precisa parsear por inteiro e o objeto resultante precisa ser **igual ao original** com
  exatamente uma diferença — `mcp.jev` acrescentado (inserir), trocado pela forma emitida (substituir)
  ou ausente (remover). Qualquer outra diferença, ou falha de parse → **nada é gravado**, estado
  `edicao_manual_necessaria` e o trecho pronto para colar.
- **Chave duplicada:** o parser devolve o **último** valor sem erro (pwsh 7.6: `ConvertFrom-Json`), então
  não há detecção explícita na v1. Uma edição que caia no objeto «sombreado» não aparece no objeto
  parseado e falha na comparação acima → `edicao_manual_necessaria`. Detecção explícita: **Anexo B.3**.
- **Limites conhecidos** do motor (cego a comentário ao casar chaves) estão registrados no **Anexo
  B.3** e na entrada própria do `999`; a validação por comparação é a mitigação da v1.
- **Fixtures da v1:** arquivo com comentários; `mcp` ausente; `mcp` com outros servidores; `mcp.jev`
  idêntico (idempotência); `mcp.jev` emitido por versão anterior (substituir); `mcp.jev` manual
  (migração com aprovação); `mcp.jev` desconhecido (`entrada_em_conflito`); remover; chave `mcp`
  duplicada; caso que o motor não suporta → `edicao_manual_necessaria`.

### A.4 Vendorização — identidade, bootstrap e evidência do `dist`

Manifesto de árvore (A.4.2), catálogo de bundles (A.4.4) e contenção de rede (A.4.6) foram movidos
para o **Anexo B** na v22; a numeração A.4.n restante foi mantida para não quebrar referências.

#### A.4.1 Identidade e cadeia verificável

A **identidade do artefato = o `integrity` sha512 do tarball** registrado no **lockfile comitado**
(`resolved`+`integrity`); o **commit Git é proveniência**, não âncora (evita afirmar
`commit == tarball`). Se houver archive Git aprovado, a equivalência commit→tarball é **registrada e
verificada** explicitamente (sha512, conteúdo extraído, data, procedimento). O `npm ci` confere o
`integrity` de cada pacote contra o lockfile no momento da instalação.

#### A.4.3 Bootstrap executável e `npm ci`

- `npm ci --ignore-scripts --no-audit --no-fund` em
  `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\`; conferir depois que a versão instalada
  (`node_modules/@jkudish/jev-mcp/package.json`) é a do pin.
- **`--ignore-scripts` justificado e testado:** o pacote declara `prepare`; usamos o `dist`
  pré-compilado. O teste prova que `dist/index.js` existe e o servidor sobe **sem** rodar `prepare`.
- `xpz-mcp-integrations/vendor/` contém o **`package.json` (pin exato) + `package-lock.json`**
  versionados; o installer **cria `vendor-<versao>\`, copia os dois para lá** e **só então** roda
  `npm ci`.
- **Sem indireção mutável:** launcher versionado por path absoluto; comando do cliente aponta para o
  launcher daquela versão. Update = novo lockfile no repositório + instalar + launcher + re-emitir
  config; rollback = versão anterior do repositório + backup do config. **Sem junction/symlink**
  (hazard de `historico/...20260622-20260922.md:48`).

#### A.4.5 Evidência commitada do `dist` (pré-condição de qualquer motor)

Em `xpz-mcp-integrations/fixtures/` (rastreada): trechos **sanitizados** de `provider.ts`/`provider.js`
(**modo `compatible`** + vars — v22), `engines.node` (**≥ 22**), `prepare` do `package.json`, boot
`initialize`, saída no fim do stdin, **+ licença
MIT integral + atribuição**. **Proveniência por fixture:** `commit`, origem, hash, **data de captura**,
escopo — **sem** usar o README da `main` como prova da `0.13.0`. Até então, a tabela de Fornecedor é
**hipótese**.

**Gate do F1:** **revisão estática do `dist` + boot sem chave**.

#### A.4.7 Semântica de rede (2 contextos na v1)

(1) instalador/vendorizador: sem registro fora de install/update; (2) launcher/MCP: só o endpoint. O
teste isolado opt-in está no **Anexo B.4.6**.

### A.5 Pré-requisitos — Node, npm, pwsh e Python opcional

Espelhar `GeneXusPythonPrerequisite.ps1`/`Test-XpzPowerShellRuntime.ps1`: **executável utilizável de
verdade** (rejeitar stub `WindowsApps`/alias da Store) para `node`/`npm`/`pwsh`. Node **gated**
(`>= 22`): `< 22` é bloqueante, acima disso é reportada. O launcher usa o Node **absoluto** resolvido
no install; reparo re-resolve e re-emite. Manifesto × catálogo e runtime dedicado: **Anexo B.5**.

**Python 3.11+ (opcional, v23):** resolvido por `GeneXusPythonPrerequisite.ps1` com checagem de
versão ≥ 3.11 (para o `tomllib`). Usado **só** pelo adaptador do Codex (A.8). Ausente ou antigo →
`python_indisponivel` (**warn**) e o Codex cai em `edicao_manual_necessaria`.

### A.6 `config.json` — schema, origem e consumo

`%LOCALAPPDATA%\xpz-mcp-integrations\config.json` — **registro de configuração não secreto**, ACL
só-dono, UTF-8 sem BOM, **schema versionado** (reduzido na v22):

```
{ schemaVersion, provider: "compatible", baseUrl, model, endpointConfirmed }
```

- **Origem/override** por parâmetro do mutador; **validado contra o descritor**.
- **Consumido** por launcher/auditor/reparo/re-emissão — é **dele** que o launcher reconstrói
  `JEV_API_BASE_URL` (URL completa) e `JEV_MCP_MODEL`.
- **Nunca** contém a chave.
- `endpointConfirmed` vale só para o `baseUrl` gravado: mudar a URL **invalida** e exige nova
  confirmação quando o host diferir do preset Command Code. Host/caminho **redigidos** antes da
  confirmação.

### A.7 Cofre — blob, entrada e eventos

- **Local:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`.
- **Blob:** DPAPI `CurrentUser`, **sem entropia adicional**, **campo `version`**, e metadado do modo
  (`compatible` / `JEV_API_KEY`) — **sem** o metadado misturado ao valor.
- **Fonte:** **só o cofre** na v1 (v23). O launcher não lê chave do ambiente; override por env e o
  estado `credencial_divergente_env_vs_cofre`: **Anexo B.7**.
- **Entrada:** `Read-Host -AsSecureString`; sem transcript/history; não-eco; **ACL antes de persistir**.
- **`acl_nao_aplicavel` — bloqueia mutadores de blob** (criação/import/rotação), sem exceção na v1.
- **Recuperar** = **re-inserir a chave** (DPAPI não roaming; sem backup do cofre na v1 — **Anexo B.7**).
- **Três eventos:** rotação (re-inserir e re-cifrar), remoção (preservar, salvo pedido), incidente
  (apagar blob + orientar revogação no provedor + restart do cliente).

### A.8 Adaptadores — descoberta, precedência e bloco do Codex

**OpenCode — algoritmo de descoberta:** raiz gerenciada na v1 = **global** `~/.config/opencode/`;
candidatos **`opencode.json` e `opencode.jsonc`** nessa pasta; **projeto-local (`.opencode/`) fora do
escopo da v1** (declarado). **Precedência:** resolver `opencode.json` → `opencode.jsonc` (espelha o motor
atual); **sem precedência comprovada** se ambos existirem → `entrada_em_conflito` (bloquear sem
escrever). **Fixtures** para cada caso. Edição em ambos os formatos pelo mecanismo do **A.3**
(inserção textual + validação pós-edição). Entrada `mcp.jev` (`type: local`,
`command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`). Escrita
transacional (A.2); idempotente. **Shape = fato externo** + fixture sanitizada no F1.

**Codex (F1, mínimo — v22/v23):** `~/.codex/config.toml`. O bloco `[mcp_servers.jev]` é emitido pela
skill entre **marcadores de comentário fixos** (ex.: `# >>> xpz-mcp-integrations:jev` /
`# <<< xpz-mcp-integrations:jev`), em texto canônico gerado pela própria skill. **Sem biblioteca TOML
de edição**; detecção e validação pelo **`tomllib`** (Python 3.11+, só leitura — A.5).

**Pré-checagem (antes de qualquer decisão):** o original precisa ser lido pelo `tomllib` sem erro
(senão `entrada_quebrada`, sem escrita); o `tomllib` informa se `mcp_servers.jev` existe **em qualquer
grafia**. Os marcadores precisam estar balanceados e únicos.

| Situação no arquivo | Ação |
|---|---|
| `mcp_servers.jev` inexistente e sem marcadores | **acrescentar** o bloco ao fim (com quebra de linha separadora) |
| Marcadores presentes, conteúdo byte-idêntico ao bloco canônico atual | OK (idempotente) |
| Marcadores presentes, conteúdo byte-idêntico a um bloco **emitido antes** (hash no manifesto de instalação, A.12) | **substituir** entre os marcadores, com diff e aprovação (atualizar/reparar) |
| Marcadores presentes, conteúdo diferente de qualquer bloco emitido (editado à mão, ou tabela alheia que caiu entre eles) | `entrada_em_conflito`; **não toca**; mostrar o diff |
| `mcp_servers.jev` existe fora dos marcadores (entrada manual, qualquer grafia) | migração: mostrar diff e, **com aprovação explícita**, substituir — só quando for um único cabeçalho `[mcp_servers.jev]` cujo trecho vai até o próximo cabeçalho que não seja `[mcp_servers.jev.*]`; outras grafias → `entrada_em_conflito` com instrução para remover à mão |
| Marcadores desbalanceados/duplicados | `entrada_em_conflito`; **não toca** |
| Remover | apagar o bloco entre os marcadores **só** se o conteúdo for byte-idêntico a um bloco emitido (atual ou anterior), com aprovação; senão `entrada_em_conflito` |

- **Pós-validação (fail-closed):** o texto montado precisa ser lido pelo `tomllib` e o objeto
  resultante precisa ser **igual ao original** com exatamente uma diferença em `mcp_servers.jev`
  (acrescentado, trocado pela forma emitida ou ausente). Qualquer outra diferença → nada é gravado,
  `edicao_manual_necessaria`.
- **Env repassado ao launcher:** `env_vars` filtra o herdado; o conjunto que o launcher precisa
  (`LOCALAPPDATA`, `USERPROFILE`, `SystemRoot` etc., para achar cofre/`config.json` e para a DPAPI) é
  **fato a verificar** com filho falso no F1 e, se preciso, declarado no bloco.
- Fixture sanitizada do `config.toml` no F1. Biblioteca TOML com round-trip: **Anexo B.8**.

### A.9 Auditoria — estados, classes e precedência

- **Agregado:** `overall = INTEGRATIONS_OK | INTEGRATIONS_GAPS`. **Tabela estado → `exitCode`/classe por
  motor** (faixa reservada no F1). **`vendor_divergente`** na v1 = versão instalada
  (`node_modules/@jkudish/jev-mcp/package.json`) ≠ pin do descritor.
- **Estado por cliente:** `notConfigured` | `written` | `reloadPending` | `handshakeConfirmed` |
  `e2eOptInConfirmed`; `overall` **não** promove `written` a sucesso operacional; a skill informa a
  **ação de recarga/reinício** necessária.
- **Offline (v1):** `OK`; `ausente`; `entrada_quebrada`/`entrada_divergente`/`entrada_em_conflito`;
  `edicao_manual_necessaria`; `vendor_ausente`/`vendor_divergente`; `launcher_ausente`/
  `launcher_divergente`; `node_ausente`/`node_incompativel`/`node_path_nao_resolve`; `pwsh_ausente`;
  `config_ausente`/`config_invalido`; `python_indisponivel` (**warn**, só afeta o Codex);
  `credencial_ausente`; `endpoint_nao_confirmado` (**warn** + confirmação, host fora do preset);
  `acl_nao_aplicavel` (**warn** na auditoria; **blocking** nos mutadores de blob).
- **Online opt-in** (`-CheckUpdates`): `atualizacao_disponivel` — informa, nunca auto-atualiza.
  Canonicalização de path antes de `entrada_divergente`.

### A.10 Self-tests — inventário executável

**Offline (F1 = v1):** detecção (rejeitar stub); **JSONC** — fixtures do A.3 com validação pós-edição
(falha → `edicao_manual_necessaria`, arquivo intacto), incluindo inserir/substituir/remover com a
comparação de objetos; **Codex** — cada linha da tabela do A.8 (acrescentar, idempotência, substituir
bloco emitido antes, divergente, migração da entrada manual, marcadores desbalanceados, remover só
bloco reconhecido), **cada grafia equivalente** de `mcp_servers.jev` (aspas simples, chave
pontilhada, tabela inline, `jev.*` dentro de `[mcp_servers]`, cabeçalho com espaços) detectada sem
escrita, **tabela alheia entre os marcadores** → conflito sem remover, e Python ausente →
`edicao_manual_necessaria`; **manifesto de instalação** (hash do bloco emitido gravado e reconhecido);
idempotência; **escrita transacional** (create×replace, corrida → recusa, arquivo especial → recusa,
temporário órfão); backup+restore do config; schema do descritor e do `config.json`; **round-trip
DPAPI**; **re-emissão de launcher por versão**; **launcher** com filho falso (exit code = do filho,
zero bytes do launcher em stdout, ambiente limpo = só a allowlist, negativos pré-filho);
**encerramento no fim do stdin** com o servidor real; **revisão estática do `dist` + boot sem chave**
(gate do F1).

**Endurecimentos adiados** (Job Object, manifesto de árvore, TOML, contenção de rede): self-tests
descritos no **Anexo B**, só quando o item voltar.

**Não são rodados pelo orquestrador de pré-push**; a skill declara cada comando e registra em `09`.
**E2E** com `jev_classify` = validação manual opt-in; um E2E aprovado **promove** o cliente de
`handshakeConfirmed` para `e2eOptInConfirmed`.

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

### A.12 Manifesto de instalação (v23)

Não confundir com o `manifest.sha256` de árvore (adiado, **Anexo B.4.2**).

- **Local:** `%LOCALAPPDATA%\xpz-mcp-integrations\install-manifest.json`; ACL só-dono; UTF-8 sem BOM;
  `schemaVersion`; escrita atômica (A.2). **Nunca** contém a chave.
- **Campos:** versão instalada do pacote; caminho absoluto do launcher de cada versão instalada e sua
  sentinela; por cliente (`opencode`, `codex`): caminho do arquivo de config, **hashes de todas as
  formas que a skill já emitiu** para a entrada (atual + anteriores) e data da última escrita.
- **Uso:** reconhecer uma entrada como «da skill» (substituir/remover só se byte-idêntica a um hash
  registrado — A.3, A.8); saber se ainda há referência a um launcher antes de removê-lo.
- **Não é autoridade sobre a config viva:** a auditoria sempre lê o arquivo real do cliente. Manifesto
  ausente ou corrompido → nenhuma entrada é reconhecida (tudo vira conflito ou migração com
  aprovação), nunca remoção cega.

---

## Anexo B — Endurecimentos adiados (preservados da v21; não são obrigação da v1)

Texto **movido sem alteração de conteúdo** do Anexo A da v21 na redução de escopo da **v22**. Cada item
só volta (F2) por **decisão própria**, com motivo concreto. A numeração B.n espelha a A.n de origem.

### B.1 Launcher — sequência nativa, ambiente e terminação (origem: A.1 da v21)

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

**Terminação/árvore:** **EOF/cancelamento** → fechar streams, prazo curto, **encerrar a árvore**;
**filho inesperado/órfão** → fechar pipes e propagar estado. Self-tests: cancelamento, órfão, stderr
intenso, término em tráfego bidirecional.

**Invariante mecanizada (parte nativa):** provar **payload binário grande** (sem re-encode/deadlock) e
**zero bytes** fora do filho.

### B.2 Escrita — ancestralidade e recuperação (origem: A.2 da v21)

- **Alvo:** config do cliente, lock, temporário e backup devem ser **arquivos regulares**, **sem
  reparse point** (symlink/junction), **sem diretório/arquivo especial** — validado por `GetAttributes`
  **em todos os componentes do caminho até uma raiz confiável** (não só na folha), **revalidado
  imediatamente antes da promoção**.
- **Recuperação:** crash → temp+journal limpos na re-execução.
- **Caminhos gerenciados:** **rejeitando reparse points em toda a ancestralidade** (não só na folha) e
  raízes de outro drive.

### B.3 JSONC — localizador estrutural, migração e fixtures (origem: A.3 da v21)

> **Nota da v23:** no pwsh 7.6.6, `ConvertFrom-Json` aceita vírgula final, e o `ConvertFrom-Jsonc` do
> Guard só remove comentários antes de chamá-lo. As menções abaixo a «sem trailing comma» e ao «bug
> vivo» da linha 252 **não se reproduzem no 7.6** (7.4 não testado). O texto segue como na v21.

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

### B.4.2 Manifesto de árvore esperado (origem: A.4.2 da v21)

`vendor/manifest.sha256`, **comitado**, **gerado em release controlada**, com metadados: **commit**,
**versão de npm e Node usadas**, **sha512 do tarball**, **sha256 por arquivo**, **data de captura**,
escopo. O installer **compara a árvore instalada** contra esse baseline e **rejeita**: arquivos
**ausentes ou excedentes**, **caminhos duplicados** após normalização, **reparse points**. Divergência de
**ferramenta** (npm/Node) é reportada **separada** da divergência do **pacote**. O manifesto cobre a
**árvore `node_modules\*\*`**; os dois arquivos do projeto são cobertos pelos hashes commitados de
`package.json`/lock.

### B.4.4 Catálogo de bundles aprovados (origem: A.4.4 da v21)

`xpz-mcp-integrations/vendor/catalog.json` versionado — cada entrada com **descriptor, lockfile,
integridade do tarball, manifesto de árvore e template/hash de launcher**. Update/rollback **só**
consomem entradas do catálogo; `-CheckUpdates` **apenas informa** (nunca instala). Obter um bundle novo =
**atualizar o repositório/skill** (novo catálogo). Rollback re-emite a partir do bundle aprovado
anterior, com **retenção explícita** das versões instaladas.

### B.4.6 Contenção de rede — protocolo de endurecimento **opt-in** (origem: A.4.6 da v21)

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

### B.5 Runtime Node — manifesto × catálogo e cópia dedicada (origem: A.5 da v21)

O `manifest.sha256` cobre **`node_modules/**`** apenas (produção do npm), **invariante** entre versões
aceitas de Node; a **versão de Node/npm** usada na liberação é **fixada no catálogo** e **gated**
(`>= 22`) — divergência de Node é **bloqueante** se `< 22`, senão reportada. O **runtime dedicado do
teste isolado** é uma **cópia do Node da máquina** com **versão e hash registrados**, vinculada ao
catálogo; o launcher de produção usa o Node **absoluto** resolvido no install (mesmo gate).

### B.7 Cofre — backup, retenção e modo inseguro (origem: A.7 da v21)

- **`acl_nao_aplicavel` — bloqueia mutadores de blob** (criação/import/rotação/restore), salvo modo
  inseguro explicitamente autorizado e rotulado.
- **Backup do cofre:** local, retenção, mesma ACL, restore.
- **Override da chave por variável de ambiente** (movido na **v23**, origem: A.7 da v22): «vault-first;
  env só com `-CredentialSource env`; auditor sinaliza `credencial_divergente_env_vs_cofre`
  (**blocking**) só quando **não** houve override». Para voltar, falta especificar como a escolha
  chega ao launcher (por exemplo, gravada no `config.json`) e como a variável passa pelo filtro
  `env_vars` do Codex.

### B.8 Codex — biblioteca TOML vendorizada (origem: A.8 da v21)

**Codex (F2):** `~/.codex/config.toml`, `[mcp_servers.jev]`. **Biblioteca TOML vendorizada** (pin pelo
commit do **próprio** lockfile + integridade + licença + re-verificação), no rigor do `jev-mcp`; o
"subconjunto próprio" foi **descartado** (a config usa arrays `args`/`env_vars`, mapa `env`,
possivelmente multiline). Prova de **round-trip** das formas reais (`command`, `args[]`, `env{}`,
`env_vars[]`, `enabled`, `startup_timeout_sec`); **proibido "span textual"**. **`env_vars` filtra o
herdado** → launcher define **conjunto mínimo explícito provado com filho falso** (`SystemRoot`,
`SystemDrive`, `TEMP`/`TMP`, `PATHEXT`, `COMSPEC`, `PATH` mínimo). Fixture sanitizada do `config.toml` no
F2.

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

## CHANGELOG da v23.1 — clarificações (2026-10-03)

Insumo: observação de agente externo sobre a v23, avaliada pelo orquestrador. Quatro frases, sem
mecanismo novo: «atualizar» incluído nas propriedades essenciais; E2E aprovado **promove**
`handshakeConfirmed` → `e2eOptInConfirmed` (corpo e A.10); migração de chave do config do cliente
grava e confere o cofre **antes** de retirar a chave; import do `auth.json` é bootstrap único para o
cofre, nunca fonte em runtime, sem alterar o `auth.json`.

## CHANGELOG da v23 — correção de gaps da v22 (2026-10-03)

Insumo: segunda opinião de subagente (10 gaps) e observação de outro agente (3 pontos). Cada claim
foi **conferido pelo orquestrador** (ver *Evidência coletada*); um descarte do subagente (grafias
equivalentes do TOML) foi revertido após teste. Decisão humana inclui a mudança da decisão nº 6.

- **Codex:** detecção e pós-validação pelo `tomllib` (Python 3.11+ opcional), cobrindo qualquer grafia
  de `mcp_servers.jev`; substituir/remover só bloco byte-idêntico a um emitido (atual ou anterior);
  migração da entrada manual com aprovação; tabela do A.8 refeita; risco aceito do deslocamento do
  marcador pelo editor do Codex.
- **OpenCode (A.3):** operações inserir/substituir/remover; validação por comparação de objetos
  parseados; reuso do instalador só por cópia rastreada (dot-source executa o script); chave
  duplicada cai na comparação.
- **Novo A.12 — manifesto de instalação** (distinto do `manifest.sha256` adiado).
- **Credencial:** chave só do cofre na v1; override por env → **B.7** (decisão nº 6 alterada).
- **Correções de texto:** ancestralidade no corpo (→ B.2); `enabled=false` retirado; E2E é
  pré-requisito de `e2eOptInConfirmed`; estado `python_indisponivel`; nota no B.3 sobre a hipótese
  do bug JSONC não reproduzida no 7.6.

## CHANGELOG da v22 — redução de escopo (2026-10-03)

Decisão humana, a partir de parecer externo (ver *Evidência coletada*). **Reabre decisões** da v21 de
forma explícita; nada foi apagado — o detalhe cortado foi **movido** para o **Anexo B**.

- **Corpo:** título v22; novo bloco **Propriedades essenciais da v1**; Decisões travadas linha 7
  (só `compatible` implementado) e nova linha 10 (v1 mínima); classe biblioteca JSONC retirada;
  seção JSONC F1-pre substituída por **reaproveitar o mecanismo existente**; vendorização sem
  manifesto/catálogo; launcher `ProcessStartInfo` com stdio herdado; Fornecedor com 4 modos em F4 e
  regra `endpoint_nao_confirmado`; Credencial sem backup do cofre nem «modo inseguro»; **Codex no F1
  com bloco entre marcadores** (sem biblioteca TOML); Fases (F1 = v1; F2 = endurecimentos; F1-pre
  extinto); Riscos aceitos da v22; Adiado aponta para o Anexo B.
- **Anexo A:** reescrito para a v1 (A.1 launcher, A.2 sem ancestralidade/journal, A.3 mecanismo JSONC
  existente, A.4 sem A.4.2/A.4.4/A.4.6, A.5, A.6 schema reduzido, A.7, A.8 tabela do bloco do Codex,
  A.9 estados da v1, A.10 self-tests da v1).
- **Anexo B (novo):** B.1 launcher nativo; B.2 ancestralidade/recuperação; B.3 JSONC estrutural +
  matriz de migração; B.4.2 manifesto; B.4.4 catálogo; B.4.6 contenção de rede; B.5 runtime Node
  dedicado; B.7 backup do cofre/modo inseguro; B.8 biblioteca TOML.
- **`999`:** entrada do `xpz-mcp-integrations` atualizada; nova entrada «JSONC do OpenCode —
  biblioteca única e migração dos consumidores».
- As seções abaixo (CHANGELOG da v21) citam a numeração A.n **da v21**.

## CHANGELOG da reorganização da v21

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
