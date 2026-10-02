# xpz-mcp-integrations — design da skill (v4)

## Papel do documento

Design **vivo** (não congelado) da skill nova `xpz-mcp-integrations`. Registra as decisões
travadas em **2026-10-02** e a evidência empírica coletada nela.

- **v2** — pré-análise do mesmo dia.
- **v3** — consolidação da rodada F0-1 (4 titulares; veredito unânime **revisa**).
- **v4** — consolidação da rodada de refino F0-2 (só opencode; 3× **revisa**).

O plano de F0 é **refinar com os revisores via opencode** até o autor não identificar mais gaps e,
só então, submeter a **uma validação final com um modelo mais caro** (voz única → **segunda
opinião**, não painel). Enquanto a rodada não fechar, `vNextState=pendingResubmission` e **nenhuma
implementação começa**.

Este documento **não** é doc operacional da skill. Quando a skill existir, o contrato
operacional vive em `xpz-mcp-integrations/SKILL.md`.

## Problema

Usuários das skills XPZ que têm acesso ao **Jev/System One** (modelo de decisão do TypeSafe,
exposto por MCP) não dispõem de um caminho gerenciado para instalar, auditar, reparar, atualizar e
remover esse componente MCP. A configuração validada na máquina de referência é manual e **não é
portátil**: **path pessoal absoluto** do wrapper, **dependência de rede/cache em runtime**,
**transitivas sem pin** e a **chave amarrada ao `auth.json` do OpenCode** (não a um cofre neutro).

A skill `xpz-skills-setup` **não** cobre esse domínio (registra skills, instrucionais globais,
`nexa`/`gam`, bootstrap git e o MCP **interno** `xpz-global-instructions` do Cursor; não gerencia
MCP de terceiros). Daí a skill dedicada.

## Escopo da v1

- **Componente:** Jev/System One via `@jkudish/jev-mcp`.
- **Clientes:** OpenCode e Codex.
- **Plataforma:** **Windows** — na prática, a KB nativa/IDE do usuário típico desta base é Windows;
  caminhos de macOS/Linux estão **fora** da v1 (a doc não promete portabilidade).
- **Ciclo:** detectar → instalar (vendorizado) → auditar → reparar → atualizar (consciente) →
  remover.
- **Credencial:** cofre neutro da própria skill.
- **Público:** comunidade (repo público `GxBrasilNOficial`).

**A `v1` (OpenCode + Codex) só se completa ao fim do F2.** O F1 entrega a parte OpenCode e o
núcleo; **sozinho, o F1 não constitui a v1**.

## Não-escopo da v1

- Fork do pacote; Cursor e Claude Code; macOS/Linux; instalar as ferramentas de agente; criar
  conta/assinatura; instalar a skill `skills/jev/` do pacote; configurar uso automático; gerenciar
  MCPs sem descritor; vender como "validados" fornecedores não provados nesta skill.

## Decisões travadas (2026-10-02)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Nome | `xpz-mcp-integrations` |
| 2 | Runtime | pacote **vendorizado** e pinado; **sem `npx`** no início |
| 3 | Node | detectar ausência **e** versão `< 22`; oferecer `winget` id `OpenJS.NodeJS.LTS` com aprovação; se houver `nvm`/`fnm`/`volta`, **relatar**, não instalar |
| 3b | npm | pré-requisito próprio da vendorização |
| 4 | Plataforma | **Windows** (explícita) |
| 5 | Escopo v1 | **OpenCode + Codex** (completa no F2) |
| 6 | Credencial | **cofre neutro**; chave em **DPAPI** (escopo usuário), desprotegida por **launcher PowerShell**; env como override; `auth.json` só import opcional |
| 7 | Fornecedor | 5 modos do pacote; `compatible`/Command Code = **parcial**; outros 4 **experimental opt-in** |
| 8 | Fork | **não** na v1 |
| 9 | Público | comunidade (doc neutra; ausência de Jev não é erro) |

## Arquitetura

### Motor genérico dirigido por descritor

Componente MCP externo = comando, transporte stdio, mapa de variáveis de ambiente, fonte de
credencial, clientes suportados e passos de validação. Cada componente é um **descritor de dados**
(ex.: `components/jev.json`), com **validação de schema fail-closed** e self-test próprio.

### Contrato dos motores novos

Todo motor novo segue o contrato de runtime do repositório (`02-regras-operacionais-e-runtime.md`):
**JSON de máquina**, `-InputPath` para entrada, `-WhatIf`/`ShouldProcess` para simulação (labels
`*_SKIPPED` sob `-WhatIf` — convenção **de propriedade de `xpz-skills-setup/SKILL.md`**; promover
ao `02` só por promoção reconciliada, nunca por adição duplicada). O motor de auditoria **declara
explicitamente** se aceita `-AsJson` (o `02` registra que passar `-AsJson` a um motor sem a flag é
erro de binding **invisível ao parse**). A skill define sua faixa de `exitCode`.

### Fronteira com `xpz-skills-setup`

- `xpz-mcp-integrations`: componentes MCP **externos opcionais**. `xpz-skills-setup`: skills,
  instrucionais, `nexa`/`gam`, bootstrap git, MCP interno do Cursor.
- Regra nos arquivos de cliente compartilhados: **merge sempre**, preservando comentários e demais
  entradas; **backup** antes de escrever; **nunca** remover entrada de outro dono. A regra de
  **backup vale para os escritores novos**; os consumidores já existentes
  (`Install-OpenCodeReviewerRoAgent.ps1`, `Install-CursorGlobalInstructionsMcp.ps1`) **hoje não
  fazem backup** e ganham item de trabalho explícito no F1-pre/F3 se vierem a ser tocados.
- `xpz-skills-setup/SKILL.md` ganha **ponteiro documental** (sem motor). A skill nova entra sozinha
  no inventário (subpasta com `SKILL.md`); **registrar ≠ instalar** e a setup **não** pode
  tratá-la como gatilho de instalação (disciplina anti-padrão `reviewer-ro`). `AGENTS.md`
  (enumeração de skills) precisa de atualização — **já está defasado hoje** (omite
  `xpz-codex-apply-patch-alternative`).

### Suporte JSONC compartilhado — frente própria (F1-pre)

Diagnóstico preciso dos três pontos (verificado no código, não presumido):

- `Find-JsoncMatchingBrace` (`Install-OpenCodeReviewerRoAgent.ps1`) é **ciente de string**, mas
  **conta chaves dentro de comentários**.
- `Find-JsoncKeyValueSpan` (mesmo script) **não é ciente de string**; o comentário no código alega
  uma "heurística de contar aspas" que **não está implementada** — qualquer forma-de-chave dentro
  de um valor string desalinha o span.
- `ConvertFrom-Jsonc` (`OpenCodeReviewerRoGuard.ps1`) é **char-a-char, ciente de string/escape/
  `//`/`/* */`** → é a **referência boa** a consolidar.
- `ConvertFrom-JsoncText` (`Build-LlmDelegateCapabilityManifest.ps1`) é **regex**, **não** é
  string-safe, e **roda hoje** lendo o `opencode.jsonc` real → defeito vivo, de classe diferente.

A frente própria cria `scripts/OpenCodeJsoncSupport.ps1` consolidando o **scanner correto**
(base no `ConvertFrom-Jsonc`), com operações localizadas de insert/update/remove para valores de
objeto, **decidindo e documentando a política de trailing comma** (hoje os dois parsers divergem).
**Consumidores refatorados** (nomear arquivo + linhagem): `OpenCodeReviewerRoGuard.ps1`,
`Build-LlmDelegateCapabilityManifest.ps1` e `Install-OpenCodeReviewerRoAgent.ps1` (que consome o
`ConvertFrom-Jsonc` do Guard via dot-source). Antes de refatorar, **adicionar fixtures negativas**
que os self-tests atuais **não** cobrem (chave comentada; forma-de-chave dentro de string; `{}`
dentro de `/* */`; `//` dentro de string) — sem elas, "re-rodar os self-tests" não prova nada.
Dono documental do script refatorado: `xpz-llm-delegate/SKILL.md`. Motivo de frente própria:
refatorar o **instrumento de revisão** dentro da frente revisada é risco auto-referente.

## Execução do MCP (vendorização)

- **Pacote:** `@jkudish/jev-mcp`; **versão fixada `0.13.0`** (integridade/tag/commit — **fatos
  externos**, ver «Fatos a re-verificar»).
- **Artefatos commitados:** `package.json` **de pin** (versão **exata** `"0.13.0"`, sem `^`/`~`) e
  `package-lock.json`. O **lockfile é a fonte autoritativa de integridade**; o `dist.integrity` do
  descritor é **asserção** conferida contra o lock.
- **Vendor:** instalação em `%LOCALAPPDATA%\xpz-mcp-integrations\vendor-<versao>\` com **`npm ci`**
  + `--ignore-scripts`; `npm` é pré-requisito próprio. **Atomicidade:** `npm ci` não é atômico →
  vendorizar em **diretório por versão** e trocar por **switch atômico** (junction/symlink ativo);
  rollback = reapontar para a versão anterior. Tratar o caso de **MCP em execução** (lock do
  Windows impede rename/delete). Sem rede no runtime; o pacote de terceiros **não** é comitado.

### Launcher portátil (molde gerado pela skill)

- **Comando do MCP = launcher PowerShell:** `command: ["pwsh", "-NoProfile", "-File", "<launcher>.ps1"]`.
  O launcher: (1) desprotege a chave do cofre com **DPAPI** em memória, **nunca por argv**;
  (2) resolve o caminho **absoluto** do `node`; (3) inicia `node
  <vendor>\node_modules\@jkudish\jev-mcp\dist\index.js` com a variável de credencial **só** no
  ambiente do filho.
- **Stdio (ponto crítico):** `Start-Process` **não** preserva stdin/stdout do MCP. O launcher usa
  `System.Diagnostics.ProcessStartInfo` com `UseShellExecute=$false` +
  `RedirectStandardInput/Output/Error=$true` e **proxy de bytes** bidirecional (ou `& node` no
  próprio processo). O self-test prova **stdio binário (payload grande) + propagação de exit code**,
  não só a injeção de env.
- **Dependência de runtime:** o launcher exige `pwsh` (7.4+); a auditoria reporta estado próprio se
  faltar. Rota descartada (Node→pwsh para desproteger) por risco de **transcrição** de PowerShell.
- **Marcador de propriedade:** sentinela no cabeçalho + registro no **manifesto**; uninstall remove
  **somente se** sentinela **e** path no manifesto; órfão = reportar.

## Fornecedor

Cinco modos (`dist/provider.d.ts` → `JevProvider`): `typesafe`, `openrouter`, `cloudflare`,
`vercel`, `compatible`.

| Modo (`JEV_PROVIDER`) | Credencial | Endpoint / wire | Status aqui |
|---|---|---|---|
| `typesafe` (padrão do pacote) | `TYPESAFE_API_KEY` | transport do SDK; modelo default `jev-latest` | experimental opt-in |
| `openrouter` | `OPENROUTER_API_KEY` | `POST {JEV_OPENROUTER_BASE_URL:-https://openrouter.ai/api}/alpha/decisions`; headers `HTTP-Referer`/`X-Title`/`X-OpenRouter-Title`; `jev-latest`→`jev-1.13`; slug `typesafe/*` | experimental opt-in |
| `cloudflare` | `JEV_CLOUDFLARE_API_TOKEN` ou `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` | `POST {JEV_CLOUDFLARE_BASE_URL:-https://api.cloudflare.com/client/v4}/accounts/<id>/ai/run`; envelope `{model, input:{state,questions}}`; resposta aninhada; slug `typesafe/jev` | experimental opt-in |
| `vercel` | `AI_GATEWAY_API_KEY` | transport do SDK (Vercel AI Gateway) | experimental opt-in |
| `compatible` | `JEV_API_KEY` | `POST` direto na **URL completa** `JEV_API_BASE_URL`, `Authorization: Bearer`; `{model, state, questions}` → `{answers, usage?}` | **parcial** |

- **`compatible` não é "qualquer API OpenAI":** exige o contrato System One/Jev; a URL é usada
  **como veio**. `cloudflare`/`vercel` usam **envelopes próprios** — não são intercambiáveis com
  `compatible`. Sem `JEV_PROVIDER` (`auto`), o pacote **infere** pela presença de env.
- **`compatible` = parcial:** a evidência registrada prova só o **handshake MCP**, não a decisão
  E2E; a doc e o relatório usam "parcial", **não** "validado". O E2E real (com chave) é validação
  manual opt-in, a registrar.
- **Command Code** é o preset `compatible` sugerido (`JEV_API_BASE_URL=…/provider/v1/systemone`,
  `JEV_MCP_MODEL=typesafe/jev`), chave gerada no site — nunca presumido.
- **Experimental opt-in:** os 4 modos não provados ficam fora do caminho feliz e dos self-tests do
  F1; só por escolha explícita, com aviso.
- **Import `auth.json`:** opcional, com ressalva de que a credencial `commandcode/*` do OpenCode é
  de **gateway de LLM** — assumir que serve como chave de decisão do System One exige confirmação.

## Credencial

- **Cofre:** `%LOCALAPPDATA%\xpz-mcp-integrations\vault\`, em `%LOCALAPPDATA%` lido **do ambiente**
  (redirecionável — não compor de `%USERPROFILE%`). Separado do `vendor-*/`.
- **DPAPI (especificação operacional):** escopo **usuário** (`CurrentUser`); **sem entropia
  adicional** (declarado) ou entropia documentada; **ACL** restritiva do diretório `vault\`
  (só o dono); procedimento de **rotação/revogação** da chave; entrada oculta por
  `Read-Host -AsSecureString` (documentar comportamento sob transcrição/GPO); o launcher **registra
  qual fonte usou** (env × cofre) **sem o valor**. Descriptografia é do **launcher**.
- **Limite honesto:** DPAPI protege **em repouso**, **não** contra processo do mesmo usuário
  (inclusive o shell do agente) nem inspeção do env do filho. Ganho real sobre o texto claro de
  hoje, não promessa absoluta.
- **Fronteira de confiança:** a chave é entregue ao processo `jev-mcp` e enviada ao **endpoint
  configurado** como credencial de transporte; o vetado é vazar para log/config/doc/chat/outro
  destino. Fronteira = pacote + transitivas + endpoint.
- **Ordem de resolução:** (1) env presente; (2) cofre; (3) falha segura. `credencial_divergente_env_vs_cofre`
  deixa de ser só informativo: **aviso acionável** (oferta de limpar o env obsoleto; opt-in
  fail-closed). **Chave nunca** impressa/logada/copiada; entrada só por comando local oculto.

## Adaptadores de cliente (v1)

- **OpenCode** — `~/.config/opencode/opencode.jsonc`, seção `mcp.jev` (`type: local`,
  `command: ["pwsh","-NoProfile","-File","<launcher>"]`, campo **`environment`**, não `env`).
  Merge via o **suporte JSONC**; backup; idempotente. Entrada `jev` preexistente divergente →
  `entrada_em_conflito`, **bloqueia sobrescrita** por padrão.
- **Codex** — `~/.codex/config.toml`, `[mcp_servers.jev]` (**F2**), com **prova empírica do shape**
  antes de escrever o motor: env em **sub-tabela** `[mcp_servers.jev.env]` (ordem importa em TOML),
  string **literal** `'...'`, span de update até o próximo cabeçalho **não-filho**, `enabled=false`
  como "desabilitar", e `env_vars` que **filtra** o ambiente herdado (ameaça o passo "env presente"
  do launcher). Fixture do `config.toml` da máquina (sanitizada) no F2.

## Auditoria (estados)

**Gate offline/determinístico:** `OK`, `ausente`, `entrada_quebrada`/`entrada_divergente`/
`entrada_em_conflito`, `versao_defasada`, `vendor_ausente`/`vendor_divergente`,
`wrapper_ausente`/`wrapper_divergente`, `node_ausente`/`node_incompativel`/`node_path_nao_resolve`,
`pwsh_ausente`, `fornecedor_ausente`/`fornecedor_nao_validado`, `credencial_ausente`/
`credencial_divergente_env_vs_cofre`.
**Online opt-in** (`-CheckUpdates`, com rede): `atualizacao_disponivel` — informa, nunca
auto-atualiza; **fora** do gate offline. Nada gravado sem confirmação; a comparação de paths
expande variáveis antes de decidir `entrada_divergente`.

## Atualizar e remover

- **Atualizar:** consciente (release notes, breaking changes, backup, switch de vendor, teste,
  rollback). Nunca por existir versão nova.
- **Remover:** manifesto registra **referências por cliente**; o launcher só sai quando **não
  restar referência**; exige **sentinela E** path no manifesto; órfão = reportar. Preservar cofre,
  `auth.json`, fornecedor e demais MCPs; no Codex, preferir `enabled=false`.

## Testes

- **Self-tests offline:** detecção, merge JSONC (**incluindo fixtures negativas**), idempotência,
  backup, rollback, **schema do descritor**, e o **launcher com filho falso** — com foco em **stdio
  binário + exit code**, injeção exata da variável, ausência de vazamento em erro e ausência de
  rede. Sem rede e sem chave.
- **Os self-tests não são rodados pelo orquestrador de pré-push**; a skill declara o comando de
  cada um e registra em `09` (`Validação:`/`Tokens:`). Self-tests de **TOML** no **F2**.
- **E2E** com `jev_classify` = validação manual opt-in; pré-requisito de qualquer alegação de
  "validado".

## Documentação e paridade

- `README.md` trilíngue (skills enumeradas em **seis** pontos: abertura + lista, ×3 línguas).
- `CHANGELOG.md` trilíngue.
- `09` com formato completo (`Dono:` + `Validação:`/`Tokens:`/`Exit:`).
- `02` (contrato de motor) e `SECURITY.md` (cofre — primeira feature de segredo em repouso do repo).
- `08` quando aplicável; `AGENTS.md` (enumeração de skills) e ponteiro documental na setup.
- `xpz-llm-delegate/SKILL.md` (dono do script refatorado no F1-pre).
- **`999-ideias-pendentes.md`:** a entrada já **contradiz** a v3/v4 ao dizer "Command Code como
  preset **validado**"; corrigir **agora** para "parcial (v3+)"; o restante sincroniza no
  congelamento.
- Conformidade: `#requires -Version 7.4`; UTF-8 **sem BOM** via `Utf8NoBomEncodingSupport.ps1`;
  molde `.example.ps1`.
- `Test-XpzParameterNamingContract.ps1` **não** é gate geral (lista fixa do empacotamento XPZ) —
  a convenção real é `02` + formato do `09`.
- Na seção de gates, **não enumerar ≥2 gates numa linha** (dispara `Test-PrePushGateEnumerationParity`).

## Fases

- **F0** — design + revisão (em andamento: F0-1 4 titulares; F0-2 refino opencode; faltam as rodadas
  de refino e a validação final com modelo mais caro).
- **F1-pre (frente própria)** — `OpenCodeJsoncSupport.ps1` + fixtures negativas + refatoração dos
  consumidores + self-tests + pré-push.
- **F1** — skill (parte OpenCode + núcleo) + descritor Jev (Command Code) + launcher + cofre/DPAPI +
  vendorizador + self-tests + docs. **F1 ≠ v1.**
- **F2** — Codex (TOML, prova empírica) + self-tests TOML + auditoria de versão/drift + update/
  rollback. **Completa a v1.**
- **F3** — Cursor + Claude Code (reconciliar o motor do `~/.cursor/mcp.json`).
- **F4** — opcionais: validação dos fornecedores experimentais; backend Python; fork/espelho.

## Riscos e decisões em aberto

- **Launcher stdio** é o ponto mais frágil do F1 (passthrough bidirecional no Windows); prova
  explícita no self-test.
- **Merge TOML (Codex)** — sub-tabela `.env`, string literal, `enabled`, `env_vars`; prova empírica
  no F2.
- **Revisão do `dist`** (pré-requisito do E2E com chave): allowlist de hosts + varredura de
  `fetch`/`undici`/`HttpClient`/telemetria + dump de env em erro/log + comportamento das **9
  transitivas** (o lock pinado não audita comportamento).
- **Fatos a re-verificar no F1/F2** (externos, não auditáveis nesta raiz): integridade/tag/commit do
  pacote, `engines.node`, tabela dos 5 modos, boot MCP offline, semântica TOML do Codex. Marcados
  como **evidência externa provisória** até virarem artefato versionado (lockfile + fixture).
- **Fornecedores experimentais** só sob opt-in.
- **Node/pwsh** são dependências de runtime.

## Evidência coletada (2026-10-02)

- `node v24.18.0`/`python 3.14`; pacote vendorizado em pasta temporária; **boot offline** com env
  fictício + `initialize` MCP (`server jev-mcp 0.13.0`, `protocolVersion 2025-06-18`).
- **`dist/provider.js` lido** (em `%TEMP%\opencode\jev-probe\`): 5 modos, endpoints/envelopes,
  inferência `auto`, contrato do `compatible`. **Evidência externa provisória** (fora do repo).
- **Rodadas F0:** F0-1 (RoundId `mcp-integrations-f0-v2`, 4 titulares meta/openai/anthropic + stealth,
  `panelReady`, **4× revisa**); F0-2 refino (RoundId `mcp-integrations-f0-v3`, opencode-only:
  meta/deepseek contam, stealth não; **3× revisa**). Os vereditos ficam em
  `Temp/revisao-por-pares/<RoundId>/` (**efêmero, gitignored**); a persistência do ledger em
  `.peer-review-rounds/` fica para o congelamento.
- Alternativa **Python** (`typesafe-mcp` no PyPI) — opção de F4.

## Referências

- `https://github.com/jkudish/jev-mcp` (MIT); `https://docs.typesafe.ai`.
- `xpz-skills-setup/SKILL.md` — fronteira.
- `15-revisao-por-pares.md` e `xpz-llm-delegate/SKILL.md` — `commandcode/*` como **catálogo de
  vozes** do painel; **não confundir** com o endpoint do Jev.
